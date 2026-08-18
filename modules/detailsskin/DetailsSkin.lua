-- DragonUI_NewEra/modules/detailsskin/DetailsSkin.lua — the "New Era" theme for Details! Damage Meter.
--
-- DOWNPORT: ReferenceAddons/NewEra/DetailsSkin/DetailsSkin.lua (Classic 1.15). We ship no damage
-- meter of our own; this makes the one people already run read like RETAIL's. Same intent, same
-- art, same typography — but the source was written against a MODERN Details, and the 3.3.5a
-- backport is Details v8.3.0 build 7269 (ReferenceAddons/Details/boot.lua:5-8, Jan 2020). That
-- version gap IS this port: a third of the keys the source drives do not exist here, three more
-- are on Details' own "a skin may not set this" list, and the one feature the source called its
-- headline (a custom title bar) has no key at all in v8.3.0 and had to be rebuilt from a seam.
--
-- WHAT THE SOURCE DRIVES THAT v8.3.0 DOES NOT HAVE (verified by grep over the backport, then
-- against the authoritative schema in classes/classe_instancia_include.lua — its
-- `instance_defaults` table IS the list of settable cprops):
--   titlebar_shown / titlebar_height / titlebar_texture / titlebar_texture_color
--                     -> ABSENT. The source's whole retail header came from these. Rebuilt via the
--                        skin `callback` seam instead — see DS.DecorateWindow.
--   row_info.row_offsets  -> ABSENT (the source's transparent inset). Folded into row_info.space,
--                        which this version does honour.
--   row_info.text_yoffset -> ABSENT. Dropped; row height + font size carry the look.
--   icon_size_offset      -> ABSENT. Dropped.
--   menu_icons_alpha      -> ABSENT. Dropped.
--   no_cache              -> ABSENT (InstallSkin has no re-install path at all: functions/skins.lua:7
--                        REFUSES a name that already exists). DS.Install clears the slot first.
--   attribute_text.show_timer -> EXISTS but is a THREE-BOOLEAN TABLE here
--                        {raid encounter, battleground, arena}, not the source's plain `true`.
--
-- WHAT A SKIN IS NOT ALLOWED TO SET (Details' own `instance_skin_ignored_values`,
-- classe_instancia_include.lua:29 — ChangeSkin skips these keys, silently): menu_icons,
-- bars_grow_direction, bars_sort_direction, strata, window_scale, total_bar, menu_alpha,
-- auto_hide_menu, grab_on_top, hide_in_combat*. The source sets four of them; they are omitted
-- here rather than left in to look effective. `window_scale` is on that list too, which is how the
-- source came to push it through inst:SetWindowScale() — see undoOurWindowScale for why this port
-- does not set it at all.
--
-- GEOMETRY comes from THIS version, TYPOGRAPHY from the source. The source's toolbar/title anchors
-- were measured against a modern Details header, so they started from the ones v8.3.0's own flat
-- skin uses ("New Gray", functions/skins.lua:2108) and were then worked out against OUR band:
-- every element in this title bar hangs off the corner `ball` textures, not off the window, so
-- the offsets have to absorb where those sit (see menu_anchor and attribute_text.anchor below).
-- The retail *look* — gold FRIZQT title, ARIALN 14 outlined white rows, "N. Name" rank prefix,
-- Compact "value (per-second)" right text, class-coloured bar fill — is the source's.
--
-- ART (Textures/DetailsSkin/, sliced from retail's Blizzard_DamageMeter sheets — same four files
-- the source shipped): header bar, panel bg (~invisible by default), bar fill (class-vertex-
-- coloured), bar shadow bg. Details takes these as LibSharedMedia "statusbar" names, so they are
-- registered before the skin table references them.
--
-- Those four files had to be REPACKED for this client, and it is not optional: 3.3.5a renders a BLP
-- it cannot sample as SOLID BRIGHT GREEN, which is exactly how the whole skin first came up. They
-- arrived from retail cropped to their art (280x28, 248x20, 154x148 — none power-of-two) and
-- without BLP2's 1024-byte palette block. Every BLP that works in this addon is power-of-two with
-- mip 0 at offset 1172; all four are now 256x32 / 128x128 and match that container byte for byte.
-- They are only ever STRETCHED to a frame, so the resample costs nothing visually. See
-- `tools/blp/repack_pot.py`, `Textures/ASSETS.md` §9, and the art assertions in
-- qa/offline/test_detailsskin.lua.
--
-- 3.3.5a API NOTES: no C_AddOns (use NE.IsAddOnLoaded), and no GetPhysicalScreenSize — which the
-- source only needed for the window scale this port does NOT set. See the block above
-- undoOurWindowScale for why that whole step is gone: it is what made the window come up small.

local NE = DragonUI_NewEra
if not NE or NE.disabled then return end
NE.detailsskin = NE.detailsskin or {}
local DS = NE.detailsskin

local SKIN_NAME = "New Era"

local ART     = [[Interface\AddOns\DragonUI_NewEra\Textures\DetailsSkin\]]
local HEADER  = ART .. "7499559-dm-header"
local PANEL   = ART .. "7499559-dm-panel-bg"
local BAR     = ART .. "6704514-dm-bar-fill"
local BAR_BG  = ART .. "7499559-dm-bar-shadowbg"

local MEDIA_HEADER = "NewEra Meter Header"
local MEDIA_PANEL  = "NewEra Meter Panel"
local MEDIA_BAR    = "NewEra Meter Bar"
local MEDIA_BAR_BG = "NewEra Meter Bar BG"

-- The header band sits directly ABOVE the bars frame: every piece of v8.3.0's own title bar anchors
-- its BOTTOM to baseframe's TOP (gumps/janela_principal.lua:8923-8960), and the interactive toolbar
-- strip it draws behind spans ~22px from there. 24 covers it with a pixel to spare.
local HEADER_H = 24

-- The art is NOT a plain band, and this is where "the icons sit too low" came from: measured over
-- 7499559-dm-header.blp's 32 rows (Textures/ASSETS.md §9), the BAR occupies rows 1..26 and rows
-- 27..31 are the soft shadow under it. Stretched into HEADER_H, the bar's centre therefore sits
-- ~1.5px ABOVE the band's own centre, so anything centred on HEADER_H/2 reads as low. Everything in
-- the title bar is positioned off BAR_CENTRE_Y instead.
local ART_ROWS, ART_BAR_TOP, ART_BAR_END = 32, 1, 27          -- ART_BAR_END is exclusive
local BAR_CENTRE_Y = HEADER_H * (ART_BAR_TOP + ART_BAR_END) / 2 / ART_ROWS   -- 10.5 at HEADER_H = 24
-- OWNER NUDGE (2026-08-18): sitting the contents exactly on that midpoint read too HIGH in game, so
-- they are dropped 3.5px below it. Kept as its own term rather than by bending the midpoint's divisor
-- (which was tried, as / 1.5) so the measurement above still means what it says: change this number
-- to move the title and icons together, and ART_BAR_* only if the art itself is re-cut.
local CONTENT_NUDGE_Y = 3.5
BAR_CENTRE_Y = BAR_CENTRE_Y + CONTENT_NUDGE_Y                                -- 14 at HEADER_H = 24

-- The bar's ends fade out over its first/last ~14 of 256 columns — retail's own authoring, so the
-- painted band stops a few percent short of wherever it is stretched to. Hanging the texture this far
-- over each edge puts the ramp outside the frame, so the band reads as reaching it. Owner's number.
local HEADER_OVERHANG = 4

-- Read by qa/offline/test_detailsskin.lua, which checks the title and icons against the same numbers.
DS.HEADER_H, DS.BAR_CENTRE_Y, DS.HEADER_OVERHANG = HEADER_H, BAR_CENTRE_Y, HEADER_OVERHANG

-- Contents of the bar, all measured from BAR_CENTRE_Y and from the ROW geometry rather than from the
-- window: a row spans [left + row_space.left, right] (janela_principal.lua:3909/3917), so its class
-- icon starts at left + 4 and the title has to start there too or the two read as misaligned.
local ROW_INSET_X   = 4                     -- row_info.space.left, below
local BALL_INNER_X  = 21                    -- where `ball`'s bottom-right lands: left + 128 - 107
local BALL_R_INNER_X = 32                   -- where `ball_r`'s bottom-left lands: right - 32
local ICON_SIZE     = 16                    -- one toolbar button at menu_icons_size = 1.0
local TITLE_SIZE    = 13
local floor = math.floor

-- Details is `_detalhes` internally and `Details` as of boot.lua:15. Readiness can't be asked the
-- way the source asked it — v8.3.0 has no Details:IsLoaded() — so we test for the two things we
-- actually use: the installer, and the table it writes into.
local function details()
  local D = _G._detalhes or _G.Details
  if D and type(D.InstallSkin) == "function" and type(D.skins) == "table" then return D end
  return nil
end

-- ============================================================================
-- "THE PLAYER CHOSE THIS SKIN", in our own SavedVariables (DragonUI_NewEraDB).
--
-- Details cannot be relied on to remember it. Its own record is per-window `skin`, and two things
-- happen to that on a reload: a name it cannot find when it restores a window is replaced by the
-- default and WRITTEN BACK (janela_principal.lua:6613-6619), and when the name IS found it takes the
-- `just_updating` path (:6541) that re-applies nothing. Either way the theme does not come back on
-- its own — which is exactly the "doesn't get kept assigned through a reload" report.
--
-- So the choice is recorded here, and DS.Restore re-asserts it after Details has built its windows.
-- It is set when the skin is applied (from the button, or by the player picking it in Details' own
-- dropdown — the ChangeSkin hook sees both) and cleared the moment they pick a different skin, so it
-- follows their intent rather than overriding it.
-- ============================================================================
function DS.SetChosen(v)
  _G.DragonUI_NewEraDB = _G.DragonUI_NewEraDB or {}
  local t = _G.DragonUI_NewEraDB.detailsskin
  if type(t) ~= "table" then t = {}; _G.DragonUI_NewEraDB.detailsskin = t end
  t.chosen = v and true or nil
end

function DS.IsChosen()
  local root = _G.DragonUI_NewEraDB
  local t = root and root.detailsskin
  return (type(t) == "table" and t.chosen) and true or false
end

-- LSM registration: Details drives bar/backdrop textures by MEDIA NAME (a registered "statusbar"),
-- and the names must exist before the skin table references them. LibSharedMedia is not ours — it
-- comes in with Details (classe_instancia_include.lua fetches it unguarded, so it is always there
-- when Details is), which is why this is looked up lazily rather than embedded.
local function registerMedia()
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not (LSM and LSM.Register) then return false end
  pcall(LSM.Register, LSM, "statusbar", MEDIA_HEADER, HEADER .. ".blp")
  pcall(LSM.Register, LSM, "statusbar", MEDIA_PANEL,  PANEL  .. ".blp")
  pcall(LSM.Register, LSM, "statusbar", MEDIA_BAR,    BAR    .. ".blp")
  pcall(LSM.Register, LSM, "statusbar", MEDIA_BAR_BG, BAR_BG .. ".blp")
  return true
end

-- ============================================================================
-- THE HEADER — what titlebar_* would have done.
--
-- v8.3.0 builds its title bar out of four texcoord slices of the skin `file`, and they DO NOT stop
-- at the window's edges (janela_principal.lua:8925-8954, driven by the skin's own corner anchors):
--
--   ball     128 wide, bottom-left pinned 107px LEFT of the window
--   emenda     8 wide, the connector right of it
--   ball_r   128 wide, bottom-right pinned 96px RIGHT of the window
--   top_bg     the centre, stretched between emenda and ball_r
--
-- So Details' own title bar overhangs the frame at both ends, while retail's is exactly the window's
-- width — which is what "a bit of misalignment in the title bar" was: our full-width band with
-- Details' corner caps sticking out past it, the right one visibly so.
--
-- Ours therefore REPLACES those four rather than covering them, and their previous shown state is
-- saved so the hook below can hand them back when the player picks another skin. The toolbar icons,
-- the close button and the title text are separate frames and are left alone.
-- ============================================================================
local HEADER_PIECES = { "ball", "emenda", "ball_r", "top_bg" }

