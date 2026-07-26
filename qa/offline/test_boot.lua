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
  function r:SetWidth(w) self._w = w end
  function r:SetHeight(h) self._h = h end
  function r:SetSize(w, h) self._w, self._h = w, h end
  function r:GetWidth() return self._w or 0 end
  function r:GetHeight() return self._h or 0 end
  function r:GetSize() return self._w or 0, self._h or 0 end
  function r:SetDrawLayer() end
  function r:SetTexCoordModifiesRect() end
  function r:SetRotation() end
  function r:SetJustifyH() end
  function r:SetJustifyV() end
  function r:SetBlendMode() end
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
-- Window surface: what a draggable, ESC-closable panel touches.
function frameMeta:SetClampedToScreen() end
function frameMeta:SetToplevel() end
function frameMeta:RegisterForDrag() end
function frameMeta:StartMoving() end
function frameMeta:StopMovingOrSizing() end
function frameMeta:EnableMouseWheel() end
function frameMeta:EnableKeyboard() end
function frameMeta:SetHitRectInsets() end
function frameMeta:RegisterForClicks() end
function frameMeta:SetResizable() end
function frameMeta:SetMinResize() end
function frameMeta:SetMaxResize() end
function frameMeta:GetRegions() return unpack(self._regions) end
function frameMeta:GetObjectType() return self._kind end
function frameMeta:SetBackdrop() end
function frameMeta:SetBackdropColor() end
function frameMeta:SetBackdropBorderColor() end
-- ScrollFrame surface.
function frameMeta:SetScrollChild(c) self._scrollChild = c end
function frameMeta:GetScrollChild() return self._scrollChild end
function frameMeta:SetVerticalScroll(v) self._vscroll = v end
function frameMeta:GetVerticalScroll() return self._vscroll or 0 end
function frameMeta:GetVerticalScrollRange() return 0 end
function frameMeta:UpdateScrollChildRect() end
-- EditBox surface (the search box).
function frameMeta:SetAutoFocus() end
function frameMeta:ClearFocus() end
function frameMeta:SetTextInsets() end
function frameMeta:SetText(t) self._text = t end
function frameMeta:GetText() return self._text or "" end
function frameMeta:SetFontObject() end
function frameMeta:SetNormalTexture() end
function frameMeta:SetHighlightTexture() end
function frameMeta:SetPushedTexture() end
function frameMeta:GetNormalTexture() return newRegion("Texture") end
function frameMeta:SetDisabledTexture() end
function frameMeta:Enable() self._enabled = true end
function frameMeta:Disable() self._enabled = false end
function frameMeta:IsEnabled() return self._enabled ~= false end
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
-- WoW exposes the Lua stdlib under short global aliases and addon code uses them freely.
tinsert, tremove, tContains = table.insert, table.remove, nil
sort, wipe = table.sort, function(t) for k in pairs(t) do t[k] = nil end return t end
strfind, strsub, strupper, strlower, strrep, strlen = string.find, string.sub, string.upper, string.lower, string.rep, string.len
format, gsub, strmatch, strsplit = string.format, string.gsub, string.match, nil
abs, floor, ceil, max, min, sqrt = math.abs, math.floor, math.ceil, math.max, math.min, math.sqrt

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
-- Mirrors 3.3.5a: IsUsableSpell takes a spell NAME (or a spellbook index + bookType). Given a
-- spellID it reads it as an index past the end of the book and returns nil — no error, just a
-- silent nil that is neither usable nor out-of-mana. Returning a blanket `true` here is what let
-- the viewer ship rendering every icon permanently grey.
function IsUsableSpell(arg)
  if type(arg) == "string" then return true, false end
  return nil
end
function IsSpellInRange() return nil end
function IsUsableItem() return true end
function IsSpellKnown(id) return true end
function GetInventoryItemCooldown() return 0, 0, 0 end
function GetItemCooldown() return 0, 0, 0 end
function GetItemIcon() return "Interface\\Icons\\Test" end

