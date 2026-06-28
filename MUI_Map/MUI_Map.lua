-- MUI_Map: reskin-in-place of Blizzard's WorldMapFrame.
--
-- WorldMapFrame is UIPanel-managed and ESC-handled — keep the native frame
-- intact (no SetParent / :Hide() on the frame itself) so ShowUIPanel /
-- HideUIPanel / panel queue / ESC binding all keep working. Strip its
-- visuals and overlay our own:
--   * Hide every region and every child of WorldMapFrame except the actual
--     WorldMapDetailFrame (the map tiles).
--   * Stretch a MetalBorderPortrait across the frame (round portrait
--     socket TL, double close/minimize corner TR).
--   * Reskin the native close button in place — wrapping it (not replacing)
--     keeps its secure OnClick that calls HideUIPanel.
-- Re-apply on every OnShow because Blizzard's own scripts re-anchor /
-- re-show internal pieces when the frame opens.

-- NavBar classes (MapNavBar, MapNavButton, MapNavHomeButton, MapNavDropdownButton)
-- and the texcoord/size constants live in MUI_MapNavigation.lua.

-- Era zone level ranges (vanilla 1.15.x). Used to append "(min-max)" to the
-- hover ZoneLabel. Keys must match C_Map.GetMapChildrenInfo's `name` field
-- (localized — these are en-us). Capital cities / battlegrounds / Moonglade
-- are intentionally omitted (no leveling content or trivial range).

local TEX = MUI.TEX_BASE .. "objecticonsatlas"
local ZONE_LEVELS = {
    -- Eastern Kingdoms
    ["Elwynn Forest"]        = {  1, 10 },
    ["Dun Morogh"]           = {  1, 10 },
    ["Tirisfal Glades"]      = {  1, 10 },
    ["Westfall"]             = { 10, 20 },
    ["Loch Modan"]           = { 10, 20 },
    ["Silverpine Forest"]    = { 10, 20 },
    ["Redridge Mountains"]   = { 15, 25 },
    ["Duskwood"]             = { 18, 30 },
    ["Wetlands"]             = { 20, 30 },
    ["Hillsbrad Foothills"]  = { 20, 30 },
    ["Alterac Mountains"]    = { 30, 40 },
    ["Arathi Highlands"]     = { 30, 40 },
    ["Stranglethorn Vale"]   = { 30, 45 },
    ["Badlands"]             = { 35, 45 },
    ["Swamp of Sorrows"]     = { 35, 45 },
    ["The Hinterlands"]      = { 40, 50 },
    ["Searing Gorge"]        = { 45, 55 },
    ["Blasted Lands"]        = { 45, 55 },
    ["Burning Steppes"]      = { 50, 58 },
    ["Western Plaguelands"]  = { 51, 58 },
    ["Eastern Plaguelands"]  = { 53, 60 },
    ["Deadwind Pass"]        = { 55, 60 },
    -- Kalimdor
    ["Teldrassil"]           = {  1, 10 },
    ["Durotar"]              = {  1, 10 },
    ["Mulgore"]              = {  1, 10 },
    ["Darkshore"]            = { 10, 20 },
    ["The Barrens"]          = { 10, 25 },
    ["Stonetalon Mountains"] = { 15, 27 },
    ["Ashenvale"]            = { 18, 30 },
    ["Thousand Needles"]     = { 25, 35 },
    ["Desolace"]             = { 30, 40 },
    ["Dustwallow Marsh"]     = { 35, 45 },
    ["Feralas"]              = { 40, 50 },
    ["Tanaris"]              = { 40, 50 },
    ["Azshara"]              = { 45, 55 },
    ["Felwood"]              = { 48, 55 },
    ["Un'Goro Crater"]       = { 48, 55 },
    ["Winterspring"]         = { 53, 60 },
    ["Silithus"]             = { 55, 60 },
}

-- Area IDs for capital cities (0 - Alliance, 1 - Horde)
local CAPITAL_UI_MAP_IDS = {
    [8]  = 0,   -- Ironforge
    [16] = 0,   -- Stormwind City
    [18] = 1,   -- Undercity
    [29] = 1,   -- Thunder Bluff
    [33] = 1,   -- Orgrimmar
    [38] = 0,   -- Darnassus
}

