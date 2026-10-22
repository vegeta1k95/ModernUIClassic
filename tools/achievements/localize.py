"""
The achievements' text in every client language: MUI_DB/Locale/<lang>.lua's
"achievements" block, which MUI_AchievementDB:Localize applies. Called by
export.py when it is given --retail and --era.

Where each text comes from, in this order:
  * a category, an achievement's name and its description: retail's
    Achievement_Category / Achievement row with the same English text
    (the achievement's own row first, found by its name);
  * a criterion's label, and a name no retail row has: the name of what
    the criterion counts, by id, where the English is that name: a
    creature, quest or item (Questie's lookups), a spell or a faction (the
    Era client's tables); failing that, the one creature, quest, item, area
    or spell with that English name;
  * the rest: tools/i18n/<lang>.json, the addon's own translations, keyed
    as tools/i18n/source/achievements.json lists them (written here, with
    the English and where it shows).
"""
import collections
import csv
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
sys.path.insert(0, os.path.join(TOOLS, "questdb_export"))
import locale_data  # noqa: E402
import locale_export  # noqa: E402

TOOL = "tools/achievements/export.py"
I18N = os.path.join(TOOLS, "i18n")
QUESTIE = os.path.join(TOOLS, "vendor", "Questie")
csv.field_size_limit(10 ** 9)


def table(folder, lang, name, column):
    with open(os.path.join(folder, lang, name + ".csv"), encoding="utf-8", newline="") as f:
        return {int(r["ID"]): r[column] for r in csv.DictReader(f)}


def first(ids):
    if isinstance(ids, list):
        return ids[0] if ids else None
    return ids


def entities(c):
    """(kind, id) of what a labelled criterion (or list entry) counts."""
    out = []
    if c.get("npc"):
        out.append(("npc", first(c["npc"])))
    if c.get("fid"):
        out.append(("faction", c["fid"]))
    for key in ("spell", "spells"):
        if c.get(key):
            out.append(("spell", first(c[key])))
    for key in ("item", "id"):
        if c.get(key):
            out.append(("item", first(c[key])))
    if c.get("any"):
        out.append(("quest", first(c["any"])))
        out.append(("item", first(c["any"])))
    return out


def labelled(d):
    """(path, entry, label) of every label an achievement's criterion shows."""
    crit = d["crit"]
    if isinstance(crit.get("label"), str):
        yield ("label",), crit, crit["label"]
    for i, text in enumerate(crit.get("labels") or [], 1):
        yield ("labels", i), crit, text
    for key in ("list", "items"):
        for i, entry in enumerate(crit.get(key) or [], 1):
            if isinstance(entry, dict) and isinstance(entry.get("label"), str):
                yield (key, i), entry, entry["label"]


