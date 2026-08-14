"""Generates modules/cooldownviewer/CdmSpellAuras.lua — WHICH AURA a castable spell drives, and on
WHICH UNIT it lands.

THE PROBLEM THIS SOLVES

Everything in the Cooldown Manager that asks "is this spell's effect up right now" — the buff glow,
the `refresh` alert, the `active` alert — asks it by comparing the AURA'S NAME to the SPELL'S NAME,
on the PLAYER. Two whole categories of ability are invisible to that test:

  * the aura is named differently from the cast. Bloodsurge turns Slam into `Slam!`; Brain Freeze
    turns Fireball into `Fireball!`. One character of difference, and the match fails forever.
  * the aura is not on the player. Faerie Fire, Moonfire and Insect Swarm land on the TARGET;
    Earth Shield lands on a PARTY MEMBER. Nothing ever looked anywhere but at the player.

Reported as issues #57 (druid Balance and warrior Slam alerts never fire; "please make abilities
that apply a buff or debuff glow while it is up") and #52 (shaman shields untrackable, Earth Shield
"trickier because the Buff may be applied to other units").

WHAT COUNTS AS A LINK

For each castable class ability, every effect slot is read two ways:

  * DIRECT — `Effect[i] == APPLY_AURA (6)`. The spell IS the aura; `ImplicitTargetA[i]` says on whom.
    Faerie Fire, Moonfire, Earth Shield and Lightning Shield all arrive this way.
  * ONE HOP — `EffectTriggerSpell[i]`, but ONLY where slot `i` is not itself an APPLY_AURA. Charge
    -> Charge Stun (on the target) arrives this way.

    That exclusion is the whole difference between a hop worth taking and a hop that lies. A trigger
    hanging off an APPLY_AURA slot is a PROC OF THAT AURA — "while this buff is up, sometimes fire
    that" — not something the cast applies. Barkskin's third slot is APPLY_AURA(self) carrying a
    trigger to `Dazed`, and reading it as a link claims Barkskin dazes your target; Lightning
    Shield's is APPLY_AURA(self) carrying its own damage proc. Neither is an aura the tile should
    report. Charge's is EffectTriggerSpell on a slot that is not an aura at all, and it is exactly
    the stun the tile should report. The procs lost to this rule — Quick Shots off Aspect of the
    Hawk, and its kin — are all in CdmAuraCatalog.lua already, trackable in their own right.

Plus one rule that is not a graph walk at all, because the relationship is not in the data:

  * BANG-PROCS. Blizzard's convention for "your next X is free/instant" is an aura named exactly
    `X!`. Bloodsurge's `Slam!` (46916) is triggered by the TALENT, not by Slam — Slam's own record
    has no aura and no trigger, so no amount of walking from Slam finds it. The link is recovered by
    NAME at generation time, which is safe here and would not be at runtime: this file is generated
    against enUS, and a Spanish client renders the same aura `¡Embate!` — bracketing exclamation
    marks that no `name .. "!"` test would ever match. Generating by name and SHIPPING IDS is what
    makes the link survive localisation.

    Restricted to bang auras that land on the CASTER, because that is what the convention means.
    133 spells in this client end in `!`; most are quest and vehicle chatter, and two of them —
    `Blind!` (71750) and `Slap!` — collide by name with a real ability while being neither its proc
    nor even on the same unit. Requiring the caster drops every one of those and keeps `Slam!`,
    `Fireball!` and Decimation's `Soul Fire!`.

WHAT IS DELIBERATELY NOT EMITTED

A link the existing runtime already finds: same name, on the player. Lightning Shield is its own
aura, on you, named `Lightning Shield` — `findPlayerAuraDataByName` has always resolved it, and a
row here would be dead weight. So a row exists only when the name differs OR the unit is not the
player. (#52's shield complaint is NOT a missing link; it is a missing stack count and a duration
window, both fixed in the addon rather than here.)

AoE implicit targets (22 = area-enemy-src, 24, and friends) are also out. `ImplicitTargetA == 22`
means "everything near the destination", and answering "is Demoralizing Shout on my current target"
with an aura scan of that target would be right about as often as it was wrong — the spell does not
mean "my target" and the tile should not imply it does. Single-unit targets only: caster, the
target, or one ally.

COLUMN POSITIONS, ALL LOCATED RATHER THAN ASSUMED — same discipline as gen_auracatalog.py, and the
same anchors where they overlap, so the two generators cannot silently disagree about a column.

KNOWN GAP: Data/patch-4.MPQ and patch-S.mpq are encrypted and unreadable, so if this server
overrides spell data there, these ids reflect the stock client.
"""
import os, re, struct, collections, sys

