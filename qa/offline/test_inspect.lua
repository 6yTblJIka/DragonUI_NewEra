-- qa/offline/test_inspect.lua — offline harness for the inspect window reskin (modules/inspect).
--
--   luajit qa/offline/test_inspect.lua        (from the addon root)
--
-- What this covers that a syntax gate cannot: the module is almost entirely ANCHOR and VISIBILITY
-- arithmetic against a frame tree nobody can see until a player right-clicks a stranger. The stub
-- below is that tree, transcribed from the real 3.3.5a Blizzard_InspectUI (Interface 30300) —
-- including the three details the port is built around:
--
--   * InspectFrame owns NO chrome. The wooden quadrants belong to each tab subframe and are
--     UNNAMED, so they can only be found by texture path — and the sweep must not take the talent
--     tree's own named background art or the PvP parchment with them.
--   * Blizzard's window is 384x512 and both native panes are laid out for it, wooden border and
--     all. Ours is one size on every tab, so each pane is scaled and anchored by its CONTENT rect.
--   * An unknown level is the STRING "??", which is why the localized PLAYER_LEVEL template has
--     its %d relaxed — string.format("%d", "??") is an error in Lua 5.1, not a warning.
--
-- The core toolkit (NE.panelchrome / nineslice / tabs / portrait) is STUBBED rather than loaded:
-- it has its own coverage, and stubbing it keeps every assertion below about this module.
local ADDON = (arg and arg[0] or ""):match("^(.*)qa/offline/[^/]+$") or "./"

