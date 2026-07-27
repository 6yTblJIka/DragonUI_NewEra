-- DragonUI_NewEra/modules/cooldownviewer/Alerts.lua — per-cooldown visual alerts and ready sounds.
--
-- Downport of NewEra/CooldownViewer/Alerts.lua. Each tracked cooldown can carry ONE assigned alert
-- that decorates its icon when the alert's event fires. Retail's event set lives in
-- Enum.CooldownViewerAlertEventType; upstream ports the three with a faithful pre-Legion meaning,
-- and so do we:
--
--   available — the ability came off cooldown. A one-shot flash on the real-cooldown -> ready
--               transition. This is also the trigger for the assigned ready SOUND.
--   refresh   — upstream's hydration of retail's PandemicTime event. Retail fires pandemic at
--               expirationTime - carriedOverToNewCast, gated on that value being > 0; it comes from
--               C_UnitAuras.GetRefreshExtendedDuration and represents retail's duration ROLLOVER on
--               refresh. 3.3.5a has neither the API nor the rollover, so the retail trigger could
--               never fire. Hydrated instead as "the tracked aura is inside the last `window`
--               fraction of its duration" — i.e. refresh it now.
--   usable    — retail's "conditionally castable" notion. Data-driven from AlertData.lua: a target
--               below an execute threshold, or a curated reactive ability becoming castable. Only
--               those spells ever flash; flashing every ready spell is explicitly not the feature.
--
-- ── THE PANDEMIC BORDER: WHAT PORTS, AND WHAT DOES NOT ──────────────────────────────────────────
--
-- Upstream renders `refresh` with a 1:1 port of retail's CooldownPandemicFXTemplate: a static ring
-- PLUS three glow textures that cascade outward, every one of them clipped to the ring shape by a
-- MaskTexture. Those are two separable halves, and only the second half is unportable.
--
-- THE RING PORTS AS-IS (§H.2.10). `UI-CooldownManager-PandemicBorder` is already a hollow
-- rounded-square ring: alpha 0 through the centre, material in two bands at cols 2-8 and 52-58 of
-- 61, real RGB at full alpha. It needs no mask, no crop and no substitute — it is the retail
-- pandemic border, and it lives on sheet 6685874, which Phase 8a already ships. (This header used to
-- say "the art is also absent". That was true before 8a and is not true now.)
--
-- THE CASCADE DOES NOT PORT, for two independent reasons:
--
--   1. MaskTexture does not exist on 3.3.5a. It is not merely missing — !!!ClassicAPI defines
--      CreateMaskTexture and AddMaskTexture as Private.Void ("potentially impossible to implement",
--      WidgetAPI.lua:279/302/476), and Cell's polyfill returns an inert dummy object. The calls
--      would succeed silently and clip nothing. That matters here specifically because
--      PandemicFX-Icon01/02/03 are FILLED 128x128 quads (centre alpha 61/81/24), not rings: without
--      the clip they scale to 1.5x as square smears across the icon and its neighbours. Worse than
--      no FX, and the reason those three atlases are deliberately not registered.
--   2. `Animation:SetTarget` does not exist on this client either (zero occurrences anywhere in the
--      AddOns tree). 3.3.5a animations act on the region that owns the AnimationGroup, so the
--      template's one-group-drives-three-textures structure has no equivalent.
--
-- SUBSTITUTION: the ring itself pulses. One texture on one frame, so the animation acts on the
-- region that owns the group — exactly what this client does support — and no mask is involved at
-- any point. It carries the same signal as the cascade (this aura is expiring, refresh it) using the
-- real art, rather than faking a clip we cannot perform.
--
-- The three LibCustomGlow renderers remain selectable for `refresh` and stay the only option for the
-- other two alert types. The ring is simply a fourth FX, and the default for `refresh`.
--
-- ── ENGINE ──────────────────────────────────────────────────────────────────────────────────────
--
-- `available` is edge-triggered off the item's ConsumeReadyTransition. `refresh` and `usable` need
-- polling: aura time decay, target health and usability transitions do not all raise events on
-- 3.3.5a. One shared 0.2s ticker walks the Essential and Utility items, and does nothing at all
-- unless at least one alert or one ready sound is assigned — the default setup costs a table lookup.
--
-- Every live evaluation is pcall-isolated: a bad read must never raise, least of all in combat.

