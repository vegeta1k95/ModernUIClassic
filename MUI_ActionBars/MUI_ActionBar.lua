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
    ["MultiBar5Button"]           = "MULTIACTIONBAR5BUTTON",
    ["MultiBar6Button"]           = "MULTIACTIONBAR6BUTTON",
    ["MultiBar7Button"]           = "MULTIACTIONBAR7BUTTON",
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

-- The range of retail's Icon Padding setting. Its lowest value stands for
-- the bar's own spacing.
local MIN_ICON_PADDING, MAX_ICON_PADDING = 2, 10

class "ActionBar" : extends "Frame" {

    MIN_ICON_PADDING = MIN_ICON_PADDING,

    __init = function(self, orientation, slotBGRegion, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self.orientation = orientation or "horizontal"
        self.slotBGRegion = slotBGRegion or "IconFrameSlot"
        self.spacing = 6.3
        self.slotPad = 2.5

        -- The grid, in the terms of retail's Edit Mode: lines across the
        -- orientation (rows, or the columns of a vertical bar), how many
        -- buttons take part (nil = all of them) and the icon padding.
        self.numRows = 1
        self.numIcons = nil
        self.iconPadding = MIN_ICON_PADDING

        self.showEmptySlots = false
        self.alwaysShowButtons = false

        self.slots = {}

        -- BG frame (behind buttons) and Border frame (above buttons).
        -- Buttons live under Blizzard's parents (MainActionBar, MultiBarBottomLeft, etc.)
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

    -- The user's "Always Show Buttons" choice; showEmptySlots is the transient
    -- state (cursor drag) layered on top of it.
    SetAlwaysShowButtons = function(self, show)
        self.alwaysShowButtons = show
        self:UpdateSlotVisibility()
    end;

    SetSlotPadding = function(self, pad)
        self.slotPad = pad
    end;

    -- ---- layout --------------------------------------------------------
    -- Each of these lays the buttons out again (see Relayout).

    SetOrientation = function(self, orientation)
        if self.orientation == orientation then return end
        self.orientation = orientation
        self:Relayout()
    end;

    SetNumRows = function(self, rows)
        if self.numRows == rows then return end
        self.numRows = rows
        self:Relayout()
    end;

    SetNumIcons = function(self, icons)
        if self.numIcons == icons then return end
        self.numIcons = icons
        self:Relayout()
    end;

    SetIconPadding = function(self, padding)
        if self.iconPadding == padding then return end
        self.iconPadding = padding
        self:Relayout()
    end;

    -- How many buttons the layout holds; the others are kept off screen.
    GetLaidOutCount = function(self)
        local count = table.getn(self.slots)
        return math.min(self.numIcons or count, count)
    end;

    AddButton = function(self, nativeButton)
        local idx = table.getn(self.slots) + 1
        local bw = nativeButton:GetWidth()
        local bh = nativeButton:GetHeight()

        -- Do NOT reparent: keeps the button's original secure parent chain intact so
        -- `actionpage` stays on a Blizzard-owned frame (not addon-modified), preventing
        -- self-cast / protected-action taint during combat.
        -- Placed by _Layout below, by SetPoint relative to our ActionBar
        -- (anchoring works cross-parent).
        local btn = Button(nativeButton)
        btn:ClearAllPoints()
        btn:SetFrameLevel(self:GetFrameLevel())
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

        -- Autocast shine animation lives on the button's AutoCastOverlay child
        -- (MEDIUM strata), so the HIGH-strata border frame hides it. Lift it
        -- above the border (border sits at self+10, see RaiseBorders).
        local nativeAC = Frame(nativeButton.AutoCastOverlay)
        nativeAC:SetFrameStrata("HIGH")
        nativeAC:SetFrameLevel(self:GetFrameLevel() + 12)

        -- Static autocastable indicator (green glow): the overlay's Corners
        -- texture. Blizzard shows the whole overlay while autocast is allowed;
        -- replace Corners with our own copy, synced via SyncAutocast.
        Texture(nativeButton.AutoCastOverlay.Corners):SetAlpha(0)
        local autocast = Texture(self.borderFrame, nil, "OVERLAY")
        autocast:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
        autocast:SetSize(bw + 22, bh + 22)
        autocast:CenterAt(btn)
        autocast:Hide()

        -- Hide vanilla hotkey text. It doubles as the native range indicator and gets
        -- Show()'d by ActionButton_UpdateRangeIndicator, so SetAlpha(0) keeps it invisible.
        local hk = FontString(nativeButton.HotKey)
        hk:Hide()
        hk:SetAlpha(0)

        -- Custom keybind/range go on borderFrame (HIGH strata) so they render above the
        -- border texture, anchored to the button so they sit at its top-right corner.
        local fs = FontString(self.borderFrame, nil, "OVERLAY")
        fs:SetFont(MUI.FONT, 10, "OUTLINE")
        fs:SetTextColor(1, 1, 1)
		fs:SetJustifyH("RIGHT")
        fs:AlignTop(btn, 2)
		fs:AlignRight(btn, 0)

        -- Style macro name text
        local mn = FontString(nativeButton.Name)
        mn:SetFont(MUI.FONT, 9, "OUTLINE")
        mn:SetTextColor(1, 1, 1)

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

        self:_Layout()

        return self.slots[idx]
    end;

    -- Lay the buttons out again. Moving them, and sizing the frame they are
    -- anchored to, is protected in combat: asked for then, it is done when
    -- combat ends (ApplyPendingLayout).
    --
    -- This is also what undoes Era's own anchoring: at UI-scale transitions
    -- (the global UI Scale slider) native code re-runs it on the multibar
    -- buttons and the new anchors stack with ours, clipping the vertical bars.
    Relayout = function(self)
        if InCombatLockdown() then
            self._layoutPending = true
            return
        end
        self._layoutPending = false
        self:_Layout()
        self:UpdateSlotVisibility()
    end;

    ApplyPendingLayout = function(self)
        if self._layoutPending then self:Relayout() end
    end;

    -- The grid, as Blizzard's ActionBarMixin:UpdateGridLayout builds it: the
    -- buttons fill lines of `stride`, as few lines as numRows allows. A
    -- horizontal bar fills rows left to right and stacks them upward, a
    -- vertical bar fills columns top to bottom and adds them to the right.
    -- Each button is anchored to the bar by the edge its line starts from and
    -- the lines are centred across the bar, which for a single line is the
    -- row or column this bar always was. Buttons past the count are parked
    -- off screen: they are secure, so they cannot be hidden from here.
    _Layout = function(self)
        local count = self:GetLaidOutCount()
        if count == 0 then return end

        local first = self.slots[1].button
        local bw, bh = first:GetWidth(), first:GetHeight()
        local gap = self.spacing + self.iconPadding - MIN_ICON_PADDING
        local stride = math.ceil(count / self.numRows)
        local lines = math.ceil(count / stride)
        local middle = (lines - 1) / 2
        local horizontal = self.orientation == "horizontal"

        for i, slot in ipairs(self.slots) do
            local btn = slot.button
            local along, across = (i - 1) % stride, math.floor((i - 1) / stride)
            btn:ClearAllPoints()
            if i > count then
                btn:SetPoint("TOPRIGHT", MUI_Root, "BOTTOMLEFT", -500, -500)
            elseif horizontal then
                btn:SetPoint("LEFT", self, "LEFT", along * (bw + gap), (across - middle) * (bh + gap))
            else
                btn:SetPoint("TOP", self, "TOP", (across - middle) * (bw + gap), -along * (bh + gap))
            end
        end

        if horizontal then
            self:SetSize(stride * bw + (stride - 1) * gap, lines * bh + (lines - 1) * gap)
        else
            self:SetSize(lines * bw + (lines - 1) * gap, stride * bh + (stride - 1) * gap)
        end

        if self.OnLayoutChanged then self:OnLayoutChanged() end
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
        local count = self:GetLaidOutCount()

        for i, slot in ipairs(self.slots) do

            local name = slot.button:GetName()
            local filled = false

            if string.find(name, "^StanceButton") then
                filled = (i <= (GetNumShapeshiftForms() or 0))
            elseif string.find(name, "^PetActionButton") then
                local petName = GetPetActionInfo(i)
                filled = (petName ~= nil and petName ~= "")
            else
                filled = C_ActionBar.HasAction(slot.button:GetActionID())
            end

            local isOn = i <= count and (self.showEmptySlots or self.alwaysShowButtons or filled)

            -- Do NOT toggle slot.button — it's a secure button, and Hide/Show from
            -- addon code taints its Update → blocks combat actions. Blizzard drives
            -- native visibility via ActionBarMixin:UpdateShownButtons.
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
            -- IsShown() is the overlay's own flag; when the pet bar hides,
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
        self._defaultOrientation = self.orientation
    end;

    -- The overlay's label reads along the bar's long side.
    _Layout = function(self)
        ActionBar._Layout(self)
        self._editLabel:SetRotation(self:GetHeight() > self:GetWidth() and math.pi / 2 or 0)
    end;

    -- The layout setters also keep the settings panel showing what they set:
    -- a saved layout is applied after the panel is built.
    SetOrientation = function(self, orientation)
        ActionBar.SetOrientation(self, orientation)
        if self._rowOrientation then
            self._rowOrientation:SetValue(orientation)
            self._rowRows:SetLabel(self:_RowsLabel())
        end
    end;

    SetNumRows = function(self, rows)
        ActionBar.SetNumRows(self, rows)
        if self._rowRows then self._rowRows:SetValue(rows) end
    end;

    SetNumIcons = function(self, icons)
        ActionBar.SetNumIcons(self, icons)
        if self._rowIcons then self._rowIcons:SetValue(self:GetLaidOutCount()) end
    end;

    SetIconPadding = function(self, padding)
        ActionBar.SetIconPadding(self, padding)
        if self._rowPadding then self._rowPadding:SetValue(padding) end
    end;

    -- Retail names the lines setting after the orientation.
    _RowsLabel = function(self)
        return self.orientation == "vertical" and HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_COLUMNS
            or HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS
    end;

    -- Settings controls stack down the panel in the order they are added.
    _EditModePlaceSetting = function(self, control)
        if self._settingsTail then
            control:Below(self._settingsTail, 8)
        else
            control:AlignParentTop(0)
        end
        self._settingsTail = control
    end;

    -- Adds retail's layout settings to this bar's edit-mode settings panel:
    -- orientation, rows (columns, when vertical), icon padding and, with
    -- `withIcons`, the number of icons. Icon size is the panel's Scale.
    EditModeAddLayoutSettings = function(self, content, withIcons)
        self._rowOrientation = EditModeDropdownRow(content, HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION, {
            { value = "horizontal", text = HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_HORIZONTAL },
            { value = "vertical",   text = HUD_EDIT_MODE_SETTING_ACTION_BAR_ORIENTATION_VERTICAL },
        })
        self._rowOrientation:SetValue(self.orientation)
        self._rowOrientation.OnChanged = function(_, value)
            self:SetOrientation(value)
            self:EditModeNotifyChanged()
        end
        self:_EditModePlaceSetting(self._rowOrientation)
        self:EditModeTrackSetting(
            function() return self.orientation end,
            function(v) self:SetOrientation(v) end)

        self._rowRows = EditModeSliderRow(content, self:_RowsLabel(), 1, 4)
        self._rowRows:SetValue(self.numRows)
        self._rowRows.OnChanged = function(_, value)
            self:SetNumRows(value)
            self:EditModeNotifyChanged()
        end
        self:_EditModePlaceSetting(self._rowRows)
        self:EditModeTrackSetting(
            function() return self.numRows end,
            function(v) self:SetNumRows(v) end)

        if withIcons then
            self._rowIcons = EditModeSliderRow(content, HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ICONS, 6, table.getn(self.slots))
            self._rowIcons:SetValue(self:GetLaidOutCount())
            self._rowIcons.OnChanged = function(_, value)
                self:SetNumIcons(value)
                self:EditModeNotifyChanged()
            end
            self:_EditModePlaceSetting(self._rowIcons)
            self:EditModeTrackSetting(
                function() return self:GetLaidOutCount() end,
                function(v) self:SetNumIcons(v) end)
        end

        self._rowPadding = EditModeSliderRow(content, HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_PADDING, MIN_ICON_PADDING, MAX_ICON_PADDING)
        self._rowPadding:SetValue(self.iconPadding)
        self._rowPadding.OnChanged = function(_, value)
            self:SetIconPadding(value)
            self:EditModeNotifyChanged()
        end
        self:_EditModePlaceSetting(self._rowPadding)
        self:EditModeTrackSetting(
            function() return self.iconPadding end,
            function(v) self:SetIconPadding(v) end)
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

    SetAlwaysShowButtons = function(self, show)
        ActionBar.SetAlwaysShowButtons(self, show)
        if self._chkAlwaysShow then self._chkAlwaysShow:SetChecked(show) end
    end;

    -- Adds the "Always Show Buttons" checkbox to this bar's edit-mode settings
    -- panel. 1.15.9 dropped the global "Always Show Action Bars" option for a
    -- per-bar Blizzard Edit Mode setting we can't write (secure showgrid), so
    -- this one drives our own slot art. On by default, as in retail.
    EditModeAddAlwaysShowButtons = function(self, content)
        self._chkAlwaysShow = CheckBox(content, nil, HUD_EDIT_MODE_SETTING_ACTION_BAR_ALWAYS_SHOW_BUTTONS)
        self._chkAlwaysShow.label:SetFontSize(12)
        self._chkAlwaysShow:SetSize(200, 29)
        self._chkAlwaysShow:SetBoxSize(24, 24)
        self._chkAlwaysShow:AlignParentLeft(0)
        self:_EditModePlaceSetting(self._chkAlwaysShow)
        self._chkAlwaysShow.OnChanged = function(_, checked)
            self:SetAlwaysShowButtons(checked)
            self:EditModeNotifyChanged()
        end

        self:SetAlwaysShowButtons(true)
        self:EditModeTrackSetting(
            function() return self.alwaysShowButtons end,
            function(v) self:SetAlwaysShowButtons(v) end)
    end;

    -- The settings ride along with the saved layout. Only what differs from
    -- the default is stored, like scale.
    EditModeGetLayout = function(self)
        local data = Editable.EditModeGetLayout(self)
        local function keep(key, value)
            data = data or {}
            data[key] = value
        end
        if self._chkAlwaysShow and not self.alwaysShowButtons then
            keep("alwaysShowButtons", false)
        end
        if self._rowOrientation then
            if self.orientation ~= self._defaultOrientation then keep("orientation", self.orientation) end
            if self.numRows ~= 1 then keep("numRows", self.numRows) end
            if self.iconPadding ~= MIN_ICON_PADDING then keep("iconPadding", self.iconPadding) end
        end
        if self._rowIcons and self:GetLaidOutCount() ~= table.getn(self.slots) then
            keep("numIcons", self.numIcons)
        end
        return data
    end;

    EditModeApplyLayout = function(self, data)
        Editable.EditModeApplyLayout(self, data)
        if not data then return end
        if data.alwaysShowButtons == false then self:SetAlwaysShowButtons(false) end
        if data.orientation then self:SetOrientation(data.orientation) end
        if data.numRows then self:SetNumRows(data.numRows) end
        if data.numIcons then self:SetNumIcons(data.numIcons) end
        if data.iconPadding then self:SetIconPadding(data.iconPadding) end
    end;

}
