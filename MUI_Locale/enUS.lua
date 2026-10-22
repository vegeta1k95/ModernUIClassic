-- English: every key there is. The other languages' files set only what
-- they translate. Keys are grouped by module.

local L = MUI.L

-- ---- retail's global strings: tools/locale_retail.py writes this block
L.CALENDAR_FILTER_HOLIDAYS = "Holidays"
L.CONTACTS_RECENT_ALLIES_TAB_NAME = "Recent Allies"
L.CRITERIA_COMPLETED = "Completed"
L.CRITERIA_NOT_COMPLETED = "Not completed"
L.DUNGEON_POI_TOOLTIP_INSTRUCTION_LINE = "<Right Click to open Adventure Guide>"
L.ENCOUNTER_JOURNAL_SECTION_FLAG13 = "Bleed"
L.INSPECT_GUILD_REALM = "Realm: %s"
L.MAP_FILTER = "Map Filter"
L.MAP_LEGEND_CATEGORY_ACTIVITIES = "Activities"
L.MAP_LEGEND_CATEGORY_MOVEMENT = "Movement"
L.MAP_LEGEND_CATEGORY_QUESTS = "Quests"
L.MAP_LEGEND_FLIGHTPOINT = "Flightpoint"
L.MAP_LEGEND_FRAME_LABEL = "Map Legend"
L.MAP_LEGEND_HUB = "Hub"
L.MAP_LEGEND_REPEATABLE = "Repeatable"
L.MAP_LEGEND_TURNIN = "Turn In"
L.MAP_PIN = "Map Pin"
L.MAP_PIN_REMOVE = "<Ctrl click to remove pin>"
L.MAP_PIN_TOOLTIP = "Place a locational pin on the map that can be tracked and shared with other players."
L.MAP_PIN_TOOLTIP_INSTRUCTIONS = "Click this button and then the map to drop a pin or <Ctrl click directly on the map>"
L.PROFESSIONS_RECIPE_UNLEARNED = "Recipe Unlearned"
L.PROFESSIONS_TRACKER_HEADER_PROFESSION = "Profession"
L.PROFESSIONS_TRACK_RECIPE = "Track Recipe"
L.QUEST_HUB_TOOLTIP_MORE_QUESTS_REMAINING = "+%d more"
L.QUEST_LOG_NO_QUESTS = "No quests available|n|nAccept quests by talking to characters with a |TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t above their head."
L.QUEST_LOG_SHOW_OBJECTIVES = "Show Quest Objectives"
L.RECENT_ALLIES_MENU_BUTTON_LABEL_PIN = "Pin"
L.RECENT_ALLIES_MENU_BUTTON_LABEL_UNPIN = "Unpin"
L.SEARCH_QUEST_LOG = "Search Quest Log"
L.SELL_ALL_JUNK_ITEMS = "Sell All Junk Items"
L.SUPER_TRACK_QUEST = "Focus"
L.TALENT_FRAME_APPLY_BUTTON_TEXT = "Apply Changes"
L.TRACKER_ALL_OBJECTIVES = "All Objectives"
-- ---- end of retail's global strings

