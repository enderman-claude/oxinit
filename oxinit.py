#!/usr/bin/env python3
"""oxinit: a PID 1 init that works exactly as documented.

Services are declared in a small stack language (see etc/services.fs).
Every service must state all 12 fields. Nothing has a default.
Each service runs in its own thread. One reaper thread owns waitpid.
"""
import ctypes
import grp
import os
import pwd
import queue
import re
import shlex
import signal
import sys
import threading
import time
from dataclasses import dataclass, field

DEFAULT_CONFIG = "/etc/oxinit/services.fs"
MEMEUNIT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "memeunit", "libmemeunit.so")
CRASH_WINDOW = 60      # seconds
CRASH_LIMIT = 5        # crashes within the window before giving up
MAX_BACKOFF = 30       # seconds

FIELDS = ("name", "exec", "args", "cwd", "user", "group", "env",
          "restart", "backoff", "stop_signal", "stop_timeout", "log")
RESTART_POLICIES = ("always", "never", "on-failure")
INT_RE = re.compile(r"-?\d+\Z")

stop_event = threading.Event()
table_lock = threading.Lock()   # guards owners, svc.pid, and the fork+register step
owners = {}                     # pid -> Service
_memeunit = None


class ConfigError(Exception):
    pass


@dataclass
class Service:
    name: str
    exec_path: str
    args: list
    cwd: str
    user: str
    group: str
    env: dict
    restart: str
    backoff: int
    stop_signal: int
    stop_timeout: int
    log_path: str
    uid: int
    gid: int
    pid: int | None = None
    exits: queue.Queue = field(default_factory=queue.Queue)
    thread: threading.Thread | None = None


# --- memeunit ---------------------------------------------------------------

def load_memeunit():
    """Load the compiled-in meme unit. Refuse to boot without it."""
    global _memeunit
    try:
        lib = ctypes.CDLL(MEMEUNIT_PATH)
    except OSError as e:
        print(f"oxinit: cannot load memeunit ({e}). Run `make` in memeunit/. "
              f"The squad needs its memes.", file=sys.stderr, flush=True)
        sys.exit(1)
    lib.memeunit_pick.restype = ctypes.c_char_p
    lib.memeunit_pick.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    _memeunit = lib


def meme(kind, seed):
    return _memeunit.memeunit_pick(kind.encode(), seed.encode()).decode()


def log(msg, kind=None, seed=""):
    line = f"[oxinit {time.strftime('%H:%M:%S')}] {msg}"
    if kind is not None:
        line += f" | {meme(kind, seed)}"
    print(line, flush=True)


# --- config language --------------------------------------------------------

def tokenize(line, lineno):
    """Split one line into ('str', text) and ('word', text) tokens.

    "double quoted" is a string literal. A backslash followed by a space
    starts a comment that runs to end of line.
    """
    tokens, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c.isspace():
            i += 1
        elif c == '"':
            j = line.find('"', i + 1)
            if j < 0:
                raise ConfigError(f"line {lineno}: unterminated string. "
                                  f"The quote ran off into the sunset.")
            tokens.append(("str", line[i + 1:j]))
            i = j + 1
        elif c == "\\" and (i + 1 == n or line[i + 1].isspace()):
            break
        else:
            j = i
            while j < n and not line[j].isspace():
                j += 1
            tokens.append(("word", line[i:j]))
            i = j
    return tokens


def _resolve_user(name, lineno):
    try:
        return pwd.getpwnam(name).pw_uid
    except KeyError:
        raise ConfigError(f"line {lineno}: user: no such user '{name}'. Create them or pick another.")


def _resolve_group(name, lineno):
    try:
        return grp.getgrnam(name).gr_gid
    except KeyError:
        raise ConfigError(f"line {lineno}: group: no such group '{name}'.")


