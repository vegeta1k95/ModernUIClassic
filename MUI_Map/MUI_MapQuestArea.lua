-- MapQuestObjectiveArea + MapQuestAreaManager: world-map equivalent of
-- MUI_MinimapQuestObjectiveArea. Renders the precomputed objective convex
-- hulls of a quest as polygon outlines on the WorldMap canvas. One area
-- per tracked quest with non-empty clusters; the manager creates/destroys
-- them with the watcher and toggles visibility on focus/hover changes.
--
-- Visibility rule (per user spec):
--   focused              → show
--   POI button hovered   → show (PushQuestHover from MapQuestPoiManager)
--   log row hovered      → show (PushQuestHover from MapQuestLog)
--   otherwise            → hide
--
-- Hulls live in world yards (same convention as the minimap renderer).
-- Per refresh we project each vertex through MUI_MapMath:WorldToMap onto
-- the currently-displayed uiMap; hulls whose continent doesn't match the
-- map's are skipped, which lets a tracked Kalimdor quest's hull stay
-- silent while the user browses Eastern Kingdoms zones.

local _canvasWrapper
local function _Canvas()
    if _canvasWrapper then return _canvasWrapper end
    if not WorldMapFrame or not WorldMapFrame.GetCanvas then return nil end
    local native = WorldMapFrame:GetCanvas()
    if not native then return nil end
    _canvasWrapper = Frame(native)
    return _canvasWrapper
end

-- Frame-level: above the explored-area overlay (Blizzard MapCanvas pin
-- frame levels start at 2000 and grow with each pin type), below our own
-- pins (MUI_MAP_PIN_FRAME_LEVEL = 3000) so pins always draw on top of
-- hulls.
local MUI_MAP_QUEST_AREA_FRAME_LEVEL = 2700

-- Enum.UIMapType.Zone == 3. Hulls only render on zone-level maps;
-- continent / world / cosmic views suppress them (the projected polygon
-- would technically still resolve via WorldToMap, but the cluster looks
-- like garbage at those zooms — same convention as static pins).
local ZONE_MAP_TYPE = 3

-- Halo + core thickness (in canvas pixels). Mirrors the minimap area
-- renderer so both surfaces look like the same widget family.
local GLOW_THICK = 5
local CORE_THICK = 30

-- Per-hull adaptive core thickness. The core gradient extends INWARD
-- from each edge by CORE_THICK pixels; on a hull narrower than 2x
-- CORE_THICK the cores from opposing edges overlap and add up into a
-- bright blob. Cap the per-hull core thickness at half the polygon's
-- narrowest projected dimension. Bounding-box min-side is a lower
-- bound on the true min width and good enough — the exact min-width
-- of a convex polygon is O(n) but unnecessarily precise here.
local function _AdaptiveCoreThick(proj, W, H)
    local minX, maxX =  math.huge, -math.huge
    local minY, maxY =  math.huge, -math.huge
    for _, p in ipairs(proj) do
        local px, py = p[1] * W, p[2] * H
        if px < minX then minX = px end
        if px > maxX then maxX = px end
        if py < minY then minY = py end
        if py > maxY then maxY = py end
    end
    local minWidthPx = math.min(maxX - minX, maxY - minY)
    return math.max(0, math.min(CORE_THICK, minWidthPx * 0.5))
end

class "MapQuestObjectiveArea" : extends "Frame" {
    __init = function(self, name, questId)
        -- Field init MUST come before self:Hide() — our Hide override
        -- calls _HideEdges() which iterates the line pools.
        self._hulls           = {}
        self._continent       = nil
        self._halos           = {}
        self._cores           = {}
        self._projectedHulls  = nil       -- hulls in normalized [0,1] map coords
        self._questId         = questId   -- needed for tooltip + hover push/pop
        self._tooltipActive   = false

        local canvas = _Canvas()
        Frame.__init(self, "Frame", canvas, name)
        self:SetAllPoints(canvas and canvas._native or nil)
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(MUI_MAP_QUEST_AREA_FRAME_LEVEL)
        self:SetAlpha(0.8)
        self:Hide()