-- Hide Details' own title-bar art (remembering what was shown), or put it back exactly as it was.
local function detailsHeaderShown(inst, shown)
  local cab = inst and inst.baseframe and inst.baseframe.cabecalho
  if not cab then return end
  local saved = inst._neSavedHeader
  if shown then
    if not saved then return end            -- we never hid it; nothing of ours to undo
    for _, key in ipairs(HEADER_PIECES) do
      local piece = cab[key]
      if piece and saved[key] ~= nil then
        if saved[key] then piece:Show() else piece:Hide() end
      end
    end
    inst._neSavedHeader = nil
  else
    if saved then return end                -- already ours; don't overwrite the saved state
    saved = {}
    for _, key in ipairs(HEADER_PIECES) do
      local piece = cab[key]
      if piece then
        saved[key] = (piece.IsShown and piece:IsShown()) and true or false
        piece:Hide()
      end
    end
    inst._neSavedHeader = saved
  end
end

function DS.DecorateWindow(inst)
  local base = inst and inst.baseframe
  if not (base and base.CreateTexture) then return end
  local hdr = base._neMeterHeader
  if not hdr then
    hdr = base:CreateTexture(nil, "OVERLAY")
    base._neMeterHeader = hdr
  end
  hdr:SetTexture(HEADER .. ".blp")
  hdr:ClearAllPoints()
  hdr:SetPoint("BOTTOMLEFT",  base, "TOPLEFT",  -HEADER_OVERHANG, 0)
  hdr:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT",  HEADER_OVERHANG, 0)
  hdr:SetHeight(HEADER_H)
  hdr:Show()
  detailsHeaderShown(inst, false)
