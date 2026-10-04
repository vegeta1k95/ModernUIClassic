-- DungeonDB: hard-coded Classic Era dungeon / raid entrance coordinates.
-- The Questie-derived MUI_QuestDB doesn't carry these — dungeon interiors
-- are separate maps whose world coords aren't reachable on foot, so the
-- outer-world entrance has to be authored.
--
-- Coordinates are stored Questie-style: Questie AreaId + normalised 0-100
-- percent. World yards are resolved on demand via MUI_MapMath.

object "DungeonDB" {
    __init = function(self)
        -- [dungeonAreaId] = { outerAreaId, x, y, name, isRaid, minLevel, maxLevel }
        -- Level ranges are the Classic meeting-stone ranges; a raid is 60.
        -- Values transcribed from Questie's Zones/data/dungeons.lua for the
        -- set of instances that exist in Classic Era. Multi-entrance raids
        -- (BRS/MC/BWL share the Blackrock Mountain entrance, Stratholme's
        -- two gates) collapse to their primary outer-world coord; that's
        -- good enough to aim an arrow OR place a pin.
        self._dungeons = {

            [2437] = { outerAreaId = 1637, x = 52.6, y = 49.0, name = "Ragefire Chasm", minLevel = 13, maxLevel = 18 },
            [209]  = { outerAreaId = 130,  x = 44.8, y = 67.8, name = "Shadowfang Keep", minLevel = 22, maxLevel = 30 },
            [491]  = { outerAreaId =  17,  x = 42.9, y = 90.2, name = "Razorfen Kraul", minLevel = 30, maxLevel = 40 },
            [717]  = { outerAreaId = 1519, x = 40.7, y = 55.7, name = "The Stockade", minLevel = 24, maxLevel = 32 },
            [718]  = { outerAreaId =  17,  x = 46.0, y = 36.5, name = "Wailing Caverns", minLevel = 17, maxLevel = 24 },
            [719]  = { outerAreaId = 331,  x = 14.5, y = 14.2, name = "Blackfathom Deeps", minLevel = 24, maxLevel = 32 },
            [721]  = { outerAreaId =   1,  x = 24.3, y = 39.8, name = "Gnomeregan", minLevel = 29, maxLevel = 38 },
            [722]  = { outerAreaId =  17,  x = 49.0, y = 93.9, name = "Razorfen Downs", minLevel = 40, maxLevel = 50 },
            [796]  = { outerAreaId =  85,  x = 82.6, y = 33.8, name = "Scarlet Monastery", minLevel = 26, maxLevel = 45 },
            [1176] = { outerAreaId = 440,  x = 38.7, y = 20.1, name = "Zul'Farrak", minLevel = 44, maxLevel = 54 },
            [1337] = { outerAreaId =   3,  x = 44.6, y = 12.1, name = "Uldaman", minLevel = 42, maxLevel = 52 },
            [1477] = { outerAreaId =   8,  x = 69.9, y = 53.5, name = "Sunken Temple", minLevel = 50, maxLevel = 56 },
            [1581] = { outerAreaId =  40,  x = 42.5, y = 71.7, name = "The Deadmines", minLevel = 18, maxLevel = 23 },
            [2100] = { outerAreaId = 405,  x = 29.1, y = 62.5, name = "Maraudon", minLevel = 46, maxLevel = 55 },
            [1583] = { outerAreaId =  51,  x = 40.7, y = 95.75,  name = "Blackrock Spire", minLevel = 55, maxLevel = 60 },
            [1584] = { outerAreaId =  46,  x = 22.78, y = 17.70, name = "Blackrock Depths", minLevel = 52, maxLevel = 60 },
            [2017] = { outerAreaId = 139,  x = 31.3, y = 15.7, name = "Stratholme", minLevel = 58, maxLevel = 60 },
            [2057] = { outerAreaId =  28,  x = 69.7, y = 73.2, name = "Scholomance", minLevel = 58, maxLevel = 60 },
            [2557] = { outerAreaId = 357,  x = 59.2, y = 45.1, name = "Dire Maul", minLevel = 56, maxLevel = 60 },
            
            -- 20 ppl
            [2159] = { outerAreaId =  15,  x = 52.6, y = 76.8, name = "Onyxia's Lair",       isRaid = true, minLevel = 60, maxLevel = 60 },
            [1977] = { outerAreaId =  33,  x = 53.9, y = 17.6, name = "Zul'Gurub",           isRaid = true, minLevel = 60, maxLevel = 60 },
            [3429] = { outerAreaId = 1377, x = 28.6, y = 92.3, name = "Ruins of Ahn'Qiraj",  isRaid = true, minLevel = 60, maxLevel = 60 },
            
            -- 40 ppl
            [2717] = { outerAreaId =  46,  x = 26.44, y = 24.44, name = "Molten Core",         isRaid = true, minLevel = 60, maxLevel = 60 },
            [2677] = { outerAreaId =  46,  x = 32.55, y = 32.13, name = "Blackwing Lair",      isRaid = true, minLevel = 60, maxLevel = 60 },
            [3428] = { outerAreaId = 1377, x = 28.6, y = 92.3, name = "Temple of Ahn'Qiraj", isRaid = true, minLevel = 60, maxLevel = 60 },
            [3456] = { outerAreaId = 139,  x = 39.9, y = 25.8, name = "Naxxramas",           isRaid = true, minLevel = 60, maxLevel = 60 },
        }
    end;

    -- Returns {outerAreaId, x, y, name, isRaid} for the dungeon's primary
    -- outer world entrance, or nil if the area id isn't a known dungeon.
    GetDungeonEntrance = function(self, areaId)
        return self._dungeons[areaId]
    end;

    -- Every dungeon entrance resolved to world yards. Each entry:
    -- { key, wx, wy, continent, name, isRaid, minLevel, maxLevel }. `key` is the dungeon's
    -- areaId (stable, locale-independent). Skips entries whose outer area
    -- can't be resolved (DB not loaded yet, etc.).
    GetAllDungeons = function(self)
        local out = {}
        for dungeonAreaId, d in pairs(self._dungeons) do
            local outerUi = MUI_ZoneDB and MUI_ZoneDB:GetUiMapForArea(d.outerAreaId)
            if outerUi then
                local wx, wy, cont = MUI_MapMath:MapToWorld(outerUi, d.x / 100, d.y / 100)
                if wx and wy then
                    out[#out + 1] = {
                        key = dungeonAreaId,
                        wx = wx, wy = wy, continent = cont,
                        name = d.name,
                        isRaid = d.isRaid and true or false,
                        minLevel = d.minLevel, maxLevel = d.maxLevel,
                    }
                end
            end
        end
        return out
    end;
}
