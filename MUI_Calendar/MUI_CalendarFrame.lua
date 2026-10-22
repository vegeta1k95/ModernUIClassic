-- MUI_CalendarFrame: the calendar window — retail's CalendarFrame (659x624,
-- its own stone and metal art, the month on a plate at the top, a grid of
-- seven by six days) at nine tenths, and everything it opens.
--
-- A window of our own: Era loads no calendar to keep (it ships its UI
-- without one), so it opens and closes in combat too, and Escape closes it
-- through UISpecialFrames — the whole window, panels and all.
--
-- C_Calendar holds the month on view (SetAbsMonth / SetMonth) and answers
-- for the player's events, guild events and raid lockouts by month offset
-- from it; the holidays come from MUI_CalendarHolidays. The filters
-- (MUI_DB.settings.calendar.filters) hide either kind.
--
--   CalendarWindow()
--     :Toggle()
--     :Update()            the month on view, again

local L = MUI.L

local Style = MUI_CalendarStyle
local S = Style.S
local DARK = CalendarDayButton.DARK

local MAX_DAYS = 42
local CELL = 91
local GRID_X, GRID_Y = 12, 74          -- the first day, under the first weekday
local WEEKDAY_W = 90 / 256 - 0.001
local WEEKDAY_TOP, WEEKDAY_H = 180 / 256, 28 / 256 - 0.001
local TODAY_FADE = 1.5

-- Monday first where retail's Blizzard_Calendar localization says so;
-- Era's constant is Sunday for every locale.
local FIRST_WEEKDAY = ({ deDE = 2, enGB = 2, esES = 2, frFR = 2, itIT = 2, ruRU = 2 })[GetLocale()] or CALENDAR_FIRST_WEEKDAY

local MONTH_NAMES = {
    MONTH_JANUARY, MONTH_FEBRUARY, MONTH_MARCH, MONTH_APRIL, MONTH_MAY, MONTH_JUNE,
    MONTH_JULY, MONTH_AUGUST, MONTH_SEPTEMBER, MONTH_OCTOBER, MONTH_NOVEMBER, MONTH_DECEMBER,
}

local FILTERS = {
    { key = "holidays",      label = L.CALENDAR_FILTER_HOLIDAYS },
    { key = "darkmoon",      label = CALENDAR_FILTER_DARKMOON },
    { key = "lockouts",      label = CALENDAR_FILTER_RAID_LOCKOUTS },
    { key = "weekly",        label = CALENDAR_FILTER_WEEKLY_HOLIDAYS },
    { key = "battlegrounds", label = L.CAL_BATTLEGROUND_WEEKENDS },
}

local POPUP_DELETE = "MUI_CALENDAR_DELETE_EVENT"
local POPUP_ERROR  = "MUI_CALENDAR_ERROR"

StaticPopupDialogs[POPUP_DELETE] = {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function() C_Calendar.ContextMenuEventRemove() end,
    whileDead = 1,
    timeout = 0,
    hideOnEscape = 1,
    enterClicksFirstButton = 1,
}
StaticPopupDialogs[POPUP_ERROR] = {
    text = CALENDAR_ERROR,
    button1 = OKAY,
    whileDead = 1,
    timeout = 0,
    showAlert = 1,
    hideOnEscape = 1,
    enterClicksFirstButton = 1,
}

