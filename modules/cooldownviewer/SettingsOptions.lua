-- DragonUI_NewEra/modules/cooldownviewer/SettingsOptions.lua — the /cdm Settings tab.
--
-- Every Cooldown Manager setting lives here, which is the point: retail's Cooldown Manager settings
-- sit IN the Cooldown Manager, and until now ours sat in DragonUI's options panel — a different
-- window, reached by a different path (PORT_PLAN §G.10).
--
-- WHAT MOVED, AND WHAT DID NOT. The DragonUI options section keeps exactly two things: the master
-- enable toggle (that panel is where a player goes to turn a module OFF, and it is read-only to us —
-- CONTRACTS §0, we register a section, we do not own the window) and a button that opens this one.
-- Everything else — the ten per-viewer settings, the two bar-only settings and buff auto-tracking — is
-- here, once. No stored VALUE is rendered in two windows: two views onto one store stay in sync only
-- as long as both are rebuilt on show, and the first time one is not, the player is looking at a stale
-- value with no way to tell. (Actions are a different matter — see the Reset section below.)
--
-- Frame POSITION stays with the movers (`/dui edit`) — §B1's decision, unchanged. It is the one
-- setting that is not a value in this store.
--
-- THE PAGE IS NOT A CATEGORY. It is a second scroll child beside `panel.content`, swapped in by
-- SetDisplayMode (§G.10's option (a)). The alternative — a "category" whose renderer draws controls —
-- would put widget layout behind an adapter whose entire contract is "return a list of spellIDs",
-- and every consumer of that list (ApplyItemFilter, the drag path, RestackCategories) would grow a
-- not-a-grid branch.
--
-- BUILT LAZILY, on the first switch to this tab: ~60 frames that a player who never opens the tab
-- should not pay for.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

NE.cooldownviewersettings = NE.cooldownviewersettings or {}
local CDS = NE.cooldownviewersettings

local PAGE_W = 330

-- Ordered, unlike the options tab's value->label maps: those go to AceGUI, which sorts them, and a
-- radio menu has to pick its own order. "Always / In Combat / Hidden" reads as a progression.
local ORIENTATION = { { "horizontal", "Horizontal" }, { "vertical", "Vertical" } }
local DIRECTION   = { { "right", "Right" }, { "left", "Left" } }
local VISIBILITY   = { { "always", "Always" }, { "incombat", "In Combat" }, { "hidden", "Hidden" } }
local BAR_CONTENT  = { { "iconAndName", "Icon and Name" }, { "iconOnly", "Icon Only" },
                       { "nameOnly", "Name Only" } }
local TRACK_DEST   = { { "both", "Icons and bars" }, { "icon", "Icons only" }, { "bar", "Bars only" } }

local function pct(v) return tostring(v) .. "%" end
local function px(v)  return tostring(v) .. " px" end

local function say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1Cooldown Manager|r " .. msg) end
end

-- ── "Position this viewer" ──────────────────────────────────────────────────────────────────────
-- The last unported piece of upstream's panel: its cog menu carried an "Edit Mode" entry that hid the
-- window and toggled retail Edit Mode (Panel.lua:211). §G.4 left it as "drop it or route it at
-- /dui edit" and never decided. Routed, and improved on: because DragonUI's editor can be told which
-- frame to select, the affordance belongs per viewer rather than once globally — the button that sits
-- under Buff Bars' sliders opens the editor with Buff Bars selected, coordinates and Reset included.
--
-- The panel closes only on SUCCESS. Hiding first and then failing (no editor, or in combat) would take
-- the window away and leave the player with nothing to show why.
local function positionViewer(category)
  local frame = M.viewers and M.viewers[category]
  if not frame then
    say("that viewer doesn't exist yet — it builds at login.")
    return
  end
  if not NE.OpenFrameEditor then
    say("editor mode isn't available in this DragonUI build. Type /dui edit to position frames.")
    return
  end
  local ok, why = NE.OpenFrameEditor(frame)
  if not ok then
    say(why or "editor mode couldn't be opened.")
    return
  end
  -- Editor mode covers the screen and the viewer being positioned may sit under this window.
  if CDS.HidePanel then CDS.HidePanel() end
end
CDS.PositionViewer = positionViewer   -- test seam

-- ── One viewer's block ──────────────────────────────────────────────────────────────────────────

local function buildViewerSection(col, spec)
  local frameID = M.FRAME_ID[spec.category]

  local function get(key) return M.GetOpt(frameID, key) end
  local function set(key)
    return function(v) M.SetOpt(frameID, key, v) end
  end

  col:AddSection(spec.label, spec.category == "essential")
  col:AddText(spec.desc)

  col:AddCheckbox({
    label = "Enabled",
    desc  = "Show this cooldown viewer.",
    get   = function() return M.IsCategoryEnabled(spec.category) end,
    set   = function(v) M.SetCategoryEnabled(spec.category, v) end,
  })

  col:AddDropdown({
    label = "Orientation", values = ORIENTATION,
    desc  = "Lay the icons out in a row or a column.",
    get = function() return get("orientation") end, set = set("orientation"),
  })
  col:AddDropdown({
    label = "Icon direction", values = DIRECTION,
    desc  = "Which way the row grows as icons are added.",
    get = function() return get("iconDirection") end, set = set("iconDirection"),
  })
  col:AddDropdown({
    label = "Visibility", values = VISIBILITY,
    desc  = "When this viewer is on screen at all.",
    get = function() return get("visibleSetting") end, set = set("visibleSetting"),
  })

  col:AddSlider({
    label = "Icons per row", min = 1, max = 20, step = 1,
    desc  = "How many icons before the layout wraps. Vertical orientation reads this as icons per "
            .. "column.",
    get = function() return get("iconLimit") end, set = set("iconLimit"),
  })
  col:AddSlider({
    label = "Icon size", min = 50, max = 200, step = 10, format = pct,
    get = function() return get("iconSize") end, set = set("iconSize"),
  })
  col:AddSlider({
    label = "Icon padding", min = 0, max = 14, step = 1, format = px,
    desc  = "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that "
            .. "is the stock look, not a bug.",
    get = function() return get("iconPadding") end, set = set("iconPadding"),
  })
  col:AddSlider({
    label = "Opacity", min = 50, max = 100, step = 1, format = pct,
    get = function() return get("opacity") end, set = set("opacity"),
  })

  col:AddCheckbox({
    label = "Show timer",
    desc  = "Draw the countdown number on each icon.",
    get   = function() return get("showTimer") and true or false end,
    set   = set("showTimer"),
  })
  col:AddCheckbox({
    label = "Show tooltips",
    desc  = "Show a tooltip when hovering an icon.",
    get   = function() return get("showTooltips") and true or false end,
    set   = set("showTooltips"),
  })

  -- Hide When Inactive is only OFFERED where it does something. Retail's Essential/Utility templates
  -- do not set allowHideWhenInactive, so UpdateShownState ignores the setting there and those viewers
  -- always show every known cooldown. The options tab shipped the control anyway with a description
  -- saying it had no effect; a control that explains why it is inert is worse than no control.
  if get("allowHideWhenInactive") then
    col:AddCheckbox({
      label = "Hide when inactive",
      desc  = "Show a slot only while its aura is active.",
      get   = function() return get("hideWhenInactive") and true or false end,
      set   = set("hideWhenInactive"),
    })
  end

  col:AddButton({
    label = "Position this viewer",
    desc  = "Opens DragonUI's editor mode with this viewer selected, so you can drag it and read its "
            .. "coordinates. Closes this window; not available in combat.",
    width = 180,
    onClick = function() positionViewer(spec.category) end,
  })

  -- Bar-only, exactly as retail exposes them (the BuffBar system alone).
  if spec.bar then
    col:AddDropdown({
      label = "Bar content", values = BAR_CONTENT, width = 140,
      get = function() return get("barContent") end, set = set("barContent"),
    })
    col:AddSlider({
      label = "Bar width", min = 50, max = 200, step = 5, format = pct,
      get = function() return get("barWidthScale") end, set = set("barWidthScale"),
    })
  end
end

-- ── The page ────────────────────────────────────────────────────────────────────────────────────

local col   -- built once, on first switch to the tab

local function build(parent)
  local Kit = CDS.controls
  if not (Kit and Kit.New) then return nil end

  local c = Kit.New(parent, PAGE_W)

  c:AddText("Everything the Cooldown Manager can be told to do. Position is the one setting that is not "
    .. "stored here — each viewer's \"Position this viewer\" button hands it to DragonUI's editor mode, "
    .. "which owns frame placement (/dui edit).", { font = "GameFontHighlightSmall" })

  for _, spec in ipairs(M.VIEWER_SPECS or {}) do
    buildViewerSection(c, spec)
  end

  -- ── Buffed spells. Retail tints the swipe gold while a spell's own buff is on you; that setter is
  -- WoD+, so ours haloes the icon instead (PORT_PLAN §H.2 8c) — which then frees the timer to show
  -- whichever number is more useful, rather than being retail's only way to say "buffed".
  c:AddSection("Buffed spells", false)
  c:AddText("A spell can be on cooldown and buffing you at the same time. The glow says which icons "
    .. "are buffed; the timer says how long.")
  c:AddCheckbox({
    label = "Glow while buffed",
    desc  = "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.",
    get   = function() return M.IsBuffGlowEnabled() end,
    set   = function(v) M.SetBuffGlowEnabled(v) end,
  })
  c:AddCheckbox({
    label = "Show the buff's time, not the cooldown",
    desc  = "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the "
            .. "spell's cooldown and the glow alone marks it as buffed — which is clearer when the "
            .. "two differ, as on Prayer of Mending.",
    get   = function() return M.BuffShowsAuraTime() end,
    set   = function(v) M.SetBuffShowsAuraTime(v) end,
  })

  -- ── Icon fit. Retail masks its icons, which both insets and rounds them; §C2 records that
  -- MaskTexture has no polyfill on this client, so the inset is reproducible and the rounding is not.
  c:AddSection("Icon fit", false)
  c:AddText("The frame is a soft shadow that falls on the icon's outer edge, so it only shows where "
    .. "there is icon underneath it. Strength draws it more than once to deepen it — that is also "
    .. "what makes its rounded corners read, since the icons themselves cannot be rounded here. "
    .. "Inset shrinks the icon, which slides the shadow off it, so raise that one sparingly.")
  c:AddSlider({
    label = "Frame strength", min = 1, max = M.FRAME_STRENGTH_MAX, step = 1,
    get = function() return M.GetFrameStrength() end,
    set = function(v) M.SetFrameStrength(v) end,
  })
  c:AddSlider({
    label = "Icon inset", min = 0, max = M.ICON_INSET_EXTRA_MAX, step = 1, format = pct,
    get = function() return M.GetIconInsetExtra() end,
    set = function(v) M.SetIconInsetExtra(v) end,
  })

  -- ── Per-spec layout. Dual talent specialisation means one character genuinely wants two layouts.
  c:AddSection("Talent specs", false)
  c:AddText("Which spells and buffs you track is remembered separately for each talent spec, so a "
    .. "Discipline layout and a Holy one do not overwrite each other. Where each viewer sits is "
    .. "always remembered per character; the appearance settings are shared unless you say otherwise "
    .. "below.")
  c:AddCheckbox({
    label = "Separate layout per spec",
    desc  = "Off, both specs share one set of lists. Turning it on copies the layout you have now "
            .. "into the spec you are in.",
    get   = function() return M.IsPerSpecLayout() end,
    set   = function(v) M.SetPerSpecLayout(v) end,
  })
  c:AddCheckbox({
    label = "Separate appearance per character",
    -- Says what happens on BOTH edges, because the reversibility is the reason it is safe to try:
    -- a character that has changed nothing keeps reading the shared values, so nothing moves when
    -- this is ticked, and unticking it simply stops consulting the per-character values rather than
    -- discarding them.
    desc  = "Off, orientation, icons per row, size, padding and opacity are one setup for every "
            .. "character. On, each character can differ — until you change something here it still "
            .. "follows the shared setup, so nothing moves when you tick this, and unticking it "
            .. "gives the shared setup back without losing what you changed.",
    get   = function() return M.IsPerCharacterFrames() end,
    set   = function(v) M.SetPerCharacterFrames(v) end,
  })
  c:AddCheckbox({
    label = "Layouts include appearance",
    -- Governs APPLYING, not saving. A share string always carries appearance, so this is the
    -- recipient's decision rather than the author's — and it is off by default because an imported
    -- layout that silently resizes and reorients four viewers is how "load a layout" stops being an
    -- action anyone trusts.
    desc  = "Off, loading or importing a layout changes only what you track — lists, tracked buffs, "
            .. "trinkets, alerts and sounds. On, it also applies the orientation, icons per row, "
            .. "size, padding and opacity the layout was saved with.|n|nLayouts always SAVE "
            .. "appearance either way, so this only decides what happens when one is applied. Revert "
            .. "always puts appearance back, whatever this says.",
    get   = function() return M.LayoutsIncludeAppearance() end,
    set   = function(v) M.SetLayoutsIncludeAppearance(v) end,
  })

  -- ── Buff tracking. The buff viewers have no curated list: any player buff shorter than the
  -- auto-track window shows automatically, which is what makes trinket, potion and proc buffs work
  -- without enumerating them in advance.
  c:AddSection("Buff tracking", false)
  c:AddText("Buffs you have not seen before are recorded and listed under Not Displayed on the "
    .. "Tracked Buffs tab, where you can assign the ones you want. Nothing appears on screen until "
    .. "you do.")
  c:AddCheckbox({
    label = ("Auto-track buffs under %ds"):format(M.BUFF_TRACK_MAX_DURATION or 120),
    desc  = "Show every short buff the moment it lands, without assigning it first. Convenient on a "
            .. "character you are still setting up; in a raid it fills the viewers with other "
            .. "people's cooldowns, food and flasks.",
    get   = function() return M.IsAutoTrackBuffs() end,
    set   = function(v) M.SetAutoTrackBuffs(v) end,
    onChanged = function() if M.RefreshActiveViewer then M.RefreshActiveViewer() end end,
  })
  c:AddDropdown({
    label = "Show them as", values = TRACK_DEST, width = 140,
    desc  = "Which of the two buff viewers auto-tracked buffs land in.",
    get   = function() return M.AutoTrackDest() end,
    set   = function(v) M.SetAutoTrackDest(v) end,
    onChanged = function() if M.RefreshActiveViewer then M.RefreshActiveViewer() end end,
  })

  -- ── Resets. These are also in the cog menu, and that is deliberate: they are ACTIONS routed to the
  -- same confirm popups (SettingsMenu.lua), not two renderings of one stored value, so there is no
  -- state to fall out of sync. The cog is at hand while working the lists; a player looking for a
  -- reset looks under Settings. What the §G.10 decision removes is a second view of the same VALUES in
  -- a second window — not a second way to press a button.
  c:AddSection("Reset", false)
  c:AddText("Both of these are immediate and cannot be undone from here — Revert only covers layout "
    .. "changes.")
  c:AddButton({
    label = "Reset spell and buff lists",
    -- Says CLASS, not "character". The store is one shared DragonUI profile keyed by class, so this
    -- is the honest scope: another class is untouched, and another character of the SAME class reads
    -- the same lists and will see them reset too. Claiming "per-character" is what the old copy did,
    -- while the code behind it reset every class at once.
    desc  = "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its "
            .. "spell lists, aura assignments and trinket placement. Other classes, alerts, sounds "
            .. "and positions are not affected.",
    onClick = function() StaticPopup_Show("NE_CDM_RESET_TRACKING") end,
  })
  c:AddButton({
    label = "Clear all alerts and sounds",
    desc  = "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.",
    onClick = function() StaticPopup_Show("NE_CDM_RESET_ALERTS") end,
  })
  c:EndSection()

  c:Relayout()
  return c
end

-- Called by SetDisplayMode. Returns the column, or nil if the kit is missing (in which case the tab
-- shows an empty page rather than erroring on the click).
function CDS.EnsureSettingsPage()
  if col then return col end
  local panel = CDS.panel
  if not (panel and panel.settingsContent) then return nil end
  col = build(panel.settingsContent)
  CDS.settingsColumn = col   -- test seam
  return col
end

-- Re-read every control. Needed because this page is not the only writer: a layout apply, a reset,
-- or the master toggle in DragonUI's options can all move a value underneath it.
function CDS.RefreshSettingsPage()
  if not col then return end
  col:Refresh()
  col:Relayout()
end
