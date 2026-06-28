#!/usr/bin/env python3
"""
Fetch tradeskill recipe metadata from wow.playjournals.com — reagents and
color-level thresholds (orange/yellow/green/grey) — for Classic profession
recipes. Emits ready-to-paste Lua entries for MUI_RecipeDB.

playjournals' `profession_skills.json` directly exposes the four color
thresholds plus the recipe's reagents and produced item. That's the only
source that has the real orange threshold (= the skill rank the recipe is
learned at), which wago.tools' SkillLineAbility doesn't ship.

The data file URL is content-hashed (e.g. profession_skills-9578e034.json).
We discover the latest hash by fetching the SPA's JS bundle and parsing the
asset manifest embedded in it.

Usage:
    # Emit lines for given spell IDs:
    python fetch_recipe_data.py 7421 7795 13628 …

    # Or pipe IDs (one per line) from a file:
    python fetch_recipe_data.py --stdin < spells.txt

    # Pin a specific hash (skip auto-discovery):
    python fetch_recipe_data.py --hash 9578e034 7421
"""

from __future__ import annotations
import argparse
import json
import os
import re
import sys
import urllib.request


CDN_BASE        = "https://cdn.playjournals.com/wow"
SPA_URL         = "https://wow.playjournals.com/classic/en/professions/enchanting/all"
USER_AGENT      = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                   "AppleWebKit/537.36 (KHTML, like Gecko) "
                   "Chrome/126.0.0.0 Safari/537.36")


def _fetch(url: str, timeout: int = 120) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def _fetch_text(url: str, timeout: int = 120) -> str:
    return _fetch(url, timeout).decode("utf-8", errors="ignore")


def discover_data_hash() -> str:
    """Scrape playjournals' SPA + JS bundle to find the current
    profession_skills.json content hash."""
    html = _fetch_text(SPA_URL, timeout=30)
    m = re.search(r'src="(https://cdn\.playjournals\.com/wow/js/bundle-[a-f0-9]+\.js)"', html)
    if not m:
        raise RuntimeError("could not find playjournals JS bundle URL on SPA page")
    bundle = _fetch_text(m.group(1), timeout=60)
    m = re.search(r'/data/classic/core/profession_skills\.json"\s*:\s*"([a-f0-9]+)"', bundle)
    if not m:
        raise RuntimeError("could not find profession_skills.json hash in JS bundle")
    return m.group(1)


def fetch_skills(content_hash: str) -> list[dict]:
    url = f"{CDN_BASE}/data/classic/core/profession_skills-{content_hash}.json"
    body = _fetch(url, timeout=120)
    return json.loads(body)


def format_entry(sid: int, entry: dict | None) -> str:
    if not entry:
        return f"        [{sid:>6}] = {{ -- NO DATA }},  -- NOT FOUND"

    parts = []

    reagents = entry.get("reagents") or []
    if reagents:
        r = ", ".join(
            f"{{{r['item_id']}, {r['item_count']}}}" for r in reagents
        )
        parts.append(f"reagents = {{ {r} }}")

    o = entry.get("color_level_1")
    y = entry.get("color_level_2")
    g = entry.get("color_level_3")
    t = entry.get("color_level_4")
    if any(v is not None for v in (o, y, g, t)):
        o = o if o is not None else (y if y is not None else 1)
        y = y if y is not None else o
        g = g if g is not None else (y + t) // 2 if t is not None else y
        t = t if t is not None else g
        parts.append(f"skillrange = {{ {o:>3}, {y:>3}, {g:>3}, {t:>3} }}")

    body = ", ".join(parts) if parts else "-- NO DATA"
    return f"        [{sid:>6}] = {{ {body} }},  -- {entry.get('name', '?')}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("spell_ids", nargs="*", type=int)
    ap.add_argument("--stdin", action="store_true",
                    help="Read spell IDs (one per line) from stdin")
    ap.add_argument("--hash", default=None,
                    help="Pin a specific data file hash (default: auto-discover)")
    args = ap.parse_args()

    ids: list[int] = list(args.spell_ids)
    if args.stdin:
        for line in sys.stdin:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                ids.append(int(line))
            except ValueError:
                pass
    if not ids:
        ap.error("no spell IDs provided")

    content_hash = args.hash or discover_data_hash()
    print(f"-- data from wow.playjournals.com profession_skills-{content_hash}.json",
          file=sys.stderr)

    skills = fetch_skills(content_hash)
    by_id = {int(s["id"]): s for s in skills}

    for sid in ids:
        print(format_entry(sid, by_id.get(sid)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
