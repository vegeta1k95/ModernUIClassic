
local TEX_THUMBNAILS = MUI.TEX_SKIN .. "talents\\spec-thumbnails"
local TEX            = MUI.TEX_SKIN .. "talents\\spec"

local SPEC_THUMBNAILS = {
    [1] = {                 -- WARRIOR
        {x=616,  y=940},
        {x=924,  y=940},
        {x=1232, y=940},
    },
    [2] = {                 -- PALADIN
        {x=924,  y=564},
        {x=1232, y=564},
        {x=1540, y=564},
    },
    [3] = {                 -- HUNTER
        {x=0,    y=376},
        {x=308,  y=376},
        {x=616,  y=376},
    },
    [4] = {                 -- ROGUE
        {x=924,  y=752},
        {x=1232, y=752},
        {x=1540, y=752},
    },
    [5] = {                 -- PRIEST
        {x=0,    y=752},
        {x=308,  y=752},
        {x=616,  y=752},
    },
    [6] = {{}, {}, {}},     -- (none — DK reserved)
    [7] = {                 -- SHAMAN
        {x=0,    y=940},
        {x=0,    y=1128},
        {x=0,    y=1316},
    },
    [8] = {                 -- MAGE
        {x=924,  y=376},
        {x=1232, y=376},
        {x=1540, y=376},
    },
    [9] = {                 -- WARLOCK
        {x=0,    y=1504},
        {x=0,    y=1692},
        {x=308,  y=940},
    },
    [11] = {                -- DRUID
        {x=1540, y=0},
        {x=308,  y=188},
        {x=616,  y=188},
    },
}

local SPEC_FLAVOR = {
    [1] = {                 -- WARRIOR
        "A battle-hardened master of weapons, using mobility and overpowering attacks to strike their opponents down.",
        "A furious dual-wielding berserker unleashing a flurry of attacks to carve their opponents to pieces.",
        "A stalwart protector who uses a shield to safeguard themselves and their allies.",
    },
    [2] = {                 -- PALADIN
        "Invokes the power of the Light to heal and protect allies and vanquish evil from the darkest corners of the world.",
        "Uses Holy magic to shield themselves and defend allies from attackers.",
        "A righteous crusader who judges and punishes opponents with weapons and Holy magic.",
    },
    [3] = {                 -- HUNTER
        "A master of the wild who can tame a wide variety of beasts to assist them in combat.",
        "A master sharpshooter who excels in bringing down enemies from afar.",
        "An adaptive ranger who favors using explosives, animal venom, and coordinated attacks with their bonded beast.",
    },
    [4] = {                 -- ROGUE
        "A deadly master of poisons who dispatches victims with vicious dagger strikes.",
        "A ruthless fugitive who uses agility and guile to stand toe-to-toe with enemies.",
        "A dark stalker who leaps from the shadows to ambush their unsuspecting prey.",
    },
    [5] = {                 -- PRIEST
        "Shields allies from harm and cures their wounds by smiting enemies.",
        "A versatile healer who can reverse damage on individuals or groups and even heal from beyond the grave.",
        "Uses sinister Shadow magic and terrifying Void magic to eradicate enemies.",
    },
    [6] = { "", "", "" },   -- (none — DK reserved)
    [7] = {                 -- SHAMAN
        "A spellcaster who harnesses the destructive forces of nature and the elements.",
        "A totemic warrior who strikes foes with weapons imbued with elemental power.",
        "A healer who calls upon ancestral spirits and the cleansing power of water to mend allies' wounds.",
    },
    [8] = {                 -- MAGE
        "Manipulates raw Arcane magic, destroying enemies with overwhelming power.",
        "Focuses the pure essence of Fire magic, assaulting enemies with combustive flames.",
        "Freezes enemies in their tracks and shatters them with Frost magic.",
    },
    [9] = {                 -- WARLOCK
        "A master of shadow magic who specializes in drains and damage-over-time spells.",
        "A commander of demons who twists the souls of their army into devastating power.",
        "A master of chaos who calls down fire to burn and demolish enemies.",
    },
    [11] = {                -- DRUID
        "Can shapeshift into a powerful Moonkin, balancing the power of Arcane and Nature magic to destroy enemies.",
        "Takes on the form of a great cat to deal damage with bleeds and bites or a mighty bear to absorb damage and protect allies.",
        "Channels powerful Nature magic to regenerate and revitalize allies.",
    },
}


class "SpecAbility" : extends "Frame" {

