-- DragonUI_NewEra/modules/professions/Crafting.lua — right-panel schematic form, RankBar,
-- create controls, and per-profession theming for NE_ProfessionsCraftingFrame.
--
-- DOWNPORT: adapted from NewEra_ReferenceFolder/NewEra/Professions/Crafting.lua (the
-- SchematicForm, RankBar, buildCreateControls, SetProfession, UpdateRank, OnRecipeSelected,
-- UpdateReagents sections). Key 3.3.5a adaptations:
--
--   * CreateMaskTexture() may return nil → every mask is pcall-guarded; if nil the fill
--     is width-clamped directly (no alpha-mask reveal, still functionally correct).
--   * NE_ATLAS replaced by NE.tex.atlases (registered in Assets.lua).
--   * Flipbook driver: inline OnUpdate stepper (no NE.fx.Interpolate dependency).
--   * NumericInputSpinnerTemplate is NOT available in 3.3.5a → quantity input is a plain
--     EditBox with manual +/− buttons.
--   * Track Recipe checkbox and NE.recipetracker are feature-gated (no-op if absent).
--   * Favorite star for the output icon is feature-gated.
--
-- Exposes (consumed by Window.lua and RecipeList.lua):
--   C.buildSchematicForm(f)
--   C.buildRankBar(f)
--   C.buildCreateControls(f)
--   C.buildLinkButton(f)
--   C.SetProfession([name])
--   C.UpdateRank()
--   C.OnRecipeSelected(r)
--   C.UpdateReagents(r)
--   C.UpdateCreateButtons(r)
--   C.ResetOutput()

local NE = DragonUI_NewEra
NE.profcraft = NE.profcraft or {}
local C = NE.profcraft

-- ============================================================================
-- Geometry constants (published from Window.lua; re-read here for local use).
-- ============================================================================
local SCHEMATIC_W    = C.SCHEMATIC_W    or 655
local SCHEMATIC_H    = C.SCHEMATIC_H    or 553
local RANKBAR_W      = C.RANKBAR_W      or 453
local RANKBAR_H      = C.RANKBAR_H      or 18
local RANKBAR_TL     = C.RANKBAR_TL     or { 280, -40 }
local ATLAS_RECIPE_BG   = C.ATLAS_RECIPE_BG   or "professions-recipe-background"
local ATLAS_SKILL_BG    = C.ATLAS_SKILL_BG    or "professions-skillbar-bg"
local ATLAS_SKILL_FRAME = C.ATLAS_SKILL_FRAME or "professions-skillbar-frame"

-- Max reagent slots shown (retail shows up to 8 on WotLK; WoTLK recipes rarely exceed 6).
local MAX_REAGENT_SLOTS = 8
local REAGENT_ROW_H     = 48

-- ============================================================================
-- Per-profession theming map. key = lowercase substring of the profession name.
-- kit = atlas suffix for Professions-Recipe-Background-<kit>.
-- icon = modern DF FDID (resolved to the shipped local BLP via NE.tex.localFiles).
-- fill = themed flipbook atlas name (nil → DefaultBlue from the chrome sheet).
-- ============================================================================
local PROF_MAP = {
  alchemy        = { kit = "Alchemy",        icon = 4620669, fill = "skillbar_fill_flipbook_alchemy"        },
  blacksmith     = { kit = "Blacksmithing",  icon = 4620670, fill = "skillbar_fill_flipbook_blacksmithing"  },
  enchant        = { kit = "Enchanting",     icon = 4620672, fill = "skillbar_fill_flipbook_enchanting"     },
  engineer       = { kit = "Engineering",    icon = 4620673, fill = "skillbar_fill_flipbook_engineering"    },
  herbal         = { kit = "Herbalism",      icon = 4620675 },   -- no crafting window on gatherers; DefaultBlue
  leather        = { kit = "Leatherworking", icon = 4620678, fill = "skillbar_fill_flipbook_leatherworking" },
  mining         = { kit = "Mining",         icon = 4620679 },
  smelt          = { kit = "Mining",         icon = 4620679 },
  skin           = { kit = "Skinning",       icon = 4620680 },
  tailor         = { kit = "Tailoring",      icon = 4620681, fill = "skillbar_fill_flipbook_tailoring"      },
  cooking        = { kit = "Cooking",        icon = 4620671, fill = "skillbar_fill_flipbook_cooking"        },
  fishing        = { kit = "Fishing",        icon = 4620674 },
  inscription    = { kit = nil,              icon = "Interface\\Icons\\INV_Inscription_Tradeskill01" },
  inscript       = { kit = nil,              icon = "Interface\\Icons\\INV_Inscription_Tradeskill01" },
  jewel          = { kit = nil,              icon = 4620677, fill = "skillbar_fill_flipbook_blacksmithing" },
  jewelcraft     = { kit = nil,              icon = 4620677, fill = "skillbar_fill_flipbook_blacksmithing" },
  prospect       = { kit = nil,              icon = 4620677, fill = "skillbar_fill_flipbook_blacksmithing" },
  ["first aid"]  = { kit = nil,              icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
                     fill = "skillbar_fill_flipbook_skinning" },
}

local function infoFromName(name)
  if not name then return nil end
  local lname = name:lower()
  for key, v in pairs(PROF_MAP) do
    if lname:find(key, 1, true) then return v end
  end
  return nil
end

local function infoFromIconPath(texPath)
  if type(texPath) ~= "string" or texPath == "" then return nil end
  local p = texPath:lower()
  if p:find("alchemy", 1, true) then return PROF_MAP.alchemy end
  if p:find("blacksmith", 1, true) then return PROF_MAP.blacksmith end
  if p:find("enchant", 1, true) then return PROF_MAP.enchant end
  if p:find("engineer", 1, true) then return PROF_MAP.engineer end
  if p:find("herbal", 1, true) then return PROF_MAP.herbal end
  if p:find("leather", 1, true) then return PROF_MAP.leather end
  if p:find("mining", 1, true) then return PROF_MAP.mining end
  if p:find("skinning", 1, true) then return PROF_MAP.skin end
  if p:find("tailor", 1, true) then return PROF_MAP.tailor end
  if p:find("cooking", 1, true) then return PROF_MAP.cooking end
  if p:find("fishing", 1, true) then return PROF_MAP.fishing end
  if p:find("jewel", 1, true) then return PROF_MAP.jewel end
  return nil
end

-- ============================================================================
-- Flipbook driver — inline OnUpdate stepper (no NE.fx.Interpolate dependency).
-- Cycles through a sprite-sheet grid at 'duration' seconds per full loop.
-- ============================================================================
local flipDriver  = CreateFrame("Frame")
local flipActive  = {}

