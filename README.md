# oxinit

A PID 1 init that is production ready and not production ready at the same time.

It works. It is predictable. It requires you to type a lot.

## What it does

- Runs as PID 1 and reaps zombies.
- One thread per service, plus one reaper thread that owns `waitpid`.
- Restarts crashing services with a cooldown that doubles each crash, capped at 30s.
- Gives up on a service that crashes more than 5 times in 60 seconds.
- On SIGTERM or SIGINT, sends each service its eviction notice, waits its grace period, then SIGKILLs anything left.

## What it does not do

- Dependency ordering. Everything starts at once.
- Log rotation. Logs go to files or stdout.
- Cgroups, socket activation, or other serious features.

## Syntax

A config file is a list of services. Each service starts with `@name` and has exactly one line per field, in any order. Every field is required. Blank lines and lines starting with `#` are ignored.

```
@web-server
!mood                chill
!summon              /usr/bin/myserver
!incant              --port 8080
!arena               /srv/web
!role                www
!party               www
!loadout             -
!lives               always
!cooldown            2s
!eviction-notice     TERM
!grace               10s
!scoreboard          /var/log/web.log
!amiafurry           true
!fursona-name        Kestrel
!fursona-description A silver wolf who guards the web server.
!fursona-species     wolf
```

### Rules

1. The first line of each service is `@name`. The name is unique, non-empty, and has no spaces.
2. Each field line is `!field value`. The field must be in the table below.
3. Every field is required in every service. A missing field is an error that names the service and the field.
4. A field may appear only once per service. A duplicate is an error.
5. `-` means "explicitly none." It is accepted only where the table says so. Anywhere else it is an error.
6. Nothing is inferred. No PATH lookup, no default user, no default restart policy.
7. `!incant` is split the way a POSIX shell splits a command line: whitespace separates arguments, single and double quotes group them, and backslash escapes the next character. A bare, unquoted `-` means no arguments. A quoted `"-"` is the argument `-`.
8. `!incant` rejects unquoted `| & ; < > ( )`, and `$` or backtick expansion anywhere. Those are errors, not silently ignored.
9. `!amiafurry` is `true` or `false`. When it is `true`, `!fursona-name`, `!fursona-description`, and `!fursona-species` must each have a real value. When it is `false`, all three must be `-`.
10. `!mood` must be one of the nine moods below.
11. A service that crashes more than 5 times in 60 seconds is no longer restarted.

### Fields

| Field | Meaning | Rules |
|---|---|---|
| `!mood` | Visual theme for this service's output | One of the nine moods below. No `-`. |
| `!summon` | Program to run | Absolute path. No `-`. |
| `!incant` | Arguments | POSIX shell splitting (rule 7). `-` for none. |
| `!arena` | Working directory | Absolute path. No `-`. |
| `!role` | User to run as | Must be an existing account. No `-`. |
| `!party` | Group to run as | Must be an existing group. No `-`. |
| `!loadout` | Environment variables | `KEY=VALUE` pairs separated by spaces. `-` for an empty environment. |
| `!lives` | Restart policy | `always`, `never`, or `on-failure` (restart only after a nonzero exit). No `-`. |
| `!cooldown` | Base restart delay | Whole seconds with `s`, such as `2s`. Doubles after each crash, capped at 30s. `0s` for no delay. |
| `!eviction-notice` | Signal sent on shutdown | Name without `SIG`: `HUP`, `INT`, `QUIT`, `USR1`, `USR2`, or `TERM`. No `-`. |
| `!grace` | Time before forced removal | Whole seconds with `s`, such as `10s`. After this, the process gets SIGKILL. |
| `!scoreboard` | Log destination | Absolute path, or `-` for stdout. |
| `!amiafurry` | Furry flag | `true` or `false`. No `-`. No runtime effect. |
| `!fursona-name` | Fursona's name | Rule 9. |
| `!fursona-description` | Fursona's description | Rule 9. |
| `!fursona-species` | Fursona's species | Rule 9. |

### Moods

A service's `!mood` sets how the init prints lines about it. The theme is fixed, so the same mood always looks the same. Each service line starts with the prefix and the service name, and the first line of a service is preceded by a border rule.

