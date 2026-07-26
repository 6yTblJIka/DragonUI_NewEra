-- DragonUI_NewEra/modules/cooldownviewer/ItemMixins.lua — the per-item layer of the Cooldown
-- Manager: one tile that binds a spell (or an on-use item) and renders its cooldown.
--
-- DOWNPORT of NewEra/CooldownViewer/ItemMixins.lua, Phase 1 scope: the COOLDOWN item mixin only
-- (Essential + Utility). The aura mixins (BuffIcon / BuffBar) are Phase 3 and are not ported here.
--
-- DEVIATIONS from the 1.15 source, all forced by the 3.3.5a widget/API surface:
--
--   * MaskTexture      — removed. Legion widget; unavailable, unpolyfillable, and an unknown XML
--                        node breaks the whole file's parse. CONTRACTS §0 lists SetMask as a hard
--                        rule. The rounded look now comes from CropIcon + the IconOverlay art.
--   * SetSwipeTexture  — removed (WoD+). We take the engine's built-in sweep.
--   * SetSwipeColor    — guarded (WoD+). The gold-aura vs black-cooldown distinction is therefore
--                        not colour-coded on this client; the aura path still drives the swipe.
--   * SetShown         — replaced with Show/Hide (CONTRACTS §0 hard rule).
--   * C_Spell.IsSpellUsable / IsSpellInRange — neither !!!ClassicAPI nor compat/C_Spell.lua provides
--                        these, so we go straight to the 3.3.5a globals IsUsableSpell / IsSpellInRange.
--                        The source already carried those as fallbacks.
--   * highestKnownRankID — REWRITTEN. The source uses `select(7, GetSpellInfo(name))`, which is the
--                        spellID on Era/TBC's modern engine but is **castTime** on 3.3.5a (the WotLK
--                        signature is name, rank, icon, cost, isFunnel, powerType, castTime, minRange,
--                        maxRange — see !!!ClassicAPI/Util/C_Spell.lua:39). Ported verbatim it would
--                        return e.g. 1500 for a 1.5s cast and use it as a spell ID. We resolve
--                        through NE.spellbook (core/SpellRanks.lua) instead.

local NE = DragonUI_NewEra
NE.cooldownviewer = NE.cooldownviewer or {}
local M = NE.cooldownviewer

local SB = NE.spellbook

-- Atlas wiring for one item tile. Era's engine atlas DB doesn't know retail nicknames; resolve via
-- NE.tex.SetAtlas. DOWNPORT: the IconMask branch is gone (see header). Every call is guarded so a
-- not-yet-shipped atlas degrades to a plain icon rather than erroring.
local function applyItemAtlases(item)
  local set = NE.tex and NE.tex.SetAtlas
  if not set then return end
  if item.IconOverlay then set(item.IconOverlay, "UI-HUD-CoolDownManager-IconOverlay", false) end
  if item.OutOfRange  then set(item.OutOfRange,  "UI-CooldownManager-OORshadow",       false) end
  -- Normalise the inconsistent baked borders on 3.3.5a icon art (8% zoom). This is also what stands
  -- in for the removed rounded mask.
  if NE.tex.CropIcon then
    NE.tex.CropIcon(item.Icon)
  elseif item.Icon and item.Icon.SetTexCoord then
    item.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
end

NE_CooldownViewerItemMixin = {}
local ItemMixin = NE_CooldownViewerItemMixin

function ItemMixin:OnLoad()
  applyItemAtlases(self)
  if self.OutOfRange then self.OutOfRange:Hide() end

  -- Countdown numbers. On 3.3.5a the Cooldown widget draws no text at all, so NE.cd owns a
  -- FontString + throttled OnUpdate (core/CooldownNumbers.lua). Same call shape as the source.
  NE.cd.ApplyNumbers(self.Cooldown, {
    font = self.cooldownFont or NE.cd.FONT.viewerEssential,
  })

  -- Retail renders drawSwipe=true, drawEdge=false, drawBling=true. 3.3.5a has none of these
  -- setters; guarded so this is a no-op here and correct if a future client gains them.
  if self.Cooldown then
    if self.Cooldown.SetDrawSwipe then self.Cooldown:SetDrawSwipe(true)  end
    if self.Cooldown.SetDrawEdge  then self.Cooldown:SetDrawEdge(false)  end
    if self.Cooldown.SetDrawBling then self.Cooldown:SetDrawBling(true)  end
  end
