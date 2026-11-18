#!/bin/bash
# Removes MuxFix. Run with sudo.
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo:  sudo bash uninstall.sh"
    exit 1
fi

echo "== stopping the LaunchDaemon =="
launchctl bootout system/com.lumi.muxfix 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.lumi.muxfix.plist

echo "== unloading the kext =="
kmutil unload -p /Library/Extensions/MuxFix.kext 2>/dev/null || true

echo "== removing the kext =="
rm -rf /Library/Extensions/MuxFix.kext || {
    echo "Could not remove /Library/Extensions/MuxFix.kext (macOS protects it)."
    echo "Remove it from Recovery, or disable SIP temporarily."
}

echo "== done. Restart to apply. =="