def build_service(v, lineno):
    def err(field_name, msg):
        return ConfigError(f"line {lineno}: {field_name}: {msg}")

    for f in ("name", "exec", "args", "cwd", "user", "group", "env",
              "restart", "stop_signal", "log"):
        if not isinstance(v[f], str):
            raise err(f, f"needs a string, got {v[f]!r}")
    for f in ("backoff", "stop_timeout"):
        if not isinstance(v[f], int) or v[f] < 0:
            raise err(f, f"needs a non-negative integer, got {v[f]!r}")

    if not v["name"]:
        raise err("name", "cannot be empty")
    if not v["exec"].startswith("/"):
        raise err("exec", "must be an absolute path. No PATH lookup here, we don't guess.")
    if not v["cwd"].startswith("/"):
        raise err("cwd", "must be an absolute path")
    if v["log"] != "-" and not v["log"].startswith("/"):
        raise err("log", 'must be an absolute path, or "-" for stdout')
    if v["restart"] not in RESTART_POLICIES:
        raise err("restart", f"must be one of {', '.join(RESTART_POLICIES)}, got '{v['restart']}'")

    sig = getattr(signal, "SIG" + v["stop_signal"], None)
    if not isinstance(sig, signal.Signals):
        raise err("stop_signal", f"'{v['stop_signal']}' is not a signal name (try \"TERM\")")

    try:
        args = shlex.split(v["args"])
    except ValueError as e:
        raise err("args", f"could not split: {e}")

    env = {}
    for tok in v["env"].split():
        key, sep, val = tok.partition("=")
        if not sep or not key:
            raise err("env", f"'{tok}' is not KEY=VALUE")
        env[key] = val

    return Service(
        name=v["name"], exec_path=v["exec"], args=args, cwd=v["cwd"],
        user=v["user"], group=v["group"], env=env, restart=v["restart"],
        backoff=v["backoff"], stop_signal=int(sig), stop_timeout=v["stop_timeout"],
        log_path=v["log"],
        uid=_resolve_user(v["user"], lineno),
        gid=_resolve_group(v["group"], lineno),
    )


def parse_config(text):
    stack, services, seen = [], [], set()
    for lineno, line in enumerate(text.splitlines(), 1):
        for kind, value in tokenize(line, lineno):
            if kind == "str":
                stack.append(value)
            elif INT_RE.match(value):
                stack.append(int(value))
            elif value == "service":
                if len(stack) != len(FIELDS):
                    raise ConfigError(
                        f"line {lineno}: service needs exactly {len(FIELDS)} values on the stack, "
                        f"found {len(stack)}. Fields in order: {' '.join(FIELDS)}. "
                        f"No defaults here.")
                svc = build_service(dict(zip(FIELDS, stack)), lineno)
                stack.clear()
                if svc.name in seen:
                    raise ConfigError(f"line {lineno}: duplicate service name '{svc.name}'")
                seen.add(svc.name)
                services.append(svc)
            else:
                raise ConfigError(f"line {lineno}: unknown word '{value}'. "
                                  f"Only literals and `service` exist here.")
    if stack:
        raise ConfigError(f"{len(stack)} leftover value(s) on the stack at end of file. "
                          f"Did you forget `service`?")
    if not services:
        raise ConfigError("no services declared. A PID 1 with nothing to do is just an expensive sleep.")
    return services


# --- process management -----------------------------------------------------

