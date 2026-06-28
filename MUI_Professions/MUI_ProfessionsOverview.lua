-- ProfessionsOverviewFrame: recreates retail's ProfessionsBookFrame on Classic Era.
-- Singleton instance auto-created at MUI_ProfessionsOverviewFrame.

local TEX_PATH = MUI.TEX_SKIN .. "professions\\"

-- Key Bindings panel label for the binding declared in Bindings.xml.
-- The binding sits under the "Interface Panel" section (Blizzard's existing
-- BINDING_HEADER_INTERFACE), alongside Spellbook / Quest Log / etc.
BINDING_NAME_MUI_TOGGLE_PROFESSIONS = "Toggle Professions Pane"

-- Profession catalog + rank-title resolution live in MUI_Professions.lua
-- (the ModuleProfessions singleton). This file just consumes its accessors
-- + subscribes to its change notifications.

class "ProfessionSlotProgress" : extends "Frame" {

    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        
        self._capLeft = Texture(self, nil, "BACKGROUND")
        self._capRight = Texture(self, nil, "BACKGROUND")

        self._capLeftFill = Texture(self, nil, "ARTWORK")
        self._capRightFill = Texture(self, nil, "ARTWORK")

        self._capLeft:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 1, 62, 17, 15)
        self._capLeft:AlignParentTopLeft()
        self._capLeft:AlignParentBottomLeft()
        self._capLeft:SetWidth(13)

        self._capLeftFill:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 1, 112, 13, 12)
        self._capLeftFill:Fill(self._capLeft, 3.5,3,0,1.5)
        
        self._capRight:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 0, 80, 17, 15)
        self._capRight:AlignParentTopRight()
        self._capRight:AlignParentBottomRight()
        self._capRight:SetWidth(13)

        self._capRightFill:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 0, 98, 13, 12)
        self._capRightFill:Fill(self._capRight, 0,3,3.5,1.5)
        self._capRightFill:Hide()


        self._middle = Texture(self, nil, "BACKGROUND")
        self._middle:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 0, 1, 256, 15)
        self._middle:FillBetweenH(self._capLeft, self._capRight)

        -- Pin LEFT + TOP + BOTTOM to capLeftFill (no right anchor) so _Refresh
        -- can drive the width directly via SetWidth.
        self._middleFill = Texture(self, nil, "ARTWORK")
        self._middleFill:SetTextureRegion(TEX_PATH .. "professions-book-progress-fill", 256, 16, 0, 0, 256, 12)
        self._middleFill:RightOf(self._capLeftFill)
        self._middleFill:AlignTop(self._capLeftFill)
        self._middleFill:AlignBottom(self._capLeftFill)

        self._text = FontString(self)
        self._text:CenterInParent()
        self._text:SetFont(MUI.FONT, 9, "OUTLINE")

        self._maxValue = 300
        self._value = 1
    end;

    SetMaxValue = function(self, value)
        self._maxValue = value
        self._value = math.min(self._value, self._maxValue)
        self:_Refresh()
    end;

    SetValue = function(self, value)
        self._value = math.min(value, self._maxValue)
        self:_Refresh()
    end;

    _Refresh = function(self)
        self._text:SetText(self._value .. "/" .. self._maxValue)
        local progress = math.max(0, math.min(1, self._value / self._maxValue))

        -- Bar layout: [capLeft 13px][middle][capRight 13px]. The fill mirrors
        -- this: capLeftFill draws the rounded left tip inside capLeft, middleFill
        -- stretches across the gap, capRightFill draws the rounded right tip
        -- inside capRight. middleFill spans (totalWidth - 13 - 13) at 100%.
        
        local fullMiddleWidth = self:GetWidth() - 26

        if progress <= 0 then
            self._capLeftFill:Hide()
            self._middleFill:Hide()
            self._capRightFill:Hide()
        elseif progress >= 1 then
            self._capLeftFill:Show()
            self._middleFill:Show()
            self._middleFill:SetWidth(fullMiddleWidth)
            self._capRightFill:Show()
        else
            self._capLeftFill:Show()
            self._middleFill:Show()
            self._middleFill:SetWidth(fullMiddleWidth * progress)
            self._capRightFill:Hide()
        end
    end;
}

