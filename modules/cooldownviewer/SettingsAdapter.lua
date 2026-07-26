-- DragonUI_NewEra/modules/cooldownviewer/SettingsAdapter.lua — the category model the /cdm panel
-- talks to. Downport of NewEra/CooldownViewerSettings/DataAdapter.lua.
--
-- The panel never touches the spell lists directly; everything goes through here. That indirection
-- is upstream's design and it earns its keep twice over: our storage model differs from theirs (we
-- keep a per-category editable list with `enabled` flags, they keep one list per bucket), and if a
-- Classic Plus client ever ships C_CooldownViewer this is the single file that would swap.
--
-- CATEGORIES. Six, in two display modes:
--   spells: Essential / Utility  — the editable lists
--           Hidden              — the ARSENAL, i.e. every class ability with a real cooldown that
--                                 is not currently in a viewer. This is what makes the panel a
--                                 picker rather than an undo list.
--   auras : Tracked Buffs / Tracked Bars / Hidden — the unified tracked-aura pool, keyed by each
--                                 entry's assignment ("icon" / "bar" / "hidden").
--
-- The two Equip source pools (on-use trinkets, trinket procs) are NOT here yet — CooldownViewerEquip
-- is still stubbed. They slot in as two more `source` categories when it lands; PORT_PLAN §G.4.
--
-- "Hidden" is a CATALOG, not a bucket. For spells it is computed — arsenal minus what is placed —
-- rather than stored, so a newly-generated ability appears in it automatically. For auras it IS a
-- stored assignment, because an aura the player force-hides has to stay hidden against a live scan.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

NE.cooldownviewersettings = NE.cooldownviewersettings or {}
local CDS = NE.cooldownviewersettings

local Adapter = {}
CDS.adapter = Adapter

-- Prefer a client GlobalString where 3.3.5a ships one, else an English literal — the house pattern.
local function GS(key, fallback)
  local v = _G[key]
  return (v ~= nil and v ~= "") and v or fallback
end

-- kind: "icon" (grid of tiles) | "bar" (stacked rows).
-- list: the editable-list key for spell categories. aura: the assignment value for aura categories.
local CATS = {
  essential   = { mode = "spells", kind = "icon", label = GS("COOLDOWN_VIEWER_SETTINGS_CATEGORY_ESSENTIAL", "Essential"), list = "essential" },
  utility     = { mode = "spells", kind = "icon", label = GS("COOLDOWN_VIEWER_SETTINGS_CATEGORY_UTILITY",   "Utility"),   list = "utility"   },
  hiddenSpell = { mode = "spells", kind = "icon", label = GS("COOLDOWN_VIEWER_SETTINGS_CATEGORY_NOT_IN_BAR", "Hidden")                       },
  trackedBuff = { mode = "auras",  kind = "icon", label = GS("COOLDOWN_VIEWER_SETTINGS_CATEGORY_TRACKED_BUFF", "Tracked Buffs"), aura = "icon"   },
  trackedBar  = { mode = "auras",  kind = "bar",  label = GS("COOLDOWN_VIEWER_SETTINGS_CATEGORY_TRACKED_BARS", "Tracked Bars"),  aura = "bar"    },
  hiddenAura  = { mode = "auras",  kind = "icon", label = GS("COOLDOWN_VIEWER_SETTINGS_CATEGORY_NOT_IN_BAR",   "Hidden"),        aura = "hidden" },
}

Adapter.MODE_ORDER = {
  spells = { "essential", "utility", "hiddenSpell" },
  auras  = { "trackedBuff", "trackedBar", "hiddenAura" },
}

function Adapter.Meta(catID)  return CATS[catID] end
function Adapter.Label(catID) return CATS[catID] and CATS[catID].label or catID end
function Adapter.Kind(catID)  return CATS[catID] and CATS[catID].kind or "icon" end
function Adapter.Mode(catID)  return CATS[catID] and CATS[catID].mode or "spells" end

-- ── Spell categories ────────────────────────────────────────────────────────────────────────────

-- true = listed and on, false = listed and off, nil = NOT MENTIONED (no list, or absent from it).
-- The nil case matters: it is what sends isPlaced to the curated defaults. Returning false for a
-- missing list instead of nil made that fallback unreachable and put every curated spell into the
-- Hidden catalog alongside itself.
local function listHasEnabled(list, id)
  if not list then return nil end
  for _, e in ipairs(list) do
    if e.spellID == id then return e.enabled and true or false end
  end
  return nil
end

-- Is this spell currently placed in ANY spell viewer?
local function isPlaced(id, class)
  for _, key in ipairs({ "essential", "utility" }) do
    local state = listHasEnabled(M.GetCustomList(key, class), id)
    if state == true then return true end
    if state == nil then
      -- No custom list, or the spell isn't in it: fall back to the curated default.
      local src = M.SPELL_DATA_BY_CATEGORY[key] and M.SPELL_DATA_BY_CATEGORY[key][class]
      if src and not M.GetCustomList(key, class) then
        for _, cid in ipairs(src) do if cid == id then return true end end
      end
    end
  end
  return false
end

