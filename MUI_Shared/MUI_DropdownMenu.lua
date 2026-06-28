-- DropdownMenu: generic popup menu with stacked rows. Each item declares
-- its type ("text" / "checkbox" / "submenu") and the menu builds the
-- matching row content. The menu owns the popup frame, the full-screen
-- click-catcher (so an outside-click dismisses), and the row layout.
-- Extracted from MUI_MinimapTrackerMenu's popup definition; that module
-- is still using its own version until the caller migrates.
--
-- Item schema:
--   { type = "text",     label = "...",  icon = <iconSpec>?,
--     OnClick = function(item, row, menu) ... end,
--     closeOnClick = true|false (default true) }
--
--   { type = "checkbox", label = "...",  icon = <iconSpec>?,
--     checked = bool,
--     OnChanged = function(item, checked) ... end,
--     closeOnClick = false (default — checkbox rows stay open) }
--
--   { type = "submenu",  label = "...",  icon = <iconSpec>?,
--     items = { ... } }   -- nested item list, opens on hover
--
--   { type = "separator" }    -- thin divider, no interaction
--
-- iconSpec:
--   { atlas = AtlasObj, region = "Name", size = 17? }
--   { texture = "Interface\\...", size = 17? }
--   { file = "Interface\\...", fileW = 1024?, fileH = 1024?,
--     x = ..., y = ..., w = ..., h = ..., size = 17? }
--
-- Hover/leave/click handlers also fire item.OnEnter/OnLeave/OnClick if
-- provided, so callers can layer extra behavior on top of the defaults.

class "DropdownMenu" : extends "Frame" {
    __init = function(self, parent, name, toggleAnchor, ninesliceScale)
        Frame.__init(self, "Frame", parent, name)
        self._toggleAnchor = toggleAnchor
        self._items        = {}
        self._rows         = {}
        self._submenus     = {}

        -- Tunable layout — override before SetItems for clean rebuild.
        self._width    = 200
        self._padL     = 13
        self._padT     = 11
        self._padR     = 18
        self._padB     = 17
        self._rowH     = 16
        self._rowGap   = 2

        -- Default anchor: drop straight down from the toggle anchor.
        -- Callers override via SetAnchor(func) for any other layout.
        self._anchorFunc = function(popup, anchor)
            if anchor then popup:Below(anchor, 0) end
        end

        self:_CreatePopup(ninesliceScale)
        self:_CreateCatcher()
    end;

    -- ----- configuration --------------------------------------------------

    SetMenuWidth = function(self, w)
        self._width = w
        self.popup:SetWidth(w)
    end;

    SetMenuPadding = function(self, l, t, r, b)
        self._padL, self._padT, self._padR, self._padB = l, t, r, b
    end;

    SetRowMetrics = function(self, h, gap)
        self._rowH, self._rowGap = h, gap
    end;

    -- Anchor function:
    --   func(popup, toggleAnchor) — called whenever the popup needs
    --   repositioning. The menu calls ClearAllPoints() before invoking
    --   it, so the caller just makes whatever SetPoint / Below / LeftOf
    --   / RightOf calls they need (one or many).
    SetAnchor = function(self, func)
        self._anchorFunc = func
        self:_PositionPopup()
    end;

    SetToggleAnchor = function(self, anchor)
        self._toggleAnchor = anchor
        self:_PositionPopup()
    end;

    -- ----- items ----------------------------------------------------------

    SetItems = function(self, items)
        self:_TearDownRows()
        self._items = items or {}
        self:_LayoutRows()
    end;

    -- Re-text a built row in place (no rebuild). 1-based index into the
    -- items last passed to SetItems.
    SetItemLabel = function(self, index, text)
        local item = self._items[index]
        if item and item._label then item._label:SetText(text) end
    end;

    -- Toggle a built row's clickability + greyed label in place.
    SetItemEnabled = function(self, index, enabled)
        local item = self._items[index]
        if not item then return end
        item.disabled = not enabled
        if item._label then
            local g = enabled and 1 or 0.5
            item._label:SetTextColor(g, g, g, 1)
        end
    end;

    -- ----- visibility -----------------------------------------------------

    Open    = function(self) self.popup:Show() end;
    Close   = function(self) self.popup:Hide() end;
    IsShown = function(self) return self.popup:IsShown() end;

