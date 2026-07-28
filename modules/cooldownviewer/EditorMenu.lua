-- DragonUI_NewEra/modules/cooldownviewer/EditorMenu.lua — each viewer's settings, on the viewer,
-- in edit mode.
--
-- WHY THIS EXISTS. Retail puts a system's settings ON the frame: you enter Edit Mode, pick the
-- Cooldown Manager, and orientation / icon limit / size / opacity are right there beside it. Ours
-- were reachable only from the /cdm Settings tab (§G.10/§G.12) — correct, complete, and a different
-- window from the one where you are looking at the thing you want to change. §B1 dropped upstream's
-- 6,441-line Edit Mode reimplementation and routed POSITION at DragonUI's editor; this routes the
-- SETTINGS the same way, so that "select a viewer, change how it looks, drag it" is one place.
--
-- SEAM: NE.RegisterHUDFrame's `editorMenu` spec field, added for this. The mouse handler, the
-- editor-active gate and the SelectEditorFrame call all live in integration/Register.lua — this file
-- knows nothing about DragonUI (CONTRACTS §4) and produces only a MenuUtil-shaped generator, which is
-- also what makes it testable with no editor and no UIDropDownMenu present.
--
-- TWO EDITORS FOR ONE VALUE, which SettingsOptions.lua's header explicitly warns against. The warning
-- is about STALENESS — two views drift the moment one of them isn't rebuilt on show — so both halves
-- are closed here rather than the rule being waived:
--
--   * the menu cannot go stale: core/Menu.lua rebuilds the tree from this generator on every open and
--     re-reads every radio predicate on every click.
--   * the page can, so every write below calls CDS.RefreshSettingsPage, which re-reads every control
--     and no-ops when the tab was never built.
--
-- WHAT IS NOT HERE. Opacity steps by 5 rather than the panel's 1 (a 51-row menu is not a control),
-- and the settings that are not per-viewer — frame strength, icon inset, buff tracking, alerts,
-- resets — stay on the tab, which "All settings…" opens. A menu is for the handful of things you
-- change while looking at the frame; it is not a second copy of the window.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

-- Same value/label pairs the Settings tab uses, in the same order.
local ORIENTATION = { { "horizontal", "Horizontal" }, { "vertical", "Vertical" } }
local DIRECTION   = { { "right", "Right" }, { "left", "Left" } }
local VISIBILITY  = { { "always", "Always" }, { "incombat", "In Combat" }, { "hidden", "Hidden" } }
local BAR_CONTENT = { { "iconAndName", "Icon and Name" }, { "iconOnly", "Icon Only" },
                      { "nameOnly", "Name Only" } }

local function pct(v) return tostring(v) .. "%" end
local function px(v)  return tostring(v) .. " px" end
local function plain(v) return tostring(v) end

-- The /cdm Settings tab is the other view onto these values. No-ops when it was never built.
local function notifyPanel()
  local CDS = NE.cooldownviewersettings
  if CDS and CDS.RefreshSettingsPage then CDS.RefreshSettingsPage() end
end

local function specFor(category)
  for _, s in ipairs(M.VIEWER_SPECS or {}) do
    if s.category == category then return s end
  end
  return nil
end

-- A submenu of radios over an explicit value/label list.
local function addChoice(root, label, values, get, set, tip)
  local sub = root:CreateButton(label)
  if tip then sub:SetTooltip(label, tip) end
  for _, pair in ipairs(values) do
    local value = pair[1]
    sub:CreateRadio(pair[2], function() return get() == value end, function() set(value) end)
  end
  return sub
end

-- A submenu of radios over a numeric range. The same min/max/step the tab's slider uses, except
-- where a slider's granularity would produce an unusable menu (see the header).
local function addRange(root, label, min, max, step, format, get, set, tip)
  local sub = root:CreateButton(label)
  if tip then sub:SetTooltip(label, tip) end
  for v = min, max, step do
    local value = v
    sub:CreateRadio(format(value),
      -- Compared with a tolerance, not ==: a stored value can come from the tab's finer slider (or an
      -- imported layout) and land between two rows, in which case NOTHING is ticked. That is the
      -- honest rendering — the menu says "not one of these" rather than rounding your setting to the
      -- nearest one it can show.
      function() local cur = get(); return type(cur) == "number" and math.abs(cur - value) < 0.001 end,
      function() set(value) end)
  end
  return sub
end

