-- QuestHubDB: hand-curated list of major quest hubs.
--
-- Each hub defines a fixed centroid + absorption radius on a single
-- uiMap. At runtime, MapStaticPinManager renders one hub pin per hub on
-- the displayed uiMap and absorbs every available-quest pin whose
-- normalized position falls within `radius` of the centroid into the
-- hub's tooltip.
--
-- Hub pins ALWAYS render whenever their uiMap is displayed (even with
-- zero available quests) so the layout is universal — every player sees
-- the same hub markers regardless of level / quest state. The tooltip
-- leads with the hub's name + flavor; available quests (if any) follow
-- as a list.
--
-- Coordinates are normalized 0..1 on the listed uiMap; radius is in the
-- same units. Tune individual radii to match each hub's footprint.

object "QuestHubDB" {
    __init = function(self)
        self._hubs = {
            { id      = "lights_hope_chapel",
              uiMapId = 1423, name = "Light's Hope Chapel",
              flavor  = "Sanctified Argent Dawn outpost guarding the Plaguelands.",
              nx = 0.81, ny = 0.59, radius = 0.05 },

            { id      = "booty_bay",
              uiMapId = 1434, name = "Booty Bay",
              flavor  = "Goblin port and Steamwheedle Cartel stronghold on Stranglethorn's southern coast.",
              nx = 0.28, ny = 0.76, radius = 0.05 },

            { id      = "gadgetzan",
              uiMapId = 1446, name = "Gadgetzan",
              flavor  = "Goblin trade city in the Tanaris desert.",
              nx = 0.51, ny = 0.28, radius = 0.04 },

            { id      = "everlook",
              uiMapId = 1452, name = "Everlook",
              flavor  = "Goblin trading post tucked into Winterspring's icy peaks.",
              nx = 0.61, ny = 0.38, radius = 0.04 },

            { id      = "ratchet",
              uiMapId = 1413, name = "Ratchet",
              flavor  = "Steamwheedle Cartel port on the eastern Barrens shore.",
              nx = 0.62, ny = 0.37, radius = 0.04 },

            { id      = "cenarion_hold",
              uiMapId = 1451, name = "Cenarion Hold",
              flavor  = "Druid stronghold in Silithus, anchoring the war against the Qiraji.",
              nx = 0.50, ny = 0.39, radius = 0.04 },

            { id      = "thorium_point",
              uiMapId = 1427, name = "Thorium Point",
              flavor  = "Thorium Brotherhood encampment in the Searing Gorge.",
              nx = 0.38, ny = 0.27, radius = 0.04 },
        }

        self._byUiMap = {}
        self._byId    = {}
        for _, h in ipairs(self._hubs) do
            local list = self._byUiMap[h.uiMapId]
            if not list then
                list = {}
                self._byUiMap[h.uiMapId] = list
            end
            list[#list + 1] = h
            self._byId[h.id] = h
        end
    end;

    GetHubsForUiMap = function(self, uiMapId)
        return self._byUiMap[uiMapId]
    end;

    GetHubById = function(self, id)
        return self._byId[id]
    end;

    GetAllHubs = function(self)
        return self._hubs
    end;
}
