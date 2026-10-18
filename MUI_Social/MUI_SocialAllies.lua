-- Recent Allies: retail's list of the players last grouped with, as a third
-- view of the Friends tab.
--
-- Retail fills it from C_RecentAllies, a server-side record. Era's client has
-- that API, but the system was found switched off there (the NewEra addon's
-- check on 1.15.8), so the record is kept here: every player met in a party
-- or raid is written down with the time and the zone, up to MAX_ALLIES of
-- them, the longest unseen dropped first. Pinned ones are kept. Whether an
-- ally is online is not known unless they are in the group.

local MAX_ALLIES = 50

local SHEET = MUI.TEX_SKIN .. "social\\friendslist"
local SHEET_W, SHEET_H = 512, 64

-- The list fills the Friends tab's own list area.
local LIST_W, LIST_H = 349, 309
local ROW_H = 46

-- ---------------------------------------------------------------------
-- SocialAllies: the record.
--   MUI_DB.data.recentAllies[fullName] = { name, class, level, zone, time, pinned }
-- ---------------------------------------------------------------------
class "SocialAllies" {

    __init = function(self)
        self._events = Frame()
        self._events:RegisterEventHandler("GROUP_ROSTER_UPDATE", function() self:Scan() end)
        self:Scan()
    end;

    -- Everyone in the group now. A member whose data has not arrived yet is
    -- picked up by the roster update that follows it.
    Scan = function(self)
        local prefix, count = "party", GetNumSubgroupMembers()
        if IsInRaid() then
            prefix, count = "raid", GetNumGroupMembers()
        end
        local seen = false
        for i = 1, count do
            seen = self:_Record(prefix .. i) or seen
        end
        if seen and self.OnChanged then self:OnChanged() end
    end;

    _Record = function(self, unit)
        if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
        local name, realm = UnitName(unit)
        if not name or name == UNKNOWNOBJECT then return false end
        if realm and realm ~= "" then name = name .. "-" .. realm end

        local store = MUI_DB.data.recentAllies
        local entry = store[name]
        local met = entry == nil
        if met then
            entry = { name = name }
            store[name] = entry
        end
        local _, class = UnitClass(unit)
        local level = UnitLevel(unit)
        entry.class = class or entry.class
        -- A member out of range reports level 0.
        if level > 0 then entry.level = level end
        entry.zone = GetRealZoneText()
        entry.time = time()
        if met then self:_Trim() end
        return true
    end;

    -- One over the cap at most: entries come in one at a time.
    _Trim = function(self)
        local store = MUI_DB.data.recentAllies
        local count, oldest = 0, nil
        for _, entry in pairs(store) do
            count = count + 1
            if not entry.pinned and (not oldest or entry.time < oldest.time) then
                oldest = entry
            end
        end
        if count > MAX_ALLIES and oldest then
            store[oldest.name] = nil
        end
    end;

    -- Pinned first, then the latest met.
    GetList = function(self)
        local list = {}
        for _, entry in pairs(MUI_DB.data.recentAllies) do
            list[#list + 1] = entry
        end
        table.sort(list, function(a, b)
            if (a.pinned or false) ~= (b.pinned or false) then
                return a.pinned or false
            end
            if a.time ~= b.time then return a.time > b.time end
            return a.name < b.name
        end)
        return list
    end;

    SetPinned = function(self, entry, pinned)
        entry.pinned = pinned or nil
        if self.OnChanged then self:OnChanged() end
    end;

    Remove = function(self, entry)
        MUI_DB.data.recentAllies[entry.name] = nil
        if self.OnChanged then self:OnChanged() end
    end;
}

-- ---------------------------------------------------------------------
-- SocialAlliesRow: one ally. Retail's RecentAlliesEntryTemplate: name, level
-- and class on a line, when and where below it, the group invite button at
-- the right end, the pin beside it.
-- ---------------------------------------------------------------------
class "SocialAlliesRow" : extends "Button" {

    __init = function(self, parent, list)
        Button.__init(self, parent)
        self._list = list
        self:SetSize(LIST_W, ROW_H)
        -- The row's menu, as on retail's.
        self:RegisterForClicks("RightButtonUp")
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

        -- The friends list's own row: a faint tint, its blue highlight bar.
        local tint = FRIENDS_OFFLINE_BACKGROUND_COLOR
        local background = Texture(self, nil, "BACKGROUND")
        background:SetColorTexture(tint.r, tint.g, tint.b, tint.a)
        background:FillParentPadding(0, 1, 0, 1)
        local highlight = self:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetVertexColor(0.243, 0.570, 1)
        highlight:ClearAllPoints()
        highlight:FillParentPadding(0, 1, 0, 1)

        self._invite = Button(self)
        self._invite:SetSize(24, 32)
        self._invite:AlignParentRight(1)
        self._invite:SetNormalTexture(SHEET):SetTextureRegion(SHEET, SHEET_W, SHEET_H, 165, 29, 24, 32)
        self._invite:SetPushedTexture(SHEET):SetTextureRegion(SHEET, SHEET_W, SHEET_H, 191, 29, 24, 32)
        local glow = self._invite:SetHighlightTexture(SHEET)
        glow:SetTextureRegion(SHEET, SHEET_W, SHEET_H, 217, 29, 24, 32)
        glow:SetBlendMode("ADD")
        self._invite:SetClickSound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        self._invite:SetTooltip("ANCHOR_RIGHT", function(tip) tip:AddTitle(GROUP_INVITE) end)
        self._invite.OnClick = function() InviteToGroup(self._entry.name) end

        self._pin = Texture(self, nil, "ARTWORK")
        self._pin:SetTextureRegion(SHEET, SHEET_W, SHEET_H, 31, 29, 28, 28)
        self._pin:SetSize(16, 16)
        self._pin:AlignParentTopRight(4, 30)

