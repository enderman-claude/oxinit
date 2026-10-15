#!/bin/bash
# Test suite. Deterministic. Every rule in the spec has a test.
set -u
cd "$(dirname "$0")"
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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

# A valid service with every field present. Tests mutate copies of it with sed.
base_svc() {
cat <<'EOF'
@web-server
!mood                chill
!summon              /bin/sh
!incant              -c 'true'
!arena               /
!role                root
!party               root
!loadout             -
!lives               never
!cooldown            0s
!eviction-notice     TERM
!grace               5s
!scoreboard          -
!amiafurry           false
!fursona-name        -
!fursona-description -
!fursona-species     -
EOF
}

# Run --check on a file, capture output and exit code.
run_check() { OUT=$(python3 oxinit.py --check "$1" 2>&1); RC=$?; }

echo "Running oxinit tests. Hold your breath, MEDIC is on standby."
make -s -C memeunit && check "memeunit builds with -Werror" "[ -f memeunit/libmemeunit.so ]"

base_svc > "$TMP/base.oxi"
run_check "$TMP/base.oxi"
check "a complete service passes" "[ \$RC -eq 0 ]"

check "bundled example config passes" "python3 oxinit.py --check etc/services.oxi >/dev/null 2>&1"

base_svc | sed 's/^!mood .*/!mood nope/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "unknown mood is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'unknown mood'"

base_svc | sed '/^!mood /d' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "missing field is rejected and named" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'missing !mood'"

{ base_svc; echo "!mood chill"; } > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "duplicate field is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q \"duplicate field '!mood'\""

{ base_svc; echo "!bogus yes"; } > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "unknown field is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q \"unknown field '!bogus'\""

base_svc | sed 's/^!summon .*/!summon sh/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "relative summon path is rejected (no PATH lookup)" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'absolute'"

base_svc | sed 's/^!role .*/!role nobody_xyz_123/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "unknown user is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'no such user'"

base_svc | sed 's/^!lives .*/!lives -/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "dash is rejected where the table forbids it" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q \"'-' is not allowed\""

base_svc | sed 's/^!eviction-notice .*/!eviction-notice SIGTERM/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "signal name with SIG prefix is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'without SIG'"

base_svc | sed 's/^!cooldown .*/!cooldown 2/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "duration without s is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'whole seconds'"

base_svc | sed 's/^!incant .*/!incant echo hi | cat/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "pipe in !incant is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q \"unquoted '|'\""

base_svc | sed 's/^!incant .*/!incant echo $HOME/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "variable expansion in !incant is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'expansion'"

base_svc | sed 's/^!incant .*/!incant "unclosed/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "unterminated quote in !incant is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'unterminated'"

base_svc | sed 's/^!incant .*/!incant -/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "bare dash in !incant means no arguments" "echo \"\$OUT\" | grep -q 'args \\[\\]'"

base_svc | sed 's/^!incant .*/!incant "-"/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "quoted dash in !incant is a real argument" "echo \"\$OUT\" | grep -q \"args \\['-'\\]\""

base_svc | sed "s/^!incant .*/!incant -c 'echo \"two words\"'/" > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "!incant follows POSIX quoting (nested quotes kept)" "echo \"\$OUT\" | grep -q \"args \\['-c', 'echo \\\\\\\"two words\\\\\\\"'\\]\""

base_svc | sed 's/^!mood .*/!mood owo/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "owo is an allowed mood" "[ \$RC -eq 0 ]"

base_svc | sed 's/^!loadout .*/!loadout FOO/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "loadout entry without = is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'not KEY=VALUE'"

base_svc | sed 's/^!amiafurry .*/!amiafurry true/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "amiafurry true requires fursona fields" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'required when !amiafurry is true'"

base_svc | sed 's/^!amiafurry .*/!amiafurry yes/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "amiafurry only accepts true or false" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'true or false'"

base_svc | sed 's/^!fursona-name .*/!fursona-name Kestrel/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "fursona fields must be - when amiafurry is false" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'must be - when'"

base_svc | sed -e 's/^!amiafurry .*/!amiafurry true/' -e 's/^!fursona-name .*/!fursona-name Kestrel/' -e 's/^!fursona-description .*/!fursona-description A silver wolf./' -e 's/^!fursona-species .*/!fursona-species wolf/' > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "amiafurry true with full fursona passes" "[ \$RC -eq 0 ]"

{ base_svc; echo; echo "@web-server"; base_svc | tail -n +2; } > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "duplicate service name is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'duplicate service name'"

echo "!mood chill" > "$TMP/t.oxi"; run_check "$TMP/t.oxi"
check "a field before any service is rejected" "[ \$RC -eq 1 ] && echo \"\$OUT\" | grep -q 'before any @service'"

# Integration: run as PID 1 in a fresh PID namespace, then send SIGTERM.
LOG="$TMP/run.log"
(unshare -fp --mount-proc python3 oxinit.py etc/services.oxi > "$LOG" 2>&1 &)
sleep 6
INIT=$(pgrep -f "^python3 oxinit.py etc/services.oxi" | head -1)
check "init runs as a process in a fresh PID namespace" "[ -n \"\$INIT\" ]"
[ -n "$INIT" ] && kill -TERM "$INIT"
sleep 4

check "all services start" "grep -q 'heartbeat started' '$LOG' && grep -q 'flaky started' '$LOG'"
check "crashing service restarts with cooldown" "grep -q 'flaky restarting in' '$LOG'"
check "lives: never service is not restarted" "grep -q 'oneshot will not be restarted' '$LOG' && ! grep -q 'oneshot restarting' '$LOG'"
check "shutdown sends the eviction notice" "grep -q 'heartbeat received eviction notice' '$LOG'"
check "service lines use the mood prefix" "grep -q '^~ heartbeat' '$LOG' && grep -q '^>:( flaky' '$LOG'"
check "oxinit exits cleanly" "grep -q '^oxinit: exiting' '$LOG'"

echo ""
echo "Results: $PASS passed, $FAIL failed."
[ $FAIL -eq 0 ]
