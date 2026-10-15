#!/usr/bin/env python3
"""oxinit: a PID 1 init that works exactly as documented.

Services are declared in .oxi files (see README.md, Syntax).
Each service runs in its own thread. One reaper thread owns waitpid.
Usage:
  oxinit.py [FILE]           run services (default /etc/oxinit/services.oxi)
  oxinit.py --check [FILE]   parse and validate only, then exit
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

DEFAULT_CONFIG = "/etc/oxinit/services.oxi"
MEMEUNIT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "memeunit", "libmemeunit.so")
CRASH_WINDOW = 60      # seconds
CRASH_LIMIT = 5        # crashes within the window before giving up
MAX_BACKOFF = 30       # seconds

FIELDS = ("mood", "summon", "incant", "arena", "role", "party", "loadout",
          "lives", "cooldown", "eviction-notice", "grace", "scoreboard",
          "amiafurry", "fursona-name", "fursona-description", "fursona-species")
FURSONA_FIELDS = ("fursona-name", "fursona-description", "fursona-species")
NO_DASH = {"mood", "summon", "arena", "role", "party", "lives", "cooldown",
           "eviction-notice", "grace", "amiafurry"}
LIVES = ("always", "never", "on-failure")

# mood -> (ANSI style, border, prefix)
MOODS = {
    "chill":   ("36",    "-",  "~"),
    "hyper":   ("1;93",  "*",  "!!"),
    "grumpy":  ("31",    "#",  ">:("),
    "sleepy":  ("2;34",  ".",  "zz"),
    "feral":   ("35",    "/\\", ">>"),
    "owo":     ("95",    "~",  "owo"),
    "sus":     ("32",    "?",  "sus"),
    "blessed": ("97;43", "=",  "(*)"),
    "doomed":  ("30;41", "x",  "RIP"),
}

SHELL_SPECIAL = set("|&;<>()`$")
DURATION_RE = re.compile(r"(\d+)s\Z")

stop_event = threading.Event()
table_lock = threading.Lock()   # guards owners, svc.pid, and the fork+register step
owners = {}                     # pid -> Service
color_on = False                # set in main(): ANSI only when stdout is a TTY
_memeunit = None


class ConfigError(Exception):
    pass


@dataclass
class Service:
    name: str
    mood: str
    program: str
    args: list
    cwd: str
    user: str
    uid: int
    group: str
    gid: int
    env: dict
    lives: str
    cooldown: int
    eviction_notice: int
    grace: int
    scoreboard: str
    amiafurry: bool
    fursona: dict
    pid: int | None = None
    exits: queue.Queue = field(default_factory=queue.Queue)
    thread: threading.Thread | None = None
    started_once: bool = False


# --- output -----------------------------------------------------------------

def olog(text):
    """Plain oxinit line, no theme (boot, shutdown, config errors)."""
    print(f"oxinit: {text}", flush=True)


def _style(text, ansi):
    if color_on and ansi:
        return f"\033[{ansi}m{text}\033[0m"
    return text


def svc_log(svc, text, kind=None):
    """Service line: themed by mood, prefix and name first."""
    ansi, _border, prefix = MOODS[svc.mood]
    line = f"{prefix} {svc.name} {text}"
    if kind is not None:
        line += f" | {meme(kind, svc.name)}"
    print(_style(line, ansi), flush=True)


def svc_rule(svc):
    ansi, border, _prefix = MOODS[svc.mood]
    print(_style(border * 8, ansi), flush=True)


def load_memeunit():
    """Load the compiled-in meme unit. Refuse to run without it."""
    global _memeunit
    try:
        lib = ctypes.CDLL(MEMEUNIT_PATH)
    except OSError as e:
        print(f"oxinit: cannot load memeunit ({e}). Run `make` in memeunit/.",
              file=sys.stderr, flush=True)
        sys.exit(1)
    lib.memeunit_pick.restype = ctypes.c_char_p
    lib.memeunit_pick.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    _memeunit = lib


def meme(kind, seed):
    return _memeunit.memeunit_pick(kind.encode(), seed.encode()).decode()


# --- config language --------------------------------------------------------

def split_incant(raw, lineno):
    """Split !incant the way a POSIX shell does, rejecting shell features we don't run."""
    def bad(msg):
        return ConfigError(f"line {lineno}: !incant: {msg}")

    if raw == "-":
        return []
    quote = None
    i = 0
    while i < len(raw):
        c = raw[i]
        if quote == "'":
            if c == "'":
                quote = None
        elif c == "\\":
            i += 1  # the next character is literal
        elif quote == '"':
            if c == '"':
                quote = None
            elif c in "$`":
                raise bad(f"'{c}' expansion is not supported")
        else:
            if c in "'\"":
                quote = c
            elif c in SHELL_SPECIAL:
                raise bad(f"unquoted '{c}' is not supported (no pipes, redirects, "
                          f"separators, or expansion)")
        i += 1
    if quote is not None:
        raise bad("unterminated quote")
    try:
        return shlex.split(raw)
    except ValueError as e:
        raise bad(str(e))


