-- MUI_MapQuestLog: quest list widget for the WorldMapFrame's right-side
-- tab panel. Reuses the QuestTracker's visual hierarchy (POI button +
-- title + objective rows; SecondaryHeader strip per category) but wires
-- the data side to the full quest log instead of the tracker watcher.
--
-- Public surface used by MUI_Map:
--   QuestLogCategory(parent, name, label) — header + body of quest rows
--   QuestLogQuest(parent, name)           — single quest block (POI + title + objectives)
--
-- Sub-widgets that are shared with the tracker (QuestPoiButton,
-- QuestTrackerObjective, QuestTrackerCollapseBtn) are loaded by
-- MUI_QuestHelper before MUI_Map and are referenced as-is here.

local HEADER_QUEST_PAD    = -2.5
local QUEST_GAP           = 2
local OBJECTIVE_GAP       = 2

local SECONDARY_H         = 18
local SECONDARY_BTN       = 14

local POI_SIZE            = 29
local POI_GLOW            = 56

local TITLE_H             = 20
local OBJECTIVE_H         = 14
local BULLET_W            = 6

local _DIFF_RED    = { 1.00, 0.10, 0.10 }
local _DIFF_ORANGE = { 1.00, 0.50, 0.25 }
local _DIFF_YELLOW = { 1.00, 1.00, 0.00 }
local _DIFF_GREEN  = { 0.25, 0.75, 0.25 }
local _DIFF_GRAY   = { 0.62, 0.62, 0.62 }
local _GOLD        = { 1.00, 0.82, 0.00 }
local _GOLD_HOVER  = { 1.00, 1.00, 0.00 }

local function _difficultyColor(level)
    local diff = level - UnitLevel("player")
    if     diff >=  5                                   then return _DIFF_RED
    elseif diff >=  3                                   then return _DIFF_ORANGE
    elseif diff >= -2                                   then return _DIFF_YELLOW
    elseif -diff <= (GetQuestGreenRange("player") or 5) then return _DIFF_GREEN
    else                                                     return _DIFF_GRAY
    end
end

local function _questColors(level, hover)
    local diffOn = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
                   and MUI_DB.settings.questHelper.showQuestDifficultyColor
    if diffOn and level and level > 0 then
        local c = _difficultyColor(level)
        if hover then
            return math.min(1, c[1] * 0.7 + 0.3),
                   math.min(1, c[2] * 0.7 + 0.3),
                   math.min(1, c[3] * 0.7 + 0.3)
        end
        return c[1], c[2], c[3]
    end
    local g = hover and _GOLD_HOVER or _GOLD
    return g[1], g[2], g[3]
end