-- MUI_Achievements: the lines under an achievement, its tooltip, the frame
L.STAT_PORTAL_TO = "Portal to %s"      -- a mage portal's name (a game object's, with no id)
L.ACH_OWN_MOUNT = "Own a mount"
L.ACH_OWN_EPIC_MOUNT = "Own an epic mount"
L.ACH_WEAPON_SKILLS_AT = "Weapon skills at %d"     -- a progress bar: how many weapon skills reached %d
L.ACH_PRIMARY_PROFESSION_SKILL = "Primary profession skill"
L.ACH_PROFESSIONS_AT = "Professions at %d"
L.ACH_HIGHEST_SKILL = "Highest effective skill"
L.ACH_RECIPES_KNOWN = "%s recipes known"           -- %s: a profession's name
L.ACH_BANK_SLOTS = "Bank bag slots purchased"
L.ACH_COMPANIONS = "Unique companions"
L.ACH_FOODS = "Different foods"
L.ACH_DRINKS = "Different drinks"
L.ACH_BOOKS = "Books read"
L.ACH_CRITTERS_LOVED = "Critter species loved"     -- the /love emote on critters
L.ACH_DANCES = "Dances"
L.ACH_JOKES = "Jokes told"
L.ACH_HUGS = "Players hugged"
L.ACH_FASTER_THAN_EPIC_MOUNT = "Ride faster than an epic mount"
L.ACH_CRITTER_HIT = "Hit a level 1 critter for %d damage"
L.ACH_INTERRUPTS = "Spells interrupted"
L.ACH_BLOCKS = "Attacks blocked"
L.ACH_CLUTCH_HEAL = "Save a player from 1% health"
L.ACH_SELF_KILL = "Engineer your own demise"      -- die by one's own engineering device
L.ACH_CREATURES_KILLED = "Creatures killed"
L.ACH_KILL_WITHIN = "Kill %d within %d seconds"
L.ACH_BOSSES_THIS_LOCKOUT = "Bosses this lockout"
L.ACH_BOSS_WITHIN = "%s within %d minutes"         -- %s: a boss, %d: minutes from entering the dungeon
L.ACH_FLAWLESS_END_BOSS = "Flawless end-boss kill"
L.ACH_QUESTS_COMPLETED = "Quests completed"
L.ACH_GOLD_FROM_QUESTS = "Gold earned from quests"
L.ACH_QUESTS_IN_A_DAY = "Most quests in one day"
L.ACH_QUESTS_WITHIN = "Turn in %d quests within %d minutes"
L.ACH_AREAS_EXPLORED = "Areas explored"
L.ACH_EXALTED_REPUTATIONS = "Exalted reputations"
L.ACH_BUBBLE_HEARTH = "Hearth inside Divine Shield"   -- use the Hearthstone while Divine Shield is up
L.ACH_CRAFT_EPIC = "Craft an epic item"
L.ACH_FISH_CAUGHT = "Fish caught"
L.ACH_LOOT_EPIC = "Loot an epic item"
L.ACH_EPICS_LOOTED = "Epic items looted"
L.ACH_ITEMS_LOOTED = "Items looted"
L.ACH_ORES_MINED = "Ores mined"
L.ACH_HERBS_GATHERED = "Herbs gathered"
L.ACH_CREATURES_SKINNED = "Creatures skinned"
L.ACH_GOLD_LOOTED = "Gold looted"
L.ACH_GOLD_HELD = "Gold held"
L.ACH_EPIC_SLOTS = "Epic-quality slots"            -- equipment slots holding an epic item
L.ACH_SUPERIOR_SLOTS = "Superior-quality slots"
L.ACH_TICKETS_SPENT = "Tickets spent"              -- Darkmoon Faire prize tickets
L.ACH_ATTAIN_RANK = "Attain rank %d"               -- a PvP rank
L.ACH_WIN_DUEL = "Win a duel"
L.ACH_DUELS_WON = "Duels won"
L.ACH_CITY_KILLING_BLOWS = "Killing blows in home cities"
L.ACH_WIN_BATTLE = "Win the battle"
L.ACH_VICTORIES = "Victories"
L.ACH_MOST_KILLS_BATTLE = "Most kills in one battle"
L.ACH_MOST_DAMAGE_BATTLE = "Most damage in one battle"
L.ACH_FLAWLESS_KILLING_BLOWS = "Best flawless killing blows"   -- killing blows in one battle without dying
L.ACH_CAPTURE_FLAG = "Capture the flag"
L.ACH_CAPTURE_UNDER = "Capture in under %d seconds"
L.ACH_IRONMAN_CAPTURES = "3 captures, no deaths, one battle"
L.ACH_PERFECT_WIN = "Win without conceding a point"
L.ACH_PET_FAMILIES = "Pet families tamed"
L.ACH_TAME_RARE = "Tame a famous rare beast"
L.ACH_SECOND_TALENT_GROUP = "Activate a second talent group"
L.ACH_SOLO_END_BOSS = "Defeat a dungeon end boss alone"
L.ACH_DUNGEON_QUESTS = "Dungeon quests completed"
L.ACH_MOUNTS_OWNED = "Mounts owned"
L.ACH_DAYS_PLAYED = "Days played"
L.ACH_BIG_BAGS = "Bags of 16 slots or more"
L.ACH_GRANTED = "ModernUI: %d |4achievement:achievements; (%d |4point:points;) granted for past deeds."   -- in chat, the first time
L.ACH_EARNED_BEFORE_TRACKING = "Earned before achievement tracking began."
L.ACH_CANT_TRACK_COMPLETED = "You may not track completed achievements."