end

-- WE DO NOT SET THE WINDOW SCALE. The 1.15 source did — it pinned every Details window to the
-- addon-wide pixel scale so the meter sat on the same grid as its own panels — and porting that
-- straight across made the window visibly small. The arithmetic does not survive the trip:
--
--   NE.FrameUtil.PixelBaseScale() is (768/physicalHeight) x an integer multiplier, so it is BELOW 1
--   on any screen taller than 768 (0.53 at 1440p, 0.71 at 1080p and at 4K). Details' own default
--   window_scale is 1.0, and both numbers reach the same `baseframe:SetScale()`
--   (janela_principal.lua:7692) — so whatever UIParent's scale happens to be, handing Details the
--   pixel base makes its window roughly half to three-quarters of the size it ships at.
--
-- Normalising it against the parent's effective scale, the way core/FrameUtil.lua's PinPixelPerfect
-- does for OUR frames (:107), is not a fix either: it moves the result in whichever direction
-- UIParent's scale points, so it can shrink the window further. Details owns this setting, it has
-- its own scale slider, and its default is the size the player expects — so the skin leaves it
-- alone. What the theme is for is the look, and nothing about the look needs the scale.
--
-- One exception, below: undoing the value the first cut of this module wrote.

-- Put back the 1.0 default IF this addon is what moved the scale off it. An earlier build wrote
-- exactly PixelBaseScale() into window_scale, so that value — and only that value — is ours to
-- reverse; a scale the player chose in Details is theirs and is left as it is. The slider's steps
-- make a genuine collision with our number vanishingly unlikely.
local function undoOurWindowScale(inst)
  if not (inst and inst.SetWindowScale) then return end
  local base = NE.FrameUtil and NE.FrameUtil.PixelBaseScale and NE.FrameUtil.PixelBaseScale()
  local cur = tonumber(inst.window_scale)
  if not (base and cur) then return end
  if math.abs(cur - base) < 1e-4 and math.abs(cur - 1) > 1e-4 then
    pcall(inst.SetWindowScale, inst, 1.0)
  end
