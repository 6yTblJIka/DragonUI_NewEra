-- Exercise core/PanelManager.lua against a stubbed widget API.
--
-- Covers the placement contract described in that file's header: home-when-alone, left-to-right
-- tiling by pushable then show-recency, the frame-units conversion for scaled windows, the
-- tight-pack retry and cascade on a row that will not fit, user placement leaving the system
-- (dragged this session, or restored from db.windowPos), and the combat rule where a protected
-- frame keeps its position but still reserves its slot.
--
-- Run as: luajit qa/offline/test_panelmgr.lua

-- ── minimal widget stub ─────────────────────────────────────────────────────
-- Two behaviours are deliberate and load-bearing:
--   * Show() fires OnShow only on a hidden->shown transition, matching the client (and it
--     propagates to children, which is how the manager watches the Spellbook's secure-wrapped
--     frame without hooking its scripts).
--   * C_Timer.After queues rather than running, so a test can assert on the SYNCHRONOUS reflow and
--     the coalesced one separately. flushTimers() drains the queue.

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flushTimers()
  local queue = timers
  timers = {}
  for _, fn in ipairs(queue) do fn() end
end

local combat = false
function InCombatLockdown() return combat end

local function newFrame(name, parent)
  local f = {
    _name = name, _parent = parent, _w = 0, _h = 0, _scale = 1, _shown = false,
    _points = {}, _scripts = {}, _children = {}, _protected = false, _raised = 0,
    -- Anchor writes are COUNTED as well as recorded: ClearAllPoints + SetPoint leaves the table one
    -- entry long every time, so the table alone cannot tell "moved again" from "never moved".
    _anchorCount = 0,
  }
  function f:GetName() return self._name end
  function f:GetParent() return self._parent end
  function f:SetSize(w, h)
    local changed = (w ~= self._w or h ~= self._h)
    self._w, self._h = w, h
    if changed then
      for _, fn in ipairs(self._scripts.OnSizeChanged or {}) do fn(self) end
    end
  end
  function f:GetWidth() return self._w end
  function f:GetHeight() return self._h end
  function f:SetScale(s) self._scale = s end
  function f:GetScale() return self._scale end
  function f:GetEffectiveScale()
    local p = self._parent
    return self._scale * (p and p:GetEffectiveScale() or 1)
  end
  function f:IsShown() return self._shown end
  function f:IsProtected() return self._protected end
  function f:Raise() self._raised = self._raised + 1 end
  function f:ClearAllPoints() self._points = {} end
  function f:SetPoint(p, rel, relP, x, y)
    self._points[#self._points + 1] = { point = p, rel = rel, relPoint = relP, x = x, y = y }
    self._anchorCount = self._anchorCount + 1
  end
  function f:GetPoint(i)
    local pt = self._points[i or 1]
    if not pt then return nil end
    return pt.point, pt.rel, pt.relPoint, pt.x, pt.y
  end
  function f:SetScript(s, fn) self._scripts[s] = { fn } end
  function f:HookScript(s, fn)
    self._scripts[s] = self._scripts[s] or {}
    table.insert(self._scripts[s], fn)
  end
  function f:RegisterEvent() end
  local function fire(self, script)
    for _, fn in ipairs(self._scripts[script] or {}) do fn(self) end
    for _, c in ipairs(self._children) do fire(c, script) end
  end
  function f:Show()
    if self._shown then return end
    self._shown = true
    fire(self, "OnShow")
  end
  function f:Hide()
    if not self._shown then return end
    self._shown = false
    fire(self, "OnHide")
  end
  -- A drag is a start, a move, and a stop. `dx` defaults to a decisive shove; pass a small value to
  -- model the accidental twitch a click on a window's body produces (these frames are mouse-enabled
  -- and drag-registered across their whole area).
  function f:Drag(dx)
    fire(self, "OnDragStart")
    self._left = (self._left or 0) + (dx or 200)
    fire(self, "OnDragStop")
  end
  function f:GetLeft() return self._left or 0 end
  function f:GetTop() return self._top or 0 end
  -- The frame's current top-left in UIParent units, derived from the anchor the manager wrote.
  function f:Placement()
    local pt = self._points[#self._points]
    if not pt then return nil end
    return pt.point, pt.x, pt.y
  end
  if parent then table.insert(parent._children, f) end
  return f
end

UIParent = newFrame("UIParent")
UIParent:SetSize(1600, 900)
UIParent._shown = true

function CreateFrame(_, name, parent)
  local f = newFrame(name, parent or UIParent)
  if name then _G[name] = f end
  return f
end

DragonUI_NewEra = { db = { windowPos = {} } }
SlashCmdList = {}   -- /nepanels registers itself at load

local ADDON = os.getenv("NE_ADDON_ROOT") or "./"
dofile(ADDON .. "core/PanelManager.lua")
local M = DragonUI_NewEra.panelmgr

-- Where a frame's CURRENT anchor puts its top-left corner, in UIParent units. Deliberately a
-- second, independent implementation of the manager's own homeTopLeft: the point of the
-- "nothing moved" assertions is that the on-screen corner is identical, which comparing raw
-- SetPoint arguments cannot show (the same corner is expressible as LEFT,16 or TOPLEFT,16,-181).
local FX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5,
             TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local FY = { TOPLEFT = 0, TOP = 0, TOPRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5,
             BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }

local function uiTopLeft(f)
  local pt = f._points[#f._points]
  if not pt then return nil end
  local s  = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local w, h = f:GetWidth() * s, f:GetHeight() * s
  local rp = pt.relPoint or pt.point
  local x =  UIParent:GetWidth()  * (FX[rp] or 0) + (pt.x or 0) * s - w * (FX[pt.point] or 0)
  local y = -UIParent:GetHeight() * (FY[rp] or 0) + (pt.y or 0) * s + h * (FY[pt.point] or 0)
  return x, y
end

-- ── assertions ──────────────────────────────────────────────────────────────
local fails = 0
local function check(label, got, want)
  local ok
  if type(got) == "number" and type(want) == "number" then
    ok = math.abs(got - want) < 0.01
  else
    ok = (got == want)
  end
  if not ok then
    fails = fails + 1
    print(string.format("  FAIL %-46s got %s want %s", label, tostring(got), tostring(want)))
  else
    print(string.format("  ok   %-46s %s", label, tostring(got)))
  end
end

-- ── fixtures ────────────────────────────────────────────────────────────────
-- Real numbers from the modules: the AH is 800x538 unscaled; Social is 465x560 at the 0.7 that
-- core/Scale.lua's BASE_SCALE applies, so it reserves 325.5 of the row.
local function makeWindow(name, w, h, scale, home)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(w, h)
  f:SetScale(scale or 1)
  f:SetPoint(home[1], UIParent, home[2], home[3], home[4])
  f:HookScript("OnDragStart", function() end)
  M.Register(f)
  return f
end

local function reset()
  for frame in pairs(M._reg) do M._reg[frame] = nil end
  M._seq, M._scheduled, M._deferred, M._reflowing = 0, nil, nil, nil
  DragonUI_NewEra.db.windowPos = {}
  UIParent:SetSize(1600, 900)
  combat = false
  timers = {}
end

local function ah()     return makeWindow("NE_AuctionHouseFrame", 800, 538, 1,   { "LEFT", "LEFT", 16, 0 }) end
local function social() return makeWindow("NE_FriendsFrame",      465, 560, 0.7, { "LEFT", "LEFT", 16, 0 }) end
local function guild()  return makeWindow("NE_GuildFrame",        990, 582, 0.7, { "LEFT", "LEFT", 16, 0 }) end

-- ── 1. alone on screen keeps the module's own default anchor ────────────────
print("\n[1] a single window opens at its own home anchor")
reset()
local a = ah()
a:Show()
local p, x, y = a:Placement()
check("home point", p, "LEFT")
check("home x", x, 16)
check("home y", y, 0)

-- ── 2. two windows tile the left rail ───────────────────────────────────────
-- The row starts from where the LEADING window already is, not from a fixed offset. The AH's home
-- is LEFT,16 — vertically centred — so on this 900-unit screen its top sits at (900-538)/2 = 181
-- units down, and that is the row's Y. Snapping to a fixed -116 instead is what made the AH visibly
-- jump upward the moment the friends list opened.
print("\n[2] AH + Social tile left->right (issue #49)")
reset()
a = ah()
local s = social()
a:Show()
local hx, hy = uiTopLeft(a)          -- where the AH sits with nothing else open
s:Show()
local tx, ty = uiTopLeft(a)
check("AH did NOT move when Social opened (x)", tx, hx)
check("AH did NOT move when Social opened (y)", ty, hy)
check("AH corner is its centred home", ty, -181)
tx, ty = uiTopLeft(s)
check("Social clears the AH", tx, 848)
check("Social shares the AH's top edge", ty, -181)
p = s:Placement()
check("Social anchor", p, "TOPLEFT")

-- ── 3. pushable orders the row, not the open order ──────────────────────────
print("\n[3] opening Social FIRST still leaves the AH leftmost (pushable 0 < 2)")
reset()
a, s = ah(), social()
s:Show()
a:Show()
_, x = a:Placement()
check("AH still leftmost", x, 16)
_, x = s:Placement()
check("Social still second", x, 848 / 0.7)

-- ── 4. ties break by show-recency (oldest leftmost) ─────────────────────────
print("\n[4] Social and Guild share pushable 2 - the older one is leftmost")
reset()
s = social()
local g = guild()
s:Show()
g:Show()
-- Social's home is LEFT,16 in ITS OWN units, which at 0.7 scale is 11.2 UIParent units — and the
-- row starts from exactly that, so Social does not budge when Guild joins it.
x = uiTopLeft(s)
check("Social (shown first) leftmost, unmoved", x, 11.2)
x = uiTopLeft(g)
-- 11.2 + 325.5 + 32 = 368.7
check("Guild to its right", x, 368.7)

-- ── 5. hiding one sends the survivor home ───────────────────────────────────
print("\n[5] closing one window returns the other to its home anchor")
reset()
a, s = ah(), social()
a:Show(); s:Show()
s:Hide()
p, x, y = a:Placement()
check("AH back home", p, "LEFT")
check("AH home x", x, 16)
check("AH home y", y, 0)

-- ── 6. a row that will not fit: tight-pack, then cascade ────────────────────
print("\n[6a] a narrow screen drops the 32px gap before giving up on tiling")
reset()
-- maxW 1144: the row needs 1173.5 with the gap and 1141.5 without, so only the tight pack fits.
UIParent:SetSize(1160, 900)
a, s = ah(), social()
a:Show(); s:Show()
_, x = a:Placement()
check("AH at the row start", x, 16)
_, x = s:Placement()
check("Social tight-packed against it", x, 816 / 0.7)

print("\n[6b] still too narrow -> the overflow cascades instead of being closed")
reset()
UIParent:SetSize(1000, 900)   -- maxW 984; even tight-packed the row needs 1141.5
a, s = ah(), social()
a:Show(); s:Show()
_, x = a:Placement()
check("AH keeps the row start", x, 16)
p, x, y = s:Placement()
check("Social cascades down-right", x, 44 / 0.7)
-- The stagger is measured from the row's origin (the AH's centred home top, -181), not a constant.
check("cascade drops a title bar", y, -209 / 0.7)
check("both windows still shown", (a:IsShown() and s:IsShown()) and 1 or 0, 1)

print("\n[6c] the cascade is clamped so the window stays wholly on screen")
reset()
-- 380 wide leaves only 38.5 units of stagger before Social's right edge would leave the screen (the
-- cascade wants 16+28), and 410 tall leaves only 18 before its bottom edge would. The AH is taller
-- than this screen, so the row top-aligns at 0 and the stagger is measured from there.
UIParent:SetSize(380, 410)
a, s = ah(), social()
a:Show(); s:Show()
p, x, y = s:Placement()
check("clamped to the right edge", x, 38.5 / 0.7)
check("clamped to the bottom edge", y, -18 / 0.7)

