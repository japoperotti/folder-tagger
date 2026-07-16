#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
Folder Tagger — one-shot recursive colorizer
--------------------------------------------
Colora una cartella E ogni sua sottocartella (a qualsiasi profondita') con un
colore Finder, oppure rimuove i tag. Pensato per l'Azione Rapida del tasto
destro: selezioni una o piu' cartelle, scegli, e tutto l'albero cambia.

Comportamento:
- Scegliendo un COLORE: sovrascrive: toglie gli eventuali colori precedenti e
  mette solo quello nuovo (una cartella = un solo colore). I tag senza colore
  (etichette di testo personali) vengono lasciati stare.
- Scegliendo "Rimuovi colore (default)": cancella TUTTI i tag → cartella al
  default, nessun colore.
- Confronto per CODICE colore (indipendente dalla lingua), ricorsivo.

Uso:
    colorize.py <cartella> [<cartella> ...]         # mostra il selettore
    colorize.py --color <0-7> <cartella> [...]      # senza dialogo (test)
                                                     # 0 = rimuovi tutti i tag

Codici colore: 1 Grigio  2 Verde  3 Viola  4 Blu  5 Giallo  6 Rosso  7 Arancio
"""

import os
import re
import sys
import binascii
import plistlib
import subprocess

ATTR = "com.apple.metadata:_kMDItemUserTags"
XATTR = "/usr/bin/xattr"

# Nomi localizzati dei 7 tag colore standard di macOS (fallback: inglese).
LOCALIZED_NAMES = {
    "en": {1: "Gray",    2: "Green", 3: "Purple", 4: "Blue",  5: "Yellow",   6: "Red",      7: "Orange"},
    "it": {1: "Grigio",  2: "Verde", 3: "Viola",  4: "Blu",   5: "Giallo",   6: "Rosso",    7: "Arancio"},
    "es": {1: "Gris",    2: "Verde", 3: "Morado", 4: "Azul",  5: "Amarillo", 6: "Rojo",     7: "Naranja"},
    "fr": {1: "Gris",    2: "Vert",  3: "Violet", 4: "Bleu",  5: "Jaune",    6: "Rouge",    7: "Orange"},
    "de": {1: "Grau",    2: "Grün",  3: "Lila",   4: "Blau",  5: "Gelb",     6: "Rot",      7: "Orange"},
    "pt": {1: "Cinza",   2: "Verde", 3: "Roxo",   4: "Azul",  5: "Amarelo",  6: "Vermelho", 7: "Laranja"},
    "nl": {1: "Grijs",   2: "Groen", 3: "Paars",  4: "Blauw", 5: "Geel",     6: "Rood",     7: "Oranje"},
}
RESET_LABELS = {
    "en": "Remove color (default)", "it": "Rimuovi colore (default)",
    "es": "Quitar color (predeterminado)", "fr": "Retirer la couleur (défaut)",
    "de": "Farbe entfernen (Standard)", "pt": "Remover cor (padrão)",
    "nl": "Kleur verwijderen (standaard)",
}
PROMPTS = {
    "en": "Pick a color for this folder and everything inside it:",
    "it": "Scegli un colore per questa cartella e tutto il suo contenuto:",
    "es": "Elige un color para esta carpeta y todo su contenido:",
    "fr": "Choisis une couleur pour ce dossier et tout son contenu:",
    "de": "Wähle eine Farbe für diesen Ordner und den gesamten Inhalt:",
    "pt": "Escolhe uma cor para esta pasta e todo o seu conteúdo:",
    "nl": "Kies een kleur voor deze map en de volledige inhoud:",
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


def names_for_lang():
    return LOCALIZED_NAMES.get(system_language(), LOCALIZED_NAMES["en"])


def _l(table):
    return table.get(system_language(), table["en"])


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


def remove_all_tags(path):
    subprocess.run([XATTR, "-d", ATTR, path], capture_output=True)


def color_code(tag):
    """Codice colore di un tag (0 = senza colore)."""
    parts = str(tag).split("\n")
    if len(parts) >= 2 and parts[-1].strip().isdigit():
        return int(parts[-1].strip())
    return 0


def targets_under(root):
    out = [root]                                     # la cartella stessa +
    for dirpath, dirnames, _ in os.walk(root):       # tutte le discendenti
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for d in dirnames:
            out.append(os.path.join(dirpath, d))
    return out


def apply_recursive(root, code, name):
    changed = 0
    for p in targets_under(root):
        current = get_tags(p)
        if code == 0:
            desired = []                             # reset: via tutti i tag
        else:
            keep = [t for t in current if color_code(t) == 0]   # tieni le etichette senza colore
            desired = keep + ["%s\n%d" % (name, code)]          # + solo il nuovo colore
        if sorted(map(str, desired)) == sorted(map(str, current)):
            continue                                 # gia' a posto
        if desired:
            try:
                set_tags(p, desired)
                changed += 1
            except subprocess.CalledProcessError:
                pass
        else:
            remove_all_tags(p)
            changed += 1
    return changed


def pick_color():
    """Selettore nativo. Ritorna: 1-7 colore, 0 reset, None se annullato."""
    names = names_for_lang()
    reset = _l(RESET_LABELS)
    items = [names[c] for c in range(1, 8)] + [reset]
    as_list = "{" + ", ".join('"%s"' % n for n in items) + "}"
    script = (
        'choose from list %s with prompt "%s" with title "Folder Tagger" '
        'default items {"%s"}' % (as_list, _l(PROMPTS), names[7])
    )
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    out = r.stdout.strip()
    if not out or out == "false":
        return None
    if out == reset:
        return 0
    for c in range(1, 8):
        if names[c] == out:
            return c
    return None


def notify(msg):
    subprocess.run(["osascript", "-e",
                    'display notification "%s" with title "Folder Tagger"' % msg],
                   capture_output=True)


def main():
    args = sys.argv[1:]
    code = None
    if len(args) >= 2 and args[0] == "--color":
        try:
            code = int(args[1])
        except ValueError:
            return
        folders = args[2:]
    else:
        folders = args

    folders = [os.path.abspath(f) for f in folders if os.path.isdir(f)]
    if not folders:
        return

    if code is None:
        code = pick_color()
        if code is None:
            return                                   # annullato
    if code < 0 or code > 7:
        return

    name = names_for_lang()[code] if code >= 1 else ""
    total = sum(apply_recursive(f, code, name) for f in folders)

    if total:
        if code == 0:
            notify("%d cartelle: tag rimossi" % total)
        else:
            notify("%d cartelle colorate (%s)" % (total, name))


if __name__ == "__main__":
    main()
