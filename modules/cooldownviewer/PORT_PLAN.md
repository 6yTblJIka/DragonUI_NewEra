# Cooldown Manager — Port Plan (Build Contract)

Downport of `ReferenceAddons/NewEra/CooldownViewer/` + `CooldownViewerSettings/` (Classic 1.15 /
TBC 2.5.x) onto 3.3.5a. Read `CONTRACTS.md` §0 first — every global convention there applies.

**Status:** Phases 0-4a, 4b-1 through 4b-5, 4c (the Settings tab), 5a (on-use trinkets) and 6 (loose
ends) implemented — the whole of both phasing tables except the deliberate cuts. Offline harnesses pass
(`qa/offline/`, 394 boot assertions). Phases 1-3 and the 4b-1 window shell are confirmed working
in-game; 4b-2 and 4b-3 are confirmed in-game (three faults found and fixed, §G.7.1/§G.7.2).

**Nothing is left that offline work can close.** Remaining: consumables (§G.9, parked as a stretch goal
by the owner — blocked on a generator pass, not on effort), and three items that need the game rather
than the harness — §F4 taint under a combat restack, §F5's four-movers-versus-one call, and an in-game
pass over 4b-4, 4b-5, 5a and 4c. See the end of §G.13.

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

1. ~~**`Cooldown:SetDrawEdge` on 3.3.5a**~~ — **answered on the evidence, and `/necdm` now prints the
   runtime answer.** ClassicAPI stubs `SetEdgeTexture` / `SetEdgeColor` / `SetEdgeScale` as
   "Incompatible (3.3.5)" (`Util/WidgetAPI.lua:1024-1026`) but does NOT stub `SetDrawEdge`, and its own
   cooldown-capture path calls `Self:GetDrawEdge()` unguarded (`Util/Cooldown.lua:204`) on every
   captured cooldown's OnShow — which would error constantly on every action button if the method were
   missing. `Process` injects unconditionally rather than filling gaps (`WidgetAPI.lua:1338`), so an
   absence from its table means native, not forgotten. Both call sites of ours guard anyway
   (`ItemMixins.lua:81`), so nothing depends on the answer; the `/necdm` line settles it rather than
   leaving an inference from someone else's code standing as fact.
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
- ~~**`NE.editmode.Toggle` / `SelectFrame`** (4 refs)~~ — **routed, in Phase 6 (§G.13).** Upstream's cog
  menu carried an "Edit Mode" entry that hid the window and toggled retail Edit Mode
  (`Panel.lua:211`); ours is a **per-viewer** "Position this viewer" button on the Settings tab, going
  through the new `NE.OpenFrameEditor` seam. Per viewer rather than once globally because DragonUI's
  editor can be told which frame to select, so the button under Buff Bars' sliders opens the editor
  with Buff Bars selected. The fourth ref, `RepositionHandle` (`CooldownViewer.lua:977` — re-anchor the
  drag rect as items come and go), needs no port: `RegisterHUDFrame` syncs the anchor to the content's
  size from the content's own `OnSizeChanged`.
- **`NE.OpenOptions`** (upstream's "Show Options" jump out to the addon's option surface) — **not
  ported, and now pointless.** The traffic runs the other way since §G.12: DragonUI's section is an
  enable toggle and a button that opens `/cdm`. A link back to a page holding one checkbox would be
  worse than its absence.
- ~~**Presets / layouts**~~ — deferred to last as planned, and **shipped as 4b-5** (§G.11) once the
  picker it sits on top of was working.

**Resolved — the Equip categories. DONE for trinkets (§G.9).** Owner's call was to port
`CooldownViewerEquip.lua` so on-use trinkets and potions are trackable. Trinkets shipped as Phase 5a
with one source pool ("Trinkets"), not two: the passive pool is cut because on this client it can
only ever contain on-use trinkets already listed in the active pool. Consumables are deferred on a
**data** blocker, not effort — `Item.dbc` carries neither item names nor item→spell links, so a
bucketed potion list cannot be generated from client data. §G.9 scopes the route through.

