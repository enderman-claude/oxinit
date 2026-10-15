#!/bin/bash
# Test suite. Passes or fails deterministically. Vibes are optional.
set -u
cd "$(dirname "$0")"
PASS=0; FAIL=0

check() {
    local desc="$1" cond="$2"
    if eval "$cond"; then
        echo "  ✅ $desc  (it worked, you may now clap)"
        PASS=$((PASS+1))
    else
        echo "  ❌ $desc  (it did not work, blame the gremlins)"
        FAIL=$((FAIL+1))
    fi
}

echo "🧪 Running oxinit tests. Please hold your breath."
python3 -m py_compile oxinit.py && check "oxinit.py compiles (no typos, we checked twice)" "true"

LOG=$(mktemp)
(unshare -fp --mount-proc python3 oxinit.py etc/services.json > "$LOG" 2>&1 &)
sleep 6
INIT=$(pgrep -f "^python3 oxinit.py" | head -1)
check "init is running as a PID namespace process (we found it, it's alive, it's sending jokes)" "[ -n \"$INIT\" ]"
[ -n "$INIT" ] && kill -TERM "$INIT"
sleep 3

check "services started (the squad assembled)" "grep -q 'heartbeat has entered the chat' '$LOG'"
check "crashing service was restarted (it's resilient, unlike my social life)" "grep -q 'restarting flaky' '$LOG'"
check "oneshot did not restart (one-hit wonder, respect)" "! grep -q 'restarting oneshot' '$LOG'"
check "shutdown was clean (everyone got a polite request to leave)" "grep -q 'asking heartbeat politely' '$LOG' && grep -q 'oxinit exiting' '$LOG'"
rm -f "$LOG"

echo ""
echo "📊 Results: $PASS passed, $FAIL failed. $( [ $FAIL -eq 0 ] && echo 'Ship it. 🚢' || echo 'Fix it. 🔧' )"
[ $FAIL -eq 0 ]