class "ProfessionSpellSlot" : extends "Frame" {

    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)

        local H_FRAME = 37

        local W_FRAME = 98
        local W_ICON = 36
        local W_PADDING = 1

        self._frame = Texture(self)
        self._frame:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 1, 19, 108, 41)
        self._frame:AlignParentRight()
        self._frame:FillHeight()
        self._frame:SetWidth(98)

        -- Secure frames can't anchor to regions (textures/fontstrings) — they
        -- must anchor to another frame. Anchor against parent's left edge; the
        -- background frame texture sits to the right via AlignParentRight, so
        -- the two meet naturally with the padding baked into outer size.
        self._iconFrame = SecureActionButton(self)
        self._iconFrame:SetSize(W_ICON, H_FRAME - 1)
        self._iconFrame:AlignParentLeft()
        self._iconFrame:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if not self._spell then return end
            if self._spell.spellID then
                -- SetSpellByID auto-sizes the tooltip to fit the spell
                -- description. SetHyperlink("spell:...") uses the default
                -- tooltip width and truncates long description lines with "...".
                tooltip:SetSpellByID(self._spell.spellID)
            else
                tooltip:SetText(self._spell.name)
            end
        end)
        self._iconFrame:RegisterForDrag("LeftButton")
        self._iconFrame:SetScript("OnDragStart", function()
            if self._spell and self._spell.spellID then
                PickupSpell(self._spell.spellID)
            end
        end)

        self._icon = Texture(self._iconFrame, nil, "ARTWORK")
        self._icon:SetTexture("Interface\\Icons\\INV_Scroll_04")
        self._icon:FillParent()

        -- Hover highlight overlay (HIGHLIGHT layer auto-shows on mouse-over).
        self._highlight = Texture(self._iconFrame, nil, "HIGHLIGHT")
        self._highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        self._highlight:SetBlendMode("ADD")
        self._highlight:Fill(self._iconFrame)

        self._name = FontString(self)
        self._name:SetText("Spell Name")
        self._name:SetTextColor(1, 0.82, 0, 1)
        self._name:SetFontSize(10.5)
        self._name:SetShadowOffset(1, -1)
        self._name:Fill(self._frame, 3,3,3,3)

        self:SetSize(W_FRAME + W_ICON + W_PADDING, H_FRAME)
    end;

    SetProfessionSpell = function(self, spell)
        if not spell then
            self._spell = nil
            self:Hide()
            return
        end
        self:Show()
        self._spell = spell
        self._icon:SetTexture(spell.icon)
        self._name:SetText(spell.name)
        -- Secure attrs drive click → spell cast (works in combat because the
        -- click flows through Blizzard's SecureActionButton dispatch). The
        -- SetAttribute itself is forbidden in combat though — guard against
        -- mid-combat profession changes. When combat ends, _Refresh fires
        -- again via PLAYER_REGEN_ENABLED-driven SKILL_LINES_CHANGED replay
        -- (or the next OnShow), reapplying the attrs.
        if not InCombatLockdown() then
            self._iconFrame:SetAttribute("type", "spell")
            self._iconFrame:SetAttribute("spell", spell.name)
        end
    end
}

class "ProfessionSlot" : extends "Frame" {

    __init = function(self, parent, index)
        Frame.__init(self, "Frame", parent)

        self:SetHeight(80)
        self:AlignParentRight(28)

        self._index = index or 0

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:AlignParentLeft()
        self._icon:SetTexture("Interface\\Icons\\INV_Scroll_04")
        self._icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        self._icon:SetDesaturated(true)
        self._icon:SetBlendMode("ADD")
        self._icon:SetSize(65, 65)
        self._icon:SetVertexColor(1, 1, 1, 0.6)