-- MUI_AuctionHouse
L.AH_NO_AUCTIONS = "You have no auctions."
L.AH_NO_BIDS = "You have no bids."
L.AH_AUCTION_CHANGED = "That auction has changed."   -- an error: the auction a click was for is gone or different
L.AH_FAVORITES_SEARCH = "Search for your favorite items."
L.AH_FAVORITES_HOW = "Star an item in the results to add it to your favorites."
L.AH_RESULTS_CAPPED = "Showing the first %d auctions by name. Narrow the search to see the rest."
L.AH_SEARCH_INTERRUPTED = "Search interrupted. Search again for the full results."
L.AH_NO_FAVORITES = "You have no favorite items. Star an item in the results to add one."
L.AH_QUANTITY_SHORT = "Qty"                          -- a narrow column's header
L.AH_BUYOUT_ONLY = "Buyout Only"                     -- a checkbox
L.AH_BUYOUT_ONLY_TOOLTIP = "Sell at a fixed price. Uncheck to set a starting bid, with or without a buyout."
L.AH_SELL_SLOT_TOOLTIP = "Drag an item here to auction it, or right-click it in your bags."

-- MUI_Bags / MUI_Bank
L.BAGS_CLEANUP_TOOLTIP = "Automatic item sorting is a setting that automatically places items. You can choose a specific type of item for each bag by clicking the icon in the upper-left corner of the bag."
L.BAGS_SEPARATE = "Separate Bags"                    -- the opposite of Blizzard's "Combine Bags"
L.BANK_DEPOSIT_TOOLTIP = "Move every trade good in your bags into the bank."

-- MUI_Calendar
L.CAL_TOGGLE = "Toggle Calendar"                     -- a key binding
L.CAL_BATTLEGROUND_WEEKENDS = "Battleground Weekends"   -- a calendar filter
L.CAL_HOLIDAY_LUNAR_FESTIVAL = "Lunar Festival"   -- retail HolidayNames 18
L.CAL_HOLIDAY_LUNAR_FESTIVAL_DESC = "Every year the druids of Moonglade hold a celebration of their city's great triumph over an ancient evil. During the Lunar Festival, citizens of Azeroth have the opportunity to honor their elders by celebrating their sage wisdom, sharing in magnificent feasts, and of course... shooting lots of fireworks!"   -- retail HolidayDescriptions 17
L.CAL_HOLIDAY_LOVE_IS_IN_THE_AIR = "Love is in the Air"   -- retail HolidayNames 9
L.CAL_HOLIDAY_LOVE_IS_IN_THE_AIR_DESC = "Something is in the air in the major cities of Azeroth. Many guards and townsfolk spend their days giving and receiving gifts to other amorous citizens."
L.CAL_HOLIDAY_NOBLEGARDEN = "Noblegarden"   -- retail HolidayNames 15
L.CAL_HOLIDAY_NOBLEGARDEN_DESC = "The feast of Noblegarden has arrived.  The proving grounds of each race, the place where young heroes first test their strength, each holds cleverly hidden treasure eggs.  How many can you find?"   -- retail HolidayDescriptions 14
L.CAL_HOLIDAY_CHILDRENS_WEEK = "Children's Week"   -- retail HolidayNames 13
L.CAL_HOLIDAY_CHILDRENS_WEEK_DESC = "Show an orphan what the hero's life is like!  Visit Orphan Matron Nightingale in Stormwind or Orphan Matron Battlewail in Orgrimmar and make a child's dream come true."
L.CAL_HOLIDAY_MIDSUMMER = "Midsummer Fire Festival"   -- retail HolidayNames 11
L.CAL_HOLIDAY_MIDSUMMER_DESC = "A time of merriment and celebration, dedicated to the hottest season of the year."   -- retail HolidayDescriptions 10
L.CAL_HOLIDAY_FIREWORKS = "Fireworks Spectacular"   -- retail HolidayNames 12
L.CAL_HOLIDAY_FIREWORKS_DESC = "After the sun sets, the end of Midsummer is celebrated, with an hourly firework extravaganza.\n\nTo watch the show, visit any capital city or Booty Bay."   -- retail HolidayDescriptions 11
L.CAL_HOLIDAY_HARVEST_FESTIVAL = "Harvest Festival"   -- retail HolidayNames 17
L.CAL_HOLIDAY_HARVEST_FESTIVAL_DESC = "The Harvest Festival is a time to commemorate those who have sacrificed their lives to help friends and allies.  Feasts are held outside Orgrimmar and Ironforge in honor of these fallen heroes."   -- retail HolidayDescriptions 16
L.CAL_HOLIDAY_HALLOWS_END = "Hallow's End"   -- retail HolidayNames 16
L.CAL_HOLIDAY_HALLOWS_END_DESC = "Hallow's End celebrates the break of the Forsaken from the Scourge.\n\nFun and mischief reign as the Innkeepers of Azeroth give treats, and tricks, to whomever asks."   -- retail HolidayDescriptions 15
L.CAL_HOLIDAY_WINTER_VEIL = "Feast of Winter Veil"   -- retail HolidayNames 14
L.CAL_HOLIDAY_WINTER_VEIL_DESC = "Greatfather Winter is visiting the cities of Ironforge and Orgrimmar, courtesy of Smokywood Pastures.  And throughout Azeroth, it is the season to be jolly!"   -- retail HolidayDescriptions 13
L.CAL_HOLIDAY_DARKMOON_ELWYNN_DESC = "The Darkmoon Faire is here, this time in idyllic Elwynn Forest.\n\nMeet Silas Darkmoon and his troupe, play games that test mind and nerve, and behold exotic sights from the four corners of Azeroth... and beyond!"   -- retail HolidayDescriptions 1
L.CAL_HOLIDAY_DARKMOON_MULGORE_DESC = "The Darkmoon Faire is here, this time at the foot of Thunder Bluff.\n\nMeet Silas Darkmoon and his troupe, play games that test mind and nerve, and behold exotic sights from the four corners of Azeroth... and beyond!"   -- retail HolidayDescriptions 26
L.CAL_HOLIDAY_FISHING_EXTRAVAGANZA = "Stranglethorn Fishing Extravaganza"   -- retail HolidayNames 6
L.CAL_HOLIDAY_FISHING_EXTRAVAGANZA_DESC = "A fishing tournament, competed along the coasts of Stranglethorn Vale.  Catch as many tastyfish as you can!  \n\nWill you be one of the first to catch forty fish and win a prize?  Tastyfish can be caught for two hours after the contest begins, but you'll have to be quick to win!"   -- retail HolidayDescriptions 4
L.CAL_HOLIDAY_CALL_TO_ARMS_AB = "Call to Arms: Arathi Basin"   -- retail HolidayNames 23
L.CAL_HOLIDAY_CALL_TO_ARMS_AB_DESC = "The battle for Arathi Basin grows intense.  Greater honor is given to those who pledge sword to their liege and battle in Arathi."   -- retail HolidayDescriptions 23
L.CAL_HOLIDAY_CALL_TO_ARMS_AV = "Call to Arms: Alterac Valley"   -- retail HolidayNames 22
L.CAL_HOLIDAY_CALL_TO_ARMS_AV_DESC = "The battle for Alterac Valley grows intense.  Greater honor is given to those who pledge sword to their liege and battle in Alterac."   -- retail HolidayDescriptions 22
L.CAL_HOLIDAY_CALL_TO_ARMS_WSG = "Call to Arms: Warsong Gulch"   -- retail HolidayNames 25
L.CAL_HOLIDAY_CALL_TO_ARMS_WSG_DESC = "The battle for Warsong Gulch grows intense.  Greater honor is given to those who pledge sword to their liege and battle in the Gulch."   -- retail HolidayDescriptions 25

