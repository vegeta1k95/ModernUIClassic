-- Resolver: turn structured `source` entries from MUI_RecipeDB (kind = trainer
-- / vendor / drop / quest / reputation / worldDrop) into tooltip lines, plus
-- a small handful of ID-to-display-name helpers shared by the recipe pane.
--
-- Stateless singleton — exposed globally as MUI_ProfessionsSourceResolver.
-- Callers pass per-call context (current profession name, recipe's orange
-- threshold) to BuildSourceLines so the resolver doesn't have to reach
-- back into the tradeskill frame's instance state.

local L = MUI.L

-- MUI_RecipeDB's factions, standings and events (in English) as a source
-- line shows them.
local FACTION_TEXT = {
    ["Argent Dawn"]         = L.PROF_FACTION_ARGENT_DAWN,
    ["Cenarion Circle"]     = L.PROF_FACTION_CENARION_CIRCLE,
    ["Thorium Brotherhood"] = L.PROF_FACTION_THORIUM_BROTHERHOOD,
    ["Timbermaw Hold"]      = L.PROF_FACTION_TIMBERMAW_HOLD,
    ["Zandalar Tribe"]      = L.PROF_FACTION_ZANDALAR_TRIBE,
}
local STANDING_TEXT = {
    Friendly = FACTION_STANDING_LABEL5, Honored = FACTION_STANDING_LABEL6,
    Revered  = FACTION_STANDING_LABEL7, Exalted = FACTION_STANDING_LABEL8,
}
local EVENT_TEXT = {
    ["Feast of Winter Veil"] = L.CAL_HOLIDAY_WINTER_VEIL,
}

object "ProfessionsSourceResolver" {

    -- Display-name overrides ONLY for area-ids the source parser collapses
    -- several related areas onto (see ZONE_ALIASES in _patch_ench_sources.py).
    -- AQ20 + AQ40 alias to the AQ40 area-id, so we override the rendered name
    -- "Temple of Ahn'Qiraj" → "Ahn'Qiraj" to cover both instances.
    -- Single-instance zones get their name from MUI_DungeonDB; no need to
    -- hard-code them here.
    _ZONE_NAME_OVERRIDES = {
        [3428] = "Ahn'Qiraj",
    },

    -- Resolve a stored NPC id into (name, zoneName). Both are bare —
    -- callers add formatting. Zone is looked up via MUI_ZoneDB →
    -- uiMapId → C_Map.GetMapInfo, returning "" when any link is missing.
    ResolveNpc = function(self, npcId)
        if not npcId or not MUI_NpcDB then return UNKNOWN, "" end
        local npc = MUI_NpcDB:Get(npcId)
        local name = (npc and npc.name) or UNKNOWN
        local zone = ""
        if npc and npc.zoneID and MUI_ZoneDB then
            local uiMapId = MUI_ZoneDB:GetUiMapForArea(npc.zoneID)
            if uiMapId and C_Map and C_Map.GetMapInfo then
                local info = C_Map.GetMapInfo(uiMapId)
                if info and info.name then zone = info.name end
            end
        end
        return name, zone
    end;

    -- Resolve an area id directly into its localized zone name. Order:
    --   1. _ZONE_NAME_OVERRIDES (parser-aliased zones)
    --   2. MUI_DungeonDB         (every Classic dungeon + raid)
    --   3. ZoneDB → C_Map.GetMapInfo  (outdoor zones)
    --   4. C_Map.GetAreaInfo / GetMapNameByID  (defensive last resort)
    ResolveZone = function(self, areaId)
        if not areaId then return "" end
        local override = self._ZONE_NAME_OVERRIDES and self._ZONE_NAME_OVERRIDES[areaId]
        if override then return override end
        if MUI_DungeonDB then
            local d = MUI_DungeonDB:GetDungeonEntrance(areaId)
            if d and d.name and d.name ~= "" then return d.name end
        end
        if MUI_ZoneDB then
            local uiMapId = MUI_ZoneDB:GetUiMapForArea(areaId)
            if uiMapId and C_Map and C_Map.GetMapInfo then
                local info = C_Map.GetMapInfo(uiMapId)
                if info and info.name and info.name ~= "" then return info.name end
            end
        end
        if C_Map and C_Map.GetAreaInfo then
            local name = C_Map.GetAreaInfo(areaId)
            if name and name ~= "" then return name end
        end
        if GetMapNameByID then
            local name = GetMapNameByID(areaId)
            if name and name ~= "" then return name end
        end
        return ""
    end;

    -- Resolve an item id into its localized name (MUI_ItemDB first, then
    -- GetItemInfo as fallback if the player has the item cached).
    ResolveItem = function(self, itemId)
        if not itemId then return "" end
        local entry = MUI_ItemDB and MUI_ItemDB:Get(itemId)
        if entry and entry.name then return entry.name end
        return C_Item.GetItemInfo(itemId) or RETRIEVING_ITEM_INFO
    end;

