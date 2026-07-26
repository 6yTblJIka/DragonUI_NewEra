-- DragonUI_NewEra/modules/cooldownviewer/ItemMenu.lua — right-click assignment menu on a cooldown
-- icon: pick the visual alert, its effect, and the ready sound; hide the spell from its viewer.
--
-- WHY THIS EXISTS AS A MENU. Upstream assigns all of this from the standalone
-- CooldownViewerSettings panel (2,139 lines, six files, built on retail's MenuUtil, GLOBAL_MOUSE_UP
-- drag-and-drop and LargeSideTabButtonTemplate — none of which this client has). That panel is the
-- next phase. Without SOME assignment surface, though, the alert and sound engines are opt-in
-- features with no way to opt in — dormant code. A context menu on the icon itself is the cheapest
-- honest surface, it is where a player looks first, and every choice it writes is the same stored
-- shape the panel will later read and edit.
--
-- MENU DEPTH: three levels (Ready Sound -> category -> entry). 3.3.5a's own UIDropDownMenu caps at
-- two, so this drives !!!ClassicAPI's C_UIDropDownMenu, which grows C_UIDROPDOWNMENU_MAXLEVELS on
-- demand (Templates/C_UIDropDownMenu.lua:124-130). The native names are used as a fallback so the
-- menu still opens (with the sound list flattened out of reach) if that ever goes away.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

local Init      = C_UIDropDownMenu_Initialize   or UIDropDownMenu_Initialize
local AddButton = C_UIDropDownMenu_AddButton    or UIDropDownMenu_AddButton
local NewInfo   = C_UIDropDownMenu_CreateInfo   or UIDropDownMenu_CreateInfo
local Toggle    = ToggleDropDownMenu
local TEMPLATE  = C_UIDropDownMenu_Initialize and "C_UIDropDownMenuTemplate" or "UIDropDownMenuTemplate"

local ALERT_TYPES = {
  { value = nil,         label = "None" },
  { value = "available", label = "When Ready",   tip = "Flash once when the cooldown finishes." },
  { value = "refresh",   label = "Aura Refresh", tip = "Glow while this spell's own aura is running out." },
  { value = "usable",    label = "When Usable",  tip = "Glow when the ability becomes conditionally castable." },
}

local WINDOWS = { 0.10, 0.20, 0.30, 0.40, 0.50 }

local menu       -- the shared dropdown frame
local ctxItem    -- the item the open menu belongs to

local function categoryOf(item)
  local viewer = item and item.GetParent and item:GetParent()
  return viewer and viewer.category or nil
end

local function viewerLabel(category)
  for _, spec in ipairs(M.VIEWER_SPECS or {}) do
    if spec.category == category then return spec.label end
  end
  return "this viewer"
end

-- `usable` only ever fires for spells curated in AlertData, and `refresh` only for spells that
-- actually place an aura. Saying so up front beats the user assigning an alert that can never fire.
local function usableApplies(item)
  local A = M.alertdata
  if not (A and item and item.spellID) then return false end
  if A.ExecuteThreshold and A.ExecuteThreshold(item.spellID, item._rankCDIDs) then return true end
  return A.IsReactive and A.IsReactive(item.spellID, item._rankCDIDs) or false
end

