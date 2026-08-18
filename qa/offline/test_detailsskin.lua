-- qa/offline/test_detailsskin.lua — offline harness for the Details! theme (modules/detailsskin).
--
--   luajit qa/offline/test_detailsskin.lua        (from the addon root)
--
-- The skin cannot be checked by reading it: whether a key does anything depends entirely on the
-- Details version underneath, and the 3.3.5a backport is v8.3.0 — old enough that a third of what
-- the 1.15 source set is either absent or on Details' own "a skin may not set this" list. A syntax
-- gate sees none of that. So the fake Details below is modelled on the INSTALLED backport
-- (ReferenceAddons/Details), and reproduces the three behaviours the port had to be written around:
--
--   * InstallSkin REFUSES a name that already exists (functions/skins.lua:7) and there is no
--     `no_cache`, so re-installing means clearing the slot first;
--   * ChangeSkin skips the skin callback when the window is already wearing that skin
--     (janela_principal.lua:6814), which is why Apply builds the header itself as well;
--   * an unknown skin name falls back to the default AND IS WRITTEN BACK over the player's saved
--     choice (janela_principal.lua:6613-6619) — the reason the skin installs at file load.
--
-- The assertions on the skin table are the version contract: each names a key that must NOT be
-- there, so a future edit that copies more of the 1.15 source back in fails here instead of
-- silently doing nothing in game.
local ADDON = (arg and arg[0] or ""):match("^(.*)qa/offline/[^/]+$") or "./"

local fails, checks = 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FAIL  " .. what) else print("ok    " .. what) end
end