-- ── 7. user placement leaves the system ─────────────────────────────────────
print("\n[7a] a dragged window is never moved again, and frees its slot")
reset()
a, s = ah(), social()
a:Show(); s:Show()
s:Drag()                       -- the player drops Social somewhere of their own
local before = s._anchorCount
flushTimers()
a:Hide(); a:Show()             -- churn the row: any reflow that still owned Social would move it
flushTimers()
check("Social not repositioned", s._anchorCount, before)
check("Social is user-placed", M.IsUserPlaced(s) and 1 or 0, 1)
_, x = a:Placement()
check("AH still tiles (2 windows up)", x, 16)

print("\n[7b] a position saved in an earlier session counts as user placement")
reset()
DragonUI_NewEra.db.windowPos.talents = { point = "TOP", relPoint = "TOP", x = 40, y = -200 }
local t = makeWindow("NE_TalentFrame", 900, 600, 1, { "TOP", "TOP", 40, -200 })
check("recognised at registration", M.IsUserPlaced(t) and 1 or 0, 1)
a = ah()
a:Show(); t:Show()
before = t._anchorCount
flushTimers()
check("saved window untouched", t._anchorCount, before)

print("\n[7c] the resolution reset puts everything back under management")
reset()
a, s = ah(), social()
a:Show(); s:Show()
s:Drag()
M.ClearUserPlaced()
flushTimers()
check("Social back in the system", M.IsUserPlaced(s) and 1 or 0, 0)
_, x = s:Placement()
check("and tiled again", x, 848 / 0.7)

