-- DragonUI_NewEra/modules/professions/Window.lua — standalone crafting window HOST.
--
-- DOWNPORT: adapted from NewEra_ReferenceFolder/NewEra/Professions/Crafting.lua (the chrome
-- shell section). Creates NE_ProfessionsCraftingFrame (942×658), wires the TRADE_SKILL_SHOW /
-- CRAFT_SHOW event interception, and exposes C.Show / C.Hide / C.Refresh for the renderer
-- (RecipeList.lua + Crafting.lua).
--
-- EVENT INTERCEPT STRATEGY (3.3.5a):
--   TradeSkillFrame / CraftFrame are UIPanel frames registered with UISpecialFrames.
--   We hide them in OnShow via hooksecurefunc on their Show method, then show our own frame.
--   We register for TRADE_SKILL_SHOW / CRAFT_SHOW on a plain EventFrame and suppress the
--   Blizzard frame by calling their :Hide() immediately. This avoids taint from combat and is
--   the same approach used by the spellbook module for ToggleSpellBook.
--
-- SHARED INTERFACE (RecipeList.lua + Crafting.lua depend on these):
--   C.frame           NE_ProfessionsCraftingFrame (global)
--   C.mode            "tradeskill" | "craft"
--   C._selected       currently-selected recipe table or nil
--   C._professionName currently-open profession name or nil
--   C.Show()          show the window + refresh
--   C.Hide()          hide the window
--   C.Refresh()       rebuild recipe list + update rank bar
--   C.SetProfession() theme portrait/title/bg for the current profession (defined in Crafting.lua)
--   C.RefreshRecipes() rebuild the recipe list (defined in RecipeList.lua)
--   C.UpdateRank()    update skill bar (defined in Crafting.lua)

local NE = DragonUI_NewEra
NE.profcraft = NE.profcraft or {}
local C = NE.profcraft

-- Geometry (retail-confirmed via probe; 942×658 is the normal/full view).
local FRAME_W, FRAME_H         = 942, 658
local RANKBAR_W, RANKBAR_H     = 453, 18
local RANKBAR_TL               = { 280, -34 }   -- TOPLEFT offset from frame (upper band, under the title)
local RECIPELIST_W             = 274
local RECIPELIST_TL            = { 5,  -72 }   -- below the rank bar; matches spellbook's content top
local RECIPELIST_BL            = { 0,   5  }
local SCHEMATIC_W, SCHEMATIC_H = 655, 553

C.FRAME_W        = FRAME_W
C.FRAME_H        = FRAME_H
C.RANKBAR_W      = RANKBAR_W
C.RANKBAR_H      = RANKBAR_H
C.RANKBAR_TL     = RANKBAR_TL
C.RECIPELIST_W   = RECIPELIST_W
C.RECIPELIST_TL  = RECIPELIST_TL
C.RECIPELIST_BL  = RECIPELIST_BL
C.SCHEMATIC_W    = SCHEMATIC_W
C.SCHEMATIC_H    = SCHEMATIC_H

local ATLAS_RECIPE_BG   = "professions-recipe-background"
local ATLAS_SKILL_BG    = "professions-skillbar-bg"
local ATLAS_SKILL_FRAME = "professions-skillbar-frame"
C.ATLAS_RECIPE_BG   = ATLAS_RECIPE_BG
C.ATLAS_SKILL_BG    = ATLAS_SKILL_BG
C.ATLAS_SKILL_FRAME = ATLAS_SKILL_FRAME

local SKILLBAR_PREWARM_ATLASES = {
  "skillbar_fill_flipbook_defaultblue",
  "skillbar_fill_flipbook_alchemy",
  "skillbar_fill_flipbook_blacksmithing",
  "skillbar_fill_flipbook_cooking",
  "skillbar_fill_flipbook_enchanting",
  "skillbar_fill_flipbook_engineering",
  "skillbar_fill_flipbook_inscription",
  "skillbar_fill_flipbook_jewelcrafting",
  "skillbar_fill_flipbook_leatherworking",
  "skillbar_fill_flipbook_tailoring",
  "skillbar_fill_flipbook_skinning",
}

