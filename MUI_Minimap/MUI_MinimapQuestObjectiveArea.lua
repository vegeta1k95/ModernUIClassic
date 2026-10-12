-- MUI_MinimapQuestObjectiveArea: glowing outlines of quest objective areas
-- on the minimap, rendered from precomputed shapes. This class is a pure
-- RENDERER: it doesn't own the clustering logic — see QuestObjectiveCluster
-- (MUI_QuestHelper/MUI_QuestObjectiveCluster.lua) for how a quest's spawn
-- points become shapes. A single cluster object is authored once per quest
-- in world yards and consumed by several renderers (minimap here, the
-- world-map overlay, edge-arrow aiming).
--
-- Per frame, Refresh() projects the rings of every supplied shape that are
-- in view through the player position + minimap rotation + zoom, clips each
-- edge to the minimap radius (minus optional edge padding), and updates a
-- pool of Lines.
--
-- Use:
--   local area = MinimapQuestObjectiveArea()
--   area:SetShapes({
--       { rings = { {wx, wy, wx, wy, ...}, ... }, box = {...} },
--       ...
--   }, continentId)

-- Glow profile: outward halo + inward core thickness, in minimap px.

local GLOW_THICK = 3
local CORE_THICK = 1

-- A ring is drawn in runs of this many edges; a run out of view is skipped
-- whole.
local RUN_EDGES = 16

-- Ring edges are clipped to (minimap radius − this) so the halo's
-- perpendicular overhang at the termination point doesn't poke past the
-- minimap border. Tunable per-instance via :SetEdgePadding(px).
local DEFAULT_EDGE_PADDING_PX = 3.5

-- Each new area takes the next frame level above Minimap's. MinimapPin
-- and MinimapEdgeArrow sit at a fixed high level (see MUI_MinimapPin.lua
-- PIN_FRAME_LEVEL), so pins always draw on top of every area overlay and
-- later-created areas draw on top of earlier ones.
local _areaFrameLevel = 0

-- === Segment ↔ circle clipping ===
-- Solves |A + t·(B-A)|² = R² for t, clamps to [0, 1], returns the interior
-- chord or nil if the segment is fully outside the circle.
local function _clipSegmentToCircle(ax, ay, bx, by, R)
    local dx, dy = bx - ax, by - ay
    local A = dx * dx + dy * dy
    if A < 1e-12 then
        if ax * ax + ay * ay <= R * R then return ax, ay, bx, by end
        return nil
    end
    local B = ax * dx + ay * dy
    local C = ax * ax + ay * ay - R * R
    local disc = B * B - A * C
    if disc < 0 then
        if C < 0 then return ax, ay, bx, by end
        return nil
    end
    local sq = math.sqrt(disc)
    local t1 = (-B - sq) / A
    local t2 = (-B + sq) / A
    local ts = math.max(t1, 0)
    local te = math.min(t2, 1)
    if ts >= te then return nil end
    return ax + ts * dx, ay + ts * dy,
           ax + te * dx, ay + te * dy
end

class "MinimapQuestObjectiveArea" : extends "Frame" {
    __init = function(self, name)
        local mm = Frame(Minimap)
        Frame.__init(self, "Frame", mm, name)
        self:SetAllPoints(mm)
        self:SetFrameStrata("MEDIUM")
        -- Sit N levels above Minimap, where N bumps per instance so later
        -- areas draw over earlier ones. Absolute level = 1 hid everything
        -- behind other MEDIUM frames overlaying the minimap; keep ourselves
        -- above Minimap's own frame level to stay visible.
        _areaFrameLevel = _areaFrameLevel + 1
        self:SetFrameLevel(mm:GetFrameLevel() + _areaFrameLevel)

        -- Shapes in UnitPosition-space world yards, fed externally, and
        -- their rings cut into runs (see SetShapes).
        self._shapes      = {}
        self._runs        = {}
        self._worldCont   = nil
        self._edgePadding = DEFAULT_EDGE_PADDING_PX

        -- How the last Refresh looked at the world, for the hover test:
        -- player position, px per yard and the minimap's rotation.
        self._view   = {}
        self._inView = false

