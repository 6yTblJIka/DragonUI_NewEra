# CDM spell generator

Generates `modules/cooldownviewer/CdmSeedWotLK.lua` from the **client's own data**, so no spell ID
is ever typed from memory. This is the 3.3.5a equivalent of the `.scratch/spellgen` pipeline that
NewEra's `CdmSeedTBC.lua` was built with, and it exists for the same reason: a wrong ID here is
silent — the icon simply never lights up, or lights up for the wrong thing.

## Requirements

```bash
python -m pip install mpyq
```

## Pipeline

Run from this directory, in order:

| script | does | writes |
|---|---|---|
| `dbc.py` | extracts + parses `DBFilesClient\Spell.dbc` | `spells.json` |
| `resolve.py` | joins it with `SkillLineAbility.dbc` to attribute spells to classes, then resolves each ability name to its rank-1 castable ID | `resolved.json`, `listing.txt` |
| `gen_wotlk.py` | applies the authored curation and emits the Lua seed | `../../modules/cooldownviewer/CdmSeedWotLK.lua` |
| `verify.py` | re-checks every emitted ID against the DBC independently | — (exit 1 on any problem) |
| `gen_alertdata.py` | resolves the Execute / Reactive ability names to **every** rank | `../../modules/cooldownviewer/AlertData.lua` |
| `gen_auracatalog.py` | the per-class pool of trackable **self-buffs** — standalone, reads the DBCs itself | `../../modules/cooldownviewer/CdmAuraCatalog.lua` |

`listing.txt` is the useful artefact for curation: every class's abilities that carry a real
cooldown, sorted longest-first.

## Where the data comes from

DBCs live in the **locale** archives, not the base ones: `Data/enUS/{locale,patch-enUS,
patch-enUS-2,patch-enUS-3}.MPQ`, later winning. `Data/*.MPQ` carry no `Spell.dbc` override.

Column positions in 3.3.5a `Spell.dbc` (234 fields, 936-byte records), all located empirically by
the scripts rather than assumed:

- `136` SpellName, `153` Rank (16 locale slots + a flags word apart)
- `29` RecoveryTime, `30` CategoryRecoveryTime — cooldown is `max` of the two

## Why "castable" needs defining

A name maps to several IDs: the ability plus its triggered sub-spells. The discriminator is a real
cooldown (`> 1.5s`), which is also exactly what the Cooldown Manager reads. So `resolve.py` picks
the lowest-rank, lowest-ID entry that has one — giving Penance `47540` rather than its `47666` /
`47750` heal and damage triggers, and Death Grip `49576` rather than `49560` / `49575`.

## What curation still means

`gen_wotlk.py` holds the only hand-authored part: which ability belongs in **Essential** (offensive
burst, damage and throughput cooldowns) vs **Utility** (defensives, interrupts, CC, escapes, raid
cooldowns). Names are authored; IDs are resolved. An unresolvable name is a hard error rather than
a silent omission.

`verify.py` then independently re-reads the DBC and asserts, for every emitted ID: it exists, its
name matches the trailing comment, it carries a real cooldown, it is rank 1, and no ID is
duplicated. That gate is what caught three Metamorphosis-form/passive entries (rank `Demon` and
`Passive`) that had no business in a pressable-cooldown list.

## Why `gen_alertdata.py` resolves differently

It answers a different question, so it cannot reuse `resolve.py`'s answer. The cooldown viewer wants
*one* id per ability; the alert engine has to recognise the ability at **whichever rank the player
casts**, so it keeps them all. It also can't use the `>1.5s cooldown` castability filter — Execute,
Victory Rush and Riposte have no cooldown at all.

Two traps, both found by reading output rather than by reasoning about it:

- **Rank text cannot tell a real ability from an impostor.** Overpower rank 1 (`7384`) has an
  **empty** rank string while its ranks 2-4 are labelled, so a "keep the ranked rows" filter throws
  away the real ability. All four NPC copies of Riposte are likewise unranked, so the same filter
  keeps them.
- **`SkillLineAbility` attribution fixes both**, because NPC spells appear in no player skill line.
  Applied *first*, the "drop unranked siblings" rule is then safe and removes triggered sub-spells
  such as Execute's damage component (`20647`).

Incidentally confirmed by the same query: Overpower's higher ranks appear in no skill line on
3.3.5a — it is single-rank on this client.

## `gen_auracatalog.py` — the buff picker's catalog

Standalone rather than a step in the pipeline above: it needs Spell.dbc columns `spells.json` does not
carry (effects, targets, durations, attribute flags), plus SkillLine, Talent and TalentTab. It locates
every column with `locate()` — the one column agreeing with 3-6 independently-known anchors, where
ambiguity is a hard error — and verifies its own output before writing.

An entry is a spell that puts a timed aura on the **caster** (`EffectImplicitTargetA == 1`) lasting
1-120s, reached directly or through one `EffectTriggerSpell` hop. The hop is where the value is: it is
the difference between a list of cooldowns you press and a list of things that happen to you
(Clearcasting, Missile Barrage, Lock and Load, Sudden Death, Bloodsurge).

Three filters exist only because output was read rather than reasoned about:

- **`AttributesEx & 0x44`** (channelled). A channel's duration lives in the same column as an aura's,
  so without this Blizzard, Evocation, Mind Control and Tranquility all arrive as "self buffs".
- **Per-row class mask first, skill-line vote only at >=90% dominance.** `resolve.py`'s majority vote
  drags in skill line 183 `GENERIC (DND)` — Grovel, Honorless Target — whose rows have a class mask of
  0 and vote evenly for all ten classes.
- **Racial skill lines excluded outright.** Blood Fury's row carries a WARRIOR class bit and would
  otherwise be offered to every warrior regardless of race.

Talent gating is the "per spec" part, and it is per **talent** rather than per spec on purpose: the
runtime asks `GetTalentInfo`, so it follows respecs and dual spec. Where an aura is reachable both as a
talent proc and as a class-skill-line row, **the talent reading wins** — the client indexes talent procs
in class skill lines, so presence there is not evidence of being baseline. All 35 both-ways conflicts
were printed and checked by hand; every one is a real talent.

## Known gap

`Data/patch-4.MPQ` and `Data/patch-S.mpq` are encrypted and cannot be read. If this server
overrides spell data there, these IDs reflect the stock client instead. Nothing observed suggests
it does, but it is the one hole in the sourcing and is repeated in the generated file's header.