end

local BOOKTYPE_SPELL_ = BOOKTYPE_SPELL or "spell"

-- Every rank spellID of an ability, so the cooldown read can find whichever rank is actually
-- ticking. Our curated lists key each ability by its RANK 1 spellID (Devouring Plague = 2944,
-- Mind Blast = 8092), but the client tracks a cooldown on the EXACT rank cast — GetSpellCooldown
-- on the rank-1 id (or the bare name) reads 0 once you cast a higher rank, and players routinely
-- cast several ranks (down-ranking for mana). WotLK still has ranks, so this matters here exactly
-- as it did on 1.15.
--
-- DOWNPORT: primary source is now NE.spellbook (core/SpellRanks.lua), built by scanning the live
-- spellbook, rather than NewEra's generated db2 dump. The book-scan fallback below still covers
-- anything the table missed (racials, item use-spells).
local function knownRankIDs(spellID, name)
  local ids, seen, n = nil, {}, 0
  local function add(id)
    if id and not seen[id] then seen[id] = true; ids = ids or {}; n = n + 1; ids[n] = id end
  end
  add(spellID)

  local list = SB and SB.KnownRankIDs and name and SB.KnownRankIDs(name)
  if list then for _, id in ipairs(list) do add(id) end end

  if name and GetNumSpellTabs and GetSpellBookItemName and GetSpellBookItemInfo then
    for tab = 1, (GetNumSpellTabs() or 0) do
      local _, _, offset, numSlots = GetSpellTabInfo(tab)
      if offset and numSlots then
        for s = offset + 1, offset + numSlots do
          if GetSpellBookItemName(s, BOOKTYPE_SPELL_) == name then
            local _, sid = GetSpellBookItemInfo(s, BOOKTYPE_SPELL_)
            add(sid)
          end
        end
      end
    end
  end
  return ids
end

-- Highest rank of an ability the player has learned, so the tile shows the live rank's icon/name/
-- tooltip rather than the curated rank-1 seed.
--
-- DOWNPORT: see the header. `select(7, GetSpellInfo(name))` is castTime on this client, so that
-- approach is not merely unavailable — it silently returns a wrong-but-plausible number. All
-- resolution goes through the spellbook-derived rank table.
local function highestKnownRankID(spellID, name)
  if not (spellID and name) then return spellID end
  if SB and SB.HighestKnownRankID then return SB.HighestKnownRankID(spellID, name) end
  return spellID
end

-- Public wrapper so other surfaces (the settings catalog) can resolve a curated rank-1 id to the
-- player's highest learned rank for display.
function M.HighestKnownRank(spellID)
  if not spellID then return spellID end
  return highestKnownRankID(spellID, GetSpellInfo(spellID))
end

function ItemMixin:SetSpell(spellID)
  self._equipSlot = nil   -- spell-sourced: clear any prior trinket binding (pool slot reuse)
  local itemID, track = M.GetItemMeta(spellID)
  self._itemCDID = (track == "item") and itemID or nil

  local name = GetSpellInfo(spellID)
  -- A pure spell displays its highest learned rank; an on-use item entry keeps its own id (its
  -- "rank" is meaningless — icon and cooldown come from the item).
  local displayID = (not itemID) and highestKnownRankID(spellID, name) or spellID
  self.spellID = displayID

  -- The id the spell was LISTED under, kept alongside the displayed one. `spellID` is whatever rank
  -- the player currently knows, so it changes under the tile the moment they train the next rank —
  -- fine for reading a cooldown, wrong as a settings key. Per-spell preferences (alerts, ready
  -- sounds) hang off this stable id instead, or training a rank would silently orphan them.
  self._baseSpellID = spellID

  local icon
  name, _, icon = GetSpellInfo(displayID)
  self.spellName = name

  self._iconItemID = itemID or nil
  if itemID then
    local itemIcon = M.ResolveItemIcon(itemID)
    if itemIcon then icon = itemIcon end
  end

  self._rankCDIDs = (not self._itemCDID) and knownRankIDs(spellID, name) or nil
  if self.Icon then self.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
  self:RefreshCooldown()
end

