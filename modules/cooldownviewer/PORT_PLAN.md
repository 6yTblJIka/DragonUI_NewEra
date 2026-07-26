# Cooldown Manager — Port Plan (Build Contract)

Downport of `ReferenceAddons/NewEra/CooldownViewer/` + `CooldownViewerSettings/` (Classic 1.15 /
TBC 2.5.x) onto 3.3.5a. Read `CONTRACTS.md` §0 first — every global convention there applies.

**Status:** Phases 0-4a plus 4b-1, 4b-2 and 4b-3 implemented. Offline harnesses pass (`qa/offline/`,
241 boot assertions). Phases 1-3 and the 4b-1 window shell are confirmed working in-game; 4b-2 and
4b-3 are harness-verified and awaiting an in-game pass. Remaining: 4b-4 drag reorder, 4b-5 presets,
plus the trinket/equip port — all scoped in §G.

---

## A. What the source actually is

Retail's Cooldown Manager is `C_CooldownViewer` / `C_CooldownViewerSettings` — client-side C++ added
in 11.0 (TWW). That API does **not** exist on 3.3.5a, and it does not exist on Classic Era or TBC
Classic either: `C_CooldownViewer.IsCooldownViewerAvailable()` returns false there.

So NewEra never ported Blizzard's Lua. It built a **visual port with a custom data driver** — retail's
frame stack (icon viewers, cooldown swipe, GCD flash, out-of-range shadow) fed by hand-curated
per-class spell lists plus live `GetSpellCooldown` / `UNIT_AURA` / `GetInventoryItemCooldown` reads.
The source header states this explicitly (`CooldownViewer.lua:1-17`).

**This is the single most important fact for planning:** the hard part — inventing a cooldown data
model for a client with no spec system and no curated cooldown sets — is already solved and shipped.
`CdmSeedTBC.lua` is a working precedent for layering one flavour's data on top of the vanilla base,
which is exactly the shape WotLK needs. Our work is the **platform gap**, not the design.

Size: **5,444 lines** across 12 files in `CooldownViewer/`, plus **2,139 lines** in
`CooldownViewerSettings/`.

| File | Lines | Ports as-is? |
|---|---|---|
| `CooldownViewer.lua` | 1,715 | mostly — `getOpt` retarget + `RegisterUnitEvent` |
| `ItemMixins.lua` | 1,289 | mostly — mask + swipe strip |
| `Alerts.lua` | 520 | partial — pandemic FX unportable (§E6) |
| `ClassData.lua` | 392 | yes (vanilla base) |
| `SoundAlertData.lua` | 349 | partial — kit IDs inert, ships extracted OGGs (§E6) |
| `EditModeRegister.lua` | 213 | **no — replace wholesale** |
| `CooldownViewerEquip.lua` | 182 | yes |
| `CdmSeedTBC.lua` | 131 | template for a new WotLK seed |
| `AlertData.lua` | 100 | regenerated for WotLK, not copied (§E6) |
| `RacialsTBC.lua` | 55 | template |
| `Assets.lua` | 50 | partial (swipe art unused in v1) |
| `CooldownViewer.xml` | 448 | needs `MaskTexture` + `GridLayoutFrame` surgery |

---

## B. Architect decisions (locked — flag before deviating)

### B1. No Edit Mode. Movers + options tab instead.

`EditModeRegister.lua` is written against `NE.editmode` — a **6,441-line retail Edit Mode
reimplementation** (`ReferenceAddons/NewEra/EditMode/`) that this addon does not have and will not
port. It uses `EM.Register` with a full settings codec (`system` / `systemIndex` / `defaultSettings` /
`settings` / `options`), `EM.GetFrameSettingStored`, `EM.const.StoredToDisplay`,
`EM.RegisterBottomManaged`, `EM.UpdateBottomManagedFrames`, `EM.RegisterToggleableFrames`,
`EM.ShouldShowActivity`, `EM.RepositionHandle`, `EM.AtLogin`.

DragonUI's equivalent is **position-only**: `core/movers.lua` is a drag handle that persists a point
string; `modules/editor_mode.lua` adds a grid overlay and a reset button. No per-frame settings popup,
no options metadata, no bottom-managed stack, no settings codec. **DragonUI is read-only** (CONTRACTS
§0) so we cannot extend it.

> **CORRECTION — found on the first in-game test, after this section was written.** DragonUI has
> **two independent** positioning systems and only one is what `/dui edit` drives:
>
> | system | registered via | shown by |
> |---|---|---|
> | `addon.MoversSystem` (`core/movers.lua`) | `NE.RegisterPanel` | **nothing** — `ToggleConfigMode` sits behind a dead `elseif` in `core/commands.lua:31`; `addon.EditorMode` always exists and wins the first branch |
> | `addon.EditableFrames` (`core/api.lua:551`) | `addon:RegisterEditableFrame` | `/dui edit` → `EditorMode:Show` → `addon:ShowAllEditableFrames` |
>
> An always-on HUD frame MUST use the second, or it registers cleanly and is then silently never
> shown. `NE.RegisterHUDFrame` (integration/Register.lua) is the seam; `NE.RegisterPanel` stays
> correct for toggled WINDOWS, where a MoversSystem handle is fine.
>
> **And `RegisterEditableFrame` alone is not enough** — it only records metadata. The drag
> affordances (`RegisterForDrag`, `OnDragStart`/`OnDragStop` with its auto-save, the green nineslice
> overlay, the label) are attached by DragonUI's frame FACTORY, `addon.CreateUIFrame`
> (`core/api.lua:255`). `addon.HideUIFrame`, which the editor calls on each registered frame, only
> does `SetMovable(true)` / `EnableMouse(true)` and shows an overlay a plain `CreateFrame` does not
> have. So the required pattern — the one `modules/castbar.lua` uses with `CastbarModule.anchor` —
> is: build a `CreateUIFrame` **anchor**, register the ANCHOR, and pin the real content to it.
> `NE.RegisterHUDFrame` does this and keeps the anchor's size synced to the content via
> `OnSizeChanged`.
>
> Two further gotchas found with it: DragonUI's `ApplyUIFramePosition` reads `x`/`y` gated on an
> `override` flag that nothing sets, while `SaveUIFramePosition` writes `anchor`/`posX`/`posY` —
> they do not round-trip, so position restore is ours. And registration must happen at
> `PLAYER_LOGIN`, not file load, matching every other NewEra module.