local NE = DragonUI_NewEra
NE.cooldownviewer = NE.cooldownviewer or {}
local M = NE.cooldownviewer
M.alerts = M.alerts or {}
local AL = M.alerts

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- ── FX catalogue ────────────────────────────────────────────────────────────────────────────────
-- Upstream's fx values are indices into NE.groupbuff.VISUAL_ALERT, a Group Buff Filter enum this
-- addon does not have. We define our own over the LibCustomGlow renderers, keeping 1 = ants as the
-- default so a stored upstream-shaped value still lands on the intended look.
AL.FX = {
  { id = 1, name = "Marching Ants" },
  { id = 2, name = "Button Glow" },
  { id = 3, name = "Sparkles" },
  { id = 4, name = "Pandemic Border" },
}

local DEFAULT_FX     = 1
-- `refresh` defaults to the real retail ring; the other two alert types have no retail art of their
-- own, so they keep the ants. Kept as a table rather than an if, so adding art for another type is
-- one line.
local DEFAULT_FX_BY_TYPE = { refresh = 4 }
AL.PANDEMIC_FX = 4
local DEFAULT_WINDOW = 0.30
local WINDOW_MIN     = 0.10
local WINDOW_MAX     = 0.50
local AVAILABLE_HOLD = 1.5    -- seconds the one-shot "available" flash stays up
local TICK           = 0.2    -- poll cadence

-- Tint per alert type, for the three LibCustomGlow renderers only — the pandemic ring is untinted
-- because its art already carries the colour (see startPandemic). `refresh` keeps a pandemic-orange
-- entry here for the case where the player picks ants or sparkles for it instead of the ring.
local TINT = {
  available = { 0.35, 1.00, 0.35, 1 },
  refresh   = { 1.00, 0.50, 0.10, 1 },
  usable    = { 0.95, 0.95, 0.32, 1 },
}
local GLOW_KEY = "NECDMAlert"

-- ── Persistence ─────────────────────────────────────────────────────────────────────────────────
-- Beside every other Cooldown Manager setting, in DragonUI's profile.
local function store(create)
  local cd = M._store and M._store(create)
  if not cd then return nil end
  if not cd.alerts then
    if not create then return nil end
    cd.alerts = {}
  end
  return cd.alerts
end

function AL.Get(spellID)
  if not spellID then return nil end
  local t = store(false)
  return t and t[spellID] or nil
end

local function ensureLeaf(spellID)
  local t = store(true)
  if not t then return nil end
  local e = t[spellID]
  if not e then e = {}; t[spellID] = e end
  return e
end

function AL.GetType(spellID)
  local e = AL.Get(spellID)
  return e and e.type or nil
end

-- type = nil disables the alert but KEEPS fx/window, so re-enabling restores the previous choice.
function AL.SetType(spellID, alertType)
  if not spellID then return end
  local e = ensureLeaf(spellID)
  if not e then return end
  e.type = alertType
  if alertType then
    if e.fx == nil then e.fx = AL.DefaultFX(alertType) end
    if e.window == nil then e.window = DEFAULT_WINDOW end
  end
end

-- The default FX for an alert type. `refresh` gets the real pandemic ring; everything else keeps the
-- ants. Resolved through one function so the stored value, the settings dropdown and the live
-- renderer cannot disagree about what "unset" means.
function AL.DefaultFX(alertType)
  return DEFAULT_FX_BY_TYPE[alertType or ""] or DEFAULT_FX
end

function AL.GetFX(spellID)
  local e = AL.Get(spellID)
  if e and e.fx then return e.fx end
  return AL.DefaultFX(e and e.type)
end

function AL.SetFX(spellID, fx)
  local e = ensureLeaf(spellID)
  if e then e.fx = fx or AL.DefaultFX(e.type) end
end

function AL.GetWindow(spellID)
  local e = AL.Get(spellID)
  return (e and e.window) or DEFAULT_WINDOW
end