-- ── 8. combat: a protected frame holds its place but keeps its slot ─────────
print("\n[8] in combat a protected window is left alone and still reserves its slot")
reset()
a, s = ah(), social()
a:Show()
a._protected = true
combat = true
s:Show()
p, x, y = a:Placement()
check("AH untouched (still home)", p, "LEFT")
_, x = s:Placement()
check("Social tiles around it, not over it", x, 848 / 0.7)
check("a deferred pass is flagged", M._deferred and 1 or 0, 1)

print("\n[8b] out of combat the deferred pass positions it")
combat = false
M.Reflow()
p, x, y = a:Placement()
check("AH now tiled", p, "TOPLEFT")
check("AH x", x, 16)

-- ── 9. the watch path (Spellbook: secure-wrapped OnShow/OnHide) ─────────────
print("\n[9] a `watch` window is driven by a child watcher, deferred not synchronous")
reset()
local sb = makeWindow("NE_SpellBookFrame", 700, 600, 1, { "TOP", "TOP", 0, -55 })
a = ah()
a:Show()
before = sb._anchorCount
sb:Show()
check("no synchronous move inside the secure show", sb._anchorCount, before)
flushTimers()
_, x = sb:Placement()
check("tiled on the coalesced pass", x, 848)

-- ── 10. home comes from the module's DECLARED default, not the live point ───
-- A persisted window is already sitting at the spot it restored from last session when the manager
-- first sees it. Reading that live point would enshrine the player's old position as the window's
-- default; FrameUtil's own registry has the real one.
print("\n[10] a persisted window's home is its declared default, not its restored position")
reset()
local persisted = CreateFrame("Frame", "NE_TalentFrame", UIParent)
persisted:SetSize(900, 600)
persisted:SetPoint("TOP", UIParent, "TOP", 40, -200)     -- restored from a previous session
DragonUI_NewEra.FrameUtil = { _persisted = {
  { frame = persisted, key = "talents", default = { point = "TOP", relPoint = "TOP", x = 0, y = -55 } },
} }
M.Register(persisted)
M.ClearUserPlaced(persisted)                             -- e.g. the resolution reset dropped it
persisted:Show()
flushTimers()
p, x, y = persisted:Placement()
check("home point", p, "TOP")
check("home x is the declared default", x, 0)
check("home y is the declared default", y, -55)
DragonUI_NewEra.FrameUtil = nil

