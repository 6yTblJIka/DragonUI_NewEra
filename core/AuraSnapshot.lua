-- DragonUI_NewEra/core/AuraSnapshot.lua — one aura scan per unit per frame (NE.aura).
--
-- DOWNPORT of NewEra's Core/Aura.lua. Purpose is unchanged: consumers that need "is aura X on unit
-- Y right now" would each run their own 1..40 UnitBuff loop, and during aura bursts UNIT_AURA can
-- fire many times per frame — so the same list gets walked over and over. This walks it ONCE per
-- (unit, filter) per frame and hands out a shared read-only view.
--
-- PUBLIC:
--   NE.aura.GetSnapshot(unit, filter) -> { byName = {[name]=row}, byNameMine = {...},
--                                          list = {row,...}, n = <count> }
--     filter: "HELPFUL" (default) or "HARMFUL"
--     row:    { name, icon, count, duration, expiration, dispelType, spellID, index, mine }
--
-- `mine` / `byNameMine` exist because "is this aura up" and "is MY aura up" are different questions
-- and the second one is the one a cooldown tile is asking. A druid standing next to another druid
-- has Moonfire on the target either way; only one of them should see their Moonfire tile lit. The
-- caster was always in the return and was always discarded — this keeps it.
--
-- The returned tables are POOLED and rewritten on the next frame's scan — read within the frame,
-- never retain. (NewEra documents the same contract.)
--
-- !! 3.3.5a ARG-POSITION HAZARD (CONTRACTS §0: "some Blizzard returns are at shifted arg positions")
-- UnitAura on 3.3.5a returns `rank` as the SECOND value, which was removed in MoP:
--     3.3.5a : name, RANK, icon, count, dispelType, duration, expirationTime, caster, ..., spellID
--     modern : name,       icon, count, dispelType, duration, expirationTime, caster, ..., spellID
-- Every index after the first is shifted by one versus the NewEra source this is ported from. The
-- source's own comment (CooldownViewer.lua ScanTargetTrackedAuras) documents the MODERN layout —
-- do not copy those indices over.

local NE = DragonUI_NewEra
NE.aura = NE.aura or {}

local UnitBuff, UnitDebuff, GetTime = UnitBuff, UnitDebuff, GetTime

-- Per (unit .. filter) cached snapshot: { stamp = <GetTime at scan>, byName = {}, list = {}, n = }
-- GetTime() is constant for the whole frame in WoW, so it is a correct and cheap frame key.
local cache = {}

local MAX_AURAS = 40

-- How many real (uncached) walks this session. One increment per SCAN, not per aura, because the
-- scan is the unit of cost: each one is a loop of up to MAX_AURAS API calls. Read by the offline
-- harness to hold the cooldown viewer's per-frame scan count to a budget — the friend-unit lookup
-- added for Earth Shield can touch seven units, and "it is cached" is a claim worth testing rather
-- than asserting.
NE.aura._scans = 0

local function scan(snapshot, unit, filter)
  NE.aura._scans = NE.aura._scans + 1
  local fn = (filter == "HARMFUL") and UnitDebuff or UnitBuff

  local byName, byNameMine, list = snapshot.byName, snapshot.byNameMine, snapshot.list
  for k in pairs(byName) do byName[k] = nil end
  for k in pairs(byNameMine) do byNameMine[k] = nil end

  local n = 0
  for i = 1, MAX_AURAS do
    -- 3.3.5a layout — see the hazard note in the file header.
    local name, _rank, icon, count, dispelType, duration, expiration, caster,
          _isStealable, _shouldConsolidate, spellID = fn(unit, i)
    if not name then break end

    n = n + 1
    local row = list[n]
    if not row then row = {}; list[n] = row end

    row.name       = name
    row.icon       = icon
    row.count      = count or 0
    row.dispelType = dispelType
    row.duration   = duration or 0
    row.expiration = expiration or 0
    row.spellID    = spellID
    row.index      = i
    row.caster     = caster
    -- "player" is the only token that means us. A pet's aura is the PET's, not ours, and a tile
    -- reporting Growl as the player's would be wrong in exactly the way this field exists to stop.
    row.mine       = (caster == "player")

    -- First occurrence wins: with two ranks of the same buff present, the lower index is the one
    -- the UI conventionally shows.
    if byName[name] == nil then byName[name] = row end
    -- A SEPARATE index rather than a filter over the first: with two casters' Moonfire on one
    -- target, byName holds whichever came first and a post-hoc `.mine` test on it would answer "no"
    -- while the player's own Moonfire sat two slots further down.
    if row.mine and byNameMine[name] == nil then byNameMine[name] = row end
  end

  snapshot.n = n
  return snapshot
end

function NE.aura.GetSnapshot(unit, filter)
  if not unit then return nil end
  filter = filter or "HELPFUL"

  -- A unit that isn't present yields an empty (but valid) snapshot, so callers never nil-check.
  local key = unit .. filter
  local snapshot = cache[key]
  if not snapshot then
    snapshot = { byName = {}, byNameMine = {}, list = {}, n = 0, stamp = -1 }
    cache[key] = snapshot
  end

  local now = GetTime()
  if snapshot.stamp == now then return snapshot end
  snapshot.stamp = now

  if not UnitExists(unit) then
    for k in pairs(snapshot.byName) do snapshot.byName[k] = nil end
    for k in pairs(snapshot.byNameMine) do snapshot.byNameMine[k] = nil end
    snapshot.n = 0
    return snapshot
  end

  return scan(snapshot, unit, filter)
end

-- Convenience: the row for one aura name, or nil. Buff-preferred, then debuff — the order the
-- CooldownViewer's findPlayerAuraDataByName relies on.
--
-- `mineOnly` restricts to auras the PLAYER cast. Off by default, because the original caller asks
-- about the player's own buffs where the distinction cannot arise; on for anything reading another
-- unit, where it always can.
--
-- `only` restricts to ONE list, "HELPFUL" or "HARMFUL", instead of trying both. That halves the scan
-- count for a caller that already knows which it wants, and one does: a buff you cast on an ally is
-- helpful by construction, so the cooldown viewer's friend-unit lookup has no reason to walk the
-- debuff list of seven units to find Earth Shield.
function NE.aura.FindByName(unit, name, mineOnly, only)
  if not (unit and name) then return nil end
  local key = mineOnly and "byNameMine" or "byName"
  if only ~= "HARMFUL" then
    local snap = NE.aura.GetSnapshot(unit, "HELPFUL")
    local row = snap and snap[key][name]
    if row then return row, false end
    if only == "HELPFUL" then return nil end
  end
  local snap = NE.aura.GetSnapshot(unit, "HARMFUL")
  local row = snap and snap[key][name]
  if row then return row, true end
  return nil
end
