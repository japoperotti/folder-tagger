# Folder Tagger 🎨📁

Automatically color-tags every sub-folder inside a folder you choose, in Finder,
as folders get created. Great for making an AI/agent workspace (or any project
tree) instantly recognizable — the whole tree shows up in one color while the
rest of your Mac stays default.

- **Recursive** — colors folders at any depth.
- **Automatic** — reacts when folders are created (plus a 60-second safety pass).
- **Non-destructive** — appends the color, never removes your existing tags.
- **Idempotent** — skips folders that already have the color.
- **No dependencies** — uses only the built-in macOS `python3` and `xattr`.

## Requirements

- macOS.
- One manual step during install: grant **Full Disk Access** to the bundled
  `FolderTagger.app` (macOS requires this for a background job to read folders
  inside Documents/Desktop/Downloads — it can't be automated).

## Install

### Easiest: let Claude Code do it
Open this folder in Claude Code and say *"install this"*. It will ask which
folder and color you want and walk you through the Full Disk Access step.
(See `INSTALL_WITH_CLAUDE_CODE.md`.)

### Manual
```bash
chmod +x install.sh uninstall.sh
./install.sh "~/Documents/My Workspace" 7        # 7 = Orange
```
Then grant Full Disk Access to the app when System Settings opens (the installer
opens the right pane and reveals the app for you).

**Colors:** `1 Gray  2 Green  3 Purple  4 Blue  5 Yellow  6 Red  7 Orange`

Non-English Mac? Pass the localized tag name as a 3rd argument so Finder reuses
the system tag, e.g. `./install.sh "~/Documents/Lavoro" 7 "Arancio"`.

## Change color / folder later
Re-run `install.sh` with new values — it reconfigures in place.

## Uninstall
```bash
./uninstall.sh
```
This removes the background agent, the app and its files. Colors already applied
to your folders stay (clear them from Finder → right-click → Tags if you want).
Also remove the app from System Settings → Privacy & Security → Full Disk Access.

## How it works

- `autotag.py` — the worker. Reads `config.json` (folder + color), walks the
  tree and writes the Finder tag via `xattr`.
- `FolderTagger.app` — a tiny AppleScript wrapper that just runs the worker. It
  exists solely as an authorizable target for Full Disk Access.
- LaunchAgent `com.coworkos.folder-tagger` — triggers the app on folder changes
  (`WatchPaths`) and every 60s (`StartInterval`), plus at login.

Files are installed to `~/Library/Application Support/FolderTagger/`.

## License
MIT — do whatever you like.
