#!/bin/bash
# Installs MuxFix. The kext must already be injected from the EFI
# (EFI/OC/Kexts/MuxFix.kext + Kernel -> Add), because macOS only loads kexts
# from /Library/Extensions when they are signed with a Developer ID Team ID.
#
# This installs:
#   - a copy of the kext in /Library/Extensions (only used as a path for kmutil)
#   - a LaunchDaemon that starts it on every boot
#
# Run with sudo.
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo:  sudo bash install.sh"
    exit 1
fi

HERE=$(cd "$(dirname "$0")" && pwd)

if [ ! -d "$HERE/src/MuxFix.kext" ]; then
    echo "== building =="
    bash "$HERE/src/build.sh"
fi

echo "== copying the kext to /Library/Extensions (path for kmutil) =="
rm -rf /Library/Extensions/MuxFix.kext 2>/dev/null || true
cp -R "$HERE/src/MuxFix.kext" /Library/Extensions/
chown -R root:wheel /Library/Extensions/MuxFix.kext
chmod -R 755 /Library/Extensions/MuxFix.kext

echo "== installing the LaunchDaemon =="
cp "$HERE/daemon/com.lumi.muxfix.plist" /Library/LaunchDaemons/
chown root:wheel /Library/LaunchDaemons/com.lumi.muxfix.plist
chmod 644 /Library/LaunchDaemons/com.lumi.muxfix.plist
launchctl bootout system/com.lumi.muxfix 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.lumi.muxfix.plist

echo "== starting the kext now =="
kmutil showloaded --list-only | grep -q com.lumi.MuxFix || \
    kmutil load -p /Library/Extensions/MuxFix.kext || true

cat <<'MSG'

Installed.

Remember: the kext must be in EFI/OC/Kexts and enabled in Kernel -> Add.
Without that, the daemon has nothing to start.

The mode takes effect on the NEXT boot (the firmware consumes it at POST).
MSG