-- MUI_Character
L.CHAR_EQUIPMENT_SET = "Equipment Set"               -- the title of the dialog that edits a set
L.CHAR_NEW_SET_TOOLTIP = "Save what you are wearing as an equipment set."
L.CHAR_DOUBLE_CLICK_EQUIP = "Double-click to equip."
L.CHAR_STAT_MELEE_DPS = "The damage your main hand weapon deals each second, on average."
L.CHAR_STAT_MELEE_SPEED = "The seconds between your melee swings."
L.CHAR_STAT_HIT = "Your bonus chance to hit with melee and ranged attacks."
L.CHAR_STAT_MELEE_CRIT = "Your chance to critically strike with melee attacks."
L.CHAR_STAT_RANGED_DPS = "The damage your ranged weapon deals each second, on average."
L.CHAR_STAT_RANGED_SPEED = "The seconds between your ranged attacks."
L.CHAR_STAT_RANGED_CRIT = "Your chance to critically strike with ranged attacks."
L.CHAR_STAT_HEALING = "Increases the healing your spells and effects do."
L.CHAR_STAT_SPELL_HIT = "Your bonus chance to hit with spells."
L.CHAR_STAT_REGEN_NOT_CASTING = "Every 5 sec. while not casting"   -- mana regained; the number follows on the right
L.CHAR_STAT_REGEN_CASTING = "Every 5 sec. while casting"
L.CHAR_STAT_DODGE = "Your chance to dodge melee attacks."
L.CHAR_STAT_PARRY = "Your chance to parry melee attacks from the front."
L.CHAR_STAT_BLOCK = "Your chance to block attacks from the front with a shield."
L.CHAR_STAT_DAMAGE_BLOCKED = "Damage blocked"        -- the shield's block value follows on the right

