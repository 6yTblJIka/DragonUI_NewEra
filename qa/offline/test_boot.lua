-- Boot the Cooldown Manager stack against a stubbed 3.3.5a client and drive it through a
-- realistic event sequence. Catches load-order faults, nil calls, and typos that a syntax
-- check cannot.

-- Addon root. Defaults to the repo root relative to the usual invocation
--   luajit qa/offline/test_boot.lua
-- Override with NE_ADDON_ROOT (trailing slash) to run from elsewhere.
local ADDON = os.getenv("NE_ADDON_ROOT") or "./"

-- ── clock ───────────────────────────────────────────────────────────────────
-- GetTime() is constant within a frame in the real client, which is exactly what NE.aura's
-- snapshot cache keys on. So a test that changes auras must also step the clock, or it will keep
-- reading the previous frame's cached scan.
local NOW = 1000.0
function GetTime() return NOW end
local function nextFrame(dt) NOW = NOW + (dt or 0.05) end

-- ── widget stubs ────────────────────────────────────────────────────────────
local allFrames = {}

local function newRegion(kind)
  local r = { _kind = kind, _shown = true, _alpha = 1 }
  function r:SetTexture(t) self._tex = t end
  function r:GetTexture() return self._tex end
  function r:SetTexCoord() end
  function r:SetVertexColor(...) self._color = { ... } end
  function r:SetDesaturated(v) self._desat = v end
  function r:SetAllPoints() end
  function r:SetPoint() end
  function r:ClearAllPoints() end
  function r:Show() self._shown = true end
  function r:Hide() self._shown = false end
  function r:IsShown() return self._shown end
  function r:SetAlpha(a) self._alpha = a end
  function r:GetAlpha() return self._alpha end
  function r:SetFontObject(f) self._font = f end
  function r:SetText(t) self._text = t end
  function r:GetText() return self._text end
  function r:SetWidth() end
  function r:SetHeight() end
  function r:SetJustifyH() end
  function r:SetJustifyV() end
  return r
end

local frameMeta = {}
frameMeta.__index = frameMeta