end

-- Our header belongs to our skin only. The skin callback fires when a window ENTERS a skin, never
-- when it leaves, so switching to someone else's skin would otherwise leave our band sitting on it.
-- ChangeSkin is plain insecure addon code, so a post-hook is enough; it touches nothing but our own
-- texture, and instances inherit it (boot.lua:39 sets `_detalhes.__index = _detalhes`).
local function hookChangeSkin(D)
  if DS._hookedChangeSkin or type(D.ChangeSkin) ~= "function" then return end
  DS._hookedChangeSkin = true
  local orig = D.ChangeSkin
  D.ChangeSkin = function(self, skinName, ...)
    local asked = skinName or (type(self) == "table" and self.skin) or nil
    local installed = D.skins and D.skins[SKIN_NAME] ~= nil
    local a, b, c = orig(self, skinName, ...)
    if type(self) ~= "table" then return a, b, c end

    local wearingOurs = (self.skin == SKIN_NAME)
    local base = self.baseframe
    local hdr = base and base._neMeterHeader
    if hdr and not wearingOurs then hdr:Hide() end
    if not wearingOurs then detailsHeaderShown(self, true) end   -- give Details its title bar back

    -- Remember the player's choice, so a reload can put it back (see DS.Restore). Only trust this
    -- when our skin was actually installed at the time: the "skin not found" path also comes through
    -- here, asking for OUR name and landing on the default, and that is Details forgetting rather
    -- than the player choosing.
    if installed then
      if wearingOurs then
        DS.SetChosen(true)
      elseif asked ~= SKIN_NAME then
        DS.SetChosen(false)
      end
    end
    return a, b, c
  end
