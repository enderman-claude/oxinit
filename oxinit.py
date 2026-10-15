#!/usr/bin/env python3
"""oxinit: a PID 1 init that works exactly as documented.

Behaviour is deterministic: same config in, same supervision out.
Only the vibes are chaotic.
"""
import json
import os
import signal
import sys
import time

DEFAULT_CONFIG = "/etc/oxinit/services.json"
CRASH_WINDOW = 60      # seconds
CRASH_LIMIT = 5        # crashes within the window before giving up
STOP_GRACE = 10        # seconds between SIGTERM and SIGKILL

services = {}          # name -> dict(spec, pid, crash_times, next_start, given_up)
shutting_down = False


def log(msg):
    print(f"[oxinit {time.strftime('%H:%M:%S')}] {msg}", flush=True)


def load_config(path):
    with open(path) as f:
        data = json.load(f)
    result = []
    for svc in data["services"]:
        if not svc.get("name") or not svc.get("command"):
            raise ValueError(f"service needs a name and a command, you gave me this nonsense: {svc}")
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
            print(f"oxinit: {name} refused to wake up ({e}). Sad. 404 process not found.",
                  file=sys.stderr, flush=True)
            os._exit(127)
    s["pid"] = pid
    log(f"{name} has entered the chat (pid {pid}) 🎉")


def handle_exit(pid, status):
    name = next((n for n, s in services.items() if s.get("pid") == pid), None)
    if name is None:
        return  # an orphan we adopted, already reaped, not our problem
    s = services[name]
    s["pid"] = None
    if shutting_down:
        log(f"{name} has left the chat. Bye bye 👋")
        return
    code = os.waitstatus_to_exitcode(status)
    log(f"{name} exited with code {code}. This is fine. 🔥🐶☕")
    if not s["restart"]:
        s["given_up"] = True
        log(f"{name} is a one-hit wonder, not restarting. Respect. 🎤")
        return
    now = time.monotonic()
    s["crash_times"] = [t for t in s["crash_times"] if now - t < CRASH_WINDOW]
    s["crash_times"].append(now)
    if len(s["crash_times"]) > CRASH_LIMIT:
        s["given_up"] = True
        log(f"{name} crashed {CRASH_LIMIT} times in {CRASH_WINDOW}s. Touch grass. "
            f"Giving up. 🌱")
        return
    delay = min(2 ** len(s["crash_times"]), 30)
    s["next_start"] = now + delay
    log(f"restarting {name} in {delay}s. Have you tried turning it off and on again? 🔌")


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
        log("you already pressed it. I heard you the first time. 😤")
        return
    shutting_down = True
    log("shutdown requested. Everybody out of the pool. 🏊")
    for name, s in services.items():
        if s["pid"] is not None:
            log(f"asking {name} politely to leave (SIGTERM) 🙏")
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
            log(f"{name} ignored us. Escalating to SIGKILL. Not personal. 💀")
            try:
                os.kill(s["pid"], signal.SIGKILL)
            except ProcessLookupError:
                pass
    for _ in range(50):
        reap()
        time.sleep(0.05)


def main():
    config_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CONFIG

    if os.getpid() != 1:
        log("I am not PID 1. I'm just a normal process pretending. Dev mode engaged 🎭")

    try:
        specs = load_config(config_path)
    except (OSError, ValueError, KeyError) as e:
        log(f"could not load {config_path}: {e}. Your config is cooked. 🍳")
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
    log(f"loaded {len(services)} service(s) from {config_path}. Assembling the squad 🦸")

    while not shutting_down:
        reap()
        supervise()
        time.sleep(0.2)

    log("oxinit exiting. It's not you, it's me. 👋")


if __name__ == "__main__":
    main()
