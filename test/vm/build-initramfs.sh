#!/bin/sh
# Builds a minimal initramfs that boots oxinit as PID 1.
# Needs: busybox (static), cpio, gzip, and the built binaries in bin/.
# Run from the repository root.
set -eu

OUT=build/vm
ROOT=$OUT/rootfs
BUSYBOX=${BUSYBOX:-$(command -v busybox)}

rm -rf "$ROOT"
mkdir -p "$ROOT"/bin "$ROOT"/sbin "$ROOT"/etc/oxinit "$ROOT"/usr/lib/oxinit \
         "$ROOT"/proc "$ROOT"/sys "$ROOT"/dev "$ROOT"/run "$ROOT"/tmp "$ROOT"/root \
         "$ROOT"/var/log "$ROOT"/lib64 "$ROOT"/lib/x86_64-linux-gnu "$ROOT"/usr/lib/x86_64-linux-gnu

# Shell and coreutils: one static busybox with applet symlinks.
# Relative links on purpose: 'busybox --install -s' writes absolute host paths,
# which do not exist inside the image.
cp "$BUSYBOX" "$ROOT/bin/busybox"
for applet in $("$BUSYBOX" --list); do
  [ "$applet" = busybox ] && continue   # never link busybox to itself
  ln -sf busybox "$ROOT/bin/$applet"
done

# oxinit is PID 1, oxictl is the client.
cp bin/oxinit "$ROOT/sbin/oxinit"
cp bin/oxictl "$ROOT/bin/oxictl"

# Shared libraries the Ada binaries need. Copied from ldd, so it adapts to this machine.
for bin in bin/oxinit bin/oxictl; do
  ldd "$bin" | awk '/=>/ {print $3} /^[[:space:]]\// {print $1}' | while read -r lib; do
    [ -n "$lib" ] && [ -e "$lib" ] && cp -L --parents "$lib" "$ROOT"
  done
done

# Accounts: oxinit checks /etc/passwd and /etc/group for !role and !party.
printf 'root:x:0:0:root:/root:/bin/sh\nnobody:x:65534:65534:nobody:/:/bin/false\n' > "$ROOT/etc/passwd"
printf 'root:x:0:\nnogroup:x:65534:\n' > "$ROOT/etc/group"

# /init mounts the pseudo filesystems, then replaces itself with oxinit.
cat > "$ROOT/init" <<'INITEOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /run /tmp
echo "init: pid $$, handing over to oxinit"
exec /sbin/oxinit /etc/oxinit/services.oxi
INITEOF
chmod 755 "$ROOT/init"

cp test/vm/selftest.sh "$ROOT/usr/lib/oxinit/selftest.sh"
chmod 755 "$ROOT/usr/lib/oxinit/selftest.sh"
cp test/vm/services.oxi "$ROOT/etc/oxinit/services.oxi"

# Console nodes, so the kernel has stdio for PID 1 even before devtmpfs is up.
if [ "$(id -u)" -eq 0 ]; then
  [ -e "$ROOT/dev/console" ] || mknod -m 600 "$ROOT/dev/console" c 5 1
  [ -e "$ROOT/dev/null" ] || mknod -m 666 "$ROOT/dev/null" c 1 3
else
  echo "build-initramfs: not root, /dev/console will be created by devtmpfs at boot" >&2
fi

(cd "$ROOT" && find . | cpio -o -H newc --quiet) | gzip -9 > "$OUT/initramfs.cpio.gz"
echo "built $OUT/initramfs.cpio.gz ($(du -h "$OUT/initramfs.cpio.gz" | cut -f1))"
