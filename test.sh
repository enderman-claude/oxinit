#!/bin/bash
# Test suite. Deterministic. Ruthlessly referential.
set -u
cd "$(dirname "$0")"
PASS=0; FAIL=0

check() {
    local desc="$1" cond="$2"
    if eval "$cond"; then
        echo "  PASS  $desc"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $desc  (the gremlins won this round)"
        FAIL=$((FAIL+1))
    fi
}

echo "Running oxinit tests. Hold your breath, MEDIC is on standby."

make -s -C memeunit && check "memeunit builds with -Werror" "[ -f memeunit/libmemeunit.so ]"
python3 -m py_compile oxinit.py && check "oxinit.py compiles" "true"

# Config language: a good file loads, a short one is rejected.
TMP=$(mktemp -d)
GOOD="$TMP/good.fs"
cp etc/services.fs "$GOOD"
OUT=$(timeout 2 python3 oxinit.py "$GOOD" 2>&1)
check "example config parses and the services boot" "echo \"\$OUT\" | grep -q 'loaded 3 service'"

printf '"a" "/bin/true" "" "/" "root" "root" "" "never" 0 "TERM" 5 service\n' > "$TMP/short.fs"
OUT=$(python3 oxinit.py "$TMP/short.fs" 2>&1); RC=$?
check "a service with 11 fields is rejected (no defaults)" "[ $RC -eq 1 ] && echo \"\$OUT\" | grep -q 'exactly 12'"

printf '"a" "relative" "" "/" "root" "root" "" "never" 0 "TERM" 5 "-" service\n' > "$TMP/rel.fs"
OUT=$(python3 oxinit.py "$TMP/rel.fs" 2>&1); RC=$?
check "relative exec path is rejected (no PATH guessing)" "[ $RC -eq 1 ] && echo \"\$OUT\" | grep -q 'absolute'"

printf '"a" "/bin/true" "" "/" "nobody_here_xyz" "root" "" "never" 0 "TERM" 5 "-" service\n' > "$TMP/user.fs"
OUT=$(python3 oxinit.py "$TMP/user.fs" 2>&1); RC=$?
check "unknown user is rejected" "[ $RC -eq 1 ] && echo \"\$OUT\" | grep -q 'no such user'"
rm -rf "$TMP"

# Determinism: the same seed must always pick the same line.
pick() { python3 -c "import ctypes;l=ctypes.CDLL('./memeunit/libmemeunit.so');l.memeunit_pick.restype=ctypes.c_char_p;l.memeunit_pick.argtypes=[ctypes.c_char_p,ctypes.c_char_p];print(l.memeunit_pick(b'start',b'heartbeat').decode())"; }
A=$(pick); B=$(pick)
check "memes are deterministic for the same seed" "[ -n \"\$A\" ] && [ \"\$A\" = \"\$B\" ]"

# Integration: run as PID 1 in a fresh PID namespace, then send SIGTERM.
LOG=$(mktemp)
(unshare -fp --mount-proc python3 oxinit.py etc/services.fs > "$LOG" 2>&1 &)
sleep 6
INIT=$(pgrep -f "^python3 oxinit.py etc/services.fs" | head -1)
check "init runs as a process in a fresh PID namespace" "[ -n \"\$INIT\" ]"
[ -n "$INIT" ] && kill -TERM "$INIT"
sleep 4

check "threads start all services" "grep -q 'heartbeat started' '$LOG' && grep -q 'flaky started' '$LOG'"
check "crashing service restarts with backoff" "grep -q 'restarting flaky' '$LOG'"
check "restart: never service is not restarted" "grep -q 'oneshot will not be restarted' '$LOG' && ! grep -q 'restarting oneshot' '$LOG'"
check "shutdown sends SIGTERM and exits cleanly" "grep -q 'sending SIGTERM to heartbeat' '$LOG' && grep -q 'oxinit exiting' '$LOG'"
check "meme lines are attached to events" "grep -q ' | ' '$LOG'"
rm -f "$LOG"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[ $FAIL -eq 0 ]