    Toggle = function(self)
        if self.popup:IsShown() then
            self.popup:Hide()
        else
            self.popup:Show()
        end
        PlaySound(self.popup:IsShown()
                  and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                  or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end;

    -- ----- internals ------------------------------------------------------

    _CreatePopup = function(self, scale)
        self.popup = NineSlice()
        self.popup:SetSize(self._width, 90)
        self.popup:SetFrameStrata("FULLSCREEN_DIALOG")
        self.popup:SetFromAtlas(MUI_AtlasRegistry.Dropdown, "Bg", 34, 30, 64, 50, scale or 0.45)
        self.popup:EnableMouse(true)
        self.popup:Hide()
        self:_PositionPopup()
    end;

    _PositionPopup = function(self)
        if not self._anchorFunc then return end
        self.popup:ClearAllPoints()
        self._anchorFunc(self.popup, self._toggleAnchor)
    end;

    _CreateCatcher = function(self)
        -- Full-screen click-catcher. Sits at DIALOG strata one level below
        -- the popup, so popup clicks land on the popup first. Propagates
        -- mouse so right-click camera / underlying UI still works.
        self.catcher = Frame()
        self.catcher:SetParent(UIParent)
        self.catcher:SetAllPoints(UIParent)
        self.catcher:SetFrameStrata("DIALOG")
        self.catcher:SetFrameLevel(self.popup:GetFrameLevel() - 1)
        self.catcher:EnableMouse(true)
        -- SetPropagateMouse* are protected in combat. If this menu is first
        -- built mid-combat (e.g. opening the world map), defer the flags to
        -- combat end rather than taking a blocked-action error.
        if InCombatLockdown() then
            self._needsPropagate = true
            self.catcher:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
                if not self._needsPropagate then return end
                self._needsPropagate = false
                self.catcher:SetPropagateMouseClicks(true)
                self.catcher:SetPropagateMouseMotion(true)
            end)
        else
            self.catcher:SetPropagateMouseClicks(true)
            self.catcher:SetPropagateMouseMotion(true)
        end
        self.catcher:Hide()

        self.catcher:SetScript("OnMouseDown", function()
            -- Skip when click is on the toggle anchor (else double-toggle:
            -- catcher closes on mouse-down, the anchor reopens on mouse-up).
            if self._toggleAnchor and self._toggleAnchor:IsMouseOver() then return end
            -- Skip when click is on any open submenu's popup.
            for _, sub in pairs(self._submenus) do
                if sub and sub.popup and sub.popup:IsShown() and sub.popup:IsMouseOver() then
                    return
                end
            end
            self:Close()
        end)

        self.popup:SetScript("OnShow", function() self.catcher:Show() end)
        self.popup:SetScript("OnHide", function()
            self.catcher:Hide()
            for _, sub in pairs(self._submenus) do
                if sub then sub:Close() end
            end
        end)
    end;

    _TearDownRows = function(self)
        for _, row in ipairs(self._rows) do
            row:Hide()
            row:SetParent(nil)
        end
        for _, sub in pairs(self._submenus) do
            if sub then sub:Close() end
        end
        self._rows = {}
        self._submenus = {}
    end;

    _LayoutRows = function(self)
        local items = self._items
        local n = #items
        self.popup:SetWidth(self._width)
        self.popup:SetHeight(self._padT + n * self._rowH + math.max(n - 1, 0) * self._rowGap + self._padB)

        local rowW = self._width - self._padL - self._padR
        for i, item in ipairs(items) do
            self._rows[i] = self:_BuildRow(item, i, rowW)
        end
    end;

    _BuildRow = function(self, item, i, rowW)
        local row = Frame("Frame", self.popup)
        row:EnableMouse(true)
        row:SetSize(rowW, self._rowH)
        row:AlignParentTopLeft(self._padT + (i - 1) * (self._rowH + self._rowGap), self._padL)
        item._row = row

        if item.type == "separator" then
            self:_BuildSeparatorRow(row)
            return row
        end

        local hover = Texture(row, nil, "BACKGROUND")
        hover:SetAtlas(MUI_AtlasRegistry.Options, "ListActive")
        hover:FillParent()
        hover:Hide()

        row:SetScript("OnEnter", function()
            hover:Show()
            if item.OnEnter then item.OnEnter(item, row, self) end
        end)
        row:SetScript("OnLeave", function()
            hover:Hide()
            if item.OnLeave then item.OnLeave(item, row, self) end
        end)

