"""Generate modules/cooldownviewer/CdmSeedWotLK.lua.

Curation (which ability belongs in Essential vs Utility) is authored here BY NAME.
Every spell ID is then resolved from the client's own Spell.dbc + SkillLineAbility.dbc
(resolved.json, built by resolve.py) -- never typed by hand. A name that fails to
resolve is a hard error, so the file can't silently ship a wrong id.

Essential = offensive burst / damage / throughput cooldowns.
Utility    = defensives, interrupts, CC, escapes, dispels, raid cooldowns.
"""
import json, sys

resolved = json.load(open("resolved.json", encoding="utf-8"))

ESSENTIAL = {
 "WARRIOR": ["Bladestorm", "Shattering Throw", "Sweeping Strikes", "Heroic Throw",
             "Shield Slam", "Overpower", "Revenge"],
 "PALADIN": ["Divine Storm", "Hammer of the Righteous", "Shield of Righteousness",
             "Avenger's Shield", "Holy Wrath", "Divine Favor", "Divine Illumination"],
 "HUNTER":  ["Explosive Shot", "Chimera Shot", "Kill Shot", "Black Arrow", "Silencing Shot"],
 "ROGUE":   ["Killing Spree", "Shadow Dance", "Ghostly Strike", "Tricks of the Trade"],
 "PRIEST":  ["Penance", "Holy Fire", "Circle of Healing", "Prayer of Mending",
             "Divine Hymn", "Hymn of Hope"],
 "MAGE":    ["Deep Freeze", "Mirror Image", "Icy Veins", "Arcane Barrage", "Blast Wave",
             "Summon Water Elemental"],
 "WARLOCK": ["Metamorphosis", "Haunt", "Chaos Bolt", "Shadowflame", "Demonic Empowerment"],
 "DRUID":   ["Starfall", "Berserk", "Typhoon", "Wild Growth", "Swiftmend"],
 "SHAMAN":  ["Feral Spirit", "Thunderstorm", "Lava Burst", "Lava Lash", "Riptide", "Heroism"],
 "DEATHKNIGHT": ["Army of the Dead", "Summon Gargoyle", "Dancing Rune Weapon",
                 "Empower Rune Weapon", "Howling Blast", "Death and Decay", "Blood Tap",
                 "Raise Dead", "Horn of Winter"],
}

UTILITY = {
 "WARRIOR": ["Shockwave", "Enraged Regeneration", "Heroic Fury", "Disarm", "Concussion Blow",
             "Challenging Shout", "Retaliation"],
 "PALADIN": ["Divine Sacrifice", "Hand of Sacrifice", "Hand of Salvation", "Aura Mastery",
             "Divine Plea", "Repentance", "Holy Shield", "Righteous Defense"],
 "HUNTER":  ["Master's Call", "Wyvern Sting", "Freezing Arrow", "Explosive Trap", "Frost Trap",
             "Flare", "Intimidation"],
 "ROGUE":   ["Dismantle", "Feint", "Distract", "Shadowstep", "Cloak of Shadows"],
 "PRIEST":  ["Dispersion", "Pain Suppression", "Guardian Spirit", "Psychic Horror"],
 "MAGE":    ["Frost Ward", "Fire Ward", "Cold Snap", "Dragon's Breath"],
 "WARLOCK": ["Demonic Circle: Teleport", "Soulshatter", "Fel Domination", "Shadow Ward"],
 "DRUID":   ["Survival Instincts", "Barkskin", "Frenzied Regeneration", "Nature's Grasp",
             "Feral Charge - Bear", "Feral Charge - Cat", "Maim", "Bash", "Rebirth",
             "Innervate", "Dash"],
 "SHAMAN":  ["Hex", "Wind Shear", "Grounding Totem", "Earthbind Totem", "Stoneclaw Totem",
             "Nature's Swiftness"],
 "DEATHKNIGHT": ["Icebound Fortitude", "Anti-Magic Shell", "Anti-Magic Zone", "Death Grip",
                 "Mind Freeze", "Strangulate", "Death Pact", "Rune Tap", "Vampiric Blood",
                 "Bone Shield", "Unbreakable Armor", "Lichborne", "Hungering Cold",
                 "Dark Command", "Raise Ally"],
}

errors = []
def lookup(cls, name):
    sid = resolved.get(cls, {}).get(name)
    if not sid:
        errors.append(f"{cls}: {name!r} did not resolve")
        return None
    return sid

def emit(table, title):
    lines = []
    for cls in sorted(table):
        entries = []
        for nm in table[cls]:
            sid = lookup(cls, nm)
            if sid:
                entries.append((sid, nm))
        if not entries:
            continue
        lines.append(f"  {cls} = {{")
        for sid, nm in entries:
            lines.append(f"    {sid},{' ' * max(1, 8 - len(str(sid)))}-- {nm}")
        lines.append("  },")
    return "\n".join(lines)

ess = emit(ESSENTIAL, "essential")
uti = emit(UTILITY, "utility")

if errors:
    print("UNRESOLVED NAMES -- refusing to generate:")
    for e in errors:
        print("  " + e)
    sys.exit(1)

header = '''-- DragonUI_NewEra/modules/cooldownviewer/CdmSeedWotLK.lua — WotLK (3.3.5a) data seed.
--
-- The 3.3.5a counterpart of NewEra's CdmSeedTBC.lua, and structured the same way: ADDITIVE appends
-- onto the vanilla curated lists in ClassData.lua, which carry the 1.12 staples whose rank-1 ids
-- still resolve on this client. Only genuinely NEW-to-WotLK abilities are listed here — plus the
-- whole of DEATHKNIGHT, which has no vanilla base at all.
--
-- FACTS, NOT GUESSES. Every spell ID below was resolved from THIS CLIENT'S OWN DATA, not typed
-- from memory:
--   * Spell.dbc            (DBFilesClient\\\\Spell.dbc, from Data/enUS/patch-enUS-3.MPQ — the
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
%s
}

local UTILITY_ADD = {
%s
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
''' % (ess, uti)

out = r"D:/Project Reforged 3.3.5a/Interface/AddOns/DragonUI_NewEra/modules/cooldownviewer/CdmSeedWotLK.lua"
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(header)

n_e = sum(len(v) for v in ESSENTIAL.values())
n_u = sum(len(v) for v in UTILITY.values())
print(f"resolved {n_e} essential + {n_u} utility = {n_e + n_u} abilities across {len(ESSENTIAL)} classes")
print("wrote", out)