end

-- ============================================================================
-- THE SKIN TABLE. Only keys this Details version reads, and none it refuses from a skin.
-- ============================================================================
local function skinTable()
  return {
    -- Details' own chrome-less sheet: the window frame art we are NOT using (the retail meter has
    -- no frame). Our header is drawn over the flat band it leaves behind.
    file    = [[Interface\AddOns\Details\images\skins\flat_skin.blp]],
    author  = "DragonUI New Era",
    version = "1.0",
    site    = "https://github.com/ghbset/DragonUI_NewEra",
    desc    = "New Era — retail damage-meter look, with art from retail's Blizzard_DamageMeter. "
           .. "Skin-key structure adapted from Details_TWW (MIT, Karl-Heinz Schneider).",

    micro_frames = { color = { 1, 1, 1, 1 }, font = "Arial Narrow", size = 10, textymod = 1 },
    can_change_alpha_head = true,
    icon_anchor_main    = { -1, -5 },
    icon_anchor_plugins = { -7, -13 },
    icon_plugins_size   = { 19, 18 },
    icon_point_anchor        = { -37, 0 },
    left_corner_anchor       = { -107, 0 },
    right_corner_anchor      = { 96, 0 },
    icon_point_anchor_bottom  = { -37, 12 },
    left_corner_anchor_bottom = { -107, 0 },
    right_corner_anchor_bottom = { 96, 0 },
    icon_on_top      = true,
    icon_ignore_alpha = true,
    icon_titletext_position = { 3, 3 },

    instance_cprops = {
      -- ── OPACITY: retail reads as floating bars — panel ~invisible, no bottom status bar. ──
      color = { 0.094, 0.094, 0.094, 0 },
      bg_r = 0.094, bg_g = 0.094, bg_b = 0.094, bg_alpha = 0,
      backdrop_texture = MEDIA_PANEL,
      show_statusbar = false,
      statusbar_info = { alpha = 0, overlay = { 0.094, 0.094, 0.094 } },
      show_sidebars = false,
      wallpaper = { enabled = false },
      hide_icon = true,          -- retail has no instance icon at the window's top-left
      -- NOT SET, and deliberately: strata / bars_grow_direction / menu_icons are on Details'
      -- instance_skin_ignored_values, so a skin writing them changes nothing. The source wrote all
      -- three.

      -- ── TOOLBAR + TITLE: v8.3.0 geometry (its own flat skin's numbers). ──
      toolbar_side = 1,
      -- The icon row anchors TOPLEFT to ball_r's BOTTOMLEFT with (x, y + 16)
      -- (janela_principal.lua:7959), so it occupies top+y .. top+y+16, and with side = 2 the first
      -- (rightmost) button lands there and the rest chain leftwards (:5453).
      --
      -- y centres the 16px row on the BAR (see BAR_CENTRE_Y) — centring it on the band instead is
      -- what left the icons sitting low. ball_r's bottom-left is at the window's right edge - 32 and
      -- the rightmost button is 16 wide, so the cluster ends at right - 32 + x + 16; x below leaves
      -- the same 4px margin the title has on the left. (At x = 16 it sat flush against the edge, with
      -- nothing to spare for the plugin icons.)
      menu_anchor = { BALL_R_INNER_X - ICON_SIZE - ROW_INSET_X, floor(BAR_CENTRE_Y - ICON_SIZE / 2),
                      side = 2 },
      -- Plugin icons (a separator, then one per plugin that has a toolbar icon) chain off the menu
      -- row. Details' default is 2 = rightwards, which walks them straight off the window: its own
      -- skins have 96px of ball_r art out there to sit on, ours stops at the edge, so a plugin's
      -- skull hung outside the band. 1 = leftwards (:5549) keeps them on it, and no fixed offset can
      -- be overflowed by however many plugins the player enables.
      plugins_grow_direction = 1,
      instance_button_anchor = { -27, 1 },
      menu_icons_size = 1.0,
      desaturated_menu = false,
      color_buttons = { 1, 1, 1, 1 },
      -- Gold title text (retail's GameFontNormalMed1 colour), anchored bottom-left of the header
      -- band. The anchor is measured off the left ball's bottom-right corner
      -- (janela_principal.lua:1030), which lands ~3px inside baseframe's left edge.
      attribute_text = {
        enabled = true, side = 1, shadow = true,
        show_timer = { true, true, true },   -- raid encounter / battleground / arena
        text_size = TITLE_SIZE, text_face = "Friz Quadrata TT",
        text_color = { 1, 0.82, 0, 1 },
        custom_text = "{name}", enable_custom_text = false,
        -- Anchored BOTTOMLEFT to ball's BOTTOMRIGHT (:1030). x puts the text's left edge exactly on
        -- the row's — i.e. on the class icon's — rather than 4px right of it, which is what showed up
        -- as the title not lining up with the icon. y centres it on the bar art, not on the band.
        anchor = { ROW_INSET_X - BALL_INNER_X, floor(BAR_CENTRE_Y - TITLE_SIZE / 2) },
      },

      row_info = {
        texture      = MEDIA_BAR,
        texture_file = BAR .. ".blp",
        texture_class_colors = true,            -- class-vertex-coloured, like retail
        texture_background      = MEDIA_BAR_BG,
        texture_background_file = BAR_BG .. ".blp",
        texture_background_class_color = false,
        fixed_texture_color = { 0, 0, 0 },
        fixed_texture_background_color = { 1, 1, 1, 1 },   -- show the shadow art as authored
        texture_highlight = "Interface\\FriendsFrame\\UI-FriendsList-Highlight",
        -- Retail row is ~25px. The source's row_offsets inset (the transparent gap under the
        -- header and at the margins) has no key here, so it comes out of `space` instead.
        height = 25,
        space = { left = ROW_INSET_X, right = -4, between = 4 },
        alpha = 1,
        -- Icons: Details' class discs on the left, the retail-ish arrangement.
        no_icon = false,
        icon_file = "Interface\\AddOns\\Details\\images\\classes_small",
        icon_offset = { 0, 0 },
        start_after_icon = true,
        -- Spec icons OFF, unlike the source: this client has no specialisations for Details to
        -- read, so the spec sheet has nothing to select and class icons are the honest answer.
        use_spec_icons = false,
        -- Text: ARIALN 14 outlined white; "1. Name" left, retail Compact "value (persec)" right.
        font_face = "Arial Narrow",
        font_face_file = "Fonts\\ARIALN.TTF",
        font_size = 14,
        textL_show_number = true,
        textL_outline = true,
        textL_class_colors = false,
        textL_enable_custom_text = false,
        textR_outline = true,
        textR_class_colors = false,
        textR_enable_custom_text = true,
        textR_custom_text = "{data1} ({data2})",
        textR_separator = ",",
        percent_type = 1,
      },
    },

    -- Runs when a window enters this skin. Details calls it through setfenv with a filtered
    -- environment (janela_principal.lua:6814), so it does nothing itself but hand the window to us.
    callback = function(skin, instance, just_updating)
      local ne = _G.DragonUI_NewEra
      if ne and ne.detailsskin and ne.detailsskin.DecorateWindow then
        ne.detailsskin.DecorateWindow(instance)
      end
    end,
  }