flipDriver:SetScript("OnUpdate", function(_, dt)
  for i = #flipActive, 1, -1 do
    local f = flipActive[i]
    f.elapsed = f.elapsed + dt
    while f.elapsed >= f.duration do f.elapsed = f.elapsed - f.duration end
    local idx = math.floor((f.elapsed / f.duration) * f.frames)
    if idx >= f.frames then idx = f.frames - 1 end
    local col = idx % f.cols
    local row = math.floor(idx / f.cols)
    f.tex:SetTexCoord(
      f.l + col * f.cellW,     f.l + (col + 1) * f.cellW,
      f.t + row * f.cellH,     f.t + (row + 1) * f.cellH)
  end
  if #flipActive == 0 then flipDriver:Hide() end
end)
flipDriver:Hide()

-- tc = { l, r, t, b }; rows/cols/frames describe the sprite grid; duration in seconds.
local function startFlip(tex, tc, rows, cols, frames, duration)
  for i = #flipActive, 1, -1 do if flipActive[i].tex == tex then table.remove(flipActive, i) end end
  tex:SetTexCoord(
    tc.l,                     tc.l + ((tc.r - tc.l) / cols),
    tc.t,                     tc.t + ((tc.b - tc.t) / rows))
  flipActive[#flipActive + 1] = {
    tex = tex, l = tc.l, t = tc.t, cols = cols, frames = frames,
    duration = duration, elapsed = 0,
    cellW = (tc.r - tc.l) / cols,
    cellH = (tc.b - tc.t) / rows,
  }
  flipDriver:Show()
end

local function stopFlip(tex)
  for i = #flipActive, 1, -1 do if flipActive[i].tex == tex then table.remove(flipActive, i) end end
  if #flipActive == 0 then flipDriver:Hide() end
end

-- Flipbook layout differs by atlas. The themed sheets are 2-column sprite grids.
-- Both DefaultBlue and art-based atlases have a black first cell; use the second cell as
-- the static fallback frame to avoid rendering black bars.
local function fillLayoutForAtlas(atlasName, entry)
  if atlasName == "skillbar_fill_flipbook_defaultblue" then
    return 1, 1, 1, 2
  end

  local cols = 2
  local rows = math.max(1, math.floor(((entry and entry.height or 34) / 34) + 0.5))
  return rows, cols, rows * cols, 2
end

-- ============================================================================
-- Helpers
-- ============================================================================
local function learnedRGB()
  local c = _G.PROFESSION_RECIPE_COLOR
  if c and c.GetRGB then return c:GetRGB() end
  return 0.96, 0.89, 0.58
end
local function unlearnedRGB()
  local c = _G.DISABLED_FONT_COLOR
  if c and c.GetRGB then return c:GetRGB() end
  return 0.5, 0.5, 0.5
end

local function applyItemQualityBorder(borderTex, glowTex, quality)
  if not borderTex then return end
  local r, g, b = 1, 1, 1
  if quality ~= nil and GetItemQualityColor then
    local qr, qg, qb = GetItemQualityColor(quality)
    if qr and qg and qb then r, g, b = qr, qg, qb end
  end
  borderTex:SetVertexColor(r, g, b)

  if glowTex then
    if quality and quality > 1 then
      glowTex:SetVertexColor(r, g, b)
      glowTex:Show()
    else
      glowTex:Hide()
    end
  end
end

local function isFav(name)
  if not name then return false end
  NE.db = NE.db or {}
  NE.db.profFavorites = NE.db.profFavorites or {}
  local function profKey()
    if C.mode == "craft" then
      if GetCraftDisplaySkillLine then local ok, v = pcall(GetCraftDisplaySkillLine); if ok and v and v ~= "" and v ~= "UNKNOWN" then return v end end
      if GetCraftName then local ok, v = pcall(GetCraftName); if ok and v and v ~= "" and v ~= "UNKNOWN" then return v end end
    else
      if GetTradeSkillLine then local ok, v = pcall(GetTradeSkillLine); if ok and v and v ~= "" and v ~= "UNKNOWN" then return v end end
    end
    return "?"
  end
  local key = profKey()
  NE.db.profFavorites[key] = NE.db.profFavorites[key] or {}
  return NE.db.profFavorites[key][name] == true
end

local function isAuctionatorLoaded()
  if NE and NE.IsAddOnLoaded then
    return NE.IsAddOnLoaded("Auctionator")
  end
  if _G.IsAddOnLoaded then
    local ok, loaded = pcall(_G.IsAddOnLoaded, "Auctionator")
    return ok and loaded and true or false
  end
  return false
end

