-- PanelTab: retail's frame tab art on one of Blizzard's PanelTemplates tabs —
-- the row hanging under a window ("bottom"), or the shorter row standing on
-- the list inside it ("top").
--
-- Blizzard keeps driving the button: its tab functions show and hide its own
-- art, re-seat its label, enable or disable it on every switch, and size it to
-- that label. So its art is made transparent rather than hidden, its label
-- emptied (a font change brings a transparent one back), and ours follow from
-- hooks on those functions. No field is written on the button: Blizzard's tab
-- code reads them on the way to opening the window.
--
-- Wrap:   PanelTab(blizzardTab, direction)
-- Create: PanelTab(parent, direction, text, name) — a tab of our own from
--         Blizzard's TabButtonTemplate, outside any PanelTemplates set and
--         switched with SetSelected.

local ATLAS = MUI_AtlasRegistry.TabBottom

-- Retail's measures: PanelTabButtonTemplate, and FriendsTabTemplate for the
-- top row (the same art upside down at three quarters of its height). The
-- caps carry a margin of their own (4 on the left one and 8 on the right; 3
-- and 9 on the selected pair), so they overhang the button. Retail turns the
-- top row's art half round, which swaps the two caps; here it is only
-- flipped, so its overhangs are the ones that put the tab's body where
-- retail's is: 2 in from the left, 4 from the right (3 when selected).
local STYLES = {
    bottom = {
        edge = "TOP", squash = 1,
        left = -3, right = 7, leftActive = -1, rightActive = 8,
        labelY = 2, labelActiveY = -3,
        pad = 20, minWidth = 72,
    },
    top = {
        edge = "BOTTOM", squash = 0.75,
        left = -2, right = 4, leftActive = -1, rightActive = 6,
        labelY = -3, labelActiveY = 0,
        pad = 10, minWidth = 100, maxWidth = 150,
    },
}

-- Skinned tabs by their native button, for the hooks below.
local tabs = {}

local function Each(native, method)
    local tab = tabs[native]
    if tab then tab[method](tab) end
end

class "PanelTab" : extends "Button" {

    __init = function(self, native, direction, text, name)
        if IsNativeObject(native) then
            Button.__init(self, native)
        else
            Frame.__init(self, "Button", native, name, "TabButtonTemplate")
            self._enabled = true
            native = _G[name]
        end
        self._tab = native
        self._style = STYLES[direction or "bottom"]

        for _, region in ipairs(self:GetRegions()) do
            region:SetAlpha(0)
        end
        -- Blizzard's art for the selected tab: shown on that one only.
        self._nativeActive = Texture(_G[self:GetName() .. "LeftDisabled"])

        self._normal = self:_Slices("BACKGROUND", "", false)
        self._active = self:_Slices("BACKGROUND", "Active", true)
        self._hover  = self:_Slices("HIGHLIGHT", "", false)
        for _, piece in ipairs(self._hover) do
            piece:SetBlendMode("ADD")
            piece:SetAlpha(0.4)
        end

        self._label = FontString(self, nil, "OVERLAY")
        self._label:SetFontSize(10)
        self._label:SetShadowOffset(1, -1)
        self._label:SetText(text or self:GetNativeText())
        self:SetNativeText("")

        self:HookScript("OnEnter", function() self:_ColorLabel(true) end)
        self:HookScript("OnLeave", function() self:_ColorLabel(false) end)

        if not next(tabs) then self:_HookTemplates() end
        tabs[native] = self
        self:Sync()
        self:Fit()
    end;

    -- Once, for every skinned tab.
    _HookTemplates = function(self)
        hooksecurefunc("PanelTemplates_SelectTab", function(native) Each(native, "Sync") end)
        hooksecurefunc("PanelTemplates_DeselectTab", function(native) Each(native, "Sync") end)
        hooksecurefunc("PanelTemplates_SetDisabledTabState", function(native) Each(native, "Sync") end)
        hooksecurefunc("PanelTemplates_TabResize", function(native) Each(native, "Fit") end)
    end;

    -- Left cap, right cap and the run between, hanging from the tab's top
    -- edge (or standing on its bottom one) at the art's own height.
    _Slices = function(self, layer, suffix, active)
        local style = self._style
        local flipped = style.edge == "BOTTOM"
        local pieces = {}
        for i, part in ipairs({ "Left", "Right", "Middle" }) do
            local info = ATLAS:GetRegion("Tab" .. part .. suffix)
            local piece = Texture(self, nil, layer)
            piece:SetTexture(info.file)
            if flipped then
                piece:SetTexCoord(info.left, info.right, info.bottom, info.top)
            else
                piece:SetTexCoord(info.left, info.right, info.top, info.bottom)
            end
            piece:SetSize(info.width, info.height * style.squash)
            pieces[i] = piece
        end
        local left, right, middle = pieces[1], pieces[2], pieces[3]
        local leftX  = active and style.leftActive or style.left
        local rightX = active and style.rightActive or style.right
        if flipped then
            left:AlignParentBottomLeft(0, leftX)
            right:AlignParentBottomRight(0, -rightX)
        else
            left:AlignParentTopLeft(0, leftX)
            right:AlignParentTopRight(0, -rightX)
        end
        middle:FillBetweenH(left, right)
        return pieces
    end;

    _ColorLabel = function(self, hovered)
        if self._disabled then
            self._label:SetTextColor(0.5, 0.5, 0.5, 1)
        elseif self._selected or hovered then
            self._label:SetTextColor(1, 1, 1, 1)
        else
            self._label:SetTextColor(1, 0.82, 0, 1)
        end
    end;

    -- For a tab of our own: Blizzard's switch, which the hooks follow.
    SetSelected = function(self, selected)
        if selected then
            PanelTemplates_SelectTab(self._tab)
        else
            PanelTemplates_DeselectTab(self._tab)
        end
    end;

    -- Draw the tab as not selected whatever Blizzard has it as: a view of ours
    -- is up in place of the one it stands for. Blizzard's own handler ignores
    -- a click on its selected tab, so while muted that click goes to
    -- `self.OnMutedClick` instead.
    SetMuted = function(self, muted)
        self._muted = muted
        if muted and not self._catcher then
            self._catcher = Button(self)
            self._catcher:FillParent()
            self._catcher:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            self._catcher.OnClick = function()
                if self.OnMutedClick then self:OnMutedClick() end
            end
        end
        self:Sync()
    end;

    -- Blizzard disables the selected tab and one it has greyed out alike;
    -- only the selected one has its own selected art showing.
    Sync = function(self)
        local chosen = self._nativeActive:IsShown()
        self._selected = chosen and not self._muted
        self._disabled = not chosen and not self:IsEnabled()
        if self._catcher then
            self._catcher:SetVisible(chosen and self._muted)
        end

        for _, piece in ipairs(self._normal) do piece:SetVisible(not self._selected) end
        for _, piece in ipairs(self._active) do piece:SetVisible(self._selected) end

        local style = self._style
        self._label:ClearAllPoints()
        self._label:CenterInParent(0, self._selected and style.labelActiveY or style.labelY)
        self:_ColorLabel(self:IsMouseOver())
    end;

    -- Blizzard sizes the tab to its own (now empty) label whenever it shows.
    Fit = function(self)
        local style = self._style
        local width = math.max(self._label:GetStringWidth() + style.pad, style.minWidth)
        if style.maxWidth then width = math.min(width, style.maxWidth) end
        self:SetWidth(width)
    end;
}
