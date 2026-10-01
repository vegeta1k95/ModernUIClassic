-- MapQuestObjectiveArea + MapQuestAreaManager: world-map equivalent of
-- MUI_MinimapQuestObjectiveArea. Renders the precomputed objective convex
-- hulls of a quest as retail-style blobs on the WorldMap canvas: each hull
-- rounded into a smooth outline, filled, with a soft glow band around it.
-- One area per tracked quest with non-empty clusters; the manager creates /
-- destroys them with the watcher and toggles visibility on focus / hover.
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

-- Blob look: a light-blue fill and a band around it that fades outward
-- from near-white at the fill's edge (the colours of the old outline).
local FILL_COLOR   = { 0.45, 0.62, 1.00, 0.35 }
local BORDER_INNER = CreateColor(0.70, 0.90, 1.00, 0.90)   -- at the fill's edge
local BORDER_OUTER = CreateColor(0.35, 0.40, 1.00, 0.00)   -- outer rim
local BORDER_WIDTH = 9      -- band width, canvas px
local BORDER_INSET = 1      -- of which this much sits inside the fill's edge
local BLOB_PAD     = 8      -- least margin between a hull vertex and the outline, canvas px

-- Stray-point circle radius (world yards). Small: BLOB_PAD already grows a
-- lone point into a blob that reads at zone-map scale.
local STRAY_CIRCLE_YARDS = 15

class "MapQuestObjectiveArea" : extends "Frame" {
    __init = function(self, name, questId)
        -- Field init MUST come before self:Hide() — our Hide override
        -- calls _HideEdges() which iterates the texture pools.
        self._hulls           = {}
        self._continent       = nil
        self._fills           = { used = 0 }
        self._borders         = { used = 0 }
        self._projectedHulls  = nil       -- hulls in normalized [0,1] map coords
        self._questId         = questId   -- needed for tooltip + hover push/pop
        self._tooltipActive   = false

        local canvas = _Canvas()
        Frame.__init(self, "Frame", canvas, name)
        self:SetAllPoints(canvas and canvas._native or nil)
        self:SetFrameStrata("MEDIUM")
        self:SetFrameLevel(MUI_MAP_QUEST_AREA_FRAME_LEVEL)
        self:Hide()

        -- Hover detection: poll IsMouseOver each frame the area is shown
        -- (OnUpdate doesn't run on hidden frames). On enter → show the
        -- POI-style quest tooltip + push hover (which reinforces this
        -- quest's visibility while the cursor's over the hull). On
        -- leave → reverse both.
        self:SetScript("OnUpdate", function() self:_PollHover() end)

        -- Tooltip cleanup: the cursor may be over the hull when we go hidden
        -- (focus cleared, solo filter, or the whole map closing, which never
        -- calls our Hide). OnHide covers all of them; drop the tooltip so it
        -- doesn't dangle.
        self:SetScript("OnHide", function()
            if self._tooltipActive then
                self._tooltipActive = false
                MUI_Tooltip:Hide()
            end
        end)
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

        self._fills.used, self._borders.used = 0, 0
        local projected = {}
        for _, hull in ipairs(self._hulls) do
            local proj, pts = {}, {}
            local ok = #hull >= 1
            for i, v in ipairs(hull) do
                local nx, ny = MUI_MapMath:WorldToMap(
                    uiMapId, v[1], v[2], self._continent)
                if not nx then ok = false; break end
                proj[i] = { nx, ny }
                pts[i]  = { nx * W, -ny * H }
            end
            if ok then
                projected[#projected + 1] = proj
                self:_DrawBlob(MUI_BlobOutline:Round(pts, BLOB_PAD))
            end
        end
        -- Cache projected hulls in normalized [0,1] map coords for the
        -- per-frame hover test in _PollHover / IsMouseOver.
        self._projectedHulls = projected

        for i = self._fills.used + 1, #self._fills do self._fills[i]:Hide() end
        for i = self._borders.used + 1, #self._borders do self._borders[i]:Hide() end
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

    -- One rounded hull: a triangle fan from the centroid for the fill (the
    -- quad's two lower corners collapse there), and a quad per segment along
    -- per-vertex outward normals for the glow band, its opaque edge on the
    -- fill's. Neighbouring quads share their vertices, so both are
    -- seamless.
    _DrawBlob = function(self, pts, cx, cy)
        local n = #pts
        local nx, ny = {}, {}
        for i = 1, n do
            local p, q = pts[(i - 2) % n + 1], pts[i % n + 1]
            local tx, ty = q[1] - p[1], q[2] - p[2]
            local len = math.sqrt(tx * tx + ty * ty)
            local ax, ay = 0, 0
            if len > 0 then ax, ay = ty / len, -tx / len end
            if ax * (pts[i][1] - cx) + ay * (pts[i][2] - cy) < 0 then ax, ay = -ax, -ay end
            nx[i], ny[i] = ax, ay
        end

        local outer = BORDER_WIDTH - BORDER_INSET
        for i = 1, n do
            local j = i % n + 1
            local a, b = pts[i], pts[j]
            self:_Piece(self._fills, 1)
                :SetQuad(a[1], a[2], cx, cy, b[1], b[2], cx, cy)
            self:_Piece(self._borders, 2)
                :SetQuad(
                    a[1] - nx[i] * BORDER_INSET, a[2] - ny[i] * BORDER_INSET,
                    a[1] + nx[i] * outer,        a[2] + ny[i] * outer,
                    b[1] - nx[j] * BORDER_INSET, b[2] - ny[j] * BORDER_INSET,
                    b[1] + nx[j] * outer,        b[2] + ny[j] * outer)
        end
    end;

    -- Next texture of a pool (`used` counts this refresh's pieces). A band
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

    _HideEdges = function(self)
        for _, t in ipairs(self._fills) do t:Hide() end
        for _, t in ipairs(self._borders) do t:Hide() end
    end;

    Show = function(self)
        Frame.Show(self)
        self:_Refresh()
    end;

    Hide = function(self)
        Frame.Hide(self)
        self:_HideEdges()
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

        -- Re-project hulls every time the world map is opened. OnMapChanged
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
        -- Real hulls when the quest has enough points to form one; otherwise
        -- per-point stray circles, as on the minimap, so scattered single
        -- locations (scout camps, lone objects) still get an area.
        local hulls = {}
        local real = cluster:GetClusters(cont)
        if #real > 0 then
            for _, c in ipairs(real) do
                if c.hull then hulls[#hulls + 1] = c.hull end
            end
        else
            hulls = cluster:GetStrayHulls(STRAY_CIRCLE_YARDS, cont)
        end
        if #hulls == 0 then self:_Destroy(questId); return end

        local area = self._areas[questId]
        if not area then
            area = MapQuestObjectiveArea("MUI_MapQuestArea_" .. questId, questId)
            self._areas[questId] = area
        end
        area:SetHulls(hulls, cont)
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
