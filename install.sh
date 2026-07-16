#!/bin/bash
# Folder Tagger — installer (right-click action + watcher)
#
# Installs BOTH:
#   • a Finder right-click Quick Action "Folder Tagger" (color a folder + its
#     whole contents on demand), and
#   • a background watcher so that once you color a folder, every NEW sub-folder
#     created inside it later inherits that color automatically.
#
# Coloring a folder from the right-click menu also *registers* it with the
# watcher (registry: watches.json). "Remove color (default)" un-registers it.
#
# Usage:
#   ./install.sh                                   # set up, then use right-click
#   ./install.sh "<folder>" <color 1-7> ["name"]   # also pre-watch one folder
#
# Colors: 1 Gray  2 Green  3 Purple  4 Blue  5 Yellow  6 Red  7 Orange
# (tag name auto-localizes to your Mac's language if omitted)
#
# One manual step: grant Full Disk Access to FolderTagger.app (macOS requires it
# for a background job to read folders inside Documents/Desktop/Downloads).

set -euo pipefail

# ---- optional pre-watch args ---------------------------------------------
TARGET="${1:-}"
COLOR="${2:-}"
TAG_NAME="${3:-}"

# ---- paths ---------------------------------------------------------------
LABEL="com.coworkos.folder-tagger"
APP_NAME="FolderTagger"
INSTALL_DIR="$HOME/Library/Application Support/FolderTagger"
APP="$INSTALL_DIR/$APP_NAME.app"
APPLET="$APP/Contents/MacOS/applet"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$INSTALL_DIR/folder-tagger.log"
REGISTRY="$INSTALL_DIR/watches.json"
SERVICES="$HOME/Library/Services"
WF="$SERVICES/Folder Tagger.workflow"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ Installing Folder Tagger (right-click action + watcher)"

# ---- prerequisites -------------------------------------------------------
[ -x /usr/bin/python3 ] || { echo "❌ /usr/bin/python3 missing (xcode-select --install)"; exit 1; }
command -v osacompile >/dev/null || { echo "❌ osacompile missing"; exit 1; }

# ---- lay down the engine -------------------------------------------------
mkdir -p "$INSTALL_DIR"
cp "$SRC_DIR/autotag.py"  "$INSTALL_DIR/autotag.py"
cp "$SRC_DIR/colorize.py" "$INSTALL_DIR/colorize.py"

# pointer that tells colorize.py where the registry + agent are
cat > "$INSTALL_DIR/watcher.json" <<JSON
{ "registry": "$REGISTRY", "label": "$LABEL", "plist": "$PLIST" }
JSON

# ---- seed the registry ---------------------------------------------------
if [ -n "$TARGET" ] && [ -n "$COLOR" ]; then
  TARGET="${TARGET/#\~/$HOME}"
  [ -d "$TARGET" ] || { echo "❌ folder does not exist: $TARGET"; exit 1; }
  TARGET="$(cd "$TARGET" && pwd)"
  case "$COLOR" in 1|2|3|4|5|6|7) ;; *) echo "❌ color must be 1-7"; exit 1;; esac
  python3 - "$REGISTRY" "$TARGET" "$COLOR" "$TAG_NAME" <<'PY'
import json, os, sys
reg, root, color, name = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
items = []
if os.path.exists(reg):
    try: items = json.load(open(reg))
    except Exception: items = []
items = [it for it in items if os.path.abspath(it.get("root","")) != os.path.abspath(root)]
items.append({"root": root, "color": color, "tag_name": name})
json.dump(items, open(reg, "w"), indent=2, ensure_ascii=False)
PY
  echo "  watching: $TARGET (color $COLOR)"
elif [ ! -f "$REGISTRY" ]; then
  echo "[]" > "$REGISTRY"
fi

# ---- build the AppleScript app (authorizable Full Disk Access target) ----
rm -rf "$APP"
TMP_SCPT="$(mktemp -t foldertagger).applescript"
cat > "$TMP_SCPT" <<APPLESCRIPT
do shell script "/usr/bin/python3 '$INSTALL_DIR/autotag.py'"
APPLESCRIPT
osacompile -o "$APP" "$TMP_SCPT"
rm -f "$TMP_SCPT"
PB="/usr/libexec/PlistBuddy"; INFO="$APP/Contents/Info.plist"
$PB -c "Set :CFBundleIdentifier $LABEL" "$INFO" 2>/dev/null || $PB -c "Add :CFBundleIdentifier string $LABEL" "$INFO"
$PB -c "Set :CFBundleName $APP_NAME" "$INFO" 2>/dev/null || true
$PB -c "Add :LSUIElement bool true" "$INFO" 2>/dev/null || $PB -c "Set :LSUIElement true" "$INFO"

# ---- LaunchAgent (WatchPaths from the registry) --------------------------
WATCHPATHS_XML="$(python3 - "$REGISTRY" <<'PY'
import json, os, sys
try: items = json.load(open(sys.argv[1]))
except Exception: items = []
roots = [os.path.abspath(os.path.expanduser(it["root"])) for it in items if it.get("root")]
if roots:
    print("    <key>WatchPaths</key>\n    <array>")
    for r in roots:
        print("        <string>%s</string>" % r.replace("&","&amp;").replace("<","&lt;"))
    print("    </array>")