-- Right-panel recipe parchment sheets (SetProfession() picks one of these per-kit files the
-- first time that profession is opened). Each is its own standalone BLP -- unlike the skillbar
-- flipbooks above, none of them share a file with anything already prewarmed, so the FIRST
-- profession a player opens in a session can render its parchment as a black frame / stale art
-- while the BLP streams in from disk. Prewarm every kit file up front the same way.
local RECIPE_BG_PREWARM_FILES = {
  4659666,  -- generic fallback
  4625450,  -- alchemy
  4625448,  -- blacksmithing
  4723320,  -- enchanting
  4722478,  -- engineering
  4723159,  -- herbalism
  4723154,  -- leatherworking
  4723189,  -- mining
  4723308,  -- skinning
  4627497,  -- tailoring
  4671747,  -- cooking
  4723316,  -- fishing
  4723119,  -- inscription
  4723112,  -- jewelcrafting
}

local FRAME_NAME = "NE_ProfessionsCraftingFrame"
local MODULE     = "Professions"

-- Window scale factor. The reference geometry (942×658) is retail's full-screen size; on a
-- 3.3.5a UI that follows UIParent we apply SB.UI_SCALE = 0.8 to keep it compact (≈754×526).
-- NE.scale.Apply is the preferred path; the hard-coded SetScale is a reliable fallback.
local WINDOW_SCALE = 0.8

local function applyWindowScale(f)
  if NE.scale and NE.scale.Apply then
    if f and NE.scale.SetFrame then NE.scale.SetFrame("professions", f) end
    NE.scale.Apply("professions")
  elseif f and f.SetScale then
    f:SetScale(WINDOW_SCALE)
  end
end

-- Minimal logger (same pattern as spellbook).
local function log(msg)
  if NE.Log then NE.Log("PROFESSIONS", msg); return end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc55DragonUI_NewEra|r [professions]: " .. tostring(msg))
  end
end
C._log = log

local function guard(label, fn)
  local ok, err = pcall(fn)
  if not ok then log(label .. " failed: " .. tostring(err)) end
  return ok
end

-- ============================================================================
-- Blizzard frame suppression.
-- TradeSkillFrame and CraftFrame are loads-on-demand (LoD) in WotLK 3.3.5a — they do NOT
-- exist at PLAYER_LOGIN. They are created the FIRST time TRADE_SKILL_SHOW / CRAFT_SHOW
-- fires and the LoD addon loads. We cannot hook their Show at login time.
-- Strategy: cloak them (non-interactive + off-screen) instead of :Hide(). On 3.3.5a some
-- client builds tie profession-session lifetime to the Blizzard frame's hide path; hard-hide
-- can drop recipe data and cause first-open races. Cloaking preserves the session while our
-- custom window renders the UI.
-- ============================================================================
local function hideBlizzardTradeSkillFrames()
  local function stripSpecial(name)
    if not (UISpecialFrames and name) then return end
    for i = #UISpecialFrames, 1, -1 do
      if UISpecialFrames[i] == name then
        tremove(UISpecialFrames, i)
      end
    end
  end

  local function suppress(frame, name)
    if not frame then return end
    local function cloak(self)
      if not self then return end
      if self.SetAlpha then self:SetAlpha(0) end
      if self.EnableMouse then self:EnableMouse(false) end
      if self.ClearAllPoints and self.SetPoint then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -1200, -1200)
      end
    end
    if not frame._neProfcraftSuppressed then
      frame._neProfcraftSuppressed = true
      frame:HookScript("OnShow", function(self)
        cloak(self)
      end)
    end
    stripSpecial(name)
    cloak(frame)
  end

  suppress(_G.TradeSkillFrame, "TradeSkillFrame")
  suppress(_G.CraftFrame, "CraftFrame")

end