    -- Resolve a quest id into its localized name (MUI_QuestDB first, then
    -- a generic placeholder if Questie data isn't in scope).
    ResolveQuest = function(self, questId)
        if not questId then return "" end
        local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
        if q and q.name then return MUI_QuestDB:LocalizeQuestName(questId) end
        return UNKNOWN
    end;

    -- Build a single tooltip line from a structured source entry. Schema:
    --   trainer       — { npc? }                       Taught by a trainer
    --   trainerManual — { item }                       Manual sold by any trainer
    --   vendor        — { npc, item? }                 Sold by a specific NPC
    --                 — { npcA, npcH, item? }          Alliance + Horde split
    --   drop          — { npc?, zone?, item? }         Drops from an NPC, or
    --                                                  from many creatures in
    --                                                  one zone
    --   quest         — { quest, item? }               Quest reward
    --   reputation    — { faction, standing?, item? }  Faction quartermaster
    --   worldDrop     — { item?, event? }              Random world drop
    --                                                  (event labels holiday-
    --                                                  only drops like "Feast
    --                                                  of Winter Veil")
    --
    -- `ctx` carries info that isn't on the entry itself:
    --     profName — current profession's display name (for trainer lines)
    --     orange   — recipe's orange-skill threshold (for trainer line suffix)
    --
    -- Each label up through ':' is gold-coded; the value text is white.
    BuildSourceLines = function(self, tooltip, entry, ctx)
        local kind = entry.kind
        local GOLD, R = "|cffffd200", "|r"
        local function emit(label, value)
            tooltip:AddLine(GOLD .. label .. HEADER_COLON .. R .. " " .. (value or ""), 1, 1, 1, false, 12)
        end

        if kind == "trainer" or kind == "trainerManual" then
            local profName = (ctx and ctx.profName) or "?"
            local lvl = ctx and ctx.orange
            local suffix = lvl and (" (" .. lvl .. ")") or ""
            emit(L.PROF_SOURCE_TRAINER, profName .. suffix)
        elseif kind == "vendor" then
            -- Alliance/Horde split (npcA/npcH) — pick by the player's faction.
            -- Neutral / single-faction vendors live in `npc` and apply to both.
            local npc = entry.npc
            if not npc and (entry.npcA or entry.npcH) then
                local fac = UnitFactionGroup and UnitFactionGroup("player")
                if fac == "Alliance" then npc = entry.npcA or entry.npcH
                else                       npc = entry.npcH or entry.npcA end
            end
            local who, zone = self:ResolveNpc(npc)
            emit(TRANSMOG_SOURCE_3, who)
            if zone ~= "" then emit(ZONE, zone) end
        elseif kind == "drop" then
            -- Three shapes (decided by the source-parser):
            --   { npc, zone? }    → single NPC drop     "Loot: <npc>" + "Zone: <zone>"
            --   { zone }          → many NPCs, one zone "Loot: creatures in <zone>"
            --   {        }        → fallback            "Loot: Unknown"
            -- entry.zone is always preferred over NPC's zoneID (when both
            -- exist) since MUI_NpcDB is incomplete for instance NPCs.
            if entry.npc then
                local who = self:ResolveNpc(entry.npc)
                emit(LOOT_NOUN, who)
                local zoneName = entry.zone and self:ResolveZone(entry.zone) or ""
                if zoneName == "" then
                    local _, npcZone = self:ResolveNpc(entry.npc)
                    zoneName = npcZone
                end
                if zoneName ~= "" then emit(ZONE, zoneName) end
            elseif entry.zone then
                local zoneName = self:ResolveZone(entry.zone)
                emit(LOOT_NOUN, zoneName ~= "" and L.PROF_CREATURES_IN:format(zoneName) or UNKNOWN)
            else
                emit(LOOT_NOUN, UNKNOWN)
            end
        elseif kind == "dungeonDrop" then
            emit(L.PROF_SOURCE, entry.zone or GROUP_FINDER)
        elseif kind == "worldDrop" then
            -- `event` lets us label holiday/event-only world drops:
            --   { kind = "worldDrop", event = "Feast of Winter Veil" }
            -- renders as "Source: Feast of Winter Veil" instead of the
            -- generic "Source: world drop".
            emit(L.PROF_SOURCE, entry.event and EVENT_TEXT[entry.event] or entry.event or TRANSMOG_SOURCE_4)
        elseif kind == "quest" then
            emit(BATTLE_PET_SOURCE_2, self:ResolveQuest(entry.quest))
        elseif kind == "reputation" then
            local rep = FACTION_TEXT[entry.faction] or entry.faction or "?"
            local standing = entry.standing and (" (" .. (STANDING_TEXT[entry.standing] or entry.standing) .. ")") or ""
            emit(COMBAT_FACTION_CHANGE, rep .. standing)
        end
    end;
}