        local iconBg = Texture(self, nil, "OVERLAY")
        iconBg:SetTextureRegion(TEX_PATH .. "professions-book", 256, 128, 111, 19, 74, 74)
        iconBg:SetSize(66, 66)
        iconBg:CenterAt(self._icon)

        self._name = FontString(self)
        self._name:AlignParentTop(4)
        self._name:RightOf(self._icon, 18)
        self._name:SetText("Herbalism")
        self._name:SetFont(MUI.FONT_CAL, 17.5, "")
        self._name:SetShadowOffset(1, -1)
        self._name:SetTextColor(0.85, 0.7, 0.6, 1)

        self._progress = ProfessionSlotProgress(self)
        self._progress:AlignLeft(self._name, -3)
        self._progress:AlignParentBottom(5)
        self._progress:SetSize(114, 14)
        self._progress:SetValue(1)

        -- Abandon-profession button: same red-X texture retail uses
        -- (Interface\Buttons\UI-GroupLoot-Pass-Up). Sits just left of the
        -- progress bar; click triggers Blizzard's UNLEARN_SKILL static popup
        -- which on confirm calls AbandonSkill(skillIndex).
        self._abandonBtn = Button(self)
        self._abandonBtn:SetSize(16, 16)
        self._abandonBtn:LeftOf(self._progress, 3)

        self._abandonIcon = Texture(self._abandonBtn, nil, "ARTWORK")
        self._abandonIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        self._abandonIcon:SetAlpha(0.75)
        self._abandonIcon:FillParent()

        self._abandonBtn:SetScript("OnEnter", function()
            self._abandonIcon:SetAlpha(1.0)
        end)
        self._abandonBtn:SetScript("OnLeave", function()
            self._abandonIcon:SetAlpha(0.75)
        end)
        self._abandonBtn:SetScript("OnMouseDown", function()
            self._abandonIcon:Fill(self._abandonBtn, 1, 1, -1, -1)
        end)
        self._abandonBtn:SetScript("OnMouseUp", function()
            self._abandonIcon:FillParent()
        end)
        self._abandonBtn:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:SetText(UNLEARN_SKILL_TOOLTIP or "Abandon Profession")
        end)
        self._abandonBtn.OnClick = function()
            local prof = self._profession
            if prof and prof.skillIndex then
                StaticPopup_Show("UNLEARN_SKILL", prof.name, nil, prof.skillIndex)
            end
        end

        self._status = FontString(self)
        self._status:Above(self._progress, 2.5)
        self._status:AlignLeft(self._name, 0)
        self._status:SetShadowOffset(1, -1)
        self._status:SetFontSize(9)
        self._status:SetText("Apprentice Herbalism")

        self._hint = FontString(self)
        self._hint:Below(self._name, 2)
        self._hint:AlignLeft(self._name)
        self._hint:AlignParentRight(40)
        self._hint:SetJustifyH("LEFT")
        self._hint:SetFontSize(9)
        self._hint:SetTextColor(0.1, 0.05, 0.05, 1)
        self._hint:SetText("Consult a profession trainer in one of the major cities to master new areas of expertise. You have the ability to learn any two professions from the gathering and crafting disciplines.")

        self._spellSlot1 = ProfessionSpellSlot(self)
        self._spellSlot1:AlignParentBottomRight(3, 1)

        self._spellSlot2 = ProfessionSpellSlot(self)
        self._spellSlot2:Above(self._spellSlot1, 1)

        self:SetProfession(nil)

    end;

    SetProfession = function(self, profession)

        self._profession = profession

        if profession == nil then

            local title = (self._index == 2) and "Second Profession" or "First Profession"
            self._name:SetTextColor(0.85, 0.7, 0.6, 1)
            self._name:SetText(title)

            self._name:ClearAllPoints()
            self._name:AlignTop(self._icon, 4)
            self._name:RightOf(self._icon, 37)

            self._icon:SetTexture("Interface\\Icons\\INV_Scroll_04")

            self._progress:Hide()
            self._status:Hide()
            self._hint:Show()
            self._abandonBtn:Hide()

            self._spellSlot1:Hide()
            self._spellSlot2:Hide()

            return
        end

        self._progress:Show()
        self._status:Show()
        self._hint:Hide()
        self._abandonBtn:Show()

        self._name:ClearAllPoints()
        self._name:AlignParentTop(4)
        self._name:RightOf(self._icon, 18)
        self._name:SetTextColor(1, 0.82, 0, 1)

        self._icon:SetTexture(profession.icon)
        self._name:SetText(profession.name)
        self._status:SetText((profession.title or "") .. " " .. (profession.name or ""))

        self._progress:SetMaxValue(profession.maxRank or 300)
        self._progress:SetValue(profession.rank or 1)

        -- spellSlot1 = bottom (primary spell), spellSlot2 = top (secondary).
        -- SetProfessionSpell(nil) hides the slot, so single-spell professions
        -- (e.g., Cooking) just pass spells[2]=nil.
        local spells = profession.spells or {}
        self._spellSlot1:SetProfessionSpell(spells[1])
        self._spellSlot2:SetProfessionSpell(spells[2])
    end

}

