"""
Build per-quest, per-TARGET spawn clusters offline.

Mirrors the runtime logic that lived in:
  - MUI_QuestHelper/MUI_QuestObjectiveResolver.lua  (objective → spawn list)
  - MUI_QuestHelper/MUI_QuestObjectiveCluster.lua   (single-linkage + hull)

Output schema, keyed by questId:
    {
        objectives = [
            { kind, name,
              clusters = [
                { uiMapId, hull = [[nx, ny], ...],
                  centroid = [nx, ny], count },
                ...
              ],
              stray = [ { uiMapId, normX, normY }, ... ],
            },
            ...
        ],
        finisher = [ { uiMapId, normX, normY }, ... ],
    }

`kind` ∈ {"npc", "object", "item", "trigger"}. `name` is the in-game
target name as it appears in the quest log leaderboard line, used at
runtime to filter completed targets via prefix match.

Per-TARGET (not per-category) so a quest like "Kill 10 X, 10 Y, 10 Z" —
which has three creatures all in the creature-kill category — produces
three separate cluster groups. As individual targets complete, the
runtime drops their groups and the remaining cluster centroid stays
accurate (vs. the old per-category scheme which kept the centroid
averaged across all three until ALL completed).

Clustering runs in normalized per-uiMap coords with a fixed threshold
(~0.07). Trade-off: small zones cluster too tightly, large zones too
loosely. Per-zone world bounds aren't shipped in any data we have access
to offline; this approximation works fine for typical "kill 10 X in
this camp" objectives.
"""
from __future__ import annotations
import math

from lua_parser import LUA_NIL


# Single-linkage threshold in normalized space (0-1). 0.07 ≈ 200 yards in
# a typical 3000-yard zone — same neighborhood as the runtime's old
# CLUSTER_RADIUS_YARDS constant.
CLUSTER_THRESHOLD = 0.07
MIN_CLUSTER_SIZE  = 3


# Dungeon-entrance rewrites — mirror MUI_TransportDB._dungeons. Maps a
# dungeon's areaId to (outerAreaId, x_pct, y_pct) of its outer-world
# entrance. Spawns at these inside-instance areaIds are rewritten to point
# at the entrance (their interior coords don't reach the outer continent
# anyway, so we can't aim at them).
DUNGEON_ENTRANCES = {
    209:  (130,  44.8, 67.8),  # Shadowfang Keep → Silverpine
    491:  ( 17,  42.9, 90.2),  # Razorfen Kraul → Barrens
    717:  (1519, 42.3, 58.9),  # The Stockade → Stormwind
    718:  ( 17,  46.0, 36.5),  # Wailing Caverns → Barrens
    719:  (331,  14.5, 14.2),  # Blackfathom Deeps → Ashenvale
    721:  (  1,  24.3, 39.8),  # Gnomeregan → Dun Morogh
    722:  ( 17,  49.0, 93.9),  # Razorfen Downs → Barrens
    796:  ( 85,  82.6, 33.8),  # Scarlet Monastery → Tirisfal
    1176: (440,  38.7, 20.1),  # Zul'Farrak → Tanaris
    1337: (  3,  44.6, 12.1),  # Uldaman → Badlands
    1477: (  8,  69.9, 53.5),  # Sunken Temple → Swamp of Sorrows
    1581: ( 40,  42.5, 71.7),  # The Deadmines → Westfall
    1583: ( 51,  34.8, 85.3),  # Blackrock Spire → Searing Gorge
    1584: ( 51,  34.8, 85.3),  # Blackrock Depths → Searing Gorge
    1977: ( 33,  53.9, 17.6),  # Zul'Gurub → Stranglethorn
    2017: (139,  31.3, 15.7),  # Stratholme → Eastern Plaguelands
    2057: ( 28,  69.7, 73.2),  # Scholomance → Western Plaguelands
    2100: (405,  29.1, 62.5),  # Maraudon → Desolace
    2159: ( 15,  52.6, 76.8),  # Onyxia's Lair → Dustwallow
    2437: (1637, 52.6, 49.0),  # Ragefire Chasm → Orgrimmar
    2557: (357,  59.2, 45.1),  # Dire Maul → Feralas
    2677: ( 51,  34.8, 85.3),  # Blackwing Lair → Searing Gorge
    2717: ( 51,  34.8, 85.3),  # Molten Core → Searing Gorge
    3428: (1377, 28.6, 92.3),  # Temple of Ahn'Qiraj → Silithus
    3429: (1377, 28.6, 92.3),  # Ruins of Ahn'Qiraj → Silithus
    3456: (139,  39.9, 25.8),  # Naxxramas → Eastern Plaguelands
}


# -------- Lua-table accessors --------

def _entries_of(v):
    """Yield non-nil entries from a list- or dict-shaped Lua table value."""
    if v is None or v is LUA_NIL:
        return
    if isinstance(v, list):
        for e in v:
            if e is not LUA_NIL and e is not None:
                yield e
    elif isinstance(v, dict):
        for e in v.values():
            if e is not LUA_NIL and e is not None:
                yield e