# The install to read. Overridable, because the generators in this directory were authored against
# one box's client and the DBCs are identical across stock 3.3.5a installs.
DATA = os.environ.get("CDM_DATA") or next(
    (p for p in (r"D:/Triumvirate/Data/enUS", r"D:/Project Reforged 3.3.5a/Data/enUS")
     if os.path.isdir(p)), r"D:/Triumvirate/Data/enUS")
ORDER = ["locale-enUS.MPQ", "patch-enUS.MPQ", "patch-enUS-2.MPQ", "patch-enUS-3.MPQ"]
OUT = "../../modules/cooldownviewer/CdmSpellAuras.lua"

APPLY_AURA = 6
ATTR_PASSIVE = 0x40
ATTREX_CHANNELED = 0x4 | 0x40

# ImplicitTargetA -> the unit token the runtime scans. Single-unit targets only; see the header.
#   1  TARGET_UNIT_CASTER        21 TARGET_UNIT_TARGET_ALLY
#   6  TARGET_UNIT_TARGET_ENEMY  25 TARGET_UNIT_TARGET_ANY
UNIT_BY_TARGET = {1: "player", 6: "target", 21: "friend", 25: "target"}

# WHICH ABILITIES MAY EMIT A `friend` LINK, and why this is a hand-authored set rather than a rule.
#
# A tile shows ONE aura. For an ability that can only be out on one ally at a time that is a complete
# answer — recasting Earth Shield removes the previous one, so "is it out, and where" has exactly one
# truth and the runtime sweep finds it. For an ability you keep on twenty people at once it is not an
# answer at all: a Discipline priest with Power Word: Shield across the raid would get whichever
# shield the sweep reached first, held until it expired, with nothing on the tile to say whose it was
# — and a dark tile whenever the shielded players happened to be outside the reachable unit set.
# Confidently wrong beats blank, and blank is what those tiles showed before.
#
# Nothing in Spell.dbc distinguishes the two: one-target-at-a-time is server-enforced, not a client
# attribute. So the rule has to be authored, and the default has to be "no".
#
# Dropping a `friend` link is not a regression for those abilities — it restores exactly what they had
# before this file existed. A self-cast Rejuvenation still resolves the ordinary way, by name, on you.
#
# Tracking many-target coverage is a real want and a DIFFERENT feature: it needs a count across the
# raid, not a single-unit lookup, and it should not be faked with one.
FRIEND_OK = {
    "Earth Shield",     # one target at a time; the ability issue #52 asked for
}

# An aura shorter than this is a mechanic, not something a glow can report. Same floor as
# gen_auracatalog.py, and for the same reason (Heroic Fury's aura lasts 100ms).
MIN_MS = 1000

CLASS_BY_ID = {1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST",
               6: "DEATHKNIGHT", 7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 11: "DRUID"}
CLASS_ORDER = ["DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN",
               "WARLOCK", "WARRIOR"]


def load(name):
    from mpyq import MPQArchive
    blob = None
    for a in ORDER:
        p = os.path.join(DATA, a)
        if not os.path.exists(p):
            continue
        try:
            d = MPQArchive(p).read_file("DBFilesClient\\" + name)
            if d:
                blob = d          # later archive wins
        except Exception:
            pass
    if not blob:
        sys.exit(f"{name} not found under {DATA}")
    magic, rc, fc, rs, sbs = struct.unpack("<4sIIII", blob[:20])
    if magic != b"WDBC":
        sys.exit(f"{name}: bad magic {magic!r}")
    recs = [struct.unpack_from(f"<{fc}I", blob, 20 + i * rs) for i in range(rc)]
    sb = blob[20 + rc * rs: 20 + rc * rs + sbs]

    def s(o):
        if o <= 0 or o >= len(sb):
            return ""
        e = sb.find(b"\0", o)
        return sb[o:e].decode("utf-8", "ignore")
    return recs, s, fc


