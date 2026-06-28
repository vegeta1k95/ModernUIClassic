-- ComboBar: Retail-style combo point bar (rogue / druid feral).
--
-- Usage:
--   local bar = ComboBar(parent, "MyBar", MUI_AtlasRegistry.ComboDruid, 5)
--   bar:SetCount(3)
--
-- Atlas regions are all optional and gracefully absent — the widget only creates /
-- animates textures for regions that actually exist. Druid uses Deplete + Smoke;
-- rogue uses FX instead. Common regions: BGDis, BGActive, BGShadow, Icon, RingGlow, Slash.

local POINT_SIZE     = 28
local POINT_SPACING  = 5
-- Flipbook config carries displayed size + atlas cell grid + anchor offset for the slash.
-- sx/sy are center offsets of the slash texture relative to the point (per-class art differs).
local DEFAULT_FLIPBOOK = { cols = 8, rows = 3, frames = 20, duration = 1.0, w = 26, h = 41, sx = 1, sy = 0 }

local function setAlpha(tex, a) if tex then tex:SetAlpha(a) end end

class "ComboBar" : extends "Frame" {
    __init = function(self, parent, name, atlas, maxPoints, flipbook)
        Frame.__init(self, "Frame", parent, name)
        self._atlas = atlas
        self._maxPoints = maxPoints or 5
        self._flipbook = flipbook or DEFAULT_FLIPBOOK
        self._points = {}

        local width = self._maxPoints * POINT_SIZE + (self._maxPoints - 1) * POINT_SPACING
        self:SetSize(width, POINT_SIZE)

        for i = 1, self._maxPoints do
            self._points[i] = self:_CreatePoint(i)
        end
    end;

    _CreatePoint = function(self, idx)
        local pt = Frame("Frame", self)
        pt:SetSize(POINT_SIZE, POINT_SIZE)
        if idx == 1 then
            pt:AlignParentLeft()
        else
            pt:RightOf(self._points[idx - 1], POINT_SPACING)
        end

        -- Only create a texture if the atlas actually has the region.
        local function add(key, layer, w, h, offX, offY)
            if not self._atlas:GetRegion(key) then return nil end
            local tex = Texture(pt, nil, layer)
            tex:SetAtlas(self._atlas, key, true)
            tex:SetSize(w, h)
            tex:CenterInParent(offX or 0, offY or 0)
            return tex
        end

        pt.shadow   = add("BGShadow", "BACKGROUND", POINT_SIZE * 1.25, POINT_SIZE * 1.25, 0, -2.5)
        pt.bgDis    = add("BGDis",    "BORDER",     POINT_SIZE,         POINT_SIZE)
        pt.bgActive = add("BGActive", "BORDER",     POINT_SIZE,         POINT_SIZE)
        pt.fx       = add("FX",       "ARTWORK",    POINT_SIZE * 0.85,  POINT_SIZE * 0.85)
        pt.icon     = add("Icon",     "ARTWORK",    POINT_SIZE * 0.7,   POINT_SIZE * 0.7)
        pt.ringGlow = add("RingGlow", "OVERLAY",    POINT_SIZE * 1.15,  POINT_SIZE * 1.15)
        pt.slash    = add("Slash",    "OVERLAY",    self._flipbook.w,    self._flipbook.h, self._flipbook.sx or 0, self._flipbook.sy or 0)
        pt.deplete  = add("Deplete",  "OVERLAY",    POINT_SIZE * 0.75,  POINT_SIZE * 0.75)
        pt.smoke    = add("Smoke",    "OVERLAY",    POINT_SIZE * 0.7,   POINT_SIZE * 1.6, 0, 15)

        setAlpha(pt.bgActive, 0)
        setAlpha(pt.fx,       0)
        setAlpha(pt.icon,     0)
        setAlpha(pt.ringGlow, 0)
        setAlpha(pt.slash,    0)
        setAlpha(pt.deplete,  0)
        setAlpha(pt.smoke,    0)

        pt.active = false
        pt._animElapsed = 0
        return pt
    end;

