-- QuestObjectiveResolver: pure resolver of questId → list of pin specs.
-- Walks MUI_QuestDB for the quest's objective table and collects every
-- spawn point of referenced creatures, objects, and items. Zone filtering
-- is left to the caller; specs are returned for every zone the target is
-- known to exist in.
--
-- Spec shape:
--   {
--       areaId       = <Questie area id>,
--       uiMapId      = <WoW UI map id, may be nil if unmapped>,
--       normX        = 0..1 (fraction of map width),
--       normY        = 0..1,
--       iconType     = <string key into MUI_MinimapPinIcons>,
--       questId      = questId,
--       objectiveIdx = <1..N, 0 for turn-in, -1 for trigger-end scout>,
--       targetId     = <npc/object/item id>,
--       targetKind   = "npc" | "object" | "item-npc" | "item-object" | "trigger",
--       spawnIdx     = <per-areaId spawn index>,
--       targetName   = <string, DB target name, may include item context>,
--   }

-- Safety ceiling matching Questie's `iconLimit` default. Effectively
-- unlimited for any real quest; clustering downstream is what actually
-- bounds visible pin count.

local OBJECTS_PER_OBJECTIVE = 1500

-- Emit one spec per spawn in `spawns`. Shape: { [areaId] = { {x, y}, ... } }.
-- Coordinates in DB are 0..100 percent; we emit 0..1 fractions.
-- Caps the TOTAL emitted for this target at QUEST_PIN_LIMIT_PER_OBJECTIVE
-- (across all zones) to prevent "kill 10 X" pinning 100 Xs.
local function _emitSpawnSpecs(out, spawns, base)
    if not spawns then return end
    local count = 0
    for areaId, coordList in pairs(spawns) do
        for spawnIdx, coord in ipairs(coordList) do
            if count >= OBJECTS_PER_OBJECTIVE then return end
            out[#out + 1] = {
                areaId       = areaId,
                uiMapId      = MUI_ZoneDB:GetUiMapForArea(areaId),
                normX        = coord[1] / 100,
                normY        = coord[2] / 100,
                iconType     = base.iconType,
                questId      = base.questId,
                objectiveIdx = base.objectiveIdx,
                targetId     = base.targetId,
                targetKind   = base.targetKind,
                spawnIdx     = spawnIdx,
                targetName   = base.targetName,
            }
            count = count + 1
        end
    end
end

local function _resolveCreature(out, questId, objectiveIdx, creatureId, iconType)
    local npc = MUI_NpcDB:Get(creatureId)
    if not npc then return end
    _emitSpawnSpecs(out, npc.spawns, {
        iconType     = iconType,
        questId      = questId,
        objectiveIdx = objectiveIdx,
        targetId     = creatureId,
        targetKind   = "npc",
        targetName   = npc.name or "?",
    })
end

local function _resolveObject(out, questId, objectiveIdx, objectId, iconType)
    local obj = MUI_ObjectDB:Get(objectId)
    if not obj then return end
    _emitSpawnSpecs(out, obj.spawns, {
        iconType     = iconType,
        questId      = questId,
        objectiveIdx = objectiveIdx,
        targetId     = objectId,
        targetKind   = "object",
        targetName   = obj.name or "?",
    })
end