**Decision:** delete `EditModeRegister.lua`. Replace with:
- one DragonUI mover per viewer, via the existing `NE.RegisterPanel` path in `integration/Register.lua`
- the ten settings rendered in the DragonUI_Options "New Era" tab

`getOpt` (`CooldownViewer.lua:141`) is the single chokepoint every setting reads through, so
retargeting it at our own DB table is a contained change. The whole `M.CDV_CODEC` retail-int mapping
(`CooldownViewer.lua:126-139`) and the `sliderToStored` / `StoredToDisplay` conversions go away —
we store display values directly.

Cost: ~300 lines of new glue instead of 6,441 lines of ported Edit Mode.

**Note on precedent:** `modules/character/EditModeRegister.lua` declines Edit Mode on the grounds
that it is "scoped to always-on HUD frames, NOT toggled windows." The Cooldown Manager *is* a
persistent HUD frame — it is the first module that rule would say *should* have one. We are declining
anyway, because the cost is the entire Edit Mode system and DragonUI's movers cover the actual need
(position + scale). Revisit only if per-viewer settings prove unusable in the options tab.

### B2. Four independent frames, not a combined group.

Follow the source's current SPLIT model (`CooldownViewer.lua:240-245`): Essential / Utility /
BuffIcon / BuffBar are four independently positioned frames. The older combined-container approach is
already reverted upstream; do not resurrect it. Default anchors (BOTTOM of UIParent):
Utility y=240, Essential y=310, BuffIcon y=370, BuffBar x=420 y=430.

### B3. No bottom-managed stacking.

`EM.RegisterBottomManaged` reflows the viewers above the action-bar tower as bars are added. There is
no DragonUI equivalent. Viewers sit where the user puts them. Drop the `OnSizeChanged` restack hook
(`EditModeRegister.lua:159-164`) with it.

---

## C. Platform gaps (verified against ClassicAPI + DragonUI, 2026-07-25)

### C1. `GridLayoutFrame` — MISSING, must build

All four viewer frames inherit it (`CooldownViewer.xml:348,374,400,427`). The layout code depends on
`:Layout()`, `layoutIndex`, `stride`, `childXPadding`/`childYPadding`, `layoutFramesGoingRight`,
`layoutFramesGoingUp`, `alwaysUpdateLayout`, `ignoreInLayout`, `ResizeLayout`.

ClassicAPI ships `AnchorUtil.CreateGridLayout` / `GridLayoutMixin` **helpers** (`Util/AnchorUtil.lua:49-101`)
but **not** the `GridLayoutFrame` XML template. Grep confirms the only occurrence of the string in the
whole AddOns tree is the NewEra source XML itself.

→ Write `core/GridLayout.lua` (~150 lines) implementing LayoutFrame / GridLayoutFrame mixin semantics,
applied in Lua at frame creation rather than via XML `inherits`. Reusable by any future HUD module.

### C2. `<MaskTexture>` — MISSING, cannot polyfill

Used in all four item templates for the rounded icon mask (`CooldownViewer.xml:56,134,208,279`).
MaskTexture is a Legion widget. It does not exist on 3.3.5a, no polyfill is possible in Lua, and an
unknown XML node risks failing the entire file's parse. CONTRACTS §0 already lists `SetMask` as a hard
rule, and `qa/staticcheck.sh` greps for it.

→ Drop the mask. Keep the `iconoverlay` art layered on top, crop the icon with `SetTexCoord`
(~0.07–0.93). `core/ButtonSkin.lua` already establishes this pattern.

### C3. `Cooldown:SetSwipeTexture` / `SetEdgeTexture` / `SetUseCircularEdge` — MISSING

WoD+ APIs, called at `ItemMixins.lua:70-71,917-918`. ClassicAPI's `Util/Cooldown.lua` is a private
quadrant-based `CooldownCapture` renderer reached through `Private`, **not** a widget-method polyfill —
it exports nothing that satisfies these calls.

→ Accept the engine's built-in sweep. Guard the calls (`if self.Cooldown.SetSwipeTexture then`) — the
source already does at line 70. The DF swipe/edge art registered in `Assets.lua` (FDIDs 6731092,
5423465) goes unused in v1. Cosmetic only.

**Unverified:** whether 3.3.5a's Cooldown widget has `SetDrawEdge`. ClassicAPI's `CooldownFrame_Set`
calls it unconditionally (`Util/Cooldown.lua:12`). Confirm before relying on it.

### C4. `self:RegisterUnitEvent(...)` — MISSING as a widget method

Called throughout the viewer `OnLoad`s (`CooldownViewer.lua:307-324`, `1321`). ClassicAPI provides
`EventHandler.RegisterUnitEvent(Object, Event, ...)` as a **namespaced function**
(`Util/EventHandler.lua:189`, exported at `:270`), not a method on the frame metatable.

→ Small shim in `compat/Compat.lua` adding the method to a frame, delegating to the ClassicAPI
dispatcher. Cheap and reusable.

### C5. `CooldownFlash` flipbook — ALREADY SOLVED

Good news: `ItemMixins.lua:463` implements the flipbook as a hand-rolled OnUpdate texcoord stepper,
written precisely because Era lacked retail's animation system. Ports as-is.

### C6. Present and usable

`NE.tex` / `RegisterLocal` / `SetAtlas` (`core/Texture.lua`), `NE.FrameUtil.PinPixelPerfect`,
`NE.Log`, `NE.flavor`, `CreateFromMixins` (ClassicAPI `Util/Mixin.lua`), `C_Timer`, `C_Item`,
`C_Container`. The settings panel builds on `ButtonFrameTemplate`, which ClassicAPI provides
(`Templates/UIPanelTemplates.xml`).

### C7. Missing NewEra helpers — small substitutions

| Symbol | Used for | Substitution |
|---|---|---|
| `NE.EV_LEARNED_SPELL` | learn-spell event name | one-line const, `LEARNED_SPELL_IN_TAB` |
| `NE.spellbook.SPELLID` | rank expansion (`CdmSeedTBC.lua:95-109`) | build by scanning the spellbook at login — do **not** ship a db2 dump |
| `NE.actionbar1.procglow` | proc/activation glow (`CooldownViewer.lua:1026-1028`) | LibCustomGlow (already embedded, see `modules/spellbook/Spellbook.lua`) + 3.3.5a's `IsSpellOverlayed` / `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` |
| `NE_CDM_HIDDEN` | generated all-cooldowns superset | optional — code fails open (`CooldownViewer.lua:622`) |
| `NE_SPELL_RACEMASK` | race-gating (`CooldownViewer.lua:654`) | optional — fails open by design |

