#!/bin/bash
# Folder Tagger — installer dell'Azione Rapida (tasto destro nel Finder)
# Aggiunge al menu contestuale delle cartelle: "Colora cartella + contenuto".
# Selezioni una o piu' cartelle, scegli un colore, e l'intero albero viene colorato.
#
# Nessuna dipendenza: /usr/bin/python3 + osascript di sistema.
#
# Uso:  ./install-quick-action.sh

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUPPORT="$HOME/Library/Application Support/FolderTagger"
SERVICES="$HOME/Library/Services"
WF_NAME="Folder Tagger"
WF="$SERVICES/$WF_NAME.workflow"
MENU_LABEL="Folder Tagger"

echo "→ Installo l'Azione Rapida \"$MENU_LABEL\""

# 1) copia il motore in una posizione stabile
mkdir -p "$SUPPORT"
cp "$SRC_DIR/colorize.py" "$SUPPORT/colorize.py"
COLORIZE="$SUPPORT/colorize.py"

# 2) costruisci il bundle .workflow (rimuovendo anche eventuali nomi vecchi)
rm -rf "$WF" "$SERVICES/Colora cartella + contenuto.workflow" "$SERVICES/folder tagger.workflow"
mkdir -p "$WF/Contents"

U1="$(uuidgen)"; U2="$(uuidgen)"; U3="$(uuidgen)"

# Info.plist — e' questo che fa comparire la voce nel menu (Finder, solo cartelle)
cat > "$WF/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>$MENU_LABEL</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSRequiredContext</key>
            <dict>
                <key>NSApplicationIdentifier</key>
                <string>com.apple.finder</string>
            </dict>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.folder</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# document.wflow — il workflow "Esegui script shell" che riceve le cartelle come argomenti
cat > "$WF/Contents/document.wflow" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key><string>523</string>
    <key>AMApplicationVersion</key><string>2.10</string>
    <key>AMDocumentVersion</key><string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key><string>List</string>
                    <key>Optional</key><true/>
                    <key>Types</key>
                    <array><string>com.apple.cocoa.path</string></array>
                </dict>
                <key>AMActionVersion</key><string>2.0.3</string>
                <key>AMApplication</key><array><string>Automator</string></array>
                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key><dict/>
                    <key>CheckedForUserDefaultShell</key><dict/>
                    <key>inputMethod</key><dict/>
                    <key>shell</key><dict/>
                    <key>source</key><dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key><string>List</string>
                    <key>Types</key><array><string>com.apple.cocoa.string</string></array>
                </dict>
                <key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key><string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key><string>/usr/bin/python3 "$COLORIZE" "\$@"</string>
                    <key>CheckedForUserDefaultShell</key><true/>
                    <key>inputMethod</key><integer>1</integer>
                    <key>shell</key><string>/bin/zsh</string>
                    <key>source</key><string></string>
                </dict>
                <key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key><string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key><false/>
                <key>CanShowWhenRun</key><true/>
                <key>Category</key><array><string>AMCategoryUtilities</string></array>
                <key>Class Name</key><string>RunShellScriptAction</string>
                <key>InputUUID</key><string>$U1</string>
                <key>Keywords</key><array><string>Shell</string><string>Script</string><string>Command</string><string>Run</string><string>Unix</string></array>
                <key>OutputUUID</key><string>$U2</string>
                <key>UUID</key><string>$U3</string>
                <key>UnlocalizedApplications</key><array><string>Automator</string></array>
                <key>arguments</key><dict/>
                <key>isViewVisible</key><integer>1</integer>
                <key>location</key><string>309.000000:253.000000</string>
                <key>nibName</key><string>Run Shell Script</string>
            </dict>
            <key>isViewVisible</key><integer>1</integer>
        </dict>
    </array>
    <key>connectors</key><dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>applicationBundleIDsByProvidedType</key><dict/>
        <key>applicationPaths</key><array/>
        <key>inputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
        <key>outputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
        <key>presentationMode</key><integer>11</integer>
        <key>processesInput</key><integer>0</integer>
        <key>serviceApplicationBundleID</key><string>com.apple.finder</string>
        <key>serviceApplicationPath</key><string>/System/Library/CoreServices/Finder.app</string>
        <key>serviceInputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
        <key>serviceInputTypeIdentifierIndex</key><integer>0</integer>
        <key>serviceOutputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
        <key>useAutomaticInputType</key><integer>0</integer>
        <key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
PLIST

# 3) validazione
plutil -lint "$WF/Contents/Info.plist" >/dev/null
plutil -lint "$WF/Contents/document.wflow" >/dev/null

# 4) aggiorna il database dei Servizi/Azioni rapide
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "✓ Installata: $WF"
echo
echo "──────────────────────────────────────────────────────────────────────"
echo "Come usarla:"
echo "  Tasto destro su una (o piu') cartelle → Azioni rapide →"
echo "  \"$MENU_LABEL\" → scegli il colore. Colora la cartella e tutto il contenuto."
echo
echo "Se non compare subito:"
echo "  • Impostazioni di Sistema → Generali → Login Items & Extensions →"
echo "    Finder / Azioni rapide → assicurati che sia attiva."
echo "  • In alternativa, esci e rientra dall'account (le Azioni rapide nuove"
echo "    a volte compaiono dopo un logout/login)."
echo "──────────────────────────────────────────────────────────────────────"
