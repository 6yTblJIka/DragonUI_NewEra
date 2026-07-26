-- DragonUI_NewEra/modules/cooldownviewer/SettingsMenu.lua — the right-click item menu and the
-- panel's settings cog. Downport of the menu halves of NewEra/CooldownViewerSettings/Categories.lua
-- (showItemMenu, applyAlertBadge) and Panel.lua (settingsMenuGenerator).
--
-- THIS IS THE PHASE THAT SWITCHES PHASE 4A ON. The alert engine and the ready-sound catalogue have
-- shipped and been running since 4a, but nothing could assign them: every store was reachable only
-- from Lua. This file is the assignment surface. Nothing below is new machinery — it is calls into
-- M.alerts, M.SetReadySoundKit and CDS.adapter, arranged as a menu.
--
-- The Phase 4a ItemMenu.lua was deleted rather than debugged, on the owner's call, because the
-- content belonged here from the start: upstream carries Move-to / Remove / Ready Sound / Alert in
-- ONE generator on the settings item, not on the live HUD icon. That is also why the menu needs
-- three levels (item -> Ready Sound -> category -> entry) and therefore core/Menu.lua's ClassicAPI
-- backend, rather than the native two-level UIDropDownMenu.
--
-- ONE DELIBERATE DIVERGENCE FROM UPSTREAM: the FX enum. Upstream's fx values index
-- NE.groupbuff.VISUAL_ALERT (1 = marching ants, 6 = flash), a Group Buff Filter enum this addon
-- does not have. Ours is AL.FX — 1/2/3 over LibCustomGlow — so the FX submenu is generated FROM
-- AL.FX rather than hardcoding two entries. Hardcoding upstream's 1/6 here would have silently
-- written 6, which AL.FX has no renderer for.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

local CDS = NE.cooldownviewersettings
local Adapter = CDS.adapter

local REFRESH_WINDOWS = { 10, 20, 30, 40, 50 }   -- percent; AL clamps to [10, 50]

-- ── Alert badge ─────────────────────────────────────────────────────────────────────────────────
-- A small marker in the corner of any tile that has an alert or a ready sound configured, so the
-- grid shows its own state instead of making the player right-click every icon to find out.
-- Upstream draws the `common-icon-visual` glyph. That atlas is not registered in this addon, so the
-- badge is upstream's own fallback: a gold dot on a dark strip. Ask HasAtlas first rather than
-- letting SetAtlas fail — a failed SetAtlas logs an ATLAS MISS, and this runs once per tile per
-- rebuild, which would bury the log in a message the answer to which is always "no".

local BADGE_ATLAS = "common-icon-visual"

local function applyAlertBadge(item)
  if not item.AlertBG then
    item.AlertBG = item:CreateTexture(nil, "OVERLAY")
    item.AlertBG:SetSize(14, 12)
    item.AlertBG:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    item.AlertBG:SetTexture(0, 0, 0, 0.7)

    item.AlertBadge = item:CreateTexture(nil, "OVERLAY")
    item.AlertBadge:SetSize(6, 6)
    item.AlertBadge:SetPoint("CENTER", item.AlertBG, "CENTER", 0, 0)
    local haveGlyph = NE.tex and NE.tex.HasAtlas and NE.tex.HasAtlas(BADGE_ATLAS)
      and NE.tex.SetAtlas(item.AlertBadge, BADGE_ATLAS, false)
    if not haveGlyph then item.AlertBadge:SetTexture(1, 0.82, 0, 1) end
  end

  local configured = (M.GetReadySoundKit and M.GetReadySoundKit(item.spellID) ~= nil)
    or (M.alerts and M.alerts.GetType and M.alerts.GetType(item.spellID) ~= nil)
  if configured then
    item.AlertBG:Show(); item.AlertBadge:Show()
  else
    item.AlertBG:Hide(); item.AlertBadge:Hide()
  end
end

CDS._applyAlertBadge = applyAlertBadge

-- Extra tooltip lines describing what the badge means for this specific tile. Called by
-- SettingsCategories' OnEnter, after the spell tooltip has been laid down.
function CDS._itemTooltipExtra(item, tooltip)
  if not (item and item.spellID and tooltip) then return end
  local AL = M.alerts
  local t = AL and AL.GetType and AL.GetType(item.spellID)
  if t then
    local fxName
    for _, fx in ipairs((AL and AL.FX) or {}) do
      if fx.id == AL.GetFX(item.spellID) then fxName = fx.name end
    end
    tooltip:AddLine(("Alert: %s (%s)"):format(t, fxName or "?"), 0.4, 1, 0.4)
  end
  local kit = M.GetReadySoundKit and M.GetReadySoundKit(item.spellID)
  if kit then
    tooltip:AddLine("Ready sound: " .. (M.GetSoundKitName(kit) or tostring(kit)), 0.4, 0.8, 1)
  end
end

-- ── The item menu ───────────────────────────────────────────────────────────────────────────────

local function addMoveEntries(root, item, class)
  for _, target in ipairs(Adapter.GetValidTargets(item._catID)) do
    root:CreateButton("Move to " .. Adapter.Label(target), function()
      Adapter.Assign(item.spellID, item._catID, target, class)
      CDS.RefreshLayout()
    end)
  end
end