        -- Line pool, grown on demand across all shapes. Per frame every
        -- drawn edge takes the next pair and the pairs beyond the last one
        -- are hidden.
        self._halos = {}
        self._cores = {}

        -- Optional centre-icon overlay (pure art — no mouse, no tooltip;
        -- hover resolution still runs off the shapes). Populated
        -- via SetCenterIcons; toggled via SetCentersVisible so the pin
        -- manager can show them only for the focused quest.
        self._centerTexs    = {}
        self._centers       = nil
        self._centerType    = nil
        self._centerSize    = 14
        self._centersVisible = false

        MUI_MinimapPinTicker:Register(self)
    end;

    -- shapes: list of area shapes in world yards (e.g. the `shape` of each
    -- QuestObjectiveCluster:GetClusters() entry).
    -- continentId: numeric continent this area belongs to; the overlay
    -- hides when the player is on a different continent.
    SetShapes = function(self, shapes, continentId)
        self._shapes    = shapes or {}
        self._worldCont = continentId
        -- The outline is rigid in world space: cut every ring into runs of
        -- edges once here, each with the circle round it and the side the
        -- area is on, and only project the runs in view per frame.
        self._runs = {}
        for _, shape in ipairs(self._shapes) do
            for k, ring in ipairs(shape.rings) do
                local points   = #ring / 2
                local areaLeft = MUI_BlobOutline:AreaOnLeft(shape.rings, k)
                for first = 1, points, RUN_EDGES do
                    local edges = math.min(RUN_EDGES, points - first + 1)
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    for p = first, first + edges do
                        local i = ((p - 1) % points) * 2
                        minX, maxX = math.min(minX, ring[i + 1]), math.max(maxX, ring[i + 1])
                        minY, maxY = math.min(minY, ring[i + 2]), math.max(maxY, ring[i + 2])
                    end
                    self._runs[#self._runs + 1] = {
                        ring = ring, points = points, first = first, edges = edges,
                        areaLeft = areaLeft,
                        x = (minX + maxX) / 2, y = (minY + maxY) / 2,
                        radius = math.sqrt((maxX - minX) ^ 2 + (maxY - minY) ^ 2) / 2,
                    }
                end
            end
        end
    end;

    Destroy = function(self)
        MUI_MinimapPinTicker:Unregister(self)
        self:_HideAll()
        self:Hide()
    end;

    -- Dim the whole area to this alpha. Frame alpha cascades to the child
    -- halo/core Lines, so this dims the entire outline in one call.
    -- MinimapQuestPinManager sets 0.5 when the quest is tracked but
    -- unfocused, and 1.0 when focused or nothing is focused.
    SetDimFactor = function(self, factor)
        self._dimFactor = factor or 1
        self:SetAlpha(self._dimFactor)
    end;

    -- Minimap pixels to inset the circular clip by. Larger = edges end
    -- further inside the minimap border (keeps the halo's perpendicular
    -- overhang inside the circle at the termination point).
    SetEdgePadding = function(self, px)
        self._edgePadding = px or 0
    end;

    -- Attach a centre-icon overlay to this area. One texture is placed at
    -- each `centers[i] = {wx, wy}` (world yards, same convention as shapes)
    -- using the icon region keyed by `iconType` in MUI_MinimapPinIcons.
    -- Centres don't render until SetCentersVisible(true) — the pin manager
    -- uses that to show the icons only for the focused quest.
    SetCenterIcons = function(self, iconType, centers)
        self._centerType = iconType
        self._centers    = centers
        -- Reset texture contents: existing pool entries are reused but
        -- need their region rebound whenever the icon type changes.
        local spec = iconType and MUI_MinimapPinIcons and MUI_MinimapPinIcons[iconType]
        if spec then
            for _, t in ipairs(self._centerTexs) do
                t:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
            end
        end
    end;

    SetCentersVisible = function(self, visible)
        self._centersVisible = visible and true or false
        if not self._centersVisible then
            for _, t in ipairs(self._centerTexs) do t:Hide() end
        end
    end;

    -- Ticker callback. Re-projects the runs in view → minimap pixels, clips
    -- edges to the minimap circle, updates Line endpoints.
    Refresh = function(self)
        if #self._runs == 0 or not self._worldCont then
            self:_HideAll(); return
        end