-- ============================================================================
-- Chrome builder — PortraitFrameTemplate metal frame + rock body + title + close button.
-- Mirrors the reference Crafting.lua buildChrome() with 3.3.5a compat guards.
-- ============================================================================
local function buildChrome(f)
  -- Rock body background (same FDID 374155 used by Character panel, already registered in
  -- Textures/Assets.lua — so no double-registration needed).
  local body = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  local rockPath = NE.tex.localFiles and NE.tex.localFiles[374155]
  if rockPath then
    body:SetTexture(rockPath, "REPEAT", "REPEAT")
    body:SetHorizTile(true); body:SetVertTile(true)
  else
    body:SetTexture(374155, "REPEAT", "REPEAT")
    body:SetHorizTile(true); body:SetVertTile(true)
  end
  body:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -21)
  body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  0,  0)
  f.bodyBg = body

  -- TopTileStreaks decorative band.
  local streaks = f:CreateTexture(nil, "BORDER")
  if NE.tex and NE.tex.SetAtlas then
    NE.tex.SetAtlas(streaks, "_UI-Frame-TopTileStreaks", false)
  end
  streaks:SetHorizTile(true); streaks:SetHeight(43)
  streaks:SetPoint("TOPLEFT",  f, "TOPLEFT",   6, -21)
  streaks:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)
  f.topStreaks = streaks

  -- Metal nineslice (PortraitFrameTemplate).
  local ns = CreateFrame("Frame", nil, f)
  ns:SetAllPoints(f); ns:EnableMouse(false)
  if NE.nineslice and NE.nineslice.ApplyLayout then
    guard("nineslice", function() NE.nineslice.ApplyLayout(ns, "PortraitFrameTemplate") end)
  end
  f.NineSlice = ns

  -- Portrait texture (circular crop via NE.portrait.ApplyCutout).
  guard("portrait", function()
    local ringFrame = f.NineSlice or f
    if not f.PortraitTex then
      f.PortraitTex = ringFrame:CreateTexture(nil, "ARTWORK")
    end
    if NE.portrait and NE.portrait.ApplyCutout then
      NE.portrait.ApplyCutout(f.PortraitTex, f)
    end
    -- 3.3.5a circular clip: CreateMaskTexture returns nil here, so ApplyCutout's mask
    -- path no-ops. Use the older Texture:SetMask() API which IS functional on 3.3.5a
    -- and applies TempPortraitAlphaMask as a circular alpha shape.
    if f.PortraitTex.SetMask then
      f.PortraitTex:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    -- Placeholder icon until C.SetProfession is called.
    f.PortraitTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end)

  -- Title container (probe-confirmed TOPLEFT(58,-1)/TOPRIGHT(-24,-1)).
  local tc = CreateFrame("Frame", nil, f)
  tc:SetFrameLevel((ns:GetFrameLevel() or 2) + 10)
  tc:SetPoint("TOPLEFT",  f, "TOPLEFT",  58, -1)
  tc:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -1)
  tc:SetHeight(20); tc:EnableMouse(false)
  local titleStr = tc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- Centered in the true middle of the window (symmetric insets clear the portrait + close button),
  -- matching how the Character window centers the player name.
  titleStr:SetJustifyH("CENTER")
  titleStr:SetPoint("TOP",   f, "TOP",    0,  -6)
  titleStr:SetPoint("LEFT",  f, "LEFT",   58,  0)
  titleStr:SetPoint("RIGHT", f, "RIGHT", -58,  0)
  titleStr:SetText(_G.TRADE_SKILLS or "Professions")
  f.TitleText = titleStr
  f.TitleContainer = tc
  f._neTitle = titleStr   -- C.SetProfession writes here
  -- Also wire the standard NE.panelchrome path (belt + suspenders).
  guard("chrome.title", function()
    if NE.panelchrome and NE.panelchrome.SetTitle then
      NE.panelchrome.SetTitle(f, _G.TRADE_SKILLS or "Professions")
    end
  end)

  -- Close button: UIPanelCloseButton reskinned with the modern RedButton-Exit art.
  local close = CreateFrame("Button", "NE_ProfessionsCraftingCloseButton", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 0)
  close:SetFrameLevel((ns:GetFrameLevel() or 2) + 10)
  close:SetScript("OnClick", function()
    if C.mode == "craft" then
      if CloseCraft then pcall(CloseCraft) end
    else
      if CloseTradeSkill then pcall(CloseTradeSkill) end
    end
    C.Hide()
  end)
  guard("closeButton.modernize", function()
    if NE.panelchrome and NE.panelchrome.ModernizeCloseButton then
      NE.panelchrome.ModernizeCloseButton(close, { frameLevelBump = 10 })
    end
  end)
  f.CloseButton = close