local function getRecipeReagentNames(r)
  if not r then return {} end

  local out = {}
  local seen = {}
  local numReagents = 0
  if r.isCraft and GetCraftNumReagents then
    numReagents = GetCraftNumReagents(r.index) or 0
  elseif GetTradeSkillNumReagents then
    numReagents = GetTradeSkillNumReagents(r.index) or 0
  end

  for i = 1, numReagents do
    local reagentName
    if r.isCraft and GetCraftReagentInfo then
      reagentName = select(1, GetCraftReagentInfo(r.index, i))
    elseif GetTradeSkillReagentInfo then
      reagentName = select(1, GetTradeSkillReagentInfo(r.index, i))
    end
    if reagentName and reagentName ~= "" and not seen[reagentName] then
      seen[reagentName] = true
      out[#out + 1] = reagentName
    end
  end

  return out
end

local function buildAuctionatorSearchPayload(r)
  if not r then return nil, {} end

  local shoppingListName = r.name
  if (not r.isCraft) and GetTradeSkillItemLink and GetItemInfo then
    local link = GetTradeSkillItemLink(r.index)
    local itemName = link and GetItemInfo(link)
    if itemName and itemName ~= "" then shoppingListName = itemName end
  end

  if shoppingListName and shoppingListName ~= "" and string.find(shoppingListName, "Enchant ", 1, true) then
    shoppingListName = "Scroll of " .. shoppingListName
  end

  local items = {}
  local seen = {}

  local function addItem(name)
    if type(name) ~= "string" or name == "" then return end
    if name == "Crystal Vial" then return end
    if seen[name] then return end
    seen[name] = true
    items[#items + 1] = name
  end

  addItem(shoppingListName)

  local reagents = getRecipeReagentNames(r)
  for i = 1, #reagents do
    addItem(reagents[i])
  end

  return shoppingListName or "Unknown", items
end

local function startAuctionatorScan(r)
  local shoppingListName, items = buildAuctionatorSearchPayload(r)
  if type(items) ~= "table" or #items == 0 then return false, "NO_ITEMS" end

  if not (_G.AuctionFrame and _G.AuctionFrame.IsShown and _G.AuctionFrame:IsShown()) then
    return false, "AH_CLOSED"
  end

  local function okCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, ...)
    return ok and true or false
  end

  -- Match the legacy reference addon flow:
  -- Atr_SelectPane(BUY_TAB) -> Atr_SearchAH(shoppingListName, items) -> Atr_Shop_UpdateUI().
  if type(_G.Atr_SelectPane) == "function" and _G.BUY_TAB ~= nil then
    okCall(_G.Atr_SelectPane, _G.BUY_TAB)
  end

  if type(_G.Atr_SearchAH) == "function" then
    local ok = okCall(_G.Atr_SearchAH, shoppingListName, items)
    if ok then
      if type(_G.Atr_Shop_UpdateUI) == "function" then okCall(_G.Atr_Shop_UpdateUI) end
      return true
    end
  end

  local a = _G.Auctionator
  local api = a and a.API and a.API.v1
  if api then
    if okCall(api.MultiSearch, "DragonUI_NewEra", items) then return true end
    if okCall(api.StartMultiSearch, "DragonUI_NewEra", items) then return true end
    if okCall(api.SearchForTerms, "DragonUI_NewEra", items) then return true end
    if okCall(api.MultiSearch, api, "DragonUI_NewEra", items) then return true end
    if okCall(api.StartMultiSearch, api, "DragonUI_NewEra", items) then return true end
    if okCall(api.SearchForTerms, api, "DragonUI_NewEra", items) then return true end
  end

  local slash = _G.SlashCmdList and (_G.SlashCmdList.AUCTIONATOR or _G.SlashCmdList.ATR)
  if type(slash) == "function" then
    if okCall(slash, table.concat(items, ";")) then return true end
  end

  return false, "NO_API"
end

-- ============================================================================
-- currentProfName — reads the open profession name from Era's legacy API.
-- ============================================================================
local function currentProfTitleName()
  local baseTitle = _G.TRADE_SKILLS or "Professions"
  local titleWidgets = {
    _G.TradeSkillFrameTitleText,
    _G.CraftFrameTitleText,
  }

  for _, widget in ipairs(titleWidgets) do
    local text = widget and widget.GetText and widget:GetText()
    if type(text) == "string" and text ~= "" and text ~= "UNKNOWN" and text ~= baseTitle then
      return text
    end
  end

  return nil
end

local function currentProfName()
  local n
  if GetTradeSkillLine then local ok, v = pcall(GetTradeSkillLine); if ok then n = v end end
  if (not n or n == "" or n == "UNKNOWN") and GetCraftDisplaySkillLine then
    local ok, v = pcall(GetCraftDisplaySkillLine); if ok then n = v end
  end
  if (not n or n == "" or n == "UNKNOWN") and GetCraftName then
    local ok, v = pcall(GetCraftName); if ok then n = v end
  end
  if not n or n == "" or n == "UNKNOWN" then
    n = currentProfTitleName()
  end
  if n == "UNKNOWN" or n == "" then n = nil end
  return n
end

-- Read active profession rank in a 3.3.5a-safe way.
-- Skillet's working path is GetTradeSkillLine() => name, rank, maxRank; we keep that as the
-- primary source and add signature/mode fallbacks for mixed cores.
local function readProfessionRank()
  local profName, rank, maxRank

  if GetTradeSkillLine then
    local ok, a, b, c, d = pcall(GetTradeSkillLine)
    if ok and a then
      profName = a
      -- Layout A: name, rank, maxRank
      if type(b) == "number" and type(c) == "number" then
        rank, maxRank = b, c
      -- Layout B: name, type, rank, maxRank
      elseif type(c) == "number" and type(d) == "number" then
        rank, maxRank = c, d
      end
    end
  end

  if (not rank or not maxRank or maxRank <= 0) and GetCraftDisplaySkillLine then
    local ok, n, r, m = pcall(GetCraftDisplaySkillLine)
    if ok and type(r) == "number" and type(m) == "number" then
      profName, rank, maxRank = n, r, m
    end
  end

  return profName, rank, maxRank
end

-- ============================================================================
-- buildReagentSlot — one 48px-tall reagent row (icon + count + name).
-- ============================================================================
local function buildReagentSlot(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(SCHEMATIC_W - 80, REAGENT_ROW_H)
  b:EnableMouse(false)

  b.SlotBg = b:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(b.SlotBg, "professions-slot-bg", false)
  b.SlotBg:SetSize(43, 43); b.SlotBg:SetPoint("LEFT", b, "LEFT", 2, 0)

  b.Icon = b:CreateTexture(nil, "BORDER")
  b.Icon:SetPoint("TOPLEFT", b.SlotBg, "TOPLEFT", 3, -4)
  b.Icon:SetPoint("BOTTOMRIGHT", b.SlotBg, "BOTTOMRIGHT", -4, 3)
  b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b.IconBorder = b:CreateTexture(nil, "OVERLAY")
  NE.tex.SetAtlas(b.IconBorder, "professions-slot-frame", false)
  b.IconBorder:SetSize(40, 40); b.IconBorder:SetPoint("CENTER", b.SlotBg, "CENTER", 0, 0)

  b.QualityGlow = b:CreateTexture(nil, "OVERLAY")
  b.QualityGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.QualityGlow:SetBlendMode("ADD")
  b.QualityGlow:SetSize(74, 74)
  b.QualityGlow:SetPoint("CENTER", b.IconBorder, "CENTER", 0, 0)
  b.QualityGlow:SetAlpha(0.85)
  b.QualityGlow:Hide()

  b.Count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.Count:SetPoint("LEFT", b.SlotBg, "RIGHT", 8, 0)
  b.Count:SetWidth(40); b.Count:SetJustifyH("LEFT")

  b.Name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.Name:SetPoint("LEFT",  b.Count, "RIGHT",  2, 0)
  b.Name:SetPoint("RIGHT", b,       "RIGHT", -2, 0)
  b.Name:SetJustifyH("LEFT")

  -- Tooltip hit area: small button covering the icon only.
  local iconHit = CreateFrame("Button", nil, b)
  iconHit:SetAllPoints(b.SlotBg)
  iconHit:SetScript("OnLeave", function() if GameTooltip_Hide then GameTooltip_Hide() else GameTooltip:Hide() end end)
  b.IconHit = iconHit

  return b
end

-- ============================================================================
-- C.buildSchematicForm(f) — right-panel recipe detail area.
-- ============================================================================
function C.buildSchematicForm(f)
  local sf = CreateFrame("Frame", "NE_ProfessionsCraftingSchematic", f)
  sf:SetWidth(SCHEMATIC_W)
  sf:SetPoint("TOPLEFT", f.RecipeList, "TOPRIGHT", 2, 0)
  sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 5)
  f.SchematicForm = sf

  -- Themed parchment background (swapped per profession in C.SetProfession).
  local bg = sf:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(bg, ATLAS_RECIPE_BG, false)
  bg:SetAllPoints(sf)
  sf.Background = bg

  -- InsetFrame nineslice border.
  local ns = CreateFrame("Frame", nil, sf)
  ns:SetAllPoints(sf); ns:EnableMouse(false)
  if NE.nineslice and NE.nineslice.ApplyLayout then
    pcall(NE.nineslice.ApplyLayout, NE.nineslice, ns, "InsetFrameTemplate")
  end
  sf.NineSlice = ns

  -- Output item button (circular icon, TOPLEFT(28,-28), 47×47).
  local out = CreateFrame("Button", "NE_ProfessionsCraftingOutputIcon", sf)
  out:SetSize(47, 47); out:SetPoint("TOPLEFT", sf, "TOPLEFT", 28, -28); out:Hide()
  out.Icon = out:CreateTexture(nil, "ARTWORK")
  out.Icon:SetAllPoints(out)
  out.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  out.Icon:Hide()
  out.IconBorder = out:CreateTexture(nil, "OVERLAY")
  NE.tex.SetAtlas(out.IconBorder, "auctionhouse-itemicon-border-white", false)
  out.IconBorder:SetSize(68, 68); out.IconBorder:SetPoint("CENTER", out, "CENTER", 0, 0); out.IconBorder:Hide()
  out.QualityGlow = out:CreateTexture(nil, "OVERLAY")
  out.QualityGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  out.QualityGlow:SetBlendMode("ADD")
  out.QualityGlow:SetSize(92, 92)
  out.QualityGlow:SetPoint("CENTER", out.IconBorder, "CENTER", 0, 0)
  out.QualityGlow:SetAlpha(0.85)
  out.QualityGlow:Hide()
  out:SetScript("OnEnter", function()
    local rec = out._recipe; if not rec then return end
    GameTooltip:SetOwner(out, "ANCHOR_RIGHT")
    if rec.isCraft and GameTooltip.SetCraftSpell then GameTooltip:SetCraftSpell(rec.index)
    elseif GameTooltip.SetTradeSkillItem then GameTooltip:SetTradeSkillItem(rec.index) end
    GameTooltip:Show()
  end)
  out:SetScript("OnLeave", function() if GameTooltip_Hide then GameTooltip_Hide() else GameTooltip:Hide() end end)
  sf.OutputIcon = out

  -- Output item name. GameFontHighlightMed2 is retail-only; fall back to GameFontHighlight.
  local outName = sf:CreateFontString(nil, "ARTWORK",
    _G.GameFontHighlightMed2 and "GameFontHighlightMed2" or "GameFontHighlight")
  do local fn, _, fl = outName:GetFont(); if fn then outName:SetFont(fn, 20, fl) end end
  outName:SetPoint("LEFT", out, "RIGHT", 14, 17); outName:SetJustifyH("LEFT"); outName:SetJustifyV("TOP")
  sf.OutputText = outName

  -- Favourite star button (20×18, next to item name).
  local fav = CreateFrame("Button", "NE_ProfessionsCraftingFavorite", sf)
  fav:SetSize(20, 18); fav:SetPoint("LEFT", outName, "RIGHT", 4, 1)
  fav.tex = fav:CreateTexture(nil, "ARTWORK"); fav.tex:SetAllPoints(fav)
  fav.hl  = fav:CreateTexture(nil, "HIGHLIGHT"); fav.hl:SetAllPoints(fav); fav.hl:SetBlendMode("ADD")
  function fav:SetIsFavorite(on)
    local atlas = on and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off"
    NE.tex.SetAtlas(self.tex, atlas, false); NE.tex.SetAtlas(self.hl, atlas, false)
    self.hl:SetAlpha(on and 0.2 or 0.4)
  end
  fav:Hide()
  fav:SetScript("OnClick", function(self)
    if not C._selected then return end
    -- Toggle via the shared favStore in RecipeList.lua (same favStore logic).
    local name = C._selected.name
    NE.db = NE.db or {}; NE.db.profFavorites = NE.db.profFavorites or {}
    local function pk()
      if C.mode == "craft" then
        if GetCraftDisplaySkillLine then local ok, v = pcall(GetCraftDisplaySkillLine); if ok and v and v ~= "" and v ~= "UNKNOWN" then return v end end
      else if GetTradeSkillLine then local ok, v = pcall(GetTradeSkillLine); if ok and v and v ~= "" and v ~= "UNKNOWN" then return v end end end
      return "?"
    end
    local k = pk(); NE.db.profFavorites[k] = NE.db.profFavorites[k] or {}
    NE.db.profFavorites[k][name] = (not NE.db.profFavorites[k][name]) or nil
    self:SetIsFavorite(NE.db.profFavorites[k][name] == true)
    if C.RefreshRecipes then C.RefreshRecipes() end
  end)
  fav:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local on = C._selected and isFav(C._selected.name)
    local line = on and (BATTLE_PET_UNFAVORITE or "Remove Favorite") or (BATTLE_PET_FAVORITE or "Set Favorite")
    if GameTooltip_AddHighlightLine then GameTooltip_AddHighlightLine(GameTooltip, line)
    else GameTooltip:AddLine(line, 1, 1, 1) end
    GameTooltip:Show()
  end)
  fav:SetScript("OnLeave", function() if GameTooltip_Hide then GameTooltip_Hide() else GameTooltip:Hide() end end)
  sf.FavoriteButton = fav

  -- Empty-state hint (shown until a recipe is selected).
  local empty = sf:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  empty:SetPoint("CENTER", sf, "CENTER", 0, 40)
  empty:SetVertexColor(0.5, 0.5, 0.5)
  empty:SetText(_G.PROFESSIONS_RECIPE_SELECT_NO_RECIPE or "Select a recipe to craft")
  sf.EmptyText = empty

  -- -------------------------------------------------------------------------
  -- Reagents header + container.
  -- -------------------------------------------------------------------------
  local rh = sf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  rh:SetPoint("TOPLEFT", out, "BOTTOMLEFT", 0, -48)
  rh:SetText(_G.REAGENTS or "Reagents"); rh:Hide()
  sf.ReagentHeader = rh

  local rc = CreateFrame("Frame", nil, sf)
  rc:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -10)
  rc:SetSize(SCHEMATIC_W - 80, 240)
  sf.ReagentContainer = rc
  sf._reagentSlots = {}
