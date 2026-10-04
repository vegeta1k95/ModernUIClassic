"""
Zone story chapters — hand-curated. Keyed by QuestDB area id; each zone is
(display name, [(chapter name, [entries]), ...]).

Entry forms (see export.py):
    "Quest Name"      every quest of the zone with that name
    "+Quest Name"     that quest plus its whole chain inside the zone
    HUB(x, y, r=8)    every quest still unclaimed whose giver stands within
                      r map-percent of (x, y), with its chain
    166               a quest by id, for one the quest log sorts under
                      another zone (a dungeon's last step of a zone story)
    (None, [...])     claims quests without a chapter: a world-spanning
                      chain that a town hub would otherwise sweep up

Chapters claim quests in the order written; the display order is by lowest
quest level. Quests no chapter claims stay plain zone quests, and a quest
that starts from a dropped item with no chain around it is always one of
those (the exporter refuses it): a random drop is nobody's story. Faction is
not a concern here: the runtime drops the quests the player can't take,
then the chapters left empty.
"""


def HUB(x, y, r=8.0):
    return ("hub", x, y, r)


ZONES = {
    # ---------------------------------------------------------------- Eastern Kingdoms
    12: ("Elwynn Forest", [
        ("Northshire Valley", [HUB(49, 42)]),
        ("The Riverpaw Gnolls", ["Riverpaw Gnoll Bounty", "Westbrook Garrison Needs Help!", 'Wanted:  "Hogger"']),
        ("Eastvale Logging Camp", ["+Further Concerns", "Protect the Frontier", "Red Linen Goods", "A Bundle of Trouble"]),
        ("Stonefields & Maclures", ["+Back to Billy", "Princess Must Die!", "+Young Lovers"]),
        ("Goldshire", [HUB(42, 65)]),
    ]),
    40: ("Westfall", [
        ("The People's Militia", ["The People's Militia", "Patrolling Westfall", "Red Leather Bandanas"]),
        ("The Defias Brotherhood", ["The Defias Brotherhood", 166]),   # 166: VanCleef's head, sorted under The Deadmines
        ("The Westfall Farms", ["Westfall Stew", "The Forgotten Heirloom", "Poor Old Blanchy", "The Killing Fields", "Goretusk Liver Pie"]),
        ("The Westfall Coast", ["Keeper of the Flame", "The Coastal Menace", "The Coast Isn't Clear", "Captain Sander's Hidden Treasure"]),
    ]),
    44: ("Redridge Mountains", [
        ("Solomon's Plea", ["Messenger to Stormwind", "Messenger to Westfall", "Messenger to Darkshire"]),
        ("The Redridge Gnolls", ["Encroaching Gnolls", "Assessing the Threat", "Solomon's Law", "+Underbelly Scales"]),
        ("The Blackrock Menace", ["+Blackrock Menace", "Blackrock Bounty", "Wanted: Gath'Ilzogg", "Wanted: Lieutenant Fangore", "Missing In Action"]),
        ("The Tower of Ilgalar", ["+A Watchful Eye"]),
        ("Lakeshire", [HUB(29, 48)]),
    ]),
    10: ("Duskwood", [
        ("Raven Hill", ["+Jitters' Growling Gut"]),
        ("Sven's Revenge", ["+Sven's Revenge"]),
        ("The Legend of Stalvan", ["The Legend of Stalvan"]),
        ("The Embalmer", ["+Supplies from Darkshire"]),
        ("Mor'Ladim", ["+The Weathered Grave"]),
        ("Nothing But The Truth", ["Nothing But The Truth"]),
        ("Darkshire", [HUB(74, 46)]),
    ]),
    1: ("Dun Morogh", [
        ("Coldridge Valley", ["+Dwarven Outfitters", "+The Troll Cave", "+Scalding Mornbrew Delivery", "The Boar Hunter", "Supplies to Tannok", "A Refugee's Quandary"]),
        ("Brewnall Village", ["+Stocking Jetsteam", "+The Perfect Stout", "+Bitter Rivals", "Tundra MacGrann's Stolen Stash"]),
        ("Kharanos", ["The Grizzled Den", "Tools for Steelgrill", "Operation Recombobulation", "Ammo for Rumbleshot"]),
    ]),
    38: ("Loch Modan", [
        ("Ironband's Excavation", ["+Resupplying the Excavation", "+Gathering Idols"]),
        ("The Stonewrought Dam", ["A Dark Threat Looms"]),
        ("The Valley of Kings", ["In Defense of the King's Lands", "The Trogg Threat"]),
        ("Farstrider Lodge", ["+A Hunter's Boast", "Crocolisk Hunting"]),
        ("Thelsamar", [HUB(35, 47), "Filthy Paws"]),
    ]),
    11: ("Wetlands", [
        ("The Dragonmaw Orcs", ["+The Algaz Gauntlet"]),
        ("The Cursed Crew", ["+The Third Fleet"]),
        ("The Thandol Span", ["The Thandol Span", "Plea To The Alliance", "The Dark Iron War", "A Grim Task"]),
        ("The Greenwarden", ["+Tramping Paws", "Daily Delivery"]),
        ("Whelgar's Excavation", ["Ormer's Revenge", "Uncovering the Past", "In Search of The Excavation Team"]),
        ("Menethil Harbor", [HUB(10, 57)]),
    ]),
    85: ("Tirisfal Glades", [
        ("Deathknell", [HUB(31, 67)]),
        ("The Scarlet Crusade", ["+Proof of Demise"]),
        ("Agamand Mills", ["+Speak with Sevren", "+A Putrid Task"]),
        ("The Prodigal Lich", ["+The Prodigal Lich", "+Return the Book"]),
        ("A New Plague", ["A New Plague", "Delivery to Silverpine Forest", "+Gordo's Task", "Fields of Grief"]),
        ("Brill", [HUB(61, 52), "A Rogue's Deal"]),
    ]),
    130: ("Silverpine Forest", [
        ("The Rot Hide Gnolls", ["+The Dead Fields"]),
        ("Ambermill", ["+Border Crossings"]),
        ("Arugal's Folly", ["+Prove Your Worth", "Beren's Peril", "Pyrewood Ambush"]),
        ("The Deathstalkers", ["+Wild Hearts", "+Escorting Erland"]),
        ("Deep Elem Mine", ["+Resting in Pieces"]),
        ("The Sepulcher", [HUB(45, 41)]),
    ]),
    267: ("Hillsbrad Foothills", [
        ("Battle of Hillsbrad", ["Battle of Hillsbrad", "Souvenirs of Death"]),
        ("Lydon's Elixirs", ["Elixir of Suffering", "Elixir of Pain", "Elixir of Agony"]),
        ("Blackmoore's Legacy", ["+The Rescue"]),
        ("The Crown of Will", ["The Crown of Will", "Helcular's Revenge"]),
        ("Down the Coast", ["+Down the Coast"]),
        ("Hints of a New Plague?", ["Hints of a New Plague?"]),
        ("Southshore", ["Soothing Turtle Bisque", "Costly Menace", "Bartolo's Yeti Fur Cloak"]),
        ("Tarren Mill", [HUB(62, 20)]),
    ]),
    36: ("Alterac Mountains", [
        ("The Syndicate", ["Syndicate Assassins", "+Foreboding Plans", "+Assassin's Contract", "+The Ensorcelled Parchment"]),
        ("Dark Council", ["+Encrypted Letter"]),
        ("Crushridge Ogres", ["+Crushridge Bounty"]),
    ]),
    45: ("Arathi Highlands", [
        ("Trol'kalar", ["+Sigil of Strom"]),
        ("Hammerfall", ["+Hammerfall", "+Call to Arms", "Foul Magics"]),
        ("Trelane's Tower", ["+Worth Its Weight in Gold"]),
        ("Refuge Pointe", ["+Northfold Manor", "Wanted!  Marez Cowl", "Wanted!  Otto and Falconcrest"]),
        ("Faldir's Cove", ["+Land Ho!"]),
        ("Princess Myzrael", ["+The Princess Trapped", "Summoning the Princess"]),
    ]),
    33: ("Stranglethorn Vale", [
        ("Nesingwary's Expedition", ["+Welcome to the Jungle"]),
        ("Colonel Kurzen", ["+The Second Rebellion"]),
        ("The Rebel Camp", ["+Jungle Secrets", "+Krazek's Cookery", "Supplies to Private Thorsen", "Investigate the Camp"]),
        ("Saving Yenniku", ["+Hunt for Yenniku"]),
        ("Grom'gol Base Camp", ["Mok'thardin's Enchantment", "+Bloody Bone Necklaces", "The Defense of Grom'gol", "Trollbane"]),
        ("The Bloodsail Buccaneers", ["+Up to Snuff"]),
        (None, ["+Avast Ye, Scallywag", "Dressing the Part"]),   # Bloodsail reputation rewards, not the story
        ("The Curse of the Tides", ["+The Stone of the Tides"]),
        ("The Old Sea Dogs", ["+Scaring Shaky", "+The Captain's Chest", "Cortello's Riddle"]),
        ("Booty Bay", [HUB(28, 76)]),
    ]),
    47: ("The Hinterlands", [
        ("Saving Sharpbeak", ["+Witherbark Cages", "+The Divination"]),
        ("Aerie Peak", ["+Gryphon Master Talonaxe", "Skulk Rock Clean-up", "Troll Necklace Bounty"]),
        ("The Vilebranch", ["+Kidnapped Elder Torntusk!", "Stalking the Stalkers", "Hunt the Savages", "Avenging the Fallen", "Separation Anxiety",
                            "Dark Vessels", "Wanted: Vile Priestess Hexx and Her Minions"]),
        ("Revantusk Village", [HUB(79, 79)]),
        ("Summoning Shadra", ["+Venom Bottles", "+Summoning Shadra", "Grim Message"]),
        ("Rin'ji's Secret", ["+Rin'ji is Trapped!", "A Sticky Situation"]),
    ]),
    3: ("Badlands", [
        ("The Shattered Necklace", ["+Necklace Recovery", "+The Shattered Necklace"]),
        ("Study of the Elements", ["+Study of the Elements: Rock"]),
        ("Hammertoe's Digsite", ["+A Sign of Hope", "A Dwarf and His Tools"]),
        ("Tremors of the Earth", ["+Agmond's Fate", "+Mirages", "Fiery Blaze Enchantments"]),
        ("Theldurin the Lost", ["+Solution to Doom", "The Lost Fragments"]),
        (None, ["Uldaman Reagent Run", "Reclaimed Treasures", "+The Hidden Chamber", "The Platinum Discs"]),   # Uldaman's own quests, not the zone's
        ("Kargath", [HUB(3, 46)]),
    ]),
    51: ("Searing Gorge", [
        ("The Torch of Retribution", ["+Divine Retribution"]),
        ("Dorius Stonetender", ["+Caught!", "Suntara Stones", "+Release Them"]),
        ("Thorium Point", [HUB(39, 27), "Prayer to Elune"]),
    ]),
    46: ("Burning Steppes", [
        ("The True Masters", ["+Dragonkin Menace"]),
        ("Morgan's Vigil", ["+Extinguish the Firegut", "FIFTY! YEP!"]),
        ("Flame Crest", ["+Broodling Essence", "Tablet of the Seven", "Leonid Barthalomew", "A Taste of Flame"]),
    ]),
    8: ("Swamp of Sorrows", [
        ("The Harborage", ["+The Lost Caravan", "Draenethyst Crystals"]),
        ("Threat From the Sea", ["+Lack of Surplus"]),
        (None, ["+The Essence of Eranikus", "+Pool of Tears"]),   # the temple's own quests, not the zone's
        ("Stonard", [HUB(47, 56)]),
    ]),
    4: ("Blasted Lands", [
        ("Nethergarde Keep", [HUB(51, 14)]),
        ("Heroes of Old", ["Petty Squabbles", "A Tale of Sorrow", "The Stones That Bind Us", "Heroes of Old"]),
        ("The Demon Hunter", ["Kirith", "The Cover of Darkness", "The Demon Hunter", "+Uniting the Shattered Amulet", "+The Disgraced One"]),
        ("Kum'isha the Collector", ["To Serve Kum'isha", "Everything Counts In Large Amounts"]),
    ]),
    28: ("Western Plaguelands", [
        ("Into the Plaguelands", ["Clear the Way", "A Call to Arms: The Plaguelands!", "Scarlet Diversions", "A Plague Upon Thee"]),
        ("The Scourge Cauldrons", ["The Scourge Cauldrons", "Target: Felstone Field", "Return to Chillwind Camp", "Return to the Bulwark", "Target: Dalson's Tears",
                                   "Target: Writhing Haunt", "Target: Gahrron's Withering", "Return to Chillwind Point", "Mission Accomplished!"]),
        ("Alas, Andorhal", ["All Along the Watchtowers", "Skeletal Fragments", "Mold Rhymes With...", "Alas, Andorhal"]),
        ("The Plagued Farms", ["Better Late Than Never", "+Good Luck Charm", "+Mrs. Dalson's Diary", "The Wildlife Suffers Too", "Glyphed Oaken Branch"]),
        ("Chromie", ["+A Matter of Time", "The Annals of Darrowshire"]),
        ("Hearthglen", ["Unfinished Business", "+Find Myranda"]),
    ]),
    139: ("Eastern Plaguelands", [
        ("Darrowshire", ["+Heroes of Darrowshire", "+Little Pamela"]),
        ("Redemption", ["+Demon Dogs"]),
        ("Nathanos Blightcaller", ["+To Kill With Purpose"]),
        ("Northpass Tower", ["+Fragments of the Past", "The Eastern Plagues", "Order Must Be Restored"]),
        (None, ["The Dread Citadel - Naxxramas", "Cryptstalker Armor Doesn't Make Itself...", "Bonescythe Digs", "Binding the Dreadnaught",
                "The Elemental Equation", 'They Call Me "The Rooster"']),   # Naxxramas's own quests
        ("Light's Hope Chapel", [HUB(81, 59)]),
    ]),
    # ---------------------------------------------------------------- Kalimdor
    141: ("Teldrassil", [
        ("Shadowglen", [HUB(59, 42)]),
        ("Lake Al'Ameth", ["+Timberling Seeds", "+The Moss-twined Heart", "Timberling Sprouts"]),
        ("The Oracle Glade", ["+The Enchanted Glade", "Mist"]),
        ("Dolanaar", [HUB(57, 59), "+The Sleeping Druid"]),
    ]),
    148: ("Darkshore", [
        ("Washed Ashore", ["+Washed Ashore"]),
        ("The Tower of Althalaxx", ["The Tower of Althalaxx"]),
        ("The Blackwood Corrupted", ["+How Big a Threat?"]),
        ("Ruins of Mathystra", ["The Absent Minded Prospector", "+The Master's Glaive", "The Sleeper Has Awakened"]),
        ("The Highborne Ruins", ["Bashal'Aran", "Tools of the Highborne", "The Fall of Ameth'Aran", "For Love Eternal", "+The Red Crystal"]),
        (None, ["The Family and the Fishing Pole"]),   # its grouper only comes out of the sea with a fishing pole
        ("Auberdine", [HUB(37, 44)]),
    ]),
    14: ("Durotar", [
        ("Valley of Trials", ["+Your Place In The World", "Sarkoth", "+Burning Blade Medallion", "+Lazy Peons", "A Peon's Burden"]),
        ("The Burning Blade", ["+Report to Orgnil"]),
        ("Sen'jin Village", ["Minshina's Skull", "Zalazane", "Practical Prey", "A Solvent Spirit", "Thwarting Kolkar Aggression"]),
        ("Tiragarde Keep", ["+Vanquish the Betrayers", "The Admiral's Orders", "Encroachment"]),
        ("Razor Hill", [HUB(52, 43)]),
    ]),
    215: ("Mulgore", [
        ("Rites of the Earthmother", ["+A Humble Task"]),
        ("Camp Narache", ["+The Hunt Begins", "A Task Unfinished", "Break Sharptusk!"]),
        ("Cleansing the Wells", ["+Poison Water"]),
        ("The Venture Co.", ["+The Ravaged Caravan"]),
        ("Bloodhoof Village", [HUB(48, 60), "Journey to the Crossroads"]),
    ]),
    17: ("The Barrens", [
        ("Beasts of the Barrens", ["+Sergra Darkthorn"]),
        ("The Barrens Oases", ["+The Barrens Oases"]),
        ("Raiders of the Barrens", ["+Kolkar Leaders", "Centaur Bracers", "+Harpy Raiders"]),
        ("Samophlange", ["+Samophlange"]),
        ("Camp Taurajo", ["+Tribes at War", "+Weapons of Choice"]),
        ("Bael Modan", ["+Gann's Reclamation", "A Vengeful Fate"]),
        ("Mor'shan Rampart", ["+Ignition", "+The Runed Scroll", "+Report to Kadrak"]),
        ("Ratchet", [HUB(63, 38)]),
        ("The Crossroads", [HUB(51, 31)]),
    ]),
    331: ("Ashenvale", [
        ("Raene's Cleansing", ["+Raene's Cleansing", "Culling the Threat"]),
        ("The Scythe of Elune", ["+The Howling Vale"]),
        ("Maestra's Post", ["+Bathran's Hair", "Supplies to Auberdine", "+Vile Satyr! Dryads in Danger!"]),
        ("The Ashenvale Hunt", ["+The Ashenvale Hunt"]),
        ("Zoram'gar Outpost", ["+Between a Rock and a Thistlefur", "Naga at the Zoram Strand", "Troll Charm", "Vorsha the Lasher", "Freedom to Ruul"]),
        ("Splintertree Post", [HUB(72, 65), "Torek's Assault"]),
        ("Astranaar", [HUB(36, 50), "+The Ancient Statuette", "+Forsaken Diseases", "+Elemental Bracers"]),
    ]),
    406: ("Stonetalon Mountains", [
        ("Gaxim's Experiments", ["A Gnome's Respite", "An Old Colleague", "Ineptitude + Chemicals = Fun", "A Scroll from Mauren", "Devils in Westfall",
                                 "Special Delivery for Gaxim", "Retrieval for Mauren"]),
        ("Stonetalon Peak", ["Enraged Spirits", "Reception from Tyrande", "Wounded Ancients", "Reclaiming the Charred Vale"]),
        ("Windshear Crag", ["Covert Ops - Alpha", "Covert Ops - Beta", "Kaela's Update", "Update for Sentinel Thenysil", "+Super Reaper 6000", "Gerenzo's Orders"]),
        ("The Grimtotem", ["+Kaya's Alive", "+Avenge My Village"]),
        ("Malaka'jin", ["Jin'Zil's Forest Magic", "Blood Feeders", "Report to Kadrak", "+The Spirits of Stonetalon"]),
        ("Sun Rock Retreat", [HUB(47, 61)]),
    ]),
    405: ("Desolace", [
        ("Reclaimers Inc.", ["The Karnitol Shipwreck", "Reagents for Reclaimers Inc."]),
        ("Nijel's Point", ["+Vahlarriel's Search", "+Down the Scarlet Path", "Centaur Bounty"]),
        ("The Corrupter", ["The Corrupter"]),
        ("The Centaur Clans", ["+Assault on the Kolkar", "+Raid on the Kolkar", "+Regthar Deathgate"]),
        ("Kodo Graveyard", ["Bodyguard for Hire", "Gizelton Caravan", "Bone Collector", "Ghost-o-plasm Round Up", "Kodo Roundup"]),
        ("Ethel Rethor", ["+Sceptre of Light", "Claim Rackmore's Treasure!"]),
        ("Shadowprey Village", [HUB(25, 71), HUB(55, 57)]),
    ]),
    400: ("Thousand Needles", [
        ("Goblin Sponsorship", ["+Load Lightening"]),
        ("The Brassbolts Brothers", ["+Salt Flat Venom", "The Brassbolts Brothers"]),
        ("Kravel Koalbeard", ["+Rumors for Kravel", "+Wharfmaster Dizzywig", "Rocket Car Parts", "A Bump in the Road", "Hemet Nesingwary"]),
        ("Tests of the Plainstalker", ["+Test of Faith", "Test of Lore", "Final Passage"]),
        ("Arikara", ["+Alien Egg"]),
        ("Freewind Post", [HUB(45, 50), HUB(35, 24)]),
    ]),
    15: ("Dustwallow Marsh", [
        ("The Black Shield", ["The Black Shield", "They Call Him Smiling Jim", "Suspicious Hoofprints", "Daelin's Men", "The Deserters", "Lieutenant Paval Reethe", "Questioning Reethe"]),
        ("The Lost Report", ["+The Lost Report"]),
        ("The Brood of Onyxia", ["+Identifying the Brood", "Overlord Mok'Morokk's Concern", "Army of the Black Dragon"]),
        ("Swamp Eye Jarl", ["+Jarl Needs a Blade"]),
        ("Theramore Isle", ["+The Orc Report", "+Stinky's Escape"]),
        ("Brackenwall Village", [HUB(37, 32)]),
    ]),
    357: ("Feralas", [
        ("The Muisek Vessel", ["+A Strange Request"]),
        ("War on the Woodpaw", ["+War on the Woodpaw"]),
        ("The Gordunni", ["+The Gordunni Scroll", "The Ogres of Feralas", "Gordunni Cobalt", "+A New Cloak's Sheen"]),
        ("The Missing Courier", ["+The Missing Courier"]),
        ("The Stave of Equinex", ["+In Search of Knowledge"]),
        ("Against the Hatecrest", ["+The Ruins of Solarsal"]),
        ("The Sprite Darters", ["+Freedom for All Creatures"]),
        ("Camp Mojache", [HUB(75, 43)]),
        ("Feathermoon Stronghold", [HUB(31, 45)]),
    ]),
    440: ("Tanaris", [
        ("The Noxious Lair", ["+Gadgetzan Water Survey", "+Bungle in the Jungle"]),
        ("Noggenfogger Elixir", ["+The Thirsty Goblin"]),
        ("Bandits & Pirates", ["Wastewander Justice", "More Wastewander Justice", "Water Pouch Bounty", "WANTED: Caliph Scorpidsting", "WANTED: Andre Firebeard",
                               "Southsea Shakedown", "Pirate Hats Ahoy!"]),
        (None, ["Troll Temper", "Divino-matic Rod", "Gahz'rilla", "Nekrum's Medallion", "The Spider God", "+Tiara of the Deep", "+Tran'rek"]),   # Zul'Farrak's own quests
        (None, ["+Translating the Ledger"]),   # Narain's chase around the world starts at Steamwheedle Port
        ("Steamwheedle Port", [HUB(66, 21)]),
        ("Gadgetzan", [HUB(52, 28)]),
    ]),
    490: ("Un'Goro Crater", [
        ("Crystals of Power", ["+Crystals of Power"]),
        ("Muigin and Larion", ["+Larion and Muigin", "+Muigin and Larion"]),
        ("Linken's Adventure", ["+It's a Secret to Everybody"]),
        ("Torwa Pathfinder", ["+The Fare of Lar'korwi", "+The Apes of Un'Goro"]),
        ("Fire Plume Ridge", ["+Finding the Source", "+A Little Help From My Friends", "Volcanic Activity"]),
        ("Marshal's Refuge", [HUB(44, 7)]),
    ]),
    361: ("Felwood", [
        ("Forces of Jaedenar", ["+Forces of Jaedenar", "Verifying the Corruption"]),
        ("The Jadefire Satyrs", ["+Flute of Xavaric", "+The Corruption of the Jadefire"]),
        ("Rescue From Jaedenar", ["+A Strange Red Key"]),
        ("Bloodvenom Post", ["Wild Guardians", "+Well of Corruption", "A Husband's Last Battle"]),
        ("Timbermaw Hold", ["Timbermaw Ally", "Speak to Nafien", "Deadwood of the North"]),
    ]),
    16: ("Azshara", [
        ("Stealing Knowledge", ["+Stealing Knowledge"]),
        ("Loramus Thalipedes", ["+Loramus"]),
    ]),
    618: ("Winterspring", [
        ("The Winterfall", ["+Winterfall Firewater", "+Threat of the Winterfall", "Strange Sources"]),
        ("Starfall Village", ["Enraged Wildkin", "+The Ruins of Kel'Theril", "+Remorseful Highborne", "+Wildkin of Elune"]),
        ("Beasts of Winterspring", ["+Ursius of the Shardtooth"]),
        ("Everlook", [HUB(61, 39)]),
    ]),
    1377: ("Silithus", [
        ("Dearest Natalia", ["+Dearest Natalia"]),
        ("Twilight Cultists", ["+The Twilight Mystery", "+Twilight Geolords", "Secret Communication", "Abyssal Contacts"]),
        ("The Abyssal Council", ["+Aurel Goldleaf", "+Lords of the Council", "A Humble Offering"]),
        (None, ["+The Path of the Righteous", "What Tomorrow Brings", "Treasure of the Timeless One"]),   # the Scepter / AQ gate questline, not the zone's
        ("Southwind Village", ["+The Spirits of Southwind"]),
        ("Cenarion Hold", [HUB(50, 37), "Scouring the Desert"]),
    ]),
}
