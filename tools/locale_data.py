"""
The MUI_DB/Locale/<lang>.lua files: the addon's tables in each client
language. Each exporter that has text in other languages writes one block
of its own into each file and leaves the others' alone:

    import locale_data
    locale_data.write_block("deDE", "achievements", "tools/achievements/export.py", lines)

A block holds Lua that runs only on that language's client; data goes in a
long string compiled there alone (loadstring), so the other languages'
files cost the client a read, not a parse.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALE_DIR = os.path.join(ROOT, "MUI_DB", "Locale")
LANGUAGES = {
    "deDE": "German", "esES": "Spanish, as in Spain", "esMX": "Spanish, as in Latin America",
    "frFR": "French", "ptBR": "Portuguese, as in Brazil", "ruRU": "Russian", "koKR": "Korean",
    "zhCN": "Chinese, simplified", "zhTW": "Chinese, traditional",
}


def header(lang):
    return (f"-- MUI_DB in {LANGUAGES[lang]}: the text of the addon's tables in the\n"
            "-- client's language. Each block is written by the tool its first line\n"
            "-- names (tools/locale_data.py); don't edit by hand.\n"
            "\n"
            f'if GetLocale() ~= "{lang}" then return end\n')


def lua_string(s):
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            continue
        elif ch < " ":
            out.append(f"\\{ord(ch)}")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def lua_value(v):
    """A Lua constructor for a str, int, list or {int|str: ...} dict."""
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return lua_string(v)
    if isinstance(v, (list, tuple)):
        return "{" + ",".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            key = f"[{k}]" if isinstance(k, int) else (k if k.isidentifier() else f"[{lua_string(k)}]")
            parts.append(f"{key}={lua_value(x)}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def loadstring(rows):
    """loadstring([==[return { ... }]==])() for a {key: value} dict, one entry a line."""
    body = "\n".join(f"[{k}]={lua_value(v)}," if isinstance(k, int) else f"{lua_value({k: v})[1:-1]},"
                     for k, v in rows.items())
    level = 1
    while f"]{'=' * level}]" in body:
        level += 1
    eq = "=" * level
    return f"loadstring([{eq}[return {{\n{body}\n}}]{eq}])()"


def write_block(lang, name, tool, lines):
    """Put `lines` (Lua, no line ends) in the file's block called `name`."""
    os.makedirs(LOCALE_DIR, exist_ok=True)
    path = os.path.join(LOCALE_DIR, lang + ".lua")
    src = open(path, encoding="utf-8", newline="").read() if os.path.exists(path) else header(lang)
    begin = f"-- ---- {name}: {tool} writes this block"
    end = f"-- ---- end of {name}"
    block = "\n".join([begin] + lines + [end])
    if begin in src:
        start = src.index(begin)
        stop = src.index(end, start) + len(end)
        src = src[:start] + block + src[stop:]
    else:
        src = src.rstrip("\n") + "\n\n" + block + "\n"
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    return path
