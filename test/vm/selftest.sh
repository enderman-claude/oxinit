#!/bin/sh
# Runs inside the VM as an oxinit service. Exercises the control socket,
# then asks PID 1 to shut down, which should power the machine off.
fail=0
check() {
  desc=$1; shift
  if "$@" >/dev/null 2>&1; then
    echo "SELFTEST ok: $desc"
  else
    echo "SELFTEST FAIL: $desc"
    fail=1
  fi
}

sleep 4
check "pid 1 is oxinit" test "$(cat /proc/1/comm)" = oxinit
check "status shows heartbeat running" sh -c 'oxictl status | grep -q "heartbeat: running"'
check "stop heartbeat" sh -c 'oxictl stop heartbeat | grep -q "ok: stopping"'
sleep 3
check "heartbeat stays stopped" sh -c 'oxictl status | grep -q "heartbeat: stopped"'
check "start heartbeat" sh -c 'oxictl start heartbeat | grep -q "ok: starting"'
sleep 3
check "heartbeat running again" sh -c 'oxictl status | grep -q "heartbeat: running"'
check "heartbeat output reaches its log file" test -s /var/log/heartbeat.log
check "unknown service is an error" sh -c '! oxictl stop nope'

if [ $fail -eq 0 ]; then echo "SELFTEST PASS"; else echo "SELFTEST FAIL"; fi
echo "SELFTEST powering off"
sync
kill -TERM 1
sleep 60
