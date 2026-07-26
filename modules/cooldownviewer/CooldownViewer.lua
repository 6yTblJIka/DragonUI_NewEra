-- DragonUI_NewEra/modules/cooldownviewer/CooldownViewer.lua — Cooldown Manager core.
--
-- DOWNPORT of NewEra/CooldownViewer/CooldownViewer.lua. Retail's Cooldown Manager reads its
-- per-spec cooldown sets from C_CooldownViewer, which does not exist on 3.3.5a (nor on Classic Era
-- or TBC Classic — NewEra hit the same wall). So this is retail's VISUAL model driven by curated
-- per-class data plus live GetSpellCooldown / UNIT_AURA reads, exactly as upstream built it.
--
-- PHASE 1 SCOPE: Essential + Utility viewers. BuffIcon / BuffBar (aura-driven) are Phase 3; the
-- alert engine and the standalone settings panel are Phase 4. The category plumbing below keeps all
-- four names so those phases are additive.
--
-- THE ONE STRUCTURAL DEVIATION — settings storage:
--
-- Upstream reads every setting through `NE.editmode` (EM.Register / EM.GetFrameSettingStored /
-- EM.const.StoredToDisplay), a 6,441-line reimplementation of retail Edit Mode. This addon does not
-- have it, DragonUI's movers are position-only, and DragonUI is read-only (CONTRACTS §0). Per
-- PORT_PLAN §B1 we drop Edit Mode entirely: `getOpt` is the single chokepoint every setting reads
-- through, so it is retargeted at our own profile table and the retail settings-int codec
-- (M.CDV_CODEC, sliderToStored, StoredToDisplay) is gone. Positions come from DragonUI's
-- MoversSystem; the ten settings are rendered in the New Era options tab.

local NE = DragonUI_NewEra
NE.cooldownviewer = NE.cooldownviewer or {}
local M = NE.cooldownviewer

-- Curated per-class/per-race data lives in ClassData.lua (loaded before this file):
-- M.ESSENTIAL_BY_CLASS / UTILITY_BY_CLASS / BUFFICON_BY_CLASS / BUFFBAR_BY_CLASS /
-- SPELL_DATA_BY_CATEGORY / RACIAL_BY_RACE.

-- Upstream defines this in the buff-viewer section (Phase 3). Declared here so ShouldTrackBuff and
-- the curated-set walk can reference it unconditionally.
M.BUFFBAR_EXCLUDE = M.BUFFBAR_EXCLUDE or {}

-- Defaults, from retail's HUDLayout preset (EditModePresetLayouts.lua).
M.DEFAULTS = {
  orientation      = "horizontal",
  iconLimit        = 12,
  iconDirection    = "right",
  iconSize         = 100,
  iconPadding      = 2,
  opacity          = 100,
  visibleSetting   = "always",
  hideWhenInactive = true,
  showTimer        = true,
  showTooltips     = true,
  -- BuffBar-only (Phase 3). Retail's Modern preset stores BarWidthScale such that it displays as
  -- 150%; upstream's owner reduced that to 100% once the pixel pin was removed, which is what we
  -- take here.
  barContent       = "iconAndName",
  barWidthScale    = 100,
}

M.FRAME_ID = {
  essential = "CooldownViewerEssential",
  utility   = "CooldownViewerUtility",
  buffIcon  = "CooldownViewerBuffIcon",
  buffBar   = "CooldownViewerBuffBar",
}

-- Per-frame overrides (retail preset values).
--
-- Essential/Utility templates do NOT set `allowHideWhenInactive` in retail XML, so retail's
-- ShouldBeShown returns true unconditionally — they always show known cooldowns regardless of the
-- HideWhenInactive setting. Only BuffIcon and BuffBar honour it. UpdateShownState reads this.
local PER_FRAME_DEFAULT_OVERRIDES = {
  CooldownViewerEssential = { iconLimit = 12, allowHideWhenInactive = false },
  CooldownViewerUtility   = { iconLimit = 7,  allowHideWhenInactive = false },
  CooldownViewerBuffIcon  = { iconLimit = 1,  iconPadding = 5, allowHideWhenInactive = true },
  CooldownViewerBuffBar   = { iconLimit = 1,  iconPadding = 5, allowHideWhenInactive = true,
                              orientation = "vertical", iconDirection = "left" },
}
M.PER_FRAME_DEFAULT_OVERRIDES = PER_FRAME_DEFAULT_OVERRIDES

-- Default anchors (retail Mainline preset), consumed by Register.lua as the movers' defaultPoint.
-- BuffBar is offset to x=420 in retail's preset (see BuffViewers.lua CreateBuffViewer), the others
-- are horizontally centred.
M.VIEWER_DEFAULT_Y = { utility = 240, essential = 310, buffIcon = 370, buffBar = 430 }

-- ── Settings store ──────────────────────────────────────────────────────────────────────────────
-- Lives in DragonUI's profile alongside every other NewEra setting (integration/Register.lua
-- ensureProfile owns the `newera` sub-table), so it follows DragonUI profiles and the options tab
-- can bind to it directly.
local function store(create)
  local cfg = NE.Config and NE.Config()
  if not cfg then return nil end
  if not cfg.cooldownviewer then
    if not create then return nil end
    cfg.cooldownviewer = {}
  end
  local cd = cfg.cooldownviewer
  if not cd.frames then
    if not create then return cd end
    cd.frames = {}
  end
  return cd
