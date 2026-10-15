#!/bin/sh
# Builds oxinit, builds the image, boots it, and checks the serial log.
set -u
cd "$(dirname "$0")/../.."
PASS=0; FAIL=0
check() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1)); else echo "  FAIL  $1"; FAIL=$((FAIL+1)); fi
}

make -s -C memeunit
gprbuild -P oxinit_prj.gpr -q >/dev/null 2>&1
sh test/vm/build-initramfs.sh || { echo "image build failed"; exit 1; }

LOG=build/vm/boot.log
sh test/vm/run-vm.sh > "$LOG" 2>&1
RC=$?

check "kernel booted and ran /init" "grep -q 'init: pid' '$LOG'"
check "oxinit is PID 1 under the real kernel" "grep -q 'SELFTEST ok: pid 1 is oxinit' '$LOG'"
check "services started" "grep -q 'heartbeat started' '$LOG' && grep -q 'selftest started' '$LOG'"
check "control socket works inside the VM" "grep -q 'SELFTEST ok: status shows heartbeat running' '$LOG'"
check "stop and start work inside the VM" "grep -q 'SELFTEST ok: heartbeat running again' '$LOG'"
check "self-test passed" "grep -q 'SELFTEST PASS' '$LOG'"
check "shutdown powered the machine off" "grep -q 'powering off' '$LOG'"
check "no kernel panic" "! grep -q 'Kernel panic' '$LOG'"
check "QEMU exited on its own, not by timeout" "[ $RC -ne 124 ]"

echo ""
echo "Results: $PASS passed, $FAIL failed. Log: $LOG"
[ $FAIL -eq 0 ]
