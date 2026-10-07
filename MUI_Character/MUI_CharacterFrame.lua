-- MUI_CharacterFrame: the character window — retail's CharacterFrame (338x424,
-- 540 wide with the paper doll's side pane; drawn at nine tenths like the
-- other portrait windows) on Era's character frame.
--
-- Era's CharacterFrame stays the real panel: the C key, the micro button and
-- Escape open and close it through the panel manager, in combat too, and its
-- five sub-frames (character, pet, reputation, skills, honor) still switch
-- under ToggleCharacter. This window is its child and covers it. Era's tab
-- buttons and close button stay the things that are clicked, wearing our art:
-- a tab of our own would have to call ToggleCharacter itself, and from addon
-- code that can neither open nor close a panel in combat. The sub-frames are
-- parked off screen; each has a pane here that shows with it.
--
--   CharacterWindow()
--     .canvas          retail's frame rect, at retail's scale: everything on
--                      it is laid out in retail's own numbers
--     .inset           the recessed area on the left (the whole body on a
--                      narrow pane)
--     .insetRight      the paper doll's side pane
--     .panes[name]     by Era sub-frame name
--
--   CharacterPane      a tab's content, a child of the inset
--     .wide            540 wide with the side pane, or 400
--     :GetTitle()      text, r, g, b for the title bar
--     :GetPortrait()   unit, or unit and an icon to show instead

local S = 0.9
-- The panel manager puts Era's frame 16 px left of and 12 px above where a
-- window's art begins: its classic art has that much empty margin.
local NATIVE_DX, NATIVE_DY = 16, 12
local FRAME_H = 424
local WIDTH_WIDE, WIDTH_NARROW = 540, 400
local INSET_W = 328               -- the paper doll's inset, whatever the frame's width
-- Neighbouring tabs share the soft edges of their art, as retail's do (its
-- tab pieces overhang the button by 3 and 7 with the buttons 1 apart).
local TAB_LEFT, TAB_OVERLAP = 12, 9

-- Era's sub-frames, and the tab each belongs to.
local SUBFRAMES = {
    PaperDollFrame    = 1,
    PetPaperDollFrame = 2,
    ReputationFrame   = 3,
    SkillFrame        = 4,
    HonorFrame        = 5,
}

local TAB_ATLAS = MUI_AtlasRegistry.TabBottom

-- A window as wide as retail's frame of `width`: its body (the frame less the
-- border art, 2 px at each side) at nine tenths, inside this window's border.
local function WindowWidth(width)
    return (width - 4) * S + 6
end
local WINDOW_H = (FRAME_H - 23) * S + 21

-- ---------------------------------------------------------------------
-- CharacterPane: what a tab shows.
-- ---------------------------------------------------------------------
class "CharacterPane" : extends "Frame" {

    wide = false,

    __init = function(self, window)
        Frame.__init(self, "Frame", window.inset)
        self:FillParent()
        self:Hide()
        self.window = window
    end;

    GetTitle = function(self)
        return UnitPVPName("player") or UnitName("player"), 1, 1, 1
    end;

    GetPortrait = function(self)
        return "player"
    end;
}

-- ---------------------------------------------------------------------
-- CharacterScrollArea: a scrolling column `height` tall — the view, its
-- content child (kept as wide as the view) and a scroll bar (public, the
-- owner may seat it elsewhere) inside the view's right edge. The bar is
-- there while the content is taller than the view; with mode "shy" only
-- while the cursor is on the view as well, with "always" at all times. The
-- owner parents its rows to `content` and reports their total height.
-- ---------------------------------------------------------------------
class "CharacterScrollArea" : extends "ScrollFrame" {
    __init = function(self, parent, height, step, mode)
        ScrollFrame.__init(self, parent)
        self._height   = height
        self._overflow = 0
        self._mode     = mode

        self.content = Frame("Frame", self)
        self.content:SetSize(1, height)
        self:SetScrollChild(self.content)
        self:SetScript("OnSizeChanged", function(_, width) self.content:SetWidth(width) end)