        -- Hover detection: poll IsMouseOver each frame the area is shown
        -- (OnUpdate doesn't run on hidden frames). On enter → show the
        -- POI-style quest tooltip + push hover (which reinforces this
        -- quest's visibility while the cursor's over the hull). On
        -- leave → reverse both.
        self:SetScript("OnUpdate", function() self:_PollHover() end)
    end;

    SetHulls = function(self, hulls, continentId)
        self._hulls     = hulls or {}
        self._continent = continentId
        if self:IsShown() then self:_Refresh() end
    end;

    Refresh = function(self) self:_Refresh() end;

    _Refresh = function(self)
        if not WorldMapFrame or not WorldMapFrame:IsShown() then
            self:_HideEdges(); return
        end
        local uiMapId = WorldMapFrame:GetMapID()
        if not uiMapId or not self._hulls or #self._hulls == 0 then
            self:_HideEdges(); return
        end
        local info = C_Map.GetMapInfo(uiMapId)
        if not info or info.mapType ~= ZONE_MAP_TYPE then
            self:_HideEdges(); return
        end

        local W, H = self:GetWidth(), self:GetHeight()
        if not W or not H or W <= 0 or H <= 0 then
            self:_HideEdges(); return
        end

        local edgeIdx = 0
        local projected = {}
        for _, hull in ipairs(self._hulls) do
            local proj = {}
            local ok = true
            for i, v in ipairs(hull) do
                local nx, ny = MUI_MapMath:WorldToMap(
                    uiMapId, v[1], v[2], self._continent)
                if not nx then ok = false; break end
                proj[i] = { nx, ny }
            end
            if ok then
                projected[#projected + 1] = proj
                -- Cap core thickness at half the polygon's narrowest
                -- projected dimension so opposing-edge cores can't blob
                -- together on thin hulls.
                local coreThick = _AdaptiveCoreThick(proj, W, H)
                local n = #proj
                for i = 1, n do
                    local a = proj[i]
                    local b = proj[(i % n) + 1]
                    edgeIdx = edgeIdx + 1
                    self:_DrawEdge(edgeIdx, coreThick,
                        a[1] * W, -a[2] * H,
                        b[1] * W, -b[2] * H)
                end
            end
        end
        -- Cache projected hulls in normalized [0,1] map coords for the
        -- per-frame hover test in _PollHover / IsMouseOver.
        self._projectedHulls = projected

        for i = edgeIdx + 1, #self._halos do
            self._halos[i]:Hide()
            if self._cores[i] then self._cores[i]:Hide() end
        end
    end;

    -- True if the cursor is inside ANY projected hull. Cursor is
    -- normalized to [0,1] map coords (matching _projectedHulls), then
    -- a sign-agnostic point-in-convex test runs per hull. Sign-
    -- agnostic so we don't have to track winding direction (the
    -- exporter's CCW-in-yards becomes CW-in-y-down here).
    IsMouseOver = function(self)
        if not self:IsShown() then return false end
        local hulls = self._projectedHulls
        if not hulls or #hulls == 0 then return false end
        local W, H = self:GetWidth(), self:GetHeight()
        if not W or not H or W <= 0 or H <= 0 then return false end

        local scale = self:GetEffectiveScale()
        if not scale or scale == 0 then return false end
        local mx, my = GetCursorPosition()
        if not mx then return false end
        mx, my = mx / scale, my / scale

        local left, top = self:GetLeft(), self:GetTop()
        if not left or not top then return false end
        local px = (mx - left) / W
        local py = (top - my) / H
        if px < 0 or px > 1 or py < 0 or py > 1 then return false end

        for _, hull in ipairs(hulls) do
            local n = #hull
            if n >= 3 then
                local prevSign, inside = nil, true
                for i = 1, n do
                    local a = hull[i]
                    local b = hull[(i % n) + 1]
                    local cross = (b[1] - a[1]) * (py - a[2])
                                - (b[2] - a[2]) * (px - a[1])
                    local s = cross >= 0
                    if prevSign == nil then
                        prevSign = s
                    elseif s ~= prevSign then
                        inside = false
                        break
                    end
                end
                if inside then return true end
            end
        end
        return false
    end;

    _PollHover = function(self)
        if not self._questId then return end
        local over = self:IsMouseOver()
        if over then
            self._tooltipActive = true
            -- Re-assert tooltip when something else has hidden it
            -- while our cursor is still inside the hull (concrete case:
            -- cursor moves POI → hull, POI:OnLeave hid the tooltip).
            -- Cheap — only rebuilds when it isn't already up.
            if not MUI_Tooltip:IsShown() then
                MUI_QuestHelper:ShowMapQuestTooltip(self, self._questId)
            end
        elseif self._tooltipActive then
            self._tooltipActive = false
            MUI_Tooltip:Hide()
        end
        -- Intentionally NO PushQuestHover/PopQuestHover here. The hull's
        -- own cursor-hover must not keep the hull alive — visibility is
        -- driven solely by focus + POI / log-row hover, so unfocused
        -- hulls disappear the instant the POI is left, even if the
        -- cursor is still inside the polygon.
    end;

    -- Same halo/core dual-line treatment as MinimapQuestObjectiveArea: a
    -- thick gradient halo (transparent → near-white outward) plus a thin
    -- core (near-white → transparent inward), offset perpendicular to
    -- the edge direction so the gradient bands sit cleanly on either
    -- side of the hull edge. Endpoints are anchored to self's TOPLEFT
    -- because (ax, ay) come in already as canvas-pixel offsets.
    _DrawEdge = function(self, index, coreThick, ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then return end
        local nx =  dy / len
        local ny = -dx / len
        local hx, hy = nx * GLOW_THICK * 0.5, ny * GLOW_THICK * 0.5
        local cx, cy = nx * coreThick * 0.5, ny * coreThick * 0.5

        local halo = self._halos[index]
        if not halo then
            halo = Line(self, nil, "ARTWORK")
            halo:SetSubpixelRendering(true)
            halo:SetColorTexture(1, 1, 1, 1)
            halo:SetThickness(GLOW_THICK)
            halo:SetGradient("VERTICAL",
                CreateColor(0.35, 0.40, 1.00, 0.00),    -- outer: transparent light-blue
                CreateColor(0.70, 0.90, 1.00, 1.00))    -- hull edge: near-white
            self._halos[index] = halo
        end
        halo:SetStartPoint("TOPLEFT", self, ax + hx, ay + hy)
        halo:SetEndPoint("TOPLEFT",   self, bx + hx, by + hy)
        halo:Show()

        -- Skip core entirely on hulls so narrow the adaptive thickness
        -- is essentially zero — the line would be invisible anyway.
        if coreThick < 0.5 then
            if self._cores[index] then self._cores[index]:Hide() end
            return
        end

        local core = self._cores[index]
        if not core then
            core = Line(self, nil, "OVERLAY")
            core:SetSubpixelRendering(true)
            core:SetColorTexture(1, 1, 1, 1)
            core:SetGradient("VERTICAL",
                CreateColor(0.80, 1.00, 1.00, 1.00),    -- hull edge: near-white
                CreateColor(0.35, 0.40, 1.00, 0.00))    -- inward: transparent
            self._cores[index] = core
        end
        core:SetThickness(coreThick)
        core:SetStartPoint("TOPLEFT", self, ax - cx, ay - cy)
        core:SetEndPoint("TOPLEFT",   self, bx - cx, by - cy)
        core:Show()
    end;

    _HideEdges = function(self)
        for _, l in ipairs(self._halos) do l:Hide() end
        for _, l in ipairs(self._cores) do l:Hide() end
    end;

    Show = function(self)
        Frame.Show(self)
        self:_Refresh()
    end;

    Hide = function(self)
        Frame.Hide(self)
        self:_HideEdges()
        -- Tooltip cleanup: cursor may have been over the hull at the
        -- moment we got hidden (e.g. focus cleared, solo filter
        -- rejected us). Drop the tooltip so it doesn't dangle.
        if self._tooltipActive then
            self._tooltipActive = false
            MUI_Tooltip:Hide()
        end
    end;

    Destroy = function(self)
        self:_HideEdges()
        self:Hide()
        self:ClearAllPoints()
    end;
}

-- Owns one MapQuestObjectiveArea per tracked quest with non-empty
-- clusters. Lifecycle is driven by the QuestLogWatcher + tracking +
-- cluster listeners; visibility is driven by focus + hover.
class "MapQuestAreaManager" : extends "Frame" {
    __init = function(self, watcher)
        Frame.__init(self, "Frame", nil, "MUI_MapQuestAreaManagerDriver")
        self.watcher = watcher
        self._areas  = {}    -- questId -> MapQuestObjectiveArea

        watcher:RegisterCallback("OnQuestAdded",  function(questId) self:_Update(questId) end)
        watcher:RegisterCallback("OnQuestRemoved", function(questId) self:_Destroy(questId) end)
        watcher:RegisterCallback("OnQuestChanged", function(questId) self:_Update(questId) end)

        MUI_QuestHelper:RegisterClustersChangedListener(function(questId)
            self:_Update(questId)
        end)
        MUI_QuestHelper:RegisterTrackingListener(function(questId, tracked)
            if tracked then self:_Update(questId)
            else            self:_Destroy(questId)
            end
        end)
        MUI_FocusManager:RegisterChangeListener(function(prevKind, prevKey, newKind, newKey)
            if prevKind == "quest" and prevKey then self:_ApplyVisibility(prevKey) end
            if newKind  == "quest" and newKey  then self:_ApplyVisibility(newKey)  end
        end)
        MUI_QuestHelper:RegisterQuestHoverListener(function(questId)
            self:_ApplyVisibility(questId)
        end)

        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            for _, area in pairs(self._areas) do area:Refresh() end
        end)

        -- Re-project hulls every time the world map is opened. OnMapChanged
        -- only fires when the map ID changes, so opening the map with the
        -- same map ID as last time (common: focus changed in tracker
        -- while map was closed) wouldn't trigger a refresh — the focused
        -- area's _Refresh ran while WorldMapFrame:IsShown() was false and
        -- early-returned, leaving lines hidden until the next hover/focus
        -- event nudged the area back through _Refresh.
        WorldMapFrame:HookScript("OnShow", function()
            for _, area in pairs(self._areas) do area:Refresh() end
        end)

        for questId in pairs(watcher:GetWatched() or {}) do
            self:_Update(questId)
        end
    end;

    _Update = function(self, questId)
        if not MUI_QuestHelper:IsTracked(questId) then
            self:_Destroy(questId); return
        end
        local cluster = MUI_QuestHelper:GetQuestClusters(questId)
        if not cluster or not cluster:HasClusters() then
            self:_Destroy(questId); return
        end
        local hulls = {}
        for _, c in ipairs(cluster:GetClusters()) do
            if c.hull then hulls[#hulls + 1] = c.hull end
        end
        if #hulls == 0 then self:_Destroy(questId); return end

        local area = self._areas[questId]
        if not area then
            area = MapQuestObjectiveArea("MUI_MapQuestArea_" .. questId, questId)
            self._areas[questId] = area
        end
        area:SetHulls(hulls, cluster:GetContinent())
        self:_ApplyVisibility(questId)
    end;

    _Destroy = function(self, questId)
        local area = self._areas[questId]
        if area then
            area:Destroy()
            self._areas[questId] = nil
        end
    end;

    _ApplyVisibility = function(self, questId)
        local area = self._areas[questId]
        if not area then return end
        -- Master toggle from the world-map filter button. When off, no
        -- hull renders regardless of focus / hover.
        local s_qh = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        if s_qh and s_qh.showObjectivesOnMap == false then
            area:Hide()
            return
        end
        local soloOk = (not self._soloQuestId) or (self._soloQuestId == questId)
        local visible = soloOk and (
                            MUI_QuestHelper:IsFocused(questId)
                         or MUI_QuestHelper:IsQuestHovered(questId))
        if visible then area:Show() else area:Hide() end
    end;

    -- Walk every tracked quest's area and re-evaluate visibility.
    -- Called by the filter button's "Show quest objectives" toggle so a
    -- flip immediately propagates without having to nudge focus/hover.
    RefreshAll = function(self)
        for qid in pairs(self._areas) do
            self:_ApplyVisibility(qid)
        end
    end;

    -- Restrict the manager to a single quest's hull (others hidden), or
    -- pass nil to clear. Mirrors MapQuestPoiManager:SetSoloQuestFilter
    -- — ModuleMap:ShowQuestDescription / ShowQuestLog drive both so the
    -- description tab shows its own quest's hull and suppresses others
    -- (including a different focused quest).
    SetSoloQuestFilter = function(self, questId)
        if self._soloQuestId == questId then return end
        self._soloQuestId = questId
        for qid in pairs(self._areas) do
            self:_ApplyVisibility(qid)
        end
    end;
}