## G.5. Phasing

| Step | Scope | Exit criterion |
|---|---|---|
| **4b-1** | Window shell: chrome, Spells/Auras side tabs, scroll body, search box, `/cdm` toggle, ESC-close. **DONE** | `/cdm` opens and closes a correctly-chromed empty window |
| **4b-2** | `SettingsAdapter` + `SettingsCategories` grids, read-only. **DONE** | All categories render the player's real spells |
| **4b-3** | `core/Menu.lua` + the item context menu. **DONE** | **The payoff.** Spell visibility, alerts and sounds are all settable, and Phase 4a stops being dormant |
| **4b-4** | Drag reorder. **DONE** | Items can be dragged between categories and reordered |
| **4b-5** | Presets / import / export, and the snapshot pair that makes Revert real (§G.11). **DONE** | Layouts save, load, import and export; Revert undoes an apply |
| **5a** | On-use trinket discovery + the Trinkets source pool (§G.9). **DONE** | An equipped on-use trinket appears in `/cdm`, drags into Essential, and shows on the bar |
| **4c** | Third `/cdm` tab hosting every viewer setting; the DragonUI section shrinks to an enable toggle plus an Open button (§G.10 scope, §G.12 notes). **DONE** | Every setting is editable from `/cdm`, and no stored value is rendered in two windows |
| **6** | Loose ends (§G.13): the edit-mode affordance §G.4 never decided, §F1, and the 4b-1 vestiges. **DONE** | Every viewer is positionable from `/cdm`; no open question left that offline work can close |
| **5b** | Consumables, via a generated Spell.dbc effect table (§G.9) | **Parked as a stretch goal** (owner, this pass). Blocked on the generator, not on effort |

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

## G.8. 4b-4 notes (drag reorder)

**The one real downport is the drag's ending.** `GLOBAL_MOUSE_UP` is retail 9.x and upstream uses it
six times. But a drag already runs an `OnUpdate` to follow the cursor, so the release is detected
there instead, by watching `IsMouseButtonDown` transitions: left down→up commits, right down at any
point cancels. Same two outcomes, no event. `GetMouseFoci` → `GetMouseFocus` was already
fallback-handled upstream. Nothing else about the file needed changing.

**`Adapter.ReorderTo` / `Adapter.AssignAt` are new.** Our storage model keeps a per-category editable
list of `{spellID, enabled}`, so ordering is that list's order; the aura pool orders itself the same
way, which lets one function serve both. `AssignAt` is `Assign` followed by a `ReorderTo`, which is
what carries the drop POSITION across a category boundary — dropping onto a tile inserts at that
caret rather than appending.

**The off-by-one that every drag reorder has.** `ReorderTo` must recompute the target index AFTER
removing the dragged entry: pulling it out shifts everything below it up by one, so an index taken
beforehand overshoots by one whenever the item moved DOWN the list. Both drop-direction assertions
fail against the pre-removal version, which is the point of having two.

**Cuts.** `CDS.SetDragActive`, which illuminates the "+" drop slots this panel does not have. (The
equip-token branches were also cut here and have since been restored by §G.9.) The
consequence is that dropping on empty space does nothing; drop onto a TILE, or onto a category's
HEADER, which resolves to that category on the walk up. Enabling mouse on the category container
would make empty-area drops work too, but it risks the scroll frame's wheel handling for an
affordance the header already provides.

**Sounds.** 3.3.5a's `SOUNDKIT` (ClassicAPI `Util/SoundKit.lua`) is a dozen entries and carries none
of retail's cursor kits. The three names used here are confirmed present in this client's own
FrameXML, and each play is `pcall`ed and checks the `willPlay` return, so an unknown name is silence
rather than an error.

**Panel close cancels the drag**, hooked on `OnHide` rather than in `CDS.HidePanel`: the close button
and ESC both call `Hide()` directly. Without it a closed window would strand the cursor icon
(parented to UIParent) and leave the source tile dimmed and locked. The offline harness now fires
`OnHide` on a shown→hidden transition, matching the client — it previously fired only `OnShow`, so
this whole class of teardown bug was invisible to it.

