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
--   C.UpdateItemDetails(r, link)
--   C.UpdateRequires(r)
--   C.UpdateReagents(r)
--   C.UpdateCreateButtons(r)
--   C.ResetOutput()

local NE = DragonUI_NewEra
local L = NE:GetLocale()
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

-- Item-details panel (right side). Repurposes retail's floating "Crafting Details" box —
-- whose mechanics (Concentration/Resourcefulness/Ingenuity/Multicraft/quality tiers) DON'T
-- exist on 3.3.5a — into a live tooltip of the item you're about to craft.
local DETAILS_W     = 250
-- The 3-slice pane's top/bottom caps are this tall (native 260×100, kept aspect). The panel must
-- be at least 2× this so the two caps meet edge-to-edge instead of overlapping (which double-darkens
-- the seam). Used both when building the pane and when clamping the min height.
local DETAILS_CAP_H = math.floor(100 * (DETAILS_W / 260) + 0.5)   -- 96 for DETAILS_W = 250
-- Reagent rows are narrowed to a left column so their names don't run under the details panel.
local REAGENT_COL_W = SCHEMATIC_W - DETAILS_W - 70

-- ============================================================================
-- PROF_MAP 
-- ============================================================================
local PROF_MAP = {
  ["Alchemy"]        = { kit = "Alchemy",        icon = 4620669, fill = "skillbar_fill_flipbook_alchemy"        },
  ["Blacksmithing"]  = { kit = "Blacksmithing",  icon = 4620670, fill = "skillbar_fill_flipbook_blacksmithing"  },
  ["Enchanting"]     = { kit = "Enchanting",     icon = 4620672, fill = "skillbar_fill_flipbook_enchanting"     },
  ["Engineering"]    = { kit = "Engineering",    icon = 4620673, fill = "skillbar_fill_flipbook_engineering"    },
  ["Herbalism"]      = { kit = "Herbalism",      icon = 4620675 },
  ["Leatherworking"] = { kit = "Leatherworking", icon = 4620678, fill = "skillbar_fill_flipbook_leatherworking" },
  ["Mining"]         = { kit = "Mining",         icon = 4620679 },
  ["Smelting"]       = { kit = "Mining",         icon = 4620679 },
  ["Skinning"]       = { kit = "Skinning",       icon = 4620680 },
  ["Tailoring"]      = { kit = "Tailoring",      icon = 4620681, fill = "skillbar_fill_flipbook_tailoring"      },
  ["Cooking"]        = { kit = "Cooking",        icon = 4620671, fill = "skillbar_fill_flipbook_cooking"        },
  ["Fishing"]        = { kit = "Fishing",        icon = 4620674 },
  ["Inscription"]    = { kit = "Inscription",   icon = 4620676, fill = "skillbar_fill_flipbook_inscription" },
  ["Jewelcrafting"]  = { kit = "Jewelcrafting", icon = 4620677, fill = "skillbar_fill_flipbook_jewelcrafting" },
  ["Prospecting"]    = { kit = "Jewelcrafting", icon = 4620677, fill = "skillbar_fill_flipbook_jewelcrafting" },
  ["First Aid"]      = { kit = nil,              icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
                         fill = "skillbar_fill_flipbook_skinning" },
}

local function infoFromName(name)
  if not name or name == "" then return nil end
  local lname = _G.strlower and _G.strlower(name) or name:lower()


  L = L or (NE.GetLocale and NE:GetLocale())

  for engKey, info in pairs(PROF_MAP) do
    local locName = (L and L[engKey]) or engKey
    local locLower = _G.strlower and _G.strlower(locName) or locName:lower()
    local engLower = _G.strlower and _G.strlower(engKey) or engKey:lower()

    if lname:find(locLower, 1, true) or lname:find(engLower, 1, true) then
      return info
    end
  end

  return nil
end

-- ============================================================================
-- Flipbook driver — inline OnUpdate stepper (no NE.fx.Interpolate dependency).
-- Cycles through a sprite-sheet grid at 'duration' seconds per full loop.
-- ============================================================================
local flipDriver  = CreateFrame("Frame")
local flipActive  = {}

-- The flare sprite lives on the SAME sheet file as each profession flipbook. The atlas crop for
-- the animated fill ends just before this block, so sample this fixed UV strip from that file.
local FLARE_U0 = 0.837402
local FLARE_U1 = 0.863281
local FLARE_H  = 0.016114

flipDriver:SetScript("OnUpdate", function(_, dt)
  for i = #flipActive, 1, -1 do
    local f = flipActive[i]
    f.elapsed = f.elapsed + dt
    while f.elapsed >= f.duration do f.elapsed = f.elapsed - f.duration end
    local first = f.first or 1
    local span  = f.frames - first
    local idx
    if span <= 0 then
      idx = first
    else
      idx = first + math.floor((f.elapsed / f.duration) * span)
      if idx >= f.frames then idx = f.frames - 1 end
    end
    local col = idx % f.cols
    local row = math.floor(idx / f.cols)

    local frac = f.tex._frac or 1
    local u0 = f.l + col * f.cellW
    local u1 = f.l + (col + 1) * f.cellW
    u1 = u0 + (u1 - u0) * frac

    local v0 = f.t + row * f.cellH
    local v1 = f.t + (row + 1) * f.cellH

    f.tex:SetTexCoord(u0, u1, v0, v1)
  end
  if #flipActive == 0 then flipDriver:Hide() end
end)
flipDriver:Hide()

