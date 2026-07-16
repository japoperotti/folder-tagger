#!/bin/bash
# Folder Tagger — installer
# Auto-applies a Finder color tag to every sub-folder of a chosen folder,
# on creation, using a LaunchAgent + a tiny AppleScript app (needed so the
# background job can read TCC-protected locations once you grant it Full Disk
# Access).
#
# Usage:
#   ./install.sh "<folder to watch>" <color 1-7> ["Tag name"]
#
# Color codes (fixed by macOS): 1 Gray  2 Green  3 Purple  4 Blue
#                               5 Yellow 6 Red   7 Orange
# The tag name is just the label shown in Finder; if omitted, the English
# default for that color is used. On a non-English Mac, pass the localized
# name (e.g. "Arancio") so it reuses the system tag instead of making a new one.

set -euo pipefail

# ---- args ----------------------------------------------------------------
TARGET="${1:-}"
COLOR="${2:-}"
TAG_NAME="${3:-}"

if [ -z "$TARGET" ] || [ -z "$COLOR" ]; then
  echo "Usage: ./install.sh \"<folder to watch>\" <color 1-7> [\"Tag name\"]"
  echo "Colors: 1 Gray  2 Green  3 Purple  4 Blue  5 Yellow  6 Red  7 Orange"
  exit 1
fi

# expand ~ and resolve to an absolute path
TARGET="${TARGET/#\~/$HOME}"
if [ ! -d "$TARGET" ]; then
  echo "ERROR: folder does not exist: $TARGET" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

case "$COLOR" in
  1|2|3|4|5|6|7) ;;
  *) echo "ERROR: color must be 1-7 (got '$COLOR')" >&2; exit 1;;
esac
# If no name is given, leave it empty: autotag.py fills in the correct
# localized name for THIS Mac's language, so it reuses the native color tag.

# ---- paths ---------------------------------------------------------------
LABEL="com.coworkos.folder-tagger"
APP_NAME="FolderTagger"
INSTALL_DIR="$HOME/Library/Application Support/FolderTagger"
APP="$INSTALL_DIR/$APP_NAME.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$INSTALL_DIR/folder-tagger.log"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ Installing Folder Tagger"
echo "  watch folder : $TARGET"
echo "  color        : $COLOR (${TAG_NAME:-auto-localized})"
echo "  install dir  : $INSTALL_DIR"
echo

# ---- stop any previous instance -----------------------------------------
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

# ---- lay down files ------------------------------------------------------
mkdir -p "$INSTALL_DIR"
cp "$SRC_DIR/autotag.py" "$INSTALL_DIR/autotag.py"

cat > "$INSTALL_DIR/config.json" <<JSON
{
  "root": "$TARGET",
  "color": $COLOR,
  "tag_name": "$TAG_NAME"
}
JSON

# ---- build the AppleScript app (authorizable target for Full Disk Access) -
rm -rf "$APP"
TMP_SCPT="$(mktemp -t foldertagger).applescript"
cat > "$TMP_SCPT" <<APPLESCRIPT
do shell script "/usr/bin/python3 '$INSTALL_DIR/autotag.py'"
APPLESCRIPT
osacompile -o "$APP" "$TMP_SCPT"
rm -f "$TMP_SCPT"

# make it a background agent (no Dock icon / no window) with a stable id
PB="/usr/libexec/PlistBuddy"
INFO="$APP/Contents/Info.plist"
$PB -c "Set :CFBundleIdentifier $LABEL" "$INFO" 2>/dev/null || \
  $PB -c "Add :CFBundleIdentifier string $LABEL" "$INFO"
$PB -c "Set :CFBundleName $APP_NAME" "$INFO" 2>/dev/null || true
$PB -c "Add :LSUIElement bool true" "$INFO" 2>/dev/null || \
  $PB -c "Set :LSUIElement true" "$INFO"

# ---- LaunchAgent ---------------------------------------------------------
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/applet</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$TARGET</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLISTEOF

# ---- load it -------------------------------------------------------------
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "✓ Installed and started."
echo
echo "──────────────────────────────────────────────────────────────────────"
echo "ONE MANUAL STEP — grant Full Disk Access (required by macOS):"
echo
echo "  Without it, the background job cannot read folders inside protected"
echo "  locations (Documents, Desktop, Downloads) and nothing gets colored."
echo
echo "  1. System Settings → Privacy & Security → Full Disk Access is opening."
echo "  2. Click + , press Cmd-Shift-G, paste this path, and add the app:"
echo "       $APP"
echo "  3. Make sure its switch is ON."
echo "──────────────────────────────────────────────────────────────────────"

# open the FDA pane and reveal the app to drag in
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
open -R "$APP" 2>/dev/null || true
