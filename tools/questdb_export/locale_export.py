"""
Put the quest, creature, object and item names of MUI_DB's Questie tables
(and the quests' objective texts, the creatures' titles) in every client
language into MUI_DB/Locale/<lang>.lua.

    python tools/questdb_export/locale_export.py --retail <dir> --era <dir> [--questie <path>]

Blizzard's own names come first, Questie's per-language lookups (GPLv3,
like the tables; they have mistakes) only where Blizzard has none:
  * items: Era's ItemSparse (<era>/<lang>/ItemSparse.csv), the client's
    own table;
  * creatures: retail's journal (<retail>/<lang>/JournalEncounter.csv and
    JournalEncounterCreature.csv) for the bosses and their creatures, the
    rest from Questie;
  * quests and objects: Questie (no client table has them; the quest
    helper asks the client for a quest's title at run time).

Only the ids MUI_QuestDB / MUI_NpcDB / MUI_ObjectDB / MUI_ItemDB hold go
in, and a name only where it is not the English one. Needs lupa (the
lookups are Lua and are evaluated, not parsed).
"""
import argparse
import csv
import os
import re
import sys

from lupa.lua51 import LuaRuntime, lua_type

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
import locale_data  # noqa: E402

TOOL = "tools/questdb_export/locale_export.py"
DB = os.path.join(ROOT, "MUI_DB")
ROW = re.compile(r"^        \[(\d+)\] = \{")
FIELD = re.compile(r"^            (name|subName) = (\".*\"|'.*'),\r?$")
OPEN = re.compile(r"loadstring\(\[(=*)\[")


def english(name):
    """id -> {"name": ..., "subName": ...} of a generated MUI_DB table."""
    rows, current = {}, None
    with open(os.path.join(DB, name), encoding="utf-8") as f:
        for line in f:
            m = ROW.match(line)
            if m:
                current = rows.setdefault(int(m.group(1)), {})
                continue
            m = FIELD.match(line)
            if m and current is not None:
                current[m.group(1)] = eval_string(m.group(2))
    return rows


def eval_string(literal):
    return lua.execute("return " + literal)


def lookup(questie, kind, lang):
    """A Questie lookup file's table, as Python values."""
    path = os.path.join(questie, "Localization", "lookups", "Classic", kind, lang + ".lua")
    src = open(path, encoding="utf-8").read()
    m = OPEN.search(src)
    close = "]" + m.group(1) + "]"
    payload = src[m.end():src.index(close, m.end())]
    return to_python(lua.execute(payload))


def to_python(value):
    if lua_type(value) != "table":
        return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [to_python(value[k]) for k in sorted(keys)]
    return {k: to_python(v) for k, v in value.items()}


def csv_rows(path):
    with open(path, encoding="utf-8", newline="") as f:
        return {int(r["ID"]): r for r in csv.DictReader(f)}


def item_names(era, lang):
    """id -> an item's name in the language, from Era's ItemSparse."""
    return {i: r["Display_lang"] for i, r in csv_rows(os.path.join(era, lang, "ItemSparse.csv")).items()
            if r["Display_lang"]}


def journal_instances():
    """The retail journal instance ids of the Adventure Guide's dungeons and raids."""
    src = open(os.path.join(DB, "MUI_EncounterJournalDB.lua"), encoding="utf-8").read()
    return {int(i) for i in re.findall(r"^\s*\{ id = (\d+), name = \"(?:[^\"\\]|\\.)*\",[^\n]*\bbutton = ", src, re.M)}


def journal_npc_names(retail, lang, npcs):
    """id -> a creature's name in the language as retail's journal has it (the
    bosses of Era's dungeons and raids and their creatures), for each of `npcs`
    (id -> English name) whose English name the journal gives one name in the
    language. Other expansions' journal entries are left out: a creature there
    may share an English name and not be the same."""
    instances = journal_instances()
    encounters = {i for i, r in csv_rows(os.path.join(retail, "enUS", "JournalEncounter.csv")).items()
                  if int(r["JournalInstanceID"] or 0) in instances}
    by_english = {}
    for table, owner in (("JournalEncounter", "ID"), ("JournalEncounterCreature", "JournalEncounterID")):
        english_rows = csv_rows(os.path.join(retail, "enUS", table + ".csv"))
        local_rows = csv_rows(os.path.join(retail, lang, table + ".csv"))
        for i, r in english_rows.items():
            local = local_rows.get(i, {}).get("Name_lang")
            if r["Name_lang"] and local and int(r[owner] or 0) in encounters:
                by_english.setdefault(r["Name_lang"], set()).add(local)
    return {i: next(iter(by_english[name])) for i, name in npcs.items()
            if name and len(by_english.get(name, ())) == 1}


