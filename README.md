# Folder Tagger 🎨📁

Color-tag folders in Finder — automatically for a whole workspace, or on demand
from the right-click menu. Great for making an AI/agent workspace (or any project
tree) instantly recognizable: the whole tree shows up in one color while the rest
of your Mac stays default.

Two independent tools, use either or both:

| Tool | What it does | Trigger |
|------|--------------|---------|
| **Auto-watcher** (`install.sh`) | Colors every sub-folder of a chosen workspace, forever, as folders are created | Automatic (background) |
| **Right-click action** (`install-quick-action.sh`) | Colors any folder **+ its whole contents** in a color you pick | Finder → right-click → Quick Actions → **Folder Tagger** |

Common traits:
- **Recursive** — colors folders at any depth.
- **Locale-aware** — reuses your Mac's own color-tag names (Orange / Arancio /
  Naranja …). Duplicate detection is by color *code*, so it works in any language.
- **No dependencies** — uses only the built-in macOS `python3` and `xattr`.

## Requirements

- macOS.
- For the **auto-watcher only**: one manual step during install — grant
  **Full Disk Access** to the bundled `FolderTagger.app` (macOS requires this for
  a *background* job to read folders inside Documents/Desktop/Downloads; it can't
  be automated). The right-click action does **not** need this — it runs on
  folders you explicitly select.

---

## 1. Auto-watcher — a whole workspace, automatically

```bash
chmod +x install.sh uninstall.sh
./install.sh "~/Documents/My Workspace" 7        # 7 = Orange
```
Then grant Full Disk Access to the app when System Settings opens (the installer
opens the right pane and reveals the app for you).

- **Colors:** `1 Gray  2 Green  3 Purple  4 Blue  5 Yellow  6 Red  7 Orange`
- The tag **name** is auto-localized to your Mac's language. To force a specific
  name, pass it as a 3rd argument: `./install.sh "~/Documents/Lavoro" 7 "Arancio"`.
- **Non-destructive:** appends the color, keeps your existing tags. Idempotent.
- Reacts on folder creation (`WatchPaths`) plus a 60-second safety pass.

Change color/folder later: just re-run `install.sh` with new values.

### Uninstall
```bash
./uninstall.sh
```
Removes the background agent, the app and its files. Colors already applied stay.
Also remove the app from System Settings → Privacy & Security → Full Disk Access.

---

## 2. Right-click action — one folder + its contents, on demand

```bash
chmod +x install-quick-action.sh
./install-quick-action.sh
```
Adds a **Folder Tagger** entry to Finder's right-click → *Quick Actions*.

Usage: right-click one (or several) folders → **Quick Actions → Folder Tagger** →
pick a color. The folder **and every sub-folder** get that color. The picker also
has **“Remove color (default)”**, which clears all tags from the folder and its
contents (your way back to no color).

Behavior:
- **Overwrite** — picking a color removes any previous *color* tag first, so a
  folder never ends up with two colors. Plain text labels (tags with no color)
  are kept.
- **Remove color (default)** — deletes **all** tags, recursively.

The action installs a copy of `colorize.py` to
`~/Library/Application Support/FolderTagger/` and a workflow to
`~/Library/Services/Folder Tagger.workflow`. To remove it, delete that
`.workflow` (and, if you like, the `colorize.py`).

> Note: custom Quick Actions show without a colored icon in the right-click
> submenu — the colorful per-item icons are reserved for Apple's system actions.

---

## How it works

- `autotag.py` — the watcher's worker. Reads `config.json` (folder + color),
  walks the tree and writes the Finder tag via `xattr`.
- `colorize.py` — the on-demand colorizer used by the right-click action. Shows a
  native color picker and applies (or clears) tags recursively.
- `FolderTagger.app` — a tiny AppleScript wrapper that just runs the watcher. It
  exists solely as an authorizable target for Full Disk Access.
- LaunchAgent `com.coworkos.folder-tagger` — triggers the app on folder changes
  and every 60s, plus at login.

Finder tags are stored as the `com.apple.metadata:_kMDItemUserTags` extended
attribute (`Name\nCode`). They travel with the folder: renaming, moving or
copying a folder keeps its color — a brief flicker on rename is just Finder
repainting, the tag itself never leaves.

## License
MIT — do whatever you like.