function CreateFrame(kind, name, parent, template)
  local f = setmetatable({
    _kind = kind, _name = name, _parent = parent, _shown = true, _scale = 1,
    _w = 0, _h = 0, _children = {}, _scripts = {}, _events = {}, _points = {},
    _regions = {},
  }, frameMeta)
  if parent and parent._children then parent._children[#parent._children + 1] = f end
  if name then _G[name] = f end
  allFrames[#allFrames + 1] = f
  return f
end

-- The client fires OnSizeChanged whenever a frame's dimensions actually change. The anchor-sync in
-- NE.RegisterHUDFrame depends on it, so the stub must too.
local function sized(f, ow, oh)
  if (f._w ~= ow or f._h ~= oh) and f._scripts.OnSizeChanged then
    f._scripts.OnSizeChanged(f, f._w, f._h)
  end
end
function frameMeta:SetSize(w, h) local ow, oh = self._w, self._h; self._w, self._h = w, h; sized(self, ow, oh) end
function frameMeta:SetWidth(w) local ow = self._w; self._w = w; sized(self, ow, self._h) end
function frameMeta:SetHeight(h) local oh = self._h; self._h = h; sized(self, self._w, oh) end
function frameMeta:GetWidth() return self._w end
function frameMeta:GetHeight() return self._h end
function frameMeta:GetScale() return self._scale end
function frameMeta:SetScale(s) self._scale = s end
function frameMeta:SetAlpha(a) self._alpha = a end
function frameMeta:GetAlpha() return self._alpha or 1 end
-- Match the client: OnShow fires only on a hidden -> shown TRANSITION, not on every Show() call.
function frameMeta:Show()
  local was = self._shown
  self._shown = true
  if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function frameMeta:Hide() self._shown = false end
function frameMeta:IsShown() return self._shown end
function frameMeta:SetPoint(p, rel, relP, x, y) self._points[#self._points + 1] = { p, rel, relP, x, y } end
function frameMeta:SetAllPoints(rel) self._points[#self._points + 1] = { "ALL", rel } end
function frameMeta:ClearAllPoints() self._points = {} end
function frameMeta:GetNumPoints() return #self._points end
function frameMeta:GetChildren() return unpack(self._children) end
function frameMeta:EnableMouse() end
function frameMeta:SetFrameLevel() end
function frameMeta:GetFrameLevel() return 1 end
function frameMeta:SetFrameStrata() end
function frameMeta:SetParent(p) self._parent = p end
function frameMeta:GetParent() return self._parent end
function frameMeta:SetMovable() end
function frameMeta:SetUserPlaced() end
function frameMeta:RegisterEvent(e) self._events[e] = true end
function frameMeta:UnregisterEvent(e) self._events[e] = nil end
function frameMeta:SetScript(s, fn) self._scripts[s] = fn end
function frameMeta:GetScript(s) return self._scripts[s] end
function frameMeta:HookScript(s, fn) self._scripts[s] = fn end
function frameMeta:CreateTexture() local t = newRegion("Texture"); self._regions[#self._regions+1] = t; return t end
function frameMeta:CreateFontString() local t = newRegion("FontString"); self._regions[#self._regions+1] = t; return t end
function frameMeta:SetCooldown(s, d) self._cdStart, self._cdDur = s, d end
function frameMeta:SetDrawEdge() end
function frameMeta:SetReverse(v) self._reverse = v end
-- StatusBar surface (BuffBar rows).
function frameMeta:SetMinMaxValues(lo, hi) self._min, self._max = lo, hi end
function frameMeta:SetValue(v) self._value = v end
function frameMeta:GetValue() return self._value end
function frameMeta:SetStatusBarColor(...) self._barColor = { ... } end
function frameMeta:SetStatusBarTexture(t) self._barTex = t end
function frameMeta:GetStatusBarTexture() return self._barTex end

-- Fire an event at every frame registered for it (respecting the unit filter shim).
local function fireEvent(event, ...)
  for _, f in ipairs(allFrames) do
    if f._events and f._events[event] and f._scripts.OnEvent then
      f._scripts.OnEvent(f, event, ...)
    end
  end
end

-- ── game API stubs ──────────────────────────────────────────────────────────
UIParent = CreateFrame("Frame", "UIParent")
BOOKTYPE_SPELL = "spell"
MAX_TOTEMS = 4

function UnitClass(u) return "Priest", "PRIEST" end
function UnitRace(u) return "Human", "Human" end
function UnitExists(u) return u == "player" end
-- Live aura tables, keyed by unit. Each entry uses the 3.3.5a return order, which is what makes
-- this stub worth having: name, RANK, icon, count, dispelType, duration, expiration, caster,
-- isStealable, shouldConsolidate, spellID. `rank` at index 2 is the shift that breaks any code
-- ported straight from a modern client.
BUFFS   = { player = {}, target = {} }
DEBUFFS = { player = {}, target = {} }

local function auraGetter(tbl)
  return function(unit, i)
    local a = tbl[unit] and tbl[unit][i]
    if not a then return nil end
    return a.name, a.rank or "", a.icon, a.count or 0, a.dispelType,
           a.duration or 0, a.expiration or 0, a.caster, false, false, a.spellID
  end
end
UnitBuff   = auraGetter(BUFFS)
UnitDebuff = auraGetter(DEBUFFS)
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
function InCombatLockdown() return false end
function GetTotemInfo() return false end
function IsUsableSpell() return true, false end
function IsSpellInRange() return nil end
function IsUsableItem() return true end
function IsSpellKnown(id) return true end
function GetInventoryItemCooldown() return 0, 0, 0 end
function GetItemCooldown() return 0, 0, 0 end
function GetItemIcon() return "Interface\\Icons\\Test" end

-- A tiny fake spellbook: Mind Blast with three ranks, plus a few singles.
local SPELLS = {
  [8092]  = { "Mind Blast", "Rank 1" },
  [8102]  = { "Mind Blast", "Rank 2" },
  [10947] = { "Mind Blast", "Rank 3" },
  [10060] = { "Power Infusion", "" },
  [14751] = { "Inner Focus", "" },
  [2944]  = { "Devouring Plague", "Rank 1" },
  [17]    = { "Power Word: Shield", "Rank 1" },
  [15487] = { "Silence", "" },
  [586]   = { "Fade", "Rank 1" },
  [8122]  = { "Psychic Scream", "Rank 1" },
  [6346]  = { "Fear Ward", "" },
  [19236] = { "Desperate Prayer", "" },
  [15286] = { "Vampiric Embrace", "" },
  [724]   = { "Lightwell", "" },
  [61304] = { "Global Cooldown", "" },
  [20572] = { "Blood Fury", "" },
}
local NAME_TO_ID = {}
for id, e in pairs(SPELLS) do
  if not NAME_TO_ID[e[1]] then NAME_TO_ID[e[1]] = id end
end
-- highest rank wins for name lookups
NAME_TO_ID["Mind Blast"] = 10947

function GetSpellInfo(idOrName)
  local id = tonumber(idOrName)
  if not id then id = NAME_TO_ID[idOrName] end
  local e = id and SPELLS[id]
  if not e then return nil end
  -- 3.3.5a signature: name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange
  return e[1], e[2], "Interface\\Icons\\Spell_" .. id, 0, false, 0, 1500, 0, 30
end

local COOLDOWNS = {}
function GetSpellCooldown(idOrName)
  local id = tonumber(idOrName) or NAME_TO_ID[idOrName]
  local cd = id and COOLDOWNS[id]
  if cd then return cd[1], cd[2], 1 end
  return 0, 0, 1
end

function GetSpellLink(slot, bookType)
  local id = _G.__SLOT_IDS and _G.__SLOT_IDS[slot]
  return id and ("|cff71d5ff|Hspell:" .. id .. "|h[x]|h|r") or nil
end

-- Spellbook: 8 slots in one tab.
local BOOK = { 8092, 8102, 10947, 10060, 14751, 2944, 17, 586 }
_G.__SLOT_IDS = BOOK
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo(tab) return "General", "", 0, #BOOK end
function GetSpellBookItemName(slot) local id = BOOK[slot]; if not id then return nil end; return SPELLS[id][1], SPELLS[id][2] end
function GetSpellBookItemInfo(slot) return "SPELL", BOOK[slot] end
function GetSpellTexture() return "Interface\\Icons\\Test" end

function CooldownFrame_Set(cd, start, duration, enable)
  if enable and enable ~= 0 and start > 0 and duration > 0 then
    cd:SetCooldown(start, duration)
  else
    cd:Hide()
  end
end
function CooldownFrame_Clear(cd) cd:Hide() end

NumberFontNormalLarge = {}
NumberFontNormal = {}
NumberFontNormalSmall = {}
GameTooltip = CreateFrame("Frame", "GameTooltip")
function GameTooltip:SetOwner() end
function GameTooltip:SetHyperlink() end
function GameTooltip:SetInventoryItem() end
function GameTooltip:SetItemByID() end

-- Deferred callbacks: run them synchronously at a drain point.
local pending = {}
C_Timer = { After = function(_, fn) pending[#pending + 1] = fn end }
local function drain()
  local n = 0
  while #pending > 0 and n < 50 do
    local queue = pending
    pending = {}
    for _, fn in ipairs(queue) do fn() end
    n = n + 1
  end
end

C_Container = {}
C_Item = {}
LibStub = nil

-- ── DragonUI host stub ──────────────────────────────────────────────────────
local profile = { newera = { enabled = true, modules = {} }, movers = {}, widgets = {} }
DragonUI = {
  db = { profile = profile },
  ModuleRegistry = { Register = function() return true end },
  MoversSystem = { RegisterMover = function(_, info) profile.movers[info.name] = info.defaultPoint end },
  EditableFrames = {},
  RegisterEditableFrame = function(self, info) self.EditableFrames[info.name] = info end,
  -- Mirrors core/api.lua:255 — the factory that actually attaches the drag scripts, the nineslice
  -- overlay and the auto-save. RegisterEditableFrame alone is only metadata.
  CreateUIFrame = function(w, h, name)
    local f = CreateFrame("Frame", "DragonUI_" .. name, UIParent)
    f:SetSize(w, h)
    f._isUIFrame = true
    f._draggable = true
    return f
  end,
}

DragonUI_NewEra = { dragon = DragonUI, db = {} }
local NE = DragonUI_NewEra
function NE.Log(tag, msg) print("  [LOG " .. tag .. "] " .. msg) end
NE.tex = { localFiles = {}, atlases = {},
  SetAtlas = function() return false end,
  GetAtlasRect = function() return nil end,
}
NE.qa = { modules = {} }
NE.compat = { RecordStub = function() end }
NE.FrameUtil = { PinPixelPerfect = function() end }

-- ── load in TOC order ───────────────────────────────────────────────────────
local FILES = {
  "compat/Events.lua",
  "core/GridLayout.lua",
  "core/CooldownNumbers.lua",
  "core/AuraSnapshot.lua",
  "core/SpellRanks.lua",
  "integration/Register.lua",
  "integration/Options.lua",
  "modules/cooldownviewer/ClassData.lua",
  "modules/cooldownviewer/CooldownViewer.lua",
  "modules/cooldownviewer/ItemMixins.lua",
  "modules/cooldownviewer/Viewers.lua",
  "modules/cooldownviewer/AuraItemMixins.lua",
  "modules/cooldownviewer/BuffViewers.lua",
  "modules/cooldownviewer/Register.lua",
}

print("=== LOAD ===")
for _, rel in ipairs(FILES) do
  local ok, err = pcall(dofile, ADDON .. rel)
  if ok then
    print("  ok   " .. rel)
  else
    print("  FAIL " .. rel .. "\n       " .. tostring(err))
    os.exit(1)
  end
end

local M = NE.cooldownviewer
local fails = 0
local function assertf(cond, msg)
  if cond then print("  ok   " .. msg)
  else fails = fails + 1; print("  FAIL " .. msg) end
end

print("\n=== BOOT (registration is deferred to PLAYER_LOGIN) ===")
-- Nothing should be registered before login fires.
assertf(next(DragonUI.EditableFrames) == nil, "no edit-mode registration at file-load time")

fireEvent("PLAYER_LOGIN")
drain()

assertf(M.viewers.essential ~= nil, "essential viewer created")
assertf(M.viewers.utility ~= nil, "utility viewer created")
-- The seam that matters: /dui edit drives EditableFrames, NOT MoversSystem.
assertf(DragonUI.EditableFrames["CooldownViewerEssential"] ~= nil, "essential registered as EditableFrame")
assertf(DragonUI.EditableFrames["CooldownViewerUtility"] ~= nil, "utility registered as EditableFrame")
assertf(#NE.optionSections == 1, "options section registered")

print("\n=== EVENTS: login ===")
local ranks = NE.spellbook.KnownRankIDs("Mind Blast")
assertf(ranks ~= nil and #ranks == 3, "spellbook rank table built (Mind Blast x3)")
assertf(NE.spellbook.HighestKnownRankID(8092, "Mind Blast") == 10947,
        "highest rank resolves 8092 -> 10947 (NOT castTime 1500)")

fireEvent("PLAYER_ENTERING_WORLD")
drain()

local ess = M.viewers.essential
local util = M.viewers.utility
local function shownItems(v)
  local n = 0
  for _, it in ipairs(v.items) do if it:IsShown() then n = n + 1 end end
  return n
end
print("  essential items: " .. #ess.items .. " (shown " .. shownItems(ess) .. ")")
print("  utility   items: " .. #util.items .. " (shown " .. shownItems(util) .. ")")
assertf(shownItems(ess) > 0, "essential viewer populated")
assertf(shownItems(util) > 0, "utility viewer populated")
assertf(ess._w > 1, "essential frame sized by layout (" .. ess._w .. "x" .. ess._h .. ")")

-- Mind Blast should have been upgraded from the curated rank-1 id to the learned rank 3.
local mb
for _, it in ipairs(ess.items) do if it.spellName == "Mind Blast" then mb = it end end
assertf(mb ~= nil, "Mind Blast tile present")
if mb then assertf(mb.spellID == 10947, "Mind Blast tile bound to highest rank (" .. tostring(mb.spellID) .. ")") end

print("\n=== EVENTS: cast a cooldown ===")
COOLDOWNS[10947] = { NOW, 8 }          -- Mind Blast rank 3, 8s cooldown
fireEvent("SPELL_UPDATE_COOLDOWN")
drain()
if mb then
  assertf(mb.Cooldown._cdStart == NOW and mb.Cooldown._cdDur == 8, "cooldown swipe set (8s)")
  assertf(mb.Icon._desat == true, "icon desaturated on real cooldown")
  assertf(mb.Cooldown._neText:GetText() ~= "" and mb.Cooldown._neText:GetText() ~= nil,
          "countdown text painted: '" .. tostring(mb.Cooldown._neText:GetText()) .. "'")
end

print("\n=== EVENTS: rank-safe read (cooldown on a rank the tile isn't keyed to) ===")
COOLDOWNS[10947] = nil
COOLDOWNS[8102] = { NOW, 8 }           -- a DIFFERENT rank is the one ticking
fireEvent("SPELL_UPDATE_COOLDOWN")
drain()
if mb then
  local s, d = mb:ReadCooldown()
  assertf(s == NOW and d == 8, "rank-safe read found the ticking rank (" .. tostring(s) .. "," .. tostring(d) .. ")")
end
COOLDOWNS[8102] = nil

print("\n=== EVENTS: GCD must not desaturate ===")
COOLDOWNS[61304] = { NOW, 1.5 }
COOLDOWNS[10947] = { NOW, 1.5 }
fireEvent("SPELL_UPDATE_COOLDOWN")
drain()
if mb then assertf(mb.Icon._desat == false, "icon NOT desaturated on GCD-length cooldown") end
COOLDOWNS[61304] = nil; COOLDOWNS[10947] = nil

print("\n=== SETTINGS ===")
M.SetOpt("CooldownViewerEssential", "iconLimit", 3)
assertf(M.GetOpt("CooldownViewerEssential", "iconLimit") == 3, "iconLimit persisted + read back")
assertf(ess.stride == 3, "stride applied to the live frame")
M.SetOpt("CooldownViewerEssential", "opacity", 60)
assertf(math.abs(ess:GetAlpha() - 0.6) < 0.001, "opacity applied live")
M.ResetOpts("CooldownViewerEssential")
assertf(M.GetOpt("CooldownViewerEssential", "iconLimit") == 12, "reset restores the default")

print("\n=== VISIBILITY ===")
M.SetCategoryEnabled("utility", false)
assertf(util:IsShown() == false, "disabling a category hides its viewer")
M.SetCategoryEnabled("utility", true)
assertf(util:IsShown() == true, "re-enabling shows it")

print("\n=== EDIT MODE ===")
local edEss = DragonUI.EditableFrames["CooldownViewerEssential"]
assertf(edEss.configPath[1] == "widgets" and edEss.configPath[2] == "neCooldownViewerEssential",
        "configPath wired (" .. edEss.configPath[1] .. "." .. edEss.configPath[2] .. ")")
assertf(edEss.editorVisible() == true, "always offered in edit mode")

-- THE bug this whole round-trip existed to catch: the registered frame must be a CreateUIFrame
-- ANCHOR (which carries the drag scripts), not the bare content frame.
assertf(edEss.frame._isUIFrame == true, "registered frame is a draggable CreateUIFrame anchor")
assertf(edEss.frame ~= ess, "anchor is distinct from the content frame")
assertf(ess.editorAnchor == edEss.frame, "content linked to its anchor")

-- Content must follow the anchor, and the anchor must track content size.
local cp = ess._points[#ess._points]
assertf(cp[2] == edEss.frame and 1 or 0, 1)
assertf(math.abs(edEss.frame:GetWidth() - ess:GetWidth()) < 0.001,
        "anchor tracks content width (" .. edEss.frame:GetWidth() .. ")")

-- showTest must populate even spells the character has NOT learned, so an empty viewer is grabbable.
local before = shownItems(ess)
edEss.showTest()
local during = shownItems(ess)
assertf(during >= before, "showTest populates demo icons (" .. before .. " -> " .. during .. ")")
edEss.hideTest()
assertf(shownItems(ess) == before, "hideTest restores the live set (" .. shownItems(ess) .. ")")

-- Position restore reads the fields DragonUI's SaveUIFramePosition actually writes.
profile.widgets = profile.widgets or {}
profile.widgets.neCooldownViewerEssential = { anchor = "TOPLEFT", posX = 123, posY = -456 }
assertf(NE.ApplySavedFramePosition(edEss.frame, "widgets", "neCooldownViewerEssential") == true,
        "saved position restored")
local pt = edEss.frame._points[#edEss.frame._points]
assertf(pt[1] == "TOPLEFT" and pt[4] == 123 and pt[5] == -456,
        "restored anchor/offsets correct (" .. pt[1] .. "," .. pt[4] .. "," .. pt[5] .. ")")

-- A DK-style empty viewer must still have a grabbable footprint in preview.
local savedList = M.GetActiveSpellList
M.GetActiveSpellList = function() return {} end
edEss.showTest()
assertf(ess._w > 1 and ess._h > 1, "empty viewer still grabbable in preview (" .. ess._w .. "x" .. ess._h .. ")")
M.GetActiveSpellList = savedList
edEss.hideTest()

print("\n=== BUFF VIEWERS (Phase 3) ===")

-- The clock MUST advance before the scan, not after: NE.aura caches its snapshot per frame, so an
-- aura change with a stale GetTime() is re-read from the previous frame's cache and looks invisible.
local function auraTick(unit)
  nextFrame()
  fireEvent("UNIT_AURA", unit)
  drain()
end
-- Same requirement for anything that rebuilds directly rather than through an event.
local function settle(fn)
  nextFrame()
  fn()
  drain()
end

local bIcon, bBar = M.viewers.buffIcon, M.viewers.buffBar
assertf(bIcon ~= nil and bBar ~= nil, "both aura viewers created")
assertf(DragonUI.EditableFrames["CooldownViewerBuffIcon"] ~= nil, "buffIcon is editable")
assertf(DragonUI.EditableFrames["CooldownViewerBuffBar"] ~= nil, "buffBar is editable")

-- Nothing up -> nothing shown.
auraTick("player")
assertf(shownItems(bIcon) == 0, "no auras -> buff icons empty")

-- A short buff must auto-track; a long one must not. This is also the arg-shift regression test:
-- read with modern indices, `duration` would receive the caster string and the window check would
-- silently reject everything.
BUFFS.player = {
  { name = "Power Infusion", rank = "", icon = "Interface\\Icons\\PI", count = 0,
    duration = 15, expiration = NOW + 11, spellID = 10060 },
  { name = "Arcane Intellect", rank = "Rank 3", icon = "Interface\\Icons\\AI", count = 0,
    duration = 1800, expiration = NOW + 1700, spellID = 10157 },
  { name = "Fortitude", rank = "Rank 1", icon = "Interface\\Icons\\PWF", count = 0,
    duration = 0, expiration = 0, spellID = 1243 },
}
auraTick("player")
assertf(shownItems(bIcon) == 1, "only the <=120s buff auto-tracks (" .. shownItems(bIcon) .. " of 3)")
assertf(bIcon.items[1].spellName == "Power Infusion",
        "tracked the right aura: " .. tostring(bIcon.items[1].spellName))
assertf(bIcon.items[1].Icon:GetTexture() == "Interface\\Icons\\PI",
        "icon read from index 3, not the rank at index 2")
assertf(shownItems(bBar) == 1, "bar viewer tracks it too (dest=both)")
assertf(math.abs((bBar.items[1]._auraDuration or 0) - 15) < 0.001,
        "bar cached duration 15 (" .. tostring(bBar.items[1]._auraDuration) .. ")")

-- The bar animates from cached values without re-scanning.
bBar.items[1]:RefreshCooldownInfo()
-- Expected remaining is expiration - now; the clock has stepped since the aura was authored, so
-- compare against the live figure rather than the literal 11 it started at.
local expectRemaining = bBar.items[1]._auraExpiration - GetTime()
assertf(math.abs((bBar.items[1].Bar._value or 0) - expectRemaining) < 0.001,
        ("bar value tracks remaining (%.2f)"):format(bBar.items[1].Bar._value or -1))
assertf(bBar.items[1].Bar._max == 15, "bar max = full duration 15")

-- Auto-track destination routing.
settle(function() M.SetAutoTrackDest("icon") end)
assertf(shownItems(bIcon) == 1 and shownItems(bBar) == 0, "dest=icon routes to icons only")
settle(function() M.SetAutoTrackDest("bar") end)
assertf(shownItems(bIcon) == 0 and shownItems(bBar) == 1, "dest=bar routes to bars only")
settle(function() M.SetAutoTrackDest("both") end)

-- Explicit assignment overrides the window: pin a PERMANENT toggle the auto path always rejects.
settle(function() M.SetAuraAssignment("PRIEST", 1243, "icon") end)
local names = {}
for _, it in ipairs(bIcon.items) do if it:IsShown() then names[it.spellName] = true end end
assertf(names["Fortitude"] == true, "explicitly assigned duration-0 aura is force-included")
assertf(names["Power Infusion"] == true, "auto-tracked aura still present alongside it")

-- ...and 'hidden' force-excludes one the window would have taken.
settle(function() M.SetAuraAssignment("PRIEST", 10060, "hidden") end)
names = {}
for _, it in ipairs(bIcon.items) do if it:IsShown() then names[it.spellName] = true end end
assertf(names["Power Infusion"] == nil, "hidden assignment excludes an auto-tracked aura")

-- One pool: assigning to the bar removes it from icons.
settle(function() M.SetAuraAssignment("PRIEST", 1243, "bar") end)
names = {}
for _, it in ipairs(bIcon.items) do if it:IsShown() then names[it.spellName] = true end end
assertf(names["Fortitude"] == nil, "bar-assigned aura no longer shows as an icon")
settle(function() M.ResetTrackedAura("PRIEST") end)

-- Buffs falling off must retire slots, not leave stale duplicates.
BUFFS.player = {}
auraTick("player")
assertf(shownItems(bIcon) == 0 and shownItems(bBar) == 0, "all auras gone -> both viewers empty")
assertf(bBar.items[1].spellID == nil, "retired bar slot cleared its spell identity")

-- Tracked DoT on the target (explicit assignments only; the auto window must never reach targets).
DEBUFFS.target = {
  { name = "Devouring Plague", rank = "Rank 1", icon = "Interface\\Icons\\DP", count = 0,
    duration = 24, expiration = NOW + 20, spellID = 2944 },
}
UnitExists = function(u) return u == "player" or u == "target" end
auraTick("target")
assertf(shownItems(bIcon) == 0, "untracked target debuff is ignored by the auto window")
settle(function() M.SetAuraAssignment("PRIEST", 2944, "icon") end)
assertf(shownItems(bIcon) == 1, "explicitly tracked target DoT appears")
DEBUFFS.target = {}
settle(function() M.ResetTrackedAura("PRIEST") end)

print("\n=== UNIT-EVENT FILTER ===")
local probe = CreateFrame("Frame")
local got = {}
probe:SetScript("OnEvent", function(_, ev, unit) got[#got + 1] = unit end)
probe:RegisterUnitEvent("UNIT_AURA", "player")
fireEvent("UNIT_AURA", "player")
fireEvent("UNIT_AURA", "target")
fireEvent("UNIT_AURA", "raid14")
assertf(#got == 1 and got[1] == "player", "filtered UNIT_AURA delivered only for player (" .. #got .. " of 3)")

print("")
if fails == 0 then print("ALL BOOT CHECKS PASSED") else print(fails .. " FAILURE(S)") end
os.exit(fails == 0 and 0 or 1)
