# oxinit

A PID 1 init that is production ready and not production ready at the same time.

It works. It is predictable. It requires you to type a lot.

## What it does

- Runs as PID 1 and reaps zombies.
- One thread per service, plus one reaper thread that owns `waitpid`.
- Restarts crashing services with backoff (base delay per service, doubled each crash, capped at 30s).
- Gives up after 5 crashes in 60 seconds.
- On SIGTERM or SIGINT, sends each service its own stop signal, waits its stop timeout, then SIGKILLs anything left.

## What it does not do

- Dependency ordering. Everything starts at once, like a Meet the Team reel with no cuts.
- Log rotation. Logs are files or stdout, living their best unbounded life.
- Cgroups, socket activation, or anything else serious.

## Config: no defaults, twelve fields, one stack

Config lives in `/etc/oxinit/services.fs` and is written in a small stack language. You push values, then say `service`. Each service needs exactly 12 values, in this order:

| # | Field         | Type                                 | Notes                                     |
|---|---------------|--------------------------------------|-------------------------------------------|
| 1 | name          | string                               | unique, non-empty                         |
| 2 | exec          | string                               | absolute path, no PATH lookup             |
| 3 | args          | string                               | split with shell rules, becomes argv[1:]  |
| 4 | cwd           | string                               | absolute path                             |
| 5 | user          | string                               | must exist                                |
| 6 | group         | string                               | must exist                                |
| 7 | env           | string                               | `KEY=VALUE` pairs, `""` for an empty env |
| 8 | restart       | `always` / `never` / `on-failure`    |                                           |
| 9 | backoff       | integer                              | base seconds, `0` for none                |
| 10 | stop_signal  | string                               | e.g. `"TERM"`                             |
| 11 | stop_timeout | integer                              | seconds before SIGKILL                    |
| 12 | log          | string                               | absolute path, or `"-"` for stdout        |

Example:

```
\ comments start with backslash-space
"web" "/usr/bin/myserver" "--port 8080" "/srv/web" "www" "www" "" "always" 2 "TERM" 10 "/var/log/web.log" service
```

Literals are double-quoted strings or bare integers. Anything else is an error that tells you the line number.

## Memes

The memes live in `memeunit/memeunit.c`, compiled into `libmemeunit.so` and loaded at boot. oxinit refuses to start without it. Each event key picks a line by hashing the service name, so the same service always gets the same joke. Build with `make -C memeunit`.

## Running

```sh
make -C memeunit
python3 oxinit.py etc/services.fs
```

As PID 1 in a container or VM, pass it as the init program.

## Testing

```sh
./test.sh
```

Runs config validation tests, then an integration test inside a fresh PID namespace.

## References

> "It works on my machine." Every init, ever.

> "I'm not crashing, I'm respawning." The `flaky` service, probably.

> "Have you tried turning it off and on again?" Engineer, and oxinit, in the logs.

> "No defaults here, sweetie." The config parser, to your 11th field.

## License

Do what you want. If it eats your PID 1, that's on you.