-- tc = { l, r, t, b }; rows/cols/frames describe the sprite grid; duration in seconds.
-- first = index of the first NON-black frame to animate from (defaults to 1 — cell 0 is black).
local function startFlip(tex, tc, rows, cols, frames, duration, first)
  first = first or 1
  local cellW = (tc.r - tc.l) / cols
  local cellH = (tc.b - tc.t) / rows
  for i = #flipActive, 1, -1 do if flipActive[i].tex == tex then table.remove(flipActive, i) end end
  -- Seed the texcoord on the first non-black frame so we never flash cell 0.
  local col0 = first % cols
  local row0 = math.floor(first / cols)
  tex:SetTexCoord(
    tc.l + col0 * cellW,      tc.l + (col0 + 1) * cellW,
    tc.t + row0 * cellH,      tc.t + (row0 + 1) * cellH)
  flipActive[#flipActive + 1] = {
    tex = tex, l = tc.l, t = tc.t, cols = cols, frames = frames,
    duration = duration, elapsed = 0, first = first,
    cellW = cellW,
    cellH = cellH,
  }
  flipDriver:Show()
end

local function stopFlip(tex)
  for i = #flipActive, 1, -1 do if flipActive[i].tex == tex then table.remove(flipActive, i) end end
  if #flipActive == 0 then flipDriver:Hide() end
end

-- Flipbook layout differs by atlas. The themed sheets are 2-column sprite grids.
-- DefaultBlue needs only the first cell skipped, but some themed profession sheets carry more
-- than one black lead cell before the animated art begins. Start themed bars one frame deeper so
-- first-open/static renders don't land on an all-black tile.
local function fillLayoutForAtlas(atlasName, entry)
  if atlasName == "skillbar_fill_flipbook_defaultblue" then
    return 1, 1, 1, 2
  end

  local cols = 2
  local rows = math.max(1, math.floor(((entry and entry.height or 34) / 34) + 0.5))
  return rows, cols, rows * cols, 3
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