end
M._store = store

-- THE settings chokepoint. Upstream read the retail Edit Mode stored-value table here and converted
-- through the settings codec; we read our own table and store display values directly.
local function getOpt(frameID, key)
  local cd = store(false)
  local frame = cd and cd.frames and cd.frames[frameID]
  if frame and frame[key] ~= nil then return frame[key] end

  local overrides = PER_FRAME_DEFAULT_OVERRIDES[frameID]
  if overrides and overrides[key] ~= nil then return overrides[key] end
  return M.DEFAULTS[key]
end
M.GetOpt = getOpt

-- Write one setting and re-apply it live.
function M.SetOpt(frameID, key, value)
  local cd = store(true)
  if not cd then return end
  cd.frames[frameID] = cd.frames[frameID] or {}
  cd.frames[frameID][key] = value
  local viewer = M.GetViewerByFrameID and M.GetViewerByFrameID(frameID)
  if viewer and viewer.RefreshLayout then viewer:RefreshLayout() end
end

-- Restore one frame's settings to defaults.
function M.ResetOpts(frameID)
  local cd = store(true)
  if not cd then return end
  cd.frames[frameID] = nil
  local viewer = M.GetViewerByFrameID and M.GetViewerByFrameID(frameID)
  if viewer and viewer.RefreshLayout then viewer:RefreshLayout() end
end

function M.GetEssentialOpt(key) return getOpt(M.FRAME_ID.essential, key) end
function M.GetUtilityOpt(key)   return getOpt(M.FRAME_ID.utility,   key) end
function M.GetBuffIconOpt(key)  return getOpt(M.FRAME_ID.buffIcon,  key) end
function M.GetBuffBarOpt(key)   return getOpt(M.FRAME_ID.buffBar,   key) end

-- ── Enable toggles ──────────────────────────────────────────────────────────────────────────────
function M.IsEnabled()
  local cd = store(false)
  if cd and cd.enabled ~= nil then return cd.enabled end
  return true
end

function M.SetEnabled(v)
  local cd = store(true)
  if cd then cd.enabled = v and true or false end
  M.ForEachViewer(function(viewer) viewer:UpdateVisibility() end)
end

-- Per-category enable. Retail's HUDLayout preset has all four viewers on.
local CATEGORY_DEFAULT_ENABLED = {
  essential = true, utility = true, buffIcon = true, buffBar = true,
}

function M.IsCategoryEnabled(category)
  local cd = store(false)
  if cd and cd.categories then
    local v = cd.categories[category]
    if v ~= nil then return v end
  end
  local d = CATEGORY_DEFAULT_ENABLED[category]
  if d == nil then return true end
  return d
end

function M.SetCategoryEnabled(category, v)
  local cd = store(true)
  if cd then
    cd.categories = cd.categories or {}
    cd.categories[category] = v and true or false
  end
  local viewer = M.viewers and M.viewers[category]
  if viewer then viewer:UpdateVisibility() end
end

-- ── Viewer registry ─────────────────────────────────────────────────────────────────────────────
-- Upstream addressed viewers through XML-created globals (NE_EssentialCooldownViewer, ...). We
-- build frames in Lua (Viewers.lua), so they register here instead.
M.viewers = M.viewers or {}

function M.RegisterViewer(category, frame)
  M.viewers[category] = frame
end

function M.GetViewerByFrameID(frameID)
  for category, frame in pairs(M.viewers) do
    if M.FRAME_ID[category] == frameID then return frame end
  end
  return nil
end

function M.ForEachViewer(fn)
  for _, frame in pairs(M.viewers) do
    if frame then fn(frame) end
  end
end

-- ── Item helpers ────────────────────────────────────────────────────────────────────────────────

-- On-use item cooldown by itemID. C_Container.GetItemCooldown takes an itemID despite the
-- namespace; the global GetItemCooldown is the 3.3.5a original.
function M.ItemCooldown(itemID)
  if itemID and C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(itemID) end
  if itemID and GetItemCooldown then return GetItemCooldown(itemID) end
  return 0, 0, 0
end

-- Resolve an item's inventory icon. Returns nil until the server caches the item; the viewer's
-- GET_ITEM_INFO_RECEIVED handler re-resolves when it lands.
function M.ResolveItemIcon(itemID)
  if not itemID then return nil end
  local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID))
    or (GetItemIcon and GetItemIcon(itemID))
  if not icon and C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(itemID)
  end
  return icon
end

function M.GetItemUseSpell(item)
  if not item then return nil end
  if C_Item and C_Item.GetItemSpell then return C_Item.GetItemSpell(item) end
  if GetItemSpell then return GetItemSpell(item) end
  return nil
end

