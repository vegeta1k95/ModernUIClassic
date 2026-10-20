-- MUI_InspectFrame: the inspect window — retail's InspectFrame (338x424, the
-- honor tab 400 wide; drawn at nine tenths like the other portrait
-- windows) on Era's InspectFrame.
--
-- Era's InspectFrame stays the real panel: the unit menu's Inspect opens it
-- through the panel manager once the server has sent the player's gear, in
-- combat too, and Escape closes it. This window is its child and covers it.
-- Era's two tab buttons and its close button stay the things that are
-- clicked, wearing our art; the guild tab, which Era doesn't have, is ours.
-- Era's two sub-frames are parked off screen and keep running; each has a
-- pane here that shows with it.
--
--   InspectWindow()
--     .canvas   retail's frame rect, at retail's scale: everything on it is
--               laid out in retail's own numbers
--     .inset    the recessed area
--     .panes    by tab: the character, honor and guild panes, each with
--               the width of retail's frame for it (.frameWidth) and where
--               the inset ends above the frame's bottom (.insetBottom)

local S = 0.9
local FRAME_H = 424
-- As the character window's tabs.
local TAB_LEFT, TAB_OVERLAP = 12, 9
local GUILD_TAB = 3

-- Era's sub-frames, by the tab each belongs to.
local SUBFRAMES = { "InspectPaperDollFrame", "InspectHonorFrame" }

class "InspectWindow" : extends "PanelPortrait" {
    __init = function(self)
        self._blizzard = Frame(InspectFrame)
        PanelPortrait.__init(self, self._blizzard, "MUI_InspectFrame", "")
        self:FillParent()
        self._eraTab = 1