end

-- ============================================================================
-- C.buildRankBar(f) — the 453×18 skill-progress bar at TOPLEFT(280,-40).
-- ============================================================================
function C.buildRankBar(f)
  local rb = CreateFrame("Frame", "NE_ProfessionsCraftingRankBar", f)
  rb:SetSize(RANKBAR_W, RANKBAR_H)
  rb:SetFrameStrata("HIGH")
  rb:SetPoint("TOPLEFT", f, "TOPLEFT", RANKBAR_TL[1], RANKBAR_TL[2])
  f.RankBar = rb

  local bgTex = rb:CreateTexture(nil, "ARTWORK", nil, 1)
  NE.tex.SetAtlas(bgTex, ATLAS_SKILL_BG, true)
  bgTex:SetPoint("TOPLEFT", rb, "TOPLEFT", 0, 0)
  rb.BarBg = bgTex

  -- Fill texture (DefaultBlue flipbook as placeholder; swapped per profession in UpdateRank).
  local baseFill = rb:CreateTexture(nil, "ARTWORK", nil, 1)
  baseFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  baseFill:SetVertexColor(0.20, 0.58, 0.96, 0.95)
  baseFill:SetSize(441, RANKBAR_H)
  baseFill:SetPoint("TOPLEFT", rb, "TOPLEFT", 5, -3)
  baseFill:SetTexCoord(0, 1, 0, 1)
  baseFill:Hide()
  rb.BaseFill = baseFill

  local fill = rb:CreateTexture(nil, "ARTWORK", nil, 2)
  NE.tex.SetAtlas(fill, "skillbar_fill_flipbook_defaultblue", false)
  fill:SetSize(441, RANKBAR_H)
  fill:SetPoint("TOPLEFT", rb, "TOPLEFT", 5, -3)
  fill:SetBlendMode("ADD")
  fill:SetAlpha(0.95)
  fill:Hide()
  rb.Fill    = fill
  rb.FillMaxW = 441

  -- 3.3.5a mask clipping is unreliable across clients/addon stacks; drive progress by
  -- explicit fill width so the bar ratio is always correct.
  rb.FillMask = nil

  -- Flare (additive spark at the leading edge of the fill).
  local flare = rb:CreateTexture(nil, "ARTWORK", nil, 2)
  flare:SetBlendMode("ADD"); flare:SetSize(53, 16)
  flare:SetPoint("RIGHT", fill, "RIGHT", 0, 0)
  flare:Hide(); rb.Flare = flare

  -- Frame/border overlay.
  local border = rb:CreateTexture(nil, "ARTWORK", nil, 3)
  NE.tex.SetAtlas(border, ATLAS_SKILL_FRAME, true)
  border:SetPoint("TOPLEFT", rb, "TOPLEFT", 0, 0)
  rb.Border = border

  -- Rank text (centered, on OVERLAY layer so it renders above the border).
  local rank = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  do
    local fn = rank:GetFont()
    if fn then rank:SetFont(fn, 12, "OUTLINE") end
  end
  rank:SetPoint("CENTER", rb, "CENTER", 0, -2); rank:SetText("")
  rb.RankText = rank