function AL.SetWindow(spellID, frac)
  local e = ensureLeaf(spellID)
  if not e then return end
  frac = tonumber(frac) or DEFAULT_WINDOW
  if frac < WINDOW_MIN then frac = WINDOW_MIN elseif frac > WINDOW_MAX then frac = WINDOW_MAX end
  e.window = frac
end

-- Ticker early-out: is any spell carrying an enabled alert?
function AL.HasAny()
  local t = store(false)
  if not t then return false end
  for _, e in pairs(t) do
    if e and e.type then return true end
  end
  return false
end

-- ── FX rendering ────────────────────────────────────────────────────────────────────────────────
-- Idempotent by (fx, alert type): re-applying restarts the animation, and at 5Hz that reads as a
-- stutter rather than a glow. `_alertFX` records what is currently up.
-- ── The pandemic ring ───────────────────────────────────────────────────────────────────────────
--
-- A CHILD FRAME, not a texture on the item. A child frame draws above every layer of its parent, and
-- that is the only way to get above the tile's own art here: the gold frame stack occupies OVERLAY
-- sublevels 0-2 and the cooldown sweep is itself a child frame (§H.2.8). Levelled above the sweep
-- for the same reason the buff glow is — a ring the swipe eats half of is a ring nobody can read.
--
-- Anchored to the item, as retail anchors it (SetAllPoints in CooldownPandemicFXTemplate). On our
-- tiles that puts the ring around the frame's inner opening, just outside the inset icon.
local PANDEMIC_PULSE_MIN  = 0.45   -- retail cascades; we breathe. See the header.
local PANDEMIC_PULSE_HALF = 0.75   -- seconds per half-cycle, so a 1.5s loop

local function buildPandemicRing(item)
  if not (NE.tex and NE.tex.HasAtlas and NE.tex.HasAtlas("UI-CooldownManager-PandemicBorder")) then
    return nil
  end
  local base = (item.Cooldown and item.Cooldown.GetFrameLevel and item.Cooldown:GetFrameLevel())
            or (item.GetFrameLevel and item:GetFrameLevel())
            or 1
  local ov = CreateFrame("Frame", nil, item)
  ov:SetAllPoints(item)
  ov:SetFrameLevel(base + 4)
  ov:Hide()

  ov.Ring = ov:CreateTexture(nil, "OVERLAY")
  ov.Ring:SetAllPoints(ov)
  NE.tex.SetAtlas(ov.Ring, "UI-CooldownManager-PandemicBorder", false)

  -- The pulse animates the FRAME, which is what 3.3.5a animations do — they act on the region that
  -- owns the group. The ring is the frame's only content, so animating the one is animating the
  -- other, and no SetTarget is needed. Feature-gated: without AnimationGroups the ring still shows,
  -- just static, which is a complete signal on its own.
  if ov.CreateAnimationGroup then
    local ok, ag = pcall(ov.CreateAnimationGroup, ov)
    if ok and ag then
      if ag.SetLooping then ag:SetLooping("REPEAT") end
      local out = ag:CreateAnimation("Alpha")
      out:SetDuration(PANDEMIC_PULSE_HALF); out:SetOrder(1)
      local back = ag:CreateAnimation("Alpha")
      back:SetDuration(PANDEMIC_PULSE_HALF); back:SetOrder(2)
      -- The native 3.3.5a Alpha animation takes a DELTA via SetChange; SetFromAlpha/SetToAlpha are
      -- ClassicAPI's polyfill over it (WidgetAPI.lua:414-436), and it only emits the SetChange once
      -- BOTH halves have been set — hence from-then-to, in that order, on each animation. The raw
      -- SetChange branch below is the fallback for a client without ClassicAPI loaded.
      --
      -- Delta semantics are why startPandemic sets the frame's alpha to 1 before Play: the animation
      -- moves it by -0.55 from wherever it happens to be, not to an absolute 0.45.
      if out.SetFromAlpha then
        out:SetFromAlpha(1); out:SetToAlpha(PANDEMIC_PULSE_MIN)
        back:SetFromAlpha(PANDEMIC_PULSE_MIN); back:SetToAlpha(1)
      elseif out.SetChange then
        out:SetChange(PANDEMIC_PULSE_MIN - 1)
        back:SetChange(1 - PANDEMIC_PULSE_MIN)
      end
      if out.SetSmoothing then out:SetSmoothing("IN_OUT"); back:SetSmoothing("IN_OUT") end
      ov.anim = ag
    end
  end
  return ov