## G.9. Phase 5a notes (on-use trinkets)

Port of `CooldownViewerEquip.lua` (182 lines) â†’ `modules/cooldownviewer/Equip.lua`. This is the
owner-approved item of Â§G.4, and it lands the *trinket* half in full.

**The model is opt-in, and that is the point.** An item cooldown has no viewer by default. It is
discovered, keyed by a stable token (`item:<itemID>`), and parked in a source pool â€” the "Trinkets"
section in `/cdm` â€” showing nowhere on screen until the player drags it into Essential or Utility.
Assignment is persisted per token in `cooldownviewer.equipAssign`, so re-equipping the same trinket
restores the choice. `"hidden"` has to be a *stored* value rather than a synonym for unassigned:
`GetEquipAssignment` falls back to the class default only when a token is genuinely absent, so an
explicit hide must occupy the key.

**Trinkets cost nothing in curation.** `GetInventoryItemID` gives the item in each trinket slot and
`GetItemSpell` gives its on-use spell; both come from the client at runtime. Nothing is typed.

### The token is the move key, not the spellID

`Adapter.GetItems` now returns a **mixed** list â€” numbers are spellIDs, tables are equip entries.
That is upstream's shape and it keeps the change small: a tile handed a table calls `SetEquipEntry`,
a tile handed a number calls `SetSpell`, and the menu and drag paths branch on `item.token`. The
alternative (promoting every spell to an entry table) would have touched the menu, the drag path,
the filter and the tests for no gain.

Routing an equip row through the spellID path is not a near-miss, it is a data corruption: it would
write the trinket's use-spell into the editable spell list, where it *survives unequipping the
trinket* and points at nothing. `Adapter.Assign` therefore refuses outright when either side of the
move is a source pool, and there is an assertion on that refusal.

**Pooled tiles must drop the binding.** A tile that held a trinket can be handed a plain spell on
the next rebuild. `clearEquipBinding` runs at the top of both `SetSpell` bodies; without it the
stale token keeps routing that row's right-click and drag through the equip path.

**An empty source pool is not rendered at all** â€” not as "(empty)". A player with no on-use trinket
should not be told about a Trinkets section; that would read as a broken feature rather than an
absent input. Stored categories still show when empty, because there an empty list is a state the
player chose.

**Reorder does not apply to an equip row.** It has no stored position â€” the viewer appends
discovered items after the spells â€” so dropping one inside its own category is a deliberate no-op.
Dragging a *spell* onto an equip row is also a no-op for the same reason: there is no index to
reorder against. Cross-category drops work normally.

**Events.** `UNIT_INVENTORY_CHANGED` triggers a full `Rebuild` on the viewers (a swap changes the
discovered set, not just a cooldown) and a `RefreshLayout` on the panel.

### Cut: the passive pool, for a data reason