end

-- ============================================================================
-- C.buildCreateControls(f) — "Create" / "Create All" + quantity input.
-- ============================================================================
function C.buildCreateControls(f)
  -- "Create" button.
  local create = CreateFrame("Button", "NE_ProfessionsCraftingCreate", f, "UIPanelButtonTemplate")
  create:SetSize(82, 22)
  create:SetText(_G.TRADESKILL_CREATE or "Create")
  create:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -9, 16)
  create:Disable()
  f.CreateButton = create

  -- Quantity EditBox (+/− buttons around it; NumericInputSpinnerTemplate absent on 3.3.5a).
  local qtyBox = CreateFrame("EditBox", "NE_ProfessionsCraftingCount", f, "InputBoxTemplate")
  qtyBox:SetSize(36, 20); qtyBox:SetAutoFocus(false); qtyBox:SetNumeric(true)
  qtyBox:SetPoint("RIGHT", create, "LEFT", -34, 0)
  qtyBox:SetText("1"); qtyBox:SetMaxLetters(4)
  f.CreateMultipleInputBox = qtyBox
  -- Helper so the click handlers can read the numeric value safely.
  function qtyBox:GetValue()
    local n = tonumber(self:GetText()) or 1; return math.max(1, n)
  end

  -- [+] / [−] spinners.
  local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  minus:SetSize(20, 20); minus:SetText("-"); minus:SetPoint("RIGHT", qtyBox, "LEFT", -8, 0)
  minus:SetScript("OnClick", function()
    local v = qtyBox:GetValue(); if v > 1 then qtyBox:SetText(v - 1) end
  end)
  local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  plus:SetSize(20, 20); plus:SetText("+"); plus:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
  plus:SetScript("OnClick", function()
    local v = qtyBox:GetValue()
    local maxN = C._selected and C._selected.numAvailable or 999
    qtyBox:SetText(math.min(v + 1, maxN))
  end)

  -- "Create All" button.
  local createAll = CreateFrame("Button", "NE_ProfessionsCraftingCreateAll", f, "UIPanelButtonTemplate")
  createAll:SetSize(125, 22)
  createAll:SetText(_G.TRADESKILL_CREATE_ALL or "Create All")
  createAll:SetPoint("RIGHT", minus, "LEFT", -30, 0)
  createAll:Disable()
  f.CreateAllButton = createAll

  -- Optional Auctionator integration: scan AH for all reagents in the selected recipe.
  if isAuctionatorLoaded() then
    local scanAH = CreateFrame("Button", "NE_ProfessionsCraftingScanAH", f, "UIPanelButtonTemplate")
    scanAH:SetSize(100, 22)
    scanAH:SetText("Scan AH")
    scanAH:SetPoint("RIGHT", createAll, "LEFT", -8, 0)
    scanAH:Disable()
    scanAH:SetScript("OnClick", function(self)
      local r = C._selected
      if not r then return end
      local reagentNames = getRecipeReagentNames(r)
      if #reagentNames == 0 then
        self:Disable()
        return
      end
      local started, reason = startAuctionatorScan(r)
      if UIErrorsFrame and UIErrorsFrame.AddMessage then
        if started then
          UIErrorsFrame:AddMessage("Auctionator scan started for recipe reagents.", 0.2, 1.0, 0.2, 1)
        elseif reason == "AH_CLOSED" then
          UIErrorsFrame:AddMessage("Open the Auction House first to run Auctionator scans.", 1.0, 0.2, 0.2, 1)
        else
          UIErrorsFrame:AddMessage("Auctionator API not available for reagent scans.", 1.0, 0.2, 0.2, 1)
        end
      end
    end)
    scanAH:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:ClearLines()
      GameTooltip:AddLine("Scan AH", 1, 1, 1)
      GameTooltip:AddLine("Searches Auctionator for the selected recipe and its reagents.", 0.85, 0.85, 0.85, true)
      GameTooltip:AddLine("Requires the Auction House window to be open.", 0.85, 0.85, 0.85, true)
      GameTooltip:Show()
    end)
    scanAH:SetScript("OnLeave", function()
      if GameTooltip_Hide then GameTooltip_Hide() else GameTooltip:Hide() end
    end)
    f.ScanAHButton = scanAH
  else
    f.ScanAHButton = nil
  end

  -- Raise above SchematicForm so chrome doesn't clip the buttons.
  local lvl = (f.SchematicForm and f.SchematicForm:GetFrameLevel() or f:GetFrameLevel()) + 20
  create:SetFrameLevel(lvl); createAll:SetFrameLevel(lvl)
  qtyBox:SetFrameLevel(lvl); minus:SetFrameLevel(lvl); plus:SetFrameLevel(lvl)
  if f.ScanAHButton then f.ScanAHButton:SetFrameLevel(lvl) end

  -- Wire click actions.
  local function doCraft(count)
    local r = C._selected; if not r then return end
    if InCombatLockdown and InCombatLockdown() then return end
    count = count or 1
    if r.isCraft then if DoCraft then pcall(DoCraft, r.index) end
    elseif DoTradeSkill then pcall(DoTradeSkill, r.index, count) end
  end
  create:SetScript("OnClick",    function() doCraft(qtyBox:GetValue()) end)
  createAll:SetScript("OnClick", function() doCraft((C._selected and C._selected.numAvailable) or 1) end)