-- One submenu per sound category, a radio per sound, plus None. Selecting previews the cue —
-- retail's "Play Sample" — because a sound you cannot hear before committing is not a choice.
local function addSoundEntries(root, item)
  if not (item.spellID and M.SOUND_DATA and M.SOUND_CATEGORY_ORDER and M.SetReadySoundKit) then return end
  root:CreateDivider()
  local soundRoot = root:CreateButton("Ready Sound")

  soundRoot:CreateRadio("None",
    function() return M.GetReadySoundKit(item.spellID) == nil end,
    function()
      M.SetReadySoundKit(item.spellID, nil)
      applyAlertBadge(item)
    end)

  for _, cat in ipairs(M.SOUND_CATEGORY_ORDER) do
    local catSub = soundRoot:CreateButton(cat)
    for _, e in ipairs(M.SOUND_DATA[cat] or {}) do
      catSub:CreateRadio(e.name,
        function() return M.GetReadySoundKit(item.spellID) == e.kit end,
        function()
          M.SetReadySoundKit(item.spellID, e.kit)
          if M.PlayReadySound then M.PlayReadySound(e.kit) end
          applyAlertBadge(item)
        end)
    end
  end
end

-- Event (None / Available / Refresh / Usable), FX style, and — for Refresh — the window %.
-- Choosing an event or an FX flashes a sample on the tile itself, the same "see it before you
-- commit" contract as the sound preview.
local function addAlertEntries(root, item)
  local AL = M.alerts
  if not (item.spellID and AL and AL.SetType) then return end
  root:CreateDivider()
  local alertRoot = root:CreateButton("Alert")

  local function isType(t) return AL.GetType(item.spellID) == t end
  local function pick(t)
    return function()
      AL.SetType(item.spellID, t)
      if t then AL.Preview(item, AL.GetFX(item.spellID)) elseif AL.ClearFX then AL.ClearFX(item) end
      applyAlertBadge(item)
    end
  end

  alertRoot:CreateRadio("None",      function() return AL.GetType(item.spellID) == nil end, pick(nil))
  alertRoot:CreateRadio("Available", function() return isType("available") end,             pick("available"))
  alertRoot:CreateRadio("Refresh",   function() return isType("refresh")   end,             pick("refresh"))
  alertRoot:CreateRadio("Usable",    function() return isType("usable")    end,             pick("usable"))
  alertRoot:CreateDivider()

  -- Generated from AL.FX, not from upstream's hardcoded pair. See the header.
  local fxSub = alertRoot:CreateButton("FX Style")
  for _, fx in ipairs(AL.FX or {}) do
    fxSub:CreateRadio(fx.name,
      function() return AL.GetFX(item.spellID) == fx.id end,
      function() AL.SetFX(item.spellID, fx.id); AL.Preview(item, fx.id) end)
  end

  local winSub = alertRoot:CreateButton("Refresh Window")
  for _, pct in ipairs(REFRESH_WINDOWS) do
    winSub:CreateRadio(pct .. "%",
      function() return math.abs((AL.GetWindow(item.spellID) * 100) - pct) < 0.5 end,
      function() AL.SetWindow(item.spellID, pct / 100) end)
  end
end

-- The generator. Kept separate from the open call so a test can build the tree and drive it without
-- any of UIDropDownMenu present.
function CDS.ItemMenuGenerator(item, class)
  return function(_, root)
    root:CreateTitle(item.spellName or "")
    addMoveEntries(root, item, class)

    -- Remove only appears when the entry is genuinely deletable — a stored user aura. A spell is
    -- never removed, only returned to the Hidden catalog, which "Move to Hidden" already does.
    if Adapter.IsRemovable and Adapter.IsRemovable(item.spellID, item._catID, class) then
      root:CreateDivider()
      root:CreateButton("|cffff5555Remove|r", function()
        Adapter.Remove(item.spellID, item._catID, class)
        CDS.RefreshLayout()
      end)
    end

    addSoundEntries(root, item)
    addAlertEntries(root, item)
  end
end

-- Called by SettingsCategories for every tile click.
function CDS.OnItemClick(item, button)
  if button ~= "RightButton" then return end
  if not (item and item._catID and item.spellID) then return end
  if not (NE.menu and NE.menu.OpenContext) then return end
  local _, class = UnitClass("player")
  NE.menu.OpenContext(CDS.ItemMenuGenerator(item, class))
end

-- ── The settings cog ────────────────────────────────────────────────────────────────────────────

function CDS.SettingsMenuGenerator(_, root)
  root:CreateCheckbox("Show Unlearned",
    function() return M.GetShowUnlearned and M.GetShowUnlearned() end,
    function()
      M.SetShowUnlearned(not M.GetShowUnlearned())
      CDS.RefreshLayout()
    end)

  root:CreateDivider()
  root:CreateButton("Reset Spell Lists", function() StaticPopup_Show("NE_CDM_RESET_TRACKING") end)
  root:CreateButton("Clear All Alerts",  function() StaticPopup_Show("NE_CDM_RESET_ALERTS") end)
end

-- Both resets are destructive and irreversible (there is no undo store until 4b-5), so both confirm.
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["NE_CDM_RESET_TRACKING"] = {
  text = "Reset the Cooldown Manager spell and buff lists to their defaults?\n\nAlerts, sounds and frame positions are not affected.",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function()
    if M.ResetTracking then M.ResetTracking() end
    if CDS.RefreshLayout then CDS.RefreshLayout() end
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1,
}
StaticPopupDialogs["NE_CDM_RESET_ALERTS"] = {
  text = "Clear every configured alert and ready sound?\n\nSpell lists and frame positions are not affected.",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function()
    if M.ResetAlerts then M.ResetAlerts() end
    if CDS.RefreshLayout then CDS.RefreshLayout() end
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function CDS.ToggleSettingsMenu(cog)
  if not (NE.menu and NE.menu.ToggleAnchored) then return end
  NE.menu.ToggleAnchored(CDS.SettingsMenuGenerator, cog, { point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", x = 0, y = -2 })
end