-- The Hidden catalog: every class ability with a real cooldown that is not currently placed, plus
-- the player's racials. Race-impossible spells are dropped outright — "show unlearned" is about
-- level, not about abilities this character can never have.
local function hiddenSpells(class)
  local seen, out = {}, {}
  local function consider(id)
    if not id or seen[id] then return end
    seen[id] = true
    if M.SpellAllowedForRace and not M.SpellAllowedForRace(id) then return end
    if not isPlaced(id, class) then out[#out + 1] = id end
  end

  local arsenal = M.ARSENAL_BY_CLASS and M.ARSENAL_BY_CLASS[class]
  if arsenal then for _, id in ipairs(arsenal) do consider(id) end end

  -- Curated ids act as a floor: an ability the curation added but the generator missed still has to
  -- be re-addable after the player removes it.
  for _, key in ipairs({ "essential", "utility" }) do
    local src = M.SPELL_DATA_BY_CATEGORY[key] and M.SPELL_DATA_BY_CATEGORY[key][class]
    if src then for _, id in ipairs(src) do consider(id) end end
  end

  local _, race = UnitRace("player")
  local rb = race and M.RACIAL_BY_RACE and M.RACIAL_BY_RACE[race]
  if rb then
    for _, key in ipairs({ "essential", "utility" }) do
      if rb[key] then for _, id in ipairs(rb[key]) do consider(id) end end
    end
  end
  return out
end

-- ── Items for a category ────────────────────────────────────────────────────────────────────────

function Adapter.GetItems(catID, class)
  if not class then local _; _, class = UnitClass("player") end
  local meta = CATS[catID]
  if not (meta and class) then return {} end

  local out = {}

  if meta.aura then
    for _, e in ipairs(M.GetTrackedAuraList(class) or {}) do
      if (e.assignment or "icon") == meta.aura then out[#out + 1] = e.spellID end
    end
    return out
  end

  if meta.list then
    -- The learn gate applies here: Essential/Utility should show what you can cast, unless the
    -- player has asked to see everything.
    local showAll = M.GetShowUnlearned and M.GetShowUnlearned()
    for _, id in ipairs(M.GetActiveSpellList(meta.list, showAll and true or false)) do
      out[#out + 1] = id
    end
    return out
  end

  -- Hidden: always the full catalog, learn state ignored. A fresh character seeing an empty picker
  -- reads as broken, and the tile tints unlearned entries instead.
  for _, id in ipairs(hiddenSpells(class)) do out[#out + 1] = id end
  return out
end

-- ── Moves ───────────────────────────────────────────────────────────────────────────────────────
-- Mirrors retail's legalOriginalSourceCategoryToTargetCategory. Same category is always legal
-- (that is a reorder, not a move).
local LEGAL = {
  essential   = { utility = true, hiddenSpell = true },
  utility     = { essential = true, hiddenSpell = true },
  hiddenSpell = { essential = true, utility = true },
  trackedBuff = { trackedBar = true, hiddenAura = true },
  trackedBar  = { trackedBuff = true, hiddenAura = true },
  hiddenAura  = { trackedBuff = true, trackedBar = true },
}

function Adapter.CanTarget(fromCat, toCat)
  if not (fromCat and toCat) then return false end
  if fromCat == toCat then return true end
  local t = LEGAL[fromCat]
  return (t and t[toCat]) and true or false
end

function Adapter.GetValidTargets(fromCat)
  local meta = CATS[fromCat]
  if not meta then return {} end
  local out = {}
  for _, id in ipairs(Adapter.MODE_ORDER[meta.mode]) do
    if id ~= fromCat and Adapter.CanTarget(fromCat, id) then out[#out + 1] = id end
  end
  return out
end

-- Move a spell or aura between categories.
function Adapter.Assign(spellID, fromCat, toCat, class)
  if not (spellID and Adapter.CanTarget(fromCat, toCat)) then return false end
  if not class then local _; _, class = UnitClass("player") end

  local fromMeta, toMeta = CATS[fromCat], CATS[toCat]
  if not (fromMeta and toMeta) then return false end

  -- Auras are one pool keyed by assignment, so a move is a single write.
  if toMeta.aura then
    M.SetAuraAssignment(class, spellID, toMeta.aura)
    return true
  end

  -- Spells: clear the old placement, then set the new one. Hidden is the ABSENCE of a placement,
  -- which is why it has no list of its own.
  if fromMeta.list then M.SetSpellEnabled(fromMeta.list, spellID, false) end
  if toMeta.list   then M.SetSpellEnabled(toMeta.list,   spellID, true)  end
  return true
end

-- Remove a user-added entry outright. Only meaningful for auras: a spell's "removal" is just
-- returning it to the Hidden catalog, which Assign already does.
function Adapter.IsRemovable(spellID, catID, class)
  local meta = CATS[catID]
  if not (meta and meta.aura and spellID) then return false end
  if not class then local _; _, class = UnitClass("player") end
  for _, e in ipairs(M.GetTrackedAuraList(class) or {}) do
    if e.spellID == spellID then return true end
  end
  return false
end

function Adapter.Remove(spellID, catID, class)
  if not Adapter.IsRemovable(spellID, catID, class) then return false end
  if not class then local _; _, class = UnitClass("player") end
  M.RemoveTrackedAura(class, spellID)
  return true
end

-- Reorder within a category. Spell order is the editable list's order; aura order is the pool's.
function Adapter.MoveWithin(catID, spellID, delta, class)
  local meta = CATS[catID]
  if not (meta and meta.list and spellID and delta ~= 0) then return false end
  if not class then local _; _, class = UnitClass("player") end

  local list = M.GetEditableList(meta.list, class)
  if not list then return false end
  for i, e in ipairs(list) do
    if e.spellID == spellID then
      local j = i + delta
      if j < 1 or j > #list then return false end
      list[i], list[j] = list[j], list[i]
      M.RefreshActiveViewer(meta.list)
      return true
    end
  end
  return false
end
