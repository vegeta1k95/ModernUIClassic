-- MUI_CalendarPanels: what opens beside or over the calendar.
--
--   CalendarHolidayPanel     a holiday's description and dates
--                            (retail's CalendarViewHolidayFrame)
--   CalendarRaidPanel        when a saved raid unlocks (CalendarViewRaidFrame)
--   CalendarViewEventPanel   an event the player is invited to: its details,
--                            the replies, the invite list (CalendarViewEventFrame)
--   CalendarEventPicker      a day's events when they don't fit in the day
--   CalendarTexturePicker    the dungeon or raid an event is for
--
-- The side panels open at the calendar's right edge, 24 below its top; the
-- two pickers are modal (the window dims the calendar behind them).

local Style = MUI_CalendarStyle

local PANEL_Y = -24
local HOLIDAY_COORDS = { 0, 0.7109375, 0, 0.7109375 }


-- ---------------------------------------------------------------------
-- CalendarHolidayPanel
-- ---------------------------------------------------------------------
class "CalendarHolidayPanel" : extends "CalendarDialog" {
    __init = function(self, window)
        CalendarDialog.__init(self, window, "MUI_CalendarViewHolidayFrame", 320, 320)
        self:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, PANEL_Y)

        -- Retail lays the default holiday art behind the text, faint.
        local art = Style:Art(self.content, "BORDER", Style.ART .. "Holidays\\Calendar_DefaultHoliday",
            nil, nil, HOLIDAY_COORDS[1], HOLIDAY_COORDS[2], HOLIDAY_COORDS[3], HOLIDAY_COORDS[4])
        art:Fill(self, 12, 13, 11, 11)
        art:SetAlpha(0.4)

        self._text = CalendarScrollText(self.content, "GameFontHighlightLeft")
        self._text:SetSize(270, 278)
        self._text:AlignParentTopLeft(30, 15)

        self.closeButton.OnClick = function() window:CloseEvent() end
    end;

    ShowEvent = function(self, event)
        self:SetTitle(event.title)
        local start, stop = event.startTime, event.endTime
        self._text:SetText(CALENDAR_HOLIDAYFRAME_BEGINSENDS:format(event.description,
            FormatShortDate(start.monthDay, start.month), Style:FormatTime(start.hour, start.minute),
            FormatShortDate(stop.monthDay, stop.month), Style:FormatTime(stop.hour, stop.minute)))
    end;
}


-- ---------------------------------------------------------------------
-- CalendarRaidPanel: a raid lockout, from C_Calendar.GetRaidInfo.
-- ---------------------------------------------------------------------
class "CalendarRaidPanel" : extends "CalendarDialog" {
    __init = function(self, window)
        CalendarDialog.__init(self, window, "MUI_CalendarViewRaidFrame", 320, 150)
        self:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, PANEL_Y)

        self._text = CalendarScrollText(self.content, "GameFontHighlightLeft")
        self._text:SetSize(270, 108)
        self._text:AlignParentTopLeft(30, 15)

        self.closeButton.OnClick = function() window:CloseEvent() end
    end;

    ShowRaid = function(self, info)
        local name = GetDungeonNameWithDifficulty(info.name, "")
        self:SetTitle(name)
        self._text:SetText(CALENDAR_RAID_LOCKOUT_DESCRIPTION:format(name, Style:FormatTime(info.time.hour, info.time.minute)))
    end;
}


