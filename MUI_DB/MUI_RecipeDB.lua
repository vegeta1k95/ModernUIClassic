-- MUI_RecipeDB: hand-written per-profession recipe metadata keyed by
-- spellID. spellIDs are stable across locales, so this table never needs
-- translation. Fields per entry:
--
--   * category — list-grouping bucket (e.g. "Bracer", "Weapon", "Rods").
--                Optional; entries without a category fall back to native
--                tradeskill order (no per-profession grouping). When even
--                one entry in a profession has a category, all entries in
--                that profession are bucketed (missing → "Other").
--
--   * source   — optional structured table describing where the recipe is
--                obtained. Either a single entry (table with `kind`) or a
--                list of entries (multiple acquisition paths). The
--                TradeSkill overlay renders one tooltip line per entry on
--                hover of the "Recipe is not known" indicator.
--                Supported kinds:
--                  trainer       — { npc? }                  Taught by trainer (any if no npc)
--                  trainerManual — { item }                  Manual sold by any profession trainer
--                  vendor        — { npc, item? } | { npcA, npcH, item? }
--                                                             Sold by a specific NPC. Use
--                                                             { npcA, npcH } when Alliance and
--                                                             Horde have separate vendors and no
--                                                             shared neutral alternative exists —
--                                                             the renderer picks by player faction.
--                  drop          — { npc?, zone?, item? }    Drops from a single NPC (npc), or
--                                                             from many creatures in one zone
--                                                             (zone area-id, no npc)
--                  quest         — { quest, item? }          Quest reward
--                  reputation    — { faction, standing?, item? }  Faction quartermaster
--                  worldDrop     — { item? }                 Random world drop
--                npc/item/quest IDs link MUI_NpcDB / MUI_ItemDB / MUI_QuestDB
--                so the tooltip can pull localized names + zones.
--
--   * reagents — list of { itemId, count } pairs. Required so the recipe
--                can be displayed in the recipe frame WITHOUT a learned
--                native row (i.e. for the "Unlearned" section).
--
--   * skillrange — { orange, yellow, green, grey } skill thresholds for
--                the difficulty colouring used by the list rows. Required
--                alongside reagents for inclusion in the "Unlearned"
--                section. Recipes lacking either field are kept hidden
--                from the unlearned list (they can still carry source /
--                category metadata for the learned-recipe presentation).
--
--   * output   — { itemId, count } describing what the recipe creates.
--                Required for the recipe-frame icon + quality border +
--                hover-tooltip on the icon when the recipe is unlearned
--                (GetSpellInfo/GetSpellTexture in Era return a generic
--                crafting placeholder for every tradeskill spell — only
--                useable via GetItemInfo on the produced item). `count`
--                defaults to 1; values > 1 are stamped over the icon
--                like for learned recipes' multi-produce numbers.
--
-- Enchanting list is curated from vanilla 1.x — trainer recipes + world-
-- drop recipes + reputation recipes. Recipes added only in TBC+ are
-- intentionally excluded.

object "RecipeDB" {

    Get = function(self, profKey)
        return self._data and self._data[profKey]
    end;