def npc_names(questie, retail, lang, npcs):
    """id -> a creature's name in the language: retail's journal's, else Questie's."""
    names = {i: e[0] for i, e in lookup(questie, "lookupNpcs", lang).items()
             if isinstance(e, list) and e and isinstance(e[0], str)}
    names.update(journal_npc_names(retail, lang, npcs))
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("--questie", default=os.path.join(ROOT, "tools", "vendor", "Questie"))
    parser.add_argument("--retail", required=True)
    parser.add_argument("--era", required=True)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    quests, npcs = english("MUI_QuestDB.lua"), english("MUI_NpcDB.lua")
    objects, items = english("MUI_ObjectDB.lua"), english("MUI_ItemDB.lua")
    npc_english = {i: r.get("name") for i, r in npcs.items()}
    for lang in locale_data.LANGUAGES:
        journal = journal_npc_names(args.retail, lang, npc_english)
        out_quests = {}
        for qid, entry in sorted(lookup(args.questie, "lookupQuests", lang).items()):
            if qid not in quests or not isinstance(entry, (list, dict)):
                continue
            entry = entry if isinstance(entry, list) else [entry.get(1), entry.get(2)]
            title = entry[0] if entry and isinstance(entry[0], str) else None
            texts = entry[1] if len(entry) > 1 and isinstance(entry[1], list) else None
            texts = [t for t in texts if isinstance(t, str)] if texts else None
            if title == quests[qid].get("name"):
                title = None
            if title or texts:
                out_quests[qid] = [title, texts]
        out_npcs = {}
        questie_npcs = lookup(args.questie, "lookupNpcs", lang)
        for nid in sorted(set(questie_npcs) | set(journal)):
            if nid not in npcs:
                continue
            entry = questie_npcs.get(nid) or []
            entry = entry if isinstance(entry, list) else [entry.get(1), entry.get(2)]
            name = journal.get(nid) or (entry[0] if entry else None)
            sub = entry[1] if len(entry) > 1 else None
            if not isinstance(name, str):
                continue
            if sub and npcs[nid].get("subName") and sub != npcs[nid]["subName"]:
                out_npcs[nid] = [name, sub]
            elif name != npcs[nid].get("name"):
                out_npcs[nid] = name
        out_objects = {i: n for i, n in sorted(lookup(args.questie, "lookupObjects", lang).items())
                       if i in objects and isinstance(n, str) and n != objects[i].get("name")}
        questie_items = lookup(args.questie, "lookupItems", lang)
        era_items = item_names(args.era, lang)
        out_items = {}
        for i in sorted(items):
            name = era_items.get(i) or questie_items.get(i)
            if isinstance(name, str) and name != items[i].get("name"):
                out_items[i] = name
        lines = [
            f"MUI_QuestDB:Localize({locale_data.loadstring(out_quests)})",
            f"MUI_NpcDB:Localize({locale_data.loadstring(out_npcs)})",
            f"MUI_ObjectDB:Localize({locale_data.loadstring(out_objects)})",
            f"MUI_ItemDB:Localize({locale_data.loadstring(out_items)})",
        ]
        path = locale_data.write_block(lang, "quests, creatures, objects and items", TOOL, lines)
        print(f"{lang}: {len(out_quests)} quests, {len(out_npcs)} creatures, "
              f"{len(out_objects)} objects, {len(out_items)} items, {os.path.getsize(path) // 1024} KB")


lua = LuaRuntime(unpack_returned_tuples=True)

if __name__ == "__main__":
    main()
