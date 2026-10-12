-- UnitFrameParty: the party frames as retail draws them, on Era's own.
--
-- Era's party frames stay in charge. PartyFrame, a layout frame and an Edit
-- Mode system, stacks four pooled secure buttons (PartyMemberFrameTemplate)
-- and shows / hides them itself, in combat too. Every time PartyFrame is
-- shown again the buttons are set up afresh and may be handed another party
-- slot, so nothing here remembers which unit a button stands for: that is
-- read off the button (its `unit`) whenever it matters.
--
-- Each button gets retail's look in retail's own numbers
-- (PartyFrameTemplates.xml) and is scaled as a whole to the size ModernUI
-- draws its other unit frames at. Blizzard's code keeps the portrait, the
-- name, the threat glow, the leader / loot master / PvP / offline icons, the
-- ready check, the debuff row and the pet button working; the bars, their
-- texts, the debuff glow and the row of the player's own buffs are ours.
--
-- Taint: Blizzard shows and hides the buttons in combat, so nothing is
-- written on them or on PartyFrame (no fields, no replaced methods, no
-- Layout() of ours). They are only hooked, and their protected geometry is
-- set once, at load.
--
--   UnitFrameParty(module)
--     :UpdateUnit(unit)    a unit's health or power changed
--     :UpdateAll()         every frame anew (the status text mode changed)
--     .frame               the edit-mode box (Reassert, reassertPending)

local TEX = MUI.TEX_SKIN .. "unitframes\\"

-- Retail's frame is 120x53, stacked 10 apart. A button is scaled to nine
-- tenths: what the player and target frames are of retail's.
local SCALE            = 0.9
local FRAME_W, FRAME_H = 120, 53
local SPACING          = 10

-- The row under a frame: Blizzard's party aura icon is 15 wide and set 2
-- apart. Up to this many of the player's buffs, then the member's debuffs.
local AURA_PITCH = 17
local MAX_BUFFS  = 8

-- The party frames' place, scale and settings in edit mode: a box the size
-- of four of them. PartyFrame's own size follows the buttons it shows (none,
-- outside a party), so it hangs from the box's top left and takes the box's
-- scale.
--   .showStatusText                 the "Status Text" setting
--   .OnShowStatusText(self, show)   it was set
class "PartyFrameEditable" : extends {"Frame", "Editable"} {
    __init = function(self)
        -- First: the settings panel applies the scale while it is built.
        self._party = Frame(PartyFrame)
        Frame.__init(self, "Frame", nil, "MUI_PartyFrame")
        Editable.__init(self)
        self:EditModeSetLabel("Party")
        self:EditModeSetupSettings(function(content)
            self:_AddStatusTextSetting(content)
        end)

        self:SetSize(FRAME_W * SCALE,
                     (MAX_PARTY_MEMBERS * FRAME_H + (MAX_PARTY_MEMBERS - 1) * SPACING) * SCALE)
        self:EditModeSetOption("party")
        self:EditModeSetDragAnchor("TOPLEFT")
        -- Where Blizzard's own layout has PartyFrame: beside the raid manager's tab.
        self:SetPoint("TOPLEFT", CompactRaidFrameManager, "TOPRIGHT", 0, 12)
        self:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", CompactRaidFrameManager, "TOPRIGHT", 0, 12)
        end)

        hooksecurefunc(PartyFrame, "UpdateSystem", function() self:Reassert() end)
        self:Reassert()
    end;

    EditModeApplyScale = function(self, scale)
        self:SetScale(scale)
        self:Reassert()
    end;

    -- Blizzard's Edit Mode puts PartyFrame back at its own place and scale
    -- whenever it applies a layout. PartyFrame holds secure buttons, so
    -- reclaiming it waits out combat.
    Reassert = function(self)
        if InCombatLockdown() then
            self.reassertPending = true
            return
        end
        self.reassertPending = false
        self._party:RawSetScale(self:GetScale())
        self._party:RawSetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    end;

    -- "Status Text": whether the bars carry their values, in the format of
    -- Blizzard's Status Text option. Off unless turned on (a bar still shows
    -- its value under the cursor); it rides with the layout.
    _AddStatusTextSetting = function(self, content)
        self.showStatusText = false

        self._chkStatusText = CheckBox(content, nil, STATUSTEXT_LABEL)
        self._chkStatusText.label:SetFontSize(12)
        self._chkStatusText:SetSize(200, 29)
        self._chkStatusText:SetBoxSize(24, 24)
        self._chkStatusText:AlignParentTopLeft(0, 0)
        self._chkStatusText.OnChanged = function(_, checked)
            self:SetShowStatusText(checked)
            self:EditModeNotifyChanged()
        end

        self:EditModeTrackSetting(
            function() return self.showStatusText end,
            function(v) self:SetShowStatusText(v) end,
            false)
    end;

    SetShowStatusText = function(self, show)
        self.showStatusText = show
        self._chkStatusText:SetChecked(show)
        if self.OnShowStatusText then self:OnShowStatusText(show) end
    end;

    -- Only the non-default (on) is stored, like scale.
    EditModeGetLayout = function(self)
        local data = Editable.EditModeGetLayout(self)
        if self.showStatusText then
            data = data or {}
            data.showStatusText = true
        end
        return data
    end;

    EditModeApplyLayout = function(self, data)
        Editable.EditModeApplyLayout(self, data)
        if data and data.showStatusText then
            self:SetShowStatusText(true)
        end
    end;

    EditModeCleanLayout = function(self, data)
        local clean = Editable.EditModeCleanLayout(self, data)
        if data.showStatusText == true then clean.showStatusText = true end
        return clean
    end;
}

