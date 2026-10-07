-- MUI_Character: retail's character window on Classic Era.
--
--   MUI_CharacterFrame        the window, on Era's own CharacterFrame: the
--                             chrome, the tabs, the pane each tab shows
--   MUI_CharacterModel        a unit's model with retail's control bar
--   MUI_CharacterStats        the stat sheet (the character's, the pet's)
--   MUI_CharacterEquipment    equipment sets, their manager, the slot flyout
--   MUI_CharacterSidebar      the paper doll's side pane and its tabs
--   MUI_CharacterPaperDoll    the Character tab
--   MUI_CharacterPet          the Pet tab
--   MUI_CharacterReputation   the Reputation tab
--   MUI_CharacterSkills       the Skills tab
--   MUI_CharacterHonor        the Honor tab
--
-- Not carried over from retail, which Era has nothing for: titles, the
-- currency tab, item level upgrades. Era's own extras are kept: the pet,
-- skills and honor tabs, the ranged and ammo slots, the guild line.

object "ModuleCharacter" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Character")
    end;

    OnEnable = function(self)
        self.window = CharacterWindow()
    end;
}