        local playerY, playerX, _, playerCont = UnitPosition("player")
        if not playerX or not playerY then self:_HideAll(); return end
        if playerCont and self._worldCont and playerCont ~= self._worldCont then
            self:_HideAll(); return
        end

        local zoomYards    = MUI_MinimapPinTicker:YardsPerRadius()
        local fullRadiusPx = MUI_Minimap:GetWidth() * 0.5
        local clipRadiusPx = fullRadiusPx - (self._edgePadding or 0)
        if zoomYards <= 0 or fullRadiusPx <= 0 or clipRadiusPx <= 0 then
            self:_HideAll(); return
        end
        local scale = fullRadiusPx / zoomYards

        local rotate = GetCVar("rotateMinimap") == "1"
        local cosF, sinF = 1, 0
        if rotate then
            local facing = GetPlayerFacing() or 0
            cosF, sinF = math.cos(facing), math.sin(facing)
        end

        local view = self._view
        view.playerY, view.playerX, view.scale = playerY, playerX, scale
        view.rotate, view.cosF, view.sinF = rotate, cosF, sinF
        self._inView = true

        -- World yards → minimap pixel space. MinimapPin axis convention:
        -- UnitPosition returns (Y, X) where Y is N-S (+north) and X is E-W
        -- (+west). A run is in view when its circle reaches the minimap's.
        local drawn = 0
        for _, run in ipairs(self._runs) do
            local dx, dy = run.x - playerY, run.y - playerX
            local reach = zoomYards + run.radius
            if dx * dx + dy * dy <= reach * reach then
                local ring, points = run.ring, run.points
                local ax, ay
                for p = run.first, run.first + run.edges do
                    local i = ((p - 1) % points) * 2
                    local east  = playerX - ring[i + 2]
                    local north = ring[i + 1] - playerY
                    if rotate then
                        east, north = east * cosF + north * sinF, -east * sinF + north * cosF
                    end
                    local bx, by = east * scale, north * scale
                    if ax then
                        local cax, cay, cbx, cby =
                            _clipSegmentToCircle(ax, ay, bx, by, clipRadiusPx)
                        -- _DrawEdge glows to the right of the edge's direction:
                        -- away from the area.
                        if cax and not run.areaLeft then
                            cax, cay, cbx, cby = cbx, cby, cax, cay
                        end
                        if cax and self:_DrawEdge(drawn + 1, cax, cay, cbx, cby) then
                            drawn = drawn + 1
                        end
                    end
                    ax, ay = bx, by
                end
            end
        end

        for i = drawn + 1, #self._halos do
            self._halos[i]:Hide()
            self._cores[i]:Hide()
        end

        -- Centre icons: project each centre to minimap pixel space using
        -- the same axes as the rings, then place/show the pooled
        -- texture. Hidden wholesale when SetCentersVisible is off.
        if self._centersVisible and self._centers and self._centerType then
            local spec = MUI_MinimapPinIcons and MUI_MinimapPinIcons[self._centerType]
            local clipSq = clipRadiusPx * clipRadiusPx
            for i, c in ipairs(self._centers) do
                local east  = playerX - c[2]
                local north = c[1]    - playerY
                if rotate then
                    east, north = east * cosF + north * sinF, -east * sinF + north * cosF
                end
                local px, py = east * scale, north * scale
                local tex = self._centerTexs[i]
                if (px * px + py * py) <= clipSq then
                    if not tex then
                        tex = Texture(self, nil, "OVERLAY")
                        tex:SetDrawLayer("OVERLAY", 7)
                        tex:SetSize(self._centerSize, self._centerSize)
                        tex:SetSubpixelRendering(true)
                        if spec then
                            tex:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
                        end
                        self._centerTexs[i] = tex
                    end
                    tex:ClearAllPoints()
                    tex:SetPoint("CENTER", self, "CENTER", px, py)
                    tex:Show()
                elseif tex then
                    tex:Hide()
                end
            end
            for i = #self._centers + 1, #self._centerTexs do
                self._centerTexs[i]:Hide()
            end
        else
            for _, t in ipairs(self._centerTexs) do t:Hide() end
        end