-- Equipped on-use trinket. Cooldown is read live from the inventory slot; the use-spell drives the
-- usable tint and aura precedence, while the icon prefers the equipped item texture.
function ItemMixin:SetEquipSlot(slot, itemID, useSpellID)
  self._equipSlot   = slot
  self._equipItemID = itemID
  self._itemCDID    = nil
  self._rankCDIDs   = nil
  self.spellID      = useSpellID
  self._baseSpellID = useSpellID   -- item use-spells have no ranks, so this is already stable
  self.spellName    = useSpellID and GetSpellInfo(useSpellID) or nil
  self._iconItemID  = itemID or nil
  local icon = (GetInventoryItemTexture and GetInventoryItemTexture("player", slot))
    or M.ResolveItemIcon(itemID)
    or (useSpellID and select(3, GetSpellInfo(useSpellID)))
  if self.Icon then self.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
  self:RefreshCooldown()
end

-- Bag consumable (potion / healthstone). Cooldown comes from the ITEM, not the use-spell.
function ItemMixin:SetBagItem(itemID, useSpellID)
  self._equipSlot   = nil
  self._equipItemID = nil
  self._bagItemID   = itemID
  self._itemCDID    = itemID
  self._rankCDIDs   = nil
  self.spellID      = useSpellID
  self._baseSpellID = useSpellID
  self.spellName    = useSpellID and GetSpellInfo(useSpellID) or nil
  self._iconItemID  = itemID or nil
  local icon = M.ResolveItemIcon(itemID)
  if self.Icon then self.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
  self:RefreshCooldown()
end

-- Re-resolve the icon for an item-backed entry once the server delivers its data.
function ItemMixin:RefreshIcon()
  if not (self.Icon and self._iconItemID) then return end
  local icon
  if self._equipSlot then
    icon = (GetInventoryItemTexture and GetInventoryItemTexture("player", self._equipSlot))
      or M.ResolveItemIcon(self._iconItemID)
  else
    icon = M.ResolveItemIcon(self._iconItemID)
  end
  if icon then self.Icon:SetTexture(icon) end
end

function ItemMixin:SetTimerShown(shown)
  self.timerShown = shown
  NE.cd.ApplyNumbers(self.Cooldown, { show = shown })
end

function ItemMixin:SetTooltipsShown(shown)
  self.tooltipsShown = shown
end

function ItemMixin:SetHideWhenInactive(hide)
  self.hideWhenInactive = hide
  self:UpdateShownState()
end

-- Retail swipe colours. DOWNPORT: 3.3.5a Cooldown has no SetSwipeColor, so these are applied only
-- when the setter exists (i.e. never on this client). Kept so the aura/cooldown distinction is
-- still expressed in code and lights up automatically if the surface ever gains it.
M.COLOR_COOLDOWN = { 0,   0,    0,    0.7 }
M.COLOR_AURA     = { 1,   0.95, 0.57, 0.7 }
M.COLOR_WHITE    = { 1,   1,    1,    1   }

local function setSwipeColor(cooldown, c)
  if cooldown and cooldown.SetSwipeColor then
    cooldown:SetSwipeColor(c[1], c[2], c[3], c[4])
  end
end

-- GCD detection. Retail reads C_Spell.GetSpellCooldown(spellID).isOnGCD; we replicate the manual
-- probe: query the sentinel "Global Cooldown" spell and compare start+duration.
local GCD_PROBE_SPELL = 61304

local function isSpellOnGCD(spellID, start, duration)
  if not (start and start > 0 and duration and duration > 0) then return false end
  local gcdStart, gcdDuration = GetSpellCooldown(GCD_PROBE_SPELL)
  if not (gcdStart and gcdDuration and gcdDuration > 0) then return false end
  return math.abs(start - gcdStart) < 0.05 and math.abs(duration - gcdDuration) < 0.05
end

-- Cast-lockout: mid-cast/channel, GetSpellCooldown reports the cast duration as the "cooldown" of
-- the locked spells.
local function isCastLockoutCooldown(start, duration)
  if not (start and duration) then return false end
  local _, _, _, csMS, ceMS = UnitCastingInfo("player")
  if csMS and ceMS then
    local castStart = csMS / 1000
    local castDur   = (ceMS - csMS) / 1000
    if math.abs(start - castStart) < 0.05 and math.abs(duration - castDur) < 0.1 then return true end
  end
  local _, _, _, hsMS, heMS = UnitChannelInfo("player")
  if hsMS and heMS then
    local chStart = hsMS / 1000
    local chDur   = (heMS - hsMS) / 1000
    if math.abs(start - chStart) < 0.05 and math.abs(duration - chDur) < 0.1 then return true end
  end
  return false