local function initialize(_, level, menuList)
  local item = ctxItem
  if not (item and item.spellID) then return end
  local AL = M.alerts
  -- Every choice below is a per-spell PREFERENCE, so it keys off the listed id rather than the
  -- learned-rank id the tile happens to display — otherwise training a rank orphans the setting.
  local spellID = item.GetSettingsKey and item:GetSettingsKey() or item.spellID
  level = level or 1

  if level == 1 then
    local title = NewInfo()
    title.text, title.isTitle, title.notCheckable = (item.spellName or "Cooldown"), true, true
    AddButton(title, level)

    local alert = NewInfo()
    alert.text, alert.hasArrow, alert.notCheckable, alert.menuList = "Alert", true, true, "alert"
    AddButton(alert, level)

    local fx = NewInfo()
    fx.text, fx.hasArrow, fx.notCheckable, fx.menuList = "Effect", true, true, "fx"
    fx.disabled = not AL.GetType(spellID)
    AddButton(fx, level)

    if AL.GetType(spellID) == "refresh" then
      local win = NewInfo()
      win.text, win.hasArrow, win.notCheckable, win.menuList = "Refresh Window", true, true, "window"
      AddButton(win, level)
    end

    local sound = NewInfo()
    sound.text, sound.hasArrow, sound.notCheckable, sound.menuList = "Ready Sound", true, true, "sound"
    AddButton(sound, level)

    local sep = NewInfo()
    sep.text, sep.isTitle, sep.notCheckable, sep.disabled = " ", true, true, true
    AddButton(sep, level)

    local category = categoryOf(item)
    if category then
      local hide = NewInfo()
      hide.text = "Hide from " .. viewerLabel(category)
      hide.notCheckable = true
      hide.func = function()
        M.SetSpellEnabled(category, spellID, false)
        CloseDropDownMenus()
      end
      AddButton(hide, level)
    end

    local close = NewInfo()
    close.text, close.notCheckable = CLOSE or "Close", true
    close.func = function() CloseDropDownMenus() end
    AddButton(close, level)
    return
  end

  if level == 2 and menuList == "alert" then
    local current = AL.GetType(spellID)
    for _, entry in ipairs(ALERT_TYPES) do
      local info = NewInfo()
      info.text = entry.label
      info.checked = (current == entry.value)
      if entry.value == "usable" and not usableApplies(item) then
        info.text = entry.label .. " |cff808080(n/a)|r"
        info.tooltipTitle = entry.label
        info.tooltipText = "This spell has no execute or reactive condition, so this alert would never fire."
        info.tooltipOnButton = true
      elseif entry.tip then
        info.tooltipTitle, info.tooltipText, info.tooltipOnButton = entry.label, entry.tip, true
      end
      info.func = function()
        AL.SetType(spellID, entry.value)
        if not entry.value then AL.ClearFX(item) end
        CloseDropDownMenus()
      end
      AddButton(info, level)
    end
    return
  end

  if level == 2 and menuList == "fx" then
    local current = AL.GetFX(spellID)
    for _, entry in ipairs(AL.FX) do
      local info = NewInfo()
      info.text = entry.name
      info.checked = (current == entry.id)
      info.func = function()
        AL.SetFX(spellID, entry.id)
        AL.ClearFX(item)
        AL.Preview(item, entry.id)   -- show the choice immediately
        CloseDropDownMenus()
      end
      AddButton(info, level)
    end
    return
  end

  if level == 2 and menuList == "window" then
    local current = AL.GetWindow(spellID)
    for _, frac in ipairs(WINDOWS) do
      local info = NewInfo()
      info.text = ("Last %d%%"):format(frac * 100)
      info.checked = (math.abs(current - frac) < 0.001)
      info.func = function() AL.SetWindow(spellID, frac); CloseDropDownMenus() end
      AddButton(info, level)
    end
    return
  end

  if level == 2 and menuList == "sound" then
    local current = M.GetReadySoundKit(spellID)
    local none = NewInfo()
    none.text, none.checked = "None", (current == nil)
    none.func = function() M.SetReadySoundKit(spellID, nil); CloseDropDownMenus() end
    AddButton(none, level)

    for _, category in ipairs(M.SOUND_CATEGORY_ORDER or {}) do
      local info = NewInfo()
      info.text, info.hasArrow, info.notCheckable = category, true, true
      info.menuList = "sound:" .. category
      AddButton(info, level)
    end
    return
  end

  if level >= 3 and type(menuList) == "string" and menuList:find("^sound:") then
    local category = menuList:sub(7)
    local current = M.GetReadySoundKit(spellID)
    for _, entry in ipairs((M.SOUND_DATA or {})[category] or {}) do
      local info = NewInfo()
      info.text, info.checked = entry.name, (current == entry.kit)
      info.func = function()
        M.SetReadySoundKit(spellID, entry.kit)
        M.PlayReadySound(entry.kit)   -- hear the choice as it is made
        CloseDropDownMenus()
      end
      AddButton(info, level)
    end
    return
  end
end

local function ensureMenu()
  if menu then return menu end
  menu = CreateFrame("Frame", "NE_CooldownViewerItemMenu", UIParent, TEMPLATE)
  Init(menu, initialize, "MENU")
  return menu
end

-- Open the menu on an item. Right-click only; left-click is left free for a future picker drag.
function M.ShowItemMenu(item)
  if not (item and item.spellID) then return end
  ctxItem = item
  Toggle(1, nil, ensureMenu(), item, 0, 0)
end

-- Attached by Viewers.lua to every cooldown item.
function M.ItemOnMouseUp(item, button)
  if button == "RightButton" then M.ShowItemMenu(item) end
end