-- MUI_Collections: where an armor set comes from, when no place or profession names it
L.COLLECTIONS_DUNGEON_SET_1 = "Dungeon Set 1"
L.COLLECTIONS_DUNGEON_SET_2 = "Dungeon Set 2"
L.COLLECTIONS_PVP_RANK = "PvP Rank %d"

-- MUI_Core
L.CORE_SETTINGS_RESET = "new character on this name slot, settings reset to defaults."   -- in chat after "ModernUI:"

-- MUI_DB: a quest hub's line under its name, on the world map
L.HUB_LIGHTS_HOPE_CHAPEL = "Sanctified Argent Dawn outpost guarding the Plaguelands."
L.HUB_BOOTY_BAY = "Goblin port and Steamwheedle Cartel stronghold on Stranglethorn's southern coast."
L.HUB_GADGETZAN = "Goblin trade city in the Tanaris desert."
L.HUB_EVERLOOK = "Goblin trading post tucked into Winterspring's icy peaks."
L.HUB_RATCHET = "Steamwheedle Cartel port on the eastern Barrens shore."
L.HUB_CENARION_HOLD = "Druid stronghold in Silithus, anchoring the war against the Qiraji."
L.HUB_THORIUM_POINT = "Thorium Brotherhood encampment in the Searing Gorge."

-- MUI_EditMode
L.EDITMODE_SETTINGS_TITLE = "%s Settings"            -- %s: a frame's name ("Action Bar 1")
L.EDITMODE_MAX_LAYOUTS = "Only %d layouts are allowed."
L.EDITMODE_REPUTATION_BAR = "Reputation Bar"
L.EDITMODE_GRID = "Grid"                             -- a short checkbox: snap to the grid
L.EDITMODE_PRESS_TO_COPY = "Press Ctrl+C to copy:"

-- MUI_Map: the world map, its quest log and legend
L.MAP_SHOW_LOW_LEVEL_QUESTS = "Show Low-Level Quests"   -- the map's filter menu
L.MAP_SHOW_DUNGEONS = "Show Dungeons"                   -- dungeon and raid entrances
L.MAP_LEGEND_AVAILABLE_PVP = "Available PvP"            -- legend rows: the map's marks
L.MAP_LEGEND_REPEATABLE_TURN_IN = "Repeat. Turn-in"     -- a repeatable quest ready to hand in (short)
L.MAP_LEGEND_KILL_QUEST = "Kill Quest"
L.MAP_LEGEND_COLLECT_QUEST = "Collect Quest"
L.MAP_LEGEND_ELITE_QUEST = "Elite Quest"
L.MAP_LEGEND_DUNGEON_QUEST = "Dungeon Quest"
L.MAP_LEGEND_RAID_QUEST = "Raid Quest"
L.MAP_LEGEND_PVP_QUEST = "PvP Quest"
L.MAP_LEGEND_TRANSPORT = "Transport"                    -- boat and zeppelin docks
L.MAP_TRAVEL_WAYPOINT = "Travel Waypoint"               -- the waypoint to the dock on the way to a far target
L.MAP_SHOW_QUEST_LEVEL = "Show Quest Level"             -- the quest log's settings menu
L.MAP_COLOR_QUESTS_BY_LEVEL = "Color Quests by Level"
L.MAP_QUEST_TYPE_ICONS = "Quest Type Icons"
L.MAP_ZONE_STORY = "Zone Story"
L.MAP_AUTO_COLLAPSE = "Auto-Collapse Categories"
L.MAP_STORY_STARTS_AT = "Starts at: %s"                 -- a zone story step's tooltip; %s: the quest giver
L.MAP_STORY_EITHER_QUEST = "Only one of these quests can be taken; either one completes the step."
L.MAP_STORY_IN_QUEST_LOG = "In your quest log"
L.MAP_STORY_SHOW_CHAPTERS = "<Click to show the chapters>"
L.MAP_STORY_HIDE_CHAPTERS = "<Click to hide the chapters>"
L.MAP_ZEPPELIN_TO = "Zeppelin to %s"                    -- a dock's label; %s: the town on the far side
L.MAP_BOAT_TO = "Boat to %s"
L.MAP_TAKE_ZEPPELIN = "Take the zeppelin from %s to %s."   -- %1$s: this dock's town, %2$s: the far side's
L.MAP_TAKE_BOAT = "Take the boat from %s to %s."
L.MAP_CLICK_TO_VIEW = "<Click to view %s>"              -- %s: a zone
L.MAP_AVAILABLE_REPEATABLE = "Available repeatable"     -- a quest hub's tooltip: the repeatable quests on offer
L.MAP_PIN_COORDS = "Map coordinates: %.1f, %.1f (%s)"   -- the map pin's tooltip; x, y in percent, then the zone
L.MAP_PIN_COORDS_UNKNOWN = "Map coordinates: ?"
L.MAP_PIN_SHARE_HINT = "<Shift-click to share coordinates in chat>"

