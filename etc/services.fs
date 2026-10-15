\ oxinit services. Stack language: push 12 values, then say `service`.
\ Field order: name exec args cwd user group env restart backoff stop_signal stop_timeout log
\ restart is always | never | on-failure. log is an absolute path, or "-" for stdout.
"heartbeat" "/bin/sh" "-c 'while true; do echo alive; sleep 2; done'" "/" "root" "root" "" "always" 2 "TERM" 5 "-" service
"flaky" "/bin/sh" "-c 'sleep 1; exit 3'" "/" "root" "root" "" "always" 1 "TERM" 5 "-" service
"oneshot" "/bin/sh" "-c 'echo done once'" "/" "root" "root" "" "never" 0 "TERM" 5 "-" service