-- ---------------------------------------------------------------------
-- UnitFramePartyPet: a member's pet button, retail's party frame at half
-- size with the health bar alone.
--   .frame    the button
-- ---------------------------------------------------------------------
class "UnitFramePartyPet" {
    __init = function(self, native, index)
        self._button = native

        self.frame = Frame(native)
        self.frame:SetSize(64, 23)
        -- The native hit rect (3, 33, 3, 3) is the portrait of Era's art.
        self.frame:SetHitRectInsets(0, 0, 0, 0)

        local nativeBar = Frame(native.HealthBar)
        nativeBar:SetAlpha(0)
        nativeBar:EnableMouse(false)
        Texture(native.Texture):SetTexture("")

        local art = Texture(self.frame, nil, "ARTWORK")
        art:SetTextureRegion(TEX .. "party-frame", 128, 64, 0, 0, 120, 49)
        art:SetSize(60, 24.5)
        art:AlignParentTopLeft(1, 0)

        -- The threat glow: Blizzard shows, hides and colours it.
        local flash = Texture(native.Flash)
        flash:SetTextureRegion(TEX .. "party-frame-combat", 128, 64, 0, 0, 114, 47)
        flash:SetSize(57, 23.5)
        flash:SetDrawLayer("ARTWORK", 1)
        flash:ClearAllPoints()
        flash:AlignParentTopLeft(1, 0)

        self.health = AnimatedBar(self.frame, "MUI_Party" .. index .. "PetHealth", 35.5, 5)
        self.health:AlignParentTopLeft(9, 21.5)
        self.health:SetFillTextureRegion(TEX .. "party-health", 128, 16, 0, 0, 70, 10)
        self.health:SetFillColor(0.5, 1.0, 0.13, 1)
        self.health:SetCutoutColor(1, 0, 0, 1)
    end;

    Update = function(self, instant)
        local unit = self._button.unit
        if not UnitExists(unit) then return end
        self.health:SetMaxValue(math.max(UnitHealthMax(unit), 1))
        self.health:SetBarValue(UnitHealth(unit), instant)
    end;

    UpdateUnit = function(self, unit)
        if unit == self._button.unit then self:Update() end
    end;
}

-- ---------------------------------------------------------------------
-- UnitFramePartyMember: one of PartyFrame's four buttons.
-- ---------------------------------------------------------------------
class "UnitFramePartyMember" {
    __init = function(self, module, native, index)
        self.module     = module
        self._button    = native
        self._showText  = false
        self._buffIcons = {}
        self._buffCount = 0

        local frame = Frame(native)
        frame:SetScale(SCALE)
        frame:SetSize(FRAME_W, FRAME_H)
        -- The native hit rect (7, 85, 6, 7) is the portrait; retail's frame takes the mouse all over.
        frame:SetHitRectInsets(0, 0, 0, 0)

        -- Era's bars keep running unseen: the portrait's dead / ghost / low
        -- health tints come off the health bar's value.
        for _, bar in ipairs({ native.HealthBar, native.ManaBar }) do
            local nativeBar = Frame(bar)
            nativeBar:SetAlpha(0)
            nativeBar:EnableMouse(false)
        end
        Texture(native.Background):Hide()

        local overlay = native.PartyMemberOverlay
        self._overlay = Frame(overlay)
        -- Blanked, not hidden: ToPlayerArt shows the frame art again on every roster update.
        Texture(overlay.Texture):SetTexture("")
        -- Era's own debuff ring flickers on for a frame at a time.
        Texture(overlay.Status):SetAlpha(0)

        local art = Texture(frame, nil, "ARTWORK")
        art:SetTextureRegion(TEX .. "party-frame", 128, 64, 0, 0, 120, 49)
        art:SetSize(120, 49)
        art:AlignParentTopLeft(2, 1)

