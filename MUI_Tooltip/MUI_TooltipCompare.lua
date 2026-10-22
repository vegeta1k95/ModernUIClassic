-- MUI_TooltipCompare: our own "If you replace this item..." stat changes.
--
-- The client builds the comparison tooltips itself (SetCompareItem) and diffs
-- only an item's base stat fields, so vanilla "Equip:" bonuses (spell damage,
-- healing, attack power, hit, crit, ...) and enchants never count. We total
-- what each item gives by its ids (MUI_ItemStatDB: the item, its enchantment,
-- its random property) and replace the client's list with ours.

local L = MUI.L

local HEADER       = ITEM_DELTA_DESCRIPTION
local HEADER_MULTI = ITEM_DELTA_MULTIPLE_COMPARISON_DESCRIPTION or HEADER

local PERCENT = "%+d%%"

-- Display order: { key, label, number format }. The labels are Blizzard's
-- for "+N <stat>" tooltip lines where it has them (ITEM_MOD_*_SHORT), which
-- other languages word to follow a number ("+5 к силе").
local STATS = {
    { "ARMOR",       ARMOR },
    { "DPS",         ITEM_MOD_DAMAGE_PER_SECOND_SHORT, "%+.1f" },
    { "WDMG",        DAMAGE },
    { "BLOCK",       ITEM_MOD_BLOCK_RATING_SHORT },
    { "STR",         ITEM_MOD_STRENGTH_SHORT },
    { "AGI",         ITEM_MOD_AGILITY_SHORT },
    { "STA",         ITEM_MOD_STAMINA_SHORT },
    { "INT",         ITEM_MOD_INTELLECT_SHORT },
    { "SPI",         ITEM_MOD_SPIRIT_SHORT },
    { "HEALTH",      ITEM_MOD_HEALTH_SHORT },
    { "MANA",        ITEM_MOD_MANA_SHORT },
    { "AP",          ITEM_MOD_ATTACK_POWER_SHORT },
    { "RAP",         ITEM_MOD_RANGED_ATTACK_POWER_SHORT },
    { "FERALAP",     ITEM_MOD_FERAL_ATTACK_POWER_SHORT },
    { "HIT",         ITEM_MOD_HIT_RATING_SHORT, PERCENT },
    { "CRIT",        ITEM_MOD_CRIT_RATING_SHORT, PERCENT },
    { "HASTE",       STAT_ATTACK_SPEED, PERCENT },
    { "SPELLDMG",    STAT_SPELLDAMAGE },
    { "HEAL",        ITEM_MOD_SPELL_HEALING_DONE_SHORT },
    { "DMG_ARCANE",  ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT },
    { "DMG_FIRE",    ITEM_MOD_FIRE_DAMAGE_DONE_SHORT },
    { "DMG_FROST",   ITEM_MOD_FROST_DAMAGE_DONE_SHORT },
    { "DMG_HOLY",    ITEM_MOD_HOLY_DAMAGE_DONE_SHORT },
    { "DMG_NATURE",  ITEM_MOD_NATURE_DAMAGE_DONE_SHORT },
    { "DMG_SHADOW",  ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT },
    { "SPELLHIT",    ITEM_MOD_HIT_SPELL_RATING_SHORT, PERCENT },
    { "SPELLCRIT",   ITEM_MOD_CRIT_SPELL_RATING_SHORT, PERCENT },
    { "SPELLPEN",    ITEM_MOD_SPELL_PENETRATION_SHORT },
    { "MP5",         ITEM_MOD_POWER_REGEN0_SHORT },
    { "HP5",         ITEM_MOD_HEALTH_REGEN_SHORT },
    { "DEFENSE",     ITEM_MOD_DEFENSE_SKILL_RATING_SHORT },
    { "DODGE",       ITEM_MOD_DODGE_RATING_SHORT, PERCENT },
    { "PARRY",       ITEM_MOD_PARRY_RATING_SHORT, PERCENT },
    { "BLOCKCHANCE", BLOCK_CHANCE, PERCENT },
    { "RES_ARCANE",  RESISTANCE6_NAME },
    { "RES_FIRE",    RESISTANCE2_NAME },
    { "RES_FROST",   RESISTANCE4_NAME },
    { "RES_NATURE",  RESISTANCE3_NAME },
    { "RES_SHADOW",  RESISTANCE5_NAME },
}

-- A shield's block value is in none of the client's tables: its line.
local BLOCK = MUI.FormatMatcher(SHIELD_BLOCK_TEMPLATE)

local function Strip(text)
    return strtrim((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
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
        if not new then return end

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

    -- Stat totals of a tooltip's item (nil without one the DB knows), the
    -- block value off its lines 1..last.
    _ReadStats = function(self, tip, last)
        local _, link = tip:GetItem()
        local stats = link and MUI_ItemStatDB:GetStats(link)
        if not stats then return end
        for i = 1, last do
            local text = tip:GetLineText(i)
            local block = text and BLOCK(Strip(text))
            if block then stats.BLOCK = (stats.BLOCK or 0) + tonumber(block) end
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
            local line = key:match("^SKILL(%d+)$")
            if line then skills[#skills + 1] = tonumber(line) end
        end
        table.sort(skills)
        for _, line in ipairs(skills) do
            add("SKILL" .. line, L.TOOLTIP_SKILL:format(MUI_SkillLineDB:GetName(line)))
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
