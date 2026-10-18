-- MUI_Social: Era's social window — FriendsFrame, with its Friends, Who,
-- Guild and Raid tabs — as retail's: the wider metal-framed window, frame
-- tabs, minimal scroll bars, and a Recent Allies list on the Friends tab.
-- The window and its lists stay Blizzard's (SocialWindow says why).

object "ModuleSocial" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Social")
    end;

    OnEnable = function(self)
        self.window = SocialWindow()
    end;
}
