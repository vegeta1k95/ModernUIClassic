-- MUI_TooltipCompare: our own "If you replace this item..." stat changes.
--
-- The client builds the comparison tooltips itself (SetCompareItem) and diffs
-- only an item's base stat fields, so vanilla "Equip:" bonuses (spell damage,
-- healing, attack power, hit, crit, ...) and enchants never count. We read
-- both items' tooltip lines as shown, total every stat we recognise, and
-- replace the client's list with ours.

local HEADER       = ITEM_DELTA_DESCRIPTION
local HEADER_MULTI = ITEM_DELTA_MULTIPLE_COMPARISON_DESCRIPTION or HEADER

local PERCENT = "%+d%%"
local SCHOOLS = { "arcane", "fire", "frost", "holy", "nature", "shadow" }

-- Display order: { key, label, number format }.
local STATS = {
    { "ARMOR",       "Armor" },
    { "DPS",         "Damage Per Second", "%+.1f" },
    { "WDMG",        "Weapon Damage" },
    { "BLOCK",       "Block" },
    { "STR",         "Strength" },
    { "AGI",         "Agility" },
    { "STA",         "Stamina" },
    { "INT",         "Intellect" },
    { "SPI",         "Spirit" },
    { "HEALTH",      "Health" },
    { "MANA",        "Mana" },
    { "AP",          "Attack Power" },
    { "RAP",         "Ranged Attack Power" },
    { "FERALAP",     "Attack Power in Forms" },
    { "HIT",         "Hit", PERCENT },
    { "CRIT",        "Critical Strike", PERCENT },
    { "HASTE",       "Attack Speed", PERCENT },
    { "SPELLDMG",    "Spell Damage" },
    { "HEAL",        "Healing" },
    { "DMG_ARCANE",  "Arcane Spell Damage" },
    { "DMG_FIRE",    "Fire Spell Damage" },
    { "DMG_FROST",   "Frost Spell Damage" },
    { "DMG_HOLY",    "Holy Spell Damage" },
    { "DMG_NATURE",  "Nature Spell Damage" },
    { "DMG_SHADOW",  "Shadow Spell Damage" },
    { "SPELLHIT",    "Spell Hit", PERCENT },
    { "SPELLCRIT",   "Spell Critical Strike", PERCENT },
    { "SPELLPEN",    "Spell Penetration" },
    { "MP5",         "Mana per 5 sec" },
    { "HP5",         "Health per 5 sec" },
    { "DEFENSE",     "Defense" },
    { "DODGE",       "Dodge", PERCENT },
    { "PARRY",       "Parry", PERCENT },
    { "BLOCKCHANCE", "Block Chance", PERCENT },
    { "RES_ARCANE",  "Arcane Resistance" },
    { "RES_FIRE",    "Fire Resistance" },
    { "RES_FROST",   "Frost Resistance" },
    { "RES_NATURE",  "Nature Resistance" },
    { "RES_SHADOW",  "Shadow Resistance" },
}

-- "+N <name>" / "<name> +N" lines: white and green stats, enchants, random
-- suffixes. Lower-case name -> stat keys.
local NAMES = {
    ["strength"]                  = { "STR" },
    ["agility"]                   = { "AGI" },
    ["stamina"]                   = { "STA" },
    ["intellect"]                 = { "INT" },
    ["spirit"]                    = { "SPI" },
    ["armor"]                     = { "ARMOR" },
    ["reinforced armor"]          = { "ARMOR" },
    ["health"]                    = { "HEALTH" },
    ["mana"]                      = { "MANA" },
    ["attack power"]              = { "AP" },
    ["ranged attack power"]       = { "RAP" },
    ["damage"]                    = { "WDMG" },
    ["weapon damage"]             = { "WDMG" },
    ["spell damage"]              = { "SPELLDMG" },
    ["damage and healing spells"] = { "SPELLDMG", "HEAL" },
    ["spell damage and healing"]  = { "SPELLDMG", "HEAL" },
    ["healing spells"]            = { "HEAL" },
    ["healing"]                   = { "HEAL" },
    ["defense"]                   = { "DEFENSE" },
    ["mana every 5 sec"]          = { "MP5" },
    ["mana per 5 sec"]            = { "MP5" },
    ["health every 5 sec"]        = { "HP5" },
    ["health per 5 sec"]          = { "HP5" },
    ["all resistances"]           = { "RES_ARCANE", "RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW" },
}
for _, school in ipairs(SCHOOLS) do
    NAMES[school .. " resistance"]   = { "RES_" .. school:upper() }
    NAMES[school .. " spell damage"] = { "DMG_" .. school:upper() }
