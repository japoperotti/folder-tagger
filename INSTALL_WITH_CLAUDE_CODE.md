# Instructions for Claude Code — install Folder Tagger

You are helping the user install **Folder Tagger** on their Mac. It adds a Finder
right-click action to color a folder + its whole contents, and keeps watching
that folder so new sub-folders inherit the color automatically.

Follow these steps:

1. **Run the installer** from this folder (no arguments needed):
   ```bash
   chmod +x install.sh uninstall.sh
   ./install.sh
   ```
   Optionally pre-watch one folder right away:
   ```bash
   ./install.sh "<folder>" <color 1-7> ["localized tag name"]
   ```
   Colors: `1 Gray 2 Green 3 Purple 4 Blue 5 Yellow 6 Red 7 Orange`. The tag name
   auto-localizes to the Mac's language, so normally omit the 3rd argument.

2. **Walk them through the one manual step — Full Disk Access.** macOS will not
   let you grant this from the command line; the user must do it. The installer
   already opened *System Settings → Privacy & Security → Full Disk Access* and
   revealed the app. Tell the user to:
   - Click **+** (or drag the revealed `FolderTagger.app` in),
   - add `~/Library/Application Support/FolderTagger/FolderTagger.app`,
   - make sure its toggle is **ON**.
   Explain *why*: without it the background watcher can't read folders inside
   Documents/Desktop/Downloads, so future sub-folders won't be auto-colored.
   (The immediate right-click coloring works even without it.)

3. **Show them how to use it.** Right-click a folder → Quick Actions → **Folder
   Tagger** → pick a color. The folder + contents get colored and the folder is
   now watched. "Remove color (default)" clears tags and stops watching it.

4. **Verify.** Right-click a folder and pick a color; then create a new
   sub-folder inside it and confirm it turns the same color within ~a minute
   (or instantly for a direct child). The registry is at
   `~/Library/Application Support/FolderTagger/watches.json`; the log at
   `~/Library/Application Support/FolderTagger/folder-tagger.log`.

5. To remove everything, run `./uninstall.sh`.

Notes:
- Requires macOS. No third-party dependencies (system `python3` + `xattr`).
- Coloring overwrites the previous color (one color per folder). The watcher only
  colors *uncolored* sub-folders, so it never fights folders you colored by hand.
