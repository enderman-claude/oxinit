#!/bin/sh
# Builds oxinit and the image, then boots it interactively for manual testing.
# The guest runs manual.oxi: a heartbeat service and a shell on the console.
#
#   sh test/vm/run-manual.sh
#
# Inside the guest:
#   oxictl status
#   oxictl stop heartbeat
#   oxictl start heartbeat
#
# Quit QEMU with Ctrl-A then X. To shut the guest down from inside, send
# SIGTERM to PID 1 with: kill -TERM 1
set -eu
cd "$(dirname "$0")/../.."

make -s -C memeunit
gprbuild -P oxinit_prj.gpr -q >/dev/null 2>&1
SERVICES=test/vm/manual.oxi sh test/vm/build-initramfs.sh

echo "Booting. Ctrl-A then X quits QEMU."
VM_INTERACTIVE=1 sh test/vm/run-vm.sh
