-- FocusedTargetArrow: kind-agnostic chevron clamped to the minimap border
-- that points at the currently-focused target. Replaces the quest-only
-- MinimapFocusedQuestArrow — its 3-tier centroid/stray/finisher walk and
-- cross-continent transport reroute now live in MUI_FocusManager:PickTarget,
-- making the arrow work for any focusable kind (quest, flightmaster, …)
-- without per-kind code paths.
--
-- Visibility: hidden when nothing is focused, the focused kind has no
-- registered adapter, the adapter returns no useful target, the player /
-- target is unresolvable, OR the target's projected pixel distance from
-- the minimap centre is inside the visible radius — in that case the pin
-- (or area outline) takes over and the arrow becomes redundant.

class "FocusedTargetArrow" : extends "MinimapEdgeArrow" {
    __init = function(self, name, size)
        MinimapEdgeArrow.__init(self, name, size or 14)
        self:SetIconType("QuestArrow")

        -- Tooltip source: dedupKey is "kind:key" so the arrow shares the
        -- focused target's dedup slot with any pin / area / overlay for
        -- the same target. Lower priority than pins so a pin hover wins.
        MUI_MinimapTooltip:Register("focusarrow", {
            isHovered = function()
                return self:IsShown() and MouseIsOver(self._native)
            end,
            dedupKey = function()
                local kind, key = MUI_FocusManager:GetFocus()
                if kind and key then
                    return kind .. ":" .. tostring(key)
                end
                return "focusarrow:none"
            end,
            priority = 1,
            build = function()
                local kind, key = MUI_FocusManager:GetFocus()
                if not kind then return end
                local adapter = MUI_FocusManager:GetAdapter(kind)
                if adapter and adapter.FillTooltip then
                    adapter:FillTooltip(key, "title")
                end
            end,
        })
    end;

    -- Per-frame ticker callback (registered by MinimapEdgeArrow.__init via
    -- MUI_MinimapPinTicker:Register).
    Refresh = function(self)
        local target = MUI_FocusManager:PickTarget()
        if not target then self:Hide(); return end

        -- Same axis convention as MinimapPin / MinimapEdgeArrow.
        -- UnitPosition: index 1 = N-S (+north), index 2 = E-W (+west).
        local east  = target.playerX - target.wy
        local north = target.wx - target.playerY

        if GetCVar("rotateMinimap") == "1" then
            local facing = GetPlayerFacing() or 0
            local c, s = math.cos(facing), math.sin(facing)
            east, north = east * c + north * s, -east * s + north * c
        end

        local distYd = math.sqrt(east * east + north * north)
        if distYd < 0.001 then self:Hide(); return end

        local zoomYards = MUI_MinimapPinTicker:YardsPerRadius()
        if zoomYards <= 0 then self:Hide(); return end

        local radiusPx  = MUI_Minimap:GetWidth() * 0.5 - 3
        local arrowHalf = self:GetWidth() * 0.5
        local effR      = radiusPx - arrowHalf

        -- Target inside the visible minimap radius → its pin / area
        -- handles display; arrow hides.
        local scale  = radiusPx / zoomYards
        local pxDist = distYd * scale
        if pxDist <= effR then self:Hide(); return end

        local nx = east  / distYd
        local ny = north / distYd

        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", nx * effR, ny * effR)

        -- Atlas chevron faces +east; rotate to point toward (east, north).
        -- −π/2 accounts for the art's +north-up convention.
        self._icon:SetRotation(math.atan2(ny, nx) - math.pi / 2)

        self:SetAlpha(1)
        self:Show()
    end;
}
