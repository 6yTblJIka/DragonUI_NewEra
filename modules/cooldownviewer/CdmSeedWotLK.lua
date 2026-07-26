-- DragonUI_NewEra/modules/cooldownviewer/CdmSeedWotLK.lua — WotLK (3.3.5a) data seed.
--
-- The 3.3.5a counterpart of NewEra's CdmSeedTBC.lua, and structured the same way: ADDITIVE appends
-- onto the vanilla curated lists in ClassData.lua, which carry the 1.12 staples whose rank-1 ids
-- still resolve on this client. Only genuinely NEW-to-WotLK abilities are listed here — plus the
-- whole of DEATHKNIGHT, which has no vanilla base at all.
--
-- FACTS, NOT GUESSES. Every spell ID below was resolved from THIS CLIENT'S OWN DATA, not typed
-- from memory:
--   * Spell.dbc            (DBFilesClient\\Spell.dbc, from Data/enUS/patch-enUS-3.MPQ — the
--                           highest-priority readable archive) for name, rank and cooldown
--   * SkillLineAbility.dbc for class attribution, via each skill line's ClassMask
-- The generator authors the curation BY NAME and resolves each name to the rank-1 CASTABLE id —
-- defined as the lowest-rank, lowest-id entry that actually carries a cooldown > 1.5s. That last
-- filter is what separates a real ability from its triggered sub-spells (e.g. Penance resolves to
-- 47540, not its 47666/47750 heal/damage triggers; Death Grip to 49576, not 49560/49575).
--
-- CAVEAT: two archives in this install (patch-4.MPQ, patch-S.mpq) are encrypted and unreadable, so
-- if the server overrides a spell's data there, these ids reflect the stock client rather than the
-- server's edit. Nothing observed suggests it does, but that is the one gap in the sourcing.
--
-- Bucketing follows retail's split: Essential = offensive burst / damage / throughput cooldowns,
-- Utility = defensives, interrupts, CC, escapes and raid cooldowns.
--
-- The BuffIcon / BuffBar viewers are deliberately NOT seeded: they auto-track any player buff
-- <= 120s (see CooldownViewer.lua), which already covers WotLK procs and trinkets, and upstream
-- removed its long-maintenance-buff seed as clutter.

local NE = DragonUI_NewEra
local M = NE.cooldownviewer
if not M then return end

local ESSENTIAL_ADD = {
  DEATHKNIGHT = {
    42650,   -- Army of the Dead
    49206,   -- Summon Gargoyle
    49028,   -- Dancing Rune Weapon
    47568,   -- Empower Rune Weapon
    49184,   -- Howling Blast
    43265,   -- Death and Decay
    45529,   -- Blood Tap
    46584,   -- Raise Dead
    57330,   -- Horn of Winter
  },
  DRUID = {
    48505,   -- Starfall
    50334,   -- Berserk
    50516,   -- Typhoon
    48438,   -- Wild Growth
    18562,   -- Swiftmend
  },
  HUNTER = {
    53301,   -- Explosive Shot
    53209,   -- Chimera Shot
    53351,   -- Kill Shot
    3674,    -- Black Arrow
    34490,   -- Silencing Shot
  },
  MAGE = {
    44572,   -- Deep Freeze
    55342,   -- Mirror Image
    12472,   -- Icy Veins
    44425,   -- Arcane Barrage
    11113,   -- Blast Wave
    31687,   -- Summon Water Elemental
  },
  PALADIN = {
    53385,   -- Divine Storm
    53595,   -- Hammer of the Righteous
    53600,   -- Shield of Righteousness
    31935,   -- Avenger's Shield
    2812,    -- Holy Wrath
    20216,   -- Divine Favor
    31842,   -- Divine Illumination
  },
  PRIEST = {
    47540,   -- Penance
    14914,   -- Holy Fire
    34861,   -- Circle of Healing
    33076,   -- Prayer of Mending
    64843,   -- Divine Hymn
    64901,   -- Hymn of Hope
  },
  ROGUE = {
    51690,   -- Killing Spree
    51713,   -- Shadow Dance
    14278,   -- Ghostly Strike
    57934,   -- Tricks of the Trade
  },
  SHAMAN = {
    51533,   -- Feral Spirit
    51490,   -- Thunderstorm
    51505,   -- Lava Burst
    60103,   -- Lava Lash
    61295,   -- Riptide
    32182,   -- Heroism
  },
  WARLOCK = {
    47241,   -- Metamorphosis
    48181,   -- Haunt
    50796,   -- Chaos Bolt
    47897,   -- Shadowflame
    47193,   -- Demonic Empowerment
  },
  WARRIOR = {
    46924,   -- Bladestorm
    64382,   -- Shattering Throw
    12328,   -- Sweeping Strikes
    57755,   -- Heroic Throw
    23922,   -- Shield Slam
    7384,    -- Overpower
    6572,    -- Revenge
  },
}

