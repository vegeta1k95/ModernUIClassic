"""
Merge base DB + corrections + faction fixes + blacklists into final named-field
Python dicts, then serialize as Lua singleton-class files.

Output shape (per file) — each generated DB is a singleton class with both
its accessors and its data in one file; data is pretty-printed (short
values inline, long values break across lines with 4-space indentation):

    -- MUI_QuestDB.lua  (AUTO-GENERATED — do not edit)
    -- Derived from Questie v<VER> (GPLv3). See ModernUI/ATTRIBUTION.md.
    object "QuestDB" {

        Get = function(self, id) return self._data and self._data[id] end;
        ...

        _data = {
            [2] = {
                name = "Sharptalon's Claw",
                startedBy = {nil, nil, {16305}},
                ...
            },
            ...
        },
    }
"""

from __future__ import annotations
from pathlib import Path
from typing import Any

from lua_parser import LUA_NIL


# ------------------------------------------------------------- merging utils

def apply_corrections(base: dict[int, list], corrections: dict[int, dict]) -> None:
    """Merge sparse field-level corrections into positional base rows.
    Mirrors Questie's `addOverride` at QuestieCorrections.lua:107–123."""
    for ent_id, patch in corrections.items():
        if not isinstance(patch, dict):
            continue
        row = base.get(ent_id)
        if row is None:
            # Correction introduces a new entity — start with empty row
            row = []
            base[ent_id] = row
        for key, value in patch.items():
            if not isinstance(key, int):
                continue
            # Grow row if needed (positional, 1-based in Lua)
            idx = key - 1
            while len(row) <= idx:
                row.append(LUA_NIL)
            row[idx] = value


def add_missing(base: dict[int, list], missing_ids: list[int]) -> None:
    """LoadMissingQuests creates empty placeholder rows to be patched by
    subsequent corrections. Equivalent to `QuestieDB.questData[id] = {}`."""
    for qid in missing_ids:
        if qid not in base:
            base[qid] = []


def drop_blacklisted(base: dict[int, list], blacklist: set[int]) -> int:
    """Remove every ID in the blacklist from the base table."""
    dropped = 0
    for bid in blacklist:
        if bid in base:
            del base[bid]
            dropped += 1
    return dropped


# ------------------------------------------------------- faction auto-patch

def apply_faction_autopatch(quests: dict[int, list], npcs: dict[int, list],
                            quest_keys: dict[str, int], npc_keys: dict[str, int],
                            race_ally: int, race_horde: int) -> int:
    """Mirror QuestieCorrections.lua:297–334. For quests with no/zero
    requiredRaces, infer from startedBy NPC's friendlyToFaction field."""
    rr_idx = quest_keys["requiredRaces"] - 1
    sb_idx = quest_keys["startedBy"] - 1
    ftf_idx = npc_keys["friendlyToFaction"] - 1
    patched = 0
    for qid, row in quests.items():
        rr = row[rr_idx] if len(row) > rr_idx else LUA_NIL
        if rr not in (LUA_NIL, None, 0):
            continue
        starts = row[sb_idx] if len(row) > sb_idx else LUA_NIL
        if not isinstance(starts, list) or not starts:
            continue
        creature_start = starts[0]
        if not isinstance(creature_start, list):
            continue
        can_horde = False
        can_alliance = False
        for npc_id in creature_start:
            if not isinstance(npc_id, int):
                continue
            npc = npcs.get(npc_id)
            if not npc or len(npc) <= ftf_idx:
                continue
            friendly = npc[ftf_idx]
            if friendly == "H":   can_horde = True
            elif friendly == "A": can_alliance = True
            elif friendly == "AH":
                can_alliance = True; can_horde = True
        if can_alliance != can_horde:
            new_rr = race_ally if can_alliance else race_horde
            while len(row) <= rr_idx:
                row.append(LUA_NIL)
            row[rr_idx] = new_rr
            patched += 1
    return patched


# ------------------------------------------- objective reverse index (custom)

def _objectives_category(objs: Any, cat: int) -> Any:
    """Return the list of entries at Lua position `cat` inside a parsed
    `objectives` value. Handles both list-shaped (all positions present)
    and dict-shaped (sparse nil padding) representations, and LUA_NIL
    holes. Returns None when the category is missing."""
    if isinstance(objs, list):
        if len(objs) >= cat:
            v = objs[cat - 1]
            return None if v is LUA_NIL else v
        return None
    if isinstance(objs, dict):
        v = objs.get(cat)
        return None if v is LUA_NIL else v
    return None