print(f"reading {DATA}")
spell, sstr, SFC = load("Spell.dbc")
dur, _, _ = load("SpellDuration.dbc")
sla, _, _ = load("SkillLineAbility.dbc")
skl, kstr, KFC = load("SkillLine.dbc")

by_id = {r[0]: r for r in spell}
DURBASE = {r[0]: r[1] for r in dur}


def locate(label, anchors, xform=lambda v: v):
    """The one column that agrees with every anchor. Ambiguity is an error, not a first match."""
    hits = [c for c in range(1, SFC)
            if all(by_id.get(sid) and xform(by_id[sid][c]) == want for sid, want in anchors.items())]
    if len(hits) != 1:
        sys.exit(f"{label}: expected exactly one matching column, got {hits}")
    print(f"  {label:26s} = {hits[0]:3d}  (proved by {len(anchors)} anchors)")
    return hits[0]


print("locating columns:")
NAME = locate("Spell.SpellName", {133: "Fireball", 8092: "Mind Blast", 1459: "Arcane Intellect"},
              xform=sstr)
RANK = NAME + 17          # next locale block: 16 locales + a flags word
DURIDX = locate("Spell.DurationIndex", {12042: 15000, 12472: 20000, 2825: 40000, 139: 15000,
                                        588: 1800000, 172: 12000}, xform=lambda v: DURBASE.get(v))
EFF = locate("Spell.Effect[0]", {133: 2, 139: 6, 12042: 6, 172: 6, 588: 6, 1459: 6})
if locate("Spell.Effect[1]", {133: 6, 172: 3, 12042: 6, 12472: 6, 139: 0}) != EFF + 1:
    sys.exit("Effect[] is not contiguous")
TGTA = locate("Spell.ImplicitTargetA[0]", {12042: 1, 588: 1, 139: 21, 133: 6, 172: 6})
TRIG = locate("Spell.EffectTriggerSpell[1]", {2687: 29131}) - 1
ATTR, ATTREX = 4, 5

# The three anchors that prove UNIT_BY_TARGET means what the header says it means. Asserted rather
# than trusted: a silently wrong unit sends the runtime scanning the wrong frame, which looks
# exactly like "the glow just doesn't work" — the bug this file exists to fix.
for sid, want in ((12042, "player"), (770, "target"), (974, "friend")):
    r = by_id[sid]
    got = next((UNIT_BY_TARGET.get(r[TGTA + i]) for i in range(3) if r[EFF + i] == APPLY_AURA), None)
    if got != want:
        sys.exit(f"unit mapping fails on {sid} ({sstr(r[NAME])}): expected {want}, got {got}")
print(f"  {'UNIT_BY_TARGET':26s} checked on Arcane Power / Faerie Fire / Earth Shield")


def spellname(sid):
    r = by_id.get(sid)
    return sstr(r[NAME]) if r else ""


def ranktext(sid):
    r = by_id.get(sid)
    return sstr(r[RANK]) if r else ""


def duration_ms(sid):
    r = by_id.get(sid)
    return DURBASE.get(r[DURIDX], 0) if r else 0


def is_timed_aura(sid):
    """A real, readable, timed aura — not a passive and not a channel's cast bar wearing an aura's
    duration column (the distinction gen_auracatalog.py had to learn the hard way)."""
    r = by_id.get(sid)
    if not r:
        return False
    if r[ATTR] & ATTR_PASSIVE:
        return False
    if r[ATTREX] & ATTREX_CHANNELED:
        return False
    return duration_ms(sid) >= MIN_MS


# ── class attribution ───────────────────────────────────────────────────────────────────────────
# Lifted from gen_auracatalog.py, whose reasoning applies unchanged: an explicit class mask is
# authoritative, a zero mask falls back to the skill line but only when that line is >=90% one
# class, and the racial lines are dropped outright (Blood Fury's row carries a WARRIOR bit).
SKL_NAME = None
for c in range(1, KFC):
    if any(r[0] == 26 and kstr(r[c]) == "Arms" for r in skl):
        SKL_NAME = c
        break