end

-- ============================================================================
-- C.buildLinkButton(f) — profession link-to-chat button (native Classic art).
-- ============================================================================
function C.buildLinkButton(f)
  if not f.RankBar then return end
  local link = CreateFrame("Button", "NE_ProfessionsCraftingLink", f)
  link:SetSize(30, 30)
  link:SetPoint("LEFT", f.RankBar, "RIGHT", 0, -2)
  link:SetNormalTexture("Interface\\Buttons\\UI-LinkProfession-Up")
  link:SetPushedTexture("Interface\\Buttons\\UI-LinkProfession-Down")
  link:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  link:SetScript("OnClick", function()
    if ChatEdit_GetActiveWindow then
      local editBox = ChatEdit_GetActiveWindow()
      if editBox then
        local link2 = GetTradeSkillListLink and GetTradeSkillListLink()
        if link2 then editBox:Insert(link2) end
      end
    end
  end)
  f.LinkButton = link
end

-- ============================================================================
-- C.SetProfession([name]) — apply portrait icon + title + themed background.
-- ============================================================================
function C.SetProfession(name)
  local f = C.frame; if not f then return end
  if (not name or name == "" or name == "UNKNOWN") and C._pendingProfessionName then
    name = C._pendingProfessionName
  end
  if not name or name == "" or name == "UNKNOWN" then
    local n = select(1, readProfessionRank())
    if n and n ~= "" and n ~= "UNKNOWN" then name = n end
  end
  if not name or name == "" or name == "UNKNOWN" then
    name = currentProfName()
  end
  if (not name or name == "" or name == "UNKNOWN") and C._professionName then
    name = C._professionName
  end
  if name == "" or name == "UNKNOWN" then name = nil end

  local iconPath = C._pendingProfessionIcon
  if (not iconPath or iconPath == "") and C.mode ~= "craft" and GetTradeSkillTexture then
    local ok, tex = pcall(GetTradeSkillTexture)
    if ok and tex and tex ~= "" then iconPath = tex end
  end

  local info = infoFromName(name)
  if not info then info = infoFromIconPath(iconPath) end

  -- Title.
  local title = name or (_G.TRADE_SKILLS or "Professions")
  if f._neTitle then f._neTitle:SetText(title) end
  if NE.panelchrome and NE.panelchrome.SetTitle then
    pcall(NE.panelchrome.SetTitle, f, title)
  end

  -- Portrait icon: resolve FDID → local BLP path (never pass raw FDID to SetTexture on 3.3.5a).
  if f.PortraitTex then
    local ic
    if info and info.icon then
      ic = info.icon
      if type(ic) == "number" then ic = (NE.tex.localFiles and NE.tex.localFiles[ic]) or ic end
    elseif iconPath and iconPath ~= "" then
      ic = iconPath
    end
    if ic then f.PortraitTex:SetTexture(ic)
    else f.PortraitTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    -- Re-apply the circular mask after every SetTexture — on 3.3.5a SetTexture clears the mask.
    if f.PortraitTex.SetMask then
      f.PortraitTex:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
  end

  -- Themed right-panel parchment.
  if f.SchematicForm and f.SchematicForm.Background then
    local atlas = (info and info.kit) and ("professions-recipe-background-" .. info.kit:lower())
                                      or  ATLAS_RECIPE_BG
    NE.tex.SetAtlas(f.SchematicForm.Background, atlas, false)
  end

  -- Fill + flare atlas for this profession.
  C._fillAtlas  = (info and info.fill) or "skillbar_fill_flipbook_defaultblue"
  C._flareAtlas = info and info.fill and info.fill:gsub("fill_flipbook", "flare") or nil

  -- Prewarm the rankbar fill atlas on profession switch. If a custom sheet fails to apply,
  -- fall back for this draw only; keep the desired atlas so UpdateRank can retry on the next
  -- refresh instead of pinning the session to DefaultBlue.
  if f.RankBar and f.RankBar.Fill and NE.tex and NE.tex.SetAtlas then
    local wanted = C._fillAtlas or "skillbar_fill_flipbook_defaultblue"
    local ok = NE.tex.SetAtlas(f.RankBar.Fill, wanted, false)
    if not ok then
      NE.tex.SetAtlas(f.RankBar.Fill, "skillbar_fill_flipbook_defaultblue", false)
    end
    -- Force UpdateRank to treat this as an atlas refresh next tick.
    f.RankBar._flipAtlas = nil
  end

  -- Clear selection only when the profession actually changes.
  if C._professionName ~= name then
    C._professionName = name
    C.ResetOutput()
  end

  C.UpdateRank()
end