end

-- The same two forms with a percent sign ("+1% Dodge").
local PERCENT_NAMES = {
    ["hit"]             = { "HIT" },
    ["critical strike"] = { "CRIT" },
    ["attack speed"]    = { "HASTE" },
    ["haste"]           = { "HASTE" },
    ["dodge"]           = { "DODGE" },
    ["parry"]           = { "PARRY" },
    ["block"]           = { "BLOCKCHANCE" },
}

-- "Equip: ..." sentences (lower-case, prefix removed): { pattern, keys... }.
local EQUIP = {
    { "^increases damage and healing done by magical spells and effects by up to (%d+)", "SPELLDMG", "HEAL" },
    { "^increases healing done by spells and effects by up to (%d+)", "HEAL" },
    { "^%+(%d+) attack power%.?$", "AP" },
    { "^%+(%d+) ranged attack power%.?$", "RAP" },
    { "^%+(%d+) attack power in cat, bear,? and dire bear forms only", "FERALAP" },
    { "^improves your chance to hit by (%d+)%%", "HIT" },
    { "^improves your chance to get a critical strike by (%d+)%%", "CRIT" },
    { "^improves your chance to hit with spells by (%d+)%%", "SPELLHIT" },
    { "^improves your chance to get a critical strike with spells by (%d+)%%", "SPELLCRIT" },
    { "^restores (%d+) mana per 5 sec", "MP5" },
    { "^restores (%d+) mana every 5 sec", "MP5" },
    { "^restores (%d+) health per 5 sec", "HP5" },
    { "^restores (%d+) health every 5 sec", "HP5" },
    { "^increased defense %+(%d+)", "DEFENSE" },
    { "^increases your chance to dodge an attack by (%d+)%%", "DODGE" },
    { "^increases your chance to parry an attack by (%d+)%%", "PARRY" },
    { "^increases your chance to block attacks with a shield by (%d+)%%", "BLOCKCHANCE" },
    { "^increases the block value of your shield by (%d+)", "BLOCK" },
    { "^decreases the magical resistances of your spell targets by (%d+)", "SPELLPEN" },
}

