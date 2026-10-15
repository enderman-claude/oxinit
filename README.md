# oxinit 🦆

A PID 1 init system that is **production ready** and **not production ready** at the same time.

Spoiler: it works. It is predictable. It just dresses like it's been up all night.

## What it does (for real)

- Runs as PID 1 and reaps zombies so the process table stays clean.
- Starts every service from `/etc/oxinit/services.json`.
- Restarts crashing services with exponential backoff (2s, 4s, 8s... capped at 30s).
- Gives up after 5 crashes in 60 seconds, because even robots need a break. 🌱
- On SIGTERM or SIGINT, stops services politely, escalates to SIGKILL after 10 seconds, then exits.

## What it does not do (also for real)

- Dependency ordering. Everything starts at once, like a group chat with no admin.
- Logging rotation. Logs are just stdout, living their best unbounded life.
- Cgroups, socket activation, or any of the fancy stuff. Simplicity is a feature. Allegedly.

## Config

```json
{
  "services": [
    {"name": "web", "command": ["/usr/bin/myserver", "--port", "8080"], "restart": true},
    {"name": "backup", "command": ["/usr/local/bin/backup.sh"], "restart": false}
  ]
}
```

`restart: false` means "run once and retire, like a one-hit wonder 🎤".

## Running it

```sh
python3 oxinit.py etc/services.json      # dev mode, it knows it's not PID 1 and is fine with that
```

As PID 1 in a container or VM, pass it as the init program. Watch it reap things.

## Testing

```sh
./test.sh
```

Runs the tests inside a fresh PID namespace, so nothing outside the sandbox is harmed.

## Memes

> "It works on my machine" — every init, ever.

> "I'm not crashing, I'm restarting with style." — the `flaky` service, probably.

> "Have you tried turning it off and on again?" — oxinit, literally, in the logs.

## License

Do what you want. If it eats your PID 1, that's on you. 🙃
