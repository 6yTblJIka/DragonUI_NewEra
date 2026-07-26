-- DragonUI_NewEra/modules/cooldownviewer/SettingsPanel.lua — the /cdm settings window.
--
-- Phase 4b-1: the SHELL only. Chrome, the Spells/Auras side tabs, the scroll body, the search box,
-- and the open/close plumbing. The category grids (4b-2) and the item context menu that actually
-- assigns things (4b-3) build on top; `CDS.RefreshLayout` is the stub they replace.
--
-- Downport of NewEra/CooldownViewerSettings/Panel.lua (612 lines). See PORT_PLAN §G for the full
-- scope. What changed and why:
--
--   * TWO side tabs, not three. The Group Buffs tab hosts NE.groupbuff.filter, a module this addon
--     does not have (12 references). Dropped whole, along with CDS.UpdateGroupBuffsTabState.
--
--   * NO strata-raising hack. Upstream fights a real problem — Era opens context menus at
--     FULLSCREEN_DIALOG, the same strata as its panel, so menus rendered BEHIND it and had to be
--     raised to TOOLTIP inside securecallfunction. 3.3.5a's UIDropDownMenu opens its list frames at
--     DIALOG and we sit at MEDIUM, so menus clear us naturally. The whole raiseMenuAbovePanel /
--     securecallfunction contract is unnecessary here and is not ported.
--
--   * NO WowStyle1DropdownTemplate. That template is retail-only. The footer layout dropdown is
--     Phase 4b-5, and the Auras tab's auto-track dropdown already has a working equivalent in the
--     options tab, so neither is rebuilt here.
--
--   * The settings cog landed in 4b-3, once core/Menu.lua existed to give it a menu. Revert is
--     still deferred: it needs the snapshot/restore pair, which belongs with presets (4b-5).
--
-- Taint: a plain display window. No secure templates, no protected frames, SavedVariables reads
-- only. Nothing here can taint the combat path.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

NE.cooldownviewersettings = NE.cooldownviewersettings or {}
local CDS = NE.cooldownviewersettings

local PANEL_NAME = "NE_CooldownViewerSettings"
local PANEL_W, PANEL_H = 399, 609
local PANEL_SCALE = 1.3

-- Which side tab a viewer category belongs to. Essential/Utility are spellbook-driven; the buff
-- viewers are aura-driven.
local CATEGORY_TO_MODE = {
  essential = "spells",
  utility   = "spells",
  buffIcon  = "auras",
  buffBar   = "auras",
}

local panel        -- lazily built on first open
local currentMode  -- "spells" | "auras"

-- ── Build ───────────────────────────────────────────────────────────────────────────────────────