def _entry_target_id(entry: Any) -> int | None:
    """Each objective entry is `{targetId[, ...]}` in Lua. Extract the
    leading integer, tolerating both list and dict representations."""
    if isinstance(entry, list):
        if entry and entry[0] is not LUA_NIL and isinstance(entry[0], int):
            return entry[0]
    elif isinstance(entry, dict):
        v = entry.get(1)
        if v is not LUA_NIL and isinstance(v, int):
            return v
    return None


def _entries_of(v: Any):
    """Yield non-nil entries from a list- or dict-shaped Lua table value."""
    if isinstance(v, list):
        for e in v:
            if e is not LUA_NIL:
                yield e
    elif isinstance(v, dict):
        for e in v.values():
            if e is not LUA_NIL:
                yield e


def _is_singular_count_quest(objectives_text: Any) -> bool:
    """Heuristic: return True iff the quest's `objectivesText` has no digits
    anywhere. Questie stores count as plain text ("Kill 15 X", "Bring 12 Y");
    single-count objectives omit the number ("Kill Hogger", "Bring the Head").
    Classic DB has no per-objective required-count field, so this is the only
    signal we can read offline. Quests with no objectivesText fail closed."""
    if objectives_text is None or objectives_text is LUA_NIL:
        return False
    def _scan(s: Any) -> bool:
        if isinstance(s, str):
            for ch in s:
                if ch.isdigit():
                    return True
        return False
    if isinstance(objectives_text, str):
        return not _scan(objectives_text)
    if isinstance(objectives_text, list):
        return not any(_scan(s) for s in objectives_text)
    if isinstance(objectives_text, dict):
        return not any(_scan(s) for s in objectives_text.values())
    return False


def build_objective_reverse_index(
    quests:  dict[int, dict],
    npcs:    dict[int, dict],
    objects: dict[int, dict],
    items:   dict[int, dict],
) -> tuple[int, int]:
    """Populate `questObjective = [questId, ...]` on NPC / Object rows
    whose id is a SINGULAR quest-important target — killing / interacting
    / looting them constitutes a 0/1 objective (not a 0/N farming task).
    Filter: the quest's objectivesText must contain no digits (Questie
    text uses plain numerals for every count > 1; single-count objectives
    omit them). Covers:
      * objectives[1] creature kills            → npcs
      * objectives[5] killCredit                → npcs
      * objectives[2] object interactions       → objects
      * objectives[3] item collect, where the item's `npcDrops`
        references an NPC                       → npcs
      * objectives[3] item collect, where the item's `objectDrops`
        references an object                   → objects
    Finisher NPCs / objects are NOT included (those are turn-in hints,
    not kill/loot targets).
    Returns (#npcs patched, #objects patched)."""
    npc_map: dict[int, set[int]] = {}
    obj_map: dict[int, set[int]] = {}

    def add_npc(npc_id, qid):
        if isinstance(npc_id, int):
            npc_map.setdefault(npc_id, set()).add(qid)

    def add_obj(obj_id, qid):
        if isinstance(obj_id, int):
            obj_map.setdefault(obj_id, set()).add(qid)

    for qid, q in quests.items():
        objs = q.get("objectives")
        if objs is None or objs is LUA_NIL:
            continue
        if not _is_singular_count_quest(q.get("objectivesText")):
            continue
        # Direct NPC kill targets.
        for cat in (1, 5):
            entries = _objectives_category(objs, cat)
            if entries:
                for e in _entries_of(entries):
                    add_npc(_entry_target_id(e), qid)
        # Direct object interaction targets.
        entries = _objectives_category(objs, 2)
        if entries:
            for e in _entries_of(entries):
                add_obj(_entry_target_id(e), qid)
        # Item collect: follow the item's drop sources so every NPC /
        # object that can drop the quest item gets tagged too.
        entries = _objectives_category(objs, 3)
        if entries:
            for e in _entries_of(entries):
                item_id = _entry_target_id(e)
                if item_id is None:
                    continue
                item = items.get(item_id)
                if item is None:
                    continue
                npc_drops = item.get("npcDrops")
                if npc_drops is not None and npc_drops is not LUA_NIL:
                    for src in _entries_of(npc_drops):
                        if isinstance(src, int):
                            add_npc(src, qid)
                obj_drops = item.get("objectDrops")
                if obj_drops is not None and obj_drops is not LUA_NIL:
                    for src in _entries_of(obj_drops):
                        if isinstance(src, int):
                            add_obj(src, qid)

    n_patched, o_patched = 0, 0
    for npc_id, qids in npc_map.items():
        rec = npcs.get(npc_id)
        if rec is not None:
            rec["questObjective"] = sorted(qids)
            n_patched += 1
    for obj_id, qids in obj_map.items():
        rec = objects.get(obj_id)
        if rec is not None:
            rec["questObjective"] = sorted(qids)
            o_patched += 1
    return n_patched, o_patched


