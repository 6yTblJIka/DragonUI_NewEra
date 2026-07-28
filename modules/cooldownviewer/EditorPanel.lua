-- DragonUI_NewEra/modules/cooldownviewer/EditorPanel.lua — each viewer's settings as a dialog beside
-- the frame, in edit mode.
--
-- WHAT THIS REPLACES. The first pass at retail's on-the-frame settings (§H.3.10) was a right-click
-- CONTEXT MENU: every setting as a submenu of radios. It worked, and it was the wrong shape. Retail —
-- and NewEra's own 1.15 edit mode, which is what the owner is comparing against — opens a small DIALOG
-- next to the selected frame, with the sliders and dropdowns visible at once. The difference is not
-- cosmetic: a menu shows you one setting at a time and hides the value you are trying to match, and a
-- numeric setting inside it has to become a list of discrete rows (§H.3.10 shipped opacity in steps of
-- 5 for exactly that reason, and had to explain in a tooltip why a value could tick nothing at all).
-- A dialog shows every value at once and takes a real slider, so both compromises simply go away.
--
-- SEAM: NE.RegisterHUDFrame's `editorSettings` field — a callback, not a menu generator, so the host
-- glue in integration/Register.lua does not care what a module chooses to open (CONTRACTS §4). Every
-- DragonUI touch lives there: the mouse handler, the edit-mode gate, SelectEditorFrame, EditorMode.
--
-- WIDGETS ARE THE /cdm SETTINGS KIT (SettingsControls.lua), not a second set. One new control was
-- needed — AddCompactSlider, a one-line slider with nudge arrows — because the tab's tall two-line
-- slider is right for a page you scroll and wrong for a dialog that has to sit on the screen next to
-- the thing it edits without burying it.
--
-- TWO EDITORS FOR ONE VALUE, which SettingsOptions.lua's header forbids. The rule is about STALENESS,
-- so both halves are closed rather than the rule waived: this dialog re-reads every control through
-- col:Refresh() each time it opens, and every write it makes calls CDS.RefreshSettingsPage, which
-- re-reads the tab's controls and no-ops when that tab was never built.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

local PANEL_W = 306
local BODY_W  = PANEL_W - 26
local TITLE_H = 28
local FOOTER_BTN_H, FOOTER_GAP = 24, 4
local SIDE_GAP = 12          -- clearance between the dialog and the frame it edits

-- Same value/label pairs, in the same order, as the /cdm Settings tab.
local ORIENTATION = { { "horizontal", "Horizontal" }, { "vertical", "Vertical" } }
local DIRECTION   = { { "right", "Right" }, { "left", "Left" } }
local VISIBILITY  = { { "always", "Always" }, { "incombat", "In Combat" }, { "hidden", "Hidden" } }
local BAR_CONTENT = { { "iconAndName", "Icon and Name" }, { "iconOnly", "Icon Only" },
                      { "nameOnly", "Name Only" } }

local function pct(v) return tostring(v) .. "%" end
local function px(v)  return tostring(v) .. "px" end

local panel                  -- the one dialog
local pages   = {}           -- category -> { body, col, dirtyCheck }
local current                -- category currently shown
local snapshots = {}         -- category -> the values Revert goes back to, per editor session

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

-- ── Revert ──────────────────────────────────────────────────────────────────────────────────────
--
-- "Revert Changes" goes back to how this viewer was when the editor was opened, NOT to defaults —
-- that is what the button below it is for, and conflating the two is how someone loses a setup they
-- spent ten minutes on. So the snapshot is taken the first time the dialog is opened for a viewer in
-- an editor session, and dropped when the editor closes.

local function snapshotOf(category)
  local frameID = M.FRAME_ID[category]
  local t = { _enabled = M.IsCategoryEnabled(category) }
  for key in pairs(M.DEFAULTS or {}) do t[key] = M.GetOpt(frameID, key) end
  return t
end

local function ensureSnapshot(category)
  if not snapshots[category] then snapshots[category] = snapshotOf(category) end
  return snapshots[category]
end

local function isDirty(category)
  local snap = snapshots[category]
  if not snap then return false end
  local now = snapshotOf(category)
  for key, v in pairs(snap) do
    if now[key] ~= v then return true end
  end
  return false
end

local function revert(category)
  local snap = snapshots[category]
  if not snap then return end
  local frameID = M.FRAME_ID[category]
  for key, v in pairs(snap) do
    if key ~= "_enabled" then M.SetOpt(frameID, key, v) end
  end
  M.SetCategoryEnabled(category, snap._enabled)
end

-- ── One viewer's page ───────────────────────────────────────────────────────────────────────────

