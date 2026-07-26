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
-- ── WHAT THE PANDEMIC BORDER FX COSTS, AND WHY IT IS GONE ───────────────────────────────────────
--
-- Upstream renders `refresh` with a 1:1 port of retail's CooldownPandemicFXTemplate: a static ring
-- plus three glow textures that cascade outward, every one of them clipped to the ring shape by a
-- MaskTexture. That is ~130 lines and it is not portable here, for two independent reasons:
--
--   1. MaskTexture does not exist on 3.3.5a. It is not merely missing — !!!ClassicAPI defines
--      CreateMaskTexture and AddMaskTexture as Private.Void ("potentially impossible to implement",
--      WidgetAPI.lua:279/302/476), and Cell's polyfill returns an inert dummy object. The calls
--      would succeed silently and clip nothing, leaving three full-quad glows scaling to 1.5x as
--      square smears across the icon and its neighbours. Worse than no FX.
--   2. `Animation:SetTarget` does not exist on this client either (zero occurrences anywhere in the
--      AddOns tree). 3.3.5a animations act on the region that owns the AnimationGroup, so the
--      template's one-group-drives-three-textures structure has no equivalent.
--
-- The art is also absent — the ring/glow atlases live on retail's CooldownManager sheet, which this
-- client's data has no entry for.
--
-- So `refresh` is rendered with the same glow family as the other alerts, tinted differently to read
-- as "expiring". LibCustomGlow (already embedded and in the TOC) supplies the renderers; it is what
-- PORT_PLAN §C7 nominated for the proc-glow substitution and it works on this client today.
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
}

local DEFAULT_FX     = 1
local DEFAULT_WINDOW = 0.30
local WINDOW_MIN     = 0.10
local WINDOW_MAX     = 0.50
local AVAILABLE_HOLD = 1.5    -- seconds the one-shot "available" flash stays up
local TICK           = 0.2    -- poll cadence

-- Tint per alert type. `refresh` gets the pandemic-orange retail uses for its expiring-aura border,
-- which is the only part of that look worth keeping without the mask.
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
    if e.fx == nil then e.fx = DEFAULT_FX end
    if e.window == nil then e.window = DEFAULT_WINDOW end
  end
end

function AL.GetFX(spellID)
  local e = AL.Get(spellID)
  return (e and e.fx) or DEFAULT_FX
end

function AL.SetFX(spellID, fx)
  local e = ensureLeaf(spellID)
  if e then e.fx = fx or DEFAULT_FX end
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
local function startGlow(item, fx, colour)
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
  fx = fx or DEFAULT_FX
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
function AL.Preview(frame, fx)
  if not frame then return end
  AL.FlashOnce(frame, fx or DEFAULT_FX, "usable")
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
  if not (IsUsableSpell and IsUsableSpell(spellID)) then return false end
  local start, dur = M.SpellCD(spellID, item and item.spellName, item and item._rankCDIDs)
  if start and start > 0 and dur and dur > (M.GCD_MAX or 1.51) then return false end
  return true
end

-- Execute (target below an HP threshold) or Reactive (a curated ability becoming castable).
-- A spell in neither table never flashes on this event.
local function inUsableState(item)
  local sid = item.spellID
  local A = M.alertdata
  if not (sid and A) then return false end

  local threshold = A.ExecuteThreshold and A.ExecuteThreshold(sid, item._rankCDIDs)
  if threshold then
    if not (UnitExists and UnitExists("target")) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("target") then return false end
    local hp, hpMax = UnitHealth("target"), UnitHealthMax("target")
    if not (hp and hpMax and hpMax > 0) then return false end
    if (hp / hpMax) > threshold then return false end
    return isSpellUsableNow(sid, item)
  end

  if A.IsReactive and A.IsReactive(sid, item._rankCDIDs) then
    return isSpellUsableNow(sid, item)
  end
  return false
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
