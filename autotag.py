#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
Folder Tagger — watcher (registry-based)
----------------------------------------
Sorveglia PIU' cartelle contemporaneamente e colora le sottocartelle nuove.

Legge il registro `watches.json` (accanto a questo script): una lista di
{root, color, tag_name}. Per ogni cartella sorvegliata, applica il suo colore a
tutte le sottocartelle che NON hanno ancora un colore. Le cartelle gia' colorate
(a mano o da un'altra regola) vengono lasciate stare. In caso di annidamento tra
cartelle sorvegliate, vince quella piu' interna (la piu' vicina).

- Ricorsivo, idempotente, non distruttivo (aggiunge il colore solo dove manca,
  mantiene eventuali etichette di testo senza colore).
- Zero dipendenze: /usr/bin/python3 + /usr/bin/xattr.
- Retro-compatibile: se manca watches.json ma esiste il vecchio config.json,
  lo tratta come un registro con una sola voce.

Lanciato dal LaunchAgent (WatchPaths sulle cartelle + StartInterval + RunAtLoad).
"""

import os
import re
import json
import time
import binascii
import plistlib
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
REGISTRY = os.path.join(HERE, "watches.json")
LEGACY = os.path.join(HERE, "config.json")

ATTR = "com.apple.metadata:_kMDItemUserTags"
XATTR = "/usr/bin/xattr"

LOCALIZED_NAMES = {
    "en": {1: "Gray",   2: "Green", 3: "Purple", 4: "Blue",  5: "Yellow",   6: "Red",      7: "Orange"},
    "it": {1: "Grigio", 2: "Verde", 3: "Viola",  4: "Blu",   5: "Giallo",   6: "Rosso",    7: "Arancio"},
    "es": {1: "Gris",   2: "Verde", 3: "Morado", 4: "Azul",  5: "Amarillo", 6: "Rojo",     7: "Naranja"},
    "fr": {1: "Gris",   2: "Vert",  3: "Violet", 4: "Bleu",  5: "Jaune",    6: "Rouge",    7: "Orange"},
    "de": {1: "Grau",   2: "Grün",  3: "Lila",   4: "Blau",  5: "Gelb",     6: "Rot",      7: "Orange"},
    "pt": {1: "Cinza",  2: "Verde", 3: "Roxo",   4: "Azul",  5: "Amarelo",  6: "Vermelho", 7: "Laranja"},
    "nl": {1: "Grijs",  2: "Groen", 3: "Paars",  4: "Blauw", 5: "Geel",     6: "Rood",     7: "Oranje"},
}


def system_language():
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


def get_tags(path):
    r = subprocess.run([XATTR, "-px", ATTR, path], capture_output=True, text=True)
    if r.returncode != 0:
        return []
    hexstr = "".join(r.stdout.split())
    if not hexstr:
        return []
    try:
        val = plistlib.loads(binascii.unhexlify(hexstr))
        return val if isinstance(val, list) else []
    except Exception:
        return []


def set_tags(path, tags):
    raw = plistlib.dumps(tags, fmt=plistlib.FMT_BINARY)
    subprocess.run([XATTR, "-wx", ATTR, binascii.hexlify(raw).decode(), path],
                   check=True, capture_output=True)


def color_code(tag):
    parts = str(tag).split("\n")
    if len(parts) >= 2 and parts[-1].strip().isdigit():
        return int(parts[-1].strip())
    return 0


def load_watches():
    items = []
    try:
        if os.path.exists(REGISTRY):
            data = json.load(open(REGISTRY))
            items = data if isinstance(data, list) else []
        elif os.path.exists(LEGACY):
            c = json.load(open(LEGACY))
            items = [{"root": c["root"], "color": c["color"],
                      "tag_name": c.get("tag_name", "")}]
    except Exception:
        return []
    out = []
    for it in items:
        try:
            root = os.path.abspath(os.path.expanduser(it["root"]))
            color = int(it["color"])
        except Exception:
            continue
        if 1 <= color <= 7 and os.path.isdir(root):
            name = it.get("tag_name") or localized_name(color)
            out.append((root, color, name))
    return out


def targets_for(root, watched_paths):
    """Cartella + discendenti, SENZA entrare in altre cartelle sorvegliate
    (quelle le gestisce la loro stessa regola → vince la piu' interna)."""
    out = [root]
    for dirpath, dirnames, _ in os.walk(root):
        keep = []
        for d in dirnames:
            if d.startswith("."):
                continue
            full = os.path.join(dirpath, d)
            if full in watched_paths and full != root:
                continue                         # cartella sorvegliata annidata: salta
            keep.append(d)
            out.append(full)
        dirnames[:] = keep
    return out


def main():
    watches = load_watches()
    if not watches:
        return
    watched_paths = set(w[0] for w in watches)
    # dalla piu' interna alla piu' esterna (nearest-ancestor wins)
    watches.sort(key=lambda w: w[0].count(os.sep), reverse=True)

    tagged = 0
    for root, color, name in watches:
        value = "%s\n%d" % (name, color)
        for p in targets_for(root, watched_paths):
            tags = get_tags(p)
            if any(color_code(t) != 0 for t in tags):
                continue                         # ha gia' un colore: non toccare
            try:
                set_tags(p, tags + [value])      # aggiunge il colore, tiene le etichette
                tagged += 1
                print("%s  %s -> %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), name, p),
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
