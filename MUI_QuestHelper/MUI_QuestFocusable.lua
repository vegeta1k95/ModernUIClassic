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

        local clusters = cluster:GetClusters()
        if #clusters > 0 then
            local pts = {}
            for _, c in ipairs(clusters) do
                pts[#pts + 1] = { c.centroid[1], c.centroid[2], hull = c.hull }
            end
            tiers[#tiers + 1] = {
                points    = pts,
                continent = cluster:GetContinent(),
            }
        end

        local stray = cluster:GetPoints()
        if stray and #stray > 0 then
            local pts = {}
            for _, p in ipairs(stray) do
                pts[#pts + 1] = { p[1], p[2] }
            end
            tiers[#tiers + 1] = {
                points    = pts,
                continent = cluster:GetContinent(),
            }
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
