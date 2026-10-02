-- MinimapGroupBlips: class-coloured circles for party / raid members on the
-- minimap, as on our world map.
--
-- The client draws its own group blips (the blue dots) from one fixed sprite,
-- so it can't colour them per class. Ours are drawn on top of those, at the
-- members' world positions. Inside instances the client doesn't report those
-- positions (UnitPosition returns nothing), so there the native dots remain.
--
-- Composed into ModuleMinimap:
--   self.groupBlips = MinimapGroupBlips()

local BLIPS_TEX = MUI.TEX_BASE .. "blips-default"
local BLIP_SIZE = 10      -- about the native dot's size, so it is covered

class "MinimapGroupBlip" : extends "MinimapPin" {
    __init = function(self, unit)
        MinimapPin.__init(self, nil, BLIP_SIZE)
        -- The native blip underneath keeps its name tooltip.
        self:EnableMouse(false)
        self.unit = unit
        self:SetIcon(BLIPS_TEX, 512, 512, 209, 139, 20, 20)
    end;

    UpdateColor = function(self)
        local _, class = UnitClass(self.unit)
        local color = class and RAID_CLASS_COLORS[class]
        if color then
            self:SetIconTint(color.r, color.g, color.b)
        else
            self:SetIconTint(1, 1, 1)
        end
    end;

    Refresh = function(self)
        local unit = self.unit
        if not UnitExists(unit) or UnitIsUnit(unit, "player") then self:Hide(); return end
        local y, x, _, instance = UnitPosition(unit)
        if y then
            local _, _, _, playerInstance = UnitPosition("player")
            if instance ~= playerInstance then self:Hide(); return end
        else
            -- No world position for other units: take the member's spot on
            -- the player's zone map, as the world map's group pins do.
            local mapId = C_Map.GetBestMapForUnit("player")
            local pos = mapId and C_Map.GetPlayerMapPosition(mapId, unit)
            if not pos then self:Hide(); return end
            local mapX, mapY = pos:GetXY()
            if mapX == 0 and mapY == 0 then self:Hide(); return end
            y, x = MUI_MapMath:MapToWorld(mapId, mapX, mapY)
            if not y then self:Hide(); return end
        end
        self._worldX, self._worldY = y, x
        MinimapPin.Refresh(self)
    end;
}

class "MinimapGroupBlips" {
    __init = function(self)
        self._blips = {}    -- [unit token] = MinimapGroupBlip

        self.driver = Frame("Frame", nil, "MUI_MinimapGroupBlipsDriver")
        self.driver:RegisterEventHandler("GROUP_ROSTER_UPDATE",   function() self:Update() end)
        self.driver:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:Update() end)
        self:Update()
    end;

    -- A blip per unit token of the current group. Tokens that fall out of
    -- use hide themselves: their unit has no position any more.
    Update = function(self)
        local prefix, count = "party", 4
        if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
        for i = 1, count do
            local unit = prefix .. i
            if UnitExists(unit) then
                local blip = self._blips[unit]
                if not blip then
                    blip = MinimapGroupBlip(unit)
                    self._blips[unit] = blip
                end
                blip:UpdateColor()
            end
        end
    end;
}
