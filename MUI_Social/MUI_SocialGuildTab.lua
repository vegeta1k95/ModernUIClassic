-- SocialGuildTab: Era's guild roster tab (shown with the classic guild window
-- on) spread over retail's wider window. Retail has no such tab — its guild
-- is the Communities window — so the layout is Era's own, 47 wider: the
-- columns of both roster views, the rows under them, the buttons below.

-- The roster rows of either view, and Era's scroll frame over them.
local LIST_X, LIST_Y, LIST_W = 3, 82, 357
local ROW_H = 16
-- "Player status" view: name, zone, level, class.
local PLAYER_COLUMNS = { 100, 125, 32, 102 }
local PLAYER_NAME_W, PLAYER_ZONE_W, PLAYER_CLASS_W = 105, 115, 97
-- "Guild status" view: name, rank, note, last online.
local GUILD_COLUMNS = { 100, 85, 96, 78 }
local GUILD_NAME_W, GUILD_RANK_W, GUILD_NOTE_W, GUILD_ONLINE_W = 90, 67, 91, 70
-- The view toggle arrow, on the totals line right of the list.
local TOGGLE_X, TOGGLE_Y = 319, -98
local MOTD_W = 362
-- Guild Information, Add Member, Guild Control: the bottom row, edge to edge.
local INFO_W, ADD_W, CONTROL_W = 139, 110, 120

class "SocialGuildTab" {

    __init = function(self)
        self._zones, self._classes, self._notes = {}, {}, {}
        self._toggle = Frame(GuildFrameGuildListToggleButton)

        self:_LayoutPlayerView()
        self:_LayoutGuildView()
        self:_BuildScrollBar()

        FontString(GuildFrameNotesText):SetWidth(MOTD_W)
        Frame(GuildFrameGuildInformationButton):SetWidth(INFO_W)
        Frame(GuildFrameAddMemberButton):SetWidth(ADD_W)
        Frame(GuildFrameControlButton):SetWidth(CONTROL_W)
        Frame(GuildFrameImpeachButton):SetWidth(CONTROL_W)

        -- Blizzard sizes a column of either view, and seats the toggle
        -- arrow, for its own scroll bar on each update.
        hooksecurefunc("GuildStatus_Update", function() self:_Reassert() end)
        self:_Reassert()
    end;

    _Row = function(self, name)
        local row = Button(_G[name])
        row:SetWidth(LIST_W)
        local highlight = row:GetHighlightTexture()
        highlight:ClearAllPoints()
        highlight:FillParent()
    end;

    _LayoutPlayerView = function(self)
        for i, width in ipairs(PLAYER_COLUMNS) do
            WhoFrameColumn_SetWidth(_G["GuildFrameColumnHeader" .. i], width)
        end
        for i = 1, GUILDMEMBERS_TO_DISPLAY do
            local name = "GuildFrameButton" .. i
            self:_Row(name)
            FontString(_G[name .. "Name"]):SetWidth(PLAYER_NAME_W)
            self._zones[i]   = FontString(_G[name .. "Zone"])
            self._classes[i] = FontString(_G[name .. "Class"])
        end
    end;

    _LayoutGuildView = function(self)
        for i, width in ipairs(GUILD_COLUMNS) do
            WhoFrameColumn_SetWidth(_G["GuildFrameGuildStatusColumnHeader" .. i], width)
        end
        for i = 1, GUILDMEMBERS_TO_DISPLAY do
            local name = "GuildFrameGuildStatusButton" .. i
            self:_Row(name)
            FontString(_G[name .. "Name"]):SetWidth(GUILD_NAME_W)
            FontString(_G[name .. "Rank"]):SetWidth(GUILD_RANK_W)
            FontString(_G[name .. "Online"]):SetWidth(GUILD_ONLINE_W)
            self._notes[i] = FontString(_G[name .. "Note"])
        end
    end;

    -- Blizzard's scroll frame over the rows, so the wheel scrolls anywhere
    -- on the list, and our bar beside it.
    _BuildScrollBar = function(self)
        local height = GUILDMEMBERS_TO_DISPLAY * ROW_H
        local scroll = Frame(GuildListScrollFrame)
        scroll:ClearAllPoints()
        scroll:AlignParentTopLeft(LIST_Y, LIST_X)
        scroll:SetSize(LIST_W, height)

        local bar = NativeScrollBar(Frame(GuildFrame), GuildListScrollFrame,
                                    GuildListScrollFrameScrollBar, height - 6)
        bar:RightOf(scroll, 5, -1)
    end;

    _Reassert = function(self)
        for i = 1, GUILDMEMBERS_TO_DISPLAY do
            self._zones[i]:SetWidth(PLAYER_ZONE_W)
            self._classes[i]:SetWidth(PLAYER_CLASS_W)
            self._notes[i]:SetWidth(GUILD_NOTE_W)
        end
        WhoFrameColumn_SetWidth(GuildFrameColumnHeader2, PLAYER_COLUMNS[2])
        WhoFrameColumn_SetWidth(GuildFrameGuildStatusColumnHeader3, GUILD_COLUMNS[3])
        self._toggle:ClearAllPoints()
        self._toggle:AlignParentLeft(TOGGLE_X, TOGGLE_Y)
    end;
}