-- ── 11. a window that resizes while tiled re-flows the row ──────────────────
print("\n[11] shrinking a tiled window closes the gap it was holding")
reset()
a, s = ah(), social()
a:Show(); s:Show()
_, x = s:Placement()
check("Social sized against an 800-wide AH", x, 848 / 0.7)
a:SetSize(400, 538)            -- the AH's own minimize would do this
flushTimers()
_, x = s:Placement()
check("Social follows it in", x, 448 / 0.7)

-- ── 12. an accidental twitch is not user placement ──────────────────────────
print("\n[12] a two-pixel drag does not count as placing the window")
reset()
a, s = ah(), social()
a:Show(); s:Show()
s:Drag(2)                      -- a click on the body that moved barely at all
flushTimers()
check("Social still managed", M.IsUserPlaced(s) and 1 or 0, 0)
x = uiTopLeft(s)
check("and still tiled", x, 848)
s:Drag(200)                    -- an unmistakable one
flushTimers()
check("a real drag does place it", M.IsUserPlaced(s) and 1 or 0, 1)

-- ── 13. /nepanels reset clears saved positions ──────────────────────────────
print("\n[13] reset clears saved positions and re-manages everything")
reset()
DragonUI_NewEra.db.windowPos.talents = { point = "TOP", relPoint = "TOP", x = 40, y = -200 }
t = makeWindow("NE_TalentFrame", 900, 600, 1, { "TOP", "TOP", 40, -200 })
check("starts out user-placed", M.IsUserPlaced(t) and 1 or 0, 1)
M.ResetPositions()
check("saved position dropped", DragonUI_NewEra.db.windowPos.talents == nil and 1 or 0, 1)
check("back under management", M.IsUserPlaced(t) and 1 or 0, 0)