if SKL_NAME is None:
    sys.exit("could not locate the SkillLine name column")
racial_lines = {r[0] for r in skl if kstr(r[SKL_NAME]).endswith("Racial")}
racial_ids = {r[2] for r in sla if r[1] in racial_lines}

line_votes = collections.defaultdict(collections.Counter)
for r in sla:
    for cid, cname in CLASS_BY_ID.items():
        if r[4] & (1 << (cid - 1)):
            line_votes[r[1]][cname] += 1

DOMINANCE = 0.90
line_class = {}
for line, v in line_votes.items():
    top, n = v.most_common(1)[0]
    if n / sum(v.values()) >= DOMINANCE:
        line_class[line] = top

class_of = {}
for r in sla:
    line, sid, mask = r[1], r[2], r[4]
    if sid in racial_ids:
        continue
    names = [c for cid, c in CLASS_BY_ID.items() if mask & (1 << (cid - 1))]
    if len(names) == 1:
        class_of.setdefault(sid, names[0])
    elif not mask and line in line_class:
        class_of.setdefault(sid, line_class[line])
print(f"  attributed {len(class_of)} spells to a class "
      f"({len(racial_lines)} racial lines excluded)")

# ── link extraction ─────────────────────────────────────────────────────────────────────────────
def aura_unit(sid, prefer=None):
    """The unit an aura lands on, from its own first APPLY_AURA slot. `prefer` lets a hop inherit
    the parent effect's target when the trigger's own slot is an AoE the map does not carry."""
    r = by_id.get(sid)
    if not r:
        return None
    for i in range(3):
        if r[EFF + i] == APPLY_AURA and r[TGTA + i] in UNIT_BY_TARGET:
            return UNIT_BY_TARGET[r[TGTA + i]]
    return prefer


def is_caster_aura(sid):
    return aura_unit(sid) == "player"


# ── bang-procs ──────────────────────────────────────────────────────────────────────────────────
# Every timed aura whose name is some other spell's name with an exclamation mark welded on. Built
# once, as a name index, because the relationship runs backwards: the aura knows the ability, the
# ability knows nothing.
bang_by_name = {}
for r in spell:
    _nm = sstr(r[NAME])
    if len(_nm) > 1 and _nm.endswith("!") and is_timed_aura(r[0]) and is_caster_aura(r[0]):
        bang_by_name.setdefault(_nm[:-1], r[0])
print(f"  {len(bang_by_name)} bang-proc auras indexed (caster-targeted only)")


def links_for(sid):
    """Every (auraID, unit, how) this spell drives. Ordered: direct first, then hops, then bang."""
    r = by_id.get(sid)
    if not r:
        return []
    out, seen = [], set()

    def add(aura, unit, how):
        if not (aura and unit) or aura in seen:
            return
        if not is_timed_aura(aura):
            return
        seen.add(aura)
        out.append((aura, unit, how))

    for i in range(3):
        if r[EFF + i] == APPLY_AURA and r[TGTA + i] in UNIT_BY_TARGET:
            add(sid, UNIT_BY_TARGET[r[TGTA + i]], "direct")
    for i in range(3):
        trig = r[TRIG + i]
        # NOT from an APPLY_AURA slot: that is a proc OF the aura, not an effect of the cast. See
        # the header — this is the rule that separates Charge -> Charge Stun from Barkskin -> Dazed.
        if trig and r[EFF + i] != APPLY_AURA:
            add(trig, aura_unit(trig, UNIT_BY_TARGET.get(r[TGTA + i])), "trigger")
    bang = bang_by_name.get(spellname(sid))
    if bang:
        add(bang, "player", "proc")
    # See FRIEND_OK: a tile shows one aura, so a `friend` link is only honest for an ability that can
    # be out on one ally at a time.
    if spellname(sid) not in FRIEND_OK:
        out = [t for t in out if t[1] != "friend"]
    return out