-- specialFlags bit 0 = repeatable (Questie's QuestieDB.IsRepeatable).
local function _isRepeatable(questId)
    if not MUI_QuestDB then return false end
    local q = MUI_QuestDB:Get(questId)
    if not q then return false end
    local f = q.specialFlags
    return f and (f % 2) >= 1 or false
end

-- Era's quest log API is index-based — GetQuestLogQuestText / SelectQuestLogEntry
-- only operate on the "currently selected" log entry. Map back from a stable
-- questId to the live log index by walking the log.
local function _findQuestLogIndex(questId)
    if not questId then return nil end
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, _, _, _, _, qID = GetQuestLogTitle(i)
        if qID == questId then return i end
    end
    return nil
end

class "QuestLogQuest" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self:EnableMouse(true)

        self.poi = QuestPoiButton(self)
        self.poi:ClearAllPoints()
        self.poi:AlignParentTopLeft(-4, 6)
        self.poi.OnClick = function()
            if not self.questId then return end
            if MUI_QuestHelper:IsFocused(self.questId) then
                MUI_QuestHelper:SetFocusedQuest(nil)
            else
                MUI_QuestHelper:SetFocusedQuest(self.questId)
            end
        end
        -- POI is a child frame, so hovering it pulls the cursor OUT of
        -- the row's mouse rect (row OnLeave fires). Mirror the row's
        -- hover-quest push/pop on the POI itself so the world-map
        -- objective hull stays visible while the cursor is on the POI.
        self.poi:HookScript("OnEnter", function()
            if self.questId then MUI_QuestHelper:PushQuestHover(self.questId) end
        end)
        self.poi:HookScript("OnLeave", function()
            if self.questId then MUI_QuestHelper:PopQuestHover(self.questId) end
        end)

        self.tracking = CheckBoxThin(self)
        self.tracking:AlignParentTopRight(4, 21)
        self.tracking:SetChecked(true)
        -- Toggle MUI_QuestHelper's per-quest tracked state. SetChecked
        -- (used by SetQuest to sync external state) does NOT fire
        -- OnChanged, so this only runs on actual user clicks.
        self.tracking.OnChanged = function(_, checked)
            if self.questId then
                MUI_QuestHelper:SetTracked(self.questId, checked)
            end
        end

        self.title = FontString(self, nil, "ARTWORK")
        self.title:SetFont(MUI.FONT, 10.5)
        self.title:SetShadowOffset(1, -1)
        self.title:SetTextColor(1, 0.82, 0, 1)
        self.title:SetJustifyH("LEFT")
        self.title:RightOf(self.poi, -2, 0.5)
        self.title:LeftOf(self.tracking)

        self.titleHover = Texture(self, nil, "ARTWORK")
        self.titleHover:SetTextureRegion(MUI.TEX_SKIN .. "worldmap\\questlog", 1024, 1024, 0, 692, 616, 105)
        self.titleHover:AlignLeft(self.title)
        self.titleHover:AlignRight(self)
        self.titleHover:AlignTop(self.title, -4)
        self.titleHover:AlignBottom(self.title, -4)
        self.titleHover:Hide()

        self.objContainer = Frame("Frame", self)
        self.objContainer:ClearAllPoints()
        self.objContainer:SetPoint("TOPLEFT",  self.title, "BOTTOMLEFT", 1, -4)
        self.objContainer:SetPoint("TOPRIGHT", self.tracking, "BOTTOMLEFT", 0, 0)

        -- Dual-purpose text row shown when there are no per-objective
        -- rows. Grey "Can Turn In." when entry.isComplete; white DB
        -- objectivesText when the quest simply has no leaderboard objectives.
        self.turnInLabel = FontString(self.objContainer, nil, "ARTWORK")
        self.turnInLabel:SetFont(MUI.FONT, 10.5)
        self.turnInLabel:SetShadowOffset(1, -1)
        self.turnInLabel:SetJustifyH("LEFT")
        self.turnInLabel:ClearAllPoints()
        self.turnInLabel:AlignParentTopLeft(0, 0)
        self.turnInLabel:AlignParentTopRight(0, 0)
        self.turnInLabel:Hide()

        self.objectives = {}
        self._dimTargets = { self.title, self.objContainer, }

        self:SetScript("OnEnter", function()
            self:_SyncHover(true)
            if self.questId then MUI_QuestHelper:PushQuestHover(self.questId) end
        end)
        self:SetScript("OnLeave", function()
            self:_SyncHover(false)
            if self.questId then MUI_QuestHelper:PopQuestHover(self.questId) end
        end)

        self:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                self:_ShowContextMenu()
            elseif button == "LeftButton" and self.questId then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                MUI_ModuleMap:ShowQuestDescription(self.questId)
                -- Navigate the world map to the zone containing the
                -- quest's POI. Skip transport reroute (third arg true)
                -- so we open the ACTUAL quest zone, not the boat dock —
                -- the POI on the world map is at the actual location, so
                -- this matches.
                local target = MUI_FocusManager:PickTarget("quest", self.questId, true)
                if target and target.continent then
                    local zoneMap = MUI_MapMath:GetBestMapForWorld(
                        target.continent, target.wx, target.wy)
                    if zoneMap then WorldMapFrame:SetMapID(zoneMap) end
                end
            end
        end)

        self:SetTooltip("ANCHOR_NONE", function(tooltip)

            if not self.questId then return end
            local idx = _findQuestLogIndex(self.questId)
            if not idx then return end

            local prev = GetQuestLogSelection() or 0
            SelectQuestLogEntry(idx)
            local _, objectivesText = GetQuestLogQuestText()
            SelectQuestLogEntry(prev)

            tooltip:ClearAllPoints()
            tooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 16, 4)

            tooltip:SetMinimumWidth(240)
            tooltip:AddTitle(self.title:GetText() or "", true)

            if objectivesText and objectivesText ~= "" then
                tooltip:AddBlank()
                tooltip:AddLine(objectivesText, 1, 1, 1, true)
            end

            local objs = self._entry and self._entry.objectives
            if objs and #objs > 0 then
                tooltip:AddBlank()
                for _, o in ipairs(objs) do
                    if o.text and o.text ~= "" then
                        if o.finished then
                            tooltip:AddLine("-" .. o.text, 0.4, 0.85, 0.4, true)
                        else
                            tooltip:AddLine("-" .. o.text, 1, 1, 1, true)
                        end
                    end
                end
            end

            tooltip:AddBlank()
            tooltip:AddLine("<Click for more details>", 0, 1, 0)
            
        end)

    end;

    SetQuest = function(self, questId, entry)
        self.questId = questId
        self._entry  = entry
        self._level  = entry.level
        
        self:SetAlpha(1)

        -- Re-apply normal-state colors. Refresh re-binds the row, so
        -- toggling "Color quests by level" off and on flows through
        -- here on the next QUEST_LOG_UPDATE / Refresh.
        local r, g, b = _questColors(self._level, false)
        self.title:SetTextColor(r, g, b, 1)

        self.poi:SetRecurring(_isRepeatable(questId))
        self.poi:SetComplete(entry.isComplete and true or false)
        self:RefreshFocus()
        self:RefreshTracking()

        for _, row in ipairs(self.objectives) do row:Hide() end

        -- Per-quest objective body is gated by the QuestLog settings
        -- gear menu's "Show quest objectives" toggle. When off, the
        -- row collapses to title + POI + tracking checkbox only — no
        -- objective lines, no "Can Turn In." indicator.
        local showObjs = MUI_DB and MUI_DB.settings
            and MUI_DB.settings.questHelper
            and MUI_DB.settings.questHelper.showObjectives
        if showObjs == nil then showObjs = true end

        local showLvl = MUI_DB and MUI_DB.settings
            and MUI_DB.settings.questHelper
            and MUI_DB.settings.questHelper.showQuestLevel

        local title = entry.title or ("quest " .. questId)
        if showLvl then 
            title = "[".. entry.level .. "] " .. title
        end
        self.title:SetText(title)

        if not showObjs then
            self.turnInLabel:Hide()
            self.objContainer:SetHeight(1)
            self:_LayoutHeight()
            return
        end

        if entry.isComplete then
            self.turnInLabel:SetText("Can Turn In")
            self.turnInLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            self.turnInLabel:Show()
            self.objContainer:SetHeight(math.max(OBJECTIVE_H,
                self.turnInLabel:GetStringHeight() or 0))
            self:_LayoutHeight()
            return
        end

        local y, count = 0, 0
        if entry.objectives then
            for _, o in ipairs(entry.objectives) do
                if o and o.text and o.text ~= "" then
                    count = count + 1
                    local row = self.objectives[count]
                    if not row then
                        row = QuestTrackerObjective(self.objContainer)
                        self.objectives[count] = row
                    end
                    row:ClearAllPoints()
                    row:AlignParentTop(y)
                    row:FillWidth()
                    row:SetObjective(o)
                    row:Show()
                    y = y + (row:GetHeight() or OBJECTIVE_H) + OBJECTIVE_GAP
                end
            end
        end

        if count == 0 then
            -- No leaderboard objectives — fall back to the DB's
            -- objectivesText so quests like "A Threat Within" still show
            -- a description under the title.
            local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
            local lines = q and q.objectivesText
            if lines and #lines > 0 then
                local text = type(lines) == "table"
                             and table.concat(lines, "\n")
                             or tostring(lines)
                self.turnInLabel:SetText(text)
                self.turnInLabel:SetTextColor(1, 1, 1, 1)
                self.turnInLabel:Show()
                y = math.max(OBJECTIVE_H,
                    self.turnInLabel:GetStringHeight() or 0)
            else
                self.turnInLabel:Hide()
            end
        else
            self.turnInLabel:Hide()
        end

        -- After the loop, y = sum(rowHeights) + n*OBJECTIVE_GAP. The
        -- container should be that minus ONE trailing gap (gaps separate
        -- rows, no gap below the last). The previous `2*OBJECTIVE_GAP`
        -- under-counted by a full gap, so the row was set 2px shorter
        -- than its visible content — across many quests the category
        -- body, the tabQuestLog childH, and the slider's max-scroll
        -- all under-counted by the same amount, which is why visible
        -- content clipped past the slider's reported bottom.
        self.objContainer:SetHeight(y == 0 and 1 or (y - OBJECTIVE_GAP))
        self:_LayoutHeight()
    end;

    -- Use the title's ACTUAL rendered height (it auto-wraps when the
    -- text is wider than the gap between POI and tracking checkbox);
    -- without that, wrapped titles undercount the row height.
    _LayoutHeight = function(self)
        local body   = self.objContainer:GetHeight() or 0
        local titleH = math.max(TITLE_H, self.title:GetStringHeight() or 0)
        local h = math.max(POI_SIZE, titleH + 2 + body)
        self:SetHeight(h)
    end;

    RefreshFocus = function(self)
        if not self.questId then return end
        self.poi:SetFocused(MUI_QuestHelper:IsFocused(self.questId))
    end;

    RefreshTracking = function(self)
        if not self.questId then return end
        self.tracking:SetChecked(MUI_QuestHelper:IsTracked(self.questId))
    end;

    _SyncHover = function(self, isOver)
        local r, g, b = _questColors(self._level, isOver)
        self.title:SetTextColor(r, g, b, 1)
        if isOver then
            self.titleHover:Show()
            self.objContainer:SetAlpha(1)
            self.poi.innerGlow:Show()
        else
            self.titleHover:Hide()
            self.objContainer:SetAlpha(0.80)
            self.poi.innerGlow:Hide()
        end
    end;

    -- Right-click context menu anchored at the cursor click point.
    -- Items: Track/Untrack (label flips on tracking state), Focus,
    -- Share quest (greyed when not pushable), Abandon quest.
    _ShowContextMenu = function(self)
        if not self.questId then return end

        if not self._contextMenu then
            self._contextMenu = DropdownMenu(self, nil, self)
            self._contextMenu:SetMenuWidth(150)
        end

        -- Anchor the popup so its TOPLEFT lands at the cursor. Capture
        -- the cursor pos NOW (not in the closure call later), so the
        -- popup pins to where the user actually clicked even if the
        -- mouse moves before the menu lays out.
        local cx, cy  = GetCursorPosition()
        local s       = UIParent:GetEffectiveScale()
        local mx, my  = cx / s, cy / s
        self._contextMenu:SetAnchor(function(popup)
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", mx, my)
        end)

        -- Probe shareability via the index-based quest API. SaveAndRestore
        -- the native quest log selection because GetQuestLogPushable reads
        -- from the currently-selected entry.
        local idx       = _findQuestLogIndex(self.questId)
        local prevSel   = idx and (GetQuestLogSelection() or 0) or 0
        local canShare  = false
        if idx then
            SelectQuestLogEntry(idx)
            canShare = (GetQuestLogPushable() == 1) and (GetNumGroupMembers() > 0)
            SelectQuestLogEntry(prevSel)
        end

        local isTracked = MUI_QuestHelper:IsTracked(self.questId)
        local questId   = self.questId  -- close over local; self.questId may rebind on rebuild

        self._contextMenu:SetItems({
            { type = "text", label = isTracked and "Untrack quest" or "Track quest",
              OnClick = function()
                  MUI_QuestHelper:SetTracked(questId, not isTracked)
              end },
            { type = "text", label = "Focus quest",
              OnClick = function()
                  MUI_QuestHelper:SetFocusedQuest(questId)
              end },
            { type = "text", label = "Share quest", disabled = not canShare,
              OnClick = function()
                  local i = _findQuestLogIndex(questId)
                  if not i then return end
                  local prev = GetQuestLogSelection() or 0
                  SelectQuestLogEntry(i)
                  QuestLogPushQuest()
                  SelectQuestLogEntry(prev)
              end },
            { type = "text", label = "Abandon quest",
              OnClick = function()
                  local i = _findQuestLogIndex(questId)
                  if not i then return end
                  local prev = GetQuestLogSelection() or 0
                  SelectQuestLogEntry(i)
                  SetAbandonQuest()
                  StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
                  SelectQuestLogEntry(prev)
              end },
        })

        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self._contextMenu:Open()
    end;
}

