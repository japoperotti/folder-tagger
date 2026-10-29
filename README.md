# Folder Tagger 🎨📁

Color-tag folders in Finder from the right-click menu — and make it **stick**.
When you color a folder, Folder Tagger colors it *and its whole contents*, then
keeps watching it so every **new sub-folder created later inherits the color**
automatically. Great for keeping a project (or an AI/agent workspace) instantly
recognizable while the rest of your Mac stays default.

- **Right-click, pick a color** — the folder and everything inside get it.
- **Future-proof** — new sub-folders added later are colored automatically.
- **Recursive**, any depth. **Nested folders** can have their own color (the
  nearest one wins).
- **Non-destructive to your work** — leaves folders you colored differently, and
  keeps plain text-label tags.
- **Locale-aware** — reuses your Mac's own color-tag names (Orange / Arancio /
  Naranja …); duplicate detection is by color *code*, so it works in any language.
- **No dependencies** — only the built-in macOS `python3` and `xattr`.

## Requirements

- macOS.
- One manual step: grant **Full Disk Access** to the bundled `Folder Tagger Watcher.app`.
  macOS requires this so the background watcher can read folders inside
  Documents/Desktop/Downloads. (The immediate right-click coloring works without
  it; only the *automatic inheritance* needs it.)

## Install

```bash
chmod +x install.sh uninstall.sh
./install.sh
```
Then grant Full Disk Access to `Folder Tagger Watcher.app` when System Settings opens
(the installer opens the right pane and reveals the app for you).

> Prefer Claude Code? Open this folder and say *"install this"* — see
> `INSTALL_WITH_CLAUDE_CODE.md`.

## Use it

Right-click one (or several) folders in Finder → **Quick Actions → Folder
Tagger** → pick a color. That folder + all its contents get colored, and it
starts being watched so new sub-folders inherit the color.

The picker also has **“Remove color (default)”**: it clears all tags from the
folder and its contents **and** stops watching it — your way back to default.

- **Colors:** `1 Gray  2 Green  3 Purple  4 Blue  5 Yellow  6 Red  7 Orange`.
- Changing a folder's color overwrites the old one (never two colors at once).
- Want a folder watched without using the menu? Pre-seed it:
  `./install.sh "~/Documents/My Workspace" 7`

## Uninstall
```bash
./uninstall.sh
```
Removes the watcher, the app, the right-click action and all its files. Colors
already applied to your folders stay. Also remove the app from System Settings →
Privacy & Security → Full Disk Access.

## How it works

- **`colorize.py`** — runs from the right-click action. Colors the selected
  folder(s) + contents, then records each in the registry `watches.json` and
  reloads the watcher (or un-records it on “Remove color”).
- **`autotag.py`** — the watcher. Reads `watches.json` and colors any *uncolored*
  sub-folder of each watched folder with that folder's color. Deepest watched
  folder wins for nested cases. Idempotent; never overrides an existing color.
- **`Folder Tagger Watcher.app`** — a tiny compiled launcher (`launcher.c`, no UI)
  that just runs the watcher; it exists solely as an authorizable target for
  Full Disk Access.
- **LaunchAgent `com.foldertagger.watcher`** — triggers the watcher when
  something changes inside a watched folder (`WatchPaths`, nested sub-folders
  included), plus at login. No periodic polling.

Everything installs to `~/Library/Application Support/Folder Tagger/`.

Finder tags are stored as the `com.apple.metadata:_kMDItemUserTags` extended
attribute (`Name\nCode`). They travel with the folder: renaming, moving or
copying keeps the color — a brief flicker on rename is just Finder repainting,
the tag itself never leaves.

## License
MIT — do whatever you like.