-- Rarity is shown by the glow RING only (matching the bags window); the metal slot frame stays
-- neutral. Poor/Common (quality <= 1) get no glow.
local function applyItemQualityBorder(_borderTex, glowTex, quality)
  if not glowTex then return end
  if quality and quality > 1 and GetItemQualityColor then
    local r, g, b = GetItemQualityColor(quality)
    if r then glowTex:SetVertexColor(r, g, b); glowTex:Show() else glowTex:Hide() end
  else
    glowTex:Hide()
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
  -- NOTE: BUY_TAB/SELL_TAB/MORE_TAB are LOCAL constants inside Auctionator's own file, never
  -- exposed as globals, so _G.BUY_TAB was always nil and this call never actually fired. Its
  -- source hardcodes BUY_TAB = 3; Atr_SelectPane just needs that numeric value.
  if type(_G.Atr_SelectPane) == "function" then
    okCall(_G.Atr_SelectPane, 3)
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
  b:SetSize(REAGENT_COL_W, REAGENT_ROW_H)
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

  -- Rarity glow ring — SAME texture + method as the bags window: UI-ActionButton-Border keeps its
  -- glow inset within a transparent margin, so it's anchored to the slot corners with a ~35% overhang
  -- (not a hardcoded oversize) so the glow reaches the slot edge cleanly.
  b.QualityGlow = b:CreateTexture(nil, "OVERLAY", nil, 7)
  b.QualityGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.QualityGlow:SetBlendMode("ADD")
  local gover = math.max(8, math.floor(43 * 0.35 + 0.5))
  b.QualityGlow:SetPoint("TOPLEFT",     b.SlotBg, "TOPLEFT",     -gover,  gover)
  b.QualityGlow:SetPoint("BOTTOMRIGHT", b.SlotBg, "BOTTOMRIGHT",  gover, -gover)
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
  -- Shift-click → link the reagent in chat; Ctrl-click → try it on (no-op for non-equippable).
  iconHit:RegisterForClicks("LeftButtonUp")
  iconHit:SetScript("OnClick", function()
    if b._link and HandleModifiedItemClick then HandleModifiedItemClick(b._link) end
  end)
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
    -- DOWNPORT: ApplyLayout is a plain function (container, layoutName) — no self arg.
    pcall(NE.nineslice.ApplyLayout, ns, "InsetFrameTemplate")
  end
  sf.NineSlice = ns

  -- Output item button (circular icon, TOPLEFT(28,-28), 47×47).
  local out = CreateFrame("Button", "NE_ProfessionsCraftingOutputIcon", sf)
  out:SetSize(47, 47); out:SetPoint("TOPLEFT", sf, "TOPLEFT", 28, -28); out:Hide()
  out.Icon = out:CreateTexture(nil, "ARTWORK")
  out.Icon:SetAllPoints(out)
  out.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  out.Icon:Hide()
  -- No rarity ring/glow on the crafted-item icon: its rarity reads from the (rarity-colored) name
  -- and the details panel. Keeping a colored circle here looked noisy.
  out:SetScript("OnEnter", function()
    local rec = out._recipe; if not rec then return end
    GameTooltip:SetOwner(out, "ANCHOR_RIGHT")
    if rec.isCraft and GameTooltip.SetCraftSpell then GameTooltip:SetCraftSpell(rec.index)
    elseif GameTooltip.SetTradeSkillItem then GameTooltip:SetTradeSkillItem(rec.index) end
    GameTooltip:Show()
  end)
  out:SetScript("OnLeave", function() if GameTooltip_Hide then GameTooltip_Hide() else GameTooltip:Hide() end end)
  -- Shift-click → link the crafted item in an open chat edit box; Ctrl-click → try it on in the
  -- dressing room. HandleModifiedItemClick (stock 3.3.5a) routes both from the item link.
  out:RegisterForClicks("LeftButtonUp")
  out:SetScript("OnClick", function()
    if out._link and HandleModifiedItemClick then HandleModifiedItemClick(out._link) end
  end)
  sf.OutputIcon = out

  -- Output item name. GameFontHighlightMed2 is retail-only; fall back to GameFontHighlight.
  local outName = sf:CreateFontString(nil, "ARTWORK",
    _G.GameFontHighlightMed2 and "GameFontHighlightMed2" or "GameFontHighlight")
  do local fn, _, fl = outName:GetFont(); if fn then outName:SetFont(fn, 20, fl) end end
  -- Offset chosen so the name + "Requires:" line below it straddle the icon's vertical center
  -- (rather than sitting up at the icon's top).
  outName:SetPoint("LEFT", out, "RIGHT", 14, 8); outName:SetJustifyH("LEFT"); outName:SetJustifyV("TOP")
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

  -- "Requires: <tools>" line (Anvil, Tool Bench, spell focus, …) — below the item NAME and
  -- indented to it (right of the icon), matching the stock/reference layout.
  local req = sf:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  req:SetPoint("TOPLEFT", outName, "BOTTOMLEFT", 0, -6)
  req:SetWidth(REAGENT_COL_W - 30)
  req:SetJustifyH("LEFT"); req:SetJustifyV("TOP")
  req:Hide()
  sf.RequiresText = req

  -- Empty-state hint (shown until a recipe is selected).
  local empty = sf:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  empty:SetPoint("CENTER", sf, "CENTER", 0, 40)
  empty:SetVertexColor(0.5, 0.5, 0.5)

  local emptyText = (L and L["Select a recipe to craft"]) or "Select a recipe to craft"

  empty:SetText(emptyText)
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
  rc:SetSize(REAGENT_COL_W, 240)
  sf.ReagentContainer = rc
  sf._reagentSlots = {}

  -- -------------------------------------------------------------------------
  -- Item-details panel (right side) — see DETAILS_W note at top of file.
  -- A dark titled box (like retail's "Crafting Details") holding a live, embedded
  -- item tooltip of the output. Hidden until a recipe is selected.
  -- -------------------------------------------------------------------------
  local dp = CreateFrame("Frame", "NE_ProfessionsCraftingDetails", sf)
  dp:SetWidth(DETAILS_W)
  -- Anchored by its vertical CENTER (right edge), so a small box sits centered on the Y axis and
  -- a taller box grows symmetrically up and down instead of dropping from a fixed top.
  dp:SetPoint("RIGHT", sf, "RIGHT", -16, 0)
  dp:SetHeight(220)   -- resized to fit content in C.UpdateItemDetails
  dp:Hide()
  sf.DetailsPanel = dp

  -- Background: the DF "detail/quality pane" 3-slice (charcoal fill, rounded corners, ornate
  -- top/bottom flourishes) — the same dark panel retail uses for its Crafting Details box. All
  -- three slices live on the already-shipped chrome sheet (4417031). Top/bottom are fixed caps
  -- sized to preserve the flourish aspect; the 1px middle stretches between them.
  local capH = DETAILS_CAP_H
  local paneTop = dp:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(paneTop, "professions-qualitypane-bg-top", false)
  paneTop:SetPoint("TOPLEFT",  dp, "TOPLEFT",  0, 0)
  paneTop:SetPoint("TOPRIGHT", dp, "TOPRIGHT", 0, 0)
  paneTop:SetHeight(capH)

  local paneBot = dp:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(paneBot, "professions-qualitypane-bg-bottom", false)
  paneBot:SetPoint("BOTTOMLEFT",  dp, "BOTTOMLEFT",  0, 0)
  paneBot:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", 0, 0)
  paneBot:SetHeight(capH)

  local paneMid = dp:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(paneMid, "professions-qualitypane-bg-middle", false)
  paneMid:SetPoint("TOPLEFT",     paneTop, "BOTTOMLEFT", 0, 0)
  paneMid:SetPoint("BOTTOMRIGHT", paneBot, "TOPRIGHT",   0, 0)
  dp.PaneTop, dp.PaneMid, dp.PaneBottom = paneTop, paneMid, paneBot

  -- Output item icon, centered near the top. An empty row's worth of gap sits above it so the
  -- icon isn't jammed against the top flourish.
  local dicon = dp:CreateTexture(nil, "ARTWORK")
  dicon:SetSize(38, 38)
  dicon:SetPoint("TOP", dp, "TOP", 0, -34)
  dicon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  dicon:Hide()
  dp.Icon = dicon

  local diconb = dp:CreateTexture(nil, "OVERLAY")
  NE.tex.SetAtlas(diconb, "professions-slot-frame", false)
  diconb:SetSize(46, 46)
  diconb:SetPoint("CENTER", dicon, "CENTER", 0, 0)
  diconb:Hide()
  dp.IconBorder = diconb

  -- Wrapped text lines are scanned from the item/recipe tooltip and pooled here.
  dp.Lines = {}
end

-- ============================================================================
-- C.buildRankBar(f) — the 453×18 skill-progress bar at TOPLEFT(280,-40).
-- ============================================================================
function C.buildRankBar(f)
  local rb = CreateFrame("Frame", "NE_ProfessionsCraftingRankBar", f)
  rb:SetSize(RANKBAR_W, 29)
  rb:SetFrameStrata("HIGH")
  rb:SetPoint("TOPLEFT", f, "TOPLEFT", RANKBAR_TL[1], RANKBAR_TL[2])
  f.RankBar = rb

  
  local bgTex = rb:CreateTexture(nil, "BACKGROUND", nil, -8)
  NE.tex.SetAtlas(bgTex, ATLAS_SKILL_BG, true)
  bgTex:SetPoint("TOPLEFT", rb, "TOPLEFT", 0, 0)
  bgTex:Hide()
  rb.BarBg = bgTex

  
  local baseFill = rb:CreateTexture(nil, "ARTWORK", nil, 1)
  baseFill:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
  baseFill:SetVertexColor(0.15, 0.85, 0.25, 1)
  baseFill:SetSize(441, 15)
  baseFill:SetPoint("TOPLEFT", rb, "TOPLEFT", 5, -7)
  baseFill:SetTexCoord(0, 1, 0, 1)
  baseFill:Hide()
  rb.BaseFill = baseFill

 
  local fill = rb:CreateTexture(nil, "ARTWORK", nil, 2)
  NE.tex.SetAtlas(fill, "skillbar_fill_flipbook_defaultblue", false)
  fill:SetSize(441, 15)
  fill:SetPoint("TOPLEFT", rb, "TOPLEFT", 5, -7)
  fill:SetBlendMode("ADD")
  fill:SetAlpha(0.95)
  fill:Hide()
  rb.Fill    = fill
  rb.FillMaxW = 441

 
  local border = rb:CreateTexture(nil, "OVERLAY", nil, 1)
  NE.tex.SetAtlas(border, ATLAS_SKILL_FRAME, true)
  border:SetPoint("TOPLEFT", rb, "TOPLEFT", 0, 0)
  border:Hide()
  rb.Border = border

  
  local flare = rb:CreateTexture(nil, "OVERLAY", nil, 2)
  flare:SetBlendMode("ADD"); flare:SetSize(53, 16)
  flare:SetPoint("RIGHT", fill, "RIGHT", 0, 0)
  flare:Hide(); rb.Flare = flare

  
  local rank = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  rank:SetDrawLayer("OVERLAY", 7)
  do
    local fn = rank:GetFont()
    if fn then rank:SetFont(fn, 12, "OUTLINE") end
  end
  rank:SetPoint("CENTER", rb, "CENTER", 0, 3)
  rank:SetText("")
  rb.RankText = rank
end

-- ============================================================================
-- C.buildCreateControls(f) — "Create" / "Create All" + quantity input.
-- ============================================================================
function C.buildCreateControls(f)
  -- "Create" button.
  local create = CreateFrame("Button", "NE_ProfessionsCraftingCreate", f, "UIPanelButtonTemplate")
  create:SetSize(82, 22)
  create:SetText((L and L["Create"]) or _G.TRADESKILL_CREATE or "Create")
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
  createAll:SetText((L and L["Create All"]) or _G.TRADESKILL_CREATE_ALL or "Create All")
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
-- C.buildLinkButton(f) — profession link-to-chat button.
-- DOWNPORT: the Classic-source art (UI-LinkProfession-Up/Down) doesn't render on 3.3.5a. Use the
-- SAME chat glyph the stock WotLK tradeskill link button uses — UI-ChatIcon-Chat (a single speech
-- bubble). (UI-ChatConversationIcon, the Cata+ double-bubble, looked wrong.) Up/Down states +
-- the classic mouse-over highlight.
-- ============================================================================
function C.buildLinkButton(f)
  if not f.RankBar then return end
  local link = CreateFrame("Button", "NE_ProfessionsCraftingLink", f)
  link:SetSize(30, 30)
  link:SetPoint("LEFT", f.RankBar, "RIGHT", 4, -2)
  link:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
  link:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
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
  if not (C.opts and C.opts.genericBar) then
    local wanted = C._fillAtlas or "skillbar_fill_flipbook_defaultblue"
    local ok = NE.tex.SetAtlas(f.RankBar.Fill, wanted, false)
    if not ok then
      NE.tex.SetAtlas(f.RankBar.Fill, "skillbar_fill_flipbook_defaultblue", false)
    end
    -- Force UpdateRank to treat this as an atlas refresh next tick.
    f.RankBar._flipAtlas = nil
  end
  end

  -- Clear selection only when the profession actually changes.
  if C._professionName ~= name then
    C._professionName = name
    C.ResetOutput()
  end

  C.UpdateRank()
end

-- ============================================================================
-- C.UpdateRank()
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
    local w     = math.max(1, maxW * frac)

    rb._profKey = profName


    if C.opts and C.opts.genericBar then
      stopFlip(rb.Fill)
      rb._flipping = false
      rb._flipAtlas = nil
      rb.Fill:Hide()
      if rb.Flare then rb.Flare:Hide() end

      if rb.BarBg then
        rb.BarBg:SetDrawLayer("BACKGROUND", -8)
        NE.tex.SetAtlas(rb.BarBg, ATLAS_SKILL_BG, true)
        rb.BarBg:SetVertexColor(0.20, 0.20, 0.20)
        rb.BarBg:Show()
      end

      if rb.Border then
        rb.Border:SetDrawLayer("OVERLAY", 1)
        NE.tex.SetAtlas(rb.Border, ATLAS_SKILL_FRAME, true)
        rb.Border:SetVertexColor(1, 1, 1)
        rb.Border:Show()
      end

      if rb.BaseFill then
        rb.BaseFill:SetDrawLayer("ARTWORK", 1)
        rb.BaseFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        rb.BaseFill:SetVertexColor(0.12, 0.75, 0.22, 1)
        rb.BaseFill:SetTexCoord(0, 1, 0, 1)
        
        rb.BaseFill:ClearAllPoints()
        rb.BaseFill:SetPoint("TOPLEFT", rb, "TOPLEFT", 6, -3) 
        rb.BaseFill:SetSize(w, 18)                             
        rb.BaseFill:SetShown(frac > 0)
      end

      if rb.RankText then rb.RankText:SetText(("%d / %d"):format(rank, maxRank)) end
      rb._ratio = frac
      return
    end


    if rb.BaseFill then rb.BaseFill:Hide() end

    if rb.BarBg then
      rb.BarBg:SetDrawLayer("BACKGROUND", -8)
      NE.tex.SetAtlas(rb.BarBg, ATLAS_SKILL_BG, true)
      rb.BarBg:SetVertexColor(1, 1, 1)
      rb.BarBg:Show()
    end
    if rb.Border then
      rb.Border:SetDrawLayer("OVERLAY", 1)
      NE.tex.SetAtlas(rb.Border, ATLAS_SKILL_FRAME, true)
      rb.Border:SetVertexColor(1, 1, 1)
      rb.Border:Show()
    end

    rb.Fill:ClearAllPoints()
    rb.Fill:SetPoint("TOPLEFT", rb, "TOPLEFT", 5, -3) 
    rb.Fill:SetHeight(18)                             
    rb.Fill:SetWidth(w)
    rb.Fill._frac = frac
    rb.Fill:SetShown(frac > 0)
    rb._ratio = frac

    local atlasChanged = (rb._flipAtlas ~= atlasName)
    NE.tex.SetAtlas(rb.Fill, atlasName, false)
    rb.Fill:SetBlendMode(atlasName == defaultAtlas and "ADD" or "BLEND")
    rb.Fill:SetVertexColor(1, 1, 1)
    rb.Fill:SetAlpha(atlasName == defaultAtlas and 0.95 or 1)

    if entry and frac > 0 then
      local rows, cols, frames, staticFrame = fillLayoutForAtlas(atlasName, entry)
      local tc = { l = entry.left, r = entry.right, t = entry.top, b = entry.bottom }

      if frames > 2 then
        if atlasChanged or not rb._flipping then
          startFlip(rb.Fill, tc, rows, cols, frames, 2.0, staticFrame)
          rb._flipping = true
        end
      else
        stopFlip(rb.Fill)
        rb._flipping = false
        local idx = math.max(1, math.min(frames, staticFrame or 1)) - 1
        local cellW = (tc.r - tc.l) / cols
        local cellH = (tc.b - tc.t) / rows
        local col = idx % cols
        local row = math.floor(idx / cols)

        local u0 = tc.l + col * cellW
        local u1 = u0 + cellW * frac
        local v0 = tc.t + row * cellH
        local v1 = tc.t + (row + 1) * cellH

        rb.Fill:SetTexCoord(u0, u1, v0, v1)
      end
      rb._flipAtlas = atlasName
    else
      stopFlip(rb.Fill)
      rb._flipping = false
      rb._flipAtlas = nil
    end

    if rb.Flare then
      local themed = (atlasName ~= defaultAtlas)
      if themed and entry and frac > 0 and frac < 1 then
        local srcFile = entry.file and (NE.tex and NE.tex.localFiles and NE.tex.localFiles[entry.file]) or entry.file
        rb.Flare:SetTexture(srcFile)
        rb.Flare:SetTexCoord(FLARE_U0, FLARE_U1, entry.top, math.min(1, entry.top + FLARE_H))
        rb.Flare:SetSize(53, 16)
        rb.Flare:Show()
      else
        rb.Flare:Hide()
      end
    end

    if rb.RankText then rb.RankText:SetText(("%d / %d"):format(rank, maxRank)) end
  else
    stopFlip(rb.Fill)
    rb._ratio, rb._profKey, rb._flipAtlas, rb._flipping = nil, nil, nil, false
    rb.Fill:Hide()
    if rb.BaseFill then rb.BaseFill:Hide() end
    if rb.BarBg then rb.BarBg:Hide() end
    if rb.Border then rb.Border:Hide() end
    if rb.Flare then rb.Flare:Hide() end
    if rb.GenBg then rb.GenBg:Hide() end
    if rb.GenBorder then for _, e in ipairs(rb.GenBorder) do e:Hide() end end
    if rb.RankText then rb.RankText:SetText("") end
  end
end

-- ============================================================================
-- C.ResetOutput() — clear the SchematicForm to its empty state.
-- ============================================================================
function C.ResetOutput()
  local sf = C.frame and C.frame.SchematicForm
  if not sf then return end
  if sf.OutputIcon then sf.OutputIcon._recipe = nil; sf.OutputIcon._link = nil; sf.OutputIcon:Hide() end
  if sf.OutputText then sf.OutputText:SetText("") end
  if sf.RequiresText then sf.RequiresText:Hide() end
  if sf.FavoriteButton then sf.FavoriteButton:Hide() end
  if sf.EmptyText then sf.EmptyText:Show() end
  if sf.ReagentHeader then sf.ReagentHeader:Hide() end
  if sf._reagentSlots then for _, s in ipairs(sf._reagentSlots) do s:Hide() end end
  if sf.DetailsPanel then sf.DetailsPanel:Hide() end
  C._selected = nil
  C.UpdateCreateButtons(nil)
  local rl = C.frame and C.frame.RecipeList
  if rl then rl._selectedKey = nil end
end

-- ============================================================================
-- C.UpdateItemDetails(r, link) — fill the right-side details panel with a live
-- tooltip of the output item (or the recipe/enchant tooltip when there's no item).
-- ============================================================================
-- Content geometry (kept as locals so the fit math and the layout can't drift apart).
local DETAILS_PAD      = 16   -- left/right text inset
local DETAILS_LINE_GAP = 3    -- gap between wrapped lines
local DETAILS_TOP      = 80   -- dp-top → first text line (top gap + icon + gap, no title)
local DETAILS_BOTTOM   = 26   -- clearance for the bottom flourish
-- At least 2× the cap height (+ a sliver of middle) so the top/bottom caps never overlap → no dark seam.
local DETAILS_MIN_H    = DETAILS_CAP_H * 2 + 4
-- Top/bottom breathing room when the box is at its tallest. The panel is CENTER-anchored, so a
-- maxed box gets this same gap above (below the item name) and below (above the Create buttons).
local DETAILS_MARGIN   = 44

-- Resolve the crafted item's icon (crafted-item icon → recipe icon → item-link icon → item id).
-- Shared so the details panel and the output icon always agree — and so callers that don't pass an
-- icon (e.g. the TRADE_SKILL_UPDATE refresh) still get one instead of blanking the details icon.
function C.ResolveOutputIcon(r)
  if not r then return nil end
  local function norm(v)
    if not v then return nil end
    if type(v) == "string" then return (v ~= "") and v or nil end
    if type(v) == "number" and NE and NE.tex and NE.tex.localFiles then return NE.tex.localFiles[v] end
    return nil
  end
  local icon
  if (not r.isCraft) and GetTradeSkillItemInfo then
    local _, itemTex = GetTradeSkillItemInfo(r.index); icon = norm(itemTex)
  end
  if not icon then
    if r.isCraft and GetCraftIcon then icon = norm(GetCraftIcon(r.index))
    elseif GetTradeSkillIcon then icon = norm(GetTradeSkillIcon(r.index)) end
  end
  if not icon then
    local link = (r.isCraft and GetCraftItemLink and GetCraftItemLink(r.index))
              or (GetTradeSkillItemLink and GetTradeSkillItemLink(r.index))
    if link and GetItemInfo then icon = norm(select(10, GetItemInfo(link))) end
    if not icon and link and GetItemIcon then
      local itemID = tonumber((link:match("item:(%d+)")))
      if itemID then icon = norm(GetItemIcon(itemID)) end
    end
  end
  return icon
end

function C.UpdateItemDetails(r, link, iconTex)
  local sf = C.frame and C.frame.SchematicForm
  local dp = sf and sf.DetailsPanel
  if not dp then return end

  -- Resolve the icon ourselves when the caller didn't pass one, so the details icon never blanks.
  iconTex = iconTex or C.ResolveOutputIcon(r)

  -- Scan the item/recipe tooltip into our OWN wrapped, rarity-colored text block. A live
  -- embedded GameTooltip auto-sizes to its widest line and can't wrap, so its text spilled
  -- out of the panel; scanning lets us clamp width (wrap) and size the panel to the content.
  local scan = C._scanTip
  if not scan then
    scan = CreateFrame("GameTooltip", "NE_ProfItemDetailsScan", UIParent, "GameTooltipTemplate")
    C._scanTip = scan
  end
  scan:SetOwner(UIParent, "ANCHOR_NONE")
  scan:ClearLines()
  local ok = false
  if link then ok = pcall(scan.SetHyperlink, scan, link) end
  if not ok and r then
    if r.isCraft and scan.SetCraftSpell then ok = pcall(scan.SetCraftSpell, scan, r.index)
    elseif scan.SetTradeSkillItem then ok = pcall(scan.SetTradeSkillItem, scan, r.index) end
  end
  if not ok then dp:Hide(); return end

  dp:Show()   -- shown before measuring so GetStringHeight() is reliable

  -- Centered output icon.
  if iconTex then
    dp.Icon:SetTexture(iconTex); dp.Icon:Show(); dp.IconBorder:Show()
  else
    dp.Icon:Hide(); dp.IconBorder:Hide()
  end

  -- Rarity color for the name line (item quality; enchants have no item → keep tooltip color).
  local nameR, nameG, nameB
  if link and GetItemInfo and GetItemQualityColor then
    local q = select(3, GetItemInfo(link))
    if q then nameR, nameG, nameB = GetItemQualityColor(q) end
  end

  local interior = DETAILS_W - DETAILS_PAD * 2
  dp.Lines = dp.Lines or {}
  local numLines = scan:NumLines()
  local prev, sumH, count = nil, 0, 0

  for i = 1, numLines do
    local src  = _G["NE_ProfItemDetailsScanTextLeft" .. i]
    local text = src and src:GetText()
    if text and text ~= "" then
      count = count + 1
      local fs = dp.Lines[i]
      if not fs then
        fs = dp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetJustifyH("LEFT")
        dp.Lines[i] = fs
      end
      fs:SetWidth(interior)          -- fixed width → words wrap, text stays inside the panel
      fs:SetText(text)
      if i == 1 and nameR then
        fs:SetTextColor(nameR, nameG, nameB)   -- rarity-colored item name
      else
        local cr, cg, cb = src:GetTextColor()
        fs:SetTextColor(cr or 1, cg or 1, cb or 1)
      end
      fs:ClearAllPoints()
      if not prev then
        fs:SetPoint("TOPLEFT", dp, "TOPLEFT", DETAILS_PAD, -DETAILS_TOP)
      else
        fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -DETAILS_LINE_GAP)
      end
      fs:Show()
      sumH = sumH + (fs:GetStringHeight() or 12)
      prev = fs
    elseif dp.Lines[i] then
      dp.Lines[i]:Hide()
    end
  end
  for i = numLines + 1, #dp.Lines do
    if dp.Lines[i] then dp.Lines[i]:Hide() end
  end

  -- Size the panel to fit: top block + all wrapped lines + inter-line gaps + bottom flourish.
  -- Cap is derived from the schematic form's height so a tall box fills from just under the item
  -- name down to just above the Create buttons, with equal margins (it's center-anchored).
  local avail = (sf.GetHeight and sf:GetHeight()) or 0
  if avail < DETAILS_MIN_H then avail = 560 end          -- fallback before first layout pass
  local maxH = math.max(DETAILS_MIN_H, avail - DETAILS_MARGIN * 2)
  local h = DETAILS_TOP + sumH + DETAILS_LINE_GAP * math.max(0, count - 1) + DETAILS_BOTTOM
  if h < DETAILS_MIN_H then h = DETAILS_MIN_H elseif h > maxH then h = maxH end
  dp:SetHeight(h)
end

-- ============================================================================
-- C.UpdateRequires(r) — "Requires: <tools>" line (Anvil, Tool Bench, spell focus, …).
-- GetTradeSkillTools' return shape varies (a tool string, or tool/have pairs), so parse
-- defensively: strings are tool names, a following boolean is that tool's have-flag.
-- ============================================================================
function C.UpdateRequires(r)
  local sf  = C.frame and C.frame.SchematicForm
  local req = sf and sf.RequiresText
  if not req then return end

  local names, anyMissing = {}, false
  if r and not r.isCraft and GetTradeSkillTools then
    local rets = { GetTradeSkillTools(r.index) }
    local i = 1
    while i <= #rets do
      local v = rets[i]
      if type(v) == "string" and v ~= "" then
        names[#names + 1] = v
        if type(rets[i + 1]) == "boolean" then
          if not rets[i + 1] then anyMissing = true end
          i = i + 1
        end
      end
      i = i + 1
    end
  elseif r and r.isCraft and GetCraftSpellFocus then
    local ok, focus = pcall(GetCraftSpellFocus, r.index)
    if ok and type(focus) == "string" and focus ~= "" then names[#names + 1] = focus end
  end

  if #names > 0 then
    req:SetText("Requires: " .. table.concat(names, ", "))
    if anyMissing then req:SetTextColor(1, 0.3, 0.3) else req:SetTextColor(0.82, 0.82, 0.82) end
    req:Show()
  else
    req:Hide()
  end
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

  -- Output icon (shared resolver, so the details panel shows the same icon).
  local icon = C.ResolveOutputIcon(r)
  sf.OutputIcon.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  sf.OutputIcon.Icon:SetTexCoord(0.079, 0.921, 0.079, 0.921)
  sf.OutputIcon.Icon:Show(); sf.OutputIcon:Show()

  -- Item quality (used for the rarity-colored name below; no ring/glow on the output icon).
  local link = (r.isCraft and GetCraftItemLink and GetCraftItemLink(r.index))
            or (GetTradeSkillItemLink and GetTradeSkillItemLink(r.index))
  local q = link and select(3, GetItemInfo(link))

  -- Output name + optional "x N" suffix.
  local made = ""
  if not r.isCraft and GetTradeSkillNumMade then
    local mn, mx = GetTradeSkillNumMade(r.index)
    if mx and mx > 1 then made = (" [%d-%d]"):format(mn or 1, mx)
    elseif mn and mn > 1 then made = (" x%d"):format(mn) end
  end
  sf.OutputText:SetText((r.name or "") .. made)
  -- Rarity-color the crafted item's name (falls back to white for enchants with no item quality).
  local nr, ng, nb = 1, 1, 1
  if q and GetItemQualityColor then
    local a, b2, c2 = GetItemQualityColor(q)
    if a then nr, ng, nb = a, b2, c2 end
  end
  sf.OutputText:SetTextColor(nr, ng, nb)

  -- Store the crafted item's link for shift/ctrl-click (chat link / dress up).
  sf.OutputIcon._link = link

  -- "Requires:" line — crafting tools / spell focus (Anvil, Tool Bench, …).
  C.UpdateRequires(r)

  -- Favourite star.
  if sf.FavoriteButton then
    sf.FavoriteButton:SetIsFavorite(isFav(r.name)); sf.FavoriteButton:Show()
  end

  -- Right-side item-details panel (scanned, wrapped, rarity-colored — sized to its content).
  C.UpdateItemDetails(r, link, icon)

  C._selected = r
  r._reagentTries = 0   -- fresh selection → allow the reagent-cache retry loop to run again
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

  local incomplete = false
  for i = 1, MAX_REAGENT_SLOTS do
    local s = slots[i]
    if not s then break end
    if i <= numReagents then
      -- Prime the item cache FIRST: querying the reagent link asks the server for the item when it
      -- isn't cached yet — the usual reason a reagent's name/icon comes back nil on first view.
      local rLink
      if r.isCraft and GetCraftReagentItemLink then
        rLink = GetCraftReagentItemLink(r.index, i)
      elseif GetTradeSkillReagentItemLink then
        rLink = GetTradeSkillReagentItemLink(r.index, i)
      end
      s._link = rLink   -- for shift/ctrl-click (chat link / dress up)

      local rName, rTex, rCount, rHave
      if r.isCraft and GetCraftReagentInfo then
        rName, rTex, rCount, rHave = GetCraftReagentInfo(r.index, i)
      elseif GetTradeSkillReagentInfo then
        rName, rTex, rCount, rHave = GetTradeSkillReagentInfo(r.index, i)
      end

      -- Not fully cached yet → keep the slot (with a placeholder) and flag a retry, so a reagent
      -- is never dropped from the list.
      if not rName or not rTex then incomplete = true end

      s.Icon:SetTexture(rTex or "Interface\\Icons\\INV_Misc_QuestionMark")
      local rq = rLink and GetItemInfo and select(3, GetItemInfo(rLink)) or nil
      applyItemQualityBorder(s.IconBorder, s.QualityGlow, rq)
      local enough = (rHave or 0) >= (rCount or 1)
      s.Count:SetText(("%d/%d"):format(rHave or 0, rCount or 1))
      s.Name:SetText(rName or "")
      local cc = enough and 1 or 0.5
      s.Count:SetVertexColor(cc, cc, cc); s.Name:SetVertexColor(cc, cc, cc)

      -- Tooltip.
      local idx = i
      s.IconHit:SetScript("OnEnter", function()
        GameTooltip:SetOwner(s.IconHit, "ANCHOR_RIGHT")
        local shown = false
        if r.isCraft and GameTooltip.SetCraftReagentItem then
          shown = pcall(GameTooltip.SetCraftReagentItem, GameTooltip, r.index, idx)
        elseif GameTooltip.SetTradeSkillReagentItem then
          shown = pcall(GameTooltip.SetTradeSkillReagentItem, GameTooltip, r.index, idx)
        end
        if not shown and s._link and GameTooltip.SetHyperlink then
          shown = pcall(GameTooltip.SetHyperlink, GameTooltip, s._link) and true or false
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
  end

  if sf.ReagentHeader then
    if numReagents > 0 then sf.ReagentHeader:Show() else sf.ReagentHeader:Hide() end
  end

  -- Bounded retry until every reagent's cached data arrives (token guards against a newer
  -- selection/update superseding this pass; ~25 × 0.12s ≈ 3s ceiling).
  C._reagentToken = (C._reagentToken or 0) + 1
  local token = C._reagentToken
  if incomplete and C_Timer and C_Timer.After and (r._reagentTries or 0) < 25 then
    r._reagentTries = (r._reagentTries or 0) + 1
    C_Timer.After(0.12, function()
      if token ~= C._reagentToken then return end
      if C._selected == r and C.frame and C.frame:IsShown() then C.UpdateReagents(r) end
    end)
  elseif not incomplete then
    r._reagentTries = 0
  end
end

-- ============================================================================
-- C.LiveNumAvailable(r) — how many of r can be crafted RIGHT NOW.
--
-- ISSUE #30 ("Professions don't live update"): r.numAvailable is a snapshot taken when the
-- recipe list was last built, and the client's own cached count (GetTradeSkillInfo /
-- GetCraftInfo) does not necessarily refresh in the same frame the reagents arrive — so
-- picking mats out of the mailbox left the Create button disabled until the recipe was
-- re-selected. The per-reagent have/need counts ARE read live, so derive a count from them
-- too and take whichever source says we can make more. Taking the max is deliberate: it can
-- only ever ENABLE a button that should be enabled, never disable one that should be usable.
-- ============================================================================
function C.LiveNumAvailable(r)
  if not r then return 0 end

  local cached = 0
  if r.isCraft and GetCraftInfo then
    cached = select(4, GetCraftInfo(r.index)) or 0
  elseif GetTradeSkillInfo then
    cached = select(3, GetTradeSkillInfo(r.index)) or 0
  end

  local numReagents = 0
  if r.isCraft and GetCraftNumReagents then
    numReagents = GetCraftNumReagents(r.index) or 0
  elseif GetTradeSkillNumReagents then
    numReagents = GetTradeSkillNumReagents(r.index) or 0
  end
  if numReagents == 0 then return cached end

  local computed
  for i = 1, numReagents do
    local rName, rTex, need, have
    if r.isCraft and GetCraftReagentInfo then
      rName, rTex, need, have = GetCraftReagentInfo(r.index, i)
    elseif GetTradeSkillReagentInfo then
      rName, rTex, need, have = GetTradeSkillReagentInfo(r.index, i)
    end
    -- Reagent not cached yet → we can't trust our own math this pass; defer to the client.
    if not rName or rName == "" then return cached end
    need = (need and need > 0) and need or 1
    local n = math.floor((have or 0) / need)
    if not computed or n < computed then computed = n end
    if computed == 0 then break end
  end

  return math.max(cached, computed or 0)
end

-- ============================================================================
-- C.UpdateCreateButtons(r) — enable/disable Create controls based on selection.
-- ============================================================================
function C.UpdateCreateButtons(r)
  local f = C.frame; if not f then return end
  
  -- Получаем перевод
  local createAllText = (L and L["Create All"]) or _G.TRADESKILL_CREATE_ALL or "Create All"

  if f.ScanAHButton then
    local reagentNames = getRecipeReagentNames(r)
    if r and #reagentNames > 0 then f.ScanAHButton:Enable() else f.ScanAHButton:Disable() end
  end

  if r and (r.numAvailable or 0) > 0 then
    if f.CreateButton    then f.CreateButton:Enable()    end
    if f.CreateAllButton then f.CreateAllButton:Enable() end
    if f.CreateAllButton then
      local n = r.numAvailable or 0
      f.CreateAllButton:SetText(createAllText .. (n > 0 and (" [%d]"):format(n) or ""))
    end
    -- Keep the quantity spinner inside the (now live) craftable range
    local qty = f.CreateMultipleInputBox
    if qty and qty.GetValue and not qty:HasFocus() then
      local v = qty:GetValue()
      if v > r.numAvailable then qty:SetText(r.numAvailable) end
    end
  else
    if f.CreateButton    then f.CreateButton:Disable()    end
    if f.CreateAllButton then
      f.CreateAllButton:Disable()
      f.CreateAllButton:SetText(createAllText)
    end
  end
end