        self.bar = MinimalScrollBar(parent)
        self.bar:SetHeight(height - 10)
        self.bar:AlignRight(self, 2)
        self.bar:PutInfront(self, 10)
        self.bar:SetScrollSpeed(step)
        self.bar.OnScroll = function(_, value) self:SetVerticalScroll(value) end
        self.bar:SetVisible(mode == "always")

        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", function(_, delta)
            self.bar:SetValue(self.bar:GetValue() - delta * step)
        end)
        if mode == "shy" then
            -- Not while a button is down: the thumb may be dragged off the view.
            self:SetScript("OnUpdate", function()
                if not IsMouseButtonDown("LeftButton") then
                    self.bar:SetVisible(self._overflow > 0 and self:IsMouseOver())
                end
            end)
        end
    end;

    SetContentHeight = function(self, height)
        self._overflow = math.max(0, height - self._height)
        self.content:SetHeight(math.max(height, self._height))
        self:UpdateScrollChildRect()
        self.bar:SetMinMax(0, self._overflow)
        self.bar:SetContentSize(self._height, math.max(height, 1))
        self:SetVerticalScroll(self.bar:GetValue())
        if not self._mode then self.bar:SetVisible(self._overflow > 0) end
    end;

    ScrollToTop = function(self)
        self.bar:SetValue(0)
    end;
}

-- ---------------------------------------------------------------------
-- CharacterTab: one of Era's CharacterFrameTab buttons in the frame tab art
-- the other windows use. Era's own pieces are made transparent rather than
-- hidden: its tab functions show and hide them on every switch. No field is
-- written to the button, as ToggleCharacter reads its fields on the way to
-- opening the panel.
-- ---------------------------------------------------------------------
class "CharacterTab" : extends "Button" {

    HEIGHT          = 31,
    HEIGHT_SELECTED = 36,

    __init = function(self, native)
        Button.__init(self, native)
        for _, region in ipairs(self:GetRegions()) do
            region:SetAlpha(0)
        end

        self._pieces = self:_Slices("BACKGROUND")
        self._hover  = self:_Slices("HIGHLIGHT")
        for _, t in ipairs(self._hover) do
            t:SetBlendMode("ADD")
            t:SetAlpha(0.4)
        end

        self._label = FontString(self, nil, "OVERLAY")
        self._label:SetFontSize(9)
        self._label:SetShadowOffset(1, -1)
        self._label:SetText(self:GetNativeText())
        self._width = math.max(72, self._label:GetStringWidth() + 28)
        -- Era's label is emptied: transparent is not enough, as selecting a
        -- tab gives it its font again and that brings it back.
        self:SetNativeText("")

        self:HookScript("OnEnter", function() self._label:SetTextColor(1, 1, 1, 1) end)
        self:HookScript("OnLeave", function() self:_ColorLabel() end)
        self:SetSelected(false)
    end;

    -- Left cap, right cap and the run between, each the tab's full height.
    _Slices = function(self, layer)
        local left = Texture(self, nil, layer)
        left:SetWidth(35)
        left:AlignParentTopLeft()
        left:AlignParentBottomLeft()
        local right = Texture(self, nil, layer)
        right:SetWidth(37)
        right:AlignParentTopRight()
        right:AlignParentBottomRight()
        local middle = Texture(self, nil, layer)
        middle:FillBetweenH(left, right)
        return { left, middle, right }
    end;

    _Apply = function(self, texture, region)
        local info = TAB_ATLAS:GetRegion(region)
        texture:SetTexture(info.file)
        texture:SetTexCoord(info.left, info.right, info.top, info.bottom)
    end;

    _ColorLabel = function(self)
        if self._selected then
            self._label:SetTextColor(1, 1, 1, 1)
        else
            self._label:SetTextColor(1, 0.82, 0, 1)
        end
    end;

    -- Era's template sizes the tab to its own label every time it shows.
    Fit = function(self)
        self:SetWidth(self._width)
    end;