local fails, checks = 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FAIL  " .. what) else print("ok    " .. what) end
end
local function eq(a, b, what)
  ok(a == b, what .. "  (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

-- ── widget stubs ────────────────────────────────────────────────────────────
--
-- Anchored sizes are CACHED, and that is deliberate. A real frame's rect does not resolve until the
-- next layout pass, so GetWidth/GetHeight on a frame whose parent was resized moments ago hands
-- back the size from BEFORE the resize. An honest stub hid a real bug here: the model measured the
-- interior right after the window was resized, got Blizzard's 512-tall window, and came out 408 tall
-- with its backdrop hanging past the window's bottom edge. `layoutPass()` is what the client's next
-- frame would do.
local spanCache = setmetatable({}, { __mode = "k" })
function layoutPass()
  for k in pairs(spanCache) do spanCache[k] = nil end
end

local function addPointApi(o)
  o._points = {}
  function o:ClearAllPoints() self._points = {} end
  function o:SetPoint(...)
    self._points[#self._points + 1] = { ... }
    if self._primeSpan then self:_primeSpan() end   -- the rect resolves against the parent AS IT IS NOW
  end
  function o:SetAllPoints(other) self._points = { { "ALLPOINTS", other } } end
  function o:SetWidth(w) self._w = w end
  function o:SetHeight(h) self._h = h end
  -- Enough anchor arithmetic to answer GetWidth/GetHeight for the one shape that needs it: a frame
  -- pinned TOPLEFT + BOTTOMRIGHT into a sized parent, which is how the interior rect is defined and
  -- what the model's height is now derived from.
  local function spanned(self, wantW)
    local tl, br
    for _, p in ipairs(self._points) do
      if p[1] == "TOPLEFT" and type(p[2]) == "table" then tl = p end
      if p[1] == "BOTTOMRIGHT" and type(p[2]) == "table" then br = p end
    end
    if not (tl and br and tl[2] == br[2]) then return nil end
    local parent = tl[2]
    if wantW then
      local pw = parent.GetWidth and parent:GetWidth()
      return pw and (pw - (tl[4] or 0) + (br[4] or 0))
    end
    local ph = parent.GetHeight and parent:GetHeight()
    return ph and (ph + (tl[5] or 0) - (br[5] or 0))
  end
  local function cached(self, wantW)
    local key = wantW and "w" or "h"
    local c = spanCache[self]
    if c and c[key] ~= nil then return c[key] end
    local v = spanned(self, wantW)
    if v ~= nil then
      c = c or {}
      c[key] = v
      spanCache[self] = c
    end
    return v
  end
  function o:GetWidth() return self._w or cached(self, true) end
  function o:GetHeight() return self._h or cached(self, false) end
  -- Called on every SetPoint: this is the moment the client would measure, and what it measures is
  -- the parent's size AT THAT MOMENT. Resizing the parent afterwards does not update it until the
  -- next layout pass.
  function o:_primeSpan() cached(self, true); cached(self, false) end
  function o:SetSize(w, h) self._w, self._h = w, h end
  function o:SetAlpha(a) self._alpha = a end
  function o:GetAlpha() return self._alpha or 1 end
  function o:Show() self._shown = true end
  function o:Hide() self._shown = false end
  function o:IsShown() return self._shown and true or false end
end

-- The first SetPoint of `obj`, as point, relativeTo, relativePoint, x, y (both XML signatures).
local function pointOf(obj)
  local p = obj and obj._points and obj._points[1]
  if not p then return nil end
  if type(p[2]) == "number" then return p[1], nil, p[1], p[2], p[3] end
  return p[1], p[2], p[3], p[4], p[5]
end

local function newTexture(layer)
  local t = { _layer = layer or "ARTWORK", _shown = true }
  addPointApi(t)
  function t:SetTexture(a) if type(a) == "string" then self._file = a else self._file = nil end end
  function t:GetTexture() return self._file end
  function t:SetTexCoord(...) self._tc = { ... } end
  function t:SetDesaturated(v) self._desat = v and true or false end
  function t:SetVertexColor(r, g, b) self._vertex = table.concat({ r, g, b }, ",") end
  function t:SetHorizTile() end
  function t:SetVertTile() end
  function t:SetBlendMode() end
  function t:SetDrawLayer(l) self._layer = l end
  function t:GetDrawLayer() return self._layer end
  function t:GetObjectType() return "Texture" end
  -- DragonUI injects set_atlas onto the Texture metatable for every texture in the client
  -- (utils/core.lua inject_api) — that is how the interior ground reaches its atlas.
  function t:set_atlas(a) self._atlas = a end
  return t
end

local function newFontString()
  local fs = { _shown = true }
  addPointApi(fs)
  function fs:SetText(s) self._text = s end
  function fs:GetText() return self._text end
  function fs:SetFormattedText(f, ...) self._text = string.format(f, ...) end
  function fs:SetFontObject() end
  function fs:SetJustifyH() end
  function fs:SetWordWrap() end
  function fs:SetTextColor() end
  function fs:SetDrawLayer() end
  function fs:GetDrawLayer() return "BACKGROUND" end
  function fs:GetObjectType() return "FontString" end
  return fs
end

local function newFrame(kind, name, parent)
  local f = { _kind = kind or "Frame", _name = name, _parent = parent, _children = {},
              _regions = {}, _scripts = {}, _events = {}, _shown = false, _level = 1 }
  if parent and parent._children then table.insert(parent._children, f) end
  addPointApi(f)
  function f:GetName() return self._name end
  function f:GetParent() return self._parent end
  function f:GetObjectType() return self._kind end
  function f:EnableMouse(v) self._mouse = v end
  function f:EnableMouseWheel() end
  function f:IsMouseOver() return self._mouseOver and true or false end
  function f:SetFrameLevel(l) self._level = l end
  function f:GetFrameLevel() return self._level end
  function f:SetFrameStrata() end
  function f:SetAttribute(k, v) self._attrs = self._attrs or {}; self._attrs[k] = v end
  function f:GetAttribute(k) return self._attrs and self._attrs[k] end
  function f:SetScale(s) self._scale = s end
  function f:GetScale() return self._scale or 1 end
  function f:GetEffectiveScale() return self._scale or 1 end
  function f:RegisterEvent(e) self._events[e] = true end
  function f:UnregisterAllEvents() self._events = {} end
  function f:RegisterForClicks() end
  function f:SetScript(s, fn) self._scripts[s] = { fn } end
  function f:GetScript(s) local l = self._scripts[s]; return l and l[1] end
  function f:HookScript(s, fn)
    self._scripts[s] = self._scripts[s] or {}
    table.insert(self._scripts[s], fn)
  end
  function f:Fire(s, ...)
    for _, fn in ipairs(self._scripts[s] or {}) do fn(self, ...) end
  end
  function f:Show() if not self._shown then self._shown = true; self:Fire("OnShow") end end
  function f:Hide() if self._shown then self._shown = false; self:Fire("OnHide") end end
  function f:CreateTexture(n, layer, _, sub)
    local t = newTexture(layer); t._sub = sub
    table.insert(self._regions, t)
    if n then _G[n] = t end
    return t
  end
  function f:CreateFontString(n, layer)
    local fs = newFontString(); fs._layer = layer
    table.insert(self._regions, fs)
    if n then _G[n] = fs end
    return fs
  end
  function f:GetRegions() return unpack(self._regions) end
  function f:GetNumRegions() return #self._regions end
  function f:GetChildren() return unpack(self._children) end
  function f:GetNumPoints() return #self._points end
  function f:GetPoint(i)
    local p = self._points[i or 1]
    if not p then return nil end
    if type(p[2]) == "number" then return p[1], self._parent, p[1], p[2], p[3] end
    return p[1], p[2], p[3], p[4], p[5]
  end
  -- Button bits (the model control strip and the native rotate buttons).
  function f:SetNormalTexture() end
  function f:GetNormalTexture() return nil end
  function f:SetPushedTexture() end
  function f:GetPushedTexture() return nil end
  function f:SetHighlightTexture() end
  function f:GetHighlightTexture() return nil end
  function f:Enable() self._enabled = true end
  function f:Disable() self._enabled = false end
  function f:IsEnabled() return self._enabled ~= false end
  function f:GetButtonState() return self._state or "NORMAL" end
  function f:SetButtonState(s) self._state = s end
  function f:SetText(t) self._text = t end
  if name then _G[name] = f end
  return f
end

_G = _G or getfenv(0)
function CreateFrame(kind, name, parent, template) return newFrame(kind, name, parent) end
function hooksecurefunc(name, post)
  local orig = _G[name]
  _G[name] = function(...) local r = { orig(...) }; post(...); return unpack(r) end
end
function unpack_safe(t) return unpack(t) end
strupper = string.upper
function IsMouseButtonDown() return false end
-- C_Timer.After, as a queue the test pumps by hand (see runTimers).
local timerQueue = {}
C_Timer = { After = function(_, fn) timerQueue[#timerQueue + 1] = fn end }
function runTimers(rounds)
  for _ = 1, (rounds or 12) do
    local q = timerQueue
    if #q == 0 then return end
    timerQueue = {}
    for _, fn in ipairs(q) do fn() end
  end
end
function GameTooltip_Hide() end
GameTooltip = { SetOwner = function() end, SetText = function() end, Show = function() end }

-- ── game data the module reads ──────────────────────────────────────────────
-- The real 3.3.5a string (GlobalStrings.lua:5678) — already %s in the level slot,
-- because Blizzard feeds it "??" itself. The %d variant is exercised further down.
PLAYER_LEVEL = "Level %s %s %s"
local UNIT = {
  target = { level = 80, race = "Gnome", raceFile = "Gnome", class = "Warlock",
             classFile = "WARLOCK", guild = "Wipe Nightly" },
}
local inspected = "target"
function UnitLevel(u) local d = UNIT[u]; return d and d.level end
function UnitRace(u) local d = UNIT[u]; return d and d.race, d and d.raceFile end
function UnitClass(u) local d = UNIT[u]; return d and d.class, d and d.classFile end
function UnitExists(u) return UNIT[u] ~= nil end
function GetGuildInfo(u) local d = UNIT[u]; return d and d.guild end
function CanInspect() return true end
function SetPortraitTexture(tex, unit) tex._portraitUnit = unit end
function HideUIPanel(f) f:Hide() end

local selectedTab = 1
function PanelTemplates_GetSelectedTab() return selectedTab end

-- PvP data, in the exact shapes Blizzard_InspectUI/InspectPVPFrame.lua reads them.
HONOR, ARENA, RATING = "Honor", "Arena", "Rating"
HONOR_TODAY, HONOR_YESTERDAY, HONOR_LIFETIME = "Today", "Yesterday", "Lifetime"
HONORABLE_KILLS, TALENTS, MAX_ARENA_TEAMS = "Honorable Kills", "Talents", 3
local honorData = { 3, 41, 7, 120, 14, 6 }
local arenaCalls = 0
function GetInspectHonorData() return unpack(honorData) end
function HasInspectHonorData() return true end
function RequestInspectHonorData() end
function GetPVPRankInfo(rank) return "Sergeant", rank end
function UnitFactionGroup(u) return "Horde" end
-- teamName, teamSize, teamRating, teamPlayed, teamWins, playerPlayed, playerRating, bg r/g/b,
-- emblem, em r/g/b, border, br r/g/b.  Only the 3v3 bracket has a team.
local arenaTeams = { {}, { "Wipe Nightly", 3, 1842, 40, 27, 38, 1806, 0.1, 0.2, 0.3, 12, 1, 1, 1, 4, 0.5, 0.5, 0.5 }, {} }
function GetInspectArenaTeamData(i)
  arenaCalls = arenaCalls + 1
  return unpack(arenaTeams[i] or {})
end

-- ── addon stubs: the core toolkit, recorded rather than exercised ───────────
DragonUI_NewEra = {
  L = setmetatable({}, { __index = function(_, k) return k end }),
  IsAddOnLoaded = function(n) return n == "Blizzard_InspectUI" end,
}
local NE = DragonUI_NewEra

-- The rock the whole window family's body is painted with, registered exactly as Textures/Assets.lua
-- registers it.
ROCK_PATH = [[Interface\AddOns\DragonUI_NewEra\Textures\Common\374155-uibackground-rock.blp]]
NE.tex = { localFiles = { [374155] = ROCK_PATH } }

NE.FrameUtil = {
  -- The real implementation (core/FrameUtil.lua) — the sweep's correctness depends on it.
  ForEachRegion = function(frame, kind, layer, fn)
    if not (frame and frame.GetRegions and fn) then return 0 end
    local regions = { frame:GetRegions() }
    local n = 0
    for i = 1, #regions do
      local r = regions[i]
      if r and (not kind or r:GetObjectType() == kind)
           and (not layer or (r:GetDrawLayer()) == layer) then
        fn(r); n = n + 1
      end
    end
    return n
  end,
}
NE.color = { WrapClass = function(classFile, text) return "|cffCLASS" .. tostring(text) .. "|r" end }

local chromeCalls = { modernized = {}, hidden = {} }
NE.panelchrome = {
  Keep = function(f, tex) f._kept = tex end,
  HideClassicChrome = function(f) chromeCalls.hidden[f] = true end,
  -- Builds f.NineSlice as the real one does: a CHILD FRAME one level up, which is the whole reason
  -- a texture left on the frame itself never shows through the band.
  ApplyModernChrome = function(f)
    f._modernChrome = true
    if not f.NineSlice then
      f.NineSlice = CreateFrame("Frame", nil, f)
      f.NineSlice:SetFrameLevel(f:GetFrameLevel() + 1)
    end
  end,
  ModernizeCloseButton = function(cb, opts) chromeCalls.modernized[cb] = opts or {} end,
  TitleBand = function(f)
    if f._neTitleBand then return f._neTitleBand end
    local band = CreateFrame("Frame", nil, f)
    band:SetFrameLevel(f:GetFrameLevel() + 11)
    f._neTitleBand = band
    return band
  end,
  SetTitle = function(f, text, fs, anchor) f._titleFS = fs; f._titleAnchor = anchor end,
}
NE.nineslice = {
  ApplyLayout = function() return true end,
  -- The real one (core/NineSlice.lua): a mouse-transparent child pinned into the parent with the
  -- InsetFrameTemplate layout walked onto it.
  AttachInset = function(parent, tlx, tly, brx, bry)
    local ns = CreateFrame("Frame", nil, parent)
    ns:SetPoint("TOPLEFT",     parent, "TOPLEFT",     tlx or 0, tly or 0)
    ns:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", brx or 0, bry or 0)
    ns:EnableMouse(false)
    ns._layout = "InsetFrameTemplate"
    return ns
  end,
  ApplyTopTileStreaks = function(frame, opts)
    local host = (opts and opts.parent) or frame
    local t = host:CreateTexture(nil, "BORDER")
    t._atlas = "_ui-frame-toptilestreaks"
    frame._neTopTileStreaks = t
    return t
  end,
}
NE.portrait = { SetUnit = function(tex, parent, unit, opts)
  tex._cutout = opts
  if unit then SetPortraitTexture(tex, unit) end
end }
local reskinnedTabs = {}
NE.tabs = {
  ReskinClassicTab = function(name) reskinnedTabs[name] = true; return true end,
  SizeAndAnchorTabs = function(parent, names, opts)
    local prev
    for _, n in ipairs(names) do
      local tab = _G[n]
      if tab then
        tab:ClearAllPoints()
        if prev then tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", opts.gap or 1, 0)
        else tab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", opts.startX, opts.startY) end
        prev = tab
      end
    end
  end,
}
-- The talent window's inspect entry point. The module itself is not loaded here (it has its own
-- surface); what matters is that the button finds it and hands it the inspected unit.
NE.talents = { ShowInspect = function(unit) NE.talents._shown = unit end }

local registered
NE.modules = { Register = function(spec) registered = spec end }
NE.qa = { modules = {} }

-- DragonUI: only the seams the module reaches for, each of which it must survive without.
NE.dragon = {
  _dir = "Interface\\AddOns\\DragonUI\\Textures\\",
  CharacterPanel = {
    StyleModelButton = function(btn, glyph) btn._glyph = glyph end,
    -- The real one rims `target` with UI-Frame-Inner art owned by `host`. Recorded, not drawn.
    DrawPaneBorder = function(host, target, outset)
      host._duiPaneBorders = host._duiPaneBorders or {}
      table.insert(host._duiPaneBorders, { target = target, outset = outset or 0 })
    end,
  },
  ModelPivot = { player = 0.9 },
  GetModuleConfig = function(_, name) return { grey_model_backdrop = true } end,
  WireModelView = function(_, model) model._wired = true end,
  ZoomModelView = function(_, model, n) model._zoom = (model._zoom or 0) + n end,
  ResetModelView = function(_, model) model._zoom = 0 end,
  ResetModelRotation = function(_, model) model.rotation = 0.61 end,
  ForwardModelInput = function() end,
}

-- ── the 3.3.5a inspect tree (Blizzard_InspectUI.xml + InspectPaperDollFrame.xml) ─────────────
local InspectFrame = CreateFrame("Frame", "InspectFrame", nil)
InspectFrame:SetSize(384, 512)
InspectFrame.unit = nil
do
  local p = InspectFrame:CreateTexture("InspectFramePortrait", "ARTWORK")
  p:SetWidth(60); p:SetHeight(60); p:SetPoint("TOPLEFT", 7, -6)
end
local nameFrame = CreateFrame("Frame", "InspectNameFrame", InspectFrame)
nameFrame:SetPoint("CENTER", 6, 232)
local nameText = nameFrame:CreateFontString("InspectNameText", "ARTWORK")
CreateFrame("Button", "InspectFrameCloseButton", InspectFrame)
for i = 1, 3 do
  local tab = CreateFrame("Button", "InspectFrameTab" .. i, InspectFrame)
  tab:SetPoint("CENTER", InspectFrame, "BOTTOMLEFT", 60, 61)
  tab:Show()   -- Blizzard's tabs are not hidden in the XML
end

local paperdoll = CreateFrame("Frame", "InspectPaperDollFrame", InspectFrame)
for _, file in ipairs({ "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-L1",
                        "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-R1",
                        "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-BottomLeft",
                        "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-BottomRight" }) do
  paperdoll:CreateTexture(nil, "BACKGROUND"):SetTexture(file)
end
local levelText = paperdoll:CreateFontString("InspectLevelText", "BACKGROUND")
paperdoll:CreateFontString("InspectTitleText", "BACKGROUND")
local guildText = paperdoll:CreateFontString("InspectGuildText", "BACKGROUND")
guildText:Hide()

local model = CreateFrame("PlayerModel", "InspectModelFrame", paperdoll)
model:SetSize(233, 300)
model:SetPoint("TOPLEFT", 65, -78)
local rotL = CreateFrame("Button", "InspectModelRotateLeftButton", model)
local rotR = CreateFrame("Button", "InspectModelRotateRightButton", model)
rotL:Show(); rotR:Show()

local SLOTS = {
  "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectBackSlot",
  "InspectChestSlot", "InspectShirtSlot", "InspectTabardSlot", "InspectWristSlot",
  "InspectHandsSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
  "InspectFinger0Slot", "InspectFinger1Slot", "InspectTrinket0Slot", "InspectTrinket1Slot",
  "InspectMainHandSlot", "InspectSecondaryHandSlot", "InspectRangedSlot",
}
for _, n in ipairs(SLOTS) do CreateFrame("Button", n, paperdoll):SetPoint("TOPLEFT", 21, -74) end

local pvp = CreateFrame("Frame", "InspectPVPFrame", InspectFrame)
for _, file in ipairs({ "Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft",
                        "Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight",
                        "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft",
                        "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight" }) do
  pvp:CreateTexture(nil, "BACKGROUND"):SetTexture(file)
end
local pvpPlate = pvp:CreateTexture("InspectPVPFrameBackground", "BORDER")
pvpPlate:SetTexture("Interface\\PVPFrame\\UI-Character-PVP")

local talents = CreateFrame("Frame", "InspectTalentFrame", InspectFrame)
-- The pane's own copy of the portrait, on BACKGROUND — a second head that travels with the pane.
local talentPortrait = talents:CreateTexture("InspectTalentFramePortrait", "BACKGROUND")
-- BORDER, not BACKGROUND: this pane declares the identical four quadrants one layer up
-- (InspectTalentFrame.xml) — exactly what a BACKGROUND-only sweep left on screen.
for _, file in ipairs({ "Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft",
                        "Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight",
                        "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft",
                        "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight" }) do
  talents:CreateTexture(nil, "BORDER"):SetTexture(file)
end
local treeArt = talents:CreateTexture("InspectTalentFrameBackgroundTopLeft", "BACKGROUND")
treeArt:SetTexture("Interface\\TalentFrame\\Warlock-Destruction-TopLeft")
local talentClose = CreateFrame("Button", "InspectTalentFrameCloseButton", talents)
talentClose:Show()

-- Blizzard's own funnels, in the shapes the module hooks.
function InspectPaperDollFrame_SetLevel()
  local unit = InspectFrame.unit
  local level = UnitLevel(unit)
  if level == -1 then level = "??" end
  levelText:SetText("stock")
end
function InspectPaperDollFrame_OnShow()
  InspectPaperDollFrame_SetLevel()
end
function InspectSwitchTabs(id)
  selectedTab = id
end

-- ── load the port ───────────────────────────────────────────────────────────
assert(loadfile(ADDON .. "modules/inspect/InspectFrame.lua"))()
assert(loadfile(ADDON .. "modules/inspect/PaperDoll.lua"))()
assert(loadfile(ADDON .. "modules/inspect/PvPPane.lua"))()
assert(loadfile(ADDON .. "modules/inspect/Register.lua"))()
local I = NE.inspect

print("== registration ==")
ok(registered and registered.name == "Inspect", "registers as the Inspect module")
ok(registered and registered.default == true, "on by default")
ok(registered and registered.events[1] == "ADDON_LOADED", "boots off ADDON_LOADED (LoadOnDemand)")
eq(#NE.qa.modules, 1, "one QA harness entry")

print("== boot gate ==")
registered.onBoot("ADDON_LOADED", "Blizzard_TradeSkillUI")
ok(not I.IsApplied(), "another addon loading does nothing")

InspectFrame.unit = "target"
registered.onBoot("ADDON_LOADED", "Blizzard_InspectUI")
ok(I.IsApplied(), "applies when Blizzard_InspectUI loads")
registered.onBoot("ADDON_LOADED", "Blizzard_InspectUI")   -- must not double-apply

print("== measured vs computed ==")
-- No layout pass yet: the window was resized during Apply, so a real client would still be handing
-- back the interior's OLD span here — 512 - 60 - 4. Anything that measured it would be 88px out.
eq(InspectFrame.NE_Inset:GetHeight(), 448, "the interior still MEASURES stale, exactly as in game")
eq(model:GetHeight(), 320,
   "...and the model is right regardless, because it computes the interior instead of measuring it")
layoutPass()
eq(InspectFrame.NE_Inset:GetHeight(), 360, "after a layout pass it measures what it always was")

print("== chrome sweep ==")
local function hiddenChrome(frame)
  local n = 0
  for _, r in ipairs(frame._regions) do
    if r.GetTexture and r:GetTexture() and not r:IsShown() then n = n + 1 end
  end
  return n
end
eq(hiddenChrome(paperdoll), 4, "the paperdoll's four wooden quadrants are hidden")
eq(hiddenChrome(talents), 4, "the talents pane's four wooden quadrants are hidden")
ok(treeArt:IsShown(), "the talent TREE art is content, and survives the sweep")
-- The PvP pane is a special case: PvPPane.lua squelches ALL of its content, parchment included,
-- because we draw that tab ourselves. The quadrants going is the least of it.
ok(not pvpPlate:IsShown(), "the PvP parchment goes with the rest of that pane's content")
ok(_G.InspectFramePortrait._cutout ~= nil, "the portrait is seated in the corner cutout")
eq(_G.InspectFramePortrait._portraitUnit, "target", "the portrait shows the INSPECTED unit")
ok(chromeCalls.modernized[_G.InspectFrameCloseButton] ~= nil, "the close button is modernized")
ok(not talentClose:IsShown(), "the talents pane's duplicate close button is hidden")
talentClose:Show()
ok(not talentClose:IsShown(), "...and stays hidden when PanelTemplates re-shows the pane")

print("== the PVP tab, drawn on our own furniture ==")
ok(_G.NE_InspectPVPFrame ~= nil, "a modern pane is built for it")
ok(pvp._neSquelched == nil, "the native FRAME keeps running — it is the client's data pump")
ok(pvpPlate.Show == pvpPlate.Hide,
   "...but its content's Show is neutered, since InspectPVPTeam_Update re-shows the team plates")
ok(not _G.NE_InspectPVPFrame:IsShown(), "our pane starts hidden, with the tab unselected")
pvp:Show()
ok(_G.NE_InspectPVPFrame:IsShown(), "showing the native pane shows ours in its place")
ok(arenaCalls >= 3, "every arena bracket is primed before it is read (the native update's own loop)")
eq(_G.NE_InspectPVPFrame.Cells[3]:GetText(), "14", "lifetime kills land in the table")
eq(_G.NE_InspectPVPFrame.Cells[4]:GetText(), "41", "today's honor too")
eq(_G.NE_InspectPVPFrame.RankName:GetText(), "Sergeant", "and the lifetime rank is named")
eq(_G.NE_InspectPVPFrame.Rows[2].Name:GetText(), "Wipe Nightly", "the 3v3 team fills its bracket row")
eq(_G.NE_InspectPVPFrame.Rows[2].Rating:GetText(), "1842", "...with its rating")
eq(_G.NE_InspectPVPFrame.Rows[2].Record:GetText(), "3v3   27 - 13", "...and its season record")
eq(_G.NE_InspectPVPFrame.Rows[1].Name:GetText(), "2v2", "a bracket with no team keeps its row, named")
ok(_G.NE_InspectPVPFrame.Rows[1]:GetAlpha() < 1, "...and dimmed")
ok(_G.NE_InspectPVPFrame.Rows[1].Bg ~= nil and _G.NE_InspectPVPFrame.Rows[1].Bg._file == nil,
   "every inset box has a BLACK ground, not a window onto the stone behind it")
local rowH = _G.NE_InspectPVPFrame.Rows[1]:GetHeight()
ok(rowH >= 46, "bracket rows are at least readable")
-- 22 heading + 6 + 110 honor + 10 + 22 heading + 6 + three rows separated by 4 = the pane's 348.
ok(184 + 3 * rowH >= 348 - 4,
   "...and share out the leftover height, so the block fills the tab rather than stopping short")
eq(rowH, 54, "which at this window size is 54 a row")
pvp:Hide()
ok(not _G.NE_InspectPVPFrame:IsShown(),
   "hiding the native pane hides ours — which is why the native frame is never hidden by US")

print("== the Talents tab ==")
local tab3 = _G.InspectFrameTab3
ok(tab3:IsShown(), "Talents stays a tab in the strip, beside Character and PvP")
local _, t3rel, t3relp = pointOf(tab3)
eq(t3rel, _G.InspectFrameTab2, "chained off the PvP tab")
tab3:Fire("OnClick")
eq(NE.talents._shown, "target",
   "clicking it opens the talent window on the INSPECTED unit, not the native tree pane")
eq(selectedTab, 1, "...and does NOT switch panes: the window keeps showing what it was showing")

print("== top band ==")
-- The band is left where ApplyModernChrome puts it: on the frame, under the nineslice, invisible.
-- Lifting it above the nineslice put it over Blizzard's portrait, and clearing the portrait left
-- its cut edge reading as a shadow across the stone. See applyChrome's comment.
ok(InspectFrame.NE_Streaks == nil, "no host frame for the streak band, and none wanted")

print("== panel placement ==")
eq(InspectFrame:GetAttribute("UIPanelLayout-xoffset"), 6,
   "nudged off the screen edge — a modern frame is opaque to its edge where the wooden one was not")
eq(InspectFrame:GetAttribute("UIPanelLayout-pushable"), 3,
   "and as pushable as the character panel, so it opens BESIDE it rather than shoving it aside")
ok(InspectFrame:GetAttribute("UIPanelLayout-defined"),
   "...declared on the frame, since writing UIPanelWindows taints the first panel open in combat")
eq(InspectFrame:GetAttribute("UIPanelLayout-area"), "left",
   "...which means area and enabled have to be restated here too, or the copy would drop them")

print("== title band ==")
ok(InspectFrame._neTitle == nameText, "the unit name is rehosted into the title band")
do
  local tp, trel, _, tx, ty = pointOf(nameText)
  eq(trel, InspectFrame, "and centred on the WINDOW, not on the band")
  eq(tp, "TOP", "...by its top edge")
  eq(tx, 0, "...dead centre: centring inside the band would sit it 17px right, clear of the portrait")
end
local p, rel = pointOf(nameFrame)
eq(p, "ALLPOINTS", "the name frame fills the band")
eq(rel, InspectFrame._neTitleBand, "...the band itself")
eq(nameFrame:GetFrameLevel(), InspectFrame._neTitleBand:GetFrameLevel(),
   "the name frame is lifted past the nineslice")

print("== tabs ==")
ok(reskinnedTabs.InspectFrameTab1 and reskinnedTabs.InspectFrameTab2 and reskinnedTabs.InspectFrameTab3,
   "all three tabs are reskinned")
local tp, tRel, tRelP, tx, ty = pointOf(_G.InspectFrameTab1)
eq(tRel, InspectFrame, "tab 1 hangs off the frame")
eq(tRelP, "BOTTOMLEFT", "...its bottom-left")
eq(tx, 11, "at retail's x")
eq(ty, 2, "at retail's y")

print("== geometry ==")
eq(InspectFrame:GetWidth(), 338, "retail width")
eq(InspectFrame:GetHeight(), 424, "retail height — the character panel's, to the pixel")
eq(InspectFrame.NE_Inset:GetWidth(), 330, "interior is 330 wide — SYMMETRIC, 4 in from each side")
eq(InspectFrame.NE_Inset:GetHeight(), 360, "...and 360 tall")
ok(InspectFrame.NE_Inset:IsShown(), "interior rect shown")
eq(InspectFrame.NE_Inset.Bg._atlas, "character-panel-background",
   "...grounded in the character panel's own inset art, so the content area reads as recessed")
do
  local rims = InspectFrame.NE_Inset._duiPaneBorders or {}
  ok(rims[1] and rims[1].target == InspectFrame.NE_Inset,
     "...and rimmed by the same routine DragonUI rims its own insets with")
end
eq(InspectFrame.Bg._file, ROCK_PATH, "the body is the shared UI-Background-Rock, tiled")
eq(InspectFrame.Bg._vertex, "1,1,1",
   "...at full brightness — PC.ApplyBodyFill's 0.32 tint is the bag windows' look, not this family's")
local bp, brel, brelp, bx, by = pointOf(InspectFrame.Bg)
eq(by, -21, "and it starts just under the title bar, like every other NewEra window's body")
eq(bx, 0, "...flush to the left edge: a 4px inset left a strip of bare frame showing down that side")
InspectSwitchTabs(2)
eq(InspectFrame:GetWidth(), 338, "PvP tab: the window does NOT resize")
eq(InspectFrame:GetHeight(), 424, "...in either dimension")
InspectSwitchTabs(3)
eq(InspectFrame:GetWidth(), 338, "Talents tab: the same window again")
InspectSwitchTabs(1)
eq(InspectFrame:GetWidth(), 338, "and back")

print("== native panes fitted to the interior ==")
-- 328x360 interior. Each pane keeps its own 384x512 coordinate space (every child is anchored in
-- it) and is scaled so its CONTENT rect — not its frame rect — covers the interior.
local IW, IH = 330, 360
for _, case in ipairs({ { pvp,     { left = 14, top = -36, right = 350, bottom = -425 } },
                        { talents, { left = 16, top = -40, right = 348, bottom = -461 } } }) do
  local sub, rect = case[1], case[2]
  local name = sub:GetName()
  local s = sub._neFitScale
  local cw, ch = rect.right - rect.left, rect.top - rect.bottom
  eq(sub:GetWidth(), 384, name .. ": keeps its 384-wide coordinate space")
  eq(sub:GetHeight(), 512, name .. ": ...and its 512-tall one")
  -- A DEGRADED PATH now, not the normal one: the PvP tab is drawn by PvPPane.lua and the talents
  -- tab is retired for a paperdoll button, so this fit is what the window falls back to if either
  -- of those is unavailable. It still has to land inside the interior.
  ok(s and s > 0.5 and s <= 1, name .. ": scaled to fit (" .. tostring(s) .. ")")
  ok(cw * s <= IW + 0.5, name .. ": content width fits the interior")
  ok(ch * s <= IH + 0.5, name .. ": content height fits the interior")
  ok(math.abs(ch * s - IH) < 0.5 or math.abs(cw * s - IW) < 0.5,
     name .. ": ...filling it on its tight axis")
  -- Where the content's top-left actually lands, in the frame's own units.
  local _, prel, _, px, py = pointOf(sub)
  eq(prel, InspectFrame, name .. ": anchored to the window")
  local cx, cy = (px + rect.left) * s, (py + rect.top) * s
  ok(math.abs(cy - -60) < 0.5, name .. ": content top lands on the interior top (-60)")
  ok(cx >= 3.5 and cx + cw * s <= 334.5, name .. ": content sits inside the interior, slack centred")
  ok(cy - ch * s >= -421, name .. ": ...and its bottom stays inside the window")
end
ok(not talentPortrait:IsShown(),
   "the talents pane's own second portrait is hidden rather than carried along by the fit")
-- A fitted pane is 384x512 in its own units, so it hangs below the window, over the tab strip.
ok(pvp._mouse == false and talents._mouse == false,
   "a fitted pane gives up its own mouse, so it can't block the tabs it hangs over")
ok(_G.InspectFrameTab1:GetFrameLevel() > pvp:GetFrameLevel(),
   "...and the tabs sit above both panes regardless")

print("== slots ==")
local inset = InspectFrame.NE_Inset
local hp, hrel, hrelp, hx, hy = pointOf(_G.InspectHeadSlot)
eq(hrel, inset, "left column head anchors to the interior")
eq(hx .. "," .. hy, "4,-2", "...at (4,-2)")
local _, arel, arelp, ax, ay = pointOf(_G.InspectHandsSlot)
eq(arelp, "TOPRIGHT", "right column head anchors to the interior's top-right")
eq(ax .. "," .. ay, "-4,-2", "...at (-4,-2)")
local _, mrel, mrelp, mx, my = pointOf(_G.InspectMainHandSlot)
eq(mrelp, "BOTTOMLEFT", "the weapon row anchors to the interior's bottom-left")
eq(mx, 104, "...centred by arithmetic: (330 - 121) / 2, not a number measured elsewhere")
eq(my, 20, "...20 up")
local nrel = select(2, pointOf(_G.InspectNeckSlot))
ok(nrel ~= inset, "the other slots keep Blizzard's chain off the column head")
-- The columns' outer art edges (the slot frame overhangs its button by 4) must be the same
-- distance from each frame edge — the asymmetry the retail inset rect carried is what left the
-- right-hand column with visibly more air beside it.
-- interior inset (4 a side) + the slot's own offset, less the 4 its frame art overhangs by.
local leftMargin  = 4 + hx - 4
local rightMargin = 4 + (-ax) - 4
eq(leftMargin, rightMargin,
   "left and right columns sit the same distance in from their own frame edge")
ok(_G.InspectHeadSlot._neSlotFrame ~= nil, "slots get the character panel's metal frame art")
ok(_G.InspectMainHandSlot._neSlotGap ~= nil, "the weapon row gets its end filler")
ok(_G.InspectHeadSlot:GetFrameLevel() > model:GetFrameLevel(),
   "slots draw above the model, so a zoomed model can't paint over the weapon row")
ok(model:GetFrameLevel() > InspectFrame.NE_Inset:GetFrameLevel(),
   "and the model itself draws above the interior ground, not behind it")

print("== model ==")
eq(model:GetWidth(), 231, "model width")
eq(model:GetHeight(), 320, "model height: derived from the interior (360 - 6 - 34), DragonUI's own")
eq(model._neRaceBg[1]:GetHeight(), 245, "...so the race backdrop's quarters come back to 245 too")
local _, mrel2, _, mx2, my2 = pointOf(model)
eq(mrel2, inset, "the model anchors to the interior")
eq(mx2 .. "," .. my2, "49,-6", "...centred too: (330 - 231) / 2")
do
  local rims = paperdoll._duiPaneBorders or {}
  local mine
  for _, r in ipairs(rims) do if r.target == model then mine = r end end
  ok(mine ~= nil, "the viewport is rimmed with DragonUI's own pane-border routine, not our own")
  eq(mine and mine.outset, 2, "...at the same 2px outset its character panel rims ITS model with")
end
ok(model._wired, "the model takes DragonUI's drag/zoom/pan gestures")
eq(_G.NE_InspectModelZoomIn._glyph, "common-icon-zoomin", "the strip is styled like the character panel's")
ok(not rotL:IsShown(), "the native rotate buttons start down with the strip")
model._mouseOver = true
model:Fire("OnEnter")
ok(rotL:IsShown() and _G.NE_InspectModelControls:IsShown(), "hovering the model reveals the strip")
_G.NE_InspectModelReset:Fire("OnClick")
model._mouseOver = false
_G.NE_InspectModelControls:Fire("OnLeave")
ok(not rotL:IsShown(), "leaving hides it again, natives included (an invisible button eats clicks)")

print("== race backdrop ==")
local q1 = model._neRaceBg[1]
eq(q1:GetTexture(), "Interface\\DressUpFrame\\DressUpBackground-Dwarf1",
   "Gnome falls back to Dwarf art (the client ships no Gnome backdrop)")
ok(q1._desat, "desaturated, following the character panel's own setting")
ok(model._neRaceBgOverlay:GetAlpha() > 0, "and dimmed under the black overlay")

print("== header lines ==")
eq(levelText:GetText(), "Level 80 Gnome |cffCLASSWarlock|r", "level line: class-coloured")
eq(guildText:GetText(), "<Wipe Nightly>", "guild line filled from GetGuildInfo")
ok(guildText:IsShown(), "...and shown")

print("== retargeting ==")
UNIT.other = { level = -1, race = "Troll", raceFile = "Troll", class = "Shaman",
               classFile = "SHAMAN", guild = nil }
InspectFrame.unit = "other"
InspectPaperDollFrame_OnShow()          -- the funnel InspectFrame_UnitChanged calls
eq(levelText:GetText(), "Level ?? Troll |cffCLASSShaman|r",
   "an unknown level is \"??\" — and does not blow up string.format")
eq(model._neRaceBg[1]:GetTexture(), "Interface\\DressUpFrame\\DressUpBackground-Orc1",
   "the backdrop follows the new unit (Troll falls back to Orc)")
ok(not guildText:IsShown(), "a guildless unit hides the guild line")
eq(_G.InspectFramePortrait._portraitUnit, "other", "the portrait follows too")
local _, lrel, lrelp, _, ly = pointOf(levelText)
eq(lrel, paperdoll, "the level line centres on the paperdoll's top")
eq(ly, -42, "...at -42 with no guild line under it")
InspectFrame.unit = "target"
InspectPaperDollFrame_OnShow()
eq(select(5, pointOf(levelText)), -36, "and lifts to -36 when the guild line joins it")

print("== DragonUI's floating item level ==")
-- Its holder, built exactly as modules/itemlevel.lua builds it: a child of the paperdoll, anchored
-- to the MODEL's bottom, holding one FontString and nothing else. It appears lazily, on the first
-- inspect that has data — so it must be found on a later refresh, not at boot.
-- ORDER MATTERS HERE, and it is the whole point: the refresh runs FIRST, with no holder to find.
-- DragonUI builds that FontString on its own debounce off INSPECT_TALENT_READY, which lands after
-- the refresh we pin from — so a single look finds nothing, the text appears unpinned over the
-- weapon row, and only the retry saves it.
InspectPaperDollFrame_OnShow()

local ilvlHolder = CreateFrame("Frame", nil, paperdoll)
ilvlHolder:SetHeight(20)
ilvlHolder:SetPoint("BOTTOMLEFT", model, "BOTTOMLEFT", 0, 0)
ilvlHolder:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 0, 0)
local ilvlText = ilvlHolder:CreateFontString(nil, "OVERLAY")
ilvlText:SetPoint("BOTTOM", ilvlHolder, "BOTTOM", 0, 4)
ilvlText:SetText("Item Level: 102")
local _, ownerBefore = pointOf(ilvlText)
eq(ownerBefore, ilvlHolder, "before: it sits on the holder, at the model's feet — over the weapon row")

runTimers()   -- the retries the refresh queued
local ip, irel, irelp, ix, iy = pointOf(ilvlText)
eq(irel, model, "after: re-anchored to the model itself")
eq(ip, "BOTTOM", "...by its bottom edge")
eq(iy, 27, "...27 up, clearing the weapon row's top by 4")
ilvlText:ClearAllPoints()
InspectPaperDollFrame_OnShow()
eq(#ilvlText._points, 0, "and it is pinned once, not re-hunted on every refresh")
runTimers()
eq(#ilvlText._points, 0, "...the retries stop too, rather than re-pinning forever")

print("== a %d level template ==")
PLAYER_LEVEL = "Level %d %s %s"
UNIT.other.level = -1
InspectFrame.unit = "other"
InspectPaperDollFrame_OnShow()
eq(levelText:GetText(), "Level ?? Troll |cffCLASSShaman|r",
   "a client whose PLAYER_LEVEL uses %d still renders \"??\" instead of erroring")

print("")
print(string.format("%d checks, %d failure(s)", checks, fails))
os.exit(fails == 0 and 0 or 1)