-- MUI_Merchant / MUI_Minimap / MUI_Nameplates
L.MERCHANT_NO_JUNK = "No junk in your bags"
L.MINIMAP_ADDON_BUTTONS = "Addon Buttons"               -- the button that collects other addons' minimap buttons
L.MINIMAP_ADDON_BUTTONS_TOOLTIP = "Collected minimap buttons."
L.MINIMAP_QUEST_AREA = "Quest Area"                     -- tracking menu: draw quest objective areas on the minimap
L.NAMEPLATES_SHOW_LEVEL = "Show level"                  -- options in Blizzard's nameplate settings
L.NAMEPLATES_SHOW_LEVEL_TOOLTIP = "Show the unit's level on its nameplate (Blizzard only does in the Classic style)."
L.NAMEPLATES_QUEST_ICON = "Show quest objective icon"
L.NAMEPLATES_QUEST_ICON_TOOLTIP = "Mark nameplates of NPCs an accepted quest still needs: a sword to kill, a bag to loot."

-- MUI_Professions
L.PROF_NO_RESULTS = "No recipes match the current filters."
L.PROF_NO_SOURCE = "Unknown — no source on file."      -- where an unknown recipe is learned
L.PROF_SOURCE_TRAINER = "Profession trainer"            -- a source line's label; the profession follows
L.PROF_CREATURES_IN = "creatures in %s"                 -- after "Loot:"; %s: a zone
L.PROF_SOURCE = "Source"                                -- a source line's label; a colon follows
L.PROF_CAT_AXE = "Axe"                                  -- recipe groups in the list of recipes not yet learned
L.PROF_CAT_BAG = "Bag"
L.PROF_CAT_BOOTS = "Boots"
L.PROF_CAT_BRACER = "Bracer"
L.PROF_CAT_CHEST = "Chest"
L.PROF_CAT_CLOAK = "Cloak"
L.PROF_CAT_CLOTH_ARMOR = "Cloth Armor"
L.PROF_CAT_CONSUMABLE = "Consumable"
L.PROF_CAT_DAGGER = "Dagger"
L.PROF_CAT_ELIXIR = "Elixir"
L.PROF_CAT_ENGINEERED_ITEM = "Engineered Item"
L.PROF_CAT_FLASK = "Flask"
L.PROF_CAT_GLOVES = "Gloves"
L.PROF_CAT_GUN = "Gun"
L.PROF_CAT_ITEM_ENHANCEMENT = "Item Enhancement"
L.PROF_CAT_LEATHER_ARMOR = "Leather Armor"
L.PROF_CAT_MACE = "Mace"
L.PROF_CAT_MAIL_ARMOR = "Mail Armor"
L.PROF_CAT_MATERIAL = "Material"
L.PROF_CAT_MISC_ARMOR = "Misc Armor"
L.PROF_CAT_OIL = "Oil"                                  -- weapon oils and the like (enchanting)
L.PROF_CAT_PLATE_ARMOR = "Plate Armor"
L.PROF_CAT_POLEARM = "Polearm"
L.PROF_CAT_POTION = "Potion"
L.PROF_CAT_REAGENT = "Reagent"
L.PROF_CAT_RODS = "Rods"                                -- enchanting rods
L.PROF_CAT_SHIELD = "Shield"
L.PROF_CAT_SHIRT = "Shirt"
L.PROF_CAT_SWORD = "Sword"
L.PROF_CAT_TRADE_GOODS = "Trade Goods"
L.PROF_CAT_WEAPON = "Weapon"
L.PROF_CAT_WEAPON_COATING = "Weapon Coating"            -- poisons, sharpening stones
L.PROF_FACTION_ARGENT_DAWN = "Argent Dawn"              -- era Faction.Name 529
L.PROF_FACTION_CENARION_CIRCLE = "Cenarion Circle"      -- era Faction.Name 609
L.PROF_FACTION_THORIUM_BROTHERHOOD = "Thorium Brotherhood"   -- era Faction.Name 59
L.PROF_FACTION_TIMBERMAW_HOLD = "Timbermaw Hold"        -- era Faction.Name 576
L.PROF_FACTION_ZANDALAR_TRIBE = "Zandalar Tribe"        -- era Faction.Name 270

