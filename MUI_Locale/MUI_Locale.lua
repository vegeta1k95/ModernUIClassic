-- MUI_Locale: the addon's own text, in the client's language.
--
--   local L = MUI.L
--   title:SetText(L.MAP_SHOW_DUNGEONS)
--   row:SetText(L.ACH_KILL_WITHIN:format(count, seconds))
--
-- enUS.lua sets every key in English. Each other language's file returns
-- unless it is the client's language, and sets what it translates; the
-- rest stays English. An English client in Europe (enGB) reads enUS.
--
-- A key is for text the client can't give: a Blizzard global string
-- (HONORABLE_KILLS), or the client's own name for an ID (C_Map.GetMapInfo,
-- C_Spell.GetSpellName, C_CreatureInfo.GetRaceInfo …), comes first. A key
-- named as a retail global string (INSPECT_GUILD_REALM) is that string,
-- with retail's translations; any other key is its module's prefix and
-- what the text says. Translations put arguments in another order with
-- %1$s and pick a plural with |4singular:plural;, as Blizzard's do.
--
-- tools/locale_audit.py lists the English left in the code and checks the
-- keys.

MUI.L = {}

-- ---- searching ----------------------------------------------------------

-- Latin-1's capitals À..Þ (but ×) are C3 80..9E, their small letters C3 A0..BE.
local function latin1(byte)
    local n = byte:byte()
    if n == 0x97 then return "\195" .. byte end
    return "\195" .. string.char(n + 32)
end

-- Cyrillic's capitals: Ѐ..Џ (D0 80..8F) to ѐ..џ (D1 90..9F), А..П (D0 90..9F)
-- to а..п (D0 B0..BF), Р..Я (D0 A0..AF) to р..я (D1 80..8F).
local function cyrillic(byte)
    local n = byte:byte()
    if n < 0x90 then return "\209" .. string.char(n + 16) end
    if n < 0xA0 then return "\208" .. string.char(n + 32) end
    return "\209" .. string.char(n - 32)
end

-- Text folded for a search that ignores case: put both the query and what
-- it is looked for in through it. lower() folds only A..Z; this also folds
-- the other capitals the client's languages write, Latin-1's (Ä É Ñ Õ …),
-- Œ, Ÿ and Cyrillic's. Korean and Chinese have no case.
MUI.Fold = function(text)
    text = text:lower():gsub("\195([\128-\158])", latin1)
    text = text:gsub("\197\146", "\197\147"):gsub("\197\184", "\195\191")
    text = text:gsub("\208([\128-\175])", cyrillic)
    return text
end

-- Latin-1's small letters à..þ (but ÷) are C3 A0..BE, their capitals C3 80..9E.
local function latin1Upper(byte)
    local n = byte:byte()
    if n == 0xB7 then return "\195" .. byte end
    return "\195" .. string.char(n - 32)
end

-- Cyrillic's small letters: а..п (D0 B0..BF) to А..П (D0 90..9F), р..я
-- (D1 80..8F) to Р..Я (D0 A0..AF), ѐ..џ (D1 90..9F) to Ѐ..Џ (D0 80..8F).
local function cyrillicUpper(lead, byte)
    local n = byte:byte()
    if lead == "\208" then return "\208" .. string.char(n - 32) end
    if n < 0x90 then return "\208" .. string.char(n + 32) end
    return "\208" .. string.char(n - 16)
end

-- Text in capitals, the other way round from Fold: upper() turns only a..z;
-- this also turns Latin-1's small letters, œ, ÿ and Cyrillic's (ß has no
-- capital of its own and stays).
MUI.Upper = function(text)
    text = text:upper():gsub("\195([\160-\190])", latin1Upper)
    text = text:gsub("\195\191", "\197\184"):gsub("\197\147", "\197\146")
    text = text:gsub("(\208)([\176-\191])", cyrillicUpper):gsub("(\209)([\128-\159])", cyrillicUpper)
    return text
end

-- ---- reading the game's own lines -------------------------------------

local CAPTURE = { s = "(.+)", d = "(%d+)", c = "(.)", f = "([%d%.]+)" }

local function escape(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- A line a Blizzard format string made, read back (loot, rolls, duels,
-- money): MUI.FormatMatcher(LOOT_ITEM_SELF) gives a function that returns
-- a line's arguments in the format's own order, %1$s first, or nil for a
-- line the format didn't make (true when it has no arguments). Another
-- language may put the arguments in another order (%2$s … %1$s), choose a
-- plural (|4one:few:many;) or a Korean particle (|1이;가;), or decline a
-- name (|3-1(%s)), and is read all the same. `anywhere` finds the text
-- inside a longer line instead of matching all of it.
MUI.FormatMatcher = function(format, anywhere)
    format = format:gsub("|3%-%d+%((.-)%)", "%1")
    local patterns, order = { "" }, {}
    -- Each piece of the format extends every pattern so far, once per way
    -- the piece can read.
    local function add(...)
        local grown = {}
        for _, pattern in ipairs(patterns) do
            for k = 1, select("#", ...) do grown[#grown + 1] = pattern .. select(k, ...) end
        end
        patterns = grown
    end
    local i = 1
    while i <= #format do
        local arg, spec, after = format:match("^%%(%d+)%$[-+ #0]*%d*%.?%d*([sdcf])()", i)
        if not spec then spec, after = format:match("^%%[-+ #0]*%d*%.?%d*([sdcf])()", i) end
        if spec then
            order[#order + 1] = tonumber(arg) or #order + 1
            add(CAPTURE[spec])
            i = after
        elseif format:find("^|4", i) then
            local close = format:find(";", i, true)
            local forms = {}
            for form in format:sub(i + 2, close - 1):gmatch("[^:]+") do forms[#forms + 1] = escape(form) end
            add(unpack(forms))
            i = close + 1
        elseif format:find("^|1", i) then
            local first = format:find(";", i, true)
            local second = format:find(";", first + 1, true)
            add(escape(format:sub(i + 2, first - 1)), escape(format:sub(first + 1, second - 1)))
            i = second + 1
        elseif format:find("^%%%%", i) then
            add("%%")
            i = i + 2
        else
            add(escape(format:sub(i, i)))
            i = i + 1
        end
    end

    local count = 0
    for k, arg in ipairs(order) do count = math.max(count, arg) end
    for k, pattern in ipairs(patterns) do
        patterns[k] = anywhere and pattern or "^" .. pattern .. "$"
    end
    return function(text)
        for _, pattern in ipairs(patterns) do
            local found = { text:match(pattern) }
            if found[1] then
                if count == 0 then return true end
                local args = {}
                for k, arg in ipairs(order) do args[arg] = found[k] end
                return unpack(args, 1, count)
            end
        end
        return nil
    end
end