        local kind = item.type or "text"
        if kind == "text" then
            self:_BuildTextRow(row, item)
        elseif kind == "checkbox" then
            self:_BuildCheckboxRow(row, item, rowW)
        elseif kind == "submenu" then
            self:_BuildSubmenuRow(row, item, i)
        end

        return row
    end;

    _BuildTextRow = function(self, row, item)
        local label = FontString(row, nil, "OVERLAY")
        label:SetText(item.label or "")
        label:SetFont(MUI.FONT, 10.5)
        label:AlignParentLeft(4, 0)
        item._label = label   -- kept for in-place SetItemLabel / SetItemEnabled

        if item.disabled then
            label:SetTextColor(0.5, 0.5, 0.5, 1)
        end

        if item.icon then self:_AttachIcon(row, item.icon) end

        row:SetScript("OnMouseUp", function()
            if item.disabled then return end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if item.OnClick then item.OnClick(item, row, self) end
            if item.closeOnClick ~= false then self:Close() end
        end)
    end;

    _BuildCheckboxRow = function(self, row, item, rowW)
        local cb = CheckBoxThin(row, nil, item.label or "")
        cb:SetSize(rowW, self._rowH)
        cb:SetBoxSize(11, 11)
        cb.label:SetFontSize(10.5)
        cb:AlignParentLeft(3, 0)
        cb:SetChecked(item.checked and true or false)

        if item.icon then self:_AttachIcon(row, item.icon) end

        cb.OnChanged = function(_, checked)
            PlaySound(checked
                and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            if item.OnChanged then item.OnChanged(item, checked) end
            if item.closeOnClick then self:Close() end
        end

        row._checkbox = cb
        item._checkbox = cb
    end;

    _BuildSubmenuRow = function(self, row, item, i)
        local label = FontString(row, nil, "OVERLAY")
        label:SetText(item.label or "")
        label:SetFont(MUI.FONT, 10.5)
        label:AlignParentLeft(4, 0)

        if item.icon then self:_AttachIcon(row, item.icon) end

        -- Right-pointing chevron tip ▶ to hint at the submenu.
        local hint = FontString(row, nil, "OVERLAY")
        hint:SetText("▶")
        hint:SetFont(MUI.FONT, 8)
        hint:SetTextColor(0.7, 0.7, 0.7, 1)
        hint:AlignParentRight(-2, 0)

        local sub = DropdownMenu(row, nil, row)
        sub:SetMenuWidth(item.submenuWidth or self._width)
        sub:SetAnchor(function(popup, anchor)
            popup:RightOf(anchor, 6)  -- open to the right of the parent row
        end)
        sub:SetItems(item.items or {})
        self._submenus[i] = sub
        item._submenu = sub

        row:SetScript("OnEnter", function()
            -- Close other open submenus so only this one is showing.
            for j, other in pairs(self._submenus) do
                if j ~= i and other then other:Close() end
            end
            sub:Open()
        end)
        -- Note: OnLeave does NOT auto-close — keeps submenu visible while
        -- the user moves into it. Closes via the click-catcher instead.
    end;

    _BuildSeparatorRow = function(self, row)
        local line = Texture(row, nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.15)
        line:SetHeight(1)
        line:AlignParentLeft(0, 0)
        line:AlignParentRight(0, 0)
    end;

    _AttachIcon = function(self, row, icon)
        local tex = Texture(row, nil, "OVERLAY")
        if icon.atlas and icon.region then
            tex:SetAtlas(icon.atlas, icon.region)
        elseif icon.texture then
            -- portrait=true → round-cropped + tight inner texcoord, the
            -- shape used for spell icons (corners trimmed).
            if icon.portrait then
                tex:SetPortrait(icon.texture)
                tex:SetTexCoord(0.04, 0.96, 0.04, 0.96)
            else
                tex:SetTexture(icon.texture)
            end
        elseif icon.file and icon.x then
            tex:SetTextureRegion(icon.file,
                                 icon.fileW or 1024, icon.fileH or 1024,
                                 icon.x, icon.y, icon.w, icon.h)
        end
        local size = icon.size or 17
        tex:SetSize(size, size)
        tex:AlignParentRight(-2, 1)
        return tex
    end;
}
