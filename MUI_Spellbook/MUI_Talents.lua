
local SPEC_ROLE = {
    [1]  = {"dps",  "dps",  "tank"},
    [2]  = {"heal", "tank", "dps"},
    [3]  = {"dps",  "dps",  "dps"},
    [4]  = {"dps",  "dps",  "dps"},
    [5]  = {"heal", "heal", "dps"},
    [6]  = {},
    [7]  = {"dps",  "dps",  "heal"},
    [8]  = {"dps",  "dps",  "dps"},
    [9]  = {"dps",  "dps",  "dps"},
    [11] = {"dps",  "tank", "heal"}
}

MUI_SPEC_ICONS = {
    [1] = {                 -- WARRIOR
        MUI.TEX_ICON .. "Ability_Warrior_SavageBlow",
        MUI.TEX_ICON .. "Ability_Warrior_InnerRage",
        MUI.TEX_ICON .. "Ability_Warrior_DefensiveStance",
    },
    [2] = {                 -- PALADIN
        MUI.TEX_ICON .. "Spell_Holy_HolyBolt",
        MUI.TEX_ICON .. "Spell_Holy_DevotionAura",
        --MUI.TEX_ICON .. "Ability_Paladin_ShieldoftheTemplar",
        MUI.TEX_ICON .. "Spell_Holy_AuraOfLight"
    },
    [3] = {                 -- HUNTER
        MUI.TEX_ICON .. "Ability_Hunter_BestialDiscipline",
        MUI.TEX_ICON .. "Ability_Hunter_FocusedAim",
        MUI.TEX_ICON .. "Ability_Hunter_Camouflage",
    },
    [4] = {                 -- ROGUE
        MUI.TEX_ICON .. "Ability_Rogue_DeadlyBrew",
        MUI.TEX_ICON .. "Ability_Rogue_Waylay",
        MUI.TEX_ICON .. "Ability_Stealth",
    },
    [5] = {                 -- PRIEST
        MUI.TEX_ICON .. "Spell_Holy_PowerWordShield",
        MUI.TEX_ICON .. "Spell_Holy_GuardianSpirit",
        MUI.TEX_ICON .. "Spell_Shadow_ShadowWordPain",
    },
    [6] = {                 -- DK (reserved)

    },
    [7] = {                 -- SHAMAN
        MUI.TEX_ICON .. "Spell_Nature_Lightning",
        MUI.TEX_ICON .. "Spell_Shaman_ImprovedStormstrike",
        MUI.TEX_ICON .. "Spell_Nature_MagicImmunity",
    },
    [8] = {                 -- MAGE
        MUI.TEX_ICON .. "Spell_Holy_MagicalSentry",
        MUI.TEX_ICON .. "Spell_Fire_FireBolt02",
        MUI.TEX_ICON .. "Spell_Frost_FrostBolt02",
    },
    [9] = {                 -- WARLOCK
        MUI.TEX_ICON .. "Spell_Shadow_DeathCoil",
        MUI.TEX_ICON .. "Spell_Shadow_Metamorphosis",
        MUI.TEX_ICON .. "Spell_Shadow_RainOfFire",
    },
    [11] = {                -- DRUID
        MUI.TEX_ICON .. "Spell_Nature_StarFall",
        MUI.TEX_ICON .. "Ability_Racial_BearForm",
        MUI.TEX_ICON .. "Spell_Nature_HealingTouch",
    },
}

object "Talents" {

    __init = function(self)
        -- No-op
    end;

    GetSpecRole = function(self, index)
        local _, _, classID = UnitClass("player")
        return SPEC_ROLE[classID][index]
    end;

    GetPrimarySpec = function(self)

        local bestIndex
        local bestName
        local bestIcon
        local bestPoints = 0

        for i = 1, GetNumTalentTabs() do
			local _, name, _, icon, pointsSpent = GetTalentTabInfo(i)
            if pointsSpent > bestPoints then
                bestIndex  = i
                bestName   = name
                bestIcon   = icon
                bestPoints = pointsSpent
            end
		end

        if bestIndex then
           return {
                index = bestIndex,
                name = bestName,
                icon = bestIcon,
                points = bestPoints
            }
        else
            return nil
        end

    end;

}