-- MUI_QuestHelper: a quest link's tooltip
L.QUEST_COMPLETED_BEFORE = "You have completed this quest"
L.QUEST_REPEATABLE = "This quest is repeatable"
L.QUEST_NOT_DONE = "You have not done this quest"
L.QUEST_INELIGIBLE = "You are ineligible for this quest"
L.QUEST_AUTO_COMPLETE = "This quest is an automatic completion quest and does not contain an objective."
L.QUEST_INSTANCE = "Instance: %s"                      -- %s: a dungeon
L.QUEST_YOUR_PROGRESS = "Your progress:"
L.QUEST_STARTED_BY = "Started by: %s"                  -- %s: a creature, object or item
L.QUEST_ENDED_BY = "Ended by: %s"
L.QUEST_FOUND_IN = "Found in: %s"                      -- %s: a zone

-- MUI_Social
L.SOCIAL_GROUPED_AGO = "Grouped %s ago"                -- %s: a time ("3 days"), from Blizzard
L.SOCIAL_ALLIES_EMPTY = "Players you group with are listed here."

-- MUI_Spellbook: spells, specializations, talents
L.SPELLBOOK_TALENT_AT_LEVEL = "Talent at level %s"     -- a rank's tooltip line; %s: the level
L.SPELLBOOK_QUEST_AT_LEVEL = "Quest at level %s"
L.SPELLBOOK_NEXT_RANK_AT_LEVEL = "Next rank at level %s"
L.SPELLBOOK_LEARNED_AT_LEVEL = "Learned at level %s"
L.SPELLBOOK_SOURCE_TRAINER = "Trainer"                 -- where a spell is learned, after "Available at level N"
L.SPELLBOOK_GROUP_TELEPORT = "Teleport"                -- one book entry for the mage's teleports
L.SPELLBOOK_GROUP_PORTAL = "Portal"                    -- and one for the portals
L.SPELLBOOK_DB_UPDATED = "Updated spells DB with %d entries"   -- in chat after "ModernUI:"
L.SPELLBOOK_SHOW_PASSIVES = "Show passive abilities"   -- the spellbook's settings menu
L.SPELLBOOK_SHOW_HEADER_ICONS = "Show header icons"
L.SPELLBOOK_ABILITIES_SHOWCASE = "Abilities showcase"  -- a header over a specialization's key spells
L.TALENTS_ACTIVE = "Active"                            -- a talent group's state, in parentheses
L.TALENTS_INACTIVE = "Inactive"
L.TALENTS_NOT_PURCHASED = "Not purchased"              -- dual specialization not bought yet
L.TALENTS_POINTS_AVAILABLE = "AVAILABLE TALENT POINTS: %s"   -- upper case in the design
L.TALENTS_FULL_VIEW = "Full view"                      -- a button switching the tree's view
L.TALENTS_DETAIL_VIEW = "Detail view"
L.TALENTS_PRIMARY = "Primary"                          -- the two talent groups
L.TALENTS_SECONDARY = "Secondary"
L.TALENTS_VISIT_TRAINER = "Visit one of the class trainers in a major city to unlock the full tree"
L.SPELLBOOK_SPEC_ARMS = "A battle-hardened master of weapons, using mobility and overpowering attacks to strike their opponents down."   -- retail ChrSpecialization.Description 71, first line
L.SPELLBOOK_SPEC_FURY = "A furious dual-wielding berserker unleashing a flurry of attacks to carve their opponents to pieces."   -- retail ChrSpecialization.Description 72, first line
L.SPELLBOOK_SPEC_PROTECTION_WARRIOR = "A stalwart protector who uses a shield to safeguard themselves and their allies."   -- retail ChrSpecialization.Description 73, first line
L.SPELLBOOK_SPEC_HOLY_PALADIN = "Invokes the power of the Light to heal and protect allies and vanquish evil from the darkest corners of the world."   -- retail ChrSpecialization.Description 65, first line
L.SPELLBOOK_SPEC_PROTECTION_PALADIN = "Uses Holy magic to shield themselves and defend allies from attackers."   -- retail ChrSpecialization.Description 66, first line
L.SPELLBOOK_SPEC_RETRIBUTION = "A righteous crusader who judges and punishes opponents with weapons and Holy magic."   -- retail ChrSpecialization.Description 70, first line
L.SPELLBOOK_SPEC_BEAST_MASTERY = "A master of the wild who can tame a wide variety of beasts to assist them in combat."   -- retail ChrSpecialization.Description 253, first line
L.SPELLBOOK_SPEC_MARKSMANSHIP = "A master sharpshooter who excels in bringing down enemies from afar."   -- retail ChrSpecialization.Description 254, first line
L.SPELLBOOK_SPEC_SURVIVAL = "An adaptive ranger who favors using explosives, animal venom, and coordinated attacks with their bonded beast."   -- retail ChrSpecialization.Description 255, first line
L.SPELLBOOK_SPEC_ASSASSINATION = "A deadly master of poisons who dispatches victims with vicious dagger strikes."   -- retail ChrSpecialization.Description 259, first line
L.SPELLBOOK_SPEC_COMBAT = "A ruthless fugitive who uses agility and guile to stand toe-to-toe with enemies."   -- retail ChrSpecialization.Description 260, first line
L.SPELLBOOK_SPEC_SUBTLETY = "A dark stalker who leaps from the shadows to ambush their unsuspecting prey."   -- retail ChrSpecialization.Description 261, first line
L.SPELLBOOK_SPEC_DISCIPLINE = "Shields allies from harm and cures their wounds by smiting enemies."   -- retail ChrSpecialization.Description 256, first line
L.SPELLBOOK_SPEC_HOLY_PRIEST = "A versatile healer who can reverse damage on individuals or groups and even heal from beyond the grave."   -- retail ChrSpecialization.Description 257, first line
L.SPELLBOOK_SPEC_SHADOW = "Uses sinister Shadow magic and terrifying Void magic to eradicate enemies."   -- retail ChrSpecialization.Description 258, first line
L.SPELLBOOK_SPEC_ELEMENTAL = "A spellcaster who harnesses the destructive forces of nature and the elements."   -- retail ChrSpecialization.Description 262, first line
L.SPELLBOOK_SPEC_ENHANCEMENT = "A totemic warrior who strikes foes with weapons imbued with elemental power."   -- retail ChrSpecialization.Description 263, first line
L.SPELLBOOK_SPEC_RESTORATION_SHAMAN = "A healer who calls upon ancestral spirits and the cleansing power of water to mend allies' wounds."   -- retail ChrSpecialization.Description 264, first line
L.SPELLBOOK_SPEC_ARCANE = "Manipulates raw Arcane magic, destroying enemies with overwhelming power."   -- retail ChrSpecialization.Description 62, first line
L.SPELLBOOK_SPEC_FIRE = "Focuses the pure essence of Fire magic, assaulting enemies with combustive flames."   -- retail ChrSpecialization.Description 63, first line
L.SPELLBOOK_SPEC_FROST = "Freezes enemies in their tracks and shatters them with Frost magic."   -- retail ChrSpecialization.Description 64, first line
L.SPELLBOOK_SPEC_AFFLICTION = "A master of shadow magic who specializes in drains and damage-over-time spells."   -- retail ChrSpecialization.Description 265, first line
L.SPELLBOOK_SPEC_DEMONOLOGY = "A commander of demons who twists the souls of their army into devastating power."   -- retail ChrSpecialization.Description 266, first line
L.SPELLBOOK_SPEC_DESTRUCTION = "A master of chaos who calls down fire to burn and demolish enemies."   -- retail ChrSpecialization.Description 267, first line
L.SPELLBOOK_SPEC_BALANCE = "Can shapeshift into a powerful Moonkin, balancing the power of Arcane and Nature magic to destroy enemies."   -- retail ChrSpecialization.Description 102, first line
L.SPELLBOOK_SPEC_FERAL = "Takes on the form of a great cat to deal damage with bleeds and bites or a mighty bear to absorb damage and protect allies."
L.SPELLBOOK_SPEC_RESTORATION_DRUID = "Channels powerful Nature magic to regenerate and revitalize allies."   -- retail ChrSpecialization.Description 105, first line

-- MUI_Tooltip / MUI_XPBar
L.TOOLTIP_SKILL = "%s Skill"                            -- an item comparison line; %s: a weapon skill ("Daggers")
L.XPBAR_CURRENT = "Current:"                            -- the experience bar's tooltip
L.XPBAR_REMAINING = "Remaining:"
L.XPBAR_RESTED = "Rested:"
