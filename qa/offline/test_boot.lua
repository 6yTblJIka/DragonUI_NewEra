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

local function newRegion(kind, layer)
  local r = { _kind = kind, _shown = true, _alpha = 1, _layer = layer }
  function r:SetTexture(t) self._tex = t end
  function r:GetTexture() return self._tex end
  -- Recorded, not discarded: the GCD flipbook stepper's only observable output is its texcoords, and
  -- that code path first executes in Phase 8a.
  function r:SetTexCoord(...) self._coords = { ... } end
  function r:GetTexCoord()
    local c = self._coords
    if not c then return nil end
    return c[1], c[2], c[3], c[4]
  end
  function r:SetVertexColor(...) self._color = { ... } end
  function r:GetVertexColor()
    local c = self._color
    if not c then return 1, 1, 1, 1 end
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
  end
  function r:SetDesaturated(v) self._desat = v end
  -- Anchors are RECORDED, in the same shape frames use. Discarding them meant a texture's geometry
  -- was unassertable, which is how the icon/frame fit went unnoticed: the overlay art was registered
  -- and the icon overshot its border by four pixels with nothing able to see it.
  r._points = {}
  function r:SetAllPoints(rel) self._points[#self._points + 1] = { "ALL", rel } end
  function r:SetPoint(p, rel, relP, x, y) self._points[#self._points + 1] = { p, rel, relP, x, y } end
  function r:ClearAllPoints() self._points = {} end
  function r:GetNumPoints() return #self._points end
  function r:GetPoint(i)
    local pt = self._points[i or 1]
    if not pt then return nil end
    return pt[1], pt[2], pt[3], pt[4], pt[5]
  end
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
  -- Recorded from Phase 8c: the buffed-spell glow is a second copy of the frame art in the same rect,
  -- so BOTH of these carry meaning — without ADD it darkens the tile instead of lighting it, and
  -- without the sublevel it draws under the art it is supposed to light.
  function r:SetDrawLayer(layer, sub) self._layer, self._sublevel = layer, sub end
  function r:GetDrawLayer() return self._layer, self._sublevel end
  function r:SetTexCoordModifiesRect() end
  function r:SetRotation() end
  function r:SetJustifyH() end
  function r:SetJustifyV() end
  -- Word-wrapped description text measures itself to decide its row height. A fixed answer is enough
  -- for the layout maths to be exercised; the real client returns the wrapped height.
  function r:GetStringHeight() return 12 end
  function r:SetBlendMode(m) self._blend = m end
  function r:GetBlendMode() return self._blend or "BLEND" end
  function r:SetParent(p) self._parent = p end
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
-- Symmetrically, OnHide fires on a shown -> hidden transition. The settings panel cancels an
-- in-flight drag from there, because the close button and ESC both call Hide() directly.
function frameMeta:Hide()
  local was = self._shown
  self._shown = false
  if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function frameMeta:IsShown() return self._shown end
function frameMeta:SetPoint(p, rel, relP, x, y) self._points[#self._points + 1] = { p, rel, relP, x, y } end
function frameMeta:SetAllPoints(rel) self._points[#self._points + 1] = { "ALL", rel } end
function frameMeta:ClearAllPoints() self._points = {} end
function frameMeta:GetNumPoints() return #self._points end
function frameMeta:GetPoint(i)
  local pt = self._points[i or 1]
  if not pt then return nil end
  return pt[1], pt[2], pt[3], pt[4], pt[5]
end
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
function frameMeta:GetName() return self._name end
function frameMeta:GetEffectiveScale() return self._scale or 1 end
-- Drag targeting is geometry: the caret goes before or after the tile depending on which side of
-- its CENTRE the cursor sits. A stub that cannot answer GetCenter cannot test that at all, so
-- tests place tiles explicitly via _center.
function frameMeta:GetCenter()
  local c = self._center
  if c then return c[1], c[2] end
  return nil
end
function frameMeta:LockHighlight() self._locked = true end
function frameMeta:UnlockHighlight() self._locked = false end
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
-- The LAYER argument is kept. Discarding it meant GetDrawLayer only ever answered for regions that
-- had also been through SetDrawLayer, so a region created on the wrong layer was unassertable — which
-- is how a mutation test on the buff glow's layer came back green with the glow back over the icon.
function frameMeta:CreateTexture(_, layer) local t = newRegion("Texture", layer); self._regions[#self._regions+1] = t; return t end
function frameMeta:CreateFontString() local t = newRegion("FontString"); self._regions[#self._regions+1] = t; return t end
function frameMeta:SetCooldown(s, d) self._cdStart, self._cdDur = s, d end
function frameMeta:SetDrawEdge() end
function frameMeta:SetReverse(v) self._reverse = v end
-- StatusBar surface (BuffBar rows) — and Slider, which shares it.
function frameMeta:SetMinMaxValues(lo, hi) self._min, self._max = lo, hi end
function frameMeta:GetMinMaxValues() return self._min or 0, self._max or 1 end
-- The client fires OnValueChanged whenever SetValue actually MOVES the value, including when the
-- caller is code rather than a drag. The settings sliders depend on that being true: each one
-- re-seats its thumb from inside its own OnValueChanged handler, and re-reads its getter on every
-- page refresh. A stub that swallowed those calls could not tell a working re-entrancy guard from a
-- missing one.
function frameMeta:SetValue(v)
  local old = self._value
  self._value = v
  if old ~= v and self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v) end
end
function frameMeta:GetValue() return self._value end
function frameMeta:SetValueStep(s) self._valueStep = s end
function frameMeta:SetOrientation(o) self._orientation = o end
-- CheckButton surface. 3.3.5a returns 1/nil rather than true/false, which is why every reader in the
-- settings kit normalises with `and true or false`; the stub returns booleans because the difference
-- is only interesting at the call site, and a test asserting `== true` on a real client would pass
-- anyway through that normalisation.
function frameMeta:SetChecked(v) self._checked = v and true or false end
function frameMeta:GetChecked() return self._checked end
function frameMeta:Click(button)
  if self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton") end
end
-- SetObeyStepOnDrag is deliberately ABSENT: it is retail-only, which is why the slider kit snaps the
-- value itself. Adding it here would hide that.
function frameMeta:SetStatusBarColor(...) self._barColor = { ... } end
function frameMeta:GetStatusBarColor()
  local c = self._barColor
  if not c then return 1, 1, 1, 1 end
  return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
end
-- SetStatusBarTexture takes a path OR a texture, and GetStatusBarTexture always hands back a
-- TEXTURE OBJECT — never the path you passed in. Returning the raw argument (as this stub used to)
-- meant NE.tex.SetAtlasOnStatusBar called SetAlpha on a string, which only surfaced once Phase 8a
-- registered the bar atlas and that function stopped bailing out early. The Pip also anchors to this
-- object (AuraItemMixins:193), so a string would silently misplace it in the real client too.
function frameMeta:SetStatusBarTexture(t)
  if type(t) == "table" then
    self._barTexObj = t
  else
    if not self._barTexObj then self._barTexObj = newRegion("Texture") end
    self._barTexObj:SetTexture(t)
  end
  self._barTex = t
end
function frameMeta:GetStatusBarTexture() return self._barTexObj end

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
-- ClassicAPI's SearchBoxTemplate seeds the edit box with this string as its placeholder, so any
-- code reading the box back sees "Search" until the player types. That is a real behaviour, not
-- decoration — it dimmed the whole settings grid once.
SEARCH, YES, NO = "Search", "Yes", "No"
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
-- Post-hook: run the original, then the hook, and hand back the original's returns. Both real forms
-- are supported — hooksecurefunc(tbl, "name", fn) and hooksecurefunc("globalName", fn).
function hooksecurefunc(a, b, c)
  local tbl, key, hook
  if type(a) == "table" then tbl, key, hook = a, b, c else tbl, key, hook = _G, a, b end
  local orig = tbl[key]
  if type(orig) ~= "function" or type(hook) ~= "function" then return end
  tbl[key] = function(...)
    local r1, r2, r3, r4 = orig(...)
    pcall(hook, ...)
    return r1, r2, r3, r4
  end
end
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

-- Equipped inventory, keyed by slot. Trinkets are 13/14. Tests mutate this to simulate a swap, so
-- discovery has to be re-read rather than cached at load.
EQUIPPED = {}
function GetInventoryItemID(unit, slot) return unit == "player" and EQUIPPED[slot] or nil end
function GetInventoryItemTexture() return "Interface\\Icons\\TestItem" end
-- itemID -> { useSpellName, useSpellID }. An item absent here has NO on-use effect, which is how a
-- proc trinket behaves and is exactly the case discovery must skip.
ITEM_SPELLS = {}
function GetItemSpell(itemID)
  local e = ITEM_SPELLS[itemID]
  if not e then return nil end
  return e[1], e[2]
end
INVSLOT_TRINKET1, INVSLOT_TRINKET2 = 13, 14

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
-- Record the lines so a test can assert what a tooltip actually said, not just that it opened.
GameTooltip.lines = {}
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:SetText(t) self.lines = { t } end
function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = t end
function GameTooltip:SetSpellByID(id) self.lines = { "spell " .. tostring(id) } end

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

-- UI click sounds (the settings checkboxes) go through PlaySound, which takes a NAME on this client.
-- Kept in its own table so the ready-sound assertions above still count only what they play.
UI_SOUNDS = {}
function PlaySound(kit)
  UI_SOUNDS[#UI_SOUNDS + 1] = kit
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

-- ── mouse, for the drag reorder ─────────────────────────────────────────────
-- 3.3.5a has no GLOBAL_MOUSE_UP, so SettingsReorder ends a drag by watching IsMouseButtonDown in
-- its OnUpdate. That makes the button state a first-class input to the code under test, not
-- scenery: a test drives a drop by releasing the button and stepping the driver.
CURSOR = { x = 0, y = 0 }
MOUSE_DOWN = { LeftButton = false, RightButton = false }
MOUSE_FOCUS = nil

function GetCursorPosition() return CURSOR.x, CURSOR.y end
function IsMouseButtonDown(btn) return MOUSE_DOWN[btn or "LeftButton"] and true or false end
function GetMouseFocus() return MOUSE_FOCUS end

-- ── C_UIDropDownMenu stand-in ───────────────────────────────────────────────
-- NOT a reimplementation. It records the `info` tables core/Menu.lua hands to AddButton, which is
-- the part of menu rendering that is OURS and therefore checkable here. The bug this exists to
-- prevent lived in ClassicAPI's own AddButton — it reads a predicate through
-- `type(x)=="function" and x() or x`, which returns the FUNCTION (truthy) whenever the predicate is
-- false, so every function-valued radio drew as selected. Copying that bug into the stub to "catch"
-- it would be circular; asserting we only ever pass a BOOLEAN is not, and is what keeps us clear of
-- it. Levels are recorded separately so a test can walk into a submenu.
DD_ROWS = {}
local function ddReset(fromLevel)
  for l = fromLevel, 8 do
    DD_ROWS[l] = nil
    local list = _G["C_DropDownList" .. l]
    if list then list.numButtons = 0 end
  end
end

function C_UIDropDownMenu_CreateInfo() return {} end

function C_UIDropDownMenu_AddButton(info, level)
  level = level or 1
  local rows = DD_ROWS[level] or {}
  DD_ROWS[level] = rows
  local copy = {}
  for k, v in pairs(info) do copy[k] = v end
  rows[#rows + 1] = copy

  local listName = "C_DropDownList" .. level
  local list = _G[listName] or CreateFrame("Frame", listName)
  list.numButtons = #rows

  local bn = listName .. "Button" .. #rows
  local b = _G[bn] or CreateFrame("Button", bn)
  b.checked = info.checked
  b.menuList = info.menuList
  _G[bn .. "Check"] = _G[bn .. "Check"] or b:CreateTexture()
end

function C_UIDropDownMenu_Initialize(frame, init, displayMode, level, menuList)
  frame.initialize = init
  ddReset(level or 1)
  if init then init(frame, level, menuList) end
end

function C_ToggleDropDownMenu(level, value, frame, anchor, x, y, menuList)
  frame = frame or DragonUI_NewEra.menu._frame   -- global on purpose: the NE local is declared below
  C_UIDropDownMenu_Initialize(frame, frame.initialize, nil, level or 1, menuList)
end

function C_CloseDropDownMenus(level) ddReset(level or 1) end

-- The destructive cog entries route through a confirm popup rather than firing on click. Record
-- which one was raised; a test then calls its OnAccept, which is the path the player takes.
StaticPopupDialogs = {}
POPUPS_SHOWN = {}
function StaticPopup_Show(which)
  POPUPS_SHOWN[#POPUPS_SHOWN + 1] = which
  return StaticPopupDialogs[which]
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
  -- Editor mode, as NE.OpenFrameEditor drives it (DragonUI modules/editor_mode.lua). Show() refusing
  -- in combat is faithful and load-bearing: the real one returns from an empty branch with no message,
  -- which is why the caller re-checks IsActive instead of trusting the call.
  EditorMode = {
    _active = false,
    Show    = function(self) if not (InCombatLockdown and InCombatLockdown()) then self._active = true end end,
    Hide    = function(self) self._active = false end,
    IsActive = function(self) return self._active end,
  },
  -- Records the frame the editor was told to select. Which frame that is, is the whole point: the
  -- editor knows the ANCHOR, never the HUD content hung off it.
  SelectEditorFrame = function(frame) DragonUI._selected = frame end,
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
  "modules/cooldownviewer/CdmAuraCatalog.lua",
  "modules/cooldownviewer/CooldownViewer.lua",
  "modules/cooldownviewer/Equip.lua",
  "modules/cooldownviewer/ItemMixins.lua",
  "modules/cooldownviewer/Viewers.lua",
  "modules/cooldownviewer/AuraItemMixins.lua",
  "modules/cooldownviewer/BuffViewers.lua",
  "modules/cooldownviewer/AlertData.lua",
  "modules/cooldownviewer/SoundAlertData.lua",
  "modules/cooldownviewer/Alerts.lua",
  "core/Texture.lua",
  -- After core/Texture.lua, not next to the viewer files it serves: both asset files bail out at
  -- their first line if NE.tex is absent, so loading them earlier would register nothing at all —
  -- silently, and with every HasAtlas assertion below then failing for the wrong reason. The real
  -- .toc has core/ long before modules/, which is why this only bites here.
  "modules/cooldownviewer/Assets.lua",
  "core/Tabs.lua",
  "core/Menu.lua",
  "core/PanelChrome.lua",
  "core/FrameUtil.lua",
  "modules/cooldownviewer/SettingsAssets.lua",
  "modules/cooldownviewer/SettingsPanel.lua",
  "modules/cooldownviewer/CdmArsenal.lua",
  "modules/cooldownviewer/SettingsAdapter.lua",
  "modules/cooldownviewer/SettingsCategories.lua",
  "modules/cooldownviewer/SettingsMenu.lua",
  "modules/cooldownviewer/SettingsReorder.lua",
  "modules/cooldownviewer/SettingsPresets.lua",
  "modules/cooldownviewer/SettingsControls.lua",
  "modules/cooldownviewer/SettingsOptions.lua",
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

-- The ready flash must be armed at all. The old guard read GetAtlasRect's first return (0 for an
-- unknown atlas) as truthy and never fired.
mb:ClearFlash()
mb:ScheduleFlash(GetTime() + 5, 10)
assertf(mb.CooldownFlash._flashStartTime ~= nil, "ready flash schedules")
-- Phase 8a ships and registers the GCD flipbook, which retires the fallback burst: this assertion
-- used to require the fallback texture, and inverting it is the intended consequence of that.
assertf(mb.CooldownFlash.Flipbook:GetTexture() == NE.tex.Local(5199404),
        "…using the flipbook sprite sheet, not the fallback highlight")

-- The sprite stepper had never executed before 8a, because the atlas it gates on was never
-- registered. Drive it and check the frame it lands on is a real cell of the strip.
do
  local l0, r0, t0, b0 = NE.tex.GetAtlasRect("UI-HUD-ActionBar-GCD-Flipbook")
  local frameW, frameH = (r0 - l0) / 2, (b0 - t0) / 11
  mb:ClearFlash()
  local start = GetTime()
  mb:ScheduleFlash(start, 5)
  local flash = mb.CooldownFlash
  local play = flash._flashStartTime
  assertf(play ~= nil, "flash armed for the sprite path")

  local seen = {}
  for _, at in ipairs({ 0.01, 0.2, 0.5, 0.74 }) do
    NOW = play + at
    flash._scripts.OnUpdate(flash)
    local l, r, t, b = flash.Flipbook:GetTexCoord()
    assertf(l and r and t and b, "stepper set texcoords at t+" .. at)
    if l then
      -- Inside the strip, and exactly one cell wide/tall. A frame straddling a boundary would show
      -- two half-sprites, which is the failure this catches.
      local inside = l >= l0 - 1e-6 and r <= r0 + 1e-6 and t >= t0 - 1e-6 and b <= b0 + 1e-6
      local oneCell = math.abs((r - l) - frameW) < 1e-6 and math.abs((b - t) - frameH) < 1e-6
      assertf(inside, ("…inside the strip (%.4f-%.4f, %.4f-%.4f)"):format(l, r, t, b))
      assertf(oneCell, "…and exactly one 47x47 cell")
      local onGrid = math.abs((l - l0) / frameW - math.floor((l - l0) / frameW + 0.5)) < 1e-4
      assertf(onGrid, "…aligned to the cell grid, not straddling two frames")
      seen[l .. ":" .. t] = true
    end
  end
  local distinct = 0
  for _ in pairs(seen) do distinct = distinct + 1 end
  assertf(distinct > 1, "the sprite advances through frames (" .. distinct .. " distinct cells)")
  -- Left ARMED, not cleared: the pulse test immediately below drives this frame's OnUpdate by hand,
  -- and ClearFlash removes the script out from under it.
  mb:ScheduleFlash(GetTime() + 5, 10)
end
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

-- Auto-track is OFF out of the box: a newly met aura is recorded and listed under Hidden, but nothing
-- appears on screen unassigned. Asserted here rather than assumed, because everything below this line
-- depends on the opposite and would otherwise fail for a reason that looks nothing like the cause.
assertf(M.IsAutoTrackBuffs() == false, "auto-track defaults OFF (new buffs stay hidden)")
BUFFS.player = { { name = "Power Infusion", rank = "", icon = "Interface\\Icons\\PI", count = 0,
                   duration = 15, expiration = NOW + 11, spellID = 10060 } }
auraTick("player")
assertf(shownItems(bIcon) == 0, "…so a short buff shows nothing until it is assigned")
M.SetAutoTrackBuffs(true)
auraTick("player")
assertf(shownItems(bIcon) == 1, "…and turning auto-track on brings it straight in")

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

-- "usable": castable right now.
--
-- This block used to assert the OPPOSITE — "a spell with no execute/reactive entry never glows" —
-- and it passed for the wrong reason. isSpellUsableNow was calling IsUsableSpell with a spellID,
-- which this client answers with nil, so nothing could glow on this event whatever the data said.
-- The assertion agreed with the bug and shielded it, until the owner reported that Usable did
-- nothing at all. A test that encodes "feature off" cannot tell you the feature is broken.
AL.SetType(8092, "usable")
AL.ClearFX(mb)
COOLDOWNS[10947] = nil; mb:RefreshCooldown()
nextFrame(); tick()
assertf(GLOWS[mb] ~= nil, "usable alert glows while the spell is castable")
local usableColour = GLOWS[mb] and GLOWS[mb].color
assertf(usableColour and usableColour[1] == 0.95 and usableColour[3] == 0.32,
        "…in the usable yellow, not the available green")
COOLDOWNS[10947] = { GetTime(), 30 }; mb:RefreshCooldown()
nextFrame(); tick()
assertf(GLOWS[mb] == nil, "…and clears while it is on cooldown")
COOLDOWNS[10947] = nil; mb:RefreshCooldown()
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

-- The preview must show the colour the player will actually SEE. It used to flash everything as
-- "usable", so choosing Available previewed yellow and then glowed green in play.
AL.ClearFX(mb)
AL.Preview(mb, 1, "available")
local previewColour = GLOWS[mb] and GLOWS[mb].color
assertf(previewColour and previewColour[1] == 0.35 and previewColour[2] == 1.00,
        "preview uses the chosen alert type's tint, not always the usable yellow")
AL.ClearFX(mb)
AL.Preview(mb, 1, "refresh")
previewColour = GLOWS[mb] and GLOWS[mb].color
assertf(previewColour and previewColour[1] == 1.00 and previewColour[2] == 0.50,
        "…and refresh previews pandemic-orange")
AL.ClearFX(mb)

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
  -- Three tabs: Spells, Tracked Buffs, Settings. NOT upstream's three — its third is Group Buffs,
  -- which needs NE.groupbuff.filter and is dropped whole (PORT_PLAN §G.4).
  assertf(#sp.tabButtons == 3, "three side tabs (" .. #sp.tabButtons .. ")")
  assertf(sp.settingsTab.displayMode == "settings", "…the third being Settings, not Group Buffs")
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
-- Registered by this module, not borrowed from the spellbook's asset file: the tab would otherwise be
-- a transparent gap on any load order where that file had not run.
assertf(NE.tex.HasAtlas("questlog-icon-setting"), "Settings tab glyph registered")

print("\n=== VIEWER ART (Phase 8a) ===")
do
  -- Six atlases were being set by name and registered nowhere, so every region rendered as nothing.
  -- HasAtlas on each is the assertion that would have caught it — the same one that caught the
  -- side-tab art above.
  local VIEWER_ATLASES = {
    "UI-HUD-CoolDownManager-IconOverlay",
    "UI-CooldownManager-OORshadow",
    "UI-HUD-ActionBar-GCD-Flipbook",
    "UI-HUD-CoolDownManager-Bar",
    "UI-HUD-CoolDownManager-Bar-BG",
    "UI-HUD-CoolDownManager-Bar-Pip",
  }
  for _, name in ipairs(VIEWER_ATLASES) do
    assertf(NE.tex.HasAtlas(name), "atlas registered: " .. name)
  end

  -- Every atlas name the viewer files MENTION must be registered. Hard-coding the list above would
  -- not have caught the original fault, because the fault was a name nobody had listed anywhere —
  -- so read them back out of the source instead. A seventh SetAtlas added later fails here.
  local mentioned, missing = {}, {}
  for _, rel in ipairs({ "modules/cooldownviewer/ItemMixins.lua",
                         "modules/cooldownviewer/AuraItemMixins.lua",
                         "modules/cooldownviewer/BuffViewers.lua",
                         "modules/cooldownviewer/Viewers.lua" }) do
    local fh = io.open(ADDON .. rel, "r")
    if fh then
      local body = fh:read("*a"); fh:close()
      -- Line by line, skipping comments. Matching on the function name does not work: the call sites
      -- go through a local alias (`local set = NE.tex.SetAtlas; set(tex, "UI-...")`), which is how a
      -- first attempt at this found 3 of 6. Skipping comment lines is the other half — these files
      -- also NAME atlases in prose, and a comment explaining why one is deliberately absent must not
      -- be read as a requirement to ship it.
      for line in body:gmatch("[^\r\n]+") do
        if not line:match("^%s*%-%-") then
          for nm in line:gmatch('"(UI%-[%w%-]+)"') do mentioned[nm] = rel end
        end
      end
    end
  end
  local n = 0
  for nm, rel in pairs(mentioned) do
    n = n + 1
    if not NE.tex.HasAtlas(nm) then missing[#missing + 1] = nm .. " (" .. rel .. ")" end
  end
  assertf(n >= 6, "found the viewer files' atlas call sites (" .. n .. " names)")
  assertf(#missing == 0, "every atlas the viewers ask for is registered"
    .. (#missing > 0 and (": MISSING " .. table.concat(missing, ", ")) or ""))

  -- The rects are transcribed from upstream's generated data, so the thing worth asserting is that
  -- they belong to the sheets WE ship: rect fraction x sheet size must give back the declared atlas
  -- size. This is what catches a repacked sheet — the exact failure SettingsAssets.lua records for
  -- 7289697, where Era-generated rects were wrong for the 12.1.0 BLP.
  local SHEET = { [6704514] = { 256, 128 }, [6685874] = { 512, 1024 }, [5199404] = { 2048, 1024 } }
  local bad = {}
  for _, name in ipairs(VIEWER_ATLASES) do
    local e = NE.tex._atlasEntry(name)
    local sheet = e and SHEET[e.file]
    if sheet then
      local w = (e.right - e.left) * sheet[1]
      local h = (e.bottom - e.top) * sheet[2]
      if math.abs(w - e.width) > 0.5 or math.abs(h - e.height) > 0.5 then
        bad[#bad + 1] = ("%s: rect gives %.1fx%.1f, declares %dx%d")
          :format(name, w, h, e.width, e.height)
      end
    else
      bad[#bad + 1] = name .. ": no known sheet size for fdid " .. tostring(e and e.file)
    end
  end
  assertf(#bad == 0, "every rect matches the shipped sheet's real dimensions"
    .. (#bad > 0 and (": " .. table.concat(bad, "; ")) or ""))

  -- Each sheet must actually be on disk under the path Assets.lua registers. A rect pointing at an
  -- unshipped FDID resolves to the bare number, which the client renders as nothing — the same
  -- invisible failure by a different route (and the one SettingsAssets.lua hit with 5684744).
  for fdid in pairs(SHEET) do
    local path = NE.tex.Local(fdid)
    assertf(path ~= nil, "sheet " .. fdid .. " has a local BLP path")
    if path then
      local rel = path:gsub("^Interface\\AddOns\\DragonUI_NewEra\\", ""):gsub("\\", "/")
      local fh = io.open(ADDON .. rel, "rb")
      assertf(fh ~= nil, "…and the file exists: " .. rel)
      if fh then
        -- Confirm the BLP header carries the dimensions the rect arithmetic above assumed, rather
        -- than trusting a table that says so.
        local head = fh:read(20); fh:close()
        local magic = head:sub(1, 4)
        local w = 0
        for i = 0, 3 do w = w + head:byte(13 + i) * (256 ^ i) end
        local h = 0
        for i = 0, 3 do h = h + head:byte(17 + i) * (256 ^ i) end
        assertf(magic == "BLP2" and w == SHEET[fdid][1] and h == SHEET[fdid][2],
          ("…and is a BLP2 of the assumed size (%s %dx%d)"):format(magic, w, h))
      end
    end
  end

  -- ── icon-vs-frame fit ─────────────────────────────────────────────────────────────────────────
  -- Registering the overlay made a geometry fault visible that had been latent since Phase 1: retail
  -- masks the Icon, and that mask insets it by 3/64 of the tile as well as rounding it. Without the
  -- inset a full-bleed icon overshoots the overlay's border line by ~4px on a 50px tile and sits out
  -- in the halo — "the icons are too large and sit outside the framing".
  assertf(math.abs(M.ICON_MASK_INSET - 3 / 64) < 1e-9,
    "the mask inset is the one decoded from 6707800 (3 of 64)")

  -- The border line's position in tile coordinates, derived from the art rather than restated: the
  -- crisp line sits at art 14-19 of the 86px cell, mapped through the overlay's outward anchor. The
  -- icon's edge must land INSIDE that band — outside it the frame floats off the icon (the old
  -- full-bleed behaviour), well inside it the frame eats into the art.
  --
  -- PER AXIS, which is the point. The overlay is anchored ±9 horizontally but ±8 vertically, so the
  -- band sits at a different offset on each axis while the mask is square. A first version of this
  -- checked the horizontal band only and passed while the icon's top and bottom edges were still
  -- outside their band on three of the four tile shapes — reported from the game as "still 1px too
  -- large in all directions".
  local function bandOn(size, o)
    local ext = size + 2 * o
    return -o + 14 * ext / 86, -o + 19 * ext / 86
  end
  for _, v in ipairs({ { "essential", M.viewers.essential, 50, 9, 8 },
                       { "utility",   M.viewers.utility,   30, 6, 5 },
                       { "buffIcon",  M.viewers.buffIcon,  40, 8, 7 } }) do
    local label, viewer, size, ox, oy = v[1], v[2], v[3], v[4], v[5]
    local item = viewer and viewer.items and viewer.items[1]
    if item and item.Icon then
      local want = M.IconInset(size)
      local p, _, _, x, y = item.Icon:GetPoint(1)
      assertf(p == "TOPLEFT" and math.abs((x or 0) - want) < 0.01 and math.abs((y or 0) + want) < 0.01,
        ("%s icon is inset by %.2fpx (got %s %s,%s)")
          :format(label, want, tostring(p), tostring(x), tostring(y)))
      for _, ax in ipairs({ { "horizontally", ox }, { "vertically", oy } }) do
        local lo, hi = bandOn(size, ax[2])
        assertf(want >= lo - 0.01 and want <= hi + 0.01,
          ("…and the border line lands on its edge %s (%.2f within %.2f..%.2f)")
            :format(ax[1], want, lo, hi))
      end

      -- Everything drawn OVER the icon shares its rect. Anchored to the tile instead, each one draws
      -- proud of the icon and shows the old footprint — which is exactly how the cooldown sweep gave
      -- itself away once the frame art shipped.
      for _, r in ipairs({ { "cooldown sweep", item.Cooldown },
                           { "out-of-range shade", item.OutOfRange },
                           { "ready flash", item.CooldownFlash } }) do
        local rn, reg = r[1], r[2]
        if reg then
          local rp, _, _, rx, ry = reg:GetPoint(1)
          assertf(rp == "TOPLEFT" and math.abs((rx or 0) - want) < 0.01
                    and math.abs((ry or 0) + want) < 0.01,
            ("…%s's %s shares the icon's rect (got %s %s,%s)")
              :format(label, rn, tostring(rp), tostring(rx), tostring(ry)))
        end
      end
    else
      assertf(false, label .. " has an item to measure")
    end
  end

  -- The inset is a SETTING now, so the invariant cannot be "it equals a number". What must hold at
  -- every legal value: the frame always covers the icon's edge (never proud of the band's outer
  -- limit), and the icon never shrinks clean through the frame's opening. The aperture is measured
  -- from the art, at art 20 of 86 — the first fully transparent texel inward of the border line.
  for _, v in ipairs({ { "essential", 50, 9, 8 }, { "utility", 30, 6, 5 }, { "buffIcon", 40, 8, 7 } }) do
    local label, size, ox, oy = v[1], v[2], v[3], v[4]
    for _, ax in ipairs({ { "horizontally", ox }, { "vertically", oy } }) do
      local lo = select(1, bandOn(size, ax[2]))
      local aperture = M.IconAperture(size, ax[2])
      local atMax = size * (M.ICON_MASK_INSET + M.ICON_INSET_EXTRA_MAX / 100)
      assertf(atMax <= aperture + 0.01,
        ("%s stays inside the frame's opening %s even at max inset (%.2f vs %.2f)")
          :format(label, ax[1], atMax, aperture))
      local atMin = size * M.ICON_MASK_INSET
      assertf(atMin >= 0, label .. " min inset is non-negative " .. ax[1])
      assertf(aperture > lo, label .. "'s opening is inside its border band " .. ax[1])
    end
  end

  -- Fractional, not flat. A flat pixel budget generous enough for a 50px tile pushes a 30px one
  -- through its own opening — the first draft did exactly that and failed here at 3.41 against 3.28.
  -- Expressed as: the SAME setting must stay legal on the largest and smallest shapes at once.
  local wide = M.IconInset(50) / 50
  local narrow = M.IconInset(30) / 30
  assertf(math.abs(wide - narrow) < 1e-9, "the inset is a fraction of the tile, not a flat pixel count")

  -- And it has to reach tiles that already exist, or the slider does nothing until the next login.
  do
    local before = select(4, mb.Icon:GetPoint(1))
    M.SetIconInsetExtra(M.ICON_INSET_EXTRA_MAX)
    local after = select(4, mb.Icon:GetPoint(1))
    assertf(after > before, ("moving the slider re-anchors a built tile (%.2f -> %.2f)")
      :format(before, after))
    M.SetIconInsetExtra(M.ICON_INSET_EXTRA)
    assertf(math.abs(select(4, mb.Icon:GetPoint(1)) - before) < 1e-9, "…and back again")
  end

  -- The flipbook's frame grid has to divide its strip evenly, or the ready-flash sprite samples
  -- across frame boundaries. 94/2 and 517/11 are both 47.
  local e = NE.tex._atlasEntry("UI-HUD-ActionBar-GCD-Flipbook")
  assertf(e.width % 2 == 0 and e.height % 11 == 0,
    "the flipbook strip divides into 2x11 whole frames")
  assertf(e.width / 2 == e.height / 11, "…and those frames are square (47x47)")
end

print("\n=== BUFFED-SPELL GLOW (Phase 8c) ===")
do
  local glow = mb.BuffGlow
  assertf(glow ~= nil, "the tile has a buff-glow region")

  -- ADD blending emits src.rgb x alpha. The first version of this drew a gold additive copy of the
  -- tile's own IconOverlay atlas, and 6704514's overlay cell is PURE BLACK — (0,0,0) throughout,
  -- with only an alpha ramp — because it is a drop shadow, not a metal frame. Everything about that
  -- version passed: the atlas resolved, the region was shown, the blend was ADD, the tint was gold.
  -- It rendered nothing, because zero times gold is zero. So the assertion is on the SOURCE: an
  -- additive region has to be given art that can carry light, and none of the sheet we ship can.
  local tx = glow:GetTexture()
  assertf(tx == M.BUFF_GLOW_TEXTURE, "…drawn from the stock soft-glow ring, not a sheet atlas")
  assertf(not tostring(tx):find("CooldownViewer", 1, true),
    "…and NOT from the CoolDownManager sheet, whose art is black and emits nothing under ADD")
  assertf(glow:GetBlendMode() == "ADD", "…blended additively, so it lights rather than darkens")

  -- Oversized, not matched to the frame or the icon: the ring has a wide transparent margin of its
  -- own, and at the tile's rect the visible part falls inside the icon instead of on its edge.
  local gp, _, _, gx, gy = glow:GetPoint(1)
  local over = M.BuffGlowInset(50)
  assertf(gp == "TOPLEFT" and gx == -over and gy == over,
    ("…and oversized past the tile by %dpx (got %s,%s)"):format(over, tostring(gx), tostring(gy)))
  local ox = select(4, mb.IconOverlay:GetPoint(1))
  assertf(over > math.abs(ox), "…which is wider than the frame art's own overhang")
  -- BEHIND the icon, which is what keeps a filled glow texture off the icon art. Drawn over the tile
  -- it veiled the icon instead of haloing it; on BACKGROUND the opaque icon does the masking that
  -- this client cannot do with a MaskTexture.
  local layer = glow:GetDrawLayer()
  assertf(layer == "BACKGROUND", "…drawn behind the icon, so it haloes rather than veils")
  local r, g, b = glow:GetVertexColor()
  assertf(r > g and g > b, "…in gold, the colour retail gives the swipe it cannot set here")

  -- The state machine. A tile with no aura of its own must not glow, or the signal means nothing.
  BUFFS.player[1] = nil
  COOLDOWNS[10947] = nil
  nextFrame(); mb:RefreshCooldown()
  assertf(glow:IsShown() == false, "no glow with the spell's buff absent")

  BUFFS.player[1] = { name = "Mind Blast", rank = "Rank 3", icon = "i",
                      duration = 15, expiration = GetTime() + 10 }
  nextFrame(); mb:RefreshCooldown()
  assertf(glow:IsShown() == true, "glows while the spell's own buff is on the player")

  -- The cooldown path must take it off again. This is the one that would break silently: the aura
  -- branch returns early, so a glow left un-cleared there stays up for the rest of the session.
  BUFFS.player[1] = nil
  COOLDOWNS[10947] = { GetTime(), 30 }
  nextFrame(); mb:RefreshCooldown()
  assertf(glow:IsShown() == false, "…and comes off when the buff falls and the cooldown starts")
  COOLDOWNS[10947] = nil; mb:RefreshCooldown()

  -- The opt-out has to reach a tile that is glowing RIGHT NOW. RefreshCooldown only revisits the
  -- glow when something about the spell changes, which for a buff already up can be a minute away —
  -- so the setter refreshes rather than waiting to be noticed.
  BUFFS.player[1] = { name = "Mind Blast", rank = "Rank 3", icon = "i",
                      duration = 15, expiration = GetTime() + 10 }
  nextFrame(); mb:RefreshCooldown()
  assertf(glow:IsShown() == true, "glowing again for the opt-out check")
  M.SetBuffGlowEnabled(false)
  assertf(M.IsBuffGlowEnabled() == false, "the setting stores off")
  assertf(glow:IsShown() == false, "…and clears a glow that was already up")
  nextFrame(); mb:RefreshCooldown()
  assertf(glow:IsShown() == false, "…and refreshing does not bring it back")
  M.SetBuffGlowEnabled(true)
  nextFrame(); mb:RefreshCooldown()
  assertf(glow:IsShown() == true, "…and turning it back on restores it")
  assertf(M.IsBuffGlowEnabled() == true, "on is the default state")

  -- A recycled tile keeps its texture regions. RefreshCooldown returns early without a spellID, so
  -- nothing on the refresh path can clear a glow left behind by the spell that used to live here —
  -- the pooling loop has to do it, or the next spell to reuse the tile inherits a gold frame.
  local ev = M.viewers.essential
  local last = ev.items[#ev.items]
  last:SetBuffGlow(true)
  assertf(last.BuffGlow:IsShown() == true, "a spare tile is glowing before the list shrinks")
  M.SetSpellEnabled("essential", 8092, false)
  ev:Rebuild()
  assertf(last.BuffGlow:IsShown() == false, "…and recycling the tile out of the layout clears it")
  M.SetSpellEnabled("essential", 8092, true)
  M.ResetCustomList("essential", "PRIEST")
  ev:Rebuild()

  BUFFS.player[1] = nil
  nextFrame()
end

print("\n=== BUFFED TILE: WHICH TIMER (Phase 8c follow-up) ===")
do
  -- Reported on Prayer of Mending: the tile counted down the 30s BUFF while the player wanted the
  -- cooldown, and two numbers ticking over the same icon are indistinguishable. Retail can only say
  -- "buffed" by tinting that swipe, so it has no choice; since 8c the glow says it, and the number
  -- is free to be the useful one.
  assertf(M.BuffShowsAuraTime() == false, "the cooldown is the default timer on a buffed tile")

  local cdStart, cdDur = GetTime() - 1, 30
  COOLDOWNS[10947] = { cdStart, cdDur }
  BUFFS.player[1] = { name = "Mind Blast", rank = "Rank 3", icon = "i",
                      duration = 6, expiration = GetTime() + 6 }
  nextFrame(); mb:RefreshCooldown()
  assertf(math.abs((mb.Cooldown._cdDur or 0) - cdDur) < 0.01,
    ("buffed AND on cooldown shows the cooldown (%s, not the 6s aura)")
      :format(tostring(mb.Cooldown._cdDur)))
  assertf(mb.BuffGlow:IsShown() == true, "…and the glow still marks it as buffed")

  -- The signal is not the setting: flipping the timer must not silence the glow, or the two numbers
  -- become indistinguishable again in the other direction.
  M.SetBuffShowsAuraTime(true)
  nextFrame(); mb:RefreshCooldown()
  assertf(math.abs((mb.Cooldown._cdDur or 0) - 6) < 0.01,
    ("retail's reading shows the aura instead (%s)"):format(tostring(mb.Cooldown._cdDur)))
  assertf(mb.BuffGlow:IsShown() == true, "…with the glow unchanged either way")
  M.SetBuffShowsAuraTime(false)

  BUFFS.player[1] = nil
  COOLDOWNS[10947] = nil
  nextFrame(); mb:RefreshCooldown()
end

print("\n=== PER-SPEC LAYOUT ===")
do
  local group = 1
  GetActiveTalentGroup = function() return group end
  M.ResetTracking()
  assertf(M.IsPerSpecLayout() == true, "per-spec layout is on by default")
  assertf(M.LayoutKey() == "spec1", "…and keys off the active talent group")

  -- The reported behaviour: hide a spell in one spec, swap, and it must come back.
  M.SetSpellEnabled("essential", 8092, false)
  assertf(M.IsSpellEnabled("essential", 8092) == false, "spell hidden in group 1")

  group = 2
  M.InvalidateCuratedCache()
  assertf(M.LayoutKey() == "spec2", "swapping groups moves to the other bucket")
  assertf(M.IsSpellEnabled("essential", 8092) == true,
    "…where the spell is still shown — the two layouts are independent")

  M.SetSpellEnabled("essential", 8092, false)
  M.SetSpellEnabled("essential", 8129, false)
  group = 1
  M.InvalidateCuratedCache()
  assertf(M.IsSpellEnabled("essential", 8129) == true,
    "…and edits in group 2 do not leak back into group 1")
  assertf(M.IsSpellEnabled("essential", 8092) == false, "…while group 1 keeps its own edit")

  -- Turning the feature off collapses both onto one shared bucket.
  M.SetPerSpecLayout(false)
  assertf(M.LayoutKey() == "shared", "off, both groups share one bucket")
  group = 2
  assertf(M.LayoutKey() == "shared", "…whichever group is active")
  M.SetPerSpecLayout(true)
  group = 1
  M.InvalidateCuratedCache()

  -- Reset clears EVERY bucket. Clearing only the active one would leave the other spec's lists in
  -- place after the player asked for a clean slate.
  M.ResetTracking()
  assertf(M.IsSpellEnabled("essential", 8092) == true, "reset clears the active bucket")
  group = 2
  M.InvalidateCuratedCache()
  assertf(M.IsSpellEnabled("essential", 8092) == true, "…and the inactive one too")
  group = 1
  M.InvalidateCuratedCache()

  -- The bucket must NOT be the saved-preset table. It was, in the first draft: `cd.layouts` is
  -- SettingsPresets' own key, so ResetTracking silently deleted every layout the player had saved.
  local cd = M._store(true)
  assertf(cd.specLayouts ~= nil, "the buckets live under specLayouts")
  cd.layouts = { ["A Saved Layout"] = { class = "PRIEST" } }
  M.ResetTracking()
  assertf(cd.layouts and cd.layouts["A Saved Layout"] ~= nil,
    "…so resetting tracking leaves saved layouts alone")
  cd.layouts = nil

  -- What is knowledge rather than layout stays shared: an aura met in one spec is still an aura this
  -- character can get, and hiding it from the other spec's picker would be a bug wearing a feature.
  M.NoteSeenAura(48168, "Improved Spirit Tap", "i", 8)
  local function seenHas(id)
    for _, e in ipairs(M.GetSeenAuraList("PRIEST")) do if e.spellID == id then return true end end
    return false
  end
  assertf(seenHas(48168), "an aura seen in group 1 is recorded")
  group = 2
  assertf(seenHas(48168), "…and is still known in group 2")
  group = 1

  -- The swap itself has to reach the screen. This is the reported bug: nothing the viewers already
  -- listened for fires on a talent-group change, so old-spec abilities sat in the window looking
  -- castable until the player happened to drag one.
  --
  -- The group must move WITHOUT anything else touching the viewer, or the test proves nothing. A
  -- first version edited a list to set the scene and passed with the handler disabled, because
  -- SetSpellEnabled rebuilds the viewer itself — the scene-setting was doing the work the event was
  -- supposed to do.
  local ev = M.viewers.essential
  M.SetSpellEnabled("essential", 8092, false)      -- group 1 hides it; this rebuilds, by design
  local hidden = shownItems(ev)
  group = 2                                        -- group 2 has never hidden anything
  assertf(shownItems(ev) == hidden,
    "the viewer is stale immediately after a silent group change — nothing has told it")
  fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
  drain()
  assertf(shownItems(ev) == hidden + 1,
    "ACTIVE_TALENT_GROUP_CHANGED rebuilds it onto the other spec's layout, with no interaction")
  group = 1
  M.ResetTracking()
  ev:Rebuild()
  GetActiveTalentGroup = nil
  M.InvalidateCuratedCache()
end

print("\n=== CATEGORY GRIDS (Phase 4b-2) ===")
local A = CDS.adapter
assertf(A ~= nil, "adapter present")
-- Four on the Spells side since the equip port: Essential / Utility / Trinkets / Hidden. The
-- Trinkets pool is spells-only — see Equip.lua on why the passive pool is cut.
assertf(#A.MODE_ORDER.spells == 4 and #A.MODE_ORDER.auras == 3, "four spell categories, three aura")
assertf(A.IsSourcePool("equipActive") and not A.IsSourcePool("essential"),
        "only the equip pool is a source category")

-- The arsenal is what turns Hidden from an undo list into a picker.
assertf(M.ARSENAL_BY_CLASS ~= nil, "generated arsenal loaded")
assertf(#(M.ARSENAL_BY_CLASS.PRIEST or {}) > 15,
        "priest arsenal populated (" .. #(M.ARSENAL_BY_CLASS.PRIEST or {}) .. ")")

M.ResetCustomList("essential", "PRIEST")
M.ResetCustomList("utility", "PRIEST")
CDS.OpenTo("essential")

local ess = A.GetItems("essential", "PRIEST")
local hid = A.GetItems("hiddenSpell", "PRIEST")
assertf(#ess > 0, "Essential lists the curated spells (" .. #ess .. ")")
assertf(#hid > 0, "Hidden lists the rest of the arsenal (" .. #hid .. ")")

-- The two must not overlap: a placed spell is not offered again.
local placed = {}
for _, id in ipairs(ess) do placed[id] = true end
local overlap = 0
for _, id in ipairs(hid) do if placed[id] then overlap = overlap + 1 end end
assertf(overlap == 0, "Hidden excludes what is already placed (" .. overlap .. " overlaps)")

-- Grids built and stacked.
local grids = CDS._categories
assertf(grids.essential ~= nil and grids.hiddenSpell ~= nil, "spell category frames built")
assertf(grids.essential._count == #ess, "Essential grid holds every entry (" .. grids.essential._count .. ")")
assertf(grids.essential.items[1] ~= nil and grids.essential.items[1].spellID ~= nil, "tiles bound to spells")
assertf(sp.content:GetHeight() > 1, "scroll child sized to the stacked sections (" .. sp.content:GetHeight() .. ")")

-- Collapsing must resize, or the scrollbar range goes stale.
local tallExpanded = grids.essential:GetHeight()
grids.essential:Toggle()
assertf(grids.essential:GetHeight() < tallExpanded, "collapsing a section shrinks it")
grids.essential:Toggle()

-- Search dims rather than reflows, so positions stay put while typing.
CDS.ApplyItemFilter("zzzznomatch")
local dimmed = grids.essential.items[1]:GetAlpha()
assertf(dimmed < 1, "non-matching tiles dim (" .. dimmed .. ")")
CDS.ApplyItemFilter("")
assertf(grids.essential.items[1]:GetAlpha() == 1, "clearing the search restores them")

-- Moving a spell between categories, which is what 4b-3's menu will drive.
local moved = ess[1]
assertf(A.CanTarget("essential", "utility"), "essential -> utility is a legal move")
assertf(not A.CanTarget("essential", "trackedBar"), "cross-mode moves are illegal")
assertf(A.Assign(moved, "essential", "utility", "PRIEST"), "assign reports success")
local ess2 = A.GetItems("essential", "PRIEST")
local uti2 = A.GetItems("utility", "PRIEST")
local stillEss, nowUti = false, false
for _, id in ipairs(ess2) do if id == moved then stillEss = true end end
for _, id in ipairs(uti2) do if id == moved then nowUti = true end end
assertf(not stillEss, "moved spell left Essential")
assertf(nowUti, "…and arrived in Utility")
M.ResetCustomList("essential", "PRIEST")
M.ResetCustomList("utility", "PRIEST")

-- Aura categories read the tracked-aura pool. Phase 7b changed the CONTRACT here: an aura category
-- returns row TABLES, not bare spellIDs, because a row now has to carry the name it was assigned
-- under (rank-proofing) and whether the viewer or the player put it there.
CDS.SetDisplayMode("auras")
M.SetAuraAssignment("PRIEST", 10060, "bar")
CDS.RefreshLayout()
local bars = A.GetItems("trackedBar", "PRIEST")
local pinned
for _, row in ipairs(bars) do if row.spellID == 10060 then pinned = row end end
assertf(pinned ~= nil, "aura assigned to bars shows under Tracked Bars")
assertf(pinned and pinned.aura and pinned.assignment == "bar", "…as an explicit aura row")
assertf(pinned and not pinned.auto, "…not marked auto")
assertf(grids.trackedBar ~= nil and grids.trackedBar.kind == "bar", "bar category uses bar rows")
M.ResetTracking()
CDS.HidePanel()

print("\n=== ITEM MENU + COG (Phase 4b-3) ===")
-- Scoped: the menu tree is built and driven WITHOUT any UIDropDownMenu present. That separation is
-- the point of NE.menu.BuildRoot — menu content is logic and gets tested like logic; only the
-- rendering needs a client.
do
  local S  = NE.cooldownviewersettings
  local A2 = S.adapter
  local AL = M.alerts

  M.ResetTracking()
  M.ResetAlerts()
  S.OpenTo("essential")

  local tile = S._categories.essential.items[1]
  local sid  = tile and tile.spellID
  assertf(tile ~= nil and tile._catID == "essential", "tile carries its own category")

  -- The placeholder trap: ClassicAPI's search box READS BACK "Search" until the player types, and
  -- feeding that to the filter dimmed every tile in the panel to 25%.
  sp.search:SetText(SEARCH)
  S.RefreshLayout()
  assertf(S.GetSearchText() == "", "the idle search box reads as empty, not as \"Search\"")
  assertf(S._categories.essential.items[1]:GetAlpha() == 1, "…so tiles are not dimmed on open")

  local root = NE.menu.BuildRoot(S.ItemMenuGenerator(tile, "PRIEST"))
  assertf(root ~= nil, "item menu builds")
  assertf(root.children[1] and root.children[1].kind == "title", "…opening with the spell name")

  -- The reason core/Menu.lua uses ClassicAPI's dropdown rather than the native one: the native
  -- C_UIDROPDOWNMENU_MAXLEVELS is 2, and this menu needs three.
  local function depth(n)
    local d = 0
    for _, c in ipairs(n.children) do
      local cd = depth(c) + 1
      if cd > d then d = cd end
    end
    return d
  end
  assertf(depth(root) >= 3, "menu nests " .. depth(root) .. " levels — past the native 2-level cap")

  -- Ready sound: category submenu -> entry radio.
  local soundRoot = root:Child("Ready Sound")
  local animals   = soundRoot and soundRoot:Child("Animals")
  local catSound  = animals and animals:Child("Cat")
  assertf(catSound ~= nil, "sound catalogue nests category -> entry")
  local playedBefore = #SOUNDS_PLAYED
  catSound:Invoke()
  assertf(M.GetReadySoundKit(sid) == 316401, "selecting a sound writes the per-spell kit")
  assertf(#SOUNDS_PLAYED > playedBefore, "…and previews it")
  assertf(catSound.isSelected() == true, "its radio reads selected")
  assertf(soundRoot:Child("None").isSelected() == false, "…and None does not")

  -- Alerts. The FX list is GENERATED from AL.FX; upstream hardcodes 1 = ants / 6 = flash, and 6 has
  -- no renderer here, so a verbatim port would have written a dead value.
  local alertRoot = root:Child("Alert")
  local fxSub     = alertRoot and alertRoot:Child("FX Style")
  -- Every event says what it needs, so an event that cannot fire for this spell says so instead of
  -- sitting there inert. Refresh is the one that genuinely cannot, for a cooldown with no aura.
  local refreshEntry = alertRoot:Child("Refresh")
  assertf(refreshEntry ~= nil and refreshEntry.tipTitle == "Refresh", "Refresh carries an explanatory tooltip")
  assertf(refreshEntry.tipText:find("no aura", 1, true) ~= nil,
          "…naming the case where it can never trigger")
  assertf(alertRoot:Child("Available").tipText:find("every spell", 1, true) ~= nil,
          "Available says it works for everything")
  assertf(alertRoot:Child("Usable").tipTitle == "Usable", "Usable carries one too")

  assertf(fxSub ~= nil and #fxSub.children == #AL.FX,
          "FX submenu generated from AL.FX (" .. (fxSub and #fxSub.children or 0) .. " entries)")
  assertf(fxSub.children[1].text == AL.FX[1].name, "…using our names, not upstream's ants/flash pair")

  alertRoot:Child("Available"):Invoke()
  assertf(AL.GetType(sid) == "available", "alert type written")
  assertf(GLOWS[tile] ~= nil, "…and previewed on the tile itself")
  alertRoot:Child("Refresh Window"):Child("40%"):Invoke()
  assertf(math.abs(AL.GetWindow(sid) - 0.40) < 0.001, "refresh window stored as a fraction")

  -- The grid has to show its own state, or the only way to read it is to right-click every icon.
  assertf(tile.AlertBG ~= nil and tile.AlertBG:IsShown(), "configured tile shows the alert badge")
  GameTooltip:ClearLines()
  S._itemTooltipExtra(tile, GameTooltip)
  local tip = table.concat(GameTooltip.lines, "|")
  assertf(tip:find("Alert: available", 1, true) ~= nil, "tooltip names the configured alert")
  assertf(tip:find("Ready sound: Cat", 1, true) ~= nil, "tooltip names the configured sound")

  alertRoot:Child("None"):Invoke()
  soundRoot:Child("None"):Invoke()
  assertf(not tile.AlertBG:IsShown(), "badge clears when both go back to None")

  -- Moves. Done last: it rebuilds the grid under us.
  local mv = root:Child("Move to " .. A2.Label("utility"))
  assertf(mv ~= nil, "Move to Utility is offered")
  mv:Invoke()
  local arrived = false
  for _, id in ipairs(A2.GetItems("utility", "PRIEST")) do if id == sid then arrived = true end end
  assertf(arrived, "invoking the entry actually moved the spell")

  -- ── the render path ──────────────────────────────────────────────────────────────────────────
  -- Everything above drives the node tree. This drives core/Menu.lua's UIDropDownMenu translation,
  -- which is where both of the shipped menu faults lived.
  -- Re-read from the tile: the move above rebuilt the grid, so items[1] now holds a different
  -- spell than `sid`. The menu keys off whatever the tile currently carries.
  local shown = tile.spellID
  M.SetReadySoundKit(shown, 316406)   -- Chicken
  S.OnItemClick(tile, "RightButton")
  assertf(DD_ROWS[1] ~= nil and #DD_ROWS[1] > 0, "right-click renders a level-1 menu (" .. #(DD_ROWS[1] or {}) .. " rows)")

  local soundRow
  for _, row in ipairs(DD_ROWS[1]) do
    if row.text == "Ready Sound" then soundRow = row end
  end
  assertf(soundRow ~= nil and soundRow.hasArrow and soundRow.notClickable,
          "a submenu parent is hasArrow + notClickable, so OnClick cannot tick it")

  -- Walk two levels in, the way hovering the arrows does.
  local mf = NE.menu._frame
  C_UIDropDownMenu_Initialize(mf, mf.initialize, nil, 2, soundRow.menuList)
  local animalRow
  for _, row in ipairs(DD_ROWS[2] or {}) do if row.text == "Animals" then animalRow = row end end
  assertf(animalRow ~= nil, "level 2 lists the sound categories")

  C_UIDropDownMenu_Initialize(mf, mf.initialize, nil, 3, animalRow.menuList)
  local onCount, chickenOn = 0, false
  for _, row in ipairs(DD_ROWS[3] or {}) do
    if row.checked == true then
      onCount = onCount + 1
      if row.text == "Chicken" then chickenOn = true end
    end
  end
  assertf(#(DD_ROWS[3] or {}) > 3, "level 3 lists the sounds — past the native 2-level cap")
  assertf(onCount == 1 and chickenOn, "exactly the stored sound reads as selected (" .. onCount .. " ticked)")

  -- The invariant behind that: never hand UIDropDownMenu a predicate. Checked at every rendered
  -- level, because level 1 holds no radios at all and would pass this vacuously.
  local fnChecked = 0
  for lvl = 1, 3 do
    for _, row in ipairs(DD_ROWS[lvl] or {}) do
      if type(row.checked) == "function" then fnChecked = fnChecked + 1 end
    end
  end
  assertf(fnChecked == 0, "info.checked is never a function — the client mis-reads those (" .. fnChecked .. ")")
  M.SetReadySoundKit(shown, nil)
  NE.menu.Close()

  -- Cog menu.
  local cog = NE.menu.BuildRoot(S.SettingsMenuGenerator)
  local su  = cog:Child("Show Unlearned")
  assertf(su ~= nil and su.kind == "checkbox", "cog menu carries Show Unlearned as a checkbox")
  local wasUnlearned = M.GetShowUnlearned()
  su:Invoke()
  assertf(M.GetShowUnlearned() ~= wasUnlearned, "toggling it flips the stored option")
  su:Invoke()

  POPUPS_SHOWN = {}
  cog:Child("Clear All Alerts"):Invoke()
  assertf(POPUPS_SHOWN[1] == "NE_CDM_RESET_ALERTS", "destructive cog entries confirm before acting")
  AL.SetType(sid, "available")
  StaticPopupDialogs["NE_CDM_RESET_ALERTS"].OnAccept()
  assertf(AL.GetType(sid) == nil, "…and confirming clears them")

  M.ResetTracking()
  M.ResetAlerts()
  S.HidePanel()
end

print("\n=== DRAG REORDER (Phase 4b-4) ===")
do
  local S  = NE.cooldownviewersettings
  local A2 = S.adapter

  M.ResetTracking()
  S.OpenTo("essential")

  local ess2 = S._categories.essential
  local a, b = ess2.items[1], ess2.items[2]
  assertf(a and b and a.spellID ~= b.spellID, "two distinct tiles to drag between")

  -- Order is the editable list's order, so assert on that rather than on tile positions.
  local function orderOf(cat)
    local out = {}
    for _, e in ipairs(M.GetEditableList(cat, "PRIEST") or {}) do out[#out + 1] = e.spellID end
    return out
  end
  local function indexIn(list, id)
    for i, v in ipairs(list) do if v == id then return i end end
  end

  local first, second = a.spellID, b.spellID
  assertf(indexIn(orderOf("essential"), first) < indexIn(orderOf("essential"), second),
          "tile 1 sorts before tile 2 to start with")

  -- One drag: press, hover the target's right half, release, step the driver each time.
  local function drag(source, target, cursorX, cursorY, cancel)
    MOUSE_DOWN.LeftButton, MOUSE_DOWN.RightButton = true, false
    S.BeginDrag(source)
    local df = S._dragFrame
    MOUSE_FOCUS = target
    CURSOR.x, CURSOR.y = cursorX, cursorY
    S._dragOnUpdate(df)                       -- hover: picks the target and the caret side
    if cancel then
      MOUSE_DOWN.RightButton = true
    else
      MOUSE_DOWN.LeftButton = false           -- release
    end
    S._dragOnUpdate(df)                       -- the transition the missing GLOBAL_MOUSE_UP replaces
    MOUSE_DOWN.RightButton = false
    MOUSE_FOCUS = nil
  end

  b._center = { 100, 100 }
  b._w, b._h = 38, 38

  MOUSE_DOWN.LeftButton = true
  S.BeginDrag(a)
  assertf(S._dragState.active, "drag begins")
  assertf(a:GetAlpha() == 0.5, "…and locks the source tile")
  S.CancelDrag()
  assertf(not S._dragState.active and a:GetAlpha() == 1, "cancel restores it")

  -- Right of the target's centre = drop AFTER it.
  drag(a, b, 140, 100)
  local after = orderOf("essential")
  assertf(not S._dragState.active, "releasing the button ends the drag (no GLOBAL_MOUSE_UP here)")
  assertf(indexIn(after, first) == indexIn(after, second) + 1,
          "dropping right of a tile lands immediately after it")

  -- …and left of centre drops BEFORE, which is where the off-by-one lives: removing the entry
  -- first shifts everything below it up, so an index captured beforehand overshoots.
  local c = S._categories.essential.items[1]
  local d = S._categories.essential.items[3]
  if c and d and c.spellID ~= d.spellID then
    d._center, d._w, d._h = { 200, 100 }, 38, 38
    local moved, anchor = c.spellID, d.spellID
    drag(c, d, 180, 100)                       -- left of d's centre → before
    local ord = orderOf("essential")
    assertf(indexIn(ord, moved) == indexIn(ord, anchor) - 1,
            "dropping left of a tile lands immediately before it")
  end

  -- Right-click mid-drag cancels without committing.
  local ordBefore = table.concat(orderOf("essential"), ",")
  local e, f2 = S._categories.essential.items[1], S._categories.essential.items[4]
  if e and f2 then
    f2._center, f2._w, f2._h = { 300, 100 }, 38, 38
    drag(e, f2, 340, 100, true)
    assertf(table.concat(orderOf("essential"), ",") == ordBefore, "right-click mid-drag commits nothing")
    assertf(e:GetAlpha() == 1, "…and unlocks the source")
  end

  -- Cross-category: legality is the adapter's, and an illegal target must not commit.
  assertf(not A2.CanTarget("essential", "trackedBar"), "essential -> Tracked Bars stays illegal")
  local hop = S._categories.essential.items[1].spellID
  assertf(A2.AssignAt(hop, "essential", "utility", nil, 0, "PRIEST"), "AssignAt moves across categories")
  local uti = {}
  for _, e2 in ipairs(M.GetEditableList("utility", "PRIEST") or {}) do
    if e2.enabled then uti[#uti + 1] = e2.spellID end
  end
  assertf(indexIn(uti, hop) ~= nil, "…and the spell arrives in the destination list")

  -- Closing the window mid-drag must not strand the cursor icon or a dimmed tile.
  local g = S._categories.essential.items[1]
  MOUSE_DOWN.LeftButton = true
  S.BeginDrag(g)
  S.HidePanel()
  assertf(not S._dragState.active and g:GetAlpha() == 1, "closing the panel mid-drag clears the drag")
  MOUSE_DOWN.LeftButton = false

  M.ResetTracking()
end

print("\n=== EQUIP: ON-USE TRINKETS (Phase 5a) ===")
do
  local S  = NE.cooldownviewersettings
  local A2 = S.adapter

  M.ResetTracking()
  EQUIPPED[13], EQUIPPED[14] = nil, nil
  ITEM_SPELLS = {}

  -- Nothing equipped: no rows, and — the part that matters for the panel — no section either.
  assertf(#M.GetEquipActiveItems() == 0, "no trinkets equipped -> empty discovery")
  S.OpenTo("essential")
  assertf(not (S._categories.equipActive and S._categories.equipActive._active),
          "…and the Trinkets section is not shown at all")

  -- One on-use trinket (45148 has a use spell), one proc trinket (37220 has none).
  EQUIPPED[13], EQUIPPED[14] = 45148, 37220
  ITEM_SPELLS[45148] = { "Speed", 60313 }

  local pool = M.GetEquipActiveItems()
  assertf(#pool == 1, "only the trinket WITH a use spell is discovered (" .. #pool .. " of 2)")
  assertf(pool[1].token == "item:45148", "…keyed by a stable item token")
  assertf(pool[1].spellID == 60313 and pool[1].label == "Speed", "…carrying the use spell and its name")

  -- Unassigned is the default, and the source pool is where it lands.
  assertf(M.GetEquipAssignment("item:45148") == nil, "a newly discovered trinket is unassigned")
  local src = A2.GetItems("equipActive", "PRIEST")
  assertf(#src == 1 and type(src[1]) == "table", "the source pool returns it as an ENTRY table")
  assertf(#M.GetEquipItemsForCategory("essential") == 0, "…and no viewer claims it yet")

  -- The panel renders it as a real tile with the item icon, not a spell tile.
  S.RefreshLayout()
  local eq = S._categories.equipActive
  assertf(eq and eq._active and eq._count == 1, "the Trinkets section appears once something is in it")
  local tile = eq.items[1]
  assertf(tile.token == "item:45148", "the tile carries the token")
  assertf(tile._iconItemID == 45148, "…and the item id, which is what drives the icon and tooltip")

  -- Placing it. This is a token move, NOT a spellID move: routing it through Assign would write the
  -- use-spell into the editable list, which survives unequipping the trinket and points at nothing.
  assertf(A2.CanTarget("equipActive", "essential"), "trinkets may move into Essential")
  assertf(not A2.CanTarget("essential", "equipActive"), "…but nothing moves back INTO the pool")
  assertf(A2.Assign(60313, "equipActive", "essential", "PRIEST") == false,
          "the spellID path refuses a source-pool row outright")

  assertf(A2.AssignEquip("item:45148", "equipActive", "essential"), "AssignEquip places it")
  assertf(M.GetEquipAssignment("item:45148") == "essential", "…persisting the assignment")
  assertf(#M.GetEquipItemsForCategory("essential") == 1, "…and the live viewer now sources it")
  assertf(#M.GetEquipItemsForCategory("utility") == 0, "…only that viewer")

  -- The editable spell list must NOT have grown: the whole point of the token path.
  local listed = false
  for _, e in ipairs(M.GetEditableList("essential", "PRIEST") or {}) do
    if e.spellID == 60313 then listed = true end
  end
  assertf(not listed, "placing a trinket adds nothing to the editable spell list")

  -- It now renders under Essential instead, and the source pool is empty and gone again.
  S.RefreshLayout()
  assertf(not (S._categories.equipActive and S._categories.equipActive._active),
          "an emptied source pool disappears again")
  local essTiles = S._categories.essential
  local found
  for i = 1, essTiles._count do
    if essTiles.items[i].token == "item:45148" then found = essTiles.items[i] end
  end
  assertf(found ~= nil, "the trinket now renders under Essential")

  -- Hidden is STORED, and storable-ness is the whole reason it is distinct from unassigned.
  assertf(A2.AssignEquip("item:45148", "essential", "hiddenSpell"), "it can be moved to Hidden")
  assertf(M.GetEquipAssignment("item:45148") == "hidden", "…which stores 'hidden', not nil")
  assertf(#A2.GetItems("equipActive", "PRIEST") == 0, "…so it does NOT fall back into the source pool")

  -- Unequipping drops it from discovery entirely; the stored assignment survives for the re-equip.
  EQUIPPED[13] = nil
  assertf(#M.GetEquipActiveItems() == 0, "unequipping removes it from discovery")
  EQUIPPED[13] = 45148
  assertf(M.GetEquipAssignment("item:45148") == "hidden", "…and re-equipping restores the choice")

  -- Dragging a trinket out of the pool goes through the token path too.
  A2.AssignEquip("item:45148", nil, nil)     -- back to unassigned
  S.RefreshLayout()
  local poolTile = S._categories.equipActive.items[1]
  local dest = S._categories.utility
  MOUSE_DOWN.LeftButton, MOUSE_DOWN.RightButton = true, false
  S.BeginDrag(poolTile)
  assertf(S._dragState.active and S._dragState.token == "item:45148",
          "a drag from the source pool carries the token, not a spellID")
  MOUSE_FOCUS = dest.items[1]
  dest.items[1]._center, dest.items[1]._w, dest.items[1]._h = { 100, 100 }, 38, 38
  CURSOR.x, CURSOR.y = 140, 100
  S._dragOnUpdate(S._dragFrame)
  MOUSE_DOWN.LeftButton = false
  S._dragOnUpdate(S._dragFrame)
  MOUSE_FOCUS = nil
  assertf(M.GetEquipAssignment("item:45148") == "utility", "dropping it on Utility assigns it there")

  -- Tile pooling: a tile that held a trinket must not keep the token when it is handed a spell.
  -- Find the tile that ACTUALLY holds it — the trinket is appended after the spells, so items[1] is
  -- a spell tile and asserting on that would pass no matter what SetSpell does.
  local reused
  local utiCat = S._categories.utility
  for i = 1, utiCat._count do
    if utiCat.items[i].token == "item:45148" then reused = utiCat.items[i] end
  end
  assertf(reused ~= nil, "the trinket has a tile under Utility to reuse")
  reused:SetSpell(8092)
  assertf(reused.token == nil and reused._iconItemID == nil,
          "reusing an equip tile for a spell drops the stale equip binding")

  -- ResetTracking clears placement, so a reset really does return to the starter state.
  M.ResetTracking()
  assertf(M.GetEquipAssignment("item:45148") == nil, "ResetTracking returns trinkets to the pool")

  EQUIPPED[13], EQUIPPED[14] = nil, nil
  ITEM_SPELLS = {}
  S.HidePanel()
  M.ResetTracking()
end

print("\n=== LAYOUTS / IMPORT-EXPORT (Phase 4b-5) ===")
do
  local S  = NE.cooldownviewersettings
  local P  = S.presets
  local A2 = S.adapter

  assertf(P ~= nil, "presets module present")
  M.ResetTracking()
  S.OpenTo("essential")

  -- ── Snapshot / restore, which the undo and every layout apply share ──
  local moved = S._categories.essential.items[1].spellID
  local snap = S.SnapshotState()
  assertf(type(snap) == "table" and snap.class == "PRIEST", "snapshot records the class it was taken on")

  local function inUtility(id)
    for _, e in ipairs(M.GetEditableList("utility", "PRIEST") or {}) do
      if e.spellID == id and e.enabled then return true end
    end
    return false
  end

  A2.Assign(moved, "essential", "utility", "PRIEST")
  assertf(inUtility(moved), "an edit lands")
  assertf(S.RestoreState(snap), "restore accepts the snapshot")
  assertf(not inUtility(moved), "…and puts the edit back")

  -- ── Named layouts ──
  assertf(#P.Names() == 0, "no layouts to start with")
  assertf(P.SaveAs("Raid"), "saving a layout")
  assertf(P.Current() == "Raid", "…selects it")
  assertf(#P.Names() == 1 and P.Names()[1] == "Raid", "…and lists it")

  -- Edit, then save a second layout capturing that edit.
  A2.Assign(moved, "essential", "utility", "PRIEST")
  assertf(P.SaveAs("PvP"), "a second layout captures the edited state")
  -- Alphabetical, not insertion order: the menu is a list the player scans by name.
  assertf(P.Names()[1] == "PvP" and P.Names()[2] == "Raid", "names come back sorted")

  -- Applying a layout REPLACES state rather than merging into it — the whole point of a layout.
  assertf(P.Apply("Raid"), "applying the first layout")
  assertf(not inUtility(moved), "…restores its state, dropping the later edit")
  assertf(P.Apply("PvP") and inUtility(moved), "applying the second brings the edit back")

  -- One-step undo. It reverts the APPLY, and it restores the selected-layout name with it.
  assertf(S.CanRevert(), "an apply arms Revert")
  assertf(S.Revert(), "revert runs")
  assertf(not inUtility(moved), "…undoing the apply")
  assertf(P.Current() == "Raid", "…and restoring the layout that was selected before it")
  assertf(not S.CanRevert(), "revert is one step, so it disarms itself")

  assertf(P.Rename("Raid", "Raid 2"), "rename")
  assertf(P.Current() == "Raid 2", "…follows the selection")
  assertf(P.Delete("Raid 2"), "delete")
  assertf(P.Current() == nil, "…clears the selection when it was the selected one")

  -- ── The codec ──
  -- Round-trip through the real share string, not through the table.
  P.SaveAs("Export Me")
  local str = P.Encode(S.SnapshotState())
  assertf(str:sub(1, 6) == "NECDM1", "a share string is tagged")
  assertf(not str:find("[^%w%+/=]"), "…and is single-line paste-safe base64")

  local back = P.Decode(str)
  assertf(type(back) == "table" and back.class == "PRIEST", "it decodes back to a snapshot")
  -- Compare a real nested value, not just the shape: the serializer is length-prefixed and the
  -- table tag carries a pair count, so a nesting bug shows up here and nowhere else.
  local origList = S.SnapshotState().customLists
  local sameShape = (type(back.customLists) == "table")
  if sameShape and origList and origList.utility and origList.utility.PRIEST then
    sameShape = type(back.customLists.utility) == "table"
      and type(back.customLists.utility.PRIEST) == "table"
      and #back.customLists.utility.PRIEST == #origList.utility.PRIEST
  end
  assertf(sameShape, "…with the nested per-class spell lists intact")

  -- Bad input never errors and never executes. Each of these is a distinct failure path.
  local _, e1 = P.Decode("")                    assertf(e1 ~= nil, "empty paste is rejected with a reason")
  local _, e2 = P.Decode("hello world")         assertf(e2 ~= nil, "a non-layout string is rejected")
  local _, e3 = P.Decode("NECDM1!!!!not b64")   assertf(e3 ~= nil, "corrupt payload is rejected, not raised")
  -- The parser must never be handed to loadstring: a payload that WOULD be valid Lua returning a
  -- table still has to fail, because we never evaluate it.
  local ok4 = P.Decode("NECDM1" .. "cmV0dXJuIHtjbGFzcz0iUFJJRVNUIn0=")
  assertf(ok4 == nil, "a payload that is valid Lua is still not executed")

  -- A length prefix that runs past the end of the payload. This is the one bad-input case that
  -- string.sub's clamping would otherwise let through SILENTLY: `t1;s5:class` + `s99:PRIEST` parses
  -- as { class = "PRIEST" } — a well-formed layout built from a truncated read — and every later
  -- check (is it a table, is .class a string, does the class match) then passes. The control below
  -- is the same payload with the correct length, to prove the rejection is about the length and not
  -- about the shape.
  local good = P.Decode("NECDM1" .. "dDE7czU6Y2xhc3NzNjpQUklFU1Q=")
  assertf(type(good) == "table" and good.class == "PRIEST", "a hand-built minimal layout decodes")
  local bad, e5 = P.Decode("NECDM1" .. "dDE7czU6Y2xhc3NzOTk6UFJJRVNU")
  assertf(bad == nil and e5 ~= nil, "…but an over-long string length is rejected, not silently truncated")

  -- A declared pair count is attacker-controlled, so a header claiming a billion pairs is the
  -- obvious denial-of-service shape. The parser needs no cap for it: every iteration must consume at
  -- least one byte of payload or raise, so the loop is self-limiting and this fails on the first
  -- pair. Asserting it here is what lets the cap stay OUT of parseValue instead of sitting there as
  -- an unreachable guard. base64("t999999999;").
  local _, e7 = P.Decode("NECDM1" .. "dDk5OTk5OTk5OTs=")
  assertf(e7 ~= nil, "a table header claiming a billion pairs fails on the first one")

  -- The class gate upstream lacks: another class's layout is refused with a reason that names it,
  -- rather than silently writing into that class's slot and appearing to do nothing.
  local mageSnap = S.SnapshotState()
  mageSnap.class = "MAGE"
  local nope, e6 = P.Decode(P.Encode(mageSnap))
  assertf(nope == nil and (e6 or ""):find("MAGE"), "another class's layout is refused by name")

  -- ── Starter reset ──
  A2.Assign(moved, "essential", "utility", "PRIEST")
  if M.SetReadySoundKit then M.SetReadySoundKit(8092, 1) end
  assertf(P.UseStarter(), "starter reset runs")
  assertf(not inUtility(moved), "…reverting the spell lists")
  assertf(not (M.GetReadySoundKit and M.GetReadySoundKit(8092)), "…and clearing the sounds")
  assertf(P.Current() == nil, "…leaving no layout selected")
  assertf(S.CanRevert(), "…but it is undoable")

  -- Closing the panel drops the undo: reverting an hour-old change is not an undo.
  S.HidePanel()
  assertf(not S.CanRevert(), "closing the panel clears the undo")

  M.ResetTracking()
end

print("\n=== SETTINGS TAB (Phase 4c) ===")
do
  local S = NE.cooldownviewersettings
  local panel = S.panel or S.Build()

  -- Laziness first, before anything opens the tab: ~60 frames a player who never opens it should not
  -- pay for. Every earlier block has opened this panel, so a page built at panel-build time would
  -- already exist here.
  assertf(S.settingsColumn == nil, "the settings page is not built until its tab is opened")

  S.ShowPanel()
  assertf(#panel.tabButtons == 3, "the panel carries three side tabs (" .. #panel.tabButtons .. ")")

  S.SetDisplayMode("settings")
  assertf(S.GetDisplayMode() == "settings", "the settings tab selects")
  local col = S.settingsColumn
  assertf(col ~= nil, "…and builds the page on that first switch")
  assertf(panel.scroll:GetScrollChild() == panel.settingsContent,
          "…swapping the scroll child to the settings page")
  assertf(panel.settingsContent:IsShown() and not panel.content:IsShown(),
          "…and showing exactly one of the two bodies")

  -- The chrome that belongs to the GRIDS goes away: the search box dims non-matching tiles and the cog
  -- holds Show Unlearned. A search box that silently does nothing is worse than an absent one.
  assertf(not panel.search:IsShown(), "the search box hides on the settings tab")
  assertf(not panel.settingsCog:IsShown(), "…as does the cog")
  -- Same for the footer: a layout captures spell lists, auras, trinket placement, alerts and sounds —
  -- not viewer geometry — so leaving it under a page of icon sliders would imply it saves them.
  assertf(not panel.layoutButton:IsShown() and not panel.revertButton:IsShown(),
          "…and the layout footer, which does not cover viewer geometry")

  -- Find a control by the section it lives in plus its own label. Scoping by section matters: "Icon
  -- size" exists four times, once per viewer, and an unscoped search would silently always answer with
  -- Essential's — so a test meaning to prove Buff Bars' slider works would prove nothing.
  local function findRow(sectionTitle, labelText)
    for _, e in ipairs(col.entries) do
      local f = e.frame
      local inSection = (not sectionTitle) or (e.section and e.section.title == sectionTitle)
      if inSection and f.Label and f.Label:GetText() == labelText then return f, e end
    end
    return nil
  end
  local function findSection(title)
    for _, s in ipairs(col.sections) do
      if s.title == title then return s end
    end
    return nil
  end

  -- ── Sliders ──
  local size = findRow("Essential Cooldowns", "Icon size")
  assertf(size ~= nil, "Essential has an Icon size slider")
  size.Slider:SetValue(150)
  assertf(M.GetOpt("CooldownViewerEssential", "iconSize") == 150, "moving it writes the viewer's opt")
  assertf(size.Value:GetText() == "150%", "…and the row shows the value with its unit")

  -- SetObeyStepOnDrag is retail-only, so the step is applied on the way in. 137 is inside the 140 step.
  size.Slider:SetValue(137)
  assertf(M.GetOpt("CooldownViewerEssential", "iconSize") == 140, "a between-steps value snaps to a step")
  assertf(size.Slider:GetValue() == 140, "…and the thumb re-seats on the snapped value")

  -- A drag fires OnValueChanged continuously, and every write re-runs the viewer's RefreshLayout, which
  -- relays out every icon. Only a change that crosses into the next step may write.
  local writes = 0
  local realSetOpt = M.SetOpt
  M.SetOpt = function(...) writes = writes + 1; return realSetOpt(...) end
  local onValue = size.Slider:GetScript("OnValueChanged")
  onValue(size.Slider, 142)
  onValue(size.Slider, 138)
  assertf(writes == 0, "a drag that stays inside one step writes nothing (" .. writes .. ")")
  onValue(size.Slider, 148)
  assertf(writes == 1, "…and crossing into the next step writes exactly once (" .. writes .. ")")
  M.SetOpt = realSetOpt

  -- ── Checkboxes ──
  local timer = findRow("Essential Cooldowns", "Show timer")
  local was = M.GetOpt("CooldownViewerEssential", "showTimer") and true or false
  -- Clicking the ROW, not the box: the label is the bigger target and has to work.
  timer:GetScript("OnClick")(timer)
  assertf((M.GetOpt("CooldownViewerEssential", "showTimer") and true or false) ~= was,
          "clicking a checkbox row flips the setting")
  assertf((timer.Check:GetChecked() and true or false) ~= was, "…and repaints the box")
  -- The box's own path. UICheckButtonTemplate flips its state before OnClick runs on the real client;
  -- the stub has no template, so the flip is done here to reproduce what the handler is handed.
  timer.Check:SetChecked(was)
  timer.Check:GetScript("OnClick")(timer.Check)
  assertf((M.GetOpt("CooldownViewerEssential", "showTimer") and true or false) == was,
          "…and clicking the box itself agrees with it")

  -- ── Dropdowns ──
  local vis = findRow("Essential Cooldowns", "Visibility")
  local root = NE.menu.BuildRoot(vis.MenuGenerator)
  assertf(#root.children == 3, "Visibility offers three choices")
  -- ORDERED, not sorted: alphabetical would put Hidden second. "Always / In Combat / Hidden" is a
  -- progression, which is the whole reason the kit takes an array where the options tab takes a map.
  assertf(root.children[1].text == "Always" and root.children[2].text == "In Combat",
          "…in the order written, not alphabetised")
  root:Child("In Combat"):Invoke()
  assertf(M.GetOpt("CooldownViewerEssential", "visibleSetting") == "incombat",
          "choosing one writes the viewer's opt")
  assertf(vis.Button:GetText() == "In Combat", "…and the button relabels to the choice")

  -- ── Which controls each viewer gets ──
  -- Hide When Inactive is only OFFERED where it does something: retail's Essential/Utility templates
  -- do not set allowHideWhenInactive, so UpdateShownState ignores it there. The options tab used to ship
  -- the control with a description explaining it was inert.
  assertf(findRow("Essential Cooldowns", "Hide when inactive") == nil,
          "Essential has no Hide when inactive control, because it would do nothing")
  assertf(findRow("Buff Icons", "Hide when inactive") ~= nil, "…but Buff Icons does")
  assertf(findRow("Buff Bars", "Bar width") ~= nil, "the bar-only settings appear on Buff Bars")
  assertf(findRow("Buff Icons", "Bar width") == nil, "…and nowhere else")

  -- ── Collapsible sections ──
  local track = findSection("Buff tracking")
  local auto  = findRow("Buff tracking", ("Auto-track buffs under %ds"):format(M.BUFF_TRACK_MAX_DURATION))
  assertf(track ~= nil and auto ~= nil, "the Buff tracking section exists")
  assertf(not track.expanded and not auto:IsShown(), "…collapsed, with its rows hidden")
  local shortH = panel.settingsContent:GetHeight()
  track.header:GetScript("OnClick")(track.header)
  assertf(track.expanded and auto:IsShown(), "clicking the header expands it")
  assertf(panel.settingsContent:GetHeight() > shortH, "…and the scroll child grows to match")

  -- ── The page is not the only writer ──
  -- A layout apply, a reset, or DragonUI's master toggle can all move a value underneath this page. A
  -- control that only ever wrote would drift, and a stale checkbox reads exactly like a setting that
  -- failed to apply.
  M.SetOpt("CooldownViewerEssential", "iconSize", 90)
  S.RefreshSettingsPage()
  assertf(size.Slider:GetValue() == 90 and size.Value:GetText() == "90%",
          "a change made elsewhere shows up on the next page refresh")

  -- ── The settings tab leaves the grids alone ──
  -- The panel refreshes on SPELL_UPDATE_ICON / GET_ITEM_INFO_RECEIVED / UNIT_INVENTORY_CHANGED while
  -- shown. Without the mode guard, each of those would deactivate every category behind a page the
  -- player is not looking at, and MODE_ORDER has no "settings" entry to re-activate them from.
  S.SetDisplayMode("spells")
  local ess = S._categories.essential
  assertf(ess ~= nil and ess._active, "the spells tab populates its categories")
  S.SetDisplayMode("settings")
  S.RefreshLayout()
  assertf(ess._active, "RefreshLayout on the settings tab does not tear the grids down")

  -- ── Switching back restores everything ──
  S.SetDisplayMode("spells")
  assertf(panel.scroll:GetScrollChild() == panel.content, "the spells tab swaps the grid body back in")
  assertf(panel.search:IsShown() and panel.settingsCog:IsShown() and panel.layoutButton:IsShown(),
          "…and brings the grid chrome back")

  -- ── The DragonUI options section is now two controls ──
  local rec = { toggles = {}, buttons = {}, sliders = 0, drops = 0, headings = 0 }
  local C = {}
  function C:AddSpacer() end
  function C:AddHeading() rec.headings = rec.headings + 1 end
  function C:AddDescription() end
  function C:AddToggle(_, o) rec.toggles[#rec.toggles + 1] = o end
  function C:AddButton(_, o) rec.buttons[#rec.buttons + 1] = o end
  -- Recorded rather than omitted: a builder that still reached for these would error out and take the
  -- whole run with it, which says less than a count does.
  function C:AddSlider() rec.sliders = rec.sliders + 1 end
  function C:AddDropdown() rec.drops = rec.drops + 1 end

  NE.optionSections[1].build({}, C)
  assertf(#rec.toggles == 1, "the DragonUI section renders one toggle (" .. #rec.toggles .. ")")
  assertf(#rec.buttons == 1, "…and one button (" .. #rec.buttons .. ")")
  assertf(rec.sliders == 0 and rec.drops == 0,
          "…and no viewer settings at all (" .. rec.sliders .. " sliders, " .. rec.drops .. " dropdowns)")

  assertf(rec.toggles[1].getFunc() == M.IsEnabled(), "its toggle reads the master enable")
  rec.toggles[1].setFunc(false)
  assertf(M.IsEnabled() == false, "…and writes it")
  assertf(not M.viewers.essential:IsShown(), "…which hides the viewers immediately, no reload")
  rec.toggles[1].setFunc(true)

  S.HidePanel()
  rec.buttons[1].callback()
  assertf(panel:IsShown() and S.GetDisplayMode() == "settings",
          "its button opens /cdm on the Settings tab")

  -- ── "Position this viewer" (Phase 6: §G.4's last undecided item) ──
  S.SetDisplayMode("settings")
  local posRow
  for _, e in ipairs(col.entries) do
    local f = e.frame
    if f.Button and f.Button:GetText() == "Position this viewer"
      and e.section and e.section.title == "Essential Cooldowns" then
      posRow = f
    end
  end
  assertf(posRow ~= nil, "each viewer section carries a Position this viewer button")

  -- In combat it must refuse AND leave the window up. Hiding the panel first and then failing would
  -- take away the only place the reason could be read.
  local realCombat = InCombatLockdown
  InCombatLockdown = function() return true end
  DragonUI.EditorMode._active, DragonUI._selected = false, nil
  S.ShowPanel()
  posRow.Button:GetScript("OnClick")(posRow.Button)
  assertf(not DragonUI.EditorMode:IsActive(), "Position refuses to open the editor in combat")
  assertf(S.panel:IsShown(), "…and leaves the settings window up to say why")
  -- The REASON, not just the refusal. EditorMode:Show() already no-ops in combat and the IsActive
  -- re-check would catch that on its own, so the explicit combat branch earns its place only by naming
  -- combat: "editor mode declined to open" mid-fight tells the player nothing to act on.
  local okc, whyc = NE.OpenFrameEditor(M.viewers.essential)
  assertf(okc == false and (whyc or ""):lower():find("combat") ~= nil,
          "…and the reason names combat rather than a generic refusal (" .. tostring(whyc) .. ")")
  InCombatLockdown = realCombat

  -- Out of combat: the editor opens, the panel closes, and the frame handed to SelectEditorFrame is
  -- the ANCHOR. This is the trap the whole helper exists for — RegisterHUDFrame registers the
  -- CreateUIFrame anchor and hangs the viewer off it, so selecting the viewer itself would put the
  -- editor's coordinate readout and Reset button on a frame it cannot move, and it would look fine.
  posRow.Button:GetScript("OnClick")(posRow.Button)
  local anchor = DragonUI.EditableFrames["CooldownViewerEssential"].frame
  assertf(DragonUI.EditorMode:IsActive(), "out of combat it opens the editor")
  assertf(DragonUI._selected == anchor, "…selecting the registered anchor")
  assertf(DragonUI._selected ~= M.viewers.essential, "…and NOT the viewer frame hung off it")
  assertf(M.viewers.essential.editorAnchor == anchor, "…which is what .editorAnchor points at")
  assertf(not S.panel:IsShown(), "…and closes the settings window, which would cover the viewer")
  DragonUI.EditorMode:Hide()

  -- A missing editor is a returned reason, not an error: some DragonUI builds have no EditorMode.
  local savedEM = DragonUI.EditorMode
  DragonUI.EditorMode = nil
  local ok6, why6 = NE.OpenFrameEditor(M.viewers.essential)
  assertf(ok6 == false and type(why6) == "string", "no editor mode reports a reason rather than erroring")
  DragonUI.EditorMode = savedEM

  -- Leave the store as we found it.
  for _, id in pairs(M.FRAME_ID) do M.ResetOpts(id) end
  S.SetDisplayMode("spells")
  S.HidePanel()
end

-- The /necdm diagnostic is ~70 lines of formatting that nothing else touches, including the §F1
-- widget probe. Run it once: a nil-format or a bad select() in there would otherwise only surface
-- when someone reached for it to debug something else.
print("\n=== TRACKED BUFFS: CATALOG + SEEN (Phase 7) ===")
do
  local S = NE.cooldownviewersettings
  local A7 = S.adapter
  local bIcon7 = M.viewers.buffIcon

  local function namesOf(rows)
    local t = {}
    for _, r in ipairs(rows) do t[(r.name or r.label or ""):lower()] = r end
    return t
  end

  -- ── 7d: the generated catalog ───────────────────────────────────────────────────────────────
  assertf(type(M.AURA_CATALOG_BY_CLASS) == "table", "CdmAuraCatalog loaded")
  local pri = M.AURA_CATALOG_BY_CLASS.PRIEST
  assertf(pri and #pri > 0, "PRIEST has catalog rows (" .. tostring(pri and #pri) .. ")")
  do
    local gated, malformed = 0, 0
    for _, e in ipairs(pri) do
      if e.talent then
        gated = gated + 1
        if not e.tree then malformed = malformed + 1 end
      end
      if not (e.id and e.name and e.dur) then malformed = malformed + 1 end
    end
    assertf(malformed == 0, "every row carries id/name/dur, and a gated row carries its tree")
    assertf(gated > 0, "…and some are spec-gated (" .. gated .. " of " .. #pri .. ")")
  end

  -- The gate FAILS OPEN when the talent API is silent. This is the guard that stops Phase 7 from
  -- reintroducing the very bug it fixes: an empty talent table read as "no talents" would hide
  -- every gated row on a client that simply had not answered yet.
  assertf(GetTalentInfo == nil, "the harness has no talent API, so the gate is unanswerable")
  M.InvalidateTalentCache()
  assertf(M.HasTalent("Serendipity"), "unanswerable gate offers the row rather than hiding it")
  assertf(#M.GetAuraCatalog("PRIEST") == #pri, "…so the whole catalog is offered")

  -- With a talent API present the gate is real.
  GetNumTalentTabs = function() return 3 end
  GetNumTalents    = function(tab) return (tab == 1) and 2 or 0 end
  GetTalentInfo    = function(tab, i)
    -- 3.3.5a flat tuple: name, icon, tier, column, rank, maxRank
    if tab == 1 and i == 1 then return "Borrowed Time", "icon", 1, 1, 3, 5 end
    if tab == 1 and i == 2 then return "Serendipity",   "icon", 1, 2, 0, 3 end
    return nil
  end
  M.InvalidateTalentCache()
  assertf(M.HasTalent("Borrowed Time"), "a talent with rank 3 reads as taken")
  assertf(not M.HasTalent("Serendipity"), "…one at rank 0 does not")
  local gatedCat = namesOf(M.GetAuraCatalog("PRIEST"))
  assertf(gatedCat["borrowed time"] ~= nil, "talented row is offered")
  assertf(gatedCat["serendipity"] == nil, "untalented row is withheld")
  assertf(gatedCat["fade"] ~= nil, "ungated row is always offered")
  assertf(gatedCat["shadow weaving"] == nil, "a talent the API never mentions is withheld too")

  -- Show Unlearned is the escape hatch: the gate is derived data, so there is a way past it.
  local shown = namesOf(M.GetAuraCatalog("PRIEST", true))
  assertf(shown["serendipity"] ~= nil, "Show Unlearned reveals the withheld row")

  -- ── 7a: the seen registry ───────────────────────────────────────────────────────────────────
  M.ResetTracking()
  BUFFS.player = {
    { name = "Inner Focus", rank = "", icon = "Interface\\Icons\\IF", count = 0,
      duration = 30, expiration = NOW + 25, spellID = 14751 },
    { name = "Arcane Intellect", rank = "Rank 3", icon = "Interface\\Icons\\AI", count = 0,
      duration = 1800, expiration = NOW + 1700, spellID = 10157 },
  }
  auraTick("player")
  local seen = {}
  for _, e in ipairs(M.GetSeenAuraList("PRIEST")) do seen[e.spellID] = e end
  assertf(seen[14751] ~= nil, "the scan records a short buff it met")
  assertf(seen[14751] and seen[14751].name == "Inner Focus" and seen[14751].dur == 30,
          "…with its name and duration, not just an id")
  assertf(seen[14751] and seen[14751].icon == "Interface\\Icons\\IF",
          "…and the icon, which is the only source for an aura with no spellbook entry")
  assertf(seen[10157] == nil, "a 1800s buff is NOT recorded (the window keeps food buffs out)")

  -- THE ONE-WAY DOOR. An aura hidden before it was ever seen must still be recorded, or hiding
  -- something removes the only row that could unhide it. This is why NoteSeenAura is called before
  -- ShouldTrackBuff rather than inside its true branch.
  --
  -- The aura has to be hidden BEFORE it first appears, and that is fiddlier than it looks:
  -- ResetTracking rebuilds the shown viewers itself, so an aura already up at that moment gets
  -- scanned — and recorded — while the pool is still empty. A first draft of this test did exactly
  -- that and passed with the guard removed. So: clear the auras, assign hidden, THEN raise it.
  -- Auras down BEFORE the reset, for the same reason: ResetTracking's rebuild would otherwise
  -- record whatever is still up as it clears. And through `settle`, not bare — NE.aura caches its
  -- snapshot per frame, so a rebuild in the same frame re-reads the auras that were up a moment ago
  -- however empty BUFFS.player now is.
  BUFFS.player = {}
  settle(M.ResetTracking)
  auraTick("player")
  assertf(#M.GetSeenAuraList("PRIEST") == 0, "nothing up, nothing recorded")
  M.SetAuraAssignment("PRIEST", 15286, "hidden", "Vampiric Embrace")
  BUFFS.player = {
    { name = "Vampiric Embrace", rank = "", icon = "Interface\\Icons\\VE", count = 0,
      duration = 60, expiration = NOW + 55, spellID = 15286 },
  }
  auraTick("player")
  local seen2 = {}
  for _, e in ipairs(M.GetSeenAuraList("PRIEST")) do seen2[e.spellID] = e end
  assertf(seen2[15286] ~= nil, "a HIDDEN aura is still recorded as seen (the one-way-door guard)")
  assertf(shownItems(bIcon7) == 0, "…while staying out of the viewer, which is what hidden means")
  assertf(namesOf(A7.GetItems("hiddenAura", "PRIEST"))["vampiric embrace"] ~= nil,
          "…so the row that could unhide it is still there")

  -- The cap, oldest evicted first.
  M.ResetTracking()
  M.NoteSeenAura(900001, "Oldest", "i", 10)
  nextFrame(10)
  for i = 2, 60 do M.NoteSeenAura(900000 + i, "Filler " .. i, "i", 10) end
  nextFrame(10)
  M.NoteSeenAura(999999, "Newest", "i", 10)
  local capped = {}
  local n = 0
  for _, e in ipairs(M.GetSeenAuraList("PRIEST")) do capped[e.spellID] = true; n = n + 1 end
  assertf(n == 60, "the registry caps at 60 (" .. n .. ")")
  assertf(capped[999999], "…keeping the newest")
  assertf(not capped[900001], "…and evicting the least recently seen")

  -- ── 7d runtime: matching by NAME, so an assignment survives rank ─────────────────────────────
  -- The payoff for the catalog storing rank-1 ids. The aura below is a DIFFERENT spellID from the
  -- assigned one and is far outside the auto window, so nothing but a name match can show it.
  M.ResetTracking()
  M.SetAuraAssignment("PRIEST", 10060, "icon", "Power Infusion")
  BUFFS.player = {
    { name = "Power Infusion", rank = "Rank 9", icon = "Interface\\Icons\\PI", count = 0,
      duration = 300, expiration = NOW + 280, spellID = 777777 },
  }
  auraTick("player")
  assertf(shownItems(bIcon7) == 1,
          "an assignment made at one rank matches the aura cast at another (" ..
          shownItems(bIcon7) .. ")")

  -- ── the DoT fix, which falls out of the registry becoming reachable at all ───────────────────
  local realExists = UnitExists
  UnitExists = function(u) return u == "player" or u == "target" end
  M.ResetTracking()
  M.SetAuraAssignment("PRIEST", 589, "icon", "Shadow Word: Pain")
  BUFFS.player = {}
  DEBUFFS.target = {
    { name = "Shadow Word: Pain", rank = "Rank 10", icon = "Interface\\Icons\\SWP", count = 0,
      duration = 18, expiration = NOW + 14, spellID = 25368 },
  }
  auraTick("player")
  assertf(shownItems(bIcon7) == 1,
          "an explicitly tracked DoT on the target now shows (" .. shownItems(bIcon7) .. ")")
  DEBUFFS.target = {}
  UnitExists = realExists

  -- ── 7b: where an unassigned candidate lands ──────────────────────────────────────────────────
  M.ResetTracking()
  M.SetAutoTrackBuffs(true)
  M.SetAutoTrackDest("both")
  local buffRows = namesOf(A7.GetItems("trackedBuff", "PRIEST"))
  local barRows  = namesOf(A7.GetItems("trackedBar", "PRIEST"))
  assertf(buffRows["fade"] ~= nil and barRows["fade"] ~= nil,
          "dest=both puts a candidate in BOTH aura sections")
  assertf(buffRows["fade"].auto, "…marked auto, because the viewer is deciding it")
  assertf(buffRows["fade"].assignment == nil, "…and with no stored assignment")

  M.SetAutoTrackDest("bar")
  assertf(namesOf(A7.GetItems("trackedBuff", "PRIEST"))["fade"] == nil,
          "dest=bar keeps candidates out of Tracked Buffs")
  assertf(namesOf(A7.GetItems("trackedBar", "PRIEST"))["fade"] ~= nil, "…and in Tracked Bars")

  -- Auto-track OFF: nothing is showing these, so Hidden is where they honestly belong.
  M.SetAutoTrackBuffs(false)
  assertf(namesOf(A7.GetItems("trackedBar", "PRIEST"))["fade"] == nil,
          "auto-track off empties the tracked sections of candidates")
  assertf(namesOf(A7.GetItems("hiddenAura", "PRIEST"))["fade"] ~= nil,
          "…and lists them under Hidden instead")
  M.SetAutoTrackBuffs(true)
  M.SetAutoTrackDest("both")

  -- An explicit assignment removes the candidate row, so a buff is never listed twice — matched by
  -- name, so a rank-1 catalog row and a differently-ranked assignment do not both appear.
  M.SetAuraAssignment("PRIEST", 999123, "bar", "Fade")
  local dupBar = A7.GetItems("trackedBar", "PRIEST")
  local fades = 0
  for _, r in ipairs(dupBar) do if (r.label or ""):lower() == "fade" then fades = fades + 1 end end
  assertf(fades == 1, "an assigned aura is listed once, not once per source (" .. fades .. ")")
  M.ResetTracking()

  -- The claim that pinning an auto row needs NO new write path: the drag already calls
  -- SetAuraAssignment, and "stop deciding this one for me" is exactly what that write means.
  local cand = M.GetAuraCandidates("PRIEST")[1]
  assertf(cand ~= nil and cand.name, "there is a candidate to drag (" .. tostring(cand and cand.name) .. ")")
  assertf(A7.Assign(cand.spellID, "trackedBar", "trackedBuff", "PRIEST"),
          "…and dragging it across is a legal move")
  local pinnedRow = namesOf(A7.GetItems("trackedBuff", "PRIEST"))[cand.name:lower()]
  assertf(pinnedRow and pinnedRow.assignment == "icon", "…which makes it an explicit icon row")
  assertf(pinnedRow and not pinnedRow.auto, "…no longer marked auto")
  local storedName
  for _, e in ipairs(M.GetTrackedAuraList("PRIEST") or {}) do
    if e.spellID == cand.spellID then storedName = e.name end
  end
  assertf(storedName == cand.name,
          "…and the write stored a NAME the drag never supplied, via ResolveAuraName")
  M.ResetTracking()

  -- ── 7b/7c: the tile and the empty state ──────────────────────────────────────────────────────
  S.OpenTo("auras")
  local barGrid = S._categories.trackedBar
  assertf(barGrid ~= nil and barGrid._count > 0, "the Tracked Bars grid is no longer empty")
  local tile7
  for i = 1, barGrid._count do
    if (barGrid.items[i].spellName or "") == "Fade" then tile7 = barGrid.items[i] end
  end
  assertf(tile7 ~= nil, "…and carries a named aura tile")
  assertf(tile7 and tile7._aura and tile7._aura.auto, "the tile knows it is an auto row")
  assertf(tile7 and tile7.Icon._desat == true, "…and reads as one (desaturated)")
  assertf(tile7 and tile7.token == nil,
          "…with no equip binding, so its right-click cannot route through the trinket path")

  assertf(A7.EmptyText("trackedBuff") ~= "(empty)",
          "an aura section's empty text is a sentence, not \"(empty)\"")
  assertf(A7.EmptyText("essential") == "(empty)", "…and other categories keep the terse form")

  S.HidePanel()
  GetNumTalentTabs, GetNumTalents, GetTalentInfo = nil, nil, nil
  M.InvalidateTalentCache()
  M.ResetTracking()
  BUFFS.player = {}
end

print("\n=== DIAGNOSTIC (/necdm) ===")
do
  local okDiag, errDiag = pcall(SlashCmdList["NECDM"])
  assertf(okDiag, "/necdm runs without erroring" .. (okDiag and "" or (": " .. tostring(errDiag))))
  assertf(M._widgetProbe ~= nil, "…and leaves its one throwaway Cooldown probe frame cached")
end

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