        self._name = FontString(self, nil, "ARTWORK")
        self._name:SetFontSize(12)
        self._name:SetShadowOffset(1, -1)
        self._name:AlignParentTopLeft(5, 8)

        self._details = FontString(self, nil, "ARTWORK")
        self._details:SetFontSize(11)
        self._details:SetShadowOffset(1, -1)
        self._details:SetTextColor(1, 0.82, 0, 1)
        self._details:RightOf(self._name, 8)

        local grey = FRIENDS_GRAY_COLOR
        self._seen = self:_GreyLine(20, grey)
        self._zone = self:_GreyLine(32, grey)

        self.OnClick = function() self._list:ShowMenu(self) end
    end;

    -- A grey line `top` below the row's top edge, left of the invite button.
    _GreyLine = function(self, top, grey)
        local line = FontString(self, nil, "ARTWORK")
        line:SetFontSize(10)
        line:SetShadowOffset(1, -1)
        line:SetTextColor(grey.r, grey.g, grey.b, 1)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        line:SetSize(LIST_W - 70, 11)
        line:AlignParentTopLeft(top, 8)
        return line
    end;

    GetEntry = function(self)
        return self._entry
    end;

    SetEntry = function(self, entry)
        self._entry = entry
        local color = entry.class and MUI.ClassColor(entry.class) or NORMAL_FONT_COLOR
        self._name:SetText(entry.name)
        self._name:SetTextColor(color.r, color.g, color.b, 1)

        local class = entry.class and LOCALIZED_CLASS_NAMES_MALE[entry.class] or ""
        if entry.level then
            self._details:SetText(string.format(FRIENDS_LEVEL_TEMPLATE, entry.level, class))
        else
            self._details:SetText(class)
        end

        self._seen:SetText("Grouped " .. FriendsFrame_GetLastOnline(entry.time) .. " ago")
        self._zone:SetText(entry.zone)
        self._pin:SetVisible(entry.pinned and true or false)
    end;
}

-- ---------------------------------------------------------------------
-- SocialAlliesList: the scrolling list, and the menu of a row.
-- ---------------------------------------------------------------------
class "SocialAlliesList" : extends "Frame" {

    __init = function(self, parent, allies)
        Frame.__init(self, "Frame", parent)
        self._allies = allies
        self._rows = {}
        self:SetSize(LIST_W, LIST_H)

        self._scroll = ScrollFrame(self)
        self._scroll:FillParent()
        self._scroll:EnableMouseWheel(true)
        self._content = Frame("Frame", self._scroll)
        self._content:SetSize(LIST_W, 1)
        self._scroll:SetScrollChild(self._content)

        self._bar = MinimalScrollBar(self)
        self._bar:RightOf(self, 5, -1)
        self._bar:SetHeight(LIST_H - 6)
        self._bar:SetScrollSpeed(ROW_H)
        self._bar.OnScroll = function(_, value) self._scroll:SetVerticalScroll(value) end
        self._scroll:SetScript("OnMouseWheel", function(_, delta)
            self._bar:SetValue(self._bar:GetValue() - delta * ROW_H)
        end)

        self._empty = FontString(self, nil, "ARTWORK")
        self._empty:SetFontSize(11)
        self._empty:SetTextColor(0.5, 0.5, 0.5, 1)
        self._empty:SetWidth(LIST_W - 60)
        self._empty:CenterInParent()
        self._empty:SetText("Players you group with are listed here.")

        self:_BuildMenu()

        self:SetScript("OnShow", function() self:Refresh() end)
        allies.OnChanged = function()
            if self:IsVisible() then self:Refresh() end
        end
    end;

    _BuildMenu = function(self)
        self._menu = DropdownMenu(self, "MUI_SocialAlliesMenu")
        self._menu:SetMenuWidth(160)
        self._menu:SetItems({
            { type = "text", label = WHISPER, OnClick = function()
                ChatFrameUtil.SendTell(self._menuEntry.name)
            end },
            { type = "text", label = GROUP_INVITE, OnClick = function()
                InviteToGroup(self._menuEntry.name)
            end },
            { type = "text", label = ADD_FRIEND, OnClick = function()
                C_FriendList.AddFriend(self._menuEntry.name)
            end },
            { type = "separator" },
            { type = "text", label = "Pin", OnClick = function()
                self._allies:SetPinned(self._menuEntry, not self._menuEntry.pinned)
            end },
            { type = "text", label = REMOVE, OnClick = function()
                self._allies:Remove(self._menuEntry)
            end },
        })
    end;

    ShowMenu = function(self, row)
        self._menuEntry = row:GetEntry()
        self._menu:SetItemLabel(5, self._menuEntry.pinned and "Unpin" or "Pin")
        self._menu:SetToggleAnchor(row)
        self._menu:Open()
    end;

    Refresh = function(self)
        local list = self._allies:GetList()
        for i, entry in ipairs(list) do
            local row = self._rows[i]
            if not row then
                row = SocialAlliesRow(self._content, self)
                row:AlignParentTopLeft((i - 1) * ROW_H, 0)
                self._rows[i] = row
            end
            row:SetEntry(entry)
            row:Show()
        end
        for i = #list + 1, #self._rows do
            self._rows[i]:Hide()
        end
        self._content:SetHeight(math.max(#list * ROW_H, 1))
        self._empty:SetVisible(#list == 0)

        local range = math.max(#list * ROW_H - LIST_H, 0)
        self._bar:SetMinMax(0, range)
        self._bar:SetContentSize(LIST_H, LIST_H + range)
        self._scroll:SetVerticalScroll(self._bar:GetValue())
    end;
}
