"""
Parse Questie zone mapping tables:
    Zones/data/zoneIds.lua               → ZoneDB.zoneIDs (name → ID)
    Zones/data/areaIdToUiMapId.lua       → areaId → uiMapId override table
    Zones/data/uiMapIdToAreaId.lua       → uiMapId → areaId override table
    Zones/data/subZoneToParentZone.lua   → subAreaId → parentAreaId
"""

from __future__ import annotations
import re
from pathlib import Path

from lua_parser import parse_lua_table, parse_return_table
from enums import _parse_table_assignment


_LONG_BRACKET_ASSIGN_RE = re.compile(
    r"ZoneDB\.private\.(\w+)\s*=\s*\[(=*)\[",
)


def _payloads_by_name(source: str) -> dict[str, str]:
    """Return every `ZoneDB.private.NAME = [[ ... ]]` payload in the source,
    keyed by NAME. Each file contains two tables: the base full mapping and
    the sparse override — we need both and merge override on top of base.
    """
    out: dict[str, str] = {}
    for m in _LONG_BRACKET_ASSIGN_RE.finditer(source):
        name = m.group(1)
        eq = m.group(2)
        close = "]" + eq + "]"
        start = m.end()
        if start < len(source) and source[start] == "\n":
            start += 1
        end = source.find(close, start)
        if end == -1:
            raise RuntimeError(f"unterminated long-bracket payload for {name}")
        out[name] = source[start:end]
    return out


def _load_base_plus_override(zdata: Path, filename: str,
                              base_name: str, override_name: str) -> dict:
    """Parse both the full base table and the sparse override table from a
    zone-data file, merging override on top of base."""
    src = (zdata / filename).read_text(encoding="utf-8")
    payloads = _payloads_by_name(src)
    base = parse_return_table(payloads[base_name]) or {}
    override = parse_return_table(payloads[override_name]) or {}
    merged = dict(base)
    for k, v in override.items():
        merged[k] = v
    return merged


def load_all(questie_root: Path) -> dict:
    zdata = questie_root / "Database" / "Zones" / "data"

    zone_ids_src = (zdata / "zoneIds.lua").read_text(encoding="utf-8")
    zone_ids = _parse_table_assignment(zone_ids_src, r"ZoneDB\.zoneIDs")

    area_to_ui = _load_base_plus_override(
        zdata, "areaIdToUiMapId.lua",
        "areaIdToUiMapId", "areaIdToUiMapIdOverride")
    ui_to_area = _load_base_plus_override(
        zdata, "uiMapIdToAreaId.lua",
        "uiMapIdToAreaId", "uiMapIdToAreaIdOverride")
    sub_to_par = _load_base_plus_override(
        zdata, "subZoneToParentZone.lua",
        "subZoneToParentZone", "subZoneToParentZoneOverride")

    return {
        "byName":    zone_ids,          # "DUSKWOOD" → 10
        "areaToUi":  area_to_ui,        # areaId → uiMapId
        "uiToArea":  ui_to_area,        # uiMapId → areaId
        "subToPar":  sub_to_par,        # subAreaId → parentAreaId
    }


if __name__ == "__main__":
    import sys
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / ".." / "vendor" / "Questie"
    z = load_all(root.resolve())
    print(f"zone names: {len(z['byName'])}")
    print(f"areaToUi:   {len(z['areaToUi'])}")
    print(f"uiToArea:   {len(z['uiToArea'])}")
    print(f"subToPar:   {len(z['subToPar'])}")
    print(f"DUSKWOOD id = {z['byName']['DUSKWOOD']}")