    -- The selected tab is the taller, brighter set; it hangs by its top
    -- edge, so it grows away from the window.
    SetSelected = function(self, selected)
        self._selected = selected and true or false
        local suffix = self._selected and "Active" or ""
        for _, set in ipairs({ self._pieces, self._hover }) do
            self:_Apply(set[1], "TabLeft" .. suffix)
            self:_Apply(set[2], "TabMiddle" .. suffix)
            self:_Apply(set[3], "TabRight" .. suffix)
        end
        self:SetHeight(self._selected and self.HEIGHT_SELECTED or self.HEIGHT)
        self._label:ClearAllPoints()
        self._label:CenterInParent(-2, self._selected and 2 or 4)
        self:_ColorLabel()
    end;
}

-- ---------------------------------------------------------------------
-- CharacterWindow
-- ---------------------------------------------------------------------
class "CharacterWindow" : extends "PanelPortrait" {
    __init = function(self)
        self._blizzard = Frame(CharacterFrame)
        PanelPortrait.__init(self, self._blizzard, "MUI_CharacterFrame", "")
        self:FillParentPadding(NATIVE_DX, NATIVE_DY, 0, 0)
        self._tabsRight = 0

        -- Nothing of Era's frame shows or takes the mouse; this window does.
        self._blizzard:HideAllRegions()
        self._blizzard:EnableMouse(false)
        Frame(CharacterNameFrame):Hide()
        self:_ParkSubFrames()
        self:_SkinCloseButton()

        self.canvas = Frame("Frame", self)
        self.canvas:SetScale(S)
        self.canvas:Fill(self._content, -2, -21, -2, -2)
        self:_BuildBody()

        self.panes = {
            PaperDollFrame    = CharacterPaperDoll(self),
            PetPaperDollFrame = CharacterPetPane(self),
            ReputationFrame   = CharacterReputation(self),
            SkillFrame        = CharacterSkills(self),
            HonorFrame        = CharacterHonor(self),
        }

        self._tabs = {}
        for i = 1, 5 do
            local tab = CharacterTab(getglobal("CharacterFrameTab" .. i))
            -- Era resizes every tab when any of them shows.
            tab:HookScript("OnShow", function() self:_LayoutTabs() end)
            tab:HookScript("OnHide", function() self:_LayoutTabs() end)
            self._tabs[i] = tab
        end

        self:_ShowPane("PaperDollFrame")
        self:_LayoutTabs()

        hooksecurefunc("CharacterFrame_ShowSubFrame", function(name) self:_ShowPane(name) end)
        -- Era chains the reputation tab to the pet tab again whenever the pet comes or goes.
        hooksecurefunc("PetTab_Update", function() self:_LayoutTabs() end)
        self._blizzard:HookScript("OnShow", function()
            self:_UpdateHeader()
            self:_Fit()
        end)

        local function header() if self:IsVisible() then self:_UpdateHeader() end end
        self:RegisterEventHandler("UNIT_NAME_UPDATE", header)
        self:RegisterEventHandler("PLAYER_PVP_RANK_CHANGED", header)
        self:RegisterEventHandler("UNIT_PORTRAIT_UPDATE", header)
        self:RegisterEventHandler("CHARACTER_POINTS_CHANGED", header)
    end;

