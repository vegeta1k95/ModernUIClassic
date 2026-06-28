#!/usr/bin/env python3
"""
Fetch Spell skill thresholds (orange/yellow/green/grey) from wago.tools'
SkillLineAbility DB2 export for the latest Classic Era build.

Outputs Lua-formatted `skillrange = { o, y, g, t }` lines for the spell
IDs passed on the command line, so they can be pasted into MUI_RecipeDB.

The DB2 only stores `TrivialSkillLineRankLow` (green) and
`TrivialSkillLineRankHigh` (grey). Orange / yellow are derived via the
canonical Blizzard tradeskill formula:
    orange = max(1, green - 25)
    yellow = green
    green  = TrivialSkillLineRankLow
    grey   = TrivialSkillLineRankHigh

Usage:
    python fetch_skill_ranges.py 3275 3276 3277 ...           # IDs as args
    python fetch_skill_ranges.py --build 1.15.8.67156 3275    # pin build
"""

from __future__ import annotations
import argparse
import csv
import io
import re
import sys
import urllib.request


WAGO_BUILDS_URL = "https://wago.tools/api/builds"
WAGO_CSV_URL    = "https://wago.tools/db2/SkillLineAbility/csv?build={build}"
# wago.tools rejects the default `Python-urllib` UA with 403, so masquerade.
USER_AGENT = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
              "AppleWebKit/537.36 (KHTML, like Gecko) "
              "Chrome/126.0.0.0 Safari/537.36")


def _fetch(url: str, timeout: int = 60) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def latest_classic_build() -> str:
    """Pick the highest 1.15.x build present in wago.tools' build list."""
    text = _fetch(WAGO_BUILDS_URL, timeout=30)
    versions = re.findall(r'"version":"(1\.15\.[^"]+)"', text)
    if not versions:
        raise RuntimeError("no 1.15.x builds found on wago.tools")
    # Sort by tuple of ints so 1.15.8.67156 beats 1.15.0.52124.
    def sortkey(v: str):
        return tuple(int(p) if p.isdigit() else 0 for p in v.split("."))
    return sorted(versions, key=sortkey)[-1]


def fetch_csv(build: str) -> list[dict]:
    body = _fetch(WAGO_CSV_URL.format(build=build), timeout=120)
    return list(csv.DictReader(io.StringIO(body)))


def compute_skillrange(low: int, high: int) -> tuple[int, int, int, int]:
    """Canonical Blizzard formula for tradeskill difficulty thresholds."""
    orange = max(1, low - 25)
    yellow = low
    green  = (low + high) // 2
    grey   = high
    return orange, yellow, green, grey


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("spell_ids", nargs="+", type=int)
    ap.add_argument("--build", default=None,
                    help="Pin a specific Classic Era build (default: latest 1.15.x)")
    args = ap.parse_args()

    build = args.build or latest_classic_build()
    print(f"-- skillrange data from wago.tools SkillLineAbility @ {build}", file=sys.stderr)

    rows = fetch_csv(build)
    by_spell: dict[int, dict] = {int(r["Spell"]): r for r in rows}

    for sid in args.spell_ids:
        row = by_spell.get(sid)
        if not row:
            print(f"        -- [{sid}] = NOT FOUND in SkillLineAbility")
            continue
        low  = int(row["TrivialSkillLineRankLow"])
        high = int(row["TrivialSkillLineRankHigh"])
        if low == 0 and high == 0:
            # Recipe with no difficulty thresholds (likely a tool / non-craft).
            print(f"        -- [{sid}] = no thresholds in DB")
            continue
        o, y, g, t = compute_skillrange(low, high)
        print(f"        -- [{sid}]  skillrange = {{ {o:3d}, {y:3d}, {g:3d}, {t:3d} }},")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
