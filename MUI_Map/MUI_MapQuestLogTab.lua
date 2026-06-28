-- MUI_MapQuestLogTab: quest-log tab — fully self-contained panel.
--
-- Each tab owns its own chrome (slider, scroll viewport, list bg,
-- shadow/border overlay, settings gear, search box) plus its content
-- (the quest-log category stack). Drop one in by parenting to a host
-- frame; tab manages its own scroll math via OnSizeChanged.
--
-- Construction:
--   MapQuestLogTab(parent)
--     parent — host frame (e.g. ModuleMap.bgFrame). Tab anchors to its
--              top-right edge with the standard 211-wide column layout.

local LOG_TEX        = MUI.TEX_SKIN .. "worldmap\\questlog"
local LOG_BG_TEX     = MUI.TEX_SKIN .. "worldmap\\questlog-bg"
local CATEGORIES_GAP = 4

-- Enum.UIMapType.Zone == 3, .Continent == 2 (Cosmic=0, World=1).
local ZONE_MAP_TYPE = 3


class "MapQuestLogTab" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent, "MUI_MapQuestLogTab")
        
        self:FillParent()

        self:_BuildChrome()
        self:_BuildContent()
        self:_BuildSettings()
        self:_BuildSearchBar()
        self:_WireScroll()
        self:_WireEvents()

        -- Re-flow scroll math whenever the panel resizes (parent or
        -- viewport changed). Refresh of category content is triggered
        -- by the host on map open via :Refresh().
        self:SetScript("OnSizeChanged", function() self:_RefreshScroll() end)

        self._categories = {}
        self:Refresh()
    end;

    -- Slider, list (with bg), scroll viewport, shadow + border + top art.
    _BuildChrome = function(self)

        self.slider = MinimalScrollBar(self, nil, 8, 8)
        self.slider:AlignParentRight(7)
        self.slider.upBtn:SetScale(1.1)
        self.slider.downBtn:SetScale(1.1)
        self.slider:AlignParentBottom(6)
        self.slider:AlignTop(self, 29)
        self.slider:SetScale(0.6)

        do
            self._borderContainer = Frame("Frame", self)
            self._borderContainer:LeftOf(self.slider, 6)
            self._borderContainer:AlignParentLeft()
            self._borderContainer:AlignParentBottom(5)
            self._borderContainer:AlignParentTop(17)

            self._bg = Texture(self._borderContainer, nil, "BACKGROUND")
            self._bg:FillParentPadding(0, 0, 0, 0)

            self._borderOverlay = Frame("Frame", self._borderContainer)
            self._borderOverlay:FillParent()
            self._borderOverlay:SetFrameLevel(self._borderContainer:GetFrameLevel() + 50)

            local border = NineSlice(self._borderOverlay)
            border:SetFromTextureRegion("skin\\worldmap\\questlog", 1024, 1024, 2, 801, 212, 212, 54, 54, 54, 54, 0.32)
            border:FillParent(-2)

            local topArt = Texture(border, nil, "OVERLAY")
            topArt:SetTextureRegion(LOG_TEX, 1024, 1024, 621, 126, 86, 32)
            topArt:AlignParentTop(-1)
            topArt:SetSize(86, 32)
            topArt:SetScale(0.32)

            local shadowBottom = Texture(self._borderOverlay, nil, "OVERLAY")
            shadowBottom:SetTextureRegion(LOG_TEX, 1024, 1024, 0, 348, 616, 131)
            shadowBottom:AlignParentBottom()
            shadowBottom:FillWidth()
            shadowBottom:SetVertexColor(1, 0, 0, 1)
            shadowBottom:SetHeight(20)
        end

        self.scroll = ScrollFrame(self._borderContainer)
        self.scroll:FillParentPadding(2, 4, 2, 4)

    end;

    -- The scrollChild + the visible content (bg, empty / not-found
    -- messages). Categories also become children of scrollChild during
    -- Refresh.
    _BuildContent = function(self)
        self.scrollChild = Frame("Frame", self.scroll)
        self.scrollChild:SetSize(1, 1)  -- placeholder; resized in _RefreshScroll
        self.scrollChild:SetScale(0.7)
        self.scroll:SetScrollChild(self.scrollChild)

        self._empty = FontString(self.scrollChild)
        self._empty:FillWidth(30, 46)
        self._empty:SetFont(MUI.FONT_CAL, 15)
        self._empty:SetTextColor(1, 1, 1, 1)
        self._empty:SetText("No quests available\n\n Accept new quests from characters marked by |TInterface\\GossipFrame\\AvailableQuestIcon:14:14|t sign over their head")

        self._notFound = FontString(self.scrollChild)
        self._notFound:SetFontSize(13)
        self._notFound:FillWidth(30, 46)
        self._notFound:AlignParentTop(20)
        self._notFound:SetText("Results not found")
        self._notFound:Hide()
    end;

    -- Slider <-> ScrollFrame wiring. Mouse wheel anywhere in the
    -- viewport routes to the slider, which drives the scroll offset.
    _WireScroll = function(self)
        self.slider:SetMinMax(0, 0)
        self.slider.OnScroll = function(_, value)
            self.scroll:SetVerticalScroll(value)
        end

        self.scroll:EnableMouseWheel(true)
        self.scroll:SetScript("OnMouseWheel", function(_, delta)
            local step = 20
            self.slider:SetValue(self.slider:GetValue() - delta * step)
        end)
    end;

    -- Compute slider range + thumb size from current viewport vs cached
    -- _contentHeight. Floors scrollChild height to viewport height so
    -- the bg fills the visible area when content is short. Uses the
    -- math we just committed (not a round-tripped GetHeight) to avoid
    -- floating-point residual ~1e-6 making range non-zero.
    _RefreshScroll = function(self)
        if not self.scroll then return end
        local s         = self.scrollChild:GetScale() or 1
        local viewportH = (self.scroll:GetHeight() or 0) / s
        local viewportW = (self.scroll:GetWidth()  or 0) / s
        local contentH  = self._contentHeight or 0
        local childH    = math.max(contentH, viewportH)

        self.scrollChild:SetWidth(viewportW)
        self.scrollChild:SetHeight(childH)
        self.scroll:UpdateScrollChildRect()

        local maxScroll = math.max(0, childH - viewportH)
        self.slider:SetMinMax(0, maxScroll)
        self.slider:SetContentSize(viewportH, childH)
        if self.slider:GetValue() > maxScroll then
            self.slider:SetValue(maxScroll)
        end
    end;

    -- Gear icon + DropdownMenu ("Show quest objectives"). Lives outside
    -- the scroll viewport so it stays visible while scrolling.
    _BuildSettings = function(self)
        local btn = Frame("Frame", self)
        btn:SetSize(9, 9.5)
        btn:Above(self.slider, 5, -0.5)
        btn:EnableMouse(true)

        local art = Texture(btn, nil, "ARTWORK")
        art:SetTextureRegion(LOG_TEX, 1024, 1024, 825, 123, 29, 31)
        art:SetSize(btn:GetWidth(), btn:GetHeight())
        art:CenterInParent()

        local hl = Texture(btn, nil, "HIGHLIGHT")
        hl:SetTextureRegion(LOG_TEX, 1024, 1024, 825, 123, 29, 31)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
        hl:SetSize(btn:GetWidth(), btn:GetHeight())
        hl:CenterInParent()

        self._settingsMenu = DropdownMenu(btn, "MUI_MapQuestLogSettings", btn)
        self._settingsMenu:SetMenuWidth(180)
        self._settingsMenu:SetAnchor(function(popup, a)
            popup:Below(a, -4)
            popup:AlignLeft(a, -10)
        end)
        self._settingsMenu:SetItems({
            {
                type    = "checkbox",
                label   = "Show quest objectives",
                checked = MUI_DB.settings.questHelper.showObjectivesInQuestLog,
                OnChanged = function(_, checked)
                    MUI_DB.settings.questHelper.showObjectivesInQuestLog = checked
                    self:Refresh()
                end,
            },
            {
                type    = "checkbox",
                label   = "Show quest level",
                checked = MUI_DB.settings.questHelper.showQuestLevel,
                OnChanged = function(_, checked)
                    MUI_DB.settings.questHelper.showQuestLevel = checked
                    self:Refresh()
                    MUI_QuestHelper.tracker:Rebuild()
                end,
            },
            {
                type    = "checkbox",
                label   = "Color quests by level",
                checked = MUI_DB.settings.questHelper.showQuestDifficultyColor,
                OnChanged = function(_, checked)
                    MUI_DB.settings.questHelper.showQuestDifficultyColor = checked
                    self:Refresh()
                    MUI_QuestHelper.tracker:Rebuild()
                end,
            },
            {
                type    = "checkbox",
                label   = "Auto-collapse categories",
                checked = MUI_DB.settings.questHelper.autoCollapseQuestCategories,
                OnChanged = function(_, checked)
                    MUI_DB.settings.questHelper.autoCollapseQuestCategories = checked
                    -- Turning the toggle off should immediately expand
                    -- every category (collapse pass would otherwise
                    -- only run on the next map / focus change).
                    if not checked then
                        for _, cat in ipairs(self._categories) do
                            if cat:IsShown() then cat:SetCollapsed(false) end
                        end
                        self:_RecalcHeight()
                    else
                        self:_ApplyMapAwareCollapse()
                    end
                end,
            },
        })

        btn:SetScript("OnMouseDown", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            art:ClearAllPoints();    art:CenterInParent(0.5, -0.5)
            hl:ClearAllPoints();     hl:CenterInParent(0.5, -0.5)
            self._settingsMenu:Toggle()
        end)
        btn:SetScript("OnMouseUp", function()
            art:ClearAllPoints();    art:CenterInParent(0, 0)
            hl:ClearAllPoints();     hl:CenterInParent(0, 0)
        end)

        self._settingsBtn = btn
    end;

    -- Search box, sits to the left of the gear icon.
    _BuildSearchBar = function(self)
        self._searchBox = SearchBox(self, "MUI_QuestLogSeachBox")
        self._searchBox:SetHint("Search in the quest list")
        self._searchBox:SetScale(0.6)
        self._searchBox:SetWidth(197 / 0.6)
        self._searchBox:LeftOf(self._settingsBtn, 4, -1)

        -- SearchBox already sets OnTextChanged for its own clear-button
        -- logic. Chain ours after it so both run.
        local prev = self._searchBox.OnTextChanged
        self._searchBox.OnTextChanged = function(box, text)
            if prev then prev(box, text) end
            self._filter = text or ""
            self:Refresh()
        end
    end;

    -- Subscribe to log + tracker events that should rebuild or
    -- partially refresh the visible categories.
    _WireEvents = function(self)
        -- QUEST_LOG_UPDATE fires after accept / abandon / objective
        -- progress; rebuild the list every time so titles, completion
        -- state and objective text stay in sync.
        self:RegisterEventHandler("QUEST_LOG_UPDATE", function()
            self:Refresh()
        end)

        -- Focus-toggle propagation: clicking a POI button fires this
        -- listener — refresh every category's POIs so the focused
        -- glow lights up on the new quest and clears on the old one.
        -- Listens to ALL focus changes (including non-quest); category
        -- POIs draw nothing for non-quest focus so the rebuild is cheap.
        MUI_FocusManager:RegisterChangeListener(function()
            for _, cat in ipairs(self._categories) do
                if cat:IsShown() then cat:RefreshFocus() end
            end
            -- Auto-collapse rule depends on which quest is focused
            -- (focused quest's category never collapses), so re-apply.
            self:_ApplyMapAwareCollapse()
        end)

        -- Re-apply auto-collapse whenever the displayed map changes.
        -- The POI manager rebuilds on the same hook; our projection
        -- check is independent of the POI manager's state, so order
        -- doesn't matter.
        if WorldMapFrame and WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                self:_ApplyMapAwareCollapse()
            end)
        end

        -- Tracking-toggle propagation: changes from elsewhere (the
        -- QuestTracker, or SetFocusedQuest's auto-untrack-clear side
        -- effect) sync back to our checkboxes without rebuilding.
        MUI_QuestHelper:RegisterTrackingListener(function()
            for _, cat in ipairs(self._categories) do
                if cat:IsShown() then cat:RefreshTracking() end
            end
        end)
    end;

    -- Group active quests by zone (the quest log's header rows ARE
    -- the zone names in Era), pour them into QuestLogCategory blocks,
    -- stack top-down on scrollChild, and update the slider math.
    Refresh = function(self)
        local byZone, zoneOrder = {}, {}
        local zone = "Misc"
        local filter      = (self._filter or ""):lower()
        local hasAnyQuest = false   -- any quest in the log, ignoring the filter
        for i = 1, GetNumQuestLogEntries() do
            local title, level, _, isHeader, _, isComplete, _, questID
                = GetQuestLogTitle(i)
            if isHeader then
                zone = title or "Misc"
            elseif questID and questID > 0 then
                hasAnyQuest = true
                local matches = filter == ""
                    or string.find((title or ""):lower(), filter, 1, true) ~= nil
                if matches then
                    local objectives = {}
                    local numObj = GetNumQuestLeaderBoards(i) or 0
                    for j = 1, numObj do
                        local text, objType, finished
                            = GetQuestLogLeaderBoard(j, i)
                        objectives[j] = {
                            text     = text or "",
                            type     = objType,
                            finished = finished and true or false,
                        }
                    end

                    if not byZone[zone] then
                        byZone[zone] = {}
                        zoneOrder[#zoneOrder + 1] = zone
                    end
                    local list = byZone[zone]
                    list[#list + 1] = {
                        questId    = questID,
                        title      = title or "",
                        level      = level or 0,
                        isComplete = isComplete == 1,
                        objectives = objectives,
                    }
                end
            end
        end

        -- Chain-anchor categories: first one to TOP, each subsequent
        -- to the previous category's BOTTOM. When a category collapses
        -- or expands, the ones below auto-flow because their TOP
        -- anchor stays attached to the previous category's BOTTOM.
        local n = 0
        local prev

        for _, name in ipairs(zoneOrder) do
            local entries = byZone[name]
            if entries and #entries > 0 then
                n = n + 1
                local cat = self._categories[n]
                if not cat then
                    cat = QuestLogCategory(self.scrollChild,
                        "MUI_MapQuestLog_Cat" .. n, name)
                    self._categories[n] = cat
                end
                cat.label:SetText(name)
                cat:ClearAllPoints()
                if prev then
                    cat:Below(prev, CATEGORIES_GAP)
                else
                    cat:AlignParentTop(10)
                end
                cat:FillWidth(-6)
                cat:SetQuests(entries)
                cat:Show()
                cat._OnLayoutChanged = function()
                    self:_RecalcHeight()
                end
                prev = cat
            end
        end
        for i = n + 1, #self._categories do
            self._categories[i]:Hide()
        end

        -- Empty-state messaging:
        --   * truly no quests in the log → "No quests available..." (_empty)
        --   * has quests but the filter matches none → "Results not found"
        --     (_notFound)
        --   * filter matches at least one quest → both hidden, list visible
        local filtered = (self._filter or "") ~= "" and n == 0
        self._empty:SetVisible(not hasAnyQuest)
        self._notFound:SetVisible(filtered)
        self._bg:SetTextureRegion(LOG_BG_TEX, 2048, 1024, hasAnyQuest and 616 or 0, 0, 616, 1022)
        self:_ApplyMapAwareCollapse()
        self:_RecalcHeight()
    end;

    -- Auto-collapse rule (opt-in via the Quest Log settings checkbox
    -- "Auto-collapse categories" — default OFF):
    --   ZONE-level map: a category is expanded iff it contains the
    --                   focused quest OR any of its quests has a POI
    --                   that projects onto the currently displayed map.
    --   Continent / World / Cosmic: expand every category — POIs
    --                   aren't shown there anyway, so the per-zone
    --                   filter would over-collapse.
    -- Re-runs on Refresh, on map change, and on focus change.
    _ApplyMapAwareCollapse = function(self)
        local s = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        if not s or not s.autoCollapseQuestCategories then return end

        local mapId = WorldMapFrame and WorldMapFrame:GetMapID()
        if not mapId then return end
        local info = C_Map.GetMapInfo(mapId)
        if not info then return end

        local zoneLevel = (info.mapType == ZONE_MAP_TYPE)
        local focusKind, focusKey = MUI_FocusManager:GetFocus()
        local focusedQuestId = (focusKind == "quest") and focusKey or nil

        local changed = false
        for _, cat in ipairs(self._categories) do
            if cat:IsShown() then
                local collapse
                if zoneLevel then
                    local keep = false
                    for _, row in ipairs(cat.quests) do
                        if row:IsShown() and row.questId then
                            if row.questId == focusedQuestId
                               or self:_IsPoiOnDisplayedMap(row.questId, mapId) then
                                keep = true
                                break
                            end
                        end
                    end
                    collapse = not keep
                else
                    collapse = false
                end
                if cat._collapsed ~= collapse then
                    cat:SetCollapsed(collapse)
                    changed = true
                end
            end
        end
        if changed then self:_RecalcHeight() end
    end;

    -- Same projection logic as MapQuestPoiManager.Rebuild — picks the
    -- quest's stationary target (no transport reroute) and tests
    -- whether it falls inside the displayed map's [0,1] rect. Returns
    -- false for untracked quests and for quests whose target lands on
    -- a different continent than the displayed map.
    _IsPoiOnDisplayedMap = function(self, questId, mapId)
        if not MUI_QuestHelper:IsTracked(questId) then return false end
        local target = MUI_FocusManager:PickTarget("quest", questId, true)
        if not target or not target.continent then return false end
        local nx, ny = MUI_MapMath:WorldToMap(
            mapId, target.wx, target.wy, target.continent)
        return nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1
    end;

    -- Sum the visible categories' heights into _contentHeight, then
    -- re-run the scroll math so the slider's range matches reality.
    _RecalcHeight = function(self)
        local h = 0
        local count = 0
        for _, cat in ipairs(self._categories) do
            if cat:IsShown() then
                h = h + (cat:GetHeight() or 0) + CATEGORIES_GAP
                count = count + 1
            end
        end
        if count > 0 then h = h - CATEGORIES_GAP end
        self._contentHeight = h + 20
        self:_RefreshScroll()
    end;
}
