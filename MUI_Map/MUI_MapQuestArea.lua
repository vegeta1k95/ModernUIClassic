-- MapQuestObjectiveArea + MapQuestAreaManager: world-map equivalent of
-- MUI_MinimapQuestObjectiveArea. Renders the precomputed objective areas
-- of a quest as retail-style blobs on the WorldMap canvas: each area
-- filled, with a soft glow band around its outline (and round its holes).
-- One area frame per tracked quest with non-empty clusters; the manager
-- creates / destroys them with the watcher and toggles visibility on focus /
-- hover. An objective found at a lone spot has no area here: on
-- this map the quest's pin marks it (the small area round such a spot is
-- the minimap's alone).
--
-- Visibility rule (per user spec):
--   focused              → show
--   POI button hovered   → show (PushQuestHover from MapQuestPoiManager)
--   log row hovered      → show (PushQuestHover from MapQuestLog)
--   otherwise            → hide
--
-- Shapes live in world yards (same convention as the minimap renderer).
-- Per redraw we project each point through MUI_MapMath:WorldToMap onto
-- the currently-displayed uiMap; shapes whose continent doesn't match the
-- map's are skipped, which lets a tracked Kalimdor quest's area stay
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
-- areas.
local MUI_MAP_QUEST_AREA_FRAME_LEVEL = 2700

-- Enum.UIMapType.Zone == 3. Areas only render on zone-level maps;
-- continent / world / cosmic views suppress them (the projected outline
-- would technically still resolve via WorldToMap, but the cluster looks
-- like garbage at those zooms — same convention as static pins).
local ZONE_MAP_TYPE = 3

-- Blob look: a light-blue fill and a band around it that fades outward
-- from near-white at the fill's edge (the colours of the old outline).
local FILL_COLOR   = { 0.45, 0.62, 1.00, 0.35 }
local BORDER_INNER = CreateColor(0.70, 0.90, 1.00, 0.90)   -- at the fill's edge
local BORDER_OUTER = CreateColor(0.35, 0.40, 1.00, 0.00)   -- outer rim
local BORDER_WIDTH = 9      -- band width, canvas px
local BORDER_INSET = 1      -- of which this much sits inside the fill's edge

class "MapQuestObjectiveArea" : extends "Frame" {
    __init = function(self, name, questId)
        self._shapes          = {}
        self._continent       = nil
        self._fills           = { used = 0 }
        self._borders         = { used = 0 }
        self._projected       = nil       -- the shapes in normalized [0,1] map coords
        self._drawnKey        = nil       -- the map and canvas size the pieces are laid out for
        self._questId         = questId   -- needed for tooltip + hover push/pop
        self._tooltipActive   = false
        self._tooltipKey      = nil       -- the targets the tooltip up now lists

        local canvas = _Canvas()
        Frame.__init(self, "Frame", canvas, name)
        self:SetAllPoints(canvas and canvas._native or nil)
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(MUI_MAP_QUEST_AREA_FRAME_LEVEL)
        self:Hide()