local function _resolveItem(out, questId, objectiveIdx, itemId)
    local item = MUI_ItemDB:Get(itemId)
    if not item then return end
    local itemName = item.name or "?"
    -- IMPORTANT: targetId is the *source* ID (NPC / Object), not itemId.
    -- Clustering downstream groups by (objectiveIdx, targetId); using itemId
    -- would merge every drop source into one cluster, erasing distinct camps
    -- across the zone. Matches Questie's QuestieQuestPrivates.item() which
    -- keys the return table by source.Id.
    if item.npcDrops then
        for _, npcId in ipairs(item.npcDrops) do
            local npc = MUI_NpcDB:Get(npcId)
            if npc then
                _emitSpawnSpecs(out, npc.spawns, {
                    iconType     = "ObjectiveLoot",
                    questId      = questId,
                    objectiveIdx = objectiveIdx,
                    targetId     = npcId,
                    targetKind   = "item-npc",
                    targetName   = itemName .. " <" .. (npc.name or "?") .. ">",
                })
            end
        end
    end
    if item.objectDrops then
        for _, objId in ipairs(item.objectDrops) do
            local obj = MUI_ObjectDB:Get(objId)
            if obj then
                -- Items sourced from world objects need an interact icon,
                -- not the "loot from corpse" icon. Matches Questie's
                -- QuestieQuestPrivates.item() branch (source.Type == "object"
                -- → ICON_TYPE_OBJECT).
                _emitSpawnSpecs(out, obj.spawns, {
                    iconType     = "ObjectiveObject",
                    questId      = questId,
                    objectiveIdx = objectiveIdx,
                    targetId     = objId,
                    targetKind   = "item-object",
                    targetName   = itemName .. " <" .. (obj.name or "?") .. ">",
                })
            end
        end
    end
end

-- triggerEnd shape: { "Scout description", { [areaId] = { {x, y}, ... } } }
local function _resolveTriggerEnd(out, questId, triggerEnd)
    if not triggerEnd then return end
    local desc, zones = triggerEnd[1], triggerEnd[2]
    if type(zones) ~= "table" then return end
    _emitSpawnSpecs(out, zones, {
        iconType     = "ObjectiveEvent",
        questId      = questId,
        objectiveIdx = -1,
        targetId     = 0,
        targetKind   = "trigger",
        targetName   = desc or "Scout location",
    })
end

object "QuestObjectiveResolver" {
    
    -- Geographic objective targets for an in-progress quest. Returns {} for
    -- quests with no geographic objectives (e.g. "speak with finisher" quests);
    -- callers should fall back to ResolveFinishers for those.
    ResolveObjectives = function(self, questId)
        local q = MUI_QuestDB:Get(questId)
        if not q then return {} end

        local out = {}

        if q.objectives then
            -- [1] creature (slay / speak-with) objectives
            if q.objectives[1] then
                for _, entry in ipairs(q.objectives[1]) do
                    if entry and entry[1] then
                        _resolveCreature(out, questId, 1, entry[1], "ObjectiveSlay")
                    end
                end
            end
            -- [2] object (interact / use) objectives
            if q.objectives[2] then
                for _, entry in ipairs(q.objectives[2]) do
                    if entry and entry[1] then
                        _resolveObject(out, questId, 2, entry[1], "ObjectiveObject")
                    end
                end
            end
            -- [3] item (loot) objectives: pin each drop source (npc or object)
            if q.objectives[3] then
                for _, entry in ipairs(q.objectives[3]) do
                    if entry and entry[1] then
                        _resolveItem(out, questId, 3, entry[1])
                    end
                end
            end
            -- [4] reputation — no geographic target, skip
            -- [5] killCredit — geographic, same treatment as [1]
            if q.objectives[5] then
                for _, entry in ipairs(q.objectives[5]) do
                    if entry and entry[1] then
                        _resolveCreature(out, questId, 5, entry[1], "ObjectiveSlay")
                    end
                end
            end
            -- [6] spell — no geographic target, skip
        end

        -- Scout-location trigger end (world position, no target entity).
        _resolveTriggerEnd(out, questId, q.triggerEnd)

        return out
    end;

    -- Turn-in spawn points. finishedBy shape: {{npcId, ...}, {objectId, ...}}.
    ResolveFinishers = function(self, questId)
        local q = MUI_QuestDB:Get(questId)
        if not q or not q.finishedBy then return {} end

        local out = {}
        if q.finishedBy[1] then
            for _, npcId in ipairs(q.finishedBy[1]) do
                _resolveCreature(out, questId, 0, npcId, "QuestTurnIn")
            end
        end
        if q.finishedBy[2] then
            for _, objId in ipairs(q.finishedBy[2]) do
                _resolveObject(out, questId, 0, objId, "QuestTurnIn")
            end
        end
        return out
    end;
}