end

-- A player buff/debuff matching this spell name. DOWNPORT: backed by NE.aura (core/AuraSnapshot.lua)
-- so the player's aura list is walked once per frame addon-wide. The returned entry keeps this
-- module's legacy field names (.expirationTime / .debuffType / .isHarmful).
local adaptedPool = {}

function M.findPlayerAuraDataByName(name)
  if not (name and NE.aura and NE.aura.FindByName) then return nil end
  local row, harmful = NE.aura.FindByName("player", name)
  if not row then return nil end
  local e = adaptedPool[name]
  if not e then e = {}; adaptedPool[name] = e end
  e.name           = row.name
  e.count          = row.count or 0
  e.duration       = row.duration or 0
  e.expirationTime = row.expiration or 0
  e.isHarmful      = harmful or nil
  e.debuffType     = harmful and row.dispelType or nil
  return e
end

-- Live totem lookup (Shaman): a tracked totem spell sources its swipe from the real totem timer.
-- 3.3.5a exposes GetTotemInfo(slot) -> haveTotem, name, startTime, duration, icon and fires
-- PLAYER_TOTEM_UPDATE, same as the source assumed.
function M.FindTotemByName(name)
  if not name then return nil end
  if not GetTotemInfo then return nil end
  local slots = (GetNumTotemSlots and GetNumTotemSlots()) or MAX_TOTEMS or 4
  for slot = 1, slots do
    local haveTotem, totemName, startTime, duration = GetTotemInfo(slot)
    if haveTotem and totemName and totemName ~= "" and duration and duration > 0 then
      if totemName == name or totemName:find(name, 1, true) or name:find(totemName, 1, true) then
        return startTime, duration
      end
    end
  end
  return nil
end

-- Duration-based GCD threshold, used when the 61304 probe is unavailable.
M.GCD_MAX = 1.51

-- Rank-safe cooldown read. Try the keyed id, then every known rank (returning the one with the
-- longest remaining cooldown — the rank actually cast, regardless of up/down-ranking), then name.
function M.SpellCD(spellID, spellName, rankIDs)
  local start, duration, enabled = GetSpellCooldown(spellID)
  if start and start > 0 then return start, duration, enabled end
  if rankIDs then
    local bestStart, bestDur, bestEnab, bestEnd = nil, nil, nil, 0
    for i = 1, #rankIDs do
      local s, d, e = GetSpellCooldown(rankIDs[i])
      if s and s > 0 and d and d > 0 and (s + d) > bestEnd then
        bestStart, bestDur, bestEnab, bestEnd = s, d, e, s + d
      end
    end
    if bestStart then return bestStart, bestDur, bestEnab end
  end
  if spellName then
    local s2, d2, e2 = GetSpellCooldown(spellName)
    if s2 and s2 > 0 then return s2, d2, e2 end
  end
  return start, duration, enabled
end

-- Read this item's cooldown, returning ALL THREE values.
--
-- MUST stay an explicit branch. The tempting one-liner
--   local start, duration, enabled = self._itemCDID and M.ItemCooldown(...) or M.SpellCD(...)
-- is the multi-return truncation trap: Lua adjusts an `or` operand to ONE value, so duration and
-- enabled arrive nil and every refresh computes cooldownIsActive=false. That was the whole
-- "doesn't show cooldowns on cooldown" bug upstream.
function ItemMixin:ReadCooldown()
  if self._equipSlot then return GetInventoryItemCooldown("player", self._equipSlot) end
  if self._itemCDID then return M.ItemCooldown(self._itemCDID) end
  return M.SpellCD(self.spellID, self.spellName, self._rankCDIDs)
end

function ItemMixin:UpdateShownState()
  if not (self.spellID or self._bagItemID) then self:Hide(); return end
  -- Retail's ShouldBeShown: items whose template doesn't set allowHideWhenInactive ALWAYS show.
  -- Essential and Utility both fall in that category — they show every configured cooldown the
  -- player knows, on or off cooldown. Only BuffIcon/BuffBar honour hideWhenInactive.
  if not self.allowHideWhenInactive then self:Show(); return end
  if not self.hideWhenInactive then self:Show(); return end

  local aura = M.findPlayerAuraDataByName(self.spellName)
  if aura and aura.duration > 0 and aura.expirationTime > GetTime() then
    self:Show()
    return
  end
  local start, duration = self:ReadCooldown()
  local hasCooldown = start and start > 0 and duration and duration > 0
  if hasCooldown
     and not isSpellOnGCD(self.spellID, start, duration)
     and not isCastLockoutCooldown(start, duration)
     and duration > M.GCD_MAX then
    self:Show()
  else
    self:Hide()
  end