class "ProfessionSlotSecondary" : extends "Frame" {

    __init = function(self, parent, name, description)
        Frame.__init(self, "Frame", parent)

        self:SetHeight(62)
        self:AlignParentRight(28)

        self._name = FontString(self)
        self._name:AlignParentLeft()
        self._name:SetText(name)
        self._name:SetFont(MUI.FONT_CAL, 15, "")
        self._name:SetTextColor(0.1, 0.05, 0.05, 1)

        self._progress = ProfessionSlotProgress(self)
        -- Anchor LEFT to parent, not to _name: in SetProfession non-nil,
        -- _name's BOTTOM gets pinned to _status's TOP, _status's BOTTOM is
        -- pinned to _progress's TOP — so anchoring _progress LEFT to _name
        -- would close a cycle (_name → _status → _progress → _name).
        -- _name is itself AlignParentLeft(), so anchoring _progress to the
        -- parent here gives the same horizontal position visually.
        self._progress:AlignParentLeft(-3)
        self._progress:AlignParentBottom(3)
        self._progress:SetSize(114, 14)
        self._progress:SetValue(1)
        self._progress:Hide()

        self._status = FontString(self)
        self._status:Above(self._progress, 2.5)
        self._status:AlignParentLeft()
        self._status:SetShadowOffset(1, -1)
        self._status:SetFontSize(9)
        self._status:SetText(nil)
        
        self._hint = FontString(self)
        self._hint:SetPoint("LEFT", self, "CENTER", -50, 0)
        self._hint:AlignParentRight(40)
        self._hint:SetJustifyH("LEFT")
        self._hint:SetFontSize(9)
        self._hint:SetTextColor(0.1, 0.05, 0.05, 1)
        self._hint:SetText(description)

        
        self._spellSlot1 = ProfessionSpellSlot(self)
        self._spellSlot1:AlignParentRight(1)

        
        self._spellSlot2 = ProfessionSpellSlot(self)
        self._spellSlot2:LeftOf(self._spellSlot1, 1)

        self:SetProfession(nil)

    end;

    SetProfession = function(self, profession)

        if profession == nil then
            self._name:SetTextColor(0.1, 0.05, 0.05, 1)
            self._name:SetShadowOffset(0, 0)

            self._name:ClearAllPoints()
            self._name:AlignParentLeft()

            self._progress:Hide()
            self._status:Hide()
            self._hint:Show()

            self._spellSlot1:Hide()
            self._spellSlot2:Hide()

            return
        end

        self._progress:Show()
        self._status:Show()
        self._hint:Hide()

        self._name:ClearAllPoints()
        self._name:AlignParentLeft()
        self._name:Above(self._status, 4)
        self._name:SetTextColor(1, 0.82, 0, 1)
        self._name:SetShadowOffset(1, -1)

