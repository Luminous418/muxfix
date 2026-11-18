#!/bin/bash
# Removes MuxFix (daemon + /Library/Extensions copy).
# Also remove MuxFix.kext from EFI/OC/Kexts and Kernel -> Add by hand.
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo:  sudo bash uninstall.sh"
    exit 1
fi

echo "== stopping the LaunchDaemon =="
launchctl bootout system/com.lumi.muxfix 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.lumi.muxfix.plist

echo "== removing the /Library/Extensions copy =="
rm -rf /Library/Extensions/MuxFix.kext || echo "Could not remove it (macOS protects it)"

echo "== done. Restart to apply. =="