-- QuestLogCategory: SecondaryHeader strip + list of quest rows.
class "QuestLogCategory" : extends "Frame" {
    __init = function(self, parent, name, label)
        Frame.__init(self, "Frame", parent, name)

        self.header = Frame("Frame", self)
        self.header:SetHeight(SECONDARY_H)
        self.header:ClearAllPoints()
        self.header:AlignParentTop()
        self.header:FillWidth()
        self.header:EnableMouse(true)

        self.headerBg = NineSlice(self.header)
        self.headerBg:SetFromTextureRegion("skin\\worldmap\\questlog", 1024, 1024, 617, 211, 127, 40, 9, 8, 11, 8, 0.5)
        self.headerBg:ClearAllPoints()
        self.headerBg:FillWidth(15)
        self.headerBg:SetHeight(SECONDARY_H)

        self.headerBgHL = NineSlice(self.header)
        self.headerBgHL:SetFromTextureRegion("skin\\worldmap\\questlog", 1024, 1024, 617, 211, 127, 40, 9, 8, 11, 8, 0.5)
        self.headerBgHL:ClearAllPoints()
        self.headerBgHL:SetAllPoints(self.headerBg)
        self.headerBgHL:SetBlendMode("ADD")
        self.headerBgHL:SetAlpha(0.4)
        self.headerBgHL:Hide()

