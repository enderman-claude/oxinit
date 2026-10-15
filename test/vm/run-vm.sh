#!/bin/sh
# Boots build/vm/initramfs.cpio.gz in QEMU. Uses KVM when /dev/kvm is usable,
# otherwise software emulation (slower, same result).
#   VM_INTERACTIVE=1  no timeout; the serial console is your terminal (Ctrl-A X quits QEMU)
set -eu
cd "$(dirname "$0")/../.."

KERNEL=${KERNEL:-$(ls /boot/vmlinuz-* 2>/dev/null | sort -V | tail -1)}
[ -n "$KERNEL" ] && [ -r "$KERNEL" ] || { echo "run-vm: no readable kernel, set KERNEL=/path/to/bzImage" >&2; exit 2; }

if [ -w /dev/kvm ]; then
  ACCEL="-accel kvm -cpu host"
else
  ACCEL="-accel tcg"
  echo "run-vm: /dev/kvm not usable, using software emulation" >&2
fi

# -no-reboot: a guest reboot exits QEMU instead of looping.
# panic=-1: a kernel panic reboots at once, which -no-reboot turns into an exit.
set -- $ACCEL -m "${VM_MEM:-512}" -smp "${VM_CPUS:-1}" -nographic -no-reboot \
  -kernel "$KERNEL" -initrd build/vm/initramfs.cpio.gz \
  -append "console=ttyS0 panic=-1 init=/init loglevel=4"

if [ -n "${VM_INTERACTIVE:-}" ]; then
  exec qemu-system-x86_64 "$@"
fi
exec timeout "${VM_TIMEOUT:-300}" qemu-system-x86_64 "$@"