-- ── 14. an unknown frame is ignored ─────────────────────────────────────────
print("\n[14] a frame with no DEFAULTS entry is not managed")
reset()
local other = CreateFrame("Frame", "NE_SomethingElse", UIParent)
other:SetSize(300, 300)
other:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
M.Register(other)
check("not registered", M._reg[other] == nil and 1 or 0, 1)

-- ── 15. every shown window user-placed: an EMPTY row is not an error ────────
-- The early-out only counted `shown`, so a screen where the player had placed ALL of the open
-- windows walked into the row layout with nothing to lay out and indexed tile[1] (issue #67). The
-- pcall in M.Reflow kept it out of the client's face, but every later pass died in the same spot,
-- so the next window to open was never tiled at all.
print("\n[15] a row emptied by user placement is a no-op, not a fault (issue #67)")
reset()
M._lastError = nil
a, s = ah(), social()
a:Show(); s:Show()
s:Drag(); a:Drag()             -- the player has now placed BOTH of them
flushTimers()
before = a._anchorCount + s._anchorCount
a:Hide(); a:Show()             -- churn the row so a fresh reflow runs with both shown
flushTimers()
check("no layout error", M._lastError == nil and 1 or 0, 1)
check("neither window repositioned", a._anchorCount + s._anchorCount, before)

print("\n[15b] and the same from db.windowPos alone, with no drag this session")
reset()
M._lastError = nil
DragonUI_NewEra.db.windowPos.talents   = { point = "TOP", relPoint = "TOP", x = 40, y = -200 }
DragonUI_NewEra.db.windowPos.spellbook = { point = "TOP", relPoint = "TOP", x = 0,  y = -55 }
t  = makeWindow("NE_TalentFrame",    900, 600, 1, { "TOP", "TOP", 40, -200 })
sb = makeWindow("NE_SpellBookFrame", 700, 600, 1, { "TOP", "TOP", 0, -55 })
t:Show(); sb:Show()
flushTimers()
check("no layout error on a restored pair", M._lastError == nil and 1 or 0, 1)
-- A third, unplaced window still has to be tiled - the point of not dying is that the pass survives
-- to do this. Two windows are already up, so the AH takes the row start and does not go home.
a = ah()
a:Show()
flushTimers()
_, x = a:Placement()
check("a managed window still tiles alongside them", x, 16)

print("")
if fails == 0 then print("ALL PANELMANAGER CHECKS PASSED") else print(fails .. " FAILURE(S)") end
os.exit(fails == 0 and 0 or 1)