end

-- ============================================================================
-- Cog settings (top-right, like the spellbook). Two persisted options:
--   hideListTooltips  — don't show recipe tooltips when hovering the left list
--   colorByDifficulty — colour recipe names by skill difficulty (orange/yellow/green/grey)
-- Options live on C.opts and persist in DragonUI_NewEraDB.professions.
-- ============================================================================
C.opts = C.opts or { hideListTooltips = false, colorByDifficulty = false, genericBar = false }

local function loadOpts()
  local root = _G.DragonUI_NewEraDB
  local o = root and root.professions
  if type(o) == "table" then
    if o.hideListTooltips  ~= nil then C.opts.hideListTooltips  = o.hideListTooltips  and true or false end
    if o.colorByDifficulty ~= nil then C.opts.colorByDifficulty = o.colorByDifficulty and true or false end
    if o.genericBar        ~= nil then C.opts.genericBar        = o.genericBar        and true or false end
  end
end

local function saveOpts()
  _G.DragonUI_NewEraDB = _G.DragonUI_NewEraDB or {}
  local o = _G.DragonUI_NewEraDB.professions or {}
  o.hideListTooltips  = C.opts.hideListTooltips
  o.colorByDifficulty = C.opts.colorByDifficulty
  o.genericBar        = C.opts.genericBar
  _G.DragonUI_NewEraDB.professions = o
end

local function prewarmSkillBarAtlases()
  if C._barPrewarmed then return end
  C._barPrewarmed = true

  local pw = CreateFrame("Frame", nil, UIParent)
  pw:SetFrameStrata("BACKGROUND")
  pw:SetFrameLevel(1)
  pw:SetSize(2, 2)
  pw:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)

  local previous
  for index, atlasName in ipairs(SKILLBAR_PREWARM_ATLASES) do
    local tex = pw:CreateTexture(nil, "BACKGROUND")
    tex:SetSize(1, 1)
    if previous then
      tex:SetPoint("LEFT", previous, "RIGHT", 0, 0)
    else
      tex:SetPoint("LEFT", pw, "LEFT", 0, 0)
    end

    local applied = NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(tex, atlasName, false)
    if applied then
      tex:SetAlpha(0.01)
      tex:Show()
      previous = tex
    else
      tex:Hide()
    end
  end

  -- Also force each per-profession recipe-parchment BLP GPU-resident (see
  -- RECIPE_BG_PREWARM_FILES comment): whole-file SetTexture, same shown frame.
  for _, fdid in ipairs(RECIPE_BG_PREWARM_FILES) do
    local path = NE.tex and NE.tex.localFiles and NE.tex.localFiles[fdid]
    if path then
      local tex = pw:CreateTexture(nil, "BACKGROUND")
      tex:SetSize(1, 1)
      if previous then
        tex:SetPoint("LEFT", previous, "RIGHT", 0, 0)
      else
        tex:SetPoint("LEFT", pw, "LEFT", 0, 0)
      end
      tex:SetTexture(path)
      tex:SetAlpha(0.01)
      tex:Show()
      previous = tex
    end
  end

  pw:Show()
  C._barPrewarm = pw
end

