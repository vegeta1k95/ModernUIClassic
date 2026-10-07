-- MUI_Achievements: retail's achievement system for Classic Era, which has
-- none — our own definitions (MUI_AchievementDB), an engine that evaluates
-- and awards them from the character's state and the trackers' tallies
-- (MUI_AchievementEngine, MUI_AchievementTrackers), the Statistics tab's
-- own trackers (MUI_StatisticsTrackers over MUI_StatisticsDB), the panel
-- (MUI_AchievementFrame) and the earned toast (MUI_AchievementToast). The
-- micro menu's Achievements button opens the panel; so does /muiach.
--
--   /muiach          toggle the panel
--   /muiach reset    forget this character's achievements and sweep again
--   /muiach toast    preview the earned toast

object "ModuleAchievements" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Achievements")
    end;

    OnEnable = function(self)
        self.engine   = AchievementEngine()
        self.trackers = AchievementTrackers(self.engine)
        self.statistics = StatisticsTrackers(self.engine)
        self.frame    = AchievementWindow(self.engine)
        MUI_ModuleMicroMenu:WireAchievements(self.frame)
        MUI_QuestHelper.tracker:SetAchievementEngine(self.engine)

        -- Past deeds count: a sweep a few seconds after login, clear of the
        -- loading rush.
        C_Timer.After(5, function() self.engine:Backfill() end)

        ChatCommand("muiach", function(_, msg)
            local cmd = string.match(msg or "", "^%s*(%S*)")
            if cmd == "reset" then
                self.engine:Reset()
            elseif cmd == "toast" then
                local def = self.engine.list[1]
                if def then
                    MUI_ModuleToasts:ShowAchievement({ id = def.id, name = def.name, pts = def.pts, icon = self.engine:IconPath(def) })
                end
            else
                self.frame:Toggle()
            end
        end)
    end;

    -- Open the panel on an achievement (the toast's click).
    Open = function(self, id)
        self.frame:Open(id)
    end;
}