-- ── client stubs ────────────────────────────────────────────────────────────
local function newTexture()
  local t = { _shown = true, _points = {} }
  function t:SetTexture(f) self._file = f end
  function t:SetTexCoord() end
  function t:ClearAllPoints() self._points = {} end
  function t:SetPoint(...) self._points[#self._points + 1] = { ... } end
  function t:SetHeight(h) self._h = h end
  function t:Show() self._shown = true end
  function t:Hide() self._shown = false end
  return t
end

local frames = {}
function CreateFrame(kind, name, parent)
  local f = { _events = {}, _scripts = {} }
  function f:RegisterEvent(e) self._events[e] = true end
  function f:SetScript(s, fn) self._scripts[s] = fn end
  function f:CreateTexture(n, layer) local t = newTexture(); t._layer = layer; return t end
  frames[#frames + 1] = f
  return f
end

-- Details' own title bar: four texcoord slices of the skin sheet, and they overhang the window at
-- both ends (ball 107px left of it, ball_r 96px right). `ball` ships hidden, the other three shown —
-- janela_principal.lua:8925-8954.
local function newCabecalho()
  local cab = {}
  for _, key in ipairs({ "ball", "emenda", "ball_r", "top_bg" }) do
    local t = newTexture()
    t._shown = (key ~= "ball")
    function t:IsShown() return self._shown end
    cab[key] = t
  end
  return cab
end

local media = {}
LibStub = setmetatable({}, { __call = function(_, name, silent)
  if name == "LibSharedMedia-3.0" then
    return { Register = function(self, kind, key, file) media[key] = { kind, file }; return true end }
  end
  return nil
end })

-- ── our addon stubs ─────────────────────────────────────────────────────────
DragonUI_NewEra = {
  L = setmetatable({}, { __index = function(_, k) return k end }),
  IsAddOnLoaded = function(n) return n == "Details" end,
  FrameUtil = { PixelBaseScale = function() return 0.7111 end },
}
local NE = DragonUI_NewEra

-- ── Details v8.3.0 stub: the API surface the port actually uses ──────────────
local D = { skins = {}, ps_abbreviation = 3, total_abbreviation = 2 }
D.__index = D            -- boot.lua:39 — instances inherit from _detalhes
function D:InstallSkin(name, tbl)
  if not name or self.skins[name] then return false end
  if not tbl.file then return false end
  self.skins[name] = tbl
  return true
end
local tokUpdates = 0
function D:UpdateToKFunctions() tokUpdates = tokUpdates + 1 end
function D:GetNumInstancesAmount() return #self.instances end
function D:GetInstance(i) return self.instances[i] end
-- ChangeSkin: the two behaviours that matter — the just_updating guard on the callback, and the
-- fallback WRITING BACK over an unknown skin name (janela_principal.lua:6613-6619).
function D:ChangeSkin(name)
  name = name or self.skin
  local skin = D.skins[name]
  local just_updating = (self.skin == name)
  if not skin then name = "WoW Interface"; skin = D.skins[name] end
  self.skin = name
  if skin and skin.callback and not just_updating then skin.callback(skin, self, just_updating) end
end
function D:SetWindowScale(s) self.window_scale = s end
D.instances = {}
local function newInstance(i, skin)
  local base = CreateFrame("Frame")
  base.cabecalho = newCabecalho()
  return setmetatable({ meu_id = i, baseframe = base, skin = skin }, D)
end
for i = 1, 2 do
  D.instances[i] = newInstance(i, "New Era")
end
D.skins["WoW Interface"] = { file = "x.blp" }
_detalhes = D
Details = D

-- ── load the port ───────────────────────────────────────────────────────────
assert(loadfile(ADDON .. "modules/detailsskin/DetailsSkin.lua"))()
local DS = NE.detailsskin

-- 1. load-time install (must happen before Details restores its windows)
ok(D.skins["New Era"] ~= nil, "skin installed at file load")
ok(media["NewEra Meter Bar"] ~= nil and media["NewEra Meter Header"] ~= nil, "LSM media registered")

-- 2. skin table only carries keys this Details version honours
local st = D.skins["New Era"]
local cp = st.instance_cprops
for _, dead in ipairs({ "titlebar_shown", "titlebar_texture", "titlebar_height", "strata",
                        "menu_icons", "bars_grow_direction", "menu_icons_alpha" }) do
  ok(cp[dead] == nil, "cprops omits " .. dead .. " (absent or skin-ignored in v8.3.0)")
end
ok(st.no_cache == nil, "no_cache dropped (not a v8.3.0 key)")
ok(cp.row_info.row_offsets == nil and cp.row_info.text_yoffset == nil, "row_info drops absent keys")
ok(type(cp.attribute_text.show_timer) == "table" and #cp.attribute_text.show_timer == 3,
   "show_timer is v8.3.0's three-boolean table")
ok(cp.row_info.use_spec_icons == false, "spec icons off (no specs on this client)")

-- 2b. THE SHIPPED ART, as a container check — this is what the first cut got wrong.
--
-- The client renders a BLP it cannot sample as SOLID BRIGHT GREEN, no error: the whole skin came up
-- green because these four regions arrived from retail cropped to their art (280x28, 248x20, …) and
-- written without BLP2's palette block. Both are invisible in the Lua and invisible to a syntax
-- gate, so they are asserted here against the two rules every working BLP in this addon follows:
-- power-of-two on both axes, and mip 0 starting at 1172 (148-byte header + the 1024-byte palette).
-- `tools/blp/repack_pot.py` is what fixes a file that fails this.
local function blpHeader(rel)
  local fh = io.open(ADDON .. rel, "rb")
  if not fh then return nil end
  local raw = fh:read(148)
  fh:close()
  if not raw or #raw < 148 or raw:sub(1, 4) ~= "BLP2" then return nil end
  -- Lua 5.1 has no string.unpack; these are little-endian uint32s.
  local function u32(at)
    local a, b, c, d = raw:byte(at, at + 3)
    return a + b * 256 + c * 65536 + d * 16777216
  end
  return { comp = raw:byte(9), w = u32(13), h = u32(17), off0 = u32(21), size0 = u32(85) }
end

local function isPOT(n)
  if n < 1 then return false end
  while n > 1 do
    if n % 2 ~= 0 then return false end
    n = n / 2
  end
  return true
end

for _, art in ipairs({ "7499559-dm-header", "7499559-dm-panel-bg",
                       "7499559-dm-bar-shadowbg", "6704514-dm-bar-fill" }) do
  local h = blpHeader("Textures/DetailsSkin/" .. art .. ".blp")
  ok(h ~= nil, art .. ".blp is present and is a BLP2 file")
  if h then
    ok(isPOT(h.w) and isPOT(h.h),
       ("%s is power-of-two (%dx%d)"):format(art, h.w, h.h))
    ok(h.off0 == 1172, ("%s carries the palette block (mip 0 at %d)"):format(art, h.off0))
    ok(h.size0 == h.w * h.h * 4 and h.comp == 3,
       art .. " is one uncompressed BGRA mip of the declared size")
  end
end

-- 2c. TITLE-BAR GEOMETRY, as arithmetic rather than as a screenshot.
--
-- Nothing in this bar is positioned relative to the window, and the band is not a plain rectangle:
--   * the title anchors BOTTOMLEFT to `ball`'s BOTTOMRIGHT, which lands at the window's left + 21
--     (janela_principal.lua:1030);
--   * the icon row anchors TOPLEFT to `ball_r`'s BOTTOMLEFT (right - 32) with y + 16 (:7959), and
--     the rightmost button is 16 wide;
--   * a row spans [left + space.left, right] (:3909/:3917), so its class icon starts at left + 4;
--   * and the header ART is a bar over rows 1..26 of 32 with a shadow below it, so the bar's centre
--     is ABOVE the band's centre.
-- Each of those bit us in turn: the title 4px right of the class icon, and the icons sitting low
-- because they were centred on the band. The checks below are that arithmetic, so the next edit to
-- any one number has to keep the relationships.
local band, barCentre = DS.HEADER_H, DS.BAR_CENTRE_Y
local ROW_INSET = cp.row_info.space.left

local iconsY = cp.menu_anchor[2]                       -- icons occupy top+y .. top+y+16
local iconsCentre = iconsY + 8
local titleY = cp.attribute_text.anchor[2]
local titleCentre = titleY + cp.attribute_text.text_size / 2
ok(math.abs(iconsCentre - barCentre) <= 1,
   ("the icon row is centred on the BAR, not the band (%.1f vs bar %.1f, band %.1f)")
     :format(iconsCentre, barCentre, band / 2))
ok(math.abs(titleCentre - barCentre) <= 1,
   ("the title is centred on the BAR (%.1f vs %.1f)"):format(titleCentre, barCentre))
ok(iconsY >= 0 and iconsY + 16 <= band, "the icon row fits inside the header band")
ok(titleY >= 0 and titleY + cp.attribute_text.text_size <= band, "the title fits inside the band")

-- Horizontal: the title's left edge must land ON the row's, since that is where the class icon the
-- player compares it against starts.
local titleX = cp.attribute_text.anchor[1] + 21        -- ball's inner corner
ok(titleX == ROW_INSET,
   ("the title starts on the class icon's edge (title %d, row %d)"):format(titleX, ROW_INSET))
-- And the icon cluster's right margin: right - 32 + x + 16 from the window's right edge.
local iconMargin = 32 - cp.menu_anchor[1] - 16
ok(iconMargin == ROW_INSET,
   ("the icon row's right margin matches the row inset (%dpx)"):format(iconMargin))
-- Plugin icons chain off the menu row; Details' default walks them RIGHT, off a window whose header
-- art (unlike its own skins') stops at the edge. 1 = leftwards, so the number of plugins enabled
-- cannot push anything outside the band.
ok(cp.plugins_grow_direction == 1, "plugin icons grow leftwards, inwards from the menu row")

-- 3. Apply: skin on every window, K/M abbreviation re-selected — and the window SIZE left alone.
--
-- The size is the other thing the first cut got wrong, and it was reported as "such a small window".
-- PixelBaseScale() is (768/physicalHeight) x an integer multiplier, so it is always below 1 on a
-- screen taller than 768, while Details' own default window_scale is 1.0 — both going into the same
-- baseframe:SetScale(). Pushing the pixel base therefore shrinks the window to 53-71% of the size it
-- ships at, whatever UIParent's scale is. Details owns this setting; the theme must not touch it.
D.instances[1].window_scale = 1.0          -- Details' default, untouched by the player
D.instances[2].window_scale = 0.9          -- a size the PLAYER chose
ok(DS.Apply() == true, "Apply reports success")
ok(D.ps_abbreviation == 2 and D.total_abbreviation == 2, "K/M abbreviation set")
ok(tokUpdates >= 1, "UpdateToKFunctions called (v8.3.0 caches the formatter)")
for i, inst in ipairs(D.instances) do
  ok(inst.skin == "New Era", "window " .. i .. " wears the skin")
  ok(inst.baseframe._neMeterHeader ~= nil, "window " .. i .. " got the header texture")
  ok(inst.baseframe._neMeterHeader._shown == true, "window " .. i .. " header shown")
end
ok(D.instances[1].window_scale == 1.0, "Apply leaves Details' default window scale at 1.0")
ok(D.instances[2].window_scale == 0.9, "Apply leaves a player-chosen window scale alone")

-- 3b. …but it DOES undo the one value an earlier build of this module wrote: exactly
-- PixelBaseScale(). That number is ours, so Apply puts the window back to Details' 1.0 default and
-- the shrunken window repairs itself instead of needing a slash command.
D.instances[1].window_scale = 0.7111       -- what the first cut wrote
D.instances[2].window_scale = 0.7112       -- one slider step away: NOT ours, must survive
DS.Apply()
ok(D.instances[1].window_scale == 1.0, "Apply resets the scale the earlier build wrote")
ok(D.instances[2].window_scale == 0.7112, "a near-miss scale is treated as the player's and kept")

-- 4. a second Apply still (re)builds the header, even though ChangeSkin skips the callback
D.instances[1].baseframe._neMeterHeader = nil
DS.Apply()
ok(D.instances[1].baseframe._neMeterHeader ~= nil, "re-Apply rebuilds the header (just_updating path)")

-- 4a. The band hangs over both edges by HEADER_OVERHANG, so the ends the art fades out over sit
-- outside the frame and the painted bar reads as reaching it.
local hdrPoints = D.instances[1].baseframe._neMeterHeader._points
local leftPt = hdrPoints[1]
local rightPt = hdrPoints[2]
ok(leftPt[1] == "BOTTOMLEFT" and leftPt[4] == -DS.HEADER_OVERHANG,
   ("the band hangs %dpx past the left edge"):format(DS.HEADER_OVERHANG))
ok(rightPt[1] == "BOTTOMRIGHT" and rightPt[4] == DS.HEADER_OVERHANG,
   ("the band hangs %dpx past the right edge"):format(DS.HEADER_OVERHANG))

-- 4b. Details' own title bar is REPLACED, not covered: its corner pieces overhang the window (ball
-- 107px left, ball_r 96px right) while ours is exactly the window's width, and the caps sticking out
-- past it were the reported "misalignment in the title bar".
local cab1 = D.instances[1].baseframe.cabecalho
ok(cab1.top_bg._shown == false and cab1.emenda._shown == false and cab1.ball_r._shown == false,
   "Details' own title-bar pieces are hidden under our header")

-- 5. switching to another skin takes our header off it AND hands Details its title bar back, in the
-- state it was in (ball ships hidden, the other three shown) — nothing of theirs is left broken.
D.instances[1]:ChangeSkin("WoW Interface")
ok(D.instances[1].baseframe._neMeterHeader._shown == false, "header hidden when another skin is picked")
ok(cab1.top_bg._shown == true and cab1.emenda._shown == true and cab1.ball_r._shown == true,
   "Details' title-bar pieces come back when another skin is picked")
ok(cab1.ball._shown == false, "a piece that was already hidden stays hidden (prior state restored)")
ok(DS.IsChosen() == false, "picking another skin clears the remembered choice")
D.instances[1]:ChangeSkin("New Era")
ok(D.instances[1].baseframe._neMeterHeader._shown == true, "header returns with our skin")
ok(DS.IsChosen() == true, "picking our skin in Details' own dropdown records the choice")

-- 5b. RELOAD. Details forgets the theme in two different ways, and neither is visible from the skin
-- table, so DS.Restore has to cover both:
--
--   * the name SURVIVED — ChangeSkin then takes its `just_updating` path and re-applies nothing at
--     all, no cprops and no callback, so our header is simply never drawn;
--   * the name was LOST — our skin was not installed yet when Details restored the window, so it fell
--     back to the default and wrote that back over the player's choice.
local function reload(skins)
  D.instances = {}
  for i, s in ipairs(skins) do D.instances[i] = newInstance(i, s) end
end

reload({ "New Era" })                       -- name survived, nothing drawn
ok(D.instances[1].baseframe._neMeterHeader == nil, "after a reload the window has no header yet")
ok(DS.Restore() == true, "Restore reports work done")
ok(D.instances[1].baseframe._neMeterHeader ~= nil, "Restore draws the header on a window still on our skin")
ok(D.instances[1].baseframe.cabecalho.top_bg._shown == false, "Restore also re-hides Details' title bar")

reload({ "WoW Interface" })                 -- name lost to the fallback; the choice is still recorded
ok(DS.IsChosen() == true, "the recorded choice survives Details forgetting")
DS.Restore()
ok(D.instances[1].skin == "New Era", "Restore puts the skin back when the player had chosen it")

DS.SetChosen(false)                         -- the player is on another skin ON PURPOSE
reload({ "WoW Interface" })
ok(DS.Restore() == false, "Restore does nothing when our skin was not the player's choice")
ok(D.instances[1].skin == "WoW Interface", "a skin the player picked is left alone across a reload")
DS.SetChosen(true)
reload({ "New Era" })
DS.Restore()

-- 6. force re-install replaces the table (no no_cache in this version)
local before = D.skins["New Era"]
DS.Install(true)
ok(D.skins["New Era"] ~= nil and D.skins["New Era"] ~= before, "Install(true) replaces the skin table")

-- 7. no Details -> everything degrades quietly
_detalhes, Details = nil, nil
ok(DS.Install() == false, "Install is a no-op without Details")
ok(DS.Apply() == false, "Apply is a no-op without Details")
ok(pcall(DS.DecorateWindow, nil) == true, "DecorateWindow tolerates nil")

print(("\n%d checks, %d failures"):format(checks, fails))
os.exit(fails == 0 and 0 or 1)
