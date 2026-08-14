-- DragonUI_NewEra/modules/cooldownviewer/CdmSpellAuras.lua — GENERATED, DO NOT HAND-EDIT.
--
-- WHICH AURA a castable spell drives, and on WHICH UNIT it lands. Regenerate with
-- tools/cdm-spellgen/gen_spellauras.py; the reasoning behind every rule is in that file's header.
--
-- The Cooldown Manager used to answer "is this spell's effect up" by matching the aura's NAME to the
-- spell's NAME, on the PLAYER. That misses an ability whose aura is named differently (Bloodsurge
-- turns Slam into `Slam!`) and every ability whose aura lands somewhere else (Faerie Fire and
-- Moonfire on the target, Earth Shield on a party member). This table is the missing edge.
--
--   [spellID] = { { id = <auraID>, unit = "player"|"target"|"friend", name = "<enUS>" }, ... }
--
-- KEYED BY EVERY RANK, like AlertData.lua and for the same reason: the curated lists key rank 1, a
-- custom list may hold any rank, and the tile displays the highest LEARNED one.
--
-- `id` IS THE PAYLOAD; `name` IS A FALLBACK. Matching at runtime is by name, but the name comes from
-- GetSpellInfo(id) on the LIVE client, so it is whatever locale the player is running. `name` here is
-- enUS and is used only when the client cannot name the id at all. Storing the enUS string as the
-- primary key would break exactly the player who reported this — `Slam!` is `¡Embate!` in esES, and
-- no amount of appending "!" gets you there.
--
-- Rows the plain name-on-player lookup already resolves are deliberately absent: Lightning Shield is
-- its own aura, on you, under its own name, and has never needed help.
--
-- KNOWN GAP: Data/patch-4.MPQ and patch-S.mpq are encrypted and unreadable, so if this server
-- overrides spell data there, these ids reflect the stock client.

local NE = DragonUI_NewEra
NE.cooldownviewer = NE.cooldownviewer or {}
local M = NE.cooldownviewer