local function buildCogMenu(f, cog)
  if f.CogMenu then return f.CogMenu end
  local menu = CreateFrame("Frame", "NE_ProfessionsCraftingCogMenu", cog)
  menu:SetSize(236, 106)
  menu:SetFrameStrata("DIALOG")
  menu:SetPoint("TOPRIGHT", cog, "BOTTOMRIGHT", 0, -2)
  if menu.SetBackdrop then
    menu:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
  end
  menu:Hide(); menu:EnableMouse(true)

  local function checkRow(label, getfn, setfn, y)
    local cb = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
    cb:SetSize(20, 20); cb:SetPoint("TOPLEFT", 10, y)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0); fs:SetText(label)
    cb:SetChecked(getfn())
    cb:SetScript("OnClick", function(self) setfn(self:GetChecked() and true or false) end)
    cb._sync = function() cb:SetChecked(getfn()) end
    return cb
  end

  menu.cbTip = checkRow("Hide item tooltips in list",
    function() return C.opts.hideListTooltips end,
    function(v) C.opts.hideListTooltips = v; saveOpts() end, -12)
  menu.cbDiff = checkRow("Colour names by skill difficulty",
    function() return C.opts.colorByDifficulty end,
    function(v)
      C.opts.colorByDifficulty = v; saveOpts()
      if C.RefreshRecipes then C.RefreshRecipes() end
    end, -40)
  menu.cbBar = checkRow("Plain skill bar (no animation)",
    function() return C.opts.genericBar end,
    function(v)
      C.opts.genericBar = v; saveOpts()
      if C.UpdateRank then C.UpdateRank() end
    end, -68)

  menu:SetScript("OnShow", function(self)
    if self.cbTip  and self.cbTip._sync  then self.cbTip._sync()  end
    if self.cbDiff and self.cbDiff._sync then self.cbDiff._sync() end
    if self.cbBar  and self.cbBar._sync  then self.cbBar._sync()  end
  end)
  f:HookScript("OnHide", function() menu:Hide() end)
  f.CogMenu = menu
  return menu
end

local function buildCog(f)
  if f.Cog then return f.Cog end
  local cog = CreateFrame("Button", "NE_ProfessionsCraftingCog", f)
  cog:SetSize(16, 18)
  cog:SetFrameLevel((f.NineSlice and f.NineSlice.GetFrameLevel and f.NineSlice:GetFrameLevel() or f:GetFrameLevel() or 2) + 10)
  -- Same spot as the spellbook cog: frame-relative TOPRIGHT (-14, -38) — just below the close button.
  cog:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -38)
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
  cog:SetScript("OnClick", function()
    local menu = buildCogMenu(f, cog)
    if menu:IsShown() then menu:Hide() else menu:Show() end
  end)
  f.Cog = cog
  return cog
end

