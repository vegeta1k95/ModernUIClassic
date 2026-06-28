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
local LOG_ATLAS_TEX  = MUI.TEX_SKIN .. "worldmap\\questlog-atlas"

-- Placeholders — replace with real art when the system is in place.
local PH_ICON  = "Interface\\Icons\\INV_Misc_QuestionMark"
local PH_COIN  = "Interface\\Icons\\INV_Misc_Coin_01"
local PH_XP    = MUI.TEX_BASE .. "Icons\\xp_icon"

-- Reward tile metrics (mirrors retail's SmallItemButtonTemplate proportions).
local TILE_H        = 28      -- per-row height
local ICON_SIZE     = 26    -- icon edge
local TILE_HGAP     = 4       -- horizontal gap between L/R tiles in a row
local TILE_VGAP     = 3       -- vertical gap between rows
local SECTION_GAP   = 4         -- gap between sections (e.g. Choices → Mandatory)
local HEADER_GAP    = 5       -- gap between a section header and its first tile

-- Single reward "tile": icon on the left, name-frame bar on the right
-- with the reward name, optional stack count overlaid on the icon.
-- Placeholders for icon + nameFrame textures live up top.
class "RewardTile" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(130, TILE_H)
        self:EnableMouse(true)

        self._icon = ItemIcon(self, nil, "BACKGROUND")
        self._icon:SetSize(ICON_SIZE + 1.5, ICON_SIZE)
        self._icon:AlignParentTopLeft(0, 0)
        self._icon:SetTexture(PH_ICON)

        self._nameFrame = Texture(self, nil, "BACKGROUND")
        self._nameFrame:SetTextureRegion(LOG_ATLAS_TEX, 2048, 1024, 960, 902, 102, 30)
        self._nameFrame:SetHeight(ICON_SIZE + 0.5)
        self._nameFrame:SetPoint("LEFT",  self._icon,    "RIGHT", 2.5, 0)
        self._nameFrame:SetPoint("RIGHT", self,          "RIGHT", -4, 0)

        self._name = FontString(self, nil, "ARTWORK")
        self._name:SetFont(MUI.FONT, 9)
        self._name:SetTextColor(1, 1, 1, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetJustifyV("MIDDLE")
        self._name:SetPoint("LEFT",  self._nameFrame, "LEFT",  3.5,  0)
        self._name:SetPoint("RIGHT", self._nameFrame, "RIGHT", -2, 0)

        self._count = FontString(self, nil, "OVERLAY")
        self._count:SetFont(MUI.FONT, 10, "OUTLINE")
        self._count:SetTextColor(1, 1, 1, 1)
        self._count:SetJustifyH("RIGHT")
        self._count:SetPoint("BOTTOMRIGHT", self._icon, "BOTTOMRIGHT", -1, 1)
        self._count:Hide()

        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if not self._link then return end
            tooltip:SetHyperlink(self._link)
        end)

    end;

    SetFontSize = function(self, size)
        self._name:SetFontSize(size)
    end;

    SetReward = function(self, iconTex, name, count, link)
        self._icon:SetTexture(iconTex or PH_ICON)
        self._name:SetText(name or "")
        if count and count > 1 then
            self._count:SetText(tostring(count))
            self._count:Show()
        else
            self._count:Hide()
        end
        self._link = link
        -- Quality border on item rewards. 3rd return of GetItemInfo is
        -- quality enum (0..7); nil link (XP / money tiles) or items
        -- whose info isn't cached yet → nil → ItemIcon hides the
        -- border. SetQuality also internally hides for poor/common
        -- (<= 1) which is the convention most addons use.
        local quality
        if link then quality = select(3, GetItemInfo(link)) end
        self._icon:SetQuality(quality)
    end;
}

-- Strip leading/trailing whitespace (including the trailing newlines that
-- GetQuestLogQuestText / GetQuestLogLeaderBoard returns slap on the end).
-- Without this, FontStrings include the empty trailing rows in their
-- GetStringHeight and the layout reserves dead vertical space.
local function _trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Era's quest log API is index-based (GetQuestLogQuestText / SelectQuestLogEntry
-- / GetQuestLogPushable etc.), so map a stable questID back to the live log
-- index by walking the log.
local function _findQuestLogIndex(questId)
    if not questId then return nil end
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, _, _, _, _, qID = GetQuestLogTitle(i)
        if qID == questId then return i end
    end
    return nil
end

