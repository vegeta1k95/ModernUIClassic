-- FocusNavigation: kind-agnostic on-screen compass that points at the
-- currently-focused target. Replaces the quest-only QuestNavigation —
-- target picking moves to MUI_FocusManager:PickTarget so any focusable
-- kind (quest, flightmaster, …) drives this widget identically.
--
-- Two textures share navigation.tga:
--   body  rides the inner ellipse upright (no rotation).
--   arrow rides a slightly outer, non-uniformly scaled ellipse and
--         rotates so its tip points radially outward — i.e. at the
--         target direction.
--
-- Visibility: hidden when there is no focus, the focused kind has no
-- resolvable target on the player's continent (and no transport
-- bridging), or player/target positions are unavailable.

local NAV_TEX = "Interface\\AddOns\\ModernUI\\assets\\textures\\navigation.tga"

local YARDS_TO_METERS = 0.9144

local OUTER_SCALE_X = 1.07
local OUTER_SCALE_Y = 1.17

-- Exponential smoothing factor applied to the displayed relative angle.
-- Every frame we move SMOOTH_ALPHA of the way from the previous shown
-- value to the freshly computed target bearing. At close range, small
-- UnitPosition jitter yields huge per-frame angle swings — this filter
-- absorbs them with almost no perceptible lag at 60 fps (1 - 0.75^60 ≈
-- full settle in ~1/4 s).
local SMOOTH_ALPHA = 0.25

-- Total arc (radians), centred on the north pole of the ellipse, inside
-- which the distance label fades in. Alpha ramps linearly from 0 at the
-- arc boundary to 1 exactly at north.
local DISTANCE_FADEIN_ANGLE = math.pi * 1.5

-- Range (metres) below which the whole compass fades out for non-hull
-- targets — 1 at this distance, 0 at the target.
local PROXIMITY_FADEOUT_METERS = 7

-- Depth (metres) past the hull boundary, toward the centroid, over which
-- the compass fades from 1 (on boundary) to 0. Used for hull-bearing
-- targets (cluster centroids) where a scalar radius misrepresents the
-- often-elongated cluster shape.
local HULL_FADE_DEPTH_METERS = 5

class "FocusNavigation" : extends "Frame" {
    __init = function(self, name)
        Frame.__init(self, "Frame", nil, name)
        self:CenterInParent(0, 0)
        self:SetFrameStrata("LOW")
        self:_SizeToScreen()

        self.body = Texture(self, nil, "OVERLAY")
        self.body:SetTextureRegion(NAV_TEX, 64, 64, 29, 0, 23, 35)
        self.body:SetSize(23 * 0.9, 35 * 0.9)
        self.body:SetSubpixelRendering(true)
        self.body:Hide()

        self.arrow = Texture(self, nil, "OVERLAY")
        self.arrow:SetTextureRegion(NAV_TEX, 64, 64, 2, 37, 20, 16)
        self.arrow:SetSize(20 * 0.9, 16 * 0.9)
        self.arrow:SetSubpixelRendering(true)
        self.arrow:Hide()

        self.distLabel = FontString(self, nil, "OVERLAY")
        self.distLabel:SetFont(MUI.FONT, 11)
        self.distLabel:SetTextColor(1, 0.82, 0, 1)
        self.distLabel:Below(self.body, 7)
        self.distLabel:SetShadowOffset(1, -1)
        self.distLabel:Hide()

        -- Frame itself stays shown so OnUpdate keeps firing even when
        -- there's no target; only the textures toggle with Refresh.
        self:SetScript("OnUpdate", function() self:Refresh() end)
    end;

    _HideAll = function(self)
        self.body:Hide()
        self.arrow:Hide()
        self.distLabel:Hide()
        self._smoothedRel = nil
    end;

    -- Inner-ellipse axes: 1/4 screen width × 1/6 screen height. Recomputed
    -- on demand so /reload picks up display-size / UI-scale changes.
    _SizeToScreen = function(self)
        self._rx = MUI_Root:GetWidth()  / 4
        self._ry = MUI_Root:GetHeight() / 6
        self:SetSize(2 * self._rx, 2 * self._ry)
    end;

    Refresh = function(self)
        local target = MUI_FocusManager:PickTarget()
        if not target then self:_HideAll(); return end

        local tx, ty = target.wx, target.wy
        local playerY, playerX = target.playerY, target.playerX

        -- World delta to target. UnitPosition / our stored points share
        -- the same convention: index 1 = N-S (+north), index 2 = E-W
        -- (+west). Same east/north math as MinimapPin.
        local east  = playerX - ty
        local north = tx - playerY
        local distSq = east * east + north * north
        if distSq < 1e-6 then self:_HideAll(); return end

