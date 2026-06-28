"""One-shot patcher: update Enchanting skillrange values in MUI_RecipeDB.lua
from the tool's most recent output at /tmp/ench_out.txt."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "MUI_DB" / "MUI_RecipeDB.lua"

new_skill = {}
import os
TMP = os.environ.get("TEMP") or os.environ.get("TMP") or "/tmp"
with open(os.path.join(TMP, "ench_out.txt"), encoding="utf-8") as f:
    for line in f:
        m = re.search(
            r"\[\s*(\d+)\s*\].*skillrange\s*=\s*\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}",
            line,
        )
        if m:
            new_skill[int(m.group(1))] = (
                int(m.group(2)),
                int(m.group(3)),
                int(m.group(4)),
                int(m.group(5)),
            )

print(f"Loaded {len(new_skill)} new skillranges", file=sys.stderr)

with open(DB, encoding="utf-8") as f:
    text = f.read()

start = text.index("ENCHANTING")
m = re.search(r"^    \},", text[start:], re.MULTILINE)
end = start + m.end()
block = text[start:end]


def update_line(line: str) -> str:
    m_sid = re.search(r"\[\s*(\d+)\s*\]", line)
    if not m_sid:
        return line
    sid = int(m_sid.group(1))
    skill = new_skill.get(sid)
    if not skill:
        return line
    o, y, g, t = skill
    new_sr = f"skillrange = {{ {o:>3}, {y:>3}, {g:>3}, {t:>3} }}"
    return re.sub(r"skillrange\s*=\s*\{[^}]+\}", new_sr, line)


new_block = "\n".join(update_line(l) for l in block.split("\n"))
new_text = text[:start] + new_block + text[end:]

with open(DB, "w", encoding="utf-8") as f:
    f.write(new_text)

print(f"Patched {DB}", file=sys.stderr)