-- Pick a representative creature to display in the NPC model frame.
-- Prefers the FIRST UNFINISHED objective so the player sees who they
-- still need to kill / loot. Falls back to the first defined objective
-- if every line is already complete (last-objective preview before
-- turn-in) or if the quest isn't in the live log.
--
-- Returns a creatureID, or nil if this quest has no kill / kill-to-loot
-- objective at all (e.g. talk-to-NPC, use-object, deliver-item-no-mob).
--
-- Questie's objectives layout (3-slot array):
--   [1] = creature kills    — { {creatureID, ...}, ... }
--   [2] = object interacts  — ignored for the model
--   [3] = items to collect  — { {itemID, ...}, ... }; we look up the
--                              item's npcDrops to surface the source mob
local function _PickQuestNpcCreature(questId)
    if not MUI_QuestDB then return nil end
    local q = MUI_QuestDB:Get(questId)
    if not q or not q.objectives then return nil end

    -- Resolve a Questie objective at (kind, position-within-kind) into
    -- a displayable creatureID. Mirrors the cluster lookup convention.
    local function npcFor(kind, pos)
        if kind == "monster" then
            local e = q.objectives[1] and q.objectives[1][pos]
            return e and e[1] or nil
        elseif kind == "item" then
            local e = q.objectives[3] and q.objectives[3][pos]
            if e and e[1] and MUI_ItemDB then
                local item = MUI_ItemDB:Get(e[1])
                if item and item.npcDrops and item.npcDrops[1] then
                    return item.npcDrops[1]
                end
            end
        end
        return nil
    end

    -- Walk the live leaderboard, counting position within each type.
    -- The first leaderboard entry whose `finished` flag is false AND
    -- whose Questie counterpart resolves to a creature wins.
    local idx = _findQuestLogIndex(questId)
    if idx then
        local prevSel = GetQuestLogSelection() or 0
        SelectQuestLogEntry(idx)
        local counter = {}
        for i = 1, (GetNumQuestLeaderBoards() or 0) do
            local _, t, finished = GetQuestLogLeaderBoard(i)
            if t then
                counter[t] = (counter[t] or 0) + 1
                if not finished then
                    local cid = npcFor(t, counter[t])
                    if cid then
                        SelectQuestLogEntry(prevSel)
                        return cid
                    end
                end
            end
        end
        SelectQuestLogEntry(prevSel)
    end

    -- Fallback: first kill objective, else first item with npcDrops.
    return npcFor("monster", 1) or npcFor("item", 1)
end


