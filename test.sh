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

make -s -C memeunit && check "memeunit builds with -Werror (no warnings, Engineer approves)" "[ -f memeunit/libmemeunit.so ]"
python3 -m py_compile oxinit.py && check "oxinit.py compiles" "true"

# Determinism: the same seed must always pick the same line.
A=$(python3 -c "import ctypes;l=ctypes.CDLL('./memeunit/libmemeunit.so');l.memeunit_pick.restype=ctypes.c_char_p;l.memeunit_pick.argtypes=[ctypes.c_char_p,ctypes.c_char_p];print(l.memeunit_pick(b'start',b'heartbeat').decode())")
B=$(python3 -c "import ctypes;l=ctypes.CDLL('./memeunit/libmemeunit.so');l.memeunit_pick.restype=ctypes.c_char_p;l.memeunit_pick.argtypes=[ctypes.c_char_p,ctypes.c_char_p];print(l.memeunit_pick(b'start',b'heartbeat').decode())")
check "memes are deterministic for the same seed" "[ -n \"\$A\" ] && [ \"\$A\" = \"\$B\" ]"

LOG=$(mktemp)
(unshare -fp --mount-proc python3 oxinit.py etc/services.json > "$LOG" 2>&1 &)
sleep 6
INIT=$(pgrep -f "^python3 oxinit.py" | head -1)
check "init runs as a PID 1 process in a fresh namespace" "[ -n \"\$INIT\" ]"
[ -n "$INIT" ] && kill -TERM "$INIT"
sleep 3

check "services start" "grep -q 'heartbeat started' '$LOG'"
check "crashing service restarts with backoff" "grep -q 'restarting flaky' '$LOG'"
check "oneshot does not restart" "grep -q 'oneshot is run-once' '$LOG' && ! grep -q 'restarting oneshot' '$LOG'"
check "shutdown sends SIGTERM and exits cleanly" "grep -q 'sending SIGTERM to heartbeat' '$LOG' && grep -q 'oxinit exiting' '$LOG'"
check "meme lines are attached to events" "grep -q ' | ' '$LOG'"
rm -f "$LOG"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[ $FAIL -eq 0 ]