        self._status:SetText((profession.title or "") .. " " .. (profession.name or ""))

        self._progress:SetMaxValue(profession.maxRank or 300)
        self._progress:SetValue(profession.rank or 1)

        local spells = profession.spells or {}
        self._spellSlot1:SetProfessionSpell(spells[1])
        self._spellSlot2:SetProfessionSpell(spells[2])
    end

}

object "ProfessionsOverviewFrame" : extends "PanelPortrait" {

    __init = function(self)
        PanelPortrait.__init(self, nil, "MUI_ProfessionsOverviewFrame", "Professions")
        
        self:SetPortrait(TEX_PATH .. "professions-book-icon")

        self._closeButton = SecureCloseButton(self, "MUI_ProfessionsOverviewCloseButton")
        self._closeButton:SetScale(scale or 0.9)
        self._closeButton:PutInfront(self._border, 2)

        self:AlignParentTopLeft(106, 10)
        self:SetSize(500, 470)

        MUI_ModuleProfessions:Subscribe(function() self:_Refresh() end)
        self:RegisterEventHandler("PLAYER_REGEN_ENABLED", function() self:_Refresh() end)

        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:_ApplyBindingOverride() end)
        self:RegisterEventHandler("UPDATE_BINDINGS",       function() self:_ApplyBindingOverride() end)

        hooksecurefunc("UpdateUIPanelPositions", function()
            if self:IsShown() then self:_Reposition() end
        end)

        self:HookScript("OnShow", function()
            PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
            self:_Refresh()
        end)

        self:HookScript("OnHide", function()
            PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
        end)

        self:Hide()

    end;

    ---@override
    PopulateContent = function(self, content)
        local page = Texture(content, nil, "ARTWORK")
        page:SetTextureRegion(TEX_PATH .. "professions-book-page", 1024, 512, 0, 0, 533, 494)
        page:FillParentPadding(6, 2, 8, 2)

        self._mainSlot1 = ProfessionSlot(content, 1)
        self._mainSlot1:AlignParentTopLeft(37, 78)
        
        self._mainSlot2 = ProfessionSlot(content, 2)
        self._mainSlot2:Below(self._mainSlot1, 5)

        self._secondarySlotCooking = ProfessionSlotSecondary(content, "Cooking", "Visit a trainer to learn Cooking. This profession allows you to learn recipes and cook food. Food restores health and grants temporary beneficial effects.")
        self._secondarySlotCooking:Below(self._mainSlot2, 12)

        self._secondarySlotFishing = ProfessionSlotSecondary(content, "Fishing", "Visit a trainer to learn Fishing. This profession allows you to catch fish and other strange things found in the waters. With basic Cooking skills, you can prepare delicious dishes from fish.")
        self._secondarySlotFishing:Below(self._secondarySlotCooking, 7)
        
        self._secondarySlotFirstAid = ProfessionSlotSecondary(content, "First Aid", "Visit a trainer to learn First Aid. This profession allows you to craft bandages from cloth. Bandages can be used to quickly restore health to yourself or your allies.")
        self._secondarySlotFirstAid:Below(self._secondarySlotFishing, 7)

    end;

    _BuildSpellEntry = function(spellID)
        local name, _, icon = GetSpellInfo(spellID)
        if not name then return nil end
        local override = MUI_IconOverrides and MUI_IconOverrides:GetOverride(spellID)
        if override then icon = override end
        return { name = name, icon = icon, spellID = spellID }
    end;

    -- Read the user's configured key(s) for MUI_TOGGLE_PROFESSIONS and route
    -- each to a secure click on MUI_MicroBtn_Professions. SetOverrideBindingClick
    -- is protected in combat — skip and let the next post-combat UPDATE_BINDINGS
    -- / PLAYER_ENTERING_WORLD re-apply. Clearing first prevents the override
    -- list from growing when the user re-binds.
    _ApplyBindingOverride = function(self)
        if InCombatLockdown() then return end
        if not MUI_MicroBtn_Professions then return end

        ClearOverrideBindings(self._native)
        local k1, k2 = GetBindingKey("MUI_TOGGLE_PROFESSIONS")
        if k1 then
            SetOverrideBindingClick(self._native, false, k1,
                "MUI_MicroBtn_Professions", "LeftButton")
        end
        if k2 then
            SetOverrideBindingClick(self._native, false, k2,
                "MUI_MicroBtn_Professions", "LeftButton")
        end
    end;

    -- Stack to the right of the rightmost open Blizzard UIPanel (Character /
    -- Skill / Spellbook / etc.). Falls back to a fixed left position when no
    -- panel is open. SetPoint on this frame is protected (implicit, via secure
    -- descendants), so skip in combat — _Refresh re-runs post-combat via
    -- PLAYER_REGEN_ENABLED.
    _Reposition = function(self)
        if InCombatLockdown() then return end
        local anchor = GetUIPanel("right") or GetUIPanel("center") or GetUIPanel("left")
        self:ClearAllPoints()
        if anchor then
            -- Anchor to the SLOT'S right edge, not the frame's right edge.
            -- UIPanel-registered frames (and addons setting UIPanelLayout-width
            -- like our TradeSkill overlay) can reserve more horizontal space
            -- than the underlying frame's actual width. GetUIPanelWidth reads
            -- UIPanelLayout-width if set, else the UIPanelWindows entry's
            -- width, else falls back to frame:GetWidth(). Anchoring at
            -- TOPLEFT + slotWidth avoids overlap when the slot is wider.
            local slotWidth = (GetUIPanelWidth and GetUIPanelWidth(anchor)) or anchor:GetWidth()
            self:SetPoint("TOPLEFT", anchor, "TOPLEFT", slotWidth + 10, 0)
        else
            self:AlignParentTopLeft(106, 10)
        end
    end;

    _Refresh = function(self)
        -- Skip entirely while in combat. Slot SetProfession path eventually
        -- runs SetAttribute on each spell slot's SecureButton, which is
        -- protected. PLAYER_REGEN_ENABLED re-fires _Refresh when combat ends.
        if InCombatLockdown() then return end

        self._mainSlot1:SetProfession(self:_BuildEntry(MUI_ModuleProfessions:GetFirstPrimaryProfession()))
        self._mainSlot2:SetProfession(self:_BuildEntry(MUI_ModuleProfessions:GetSecondPrimaryProfession()))
        self._secondarySlotCooking:SetProfession(self:_BuildEntry(MUI_ModuleProfessions:GetCooking()))
        self._secondarySlotFishing:SetProfession(self:_BuildEntry(MUI_ModuleProfessions:GetFishing()))
        self._secondarySlotFirstAid:SetProfession(self:_BuildEntry(MUI_ModuleProfessions:GetFirstAid()))

        self:_Reposition()
    end;

    -- Adapt a ModuleProfessions state table into the shape ProfessionSlot /
    -- ProfessionSlotSecondary expect. Slot wires spells[1] → bottom button,
    -- spells[2] → top button, so pack in (rank, other) order — the highest
    -- learned rank spell anchors the bottom slot, the auxiliary spell
    -- (Find Herbs, Smelting, Disenchant, Basic Campfire) goes on top.
    _BuildEntry = function(self, state)
        if not state then return nil end

        local spells = {}
        if state.knownSpells.rank then
            table.insert(spells, self._BuildSpellEntry(state.knownSpells.rank))
        end
        if state.knownSpells.other then
            table.insert(spells, self._BuildSpellEntry(state.knownSpells.other))
        end

        return {
            name       = state.name,
            title      = state.title,
            icon       = state.def.icon,
            rank       = state.rank,
            maxRank    = state.maxRank,
            skillIndex = state.skillIndex,
            spells     = spells,
        }
    end;

}