def _objectives_category(objs, cat):
    """Get position `cat` (1-indexed) from a parsed `objectives` value."""
    if objs is None or objs is LUA_NIL:
        return None
    if isinstance(objs, list):
        if len(objs) >= cat:
            v = objs[cat - 1]
            return None if v is LUA_NIL else v
        return None
    if isinstance(objs, dict):
        v = objs.get(cat)
        return None if v is LUA_NIL else v
    return None


def _entry_target_id(entry):
    """Extract leading integer id from {id[, ...]} table."""
    if isinstance(entry, list):
        if entry and entry[0] is not LUA_NIL and isinstance(entry[0], int):
            return entry[0]
    elif isinstance(entry, dict):
        v = entry.get(1)
        if v is not LUA_NIL and isinstance(v, int):
            return v
    return None


def _table_field(t, num_key, list_idx=None):
    if list_idx is None:
        list_idx = num_key - 1
    if isinstance(t, list):
        if len(t) > list_idx:
            v = t[list_idx]
            return None if v is LUA_NIL else v
        return None
    if isinstance(t, dict):
        v = t.get(num_key)
        return None if v is LUA_NIL else v
    return None


# -------- spawn enumeration --------

def _emit_spawns_into(out_list, spawns_table, area_to_ui):
    """Append (uiMapId, normX, normY) tuples to `out_list` from a Lua-shaped
    spawns_table {[areaId] = {{x, y}, ...}}, applying dungeon rewrites and
    areaId → uiMapId resolution."""
    if spawns_table is None or spawns_table is LUA_NIL:
        return
    if not isinstance(spawns_table, dict):
        return
    for area_id, coord_list in spawns_table.items():
        if area_id is LUA_NIL or not isinstance(area_id, int):
            continue
        if area_id in DUNGEON_ENTRANCES:
            outer_area, ox, oy = DUNGEON_ENTRANCES[area_id]
            ui_map = area_to_ui.get(outer_area)
            if ui_map:
                out_list.append((ui_map, ox / 100.0, oy / 100.0))
            continue
        ui_map = area_to_ui.get(area_id)
        if not ui_map:
            continue
        for coord in _entries_of(coord_list):
            cx = _table_field(coord, 1)
            cy = _table_field(coord, 2)
            if isinstance(cx, (int, float)) and isinstance(cy, (int, float)):
                out_list.append((ui_map, cx / 100.0, cy / 100.0))


# -------- clustering --------

def _cluster_points(points, threshold=CLUSTER_THRESHOLD):
    n = len(points)
    parent = list(range(n))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    r2 = threshold * threshold
    for i in range(n):
        for j in range(i + 1, n):
            dx = points[i][0] - points[j][0]
            dy = points[i][1] - points[j][1]
            if dx * dx + dy * dy < r2:
                ri, rj = find(i), find(j)
                if ri != rj:
                    parent[ri] = rj
    groups = {}
    for i in range(n):
        root = find(i)
        groups.setdefault(root, []).append(points[i])
    return list(groups.values())


def _merge_small(clusters, min_size=MIN_CLUSTER_SIZE):
    clusters = [list(c) for c in clusters]
    while True:
        small_idx = None
        small_size = math.inf
        for i, c in enumerate(clusters):
            if len(c) < min_size and len(c) < small_size:
                small_idx = i
                small_size = len(c)
        if small_idx is None:
            break
        if len(clusters) == 1:
            return []
        small = clusters[small_idx]
        nearest = None
        nearest_d = math.inf
        for j, other in enumerate(clusters):
            if j == small_idx:
                continue
            for p in small:
                for q in other:
                    dx, dy = p[0] - q[0], p[1] - q[1]
                    d = dx * dx + dy * dy
                    if d < nearest_d:
                        nearest_d = d
                        nearest = j
        target = clusters[nearest]
        target.extend(small)
        clusters.pop(small_idx)
    return clusters