---

## D. Data work (WotLK)

The engineering above is bounded; **this is the main authoring cost.**

`CdmSeedTBC.lua` (131 lines) + `RacialsTBC.lua` (55) are the templates. Both are flavour-guarded
(`if not (NE and NE.flavor == "tbc") then return end`) and purely additive over the vanilla
`ClassData.lua` base. A `CdmSeedWotLK.lua` follows the identical shape.

Needed:
- **Death Knight in full** — absent from every table; new class in 3.3.5a.
- **WotLK additions for the other nine.** Non-exhaustive: Warrior Bladestorm/Shockwave; Paladin
  Divine Storm/Hand of Protection-Freedom-Sacrifice; Hunter Explosive Shot/Call of the Wild; Rogue
  Fan of Knives/Killing Spree/Shadow Dance; Priest Penance/Dispersion/Hymn of Hope; Mage Deep
  Freeze/Mirror Image/Living Bomb; Warlock Metamorphosis/Haunt/Demonic Circle; Shaman Feral
  Spirit/Thunderstorm/Riptide; Druid Starfall/Berserk/Wild Growth/Survival Instincts.
- **Buff-viewer seed.** Per `CdmSeedTBC.lua:83-89`, seed only *permanent state toggles* (armors,
  aspects, forms, shields) as `icon`. The ≤120s auto-window (`BUFF_TRACK_MAX_DURATION`,
  `CooldownViewer.lua:1115`) handles short procs. Do **not** seed long maintenance buffs — upstream
  removed those as clutter.

**Sourcing rule (CLAUDE.md prime directive, restated in `CdmSeedTBC.lua:21-26`):** every spellID must
come from the 3.3.5a client data, not memory. Store one representative rank per ability; the runtime
rank resolver (`highestKnownRankID`) picks the learned rank live.

---

## E. Phasing

| Phase | Scope | Exit criterion |
|---|---|---|
| **0** | `core/GridLayout.lua`; `RegisterUnitEvent` shim; `EV_LEARNED_SPELL`; spellbook rank table. No CDM code. | A throwaway grid of 12 test frames lays out, wraps at stride, and reflows on padding change. |
| **1** | Essential + Utility viewers. Mask and swipe stripped. One mover each. Settings in options tab. | Icons appear, swipe on cast, timer counts down, `/dnetest` PASS. The "does it feel right" checkpoint. |
| **2** | `CdmSeedWotLK.lua` + `RacialsWotLK.lua` + Death Knight. | Every class shows a sensible default set at 80. |
| **3** | ~~BuffIcon + BuffBar (aura-driven; more moving parts).~~ **DONE** — see §E2. | Buff bars track, auto-window catches procs, no empty-row churn. |
| **4a** | `Alerts.lua` + `SoundAlertData.lua` + `AlertData.lua` — the ENGINE and its stores. **DONE** — see §E6. | Assigning an alert or sound programmatically makes it fire. |
| **4b** | The `CooldownViewerSettings/` panel: spell picker, per-spell alert/sound assignment, drag reorder, presets. Re-scoped in §E6. | Alerts, sounds and spell visibility are all settable from the UI. |

Phases 1 and 2 are the shippable unit. Phase 3 onward is optional polish.

---

## E1. Implementation notes (added after building Phases 0–1)

Three things the scope did not anticipate, all resolved:

1. **`GetSpellInfo` position 7 is `castTime` on 3.3.5a, not `spellID`.** The WotLK signature is
   `name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange` (confirmed by
   `!!!ClassicAPI/Util/C_Spell.lua:39`). The source's `highestKnownRankID` is built entirely on
   `select(7, GetSpellInfo(name))`, so ported verbatim it would return e.g. `1500` for a 1.5s cast
   and use it as a spell ID — silently, since that is a plausible-looking number. This promoted
   `core/SpellRanks.lua` from a convenience to **load-bearing**: it is the only correct source of
   "highest rank the player knows" on this client.

