"""
Write the text the addon takes from retail's client data into the
MUI_Locale files, in every language.

    python tools/locale_retail.py <retail dir> [--era <Era dir>]

<retail dir> holds <lang>/<Table>.csv for enUS and each other language of a
retail build (wago.tools/db2/<Table>/csv?build=…&locale=…). Two kinds of
key are written, between the two marker lines below (put after
`local L = MUI.L` the first time); hand-written keys stay outside the block:

  * a key the code reads (L.MAP_PIN) that is a retail global string
    (GlobalStrings.csv): enUS.lua gets retail's English, each other
    language's file its translation;
  * a key enUS.lua sets by hand with a comment naming a row of another
    table, `-- retail HolidayNames 18` (its *_lang column; Table.Column
    picks one, `ChrSpecialization.Description 71`), optionally
    `, first line`: the other languages get that row's text. A key
    whose English is not the row's is reported and left out. `-- era`
    names a table of the Era build instead.

--era is the Era build's folder of the same kind: a key Era has as a global
string too is reported (the code should read Era's global instead), and
`-- era` rows are read from it.
"""
import argparse
import csv
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALE_DIR = os.path.join(ROOT, "MUI_Locale")
NOT_SCANNED = {"tools", "MUI_Locale", "assets", ".git", ".claude", ".vscode"}
LANGUAGES = ["enUS", "deDE", "esES", "esMX", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
BEGIN = "-- ---- retail's global strings: tools/locale_retail.py writes this block"
END = "-- ---- end of retail's global strings"
KEY_READ = re.compile(r"\bL\.([A-Z][A-Z0-9_]+)\b")
SOURCED = re.compile(r'^L\.([A-Z][A-Z0-9_]+)\s*=\s*("(?:[^"\\]|\\.)*")\s*--\s*(retail|era) (\w+)(?:\.(\w+))? (\d+)(, first line)?', re.M)
csv.field_size_limit(10 ** 9)


def strings(folder, lang):
    """BaseTag -> text of a GlobalStrings.csv, the rows the game loads."""
    path = os.path.join(folder, lang, "GlobalStrings.csv")
    with open(path, encoding="utf-8", newline="") as f:
        return {r["BaseTag"]: r["TagText_lang"] for r in csv.DictReader(f) if int(r["Flags"]) & 1}


_tables = {}


def table_text(folder, lang, table, column, row_id, first_line):
    if (folder, lang, table, column) not in _tables:
        with open(os.path.join(folder, lang, table + ".csv"), encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            name = column + "_lang" if column else next(c for c in reader.fieldnames if c.endswith("_lang"))
            _tables[folder, lang, table, column] = {r["ID"]: r[name] for r in reader}
    text = _tables[folder, lang, table, column].get(row_id, "").replace("\r", "")
    if first_line:
        text = text.split("\n")[0]
    return text.strip()


def lua_literal(text):
    """The table's text is Lua source already (\\n, \\", \\\\ escapes): keep
    those, escape what is bare (a quote, a line break, a lone backslash)."""
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text) and (text[i + 1] in 'ntr\\"\'' or text[i + 1].isdigit()):
            out.append(text[i:i + 2])
            i += 2
            continue
        if c == "\\":
            out.append("\\\\")
        elif c == '"':
            out.append('\\"')
        elif c == "\r":
            pass
        elif c == "\n":
            out.append("\\n")
        else:
            out.append(c)
        i += 1
    return '"' + "".join(out) + '"'


def keys_read():
    found = set()
    for base, dirs, files in os.walk(ROOT):
        rel = os.path.relpath(base, ROOT)
        if rel.split(os.sep)[0] in NOT_SCANNED:
            dirs[:] = []
            continue
        for name in files:
            if name.endswith(".lua"):
                src = open(os.path.join(base, name), encoding="utf-8", errors="replace").read()
                if "MUI.L" in src:
                    found.update(KEY_READ.findall(src))
    return found


def write_block(path, lines):
    with open(path, encoding="utf-8", newline="") as f:
        src = f.read()
    eol = "\r\n" if "\r\n" in src else "\n"
    block = eol.join([BEGIN] + lines + [END])
    if BEGIN in src:
        start = src.index(BEGIN)
        end = src.index(END, start) + len(END)
        src = src[:start] + block + src[end:]
    else:
        anchor = "local L = MUI.L"
        at = src.index(anchor) + len(anchor)
        rest = src[at:].lstrip("\r\n")
        src = src[:at] + eol + eol + block + eol + (eol + rest if rest else "")
        if not src.endswith(eol):
            src += eol
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)


def unescape(literal):
    return literal[1:-1].replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("retail")
    parser.add_argument("--era")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    english = strings(args.retail, "enUS")
    keys = sorted(k for k in keys_read() if k in english)
    own = open(os.path.join(LOCALE_DIR, "enUS.lua"), encoding="utf-8").read()
    if BEGIN in own:
        own = own[:own.index(BEGIN)] + own[own.index(END) + len(END):]
    for key in keys:
        if re.search(r"^L\." + key + r"\s*=", own, re.M):
            print(f"  L.{key} is set by hand and is a retail string's name: rename the key")
    if args.era:
        era = strings(args.era, "enUS")
        for key in keys:
            if key in era:
                print(f"  Era has {key}: read the global instead")
    sourced = []
    for key, literal, build, table, column, row_id, first in SOURCED.findall(own):
        folder = args.retail if build == "retail" else args.era
        mine = re.sub(r"\s+", " ", unescape(literal)).strip()
        theirs = re.sub(r"\s+", " ", table_text(folder, "enUS", table, column, row_id, first)).strip()
        if mine != theirs:
            print(f"  L.{key}: not {table} {row_id}'s English ({theirs[:60]!r}), left out")
            continue
        sourced.append((key, folder, table, column, row_id, first))
    for lang in LANGUAGES:
        texts = english if lang == "enUS" else strings(args.retail, lang)
        lines = [f"L.{key} = {lua_literal(texts[key])}" for key in keys if texts.get(key)]
        if lang != "enUS":
            for key, folder, table, column, row_id, first in sourced:
                text = table_text(folder, lang, table, column, row_id, first)
                if text:
                    lines.append(f"L.{key} = {lua_literal(text)}")
        write_block(os.path.join(LOCALE_DIR, lang + ".lua"), lines)
        print(f"{lang}: {len(lines)} keys")


if __name__ == "__main__":
    main()