end

-- ── Ready flash ─────────────────────────────────────────────────────────────────────────────────
-- The GCD flipbook sprite stepper. DOWNPORT: the source drives this from the generated NE_ATLAS
-- table; we read our own NE.tex registry. Phase 1 does not ship the flipbook art, so getFlashAtlas
-- returns nil and the whole path degrades to "no flash" rather than erroring — the structure is
-- kept so dropping the BLP in later is the only change needed.
local FLASH_DURATION = 0.75
local FLASH_FRAMES   = 22
local FLASH_ROWS     = 11
local FLASH_COLS     = 2

local function getFlashAtlas()
  if not (NE.tex and NE.tex.GetAtlasRect) then return nil end
  return NE.tex.GetAtlasRect("UI-HUD-ActionBar-GCD-Flipbook")
end

local function flashOnUpdate(flash)
  local now = GetTime()
  local start = flash._flashStartTime
  if not start then flash:SetScript("OnUpdate", nil); flash:Hide(); return end
  if now < start then return end
  local progress = (now - start) / FLASH_DURATION
  if progress >= 1 then
    flash:SetScript("OnUpdate", nil)
    flash:Hide()
    if flash.Flipbook then flash.Flipbook:SetAlpha(0) end
    flash._flashStartTime = nil
    return
  end
  if flash.Flipbook then flash.Flipbook:SetAlpha(1) end
  local atlas = getFlashAtlas()
  if not (atlas and flash.Flipbook) then return end
  local frame = math.floor(progress * FLASH_FRAMES)
  if frame >= FLASH_FRAMES then frame = FLASH_FRAMES - 1 end
  local col = frame % FLASH_COLS
  local row = math.floor(frame / FLASH_COLS)
  local frameW = (atlas.right - atlas.left) / FLASH_COLS
  local frameH = (atlas.bottom - atlas.top) / FLASH_ROWS
  local l = atlas.left + col * frameW
  local t = atlas.top  + row * frameH
  flash.Flipbook:SetTexCoord(l, l + frameW, t, t + frameH)
end

function ItemMixin:ScheduleFlash(start, duration)
  local flash = self.CooldownFlash
  if not flash then return end
  if not getFlashAtlas() then return end   -- art not shipped yet: no-op cleanly
  if self._flashScheduledFor == start and self._flashScheduledDur == duration then return end
  self._flashScheduledFor = start
  self._flashScheduledDur = duration
  local playStart = (start + duration) - FLASH_DURATION
  if playStart <= GetTime() then
    flash:Hide()
    flash:SetScript("OnUpdate", nil)
    return
  end
  flash._flashStartTime = playStart
  if flash.Flipbook then flash.Flipbook:SetAlpha(0) end
  flash:Show()
  flash:SetScript("OnUpdate", flashOnUpdate)
end

function ItemMixin:ClearFlash()
  self._flashScheduledFor = nil
  self._flashScheduledDur = nil
  local flash = self.CooldownFlash
  if flash then
    flash:SetScript("OnUpdate", nil)
    flash:Hide()
    flash._flashStartTime = nil
    if flash.Flipbook then flash.Flipbook:SetAlpha(0) end
  end
end

-- ── Icon tint ───────────────────────────────────────────────────────────────────────────────────
-- Priority: out-of-range red > usable white > not-enough-mana blue > not-usable grey, plus the OOR
-- shadow overlay. Composes with SetDesaturated (orthogonal).
M.ICON_USABLE     = { 1.0,  1.0,  1.0  }
M.ICON_OOM        = { 0.5,  0.5,  1.0  }
M.ICON_UNUSABLE   = { 0.4,  0.4,  0.4  }
M.ICON_OUTOFRANGE = { 0.64, 0.15, 0.15 }

-- DOWNPORT: SetShown does not exist on 3.3.5a (CONTRACTS §0).
local function setShown(region, shown)
  if not region then return end
  if shown then region:Show() else region:Hide() end