local UTILITY_ADD = {
  DEATHKNIGHT = {
    48792,   -- Icebound Fortitude
    48707,   -- Anti-Magic Shell
    51052,   -- Anti-Magic Zone
    49576,   -- Death Grip
    47528,   -- Mind Freeze
    47476,   -- Strangulate
    48743,   -- Death Pact
    48982,   -- Rune Tap
    55233,   -- Vampiric Blood
    49222,   -- Bone Shield
    51271,   -- Unbreakable Armor
    49039,   -- Lichborne
    49203,   -- Hungering Cold
    56222,   -- Dark Command
    61999,   -- Raise Ally
  },
  DRUID = {
    61336,   -- Survival Instincts
    22812,   -- Barkskin
    22842,   -- Frenzied Regeneration
    16689,   -- Nature's Grasp
    16979,   -- Feral Charge - Bear
    49376,   -- Feral Charge - Cat
    22570,   -- Maim
    5211,    -- Bash
    20484,   -- Rebirth
    29166,   -- Innervate
    1850,    -- Dash
  },
  HUNTER = {
    53271,   -- Master's Call
    19386,   -- Wyvern Sting
    60192,   -- Freezing Arrow
    13813,   -- Explosive Trap
    13809,   -- Frost Trap
    1543,    -- Flare
    19577,   -- Intimidation
  },
  MAGE = {
    6143,    -- Frost Ward
    543,     -- Fire Ward
    11958,   -- Cold Snap
    31661,   -- Dragon's Breath
  },
  PALADIN = {
    64205,   -- Divine Sacrifice
    6940,    -- Hand of Sacrifice
    1038,    -- Hand of Salvation
    31821,   -- Aura Mastery
    54428,   -- Divine Plea
    20066,   -- Repentance
    20925,   -- Holy Shield
    31789,   -- Righteous Defense
  },
  PRIEST = {
    47585,   -- Dispersion
    33206,   -- Pain Suppression
    47788,   -- Guardian Spirit
    64044,   -- Psychic Horror
  },
  ROGUE = {
    51722,   -- Dismantle
    1966,    -- Feint
    1725,    -- Distract
    36554,   -- Shadowstep
    31224,   -- Cloak of Shadows
  },
  SHAMAN = {
    51514,   -- Hex
    57994,   -- Wind Shear
    8177,    -- Grounding Totem
    2484,    -- Earthbind Totem
    5730,    -- Stoneclaw Totem
    16188,   -- Nature's Swiftness
  },
  WARLOCK = {
    48020,   -- Demonic Circle: Teleport
    29858,   -- Soulshatter
    18708,   -- Fel Domination
    6229,    -- Shadow Ward
  },
  WARRIOR = {
    46968,   -- Shockwave
    55694,   -- Enraged Regeneration
    60970,   -- Heroic Fury
    676,     -- Disarm
    12809,   -- Concussion Blow
    1161,    -- Challenging Shout
    20230,   -- Retaliation
  },
}

-- Append (deduped) into the existing per-class arrays. A class with no vanilla entry — i.e.
-- DEATHKNIGHT — gets a fresh list rather than being skipped.
local function appendAll(target, byClass)
  if not target then return end
  for class, adds in pairs(byClass) do
    local list = target[class]
    if not list then list = {}; target[class] = list end
    local seen = {}
    for _, id in ipairs(list) do seen[id] = true end
    for _, id in ipairs(adds) do
      if not seen[id] then seen[id] = true; list[#list + 1] = id end
    end
  end
end

appendAll(M.ESSENTIAL_BY_CLASS, ESSENTIAL_ADD)
appendAll(M.UTILITY_BY_CLASS,   UTILITY_ADD)

-- SPELL_DATA_BY_CATEGORY holds references to the same tables, so the appends above are already
-- visible through it. The learn-gate memoises the curated set on first use, though, so drop that
-- cache now that the tables have grown.
if M.InvalidateCuratedCache then M.InvalidateCuratedCache() end