local function buildPage(category)
  local Kit = NE.cooldownviewersettings and NE.cooldownviewersettings.controls
  if not (Kit and Kit.New) then return nil end

  local frameID = M.FRAME_ID[category]
  local spec    = specFor(category)

  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -TITLE_H)
  body:SetWidth(BODY_W)
  body:Hide()

  local col = Kit.New(body, BODY_W)

  local function get(key) return M.GetOpt(frameID, key) end
  -- Every write goes through here: store, then the OTHER view, then this dialog's own Revert state.
  local function set(key)
    return function(v)
      M.SetOpt(frameID, key, v)
      notifyPanel()
      if panel and panel.UpdateRevert then panel.UpdateRevert() end
    end
  end
  local function getter(key) return function() return get(key) end end

  col:AddCheckbox({
    label = "Enabled",
    desc  = "Show this viewer at all. The editor handle stays either way, so this is reversible from "
            .. "right here.",
    get   = function() return M.IsCategoryEnabled(category) end,
    set   = function(v)
      M.SetCategoryEnabled(category, v)
      notifyPanel()
      if panel and panel.UpdateRevert then panel.UpdateRevert() end
    end,
  })

  col:AddDropdown({
    label = "Orientation", values = ORIENTATION, width = 140,
    get = getter("orientation"), set = set("orientation"),
  })
  col:AddCompactSlider({
    label = "Icon Limit", min = 1, max = 20, step = 1,
    desc  = "How many icons before the layout wraps. Vertical orientation reads this as icons per "
            .. "column.",
    get = getter("iconLimit"), set = set("iconLimit"),
  })
  col:AddDropdown({
    label = "Icon Direction", values = DIRECTION, width = 140,
    get = getter("iconDirection"), set = set("iconDirection"),
  })
  col:AddCompactSlider({
    label = "Icon Size", min = 50, max = 200, step = 10, format = pct,
    get = getter("iconSize"), set = set("iconSize"),
  })
  col:AddCompactSlider({
    label = "Icon Padding", min = 0, max = 14, step = 1, format = px,
    desc  = "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is "
            .. "the stock look, not a bug.",
    get = getter("iconPadding"), set = set("iconPadding"),
  })
  col:AddCompactSlider({
    label = "Opacity", min = 50, max = 100, step = 1, format = pct,
    get = getter("opacity"), set = set("opacity"),
  })
  col:AddDropdown({
    label = "Visibility", values = VISIBILITY, width = 140,
    desc  = "When this viewer is on screen at all. Hidden still leaves the editor handle here.",
    get = getter("visibleSetting"), set = set("visibleSetting"),
  })

  -- Only where it does something: retail's Essential/Utility templates do not set
  -- allowHideWhenInactive, so UpdateShownState ignores the setting there. The /cdm tab drops the
  -- control for the same reason, and a row that silently does nothing is worse than no row.
  if get("allowHideWhenInactive") then
    col:AddCheckbox({
      label = "Hide When Inactive",
      desc  = "Show a slot only while its aura is active.",
      get   = function() return get("hideWhenInactive") and true or false end,
      set   = set("hideWhenInactive"),
    })
  end

  col:AddCheckbox({
    label = "Show Timer",
    desc  = "Draw the countdown number on each icon.",
    get   = function() return get("showTimer") and true or false end,
    set   = set("showTimer"),
  })
  col:AddCheckbox({
    label = "Show Tooltips",
    desc  = "Show a tooltip when hovering an icon.",
    get   = function() return get("showTooltips") and true or false end,
    set   = set("showTooltips"),
  })

  -- Bar-only, exactly as retail exposes them (the BuffBar system alone).
  if spec and spec.bar then
    col:AddDropdown({
      label = "Bar Content", values = BAR_CONTENT, width = 140,
      get = getter("barContent"), set = set("barContent"),
    })
    col:AddCompactSlider({
      label = "Bar Width", min = 50, max = 200, step = 5, format = pct,
      get = getter("barWidthScale"), set = set("barWidthScale"),
    })
  end

  col:Relayout()
  local page = { body = body, col = col, category = category }
  pages[category] = page
  return page
end

-- ── The dialog ──────────────────────────────────────────────────────────────────────────────────

