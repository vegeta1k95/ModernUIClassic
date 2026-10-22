"""
List the English text left in ModernUI's code, and check the keys of its
string table, MUI.L (MUI_Locale/).

    python tools/locale_audit.py [--era <db2 dir>] [--retail <db2 dir>] [<module> ...]

Without a module it counts what each module has left; with modules
(MUI_Map, MUI_Bags, ...) it lists every finding in them, by file and line.
--era and --retail name folders holding GlobalStrings.csv of the Era build
in .build.info and of retail (wago.tools/db2): each finding then names the
Blizzard global strings with its text, Era's when Era has one.

A finding is a string literal of the addon's Lua (not tools/, MUI_DB/ or
MUI_Locale/) that reads as words:
  * "match": compared with text the game sends, or a key such text is
    looked up by, which only works on an English client;
  * "text": the rest, most of it shown to the player.
Not findings: tokens the game sends in English on every client (faction
groups, GUID types and the like) where they are compared, Lua and macros
held in strings, a module's name (what it hands Module.__init), and what
tools/locale_audit_ignore.txt lists.

The keys: every L.KEY the code reads has to be set in MUI_Locale/enUS.lua.
A key enUS.lua sets and nothing reads, and one another language sets that
enUS.lua doesn't, are listed too, with how many keys each language sets.
The script exits with 1 when the code reads a key enUS.lua doesn't set.
"""
import argparse
import collections
import csv
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALE_DIR = os.path.join(ROOT, "MUI_Locale")
IGNORE_FILE = os.path.join(ROOT, "tools", "locale_audit_ignore.txt")
NOT_SCANNED = {"tools", "MUI_DB", "MUI_Locale", "assets", ".git", ".claude", ".vscode"}
LANGUAGES = ["deDE", "esES", "esMX", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]

# In English on every client: UnitFactionGroup's first return, a GUID's
# type, the combat log's environmental damage types, the "None" dispel type.
TOKENS = {"Horde", "Alliance", "Neutral", "Creature", "Vehicle", "Pet", "Player",
          "GameObject", "None", "Falling", "Drowning", "Fatigue", "Lava", "Slime"}

# Widget types; the addon's own class and object names join them.
NAMES = set("""Frame Button Texture FontString Model PlayerModel DressUpModel Slider
EditBox CheckButton StatusBar ScrollFrame Cooldown GameTooltip Line MaskTexture
Animation Alpha Translation Scale Rotation Path AnimationGroup MessageFrame SimpleHTML
ColorSelect ScrollingMessageFrame MovieFrame Minimap ModelScene CinematicModel
TabardModel Font""".split())

CLASS = re.compile(r'\b(?:class|object)\s+"(\w+)"')
KEY_READ = re.compile(r"\bL\.([A-Z][A-Z0-9_]+)\b")
KEY_SET = re.compile(r"^[ \t]*L\.([A-Z][A-Z0-9_]+)[ \t]*=", re.M)
# The literal is the pattern of a find / match / gsub, a side of == or ~=,
# or a table key.
MATCH = re.compile(r"(?:find|match|gmatch|gsub|strfind|strmatch)\s*\(\s*(?:[^,()]*,\s*)?$"
                   r"|(?:==|~=)\s*$|\[\s*$")
MODULE_NAME = re.compile(r"\bModule\.__init\(\s*self\s*,\s*$")
# A colour, line break, texture, atlas or link in the text.
ESCAPE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|n|\|T[^|]*\|t|\|A[^|]*\|a|\|H[^|]*\|h|\|h")


def lua_files():
    for root, dirs, names in os.walk(ROOT):
        rel = os.path.relpath(root, ROOT)
        if rel.split(os.sep)[0] in NOT_SCANNED:
            dirs[:] = []
            continue
        for name in sorted(names):
            if name.endswith(".lua"):
                path = os.path.join(root, name)
                yield os.path.relpath(path, ROOT).replace(os.sep, "/"), path


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def literals(src):
    """(line, start, end, text) of each string literal outside comments."""
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
        elif src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:i + 64])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                j = n if j < 0 else j + len(close)
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
            line += src.count("\n", i, j)
            i = j
        elif c == "[" and re.match(r"\[(=*)\[", src[i:i + 64]):
            m = re.match(r"\[(=*)\[", src[i:i + 64])
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            j = n if j < 0 else j + len(close)
            yield line, i, j, src[i + len(m.group(0)):j - len(close)]
            line += src.count("\n", i, j)
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            yield line, i, j + 1, src[i + 1:j]
            i = j + 1
        else:
            i += 1


def reads_as_words(s):
    s = ESCAPE.sub("", s)
    if not re.search(r"[A-Za-z]{2}", s):
        return False
    if s.startswith(("Interface", "interface", "/")) or "\\\\" in s:
        return False                                            # paths, macros
    if re.search(r"\.(blp|tga|ttf|png|m2|lua|xml)\b", s, re.I):
        return False
    if re.search(r"\bself[:.]|\blocal\s+\w|:[GS]et\w+\(", s) or re.search(r"\bthen\b[\s\S]*\bend\b", s):
        return False                                            # Lua in a string
    if re.fullmatch(r"[A-Z0-9_|:.\-]+", s):                     # events, anchors, filters
        return False
    if re.fullmatch(r"[a-z_][A-Za-z0-9_.]*", s):                # keys, units, CVars
        return False
    if re.fullmatch(r"[A-Z][a-z0-9]+(?:[A-Z][A-Za-z0-9]*)+", s):  # CamelCase
        return False
    if s in NAMES:
        return False
    word = s.strip()
    if " " not in word:
        word = word.strip("()[]<>")
        if word != s and re.fullmatch(r"[a-z][a-z']+[:.!?]?", word):
            return True                                         # " items", "quest " .. id
        return bool(re.fullmatch(r"[A-Z][a-z']+[:.!?]?", word))
    return True


