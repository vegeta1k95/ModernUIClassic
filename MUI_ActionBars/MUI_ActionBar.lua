-- ActionBar: Container for a row/column of action button slots
-- Each slot: bg texture -> reparented action button -> border overlay
--
-- Usage:
--   local bar = ActionBar("horizontal", "IconFrameSlot")
--   bar:AddButton(ActionButton1)
--   bar:UpdateHotkeys()

local ATLAS = MUI_AtlasRegistry.ActionBar
local TEX = MUI.TEX_SKIN .. "actionbars\\"

-- Map button name prefix -> binding command prefix
local KEYBIND_PREFIX_MAP = {
    ["ActionButton"]              = "ACTIONBUTTON",
    ["BonusActionButton"]         = "ACTIONBUTTON",
    ["MultiBarBottomLeftButton"]  = "MULTIACTIONBAR1BUTTON",
    ["MultiBarBottomRightButton"] = "MULTIACTIONBAR2BUTTON",
    ["MultiBarRightButton"]       = "MULTIACTIONBAR3BUTTON",
    ["MultiBarLeftButton"]        = "MULTIACTIONBAR4BUTTON",
    ["StanceButton"]              = "SHAPESHIFTBUTTON",
    ["PetActionButton"]           = "BONUSACTIONBUTTON",
}

local function ShortenKey(key)
    if not key then return "" end
    key = string.gsub(key, "BUTTON", "M")
    key = string.gsub(key, "SHIFT%-", "S-")
    key = string.gsub(key, "CTRL%-", "C-")
    key = string.gsub(key, "ALT%-", "A-")
    key = string.gsub(key, "SPACE", "SP")
    key = string.gsub(key, "NUMPAD", "NP-")
    key = string.gsub(key, "MOUSEWHEELUP", "MWU")
    key = string.gsub(key, "MOUSEWHEELDOWN", "MWD")
    return key
end

-- Extract the prefix and index from a button name like "ActionButton7"
local function ParseButtonName(name)
    local _, _, prefix, idx = string.find(name, "^(.-)(%d+)$")
    return prefix, tonumber(idx)
end