    _ICON_SIZE = 46;

    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)

        self:SetSize(self._ICON_SIZE, self._ICON_SIZE)

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:SetSize(self._ICON_SIZE, self._ICON_SIZE)
        self._icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
        self._icon:CenterInParent()

        self._bg = Texture(self, nil, "OVERLAY")
        self._bg:SetTextureRegion(MUI.TEX_SKIN .. "talents\\spec-ability-border", 64, 64, 2, 2, 60, 60)
        self._bg:FillParent(-4)

    end;

    SetTalent = function(self, talentID, icon)
        if icon then self._icon:SetPortrait(icon) end
        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:SetTalent(talentID, false, false, nil)
        end)
    end;

    SetSpell = function(self, spellID)
        local info = C_Spell.GetSpellInfo(spellID)
        self._icon:SetPortrait(info.iconID)
        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:SetSpellByID(spellID)
        end)
    end;

}

class "SpecColumn" : extends "SecureActionButton" {

    __init = function(self, parent, selectorMode)
        SecureActionButton.__init(self, parent)

        self._isHovered = false
        self._isSelected = false

        self._selectorMode = selectorMode or 0      -- 0 - both, 1 - left, 2 - right, 3 - mild

        self._thumbnail = Texture(self, nil, "ARTWORK")
        self._thumbnail:AlignParentTop(42)
        self._thumbnail:SetSize(273, 166.5)

        self._thumbnailBorder = Texture(self, nil, "OVERLAY")
        self._thumbnailBorder:Fill(self._thumbnail, -7, -7, -7, -7)
        self._thumbnailBorder:SetTextureRegion(TEX, 2048, 2048, 2, 1718, 320, 200)

        self._selectionBg1 = Texture(self, nil, "BACKGROUND")
        self._selectionBg1:SetTextureRegion(TEX, 2048, 2048, 0, 858, 397, 858)
        self._selectionBg1:SetAlpha(0.1)
        self._selectionBg1:SetBlendMode("ADD")
        self._selectionBg1:FillParentPadding()
        self._selectionBg1:Hide()

        self._selectionBg2 = Texture(self, nil, "BACKGROUND")
        self._selectionBg2:SetTextureRegion(TEX, 2048, 2048, 0, 858, 397, 858)
        self._selectionBg2:SetAlpha(0.1)
        self._selectionBg2:SetBlendMode("MOD")
        self._selectionBg2:FillParentPadding()
        self._selectionBg2:Hide()

        self._selectionL1 = Texture(self, nil, "BACKGROUND")
        self._selectionL1:SetTextureRegion(TEX, 2048, 2048, 794, 858, 397, 858)
        self._selectionL1:SetAlpha(0.3)
        self._selectionL1:SetBlendMode("ADD")
        self._selectionL1:FillParentPadding()
        self._selectionL1:Hide()

        self._selectionL2 = Texture(self, nil, "BACKGROUND")
        self._selectionL2:SetTextureRegion(TEX, 2048, 2048, 1191, 858, 397, 858)
        self._selectionL2:SetAlpha(0.5)
        self._selectionL2:SetBlendMode("ADD")
        self._selectionL2:FillParentPadding()
        self._selectionL2:Hide()

        self._selectionL3 = Texture(self, nil, "BACKGROUND")
        self._selectionL3:SetTextureRegion(TEX, 2048, 2048, 1588, 858, 397, 858)
        self._selectionL3:SetAlpha(1)
        self._selectionL3:SetBlendMode("ADD")
        self._selectionL3:FillParentPadding()
        self._selectionL3:Hide()

        self._selectionR1 = Texture(self, nil, "BACKGROUND")
        self._selectionR1:SetTextureRegion(TEX, 2048, 2048, 794, 858, 397, 858, true)
        self._selectionR1:SetAlpha(0.3)
        self._selectionR1:SetBlendMode("ADD")
        self._selectionR1:FillParentPadding()
        self._selectionR1:Hide()

        self._selectionR2 = Texture(self, nil, "BACKGROUND")
        self._selectionR2:SetTextureRegion(TEX, 2048, 2048, 1191, 858, 397, 858, true)
        self._selectionR2:SetAlpha(0.5)
        self._selectionR2:SetBlendMode("ADD")
        self._selectionR2:FillParentPadding()
        self._selectionR2:Hide()

        self._selectionR3 = Texture(self, nil, "BACKGROUND")
        self._selectionR3:SetTextureRegion(TEX, 2048, 2048, 1588, 858, 397, 858, true)
        self._selectionR3:SetAlpha(1)
        self._selectionR3:SetBlendMode("ADD")
        self._selectionR3:FillParentPadding()
        self._selectionR3:Hide()


        -- ====== Labels ======= --

        self._title = FontString(self, nil, "OVERLAY")
        self._title:Below(self._thumbnail, 43)
        self._title:FillWidth(40)
        self._title:SetHeight(40)
        self._title:SetJustifyH("CENTER")
        self._title:SetFont(MUI.FONT, 27, "")