M.SPELL_AURA_LINKS = {

  -- DEATHKNIGHT
  [45462] = { { id = 55078, unit = "target", name = "Blood Plague" } },  -- Plague Strike (Rank 1) -> Blood Plague via trigger on target
  [49917] = { { id = 55078, unit = "target", name = "Blood Plague" } },  -- Plague Strike (Rank 2) -> Blood Plague via trigger on target
  [49918] = { { id = 55078, unit = "target", name = "Blood Plague" } },  -- Plague Strike (Rank 3) -> Blood Plague via trigger on target
  [49919] = { { id = 55078, unit = "target", name = "Blood Plague" } },  -- Plague Strike (Rank 4) -> Blood Plague via trigger on target
  [49920] = { { id = 55078, unit = "target", name = "Blood Plague" } },  -- Plague Strike (Rank 5) -> Blood Plague via trigger on target
  [49921] = { { id = 55078, unit = "target", name = "Blood Plague" } },  -- Plague Strike (Rank 6) -> Blood Plague via trigger on target
  [52373] = { { id = 52373, unit = "target", name = "Plague Strike" } },  -- Plague Strike (Rank 1) -> Plague Strike on target
  [45469] = { { id = 45469, unit = "target", name = "Death Strike" } },  -- Death Strike -> Death Strike on target
  [45477] = { { id = 55095, unit = "target", name = "Frost Fever" } },  -- Icy Touch (Rank 1) -> Frost Fever via trigger on target
  [49896] = { { id = 55095, unit = "target", name = "Frost Fever" } },  -- Icy Touch (Rank 2) -> Frost Fever via trigger on target
  [49903] = { { id = 55095, unit = "target", name = "Frost Fever" } },  -- Icy Touch (Rank 3) -> Frost Fever via trigger on target
  [49904] = { { id = 55095, unit = "target", name = "Frost Fever" } },  -- Icy Touch (Rank 4) -> Frost Fever via trigger on target
  [49909] = { { id = 55095, unit = "target", name = "Frost Fever" } },  -- Icy Touch (Rank 5) -> Frost Fever via trigger on target
  [52372] = { { id = 52372, unit = "target", name = "Icy Touch" } },  -- Icy Touch (Rank 1) -> Icy Touch on target
  [45524] = { { id = 45524, unit = "target", name = "Chains of Ice" } },  -- Chains of Ice -> Chains of Ice on target
  [47476] = { { id = 47476, unit = "target", name = "Strangulate" } },  -- Strangulate -> Strangulate on target
  [49005] = { { id = 49005, unit = "target", name = "Mark of Blood" } },  -- Mark of Blood -> Mark of Blood on target
  [49206] = { { id = 49206, unit = "target", name = "Summon Gargoyle" } },  -- Summon Gargoyle -> Summon Gargoyle on target
  [49560] = { { id = 49560, unit = "target", name = "Death Grip" } },  -- Death Grip -> Death Grip on target
  [50536] = { { id = 50536, unit = "target", name = "Unholy Blight" } },  -- Unholy Blight -> Unholy Blight on target
  [56222] = { { id = 56222, unit = "target", name = "Dark Command" } },  -- Dark Command -> Dark Command on target

  -- DRUID
  [339] = { { id = 339, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 1) -> Entangling Roots on target
  [1062] = { { id = 1062, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 2) -> Entangling Roots on target
  [5195] = { { id = 5195, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 3) -> Entangling Roots on target
  [5196] = { { id = 5196, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 4) -> Entangling Roots on target
  [9852] = { { id = 9852, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 5) -> Entangling Roots on target
  [9853] = { { id = 9853, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 6) -> Entangling Roots on target
  [26989] = { { id = 26989, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 7) -> Entangling Roots on target
  [53308] = { { id = 53308, unit = "target", name = "Entangling Roots" } },  -- Entangling Roots (Rank 8) -> Entangling Roots on target
  [770] = { { id = 770, unit = "target", name = "Faerie Fire" } },  -- Faerie Fire -> Faerie Fire on target
  [1079] = { { id = 1079, unit = "target", name = "Rip" } },  -- Rip (Rank 1) -> Rip on target
  [9492] = { { id = 9492, unit = "target", name = "Rip" } },  -- Rip (Rank 2) -> Rip on target
  [9493] = { { id = 9493, unit = "target", name = "Rip" } },  -- Rip (Rank 3) -> Rip on target
  [9752] = { { id = 9752, unit = "target", name = "Rip" } },  -- Rip (Rank 4) -> Rip on target
  [9894] = { { id = 9894, unit = "target", name = "Rip" } },  -- Rip (Rank 5) -> Rip on target
  [9896] = { { id = 9896, unit = "target", name = "Rip" } },  -- Rip (Rank 6) -> Rip on target
  [27008] = { { id = 27008, unit = "target", name = "Rip" } },  -- Rip (Rank 7) -> Rip on target
  [49799] = { { id = 49799, unit = "target", name = "Rip" } },  -- Rip (Rank 8) -> Rip on target
  [49800] = { { id = 49800, unit = "target", name = "Rip" } },  -- Rip (Rank 9) -> Rip on target
  [1822] = { { id = 1822, unit = "target", name = "Rake" } },  -- Rake (Rank 1) -> Rake on target
  [1823] = { { id = 1823, unit = "target", name = "Rake" } },  -- Rake (Rank 2) -> Rake on target
  [1824] = { { id = 1824, unit = "target", name = "Rake" } },  -- Rake (Rank 3) -> Rake on target
  [9904] = { { id = 9904, unit = "target", name = "Rake" } },  -- Rake (Rank 4) -> Rake on target
  [27003] = { { id = 27003, unit = "target", name = "Rake" } },  -- Rake (Rank 5) -> Rake on target
  [48573] = { { id = 48573, unit = "target", name = "Rake" } },  -- Rake (Rank 6) -> Rake on target
  [48574] = { { id = 48574, unit = "target", name = "Rake" } },  -- Rake (Rank 7) -> Rake on target
  [2637] = { { id = 2637, unit = "target", name = "Hibernate" } },  -- Hibernate (Rank 1) -> Hibernate on target
  [18657] = { { id = 18657, unit = "target", name = "Hibernate" } },  -- Hibernate (Rank 2) -> Hibernate on target
  [18658] = { { id = 18658, unit = "target", name = "Hibernate" } },  -- Hibernate (Rank 3) -> Hibernate on target
  [2908] = { { id = 2908, unit = "target", name = "Soothe Animal" } },  -- Soothe Animal (Rank 1) -> Soothe Animal on target
  [8955] = { { id = 8955, unit = "target", name = "Soothe Animal" } },  -- Soothe Animal (Rank 2) -> Soothe Animal on target
  [9901] = { { id = 9901, unit = "target", name = "Soothe Animal" } },  -- Soothe Animal (Rank 3) -> Soothe Animal on target
  [26995] = { { id = 26995, unit = "target", name = "Soothe Animal" } },  -- Soothe Animal (Rank 4) -> Soothe Animal on target
  [5211] = { { id = 5211, unit = "target", name = "Bash" } },  -- Bash (Rank 1) -> Bash on target
  [6798] = { { id = 6798, unit = "target", name = "Bash" } },  -- Bash (Rank 2) -> Bash on target
  [8983] = { { id = 8983, unit = "target", name = "Bash" } },  -- Bash (Rank 3) -> Bash on target
  [5570] = { { id = 5570, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 1) -> Insect Swarm on target
  [24974] = { { id = 24974, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 2) -> Insect Swarm on target
  [24975] = { { id = 24975, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 3) -> Insect Swarm on target
  [24976] = { { id = 24976, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 4) -> Insect Swarm on target
  [24977] = { { id = 24977, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 5) -> Insect Swarm on target
  [27013] = { { id = 27013, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 6) -> Insect Swarm on target
  [48468] = { { id = 48468, unit = "target", name = "Insect Swarm" } },  -- Insect Swarm (Rank 7) -> Insect Swarm on target
  [6795] = { { id = 6795, unit = "target", name = "Growl" } },  -- Growl -> Growl on target
  [8921] = { { id = 8921, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 1) -> Moonfire on target
  [8924] = { { id = 8924, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 2) -> Moonfire on target
  [8925] = { { id = 8925, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 3) -> Moonfire on target
  [8926] = { { id = 8926, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 4) -> Moonfire on target
  [8927] = { { id = 8927, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 5) -> Moonfire on target
  [8928] = { { id = 8928, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 6) -> Moonfire on target
  [8929] = { { id = 8929, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 7) -> Moonfire on target
  [9833] = { { id = 9833, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 8) -> Moonfire on target
  [9834] = { { id = 9834, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 9) -> Moonfire on target
  [9835] = { { id = 9835, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 10) -> Moonfire on target
  [26987] = { { id = 26987, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 11) -> Moonfire on target
  [26988] = { { id = 26988, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 12) -> Moonfire on target
  [48462] = { { id = 48462, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 13) -> Moonfire on target
  [48463] = { { id = 48463, unit = "target", name = "Moonfire" } },  -- Moonfire (Rank 14) -> Moonfire on target
  [9005] = { { id = 9005, unit = "target", name = "Pounce" }, { id = 9007, unit = "target", name = "Pounce Bleed" } },  -- Pounce (Rank 1) -> Pounce on target, Pounce Bleed via trigger on target
  [9823] = { { id = 9823, unit = "target", name = "Pounce" }, { id = 9824, unit = "target", name = "Pounce Bleed" } },  -- Pounce (Rank 2) -> Pounce on target, Pounce Bleed via trigger on target
  [9827] = { { id = 9827, unit = "target", name = "Pounce" }, { id = 9826, unit = "target", name = "Pounce Bleed" } },  -- Pounce (Rank 3) -> Pounce on target, Pounce Bleed via trigger on target
  [27006] = { { id = 27006, unit = "target", name = "Pounce" }, { id = 27007, unit = "target", name = "Pounce Bleed" } },  -- Pounce (Rank 4) -> Pounce on target, Pounce Bleed via trigger on target
  [49803] = { { id = 49803, unit = "target", name = "Pounce" }, { id = 49804, unit = "target", name = "Pounce Bleed" } },  -- Pounce (Rank 5) -> Pounce on target, Pounce Bleed via trigger on target
  [9007] = { { id = 9007, unit = "target", name = "Pounce Bleed" } },  -- Pounce Bleed (Rank 1) -> Pounce Bleed on target
  [9824] = { { id = 9824, unit = "target", name = "Pounce Bleed" } },  -- Pounce Bleed (Rank 2) -> Pounce Bleed on target
  [9826] = { { id = 9826, unit = "target", name = "Pounce Bleed" } },  -- Pounce Bleed (Rank 3) -> Pounce Bleed on target
  [27007] = { { id = 27007, unit = "target", name = "Pounce Bleed" } },  -- Pounce Bleed (Rank 4) -> Pounce Bleed on target
  [49804] = { { id = 49804, unit = "target", name = "Pounce Bleed" } },  -- Pounce Bleed (Rank 5) -> Pounce Bleed on target
  [16857] = { { id = 16857, unit = "target", name = "Faerie Fire (Feral)" } },  -- Faerie Fire (Feral) -> Faerie Fire (Feral) on target
  [16979] = { { id = 19675, unit = "target", name = "Feral Charge Effect" }, { id = 45334, unit = "target", name = "Feral Charge Effect" } },  -- Feral Charge - Bear -> Feral Charge Effect via trigger on target, Feral Charge Effect via trigger on target
  [24858] = { { id = 24907, unit = "player", name = "Moonkin Aura" } },  -- Moonkin Form (Shapeshift) -> Moonkin Aura via trigger on player
  [33745] = { { id = 33745, unit = "target", name = "Lacerate" } },  -- Lacerate (Rank 1) -> Lacerate on target
  [48567] = { { id = 48567, unit = "target", name = "Lacerate" } },  -- Lacerate (Rank 2) -> Lacerate on target
  [48568] = { { id = 48568, unit = "target", name = "Lacerate" } },  -- Lacerate (Rank 3) -> Lacerate on target
  [33786] = { { id = 33786, unit = "target", name = "Cyclone" } },  -- Cyclone -> Cyclone on target
  [33876] = { { id = 33876, unit = "target", name = "Mangle (Cat)" } },  -- Mangle (Cat) (Rank 1) -> Mangle (Cat) on target
  [33982] = { { id = 33982, unit = "target", name = "Mangle (Cat)" } },  -- Mangle (Cat) (Rank 2) -> Mangle (Cat) on target
  [33983] = { { id = 33983, unit = "target", name = "Mangle (Cat)" } },  -- Mangle (Cat) (Rank 3) -> Mangle (Cat) on target
  [48565] = { { id = 48565, unit = "target", name = "Mangle (Cat)" } },  -- Mangle (Cat) (Rank 4) -> Mangle (Cat) on target
  [48566] = { { id = 48566, unit = "target", name = "Mangle (Cat)" } },  -- Mangle (Cat) (Rank 5) -> Mangle (Cat) on target
  [33878] = { { id = 33878, unit = "target", name = "Mangle (Bear)" } },  -- Mangle (Bear) (Rank 1) -> Mangle (Bear) on target
  [33986] = { { id = 33986, unit = "target", name = "Mangle (Bear)" } },  -- Mangle (Bear) (Rank 2) -> Mangle (Bear) on target
  [33987] = { { id = 33987, unit = "target", name = "Mangle (Bear)" } },  -- Mangle (Bear) (Rank 3) -> Mangle (Bear) on target
  [48563] = { { id = 48563, unit = "target", name = "Mangle (Bear)" } },  -- Mangle (Bear) (Rank 4) -> Mangle (Bear) on target
  [48564] = { { id = 48564, unit = "target", name = "Mangle (Bear)" } },  -- Mangle (Bear) (Rank 5) -> Mangle (Bear) on target
  [33917] = { { id = 33878, unit = "target", name = "Mangle (Bear)" }, { id = 33876, unit = "target", name = "Mangle (Cat)" } },  -- Mangle (Rank 1) -> Mangle (Bear) via trigger on target, Mangle (Cat) via trigger on target
  [49376] = { { id = 50259, unit = "target", name = "Dazed" } },  -- Feral Charge - Cat -> Dazed via trigger on target

  -- HUNTER
  [1130] = { { id = 1130, unit = "target", name = "Hunter's Mark" } },  -- Hunter's Mark (Rank 1) -> Hunter's Mark on target
  [14323] = { { id = 14323, unit = "target", name = "Hunter's Mark" } },  -- Hunter's Mark (Rank 2) -> Hunter's Mark on target
  [14324] = { { id = 14324, unit = "target", name = "Hunter's Mark" } },  -- Hunter's Mark (Rank 3) -> Hunter's Mark on target
  [14325] = { { id = 14325, unit = "target", name = "Hunter's Mark" } },  -- Hunter's Mark (Rank 4) -> Hunter's Mark on target
  [53338] = { { id = 53338, unit = "target", name = "Hunter's Mark" } },  -- Hunter's Mark (Rank 5) -> Hunter's Mark on target
  [1462] = { { id = 1462, unit = "target", name = "Beast Lore" } },  -- Beast Lore -> Beast Lore on target
  [1513] = { { id = 1513, unit = "target", name = "Scare Beast" } },  -- Scare Beast (Rank 1) -> Scare Beast on target
  [14326] = { { id = 14326, unit = "target", name = "Scare Beast" } },  -- Scare Beast (Rank 2) -> Scare Beast on target
  [14327] = { { id = 14327, unit = "target", name = "Scare Beast" } },  -- Scare Beast (Rank 3) -> Scare Beast on target
  [1978] = { { id = 1978, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 1) -> Serpent Sting on target
  [13549] = { { id = 13549, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 2) -> Serpent Sting on target
  [13550] = { { id = 13550, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 3) -> Serpent Sting on target
  [13551] = { { id = 13551, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 4) -> Serpent Sting on target
  [13552] = { { id = 13552, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 5) -> Serpent Sting on target
  [13553] = { { id = 13553, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 6) -> Serpent Sting on target
  [13554] = { { id = 13554, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 7) -> Serpent Sting on target
  [13555] = { { id = 13555, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 8) -> Serpent Sting on target
  [25295] = { { id = 25295, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 9) -> Serpent Sting on target
  [27016] = { { id = 27016, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 10) -> Serpent Sting on target
  [49000] = { { id = 49000, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 11) -> Serpent Sting on target
  [49001] = { { id = 49001, unit = "target", name = "Serpent Sting" } },  -- Serpent Sting (Rank 12) -> Serpent Sting on target
  [2974] = { { id = 2974, unit = "target", name = "Wing Clip" } },  -- Wing Clip -> Wing Clip on target
  [3034] = { { id = 3034, unit = "target", name = "Viper Sting" } },  -- Viper Sting -> Viper Sting on target
  [3043] = { { id = 3043, unit = "target", name = "Scorpid Sting" } },  -- Scorpid Sting -> Scorpid Sting on target
  [3674] = { { id = 3674, unit = "target", name = "Black Arrow" } },  -- Black Arrow (Rank 1) -> Black Arrow on target
  [63668] = { { id = 63668, unit = "target", name = "Black Arrow" } },  -- Black Arrow (Rank 2) -> Black Arrow on target
  [63669] = { { id = 63669, unit = "target", name = "Black Arrow" } },  -- Black Arrow (Rank 3) -> Black Arrow on target
  [63670] = { { id = 63670, unit = "target", name = "Black Arrow" } },  -- Black Arrow (Rank 4) -> Black Arrow on target
  [63671] = { { id = 63671, unit = "target", name = "Black Arrow" } },  -- Black Arrow (Rank 5) -> Black Arrow on target
  [63672] = { { id = 63672, unit = "target", name = "Black Arrow" } },  -- Black Arrow (Rank 6) -> Black Arrow on target
  [5116] = { { id = 5116, unit = "target", name = "Concussive Shot" } },  -- Concussive Shot -> Concussive Shot on target
  [13159] = { { id = 15571, unit = "player", name = "Dazed" } },  -- Aspect of the Pack -> Dazed via trigger on player
  [13797] = { { id = 13797, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 1) -> Immolation Trap on target
  [14298] = { { id = 14298, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 2) -> Immolation Trap on target
  [14299] = { { id = 14299, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 3) -> Immolation Trap on target
  [14300] = { { id = 14300, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 4) -> Immolation Trap on target
  [14301] = { { id = 14301, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 5) -> Immolation Trap on target
  [27024] = { { id = 27024, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 6) -> Immolation Trap on target
  [49053] = { { id = 49053, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 7) -> Immolation Trap on target
  [49054] = { { id = 49054, unit = "target", name = "Immolation Trap" } },  -- Immolation Trap (Rank 8) -> Immolation Trap on target
  [19306] = { { id = 19306, unit = "target", name = "Counterattack" } },  -- Counterattack (Rank 1) -> Counterattack on target
  [20909] = { { id = 20909, unit = "target", name = "Counterattack" } },  -- Counterattack (Rank 2) -> Counterattack on target
  [20910] = { { id = 20910, unit = "target", name = "Counterattack" } },  -- Counterattack (Rank 3) -> Counterattack on target
  [27067] = { { id = 27067, unit = "target", name = "Counterattack" } },  -- Counterattack (Rank 4) -> Counterattack on target
  [48998] = { { id = 48998, unit = "target", name = "Counterattack" } },  -- Counterattack (Rank 5) -> Counterattack on target
  [48999] = { { id = 48999, unit = "target", name = "Counterattack" } },  -- Counterattack (Rank 6) -> Counterattack on target
  [19386] = { { id = 19386, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 1) -> Wyvern Sting on target
  [24131] = { { id = 24131, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 1) -> Wyvern Sting on target
  [24132] = { { id = 24132, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 2) -> Wyvern Sting on target
  [24133] = { { id = 24133, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 3) -> Wyvern Sting on target
  [24134] = { { id = 24134, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 2) -> Wyvern Sting on target
  [24135] = { { id = 24135, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 3) -> Wyvern Sting on target
  [27068] = { { id = 27068, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 4) -> Wyvern Sting on target
  [27069] = { { id = 27069, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 4) -> Wyvern Sting on target
  [49009] = { { id = 49009, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 5) -> Wyvern Sting on target
  [49010] = { { id = 49010, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 6) -> Wyvern Sting on target
  [49011] = { { id = 49011, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 5) -> Wyvern Sting on target
  [49012] = { { id = 49012, unit = "target", name = "Wyvern Sting" } },  -- Wyvern Sting (Rank 6) -> Wyvern Sting on target
  [19434] = { { id = 19434, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 1) -> Aimed Shot on target
  [20900] = { { id = 20900, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 2) -> Aimed Shot on target
  [20901] = { { id = 20901, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 3) -> Aimed Shot on target
  [20902] = { { id = 20902, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 4) -> Aimed Shot on target
  [20903] = { { id = 20903, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 5) -> Aimed Shot on target
  [20904] = { { id = 20904, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 6) -> Aimed Shot on target
  [27065] = { { id = 27065, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 7) -> Aimed Shot on target
  [49049] = { { id = 49049, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 8) -> Aimed Shot on target
  [49050] = { { id = 49050, unit = "target", name = "Aimed Shot" } },  -- Aimed Shot (Rank 9) -> Aimed Shot on target
  [19503] = { { id = 19503, unit = "target", name = "Scatter Shot" } },  -- Scatter Shot -> Scatter Shot on target
  [20736] = { { id = 20736, unit = "target", name = "Distracting Shot" } },  -- Distracting Shot (Rank 1) -> Distracting Shot on target
  [34490] = { { id = 34490, unit = "target", name = "Silencing Shot" } },  -- Silencing Shot -> Silencing Shot on target
  [35101] = { { id = 35101, unit = "target", name = "Concussive Barrage" } },  -- Concussive Barrage -> Concussive Barrage on target
  [53301] = { { id = 53301, unit = "target", name = "Explosive Shot" } },  -- Explosive Shot (Rank 1) -> Explosive Shot on target
  [60051] = { { id = 60051, unit = "target", name = "Explosive Shot" } },  -- Explosive Shot (Rank 2) -> Explosive Shot on target
  [60052] = { { id = 60052, unit = "target", name = "Explosive Shot" } },  -- Explosive Shot (Rank 3) -> Explosive Shot on target
  [60053] = { { id = 60053, unit = "target", name = "Explosive Shot" } },  -- Explosive Shot (Rank 4) -> Explosive Shot on target
  [60210] = { { id = 60210, unit = "target", name = "Freezing Arrow Effect" } },  -- Freezing Arrow Effect (Rank 1) -> Freezing Arrow Effect on target

  -- MAGE
  [116] = { { id = 116, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 1) -> Frostbolt on target
  [205] = { { id = 205, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 2) -> Frostbolt on target
  [837] = { { id = 837, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 3) -> Frostbolt on target
  [7322] = { { id = 7322, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 4) -> Frostbolt on target
  [8406] = { { id = 8406, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 5) -> Frostbolt on target
  [8407] = { { id = 8407, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 6) -> Frostbolt on target
  [8408] = { { id = 8408, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 7) -> Frostbolt on target
  [10179] = { { id = 10179, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 8) -> Frostbolt on target
  [10180] = { { id = 10180, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 9) -> Frostbolt on target
  [10181] = { { id = 10181, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 10) -> Frostbolt on target
  [25304] = { { id = 25304, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 11) -> Frostbolt on target
  [27071] = { { id = 27071, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 12) -> Frostbolt on target
  [27072] = { { id = 27072, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 13) -> Frostbolt on target
  [38697] = { { id = 38697, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 14) -> Frostbolt on target
  [42841] = { { id = 42841, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 15) -> Frostbolt on target
  [42842] = { { id = 42842, unit = "target", name = "Frostbolt" } },  -- Frostbolt (Rank 16) -> Frostbolt on target
  [118] = { { id = 118, unit = "target", name = "Polymorph" } },  -- Polymorph (Rank 1) -> Polymorph on target
  [12824] = { { id = 12824, unit = "target", name = "Polymorph" } },  -- Polymorph (Rank 2) -> Polymorph on target
  [12825] = { { id = 12825, unit = "target", name = "Polymorph" } },  -- Polymorph (Rank 3) -> Polymorph on target
  [12826] = { { id = 12826, unit = "target", name = "Polymorph" } },  -- Polymorph (Rank 4) -> Polymorph on target
  [28271] = { { id = 28271, unit = "target", name = "Polymorph" } },  -- Polymorph (Turtle) -> Polymorph on target
  [28272] = { { id = 28272, unit = "target", name = "Polymorph" } },  -- Polymorph (Pig) -> Polymorph on target
  [61025] = { { id = 61025, unit = "target", name = "Polymorph" } },  -- Polymorph (Serpent) -> Polymorph on target
  [61305] = { { id = 61305, unit = "target", name = "Polymorph" } },  -- Polymorph (Black Cat) -> Polymorph on target
  [61721] = { { id = 61721, unit = "target", name = "Polymorph" } },  -- Polymorph (Rabbit) -> Polymorph on target
  [61780] = { { id = 61780, unit = "target", name = "Polymorph" } },  -- Polymorph (Turkey) -> Polymorph on target
  [133] = { { id = 133, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 1) -> Fireball on target, Fireball! proc on player
  [143] = { { id = 143, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 2) -> Fireball on target, Fireball! proc on player
  [145] = { { id = 145, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 3) -> Fireball on target, Fireball! proc on player
  [3140] = { { id = 3140, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 4) -> Fireball on target, Fireball! proc on player
  [8400] = { { id = 8400, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 5) -> Fireball on target, Fireball! proc on player
  [8401] = { { id = 8401, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 6) -> Fireball on target, Fireball! proc on player
  [8402] = { { id = 8402, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 7) -> Fireball on target, Fireball! proc on player
  [10148] = { { id = 10148, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 8) -> Fireball on target, Fireball! proc on player
  [10149] = { { id = 10149, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 9) -> Fireball on target, Fireball! proc on player
  [10150] = { { id = 10150, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 10) -> Fireball on target, Fireball! proc on player
  [10151] = { { id = 10151, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 11) -> Fireball on target, Fireball! proc on player
  [25306] = { { id = 25306, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 12) -> Fireball on target, Fireball! proc on player
  [27070] = { { id = 27070, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 13) -> Fireball on target, Fireball! proc on player
  [38692] = { { id = 38692, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 14) -> Fireball on target, Fireball! proc on player
  [42832] = { { id = 42832, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 15) -> Fireball on target, Fireball! proc on player
  [42833] = { { id = 42833, unit = "target", name = "Fireball" }, { id = 57761, unit = "player", name = "Fireball!" } },  -- Fireball (Rank 16) -> Fireball on target, Fireball! proc on player
  [11366] = { { id = 11366, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 1) -> Pyroblast on target
  [12505] = { { id = 12505, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 2) -> Pyroblast on target
  [12522] = { { id = 12522, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 3) -> Pyroblast on target
  [12523] = { { id = 12523, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 4) -> Pyroblast on target
  [12524] = { { id = 12524, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 5) -> Pyroblast on target
  [12525] = { { id = 12525, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 6) -> Pyroblast on target
  [12526] = { { id = 12526, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 7) -> Pyroblast on target
  [18809] = { { id = 18809, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 8) -> Pyroblast on target
  [27132] = { { id = 27132, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 9) -> Pyroblast on target
  [33938] = { { id = 33938, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 10) -> Pyroblast on target
  [42890] = { { id = 42890, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 11) -> Pyroblast on target
  [42891] = { { id = 42891, unit = "target", name = "Pyroblast" } },  -- Pyroblast (Rank 12) -> Pyroblast on target
  [12355] = { { id = 12355, unit = "target", name = "Impact" } },  -- Impact (Rank 1) -> Impact on target
  [12484] = { { id = 12484, unit = "target", name = "Chilled" } },  -- Chilled (Rank 1) -> Chilled on target
  [12485] = { { id = 12485, unit = "target", name = "Chilled" } },  -- Chilled (Rank 2) -> Chilled on target
  [12486] = { { id = 12486, unit = "target", name = "Chilled" } },  -- Chilled (Rank 3) -> Chilled on target
  [12494] = { { id = 12494, unit = "target", name = "Frostbite" } },  -- Frostbite -> Frostbite on target
  [12654] = { { id = 12654, unit = "target", name = "Ignite" } },  -- Ignite -> Ignite on target
  [22959] = { { id = 22959, unit = "target", name = "Improved Scorch" } },  -- Improved Scorch -> Improved Scorch on target
  [31589] = { { id = 31589, unit = "target", name = "Slow" } },  -- Slow -> Slow on target
  [44457] = { { id = 44457, unit = "target", name = "Living Bomb" } },  -- Living Bomb (Rank 1) -> Living Bomb on target
  [55359] = { { id = 55359, unit = "target", name = "Living Bomb" } },  -- Living Bomb (Rank 2) -> Living Bomb on target
  [55360] = { { id = 55360, unit = "target", name = "Living Bomb" } },  -- Living Bomb (Rank 3) -> Living Bomb on target
  [44572] = { { id = 44572, unit = "target", name = "Deep Freeze" } },  -- Deep Freeze -> Deep Freeze on target
  [44614] = { { id = 44614, unit = "target", name = "Frostfire Bolt" } },  -- Frostfire Bolt (Rank 1) -> Frostfire Bolt on target
  [47610] = { { id = 47610, unit = "target", name = "Frostfire Bolt" } },  -- Frostfire Bolt (Rank 2) -> Frostfire Bolt on target
  [54648] = { { id = 54648, unit = "target", name = "Focus Magic" } },  -- Focus Magic -> Focus Magic on target

  -- PALADIN
  [67] = { { id = 67, unit = "target", name = "Vindication" } },  -- Vindication (Rank 1) -> Vindication on target
  [26017] = { { id = 26017, unit = "target", name = "Vindication" } },  -- Vindication (Rank 2) -> Vindication on target
  [853] = { { id = 853, unit = "target", name = "Hammer of Justice" } },  -- Hammer of Justice (Rank 1) -> Hammer of Justice on target
  [5588] = { { id = 5588, unit = "target", name = "Hammer of Justice" } },  -- Hammer of Justice (Rank 2) -> Hammer of Justice on target
  [5589] = { { id = 5589, unit = "target", name = "Hammer of Justice" } },  -- Hammer of Justice (Rank 3) -> Hammer of Justice on target
  [10308] = { { id = 10308, unit = "target", name = "Hammer of Justice" } },  -- Hammer of Justice (Rank 4) -> Hammer of Justice on target
  [10326] = { { id = 10326, unit = "target", name = "Turn Evil" } },  -- Turn Evil -> Turn Evil on target
  [20066] = { { id = 20066, unit = "target", name = "Repentance" } },  -- Repentance -> Repentance on target
  [20184] = { { id = 20184, unit = "target", name = "Judgement of Justice" } },  -- Judgement of Justice -> Judgement of Justice on target
  [20185] = { { id = 20185, unit = "target", name = "Judgement of Light" } },  -- Judgement of Light (Rank 1) -> Judgement of Light on target
  [20186] = { { id = 20186, unit = "target", name = "Judgement of Wisdom" } },  -- Judgement of Wisdom (Rank 1) -> Judgement of Wisdom on target
  [31803] = { { id = 31803, unit = "target", name = "Holy Vengeance" } },  -- Holy Vengeance (Rank 1) -> Holy Vengeance on target
  [31935] = { { id = 31935, unit = "target", name = "Avenger's Shield" } },  -- Avenger's Shield (Rank 1) -> Avenger's Shield on target
  [32699] = { { id = 32699, unit = "target", name = "Avenger's Shield" } },  -- Avenger's Shield (Rank 2) -> Avenger's Shield on target
  [32700] = { { id = 32700, unit = "target", name = "Avenger's Shield" } },  -- Avenger's Shield (Rank 3) -> Avenger's Shield on target
  [48826] = { { id = 48826, unit = "target", name = "Avenger's Shield" } },  -- Avenger's Shield (Rank 4) -> Avenger's Shield on target
  [48827] = { { id = 48827, unit = "target", name = "Avenger's Shield" } },  -- Avenger's Shield (Rank 5) -> Avenger's Shield on target
  [53742] = { { id = 53742, unit = "target", name = "Blood Corruption" } },  -- Blood Corruption (Rank 1) -> Blood Corruption on target
  [62124] = { { id = 62124, unit = "target", name = "Hand of Reckoning" } },  -- Hand of Reckoning -> Hand of Reckoning on target

  -- PRIEST
  [453] = { { id = 453, unit = "target", name = "Mind Soothe" } },  -- Mind Soothe -> Mind Soothe on target
  [589] = { { id = 589, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 1) -> Shadow Word: Pain on target
  [594] = { { id = 594, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 2) -> Shadow Word: Pain on target
  [970] = { { id = 970, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 3) -> Shadow Word: Pain on target
  [992] = { { id = 992, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 4) -> Shadow Word: Pain on target
  [2767] = { { id = 2767, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 5) -> Shadow Word: Pain on target
  [10892] = { { id = 10892, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 6) -> Shadow Word: Pain on target
  [10893] = { { id = 10893, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 7) -> Shadow Word: Pain on target
  [10894] = { { id = 10894, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 8) -> Shadow Word: Pain on target
  [25367] = { { id = 25367, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 9) -> Shadow Word: Pain on target
  [25368] = { { id = 25368, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 10) -> Shadow Word: Pain on target
  [48124] = { { id = 48124, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 11) -> Shadow Word: Pain on target
  [48125] = { { id = 48125, unit = "target", name = "Shadow Word: Pain" } },  -- Shadow Word: Pain (Rank 12) -> Shadow Word: Pain on target
  [2944] = { { id = 2944, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 1) -> Devouring Plague on target
  [19276] = { { id = 19276, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 2) -> Devouring Plague on target
  [19277] = { { id = 19277, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 3) -> Devouring Plague on target
  [19278] = { { id = 19278, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 4) -> Devouring Plague on target
  [19279] = { { id = 19279, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 5) -> Devouring Plague on target
  [19280] = { { id = 19280, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 6) -> Devouring Plague on target
  [25467] = { { id = 25467, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 7) -> Devouring Plague on target
  [48299] = { { id = 48299, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 8) -> Devouring Plague on target
  [48300] = { { id = 48300, unit = "target", name = "Devouring Plague" } },  -- Devouring Plague (Rank 9) -> Devouring Plague on target
  [9484] = { { id = 9484, unit = "target", name = "Shackle Undead" } },  -- Shackle Undead (Rank 1) -> Shackle Undead on target
  [9485] = { { id = 9485, unit = "target", name = "Shackle Undead" } },  -- Shackle Undead (Rank 2) -> Shackle Undead on target
  [10955] = { { id = 10955, unit = "target", name = "Shackle Undead" } },  -- Shackle Undead (Rank 3) -> Shackle Undead on target
  [14914] = { { id = 14914, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 1) -> Holy Fire on target
  [15261] = { { id = 15261, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 8) -> Holy Fire on target
  [15262] = { { id = 15262, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 2) -> Holy Fire on target
  [15263] = { { id = 15263, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 3) -> Holy Fire on target
  [15264] = { { id = 15264, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 4) -> Holy Fire on target
  [15265] = { { id = 15265, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 5) -> Holy Fire on target
  [15266] = { { id = 15266, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 6) -> Holy Fire on target
  [15267] = { { id = 15267, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 7) -> Holy Fire on target
  [25384] = { { id = 25384, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 9) -> Holy Fire on target
  [48134] = { { id = 48134, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 10) -> Holy Fire on target
  [48135] = { { id = 48135, unit = "target", name = "Holy Fire" } },  -- Holy Fire (Rank 11) -> Holy Fire on target
  [15487] = { { id = 15487, unit = "target", name = "Silence" } },  -- Silence -> Silence on target
  [33196] = { { id = 33196, unit = "target", name = "Misery" } },  -- Misery (Rank 1) -> Misery on target
  [33197] = { { id = 33197, unit = "target", name = "Misery" } },  -- Misery (Rank 2) -> Misery on target
  [33198] = { { id = 33198, unit = "target", name = "Misery" } },  -- Misery (Rank 3) -> Misery on target
  [34914] = { { id = 34914, unit = "target", name = "Vampiric Touch" } },  -- Vampiric Touch (Rank 1) -> Vampiric Touch on target
  [34916] = { { id = 34916, unit = "target", name = "Vampiric Touch" } },  -- Vampiric Touch (Rank 2) -> Vampiric Touch on target
  [34917] = { { id = 34917, unit = "target", name = "Vampiric Touch" } },  -- Vampiric Touch (Rank 3) -> Vampiric Touch on target
  [48159] = { { id = 48159, unit = "target", name = "Vampiric Touch" } },  -- Vampiric Touch (Rank 4) -> Vampiric Touch on target
  [48160] = { { id = 48160, unit = "target", name = "Vampiric Touch" } },  -- Vampiric Touch (Rank 5) -> Vampiric Touch on target
  [64044] = { { id = 64044, unit = "target", name = "Psychic Horror" }, { id = 64058, unit = "target", name = "Psychic Horror" } },  -- Psychic Horror -> Psychic Horror on target, Psychic Horror via trigger on target
  [64058] = { { id = 64058, unit = "target", name = "Psychic Horror" } },  -- Psychic Horror -> Psychic Horror on target

  -- ROGUE
  [703] = { { id = 703, unit = "target", name = "Garrote" } },  -- Garrote (Rank 1) -> Garrote on target
  [8631] = { { id = 8631, unit = "target", name = "Garrote" } },  -- Garrote (Rank 2) -> Garrote on target
  [8632] = { { id = 8632, unit = "target", name = "Garrote" } },  -- Garrote (Rank 3) -> Garrote on target
  [8633] = { { id = 8633, unit = "target", name = "Garrote" } },  -- Garrote (Rank 4) -> Garrote on target
  [11289] = { { id = 11289, unit = "target", name = "Garrote" } },  -- Garrote (Rank 5) -> Garrote on target
  [11290] = { { id = 11290, unit = "target", name = "Garrote" } },  -- Garrote (Rank 6) -> Garrote on target
  [26839] = { { id = 26839, unit = "target", name = "Garrote" }, { id = 1330, unit = "target", name = "Garrote - Silence" } },  -- Garrote (Rank 7) -> Garrote on target, Garrote - Silence via trigger on target
  [26884] = { { id = 26884, unit = "target", name = "Garrote" }, { id = 1330, unit = "target", name = "Garrote - Silence" } },  -- Garrote (Rank 8) -> Garrote on target, Garrote - Silence via trigger on target
  [48675] = { { id = 48675, unit = "target", name = "Garrote" }, { id = 1330, unit = "target", name = "Garrote - Silence" } },  -- Garrote (Rank 9) -> Garrote on target, Garrote - Silence via trigger on target
  [48676] = { { id = 48676, unit = "target", name = "Garrote" }, { id = 1330, unit = "target", name = "Garrote - Silence" } },  -- Garrote (Rank 10) -> Garrote on target, Garrote - Silence via trigger on target
  [1776] = { { id = 1776, unit = "target", name = "Gouge" } },  -- Gouge -> Gouge on target
  [1833] = { { id = 1833, unit = "target", name = "Cheap Shot" } },  -- Cheap Shot -> Cheap Shot on target
  [1943] = { { id = 1943, unit = "target", name = "Rupture" } },  -- Rupture (Rank 1) -> Rupture on target
  [8639] = { { id = 8639, unit = "target", name = "Rupture" } },  -- Rupture (Rank 2) -> Rupture on target
  [8640] = { { id = 8640, unit = "target", name = "Rupture" } },  -- Rupture (Rank 3) -> Rupture on target
  [11273] = { { id = 11273, unit = "target", name = "Rupture" } },  -- Rupture (Rank 4) -> Rupture on target
  [11274] = { { id = 11274, unit = "target", name = "Rupture" } },  -- Rupture (Rank 5) -> Rupture on target
  [11275] = { { id = 11275, unit = "target", name = "Rupture" } },  -- Rupture (Rank 6) -> Rupture on target
  [26867] = { { id = 26867, unit = "target", name = "Rupture" } },  -- Rupture (Rank 7) -> Rupture on target
  [48671] = { { id = 48671, unit = "target", name = "Rupture" } },  -- Rupture (Rank 8) -> Rupture on target
  [48672] = { { id = 48672, unit = "target", name = "Rupture" } },  -- Rupture (Rank 9) -> Rupture on target
  [2070] = { { id = 2070, unit = "target", name = "Sap" } },  -- Sap (Rank 2) -> Sap on target
  [6770] = { { id = 6770, unit = "target", name = "Sap" } },  -- Sap (Rank 1) -> Sap on target
  [11297] = { { id = 11297, unit = "target", name = "Sap" } },  -- Sap (Rank 3) -> Sap on target
  [51724] = { { id = 51724, unit = "target", name = "Sap" } },  -- Sap (Rank 4) -> Sap on target
  [2094] = { { id = 2094, unit = "target", name = "Blind" } },  -- Blind -> Blind on target
  [8643] = { { id = 8643, unit = "target", name = "Kidney Shot" } },  -- Kidney Shot (Rank 2) -> Kidney Shot on target
  [14251] = { { id = 14251, unit = "target", name = "Riposte" } },  -- Riposte -> Riposte on target
  [16511] = { { id = 16511, unit = "target", name = "Hemorrhage" } },  -- Hemorrhage (Rank 1) -> Hemorrhage on target
  [17347] = { { id = 17347, unit = "target", name = "Hemorrhage" } },  -- Hemorrhage (Rank 2) -> Hemorrhage on target
  [17348] = { { id = 17348, unit = "target", name = "Hemorrhage" } },  -- Hemorrhage (Rank 3) -> Hemorrhage on target
  [26864] = { { id = 26864, unit = "target", name = "Hemorrhage" } },  -- Hemorrhage (Rank 4) -> Hemorrhage on target
  [48660] = { { id = 48660, unit = "target", name = "Hemorrhage" } },  -- Hemorrhage (Rank 5) -> Hemorrhage on target
  [26679] = { { id = 26679, unit = "target", name = "Deadly Throw" } },  -- Deadly Throw (Rank 1) -> Deadly Throw on target
  [48673] = { { id = 48673, unit = "target", name = "Deadly Throw" } },  -- Deadly Throw (Rank 2) -> Deadly Throw on target
  [48674] = { { id = 48674, unit = "target", name = "Deadly Throw" } },  -- Deadly Throw (Rank 3) -> Deadly Throw on target
  [31125] = { { id = 31125, unit = "target", name = "Blade Twisting" } },  -- Blade Twisting -> Blade Twisting on target
  [51693] = { { id = 51693, unit = "target", name = "Waylay" } },  -- Waylay -> Waylay on target
  [51722] = { { id = 51722, unit = "target", name = "Dismantle" } },  -- Dismantle -> Dismantle on target

  -- SHAMAN
  [974] = { { id = 974, unit = "friend", name = "Earth Shield" } },  -- Earth Shield (Rank 1) -> Earth Shield on friend
  [32593] = { { id = 32593, unit = "friend", name = "Earth Shield" } },  -- Earth Shield (Rank 2) -> Earth Shield on friend
  [32594] = { { id = 32594, unit = "friend", name = "Earth Shield" } },  -- Earth Shield (Rank 3) -> Earth Shield on friend
  [49283] = { { id = 49283, unit = "friend", name = "Earth Shield" } },  -- Earth Shield (Rank 4) -> Earth Shield on friend
  [49284] = { { id = 49284, unit = "friend", name = "Earth Shield" } },  -- Earth Shield (Rank 5) -> Earth Shield on friend
  [8042] = { { id = 8042, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 1) -> Earth Shock on target
  [8044] = { { id = 8044, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 2) -> Earth Shock on target
  [8045] = { { id = 8045, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 3) -> Earth Shock on target
  [8046] = { { id = 8046, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 4) -> Earth Shock on target
  [10412] = { { id = 10412, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 5) -> Earth Shock on target
  [10413] = { { id = 10413, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 6) -> Earth Shock on target
  [10414] = { { id = 10414, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 7) -> Earth Shock on target
  [25454] = { { id = 25454, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 8) -> Earth Shock on target
  [49230] = { { id = 49230, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 9) -> Earth Shock on target
  [49231] = { { id = 49231, unit = "target", name = "Earth Shock" } },  -- Earth Shock (Rank 10) -> Earth Shock on target
  [8050] = { { id = 8050, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 1) -> Flame Shock on target
  [8052] = { { id = 8052, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 2) -> Flame Shock on target
  [8053] = { { id = 8053, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 3) -> Flame Shock on target
  [10447] = { { id = 10447, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 4) -> Flame Shock on target
  [10448] = { { id = 10448, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 5) -> Flame Shock on target
  [25457] = { { id = 25457, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 7) -> Flame Shock on target
  [29228] = { { id = 29228, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 6) -> Flame Shock on target
  [49232] = { { id = 49232, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 8) -> Flame Shock on target
  [49233] = { { id = 49233, unit = "target", name = "Flame Shock" } },  -- Flame Shock (Rank 9) -> Flame Shock on target
  [8056] = { { id = 8056, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 1) -> Frost Shock on target
  [8058] = { { id = 8058, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 2) -> Frost Shock on target
  [10472] = { { id = 10472, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 3) -> Frost Shock on target
  [10473] = { { id = 10473, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 4) -> Frost Shock on target
  [25464] = { { id = 25464, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 5) -> Frost Shock on target
  [49235] = { { id = 49235, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 6) -> Frost Shock on target
  [49236] = { { id = 49236, unit = "target", name = "Frost Shock" } },  -- Frost Shock (Rank 7) -> Frost Shock on target
  [17364] = { { id = 17364, unit = "target", name = "Stormstrike" } },  -- Stormstrike -> Stormstrike on target
  [51514] = { { id = 51514, unit = "target", name = "Hex" } },  -- Hex -> Hex on target
  [63685] = { { id = 63685, unit = "target", name = "Freeze" } },  -- Freeze -> Freeze on target

  -- WARLOCK
  [172] = { { id = 172, unit = "target", name = "Corruption" } },  -- Corruption (Rank 1) -> Corruption on target
  [6222] = { { id = 6222, unit = "target", name = "Corruption" } },  -- Corruption (Rank 2) -> Corruption on target
  [6223] = { { id = 6223, unit = "target", name = "Corruption" } },  -- Corruption (Rank 3) -> Corruption on target
  [7648] = { { id = 7648, unit = "target", name = "Corruption" } },  -- Corruption (Rank 4) -> Corruption on target
  [11671] = { { id = 11671, unit = "target", name = "Corruption" } },  -- Corruption (Rank 5) -> Corruption on target
  [11672] = { { id = 11672, unit = "target", name = "Corruption" } },  -- Corruption (Rank 6) -> Corruption on target
  [25311] = { { id = 25311, unit = "target", name = "Corruption" } },  -- Corruption (Rank 7) -> Corruption on target
  [27216] = { { id = 27216, unit = "target", name = "Corruption" } },  -- Corruption (Rank 8) -> Corruption on target
  [47812] = { { id = 47812, unit = "target", name = "Corruption" } },  -- Corruption (Rank 9) -> Corruption on target
  [47813] = { { id = 47813, unit = "target", name = "Corruption" } },  -- Corruption (Rank 10) -> Corruption on target
  [348] = { { id = 348, unit = "target", name = "Immolate" } },  -- Immolate (Rank 1) -> Immolate on target
  [707] = { { id = 707, unit = "target", name = "Immolate" } },  -- Immolate (Rank 2) -> Immolate on target
  [1094] = { { id = 1094, unit = "target", name = "Immolate" } },  -- Immolate (Rank 3) -> Immolate on target
  [2941] = { { id = 2941, unit = "target", name = "Immolate" } },  -- Immolate (Rank 4) -> Immolate on target
  [11665] = { { id = 11665, unit = "target", name = "Immolate" } },  -- Immolate (Rank 5) -> Immolate on target
  [11667] = { { id = 11667, unit = "target", name = "Immolate" } },  -- Immolate (Rank 6) -> Immolate on target
  [11668] = { { id = 11668, unit = "target", name = "Immolate" } },  -- Immolate (Rank 7) -> Immolate on target
  [25309] = { { id = 25309, unit = "target", name = "Immolate" } },  -- Immolate (Rank 8) -> Immolate on target
  [27215] = { { id = 27215, unit = "target", name = "Immolate" } },  -- Immolate (Rank 9) -> Immolate on target
  [47810] = { { id = 47810, unit = "target", name = "Immolate" } },  -- Immolate (Rank 10) -> Immolate on target
  [47811] = { { id = 47811, unit = "target", name = "Immolate" } },  -- Immolate (Rank 11) -> Immolate on target
  [603] = { { id = 603, unit = "target", name = "Curse of Doom" } },  -- Curse of Doom (Rank 1) -> Curse of Doom on target
  [30910] = { { id = 30910, unit = "target", name = "Curse of Doom" } },  -- Curse of Doom (Rank 2) -> Curse of Doom on target
  [47867] = { { id = 47867, unit = "target", name = "Curse of Doom" } },  -- Curse of Doom (Rank 3) -> Curse of Doom on target
  [702] = { { id = 702, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 1) -> Curse of Weakness on target
  [1108] = { { id = 1108, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 2) -> Curse of Weakness on target
  [6205] = { { id = 6205, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 3) -> Curse of Weakness on target
  [7646] = { { id = 7646, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 4) -> Curse of Weakness on target
  [11707] = { { id = 11707, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 5) -> Curse of Weakness on target
  [11708] = { { id = 11708, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 6) -> Curse of Weakness on target
  [27224] = { { id = 27224, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 7) -> Curse of Weakness on target
  [30909] = { { id = 30909, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 8) -> Curse of Weakness on target
  [50511] = { { id = 50511, unit = "target", name = "Curse of Weakness" } },  -- Curse of Weakness (Rank 9) -> Curse of Weakness on target
  [710] = { { id = 710, unit = "target", name = "Banish" } },  -- Banish (Rank 1) -> Banish on target
  [18647] = { { id = 18647, unit = "target", name = "Banish" } },  -- Banish (Rank 2) -> Banish on target
  [980] = { { id = 980, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 1) -> Curse of Agony on target
  [1014] = { { id = 1014, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 2) -> Curse of Agony on target
  [6217] = { { id = 6217, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 3) -> Curse of Agony on target
  [11711] = { { id = 11711, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 4) -> Curse of Agony on target
  [11712] = { { id = 11712, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 5) -> Curse of Agony on target
  [11713] = { { id = 11713, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 6) -> Curse of Agony on target
  [27218] = { { id = 27218, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 7) -> Curse of Agony on target
  [47863] = { { id = 47863, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 8) -> Curse of Agony on target
  [47864] = { { id = 47864, unit = "target", name = "Curse of Agony" } },  -- Curse of Agony (Rank 9) -> Curse of Agony on target
  [1010] = { { id = 1010, unit = "target", name = "Curse of Idiocy" } },  -- Curse of Idiocy (Rank 1) -> Curse of Idiocy on target
  [1098] = { { id = 1098, unit = "target", name = "Enslave Demon" } },  -- Enslave Demon (Rank 1) -> Enslave Demon on target
  [11725] = { { id = 11725, unit = "target", name = "Enslave Demon" } },  -- Enslave Demon (Rank 2) -> Enslave Demon on target
  [11726] = { { id = 11726, unit = "target", name = "Enslave Demon" } },  -- Enslave Demon (Rank 3) -> Enslave Demon on target
  [61191] = { { id = 61191, unit = "target", name = "Enslave Demon" } },  -- Enslave Demon (Rank 4) -> Enslave Demon on target
  [1490] = { { id = 1490, unit = "target", name = "Curse of the Elements" } },  -- Curse of the Elements (Rank 1) -> Curse of the Elements on target
  [11721] = { { id = 11721, unit = "target", name = "Curse of the Elements" } },  -- Curse of the Elements (Rank 2) -> Curse of the Elements on target
  [11722] = { { id = 11722, unit = "target", name = "Curse of the Elements" } },  -- Curse of the Elements (Rank 3) -> Curse of the Elements on target
  [27228] = { { id = 27228, unit = "target", name = "Curse of the Elements" } },  -- Curse of the Elements (Rank 4) -> Curse of the Elements on target
  [47865] = { { id = 47865, unit = "target", name = "Curse of the Elements" } },  -- Curse of the Elements (Rank 5) -> Curse of the Elements on target
  [1714] = { { id = 1714, unit = "target", name = "Curse of Tongues" } },  -- Curse of Tongues (Rank 1) -> Curse of Tongues on target
  [11719] = { { id = 11719, unit = "target", name = "Curse of Tongues" } },  -- Curse of Tongues (Rank 2) -> Curse of Tongues on target
  [5782] = { { id = 5782, unit = "target", name = "Fear" } },  -- Fear (Rank 1) -> Fear on target
  [6213] = { { id = 6213, unit = "target", name = "Fear" } },  -- Fear (Rank 2) -> Fear on target
  [6215] = { { id = 6215, unit = "target", name = "Fear" } },  -- Fear (Rank 3) -> Fear on target
  [6353] = { { id = 61189, unit = "player", name = "Soul Fire!" } },  -- Soul Fire (Rank 1) -> Soul Fire! proc on player
  [17924] = { { id = 61189, unit = "player", name = "Soul Fire!" } },  -- Soul Fire (Rank 2) -> Soul Fire! proc on player
  [27211] = { { id = 61189, unit = "player", name = "Soul Fire!" } },  -- Soul Fire (Rank 3) -> Soul Fire! proc on player
  [30545] = { { id = 61189, unit = "player", name = "Soul Fire!" } },  -- Soul Fire (Rank 4) -> Soul Fire! proc on player
  [47824] = { { id = 61189, unit = "player", name = "Soul Fire!" } },  -- Soul Fire (Rank 5) -> Soul Fire! proc on player
  [47825] = { { id = 61189, unit = "player", name = "Soul Fire!" } },  -- Soul Fire (Rank 6) -> Soul Fire! proc on player
  [6789] = { { id = 6789, unit = "target", name = "Death Coil" } },  -- Death Coil (Rank 1) -> Death Coil on target
  [17925] = { { id = 17925, unit = "target", name = "Death Coil" } },  -- Death Coil (Rank 2) -> Death Coil on target
  [17926] = { { id = 17926, unit = "target", name = "Death Coil" } },  -- Death Coil (Rank 3) -> Death Coil on target
  [27223] = { { id = 27223, unit = "target", name = "Death Coil" } },  -- Death Coil (Rank 4) -> Death Coil on target
  [47859] = { { id = 47859, unit = "target", name = "Death Coil" } },  -- Death Coil (Rank 5) -> Death Coil on target
  [47860] = { { id = 47860, unit = "target", name = "Death Coil" } },  -- Death Coil (Rank 6) -> Death Coil on target
  [17877] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 1) -> Shadowburn via trigger on target
  [18867] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 2) -> Shadowburn via trigger on target
  [18868] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 3) -> Shadowburn via trigger on target
  [18869] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 4) -> Shadowburn via trigger on target
  [18870] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 5) -> Shadowburn via trigger on target
  [18871] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 6) -> Shadowburn via trigger on target
  [27263] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 7) -> Shadowburn via trigger on target
  [30546] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 8) -> Shadowburn via trigger on target
  [47826] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 9) -> Shadowburn via trigger on target
  [47827] = { { id = 29341, unit = "target", name = "Shadowburn" } },  -- Shadowburn (Rank 10) -> Shadowburn via trigger on target
  [17962] = { { id = 17962, unit = "target", name = "Conflagrate" } },  -- Conflagrate -> Conflagrate on target
  [18223] = { { id = 18223, unit = "target", name = "Curse of Exhaustion" } },  -- Curse of Exhaustion -> Curse of Exhaustion on target
  [27243] = { { id = 27243, unit = "target", name = "Seed of Corruption" } },  -- Seed of Corruption (Rank 1) -> Seed of Corruption on target
  [47835] = { { id = 47835, unit = "target", name = "Seed of Corruption" } },  -- Seed of Corruption (Rank 2) -> Seed of Corruption on target
  [47836] = { { id = 47836, unit = "target", name = "Seed of Corruption" } },  -- Seed of Corruption (Rank 3) -> Seed of Corruption on target
  [30108] = { { id = 30108, unit = "target", name = "Unstable Affliction" } },  -- Unstable Affliction (Rank 1) -> Unstable Affliction on target
  [30404] = { { id = 30404, unit = "target", name = "Unstable Affliction" } },  -- Unstable Affliction (Rank 2) -> Unstable Affliction on target
  [30405] = { { id = 30405, unit = "target", name = "Unstable Affliction" } },  -- Unstable Affliction (Rank 3) -> Unstable Affliction on target
  [31117] = { { id = 31117, unit = "target", name = "Unstable Affliction" } },  -- Unstable Affliction -> Unstable Affliction on target
  [47841] = { { id = 47841, unit = "target", name = "Unstable Affliction" } },  -- Unstable Affliction (Rank 4) -> Unstable Affliction on target
  [47843] = { { id = 47843, unit = "target", name = "Unstable Affliction" } },  -- Unstable Affliction (Rank 5) -> Unstable Affliction on target
  [32386] = { { id = 32386, unit = "target", name = "Shadow Embrace" } },  -- Shadow Embrace -> Shadow Embrace on target
  [32388] = { { id = 32388, unit = "target", name = "Shadow Embrace" } },  -- Shadow Embrace -> Shadow Embrace on target
  [32389] = { { id = 32389, unit = "target", name = "Shadow Embrace" } },  -- Shadow Embrace -> Shadow Embrace on target
  [32390] = { { id = 32390, unit = "target", name = "Shadow Embrace" } },  -- Shadow Embrace -> Shadow Embrace on target
  [32391] = { { id = 32391, unit = "target", name = "Shadow Embrace" } },  -- Shadow Embrace -> Shadow Embrace on target
  [47206] = { { id = 47206, unit = "target", name = "Atrocity" } },  -- Atrocity (Rank 1) -> Atrocity on target
  [48181] = { { id = 48181, unit = "target", name = "Haunt" } },  -- Haunt (Rank 1) -> Haunt on target
  [59161] = { { id = 59161, unit = "target", name = "Haunt" } },  -- Haunt (Rank 2) -> Haunt on target
  [59163] = { { id = 59163, unit = "target", name = "Haunt" } },  -- Haunt (Rank 3) -> Haunt on target
  [59164] = { { id = 59164, unit = "target", name = "Haunt" } },  -- Haunt (Rank 4) -> Haunt on target
  [54785] = { { id = 60995, unit = "target", name = "Demon Charge" } },  -- Demon Charge (Demon) -> Demon Charge via trigger on target
  [59673] = { { id = 59671, unit = "player", name = "Challenging Howl" }, { id = 50589, unit = "player", name = "Immolation Aura" } },  -- Metamorphosis -> Challenging Howl via trigger on player, Immolation Aura via trigger on player

  -- WARRIOR
  [72] = { { id = 29703, unit = "target", name = "Dazed" } },  -- Shield Bash -> Dazed via trigger on target
  [100] = { { id = 7922, unit = "target", name = "Charge Stun" } },  -- Charge (Rank 1) -> Charge Stun via trigger on target
  [6178] = { { id = 7922, unit = "target", name = "Charge Stun" } },  -- Charge (Rank 2) -> Charge Stun via trigger on target
  [11578] = { { id = 7922, unit = "target", name = "Charge Stun" } },  -- Charge (Rank 3) -> Charge Stun via trigger on target
  [355] = { { id = 355, unit = "target", name = "Taunt" } },  -- Taunt -> Taunt on target
  [676] = { { id = 676, unit = "target", name = "Disarm" } },  -- Disarm -> Disarm on target
  [694] = { { id = 694, unit = "target", name = "Mocking Blow" } },  -- Mocking Blow -> Mocking Blow on target
  [772] = { { id = 772, unit = "target", name = "Rend" } },  -- Rend (Rank 1) -> Rend on target
  [6546] = { { id = 6546, unit = "target", name = "Rend" } },  -- Rend (Rank 2) -> Rend on target
  [6547] = { { id = 6547, unit = "target", name = "Rend" } },  -- Rend (Rank 3) -> Rend on target
  [6548] = { { id = 6548, unit = "target", name = "Rend" } },  -- Rend (Rank 4) -> Rend on target
  [11572] = { { id = 11572, unit = "target", name = "Rend" } },  -- Rend (Rank 5) -> Rend on target
  [11573] = { { id = 11573, unit = "target", name = "Rend" } },  -- Rend (Rank 6) -> Rend on target
  [11574] = { { id = 11574, unit = "target", name = "Rend" } },  -- Rend (Rank 7) -> Rend on target
  [25208] = { { id = 25208, unit = "target", name = "Rend" } },  -- Rend (Rank 8) -> Rend on target
  [46845] = { { id = 46845, unit = "target", name = "Rend" } },  -- Rend (Rank 9) -> Rend on target
  [47465] = { { id = 47465, unit = "target", name = "Rend" } },  -- Rend (Rank 10) -> Rend on target
  [1464] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 1) -> Slam! proc on player
  [8820] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 2) -> Slam! proc on player
  [11604] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 3) -> Slam! proc on player
  [11605] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 4) -> Slam! proc on player
  [25241] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 5) -> Slam! proc on player
  [25242] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 6) -> Slam! proc on player
  [47474] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 7) -> Slam! proc on player
  [47475] = { { id = 46916, unit = "player", name = "Slam!" } },  -- Slam (Rank 8) -> Slam! proc on player
  [1715] = { { id = 1715, unit = "target", name = "Hamstring" } },  -- Hamstring -> Hamstring on target
  [5246] = { { id = 20511, unit = "target", name = "Intimidating Shout" } },  -- Intimidating Shout -> Intimidating Shout via trigger on target
  [7386] = { { id = 58567, unit = "target", name = "Sunder Armor" } },  -- Sunder Armor -> Sunder Armor via trigger on target
  [12294] = { { id = 12294, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 1) -> Mortal Strike on target
  [21551] = { { id = 21551, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 2) -> Mortal Strike on target
  [21552] = { { id = 21552, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 3) -> Mortal Strike on target
  [21553] = { { id = 21553, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 4) -> Mortal Strike on target
  [25248] = { { id = 25248, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 5) -> Mortal Strike on target
  [30330] = { { id = 30330, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 6) -> Mortal Strike on target
  [47485] = { { id = 47485, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 7) -> Mortal Strike on target
  [47486] = { { id = 47486, unit = "target", name = "Mortal Strike" } },  -- Mortal Strike (Rank 8) -> Mortal Strike on target
  [12705] = { { id = 12705, unit = "target", name = "Long Daze" } },  -- Long Daze (Rank 1) -> Long Daze on target
  [12798] = { { id = 12798, unit = "target", name = "Revenge Stun" } },  -- Revenge Stun (Rank 1) -> Revenge Stun on target
  [12809] = { { id = 12809, unit = "target", name = "Concussion Blow" } },  -- Concussion Blow -> Concussion Blow on target
  [18498] = { { id = 18498, unit = "target", name = "Silenced - Gag Order" } },  -- Silenced - Gag Order -> Silenced - Gag Order on target
  [20252] = { { id = 20253, unit = "target", name = "Intercept" } },  -- Intercept -> Intercept via trigger on target
  [46856] = { { id = 46856, unit = "target", name = "Trauma" } },  -- Trauma (Rank 1) -> Trauma on target
  [46857] = { { id = 46857, unit = "target", name = "Trauma" } },  -- Trauma (Rank 2) -> Trauma on target
  [56112] = { { id = 56112, unit = "target", name = "Furious Attacks" } },  -- Furious Attacks -> Furious Attacks on target
  [64382] = { { id = 64382, unit = "target", name = "Shattering Throw" } },  -- Shattering Throw -> Shattering Throw on target

}