        -- Hover detection: poll IsMouseOver each frame the area is shown
        -- (OnUpdate doesn't run on hidden frames). On enter → show the
        -- POI-style quest tooltip + push hover (which reinforces this
        -- quest's visibility while the cursor's over the area). On
        -- leave → reverse both.
        self:SetScript("OnUpdate", function() self:_PollHover() end)

        -- Tooltip cleanup: the cursor may be over the area when we go hidden
        -- (focus cleared, solo filter, or the whole map closing, which never
        -- calls our Hide). OnHide covers all of them; drop the tooltip so it
        -- doesn't dangle.
        self:SetScript("OnHide", function()
            if self._tooltipActive then
                self._tooltipActive = false
                self._tooltipKey = nil
                MUI_Tooltip:Hide()
            end
        end)
    end;

    -- shapes: list of area shapes in world yards (the `shape` of each
    -- QuestObjectiveCluster:GetClusters() entry). The same shapes again
    -- leave what is drawn alone.
    SetShapes = function(self, shapes, continentId)
        shapes = shapes or {}
        local same = continentId == self._continent and #shapes == #self._shapes
        for i = 1, #shapes do
            same = same and shapes[i] == self._shapes[i]
        end
        if not same then
            self._shapes    = shapes
            self._continent = continentId
            self._drawnKey  = nil
        end
        if self:IsShown() then self:_Refresh() end
    end;

    Refresh = function(self) self:_Refresh() end;

    -- Lays the pieces out for the displayed map, once the area shows on it.
    -- They stay laid out while the frame is hidden, so showing it again for
    -- the same map and canvas size costs nothing.
    _Refresh = function(self)
        if not self:IsShown() or not WorldMapFrame:IsShown() then return end
        local uiMapId = WorldMapFrame:GetMapID()
        if not uiMapId or #self._shapes == 0 then
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

        local key = uiMapId .. ":" .. W .. ":" .. H
        if key == self._drawnKey then return end
        self._drawnKey = key

        self._fills.used, self._borders.used = 0, 0
        local projected = {}
        for _, shape in ipairs(self._shapes) do
            -- Normalized rings for the hover test, canvas px for drawing.
            local proj = { shape = shape, rings = {} }
            local rings, ok = {}, true
            for k, ring in ipairs(shape.rings) do
                local norm, px = {}, {}
                for i = 1, #ring, 2 do
                    local nx, ny = MUI_MapMath:WorldToMap(
                        uiMapId, ring[i], ring[i + 1], self._continent)
                    if not nx then ok = false; break end
                    norm[i], norm[i + 1] = nx, ny
                    px[i],   px[i + 1]   = nx * W, -ny * H
                end
                if not ok then break end
                proj.rings[k], rings[k] = norm, px
            end
            if ok then
                proj.box = { MUI_BlobOutline:Bounds(proj.rings) }
                projected[#projected + 1] = proj
                self:_DrawShape(rings, shape.tris)
            end
        end
        -- Cache the projected shapes for the per-frame hover test in
        -- _PollHover / IsMouseOver.
        self._projected = projected

        for i = self._fills.used + 1, #self._fills do self._fills[i]:Hide() end
        for i = self._borders.used + 1, #self._borders do self._borders[i]:Hide() end
    end;

    -- True if the cursor is inside ANY projected shape.
    IsMouseOver = function(self)
        return self:_HoveredTargets() ~= nil
    end;

    -- What the cursor is over, nil when it is inside no projected shape:
    -- a key naming the targets of the shapes it is inside, and those
    -- targets as two sets, objective lines (indices into the quest's
    -- leaderboard) and required source items. Shapes of different
    -- objectives overlap, so it can be several. A shape that names no
    -- target (no leaderboard yet) stands for the whole quest: the key is
    -- then "" and there are no sets.
    -- Cursor is normalized to [0,1] map coords (matching _projected) and
    -- tried against each shape's box, then its rings.
    _HoveredTargets = function(self)
        if not self:IsShown() then return nil end
        local shapes = self._projected
        if not shapes or #shapes == 0 then return nil end
        local W, H = self:GetWidth(), self:GetHeight()
        if not W or not H or W <= 0 or H <= 0 then return nil end

        local scale = self:GetEffectiveScale()
        if not scale or scale == 0 then return nil end
        local mx, my = GetCursorPosition()
        if not mx then return nil end
        mx, my = mx / scale, my / scale

        local left, top = self:GetLeft(), self:GetTop()
        if not left or not top then return nil end
        local px = (mx - left) / W
        local py = (top - my) / H
        if px < 0 or px > 1 or py < 0 or py > 1 then return nil end

        local key, objectives, items, whole
        for _, proj in ipairs(shapes) do
            local box = proj.box
            if px >= box[1] and px <= box[3] and py >= box[2] and py <= box[4]
                    and MUI_BlobOutline:Contains(proj.rings, px, py) then
                local shape = proj.shape
                key = key or ""
                objectives, items = objectives or {}, items or {}
                if shape.objective then
                    if not objectives[shape.objective] then
                        objectives[shape.objective] = true
                        key = key .. "o" .. shape.objective
                    end
                elseif shape.itemId then
                    if not items[shape.itemId] then
                        items[shape.itemId] = true
                        key = key .. "i" .. shape.itemId
                    end
                else
                    whole = true
                end
            end
        end
        if whole then return "" end
        return key, objectives, items
    end;

    _PollHover = function(self)
        if not self._questId then return end
        local key, objectives, items = self:_HoveredTargets()
        if key then
            self._tooltipActive = true
            -- Re-assert tooltip when something else has hidden it
            -- while our cursor is still inside the area (concrete case:
            -- cursor moves POI → area, POI:OnLeave hid the tooltip).
            -- Cheap — only rebuilds when it isn't already up, or when the
            -- cursor has moved onto another objective's area.
            if key ~= self._tooltipKey or not MUI_Tooltip:IsShown() then
                self._tooltipKey = key
                MUI_QuestHelper:ShowMapQuestTooltip(self, self._questId, objectives, items)
            end
        elseif self._tooltipActive then
            self._tooltipActive = false
            self._tooltipKey = nil
            MUI_Tooltip:Hide()
        end
        -- Intentionally NO PushQuestHover/PopQuestHover here. The area's
        -- own cursor-hover must not keep the area alive — visibility is
        -- driven solely by focus + POI / log-row hover, so unfocused
        -- areas disappear the instant the POI is left, even if the
        -- cursor is still inside the outline.
    end;

    -- One shape, its `rings` in canvas px: a piece per triangle of `tris`
    -- for the fill (a quad with two corners on one point), and a quad per
    -- ring segment along per-vertex outward normals for the glow band, its
    -- opaque edge on the fill's. Neighbouring pieces share their vertices,
    -- so both are seamless.
    _DrawShape = function(self, rings, tris)
        local xs, ys = {}, {}
        local outer = BORDER_WIDTH - BORDER_INSET
        for k, ring in ipairs(rings) do
            local n = #ring / 2
            -- Outward is to the right of the ring's direction when the area
            -- is on its left.
            local side = MUI_BlobOutline:AreaOnLeft(rings, k) and 1 or -1
            local nx, ny = {}, {}
            for i = 1, n do
                local p, q = ((i - 2) % n) * 2, (i % n) * 2
                local tx, ty = ring[q + 1] - ring[p + 1], ring[q + 2] - ring[p + 2]
                local len = math.sqrt(tx * tx + ty * ty)
                if len > 0 then
                    nx[i], ny[i] = side * ty / len, -side * tx / len
                else
                    nx[i], ny[i] = 0, 0
                end
                xs[#xs + 1], ys[#ys + 1] = ring[2 * i - 1], ring[2 * i]
            end
            for i = 1, n do
                local j = i % n + 1
                local ax, ay, bx, by = ring[2 * i - 1], ring[2 * i], ring[2 * j - 1], ring[2 * j]
                self:_Piece(self._borders, 2)
                    :SetQuad(
                        ax - nx[i] * BORDER_INSET, ay - ny[i] * BORDER_INSET,
                        ax + nx[i] * outer,        ay + ny[i] * outer,
                        bx - nx[j] * BORDER_INSET, by - ny[j] * BORDER_INSET,
                        bx + nx[j] * outer,        by + ny[j] * outer)
            end
        end

        for t = 1, #tris, 3 do
            local a, b, c = tris[t], tris[t + 1], tris[t + 2]
            self:_Piece(self._fills, 1)
                :SetQuad(xs[a], ys[a], xs[c], ys[c], xs[b], ys[b], xs[c], ys[c])
        end
    end;

    -- Next texture of a pool (`used` counts this redraw's pieces). A band
    -- piece is a vertical gradient: its top edge lies on the fill's edge.
    _Piece = function(self, pool, subLevel)
        pool.used = pool.used + 1
        local tex = pool[pool.used]
        if not tex then
            tex = Texture(self, nil, "ARTWORK")
            tex:SetDrawLayer("ARTWORK", subLevel)
            if pool == self._fills then
                tex:SetColorTexture(FILL_COLOR[1], FILL_COLOR[2], FILL_COLOR[3], FILL_COLOR[4])
            else
                tex:SetColorTexture(1, 1, 1, 1)
                tex:SetGradient("VERTICAL", BORDER_OUTER, BORDER_INNER)
            end
            tex:SetSubpixelRendering(true)
            pool[pool.used] = tex
        end
        tex:Show()
        return tex
    end;

    -- Nothing to draw on the displayed map.
    _HideEdges = function(self)
        for _, t in ipairs(self._fills) do t:Hide() end
        for _, t in ipairs(self._borders) do t:Hide() end
        self._drawnKey  = nil
        self._projected = nil
    end;

    Show = function(self)
        Frame.Show(self)
        self:_Refresh()
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
            self:_UpdateAll()
        end)

        -- Re-project areas every time the world map is opened. OnMapChanged
        -- only fires when the map ID changes, so opening the map with the
        -- same map ID as last time (common: focus changed in tracker
        -- while map was closed) wouldn't trigger a refresh — the focused
        -- area's _Refresh ran while WorldMapFrame:IsShown() was false and
        -- early-returned, leaving lines hidden until the next hover/focus
        -- event nudged the area back through _Refresh.
        WorldMapFrame:HookScript("OnShow", function()
            self:_UpdateAll()
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
        if not cluster then
            self:_Destroy(questId); return
        end
        -- Targets on the displayed map's continent; _UpdateAll re-picks
        -- on every map change.
        local cont = self:_DisplayedContinent() or cluster:GetContinent()
        local shapes = {}
        for _, c in ipairs(cluster:GetClusters(cont)) do
            shapes[#shapes + 1] = c.shape
        end
        if #shapes == 0 then self:_Destroy(questId); return end

        local area = self._areas[questId]
        if not area then
            area = MapQuestObjectiveArea("MUI_MapQuestArea_" .. questId, questId)
            self._areas[questId] = area
        end
        area:SetShapes(shapes, cont)
        self:_ApplyVisibility(questId)
    end;

    _DisplayedContinent = function(self)
        local mapId = WorldMapFrame:GetMapID()
        if not mapId then return nil end
        local _, _, cont = MUI_MapMath:MapToWorld(mapId, 0.5, 0.5)
        return cont
    end;

    _UpdateAll = function(self)
        for questId in pairs(self.watcher:GetWatched() or {}) do
            self:_Update(questId)
        end
        for _, area in pairs(self._areas) do area:Refresh() end
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
        -- area renders regardless of focus / hover.
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

    -- Restrict the manager to a single quest's area (others hidden), or
    -- pass nil to clear. Mirrors MapQuestPoiManager:SetSoloQuestFilter
    -- — ModuleMap:ShowQuestDescription / ShowQuestLog drive both so the
    -- description tab shows its own quest's area and suppresses others
    -- (including a different focused quest).
    SetSoloQuestFilter = function(self, questId)
        if self._soloQuestId == questId then return end
        self._soloQuestId = questId
        for qid in pairs(self._areas) do
            self:_ApplyVisibility(qid)
        end
    end;
}
