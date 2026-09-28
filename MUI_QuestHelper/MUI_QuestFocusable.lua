-- MUI_QuestFocusable: focus adapter for the "quest" kind. Translates a
-- questId into the candidate-tier shape the generic FocusedTargetArrow /
-- FocusNavigation widgets expect. Delegates to QuestObjectiveCluster
-- (already authored once per quest in MUI_QuestHelper) for geographic
-- data — no clustering / hull math lives here.
--
-- Tier order (walker stops at first non-empty):
--   1. Cluster centroids (carry their hull for proximity fade).
--   2. Stray objective points (no hull — quests below clustering threshold).
--   3. Finisher (turn-in NPC / object) points — used when objectives are
--      exhausted or the quest is ready to turn in.
-- Levels 1 and 2 emit one tier per continent, the player's continent
-- first, so a quest with targets on both sides of the sea (a required
-- source item in Westfall for a Moonglade quest) walks the reachable
-- ones before rerouting to a boat.

object "QuestFocusable" {

    __init = function(self)
        -- Register the "quest" kind at file load time. MUI_FocusManager singleton
        -- exists from when its file loaded (which the .toc places ahead of this
        -- one), so the registry is reachable now.
        MUI_FocusManager:RegisterKind("quest", self)
    end;

    GetTargetPoints = function(self, questId)
        local cluster = MUI_QuestHelper:GetQuestClusters(questId)
        if not cluster or cluster:IsEmpty() then return nil end

        local tiers = {}
        local _, _, _, playerCont = UnitPosition("player")
        local continents = cluster:GetContinents(playerCont)

        for _, cont in ipairs(continents) do
            local pts = {}
            for _, c in ipairs(cluster:GetClusters(cont)) do
                pts[#pts + 1] = { c.centroid[1], c.centroid[2], hull = c.hull }
            end
            if #pts > 0 then
                tiers[#tiers + 1] = { points = pts, continent = cont }
            end
        end

        for _, cont in ipairs(continents) do
            local pts = {}
            for _, p in ipairs(cluster:GetPoints(cont)) do
                pts[#pts + 1] = { p[1], p[2] }
            end
            if #pts > 0 then
                tiers[#tiers + 1] = { points = pts, continent = cont }
            end
        end

        local fins = cluster:GetFinisherPoints()
        if fins and #fins > 0 then
            local pts = {}
            for _, p in ipairs(fins) do
                pts[#pts + 1] = { p[1], p[2] }
            end
            tiers[#tiers + 1] = {
                points    = pts,
                continent = cluster:GetFinisherContinent(),
            }
        end

        if #tiers == 0 then return nil end
        return tiers
    end;

    FillTooltip = function(self, questId, mode)
        MUI_QuestHelper:FillQuestTooltip(questId, mode)
    end;
}
