#!/bin/bash
# Installs MuxFix: builds if needed, copies the kext, installs the LaunchDaemon
# and loads it. Run with sudo.
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

echo "== copying the kext to /Library/Extensions =="
rm -rf /Library/Extensions/MuxFix.kext 2>/dev/null || true
cp -R "$HERE/src/MuxFix.kext" /Library/Extensions/
chown -R root:wheel /Library/Extensions/MuxFix.kext
chmod -R 755 /Library/Extensions/MuxFix.kext

echo "== installing the LaunchDaemon =="
cp "$HERE/daemon/com.lumi.muxfix.plist" /Library/LaunchDaemons/
chown root:wheel /Library/LaunchDaemons/com.lumi.muxfix.plist
chmod 644 /Library/LaunchDaemons/com.lumi.muxfix.plist
launchctl bootout system/com.lumi.muxfix 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.lumi.muxfix.plist || true

echo "== loading the kext now =="
kmutil load -p /Library/Extensions/MuxFix.kext && echo "kext loaded" || echo "not loaded (it will load on next boot)"

cat <<'MSG'

Installed.

- If macOS asks in System Settings -> Privacy & Security, approve the extension
  and restart.
- The setting takes effect on the NEXT boot (the firmware consumes it at POST).
MSG
