-- MUI_CharacterStats: a unit's stat sheet as retail's CharacterStatsPane —
-- the class backdrop, the category plates, the striped stat rows — listing
-- what Era has: the paper doll's side pane, and the pet's.
--
--   CharacterStatSource     reads one stat into a row; the numbers and the
--                           tooltip wording follow Era's own PaperDollFrame
--   CharacterStatSheet(parent, unit, sections, withItemLevel)
--     sections = { { title, { { method, argument }, ... } }, ... }
--     :Refresh()

local SHEET  = "Interface\\PaperDollInfoFrame\\PaperDollInfoPart1"
local SHEET2 = "Interface\\PaperDollInfoFrame\\PaperDollInfoPart2"

-- Each class's 197x355 backdrop: sheet, the sheet's height, x, y.
local CLASS_ART = {
    MAGE    = { SHEET,  1024, 1,   1 },
    PALADIN = { SHEET,  1024, 200, 1 },
    ROGUE   = { SHEET,  1024, 399, 1 },
    WARLOCK = { SHEET,  1024, 598, 1 },
    WARRIOR = { SHEET,  1024, 797, 1 },
    PRIEST  = { SHEET,  1024, 200, 358 },
    SHAMAN  = { SHEET,  1024, 399, 358 },
    DRUID   = { SHEET2, 512,  399, 1 },
    HUNTER  = { SHEET2, 512,  598, 1 },
}

local PANE_W, PANE_H = 197, 355
local ROW_W, ROW_H   = 187, 15
local PLATE_H        = 40