def parse_seconds(value, fname, lineno):
    m = DURATION_RE.match(value)
    if not m:
        raise ConfigError(f"line {lineno}: !{fname}: must be whole seconds like 2s, got '{value}'")
    return int(m.group(1))


def build_service(name, fields, header_line):
    missing = [f for f in FIELDS if f not in fields]
    if missing:
        raise ConfigError(f"line {header_line}: service '{name}' is missing "
                          + ", ".join("!" + m for m in missing))

    def val(f):
        return fields[f][0]

    def ln(f):
        return fields[f][1]

    def err(f, msg):
        return ConfigError(f"line {ln(f)}: !{f}: {msg}")

    for f in NO_DASH:
        if val(f) == "-":
            raise err(f, "'-' is not allowed here, give a real value")

    mood = val("mood")
    if mood not in MOODS:
        raise err("mood", f"unknown mood '{mood}'. Choose one of: {', '.join(MOODS)}")

    summon = val("summon")
    if not summon.startswith("/"):
        raise err("summon", "must be an absolute path. No PATH lookup here.")

    arena = val("arena")
    if not arena.startswith("/"):
        raise err("arena", "must be an absolute path")

    try:
        uid = pwd.getpwnam(val("role")).pw_uid
    except KeyError:
        raise err("role", f"no such user '{val('role')}'")
    try:
        gid = grp.getgrnam(val("party")).gr_gid
    except KeyError:
        raise err("party", f"no such group '{val('party')}'")

    env = {}
    if val("loadout") != "-":
        for tok in val("loadout").split():
            key, sep, value = tok.partition("=")
            if not sep or not key:
                raise err("loadout", f"'{tok}' is not KEY=VALUE")
            env[key] = value

    lives = val("lives")
    if lives not in LIVES:
        raise err("lives", f"must be one of {', '.join(LIVES)}")

    cooldown = parse_seconds(val("cooldown"), "cooldown", ln("cooldown"))
    grace = parse_seconds(val("grace"), "grace", ln("grace"))

    sig_name = val("eviction-notice")
    if sig_name.startswith("SIG"):
        raise err("eviction-notice", f"write the name without SIG, like '{sig_name[3:]}'")
    sig = getattr(signal, "SIG" + sig_name, None)
    if not isinstance(sig, signal.Signals):
        raise err("eviction-notice", f"'{sig_name}' is not a signal name (try TERM)")

    scoreboard = val("scoreboard")
    if scoreboard != "-" and not scoreboard.startswith("/"):
        raise err("scoreboard", "must be an absolute path, or - for stdout")

    amiafurry = val("amiafurry")
    if amiafurry not in ("true", "false"):
        raise err("amiafurry", "must be true or false")

    fursona = {}
    for f in FURSONA_FIELDS:
        v = val(f)
        if amiafurry == "true" and v == "-":
            raise err(f, "required when !amiafurry is true, give a real value")
        if amiafurry == "false" and v != "-":
            raise err(f, "must be - when !amiafurry is false")
        fursona[f] = v

    return Service(
        name=name, mood=mood, program=summon,
        args=split_incant(val("incant"), ln("incant")),
        cwd=arena, user=val("role"), uid=uid, group=val("party"), gid=gid,
        env=env, lives=lives, cooldown=cooldown, eviction_notice=int(sig),
        grace=grace, scoreboard=scoreboard,
        amiafurry=(amiafurry == "true"), fursona=fursona,
    )


def parse_config(text):
    services, names = [], set()
    current = None  # [name, header_line, fields]

    def finish():
        services.append(build_service(current[0], current[2], current[1]))

    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("@"):
            if current is not None:
                finish()
            name = line[1:].strip()
            if not name or any(ch.isspace() for ch in name):
                raise ConfigError(f"line {lineno}: service name must be non-empty with no spaces")
            if name in names:
                raise ConfigError(f"line {lineno}: duplicate service name '{name}'")
            names.add(name)
            current = [name, lineno, {}]
        elif line.startswith("!"):
            if current is None:
                raise ConfigError(f"line {lineno}: field before any @service")
            parts = line[1:].split(None, 1)
            fname = parts[0]
            value = parts[1].strip() if len(parts) > 1 else ""
            if fname not in FIELDS:
                raise ConfigError(f"line {lineno}: unknown field '!{fname}'")
            if fname in current[2]:
                raise ConfigError(f"line {lineno}: duplicate field '!{fname}' in service '{current[0]}'")
            if value == "":
                raise ConfigError(f"line {lineno}: !{fname} has no value")
            current[2][fname] = (value, lineno)
        else:
            raise ConfigError(f"line {lineno}: lines must start with @ (service) or ! (field)")

    if current is not None:
        finish()
    if not services:
        raise ConfigError("no services declared")
    return services


