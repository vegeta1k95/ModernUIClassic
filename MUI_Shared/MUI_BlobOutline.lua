-- BlobOutline: turns a convex hull into the smooth closed outline the quest
-- objective areas are drawn with, on the world map (filled) and the minimap
-- (outline). Works in any flat 2-D space: canvas pixels, world yards.

local ARC_STEP       = math.pi / 8   -- angle between points on a padded corner's arc
local BLOB_RAYS      = 32            -- directions the hull's radius is measured along
local BLOB_SMOOTHING = 4             -- smoothing passes over those radii
local BLOB_POINTS    = 48            -- outline vertices per blob

-- A convex hull given as points {x, y}, grown outward by `pad`: its
-- edges moved out and joined by circular arcs around the vertices. Every
-- hull point ends up `pad` or more inside; a segment becomes a
-- capsule and a lone point a circle.
local function _PadHull(pts, pad)
    -- Drop repeated points (a zero-length edge has no direction).
    local ring = {}
    for _, p in ipairs(pts) do
        local last = ring[#ring]
        if not last or math.abs(p[1] - last[1]) + math.abs(p[2] - last[2]) > 0.01 then
            ring[#ring + 1] = p
        end
    end
    local first, last = ring[1], ring[#ring]
    if #ring > 1 and math.abs(first[1] - last[1]) + math.abs(first[2] - last[2]) <= 0.01 then
        ring[#ring] = nil
    end
    local n = #ring

    -- Counter-clockwise, so (dy, -dx) is an edge's outward normal.
    local area = 0
    for i, p in ipairs(ring) do
        local q = ring[i % n + 1]
        area = area + p[1] * q[2] - q[1] * p[2]
    end
    if area < 0 then
        for i = 1, math.floor(n / 2) do
            ring[i], ring[n + 1 - i] = ring[n + 1 - i], ring[i]
        end
    end

    local out = {}
    local function arc(p, from, sweep)
        local steps = math.ceil(sweep / ARC_STEP)
        for s = 0, steps do
            local a = from + (steps > 0 and sweep * s / steps or 0)
            out[#out + 1] = { p[1] + pad * math.cos(a), p[2] + pad * math.sin(a) }
        end
    end
    if n == 1 then
        arc(ring[1], 0, 2 * math.pi - ARC_STEP)
    else
        for i = 1, n do
            local prev, cur, nxt = ring[(i - 2) % n + 1], ring[i], ring[i % n + 1]
            local from = math.atan2(prev[1] - cur[1], cur[2] - prev[2])
            local to   = math.atan2(cur[1] - nxt[1], nxt[2] - cur[2])
            arc(cur, from, (to - from) % (2 * math.pi))
        end
    end
    return out
end

-- Distance from the origin along the unit direction (ux, uy) to the
-- boundary of the polygon `ring` (which contains the origin).
local function _RayRadius(ring, ux, uy)
    local n, far = #ring, 0
    for i = 1, n do
        local a, b = ring[i], ring[i % n + 1]
        local ex, ey = b[1] - a[1], b[2] - a[2]
        local denom = ux * ey - uy * ex
        if math.abs(denom) > 1e-9 then
            local t = (a[1] * ey - a[2] * ex) / denom
            local w = (a[1] * uy - a[2] * ux) / denom
            if t > far and w >= 0 and w <= 1 then far = t end
        end
    end
    return far
end

-- Periodic Catmull-Rom interpolation of the ray radii at turn fraction u.
local function _RadiusAt(r, u)
    local n = #r
    local s = (u % 1) * n
    local k = math.floor(s)
    local t = s - k
    local p0, p1 = r[(k - 1) % n + 1], r[k % n + 1]
    local p2, p3 = r[(k + 1) % n + 1], r[(k + 2) % n + 1]
    return 0.5 * (2 * p1 + (p2 - p0) * t
        + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
        + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)
end

object "BlobOutline" {

    -- Outline of the convex hull `pts` ({x, y} points), kept at least `pad`
    -- outside every hull point. The padded hull (_PadHull) is squashed along
    -- its long axis until it is about as wide as it is long; there its radius
    -- around the centre is measured along BLOB_RAYS directions, smoothed,
    -- interpolated into a closed curve and scaled out to contain the padded
    -- hull; then the curve is stretched back. Working in the squashed space
    -- is what keeps a long, thin hull smooth. The curve runs counter-
    -- clockwise and is star-shaped around the centre, so a triangle fan from
    -- there fills it exactly. Returns points, cx, cy.
    Round = function(self, pts, pad)
        local padded = _PadHull(pts, pad)
        local n = #padded

        -- Centre, principal axis and spread along / across it.
        local cx, cy = 0, 0
        for _, p in ipairs(padded) do cx, cy = cx + p[1], cy + p[2] end
        cx, cy = cx / n, cy / n
        local sxx, syy, sxy = 0, 0, 0
        for _, p in ipairs(padded) do
            local dx, dy = p[1] - cx, p[2] - cy
            sxx, syy, sxy = sxx + dx * dx, syy + dy * dy, sxy + dx * dy
        end
        local phi = 0.5 * math.atan2(2 * sxy, sxx - syy)
        local cosP, sinP = math.cos(phi), math.sin(phi)
        local mid = (sxx + syy) / 2
        local dev = math.sqrt(((sxx - syy) / 2) ^ 2 + sxy * sxy)
        local along  = math.sqrt((mid + dev) / n)
        local across = math.sqrt(math.max(mid - dev, 0) / n)

        local flat = {}
        for i, p in ipairs(padded) do
            local dx, dy = p[1] - cx, p[2] - cy
            flat[i] = { (dx * cosP + dy * sinP) / along, (dy * cosP - dx * sinP) / across }
        end

        local r = {}
        for k = 1, BLOB_RAYS do
            local a = (k - 1) / BLOB_RAYS * 2 * math.pi
            r[k] = _RayRadius(flat, math.cos(a), math.sin(a))
        end
        for _ = 1, BLOB_SMOOTHING do
            local s = {}
            for k = 1, BLOB_RAYS do
                s[k] = 0.25 * r[(k - 2) % BLOB_RAYS + 1] + 0.5 * r[k] + 0.25 * r[k % BLOB_RAYS + 1]
            end
            r = s
        end

        local scale = 1
        for _, q in ipairs(flat) do
            local dist = math.sqrt(q[1] * q[1] + q[2] * q[2])
            local reach = _RadiusAt(r, math.atan2(q[2], q[1]) / (2 * math.pi))
            scale = math.max(scale, dist / reach)
        end

        local out = {}
        for i = 1, BLOB_POINTS do
            local u = (i - 1) / BLOB_POINTS
            local a, reach = u * 2 * math.pi, _RadiusAt(r, u) * scale
            local fx, fy = reach * math.cos(a) * along, reach * math.sin(a) * across
            out[i] = { cx + fx * cosP - fy * sinP, cy + fx * sinP + fy * cosP }
        end
        return out, cx, cy
    end;
}
