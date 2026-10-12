-- BlobOutline: geometry of the quest objective areas the world map (filled)
-- and the minimap (outline) draw. An area is a set of closed rings: the
-- outlines of its parts and of the holes in them, each a flat run of
-- coordinates {x1, y1, x2, y2, ...}. A point is inside the area when it is
-- inside an odd number of rings. Works in any flat 2-D space: world yards,
-- canvas pixels, normalized map coordinates.

object "BlobOutline" {

    -- Whether (x, y) is inside the area.
    Contains = function(self, rings, x, y)
        local inside = false
        for _, ring in ipairs(rings) do
            local n = #ring
            local px, py = ring[n - 1], ring[n]
            for i = 1, n, 2 do
                local qx, qy = ring[i], ring[i + 1]
                if (py > y) ~= (qy > y) and x < px + (y - py) * (qx - px) / (qy - py) then
                    inside = not inside
                end
                px, py = qx, qy
            end
        end
        return inside
    end;

    -- Distance from (x, y) to the nearest ring.
    EdgeDistance = function(self, rings, x, y)
        local best = math.huge
        for _, ring in ipairs(rings) do
            local n = #ring
            local px, py = ring[n - 1], ring[n]
            for i = 1, n, 2 do
                local qx, qy = ring[i], ring[i + 1]
                local ex, ey = qx - px, qy - py
                local len2 = ex * ex + ey * ey
                local t = 0
                if len2 > 0 then
                    t = math.max(0, math.min(1, ((x - px) * ex + (y - py) * ey) / len2))
                end
                local dx, dy = px + t * ex - x, py + t * ey - y
                local d2 = dx * dx + dy * dy
                if d2 < best then best = d2 end
                px, py = qx, qy
            end
        end
        return math.sqrt(best)
    end;

    -- Whether the area lies to the left of ring `k` when walking it in order
    -- (with y pointing up). Tried with a point just left of the middle of the
    -- ring's longest edge.
    AreaOnLeft = function(self, rings, k)
        local ring = rings[k]
        local n = #ring
        local longest, ax, ay, bx, by = -1, 0, 0, 0, 0
        local px, py = ring[n - 1], ring[n]
        for i = 1, n, 2 do
            local qx, qy = ring[i], ring[i + 1]
            local len2 = (qx - px) * (qx - px) + (qy - py) * (qy - py)
            if len2 > longest then
                longest, ax, ay, bx, by = len2, px, py, qx, qy
            end
            px, py = qx, qy
        end
        local dx, dy = bx - ax, by - ay
        return self:Contains(rings, (ax + bx) / 2 - dy * 0.001, (ay + by) / 2 + dx * 0.001)
    end;

    -- The box round the rings: minX, minY, maxX, maxY.
    Bounds = function(self, rings)
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, ring in ipairs(rings) do
            for i = 1, #ring, 2 do
                local x, y = ring[i], ring[i + 1]
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y < minY then minY = y end
                if y > maxY then maxY = y end
            end
        end
        return minX, minY, maxX, maxY
    end;
}