end

-- DELIBERATELY UNTINTED, unlike every other FX here. The three LibCustomGlow renderers are
-- colourless and take their meaning from TINT; this art does not — it ships as the pandemic colour
-- already (peak 255,48,48). Vertex colour multiplies, so applying TINT.refresh's (1, 0.5, 0.1) to a
-- ring that is (1, 0.19, 0.19) would land on (1, 0.09, 0.02): a darker, muddier red than the artist
-- chose, arrived at by "tinting" something that needed no tint.
local function startPandemic(item)
  local ov = item._pandemicRing
  if ov == nil then
    ov = buildPandemicRing(item) or false
    item._pandemicRing = ov
  end
  if not ov then return false end
  ov:SetAlpha(1)
  ov:Show()
  if ov.anim and ov.anim.Play then ov.anim:Play() end
  return true
end

local function stopPandemic(item)
  local ov = item and item._pandemicRing
  if not ov then return end
  if ov.anim and ov.anim.Stop then ov.anim:Stop() end
  ov:SetAlpha(1)   -- the group leaves the frame wherever the pulse stopped
  ov:Hide()
end

local function startGlow(item, fx, colour)
  if fx == 4 then return startPandemic(item) end
  if not LCG then return false end
  if fx == 2 and LCG.ButtonGlow_Start then
    -- ButtonGlow takes no key; it is one-per-frame by construction.
    LCG.ButtonGlow_Start(item, colour, 0.35)
    return true
  elseif fx == 3 and LCG.AutoCastGlow_Start then
    LCG.AutoCastGlow_Start(item, colour, 4, 0.25, 1, 0, 0, GLOW_KEY)
    return true
  elseif LCG.PixelGlow_Start then
    LCG.PixelGlow_Start(item, colour, 8, 0.25, nil, 2, 0, 0, false, GLOW_KEY)
    return true
  end
  return false
end

local function stopGlow(item, fx)
  if fx == 4 then return stopPandemic(item) end
  if not LCG then return end
  if fx == 2 then
    if LCG.ButtonGlow_Stop then LCG.ButtonGlow_Stop(item) end
  elseif fx == 3 then
    if LCG.AutoCastGlow_Stop then LCG.AutoCastGlow_Stop(item, GLOW_KEY) end
  else
    if LCG.PixelGlow_Stop then LCG.PixelGlow_Stop(item, GLOW_KEY) end
  end
end

function AL.ShowFX(item, fx, alertType)
  if not item then return end
  fx = fx or AL.DefaultFX(alertType)
  local sig = tostring(fx) .. ":" .. tostring(alertType)
  if item._alertFX == sig then return end
  -- A change of fx family has to stop the OLD renderer, not the new one.
  if item._alertFX then AL.ClearFX(item) end
  item._alertFXKind = fx
  local ok, started = pcall(startGlow, item, fx, TINT[alertType] or TINT.usable)
  -- Only record a live FX if one actually rendered. With no glow library present startGlow returns
  -- false without erroring, and claiming success would leave a flag with nothing behind it.
  if ok and started then item._alertFX = sig else item._alertFXKind = nil end
end

function AL.ClearFX(item)
  if not item then return end
  item._alertFlashUntil = nil
  if not item._alertFX then return end
  local fx = item._alertFXKind
  item._alertFX, item._alertFXKind = nil, nil
  pcall(stopGlow, item, fx)
end

-- One-shot flash for the `available` event: show, then auto-clear after a hold.
function AL.FlashOnce(item, fx, alertType)
  if not item then return end
  AL.ShowFX(item, fx, alertType or "available")
  item._alertFlashUntil = GetTime() + AVAILABLE_HOLD
  if C_Timer and C_Timer.After then
    C_Timer.After(AVAILABLE_HOLD, function()
      -- Only clear if this flash is still the one showing — a later alert may have taken over.
      if item._alertFlashUntil and GetTime() >= item._alertFlashUntil then
        item._alertFlashUntil = nil
        AL.ClearFX(item)
      end
    end)
  end