end

-- Install (or re-install) the skin. v8.3.0's InstallSkin refuses a name that already exists and has
-- no `no_cache`, so `force` clears the slot first — that is how an edited table takes effect without
-- a full client restart, and it is immediately followed by the install so nothing sees an empty slot.
function DS.Install(force)
  local D = details()
  if not D then return false end
  registerMedia()
  hookChangeSkin(D)
  if D.skins[SKIN_NAME] and not force then return true end
  if force then D.skins[SKIN_NAME] = nil end
  local ok, installed = pcall(D.InstallSkin, D, SKIN_NAME, skinTable())
  return (ok and installed) and true or false
end

-- Full push: install, switch every window to the skin, and write the profile variables a skin cannot
-- express. Called from the options button and /nedetails — NEVER automatically: a Details profile is
-- the player's own data, and this overwrites part of it. Re-run it to re-apply after they customise
-- something.
function DS.Apply()
  local D = details()
  if not D then return false end
  DS.Install(true)
  DS.SetChosen(true)   -- so a reload can put it back (Details will not; see DS.Restore)

  -- Retail's K/M abbreviation. Value 2 is the "305.500 -> 305.5K" formatter
  -- (gumps/janela_options.lua:4043), and v8.3.0 caches the chosen formatter per attribute, so the
  -- change does not show until UpdateToKFunctions re-selects it.
  D.ps_abbreviation, D.total_abbreviation = 2, 2
  if type(D.UpdateToKFunctions) == "function" then pcall(D.UpdateToKFunctions, D) end

  local applied = 0
  for i = 1, ((type(D.GetNumInstancesAmount) == "function" and D:GetNumInstancesAmount()) or 0) do
    local inst = D.GetInstance and D:GetInstance(i)
    if inst and inst.ChangeSkin then
      pcall(inst.ChangeSkin, inst, SKIN_NAME)
      -- ChangeSkin skips the skin callback when the window is ALREADY on this skin
      -- (janela_principal.lua:6814 `if not just_updating`), so the header is (re)built from here
      -- too — otherwise a second Apply, or Apply on a window already wearing the skin, gets no
      -- header at all.
      DS.DecorateWindow(inst)
      undoOurWindowScale(inst)
      applied = applied + 1
    end
  end
  return applied > 0