class "MapQuestDescriptionTab" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent, "MUI_MapQuestDescriptionTab")
        
        self:FillParent()

        self:_BuildChrome()
        self:_BuildContent()
        self:_BuildNpcModel()
        self:_WireScroll()

        -- Re-run a full layout (not just slider math) on size change.
        -- The first paint after Show() measures FontStrings before
        -- their width has fully resolved, so initial heights are off
        -- — re-measuring on the next OnSizeChanged tick fixes it.
        self:SetScript("OnSizeChanged", function()
            if self.questId then
                self:_LayoutContent()
            end
            self:_RefreshScroll()
        end)
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
            self._borderContainer:AlignParentBottom(16)
            self._borderContainer:AlignParentTop(1)

            local bg = Texture(self._borderContainer, nil, "BACKGROUND")
            bg:FillParentPadding(0, 0, 1, 0)
            bg:SetTextureRegion(LOG_ATLAS_TEX, 2048, 1024, 289, 0, 286, 466)

            self._borderOverlay = Frame("Frame", self._borderContainer)
            self._borderOverlay:FillParent()
            self._borderOverlay:SetFrameLevel(self._borderContainer:GetFrameLevel() + 50)

            local header = Texture(self._borderOverlay)
            header:SetTextureRegion(LOG_TEX, 1024, 1024, 0, 592, 616, 101)
            header:AlignParentTopLeft(-1, 0)
            header:AlignParentTopRight(-1, 0)
            header:SetHeight(33)

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
            shadowBottom:SetHeight(10)
        end

        self.scroll = ScrollFrame(self._borderContainer)
        self.scroll:FillParentPadding(2, 4, 1, 1)

        self._btnBack = ButtonGold(self._borderOverlay, "MUI_MapQuestDescriptionBack", "Back")
        self._btnBack:AlignParentTopLeft(13, 11)
        self._btnBack:SetScale(0.6)
        self._btnBack.OnClick = function()
            MUI_ModuleMap:ShowQuestLog()
        end

        local bottomPanel = Frame("Frame", self)
        bottomPanel:Below(self._borderContainer)
        bottomPanel:AlignParentBottom(2)
        bottomPanel:AlignParentLeft()
        bottomPanel:AlignRight(self._borderContainer)
        bottomPanel:SetFrameLevel(self._borderOverlay:GetFrameLevel() + 10)

        local width = (211-6-self.slider:GetWidth()) / 3

        self._btnAbandon = ButtonGold(bottomPanel, "MUI_MapQuestDescriptionAbandon", "Abandon")
        self._btnAbandon:AlignParentLeft(-3)
        self._btnAbandon:SetScale(0.61)
        self._btnAbandon:SetWidth(width/0.61)
        self._btnAbandon.OnClick = function()
            if not self.questId then return end
            local idx = _findQuestLogIndex(self.questId)
            if not idx then return end
            local prev = GetQuestLogSelection() or 0
            SelectQuestLogEntry(idx)
            SetAbandonQuest()
            StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
            SelectQuestLogEntry(prev)
        end

        local div1 = Texture(bottomPanel, "OVERLAY")
        div1:SetTextureRegion(MUI.TEX_BASE .. "frame-inner", 128, 128, 0, 98, 15, 32)
        div1:RightOf(self._btnAbandon, -7, -6)
        div1:SetSize(12, 34)
        div1:SetScale(0.63)

        self._btnTrack = ButtonGold(bottomPanel, "MUI_MapQuestDescriptionTrack", "Track")
        self._btnTrack:AlignParentRight(-3)
        self._btnTrack:SetScale(0.61)
        self._btnTrack:SetWidth(width/0.61)
        self._btnTrack.OnClick = function()
            if not self.questId then return end
            local tracked = MUI_QuestHelper:IsTracked(self.questId)
            MUI_QuestHelper:SetTracked(self.questId, not tracked)
            -- Refresh button label state.
            self:_UpdateButtonStates()
        end

        local div2 = Texture(bottomPanel, "OVERLAY")
        div2:SetTextureRegion(MUI.TEX_BASE .. "frame-inner", 128, 128, 0, 98, 15, 32)
        div2:LeftOf(self._btnTrack, -7, -6)
        div2:SetSize(12, 34)
        div2:SetScale(0.63)

        self._btnShare = ButtonGold(bottomPanel, "MUI_MapQuestDescriptionShare", "Share")
        self._btnShare:LeftOf(self._btnTrack, 0)
        self._btnShare:RightOf(self._btnAbandon, 0)
        self._btnShare:SetScale(0.61)
        self._btnShare:SetEnabled(false)
        self._btnShare.OnClick = function()
            if not self.questId then return end
            local idx = _findQuestLogIndex(self.questId)
            if not idx then return end
            local prev = GetQuestLogSelection() or 0
            SelectQuestLogEntry(idx)
            QuestLogPushQuest()
            SelectQuestLogEntry(prev)
        end

    end;

    _BuildContent = function(self)
        self.scrollChild = Frame("Frame", self.scroll)
        self.scrollChild:SetSize(1, 1)  -- placeholder; resized in _RefreshScroll
        self.scrollChild:SetScale(0.7)
        self.scroll:SetScrollChild(self.scrollChild)

        self._footer = Frame("Frame", self.scrollChild)
        self._footer:AlignParentBottom(0)
        self._footer:FillWidth()

        local footerTop = Texture(self._footer, nil, "ARTWORK")
        footerTop:SetTextureRegion(LOG_TEX, 1024, 1024, 0, 479, 616, 114)
        footerTop:AlignParentTop()
        footerTop:FillWidth()
        footerTop:SetHeight(50)

        self._footerContent = Frame("Frame", self._footer)
        self._footerContent:Below(footerTop)
        self._footerContent:AlignParentBottom()
        self._footerContent:FillWidth()
        self._footerContent:SetHeight(1)

        local header = FontString(self._footerContent, nil, "OVERLAY")
        header:SetFont(MUI.FONT_CAL, 17)
        header:SetTextColor(0.9, 0.8, 0.71, 1)
        header:SetJustifyH("LEFT")
        header:SetText("Rewards")
        header:CenterAt(footerTop, 0, -2)

        local footerTex = Texture(self._footerContent, nil, "ARTWORK")
        footerTex:SetTextureRegion(LOG_TEX, 1024, 1024, 0, 177, 616, 168)
        footerTex:FillParentPadding(0,-2,0,-12)

        local footerBottom = Texture(self._footerContent, nil, "OVERLAY")
        footerBottom:SetTextureRegion(LOG_TEX, 1024, 1024, 0, 124, 616, 53)
        footerBottom:AlignParentBottom(0)
        footerBottom:FillWidth()
        footerBottom:SetHeight(30)

        self._content = Frame("Frame", self.scrollChild)
        self._content:FillWidth()
        self._content:Above(self._footer)
        self._content:AlignParentTop()

        -- Content fontstrings, stacked vertically, populated by SetQuest.
        -- Each starts hidden; SetQuest sets text and calls _LayoutContent
        -- to chain-anchor the visible ones.
        self._contentTitle = FontString(self._content, nil, "OVERLAY")
        self._contentTitle:SetFont(MUI.FONT_CAL, 17)
        self._contentTitle:SetTextColor(0,0,0)
        self._contentTitle:SetJustifyH("LEFT")
        self._contentTitle:SetShadowOffset(1, -1)
        self._contentTitle:SetShadowColor(0,0,0,0.4)

        self._contentObjBody = FontString(self._content, nil, "OVERLAY")
        self._contentObjBody:SetFont(MUI.FONT, 12)
        self._contentObjBody:SetTextColor(0, 0, 0, 0.8)
        self._contentObjBody:SetJustifyH("LEFT")

        self._contentObjList = FontString(self._content, nil, "OVERLAY")
        self._contentObjList:SetFont(MUI.FONT, 10.5)
        self._contentObjList:SetTextColor(0, 0, 0, 0.8)
        self._contentObjList:SetJustifyH("LEFT")

        self._contentDescHeader = FontString(self._content, nil, "OVERLAY")
        self._contentDescHeader:SetFont(MUI.FONT_CAL, 17)
        self._contentDescHeader:SetTextColor(0, 0, 0)
        self._contentDescHeader:SetJustifyH("LEFT")
        self._contentDescHeader:SetText("Description")
        self._contentDescHeader:SetShadowOffset(1, -1)
        self._contentDescHeader:SetShadowColor(0,0,0,0.4)

        self._contentDescBody = FontString(self._content, nil, "OVERLAY")
        self._contentDescBody:SetFont(MUI.FONT, 12)
        self._contentDescBody:SetTextColor(0, 0, 0, 0.8)
        self._contentDescBody:SetJustifyH("LEFT")

        -- Container for the rewards layout (sub-headers + 2-col grid of
        -- RewardTile). Positioned + sized in _LayoutContent / _LayoutRewards.
        self._footerRewards = Frame("Frame", self._footerContent)

        -- Reusable pools — _LayoutRewards acquires by index and hides
        -- the rest. Tiles are RewardTile, sub-headers are FontStrings
        -- (e.g. "You will receive:" / "Choose one of these rewards:").
        self._rewardTiles   = {}
        self._rewardHeaders = {}
    end;

    -- NPC model "wing" — a 3D portrait that sits OUTSIDE the right edge
    -- of the WorldMapFrame, anchored to this tab. Parented to the tab so
    -- it auto-hides when the description tab hides; visibility is further
    -- gated in _RefreshNpcModel against whether the quest has a kill or
    -- kill-to-loot objective.
    _BuildNpcModel = function(self)

        self._npcModelContainer = Frame("Frame", self, "MUI_QuestNpcModelContainer")
        self._npcModelContainer:SetSize(139, 187)
        self._npcModelContainer:SetPoint("TOPLEFT", self, "TOPRIGHT", -4, 6)
        self._npcModelContainer:Hide()

        self._npcModel = PlayerModel(self._npcModelContainer)
        self._npcModel:FillParentPadding(6, 19, 6, 4)
        -- Pivot SetTransform around the model's bbox center; also clears
        -- the alpha-test ghosting bug that SetTransform otherwise causes.
        self._npcModel:UseModelCenterToTransform(false)

        -- Background plate behind the model (boss-portrait dark gradient).
        -- Sized to the model's framing so the plate fills the visible
        -- interior of the 9-slice border.
        local bg = Texture(self._npcModelContainer, nil, "BACKGROUND")
        bg:SetAtlas(MUI_AtlasRegistry.FrameBossPortrait, "Background", true)
        bg:FillParentPadding(6, 19, 6, 4)

        local topBar = TextureTiled(self._npcModelContainer)
        topBar:SetSize(self._npcModelContainer:GetWidth() - 16, 13.5)
        topBar:SetPoint("TOPLEFT", self._npcModelContainer, "TOPLEFT", 8, -5)
        topBar:SetAtlasTile(
            MUI_AtlasRegistry.FrameBossPortrait, "Tile", 7.7, 13.5)

        local border  = NineSlice(self._npcModelContainer)
        border:FillParent()
        border:SetFromAtlas(MUI_AtlasRegistry.FrameBossPortrait, "Nineslice", 64, 64, 64, 64, 0.33)

        local bottom = Frame("Frame", border)
        bottom:SetHeight(24)
        bottom:AlignLeft(self._npcModel, -1)
        bottom:AlignRight(self._npcModel, -1)
        bottom:AlignBottom(self._npcModel, -7)
        
        local bottomBar = Texture(bottom, nil, "OVERLAY")
        bottomBar:SetTextureRegion(MUI.TEX_BASE .. "frame-bossportrait", 512, 2048, 0, 1394, 402, 76)
        bottomBar:FillParent()

        local bottomBarBg = Texture(bottom, nil, "BACKGROUND")
        bottomBarBg:SetColorTexture(0, 0, 0, 1)
        bottomBarBg:FillParentPadding(0, 6, 0, 6)

        self._npcName = FontString(bottom)
        self._npcName:SetFontSize(8)
        self._npcName:SetPoint("CENTER", bottom, "CENTER", 0, 0)
        self._npcName:SetTextColor(1, 0.82, 0, 1)
        self._npcName:AlignLeft(bottom, 20)
        self._npcName:AlignRight(bottom, 20)
        self._npcName:FillHeight(7)
        self._npcName:SetJustifyV("MIDDLE")

        -- Camera baseline (unzoomed). Wheel zoom scales the (camera -
        -- target) vector by self._npcZoom. Vertical Z is unzoomed so
        -- the camera height stays fixed.
        local CAM_BASE_X, CAM_BASE_Y, CAM_BASE_Z = 5, -1, 1
        local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP      = 0.5, 2.0, 0.1
        self._npcZoom = 1.0

        local function applyCamera()
            self._npcModel:SetCustomCamera(0)
            self._npcModel:SetCameraPosition(
                CAM_BASE_X * self._npcZoom,
                CAM_BASE_Y * self._npcZoom,
                CAM_BASE_Z)
            self._npcModel:SetCameraTarget(0, 0, 1)
        end

        -- The model file loads asynchronously, so the camera can only be
        -- set once the load completes — SetCustomCamera/SetCameraPosition
        -- throw "Not using a custom camera" while the file is still loading
        -- (the cold-start first open). Apply it from OnModelLoaded, which
        -- fires when the model is actually ready.
        self._npcModel:SetScript("OnModelLoaded", function()
            applyCamera()
            self._npcModel:SetFacing(self._npcFacing or 0)
        end)

        -- Cold-start fix: the very first SetCreature(...) of a session
        -- is a no-op if the Model frame isn't yet visible (the engine
        -- skips the async file load while hidden). Re-issue it on every
        -- show — this call fires while the frame is on screen, so the model
        -- loads, which in turn fires OnModelLoaded (above) and applies the
        -- camera. _RefreshNpcModel stashes the creature for us.
        self._npcModelContainer:HookScript("OnShow", function()
            local cid = self._npcModelLastCreature
            if cid then
                self._npcModel:SetCreature(cid)
            end
        end)

        -- Click-and-drag horizontal yaw on the model frame. Holding the
        -- left mouse button and dragging sideways spins the creature
        -- around its vertical axis. Sensitivity is radians-per-pixel so
        -- a ~screen-width drag covers a full 360° turn.
        local DRAG_SENSITIVITY = 0.01
        self._npcFacing = 0
        self._npcModel:EnableMouse(true)
        self._npcModel:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            self._npcDragStartX  = GetCursorPosition()
            self._npcDragStartF  = self._npcFacing
        end)
        self._npcModel:SetScript("OnMouseUp", function(_, button)
            if button ~= "LeftButton" then return end
            self._npcDragStartX = nil
        end)
        self._npcModel:SetScript("OnUpdate", function()
            if not self._npcDragStartX then return end
            local cx = GetCursorPosition()
            self._npcFacing = self._npcDragStartF
                            + (cx - self._npcDragStartX) * DRAG_SENSITIVITY
            self._npcModel:SetFacing(self._npcFacing)
        end)

        -- Mouse wheel zoom: scroll up = zoom in (closer), scroll down =
        -- zoom out (further). Clamped to [ZOOM_MIN, ZOOM_MAX] so the
        -- camera can't push into the model or recede off-screen.
        self._npcModel:EnableMouseWheel(true)
        self._npcModel:SetScript("OnMouseWheel", function(_, delta)
            self._npcZoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX,
                                     self._npcZoom - delta * ZOOM_STEP))
            applyCamera()
        end)
    end;

    -- Show the NPC model + portrait border for `creatureID`, or hide the
    -- whole wing if `creatureID` is nil. Called from SetQuest after a
    -- quest is selected.
    _RefreshNpcModel = function(self, creatureID)
        if creatureID then
            self._npcModel:SetCreature(creatureID)
            self._npcModelContainer:Hide()
            self._npcModelLastCreature = creatureID
            self._npcFacing = 0
            self._npcModelContainer:Show()

            local npc  = MUI_NpcDB and MUI_NpcDB:Get(creatureID)
            local name = (npc and npc.name) or ""
            self._npcName:SetText(name)
            
        else
            self._npcModelLastCreature = nil
            self._npcModel:ClearModel()
            self._npcName:SetText("")
            self._npcModelContainer:Hide()
        end
    end;

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

    -- Populate the panel for a given quest. Reads description /
    -- objectives via the index-based quest log API, formats the
    -- rewards block, lays out the FontStrings, and updates button
    -- states (Track label flips, Share enabled iff pushable + grouped).
    SetQuest = function(self, questId)
        self.questId = questId
        if not questId then return end

        local idx = _findQuestLogIndex(questId)
        if not idx then return end

        local prevSel = GetQuestLogSelection() or 0
        SelectQuestLogEntry(idx)

        local title, level, _, _, _, isComplete = GetQuestLogTitle(idx)
        local description, objectivesText        = GetQuestLogQuestText()
        description    = _trim(description)
        objectivesText = _trim(objectivesText)

        -- Per-objective leaderboard lines.
        local objLines = {}
        for i = 1, (GetNumQuestLeaderBoards() or 0) do
            local text, _, finished = GetQuestLogLeaderBoard(i)
            text = _trim(text)
            if text ~= "" then
                local color = finished and "|cFF444444" or "|cFF000000"
                objLines[#objLines + 1] = color .. "" .. text .. " " .. (finished and "(Complete)" or "") .. "|r"
            end
        end

        -- Rewards: collect raw data into a struct, layout happens in
        -- _LayoutRewards (2-col grid of RewardTile + sub-headers).
        -- Captures the item link while the quest is selected so each
        -- tile can show the item's tooltip on hover via SetHyperlink
        -- without having to re-select the quest later.
        local rewards = { items = {}, choices = {}, xp = 0, money = 0 }
        rewards.xp    = (GetQuestLogRewardXP    and GetQuestLogRewardXP())    or 0
        rewards.money = (GetQuestLogRewardMoney and GetQuestLogRewardMoney()) or 0
        for i = 1, (GetNumQuestLogRewards() or 0) do
            local rname, ricon, count = GetQuestLogRewardInfo(i)
            if rname then
                rewards.items[#rewards.items + 1] = {
                    name  = rname, icon = ricon, count = count,
                    link  = GetQuestLogItemLink and GetQuestLogItemLink("reward", i) or nil,
                }
            end
        end
        for i = 1, (GetNumQuestLogChoices() or 0) do
            local cname, cicon, count = GetQuestLogChoiceInfo(i)
            if cname then
                rewards.choices[#rewards.choices + 1] = {
                    name  = cname, icon = cicon, count = count,
                    link  = GetQuestLogItemLink and GetQuestLogItemLink("choice", i) or nil,
                }
            end
        end
        self._rewardData = rewards

        -- Pushable for Share button (read while we're still selected).
        self._canShare = (GetQuestLogPushable() == 1)
                         and ((GetNumGroupMembers() or 0) > 0)

        SelectQuestLogEntry(prevSel)

        self._contentTitle:SetText(title or "")

        -- Objectives section (paragraph + leaderboard).
        if objectivesText and objectivesText ~= "" then
            self._contentObjBody:SetText(objectivesText)
            self._contentObjBody:Show()
        else
            self._contentObjBody:Hide()
        end
        if #objLines > 0 then
            self._contentObjList:SetText(table.concat(objLines, "\n"))
            self._contentObjList:Show()
        else
            self._contentObjList:Hide()
        end

        -- Description (flavor) section.
        if description and description ~= "" then
            self._contentDescBody:SetText(description)
            self._contentDescBody:Show()
            self._contentDescHeader:Show()
        else
            self._contentDescBody:Hide()
            self._contentDescHeader:Hide()
        end

        self:_UpdateButtonStates()
        self:_RefreshNpcModel(_PickQuestNpcCreature(questId))
        self:_LayoutContent()
        self:_RefreshScroll()
        -- Always start at the top of the quest's content.
        self.slider:SetValue(0)
        self.scroll:SetVerticalScroll(0)

        -- The first pass measures FontStrings before WoW has finished
        -- resolving the just-shown tab's anchor chain — wrap-widths are
        -- stale, so heights are off and the scroll/footer end up wrong.
        -- OnSizeChanged doesn't always fire (the tab's size may not
        -- actually change between hidden and shown), so explicitly
        -- defer a second layout pass to next frame.
        local pendingId = questId
        C_Timer.After(0, function()
            if self.questId ~= pendingId then return end
            self:_LayoutContent()
            self:_RefreshScroll()
            self.slider:SetValue(0)
            self.scroll:SetVerticalScroll(0)
        end)
    end;

    -- Chain-anchor the visible content FontStrings top-down inside
    -- self._content, sizing it to the sum of their heights. Then size
    -- self._footerContent's rewards block. _contentHeight = total
    -- (content + footer).
    _LayoutContent = function(self)
        -- Width must already be set on scrollChild (and propagated to
        -- _content via FillWidth) so the FontStrings know how to wrap.
        -- _RefreshScroll handles the propagation; SetQuest calls us
        -- between content set and final RefreshScroll.
        local s         = self.scrollChild:GetScale() or 1
        local viewportW = (self.scroll:GetWidth() or 0) / s
        self.scrollChild:SetWidth(viewportW)

        local function place(fs, top, gap)
            if not fs:IsShown() then return top end
            fs:ClearAllPoints()
            fs:AlignParentTop(top)
            fs:FillWidth(8)
            return top + (fs:GetStringHeight() or 0) + (gap or 0)
        end

        local y = 42
        y = place(self._contentTitle,      y, 6)
        y = place(self._contentObjBody,    y, 8)
        y = place(self._contentObjList,    y, 14)
        y = place(self._contentDescHeader, y, 6)
        y = place(self._contentDescBody,   y, 0)
        local contentBlockH = y
        self._content:SetHeight(contentBlockH)

        self._footerRewards:ClearAllPoints()
        self._footerRewards:AlignParentTop(2.5)
        self._footerRewards:FillWidth(8)
        local rh = self:_LayoutRewards()
        if rh > 0 then
            self._footer:Show()
            self._footerRewards:SetHeight(rh)

            local footerContentH = rh + 4
            self._footerContent:SetHeight(footerContentH)

            local footerH = 50 + footerContentH + 7
            self._footer:SetHeight(footerH)

            self._contentHeight = contentBlockH + footerH
        else
            -- No rewards at all → hide the whole footer (decorations +
            -- Rewards header + grid). _content takes the full scrollChild
            -- because _footer's height collapses to 0 and its Above()
            -- anchor pins _content.bottom at scrollChild.bottom.
            self._footer:Hide()
            self._footer:SetHeight(0)
            self._contentHeight = contentBlockH
        end
    end;

    -- Lay out the rewards block as retail's MapQuestInfoRewardsFrame:
    -- sub-headers ("Choose one of these rewards:" / "You will receive:")
    -- on full-width rows, RewardTiles in a 2-col grid below each header.
    -- Returns total block height (in _footerRewards local units).
    _LayoutRewards = function(self)
        -- Hide all pooled tiles + headers before re-acquiring by index.
        for _, t in ipairs(self._rewardTiles)   do t:Hide() end
        for _, h in ipairs(self._rewardHeaders) do h:Hide() end

        local data = self._rewardData
        if not data then return 0 end

        -- Tile width = (containerWidth - hgap) / 2, so two tiles + gap fit exactly.
        local containerW = self._footerRewards:GetWidth() or 0
        local tileW      = math.max(40, math.floor((containerW - TILE_HGAP) / 2))

        local nextTile, nextHeader = 0, 0
        local function getTile()
            nextTile = nextTile + 1
            local t = self._rewardTiles[nextTile]
            if not t then
                t = RewardTile(self._footerRewards)
                self._rewardTiles[nextTile] = t
            end
            t:SetWidth(tileW)
            t:Show()
            return t
        end
        local function getHeader(text)
            nextHeader = nextHeader + 1
            local h = self._rewardHeaders[nextHeader]
            if not h then
                h = FontString(self._footerRewards, nil, "OVERLAY")
                h:SetFont(MUI.FONT, 9)
                h:SetTextColor(0.902, 0.788, 0.671, 1)  -- retail's REWARD header tint
                h:SetJustifyH("LEFT")
                self._rewardHeaders[nextHeader] = h
            end
            h:SetText(text)
            h:Show()
            return h
        end

        -- Layout state — y is the top of the next element (relative to
        -- _footerRewards.top). leftSidePlaced tracks whether we've placed
        -- a left-column tile waiting for a right-column partner.
        local y = 0
        local leftSidePlaced, lastLeft = false, nil

        local function placeTile(tile)
            if leftSidePlaced then
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", lastLeft, "TOPRIGHT", TILE_HGAP, 0)
                leftSidePlaced, lastLeft = false, nil
                y = y + TILE_H + TILE_VGAP
            else
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", self._footerRewards, "TOPLEFT", 0, -y)
                leftSidePlaced, lastLeft = true, tile
            end
        end
        local function flushRow()
            if leftSidePlaced then
                -- Orphaned left tile finishes the row alone.
                y = y + TILE_H + TILE_VGAP
                leftSidePlaced, lastLeft = false, nil
            end
        end
        local function placeHeader(text)
            local h = getHeader(text)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT",  self._footerRewards, "TOPLEFT",  0, -y)
            h:SetPoint("RIGHT",    self._footerRewards, "RIGHT",    0,  0)
            y = y + (h:GetStringHeight() or 0) + HEADER_GAP
        end

        -- Tile entry helpers. Each section is a list of { kind=... }
        -- entries; placeSection iterates and dispatches.
        local function entryItem(item)   return { kind = "item",   item = item   } end
        local function entryChoice(item) return { kind = "choice", item = item   } end
        local entryXP    = (data.xp    > 0) and { kind = "xp"    } or nil
        local entryMoney = (data.money > 0) and { kind = "money" } or nil

        local function placeOne(entry)
            local t = getTile()
            if entry.kind == "xp" then
                t:SetReward(PH_XP, BreakUpLargeNumbers(data.xp), nil, nil)
                t:SetFontSize(11)
            elseif entry.kind == "money" then
                t:SetReward(PH_COIN, GetCoinTextureString(data.money, 12), nil, nil)
                t:SetFontSize(11)
            elseif entry.kind == "choice" then
                local c = entry.item
                t:SetReward(c.icon, c.name, c.count, c.link)
                t:SetFontSize(9)
            else  -- item
                local item = entry.item
                t:SetReward(item.icon, item.name, item.count, item.link)
                t:SetFontSize(9)
            end
            placeTile(t)
        end

        local function placeSection(header, list)
            if not header or #list == 0 then return end
            if y > 0 then y = y + SECTION_GAP - TILE_VGAP end
            placeHeader(header)
            for _, entry in ipairs(list) do placeOne(entry) end
            flushRow()
        end

        -- Build sections per the user's spec:
        --   1) choices + (anything else)        → "Choose one of these rewards:" + "You will also receive:" (rest)
        --   2) no choices, has items + xp/money → "You will receive:" (items) + "You will also receive:" (xp/money)
        --   3) no choices, items only           → "You will receive:" (items)
        --   4) no choices, no items, xp/money   → "You will receive:" (xp/money)
        --   5) nothing                          → return 0 (caller hides footer)
        local hasChoices = #data.choices > 0
        local hasItems   = #data.items   > 0
        local hasXPMoney = entryXP or entryMoney

        if hasChoices then
            -- Section 1: choices.
            local choices = {}
            for _, c in ipairs(data.choices) do choices[#choices + 1] = entryChoice(c) end
            placeSection("Choose one of these rewards:", choices)
            -- Section 2: everything else under "also receive".
            if hasItems or hasXPMoney then
                local rest = {}
                for _, item in ipairs(data.items) do rest[#rest + 1] = entryItem(item) end
                if entryXP    then rest[#rest + 1] = entryXP    end
                if entryMoney then rest[#rest + 1] = entryMoney end
                placeSection("You will also receive:", rest)
            end
        elseif hasItems then
            -- Section 1: items under "receive".
            local items = {}
            for _, item in ipairs(data.items) do items[#items + 1] = entryItem(item) end
            placeSection("You will receive:", items)
            -- Section 2: xp/money under "also receive" (only if any).
            if hasXPMoney then
                local rest = {}
                if entryXP    then rest[#rest + 1] = entryXP    end
                if entryMoney then rest[#rest + 1] = entryMoney end
                placeSection("You will also receive:", rest)
            end
        elseif hasXPMoney then
            -- Only xp/money — single section under "receive".
            local rest = {}
            if entryXP    then rest[#rest + 1] = entryXP    end
            if entryMoney then rest[#rest + 1] = entryMoney end
            placeSection("You will receive:", rest)
        end

        if y == 0 then return 0 end
        -- Strip the trailing TILE_VGAP after the last row.
        return math.max(0, y - TILE_VGAP)
    end;

    _UpdateButtonStates = function(self)
        if not self.questId then return end
        local tracked = MUI_QuestHelper:IsTracked(self.questId)
        self._btnTrack:SetText(tracked and "Untrack" or "Track")
        if self._canShare then
            self._btnShare:SetEnabled(true)
        else
            self._btnShare:SetEnabled(false)
        end
    end;
}
