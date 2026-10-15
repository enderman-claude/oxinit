#!/bin/sh
# Interactive VM for hands-on testing of oxinit as PID 1.
#
# Builds oxinit and a small root filesystem with a real login on the console
# (agetty and login, root and tester accounts, a hostname, a release file, and
# the libraries those programs need, copied from the host). Boots it under
# QEMU with the console on this terminal.
#
#   sh test/vm/vm-test.sh                       # boot with test/vm/interactive.oxi
#   sh test/vm/vm-test.sh --services FILE       # your own services file
#   sh test/vm/vm-test.sh --skip-build          # reuse the last oxinit build
#   sh test/vm/vm-test.sh --run-tests          # also run ./test.sh before booting
#   sh test/vm/vm-test.sh --mem 1024 --cpus 2 --kernel /path/to/bzImage
#
# Log in as root (no password). Services: oxictl status. Shut the VM down from a
# root shell with: kill -TERM 1. Quit QEMU with Ctrl-A then X.
set -eu

cd "$(dirname "$0")/../.."
PATH="$PATH:/sbin:/usr/sbin:/bin:/usr/bin"

SERVICES=test/vm/interactive.oxi
MEM=${VM_MEM:-1024}
CPUS=${VM_CPUS:-2}
KERNEL=${KERNEL:-}
SKIP_BUILD=0
RUN_TESTS=0
ROOT=build/vm/rootfs
IMAGE=build/vm/vm-test.cpio.gz

die() { echo "vm-test: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --services)   SERVICES=$2; shift 2 ;;
    --mem)        MEM=$2; shift 2 ;;
    --cpus)       CPUS=$2; shift 2 ;;
    --kernel)     KERNEL=$2; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --run-tests)  RUN_TESTS=1; shift ;;
    -h|--help)    sed -n '2,15p' "$0"; exit 0 ;;
    *)            die "unknown option $1 (try --help)" ;;
  esac
done

# --- Preflight: fail before doing any work ----------------------------------

MISSING=""
for tool in qemu-system-x86_64 busybox agetty login ldd ldconfig cpio gzip install gprbuild make; do
  command -v "$tool" >/dev/null 2>&1 || MISSING="$MISSING $tool"
done
[ -z "$MISSING" ] || die "missing tools:$MISSING (Debian: qemu-system-x86 busybox-static util-linux login cpio gprbuild make)"

[ -f "$SERVICES" ] || die "no services file at $SERVICES"

if [ -z "$KERNEL" ]; then
  KERNEL=$(ls /boot/vmlinuz-* 2>/dev/null | sort -V | tail -1 || true)
fi
[ -n "$KERNEL" ] && [ -r "$KERNEL" ] || die "no readable kernel; pass --kernel /path/to/bzImage"