-- On-use item entries live in the custom lists keyed by their USE-SPELL id, carrying itemID +
-- track ("item" = GetItemCooldown / "spell" = GetSpellCooldown on the use-spell).
--
-- MUST use GetCustomList, never GetEditableList. This is a read-only QUERY, and it runs from
-- ItemMixins:SetSpell for every icon on every rebuild. GetEditableList SEEDS AND PERSISTS the
-- custom list from the curated defaults as a side effect, so calling it here silently froze the
-- then-current spell list into SavedVariables the very first time a viewer built. After that
-- GetActiveSpellList took the `custom` branch forever and ignored the curated tables — which is
-- why every ability added by CdmSeedWotLK.lua stayed invisible on a character that had run an
-- earlier build. A query must not pin persistent state.
function M.GetItemMeta(spellID, class)
  if not class then local _; _, class = UnitClass("player") end
  if not (spellID and class) then return nil end
  for _, key in ipairs({ "essential", "utility" }) do
    local list = M.GetCustomList(key, class)
    if list then
      for _, e in ipairs(list) do
        if e.itemID and e.spellID == spellID then return e.itemID, e.track or "spell" end
      end
    end
  end
  return nil
end

-- Equipped-trinket auto-discovery and the per-token assignment registry live in Equip.lua, which
-- loads after this file and defines M.GetEquipActiveItems / M.GetEquipAssignment /
-- M.GetEquipItemsForCategory. This stub is the fallback for the case Equip.lua is absent (a partial
-- install, or the offline harness loading a subset): an empty list makes the Rebuild branch that
-- consumes it a clean no-op rather than an error.
function M.GetEquipItemsForCategory(_)
  return {}
end

-- ── Spell list resolution ───────────────────────────────────────────────────────────────────────

-- Per-character custom list, per category:
--   store().customLists[<category>][<CLASS>] = { { spellID=, enabled= }, ... }
-- nil means "use the curated default for this class".
local function getCustomTable(category)
  local cd = store(true)
  if not (cd and category) then return nil end
  cd.customLists = cd.customLists or {}
  cd.customLists[category] = cd.customLists[category] or {}
  return cd.customLists[category]
end

function M.GetCustomList(category, class)
  if not class then local _; _, class = UnitClass("player") end
  local t = getCustomTable(category)
  return t and t[class] or nil
end

function M.SetCustomList(category, class, list)
  if not class then local _; _, class = UnitClass("player") end
  local t = getCustomTable(category)
  if not t then return end
  t[class] = list
end

function M.ResetCustomList(category, class)
  if not class then local _; _, class = UnitClass("player") end
  local t = getCustomTable(category)
  if not t then return end
  t[class] = nil
end

-- One-time migration: drop custom lists that were never deliberately created.
--
-- Until the spell picker lands (Phase 4) there is NO user-facing way to author a custom list, so
-- any list already in SavedVariables is an artifact of the GetItemMeta side effect described above
-- — a frozen snapshot of whatever the curated defaults happened to be at the time, which then
-- masks every later addition (the entire WotLK seed, for a character that had run an earlier
-- build). Clearing them restores the curated path and loses nothing the user chose.
--
-- Versioned so it runs exactly once and can never wipe a genuinely authored list later. Upstream
-- carries the same guarded one-time reset for the same reason ("hiding the new defaults").
local CUSTOM_LIST_RESET_VERSION = "customListsV2"

function M.MigrateStaleCustomLists()
  local cd = store(true)
  if not cd then return false end
  if cd[CUSTOM_LIST_RESET_VERSION] then return false end
  cd[CUSTOM_LIST_RESET_VERSION] = true
  local had = cd.customLists and next(cd.customLists) ~= nil
  cd.customLists = {}
  M.InvalidateCuratedCache()
  if had and NE.Log then
    NE.Log("CDM", "cleared stale auto-seeded spell lists; curated defaults restored")
  end
  return had
end

function M.GetEditableList(category, class)
  if not class then local _; _, class = UnitClass("player") end
  local t = getCustomTable(category)
  if not (t and class) then return nil end
  if not t[class] then
    local source = M.SPELL_DATA_BY_CATEGORY and M.SPELL_DATA_BY_CATEGORY[category]
    local default = source and source[class] or {}
    local seeded = {}
    for _, spellID in ipairs(default) do
      table.insert(seeded, { spellID = spellID, enabled = true })
    end
    t[class] = seeded
  end
  return t[class]
end