# ----------------------------------------------- repeatable turn-in tagging

def mark_repeatable_turn_ins(
    quests: dict[int, dict],
    items:  dict[int, dict],
) -> int:
    """Tag repeatables that are pure DELIVERY quests — "Additional
    Runecloth"-style turn-ins where the player just hands over generic
    materials. These differ from real repeatables (kill X, gather Y) in
    that they have no kill / interact objectives and the items asked
    for are non-quest-class (Trade Goods, recipes, etc.) rather than
    quest-bound items.

    Heuristic per quest:
      * specialFlags bit 0 (REPEATABLE) is set, AND
      * objectives[1] (creature kills) is empty, AND
      * objectives[2] (object interactions) is empty, AND
      * objectives[3] (item delivery) is non-empty, AND
      * every required item has class != 12 (i.e. not a quest item;
        12 is Enum.ItemClass.Quest).

    Stored as `isRepeatableTurnIn = True`; absent / nil otherwise so
    serialized output stays small. Returns the count of tagged quests."""
    tagged = 0
    for qid, q in quests.items():
        sf = q.get("specialFlags")
        if not isinstance(sf, int) or (sf & 1) == 0:
            continue
        objs = q.get("objectives")
        if objs is None or objs is LUA_NIL:
            continue

        # Bail if there's any kill or interact target.
        kills = _objectives_category(objs, 1)
        if kills:
            for e in _entries_of(kills):
                if _entry_target_id(e) is not None:
                    kills = True
                    break
            else:
                kills = None
        if kills:
            continue
        interacts = _objectives_category(objs, 2)
        if interacts:
            for e in _entries_of(interacts):
                if _entry_target_id(e) is not None:
                    interacts = True
                    break
            else:
                interacts = None
        if interacts:
            continue

        # Need at least one item entry; every item must be non-quest-class.
        # Items missing from `items` are blacklisted upstream by Questie
        # (QuestieItemBlacklist.lua) — which only ever lists generic
        # trade goods / common drops (Runecloth, Linen Cloth, ore, etc.),
        # NEVER quest-class items. So a missing item is positive evidence
        # of a turn-in quest, not negative; treat it as non-quest-class.
        item_entries = _objectives_category(objs, 3)
        if not item_entries:
            continue
        any_item    = False
        only_trade  = True
        for e in _entries_of(item_entries):
            iid = _entry_target_id(e)
            if iid is None:
                continue
            any_item = True
            it = items.get(iid)
            if it is not None and it.get("class") == 12:  # Enum.ItemClass.Quest
                only_trade = False
                break
        if not any_item or not only_trade:
            continue

        q["isRepeatableTurnIn"] = True
        tagged += 1
    return tagged


# --------------------------------------------- positional → named conversion

def positional_to_named(rows: dict[int, list], keys: dict[str, int]) -> dict[int, dict]:
    """Convert positional arrays to dicts keyed by field name. Drops fields
    whose value is LUA_NIL (saves output size — missing field = nil at runtime)."""
    # Build reverse: index → field name
    rev = {idx: name for name, idx in keys.items()}
    out: dict[int, dict] = {}
    for ent_id, row in rows.items():
        named: dict[str, Any] = {}
        for i, v in enumerate(row):
            name = rev.get(i + 1)  # keys are 1-based
            if name is None:
                continue
            if v is LUA_NIL:
                continue
            named[name] = v
        out[ent_id] = named
    return out


# ----------------------------------------------------------- serializer (Lua)

# Width threshold for pretty-printer: values whose compact form is at most
# this many characters stay inline; longer ones break across lines. Pick a
# value tuned so most numeric/short-string rows stay readable on one line
# while dense quest/cluster rows wrap.
_PRETTY_WIDTH = 80
_INDENT = "    "  # 4 spaces per level


_LUA_KEYWORDS = frozenset({
    "and", "break", "do", "else", "elseif", "end", "false", "for",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
})