-- ============================================================================
-- C.UpdateRank() — refresh the RankBar from the live profession skill.
-- ============================================================================
function C.UpdateRank()
  local rb = C.frame and C.frame.RankBar
  if not (rb and rb.Fill) then return end

  local profName, rank, maxRank = readProfessionRank()

  local defaultAtlas = "skillbar_fill_flipbook_defaultblue"
  local atlasName = C._fillAtlas or defaultAtlas
  local entry     = NE.tex and NE.tex.atlases and NE.tex.atlases[atlasName:lower()]
  if not entry then
    atlasName = defaultAtlas
    entry = NE.tex and NE.tex.atlases and NE.tex.atlases[defaultAtlas:lower()]
  end

  if rank and maxRank and maxRank > 0 then
    local frac = math.max(0, math.min(1, rank / maxRank))
    local maxW  = rb.FillMaxW or 441

    -- Animate the mask/width to reveal 'frac' of the fill bar.
    local profChanged = (rb._profKey ~= profName)
    rb._profKey = profName

    if profChanged then
      if rb._interp and rb._interp.driver then rb._interp.driver:SetScript("OnUpdate", nil) end
      rb._interp = nil
      local w = math.max(1, maxW * frac)
      rb.Fill:SetWidth(w)
      if rb.BaseFill then rb.BaseFill:SetWidth(w) end
      rb._ratio = frac
    elseif frac ~= (rb._ratio or 0) then
      -- Smooth width tween on ratio changes.
      if rb._interp and rb._interp.driver then rb._interp.driver:SetScript("OnUpdate", nil) end
      local from   = rb._ratio or 0
      local to     = frac
      local dur    = 0.5
      local t      = 0
      rb._interp   = {}
      local driver = CreateFrame("Frame")
      rb._interp.driver = driver
      driver:SetScript("OnUpdate", function(_, dt)
        t = t + dt
        if t >= dur then
          local w = math.max(1, maxW * to)
          rb.Fill:SetWidth(w)
          if rb.BaseFill then rb.BaseFill:SetWidth(w) end
          rb._ratio = to
          rb._interp = nil; driver:SetScript("OnUpdate", nil); driver:Hide()
        else
          local u = t / dur
          u = 1 - (1 - u) * (1 - u)
          local w = math.max(1, maxW * (from + (to - from) * u))
          rb.Fill:SetWidth(w)
          if rb.BaseFill then rb.BaseFill:SetWidth(w) end
        end
      end)
      driver:Show()
      rb._ratio = frac
    end

    rb.Fill:SetShown(frac > 0)
    rb.Fill:SetBlendMode(atlasName == defaultAtlas and "ADD" or "BLEND")
    rb.Fill:SetAlpha(atlasName == defaultAtlas and 0.95 or 1)
    if rb.BaseFill then rb.BaseFill:Hide() end

    -- Flipbook shimmer on the fill texture.
    if entry and frac > 0 then
      local atlasChanged = (rb._flipAtlas ~= atlasName)
      if atlasChanged then
        local applied = NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(rb.Fill, atlasName, false)
        if not applied and atlasName ~= defaultAtlas then
          atlasName = defaultAtlas
          entry = NE.tex and NE.tex.atlases and NE.tex.atlases[defaultAtlas:lower()]
          NE.tex.SetAtlas(rb.Fill, atlasName, false)
        end
      end
      rb.Fill:SetBlendMode(atlasName == defaultAtlas and "ADD" or "BLEND")
      rb.Fill:SetAlpha(atlasName == defaultAtlas and 0.95 or 1)
      if rb.BaseFill then rb.BaseFill:Hide() end

      local rows, cols, frames, staticFrame = fillLayoutForAtlas(atlasName, entry)
      local tc     = { l = entry.left, r = entry.right, t = entry.top, b = entry.bottom }
      if frames > 2 then
        if atlasChanged or not rb._flipping then
          startFlip(rb.Fill, tc, rows, cols, frames, 2.0); rb._flipping = true
        end
      else
        stopFlip(rb.Fill); rb._flipping = false
        -- Static: choose a deterministic frame (defaultblue uses frame 2 to avoid black cell).
        local idx = math.max(1, math.min(frames, staticFrame or 1)) - 1
        local cellW = (tc.r - tc.l) / cols
        local cellH = (tc.b - tc.t) / rows
        local col = idx % cols
        local row = math.floor(idx / cols)
        rb.Fill:SetTexCoord(
          tc.l + col * cellW,     tc.l + (col + 1) * cellW,
          tc.t + row * cellH,     tc.t + (row + 1) * cellH)
      end
      rb._flipAtlas = atlasName
    else
      stopFlip(rb.Fill); rb._flipping = false; rb._flipAtlas = nil
      if rb.BaseFill then rb.BaseFill:Hide() end
    end

    -- Flare at the leading edge.
    if rb.Flare then
      local fa = C._flareAtlas
      if fa and entry and frac > 0 and frac < 1 then
        NE.tex.SetAtlas(rb.Flare, fa, false); rb.Flare:SetSize(53, 16); rb.Flare:Show()
      else
        rb.Flare:Hide()
      end
    end

    if rb.RankText then rb.RankText:SetText(("%d / %d"):format(rank, maxRank)) end
  else
    -- No valid rank data.
    if rb._interp and rb._interp.driver then rb._interp.driver:SetScript("OnUpdate", nil) end
    rb._interp, rb._ratio, rb._profKey, rb._flipAtlas, rb._flipping = nil, nil, nil, nil, false
    rb.Fill:Hide(); stopFlip(rb.Fill)
    if rb.BaseFill then rb.BaseFill:Hide() end
    if rb.Flare then rb.Flare:Hide() end
    if rb.RankText then rb.RankText:SetText("") end
  end
end

-- ============================================================================
-- C.ResetOutput() — clear the SchematicForm to its empty state.
-- ============================================================================
function C.ResetOutput()
  local sf = C.frame and C.frame.SchematicForm
  if not sf then return end
  if sf.OutputIcon then sf.OutputIcon._recipe = nil; sf.OutputIcon:Hide() end
  if sf.OutputIcon and sf.OutputIcon.QualityGlow then sf.OutputIcon.QualityGlow:Hide() end
  if sf.OutputText then sf.OutputText:SetText("") end
  if sf.FavoriteButton then sf.FavoriteButton:Hide() end
  if sf.EmptyText then sf.EmptyText:Show() end
  if sf.ReagentHeader then sf.ReagentHeader:Hide() end
  if sf._reagentSlots then for _, s in ipairs(sf._reagentSlots) do s:Hide() end end
  C._selected = nil
  C.UpdateCreateButtons(nil)
  local rl = C.frame and C.frame.RecipeList
  if rl then rl._selectedKey = nil end
end