        self._role = Frame("Frame", self)
        self._role:Below(self._title, 2)

        self._roleIcon = Texture(self._role, nil, "OVERLAY")
        self._roleIcon:SetSize(26, 26)
        self._roleIcon:AlignParentLeft()

        self._roleName = FontString(self._role, nil, "OVERLAY")
        self._roleName:SetFont(MUI.FONT, 13, "")
        self._roleName:SetShadowOffset(1, -1)
        self._roleName:SetTextColor(1, 0.82, 0, 1)
        self._roleName:RightOf(self._roleIcon, 6, -1)

        local separator = Texture(self, nil, "BACKGROUND")
        separator:SetTextureRegion(TEX, 2048, 2048, 0, 1920, 262, 4)
        separator:SetSize(240, 1)
        separator:Below(self._role, 32)
        separator:SetAlpha(0.2)

        self._flavorText = FontString(self, nil, "OVERLAY")
        self._flavorText:SetFontSize(13)
        self._flavorText:SetShadowOffset(1, -1)
        self._flavorText:SetTextColor(1, 0.82, 0, 1)
        self._flavorText:Below(separator, 23)
        self._flavorText:SetTextHeight(13)
        self._flavorText:SetSize(230, 100)
        
        self._flavorText:SetJustifyH("CENTER")
        self._flavorText:SetJustifyV("TOP")
        self._flavorText:SetText("SUKA")

        local spellsHeader = FontString(self)
        spellsHeader:Below(self._flavorText, 44)
        spellsHeader:SetFontSize(13)
        spellsHeader:SetText("Abilities showcase")
        spellsHeader:SetSize(spellsHeader:GetStringWidth() + 2, 13)

        local spells = Frame("Frame", self)
        spells:Below(spellsHeader, 16)
        self._ability1 = SpecAbility(spells)
        self._ability2 = SpecAbility(spells)
        self._ability1:AlignParentLeft(-4)
        self._ability2:RightOf(self._ability1, 15)
        spells:SetSize(self._ability1:GetWidth() * 2 + 4, self._ability1:GetHeight())

        self:EnableMouse(true)
        self:SetScript("OnEnter", function ()
            self._isHovered = true
            self:_RefreshVisual()
        end)
        self:SetScript("OnLeave", function ()
            self._isHovered = false
            self:_RefreshVisual()
        end)
        self:_RefreshVisual()

    end;

    SetSelected = function(self, selected)
        self._isSelected = selected
        self:_RefreshVisual()
    end;

    SetSpec = function(self, index)
        local _, _, classID = UnitClass("player")
        local _, name = GetTalentTabInfo(index)
        local coords = SPEC_THUMBNAILS[classID]
        self._thumbnail:SetTextureRegion(TEX_THUMBNAILS, 2048, 2048, coords[index].x, coords[index].y, 308, 188)
        self._title:SetText(name)
        self._flavorText:SetText(SPEC_FLAVOR[classID][index])

        self:_SetRole(MUI_Talents:GetSpecRole(index))
        self:_SetAbilities(classID, index)

    end;

    _SetAbilities = function(self, classID, index)
        local bucket = MUI_DB.data.spells.class[index]
        if not bucket then return end

        -- Gather all talent defs in this spec's bucket.
        local talents = {}
        for _, defs in pairs(bucket) do
            for _, d in ipairs(defs) do
                if d.source == "talent" and d.gridY then
                    table.insert(talents, d)
                end
            end
        end
        if #talents == 0 then return end

        -- Capstone: maxRank == 1, max gridY (last row). Pick the bottom-most
        -- single-rank talent.
        local capstone
        for _, d in ipairs(talents) do
            if (d.maxRank == 1) and (not capstone or d.gridY > capstone.gridY) then
                capstone = d
            end
        end

        -- Exceptional: any other isExceptional talent, preferring later
        -- (higher gridY) ones, excluding the capstone.
        local exceptional
        for _, d in ipairs(talents) do
            if d.isExceptional and d ~= capstone then
                if not exceptional or d.gridY > exceptional.gridY then
                    exceptional = d
                end
            end
        end

        -- Fallback: talent with the least amount of points
        if not exceptional then
            for _, d in ipairs(talents) do
                if not exceptional and d.talentID ~= capstone.talentID then
                    exceptional = d
                end
                if d.maxRank < exceptional.maxRank and d.talentID ~= capstone.talentID then
                    exceptional = d
                end

            end
        end

        local function apply(slot, d)
            if not d then return end
            if d.spellID then
                slot:SetSpell(d.spellID)
            elseif d.talentID then
                slot:SetTalent(d.talentID, d.icon)
            end
        end

        apply(self._ability1, exceptional)
        apply(self._ability2, capstone)
    end;