-- The weekday of grid column `index` (retail's _CalendarFrame_GetWeekdayIndex).
local function WeekdayOf(index)
    return (index - 2 + FIRST_WEEKDAY) % 7 + 1
end

class "CalendarWindow" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_CalendarFrame")
        self:SetSize(659, 624)
        self:SetScale(S)
        self:AlignParentTopLeft(84 / S, 16 / S)
        self:SetFrameStrata("HIGH")
        self:SetToplevel(true)
        self:EnableMouse(true)
        self:EnableMouseWheel(true)
        self:Hide()
        tinsert(UISpecialFrames, "MUI_CalendarFrame")

        self.militaryTime = GetCVarBool("timeMgrUseMilitaryTime")
        self._modals = {}

        self:_BuildArt()
        self:_BuildTitle()
        self:_BuildDays()
        self:_BuildToday()
        self:_BuildFilter()

        local close = CloseButton(self, "MUI_CalendarFrameClose")
        close:ClearAllPoints()
        close:AlignParentTopRight(17, -1)

        self.holidayPanel  = CalendarHolidayPanel(self)
        self.raidPanel     = CalendarRaidPanel(self)
        self.viewPanel     = CalendarViewEventPanel(self)
        self.createPanel   = CalendarCreateEventPanel(self)
        self.eventPicker   = CalendarEventPicker(self)
        self.texturePicker = CalendarTexturePicker(self)
        self:_BuildModal()

        self._menu = DropdownMenu(self, "MUI_CalendarMenu")
        self._menu:SetMenuWidth(180)

        self:SetScript("OnMouseWheel", function(_, delta)
            local button = delta > 0 and self._prevMonth or self._nextMonth
            if button:IsEnabled() then button:Click() end
        end)
        self:SetScript("OnShow", function() self:_OnShow() end)
        self:SetScript("OnHide", function() self:_OnHide() end)
        self:_RegisterEvents()
    end;

    Toggle = function(self)
        self:SetVisible(not self:IsShown())
    end;

    -- ---- building ------------------------------------------------------

    -- Retail's frame art: the top, the sides, the bottom, each piece where
    -- its anchors chain it from the top left corner.
    _BuildArt = function(self)
        local function piece(file, w, h, top, left, l, r, t, b)
            local texture = Style:Art(self, "BORDER", file, w, h, l, r, t, b)
            texture:AlignParentTopLeft(top, left)
        end
        piece("CalendarFrame_TopAndBottom", 256, 46, 0, 0,   0, 1, 0.00390625, 0.16015625)
        piece("CalendarFrame_TopAndBottom", 256, 46, 0, 256, 0, 1, 0.16796875, 0.32421875)
        piece("CalendarFrame_TopAndBottom", 147, 30, 16, 512, 0, 0.57421875, 0.328125, 0.4296875)
        piece("CalendarFrame_Sides", 12, 256, 46, 0,  0, 0.09375, 0, 1)
        piece("CalendarFrame_Sides", 12, 256, 302, 0, 0.09375, 0.1875, 0, 1)
        piece("CalendarFrame_Sides", 11, 62, 558, 2,  0.1953125, 0.28125, 0, 0.2421875)
        piece("CalendarFrame_Sides", 13, 256, 46, 646,  0.296875, 0.3984375, 0, 1)
        piece("CalendarFrame_Sides", 11, 256, 302, 648, 0.3984375, 0.484375, 0, 1)
        piece("CalendarFrame_Sides", 11, 62, 558, 648,  0.484375, 0.5703125, 0, 0.2421875)
        piece("CalendarFrame_TopAndBottom", 256, 9, 620, 2,   0, 1, 0.43359375, 0.46875)
        piece("CalendarFrame_TopAndBottom", 256, 9, 620, 258, 0, 1, 0.46875, 0.50390625)
        piece("CalendarFrame_TopAndBottom", 145, 9, 620, 514, 0, 0.56640625, 0.50390625, 0.5390625)

        -- The weekday names on their strips, in alternating cuts.
        self._weekdays = {}
        for i = 1, 7 do
            local left = (i % 2) * WEEKDAY_W
            local strip = Style:Art(self, "BACKGROUND", "CalendarBackground", CELL, 28,
                left, left + WEEKDAY_W, WEEKDAY_TOP, WEEKDAY_TOP + WEEKDAY_H)
            strip:AlignParentTopLeft(46, GRID_X + (i - 1) * CELL)
            local name = Style:Label(self, "GameFontNormal", "BACKGROUND")
            name:SetTextColor(1, 1, 0.604)
            name:CenterAt(strip)
            self._weekdays[i] = { strip = strip, name = name }
        end
        self._weekdaySelected = Style:Art(self, "ARTWORK", "Highlights", 85, 21, 0, 0.33203125, 0.6953125, 0.859375)
        self._weekdaySelected:SetBlendMode("ADD")
        self._weekdaySelected:Hide()
    end;

    -- The month and the year on their plates, the arrows either side.
    _BuildTitle = function(self)
        local plate = Style:Art(self, "OVERLAY", "CalendarBackground", 142, 36, 0, 0.5546875, 0.828125, 0.96875)
        plate:AlignParentTop(1, -3)
        self._monthName = Style:Label(self, "GameFontHighlightLarge")
        self._monthName:CenterAt(plate)

        local yearPlate = Style:Art(self, "ARTWORK", "CalendarBackground", 47, 24, 0, 0.5546875, 0.828125, 0.96875)
        yearPlate:Below(plate, -13, -2)
        self._yearName = Style:Label(self, "GameFontNormalSmall")
        self._yearName:CenterAt(yearPlate, 0, -1)

        local function arrow(name, offset)
            local button = Button(self)
            button:SetSize(32, 32)
            button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Up")
            button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Down")
            button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Disabled")
            button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight"):SetBlendMode("ADD")
            button:SetClickSound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
            button.OnClick = function() self:OffsetMonth(offset) end
            return button
        end
        self._prevMonth = arrow("PrevPage", -1)
        self._prevMonth:LeftOf(plate, 0, -1)
        self._nextMonth = arrow("NextPage", 1)
        self._nextMonth:RightOf(plate, 0, -1)
    end;

    _BuildDays = function(self)
        self.days = {}
        for i = 1, MAX_DAYS do
            local day = CalendarDayButton(self, i)
            day:AlignParentTopLeft(GRID_Y + math.floor((i - 1) / 7) * CELL, GRID_X + (i - 1) % 7 * CELL)
            self.days[i] = day
        end
        -- The corner that joins the last day of a month ending mid-week to
        -- the shading of the days after it.
        self._lastDayDark = Style:Art(self, "ARTWORK", "CalendarShadows", 3, 3, 0, 0.004859375, 0.90234375, 0.9140625)
        self._lastDayDark:Hide()
    end;

    -- Today's ring and its glow, pulsing in and out.
    _BuildToday = function(self)
        local today = Frame("Frame", self)
        today:SetSize(145, 140)
        today:Hide()
        local ring = Style:Art(today, "BORDER", "CurrentDay", 145, 140, 0.0078125, 0.57421875, 0.0390625, 0.5859375)
        ring:CenterInParent()
        local glow = Style:Art(today, "OVERLAY", "CurrentDay", 112, 130, 0.5625, 1, 0, 0.5078125)
        glow:SetBlendMode("ADD")
        glow:CenterInParent(2, 15)
        local timer, fadeIn = 0, true
        today:SetScript("OnUpdate", function(_, elapsed)
            timer = timer + elapsed
            if timer >= TODAY_FADE then
                timer, fadeIn = 0, not fadeIn
            end
            glow:SetAlpha(fadeIn and timer / TODAY_FADE or 1 - timer / TODAY_FADE)
        end)
        self._today = today
    end;

    _BuildFilter = function(self)
        local button = DropdownSimple(self, "MUI_CalendarFilter")
        button:SetSize(106, 22)
        button:AlignParentTopRight(20, 27)
        button:SetText(CALENDAR_FILTERS)

        local filters = MUI_DB.settings.calendar.filters
        local menu = DropdownMenu(button, "MUI_CalendarFilterMenu", button)
        menu:SetMenuWidth(190)
        local items = {}
        for _, filter in ipairs(FILTERS) do
            items[#items + 1] = { type = "checkbox", label = filter.label, checked = filters[filter.key], OnChanged = function(_, checked)
                filters[filter.key] = checked
                self:Update()
            end }
        end
        menu:SetItems(items)
        button.OnClick = function() menu:Toggle() end
        self._filter = button
    end;

    -- What a dialog waiting for an answer dims: the grid, and the side
    -- panel open; both take the clicks meant for what is under them.
    _BuildModal = function(self)
        local function shade(alpha)
            local frame = Frame("Frame", self)
            frame:EnableMouse(true)
            frame:Hide()
            local texture = Texture(frame, nil, "BACKGROUND")
            texture:FillParent()
            texture:SetColorTexture(0, 0, 0, alpha)
            return frame
        end
        self._gridShade = shade(0.6)
        self._gridShade:SetPoint("TOPLEFT", self.days[1], "TOPLEFT")
        self._gridShade:SetPoint("BOTTOMRIGHT", self.days[MAX_DAYS], "BOTTOMRIGHT")
        self._gridShade:SetFrameLevel(self.days[1]:GetFrameLevel() + 10)
        self._panelShade = shade(0.5)
    end;

    _RegisterEvents = function(self)
        self:RegisterEventHandler("CALENDAR_UPDATE_EVENT_LIST", function()
            if not self:IsShown() then return end
            self:Update()
            if self.eventPicker:IsShown() then self.eventPicker:Update() end
        end)
        self:RegisterEventHandler("CALENDAR_OPEN_EVENT", function(_, _, calendarType)
            if self:IsShown() then self:_OnOpenEvent(calendarType) end
        end)
        self:RegisterEventHandler("CALENDAR_CLOSE_EVENT", function()
            self:HideEventPanel(self.viewPanel)
            self:HideEventPanel(self.createPanel)
        end)
        self:RegisterEventHandler("CALENDAR_NEW_EVENT", function(_, _, isCopy)
            -- The event made shows on the calendar; the panel that made it closes.
            if not isCopy then self:HideEventPanel(self.createPanel) end
        end)
        self:RegisterEventHandler("CALENDAR_UPDATE_EVENT", function() self:_OnEventChanged(false) end)
        self:RegisterEventHandler("CALENDAR_UPDATE_INVITE_LIST", function() self:_OnEventChanged(true) end)
        self:RegisterEventHandler("GUILD_ROSTER_UPDATE", function() self:_OnPermissionsChanged() end)
        self:RegisterEventHandler("PLAYER_GUILD_UPDATE", function() self:_OnPermissionsChanged() end)
        self:RegisterEventHandler("CALENDAR_UPDATE_ERROR", function(_, _, message)
            StaticPopup_Show(POPUP_ERROR, _G[message] or message)
        end)
        self:RegisterEventHandler("CALENDAR_UPDATE_ERROR_WITH_COUNT", function(_, _, message, count)
            StaticPopup_Show(POPUP_ERROR, (_G[message] or message):format(count))
        end)
        self:RegisterEventHandler("CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME", function(_, _, message, name)
            StaticPopup_Show(POPUP_ERROR, (_G[message] or message):format(name))
        end)
        -- The clock between 12 and 24 hours.
        self:RegisterEventHandler("CVAR_UPDATE", function()
            local military = GetCVarBool("timeMgrUseMilitaryTime")
            if military == self.militaryTime then return end
            self.militaryTime = military
            if not self:IsShown() then return end
            self:Update()
            if self._eventPanel == self.createPanel then
                self.createPanel:UpdateTimeFormat(military)
            elseif self._eventPanel == self.viewPanel then
                self.viewPanel:Update()
            end
            if self.eventPicker:IsShown() then self.eventPicker:Update() end
        end)
    end;

    -- ---- showing -------------------------------------------------------

    -- Retail's CalendarFrame_OnShow: today's month, the server asked for
    -- the events.
    _OnShow = function(self)
        self:CloseEvent()
        self.militaryTime = GetCVarBool("timeMgrUseMilitaryTime")
        local now = C_DateAndTime.GetCurrentCalendarTime()
        C_Calendar.SetAbsMonth(now.month, now.year)
        self:Update()
        C_Calendar.OpenCalendar()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
    end;

    _OnHide = function(self)
        self:CloseEvent()
        self.eventPicker:Close()
        self.texturePicker:Close()
        self.createPanel.massInvite:Close()
        StaticPopup_Hide(POPUP_DELETE)
        StaticPopup_Hide(POPUP_ERROR)
        self._menu:Close()
        wipe(self._modals)
        self:_UpdateModal()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
    end;

    -- Retail's CalendarFrame_Update: the days of the month before that share
    -- the first week, the month, then the next one's to fill six weeks; the
    -- days around the month in shade that joins up at its corners.
    Update = function(self)
        local now = C_DateAndTime.GetCurrentCalendarTime()
        local before, month, after = C_Calendar.GetMonthInfo(-1), C_Calendar.GetMonthInfo(0), C_Calendar.GetMonthInfo(1)
        self.viewedMonth, self.viewedYear = month.month, month.year
        self._monthName:SetText(MONTH_NAMES[month.month])
        self._yearName:SetText(month.year)
        self:_UpdateMonthButtons()
        for i = 1, 7 do
            self._weekdays[i].name:SetText(CALENDAR_WEEKDAY_NAMES[WeekdayOf(i)])
        end

        self._today:Hide()
        self._weekdaySelected:Hide()
        self._lastDayDark:Hide()
        self:_SetSelectedDayButton(nil)
        self:_RefreshSelectedEvent()
        self._selectedEventButton = nil

        local index = 1
        local function show(day, offset, info, darkTop, darkBottom)
            local button = self.days[index]
            button:SetDate(day, offset, darkTop, darkBottom)
            button:SetEvents(self:GetDayEvents(offset, day), C_Calendar.GetFirstPendingInvite(offset, day) ~= nil)
            local selected = self.selectedDate
            if selected and selected.year == info.year and selected.month == info.month and selected.day == day then
                self:_SetSelectedDayButton(button)
            end
            if now.year == info.year and now.month == info.month and now.monthDay == day then
                self:_SetToday(button)
            end
            self:_HighlightSelectedEvent(button)
            index = index + 1
        end

        local lead = (month.firstWeekday - FIRST_WEEKDAY) % 7
        for i = 1, lead do
            local top, bottom = DARK.PREV + DARK.TOP, DARK.PREV + DARK.BOTTOM
            if i == 1 then top, bottom = top + DARK.LEFT, bottom + DARK.LEFT end
            if i == lead then top, bottom = top + DARK.RIGHT, bottom + DARK.RIGHT end
            show(before.numDays - lead + i, -1, before, top, bottom)
        end
        for day = 1, month.numDays do
            show(day, 0, month)
        end
        -- A month ending mid-week: the corner piece on its last day.
        if index < 36 and (index - 1) % 7 ~= 0 then
            local last = self.days[index - 1]
            self._lastDayDark:SetParent(last)
            self._lastDayDark:ClearAllPoints()
            self._lastDayDark:AlignParentBottomRight()
            self._lastDayDark:Show()
        end
        local corners = index % 7 ~= 1
        local day = 1
        while index <= MAX_DAYS do
            local top, bottom = DARK.NEXT, DARK.NEXT
            local column = (index - 1) % 7 + 1
            if column == 1 or day == 1 then top, bottom = top + DARK.LEFT, bottom + DARK.LEFT end
            if column == 7 then top, bottom = top + DARK.RIGHT, bottom + DARK.RIGHT end
            if not self.days[index - 7].dark then top = top + DARK.TOP end
            if index + 7 > MAX_DAYS then bottom = bottom + DARK.BOTTOM end
            if corners and (day == 1 or day == 7 or day == 8) then top = top + DARK.CORNER end
            show(day, 1, after, top, bottom)
            day = day + 1
        end

        -- The event open is not on this page: its panel closes, as retail's.
        if not self._selectedEventButton and self._eventPanel and not (self._eventPanel == self.createPanel and self.createPanel.mode == "create") then
            self:CloseEvent()
        end
    end;

    _UpdateMonthButtons = function(self)
        local modal = #self._modals > 0
        local min, max = C_Calendar.GetMinDate(), C_Calendar.GetMaxCreateDate()
        local month, year = self.viewedMonth, self.viewedYear
        self._prevMonth:SetEnabled(not modal and (year > min.year or (year == min.year and month > min.month)))
        self._nextMonth:SetEnabled(not modal and (year < max.year or (year == max.year and month < max.month)))
    end;

    OffsetMonth = function(self, offset)
        C_Calendar.SetMonth(offset)
        StaticPopup_Hide(POPUP_DELETE)
        self.eventPicker:Close()
        self.texturePicker:Close()
        self:Update()
    end;

    -- The day's events: the holidays first, then the server's — the
    -- player's and guild's events and the raid lockouts — each with its
    -- C_Calendar index.
    GetDayEvents = function(self, monthOffset, day)
        local info = C_Calendar.GetMonthInfo(monthOffset)
        local filters = MUI_DB.settings.calendar.filters
        local events = {}
        for _, event in ipairs(MUI_CalendarHolidays:GetDayEvents(info.year, info.month, day)) do
            if filters[event.filter] then events[#events + 1] = event end
        end
        for index = 1, C_Calendar.GetNumDayEvents(monthOffset, day) do
            local event = C_Calendar.GetDayEvent(monthOffset, day, index)
            if event and (event.calendarType ~= "RAID_LOCKOUT" or filters.lockouts) then
                event.index = index
                event.key = "c" .. index
                events[#events + 1] = event
            end
        end
        return events
    end;

    -- ---- days and dates ------------------------------------------------

    FullDateOf = function(self, dayButton)
        local info = C_Calendar.GetMonthInfo(dayButton.monthOffset)
        return Style:FullDate(WeekdayOf(dayButton.index), info.month, dayButton.day, info.year)
    end;

    IsTodayOrLater = function(self, month, day, year)
        local now = C_DateAndTime.GetCurrentCalendarTime()
        if year ~= now.year then return year > now.year end
        if month ~= now.month then return month > now.month end
        return day >= now.monthDay
    end;

    _IsAfterMaxCreateDate = function(self, month, day, year)
        local max = C_Calendar.GetMaxCreateDate()
        if year ~= max.year then return year > max.year end
        if month ~= max.month then return month > max.month end
        return day > max.monthDay
    end;

    SelectDay = function(self, dayButton)
        if self.eventPicker.dayButton and self.eventPicker.dayButton ~= dayButton then
            self.eventPicker:Close()
        end
        local info = C_Calendar.GetMonthInfo(dayButton.monthOffset)
        self.selectedDate = { year = info.year, month = info.month, day = dayButton.day }
        self:_SetSelectedDayButton(dayButton)
    end;

    -- The selected day keeps its highlight; its weekday's strip lights up.
    _SetSelectedDayButton = function(self, dayButton)
        if self.selectedDayButton and self.selectedDayButton ~= dayButton then
            self.selectedDayButton:SetSelected(false)
        end
        self.selectedDayButton = dayButton
        if dayButton then
            dayButton:SetSelected(true)
            self._weekdaySelected:ClearAllPoints()
            self._weekdaySelected:CenterAt(self._weekdays[(dayButton.index - 1) % 7 + 1].strip)
            self._weekdaySelected:Show()
        end
    end;

    _SetToday = function(self, dayButton)
        self._today:SetParent(dayButton)
        self._today:ClearAllPoints()
        self._today:CenterAt(dayButton)
        self._today:SetFrameLevel(dayButton:GetTopLevel())
        self._today:Show()
    end;

    -- ---- events --------------------------------------------------------

    -- A server event open keeps its place through updates by its index.
    _RefreshSelectedEvent = function(self)
        local selected = self._selectedEvent
        if not selected or not selected.server or not C_Calendar.IsEventOpen() then return end
        local index = C_Calendar.GetEventIndex()
        if index and index.eventIndex > 0 then
            local info = C_Calendar.GetMonthInfo(index.offsetMonths)
            self._selectedEvent = { year = info.year, month = info.month, day = index.monthDay, key = "c" .. index.eventIndex, server = true }
        end
    end;

    IsEventSelected = function(self, dayButton, event)
        local selected = self._selectedEvent
        if not selected or selected.key ~= event.key or selected.day ~= dayButton.day then return false end
        local info = C_Calendar.GetMonthInfo(dayButton.monthOffset)
        return selected.year == info.year and selected.month == info.month
    end;

    _HighlightSelectedEvent = function(self, dayButton)
        for _, button in ipairs(dayButton.eventButtons) do
            local selected = button.event ~= nil and self:IsEventSelected(dayButton, button.event)
            button:SetSelected(selected)
            if selected then self._selectedEventButton = button end
        end
    end;

    _SetSelectedEvent = function(self, dayButton, event)
        if self._selectedEventButton then
            self._selectedEventButton:SetSelected(false)
            self._selectedEventButton = nil
        end
        if not event then
            self._selectedEvent = nil
            return
        end
        local info = C_Calendar.GetMonthInfo(dayButton.monthOffset)
        self._selectedEvent = { year = info.year, month = info.month, day = dayButton.day, key = event.key,
                                server = event.calendarType ~= "HOLIDAY" }
        self:_HighlightSelectedEvent(dayButton)
    end;

    -- A holiday shows in our panel; anything else is the server's to open
    -- (CALENDAR_OPEN_EVENT brings its panel).
    OpenEvent = function(self, dayButton, event)
        self:_SetSelectedEvent(dayButton, event)
        if event.calendarType == "HOLIDAY" then
            C_Calendar.CloseEvent()
            self.holidayPanel:ShowEvent(event)
            self:ShowEventPanel(self.holidayPanel)
        else
            C_Calendar.OpenEvent(dayButton.monthOffset, dayButton.day, event.index)
        end
    end;

    _OnOpenEvent = function(self, calendarType)
        if calendarType == "RAID_LOCKOUT" then
            local index = C_Calendar.GetEventIndex()
            local info = index and C_Calendar.GetRaidInfo(index.offsetMonths, index.monthDay, index.eventIndex)
            if info then
                self.raidPanel:ShowRaid(info)
                self:ShowEventPanel(self.raidPanel)
            end
        elseif Style:IsPlayerEvent(calendarType) then
            if C_Calendar.EventCanEdit() then
                self.createPanel.mode = "edit"
                self:ShowEventPanel(self.createPanel)
            else
                self:ShowEventPanel(self.viewPanel)
            end
        end
    end;

    -- The open event or its invite list changed; someone who may now edit
    -- it (or no longer) gets the other panel.
    _OnEventChanged = function(self, invites)
        local panel = self._eventPanel
        if panel == self.viewPanel then
            if C_Calendar.EventCanEdit() then
                self.createPanel.mode = "edit"
                self:ShowEventPanel(self.createPanel)
            else
                self.viewPanel:Update()
            end
        elseif panel == self.createPanel and self.createPanel.mode == "edit" then
            if not C_Calendar.EventCanEdit() then
                self:ShowEventPanel(self.viewPanel)
            elseif invites then
                self.createPanel:UpdateInvites()
            else
                self.createPanel:Update()
            end
        elseif panel == self.createPanel and invites then
            self.createPanel:UpdateInvites()
        end
    end;

    _OnPermissionsChanged = function(self)
        local panel = self._eventPanel
        if panel == self.viewPanel and C_Calendar.EventCanEdit() then
            self.createPanel.mode = "edit"
            self:ShowEventPanel(self.createPanel)
        elseif panel == self.createPanel and self.createPanel.mode == "edit" then
            if C_Calendar.EventCanEdit() then
                self.createPanel:Update()
            else
                self:ShowEventPanel(self.viewPanel)
            end
        end
    end;

    -- One side panel at a time, at the window's right edge.
    ShowEventPanel = function(self, panel)
        if self._eventPanel ~= panel then
            if self._eventPanel then self._eventPanel:Hide() end
            self._eventPanel = panel
            panel:Show()
        end
        if panel.Update then panel:Update() end
        self:_UpdateModal()
    end;

    HideEventPanel = function(self, panel)
        if not self._eventPanel or (panel and panel ~= self._eventPanel) then return end
        self._eventPanel:Hide()
        self._eventPanel = nil
        self:_UpdateModal()
    end;

    -- Retail's CalendarFrame_CloseEvent.
    CloseEvent = function(self)
        C_Calendar.CloseEvent()
        self:HideEventPanel()
        self:_SetSelectedEvent(nil, nil)
    end;

    -- A new event on `dayButton`'s day; `create` is the C_Calendar call
    -- that starts it (a player's event or a guild's).
    CreateEvent = function(self, dayButton, create)
        self:CloseEvent()
        self:SelectDay(dayButton)
        create()
        self.createPanel.mode = "create"
        self.createPanel.dayButton = dayButton
        self:ShowEventPanel(self.createPanel)
    end;

    -- ---- clicks --------------------------------------------------------

    -- A day with events answers as its first one; an empty one is selected,
    -- or offers to make an event.
    ClickDay = function(self, dayButton, mouseButton)
        if dayButton.firstEventButton then
            self:ClickEvent(dayButton.firstEventButton, mouseButton)
            return
        end
        if mouseButton == "LeftButton" then
            local changed = dayButton ~= self.selectedDayButton
            self:SelectDay(dayButton)
            if changed then self:CloseEvent() end
        else
            self:ShowDayMenu(dayButton)
        end
    end;

    ClickEvent = function(self, eventButton, mouseButton)
        local dayButton = eventButton.dayButton
        if mouseButton == "LeftButton" then
            self:SelectDay(dayButton)
            self:OpenEvent(dayButton, eventButton.event)
        else
            self:ShowDayMenu(dayButton, eventButton.event, eventButton)
        end
    end;

    ClickMoreEvents = function(self, dayButton, mouseButton)
        if mouseButton == "LeftButton" then
            self:SelectDay(dayButton)
            self.eventPicker:Toggle(dayButton)
        else
            self:ShowDayMenu(dayButton)
        end
    end;

    ShowMenu = function(self, anchor, items)
        self._menu:SetItems(items)
        self._menu:SetToggleAnchor(anchor)
        self._menu:Open()
    end;

    -- Retail's GenerateDayContextMenu: making an event on a day from today
    -- to the last day events can be made for; copying, pasting, deleting
    -- and answering a player's event.
    ShowDayMenu = function(self, dayButton, event, anchor)
        local info = C_Calendar.GetMonthInfo(dayButton.monthOffset)
        local month, day, year = info.month, dayButton.day, info.year
        local todayOrLater = self:IsTodayOrLater(month, day, year)
        local afterMax = self:_IsAfterMaxCreateDate(month, day, year)
        local canCreate = todayOrLater and not afterMax
        local canPaste = canCreate and C_Calendar.ContextMenuEventClipboard()

        local items = {}
        local function add(label, func)
            items[#items + 1] = { type = "text", label = label, OnClick = func }
        end
        local function divider()
            if #items > 0 and items[#items].type ~= "separator" then items[#items + 1] = { type = "separator" } end
        end
        local function paste()
            C_Calendar.ContextMenuEventPaste(dayButton.monthOffset, day)
        end

        if canCreate then
            add(CALENDAR_CREATE_EVENT, function() self:CreateEvent(dayButton, C_Calendar.CreatePlayerEvent) end)
            if IsInGuild() then
                add(CALENDAR_CREATE_GUILD_EVENT, function() self:CreateEvent(dayButton, C_Calendar.CreateGuildSignUpEvent) end)
            end
            divider()
        end

        if event and Style:IsPlayerEvent(event.calendarType) then
            local offset, index = dayButton.monthOffset, event.index
            if C_Calendar.ContextMenuEventCanEdit(offset, day, index) then
                add(CALENDAR_COPY_EVENT, function() C_Calendar.ContextMenuEventCopy() end)
            end
            if canPaste then add(CALENDAR_PASTE_EVENT, paste) end
            if C_Calendar.ContextMenuEventCanRemove(offset, day, index) then
                add(CALENDAR_DELETE_EVENT, function()
                    StaticPopup_Show(POPUP_DELETE, event.calendarType == "GUILD_EVENT"
                        and CALENDAR_DELETE_GUILD_EVENT_CONFIRM or CALENDAR_DELETE_EVENT_CONFIRM)
                end)
            end
            divider()
            self:_AddReplyItems(add, event, canCreate)
            C_Calendar.ContextMenuSelectEvent(offset, day, index)
        elseif canPaste then
            add(CALENDAR_PASTE_EVENT, paste)
        end

        while #items > 0 and items[#items].type == "separator" do items[#items] = nil end
        if #items == 0 then
            if not todayOrLater then
                StaticPopup_Show(POPUP_ERROR, CALENDAR_ERROR_CREATEDATE_BEFORE_TODAY)
            elseif afterMax then
                local max = C_Calendar.GetMaxCreateDate()
                StaticPopup_Show(POPUP_ERROR, CALENDAR_ERROR_CREATEDATE_AFTER_MAX:format(
                    CALENDAR_WEEKDAY_NAMES[max.weekday], CALENDAR_FULLDATE_MONTH_NAMES[max.month], max.monthDay, max.year))
            end
            return
        end
        self:ShowMenu(anchor or dayButton, items)
    end;

    -- Answering an invite from the menu: sign up to a guild sign-up event,
    -- accept / tentative / decline anything else not one's own; and
    -- removing an invitation one was only sent.
    _AddReplyItems = function(self, add, event, open)
        local status = event.inviteStatus
        local canReply = status == Enum.CalendarStatus.Invited or status == Enum.CalendarStatus.Available
            or status == Enum.CalendarStatus.Declined or status == Enum.CalendarStatus.Signedup
            or status == Enum.CalendarStatus.NotSignedup or status == Enum.CalendarStatus.Tentative
        local signup = event.calendarType == "GUILD_EVENT" and event.inviteType == Enum.CalendarInviteType.Signup
        if open and canReply then
            if signup then
                if status == Enum.CalendarStatus.NotSignedup then
                    add(CALENDAR_SIGNUP, function() C_Calendar.ContextMenuEventSignUp() end)
                end
            elseif event.modStatus ~= "CREATOR" then
                if status ~= Enum.CalendarStatus.Available then
                    add(CALENDAR_ACCEPT_INVITATION, function() C_Calendar.ContextMenuInviteAvailable() end)
                end
                if status ~= Enum.CalendarStatus.Tentative then
                    add(CALENDAR_TENTATIVE_INVITATION, function() C_Calendar.ContextMenuInviteTentative() end)
                end
                if status ~= Enum.CalendarStatus.Declined then
                    add(CALENDAR_DECLINE_INVITATION, function() C_Calendar.ContextMenuInviteDecline() end)
                end
            end
        end
        if event.modStatus ~= "CREATOR" and (event.calendarType == "PLAYER"
            or (event.calendarType == "GUILD_EVENT" and event.inviteType == Enum.CalendarInviteType.Normal)) then
            add(CALENDAR_REMOVE_INVITATION, function() C_Calendar.ContextMenuInviteRemove() end)
        end
    end;

    -- ---- modal dialogs -------------------------------------------------

    PushModal = function(self, frame)
        if self._modals[#self._modals] == frame then return end
        self._modals[#self._modals + 1] = frame
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:_UpdateModal()
    end;

    PopModal = function(self, frame)
        for i = #self._modals, 1, -1 do
            if self._modals[i] == frame then
                table.remove(self._modals, i)
                PlaySound(SOUNDKIT.IG_MAINMENU_QUIT)
                break
            end
        end
        self:_UpdateModal()
    end;

    -- While a dialog waits: the grid and the side panel dimmed, the month
    -- arrows and the filters out of reach.
    _UpdateModal = function(self)
        local modal = #self._modals > 0
        self._gridShade:SetVisible(modal)
        local panel = self._eventPanel
        if modal and panel then
            self._panelShade:SetParent(panel)
            self._panelShade:ClearAllPoints()
            self._panelShade:FillParent(10)
            self._panelShade:SetFrameLevel(panel:GetFrameLevel() + 20)
            self._panelShade:Show()
        else
            self._panelShade:Hide()
        end
        self._filter:SetEnabled(not modal)
        if self.viewedMonth then self:_UpdateMonthButtons() end
    end;

    -- ---- tooltip -------------------------------------------------------

    -- Retail's CalendarDayButton_OnEnter: the date, then the day's events by
    -- time, the ongoing ones under their own label with their date range.
    ShowDayTooltip = function(self, dayButton)
        local events = dayButton.events
        if not events or #events == 0 then return end
        local sorted = {}
        for i, event in ipairs(events) do sorted[i] = event end
        table.sort(sorted, function(a, b)
            local aOngoing, bOngoing = a.sequenceType == "ONGOING", b.sequenceType == "ONGOING"
            if aOngoing ~= bOngoing then return bOngoing end
            if aOngoing and a.sequenceIndex ~= b.sequenceIndex then return a.sequenceIndex > b.sequenceIndex end
            if a.startTime.hour ~= b.startTime.hour then return a.startTime.hour < b.startTime.hour end
            return a.startTime.minute < b.startTime.minute
        end)

        MUI_Tooltip:ShowFor(dayButton, "ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(self:FullDateOf(dayButton), 1, 1, 1, false, 13)
            tooltip:AddBlank()
            local ongoing = 0
            for i, event in ipairs(sorted) do
                if i > 1 and ongoing == 0 then tooltip:AddBlank() end
                local when
                if event.sequenceType == "ONGOING" then
                    if ongoing == 0 then tooltip:AddLine(CALENDAR_TOOLTIP_ONGOING, 1, 1, 1) end
                    ongoing = ongoing + 1
                    when = CALENDAR_TOOLTIP_DATE_RANGE:format(
                        FormatShortDate(event.startTime.monthDay, event.startTime.month),
                        FormatShortDate(event.endTime.monthDay, event.endTime.month))
                elseif event.sequenceType == "END" then
                    when = Style:FormatTime(event.endTime.hour, event.endTime.minute)
                else
                    when = Style:FormatTime(event.startTime.hour, event.startTime.minute)
                end
                local color = Style:EventColor(event, true)
                tooltip:AddDoubleLine(Style:EventTitle(event, true), when, color.r, color.g, color.b, 1, 1, 1, 10.5)
                if Style:IsPlayerEvent(event.calendarType) then
                    tooltip:AddLine(self:_InviteLine(event), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                end
            end
        end)
    end;

    -- Who invited the player to a player's event, or where they stand on a
    -- guild sign-up.
    _InviteLine = function(self, event)
        if UnitIsUnit("player", event.invitedBy) then
            return event.calendarType == "GUILD_EVENT" and CALENDAR_GUILDEVENT_INVITEDBY_YOURSELF or CALENDAR_EVENT_INVITEDBY_YOURSELF
        end
        if event.calendarType == "GUILD_EVENT" and event.inviteType == Enum.CalendarInviteType.Signup then
            local status = CalendarUtil.GetCalendarInviteStatusInfo(event.inviteStatus)
            if event.inviteStatus == Enum.CalendarStatus.NotSignedup or event.inviteStatus == Enum.CalendarStatus.Signedup then
                return status.name
            end
            return CALENDAR_SIGNEDUP_FOR_GUILDEVENT_WITH_STATUS:format(status.name)
        end
        return CALENDAR_EVENT_INVITEDBY_PLAYER:format(event.invitedBy ~= "" and event.invitedBy or UNKNOWN)
    end;
}