-- ============================================================================
-- Build the window shell ONCE.
-- ============================================================================
local function buildWindow()
  if C.frame then return C.frame end

  local f = CreateFrame("Frame", FRAME_NAME, UIParent)
  f:SetSize(FRAME_W, FRAME_H)
  f:SetPoint("TOP", UIParent, "TOP", 0, -55)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:Hide()
  C.frame = f

  -- Drag-to-move with saved position.
  if NE.FrameUtil and NE.FrameUtil.PersistWindowPosition then
    NE.FrameUtil.PersistWindowPosition(f, "professions",
      { point = "TOP", relPoint = "TOP", x = 0, y = -55 })
  else
    f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
  end

  -- Open/close sounds.
  guard("sounds", function()
    if NE.FrameUtil and NE.FrameUtil.WirePanelSounds then
      NE.FrameUtil.WirePanelSounds(f, "igCharacterInfoOpen", "igCharacterInfoClose")
    end
  end)

  -- ESC closes the window (queues CloseTradeSkill/CloseCraft via the close-button script).
  guard("escClose", function()
    if NE.FrameUtil and NE.FrameUtil.EscClose then
      NE.FrameUtil.EscClose(FRAME_NAME)
    else
      tinsert(UISpecialFrames, FRAME_NAME)
    end
  end)

  -- Chrome (portrait frame, rock bg, title, close).
  guard("buildChrome", function() buildChrome(f) end)

  -- Cog settings button (top-right, left of the close button).
  guard("buildCog", function() buildCog(f) end)

  -- Window scale.
  guard("windowScale", function() applyWindowScale(f) end)
  f:HookScript("OnShow", function(self) applyWindowScale(self) end)

  -- Refresh content on every show.
  f:HookScript("OnShow", function()
    if C.Refresh then guard("refresh.onshow", C.Refresh) end
  end)

  -- Ensure focused EditBoxes inside the panel don't keep swallowing ESC after close.
  f:HookScript("OnHide", function()
    if CloseDropDownMenus then pcall(CloseDropDownMenus) end
    local sb = f.RecipeList and f.RecipeList.SearchBox
    if sb and sb.ClearFocus then sb:ClearFocus() end

    if GetCurrentKeyBoardFocus then
      local kf = GetCurrentKeyBoardFocus()
      if kf and kf.ClearFocus then pcall(kf.ClearFocus, kf) end
    end

    -- If hidden via ESC (UISpecialFrames path), explicitly close the underlying profession
    -- session so the client doesn't keep consuming ESC on an invisible tradeskill state.
    if not f._neClosingSession then
      f._neClosingSession = true
      if C.mode == "craft" then
        if CloseCraft then pcall(CloseCraft) end
      else
        if CloseTradeSkill then pcall(CloseTradeSkill) end
      end
      f._neClosingSession = nil
    end
  end)

  -- Build sub-panels (RecipeList + SchematicForm + RankBar + CreateControls).
  -- These functions are defined in RecipeList.lua and Crafting.lua which load AFTER this file.
  -- We defer building them to the first Show so all functions are guaranteed to exist by then.
  f._subBuilt = false
  f:HookScript("OnShow", function()
    if not f._subBuilt then
      f._subBuilt = true
      guard("buildRecipeList",    function() if C.buildRecipeList    then C.buildRecipeList(f)    end end)
      guard("buildSchematicForm", function() if C.buildSchematicForm then C.buildSchematicForm(f) end end)
      guard("buildRankBar",       function() if C.buildRankBar       then C.buildRankBar(f)       end end)
      guard("buildCreateControls",function() if C.buildCreateControls then C.buildCreateControls(f) end end)
      guard("buildLinkButton",    function() if C.buildLinkButton     then C.buildLinkButton(f)    end end)
    end
  end)

  return f
end
C.BuildWindow = buildWindow

-- ============================================================================
-- Show / Hide / Refresh / Toggle.
-- ============================================================================
function C.Show()
  local f = C.frame or buildWindow()
  if not f then return end
  f:Show()
  applyWindowScale(f)
end

function C.Hide()
  local f = C.frame
  if CloseDropDownMenus then pcall(CloseDropDownMenus) end
  if GetCurrentKeyBoardFocus then
    local kf = GetCurrentKeyBoardFocus()
    if kf and kf.ClearFocus then pcall(kf.ClearFocus, kf) end
  end
  if f and f.RecipeList and f.RecipeList.SearchBox and f.RecipeList.SearchBox.ClearFocus then
    f.RecipeList.SearchBox:ClearFocus()
  end
  if f then f:Hide() end
end

function C.Toggle()
  local f = C.frame
  if f and f:IsShown() then
    C.Hide()
  else
    C.Show()
  end
end

function C.Refresh()
  guard("SetProfession",  function() if C.SetProfession  then C.SetProfession()  end end)
  guard("RefreshRecipes", function() if C.RefreshRecipes then C.RefreshRecipes() end end)
  guard("UpdateRank",     function() if C.UpdateRank     then C.UpdateRank()     end end)
end