    -- inactive → active: flipbook slash (if present) + bg swap + icon/fx fade + ring glow.
    _PlayActivate = function(self, pt)
        local region = self._atlas:GetRegion("Slash")
        local fb = self._flipbook
        local frameU, frameV
        if region then
            frameU = (region.right - region.left) / fb.cols
            frameV = (region.bottom - region.top) / fb.rows
        end

        pt._animElapsed = 0
        setAlpha(pt.slash, region and 1 or 0)
        setAlpha(pt.ringGlow, 1)

        pt:SetScript("OnUpdate", function(_, delta)
            pt._animElapsed = pt._animElapsed + delta
            local t = pt._animElapsed / fb.duration

            if t >= 1 then
                setAlpha(pt.slash, 0)
                setAlpha(pt.ringGlow, 0)
                pt:SetScript("OnUpdate", nil)
                return
            end

            if region then
                local frame = math.floor(t * fb.frames)
                if frame >= fb.frames then frame = fb.frames - 1 end
                local col = frame % fb.cols
                local row = math.floor(frame / fb.cols)
                local l = region.left + col * frameU
                local r = l + frameU
                local tt = region.top + row * frameV
                local b  = tt + frameV
                pt.slash:SetTexCoord(l, r, tt, b)
            end

            local cross = math.min(1, t / 0.5)
            setAlpha(pt.icon, cross)
            setAlpha(pt.fx, cross)
            setAlpha(pt.bgActive, cross)
            setAlpha(pt.bgDis, 1 - cross)

            if t > 0.3 then
                setAlpha(pt.ringGlow, math.max(0, 1 - (t - 0.3) / 0.5))
            end
        end)
    end;

    -- Snap to inactive (no animation).
    _SetInactive = function(self, pt)
        pt:SetScript("OnUpdate", nil)
        setAlpha(pt.bgDis, 1)
        setAlpha(pt.bgActive, 0)
        setAlpha(pt.icon, 0)
        setAlpha(pt.fx, 0)
        setAlpha(pt.ringGlow, 0)
        setAlpha(pt.slash, 0)
        setAlpha(pt.deplete, 0)
        setAlpha(pt.smoke, 0)
    end;

    -- active → inactive: ring glow pulse, bg cross-fade, icon/fx fade, deplete flash, smoke.
    _PlayDeactivate = function(self, pt)
        pt._animElapsed = 0
        setAlpha(pt.bgActive, 1)
        setAlpha(pt.bgDis, 0)
        setAlpha(pt.icon, 1)
        setAlpha(pt.fx, 1)
        setAlpha(pt.slash, 0)

        local DURATION = 0.6
        pt:SetScript("OnUpdate", function(_, delta)
            pt._animElapsed = pt._animElapsed + delta
            local t = pt._animElapsed / DURATION

            if t >= 1 then
                self:_SetInactive(pt)
                return
            end

            local iconFade = math.max(0, 1 - math.min(1, t / 0.3))
            setAlpha(pt.icon, iconFade)
            setAlpha(pt.fx, iconFade)

            local bgCross = math.min(1, t / 0.5)
            setAlpha(pt.bgActive, math.max(0, 1 - bgCross))
            setAlpha(pt.bgDis, bgCross)

            if t < 0.3 then
                setAlpha(pt.ringGlow, t / 0.3)
            elseif t < 0.7 then
                setAlpha(pt.ringGlow, 1)
            else
                setAlpha(pt.ringGlow, math.max(0, 1 - (t - 0.7) / 0.3))
            end

            if t < 0.2 then
                setAlpha(pt.deplete, t / 0.2)
            elseif t < 0.45 then
                setAlpha(pt.deplete, math.max(0, 1 - (t - 0.2) / 0.25))
            end

            if t < 0.5 then
                setAlpha(pt.smoke, t / 0.5)
            else
                setAlpha(pt.smoke, math.max(0, 1 - (t - 0.5) / 0.5))
            end
        end)
    end;

    SetCount = function(self, count)
        count = math.max(0, math.min(count or 0, self._maxPoints))
        for i = 1, self._maxPoints do
            local pt = self._points[i]
            local shouldBeActive = (i <= count)
            if shouldBeActive and not pt.active then
                pt.active = true
                self:_PlayActivate(pt)
            elseif (not shouldBeActive) and pt.active then
                pt.active = false
                self:_PlayDeactivate(pt)
            end
        end
    end;
}
