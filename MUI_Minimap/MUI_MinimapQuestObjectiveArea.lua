-- MUI_MinimapQuestObjectiveArea: glowing convex-hull overlays on the
-- minimap, rendered from precomputed hulls. This class is a pure RENDERER:
-- it doesn't own the clustering logic — see QuestObjectiveCluster
-- (MUI_QuestHelper/MUI_QuestObjectiveCluster.lua) for how a quest's spawn
-- points become hulls. A single cluster object is authored once per quest
-- in world yards and can be consumed by multiple renderers (minimap here,
-- future world-map overlay, edge-arrow aiming).
--
-- Per frame, Refresh() projects every supplied hull through the player
-- position + minimap rotation + zoom, clips each edge to the minimap radius
-- (minus optional edge padding), and updates a pool of Lines.
--
-- Use:
--   local area = MinimapQuestObjectiveArea()
--   area:SetHulls({
--       { {wx, wy}, {wx, wy}, ... },   -- CCW hull 1
--       { {wx, wy}, {wx, wy}, ... },   -- CCW hull 2
--       ...
--   }, continentId)

-- Glow profile: outward halo + inward core thickness, in minimap px.

local GLOW_THICK = 3
local CORE_THICK = 1

-- Hull edges are clipped to (minimap radius − this) so the halo's
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

        -- Hulls in UnitPosition-space world yards, fed externally.
        -- self._hulls[i] = { {wx, wy}, {wx, wy}, ... } (CCW vertices)
        self._hulls       = {}
        self._worldCont   = nil
        self._edgePadding = DEFAULT_EDGE_PADDING_PX

        -- Line pool, grown on demand across all hulls. Per frame,
        -- _DrawEdge(idx, ...) bumps idx for every drawn edge and unused
        -- pool slots beyond the final idx are hidden.
        self._halos = {}
        self._cores = {}

        -- Optional per-hull centre-icon overlay (pure art — no mouse, no
        -- tooltip; hover resolution still runs off the hulls). Populated
        -- via SetCenterIcons; toggled via SetCentersVisible so the pin
        -- manager can show them only for the focused quest.
        self._centerTexs    = {}
        self._centers       = nil
        self._centerType    = nil
        self._centerSize    = 14
        self._centersVisible = false

        MUI_MinimapPinTicker:Register(self)
    end;

    -- hulls: list of CCW hulls in world yards (e.g. from a
    -- QuestObjectiveCluster:GetClusters() spread).
    -- continentId: numeric continent this area belongs to; the overlay
    -- hides when the player is on a different continent.
    SetHulls = function(self, hulls, continentId)
        self._hulls     = hulls or {}
        self._worldCont = continentId
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
    -- each `centers[i] = {wx, wy}` (world yards, same convention as hulls)
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

    -- Ticker callback. Re-projects every hull → minimap pixels, clips
    -- edges to the minimap circle, updates Line endpoints.
    Refresh = function(self)
        if not self._hulls or #self._hulls == 0 or not self._worldCont then
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
        local cosF, sinF
        if rotate then
            local facing = GetPlayerFacing() or 0
            cosF, sinF = math.cos(facing), math.sin(facing)
        end

        local drawn = 0
        local projectedHulls = {}
        for hIdx, hull in ipairs(self._hulls) do
            -- Project hull vertices to minimap pixel space. MinimapPin axis
            -- convention: UnitPosition returns (Y, X) where Y is N-S (+north)
            -- and X is E-W (+west).
            local proj = {}
            for i, v in ipairs(hull) do
                local east  = playerX - v[2]
                local north = v[1]    - playerY
                if rotate then
                    east, north = east * cosF + north * sinF, -east * sinF + north * cosF
                end
                proj[i] = { east * scale, north * scale }
            end
            projectedHulls[hIdx] = proj

            for i = 1, #proj do
                local a = proj[i]
                local b = proj[(i % #proj) + 1]
                local cax, cay, cbx, cby =
                    _clipSegmentToCircle(a[1], a[2], b[1], b[2], clipRadiusPx)
                if cax then
                    drawn = drawn + 1
                    self:_DrawEdge(drawn, cax, cay, cbx, cby)
                end
            end
        end
        -- Cache the (unclipped) projected hulls so IsMouseOver can run
        -- point-in-polygon without re-projecting.
        self._projectedHulls = projectedHulls

        for i = drawn + 1, #self._halos do
            self._halos[i]:Hide()
            self._cores[i]:Hide()
        end

        -- Centre icons: project each centre to minimap pixel space using
        -- the same axes as hull projection, then place/show the pooled
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
        self._projectedHulls = nil
    end;

    -- True if the cursor is inside ANY projected hull of this area. Uses
    -- the CCW point-in-convex test against the last projected hulls cached
    -- by Refresh(). Cheap: O(Σ hullSize) per call.
    IsMouseOver = function(self)
        local hulls = self._projectedHulls
        if not hulls or #hulls == 0 then return false end
        if not MUI_Minimap:IsMouseOver() then return false end

        local scale = MUI_Minimap:GetEffectiveScale()
        local mx, my = GetCursorPosition()
        mx, my = mx / scale, my / scale
        local cx, cy = MUI_Minimap:GetCenter()
        if not cx then return false end
        local px, py = mx - cx, my - cy

        for _, hull in ipairs(hulls) do
            local n = #hull
            local inside = n >= 3
            for i = 1, n do
                local a = hull[i]
                local b = hull[(i % n) + 1]
                -- CCW test: interior keeps cross(b-a, p-a) >= 0 on every edge.
                if ((b[1] - a[1]) * (py - a[2]) - (b[2] - a[2]) * (px - a[1])) < 0 then
                    inside = false
                    break
                end
            end
            if inside then return true end
        end
        return false
    end;

    -- Lazily allocate and reuse pool lines. Endpoints are anchored to
    -- Minimap's CENTER so the pixel offsets we pass are minimap-local.
    _DrawEdge = function(self, index, ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then return end
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
                CreateColor(0.70, 0.90, 1.00, 1.00))    -- hull edge: near-white
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
                CreateColor(0.80, 1.00, 1.00, 1.00),    -- hull edge: near-white
                CreateColor(0.35, 0.40, 1.00, 0.00))    -- inward: transparent
            self._cores[index] = core
        end
        core:SetStartPoint("CENTER", Minimap, ax - cx, ay - cy)
        core:SetEndPoint("CENTER", Minimap, bx - cx, by - cy)
        core:Show()
    end;
}