def _lua_value(v: Any) -> str:
    """Single-line Lua serializer. Uses ` = ` around dict assignments and
    `, ` after commas for readability. Output never contains newlines —
    used both as the everywhere-compact form and as the size-probe for
    `_lua_value_pretty`."""
    if v is LUA_NIL or v is None:
        return "nil"
    if v is True:  return "true"
    if v is False: return "false"
    if isinstance(v, (int, float)):
        # Lua accepts the same numeric forms Python emits.
        if isinstance(v, float) and v.is_integer():
            return str(int(v))
        return str(v)
    if isinstance(v, str):
        return _lua_string(v)
    if isinstance(v, list):
        return "{" + ", ".join(_lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        # Emit integer-keyed entries in sorted order first, then string keys.
        int_items = sorted((k for k in v if isinstance(k, int)))
        str_items = sorted((k for k in v if isinstance(k, str)))
        for k in int_items:
            parts.append(f"[{k}] = {_lua_value(v[k])}")
        for k in str_items:
            # Emit as name=value if the key is a safe Lua identifier, else [name]=value.
            if k.isidentifier() and k not in _LUA_KEYWORDS:
                parts.append(f"{k} = {_lua_value(v[k])}")
            else:
                parts.append(f"[{_lua_string(k)}] = {_lua_value(v[k])}")
        return "{" + ", ".join(parts) + "}"
    raise TypeError(f"cannot serialize {type(v).__name__}: {v!r}")


def _is_numeric_leaf_array(v: Any) -> bool:
    """True iff v is a non-empty list whose every leaf (recursing through
    nested lists) is a Lua number — no nils, booleans, strings, or dicts.
    Used by the pretty-printer to keep coord/id arrays on one line."""
    if not isinstance(v, list) or not v:
        return False
    for x in v:
        if isinstance(x, bool):
            return False
        if isinstance(x, (int, float)):
            continue
        if isinstance(x, list) and _is_numeric_leaf_array(x):
            continue
        return False
    return True


def _lua_value_pretty(v: Any, indent: int = 0, width: int = _PRETTY_WIDTH) -> str:
    """Pretty-print v as Lua source. Returns the compact single-line form
    when it is at most `width` characters; otherwise breaks across lines
    indented by `indent` spaces (children at `indent + 4`). `indent` is
    the column of the OPENING brace's enclosing context — the returned
    string assumes the caller already placed the cursor at `indent` and
    only adds indentation on continuation lines."""
    compact = _lua_value(v)
    if len(compact) <= width:
        return compact

    # Numeric-leaf arrays stay on one line regardless of length — covers
    # both flat `{193, 818, 1046, ...}` (npcDrops/objectDrops/etc.) and
    # nested coordinate arrays `{{46.17, 38.96}, {46.73, 39.7}, ...}`
    # (spawns / hulls). Breaking these vertically just produces hundreds
    # of useless one-number lines.
    if _is_numeric_leaf_array(v):
        return compact

    pad       = " " * (indent + len(_INDENT))
    pad_close = " " * indent

    if isinstance(v, list):
        if not v:
            return "{}"
        lines = ["{"]
        for x in v:
            lines.append(f"{pad}{_lua_value_pretty(x, indent + len(_INDENT), width)},")
        lines.append(f"{pad_close}}}")
        return "\n".join(lines)

    if isinstance(v, dict):
        if not v:
            return "{}"
        int_keys = sorted(k for k in v if isinstance(k, int))
        str_keys = sorted(k for k in v if isinstance(k, str))
        lines = ["{"]
        for k in int_keys:
            val = _lua_value_pretty(v[k], indent + len(_INDENT), width)
            lines.append(f"{pad}[{k}] = {val},")
        for k in str_keys:
            val = _lua_value_pretty(v[k], indent + len(_INDENT), width)
            if k.isidentifier() and k not in _LUA_KEYWORDS:
                lines.append(f"{pad}{k} = {val},")
            else:
                lines.append(f"{pad}[{_lua_string(k)}] = {val},")
        lines.append(f"{pad_close}}}")
        return "\n".join(lines)

    # Primitive whose compact form exceeds width (e.g., a very long string).
    # Nothing to break — emit as-is.
    return compact


def _lua_string(s: str) -> str:
    # Pick the quote style that requires less escaping.
    # Escape backslashes, the quote, and control chars.
    def esc(s: str, q: str) -> str:
        out = []
        for ch in s:
            if ch == "\\":   out.append("\\\\")
            elif ch == q:    out.append("\\" + q)
            elif ch == "\n": out.append("\\n")
            elif ch == "\r": out.append("\\r")
            elif ch == "\t": out.append("\\t")
            elif ch < " ":   out.append(f"\\{ord(ch)}")
            else:            out.append(ch)
        return out and "".join(out) or ""
    dq = esc(s, "\"")
    sq = esc(s, "'")
    if len(sq) < len(dq):
        return "'" + sq + "'"
    return "\"" + dq + "\""


def serialize_singleton(class_name: str, methods: str, data,
                        header_comment: str, data_field: str = "_data") -> str:
    """Serialize a singleton DB file: header + `object "Name" { <methods>;
    <data_field> = <data>; }`. Methods are passed as a raw Lua source
    fragment (already indented). Data is pretty-printed."""
    data_str = _lua_value_pretty(data, indent=len(_INDENT))
    out = [
        header_comment,
        f'object "{class_name}" {{',
        "",
        methods.rstrip(),
        "",
        f"{_INDENT}{data_field} = {data_str},",
        "}",
        "",
    ]
    return "\n".join(out)
