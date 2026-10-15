#!/bin/sh
# Interactive VM for hands-on testing. Builds oxinit and a root filesystem that
# looks like a small machine (hostname, release file, login banner, a regular
# user), then boots it under QEMU with the console on this terminal.
#
#   sh test/vm/vm-test.sh                       # default services (manual.oxi)
#   sh test/vm/vm-test.sh --services FILE       # your own service file
#   sh test/vm/vm-test.sh --mem 1024 --cpus 2   # more resources
#   sh test/vm/vm-test.sh --kernel /path/bzImage
#
# Inside the VM, root has a shell on the console and tester has an account.
# Use oxictl to control services. Quit QEMU with Ctrl-A then X.
set -eu
cd "$(dirname "$0")/../.."

SERVICES=test/vm/manual.oxi
export VM_MEM=${VM_MEM:-1024}
export VM_CPUS=${VM_CPUS:-2}

while [ $# -gt 0 ]; do
  case "$1" in
    --services) SERVICES=$2; shift 2 ;;
    --mem)      VM_MEM=$2; export VM_MEM; shift 2 ;;
    --cpus)     VM_CPUS=$2; export VM_CPUS; shift 2 ;;
    --kernel)   KERNEL=$2; export KERNEL; shift 2 ;;
    -h|--help)  sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "vm-test: unknown option $1 (try --help)" >&2; exit 2 ;;
  esac
done

[ -f "$SERVICES" ] || { echo "vm-test: no service file at $SERVICES" >&2; exit 2; }

make -s -C memeunit
gprbuild -P oxinit_prj.gpr -q >/dev/null 2>&1 || { echo "vm-test: build failed" >&2; exit 1; }

# Extra root filesystem files, laid over the base image.
EXTRA=build/vm/extra-rootfs
rm -rf "$EXTRA"
mkdir -p "$EXTRA/etc" "$EXTRA/root" "$EXTRA/home/tester"

printf 'oxinit-vm\n' > "$EXTRA/etc/hostname"

cat > "$EXTRA/etc/os-release" <<'OSR'
NAME="Oxinit Test VM"
ID=oxinit
VERSION="0.1"
PRETTY_NAME="Oxinit Test VM 0.1"
OSR

cat > "$EXTRA/etc/motd" <<'MOTD'

  oxinit test VM
  PID 1 is oxinit. Services: oxictl status
  Quit QEMU: Ctrl-A then X

MOTD

cat > "$EXTRA/etc/passwd" <<'PW'
root:x:0:0:root:/root:/bin/sh
tester:x:1000:1000:Tester:/home/tester:/bin/sh
nobody:x:65534:65534:nobody:/:/bin/false
PW

cat > "$EXTRA/etc/group" <<'GR'
root:x:0:
tester:x:1000:
nogroup:x:65534:
GR

cat > "$EXTRA/root/.profile" <<'RP'
echo "Logged in as root on $(cat /etc/hostname)."
RP

cat > "$EXTRA/home/tester/.profile" <<'TP'
echo "Logged in as tester. Your home is /home/tester."
TP

echo "vm-test: building image with services from $SERVICES"
SERVICES="$SERVICES" EXTRA_ROOTFS="$EXTRA" sh test/vm/build-initramfs.sh

echo "vm-test: booting ${VM_MEM} MB, ${VM_CPUS} CPU(s). Ctrl-A then X quits QEMU."
VM_INTERACTIVE=1 sh test/vm/run-vm.sh