2. **`RegisterUnitEvent` could not be delegated.** !!!ClassicAPI implements the semantics
   (`Util/EventHandler.lua:189`) but only inside its `Private` namespace — never exported — so
   `compat/Events.lua` implements it on the Frame metatable instead (RegisterEvent + a per-frame
   allow-set enforced by wrapping that frame's OnEvent).

3. **`Rebuild → RefreshLayout → UpdateVisibility → Show → OnShow → Rebuild` is a re-entrancy
   cycle.** The client only fires `OnShow` on a hidden→shown transition, so it settles at depth two
   rather than recursing forever — but that is an implicit dependency on client behaviour. Guarded
   explicitly in `Viewers.lua:Rebuild`.

Also deferred deliberately in Phase 1: `CooldownViewerEquip.lua` (trinket/potion discovery) is
stubbed to return empty, with the consuming loop left in place so the Phase 2 port drops in.

## E2. Phase 3 notes (aura viewers)

Built out of order, ahead of Phase 2, because the buff viewers need **no class data**: they read
live auras, not curated cooldown lists. Three parts:

- `AuraItemMixins.lua` — the BuffIcon tile (reverse swipe = aura elapsed, stack count, dispel
  border) and the BuffBar row (depleting StatusBar + pip, driven by a per-frame OnUpdate off cached
  expiration/duration rather than a per-frame aura scan).
- `BuffViewers.lua` — both viewer frames plus the shared aura-scan rebuild.
- Tracked-aura pool in `CooldownViewer.lua` — ONE pool as retail models it: each aura is `icon`,
  `bar` or `hidden`, so a bar-assigned aura never also renders as an icon.

Model: any player buff with `0 < duration <= 120s` auto-tracks, which is what makes trinket, potion
and proc buffs work without enumerating them. Longer buffs and permanent toggles are excluded, so
the viewers stay quiet out of combat. Explicit assignments override the window in both directions.
Target auras are a secondary source for EXPLICITLY tracked entries only — never the auto window,
which would flood the viewer with every enemy debuff.

**The trap worth naming:** the 1.15 source scans with
`local name, icon, count, _, duration, expiration, _, _, _, spellID = UnitBuff("player", i)` — the
MODERN return layout. On 3.3.5a `rank` occupies index 2 and shifts everything after it, so ported
verbatim `icon` receives the rank string and `duration` the caster. All scanning here goes through
`NE.aura` (core/AuraSnapshot.lua), which owns the correction in one place. `test_boot.lua` asserts
the icon comes from index 3 specifically, as a regression guard.

Two stride subtleties preserved from upstream, both of which otherwise wrap the stack into a
phantom extra column: `GetStride` counts LAYOUT children (has `layoutIndex`, not `ignoreInLayout`)
rather than SHOWN ones, and `BuffBarItem:UpdateShownState` keeps `ignoreInLayout` mirroring
visibility.

## E3. Phase 2 notes (WotLK data)

131 abilities across all ten classes, including the whole of Death Knight (9 Essential, 15 Utility)
which had no vanilla base at all. Additive appends onto `ClassData.lua`, same shape as
`CdmSeedTBC.lua`.

**Every ID is generated from this client's own data, not typed from memory** — see
`tools/cdm-spellgen/`. `Spell.dbc` and `SkillLineAbility.dbc` are extracted from the locale MPQs
(`Data/enUS/`, not the base archives), spells are attributed to classes via each skill line's
ClassMask, and each authored ability NAME resolves to the rank-1 castable ID. "Castable" is defined
as the lowest-rank, lowest-ID entry carrying a real cooldown (> 1.5s) — which is what separates an
ability from its triggered sub-spells: Penance resolves to 47540, not its 47666/47750 heal and
damage triggers; Death Grip to 49576, not 49560/49575.

Only the curation is hand-authored: which ability is Essential vs Utility. An unresolvable name is
a hard error rather than a silent omission, and `verify.py` independently re-reads the DBC to assert
every emitted ID exists, matches its comment, has a cooldown, is rank 1, and is unique. That gate
caught three entries that had no business in a pressable-cooldown list — Immolation Aura and Demon
Charge (rank `Demon`, Metamorphosis-form only) and Reincarnation (rank `Passive`).

Column positions were located empirically rather than assumed: `Spell.dbc` name 136, rank 153,
RecoveryTime 29, CategoryRecoveryTime 30 (cooldown is the max of the last two). An early attempt to
find the cooldown column by matching remembered durations failed outright — a small reminder of why
the sourcing rule exists.

**Known gap:** `Data/patch-4.MPQ` and `Data/patch-S.mpq` are encrypted and unreadable. If the server
overrides spell data there, these IDs reflect the stock client. Repeated in the generated file's
header.

## E4. Learn-gate fix (after first in-game test of Phases 2-3)

Reported: a Disc priest's **Penance** and a Holy priest's **Guardian Spirit** never appeared despite
both talents being taken, and **Divine Hymn** never appeared on a level-squished server where the
character knows it at 60. All three are one fault — the learn-gate, not the data.

The source checks `IsSpellKnown(spellID)` then falls back to `GetSpellInfo(name)`. Both fail here:

- `IsSpellKnown(id)` tests **one exact rank**. Our curated lists key each ability by its rank-1 id,
  so the check goes false the moment the player trains rank 2 — which is most talent abilities.
- `GetSpellInfo(name)` is a spell-database lookup on this client, not a membership test.
- Neither consults the spellbook, and neither is level-aware — which matters on a squished server.

Fixed by asking the **spellbook, by name** (`SB.IsSpellNameKnown`, core/SpellRanks.lua). That is
authoritative, rank-agnostic and level-agnostic. The name set is built from `GetSpellBookItemName`
alone — deliberately without id resolution — so an entry whose `GetSpellLink` can't be parsed still
counts as known. The old checks remain as fallbacks, so the change can only widen what shows.

Two supporting changes: the rank table now builds lazily on first use (viewers rebuild on
`PLAYER_ENTERING_WORLD`, which can precede the deferred `SPELLS_CHANGED` build), and
`SB.OnRebuilt` lets the viewers re-source after training or a spec switch.

`/necdm` prints the gate's decision per curated spell — book / IsSpellKnown / byName — so the next
report of a missing icon doesn't need guesswork.

## E5. Custom-list shadowing (the second half of the "missing abilities" report)

The learn-gate fix in §E4 was necessary but not sufficient. `/necdm` then showed the real fault:

```
hidden Holy Fire  id=14914  book=true  IsSpellKnown=true  byName=true
```

Every check passing, still hidden — so the gate was never the filter. `10 curated, 3 shown` was the
tell.

`M.GetItemMeta` is a read-only query, called from `ItemMixins:SetSpell` for **every icon on every
rebuild** — and it called `GetEditableList`, which SEEDS AND PERSISTS a custom list from the curated
defaults. So the first time any viewer built, it froze the then-current spell list into
SavedVariables; `GetActiveSpellList` took the `custom` branch from then on and ignored the curated
tables permanently. Every ability added later — the entire WotLK seed — was invisible on any
character that had run an earlier build.

Fixes:
1. `GetItemMeta` now uses `GetCustomList` (read-only). **A query must never pin persistent state.**
2. `M.MigrateStaleCustomLists`, versioned and run once at boot, clears lists that were never
   deliberately authored. Until the Phase 4 picker exists there is no way to author one, so every
   stored list is an artifact and clearing it loses nothing the user chose.
3. `/necdm` now reports when a custom list is shadowing the curated table. Its absence from the
   first version is exactly why this took two rounds to find.

Upstream carries the same guarded one-time reset, for the same reason — its boot block notes a
stale snapshot was "hiding the new defaults". That block was dropped along with
`EditModeRegister.lua`; this restores its intent.

## E6. Phase 4a notes (alerts, sounds, and the assignment menu)

§F2 asked for a re-scope before committing. Doing it changed the shape of the phase.

**What did not port: the pandemic border FX** (~130 of `Alerts.lua`'s 520 lines). Upstream renders
the `refresh` alert with a 1:1 port of retail's `CooldownPandemicFXTemplate` — a ring plus three
cascading glows, every one clipped to the ring by a `MaskTexture`. Two independent blockers:

- MaskTexture is not merely missing here. ClassicAPI defines `CreateMaskTexture` / `AddMaskTexture`
  as `Private.Void` ("potentially impossible to implement", `WidgetAPI.lua:279/302/476`) and Cell's
  polyfill returns an inert dummy. The calls would *succeed and clip nothing*, leaving three
  full-quad glows scaling to 1.5x as square smears across the icon and its neighbours — worse than
  no FX, and silently so.
- `Animation:SetTarget` does not exist on 3.3.5a either (zero occurrences in the whole AddOns tree).
  Animations act on the region owning the AnimationGroup, so one-group-drives-three-textures has no
  equivalent.

The atlases are absent too. So `refresh` renders through LibCustomGlow — already embedded, already
in the TOC, and what §C7 nominated for the proc-glow substitution — tinted pandemic-orange to keep
the one legible part of the retail look.

**What the sound port actually required.** Upstream's fallback path, `PlaySound(kit)`, is *dead* on
3.3.5a: this client's `PlaySound` takes a name string, and `PlaySoundKitID` takes a 3.3.5a kit index,
not a six-digit TWW id. Nothing retail-numbered can make a sound. The only working route is playing
audio by file path, so the 67 OGGs upstream extracted are shipped in `Sounds/cdm/` and played with
`PlaySoundFile` (`.ogg` is fine here — DBM has shipped them on this client for years). The retail kit
id survives purely as the stable assignment key. The whole `Short` category (26 entries) is dropped:
upstream never had extractable audio for it, so here it could only ever be 26 menu entries that play
nothing.

**`AlertData.lua` is regenerated, not copied.** Upstream's tables are vanilla-only. WotLK adds Kill
Shot (a genuine third execute ability) and Victory Rush, and *removes* Mongoose Bite's dodge gate in
3.1.0 — listing it would flash the icon every time it came up, the exact behaviour the data gate
exists to prevent. `tools/cdm-spellgen/gen_alertdata.py` resolves every rank from the client DBCs.
Two impostor classes had to be filtered, both found by inspecting output rather than by assumption:

- Rank text cannot discriminate. 3.3.5a gives Overpower rank 1 (7384) an **empty** rank string while
  its ranks 2-4 are labelled — and those higher ranks appear in no skill line at all, so Overpower is
  single-rank on this client. A "keep the ranked rows" filter drops the real ability and keeps four
  NPC copies of Riposte.
- `SkillLineAbility` class attribution fixes both. Applied *first*, the "drop unranked siblings" rule
  then safely removes triggered sub-spells like Execute's damage component (20647).

**The bug the harness caught: preferences were keyed on a moving id.** `ItemMixin.spellID` holds the
*learned rank*, not the listed one — Mind Blast's tile reports 10947, not the curated 8092. Keying
alerts and sounds on it would have silently orphaned every assignment the moment the player trained
the next rank. `_baseSpellID` / `GetSettingsKey()` now carries the stable id, and the harness asserts
the two differ. This is the same rank gotcha the cooldown path already documents, resurfacing in a
new place.

**The assignment surface was tried as a right-click menu, and removed.** Alerts and sounds are
strictly opt-in per spell, so 4a otherwise ships dormant. `ItemMenu.lua` put the choices on the icon
itself. It did not open in-game, and rather than debug a surface the Phase 4b panel replaces, the
owner called it: delete it and do assignment in the settings panel. So the ENGINE and its stores
ship here and nothing drives them yet — the options tab says so rather than advertising a way in
that does not exist.

`M.SetSpellEnabled` / `M.IsSpellEnabled` survive that removal and are the panel's seam for showing
and hiding a spell. `SetSpellEnabled` is the only caller of `GetEditableList`, which is the point of
the §E5 fix: seeding a custom list is correct exactly when the user has just chosen something.

**Phase 4b, re-scoped.** `CooldownViewerSettings/` is 2,139 lines across six files, and its retail
dependencies are heavier than §F3 assumed: `MenuUtil` (absent), `GLOBAL_MOUSE_UP` (retail 9.x,
absent — `Reorder.lua` is built entirely on it), `LargeSideTabButtonTemplate` (absent), clipboard
export (no `CopyToClipboard` on 3.3.5a), and the CDM side-tab art. It is a phase in its own right,
not a tail on this one. The per-spell menu covers the assignment need in the meantime.

## E7. Faults found on the first in-game tests of Phase 4a

All of these predate this phase. Each had been invisible because a harness stub was more generous
than the real client — a pattern worth noting in its own right: every one of these was found by a
player looking at the screen, not by the 156 assertions.

1. **Every icon rendered grey.** `RefreshIconColor` called `IsUsableSpell(self.spellID)`. On 3.3.5a
   that function takes a spell NAME, or a spellbook INDEX with a bookType — never a spellID. Given
   one it reads it as an index far past the end of the book and returns **nil**, without erroring.
   nil is neither usable nor out-of-mana, so every icon fell through to `ICON_UNUSABLE` and the
   whole viewer dimmed to 40%. DragonUI's own action bars pass a name
   (`modules/actionbars/extrabar.lua:1049`). The harness stub returned a blanket `true` regardless
   of argument, which is exactly why it never caught this; it now mimics the client.

2. **The ready flash never played, for two compounding reasons.** `NE.tex.GetAtlasRect` returns four
   NUMBERS, not a table, and the flipbook stepper indexed the result as `atlas.right` — so `atlas`
   was the number `left` and every access inside an OnUpdate was an error waiting to happen. It
   never got that far, because the "art not shipped, degrade quietly" guard was
   `if not getFlashAtlas()`, and `GetAtlasRect` returns `0, 1, 0, 1` for an unknown atlas — `0` is
   truthy in Lua, so the guard passed precisely when the art was missing and `ScheduleFlash` bailed
   for the wrong reason. `NE.tex.HasAtlas` is the correct test. The retail GCD flipbook is not
   registered on this client, so the sprite path stays dormant and an undecorated alpha pulse on
   `Interface\Buttons\ButtonHilight-Square` (a base texture DragonUI itself uses) provides the cue.
   The sprite path takes over automatically if the atlas is ever registered.

3. **Icons went grey on cast and STAYED grey.** Distinct from fault 1, and only visible once that
   was fixed. Every event the viewer listens for — `SPELL_UPDATE_COOLDOWN`, `UNIT_SPELLCAST_*`,
   `BAG_UPDATE_COOLDOWN` — marks a cooldown STARTING or changing. **3.3.5a fires nothing when one
   expires** (`Alerts.lua`'s header already said so, in the course of explaining why the ready
   transition has to be polled). The swipe still completed, because the Cooldown widget animates
   itself in C, but no Lua re-ran, so the `SetDesaturated(true)` from the start of the cooldown
   persisted until some unrelated event refreshed the tile — usually the player's next cast. Each
   item now schedules its own refresh for the moment its cooldown ends, keyed on the end time so
   repeated refreshes during one cooldown don't stack timers.

   The harness could not have caught this: its `C_Timer.After` stub ran every callback immediately
   at the next drain, regardless of delay, so a scheduled refresh would have "worked" no matter
   what. The stub now honours the delay, and the regression test asserts the tile un-desaturates
   **with no event fired at all**.

4. **The ready flash was too faint to notice.** Fixing the plumbing (fault 2) was not enough: an
   alpha blink on an icon-sized quad barely registers against the icon art beneath it. The fallback
   burst now snaps to full brightness and expands to ~1.7x the icon while fading, in warm gold on an
   ADD blend, and sits two frame levels above the Cooldown swipe it plays over.

5. **`AceLocale: Missing entry for 'CooldownViewerBuffBar'` on every login.** DragonUI's
   `CreateUIFrame` labels the editor handle with `addon.L[frameName]`, and AceLocale's read metatable
   fires a non-breaking error for any undefined key. Harmless but noisy, once per registered frame.
   The table `GetLocale` returns has an `__index` hook but **no `__newindex`**, so `NE.RegisterHUDFrame`
   now seeds its own key — a plain assignment into a runtime table, not a change to DragonUI — which
   both silences the warning and upgrades the handle's label from `CooldownViewerBuffBar` to
   "Buff Bars".

## F. Open questions / unverified

1. **`Cooldown:SetDrawEdge` on 3.3.5a** — ClassicAPI assumes it exists (C3). Confirm.
2. ~~`Alerts.lua` and `SoundAlertData.lua` not dependency-mapped.~~ **Done — see §E6.**
3. ~~`CooldownViewerSettings/` blockers named but not designed.~~ **Done — scoped in §G.** Two of
   the blockers §E6 listed were wrong; see §G.1.
4. **Taint.** The viewers are pure display frames with no secure attributes, and `EnsureGroup`
   reparents them freely, so taint should be a non-issue — but Phase 1 must verify no combat-lockdown
   errors on `SetPoint` during a live restack.
5. **Whether four separate movers is tolerable UX** in DragonUI's editor mode versus one grouped
   handle. Decide during Phase 1 with the frames on screen.

---

# G. Phase 4b — the settings panel (`/cdm`)

Scope for porting `ReferenceAddons/NewEra/CooldownViewerSettings/` (2,139 lines / 6 files) as a
**standalone window opened with `/cdm`**, matching upstream's own choice of a free dialog rather
than a managed UIPanel.

This is where spell picking and per-spell alert/sound assignment live. Phase 4a shipped the engines
and their stores with nothing driving them; this closes that.

## G.1. Corrections to §E6

Two blockers named there do not exist. Checking beats remembering:

- **`LargeSideTabButtonTemplate` is not a problem.** Upstream synthesized it because Era lacks it —
  and so did we, already, for another module: `NE.tabs.MakeSideTab` (`core/Tabs.lua:222`) is the
  same substitution, complete with tooltip wiring. The Spells/Auras side tabs use it as-is.
- **Clipboard export is not a problem.** `CopyToClipboard` appears nowhere in the source. Export
  goes through a `StaticPopup` with a pre-selected edit box (`Presets.lua:260`) — the classic
  manual-copy pattern, native on 3.3.5a.

Also better than expected: **no `WowScrollBox` / `ScrollUtil` anywhere.** The body is a plain
`UIPanelScrollFrameTemplate` with a `SetScrollChild` (`Panel.lua:377`), which is native here and
which `NE.scrollbar.Reskin` already knows how to restyle.

## G.2. What already exists

| Need | Have | Where |
|---|---|---|
| Side tabs | `NE.tabs.MakeSideTab` | `core/Tabs.lua:222` |
| Window chrome | `NE.chrome.Apply` | `core/PanelChrome.lua:277`; precedent `modules/collections/Window.lua:264` |
| Scrollbar restyle | `NE.scrollbar.Reskin` | `core/ScrollbarReskin.lua:156` |
| Portrait cutout | `NE.portrait.ApplyCutout` | `core/Portrait.lua` |
| Open/close sounds | `NE.FrameUtil.WirePanelSounds` | `core/FrameUtil.lua:246` |
| Templates | `ButtonFrameTemplate`, `SearchBoxTemplate` (ClassicAPI); `UIPanelScrollFrameTemplate`, `UIPanelButtonTemplate`, `StaticPopupDialogs` (native) | — |
| Panel background art | `character-panel-background` (5882640) already registered | `modules/character/Assets.lua:35` |
| Alert + sound stores | shipped in Phase 4a | `Alerts.lua`, `SoundAlertData.lua` |
| Show/hide a spell | `M.SetSpellEnabled` / `M.IsSpellEnabled` | `CooldownViewer.lua` |
| ESC-to-close, slash command | `UISpecialFrames` + `SLASH_*` | precedent `modules/encounterjournal:643` |

## G.3. What must be built

1. **`core/Menu.lua` — a MenuUtil-shaped builder over `UIDropDownMenu`.** The highest-leverage
   piece by far. All three menu sites (`Categories.lua:42` item menu, `Panel.lua:192` settings menu,
   `Presets.lua:348` layout menu) are written against MenuUtil's builder API — `root:CreateTitle`,
   `CreateButton`, `CreateRadio`, `CreateDivider`, arbitrarily nested. Reimplementing that API over
   3.3.5a's `UIDropDownMenu` (~120 lines) lets all three port close to verbatim, instead of
   rewriting each by hand. Use ClassicAPI's `C_UIDropDownMenu`, which grows
   `C_UIDROPDOWNMENU_MAXLEVELS` on demand — the sound menu needs four levels
   (item → Ready Sound → category → entry) and the native one caps at two.

   This is also the correct home for the Phase 4a right-click menu that was deleted: upstream's
   `showItemMenu` already carries Move-to / Remove / Ready Sound / Alert (type, FX, window), and it
   maps onto the 4a API almost one-to-one. Only the FX enum differs — upstream uses `1 = ants`,
   `6 = flash`; ours is `1/2/3` over LibCustomGlow (`AL.FX`), so drive the submenu off `AL.FX`.

2. **Drag reorder without `GLOBAL_MOUSE_UP`** (`Reorder.lua`, 6 uses). That event is retail 9.x.
   The file already runs an `OnUpdate` driver while a drag is active, so the substitution is to
   watch `IsMouseButtonDown` transitions there and call the existing `endChange` / `CancelOrderChange`
   on release. ~30 lines changed, not a rewrite. `GetMouseFoci` → `GetMouseFocus` is already
   fallback-handled at `Reorder.lua:23`.

3. **`NE.listheader`** — the collapsible category header. Absent, but with in-repo precedent:
   `modules/character/Reputation.lua:68` notes the same gap and builds one inline.

4. **Small shims:** `NE.button.Skin` and `NE.dropdown.SkinStyle` (cosmetic — may no-op initially),
   `NE.OpenOptions` (point at our `NE.optionSections` tab), `SetShown` → the local `setShown`
   helper (10 sites, CONTRACTS §0).

5. **Art:** copy `7289697-cdmadvanced.blp` from the reference `Art/CooldownViewerSettings/`. Only
   two of its three glyphs are needed (`icon_cooldownmanager`, `icon_trackedbuffs`).

## G.4. Deliberate cuts

- **The Group Buffs side tab.** 12 references to `NE.groupbuff.filter`, a module this addon does not
  have. Two tabs, not three — `CDS.UpdateGroupBuffsTabState` goes with it.
- **`NE.editmode.Toggle` / `SelectFrame`** (4 refs). No Edit Mode here (§B1). Either drop the
  "position this frame" affordance or route it at `/dui edit`.
- **Presets / layouts** (`Presets.lua`, 378 lines) — self-contained and genuinely portable
  (StaticPopup + base64 + a hand-rolled parser, no `loadstring`), but it is a convenience on top of
  a picker that does not exist yet. Defer to last.

**Resolved — the Equip categories.** Owner's call: port `CooldownViewerEquip.lua` (182 lines) so
on-use trinkets and potions are trackable, and add the two source-pool categories back. Not yet done;
it is separable from the picker and does not gate 4b-3.

## G.5. Phasing

| Step | Scope | Exit criterion |
|---|---|---|
| **4b-1** | Window shell: chrome, Spells/Auras side tabs, scroll body, search box, `/cdm` toggle, ESC-close. **DONE** | `/cdm` opens and closes a correctly-chromed empty window |
| **4b-2** | `SettingsAdapter` + `SettingsCategories` grids, read-only. **DONE** | All categories render the player's real spells |
| **4b-3** | `core/Menu.lua` + the item context menu. **DONE** | **The payoff.** Spell visibility, alerts and sounds are all settable, and Phase 4a stops being dormant |
| **4b-4** | Drag reorder | Items can be dragged between categories and reordered |
| **4b-5** | Presets / import / export | Optional |

4b-3 is the milestone that matters; 4b-4 and 4b-5 are polish. Rough size: ~1,400 lines adapted from
the source plus ~200 of new shim, against 2,139 in the original — the difference being the Group
Buffs tab, Edit Mode wiring, and the retail menu framework.

## G.6. 4b-2 notes (adapter + grids)

**The Hidden section needed data that did not exist.** Upstream's Hidden is the opt-in catalog, and
it is driven by a generated `NE_CDM_HIDDEN` global — every class ability with a real cooldown.
Without an equivalent, Hidden could only ever re-offer spells the player had removed, which is an
undo list, not a picker. `tools/cdm-spellgen/gen_arsenal.py` emits `CdmArsenal.lua`
(`M.ARSENAL_BY_CLASS`, 303 abilities across ten classes) from the same `resolved.json` the Phase 2
seed came from, so it costs one thin emitter rather than new analysis.

Expect Hidden to look SHORT in game. Our curation is deliberately broad, so most of a class's
cooldown abilities already sit in Essential or Utility; what remains is the difference. That is the
intended behaviour — the section fills up as the player moves things out.

**`NE.listheader` substituted inline**, the same call `modules/character/Reputation.lua` made for the
same missing Core helper, using the client's own +/- collapse buttons.

**Bug worth recording: a tri-state predicate that only ever returned two.** `listHasEnabled` answers
"is this spell listed and enabled?" with true / false / **nil**, where nil means *not mentioned* and
is what sends `isPlaced` to the curated defaults. It returned `false` for a missing list instead of
nil, so the curated fallback was unreachable and every curated spell appeared in Hidden alongside
itself. Caught by asserting the two sets do not overlap — a property that is obvious to state and
was not obvious to eyeball.

## G.7. 4b-3 notes (the menu shim and the item menu)

**`core/Menu.lua` reimplements the MenuUtil builder API, not the menus.** Every menu in the source
is written as a generator that receives a root description and calls `root:CreateTitle`,
`CreateButton`, `CreateRadio`, `CreateCheckbox`, `CreateDivider`, nesting by adding children to a
returned description. Rebuilding that API once over `UIDropDownMenu` (~250 lines) means the three
menu sites port close to verbatim. Rewriting each by hand into the init-callback idiom would have
been more code in total and a fresh chance to get the level plumbing wrong at every site.

**Why ClassicAPI's `C_UIDropDownMenu` and not the native one.** The native 3.3.5a
`UIDROPDOWNMENU_MAXLEVELS` is a hard 2. The ready-sound menu is three deep — item → Ready Sound →
category → entry — and the alert menu is three as well (item → Alert → FX Style). ClassicAPI's copy
grows the cap inside `C_UIDropDownMenu_CreateFrames`. The native API is kept as a fallback (same
shape, different list-frame name prefix), so the shim still works two levels deep if ClassicAPI is
ever absent. `compat/COVERAGE.md` previously recorded this symbol as having "no current consumer";
`core/Menu.lua` is now that consumer.

**The tree is built separately from the render.** `NE.menu.BuildRoot` runs a generator and returns a
plain node tree with no widget touched. That is what makes menu CONTENT testable offline: the
harness builds the item menu, walks it, and invokes a leaf's callback to assert that selecting
"Cat" writes kit 316401 and previews it — none of `UIDropDownMenu` is stubbed. The 4b-3 block adds
26 assertions on that basis.

**Two client-behaviour traps in `UIDropDownMenu`, both worth remembering.**

1. *A submenu parent must be `notClickable`, not a no-op `func`.* `UIDropDownMenuButton_OnClick`
   toggles the row's Check texture **before** it looks at `func`, so a clickable-but-inert parent
   paints a stray checkmark on itself. Disabling the row leaves `OnEnter` — which is what actually
   opens the submenu — firing normally.
2. *`C_UIDropDownMenu_Refresh` cannot refresh our radios.* It keys off
   `frame.selectedName/selectedID/selectedValue`, which say nothing about a function-valued
   `checked`. Calling it would hide every check. The shim repaints a level's marks itself, from the
   predicates, after any radio or checkbox fires.

**One deliberate divergence from upstream: the FX enum.** Upstream's fx values index
`NE.groupbuff.VISUAL_ALERT` (`1` = marching ants, `6` = flash), an enum this addon does not have.
Ours is `AL.FX` — 1/2/3 over LibCustomGlow. The FX submenu is therefore *generated from* `AL.FX`
rather than hardcoding upstream's pair; porting those two lines verbatim would have silently
written `6`, for which there is no renderer. Pinned by a test that compares the submenu against
`AL.FX` rather than against a literal.

**The grid now shows its own state.** A tile with an alert or a ready sound configured carries a
corner badge, and its tooltip names both. Without that, the only way to read the configuration is
to right-click every icon in turn. Upstream's `common-icon-visual` glyph is not registered here, so
the badge uses upstream's own fallback (a gold dot) — asked via `HasAtlas` rather than by letting
`SetAtlas` fail, because a failed `SetAtlas` logs an ATLAS MISS and this runs once per tile per
rebuild.

**Both cog resets confirm first.** "Reset Spell Lists" and "Clear All Alerts" are irreversible until
4b-5 brings a snapshot store, so both route through a `StaticPopup`. The harness asserts the click
raises the popup rather than acting, then drives `OnAccept` separately.

### G.7.1 In-game faults found on the 4b-3 pass

Three reports, three unrelated causes. All three were invisible to the harness as it stood, and all
three are now covered — including negative checks confirming each new assertion fails against the
unfixed code.

**"Icons in the cooldown manager window are all greyed out."** Not the learn tint, and not the icon
textures: **alpha 0.25 on every tile, from the search filter.** ClassicAPI's `SearchBoxTemplate` has
**no `Instructions` FontString** — its placeholder *is* the edit box's text (`SearchBoxTemplate_OnLoad`
does `SetText(SEARCH)`, and `OnEditFocusLost` puts it back). So an untouched box reads back
`"Search"`, `RefreshLayout` handed that straight to `ApplyItemFilter`, and every tile whose spell is
not named "Search" dimmed. The 4b-1 line `if f.search.Instructions then … end` was a no-op guarding
a field that never exists, which is exactly why it looked fine. Every read now goes through
`CDS.GetSearchText`, which maps the placeholder to `""`. The harness sets `SEARCH` and seeds the box
with it before asserting the tiles stay at full alpha.

**"The selected alert or sound doesn't get reflected in the menu on reopening."** A **Lua idiom bug
in ClassicAPI's `C_UIDropDownMenu_AddButton`**:

```lua
local checked = type(info.checked) == "function" and info.checked() or info.checked
```

When the predicate returns **false**, `(true and false)` is false, so the `or` falls through to
`info.checked` — the function object, which is truthy. Every function-valued radio therefore
rendered as selected, and a menu where *everything* is ticked communicates nothing. DragonUI and
ClassicAPI are read-only (§0), so the fix is on our side: `core/Menu.lua` snapshots the predicate to
a **boolean** at build time. Nothing is lost — the tree is rebuilt from the generator on every open,
and `refreshChecks` re-reads the predicate on every click. Pinned by two assertions: exactly one
radio in a group reads selected, and `info.checked` is never a function *at any rendered level*
(the first version of that check scanned level 1 only, which holds no radios, and passed
vacuously).

**Panel size.** Owner asked for +30%. Applied as `PinPixelPerfect(f, 1.3)` — a **scale**, not larger
`PANEL_W`/`PANEL_H`. The grid geometry (38px tiles, 46px pitch, 7 per row, 344-wide category) is
upstream's probe-confirmed layout; growing the frame around unchanged tiles would only add margin.
`PinPixelPerfect` folds the multiplier into its pixel-snap target and re-applies it whenever the UI
scale changes.

**What this cost, and the lesson.** The harness could assert menu *content* but nothing about
*rendering*, so it could not have caught either of the first two. It now carries a small
`C_UIDropDownMenu` stand-in — deliberately **not** a reimplementation. Copying ClassicAPI's `and`/`or`
bug into a stub in order to "catch" it would be circular. What the stub records is the shape of the
`info` tables *we* produce, and the invariant that keeps us clear of the bug ("never hand the client
a predicate") is checkable without reproducing it.

### G.7.2 Alert engine faults (second in-game pass)

**"The FX come out green when actually used on the bars."** The preview was lying. `AL.Preview`
hardcoded the alert type `"usable"`, so every preview flashed the usable YELLOW regardless of which
event the player had just chosen — then the live icon glowed in that event's real tint (available
green, refresh pandemic-orange). `Preview` now takes the type and the menu passes the one being
configured. A preview whose whole job is "see it before you commit" has to show the colour you will
actually get.

**"The only FX Alert type that seems to do anything is available."** Two compounding causes.

1. **`IsUsableSpell(spellID)` again, in `Alerts.lua:262`.** The same fault fixed in
   `ItemMixins.lua:545` — 3.3.5a's `IsUsableSpell` takes a NAME or a spellbook index, never an id;
   given an id it reads it as an index past the end of the book and returns nil. `isSpellUsableNow`
   therefore returned false unconditionally, so the Usable event could never fire for anybody. The
   ItemMixins fix did not sweep for other call sites. It should have.

2. **The curated gate made Usable a dead entry for six classes.** `inUsableState` returned false for
   any spell not in AlertData's EXECUTE or REACTIVE tables — eight abilities across Hunter, Paladin,
   Warrior and Rogue. A Priest or a Mage could select "Usable" and nothing could ever happen. That
   gate is defensible upstream, where the alert can be attached to spells with no cooldown at all;
   here it contradicts the label. **Semantics changed:** Usable now means castable right now.
   EXECUTE stays as the stricter condition where it applies, because target health is something
   `IsUsableSpell` knows nothing about — without it Kill Shot would glow all fight instead of in
   execute range. `A.IsReactive` is no longer consulted at all: the client already reports Overpower
   and Revenge as unusable outside their proc window, so the curated check only restated it.
   `A.REACTIVE` stays in AlertData as data with no reader.

**The test that shielded the bug.** The 4a suite asserted, in as many words, *"a spell with no
execute/reactive entry never glows on 'usable'"* — and it passed, for the wrong reason: with
`isSpellUsableNow` hard-false, nothing glowed whatever the data said. The assertion agreed with the
bug and hid it until the owner reported the feature did nothing. **A test that encodes "this feature
is off here" cannot tell you the feature is broken.** Where the intended behaviour is negative,
assert the positive case somewhere too, or the negative one proves nothing.