        self:Show()
    end;

    _HideAll = function(self)
        for _, l in ipairs(self._halos) do l:Hide() end
        for _, l in ipairs(self._cores) do l:Hide() end
        for _, t in ipairs(self._centerTexs) do t:Hide() end
        self._inView = false
    end;

    -- True if the cursor is inside ANY shape of this area. What
    -- those shapes are for is kept for GetHoveredTargets.
    IsMouseOver = function(self)
        self._hoverKey, self._hoverObjectives, self._hoverItems = self:_HoveredTargets()
        return self._hoverKey ~= nil
    end;

    -- What the last IsMouseOver found under the cursor, nil when nothing:
    -- a key naming the targets of the shapes the cursor is inside, and those
    -- targets as two sets, objective lines (indices into the quest's
    -- leaderboard) and required source items. Shapes of different objectives
    -- overlap, so it can be several. A shape that names no target stands for
    -- the whole quest: the key is then "" and there are no sets.
    GetHoveredTargets = function(self)
        return self._hoverKey, self._hoverObjectives, self._hoverItems
    end;

    -- The cursor is taken back from minimap pixels to world yards, as the
    -- last Refresh() looked at the world, and tried against each shape there.
    _HoveredTargets = function(self)
        if not self._inView then return nil end
        if not MUI_Minimap:IsMouseOver() then return nil end

        local scale = MUI_Minimap:GetEffectiveScale()
        local mx, my = GetCursorPosition()
        mx, my = mx / scale, my / scale
        local cx, cy = MUI_Minimap:GetCenter()
        if not cx then return nil end
        local view = self._view
        local east, north = (mx - cx) / view.scale, (my - cy) / view.scale
        if view.rotate then
            east, north = east * view.cosF - north * view.sinF,
                          east * view.sinF + north * view.cosF
        end
        local wx, wy = view.playerY + north, view.playerX - east

        local key, objectives, items, whole
        for _, shape in ipairs(self._shapes) do
            local box = shape.box
            if wx >= box[1] and wx <= box[3] and wy >= box[2] and wy <= box[4]
                    and MUI_BlobOutline:Contains(shape.rings, wx, wy) then
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

    -- Lazily allocate and reuse pool lines. Endpoints are anchored to
    -- Minimap's CENTER so the pixel offsets we pass are minimap-local.
    -- Returns whether the edge was long enough to draw.
    _DrawEdge = function(self, index, ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then return false end
        local nx =  dy / len
        local ny = -dx / len
        local hx, hy = nx * GLOW_THICK * 0.5, ny * GLOW_THICK * 0.5
        local cx, cy = nx * CORE_THICK * 0.5, ny * CORE_THICK * 0.5

        local halo = self._halos[index]
        if not halo then
            halo = Line(self, nil, "ARTWORK")
            halo:SetSubpixelRendering(true)
            halo:SetColorTexture(1, 1, 1, 1)
            halo:SetThickness(GLOW_THICK)
            halo:SetGradient("VERTICAL",
                CreateColor(0.35, 0.40, 1.00, 0.00),    -- outer: transparent light-blue
                CreateColor(0.70, 0.90, 1.00, 1.00))    -- area edge: near-white
            self._halos[index] = halo
        end
        halo:SetStartPoint("CENTER", Minimap, ax + hx, ay + hy)
        halo:SetEndPoint("CENTER", Minimap, bx + hx, by + hy)
        halo:Show()

        local core = self._cores[index]
        if not core then
            core = Line(self, nil, "OVERLAY")
            core:SetSubpixelRendering(true)
            core:SetColorTexture(1, 1, 1, 1)
            core:SetThickness(CORE_THICK)
            core:SetGradient("VERTICAL",
                CreateColor(0.80, 1.00, 1.00, 1.00),    -- area edge: near-white
                CreateColor(0.35, 0.40, 1.00, 0.00))    -- inward: transparent
            self._cores[index] = core
        end
        core:SetStartPoint("CENTER", Minimap, ax - cx, ay - cy)
        core:SetEndPoint("CENTER", Minimap, bx - cx, by - cy)
        core:Show()
        return true
    end;
}
