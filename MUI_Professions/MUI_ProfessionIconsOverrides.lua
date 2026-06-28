-- MUI_ProfessionIconsOverrides
-- Replaces vanilla profession spell icons with our modern ones on the two
-- surfaces where they actually appear:
--   - Action bars (any ActionButton holding a profession spell)
--   - Spellbook pages (the Trade Skills tab in particular)
--
-- Scoped to specific spell IDs rather than texture paths, so other UI elements
-- that happen to share a profession's vanilla icon (recipe items, vendor
-- entries, tooltip cross-refs, etc.) keep their original look.

local R = MUI.TEX_ICON

-- spellID → modern icon. Each profession's four rank IDs, its secondary
-- castables, and its specialization spell IDs all map to that profession's
-- icon. Shared spells (Smelting is castable by both Mining and Blacksmithing)
-- pick one canonical target — Smelting → Mining since the visual reads
-- more like Mining.
local SPELL_ICON_OVERRIDES = {
    -- Alchemy
    [2259]  = R .. "profession-alchemy",
    [3101]  = R .. "profession-alchemy",
    [3464]  = R .. "profession-alchemy",
    [11611] = R .. "profession-alchemy",

    -- Blacksmithing (+ Weaponsmith/Armorsmith and Master sub-specs)
    [2018]  = R .. "profession-blacksmithing",
    [3100]  = R .. "profession-blacksmithing",
    [3538]  = R .. "profession-blacksmithing",
    [9785]  = R .. "profession-blacksmithing",
    --[9787]  = R .. "profession-Blacksmithing",   -- Weaponsmith
    --[9788]  = R .. "profession-Blacksmithing",   -- Armorsmith
    --[17039] = R .. "profession-Blacksmithing",   -- Master Swordsmith
    --[17040] = R .. "profession-Blacksmithing",   -- Master Hammersmith
    --[17041] = R .. "profession-Blacksmithing",   -- Master Axesmith

    -- Enchanting (+ Disenchant)
    [7411]  = R .. "profession-enchanting",
    [7412]  = R .. "profession-enchanting",
    [7413]  = R .. "profession-enchanting",
    [13920] = R .. "profession-enchanting",
    [13262] = R .. "profession-disenchant",      -- Disenchant

    -- Engineering (+ Gnomish/Goblin specs)
    [4036]  = R .. "profession-engineering",
    [4037]  = R .. "profession-engineering",
    [4038]  = R .. "profession-engineering",
    [12656] = R .. "profession-engineering",
    --[20219] = R .. "profession-engineering",     -- Gnomish
    --[20222] = R .. "profession-engineering",     -- Goblin

    -- Herbalism (+ Find Herbs)
    [2366]  = R .. "profession-herbalism",
    [2368]  = R .. "profession-herbalism",
    [3570]  = R .. "profession-herbalism",
    [11993] = R .. "profession-herbalism",
    [2383]  = R .. "profession-herbalism",       -- Find Herbs

    -- Leatherworking (+ Dragonscale/Elemental/Tribal specs)
    [2108]  = R .. "profession-leatherworking",
    [3104]  = R .. "profession-leatherworking",
    [3811]  = R .. "profession-leatherworking",
    [10662] = R .. "profession-leatherworking",
    --[10656] = R .. "profession-leatherworking", -- Dragonscale
    --[10658] = R .. "profession-leatherworking", -- Elemental
    --[10660] = R .. "profession-leatherworking", -- Tribal

    -- Mining (+ Smelting, Find Minerals)
    [2575]  = R .. "profession-mining",
    [2576]  = R .. "profession-mining",
    [3564]  = R .. "profession-mining",
    [10248] = R .. "profession-mining",
    --[2656]  = R .. "profession-mining",          -- Smelting (shared w/ Blacksmithing)
    --[2580]  = R .. "profession-mining",          -- Find Minerals

    -- Skinning
    [8613]  = R .. "profession-skinning",
    [8617]  = R .. "profession-skinning",
    [8618]  = R .. "profession-skinning",
    [10768] = R .. "profession-skinning",

    -- Tailoring
    [3908]  = R .. "profession-tailoring",
    [3909]  = R .. "profession-tailoring",
    [3910]  = R .. "profession-tailoring",
    [12180] = R .. "profession-tailoring",

    -- Cooking
    [2550]  = R .. "profession-cooking",
    [3102]  = R .. "profession-cooking",
    [3413]  = R .. "profession-cooking",
    [18260] = R .. "profession-cooking",

    -- First Aid
    [3273]  = R .. "profession-firstaid",
    [3274]  = R .. "profession-firstaid",
    [7924]  = R .. "profession-firstaid",
    [10846] = R .. "profession-firstaid",

    -- Fishing
    [7620]  = R .. "profession-fishing",
    [7731]  = R .. "profession-fishing",
    [7732]  = R .. "profession-fishing",
    [18248] = R .. "profession-fishing",
}

for id, tex in pairs(SPELL_ICON_OVERRIDES) do
    MUI_IconOverrides:SetSpellOverride(id, tex)
end