-- Show or hide one spell in a category, as a DELIBERATE user action.
--
-- This is the only caller of GetEditableList, and that is the whole point: seeding a custom list is
-- a side effect with teeth (PORT_PLAN §E5 — a read-only query doing it froze the curated defaults
-- into SavedVariables and hid every later addition). Seeding is correct HERE, because the user has
-- just expressed an explicit preference about this list, so a list is what should exist afterwards.
--
-- Returns true if anything changed.
function M.SetSpellEnabled(category, spellID, enabled)
  if not (category and spellID) then return false end
  local _, class = UnitClass("player")
  local list = M.GetEditableList(category, class)
  if not list then return false end

  enabled = enabled and true or false
  for _, entry in ipairs(list) do
    if entry.spellID == spellID then
      if entry.enabled == enabled then return false end
      entry.enabled = enabled
      M.RefreshActiveViewer(category)
      return true
    end
  end

  -- Not in the seeded list: a racial, or a spell added after the list was authored. Append it so
  -- the preference sticks rather than being silently dropped.
  list[#list + 1] = { spellID = spellID, enabled = enabled }
  M.RefreshActiveViewer(category)
  return true
end

-- Should the settings panel list curated spells the player has not learned?
--
-- Off by default: Essential/Utility show what you can actually cast. The Hidden catalog ignores this
-- and always lists everything, because a low-level character seeing an empty picker reads as broken.
function M.GetShowUnlearned()
  local cd = store(false)
  return (cd and cd.showUnlearned) and true or false
end

function M.SetShowUnlearned(v)
  local cd = store(true)
  if cd then cd.showUnlearned = v and true or false end
  M.RefreshActiveViewer()
end

-- Light the tile's frame gold while the spell's own buff is on the player (§H.2 8c, the substitute
-- for retail's gold swipe). ON by default: it is a retail feature, not an addition of ours.
function M.IsBuffGlowEnabled()
  local cd = store(false)
  if cd and cd.buffGlow ~= nil then return cd.buffGlow and true or false end
  return true
end

function M.SetBuffGlowEnabled(v)
  local cd = store(true)
  if cd then cd.buffGlow = v and true or false end
  -- Turning it OFF has to reach tiles that are glowing right now, and RefreshCooldown only revisits
  -- the glow when something about the spell changes — which for a buff already up may be a minute away.
  M.RefreshActiveViewer()
end

-- Is this spell currently enabled in the category? Reads the custom list WITHOUT seeding one.
function M.IsSpellEnabled(category, spellID)
  if not (category and spellID) then return true end
  local _, class = UnitClass("player")
  local list = M.GetCustomList(category, class)
  if not list then return true end   -- no custom list: the curated default is shown
  for _, entry in ipairs(list) do
    if entry.spellID == spellID then return entry.enabled and true or false end
  end
  return true
end

-- Merge per-race racials into a category's list. UnitRace's 2nd return is the canonical key
-- ("Human", "Scourge", ...). Deduped, and never overrides a deliberate user disable.
local function appendRacials(out, category, exclude)
  local _, raceFile = UnitRace("player")
  if not raceFile then return end
  local bucket = M.RACIAL_BY_RACE and M.RACIAL_BY_RACE[raceFile]
  local list = bucket and bucket[category]
  if not list then return end
  local seen = {}
  for _, id in ipairs(out) do seen[id] = true end
  for _, spellID in ipairs(list) do
    if not seen[spellID] and not (exclude and exclude[spellID]) then
      out[#out + 1] = spellID
      seen[spellID] = true
    end
  end
end

-- Learn-gate. The curated per-class set is what we gate; a spellID NOT in it is a user-added
-- item/external (its use-spell is never "known"), so it is always trackable. Memoised per class.
local curatedSetCache = {}
local function curatedSet(class)
  if curatedSetCache[class] then return curatedSetCache[class] end
  local set = {}
  if M.SPELL_DATA_BY_CATEGORY then
    for _, byClass in pairs(M.SPELL_DATA_BY_CATEGORY) do
      local list = byClass[class]
      if list then for _, id in ipairs(list) do set[id] = true end end
    end
  end
  if M.RACIAL_BY_RACE then
    for _, bucket in pairs(M.RACIAL_BY_RACE) do
      for _, catName in ipairs({ "essential", "utility", "buffIcon", "buffBar" }) do
        local l = bucket[catName]
        if l then for _, id in ipairs(l) do set[id] = true end end
      end
    end
  end
  curatedSetCache[class] = set
  return set
end

-- Invalidated when the curated tables are appended to (the Phase 2 WotLK seed does exactly that).
function M.InvalidateCuratedCache()
  curatedSetCache = {}
end

-- Does the player know this ability, at ANY rank?
--
-- DOWNPORT / BUGFIX: the source tries IsSpellKnown(spellID) first, then GetSpellInfo(name). Both
-- are unreliable here, and between them they hid every talent-granted and higher-rank ability:
--
--   * IsSpellKnown(id) tests ONE EXACT RANK. Our curated lists key each ability by its rank-1 id,
--     so the moment the player trains rank 2 the check reports false — Penance (47540) on a Disc
--     priest who has trained past rank 1, for instance.
--   * GetSpellInfo(name) is a spell-database lookup on this client, not a reliable membership test.
--
-- Neither is level-aware either, which matters on a level-squished server where a character can
-- legitimately know an ability far below its stock level (Divine Hymn at 60).
--
-- So we ask the SPELLBOOK, by name (core/SpellRanks.lua). That is authoritative, rank-agnostic and
-- level-agnostic: if it is in the book, the player has it. The old checks stay as fallbacks in case
-- the book scan is unavailable, so this can only ever widen what shows, never narrow it.
local function isLearned(spellID)
  local name = GetSpellInfo(spellID)
  local SB = NE.spellbook
  if name and SB and SB.IsSpellNameKnown and SB.IsSpellNameKnown(name) then return true end
  if IsSpellKnown and IsSpellKnown(spellID) then return true end
  return (name and GetSpellInfo(name)) and true or false
end

-- Race gate. Upstream reads the generated NE_SPELL_RACEMASK table (SkillLineAbility RaceMask) to
-- hide never-learnable-by-race spells. We do not ship that data, and the upstream design already
-- FAILS OPEN on a missing mask — so this is currently a permissive pass-through. Kept as the seam.
function M.SpellAllowedForRace(spellID)
  local mask = spellID and _G.NE_SPELL_RACEMASK and _G.NE_SPELL_RACEMASK[spellID]
  if not mask then return true end
  return true
end

function M.IsTrackable(spellID, class)
  if not class then local _; _, class = UnitClass("player") end
  if not (spellID and class) then return true end
  if not curatedSet(class)[spellID] then return true end
  return isLearned(spellID)
end

function M.IsCuratedSpell(spellID, class)
  if not class then local _; _, class = UnitClass("player") end
  return (spellID and class and curatedSet(class)[spellID]) and true or false
end

-- The live spell list for a category. `includeUnlearned` skips the learn-gate (used by the
-- options-tab preview so an untrained character still sees the full curated set).
function M.GetActiveSpellList(category, includeUnlearned)
  local _, class = UnitClass("player")
  if not class then return {} end

  local raw = {}
  local present   -- spellIDs the user explicitly listed (enabled OR disabled)
  local custom = M.GetCustomList(category, class)
  if custom then
    present = {}
    for _, entry in ipairs(custom) do
      present[entry.spellID] = true
      if entry.enabled then raw[#raw + 1] = entry.spellID end
    end
  else
    local source = M.SPELL_DATA_BY_CATEGORY and M.SPELL_DATA_BY_CATEGORY[category]
    local classList = (source and source[class]) or {}
    for _, spellID in ipairs(classList) do raw[#raw + 1] = spellID end
  end

  -- Racials are class-agnostic and were never in the editable seed, so append in BOTH paths
  -- (deduped) — otherwise the moment a custom list is seeded, every racial silently vanishes.
  -- `present` keeps an explicit user disable authoritative.
  appendRacials(raw, category, present)

  local allowed = {}
  for _, id in ipairs(raw) do
    if M.SpellAllowedForRace(id) then allowed[#allowed + 1] = id end
  end
  if includeUnlearned then return allowed end

  local out = {}
  for _, id in ipairs(allowed) do
    if M.IsTrackable(id, class) then out[#out + 1] = id end
  end
  return out
end

-- ── Tracked auras (BuffIcon / BuffBar) ──────────────────────────────────────────────────────────
--
-- Retail's TrackedBuff/TrackedBar read a Blizzard-curated per-spec aura set from C_CooldownViewer.
-- With no such data, upstream drives both buff viewers from an AUTO-TRACK window — any live player
-- buff with 0 < duration <= BUFF_TRACK_MAX_DURATION — plus a manual override pool. That is what
-- ports; the curated BUFFICON_BY_CLASS / BUFFBAR_BY_CLASS tables in ClassData.lua are unused here
-- (they were full of duration-0 permanent toggles, which is the wrong thing for these viewers).
--
-- ONE pool, like retail: each aura is in exactly one state — "icon" (TrackedBuff), "bar"
-- (TrackedBar) or "hidden" (force-excluded from both).
--   store().trackedAura[<CLASS>] = { { spellID = 10060, assignment = "icon" }, ... }
-- It starts EMPTY by design: the auto window provides the defaults, this is the override registry.

local BUFF_TRACK_MAX_DURATION = 120

local VALID_ASSIGNMENT = { icon = true, bar = true, hidden = true }

local function getTrackedAuraTable()
  local cd = store(true)
  if not cd then return nil end
  cd.trackedAura = cd.trackedAura or {}
  return cd.trackedAura
end

function M.GetTrackedAuraList(class)
  if not class then local _; _, class = UnitClass("player") end
  local t = getTrackedAuraTable()
  if not (t and class) then return nil end
  t[class] = t[class] or {}
  return t[class]
end

-- `name` is stored alongside the id because matching is by name (see GetBuffOverrides): a catalog
-- row is rank 1, the aura the player actually gets may be any rank, and GetSpellInfo cannot always
-- resolve an id this client only knows as an aura.
-- The best name available for an aura id, in falling order of certainty: the client, what the scan
-- recorded, the catalog. Resolved HERE rather than threaded through the picker's drag and menu
-- paths, so every writer stores a name whether or not its caller happened to know one.
function M.ResolveAuraName(spellID)
  if not spellID then return nil end
  local nm = GetSpellInfo(spellID)
  if nm then return nm end
  local _, class = UnitClass("player")
  if not class then return nil end
  local cd = store(false)
  local bag = cd and cd.seenAura and cd.seenAura[class]
  if bag and bag[spellID] and bag[spellID].name then return bag[spellID].name end
  for _, c in ipairs((M.AURA_CATALOG_BY_CLASS or {})[class] or {}) do
    if c.id == spellID then return c.name end
  end
  return nil
end

function M.SetAuraAssignment(class, spellID, assignment, name)
  if not VALID_ASSIGNMENT[assignment] then return end
  local list = M.GetTrackedAuraList(class)
  if not (list and spellID) then return end
  name = name or M.ResolveAuraName(spellID)
  for _, e in ipairs(list) do
    if e.spellID == spellID then
      e.assignment = assignment
      if name and not e.name then e.name = name end   -- late-arriving name, never overwritten
      M.RefreshActiveViewer(); return
    end
  end
  list[#list + 1] = { spellID = spellID, assignment = assignment, name = name }
  M.RefreshActiveViewer()
end

function M.RemoveTrackedAura(class, spellID)
  local list = M.GetTrackedAuraList(class)
  if not list then return end
  for i = #list, 1, -1 do
    if list[i].spellID == spellID then table.remove(list, i) end
  end
  M.RefreshActiveViewer()
end

function M.ResetTrackedAura(class)
  if not class then local _; _, class = UnitClass("player") end
  local t = getTrackedAuraTable()
  if t and class then t[class] = {} end
  M.RefreshActiveViewer()
end

-- ── What the picker can OFFER (Phase 7) ─────────────────────────────────────────────────────────
--
-- The pool above is an OVERRIDE registry, and its only writer is the picker. On its own that makes
-- the Tracked Buffs / Tracked Bars tab a store whose sole editor is a view of itself: nothing can
-- ever enter it, so the tab is empty on every character forever, and ScanTargetTrackedAuras — whose
-- input is that registry — never has anything to look for either. Two sources fix that:
--
--   * the CATALOG (CdmAuraCatalog.lua, generated): what you CAN have. This is retail's shape, where
--     the Buffs menu lists a Blizzard-curated per-spec aura set. Spec-gating is per TALENT rather
--     than per spec, which on this client is strictly better — it follows respecs and dual spec.
--   * the SEEN registry: what you HAVE had. The catalog cannot cover racials, trinket and set
--     procs, or anything this client grants outside a class skill line, so the live scan records
--     what it meets. This is the safety net that lets the catalog be imperfect.

local SEEN_CAP    = 60    -- per class
local SEEN_RENOTE = 5     -- seconds; a re-note inside this window is skipped

local function getSeenAuraTable()
  local cd = store(true)
  if not cd then return nil end
  cd.seenAura = cd.seenAura or {}
  return cd.seenAura
end

-- Called from the aura scan for every player buff it walks, BEFORE the include/exclude decision.
-- The ordering is load-bearing: recorded after, an aura the player hides would drop out of the
-- registry, its row would vanish from Hidden, and there would be nothing left to unhide it with.
-- Returns true only when a NEW aura was added.
function M.NoteSeenAura(spellID, name, icon, duration)
  if not (spellID and name) then return false end
  -- Exactly the window the viewers use, so the tab describes what the bars are doing rather than
  -- some wider idea of it. Also what keeps food buffs, flasks and permanent toggles out.
  if not (duration and duration > 0 and duration <= BUFF_TRACK_MAX_DURATION) then return false end
  local _, class = UnitClass("player")
  local t = class and getSeenAuraTable()
  if not t then return false end
  t[class] = t[class] or {}
  local bag = t[class]
  local now = (GetTime and GetTime()) or 0

  local e = bag[spellID]
  if e then
    if (now - (e.last or 0)) < SEEN_RENOTE then return false end
    e.name, e.icon, e.dur, e.last = name, icon, duration, now
    return false
  end

  -- Capped, evicting the least recently seen. Unbounded this follows the character forever and is
  -- copied into every layout snapshot (§G.11), so a raid night of procs would bloat both.
  local n, oldest, oldestAt = 0, nil, nil
  for k, v in pairs(bag) do
    n = n + 1
    local last = v.last or 0
    if not oldestAt or last < oldestAt then oldest, oldestAt = k, last end
  end
  if n >= SEEN_CAP and oldest then bag[oldest] = nil end

  bag[spellID] = { name = name, icon = icon, dur = duration, last = now }
  return true
end

function M.GetSeenAuraList(class)
  if not class then local _; _, class = UnitClass("player") end
  local t = store(false)
  local bag = t and t.seenAura and class and t.seenAura[class]
  local out = {}
  if not bag then return out end
  for spellID, e in pairs(bag) do
    out[#out + 1] = { spellID = spellID, name = e.name, icon = e.icon, dur = e.dur, last = e.last }
  end
  -- Duration descending, matching the catalog's order and the bars', so the grid reads the same way
  -- however a row got there.
  table.sort(out, function(a, b)
    if (a.dur or 0) ~= (b.dur or 0) then return (a.dur or 0) > (b.dur or 0) end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

function M.ResetSeenAura(class)
  if not class then local _; _, class = UnitClass("player") end
  local t = getSeenAuraTable()
  if t and class then t[class] = {} end
end

-- ── The talent gate ─────────────────────────────────────────────────────────────────────────────
-- A catalog row carrying `talent` is only offered when the player has that talent. Cached with a
-- short TTL rather than event-invalidated: the only caller is the picker, so this is never in the
-- aura hot path, and a TTL self-heals after a respec without needing to be told about one.
local TALENT_TTL = 2
local talentRanks, talentStamp

local function talentTable()
  local now = (GetTime and GetTime()) or 0
  if talentRanks and (now - (talentStamp or 0)) < TALENT_TTL then return talentRanks end
  local t, n = {}, 0
  if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
    for tab = 1, (GetNumTalentTabs() or 0) do
      for i = 1, (GetNumTalents(tab) or 0) do
        -- 3.3.5a flat 10-tuple; rank is the 5th return (see modules/talents/Behavior.lua).
        local name, _, _, _, rank = GetTalentInfo(tab, i)
        if name then t[name:lower()] = rank or 0; n = n + 1 end
      end
    end
  end
  t._count = n
  talentRanks, talentStamp = t, now
  return t
end

-- Fails OPEN. No talent rows at all means the API has not answered yet — early login, or a build
-- without the talent globals — NOT that the player has spent nothing. Hiding every spec-gated row
-- on that reading would reproduce the exact bug this phase exists to fix.
function M.HasTalent(name)
  if not name then return true end
  local t = talentTable()
  if t._count == 0 then return true end
  return (t[name:lower()] or 0) > 0
end

function M.InvalidateTalentCache() talentRanks, talentStamp = nil, nil end

-- The catalog for a class, spec-filtered. `includeUntalented` is the picker's Show Unlearned
-- escape hatch: the gate is derived data and can be wrong, so there is a way to see past it.
function M.GetAuraCatalog(class, includeUntalented)
  if not class then local _; _, class = UnitClass("player") end
  local all = class and (M.AURA_CATALOG_BY_CLASS or {})[class]
  if not all then return {} end
  local out = {}
  for _, e in ipairs(all) do
    if (not e.talent) or includeUntalented or M.HasTalent(e.talent) then out[#out + 1] = e end
  end
  return out
end

-- Catalog ∪ seen, minus anything the player has already assigned by hand — the rows the picker can
-- offer as AUTO. Deduped by lowercased name, not by id: the same buff arrives from the catalog at
-- rank 1 and from the scan at whatever rank was cast, and those are two ids for one buff.
function M.GetAuraCandidates(class, includeUntalented)
  if not class then local _; _, class = UnitClass("player") end
  local out, byName, explicit = {}, {}, {}

  for _, e in ipairs(M.GetTrackedAuraList(class) or {}) do
    if e.spellID then explicit[e.spellID] = true end
    local nm = e.name or (e.spellID and GetSpellInfo(e.spellID))
    if nm then explicit[nm:lower()] = true end
  end

  local function add(entry)
    local key = entry.name and entry.name:lower()
    if not key then return end
    if byName[key] or explicit[key] or (entry.spellID and explicit[entry.spellID]) then return end
    byName[key] = true
    out[#out + 1] = entry
  end

  for _, c in ipairs(M.GetAuraCatalog(class, includeUntalented)) do
    local nm, _, icon = GetSpellInfo(c.id)
    add({ spellID = c.id, name = c.name or nm, icon = icon, dur = c.dur,
          talent = c.talent, tree = c.tree, catalog = true,
          -- Only ever true when Show Unlearned opened the gate; the tile tints on it.
          untalented = (c.talent and not M.HasTalent(c.talent)) or nil })
  end
  for _, s in ipairs(M.GetSeenAuraList(class)) do
    add({ spellID = s.spellID, name = s.name, icon = s.icon, dur = s.dur, seen = true })
  end
  return out
end

-- Auras never to auto-track, by spellID. Starts empty; populate as real noise turns up.
M.BUFFBAR_EXCLUDE = M.BUFFBAR_EXCLUDE or {}

-- Derive the include/exclude sets for one buff viewer from the single pool. An aura assigned to
-- THIS viewer is a force-include; assigned to the other viewer, or hidden, is a force-exclude — so
-- a bar-assigned aura never also shows as an icon.
--
-- Each set is keyed BY BOTH id and lowercased name, in the one table — spellIDs are numbers and
-- names are strings, so they cannot collide. The name key is what makes an assignment survive rank:
-- the player assigns Renew from a catalog row holding rank 1, then casts rank 14, and an id-only
-- lookup would quietly not match. ScanTargetTrackedAuras already had to match DoTs by name for the
-- same reason; this makes that the rule rather than the exception.
function M.GetBuffOverrides(category)
  local include, exclude = {}, {}
  local _, class = UnitClass("player")
  local tracked = class and M.GetTrackedAuraList(class)
  if tracked then
    for _, e in ipairs(tracked) do
      if e.spellID then
        local here = (category == "buffIcon" and e.assignment == "icon")
                  or (category == "buffBar"  and e.assignment == "bar")
        local set = here and include or exclude
        set[e.spellID] = true
        local nm = e.name or GetSpellInfo(e.spellID)
        if nm then set[nm:lower()] = true end
      end
    end
  end
  return include, exclude
end

-- Auto-track toggle. ON by default; when OFF only explicit assignments track.
function M.IsAutoTrackBuffs()
  local cd = store(false)
  if cd and cd.autoTrackBuffs ~= nil then return cd.autoTrackBuffs end
  return true
end

function M.SetAutoTrackBuffs(v)
  local cd = store(true)
  if cd then cd.autoTrackBuffs = v and true or false end
  M.RefreshActiveViewer("buffIcon")
  M.RefreshActiveViewer("buffBar")
end

-- Where auto-tracked short buffs render: "icon" | "bar" | "both".
function M.AutoTrackDest()
  local cd = store(false)
  if cd and cd.autoTrackDest then return cd.autoTrackDest end
  return "both"
end

function M.SetAutoTrackDest(v)
  local cd = store(true)
  if cd then cd.autoTrackDest = v end
  M.RefreshActiveViewer("buffIcon")
  M.RefreshActiveViewer("buffBar")
end

M.BUFF_TRACK_MAX_DURATION = BUFF_TRACK_MAX_DURATION

-- The per-aura decision. Explicit assignments win; otherwise the auto window applies, honouring
-- the icon/bar/both destination. `name` is optional and trailing so existing callers still work,
-- but passing it is what makes an assignment rank-proof — see GetBuffOverrides.
function M.ShouldTrackBuff(spellID, duration, include, exclude, category, name)
  local key = name and name:lower()
  if spellID and include[spellID] then return true end
  if key and include[key] then return true end
  if spellID and (exclude[spellID] or M.BUFFBAR_EXCLUDE[spellID]) then return false end
  if key and exclude[key] then return false end
  if not M.IsAutoTrackBuffs() then return false end
  if category then
    local dest = M.AutoTrackDest()
    if dest == "icon" and category ~= "buffIcon" then return false end
    if dest == "bar"  and category ~= "buffBar"  then return false end
  end
  return (duration and duration > 0 and duration <= BUFF_TRACK_MAX_DURATION) and true or false
end

-- Tracked auras on the TARGET (DoTs). Retail registers UNIT_AURA for player and target, so a
-- tracked debuff on the target shows in the buff viewers. This adds the target as a SECONDARY
-- source for EXPLICITLY tracked auras only — never the auto window, which would flood the viewer
-- with every enemy debuff. Matched by NAME so a down-ranked DoT still resolves.
function M.ScanTargetTrackedAuras(include, shownNames)
  local out = {}
  if not include then return out end
  if not (UnitExists and UnitExists("target")) then return out end

  -- `include` is keyed by id AND by lowercased name (GetBuffOverrides), so both key types resolve
  -- here: a string key IS the name, and is the only thing that works for an aura id this client
  -- cannot hand back to GetSpellInfo.
  local wantName = {}
  for key in pairs(include) do
    if type(key) == "string" then
      wantName[key] = true
    else
      local nm = GetSpellInfo(key)
      if nm then wantName[nm:lower()] = true end
    end
  end
  if not next(wantName) then return out end

  -- DOWNPORT: the source iterates UnitDebuff/UnitBuff directly with MODERN return positions. On
  -- 3.3.5a every field after the first is shifted by one (`rank` at index 2). Going through
  -- NE.aura keeps that correction in exactly one place.
  local function scan(filter)
    local snap = NE.aura and NE.aura.GetSnapshot("target", filter)
    if not snap then return end
    for i = 1, snap.n do
      local row = snap.list[i]
      if row.name and wantName[row.name:lower()] and not (shownNames and shownNames[row.name]) then
        out[#out + 1] = {
          name = row.name, icon = row.icon, count = row.count,
          duration = row.duration, expiration = row.expiration, spellID = row.spellID,
        }
        if shownNames then shownNames[row.name] = true end
      end
    end
  end
  scan("HARMFUL")   -- DoTs are debuffs on the target (primary case)
  scan("HELPFUL")   -- (rare) a tracked buff the player placed on the target
  return out
end

function M.RefreshActiveViewer(category)
  if category == nil then
    M.ForEachViewer(function(v) if v:IsShown() then v:Rebuild() end end)
    return
  end
  local viewer = M.viewers[category]
  if viewer and viewer:IsShown() then viewer:Rebuild() end
end

-- Reset the per-character tracking data (rank-specific list overrides). Storing a SPECIFIC rank is
-- pointless — every rank shares one cooldown and the viewer resolves the displayed rank live — and
-- a stale snapshot also masks newly-curated defaults. Positions/scale live in DragonUI's mover
-- store, NOT here, so this never touches layout.
function M.ResetTracking()
  local cd = store(true)
  if not cd then return end
  cd.customLists = {}
  cd.trackedAura = {}
  -- Observed history goes too. It is not a choice the player made, but leaving it would mean "reset
  -- tracking" left rows behind that the player could not account for — and the catalog keeps the
  -- picker populated either way, so nothing is lost but the record of one character's procs.
  cd.seenAura = {}
  -- Trinket placement is a tracking choice like any other, so "reset tracking" returns every
  -- discovered item to the unassigned source pool.
  cd.equipAssign = {}
  M.InvalidateCuratedCache()
  M.ForEachViewer(function(v) if v.Rebuild and v:IsShown() then v:Rebuild() end end)
end
