-- SocialWindow: Era's FriendsFrame (Friends / Who / Guild / Raid) as retail's
-- social window — its width, the metal frame, the frame tabs under it.
--
-- Reskinned in place. The frame stays Blizzard's: it is a UIPanel, the
-- keybinds and the micro button toggle it, and its Lua runs every list. Once
-- the raid tab has been opened it also holds Blizzard's secure raid buttons,
-- which makes the frame itself protected in combat, so nothing here writes a
-- field on it or on anything its Lua reads (that would taint the code that
-- opens it), and its own size is set once, out of combat.

-- Retail's FriendsFrame; Era's is the template's 338 x 424.
local WIDTH, HEIGHT = 385, 424
local PORTRAIT = "Interface\\FriendsFrame\\Battlenet-Portrait"

-- Era's bottom tabs: Friends, Who, Guild (only with the classic guild
-- window on), Raid.
local TAB_COUNT, TAB_FRIENDS = 4, 1
-- Retail's row: the first tab 5 in from the corner and 30 below the window's
-- bottom edge, each next one 3 right of the one before. (Its XML tucks them
-- 15 under each other; PanelTemplates_AnchorTabs re-seats them at load.)
local TAB_X, TAB_Y, TAB_GAP = 5, -30, 3

class "SocialWindow" : extends "Frame" {

    __init = function(self)
        Frame.__init(self, FriendsFrame)
        self._nativeTitle = FontString(FriendsFrameTitleText)

        self:_Resize()
        self:_HideClassicArt()
        self:_BuildTabs()

        self.friends = SocialFriendsTab(self)
        self.who     = SocialWhoTab()
        self.guild   = SocialGuildTab()
        self.raid    = SocialRaidTab()

        -- Blizzard's art, the close button and the frame levels come back
        -- with every show.
        self:_ApplyChrome()
        self:HookScript("OnShow", function() self:_ApplyChrome() end)
        hooksecurefunc("FriendsFrame_Update", function() self:Refresh() end)
        hooksecurefunc("FriendsFrame_UpdateGuildTabVisibility", function() self:_LayoutTabs() end)
        self:Refresh()
    end;

    -- ---- frame ---------------------------------------------------------

    _Resize = function(self)
        if self:IsProtected() and InCombatLockdown() then
            self._events = Frame()
            self._events:RegisterEventHandler("PLAYER_REGEN_ENABLED", function(events)
                events:UnregisterEventHandler("PLAYER_REGEN_ENABLED")
                self:SetSize(WIDTH, HEIGHT)
            end)
            return
        end
        self:SetSize(WIDTH, HEIGHT)
    end;

    -- What PanelChrome leaves: the button bar's strip (Blizzard shows it
    -- again on every tab switch), the loose portrait and the loose title.
    _HideClassicArt = function(self)
        Texture(FriendsFrameBtnCornerLeft):SetAlpha(0)
        Texture(FriendsFrameBtnCornerRight):SetAlpha(0)
        Texture(FriendsFrameButtonBottomBorder):SetAlpha(0)
        Texture(FriendsFrameIcon):Hide()
        self._nativeTitle:Hide()
    end;

    _ApplyChrome = function(self)
        MUI_PanelChrome:Apply(FriendsFrame)
        self:SetPortraitToAsset(PORTRAIT)
        self:_UpdateTitle()
    end;

    -- Blizzard writes each tab's title to its own string; ours is drawn above
    -- the metal frame.
    _UpdateTitle = function(self)
        local title = self._nativeTitle:GetText()
        if self:GetSelectedTab() == TAB_FRIENDS then
            title = self.friends:GetTitle() or title
        end
        MUI_PanelChrome:SetTitle(FriendsFrame, title)
    end;

    GetSelectedTab = function(self)
        return PanelTemplates_GetSelectedTab(FriendsFrame) or TAB_FRIENDS
    end;

    -- After every tab switch, and whenever the window shows.
    Refresh = function(self)
        self.friends:Refresh()
        self:_UpdateTitle()
    end;

    -- ---- tabs ----------------------------------------------------------

    _BuildTabs = function(self)
        self._tabs = {}
        for i = 1, TAB_COUNT do
            self._tabs[i] = PanelTab(_G["FriendsFrameTab" .. i], "bottom")
        end
        self:_LayoutTabs()
    end;

    -- The tabs that show, in a row hanging under the window. Blizzard chains
    -- the raid tab to the guild or the who tab again each time it shows.
    _LayoutTabs = function(self)
        local previous
        for _, tab in ipairs(self._tabs) do
            if tab:IsShown() then
                tab:ClearAllPoints()
                if previous then
                    tab:RightOf(previous, TAB_GAP)
                else
                    tab:AlignParentBottomLeft(TAB_Y, TAB_X)
                end
                previous = tab
            end
        end
    end;
}
