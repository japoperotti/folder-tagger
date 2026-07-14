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
import json
import time
import binascii
import plistlib
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(HERE, "config.json")

ATTR = "com.apple.metadata:_kMDItemUserTags"
XATTR = "/usr/bin/xattr"


def load_config():
    with open(CONFIG_PATH, "r") as f:
        cfg = json.load(f)
    root = os.path.expanduser(cfg["root"])
    color = int(cfg["color"])          # 1..7 (macOS Finder color code)
    name = cfg.get("tag_name", "")     # localized label; may be empty
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