        -- The threat glow: Blizzard shows, hides and colours it.
        local flash = Texture(native.Flash)
        flash:SetTextureRegion(TEX .. "party-frame-combat", 128, 64, 0, 0, 114, 47)
        flash:SetSize(114, 47)
        flash:SetDrawLayer("ARTWORK", 1)
        flash:ClearAllPoints()
        flash:AlignParentTopLeft(2, 1)

        -- Retail's name is 57 wide, short of its role icon; Era has none.
        local name = FontString(overlay.Name)
        name:SetFont(MUI.FONT, 10)
        name:SetTextColor(1, 0.82, 0)
        name:SetJustifyH("LEFT")
        name:SetSize(68, 12)
        name:ClearAllPoints()
        name:AlignParentTopLeft(6, 46)

        self.health = AnimatedBar(frame, "MUI_Party" .. index .. "Health", 70, 10)
        self.health:AlignParentTopLeft(19, 45)
        self.health:SetFillTextureRegion(TEX .. "party-health", 128, 16, 0, 0, 70, 10)
        self.health:SetCutoutColor(1, 0, 0, 1)
        self._healthText = self:_CreateBarText(self.health)

        self.mana = AnimatedBar(frame, "MUI_Party" .. index .. "Mana", 74, 7)
        self.mana:AlignParentTopLeft(30, 41)
        self.mana:SetFillTextureRegion(TEX .. "party-resource", 128, 8, 0, 0, 74, 7)
        self._manaText = self:_CreateBarText(self.mana)

        -- Retail's debuff glow, over the bars like the icons.
        self._status = Texture(self._overlay, nil, "ARTWORK")
        self._status:SetTextureRegion(TEX .. "party-frame-status", 128, 64, 0, 0, 120, 49)
        self._status:SetSize(120, 49)
        self._status:AlignParentTopLeft(2, 1)
        self._status:Hide()

        -- The crown and the loot master's bag as on the player frame; the
        -- PvP badge at the portrait's lower left, where retail has it.
        self._leader = Texture(overlay.LeaderIcon)
        self._leader:SetTexture(TEX .. "flag-leader")
        self._leader:SetSize(16)
        local master = Texture(overlay.MasterIcon)
        master:SetSize(13)
        master:ClearAllPoints()
        master:RightOf(self._leader, 1)
        self._pvp = Texture(overlay.PVPIcon)
        self._pvp:SetSize(38)

        local notPresent = Frame(native.NotPresentIcon)
        notPresent:ClearAllPoints()
        notPresent:RightOf(frame, 2, -2)

        self._debuffs = Frame(native.AuraFrameContainer)
        -- The buff icons' parent, the size of the button: icons are made as
        -- buffs come, in combat too, and so not on the secure button itself.
        self._buffRow = Frame("Frame", frame)
        self._buffRow:FillParent()
        self.pet = UnitFramePartyPet(native.PetFrame, index)

        -- ToPlayerArt closes every refresh of a button: a roster update, a
        -- member going on or off line, a new set-up.
        hooksecurefunc(native, "ToPlayerArt", function()
            self:_Place()
            self:Update(true)
        end)
        hooksecurefunc(native, "UpdateAuras", function()
            self:UpdateStatus()
            self:UpdateBuffs()
        end)
        hooksecurefunc(native, "UpdatePet", function()
            self:_Place()
            self.pet:Update(true)
        end)

        self:Update(true)
        self:UpdateStatus()
        self:UpdateBuffs()
        self.pet:Update(true)
    end;

    -- A bar's value: shown by the "Status Text" setting, and while the cursor
    -- is on the bar. Its frame takes the hover only (clicks go on to the
    -- button) and passes it on too: the button's tooltip, and its unit for
    -- mouseover casts.
    _CreateBarText = function(self, bar)
        local frame = Frame("Frame", bar)
        frame:FillParent()
        frame:EnableMouseMotion(true)
        frame:SetPropagateMouseMotion(true)

        local text = { hovered = false }
        text.value = FontString(frame, nil, "OVERLAY")
        text.value:SetFont(MUI.FONT, 8, "OUTLINE")
        text.value:SetTextColor(1, 1, 1)
        text.value:CenterInParent()

        frame:SetScript("OnEnter", function()
            text.hovered = true
            self:Update()
        end)
        frame:SetScript("OnLeave", function()
            text.hovered = false
            self:Update()
        end)
        return text
    end;

    -- What does not stay where it was put. ToPlayerArt takes the crown and
    -- the PvP badge back to their classic places. The row under the frame is
    -- the player's buffs, then the debuffs; it starts where retail has its
    -- debuffs, or right of the pet button, which retail lets them overlap.
    _Place = function(self)
        self._leader:ClearAllPoints()
        self._leader:Above(self._overlay, -6, -10)
        self._pvp:ClearAllPoints()
        self._pvp:AlignParentTopLeft(24, -4)