Upstream's `GetEquipPassiveItems` walks the same two trinket slots and surfaces each one's **use**
spell as a trackable aura. So a proc trinket â€” the only kind for which a passive aura row would mean
anything â€” returns nil from `GetItemSpell` and never appears, and the pool can only ever contain
on-use trinkets that are already rows in the active pool. Upstream flags this itself ("Era has no
on-equip-aura data layer", `TODO(hydrate)`). Shipping it would add a second source section whose
contents duplicate the first. `equipPassive` and its half of the legal-target matrix go with it.

### Deferred: consumables (potions, healthstones, runes)

Upstream's `M.POTION_CATEGORIES` is a hand-curated table of ~45 **vanilla** item ids bucketed into
Healing / Mana / Healthstone / Soulstone / Combat, best-rank-first, so the runtime can show one slot
per bucket for the best item held. WotLK adds a tier to every one of those buckets. Typing those ids
in violates the prime directive, and **the 3.3.5a client cannot supply them**: `Item.dbc` carries no
item names and no itemâ†’spell link â€” both live server-side in `item_template` â€” so there is nothing
to generate a bucketed list *from*.

The way through is to classify at runtime by the use-spell's **effect**, which *is* client data:

1. Extend `tools/cdm-spellgen/dbc.py` to keep `Effect[0..2]` and `EffectBasePoints[0..2]` alongside
   the name/rank columns it already parses. It reads every field as `uint32` today, so this is a
   wider tuple, not a new parser. Locate the columns the way `name_col` is located â€” empirically,
   against anchors (spell 2050 Lesser Heal has `SPELL_EFFECT_HEAL`).
2. Emit `M.CONSUMABLE_SPELLS = { [spellID] = { bucket = "health"|"mana", magnitude = <basepoints> } }`
   for every spell whose effect is Heal (10) or Energize (30, mana).
3. At runtime, scan the bags once per `BAG_UPDATE` (dirty-flagged), map each item through
   `GetItemSpell` â†’ spellID â†’ that table, and keep the highest-magnitude item per bucket.

That covers health/mana potions, healthstones and runes across every tier automatically, with no id
typed anywhere. Combat potions (Free Action, Mighty Rage) apply auras rather than heals and are not
reachable this way; they would need either a third bucket keyed on aura-applying effects or a
deliberate cut. `M.DEFAULT_EQUIP_BY_CLASS` is already in place and empty so that the Warlock
Healthstone/Soulstone defaults become a data change rather than a code change.

## G.10. Scope: a third `/cdm` tab for the viewer settings

**Where the settings live today.** Every non-per-spell setting is in the DragonUI options panel,
registered by `modules/cooldownviewer/Register.lua` as section `cooldownviewer`. That is a different
window, reached by a different path, and it is the one thing about the current `/cdm` that does not
match retail â€” retail's Cooldown Manager settings sit *in* the Cooldown Manager.

**What the tab would host.** Everything currently in the options section: per-viewer enable, scale,
opacity, orientation/stride, visibility mode (always / in combat), show-timer and show-tooltip
toggles, plus the "Show Unlearned" checkbox that is presently in the cog menu. Frame *position*
stays with the movers (`/dui edit`) â€” Â§B1's decision, unchanged.

**The pieces already exist, which is why this is small.**

- `NE.tabs.MakeSideTab` builds the tab; `f.tabButtons` is already a list and `SetDisplayMode`
  already iterates it. Adding a third entry is three lines plus an anchor.
- The panel body is a `ScrollFrame` over `f.content`. `CDS.RefreshLayout` fills it from
  `Adapter.MODE_ORDER[mode]`, which has no entry for a settings mode.
- The side-tab glyph is the one asset gap: `SettingsAssets.lua` registers two
  (`icon_cooldownmanager`, `icon_trackedbuffs`) from the reference sheet, which carries a third.

**The one real decision â€” and the reason this is scoped rather than done.** The current body is
owned end-to-end by the category grids: `RefreshLayout` rebuilds `f.content` from the adapter on
every call, and there is nowhere for a page of controls that is *not* a category list to live. Two
ways out:

- **(a) A second content frame.** Build a `f.settingsContent` sibling, and have `SetDisplayMode`
  show one and hide the other via `f.scroll:SetScrollChild`. `RefreshLayout` early-returns for the
  settings mode and never touches it. Cheap, and no risk to the grids.
- **(b) A "category" whose renderer is a control list.** More uniform, but it puts widget layout
  behind an adapter whose whole contract is "return a list of spellIDs", and every consumer
  (`ApplyItemFilter`, the drag path, `RestackCategories`) would need a "not a grid" branch.

**(a) is the recommendation** â€” the settings page has nothing in common with a grid of tiles, and
pretending otherwise buys uniformity at the cost of a branch in four files.

Two smaller consequences fall out of (a) and should be handled with it: the **search box and cog**
are meaningless on a settings page and should hide with the grids, and the panel is 399x609 at 1.3
scale, so a long control list needs the scroll frame it already has rather than a taller window.

**Duplication is the thing to decide, not the layout.** The options section cannot simply be moved:
DragonUI's options panel is where a user goes to turn the module *off*, and it is read-only to us
(CONTRACTS Â§0 â€” we register a section, we do not own the window). So either

- the tab and the options section both read and write the same `NE.Config().cooldownviewer` store
  and stay in sync by construction (each rebuilds on show; no shared widget state), or
- the options section shrinks to an enable toggle plus an "Open Cooldown Manager" button, and the
  tab becomes the single home for the rest.

The second is retail's shape and the better end state. It is also the one that changes behaviour a
user may already rely on, so it is an owner's call rather than an implementation detail.

**RESOLVED (owner): the second.** The options section keeps the master enable toggle and an "Open
Cooldown Manager" button; everything else moved to the tab. Implementation notes in §G.12.

**Estimated size:** ~40 lines of panel wiring, ~180 lines for the control page (reusing the same
slider/checkbox helpers `Register.lua` already builds for the options section), plus harness
coverage that the tab switches modes and that a write from the tab is visible to the options
section. No new platform gap â€” nothing here needs an API 3.3.5a lacks.


## G.11. 4b-5 notes (layouts, import/export, and the real Revert)

Downport of `CooldownViewerSettings/Presets.lua` (378 lines) â†’ `SettingsPresets.lua`.

**The snapshot pair came with it, and that is the point.** Upstream's `Panel.lua` owns
`snapshotState`/`restoreState` and exposes them as `CDS.SnapshotState` / `CDS.RestoreState` /
`CDS.DeepCopy`; 4b-1 deferred the Revert button precisely because that pair did not exist. It lives
here now, so Revert is real. Applying a layout and undoing one are the same operation with a
different source snapshot â€” building two mechanisms for that would have been the mistake.

A layout is the five editable leaves plus the class it was captured on: `customLists`,
`trackedAura`, `equipAssign`, `alerts`, `sounds`, `class`. Restore is **whole-leaf assignment, not a
merge**: a layout is a complete state, so a spell the snapshot does not mention has to end up
unmentioned rather than surviving from whatever was there before.

`InvalidateCuratedCache` on restore is load-bearing. `GetActiveSpellList` caches the resolved curated
list, and replacing `customLists` underneath it leaves the viewers rendering the *previous* layout
until something else happens to dirty the cache â€” the same shape as the Â§E5 shadowing bug.

**Undo is one step, and only for this session.** The panel's edits are individually reversible by
hand (move it back, pick None), so what a player actually needs is "undo the layout I just applied",
not a history. The snapshot is taken before any apply / starter / import, and cleared on `OnHide`:
reverting an hour-old change is not an undo. The selected layout NAME is tracked *beside* the
snapshot rather than inside it â€” it is session bookkeeping, and putting it in the snapshot would bake
it into every export string, so a shared layout would arrive carrying the name of the layout its
author happened to have selected.

### Downport changes

**No `WowStyle1DropdownTemplate`.** The footer control is a plain `UIPanelButtonTemplate` opening
`CDS.BuildLayoutMenu` through `core/Menu.lua`. Same menu tree; only the widget differs. Its label is
the selected layout's name, so the footer still answers "which layout am I on" at a glance.

**Import is class-checked, which upstream is not.** A snapshot's spell lists are keyed by class, so
restoring a Priest layout on a Mage writes into the Priest's slot and appears to do *nothing at all*.
A silent no-op is the worst outcome for a paste, because the player cannot tell it from a broken
feature. `Decode` now refuses with a reason naming the class the layout was built for.

**Nothing else.** The codec is upstream's and was already 3.3.5a-clean â€” `string.byte`/`char`,
`math.floor`, `string.find`, no `bit` library anywhere.

### Safety

Import never executes pasted input: a hand-rolled typed reader, no `loadstring`, no `setfenv`, every
parse wrapped in `pcall`. Strings are length-prefixed so a spell name containing a tag character is
still safe. Plain SavedVariables plus StaticPopups throughout â€” nothing here can taint the combat
path.

**Two bad-input findings, both from writing the negative test rather than the guard:**

1. **The over-long string length is the one bad input that would pass silently.** `string.sub` clamps,
   so `t1;s5:class` + `s99:PRIEST` parses as `{ class = "PRIEST" }` â€” a well-formed layout built from a
   truncated read â€” and every later check (is it a table, is `.class` a string, does the class match)
   then passes. The explicit bounds check in the `s` branch is what stops it. The test pairs it with
   the same payload at the correct length, so the rejection is provably about the length and not the
   shape.

2. **The table pair-count cap was dead code, and was removed.** A header claiming a billion pairs is
   the obvious DoS shape, so the first version capped `count`. The negative test showed the cap
   changed nothing: every loop iteration must consume at least one byte of payload or raise, so the
   parser is self-limiting and such a header fails on the first pair. The assertion now states *that*
   â€” which is what lets the cap stay out instead of sitting there as a guard no input can reach.

Both are the Â§G.7.2 lesson again: a guard whose test passes with the guard removed is telling you
something, and it is usually that the guard or the test is wrong.

## G.12. 4c notes (the Settings tab)

§G.10 scoped this; the owner picked the second option, so the DragonUI options section is now an
enable toggle and an "Open Cooldown Manager" button, and every viewer setting lives on a third `/cdm`
tab. Two new files: `SettingsControls.lua` (the widget kit) and `SettingsOptions.lua` (the page).

**Option (a) as scoped: a second scroll child.** `panel.settingsContent` is a sibling of
`panel.content`, and `SetDisplayMode` swaps which one the ScrollFrame holds. The category grids own
`panel.content` end to end — `RefreshLayout` rebuilds it from the adapter on every call — so a page of
controls could not have shared it without an adapter category whose "list of spellIDs" contract it
cannot satisfy.

`CDS.RefreshLayout` gained a settings-mode early return, and that guard is load-bearing rather than an
optimisation. The panel refreshes on `SPELL_UPDATE_ICON`, `GET_ITEM_INFO_RECEIVED` and
`UNIT_INVENTORY_CHANGED` whenever it is shown; `MODE_ORDER` has no `settings` entry, so without the
return each of those events would walk the deactivate loop, switch every category off, and find
nothing to switch back on — leaving the grids empty behind a page the player is not looking at, to be
discovered on the next tab switch.

### Why a widget kit at all

DragonUI's `Controls:AddToggle` / `AddSlider` / `AddDropdown` are AceGUI widgets that call
`parent:AddChild(...)` and lay themselves out only inside an AceGUI container. Our body is a plain
Frame in a plain ScrollFrame, and DragonUI is read-only (CONTRACTS §0), so the choice was a kit or an
AceGUI container inside our panel. The kit is ~330 lines over the client's own
`UICheckButtonTemplate` and `OptionsSliderTemplate`, and it keeps the page looking like the rest of
the window rather than like the options tab embedded in it.

**Three downport points inside the kit:**

1. **No `WowStyle1DropdownTemplate`** — same absence the footer works around (§G.11). A dropdown is a
   button labelled with the current value, opening a radio menu through `core/Menu.lua`. It also takes
   an ORDERED array where the options tab takes a `value -> label` map: AceGUI sorts a map for you, and
   a radio menu has to choose. "Always / In Combat / Hidden" is a progression; alphabetised, Hidden
   lands in the middle.

2. **`SetObeyStepOnDrag` does not exist here**, and `SetValueStep` alone only governs the arrow keys,
   so a drag delivers continuous values. The kit snaps on the way in — the same thing Blizzard's own
   option sliders do in their `OnValueChanged`.

3. **The write gate on that same handler.** A drag fires `OnValueChanged` on every mouse move, and
   every write runs `M.SetOpt`, which re-runs the viewer's `RefreshLayout` and relays out every icon.
   Only a value that crosses into the next step may write. Verified by removing it: the "stays inside
   one step" assertion goes from 0 writes to 2.

### What is NOT on the page

**Frame position.** Still the movers (`/dui edit`), §B1's decision unchanged. It is the one setting
that is not a value in this store.

**Hide When Inactive on Essential and Utility.** Retail's templates for those two do not set
`allowHideWhenInactive`, so `UpdateShownState` ignores the setting and they always show every known
cooldown. The options tab shipped the control anyway with a description explaining that it did
nothing. The page offers it only where `GetOpt(frameID, "allowHideWhenInactive")` is true: a control
that has to explain its own inertness is worse than an absent one.

**The master enable.** It stays in DragonUI's options and appears nowhere here. That panel is where a
player goes to turn a module off, and nobody looks inside a window for the way to make that window's
frames stop existing.

### Duplication: values versus actions

The rule the §G.10 decision enforces is that no stored VALUE has two editors. A setting with two
editors is consistent only while both rebuild on show, and the first time one does not, the player is
reading a stale control and cannot tell that from a setting that failed to apply. Hence exactly one
home for each of the ten per-viewer settings, the two bar-only ones, and buff auto-tracking.

The two resets are deliberately in two places — the cog menu and the page's Reset section. They are
ACTIONS routed to the same `StaticPopup`s, with no stored state to fall out of sync: the cog is at
hand while working the lists, and a player looking for a reset looks under Settings. "Show Unlearned"
stays in the cog alone, because it filters the grids rather than configuring a viewer, which is also
why the cog and the search box both hide on this tab.

### Art

The tab glyph is the client's own `questlog-icon-setting` at 18px, not a third glyph from the CDM
sheet. That sheet's spare is `icon_buffreorder` — "reorder group buffs" — which would be a lie here,
and reusing the cog ties the tab to the cog beside the search box, which is what a player already
reads as "options for this window". `SettingsAssets.lua` now registers that rect itself rather than
depending on `modules/spellbook/Assets.lua` having loaded; the harness asserts it resolves, because an
unregistered atlas is a transparent gap rather than an error.

### Harness

47 new/changed assertions (382 at that point; 394 after Phase 6). Five guards were confirmed by removal: the slider write gate,
the step snap, the settings-mode return in `RefreshLayout`, the `allowHideWhenInactive` gate, and the
chrome hiding. Two stub notes:

- `frameMeta:SetValue` now fires `OnValueChanged` on a real change, as the client does. The sliders
  re-seat their own thumb from inside that handler and re-read their getter on every page refresh, so
  a stub that swallowed those calls could not tell a working re-entrancy guard from a missing one.
- `SetObeyStepOnDrag` is deliberately still absent from the stub. Adding it would hide the reason the
  kit snaps values itself.

The control finder in the test scopes by section title as well as label, and that is not tidiness:
"Icon size" exists four times, once per viewer, so an unscoped search always answers with Essential's
row — and a test meaning to prove Buff Bars' slider works would have proved nothing. Same failure
shape as §G.7.2 and the 5a pooled-tile test.

## G.13. Phase 6 notes (loose ends)

With 4c shipped and consumables parked as a stretch goal, both phasing tables were complete and there
was no next *port* phase — what remained was a short list of things the plan had deferred rather than
decided. This closes them.

### 1. The edit-mode affordance (§G.4, undecided since the §G scope was written)

`NE.editmode.Toggle` / `SelectFrame` were listed as "drop the affordance or route it at `/dui edit`",
and neither was ever chosen — so the Settings tab shipped in 4c telling players to type `/dui edit`.
Routed now, through a new integration seam:

```
NE.OpenFrameEditor(frame) -> true | false, reason
```

**It lives in `integration/Register.lua`, not in the module** (CONTRACTS §4: panel modules never reach
into DragonUI internals directly), and **it takes the CONTENT frame while selecting the ANCHOR.** That
is the trap the seam exists for. `RegisterHUDFrame` registers the `CreateUIFrame` anchor as the editable
frame and hangs the viewer off it, so DragonUI's editor knows the anchor and nothing at all about the
viewer. Handing `SelectEditorFrame` a content frame would put the coordinate readout and the Reset
button on a frame the editor cannot move — and it would look like it worked. `.editorAnchor`, which
`RegisterHUDFrame` already set, is the bridge.

**Failure returns a reason instead of printing one**, because the caller knows where its message
belongs. Two of the three failure paths matter:

- **In combat.** `EditorMode:Show()` returns silently in combat — an empty branch, no message
  (`DragonUI/modules/editor_mode.lua:334`) — so a button wired straight to it appears to do nothing
  mid-fight. `OpenFrameEditor` re-checks `IsActive()` rather than trusting the call, and the explicit
  combat branch exists purely to name combat in the reason. That distinction is now asserted: without
  the branch the refusal still happens, but the player is told "editor mode declined to open", which is
  not actionable. A guard whose only product is a better message still needs a test that reads the
  message.
- **No `EditorMode` at all**, on a DragonUI build that predates it. Returns a reason; does not error.

**Per viewer, not once globally.** Upstream's version was a single cog-menu entry. Because DragonUI's
editor takes a frame to select, ours is a "Position this viewer" button inside each viewer's section, so
the one under Buff Bars' sliders opens the editor with Buff Bars selected. The panel closes only on
success — hiding first and then failing would take away the only surface the reason could appear on.

The fourth upstream ref, `RepositionHandle` (`CooldownViewer.lua:977`, re-anchor the drag rect as items
are learned), needs no port at all: `RegisterHUDFrame` syncs the anchor to the content's footprint from
the content's own `OnSizeChanged`.

### 2. §F1, `Cooldown:SetDrawEdge`

Open since Phase 0. The static evidence is strong enough to call it — ClassicAPI stubs the three
`SetEdge*` methods as "Incompatible (3.3.5)" but not `SetDrawEdge`, injects unconditionally rather than
filling gaps, and calls `GetDrawEdge` unguarded on every captured cooldown's OnShow — but that is an
inference from someone else's code, so `/necdm` now prints the runtime answer for the four cooldown
methods we care about. Both of our call sites guard regardless, so nothing depends on it; what changes
is that the question stops being open.

The probe frame is created on demand and cached, not at load: frames cannot be destroyed, so a
diagnostic-only frame should not exist on a character who never runs the diagnostic.

`/necdm` is also now smoke-tested. It is ~70 lines of formatting that nothing else touches, and a bad
`select()` or a nil in a format string would otherwise surface only when someone reached for it to debug
something else — the worst possible moment.

### 3. 4b-1 vestiges

The "Spell list coming in the next step." placeholder outlived 4b-2 by four phases: still built, still
anchored, hidden on the first `RefreshLayout` and never seen again, with two live references keeping it
alive. Removed, along with the stub `RefreshLayout` body that painted it. The stub itself stays as a
genuine no-op, so a load failure in `SettingsCategories.lua` costs the grids rather than every
`SetDisplayMode` call.

Also corrected: `SettingsAssets.lua` now registers sheet 5684744 itself instead of relying on
`modules/spellbook/Assets.lua` having shipped it. The side-tab BODY has depended on that all along and
worked, because both files load from the same TOC — but the dependency was implicit and the harness was
quietly logging the sheet as unshipped. One path registered twice, not one file shipped twice.

### What is left, and it is not code

Three items, all needing the game rather than the harness:

- **§F4 taint.** The viewers are unsecure display frames with no attributes, so `SetPoint` during a live
  restack should be a non-issue — but "should be" is what §F4 asks to confirm, and only a combat restack
  confirms it.
- **§F5, whether four separate movers is tolerable** versus one grouped handle. An owner call with the
  frames on screen. The new per-viewer Position buttons make the four-mover shape easier to live with,
  which is worth re-judging before changing it.
- **In-game confirmation of 4b-4, 4b-5, 5a and 4c.** 1-3, 4b-1, 4b-2 and 4b-3 have had a pass; the four
  most recent phases have not. Every in-game pass so far has found something (§G.7.1, §G.7.2), and none
  of those faults were the kind an offline harness can reach — three of them were art and event-order
  problems visible only on a real frame.
