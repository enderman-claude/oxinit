#!/usr/bin/env python3
"""oxinit: a PID 1 init that works exactly as documented.

Behaviour is deterministic: same config in, same supervision out.
Only the memes are chaotic, and even those are seeded by the service name.
"""
import ctypes
import json
import os
import signal
import sys
import time

DEFAULT_CONFIG = "/etc/oxinit/services.json"
MEMEUNIT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "memeunit", "libmemeunit.so")
CRASH_WINDOW = 60      # seconds
CRASH_LIMIT = 5        # crashes within the window before giving up
STOP_GRACE = 10        # seconds between SIGTERM and SIGKILL

services = {}          # name -> dict(spec, pid, crash_times, next_start, given_up)
shutting_down = False
_memeunit = None


def load_memeunit():
    """Load the compiled-in meme unit. Refuse to boot without it: the memes are load-bearing."""
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


def load_config(path):
    with open(path) as f:
        data = json.load(f)
    result = []
    for svc in data["services"]:
        if not svc.get("name") or not svc.get("command"):
            raise ValueError(f"service needs a name and a command: {svc}")
        result.append({
            "name": svc["name"],
            "command": list(svc["command"]),
            "restart": bool(svc.get("restart", True)),
        })
    return result


def spawn(name):
    s = services[name]
    pid = os.fork()
    if pid == 0:
        try:
            signal.signal(signal.SIGTERM, signal.SIG_DFL)
            signal.signal(signal.SIGINT, signal.SIG_DFL)
            os.setsid()
            os.execvp(s["command"][0], s["command"])
        except Exception as e:
            print(f"oxinit: {name} failed to exec: {e}", file=sys.stderr, flush=True)
            os._exit(127)
    s["pid"] = pid
    log(f"{name} started (pid {pid})", "start", name)


def handle_exit(pid, status):
    name = next((n for n, s in services.items() if s.get("pid") == pid), None)
    if name is None:
        return  # an orphan we adopted, already reaped
    s = services[name]
    s["pid"] = None
    if shutting_down:
        log(f"{name} exited during shutdown", "stop", name)
        return
    code = os.waitstatus_to_exitcode(status)
    log(f"{name} exited with code {code}", "exit", name)
    if not s["restart"]:
        s["given_up"] = True
        log(f"{name} is run-once, not restarting", "oneshot", name)
        return
    now = time.monotonic()
    s["crash_times"] = [t for t in s["crash_times"] if now - t < CRASH_WINDOW]
    s["crash_times"].append(now)
    if len(s["crash_times"]) > CRASH_LIMIT:
        s["given_up"] = True
        log(f"{name} crashed {CRASH_LIMIT} times in {CRASH_WINDOW}s, giving up",
            "giveup", name)
        return
    delay = min(2 ** len(s["crash_times"]), 30)
    s["next_start"] = now + delay
    log(f"restarting {name} in {delay}s", "restart", name)


def reap():
    while True:
        try:
            pid, status = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return
        if pid == 0:
            return
        handle_exit(pid, status)


def supervise():
    now = time.monotonic()
    for name, s in services.items():
        if s["pid"] is None and not s["given_up"] and not shutting_down:
            if now >= s["next_start"]:
                spawn(name)


def shutdown(*_):
    global shutting_down
    if shutting_down:
        log("shutdown already in progress")
        return
    shutting_down = True
    log("shutdown requested")
    for name, s in services.items():
        if s["pid"] is not None:
            log(f"sending SIGTERM to {name}", "stop", name)
            try:
                os.kill(s["pid"], signal.SIGTERM)
            except ProcessLookupError:
                pass
    deadline = time.monotonic() + STOP_GRACE
    while time.monotonic() < deadline:
        reap()
        if all(s["pid"] is None for s in services.values()):
            break
        time.sleep(0.1)
    for name, s in services.items():
        if s["pid"] is not None:
            log(f"{name} ignored SIGTERM, sending SIGKILL", "kill", name)
            try:
                os.kill(s["pid"], signal.SIGKILL)
            except ProcessLookupError:
                pass
    for _ in range(50):
        reap()
        time.sleep(0.05)


def main():
    config_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG
    load_memeunit()

    if os.getpid() != 1:
        log("not running as PID 1, dev mode")

    try:
        specs = load_config(config_path)
    except (OSError, ValueError, KeyError) as e:
        log(f"could not load {config_path}: {e}")
        sys.exit(1)

    for spec in specs:
        services[spec["name"]] = {
            "command": spec["command"],
            "restart": spec["restart"],
            "pid": None,
            "crash_times": [],
            "next_start": 0.0,
            "given_up": False,
        }

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    log(f"loaded {len(services)} service(s) from {config_path}")

    while not shutting_down:
        reap()
        supervise()
        time.sleep(0.2)

    log("oxinit exiting")


if __name__ == "__main__":
    main()
