# oxinit: Target Creation and Lifecycle Rules

These are the rules agreed so far. Section 7 lists what is still open.

## 1. Target creation and ordering

1. Every service must have ordering. A service must ultimately connect to a target through its dependency graph.
2. Services may create targets with `!convention`. A service can belong to one target's dependency chain while providing another target.
3. Targets establish ordering. A target can act as a synchronisation point for downstream services.
4. Multiple services may start simultaneously when their ordering conditions are satisfied.
5. Circular dependencies are invalid. A service cannot depend on a target whose activation requires that same service, directly or indirectly.
6. Targets can have special built-in behaviour. They are not limited to passive ordering.
7. oxinit has no defaults. Every field a unit needs must be written out. A missing field is a config error that names the field.

For example:

```
#fandomandreddit        (networking target)

@jellyfin               (wrapper service)
!convention #jellyfin
!obsessiveservice safe

#jellyfin               (created by the wrapper)

Dependent services
```

## 2. Target activation

A service-created target activates when its associated service satisfies the configured success condition.

**Start threshold.** A unit counts as started once it has stayed up for 0.5 seconds. This applies to targets, `!laterthan`, and `!obsessive`. The docs recommend a service stay up for 1 second, which gives the check a clear margin. The threshold is fixed in oxinit and is not a config field.

A target does not automatically activate merely because its creator exists.

You've also described delayed activation, although the exact delay syntax and timing have not yet been defined.

## 3. `!obsessiveservice` lifecycle rules

| Mode      | Target behaviour                                                                           |
| --------- | ------------------------------------------------------------------------------------------ |
| `exit`    | Remains active while the associated service is running; exiting deactivates it.            |
| `crash`   | Remains active while running and after a clean exit (`0`); a non-zero exit deactivates it. |
| `safe`    | Once the service successfully starts, its later lifecycle does not affect the target.      |
| `disable` | Do not create the target.                                                                  |

`!obsessiveservice` is required whenever `!convention` is used. There is no default.

These rules concern the target's state, not whether the underlying service should be restarted.

## 4. Dependency arguments

| Argument       | Behaviour                                                                                                                              |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `!laterthan`   | Establishes ordering after another unit, without starting it.                                                                          |
| `!earlierthan` | Establishes ordering before another unit.                                                                                              |
| `!likes`       | Ordering: waits for the referenced unit's place in the graph to resolve, unless oxinit already knows it will not start. No lifetime coupling. |
| `!obsessive`   | Ordering exactly as `!laterthan`, plus a lifetime coupling to the referenced unit (see below). |

**`!likes` (official definition).** `!likes X` adds ordering and nothing else.

- The unit waits for `X` to resolve: it boots after `X` if `X` is going to start, and waits at `X`'s ordering point if `X` is not yet known.
- If `X` is a target or a unit ordered after a target, the unit waits at that target. For example, if `@a` likes `@c`, and `@c` is `!laterthan #b`, then `@a` waits until `#b`, where `@c` starts.
- It does not couple lifetimes. If `X` dies, the unit keeps running. `X` is not restarted by `!likes`.
- If oxinit already knows `X` will not start, the unit does not wait for it.

**`!obsessive` (official definition).** `!obsessive X` adds no rules beyond ordering.

- It orders the unit after `X`, exactly as `!laterthan X` does.
- It couples the unit's lifetime to `X`. If `X` dies, the unit is killed, and its recorded reason is `dependency failed: X`. When `X` comes back, the unit restarts.
- A unit boots once every ordering condition on it is satisfied, including its `!obsessive` conditions.

For example, if `@a` is `!obsessive` on `@c`, and `@c` is `!laterthan #b`, then `@a` boots after `#b` too, because `@c` does and `@a` must wait for `@c`.

If the referenced unit is a target, the coupling does nothing, because a target is not a process. The unit boots only once that target is reached.

`!obsessive` never restarts a target. A target that becomes inactive must regain activation through its own conditions.

## 5. Target completion and service counts

- A normal target prints a finished message once its associated prerequisite services have been processed.
- `N services` counts the unique downstream services attached to a target, including indirect dependencies.
- A service reachable through multiple paths should count only once.
- The target itself is not included in N.
- Skipped services count as failures in the `success/fail/success%` report.

For example, `#fandomandreddit` has three downstream services in the chain `networkmanager → jellyfin-proxy → jellyfin-server`, so its count is 3: two jellyfin units and one network unit.

## 6. Special targets

| Target            | Purpose                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------- |
| `#inbed`          | Initial boot target. Services with no other ordering start from here.                    |
| `#fandomandreddit`| Networking target. Runs before `#hadmycoffee`.                                           |
| `#hadmycoffee`    | Boot complete. Prints `Boot complete.`, then starts the services ordered after it. Console output is suppressed afterwards. |
| `#shutdown`       | The only target that runs after boot.                                                    |
| `#networkworked`  | Example of a networking prerequisite target.                                             |
| `#jellyfin`       | Example of a service-created target.                                                     |

`#hadmycoffee` is reached once every service ordered before it has made its first start attempt. Services ordered after it start next.

## 7. Rules not yet fully specified

These still need formal definitions before implementation:

- Whether one service may create multiple targets with `!convention`.
- Whether multiple services may create the same target.
- The success condition for a service-created target: "started" (up for 0.5 seconds), or a specific exit status.
- How long activation can be delayed and how the delay is represented.
- Whether deactivating a target stops already-running dependent services.
- Whether a deactivated target may reactivate when its provider recovers.
- Whether the 0.5-second start threshold applies again when an `!obsessive` dependent restarts after its dependency returns.
- The exact semantics of `!likes` when its dependency is itself a target.

The central design rule: targets represent ordering and state, while services represent executable processes. A service can create or control a target, but targets cannot be restarted like processes.
