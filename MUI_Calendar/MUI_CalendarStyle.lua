-- MUI_CalendarStyle: what the calendar's frames share — the scale, the art,
-- how an event is named and coloured (retail's Blizzard_Calendar tables),
-- the dungeons an event can be for, and the dialog every side panel is.

local ART = "Interface\\Calendar\\"

-- Retail's CALENDAR_CALENDARTYPE_NAMEFORMAT (on the calendar) and
-- CALENDAR_CALENDARTYPE_TOOLTIP_NAMEFORMAT (in a day's tooltip).
local NAME_FORMAT = {
    HOLIDAY      = { START = "%s", END = "%s", ONGOING = "%s", [""] = "%s" },
    RAID_LOCKOUT = { [""] = CALENDAR_EVENTNAME_FORMAT_RAID_LOCKOUT },
}
local TOOLTIP_NAME_FORMAT = {
    HOLIDAY      = { START = CALENDAR_EVENTNAME_FORMAT_START, END = CALENDAR_EVENTNAME_FORMAT_END, ONGOING = "%s", [""] = "%s" },
    RAID_LOCKOUT = { [""] = CALENDAR_EVENTNAME_FORMAT_RAID_LOCKOUT },
}

local TYPE_COLORS = {
    SYSTEM       = YELLOW_FONT_COLOR,
    HOLIDAY      = HIGHLIGHT_FONT_COLOR,
    RAID_LOCKOUT = HIGHLIGHT_FONT_COLOR,
}
local TOOLTIP_TYPE_COLORS = { HOLIDAY = NORMAL_FONT_COLOR }
local MODERATOR_COLOR = CreateColor(0.54, 0.75, 1.0)

local PLAYER_TYPES = { PLAYER = true, GUILD_ANNOUNCEMENT = true, GUILD_EVENT = true, COMMUNITY_EVENT = true }

local EVENT_TYPE_NAMES = {
    [Enum.CalendarEventType.Raid]    = CALENDAR_TYPE_RAID,
    [Enum.CalendarEventType.Dungeon] = CALENDAR_TYPE_DUNGEON,
    [Enum.CalendarEventType.PvP]     = CALENDAR_TYPE_PVP,
    [Enum.CalendarEventType.Meeting] = CALENDAR_TYPE_MEETING,
    [Enum.CalendarEventType.Other]   = CALENDAR_TYPE_OTHER,
}
local EVENT_TYPE_TEXTURES = {
    [Enum.CalendarEventType.Raid]    = "Interface\\LFGFrame\\LFGIcon-Raid",
    [Enum.CalendarEventType.Dungeon] = "Interface\\LFGFrame\\LFGIcon-Dungeon",
    [Enum.CalendarEventType.Meeting] = ART .. "MeetingIcon",
    [Enum.CalendarEventType.Other]   = ART .. "UI-Calendar-Event-Other",
}

object "CalendarStyle" {

    -- The window is drawn at nine tenths, like the other windows: everything
    -- in it is laid out in retail's own numbers.
    S = 0.9,

    ART = ART,

    -- A string in one of Blizzard's fonts (GameFontNormal, ...).
    Label = function(self, parent, font, layer)
        return FontString(parent, nil, layer or "OVERLAY", font)
    end;

    -- A piece of a calendar sheet: `file` under Interface\Calendar unless it
    -- has a folder of its own, at `w` x `h`, cut at left, right, top, bottom.
    Art = function(self, parent, layer, file, w, h, l, r, t, b)
        local texture = Texture(parent, nil, layer)
        texture:SetTexture(file:find("\\") and file or ART .. file)
        if w then texture:SetSize(w, h) end
        if l then texture:SetTexCoord(l, r, t, b) end
        return texture
    end;

    -- The dark strip retail lays under a dialog's bottom buttons.
    ButtonStrip = function(self, dialog)
        local strip = self:Art(dialog, "ARTWORK", "Interface\\Buttons\\UI-Button-Borders", nil, nil, 0, 1, 0.59375, 1)
        strip:SetHeight(26)
        strip:AlignParentBottomLeft(9, 11)
        strip:AlignParentBottomRight(9, 11)
        return strip
    end;

    -- The frame of a bottom button: the right-hand one's, or the left's.
    ButtonBorder = function(self, button, left)
        local border = self:Art(button, "BACKGROUND", "Interface\\Buttons\\UI-Button-Borders")
        if left then
            border:SetTexCoord(0, 0.4140625, 0, 0.40625)
            border:Fill(button, -1, -1, -10, -3)
        else
            border:SetTexCoord(0.58203125, 1, 0, 0.40625)
            border:Fill(button, -10, -1, -1, -3)
        end
        return border
    end;

    FormatTime = function(self, hour, minute)
        return GameTime_GetFormattedTime(hour, minute, true)
    end;

    -- "Sunday, October 18 2026", from a CalendarTime or its parts.
    FullDate = function(self, weekday, month, day, year)
        return FULLDATE:format(CALENDAR_WEEKDAY_NAMES[weekday], CALENDAR_FULLDATE_MONTH_NAMES[month], day, year)
    end;

    IsPlayerEvent = function(self, calendarType)
        return PLAYER_TYPES[calendarType] == true
    end;

    -- An event's line on the calendar, or in a tooltip.
    EventTitle = function(self, event, tooltip)
        local title = event.isCustomTitle and event.title or _G[event.title] or event.title
        if event.calendarType == "RAID_LOCKOUT" then
            title = GetDungeonNameWithDifficulty(title, "")
        end
        local formats = (tooltip and TOOLTIP_NAME_FORMAT or NAME_FORMAT)[event.calendarType]
        return ((formats and formats[event.sequenceType]) or "%s"):format(title)
    end;

    -- Retail's _CalendarFrame_GetEventColor: a player event in its invite
    -- status's colour (blue to its moderators), the rest by kind.
    EventColor = function(self, event, tooltip)
        local calendarType = event.calendarType
        if PLAYER_TYPES[calendarType] then
            if event.modStatus == "MODERATOR" or event.modStatus == "CREATOR" then
                return MODERATOR_COLOR
            end
            local info = CALENDAR_INVITESTATUS_INFO[event.inviteStatus]
            if info then return info.color end
        elseif tooltip and TOOLTIP_TYPE_COLORS[calendarType] then
            return TOOLTIP_TYPE_COLORS[calendarType]
        elseif TYPE_COLORS[calendarType] then
            return TYPE_COLORS[calendarType]
        end
        return NORMAL_FONT_COLOR
    end;

    EventTypeName = function(self, eventType)
        return EVENT_TYPE_NAMES[eventType] or CALENDAR_TYPE_OTHER
    end;

    -- The PvP icon is the player's faction's.
    EventTypeTexture = function(self, eventType)
        if eventType == Enum.CalendarEventType.PvP then
            return ART .. (UnitFactionGroup("player") == "Alliance" and "UI-Calendar-Event-PVP02" or "UI-Calendar-Event-PVP01")
        end
        return EVENT_TYPE_TEXTURES[eventType] or EVENT_TYPE_TEXTURES[Enum.CalendarEventType.Other]
    end;

    -- The dungeons (or raids) an event of `eventType` can be for, as the
    -- texture picker lists them: { textureIndex, title, texture } entries
    -- under a header per expansion, a blank row between expansions.
    Dungeons = function(self, eventType)
        if self._dungeonType ~= eventType then
            local list, expansion = {}, nil
            for index, info in ipairs(C_Calendar.EventGetTextures(eventType)) do
                if info.expansionLevel ~= expansion then
                    if expansion then list[#list + 1] = {} end
                    list[#list + 1] = { header = _G["EXPANSION_NAME" .. info.expansionLevel] }
                    expansion = info.expansionLevel
                end
                list[#list + 1] = { textureIndex = index, title = info.title, texture = info.iconTexture }
            end
            self._dungeonType, self._dungeons = eventType, list
        end
        return self._dungeons
    end;

    -- The dungeon an event's texture index stands for, if any.
    Dungeon = function(self, textureIndex, eventType)
        if not textureIndex or not eventType then return nil end
        for _, entry in ipairs(self:Dungeons(eventType)) do
            if entry.textureIndex == textureIndex then return entry end
        end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarButton: retail's CalendarEventButtonTemplate (a 95x22
-- UIPanelButtonTemplate) in the gold button's art, with a tooltip when it
-- is given one.
-- ---------------------------------------------------------------------
class "CalendarButton" : extends "ButtonGold" {
    __init = function(self, parent, text, tooltip)
        ButtonGold.__init(self, parent, nil, text)
        self:SetSize(95, 22)
        self.tooltip = tooltip

        local onEnter, onLeave = self.OnEnter, self.OnLeave
        self.OnEnter = function()
            onEnter(self)
            if self.tooltip then
                MUI_Tooltip:ShowFor(self, "ANCHOR_LEFT", function(t) t:AddLine(self.tooltip, 1, 1, 1, true) end)
            end
        end
        self.OnLeave = function()
            onLeave(self)
            MUI_Tooltip:Hide()
        end
    end;

    -- As wide as its text, as retail sizes its labelled buttons.
    FitText = function(self)
        self:SetWidth(self.label:GetStringWidth() + 40)
    end;

    -- SetEnabled for a state polled often: the art changes only with it.
    SetActive = function(self, enabled)
        if self._active ~= enabled then
            self._active = enabled
            self:SetEnabled(enabled)
        end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarDialog: retail's calendar side panel — DialogBorderDarkTemplate
-- (our diamond border), DialogHeaderTemplate (the header plate over its
-- top edge) and a close button. What the panel shows goes on .content,
-- which sits over the border's dark centre.
-- ---------------------------------------------------------------------
class "CalendarDialog" : extends "Frame" {
    __init = function(self, parent, name, width, height, title)
        Frame.__init(self, "Frame", parent, name)
        self:SetSize(width, height)
        self:SetToplevel(true)
        self:EnableMouse(true)
        self:Hide()

        self._border = DiamondBorder(self)
        self._border:FillParent()
        self._border:SetFrameLevel(self:GetFrameLevel())

        self.content = Frame("Frame", self)
        self.content:FillParent()

        self._header = DiamondHeader(self, nil, title or "")
        self._header:AlignTop(self._border, -26)

        self.closeButton = CloseButton(self)
        self.closeButton:ClearAllPoints()
        self.closeButton:AlignParentTopRight(7, 7)
    end;

    SetTitle = function(self, text)
        self._header:SetText(text)
    end;
}
