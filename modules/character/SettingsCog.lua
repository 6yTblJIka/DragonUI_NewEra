-- DragonUI_NewEra/modules/character/SettingsCog.lua — the settings gear in the character panel's
-- top-right corner, and the dropdown of display options it opens.
--
-- Art + build follow modules/talents/SpecTabs.lua's cog verbatim (questlog-icon-setting atlas with
-- the stock Interface\Buttons\UI-OptionsButton as the 3.3.5a fallback), so the two windows' gears
-- match. The menu itself is the native EasyMenu/UIDropDownMenu pattern used by modules/social/*.
--
-- PLACEMENT: seated LEFT of the close X, which PanelChrome anchors at TOPRIGHT(1,0) at 24x24. The
-- cog's frame level clears the whole chrome stack the same way the close button does — the nineslice
-- corner (level+1) and the title band (level+11) both paint over this corner otherwise.
--
-- ADDING AN OPTION: append to buildMenu(). Anything with a getter/setter pair on CP works; keep the
-- SETTING itself in the module that owns the feature (as CP.IsSlotItemLevelShown lives in
-- SlotItemLevel.lua) so this file stays presentation-only.

local NE = DragonUI_NewEra
NE.charpanel = NE.charpanel or {}
local CP = NE.charpanel

local MODULE = "character"
local L = NE.L or setmetatable({}, { __index = function(_, k) return k end })

local function log(msg) if CP._log then CP._log(msg) elseif NE.Log then NE.Log("CHARPANEL", msg) end end

local COG_SIZE = 18
local COG_X    = -28   -- clears the 24px close button at TOPRIGHT(1,0)
local COG_Y    = -5

-- ----------------------------------------------------------------------------
-- The dropdown. Rebuilt per open so the `checked` values are current.
-- ----------------------------------------------------------------------------
local menuFrame

local function buildMenu()
  return {
    { text = L["Character Panel"], isTitle = true, notCheckable = true },
    {
      text = L["Show Item Level on equipped items"],
      -- isNotRadio: a checkbox, not one-of-many. keepShownOnClick lets several options be toggled
      -- in one visit instead of the menu closing after each.
      isNotRadio       = true,
      keepShownOnClick = true,
      checked          = function() return CP.IsSlotItemLevelShown and CP.IsSlotItemLevelShown() end,
      func = function()
        if not (CP.IsSlotItemLevelShown and CP.SetSlotItemLevelShown) then return end
        CP.SetSlotItemLevelShown(not CP.IsSlotItemLevelShown())
      end,
    },
  }
end

local function openMenu(anchor)
  if not EasyMenu then log("EasyMenu absent; settings cog has nothing to open"); return end
  if not menuFrame then
    menuFrame = CreateFrame("Frame", "NE_CharacterSettingsMenu", UIParent, "UIDropDownMenuTemplate")
  end
  EasyMenu(buildMenu(), menuFrame, anchor, 0, 0, "MENU")
end

-- ----------------------------------------------------------------------------
-- The gear button.
-- ----------------------------------------------------------------------------
local function buildCog()
  local f = CP.frame
  if not f then return nil end
  if CP._settingsCog then return CP._settingsCog end

  local cog = CreateFrame("Button", "NE_CharacterSettingsCog", f)
  cog:SetSize(COG_SIZE, COG_SIZE)

  cog.Icon = cog:CreateTexture(nil, "ARTWORK")
  if not (NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(cog.Icon, "questlog-icon-setting", true)) then
    cog.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton"); cog.Icon:SetSize(16, 16)
  end
  cog.Icon:SetPoint("CENTER")

  cog.Hi = cog:CreateTexture(nil, "HIGHLIGHT")
  if not (NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(cog.Hi, "questlog-icon-setting", true)) then
    cog.Hi:SetTexture("Interface\\Buttons\\UI-OptionsButton"); cog.Hi:SetSize(16, 16)
  end
  cog.Hi:SetPoint("CENTER"); cog.Hi:SetBlendMode("ADD"); cog.Hi:SetAlpha(0.4)

  -- Above the nineslice corner + title band, matching how CloseButton.lua lifts the X.
  cog:SetFrameLevel(((f.GetFrameLevel and f:GetFrameLevel()) or 1) + 20)
  cog:SetPoint("TOPRIGHT", f, "TOPRIGHT", COG_X, COG_Y)

  cog:RegisterForClicks("LeftButtonUp")
  cog:SetScript("OnClick", function(self) openMenu(self) end)
  cog:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Character panel settings"], 1, 1, 1)
    GameTooltip:Show()
  end)
  cog:SetScript("OnLeave", function() GameTooltip:Hide() end)

  CP._settingsCog = cog
  return cog
end

CP.BuildSettingsCog = buildCog

-- ----------------------------------------------------------------------------
-- A POINTER in the New Era options tab — not the settings themselves.
--
-- The character panel's display options live on the cog because they're judged by eye on the panel
-- you're looking at, and because a global tab shouldn't accumulate one window's cosmetic toggles.
-- That's the same split the Cooldown Manager section makes ("every setting ... lives in the Cooldown
-- Manager window itself (/cdm)"). The cost of that split is discoverability — a gear in a title bar
-- is easy to miss — so the tab carries a line telling you where to look, and nothing more. Do NOT
-- add the toggles here too: two homes for one setting is how they drift.
-- ----------------------------------------------------------------------------
if NE.RegisterOptionSection then
  NE.RegisterOptionSection({
    id    = "characterpanel",
    order = 30,   -- ahead of Cooldown Manager (40) and Level Up Display (45)
    build = function(scroll, C)
      if C.AddSpacer then C:AddSpacer(scroll) end
      C:AddHeading(scroll, "Character Panel")
      C:AddDescription(scroll,
        "Display options for the character panel — including |cffffcc55item level on equipped "
        .. "items|r — live on the |cffffcc55cog in the panel's top-right corner|r, next to the close "
        .. "button. They're there so you can see each change land on the panel as you make it.")
    end,
  })
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
  if NE.modules and NE.modules.IsEnabled and not NE.modules.IsEnabled(MODULE) then return end
  -- The frame owns the corner we anchor into; build it first (idempotent), same as CloseButton.lua.
  if CP.BuildFrame then pcall(CP.BuildFrame) end
  local ok, err = pcall(buildCog)
  if not ok then log("settings cog build failed: " .. tostring(err)) end
end)