        -- Target direction in WoW facing convention (0=N, π/2=W, CCW+).
        local worldAngle = -math.atan2(east, north)
        local cameraYaw  = GetPlayerFacing() or 0
        local rawRel     = worldAngle - cameraYaw

        -- Exponential smoothing with angle-wrap unwinding.
        local prev = self._smoothedRel
        local rel
        if prev then
            local diff = rawRel - prev
            while diff >  math.pi do diff = diff - 2 * math.pi end
            while diff < -math.pi do diff = diff + 2 * math.pi end
            rel = prev + diff * SMOOTH_ALPHA
        else
            rel = rawRel
        end
        self._smoothedRel = rel

        -- Screen ellipse uses math θ (CCW from +x). Target ahead
        -- (rel = 0) → top (θ = π/2); target behind → bottom.
        local theta = math.pi / 2 + rel
        local cosT, sinT = math.cos(theta), math.sin(theta)

        self.body:ClearAllPoints()
        self.body:CenterInParent(self._rx * cosT, self._ry * sinT)
        self.body:Show()

        self.arrow:ClearAllPoints()
        self.arrow:CenterInParent(
            self._rx * OUTER_SCALE_X * cosT,
            self._ry * OUTER_SCALE_Y * sinT)
        self.arrow:SetRotation(rel)
        self.arrow:Show()

        local meters = math.sqrt(distSq) * YARDS_TO_METERS
        self.distLabel:SetText(string.format("%d m", math.floor(meters + 0.5)))
        local angleFromNorth = math.acos(sinT)
        local halfArc        = DISTANCE_FADEIN_ANGLE * 0.5
        local labelAlpha     = 0
        if angleFromNorth < halfArc then
            labelAlpha = 1 - angleFromNorth / halfArc
        end
        self.distLabel:SetAlpha(labelAlpha)
        self.distLabel:Show()

        -- Proximity fade: hull-ray for cluster-centroid targets (non-nil
        -- hull on the candidate); fixed-meter fallback otherwise.
        local proximityAlpha = 1
        if target.hull then
            proximityAlpha = self:_HullFadeAlpha(tx, ty, target.hull, playerY, playerX)
        elseif meters < PROXIMITY_FADEOUT_METERS then
            proximityAlpha = meters / PROXIMITY_FADEOUT_METERS
        end
        self:SetAlpha(math.min(proximityAlpha, self:_CursorFadeAlpha()))
    end;

    -- Fade multiplier for hull-bearing targets: 1 outside the hull and on
    -- the boundary, ramps to 0 once the player is HULL_FADE_DEPTH_METERS
    -- past the boundary along the centroid→player direction. Cast the ray
    -- centroid + s·(player − centroid) against every CCW edge; smallest
    -- positive s where the ray line crosses an edge is where the ray
    -- exits the hull (s=1 means player is on boundary; s>1 means player
    -- is that multiple of |player−centroid| away from boundary, i.e.
    -- inside).
    _HullFadeAlpha = function(self, cWx, cWy, hull, playerY, playerX)
        if not hull or #hull < 3 then return 1 end

        local dx, dy = playerY - cWx, playerX - cWy
        local playerDistSq = dx * dx + dy * dy
        if playerDistSq < 1e-6 then return 0 end

        local sExit = math.huge
        local n = #hull
        for i = 1, n do
            local a = hull[i]
            local b = hull[(i % n) + 1]
            local ex = b[1] - a[1]
            local ey = b[2] - a[2]
            local denom = ex * dy - ey * dx
            if denom > 1e-12 or denom < -1e-12 then
                local s = (ey * (cWx - a[1]) - ex * (cWy - a[2])) / denom
                if s > 0 and s < sExit then sExit = s end
            end
        end
        if sExit == math.huge or sExit <= 1 then return 1 end

        -- Player is inside. Depth in yards past the boundary toward centroid.
        local depthYards = (sExit - 1) * math.sqrt(playerDistSq)
        local fadeYards  = HULL_FADE_DEPTH_METERS / YARDS_TO_METERS
        if depthYards >= fadeYards then return 0 end
        return 1 - depthYards / fadeYards
    end;

    -- Fade the whole frame toward transparent when the cursor is over the
    -- body texture so it doesn't obscure clickable world UI underneath.
    _CursorFadeAlpha = function(self)
        local bx, by = self.body:GetCenter()
        local cx, cy = GetCursorPosition()
        if not (bx and cx) then return 1 end
        local scale = self.body:GetEffectiveScale()
        local dx = cx / scale - bx
        local dy = cy / scale - by
        local hx = self.body:GetWidth()  * 1.3
        local hy = self.body:GetHeight() * 1.3
        local nx, ny = dx / hx, dy / hy
        local nd = math.sqrt(nx * nx + ny * ny)
        if nd > 1 then nd = 1 end
        return nd
    end;
}
