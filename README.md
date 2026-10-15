# oxinit

A PID 1 init that is production ready and not production ready at the same time.

It works. It is predictable. It dresses like it hasn't slept since the Gold Rush update.

## What it does

- Runs as PID 1 and reaps zombies.
- Starts every service from `/etc/oxinit/services.json`.
- Restarts crashing services with exponential backoff (2s, 4s, 8s, capped at 30s).
- Gives up after 5 crashes in 60 seconds. Soldiers rocket-jump back, but there are limits.
- On SIGTERM or SIGINT, asks services to leave, escalates to SIGKILL after 10 seconds, exits.

## What it does not do

- Dependency ordering. Everything starts at once, like a Meet the Team reel with no cuts.
- Log rotation. Logs are stdout, living their best unbounded life.
- Cgroups, socket activation, or anything else serious. Simplicity is a feature. Allegedly.

## The memeunit

The memes live in `memeunit/memeunit.c`, compiled into `libmemeunit.so` and loaded at boot. oxinit refuses to start without it. The memes are load-bearing.

Each event key picks a line from its table by hashing the service name, so the same service always gets the same joke. Predictable chaos. Build with `make` in `memeunit/`.

## Config

```json
{
  "services": [
    {"name": "web", "command": ["/usr/bin/myserver", "--port", "8080"], "restart": true},
    {"name": "backup", "command": ["/usr/local/bin/backup.sh"], "restart": false}
  ]
}
```

`restart: false` makes a run-once service, like a Sniper with one clean headshot.

## Running

```sh
make -C memeunit
python3 oxinit.py etc/services.json
```

As PID 1 in a container or VM, pass it as the init program.

## Testing

```sh
./test.sh
```

Runs the integration test inside a fresh PID namespace, so nothing outside the sandbox gets hurt.

## References

> "It works on my machine." Every init, ever.

> "I'm not crashing, I'm respawning." The `flaky` service, probably.

> "Have you tried turning it off and on again?" Engineer, and oxinit, in the logs.

> "uwu, your service crashed." Furry-approved error reporting.

## License

Do what you want. If it eats your PID 1, that's on you.
