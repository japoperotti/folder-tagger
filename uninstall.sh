#!/bin/bash
# Folder Tagger — uninstaller. Removes the LaunchAgent, the app and its files.
# Does NOT remove color tags already applied to your folders (harmless; you can
# clear them from Finder → right-click → Tags if you want).
set -uo pipefail

LABEL="com.foldertagger.watcher"
INSTALL_DIR="$HOME/Library/Application Support/Folder Tagger"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
QUICK_ACTION="$HOME/Library/Services/Folder Tagger.workflow"

echo "→ Uninstalling Folder Tagger"

# current + any legacy agents/dirs from earlier versions
for L in "$LABEL" com.coworkos.folder-tagger com.japo.cowork-autotag; do
  launchctl bootout "gui/$(id -u)/$L" 2>/dev/null && echo "  stopped agent $L" || true
  rm -f "$HOME/Library/LaunchAgents/$L.plist"
done
for D in "$INSTALL_DIR" "$HOME/Library/Application Support/FolderTagger" "$HOME/Library/Application Support/CoworkAutotag"; do
  [ -e "$D" ] && rm -rf "$D" && echo "  removed $D"
done
if [ -d "$QUICK_ACTION" ]; then
  rm -rf "$QUICK_ACTION"
  /System/Library/CoreServices/pbs -flush 2>/dev/null || true
  echo "  removed right-click Quick Action"
fi
echo "✓ Done."
echo
echo "Optional: remove the app from System Settings → Privacy & Security →"
echo "Full Disk Access (select FolderTagger and click −)."
