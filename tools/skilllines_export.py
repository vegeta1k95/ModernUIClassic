"""
Build MUI_DB/MUI_SkillLineDB.lua: the skill lines the addon reads off the
skill window, by the name the Era client gives each in every language.

    python tools/skilllines_export.py <db2 dir>

<db2 dir> holds a folder per language (enUS, deDE, esES, esMX, frFR, ptBR,
ruRU, koKR, zhCN, zhTW), each with SkillLine.csv of the Era build in
.build.info (wago.tools/db2, with &locale=<language>).

GetSkillLineInfo names a row of the skill window and gives no id, so the
addon tells a row by its name in the client's language. What goes in:
  * every weapon skill, profession and secondary skill (categories 6, 11
    and 9), and the two class skills the addon reads, Poisons and
    Lockpicking: class skills share names (Protection, Holy, Restoration);
  * a line's name in each language. A Horde name of its own (the table
    has the column, no line here uses it) stops the script, and so does a
    name two of these lines share in some language.
"""
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 2:
    sys.exit(__doc__)
DB2 = sys.argv[1]
OUT = os.path.join(ROOT, "MUI_DB", "MUI_SkillLineDB.lua")
LANGUAGES = ["enUS", "deDE", "esES", "esMX", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
CATEGORIES = {6, 9, 11}
CLASS_SKILLS = {40, 633}          # Poisons, Lockpicking


def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


lines = {}
for lang in LANGUAGES:
    with open(os.path.join(DB2, lang, "SkillLine.csv"), encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    seen = {}
    for row in rows:
        id, cat = int(row["ID"]), int(row["CategoryID"])
        if cat not in CATEGORIES and id not in CLASS_SKILLS:
            continue
        name = row["DisplayName_lang"]
        if not name:
            sys.exit(f"{lang}: skill line {id} has no name")
        if row["HordeDisplayName_lang"] not in ("", name):
            sys.exit(f"{lang}: skill line {id} has a Horde name, {row['HordeDisplayName_lang']!r}")
        if seen.get(name, id) != id:
            sys.exit(f"{lang}: {name!r} names skill lines {seen[name]} and {id}")
        seen[name] = id
        lines.setdefault(id, {"cat": cat, "names": {}})["names"][lang] = name

out = [
    "-- MUI_SkillLineDB.lua  (AUTO-GENERATED — do not edit)",
    "-- Regenerate via: python tools/skilllines_export.py <db2 dir>",
    "--",
    "-- The skill lines the addon reads off the skill window, by the name the",
    "-- client gives each in its language: GetSkillLineInfo names a row and",
    "-- gives no id. The weapon skills, professions and secondary skills, and",
    "-- the class skills Poisons and Lockpicking (class skills share names).",
    "--",
    "--   MUI_SkillLineDB:GetByName(name)   skill line id and category of a",
    "--                                     row (6 weapon skills, 9 secondary",
    "--                                     skills, 11 professions), or nil",
    "--   MUI_SkillLineDB:GetName(id[, language])",
    "--                                     a line's name, in the client's",
    "--                                     language or the one asked for",
    'object "SkillLineDB" {',
    "    __init = function(self)",
    "        local language = GetLocale()",
    "        self._byName = {}",
    "        for id, line in pairs(self._lines) do",
    "            self._byName[line[language] or line.enUS] = id",
    "        end",
    "    end;",
    "",
    "    GetByName = function(self, name)",
    "        local id = self._byName[name]",
    "        if id then return id, self._lines[id].cat end",
    "    end;",
    "",
    "    GetName = function(self, id, language)",
    "        local line = self._lines[id]",
    "        return line[language or GetLocale()] or line.enUS",
    "    end;",
    "",
    "    -- [skill line id] = { cat = category, <language> = name }",
    "    _lines = {",
]
for id in sorted(lines):
    line = lines[id]
    missing = [lang for lang in LANGUAGES if lang not in line["names"]]
    if missing:
        sys.exit(f"skill line {id} is missing in {', '.join(missing)}")
    out.append(f"        [{id}] = {{ cat = {line['cat']},")
    for lang in LANGUAGES:
        out.append(f"            {lang} = {lua(line['names'][lang])},")
    out.append("        },")
out += ["    },", "}", ""]

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out))
print(f"{len(lines)} skill lines -> {os.path.relpath(OUT, ROOT)}")