end

-- Settings preview: flash any frame so the user can see their choice. Safe on a non-item frame.
--
-- The alert type matters here, because it picks the TINT. Previewing everything as "usable" made
-- the settings tile flash yellow while the live icon then glowed green — the preview was showing a
-- colour the player had not chosen and would never see. Callers pass the type being configured.
function AL.Preview(frame, fx, alertType)
  if not frame then return end
  local t = TINT[alertType] and alertType or "usable"
  AL.FlashOnce(frame, fx or AL.DefaultFX(t), t)
end

-- ── Trigger evaluators ──────────────────────────────────────────────────────────────────────────

-- Is the tracked aura inside the last `window` fraction of its duration?
--
-- The aura a cooldown maintains shares the spell's NAME (a DoT, HoT or self-buff), which is the only
-- handle available: 3.3.5a cannot query an aura by spellID. Player first (HoTs, self-buffs), then
-- target (DoTs). NE.aura caches one scan per unit per frame, so polling this at 5Hz is cheap.
local function inRefreshWindow(item, window)
  local name = item.spellName
  if not (name and NE.aura) then return false end

  local row = NE.aura.FindByName("player", name)
  if not (row and row.duration and row.duration > 0) then
    row = NE.aura.FindByName("target", name)
  end
  if not (row and row.duration and row.duration > 0 and row.expiration) then return false end

  local remaining = row.expiration - GetTime()
  if remaining <= 0 then return false end
  return (remaining / row.duration) <= (window or DEFAULT_WINDOW)
end

-- Castable right now: resources available and not on a real cooldown. A GCD-length lockout does not
-- count as a cooldown — the same heuristic the viewer applies everywhere else.
local function isSpellUsableNow(spellID, item)
  if not spellID then return false end
  -- 3.3.5a's IsUsableSpell takes a NAME (or a spellbook index + bookType), never a spellID. Passing
  -- an id reads it as an index past the end of the book and returns nil — no error, just a silent
  -- false. That made this function return false unconditionally, which is why the Usable alert
  -- never fired for anyone. Same fault, same fix as ItemMixins.lua:545; this site was missed.
  if not IsUsableSpell then return false end
  if not IsUsableSpell((item and item.spellName) or spellID) then return false end
  local start, dur = M.SpellCD(spellID, item and item.spellName, item and item._rankCDIDs)
  if start and start > 0 and dur and dur > (M.GCD_MAX or 1.51) then return false end
  return true
end

-- "Usable" = castable right now.
--
-- DIVERGENCE FROM UPSTREAM, and the reason for it: upstream flashes ONLY spells listed in
-- AlertData's EXECUTE or REACTIVE tables and returns false for everything else. That is defensible
-- upstream, where the alert can be attached to spells with no cooldown at all. Here it made
-- "Usable" a dead menu entry for six of the ten classes — AlertData covers eight abilities across
-- Hunter, Paladin, Warrior and Rogue, so a Priest or a Mage could select it and nothing could ever
-- happen. The label says what it does: a spell off cooldown and affordable IS usable.
--
-- EXECUTE stays as the stricter condition, because target health is something IsUsableSpell knows
-- nothing about — without it Kill Shot would glow all fight instead of in execute range.
-- A.IsReactive is deliberately NOT consulted any more: 3.3.5a's IsUsableSpell already reports
-- Overpower and Revenge as unusable outside their proc window, so the curated check was only
-- restating what the client says. A.REACTIVE stays in AlertData as data; nothing reads it.
local function inUsableState(item)
  local sid = item.spellID
  if not sid then return false end
  local A = M.alertdata

  local threshold = A and A.ExecuteThreshold and A.ExecuteThreshold(sid, item._rankCDIDs)
  if threshold then
    if not (UnitExists and UnitExists("target")) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return false end
    local hp, hpMax = UnitHealth("target"), UnitHealthMax("target")
    if not (hp and hpMax and hpMax > 0) then return false end
    if (hp / hpMax) > threshold then return false end
    return isSpellUsableNow(sid, item)
  end

  return isSpellUsableNow(sid, item)