local function refreshSelectedRecipeAvailability()
  local r = C._selected
  if not r then return end

  local numAvailable
  if r.isCraft and GetCraftInfo then
    numAvailable = select(4, GetCraftInfo(r.index))
  elseif GetTradeSkillInfo then
    numAvailable = select(3, GetTradeSkillInfo(r.index))
  end

  if numAvailable ~= nil then
    r.numAvailable = numAvailable or 0
  end

  if C.UpdateReagents then C.UpdateReagents(r) end
  if C.UpdateCreateButtons then C.UpdateCreateButtons(r) end
end

-- First-open on 3.3.5a can race the skill-line API population, leaving the header portrait/title
-- unresolved until a manual reopen. Run a couple of deferred refresh passes right after SHOW so
-- the same open cycle converges once the client has populated the trade/craft data.
local function refreshAfterOpen()
  local f = C.frame
  if not (f and f:IsShown()) then return end

  -- Bounded retry loop: initial opens can report UNKNOWN/blank profession for a short time.
  -- Keep re-running Refresh until header resolves or we hit the retry cap.
  C._openRefreshToken = (C._openRefreshToken or 0) + 1
  local token = C._openRefreshToken
  local tries = 0
  local maxTries = 50
  local baseTitle = _G.TRADE_SKILLS or "Professions"

  local function readLiveName()
    if GetTradeSkillLine then
      local ok, n = pcall(GetTradeSkillLine)
      if ok and type(n) == "string" and n ~= "" and n ~= "UNKNOWN" then return n end
    end
    if GetCraftDisplaySkillLine then
      local ok, n = pcall(GetCraftDisplaySkillLine)
      if ok and type(n) == "string" and n ~= "" and n ~= "UNKNOWN" then return n end
    end
    if GetCraftName then
      local ok, n = pcall(GetCraftName)
      if ok and type(n) == "string" and n ~= "" and n ~= "UNKNOWN" then return n end
    end
    return nil
  end

  local function step()
    if token ~= C._openRefreshToken then return end
    local frame = C.frame
    if not (frame and frame:IsShown()) then return end

    guard("Refresh.postOpen.loop", C.Refresh)

    local liveName = readLiveName()
    if liveName and C.SetProfession then
      guard("SetProfession.postOpen.live", function() C.SetProfession(liveName) end)
    end

    local title = frame._neTitle and frame._neTitle.GetText and frame._neTitle:GetText() or nil
    local resolved = liveName and title and title ~= "" and title ~= "UNKNOWN" and title ~= baseTitle
    if resolved then return end

    tries = tries + 1
    if tries >= maxTries then return end
    if C_Timer and C_Timer.After then
      C_Timer.After(0.10, step)
    end
  end

  step()
end

-- ============================================================================
-- Module-enabled guard. Mirrors the pattern used by every other NE module:
-- reads profile.newera.modules[MODULE].enabled; defaults to true when absent.
-- When disabled the event handlers become no-ops, Blizzard's default
-- TradeSkill/Craft frames are restored, and our window stays hidden.
-- ============================================================================
local function isModuleEnabled()
  local dragon = NE.dragon
  if not (dragon and dragon.db and dragon.db.profile) then return true end
  local ne = dragon.db.profile.newera
  if not (ne and type(ne.modules) == "table") then return true end
  local m = ne.modules[MODULE]
  if type(m) == "table" and m.enabled ~= nil then return m.enabled and true or false end
  return true
end

