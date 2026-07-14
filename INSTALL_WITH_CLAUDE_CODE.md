# Instructions for Claude Code — install Folder Tagger

You are helping the user install **Folder Tagger** on their Mac. It auto-applies
a Finder color tag to every sub-folder (any depth) of a folder they choose, as
folders are created — so their workspace is recognizable at a glance.

Follow these steps:

1. **Ask the user two things** (if they haven't already said):
   - Which folder to watch (absolute path, e.g. `~/Documents/My Workspace`).
   - Which color, 1–7:
     `1 Gray  2 Green  3 Purple  4 Blue  5 Yellow  6 Red  7 Orange`.
   - If their Mac is not in English, also ask the localized tag name for that
     color (e.g. Italian orange = `Arancio`) so Finder reuses the system tag
     instead of creating a new custom one. If English or unsure, skip it.

2. **Run the installer** from this folder:
   ```bash
   ./install.sh "<their folder>" <color number> ["localized tag name"]
   ```
   (Make it executable first if needed: `chmod +x install.sh uninstall.sh`.)

3. **Walk them through the one manual step — Full Disk Access.** macOS will not
   let you grant this from the command line; the user must do it themselves.
   The installer already opened *System Settings → Privacy & Security → Full
   Disk Access* and revealed the app in Finder. Tell the user to:
   - Click **+** in that pane (or drag the revealed `FolderTagger.app` in),
   - add `~/Library/Application Support/FolderTagger/FolderTagger.app`,
   - make sure its toggle is **ON**.
   Explain *why*: without it the background job can't read folders inside
   Documents/Desktop/Downloads and nothing gets colored.

4. **Verify.** After they've granted access, create a test sub-folder in their
   watched folder and check it turns the chosen color within ~a minute (or
   instantly if it's a top-level folder). You can also trigger a pass manually:
   ```bash
   /usr/bin/python3 "$HOME/Library/Application Support/FolderTagger/autotag.py"
   ```
   and check the log at
   `~/Library/Application Support/FolderTagger/folder-tagger.log`.

5. To change the folder or color later, just re-run `install.sh` with new
   values. To remove everything, run `./uninstall.sh`.

Notes:
- Requires macOS. No third-party dependencies (system `python3` + `xattr`).
- The tool never deletes tags; it only appends the chosen color.
