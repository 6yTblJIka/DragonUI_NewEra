# Cooldown Manager — Port Plan (Build Contract)

Downport of `ReferenceAddons/NewEra/CooldownViewer/` + `CooldownViewerSettings/` (Classic 1.15 /
TBC 2.5.x) onto 3.3.5a. Read `CONTRACTS.md` §0 first — every global convention there applies.

**Status:** Phases 0, 1 and 3 implemented. Offline harnesses pass (`qa/offline/`). Phase 1 has been
smoke-tested in-game; Phase 3 has not. **Phase 2 (WotLK data incl. Death Knight) is still
outstanding** and is now the main gap — Phase 3 was done first because the aura viewers are driven
by the auto-track window rather than the curated class lists, so they never depended on it.

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
| `Alerts.lua` | 520 | Phase 4, not re-scoped |
| `ClassData.lua` | 392 | yes (vanilla base) |
| `SoundAlertData.lua` | 349 | Phase 4 |
| `EditModeRegister.lua` | 213 | **no — replace wholesale** |
| `CooldownViewerEquip.lua` | 182 | yes |
| `CdmSeedTBC.lua` | 131 | template for a new WotLK seed |
| `AlertData.lua` | 100 | Phase 4 |
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
| **4** | `Alerts.lua` + `SoundAlertData.lua`, then the `CooldownViewerSettings/` panel port if the options-tab version proves too cramped. | — |

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

## F. Open questions / unverified

1. **`Cooldown:SetDrawEdge` on 3.3.5a** — ClassicAPI assumes it exists (C3). Confirm.
2. **`Alerts.lua` (520 lines) and `SoundAlertData.lua` (349)** — skimmed only, not dependency-mapped.
   Re-scope before committing to Phase 4.
3. **`CooldownViewerSettings/Panel.lua`** — reimplements `LargeSideTabButtonTemplate`, which is absent
   on Era too and was already synthesized there; likely portable, but its scroll-body and dropdown
   dependencies are unmapped.
4. **Taint.** The viewers are pure display frames with no secure attributes, and `EnsureGroup`
   reparents them freely, so taint should be a non-issue — but Phase 1 must verify no combat-lockdown
   errors on `SetPoint` during a live restack.
5. **Whether four separate movers is tolerable UX** in DragonUI's editor mode versus one grouped
   handle. Decide during Phase 1 with the frames on screen.