-- ── The generator ───────────────────────────────────────────────────────────────────────────────
--
-- Returns generator(owner, root) for one viewer. Built per category at registration and reused: the
-- tree itself is rebuilt from it on every open, so nothing it closes over can go stale.
function M.EditorMenuGenerator(category)
  local frameID = M.FRAME_ID and M.FRAME_ID[category]

  return function(_, root)
    if not frameID then return end
    local spec = specFor(category)

    local function get(key) return M.GetOpt(frameID, key) end
    local function set(key)
      return function(v)
        M.SetOpt(frameID, key, v)
        notifyPanel()
      end
    end
    local function getter(key) return function() return get(key) end end

    root:CreateTitle(spec and spec.label or category)

    -- Enabled is offered here even though switching it off empties the frame, because the green
    -- editor handle is NOT the viewer: it stays on screen and stays right-clickable, so this is
    -- reversible from the same menu. (UpdateVisibility hides the content; ShowAllEditableFrames owns
    -- the handle.) The same goes for Visibility -> Hidden below.
    root:CreateCheckbox("Enabled",
      function() return M.IsCategoryEnabled(category) end,
      function()
        M.SetCategoryEnabled(category, not M.IsCategoryEnabled(category))
        notifyPanel()
      end):SetTooltip("Enabled",
        "Show this viewer at all.|n|nThe editor handle stays here either way,|nso you can turn it"
        .. " back on from this menu.")

    root:CreateDivider()

    addChoice(root, "Orientation", ORIENTATION, getter("orientation"), set("orientation"),
      "Lay the icons out in a row or a column.")
    addChoice(root, "Icon direction", DIRECTION, getter("iconDirection"), set("iconDirection"),
      "Which way the row grows as icons are added.")
    addChoice(root, "Visibility", VISIBILITY, getter("visibleSetting"), set("visibleSetting"),
      "When this viewer is on screen at all.|n|nHidden still leaves the editor handle here.")

    addRange(root, "Icons per row", 1, 20, 1, plain, getter("iconLimit"), set("iconLimit"),
      "How many icons before the layout wraps.|nVertical orientation reads this as icons|nper column.")
    addRange(root, "Icon size", 50, 200, 10, pct, getter("iconSize"), set("iconSize"))
    addRange(root, "Icon padding", 0, 14, 1, px, getter("iconPadding"), set("iconPadding"),
      "Gap between icons. Retail offsets this by -4,|nso the low end overlaps slightly — that is|nthe"
      .. " stock look, not a bug.")
    -- Step 5, where the tab's slider steps 1. See the header: this is the one place the two views
    -- differ, and a value the slider set in between simply ticks nothing here.
    addRange(root, "Opacity", 50, 100, 5, pct, getter("opacity"), set("opacity"),
      "Steps of 5 here. The Settings tab's slider|nis finer, and a value it set in between will|nshow"
      .. " nothing ticked in this list.")

    root:CreateDivider()

    root:CreateCheckbox("Show timer",
      function() return get("showTimer") and true or false end,
      function() set("showTimer")(not get("showTimer")) end)
    root:CreateCheckbox("Show tooltips",
      function() return get("showTooltips") and true or false end,
      function() set("showTooltips")(not get("showTooltips")) end)

    -- Only where it does something. Retail's Essential/Utility templates do not set
    -- allowHideWhenInactive, so UpdateShownState ignores the setting there — the tab drops the control
    -- for the same reason, and a menu row that silently does nothing is worse than no row.
    if get("allowHideWhenInactive") then
      root:CreateCheckbox("Hide when inactive",
        function() return get("hideWhenInactive") and true or false end,
        function() set("hideWhenInactive")(not get("hideWhenInactive")) end)
        :SetTooltip("Hide when inactive", "Show a slot only while its aura is active.")
    end

    -- Bar-only, exactly as retail exposes them (the BuffBar system alone).
    if spec and spec.bar then
      root:CreateDivider()
      addChoice(root, "Bar content", BAR_CONTENT, getter("barContent"), set("barContent"))
      addRange(root, "Bar width", 50, 200, 10, pct, getter("barWidthScale"), set("barWidthScale"))
    end

    root:CreateDivider()

    -- APPEARANCE, not position. DragonUI's editor panel already carries a Reset for the frame's
    -- placement, and one menu offering a differently-scoped "Reset" next to it would be read as the
    -- same button.
    root:CreateButton("Reset appearance", function()
      M.ResetOpts(frameID)
      notifyPanel()
    end):SetTooltip("Reset appearance",
      "Put this viewer's orientation, size, padding|nand opacity back to their defaults.|n|nIts"
      .. " POSITION is not touched — the editor's own|nReset button does that one.")

    root:CreateButton("All settings\226\128\166", function()
      -- Leave the editor first. It covers the screen, and DragonUI saves every frame's position on
      -- the way out, so this loses nothing.
      if NE.CloseFrameEditor then NE.CloseFrameEditor() end
      if M.OpenSettingsPanel then M.OpenSettingsPanel("settings") end
    end):SetTooltip("All settings",
      "Closes edit mode and opens the Cooldown Manager|nwindow, which carries the settings that are"
      .. " not|nper-viewer: alerts, ready sounds, buff tracking,|nicon fit and the resets.")
  end
end