PAM_PERMIT=$(ls /usr/lib/*/security/pam_permit.so 2>/dev/null | head -1 || true)
[ -n "$PAM_PERMIT" ] || die "pam_permit.so not found (Debian: apt install libpam-modules)"

NSS_FILES=$(ldconfig -p | awk '$1 == "libnss_files.so.2" && /x86-64/ { print $NF; exit }')
[ -n "$NSS_FILES" ] || die "libnss_files.so.2 not found"

# --- Build oxinit -----------------------------------------------------------

if [ "$SKIP_BUILD" -eq 0 ]; then
  make -s -C memeunit || die "memeunit build failed"
  make -s -C memeunit test_memeunit || die "memeunit test build failed"
  gprbuild -P oxinit_prj.gpr -q || die "oxinit build failed"
  bash -n test.sh || die "test.sh has a syntax error"
  echo "vm-test: built oxinit and all test binaries"
fi

# Optional: run the whole suite before booting. Warnings only, so a failing
# test does not stop the VM from starting.
if [ "$RUN_TESTS" -eq 1 ]; then
  make -s -C memeunit test || echo "vm-test: memeunit tests failed" >&2
  ./test.sh || echo "vm-test: test.sh had failures, booting anyway" >&2
fi
[ -x bin/oxinit ] && [ -x bin/oxictl ] || die "bin/oxinit or bin/oxictl missing; run without --skip-build"

# --- Root filesystem ---------------------------------------------------------

rm -rf "$ROOT"
mkdir -p "$ROOT/bin" "$ROOT/sbin" "$ROOT/lib" "$ROOT/lib64" "$ROOT/usr/lib" \
         "$ROOT/etc/oxinit" "$ROOT/etc/pam.d" "$ROOT/proc" "$ROOT/sys" "$ROOT/dev" \
         "$ROOT/run" "$ROOT/tmp" "$ROOT/root" "$ROOT/home/tester" "$ROOT/var/log" \
         "$ROOT/var/run" "$ROOT/var/mail" "$ROOT/mnt" "$ROOT/opt" \
         "$ROOT/usr/lib/x86_64-linux-gnu/security"
chmod 1777 "$ROOT/tmp"

# Copy a host file to the same path inside the image, following symlinks.
copy_same_path() {
  cp -L --parents "$1" "$ROOT"
}

# Copy the shared libraries a host binary needs, at their own paths.
copy_deps() {
  if ldd "$1" 2>/dev/null | grep -q 'not found'; then
    die "missing shared library for $1 (see: ldd $1)"
  fi
  ldd "$1" 2>/dev/null | awk '/=>/ { print $3 } /^[[:space:]]*\// { print $1 }' |
  while read -r lib; do
    [ -n "$lib" ] && copy_same_path "$lib"
  done
  return 0
}

# Install a host binary at a fixed path inside the image, plus its libraries.
install_bin() {
  src=$1; dst=$2
  [ -n "$src" ] && [ -f "$src" ] || die "cannot find a binary for $dst"
  rm -f "$ROOT$dst"
  install -D -m 755 "$src" "$ROOT$dst"
  copy_deps "$src"
}

# busybox: one binary with applet symlinks, so /bin/sh and the usual tools exist.
BUSYBOX=$(command -v busybox)
install_bin "$BUSYBOX" /bin/busybox
for applet in $("$BUSYBOX" --list); do
  [ "$applet" = busybox ] && continue
  ln -sf busybox "$ROOT/bin/$applet"
done

# The real login path: agetty opens the console, login authenticates, sh runs.
# These come after busybox so they replace its login applet.
install_bin "$(command -v agetty)" /sbin/agetty
install_bin "$(command -v login)" /bin/login

# oxinit is PID 1, oxictl is the client.
install_bin bin/oxinit /sbin/oxinit
install_bin bin/oxictl /bin/oxictl

# dlopen()ed libraries: name service lookup and the PAM module login uses.
copy_same_path "$NSS_FILES"
copy_deps "$NSS_FILES"
copy_same_path "$PAM_PERMIT"
copy_deps "$PAM_PERMIT"

# Identity and configuration.
printf 'oxinit-vm\n' > "$ROOT/etc/hostname"

cat > "$ROOT/etc/os-release" <<'EOF'
NAME="Oxinit Test VM"
ID=oxinit
VERSION_ID="0.1"
PRETTY_NAME="Oxinit Test VM 0.1"
EOF

cat > "$ROOT/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
tester:x:1000:1000:Tester:/home/tester:/bin/sh
nobody:x:65534:65534:nobody:/:/bin/false
EOF

cat > "$ROOT/etc/group" <<'EOF'
root:x:0:
tester:x:1000:
nogroup:x:65534:
EOF

cat > "$ROOT/etc/shadow" <<'EOF'
root::0:0:99999:7:::
tester::0:0:99999:7:::
nobody:!:0:0:99999:7:::
EOF
chmod 600 "$ROOT/etc/shadow"

cat > "$ROOT/etc/nsswitch.conf" <<'EOF'
passwd: files
group: files
shadow: files
hosts: files
EOF

cat > "$ROOT/etc/login.defs" <<'EOF'
ENV_PATH        PATH=/bin:/sbin:/usr/bin:/usr/sbin
ENV_SUPATH      PATH=/sbin:/bin:/usr/sbin:/usr/bin
ENCRYPT_METHOD  SHA512
EOF

# Every login is accepted: this is a test VM, not a machine anyone else uses.
cat > "$ROOT/etc/pam.d/login" <<'EOF'
auth       required   pam_permit.so
account    required   pam_permit.so
session    required   pam_permit.so
password   required   pam_permit.so
EOF

cat > "$ROOT/etc/issue" <<'EOF'
Oxinit Test VM \n \l

EOF

cat > "$ROOT/etc/motd" <<'EOF'

  oxinit test VM. PID 1 is oxinit.
  oxictl status           list services
  kill -TERM 1            shut the VM down (from root)

EOF

cat > "$ROOT/etc/profile" <<'EOF'
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PS1='\u@\h:\w\$ '
EOF

# Login records: login expects these to exist.
: > "$ROOT/var/run/utmp"
: > "$ROOT/var/log/wtmp"
: > "$ROOT/var/log/btmp"
: > "$ROOT/var/log/lastlog"

# Services: the chosen file, plus the login prompt on the console.
cp "$SERVICES" "$ROOT/etc/oxinit/services.oxi"
cat >> "$ROOT/etc/oxinit/services.oxi" <<'EOF'

@console-login
!mood                chill
!summon              /sbin/agetty
!incant              --noclear ttyS0 115200 linux
!arena               /
!role                root
!party               root
!loadout             -
!lives               always
!cooldown            1s
!eviction-notice     TERM
!grace               2s
!scoreboard          -
!amiafurry           false
!fursona-name        -
!fursona-description -
!fursona-species     -
EOF

# /init: mount the pseudo filesystems, set the hostname, become oxinit.
cat > "$ROOT/init" <<'EOF'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
hostname -F /etc/hostname
exec /sbin/oxinit /etc/oxinit/services.oxi
EOF
chmod 755 "$ROOT/init"

# --- Image ---------------------------------------------------------------------

(cd "$ROOT" && find . | cpio -o -H newc --quiet) | gzip -1 > "$IMAGE"
echo "vm-test: image $IMAGE ($(du -h "$IMAGE" | cut -f1))"

# --- Boot ----------------------------------------------------------------------

if [ -w /dev/kvm ]; then
  echo "vm-test: booting with KVM, ${MEM} MB, ${CPUS} CPU(s)"
else
  echo "vm-test: /dev/kvm not usable, booting with software emulation (slow)"
fi
echo "vm-test: log in as root. Ctrl-A then X quits QEMU."

exec qemu-system-x86_64 \
  -accel kvm:tcg -cpu max \
  -m "$MEM" -smp "$CPUS" \
  -nographic -serial mon:stdio -no-reboot \
  -kernel "$KERNEL" -initrd "$IMAGE" \
  -append "console=ttyS0 panic=-1 init=/init loglevel=4"