    _SetRole = function(self, role)
        
        if role == "dps" then
            self._roleIcon:SetTextureRegion(MUI.TEX_BASE .. "roles", 2048, 2048, 0, 1804, 59, 59)
            self._roleName:SetText("Damage")
        elseif role == "heal" then
            self._roleIcon:SetTextureRegion(MUI.TEX_BASE .. "roles", 2048, 2048, 0, 1930, 59, 59)
            self._roleName:SetText("Healer")
        elseif role == "tank" then
            self._roleIcon:SetTextureRegion(MUI.TEX_BASE .. "roles", 2048, 2048, 189, 1804, 59, 59)
            self._roleName:SetText("Tank")
        end

        self._role:SetSize(self._roleIcon:GetWidth() + 4 + self._roleName:GetStringWidth(), self._roleIcon:GetHeight())

    end;

    _RefreshVisual = function(self)

        if (MUI_Talents:GetPrimarySpec()) and not self._isSelected then

            if self._isHovered then
                self._selectionBg1:Show()
            else
                self._selectionBg1:Hide()
            end

        else
            if self._isSelected or self._isHovered then
                self._thumbnailBorder:SetTextureRegion(TEX, 2048, 2048, 399, 1718, 320, 200)
                self._selectionBg1:Show()
                self._selectionBg2:Show()

                if self._selectorMode == 0 or self._selectorMode == 1 then
                    self._selectionL1:Show()
                    self._selectionL2:Show()
                    self._selectionL3:Show()
                end

                if self._selectorMode == 0 or self._selectorMode == 2 then
                    self._selectionR1:Show()
                    self._selectionR2:Show()
                    self._selectionR3:Show()
                end

            else
                self._thumbnailBorder:SetTextureRegion(TEX, 2048, 2048, 2, 1718, 320, 200)
                self._selectionBg1:Hide()
                self._selectionBg2:Hide()

                self._selectionL1:Hide()
                self._selectionL2:Hide()
                self._selectionL3:Hide()

                self._selectionR1:Hide()
                self._selectionR2:Hide()
                self._selectionR3:Hide()
            end
        end
    end;
}


class "TabSpecializations" : extends "SecureFrame" {

    __init = function(self, parent)
        SecureFrame.__init(self, parent, "MUI_TabSpecsFrame")

        self:FillParent()

        local SPEC_WIDTH = 485

        self._spec2 = SpecColumn(self, 0)
        self._spec2:FillHeight()
        self._spec2:CenterInParent()
        self._spec2:SetWidth(SPEC_WIDTH)

        self._spec1 = SpecColumn(self, 2)
        self._spec1:FillHeight()
        self._spec1:AlignParentLeft()
        self._spec1:LeftOf(self._spec2)

        self._spec3 = SpecColumn(self, 1)
        self._spec3:FillHeight()
        self._spec3:AlignParentRight()
        self._spec3:RightOf(self._spec2)

        self._spec1:SetMacroText("/click MUI_ClassbookTabBtnTalents")
        self._spec1:HookScript("OnClick", function() MUI_ClassBookFrame:GoToTalents(1) end)

        self._spec2:SetMacroText("/click MUI_ClassbookTabBtnTalents")
        self._spec2:HookScript("OnClick", function() MUI_ClassBookFrame:GoToTalents(2) end)

        self._spec3:SetMacroText("/click MUI_ClassbookTabBtnTalents")
        self._spec3:HookScript("OnClick", function() MUI_ClassBookFrame:GoToTalents(3) end)


        local separator1 = Texture(self)
        separator1:SetTextureRegion(TEX, 2048, 2048, 2011.3, 0, 9, 858)
        separator1:FillHeight()
        separator1:LeftOf(self._spec2, -3.5)
        separator1:SetWidth(7)

        local separator2 = Texture(self)
        separator2:SetTextureRegion(TEX, 2048, 2048, 2011.3, 0, 9, 858)
        separator2:FillHeight()
        separator2:RightOf(self._spec2, -3.5)
        separator2:SetWidth(7)

        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function ()
            self._spec1:SetSpec(1)
            self._spec2:SetSpec(2)
            self._spec3:SetSpec(3)
            self:_Refresh()
        end)

        self:RegisterEventHandler("CHARACTER_POINTS_CHANGED", function() self:_Refresh() end)
        self:RegisterEventHandler("ACTIVE_TALENT_GROUP_CHANGED", function() self:_Refresh() end)

    end;

    _Refresh = function(self)
        local spec = MUI_Talents:GetPrimarySpec()
        local index = spec and spec.index
        self._spec1:SetSelected(index == 1)
        self._spec2:SetSelected(index == 2)
        self._spec3:SetSelected(index == 3)
    end;

}