        local left = self.pet.frame:IsShown() and 86 or 48
        for i, icon in ipairs(self._buffIcons) do
            icon:ClearAllPoints()
            icon:AlignParentTopLeft(43, left + (i - 1) * AURA_PITCH)
        end
        if self._buffCount > 0 then
            left = left + self._buffCount * AURA_PITCH + 3
        end
        self._debuffs:ClearAllPoints()
        self._debuffs:AlignParentTopLeft(43, left)
    end;

    SetShowStatusText = function(self, show)
        self._showText = show
        self:Update()
    end;

    -- Both bars and their texts, for the unit the button shows now. A member
    -- who is off line has full grey bars, as Era draws him.
    Update = function(self, instant)
        local unit = self._button.unit
        if not UnitExists(unit) then return end

        local connected = UnitIsConnected(unit)
        local dead      = connected and UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit)
        local showText  = self._showText and GetCVar("statusTextDisplay") ~= "NONE"

        local maxHealth = math.max(UnitHealthMax(unit), 1)
        local health    = connected and UnitHealth(unit) or maxHealth
        self.health:SetMaxValue(maxHealth)
        self.health:SetBarValue(health, instant)
        self.health:SetPrediction(connected and self.module:GetIncomingHeals(unit) or 0)
        if connected then
            self.health:SetFillColor(0.5, 1.0, 0.13, 1)
        else
            self.health:SetFillColor(0.5, 0.5, 0.5, 1)
        end

        local healthText = self._healthText
        if dead then
            healthText.value:SetText(DEAD)
        elseif connected then
            healthText.value:SetText(self.module:FormatValue(health, maxHealth, unit, true))
        else
            healthText.value:SetText("")
        end
        healthText.value:SetVisible(dead or showText or healthText.hovered)

        local maxPower = UnitPowerMax(unit)
        local power    = connected and UnitPower(unit) or maxPower
        local manaText = self._manaText
        self.mana:SetVisible(maxPower > 0)
        if maxPower > 0 then
            self.mana:SetMaxValue(maxPower)
            self.mana:SetBarValue(power, instant)
            if connected then
                self.mana:SetFillColor(self.module:GetPowerColor(unit))
                manaText.value:SetText(self.module:FormatValue(power, maxPower, unit))
            else
                self.mana:SetFillColor(0.5, 0.5, 0.5, 1)
                manaText.value:SetText("")
            end
        end
        manaText.value:SetVisible(showText or manaText.hovered)
    end;

    -- The frame's outline in the colour of the member's first debuff, of
    -- those Blizzard's aura pass kept for the frame (all of them, or with
    -- "Show Dispellable Debuffs" only what the player can take off). The
    -- button has no list before it first showed a member.
    UpdateStatus = function(self)
        local debuffs = self._button.debuffs
        local debuff  = debuffs and debuffs:GetTop()
        if debuff then
            local info = AuraUtil.GetDebuffDisplayInfoTable()
            self._status:SetVertexColor((info[debuff.dispelName] or info["None"]).color:GetRGB())
        end
        self._status:SetVisible(debuff)
    end;

    -- Every buff the player cast on the member, in the icons of the tooltip
    -- that comes up over the frame. Not that tooltip's list (button.buffs):
    -- it leaves out what the spell data keeps off group frames, Mark of the
    -- Wild and the other long buffs among it.
    UpdateBuffs = function(self)
        local unit, count = self._button.unit, 0
        while count < MAX_BUFFS do
            local aura = C_UnitAuras.GetBuffDataByIndex(unit, count + 1, "HELPFUL|PLAYER")
            if not aura then break end
            count = count + 1
            self:_BuffIcon(count):SetupPartyAura(unit, aura, true)
        end
        for i = count + 1, #self._buffIcons do
            self._buffIcons[i]:Hide()
        end
        self._buffCount = count
        self:_Place()
    end;

    _BuffIcon = function(self, index)
        local icon = self._buffIcons[index]
        if not icon then
            icon = Frame("Frame", self._buffRow, nil, "PartyAuraFrameTemplate")
            self._buffIcons[index] = icon
        end
        return icon
    end;

    UpdateUnit = function(self, unit)
        if unit == self._button.unit then self:Update() end
        self.pet:UpdateUnit(unit)
    end;
}

class "UnitFrameParty" {
    __init = function(self, module)
        self.frame   = PartyFrameEditable()
        self.members = {}
        for native in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            local index = #self.members + 1
            self.members[index] = UnitFramePartyMember(module, native, index)
        end
        self.frame.OnShowStatusText = function(_, show)
            for _, member in ipairs(self.members) do
                member:SetShowStatusText(show)
            end
        end
    end;

    UpdateUnit = function(self, unit)
        for _, member in ipairs(self.members) do
            member:UpdateUnit(unit)
        end
    end;

    UpdateAll = function(self)
        for _, member in ipairs(self.members) do
            member:Update(true)
        end
    end;
}