-- ============================================================================
-- C.OnRecipeSelected(r) — populate the SchematicForm with recipe r.
-- ============================================================================
function C.OnRecipeSelected(r)
  local sf = C.frame and C.frame.SchematicForm
  if not (sf and sf.OutputIcon) then return end
  if r.isCraft then
    if SelectCraft then pcall(SelectCraft, r.index) end
  else
    if SelectTradeSkill then pcall(SelectTradeSkill, r.index) end
  end
  sf.OutputIcon._recipe = r
  if sf.EmptyText then sf.EmptyText:Hide() end

  local function normalizeIconPath(v)
    if not v then return nil end
    if type(v) == "string" then
      return (v ~= "") and v or nil
    end
    if type(v) == "number" and NE and NE.tex and NE.tex.localFiles then
      return NE.tex.localFiles[v]
    end
    return nil
  end

  -- Output icon.
  local icon
  if (not r.isCraft) and GetTradeSkillItemInfo then
    local _, itemTex = GetTradeSkillItemInfo(r.index)
    icon = normalizeIconPath(itemTex)
  end
  if not icon then
    if r.isCraft and GetCraftIcon then icon = normalizeIconPath(GetCraftIcon(r.index))
    elseif GetTradeSkillIcon then icon = normalizeIconPath(GetTradeSkillIcon(r.index)) end
  end
  if not icon then
    local link = (r.isCraft and GetCraftItemLink and GetCraftItemLink(r.index))
              or (GetTradeSkillItemLink and GetTradeSkillItemLink(r.index))
    if link and GetItemInfo then
      icon = normalizeIconPath(select(10, GetItemInfo(link)))
    end
    if not icon and link and GetItemIcon then
      local itemID = tonumber((link:match("item:(%d+)")))
      if itemID then icon = normalizeIconPath(GetItemIcon(itemID)) end
    end
  end
  sf.OutputIcon.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  sf.OutputIcon.Icon:SetTexCoord(0.079, 0.921, 0.079, 0.921)
  sf.OutputIcon.Icon:Show(); sf.OutputIcon.IconBorder:Show(); sf.OutputIcon:Show()

  -- Quality-tint the border.
  local link = (r.isCraft and GetCraftItemLink and GetCraftItemLink(r.index))
            or (GetTradeSkillItemLink and GetTradeSkillItemLink(r.index))
  local q = link and select(3, GetItemInfo(link))
  applyItemQualityBorder(sf.OutputIcon.IconBorder, sf.OutputIcon.QualityGlow, q)

  -- Output name + optional "x N" suffix.
  local made = ""
  if not r.isCraft and GetTradeSkillNumMade then
    local mn, mx = GetTradeSkillNumMade(r.index)
    if mx and mx > 1 then made = (" [%d-%d]"):format(mn or 1, mx)
    elseif mn and mn > 1 then made = (" x%d"):format(mn) end
  end
  sf.OutputText:SetText((r.name or "") .. made)
  sf.OutputText:SetTextColor(1, 1, 1)

  -- Favourite star.
  if sf.FavoriteButton then
    sf.FavoriteButton:SetIsFavorite(isFav(r.name)); sf.FavoriteButton:Show()
  end

  C._selected = r
  C.UpdateReagents(r)
  C.UpdateCreateButtons(r)
end

-- ============================================================================
-- C.UpdateReagents(r) — populate the reagent slot pool.
-- ============================================================================
function C.UpdateReagents(r)
  local sf = C.frame and C.frame.SchematicForm
  if not sf then return end
  local rc = sf.ReagentContainer; if not rc then return end

  local numReagents = 0
  if r.isCraft and GetCraftNumReagents then
    numReagents = GetCraftNumReagents(r.index) or 0
  elseif GetTradeSkillNumReagents then
    numReagents = GetTradeSkillNumReagents(r.index) or 0
  end

  -- Ensure enough slot widgets exist.
  local slots = sf._reagentSlots
  for i = #slots + 1, numReagents do
    slots[i] = buildReagentSlot(rc)
    slots[i]:SetPoint("TOPLEFT", rc, "TOPLEFT", 0, -(i - 1) * REAGENT_ROW_H)
  end

  for i = 1, MAX_REAGENT_SLOTS do
    local s = slots[i]
    if not s then break end
    if i <= numReagents then
      local rName, rTex, rCount, rHave
      if r.isCraft and GetCraftReagentInfo then
        rName, rTex, rCount, rHave = GetCraftReagentInfo(r.index, i)
      elseif GetTradeSkillReagentInfo then
        rName, rTex, rCount, rHave = GetTradeSkillReagentInfo(r.index, i)
      end
      if rName then
        s.Icon:SetTexture(rTex or "Interface\\Icons\\INV_Misc_QuestionMark")
        local rLink
        if r.isCraft and GetCraftReagentItemLink then
          rLink = GetCraftReagentItemLink(r.index, i)
        elseif GetTradeSkillReagentItemLink then
          rLink = GetTradeSkillReagentItemLink(r.index, i)
        end
        local rq = rLink and GetItemInfo and select(3, GetItemInfo(rLink)) or nil
        applyItemQualityBorder(s.IconBorder, s.QualityGlow, rq)
        local enough = (rHave or 0) >= (rCount or 1)
        local countTxt = ("%d/%d"):format(rHave or 0, rCount or 1)
        s.Count:SetText(countTxt)
        s.Name:SetText(rName)
        local cr, cg, cb = enough and 1 or 0.5, enough and 1 or 0.5, enough and 1 or 0.5
        s.Count:SetVertexColor(cr, cg, cb); s.Name:SetVertexColor(cr, cg, cb)
        -- Tooltip.
        s.IconHit:SetScript("OnEnter", function()
          GameTooltip:SetOwner(s.IconHit, "ANCHOR_RIGHT")
          local shown = false
          if r.isCraft and GameTooltip.SetCraftReagentItem then
            shown = pcall(GameTooltip.SetCraftReagentItem, GameTooltip, r.index, i)
          elseif GameTooltip.SetTradeSkillReagentItem then
            shown = pcall(GameTooltip.SetTradeSkillReagentItem, GameTooltip, r.index, i)
          end

          if not shown then
            local link
            if r.isCraft and GetCraftReagentItemLink then
              local ok, v = pcall(GetCraftReagentItemLink, r.index, i)
              if ok then link = v end
            elseif GetTradeSkillReagentItemLink then
              local ok, v = pcall(GetTradeSkillReagentItemLink, r.index, i)
              if ok then link = v end
            end

            if link and GameTooltip.SetHyperlink then
              local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
              shown = ok and true or false
            end
          end

          if not shown then
            GameTooltip:ClearLines()
            GameTooltip:AddLine(rName or (_G.REAGENT or "Reagent"), 1, 1, 1)
            GameTooltip:AddLine(("%d / %d"):format(rHave or 0, rCount or 1), 0.8, 0.8, 0.8)
          end
          GameTooltip:Show()
        end)
        s:Show()
      else
        s:Hide()
      end
    else
      s:Hide()
    end
  end

  if numReagents > 0 then
    if sf.ReagentHeader then sf.ReagentHeader:Show() end
  else
    if sf.ReagentHeader then sf.ReagentHeader:Hide() end
  end
end

-- ============================================================================
-- C.UpdateCreateButtons(r) — enable/disable Create controls based on selection.
-- ============================================================================
function C.UpdateCreateButtons(r)
  local f = C.frame; if not f then return end

  if f.ScanAHButton then
    local reagentNames = getRecipeReagentNames(r)
    if r and #reagentNames > 0 then f.ScanAHButton:Enable() else f.ScanAHButton:Disable() end
  end

  if r and (r.numAvailable or 0) > 0 then
    if f.CreateButton    then f.CreateButton:Enable()    end
    if f.CreateAllButton then f.CreateAllButton:Enable() end
    if f.CreateAllButton then
      local n = r.numAvailable or 0
      f.CreateAllButton:SetText((_G.TRADESKILL_CREATE_ALL or "Create All") .. (n > 0 and (" [%d]"):format(n) or ""))
    end
  else
    if f.CreateButton    then f.CreateButton:Disable()    end
    if f.CreateAllButton then
      f.CreateAllButton:Disable()
      f.CreateAllButton:SetText(_G.TRADESKILL_CREATE_ALL or "Create All")
    end
  end
end