end

-- Put the theme back after a reload, once Details has built its windows.
--
-- Two cases, and the difference matters: a window that still NAMES our skin only needs its header
-- (Details' restore takes the `just_updating` path and runs no callback, so nothing of ours is
-- drawn), while a window whose name Details replaced with the default has to be switched back — and
-- only if the player's recorded choice says so. A window on someone else's skin, chosen by them, is
-- never touched.
--
-- Idempotent: safe to call repeatedly, which is what the staggered login passes below do.
function DS.Restore()
  local D = details()
  if not D then return false end
  DS.Install()
  local chosen = DS.IsChosen()
  local restored = 0
  for i = 1, ((type(D.GetNumInstancesAmount) == "function" and D:GetNumInstancesAmount()) or 0) do
    local inst = D.GetInstance and D:GetInstance(i)
    if inst and inst.baseframe then
      if inst.skin == SKIN_NAME then
        DS.DecorateWindow(inst)
        restored = restored + 1
      elseif chosen and inst.ChangeSkin then
        pcall(inst.ChangeSkin, inst, SKIN_NAME)
        DS.DecorateWindow(inst)
        restored = restored + 1
      end
    end
  end
  return restored > 0
end

function DS.IsDetailsLoaded()
  return NE.IsAddOnLoaded and NE.IsAddOnLoaded("Details") or false