# Ranks of an ability, so a tile holding any rank resolves. Same reasoning as AlertData.lua: our
# curated lists key rank 1, a custom list may hold any of them, and the tile displays the highest
# LEARNED one.
ranks_by_key = collections.defaultdict(list)
for sid, cls in class_of.items():
    ranks_by_key[(cls, spellname(sid))].append(sid)

emitted = collections.defaultdict(dict)     # class -> {spellID: [(aura, unit, how), ...]}
stats = collections.Counter()
for sid, cls in sorted(class_of.items()):
    r = by_id.get(sid)
    if not r or r[ATTR] & ATTR_PASSIVE:
        continue
    rows = links_for(sid)
    if not rows:
        continue
    own = spellname(sid)
    # THE FILTER THAT KEEPS THIS FILE HONEST: a link the runtime already finds unaided is not a
    # link worth shipping. Same name, on the player, is exactly what findPlayerAuraDataByName does.
    rows = [t for t in rows if not (t[1] == "player" and spellname(t[0]) == own)]
    if not rows:
        continue
    for how in {t[2] for t in rows}:
        stats[how] += 1
    emitted[cls][sid] = rows

total = sum(len(v) for v in emitted.values())
print(f"  {total} spells linked  ({dict(stats)})")

# NO SILENT CAPS. FRIEND_OK drops links that the graph genuinely found, so say which — a reader
# comparing this output to the DBC should not have to rediscover the rule from a missing row.
dropped = set()
for sid, cls in class_of.items():
    r = by_id.get(sid)
    if not r or r[ATTR] & ATTR_PASSIVE:
        continue
    nm = spellname(sid)
    if nm in FRIEND_OK:
        continue
    for i in range(3):
        if r[EFF + i] == APPLY_AURA and UNIT_BY_TARGET.get(r[TGTA + i]) == "friend" \
           and is_timed_aura(sid):
            dropped.add(nm)
if dropped:
    print(f"  {len(dropped)} many-target ally buffs deliberately NOT given a friend link "
          f"(see FRIEND_OK):")
    for nm in sorted(dropped):
        print(f"      {nm}")

# ── emit ────────────────────────────────────────────────────────────────────────────────────────
HOW_NOTE = {"direct": "", "trigger": " via trigger", "proc": " proc"}

lines = ["""-- DragonUI_NewEra/modules/cooldownviewer/CdmSpellAuras.lua — GENERATED, DO NOT HAND-EDIT.
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
"""]

for cls in CLASS_ORDER:
    rows = emitted.get(cls)
    if not rows:
        continue
    lines.append(f"  -- {cls}")
    # Group by ability so every rank of it sits together, ordered by the rank-1 id.
    byname = collections.defaultdict(list)
    for sid in rows:
        byname[spellname(sid)].append(sid)
    for nm in sorted(byname, key=lambda n: min(byname[n])):
        ids = sorted(byname[nm])
        for sid in ids:
            parts = []
            for aura, unit, how in emitted[cls][sid]:
                parts.append('{ id = %d, unit = "%s", name = %s }'
                             % (aura, unit, '"%s"' % spellname(aura).replace('"', '\\"')))
            rt = ranktext(sid)
            note = ", ".join(f"{spellname(a)}{HOW_NOTE[h]} on {u}" for a, u, h in emitted[cls][sid])
            lines.append("  [%d] = { %s },%s-- %s%s -> %s"
                         % (sid, ", ".join(parts), " " * max(1, 2), nm,
                            f" ({rt})" if rt else "", note))
    lines.append("")

lines.append("}\n")

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines))
print(f"wrote {OUT}  ({total} spells)")

# ── the report the curation is read from ────────────────────────────────────────────────────────
print("\nsample links, by class:")
for cls in CLASS_ORDER:
    rows = emitted.get(cls) or {}
    firsts = {}
    for sid, rs in sorted(rows.items()):
        firsts.setdefault(spellname(sid), rs)
    print(f"  {cls:12s} {len(firsts):3d} abilities")
    for nm, rs in list(sorted(firsts.items()))[:6]:
        print("      %-28s %s" % (nm, ", ".join(f"{spellname(a)}@{u}" for a, u, _ in rs)))