def loose(s):
    s = s.replace("\\n", "\n").strip()
    s = re.sub(r"%(\d+\$)?[-+ #0]*\d*(\.\d+)?[sdifgxc]", "%s", s)
    return re.sub(r"(\.\.\.|…|[:.!])$", "", s).strip().lower()


def global_strings(folder):
    """Tags by text, and by text taken loosely, of a GlobalStrings.csv."""
    exact, near = collections.defaultdict(list), collections.defaultdict(list)
    if folder:
        csv.field_size_limit(10 ** 9)
        with open(os.path.join(folder, "GlobalStrings.csv"), encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                exact[row["TagText_lang"]].append(row["BaseTag"])
                near[loose(row["TagText_lang"])].append(row["BaseTag"])
    return exact, near


def blizzard(text, era, retail):
    """Where Blizzard has the text: ("era" | "retail" | "", "~" when taken loosely, tags)."""
    for where, (exact, near) in (("era", era), ("retail", retail)):
        if text in exact:
            return where, "", exact[text]
        if loose(text) in near:
            return where, "~", near[loose(text)]
    return "", "", []


def ignored():
    found = set()
    if os.path.exists(IGNORE_FILE):
        for line in read(IGNORE_FILE).splitlines():
            if line and not line.startswith("#"):
                path, _, text = line.partition(": ")
                found.add((path, text))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("modules", nargs="*")
    parser.add_argument("--era")
    parser.add_argument("--retail")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    files = [(rel, read(path)) for rel, path in lua_files()]
    for _, src in files:
        NAMES.update(CLASS.findall(src))
    era, retail = global_strings(args.era), global_strings(args.retail)
    skip = ignored()

    # ---- English in the code
    findings = []
    for rel, src in files:
        module = rel.split("/")[0].removesuffix(".lua")
        for line, start, _, text in literals(src):
            if (rel, text) in skip or not reads_as_words(text):
                continue
            before = src[src.rfind("\n", 0, start) + 1:start]
            if MODULE_NAME.search(before):
                continue
            kind = "match" if MATCH.search(before) else "text"
            if kind == "match" and text in TOKENS:
                continue
            findings.append((module, rel, line, kind, text))

    with_gs = bool(args.era or args.retail)
    if args.modules:
        for module, rel, line, kind, text in findings:
            if module in args.modules:
                where, near, tags = blizzard(text, era, retail)
                note = f"  {where}{near}: {', '.join(tags[:4])}" if where else ""
                print(f'{rel}:{line}  {kind:5}  "{text}"{note}')
    else:
        per = collections.defaultdict(collections.Counter)
        for module, _, _, kind, text in findings:
            per[module][kind] += 1
            if with_gs:
                per[module][blizzard(text, era, retail)[0] or "none"] += 1
        cols = ["text", "match"] + (["era", "retail", "none"] if with_gs else [])
        print(f"{'module':22}" + "".join(f"{c:>8}" for c in cols))
        total = collections.Counter()
        for module in sorted(per, key=lambda m: -(per[m]["text"] + per[m]["match"])):
            total.update(per[module])
            print(f"{module:22}" + "".join(f"{per[module][c]:8}" for c in cols))
        print(f"{'total':22}" + "".join(f"{total[c]:8}" for c in cols))

    # ---- the keys (MUI_DB's hand-written tables read some too)
    english = set(KEY_SET.findall(read(os.path.join(LOCALE_DIR, "enUS.lua"))))
    reads = collections.defaultdict(list)
    db = os.path.join(ROOT, "MUI_DB")
    db_files = [("MUI_DB/" + n, read(os.path.join(db, n))) for n in sorted(os.listdir(db)) if n.endswith(".lua")]
    for rel, src in files + db_files:
        if "MUI.L" in src:
            for m in KEY_READ.finditer(src):
                reads[m.group(1)].append(f"{rel}:{src.count(chr(10), 0, m.start()) + 1}")
    unset = sorted(k for k in reads if k not in english)
    print(f"\nkeys: {len(english)} set in enUS.lua, {len(reads)} read by the code")
    for key in unset:
        print(f"  read and never set: L.{key}  ({', '.join(reads[key][:3])})")
    for key in sorted(english - set(reads)):
        print(f"  set and never read: L.{key}")
    for lang in LANGUAGES:
        keys = set(KEY_SET.findall(read(os.path.join(LOCALE_DIR, lang + ".lua"))))
        extra = sorted(keys - english)
        print(f"  {lang}: {len(keys & english)} of {len(english)}"
              + (f"; not in enUS.lua: {', '.join(extra)}" if extra else ""))
    return 1 if unset else 0


if __name__ == "__main__":
    sys.exit(main())