-- ---------------------------------------------------------------------
-- CalendarRsvpButton: a reply button of the view panel, glowing while the
-- invite is still unanswered (retail's CalendarViewEventRSVPButtonTemplate).
-- ---------------------------------------------------------------------
class "CalendarRsvpButton" : extends "CalendarButton" {
    __init = function(self, parent, text, tooltip)
        CalendarButton.__init(self, parent, text, tooltip)
        self:SetSize(128, 22)

        self.glow = Style:Art(self, "OVERLAY", "Interface\\Buttons\\UI-Panel-Button-Glow", nil, nil, 0, 0.75, 0, 0.609375)
        self.glow:SetBlendMode("ADD")
        self.glow:Fill(self, -11, -7, -11, -7)
        self.glow:Hide()
    end;
}


-- ---------------------------------------------------------------------
-- CalendarViewEventPanel
-- ---------------------------------------------------------------------
local RSVP_W, SIGNUP_W = 128, 94
local LIST_H, SIGNUP_LIST_H = 230, 250
local FLASH_TIME = 0.7

class "CalendarViewEventPanel" : extends "CalendarDialog" {
    __init = function(self, window)
        CalendarDialog.__init(self, window, "MUI_CalendarViewEventFrame", 320, 500)
        self.window = window
        self:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, PANEL_Y)

        self:_BuildHeader()

        -- The description, in a dark box.
        local box = Frame("Frame", self.content, nil, "TooltipBackdropTemplate")
        box:SetSize(287, 65)
        box:AlignParentTopLeft(95, 16)
        box:SetBackdropColor(0, 0, 0, 0.9)
        self._description = CalendarScrollText(box, "GameFontNormalSmallLeft")
        self._description:Fill(box, 4, 4, 23, 3)

        -- The replies and the invite list.
        local section = Frame("Frame", self.content)
        section:SetSize(320, 320)
        section:AlignParentTopLeft(170, 0)
        self._section = section

        self._divider = Style:Art(section, "BORDER", "Interface\\DialogFrame\\UI-DialogBox-Divider", 303, 16, 0, 0.75390625, 0, 0.5)

        self._accept = CalendarRsvpButton(section, ACCEPT, CALENDAR_TOOLTIP_AVAILABLEBUTTON)
        self._accept.OnClick = function()
            if self._inviteType == Enum.CalendarInviteType.Signup then
                C_Calendar.EventSignUp()
            else
                C_Calendar.EventAvailable()
            end
        end
        self._tentative = CalendarRsvpButton(section, CALENDAR_VIEW_EVENT_TENTATIVE, CALENDAR_TOOLTIP_TENTATIVEBUTTON)
        self._tentative.OnClick = function() C_Calendar.EventTentative() end
        self._decline = CalendarRsvpButton(section, DECLINE, CALENDAR_TOOLTIP_DECLINEBUTTON)
        self._decline.OnClick = function() C_Calendar.EventDecline() end
        self._remove = CalendarRsvpButton(section, CALENDAR_VIEW_EVENT_REMOVE, CALENDAR_TOOLTIP_REMOVEBUTTON)
        self._remove.OnClick = function() C_Calendar.RemoveEvent() end

        self.inviteList = CalendarInviteList(section, self)

        self.classTotals = CalendarClassTotals(self)
        self.classTotals:SetPoint("TOPLEFT", self, "TOPRIGHT", -4, -30)

        -- Unanswered: the reply buttons glow, in and out.
        local flash = 0
        self:SetScript("OnUpdate", function(_, elapsed)
            if not self._accept.glow:IsShown() then return end
            flash = (flash + elapsed) % (FLASH_TIME * 2)
            local alpha = flash < FLASH_TIME and flash / FLASH_TIME or 2 - flash / FLASH_TIME
            self._accept.glow:SetAlpha(alpha)
            self._tentative.glow:SetAlpha(alpha)
            self._decline.glow:SetAlpha(alpha)
        end)

        self.closeButton.OnClick = function() window:CloseEvent() end
    end;

    -- The icon, title and the lines under it; hovering shows them all when
    -- one is cut short.
    _BuildHeader = function(self)
        local header = Frame("Frame", self.content)
        header:SetSize(320, 100)
        header:AlignParentTopLeft()
        header:EnableMouse(true)

        self._icon = Texture(header, nil, "BORDER")
        self._icon:SetSize(60, 60)
        self._icon:AlignParentTopLeft(26, 16)

        local function line(font, width)
            local fs = Style:Label(header, font, "BACKGROUND")
            fs:SetJustifyH("LEFT")
            if width then fs:SetSize(width, 12) end
            return fs
        end
        self._title = line("GameFontNormal", 220)
        self._title:SetPoint("TOPLEFT", self._icon, "TOPRIGHT", 2, 0)
        self._community = line("GameFontNormalSmall", 220)
        self._community:SetPoint("TOPLEFT", self._title, "BOTTOMLEFT")
        self._type = line("GameFontNormalSmall", 220)
        self._creator = line("GameFontNormalSmall", 220)
        self._creator:SetPoint("TOPLEFT", self._type, "BOTTOMLEFT")
        self._date = line("GameFontHighlightSmall")
        self._date:SetPoint("TOPLEFT", self._creator, "BOTTOMLEFT")
        self._time = line("GameFontHighlightSmall")
        self._time:SetPoint("TOPLEFT", self._date, "BOTTOMLEFT")

        local lines = { self._title, self._community, self._type, self._creator, self._date, self._time }
        header:SetScript("OnEnter", function()
            local cut = false
            for _, fs in ipairs(lines) do
                if fs:IsShown() and fs:IsTruncated() then cut = true end
            end
            if not cut then return end
            MUI_Tooltip:ShowFor(header, "ANCHOR_RIGHT", function(tooltip)
                tooltip:AddLine(self._title:GetText(), 1, 0.82, 0, false, 13)
                for i = 2, #lines do
                    local fs = lines[i]
                    if fs:IsShown() then
                        local color = (fs == self._date or fs == self._time) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
                        tooltip:AddLine(fs:GetText(), color.r, color.g, color.b)
                    end
                end
            end)
        end)
        header:SetScript("OnLeave", function() MUI_Tooltip:Hide() end)
    end;

    -- Retail's CalendarViewEventFrame_Update.
    Update = function(self)
        local info = C_Calendar.GetEventInfo()
        if not info or not info.title then
            self.window:HideEventPanel(self)
            return
        end
        self._inviteType = info.inviteType

        local dungeon = Style:Dungeon(info.textureIndex, info.eventType)
        if dungeon then
            self._type:SetText(CALENDAR_VIEW_EVENTTYPE:format(Style:EventTypeName(info.eventType), GetDungeonNameWithDifficulty(dungeon.title, "")))
            self._icon:SetTexture(dungeon.texture or Style:EventTypeTexture(info.eventType))
        else
            self._type:SetText(Style:EventTypeName(info.eventType))
            self._icon:SetTexture(Style:EventTypeTexture(info.eventType))
        end
        self._creator:SetText(CALENDAR_EVENT_CREATORNAME:format(info.creator ~= "" and info.creator or UNKNOWN))
        self._date:SetText(Style:FullDate(info.time.weekday, info.time.month, info.time.monthDay, info.time.year))
        self._time:SetText(Style:FormatTime(info.time.hour, info.time.minute))
        self._description:SetText(info.description)

        -- A guild event names the guild, in green. Era's API leaves the name
        -- empty (ClassicCalendar's notes): the player's own guild is it.
        self._type:ClearAllPoints()
        if info.calendarType == "GUILD_EVENT" then
            local guild = info.communityName
            if not guild or guild == "" then guild = GetGuildInfo("player") end
            self._community:SetText(guild or "")
            self._community:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
            self._community:Show()
            self._type:SetPoint("TOPLEFT", self._community, "BOTTOMLEFT")
        else
            self._community:Hide()
            self._type:SetPoint("TOPLEFT", self._title, "BOTTOMLEFT")
        end

        local gold = NORMAL_FONT_COLOR
        if info.isLocked then
            self._title:SetText(CALENDAR_VIEW_EVENTTITLE_LOCKED:format(info.title))
            self._icon:SetDesaturated(true)
            gold = GRAY_FONT_COLOR
        else
            self._title:SetText(info.title)
            self._icon:SetDesaturated(false)
        end
        self._type:SetTextColor(gold.r, gold.g, gold.b)
        self._creator:SetTextColor(gold.r, gold.g, gold.b)
        self._description:SetTextColor(gold)

        self:SetTitle(info.calendarType == "GUILD_EVENT" and CALENDAR_VIEW_GUILD_EVENT or CALENDAR_VIEW_EVENT)
        self:_UpdateReplies(info)
        self:UpdateInvites()
    end;

    -- Retail's CalendarViewEventRSVP_Update and _SetEventButtons: a sign-up
    -- event takes Sign Up / Tentative / Remove, any other Accept / Tentative /
    -- Decline over Remove; only an event today or later can be answered.
    _UpdateReplies = function(self, info)
        local signup = (info.calendarType == "GUILD_EVENT" or info.calendarType == "COMMUNITY_EVENT")
                       and info.inviteType == Enum.CalendarInviteType.Signup
        local accept, tentative, decline, remove = self._accept, self._tentative, self._decline, self._remove
        for _, button in ipairs({ accept, tentative, decline, remove }) do button:ClearAllPoints() end

        if signup then
            accept:SetText(CALENDAR_SIGNUP)
            accept.tooltip = CALENDAR_TOOLTIP_SIGNUPBUTTON
            remove.tooltip = CALENDAR_TOOLTIP_REMOVESIGNUPBUTTON
            for _, button in ipairs({ accept, tentative, remove }) do button:SetWidth(SIGNUP_W) end
            accept:AlignParentTopLeft(0, 14)
            tentative:AlignParentTop()
            remove:AlignParentTopRight(0, 14)
            decline:Hide()
            self._divider:ClearAllPoints()
            self._divider:AlignParentTopLeft(30, 10)
            self.inviteList:ClearAllPoints()
            self.inviteList:AlignParentTop(60)
            self.inviteList:SetHeight(SIGNUP_LIST_H)
        else
            accept:SetText(ACCEPT)
            accept.tooltip = CALENDAR_TOOLTIP_AVAILABLEBUTTON
            remove.tooltip = CALENDAR_TOOLTIP_REMOVEBUTTON
            for _, button in ipairs({ accept, tentative, decline, remove }) do button:SetWidth(RSVP_W) end
            accept:SetPoint("TOPRIGHT", self._section, "TOP", -10, 4)
            tentative:SetPoint("TOPLEFT", self._section, "TOP", 10, 4)
            decline:SetPoint("TOPRIGHT", self._section, "TOP", -10, -26)
            remove:SetPoint("TOPLEFT", self._section, "TOP", 10, -26)
            decline:Show()
            self._divider:ClearAllPoints()
            self._divider:AlignParentTopLeft(50, 10)
            self.inviteList:ClearAllPoints()
            self.inviteList:AlignParentTop(80)
            self.inviteList:SetHeight(LIST_H)
        end

        local open = not info.isLocked and self.window:IsTodayOrLater(info.time.month, info.time.monthDay, info.time.year)
        local status = info.inviteStatus
        local glow = false
        if signup then
            local notSigned = status == Enum.CalendarStatus.NotSignedup
            accept:SetEnabled(open and notSigned)
            tentative:SetEnabled(open and notSigned)
            remove:SetEnabled(open and not notSigned)
        else
            local canReply = open and (status == Enum.CalendarStatus.Invited or status == Enum.CalendarStatus.Available
                or status == Enum.CalendarStatus.Declined or status == Enum.CalendarStatus.Signedup
                or status == Enum.CalendarStatus.NotSignedup or status == Enum.CalendarStatus.Tentative)
            accept:SetEnabled(canReply and status ~= Enum.CalendarStatus.Available)
            tentative:SetEnabled(canReply and status ~= Enum.CalendarStatus.Tentative)
            decline:SetEnabled(canReply and status ~= Enum.CalendarStatus.Declined)
            remove:SetEnabled(true)
            glow = canReply and info.hasPendingInvite
        end
        accept.glow:SetVisible(glow)
        tentative.glow:SetVisible(glow)
        decline.glow:SetVisible(glow)
    end;

    UpdateInvites = function(self)
        self.inviteList:Update(self.classTotals)
    end;

    -- Right-clicking the player's own line while the invite is unanswered
    -- sets their status (retail's CalendarViewEventInviteListButton_OnClick).
    ClickInvite = function(self, row, mouseButton)
        if mouseButton ~= "RightButton" or not row.info.inviteIsMine or not C_Calendar.EventHasPendingInvite() then
            return
        end
        local items = {}
        for _, option in ipairs(C_Calendar.EventGetStatusOptions(row.inviteIndex)) do
            items[#items + 1] = { type = "text", label = _G[option.statusString], OnClick = function()
                C_Calendar.EventSetInviteStatus(row.inviteIndex, option.status)
            end }
        end
        self.window:ShowMenu(row, { { type = "submenu", label = CALENDAR_INVITELIST_SETINVITESTATUS, items = items } })
    end;
}


-- ---------------------------------------------------------------------
-- CalendarEventPicker: retail's CalendarEventPickerFrame — every event of a
-- day with more than four, beside that day.
-- ---------------------------------------------------------------------
class "CalendarPickerRow" : extends "Button" {
    __init = function(self, parent, width)
        Button.__init(self, parent)
        self:SetSize(width, 16)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar"):SetBlendMode("ADD")

        self.icon = Texture(self, nil, "BORDER")
        self.icon:SetSize(16, 16)
        self.icon:AlignParentLeft()
        self.time = Style:Label(self, "GameFontHighlight", "BORDER")
        self.time:SetJustifyH("RIGHT")
        self.time:AlignParentRight()
        self.title = Style:Label(self, "GameFontNormal", "BORDER")
        self.title:SetJustifyH("LEFT")
    end;
}

class "CalendarEventPicker" : extends "CalendarDialog" {
    __init = function(self, window)
        CalendarDialog.__init(self, window, "MUI_CalendarEventPickerFrame", 290, 226, CALENDAR_EVENT_PICKER_TITLE)
        self.window = window
        self:SetFrameStrata("DIALOG")
        self:SetClampedToScreen(true)
        self.closeButton:Hide()

        self._list = CalendarList(self.content, 16, function(content)
            local row = CalendarPickerRow(content, 235)
            row.OnClick = function(_, mouseButton) self:_Click(row, mouseButton) end
            row:SetScript("OnDoubleClick", function()
                self:_Click(row, "LeftButton")
                self:Close()
            end)
            return row
        end)
        self._list:SetSize(235, 163)
        self._list:AlignParentTopLeft(26, 20)
        self._list.bar:SetPoint("TOPLEFT", self._list, "TOPRIGHT", 9, 9)
        self._list.bar:SetPoint("BOTTOMLEFT", self._list, "BOTTOMRIGHT", 9, 5)

        Style:ButtonStrip(self.content)
        local close = CalendarButton(self.content, CLOSE)
        close:AlignParentBottomRight(12, 11)
        Style:ButtonBorder(close)
        close.OnClick = function() self:Close() end
    end;

    -- Toggled from a day's arrow; it opens to the day's right, or left from
    -- the end of the week.
    Toggle = function(self, dayButton)
        if self:IsShown() then
            self:Close()
            return
        end
        self.dayButton = dayButton
        self:ClearAllPoints()
        if (dayButton.index - 1) % 7 + 1 > 4 then
            self:SetPoint("TOPRIGHT", dayButton, "TOPLEFT")
        else
            self:SetPoint("TOPLEFT", dayButton, "TOPRIGHT")
        end
        self:Show()
        self.window:PushModal(self)
        self:Update()
    end;

    Close = function(self)
        if not self:IsShown() then return end
        self.dayButton = nil
        self:Hide()
        self.window:PopModal(self)
    end;

    -- Retail lists every event but the ongoing ones; gone back under five,
    -- the day shows them all itself.
    Update = function(self)
        local day = self.dayButton
        if not day or day.numViewableEvents <= 4 then
            self:Close()
            return
        end
        local events = {}
        for _, event in ipairs(day.events) do
            if event.sequenceType ~= "ONGOING" then events[#events + 1] = event end
        end
        self._list:SetCount(#events, function(row, i)
            local event = events[i]
            row.event = event
            if event.iconTexture then
                row.icon:SetTexture(event.iconTexture)
                if event.calendarType == "HOLIDAY" then
                    row.icon:SetTexCoord(HOLIDAY_COORDS[1], HOLIDAY_COORDS[2], HOLIDAY_COORDS[3], HOLIDAY_COORDS[4])
                else
                    row.icon:SetTexCoord(0, 1, 0, 1)
                end
                row.icon:Show()
            else
                row.icon:Hide()
            end
            row.title:ClearAllPoints()
            if row.icon:IsShown() then
                row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT")
            else
                row.title:AlignParentTopLeft()
            end
            if event.calendarType == "HOLIDAY" then
                row.time:Hide()
                row.title:AlignParentBottomRight()
            else
                local date = event.sequenceType == "END" and event.endTime or event.startTime
                row.time:SetText(Style:FormatTime(date.hour, date.minute))
                row.time:Show()
                row.title:SetPoint("BOTTOMRIGHT", row.time, "BOTTOMLEFT")
            end
            row.title:SetText(Style:EventTitle(event))
            local color = Style:EventColor(event)
            row.title:SetTextColor(color.r, color.g, color.b)
            if self.window:IsEventSelected(day, event) then row:LockHighlight() else row:UnlockHighlight() end
        end)
    end;

    _Click = function(self, row, mouseButton)
        if mouseButton == "RightButton" then
            self.window:ShowDayMenu(self.dayButton, row.event, row)
            return
        end
        self.window:OpenEvent(self.dayButton, row.event)
        self:Update()
    end;
}


-- ---------------------------------------------------------------------
-- CalendarTexturePicker: retail's CalendarTexturePickerFrame — the
-- dungeons or raids an event can be for, under a header per expansion.
-- ---------------------------------------------------------------------
class "CalendarTexturePicker" : extends "CalendarDialog" {
    __init = function(self, window)
        CalendarDialog.__init(self, window, "MUI_CalendarTexturePickerFrame", 290, 286)
        self.window = window
        self:SetFrameStrata("DIALOG")
        self:AlignParentTopRight(24, 0)
        self.closeButton:Hide()

        self._list = CalendarList(self.content, 16, function(content)
            local row = CalendarPickerRow(content, 240)
            row.icon:SetTexCoord(0, 0.796875, 0, 0.71875)
            row.title:SetWidth(224)
            row.title:SetHeight(16)
            row.title:RightOf(row.icon)
            row.OnClick = function() self:_Select(row) end
            row:SetScript("OnDoubleClick", function()
                self:_Select(row)
                self:_Accept()
            end)
            return row
        end)
        self._list:SetSize(239, 224)
        self._list:AlignParentTopLeft(26, 20)
        self._list.bar:SetPoint("TOPLEFT", self._list, "TOPRIGHT", 5, 9)
        self._list.bar:SetPoint("BOTTOMLEFT", self._list, "BOTTOMRIGHT", 5, 5)

        Style:ButtonStrip(self.content)
        local cancel = CalendarButton(self.content, CANCEL)
        cancel:AlignParentBottomRight(12, 11)
        Style:ButtonBorder(cancel)
        cancel.OnClick = function() self:Close() end
        local accept = CalendarButton(self.content, ACCEPT)
        accept:LeftOf(cancel, 3)
        Style:ButtonBorder(accept)
        accept.OnClick = function() self:_Accept() end
    end;

    -- `onAccept(textureIndex, eventType)` takes the choice.
    Open = function(self, eventType, selected, onAccept)
        self._eventType = eventType
        self._selected = selected
        self._onAccept = onAccept
        self:SetTitle(eventType == Enum.CalendarEventType.Raid and CALENDAR_TEXTURE_PICKER_TITLE_RAID or CALENDAR_TEXTURE_PICKER_TITLE_DUNGEON)
        if not self:IsShown() then
            self:Show()
            self.window:PushModal(self)
        end
        self._list:ScrollToTop()
        self:_Update()
    end;

    Close = function(self)
        if not self:IsShown() then return end
        self:Hide()
        self.window:PopModal(self)
    end;

    _Update = function(self)
        local entries = Style:Dungeons(self._eventType)
        self._list:SetCount(#entries, function(row, i)
            local entry = entries[i]
            row.textureIndex = entry.textureIndex
            row.title:ClearAllPoints()
            if entry.textureIndex then
                row.title:SetText(GetDungeonNameWithDifficulty(entry.title, ""))
                row.title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                row.title:RightOf(row.icon)
                row.icon:SetTexture(entry.texture or Style:EventTypeTexture(self._eventType))
                row.icon:Show()
                row.title:Show()
                row:Enable()
            elseif entry.header then
                row.title:SetText(entry.header)
                row.title:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                row.title:AlignLeft(row.icon)
                row.icon:Hide()
                row.title:Show()
                row:Disable()
            else
                row.icon:Hide()
                row.title:Hide()
                row:Disable()
            end
            if entry.textureIndex and entry.textureIndex == self._selected then row:LockHighlight() else row:UnlockHighlight() end
        end)
    end;

    _Select = function(self, row)
        self._selected = row.textureIndex
        self:_Update()
    end;

    _Accept = function(self)
        if self._selected then
            self._onAccept(self._selected, self._eventType)
        end
        self:Close()
    end;
}