def load_config(path):
    try:
        with open(path) as f:
            return parse_config(f.read())
    except OSError as e:
        olog(f"cannot read {path}: {e}")
        sys.exit(1)
    except ConfigError as e:
        olog(f"config error: {e}")
        sys.exit(1)


# --- process management -----------------------------------------------------

def _child(svc):
    """Runs in the forked child. Never returns."""
    try:
        signal.signal(signal.SIGTERM, signal.SIG_DFL)
        signal.signal(signal.SIGINT, signal.SIG_DFL)
        os.setsid()
        if svc.scoreboard != "-":
            fd = os.open(svc.scoreboard, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
            os.dup2(fd, 1)
            os.dup2(fd, 2)
            os.close(fd)
        os.chdir(svc.cwd)
        os.setgid(svc.gid)
        os.setuid(svc.uid)
        os.execve(svc.program, [svc.program] + svc.args, svc.env)
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
    if not svc.started_once:
        svc_rule(svc)
        svc.started_once = True
    svc_log(svc, f"started (pid {pid})", "start")
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
            olog(f"reaped orphan pid {pid}")


def service_thread(svc):
    crashes = []
    while not stop_event.is_set():
        if not spawn(svc):
            break
        status = svc.exits.get()          # blocks until the reaper delivers the exit
        code = os.waitstatus_to_exitcode(status)
        svc_log(svc, f"exited with code {code}", "exit")
        if stop_event.is_set():
            svc_log(svc, "left during shutdown", "stop")
            break
        if svc.lives == "never" or (svc.lives == "on-failure" and code == 0):
            svc_log(svc, f"will not be restarted (lives: {svc.lives})", "oneshot")
            break
        now = time.monotonic()
        crashes = [t for t in crashes if now - t < CRASH_WINDOW]
        crashes.append(now)
        if len(crashes) > CRASH_LIMIT:
            svc_log(svc, f"crashed {CRASH_LIMIT} times in {CRASH_WINDOW}s, giving up", "giveup")
            break
        delay = min(svc.cooldown * 2 ** (len(crashes) - 1), MAX_BACKOFF)
        svc_log(svc, f"restarting in {delay}s", "restart")
        stop_event.wait(delay)


def shutdown(services):
    with table_lock:
        stop_event.set()
        targets = [(s, s.pid) for s in services if s.pid is not None]
    olog("shutdown requested")
    for svc, pid in targets:
        svc_log(svc, "received eviction notice", "stop")
        try:
            os.kill(pid, svc.eviction_notice)
        except ProcessLookupError:
            pass
    for svc in services:
        if svc.thread is None:
            continue
        svc.thread.join(timeout=svc.grace)
        if svc.thread.is_alive():
            with table_lock:
                if svc.pid is not None:
                    svc_log(svc, "did not leave, forced removal (SIGKILL)", "kill")
                    os.kill(svc.pid, signal.SIGKILL)
            svc.thread.join(timeout=5)


def main(argv):
    global color_on

    if argv[:1] == ["--check"]:
        path = argv[1] if len(argv) > 1 else DEFAULT_CONFIG
        services = load_config(path)
        for svc in services:
            print(f"ok: {svc.name} (mood {svc.mood}, program {svc.program}, "
                  f"args {svc.args}, lives {svc.lives}, furry {svc.amiafurry})")
        print(f"ok: {len(services)} service(s) valid")
        return 0

    path = argv[0] if argv else DEFAULT_CONFIG
    color_on = sys.stdout.isatty()
    load_memeunit()

    if os.getpid() != 1:
        olog("not running as PID 1, dev mode")

    services = load_config(path)

    threading.Thread(target=reaper, name="reaper", daemon=True).start()
    for svc in services:
        svc.thread = threading.Thread(target=service_thread, args=(svc,),
                                      name=svc.name, daemon=True)
        svc.thread.start()

    signal.signal(signal.SIGTERM, lambda *_: stop_event.set())
    signal.signal(signal.SIGINT, lambda *_: stop_event.set())
    olog(f"loaded {len(services)} service(s) from {path}")

    while not stop_event.is_set():
        time.sleep(0.2)

    shutdown(services)
    olog("exiting")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
