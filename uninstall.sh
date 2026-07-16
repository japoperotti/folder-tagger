#!/bin/bash
# Folder Tagger — uninstaller. Removes the LaunchAgent, the app and its files.
# Does NOT remove color tags already applied to your folders (harmless; you can
# clear them from Finder → right-click → Tags if you want).
set -uo pipefail

LABEL="com.coworkos.folder-tagger"
INSTALL_DIR="$HOME/Library/Application Support/FolderTagger"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
QUICK_ACTION="$HOME/Library/Services/Folder Tagger.workflow"

echo "→ Uninstalling Folder Tagger"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && echo "  stopped agent" || echo "  agent was not running"
rm -f "$PLIST"           && echo "  removed LaunchAgent plist"
rm -rf "$INSTALL_DIR"    && echo "  removed app + files"
if [ -d "$QUICK_ACTION" ]; then
  rm -rf "$QUICK_ACTION"
  /System/Library/CoreServices/pbs -flush 2>/dev/null || true
  echo "  removed right-click Quick Action"
fi
echo "✓ Done."
echo
echo "Optional: remove the app from System Settings → Privacy & Security →"
echo "Full Disk Access (select FolderTagger and click −)."