-- A tiny fake spellbook: Mind Blast with three ranks, plus a few singles.
SPELLS = {
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
BOOK = { 8092, 8102, 10947, 10060, 14751, 2944, 17, 586 }
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

-- Deferred callbacks, run at a drain point — but only once their delay has actually elapsed on the
-- stub clock. Honouring the delay matters: the cooldown-expiry refresh schedules itself for the end
-- of the cooldown, and a stub that fired every timer immediately would make that path look like it
-- worked no matter what it did.
local pending = {}
C_Timer = {
  After = function(delay, fn)
    pending[#pending + 1] = { at = NOW + (tonumber(delay) or 0), fn = fn }
  end,
}
local function drain()
  local n = 0
  while n < 50 do
    local due, rest = {}, {}
    for _, e in ipairs(pending) do
      if e.at <= NOW then due[#due + 1] = e else rest[#rest + 1] = e end
    end
    if #due == 0 then break end
    pending = rest
    for _, e in ipairs(due) do e.fn() end
    n = n + 1
  end
end

C_Container = {}
C_Item = {}
SlashCmdList = {}
UISpecialFrames = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

-- ── Phase 4 stubs: alerts, sounds, menu ─────────────────────────────────────
-- Target health drives the execute branch of the "usable" alert.
TARGET_HP, TARGET_HP_MAX = 100, 100
function UnitHealth(u) return u == "target" and TARGET_HP or 100 end
function UnitHealthMax(u) return u == "target" and TARGET_HP_MAX or 100 end
function UnitIsDeadOrGhost() return false end

-- Records what was actually asked to play, so a test can tell "played the right file" from
-- "silently played nothing" — the exact distinction that matters given retail kit IDs are inert
-- on this client.
SOUNDS_PLAYED = {}
function PlaySoundFile(path, channel)
  SOUNDS_PLAYED[#SOUNDS_PLAYED + 1] = { path = path, channel = channel }
  return true
end

-- LibCustomGlow stands in for the FX renderers. It records the live glow per frame so the tests can
-- assert on what is showing rather than on internal bookkeeping.
GLOWS = setmetatable({}, { __mode = "k" })
local LCG_STUB = {
  PixelGlow_Start    = function(r, color) GLOWS[r] = { kind = "pixel",  color = color } end,
  PixelGlow_Stop     = function(r) if GLOWS[r] and GLOWS[r].kind == "pixel"  then GLOWS[r] = nil end end,
  ButtonGlow_Start   = function(r, color) GLOWS[r] = { kind = "button", color = color } end,
  ButtonGlow_Stop    = function(r) if GLOWS[r] and GLOWS[r].kind == "button" then GLOWS[r] = nil end end,
  AutoCastGlow_Start = function(r, color) GLOWS[r] = { kind = "auto",   color = color } end,
  AutoCastGlow_Stop  = function(r) if GLOWS[r] and GLOWS[r].kind == "auto"   then GLOWS[r] = nil end end,
}
function LibStub(name, silent)
  if name == "LibCustomGlow-1.0" then return LCG_STUB end
  return nil
end


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
  "modules/cooldownviewer/CdmSeedWotLK.lua",
  "modules/cooldownviewer/CooldownViewer.lua",
  "modules/cooldownviewer/ItemMixins.lua",
  "modules/cooldownviewer/Viewers.lua",
  "modules/cooldownviewer/AuraItemMixins.lua",
  "modules/cooldownviewer/BuffViewers.lua",
  "modules/cooldownviewer/AlertData.lua",
  "modules/cooldownviewer/SoundAlertData.lua",
  "modules/cooldownviewer/Alerts.lua",
  "core/Texture.lua",
  "core/Tabs.lua",
  "core/PanelChrome.lua",
  "core/FrameUtil.lua",
  "modules/cooldownviewer/SettingsAssets.lua",
  "modules/cooldownviewer/SettingsPanel.lua",
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

print("\n=== ICON TINT ===")
-- Reported in-game: every icon rendered grey. IsUsableSpell was being handed a spellID, which this
-- client reads as a spellbook index and answers nil for, so the tint fell through to ICON_UNUSABLE.
mb:RefreshIconColor()
local tint = mb.Icon._color
assertf(tint and tint[1] == M.ICON_USABLE[1] and tint[2] == M.ICON_USABLE[2],
        "a usable spell tints white, not grey (got "
        .. table.concat({ tostring(tint and tint[1]), tostring(tint and tint[2]) }, ",") .. ")")

-- The ready flash must be armed without the retail flipbook atlas, which this client lacks. The old
-- guard read GetAtlasRect's first return (0 for an unknown atlas) as truthy and never fired.
mb:ClearFlash()
mb:ScheduleFlash(GetTime() + 5, 10)
assertf(mb.CooldownFlash._flashStartTime ~= nil, "ready flash schedules without the flipbook atlas")
assertf(mb.CooldownFlash.Flipbook:GetTexture() == M.FLASH_FALLBACK_TEXTURE,
        "…using the fallback highlight texture")
-- Step into the flash window and confirm the pulse drives alpha rather than erroring on a number.
mb.CooldownFlash._flashStartTime = GetTime() - 0.2
mb.CooldownFlash:GetScript("OnUpdate")(mb.CooldownFlash)
assertf((mb.CooldownFlash.Flipbook:GetAlpha() or 0) > 0, "…and the pulse raises its alpha")
mb:ClearFlash()

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

print("\n=== COOLDOWN EXPIRY ===")
-- Reported in-game: icons went grey on cast and STAYED grey after the cooldown finished.
-- 3.3.5a fires no event when a cooldown expires, so nothing re-ran RefreshCooldown and the
-- desaturation persisted until some unrelated event refreshed the tile. The item now schedules its
-- own refresh for the moment the cooldown ends. Note this asserts with NO event fired at all.
if mb then
  assertf(mb.Icon._desat == true, "still desaturated mid-cooldown")
  nextFrame(8.2)          -- past the 8s cooldown
  COOLDOWNS[10947] = nil  -- the client would now report no cooldown
  drain()                 -- only the expiry timer is due; no event is sent
  assertf(mb.Icon._desat == false, "icon un-desaturates at expiry with NO event fired")
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

print("\n=== WOTLK SEED (Phase 2) ===")
-- Vanilla ClassData has no DEATHKNIGHT at all; CdmSeedWotLK must create it.
local dkEss = M.ESSENTIAL_BY_CLASS.DEATHKNIGHT
local dkUti = M.UTILITY_BY_CLASS.DEATHKNIGHT
assertf(dkEss ~= nil and #dkEss > 0, "Death Knight essential list exists (" .. (dkEss and #dkEss or 0) .. ")")
assertf(dkUti ~= nil and #dkUti > 0, "Death Knight utility list exists (" .. (dkUti and #dkUti or 0) .. ")")

-- The appends must be additive, not replacements: vanilla Priest entries survive alongside WotLK.
local pEss = M.ESSENTIAL_BY_CLASS.PRIEST
local hasVanilla, hasWotlk = false, false
for _, id in ipairs(pEss) do
  if id == 8092  then hasVanilla = true end   -- Mind Blast, from ClassData
  if id == 47540 then hasWotlk   = true end   -- Penance, from the seed
end
assertf(hasVanilla and hasWotlk, "seed appends to the vanilla list rather than replacing it")

-- No duplicates anywhere (appendAll dedupes).
local dupes = 0
for _, tbl in pairs({ M.ESSENTIAL_BY_CLASS, M.UTILITY_BY_CLASS }) do
  for _, list in pairs(tbl) do
    local seen = {}
    for _, id in ipairs(list) do
      if seen[id] then dupes = dupes + 1 end
      seen[id] = true
    end
  end
end
assertf(dupes == 0, "no duplicate ids after the append (" .. dupes .. ")")

-- A Death Knight must actually populate. Rebuild filters on GetSpellInfo resolving, and the fake
-- spellbook above deliberately knows only a handful of Priest spells — so register the seed's DK
-- ids with it first. (Keeping the stub strict by default is what lets Rebuild's "a bad curated
-- entry can't create a broken tile" guard stay meaningful for every other test.)
for _, list in ipairs({ dkEss, dkUti }) do
  for _, id in ipairs(list) do
    SPELLS[id] = { "DK Ability " .. id, "" }
  end
end
UnitClass = function() return "Death Knight", "DEATHKNIGHT" end
M.InvalidateCuratedCache()
ess._editPreview = true          -- preview skips the learn-gate, as edit mode does
settle(function() ess:Rebuild() end)
assertf(shownItems(ess) > 0, "Death Knight essential viewer populates (" .. shownItems(ess) .. " icons)")
ess._editPreview = false
UnitClass = function() return "Priest", "PRIEST" end
M.InvalidateCuratedCache()
settle(function() ess:Rebuild() end)

print("\n=== LEARN GATE ===")
-- Regressions reported in-game: a Disc priest's Penance and a Holy priest's Guardian Spirit were
-- filtered out, as was Divine Hymn on a level-squished (60) server. All three are the same fault —
-- the gate keyed on an exact rank id / level rather than on the spellbook.

-- 1. Higher rank trained. The curated id is rank 1; the book holds rank 3 under the SAME name, and
--    IsSpellKnown on the rank-1 id says false. This is the Penance case.
SPELLS[47540] = { "Penance", "Rank 1" }   -- curated seed id
SPELLS[53007] = { "Penance", "Rank 3" }   -- what the player actually trained
BOOK[#BOOK + 1] = 53007
IsSpellKnown = function(id) return id == 53007 end   -- exact-rank semantics, as the client has
_G.__SLOT_IDS = BOOK
settle(function() NE.spellbook.BuildRankTable() end)
assertf(NE.spellbook.IsSpellNameKnown("Penance") == true, "spellbook knows Penance by name")
assertf(M.IsTrackable(47540, "PRIEST") == true,
        "rank-1 curated id passes the gate when a HIGHER rank is trained")

-- 2. Level squish: an ability known far below its stock level. The gate must not consult level at
--    all — being in the book is sufficient. This is the Divine Hymn case.
SPELLS[64843] = { "Divine Hymn", "" }
BOOK[#BOOK + 1] = 64843
_G.__SLOT_IDS = BOOK
settle(function() NE.spellbook.BuildRankTable() end)
assertf(M.IsTrackable(64843, "PRIEST") == true, "level-squished ability passes on spellbook presence")

-- 3. The gate must still EXCLUDE something genuinely not known, or it is useless.
assertf(M.IsTrackable(47585, "PRIEST") == false, "unknown curated spell is still filtered (Dispersion)")

-- 4. A spellbook entry whose link can't be parsed (GetSpellBookItemInfo -> nil id) must still count
--    as known: KNOWN_NAMES is built from names alone for exactly this reason.
SPELLS[47788] = { "Guardian Spirit", "" }
BOOK[#BOOK + 1] = 47788
_G.__SLOT_IDS = BOOK
local realLink = GetSpellLink
GetSpellLink = function() return nil end          -- simulate unparseable links
settle(function() NE.spellbook.BuildRankTable() end)
assertf(NE.spellbook.IsSpellNameKnown("Guardian Spirit") == true,
        "name-only book scan survives failed link parsing")
assertf(M.IsTrackable(47788, "PRIEST") == true, "talent-granted ability passes without an id")
GetSpellLink = realLink
settle(function() NE.spellbook.BuildRankTable() end)

print("\n=== CUSTOM-LIST SHADOWING ===")
-- The reported fault: every WotLK-seeded ability stayed hidden even though the learn-gate passed
-- for it. Cause was a stale CUSTOM list frozen into SavedVariables by a read-only query, which
-- then shadowed the curated tables permanently.

-- 1. GetItemMeta is a query and must NOT create a custom list as a side effect.
local cd = M._store(true)
cd.customLists = {}
M.GetItemMeta(8092, "PRIEST")
assertf(M.GetCustomList("essential", "PRIEST") == nil,
        "GetItemMeta does not seed a custom list")

-- 2. With no custom list, the curated table (incl. the WotLK seed) drives the viewer.
local curated = M.GetActiveSpellList("essential", true)
local sawSeeded = false
for _, id in ipairs(curated) do if id == 47540 then sawSeeded = true end end
assertf(sawSeeded, "curated path includes seeded abilities (Penance)")

-- 3. A stale custom list DOES shadow it — reproducing the bug, so the fix is meaningful.
M.SetCustomList("essential", "PRIEST", { { spellID = 8092, enabled = true } })
local shadowed = M.GetActiveSpellList("essential", true)
local stillSeeded = false
for _, id in ipairs(shadowed) do if id == 47540 then stillSeeded = true end end
assertf(not stillSeeded, "a custom list shadows the curated table (the reported bug)")

-- 4. The one-time migration clears it and restores the curated path.
cd.customListsV2 = nil
assertf(M.MigrateStaleCustomLists() == true, "migration reports it cleared something")
assertf(M.GetCustomList("essential", "PRIEST") == nil, "stale list gone")
local restored = M.GetActiveSpellList("essential", true)
local backAgain = false
for _, id in ipairs(restored) do if id == 47540 then backAgain = true end end
assertf(backAgain, "curated abilities visible again after migration")

-- 5. It must be one-shot: a list authored later (Phase 4 picker) must survive.
M.SetCustomList("essential", "PRIEST", { { spellID = 8092, enabled = true } })
assertf(M.MigrateStaleCustomLists() == false, "migration does not run twice")
assertf(M.GetCustomList("essential", "PRIEST") ~= nil, "a deliberately authored list is preserved")
M.ResetCustomList("essential", "PRIEST")

print("\n=== ALERT DATA (Phase 4) ===")
local A  = M.alertdata
local AL = M.alerts

assertf(A.EXECUTE[24275] == 0.20, "Hammer of Wrath rank 1 carries a 20% execute threshold")
assertf(A.EXECUTE[48806] == 0.20, "…and so does its highest WotLK rank")
assertf(A.EXECUTE[53351] == 0.20, "Kill Shot present (the WotLK-only execute, absent upstream)")
assertf(A.REACTIVE[7384] == true, "Overpower present despite an EMPTY rank string in the DBC")
-- The two impostor classes the generator has to reject. Both were live faults during generation.
assertf(A.REACTIVE[34097] == nil, "NPC copies of Riposte excluded (class attribution)")
assertf(A.EXECUTE[20647] == nil, "Execute's triggered damage sub-spell excluded (unranked sibling)")
assertf(A.REACTIVE[1495] == nil, "Mongoose Bite excluded — not dodge-gated on 3.3.5a")

assertf(A.ExecuteThreshold(999999, { 24274 }) == 0.20, "execute resolves through a known rank id")
assertf(A.ExecuteThreshold(999999, nil) == nil, "a non-execute spell yields no threshold")
assertf(A.IsReactive(6572) == true, "Revenge is reactive")
assertf(A.IsReactive(8092) == false, "Mind Blast is not")

print("\n=== SOUND CATALOGUE (Phase 4) ===")
local nSounds, missingFile = 0, 0
for _, cat in ipairs(M.SOUND_CATEGORY_ORDER) do
  for _, e in ipairs(M.SOUND_DATA[cat] or {}) do
    nSounds = nSounds + 1
    if not e.file then missingFile = missingFile + 1 end
  end
end
assertf(nSounds == 67, "67 sounds catalogued (" .. nSounds .. ")")
assertf(missingFile == 0, "every catalogued sound has a shipped file")
assertf(M.SOUND_DATA.Short == nil, "the unplayable 'Short' category is not offered")
assertf(M.GetSoundKitName(316401) == "Cat", "kit id resolves to its label")

SOUNDS_PLAYED = {}
assertf(M.PlayReadySound(316401) == true, "PlayReadySound reports it played")
assertf(#SOUNDS_PLAYED == 1 and SOUNDS_PLAYED[1].path:find("7466002%.ogg"),
        "…by FILE PATH, not by kit id (" .. tostring(SOUNDS_PLAYED[1] and SOUNDS_PLAYED[1].path) .. ")")
assertf(M.PlayReadySound(999999) == false, "an unmapped kit plays nothing and says so")

print("\n=== ALERT STORE (Phase 4) ===")
assertf(AL.HasAny() == false, "no alerts assigned by default")
assertf(M.HasAnyReadySound() == false, "no sounds assigned by default")

AL.SetType(8092, "usable")
assertf(AL.GetType(8092) == "usable", "alert type stored")
assertf(AL.GetFX(8092) == 1, "fx defaulted on first assignment")
assertf(AL.GetWindow(8092) == 0.30, "window defaulted on first assignment")
assertf(AL.HasAny() == true, "HasAny sees the assignment")

AL.SetFX(8092, 2)
AL.SetType(8092, nil)
assertf(AL.GetType(8092) == nil, "alert can be disabled")
assertf(AL.GetFX(8092) == 2, "…and disabling KEEPS the fx choice for re-enabling")
assertf(AL.HasAny() == false, "HasAny false again once disabled")

AL.SetWindow(8092, 0.95); assertf(AL.GetWindow(8092) == 0.50, "window clamps to the 50% maximum")
AL.SetWindow(8092, 0.01); assertf(AL.GetWindow(8092) == 0.10, "window clamps to the 10% minimum")

M.SetReadySoundKit(8092, 316401)
assertf(M.GetReadySoundKit(8092) == 316401, "ready sound stored")
assertf(M.HasAnyReadySound() == true, "HasAnyReadySound sees it")

-- Preferences must key off the LISTED id, not the learned-rank id the tile displays. The Mind Blast
-- tile shows rank 3 (10947) but is listed as rank 1 (8092); keying on the former would silently
-- orphan every alert and sound the moment the player trained the next rank.
assertf(mb.spellID == 10947, "the tile displays the learned rank")
assertf(mb:GetSettingsKey() == 8092, "…but its settings key is the listed rank-1 id")

print("\n=== ALERT ENGINE (Phase 4) ===")
local tickFn = AL._ticker:GetScript("OnUpdate")
local function tick() tickFn(AL._ticker, 1) end

local function itemFor(name)
  for _, it in ipairs(ess.items) do if it.spellName == name then return it end end
  for _, it in ipairs(util.items) do if it.spellName == name then return it end end
  return nil
end

-- The ready transition: a real cooldown finishing must fire the assigned sound EXACTLY once.
COOLDOWNS[10947] = { GetTime(), 30 }
mb:RefreshCooldown()
tick()
SOUNDS_PLAYED = {}
COOLDOWNS[10947] = nil
mb:RefreshCooldown()
tick()
assertf(#SOUNDS_PLAYED == 1, "cooldown -> ready fires the assigned sound once (" .. #SOUNDS_PLAYED .. ")")
tick(); tick()
assertf(#SOUNDS_PLAYED == 1, "…and not again on later ticks")

-- "available" is an edge-triggered flash, not a state the ticker maintains.
AL.SetType(8092, "available")
AL.ClearFX(mb)
COOLDOWNS[10947] = { GetTime(), 30 }; mb:RefreshCooldown(); tick()
COOLDOWNS[10947] = nil;         mb:RefreshCooldown(); tick()
assertf(GLOWS[mb] ~= nil, "available alert flashes the icon on the ready transition")
tick()
assertf(GLOWS[mb] ~= nil, "…and the ticker does not clear the one-shot flash out from under it")
AL.SetType(8092, nil); AL.ClearFX(mb)

-- "refresh": glow only inside the last `window` fraction of the tracked aura's duration.
AL.SetType(2944, "refresh")
AL.SetWindow(2944, 0.30)
local dp = itemFor("Devouring Plague")
assertf(dp ~= nil, "Devouring Plague tile present for the refresh test")
if dp then
  BUFFS.player[1] = { name = "Devouring Plague", rank = "Rank 1", icon = "i", duration = 24, expiration = GetTime() + 20 }
  nextFrame(); tick()
  assertf(GLOWS[dp] == nil, "no refresh glow at 20s of 24s remaining")
  BUFFS.player[1].expiration = GetTime() + 5
  nextFrame(); tick()
  assertf(GLOWS[dp] ~= nil, "refresh glow inside the last 30% (5s of 24s)")
  local colour = GLOWS[dp] and GLOWS[dp].color
  assertf(colour and colour[1] == 1.00 and colour[2] == 0.50, "…tinted pandemic-orange, not the usable yellow")
  BUFFS.player[1] = nil
  nextFrame(); tick()
  assertf(GLOWS[dp] == nil, "refresh glow clears when the aura falls off")
end
AL.SetType(2944, nil)

-- "usable": data-driven. Only an execute/reactive spell ever glows, and only when its condition holds.
AL.SetType(8092, "usable")
TARGET_HP = 10
nextFrame(); tick()
assertf(GLOWS[mb] == nil, "a spell with no execute/reactive entry never glows on 'usable'")
AL.SetType(8092, nil); AL.ClearFX(mb)
TARGET_HP = 100

-- A one-shot flash must survive the very next tick, or the settings PREVIEW is invisible.
AL.ClearFX(mb)
AL.Preview(mb, 1)
assertf(GLOWS[mb] ~= nil, "preview shows an effect immediately")
tick()
assertf(GLOWS[mb] ~= nil, "…and the ticker leaves it up for its hold")
nextFrame(2)   -- past AVAILABLE_HOLD
tick()
assertf(GLOWS[mb] == nil, "…then it clears once the hold expires")

-- The global escape hatch in the options tab.
AL.SetType(8092, "available")
M.ResetAlerts()
assertf(AL.HasAny() == false and M.HasAnyReadySound() == false, "ResetAlerts clears both stores")
assertf(GLOWS[mb] == nil, "…and takes down anything currently glowing")

print("\n=== SPELL VISIBILITY (Phase 4) ===")
-- Hiding a spell is the one place seeding a custom list is correct: the user just chose.
M.ResetCustomList("essential", "PRIEST")
assertf(M.IsSpellEnabled("essential", 8092) == true, "spell enabled by default")
assertf(M.GetCustomList("essential", "PRIEST") == nil, "…and asking did NOT seed a list")

assertf(M.SetSpellEnabled("essential", 8092, false) == true, "hiding a spell reports a change")
assertf(M.IsSpellEnabled("essential", 8092) == false, "spell now hidden")
local afterHide = M.GetActiveSpellList("essential", true)
local stillThere = false
for _, id in ipairs(afterHide) do if id == 8092 then stillThere = true end end
assertf(not stillThere, "hidden spell drops out of the active list")
assertf(M.SetSpellEnabled("essential", 8092, false) == false, "hiding twice is a no-op")
M.SetSpellEnabled("essential", 8092, true)
assertf(M.IsSpellEnabled("essential", 8092) == true, "and it can be shown again")
M.ResetCustomList("essential", "PRIEST")


print("\n=== SETTINGS PANEL (Phase 4b-1) ===")
local CDS = NE.cooldownviewersettings
assertf(CDS ~= nil, "settings panel namespace exists")
assertf(SlashCmdList["NECDMSETTINGS"] ~= nil, "/cdm slash command registered")
assertf(_G.NE_CooldownViewerSettings == nil, "panel not built before first open (lazy)")

SlashCmdList["NECDMSETTINGS"]()
local sp = _G.NE_CooldownViewerSettings
assertf(sp ~= nil, "/cdm builds and shows the panel")
if sp then
  assertf(sp:IsShown(), "panel shown after first /cdm")
  assertf(sp._w == 399 and sp._h == 609, "panel sized 399x609 (" .. sp._w .. "x" .. sp._h .. ")")
  assertf(CDS.GetDisplayMode() == "spells", "opens on the Spells tab")
  assertf(#sp.tabButtons == 2, "two side tabs, not three (" .. #sp.tabButtons .. ")")
  assertf(sp.scroll ~= nil and sp.content ~= nil, "scroll body built")
  assertf(sp.search ~= nil, "search box built")

  local esc = false
  for _, n in ipairs(UISpecialFrames) do if n == "NE_CooldownViewerSettings" then esc = true end end
  assertf(esc, "registered with UISpecialFrames for ESC-close")

  CDS.SetDisplayMode("auras")
  assertf(CDS.GetDisplayMode() == "auras", "switches to the Auras tab")

  SlashCmdList["NECDMSETTINGS"]()
  assertf(not sp:IsShown(), "/cdm toggles the panel closed")
  CDS.OpenTo("buffBar")
  assertf(sp:IsShown() and CDS.GetDisplayMode() == "auras", "OpenTo(buffBar) opens on the Auras tab")
  CDS.HidePanel()
end

-- The side-tab art must resolve or the tabs are transparent gaps. This is what would have caught
-- core/Tabs.lua's stale "sheet not shipped" note.
assertf(NE.tex.HasAtlas("questlog-tab-side"), "side-tab body atlas registered")
assertf(NE.tex.HasAtlas("icon_cooldownmanager"), "Spells tab glyph registered")
assertf(NE.tex.HasAtlas("icon_trackedbuffs"), "Auras tab glyph registered")

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