        -- Nothing of Era's frame shows: its art, the inset, the name over
        -- the old title, and the template's portrait ring, which Era's own
        -- InspectFramePortrait is not (both have that name; the global is
        -- the ring's).
        self._blizzard:HideAllRegions()
        for _, key in ipairs({ "NineSlice", "Inset", "TitleContainer", "PortraitContainer" }) do
            Frame(InspectFrame[key]):Hide()
        end
        Frame(InspectNameFrame):Hide()
        -- The level line of Era's sheet hangs from that name, not from the
        -- sheet: parking the sheet leaves it here.
        FontString(InspectLevelText):SetAlpha(0)
        self:_ParkSubFrames()
        self:_SkinCloseButton()

        self.canvas = Frame("Frame", self)
        self.canvas:SetScale(S)
        self.canvas:Fill(self._content, -2, -21, -2, -2)
        self:_BuildBody()

        self.panes = {
            InspectPaperDoll(self),
            InspectHonor(self),
            InspectGuild(self),
        }
        self:_BuildTabs()
        self:_ShowPane(1)

        hooksecurefunc("InspectSwitchTabs", function(id) self:_ShowPane(id) end)
        self._blizzard:HookScript("OnShow", function() self:_UpdateHeader() end)
        self:RegisterEventHandler("INSPECT_READY", function(_, _, guid)
            local unit = InspectFrame.unit
            if unit and UnitGUID(unit) == guid then self:_UpdateHeader() end
        end)
        local function header(_, _, unit)
            if (unit == nil or unit == InspectFrame.unit) and self:IsVisible() then self:_UpdateHeader() end
        end
        self:RegisterEventHandler("UNIT_NAME_UPDATE", header)
        self:RegisterEventHandler("UNIT_PORTRAIT_UPDATE", header)
        self:RegisterEventHandler("PORTRAITS_UPDATED", header)
    end;

    -- Era's sub-frames keep running (its tab buttons show and hide them,
    -- and the honor frame asks the server for the player's honor), well
    -- off the screen.
    _ParkSubFrames = function(self)
        for _, name in ipairs(SUBFRAMES) do
            local sub = Frame(getglobal(name))
            sub:ClearAllPoints()
            sub:SetPoint("BOTTOMRIGHT", MUI_Root, "TOPLEFT", -200, 200)
            sub:SetSize(338, FRAME_H)
        end
    end;

    -- Era's close button, where and how the other windows have theirs. Its
    -- own click closes the panel through the panel manager.
    _SkinCloseButton = function(self)
        local close = Button(InspectFrame.CloseButton)
        local atlas = MUI_AtlasRegistry.ButtonRedControl
        close:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        close:SetHighlightAtlas(atlas, "Highlight", true)
        close:SetSize(23, 24.5)
        close:SetScale(S)
        close:ClearAllPoints()
        close:AlignParentTopRight(-2, -0.5)
        close:PutInfront(self._border, 1)
    end;

    -- The streak band under the title bar and the recessed area.
    _BuildBody = function(self)
        local streaks = Texture(self.canvas, nil, "BACKGROUND")
        streaks:SetBlizzardAtlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetHeight(43)
        streaks:AlignParentTopLeft(21, 6)
        streaks:AlignParentTopRight(21, 2)

        self.inset = InnerFrame(self.canvas)
    end;

    -- ---- tabs ----------------------------------------------------------

    -- Era's Character and Honor tabs, and retail's Guild tab after them.
    _BuildTabs = function(self)
        self._tabs = {}
        for i = 1, #SUBFRAMES do
            local tab = CharacterTab(getglobal("InspectFrameTab" .. i))
            -- Era resizes its tabs whenever they show.
            tab:HookScript("OnShow", function() self:_LayoutTabs() end)
            self._tabs[i] = tab
        end

        local guild = CharacterTab(self._blizzard, GUILD)
        guild:SetFrameLevel(self._tabs[1]:GetFrameLevel())
        guild:SetClickSound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        guild.OnClick = function() self:_ShowGuild() end
        guild.OnEnter = function()
            MUI_Tooltip:ShowFor(guild, "ANCHOR_RIGHT", function(tip) tip:AddTitle(GUILD) end)
        end
        guild.OnLeave = function() MUI_Tooltip:Hide() end
        self._tabs[GUILD_TAB] = guild

        self:_LayoutTabs()
    end;

    -- The tabs in a row hanging under the window's bottom edge.
    _LayoutTabs = function(self)
        local x = TAB_LEFT
        for _, tab in ipairs(self._tabs) do
            tab:Fit()
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", x, 1)
            x = x + tab:GetWidth() - TAB_OVERLAP
        end
    end;

    -- Era knows nothing of the guild tab. The tab it has selected, which it
    -- keeps disabled, is enabled again so that a click goes back to it.
    _ShowGuild = function(self)
        self:_ShowPane(GUILD_TAB)
        self._tabs[self._eraTab]:SetEnabled(true)
    end;

    -- ---- panes ---------------------------------------------------------

    _ShowPane = function(self, id)
        if not self.panes[id] then return end
        if id ~= GUILD_TAB then self._eraTab = id end
        self._active = id
        for i, pane in ipairs(self.panes) do
            pane:SetVisible(i == id)
        end
        for i, tab in ipairs(self._tabs) do
            tab:SetSelected(i == id)
        end
        self:_LayoutTabs()
        self:_Fit()
    end;

    -- The inspected player's name and portrait, and the guild tab open to
    -- a player in a guild.
    _UpdateHeader = function(self)
        local unit = InspectFrame.unit
        if not unit then return end
        self:SetTitle(GetUnitName(unit, true))
        self._title:SetTextColor(1, 1, 1, 1)
        self:SetPortraitFromUnit(unit)
        self._tabs[GUILD_TAB]:SetTabEnabled(self.panes[GUILD_TAB]:ReadGuild(unit) ~= nil)
    end;

    -- Era's frame takes the showing pane's width, and with it everything
    -- laid out on the canvas. The panel manager places the next panel by
    -- that width; it moves the open panels only out of combat.
    _Fit = function(self)
        local pane = self.panes[self._active]
        self.inset:ClearAllPoints()
        self.inset:Fill(self.canvas, 4, 60, 6, pane.insetBottom)
        self._blizzard:SetSize((pane.frameWidth - 4) * S + 6, (FRAME_H - 23) * S + 21)
        if self._blizzard:IsShown() and not InCombatLockdown() then
            UpdateUIPanelPositions(InspectFrame)
        end
    end;
}