class "ActionBar" : extends "Frame" {
    __init = function(self, orientation, slotBGRegion, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self.orientation = orientation or "horizontal"
        self.slotBGRegion = slotBGRegion or "IconFrameSlot"
        self.spacing = 6.3
        self.slotPad = 2.5

        self.showEmptySlots = Settings.GetValue("alwaysShowActionBars")

        self.slots = {}

        -- BG frame (behind buttons) and Border frame (above buttons).
        -- Buttons live under Blizzard's parents (MainMenuBarArtFrame, MultiBarBottomLeft, etc.)
        -- at MEDIUM strata, so we use LOW / HIGH strata to force layering across parent chains.
        self.bgFrame = Frame("Frame", self, (name or "ActionBar") .. "_BG")
        self.bgFrame:FillParent()
        self.bgFrame:SetFrameStrata("LOW")

        self.borderFrame = Frame("Frame", self, (name or "ActionBar") .. "_Border")
        self.borderFrame:FillParent()
        self.borderFrame:SetFrameStrata("HIGH")
    end;

    SetSpacing = function(self, spacing)
        self.spacing = spacing
    end;

    SetShowEmptySlots = function(self, show)
        self.showEmptySlots = show
        self:UpdateSlotVisibility()
    end;

    SetSlotPadding = function(self, pad)
        self.slotPad = pad
    end;

    AddButton = function(self, nativeButton)
        local idx = table.getn(self.slots) + 1
        local bw = nativeButton:GetWidth()
        local bh = nativeButton:GetHeight()

        -- Do NOT reparent: keeps the button's original secure parent chain intact so
        -- `actionpage` stays on a Blizzard-owned frame (not addon-modified), preventing
        -- self-cast / protected-action taint during combat.
        local btn = Button(nativeButton)
        btn:ClearAllPoints()
        btn:SetFrameLevel(self:GetFrameLevel())

        -- Position by SetPoint relative to our ActionBar (anchoring works cross-parent).
        if idx == 1 then
            if self.orientation == "horizontal" then
                btn:SetPoint("LEFT", self, "LEFT", 0, 0)
            else
                btn:SetPoint("TOP", self, "TOP", 0, 0)
            end
        else
            local prevBtn = self.slots[idx - 1].button
            if self.orientation == "horizontal" then
                btn:SetPoint("LEFT", prevBtn, "RIGHT", self.spacing, 0)
            else
                btn:SetPoint("TOP", prevBtn, "BOTTOM", 0, -self.spacing)
            end
        end
        btn:Show()

        -- Slot background
        local bg = Texture(self, nil, "BACKGROUND")
        bg:SetAtlas(ATLAS, self.slotBGRegion, true)
        bg:Fill(btn, -self.slotPad, -self.slotPad, -self.slotPad, -self.slotPad)
        bg:SetDrawLayer("BACKGROUND", -4)

        -- Slot border
        local border = Texture(self.borderFrame, nil, "ARTWORK")
        border:SetTextureRegion(TEX .. "actionbar-slot", 128, 128, 17, 16, 92, 95)
        border:Fill(btn, -0.5-self.slotPad, -0.5-self.slotPad, -self.slotPad, -1-self.slotPad)

        -- Autocast shine animation lives on the button (MEDIUM strata), so the
        -- HIGH-strata border frame hides it. Lift it above the border (border
        -- sits at self+10, see RaiseBorders).
        local shine = getglobal(btn:GetName() .. "Shine")
        if shine then
            local sh = Frame(shine)
            sh:SetFrameStrata("HIGH")
            sh:SetFrameLevel(self:GetFrameLevel() + 12)
        end

        -- Static autocastable indicator (green glow), a texture on the button
        -- under the border frame. ActionButtons toggle it via parentKey (no
        -- global name). Pet buttons inherit that parentKey copy too but
        -- Blizzard toggles a SEPARATE named-global copy — so prefer the named
        -- global, fall back to parentKey. Mirror it, synced via SyncAutocast.
        local acRaw = getglobal(btn:GetName() .. "AutoCastable") or nativeButton.AutoCastable
        local nativeAC = acRaw and Texture(acRaw)
        local autocast
        if nativeAC then
            autocast = Texture(self.borderFrame, nil, "OVERLAY")
            autocast:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
            autocast:SetSize(bw + 22, bh + 22)
            autocast:CenterAt(btn)
            autocast:Hide()
        end

        -- Hide vanilla hotkey text. It doubles as the native range indicator and gets
        -- Show()'d by ActionButton_UpdateRangeIndicator, so SetAlpha(0) keeps it invisible.
        local hotkey = getglobal(btn:GetName() .. "HotKey")
        if hotkey then
            local hk = FontString(hotkey)
            hk:Hide()
            hk:SetAlpha(0)
        end

        -- Custom keybind/range go on borderFrame (HIGH strata) so they render above the
        -- border texture, anchored to the button so they sit at its top-right corner.
        local fs = FontString(self.borderFrame, nil, "OVERLAY")
        fs:SetFont(MUI.FONT, 10, "OUTLINE")
        fs:SetTextColor(1, 1, 1)
		fs:SetJustifyH("RIGHT")
        fs:AlignTop(btn, 2)
		fs:AlignRight(btn, 0)

        -- Style macro name text
        local macroName = getglobal(btn:GetName() .. "Name")
        if macroName then
            local mn = FontString(macroName)
            mn:SetFont(MUI.FONT, 9, "OUTLINE")
            mn:SetTextColor(1, 1, 1)
        end

        -- Range indicator
        local range = FontString(self.borderFrame, nil, "OVERLAY")
        range:SetFont(MUI.FONT, 20, "OUTLINE")
        range:SetTextColor(1, 0.2, 0.2)
        range:SetText("•")
        range:AlignTop(btn, -4)
		range:AlignRight(btn, 0)
        range:Hide()

        -- Store slot
        self.slots[idx] = {
            button = btn,
            bg = bg,
            border = border,
			range = range,
			hotkey = fs,
            autocast = autocast,
            nativeAutoCast = nativeAC,
        }
        self._slotByName = self._slotByName or {}
        self._slotByName[btn:GetName()] = self.slots[idx]

        -- Update container size
        self:UpdateSize()

        return self.slots[idx]
    end;

    UpdateSize = function(self)
        local count = table.getn(self.slots)
        if count == 0 then return end

        local first = self.slots[1].button
        local bw = first:GetWidth()
        local bh = first:GetHeight()

        if self.orientation == "horizontal" then
            local totalW = count * bw + (count - 1) * self.spacing + 0
            self:SetSize(totalW, bh + 0)
        else
            local totalH = count * bh + (count - 1) * self.spacing + 0
            self:SetSize(bw + 0, totalH)
        end
    end;

    -- Re-apply our SetPoint anchors on every existing button. Needed
    -- because at UI-scale transitions (the global UI Scale slider), Era
    -- native code re-runs its own anchoring on multibar buttons and the
    -- new anchors stack with ours — causing visible clipping/overlap on
    -- the vertical bars (MULTIBAR3 / MULTIBAR4) where slot pitch is
    -- tighter. Wiping with ClearAllPoints + re-anchoring restores our
    -- single, intended anchor per button.
    Relayout = function(self)
        for i, slot in ipairs(self.slots) do
            local btn = slot.button
            if btn then
                btn:ClearAllPoints()
                if i == 1 then
                    if self.orientation == "horizontal" then
                        btn:SetPoint("LEFT", self, "LEFT", 0, 0)
                    else
                        btn:SetPoint("TOP", self, "TOP", 0, 0)
                    end
                else
                    local prev = self.slots[i - 1].button
                    if self.orientation == "horizontal" then
                        btn:SetPoint("LEFT", prev, "RIGHT", self.spacing, 0)
                    else
                        btn:SetPoint("TOP",  prev, "BOTTOM", 0, -self.spacing)
                    end
                end
            end
        end
        self:UpdateSize()
    end;

    -- Update hotkey text on all buttons in this bar
    UpdateHotkeys = function(self)
        for _, slot in ipairs(self.slots) do
            local btn = slot.button
            if btn then
                local name = btn:GetName()
                local prefix, idx = ParseButtonName(name)
                local cmd = prefix and KEYBIND_PREFIX_MAP[prefix]
                if cmd and idx then
                    local key = GetBindingKey(cmd .. idx)
                    slot.hotkey:SetText(ShortenKey(key))
                else
                    slot.hotkey:SetText("")
                end
            end
        end
    end;

    -- Show/hide empty slots based on showEmptySlots flag
    UpdateSlotVisibility = function(self)
		
        for i, slot in ipairs(self.slots) do

            local name = slot.button:GetName()
            local filled = false

            if string.find(name, "^StanceButton") then
                filled = (i <= (GetNumShapeshiftForms() or 0))
            elseif string.find(name, "^PetActionButton") then
                local petName = GetPetActionInfo(i)
                filled = (petName ~= nil and petName ~= "")
            else
                filled = HasAction(slot.button:GetActionID())
            end

			local isOn = self.showEmptySlots or filled

            -- Do NOT toggle slot.button — it's a secure button, and Hide/Show from
            -- addon code taints ActionButton_Update → blocks combat actions. Blizzard
            -- drives native visibility via StanceBar_Update / PetActionBar_Update /
            -- MultiActionBar_UpdateGridVisibility.
            if isOn then
                slot.hotkey:Show()
                slot.bg:Show()
                slot.border:Show()
            else
                slot.hotkey:Hide()
                slot.bg:Hide()
                slot.border:Hide()
            end

            self:_SyncSlotAutocast(slot)

        end
		
    end;

    -- Returns true if any slot is currently visible
    HasVisibleSlots = function(self)
        for _, slot in ipairs(self.slots) do
            if slot.button:IsShown() then return true end
        end
        return false
    end;

    -- Re-raise border frame (call after drag-and-drop if needed)
    RaiseBorders = function(self)
        self.borderFrame:SetFrameLevel(self:GetFrameLevel() + 10)
    end;

    -- Mirror the native autocastable overlay's visibility onto our copy.
    SyncAutocast = function(self, name)
        local slot = self._slotByName and self._slotByName[name]
        if slot then self:_SyncSlotAutocast(slot) end
    end;

    -- Sync every slot — for bar-wide updates (pet bar) where the hook doesn't
    -- name a single button.
    SyncAllAutocast = function(self)
        for _, slot in ipairs(self.slots) do
            self:_SyncSlotAutocast(slot)
        end
    end;

    _SyncSlotAutocast = function(self, slot)
        if slot.autocast and slot.nativeAutoCast then
            -- IsShown() is the texture's own flag; when the pet bar hides,
            -- Blizzard hides the PARENT without clearing it, so also require
            -- the button to be actually visible.
            if slot.nativeAutoCast:IsShown() and slot.border:IsVisible() then
                slot.autocast:Show()
            else
                slot.autocast:Hide()
            end
        end
    end;
}

class "ActionBarEditable" : extends {"ActionBar", "Editable"} {

    __init = function(self, orientation, slotBGRegion, parent, name)
        ActionBar.__init(self, orientation, slotBGRegion, parent, name)
        Editable.__init(self)
    end;

    -- The buttons keep their native parents (not children of this bar), so the
    -- frame's own SetScale never reaches them. Scale the bar (its bg/border/art)
    -- AND each button — both by the same factor — so the row scales uniformly.
    -- SetScale on secure buttons out of combat is safe (already done for the
    -- stance/pet bars at setup).
    EditModeApplyScale = function(self, scale)
        self:SetScale(scale)
        for _, slot in ipairs(self.slots) do
            if slot.button then slot.button:SetScale(scale) end
        end
    end;

}