def write(defs, categories, retail, era):
    english_npcs = locale_export.english("MUI_NpcDB.lua")
    english_quests = locale_export.english("MUI_QuestDB.lua")
    english_items = locale_export.english("MUI_ItemDB.lua")
    english = {
        "npc": {i: r.get("name") for i, r in english_npcs.items()},
        "quest": {i: r.get("name") for i, r in english_quests.items()},
        "item": {i: r.get("name") for i, r in english_items.items()},
        "spell": table(era, "enUS", "SpellName", "Name_lang"),
        "faction": table(era, "enUS", "Faction", "Name_lang"),
        "area": table(era, "enUS", "AreaTable", "AreaName_lang"),
    }
    # the one thing of a kind with an English name (None when several)
    unique = {}
    for kind in ("npc", "quest", "item", "area", "spell"):
        seen = {}
        for i, name in english[kind].items():
            if name:
                seen[name] = None if name in seen else i
        unique[kind] = seen

    # every thing of that English name, the criterion's own first: a language
    # may lack one (Questie's lookups have gaps) and have another
    def by_name(text, entry):
        sources = [(kind, i) for kind, i in entities(entry) if i and english[kind].get(i) == text][:1]
        for kind in ("npc", "quest", "item", "area", "spell"):
            if unique[kind].get(text) and (kind, unique[kind][text]) not in sources:
                sources.append((kind, unique[kind][text]))
        return sources
    titles = table(retail, "enUS", "Achievement", "Title_lang")
    descs = table(retail, "enUS", "Achievement", "Description_lang")
    by_title, by_desc = collections.defaultdict(list), collections.defaultdict(list)
    for i, t in titles.items():
        by_title[t].append(i)
    for i, t in descs.items():
        by_desc[t].append(i)
    cat_names = table(retail, "enUS", "Achievement_Category", "Name_lang")
    cat_by_name = {}
    for i, n in sorted(cat_names.items()):
        cat_by_name.setdefault(n, i)

    # what each text's Blizzard source is, or that it is ours
    plan_cats, plan_ach, ours = {}, {}, {}
    for c in categories:
        if c["name"] in cat_by_name:
            plan_cats[c["id"]] = ("category", cat_by_name[c["name"]])
        else:
            ours[f"achievements/cat/{c['id']}"] = {"en": c["name"], "note": "an achievement category"}
    for d in defs:
        plan = {}
        rows = by_title.get(d["name"], [])
        same = [r for r in rows if descs.get(r) == d["desc"]]
        named = by_name(d["name"], d["crit"])
        if rows:
            plan["name"] = [("title", (same or rows)[0])]
        elif named:
            plan["name"] = named
        else:
            ours[f"achievements/{d['id']}/name"] = {"en": d["name"], "note": "an achievement's name"}
        if same:
            plan["desc"] = [("desc", same[0])]
        elif len(by_desc.get(d["desc"], [])) >= 1:
            plan["desc"] = [("desc", by_desc[d["desc"]][0])]
        else:
            ours[f"achievements/{d['id']}/desc"] = {"en": d["desc"], "note": f"the description of the achievement \"{d['name']}\""}
        for path, entry, text in labelled(d):
            source = by_name(text, entry)
            if source:
                plan[path] = source
            else:
                key = f"achievements/{d['id']}/" + ".".join(str(p) for p in path)
                ours[key] = {"en": text, "note": f"a criterion of the achievement \"{d['name']}\" ({d['desc']})"}
        plan_ach[d["id"]] = plan

    for lang in locale_data.LANGUAGES:
        names = {
            "npc": {}, "quest": {}, "item": {},
            "spell": table(era, lang, "SpellName", "Name_lang"),
            "faction": table(era, lang, "Faction", "Name_lang"),
            "area": table(era, lang, "AreaTable", "AreaName_lang"),
        }
        names["npc"] = locale_export.npc_names(QUESTIE, retail, lang, english["npc"])
        for i, e in locale_export.lookup(QUESTIE, "lookupQuests", lang).items():
            if isinstance(e, list) and e and isinstance(e[0], str):
                names["quest"][i] = e[0]
        for i, e in locale_export.lookup(QUESTIE, "lookupItems", lang).items():
            if isinstance(e, str):
                names["item"][i] = e
        names["item"].update(locale_export.item_names(era, lang))
        loc_titles = table(retail, lang, "Achievement", "Title_lang")
        loc_descs = table(retail, lang, "Achievement", "Description_lang")
        loc_cats = table(retail, lang, "Achievement_Category", "Name_lang")
        mine = {}
        path = os.path.join(I18N, lang + ".json")
        if os.path.exists(path):
            mine = json.load(open(path, encoding="utf-8"))

        def resolve(source):
            kind, i = source
            if kind == "title":
                return loc_titles.get(i)
            if kind == "desc":
                return loc_descs.get(i)
            if kind == "category":
                return loc_cats.get(i)
            return names[kind].get(i)

        def resolve_first(sources):
            return next((text for text in map(resolve, sources) if text), None)

        cats = {}
        for c in categories:
            text = resolve(plan_cats[c["id"]]) if c["id"] in plan_cats else mine.get(f"achievements/cat/{c['id']}")
            if text and text != c["name"]:
                cats[c["id"]] = text
        # a Blizzard text this language lacks is ours as well, for every language
        def text_for(key, plan, field, english_text, note):
            found = resolve_first(plan[field]) if field in plan else None
            if field in plan and not found:
                ours.setdefault(key, {"en": english_text, "note": note})
            return found or mine.get(key)

        ach = {}
        missing = []
        for d in defs:
            out = {}
            plan = plan_ach[d["id"]]
            for field in ("name", "desc"):
                key = f"achievements/{d['id']}/{field}"
                note = "an achievement's name" if field == "name" else f"the description of the achievement \"{d['name']}\""
                text = text_for(key, plan, field, d[field], note)
                if text and text != d[field]:
                    out[field] = text
                elif not text:
                    missing.append(key)
            for p, entry, english_text in labelled(d):
                key = f"achievements/{d['id']}/" + ".".join(str(x) for x in p)
                text = text_for(key, plan, p, english_text, f"a criterion of the achievement \"{d['name']}\" ({d['desc']})")
                if not text:
                    missing.append(key)
                    continue
                if text == english_text:
                    continue
                if p == ("label",):
                    out["label"] = text
                else:
                    out.setdefault(p[0], {})[p[1]] = text
            if out:
                ach[d["id"]] = out
        lines = [f"MUI_AchievementDB:Localize({locale_data.loadstring({'cats': cats, 'ach': ach})})"]
        locale_data.write_block(lang, "achievements", TOOL, lines)
        print(f"{lang}: {len(ach)} achievements, {len(cats)} categories in the language; {len(missing)} texts still English"
              + (" (" + ", ".join(missing[:5]) + ")" if missing else ""))
    os.makedirs(os.path.join(I18N, "source"), exist_ok=True)
    with open(os.path.join(I18N, "source", "achievements.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(ours, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"ours to translate: {len(ours)} (tools/i18n/source/achievements.json)")
    write_statistics(retail, titles, cat_by_name)


def write_statistics(retail, titles, cat_by_name):
    """MUI_StatisticsDB's names (hand-written; most are retail's statistics):
    the "statistics" block, the rest ours (tools/i18n/source/statistics.json)."""
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function object(n) return function(def) local i = setmetatable({}, {__index = def})"
                " if def.__init then def.__init(i) end _G['MUI_' .. n] = i end end")
    path = os.path.join(os.path.dirname(TOOLS), "MUI_DB", "MUI_StatisticsDB.lua")
    lua.execute(open(path, encoding="utf-8").read())
    db = lua.globals().MUI_StatisticsDB
    cats = [(int(c.id), c.name) for c in db._categories.values()]
    stats = [(s.key + ("/" + s.kind if s.kind else ""), s.name) for s in db._list.values()]
    by_title = {}
    for i, t in sorted(titles.items()):
        by_title.setdefault(t, i)
    ours = {}
    for cid, name in cats:
        if name not in cat_by_name:
            ours[f"statistics/cat/{cid}"] = {"en": name, "note": "a category of the Statistics tab"}
    for key, name in stats:
        if name not in by_title:
            ours[f"statistics/{key}"] = {"en": name, "note": "a statistic's name (a number follows it)"}
    with open(os.path.join(I18N, "source", "statistics.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(ours, f, ensure_ascii=False, indent=1)
        f.write("\n")
    for lang in locale_data.LANGUAGES:
        loc_titles = table(retail, lang, "Achievement", "Title_lang")
        loc_cats = table(retail, lang, "Achievement_Category", "Name_lang")
        path = os.path.join(I18N, lang + ".json")
        mine = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        out = {"cats": {}, "stats": {}}
        for cid, name in cats:
            text = loc_cats.get(cat_by_name[name]) if name in cat_by_name else mine.get(f"statistics/cat/{cid}")
            if text and text != name:
                out["cats"][cid] = text
        for key, name in stats:
            text = loc_titles.get(by_title[name]) if name in by_title else mine.get(f"statistics/{key}")
            if text and text != name:
                out["stats"][key] = text
        lines = [f"MUI_StatisticsDB:Localize({locale_data.loadstring(out)})"]
        locale_data.write_block(lang, "statistics", TOOL, lines)
        print(f"{lang}: {len(out['stats'])} of {len(stats)} statistics in the language")
    print(f"ours to translate: {len(ours)} (tools/i18n/source/statistics.json)")