-- Area IDS for settlements (0 - Alliance, 1 - Horde, 2 - Neutral)
local SETTLEMENT_IDS = {
    -- Eastern Kingdoms
    [3]   = 0, -- Darkshire
    [10]  = 0, -- Lakeshire
    [11]  = 0, -- Menethil Harbor
    [15]  = 0, -- Sentinel Hill
    [17]  = 1, -- The Sepulcher
    [19]  = 0, -- Thelsamar
    [22]  = 0, -- Southshore
    [23]  = 1, -- Tarren Mill
    [25]  = 1, -- Hammerfall
    [26]  = 1, -- Kargath
    [40]  = 2, -- Booty Bay
    [41]  = 1, -- Grom'gol Camp
    [788] = 1, -- Stonard
    [792] = 0, -- Aerie Peak
    [1507] = 1, -- Revantusk Village

    -- Kalimdor
    [35]  = 1, -- Crossroads
    [39]  = 2, -- Ratchet
    [42]  = 0, -- Astranaar
    [44]  = 0, -- Stonetalon Peak
    [45]  = 0, -- Thalanaar
    [46]  = 1, -- Freewind Post
    [701] = 1, -- Sun Rock Retreat
    [789] = 2, -- Gadgetzan
    [790] = 1, -- Camp Mojache
    [791] = 0, -- Theramore Isle
    [794] = 2, -- Everlook
    [795] = 1, -- Shadowprey Village
    [796] = 0, -- Feathermoon Stronghold
    [798] = 0, -- Auberdine
    [799] = 0, -- Nijel's Point
    [1469] = 1, -- Camp Taurajo
    [1471] = 1, -- Splintertree Post
    [1685] = 2, -- Cenarion Hold
}

-- Standard quest-difficulty colors keyed off (zoneLevel - playerLevel).
-- Same thresholds as GetQuestDifficultyColor / Questie's GetDifficultyColorPercent.
local function DifficultyHex(level)
    local diff = level - UnitLevel("player")
    if     diff >=  5                                   then return "FF1A1A"  -- red
    elseif diff >=  3                                   then return "FF8040"  -- orange
    elseif diff >= -2                                   then return "FFFF00"  -- yellow
    elseif -diff <= (GetQuestGreenRange("player") or 5) then return "40C040"  -- green
    else                                                     return "C0C0C0"  -- gray
    end
end