local ATTRIBUTES = { "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" }
local SCHOOLS    = { [2] = "Fire", [3] = "Nature", [4] = "Frost", [5] = "Shadow", [6] = "Arcane" }
-- Era's strip of resistance tiles (32x256, one every 29 px), and how far
-- down it each school's tile is.
local RESISTANCE_TILES = "Interface\\PaperDollInfoFrame\\UI-Character-ResistanceIcons"
local RESISTANCE_TILE  = { [2] = 0, [3] = 29, [6] = 58, [4] = 87, [5] = 116 }
-- The spell schools a caster's bonuses come in (2 holy .. 7 arcane).
local SPELL_SCHOOLS = { "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }

-- The slots an average item level counts: everything but shirt and tabard.
local LEVEL_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

local GREEN, RED, CLOSE = "|cff20ff20", "|cffff2020", "|r"

-- Whatever can change a number on the sheet.
local EVENTS = {
    "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "PLAYER_DAMAGE_DONE_MODS",
    "UNIT_ATTACK_SPEED", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_ATTACK", "UNIT_DEFENSE",
    "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_AURA", "UNIT_LEVEL", "UNIT_PET",
    "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "CHARACTER_POINTS_CHANGED",
}

-- ---------------------------------------------------------------------
-- CharacterStatSource: every method takes (row, unit, argument) and fills
-- the row with a label, a value, a tooltip title and tooltip lines (a string,
-- or a { left, right } pair).
-- ---------------------------------------------------------------------
object "CharacterStatSource" {

    -- A total, green while buffed and red while debuffed.
    _Tint = function(self, value, pos, neg)
        if neg < 0 then return RED .. value .. CLOSE end
        if pos > 0 then return GREEN .. value .. CLOSE end
        return tostring(value)
    end;

    -- "Name 120 (100 +25 -5)".
    _Breakdown = function(self, name, value, base, pos, neg)
        local text = name .. " " .. value
        if pos ~= 0 or neg ~= 0 then
            text = text .. " (" .. base
            if pos > 0 then text = text .. GREEN .. " +" .. pos .. CLOSE end
            if neg < 0 then text = text .. RED .. " " .. neg .. CLOSE end
            text = text .. ")"
        end
        return text
    end;

    -- One weapon's swing: the range shown on the row, the range with its
    -- bonuses spelt out for the tooltip, and its damage per second.
    _Swing = function(self, low, high, pos, neg, percent, speed)
        local shown = math.max(math.floor(low), 1) .. " - " .. math.max(math.ceil(high), 1)
        if percent == 0 then
            low, high = 0, 0
        else
            low  = low / percent - pos - neg
            high = high / percent - pos - neg
        end
        local base  = (low + high) * 0.5
        local full  = (base + pos + neg) * percent
        local bonus = full - base
        if bonus < 0.1 and bonus > -0.1 then bonus = 0 end

        local detail = math.max(math.floor(low), 1) .. " - " .. math.max(math.ceil(high), 1)
        if bonus ~= 0 then
            shown = (bonus > 0 and GREEN or RED) .. shown .. CLOSE
            if pos > 0 then detail = detail .. GREEN .. " +" .. pos .. CLOSE end
            if neg < 0 then detail = detail .. RED .. " " .. neg .. CLOSE end
            if percent > 1 then
                detail = detail .. GREEN .. " x" .. math.floor(percent * 100 + 0.5) .. "%" .. CLOSE
            elseif percent < 1 then
                detail = detail .. RED .. " x" .. math.floor(percent * 100 + 0.5) .. "%" .. CLOSE
            end
        end
        local dps = speed > 0 and math.max(full, 1) / speed or 0
        return shown, detail, dps
    end;

    _HasRanged = function(self)
        return GetInventoryItemTexture("player", 18) ~= nil
    end;

    -- ---- general -------------------------------------------------------

    Health = function(self, row, unit)
        local value = UnitHealthMax(unit)
        row:Set(HEALTH, value, HEALTH .. " " .. value)
    end;

    Power = function(self, row, unit)
        local _, token = UnitPowerType(unit)
        local name = getglobal(token) or MANA
        local value = UnitPowerMax(unit)
        row:Set(name, value, name .. " " .. value)
    end;

    -- argument: 1 strength .. 5 spirit. Era reports a pet's totals without
    -- what its buffs add.
    Attribute = function(self, row, unit, index)
        local stat, effective, pos, neg = UnitStat(unit, index)
        if unit ~= "player" then pos, neg = 0, 0 end
        local name = getglobal("SPELL_STAT" .. index .. "_NAME")
        local _, class = UnitClass(unit)
        local key = "_" .. ATTRIBUTES[index] .. "_TOOLTIP"
        local help = getglobal((class or "DEFAULT") .. key) or getglobal("DEFAULT" .. key)
        row:Set(name, self:_Tint(effective, pos, neg),
            self:_Breakdown(name, effective, stat - pos - neg, pos, neg), help)
    end;

    -- ---- melee ---------------------------------------------------------

    Damage = function(self, row, unit)
        local speed, offSpeed = UnitAttackSpeed(unit)
        local low, high, offLow, offHigh, pos, neg, percent = UnitDamage(unit)
        local shown, detail, dps = self:_Swing(low, high, pos, neg, percent, speed)
        if offSpeed then
            local _, offDetail, offDps = self:_Swing(offLow, offHigh, pos, neg, percent, offSpeed)
            row:Set(DAMAGE, shown, INVTYPE_WEAPONMAINHAND,
                { ATTACK_SPEED_COLON, string.format("%.2f", speed) },
                { DAMAGE_COLON, detail },
                { DAMAGE_PER_SECOND, string.format("%.1f", dps) },
                " ",
                "|cffffffff" .. INVTYPE_WEAPONOFFHAND .. CLOSE,
                { ATTACK_SPEED_COLON, string.format("%.2f", offSpeed) },
                { DAMAGE_COLON, offDetail },
                { DAMAGE_PER_SECOND, string.format("%.1f", offDps) })
        else
            row:Set(DAMAGE, shown, INVTYPE_WEAPONMAINHAND,
                { ATTACK_SPEED_COLON, string.format("%.2f", speed) },
                { DAMAGE_COLON, detail },
                { DAMAGE_PER_SECOND, string.format("%.1f", dps) })
        end
    end;

    DamagePerSecond = function(self, row, unit)
        local speed = UnitAttackSpeed(unit)
        local low, high, _, _, pos, neg, percent = UnitDamage(unit)
        local _, _, dps = self:_Swing(low, high, pos, neg, percent, speed)
        local value = string.format("%.1f", dps)
        row:Set("Damage per Second", value, "Damage per Second " .. value,
            "The damage your main hand weapon deals each second, on average.")
    end;

    AttackSpeed = function(self, row, unit)
        local speed, offSpeed = UnitAttackSpeed(unit)
        local value = string.format("%.2f", speed)
        if offSpeed then value = value .. " / " .. string.format("%.2f", offSpeed) end
        row:Set("Attack Speed", value, "Attack Speed " .. value, "The seconds between your melee swings.")
    end;

    AttackPower = function(self, row, unit)
        local base, pos, neg = UnitAttackPower(unit)
        local total = base + pos + neg
        row:Set("Attack Power", self:_Tint(total, pos, neg),
            self:_Breakdown(MELEE_ATTACK_POWER, total, base, pos, neg),
            MELEE_ATTACK_POWER_TOOLTIP:format(math.max(total, 0) / ATTACK_POWER_MAGIC_NUMBER))
    end;

    -- The skill with the weapon in the main hand; a pet's attack rating.
    Attack = function(self, row, unit)
        local base, modifier = UnitAttackBothHands(unit)
        row:Set(unit == "player" and "Weapon Skill" or "Attack", self:_Tint(base + modifier, modifier, modifier),
            ATTACK_TOOLTIP, ATTACK_TOOLTIP_SUBTEXT)
    end;

    Hit = function(self, row)
        local value = string.format("%.2f%%", GetHitModifier() or 0)
        row:Set("Hit Chance", value, "Hit Chance " .. value, "Your bonus chance to hit with melee and ranged attacks.")
    end;

    Crit = function(self, row)
        local value = string.format("%.2f%%", GetCritChance())
        row:Set("Crit Chance", value, "Crit Chance " .. value, "Your chance to critically strike with melee attacks.")
    end;

    -- ---- ranged --------------------------------------------------------

    RangedDamage = function(self, row, unit)
        if not self:_HasRanged() then
            row:Set(DAMAGE, NOT_APPLICABLE, INVTYPE_RANGED)
            return
        end
        local speed, low, high, pos, neg, percent = UnitRangedDamage(unit)
        local shown, detail, dps = self:_Swing(low, high, pos, neg, percent, speed)
        row:Set(DAMAGE, shown, INVTYPE_RANGED,
            { ATTACK_SPEED_COLON, string.format("%.2f", speed) },
            { DAMAGE_COLON, detail },
            { DAMAGE_PER_SECOND, string.format("%.1f", dps) })
    end;

    RangedDamagePerSecond = function(self, row, unit)
        if not self:_HasRanged() then
            row:Set("Damage per Second", NOT_APPLICABLE, "Damage per Second")
            return
        end
        local speed, low, high, pos, neg, percent = UnitRangedDamage(unit)
        local _, _, dps = self:_Swing(low, high, pos, neg, percent, speed)
        local value = string.format("%.1f", dps)
        row:Set("Damage per Second", value, "Damage per Second " .. value,
            "The damage your ranged weapon deals each second, on average.")
    end;

    RangedAttackSpeed = function(self, row, unit)
        if not self:_HasRanged() then
            row:Set("Attack Speed", NOT_APPLICABLE, "Attack Speed")
            return
        end
        local value = string.format("%.2f", (UnitRangedDamage(unit)))
        row:Set("Attack Speed", value, "Attack Speed " .. value, "The seconds between your ranged attacks.")
    end;

    -- A wand takes nothing from attack power.
    RangedAttackPower = function(self, row, unit)
        if not self:_HasRanged() then
            row:Set("Attack Power", NOT_APPLICABLE, RANGED_ATTACK_POWER)
        elseif HasWandEquipped() then
            row:Set("Attack Power", "--", RANGED_ATTACK_POWER)
        else
            local base, pos, neg = UnitRangedAttackPower(unit)
            local total = base + pos + neg
            row:Set("Attack Power", self:_Tint(total, pos, neg),
                self:_Breakdown(RANGED_ATTACK_POWER, total, base, pos, neg),
                RANGED_ATTACK_POWER_TOOLTIP:format(math.max(total, 0) / ATTACK_POWER_MAGIC_NUMBER))
        end
    end;

    RangedAttack = function(self, row, unit)
        if not self:_HasRanged() then
            row:Set("Weapon Skill", NOT_APPLICABLE, RANGED_ATTACK_TOOLTIP)
            return
        end
        local base, modifier = UnitRangedAttack(unit)
        row:Set("Weapon Skill", self:_Tint(base + modifier, modifier, modifier), RANGED_ATTACK_TOOLTIP, ATTACK_TOOLTIP_SUBTEXT)
    end;

    RangedCrit = function(self, row)
        local value = string.format("%.2f%%", GetRangedCritChance())
        row:Set("Crit Chance", value, "Crit Chance " .. value, "Your chance to critically strike with ranged attacks.")
    end;

    -- ---- spell ---------------------------------------------------------

    -- The best school on the row, every school in the tooltip.
    SpellDamage = function(self, row)
        local best, lines = 0, {}
        for school = 2, 7 do
            local bonus = GetSpellBonusDamage(school)
            best = math.max(best, bonus)
            lines[#lines + 1] = { SPELL_SCHOOLS[school - 1], tostring(bonus) }
        end
        row:Set("Bonus Damage", best, "Bonus Damage " .. best, unpack(lines))
    end;

    SpellHealing = function(self, row)
        local value = GetSpellBonusHealing()
        row:Set("Bonus Healing", value, "Bonus Healing " .. value, "Increases the healing your spells and effects do.")
    end;

    SpellHit = function(self, row)
        local value = string.format("%.2f%%", GetSpellHitModifier() or 0)
        row:Set("Hit Chance", value, "Hit Chance " .. value, "Your bonus chance to hit with spells.")
    end;

    SpellCrit = function(self, row)
        local best, lines = 0, {}
        for school = 2, 7 do
            local chance = GetSpellCritChance(school)
            best = math.max(best, chance)
            lines[#lines + 1] = { SPELL_SCHOOLS[school - 1], string.format("%.2f%%", chance) }
        end
        local value = string.format("%.2f%%", best)
        row:Set("Crit Chance", value, "Crit Chance " .. value, unpack(lines))
    end;

    ManaRegen = function(self, row)
        local base, casting = GetManaRegen()
        local value = string.format("%.0f", base * 5)
        row:Set("Mana Regen", value, "Mana Regen " .. value,
            { "Every 5 sec. while not casting", string.format("%.1f", base * 5) },
            { "Every 5 sec. while casting", string.format("%.1f", casting * 5) })
    end;

    -- ---- defense -------------------------------------------------------

    Armor = function(self, row, unit)
        local base, effective, _, pos, neg = UnitArmor(unit)
        if unit ~= "player" then base, pos, neg = effective, 0, 0 end
        local level = UnitLevel(unit)
        row:Set(ARMOR, self:_Tint(effective, pos, neg),
            self:_Breakdown(ARMOR, effective, base, pos, neg),
            ARMOR_TOOLTIP:format(level, C_PaperDollInfo.GetArmorEffectiveness(effective, level) * 100))
    end;

    Defense = function(self, row, unit)
        local base, modifier = UnitDefense(unit)
        local pos, neg = math.max(modifier, 0), math.min(modifier, 0)
        row:Set(DEFENSE, self:_Tint(base + modifier, pos, neg),
            self:_Breakdown(DEFENSE, base + modifier, base, pos, neg))
    end;

    Dodge = function(self, row)
        local value = string.format("%.2f%%", GetDodgeChance())
        row:Set("Dodge", value, "Dodge " .. value, "Your chance to dodge melee attacks.")
    end;

    Parry = function(self, row)
        local value = string.format("%.2f%%", GetParryChance())
        row:Set("Parry", value, "Parry " .. value, "Your chance to parry melee attacks from the front.")
    end;

    Block = function(self, row)
        local value = string.format("%.2f%%", GetBlockChance())
        row:Set("Block", value, "Block " .. value,
            "Your chance to block attacks from the front with a shield.",
            { "Damage blocked", tostring(GetShieldBlock()) })
    end;

    -- argument: the school's resistance id (2 fire .. 6 arcane).
    Resistance = function(self, row, unit, school)
        local base, total, pos, neg = UnitResistance(unit, school)
        local value = tostring(total)
        if math.abs(neg) > pos then
            value = RED .. total .. CLOSE
        elseif math.abs(neg) < pos then
            value = GREEN .. total .. CLOSE
        end
        local level = math.max(UnitLevel(unit), 20)
        local ratio = total / level
        local rating = RESISTANCE_NONE
        if ratio > 5 then rating = RESISTANCE_EXCELLENT
        elseif ratio > 3.75 then rating = RESISTANCE_VERYGOOD
        elseif ratio > 2.5 then rating = RESISTANCE_GOOD
        elseif ratio > 1.25 then rating = RESISTANCE_FAIR
        elseif ratio > 0 then rating = RESISTANCE_POOR end
        row:Set(SCHOOLS[school], value,
            self:_Breakdown(getglobal("RESISTANCE" .. school .. "_NAME"), total, base, pos, neg),
            RESISTANCE_TOOLTIP_SUBTEXT:format(getglobal("RESISTANCE_TYPE" .. school), level, rating))
        row:SetIcon(RESISTANCE_TILES, 32, 256, 3, RESISTANCE_TILE[school] + 1, 26, 27)
    end;

    -- ---- item level ----------------------------------------------------

    -- The average level of what is worn, a two-hander counting for both hands.
    ItemLevel = function(self)
        local total = 0
        for _, slot in ipairs(LEVEL_SLOTS) do
            local link = GetInventoryItemLink("player", slot)
            if link then
                local _, _, _, level, _, _, _, _, equipLoc = C_Item.GetItemInfo(link)
                level = level or 0
                total = total + level
                if slot == 16 and equipLoc == "INVTYPE_2HWEAPON" and not GetInventoryItemLink("player", 17) then
                    total = total + level
                end
            end
        end
        return total / #LEVEL_SLOTS
    end;
}

-- ---------------------------------------------------------------------
-- CharacterStatRow: retail's CharacterStatFrameTemplate.
-- ---------------------------------------------------------------------
class "CharacterStatRow" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(ROW_W, ROW_H)

        self._stripe = Texture(self, nil, "BACKGROUND")
        self._stripe:SetTextureRegion(SHEET, 1024, 1024, 1, 788, 157, 19)
        self._stripe:SetSize(157, 19)
        self._stripe:SetAlpha(0.3)
        self._stripe:CenterInParent()

        self._label = FontString(self, nil, "ARTWORK")
        self._label:SetFontSize(10)
        self._label:SetTextColor(1, 0.82, 0, 1)
        self._label:AlignParentLeft(11)

        self._value = FontString(self, nil, "ARTWORK")
        self._value:SetFontSize(10)
        self._value:SetTextColor(1, 1, 1, 1)
        self._value:AlignParentRight(8)

        self:SetTooltip("ANCHOR_RIGHT", function(tooltip) self:_BuildTooltip(tooltip) end)
    end;

    SetStriped = function(self, striped)
        self._stripe:SetVisible(striped)
    end;

    Set = function(self, label, value, title, ...)
        self._label:SetText(label .. ":")
        self._value:SetText(value)
        self._title = title
        self._lines = { ... }
    end;

    -- A tiny picture before the label: a region of a texture, given as
    -- Texture:SetTextureRegion takes it.
    SetIcon = function(self, path, fileW, fileH, x, y, w, h)
        if not self._icon then
            self._icon = Texture(self, nil, "ARTWORK")
            self._icon:SetSize(13, 13)
            self._icon:AlignParentLeft(10)
            self._label:ClearAllPoints()
            self._label:AlignParentLeft(26)
        end
        self._icon:SetTextureRegion(path, fileW, fileH, x, y, w, h)
    end;

    _BuildTooltip = function(self, tooltip)
        tooltip:AddLine(self._title, 1, 1, 1, false, 13)
        for _, line in ipairs(self._lines) do
            if type(line) == "table" then
                tooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1, 10.5)
            else
                tooltip:AddLine(line, 1, 0.82, 0, true)
            end
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterStatSheet
-- ---------------------------------------------------------------------
class "CharacterStatSheet" : extends "Frame" {
    __init = function(self, parent, unit, sections, withItemLevel)
        Frame.__init(self, "Frame", parent)
        self:FillParent()
        self.unit = unit
        self._rows = {}

        local _, class = UnitClass("player")
        local art = CLASS_ART[class]
        local backdrop = Texture(self, nil, "BACKGROUND")
        backdrop:SetTextureRegion(art[1], 1024, art[2], art[3], art[4], PANE_W, PANE_H)
        backdrop:SetSize(PANE_W, PANE_H)
        backdrop:AlignParentTopLeft()

        self._scroll = CharacterScrollArea(self, PANE_H, ROW_H * 2, "shy")
        self._scroll:FillParent()
        local content = self._scroll.content

        local y = 2
        if withItemLevel then
            self:_Plate(content, "Item Level", y)
            y = y + PLATE_H
            y = y + self:_BuildItemLevel(content, y)
        end
        for _, section in ipairs(sections) do
            self:_Plate(content, section[1], y)
            y = y + PLATE_H + 2
            for i, stat in ipairs(section[2]) do
                local row = CharacterStatRow(content)
                row:AlignParentTop(y)
                row:SetStriped(i % 2 == 0)
                row.method, row.argument = stat[1], stat[2]
                self._rows[#self._rows + 1] = row
                y = y + ROW_H
            end
        end
        self._scroll:SetContentHeight(y + 4)

        -- The stat events come in bursts: one refresh a frame, while showing.
        for _, event in ipairs(EVENTS) do
            self:RegisterEventHandler(event, function() self._stale = true end)
        end
        self:HookScript("OnShow", function() self:Refresh() end)
        self:HookScript("OnUpdate", function()
            if self._stale then self:Refresh() end
        end)
    end;

    -- A category's title plate, `y` below the content's top.
    _Plate = function(self, content, title, y)
        local plate = Texture(content, nil, "BACKGROUND")
        plate:SetTextureRegion(SHEET, 1024, 1024, 1, 715, 196, 40)
        plate:SetSize(PANE_W, PLATE_H)
        plate:AlignParentTop(y)
        local text = FontString(content, nil, "ARTWORK")
        text:SetFontSize(12)
        text:SetTextColor(1, 1, 1, 1)
        text:CenterAt(plate, 0, 1)
        text:SetText(title)
    end;

    -- Retail's ItemLevelFrame: the one big number. Returns its height.
    _BuildItemLevel = function(self, content, y)
        local glow = Texture(content, nil, "BACKGROUND")
        glow:SetTextureRegion(SHEET, 1024, 1024, 1, 757, 162, 29)
        glow:SetSize(162, 29)
        glow:SetAlpha(0.3)
        glow:AlignParentTop(y)

        local holder = Frame("Frame", content)
        holder:SetSize(ROW_W, 29)
        holder:AlignParentTop(y)
        self._itemLevel = FontString(holder, nil, "ARTWORK")
        self._itemLevel:SetFontSize(15, "OUTLINE")
        self._itemLevel:SetTextColor(1, 1, 1, 1)
        self._itemLevel:CenterInParent()
        holder:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(string.format("Item Level %.2f", self._itemLevelValue or 0), 1, 1, 1, false, 13)
            tooltip:AddLine("The average item level of your equipped items.", 1, 0.82, 0, true)
        end)
        return 29
    end;

    Refresh = function(self)
        self._stale = false
        if not UnitExists(self.unit) then return end
        local source = MUI_CharacterStatSource
        for _, row in ipairs(self._rows) do
            source[row.method](source, row, self.unit, row.argument)
        end
        if self._itemLevel then
            self._itemLevelValue = source:ItemLevel()
            self._itemLevel:SetText(math.floor(self._itemLevelValue))
        end
    end;
}