local function Strip(text)
    return strtrim((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end

local function Add(stats, keys, value, first)
    for i = first or 1, #keys do
        stats[keys[i]] = (stats[keys[i]] or 0) + value
    end
end

local function ParseEquip(stats, text)
    for _, entry in ipairs(EQUIP) do
        local value = text:match(entry[1])
        if value then
            Add(stats, entry, tonumber(value), 2)
            return
        end
    end
    local school, damage = text:match("^increases damage done by (%a+) spells and effects by up to (%d+)")
    if school and NAMES[school .. " spell damage"] then
        Add(stats, NAMES[school .. " spell damage"], tonumber(damage))
        return
    end
    -- Weapon skills: "Increased Swords +7."
    local skill, points = text:match("^increased ([%a%s%-]+) %+(%d+)")
    if skill then
        Add(stats, { "SKILL:" .. skill }, tonumber(points))
    end
end

-- Add whatever one tooltip line grants to `stats`.
local function ParseLine(stats, text)
    text = Strip(text):lower()

    local equip = text:match("^equip: (.+)$")
    if equip then
        ParseEquip(stats, equip)
        return
    end

    local value = text:match("^(%d+) armor$")
    if value then Add(stats, { "ARMOR" }, tonumber(value)) return end
    value = text:match("^(%d+) block$")
    if value then Add(stats, { "BLOCK" }, tonumber(value)) return end
    value = text:match("^%(([%d%.]+) damage per second%)$")
    if value then Add(stats, { "DPS" }, tonumber(value)) return end

    local sign, percent, name
    sign, value, percent, name = text:match("^([%+%-])(%d+)(%%?) (.-)%.?$")
    if not value then
        name, value, percent = text:match("^(.-) %+(%d+)(%%?)%.?$")
    end
    local keys = value and (percent == "%" and PERCENT_NAMES or NAMES)[name]
    if keys then
        Add(stats, keys, sign == "-" and -tonumber(value) or tonumber(value))
    end
end

local function IsBlank(text)
    return not text or strtrim(text) == ""
end

object "TooltipItemCompare" {

    __init = function(self)
        self._mains = {
            [GameTooltip]    = MUI_Tooltip,
            [ItemRefTooltip] = MUI_TooltipItemRef,
        }
        self._shopping = {
            [GameTooltip]    = { MUI_TooltipComparison1, MUI_TooltipComparison2 },
            [ItemRefTooltip] = { MUI_TooltipItemRefComparison1, MUI_TooltipItemRefComparison2 },
        }
        self._cells = {}
        -- Every comparison goes through this global; by the time it returns
        -- the client has filled both comparison tooltips.
        hooksecurefunc("GameTooltip_ShowCompareItem", function(tooltip)
            self:_Compare(tooltip or GameTooltip)
        end)
    end;

    _Compare = function(self, native)
        local main, tips = self._mains[native], self._shopping[native]
        if not main then return end

        local _, link = main:GetItem()
        local equipLoc = link and select(9, C_Item.GetItemInfo(link))
        local new = self:_ReadStats(main, main:NumLines())

        -- Each comparison tooltip's own item: the lines above the client's list.
        local old, headers = {}, {}
        for i, tip in ipairs(tips) do
            if tip:IsShown() then
                headers[i] = self:_FindHeader(tip)
                old[i] = self:_ReadStats(tip, (headers[i] or tip:NumLines() + 1) - 1)
            end
        end

        -- A two-hander replaces both hands: one list, in the first tooltip.
        local both = equipLoc == "INVTYPE_2HWEAPON" and old[1] and old[2]
        for i, tip in ipairs(tips) do
            if old[i] then
                local lines = {}
                if both and i == 1 then
                    lines = self:_Delta(new, old[1], old[2])
                elseif not both then
                    lines = self:_Delta(new, old[i])
                end
                self:_Write(tip, headers[i], both and HEADER_MULTI or HEADER, lines)
            end
        end
    end;

    _FindHeader = function(self, tip)
        for i = 1, tip:NumLines() do
            local text = tip:GetLineText(i)
            text = text and Strip(text)
            if text == HEADER or text == HEADER_MULTI then return i end
        end
    end;

    -- Stat totals of lines 1..last of a tooltip.
    _ReadStats = function(self, tip, last)
        local stats = {}
        for i = 1, last do
            local text = tip:GetLineText(i)
            if text then ParseLine(stats, text) end
        end
        return stats
    end;

    -- Lines for what changes going from the items in `...` to `new`.
    _Delta = function(self, new, ...)
        local diff = {}
        for key, value in pairs(new) do diff[key] = value end
        for i = 1, select("#", ...) do
            for key, value in pairs((select(i, ...))) do
                diff[key] = (diff[key] or 0) - value
            end
        end

        local lines = {}
        local function add(key, label, format)
            local value = diff[key]
            if value and math.abs(value) >= 0.05 then
                local text = string.format(format or "%+d", value)
                lines[#lines + 1] = { sign = text:sub(1, 1), number = text:sub(2), label = label, gain = value > 0 }
            end
        end
        for _, stat in ipairs(STATS) do
            add(stat[1], stat[2], stat[3])
        end

        local skills = {}
        for key in pairs(diff) do
            if key:sub(1, 6) == "SKILL:" then skills[#skills + 1] = key end
        end
        table.sort(skills)
        for _, key in ipairs(skills) do
            local name = key:sub(7):gsub("%a+", function(word)
                return word:sub(1, 1):upper() .. word:sub(2)
            end)
            add(key, name .. " Skill")
        end
        return lines
    end;

    -- Replace the client's list (the lines after its header, up to the next
    -- blank one) with ours, keeping whatever follows it. The tooltip lines
    -- only hold space; the visible text is our own font strings laid over
    -- them (_PlaceNumbers).
    _Write = function(self, tip, header, headerText, lines)
        local spacers = self:_FillNumbers(tip, lines)
        local first

        if not header then
            if #lines == 0 then return end
            tip:AddBlank()
            tip:AddLine(headerText, 1, 0.82, 0, true)
            first = tip:NumLines() + 1
            for i in ipairs(lines) do
                tip:AddLine(spacers[i], 1, 1, 1)
            end
        else
            local last = header
            while last < tip:NumLines() and not IsBlank(tip:GetLineText(last + 1)) do
                last = last + 1
            end

            -- Nothing differs: drop the list, its header and the blank above it.
            if #lines == 0 then
                local from = header
                if header > 1 and IsBlank(tip:GetLineText(header - 1)) then from = header - 1 end
                for i = last, from, -1 do tip:RemoveLine(i) end
                self:_PlaceNumbers(tip, from, lines)
                return
            end

            tip:SetLine(header, headerText, 1, 0.82, 0, true)
            first = header + 1
            for i in ipairs(lines) do
                if header + i <= last then
                    tip:SetLine(header + i, spacers[i], 1, 1, 1)
                else
                    tip:InsertLine(header + i, spacers[i], 1, 1, 1)
                end
            end
            for i = last, header + #lines + 1, -1 do tip:RemoveLine(i) end
        end

        self:_PlaceNumbers(tip, first, lines)
        tip:Show()
    end;

    -- ---- number column -----------------------------------------------------
    -- Sign centred in a fixed slot, then the digits with the label right
    -- after them, so every line's sign and first digit start at the same x.

    _Cell = function(self, tip, i)
        local cells = self._cells[tip]
        if not cells then
            cells = {}
            self._cells[tip] = cells
            local function hide()
                for _, cell in ipairs(cells) do
                    cell.sign:Hide()
                    cell.number:Hide()
                end
            end
            tip:HookScript("OnTooltipCleared", hide)
            tip:HookScript("OnHide", hide)
        end
        local cell = cells[i]
        if not cell then
            local function label(justify)
                local fs = FontString(tip, nil, "OVERLAY")
                fs:SetFont(MUI.FONT, 10.5, "")
                fs:SetShadowOffset(1, -1)
                fs:SetJustifyH(justify)
                return fs
            end
            cell = { sign = label("CENTER"), number = label("LEFT") }
            cell.number:SetTextColor(1, 1, 1)
            cell.number:RightOf(cell.sign)
            cells[i] = cell
        end
        return cell
    end;

    _Measure = function(self, tip)
        if self._slotWidth then return end
        local fs = self:_Cell(tip, 1).sign
        fs:SetText("+")
        local plus = fs:GetStringWidth()
        fs:SetText("-")
        self._slotWidth = math.max(plus, fs:GetStringWidth())
        fs:SetText("0 0")
        local spaced = fs:GetStringWidth()
        fs:SetText("00")
        self._spaceWidth = math.max(spaced - fs:GetStringWidth(), 1)
    end;

    -- Set the cells' text and colour. Returns, per line, the run of spaces the
    -- tooltip line holds instead: invisible, but at least as wide as the cell,
    -- so the tooltip is sized for it.
    _FillNumbers = function(self, tip, lines)
        self:_Measure(tip)
        local spacers = {}
        for i, line in ipairs(lines) do
            local cell = self:_Cell(tip, i)
            local hex = line.gain and "|cff00ff00" or "|cffff2121"
            cell.sign:SetText(hex .. line.sign)
            cell.sign:SetWidth(self._slotWidth)
            cell.number:SetText(hex .. line.number .. "|r " .. line.label)
            local width = self._slotWidth + cell.number:GetStringWidth()
            spacers[i] = string.rep(" ", math.ceil(width / self._spaceWidth))
        end
        return spacers
    end;

    -- Seat the cells on their lines (indices are final only after _Write).
    _PlaceNumbers = function(self, tip, first, lines)
        local cells = self._cells[tip]
        for i, cell in ipairs(cells) do
            if i <= #lines then
                cell.sign:ClearAllPoints()
                cell.sign:AlignLeft(tip:GetLineWidget(first + i - 1))
                cell.sign:Show()
                cell.number:Show()
            else
                cell.sign:Hide()
                cell.number:Hide()
            end
        end
    end;
}