end

-- Evaluate one item's assigned alert. `available` is edge-triggered elsewhere, so the ticker leaves
-- its flash alone rather than clearing it every pass.
local function evalItem(item)
  if not item then return end

  -- A one-shot flash owns the icon until its hold expires. Without this the ticker wipes it within
  -- 200ms — which also silently defeated the settings PREVIEW, whose whole job is to be seen.
  if item._alertFlashUntil and GetTime() < item._alertFlashUntil then return end

  -- Preferences key off the LISTED id, not the learned-rank one the tile displays.
  local sid = item.GetSettingsKey and item:GetSettingsKey() or item.spellID
  if not sid then AL.ClearFX(item); return end

  local cfg = AL.Get(sid)
  if not (cfg and cfg.type) then AL.ClearFX(item); return end

  if cfg.type == "available" then return end

  if item.IsShown and not item:IsShown() then AL.ClearFX(item); return end

  local on
  if cfg.type == "refresh" then
    on = inRefreshWindow(item, cfg.window)
  elseif cfg.type == "usable" then
    on = inUsableState(item)
  end

  if on then AL.ShowFX(item, cfg.fx, cfg.type) else AL.ClearFX(item) end
end

-- ── Ready transition ────────────────────────────────────────────────────────────────────────────
-- Detected by polling, not by an event: 3.3.5a emits nothing when a cooldown ends, and the viewer's
-- own OnCooldownDone timer is unreliable because a refresh re-Sets or Clears the swipe and cancels
-- it. ConsumeReadyTransition is the one-shot edge (ItemMixins.lua); it is shared with nothing else,
-- so a transition fires exactly once.
function AL.OnAvailable(item)
  if not item then return end
  local cfg = AL.Get(item.GetSettingsKey and item:GetSettingsKey() or item.spellID)
  if cfg and cfg.type == "available" then
    AL.FlashOnce(item, cfg.fx, "available")
  end
end

local function checkReadyTransition(item)
  if not (item and item.spellID and item.ConsumeReadyTransition) then return end
  if item.IsShown and not item:IsShown() then return end
  if item:ConsumeReadyTransition() and item.FireReadyAlerts then
    item:FireReadyAlerts()
  end
end

-- ── Ticker ──────────────────────────────────────────────────────────────────────────────────────
-- Only the spell viewers carry cooldown items; the aura viewers have no ready transition and no
-- curated usable state.
local function runViewer(viewer)
  if not (viewer and viewer.IsShown and viewer:IsShown() and viewer.items) then return end
  for _, item in ipairs(viewer.items) do
    pcall(evalItem, item)
    pcall(checkReadyTransition, item)
  end
end

local ticker = CreateFrame("Frame")
ticker.elapsed = 0
ticker:Hide()
ticker:SetScript("OnUpdate", function(self, delta)
  self.elapsed = self.elapsed + delta
  if self.elapsed < TICK then return end
  self.elapsed = 0
  if not (AL.HasAny() or (M.HasAnyReadySound and M.HasAnyReadySound())) then return end
  local viewers = M.viewers
  if not viewers then return end
  runViewer(viewers.essential)
  runViewer(viewers.utility)
end)

-- Started by Register.lua once the viewers exist.
function AL.Start()
  ticker:Show()
end

function AL.Stop()
  ticker:Hide()
  M.ForEachViewer(function(viewer)
    if viewer.items then
      for _, item in ipairs(viewer.items) do AL.ClearFX(item) end
    end
  end)
end

-- Drop every per-spell alert and ready sound, and take down anything currently glowing. Spell lists
-- and viewer positions live elsewhere and are deliberately untouched.
function M.ResetAlerts()
  local cd = M._store and M._store(true)
  if cd then
    cd.alerts = {}
    cd.sounds = {}
  end
  M.ForEachViewer(function(viewer)
    if viewer.items then
      for _, item in ipairs(viewer.items) do AL.ClearFX(item) end
    end
  end)
end

AL._ticker = ticker   -- test seam