def _convex_hull(points):
    sorted_pts = sorted(set(points))
    if len(sorted_pts) < 3:
        return sorted_pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower = []
    for p in sorted_pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(sorted_pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def _build_uimap_clusters(points):
    """Cluster points in a single uiMap. Returns (clusters, stray)."""
    if len(points) < MIN_CLUSTER_SIZE:
        return [], list(points)
    groups = _cluster_points(points)
    groups = _merge_small(groups)
    if not groups:
        return [], list(points)
    clusters = []
    for g in groups:
        if len(g) < MIN_CLUSTER_SIZE:
            continue
        hull = _convex_hull(g)
        if len(hull) < 3:
            continue
        cx = sum(p[0] for p in g) / len(g)
        cy = sum(p[1] for p in g) / len(g)
        clusters.append({
            "hull": [list(v) for v in hull],
            "centroid": [cx, cy],
            "count": len(g),
        })
    return clusters, []


def _bake_target_groups(target_groups):
    """Cluster each target group's points (per-uiMap) and produce the
    output rows. Filters out targets with no resolvable spawns."""
    out = []
    for tg in target_groups:
        points = tg["points"]
        if not points:
            continue
        by_map = {}
        for ui, nx, ny in points:
            by_map.setdefault(ui, []).append((nx, ny))
        target_clusters = []
        target_stray = []
        for ui_map, ui_points in by_map.items():
            clusters, stray = _build_uimap_clusters(ui_points)
            for c in clusters:
                target_clusters.append({
                    "uiMapId":  ui_map,
                    "hull":     c["hull"],
                    "centroid": c["centroid"],
                    "count":    c["count"],
                })
            for s in stray:
                target_stray.append({
                    "uiMapId": ui_map,
                    "normX":   s[0],
                    "normY":   s[1],
                })
        if not target_clusters and not target_stray:
            continue
        row = {"kind": tg["kind"], "name": tg["name"]}
        if target_clusters:
            row["clusters"] = target_clusters
        if target_stray:
            row["stray"] = target_stray
        out.append(row)
    return out


# -------- main entry --------

def build_all(quests, npcs, objects, items, area_to_ui):
    """Compute per-quest cluster data. Returns {questId: row}."""
    out = {}
    for quest_id, q in quests.items():
        target_groups = []   # list of {kind, name, points = [(ui, nx, ny), ...]}

        objs = q.get("objectives")

        # [1] creature kills + [5] killCredit — both creature-shaped, both
        # match leaderboard type "monster".
        for cat_idx in (1, 5):
            cat = _objectives_category(objs, cat_idx)
            if not cat:
                continue
            for entry in _entries_of(cat):
                cid = _entry_target_id(entry)
                if not cid:
                    continue
                npc = npcs.get(cid)
                if not npc:
                    continue
                points = []
                _emit_spawns_into(points, npc.get("spawns"), area_to_ui)
                if points:
                    target_groups.append({
                        "kind":   "npc",
                        "name":   npc.get("name") or "?",
                        "points": points,
                    })

        # [2] object interacts
        cat = _objectives_category(objs, 2)
        if cat:
            for entry in _entries_of(cat):
                oid = _entry_target_id(entry)
                if not oid:
                    continue
                obj = objects.get(oid)
                if not obj:
                    continue
                points = []
                _emit_spawns_into(points, obj.get("spawns"), area_to_ui)
                if points:
                    target_groups.append({
                        "kind":   "object",
                        "name":   obj.get("name") or "?",
                        "points": points,
                    })

        # [3] item loot — combine ALL source NPCs / objects under the
        # item's name (leaderboard line shows just the item name).
        cat = _objectives_category(objs, 3)
        if cat:
            for entry in _entries_of(cat):
                iid = _entry_target_id(entry)
                if not iid:
                    continue
                item = items.get(iid)
                if not item:
                    continue
                points = []
                for src_id in _entries_of(item.get("npcDrops")):
                    if isinstance(src_id, int):
                        npc = npcs.get(src_id)
                        if npc:
                            _emit_spawns_into(points, npc.get("spawns"), area_to_ui)
                for src_id in _entries_of(item.get("objectDrops")):
                    if isinstance(src_id, int):
                        obj = objects.get(src_id)
                        if obj:
                            _emit_spawns_into(points, obj.get("spawns"), area_to_ui)
                if points:
                    target_groups.append({
                        "kind":   "item",
                        "name":   item.get("name") or "?",
                        "points": points,
                    })

        # triggerEnd (scout-location). Shape: { desc, { [areaId] = {{x,y}} } }
        trig = q.get("triggerEnd")
        zones = _table_field(trig, 2) if trig is not None and trig is not LUA_NIL else None
        if isinstance(zones, dict):
            points = []
            _emit_spawns_into(points, zones, area_to_ui)
            if points:
                desc = _table_field(trig, 1)
                target_groups.append({
                    "kind":   "trigger",
                    "name":   desc if isinstance(desc, str) else "Scout location",
                    "points": points,
                })

        # Finisher (turn-in) spawns. finishedBy = { {npcIds}, {objIds} }.
        # Single flat list — no per-target breakdown needed since the
        # runtime just falls back here when objectives are exhausted.
        finisher = []
        finished_by = q.get("finishedBy")
        if finished_by is not None and finished_by is not LUA_NIL:
            f_npcs = _table_field(finished_by, 1)
            f_objs = _table_field(finished_by, 2)
            for npc_id in _entries_of(f_npcs):
                if isinstance(npc_id, int):
                    npc = npcs.get(npc_id)
                    if npc:
                        _emit_spawns_into(finisher, npc.get("spawns"), area_to_ui)
            for obj_id in _entries_of(f_objs):
                if isinstance(obj_id, int):
                    obj = objects.get(obj_id)
                    if obj:
                        _emit_spawns_into(finisher, obj.get("spawns"), area_to_ui)

        target_out = _bake_target_groups(target_groups)
        finisher_out = [{"uiMapId": ui, "normX": nx, "normY": ny}
                        for ui, nx, ny in finisher]

        row = {}
        if target_out:
            row["objectives"] = target_out
        if finisher_out:
            row["finisher"] = finisher_out
        if row:
            out[quest_id] = row

    return out
