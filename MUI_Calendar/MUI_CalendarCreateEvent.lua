-- MUI_CalendarCreateEvent: making and editing an event — retail's
-- CalendarCreateEventFrame — and its Mass Invite dialog.
--
-- Era's server keeps player and guild events (ClassicCalendar's notes); what
-- it lacks is left out: guild announcements and community events (Era has
-- no permission for the one and no communities), and a mass invite reaches
-- the guild only, which is all Era's own (Classic) calendar code sends.

local Style = MUI_CalendarStyle

local PANEL_Y = -24
local DEFAULT_HOUR, DEFAULT_MINUTE = 12, 0


-- ---------------------------------------------------------------------
-- CalendarDescriptionEdit: retail's ScrollingEditBoxTemplate in a dark
-- box — a multi-line edit box that scrolls with its cursor, and the grey
-- "Event Description" while it is empty. OnTextChanged(text) fires for
-- what the player types.
-- ---------------------------------------------------------------------
class "CalendarDescriptionEdit" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent, nil, "TooltipBackdropTemplate")
        self:SetSize(287, 65)
        self:SetBackdropColor(0, 0, 0, 0.9)
        self:EnableMouse(true)

        self._scroll = ScrollFrame(self)
        self._scroll:Fill(self, 6, 6, 20, 6)
        self._scroll:EnableMouseWheel(true)

        self.edit = EditBox(self._scroll, nil, "InputBoxScriptTemplate")
        self.edit:SetMultiLine(true)
        self.edit:SetAutoFocus(false)
        self.edit:SetMaxLetters(255)
        self.edit:SetFontObject("GameFontHighlightSmall")
        self.edit:SetWidth(261)
        self._scroll:SetScrollChild(self.edit)

        self._placeholder = Style:Label(self, "GameFontDisableSmall")
        self._placeholder:SetText(CALENDAR_EVENT_DESCRIPTION)
        self._placeholder:AlignParentTopLeft(6, 6)

        self._bar = MinimalScrollBar(self)
        self._bar:AlignParentTopRight(5, 5)
        self._bar:AlignParentBottomRight(5, 5)
        self._bar:SetScrollSpeed(12)
        self._bar.OnScroll = function(_, value) self._scroll:SetVerticalScroll(value) end
        self._bar:Hide()
        self._scroll:SetScript("OnMouseWheel", function(_, delta)
            self._bar:SetValue(self._bar:GetValue() - delta * 12)
        end)

        -- The template selects everything on focus; a description is edited
        -- where it is clicked.
        self.edit.OnFocusGained = function()
            self.edit:HighlightText(0, 0)
            self:_UpdatePlaceholder()
        end
        self.edit.OnFocusLost = function() self:_UpdatePlaceholder() end
        self.edit.OnTextChanged = function(_, text, userInput)
            self:_UpdatePlaceholder()
            if userInput and self.OnTextChanged then self:OnTextChanged(text) end
        end
        self.edit:SetScript("OnSizeChanged", function() self:_UpdateRange() end)
        self.edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            self:_ShowCursor(-y, height)
        end)
        self:SetScript("OnMouseDown", function() self.edit:SetFocus() end)
    end;

    SetText = function(self, text)
        self.edit:SetText(text or "")
        self._bar:SetValue(0)
        self._scroll:SetVerticalScroll(0)
        self:_UpdatePlaceholder()
    end;

    _UpdatePlaceholder = function(self)
        self._placeholder:SetVisible(self.edit:GetText() == "" and not self.edit:HasFocus())
    end;

    _UpdateRange = function(self)
        local view = self._scroll:GetHeight()
        local range = math.max(self.edit:GetHeight() - view, 0)
        self._bar:SetMinMax(0, range)
        self._bar:SetContentSize(view, view + range)
        self._bar:SetVisible(range > 0)
        self._scroll:SetVerticalScroll(self._bar:GetValue())
    end;

    -- Keep the line the cursor is on in view.
    _ShowCursor = function(self, top, height)
        local scroll, view = self._bar:GetValue(), self._scroll:GetHeight()
        if top < scroll then
            self._bar:SetValue(top)
        elseif top + height > scroll + view then
            self._bar:SetValue(top + height - view)
        end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarCreateEventPanel: mode "create" (a new event on .dayButton's
-- day) or "edit" (the event C_Calendar has open).
-- ---------------------------------------------------------------------
class "CalendarCreateEventPanel" : extends "CalendarDialog" {
    __init = function(self, window)
        CalendarDialog.__init(self, window, "MUI_CalendarCreateEventFrame", 320, 580)
        self.window = window
        self.mode = "create"
        self:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, PANEL_Y)

        self:_BuildHeader()
        self:_BuildTitle()
        self:_BuildType()
        self:_BuildTime()

        self._description = CalendarDescriptionEdit(self.content)
        self._description:AlignParentTopLeft(146, 16)
        self._description.OnTextChanged = function(_, text) C_Calendar.EventSetDescription(text) end
        self._title:SetScript("OnTabPressed", function() self._description.edit:SetFocus() end)
        self._description.edit:SetScript("OnTabPressed", function() self._inviteEdit:SetFocus() end)

        self:_BuildInvites()
        self:_BuildButtons()
        self.massInvite = CalendarMassInvite(window, self._massInvite)

        self.closeButton.OnClick = function() window:CloseEvent() end

        -- Retail polls its buttons every frame; a few times a second will do.
        local wait = 0
        self:SetScript("OnUpdate", function(_, elapsed)
            wait = wait - elapsed
            if wait > 0 then return end
            wait = 0.2
            self:_UpdateButtons()
        end)
        self:SetScript("OnHide", function()
            self._inviteLostMembers = false
            self.massInvite:Close()
        end)
        self:RegisterEventHandler("GROUP_ROSTER_UPDATE", function() self:_OnGroupChanged() end)
    end;

    -- ---- building ------------------------------------------------------

    -- The icon and the lines beside it: the guild, the dungeon, who made
    -- the event, its date.
    _BuildHeader = function(self)
        self._icon = Texture(self.content, nil, "BORDER")
        self._icon:SetSize(50, 50)
        self._icon:AlignParentTopLeft(26, 16)

        self._guild = Style:Label(self.content, "GameFontNormalSmall", "BACKGROUND")
        self._guild:SetSize(220, 12)
        self._guild:SetJustifyH("LEFT")
        self._guild:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
        self._dungeon = Style:Label(self.content, "GameFontNormalSmall", "BACKGROUND")
        self._dungeon:SetWidth(230)
        self._dungeon:SetJustifyH("LEFT")
        self._dungeon:SetJustifyV("TOP")
        self._creator = Style:Label(self.content, "GameFontNormalSmall", "BACKGROUND")
        self._creator:SetSize(220, 12)
        self._creator:SetJustifyH("LEFT")
        self._date = Style:Label(self.content, "GameFontHighlightSmall", "BACKGROUND")
    end;

    _BuildTitle = function(self)
        local edit = EditBox(self.content, "MUI_CalendarCreateEventTitleEdit", "InputBoxTemplate")
        edit:SetSize(120, 20)
        edit:AlignParentTopLeft(84, 25)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(31)
        -- The default name or nothing but spaces makes no title.
        edit.OnTextChanged = function(_, text, userInput)
            if not userInput then return end
            local trimmed = strtrim(text)
            C_Calendar.EventSetTitle((trimmed == "" or trimmed == CALENDAR_EVENT_NAME) and "" or text)
        end
        edit.OnFocusLost = function()
            if strtrim(edit:GetText()) == "" then edit:SetText(CALENDAR_EVENT_NAME) end
            edit:HighlightText(0, 0)
        end
        edit.OnEnterPressed = function() edit:ClearFocus() end
        self._title = edit
    end;

    -- A dropdown of ours in retail's place: `width` wide, its menu filled later.
    _Dropdown = function(self, width)
        local button = DropdownSimple(self.content)
        button:SetSize(width, 22)
        local menu = DropdownMenu(button, nil, button)
        menu:SetMenuWidth(math.max(width + 20, 80))
        button.OnClick = function() menu:Toggle() end
        return button, menu
    end;

    -- Raid and Dungeon ask which one first (the texture picker).
    _BuildType = function(self)
        local button, menu = self:_Dropdown(100)
        button:AlignParentTopLeft(82, 190)
        local items = {}
        for _, info in ipairs(C_Calendar.EventGetTypesDisplayOrdered()) do
            local eventType = info.eventType
            items[#items + 1] = { type = "text", label = _G[info.displayString], OnClick = function()
                if eventType == Enum.CalendarEventType.Raid or eventType == Enum.CalendarEventType.Dungeon then
                    local selected = self.selectedEventType == eventType and self.selectedTextureIndex or nil
                    self.window.texturePicker:Open(eventType, selected, function(index, chosenType)
                        self:_SetDungeon(index, chosenType)
                    end)
                else
                    C_Calendar.EventSetType(eventType)
                    self.selectedEventType = eventType
                    self.selectedTextureIndex = nil
                    self:_UpdateTexture()
                end
            end }
        end
        menu:SetItems(items)
        self._typeButton = button
    end;

    _BuildTime = function(self)
        self._hourButton, self._hourMenu = self:_Dropdown(58)
        self._hourButton:AlignParentTopLeft(114, 20)
        self._minuteButton, self._minuteMenu = self:_Dropdown(58)
        self._minuteButton:RightOf(self._hourButton, 5)
        self._ampmButton, self._ampmMenu = self:_Dropdown(62)
        self._ampmButton:RightOf(self._minuteButton, 5)

        local minutes = {}
        for minute = 0, 55, 5 do
            minutes[#minutes + 1] = { type = "text", label = TIMEMANAGER_MINUTE:format(minute), OnClick = function()
                self.selectedMinute = minute
                self:_SetTime()
            end }
        end
        self._minuteMenu:SetItems(minutes)

        local function half(text, am)
            return { type = "text", label = text, OnClick = function()
                self.selectedAM = am
                self:_SetTime()
            end }
        end
        self._ampmMenu:SetItems({ half(TIMEMANAGER_AM, true), half(TIMEMANAGER_PM, false) })
    end;

    -- The lock box, the invite list, the name box and its Invite button.
    _BuildInvites = function(self)
        local section = Frame("Frame", self.content)
        section:SetSize(320, 330)
        section:AlignParentTopLeft(210, 0)
        self._section = section

        local divider = Style:Art(section, "BORDER", "Interface\\DialogFrame\\UI-DialogBox-Divider", 303, 16, 0, 0.75390625, 0, 0.5)
        divider:AlignParentTopLeft(20, 10)

        self._lock = CheckBox(section, nil, CALENDAR_LOCK_EVENT)
        self._lock:SetSize(90, 24)
        self._lock:SetBoxSize(24, 24)
        self._lock.label:SetFontSize(10)
        self._lock.label:SetTextColor(1, 0.82, 0)
        self._lock:AlignParentTopLeft(0, 201)
        self._lock.OnChanged = function(_, checked)
            if checked then C_Calendar.EventSetLocked() else C_Calendar.EventClearLocked() end
        end
        self._lock:SetTooltip("ANCHOR_LEFT", function(tooltip)
            tooltip:AddLine(CALENDAR_TOOLTIP_LOCKEVENT, 1, 1, 1, true)
        end)

        self.inviteList = CalendarInviteList(section, self)
        self.inviteList:AlignParentTop(50)
        self.classTotals = CalendarClassTotals(self)
        self.classTotals:SetPoint("TOPLEFT", self, "TOPRIGHT", -4, -30)

        -- The first Enter takes a name from the completion list, the next
        -- one invites.
        local edit = EditBox(section, "MUI_CalendarCreateEventInviteEdit", "InputBoxTemplate,AutoCompleteEditBoxTemplate")
        edit:SetSize(192, 20)
        edit:SetPoint("TOPLEFT", self.inviteList, "BOTTOMLEFT", 6, -3)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(32)
        edit:SetText(CALENDAR_PLAYER_NAME)
        edit:SetScript("OnEnterPressed", function()
            if not edit:AcceptAutoComplete() then self:_Invite() end
        end)
        edit:SetScript("OnEscapePressed", function()
            if not edit:CancelAutoComplete() then edit:ClearFocus() end
        end)
        edit.OnFocusLost = function()
            edit:HighlightText(0, 0)
            if strtrim(edit:GetText()) == "" then edit:SetText(CALENDAR_PLAYER_NAME) end
        end
        self._inviteEdit = edit

        self._inviteButton = CalendarButton(section, INVITE)
        self._inviteButton:SetPoint("TOPLEFT", edit, "TOPRIGHT", 0, 1)
        self._inviteButton:SetPoint("TOPRIGHT", self.inviteList, "BOTTOMRIGHT", 0, 1)
        self._inviteButton.OnClick = function() self:_Invite() end
    end;

    -- Mass Invite (a new event) or Invite Members (one being edited) at the
    -- left, Create / Update at the right.
    _BuildButtons = function(self)
        Style:ButtonStrip(self.content)

        self._massInvite = CalendarButton(self.content, CALENDAR_MASS_INVITE, CALENDAR_TOOLTIP_MASSINVITE)
        self._massInvite:FitText()
        self._massInvite:AlignParentBottomLeft(12, 12)
        Style:ButtonBorder(self._massInvite, true)
        self._massInvite.OnClick = function() self.massInvite:Toggle() end

        self._raidInvite = CalendarButton(self.content, CALENDAR_INVITE_MEMBERS)
        self._raidInvite:FitText()
        self._raidInvite:AlignParentBottomLeft(12, 12)
        Style:ButtonBorder(self._raidInvite, true)
        self._raidInvite.OnClick = function() self:_InviteToGroup() end

        self._create = CalendarButton(self.content, CALENDAR_CREATE)
        self._create:AlignParentBottomRight(12, 11)
        Style:ButtonBorder(self._create)
        self._create.OnClick = function()
            if self.mode == "create" then C_Calendar.AddEvent() else C_Calendar.UpdateEvent() end
        end
    end;

    -- ---- updating ------------------------------------------------------

    -- Retail's CalendarCreateEventFrame_Update.
    Update = function(self)
        if self.mode == "create" then
            self:_UpdateCreate()
        else
            self:_UpdateEdit()
        end
        self._inviteEdit:SetAutoCompleteSource(
            C_Calendar.EventGetCalendarType() == "GUILD_EVENT" and AUTOCOMPLETE_LIST.CALENDARGUILDEVENT.include or AUTOCOMPLETE_LIST.CALENDAREVENT.include,
            C_Calendar.EventGetCalendarType() == "GUILD_EVENT" and AUTOCOMPLETE_LIST.CALENDARGUILDEVENT.exclude or AUTOCOMPLETE_LIST.CALENDAREVENT.exclude)
        self:_UpdateButtons()
    end;

    -- A new event on the day clicked: noon, of type Other, unlocked.
    _UpdateCreate = function(self)
        local day = self.dayButton
        local info = C_Calendar.GetMonthInfo(day.monthOffset)
        C_Calendar.EventSetDate(info.month, day.day, info.year)
        self._date:SetText(self.window:FullDateOf(day))

        self._title:SetText(CALENDAR_EVENT_NAME)
        self._title:HighlightText()
        self._title:SetFocus()
        C_Calendar.EventSetTitle("")
        self._description:SetText("")
        C_Calendar.EventSetDescription("")

        self.selectedMinute = DEFAULT_MINUTE
        self.selectedAM = true
        self.selectedHour = self.window.militaryTime and GameTime_ComputeMilitaryTime(DEFAULT_HOUR, true) or DEFAULT_HOUR
        self:_SetTime()

        self.selectedEventType = Enum.CalendarEventType.Other
        self.selectedTextureIndex = nil
        C_Calendar.EventSetType(self.selectedEventType)
        self._guild:Hide()
        self._creator:Hide()
        self:_UpdateTexture()

        self:SetTitle(C_Calendar.EventGetCalendarType() == "GUILD_EVENT" and CALENDAR_CREATE_GUILD_EVENT or CALENDAR_CREATE_EVENT)
        self._massInvite:SetVisible(C_Calendar.EventGetCalendarType() ~= "GUILD_EVENT")
        self._raidInvite:Hide()
        self._create:SetText(CALENDAR_CREATE)
        self._create:FitText()

        C_Calendar.EventClearAutoApprove()
        self._lock:SetChecked(false)
        C_Calendar.EventClearLocked()
        self:UpdateInvites()
    end;

    -- The event C_Calendar has open, as it stands.
    _UpdateEdit = function(self)
        local info = C_Calendar.GetEventInfo()
        if not info or not info.title then
            self.window:HideEventPanel(self)
            return
        end

        self._title:SetText(info.title)
        self._title:SetCursorPosition(0)
        self._title:ClearFocus()
        self._description.edit:ClearFocus()
        self._description:SetText(info.description)
        self._date:SetText(Style:FullDate(info.time.weekday, info.time.month, info.time.monthDay, info.time.year))

        self.selectedMinute = info.time.minute
        self.selectedAM = info.time.hour < 12
        if self.window.militaryTime then
            self.selectedHour = info.time.hour
        else
            self.selectedHour = GameTime_ComputeStandardTime(info.time.hour)
        end
        self:_UpdateTime()

        self.selectedEventType = info.eventType
        self.selectedTextureIndex = info.textureIndex
        if info.calendarType == "GUILD_EVENT" then
            local guild = info.communityName
            if not guild or guild == "" then guild = GetGuildInfo("player") end
            self._guild:SetText(guild or "")
            self._guild:Show()
        else
            self._guild:Hide()
        end
        self._creator:SetText(CALENDAR_EVENT_CREATORNAME:format(info.creator ~= "" and info.creator or UNKNOWN))
        self._creator:Show()
        self:_UpdateTexture()

        self:SetTitle(info.calendarType == "GUILD_EVENT" and CALENDAR_EDIT_GUILD_EVENT or CALENDAR_EDIT_EVENT)
        self._lock:SetChecked(info.isLocked)
        self._massInvite:Hide()
        self._raidInvite:Show()
        self._create:SetText(CALENDAR_UPDATE)
        self._create:FitText()
        self:UpdateInvites()
    end;

    -- The icon, the dungeon's name and the type's, and the lines beside
    -- the icon under one another.
    _UpdateTexture = function(self)
        local eventType = self.selectedEventType
        local dungeon = Style:Dungeon(self.selectedTextureIndex, eventType)
        if dungeon then
            self._dungeon:SetText(GetDungeonNameWithDifficulty(dungeon.title, ""))
            self._dungeon:Show()
            self._icon:SetTexture(dungeon.texture or Style:EventTypeTexture(eventType))
        else
            self._dungeon:Hide()
            self._icon:SetTexture(Style:EventTypeTexture(eventType))
        end
        self._typeButton:SetText(Style:EventTypeName(eventType))

        local previous
        for _, line in ipairs({ self._guild, self._dungeon, self._creator, self._date }) do
            if line:IsShown() then
                line:ClearAllPoints()
                if previous then
                    line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
                else
                    line:SetPoint("TOPLEFT", self._icon, "TOPRIGHT", 5, 0)
                end
                previous = line
            end
        end
    end;

    _SetDungeon = function(self, textureIndex, eventType)
        C_Calendar.EventSetType(eventType)
        C_Calendar.EventSetTextureID(textureIndex)
        self.selectedEventType = eventType
        self.selectedTextureIndex = textureIndex
        self:_UpdateTexture()
    end;

    -- The hour menu counts 0-23 or 1-12 as the clock does; AM / PM only
    -- with the 12-hour clock.
    _UpdateTime = function(self)
        local military = self.window.militaryTime
        if military ~= self._militaryMenu then
            self._militaryMenu = military
            local hours = {}
            for hour = military and 0 or 1, military and 23 or 12 do
                hours[#hours + 1] = { type = "text", label = military and TIMEMANAGER_24HOUR:format(hour) or tostring(hour), OnClick = function()
                    self.selectedHour = hour
                    self:_SetTime()
                end }
            end
            self._hourMenu:SetItems(hours)
        end
        self._hourButton:SetText(military and TIMEMANAGER_24HOUR:format(self.selectedHour) or tostring(self.selectedHour))
        self._minuteButton:SetText(TIMEMANAGER_MINUTE:format(self.selectedMinute))
        self._ampmButton:SetText(self.selectedAM and TIMEMANAGER_AM or TIMEMANAGER_PM)
        self._ampmButton:SetVisible(not military)
    end;

    _SetTime = function(self)
        local hour = self.selectedHour
        if not self.window.militaryTime then
            hour = GameTime_ComputeMilitaryTime(hour, self.selectedAM)
        end
        C_Calendar.EventSetTime(hour, self.selectedMinute)
        self:_UpdateTime()
    end;

    -- The clock changed between 12 and 24 hours: the time the panel holds
    -- is converted, as retail's CalendarCreateEvent_UpdateTimeFormat does.
    UpdateTimeFormat = function(self, military)
        if military then
            self.selectedHour = GameTime_ComputeMilitaryTime(self.selectedHour, self.selectedAM)
        else
            self.selectedHour, self.selectedAM = GameTime_ComputeStandardTime(self.selectedHour)
        end
        self:_UpdateTime()
    end;

    UpdateInvites = function(self)
        self.inviteList:Update(self.classTotals)
        self:_UpdateRaidInvite()
    end;

    _UpdateButtons = function(self)
        if self.mode == "create" then
            self._create:SetActive(C_Calendar.CanAddEvent())
        else
            self._create:SetActive(C_Calendar.EventHaveSettingsChanged() and not C_Calendar.IsActionPending())
        end
        self._inviteButton:SetActive(C_Calendar.CanSendInvite())
        self._massInvite:SetActive(C_Calendar.CanSendInvite() and IsInGuild())
    end;

    -- ---- inviting ------------------------------------------------------

    _Invite = function(self)
        local name = strtrim(self._inviteEdit:GetText())
        if name == "" or name == CALENDAR_PLAYER_NAME then
            self._inviteEdit:ClearFocus()
        elseif C_Calendar.CanSendInvite() then
            C_Calendar.EventInvite(name)
            self._inviteEdit:SetText("")
        end
    end;

    -- Retail's CalendarCreateEventInviteListButton_OnClick: a right click on
    -- an invitee offers what the event's creator can do to them.
    ClickInvite = function(self, row, mouseButton)
        if mouseButton ~= "RightButton" then return end
        local index, info = row.inviteIndex, row.info
        local items = {}
        if info.modStatus ~= "CREATOR" then
            items[#items + 1] = { type = "text", label = REMOVE, OnClick = function() C_Calendar.EventRemoveInvite(index) end }
            if info.modStatus == "MODERATOR" then
                items[#items + 1] = { type = "text", label = CALENDAR_INVITELIST_CLEARMODERATOR, OnClick = function() C_Calendar.EventClearModerator(index) end }
            else
                items[#items + 1] = { type = "text", label = CALENDAR_INVITELIST_SETMODERATOR, OnClick = function() C_Calendar.EventSetModerator(index) end }
            end
        end
        if self.mode == "edit" then
            local statuses = {}
            for _, option in ipairs(C_Calendar.EventGetStatusOptions(index)) do
                statuses[#statuses + 1] = { type = "text", label = _G[option.statusString], OnClick = function()
                    C_Calendar.EventSetInviteStatus(index, option.status)
                end }
            end
            items[#items + 1] = { type = "submenu", label = CALENDAR_INVITELIST_SETINVITESTATUS, items = statuses }
        end
        if not UnitIsUnit("player", info.name) and not UnitInParty(info.name) and not UnitInRaid(info.name) then
            items[#items + 1] = { type = "text", label = CALENDAR_INVITELIST_INVITETORAID, OnClick = function() C_PartyInfo.InviteUnit(info.name) end }
        end
        if #items > 0 then self.window:ShowMenu(row, items) end
    end;

    -- Accepted, confirmed, signed-up and tentative invitees not in the group.
    _GroupCandidates = function(self, limit)
        local names = {}
        local player = UnitName("player")
        for index = 1, C_Calendar.GetNumInvites() do
            if #names >= limit then break end
            local info = C_Calendar.EventGetInvite(index)
            local status = info.inviteStatus
            if info.name and info.name ~= player and not UnitInParty(info.name) and not UnitInRaid(info.name)
               and (status == Enum.CalendarStatus.Available or status == Enum.CalendarStatus.Confirmed
                    or status == Enum.CalendarStatus.Signedup or status == Enum.CalendarStatus.Tentative) then
                names[#names + 1] = info.name
            end
        end
        return names
    end;

    _UpdateRaidInvite = function(self)
        local count = #self:_GroupCandidates(MAX_RAID_MEMBERS - GetNumGroupMembers())
        self._raidInviteCount = count
        self._raidInvite:SetActive(count > 0)
        local raid = IsInRaid() or GetNumGroupMembers() + count > MAX_PARTY_MEMBERS + 1
        self._raidInvite.tooltip = raid and CALENDAR_TOOLTIP_INVITEMEMBERS_BUTTON_RAID or CALENDAR_TOOLTIP_INVITEMEMBERS_BUTTON_PARTY
    end;

    -- Retail's CalendarCreateEventRaidInviteButton_OnClick: a party that
    -- cannot hold everyone becomes a raid first, then the invites go out.
    _InviteToGroup = function(self)
        local members = GetNumGroupMembers()
        local limit
        if IsInRaid() then
            limit = MAX_RAID_MEMBERS - members
        else
            if members + self._raidInviteCount > MAX_PARTY_MEMBERS + 1 then
                self._inviteLostMembers = true
                if members > 0 then
                    ConvertToRaid()
                    return
                end
            end
            limit = MAX_PARTY_MEMBERS + 1 - members
        end
        for _, name in ipairs(self:_GroupCandidates(limit)) do
            C_PartyInfo.InviteUnit(name)
        end
    end;

    -- A party formed after a click that could not fit everyone turns into a
    -- raid for the rest.
    _OnGroupChanged = function(self)
        if not self:IsShown() or self.mode ~= "edit" then return end
        self:_UpdateRaidInvite()
        if self._inviteLostMembers and IsInGroup() and not IsInRaid() then
            ConvertToRaid()
        end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarMassInvite: retail's CalendarMassInviteFrame for the guild —
-- everyone in a level range down to a rank.
-- ---------------------------------------------------------------------
class "CalendarMassInvite" : extends "CalendarDialog" {
    __init = function(self, window, anchor)
        CalendarDialog.__init(self, window, "MUI_CalendarMassInviteFrame", 320, 210, CALENDAR_MASS_INVITE)
        self.window = window
        self:SetFrameStrata("DIALOG")
        self:SetPoint("BOTTOMRIGHT", anchor, "TOPLEFT")
        self.closeButton.OnClick = function() self:Close() end

        self._guild = Style:Label(self.content, "GameFontNormal")
        self._guild:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
        self._guild:AlignParentTop(38)

        local help = Style:Label(self.content, "GameFontHighlightSmall", "BACKGROUND")
        help:SetWidth(280)
        help:SetJustifyH("CENTER")
        help:SetText(CALENDAR_MASSINVITE_GUILD_HELP)
        help:AlignParentTop(76)

        local level = Style:Label(self.content, "GameFontNormalSmall", "BACKGROUND")
        level:SetText(LEVEL)
        level:AlignParentTopLeft(103, 46)
        local dash = Style:Label(self.content, "GameFontNormalSmall", "BACKGROUND")
        dash:SetText("-")
        dash:AlignParentTopLeft(127, 80)

        local function levelEdit(x)
            local edit = EditBox(self.content, nil, "InputBoxTemplate")
            edit:SetSize(25, 20)
            edit:AlignParentTopLeft(122, x)
            edit:SetAutoFocus(false)
            edit:SetNumeric(true)
            edit:SetMaxLetters(3)
            edit.OnEnterPressed = function() edit:ClearFocus() end
            return edit
        end
        self._minLevel = levelEdit(50)
        self._maxLevel = levelEdit(97)

        local rank = Style:Label(self.content, "GameFontNormalSmall", "BACKGROUND")
        rank:SetText(CALENDAR_MASSINVITE_GUILD_MINRANK)
        rank:AlignParentTopLeft(103, 170)
        self._rankButton = DropdownSimple(self.content)
        self._rankButton:SetSize(122, 22)
        self._rankButton:AlignParentTopLeft(120, 149)
        self._rankMenu = DropdownMenu(self._rankButton, nil, self._rankButton)
        self._rankMenu:SetMenuWidth(150)
        self._rankButton.OnClick = function() self._rankMenu:Toggle() end

        self._accept = CalendarButton(self.content, ACCEPT)
        self._accept:AlignParentTop(160)
        self._accept.OnClick = function()
            C_Calendar.MassInviteGuild(self._minLevel:GetNumber(), self._maxLevel:GetNumber(), self._rank)
            self:Close()
        end

        local filter = C_Calendar.GetDefaultGuildFilter()
        self._minLevel:SetNumber(filter.minLevel)
        self._maxLevel:SetNumber(filter.maxLevel)

        self:RegisterEventHandler("GUILD_ROSTER_UPDATE", function(_, _, canRequest)
            if canRequest then C_GuildInfo.GuildRoster() end
            if self:IsShown() then self:_Update() end
        end)
        self:RegisterEventHandler("PLAYER_GUILD_UPDATE", function()
            if self:IsShown() then self:_Update() end
        end)
    end;

    Toggle = function(self)
        if self:IsShown() then
            self:Close()
            return
        end
        if IsInGuild() and GetNumGuildMembers() == 0 then
            C_GuildInfo.GuildRoster()
        end
        self:Show()
        self.window:PushModal(self)
        self:_Update()
    end;

    Close = function(self)
        if not self:IsShown() then return end
        self:Hide()
        self.window:PopModal(self)
    end;

    -- Out of the guild there is no one to invite.
    _Update = function(self)
        if not IsInGuild() then
            self:Close()
            return
        end
        self._guild:SetText(GetGuildInfo("player") or "")

        local numRanks = GuildControlGetNumRanks()
        if not self._rank or self._rank > numRanks then
            self._rank = C_Calendar.GetDefaultGuildFilter().rank
        end
        local items = {}
        for index = 1, numRanks do
            items[#items + 1] = { type = "text", label = GuildControlGetRankName(index), OnClick = function()
                self._rank = index
                self._rankButton:SetText(GuildControlGetRankName(index))
            end }
        end
        self._rankMenu:SetItems(items)
        self._rankButton:SetText(GuildControlGetRankName(self._rank) or "")
        self._accept:SetActive(C_Calendar.CanSendInvite())
    end;
}