object "ModuleMap" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Map")
    end;

    OnEnable = function(self)
        if not WorldMapFrame then return end
		
        self.frame  = Frame(WorldMapFrame)
		self.map = WorldMapFrame.ScrollContainer and Frame(WorldMapFrame.ScrollContainer) or nil

        -- WorldMapFrame's XML sets ignoreParentScale="true", which
        -- pins it to a fixed pixel size regardless of the global UI
        -- Scale slider. Flip it off so the map scales with everything
        -- else.
        --self.frame:SetIgnoreParentScale(false)

        self.anchor = WorldMapScreenAnchor and Frame(WorldMapScreenAnchor) or nil
        if self.anchor then
            self.anchor:ClearAllPoints()
            self.anchor:AlignParentTopLeft(80, 10)
        end

        self.navBar = MapNavBar(self.frame, "MUI_MapNavBar")
        self.navBar:AlignParentTopLeft(10, 42)

        self:ReskinFrame()

        -- Create tabs here
        self._isTabVisible = true
        self._tabHolder = Frame("Frame", self.bgFrame, "MUI_MapTabHolder")
        self._tabHolder:AlignParentBottomRight(0, 0)
        self._tabHolder:AlignParentTop(10)
        self._tabHolder:SetWidth(211)

        self.questLogTab = MapQuestLogTab(self._tabHolder)
        self.questDescriptionTab = MapQuestDescriptionTab(self._tabHolder)
        self.questDescriptionTab:Hide()

        self:RedirectQuestLog()

        self:RetexturePlayerArrow()

        self.frame:HookScript("OnShow", function() self:HideVanilla() end)

        hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", function()
            self:_ResizeFrame()
        end)

        -- Re-center the canvas scroll when the viewport is taller / wider
        -- than the canvas renders at baseScale. Era's
        -- CalculateScrollExtentsAtScale returns INVERTED bounds
        -- (scrollMin > scrollMax) in that case — so ResetZoom's Clamp on
        -- panY=0.5 lands at min one map, max another, producing a 3-4px
        -- alternating shift. Forcing 0.5 keeps it centered every call.
        if WorldMapFrame.ScrollContainer then
            hooksecurefunc(WorldMapFrame.ScrollContainer, "InstantPanAndZoom", function(sc)
                if sc.scrollYExtentsMin and sc.scrollYExtentsMax
                   and sc.scrollYExtentsMin > sc.scrollYExtentsMax then
                    sc.targetScrollY  = 0.5
                    sc.currentScrollY = 0.5
                    sc:SetNormalizedVerticalScroll(0.5)
                end
                if sc.scrollXExtentsMin and sc.scrollXExtentsMax
                   and sc.scrollXExtentsMin > sc.scrollXExtentsMax then
                    sc.targetScrollX  = 0.5
                    sc.currentScrollX = 0.5
                    sc:SetNormalizedHorizontalScroll(0.5)
                end
            end)
        end

        self:WirePlayerMoveFade()
        self:WireMapWheelZoom()
        self:TweakZoneLabel()
        self:HideNonCapitalMapLinks()

        self:BuildTabToggle()
        --self:_BuildCursorDebugLabel()

        self.staticPinManager = MapStaticPinManager()
        self.questPoiManager  = MapQuestPoiManager()

        self.filterButton = MapCornerButton(self.map, "MUI_MapFilterButton")
        self.filterButton.icon:SetTextureRegion(MUI.TEX_SKIN .. "worldmap\\button-filter", 128, 64, 51, 1, 48, 48)
        self.filterButton:AlignParentTopRight(1, 2.5)
        self.filterButton:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine("Map filters", 1,1,1,false, 13)
        end)

        -- Filter dropdown: master toggles for what's drawn on the
        -- world map. Each callback talks to the manager that owns the
        -- affected pin layer so the change propagates immediately.
        self._filterMenu = DropdownMenu(self.filterButton,
                                        "MUI_MapFilterMenu",
                                        self.filterButton)
        self._filterMenu:SetMenuWidth(190)
        self._filterMenu:SetAnchor(function(popup, anchor)
            popup:Below(anchor, 2)
            popup:AlignRight(anchor)
        end)
        self._filterMenu:SetItems({
            {
                type    = "checkbox",
                label   = "Show quest objectives",
                checked = MUI_DB.settings.questHelper.showObjectivesOnMap,
                OnChanged = function(_, checked)
                    MUI_DB.settings.questHelper.showObjectivesOnMap = checked
                    if self.questPoiManager then self.questPoiManager:Rebuild() end
                    if MUI_QuestHelper and MUI_QuestHelper.mapQuestAreaMgr then
                        MUI_QuestHelper.mapQuestAreaMgr:RefreshAll()
                    end
                end,
            },
            {
                type    = "checkbox",
                label   = "Show low-level quests",
                checked = MUI_DB.settings.questHelper.showLowLevelAvailableQuestsOnMap,
                OnChanged = function(_, checked)
                    MUI_QuestHelper:SetShowLowLevelAvailableQuestsOnMap(checked)
                end,
            },
            {
                type    = "checkbox",
                label   = "Show dungeons",
                checked = MUI_DB.settings.questHelper.showDungeonsOnMap,
                OnChanged = function(_, checked)
                    MUI_DB.settings.questHelper.showDungeonsOnMap = checked
                    if self.staticPinManager then self.staticPinManager:Rebuild() end
                end,
            },
        })

        self.filterButton.OnClick = function() self._filterMenu:Toggle() end

        -- The dropdown popup is a top-level frame (parented to the root so it
        -- isn't clipped), so it doesn't ride WorldMapFrame's visibility. Closing
        -- the map (ESC / close button / HideUIPanel) must dismiss it explicitly.
        self.frame:HookScript("OnHide", function() self._filterMenu:Close() end)


        self.pinButton = MapCornerButton(self.map, "MUI_MapPinButton")
        self.pinButton.icon:SetTextureRegion(MUI.TEX_BASE .. "objecticonsatlas", 1024, 1024, 898, 726, 27, 26)
        self.pinButton:Below(self.filterButton, 0.5)
        self.pinButton:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine("Map waypoint", 1,1,1,false, 13)
            tooltip:AddLine("You can place a trackable pin on the map to help you navigate to it.", 1, 0.82, 0, true)
            tooltip:AddBlank()
            tooltip:AddLine("To place a pin, click this button, then on the map. Or <Ctrl-click directly on the map>.", 0, 1, 0, true)
        end)

        self.waypointManager = MapWaypointManager(function(isPlacementMode)
            self.pinButton:SetActive(isPlacementMode)
        end)

        self.pinButton.OnClick = function()
            self.waypointManager:TogglePlaceMode()
        end

    end;

    -- Debug overlay: shows the cursor's position on the displayed map's
    -- canvas AND the player's position on the same map, both as 0..100
    -- percent (the same convention MUI_TransportDB and Questie spawn data
    -- use). Lets you tweak transport / dungeon coords by reading them off
    -- the screen at the desired spot. Cursor and player share coord space
    -- so pointing the cursor at the player arrow yields matching readouts.
    _BuildCursorDebugLabel = function(self)
        -- Parent to self.border, not bgFrame: bgFrame sits at
        -- (mapLevel - 1) so anything on it draws BEHIND the map tiles
        -- and is invisible. Border sits at (mapLevel + 1) — above the map.
        local fs = FontString(self.border, nil, "OVERLAY")
        fs:SetFont(MUI.FONT, 9, "OUTLINE")
        fs:SetTextColor(0.6, 1, 0.6, 1)
        fs:AlignParentTopLeft(50, 26)
        fs:SetJustifyH("LEFT")
        fs:SetText("--, --")
        self._cursorDebugLabel = fs

        local scrollContainer = WorldMapFrame and WorldMapFrame.ScrollContainer
        if not scrollContainer or not scrollContainer.GetNormalizedCursorPosition then return end

        self.frame:HookScript("OnUpdate", function()
            if not WorldMapFrame:IsShown() then return end

            -- Cursor: use Blizzard's own scroll-container helper so the
            -- coords match how Blizzard places its own pins (and our
            -- MapPin) on the canvas. Hand-rolled GetCursorPosition /
            -- GetEffectiveScale math drifts under canvas zoom.
            local cursorText = "off-canvas"
            local nx, ny = scrollContainer:GetNormalizedCursorPosition()
            if nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                cursorText = string.format("%.2f, %.2f", nx * 100, ny * 100)
            end

            -- Player: query GetPlayerMapPosition against the DISPLAYED
            -- map id (not the player's current zone). Returns valid coords
            -- when the displayed map contains the player; nil otherwise
            -- (player on different continent / viewing continent map).
            local playerText = "--, --"
            local displayedMap = WorldMapFrame:GetMapID()
            if displayedMap then
                local pos = C_Map.GetPlayerMapPosition(displayedMap, "player")
                if pos then
                    playerText = string.format("%.2f, %.2f", pos.x * 100, pos.y * 100)
                end
            end

            fs:SetText("cursor " .. cursorText .. "\nplayer " .. playerText)
        end)
    end;

    _ResizeFrame = function(self)

        if self._isTabVisible then
            self._tabHolder:Show()
            self.frame:SetSize(661, 335)
            self.frame:SetAttribute("UIPanelLayout-width", 661)
        else
            self._tabHolder:Hide()
            self.frame:SetSize(448, 335)
            self.frame:SetAttribute("UIPanelLayout-width", 448)
        end
        
        self.closeBtn:ClearAllPoints()
        self.closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 2, 6)

        self.map:ClearAllPoints()
        self.map:AlignParentBottomLeft(0, 1.5)
        self.map:SetPoint("TOPRIGHT", self.navBar, "BOTTOMRIGHT", 3, -6)

        self.questLogTab:Refresh()
    end;

    HideNonCapitalMapLinks = function(self)
        if not WorldMapFrame or not WorldMapFrame.AcquirePin then return end
        hooksecurefunc(WorldMapFrame, "AcquirePin", function(canvas, template, mapLink)
            if template == "CorpsePinTemplate" then
                
                local function _getPinTexture(pin)
                    for i = 1, select("#", pin:GetRegions()) do
                        local r = select(i, pin:GetRegions())
                        if r:GetObjectType() == "Texture" then return Texture(r) end
                    end
                end

                for pin in canvas:EnumeratePinsByTemplate(template) do
                    pin:SetSize(12, 17)
                    local tex = _getPinTexture(pin)
                    if tex then tex:SetTextureRegion(MUI.TEX_BASE .. "navigation", 64, 64, 2, 1, 24, 32) end
                end
            elseif template == "AreaPOIPinTemplate" then
                
                if not mapLink or not mapLink.areaPoiID then return end

                local areaId = mapLink.areaPoiID

                local isCapital = CAPITAL_UI_MAP_IDS[areaId]
                local isSettlement = SETTLEMENT_IDS[areaId]

                for pin in canvas:EnumeratePinsByTemplate(template) do
                    if pin.areaPoiID == areaId then

                        local tex = Texture(pin.Texture)

                        if isCapital then
                            pin:SetSize(12, 12)
                            tex:SetSize(12, 12)
                            if CAPITAL_UI_MAP_IDS[areaId] == 0 then
                                tex:SetTextureRegion(TEX, 1024, 1024, 13, 277, 40, 42)
                            else
                                tex:SetTextureRegion(TEX, 1024, 1024, 83, 208, 40, 42)
                            end
                        elseif isSettlement then
                            pin:SetSize(8, 8)
                            tex:SetSize(8, 8)

                            if SETTLEMENT_IDS[areaId] == 0 then
                                tex:SetTextureRegion(TEX, 1024, 1024, 347, 965, 30, 30)
                            elseif SETTLEMENT_IDS[areaId] == 1 then
                                tex:SetTextureRegion(TEX, 1024, 1024, 420, 859, 30, 30)
                            else
                                tex:SetTextureRegion(TEX, 1024, 1024, 657, 519, 32, 32)
                            end
                        else
                            --print("Pin: " .. pin.areaPoiID .. " " .. pin.name)
                            pin:SetSize(12, 12)
                            tex:SetSize(12, 12)
                        end
                        break
                    end
                end

            end
        end)
    end;

    WireMapWheelZoom = function(self)
        local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
        if not sc then return end

        sc:EnableMouseWheel(true)

        local function baseScale()
            return sc.zoomLevels and sc.zoomLevels[1]
                   and sc.zoomLevels[1].scale or 1
        end

        sc:SetScript("OnMouseWheel", function(_, delta)
            local cur     = sc:GetCanvasScale() or baseScale()
            local base    = baseScale()
            local factor  = (delta > 0) and 1.15 or (1 / 1.15)
            local target  = cur * factor
            target        = math.max(base,        target)
            target        = math.min(base * 2.5,    target)
            local panX    = sc:GetCurrentScrollX() or 0.5
            local panY    = sc:GetCurrentScrollY() or 0.5
            sc:InstantPanAndZoom(target, panX, panY)
        end)
    end;

    -- Switch the right-side panel to the quest-description tab and
    -- populate it for the given questId. Hides the quest-log tab.
    -- Show the description tab BEFORE SetQuest so its scroll/anchor
    -- chain is laid out and FontStrings can wrap against the correct
    -- width when SetQuest measures them.
    ShowQuestDescription = function(self, questId)
        if not self.questDescriptionTab then return end
        if self.questLogTab then self.questLogTab:Hide() end
        self.questDescriptionTab:Show()
        self.questDescriptionTab:SetQuest(questId)
        -- Solo-mode the world-map POIs AND hulls: hide every other
        -- quest's pin/hull so only the described one stands out, even
        -- if a different quest is currently focused.
        if self.questPoiManager then
            self.questPoiManager:SetSoloQuestFilter(questId)
        end
        if MUI_QuestHelper and MUI_QuestHelper.mapQuestAreaMgr then
            MUI_QuestHelper.mapQuestAreaMgr:SetSoloQuestFilter(questId)
        end
        -- Hover-push the described quest so its hull SHOWS while in
        -- description view (regardless of focus). Pop on tab exit.
        if self._descriptionHoverQuestId
           and self._descriptionHoverQuestId ~= questId then
            MUI_QuestHelper:PopQuestHover(self._descriptionHoverQuestId)
        end
        if questId and self._descriptionHoverQuestId ~= questId then
            MUI_QuestHelper:PushQuestHover(questId)
        end
        self._descriptionHoverQuestId = questId
    end;

    -- Switch the right-side panel back to the quest-log tab.
    ShowQuestLog = function(self)
        if self.questDescriptionTab then self.questDescriptionTab:Hide() end
        if self.questLogTab then
            self.questLogTab:Show()
            self.questLogTab:Refresh()
        end
        -- Restore all tracked quest POIs and hulls.
        if self.questPoiManager then
            self.questPoiManager:SetSoloQuestFilter(nil)
        end
        if MUI_QuestHelper and MUI_QuestHelper.mapQuestAreaMgr then
            MUI_QuestHelper.mapQuestAreaMgr:SetSoloQuestFilter(nil)
        end
        if self._descriptionHoverQuestId then
            MUI_QuestHelper:PopQuestHover(self._descriptionHoverQuestId)
            self._descriptionHoverQuestId = nil
        end
    end;

    -- Hide everything inside WorldMapFrame except WorldMapDetailFrame
    -- (the actual map tiles) and our own overlays. Direct regions
    -- (textures / fontstrings) on WorldMapFrame go alpha 0; children get
    -- alpha 0 AND have their mouse capture disabled recursively — alpha
    -- alone leaves invisible buttons (e.g. MaximizeMinimizeFrame's
    -- Maximize / Minimize sub-buttons) clickable through empty space.
    HideVanilla = function(self)
        for _, region in ipairs(self.frame:GetRegions()) do
            region:SetAlpha(0)
        end

        local keep = {
            [self.map       and self.map._native       or false] = true,
            [self.border    and self.border._native    or false] = true,
            [self.closeBtn  and self.closeBtn._native  or false] = true,
            [self.navBar    and self.navBar._native    or false] = true,
            [self.bgFrame   and self.bgFrame._native   or false] = true,
        }

        local function disableMouseTree(native)
            if not native or not native.EnableMouse then return end
            native:EnableMouse(false)
            if native.EnableMouseWheel then native:EnableMouseWheel(false) end
            if native.GetChildren then
                for _, sub in ipairs({native:GetChildren()}) do
                    disableMouseTree(sub)
                end
            end
        end

        for _, child in ipairs(self.frame:GetChildren()) do
            if not keep[child._native] then
                child:SetAlpha(0)
                disableMouseTree(child._native)
            end
        end
    end;

    -- Fade the whole frame to 0.5 alpha while the player character is
    -- moving in the world, back to 1.0 when they stop. Driven by the
    -- PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING events; the actual
    -- alpha tween runs in OnUpdate (only ticks while the frame is shown).
    WirePlayerMoveFade = function(self)
        local FADE_DUR   = 0.15
        local MOVE_ALPHA = 0.6
        local FULL_ALPHA = 1.0
        local STEP_RANGE = FULL_ALPHA - MOVE_ALPHA

        self._playerMoving = false
        self.frame:RegisterEventHandler("PLAYER_STARTED_MOVING", function()
            self._playerMoving = true
        end)
        self.frame:RegisterEventHandler("PLAYER_STOPPED_MOVING", function()
            self._playerMoving = false
        end)

        self.frame:HookScript("OnUpdate", function(_, dt)
            -- Hovering the frame keeps it fully opaque so the user can
            -- always read the map even while running.
            local fade    = self._playerMoving and not self.frame:IsMouseOver()
            local desired = fade and MOVE_ALPHA or FULL_ALPHA
            local current = self.frame:GetAlpha()
            if current == desired then return end

            local diff = desired - current
            local step = (dt / FADE_DUR) * STEP_RANGE
            if math.abs(diff) <= step then
                self.frame:SetAlpha(desired)
            elseif diff > 0 then
                self.frame:SetAlpha(current + step)
            else
                self.frame:SetAlpha(current - step)
            end
        end)
    end;

    ReskinFrame = function(self)
        -- Background frame: sits BELOW the map's ScrollContainer so the
        -- rock fill shows behind the canvas, not on top of it. Border /
        -- portrait / title still live above the map.
        self.bgFrame = Frame("Frame", self.frame, "MUI_MapBgFrame")
        self.bgFrame:FillParent()
        self.bgFrame:SetFrameLevel(self.map:GetFrameLevel() - 1)

        local bg = Texture(self.bgFrame, nil, "BACKGROUND")
        bg:SetTexture(MUI.TEX_BASE .. "frame-background-rock")
        bg:FillParentPadding(1, 8, 0, 1)

        self.border = MetalBorderPortrait(self.frame, "MUI_MapBorder", 0.6399)
        self.border:FillParent()
        self.border:SetFrameLevel(self.map:GetFrameLevel() + 1)
		
		local portrait = Texture(self.border, nil, "ARTWORK")
		portrait:SetTexture(MUI.TEX_BASE .. "frame-portrait-questlog")
		portrait:AlignParentTopLeft(-10, -3)
		portrait:SetSize(40, 40)
		
		local title = FontString(self.border)
		title:SetText("World Map and Quest Log")
		title:SetFontSize(7.5)
		title:SetShadowOffset(1, -1)
		title:SetTextColor(1, 0.82, 0, 1)
		title:AlignParentTop(-2, 16)
		
		-- Parented to self.border (not self.frame): Strip() alpha-zeroes
		-- every region on self.frame, which would hide a separator placed
		-- there. Borders / bg / portrait / title also live on self.border
		-- for the same reason.
		local separator = Texture(self.border, nil, "OVERLAY")
		separator:SetColorTexture(0, 0, 0, 0.7)
		separator:ClearAllPoints()
		separator:SetHeight(0.5)
		separator:Above(self.map, 2)
		separator:AlignLeft(self.map)
		separator:AlignRight(self.map)

        -- Reskin close button
        local native = nil

        if WorldMapFrame then
            if WorldMapFrame.CloseButton then native = WorldMapFrame.CloseButton end
            if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.CloseButton then
                native = WorldMapFrame.BorderFrame.CloseButton
            end
        end
        if not native then native = getglobal("WorldMapFrameCloseButton") end
        if not native then return end

        local atlas = MUI_AtlasRegistry.ButtonRedControl
        local btn = Button(native)
        btn:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        btn:SetHighlightAtlas(atlas, "Highlight", true)
        btn:SetSize(23.5*0.6399, 24*0.6399)
        btn:SetFrameLevel(self.frame:GetFrameLevel() + 20)

        self.closeBtn = btn
		
    end;

    TweakZoneLabel = function(self)
        if not WorldMapFrame.dataProviders then return end
        local dp
        for provider in pairs(WorldMapFrame.dataProviders) do
            if provider.Label and provider.SetOffsetY and provider.Label.Name then
                dp = provider
                break
            end
        end
        if not dp then return end

        local label = dp.Label
        self.zoneLabel     = Frame(label)
        self.zoneLabelName = FontString(label.Name)
        self.zoneSubLabel  = FontString(self.zoneLabel)
        self.zoneSubLabel:Below(self.zoneLabelName, 7)

        -- Smaller font. Reuse the inherited font file from the template
        -- (WorldMapTextFont); only override the size.
        local fontFile, _, fontFlags = self.zoneLabelName:GetFont()
        if fontFile then
            self.zoneLabelName:SetFont(fontFile, 20, fontFlags or "")
            self.zoneSubLabel:SetFont(fontFile, 17, fontFlags or "")
        end

        -- Re-anchor to the ScrollContainer's top instead of
        -- WorldMapFrame's top. SetOffsetY(...) anchors to GetMap()
        -- (= WorldMapFrame); in our compact layout that's *above*
        -- ScrollContainer (behind navbar + border), and ScrollContainer
        -- clips its children — so the label disappears.
        if self.map then
            self.zoneLabel:ClearAllPoints()
            self.zoneLabel:AlignTop(self.map, -3)
        end

        -- Hook SetLabel: prefix the name with " (min-max)" before the
        -- frame stores it in labelInfoByType. EvaluateLabels then renders
        -- the augmented name.
        local origSetLabel = label.SetLabel
        label.SetLabel = function(lbl, areaLabelType, name, description, ...)
            if name and ZONE_LEVELS[name] then
                local r = ZONE_LEVELS[name]
                local hex = DifficultyHex(r[2])
                name = name .. " |cFF" .. hex .. "(" .. r[1] .. "-" .. r[2] .. ")|r"
            end
            return origSetLabel(lbl, areaLabelType, name, description, ...)
        end
    end;

    RetexturePlayerArrow = function(self)
        if not WorldMapFrame or not WorldMapFrame.dataProviders then return end
        for dp in pairs(WorldMapFrame.dataProviders) do
            if dp.pin and dp.GetUnitPinSizesTable and dp.pin.SetPinTexture then
                dp.pin:SetPinTexture("player", MUI.TEX_SKIN .. "worldmap\\player-arrow")
                if dp.SetUnitPinSize then
                    dp:SetUnitPinSize("player", 18)  -- default 16
                end
                -- Force the player arrow above every MUI pin layer.
                -- MUI_MAP_PIN_FRAME_LEVEL = 3000 (flight masters), POI
                -- counter starts at 3010 and inflates per pin. We bump
                -- both strata (HIGH beats every MEDIUM-stratum sibling
                -- regardless of level) and frame level (8000), and
                -- re-assert after every data-provider refresh — the
                -- canvas's PinFrameLevelsManager re-applies the pin's
                -- declared frame level type whenever the provider
                -- rebuilds, which would otherwise drop us back under
                -- the POIs.
                local function _bump()
                    dp.pin:SetFrameStrata("HIGH")
                    dp.pin:SetFrameLevel(8000)
                end
                _bump()
                if dp.RefreshAllData then
                    hooksecurefunc(dp, "RefreshAllData", _bump)
                end
                if dp.pin.Refresh then
                    hooksecurefunc(dp.pin, "Refresh", _bump)
                end
                return
            end
        end
    end;

    -- Redirect "open quest log" to the world map. Two layers:
    --
    --   1) SetOverrideBinding on the TOGGLEQUESTLOG key → TOGGLEWORLDMAP.
    --      This is the COMBAT-SAFE path — the binding system runs in
    --      secure context, so the L key works during combat. Function
    --      replacement of ToggleQuestLog wouldn't, because its
    --      ShowUIPanel call from addon Lua is blocked in combat.
    --
    --   2) Replace ToggleQuestLog (for the micromenu button and other
    --      Lua callers) — works only out of combat, but covers all
    --      non-keybind paths there. In combat those paths are blocked
    --      anyway by Blizzard's UIPanel protection.
    --
    -- UPDATE_BINDINGS re-applies the override when the user rebinds
    -- their quest-log key in the keybind options. Tracks which keys
    -- we set so a rebind cleans up the old override.
    RedirectQuestLog = function(self)
        if ToggleQuestLog and ToggleWorldMap then
            ToggleQuestLog = function() ToggleWorldMap() end
        end

        self._overriddenQLKeys = {}
        local function applyOverride()
            for _, k in ipairs(self._overriddenQLKeys) do
                SetOverrideBinding(UIParent, false, k, nil)
            end
            self._overriddenQLKeys = {}
            local k1, k2 = GetBindingKey("TOGGLEQUESTLOG")
            for _, k in ipairs({ k1, k2 }) do
                if k then
                    SetOverrideBinding(UIParent, false, k, "TOGGLEWORLDMAP")
                    table.insert(self._overriddenQLKeys, k)
                end
            end
        end
        applyOverride()
        self.frame:RegisterEventHandler("UPDATE_BINDINGS", applyOverride)
    end;

    BuildTabToggle = function(self)

        local TEX = MUI.TEX_SKIN .. "worldmap\\questlog-toggle"
        
        self._tabToggle = Button(self.map, "MUI_MapTabVisibilityToggle")
        self._tabToggle:SetSize(21, 20)
        self._tabToggle:AlignBottom(self.map, 1)
        self._tabToggle:AlignRight(self.map, 1)
        
        self._tabToggle:SetNormalTexture(TEX)
        self._tabToggle:GetNormalTexture():SetTexCoord(0.0, 0.5, 0.0, 0.5)

        self._tabToggle:SetPushedTexture(TEX)
        self._tabToggle:GetPushedTexture():SetTexCoord(0.5, 1.0, 0.0, 0.5)

        self._tabToggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        local hl = self._tabToggle:GetHighlightTexture()
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.7)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT",     self._tabToggle, "TOPLEFT",     -5,  5)
        hl:SetPoint("BOTTOMRIGHT", self._tabToggle, "BOTTOMRIGHT",  5, -5)

        self._tabToggle.OnClick = function(btn)
            self._isTabVisible = not self._isTabVisible
            if self._isTabVisible then
                btn:GetNormalTexture():SetTexCoord(0.0, 0.5, 0.0, 0.5)
                btn:GetPushedTexture():SetTexCoord(0.5, 1.0, 0.0, 0.5)
            else
                btn:GetNormalTexture():SetTexCoord(0.0, 0.5, 0.5, 1.0)
                btn:GetPushedTexture():SetTexCoord(0.5, 1.0, 0.5, 1.0)
            end
            self:_ResizeFrame()
        end

    end
}