PY
)"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APPLET</string>
    </array>
$WATCHPATHS_XML
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
plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

# ---- right-click Quick Action --------------------------------------------
rm -rf "$WF" "$SERVICES/Colora cartella + contenuto.workflow" "$SERVICES/folder tagger.workflow"
mkdir -p "$WF/Contents"
U1="$(uuidgen)"; U2="$(uuidgen)"; U3="$(uuidgen)"
cat > "$WF/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>NSServices</key><array><dict>
        <key>NSMenuItem</key><dict><key>default</key><string>Folder Tagger</string></dict>
        <key>NSMessage</key><string>runWorkflowAsService</string>
        <key>NSRequiredContext</key><dict>
            <key>NSApplicationIdentifier</key><string>com.apple.finder</string></dict>
        <key>NSSendFileTypes</key><array><string>public.folder</string></array>
    </dict></array>
</dict></plist>
PLIST
cat > "$WF/Contents/document.wflow" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>AMApplicationBuild</key><string>523</string>
    <key>AMApplicationVersion</key><string>2.10</string>
    <key>AMDocumentVersion</key><string>2</string>
    <key>actions</key><array><dict>
        <key>action</key><dict>
            <key>AMAccepts</key><dict>
                <key>Container</key><string>List</string><key>Optional</key><true/>
                <key>Types</key><array><string>com.apple.cocoa.path</string></array></dict>
            <key>AMActionVersion</key><string>2.0.3</string>
            <key>AMApplication</key><array><string>Automator</string></array>
            <key>AMParameterProperties</key><dict>
                <key>COMMAND_STRING</key><dict/><key>CheckedForUserDefaultShell</key><dict/>
                <key>inputMethod</key><dict/><key>shell</key><dict/><key>source</key><dict/></dict>
            <key>AMProvides</key><dict>
                <key>Container</key><string>List</string>
                <key>Types</key><array><string>com.apple.cocoa.string</string></array></dict>
            <key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
            <key>ActionName</key><string>Run Shell Script</string>
            <key>ActionParameters</key><dict>
                <key>COMMAND_STRING</key><string>/usr/bin/python3 "$INSTALL_DIR/colorize.py" "\$@"</string>
                <key>CheckedForUserDefaultShell</key><true/>
                <key>inputMethod</key><integer>1</integer>
                <key>shell</key><string>/bin/zsh</string><key>source</key><string></string></dict>
            <key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
            <key>CFBundleVersion</key><string>2.0.3</string>
            <key>CanShowSelectedItemsWhenRun</key><false/>
            <key>CanShowWhenRun</key><true/>
            <key>Category</key><array><string>AMCategoryUtilities</string></array>
            <key>Class Name</key><string>RunShellScriptAction</string>
            <key>InputUUID</key><string>$U1</string>
            <key>Keywords</key><array><string>Shell</string><string>Script</string></array>
            <key>OutputUUID</key><string>$U2</string><key>UUID</key><string>$U3</string>
            <key>UnlocalizedApplications</key><array><string>Automator</string></array>
            <key>arguments</key><dict/><key>isViewVisible</key><integer>1</integer>
            <key>location</key><string>309.000000:253.000000</string>
            <key>nibName</key><string>Run Shell Script</string>
        </dict><key>isViewVisible</key><integer>1</integer>
    </dict></array>
    <key>connectors</key><dict/>
    <key>workflowMetaData</key><dict>
        <key>applicationBundleIDsByProvidedType</key><dict/><key>applicationPaths</key><array/>
        <key>inputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
        <key>outputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
        <key>presentationMode</key><integer>11</integer><key>processesInput</key><integer>0</integer>
        <key>serviceApplicationBundleID</key><string>com.apple.finder</string>
        <key>serviceApplicationPath</key><string>/System/Library/CoreServices/Finder.app</string>
        <key>serviceInputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
        <key>serviceInputTypeIdentifierIndex</key><integer>0</integer>
        <key>serviceOutputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
        <key>useAutomaticInputType</key><integer>0</integer>
        <key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict></plist>
PLIST
plutil -lint "$WF/Contents/Info.plist" >/dev/null
plutil -lint "$WF/Contents/document.wflow" >/dev/null
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "✓ Installed."
echo
echo "──────────────────────────────────────────────────────────────────────"
echo "ONE MANUAL STEP — grant Full Disk Access (needed for the watcher):"
echo "  1. System Settings → Privacy & Security → Full Disk Access (opening…)"
echo "  2. Add:  $APP"
echo "  3. Turn its switch ON."
echo
echo "Then: right-click a folder → Quick Actions → Folder Tagger → pick a color."
echo "The folder + its contents get colored, and future sub-folders inherit it."
echo "──────────────────────────────────────────────────────────────────────"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
open -R "$APP" 2>/dev/null || true