def _child(svc):
    """Runs in the forked child. Never returns."""
    try:
        signal.signal(signal.SIGTERM, signal.SIG_DFL)
        signal.signal(signal.SIGINT, signal.SIG_DFL)
        os.setsid()
        if svc.log_path != "-":
            fd = os.open(svc.log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
            os.dup2(fd, 1)
            os.dup2(fd, 2)
            os.close(fd)
        os.chdir(svc.cwd)
        os.setgid(svc.gid)
        os.setuid(svc.uid)
        os.execve(svc.exec_path, [svc.exec_path] + svc.args, svc.env)
    except BaseException as e:
        os.write(2, f"oxinit: {svc.name} failed to start: {e}\n".encode())
        os._exit(127)


def spawn(svc):
    """Fork and register the child under one lock, so the reaper can never miss it."""
    with table_lock:
        if stop_event.is_set():
            return False
        pid = os.fork()
        if pid == 0:
            _child(svc)
        owners[pid] = svc
        svc.pid = pid
    log(f"{svc.name} started (pid {pid})", "start", svc.name)
    return True


def reaper():
    """The only thread that calls waitpid. Hands exit statuses to service threads."""
    while True:
        try:
            pid, status = os.waitpid(-1, 0)
        except ChildProcessError:
            time.sleep(0.1)  # no children right now, not an error
            continue
        with table_lock:
            svc = owners.pop(pid, None)
            if svc is not None:
                svc.pid = None
        if svc is not None:
            svc.exits.put(status)
        else:
            log(f"reaped orphan pid {pid}")


def service_thread(svc):
    crashes = []
    while not stop_event.is_set():
        if not spawn(svc):
            break
        status = svc.exits.get()          # blocks until the reaper delivers the exit
        code = os.waitstatus_to_exitcode(status)
        log(f"{svc.name} exited with code {code}", "exit", svc.name)
        if stop_event.is_set():
            log(f"{svc.name} exited during shutdown", "stop", svc.name)
            break
        if svc.restart == "never" or (svc.restart == "on-failure" and code == 0):
            log(f"{svc.name} will not be restarted (restart: {svc.restart})", "oneshot", svc.name)
            break
        now = time.monotonic()
        crashes = [t for t in crashes if now - t < CRASH_WINDOW]
        crashes.append(now)
        if len(crashes) > CRASH_LIMIT:
            log(f"{svc.name} crashed {CRASH_LIMIT} times in {CRASH_WINDOW}s, giving up",
                "giveup", svc.name)
            break
        delay = min(svc.backoff * 2 ** (len(crashes) - 1), MAX_BACKOFF)
        log(f"restarting {svc.name} in {delay}s", "restart", svc.name)
        stop_event.wait(delay)


def shutdown(services):
    with table_lock:
        stop_event.set()
        targets = [(s, s.pid) for s in services if s.pid is not None]
    log("shutdown requested")
    for svc, pid in targets:
        log(f"sending SIGTERM to {svc.name}", "stop", svc.name)
        try:
            os.kill(pid, svc.stop_signal)
        except ProcessLookupError:
            pass
    for svc in services:
        if svc.thread is None:
            continue
        svc.thread.join(timeout=svc.stop_timeout)
        if svc.thread.is_alive():
            with table_lock:
                pid = svc.pid
                if pid is not None:
                    log(f"{svc.name} ignored the polite request, sending SIGKILL", "kill", svc.name)
                    os.kill(pid, signal.SIGKILL)
            svc.thread.join(timeout=5)


def main():
    config_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG
    load_memeunit()

    if os.getpid() != 1:
        log("not running as PID 1, dev mode")

    try:
        with open(config_path) as f:
            services = parse_config(f.read())
    except OSError as e:
        log(f"could not read {config_path}: {e}")
        sys.exit(1)
    except ConfigError as e:
        log(f"config error: {e}", "config")
        sys.exit(1)

    threading.Thread(target=reaper, name="reaper", daemon=True).start()
    for svc in services:
        svc.thread = threading.Thread(target=service_thread, args=(svc,),
                                      name=svc.name, daemon=True)
        svc.thread.start()

    signal.signal(signal.SIGTERM, lambda *_: stop_event.set())
    signal.signal(signal.SIGINT, lambda *_: stop_event.set())
    log(f"loaded {len(services)} service(s) from {config_path}")

    while not stop_event.is_set():
        time.sleep(0.2)

    shutdown(services)
    log("oxinit exiting")


if __name__ == "__main__":
    main()