end

-- ============================================================================
-- BOOT — install EARLY, then restore once Details has its windows up.
--
-- INSTALL EARLY is not cosmetic timing: when Details restores a window it calls ChangeSkin() with the
-- saved name, and a name it cannot find is replaced by the default AND WRITTEN BACK over the player's
-- choice (janela_principal.lua:6613-6619). Registering late loses the setting, not just the look.
-- "Details" sorts before "DragonUI_NewEra", so its skins table is normally already there when this
-- file runs and the first call is the one that counts; the events cover a load order that puts it
-- after us.
--
-- THE LOGIN MESSAGE IS EXPECTED, and is not worth chasing again. Details reads its profile inside
-- its OWN ADDON_LOADED (start_details -> LoadConfig -> ApplyProfile -> AtivarInstancia ->
-- InstanceColor, janela_principal.lua:5064), where a skin name it cannot find prints
--   "Skin New Era not found, changing to 'Minimalistic'."
-- and writes that name back. "Details" sorts before "DragonUI_NewEra", so its files run and that
-- handler fires BEFORE the first line of this file executes — no install of ours, however early,
-- can beat it, and the message cannot be suppressed from here either. Only an addon whose folder
-- sorts before "Details" could register in time (its ADDON_LOADED handler would run before
-- Details' own); that was weighed and declined, since the restore below fixes the outcome and the
-- notice is Details' own diagnostic rather than a fault. Owner decision, 2026-08-18.
--
-- RESTORE AFTER is the other half, and it is why the theme did not survive a reload even with the
-- skin installed in time: when Details DOES find the name, ChangeSkin takes its `just_updating` path
-- (:6541) and re-applies nothing at all — no cprops, and no skin callback — so our header never gets
-- drawn. Nothing about that is observable from the skin table, so the module re-asserts it itself.
--
-- The passes are staggered because Details builds its windows in Details:Start() on ITS PLAYER_LOGIN
-- handler, registered when Details loaded — i.e. before ours, so normally already done by the time we
-- run. The later passes are for the cases where it is not (a slow load, or its own deferred work).
-- DS.Restore is idempotent, and with nothing to do it is a loop over one or two windows.
-- ============================================================================
DS.Install()

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(_, event, addon)
  if event == "ADDON_LOADED" and addon ~= "Details" then return end
  DS.Install()
  if event ~= "PLAYER_LOGIN" then return end
  DS.Restore()
  if C_Timer and C_Timer.After then
    C_Timer.After(1, DS.Restore)
    C_Timer.After(5, DS.Restore)   -- last word, after Details' own deferred startup work
  end
end)
