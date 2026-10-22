-- SocialFriendsTab: the Friends tab at retail's width — the Battle.net strip,
-- the tab row standing on the list, the friends and ignore lists — and the
-- Recent Allies view beside them.
--
-- Era's two header tabs are a PanelTemplates set of their own, whose selected
-- tab Blizzard's Lua reads when the window opens. A third tab can not be added
-- to that set from here without tainting it, so Recent Allies is a view of
-- ours laid over the tab: while it is up the list Blizzard's selection stands
-- for is hidden, and its header tab is drawn as not selected.

local L = MUI.L

-- Retail's ScrollBox: 8 in from the window's left edge, 87 below its top, and
-- as wide as the window less the scroll bar's gutter.
local LIST_X, LIST_Y, LIST_W = 8, 87, 349
local IGNORE_H = 309
-- Retail's Battle.net strip, under the title and right of the status menu.
local BNET_X, BNET_Y, STATUS_GAP = 155, 27, 7
-- Retail's header tabs: 24 tall, their bottom edge on the inset.
local HEADER_X, HEADER_Y, HEADER_H, HEADER_GAP = 18, 60, 24, 1
-- Bottom buttons, as retail's FriendsFrameButtonTemplate.
local BUTTON_W = 134
local HEADER_IGNORE = 2

local ALLIES_LABEL = L.CONTACTS_RECENT_ALLIES_TAB_NAME

class "SocialFriendsTab" {

    __init = function(self, window)
        self._window  = window
        self._header  = Frame(FriendsTabHeader)
        self._friends = Frame(FriendsListFrame)
        self._ignores = Frame(IgnoreListFrame)
        self._alliesShown = false

        self:_LayoutBattlenet()
        self:_BuildFriendsList()
        self:_BuildIgnoreList()
        self:_BuildAllies()
        self:_BuildHeaderTabs()
    end;

    -- ---- Battle.net strip ----------------------------------------------

    -- Era has the strip at the left, where retail's wider window has the
    -- status menu; the broadcast button rides on the strip's right end.
    _LayoutBattlenet = function(self)
        local bnet = Frame(FriendsFrameBattlenetFrame)
        bnet:ClearAllPoints()
        bnet:AlignParentTopLeft(BNET_Y, BNET_X)
        local status = Frame(FriendsFrameStatusDropdown)
        status:ClearAllPoints()
        status:LeftOf(bnet, STATUS_GAP)
        self._status = DropdownSkin(FriendsFrameStatusDropdown)
    end;

    -- ---- friends list --------------------------------------------------

    -- Era's rows are made once, at their template's 298.
    _BuildFriendsList = function(self)
        local scroll = Frame(FriendsFrameFriendsScrollFrame)
        scroll:SetWidth(LIST_W)
        Frame(FriendsFrameFriendsScrollFrameScrollChild):SetWidth(LIST_W)
        for _, row in ipairs(FriendsFrameFriendsScrollFrame.buttons) do
            Frame(row):SetWidth(LIST_W)
        end
        Frame(FriendsFrameFriendsScrollFrame.PendingInvitesHeaderButton):SetWidth(LIST_W - 3)
        Frame(FriendsListFrame.RIDWarning):SetWidth(LIST_W + 2)

        local bar = NativeScrollBar(self._friends, FriendsFrameFriendsScrollFrame,
                                    FriendsFrameFriendsScrollFrameScrollBar, FRIENDS_SCROLLFRAME_HEIGHT - 6)
        bar:RightOf(scroll, 5, -1)

        Frame(FriendsFrameAddFriendButton):SetWidth(BUTTON_W)
        Frame(FriendsFrameSendMessageButton):SetWidth(BUTTON_W)
    end;

    -- ---- ignore list ---------------------------------------------------

    _BuildIgnoreList = function(self)
        for i = 1, IGNORES_TO_DISPLAY do
            Frame(_G["FriendsFrameIgnoreButton" .. i]):SetWidth(LIST_W)
        end
        -- The classic scroll bar's track, drawn on the list frame here.
        Texture(IgnoreListFrameTop):Hide()
        Texture(IgnoreListFrameBottom):Hide()
        Texture(IgnoreListFrameMiddle):Hide()

        -- Over the rows, so the wheel scrolls anywhere on the list.
        local scroll = Frame(FriendsFrameIgnoreScrollFrame)
        scroll:ClearAllPoints()
        scroll:AlignParentTopLeft(LIST_Y, LIST_X)
        scroll:SetSize(LIST_W, IGNORE_H)

        local bar = NativeScrollBar(self._ignores, FriendsFrameIgnoreScrollFrame,
                                    FriendsFrameIgnoreScrollFrameScrollBar, IGNORE_H - 6)
        bar:RightOf(scroll, 5, -1)
    end;

    -- ---- recent allies -------------------------------------------------

    _BuildAllies = function(self)
        self._allies = SocialAlliesList(self._header, SocialAllies())
        self._allies:AlignParentTopLeft(LIST_Y, LIST_X)
        self._allies:Hide()
    end;

    -- ---- header tabs ---------------------------------------------------

    _BuildHeaderTabs = function(self)
        self._tabs = {
            PanelTab(FriendsTabHeaderTab1, "top"),
            PanelTab(FriendsTabHeaderTab2, "top"),
        }
        self._alliesTab = PanelTab(self._header, "top", ALLIES_LABEL, "MUI_SocialAlliesTab")
        self._alliesTab:SetSelected(false)

        local previous
        for _, tab in ipairs({ self._tabs[1], self._tabs[2], self._alliesTab }) do
            tab:SetHeight(HEADER_H)
            tab:ClearAllPoints()
            if previous then
                tab:RightOf(previous, HEADER_GAP)
            else
                tab:AlignParentTopLeft(HEADER_Y, HEADER_X)
            end
            previous = tab
        end

        -- Blizzard's own click has already switched its list by the time the
        -- hook runs; the tab it has as selected takes no click of its own.
        for _, tab in ipairs(self._tabs) do
            tab:HookScript("OnClick", function() self:ShowAllies(false) end)
            tab.OnMutedClick = function() self:ShowAllies(false) end
        end
        self._alliesTab:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            self:ShowAllies(true)
        end)
    end;

    ShowAllies = function(self, show)
        if self._alliesShown == show then return end
        self._alliesShown = show
        for _, tab in ipairs(self._tabs) do
            tab:SetMuted(show)
        end
        self._alliesTab:SetSelected(show)
        self._allies:SetVisible(show)
        if not show then self:_ShowBlizzardList() end
        self._window:Refresh()
    end;

    -- The list Blizzard's header selection stands for, back from under the
    -- allies view. The friends list skips its updates while hidden, so a
    -- fresh one is asked for: Blizzard redraws it on the reply.
    _ShowBlizzardList = function(self)
        if PanelTemplates_GetSelectedTab(FriendsTabHeader) == HEADER_IGNORE then
            self._ignores:Show()
        else
            self._friends:Show()
            C_FriendList.ShowFriends()
        end
    end;

    -- Blizzard shows its own list again on every update of the window.
    Refresh = function(self)
        if self._alliesShown then
            self._friends:Hide()
            self._ignores:Hide()
        end
    end;

    -- The window's title while the allies view is up, nil for Blizzard's.
    GetTitle = function(self)
        return self._alliesShown and ALLIES_LABEL or nil
    end;
}