        self.collapse = QuestTrackerCollapseBtn(self.header, nil, "secondary", SECONDARY_BTN)
        self.collapse:ClearAllPoints()
        self.collapse:AlignParentRight(21)
        -- The collapse button stays as a visual indicator only — the
        -- ENTIRE header strip is the click target now (set up below).
        -- Disabling mouse on the button avoids the parent+child both-
        -- mouse-enabled trap that confuses Era's focus tracker.
        self.collapse:EnableMouse(false)

        self.label = FontString(self.headerBg, nil, "OVERLAY")
        self.label:SetFont(MUI.FONT_CAL, 14)
        self.label:SetShadowOffset(1, -1)
        self.label:SetTextColor(0.5, 0.5, 0.5, 1)
        self.label:SetJustifyH("LEFT")
        self.label:ClearAllPoints()
        self.label:AlignParentLeft(6, 0)
        self.label:LeftOf(self.collapse)
        self.label:SetText(label or "")

        self.body = Frame("Frame", self)
        self.body:ClearAllPoints()
        self.body:SetPoint("TOPLEFT",  self.header, "BOTTOMLEFT",  0, -HEADER_QUEST_PAD)
        self.body:SetPoint("TOPRIGHT", self.header, "BOTTOMRIGHT", 0, -HEADER_QUEST_PAD)