| Mood | Color | Border | Prefix | Example line |
|---|---|---|---|---|
| `chill` | cyan | `-` | `~` | `~ web-server started (pid 412)` |
| `hyper` | bright yellow, bold | `*` | `!!` | `!! web-server started (pid 412)` |
| `grumpy` | red | `#` | `>:(` | `>:( web-server exited with code 3` |
| `sleepy` | dim blue | `.` | `zz` | `zz web-server started (pid 412)` |
| `feral` | magenta | `/\` | `>>` | `>> web-server started (pid 412)` |
| `owo` | bright magenta | `~` | `owo` | `owo web-server started (pid 412)` |
| `sus` | green | `?` | `sus` | `sus web-server started (pid 412)` |
| `blessed` | bright white on yellow | `=` | `(*)` | `(*) web-server started (pid 412)` |
| `doomed` | black on red | `x` | `RIP` | `RIP web-server exited with code 3` |

Color is used only when stdout is a terminal. Piped or saved output keeps the prefix and border but has no ANSI codes.

Plain `oxinit:` lines (boot, shutdown, config errors) have no mood and no color.

## Building

oxinit is written in Ada (GNAT). The meme unit is C and is linked in as a static archive.

```sh
make -C memeunit
gprbuild -P oxinit_prj.gpr
```

The binaries are written to `bin/oxinit` and `bin/oxictl`. There are no runtime dependencies.

## Running

Check a config without starting anything:

```sh
./bin/oxinit --check etc/services.oxi
```

Run services:

```sh
./bin/oxinit etc/services.oxi
```

As PID 1 in a container or VM, pass the config as the init program's argument. The default config path is `/etc/oxinit/services.oxi`.

## Control: oxictl

A running oxinit listens on a Unix socket at `/run/oxinit.sock`, or at `$OXINIT_SOCKET` if that is set. The socket is root-only (mode 600) and is removed on shutdown.

```sh
oxictl status          # each service: state, pid, mood, furry flag
oxictl stop NAME       # send the eviction notice, keep it down until started again
oxictl start NAME      # bring a stopped or given-up service back up
```

Exit status is 0 on success and 1 on an error reply, such as an unknown service name.

`reload` is not implemented yet. The service list is read once at startup.

## Layout

| Unit | Role |
|---|---|
| `oxinit_main.adb` | Entry point, startup, shutdown |
| `oxinit-parser` | Reads `@` and `!` lines into raw services |
| `oxinit-validate` | Checks every field and builds a service |
| `oxinit-checks` | Shared field helpers: durations, loadout, errors |
| `oxinit-shell` | POSIX-style splitting for `!incant` |
| `oxinit-config` | Loads a file into the service list |
| `oxinit-launch` | Prepares exec data and runs in the forked child |
| `oxinit-table` | Pid registry and per-service mailboxes (protected objects) |
| `oxinit-worker` | One task per service: spawn, wait, restart policy, stop and start requests |
| `oxinit-ctl_server`, `oxinit-commands`, `oxinit-socket` | Control socket: accepts oxictl requests and runs them |
| `oxictl_main.adb` | The oxictl client |
| `oxinit-reaping` | The only task that calls `waitpid` |
| `oxinit-output`, `oxinit-moods`, `oxinit-memes` | Themed output and the compiled-in memeunit |
| `oxinit-posix`, `oxinit-accounts`, `oxinit-signals` | POSIX bindings, user lookup, signal handling |

## Testing

```sh
./test.sh
```

Builds everything, runs one check per rule above, then runs an integration test inside a fresh PID namespace.

## Testing in a VM

`test/vm/` builds a bootable image and boots it under QEMU, with oxinit as PID 1 under a real kernel. The guest runs a self-test service that uses `oxictl` and then powers the machine off. The driver checks the serial log.

```sh
bash test/vm/test-vm.sh
```

Requirements: `qemu-system-x86_64`, a static `busybox`, `cpio`, `gzip`, `gprbuild`, and a Linux kernel with serial console and devtmpfs built in. The kernel defaults to the newest `/boot/vmlinuz-*`. Override it with `KERNEL=/path/to/bzImage`. The image builder copies the shared libraries from `ldd`, so it works with whatever the host provides.

Without KVM (`/dev/kvm`), QEMU uses software emulation. It is slower but gives the same result. `VM_TIMEOUT` sets the QEMU timeout, default 300 seconds.

The boot log is in `build/vm/boot.log`.

## License

Do what you want. If it eats your PID 1, that's on you.

## Manual testing in a VM

`test/vm/run-manual.sh` builds the same image as `test-vm.sh` and boots it with the serial console attached to your terminal. There is no timeout. The guest runs `test/vm/manual.oxi`, which starts a heartbeat service and a shell, so you can use `oxictl` by hand. Press Ctrl-A then X to quit QEMU.

```sh
sh test/vm/run-manual.sh
```

Requirements and the `KERNEL` override are the same as for the automated VM test.