-- ============================================================================
-- Event wiring. A plain EventFrame (not the window itself) owns the game events
-- so the window frame doesn't carry event overhead when hidden.
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("CRAFT_SHOW")
eventFrame:RegisterEvent("CRAFT_CLOSE")
eventFrame:RegisterEvent("CRAFT_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE")   -- reagent counts change → refresh schematic
eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    guard("loadOpts", loadOpts)
    guard("buildWindow", buildWindow)
    -- Prewarm both the plain-bar fill texture and the art-based profession flipbook sheets on a
    -- SHOWN frame so their first visible use doesn't resolve as a dark placeholder.
    guard("prewarmBar", function()
      prewarmSkillBarAtlases()

      local pw = C._barPrewarm
      if not pw then return end

      local t = pw:CreateTexture(nil, "BACKGROUND")
      t:SetAllPoints(pw)
      t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
      t:SetAlpha(0.01)
      t:Show()
      C._genericBarPrewarm = t
    end)
    -- Register with the module system.
    guard("RegisterPanel", function()
      if NE.RegisterPanel then
        NE.RegisterPanel({
          id      = MODULE,
          title   = _G.TRADE_SKILLS or "Professions",
          desc    = "Retail-style crafting window for all professions.",
          frame   = C.frame,
          openFn  = C.Show,
          closeFn = C.Hide,
          -- defaultPoint must be nil or a plain anchor string accepted by DragonUI movers.lua.
          -- Passing a table causes strsplit to error on the table value.
          order   = 40,
        })
      end
    end)

  elseif event == "TRADE_SKILL_SHOW" then
    if not isModuleEnabled() then return end
    C.mode = "tradeskill"
    do
      local n = GetTradeSkillLine and GetTradeSkillLine()
      if n and n ~= "" and n ~= "UNKNOWN" then C._pendingProfessionName = n end
      local tex = GetTradeSkillTexture and GetTradeSkillTexture()
      if tex and tex ~= "" then C._pendingProfessionIcon = tex end
    end
    if C.filters then C.filters.search = "" end
    if C.frame and C.frame.RecipeList and C.frame.RecipeList.SearchBox then
      C.frame.RecipeList.SearchBox:SetText("")
    end
    -- Hide Blizzard's frame immediately (it was just shown by the LoD addon load).
    hideBlizzardTradeSkillFrames()
    -- Also schedule a deferred hide in case our handler runs before Blizzard's Show.
    if C_Timer and C_Timer.After then
      C_Timer.After(0, hideBlizzardTradeSkillFrames)
    end
    C.Show()
    refreshAfterOpen()

  elseif event == "CRAFT_SHOW" then
    if not isModuleEnabled() then return end
    C.mode = "craft"
    do
      local n = (GetCraftDisplaySkillLine and GetCraftDisplaySkillLine())
      if (not n or n == "" or n == "UNKNOWN") and GetCraftName then n = GetCraftName() end
      if n and n ~= "" and n ~= "UNKNOWN" then C._pendingProfessionName = n end
      -- Craft API has no direct texture getter in 3.3.5a; keep pending icon as-is.
    end
    if C.filters then C.filters.search = "" end
    if C.frame and C.frame.RecipeList and C.frame.RecipeList.SearchBox then
      C.frame.RecipeList.SearchBox:SetText("")
    end
    hideBlizzardTradeSkillFrames()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, hideBlizzardTradeSkillFrames)
    end
    C.Show()
    refreshAfterOpen()

  elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
    C._pendingProfessionName = nil
    C._pendingProfessionIcon = nil
    if isModuleEnabled() then C.Hide() end

  elseif event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
    if isModuleEnabled() and C.frame and C.frame:IsShown() then
      guard("Refresh.update", C.Refresh)
      -- New item/skill data arrived — re-fill the open recipe's reagents/details so any that were
      -- still uncached (missing) now resolve.
      guard("Refresh.update.selected", function()
        if C._selected then
          if C.UpdateReagents then C.UpdateReagents(C._selected) end
          if C.UpdateItemDetails then C.UpdateItemDetails(C._selected) end
        end
      end)
    end

  elseif event == "BAG_UPDATE" then
    if isModuleEnabled() and C.frame and C.frame:IsShown() then
      -- Bag changes can alter the live craftable count for every recipe, so refresh the list and
      -- then resync the selected row's controls against the updated API values.
      guard("RefreshRecipes.bag", function()
        if C.RefreshRecipes then C.RefreshRecipes() end
        refreshSelectedRecipeAvailability()
      end)
    end
  end
end)
