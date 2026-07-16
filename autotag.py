#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
Folder Tagger — worker script
------------------------------
Applies a Finder color tag to every sub-folder (at any depth) of a chosen
workspace folder, so the whole tree is recognizable at a glance in Finder.

- Recursive: any depth.
- Idempotent: skips folders that already carry the chosen color (no dupes).
- Non-destructive: if a folder has other tags, the color is appended without
  removing them.
- Zero dependencies: uses only the system python3 (/usr/bin/python3),
  plistlib (stdlib) and /usr/bin/xattr.

Configuration lives in `config.json` next to this file (written by install.sh),
so this script itself is generic and never needs editing.

It is launched by a LaunchAgent both when the folder changes (WatchPaths) and
periodically (StartInterval).
"""

import os
import re
import json
import time
import binascii
import plistlib
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(HERE, "config.json")

ATTR = "com.apple.metadata:_kMDItemUserTags"
XATTR = "/usr/bin/xattr"

# macOS localized names of the 7 standard Finder color tags, by language.
# Falls back to English for any language not listed. Adding a language here
# lets the tool reuse that Mac's native color tag instead of creating a
# separate, foreign-named one. Color codes: 1..7 as documented below.
LOCALIZED_NAMES = {
    "en": {1: "Gray",    2: "Green", 3: "Purple", 4: "Blue", 5: "Yellow",  6: "Red",      7: "Orange"},
    "it": {1: "Grigio",  2: "Verde", 3: "Viola",  4: "Blu",  5: "Giallo",  6: "Rosso",    7: "Arancio"},
    "es": {1: "Gris",    2: "Verde", 3: "Morado", 4: "Azul", 5: "Amarillo", 6: "Rojo",    7: "Naranja"},
    "fr": {1: "Gris",    2: "Vert",  3: "Violet", 4: "Bleu", 5: "Jaune",   6: "Rouge",    7: "Orange"},
    "de": {1: "Grau",    2: "Grün",  3: "Lila",   4: "Blau", 5: "Gelb",    6: "Rot",      7: "Orange"},
    "pt": {1: "Cinza",   2: "Verde", 3: "Roxo",   4: "Azul", 5: "Amarelo", 6: "Vermelho", 7: "Laranja"},
    "nl": {1: "Grijs",   2: "Groen", 3: "Paars",  4: "Blauw", 5: "Geel",   6: "Rood",     7: "Oranje"},
}


def system_language():
    """Two-letter code of the Mac's primary UI language (e.g. 'it'), 'en' if unknown."""
    try:
        r = subprocess.run(["defaults", "read", "-g", "AppleLanguages"],
                           capture_output=True, text=True)
        m = re.search(r'[A-Za-z]{2}', r.stdout)
        if m:
            return m.group(0).lower()
    except Exception:
        pass
    return "en"


def localized_name(color):
    table = LOCALIZED_NAMES.get(system_language(), LOCALIZED_NAMES["en"])
    return table.get(color, LOCALIZED_NAMES["en"][color])


def load_config():
    with open(CONFIG_PATH, "r") as f:
        cfg = json.load(f)
    root = os.path.expanduser(cfg["root"])
    color = int(cfg["color"])          # 1..7 (macOS Finder color code)
    name = cfg.get("tag_name", "")     # localized label; empty = auto-localize
    if not name:
        name = localized_name(color)   # match the Mac's own language
    return root, name, color


def get_tags(path):
    """Return the folder's tag list (empty if none)."""
    r = subprocess.run([XATTR, "-px", ATTR, path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return []
    hexstr = "".join(r.stdout.split())
    if not hexstr:
        return []
    try:
        raw = binascii.unhexlify(hexstr)
        val = plistlib.loads(raw)
        return val if isinstance(val, list) else []
    except Exception:
        return []


def set_tags(path, tags):
    raw = plistlib.dumps(tags, fmt=plistlib.FMT_BINARY)
    hexstr = binascii.hexlify(raw).decode()
    subprocess.run([XATTR, "-wx", ATTR, hexstr, path],
                   check=True, capture_output=True)


def has_color(tags, color):
    """True if any existing tag already uses this color code.

    A Finder tag value is 'Name\\nCode'; matching on the trailing code makes
    this locale-independent (works regardless of the tag's display name)."""
    for t in tags:
        parts = str(t).split("\n")
        if len(parts) >= 2 and parts[-1] == str(color):
            return True
    return False


def main():
    root, name, color = load_config()
    tag_value = "%s\n%d" % (name, color)  # e.g. "Orange\n7" or "\n7"
    if not os.path.isdir(root):
        return
    tagged = 0
    for dirpath, dirnames, _ in os.walk(root):
        # do not descend into hidden folders (.git, etc.)
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for d in dirnames:
            p = os.path.join(dirpath, d)
            tags = get_tags(p)
            if has_color(tags, color):
                continue
            tags.append(tag_value)
            try:
                set_tags(p, tags)
                tagged += 1
                print("%s  color -> %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), p),
                      flush=True)
            except subprocess.CalledProcessError as e:
                detail = e.stderr.decode(errors="replace") if e.stderr else e
                print("%s  ERROR %s: %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), p, detail),
                      flush=True)
    if tagged:
        print("%s  done: %d folders tagged" % (time.strftime("%Y-%m-%d %H:%M:%S"), tagged),
              flush=True)


if __name__ == "__main__":
    main()