        self.quests     = {}
        self._collapsed = false

        -- Hover + click target is the whole header strip. OnMouseUp
        -- guards on IsMouseOver so clicks released outside the header
        -- (drag-off) don't fire ToggleCollapsed.
        self.header:SetScript("OnEnter", function()
            self.label:SetTextColor(1, 1, 1, 1)
            self.headerBgHL:Show()
        end)
        self.header:SetScript("OnLeave", function()
            self.label:SetTextColor(0.5, 0.5, 0.5, 1)
            self.headerBgHL:Hide()
        end)
        self.header:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            if self.header:IsMouseOver() then
                self:ToggleCollapsed()
            end
        end)
    end;

    SetQuests = function(self, entries)
        local seen = {}
        local bY   = 8.5
        for _, row in ipairs(self.quests) do row:Hide() end

        for i, entry in ipairs(entries or {}) do
            local row = self.quests[i]
            if not row then
                row = QuestLogQuest(self.body)
                self.quests[i] = row
            end
            row:ClearAllPoints()
            row:AlignParentTop(bY)
            row:FillWidth()
            row:SetQuest(entry.questId, entry)
            row:Show()
            row:_SyncHover()
            bY = bY + row:GetHeight() + QUEST_GAP
            seen[entry.questId] = true
        end

        self.body:SetHeight(bY == 0 and 1 or (bY - QUEST_GAP))
        self:_ApplyCollapsed()
        return seen
    end;

    RefreshFocus = function(self)
        for _, row in ipairs(self.quests) do
            if row:IsShown() then row:RefreshFocus() end
        end
    end;

    RefreshTracking = function(self)
        for _, row in ipairs(self.quests) do
            if row:IsShown() then row:RefreshTracking() end
        end
    end;

    ToggleCollapsed = function(self)
        self._collapsed = not self._collapsed
        PlaySound(self._collapsed
            and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
            or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self.collapse:SetExpanded(not self._collapsed)
        self:_ApplyCollapsed()
        if self._OnLayoutChanged then self:_OnLayoutChanged() end
    end;

    -- Programmatic collapse setter — no click sound, no _OnLayoutChanged
    -- callback (caller batches the layout fix-up). Used by
    -- MapQuestLogTab's map-aware auto-collapse pass.
    SetCollapsed = function(self, collapsed)
        collapsed = collapsed and true or false
        if self._collapsed == collapsed then return end
        self._collapsed = collapsed
        self.collapse:SetExpanded(not collapsed)
        self:_ApplyCollapsed()
    end;

    _ApplyCollapsed = function(self)
        if self._collapsed then
            self.body:Hide()
            self:SetHeight(SECONDARY_H)
        else
            self.body:Show()
            self:SetHeight(SECONDARY_H + HEADER_QUEST_PAD + math.max(self.body:GetHeight() or 0, 0))
        end
    end;

    IsEmpty = function(self)
        for _, row in ipairs(self.quests) do
            if row:IsShown() then return false end
        end
        return true
    end;
}