    _data = {

    ALCHEMY         = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  2330] = { category = "Potion", source = { kind = "trainer" }, output = { 118, 1 }, reagents = { {765, 1}, {2447, 1}, {3371, 1} }, skillrange = {   1,  55,  75,  95 } },  -- Minor Healing Potion
        [  2329] = { category = "Elixir", source = { kind = "trainer" }, output = { 2454, 1 }, reagents = { {765, 1}, {2449, 1}, {3371, 1} }, skillrange = {   1,  55,  75,  95 } },  -- Elixir of Lion's Strength
        [  7183] = { category = "Elixir", source = { kind = "trainer" }, output = { 5997, 1 }, reagents = { {765, 2}, {3371, 1} }, skillrange = {   1,  55,  75,  95 } },  -- Elixir of Minor Defense
        [  3170] = { category = "Elixir", source = { kind = "trainer" }, output = { 3382, 1 }, reagents = { {2447, 1}, {2449, 2}, {3371, 1} }, skillrange = {  15,  60,  80, 100 } },  -- Weak Troll's Blood Potion
        [  2331] = { category = "Potion", source = { kind = "trainer" }, output = { 2455, 1 }, reagents = { {765, 1}, {785, 1}, {3371, 1} }, skillrange = {  25,  65,  85, 105 } },  -- Minor Mana Potion
        [  2332] = { category = "Potion", source = { kind = "trainer" }, output = { 2456, 1 }, reagents = { {785, 2}, {2447, 1}, {3371, 1} }, skillrange = {  40,  70,  90, 110 } },  -- Minor Rejuvenation Potion
        [  2334] = { category = "Elixir", source = { kind = "trainer" }, output = { 2458, 1 }, reagents = { {2447, 1}, {2449, 2}, {3371, 1} }, skillrange = {  50,  80, 100, 120 } },  -- Elixir of Minor Fortitude
        [  3230] = { category = "Elixir", source = { kind = "worldDrop", item = 2553 }, output = { 2457, 1 }, reagents = { {765, 1}, {2452, 1}, {3371, 1} }, skillrange = {  50,  80, 100, 120 } },  -- Elixir of Minor Agility
        [  4508] = { category = "Potion", source = { kind = "quest", item = 4597, quest = 429 }, output = { 4596, 1 }, reagents = { {2447, 1}, {3164, 1}, {3371, 1} }, skillrange = {  50,  80, 100, 120 } },  -- Discolored Healing Potion
        [  2337] = { category = "Potion", source = { kind = "trainer" }, output = { 858, 1 }, reagents = { {118, 1}, {2450, 1} }, skillrange = {  55,  85, 105, 125 } },  -- Lesser Healing Potion
        [  2335] = { category = "Potion", source = { kind = "worldDrop", item = 2555 }, output = { 2459, 1 }, reagents = { {2450, 1}, {2452, 1}, {3371, 1} }, skillrange = {  60,  90, 110, 130 } },  -- Swiftness Potion
        [  6617] = { category = "Potion", source = { kind = "vendor", npc = 1669, item = 5640 }, output = { 5631, 1 }, reagents = { {2450, 1}, {3371, 1}, {5635, 1} }, skillrange = {  60,  90, 110, 130 } },  -- Rage Potion
        [  7836] = { category = "Reagent", source = { kind = "trainer" }, output = { 6370, 1 }, reagents = { {3371, 1}, {6358, 2} }, skillrange = {  80,  80,  90, 100 } },  -- Blackmouth Oil
        [  3171] = { category = "Elixir", source = { kind = "trainer" }, output = { 3383, 1 }, reagents = { {785, 1}, {2450, 2}, {3371, 1} }, skillrange = {  90, 120, 140, 160 } },  -- Elixir of Wisdom
        [  7179] = { category = "Elixir", source = { kind = "trainer" }, output = { 5996, 1 }, reagents = { {3371, 1}, {3820, 1}, {6370, 2} }, skillrange = {  90, 120, 140, 160 } },  -- Elixir of Water Breathing
        [  8240] = { category = "Elixir", source = { kind = "drop", item = 6663 }, output = { 6662, 1 }, reagents = { {2449, 1}, {3371, 1}, {6522, 1} }, skillrange = {  90, 120, 140, 160 } },  -- Elixir of Giant Growth
        [  7255] = { category = "Potion", source = { kind = "vendor", npc = 3134, item = 6053 }, output = { 6051, 1 }, reagents = { {2452, 1}, {2453, 1}, {3371, 1} }, skillrange = { 100, 130, 150, 170 } },  -- Holy Protection Potion
        [  7841] = { category = "Potion", source = { kind = "trainer" }, output = { 6372, 1 }, reagents = { {2452, 1}, {3371, 1}, {6370, 1} }, skillrange = { 100, 130, 150, 170 } },  -- Swim Speed Potion
        [  3447] = { category = "Potion", source = { kind = "trainer" }, output = { 929, 1 }, reagents = { {2450, 1}, {2453, 1}, {3372, 1} }, skillrange = { 110, 135, 155, 175 } },  -- Healing Potion
        [  3172] = { category = "Oil", source = { kind = "worldDrop", item = 3393 }, output = { 3384, 1 }, reagents = { {785, 3}, {3355, 1}, {3371, 1} }, skillrange = { 110, 135, 155, 175 } },  -- Minor Magic Resistance Potion
        [  3173] = { category = "Potion", source = { kind = "trainer" }, output = { 3385, 1 }, reagents = { {785, 1}, {3371, 1}, {3820, 1} }, skillrange = { 120, 145, 165, 185 } },  -- Lesser Mana Potion
        [  3174] = { category = "Potion", source = { kind = "worldDrop", item = 3394 }, output = { 3386, 1 }, reagents = { {1288, 1}, {2453, 1}, {3372, 1} }, skillrange = { 120, 145, 165, 185 } },  -- Elixir of Poison Resistance
        [  3176] = { category = "Elixir", source = { kind = "trainer" }, output = { 3388, 1 }, reagents = { {2450, 2}, {2453, 2}, {3372, 1} }, skillrange = { 125, 150, 170, 190 } },  -- Strong Troll's Blood Potion
        [  3177] = { category = "Elixir", source = { kind = "trainer" }, output = { 3389, 1 }, reagents = { {3355, 1}, {3372, 1}, {3820, 1} }, skillrange = { 130, 155, 175, 195 } },  -- Elixir of Defense
        [  7837] = { category = "Reagent", source = { kind = "trainer" }, output = { 6371, 1 }, reagents = { {3371, 1}, {6359, 2} }, skillrange = { 130, 150, 160, 170 } },  -- Fire Oil
        [  7256] = { category = "Potion", source = { kind = "vendor", npcA = 3956, npcH = 2393, item = 6054 }, output = { 6048, 1 }, reagents = { {3356, 1}, {3369, 1}, {3372, 1} }, skillrange = { 135, 160, 180, 200 } },  -- Shadow Protection Potion
        [  2333] = { category = "Elixir", source = { kind = "worldDrop", item = 3396 }, output = { 3390, 1 }, reagents = { {2452, 1}, {3355, 1}, {3372, 1} }, skillrange = { 140, 165, 185, 205 } },  -- Elixir of Lesser Agility
        [  7845] = { category = "Elixir", source = { kind = "trainer" }, output = { 6373, 1 }, reagents = { {3356, 1}, {3372, 1}, {6371, 2} }, skillrange = { 140, 165, 185, 205 } },  -- Elixir of Firepower
        [  3188] = { category = "Elixir", source = { kind = "worldDrop", item = 6211 }, output = { 3391, 1 }, reagents = { {2449, 1}, {3356, 1}, {3372, 1} }, skillrange = { 150, 175, 195, 215 } },  -- Elixir of Ogre's Strength
        [  6624] = { category = "Potion", source = { kind = "vendor", npcA = 4226, npcH = 3348, item = 5642 }, output = { 5634, 1 }, reagents = { {3372, 1}, {3820, 1}, {6370, 2} }, skillrange = { 150, 175, 195, 215 } },  -- Free Action Potion
        [  7181] = { category = "Potion", source = { kind = "trainer" }, output = { 1710, 1 }, reagents = { {3356, 1}, {3357, 1}, {3372, 1} }, skillrange = { 155, 175, 195, 215 } },  -- Greater Healing Potion
        [  3452] = { category = "Potion", source = { kind = "trainer" }, output = { 3827, 1 }, reagents = { {3356, 1}, {3372, 1}, {3820, 1} }, skillrange = { 160, 180, 200, 220 } },  -- Mana Potion
        [  3449] = { category = "Weapon Coating", source = { kind = "vendor", npc = 2481, item = 6068 }, output = { 3824, 1 }, reagents = { {3369, 4}, {3372, 1}, {3818, 4} }, skillrange = { 165, 190, 210, 230 } },  -- Shadow Oil
        [  3448] = { category = "Potion", source = { kind = "trainer" }, output = { 3823, 1 }, reagents = { {3355, 1}, {3372, 1}, {3818, 1} }, skillrange = { 165, 185, 205, 225 } },  -- Lesser Invisibility Potion
        [  7257] = { category = "Potion", source = { kind = "vendor", npcA = 2380, npcH = 4083, item = 6055 }, output = { 6049, 1 }, reagents = { {3372, 1}, {4402, 1}, {6371, 1} }, skillrange = { 165, 210, 230, 250 } },  -- Fire Protection Potion
        [  6618] = { category = "Potion", source = { kind = "vendor", npcA = 4226, npcH = 3335, item = 5643 }, output = { 5633, 1 }, reagents = { {3356, 1}, {3372, 1}, {5637, 1} }, skillrange = { 175, 195, 215, 235 } },  -- Great Rage Potion
        [  3450] = { category = "Elixir", source = { kind = "trainer" }, output = { 3825, 1 }, reagents = { {3355, 1}, {3372, 1}, {3821, 1} }, skillrange = { 175, 195, 215, 235 } },  -- Elixir of Fortitude
        [  3451] = { category = "Elixir", source = { kind = "worldDrop", item = 3831 }, output = { 3826, 1 }, reagents = { {2453, 1}, {3357, 1}, {3372, 1} }, skillrange = { 180, 200, 220, 240 } },  -- Mighty Troll's Blood Potion
        [ 11449] = { category = "Elixir", source = { kind = "trainer" }, output = { 8949, 1 }, reagents = { {3372, 1}, {3820, 1}, {3821, 1} }, skillrange = { 185, 205, 225, 245 } },  -- Elixir of Agility
        [ 21923] = { category = "Elixir", source = { kind = "worldDrop", item = 17709 }, output = { 17708, 1 }, reagents = { {3358, 1}, {3372, 1}, {3819, 2} }, skillrange = { 190, 210, 230, 250 } },  -- Elixir of Frost Power
        [  7258] = { category = "Potion", source = { kind = "vendor", npc = 2848, item = 6056 }, output = { 6050, 1 }, reagents = { {3372, 1}, {3819, 1}, {3821, 1} }, skillrange = { 190, 205, 225, 245 } },  -- Frost Protection Potion
        [  7259] = { category = "Potion", source = { kind = "vendor", npc = 2848, item = 6057 }, output = { 6052, 1 }, reagents = { {3357, 1}, {3372, 1}, {3820, 1} }, skillrange = { 190, 210, 230, 250 } },  -- Nature Protection Potion
        [ 11450] = { category = "Elixir", source = { kind = "trainer" }, output = { 8951, 1 }, reagents = { {3355, 1}, {3372, 1}, {3821, 1} }, skillrange = { 195, 215, 235, 255 } },  -- Elixir of Greater Defense
        [  3453] = { category = "Elixir", source = { kind = "worldDrop", item = 3832 }, output = { 3828, 1 }, reagents = { {3358, 1}, {3372, 1}, {3818, 1} }, skillrange = { 195, 215, 235, 255 } },  -- Elixir of Detect Lesser Invisibility
        [  3454] = { category = "Weapon Coating", source = { kind = "vendor", npc = 2480, item = 14634 }, output = { 3829, 1 }, reagents = { {3358, 4}, {3372, 1}, {3819, 2} }, skillrange = { 200, 220, 240, 260 } },  -- Frost Oil
        [ 12609] = { category = "Elixir", source = { kind = "trainer" }, output = { 10592, 1 }, reagents = { {3372, 1}, {3818, 1}, {3821, 1} }, skillrange = { 200, 220, 240, 260 } },  -- Catseye Elixir
        [ 11451] = { category = "Oil", source = { kind = "trainer" }, output = { 8956, 1 }, reagents = { {3821, 1}, {4625, 1}, {8925, 1} }, skillrange = { 205, 220, 240, 260 } },  -- Oil of Immolation
        [ 11448] = { category = "Potion", source = { kind = "trainer" }, output = { 6149, 1 }, reagents = { {3358, 1}, {3372, 1}, {3821, 1} }, skillrange = { 205, 220, 240, 260 } },  -- Greater Mana Potion
        [ 11456] = { category = "Reagent", source = { kind = "drop", item = 10644 }, output = { 9061, 1 }, reagents = { {3372, 1}, {4625, 1}, {9260, 1} }, skillrange = { 210, 225, 245, 265 } },  -- Goblin Rocket Fuel
        [ 11453] = { category = "Oil", source = { kind = "worldDrop", item = 9293 }, output = { 9036, 1 }, reagents = { {3358, 1}, {8831, 1}, {8925, 1} }, skillrange = { 210, 225, 245, 265 } },  -- Magic Resistance Potion
        [ 11457] = { category = "Potion", source = { kind = "trainer" }, output = { 3928, 1 }, reagents = { {3358, 1}, {8838, 1}, {8925, 1} }, skillrange = { 215, 230, 250, 270 } },  -- Superior Healing Potion
        [ 11452] = { category = "Potion", source = { kind = "quest", quest = 2203 }, output = { 9030, 1 }, reagents = { {3821, 1}, {7067, 1}, {8925, 1} }, skillrange = { 215, 225, 245, 265 } },  -- Restorative Potion
        [  4942] = { category = "Potion", source = { kind = "quest", item = 4624, quest = 715 }, output = { 4623, 1 }, reagents = { {3372, 1}, {3821, 1}, {3858, 1} }, skillrange = { 215, 230, 250, 270 } },  -- Lesser Stoneshield Potion
        [ 22808] = { category = "Elixir", source = { kind = "trainer" }, output = { 18294, 1 }, reagents = { {7972, 1}, {8831, 2}, {8925, 1} }, skillrange = { 215, 230, 250, 270 } },  -- Elixir of Greater Water Breathing
        [ 11479] = { category = "Trade Goods", source = { kind = "vendor", npc = 5594, item = 9304 }, output = { 3577, 1 }, reagents = { {3575, 1} }, skillrange = { 225, 240, 260, 280 } },  -- Transmute: Iron to Gold
        [ 11480] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 6037, 1 }, reagents = { {3860, 1} }, skillrange = { 225, 240, 260, 280 } },  -- Transmute: Mithril to Truesilver
        [ 11458] = { category = "Potion", source = { kind = "worldDrop", item = 9294 }, output = { 9144, 1 }, reagents = { {8153, 1}, {8831, 1}, {8925, 1} }, skillrange = { 225, 240, 260, 280 } },  -- Wildvine Potion
        [ 11459] = { category = "Trade Goods", source = { kind = "vendor", npc = 5594, item = 9303 }, output = { 9149, 1 }, reagents = { {3575, 4}, {4625, 4}, {8831, 4}, {9262, 1} }, skillrange = { 225, 240, 260, 280 } },  -- Philosophers' Stone
        [ 11460] = { category = "Elixir", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 9154, 1 }, reagents = { {8836, 1}, {8925, 1} }, skillrange = { 230, 245, 265, 285 } },  -- Elixir of Detect Undead
        [ 15833] = { category = "Potion", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 12190, 1 }, reagents = { {8831, 3}, {8925, 1} }, skillrange = { 230, 245, 265, 285 } },  -- Dreamless Sleep Potion
        [ 11461] = { category = "Elixir", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 9155, 1 }, reagents = { {3821, 1}, {8839, 1}, {8925, 1} }, skillrange = { 235, 250, 270, 290 } },  -- Arcane Elixir
        [ 11465] = { category = "Elixir", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 9179, 1 }, reagents = { {3358, 1}, {8839, 1}, {8925, 1} }, skillrange = { 235, 250, 270, 290 } },  -- Elixir of Greater Intellect
        [ 11464] = { category = "Potion", source = { kind = "worldDrop", item = 9295 }, output = { 9172, 1 }, reagents = { {8838, 1}, {8845, 1}, {8925, 1} }, skillrange = { 235, 250, 270, 290 } },  -- Invisibility Potion
        [ 11466] = { category = "Elixir", source = { kind = "drop", zone = 28, item = 9296 }, output = { 9088, 1 }, reagents = { {8836, 1}, {8839, 1}, {8925, 1} }, skillrange = { 240, 255, 275, 295 } },  -- Gift of Arthas
        [ 11467] = { category = "Elixir", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 9187, 1 }, reagents = { {3821, 1}, {8838, 1}, {8925, 1} }, skillrange = { 240, 255, 275, 295 } },  -- Elixir of Greater Agility
        [ 11468] = { category = "Elixir", source = { kind = "worldDrop", item = 9297 }, output = { 9197, 1 }, reagents = { {8831, 3}, {8925, 1} }, skillrange = { 240, 255, 275, 295 } },  -- Elixir of Dream Vision
        [ 11473] = { category = "Trade Goods", source = { kind = "vendor", npcA = 8157, npcH = 8158, item = 9302 }, output = { 9210, 1 }, reagents = { {4342, 1}, {8845, 2}, {8925, 1} }, skillrange = { 245, 260, 280, 300 } },  -- Ghost Dye
        [ 11472] = { category = "Elixir", source = { kind = "worldDrop", item = 9298 }, output = { 9206, 1 }, reagents = { {8838, 1}, {8846, 1}, {8925, 1} }, skillrange = { 245, 260, 280, 300 } },  -- Elixir of Giants
        [ 17551] = { category = "Reagent", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 13423, 1 }, reagents = { {3372, 1}, {13422, 1} }, skillrange = { 250, 250, 255, 260 } },  -- Stonescale Oil
        [ 11477] = { category = "Elixir", source = { kind = "vendor", npcA = 8178, npcH = 8177, item = 9300 }, output = { 9224, 1 }, reagents = { {8845, 1}, {8846, 1}, {8925, 1} }, skillrange = { 250, 265, 285, 305 } },  -- Elixir of Demonslaying
        [ 11476] = { category = "Elixir", source = { kind = "vendor", npcA = 1313, npcH = 4610, item = 9301 }, output = { 9264, 1 }, reagents = { {8845, 3}, {8925, 1} }, skillrange = { 250, 265, 285, 305 } },  -- Elixir of Shadow Power
        [ 11478] = { category = "Elixir", source = { kind = "vendor", npcA = 7948, npcH = 1386 }, output = { 9233, 1 }, reagents = { {8846, 2}, {8925, 1} }, skillrange = { 250, 265, 285, 305 } },  -- Elixir of Detect Demon
        [ 26277] = { category = "Elixir", source = { kind = "drop", zone = 51, item = 21547 }, output = { 21546, 1 }, reagents = { {4625, 3}, {6371, 3}, {8925, 1} }, skillrange = { 250, 265, 285, 305 } },  -- Elixir of Greater Firepower
        [  3175] = { category = "Potion", source = { kind = "worldDrop", item = 3395 }, output = { 3387, 1 }, reagents = { {8839, 2}, {8845, 1}, {8925, 1} }, skillrange = { 250, 275, 295, 315 } },  -- Limited Invulnerability Potion
        [ 17552] = { category = "Potion", source = { kind = "drop", npc = 7027, zone = 46, item = 13476 }, output = { 13442, 1 }, reagents = { {8846, 3}, {8925, 1} }, skillrange = { 255, 270, 290, 310 } },  -- Mighty Rage Potion
        [ 17553] = { category = "Potion", source = { kind = "vendor", npcA = 4226, npcH = 4610, item = 13477 }, output = { 13443, 1 }, reagents = { {8838, 2}, {8839, 2}, {8925, 1} }, skillrange = { 260, 275, 295, 315 } },  -- Superior Mana Potion
        [ 17554] = { category = "Elixir", source = { kind = "vendor", npcA = 5178, npcH = 3348, item = 13478 }, output = { 13445, 1 }, reagents = { {8838, 1}, {8925, 1}, {13423, 2} }, skillrange = { 265, 280, 300, 320 } },  -- Elixir of Superior Defense
        [ 17555] = { category = "Elixir", source = { kind = "drop", npc = 9451, zone = 139, item = 13479 }, output = { 13447, 1 }, reagents = { {8925, 1}, {13463, 1}, {13466, 2} }, skillrange = { 270, 285, 305, 325 } },  -- Elixir of the Sages
        [ 17560] = { category = "Reagent", source = { kind = "vendor", npc = 9499, item = 13483 }, output = { 7076, 1 }, reagents = { {7078, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Fire to Earth
        [ 17559] = { category = "Reagent", source = { kind = "reputation", item = 13482, faction = "Argent Dawn", standing = "Honored" }, output = { 7078, 1 }, reagents = { {7082, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Air to Fire
        [ 17562] = { category = "Reagent", source = { kind = "vendor", npc = 11278, item = 13485 }, output = { 7082, 1 }, reagents = { {7080, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Water to Air
        [ 17561] = { category = "Reagent", source = { kind = "reputation", item = 13484, faction = "Timbermaw Hold", standing = "Friendly" }, output = { 7080, 1 }, reagents = { {7076, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Earth to Water
        [ 17563] = { category = "Reagent", source = { kind = "worldDrop", item = 13486 }, output = { 7080, 1 }, reagents = { {12808, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Undeath to Water
        [ 17564] = { category = "Reagent", source = { kind = "worldDrop", item = 13487 }, output = { 12808, 1 }, reagents = { {7080, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Water to Undeath
        [ 17565] = { category = "Reagent", source = { kind = "worldDrop", item = 13488 }, output = { 7076, 1 }, reagents = { {12803, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Life to Earth
        [ 17566] = { category = "Reagent", source = { kind = "worldDrop", item = 13489 }, output = { 12803, 1 }, reagents = { {7076, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Earth to Life
        [ 17187] = { category = "Trade Goods", source = { kind = "vendor", npc = 5594, item = 12958 }, output = { 12360, 1 }, reagents = { {12359, 1}, {12363, 1} }, skillrange = { 275, 275, 282, 290 } },  -- Transmute: Arcanite
        [ 17556] = { category = "Potion", source = { kind = "vendor", npc = 11188, item = 13480 }, output = { 13446, 1 }, reagents = { {8925, 1}, {13464, 2}, {13465, 1} }, skillrange = { 275, 290, 310, 330 } },  -- Major Healing Potion
        [ 24365] = { category = "Elixir", source = { kind = "reputation", item = 20011, faction = "Zandalar Tribe", standing = "Revered" }, output = { 20007, 1 }, reagents = { {8925, 1}, {13463, 1}, {13466, 2} }, skillrange = { 275, 290, 310, 330 } },  -- Mageblood Potion
        [ 24366] = { category = "Potion", source = { kind = "reputation", item = 20012, faction = "Zandalar Tribe", standing = "Friendly" }, output = { 20002, 1 }, reagents = { {8925, 1}, {13463, 2}, {13464, 1} }, skillrange = { 275, 290, 310, 330 } },  -- Greater Dreamless Sleep Potion
        [ 17557] = { category = "Elixir", source = { kind = "quest", item = 13481, quest = 5150 }, output = { 13453, 1 }, reagents = { {8846, 2}, {8925, 1}, {13466, 2} }, skillrange = { 275, 290, 310, 330 } },  -- Elixir of Brute Force
        [ 17571] = { category = "Elixir", source = { kind = "worldDrop", item = 13491 }, output = { 13452, 1 }, reagents = { {8925, 1}, {13465, 2}, {13466, 2} }, skillrange = { 280, 295, 315, 335 } },  -- Elixir of the Mongoose
        [ 17570] = { category = "Potion", source = { kind = "worldDrop", item = 13490 }, output = { 13455, 1 }, reagents = { {8925, 1}, {10620, 1}, {13423, 3} }, skillrange = { 280, 295, 315, 335 } },  -- Greater Stoneshield Potion
        [ 24367] = { category = "Potion", source = { kind = "reputation", item = 20013, faction = "Zandalar Tribe", standing = "Exalted" }, output = { 20008, 1 }, reagents = { {8925, 1}, {10286, 2}, {13465, 2}, {13467, 2} }, skillrange = { 285, 300, 320, 340 } },  -- Living Action Potion
        [ 17573] = { category = "Elixir", source = { kind = "worldDrop", item = 13493 }, output = { 13454, 1 }, reagents = { {8925, 1}, {13463, 3}, {13465, 1} }, skillrange = { 285, 300, 320, 340 } },  -- Greater Arcane Elixir
        [ 17572] = { category = "Potion", source = { kind = "worldDrop", item = 13492 }, output = { 13462, 1 }, reagents = { {8925, 1}, {13466, 2}, {13467, 2} }, skillrange = { 285, 300, 320, 340 } },  -- Purification Potion
        [ 17577] = { category = "Potion", source = { kind = "drop", npc = 7437, zone = 618, item = 13497 }, output = { 13461, 1 }, reagents = { {8925, 1}, {11176, 1}, {13463, 1} }, skillrange = { 290, 305, 325, 345 } },  -- Greater Arcane Protection Potion
        [ 24368] = { category = "Elixir", source = { kind = "reputation", item = 20014, faction = "Zandalar Tribe", standing = "Honored" }, output = { 20004, 1 }, reagents = { {8846, 1}, {8925, 1}, {13466, 2} }, skillrange = { 290, 305, 325, 345 } },  -- Major Troll's Blood Potion
        [ 17578] = { category = "Potion", source = { kind = "drop", zone = 139, item = 13499 }, output = { 13459, 1 }, reagents = { {3824, 1}, {8925, 1}, {13463, 1} }, skillrange = { 290, 305, 325, 345 } },  -- Greater Shadow Protection Potion
        [ 17574] = { category = "Potion", source = { kind = "drop", zone = 1583, item = 13494 }, output = { 13457, 1 }, reagents = { {7068, 1}, {8925, 1}, {13463, 1} }, skillrange = { 290, 305, 325, 345 } },  -- Greater Fire Protection Potion
        [ 17575] = { category = "Potion", source = { kind = "drop", npc = 7428, zone = 618, item = 13495 }, output = { 13456, 1 }, reagents = { {7070, 1}, {8925, 1}, {13463, 1} }, skillrange = { 290, 305, 325, 345 } },  -- Greater Frost Protection Potion
        [ 17576] = { category = "Potion", source = { kind = "drop", zone = 28, item = 13496 }, output = { 13458, 1 }, reagents = { {7067, 1}, {8925, 1}, {13463, 1} }, skillrange = { 290, 305, 325, 345 } },  -- Greater Nature Protection Potion
        [ 17580] = { category = "Potion", source = { kind = "vendor", npc = 11278, item = 13501 }, output = { 13444, 1 }, reagents = { {8925, 1}, {13463, 3}, {13467, 2} }, skillrange = { 295, 310, 330, 350 } },  -- Major Mana Potion
        [ 17637] = { category = "Flask", source = { kind = "drop", npc = 10508, zone = 2057, item = 13521 }, output = { 13512, 1 }, reagents = { {8925, 1}, {13463, 30}, {13465, 10}, {13468, 1} }, skillrange = { 300, 315, 322, 330 } },  -- Flask of Supreme Power
        [ 25146] = { category = "Reagent", source = { kind = "reputation", item = 20761, faction = "Thorium Brotherhood", standing = "Friendly" }, output = { 7068, 3 }, reagents = { {7077, 1} }, skillrange = { 300, 301, 305, 310 } },  -- Transmute: Elemental Fire
        [ 17635] = { category = "Flask", source = { kind = "drop", npc = 10363, zone = 1583, item = 13519 }, output = { 13510, 1 }, reagents = { {8846, 30}, {8925, 1}, {13423, 10}, {13468, 1} }, skillrange = { 300, 315, 322, 330 } },  -- Flask of the Titans
        [ 22732] = { category = "Potion", source = { kind = "drop", zone = 2717, item = 18257 }, output = { 18253, 1 }, reagents = { {10286, 1}, {13463, 4}, {13464, 4}, {18256, 1} }, skillrange = { 300, 310, 320, 330 } },  -- Major Rejuvenation Potion
        [ 17634] = { category = "Potion", source = { kind = "worldDrop", item = 13518 }, output = { 13506, 1 }, reagents = { {8925, 1}, {13423, 30}, {13465, 10}, {13468, 1} }, skillrange = { 300, 315, 322, 330 } },  -- Flask of Petrification
        [ 17636] = { category = "Flask", source = { kind = "drop", npc = 10813, zone = 2017, item = 13520 }, output = { 13511, 1 }, reagents = { {8925, 1}, {13463, 30}, {13467, 10}, {13468, 1} }, skillrange = { 300, 315, 322, 330 } },  -- Flask of Distilled Wisdom
        [ 17638] = { category = "Flask", source = { kind = "drop", npc = 10339, item = 13522 }, output = { 13513, 1 }, reagents = { {8925, 1}, {13465, 10}, {13467, 30}, {13468, 1} }, skillrange = { 300, 315, 322, 330 } },  -- Flask of Chromatic Resistance
        [ 24266] = { category = "Other", source = { kind = "drop", zone = 1977 }, output = { 19931, 3 }, reagents = { {12804, 6}, {12938, 1}, {13468, 1}, {19943, 1} }, skillrange = { 315, 315, 322, 330 } },  -- Gurubashi Mojo Madness

    },
    BLACKSMITHING   = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  2662] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2852, 1 }, reagents = { {2840, 4} }, skillrange = {   1,  50,  70,  90 } },  -- Copper Chain Pants
        [  2663] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2853, 1 }, reagents = { {2840, 2} }, skillrange = {   1,  20,  40,  60 } },  -- Copper Bracers
        [ 12260] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 10421, 1 }, reagents = { {2840, 4} }, skillrange = {   1,  15,  35,  55 } },  -- Rough Copper Vest
        [  2660] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 2862, 1 }, reagents = { {2835, 1} }, skillrange = {   1,  15,  35,  55 } },  -- Rough Sharpening Stone
        [  3115] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 3239, 1 }, reagents = { {2589, 1}, {2835, 1} }, skillrange = {   1,  15,  35,  55 } },  -- Rough Weightstone
        [  2737] = { category = "Mace", source = { kind = "trainer" }, output = { 2844, 1 }, reagents = { {2589, 2}, {2840, 6}, {2880, 1} }, skillrange = {  15,  55,  75,  95 } },  -- Copper Mace
        [  2738] = { category = "Axe", source = { kind = "trainer" }, output = { 2845, 1 }, reagents = { {2589, 2}, {2840, 6}, {2880, 1} }, skillrange = {  20,  60,  80, 100 } },  -- Copper Axe
        [  3319] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3469, 1 }, reagents = { {2840, 8} }, skillrange = {  20,  60,  80, 100 } },  -- Copper Chain Boots
        [  3320] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3470, 1 }, reagents = { {2835, 2} }, skillrange = {  25,  45,  65,  85 } },  -- Rough Grinding Stone
        [  2739] = { category = "Sword", source = { kind = "trainer" }, output = { 2847, 1 }, reagents = { {2589, 2}, {2840, 6}, {2880, 1} }, skillrange = {  25,  65,  85, 105 } },  -- Copper Shortsword
        [  8880] = { category = "Dagger", source = { kind = "trainer" }, output = { 7166, 1 }, reagents = { {2318, 1}, {2840, 6}, {2880, 1}, {3470, 1} }, skillrange = {  30,  70,  90, 110 } },  -- Copper Dagger
        [  9983] = { category = "Sword", source = { kind = "trainer" }, output = { 7955, 1 }, reagents = { {2318, 1}, {2840, 10}, {2880, 2}, {3470, 1} }, skillrange = {  30,  70,  90, 110 } },  -- Copper Claymore
        [  3293] = { category = "Axe", source = { kind = "trainer" }, output = { 3488, 1 }, reagents = { {774, 2}, {2318, 2}, {2840, 12}, {2880, 2}, {3470, 2} }, skillrange = {  35,  75,  95, 115 } },  -- Copper Battle Axe
        [  2661] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2851, 1 }, reagents = { {2840, 6} }, skillrange = {  35,  75,  95, 115 } },  -- Copper Chain Belt
        [  3321] = { category = "Mail Armor", source = { kind = "quest", item = 3609, quest = 1578 }, output = { 3471, 1 }, reagents = { {774, 1}, {2840, 8}, {3470, 2} }, skillrange = {  35,  75,  95, 115 } },  -- Copper Chain Vest
        [  3323] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3472, 1 }, reagents = { {2840, 8}, {3470, 2} }, skillrange = {  40,  80, 100, 120 } },  -- Runed Copper Gauntlets
        [  3324] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3473, 1 }, reagents = { {2321, 2}, {2840, 8}, {3470, 3} }, skillrange = {  45,  85, 105, 125 } },  -- Runed Copper Pants
        [  3325] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3610 }, output = { 3474, 1 }, reagents = { {774, 1}, {818, 1}, {2840, 8} }, skillrange = {  60, 100, 120, 140 } },  -- Gemmed Copper Gauntlets
        [  3116] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 3240, 1 }, reagents = { {2592, 1}, {2836, 1} }, skillrange = {  65,  65,  72,  80 } },  -- Coarse Weightstone
        [  7408] = { category = "Mace", source = { kind = "trainer" }, output = { 6214, 1 }, reagents = { {2318, 2}, {2840, 12}, {2880, 2} }, skillrange = {  65, 105, 125, 145 } },  -- Heavy Copper Maul
        [  2665] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 2863, 1 }, reagents = { {2836, 1} }, skillrange = {  65,  65,  72,  80 } },  -- Coarse Sharpening Stone
        [  2666] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2857, 1 }, reagents = { {2840, 10} }, skillrange = {  70, 110, 130, 150 } },  -- Runed Copper Belt
        [  3294] = { category = "Axe", source = { kind = "trainer" }, output = { 3489, 1 }, reagents = { {2318, 2}, {2840, 10}, {2842, 2}, {2880, 2}, {3470, 2} }, skillrange = {  70, 110, 130, 150 } },  -- Thick War Axe
        [  3326] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3478, 1 }, reagents = { {2836, 2} }, skillrange = {  75,  75,  87, 100 } },  -- Coarse Grinding Stone
        [  2667] = { category = "Mail Armor", source = { kind = "worldDrop", item = 2881 }, output = { 2864, 1 }, reagents = { {1210, 1}, {2840, 12}, {3470, 2} }, skillrange = {  80, 120, 140, 160 } },  -- Runed Copper Breastplate
        [  2664] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2854, 1 }, reagents = { {2840, 10}, {3470, 3} }, skillrange = {  90, 115, 127, 140 } },  -- Runed Copper Bracers
        [  3292] = { category = "Sword", source = { kind = "trainer" }, output = { 3487, 1 }, reagents = { {818, 2}, {2319, 2}, {2840, 14}, {2880, 2} }, skillrange = {  95, 135, 155, 175 } },  -- Heavy Copper Broadsword
        [  7817] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 6350, 1 }, reagents = { {2841, 6}, {3470, 6} }, skillrange = {  95, 125, 140, 155 } },  -- Rough Bronze Boots
        [  8367] = { category = "Mail Armor", source = { kind = "quest", item = 6735, quest = 1618 }, output = { 6731, 1 }, reagents = { {818, 2}, {2840, 16}, {3470, 3} }, skillrange = { 100, 140, 160, 180 } },  -- Ironforge Breastplate
        [  7818] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 6338, 1 }, reagents = { {2842, 1}, {3470, 2} }, skillrange = { 100, 105, 107, 110 } },  -- Silver Rod
        [ 19666] = { category = "Other", source = { kind = "trainer" }, output = { 15869, 2 }, reagents = { {2842, 1}, {3470, 1} }, skillrange = { 100, 100, 110, 120 } },  -- Silver Skeleton Key
        [  2668] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2865, 1 }, reagents = { {2841, 6} }, skillrange = { 105, 145, 160, 175 } },  -- Rough Bronze Leggings
        [  2670] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2866, 1 }, reagents = { {2841, 7} }, skillrange = { 105, 145, 160, 175 } },  -- Rough Bronze Cuirass
        [  3491] = { category = "Dagger", source = { kind = "trainer" }, output = { 3848, 1 }, reagents = { {818, 1}, {2319, 1}, {2841, 6}, {2880, 4}, {3470, 2} }, skillrange = { 105, 135, 150, 165 } },  -- Big Bronze Knife
        [  6517] = { category = "Dagger", source = { kind = "trainer" }, output = { 5540, 1 }, reagents = { {2841, 6}, {3466, 1}, {3478, 2}, {5498, 2} }, skillrange = { 110, 140, 155, 170 } },  -- Pearl-handled Dagger
        [  2740] = { category = "Mace", source = { kind = "trainer" }, output = { 2848, 1 }, reagents = { {2319, 1}, {2841, 6}, {2880, 4} }, skillrange = { 110, 140, 155, 170 } },  -- Bronze Mace
        [  3328] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3480, 1 }, reagents = { {1210, 1}, {2841, 5}, {3478, 1} }, skillrange = { 110, 140, 155, 170 } },  -- Rough Bronze Shoulders
        [  2741] = { category = "Axe", source = { kind = "trainer" }, output = { 2849, 1 }, reagents = { {2319, 1}, {2841, 7}, {2880, 4} }, skillrange = { 115, 145, 160, 175 } },  -- Bronze Axe
        [  2742] = { category = "Sword", source = { kind = "trainer" }, output = { 2850, 1 }, reagents = { {2319, 2}, {2841, 5}, {2880, 4} }, skillrange = { 120, 150, 165, 180 } },  -- Bronze Shortsword
        [  2672] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2868, 1 }, reagents = { {2841, 5}, {3478, 2} }, skillrange = { 120, 150, 165, 180 } },  -- Patterned Bronze Bracers
        [  3337] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3486, 1 }, reagents = { {2838, 3} }, skillrange = { 125, 125, 137, 150 } },  -- Heavy Grinding Stone
        [  3330] = { category = "Mail Armor", source = { kind = "worldDrop", item = 2882 }, output = { 3481, 1 }, reagents = { {2841, 8}, {2842, 2}, {3478, 2} }, skillrange = { 125, 155, 170, 185 } },  -- Silvered Bronze Shoulders
        [  3295] = { category = "Dagger", source = { kind = "worldDrop", item = 2883 }, output = { 3490, 1 }, reagents = { {1210, 2}, {2319, 2}, {2459, 1}, {2841, 4}, {3466, 1}, {3478, 2} }, skillrange = { 125, 155, 170, 185 } },  -- Deadly Bronze Poniard
        [  9985] = { category = "Mace", source = { kind = "trainer" }, output = { 7956, 1 }, reagents = { {2319, 1}, {2841, 8}, {3466, 1} }, skillrange = { 125, 155, 170, 185 } },  -- Bronze Warhammer
        [  2674] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 2871, 1 }, reagents = { {2838, 1} }, skillrange = { 125, 125, 132, 140 } },  -- Heavy Sharpening Stone
        [  3117] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 3241, 1 }, reagents = { {2592, 1}, {2838, 1} }, skillrange = { 125, 125, 132, 140 } },  -- Heavy Weightstone
        [  2673] = { category = "Mail Armor", source = { kind = "worldDrop", item = 5578 }, output = { 2869, 1 }, reagents = { {1705, 1}, {2841, 10}, {2842, 2}, {3478, 2} }, skillrange = { 130, 160, 175, 190 } },  -- Silvered Bronze Breastplate
        [  3331] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3482, 1 }, reagents = { {2841, 6}, {2842, 1}, {3478, 2} }, skillrange = { 130, 160, 175, 190 } },  -- Silvered Bronze Boots
        [  9986] = { category = "Sword", source = { kind = "trainer" }, output = { 7957, 1 }, reagents = { {2319, 2}, {2841, 12}, {3466, 2} }, skillrange = { 130, 160, 175, 190 } },  -- Bronze Greatsword
        [  3296] = { category = "Mace", source = { kind = "trainer" }, output = { 3491, 1 }, reagents = { {1206, 1}, {1210, 1}, {2319, 2}, {2841, 8}, {3466, 1}, {3478, 2} }, skillrange = { 130, 160, 175, 190 } },  -- Heavy Bronze Mace
        [  3333] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3483, 1 }, reagents = { {2841, 8}, {2842, 1}, {3478, 2} }, skillrange = { 135, 165, 180, 195 } },  -- Silvered Bronze Gauntlets
        [  9987] = { category = "Axe", source = { kind = "trainer" }, output = { 7958, 1 }, reagents = { {2319, 2}, {2841, 14}, {3466, 1} }, skillrange = { 135, 165, 180, 195 } },  -- Bronze Battle Axe
        [  6518] = { category = "Mace", source = { kind = "worldDrop", item = 5543 }, output = { 5541, 1 }, reagents = { {2319, 2}, {2841, 10}, {3466, 1}, {3478, 2}, {5500, 1} }, skillrange = { 140, 170, 185, 200 } },  -- Iridescent Hammer
        [  3334] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3611 }, output = { 3484, 1 }, reagents = { {1705, 2}, {2605, 1}, {3478, 2}, {3575, 4} }, skillrange = { 145, 175, 190, 205 } },  -- Green Iron Boots
        [  3297] = { category = "Mace", source = { kind = "worldDrop", item = 3608 }, output = { 3492, 1 }, reagents = { {1705, 2}, {2319, 2}, {3391, 1}, {3466, 2}, {3478, 2}, {3575, 6} }, skillrange = { 145, 175, 190, 205 } },  -- Mighty Iron Hammer
        [  2675] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 2870, 1 }, reagents = { {1206, 2}, {1705, 2}, {2841, 20}, {2842, 4}, {5500, 2} }, skillrange = { 145, 175, 190, 205 } },  -- Shining Silver Breastplate
        [  8768] = { category = "Reagent", source = { kind = "trainer" }, output = { 7071, 2 }, reagents = { {3575, 1} }, skillrange = { 150, 150, 152, 155 } },  -- Iron Buckle
        [ 14379] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 11128, 1 }, reagents = { {3478, 2}, {3577, 1} }, skillrange = { 150, 155, 157, 160 } },  -- Golden Rod
        [  3336] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3612 }, output = { 3485, 1 }, reagents = { {2605, 1}, {3478, 2}, {3575, 4}, {5498, 2} }, skillrange = { 150, 180, 195, 210 } },  -- Green Iron Gauntlets
        [  7221] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 6044 }, output = { 6042, 1 }, reagents = { {3478, 4}, {3575, 6} }, skillrange = { 150, 180, 195, 210 } },  -- Iron Shield Spike
        [ 19667] = { category = "Other", source = { kind = "trainer" }, output = { 15870, 2 }, reagents = { {3486, 1}, {3577, 1} }, skillrange = { 150, 150, 160, 170 } },  -- Golden Skeleton Key
        [  3506] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3842, 1 }, reagents = { {2605, 1}, {3486, 1}, {3575, 8} }, skillrange = { 155, 180, 192, 205 } },  -- Green Iron Leggings
        [ 12259] = { category = "Mail Armor", source = { kind = "worldDrop", item = 10424 }, output = { 10423, 1 }, reagents = { {2841, 12}, {2842, 4}, {3478, 2} }, skillrange = { 155, 180, 192, 205 } },  -- Silvered Bronze Leggings
        [  3494] = { category = "Mace", source = { kind = "vendor", npc = 9179, item = 10858 }, output = { 3851, 1 }, reagents = { {2842, 4}, {3466, 2}, {3486, 1}, {3575, 8}, {4234, 2} }, skillrange = { 155, 180, 192, 205 } },  -- Solid Iron Maul
        [  3504] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3870 }, output = { 3840, 1 }, reagents = { {2605, 1}, {3486, 1}, {3575, 7} }, skillrange = { 160, 185, 197, 210 } },  -- Green Iron Shoulders
        [  9811] = { category = "Mail Armor", source = { kind = "quest", item = 7978, quest = 2752 }, output = { 7913, 1 }, reagents = { {1210, 2}, {3486, 2}, {3575, 8}, {5635, 4} }, skillrange = { 160, 185, 197, 210 } },  -- Barbaric Iron Shoulders
        [  9813] = { category = "Mail Armor", source = { kind = "quest", item = 7979, quest = 2751 }, output = { 7914, 1 }, reagents = { {3486, 4}, {3575, 20} }, skillrange = { 160, 185, 197, 210 } },  -- Barbaric Iron Breastplate
        [  3492] = { category = "Sword", source = { kind = "vendor", npc = 2843, item = 12162 }, output = { 3849, 1 }, reagents = { {1705, 2}, {3466, 2}, {3486, 1}, {3575, 6}, {4234, 3} }, skillrange = { 160, 185, 197, 210 } },  -- Hardened Iron Shortsword
        [  3501] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3835, 1 }, reagents = { {2605, 1}, {3575, 6} }, skillrange = { 165, 190, 202, 215 } },  -- Green Iron Bracers
        [  7222] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 6045 }, output = { 6043, 1 }, reagents = { {1705, 1}, {3478, 2}, {3575, 4} }, skillrange = { 165, 190, 202, 215 } },  -- Iron Counterweight
        [  3507] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3872 }, output = { 3843, 1 }, reagents = { {3486, 1}, {3575, 10}, {3577, 2} }, skillrange = { 170, 195, 207, 220 } },  -- Golden Scale Leggings
        [  3495] = { category = "Mace", source = { kind = "worldDrop", item = 3867 }, output = { 3852, 1 }, reagents = { {1705, 2}, {3466, 2}, {3486, 2}, {3575, 10}, {3577, 4}, {4234, 2} }, skillrange = { 170, 195, 207, 220 } },  -- Golden Iron Destroyer
        [  3502] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3836, 1 }, reagents = { {2605, 1}, {3575, 12}, {3864, 1} }, skillrange = { 170, 195, 207, 220 } },  -- Green Iron Helm
        [  3505] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3871 }, output = { 3841, 1 }, reagents = { {3486, 1}, {3577, 2}, {3859, 6} }, skillrange = { 175, 200, 212, 225 } },  -- Golden Scale Shoulders
        [  9814] = { category = "Mail Armor", source = { kind = "quest", item = 7980, quest = 2754 }, output = { 7915, 1 }, reagents = { {3575, 10}, {5635, 2}, {5637, 2} }, skillrange = { 175, 200, 212, 225 } },  -- Barbaric Iron Helm
        [  3493] = { category = "Sword", source = { kind = "worldDrop", item = 3866 }, output = { 3850, 1 }, reagents = { {1529, 2}, {3466, 2}, {3486, 2}, {3575, 8}, {4234, 3} }, skillrange = { 175, 200, 212, 225 } },  -- Jade Serpentblade
        [  3508] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 3844, 1 }, reagents = { {1206, 2}, {1529, 2}, {3486, 4}, {3575, 20}, {4255, 1} }, skillrange = { 180, 205, 217, 230 } },  -- Green Iron Hauberk
        [  9818] = { category = "Mail Armor", source = { kind = "quest", item = 7981, quest = 2753 }, output = { 7916, 1 }, reagents = { {818, 4}, {3486, 2}, {3575, 12}, {5637, 4} }, skillrange = { 180, 205, 217, 230 } },  -- Barbaric Iron Boots
        [ 15972] = { category = "Dagger", source = { kind = "trainer" }, output = { 12259, 1 }, reagents = { {1206, 1}, {3466, 2}, {3859, 10}, {4234, 1}, {7067, 1} }, skillrange = { 180, 205, 217, 230 } },  -- Glinting Steel Dagger
        [  3496] = { category = "Sword", source = { kind = "vendor", npc = 2482, item = 12163 }, output = { 3853, 1 }, reagents = { {1705, 3}, {3466, 2}, {3486, 2}, {3859, 8}, {4234, 3} }, skillrange = { 180, 205, 217, 230 } },  -- Moonsteel Broadsword
        [  7223] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 6040, 1 }, reagents = { {3486, 2}, {3859, 5} }, skillrange = { 185, 210, 222, 235 } },  -- Golden Scale Bracers
        [  9820] = { category = "Mail Armor", source = { kind = "quest", item = 7982, quest = 2755 }, output = { 7917, 1 }, reagents = { {3486, 3}, {3575, 14}, {5637, 2} }, skillrange = { 185, 210, 222, 235 } },  -- Barbaric Iron Gloves
        [  3498] = { category = "Axe", source = { kind = "vendor", npc = 2483, item = 12164 }, output = { 3855, 1 }, reagents = { {3466, 2}, {3486, 2}, {3575, 14}, {3577, 4}, {4234, 2} }, skillrange = { 185, 210, 222, 235 } },  -- Massive Iron Axe
        [  3513] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3874 }, output = { 3846, 1 }, reagents = { {1705, 1}, {3486, 2}, {3859, 8}, {3864, 1} }, skillrange = { 185, 210, 222, 235 } },  -- Polished Steel Boots
        [  3503] = { category = "Mail Armor", source = { kind = "vendor", npc = 5411, item = 6047 }, output = { 3837, 1 }, reagents = { {3486, 2}, {3577, 2}, {3859, 8} }, skillrange = { 190, 215, 227, 240 } },  -- Golden Scale Coif
        [ 21913] = { category = "Axe", source = { kind = "worldDrop", item = 17706 }, output = { 17704, 1 }, reagents = { {3829, 1}, {3859, 10}, {4234, 2}, {7069, 2}, {7070, 2} }, skillrange = { 190, 215, 227, 240 } },  -- Edge of Winter
        [ 15973] = { category = "Dagger", source = { kind = "worldDrop", item = 12261 }, output = { 12260, 1 }, reagents = { {3577, 4}, {3859, 10}, {4234, 2}, {7068, 2} }, skillrange = { 190, 215, 227, 240 } },  -- Searing Golden Blade
        [  7224] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 6046 }, output = { 6041, 1 }, reagents = { {3486, 2}, {3859, 8}, {4234, 4} }, skillrange = { 190, 215, 227, 240 } },  -- Steel Weapon Chain
        [  3511] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3873 }, output = { 3845, 1 }, reagents = { {1529, 2}, {3486, 4}, {3577, 2}, {3859, 12} }, skillrange = { 195, 220, 232, 245 } },  -- Golden Scale Cuirass
        [  9920] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 7966, 1 }, reagents = { {7912, 4} }, skillrange = { 200, 200, 205, 210 } },  -- Solid Grinding Stone
        [  3515] = { category = "Mail Armor", source = { kind = "worldDrop", item = 3875 }, output = { 3847, 1 }, reagents = { {3486, 4}, {3577, 4}, {3859, 10}, {3864, 1} }, skillrange = { 200, 225, 237, 250 } },  -- Golden Scale Boots
        [ 11454] = { category = "Reagent", source = { kind = "drop", item = 10713 }, output = { 9060, 1 }, reagents = { {3577, 1}, {3860, 5}, {6037, 1} }, skillrange = { 200, 225, 237, 250 } },  -- Inlaid Mithril Cylinder
        [  3497] = { category = "Sword", source = { kind = "worldDrop", item = 3868 }, output = { 3854, 1 }, reagents = { {1529, 2}, {3466, 2}, {3486, 2}, {3829, 1}, {3859, 8}, {4234, 4} }, skillrange = { 200, 225, 237, 250 } },  -- Frost Tiger Blade
        [  3500] = { category = "Axe", source = { kind = "worldDrop", item = 3869 }, output = { 3856, 1 }, reagents = { {3466, 2}, {3486, 3}, {3824, 1}, {3859, 10}, {3864, 2}, {4234, 3} }, skillrange = { 200, 225, 237, 250 } },  -- Shadow Crescent Axe
        [  9916] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 7963, 1 }, reagents = { {3486, 3}, {3859, 16} }, skillrange = { 200, 225, 237, 250 } },  -- Steel Breastplate
        [ 14380] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 11144, 1 }, reagents = { {3486, 1}, {6037, 1} }, skillrange = { 200, 205, 207, 210 } },  -- Truesilver Rod
        [ 19668] = { category = "Other", source = { kind = "trainer" }, output = { 15871, 2 }, reagents = { {6037, 1}, {7966, 1} }, skillrange = { 200, 200, 210, 220 } },  -- Truesilver Skeleton Key
        [  9921] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 7965, 1 }, reagents = { {4306, 1}, {7912, 1} }, skillrange = { 200, 200, 205, 210 } },  -- Solid Weightstone
        [  9918] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 7964, 1 }, reagents = { {7912, 1} }, skillrange = { 200, 200, 205, 210 } },  -- Solid Sharpening Stone
        [  9926] = { category = "Plate Armor", source = { kind = "trainer" }, output = { 7918, 1 }, reagents = { {3860, 8}, {4234, 6} }, skillrange = { 205, 225, 235, 245 } },  -- Heavy Mithril Shoulder
        [  9928] = { category = "Plate Armor", source = { kind = "trainer" }, output = { 7919, 1 }, reagents = { {3860, 6}, {4338, 4} }, skillrange = { 205, 225, 235, 245 } },  -- Heavy Mithril Gauntlet
        [ 11643] = { category = "Mail Armor", source = { kind = "quest", item = 9367, quest = 2758 }, output = { 9366, 1 }, reagents = { {3486, 4}, {3577, 4}, {3859, 10}, {3864, 1} }, skillrange = { 205, 225, 235, 245 } },  -- Golden Scale Gauntlets
        [  9933] = { category = "Plate Armor", source = { kind = "worldDrop", item = 7975 }, output = { 7921, 1 }, reagents = { {1705, 2}, {3860, 10} }, skillrange = { 210, 230, 240, 250 } },  -- Heavy Mithril Pants
        [  9993] = { category = "Axe", source = { kind = "trainer" }, output = { 7941, 1 }, reagents = { {3860, 12}, {3864, 2}, {4234, 4}, {7966, 1} }, skillrange = { 210, 235, 247, 260 } },  -- Heavy Mithril Axe
        [  9931] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 7920, 1 }, reagents = { {3860, 12} }, skillrange = { 210, 230, 240, 250 } },  -- Mithril Scale Pants
        [  9935] = { category = "Plate Armor", source = { kind = "trainer" }, output = { 7922, 1 }, reagents = { {3859, 14}, {7966, 1} }, skillrange = { 215, 235, 245, 255 } },  -- Steel Plate Helm
        [  9937] = { category = "Mail Armor", source = { kind = "vendor", npcA = 8161, npcH = 8176, item = 7995 }, output = { 7924, 1 }, reagents = { {3860, 8}, {3864, 2} }, skillrange = { 215, 235, 245, 255 } },  -- Mithril Scale Bracers
        [  9939] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 7976 }, output = { 7967, 1 }, reagents = { {3860, 4}, {6037, 2}, {7966, 4} }, skillrange = { 215, 235, 245, 255 } },  -- Mithril Shield Spike
        [  9945] = { category = "Plate Armor", source = { kind = "quest", item = 7983, quest = 2761 }, output = { 7926, 1 }, reagents = { {3860, 12}, {6037, 1}, {7909, 1}, {7966, 1} }, skillrange = { 220, 240, 250, 260 } },  -- Ornate Mithril Pants
        [  9950] = { category = "Plate Armor", source = { kind = "quest", item = 7984, quest = 2762 }, output = { 7927, 1 }, reagents = { {3860, 10}, {4338, 6}, {6037, 1}, {7966, 1} }, skillrange = { 220, 240, 250, 260 } },  -- Ornate Mithril Gloves
        [  9995] = { category = "Axe", source = { kind = "worldDrop", item = 7992 }, output = { 7942, 1 }, reagents = { {3860, 16}, {4304, 4}, {7909, 2}, {7966, 1} }, skillrange = { 220, 245, 257, 270 } },  -- Blue Glittering Axe
        [  9952] = { category = "Plate Armor", source = { kind = "quest", item = 7985, quest = 2763 }, output = { 7928, 1 }, reagents = { {3860, 12}, {4304, 6}, {6037, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Ornate Mithril Shoulders
        [  9997] = { category = "Sword", source = { kind = "worldDrop", item = 8029 }, output = { 7943, 1 }, reagents = { {3860, 14}, {4304, 2}, {6037, 4}, {7966, 1} }, skillrange = { 225, 250, 262, 275 } },  -- Wicked Mithril Blade
        [  9954] = { category = "Plate Armor", source = { kind = "trainer" }, output = { 7938, 1 }, reagents = { {3860, 10}, {3864, 3}, {5966, 1}, {6037, 8}, {7909, 3}, {7966, 2} }, skillrange = { 225, 245, 255, 265 } },  -- Truesilver Gauntlets
        [ 10001] = { category = "Mace", source = { kind = "vendor", npc = 2836 }, output = { 7945, 1 }, reagents = { {1210, 4}, {3860, 16}, {4304, 2}, {7966, 1}, {7971, 1} }, skillrange = { 230, 255, 267, 280 } },  -- Big Black Mace
        [  9959] = { category = "Plate Armor", source = { kind = "vendor", npc = 2836 }, output = { 7930, 1 }, reagents = { {3860, 16} }, skillrange = { 230, 250, 260, 270 } },  -- Heavy Mithril Breastplate
        [  9961] = { category = "Mail Armor", source = { kind = "vendor", npc = 2836 }, output = { 7931, 1 }, reagents = { {3860, 10}, {4338, 6} }, skillrange = { 230, 250, 260, 270 } },  -- Mithril Coif
        [  9957] = { category = "Mail Armor", source = { kind = "quest", quest = 2756 }, output = { 7929, 1 }, reagents = { {3860, 12}, {7067, 1} }, skillrange = { 230, 250, 260, 270 } },  -- Orcish War Leggings
        [  9968] = { category = "Plate Armor", source = { kind = "vendor", npc = 2836 }, output = { 7933, 1 }, reagents = { {3860, 14}, {4304, 4} }, skillrange = { 235, 255, 265, 275 } },  -- Heavy Mithril Boots
        [ 10003] = { category = "Mace", source = { kind = "vendor", npcA = 11146, npcH = 11178 }, output = { 7954, 1 }, reagents = { {1529, 5}, {3860, 24}, {3864, 5}, {4304, 4}, {6037, 6}, {7075, 4}, {7966, 4} }, skillrange = { 235, 260, 272, 285 } },  -- The Shatterer
        [  9966] = { category = "Mail Armor", source = { kind = "worldDrop", item = 7991 }, output = { 7932, 1 }, reagents = { {3860, 14}, {3864, 4}, {4304, 4} }, skillrange = { 235, 255, 265, 275 } },  -- Mithril Scale Shoulders
        [  9964] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 7989 }, output = { 7969, 1 }, reagents = { {3860, 4}, {7966, 3} }, skillrange = { 235, 255, 265, 275 } },  -- Mithril Spurs
        [ 10005] = { category = "Sword", source = { kind = "worldDrop", item = 7993 }, output = { 7944, 1 }, reagents = { {1206, 2}, {1705, 2}, {3860, 14}, {4338, 2}, {7909, 1}, {7966, 1} }, skillrange = { 240, 265, 277, 290 } },  -- Dazzling Mithril Rapier
        [  9972] = { category = "Plate Armor", source = { kind = "quest", quest = 2773 }, output = { 7935, 1 }, reagents = { {3860, 16}, {6037, 6}, {7077, 1}, {7966, 1} }, skillrange = { 240, 260, 270, 280 } },  -- Ornate Mithril Breastplate
        [  9970] = { category = "Plate Armor", source = { kind = "worldDrop", item = 7990 }, output = { 7934, 1 }, reagents = { {3860, 14}, {7909, 1} }, skillrange = { 245, 255, 265, 275 } },  -- Heavy Mithril Helm
        [  9979] = { category = "Plate Armor", source = { kind = "quest", quest = 2772 }, output = { 7936, 1 }, reagents = { {3860, 14}, {4304, 4}, {6037, 2}, {7909, 1}, {7966, 1} }, skillrange = { 245, 265, 275, 285 } },  -- Ornate Mithril Boots
        [  9980] = { category = "Plate Armor", source = { kind = "quest", quest = 2771 }, output = { 7937, 1 }, reagents = { {3860, 16}, {6037, 2}, {7966, 1}, {7971, 1} }, skillrange = { 245, 265, 275, 285 } },  -- Ornate Mithril Helm
        [ 10007] = { category = "Sword", source = { kind = "vendor", npcA = 11146, npcH = 11178 }, output = { 7961, 1 }, reagents = { {3823, 2}, {3860, 28}, {4304, 2}, {6037, 8}, {7081, 6}, {7909, 6}, {7966, 4} }, skillrange = { 245, 270, 282, 295 } },  -- Phantom Blade
        [ 10009] = { category = "Mace", source = { kind = "worldDrop", item = 8028 }, output = { 7946, 1 }, reagents = { {3860, 18}, {4304, 4}, {7075, 2}, {7966, 1} }, skillrange = { 245, 270, 282, 295 } },  -- Runed Mithril Hammer
        [  9974] = { category = "Plate Armor", source = { kind = "trainer" }, output = { 7939, 1 }, reagents = { {3860, 12}, {6037, 24}, {7910, 4}, {7966, 2}, {7971, 4} }, skillrange = { 245, 265, 275, 285 } },  -- Truesilver Breastplate
        [ 16639] = { category = "Trade Goods", source = { kind = "vendor", npc = 2836 }, output = { 12644, 1 }, reagents = { {12365, 4} }, skillrange = { 250, 255, 257, 260 } },  -- Dense Grinding Stone
        [ 16642] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12682 }, output = { 12405, 1 }, reagents = { {11188, 4}, {12359, 16}, {12361, 1} }, skillrange = { 250, 270, 280, 290 } },  -- Thorium Armor
        [ 16643] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12683 }, output = { 12406, 1 }, reagents = { {11186, 4}, {12359, 12} }, skillrange = { 250, 270, 280, 290 } },  -- Thorium Belt
        [ 16640] = { category = "Weapon Coating", source = { kind = "vendor", npc = 2836 }, output = { 12643, 1 }, reagents = { {12365, 1}, {14047, 1} }, skillrange = { 250, 255, 257, 260 } },  -- Dense Weightstone
        [ 10011] = { category = "Polearm", source = { kind = "vendor", npcA = 11146, npcH = 11178 }, output = { 7959, 1 }, reagents = { {3860, 28}, {4304, 6}, {6037, 10}, {7966, 6}, {7972, 10} }, skillrange = { 250, 275, 287, 300 } },  -- Blight
        [ 16641] = { category = "Weapon Coating", source = { kind = "vendor", npc = 2836 }, output = { 12404, 1 }, reagents = { {12365, 1} }, skillrange = { 250, 255, 257, 260 } },  -- Dense Sharpening Stone
        [ 16644] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12684 }, output = { 12408, 1 }, reagents = { {11184, 4}, {12359, 12} }, skillrange = { 255, 275, 285, 295 } },  -- Thorium Bracers
        [ 10013] = { category = "Dagger", source = { kind = "vendor", npc = 11278, item = 8030 }, output = { 7947, 1 }, reagents = { {3860, 12}, {4304, 2}, {6037, 6}, {7910, 2}, {7966, 1} }, skillrange = { 255, 280, 292, 305 } },  -- Ebon Shiv
        [ 16645] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12685 }, output = { 12416, 1 }, reagents = { {7077, 2}, {12359, 10} }, skillrange = { 260, 280, 290, 300 } },  -- Radiant Belt
        [ 10015] = { category = "Sword", source = { kind = "vendor", npcA = 11146, npcH = 11178 }, output = { 7960, 1 }, reagents = { {3860, 30}, {4304, 6}, {6037, 16}, {7081, 4}, {7910, 6}, {7966, 8} }, skillrange = { 260, 285, 297, 310 } },  -- Truesilver Champion
        [ 16647] = { category = "Plate Armor", source = { kind = "quest", item = 12688, quest = 7653 }, output = { 12424, 1 }, reagents = { {7909, 1}, {8170, 6}, {12359, 22} }, skillrange = { 265, 285, 295, 305 } },  -- Imperial Plate Belt
        [ 16646] = { category = "Plate Armor", source = { kind = "quest", item = 12687, quest = 7659 }, output = { 12428, 1 }, reagents = { {3864, 2}, {8170, 6}, {12359, 24} }, skillrange = { 265, 285, 295, 305 } },  -- Imperial Plate Shoulders
        [ 15292] = { category = "Mace", source = { kind = "drop", npc = 9028, zone = 1584, item = 11610 }, output = { 11608, 1 }, reagents = { {7077, 4}, {11371, 18} }, skillrange = { 265, 285, 295, 305 } },  -- Dark Iron Pulverizer
        [ 16649] = { category = "Plate Armor", source = { kind = "quest", item = 12690, quest = 7655 }, output = { 12425, 1 }, reagents = { {7910, 1}, {12359, 20} }, skillrange = { 270, 290, 300, 310 } },  -- Imperial Plate Bracers
        [ 16648] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12689 }, output = { 12415, 1 }, reagents = { {7077, 2}, {7910, 1}, {12359, 18} }, skillrange = { 270, 290, 300, 310 } },  -- Radiant Breastplate
        [ 15293] = { category = "Mail Armor", source = { kind = "drop", zone = 1584, item = 11614 }, output = { 11606, 1 }, reagents = { {7077, 2}, {11371, 10} }, skillrange = { 270, 290, 300, 310 } },  -- Dark Iron Mail
        [ 16650] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12691 }, output = { 12624, 1 }, reagents = { {8153, 4}, {12359, 40}, {12364, 1}, {12655, 2}, {12803, 4} }, skillrange = { 270, 290, 300, 310 } },  -- Wildthorn Mail
        [ 16969] = { category = "Axe", source = { kind = "vendor", npc = 11278, item = 12819 }, output = { 12773, 1 }, reagents = { {8170, 4}, {12359, 20}, {12644, 2}, {12799, 2} }, skillrange = { 275, 300, 312, 325 } },  -- Ornate Thorium Handaxe
        [ 16970] = { category = "Axe", source = { kind = "quest", item = 12821, quest = 5306 }, output = { 12774, 1 }, reagents = { {7910, 4}, {8170, 4}, {12359, 30}, {12361, 4}, {12644, 2}, {12655, 4} }, skillrange = { 275, 300, 312, 325 } },  -- Dawn's Edge
        [ 15294] = { category = "Axe", source = { kind = "drop", zone = 1584, item = 11611 }, output = { 11607, 1 }, reagents = { {7077, 4}, {11371, 26} }, skillrange = { 275, 295, 305, 315 } },  -- Dark Iron Sunderer
        [ 16651] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 12692 }, output = { 12645, 1 }, reagents = { {7076, 2}, {12359, 4}, {12644, 4} }, skillrange = { 275, 295, 305, 315 } },  -- Thorium Shield Spike
        [ 19669] = { category = "Other", source = { kind = "vendor", npc = 2836 }, output = { 15872, 2 }, reagents = { {12360, 1}, {12644, 1} }, skillrange = { 275, 275, 280, 285 } },  -- Arcanite Skeleton Key
        [ 20201] = { category = "Trade Goods", source = { kind = "vendor", npc = 2836 }, output = { 16206, 1 }, reagents = { {12360, 3}, {12644, 1} }, skillrange = { 275, 275, 280, 285 } },  -- Arcanite Rod
        [ 16652] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12693 }, output = { 12409, 1 }, reagents = { {8170, 8}, {11185, 4}, {12359, 20} }, skillrange = { 280, 300, 310, 320 } },  -- Thorium Boots
        [ 16971] = { category = "Axe", source = { kind = "vendor", npc = 11278, item = 12823 }, output = { 12775, 1 }, reagents = { {8170, 6}, {12359, 40}, {12644, 6} }, skillrange = { 280, 305, 317, 330 } },  -- Huge Thorium Battleaxe
        [ 16973] = { category = "Mace", source = { kind = "quest", item = 12824, quest = 5305 }, output = { 12776, 1 }, reagents = { {8170, 4}, {12359, 20}, {12364, 2}, {12655, 6}, {12804, 4} }, skillrange = { 280, 305, 317, 330 } },  -- Enchanted Battlehammer
        [ 16978] = { category = "Sword", source = { kind = "quest", item = 12825, quest = 5307 }, output = { 12777, 1 }, reagents = { {7077, 4}, {7078, 4}, {12644, 2}, {12655, 10}, {12800, 2} }, skillrange = { 280, 305, 317, 330 } },  -- Blazing Rapier
        [ 15295] = { category = "Plate Armor", source = { kind = "drop", zone = 1584, item = 11615 }, output = { 11605, 1 }, reagents = { {7077, 1}, {11371, 6} }, skillrange = { 280, 300, 310, 320 } },  -- Dark Iron Shoulders
        [ 16653] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12694 }, output = { 12410, 1 }, reagents = { {7910, 1}, {11188, 4}, {12359, 24} }, skillrange = { 280, 300, 310, 320 } },  -- Thorium Helm
        [ 15296] = { category = "Plate Armor", source = { kind = "drop", npc = 9543, zone = 1584, item = 11612 }, output = { 11604, 1 }, reagents = { {7077, 8}, {11371, 20} }, skillrange = { 285, 305, 315, 325 } },  -- Dark Iron Plate
        [ 16654] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12695 }, output = { 12418, 1 }, reagents = { {7077, 4}, {12359, 18} }, skillrange = { 285, 305, 315, 325 } },  -- Radiant Gloves
        [ 16667] = { category = "Plate Armor", source = { kind = "quest", item = 12696, quest = 5127 }, output = { 12628, 1 }, reagents = { {7910, 4}, {12359, 40}, {12361, 4}, {12662, 10} }, skillrange = { 285, 305, 315, 325 } },  -- Demon Forged Breastplate
        [ 16983] = { category = "Mace", source = { kind = "drop", zone = 2017, item = 12827 }, output = { 12781, 1 }, reagents = { {12360, 2}, {12361, 2}, {12364, 1}, {12655, 6}, {12799, 2}, {12804, 4} }, skillrange = { 285, 310, 322, 335 } },  -- Serenity
        [ 16656] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12697 }, output = { 12419, 1 }, reagents = { {7077, 4}, {12359, 14} }, skillrange = { 290, 310, 320, 330 } },  -- Radiant Boots
        [ 16655] = { category = "Plate Armor", source = { kind = "quest", item = 12699, quest = 5124 }, output = { 12631, 1 }, reagents = { {7078, 2}, {7910, 4}, {12359, 20}, {12655, 6} }, skillrange = { 290, 310, 320, 330 } },  -- Fiery Plate Gauntlets
        [ 23628] = { category = "Mail Armor", source = { kind = "reputation", item = 19202, faction = "Timbermaw Hold", standing = "Honored" }, output = { 19043, 1 }, reagents = { {7076, 3}, {12359, 12}, {12803, 3} }, skillrange = { 290, 310, 320, 330 } },  -- Heavy Timbermaw Belt
        [ 16984] = { category = "Mace", source = { kind = "drop", npc = 10119, zone = 46, item = 12828 }, output = { 12792, 1 }, reagents = { {7077, 4}, {7910, 4}, {8170, 4}, {12359, 30} }, skillrange = { 290, 315, 327, 340 } },  -- Volcanic Hammer
        [ 16985] = { category = "Sword", source = { kind = "drop", zone = 2017, item = 12830 }, output = { 12782, 1 }, reagents = { {8170, 4}, {12359, 40}, {12360, 2}, {12361, 2}, {12644, 2}, {12662, 16}, {12808, 8} }, skillrange = { 290, 315, 327, 340 } },  -- Corruption
        [ 16660] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12698 }, output = { 12625, 1 }, reagents = { {7080, 2}, {12359, 20}, {12360, 4}, {12364, 2} }, skillrange = { 290, 310, 320, 330 } },  -- Dawnbringer Shoulders
        [ 23632] = { category = "Plate Armor", source = { kind = "reputation", item = 19203, faction = "Argent Dawn", standing = "Honored" }, output = { 19051, 1 }, reagents = { {6037, 6}, {12359, 8}, {12811, 1} }, skillrange = { 290, 310, 320, 330 } },  -- Girdle of the Dawn
        [ 16657] = { category = "Plate Armor", source = { kind = "quest", item = 12700, quest = 7654 }, output = { 12426, 1 }, reagents = { {7909, 1}, {7910, 1}, {12359, 34} }, skillrange = { 295, 315, 325, 335 } },  -- Imperial Plate Boots
        [ 16658] = { category = "Plate Armor", source = { kind = "quest", item = 12701, quest = 7657 }, output = { 12427, 1 }, reagents = { {7910, 2}, {12359, 34} }, skillrange = { 295, 315, 325, 335 } },  -- Imperial Plate Helm
        [ 20874] = { category = "Plate Armor", source = { kind = "reputation", item = 17051, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 17014, 1 }, reagents = { {11371, 4}, {17010, 2}, {17011, 2} }, skillrange = { 295, 315, 325, 335 } },  -- Dark Iron Bracers
        [ 16659] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12702 }, output = { 12417, 1 }, reagents = { {7077, 4}, {12359, 18} }, skillrange = { 295, 315, 325, 335 } },  -- Radiant Circlet
        [ 16661] = { category = "Mail Armor", source = { kind = "vendor", npc = 11278, item = 12703 }, output = { 12632, 1 }, reagents = { {7080, 4}, {12359, 20}, {12361, 4}, {12655, 4} }, skillrange = { 295, 315, 325, 335 } },  -- Storm Gauntlets
        [ 20872] = { category = "Mail Armor", source = { kind = "reputation", item = 17049, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16989, 1 }, reagents = { {11371, 6}, {17010, 3}, {17011, 3} }, skillrange = { 295, 315, 325, 335 } },  -- Fiery Chain Girdle
        [ 16663] = { category = "Plate Armor", source = { kind = "quest", item = 12705, quest = 7656 }, output = { 12422, 1 }, reagents = { {7910, 2}, {12359, 40} }, skillrange = { 300, 320, 330, 340 } },  -- Imperial Plate Chest
        [ 16730] = { category = "Plate Armor", source = { kind = "quest", item = 12715, quest = 7658 }, output = { 12429, 1 }, reagents = { {7910, 2}, {12359, 44} }, skillrange = { 300, 320, 330, 340 } },  -- Imperial Plate Leggings
        [ 24136] = { category = "Mail Armor", source = { kind = "reputation", item = 19776, faction = "Zandalar Tribe", standing = "Revered" }, output = { 19690, 1 }, reagents = { {7910, 2}, {12359, 20}, {19726, 2}, {19774, 10} }, skillrange = { 300, 320, 330, 340 } },  -- Bloodsoul Breastplate
        [ 24137] = { category = "Mail Armor", source = { kind = "reputation", item = 19777, faction = "Zandalar Tribe", standing = "Honored" }, output = { 19691, 1 }, reagents = { {7910, 1}, {12359, 16}, {19726, 2}, {19774, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Bloodsoul Shoulders
        [ 24138] = { category = "Mail Armor", source = { kind = "reputation", item = 19778, faction = "Zandalar Tribe", standing = "Friendly" }, output = { 19692, 1 }, reagents = { {12359, 12}, {12810, 4}, {19726, 2}, {19774, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Bloodsoul Gauntlets
        [ 24139] = { category = "Plate Armor", source = { kind = "reputation", item = 19779, faction = "Zandalar Tribe", standing = "Revered" }, output = { 19693, 1 }, reagents = { {12359, 20}, {12799, 2}, {19774, 14} }, skillrange = { 300, 320, 330, 340 } },  -- Darksoul Breastplate
        [ 24140] = { category = "Plate Armor", source = { kind = "reputation", item = 19780, faction = "Zandalar Tribe", standing = "Honored" }, output = { 19694, 1 }, reagents = { {12359, 18}, {12799, 2}, {19774, 12} }, skillrange = { 300, 320, 330, 340 } },  -- Darksoul Leggings
        [ 24141] = { category = "Plate Armor", source = { kind = "reputation", item = 19781, faction = "Zandalar Tribe", standing = "Friendly" }, output = { 19695, 1 }, reagents = { {12359, 16}, {12799, 1}, {19774, 10} }, skillrange = { 300, 320, 330, 340 } },  -- Darksoul Shoulders
        [ 20876] = { category = "Plate Armor", source = { kind = "reputation", item = 17052, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 17013, 1 }, reagents = { {11371, 16}, {17010, 4}, {17011, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Dark Iron Leggings
        [ 23636] = { category = "Plate Armor", source = { kind = "reputation", item = 19206, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19148, 1 }, reagents = { {11371, 4}, {17010, 2}, {17011, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Dark Iron Helm
        [ 23637] = { category = "Plate Armor", source = { kind = "reputation", item = 19207, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19164, 1 }, reagents = { {11371, 4}, {11382, 2}, {17010, 5}, {17011, 3}, {17012, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Dark Iron Gauntlets
        [ 24399] = { category = "Plate Armor", source = { kind = "reputation", item = 20040, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 20039, 1 }, reagents = { {11371, 6}, {17010, 3}, {17011, 3}, {17012, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Dark Iron Boots
        [ 28242] = { category = "Plate Armor", source = { kind = "vendor", npc = 16365 }, output = { 22669, 1 }, reagents = { {7080, 4}, {12359, 16}, {12360, 2}, {22682, 7} }, skillrange = { 300, 320, 330, 340 } },  -- Icebane Breastplate
        [ 28243] = { category = "Plate Armor", source = { kind = "vendor", npc = 16365 }, output = { 22670, 1 }, reagents = { {7080, 2}, {12359, 12}, {12360, 2}, {22682, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Icebane Gauntlets
        [ 28244] = { category = "Plate Armor", source = { kind = "vendor", npc = 16365 }, output = { 22671, 1 }, reagents = { {7080, 2}, {12359, 12}, {12360, 2}, {22682, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Icebane Bracers
        [ 16662] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12704 }, output = { 12414, 1 }, reagents = { {11186, 4}, {12359, 26} }, skillrange = { 300, 320, 330, 340 } },  -- Thorium Leggings
        [ 16725] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12713 }, output = { 12420, 1 }, reagents = { {7077, 4}, {12359, 20} }, skillrange = { 300, 320, 330, 340 } },  -- Radiant Leggings
        [ 16664] = { category = "Plate Armor", source = { kind = "drop", npc = 4366, zone = 15, item = 12706 }, output = { 12610, 1 }, reagents = { {3577, 6}, {12359, 20}, {12360, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Plate Shoulders
        [ 16665] = { category = "Plate Armor", source = { kind = "drop", npc = 1836, zone = 28, item = 12707 }, output = { 12611, 1 }, reagents = { {2842, 10}, {12359, 20}, {12360, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Plate Boots
        [ 16731] = { category = "Plate Armor", source = { kind = "drop", zone = 15, item = 12718 }, output = { 12613, 1 }, reagents = { {7910, 1}, {12359, 40}, {12360, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Breastplate
        [ 16732] = { category = "Plate Armor", source = { kind = "drop", npc = 1885, zone = 28, item = 12719 }, output = { 12614, 1 }, reagents = { {7910, 1}, {12359, 40}, {12360, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Plate Leggings
        [ 16745] = { category = "Plate Armor", source = { kind = "quest", item = 12727, quest = 7649 }, output = { 12618, 1 }, reagents = { {7076, 4}, {7080, 4}, {12360, 8}, {12364, 2}, {12655, 24}, {12800, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Enchanted Thorium Breastplate
        [ 16744] = { category = "Plate Armor", source = { kind = "quest", item = 12726, quest = 7650 }, output = { 12619, 1 }, reagents = { {7080, 6}, {12360, 10}, {12361, 2}, {12364, 1}, {12655, 20} }, skillrange = { 300, 320, 330, 340 } },  -- Enchanted Thorium Leggings
        [ 16746] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12728 }, output = { 12641, 1 }, reagents = { {12360, 30}, {12364, 6}, {12655, 30}, {12800, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Invulnerable Mail
        [ 23629] = { category = "Mail Armor", source = { kind = "reputation", item = 19204, faction = "Timbermaw Hold", standing = "Revered" }, output = { 19048, 1 }, reagents = { {7076, 6}, {12360, 4}, {12803, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Heavy Timbermaw Boots
        [ 27589] = { category = "Mail Armor", source = { kind = "drop", npc = 15340, zone = 3428, item = 22220 }, output = { 22194, 1 }, reagents = { {12810, 8}, {13512, 1}, {22202, 24}, {22203, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Black Grasp of the Destroyer
        [ 27588] = { category = "Mail Armor", source = { kind = "reputation", item = 22214, faction = "Cenarion Circle", standing = "Honored" }, output = { 22195, 1 }, reagents = { {12810, 4}, {22202, 14} }, skillrange = { 300, 320, 330, 340 } },  -- Light Obsidian Belt
        [ 27829] = { category = "Plate Armor", source = { kind = "worldDrop", item = 22388 }, output = { 22385, 1 }, reagents = { {7076, 10}, {12360, 12}, {12655, 20}, {13510, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Titanic Leggings
        [ 28461] = { category = "Plate Armor", source = { kind = "reputation", item = 22766, faction = "Cenarion Circle", standing = "Revered" }, output = { 22762, 1 }, reagents = { {12360, 2}, {12655, 12}, {12803, 2}, {19726, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Ironvine Breastplate
        [ 28462] = { category = "Plate Armor", source = { kind = "reputation", item = 22767, faction = "Cenarion Circle", standing = "Honored" }, output = { 22763, 1 }, reagents = { {12655, 8}, {12803, 2}, {19726, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Ironvine Gloves
        [ 28463] = { category = "Plate Armor", source = { kind = "reputation", item = 22768, faction = "Cenarion Circle", standing = "Friendly" }, output = { 22764, 1 }, reagents = { {12655, 6}, {12803, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Ironvine Belt
        [ 16991] = { category = "Axe", source = { kind = "drop", npc = 9736, zone = 1583, item = 12835 }, output = { 12798, 1 }, reagents = { {12359, 40}, {12360, 12}, {12364, 8}, {12644, 2}, {12808, 10}, {12810, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Annihilator
        [ 20897] = { category = "Axe", source = { kind = "reputation", item = 17060, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 17016, 1 }, reagents = { {11371, 18}, {11382, 2}, {12810, 2}, {17011, 12} }, skillrange = { 300, 320, 330, 340 } },  -- Dark Iron Destroyer
        [ 16995] = { category = "Dagger", source = { kind = "drop", npc = 10997, zone = 2017, item = 12839 }, output = { 12783, 1 }, reagents = { {7910, 6}, {12360, 10}, {12644, 4}, {12655, 10}, {12799, 6}, {12800, 6}, {12810, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Heartseeker
        [ 23638] = { category = "Dagger", source = { kind = "reputation", item = 19208, faction = "Thorium Brotherhood", standing = "Exalted" }, output = { 19166, 1 }, reagents = { {11371, 4}, {11382, 1}, {12360, 12}, {17010, 6}, {17011, 3} }, skillrange = { 300, 320, 330, 340 } },  -- Black Amnesty
        [ 16994] = { category = "Axe", source = { kind = "drop", npc = 9596, zone = 1583, item = 12838 }, output = { 12784, 1 }, reagents = { {12360, 20}, {12644, 2}, {12810, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Arcanite Reaper
        [ 16990] = { category = "Sword", source = { kind = "drop", npc = 10899, zone = 1583, item = 12834 }, output = { 12790, 1 }, reagents = { {12360, 15}, {12644, 2}, {12799, 4}, {12800, 8}, {12810, 8}, {12811, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Arcanite Champion
        [ 16993] = { category = "Mace", source = { kind = "drop", npc = 10899, zone = 1583, item = 12837 }, output = { 12794, 1 }, reagents = { {7076, 6}, {12364, 8}, {12655, 20}, {12799, 8}, {12810, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Masterwork Stormhammer
        [ 16988] = { category = "Mace", source = { kind = "drop", npc = 10438, zone = 2017, item = 12833 }, output = { 12796, 1 }, reagents = { {7076, 10}, {12359, 50}, {12360, 15}, {12809, 4}, {12810, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Hammer of the Titans
        [ 16992] = { category = "Sword", source = { kind = "drop", npc = 1844, zone = 28, item = 12836 }, output = { 12797, 1 }, reagents = { {7080, 4}, {12360, 18}, {12361, 8}, {12644, 2}, {12800, 8}, {12810, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Frostguard
        [ 20890] = { category = "Sword", source = { kind = "reputation", item = 17059, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 17015, 1 }, reagents = { {11371, 16}, {11382, 2}, {12810, 2}, {17010, 12} }, skillrange = { 300, 320, 330, 340 } },  -- Dark Iron Reaver
        [ 21161] = { category = "Mace", source = { kind = "quest", item = 18592, quest = 7604 }, output = { 17193, 1 }, reagents = { {7078, 25}, {11371, 20}, {11382, 10}, {12360, 50}, {17010, 10}, {17011, 10}, {17203, 8} }, skillrange = { 300, 325, 337, 350 } },  -- Sulfuron Hammer
        [ 23639] = { category = "Polearm", source = { kind = "reputation", item = 19209, faction = "Thorium Brotherhood", standing = "Exalted" }, output = { 19167, 1 }, reagents = { {11371, 6}, {12360, 16}, {17010, 2}, {17011, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Blackfury
        [ 23652] = { category = "Sword", source = { kind = "reputation", item = 19211, faction = "Thorium Brotherhood", standing = "Exalted" }, output = { 19168, 1 }, reagents = { {11371, 6}, {12360, 10}, {12809, 12}, {17010, 6}, {17011, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Blackguard
        [ 23653] = { category = "Axe", source = { kind = "reputation", item = 19212, faction = "Thorium Brotherhood", standing = "Exalted" }, output = { 19169, 1 }, reagents = { {11371, 12}, {12360, 10}, {12364, 4}, {17010, 5}, {17011, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Nightfall
        [ 23650] = { category = "Mace", source = { kind = "reputation", item = 19210, faction = "Thorium Brotherhood", standing = "Exalted" }, output = { 19170, 1 }, reagents = { {11371, 8}, {12360, 12}, {12800, 4}, {17010, 7}, {17011, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Ebon Hand
        [ 27832] = { category = "Sword", source = { kind = "worldDrop", item = 22389 }, output = { 22383, 1 }, reagents = { {12360, 12}, {12810, 4}, {13512, 2}, {20725, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Sageblade
        [ 27830] = { category = "Mace", source = { kind = "worldDrop", item = 22390 }, output = { 22384, 1 }, reagents = { {11371, 10}, {12360, 15}, {12753, 2}, {12808, 20}, {15417, 10}, {20520, 20} }, skillrange = { 300, 320, 330, 340 } },  -- Persuader
        [ 16742] = { category = "Plate Armor", source = { kind = "quest", item = 12725, quest = 7651 }, output = { 12620, 1 }, reagents = { {7076, 6}, {12360, 6}, {12655, 16}, {12799, 2}, {12800, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Enchanted Thorium Helm
        [ 16724] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12711 }, output = { 12633, 1 }, reagents = { {3577, 6}, {6037, 6}, {12359, 20}, {12655, 4}, {12800, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Whitesoul Helm
        [ 16741] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12720 }, output = { 12639, 1 }, reagents = { {7076, 10}, {12360, 15}, {12361, 4}, {12655, 20}, {12799, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Stronghold Gauntlets
        [ 16729] = { category = "Plate Armor", source = { kind = "worldDrop", item = 12717 }, output = { 12640, 1 }, reagents = { {8146, 40}, {12359, 80}, {12360, 12}, {12361, 10}, {12800, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Lionheart Helm
        [ 27590] = { category = "Mail Armor", source = { kind = "reputation", item = 22221, faction = "Cenarion Circle", standing = "Exalted" }, output = { 22191, 1 }, reagents = { {12800, 4}, {12809, 10}, {12810, 12}, {22202, 36}, {22203, 15} }, skillrange = { 300, 320, 330, 340 } },  -- Obsidian Mail Tunic
        [ 27587] = { category = "Plate Armor", source = { kind = "drop", npc = 15263, zone = 3428, item = 22222 }, output = { 22196, 1 }, reagents = { {7076, 10}, {12364, 4}, {12655, 12}, {22202, 40}, {22203, 18} }, skillrange = { 300, 320, 330, 340 } },  -- Thick Obsidian Breastplate
        [ 27586] = { category = "Shield", source = { kind = "reputation", item = 22219, faction = "Cenarion Circle", standing = "Revered" }, output = { 22198, 1 }, reagents = { {7076, 4}, {12655, 8}, {22202, 24}, {22203, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Jagged Obsidian Shield
        [ 16728] = { category = "Mail Armor", source = { kind = "worldDrop", item = 12716 }, output = { 12636, 1 }, reagents = { {8168, 60}, {12359, 40}, {12364, 2}, {12655, 4}, {12799, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Helm of the Great Chief
        [ 20873] = { category = "Mail Armor", source = { kind = "reputation", item = 17053, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16988, 1 }, reagents = { {11371, 16}, {17010, 4}, {17011, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Fiery Chain Shoulders
        [ 24912] = { category = "Plate Armor", source = { kind = "quest", item = 20553, quest = 8323 }, output = { 20549, 1 }, reagents = { {6037, 6}, {12359, 12}, {12810, 2}, {20520, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Darkrune Gauntlets
        [ 16726] = { category = "Plate Armor", source = { kind = "drop", npc = 4364, zone = 15, item = 12714 }, output = { 12612, 1 }, reagents = { {6037, 2}, {12359, 30}, {12360, 2}, {12364, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Plate Helm
        [ 23633] = { category = "Plate Armor", source = { kind = "reputation", item = 19205, faction = "Argent Dawn", standing = "Revered" }, output = { 19057, 1 }, reagents = { {6037, 10}, {12360, 2}, {12811, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Gloves of the Dawn
        [ 24914] = { category = "Plate Armor", source = { kind = "quest", item = 20554, quest = 8323 }, output = { 20550, 1 }, reagents = { {6037, 10}, {12359, 20}, {20520, 10} }, skillrange = { 300, 320, 330, 340 } },  -- Darkrune Breastplate
        [ 24913] = { category = "Plate Armor", source = { kind = "drop", npc = 15184, zone = 1377, item = 20555 }, output = { 20551, 1 }, reagents = { {6037, 8}, {11754, 1}, {12359, 16}, {20520, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Darkrune Helm
        [ 27585] = { category = "Plate Armor", source = { kind = "reputation", item = 22209, faction = "Cenarion Circle", standing = "Friendly" }, output = { 22197, 1 }, reagents = { {7076, 2}, {12655, 4}, {22202, 14} }, skillrange = { 300, 320, 330, 340 } },  -- Heavy Obsidian Belt
        [ 22757] = { category = "Weapon Coating", source = { kind = "drop", zone = 2717, item = 18264 }, output = { 18262, 1 }, reagents = { {7067, 2}, {12365, 3} }, skillrange = { 300, 300, 310, 320 } },  -- Elemental Sharpening Stone

    },
    ENCHANTING      = {

        -- Reagents + skillrange harvested by tools/recipedb_skill/fetch_recipe_data.py
        -- (wago.tools SpellReagents + SkillLineAbility @ build 1.15.8.67156).
        -- `orange` is 1 for AcquireMethod=1 (auto-learned with profession) and
        -- TrivialSkillLineRankLow otherwise — most trainer-gated recipes have no
        -- orange phase below their yellow threshold.
        -- Source field is hand-authored; trainer = any enchanting trainer.
        -- ZG variants (22xxx / 23799-23804) and a few deprecated vanilla IDs
        -- (3231, 6296, 6476, 8375, 19927, 19932, 23141-23144) have no
        -- SkillLineAbility row in 1.15.x — kept as category-only stubs.

        -- ===== Runed Rods =====
        [7421]  = { category = "Rods", source = { kind = "trainer" }, reagents = { {6217,1}, {10940,1}, {10938,1} }, skillrange = {   1,   5,   7,  10 } },  -- Runed Copper Rod
        [7795]  = { category = "Rods", source = { kind = "trainer" }, reagents = { {6338,1}, {10940,6}, {10939,3}, {1210,1} }, skillrange = { 100, 130, 150, 170 } },  -- Runed Silver Rod
        [13628] = { category = "Rods", source = { kind = "trainer" }, reagents = { {11128,1}, {5500,1}, {11082,2}, {11083,2} }, skillrange = { 150, 175, 195, 215 } },  -- Runed Golden Rod
        [13702] = { category = "Rods", source = { kind = "trainer" }, reagents = { {11144,1}, {7971,1}, {11135,2}, {11137,2} }, skillrange = { 200, 220, 240, 260 } },  -- Runed Truesilver Rod
        [20051] = { category = "Rods", source = { kind = "vendor", npc = 12022, item = 16243 }, reagents = { {16206,1}, {13926,1}, {16204,10}, {16203,4}, {14343,4}, {14344,2} }, skillrange = { 290, 310, 330, 350 } },  -- Runed Arcanite Rod

        -- ===== Bracer =====
        [7418]  = { category = "Bracer", source = { kind = "trainer" }, reagents = { {10940,1} }, skillrange = {   1,  70,  90, 110 } },  -- Minor Health
        [7428]  = { category = "Bracer", source = { kind = "trainer" }, reagents = { {10938,1}, {10940,1} }, skillrange = {   1,  80, 100, 120 } },  -- Minor Deflection
        [7457]  = { category = "Bracer", source = { kind = "trainer" }, reagents = { {10940,3} }, skillrange = {  50, 100, 120, 140 } },  -- Minor Stamina
        [7766]  = { category = "Bracer", source = { kind = "worldDrop", item = 6344 }, reagents = { {10938,2} }, skillrange = {  60, 105, 125, 145 } },  -- Minor Spirit
        [7779]  = { category = "Bracer", source = { kind = "trainer" }, reagents = { {10940,2}, {10939,1} }, skillrange = {  80, 115, 135, 155 } },  -- Minor Agility
        [7782]  = { category = "Bracer", source = { kind = "worldDrop", item = 6347 }, reagents = { {10940,5} }, skillrange = {  80, 115, 135, 155 } },  -- Minor Strength
        [7859]  = { category = "Bracer", source = { kind = "worldDrop", item = 6375 }, reagents = { {10998,2} }, skillrange = { 120, 145, 165, 185 } },  -- Lesser Spirit
        [13501] = { category = "Bracer", source = { kind = "trainer" }, reagents = { {11083,2} }, skillrange = { 130, 155, 175, 195 } },  -- Lesser Stamina
        [13536] = { category = "Bracer", source = { kind = "vendor", npcA = 3954, npcH = 12043, item = 11101 }, reagents = { {11083,2} }, skillrange = { 140, 165, 185, 205 } },  -- Lesser Strength
        [13622] = { category = "Bracer", source = { kind = "trainer" }, reagents = { {11082,2} }, skillrange = { 150, 175, 195, 215 } },  -- Intellect
        [13642] = { category = "Bracer", source = { kind = "trainer" }, reagents = { {11134,1} }, skillrange = { 165, 185, 205, 225 } },  -- Spirit
        [13646] = { category = "Bracer", source = { kind = "vendor", npcA = 2381, npcH = 2821, item = 11163 }, reagents = { {11134,1}, {11083,2} }, skillrange = { 170, 190, 210, 230 } },  -- Deflection
        [13648] = { category = "Bracer", source = { kind = "trainer" }, reagents = { {11083,6} }, skillrange = { 170, 190, 210, 230 } },  -- Stamina
        [13661] = { category = "Bracer", source = { kind = "trainer" }, reagents = { {11137,1} }, skillrange = { 180, 200, 220, 240 } },  -- Strength
        [13822] = { category = "Bracer", source = { kind = "trainer" }, reagents = { {11174,2} }, skillrange = { 210, 230, 250, 270 } },  -- Greater Intellect
        [13846] = { category = "Bracer", source = { kind = "drop", zone = 33, item = 11204 }, reagents = { {11174,3}, {11137,1} }, skillrange = { 220, 240, 260, 280 } },  -- Greater Spirit
        [13931] = { category = "Bracer", source = { kind = "vendor", npcA = 4229, npcH = 989, item = 11223 }, reagents = { {11175,1}, {11176,2} }, skillrange = { 235, 255, 275, 295 } },  -- Greater Deflection
        [13939] = { category = "Bracer", source = { kind = "vendor", npc = 11073 }, reagents = { {11176,2}, {11175,1} }, skillrange = { 240, 260, 280, 300 } },  -- Greater Strength
        [13945] = { category = "Bracer", source = { kind = "worldDrop", item = 11225 }, reagents = { {11176,5} }, skillrange = { 245, 265, 285, 305 } },  -- Greater Stamina (formula drops, Stratholme/Scholo)
        [20008] = { category = "Bracer", source = { kind = "worldDrop", item = 16214 }, reagents = { {16202,3} }, skillrange = { 255, 275, 295, 315 } },  -- Major Intellect
        [20009] = { category = "Bracer", source = { kind = "worldDrop", item = 16218 }, reagents = { {16202,3}, {11176,10} }, skillrange = { 270, 290, 310, 330 } },  -- Superior Spirit
        [20010] = { category = "Bracer", source = { kind = "drop", npc = 7372, zone = 41, item = 16246 }, reagents = { {16204,6}, {16203,6} }, skillrange = { 295, 315, 335, 355 } },  -- Superior Strength
        [20011] = { category = "Bracer", source = { kind = "worldDrop", item = 16251 }, reagents = { {16204,15} }, skillrange = { 300, 320, 340, 360 } },  -- Superior Stamina
        [23801] = { category = "Bracer", source = { kind = "reputation", item = 19446, faction = "Argent Dawn", standing = "Honored" }, reagents = { {16204,16}, {16203,4}, {7080,2} }, skillrange = { 290, 310, 330, 350 } },  -- Mana Regeneration (drops Princess Huhuran, AQ40)
        [23802] = { category = "Bracer", source = { kind = "reputation", item = 19447, faction = "Argent Dawn", standing = "Honored" }, reagents = { {14344,2}, {16204,20}, {16203,4}, {12803,6} }, skillrange = { 300, 320, 340, 360 } },  -- Healing Power (drops Princess Huhuran, AQ40)

        -- ===== Chest =====
        [7420]  = { category = "Chest", source = { kind = "trainer" }, reagents = { {10940,1} }, skillrange = {  15,  70,  90, 110 } },  -- Minor Health
        [7426]  = { category = "Chest", source = { kind = "trainer" }, reagents = { {10940,2}, {10938,1} }, skillrange = {  40,  90, 110, 130 } },  -- Minor Absorption
        [7443]  = { category = "Chest", source = { kind = "vendor", npc = 15419, item = 6342 }, reagents = { {10938,1} }, skillrange = {  20,  80, 100, 120 } },  -- Minor Mana
        [7748]  = { category = "Chest", source = { kind = "trainer" }, reagents = { {10940,2}, {10938,2} }, skillrange = {  60, 105, 125, 145 } },  -- Lesser Health
        [7776]  = { category = "Chest", source = { kind = "vendor", npc = 3346, item = 6346 }, reagents = { {10939,1}, {10938,1} }, skillrange = {  80, 115, 135, 155 } },  -- Lesser Mana
        [7857]  = { category = "Chest", source = { kind = "trainer" }, reagents = { {10940,4}, {10998,1} }, skillrange = { 120, 145, 165, 185 } },  -- Health
        [13538] = { category = "Chest", source = { kind = "trainer" }, reagents = { {10940,2}, {11082,1}, {11084,1} }, skillrange = { 140, 165, 185, 205 } },  -- Lesser Absorption
        [13607] = { category = "Chest", source = { kind = "trainer" }, reagents = { {11082,1}, {10998,2} }, skillrange = { 145, 170, 190, 210 } },  -- Mana
        [13626] = { category = "Chest", source = { kind = "trainer" }, reagents = { {11082,1}, {11083,1}, {11084,1} }, skillrange = { 150, 175, 195, 215 } },  -- Minor Stats
        [13640] = { category = "Chest", source = { kind = "trainer" }, reagents = { {11083,3} }, skillrange = { 160, 180, 200, 220 } },  -- Greater Health
        [13663] = { category = "Chest", source = { kind = "trainer" }, reagents = { {11135,1} }, skillrange = { 185, 205, 225, 245 } },  -- Greater Mana
        [13700] = { category = "Chest", source = { kind = "trainer" }, reagents = { {11135,2}, {11137,2}, {11139,1} }, skillrange = { 200, 220, 240, 260 } },  -- Lesser Stats
        [13858] = { category = "Chest", source = { kind = "trainer" }, reagents = { {11137,6} }, skillrange = { 220, 240, 260, 280 } },  -- Superior Health
        [13917] = { category = "Chest", source = { kind = "vendor", npc = 11073 }, reagents = { {11175,1}, {11174,2} }, skillrange = { 230, 250, 270, 290 } },  -- Superior Mana
        [13941] = { category = "Chest", source = { kind = "vendor", npc = 11073 }, reagents = { {11178,1}, {11176,3}, {11175,2} }, skillrange = { 245, 265, 285, 305 } },  -- Stats (drops Scholomance/AQ20)
        [20025] = { category = "Chest", source = { kind = "worldDrop", item = 16253 }, reagents = { {14344,4}, {16204,15}, {16203,10} }, skillrange = { 300, 320, 340, 360 } },  -- Greater Stats (drops Maleki, Stratholme)
        [20026] = { category = "Chest", source = { kind = "vendor", npc = 11189, item = 16221 }, reagents = { {16204,6}, {14343,1} }, skillrange = { 275, 295, 315, 335 } },  -- Major Health (drops King Gordok, Dire Maul)
        [20028] = { category = "Chest", source = { kind = "worldDrop", item = 16242 }, reagents = { {16203,3}, {14343,1} }, skillrange = { 290, 310, 330, 350 } },  -- Major Mana (drops Dire Maul)

        -- ===== Cloak =====
        [7454]  = { category = "Cloak", source = { kind = "trainer" }, reagents = { {10940,1}, {10938,2} }, skillrange = {  45,  95, 115, 135 } },  -- Minor Resistance
        [7771]  = { category = "Cloak", source = { kind = "trainer" }, reagents = { {10940,3}, {10939,1} }, skillrange = {  70, 110, 130, 150 } },  -- Minor Armor
        [7861]  = { category = "Cloak", source = { kind = "trainer" }, reagents = { {6371,1}, {10998,1} }, skillrange = { 125, 150, 170, 190 } },  -- Lesser Fire Resistance
        [13419] = { category = "Cloak", source = { kind = "vendor", npcA = 3954, npcH = 12043, item = 11039 }, reagents = { {10998,1} }, skillrange = { 110, 135, 155, 175 } },  -- Lesser Agility
        [13421] = { category = "Cloak", source = { kind = "trainer" }, reagents = { {10940,6}, {10978,1} }, skillrange = { 115, 140, 160, 180 } },  -- Lesser Armor
        [13522] = { category = "Cloak", source = { kind = "worldDrop", item = 11098 }, reagents = { {11082,1}, {6048,1} }, skillrange = { 135, 160, 180, 200 } },  -- Greater Shadow Resistance (formula drops)
        [13635] = { category = "Cloak", source = { kind = "trainer" }, reagents = { {11138,1}, {11083,3} }, skillrange = { 155, 175, 195, 215 } },  -- Armor
        [13657] = { category = "Cloak", source = { kind = "trainer" }, reagents = { {11134,1}, {7068,1} }, skillrange = { 175, 195, 215, 235 } },  -- Fire Resistance
        [13746] = { category = "Cloak", source = { kind = "trainer" }, reagents = { {11137,3} }, skillrange = { 205, 225, 245, 265 } },  -- Greater Armor
        [13794] = { category = "Cloak", source = { kind = "trainer" }, reagents = { {11174,1} }, skillrange = { 205, 225, 245, 265 } },  -- Resistance
        [13882] = { category = "Cloak", source = { kind = "worldDrop", item = 11206 }, reagents = { {11174,2} }, skillrange = { 225, 245, 265, 285 } },  -- Lesser Agility (rank 2)
        [20014] = { category = "Cloak", source = { kind = "drop", npc = 5259, zone = 1477, item = 16216 }, reagents = { {16202,2}, {7077,1}, {7075,1}, {7079,1}, {7081,1}, {7972,1} }, skillrange = { 265, 285, 305, 325 } },  -- Greater Resistance (formula drops, BRD)
        [20015] = { category = "Cloak", source = { kind = "vendor", npc = 12022, item = 16224 }, reagents = { {16204,8} }, skillrange = { 285, 305, 325, 345 } },  -- Subtlety (formula drops, Scholomance)
        [25081] = { category = "Cloak", source = { kind = "vendor", npc = 15419, item = 20732 }, reagents = { {20725,3}, {14344,8}, {7078,4} }, skillrange = { 300, 320, 340, 360 } },  -- Greater Fire Resistance (Naxx-era drop)
        [25082] = { category = "Cloak", source = { kind = "vendor", npc = 15419, item = 20733 }, reagents = { {20725,2}, {14344,8}, {12803,4} }, skillrange = { 300, 320, 340, 360 } },  -- Greater Nature Resistance
        [25083] = { category = "Cloak", source = { kind = "drop", zone = 3428, item = 20734 }, reagents = { {20725,3}, {14344,8}, {13468,2} }, skillrange = { 300, 320, 340, 360 } },  -- Stealth
        [25084] = { category = "Cloak", source = { kind = "drop", npc = 15276, zone = 3428, item = 20735 }, reagents = { {20725,4}, {14344,6}, {11754,2} }, skillrange = { 300, 320, 340, 360 } },  -- Subtlety (rank 2, Naxx-era drop)
        [25086] = { category = "Cloak", source = { kind = "drop", zone = 3428, item = 20736 }, reagents = { {20725,3}, {14344,8}, {12809,8} }, skillrange = { 300, 320, 340, 360 } },  -- Dodge

        -- ===== Boots =====
        [7863]  = { category = "Boots", source = { kind = "trainer" }, reagents = { {10940,8} }, skillrange = { 125, 150, 170, 190 } },  -- Minor Stamina
        [7867]  = { category = "Boots", source = { kind = "vendor", npc = 3537, item = 6377 }, reagents = { {10940,6}, {10998,2} }, skillrange = { 125, 150, 170, 190 } },  -- Minor Agility
        [13637] = { category = "Boots", source = { kind = "trainer" }, reagents = { {11083,1}, {11134,1} }, skillrange = { 160, 180, 200, 220 } },  -- Lesser Agility
        [13644] = { category = "Boots", source = { kind = "trainer" }, reagents = { {11083,4} }, skillrange = { 170, 190, 210, 230 } },  -- Lesser Stamina
        [13687] = { category = "Boots", source = { kind = "drop", npc = 92, zone = 3, item = 11167 }, reagents = { {11135,1}, {11134,2} }, skillrange = { 190, 210, 230, 250 } },  -- Lesser Spirit
        [13836] = { category = "Boots", source = { kind = "trainer" }, reagents = { {11137,5} }, skillrange = { 215, 235, 255, 275 } },  -- Stamina
        [13890] = { category = "Boots", source = { kind = "trainer" }, reagents = { {11177,1}, {7909,1}, {11174,1} }, skillrange = { 225, 245, 265, 285 } },  -- Minor Speed (drops Maraudon — Cache of Mau'ari)
        [13935] = { category = "Boots", source = { kind = "vendor", npc = 11073 }, reagents = { {11175,2} }, skillrange = { 235, 255, 275, 295 } },  -- Greater Agility (formula drops, Dire Maul)
        [20020] = { category = "Boots", source = { kind = "worldDrop", item = 16215 }, reagents = { {11176,10} }, skillrange = { 260, 280, 300, 320 } },  -- Greater Stamina (drops Stratholme)
        [20023] = { category = "Boots", source = { kind = "worldDrop", item = 16245 }, reagents = { {16203,8} }, skillrange = { 295, 315, 335, 355 } },  -- Greater Agility (drops Dire Maul)
        [20024] = { category = "Boots", source = { kind = "worldDrop", item = 16220 }, reagents = { {16203,2}, {16202,1} }, skillrange = { 275, 295, 315, 335 } },  -- Spirit (drops Stratholme)

        -- ===== Gloves =====
        [13612] = { category = "Gloves", source = { kind = "worldDrop", item = 11150 }, reagents = { {11083,1}, {2772,3} }, skillrange = { 145, 170, 190, 210 } },  -- Mining
        [13617] = { category = "Gloves", source = { kind = "worldDrop", item = 11151 }, reagents = { {11083,1}, {3356,3} }, skillrange = { 145, 170, 190, 210 } },  -- Herbalism
        [13620] = { category = "Gloves", source = { kind = "drop", zone = 267, item = 11152 }, reagents = { {11083,1}, {6370,3} }, skillrange = { 145, 170, 190, 210 } },  -- Fishing
        [13698] = { category = "Gloves", source = { kind = "drop", zone = 45, item = 11166 }, reagents = { {11137,1}, {7392,3} }, skillrange = { 200, 220, 240, 260 } },  -- Skinning
        [13815] = { category = "Gloves", source = { kind = "trainer" }, reagents = { {11174,1}, {11137,1} }, skillrange = { 210, 230, 250, 270 } },  -- Agility
        [13841] = { category = "Gloves", source = { kind = "drop", npc = 674, zone = 33, item = 11203 }, reagents = { {11137,3}, {6037,3} }, skillrange = { 215, 235, 255, 275 } },  -- Advanced Mining
        [13868] = { category = "Gloves", source = { kind = "drop", zone = 8, item = 11205 }, reagents = { {11137,3}, {8838,3} }, skillrange = { 225, 245, 265, 285 } },  -- Advanced Herbalism
        [13887] = { category = "Gloves", source = { kind = "trainer" }, reagents = { {11174,2}, {11137,3} }, skillrange = { 225, 245, 265, 285 } },  -- Strength
        [13947] = { category = "Gloves", source = { kind = "worldDrop", item = 11226 }, reagents = { {11178,2}, {11176,3} }, skillrange = { 250, 270, 290, 310 } },  -- Riding Skill (joke recipe, world drop)
        [13948] = { category = "Gloves", source = { kind = "vendor", npc = 11073 }, reagents = { {11178,2}, {8153,2} }, skillrange = { 250, 270, 290, 310 } },  -- Minor Haste (formula drops, Dire Maul)
        [20012] = { category = "Gloves", source = { kind = "drop", npc = 6201, zone = 16, item = 16219 }, reagents = { {16202,3}, {16204,3} }, skillrange = { 270, 290, 310, 330 } },  -- Greater Agility
        [20013] = { category = "Gloves", source = { kind = "drop", npc = 9198, zone = 1583, item = 16244 }, reagents = { {16203,4}, {16204,4} }, skillrange = { 295, 315, 335, 355 } },  -- Greater Strength
        [25072] = { category = "Gloves", source = { kind = "drop", npc = 15275, zone = 3428, item = 20726 }, reagents = { {20725,4}, {14344,6}, {18512,8} }, skillrange = { 300, 320, 340, 360 } },  -- Threat (Naxx-era drop)
        [25073] = { category = "Gloves", source = { kind = "drop", zone = 3428, item = 20727 }, reagents = { {20725,3}, {14344,10}, {12808,6} }, skillrange = { 300, 320, 340, 360 } },  -- Shadow Power
        [25074] = { category = "Gloves", source = { kind = "drop", zone = 3428, item = 20728 }, reagents = { {20725,3}, {14344,10}, {7080,4} }, skillrange = { 300, 320, 340, 360 } },  -- Frost Power
        [25078] = { category = "Gloves", source = { kind = "drop", zone = 3428, item = 20729 }, reagents = { {20725,2}, {14344,10}, {7078,4} }, skillrange = { 300, 320, 340, 360 } },  -- Fire Power
        [25079] = { category = "Gloves", source = { kind = "drop", zone = 3428, item = 20730 }, reagents = { {20725,3}, {14344,8}, {12811,1} }, skillrange = { 300, 320, 340, 360 } },  -- Healing Power
        [25080] = { category = "Gloves", source = { kind = "drop", zone = 3428, item = 20731 }, reagents = { {20725,3}, {14344,8}, {7082,4} }, skillrange = { 300, 320, 340, 360 } },  -- Superior Agility

        -- ===== Shield =====
        [13378] = { category = "Shield", source = { kind = "trainer" }, reagents = { {10998,1}, {10940,2} }, skillrange = { 105, 130, 150, 170 } },  -- Minor Stamina
        [13464] = { category = "Shield", source = { kind = "worldDrop", item = 11081 }, reagents = { {10998,1}, {10940,1}, {10978,1} }, skillrange = { 115, 140, 160, 180 } },  -- Lesser Protection
        [13485] = { category = "Shield", source = { kind = "trainer" }, reagents = { {10998,2}, {10940,4} }, skillrange = { 130, 155, 175, 195 } },  -- Lesser Spirit
        [13631] = { category = "Shield", source = { kind = "trainer" }, reagents = { {11134,1}, {11083,1} }, skillrange = { 155, 175, 195, 215 } },  -- Lesser Stamina
        [13659] = { category = "Shield", source = { kind = "trainer" }, reagents = { {11135,1}, {11137,1} }, skillrange = { 180, 200, 220, 240 } },  -- Spirit
        [13689] = { category = "Shield", source = { kind = "worldDrop", item = 11168 }, reagents = { {11135,2}, {11137,2}, {11139,1} }, skillrange = { 195, 215, 235, 255 } },  -- Lesser Block
        [13817] = { category = "Shield", source = { kind = "drop", zone = 33, item = 11202 }, reagents = { {11137,5} }, skillrange = { 210, 230, 250, 270 } },  -- Stamina
        [13905] = { category = "Shield", source = { kind = "vendor", npc = 11073 }, reagents = { {11175,1}, {11176,2} }, skillrange = { 230, 250, 270, 290 } },  -- Greater Spirit (formula drops)
        [13933] = { category = "Shield", source = { kind = "worldDrop", item = 11224 }, reagents = { {11178,1}, {3829,1} }, skillrange = { 235, 255, 275, 295 } },  -- Frost Resistance (formula drops)
        [20016] = { category = "Shield", source = { kind = "worldDrop", item = 16222 }, reagents = { {16203,2}, {16204,4} }, skillrange = { 280, 300, 320, 340 } },  -- Greater Spirit
        [20017] = { category = "Shield", source = { kind = "vendor", npcA = 4229, npcH = 4561, item = 16217 }, reagents = { {11176,10} }, skillrange = { 265, 285, 305, 325 } },  -- Greater Stamina

        -- ===== Weapon (1H + 2H combined) =====
        [7745]  = { category = "Weapon", source = { kind = "trainer" }, reagents = { {10940,4}, {10978,1} }, skillrange = { 100, 130, 150, 170 } },  -- Lesser Striking
        [7786]  = { category = "Weapon", source = { kind = "worldDrop", item = 6348 }, reagents = { {10940,4}, {10939,2} }, skillrange = {  90, 120, 140, 160 } },  -- Beastslayer
        [7788]  = { category = "Weapon", source = { kind = "trainer" }, reagents = { {10940,2}, {10939,1}, {10978,1} }, skillrange = {  90, 120, 140, 160 } },  -- Minor Striking
        [7793]  = { category = "Weapon", source = { kind = "vendor", npcA = 5158, npcH = 3346, item = 6349 }, reagents = { {10939,3} }, skillrange = { 100, 130, 150, 170 } },  -- 2H: Lesser Intellect
        [13380] = { category = "Weapon", source = { kind = "worldDrop", item = 11038 }, reagents = { {10998,1}, {10940,6} }, skillrange = { 110, 135, 155, 175 } },  -- 2H: Lesser Spirit
        [13503] = { category = "Weapon", source = { kind = "trainer" }, reagents = { {11083,2}, {11084,1} }, skillrange = { 140, 165, 185, 205 } },  -- Lesser Striking (variant)
        [13529] = { category = "Weapon", source = { kind = "trainer" }, reagents = { {11083,3}, {11084,1} }, skillrange = { 145, 170, 190, 210 } },  -- Striking
        [13653] = { category = "Weapon", source = { kind = "drop", npc = 92, zone = 3, item = 11164 }, reagents = { {11134,1}, {5637,2}, {11138,1} }, skillrange = { 175, 195, 215, 235 } },  -- 2H: Lesser Impact
        [13655] = { category = "Weapon", source = { kind = "drop", npc = 92, zone = 3, item = 11165 }, reagents = { {11134,1}, {7067,1}, {11138,1} }, skillrange = { 175, 195, 215, 235 } },  -- 2H: Lesser Beastslayer
        [13693] = { category = "Weapon", source = { kind = "trainer" }, reagents = { {11135,2}, {11139,1} }, skillrange = { 195, 215, 235, 255 } },  -- 2H: Impact
        [13695] = { category = "Weapon", source = { kind = "trainer" }, reagents = { {11137,4}, {11139,1} }, skillrange = { 200, 220, 240, 260 } },  -- Striking (variant)
        [13898] = { category = "Weapon", source = { kind = "drop", npc = 9024, zone = 1584, item = 11207 }, reagents = { {11177,4}, {7078,1} }, skillrange = { 265, 285, 305, 325 } },  -- Fiery Weapon (formula drops)
        [13915] = { category = "Weapon", source = { kind = "worldDrop", item = 11208 }, reagents = { {11177,1}, {11176,2}, {9224,1} }, skillrange = { 230, 250, 270, 290 } },  -- Demonslaying (formula drops)
        [13937] = { category = "Weapon", source = { kind = "vendor", npc = 11073 }, reagents = { {11178,2}, {11176,2} }, skillrange = { 240, 260, 280, 300 } },  -- Striking (variant)
        [13943] = { category = "Weapon", source = { kind = "vendor", npc = 11073 }, reagents = { {11178,2}, {11175,2} }, skillrange = { 245, 265, 285, 305 } },  -- Striking (variant)
        [20029] = { category = "Weapon", source = { kind = "drop", npc = 7524, zone = 618, item = 16223 }, reagents = { {14343,4}, {7080,1}, {7082,1}, {13467,1} }, skillrange = { 285, 305, 325, 345 } },  -- Icy Chill (formula drops, Stratholme)
        [20030] = { category = "Weapon", source = { kind = "drop", npc = 10317, zone = 1583, item = 16247 }, reagents = { {14344,4}, {16204,10} }, skillrange = { 295, 315, 335, 355 } },  -- Superior Striking
        [20031] = { category = "Weapon", source = { kind = "drop", npc = 9216, zone = 1583, item = 16250 }, reagents = { {14344,2}, {16203,10} }, skillrange = { 300, 320, 340, 360 } },  -- Striking (variant)
        [20032] = { category = "Weapon", source = { kind = "drop", npc = 10499, zone = 2057, item = 16254 }, reagents = { {14344,6}, {12808,6}, {12803,6} }, skillrange = { 300, 320, 340, 360 } },  -- Lifestealing (formula drops, Scholomance)
        [20033] = { category = "Weapon", source = { kind = "drop", npc = 10398, zone = 2017, item = 16248 }, reagents = { {14344,4}, {12808,4} }, skillrange = { 295, 315, 335, 355 } },  -- Unholy (formula drops, Stratholme)
        [20034] = { category = "Weapon", source = { kind = "drop", npc = 4494, zone = 28, item = 16252 }, reagents = { {14344,4}, {12811,2} }, skillrange = { 300, 320, 340, 360 } },  -- Crusader (drops from Scarlet Crusade)
        [20035] = { category = "Weapon", source = { kind = "drop", npc = 10469, zone = 2057, item = 16255 }, reagents = { {16203,12}, {14344,2} }, skillrange = { 300, 320, 340, 360 } },  -- 2H: Major Spirit
        [20036] = { category = "Weapon", source = { kind = "drop", npc = 10422, zone = 2017, item = 16249 }, reagents = { {16203,12}, {14344,2} }, skillrange = { 300, 320, 340, 360 } },  -- 2H: Major Intellect
        [21931] = { category = "Weapon", source = { kind = "worldDrop", item = 17725, event = "Feast of Winter Veil" }, reagents = { {11135,3}, {11137,3}, {11139,1}, {3819,2} }, skillrange = { 190, 210, 230, 250 } },  -- Winter's Might (Winter Veil event quest)
        [22749] = { category = "Weapon", source = { kind = "drop", zone = 2717, item = 18259 }, reagents = { {14344,4}, {16203,12}, {7078,4}, {7080,4}, {7082,4}, {13926,2} }, skillrange = { 300, 320, 340, 360 } },  -- Spell Power (drops Princess Yauj, AQ40)
        [22750] = { category = "Weapon", source = { kind = "drop", zone = 2717, item = 18260 }, reagents = { {14344,4}, {16203,8}, {12803,6}, {7080,6}, {12811,1} }, skillrange = { 300, 320, 340, 360 } },  -- Healing Power (drops Princess Yauj, AQ40)
        [23799] = { category = "Weapon", source = { kind = "reputation", item = 19444, faction = "Thorium Brotherhood", standing = "Honored" }, reagents = { {14344,6}, {16203,6}, {16204,4}, {7076,2} }, skillrange = { 290, 310, 330, 350 } },  -- ZG: Strength
        [23800] = { category = "Weapon", source = { kind = "vendor", npc = 11557, item = 19445 }, reagents = { {14344,6}, {16203,6}, {16204,4}, {7082,2} }, skillrange = { 290, 310, 330, 350 } },  -- ZG: Agility
        [23803] = { category = "Weapon", source = { kind = "reputation", item = 19448, faction = "Thorium Brotherhood", standing = "Honored" }, reagents = { {14344,10}, {16203,8}, {16204,15} }, skillrange = { 300, 320, 340, 360 } },  -- ZG: Spirit
        [23804] = { category = "Weapon", source = { kind = "reputation", item = 19449, faction = "Thorium Brotherhood", standing = "Honored" }, reagents = { {14344,15}, {16203,12}, {16204,20} }, skillrange = { 300, 320, 340, 360 } },  -- ZG: Intellect
        [27837] = { category = "Weapon", source = { kind = "vendor", npc = 11557, item = 22392 }, reagents = { {14344,10}, {16203,6}, {16204,14}, {7082,4} }, skillrange = { 290, 310, 330, 350 } },  -- 2H: Agility (added in 1.11)

    },

    ENGINEERING     = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  3918] = { category = "Material", source = { kind = "trainer" }, output = { 4357, 1 }, reagents = { {2835, 1} }, skillrange = {   1,  20,  30,  40 } },  -- Rough Blasting Powder
        [  3919] = { category = "Material", source = { kind = "trainer" }, output = { 4358, 2 }, reagents = { {2589, 1}, {4357, 2} }, skillrange = {   1,  30,  45,  60 } },  -- Rough Dynamite
        [  3922] = { category = "Material", source = { kind = "trainer" }, output = { 4359, 1 }, reagents = { {2840, 1} }, skillrange = {  30,  45,  52,  60 } },  -- Handful of Copper Bolts
        [  3920] = { source = { kind = "trainer" }, output = { 8067, 200 }, reagents = { {2840, 1}, {4357, 1} }, skillrange = {   1,  30,  45,  60 } },  -- Crafted Light Shot
        [  3923] = { category = "Material", source = { kind = "trainer" }, output = { 4360, 2 }, reagents = { {2589, 1}, {2840, 1}, {4357, 2}, {4359, 1} }, skillrange = {  30,  60,  75,  90 } },  -- Rough Copper Bomb
        [  3925] = { category = "Gun", source = { kind = "trainer" }, output = { 4362, 1 }, reagents = { {4359, 1}, {4361, 1}, {4399, 1} }, skillrange = {  50,  80,  95, 110 } },  -- Rough Boomstick
        [  3924] = { category = "Material", source = { kind = "trainer" }, output = { 4361, 1 }, reagents = { {2840, 2}, {2880, 1} }, skillrange = {  50,  80,  95, 110 } },  -- Copper Tube
        [  7430] = { category = "Weapon", source = { kind = "trainer" }, output = { 6219, 1 }, reagents = { {2840, 6} }, skillrange = {  50,  70,  80,  90 } },  -- Arclight Spanner
        [  3977] = { category = "Item Enhancement", source = { kind = "trainer" }, output = { 4405, 1 }, reagents = { {774, 1}, {4359, 1}, {4361, 1} }, skillrange = {  60,  90, 105, 120 } },  -- Crude Scope
        [  3926] = { category = "Material", source = { kind = "trainer" }, output = { 4363, 1 }, reagents = { {2589, 2}, {2840, 1}, {4359, 2} }, skillrange = {  65,  95, 110, 125 } },  -- Copper Modulator
        [  3929] = { category = "Material", source = { kind = "trainer" }, output = { 4364, 1 }, reagents = { {2836, 1} }, skillrange = {  75,  85,  90,  95 } },  -- Coarse Blasting Powder
        [  3930] = { source = { kind = "trainer" }, output = { 8068, 200 }, reagents = { {2840, 1}, {4364, 1} }, skillrange = {  75,  85,  90,  95 } },  -- Crafted Heavy Shot
        [  3928] = { category = "Material", source = { kind = "worldDrop", item = 4408 }, output = { 4401, 1 }, reagents = { {774, 2}, {2840, 1}, {4359, 1}, {4363, 1} }, skillrange = {  75, 105, 120, 135 } },  -- Mechanical Squirrel
        [  3931] = { category = "Material", source = { kind = "trainer" }, output = { 4365, 1 }, reagents = { {2589, 1}, {4364, 3} }, skillrange = {  75,  90,  97, 105 } },  -- Coarse Dynamite
        [  3932] = { category = "Material", source = { kind = "trainer" }, output = { 4366, 1 }, reagents = { {2592, 1}, {2841, 1}, {4359, 2}, {4363, 1} }, skillrange = {  85, 115, 130, 145 } },  -- Target Dummy
        [  3973] = { category = "Material", source = { kind = "trainer" }, output = { 4404, 5 }, reagents = { {2842, 1} }, skillrange = {  90, 110, 125, 140 } },  -- Silver Contact
        [  3934] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4368, 1 }, reagents = { {818, 2}, {2318, 6} }, skillrange = { 100, 130, 145, 160 } },  -- Flying Tiger Goggles
        [  8334] = { category = "Other", source = { kind = "trainer" }, output = { 6712, 1 }, reagents = { {2841, 1}, {2880, 1}, {4359, 2} }, skillrange = { 100, 115, 122, 130 } },  -- Practice Lock
        [  3933] = { category = "Material", source = { kind = "worldDrop", item = 4409 }, output = { 4367, 1 }, reagents = { {159, 1}, {2318, 1}, {4363, 1}, {4364, 2} }, skillrange = { 100, 130, 145, 160 } },  -- Small Seaforium Charge
        [  8339] = { category = "Material", source = { kind = "worldDrop", item = 6716 }, output = { 6714, 1 }, reagents = { {2592, 1}, {4364, 4} }, skillrange = { 100, 115, 122, 130 } },  -- EZ-Thro Dynamite
        [  3936] = { category = "Gun", source = { kind = "trainer" }, output = { 4369, 1 }, reagents = { {2319, 2}, {4359, 4}, {4361, 2}, {4399, 1} }, skillrange = { 105, 130, 142, 155 } },  -- Deadly Blunderbuss
        [  3938] = { category = "Material", source = { kind = "trainer" }, output = { 4371, 1 }, reagents = { {2841, 2}, {2880, 1} }, skillrange = { 105, 105, 130, 155 } },  -- Bronze Tube
        [  3937] = { category = "Material", source = { kind = "trainer" }, output = { 4370, 2 }, reagents = { {2840, 3}, {4364, 4}, {4404, 1} }, skillrange = { 105, 105, 130, 155 } },  -- Large Copper Bomb
        [  3978] = { category = "Item Enhancement", source = { kind = "trainer" }, output = { 4406, 1 }, reagents = { {1206, 1}, {4371, 1} }, skillrange = { 110, 135, 147, 160 } },  -- Standard Scope
        [  3939] = { category = "Gun", source = { kind = "vendor", npc = 6730, item = 13309 }, output = { 4372, 1 }, reagents = { {1206, 3}, {4359, 2}, {4371, 2}, {4400, 1} }, skillrange = { 120, 145, 157, 170 } },  -- Lovingly Crafted Boomstick
        [  3940] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4410 }, output = { 4373, 1 }, reagents = { {1210, 2}, {2319, 4} }, skillrange = { 120, 145, 157, 170 } },  -- Shadow Goggles
        [  3941] = { category = "Material", source = { kind = "trainer" }, output = { 4374, 1 }, reagents = { {2592, 1}, {2841, 2}, {4364, 4}, {4404, 1} }, skillrange = { 120, 120, 145, 170 } },  -- Small Bronze Bomb
        [  3942] = { category = "Material", source = { kind = "trainer" }, output = { 4375, 1 }, reagents = { {2592, 1}, {2841, 2} }, skillrange = { 125, 125, 150, 175 } },  -- Whirring Bronze Gizmo
        [  3945] = { category = "Material", source = { kind = "trainer" }, output = { 4377, 1 }, reagents = { {2838, 1} }, skillrange = { 125, 125, 135, 145 } },  -- Heavy Blasting Powder
        [  9269] = { category = "Engineered Item", source = { kind = "vendor", npc = 6730, item = 7560 }, output = { 7506, 1 }, reagents = { {774, 1}, {814, 2}, {818, 1}, {2841, 6}, {4375, 1} }, skillrange = { 125, 150, 162, 175 } },  -- Gnomish Universal Remote
        [ 26418] = { category = "Oil", source = { kind = "quest", item = 21726, quest = 8876 }, output = { 21557, 3 }, reagents = { {2319, 1}, {4364, 1} }, skillrange = { 125, 125, 137, 150 } },  -- Small Red Rocket
        [ 26416] = { category = "Oil", source = { kind = "quest", item = 21724, quest = 8876 }, output = { 21558, 3 }, reagents = { {2319, 1}, {4364, 1} }, skillrange = { 125, 125, 137, 150 } },  -- Small Blue Rocket
        [ 26417] = { category = "Oil", source = { kind = "quest", item = 21725, quest = 8876 }, output = { 21559, 3 }, reagents = { {2319, 1}, {4364, 1} }, skillrange = { 125, 125, 137, 150 } },  -- Small Green Rocket
        [  3946] = { category = "Material", source = { kind = "trainer" }, output = { 4378, 1 }, reagents = { {2592, 1}, {4377, 2} }, skillrange = { 125, 125, 135, 145 } },  -- Heavy Dynamite
        [  3947] = { source = { kind = "trainer" }, output = { 8069, 200 }, reagents = { {2841, 1}, {4377, 1} }, skillrange = { 125, 125, 135, 145 } },  -- Crafted Solid Shot
        [  3944] = { category = "Material", source = { kind = "drop", npc = 7800, zone = 721, item = 4411 }, output = { 4376, 1 }, reagents = { {4375, 1}, {4402, 1} }, skillrange = { 125, 125, 150, 175 } },  -- Flame Deflector
        [  3949] = { category = "Gun", source = { kind = "trainer" }, output = { 4379, 1 }, reagents = { {2842, 3}, {4371, 2}, {4375, 2}, {4400, 1} }, skillrange = { 130, 155, 167, 180 } },  -- Silver-plated Shotgun
        [  6458] = { category = "Material", source = { kind = "trainer" }, output = { 5507, 1 }, reagents = { {1206, 1}, {4363, 1}, {4371, 2}, {4375, 2} }, skillrange = { 135, 160, 172, 185 } },  -- Ornate Spyglass
        [  3952] = { category = "Engineered Item", source = { kind = "vendor", npc = 2682, item = 14639 }, output = { 4381, 1 }, reagents = { {1206, 1}, {2319, 2}, {4371, 1}, {4375, 2} }, skillrange = { 140, 165, 177, 190 } },  -- Minor Recombobulator
        [  3950] = { category = "Material", source = { kind = "trainer" }, output = { 4380, 2 }, reagents = { {2841, 3}, {4377, 2}, {4404, 1} }, skillrange = { 140, 140, 165, 190 } },  -- Big Bronze Bomb
        [  3954] = { category = "Gun", source = { kind = "worldDrop", item = 4412 }, output = { 4383, 1 }, reagents = { {1705, 2}, {4371, 3}, {4375, 3}, {4400, 1} }, skillrange = { 145, 170, 182, 195 } },  -- Moonsight Rifle
        [  3953] = { category = "Material", source = { kind = "trainer" }, output = { 4382, 1 }, reagents = { {2319, 1}, {2592, 1}, {2841, 2} }, skillrange = { 145, 145, 170, 195 } },  -- Bronze Framework
        [ 23068] = { category = "Oil", source = { kind = "vendor", npc = 2838, item = 18648 }, output = { 9313, 3 }, reagents = { {4234, 1}, {4377, 1} }, skillrange = { 150, 150, 162, 175 } },  -- Green Firework
        [ 12584] = { category = "Material", source = { kind = "trainer" }, output = { 10558, 3 }, reagents = { {3577, 1} }, skillrange = { 150, 150, 170, 190 } },  -- Gold Power Core
        [  3956] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4385, 1 }, reagents = { {1206, 2}, {2319, 4}, {4368, 1} }, skillrange = { 150, 175, 187, 200 } },  -- Green Tinted Goggles
        [ 23067] = { category = "Oil", source = { kind = "vendor", npc = 1304, item = 18649 }, output = { 9312, 3 }, reagents = { {4234, 1}, {4377, 1} }, skillrange = { 150, 150, 162, 175 } },  -- Blue Firework
        [ 23066] = { category = "Oil", source = { kind = "vendor", npc = 3413, item = 18647 }, output = { 9318, 3 }, reagents = { {4234, 1}, {4377, 1} }, skillrange = { 150, 150, 162, 175 } },  -- Red Firework
        [  9271] = { category = "Weapon Coating", source = { kind = "trainer" }, output = { 6533, 3 }, reagents = { {2841, 2}, {4364, 1}, {6530, 1} }, skillrange = { 150, 150, 160, 170 } },  -- Aquadynamic Fish Attractor
        [  3955] = { category = "Material", source = { kind = "trainer" }, output = { 4384, 1 }, reagents = { {2592, 2}, {4375, 1}, {4377, 2}, {4382, 1} }, skillrange = { 150, 175, 187, 200 } },  -- Explosive Sheep
        [  3957] = { category = "Material", source = { kind = "vendor", npc = 2684, item = 13308 }, output = { 4386, 1 }, reagents = { {3829, 1}, {4375, 1} }, skillrange = { 155, 175, 185, 195 } },  -- Ice Deflector
        [  3958] = { category = "Material", source = { kind = "trainer" }, output = { 4387, 1 }, reagents = { {3575, 2} }, skillrange = { 160, 160, 170, 180 } },  -- Iron Strut
        [  3959] = { category = "Material", source = { kind = "drop", npc = 7800, zone = 721, item = 4413 }, output = { 4388, 1 }, reagents = { {1529, 1}, {4306, 2}, {4371, 1}, {4375, 3} }, skillrange = { 160, 180, 190, 200 } },  -- Discombobulator Ray
        [  9273] = { category = "Engineered Item", source = { kind = "vendor", npc = 4086, item = 7561 }, output = { 7148, 1 }, reagents = { {814, 2}, {1210, 2}, {3575, 6}, {4306, 2}, {4375, 2}, {7191, 1} }, skillrange = { 165, 165, 180, 200 } },  -- Goblin Jumper Cables
        [  3960] = { category = "Material", source = { kind = "worldDrop", item = 4414 }, output = { 4403, 1 }, reagents = { {2319, 4}, {4371, 4}, {4377, 4}, {4387, 1} }, skillrange = { 165, 185, 195, 205 } },  -- Portable Bronze Mortar
        [  3961] = { category = "Material", source = { kind = "trainer" }, output = { 4389, 1 }, reagents = { {3575, 1}, {10558, 1} }, skillrange = { 170, 170, 190, 210 } },  -- Gyrochronatom
        [ 12585] = { category = "Material", source = { kind = "trainer" }, output = { 10505, 1 }, reagents = { {7912, 2} }, skillrange = { 175, 175, 185, 195 } },  -- Solid Blasting Powder
        [ 12586] = { category = "Material", source = { kind = "trainer" }, output = { 10507, 2 }, reagents = { {4306, 1}, {10505, 1} }, skillrange = { 175, 175, 185, 195 } },  -- Solid Dynamite
        [ 12587] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10601 }, output = { 10499, 1 }, reagents = { {3864, 2}, {4234, 6} }, skillrange = { 175, 195, 205, 215 } },  -- Bright-Eye Goggles
        [  3962] = { category = "Material", source = { kind = "trainer" }, output = { 4390, 2 }, reagents = { {3575, 1}, {4306, 1}, {4377, 1} }, skillrange = { 175, 175, 195, 215 } },  -- Iron Grenade
        [  3963] = { category = "Material", source = { kind = "trainer" }, output = { 4391, 1 }, reagents = { {4234, 4}, {4382, 1}, {4387, 2}, {4389, 2} }, skillrange = { 175, 175, 195, 215 } },  -- Compact Harvest Reaper Kit
        [ 12590] = { category = "Material", source = { kind = "trainer" }, output = { 10498, 1 }, reagents = { {3859, 4} }, skillrange = { 175, 175, 195, 215 } },  -- Gyromatic Micro-Adjustor
        [ 26421] = { category = "Oil", source = { kind = "quest", item = 21728, quest = 8879 }, output = { 21590, 3 }, reagents = { {4234, 1}, {4377, 1} }, skillrange = { 175, 175, 187, 200 } },  -- Large Green Rocket
        [ 26420] = { category = "Oil", source = { kind = "quest", item = 21727, quest = 8879 }, output = { 21589, 3 }, reagents = { {4234, 1}, {4377, 1} }, skillrange = { 175, 175, 187, 200 } },  -- Large Blue Rocket
        [ 26422] = { category = "Oil", source = { kind = "quest", item = 21729, quest = 8879 }, output = { 21592, 3 }, reagents = { {4234, 1}, {4377, 1} }, skillrange = { 175, 175, 187, 200 } },  -- Large Red Rocket
        [  3979] = { category = "Item Enhancement", source = { kind = "vendor", npc = 2685, item = 13310 }, output = { 4407, 1 }, reagents = { {1529, 1}, {3864, 1}, {4371, 1} }, skillrange = { 180, 200, 210, 220 } },  -- Accurate Scope
        [  8243] = { category = "Material", source = { kind = "quest", item = 6672, quest = 1559 }, output = { 4852, 1 }, reagents = { {4306, 1}, {4377, 1}, {4611, 1} }, skillrange = { 185, 185, 205, 225 } },  -- Flash Bomb
        [  3965] = { category = "Material", source = { kind = "trainer" }, output = { 4392, 1 }, reagents = { {4234, 4}, {4382, 1}, {4387, 1}, {4389, 1} }, skillrange = { 185, 185, 205, 225 } },  -- Advanced Target Dummy
        [  3966] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4415 }, output = { 4393, 1 }, reagents = { {3864, 2}, {4234, 6} }, skillrange = { 185, 205, 215, 225 } },  -- Craftsman's Monocle
        [  3967] = { category = "Material", source = { kind = "trainer" }, output = { 4394, 2 }, reagents = { {3575, 3}, {4377, 3}, {4404, 1} }, skillrange = { 190, 190, 210, 230 } },  -- Big Iron Bomb
        [ 21940] = { category = "Material", source = { kind = "worldDrop", item = 17720, event = "Feast of Winter Veil" }, output = { 17716, 1 }, reagents = { {3829, 1}, {3860, 8}, {4389, 4}, {17202, 4} }, skillrange = { 190, 190, 210, 230 } },  -- SnowMaster 9000
        [ 12589] = { category = "Material", source = { kind = "trainer" }, output = { 10559, 1 }, reagents = { {3860, 3} }, skillrange = { 195, 195, 215, 235 } },  -- Mithril Tube
        [  3968] = { category = "Material", source = { kind = "worldDrop", item = 4416 }, output = { 4395, 1 }, reagents = { {3575, 2}, {4377, 3}, {4389, 1} }, skillrange = { 195, 215, 225, 235 } },  -- Goblin Land Mine
        [ 15255] = { category = "Material", source = { kind = "trainer" }, output = { 11590, 1 }, reagents = { {3860, 1}, {4338, 1}, {10505, 1} }, skillrange = { 200, 200, 220, 240 } },  -- Mechanical Repair Kit
        [ 12591] = { category = "Material", source = { kind = "trainer" }, output = { 10560, 1 }, reagents = { {3860, 1}, {4338, 1}, {10505, 1} }, skillrange = { 200, 200, 220, 240 } },  -- Unstable Trigger
        [  3971] = { category = "Engineered Item", source = { kind = "vendor", npc = 6777, item = 7742 }, output = { 4397, 1 }, reagents = { {1529, 2}, {1705, 2}, {3864, 2}, {4389, 4}, {7191, 1} }, skillrange = { 200, 220, 230, 240 } },  -- Gnomish Cloaking Device
        [  3969] = { category = "Engineered Item", source = { kind = "vendor", npc = 2687, item = 13311 }, output = { 4396, 1 }, reagents = { {3864, 2}, {4382, 1}, {4387, 4}, {4389, 4}, {7191, 1} }, skillrange = { 200, 220, 230, 240 } },  -- Mechanical Dragonling
        [  3972] = { category = "Material", source = { kind = "worldDrop", item = 4417 }, output = { 4398, 1 }, reagents = { {159, 1}, {4234, 2}, {10505, 2} }, skillrange = { 200, 200, 220, 240 } },  -- Large Seaforium Charge
        [ 23069] = { category = "Material", source = { kind = "vendor", npc = 8131, item = 18650 }, output = { 18588, 1 }, reagents = { {4338, 2}, {10505, 1} }, skillrange = { 200, 200, 210, 220 } },  -- EZ-Thro Dynamite II
        [ 12760] = { category = "Material", source = { kind = "vendor", npc = 8738 }, output = { 10646, 1 }, reagents = { {4338, 1}, {10505, 3}, {10560, 1} }, skillrange = { 205, 205, 225, 245 } },  -- Goblin Sapper Charge
        [ 12595] = { category = "Gun", source = { kind = "trainer" }, output = { 10508, 1 }, reagents = { {3860, 4}, {4400, 1}, {7068, 2}, {10559, 1}, {10560, 1} }, skillrange = { 205, 225, 235, 245 } },  -- Mithril Blunderbuss
        [ 12717] = { category = "Mail Armor", source = { kind = "vendor", npc = 8738 }, output = { 10542, 1 }, reagents = { {3860, 8}, {3864, 1}, {7067, 4} }, skillrange = { 205, 225, 235, 245 } },  -- Goblin Mining Helmet
        [ 12718] = { category = "Cloth Armor", source = { kind = "vendor", npc = 8738 }, output = { 10543, 1 }, reagents = { {3860, 8}, {3864, 1}, {7068, 4} }, skillrange = { 205, 225, 235, 245 } },  -- Goblin Construction Helmet
        [ 12594] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10500, 1 }, reagents = { {3864, 2}, {4234, 4}, {4385, 1}, {7068, 2} }, skillrange = { 205, 225, 235, 245 } },  -- Fire Goggles
        [ 13240] = { category = "Engineered Item", source = { kind = "vendor", npc = 8738 }, output = { 10577, 1 }, reagents = { {3860, 1}, {10505, 3}, {10577, 1} } },  -- The Mortar: Reloaded
        [ 12899] = { category = "Engineered Item", source = { kind = "vendor", npc = 7406 }, output = { 10716, 1 }, reagents = { {1529, 2}, {3860, 4}, {8151, 4}, {10559, 1}, {10560, 1} }, skillrange = { 205, 225, 235, 245 } },  -- Gnomish Shrink Ray
        [ 12895] = { source = { kind = "vendor", npc = 7406 }, output = { 10713, 1 }, reagents = { {10647, 1}, {10648, 1} }, skillrange = {   1,   1, 103, 205 } },  -- Inlaid Mithril Cylinder Plans
        [ 15628] = { category = "Material", source = { kind = "drop", npc = 7800, zone = 721, item = 11828 }, output = { 11825, 1 }, reagents = { {3860, 6}, {4394, 1}, {7077, 1}, {7191, 1} }, skillrange = {   1,   1, 103, 205 } },  -- Pet Bombling
        [ 15633] = { category = "Material", source = { kind = "drop", zone = 721, item = 11827 }, output = { 11826, 1 }, reagents = { {3860, 2}, {4389, 2}, {6037, 1}, {7075, 1}, {7191, 1} }, skillrange = {   1,   1, 103, 205 } },  -- Lil' Smoky
        [ 12715] = { source = { kind = "vendor", npc = 8738 }, output = { 10644, 1 }, reagents = { {10647, 1}, {10648, 1} }, skillrange = {   1,   1, 103, 205 } },  -- Goblin Rocket Fuel Recipe
        [ 12597] = { category = "Item Enhancement", source = { kind = "vendor", npc = 8679, item = 10602 }, output = { 10546, 1 }, reagents = { {4304, 2}, {7909, 2}, {10559, 1} }, skillrange = { 210, 230, 240, 250 } },  -- Deadly Scope
        [ 12897] = { category = "Cloth Armor", source = { kind = "vendor", npc = 7406 }, output = { 10545, 1 }, reagents = { {4234, 2}, {8151, 2}, {10500, 1}, {10558, 2}, {10559, 1} }, skillrange = { 210, 230, 240, 250 } },  -- Gnomish Goggles
        [ 12902] = { category = "Engineered Item", source = { kind = "vendor", npc = 7406 }, output = { 10720, 1 }, reagents = { {3860, 4}, {4337, 4}, {10285, 2}, {10505, 2}, {10559, 1} }, skillrange = { 210, 230, 240, 250 } },  -- Gnomish Net-o-Matic Projector
        [ 12596] = { source = { kind = "trainer" }, output = { 10512, 200 }, reagents = { {3860, 1}, {10505, 1} }, skillrange = { 210, 210, 230, 250 } },  -- Hi-Impact Mithril Slugs
        [ 12599] = { category = "Material", source = { kind = "trainer" }, output = { 10561, 1 }, reagents = { {3860, 3} }, skillrange = { 215, 215, 235, 255 } },  -- Mithril Casing
        [ 12903] = { category = "Leather Armor", source = { kind = "vendor", npc = 7406 }, output = { 10721, 1 }, reagents = { {3860, 4}, {6037, 2}, {7387, 1}, {7909, 2}, {10560, 1} }, skillrange = { 215, 235, 245, 255 } },  -- Gnomish Harm Prevention Belt
        [ 12603] = { category = "Material", source = { kind = "trainer" }, output = { 10514, 3 }, reagents = { {10505, 1}, {10560, 1}, {10561, 1} }, skillrange = { 215, 215, 235, 255 } },  -- Mithril Frag Bomb
        [ 12614] = { category = "Gun", source = { kind = "worldDrop", item = 10604 }, output = { 10510, 1 }, reagents = { {3860, 6}, {3864, 2}, {4400, 1}, {10559, 2}, {10560, 1} }, skillrange = { 220, 240, 250, 260 } },  -- Mithril Heavy-bore Rifle
        [ 12607] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10603 }, output = { 10501, 1 }, reagents = { {4304, 4}, {7909, 2}, {10592, 1} }, skillrange = { 220, 240, 250, 260 } },  -- Catseye Ultra Goggles
        [  8895] = { category = "Cloth Armor", source = { kind = "vendor", npc = 8738 }, output = { 7189, 1 }, reagents = { {4234, 4}, {9061, 2}, {10026, 1}, {10559, 2}, {10560, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Goblin Rocket Boots
        [ 12616] = { category = "Cloak", source = { kind = "worldDrop", item = 10606 }, output = { 10518, 1 }, reagents = { {4339, 4}, {10285, 2}, {10505, 4}, {10560, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Parachute Cloak
        [ 12716] = { category = "Engineered Item", source = { kind = "vendor", npc = 8126 }, output = { 10577, 1 }, reagents = { {3860, 4}, {7068, 1}, {10505, 5}, {10558, 1}, {10559, 2} }, skillrange = { 225, 225, 235, 245 } },  -- Goblin Mortar
        [ 12905] = { category = "Cloth Armor", source = { kind = "vendor", npc = 7406 }, output = { 10724, 1 }, reagents = { {4234, 4}, {4389, 4}, {10026, 1}, {10505, 8}, {10559, 2} }, skillrange = { 225, 245, 255, 265 } },  -- Gnomish Rocket Boots
        [ 12615] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10605 }, output = { 10502, 1 }, reagents = { {4304, 4}, {7910, 2} }, skillrange = { 225, 245, 255, 265 } },  -- Spellpower Goggles Xtreme
        [ 26423] = { category = "Oil", source = { kind = "quest", item = 21730, quest = 8880 }, output = { 21571, 3 }, reagents = { {4304, 1}, {10505, 1} }, skillrange = { 225, 225, 237, 250 } },  -- Blue Rocket Cluster
        [ 26424] = { category = "Oil", source = { kind = "quest", item = 21731, quest = 8880 }, output = { 21574, 3 }, reagents = { {4304, 1}, {10505, 1} }, skillrange = { 225, 225, 237, 250 } },  -- Green Rocket Cluster
        [ 26425] = { category = "Oil", source = { kind = "quest", item = 21732, quest = 8880 }, output = { 21576, 3 }, reagents = { {4304, 1}, {10505, 1} }, skillrange = { 225, 225, 237, 250 } },  -- Red Rocket Cluster
        [ 26442] = { category = "Oil", source = { kind = "quest", item = 21738, quest = 8877 }, output = { 21569, 1 }, reagents = { {9060, 1}, {9061, 1}, {10560, 1}, {10561, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Firework Launcher
        [ 12906] = { category = "Engineered Item", source = { kind = "vendor", npc = 7406 }, output = { 10725, 1 }, reagents = { {1529, 2}, {3860, 6}, {6037, 6}, {9060, 2}, {10558, 1}, {10561, 1} }, skillrange = { 230, 250, 260, 270 } },  -- Gnomish Battle Chicken
        [ 12617] = { category = "Cloth Armor", source = { kind = "vendor", npc = 8678, item = 10607 }, output = { 10506, 1 }, reagents = { {774, 4}, {818, 4}, {3860, 8}, {6037, 1}, {10561, 1} }, skillrange = { 230, 250, 260, 270 } },  -- Deepdive Helmet
        [ 12755] = { category = "Engineered Item", source = { kind = "vendor", npc = 8738 }, output = { 10587, 1 }, reagents = { {4407, 2}, {6037, 6}, {10505, 4}, {10560, 1}, {10561, 2} }, skillrange = { 230, 230, 250, 270 } },  -- Goblin Bomb Dispenser
        [ 12618] = { category = "Cloth Armor", source = { kind = "vendor", npc = 8736 }, output = { 10503, 1 }, reagents = { {4304, 6}, {7910, 2} }, skillrange = { 230, 250, 260, 270 } },  -- Rose Colored Goggles
        [ 12619] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 10562, 4 }, reagents = { {10505, 2}, {10560, 1}, {10561, 2} }, skillrange = { 235, 235, 255, 275 } },  -- Hi-Explosive Bomb
        [ 12907] = { category = "Cloth Armor", source = { kind = "vendor", npc = 7406 }, output = { 10726, 1 }, reagents = { {3860, 10}, {4338, 4}, {6037, 4}, {7910, 2}, {10558, 1} }, skillrange = { 235, 255, 265, 275 } },  -- Gnomish Mind Control Cap
        [ 12754] = { category = "Material", source = { kind = "vendor", npc = 8738 }, output = { 10586, 2 }, reagents = { {9061, 1}, {10507, 6}, {10560, 1}, {10561, 1} }, skillrange = { 235, 235, 255, 275 } },  -- The Big One
        [ 12759] = { category = "Engineered Item", source = { kind = "vendor", npc = 7406 }, output = { 10645, 1 }, reagents = { {7972, 4}, {9060, 1}, {10559, 2}, {10560, 1}, {12808, 1} }, skillrange = { 240, 260, 270, 280 } },  -- Gnomish Death Ray
        [ 12908] = { category = "Engineered Item", source = { kind = "vendor", npc = 8738 }, output = { 10727, 1 }, reagents = { {3860, 6}, {6037, 6}, {9061, 4}, {10559, 2}, {10560, 1} }, skillrange = { 240, 260, 270, 280 } },  -- Goblin Dragon Gun
        [ 12620] = { category = "Item Enhancement", source = { kind = "worldDrop", item = 10608 }, output = { 10548, 1 }, reagents = { {6037, 2}, {7910, 1}, {10559, 1} }, skillrange = { 240, 260, 270, 280 } },  -- Sniper Scope
        [ 12622] = { category = "Cloth Armor", source = { kind = "vendor", npc = 8736 }, output = { 10504, 1 }, reagents = { {1529, 3}, {4304, 8}, {7909, 3}, {8153, 2}, {10286, 2} }, skillrange = { 245, 265, 275, 285 } },  -- Green Lens
        [ 12758] = { category = "Cloth Armor", source = { kind = "vendor", npc = 8738 }, output = { 10588, 1 }, reagents = { {3860, 4}, {9061, 4}, {10543, 1}, {10560, 1} }, skillrange = { 245, 265, 275, 285 } },  -- Goblin Rocket Helmet
        [ 12621] = { source = { kind = "vendor", npc = 8736 }, output = { 10513, 200 }, reagents = { {3860, 2}, {10505, 2} }, skillrange = { 245, 245, 265, 285 } },  -- Mithril Gyro-Shot
        [ 19788] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 15992, 1 }, reagents = { {12365, 2} }, skillrange = { 250, 250, 255, 260 } },  -- Dense Blasting Powder
        [ 12624] = { category = "Engineered Item", source = { kind = "vendor", npc = 2688, item = 10609 }, output = { 10576, 1 }, reagents = { {3860, 14}, {6037, 4}, {7077, 4}, {7910, 2}, {9060, 2}, {9061, 2} }, skillrange = { 250, 270, 280, 290 } },  -- Mithril Mechanical Dragonling
        [ 19567] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 15846, 1 }, reagents = { {10558, 1}, {10560, 4}, {10561, 1}, {12359, 6} }, skillrange = { 250, 270, 280, 290 } },  -- Salt Shaker
        [ 26011] = { category = "Material", source = { kind = "quest", quest = 8798 }, output = { 21277, 1 }, reagents = { {7079, 2}, {10558, 1}, {15407, 1}, {15994, 4}, {18631, 2} }, skillrange = { 250, 320, 330, 340 } },  -- Tranquil Mechanical Yeti
        [ 23507] = { category = "Oil", source = { kind = "vendor", npc = 14637, item = 19027 }, output = { 19026, 4 }, reagents = { {8150, 1}, {14047, 2}, {15992, 2} }, skillrange = { 250, 250, 260, 270 } },  -- Snake Burst Firework
        [ 23070] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 18641, 2 }, reagents = { {14047, 3}, {15992, 2} }, skillrange = { 250, 250, 260, 270 } },  -- Dense Dynamite
        [ 19791] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 15994, 1 }, reagents = { {12359, 3}, {14047, 1} }, skillrange = { 260, 280, 290, 300 } },  -- Thorium Widget
        [ 19790] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 15993, 3 }, reagents = { {12359, 3}, {14047, 3}, {15992, 3}, {15994, 1} }, skillrange = { 260, 280, 290, 300 } },  -- Thorium Grenade
        [ 19792] = { category = "Gun", source = { kind = "worldDrop", item = 16043 }, output = { 15995, 1 }, reagents = { {10546, 1}, {10559, 2}, {10561, 2}, {12359, 4}, {15994, 2} }, skillrange = { 260, 280, 290, 300 } },  -- Thorium Rifle
        [ 23071] = { category = "Material", source = { kind = "vendor", npc = 8736 }, output = { 18631, 1 }, reagents = { {6037, 2}, {7067, 2}, {7069, 1} }, skillrange = { 260, 270, 275, 280 } },  -- Truesilver Transformer
        [ 23077] = { category = "Engineered Item", source = { kind = "vendor", npc = 11185, item = 18652 }, output = { 18634, 1 }, reagents = { {3829, 2}, {7078, 4}, {12361, 2}, {13467, 4}, {15994, 6}, {18631, 2} }, skillrange = { 260, 280, 290, 300 } },  -- Gyrofreeze Ice Reflector
        [ 23129] = { category = "Material", source = { kind = "drop", npc = 8920, zone = 1584, item = 18661 }, output = { 18660, 1 }, reagents = { {3864, 1}, {10558, 1}, {10560, 1}, {10561, 1}, {15994, 2} }, skillrange = { 260, 260, 265, 270 } },  -- World Enlarger
        [ 23078] = { category = "Engineered Item", source = { kind = "drop", npc = 9499, zone = 1584, item = 18653 }, output = { 18587, 1 }, reagents = { {7191, 2}, {7910, 2}, {14227, 2}, {15994, 2}, {18631, 2} }, skillrange = { 265, 285, 295, 305 } },  -- Goblin Jumper Cables XL
        [ 19793] = { category = "Material", source = { kind = "worldDrop", item = 16044 }, output = { 15996, 1 }, reagents = { {8170, 1}, {10558, 1}, {12803, 1}, {15994, 4} }, skillrange = { 265, 285, 295, 305 } },  -- Lifelike Mechanical Toad
        [ 23096] = { category = "Material", source = { kind = "drop", npc = 8920, zone = 1584, item = 18654 }, output = { 18645, 1 }, reagents = { {7191, 1}, {7910, 1}, {8170, 4}, {12359, 4}, {15994, 2} }, skillrange = { 265, 275, 280, 285 } },  -- Alarm-O-Bot
        [ 19794] = { category = "Cloth Armor", source = { kind = "drop", npc = 6195, zone = 16, item = 16045 }, output = { 15999, 1 }, reagents = { {7910, 4}, {10502, 1}, {12810, 2}, {14047, 8} }, skillrange = { 270, 290, 300, 310 } },  -- Spellpower Goggles Xtreme Plus
        [ 19795] = { category = "Material", source = { kind = "vendor", npc = 11185, item = 16047 }, output = { 16000, 1 }, reagents = { {12359, 6} }, skillrange = { 275, 295, 305, 315 } },  -- Thorium Tube
        [ 19796] = { category = "Gun", source = { kind = "drop", npc = 8897, zone = 1584, item = 16048 }, output = { 16004, 1 }, reagents = { {8170, 4}, {10546, 2}, {11371, 6}, {12361, 2}, {12799, 2}, {16000, 2} }, skillrange = { 275, 295, 305, 315 } },  -- Dark Iron Rifle
        [ 23079] = { category = "Engineered Item", source = { kind = "drop", npc = 14324, zone = 2557, item = 18655 }, output = { 18637, 1 }, reagents = { {14047, 2}, {16000, 2}, {18631, 1} }, skillrange = { 275, 285, 290, 295 } },  -- Major Recombobulator
        [ 19814] = { category = "Material", source = { kind = "vendor", npc = 11185, item = 16046 }, output = { 16023, 1 }, reagents = { {6037, 1}, {8170, 2}, {10561, 1}, {14047, 4}, {15994, 2}, {16000, 1} }, skillrange = { 275, 295, 305, 315 } },  -- Masterwork Target Dummy
        [ 26443] = { category = "Oil", source = { kind = "quest", item = 21737, quest = 8882 }, output = { 21570, 1 }, reagents = { {9060, 4}, {9061, 4}, {10561, 1}, {18631, 2} }, skillrange = { 275, 295, 305, 315 } },  -- Firework Cluster Launcher
        [ 26427] = { category = "Oil", source = { kind = "quest", item = 21734, quest = 8881 }, output = { 21716, 3 }, reagents = { {8170, 1}, {15992, 1} }, skillrange = { 275, 275, 280, 285 } },  -- Large Green Rocket Cluster
        [ 26426] = { category = "Oil", source = { kind = "quest", item = 21733, quest = 8881 }, output = { 21714, 3 }, reagents = { {8170, 1}, {15992, 1} }, skillrange = { 275, 275, 280, 285 } },  -- Large Blue Rocket Cluster
        [ 26428] = { category = "Oil", source = { kind = "quest", item = 21735, quest = 8881 }, output = { 21718, 3 }, reagents = { {8170, 1}, {15992, 1} }, skillrange = { 275, 275, 280, 285 } },  -- Large Red Rocket Cluster
        [ 23080] = { category = "Material", source = { kind = "vendor", npc = 11185, item = 18656 }, output = { 18594, 1 }, reagents = { {159, 1}, {8170, 2}, {15992, 3}, {15994, 2} }, skillrange = { 275, 275, 285, 295 } },  -- Powerful Seaforium Charge
        [ 19815] = { category = "Material", source = { kind = "vendor", npc = 11185, item = 16050 }, output = { 16006, 1 }, reagents = { {12360, 1}, {14227, 1} }, skillrange = { 285, 305, 315, 325 } },  -- Delicate Arcanite Converter
        [ 23486] = { category = "Engineered Item", source = { kind = "vendor", npc = 14742 }, output = { 18984, 1 }, reagents = { {3860, 10}, {7077, 4}, {7910, 2}, {10586, 1}, {18631, 1} }, skillrange = { 285, 285, 295, 305 } },  -- Dimensional Ripper - Everlook
        [ 23489] = { category = "Engineered Item", source = { kind = "vendor", npc = 14743 }, output = { 18986, 1 }, reagents = { {3860, 12}, {7075, 4}, {7079, 2}, {7909, 4}, {9060, 1}, {18631, 2} }, skillrange = { 285, 285, 295, 305 } },  -- Ultrasafe Transporter - Gadgetzan
        [ 19800] = { source = { kind = "worldDrop", item = 16051 }, output = { 15997, 200 }, reagents = { {12359, 2}, {15992, 1} }, skillrange = { 285, 305, 315, 325 } },  -- Thorium Shells
        [ 19799] = { category = "Material", source = { kind = "drop", npc = 8920, zone = 1584, item = 16049 }, output = { 16005, 3 }, reagents = { {11371, 1}, {14047, 3}, {15992, 3}, {15994, 2} }, skillrange = { 285, 305, 315, 325 } },  -- Dark Iron Bomb
        [ 23081] = { category = "Engineered Item", source = { kind = "drop", npc = 10264, item = 18657 }, output = { 18638, 1 }, reagents = { {7080, 6}, {7910, 4}, {11371, 4}, {12800, 2}, {18631, 3} }, skillrange = { 290, 310, 320, 330 } },  -- Hyper-Radiant Flame Reflector
        [ 19825] = { category = "Cloth Armor", source = { kind = "drop", npc = 8900, zone = 1584, item = 16053 }, output = { 16008, 1 }, reagents = { {10500, 1}, {12364, 2}, {12810, 4} }, skillrange = { 290, 310, 320, 330 } },  -- Master Engineer's Goggles
        [ 19819] = { category = "Engineered Item", source = { kind = "drop", npc = 10426, zone = 2017, item = 16052 }, output = { 16009, 1 }, reagents = { {10558, 1}, {12799, 1}, {15994, 1}, {16006, 2} }, skillrange = { 290, 310, 320, 330 } },  -- Voice Amplification Modulator
        [ 19833] = { category = "Gun", source = { kind = "drop", npc = 8561, zone = 139, item = 16056 }, output = { 16007, 1 }, reagents = { {7076, 2}, {7078, 2}, {12360, 10}, {12800, 2}, {12810, 2}, {16000, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Flawless Arcanite Rifle
        [ 22795] = { category = "Gun", source = { kind = "drop", zone = 2717, item = 18292 }, output = { 18282, 1 }, reagents = { {12360, 6}, {16000, 2}, {16006, 2}, {17010, 4}, {17011, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Core Marksman Rifle
        [ 19830] = { category = "Engineered Item", source = { kind = "drop", npc = 7437, zone = 618, item = 16054 }, output = { 16022, 1 }, reagents = { {10558, 4}, {10576, 1}, {12655, 10}, {12810, 6}, {15994, 6}, {16006, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Arcanite Dragonling
        [ 22797] = { category = "Shield", source = { kind = "drop", zone = 2717, item = 18291 }, output = { 18168, 1 }, reagents = { {7076, 8}, {7082, 8}, {12360, 6}, {12803, 12}, {16006, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Force Reactive Disk
        [ 23082] = { category = "Engineered Item", source = { kind = "drop", npc = 10426, zone = 2017, item = 18658 }, output = { 18639, 1 }, reagents = { {11371, 8}, {12799, 2}, {12800, 2}, {12803, 6}, {12808, 4}, {18631, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Ultra-Flash Shadow Reflector
        [ 24356] = { category = "Cloth Armor", source = { kind = "reputation", item = 20000, faction = "Zandalar Tribe", standing = "Honored" }, output = { 19999, 1 }, reagents = { {12804, 8}, {12810, 4}, {16006, 2}, {19726, 4}, {19774, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Bloodvine Goggles
        [ 24357] = { category = "Leather Armor", source = { kind = "reputation", item = 20001, faction = "Zandalar Tribe", standing = "Friendly" }, output = { 19998, 1 }, reagents = { {12804, 8}, {12810, 4}, {16006, 1}, {19726, 5}, {19774, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Bloodvine Lens
        [ 19831] = { category = "Material", source = { kind = "worldDrop", item = 16055 }, output = { 16040, 3 }, reagents = { {12359, 3}, {14047, 1}, {16006, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Arcane Bomb
        [ 22704] = { category = "Material", source = { kind = "drop", zone = 1584, item = 18235 }, output = { 18232, 1 }, reagents = { {7067, 2}, {7068, 1}, {7191, 1}, {8170, 4}, {12359, 12} }, skillrange = { 300, 320, 330, 340 } },  -- Field Repair Bot 74A
        [ 22793] = { category = "Item Enhancement", source = { kind = "drop", zone = 2717, item = 18290 }, output = { 18283, 1 }, reagents = { {7076, 2}, {11371, 6}, {16000, 1}, {16006, 4}, {17011, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Biznicks 247x128 Accurascope

    },
    HERBALISM       = {},
    LEATHERWORKING  = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  2881] = { category = "Material", source = { kind = "trainer" }, output = { 2318, 1 }, reagents = { {2934, 3} }, skillrange = {   1,  20,  30,  40 } },  -- Light Leather
        [  2149] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 2302, 1 }, reagents = { {2318, 2}, {2320, 1} }, skillrange = {   1,  40,  55,  70 } },  -- Handstitched Leather Boots
        [  7126] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 5957, 1 }, reagents = { {2318, 3}, {2320, 1} }, skillrange = {   1,  40,  55,  70 } },  -- Handstitched Leather Vest
        [  9058] = { category = "Cloak", source = { kind = "trainer" }, output = { 7276, 1 }, reagents = { {2318, 2}, {2320, 1} }, skillrange = {   1,  40,  55,  70 } },  -- Handstitched Leather Cloak
        [  9059] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7277, 1 }, reagents = { {2318, 2}, {2320, 3} }, skillrange = {   1,  40,  55,  70 } },  -- Handstitched Leather Bracers
        [  2152] = { category = "Item Enhancement", source = { kind = "trainer" }, output = { 2304, 1 }, reagents = { {2318, 1} }, skillrange = {   1,  30,  45,  60 } },  -- Light Armor Kit
        [  2153] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 2303, 1 }, reagents = { {2318, 4}, {2320, 1} }, skillrange = {  15,  45,  60,  75 } },  -- Handstitched Leather Pants
        [  3753] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4237, 1 }, reagents = { {2318, 6}, {2320, 1} }, skillrange = {  25,  55,  70,  85 } },  -- Handstitched Leather Belt
        [  9060] = { source = { kind = "trainer" }, output = { 7278, 1 }, reagents = { {2318, 4}, {2320, 2} }, skillrange = {  30,  60,  75,  90 } },  -- Light Leather Quiver
        [  9062] = { source = { kind = "trainer" }, output = { 7279, 1 }, reagents = { {2318, 3}, {2320, 4} }, skillrange = {  30,  60,  75,  90 } },  -- Small Leather Ammo Pouch
        [  3816] = { category = "Material", source = { kind = "trainer" }, output = { 4231, 1 }, reagents = { {783, 1}, {4289, 1} }, skillrange = {  35,  55,  65,  75 } },  -- Cured Light Hide
        [  9064] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7288 }, output = { 7280, 1 }, reagents = { {2318, 5}, {2320, 5} }, skillrange = {  35,  65,  80,  95 } },  -- Rugged Leather Pants
        [  2160] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 2300, 1 }, reagents = { {2318, 8}, {2320, 4} }, skillrange = {  40,  70,  85, 100 } },  -- Embossed Leather Vest
        [  5244] = { source = { kind = "quest", item = 5083, quest = 769 }, output = { 5081, 1 }, reagents = { {2318, 4}, {2320, 1}, {5082, 3} }, skillrange = {  40,  70,  85, 100 } },  -- Kodo Hide Bag
        [  2161] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 2309, 1 }, reagents = { {2318, 8}, {2320, 5} }, skillrange = {  55,  85, 100, 115 } },  -- Embossed Leather Boots
        [  3756] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4239, 1 }, reagents = { {2318, 3}, {2320, 2} }, skillrange = {  55,  85, 100, 115 } },  -- Embossed Leather Gloves
        [  2163] = { category = "Leather Armor", source = { kind = "worldDrop", item = 2407 }, output = { 2311, 1 }, reagents = { {2318, 8}, {2320, 2}, {2324, 1} }, skillrange = {  60,  90, 105, 120 } },  -- White Leather Jerkin
        [  2162] = { category = "Cloak", source = { kind = "trainer" }, output = { 2310, 1 }, reagents = { {2318, 5}, {2320, 2} }, skillrange = {  60,  90, 105, 120 } },  -- Embossed Leather Cloak
        [  9065] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7281, 1 }, reagents = { {2318, 6}, {2320, 4} }, skillrange = {  70, 100, 115, 130 } },  -- Light Leather Bracers
        [  2164] = { category = "Leather Armor", source = { kind = "worldDrop", item = 2408 }, output = { 2312, 1 }, reagents = { {2318, 4}, {2320, 2}, {4231, 1} }, skillrange = {  75, 105, 120, 135 } },  -- Fine Leather Gloves
        [  3759] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4242, 1 }, reagents = { {2318, 6}, {2320, 2}, {4231, 1} }, skillrange = {  75, 105, 120, 135 } },  -- Embossed Leather Pants
        [  3763] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4246, 1 }, reagents = { {2318, 6}, {2320, 2} }, skillrange = {  80, 110, 125, 140 } },  -- Fine Leather Belt
        [  3761] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4243, 1 }, reagents = { {2318, 6}, {2320, 4}, {4231, 3} }, skillrange = {  85, 115, 130, 145 } },  -- Fine Leather Tunic
        [  2159] = { category = "Cloak", source = { kind = "trainer" }, output = { 2308, 1 }, reagents = { {2318, 10}, {2321, 2} }, skillrange = {  85, 105, 120, 135 } },  -- Fine Leather Cloak
        [  2158] = { category = "Leather Armor", source = { kind = "worldDrop", item = 2406 }, output = { 2307, 1 }, reagents = { {2318, 7}, {2320, 2} }, skillrange = {  90, 120, 135, 150 } },  -- Fine Leather Boots
        [  6702] = { category = "Leather Armor", source = { kind = "vendor", npcA = 4186, npcH = 3556, item = 5786 }, output = { 5780, 1 }, reagents = { {2318, 6}, {2321, 1}, {5784, 8} }, skillrange = {  90, 120, 135, 150 } },  -- Murloc Scale Belt
        [  8322] = { category = "Leather Armor", source = { kind = "quest", item = 6710, quest = 1582 }, output = { 6709, 1 }, reagents = { {2318, 6}, {2320, 4}, {4231, 1}, {5498, 1} }, skillrange = {  90, 115, 130, 145 } },  -- Moonglow Vest
        [  7953] = { category = "Cloak", source = { kind = "vendor", npc = 5783, item = 6474 }, output = { 6466, 1 }, reagents = { {2321, 1}, {4231, 1}, {6470, 8} }, skillrange = {  90, 120, 135, 150 } },  -- Deviate Scale Cloak
        [  9068] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7282, 1 }, reagents = { {2318, 10}, {2321, 1}, {4231, 1} }, skillrange = {  95, 125, 140, 155 } },  -- Light Leather Pants
        [  6703] = { category = "Leather Armor", source = { kind = "vendor", npcA = 4186, npcH = 3556, item = 5787 }, output = { 5781, 1 }, reagents = { {2318, 8}, {2321, 1}, {4231, 1}, {5784, 12} }, skillrange = {  95, 125, 140, 155 } },  -- Murloc Scale Breastplate
        [ 20648] = { category = "Material", source = { kind = "trainer" }, output = { 2319, 1 }, reagents = { {2318, 4} }, skillrange = { 100, 100, 105, 110 } },  -- Medium Leather
        [  3762] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4293 }, output = { 4244, 1 }, reagents = { {2320, 2}, {4231, 2}, {4243, 1} }, skillrange = { 100, 125, 137, 150 } },  -- Hillman's Leather Vest
        [  3817] = { category = "Material", source = { kind = "trainer" }, output = { 4233, 1 }, reagents = { {4232, 1}, {4289, 1} }, skillrange = { 100, 115, 122, 130 } },  -- Cured Medium Hide
        [  2165] = { category = "Item Enhancement", source = { kind = "trainer" }, output = { 2313, 1 }, reagents = { {2319, 4}, {2320, 1} }, skillrange = { 100, 115, 122, 130 } },  -- Medium Armor Kit
        [  2167] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 2315, 1 }, reagents = { {2319, 4}, {2321, 2}, {4340, 1} }, skillrange = { 100, 125, 137, 150 } },  -- Dark Leather Boots
        [  2169] = { category = "Leather Armor", source = { kind = "worldDrop", item = 2409 }, output = { 2317, 1 }, reagents = { {2319, 6}, {2321, 1}, {4340, 1} }, skillrange = { 100, 125, 137, 150 } },  -- Dark Leather Tunic
        [ 24940] = { category = "Leather Armor", source = { kind = "vendor", npc = 777, item = 20576 }, output = { 20575, 1 }, reagents = { {2319, 8}, {2321, 2}, {4231, 1}, {7286, 8} }, skillrange = { 100, 125, 137, 150 } },  -- Black Whelp Tunic
        [  9070] = { category = "Cloak", source = { kind = "vendor", npc = 2697, item = 7289 }, output = { 7283, 1 }, reagents = { {2319, 4}, {2321, 1}, {7286, 12} }, skillrange = { 100, 125, 137, 150 } },  -- Black Whelp Cloak
        [  7133] = { category = "Leather Armor", source = { kind = "worldDrop", item = 5972 }, output = { 5958, 1 }, reagents = { {2319, 8}, {2321, 1}, {2997, 1} }, skillrange = { 105, 130, 142, 155 } },  -- Fine Leather Pants
        [  7954] = { category = "Leather Armor", source = { kind = "vendor", npc = 5783, item = 6475 }, output = { 6467, 1 }, reagents = { {2321, 2}, {6470, 6}, {6471, 2} }, skillrange = { 105, 130, 142, 155 } },  -- Deviate Scale Gloves
        [  2168] = { category = "Cloak", source = { kind = "trainer" }, output = { 2316, 1 }, reagents = { {2319, 8}, {2321, 1}, {4340, 1} }, skillrange = { 110, 135, 147, 160 } },  -- Dark Leather Cloak
        [  7135] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 5961, 1 }, reagents = { {2319, 12}, {2321, 1}, {4340, 1} }, skillrange = { 115, 140, 152, 165 } },  -- Dark Leather Pants
        [  7955] = { category = "Leather Armor", source = { kind = "quest", item = 6476, quest = 1487 }, output = { 6468, 1 }, reagents = { {2321, 2}, {6470, 10}, {6471, 10} }, skillrange = { 115, 140, 152, 165 } },  -- Deviate Scale Belt
        [  2166] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 2314, 1 }, reagents = { {2319, 10}, {2321, 2}, {4231, 2} }, skillrange = { 120, 145, 157, 170 } },  -- Toughened Leather Armor
        [  3765] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7360 }, output = { 4248, 1 }, reagents = { {2312, 1}, {2321, 1}, {4233, 1}, {4340, 1} }, skillrange = { 120, 155, 167, 180 } },  -- Dark Leather Gloves
        [  9072] = { category = "Leather Armor", source = { kind = "vendor", npc = 2679, item = 7290 }, output = { 7284, 1 }, reagents = { {2319, 4}, {2321, 1}, {7287, 6} }, skillrange = { 120, 145, 157, 170 } },  -- Red Whelp Gloves
        [  9074] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7285, 1 }, reagents = { {2319, 6}, {2321, 1}, {2457, 1} }, skillrange = { 120, 145, 157, 170 } },  -- Nimble Leather Gloves
        [  3767] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4294 }, output = { 4250, 1 }, reagents = { {2319, 8}, {2321, 2}, {3383, 1} }, skillrange = { 120, 145, 157, 170 } },  -- Hillman's Belt
        [  3766] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4249, 1 }, reagents = { {2321, 2}, {4233, 1}, {4246, 1}, {4340, 1} }, skillrange = { 125, 150, 162, 175 } },  -- Dark Leather Belt
        [  9145] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7348, 1 }, reagents = { {2319, 8}, {2321, 2}, {5116, 4} }, skillrange = { 125, 150, 162, 175 } },  -- Fletcher's Gloves
        [  3768] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4251, 1 }, reagents = { {2319, 4}, {2321, 1}, {4233, 1} }, skillrange = { 130, 155, 167, 180 } },  -- Hillman's Shoulders
        [  3770] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4253, 1 }, reagents = { {2319, 4}, {2321, 2}, {3182, 2}, {3389, 2}, {4233, 2} }, skillrange = { 135, 160, 172, 185 } },  -- Toughened Leather Gloves
        [  9147] = { category = "Leather Armor", source = { kind = "vendor", npc = 3537, item = 7362 }, output = { 7352, 1 }, reagents = { {2319, 6}, {2321, 2}, {7067, 1} }, skillrange = { 135, 160, 172, 185 } },  -- Earthen Leather Shoulders
        [  9146] = { category = "Leather Armor", source = { kind = "vendor", npc = 6731, item = 7361 }, output = { 7349, 1 }, reagents = { {2319, 8}, {2321, 2}, {3356, 4} }, skillrange = { 135, 160, 172, 185 } },  -- Herbalist's Gloves
        [  3769] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4296 }, output = { 4252, 1 }, reagents = { {2319, 12}, {2321, 2}, {3390, 1}, {4340, 1} }, skillrange = { 140, 165, 177, 190 } },  -- Dark Leather Shoulders
        [  9148] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7363 }, output = { 7358, 1 }, reagents = { {2319, 10}, {2321, 2}, {5373, 2} }, skillrange = { 140, 165, 177, 190 } },  -- Pilferer's Gloves
        [  3764] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4247, 1 }, reagents = { {2319, 14}, {2321, 4} }, skillrange = { 145, 170, 182, 195 } },  -- Hillman's Leather Gloves
        [  9149] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7364 }, output = { 7359, 1 }, reagents = { {2319, 12}, {2321, 2}, {2997, 2}, {7067, 2} }, skillrange = { 145, 170, 182, 195 } },  -- Heavy Earthen Gloves
        [ 20649] = { category = "Material", source = { kind = "trainer" }, output = { 4234, 1 }, reagents = { {2319, 5} }, skillrange = { 150, 150, 155, 160 } },  -- Heavy Leather
        [  3818] = { category = "Material", source = { kind = "trainer" }, output = { 4236, 1 }, reagents = { {4235, 1}, {4289, 3} }, skillrange = { 150, 160, 165, 170 } },  -- Cured Heavy Hide
        [  3780] = { category = "Item Enhancement", source = { kind = "trainer" }, output = { 4265, 1 }, reagents = { {2321, 1}, {4234, 5} }, skillrange = { 150, 170, 180, 190 } },  -- Heavy Armor Kit
        [  3760] = { category = "Cloak", source = { kind = "trainer" }, output = { 3719, 1 }, reagents = { {2321, 2}, {4234, 5} }, skillrange = { 150, 170, 180, 190 } },  -- Hillman's Cloak
        [  3771] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4297 }, output = { 4254, 1 }, reagents = { {2321, 1}, {4234, 6}, {5637, 2} }, skillrange = { 150, 170, 180, 190 } },  -- Barbaric Gloves
        [ 23190] = { category = "Oil", source = { kind = "vendor", npcA = 5128, npcH = 3366, item = 18731 }, output = { 18662, 1 }, reagents = { {2321, 1}, {4234, 2} }, skillrange = { 150, 150, 155, 160 } },  -- Heavy Leather Ball
        [  9193] = { source = { kind = "trainer" }, output = { 7371, 1 }, reagents = { {2321, 2}, {4234, 8} }, skillrange = { 150, 170, 180, 190 } },  -- Heavy Quiver
        [  9194] = { source = { kind = "trainer" }, output = { 7372, 1 }, reagents = { {2321, 2}, {4234, 8} }, skillrange = { 150, 170, 180, 190 } },  -- Heavy Leather Ammo Pouch
        [  3772] = { category = "Leather Armor", source = { kind = "vendor", npcA = 2679, npcH = 2698, item = 7613 }, output = { 4255, 1 }, reagents = { {2321, 4}, {2605, 2}, {4234, 9} }, skillrange = { 155, 175, 185, 195 } },  -- Green Leather Armor
        [ 23399] = { category = "Leather Armor", source = { kind = "vendor", npcA = 4225, npcH = 4589, item = 18949 }, output = { 18948, 1 }, reagents = { {4234, 8}, {4236, 2}, {4461, 1}, {5498, 4}, {5637, 4} }, skillrange = { 155, 175, 185, 195 } },  -- Barbaric Bracers
        [  3774] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4257, 1 }, reagents = { {2321, 1}, {2605, 1}, {4234, 5}, {4236, 1}, {7071, 1} }, skillrange = { 160, 180, 190, 200 } },  -- Green Leather Belt
        [  7147] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 5962, 1 }, reagents = { {2321, 2}, {4234, 12}, {4305, 2} }, skillrange = { 160, 180, 190, 200 } },  -- Guardian Pants
        [  4096] = { category = "Leather Armor", source = { kind = "vendor", npc = 2819, item = 13287 }, output = { 4455, 1 }, reagents = { {2321, 2}, {4234, 4}, {4461, 6} }, skillrange = { 165, 185, 195, 205 } },  -- Raptor Hide Harness
        [  4097] = { category = "Leather Armor", source = { kind = "vendor", npc = 2816, item = 13288 }, output = { 4456, 1 }, reagents = { {2321, 2}, {4234, 4}, {4461, 4} }, skillrange = { 165, 185, 195, 205 } },  -- Raptor Hide Belt
        [  9195] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7449 }, output = { 7373, 1 }, reagents = { {2321, 2}, {2325, 1}, {4234, 10} }, skillrange = { 165, 185, 195, 205 } },  -- Dusky Leather Leggings
        [  3775] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4298 }, output = { 4258, 1 }, reagents = { {2321, 1}, {4234, 4}, {4236, 2}, {7071, 1} }, skillrange = { 170, 190, 200, 210 } },  -- Guardian Belt
        [  6704] = { category = "Leather Armor", source = { kind = "vendor", npc = 2846, item = 5788 }, output = { 5782, 1 }, reagents = { {2321, 3}, {4234, 10}, {4236, 1}, {5785, 12} }, skillrange = { 170, 190, 200, 210 } },  -- Thick Murloc Armor
        [  7149] = { category = "Leather Armor", source = { kind = "vendor", npcA = 3958, npcH = 2821, item = 5973 }, output = { 5963, 1 }, reagents = { {1206, 1}, {2321, 2}, {4234, 10} }, skillrange = { 170, 190, 200, 210 } },  -- Barbaric Leggings
        [  3773] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4299 }, output = { 4256, 1 }, reagents = { {2321, 2}, {3824, 1}, {4234, 12}, {4236, 2} }, skillrange = { 175, 195, 205, 215 } },  -- Guardian Armor
        [  7151] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 5964, 1 }, reagents = { {2321, 2}, {4234, 8}, {4236, 1} }, skillrange = { 175, 195, 205, 215 } },  -- Barbaric Shoulders
        [  9196] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7374, 1 }, reagents = { {2321, 2}, {3824, 1}, {4234, 10} }, skillrange = { 175, 195, 205, 215 } },  -- Dusky Leather Armor
        [  9197] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7450 }, output = { 7375, 1 }, reagents = { {2321, 2}, {4234, 10}, {7392, 4} }, skillrange = { 175, 195, 205, 215 } },  -- Green Whelp Armor
        [  3776] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 4259, 1 }, reagents = { {2321, 1}, {2605, 1}, {4234, 6}, {4236, 2} }, skillrange = { 180, 200, 210, 220 } },  -- Green Leather Bracers
        [  9198] = { category = "Cloak", source = { kind = "trainer" }, output = { 7377, 1 }, reagents = { {2321, 2}, {4234, 6}, {7067, 2}, {7070, 2} }, skillrange = { 180, 200, 210, 220 } },  -- Frost Leather Cloak
        [  9201] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7378, 1 }, reagents = { {2325, 1}, {4234, 16}, {4291, 2} }, skillrange = { 185, 205, 215, 225 } },  -- Dusky Bracers
        [  3778] = { category = "Leather Armor", source = { kind = "vendor", npc = 2699, item = 14635 }, output = { 4262, 1 }, reagents = { {1529, 2}, {2321, 1}, {3864, 1}, {4236, 4}, {5500, 2} }, skillrange = { 185, 205, 215, 225 } },  -- Gem-studded Leather Belt
        [  7153] = { category = "Cloak", source = { kind = "worldDrop", item = 5974 }, output = { 5965, 1 }, reagents = { {4234, 14}, {4291, 2}, {4305, 2} }, skillrange = { 185, 205, 215, 225 } },  -- Guardian Cloak
        [  6661] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 5739, 1 }, reagents = { {2321, 2}, {4234, 14}, {7071, 1} }, skillrange = { 190, 210, 220, 230 } },  -- Barbaric Harness
        [  7156] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 5966, 1 }, reagents = { {4234, 4}, {4236, 1}, {4291, 1} }, skillrange = { 190, 210, 220, 230 } },  -- Guardian Gloves
        [  6705] = { category = "Leather Armor", source = { kind = "vendor", npc = 2846, item = 5789 }, output = { 5783, 1 }, reagents = { {4234, 14}, {4236, 1}, {4291, 1}, {5785, 16} }, skillrange = { 190, 210, 220, 230 } },  -- Murloc Scale Bracers
        [  9202] = { category = "Leather Armor", source = { kind = "vendor", npcA = 4225, npcH = 4589, item = 7451 }, output = { 7386, 1 }, reagents = { {4234, 8}, {4291, 2}, {7392, 6} }, skillrange = { 190, 210, 220, 230 } },  -- Green Whelp Bracers
        [ 21943] = { category = "Leather Armor", source = { kind = "worldDrop", item = 17722 }, output = { 17721, 1 }, reagents = { {4234, 8}, {4291, 1}, {7067, 4} }, skillrange = { 190, 210, 220, 230 } },  -- Gloves of the Greatfather
        [  9206] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 7387, 1 }, reagents = { {2325, 2}, {4234, 10}, {4305, 2}, {7071, 1} }, skillrange = { 195, 215, 225, 235 } },  -- Dusky Belt
        [  3777] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4300 }, output = { 4260, 1 }, reagents = { {4234, 6}, {4236, 2}, {4291, 1} }, skillrange = { 195, 215, 225, 235 } },  -- Guardian Leather Bracers
        [ 20650] = { category = "Material", source = { kind = "trainer" }, output = { 4304, 1 }, reagents = { {4234, 6} }, skillrange = { 200, 200, 202, 205 } },  -- Thick Leather
        [  3779] = { category = "Leather Armor", source = { kind = "worldDrop", item = 4301 }, output = { 4264, 1 }, reagents = { {4096, 2}, {4234, 6}, {4236, 2}, {4291, 1}, {5633, 1}, {7071, 1} }, skillrange = { 200, 220, 230, 240 } },  -- Barbaric Belt
        [  9207] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7452 }, output = { 7390, 1 }, reagents = { {3824, 1}, {4234, 8}, {4291, 2}, {7428, 2} }, skillrange = { 200, 220, 230, 240 } },  -- Dusky Boots
        [ 10490] = { category = "Leather Armor", source = { kind = "worldDrop", item = 8384 }, output = { 8174, 1 }, reagents = { {4234, 12}, {4236, 2}, {4291, 2} }, skillrange = { 200, 220, 230, 240 } },  -- Comfortable Leather Hat
        [ 10482] = { category = "Material", source = { kind = "trainer" }, output = { 8172, 1 }, reagents = { {8150, 1}, {8169, 1} }, skillrange = {   1,   1, 100, 200 } },  -- Cured Thick Hide
        [ 10487] = { category = "Item Enhancement", source = { kind = "trainer" }, output = { 8173, 1 }, reagents = { {4291, 1}, {4304, 5} }, skillrange = { 200, 220, 230, 240 } },  -- Thick Armor Kit
        [  9208] = { category = "Leather Armor", source = { kind = "worldDrop", item = 7453 }, output = { 7391, 1 }, reagents = { {2459, 2}, {4234, 10}, {4291, 1}, {4337, 2} }, skillrange = { 200, 220, 230, 240 } },  -- Swift Boots
        [ 22711] = { category = "Leather Armor", source = { kind = "vendor", npc = 2699, item = 18239 }, output = { 18238, 1 }, reagents = { {1210, 4}, {4236, 2}, {4304, 6}, {7428, 8}, {7971, 2}, {8343, 1} }, skillrange = { 200, 210, 220, 230 } },  -- Shadowskin Gloves
        [ 10499] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 8175, 1 }, reagents = { {4291, 2}, {4304, 7} }, skillrange = { 205, 225, 235, 245 } },  -- Nightscape Tunic
        [ 10507] = { category = "Leather Armor", source = { kind = "trainer" }, output = { 8176, 1 }, reagents = { {4291, 2}, {4304, 5} }, skillrange = { 205, 225, 235, 245 } },  -- Nightscape Headband
        [ 10509] = { category = "Mail Armor", source = { kind = "vendor", npcA = 7852, npcH = 7854, item = 8385 }, output = { 8187, 1 }, reagents = { {4304, 6}, {8167, 8}, {8343, 1} }, skillrange = { 205, 225, 235, 245 } },  -- Turtle Scale Gloves
        [ 10518] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 8198, 1 }, reagents = { {4304, 8}, {8167, 12}, {8343, 1} }, skillrange = { 210, 230, 240, 250 } },  -- Turtle Scale Bracers
        [ 10516] = { category = "Leather Armor", source = { kind = "vendor", npcA = 8160, npcH = 7854, item = 8409 }, output = { 8192, 1 }, reagents = { {4291, 3}, {4304, 8}, {4338, 6} }, skillrange = { 210, 230, 240, 250 } },  -- Nightscape Shoulders
        [ 10511] = { category = "Mail Armor", source = { kind = "trainer" }, output = { 8189, 1 }, reagents = { {4304, 6}, {8167, 12}, {8343, 1} }, skillrange = { 210, 230, 240, 250 } },  -- Turtle Scale Breastplate
        [ 10520] = { category = "Leather Armor", source = { kind = "worldDrop", item = 8386 }, output = { 8200, 1 }, reagents = { {4304, 10}, {8151, 4}, {8343, 1} }, skillrange = { 215, 235, 245, 255 } },  -- Big Voodoo Robe
        [ 10525] = { category = "Mail Armor", source = { kind = "drop", npc = 5618, zone = 440, item = 8395 }, output = { 8203, 1 }, reagents = { {4291, 4}, {4304, 12}, {8154, 12} }, skillrange = { 220, 240, 250, 260 } },  -- Tough Scorpid Breastplate
        [ 10533] = { category = "Mail Armor", source = { kind = "drop", npc = 5617, zone = 440, item = 8397 }, output = { 8205, 1 }, reagents = { {4291, 2}, {4304, 10}, {8154, 4} }, skillrange = { 220, 240, 250, 260 } },  -- Tough Scorpid Bracers
        [ 10531] = { category = "Leather Armor", source = { kind = "worldDrop", item = 8387 }, output = { 8201, 1 }, reagents = { {4304, 8}, {8151, 6}, {8343, 1} }, skillrange = { 220, 240, 250, 260 } },  -- Big Voodoo Mask
        [ 10529] = { category = "Leather Armor", source = { kind = "quest", item = 8403, quest = 2848 }, output = { 8210, 1 }, reagents = { {4304, 10}, {8153, 1}, {8172, 1} }, skillrange = { 220, 240, 250, 260 } },  -- Wild Leather Shoulders
        [ 10542] = { category = "Mail Armor", source = { kind = "drop", npc = 5616, zone = 440, item = 8398 }, output = { 8204, 1 }, reagents = { {4291, 2}, {4304, 6}, {8154, 8} }, skillrange = { 225, 245, 255, 265 } },  -- Tough Scorpid Gloves
        [ 10544] = { category = "Leather Armor", source = { kind = "quest", item = 8404, quest = 2849 }, output = { 8211, 1 }, reagents = { {4304, 12}, {8153, 2}, {8172, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Wild Leather Vest
        [ 10546] = { category = "Leather Armor", source = { kind = "quest", item = 8405, quest = 2850 }, output = { 8214, 1 }, reagents = { {4304, 10}, {8153, 2}, {8172, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Wild Leather Helmet
        [ 10621] = { category = "Leather Armor", source = { kind = "vendor", npcA = 7870, npcH = 7871 }, output = { 8345, 1 }, reagents = { {4304, 18}, {8146, 8}, {8172, 2}, {8343, 4}, {8368, 2} }, skillrange = { 225, 245, 255, 265 } },  -- Wolfshead Helm
        [ 10619] = { category = "Mail Armor", source = { kind = "vendor", npc = 7866 }, output = { 8347, 1 }, reagents = { {4304, 24}, {8165, 12}, {8172, 2}, {8343, 4} }, skillrange = { 225, 245, 255, 265 } },  -- Dragonscale Gauntlets
        [ 14930] = { source = { kind = "trainer" }, output = { 8217, 1 }, reagents = { {4291, 4}, {4304, 12}, {8172, 1}, {8949, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Quickdraw Quiver
        [ 14932] = { source = { kind = "trainer" }, output = { 8218, 1 }, reagents = { {4291, 6}, {4304, 10}, {8172, 1}, {8951, 1} }, skillrange = { 225, 245, 255, 265 } },  -- Thick Leather Ammo Pouch
        [ 10548] = { category = "Leather Armor", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 8193, 1 }, reagents = { {4291, 4}, {4304, 14} }, skillrange = { 230, 250, 260, 270 } },  -- Nightscape Pants
        [ 10630] = { category = "Leather Armor", source = { kind = "vendor", npc = 7868 }, output = { 8346, 1 }, reagents = { {4304, 20}, {7075, 2}, {7079, 8}, {8172, 1}, {8343, 4} }, skillrange = { 230, 250, 260, 270 } },  -- Gauntlets of the Sea
        [ 10552] = { category = "Mail Armor", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 8191, 1 }, reagents = { {4304, 14}, {8167, 24}, {8343, 1} }, skillrange = { 230, 250, 260, 270 } },  -- Turtle Scale Helm
        [ 10556] = { category = "Mail Armor", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 8185, 1 }, reagents = { {4304, 14}, {8167, 28}, {8343, 1} }, skillrange = { 235, 255, 265, 275 } },  -- Turtle Scale Leggings
        [ 10558] = { category = "Leather Armor", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 8197, 1 }, reagents = { {4304, 16}, {8343, 2} }, skillrange = { 235, 255, 265, 275 } },  -- Nightscape Boots
        [ 10554] = { category = "Mail Armor", source = { kind = "drop", npc = 5615, zone = 440, item = 8399 }, output = { 8209, 1 }, reagents = { {4291, 6}, {4304, 12}, {8154, 12} }, skillrange = { 235, 255, 265, 275 } },  -- Tough Scorpid Boots
        [ 10564] = { category = "Mail Armor", source = { kind = "drop", zone = 440, item = 8400 }, output = { 8207, 1 }, reagents = { {4304, 12}, {8154, 16}, {8343, 2} }, skillrange = { 240, 260, 270, 280 } },  -- Tough Scorpid Shoulders
        [ 10560] = { category = "Leather Armor", source = { kind = "worldDrop", item = 8389 }, output = { 8202, 1 }, reagents = { {4304, 10}, {8152, 6}, {8343, 2} }, skillrange = { 240, 260, 270, 280 } },  -- Big Voodoo Pants
        [ 10562] = { category = "Cloak", source = { kind = "worldDrop", item = 8390 }, output = { 8216, 1 }, reagents = { {4304, 14}, {8152, 4}, {8343, 2} }, skillrange = { 240, 260, 270, 280 } },  -- Big Voodoo Cloak
        [ 10568] = { category = "Mail Armor", source = { kind = "drop", npc = 5615, zone = 440, item = 8401 }, output = { 8206, 1 }, reagents = { {4304, 14}, {8154, 8}, {8343, 2} }, skillrange = { 245, 265, 275, 285 } },  -- Tough Scorpid Leggings
        [ 10566] = { category = "Leather Armor", source = { kind = "quest", item = 8406, quest = 2851 }, output = { 8213, 1 }, reagents = { {4304, 14}, {8153, 4}, {8172, 2} }, skillrange = { 245, 265, 275, 285 } },  -- Wild Leather Boots
        [ 22331] = { category = "Material", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 8170, 1 }, reagents = { {4304, 6} }, skillrange = {   1,   1, 125, 250 } },  -- Rugged Leather
        [ 19047] = { category = "Material", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 15407, 1 }, reagents = { {8171, 1}, {15409, 1} }, skillrange = { 250, 250, 255, 260 } },  -- Cured Rugged Hide
        [ 19058] = { category = "Item Enhancement", source = { kind = "vendor", npcA = 11097, npcH = 11098 }, output = { 15564, 1 }, reagents = { {8170, 5} }, skillrange = { 250, 250, 260, 270 } },  -- Rugged Armor Kit
        [ 10632] = { category = "Leather Armor", source = { kind = "vendor", npcA = 7868, npcH = 7869 }, output = { 8348, 1 }, reagents = { {4304, 40}, {7075, 4}, {7077, 8}, {8172, 2}, {8343, 4} }, skillrange = { 250, 270, 280, 290 } },  -- Helm of Fire
        [ 10572] = { category = "Leather Armor", source = { kind = "quest", item = 8407, quest = 2852 }, output = { 8212, 1 }, reagents = { {4304, 16}, {8153, 6}, {8172, 2} }, skillrange = { 250, 270, 280, 290 } },  -- Wild Leather Leggings
        [ 10647] = { category = "Leather Armor", source = { kind = "vendor", npcA = 7870, npcH = 7871 }, output = { 8349, 1 }, reagents = { {4304, 40}, {7971, 2}, {8168, 40}, {8172, 4}, {8343, 4} }, skillrange = { 250, 270, 280, 290 } },  -- Feathered Breastplate
        [ 10570] = { category = "Mail Armor", source = { kind = "drop", zone = 440, item = 8402 }, output = { 8208, 1 }, reagents = { {4304, 10}, {8154, 20}, {8343, 2} }, skillrange = { 250, 270, 280, 290 } },  -- Tough Scorpid Helm
        [ 10574] = { category = "Cloak", source = { kind = "quest", item = 8408, quest = 2853 }, output = { 8215, 1 }, reagents = { {4304, 16}, {8153, 6}, {8172, 2} }, skillrange = { 250, 270, 280, 290 } },  -- Wild Leather Cloak
        [ 19048] = { category = "Mail Armor", source = { kind = "vendor", npc = 12956, item = 15724 }, output = { 15077, 1 }, reagents = { {8170, 4}, {14341, 1}, {15408, 4} }, skillrange = { 255, 275, 285, 295 } },  -- Heavy Scorpid Bracers
        [ 10650] = { category = "Mail Armor", source = { kind = "vendor", npc = 7866 }, output = { 8367, 1 }, reagents = { {4304, 40}, {8165, 30}, {8172, 4}, {8343, 4} }, skillrange = { 255, 275, 285, 295 } },  -- Dragonscale Breastplate
        [ 19050] = { category = "Mail Armor", source = { kind = "vendor", npc = 11874, item = 15726 }, output = { 15045, 1 }, reagents = { {8170, 20}, {14341, 2}, {15412, 25} }, skillrange = { 260, 280, 290, 300 } },  -- Green Dragonscale Breastplate
        [ 19049] = { category = "Leather Armor", source = { kind = "vendor", npcA = 12942, npcH = 12943, item = 15725 }, output = { 15083, 1 }, reagents = { {2325, 1}, {8170, 8}, {14341, 1} }, skillrange = { 260, 280, 290, 300 } },  -- Wicked Leather Gauntlets
        [ 19051] = { category = "Mail Armor", source = { kind = "drop", npc = 5981, zone = 4, item = 15727 }, output = { 15076, 1 }, reagents = { {8170, 6}, {14341, 1}, {15408, 6} }, skillrange = { 265, 285, 295, 305 } },  -- Heavy Scorpid Vest
        [ 19052] = { category = "Leather Armor", source = { kind = "drop", npc = 6201, zone = 16, item = 15728 }, output = { 15084, 1 }, reagents = { {2325, 1}, {8170, 8}, {14341, 1} }, skillrange = { 265, 285, 295, 305 } },  -- Wicked Leather Bracers
        [ 19053] = { category = "Leather Armor", source = { kind = "vendor", npc = 12957, item = 15729 }, output = { 15074, 1 }, reagents = { {8170, 6}, {14341, 1}, {15423, 6} }, skillrange = { 265, 285, 295, 305 } },  -- Chimeric Gloves
        [ 19059] = { category = "Leather Armor", source = { kind = "drop", npc = 7035, zone = 46, item = 15732 }, output = { 15054, 1 }, reagents = { {7075, 1}, {7078, 1}, {8170, 6}, {14341, 1} }, skillrange = { 270, 290, 300, 310 } },  -- Volcanic Leggings
        [ 19062] = { category = "Leather Armor", source = { kind = "vendor", npc = 12958, item = 15735 }, output = { 15067, 1 }, reagents = { {1529, 2}, {8170, 24}, {14341, 1}, {15420, 80} }, skillrange = { 270, 290, 300, 310 } },  -- Ironfeather Shoulders
        [ 19060] = { category = "Mail Armor", source = { kind = "drop", npc = 5226, zone = 1477, item = 15733 }, output = { 15046, 1 }, reagents = { {8170, 20}, {14341, 1}, {15412, 25} }, skillrange = { 270, 290, 300, 310 } },  -- Green Dragonscale Leggings
        [ 19061] = { category = "Leather Armor", source = { kind = "vendor", npcA = 7852, npcH = 7854, item = 15734 }, output = { 15061, 1 }, reagents = { {8170, 12}, {12803, 4}, {14341, 1} }, skillrange = { 270, 290, 300, 310 } },  -- Living Shoulders
        [ 19055] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15731 }, output = { 15091, 1 }, reagents = { {8170, 10}, {14047, 6}, {14341, 1} }, skillrange = { 270, 290, 300, 310 } },  -- Runic Leather Gauntlets
        [ 19067] = { category = "Leather Armor", source = { kind = "vendor", npcA = 12942, npcH = 12943, item = 15741 }, output = { 15057, 1 }, reagents = { {7080, 2}, {7082, 2}, {8170, 16}, {14341, 1} }, skillrange = { 275, 295, 305, 315 } },  -- Stormshroud Pants
        [ 19068] = { category = "Leather Armor", source = { kind = "reputation", item = 20253, faction = "Timbermaw Hold", standing = "Friendly" }, output = { 15064, 1 }, reagents = { {8170, 28}, {14341, 1}, {15419, 12} }, skillrange = { 275, 295, 305, 315 } },  -- Warbear Harness
        [ 19066] = { category = "Leather Armor", source = { kind = "vendor", npc = 11189, item = 15740 }, output = { 15071, 1 }, reagents = { {8170, 4}, {14341, 1}, {15422, 6} }, skillrange = { 275, 295, 305, 315 } },  -- Frostsaber Boots
        [ 19063] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15737 }, output = { 15073, 1 }, reagents = { {8170, 4}, {14341, 1}, {15423, 8} }, skillrange = { 275, 295, 305, 315 } },  -- Chimeric Boots
        [ 19064] = { category = "Mail Armor", source = { kind = "drop", npc = 7025, zone = 46, item = 15738 }, output = { 15078, 1 }, reagents = { {8170, 6}, {14341, 1}, {15408, 8} }, skillrange = { 275, 295, 305, 315 } },  -- Heavy Scorpid Gauntlets
        [ 19065] = { category = "Leather Armor", source = { kind = "drop", npc = 7112, zone = 361, item = 15739 }, output = { 15092, 1 }, reagents = { {7971, 1}, {8170, 6}, {14047, 6}, {14341, 1} }, skillrange = { 275, 295, 305, 315 } },  -- Runic Leather Bracers
        [ 24655] = { category = "Mail Armor", source = { kind = "vendor", npc = 7866 }, output = { 20296, 1 }, reagents = { {8170, 20}, {14341, 2}, {15407, 1}, {15412, 30} }, skillrange = { 280, 300, 310, 320 } },  -- Green Dragonscale Gauntlets
        [ 19073] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15746 }, output = { 15072, 1 }, reagents = { {8170, 8}, {14341, 1}, {15423, 8} }, skillrange = { 280, 300, 310, 320 } },  -- Chimeric Leggings
        [ 19070] = { category = "Mail Armor", source = { kind = "worldDrop", item = 15743 }, output = { 15082, 1 }, reagents = { {8170, 6}, {14341, 1}, {15408, 8} }, skillrange = { 280, 300, 310, 320 } },  -- Heavy Scorpid Belt
        [ 19071] = { category = "Leather Armor", source = { kind = "drop", npc = 7107, zone = 361, item = 15744 }, output = { 15086, 1 }, reagents = { {2325, 1}, {8170, 12}, {14341, 1} }, skillrange = { 280, 300, 310, 320 } },  -- Wicked Leather Headband
        [ 19072] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15745 }, output = { 15093, 1 }, reagents = { {8170, 12}, {14047, 10}, {14341, 1} }, skillrange = { 280, 300, 310, 320 } },  -- Runic Leather Belt
        [ 19076] = { category = "Leather Armor", source = { kind = "drop", npc = 9259, zone = 1583, item = 15749 }, output = { 15053, 1 }, reagents = { {7076, 1}, {7078, 1}, {8170, 8}, {14341, 1} }, skillrange = { 285, 305, 315, 325 } },  -- Volcanic Breastplate
        [ 19079] = { category = "Leather Armor", source = { kind = "drop", npc = 6138, zone = 16, item = 15753 }, output = { 15056, 1 }, reagents = { {7080, 3}, {7082, 3}, {8170, 16}, {14341, 1}, {15407, 1} }, skillrange = { 285, 305, 315, 325 } },  -- Stormshroud Armor
        [ 19077] = { category = "Mail Armor", source = { kind = "vendor", npc = 12957, item = 15751 }, output = { 15048, 1 }, reagents = { {8170, 28}, {14341, 1}, {15407, 1}, {15415, 30} }, skillrange = { 285, 305, 315, 325 } },  -- Blue Dragonscale Breastplate
        [ 19078] = { category = "Leather Armor", source = { kind = "drop", npc = 7158, zone = 361, item = 15752 }, output = { 15060, 1 }, reagents = { {8170, 16}, {12803, 6}, {14341, 1}, {15407, 1} }, skillrange = { 285, 305, 315, 325 } },  -- Living Leggings
        [ 19080] = { category = "Leather Armor", source = { kind = "reputation", item = 20254, faction = "Timbermaw Hold", standing = "Friendly" }, output = { 15065, 1 }, reagents = { {8170, 24}, {14341, 1}, {15419, 14} }, skillrange = { 285, 305, 315, 325 } },  -- Warbear Woolies
        [ 19074] = { category = "Leather Armor", source = { kind = "drop", npc = 7440, zone = 618, item = 15747 }, output = { 15069, 1 }, reagents = { {8170, 6}, {14341, 1}, {15422, 8} }, skillrange = { 285, 305, 315, 325 } },  -- Frostsaber Leggings
        [ 19075] = { category = "Mail Armor", source = { kind = "drop", npc = 7027, zone = 46, item = 15748 }, output = { 15079, 1 }, reagents = { {8170, 8}, {14341, 1}, {15408, 12} }, skillrange = { 285, 305, 315, 325 } },  -- Heavy Scorpid Leggings
        [ 22815] = { category = "Oil", source = { kind = "quest", quest = 5518 }, output = { 18258, 1 }, reagents = { {8170, 4}, {14048, 2}, {14341, 1}, {18240, 1} }, skillrange = { 285, 285, 290, 295 } },  -- Gordok Ogre Suit
        [ 19084] = { category = "Leather Armor", source = { kind = "vendor", npc = 12959, item = 15758 }, output = { 15063, 1 }, reagents = { {8170, 30}, {14341, 1}, {15417, 8} }, skillrange = { 290, 310, 320, 330 } },  -- Devilsaur Gauntlets
        [ 19086] = { category = "Leather Armor", source = { kind = "drop", npc = 2644, zone = 47, item = 15760 }, output = { 15066, 1 }, reagents = { {1529, 1}, {8170, 40}, {14341, 1}, {15407, 1}, {15420, 120} }, skillrange = { 290, 310, 320, 330 } },  -- Ironfeather Breastplate
        [ 19085] = { category = "Mail Armor", source = { kind = "vendor", npc = 9499, item = 15759 }, output = { 15050, 1 }, reagents = { {8170, 40}, {14341, 2}, {15407, 1}, {15416, 60} }, skillrange = { 290, 310, 320, 330 } },  -- Black Dragonscale Breastplate
        [ 19081] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15755 }, output = { 15075, 1 }, reagents = { {8170, 10}, {14341, 1}, {15423, 10} }, skillrange = { 290, 310, 320, 330 } },  -- Chimeric Vest
        [ 23703] = { category = "Leather Armor", source = { kind = "reputation", item = 19326, faction = "Timbermaw Hold", standing = "Honored" }, output = { 19044, 1 }, reagents = { {8170, 30}, {12803, 4}, {12804, 2}, {14341, 2}, {15407, 2} }, skillrange = { 290, 310, 320, 330 } },  -- Might of the Timbermaw
        [ 19083] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15757 }, output = { 15087, 1 }, reagents = { {2325, 3}, {8170, 16}, {14341, 1}, {15407, 1} }, skillrange = { 290, 310, 320, 330 } },  -- Wicked Leather Pants
        [ 19082] = { category = "Leather Armor", source = { kind = "vendor", npc = 12941, item = 15756 }, output = { 15094, 1 }, reagents = { {8170, 14}, {14047, 10}, {14341, 1} }, skillrange = { 290, 310, 320, 330 } },  -- Runic Leather Headband
        [ 23705] = { category = "Leather Armor", source = { kind = "reputation", item = 19328, faction = "Argent Dawn", standing = "Honored" }, output = { 19052, 1 }, reagents = { {7080, 4}, {8170, 30}, {12809, 2}, {14341, 2}, {15407, 2} }, skillrange = { 290, 310, 320, 330 } },  -- Dawn Treaders
        [ 19090] = { category = "Leather Armor", source = { kind = "drop", npc = 6144, zone = 16, item = 15764 }, output = { 15058, 1 }, reagents = { {7080, 3}, {7082, 3}, {8170, 12}, {12810, 2}, {14341, 1} }, skillrange = { 295, 315, 325, 335 } },  -- Stormshroud Shoulders
        [ 19089] = { category = "Mail Armor", source = { kind = "drop", npc = 6146, zone = 16, item = 15763 }, output = { 15049, 1 }, reagents = { {8170, 28}, {12810, 2}, {14341, 1}, {15407, 1}, {15415, 30} }, skillrange = { 295, 315, 325, 335 } },  -- Blue Dragonscale Shoulders
        [ 20853] = { category = "Leather Armor", source = { kind = "reputation", item = 17022, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16982, 1 }, reagents = { {14341, 2}, {17010, 6}, {17011, 2}, {17012, 20} }, skillrange = { 295, 315, 325, 335 } },  -- Corehound Boots
        [ 19087] = { category = "Leather Armor", source = { kind = "drop", npc = 7441, zone = 618, item = 15761 }, output = { 15070, 1 }, reagents = { {8170, 6}, {14341, 1}, {15422, 10} }, skillrange = { 295, 315, 325, 335 } },  -- Frostsaber Gloves
        [ 19088] = { category = "Mail Armor", source = { kind = "vendor", npc = 12956, item = 15762 }, output = { 15080, 1 }, reagents = { {8170, 8}, {14341, 1}, {15407, 1}, {15408, 12} }, skillrange = { 295, 315, 325, 335 } },  -- Heavy Scorpid Helm
        [ 19101] = { category = "Leather Armor", source = { kind = "drop", npc = 9260, zone = 1583, item = 15775 }, output = { 15055, 1 }, reagents = { {7076, 1}, {7078, 1}, {8170, 10}, {14341, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Volcanic Shoulders
        [ 26279] = { category = "Leather Armor", source = { kind = "worldDrop", item = 21548 }, output = { 21278, 1 }, reagents = { {7080, 4}, {7082, 4}, {12810, 6}, {14227, 2}, {15407, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Stormshroud Gloves
        [ 19097] = { category = "Leather Armor", source = { kind = "drop", zone = 490, item = 15772 }, output = { 15062, 1 }, reagents = { {8170, 30}, {14341, 1}, {15407, 1}, {15417, 14} }, skillrange = { 300, 320, 330, 340 } },  -- Devilsaur Leggings
        [ 24121] = { category = "Leather Armor", source = { kind = "reputation", item = 19769, faction = "Zandalar Tribe", standing = "Revered" }, output = { 19685, 1 }, reagents = { {12803, 4}, {14341, 4}, {15407, 5}, {19767, 14} }, skillrange = { 300, 320, 330, 340 } },  -- Primal Batskin Jerkin
        [ 24123] = { category = "Leather Armor", source = { kind = "reputation", item = 19771, faction = "Zandalar Tribe", standing = "Friendly" }, output = { 19687, 1 }, reagents = { {12803, 4}, {14341, 3}, {15407, 3}, {19767, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Primal Batskin Bracers
        [ 24122] = { category = "Leather Armor", source = { kind = "reputation", item = 19770, faction = "Zandalar Tribe", standing = "Honored" }, output = { 19686, 1 }, reagents = { {12803, 4}, {14341, 3}, {15407, 4}, {19767, 10} }, skillrange = { 300, 320, 330, 340 } },  -- Primal Batskin Gloves
        [ 24124] = { category = "Leather Armor", source = { kind = "reputation", item = 19772, faction = "Zandalar Tribe", standing = "Revered" }, output = { 19688, 1 }, reagents = { {14341, 3}, {15407, 3}, {19726, 2}, {19768, 35} }, skillrange = { 300, 320, 330, 340 } },  -- Blood Tiger Breastplate
        [ 24125] = { category = "Leather Armor", source = { kind = "reputation", item = 19773, faction = "Zandalar Tribe", standing = "Honored" }, output = { 19689, 1 }, reagents = { {14341, 3}, {15407, 3}, {19726, 2}, {19768, 25} }, skillrange = { 300, 320, 330, 340 } },  -- Blood Tiger Shoulders
        [ 20855] = { category = "Mail Armor", source = { kind = "reputation", item = 17025, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16984, 1 }, reagents = { {12810, 6}, {14341, 2}, {15416, 30}, {17010, 4}, {17011, 3} }, skillrange = { 300, 320, 330, 340 } },  -- Black Dragonscale Boots
        [ 19107] = { category = "Mail Armor", source = { kind = "drop", npc = 8903, zone = 1584, item = 15781 }, output = { 15052, 1 }, reagents = { {8170, 40}, {12810, 4}, {14341, 2}, {15407, 1}, {15416, 60} }, skillrange = { 300, 320, 330, 340 } },  -- Black Dragonscale Leggings
        [ 19094] = { category = "Mail Armor", source = { kind = "drop", npc = 8898, zone = 1584, item = 15770 }, output = { 15051, 1 }, reagents = { {8170, 44}, {12810, 2}, {14341, 1}, {15407, 1}, {15416, 45} }, skillrange = { 300, 320, 330, 340 } },  -- Black Dragonscale Shoulders
        [ 24654] = { category = "Mail Armor", source = { kind = "vendor", npc = 7866 }, output = { 20295, 1 }, reagents = { {8170, 28}, {14341, 2}, {15407, 2}, {15415, 36} }, skillrange = { 300, 320, 330, 340 } },  -- Blue Dragonscale Leggings
        [ 19095] = { category = "Leather Armor", source = { kind = "drop", npc = 1813, zone = 28, item = 15771 }, output = { 15059, 1 }, reagents = { {8170, 16}, {12803, 8}, {14341, 2}, {14342, 2}, {15407, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Living Breastplate
        [ 28219] = { category = "Leather Armor", source = { kind = "vendor", npc = 16365 }, output = { 22661, 1 }, reagents = { {7080, 2}, {12810, 16}, {14227, 4}, {15407, 4}, {22682, 7} }, skillrange = { 300, 320, 330, 340 } },  -- Polar Tunic
        [ 28220] = { category = "Leather Armor", source = { kind = "vendor", npc = 16365 }, output = { 22662, 1 }, reagents = { {7080, 2}, {12810, 12}, {14227, 4}, {15407, 3}, {22682, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Polar Gloves
        [ 28221] = { category = "Leather Armor", source = { kind = "vendor", npc = 16365 }, output = { 22663, 1 }, reagents = { {7080, 2}, {12810, 12}, {14227, 4}, {15407, 2}, {22682, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Polar Bracers
        [ 28222] = { category = "Mail Armor", source = { kind = "vendor", npc = 16365 }, output = { 22664, 1 }, reagents = { {7080, 2}, {14227, 4}, {15407, 4}, {15408, 24}, {22682, 7} }, skillrange = { 300, 320, 330, 340 } },  -- Icy Scale Breastplate
        [ 28224] = { category = "Mail Armor", source = { kind = "vendor", npc = 16365 }, output = { 22665, 1 }, reagents = { {7080, 2}, {14227, 4}, {15407, 2}, {15408, 16}, {22682, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Icy Scale Bracers
        [ 28223] = { category = "Mail Armor", source = { kind = "vendor", npc = 16365 }, output = { 22666, 1 }, reagents = { {7080, 2}, {14227, 4}, {15407, 3}, {15408, 16}, {22682, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Icy Scale Gauntlets
        [ 19054] = { category = "Mail Armor", source = { kind = "drop", npc = 10363, zone = 1583, item = 15730 }, output = { 15047, 1 }, reagents = { {8170, 40}, {14341, 1}, {15414, 30} }, skillrange = { 300, 320, 330, 340 } },  -- Red Dragonscale Breastplate
        [ 19104] = { category = "Leather Armor", source = { kind = "drop", npc = 7438, zone = 618, item = 15779 }, output = { 15068, 1 }, reagents = { {8170, 12}, {14341, 2}, {15407, 1}, {15422, 12} }, skillrange = { 300, 320, 330, 340 } },  -- Frostsaber Tunic
        [ 23704] = { category = "Leather Armor", source = { kind = "reputation", item = 19327, faction = "Timbermaw Hold", standing = "Revered" }, output = { 19049, 1 }, reagents = { {12803, 6}, {12804, 6}, {12810, 8}, {14227, 2}, {15407, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Timbermaw Brawlers
        [ 28473] = { category = "Leather Armor", source = { kind = "reputation", item = 22770, faction = "Cenarion Circle", standing = "Honored" }, output = { 22760, 1 }, reagents = { {12803, 2}, {12810, 6}, {15407, 2}, {18512, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Bramblewood Boots
        [ 28474] = { category = "Leather Armor", source = { kind = "reputation", item = 22769, faction = "Cenarion Circle", standing = "Friendly" }, output = { 22761, 1 }, reagents = { {12803, 2}, {12810, 4}, {15407, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Bramblewood Belt
        [ 19092] = { category = "Leather Armor", source = { kind = "drop", npc = 10406, zone = 2017, item = 15768 }, output = { 15088, 1 }, reagents = { {2325, 2}, {8170, 14}, {14341, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Wicked Leather Belt
        [ 19091] = { category = "Leather Armor", source = { kind = "worldDrop", item = 15765 }, output = { 15095, 1 }, reagents = { {8170, 18}, {12810, 2}, {14047, 12}, {14341, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Leather Pants
        [ 19093] = { category = "Cloak", source = { kind = "quest", quest = 7497 }, output = { 15138, 1 }, reagents = { {14044, 1}, {14341, 1}, {15410, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Onyxia Scale Cloak
        [ 20854] = { category = "Leather Armor", source = { kind = "reputation", item = 17023, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16983, 1 }, reagents = { {14341, 2}, {17010, 3}, {17011, 6}, {17012, 15} }, skillrange = { 300, 320, 330, 340 } },  -- Molten Helm
        [ 22922] = { category = "Leather Armor", source = { kind = "drop", zone = 2557, item = 18515 }, output = { 18506, 1 }, reagents = { {7082, 6}, {8170, 12}, {11754, 4}, {14341, 4}, {15407, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Mongoose Boots
        [ 22927] = { category = "Cloak", source = { kind = "drop", zone = 2557, item = 18518 }, output = { 18510, 1 }, reagents = { {7080, 10}, {8170, 30}, {12803, 12}, {14341, 8}, {15407, 3}, {18512, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Hide of the Wild
        [ 22928] = { category = "Cloak", source = { kind = "drop", zone = 2557, item = 18519 }, output = { 18511, 1 }, reagents = { {7082, 12}, {8170, 30}, {12753, 4}, {12809, 8}, {14341, 8}, {15407, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Shifting Cloak
        [ 23707] = { category = "Leather Armor", source = { kind = "reputation", item = 19330, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19149, 1 }, reagents = { {14227, 4}, {15407, 4}, {17011, 5} }, skillrange = { 300, 320, 330, 340 } },  -- Lava Belt
        [ 23708] = { category = "Mail Armor", source = { kind = "reputation", item = 19331, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19157, 1 }, reagents = { {12607, 4}, {14227, 4}, {15407, 4}, {17010, 5}, {17011, 2}, {17012, 4} }, skillrange = { 300, 320, 330, 340 } },  -- Chromatic Gauntlets
        [ 23709] = { category = "Leather Armor", source = { kind = "reputation", item = 19332, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19162, 1 }, reagents = { {12810, 10}, {14227, 4}, {15407, 4}, {17010, 8}, {17012, 12} }, skillrange = { 300, 320, 330, 340 } },  -- Corehound Belt
        [ 23710] = { category = "Leather Armor", source = { kind = "reputation", item = 19333, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19163, 1 }, reagents = { {7076, 6}, {14227, 4}, {15407, 4}, {17010, 2}, {17011, 7} }, skillrange = { 300, 320, 330, 340 } },  -- Molten Belt
        [ 24851] = { category = "Mail Armor", source = { kind = "reputation", item = 20511, faction = "Cenarion Circle", standing = "Revered" }, output = { 20478, 1 }, reagents = { {15407, 2}, {18512, 2}, {20498, 40}, {20501, 3} }, skillrange = { 300, 320, 330, 340 } },  -- Sandstalker Breastplate
        [ 28472] = { category = "Leather Armor", source = { kind = "reputation", item = 22771, faction = "Cenarion Circle", standing = "Revered" }, output = { 22759, 1 }, reagents = { {12803, 2}, {12810, 12}, {15407, 2}, {19726, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Bramblewood Helm
        [ 19098] = { category = "Leather Armor", source = { kind = "drop", npc = 10499, zone = 2057, item = 15773 }, output = { 15085, 1 }, reagents = { {2325, 4}, {8170, 20}, {14256, 6}, {14341, 2}, {15407, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Wicked Leather Armor
        [ 19102] = { category = "Leather Armor", source = { kind = "drop", npc = 11582, zone = 2057, item = 15776 }, output = { 15090, 1 }, reagents = { {8170, 22}, {12810, 4}, {14047, 16}, {14341, 2}, {15407, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Leather Armor
        [ 19103] = { category = "Leather Armor", source = { kind = "drop", npc = 10425, zone = 2017, item = 15777 }, output = { 15096, 1 }, reagents = { {8170, 16}, {12810, 4}, {14047, 18}, {14341, 2}, {15407, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Runic Leather Shoulders
        [ 22921] = { category = "Leather Armor", source = { kind = "drop", zone = 2557, item = 18514 }, output = { 18504, 1 }, reagents = { {8170, 12}, {12804, 12}, {14341, 4}, {15407, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Girdle of Insight
        [ 23706] = { category = "Leather Armor", source = { kind = "reputation", item = 19329, faction = "Argent Dawn", standing = "Revered" }, output = { 19058, 1 }, reagents = { {12803, 4}, {12809, 4}, {12810, 8}, {14341, 2}, {15407, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Golden Mantle of the Dawn
        [ 19100] = { category = "Mail Armor", source = { kind = "drop", npc = 7029, zone = 46, item = 15774 }, output = { 15081, 1 }, reagents = { {8170, 14}, {14341, 2}, {15407, 1}, {15408, 14} }, skillrange = { 300, 320, 330, 340 } },  -- Heavy Scorpid Shoulders
        [ 22923] = { category = "Mail Armor", source = { kind = "drop", zone = 2557, item = 18516 }, output = { 18508, 1 }, reagents = { {8170, 12}, {14341, 4}, {15407, 4}, {15420, 60}, {18512, 8} }, skillrange = { 300, 320, 330, 340 } },  -- Swift Flight Bracers
        [ 24703] = { category = "Mail Armor", source = { kind = "reputation", item = 20382, faction = "Cenarion Circle", standing = "Exalted" }, output = { 20380, 1 }, reagents = { {12803, 4}, {12810, 12}, {14227, 6}, {15407, 4}, {20381, 6} }, skillrange = { 300, 320, 330, 340 } },  -- Dreamscale Breastplate
        [ 24849] = { category = "Mail Armor", source = { kind = "reputation", item = 20509, faction = "Cenarion Circle", standing = "Friendly" }, output = { 20476, 1 }, reagents = { {18512, 2}, {20498, 20}, {20501, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Sandstalker Bracers
        [ 24850] = { category = "Mail Armor", source = { kind = "reputation", item = 20510, faction = "Cenarion Circle", standing = "Honored" }, output = { 20477, 1 }, reagents = { {15407, 1}, {18512, 2}, {20498, 30}, {20501, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Sandstalker Gauntlets
        [ 24848] = { category = "Mail Armor", source = { kind = "reputation", item = 20508, faction = "Cenarion Circle", standing = "Revered" }, output = { 20479, 1 }, reagents = { {7078, 2}, {15407, 2}, {20498, 40}, {20500, 3} }, skillrange = { 300, 320, 330, 340 } },  -- Spitfire Breastplate
        [ 24847] = { category = "Mail Armor", source = { kind = "reputation", item = 20507, faction = "Cenarion Circle", standing = "Honored" }, output = { 20480, 1 }, reagents = { {7078, 2}, {15407, 1}, {20498, 30}, {20500, 2} }, skillrange = { 300, 320, 330, 340 } },  -- Spitfire Gauntlets
        [ 24846] = { category = "Mail Armor", source = { kind = "reputation", item = 20506, faction = "Cenarion Circle", standing = "Friendly" }, output = { 20481, 1 }, reagents = { {7078, 2}, {20498, 20}, {20500, 1} }, skillrange = { 300, 320, 330, 340 } },  -- Spitfire Bracers
        [ 22926] = { category = "Cloak", source = { kind = "drop", zone = 2557, item = 18517 }, output = { 18509, 1 }, reagents = { {8170, 30}, {12607, 12}, {14341, 8}, {15407, 5}, {15414, 30}, {15416, 30} }, skillrange = { 300, 320, 330, 340 } },  -- Chromatic Cloak
        [ 22727] = { category = "Item Enhancement", source = { kind = "drop", zone = 2717, item = 18252 }, output = { 18251, 1 }, reagents = { {14341, 2}, {17012, 3} }, skillrange = { 300, 320, 330, 340 } },  -- Core Armor Kit

    },
    MINING          = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  2657] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 2840, 1 }, reagents = { {2770, 1} }, skillrange = {   1,  25,  47,  70 } },  -- Smelt Copper
        [  2659] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 2841, 2 }, reagents = { {2840, 1}, {3576, 1} }, skillrange = {  65,  65,  90, 115 } },  -- Smelt Bronze
        [  3304] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3576, 1 }, reagents = { {2771, 1} }, skillrange = {  65,  65,  70,  75 } },  -- Smelt Tin
        [  2658] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 2842, 1 }, reagents = { {2775, 1} }, skillrange = {  75, 115, 122, 130 } },  -- Smelt Silver
        [  3307] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3575, 1 }, reagents = { {2772, 1} }, skillrange = { 125, 130, 135, 140 } },  -- Smelt Iron
        [  3308] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3577, 1 }, reagents = { {2776, 1} }, skillrange = { 155, 170, 177, 185 } },  -- Smelt Gold
        [  3569] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3859, 1 }, reagents = { {3575, 1}, {3857, 1} }, skillrange = { 165, 165, 165, 165 } },  -- Smelt Steel
        [ 10097] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 3860, 1 }, reagents = { {3858, 1} }, skillrange = { 175, 175, 202, 230 } },  -- Smelt Mithril
        [ 14891] = { category = "Trade Goods", source = { kind = "quest", quest = 4083 }, output = { 11371, 1 }, reagents = { {11370, 8} }, skillrange = { 300, 300, 305, 310 } },  -- Smelt Dark Iron
        [ 10098] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 6037, 1 }, reagents = { {7911, 1} }, skillrange = { 230, 250, 270, 290 } },  -- Smelt Truesilver
        [ 16153] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 12359, 1 }, reagents = { {10620, 1} }, skillrange = { 250, 250, 270, 290 } },  -- Smelt Thorium
        [ 22967] = { category = "Trade Goods", source = { kind = "vendor", npc = 14401 }, output = { 17771, 1 }, reagents = { {12360, 10}, {17010, 1}, {18562, 1}, {18567, 3} }, skillrange = { 300, 350, 362, 375 } },  -- Smelt Elementium

    },
    SKINNING        = {},
    TAILORING       = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  2963] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 2996, 1 }, reagents = { {2589, 2} }, skillrange = {   1,  25,  37,  50 } },  -- Bolt of Linen Cloth
        [ 12044] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10045, 1 }, reagents = { {2320, 1}, {2996, 1} }, skillrange = {   1,  35,  47,  60 } },  -- Simple Linen Pants
        [  2387] = { category = "Cloak", source = { kind = "trainer" }, output = { 2570, 1 }, reagents = { {2320, 1}, {2996, 1} }, skillrange = {   1,  35,  47,  60 } },  -- Linen Cloak
        [  2393] = { category = "Shirt", source = { kind = "trainer" }, output = { 2576, 1 }, reagents = { {2320, 1}, {2324, 1}, {2996, 1} }, skillrange = {   1,  35,  47,  60 } },  -- White Linen Shirt
        [  3915] = { category = "Shirt", source = { kind = "trainer" }, output = { 4344, 1 }, reagents = { {2320, 1}, {2996, 1} }, skillrange = {   1,  35,  47,  60 } },  -- Brown Linen Shirt
        [  2385] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 2568, 1 }, reagents = { {2320, 1}, {2996, 1} }, skillrange = {  10,  45,  57,  70 } },  -- Brown Linen Vest
        [  8776] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7026, 1 }, reagents = { {2320, 1}, {2996, 1} }, skillrange = {  15,  50,  67,  85 } },  -- Linen Belt
        [ 12045] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10046, 1 }, reagents = { {2318, 1}, {2320, 1}, {2996, 2} }, skillrange = {  20,  50,  67,  85 } },  -- Simple Linen Boots
        [  3914] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4343, 1 }, reagents = { {2320, 1}, {2996, 2} }, skillrange = {  30,  55,  72,  90 } },  -- Brown Linen Pants
        [  7623] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 6238, 1 }, reagents = { {2320, 1}, {2996, 3} }, skillrange = {  30,  55,  72,  90 } },  -- Brown Linen Robe
        [  7624] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 6241, 1 }, reagents = { {2320, 1}, {2324, 1}, {2996, 3} }, skillrange = {  30,  55,  72,  90 } },  -- White Linen Robe
        [  3840] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4307, 1 }, reagents = { {2320, 1}, {2996, 2} }, skillrange = {  35,  60,  77,  95 } },  -- Heavy Linen Gloves
        [  2389] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 2598 }, output = { 2572, 1 }, reagents = { {2320, 2}, {2604, 2}, {2996, 3} }, skillrange = {  40,  65,  82, 100 } },  -- Red Linen Robe
        [  2392] = { category = "Shirt", source = { kind = "trainer" }, output = { 2575, 1 }, reagents = { {2320, 1}, {2604, 1}, {2996, 2} }, skillrange = {  40,  65,  82, 100 } },  -- Red Linen Shirt
        [  2394] = { category = "Shirt", source = { kind = "trainer" }, output = { 2577, 1 }, reagents = { {2320, 1}, {2996, 2}, {6260, 1} }, skillrange = {  40,  65,  82, 100 } },  -- Blue Linen Shirt
        [  8465] = { category = "Misc Armor", source = { kind = "trainer" }, output = { 6786, 1 }, reagents = { {2320, 1}, {2324, 1}, {2996, 2}, {6260, 1} }, skillrange = {  40,  65,  82, 100 } },  -- Simple Dress
        [  3755] = { category = "Bag", source = { kind = "trainer" }, output = { 4238, 1 }, reagents = { {2320, 3}, {2996, 3} }, skillrange = {  45,  70,  87, 105 } },  -- Linen Bag
        [  7629] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 6271 }, output = { 6239, 1 }, reagents = { {2320, 1}, {2604, 1}, {2996, 3} }, skillrange = {  55,  80,  97, 115 } },  -- Red Linen Vest
        [  7630] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 4189, npcH = 3364, item = 6270 }, output = { 6240, 1 }, reagents = { {2320, 1}, {2996, 3}, {6260, 1} }, skillrange = {  55,  80,  97, 115 } },  -- Blue Linen Vest
        [  2397] = { category = "Cloak", source = { kind = "trainer" }, output = { 2580, 1 }, reagents = { {2320, 3}, {2996, 2} }, skillrange = {  60,  85, 102, 120 } },  -- Reinforced Linen Cape
        [  3841] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4308, 1 }, reagents = { {2320, 2}, {2605, 1}, {2996, 3} }, skillrange = {  60,  85, 102, 120 } },  -- Green Linen Bracers
        [  2386] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 2569, 1 }, reagents = { {2318, 1}, {2320, 1}, {2996, 3} }, skillrange = {  65,  90, 107, 125 } },  -- Linen Boots
        [  2395] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 2578, 1 }, reagents = { {2318, 1}, {2321, 1}, {2996, 4} }, skillrange = {  70,  95, 112, 130 } },  -- Barbaric Linen Vest
        [  3842] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4309, 1 }, reagents = { {2321, 2}, {2996, 4} }, skillrange = {  70,  95, 112, 130 } },  -- Handstitched Linen Britches
        [  7633] = { category = "Cloth Armor", source = { kind = "vendor", npc = 3499, item = 6272 }, output = { 6242, 1 }, reagents = { {2320, 2}, {2996, 4}, {6260, 2} }, skillrange = {  70,  95, 112, 130 } },  -- Blue Linen Robe
        [  2396] = { category = "Shirt", source = { kind = "trainer" }, output = { 2579, 1 }, reagents = { {2321, 1}, {2605, 1}, {2996, 3} }, skillrange = {  70,  95, 112, 130 } },  -- Green Linen Shirt
        [  6686] = { category = "Bag", source = { kind = "vendor", npcA = 4189, npcH = 3556, item = 5771 }, output = { 5762, 1 }, reagents = { {2321, 1}, {2604, 1}, {2996, 4} }, skillrange = {  70,  95, 112, 130 } },  -- Red Linen Bag
        [  2964] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 2997, 1 }, reagents = { {2592, 3} }, skillrange = {  75,  90,  97, 105 } },  -- Bolt of Woolen Cloth
        [ 12046] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10047, 1 }, reagents = { {2321, 1}, {2996, 4} }, skillrange = {  75, 100, 117, 135 } },  -- Simple Kilt
        [  2402] = { category = "Cloak", source = { kind = "trainer" }, output = { 2584, 1 }, reagents = { {2321, 1}, {2997, 1} }, skillrange = {  75, 100, 117, 135 } },  -- Woolen Cape
        [  3845] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4312, 1 }, reagents = { {2318, 2}, {2321, 1}, {2996, 5} }, skillrange = {  80, 105, 122, 140 } },  -- Soft-soled Linen Boots
        [  3757] = { category = "Bag", source = { kind = "trainer" }, output = { 4240, 1 }, reagents = { {2321, 1}, {2997, 3} }, skillrange = {  80, 105, 122, 140 } },  -- Woolen Bag
        [  3843] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4310, 1 }, reagents = { {2321, 1}, {2997, 3} }, skillrange = {  85, 110, 127, 145 } },  -- Heavy Woolen Gloves
        [  2399] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 2582, 1 }, reagents = { {2321, 2}, {2605, 1}, {2997, 2} }, skillrange = {  85, 110, 127, 145 } },  -- Green Woolen Vest
        [  6521] = { category = "Cloak", source = { kind = "trainer" }, output = { 5542, 1 }, reagents = { {2321, 2}, {2997, 3}, {5498, 1} }, skillrange = {  90, 115, 132, 150 } },  -- Pearl-clasped Cloak
        [  3847] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4345 }, output = { 4313, 1 }, reagents = { {2318, 2}, {2321, 1}, {2604, 2}, {2997, 4} }, skillrange = {  95, 120, 137, 155 } },  -- Red Woolen Boots
        [  3758] = { category = "Bag", source = { kind = "worldDrop", item = 4292 }, output = { 4241, 1 }, reagents = { {2321, 1}, {2605, 1}, {2997, 4} }, skillrange = {  95, 120, 137, 155 } },  -- Green Woolen Bag
        [  2401] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 2583, 1 }, reagents = { {2318, 2}, {2321, 2}, {2997, 4} }, skillrange = {  95, 120, 137, 155 } },  -- Woolen Boots
        [  7639] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 843, npcH = 3364, item = 6274 }, output = { 6263, 1 }, reagents = { {2321, 2}, {2997, 4}, {6260, 2} }, skillrange = { 100, 125, 142, 160 } },  -- Blue Overalls
        [  3844] = { category = "Cloak", source = { kind = "worldDrop", item = 4346 }, output = { 4311, 1 }, reagents = { {2321, 2}, {2997, 3}, {5498, 2} }, skillrange = { 100, 125, 142, 160 } },  -- Heavy Woolen Cloak
        [  2406] = { category = "Shirt", source = { kind = "trainer" }, output = { 2587, 1 }, reagents = { {2321, 1}, {2997, 2}, {4340, 1} }, skillrange = { 100, 110, 120, 130 } },  -- Gray Woolen Shirt
        [  2403] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 2601 }, output = { 2585, 1 }, reagents = { {2321, 3}, {2997, 4}, {4340, 1} }, skillrange = { 105, 130, 147, 165 } },  -- Gray Woolen Robe
        [  3848] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4314, 1 }, reagents = { {2321, 2}, {2997, 3} }, skillrange = { 110, 135, 152, 170 } },  -- Double-stitched Woolen Shoulders
        [  3850] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4316, 1 }, reagents = { {2321, 4}, {2997, 5} }, skillrange = { 110, 135, 152, 170 } },  -- Heavy Woolen Pants
        [  8467] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 6787, 1 }, reagents = { {2321, 1}, {2324, 4}, {2997, 3} }, skillrange = { 110, 135, 152, 170 } },  -- White Woolen Dress
        [  3866] = { category = "Shirt", source = { kind = "trainer" }, output = { 4330, 1 }, reagents = { {2321, 1}, {2604, 2}, {2997, 3} }, skillrange = { 110, 135, 152, 170 } },  -- Stylish Red Shirt
        [  7643] = { category = "Cloth Armor", source = { kind = "vendor", npc = 3499, item = 6275 }, output = { 6264, 1 }, reagents = { {2321, 3}, {2604, 3}, {2997, 5} }, skillrange = { 115, 140, 157, 175 } },  -- Greater Adept's Robe
        [  6688] = { category = "Bag", source = { kind = "vendor", npc = 3537, item = 5772 }, output = { 5763, 1 }, reagents = { {2321, 1}, {2604, 1}, {2997, 4} }, skillrange = { 115, 140, 157, 175 } },  -- Red Woolen Bag
        [  3849] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4347 }, output = { 4315, 1 }, reagents = { {2319, 2}, {2321, 2}, {2997, 6} }, skillrange = { 120, 145, 162, 180 } },  -- Reinforced Woolen Shoulders
        [ 12047] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10316 }, output = { 10048, 1 }, reagents = { {2321, 1}, {2604, 3}, {2997, 5} }, skillrange = { 120, 145, 162, 180 } },  -- Colorful Kilt
        [  7892] = { category = "Shirt", source = { kind = "worldDrop", item = 6390 }, output = { 6384, 1 }, reagents = { {2321, 1}, {2997, 4}, {4340, 1}, {6260, 2} }, skillrange = { 120, 145, 162, 180 } },  -- Stylish Blue Shirt
        [  7893] = { category = "Shirt", source = { kind = "worldDrop", item = 6391 }, output = { 6385, 1 }, reagents = { {2321, 1}, {2605, 2}, {2997, 4}, {4340, 1} }, skillrange = { 120, 145, 162, 180 } },  -- Stylish Green Shirt
        [  3855] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4320, 1 }, reagents = { {2319, 4}, {3182, 4}, {4305, 2}, {5500, 2} }, skillrange = { 125, 150, 167, 185 } },  -- Spidersilk Boots
        [  3839] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 4305, 1 }, reagents = { {4306, 4} }, skillrange = { 125, 135, 140, 145 } },  -- Bolt of Silk Cloth
        [  3851] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4349 }, output = { 4317, 1 }, reagents = { {2321, 3}, {2997, 6}, {5500, 1} }, skillrange = { 125, 150, 167, 185 } },  -- Phoenix Pants
        [  3868] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4348 }, output = { 4331, 1 }, reagents = { {2321, 4}, {2324, 2}, {2997, 4}, {5500, 1} }, skillrange = { 125, 150, 167, 185 } },  -- Phoenix Gloves
        [  3852] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4318, 1 }, reagents = { {2321, 3}, {2997, 4}, {3383, 1} }, skillrange = { 130, 150, 165, 180 } },  -- Gloves of Meditation
        [  6690] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 5766, 1 }, reagents = { {2321, 2}, {3182, 2}, {4305, 2} }, skillrange = { 135, 155, 170, 185 } },  -- Lesser Wizard's Robe
        [  3869] = { category = "Shirt", source = { kind = "vendor", npc = 2668, item = 14627 }, output = { 4332, 1 }, reagents = { {2321, 1}, {4305, 1}, {4341, 1} }, skillrange = { 135, 145, 150, 155 } },  -- Bright Yellow Shirt
        [  8758] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7046, 1 }, reagents = { {2321, 3}, {4305, 4}, {6260, 2} }, skillrange = { 140, 160, 175, 190 } },  -- Azure Silk Pants
        [  3856] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4350 }, output = { 4321, 1 }, reagents = { {2321, 2}, {3182, 1}, {4305, 3} }, skillrange = { 140, 160, 175, 190 } },  -- Spider Silk Slippers
        [  3854] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 2679, npcH = 9636, item = 7114 }, output = { 4319, 1 }, reagents = { {2321, 2}, {4234, 2}, {4305, 3}, {6260, 2} }, skillrange = { 145, 165, 180, 195 } },  -- Azure Silk Gloves
        [  8780] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 7092 }, output = { 7047, 1 }, reagents = { {2321, 2}, {4234, 2}, {4305, 3}, {6048, 2} }, skillrange = { 145, 165, 180, 195 } },  -- Hands of Darkness
        [  8760] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7048, 1 }, reagents = { {2321, 1}, {4305, 2}, {6260, 2} }, skillrange = { 145, 155, 160, 165 } },  -- Azure Silk Hood
        [  3859] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 4324, 1 }, reagents = { {4305, 5}, {6260, 4} }, skillrange = { 150, 170, 185, 200 } },  -- Azure Silk Vest
        [  6692] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 5773 }, output = { 5770, 1 }, reagents = { {2321, 2}, {3182, 2}, {4305, 4} }, skillrange = { 150, 170, 185, 200 } },  -- Robes of Arcana
        [  8782] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 7091 }, output = { 7049, 1 }, reagents = { {929, 4}, {2321, 1}, {4234, 2}, {4305, 3} }, skillrange = { 150, 170, 185, 200 } },  -- Truefaith Gloves
        [  3813] = { category = "Bag", source = { kind = "trainer" }, output = { 4245, 1 }, reagents = { {2321, 3}, {4234, 2}, {4305, 3} }, skillrange = { 150, 170, 185, 200 } },  -- Small Silk Pack
        [  3870] = { category = "Shirt", source = { kind = "vendor", npcA = 2669, npcH = 2394, item = 6401 }, output = { 4333, 1 }, reagents = { {2321, 1}, {4305, 2}, {4340, 2} }, skillrange = { 155, 165, 170, 175 } },  -- Dark Silk Shirt
        [  8762] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7050, 1 }, reagents = { {2321, 2}, {4305, 3} }, skillrange = { 160, 170, 175, 180 } },  -- Silk Headband
        [  8483] = { category = "Shirt", source = { kind = "trainer" }, output = { 6795, 1 }, reagents = { {2324, 2}, {4291, 1}, {4305, 3} }, skillrange = { 160, 170, 175, 180 } },  -- White Swashbuckler's Shirt
        [  3857] = { category = "Cloth Armor", source = { kind = "vendor", npc = 12246, item = 14630 }, output = { 4322, 1 }, reagents = { {2321, 2}, {4305, 3}, {4337, 2} }, skillrange = { 165, 185, 200, 215 } },  -- Enchanter's Cowl
        [  8784] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 7090 }, output = { 7065, 1 }, reagents = { {2605, 2}, {4291, 1}, {4305, 5} }, skillrange = { 165, 185, 200, 215 } },  -- Green Silk Armor
        [  8764] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7051, 1 }, reagents = { {2321, 2}, {4305, 3}, {7067, 1} }, skillrange = { 170, 190, 205, 220 } },  -- Earthen Vest
        [  3871] = { category = "Shirt", source = { kind = "trainer" }, output = { 4334, 1 }, reagents = { {2321, 1}, {2324, 2}, {4305, 3} }, skillrange = { 170, 180, 185, 190 } },  -- Formal White Shirt
        [  3858] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4351 }, output = { 4323, 1 }, reagents = { {3824, 1}, {4291, 1}, {4305, 4} }, skillrange = { 170, 190, 205, 220 } },  -- Shadow Hood
        [  3865] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 4339, 1 }, reagents = { {4338, 5} }, skillrange = { 175, 180, 182, 185 } },  -- Bolt of Mageweave
        [  8772] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7055, 1 }, reagents = { {2604, 2}, {4291, 1}, {4305, 4}, {7071, 1} }, skillrange = { 175, 195, 210, 225 } },  -- Crimson Silk Belt
        [  8766] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7052, 1 }, reagents = { {2321, 2}, {4305, 4}, {6260, 2}, {7070, 1}, {7071, 1} }, skillrange = { 175, 195, 210, 225 } },  -- Azure Silk Belt
        [  8786] = { category = "Cloak", source = { kind = "vendor", npcA = 6576, npcH = 6574, item = 7089 }, output = { 7053, 1 }, reagents = { {2321, 2}, {4305, 3}, {6260, 2} }, skillrange = { 175, 195, 210, 225 } },  -- Azure Silk Cloak
        [  8489] = { category = "Shirt", source = { kind = "trainer" }, output = { 6796, 1 }, reagents = { {2604, 2}, {4291, 1}, {4305, 3} }, skillrange = { 175, 185, 190, 195 } },  -- Red Swashbuckler's Shirt
        [  6693] = { category = "Bag", source = { kind = "worldDrop", item = 5774 }, output = { 5764, 1 }, reagents = { {2321, 3}, {2605, 1}, {4234, 3}, {4305, 4} }, skillrange = { 175, 195, 210, 225 } },  -- Green Silk Pack
        [  3860] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4352 }, output = { 4325, 1 }, reagents = { {4291, 1}, {4305, 4}, {4337, 2} }, skillrange = { 175, 195, 210, 225 } },  -- Boots of the Enchanter
        [  3863] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4353 }, output = { 4328, 1 }, reagents = { {4305, 4}, {4337, 2}, {7071, 1} }, skillrange = { 180, 200, 215, 230 } },  -- Spider Belt
        [  8774] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7057, 1 }, reagents = { {4291, 2}, {4305, 5} }, skillrange = { 180, 200, 215, 230 } },  -- Green Silken Shoulders
        [  8789] = { category = "Cloak", source = { kind = "vendor", npc = 12246, item = 7087 }, output = { 7056, 1 }, reagents = { {2604, 2}, {4291, 1}, {4305, 5}, {6371, 2} }, skillrange = { 180, 200, 215, 230 } },  -- Crimson Silk Cloak
        [  8791] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7058, 1 }, reagents = { {2321, 2}, {2604, 2}, {4305, 4} }, skillrange = { 185, 205, 215, 225 } },  -- Crimson Silk Vest
        [  3861] = { category = "Cloak", source = { kind = "trainer" }, output = { 4326, 1 }, reagents = { {3827, 1}, {4291, 1}, {4305, 4} }, skillrange = { 185, 205, 220, 235 } },  -- Long Silken Cloak
        [  3872] = { category = "Shirt", source = { kind = "worldDrop", item = 4354 }, output = { 4335, 1 }, reagents = { {4291, 1}, {4305, 4}, {4342, 1} }, skillrange = { 185, 195, 200, 205 } },  -- Rich Purple Silk Shirt
        [  6695] = { category = "Bag", source = { kind = "worldDrop", item = 5775 }, output = { 5765, 1 }, reagents = { {2321, 4}, {2325, 1}, {4305, 5} }, skillrange = { 185, 205, 220, 235 } },  -- Black Silk Pack
        [  8770] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7054, 1 }, reagents = { {4291, 2}, {4339, 2}, {7067, 2}, {7068, 2}, {7069, 2}, {7070, 2} }, skillrange = { 190, 210, 225, 240 } },  -- Robe of Power
        [  8795] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 7085 }, output = { 7060, 1 }, reagents = { {4291, 2}, {4305, 6}, {6260, 2}, {7072, 2} }, skillrange = { 190, 210, 225, 240 } },  -- Azure Shoulders
        [ 21945] = { category = "Shirt", source = { kind = "worldDrop", item = 17724, event = "Feast of Winter Veil" }, output = { 17723, 1 }, reagents = { {2605, 4}, {4291, 1}, {4305, 5} }, skillrange = { 190, 200, 205, 210 } },  -- Green Holiday Shirt
        [  8793] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 7084 }, output = { 7059, 1 }, reagents = { {2604, 2}, {4291, 2}, {4305, 5}, {6371, 2} }, skillrange = { 190, 210, 225, 240 } },  -- Crimson Silk Shoulders
        [  8797] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 7086 }, output = { 7061, 1 }, reagents = { {4234, 4}, {4291, 2}, {4305, 5}, {7067, 4}, {7071, 1} }, skillrange = { 195, 215, 230, 245 } },  -- Earthen Silk Belt
        [  8799] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7062, 1 }, reagents = { {2604, 2}, {4291, 2}, {4305, 4} }, skillrange = { 195, 215, 225, 235 } },  -- Crimson Silk Pantaloons
        [  3862] = { category = "Cloak", source = { kind = "vendor", npcA = 2381, npcH = 6567, item = 4355 }, output = { 4327, 1 }, reagents = { {3829, 1}, {4291, 2}, {4337, 2}, {4339, 3} }, skillrange = { 200, 220, 235, 250 } },  -- Icy Cloak
        [  3864] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 4356 }, output = { 4329, 1 }, reagents = { {3864, 1}, {4234, 4}, {4291, 1}, {4339, 4}, {7071, 1} }, skillrange = { 200, 220, 235, 250 } },  -- Star Belt
        [  3873] = { category = "Shirt", source = { kind = "vendor", npc = 2663, item = 10728 }, output = { 4336, 1 }, reagents = { {2325, 1}, {4291, 1}, {4305, 5} }, skillrange = { 200, 210, 215, 220 } },  -- Black Swashbuckler's Shirt
        [ 12048] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 9998, 1 }, reagents = { {4291, 3}, {4339, 2} }, skillrange = { 205, 220, 235, 250 } },  -- Black Mageweave Vest
        [ 12049] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 9999, 1 }, reagents = { {4291, 3}, {4339, 2} }, skillrange = { 205, 220, 235, 250 } },  -- Black Mageweave Leggings
        [  8802] = { category = "Cloth Armor", source = { kind = "vendor", npc = 6568, item = 7088 }, output = { 7063, 1 }, reagents = { {2604, 4}, {3827, 2}, {4291, 1}, {4305, 8}, {7068, 4} }, skillrange = { 205, 220, 235, 250 } },  -- Crimson Silk Robe
        [ 12052] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 9584, npcH = 4578 }, output = { 10002, 1 }, reagents = { {4339, 3}, {8343, 1}, {10285, 2} }, skillrange = { 210, 225, 240, 255 } },  -- Shadoweave Pants
        [ 12050] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10001, 1 }, reagents = { {4339, 3}, {8343, 1} }, skillrange = { 210, 225, 240, 255 } },  -- Black Mageweave Robe
        [  8804] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 7064, 1 }, reagents = { {2604, 4}, {4291, 2}, {4304, 2}, {4305, 6}, {6371, 2}, {7068, 2} }, skillrange = { 210, 225, 240, 255 } },  -- Crimson Silk Gloves
        [ 12053] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10003, 1 }, reagents = { {4339, 2}, {8343, 2} }, skillrange = { 215, 230, 245, 260 } },  -- Black Mageweave Gloves
        [ 12055] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 9584, npcH = 4578 }, output = { 10004, 1 }, reagents = { {4339, 3}, {8343, 1}, {10285, 2} }, skillrange = { 215, 230, 245, 260 } },  -- Shadoweave Robe
        [ 12059] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10301 }, output = { 10008, 1 }, reagents = { {2324, 1}, {4339, 1}, {8343, 1} }, skillrange = { 215, 220, 225, 230 } },  -- White Bandit Mask
        [ 12061] = { category = "Shirt", source = { kind = "trainer" }, output = { 10056, 1 }, reagents = { {4339, 1}, {6261, 1}, {8343, 1} }, skillrange = { 215, 220, 225, 230 } },  -- Orange Mageweave Shirt
        [ 12056] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10300 }, output = { 10007, 1 }, reagents = { {2604, 2}, {4339, 3}, {8343, 1} }, skillrange = { 215, 230, 245, 260 } },  -- Red Mageweave Vest
        [ 12060] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10302 }, output = { 10009, 1 }, reagents = { {2604, 2}, {4339, 3}, {8343, 1} }, skillrange = { 215, 230, 245, 260 } },  -- Red Mageweave Pants
        [ 12064] = { category = "Shirt", source = { kind = "vendor", npcA = 4168, npcH = 3005, item = 10311 }, output = { 10052, 1 }, reagents = { {4339, 2}, {6261, 2}, {8343, 1} }, skillrange = { 220, 225, 230, 235 } },  -- Orange Martial Shirt
        [ 12067] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10019, 1 }, reagents = { {4339, 4}, {8153, 4}, {8343, 2}, {10286, 2} }, skillrange = { 225, 240, 255, 270 } },  -- Dreamweave Gloves
        [ 12070] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10021, 1 }, reagents = { {4339, 6}, {8153, 6}, {8343, 2}, {10286, 2} }, skillrange = { 225, 240, 255, 270 } },  -- Dreamweave Vest
        [ 12066] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10312 }, output = { 10018, 1 }, reagents = { {2604, 2}, {4339, 3}, {8343, 2} }, skillrange = { 225, 240, 255, 270 } },  -- Red Mageweave Gloves
        [ 12071] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 9584, npcH = 4578 }, output = { 10023, 1 }, reagents = { {4339, 5}, {8343, 2}, {10285, 5} }, skillrange = { 225, 240, 255, 270 } },  -- Shadoweave Gloves
        [ 12069] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10042, 1 }, reagents = { {4339, 5}, {7077, 2}, {8343, 2} }, skillrange = { 225, 240, 255, 270 } },  -- Cindercloth Robe
        [ 12065] = { category = "Bag", source = { kind = "trainer" }, output = { 10050, 1 }, reagents = { {4291, 2}, {4339, 4} }, skillrange = { 225, 240, 255, 270 } },  -- Mageweave Bag
        [ 27658] = { category = "Bag", source = { kind = "vendor", npc = 15419, item = 22307 }, output = { 22246, 1 }, reagents = { {4339, 4}, {8343, 2}, {11137, 4} }, skillrange = { 225, 240, 255, 270 } },  -- Enchanted Mageweave Pouch
        [ 12073] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10026, 1 }, reagents = { {4304, 2}, {4339, 3}, {8343, 2} }, skillrange = { 230, 245, 260, 275 } },  -- Black Mageweave Boots
        [ 12072] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10024, 1 }, reagents = { {4339, 3}, {8343, 2} }, skillrange = { 230, 245, 260, 275 } },  -- Black Mageweave Headband
        [ 12074] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10027, 1 }, reagents = { {4339, 3}, {8343, 2} }, skillrange = { 230, 245, 260, 275 } },  -- Black Mageweave Shoulders
        [ 12075] = { category = "Shirt", source = { kind = "vendor", npcA = 8681, npcH = 3364, item = 10314 }, output = { 10054, 1 }, reagents = { {4339, 2}, {4342, 2}, {8343, 2} }, skillrange = { 230, 235, 240, 245 } },  -- Lavender Mageweave Shirt
        [ 12076] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 9584, npcH = 4578 }, output = { 10028, 1 }, reagents = { {4339, 5}, {8343, 2}, {10285, 4} }, skillrange = { 235, 250, 265, 280 } },  -- Shadoweave Shoulders
        [ 12078] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10315 }, output = { 10029, 1 }, reagents = { {2604, 2}, {4339, 4}, {8343, 3} }, skillrange = { 235, 250, 265, 280 } },  -- Red Mageweave Shoulders
        [ 12080] = { category = "Shirt", source = { kind = "vendor", npcA = 8681, npcH = 3364, item = 10317 }, output = { 10055, 1 }, reagents = { {4339, 3}, {8343, 1}, {10290, 1} }, skillrange = { 235, 240, 245, 250 } },  -- Pink Mageweave Shirt
        [ 12077] = { category = "Misc Armor", source = { kind = "trainer" }, output = { 10053, 1 }, reagents = { {2324, 1}, {2325, 1}, {4339, 3}, {8343, 1} }, skillrange = { 235, 240, 245, 250 } },  -- Simple Black Dress
        [ 12079] = { category = "Bag", source = { kind = "trainer" }, output = { 10051, 1 }, reagents = { {2604, 2}, {4339, 4}, {8343, 2} }, skillrange = { 235, 250, 265, 280 } },  -- Red Mageweave Bag
        [ 12081] = { category = "Cloth Armor", source = { kind = "vendor", npc = 2672, item = 10318 }, output = { 10030, 1 }, reagents = { {4339, 3}, {4589, 6}, {8343, 2} }, skillrange = { 240, 255, 270, 285 } },  -- Admiral's Hat
        [ 12082] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 9584, npcH = 4578 }, output = { 10031, 1 }, reagents = { {4304, 2}, {4339, 6}, {8343, 3}, {10285, 6} }, skillrange = { 240, 255, 270, 285 } },  -- Shadoweave Boots
        [ 12084] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 10320 }, output = { 10033, 1 }, reagents = { {2604, 2}, {4339, 4}, {8343, 2} }, skillrange = { 240, 255, 270, 285 } },  -- Red Mageweave Headband
        [ 12085] = { category = "Shirt", source = { kind = "vendor", npcA = 8681, npcH = 4577, item = 10321 }, output = { 10034, 1 }, reagents = { {4339, 4}, {8343, 2} }, skillrange = { 240, 245, 250, 255 } },  -- Tuxedo Shirt
        [ 12086] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 9584, npcH = 4578 }, output = { 10025, 1 }, reagents = { {4339, 2}, {8343, 2}, {10285, 8} }, skillrange = { 245, 260, 275, 290 } },  -- Shadoweave Mask
        [ 12089] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 8681, npcH = 4577, item = 10323 }, output = { 10035, 1 }, reagents = { {4339, 4}, {8343, 3} }, skillrange = { 245, 250, 255, 260 } },  -- Tuxedo Pants
        [ 12088] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10044, 1 }, reagents = { {4304, 2}, {4339, 5}, {7077, 1}, {8343, 3} }, skillrange = { 245, 260, 275, 290 } },  -- Cindercloth Boots
        [ 18401] = { category = "Trade Goods", source = { kind = "trainer" }, output = { 14048, 1 }, reagents = { {14047, 5} }, skillrange = { 250, 255, 257, 260 } },  -- Bolt of Runecloth
        [ 18560] = { category = "Trade Goods", source = { kind = "vendor", npc = 11189, item = 14526 }, output = { 14342, 1 }, reagents = { {14256, 2} }, skillrange = { 250, 290, 305, 320 } },  -- Mooncloth
        [ 12093] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 8681, npcH = 4577, item = 10326 }, output = { 10036, 1 }, reagents = { {4339, 5}, {8343, 3} }, skillrange = { 250, 265, 280, 295 } },  -- Tuxedo Jacket
        [ 12092] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 10041, 1 }, reagents = { {1529, 1}, {4339, 8}, {6037, 1}, {8153, 4}, {8343, 3}, {10286, 2} }, skillrange = { 250, 265, 280, 295 } },  -- Dreamweave Circlet
        [ 12091] = { category = "Cloth Armor", source = { kind = "vendor", npcA = 1347, npcH = 3005, item = 10325 }, output = { 10040, 1 }, reagents = { {2324, 1}, {4339, 5}, {8343, 3} }, skillrange = { 250, 255, 260, 265 } },  -- White Wedding Dress
        [ 26403] = { category = "Misc Armor", source = { kind = "quest", item = 21722, quest = 8878 }, output = { 21154, 1 }, reagents = { {2604, 2}, {4625, 2}, {14048, 4}, {14341, 1} }, skillrange = { 250, 265, 280, 295 } },  -- Festive Red Dress
        [ 26407] = { category = "Misc Armor", source = { kind = "quest", item = 21723, quest = 8878 }, output = { 21542, 1 }, reagents = { {2604, 2}, {4625, 2}, {14048, 4}, {14341, 1} }, skillrange = { 250, 265, 280, 295 } },  -- Festive Red Pant Suit
        [ 18402] = { category = "Cloth Armor", source = { kind = "trainer" }, output = { 13856, 1 }, reagents = { {14048, 3}, {14341, 1} }, skillrange = { 255, 270, 285, 300 } },  -- Runecloth Belt
        [ 18403] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14466 }, output = { 13869, 1 }, reagents = { {7079, 2}, {14048, 5}, {14341, 1} }, skillrange = { 255, 270, 285, 300 } },  -- Frostweave Tunic
        [ 18404] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14467 }, output = { 13868, 1 }, reagents = { {7079, 2}, {14048, 5}, {14341, 1} }, skillrange = { 255, 270, 285, 300 } },  -- Frostweave Robe
        [ 18407] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14470 }, output = { 13857, 1 }, reagents = { {14048, 5}, {14227, 1}, {14341, 1} }, skillrange = { 260, 275, 290, 305 } },  -- Runecloth Tunic
        [ 18408] = { category = "Cloth Armor", source = { kind = "drop", npc = 5861, zone = 51, item = 14471 }, output = { 14042, 1 }, reagents = { {7077, 3}, {14048, 5}, {14341, 1} }, skillrange = { 260, 275, 290, 305 } },  -- Cindercloth Vest
        [ 18405] = { category = "Bag", source = { kind = "vendor", npc = 11189, item = 14468 }, output = { 14046, 1 }, reagents = { {8170, 2}, {14048, 5}, {14341, 1} }, skillrange = { 260, 275, 290, 305 } },  -- Runecloth Bag
        [ 18406] = { category = "Cloth Armor", source = { kind = "vendor", npc = 7940, item = 14469 }, output = { 13858, 1 }, reagents = { {14048, 5}, {14227, 1}, {14341, 1} }, skillrange = { 260, 275, 290, 305 } },  -- Runecloth Robe
        [ 26085] = { category = "Bag", source = { kind = "vendor", npc = 6568, item = 21358 }, output = { 21340, 1 }, reagents = { {7972, 2}, {8170, 4}, {14048, 6}, {14341, 1} }, skillrange = { 260, 275, 290, 305 } },  -- Soul Pouch
        [ 18411] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14474 }, output = { 13870, 1 }, reagents = { {7080, 1}, {14048, 3}, {14341, 1} }, skillrange = { 265, 280, 295, 310 } },  -- Frostweave Gloves
        [ 18410] = { category = "Cloth Armor", source = { kind = "drop", npc = 7864, zone = 16, item = 14473 }, output = { 14143, 1 }, reagents = { {9210, 2}, {14048, 3}, {14227, 1}, {14341, 1} }, skillrange = { 265, 280, 295, 310 } },  -- Ghostweave Belt
        [ 18409] = { category = "Cloak", source = { kind = "vendor", npc = 7940, item = 14472 }, output = { 13860, 1 }, reagents = { {14048, 4}, {14227, 1}, {14341, 1} }, skillrange = { 265, 280, 295, 310 } },  -- Runecloth Cloak
        [ 18413] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14477 }, output = { 14142, 1 }, reagents = { {9210, 2}, {14048, 4}, {14227, 1}, {14341, 1} }, skillrange = { 270, 285, 300, 315 } },  -- Ghostweave Gloves
        [ 18412] = { category = "Cloth Armor", source = { kind = "drop", npc = 5861, zone = 51, item = 14476 }, output = { 14043, 1 }, reagents = { {7077, 3}, {14048, 4}, {14341, 1} }, skillrange = { 270, 285, 300, 315 } },  -- Cindercloth Gloves
        [ 18414] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14478 }, output = { 14100, 1 }, reagents = { {3577, 2}, {14048, 5}, {14341, 1} }, skillrange = { 270, 285, 300, 315 } },  -- Brightcloth Robe
        [ 18415] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14479 }, output = { 14101, 1 }, reagents = { {3577, 2}, {14048, 4}, {14341, 1} }, skillrange = { 270, 285, 300, 315 } },  -- Brightcloth Gloves
        [ 18417] = { category = "Cloth Armor", source = { kind = "vendor", npc = 11189, item = 14481 }, output = { 13863, 1 }, reagents = { {8170, 4}, {14048, 4}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Runecloth Gloves
        [ 18418] = { category = "Cloak", source = { kind = "drop", npc = 7037, zone = 46, item = 14482 }, output = { 14044, 1 }, reagents = { {7078, 1}, {14048, 5}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Cindercloth Cloak
        [ 18419] = { category = "Cloth Armor", source = { kind = "vendor", npc = 12022, item = 14483 }, output = { 14107, 1 }, reagents = { {14048, 5}, {14256, 4}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Felcloth Pants
        [ 18421] = { category = "Cloth Armor", source = { kind = "drop", npc = 8551, zone = 139, item = 14485 }, output = { 14132, 1 }, reagents = { {11176, 1}, {14048, 6}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Wizardweave Leggings
        [ 18416] = { category = "Cloth Armor", source = { kind = "drop", npc = 8538, zone = 139, item = 14480 }, output = { 14141, 1 }, reagents = { {9210, 4}, {14048, 6}, {14227, 1}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Ghostweave Vest
        [ 18420] = { category = "Cloak", source = { kind = "worldDrop", item = 14484 }, output = { 14103, 1 }, reagents = { {3577, 2}, {14048, 4}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Brightcloth Cloak
        [ 18422] = { category = "Cloak", source = { kind = "drop", npc = 9026, zone = 46, item = 14486 }, output = { 14134, 1 }, reagents = { {7068, 4}, {7077, 4}, {7078, 4}, {14048, 6}, {14341, 1} }, skillrange = { 275, 290, 305, 320 } },  -- Cloak of Fire
        [ 27659] = { category = "Bag", source = { kind = "vendor", npc = 15419, item = 22308 }, output = { 22248, 1 }, reagents = { {14048, 5}, {14341, 2}, {16203, 2} }, skillrange = { 275, 290, 305, 320 } },  -- Enchanted Runecloth Bag
        [ 27724] = { category = "Bag", source = { kind = "reputation", item = 22310, faction = "Cenarion Circle", standing = "Friendly" }, output = { 22251, 1 }, reagents = { {8831, 10}, {11040, 8}, {14048, 5}, {14341, 2} }, skillrange = { 275, 290, 305, 320 } },  -- Cenarion Herb Bag
        [ 18434] = { category = "Cloth Armor", source = { kind = "drop", npc = 7037, zone = 46, item = 14490 }, output = { 14045, 1 }, reagents = { {7078, 1}, {14048, 6}, {14341, 1} }, skillrange = { 280, 295, 310, 325 } },  -- Cindercloth Pants
        [ 18423] = { category = "Cloth Armor", source = { kind = "vendor", npc = 7940, item = 14488 }, output = { 13864, 1 }, reagents = { {8170, 4}, {14048, 4}, {14227, 2}, {14341, 1} }, skillrange = { 280, 295, 310, 325 } },  -- Runecloth Boots
        [ 18424] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14489 }, output = { 13871, 1 }, reagents = { {7080, 1}, {14048, 6}, {14341, 1} }, skillrange = { 280, 295, 310, 325 } },  -- Frostweave Pants
        [ 18437] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14492 }, output = { 14108, 1 }, reagents = { {8170, 4}, {14048, 6}, {14256, 4}, {14341, 1} }, skillrange = { 285, 300, 315, 330 } },  -- Felcloth Boots
        [ 18436] = { category = "Cloth Armor", source = { kind = "drop", npc = 7437, zone = 618, item = 14493 }, output = { 14136, 1 }, reagents = { {7080, 4}, {12808, 4}, {14048, 10}, {14256, 12}, {14341, 1} }, skillrange = { 285, 300, 315, 330 } },  -- Robe of Winter Night
        [ 18438] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14491 }, output = { 13865, 1 }, reagents = { {14048, 6}, {14227, 2}, {14341, 1} }, skillrange = { 285, 300, 315, 330 } },  -- Runecloth Pants
        [ 26086] = { category = "Bag", source = { kind = "drop", zone = 2057 }, output = { 21341, 1 }, reagents = { {12810, 6}, {14227, 4}, {14256, 12}, {20520, 2} }, skillrange = { 285, 300, 315, 330 } },  -- Felcloth Bag
        [ 22813] = { category = "Oil", source = { kind = "quest", quest = 5518 }, output = { 18258, 1 }, reagents = { {8170, 4}, {14048, 2}, {14341, 1}, {18240, 1} }, skillrange = { 285, 285, 290, 295 } },  -- Gordok Ogre Suit
        [ 18442] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14496 }, output = { 14111, 1 }, reagents = { {14048, 5}, {14256, 4}, {14341, 1} }, skillrange = { 290, 305, 320, 335 } },  -- Felcloth Hood
        [ 18440] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14497 }, output = { 14137, 1 }, reagents = { {14048, 6}, {14341, 1}, {14342, 4} }, skillrange = { 290, 305, 320, 335 } },  -- Mooncloth Leggings
        [ 18441] = { category = "Cloth Armor", source = { kind = "drop", npc = 10384, zone = 2017, item = 14495 }, output = { 14144, 1 }, reagents = { {9210, 4}, {14048, 6}, {14341, 1} }, skillrange = { 290, 305, 320, 335 } },  -- Ghostweave Pants
        [ 19435] = { category = "Cloth Armor", source = { kind = "quest", quest = 6032 }, output = { 15802, 1 }, reagents = { {7971, 2}, {14048, 6}, {14341, 1}, {14342, 4} }, skillrange = { 290, 295, 310, 325 } },  -- Mooncloth Boots
        [ 23664] = { category = "Cloth Armor", source = { kind = "reputation", item = 19216, faction = "Argent Dawn", standing = "Honored" }, output = { 19056, 1 }, reagents = { {12809, 2}, {12810, 4}, {13926, 2}, {14048, 6}, {14227, 2} }, skillrange = { 290, 305, 320, 335 } },  -- Argent Boots
        [ 18439] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14494 }, output = { 14104, 1 }, reagents = { {3577, 4}, {14048, 6}, {14227, 1}, {14341, 1} }, skillrange = { 290, 305, 320, 335 } },  -- Brightcloth Pants
        [ 23662] = { category = "Cloth Armor", source = { kind = "reputation", item = 19215, faction = "Timbermaw Hold", standing = "Honored" }, output = { 19047, 1 }, reagents = { {7076, 3}, {12803, 3}, {14048, 8}, {14227, 2} }, skillrange = { 290, 305, 320, 335 } },  -- Wisdom of the Timbermaw
        [ 18444] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14498 }, output = { 13866, 1 }, reagents = { {14048, 4}, {14227, 2}, {14341, 1} }, skillrange = { 295, 310, 325, 340 } },  -- Runecloth Headband
        [ 24091] = { category = "Cloth Armor", source = { kind = "reputation", item = 19764, faction = "Zandalar Tribe", standing = "Revered" }, output = { 19682, 1 }, reagents = { {12804, 4}, {14048, 4}, {14227, 2}, {14342, 3}, {19726, 5} }, skillrange = { 300, 315, 330, 345 } },  -- Bloodvine Vest
        [ 24092] = { category = "Cloth Armor", source = { kind = "reputation", item = 19765, faction = "Zandalar Tribe", standing = "Honored" }, output = { 19683, 1 }, reagents = { {12804, 4}, {14048, 4}, {14227, 2}, {14342, 4}, {19726, 4} }, skillrange = { 300, 315, 330, 345 } },  -- Bloodvine Leggings
        [ 24093] = { category = "Cloth Armor", source = { kind = "reputation", item = 19766, faction = "Zandalar Tribe", standing = "Friendly" }, output = { 19684, 1 }, reagents = { {12810, 4}, {14048, 4}, {14227, 4}, {14342, 3}, {19726, 3} }, skillrange = { 300, 315, 330, 345 } },  -- Bloodvine Boots
        [ 23666] = { category = "Cloth Armor", source = { kind = "reputation", item = 19219, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19156, 1 }, reagents = { {7078, 6}, {14227, 4}, {14342, 10}, {17010, 2}, {17011, 3} }, skillrange = { 300, 315, 330, 345 } },  -- Flarecore Robe
        [ 28207] = { category = "Cloth Armor", source = { kind = "vendor", npc = 16365 }, output = { 22652, 1 }, reagents = { {7080, 6}, {14048, 8}, {14227, 8}, {22682, 7} }, skillrange = { 300, 315, 330, 345 } },  -- Glacial Vest
        [ 28205] = { category = "Cloth Armor", source = { kind = "vendor", npc = 16365 }, output = { 22654, 1 }, reagents = { {7080, 4}, {14048, 4}, {14227, 4}, {22682, 5} }, skillrange = { 300, 315, 330, 345 } },  -- Glacial Gloves
        [ 28209] = { category = "Cloth Armor", source = { kind = "vendor", npc = 16365 }, output = { 22655, 1 }, reagents = { {7080, 2}, {14048, 2}, {14227, 4}, {22682, 4} }, skillrange = { 300, 315, 330, 345 } },  -- Glacial Wrists
        [ 28208] = { category = "Cloak", source = { kind = "vendor", npc = 16365 }, output = { 22658, 1 }, reagents = { {7080, 2}, {14048, 4}, {14227, 4}, {22682, 5} }, skillrange = { 300, 315, 330, 345 } },  -- Glacial Cloak
        [ 18451] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14506 }, output = { 14106, 1 }, reagents = { {12662, 4}, {14048, 8}, {14256, 8}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Felcloth Robe
        [ 18453] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14508 }, output = { 14112, 1 }, reagents = { {8170, 4}, {12662, 4}, {14048, 7}, {14256, 6}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Felcloth Shoulders
        [ 18447] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14501 }, output = { 14138, 1 }, reagents = { {14048, 6}, {14341, 1}, {14342, 4} }, skillrange = { 300, 315, 330, 345 } },  -- Mooncloth Vest
        [ 18457] = { category = "Cloth Armor", source = { kind = "drop", npc = 9264, zone = 1583, item = 14513 }, output = { 14152, 1 }, reagents = { {7076, 10}, {7078, 10}, {7080, 10}, {7082, 10}, {14048, 12}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Robe of the Archmage
        [ 18458] = { category = "Cloth Armor", source = { kind = "drop", npc = 1853, zone = 2057, item = 14514 }, output = { 14153, 1 }, reagents = { {7078, 12}, {12662, 20}, {12808, 12}, {14048, 12}, {14256, 40}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Robe of the Void
        [ 18456] = { category = "Cloth Armor", source = { kind = "drop", npc = 10813, zone = 2017, item = 14512 }, output = { 14154, 1 }, reagents = { {9210, 10}, {12811, 4}, {13926, 4}, {14048, 12}, {14341, 2}, {14342, 10} }, skillrange = { 300, 315, 330, 345 } },  -- Truefaith Vestments
        [ 20848] = { category = "Cloth Armor", source = { kind = "reputation", item = 17017, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16980, 1 }, reagents = { {12810, 6}, {14048, 12}, {14341, 2}, {17010, 4}, {17011, 4} }, skillrange = { 300, 315, 330, 345 } },  -- Flarecore Mantle
        [ 22866] = { category = "Cloth Armor", source = { kind = "drop", zone = 2557, item = 18414 }, output = { 18405, 1 }, reagents = { {7078, 12}, {7080, 12}, {9210, 10}, {14048, 16}, {14341, 6}, {14342, 10}, {14344, 6} }, skillrange = { 300, 315, 330, 345 } },  -- Belt of the Archmage
        [ 22867] = { category = "Cloth Armor", source = { kind = "drop", zone = 2557, item = 18415 }, output = { 18407, 1 }, reagents = { {12662, 6}, {12808, 8}, {14048, 12}, {14256, 20}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Felcloth Gloves
        [ 22870] = { category = "Cloak", source = { kind = "drop", zone = 2557, item = 18418 }, output = { 18413, 1 }, reagents = { {12360, 1}, {12809, 4}, {14048, 12}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Cloak of Warding
        [ 23667] = { category = "Cloth Armor", source = { kind = "reputation", item = 19220, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 19165, 1 }, reagents = { {7078, 10}, {14227, 4}, {14342, 8}, {17010, 5}, {17011, 3} }, skillrange = { 300, 315, 330, 345 } },  -- Flarecore Leggings
        [ 24903] = { category = "Cloth Armor", source = { kind = "quest", item = 20547, quest = 8323 }, output = { 20537, 1 }, reagents = { {12810, 2}, {14048, 4}, {14227, 2}, {14256, 4}, {20520, 6} }, skillrange = { 300, 315, 330, 345 } },  -- Runed Stygian Boots
        [ 24901] = { category = "Cloth Armor", source = { kind = "quest", item = 20546, quest = 8323 }, output = { 20538, 1 }, reagents = { {14048, 6}, {14227, 2}, {14256, 6}, {20520, 8} }, skillrange = { 300, 315, 330, 345 } },  -- Runed Stygian Leggings
        [ 24902] = { category = "Cloth Armor", source = { kind = "quest", item = 20548, quest = 8323 }, output = { 20539, 1 }, reagents = { {12810, 2}, {14048, 2}, {14227, 2}, {14256, 2}, {20520, 6} }, skillrange = { 300, 315, 330, 345 } },  -- Runed Stygian Belt
        [ 28210] = { category = "Cloak", source = { kind = "reputation", item = 22683, faction = "Cenarion Circle", standing = "Revered" }, output = { 22660, 1 }, reagents = { {12803, 4}, {14227, 4}, {14342, 2}, {19726, 1} }, skillrange = { 300, 315, 330, 345 } },  -- Gaea's Embrace
        [ 28480] = { category = "Cloth Armor", source = { kind = "reputation", item = 22774, faction = "Cenarion Circle", standing = "Revered" }, output = { 22756, 1 }, reagents = { {12803, 2}, {14048, 4}, {14227, 2}, {19726, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Sylvan Vest
        [ 28481] = { category = "Cloth Armor", source = { kind = "reputation", item = 22773, faction = "Cenarion Circle", standing = "Honored" }, output = { 22757, 1 }, reagents = { {12803, 2}, {14048, 4}, {14227, 2}, {14342, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Sylvan Crown
        [ 28482] = { category = "Cloth Armor", source = { kind = "reputation", item = 22772, faction = "Cenarion Circle", standing = "Friendly" }, output = { 22758, 1 }, reagents = { {12803, 4}, {14048, 2}, {14227, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Sylvan Shoulders
        [ 18449] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14504 }, output = { 13867, 1 }, reagents = { {8170, 4}, {14048, 7}, {14227, 2}, {14341, 1} }, skillrange = { 300, 315, 330, 345 } },  -- Runecloth Shoulders
        [ 18446] = { category = "Cloth Armor", source = { kind = "drop", npc = 8526, zone = 139, item = 14500 }, output = { 14128, 1 }, reagents = { {11176, 2}, {14048, 8}, {14341, 1} }, skillrange = { 300, 315, 330, 345 } },  -- Wizardweave Robe
        [ 18450] = { category = "Cloth Armor", source = { kind = "drop", npc = 8526, zone = 139, item = 14505 }, output = { 14130, 1 }, reagents = { {7910, 1}, {11176, 4}, {14048, 6}, {14341, 1} }, skillrange = { 300, 315, 330, 345 } },  -- Wizardweave Turban
        [ 18448] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14507 }, output = { 14139, 1 }, reagents = { {14048, 5}, {14341, 1}, {14342, 5} }, skillrange = { 300, 315, 330, 345 } },  -- Mooncloth Shoulders
        [ 18452] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14509 }, output = { 14140, 1 }, reagents = { {12800, 1}, {12810, 2}, {14048, 4}, {14341, 2}, {14342, 6} }, skillrange = { 300, 315, 330, 345 } },  -- Mooncloth Circlet
        [ 18454] = { category = "Cloth Armor", source = { kind = "worldDrop", item = 14511 }, output = { 14146, 1 }, reagents = { {9210, 10}, {12364, 6}, {12810, 8}, {13926, 6}, {14048, 10}, {14341, 2}, {14342, 10} }, skillrange = { 300, 315, 330, 345 } },  -- Gloves of Spell Mastery
        [ 20849] = { category = "Cloth Armor", source = { kind = "reputation", item = 17018, faction = "Thorium Brotherhood", standing = "Honored" }, output = { 16979, 1 }, reagents = { {7078, 4}, {12810, 2}, {14048, 8}, {14341, 2}, {17010, 6} }, skillrange = { 300, 315, 330, 345 } },  -- Flarecore Gloves
        [ 22759] = { category = "Cloth Armor", source = { kind = "drop", zone = 2717, item = 18265 }, output = { 18263, 1 }, reagents = { {7078, 2}, {12810, 6}, {14341, 4}, {14342, 6}, {17010, 8} }, skillrange = { 300, 320, 335, 350 } },  -- Flarecore Wraps
        [ 22868] = { category = "Cloth Armor", source = { kind = "drop", zone = 2557, item = 18416 }, output = { 18408, 1 }, reagents = { {7078, 10}, {7910, 2}, {14048, 12}, {14341, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Inferno Gloves
        [ 22869] = { category = "Cloth Armor", source = { kind = "drop", zone = 2557, item = 18417 }, output = { 18409, 1 }, reagents = { {13926, 2}, {14048, 12}, {14341, 2}, {14342, 6} }, skillrange = { 300, 315, 330, 345 } },  -- Mooncloth Gloves
        [ 22902] = { category = "Cloth Armor", source = { kind = "vendor", npc = 14371, item = 18487 }, output = { 18486, 1 }, reagents = { {13926, 2}, {14048, 6}, {14341, 2}, {14342, 4} }, skillrange = { 300, 315, 330, 345 } },  -- Mooncloth Robe
        [ 23663] = { category = "Cloth Armor", source = { kind = "reputation", item = 19218, faction = "Timbermaw Hold", standing = "Revered" }, output = { 19050, 1 }, reagents = { {7076, 5}, {12803, 5}, {14227, 2}, {14342, 5} }, skillrange = { 300, 315, 330, 345 } },  -- Mantle of the Timbermaw
        [ 23665] = { category = "Cloth Armor", source = { kind = "reputation", item = 19217, faction = "Argent Dawn", standing = "Revered" }, output = { 19059, 1 }, reagents = { {12809, 2}, {14227, 2}, {14342, 5} }, skillrange = { 300, 315, 330, 345 } },  -- Argent Shoulders
        [ 18445] = { category = "Bag", source = { kind = "worldDrop", item = 14499 }, output = { 14155, 1 }, reagents = { {14048, 4}, {14341, 1}, {14342, 1} }, skillrange = { 300, 315, 330, 345 } },  -- Mooncloth Bag
        [ 18455] = { category = "Bag", source = { kind = "worldDrop", item = 14510 }, output = { 14156, 1 }, reagents = { {14048, 8}, {14341, 2}, {14342, 12}, {14344, 2}, {17012, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Bottomless Bag
        [ 26087] = { category = "Bag", source = { kind = "worldDrop", item = 21371 }, output = { 21342, 1 }, reagents = { {7078, 4}, {14227, 4}, {14256, 20}, {17012, 16}, {19726, 8} }, skillrange = { 300, 315, 330, 345 } },  -- Core Felcloth Bag
        [ 27660] = { category = "Bag", source = { kind = "drop", npc = 11487, zone = 2557, item = 22309 }, output = { 22249, 1 }, reagents = { {12810, 4}, {14048, 6}, {14227, 4}, {14344, 4} }, skillrange = { 300, 315, 330, 345 } },  -- Big Bag of Enchantment
        [ 27725] = { category = "Bag", source = { kind = "reputation", item = 22312, faction = "Cenarion Circle", standing = "Revered" }, output = { 22252, 1 }, reagents = { {13468, 1}, {14048, 6}, {14227, 4}, {14342, 2} }, skillrange = { 300, 315, 330, 345 } },  -- Satchel of Cenarius

    },
    COOKING         = {

        -- Reagents, output, skillrange and source harvested by
        -- tools/recipedb_skill/_generate_profession.py from
        -- wow.playjournals.com profession_skills + spells + items + npcs.
        -- Sorted by `learned_at_rank` ascending.

        [  7752] = { category = "Consumable", source = { kind = "vendor", npcA = 10118, npcH = 5942, item = 6326 }, output = { 787, 1 }, reagents = { {6303, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Slitherskin Mackerel
        [ 21143] = { category = "Consumable", source = { kind = "vendor", npc = 13420, item = 17200 }, output = { 17197, 1 }, reagents = { {6889, 1}, {17194, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Gingerbread Cookie
        [  2538] = { category = "Consumable", source = { kind = "trainer" }, output = { 2679, 1 }, reagents = { {2672, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Charred Wolf Meat
        [  2540] = { category = "Consumable", source = { kind = "trainer" }, output = { 2681, 1 }, reagents = { {769, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Roasted Boar Meat
        [  7751] = { category = "Consumable", source = { kind = "vendor", npcA = 1684, npcH = 3550, item = 6325 }, output = { 6290, 1 }, reagents = { {6291, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Brilliant Smallfish
        [  8604] = { category = "Consumable", source = { kind = "trainer" }, output = { 6888, 1 }, reagents = { {2678, 1}, {6889, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Herb Baked Egg
        [ 15935] = { category = "Consumable", source = { kind = "vendor", npc = 2118, item = 12226 }, output = { 12224, 1 }, reagents = { {2678, 1}, {12223, 1} }, skillrange = {   1,  45,  65,  85 } },  -- Crispy Bat Wing
        [   818] = { category = "Consumable", source = { kind = "trainer" }, reagents = { {4470, 1} } },  -- Basic Campfire
        [  6412] = { category = "Consumable", source = { kind = "quest", item = 5482, quest = 4161 }, output = { 5472, 1 }, reagents = { {5465, 1} }, skillrange = {  10,  50,  70,  90 } },  -- Kaldorei Spider Kabob
        [  2539] = { category = "Consumable", source = { kind = "trainer" }, output = { 2680, 1 }, reagents = { {2672, 1}, {2678, 1} }, skillrange = {  10,  50,  70,  90 } },  -- Spiced Wolf Meat
        [  6413] = { category = "Consumable", source = { kind = "vendor", npc = 3881, item = 5483 }, output = { 5473, 1 }, reagents = { {5466, 1} }, skillrange = {  20,  60,  80, 100 } },  -- Scorpid Surprise
        [  2795] = { category = "Consumable", source = { kind = "quest", item = 2889, quest = 384 }, output = { 2888, 1 }, reagents = { {2886, 1}, {2894, 1} }, skillrange = {  25,  60,  80, 100 } },  -- Beer Basted Boar Ribs
        [ 21144] = { category = "Consumable", source = { kind = "vendor", npc = 13420, item = 17201 }, output = { 17198, 1 }, reagents = { {1179, 1}, {6889, 1}, {17194, 1}, {17196, 1} }, skillrange = {  35,  75,  95, 115 } },  -- Egg Nog
        [  6414] = { category = "Consumable", source = { kind = "vendor", npc = 3081, item = 5484 }, output = { 5474, 2 }, reagents = { {2678, 1}, {5467, 1} }, skillrange = {  35,  75,  95, 115 } },  -- Roasted Kodo Meat
        [  8607] = { category = "Consumable", source = { kind = "vendor", npcA = 1465, npcH = 3556, item = 6892 }, output = { 6890, 1 }, reagents = { {3173, 1} }, skillrange = {  40,  80, 100, 120 } },  -- Smoked Bear Meat
        [  7827] = { category = "Consumable", source = { kind = "vendor", npc = 3497, item = 6368 }, output = { 5095, 1 }, reagents = { {6361, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Rainbow Fin Albacore
        [  7753] = { category = "Consumable", source = { kind = "vendor", npcA = 1684, npcH = 4574, item = 6328 }, output = { 4592, 1 }, reagents = { {6289, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Longjaw Mud Snapper
        [  2542] = { category = "Consumable", source = { kind = "quest", item = 2697, quest = 22 }, output = { 724, 1 }, reagents = { {723, 1}, {2678, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Goretusk Liver Pie
        [  6416] = { category = "Consumable", source = { kind = "quest", item = 5486, quest = 2178 }, output = { 5477, 2 }, reagents = { {4536, 1}, {5469, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Strider Stew
        [  6499] = { category = "Consumable", source = { kind = "trainer" }, output = { 5525, 1 }, reagents = { {159, 1}, {5503, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Boiled Clams
        [  2541] = { category = "Consumable", source = { kind = "trainer" }, output = { 2684, 1 }, reagents = { {2673, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Coyote Steak
        [  6415] = { category = "Consumable", source = { kind = "vendor", npc = 4200, item = 5485 }, output = { 5476, 2 }, reagents = { {2678, 1}, {5468, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Fillet of Frenzy
        [  7754] = { category = "Consumable", source = { kind = "vendor", npc = 1684, item = 6329 }, output = { 6316, 1 }, reagents = { {2678, 1}, {6317, 1} }, skillrange = {  50,  90, 110, 130 } },  -- Loch Frenzy Delight
        [  3371] = { category = "Consumable", source = { kind = "quest", item = 3679, quest = 418 }, output = { 3220, 2 }, reagents = { {3172, 1}, {3173, 1}, {3174, 1} }, skillrange = {  60, 100, 120, 140 } },  -- Blood Sausage
        [  9513] = { category = "Consumable", source = { kind = "quest", item = 18160, quest = 2359 }, output = { 7676, 1 }, reagents = { {159, 1}, {2452, 1} }, skillrange = {  60, 100, 120, 140 } },  -- Thistle Tea
        [  2543] = { category = "Consumable", source = { kind = "quest", item = 728, quest = 38 }, output = { 733, 1 }, reagents = { {729, 1}, {730, 1}, {731, 1} }, skillrange = {  75, 115, 135, 155 } },  -- Westfall Stew
        [  2544] = { category = "Consumable", source = { kind = "trainer" }, output = { 2683, 1 }, reagents = { {2674, 1}, {2678, 1} }, skillrange = {  75, 115, 135, 155 } },  -- Crab Cake
        [  2546] = { category = "Consumable", source = { kind = "trainer" }, output = { 2687, 1 }, reagents = { {2677, 1}, {2678, 1} }, skillrange = {  80, 120, 140, 160 } },  -- Dry Pork Ribs
        [  3370] = { category = "Consumable", source = { kind = "quest", item = 3678, quest = 385 }, output = { 3662, 1 }, reagents = { {2678, 1}, {2924, 1} }, skillrange = {  80, 120, 140, 160 } },  -- Crocolisk Steak
        [ 25704] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 21099 }, output = { 21072, 1 }, reagents = { {2678, 1}, {21071, 1} }, skillrange = {  80, 120, 140, 160 } },  -- Smoked Sagefish
        [  2545] = { category = "Consumable", source = { kind = "vendor", npc = 340, item = 2698 }, output = { 2682, 1 }, reagents = { {2675, 1}, {2678, 1} }, skillrange = {  85, 125, 145, 165 } },  -- Cooked Crab Claw
        [  8238] = { category = "Consumable", source = { kind = "drop", item = 6661 }, output = { 6657, 1 }, reagents = { {2678, 1}, {6522, 1} }, skillrange = {  85, 125, 145, 165 } },  -- Savory Deviate Delight
        [  6417] = { category = "Consumable", source = { kind = "quest", item = 5487, quest = 862 }, output = { 5478, 2 }, reagents = { {5051, 1} }, skillrange = {  90, 130, 150, 170 } },  -- Dig Rat Stew
        [  3372] = { category = "Consumable", source = { kind = "quest", item = 3680, quest = 127 }, output = { 3663, 1 }, reagents = { {1468, 2}, {2692, 1} }, skillrange = {  90, 130, 150, 170 } },  -- Murloc Fin Soup
        [  6501] = { category = "Consumable", source = { kind = "vendor", npc = 4307, item = 5528 }, output = { 5526, 1 }, reagents = { {1179, 1}, {2678, 1}, {5503, 1} }, skillrange = {  90, 130, 150, 170 } },  -- Clam Chowder
        [  7755] = { category = "Consumable", source = { kind = "vendor", npc = 3497, item = 6330 }, output = { 4593, 1 }, reagents = { {6308, 1} }, skillrange = { 100, 140, 160, 180 } },  -- Bristle Whisker Catfish
        [  2547] = { category = "Consumable", source = { kind = "quest", item = 2699, quest = 92 }, output = { 1082, 1 }, reagents = { {1080, 1}, {1081, 1} }, skillrange = { 100, 135, 155, 175 } },  -- Redridge Goulash
        [  2549] = { category = "Consumable", source = { kind = "quest", item = 2701, quest = 90 }, output = { 1017, 3 }, reagents = { {1015, 2}, {2665, 1} }, skillrange = { 100, 140, 160, 180 } },  -- Seasoned Wolf Kabob
        [  6418] = { category = "Consumable", source = { kind = "vendor", npc = 3482, item = 5488 }, output = { 5479, 2 }, reagents = { {2692, 1}, {5470, 1} }, skillrange = { 100, 140, 160, 180 } },  -- Crispy Lizard Tail
        [  2548] = { category = "Consumable", source = { kind = "vendor", npc = 340, item = 2700 }, output = { 2685, 1 }, reagents = { {2677, 2}, {2692, 1} }, skillrange = { 110, 130, 150, 170 } },  -- Succulent Pork Ribs
        [  3377] = { category = "Consumable", source = { kind = "quest", item = 3683, quest = 93 }, output = { 3666, 1 }, reagents = { {2251, 2}, {2692, 1} }, skillrange = { 110, 150, 170, 190 } },  -- Gooey Spider Cake
        [  3397] = { category = "Consumable", source = { kind = "quest", item = 3734, quest = 498 }, output = { 3726, 1 }, reagents = { {2692, 1}, {3730, 1} }, skillrange = { 110, 150, 170, 190 } },  -- Big Bear Steak
        [  6419] = { category = "Consumable", source = { kind = "vendor", npc = 12245, item = 5489 }, output = { 5480, 2 }, reagents = { {2678, 4}, {5471, 1} }, skillrange = { 110, 150, 170, 190 } },  -- Lean Venison
        [  3373] = { category = "Consumable", source = { kind = "quest", item = 3681, quest = 471 }, output = { 3664, 1 }, reagents = { {2692, 1}, {3667, 1} }, skillrange = { 120, 160, 180, 200 } },  -- Crocolisk Gumbo
        [ 15853] = { category = "Consumable", source = { kind = "vendor", npc = 12246, item = 12227 }, output = { 12209, 1 }, reagents = { {1015, 1}, {2678, 1} }, skillrange = { 125, 165, 185, 205 } },  -- Lean Wolf Steak
        [  3398] = { category = "Consumable", source = { kind = "quest", item = 3735, quest = 501 }, output = { 3727, 1 }, reagents = { {2692, 1}, {3731, 1} }, skillrange = { 125, 175, 195, 215 } },  -- Hot Lion Chops
        [  6500] = { category = "Consumable", source = { kind = "trainer" }, output = { 5527, 1 }, reagents = { {2692, 1}, {5504, 1} }, skillrange = { 125, 165, 185, 205 } },  -- Goblin Deviled Clams
        [  3376] = { category = "Consumable", source = { kind = "quest", item = 3682, quest = 296 }, output = { 3665, 1 }, reagents = { {2692, 1}, {3685, 1} }, skillrange = { 130, 170, 190, 210 } },  -- Curiously Tasty Omelet
        [  3399] = { category = "Consumable", source = { kind = "quest", item = 3736, quest = 564 }, output = { 3728, 1 }, reagents = { {3713, 1}, {3731, 2} }, skillrange = { 150, 190, 210, 230 } },  -- Tasty Lion Steak
        [ 24418] = { category = "Consumable", source = { kind = "vendor", npc = 4879, item = 20075 }, output = { 20074, 1 }, reagents = { {3667, 2}, {3713, 1} }, skillrange = { 150, 160, 180, 200 } },  -- Heavy Crocolisk Stew
        [ 15855] = { category = "Consumable", source = { kind = "vendor", npc = 12245, item = 12228 }, output = { 12210, 1 }, reagents = { {2692, 1}, {12184, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Roast Raptor
        [  7828] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 6369 }, output = { 4594, 1 }, reagents = { {6362, 1} }, skillrange = { 175, 190, 210, 230 } },  -- Rockscale Cod
        [  4094] = { category = "Consumable", source = { kind = "vendor", npc = 2818 }, output = { 4457, 1 }, reagents = { {2692, 1}, {3404, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Barbecued Buzzard Wing
        [  3400] = { category = "Consumable", source = { kind = "quest", item = 3737, quest = 555 }, output = { 3729, 1 }, reagents = { {3712, 1}, {3713, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Soothing Turtle Bisque
        [ 13028] = { category = "Consumable", source = { kind = "vendor", npc = 8696 }, output = { 10841, 4 }, reagents = { {159, 1}, {3821, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Goldthorn Tea
        [ 15861] = { category = "Consumable", source = { kind = "vendor", npc = 12245, item = 12231 }, output = { 12212, 2 }, reagents = { {159, 1}, {4536, 2}, {12202, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Jungle Stew
        [ 15865] = { category = "Consumable", source = { kind = "vendor", npc = 12246, item = 12233 }, output = { 12214, 1 }, reagents = { {2596, 1}, {12037, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Mystery Stew
        [  7213] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 6039 }, output = { 6038, 1 }, reagents = { {2692, 1}, {4655, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Giant Clam Scorcho
        [ 20916] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 17062 }, output = { 8364, 1 }, reagents = { {8365, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Mithril Headed Trout
        [ 15863] = { category = "Consumable", source = { kind = "vendor", npc = 12245, item = 12232 }, output = { 12213, 1 }, reagents = { {2692, 1}, {12037, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Carrion Surprise
        [ 15856] = { category = "Consumable", source = { kind = "vendor", npc = 12246, item = 12229 }, output = { 13851, 1 }, reagents = { {2692, 1}, {12203, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Hot Wolf Ribs
        [ 25954] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 21219 }, output = { 21217, 1 }, reagents = { {2692, 1}, {21153, 1} }, skillrange = { 175, 215, 235, 255 } },  -- Sagefish Delight
        [ 15910] = { category = "Consumable", source = { kind = "vendor", npc = 12245, item = 12240 }, output = { 12215, 2 }, reagents = { {159, 1}, {3713, 1}, {12204, 2} }, skillrange = { 200, 240, 260, 280 } },  -- Heavy Kodo Stew
        [ 15906] = { category = "Consumable", source = { kind = "vendor", npc = 12246, item = 12239 }, output = { 12217, 1 }, reagents = { {2692, 1}, {4402, 1}, {12037, 1} }, skillrange = { 200, 240, 260, 280 } },  -- Dragonbreath Chili
        [ 21175] = { category = "Consumable", source = { kind = "trainer" }, output = { 17222, 1 }, reagents = { {12205, 2} }, skillrange = { 200, 240, 260, 280 } },  -- Spider Sausage
        [ 18238] = { category = "Consumable", source = { kind = "vendor", npc = 8137, item = 13939 }, output = { 6887, 1 }, reagents = { {4603, 1} }, skillrange = { 225, 265, 285, 305 } },  -- Spotted Yellowtail
        [ 20626] = { category = "Consumable", source = { kind = "vendor", npc = 8139, item = 16767 }, output = { 16766, 2 }, reagents = { {1179, 1}, {2692, 1}, {7974, 2} }, skillrange = { 225, 265, 285, 305 } },  -- Undermine Clam Chowder
        [ 15915] = { category = "Consumable", source = { kind = "vendor", npcA = 4305, npcH = 989, item = 16111 }, output = { 12216, 1 }, reagents = { {2692, 2}, {12206, 1} }, skillrange = { 225, 265, 285, 305 } },  -- Spiced Chili Crab
        [ 15933] = { category = "Consumable", source = { kind = "vendor", npc = 11187, item = 16110 }, output = { 12218, 1 }, reagents = { {3713, 2}, {12207, 1} }, skillrange = { 225, 265, 285, 305 } },  -- Monster Omelet
        [ 18239] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 13940 }, output = { 13927, 1 }, reagents = { {3713, 1}, {13754, 1} }, skillrange = { 225, 265, 285, 305 } },  -- Cooked Glossy Mightfish
        [ 18241] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 13941 }, output = { 13930, 1 }, reagents = { {13758, 1} }, skillrange = { 225, 265, 285, 305 } },  -- Filet of Redgill
        [ 22480] = { category = "Consumable", source = { kind = "vendor", npc = 7733, item = 18046 }, output = { 18045, 1 }, reagents = { {3713, 1}, {12208, 1} }, skillrange = { 225, 265, 285, 305 } },  -- Tender Wolf Steak
        [ 18240] = { category = "Consumable", source = { kind = "vendor", npc = 8137, item = 13942 }, output = { 13928, 1 }, reagents = { {3713, 1}, {13755, 1} }, skillrange = { 240, 280, 300, 320 } },  -- Grilled Squid
        [ 18242] = { category = "Consumable", source = { kind = "vendor", npc = 2664, item = 13943 }, output = { 13929, 1 }, reagents = { {2692, 2}, {13756, 1} }, skillrange = { 240, 280, 300, 320 } },  -- Hot Smoked Bass
        [ 18243] = { category = "Consumable", source = { kind = "vendor", npc = 8137, item = 13945 }, output = { 13931, 1 }, reagents = { {159, 1}, {13759, 1} }, skillrange = { 250, 290, 310, 330 } },  -- Nightfin Soup
        [ 18244] = { category = "Consumable", source = { kind = "vendor", npc = 8137, item = 13946 }, output = { 13932, 1 }, reagents = { {13760, 1} }, skillrange = { 250, 290, 310, 330 } },  -- Poached Sunscale Salmon
        [ 18247] = { category = "Consumable", source = { kind = "vendor", npcA = 7947, npcH = 8145, item = 13949 }, output = { 13935, 1 }, reagents = { {3713, 1}, {13889, 1} }, skillrange = { 275, 315, 335, 355 } },  -- Baked Salmon
        [ 18245] = { category = "Consumable", source = { kind = "vendor", npcA = 7947, npcH = 8145, item = 13947 }, output = { 13933, 1 }, reagents = { {159, 1}, {13888, 1} }, skillrange = { 275, 315, 335, 355 } },  -- Lobster Stew
        [ 18246] = { category = "Consumable", source = { kind = "vendor", npcA = 7947, npcH = 8145, item = 13948 }, output = { 13934, 1 }, reagents = { {2692, 1}, {3713, 1}, {13893, 1} }, skillrange = { 275, 315, 335, 355 } },  -- Mightfish Steak
        [ 22761] = { category = "Consumable", source = { kind = "drop", npc = 14354, zone = 2557, item = 18267 }, output = { 18254, 1 }, reagents = { {3713, 1}, {18255, 1} }, skillrange = { 275, 315, 335, 355 } },  -- Runn Tum Tuber Surprise
        [ 24801] = { category = "Consumable", source = { kind = "quest", quest = 8313 }, output = { 20452, 1 }, reagents = { {3713, 1}, {20424, 1} }, skillrange = { 285, 325, 345, 365 } },  -- Smoked Desert Dumplings
        [ 25659] = { category = "Consumable", source = { kind = "quest", item = 21025, quest = 8586 }, output = { 21023, 5 }, reagents = { {2692, 1}, {8150, 1}, {9061, 1}, {21024, 1} }, skillrange = { 300, 325, 345, 365 } },  -- Dirge's Kickin' Chimaerok Chops

    },
    FISHING         = {},

    FIRST_AID       = {

        -- ===== Bandages — Apprentice / Journeyman tiers =====
        -- All trainer-taught directly (no manual item to buy).
        [3275] = {  -- Linen Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 1251, 1 },                    -- Linen Bandage
            reagents   = { {2589, 1} },                  -- Linen Cloth ×1
            skillrange = {  1,  30,  45,  60 },
        },
        [3276] = {  -- Heavy Linen Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 2581, 1 },                    -- Heavy Linen Bandage
            reagents   = { {2589, 2} },                  -- Linen Cloth ×2
            skillrange = {  40,  50,  75, 100 },
        },
        [3277] = {  -- Wool Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 3530, 1 },                    -- Wool Bandage
            reagents   = { {2592, 1} },                  -- Wool Cloth ×1
            skillrange = {  80,  80, 115, 150 },
        },
        [3278] = {  -- Heavy Wool Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 3531, 1 },                    -- Heavy Wool Bandage
            reagents   = { {2592, 2} },                  -- Wool Cloth ×2
            skillrange = {  115, 115, 150, 185 },
        },
        [7928] = {  -- Silk Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 6450, 1 },                    -- Silk Bandage
            reagents   = { {4306, 1} },                  -- Silk Cloth ×1
            skillrange = { 150, 150, 180, 210 },
        },

        -- ===== Bandages — Expert tier (book 'Expert First Aid - Under Wraps' 16084) =====
        [7929] = {  -- Heavy Silk Bandage
            category   = "Consumable",
            source     = { kind = "trainerManual", item = 16112 },
            output     = { 6451, 1 },                    -- Heavy Silk Bandage
            reagents   = { {4306, 2} },                  -- Silk Cloth ×2
            skillrange = { 180, 180, 210, 240 },
        },
        [10840] = { -- Mageweave Bandage
            category   = "Consumable",
            source     = { kind = "trainerManual", item = 16113 },
            output     = { 8544, 1 },                    -- Mageweave Bandage
            reagents   = { {4338, 1} },                  -- Mageweave Cloth ×1
            skillrange = { 210, 210, 240, 270 },
        },
        [10841] = { -- Heavy Mageweave Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 8545, 1 },                    -- Heavy Mageweave Bandage
            reagents   = { {4338, 2} },                  -- Mageweave Cloth ×2
            skillrange = { 240, 240, 270, 300 },
        },

        [18629] = { -- Runecloth Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 14529, 1 },                   -- Runecloth Bandage
            reagents   = { {14047, 1} },                 -- Runecloth ×1
            skillrange = { 260, 260, 290, 320 },
        },
        [18630] = { -- Heavy Runecloth Bandage
            category   = "Consumable",
            source     = { kind = "trainer" },
            output     = { 14530, 1 },                   -- Heavy Runecloth Bandage
            reagents   = { {14047, 2} },                 -- Runecloth ×2
            skillrange = { 290, 290, 320, 350 },
        },

        -- ===== Anti-Venom line (Deeg, NPC 2488 in Tanaris) =====
        [7934] = {  -- Anti-Venom (taught directly by Deeg)
            category   = "Reagent",
            source     = { kind = "trainer", npc = 2488 },
            output     = { 6452, 1 },                    -- Anti-Venom
            reagents   = { {1475, 1} },                  -- Small Venom Sac ×1
            skillrange = {  80,  80, 115, 150 },
        },
        [7935] = {  -- Strong Anti-Venom (Manual sold by Deeg)
            category   = "Reagent",
            source     = { kind = "vendor", npc = 2488, item = 6454 },
            output     = { 6453, 1 },                    -- Strong Anti-Venom
            reagents   = { {1288, 1} },                  -- Large Venom Sac ×1
            skillrange = { 130, 130, 165, 200 },
        },
        [23787] = { -- Powerful Anti-Venom (Argent Dawn rep reward)
            category   = "Reagent",
            source     = { kind = "reputation", faction = "Argent Dawn", standing = "Honored", item = 19442 },
            output     = { 19440, 1 },                   -- Powerful Anti-Venom
            reagents   = { {19441, 1} },                 -- Huge Venom Sac ×1
            skillrange = { 300, 300, 330, 360 },
        },
    },

    };
}