local function build()
  if panel then return panel end

  local f = CreateFrame("Frame", PANEL_NAME, UIParent, "ButtonFrameTemplate")
  f:SetSize(PANEL_W, PANEL_H)
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)

  -- MEDIUM, matching our other standalone windows. Upstream needs DIALOG + SetToplevel to clear a
  -- retail Edit Mode overlay that does not exist here; sitting lower keeps dropdown lists (DIALOG
  -- on this client) above us without any per-menu strata juggling.
  f:SetFrameStrata("MEDIUM")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)
  f:Hide()

  -- Re-pull icons when the client reports them changed, and when an item's data finally arrives —
  -- an equip row's icon is nil until the server delivers it.
  f:RegisterEvent("SPELL_UPDATE_ICON")
  f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  -- A trinket swap changes the discovery set, so the Trinkets section has to re-source. Registered
  -- unfiltered: RegisterUnitEvent is our own compat shim and this frame has no other unit events.
  f:RegisterEvent("UNIT_INVENTORY_CHANGED")
  f:SetScript("OnEvent", function(self)
    if self:IsShown() then CDS.RefreshLayout() end
  end)

  -- On OnHide, not in HidePanel: the close button and ESC both call Hide() directly. A drag in
  -- flight owns a cursor icon parented to UIParent and a dimmed, locked source tile, and closing
  -- the window out from under it would strand both.
  f:HookScript("OnHide", function()
    if CDS.CancelDrag then CDS.CancelDrag() end
  end)

  -- Shared modern chrome: hides the classic ButtonFrameTemplate border, applies our nineslice,
  -- retextures the streaks and sets the title styling. Same path modules/collections/Window.lua uses.
  local PC = NE.panelchrome
  if PC and PC.Apply then
    PC.Apply(f, { layout = "PortraitFrameTemplate", title = "Cooldown Manager", noPortrait = true })
  end

  -- Retail fills the Inset with character-panel-background rather than the rock marble. That atlas
  -- is already registered by modules/character/Assets.lua. PC.Keep guards it against any later
  -- BACKGROUND-layer teardown.
  if f.Inset and NE.tex and NE.tex.SetAtlas then
    if f.Inset.Bg then f.Inset.Bg:Hide() end
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetPoint("TOPLEFT",     f.Inset, "TOPLEFT",     0, 0)
    bg:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", 0, 0)
    NE.tex.SetAtlas(bg, "character-panel-background", false)
    f.bg = bg
    if PC and PC.Keep then PC.Keep(f, bg) end
  end
  if PC and PC.ModernizeCloseButton then PC.ModernizeCloseButton(f.CloseButton) end

  -- Portrait: retail shows the spec icon. No specs on 3.3.5a, so use the class icon — the same
  -- fallback the character panel's spec portrait uses, and a solid circle that fills the cutout.
  if f.portrait and NE.portrait and NE.portrait.ApplyCutout then
    local _, class = UnitClass("player")
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    f.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    if coords then f.portrait:SetTexCoord(unpack(coords)) end
    NE.portrait.ApplyCutout(f.portrait, f)
  end

  if NE.FrameUtil then
    -- 1.3 = the owner's +30%. Applied as a SCALE, not by growing PANEL_W/H: the grid geometry
    -- (38px tiles on a 46px pitch, 7 to a row, a 344-wide category) is upstream's probe-confirmed
    -- layout, and a bigger frame around unchanged tiles would just add margin. PinPixelPerfect
    -- folds this into its pixel-snap target and re-applies it on any UI-scale change.
    if NE.FrameUtil.PinPixelPerfect then NE.FrameUtil.PinPixelPerfect(f, PANEL_SCALE) end
    if NE.FrameUtil.EscClose then NE.FrameUtil.EscClose(PANEL_NAME) end
    if NE.FrameUtil.WirePanelSounds then
      -- Retail plays the class-talent open/close kits; those are retail sound IDs, so the helper's
      -- vanilla character-pane fallback is what actually sounds here.
      NE.FrameUtil.WirePanelSounds(f, nil, nil,
        SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN,
        SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end
  end

  -- Side tabs, hung off the right edge. Anchors mirror retail's QuestMapFrame: first
  -- TOPLEFT -> panel TOPRIGHT(+1,-28), next TOP -> prev BOTTOM(0,-3). Retail reuses one glyph for
  -- both active and inactive states, so only activeAtlas is passed.
  f.spellsTab = NE.tabs.MakeSideTab(f, {
    activeAtlas = "icon_cooldownmanager", tooltip = "Spells", iconSize = 32,
    onClick = function() CDS.SetDisplayMode("spells") end,
  })
  f.spellsTab.displayMode = "spells"
  f.spellsTab:SetPoint("TOPLEFT", f, "TOPRIGHT", 1, -28)

  f.aurasTab = NE.tabs.MakeSideTab(f, {
    activeAtlas = "icon_trackedbuffs", tooltip = "Tracked Buffs", iconSize = 32,
    onClick = function() CDS.SetDisplayMode("auras") end,
  })
  f.aurasTab.displayMode = "auras"
  f.aurasTab:SetPoint("TOP", f.spellsTab, "BOTTOM", 0, -3)

  f.tabButtons = { f.spellsTab, f.aurasTab }

  -- Search box. Filtering DIMS non-matching items in place rather than reflowing the grid, which is
  -- what retail does; Categories.lua owns the per-item overlay in 4b-2.
  f.search = CreateFrame("EditBox", PANEL_NAME .. "Search", f, "SearchBoxTemplate")
  f.search:SetSize(290, 30)
  f.search:SetPoint("TOPLEFT", 72, -30)
  f.search:SetAutoFocus(false)
  f.search:HookScript("OnTextChanged", function()
    if CDS.ApplyItemFilter then CDS.ApplyItemFilter(CDS.GetSearchText()) end
  end)

  -- Settings cog, immediately right of the search box (retail anchors its SettingsDropdown
  -- LEFT -> SearchBox.RIGHT +5). Same 16x18 native-atlas recipe as the spellbook and professions
  -- cogs; the menu itself is SettingsMenu.lua's, opened through NE.menu so it toggles closed on a
  -- second click.
  local cog = CreateFrame("Button", nil, f)
  cog:SetSize(16, 18)
  cog:SetPoint("LEFT", f.search, "RIGHT", 5, 0)
  cog.Icon = cog:CreateTexture(nil, "ARTWORK")
  if not (NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(cog.Icon, "questlog-icon-setting", true)) then
    cog.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    cog.Icon:SetSize(16, 16)
  end
  cog.Icon:SetPoint("CENTER")
  cog.Hi = cog:CreateTexture(nil, "HIGHLIGHT")
  if not (NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(cog.Hi, "questlog-icon-setting", true)) then
    cog.Hi:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    cog.Hi:SetSize(16, 16)
  end
  cog.Hi:SetPoint("CENTER")
  cog.Hi:SetBlendMode("ADD")
  cog.Hi:SetAlpha(0.4)
  cog:SetScript("OnClick", function(self)
    if CDS.ToggleSettingsMenu then CDS.ToggleSettingsMenu(self) end
  end)
  cog:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Options")
    GameTooltip:Show()
  end)
  cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.settingsCog = cog

  -- Scrollable body. A plain UIPanelScrollFrameTemplate — upstream uses the same, and there is no
  -- WowScrollBox anywhere in the source to have to replace.
  f.scroll = CreateFrame("ScrollFrame", PANEL_NAME .. "Scroll", f, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", 17, -72)
  f.scroll:SetPoint("BOTTOMRIGHT", -30, 29)
  f.content = CreateFrame("Frame", nil, f.scroll)
  f.content:SetSize(330, 1)
  f.scroll:SetScrollChild(f.content)
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(f.scroll) end

  -- Placeholder while the grids are unbuilt. Removed in 4b-2.
  f.placeholder = f.content:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
  f.placeholder:SetPoint("TOP", f.content, "TOP", 0, -40)
  f.placeholder:SetWidth(300)
  f.placeholder:SetJustifyH("CENTER")
  f.placeholder:SetText("Spell list coming in the next step.")

  panel = f
  CDS.panel = f
  return f
end

CDS.Build = build

-- ── Display mode ────────────────────────────────────────────────────────────────────────────────

function CDS.SetDisplayMode(mode)
  build()
  if mode ~= "spells" and mode ~= "auras" then mode = "spells" end
  currentMode = mode
  CDS.displayMode = mode   -- read by the category grids in 4b-2

  for _, tab in ipairs(panel.tabButtons) do
    tab:SetSelectedState(tab.displayMode == mode)
  end

  CDS.RefreshLayout()
end

function CDS.GetDisplayMode() return currentMode end

-- ── Search text ─────────────────────────────────────────────────────────────────────────────────
-- ClassicAPI's SearchBoxTemplate has NO Instructions FontString: its placeholder IS the edit box's
-- text (SearchBoxTemplate_OnLoad calls SetText(SEARCH), and OnEditFocusLost puts it back). So an
-- untouched search box reads back "Search", and handing that to the filter dimmed every tile in the
-- panel to 25% — which is what "all the icons are greyed out" turned out to be. Every read of the
-- box goes through here.
function CDS.GetSearchText()
  if not (panel and panel.search) then return "" end
  local t = panel.search:GetText() or ""
  if t == (SEARCH or "Search") then return "" end
  return t
end

-- Replaced in 4b-2 by the real category-grid builder.
function CDS.RefreshLayout()
  if not panel then return end
  if panel.placeholder then
    panel.placeholder:SetText(currentMode == "auras"
      and "Tracked buff list coming in the next step."
      or  "Spell list coming in the next step.")
  end
end

-- ── Public entry points ─────────────────────────────────────────────────────────────────────────

function CDS.ShowPanel()
  build()
  if not currentMode then CDS.SetDisplayMode("spells") else CDS.RefreshLayout() end
  panel:Show()
end

function CDS.HidePanel()
  if panel then panel:Hide() end
end

function CDS.TogglePanel()
  build()
  if panel:IsShown() then panel:Hide() else CDS.ShowPanel() end
end

-- Open with a viewer category pre-selecting the right tab.
function CDS.OpenTo(category)
  build()
  CDS.ShowPanel()
  CDS.SetDisplayMode(CATEGORY_TO_MODE[category] or "spells")
end

-- One entry point for slash commands and any future keybind.
M.OpenSettingsPanel = function(category) CDS.OpenTo(category) end

SLASH_NECDMSETTINGS1 = "/cdm"
SlashCmdList["NECDMSETTINGS"] = function() CDS.TogglePanel() end