local function ensurePanel()
  if panel then return panel end

  local f = CreateFrame("Frame", "NE_CDMEditorPanel", UIParent)
  f:SetSize(PANEL_W, 200)
  -- Above the editor's own handles, which CreateUIFrame puts at FULLSCREEN. A settings dialog that
  -- renders behind the frame it configures is not a settings dialog.
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self._moved = true   -- once you place it yourself, it stops jumping to each frame you select
  end)
  f:Hide()

  local PC = NE.chrome
  if PC and PC.Apply then
    pcall(PC.Apply, f, { title = "Cooldown Manager", noPortrait = true })
    -- PanelChrome washes the rock down for a full-size window body; at this size that reads as murk.
    if f.Bg and f.Bg.SetVertexColor then f.Bg:SetVertexColor(1, 1, 1) end
  end
  if f.CloseButton then
    f.CloseButton:SetScript("OnClick", function() M.HideEditorPanel() end)
  end

  -- Footer. Built once and pointed at whichever viewer is showing, rather than per page: three
  -- buttons that differ only in which category they act on would be three copies of this block.
  local function footerButton(label, onClick)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(BODY_W, FOOTER_BTN_H)
    b:SetText(label)
    b:SetScript("OnClick", function() if current then onClick(current) end end)
    return b
  end

  f.settingsButton = footerButton("Cooldown Manager Settings", function()
    -- Leave the editor first: it covers the screen, and DragonUI saves every frame's position on the
    -- way out, so nothing is lost by going this way.
    if NE.CloseFrameEditor then NE.CloseFrameEditor() end
    if M.OpenSettingsPanel then M.OpenSettingsPanel("settings") end
  end)
  f.revertButton = footerButton("Revert Changes", function(category)
    revert(category)
    M.RefreshEditorPanel()
  end)
  f.resetButton = footerButton("Reset to Default", function(category)
    M.ResetOpts(M.FRAME_ID[category])
    M.RefreshEditorPanel()
  end)

  -- Revert is disabled until there IS something to revert. A button that is always live and usually
  -- does nothing teaches you to ignore it, and this one is the undo.
  function f.UpdateRevert()
    local on = current and isDirty(current)
    if on then f.revertButton:Enable() else f.revertButton:Disable() end
  end

  panel = f
  return f
end

-- Anchor beside the frame being edited, on whichever side has room. Skipped once the player has
-- dragged the dialog somewhere themselves.
local function place(f, anchor)
  if f._moved then return end
  f:ClearAllPoints()
  local cx = anchor and anchor.GetCenter and select(1, anchor:GetCenter())
  local sw = (UIParent and UIParent:GetWidth()) or 1024
  if not cx then
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  elseif cx > sw / 2 then
    f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -SIDE_GAP, 0)
  else
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", SIDE_GAP, 0)
  end
end

-- ── API ─────────────────────────────────────────────────────────────────────────────────────────

function M.ShowEditorPanel(category, anchor)
  if not (category and M.FRAME_ID and M.FRAME_ID[category]) then return false end
  local f = ensurePanel()
  if not f then return false end

  local page = pages[category] or buildPage(category)
  if not page then return false end

  for cat, p in pairs(pages) do
    if cat ~= category then p.body:Hide() end
  end
  page.body:Show()
  current = category

  -- Re-read every control before showing. Something else may have moved these underneath us — the
  -- /cdm tab, a layout apply, a reset — and a dialog that opens on stale values is indistinguishable
  -- from one whose settings did not take.
  page.col:Refresh()
  local h = page.col:Relayout()

  local spec = specFor(category)
  local PC = NE.chrome
  if PC and PC.SetTitle then PC.SetTitle(f, (spec and spec.label) or category) end

  -- Size to the page, then the footer under it. Height varies by viewer — Buff Bars carries two rows
  -- nothing else does — so this is computed rather than a constant that would clip one of them.
  local footerH = (FOOTER_BTN_H + FOOTER_GAP) * 3
  f:SetHeight(TITLE_H + h + 10 + footerH + 10)
  f.settingsButton:ClearAllPoints()
  f.settingsButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 13, 10 + (FOOTER_BTN_H + FOOTER_GAP) * 2)
  f.revertButton:ClearAllPoints()
  f.revertButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 13, 10 + FOOTER_BTN_H + FOOTER_GAP)
  f.resetButton:ClearAllPoints()
  f.resetButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 13, 10)

  ensureSnapshot(category)
  f.UpdateRevert()
  place(f, anchor or (M.viewers and M.viewers[category] and M.viewers[category].editorAnchor))
  f:Show()
  return true
end

-- Re-read the open page. Used by the footer buttons, which change values without going through a
-- control's own setter.
function M.RefreshEditorPanel()
  local page = current and pages[current]
  if not page then return end
  page.col:Refresh()
  notifyPanel()
  if panel and panel.UpdateRevert then panel.UpdateRevert() end
end

-- Closing the editor drops the Revert snapshots: "revert" means "back to how this was when I started
-- editing", and once you have left, that session is over. Keeping them would silently arm the button
-- with a state from an hour ago.
function M.HideEditorPanel()
  snapshots = {}
  current = nil
  if panel then panel:Hide() end
end

M.IsEditorPanelShown = function() return (panel and panel:IsShown()) and true or false end
M._editorPanel = function() return panel, pages end   -- test seam