    -- Era's sub-frames keep running (ToggleCharacter shows and hides them,
    -- and their own events keep the tabs right), well off the screen.
    _ParkSubFrames = function(self)
        for name in pairs(SUBFRAMES) do
            local sub = Frame(getglobal(name))
            sub:ClearAllPoints()
            sub:SetPoint("BOTTOMRIGHT", MUI_Root, "TOPLEFT", -200, 200)
            sub:SetSize(384, 512)
        end
    end;

    -- Era's close button, where and how the other windows have theirs. Its
    -- own click closes the panel through the panel manager.
    _SkinCloseButton = function(self)
        local close = Button(CharacterFrameCloseButton)
        local atlas = MUI_AtlasRegistry.ButtonRedControl
        close:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        close:SetHighlightAtlas(atlas, "Highlight", true)
        close:SetSize(23, 24.5)
        close:SetScale(S)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0.5, 2)
        close:PutInfront(self._border, 1)
    end;

    -- The streak band under the title bar and the two recessed areas, the
    -- left one over retail's character panel background.
    _BuildBody = function(self)
        local streaks = Texture(self.canvas, nil, "BACKGROUND")
        streaks:SetBlizzardAtlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetHeight(43)
        streaks:AlignParentTopLeft(21, 6)
        streaks:AlignParentTopRight(21, 2)

        self.inset = InnerFrame(self.canvas)
        self.inset:HideBg()
        local background = Texture(self.inset, nil, "BACKGROUND")
        background:SetTextureRegion(MUI.TEX_SKIN .. "character\\character-panel-background", 1024, 512, 1, 1, 450, 420)
        background:FillParent()

        self.insetRight = InnerFrame(self.canvas)
        self.insetRight:Fill(self.canvas, 4 + INSET_W + 1, 60, 4, 4)
    end;

    -- ---- tabs ----------------------------------------------------------

    -- The tabs that show, in a row hanging under the window's bottom edge.
    _LayoutTabs = function(self)
        local x = TAB_LEFT
        for _, tab in ipairs(self._tabs) do
            if tab:IsShown() then
                tab:Fit()
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", x, 1)
                x = x + tab:GetWidth() - TAB_OVERLAP
            end
        end
        x = x + TAB_OVERLAP
        if x ~= self._tabsRight then
            self._tabsRight = x
            self:_Fit()
        end
    end;

    -- ---- panes ---------------------------------------------------------

    _ShowPane = function(self, name)
        if not self.panes[name] then return end
        self._active = name
        for key, pane in pairs(self.panes) do
            pane:SetVisible(key == name)
        end
        for i, tab in ipairs(self._tabs) do
            tab:SetSelected(i == SUBFRAMES[name])
        end
        self:_UpdateHeader()
        self:_Fit()
    end;

    -- The title and the portrait are the showing pane's.
    _UpdateHeader = function(self)
        local pane = self.panes[self._active]
        local text, r, g, b = pane:GetTitle()
        self:SetTitle(text)
        self._title:SetTextColor(r, g, b, 1)

        local unit, icon = pane:GetPortrait()
        if icon then
            self:SetPortrait(icon, 50)
            self._portrait:Show()
            if self._unitPortrait then self._unitPortrait:Hide() end
        else
            self:SetPortraitFromUnit(unit)
            self._unitPortrait:Show()
            if self._portrait then self._portrait:Hide() end
        end
    end;

    -- The window takes the showing pane's width (a narrow pane no narrower
    -- than the tab row), and Era's frame that plus the margin the panel
    -- manager gives it. Era's panel entry carries a fixed width of its own,
    -- which the manager would place the next panel by; it is replaced once
    -- the manager has set the frame up, and the panels are laid out again
    -- only out of combat, where the manager may move them all.
    _Fit = function(self)
        local pane = self.panes[self._active]
        local width
        if pane.wide then
            width = WindowWidth(WIDTH_WIDE)
        else
            width = math.max(WindowWidth(WIDTH_NARROW), self._tabsRight + 6)
        end

        self.inset:ClearAllPoints()
        self.inset:AlignParentTopLeft(60, 4)
        if pane.wide then
            self.inset:AlignParentBottomLeft(4, 4)
            self.inset:SetWidth(INSET_W)
        else
            self.inset:AlignParentBottomRight(4, 6)
        end
        self.insetRight:SetVisible(pane.wide)

        local native = NATIVE_DX + width
        self._blizzard:SetSize(native, NATIVE_DY + WINDOW_H)
        if native ~= self._panelWidth and self._blizzard:GetAttribute("UIPanelLayout-defined") then
            self._panelWidth = native
            self._blizzard:SetAttribute("UIPanelLayout-width", native)
            if self._blizzard:IsShown() and not InCombatLockdown() then
                UpdateUIPanelPositions(CharacterFrame)
            end
        end
    end;
}
