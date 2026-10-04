-- MUI_StorylineDB.lua  (AUTO-GENERATED — do not edit)
-- Zone story chapters, hand-curated in tools/storylines/chapters.py.
-- Regenerate via: python tools/storylines/export.py
object "StorylineDB" {

    -- Chapters of a zone (QuestDB area id), in story order:
    --   { name, steps = { {questId, ...}, ... } }
    -- A step lists the ids of same-named quests (a multi-part chain or
    -- exclusive variants); `any = true` means one of them is enough.
    GetChapters = function(self, areaId)
        return self._data[areaId]
    end;

    _data = {
        [12] = {  -- Elwynn Forest
            { name = "Northshire Valley", steps = {
                { 783 },  -- A Threat Within
                { 7 },  -- Kobold Camp Cleanup
                { 5261 },  -- Eagan Peltskinner
                { 33 },  -- Wolves Across the Border
                { 15 },  -- Investigate Echo Ridge
                { 18 },  -- Brotherhood of Thieves
                { 3903 },  -- Milly Osworth
                { 3904 },  -- Milly's Harvest
                { 3905 },  -- Grape Manifest
                { 6 },  -- Bounty on Garrick Padfoot
                { 21 },  -- Skirmish at Echo Ridge
                { 54 },  -- Report to Goldshire
            } },
            { name = "Stonefields & Maclures", steps = {
                { 85 },  -- Lost Necklace
                { 86 },  -- Pie for Billy
                { 84 },  -- Back to Billy
                { 106 },  -- Young Lovers
                { 111 },  -- Speak with Gramma
                { 107 },  -- Note to William
                { 112 },  -- Collecting Kelp
                { 114 },  -- The Escape
                { 87 },  -- Goldtooth
                { 88 },  -- Princess Must Die!
            } },
            { name = "Goldshire", steps = {
                { 47 },  -- Gold Dust Exchange
                { 60 },  -- Kobold Candles
                { 62 },  -- The Fargodeep Mine
                { 76 },  -- The Jasperlode Mine
                { 123 },  -- The Collector
                { 147 },  -- Manhunt
            } },
            { name = "Eastvale Logging Camp", steps = {
                { 83 },  -- Red Linen Goods
                { 5545 },  -- A Bundle of Trouble
                { 40 },  -- A Fishy Peril
                { 35 },  -- Further Concerns
                { 37 },  -- Find the Lost Guards
                { 45 },  -- Discover Rolf's Fate
                { 52 },  -- Protect the Frontier
                { 71 },  -- Report to Thomas
                { 39 },  -- Deliver Thomas' Report
                { 46 },  -- Bounty on Murlocs
                { 59 },  -- Cloth and Leather Armor
            } },
            { name = "The Riverpaw Gnolls", steps = {
                { 239 },  -- Westbrook Garrison Needs Help!
                { 11 },  -- Riverpaw Gnoll Bounty
                { 176 },  -- Wanted:  "Hogger"
            } },
        },
        [40] = {  -- Westfall
            { name = "The Westfall Farms", steps = {
                { 36, 38 },  -- Westfall Stew
                { 22 },  -- Goretusk Liver Pie
                { 64 },  -- The Forgotten Heirloom
                { 151 },  -- Poor Old Blanchy
                { 9 },  -- The Killing Fields
            } },
            { name = "The People's Militia", steps = {
                { 12, 13, 14 },  -- The People's Militia
                { 102 },  -- Patrolling Westfall
                { 153 },  -- Red Leather Bandanas
            } },
            { name = "The Westfall Coast", steps = {
                { 103 },  -- Keeper of the Flame
                { 136, 138, 139, 140 },  -- Captain Sander's Hidden Treasure
                { 152 },  -- The Coast Isn't Clear
                { 104 },  -- The Coastal Menace
            } },
            { name = "The Defias Brotherhood", steps = {
                { 65, 132, 135, 141, 142, 155, 166 },  -- The Defias Brotherhood
            } },
        },
        [44] = {  -- Redridge Mountains
            { name = "Solomon's Plea", steps = {
                { 120, 121 },  -- Messenger to Stormwind
                { 143, 144 },  -- Messenger to Westfall
                { 145, 146 },  -- Messenger to Darkshire
            } },
            { name = "Lakeshire", steps = {
                { 129 },  -- A Free Lunch
                { 130 },  -- Visit the Herbalist
                { 131 },  -- Delivering Daffodils
                { 3741 },  -- Hilary's Necklace
                { 125 },  -- The Lost Tools
                { 92 },  -- Redridge Goulash
                { 89 },  -- The Everstill Bridge
                { 150 },  -- Murloc Poachers
                { 127 },  -- Selling Fish
                { 34 },  -- An Unwelcome Guest
            } },
            { name = "The Redridge Gnolls", steps = {
                { 244 },  -- Encroaching Gnolls
                { 246 },  -- Assessing the Threat
                { 118 },  -- The Price of Shoes
                { 119 },  -- Return to Verner
                { 122 },  -- Underbelly Scales
                { 124 },  -- A Baying of Gnolls
                { 91 },  -- Solomon's Law
                { 126 },  -- Howling in the Hills
            } },
            { name = "The Blackrock Menace", steps = {
                { 20 },  -- Blackrock Menace
                { 115 },  -- Shadow Magic
                { 19 },  -- Tharil'zun
                { 128 },  -- Blackrock Bounty
                { 219 },  -- Missing In Action
                { 169 },  -- Wanted: Gath'Ilzogg
                { 180 },  -- Wanted: Lieutenant Fangore
            } },
            { name = "The Tower of Ilgalar", steps = {
                { 94 },  -- A Watchful Eye
                { 248 },  -- Looking Further
                { 249 },  -- Morganth
            } },
        },
        [10] = {  -- Duskwood
            { name = "Raven Hill", steps = {
                { 163 },  -- Raven Hill
                { 5 },  -- Jitters' Growling Gut
                { 93 },  -- Dusky Crab Cakes
                { 240 },  -- Return to Jitters
            } },
            { name = "Sven's Revenge", steps = {
                { 164 },  -- Deliveries to Sven
                { 95 },  -- Sven's Revenge
                { 230 },  -- Sven's Camp
                { 262 },  -- The Shadowy Figure
                { 265 },  -- The Shadowy Search Continues
                { 266 },  -- Inquire at the Inn
                { 453 },  -- Finding the Shadowy Figure
                { 268 },  -- Return to Sven
                { 323 },  -- Proving Your Worth
                { 269 },  -- Seeking Wisdom
                { 270 },  -- The Doomed Fleet
                { 321 },  -- Lightforge Iron
                { 324 },  -- The Lost Ingots
                { 526 },  -- Lightforge Ingots
                { 322 },  -- Blessed Arm
                { 325 },  -- Armed and Ready
                { 55 },  -- Morbent Fel
            } },
            { name = "The Embalmer", steps = {
                { 165 },  -- The Hermit
                { 148 },  -- Supplies from Darkshire
                { 149 },  -- Ghost Hair Thread
                { 154 },  -- Return the Comb
                { 157 },  -- Deliver the Thread
                { 158 },  -- Zombie Juice
                { 156 },  -- Gather Rot Blossoms
                { 159 },  -- Juice Delivery
                { 133 },  -- Ghoulish Effigy
                { 134 },  -- Ogre Thieves
                { 160 },  -- Note to the Mayor
                { 251 },  -- Translate Abercrombie's Note
                { 401 },  -- Wait for Sirra to Finish
                { 252 },  -- Translation to Ello
                { 253 },  -- Bride of the Embalmer
            } },
            { name = "Darkshire", steps = {
                { 56, 57, 58 },  -- The Night Watch
                { 101 },  -- The Totem of Infliction
                { 174, 175, 177, 181 },  -- Look To The Stars
                { 173, 221, 222, 223 },  -- Worgen in the Woods
            } },
            { name = "The Legend of Stalvan", steps = {
                { 66, 67, 68, 69, 70, 72, 74, 75, 78, 79, 80, 97, 98 },  -- The Legend of Stalvan
            } },
            { name = "Mor'Ladim", steps = {
                { 225 },  -- The Weathered Grave
                { 227 },  -- Morgan Ladimore
                { 228 },  -- Mor'Ladim
                { 229 },  -- The Daughter Who Lived
                { 231 },  -- A Daughter's Love
            } },
            { name = "Nothing But The Truth", steps = {
                { 1372, 1383, 1388, 1391 },  -- Nothing But The Truth
            } },
        },
        [1] = {  -- Dun Morogh
            { name = "Coldridge Valley", steps = {
                { 179 },  -- Dwarven Outfitters
                { 170 },  -- A New Threat
                { 183 },  -- The Boar Hunter
                { 233, 234 },  -- Coldridge Valley Mail Delivery
                { 3361 },  -- A Refugee's Quandary
                { 182 },  -- The Troll Cave
                { 218 },  -- The Stolen Journal
                { 282, 420 },  -- Senir's Observations
                { 2160 },  -- Supplies to Tannok
                { 3364 },  -- Scalding Mornbrew Delivery
                { 3365 },  -- Bring Back the Mug
                { 287 },  -- Frostmane Hold
                { 291 },  -- The Reports
            } },
            { name = "Kharanos", steps = {
                { 400 },  -- Tools for Steelgrill
                { 5541 },  -- Ammo for Rumbleshot
                { 313 },  -- The Grizzled Den
                { 412 },  -- Operation Recombobulation
            } },
            { name = "Brewnall Village", steps = {
                { 310 },  -- Bitter Rivals
                { 317 },  -- Stocking Jetsteam
                { 311 },  -- Return to Marleth
                { 318 },  -- Evershine
                { 319 },  -- A Favor for Evershine
                { 320 },  -- Return to Bellowfiz
                { 315 },  -- The Perfect Stout
                { 415 },  -- Rejold's New Brew
                { 413 },  -- Shimmer Stout
                { 414 },  -- Stout to Kadrell
                { 312 },  -- Tundra MacGrann's Stolen Stash
            } },
        },
        [38] = {  -- Loch Modan
            { name = "Thelsamar", steps = {
                { 416 },  -- Rat Catching
                { 418 },  -- Thelsamar Blood Sausages
                { 307 },  -- Filthy Paws
                { 255 },  -- Mercenaries
                { 256 },  -- WANTED: Chok'sul
            } },
            { name = "The Valley of Kings", steps = {
                { 224, 237, 263, 217 },  -- In Defense of the King's Lands
                { 267 },  -- The Trogg Threat
            } },
            { name = "Ironband's Excavation", steps = {
                { 298 },  -- Excavation Progress Report
                { 301 },  -- Report to Ironforge
                { 302 },  -- Powder to Ironband
                { 273 },  -- Resupplying the Excavation
                { 454 },  -- After the Ambush
                { 309 },  -- Protecting the Shipment
                { 436 },  -- Ironband's Excavation
                { 297 },  -- Gathering Idols
            } },
            { name = "Farstrider Lodge", steps = {
                { 385 },  -- Crocolisk Hunting
                { 257 },  -- A Hunter's Boast
                { 258 },  -- A Hunter's Challenge
                { 271, 531 },  -- Vyrin's Revenge
            } },
            { name = "The Stonewrought Dam", steps = {
                { 250, 199, 161, 274, 278, 280, 283 },  -- A Dark Threat Looms
            } },
        },
        [11] = {  -- Wetlands
            { name = "The Dragonmaw Orcs", steps = {
                { 468 },  -- Report to Mountaineer Rockgar
                { 455 },  -- The Algaz Gauntlet
                { 473 },  -- Report to Captain Stoutfist
                { 464 },  -- War Banners
                { 465 },  -- Nek'rosh's Gambit
                { 474 },  -- Defeat Nek'rosh
            } },
            { name = "The Greenwarden", steps = {
                { 463 },  -- The Greenwarden
                { 276 },  -- Tramping Paws
                { 469 },  -- Daily Delivery
                { 277 },  -- Fire Taboo
                { 275 },  -- Blisters on The Land
            } },
            { name = "Menethil Harbor", steps = {
                { 279 },  -- Claws from the Deep
                { 484 },  -- Young Crocolisk Skins
                { 470 },  -- Digging Through the Ooze
                { 281 },  -- Reclaiming Goods
                { 284 },  -- The Search Continues
                { 285 },  -- Search More Hovels
                { 286 },  -- Return the Statuette
                { 471 },  -- Apprentice's Duties
            } },
            { name = "Whelgar's Excavation", steps = {
                { 294, 295, 296 },  -- Ormer's Revenge
                { 305, 306 },  -- In Search of The Excavation Team
                { 299 },  -- Uncovering the Past
            } },
            { name = "The Cursed Crew", steps = {
                { 288 },  -- The Third Fleet
                { 289 },  -- The Cursed Crew
                { 290 },  -- Lifting the Curse
                { 292 },  -- The Eye of Paleth
                { 293 },  -- Cleansing the Eye
            } },
            { name = "The Thandol Span", steps = {
                { 303 },  -- The Dark Iron War
                { 631, 632, 633 },  -- The Thandol Span
                { 634 },  -- Plea To The Alliance
                { 304 },  -- A Grim Task
            } },
        },
        [85] = {  -- Tirisfal Glades
            { name = "Deathknell", steps = {
                { 363 },  -- Rude Awakening
                { 364 },  -- The Mindless Ones
                { 376 },  -- The Damned
                { 3901 },  -- Rattling the Rattlecages
                { 3902 },  -- Scavenging Deathknell
                { 380 },  -- Night Web's Hollow
                { 381 },  -- The Scarlet Crusade
                { 382 },  -- The Red Messenger
                { 383 },  -- Vital Intelligence
                { 6395 },  -- Marla's Last Wish
            } },
            { name = "A New Plague", steps = {
                { 5481 },  -- Gordo's Task
                { 367, 368, 369, 492 },  -- A New Plague
                { 5482 },  -- Doom Weed
                { 365, 407 },  -- Fields of Grief
                { 445 },  -- Delivery to Silverpine Forest
            } },
            { name = "Brill", steps = {
                { 8, 590 },  -- A Rogue's Deal
                { 375 },  -- The Chill of Death
                { 398 },  -- Wanted: Maggot Eye
            } },
            { name = "Agamand Mills", steps = {
                { 404 },  -- A Putrid Task
                { 426 },  -- The Mills Overrun
                { 362 },  -- The Haunted Mills
                { 354 },  -- Deaths in the Family
                { 355 },  -- Speak with Sevren
                { 408 },  -- The Family Crypt
            } },
            { name = "The Scarlet Crusade", steps = {
                { 427, 370, 371, 372 },  -- At War With The Scarlet Crusade
                { 374 },  -- Proof of Demise
            } },
            { name = "The Prodigal Lich", steps = {
                { 358 },  -- Graverobbers
                { 366 },  -- Return the Book
                { 405 },  -- The Prodigal Lich
                { 359 },  -- Forsaken Duties
                { 360 },  -- Return to the Magistrate
                { 409 },  -- Proving Allegiance
                { 411 },  -- The Prodigal Lich Returns
            } },
        },
        [130] = {  -- Silverpine Forest
            { name = "Arugal's Folly", steps = {
                { 421 },  -- Prove Your Worth
                { 422, 423, 424, 99 },  -- Arugal's Folly
                { 452 },  -- Pyrewood Ambush
                { 516 },  -- Beren's Peril
            } },
            { name = "The Deathstalkers", steps = {
                { 435 },  -- Escorting Erland
                { 449 },  -- The Deathstalkers' Report
                { 428 },  -- Lost Deathstalkers
                { 429 },  -- Wild Hearts
                { 430 },  -- Return to Quinn
                { 425 },  -- Ivar the Foul
                { 3221 },  -- Speak with Renferrel
            } },
            { name = "The Sepulcher", steps = {
                { 447, 450, 451 },  -- A Recipe For Death
            } },
            { name = "The Rot Hide Gnolls", steps = {
                { 437 },  -- The Dead Fields
                { 438 },  -- The Decrepit Ferry
                { 439 },  -- Rot Hide Clues
                { 440 },  -- The Engraved Ring
                { 441 },  -- Raleigh and the Undercity
                { 443 },  -- Rot Hide Ichor
                { 444 },  -- Rot Hide Origins
                { 446 },  -- Thule Ravenclaw
                { 448 },  -- Report to Hadrec
                { 530 },  -- A Husband's Revenge
                { 442 },  -- Assault on Fenris Isle
            } },
            { name = "Ambermill", steps = {
                { 477 },  -- Border Crossings
                { 478 },  -- Maps and Runes
                { 481 },  -- Dalar's Analysis
                { 482 },  -- Dalaran's Intentions
                { 479 },  -- Ambermill Investigations
                { 480 },  -- The Weaver
            } },
            { name = "Deep Elem Mine", steps = {
                { 460 },  -- Resting in Pieces
                { 461 },  -- The Hidden Niche
                { 491 },  -- Wand to Bethor
            } },
        },
        [267] = {  -- Hillsbrad Foothills
            { name = "Lydon's Elixirs", steps = {
                { 496, 499 },  -- Elixir of Suffering
                { 501, 502 },  -- Elixir of Pain
                { 509, 513, 515, 517, 524 },  -- Elixir of Agony
            } },
            { name = "Blackmoore's Legacy", steps = {
                { 498 },  -- The Rescue
                { 533 },  -- Infiltration
                { 503 },  -- Gol'dir
                { 506 },  -- Blackmoore's Legacy
                { 507 },  -- Lord Aliden Perenolde
                { 508 },  -- Taretha's Gift
            } },
            { name = "Tarren Mill", steps = {
                { 549 },  -- WANTED: Syndicate Personnel
                { 567 },  -- Dangerous!
                { 547 },  -- Humbert's Sword
                { 566 },  -- WANTED: Baron Vardus
            } },
            { name = "Battle of Hillsbrad", steps = {
                { 527, 528, 529, 532, 539, 541, 550 },  -- Battle of Hillsbrad
                { 546 },  -- Souvenirs of Death
            } },
            { name = "Down the Coast", steps = {
                { 536 },  -- Down the Coast
                { 559, 560, 561 },  -- Farren's Proof
                { 562 },  -- Stormwind Ho!
                { 563 },  -- Reassignment
            } },
            { name = "Southshore", steps = {
                { 555 },  -- Soothing Turtle Bisque
                { 564 },  -- Costly Menace
                { 565 },  -- Bartolo's Yeti Fur Cloak
            } },
            { name = "The Crown of Will", steps = {
                { 552, 553 },  -- Helcular's Revenge
                { 518, 519, 520, 521 },  -- The Crown of Will
            } },
            { name = "Hints of a New Plague?", steps = {
                { 659, 658, 657, 660, 661 },  -- Hints of a New Plague?
            } },
        },
        [36] = {  -- Alterac Mountains
            { name = "The Syndicate", steps = {
                { 505 },  -- Syndicate Assassins
                { 510 },  -- Foreboding Plans
                { 512 },  -- Noble Deaths
                { 522 },  -- Assassin's Contract
                { 523 },  -- Baron's Demise
                { 551 },  -- The Ensorcelled Parchment
                { 554 },  -- Stormpike's Deciphering
            } },
            { name = "Dark Council", steps = {
                { 511 },  -- Encrypted Letter
                { 514 },  -- Letter to Stormpike
                { 525 },  -- Further Mysteries
                { 537 },  -- Dark Council
            } },
            { name = "Crushridge Ogres", steps = {
                { 500 },  -- Crushridge Bounty
                { 504 },  -- Crushridge Warmongers
            } },
        },
        [45] = {  -- Arathi Highlands
            { name = "Refuge Pointe", steps = {
                { 681 },  -- Northfold Manor
                { 682 },  -- Stromgarde Badges
                { 684 },  -- Wanted!  Marez Cowl
                { 685 },  -- Wanted!  Otto and Falconcrest
            } },
            { name = "Hammerfall", steps = {
                { 677, 678, 679 },  -- Call to Arms
                { 671, 673 },  -- Foul Magics
                { 655 },  -- Hammerfall
                { 672, 674, 675 },  -- Raising Spirits
                { 701, 702, 847 },  -- Guile of the Raptor
                { 680 },  -- The Real Threat
            } },
            { name = "Faldir's Cove", steps = {
                { 663 },  -- Land Ho!
                { 662 },  -- Deep Sea Salvage
                { 664 },  -- Drowned Sorrows
                { 665, 666, 668, 669, 670 },  -- Sunken Treasure
                { 667 },  -- Death From Below
            } },
            { name = "Trelane's Tower", steps = {
                { 691 },  -- Worth Its Weight in Gold
                { 693 },  -- Wand over Fist
                { 694 },  -- Trelane's Defenses
                { 695 },  -- An Apprentice's Enchantment
                { 696 },  -- Attack on the Tower
                { 697 },  -- Malin's Request
            } },
            { name = "Trol'kalar", steps = {
                { 639 },  -- Sigil of Strom
                { 640 },  -- The Broken Sigil
                { 641 },  -- Sigil of Thoradin
                { 643 },  -- Sigil of Arathor
                { 644 },  -- Sigil of Trollbane
                { 645, 646 },  -- Trol'kalar
            } },
            { name = "Princess Myzrael", steps = {
                { 642 },  -- The Princess Trapped
                { 651 },  -- Stones of Binding
                { 652 },  -- Breaking the Keystone
                { 653, 688 },  -- Myzrael's Allies
                { 687 },  -- Theldurin the Lost
                { 656 },  -- Summoning the Princess
            } },
        },
        [33] = {  -- Stranglethorn Vale
            { name = "Nesingwary's Expedition", steps = {
                { 583 },  -- Welcome to the Jungle
                { 185, 186, 187, 188 },  -- Tiger Mastery
                { 190, 191, 192, 193 },  -- Panther Mastery
                { 194, 195, 196, 197 },  -- Raptor Mastery
                { 338 },  -- The Green Hills of Stranglethorn
                { 339 },  -- Chapter I
                { 340 },  -- Chapter II
                { 341 },  -- Chapter III
                { 342 },  -- Chapter IV
                { 208 },  -- Big Game Hunter
            } },
            { name = "Booty Bay", steps = {
                { 575 },  -- Supply and Demand
                { 189 },  -- Bloodscalp Ears
                { 605 },  -- Singing Blue Shards
                { 213 },  -- Hostile Takeover
                { 577 },  -- Some Assembly Required
                { 628 },  -- Excelsior
                { 600 },  -- Venture Company Mining
                { 209 },  -- Skullsplitter Tusks
                { 617 },  -- Akiris by the Bundle
                { 621 },  -- Zanzil's Secret
                { 348 },  -- Stranglethorn Fever
                { 8552 },  -- The Monogrammed Sash
                { 8553 },  -- The Captain's Cutlass
                { 8554 },  -- Facing Negolash
            } },
            { name = "The Rebel Camp", steps = {
                { 198 },  -- Supplies to Private Thorsen
                { 201 },  -- Investigate the Camp
                { 215 },  -- Jungle Secrets
                { 200 },  -- Bookie Herod
                { 210 },  -- Krazek's Cookery
                { 328 },  -- The Hidden Key
                { 329 },  -- The Spy Revealed!
                { 330 },  -- Patrol Schedules
                { 331 },  -- Report to Doren
                { 627 },  -- Favor for Krazek
                { 622 },  -- Return to Corporal Kaleb
            } },
            { name = "Colonel Kurzen", steps = {
                { 203 },  -- The Second Rebellion
                { 204 },  -- Bad Medicine
                { 207 },  -- Kurzen's Mystery
                { 574 },  -- Special Forces
                { 202 },  -- Colonel Kurzen
                { 205 },  -- Troll Witchery
                { 206 },  -- Mai'Zoth
            } },
            { name = "Saving Yenniku", steps = {
                { 581 },  -- Hunt for Yenniku
                { 582 },  -- Headhunting
                { 584 },  -- Bloodscalp Clan Heads
                { 585 },  -- Speaking with Nezzliok
                { 586 },  -- Speaking with Gan'zulah
                { 588 },  -- The Fate of Yenniku
                { 589 },  -- The Singing Crystals
                { 591 },  -- The Mind's Eye
                { 592 },  -- Saving Yenniku
            } },
            { name = "Grom'gol Base Camp", steps = {
                { 568, 569 },  -- The Defense of Grom'gol
                { 596 },  -- Bloody Bone Necklaces
                { 629 },  -- The Vile Reef
                { 638 },  -- Trollbane
                { 570, 572, 571, 573 },  -- Mok'thardin's Enchantment
                { 598 },  -- Split Bone Necklace
            } },
            { name = "The Curse of the Tides", steps = {
                { 616 },  -- The Haunted Isle
                { 578 },  -- The Stone of the Tides
                { 601 },  -- Water Elementals
                { 602 },  -- Magical Analysis
                { 603 },  -- Ansirem's Key
                { 610 },  -- "Pretty Boy" Duncan
                { 611 },  -- The Curse of the Tides
            } },
            { name = "The Bloodsail Buccaneers", steps = {
                { 595, 597, 599, 604, 608 },  -- The Bloodsail Buccaneers
                { 587 },  -- Up to Snuff
                { 576 },  -- Keep An Eye Out
            } },
            { name = "The Old Sea Dogs", steps = {
                { 606 },  -- Scaring Shaky
                { 607 },  -- Return to MacKinley
                { 624, 625, 626 },  -- Cortello's Riddle
                { 609 },  -- Voodoo Dues
                { 613 },  -- Cracking Maury's Foot
                { 8551 },  -- The Captain's Chest
            } },
        },
        [47] = {  -- The Hinterlands
            { name = "Summoning Shadra", steps = {
                { 2932 },  -- Grim Message
                { 2933 },  -- Venom Bottles
                { 2934 },  -- Undamaged Venom Sac
                { 2935 },  -- Consult Master Gadrin
                { 2937 },  -- Summoning Shadra
                { 2938 },  -- Venom to the Undercity
            } },
            { name = "Aerie Peak", steps = {
                { 1450 },  -- Gryphon Master Talonaxe
                { 1451 },  -- Rhapsody Shindigger
                { 1452 },  -- Rhapsody's Kalimdor Kocktail
                { 1469 },  -- Rhapsody's Tale
                { 2880 },  -- Troll Necklace Bounty
                { 2877 },  -- Skulk Rock Clean-up
            } },
            { name = "Saving Sharpbeak", steps = {
                { 2988 },  -- Witherbark Cages
                { 2992 },  -- The Divination
                { 2993 },  -- Return to the Hinterlands
                { 2989 },  -- The Altar of Zul
                { 2990 },  -- Thadius Grimshade
                { 2994 },  -- Saving Sharpbeak
            } },
            { name = "Rin'ji's Secret", steps = {
                { 2742 },  -- Rin'ji is Trapped!
                { 2782 },  -- Rin'ji's Secret
                { 8273 },  -- Oran's Gratitude
                { 77 },  -- A Sticky Situation
            } },
            { name = "The Vilebranch", steps = {
                { 7828 },  -- Stalking the Stalkers
                { 7829 },  -- Hunt the Savages
                { 7830 },  -- Avenging the Fallen
                { 7849 },  -- Separation Anxiety
                { 7850 },  -- Dark Vessels
                { 7845 },  -- Kidnapped Elder Torntusk!
                { 7846 },  -- Recover the Key!
                { 7847 },  -- Return to Primal Torntusk
                { 7861 },  -- Wanted: Vile Priestess Hexx and Her Minions
            } },
            { name = "Revantusk Village", steps = {
                { 7816 },  -- Gammerita, Mon!
                { 7839 },  -- Vilebranch Hooligans
                { 7841 },  -- Message to the Wildhammer
                { 7842 },  -- Another Message to the Wildhammer
                { 7844 },  -- Cannibalistic Cousins
                { 7840 },  -- Lard Lost His Lunch
                { 7815 },  -- Snapjaws, Mon!
                { 7843 },  -- The Final Message to the Wildhammer
                { 7862 },  -- Job Opening: Guard Captain of Revantusk Village
            } },
        },
        [3] = {  -- Badlands
            { name = "Hammertoe's Digsite", steps = {
                { 719 },  -- A Dwarf and His Tools
                { 720, 721 },  -- A Sign of Hope
                { 722 },  -- Amulet of Secrets
                { 723, 724 },  -- Prospect of Faith
                { 725, 726 },  -- Passing Word of a Threat
                { 762 },  -- An Ambassador of Evil
                { 1139 },  -- The Lost Tablets of Will
            } },
            { name = "Study of the Elements", steps = {
                { 710, 711, 712 },  -- Study of the Elements: Rock
                { 713 },  -- Coolant Heads Prevail
                { 714 },  -- Gyro... What?
                { 715 },  -- Liquid Stone
                { 716 },  -- Stone Is Better than Cloth
                { 734, 777, 778 },  -- This Is Going to Be Hard
            } },
            { name = "Tremors of the Earth", steps = {
                { 718 },  -- Mirages
                { 738 },  -- Find Agmond
                { 733 },  -- Scrounging
                { 739 },  -- Murdaloc
                { 704 },  -- Agmond's Fate
                { 732, 717 },  -- Tremors of the Earth
                { 706 },  -- Fiery Blaze Enchantments
            } },
            { name = "Kargath", steps = {
                { 2258 },  -- Badlands Reagent Run
                { 1419 },  -- Coyote Thieves
                { 782, 793 },  -- Broken Alliances
                { 2203 },  -- Badlands Reagent Run II
            } },
            { name = "Theldurin the Lost", steps = {
                { 709 },  -- Solution to Doom
                { 727 },  -- To Ironforge for Yagyin's Digest
                { 728 },  -- To the Undercity for Yagyin's Digest
                { 692 },  -- The Lost Fragments
                { 735 },  -- The Star, the Hand and the Heart
                { 737 },  -- Forbidden Knowledge
            } },
            { name = "The Shattered Necklace", steps = {
                { 2198 },  -- The Shattered Necklace
                { 2199 },  -- Lore for a Price
                { 2283 },  -- Necklace Recovery
                { 2284 },  -- Necklace Recovery, Take 2
                { 2200 },  -- Back to Uldaman
                { 2318, 2338 },  -- Translating the Journal
                { 2201 },  -- Find the Gems
                { 2204, 2361 },  -- Restoring the Necklace
                { 2339 },  -- Find the Gems and Power Source
                { 2340 },  -- Deliver the Gems
                { 2341 },  -- Necklace Recovery, Take 3
            } },
        },
        [51] = {  -- Searing Gorge
            { name = "Dorius Stonetender", steps = {
                { 4449 },  -- Caught!
                { 4450 },  -- Ledger from Tanaris
                { 3367, 3368 },  -- Suntara Stones
                { 3372 },  -- Release Them
                { 3566 },  -- Rise, Obsidion!
            } },
            { name = "The Torch of Retribution", steps = {
                { 3441 },  -- Divine Retribution
                { 3442 },  -- The Flawless Flame
                { 3443 },  -- Forging the Shaft
                { 3452 },  -- The Flame's Casing
                { 3453, 3454 },  -- The Torch of Retribution
                { 3462 },  -- Squire Maltrake
                { 3463 },  -- Set Them Ablaze!
                { 3481 },  -- Trinkets...
            } },
            { name = "Thorium Point", steps = {
                { 7728 },  -- STOLEN: Smithing Tuyere and Lookout's Spyglass
                { 7729 },  -- JOB OPPORTUNITY: Culling the Competition
                { 7723 },  -- Curse These Fat Fingers
                { 7724 },  -- Fiery Menace!
                { 7727 },  -- Incendosaurs? Whateverosaur is More Like It
                { 3377, 3378 },  -- Prayer to Elune
                { 7701 },  -- WANTED: Overseer Maltorius
                { 7722 },  -- What the Flux?
            } },
        },
        [46] = {  -- Burning Steppes
            { name = "Flame Crest", steps = {
                { 4296 },  -- Tablet of the Seven
                { 4726 },  -- Broodling Essence
                { 4022, 4023, any = true },  -- A Taste of Flame
                { 4808 },  -- Felnok Steelspring
                { 5522 },  -- Leonid Barthalomew
            } },
            { name = "Morgan's Vigil", steps = {
                { 3823 },  -- Extinguish the Firegut
                { 3824 },  -- Gor'tesh the Brute Lord
                { 3825 },  -- Ogre Head On A Stick = Party
                { 4283 },  -- FIFTY! YEP!
            } },
            { name = "The True Masters", steps = {
                { 4182 },  -- Dragonkin Menace
                { 4183, 4184, 4185, 4186, 4223, 4224 },  -- The True Masters
            } },
        },
        [8] = {  -- Swamp of Sorrows
            { name = "The Harborage", steps = {
                { 1389 },  -- Draenethyst Crystals
                { 1396 },  -- Encroaching Wildlife
                { 1421 },  -- The Lost Caravan
                { 1398 },  -- Driftwood
                { 1425 },  -- Deliver the Shipment
            } },
            { name = "Threat From the Sea", steps = {
                { 698, 699 },  -- Lack of Surplus
                { 1422, 1426, 1427 },  -- Threat From the Sea
                { 1428 },  -- Continued Threat
            } },
            { name = "Stonard", steps = {
                { 1430 },  -- Fresh Meat
                { 2622 },  -- The Missing Orders
                { 2623 },  -- The Swamp Talker
            } },
        },
        [4] = {  -- Blasted Lands
            { name = "Nethergarde Keep", steps = {
                { 2581 },  -- Snickerfang Jowls
                { 2583 },  -- A Boar's Vitality
                { 2585 },  -- The Decisive Striker
                { 2601 },  -- The Basilisk's Bite
                { 2603 },  -- Vulture's Vigor
            } },
            { name = "The Demon Hunter", steps = {
                { 2784 },  -- Fall From Grace
                { 2621 },  -- The Disgraced One
                { 2721 },  -- Kirith
                { 2743 },  -- The Cover of Darkness
                { 2744 },  -- The Demon Hunter
                { 3627 },  -- Uniting the Shattered Amulet
                { 3628 },  -- You Are Rakh'likh, Demon
            } },
            { name = "Kum'isha the Collector", steps = {
                { 2521 },  -- To Serve Kum'isha
                { 3501 },  -- Everything Counts In Large Amounts
            } },
            { name = "Heroes of Old", steps = {
                { 2783 },  -- Petty Squabbles
                { 2801 },  -- A Tale of Sorrow
                { 2681 },  -- The Stones That Bind Us
                { 2702, 2701 },  -- Heroes of Old
            } },
        },
        [28] = {  -- Western Plaguelands
            { name = "Into the Plaguelands", steps = {
                { 5093, 5094, 5095, any = true },  -- A Call to Arms: The Plaguelands!
                { 5092 },  -- Clear the Way
                { 5096 },  -- Scarlet Diversions
                { 5903, 5904, 6389, 6390 },  -- A Plague Upon Thee
            } },
            { name = "The Plagued Farms", steps = {
                { 5021, 5022, 5023 },  -- Better Late Than Never
                { 5050 },  -- Good Luck Charm
                { 4984, 4985 },  -- The Wildlife Suffers Too
                { 5051 },  -- Two Halves Become One
                { 5058 },  -- Mrs. Dalson's Diary
                { 5060 },  -- Locked Away
                { 4986, 4987 },  -- Glyphed Oaken Branch
            } },
            { name = "The Scourge Cauldrons", steps = {
                { 5215, 5228 },  -- The Scourge Cauldrons
                { 5216, 5229 },  -- Target: Felstone Field
                { 5217, 5220, 5223 },  -- Return to Chillwind Camp
                { 5230, 5232, 5234, 5236 },  -- Return to the Bulwark
                { 5219, 5231 },  -- Target: Dalson's Tears
                { 5222, 5233 },  -- Target: Writhing Haunt
                { 5225, 5235 },  -- Target: Gahrron's Withering
                { 5226 },  -- Return to Chillwind Point
                { 5237, 5238 },  -- Mission Accomplished!
            } },
            { name = "Alas, Andorhal", steps = {
                { 5097, 5098 },  -- All Along the Watchtowers
                { 964, 5537 },  -- Skeletal Fragments
                { 5514, 5538 },  -- Mold Rhymes With...
                { 105, 211 },  -- Alas, Andorhal
            } },
            { name = "Chromie", steps = {
                { 4971 },  -- A Matter of Time
                { 4972 },  -- Counting Out Time
                { 5154 },  -- The Annals of Darrowshire
            } },
            { name = "Hearthglen", steps = {
                { 6004, 6023, 6025 },  -- Unfinished Business
                { 5861 },  -- Find Myranda
                { 5862 },  -- Scarlet Subterfuge
                { 5944 },  -- In Dreams
            } },
        },
        [139] = {  -- Eastern Plaguelands
            { name = "Darrowshire", steps = {
                { 5142, 5601, any = true },  -- Little Pamela / Sister Pamela
                { 5149 },  -- Pamela's Doll
                { 5152 },  -- Auntie Marlene
                { 5153 },  -- A Strange Historian
                { 5210 },  -- Brother Carlin
                { 5168 },  -- Heroes of Darrowshire
                { 5241 },  -- Uncle Carlin
                { 5211 },  -- Defenders of Darrowshire
                { 5181 },  -- Villains of Darrowshire
                { 5206 },  -- Marauders of Darrowshire
                { 5941 },  -- Return to Chromie
                { 5721 },  -- The Battle of Darrowshire
                { 5942 },  -- Hidden Treasures
            } },
            { name = "Light's Hope Chapel", steps = {
                { 6021 },  -- Zaeldarr the Outcast
                { 6026 },  -- That's Asking A Lot
                { 6041 },  -- When Smokey Sings, I Get Violent
                { 5264 },  -- Lord Maxwell Tyrosus
                { 5265 },  -- The Argent Hold
                { 9664 },  -- Establishing New Outposts
                { 9665 },  -- Bolstering Our Defenses
            } },
            { name = "Redemption", steps = {
                { 5542 },  -- Demon Dogs
                { 5543 },  -- Blood Tinged Skies
                { 5544 },  -- Carrion Grubbage
                { 5742 },  -- Redemption
                { 5781 },  -- Of Forgotten Memories
                { 5845 },  -- Of Lost Honor
                { 5846 },  -- Of Love and Family
            } },
            { name = "Northpass Tower", steps = {
                { 5246, 5247 },  -- Fragments of the Past
                { 5248 },  -- Tormented By the Past
                { 6185 },  -- The Eastern Plagues
                { 6187 },  -- Order Must Be Restored
            } },
            { name = "Nathanos Blightcaller", steps = {
                { 6022 },  -- To Kill With Purpose
                { 6042 },  -- Un-Life's Little Annoyances
                { 6133 },  -- The Ranger Lord's Behest
                { 6135 },  -- Duskwing, Oh How I Hate Thee...
                { 6136 },  -- The Corpulent One
                { 6144 },  -- The Call to Command
                { 6145 },  -- The Crimson Courier
                { 6146 },  -- Nathanos' Ruse
                { 6147 },  -- Return to Nathanos
                { 6148 },  -- The Scarlet Oracle, Demetria
            } },
        },
        [141] = {  -- Teldrassil
            { name = "Shadowglen", steps = {
                { 458, 459 },  -- The Woodland Protector
                { 456, 457 },  -- The Balance of Nature
                { 916 },  -- Webwood Venom
                { 4495 },  -- A Good Friend
                { 3519 },  -- A Friend in Need
                { 3521, 3522 },  -- Iverron's Antidote
                { 917 },  -- Webwood Egg
                { 920 },  -- Tenaron's Summons
                { 921, 928, 929, 933, 7383 },  -- Crown of the Earth
            } },
            { name = "Dolanaar", steps = {
                { 488 },  -- Zenn's Bidding
                { 475 },  -- A Troubling Breeze
                { 476 },  -- Gnarlpine Corruption
                { 2438 },  -- The Emerald Dreamcatcher
                { 489 },  -- Seek Redemption!
                { 932 },  -- Twisted Hatred
                { 487 },  -- The Road to Darnassus
                { 2459 },  -- Ferocitas the Dream Eater
                { 2541 },  -- The Sleeping Druid
                { 483 },  -- The Relics of Wakening
                { 2561 },  -- Druid of the Claw
                { 486 },  -- Ursal the Mauler
            } },
            { name = "Lake Al'Ameth", steps = {
                { 918 },  -- Timberling Seeds
                { 919 },  -- Timberling Sprouts
                { 922 },  -- Rellian Greenspyre
                { 923 },  -- Tumors
                { 2498 },  -- Return to Denalan
                { 2499 },  -- Oakenscowl
                { 930 },  -- The Glowing Fruit
                { 931 },  -- The Shimmering Frond
                { 2399 },  -- The Sprouted Fronds
                { 927 },  -- The Moss-twined Heart
                { 941 },  -- Planting the Heart
            } },
            { name = "The Oracle Glade", steps = {
                { 937 },  -- The Enchanted Glade
                { 940 },  -- Teldrassil
                { 938 },  -- Mist
            } },
        },
        [148] = {  -- Darkshore
            { name = "Auberdine", steps = {
                { 983 },  -- Buzzbox 827
                { 1001 },  -- Buzzbox 411
                { 1002 },  -- Buzzbox 323
                { 2118 },  -- Plagued Lands
                { 1003 },  -- Buzzbox 525
                { 2138 },  -- Cleansing of the Infected
                { 982 },  -- Deep Ocean, Vast Sea
                { 1138 },  -- Fruit of the Sea
                { 2139 },  -- Tharnariun's Hope
                { 4740 },  -- WANTED: Murkdeep!
            } },
            { name = "The Highborne Ruins", steps = {
                { 953 },  -- The Fall of Ameth'Aran
                { 954, 955, 956, 957 },  -- Bashal'Aran
                { 958 },  -- Tools of the Highborne
                { 4811 },  -- The Red Crystal
                { 4812 },  -- As Water Cascades
                { 4813 },  -- The Fragments Within
                { 963 },  -- For Love Eternal
            } },
            { name = "Washed Ashore", steps = {
                { 3524, 4681 },  -- Washed Ashore
                { 4722, 4725, 4727, 4731, 4732 },  -- Beached Sea Turtle
                { 4723, 4728, 4730, 4733 },  -- Beached Sea Creature
            } },
            { name = "The Blackwood Corrupted", steps = {
                { 984, 985 },  -- How Big a Threat?
                { 4761 },  -- Thundris Windweaver
                { 4762 },  -- The Cliffspring River
                { 4763 },  -- The Blackwood Corrupted
                { 986, 993 },  -- A Lost Master
                { 995, 994, any = true },  -- Escape Through Stealth / Escape Through Force
            } },
            { name = "Ruins of Mathystra", steps = {
                { 947 },  -- Cave Mushrooms
                { 948 },  -- Onu
                { 944 },  -- The Master's Glaive
                { 949 },  -- The Twilight Camp
                { 950 },  -- Return to Onu
                { 729, 731, 741, 942, 943 },  -- The Absent Minded Prospector
                { 951 },  -- Mathystra Relics
                { 5321 },  -- The Sleeper Has Awakened
            } },
            { name = "The Tower of Althalaxx", steps = {
                { 965, 966, 967, 970, 973, 1140, 1167, 1143, 981 },  -- The Tower of Althalaxx
            } },
        },
        [14] = {  -- Durotar
            { name = "Valley of Trials", steps = {
                { 4641 },  -- Your Place In The World
                { 788 },  -- Cutting Teeth
                { 789 },  -- Sting of the Scorpid
                { 4402 },  -- Galgar's Cactus Apple Surprise
                { 5441 },  -- Lazy Peons
                { 6394 },  -- Thazz'ril's Pick
                { 790, 804 },  -- Sarkoth
                { 794 },  -- Burning Blade Medallion
                { 805 },  -- Report to Sen'jin Village
                { 2161 },  -- A Peon's Burden
            } },
            { name = "The Burning Blade", steps = {
                { 823 },  -- Report to Orgnil
                { 806 },  -- Dark Storms
                { 828 },  -- Margoz
                { 827 },  -- Skull Rock
                { 829 },  -- Neeru Fireblade
                { 809 },  -- Ak'Zeloth
                { 924 },  -- The Demon Seed
            } },
            { name = "Sen'jin Village", steps = {
                { 818 },  -- A Solvent Spirit
                { 786 },  -- Thwarting Kolkar Aggression
                { 817 },  -- Practical Prey
                { 808 },  -- Minshina's Skull
                { 826 },  -- Zalazane
            } },
            { name = "Tiragarde Keep", steps = {
                { 784 },  -- Vanquish the Betrayers
                { 830, 831 },  -- The Admiral's Orders
                { 825 },  -- From The Wreckage....
                { 837 },  -- Encroachment
            } },
            { name = "Razor Hill", steps = {
                { 791 },  -- Carry Your Weight
                { 815 },  -- Break a Few Eggs
            } },
        },
        [215] = {  -- Mulgore
            { name = "Rites of the Earthmother", steps = {
                { 752, 753 },  -- A Humble Task
                { 755, 763, 776 },  -- Rites of the Earthmother
                { 757 },  -- Rite of Strength
                { 767, 771, 772 },  -- Rite of Vision
                { 773 },  -- Rite of Wisdom
                { 775 },  -- Journey into Thunder Bluff
            } },
            { name = "Camp Narache", steps = {
                { 747 },  -- The Hunt Begins
                { 750 },  -- The Hunt Continues
                { 780 },  -- The Battleboars
                { 1656 },  -- A Task Unfinished
                { 3376 },  -- Break Sharptusk!
            } },
            { name = "Cleansing the Wells", steps = {
                { 748 },  -- Poison Water
                { 754 },  -- Winterhoof Cleansing
                { 756 },  -- Thunderhorn Totem
                { 758 },  -- Thunderhorn Cleansing
                { 759 },  -- Wildmane Totem
                { 760 },  -- Wildmane Cleansing
            } },
            { name = "Bloodhoof Village", steps = {
                { 745 },  -- Sharing the Land
                { 761 },  -- Swoop Hunting
                { 743 },  -- Dangers of the Windfury
                { 746 },  -- Dwarven Digging
                { 766 },  -- Mazzranache
                { 854 },  -- Journey to the Crossroads
            } },
            { name = "The Venture Co.", steps = {
                { 749, 751 },  -- The Ravaged Caravan
                { 764 },  -- The Venture Co.
                { 765 },  -- Supervisor Fizsprocket
            } },
        },
        [17] = {  -- The Barrens
            { name = "Beasts of the Barrens", steps = {
                { 860 },  -- Sergra Darkthorn
                { 844 },  -- Plainstrider Menace
                { 845 },  -- The Zhevra
                { 903 },  -- Prowlers of the Barrens
                { 881 },  -- Echeyakee
                { 905 },  -- The Angry Scytheclaws
                { 3261 },  -- Jorn Skyseer
                { 882 },  -- Ishamuhale
                { 907 },  -- Enraged Thunder Lizards
                { 913 },  -- Cry of the Thunderhawk
                { 6382 },  -- The Ashenvale Hunt
                { 874 },  -- Mahren Skyseer
                { 873 },  -- Isha Awak
            } },
            { name = "The Barrens Oases", steps = {
                { 886 },  -- The Barrens Oases
                { 870 },  -- The Forgotten Pools
                { 877 },  -- The Stagnant Oasis
                { 880 },  -- Altered Beings
                { 3301 },  -- Mura Runetotem
            } },
            { name = "The Crossroads", steps = {
                { 871 },  -- Disrupt the Attacks
                { 869 },  -- Raptor Thieves
                { 5041 },  -- Supplies for the Crossroads
                { 848 },  -- Fungal Spores
                { 872 },  -- The Disruption Ends
                { 3281 },  -- Stolen Silver
                { 899 },  -- Consumed by Hatred
                { 4921 },  -- Lost in Battle
                { 868 },  -- Egg Hunt
            } },
            { name = "Raiders of the Barrens", steps = {
                { 855 },  -- Centaur Bracers
                { 867 },  -- Harpy Raiders
                { 850 },  -- Kolkar Leaders
                { 875 },  -- Harpy Lieutenants
                { 851 },  -- Verog the Dervish
                { 852 },  -- Hezrul Bloodmark
                { 876 },  -- Serena Bloodfeather
                { 1060 },  -- Letter to Jin'Zil
                { 4021 },  -- Counterattack!
            } },
            { name = "Samophlange", steps = {
                { 894, 900, 901, 902 },  -- Samophlange
                { 3921 },  -- Wenikee Boltbucket
                { 3922 },  -- Nugget Slugs
                { 3923 },  -- Rilli Greasygob
                { 3924 },  -- Samophlange Manual
            } },
            { name = "Ratchet", steps = {
                { 887 },  -- Southsea Freebooters
                { 890, 892 },  -- The Missing Shipment
                { 819, 821 },  -- Chen's Empty Keg
                { 888 },  -- Stolen Booty
                { 895 },  -- WANTED: Baron Longshore
                { 865 },  -- Raptor Horns
                { 896 },  -- Miner's Fortune
                { 891 },  -- The Guns of Northwatch
                { 1221 },  -- Blueleaf Tubers
            } },
            { name = "Mor'shan Rampart", steps = {
                { 858 },  -- Ignition
                { 863 },  -- The Escape
                { 6541 },  -- Report to Kadrak
                { 6543 },  -- The Warsong Reports
                { 3513 },  -- The Runed Scroll
                { 3514 },  -- Horde Presence
            } },
            { name = "Camp Taurajo", steps = {
                { 878 },  -- Tribes at War
                { 5052 },  -- Blood Shards of Agamaggan
                { 893 },  -- Weapons of Choice
                { 879, 906 },  -- Betrayal from Within
                { 1153 },  -- A New Ore Sample
            } },
            { name = "Bael Modan", steps = {
                { 843 },  -- Gann's Reclamation
                { 846, 849 },  -- Revenge of Gann
                { 1102 },  -- A Vengeful Fate
            } },
        },
        [331] = {  -- Ashenvale
            { name = "Raene's Cleansing", steps = {
                { 991, 1023, 1024, 1026, 1027, 1028, 1055, 1029, 1030, 1045, 1046 },  -- Raene's Cleansing
                { 1025 },  -- An Aggressive Defense
                { 1054 },  -- Culling the Threat
            } },
            { name = "Zoram'gar Outpost", steps = {
                { 6442 },  -- Naga at the Zoram Strand
                { 6641 },  -- Vorsha the Lasher
                { 216 },  -- Between a Rock and a Thistlefur
                { 6462 },  -- Troll Charm
                { 6482 },  -- Freedom to Ruul
                { 6621 },  -- King of the Foulweald
            } },
            { name = "Astranaar", steps = {
                { 1008 },  -- The Zoram Strand
                { 1007 },  -- The Ancient Statuette
                { 1134 },  -- Pridewings of Stonetalon
                { 1016 },  -- Elemental Bracers
                { 1009 },  -- Ruuzel
                { 1017 },  -- Mage Summoner
                { 1011 },  -- Forsaken Diseases
                { 1012 },  -- Insane Druids
            } },
            { name = "Maestra's Post", steps = {
                { 1010 },  -- Bathran's Hair
                { 1020 },  -- Orendil's Cure
                { 1033 },  -- Elune's Tear
                { 1034 },  -- The Ruins of Stardust
                { 976 },  -- Supplies to Auberdine
                { 1035 },  -- Fallen Sky Lake
                { 1021 },  -- Vile Satyr! Dryads in Danger!
                { 1031 },  -- The Branch of Cenarius
                { 1032 },  -- Satyr Slaying!
            } },
            { name = "The Ashenvale Hunt", steps = {
                { 6383 },  -- The Ashenvale Hunt
                { 23 },  -- Ursangous's Paw
                { 24 },  -- Shadumbra's Head
                { 2 },  -- Sharptalon's Claw
                { 247 },  -- The Hunt Completed
            } },
            { name = "Splintertree Post", steps = {
                { 6503 },  -- Ashenvale Outrunners
                { 6544 },  -- Torek's Assault
                { 25 },  -- Stonetalon Standstill
                { 6441 },  -- Satyr Horns
                { 1918 },  -- The Befouled Element
                { 824 },  -- Je'neu of the Earthen Ring
                { 6571 },  -- Warsong Supplies
                { 6504 },  -- The Lost Pages
            } },
            { name = "The Scythe of Elune", steps = {
                { 1022 },  -- The Howling Vale
                { 1037 },  -- Velinde Starsong
                { 1038 },  -- Velinde's Effects
                { 1039 },  -- The Barrens Port
                { 1040 },  -- Passage to Booty Bay
                { 1041 },  -- The Caravan Road
                { 1042 },  -- The Carevin Family
                { 1043 },  -- The Scythe of Elune
                { 1044 },  -- Answered Questions
            } },
        },
        [406] = {  -- Stonetalon Mountains
            { name = "Malaka'jin", steps = {
                { 1061 },  -- The Spirits of Stonetalon
                { 1062 },  -- Goblin Invaders
                { 1063 },  -- The Elder Crone
                { 6461 },  -- Blood Feeders
                { 6542 },  -- Report to Kadrak
                { 1068 },  -- Shredding Machines
                { 1058 },  -- Jin'Zil's Forest Magic
            } },
            { name = "The Grimtotem", steps = {
                { 6523 },  -- Protect Kaya
                { 6401 },  -- Kaya's Alive
                { 6548 },  -- Avenge My Village
                { 6629 },  -- Kill Grundig Darkcloud
            } },
            { name = "Sun Rock Retreat", steps = {
                { 6421 },  -- Boulderslide Ravine
                { 6481 },  -- Earthen Arise
                { 6301 },  -- Cycle of Rebirth
                { 1087 },  -- Cenarius' Legacy
                { 6381 },  -- New Life
                { 6393 },  -- Elemental War
                { 6282 },  -- Harpies Threaten
                { 6283 },  -- Bloodfury Bloodline
                { 1088 },  -- Ordanus
                { 1089 },  -- The Den
            } },
            { name = "Gaxim's Experiments", steps = {
                { 1071 },  -- A Gnome's Respite
                { 1072 },  -- An Old Colleague
                { 1073, 1074 },  -- Ineptitude + Chemicals = Fun
                { 1075 },  -- A Scroll from Mauren
                { 1076 },  -- Devils in Westfall
                { 1077 },  -- Special Delivery for Gaxim
                { 1078 },  -- Retrieval for Mauren
            } },
            { name = "Windshear Crag", steps = {
                { 1093 },  -- Super Reaper 6000
                { 1094, 1095 },  -- Further Instructions
                { 1079 },  -- Covert Ops - Alpha
                { 1080 },  -- Covert Ops - Beta
                { 1082 },  -- Update for Sentinel Thenysil
                { 1090, 1092 },  -- Gerenzo's Orders
                { 1091 },  -- Kaela's Update
                { 1096 },  -- Gerenzo Wrenchwhistle
            } },
            { name = "Stonetalon Peak", steps = {
                { 1083 },  -- Enraged Spirits
                { 1057, 1059 },  -- Reclaiming the Charred Vale
                { 1081 },  -- Reception from Tyrande
                { 1084 },  -- Wounded Ancients
            } },
        },
        [405] = {  -- Desolace
            { name = "Nijel's Point", steps = {
                { 1366, 1387 },  -- Centaur Bounty
                { 1437, 1465, 1438 },  -- Vahlarriel's Search
                { 1439 },  -- Search for Tyranis
                { 1440 },  -- Return to Vahlarriel
                { 6141 },  -- Brother Anton
                { 261, 1052 },  -- Down the Scarlet Path
            } },
            { name = "The Centaur Clans", steps = {
                { 1361 },  -- Regthar Deathgate
                { 1362 },  -- The Kolkar of Desolace
                { 1367 },  -- Magram Alliance
                { 1368 },  -- Gelkis Alliance
                { 1365 },  -- Khan Dez'hepah
                { 1382 },  -- Strange Alliance
                { 1384 },  -- Raid on the Kolkar
                { 1370 },  -- Stealing Supplies
                { 1385 },  -- Brutal Politics
                { 1386 },  -- Assault on the Kolkar
                { 1369 },  -- Broken Tears
                { 1371 },  -- Gizmo for Warug
                { 1373 },  -- Ongeku
                { 1374 },  -- Khan Jehn
                { 1375 },  -- Khan Shaka
                { 1380, 1381 },  -- Khan Hratha
            } },
            { name = "Reclaimers Inc.", steps = {
                { 1458, 1459, 1466, 1467 },  -- Reagents for Reclaimers Inc.
                { 1454, 1455, 1456, 1457 },  -- The Karnitol Shipwreck
            } },
            { name = "The Corrupter", steps = {
                { 1480, 1481, 1482, 1484, 1488 },  -- The Corrupter
            } },
            { name = "Ethel Rethor", steps = {
                { 5741 },  -- Sceptre of Light
                { 6161 },  -- Claim Rackmore's Treasure!
                { 6027 },  -- Book of the Ancients
            } },
            { name = "Kodo Graveyard", steps = {
                { 5561 },  -- Kodo Roundup
                { 5821 },  -- Bodyguard for Hire
                { 5943 },  -- Gizelton Caravan
                { 5501 },  -- Bone Collector
                { 6134 },  -- Ghost-o-plasm Round Up
            } },
            { name = "Shadowprey Village", steps = {
                { 6142 },  -- Clam Bait
                { 6143 },  -- Other Fish to Fry
                { 5386 },  -- Catch of the Day
                { 5381 },  -- Hand of Iruxos
                { 5581 },  -- Portals of the Legion
            } },
        },
        [400] = {  -- Thousand Needles
            { name = "Freewind Post", steps = {
                { 4542 },  -- Message to Freewind Post
                { 4841 },  -- Pacify the Centaur
                { 5064 },  -- Grimtotem Spying
                { 4767 },  -- Wind Rider
                { 4904 },  -- Free at Last
                { 5147 },  -- Wanted - Arnak Grimtotem
            } },
            { name = "Tests of the Plainstalker", steps = {
                { 1149 },  -- Test of Faith
                { 1150 },  -- Test of Endurance
                { 1151 },  -- Test of Strength
                { 1152, 1154, 6627, 1159, 6628 },  -- Test of Lore
                { 1394 },  -- Final Passage
            } },
            { name = "Arikara", steps = {
                { 4821 },  -- Alien Egg
                { 4865 },  -- Serpent Wild
                { 5062 },  -- Sacred Fire
                { 5088 },  -- Arikara
            } },
            { name = "Goblin Sponsorship", steps = {
                { 1176 },  -- Load Lightening
                { 1178, 1180, 1181, 1182, 1183 },  -- Goblin Sponsorship
                { 1186 },  -- The Eighteenth Pilot
                { 1187 },  -- Razzeric's Tweaking
                { 1188, 1189 },  -- Safety First
            } },
            { name = "The Brassbolts Brothers", steps = {
                { 1104 },  -- Salt Flat Venom
                { 1105 },  -- Hardened Shells
                { 1179, 2769 },  -- The Brassbolts Brothers
                { 1106 },  -- Martek the Exiled
                { 1107 },  -- Encrusted Tail Fins
                { 1108 },  -- Indurium
                { 1137 },  -- News for Fizzle
                { 1190 },  -- Keeping Pace
                { 1194 },  -- Rizzle's Schematics
            } },
            { name = "Kravel Koalbeard", steps = {
                { 1110 },  -- Rocket Car Parts
                { 5762 },  -- Hemet Nesingwary
                { 1175 },  -- A Bump in the Road
                { 1111 },  -- Wharfmaster Dizzywig
                { 1112 },  -- Parts for Kravel
                { 1114 },  -- Delivery to the Gnomes
                { 1115 },  -- The Rumormonger
                { 1117 },  -- Rumors for Kravel
                { 1118 },  -- Back to Booty Bay
                { 1119 },  -- Zanzil's Mixture and a Fool's Stout
                { 1120, 1121, any = true },  -- Get the Gnomes Drunk / Get the Goblins Drunk
                { 1122 },  -- Report Back to Fizzlebub
            } },
        },
        [15] = {  -- Dustwallow Marsh
            { name = "The Black Shield", steps = {
                { 1251, 1253, 1319, 1320, 1321, 1276, 1322, 1323 },  -- The Black Shield
                { 1268, 1284 },  -- Suspicious Hoofprints
                { 1282 },  -- They Call Him Smiling Jim
                { 1269, 1252, 1259 },  -- Lieutenant Paval Reethe
                { 1273 },  -- Questioning Reethe
                { 1285 },  -- Daelin's Men
                { 1286, 1287 },  -- The Deserters
            } },
            { name = "The Lost Report", steps = {
                { 1238 },  -- The Lost Report
                { 1239 },  -- The Severed Head
                { 1240 },  -- The Troll Witchdoctor
                { 1261 },  -- Marg Speaks
                { 1262 },  -- Report to Zor
                { 7541 },  -- Service to the Horde
            } },
            { name = "Swamp Eye Jarl", steps = {
                { 1218 },  -- Soothing Spices
                { 1206 },  -- Jarl Needs Eyes
                { 1203 },  -- Jarl Needs a Blade
            } },
            { name = "Theramore Isle", steps = {
                { 1219 },  -- The Orc Report
                { 1220 },  -- Captain Vimes
                { 1222, 1270 },  -- Stinky's Escape
                { 1260 },  -- Morgan Stern
                { 1204 },  -- Mudrock Soup and Bugs
                { 1271 },  -- Feast at the Blue Recluse
                { 1258 },  -- ... and Bugs
            } },
            { name = "Brackenwall Village", steps = {
                { 1201 },  -- Theramore Spies
                { 1202 },  -- The Theramore Docks
                { 1177 },  -- Hungry!
            } },
            { name = "The Brood of Onyxia", steps = {
                { 1166 },  -- Overlord Mok'Morokk's Concern
                { 1168 },  -- Army of the Black Dragon
                { 1169 },  -- Identifying the Brood
                { 1170, 1171, 1172 },  -- The Brood of Onyxia
                { 1173 },  -- Challenge Overlord Mok'Morokk
            } },
        },
        [357] = {  -- Feralas
            { name = "War on the Woodpaw", steps = {
                { 2862 },  -- War on the Woodpaw
                { 2863 },  -- Alpha Strike
                { 2902 },  -- Woodpaw Investigation
                { 2903 },  -- The Battle Plans
                { 7730 },  -- Zukk'ash Infestation
                { 7731 },  -- Stinglasher
                { 7732 },  -- Zukk'ash Report
            } },
            { name = "The Gordunni", steps = {
                { 2975, 2980 },  -- The Ogres of Feralas
                { 2978 },  -- The Gordunni Scroll
                { 2987 },  -- Gordunni Cobalt
                { 2973 },  -- A New Cloak's Sheen
                { 2974, 2976 },  -- A Grim Discovery
                { 2979 },  -- Dark Ceremony
                { 3002 },  -- The Gordunni Orb
            } },
            { name = "The Missing Courier", steps = {
                { 4124, 4125 },  -- The Missing Courier
                { 4127 },  -- Boat Wreckage
                { 4129 },  -- The Knife Revealed
                { 4130 },  -- Psychometric Reading
                { 4131 },  -- The Woodpaw Gnolls
                { 4135 },  -- The Writhing Deep
                { 4265 },  -- Freed from the Hive
                { 4266 },  -- A Hero's Welcome
                { 4267 },  -- Rise of the Silithid
            } },
            { name = "Against the Hatecrest", steps = {
                { 2866 },  -- The Ruins of Solarsal
                { 2867 },  -- Return to Feathermoon Stronghold
                { 3130, 2869 },  -- Against the Hatecrest
                { 2870 },  -- Against Lord Shalzaru
                { 2871 },  -- Delivering the Relic
            } },
            { name = "Feathermoon Stronghold", steps = {
                { 2982 },  -- The High Wilderness
                { 2821 },  -- The Mark of Quality
                { 7733 },  -- Improved Quality
                { 3788 },  -- Jonespyre's Request
                { 3791 },  -- The Mystery of Morrowgrain
            } },
            { name = "The Muisek Vessel", steps = {
                { 3121 },  -- A Strange Request
                { 3122 },  -- Return to Witch Doctor Uzer'i
                { 3123 },  -- Testing the Vessel
                { 3124 },  -- Hippogryph Muisek
                { 3125 },  -- Faerie Dragon Muisek
                { 3126 },  -- Treant Muisek
                { 3127 },  -- Mountain Giant Muisek
                { 3128 },  -- Natural Materials
                { 3129 },  -- Weapons of Spirit
            } },
            { name = "Camp Mojache", steps = {
                { 2822 },  -- The Mark of Quality
                { 7734 },  -- Improved Quality
                { 3062 },  -- Dark Heart
                { 3063 },  -- Vengeance on the Northspring
            } },
            { name = "The Stave of Equinex", steps = {
                { 2939 },  -- In Search of Knowledge
                { 2940 },  -- Feralas: A History
                { 2941 },  -- The Borrower
                { 2944 },  -- The Super Snapper FX
                { 2943 },  -- Return to Troyas
                { 2879 },  -- The Stave of Equinex
                { 2942 },  -- The Morrow Stone
            } },
            { name = "The Sprite Darters", steps = {
                { 2969 },  -- Freedom for All Creatures
                { 2970, 2972 },  -- Doling Justice
                { 3841 },  -- An Orphan Looking For a Home
                { 3842 },  -- A Short Incubation
                { 3843 },  -- The Newest Member of the Family
                { 4297 },  -- Food for Baby
                { 4298 },  -- Becoming a Parent
            } },
        },
        [440] = {  -- Tanaris
            { name = "Bandits & Pirates", steps = {
                { 1690 },  -- Wastewander Justice
                { 1691 },  -- More Wastewander Justice
                { 1707 },  -- Water Pouch Bounty
                { 2875 },  -- WANTED: Andre Firebeard
                { 8365 },  -- Pirate Hats Ahoy!
                { 8366 },  -- Southsea Shakedown
                { 2781 },  -- WANTED: Caliph Scorpidsting
            } },
            { name = "Steamwheedle Port", steps = {
                { 3520 },  -- Screecher Spirits
                { 2872 },  -- Stoley's Debt
                { 2873 },  -- Stoley's Shipment
                { 3527 },  -- The Prophecy of Mosh'aru
            } },
            { name = "The Noxious Lair", steps = {
                { 992 },  -- Gadgetzan Water Survey
                { 82 },  -- Noxious Lair Investigation
                { 10 },  -- The Scrimshank Redemption
                { 110, 113 },  -- Insect Part Analysis
                { 32, 162 },  -- Rise of the Silithid
                { 4496 },  -- Bungle in the Jungle
                { 4507 },  -- Pawn Captures Queen
                { 4508, 4509 },  -- Calm Before the Storm
            } },
            { name = "Gadgetzan", steps = {
                { 243 },  -- Into the Field
                { 379 },  -- Slake That Thirst
                { 654 },  -- Tanaris Field Sampling
                { 5863 },  -- The Dunemaul Compound
                { 3362 },  -- Thistleshrub Valley
            } },
            { name = "Noggenfogger Elixir", steps = {
                { 2605 },  -- The Thirsty Goblin
                { 2606 },  -- In Good Taste
                { 2641 },  -- Sprinkle's Secret Ingredient
                { 2661 },  -- Delivery for Marin
                { 2662 },  -- Noggenfogger Elixir
            } },
        },
        [490] = {  -- Un'Goro Crater
            { name = "Marshal's Refuge", steps = {
                { 3882 },  -- Roll the Bones
                { 4503 },  -- Shizzle's Flyer
                { 3883 },  -- Alien Ecology
                { 3881 },  -- Expedition Salvation
                { 4243, 4244, 4245 },  -- Chasing A-Me 01
                { 4501 },  -- Beware of Pterrordax
            } },
            { name = "Muigin and Larion", steps = {
                { 4141 },  -- Muigin and Larion
                { 4142 },  -- A Visit to Gregan
                { 4143 },  -- Haze of Evil
                { 4145 },  -- Larion and Muigin
                { 4147 },  -- Marvon's Workshop
                { 4146 },  -- Zapper Fuel
                { 4148 },  -- Bloodpetal Zapper
            } },
            { name = "Linken's Adventure", steps = {
                { 3844, 3845, 3908 },  -- It's a Secret to Everybody
                { 3909 },  -- The Videre Elixir
                { 3912 },  -- Meet at the Grave
                { 3913 },  -- A Grave Situation
                { 3914 },  -- Linken's Sword
                { 3941 },  -- A Gnome's Assistance
                { 3942 },  -- Linken's Memory
                { 4084 },  -- Silver Heart
                { 4005 },  -- Aquementas
                { 3961 },  -- Linken's Adventure
                { 3962 },  -- It's Dangerous to Go Alone
            } },
            { name = "Crystals of Power", steps = {
                { 4284 },  -- Crystals of Power
                { 4285 },  -- The Northern Pylon
                { 4287 },  -- The Eastern Pylon
                { 4288 },  -- The Western Pylon
                { 4321 },  -- Making Sense of It
            } },
            { name = "Torwa Pathfinder", steps = {
                { 4290 },  -- The Fare of Lar'korwi
                { 4291 },  -- The Scent of Lar'korwi
                { 4289 },  -- The Apes of Un'Goro
                { 4301 },  -- The Mighty U'cha
                { 4292 },  -- The Bait for Lar'korwi
            } },
            { name = "Fire Plume Ridge", steps = {
                { 974 },  -- Finding the Source
                { 980 },  -- The New Springs
                { 4492 },  -- Lost!
                { 4491 },  -- A Little Help From My Friends
                { 4502 },  -- Volcanic Activity
            } },
        },
        [361] = {  -- Felwood
            { name = "Timbermaw Hold", steps = {
                { 8460 },  -- Timbermaw Ally
                { 8461 },  -- Deadwood of the North
                { 8462 },  -- Speak to Nafien
            } },
            { name = "Forces of Jaedenar", steps = {
                { 5155 },  -- Forces of Jaedenar
                { 5157 },  -- Collection of the Corrupt Water
                { 5158 },  -- Seeking Spiritual Aid
                { 5156 },  -- Verifying the Corruption
                { 5159 },  -- Cleansed Water Returns to Felwood
                { 5165 },  -- Dousing the Flames of Protection
                { 5242 },  -- A Final Blow
            } },
            { name = "Bloodvenom Post", steps = {
                { 6162 },  -- A Husband's Last Battle
                { 4505 },  -- Well of Corruption
                { 4506 },  -- Corrupted Sabers
                { 4521, 4741, 4721 },  -- Wild Guardians
            } },
            { name = "The Jadefire Satyrs", steps = {
                { 939 },  -- Flute of Xavaric
                { 4421 },  -- The Corruption of the Jadefire
                { 4441 },  -- Felbound Ancients
                { 4442 },  -- Purified!
                { 4906 },  -- Further Corruption
                { 4261 },  -- Ancient Spirit
            } },
            { name = "Rescue From Jaedenar", steps = {
                { 5202 },  -- A Strange Red Key
                { 5203 },  -- Rescue From Jaedenar
                { 5204 },  -- Retribution of the Light
                { 5385 },  -- The Remains of Trey Lightforge
            } },
        },
        [16] = {  -- Azshara
            { name = "Stealing Knowledge", steps = {
                { 3517 },  -- Stealing Knowledge
                { 3518 },  -- Delivery to Magatha
                { 3541 },  -- Delivery to Jes'rimon
                { 3542 },  -- Delivery to Andron Gant
                { 3561 },  -- Delivery to Archmage Xylem
                { 3562 },  -- Magatha's Payment to Jediga
                { 3563 },  -- Jes'rimon's Payment to Jediga
                { 3564 },  -- Andron's Payment to Jediga
                { 3565 },  -- Xylem's Payment to Jediga
            } },
            { name = "Loramus Thalipedes", steps = {
                { 3141 },  -- Loramus
                { 3508 },  -- Breaking the Ward
                { 3509, 3510, 3511 },  -- The Name of the Beast
                { 3602 },  -- Azsharite
                { 3621 },  -- The Formation of Felbane
            } },
        },
        [618] = {  -- Winterspring
            { name = "Everlook", steps = {
                { 4809 },  -- Chillwind Horns
                { 3783, 977, 5163 },  -- Are We There, Yeti?
                { 969 },  -- Luck Be With You
                { 975 },  -- Cache of Mau'ari
                { 8798 },  -- A Yeti of Your Own
            } },
            { name = "The Winterfall", steps = {
                { 4842 },  -- Strange Sources
                { 5083 },  -- Winterfall Firewater
                { 5084 },  -- Falling to Corruption
                { 5085 },  -- Mystery Goo
                { 5086 },  -- Toxic Horrors
                { 6603 },  -- Trouble in Winterspring!
                { 5082 },  -- Threat of the Winterfall
                { 5087 },  -- Winterfall Runners
                { 5121 },  -- High Chief Winterfall
                { 5123 },  -- The Final Piece
                { 5128 },  -- Words of the High Chief
            } },
            { name = "Starfall Village", steps = {
                { 5244 },  -- The Ruins of Kel'Theril
                { 5245 },  -- Troubled Spirits of Kel'Theril
                { 5252 },  -- Remorseful Highborne
                { 5253 },  -- The Crystal of Zin-Malor
                { 4901 },  -- Guardians of the Altar
                { 4902 },  -- Wildkin of Elune
                { 6604, 4861, 4863, 4864 },  -- Enraged Wildkin
            } },
            { name = "Beasts of Winterspring", steps = {
                { 5054 },  -- Ursius of the Shardtooth
                { 5055 },  -- Brumeran of the Chillwind
                { 5056 },  -- Shy-Rotam
                { 5057 },  -- Past Endeavors
            } },
        },
        [1377] = {  -- Silithus
            { name = "Southwind Village", steps = {
                { 1125 },  -- The Spirits of Southwind
                { 1126 },  -- Hive in the Tower
                { 6844 },  -- Umber, Archivist
            } },
            { name = "Cenarion Hold", steps = {
                { 8277 },  -- Deadly Desert Venom
                { 8280 },  -- Securing the Supply Lines
                { 8278 },  -- Noggle's Last Hope
                { 8281 },  -- Stepping Up Security
                { 8282 },  -- Noggle's Lost Satchel
                { 8283 },  -- Wanted - Deathclasp, Terror of the Sands
                { 9023 },  -- The Perfect Poison
                { 9419, 9422 },  -- Scouring the Desert
            } },
            { name = "Twilight Cultists", steps = {
                { 8284 },  -- The Twilight Mystery
                { 8285 },  -- The Deserter
                { 8279 },  -- The Twilight Lexicon
                { 8323 },  -- True Believers
                { 8287 },  -- A Terrible Purpose
                { 8318 },  -- Secret Communication
                { 8320 },  -- Twilight Geolords
                { 8321 },  -- Vyral the Vile
                { 8361 },  -- Abyssal Contacts
            } },
            { name = "Dearest Natalia", steps = {
                { 8304 },  -- Dearest Natalia
                { 8306 },  -- Into The Maw of Madness
                { 8309 },  -- Glyph Chasing
                { 8310 },  -- Breaking the Code
                { 8314 },  -- Unraveling the Mystery
                { 8315 },  -- The Calling
            } },
            { name = "The Abyssal Council", steps = {
                { 8331 },  -- Aurel Goldleaf
                { 8332 },  -- Dukes of the Council
                { 8343 },  -- Goldleaf's Discovery
                { 8341 },  -- Lords of the Council
                { 8349 },  -- Bor Wildmane
                { 8348 },  -- Signet of the Dukes
                { 8351 },  -- Bor Wishes to Speak
                { 8352 },  -- Scepter of the Council
                { 9248 },  -- A Humble Offering
            } },
        },
    },
}