end

function ItemMixin:RefreshIconColor()
  if not self.Icon then return end

  -- Equipped trinket / bag consumable: tint from ITEM usability. IsUsableSpell on a use-spell
  -- returns false (it isn't a known player spell), which would wrongly grey a usable trinket.
  local itemForUsability = self._equipSlot and self._equipItemID or self._bagItemID
  if itemForUsability or self._equipSlot then
    local usable = true
    if IsUsableItem and itemForUsability then usable = IsUsableItem(itemForUsability) and true or false end
    local c = usable and M.ICON_USABLE or M.ICON_UNUSABLE
    self.Icon:SetVertexColor(c[1], c[2], c[3])
    setShown(self.OutOfRange, false)
    return
  end

  if not self.spellID then return end

  -- DOWNPORT: C_Spell.IsSpellUsable is absent on this client (neither ClassicAPI nor compat provides
  -- it), so we use the 3.3.5a global directly.
  local usable, oom
  if IsUsableSpell then usable, oom = IsUsableSpell(self.spellID) end

  -- Range only matters with a live target and a spell that actually range-checks. 3.3.5a's
  -- IsSpellInRange takes a NAME and returns 1/0/nil (nil = no range check applies).
  local outOfRange = false
  if UnitExists("target") and IsSpellInRange and self.spellName then
    local r = IsSpellInRange(self.spellName, "target")
    if r ~= nil then outOfRange = (r == 0) end
  end

  local c = outOfRange and M.ICON_OUTOFRANGE
    or usable and M.ICON_USABLE
    or oom and M.ICON_OOM
    or M.ICON_UNUSABLE
  self.Icon:SetVertexColor(c[1], c[2], c[3])
  setShown(self.OutOfRange, outOfRange)
end

-- ── The refresh ─────────────────────────────────────────────────────────────────────────────────
-- Retail contract:
--   isOnActualCooldown  = not isOnGCD and cooldownIsActive
--   cooldownDesaturated = isOnActualCooldown   -- bright on GCD, grey on a real CD
--   cooldownPlayFlash   = isOnActualCooldown
-- Aura precedence: an active self-aura overrides with the (retail: golden) swipe and no desaturation.
function ItemMixin:RefreshCooldown()
  if not self.spellID or not self.Cooldown then return end

  self:RefreshIconColor()

  -- 1. Aura precedence.
  local aura = M.findPlayerAuraDataByName(self.spellName)
  if aura and aura.duration > 0 and aura.expirationTime > GetTime() then
    local auraStart = aura.expirationTime - aura.duration
    setSwipeColor(self.Cooldown, M.COLOR_AURA)
    if self.Cooldown.SetDrawSwipe then self.Cooldown:SetDrawSwipe(true) end
    CooldownFrame_Set(self.Cooldown, auraStart, aura.duration, 1)
    if self.Icon then self.Icon:SetDesaturated(false) end
    self:ClearFlash()
    if self.hideWhenInactive then self:Show() end
    return
  end

  -- 1b. Totem precedence (Shaman): source the swipe from the live totem timer; falls through to the
  -- normal cooldown path once the totem is gone, so the cast CD still shows.
  local totemStart, totemDur = M.FindTotemByName(self.spellName)
  if totemStart and totemDur and totemDur > 0 then
    setSwipeColor(self.Cooldown, M.COLOR_AURA)
    if self.Cooldown.SetDrawSwipe then self.Cooldown:SetDrawSwipe(true) end
    CooldownFrame_Set(self.Cooldown, totemStart, totemDur, 1)
    if self.Icon then self.Icon:SetDesaturated(false) end
    self:ClearFlash()
    if self.hideWhenInactive then self:Show() end
    return
  end

  -- 2. Spell cooldown.
  local start, duration, enabled = self:ReadCooldown()
  local cooldownIsActive = start and start > 0 and duration and duration > 0 and enabled == 1

  if cooldownIsActive then
    -- No isOnGCD flag on this client. Use the duration heuristic, then catch cast/channel lockout
    -- (while mid-cast, all OTHER spells report a "cooldown" matching the cast duration).
    local isOnGCD = duration <= M.GCD_MAX
    if not isOnGCD then isOnGCD = isCastLockoutCooldown(start, duration) end
    local isOnActualCooldown = not isOnGCD

    -- Arm the ready-transition flag. ARM-ONLY here — never clear on this path — so a frequent
    -- refresh can't wipe a pending transition before the detector observes it.
    if isOnActualCooldown then self._wasOnRealCD = true end

    if self.Cooldown.SetDrawSwipe then self.Cooldown:SetDrawSwipe(true) end
    setSwipeColor(self.Cooldown, M.COLOR_COOLDOWN)
    CooldownFrame_Set(self.Cooldown, start, duration, enabled)

    if self.Icon then self.Icon:SetDesaturated(isOnActualCooldown) end

    if isOnActualCooldown then
      self:ScheduleFlash(start, duration)
    else
      self:ClearFlash()
    end
  else
    CooldownFrame_Clear(self.Cooldown)
    if self.Icon then self.Icon:SetDesaturated(false) end
    self:ClearFlash()
  end

  if self.hideWhenInactive then self:UpdateShownState() end
end

-- Is this item on a REAL cooldown right now — not the GCD, not a cast/channel lockout?
function ItemMixin:IsOnRealCooldown()
  if not self.spellID then return false end
  local start, duration, enabled = self:ReadCooldown()
  if not (start and start > 0 and duration and duration > 0 and enabled == 1) then return false end
  if duration <= M.GCD_MAX then return false end
  if isSpellOnGCD(self.spellID, start, duration) then return false end
  if isCastLockoutCooldown(start, duration) then return false end
  return true
end

-- True EXACTLY ONCE per real-cooldown -> ready transition. Alerts.lua's ticker consumes this.
function ItemMixin:ConsumeReadyTransition()
  if self:IsOnRealCooldown() then
    self._wasOnRealCD = true
    return false
  end
  if self._wasOnRealCD then
    self._wasOnRealCD = false
    return true
  end
  return false
end

-- Fire everything assigned to this spell's "ability is ready" event: the visual alert flash and the
-- ready sound. Called once per transition by the alert ticker, which owns the edge detection.
--
-- Self-gating: both halves no-op unless the player assigned something, so an unconfigured spell
-- costs two table lookups and makes no sound.
function ItemMixin:FireReadyAlerts()
  local key = self:GetSettingsKey()
  if not key then return end
  if M.alerts and M.alerts.OnAvailable then
    M.alerts.OnAvailable(self)
  end
  if M.GetReadySoundKit and M.PlayReadySound then
    local kit = M.GetReadySoundKit(key)
    if kit then M.PlayReadySound(kit) end
  end
end

-- The id every per-spell PREFERENCE is stored under. See the note in SetSpell: never use
-- `spellID` for this, it tracks the learned rank and moves.
function ItemMixin:GetSettingsKey()
  return self._baseSpellID or self.spellID
end

-- ── Tooltip ─────────────────────────────────────────────────────────────────────────────────────
-- DOWNPORT: 3.3.5a GameTooltip has no SetSpellByID. !!!ClassicAPI adds SetItemByID (WidgetAPI.lua)
-- but not the spell equivalent, so we fall back to the spell hyperlink, which 3.3.5a does support.
local function tooltipSetSpell(tip, spellID)
  if tip.SetSpellByID then
    local ok = pcall(tip.SetSpellByID, tip, spellID)
    if ok then return true end
  end
  return pcall(tip.SetHyperlink, tip, "spell:" .. spellID)
end
M.TooltipSetSpell = tooltipSetSpell   -- reused by the aura item mixins (AuraItemMixins.lua)

-- Shared icon-crop helper: what stands in for the removed rounded MaskTexture.
function M.CropIcon(tex)
  if not tex then return end
  if NE.tex and NE.tex.CropIcon then
    NE.tex.CropIcon(tex)
  elseif tex.SetTexCoord then
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
end

function ItemMixin:OnEnter()
  if self.tooltipsShown == false then return end
  if self._equipSlot then
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetInventoryItem("player", self._equipSlot)
    GameTooltip:Show()
    return
  end
  if self._bagItemID then
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(self._bagItemID)
    else
      GameTooltip:SetHyperlink("item:" .. self._bagItemID)
    end
    GameTooltip:Show()
    return
  end
  if not self.spellID then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  if tooltipSetSpell(GameTooltip, self.spellID) then GameTooltip:Show() end
end

function ItemMixin:OnLeave()
  GameTooltip:Hide()
end
