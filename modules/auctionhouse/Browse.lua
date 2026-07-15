-- DragonUI_NewEra/modules/auctionhouse/Browse.lua
-- Buy tab visual shell and Blizzard API search bridge.

local NE = DragonUI_NewEra
if not NE then return end

NE.ah = NE.ah or {}
local AH = NE.ah

-- Aggregate browse row click drills into a per-item detail page (all individual auctions of that
-- item); the detail page's Bid/Buyout buttons act on the selected listing via these two confirms.
StaticPopupDialogs["NE_AH_BROWSE_BID"] = {
  text = "Place a bid of %s?",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function(_, data)
    if not data or not data.index then return end
    local ok, err = pcall(PlaceAuctionBid, "list", data.index, data.price)
    if not ok and NE.Log then
      NE.Log("AH", "PlaceAuctionBid(bid) error: " .. tostring(err))
    end
  end,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  showAlert = 1,
}
StaticPopupDialogs["NE_AH_BROWSE_BUYOUT"] = {
  text = "Buy out this auction for %s?",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function(_, data)
    if not data or not data.index then return end
    local ok, err = pcall(PlaceAuctionBid, "list", data.index, data.price)
    if not ok and NE.Log then
      NE.Log("AH", "PlaceAuctionBid(buyout) error: " .. tostring(err))
    end
  end,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  showAlert = 1,
}

local CATEGORY_TREE = {
  { name = "Weapons", children = { "One-Handed Axes", "Two-Handed Axes", "Bows", "Guns", "One-Handed Maces", "Two-Handed Maces", "Polearms", "One-Handed Swords", "Two-Handed Swords", "Staves", "Fist Weapons", "Daggers", "Thrown" } },
  { name = "Armor", children = { "Cloth", "Leather", "Mail", "Plate", "Shields", "Librams", "Idols", "Totems", "Sigils" } },
  { name = "Container", children = { "Bags", "Soul Bags", "Herb Bags", "Enchanting Bags", "Engineering Bags", "Gem Bags", "Mining Bags" } },
  { name = "Consumable", children = { "Food & Drink", "Potion", "Elixir", "Flask", "Bandage", "Scroll", "Item Enhancement" } },
  { name = "Trade Goods", children = { "Parts", "Explosives", "Devices", "Jewelcrafting", "Cloth", "Leather", "Metal & Stone", "Meat", "Herb", "Elemental", "Enchanting", "Materials", "Armor Enchantment", "Weapon Enchantment" } },
  { name = "Projectile", children = { "Wand", "Arrow", "Bullet" } },
  { name = "Quiver", children = { "Quiver", "Ammo Pouch" } },
  { name = "Recipe", children = { "Book", "Leatherworking", "Tailoring", "Engineering", "Blacksmithing", "Cooking", "Alchemy", "First Aid", "Enchanting", "Fishing", "Jewelcrafting", "Inscription" } },
  { name = "Gems", children = { "Red", "Blue", "Yellow", "Purple", "Green", "Orange", "Meta", "Simple", "Prismatic" } },
  { name = "Miscellaneous", children = { "Junk", "Reagent", "Pet", "Holiday", "Other" } },
  { name = "Quest Items", children = { "Quest" } },
}

local function buildCategoryList(parent)
  local ROW_H = 21
  local ROW_GAP = 1
  -- Row count sized to fill the categories panel's own background art down to its bottom edge
  -- (previously 18 rows against a hardcoded 424px list height -- neither number matched the other,
  -- leaving a large dead gap below the last row; both now derive from the same VISIBLE_ROWS).
  local VISIBLE_ROWS = 19

  local list = CreateFrame("Frame", nil, parent)
  list:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -6)
  list:SetSize(152, VISIBLE_ROWS * ROW_H + (VISIBLE_ROWS - 1) * ROW_GAP)

  local rows = {}
  local flat = {}
  local selectedCat = nil
  local selectedSub = nil
  local selectedInv = nil
  local currentOffset = 0

  -- classIndex/subClassIndex passed to QueryAuctionItems are POSITIONAL (luaIndex into
  -- GetAuctionItemClasses()/GetAuctionItemSubClasses(classIndex)), not name-matched. Source the
  -- category tree from those same calls so the index we click is guaranteed to be the index the
  -- server expects -- a hand-maintained name list (CATEGORY_TREE) can silently drift out of order
  -- from the live class/subclass table and file every search under the wrong category. CATEGORY_TREE
  -- is kept only as a display-name fallback for the (never-expected) case these globals are missing.
  local classNamesCache
  local subClassCache = {}

  local function getClassNames()
    if classNamesCache then return classNamesCache end
    local names = {}
    if type(GetAuctionItemClasses) == "function" then
      local ok, res = pcall(function() return { GetAuctionItemClasses() } end)
      if ok and res and #res > 0 then names = res end
    end
    if #names == 0 then
      for i = 1, #CATEGORY_TREE do names[i] = CATEGORY_TREE[i].name end
    end
    classNamesCache = names
    return names
  end

  local function getSubClassNames(classIndex)
    local cached = subClassCache[classIndex]
    if cached then return cached end
    local subs = {}
    if type(GetAuctionItemSubClasses) == "function" then
      local ok, res = pcall(function() return { GetAuctionItemSubClasses(classIndex) } end)
      if ok and res then subs = res end
    end
    if #subs == 0 and CATEGORY_TREE[classIndex] then
      subs = CATEGORY_TREE[classIndex].children or {}
    end
    subClassCache[classIndex] = subs
    return subs
  end

  -- Third tier: inventory-type slots (Head, Shoulder, ...) within a selected class+subclass, e.g.
  -- Armor > Leather > Head. GetAuctionInvTypes(classIndex, subClassIndex) returns a FLAT list of
  -- (invTypeToken, shouldDisplay) pairs -- NOT one name per return like GetAuctionItemClasses -- so
  -- unlike the two tiers above this can't just be indexed 1:1; we walk it in twos, keep only the
  -- shouldDisplay entries, and record each one's ORIGINAL pair position as its invTypeIndex (the
  -- luaIndex QueryAuctionItems' invTypeIndex arg expects), not its position among the filtered/shown
  -- entries. invTypeToken (e.g. "INVTYPE_HEAD") is also the name of a global localized string with
  -- the human-readable slot name, same convention PaperDoll/Item tooltips use.
  local invTypeCache = {}

  local function getInvTypes(classIndex, subClassIndex)
    local key = classIndex .. ":" .. subClassIndex
    local cached = invTypeCache[key]
    if cached then return cached end
    local list = {}
    if type(GetAuctionInvTypes) == "function" then
      local ok, res = pcall(function() return { GetAuctionInvTypes(classIndex, subClassIndex) } end)
      if ok and res then
        local pos = 0
        for i = 1, #res, 2 do
          pos = pos + 1
          local token, display = res[i], res[i + 1]
          if display and token and token ~= "" then
            list[#list + 1] = { text = _G[token] or token, index = pos }
          end
        end
      end
    end
    invTypeCache[key] = list
    return list
  end

  local function maxOffset()
    local m = #flat - VISIBLE_ROWS
    if m < 0 then m = 0 end
    return m
  end

  local function setOffset(v)
    if v < 0 then v = 0 end
    local m = maxOffset()
    if v > m then v = m end
    currentOffset = v
    local sliderName = list.Scroll and list.Scroll.GetName and list.Scroll:GetName()
    local slider = sliderName and _G[sliderName .. "ScrollBar"]
    if slider and slider.SetValue then
      slider:SetValue(v * (ROW_H + ROW_GAP))
    elseif list.Scroll and list.Scroll.SetVerticalScroll then
      list.Scroll:SetVerticalScroll(v * (ROW_H + ROW_GAP))
    end
  end

  local function getOffset()
    if list.Scroll and FauxScrollFrame_GetOffset then
      local offset = FauxScrollFrame_GetOffset(list.Scroll) or 0
      currentOffset = offset
      return offset
    end
    return currentOffset
  end

  local function flatten()
    local out = {}
    local classNames = getClassNames()

    for ci = 1, #classNames do
      local catSelected = (selectedCat == ci)
      out[#out + 1] = { text = classNames[ci], kind = "category", ci = ci, selected = catSelected }
      if catSelected then
        local subs = getSubClassNames(ci)
        for si = 1, #subs do
          local subSelected = (selectedSub == si)
          out[#out + 1] = {
            text = subs[si] or tostring(si),
            kind = "subCategory",
            ci = ci,
            si = si,
            selected = subSelected,
          }
          if subSelected then
            local invTypes = getInvTypes(ci, si)
            for ii = 1, #invTypes do
              local inv = invTypes[ii]
              out[#out + 1] = {
                text = inv.text,
                kind = "invType",
                ci = ci,
                si = si,
                vi = inv.index,
                selected = (selectedInv == inv.index),
              }
            end
          end
        end
      end
    end
    return out
  end

  -- classIndex/subClassIndex/invTypeIndex for QueryAuctionItems. 0 == "any" (the client's own
  -- sentinel for an unset luaIndex filter slot), matching what a deselected row means.
  function list:GetSelectedIndices()
    return selectedCat or 0, selectedSub or 0, selectedInv or 0
  end

  local function styleRow(row, info)
    row.Bg:Hide()
    row.Line:Hide()

    if info.kind == "category" then
      if NE.tex and NE.tex.SetAtlas then
        NE.tex.SetAtlas(row.NormalTexture, "auctionhouse-nav-button", false)
        NE.tex.SetAtlas(row.SelectedTexture, "auctionhouse-nav-button-select", false)
        NE.tex.SetAtlas(row.HighlightTexture, "auctionhouse-nav-button-highlight", false)
      end
      row.NormalTexture:SetSize(136, 32)
      row.NormalTexture:ClearAllPoints()
      row.NormalTexture:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 0)

      row.SelectedTexture:SetSize(132, 21)
      row.SelectedTexture:ClearAllPoints()
      row.SelectedTexture:SetPoint("LEFT", row, "LEFT", 0, 0)

      row.HighlightTexture:SetSize(132, 21)
      row.HighlightTexture:ClearAllPoints()
      row.HighlightTexture:SetPoint("LEFT", row, "LEFT", 0, 0)

      row.Text:SetFontObject(GameFontNormal)
      row.Text:SetPoint("LEFT", row, "LEFT", 8, 0)
      row.Text:SetTextColor(1.0, 0.82, 0.0)
    else
      if NE.tex and NE.tex.SetAtlas then
        NE.tex.SetAtlas(row.NormalTexture, "auctionhouse-nav-button-secondary", false)
        NE.tex.SetAtlas(row.SelectedTexture, "auctionhouse-nav-button-secondary-select", false)
        NE.tex.SetAtlas(row.HighlightTexture, "auctionhouse-nav-button-secondary-highlight", false)
      end
      row.NormalTexture:SetSize(133, 32)
      row.NormalTexture:ClearAllPoints()
      row.NormalTexture:SetPoint("TOPLEFT", row, "TOPLEFT", 1, 0)

      row.SelectedTexture:SetSize(122, 21)
      row.SelectedTexture:ClearAllPoints()
      row.SelectedTexture:SetPoint("TOPLEFT", row, "TOPLEFT", 10, 0)

      row.HighlightTexture:SetSize(122, 21)
      row.HighlightTexture:ClearAllPoints()
      row.HighlightTexture:SetPoint("TOPLEFT", row, "TOPLEFT", 10, 0)

      -- Third tier (invType, e.g. "Head" under Armor > Leather) indents further than a plain
      -- subcategory so the two nesting depths read distinctly, matching the reference's deeper
      -- sub-sub-category rows.
      -- Sub/inv rows sit on a narrower secondary button (133px, vs. 136 for a category) AND start
      -- more indented -- GameFontNormal (used for the top-level rows) was overflowing that reduced
      -- width for longer names like "One-Handed Axes"/"Two-Handed Swords". Smaller font object fits
      -- comfortably within the button texture at every indent depth.
      row.Text:SetFontObject(GameFontHighlightSmall)
      row.Text:ClearAllPoints()
      local indent = (info.kind == "invType") and 28 or 18
      row.Text:SetPoint("LEFT", row, "LEFT", indent, 0)
      row.Text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
      row.Text:SetTextColor(0.88, 0.9, 0.95)
      row.Line:Show()
    end

    row.SelectedTexture:SetShown(info.selected and true or false)
    row.HighlightTexture:Hide()
  end

  local viewport = CreateFrame("Frame", nil, list)
  viewport:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  viewport:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
  viewport:SetHeight(VISIBLE_ROWS * ROW_H + (VISIBLE_ROWS - 1) * ROW_GAP)
  viewport:EnableMouseWheel(true)

  local function refreshRows()
    flat = flatten()
    setOffset(currentOffset)
    local offset = getOffset()

    for i = 1, VISIBLE_ROWS do
      local info = flat[i + offset]
      local row = rows[i]
      if not row then
        row = CreateFrame("Button", nil, viewport)
        row:SetSize(146, ROW_H)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetAllPoints(row)
        bg:Hide()
        row.Bg = bg

        row.NormalTexture = row:CreateTexture(nil, "BACKGROUND")
        row.SelectedTexture = row:CreateTexture(nil, "ARTWORK")
        row.HighlightTexture = row:CreateTexture(nil, "BORDER")
        row.HighlightTexture:Hide()

        row.Line = row:CreateTexture(nil, "BACKGROUND")
        if NE.tex and NE.tex.SetAtlas then
          NE.tex.SetAtlas(row.Line, "auctionhouse-nav-button-tertiary-filterline", true)
        end
        row.Line:SetPoint("LEFT", row, "LEFT", 18, 3)
        row.Line:Hide()

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", row, "LEFT", 8, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        row.Text = text

        row:SetScript("OnEnter", function(self)
          if self.HighlightTexture then self.HighlightTexture:Show() end
        end)
        row:SetScript("OnLeave", function(self)
          if self.HighlightTexture then self.HighlightTexture:Hide() end
        end)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function(self)
          if self._kind == "category" then
            if selectedCat == self._ci then
              selectedCat = nil
            else
              selectedCat = self._ci
            end
            selectedSub = nil
            selectedInv = nil
          elseif self._kind == "subCategory" then
            if selectedSub == self._si then
              selectedSub = nil
            else
              selectedSub = self._si
            end
            selectedInv = nil
          elseif self._kind == "invType" then
            if selectedInv == self._vi then
              selectedInv = nil
            else
              selectedInv = self._vi
            end
          else
            return
          end

          refreshRows()
        end)

        rows[i] = row
      end

      if i == 1 then
        row:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
      else
        row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -ROW_GAP)
      end

      if info then
        row._kind = info.kind
        row._ci = info.ci
        row._si = info.si
        row._vi = info.vi

        row.Text:SetText(info.text)
        styleRow(row, info)

        row:Show()
      else
        row._kind = nil
        row._ci = nil
        row._si = nil
        row._vi = nil
        row:Hide()
      end
    end

    if list.Scroll and FauxScrollFrame_Update then
      FauxScrollFrame_Update(list.Scroll, #flat, VISIBLE_ROWS, ROW_H + ROW_GAP)
    end
  end

  -- FauxScrollFrameTemplate's handlers (FauxScrollFrame_Update etc., FrameXML/UIPanelTemplates.lua)
  -- resolve the scrollbar's sub-widgets via frame:GetName() string concatenation, NOT parentKey --
  -- an anonymous (nil-named) FauxScrollFrame throws "attempt to concatenate ... (a nil value)" the
  -- moment FauxScrollFrame_Update runs on it. Must have a real global name.
  local scroll = CreateFrame("ScrollFrame", "NE_AuctionHouseBrowseCategoryScroll", list, "FauxScrollFrameTemplate")
  -- Explicit TOPLEFT+BOTTOMRIGHT (not just TOPLEFT+BOTTOMLEFT) so this frame actually has a defined
  -- width -- BuildCustom's bar anchors off scroll:GetRight(), which is meaningless on a frame that
  -- was never given a right edge, and could leave the bar mispositioned/invisible.
  -- The right edge must sit INSET from viewport's own right edge (not flush with it) -- BuildCustom
  -- places the bar opts.x (8px here) further right of scroll's right edge, same as the results-list
  -- and item-detail scroll frames, which each reserve a >=18px gutter for exactly this. A flush (0)
  -- inset here pushed the bar 8px past the whole category panel's border, off its visible bounds --
  -- reserving 18px keeps the bar's 8px-wide track inside `list`/`viewport`'s actual bounds.
  scroll:SetPoint("TOPLEFT", viewport, "TOPRIGHT", -30, -2)
  scroll:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -18, 2)
  scroll:SetScript("OnVerticalScroll", function(self, offset)
    if FauxScrollFrame_OnVerticalScroll then
      FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H + ROW_GAP, refreshRows)
      return
    end
    local step = ROW_H + ROW_GAP
    local nextOffset = math.floor((offset / step) + 0.5)
    currentOffset = nextOffset
    refreshRows()
  end)
  list.Scroll = scroll

  -- Physical scrollbar track+thumb (FauxScrollFrameTemplate alone draws NOTHING visible -- it's
  -- just offset math plus a hidden slider; every other FauxScroll list in this addon gets its
  -- visible bar from this same hand-built widget, driven off that hidden slider's min/max/value).
  -- BuildCustom's bar defaults to "HIGH" strata. AH.frame itself is explicitly "DIALOG" (Window.lua),
  -- and a frame's strata is inherited from its parent AT CREATION unless overridden -- so `list`/
  -- `viewport`/`scroll`, none of which set their own strata, are ALL "DIALOG" too, same as the rows
  -- built on them. That puts a "HIGH"-strata bar BEHIND the row buttons, hiding it completely (same
  -- trap already fixed for the results-list and item-detail scrollbars below). Force it to match.
  if NE.scrollbar and NE.scrollbar.BuildCustom then
    local ok, bar = pcall(NE.scrollbar.BuildCustom, scroll, { x = -8, alwaysShow = true })
    if ok and bar then
      bar:SetFrameStrata("DIALOG")
      bar:SetFrameLevel((viewport:GetFrameLevel() or 1) + 10)
      -- The arrow buttons' strata/level were set INSIDE BuildCustom against the bar's strata AT
      -- THAT TIME ("HIGH") -- promoting the bar to DIALOG afterward left them a strata behind,
      -- same trap as the bar-vs-rows one described above, so they never rendered (there but hidden).
      if bar._upBtn then bar._upBtn:SetFrameStrata("DIALOG"); bar._upBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
      if bar._downBtn then bar._downBtn:SetFrameStrata("DIALOG"); bar._downBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
    end
  end

  local function onMouseWheel(_, delta)
    if delta > 0 then
      setOffset(currentOffset - 1)
    else
      setOffset(currentOffset + 1)
    end
    refreshRows()
  end
  viewport:SetScript("OnMouseWheel", onMouseWheel)
  list:SetScript("OnMouseWheel", onMouseWheel)
  list:EnableMouseWheel(true)

  refreshRows()

  list.Refresh = refreshRows
  list.Rows = rows
  return list
end

function AH.BuildBrowsePane(parent)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetAllPoints(parent)

  -- Build right-to-left with RELATIVE anchors (searchButton -> filterButton -> searchBox) so the
  -- three controls can never overlap regardless of individual widths. The previous version anchored
  -- filterButton and searchButton independently off pane:TOPRIGHT with fixed offsets that didn't
  -- account for both widths, so filterButton's right 12px sat underneath searchButton's left edge.
  local searchButton = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
  searchButton:SetSize(120, 22)
  searchButton:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -8, -38)
  searchButton:SetText(SEARCH or "Search")
  pane.SearchButton = searchButton

  local filterButton = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
  filterButton:SetSize(90, 22)
  filterButton:SetPoint("RIGHT", searchButton, "LEFT", -10, 0)
  filterButton:SetText(AUCTION_FILTER_SUBCATEGORY_INVENTORY_TYPE or "Filter")
  pane.FilterButton = filterButton

  -- Styled to match the professions crafting search box (modules/professions/RecipeList.lua) --
  -- plain EditBox + dark tooltip backdrop + left search icon + right clear "x", instead of the
  -- stock InputBoxTemplate's gold-inset look, for visual consistency across the addon's search
  -- fields.
  local searchBox = CreateFrame("EditBox", nil, pane)
  searchBox:SetAutoFocus(false)
  searchBox:SetHeight(20)
  searchBox:SetWidth(220)
  searchBox:SetPoint("TOPLEFT", pane, "TOPLEFT", 220, -38)
  searchBox:SetPoint("RIGHT", filterButton, "LEFT", -10, 0)
  searchBox:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlightSmall)
  searchBox:SetTextInsets(20, 18, 0, 0)
  if searchBox.SetBackdrop then
    searchBox:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    searchBox:SetBackdropColor(0, 0, 0, 0.6)
    searchBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end
  searchBox:SetText("")
  searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  pane.SearchBox = searchBox

  local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
  searchIcon:SetSize(14, 14)
  searchIcon:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
  searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

  local searchClear = CreateFrame("Button", nil, searchBox)
  searchClear:SetSize(16, 16)
  searchClear:SetPoint("RIGHT", searchBox, "RIGHT", -2, 0)
  local searchClearTex = searchClear:CreateTexture(nil, "OVERLAY")
  searchClearTex:SetAllPoints(searchClear)
  if not (NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(searchClearTex, "common-search-clearbutton", false)) then
    searchClearTex:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  end
  searchClear:Hide()
  searchClear:SetScript("OnClick", function()
    searchBox:SetText("")
    searchBox:ClearFocus()
  end)
  searchBox:HookScript("OnTextChanged", function(self)
    local txt = self:GetText() or ""
    if txt ~= "" then searchClear:Show() else searchClear:Hide() end
  end)
  pane.SearchClear = searchClear

  -- Filter popup: Level Range + Usable Items Only. Plain manual frame (not a dropdown/menu widget
  -- unavailable on 3.3.5a). Styled with the SAME gold-trim inset + dark fill used everywhere else
  -- in this window (categories/results panels), instead of the flat parchment DialogBox backdrop,
  -- for visual consistency. Sits in "FULLSCREEN_DIALOG" strata (above the window's own "DIALOG"
  -- strata) so it always draws above the results list header/rows regardless of sibling creation
  -- order -- the previous version shared "DIALOG" with the results list, which (being built later
  -- in this function) drew on top of the panel and made it unreadable.
  pane.Filter = { minLevel = 0, maxLevel = 0, usable = false, minQuality = 0 }

  local filterPanel = CreateFrame("Frame", nil, pane)
  filterPanel:SetFrameStrata("FULLSCREEN_DIALOG")
  filterPanel:EnableMouse(true)
  filterPanel:Hide()
  filterPanel:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -6)
  filterPanel:SetSize(184, 262)
  pane.FilterPanel = filterPanel

  -- Grey fill matching THIS window's own header-strip tone (the results list's Price/Name/
  -- Available header row, a few lines below), not a value borrowed from an unrelated module --
  -- that mismatched against everything else in the Auction House window, which is uniformly dark.
  local filterBg = filterPanel:CreateTexture(nil, "BACKGROUND")
  filterBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  filterBg:SetVertexColor(0.06, 0.06, 0.07, 0.97)
  filterBg:SetAllPoints(filterPanel)

  if NE.nineslice and NE.nineslice.AttachInset then
    pcall(NE.nineslice.AttachInset, filterPanel, 0, 0, 0, 0)
  end

  local lvlTitle = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lvlTitle:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 14, -14)
  lvlTitle:SetText(AUCTION_HOUSE_FILTER_DROP_DOWN_LEVEL_RANGE or "Level Range")
  lvlTitle:SetTextColor(1, 0.82, 0)

  local function lvlBox()
    local b = CreateFrame("EditBox", nil, filterPanel, "InputBoxTemplate")
    b:SetSize(32, 20)
    b:SetAutoFocus(false)
    b:SetNumeric(true)
    b:SetMaxLetters(2)
    b:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    b:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    return b
  end

  local minBox = lvlBox()
  minBox:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 22, -36)
  local dash = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  dash:SetPoint("LEFT", minBox, "RIGHT", 10, 0)
  dash:SetText("-")
  local maxBox = lvlBox()
  maxBox:SetPoint("LEFT", dash, "RIGHT", 10, 0)

  local function commitLevels()
    pane.Filter.minLevel = minBox:GetNumber() or 0
    pane.Filter.maxLevel = maxBox:GetNumber() or 0
  end
  minBox:SetScript("OnEditFocusLost", commitLevels)
  maxBox:SetScript("OnEditFocusLost", commitLevels)
  minBox:SetScript("OnTextChanged", commitLevels)
  maxBox:SetScript("OnTextChanged", commitLevels)

  local divider = filterPanel:CreateTexture(nil, "ARTWORK")
  divider:SetTexture("Interface\\Buttons\\WHITE8X8")
  divider:SetVertexColor(1, 0.82, 0, 0.25)
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 12, -62)
  divider:SetPoint("TOPRIGHT", filterPanel, "TOPRIGHT", -12, -62)

  local usable = CreateFrame("CheckButton", nil, filterPanel, "UICheckButtonTemplate")
  usable:SetSize(24, 24)
  usable:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 10, -72)
  local usableLabel = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  usableLabel:SetPoint("LEFT", usable, "RIGHT", 2, 0)
  usableLabel:SetText(AUCTION_HOUSE_FILTER_USABLE_ONLY or USABLE_ITEMS or "Usable Items Only")
  usable:SetScript("OnClick", function(self)
    pane.Filter.usable = self:GetChecked() and true or false
  end)

  local divider2 = filterPanel:CreateTexture(nil, "ARTWORK")
  divider2:SetTexture("Interface\\Buttons\\WHITE8X8")
  divider2:SetVertexColor(1, 0.82, 0, 0.25)
  divider2:SetHeight(1)
  divider2:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 12, -104)
  divider2:SetPoint("TOPRIGHT", filterPanel, "TOPRIGHT", -12, -104)

  local rarityTitle = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rarityTitle:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 14, -114)
  rarityTitle:SetText(RARITY or "Rarity")
  rarityTitle:SetTextColor(1, 0.82, 0)

  -- Rarity radios (All + Poor..Epic). No dedicated radio-button XML template is trusted here --
  -- "RefreshButtonTemplate" already proved reference-addon template assumptions don't hold on this
  -- exact client build (see the detailRefresh comment above), so this reuses the SAME
  -- UICheckButtonTemplate the Usable Items checkbox above already uses safely, with hand-rolled
  -- mutual exclusivity instead of relying on a native radio widget.
  local rarityBtns = {}
  local function setRarity(val)
    pane.Filter.minQuality = val or 0
    for _, rb in ipairs(rarityBtns) do rb:SetChecked(rb._val == val) end
  end
  local function rarityRow(y, val, label)
    local rb = CreateFrame("CheckButton", nil, filterPanel, "UICheckButtonTemplate")
    rb:SetSize(18, 18)
    rb:SetPoint("TOPLEFT", filterPanel, "TOPLEFT", 12, y)
    rb._val = val
    local fs = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", rb, "RIGHT", 4, 0)
    fs:SetText(label)
    rb:SetScript("OnClick", function() setRarity(val) end)
    rarityBtns[#rarityBtns + 1] = rb
  end
  rarityRow(-134, nil, ALL or "All")
  rarityRow(-153, 0, NE.itembtn and NE.itembtn.WrapTextByQuality(_G.ITEM_QUALITY0_DESC or "Poor", 0) or (_G.ITEM_QUALITY0_DESC or "Poor"))
  rarityRow(-172, 1, NE.itembtn and NE.itembtn.WrapTextByQuality(_G.ITEM_QUALITY1_DESC or "Common", 1) or (_G.ITEM_QUALITY1_DESC or "Common"))
  rarityRow(-191, 2, NE.itembtn and NE.itembtn.WrapTextByQuality(_G.ITEM_QUALITY2_DESC or "Uncommon", 2) or (_G.ITEM_QUALITY2_DESC or "Uncommon"))
  rarityRow(-210, 3, NE.itembtn and NE.itembtn.WrapTextByQuality(_G.ITEM_QUALITY3_DESC or "Rare", 3) or (_G.ITEM_QUALITY3_DESC or "Rare"))
  rarityRow(-229, 4, NE.itembtn and NE.itembtn.WrapTextByQuality(_G.ITEM_QUALITY4_DESC or "Epic", 4) or (_G.ITEM_QUALITY4_DESC or "Epic"))
  setRarity(nil)

  filterButton:SetScript("OnClick", function() filterPanel:SetShown(not filterPanel:IsShown()) end)

  -- Click-outside-to-close: a fullscreen catcher one frame level under the panel, same strata so
  -- it still sits above the rest of the window and intercepts the outside click.
  local filterCatcher = CreateFrame("Button", nil, filterPanel)
  filterCatcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
  filterCatcher:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
  filterCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
  filterCatcher:SetFrameLevel(math.max((filterPanel:GetFrameLevel() or 1) - 1, 0))
  filterCatcher:EnableMouse(true)
  filterCatcher:Hide()
  filterCatcher:SetScript("OnClick", function() filterPanel:Hide() end)
  filterPanel:HookScript("OnShow", function() filterCatcher:Show() end)
  filterPanel:HookScript("OnHide", function() filterCatcher:Hide() end)
  pane:HookScript("OnHide", function() filterPanel:Hide() end)

  local list = CreateFrame("Frame", nil, pane)
  list:SetPoint("TOPLEFT", pane, "TOPLEFT", 172, -73)
  -- -5, matching the Sell tab's right-hand panel (Sell.lua's `right`) -- previously -24, which cut
  -- this panel 19px shorter than Sell's and left its right edge not lining up across tabs.
  list:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -5, 27)
  pane.Results = list

  local listFallback = list:CreateTexture(nil, "BACKGROUND")
  listFallback:SetTexture("Interface\\Buttons\\WHITE8X8")
  listFallback:SetVertexColor(0.02, 0.02, 0.025, 0.92)
  listFallback:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -22)
  listFallback:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -22, 0)

  local listBg = list:CreateTexture(nil, "BACKGROUND")
  local appliedIndexAtlas = false
  if NE.tex and NE.tex.SetAtlas then
    appliedIndexAtlas = NE.tex.SetAtlas(listBg, "auctionhouse-background-index", false) and true or false
  end
  if appliedIndexAtlas then
    listBg:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -22)
    listBg:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -22, 0)
  else
    listBg:SetTexture(nil)
  end

  if NE.nineslice and NE.nineslice.AttachInset then
    pcall(NE.nineslice.AttachInset, list, 0, -19, -22, 0)
  end

  local headerStrip = list:CreateTexture(nil, "BORDER")
  headerStrip:SetTexture("Interface\\Buttons\\WHITE8X8")
  headerStrip:SetVertexColor(0.06, 0.06, 0.07, 0.95)
  headerStrip:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -1)
  headerStrip:SetPoint("TOPRIGHT", list, "TOPRIGHT", -22, -1)
  headerStrip:SetHeight(21)

  local headers = {
    { text = AUCTION_HOUSE_BROWSE_HEADER_PRICE or "Price", x = 10, w = 120, just = "LEFT" },
    { text = AUCTION_HOUSE_BROWSE_HEADER_NAME or NAME or "Name", x = 180, w = 260, just = "LEFT" },
    { text = AUCTION_HOUSE_BROWSE_HEADER_QUANTITY or "Available", x = -80, w = 72, just = "RIGHT", right = true },
  }

  for i = 1, #headers do
    local h = headers[i]
    local fs = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", list, "TOPLEFT", h.x, -7)
    if h.right then
      fs:ClearAllPoints()
      fs:SetPoint("TOPRIGHT", list, "TOPRIGHT", h.x, -7)
    end
    fs:SetWidth(h.w)
    fs:SetJustifyH(h.just)
    fs:SetText(h.text)
  end

  local empty = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("CENTER", list, "CENTER", 0, 44)
  empty:SetText("Choose search criteria and press \"Search\"")
  empty:SetTextColor(1, 0.82, 0)
  pane.EmptyText = empty

  local RESULTS_TOP = -24
  local ROW_H = 20

  local rows = {}
  local rowsHost = CreateFrame("Frame", nil, list)
  rowsHost:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
  rowsHost:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
  rowsHost:SetFrameStrata("DIALOG")
  rowsHost:SetFrameLevel((list:GetFrameLevel() or 1) + 20)

  -- FauxScrollFrameTemplate's handlers resolve the scrollbar's sub-widgets via frame:GetName()
  -- string concatenation, NOT parentKey -- an anonymous (nil-named) FauxScrollFrame throws
  -- "attempt to concatenate ... (a nil value)" the moment FauxScrollFrame_Update runs on it. THIS
  -- was the actual reason the Buy tab got stuck on "Searching..." forever: refreshResults() called
  -- FauxScrollFrame_Update on this nameless frame, the resulting error aborted refreshResults()
  -- before it ever reached the empty:Hide()/row-population code below it, even though the data
  -- (listRows) was already correctly populated by that point.
  local scroll = CreateFrame("ScrollFrame", "NE_AuctionHouseBrowseResultsScroll", list, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 2, RESULTS_TOP)
  scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -26, 4)
  local resultsCustomBar

  -- Physical scrollbar track+thumb -- FauxScrollFrameTemplate alone draws nothing visible, just
  -- offset math plus a hidden slider. Sits in the 26px gutter reserved above, so it never overlaps
  -- the DIALOG-strata rows (they're inset -30 from list's right edge, see ensureRow below).
  -- BuildCustom's bar defaults to "HIGH" strata, but rowsHost (the actual row buttons, below) is
  -- explicitly "DIALOG" so it draws above the plain-strata list background -- that puts the rows
  -- ABOVE a HIGH-strata scrollbar too, hiding it entirely. Same trap already fixed for the item-
  -- detail scroll bar (see detailScroll below); force this bar to match.
  if NE.scrollbar and NE.scrollbar.BuildCustom then
    local ok, bar = pcall(NE.scrollbar.BuildCustom, scroll, { x = -8, alwaysShow = true })
    if ok and bar then
      resultsCustomBar = bar
      bar:SetFrameStrata("DIALOG")
      bar:SetFrameLevel((rowsHost:GetFrameLevel() or 1) + 10)
      -- See the matching comment on the category-list scrollbar above -- the arrow buttons need
      -- the same post-hoc strata promotion the bar itself gets, or they stay stuck at "HIGH".
      if bar._upBtn then bar._upBtn:SetFrameStrata("DIALOG"); bar._upBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
      if bar._downBtn then bar._downBtn:SetFrameStrata("DIALOG"); bar._downBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
    end
  end

  local function setResultsScrollbarShown(shown)
    if not resultsCustomBar then return end
    if shown then
      resultsCustomBar:Show()
      if resultsCustomBar._upBtn then resultsCustomBar._upBtn:Show() end
      if resultsCustomBar._downBtn then resultsCustomBar._downBtn:Show() end
    else
      resultsCustomBar:Hide()
      if resultsCustomBar._upBtn then resultsCustomBar._upBtn:Hide() end
      if resultsCustomBar._downBtn then resultsCustomBar._downBtn:Hide() end
    end
  end

  local function setBrowseResultsShown(shown)
    if shown then
      list:Show()
    else
      list:Hide()
    end
    setResultsScrollbarShown(shown)
  end

  local function fsUpdate(frame, total, shown, step)
    if FauxScrollFrame_Update then
      FauxScrollFrame_Update(frame, total, shown, step)
    else
      frame.offset = frame.offset or 0
    end
  end

  local function fsGetOffset(frame)
    if FauxScrollFrame_GetOffset then
      return FauxScrollFrame_GetOffset(frame) or 0
    end
    return frame.offset or 0
  end

  local function moneyText(copper)
    if not copper or copper <= 0 then return "-" end
    if GetCoinTextureString then
      return GetCoinTextureString(copper)
    end
    return tostring(copper)
  end

  local listRows = {}
  local listTotal = 0
  local displayRows = {}

  -- Page navigation -- QueryAuctionItems' 7th arg is a server-side page number (each page capped at
  -- NUM_AUCTION_ITEMS_PER_PAGE, typically 50); this was previously hardcoded to 0 in runSearch below,
  -- so a browse could never surface anything past the server's first page no matter how many results
  -- matched. Small Prev/Next buttons + a "Page N of M" label in the gutter under the results list,
  -- using the same proven-safe UIPanelButtonTemplate the Search/Filter buttons above already use.
  local currentPage = 0
  local lastQuery = nil

  local pagePrev = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
  pagePrev:SetSize(24, 20)
  pagePrev:SetText("<")
  pagePrev:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 3, -24)
  pagePrev:Disable()

  local pageNext = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
  pageNext:SetSize(24, 20)
  pageNext:SetText(">")
  pageNext:SetPoint("LEFT", pagePrev, "RIGHT", 4, 0)
  pageNext:Disable()

  local pageLabel = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pageLabel:SetPoint("LEFT", pageNext, "RIGHT", 8, 0)
  pageLabel:SetText("Page 1 of 1")

  local function updatePageControls()
    local perPage = NUM_AUCTION_ITEMS_PER_PAGE or 50
    local totalPages = math.max(1, math.ceil((listTotal or 0) / perPage))
    pageLabel:SetText(string.format("Page %d of %d", currentPage + 1, totalPages))
    if currentPage <= 0 then pagePrev:Disable() else pagePrev:Enable() end
    if currentPage + 1 >= totalPages then pageNext:Disable() else pageNext:Enable() end
  end

  -- "browse" (aggregate results list, below) or "itembuy" (the per-item drill-down built near the
  -- end of this function). Both share the client's single "list" query slot and its
  -- AUCTION_ITEM_LIST_UPDATE event, so this flag routes that shared watcher to the right refresher
  -- -- opening the drill-down re-queries "list" scoped to one item, which would otherwise silently
  -- clobber the aggregate browse rows with that one item's data.
  local activeQuery = "browse"
  -- Forward decls: assigned once the drill-down widgets exist, near the end of this function, but
  -- referenced earlier (the aggregate row's OnClick, the shared watcher below).
  local openItemDetail
  local refreshDetailRows

  -- Switching away from Buy (Sell/Auctions tab, or closing the window) while the item drill-down
  -- is open would otherwise leave activeQuery == "itembuy" and keep routing the shared
  -- AUCTION_ITEM_LIST_UPDATE watcher away from the browse list on return.
  pane:HookScript("OnHide", function()
    activeQuery = "browse"
    if pane.ItemDetail then pane.ItemDetail:Hide() end
    setBrowseResultsShown(true)
  end)

  local function getListCounts()
    if type(GetNumAuctionItems) ~= "function" then
      return 0, 0
    end
    local batch, total = GetNumAuctionItems("list")
    batch = (type(batch) == "number" and batch) or 0
    total = (type(total) == "number" and total) or batch
    if total < batch then
      total = batch
    end
    return batch, total
  end

  local function captureListRows()
    local rows = {}
    local batchCount, totalCount = getListCounts()
    listTotal = totalCount
    updatePageControls()

    local cap = batchCount
    if cap <= 0 then
      cap = NUM_AUCTION_ITEMS_PER_PAGE or 50
    end

    for index = 1, cap do
      -- Field order per THIS server's own bundled APIDocumentation addon (13 return values, no
      -- "levelColumnName" slot the generic retail/Wowpedia signature has): name, texture, count,
      -- quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highestBidder, owner,
      -- sold. minBid is position 7 and buyoutPrice is position 9 on THIS client.
      local name, texture, count, quality, _, _, minBid, _, buyoutPrice = GetAuctionItemInfo("list", index)
      if not name then
        break
      end
      local link = GetAuctionItemLink and GetAuctionItemLink("list", index)
      rows[#rows + 1] = {
        index = index,
        name = name,
        texture = texture,
        quality = quality,
        count = count,
        minBid = minBid,
        buyoutPrice = buyoutPrice,
        link = link,
      }
    end

    listRows = rows
    return rows, batchCount, totalCount
  end

  -- Group the raw per-auction rows above by item name into one row per item (icon, quality-colored
  -- name, cheapest current price, total quantity across every auction of that item) -- matching the
  -- reference's aggregated Browse view. Clicking an aggregate row re-queries and drills into the
  -- individual auctions (openItemDetail, near the end of this function).
  local function buildDisplayRows()
    local groups = {}
    local order = {}
    for i = 1, #listRows do
      local r = listRows[i]
      local g = groups[r.name]
      if not g then
        g = { name = r.name, texture = r.texture, quality = r.quality, count = 0 }
        groups[r.name] = g
        order[#order + 1] = g
      end
      g.link = g.link or r.link
      g.count = g.count + (r.count or 1)
      if r.buyoutPrice and r.buyoutPrice > 0 then
        if not g.minBuyout or r.buyoutPrice < g.minBuyout then g.minBuyout = r.buyoutPrice end
      end
      if r.minBid and r.minBid > 0 then
        if not g.minBid or r.minBid < g.minBid then g.minBid = r.minBid end
      end
    end
    displayRows = order
  end

  -- Fill the entire scroll viewport instead of a hardcoded row count -- previously a fixed 17 rows
  -- left most of the panel's actual (much taller) height as dead space below the last row, same bug
  -- already fixed on the item-detail rows below (see detailVisibleRows).
  local function resultsVisibleRows()
    local h = scroll:GetHeight() or 0
    return math.max(1, math.floor(h / (ROW_H + 1)))
  end

  local function ensureRow(i)
    local row = rows[i]
    if row then return row end

    row = CreateFrame("Button", nil, rowsHost)
    row:SetFrameStrata("DIALOG")
    row:SetHeight(ROW_H)
    row:SetFrameLevel((list:GetFrameLevel() or 1) + 10)
    if i == 1 then
      row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, RESULTS_TOP)
      row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -30, RESULTS_TOP)
    else
      row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -1)
      row:SetPoint("TOPRIGHT", rows[i - 1], "BOTTOMRIGHT", 0, -1)
    end

    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    rowBg:SetAllPoints(row)
    rowBg:SetVertexColor(0.07, 0.07, 0.08, (i % 2 == 0) and 0.30 or 0.20)
    row.Bg = rowBg

    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local hl = row:GetHighlightTexture()
    if hl then
      hl:SetVertexColor(1, 0.82, 0, 0.12)
      hl:SetBlendMode("ADD")
    end

    local price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    price:SetPoint("LEFT", row, "LEFT", 4, 0)
    price:SetWidth(164)
    price:SetJustifyH("LEFT")
    row.Price = price

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 174, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.Icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -90, 0)
    name:SetJustifyH("LEFT")
    row.Name = name

    local qty = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qty:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    qty:SetWidth(80)
    qty:SetJustifyH("RIGHT")
    row.Qty = qty

    -- Click drills into this item's individual auctions (the ItemBuy-style page built near the end
    -- of this function), matching the reference's two-tier Browse -> item-detail flow. These rows
    -- are aggregated across auctions, so show a normal item tooltip from the item link rather than
    -- an auction-index tooltip bound to one specific listing.
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
      if IsModifiedClick and IsModifiedClick("DRESSUP") and self._data and self._data.link then
        AH.DressUpItem(self._data.link)
        return
      end
      if openItemDetail then openItemDetail(self._data) end
    end)
    row:SetScript("OnEnter", function(self)
      if not (self._data and self._data.name) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local shown = self._data.link and pcall(GameTooltip.SetHyperlink, GameTooltip, self._data.link)
      if not shown then
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self._data.name, 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    rows[i] = row
    return row
  end

  local function refreshResults()
    local drawCount = #displayRows
    local visibleRows = resultsVisibleRows()
    fsUpdate(scroll, drawCount, visibleRows, ROW_H + 1)
    local offset = fsGetOffset(scroll)
    local maxOffset = drawCount - visibleRows
    if maxOffset < 0 then maxOffset = 0 end
    if offset > maxOffset then offset = maxOffset end

    if drawCount > 0 then
      empty:Hide()
    else
      empty:Show()
      if listTotal > 0 then
        empty:SetText("Loading results...")
      else
        empty:SetText("No results. Adjust filters and search again.")
      end
    end

    for i = 1, visibleRows do
      local row = ensureRow(i)
      local data = displayRows[i + offset]
      if data then
        row._data = data
        row.Price:SetText(moneyText((data.minBuyout and data.minBuyout > 0) and data.minBuyout or data.minBid or 0))
        row.Name:SetText(data.name or "?")
        if data.quality and data.quality > 1 and GetItemQualityColor then
          local r, g, b = GetItemQualityColor(data.quality)
          row.Name:SetTextColor(r, g, b)
        else
          row.Name:SetTextColor(1, 1, 1)
        end
        if row.Icon then
          row.Icon:SetTexture(data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        row.Qty:SetText(data.count and tostring(data.count) or "1")
        row:Show()
      else
        row._data = nil
        row:Hide()
      end
    end
    -- Hide any previously-built rows beyond the current viewport (only relevant if the panel's
    -- effective height ever shrinks between refreshes; harmless no-op otherwise).
    for i = visibleRows + 1, #rows do
      local row = rows[i]
      row._data = nil
      row:Hide()
    end
  end

  scroll:SetScript("OnVerticalScroll", function(self, offset)
    if FauxScrollFrame_OnVerticalScroll then
      FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H + 1, refreshResults)
    else
      local step = ROW_H + 1
      local nextOffset = math.floor((offset / step) + 0.5)
      if nextOffset < 0 then nextOffset = 0 end
      self.offset = nextOffset
      refreshResults()
    end
  end)

  -- Re-issue the last search scoped to a different server page, reusing the same filter/category
  -- params runSearch captured into `lastQuery`. Shared by runSearch (always page 0) and the Prev/
  -- Next buttons below.
  local function doQuery(page)
    if not lastQuery then return end
    if not (CanSendAuctionQuery and CanSendAuctionQuery("list")) then
      empty:SetText("Auction query is throttled. Try again in a moment.")
      return
    end

    currentPage = page
    listRows = {}
    displayRows = {}

    local q = lastQuery
    local ok, err = pcall(QueryAuctionItems, q.text, q.minLevel, q.maxLevel, q.invTypeIndex, q.classIndex, q.subClassIndex, page, q.isUsable, q.minQuality, false)
    if ok then
      empty:SetText("Searching...")
    else
      -- Surface the real Lua error instead of a generic message -- if this still isn't the right
      -- call shape, the exact "bad argument #N" text tells us which slot to fix next.
      empty:SetText("Search failed: " .. tostring(err))
      if NE.Log then NE.Log("AH", "QueryAuctionItems error: " .. tostring(err)) end
    end
    updatePageControls()
  end

  local function runSearch()
    listTotal = 0
    -- A fresh browse search always returns to the aggregate list -- close any open item drill-down
    -- so it can't keep routing the shared "list" query event and show a stale item's rows.
    activeQuery = "browse"
    if pane.ItemDetail then pane.ItemDetail:Hide() end
    setBrowseResultsShown(true)

    local q = searchBox:GetText() or ""
    q = string.gsub(q, "^%s+", "")
    q = string.gsub(q, "%s+$", "")

    -- 3.3.5a's QueryAuctionItems signature per THIS server's own bundled APIDocumentation addon
    -- (Interface/AddOns/APIDocumentation/Documentation/AuctionDocumentation.lua): name, minLevel,
    -- maxLevel, invTypeIndex, classIndex, subClassIndex, page, isUsable, minQuality, getAll -- and
    -- EVERY one of those except getAll is documented Nilable=false with a concrete type (number/
    -- luaIndex/bool), not just invTypeIndex. The previous version still passed nil for classIndex/
    -- subClassIndex/minQuality and a number (0) for the bool isUsable slot; pass real typed values
    -- for all of them so a strict argument check on this core can't reject the call outright.
    local filter = pane.Filter or {}
    local minLevel = filter.minLevel or 0
    local maxLevel = filter.maxLevel or 0
    local isUsable = filter.usable and true or false
    local minQuality = filter.minQuality or 0

    -- classIndex/subClassIndex/invTypeIndex from the left category tree (0/0/0 == no category
    -- filter). These are POSITIONAL luaIndex values into GetAuctionItemClasses()/
    -- GetAuctionItemSubClasses()/GetAuctionInvTypes(), which is exactly what pane.CategoryList
    -- tracks a click against -- see buildCategoryList's getClassNames/getSubClassNames/getInvTypes.
    -- Previously hardcoded to 0,0,0 here, so clicking a category never filtered.
    local classIndex, subClassIndex, invTypeIndex = 0, 0, 0
    if pane.CategoryList and pane.CategoryList.GetSelectedIndices then
      classIndex, subClassIndex, invTypeIndex = pane.CategoryList:GetSelectedIndices()
    end

    lastQuery = {
      text = q, minLevel = minLevel, maxLevel = maxLevel, invTypeIndex = invTypeIndex,
      classIndex = classIndex, subClassIndex = subClassIndex, isUsable = isUsable, minQuality = minQuality,
    }
    doQuery(0)
  end

  pagePrev:SetScript("OnClick", function()
    if currentPage > 0 then doQuery(currentPage - 1) end
  end)
  pageNext:SetScript("OnClick", function()
    local perPage = NUM_AUCTION_ITEMS_PER_PAGE or 50
    local totalPages = math.max(1, math.ceil((listTotal or 0) / perPage))
    if currentPage + 1 < totalPages then doQuery(currentPage + 1) end
  end)

  -- Exposed so Window.lua can clear this pane's search state when the WHOLE Auction House window
  -- closes (AH.frame:Hide(), via AUCTION_HOUSE_CLOSED/ESC/close-button) -- not the same as switching
  -- away from the Buy tab, which only hides `pane` itself and is already handled by the OnHide hook
  -- below. Hiding the top-level frame does NOT fire OnHide on this pane (WoW only fires a frame's
  -- own OnHide from its own explicit :Hide() call, not from an ancestor's), so without this the next
  -- AUCTION_HOUSE_SHOW would still be showing whatever was searched last session.
  local function resetSearch()
    listRows = {}
    listTotal = 0
    displayRows = {}
    activeQuery = "browse"
    currentPage = 0
    lastQuery = nil
    if pane.ItemDetail then pane.ItemDetail:Hide() end
    setBrowseResultsShown(true)
    searchBox:SetText("")
    searchBox:ClearFocus()
    empty:SetText("Choose search criteria and press \"Search\"")
    refreshResults()
    updatePageControls()
  end
  pane.ResetSearch = resetSearch

  searchButton:SetScript("OnClick", runSearch)
  searchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    runSearch()
  end)

  -- The client reports GetNumAuctionItems("list") counts before GetAuctionItemInfo has the
  -- per-index data ready, so a single retry can still race the server response. Poll on a short
  -- timer until rows actually populate (or we give up) instead of trying just once.
  local pollAttempts = 0
  local MAX_POLL_ATTEMPTS = 40 -- ~4s at 0.1s steps

  local function pollForRows()
    if not (pane and pane:IsShown()) then return end
    if activeQuery ~= "browse" then return end
    local rowsData = captureListRows()
    buildDisplayRows()
    refreshResults()
    if #rowsData > 0 then
      pollAttempts = 0
      return
    end
    pollAttempts = pollAttempts + 1
    if pollAttempts < MAX_POLL_ATTEMPTS and C_Timer and C_Timer.After then
      C_Timer.After(0.1, pollForRows)
    else
      pollAttempts = 0
    end
  end

  local watcher = CreateFrame("Frame", nil, pane)
  watcher:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
  watcher:SetScript("OnEvent", function()
    if not pane:IsShown() then return end
    if type(AuctionFrameBrowse_Update) == "function" then
      pcall(AuctionFrameBrowse_Update)
    end
    -- AuctionFrameBrowse_Update (stock FrameXML, called above so the legacy client's own internal
    -- state stays consistent) can reassert Show()/alpha on the legacy AH frame as part of its own
    -- normal update logic, undoing the one-time cloak from window-open time -- re-cloak on every
    -- single event (browse AND the item drill-down's own re-query both fire this) so its old
    -- parchment/stone background can never bleed back through.
    if AH.SuppressLegacyAuctionFrame then pcall(AH.SuppressLegacyAuctionFrame) end
    if AH.SuppressModernAuctionFrame then pcall(AH.SuppressModernAuctionFrame) end

    -- The item drill-down issues its own "list" query scoped to one item -- route this shared
    -- event to its refresher instead of the aggregate browse path while it's the active query.
    if activeQuery == "itembuy" then
      if refreshDetailRows then
        local rdOk, rdErr = pcall(refreshDetailRows)
        if not rdOk and NE.Log then
          NE.Log("AH", "refreshDetailRows error: " .. tostring(rdErr))
        end
      end
      return
    end

    local rowsData, batchCount, totalCount = captureListRows()
    buildDisplayRows()
    local found = totalCount
    if found <= 0 then
      found = batchCount
    end
    -- pcall-wrapped: refreshResults calls the stock FauxScrollFrame_Update, which errors if the
    -- scroll frame is ever anonymous again (see the naming comment above) -- don't let a future
    -- regression there leave the UI stuck showing stale text with no visible feedback.
    local rrOk, rrErr = pcall(refreshResults)
    if not rrOk and NE.Log then
      NE.Log("AH", "refreshResults error: " .. tostring(rrErr))
    end
    if found > 0 and #rowsData <= 0 and C_Timer and C_Timer.After then
      pollAttempts = 0
      C_Timer.After(0.1, pollForRows)
    end
  end)

  -- ================================================================================
  -- Item drill-down (retail's Buy -> ItemBuy two-tier flow): clicking an aggregate row above
  -- re-queries "list" scoped to that exact item name and lists every individual auction (Current
  -- Bid / Buyout / Qty / Seller / Time Left). Click a listing to select it, then Bid/Buyout acts on
  -- it. Confirmed against a live screenshot of the actual NewEra reference addon: the search bar
  -- STAYS visible/unhidden -- this overlay only occupies the categories/results footprint below
  -- it (same TOPLEFT the results list itself uses, 172,-73), with a plain Back/count/refresh row
  -- at its own top (no border around just that row), then the item header card and the auction
  -- list as two SEPARATE bordered boxes beneath it -- not one border wrapping the whole thing.
  -- ================================================================================
  local detail = CreateFrame("Frame", nil, pane)
  detail:SetFrameStrata("DIALOG")
  detail:SetFrameLevel((list:GetFrameLevel() or 1) + 30)
  detail:SetPoint("TOPLEFT", pane, "TOPLEFT", 172, -73)
  -- Matches `list`'s own right edge (-5, same as Sell's `right` panel) so this overlay lines up
  -- with the panel it sits on top of.
  detail:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -5, 27)
  detail:EnableMouse(true) -- swallow clicks so the hidden results list beneath can't be hit
  detail:Hide()
  pane.ItemDetail = detail

  local detailBg = detail:CreateTexture(nil, "BACKGROUND")
  detailBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  detailBg:SetVertexColor(0.045, 0.045, 0.05, 0.98)
  detailBg:SetAllPoints(detail)

  local detailBack = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
  detailBack:SetSize(90, 22)
  detailBack:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -8)
  detailBack:SetText(BACK or "Back")

  -- Refresh button: plain text, same UIPanelButtonTemplate every other button on this page uses.
  -- Two prior icon attempts both failed on THIS client build -- a hand-rolled
  -- Interface\Buttons\UI-RefreshButton texcoord split guessed the sheet layout wrong (rendered as
  -- a cut-off half-circle), and "RefreshButtonTemplate" (which the reference addon's own
  -- ItemList.lua assumes) doesn't exist as an inheritable XML template here at all -- CreateFrame
  -- threw "Couldn't find inherited node", which errored the ENTIRE pane builder (safeBuild's pcall
  -- caught it) and dropped the whole Buy tab to its fallback screen. A plain text button needs no
  -- texture asset at all, so it can't hit either failure mode.
  local detailRefresh = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
  detailRefresh:SetSize(70, 20)
  detailRefresh:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -6, -10)
  detailRefresh:SetText(REFRESH or "Refresh")

  local detailCount = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  detailCount:SetPoint("RIGHT", detailRefresh, "LEFT", -8, 0)
  detailCount:SetTextColor(1, 1, 1)

  -- Item header card (its own separate bordered box, not shared with the Back row above it). Real
  -- retail art per the reference addon's own atlas dump (ReferenceAddons/NewEra/Generated/
  -- AtlasData.lua) -- both atlases live on the SAME two sheet files this module already ships
  -- locally (3054898/3046538), just not previously registered here. Flat-fill/plain-square
  -- fallback if SetAtlas ever can't find them (missing/renamed asset), so a bad lookup degrades
  -- gracefully instead of leaving the header blank.
  local detailHeader = CreateFrame("Frame", nil, detail)
  detailHeader:SetPoint("TOPLEFT", detail, "TOPLEFT", 6, -36)
  detailHeader:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -6, -36)
  detailHeader:SetHeight(76)

  local detailHeaderFallback = detailHeader:CreateTexture(nil, "BACKGROUND", nil, -1)
  detailHeaderFallback:SetTexture("Interface\\Buttons\\WHITE8X8")
  detailHeaderFallback:SetVertexColor(0.06, 0.06, 0.07, 0.95)
  detailHeaderFallback:SetAllPoints(detailHeader)

  local detailHeaderBg = detailHeader:CreateTexture(nil, "BACKGROUND")
  if NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(detailHeaderBg, "auctionhouse-background-buy-noncommodities-header", false) then
    detailHeaderBg:SetPoint("TOPLEFT", detailHeader, "TOPLEFT", 3, -2)
    detailHeaderBg:SetPoint("BOTTOMRIGHT", detailHeader, "BOTTOMRIGHT", -3, 2)
  end
  if NE.nineslice and NE.nineslice.AttachInset then
    pcall(NE.nineslice.AttachInset, detailHeader, 0, 0, 0, 0)
  end

  -- Item icon button + hover tooltip. Plain Frame, not CreateTexture, because only frames/buttons
  -- can receive OnEnter/OnLeave on 3.3.5a.
  local detailIconBtn = CreateFrame("Button", nil, detailHeader)
  detailIconBtn:SetSize(54, 54)
  detailIconBtn:SetPoint("LEFT", detailHeader, "LEFT", 12, 0)

  local detailIcon = detailIconBtn:CreateTexture(nil, "ARTWORK")
  detailIcon:SetSize(46, 46)
  detailIcon:SetPoint("CENTER")
  detailIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- Rarity glow -- NOT a ring atlas. A cropped/masked circular ring (the previous
  -- "auctionhouse-itemicon-border-white" atlas) reads as a big blue smear here because circular
  -- icon masking (CreateMaskTexture/AddMaskTexture) doesn't work on this 3.3.5a client (see
  -- core/Portrait.lua) -- there's no way to clip the ring down to just the visible band. Swapped
  -- to the SAME glow technique the professions crafting reagent slots and the bags window use
  -- instead: UI-ActionButton-Border, ADD blend, tinted per quality, oversized by ~35% so its own
  -- built-in transparent margin reaches the icon's edge.
  local detailRing = detailIconBtn:CreateTexture(nil, "OVERLAY")
  detailRing:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  detailRing:SetBlendMode("ADD")
  local detailGlowOver = math.max(8, math.floor(54 * 0.35 + 0.5))
  detailRing:SetPoint("TOPLEFT", detailIconBtn, "TOPLEFT", -detailGlowOver, detailGlowOver)
  detailRing:SetPoint("BOTTOMRIGHT", detailIconBtn, "BOTTOMRIGHT", detailGlowOver, -detailGlowOver)
  detailRing:Hide()

  detailIconBtn:SetScript("OnEnter", function(self)
    local item = detail.CurrentItem
    if not item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shown = item.link and pcall(GameTooltip.SetHyperlink, GameTooltip, item.link)
    if not shown then
      GameTooltip:ClearLines()
      GameTooltip:AddLine(item.name or "", 1, 1, 1)
    end
    GameTooltip:Show()
  end)
  detailIconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local detailName = detailHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  detailName:SetPoint("LEFT", detailIconBtn, "RIGHT", 14, 0)
  detailName:SetPoint("RIGHT", detailHeader, "RIGHT", -14, 0)
  detailName:SetJustifyH("LEFT")

  -- Bid / Buyout footer bar (acts on the currently-selected listing below; OnClick wired further
  -- down once detailSelected exists).
  local detailBar = CreateFrame("Frame", nil, detail)
  detailBar:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 6, 6)
  detailBar:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -6, 6)
  detailBar:SetHeight(22)

  local detailBuyoutBtn = CreateFrame("Button", nil, detailBar, "UIPanelButtonTemplate")
  detailBuyoutBtn:SetSize(110, 22)
  detailBuyoutBtn:SetPoint("RIGHT", detailBar, "RIGHT", 0, 0)
  detailBuyoutBtn:SetText(AUCTION_HOUSE_BUYOUT_BUTTON or BUYOUT or "Buyout")

  local detailBidBtn = CreateFrame("Button", nil, detailBar, "UIPanelButtonTemplate")
  detailBidBtn:SetSize(110, 22)
  detailBidBtn:SetPoint("RIGHT", detailBuyoutBtn, "LEFT", -6, 0)
  detailBidBtn:SetText(AUCTION_HOUSE_BID_BUTTON or BID or "Bid")

  -- Per-auction list.
  local detailList = CreateFrame("Frame", nil, detail)
  detailList:SetPoint("TOPLEFT", detailHeader, "BOTTOMLEFT", 0, -10)
  detailList:SetPoint("BOTTOMRIGHT", detailBar, "TOPRIGHT", 0, 6)

  -- Same always-present-fallback + optional-atlas-overlay pattern as the main results list's own
  -- listFallback/listBg pair above (search for "auctionhouse-background-index").
  local detailListFallback = detailList:CreateTexture(nil, "BACKGROUND")
  detailListFallback:SetTexture("Interface\\Buttons\\WHITE8X8")
  detailListFallback:SetVertexColor(0.02, 0.02, 0.025, 0.92)
  detailListFallback:SetPoint("TOPLEFT", detailList, "TOPLEFT", 3, -22)
  detailListFallback:SetPoint("BOTTOMRIGHT", detailList, "BOTTOMRIGHT", -22, 0)

  local detailListBg = detailList:CreateTexture(nil, "BACKGROUND")
  if NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(detailListBg, "auctionhouse-background-buy-noncommodities-market", false) then
    detailListBg:SetPoint("TOPLEFT", detailList, "TOPLEFT", 3, -22)
    detailListBg:SetPoint("BOTTOMRIGHT", detailList, "BOTTOMRIGHT", -22, 0)
  else
    detailListBg:SetTexture(nil)
  end

  if NE.nineslice and NE.nineslice.AttachInset then
    pcall(NE.nineslice.AttachInset, detailList, 0, -19, -22, 0)
  end

  local detailHeaderStrip = detailList:CreateTexture(nil, "BORDER")
  detailHeaderStrip:SetTexture("Interface\\Buttons\\WHITE8X8")
  detailHeaderStrip:SetVertexColor(0.06, 0.06, 0.07, 0.95)
  detailHeaderStrip:SetPoint("TOPLEFT", detailList, "TOPLEFT", 3, -1)
  detailHeaderStrip:SetPoint("TOPRIGHT", detailList, "TOPRIGHT", -22, -1)
  detailHeaderStrip:SetHeight(21)

  local detailCols = {
    { text = AUCTION_HOUSE_HEADER_CURRENT_BID or BID or "Current Bid", x = 8,   w = 110, just = "RIGHT" },
    { text = AUCTION_HOUSE_HEADER_BUYOUT or BUYOUT or "Buyout",        x = 128, w = 110, just = "RIGHT" },
    { text = AUCTION_HOUSE_HEADER_QUANTITY or "Qty",                   x = 248, w = 50,  just = "RIGHT" },
    { text = AUCTION_HOUSE_HEADER_SELLER or SELLER or "Seller",        x = 308, w = 220, just = "LEFT" },
    { text = AUCTION_HOUSE_HEADER_TIME_LEFT or "Time Left",            x = -80, w = 72,  just = "RIGHT", right = true },
  }
  for i = 1, #detailCols do
    local h = detailCols[i]
    local fs = detailList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", detailList, "TOPLEFT", h.x, -7)
    if h.right then
      fs:ClearAllPoints()
      fs:SetPoint("TOPRIGHT", detailList, "TOPRIGHT", h.x, -7)
    end
    fs:SetWidth(h.w)
    fs:SetJustifyH(h.just)
    fs:SetText(h.text)
  end

  local detailEmpty = detailList:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  detailEmpty:SetPoint("CENTER", detailList, "CENTER", 0, 44)
  detailEmpty:SetTextColor(1, 0.82, 0)

  local DETAIL_ROW_H = 20
  local DETAIL_TOP = -24

  local detailRowWidgets = {}
  local detailRowsHost = CreateFrame("Frame", nil, detailList)
  detailRowsHost:SetPoint("TOPLEFT", detailList, "TOPLEFT", 0, 0)
  detailRowsHost:SetPoint("BOTTOMRIGHT", detailList, "BOTTOMRIGHT", 0, 0)
  detailRowsHost:SetFrameStrata("DIALOG")
  detailRowsHost:SetFrameLevel((detailList:GetFrameLevel() or 1) + 20)

  local detailScroll = CreateFrame("ScrollFrame", "NE_AuctionHouseItemBuyScroll", detailList, "FauxScrollFrameTemplate")
  detailScroll:SetPoint("TOPLEFT", detailList, "TOPLEFT", 2, DETAIL_TOP)
  detailScroll:SetPoint("BOTTOMRIGHT", detailList, "BOTTOMRIGHT", -26, 4)
  if NE.scrollbar and NE.scrollbar.BuildCustom then
    local ok, bar = pcall(NE.scrollbar.BuildCustom, detailScroll, { x = -8 })
    -- BuildCustom's bar defaults to "HIGH" strata, which is correct everywhere else it's used (plain
    -- MEDIUM-strata list hosts), but `detail` (this overlay's root) is deliberately "DIALOG" strata
    -- so it draws above the underlying browse results list -- every descendant frame that doesn't
    -- set its own strata (detailList, detailListBg/detailRowsHost) inherits that DIALOG level, which
    -- then sits ABOVE the scrollbar's HIGH strata and hides it behind the list background. Force the
    -- bar to match this overlay's own strata and sit above its row buttons.
    if ok and bar then
      bar:SetFrameStrata("DIALOG")
      bar:SetFrameLevel((detailRowsHost:GetFrameLevel() or 1) + 10)
      -- Same post-hoc strata promotion the arrow buttons need everywhere else this pattern is used.
      if bar._upBtn then bar._upBtn:SetFrameStrata("DIALOG"); bar._upBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
      if bar._downBtn then bar._downBtn:SetFrameStrata("DIALOG"); bar._downBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
    end
  end

  local detailRowsData = {}
  local detailSelected = nil
  local detailAutoResyncDone = false

  -- Fill the entire scroll viewport instead of a hardcoded row count -- previously a fixed 8 rows
  -- left most of the panel's actual (much taller) height as dead space below the last row.
  local function detailVisibleRows()
    local h = detailScroll:GetHeight() or 0
    return math.max(1, math.floor(h / (DETAIL_ROW_H + 1)))
  end

  -- GetAuctionItemTimeLeft is an enum (1-4) on this client; handle a raw seconds value too, just
  -- in case.
  local function detailTimeLeftText(v)
    if not v then return "" end
    local TL = {
      [1] = AUCTION_TIME_LEFT1 or "Short", [2] = AUCTION_TIME_LEFT2 or "Medium",
      [3] = AUCTION_TIME_LEFT3 or "Long",  [4] = AUCTION_TIME_LEFT4 or "Very Long",
    }
    if v >= 1 and v <= 4 and TL[v] then return TL[v] end
    return SecondsToTime and SecondsToTime(v) or tostring(v)
  end

  local function updateDetailActions()
    local r = detailSelected
    local canBuyout = r and r.buyout and r.buyout > 0
    local canBid = r and r.nextBid and r.nextBid > 0
    detailBuyoutBtn:SetEnabled(canBuyout and true or false)
    detailBidBtn:SetEnabled(canBid and true or false)
  end

  local function ensureDetailRow(i)
    local row = detailRowWidgets[i]
    if row then return row end

    row = CreateFrame("Button", nil, detailRowsHost)
    row:SetFrameStrata("DIALOG")
    row:SetHeight(DETAIL_ROW_H)
    row:SetFrameLevel((detailList:GetFrameLevel() or 1) + 10)
    if i == 1 then
      row:SetPoint("TOPLEFT", detailList, "TOPLEFT", 6, DETAIL_TOP)
      row:SetPoint("TOPRIGHT", detailList, "TOPRIGHT", -30, DETAIL_TOP)
    else
      row:SetPoint("TOPLEFT", detailRowWidgets[i - 1], "BOTTOMLEFT", 0, -1)
      row:SetPoint("TOPRIGHT", detailRowWidgets[i - 1], "BOTTOMRIGHT", 0, -1)
    end

    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    rowBg:SetAllPoints(row)
    rowBg:SetVertexColor(0.07, 0.07, 0.08, (i % 2 == 0) and 0.30 or 0.20)
    row.Bg = rowBg

    local sel = row:CreateTexture(nil, "ARTWORK")
    sel:SetTexture("Interface\\Buttons\\WHITE8X8")
    sel:SetVertexColor(1, 0.82, 0, 0.25)
    sel:SetAllPoints(row)
    sel:Hide()
    row.Sel = sel

    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local hl = row:GetHighlightTexture()
    if hl then
      hl:SetVertexColor(1, 0.82, 0, 0.12)
      hl:SetBlendMode("ADD")
    end

    local bid = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bid:SetPoint("LEFT", row, "LEFT", 0, 0)
    bid:SetWidth(118)
    bid:SetJustifyH("RIGHT")
    row.Bid = bid

    local buyout = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    buyout:SetPoint("LEFT", row, "LEFT", 120, 0)
    buyout:SetWidth(118)
    buyout:SetJustifyH("RIGHT")
    row.Buyout = buyout

    local qty = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qty:SetPoint("LEFT", row, "LEFT", 248, 0)
    qty:SetWidth(50)
    qty:SetJustifyH("RIGHT")
    row.Qty = qty

    local seller = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    seller:SetPoint("LEFT", row, "LEFT", 308, 0)
    seller:SetPoint("RIGHT", row, "RIGHT", -84, 0)
    seller:SetJustifyH("LEFT")
    row.Seller = seller

    local time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    time:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    time:SetWidth(76)
    time:SetJustifyH("RIGHT")
    row.Time = time

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
      if IsModifiedClick and IsModifiedClick("DRESSUP") and self._data and self._data.index then
        local link = GetAuctionItemLink and GetAuctionItemLink("list", self._data.index)
        if link then AH.DressUpItem(link) end
        return
      end
      detailSelected = self._data
      for _, rr in ipairs(detailRowWidgets) do
        if rr.Sel then rr.Sel:SetShown(rr._data ~= nil and rr._data == detailSelected) end
      end
      updateDetailActions()
    end)

    detailRowWidgets[i] = row
    return row
  end

  local function readDetailPage()
    local out = {}
    local batch = 0
    if type(GetNumAuctionItems) == "function" then
      batch = select(1, GetNumAuctionItems("list")) or 0
    end
    -- This client's QueryAuctionItems does a SUBSTRING search, not an exact-name match (there's no
    -- dedicated exact-match argument in its signature) -- searching "Linen Cloth" also returns
    -- "Bolt of Linen Cloth". Auctionator and the default 3.3.5a AH UI both filter the requeried
    -- page down to an EXACT name match client-side before listing/allowing a purchase; do the same
    -- here, or a click on "Linen Cloth" could end up placing a bid on a totally different listing
    -- that merely shares the substring.
    local wantName = detail.CurrentItem and detail.CurrentItem.name
    for i = 1, batch do
      -- Same 13-value field order as captureListRows above.
      local name, _, count, _, _, _, minBid, minInc, buyout, bidAmt, _, owner = GetAuctionItemInfo("list", i)
      if name and (not wantName or name == wantName) then
        local cur = (bidAmt and bidAmt > 0) and bidAmt or minBid
        local tl = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("list", i)
        out[#out + 1] = {
          index = i, count = count or 1,
          curBid = cur, nextBid = (cur or 0) + (minInc or 0),
          buyout = buyout, owner = owner,
          timeText = detailTimeLeftText(tl),
        }
      end
    end
    return out
  end

  refreshDetailRows = function()
    detailRowsData = readDetailPage()
    local drawCount = #detailRowsData
    local visibleRows = detailVisibleRows()
    if FauxScrollFrame_Update then
      FauxScrollFrame_Update(detailScroll, drawCount, visibleRows, DETAIL_ROW_H + 1)
    end
    local offset = (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(detailScroll)) or 0

    if drawCount > 0 then
      detailEmpty:Hide()
    else
      detailEmpty:Show()
      detailEmpty:SetText("No listings.")
    end
    detailCount:SetText(tostring(drawCount))

    -- Selection survives a refresh only if the same auction index is still present -- buying an
    -- auction removes it from the next update, so drop a stale selection instead of leaving the
    -- footer buttons pointed at a listing that no longer exists.
    if detailSelected then
      local stillThere = nil
      for i = 1, #detailRowsData do
        if detailRowsData[i].index == detailSelected.index then
          stillThere = detailRowsData[i]
          break
        end
      end
      detailSelected = stillThere
    end

    for i = 1, visibleRows do
      local row = ensureDetailRow(i)
      local data = detailRowsData[i + offset]
      if data then
        row._data = data
        row.Bid:SetText(moneyText(data.curBid or 0))
        row.Buyout:SetText(moneyText(data.buyout or 0))
        row.Qty:SetText(tostring(data.count or 1))
        row.Seller:SetText(data.owner or "")
        row.Time:SetText(data.timeText or "")
        if row.Sel then row.Sel:SetShown(data == detailSelected) end
        row:Show()
      else
        row._data = nil
        if row.Sel then row.Sel:Hide() end
        row:Hide()
      end
    end
    -- Hide any previously-built rows beyond the current viewport (only relevant if the panel's
    -- effective height ever shrinks between refreshes; harmless no-op otherwise).
    for i = visibleRows + 1, #detailRowWidgets do
      local row = detailRowWidgets[i]
      row._data = nil
      if row.Sel then row.Sel:Hide() end
      row:Hide()
    end
    updateDetailActions()

    -- detailVisibleRows() reads detailScroll:GetHeight(), but the very first refresh after
    -- openItemDetail's detail:Show() can land before this branch of the anchor chain has settled
    -- (same class of stale-zero-size read BuildCustom's own first sync() guards against below) --
    -- that undercounts the viewport, makes FauxScrollFrame_Update think there's more to scroll than
    -- there really is, and leaves the scrollbar/arrows stuck showing even though every row fits.
    -- One deferred re-run per item-open with a settled layout self-corrects it. Flag is set BEFORE
    -- scheduling (not inside the callback) so the callback's own call to refreshDetailRows sees it
    -- already true and doesn't reschedule itself forever; openItemDetail resets it per new item.
    if not detailAutoResyncDone and C_Timer and C_Timer.After then
      detailAutoResyncDone = true
      C_Timer.After(0, function()
        if activeQuery == "itembuy" then
          pcall(refreshDetailRows)
        end
      end)
    end
  end

  detailScroll:SetScript("OnVerticalScroll", function(self, offset)
    if FauxScrollFrame_OnVerticalScroll then
      FauxScrollFrame_OnVerticalScroll(self, offset, DETAIL_ROW_H + 1, refreshDetailRows)
    end
  end)

  detailBuyoutBtn:SetScript("OnClick", function()
    local r = detailSelected
    if not (r and r.buyout and r.buyout > 0) then return end
    StaticPopup_Show("NE_AH_BROWSE_BUYOUT", moneyText(r.buyout), nil, { index = r.index, price = r.buyout })
  end)
  detailBidBtn:SetScript("OnClick", function()
    local r = detailSelected
    if not (r and r.nextBid and r.nextBid > 0) then return end
    StaticPopup_Show("NE_AH_BROWSE_BID", moneyText(r.nextBid), nil, { index = r.index, price = r.nextBid })
  end)

  detailBack:SetScript("OnClick", function()
    activeQuery = "browse"
    detail:Hide()
    setBrowseResultsShown(true)
  end)
  detailRefresh:SetScript("OnClick", function()
    if detail.CurrentItem and openItemDetail then openItemDetail(detail.CurrentItem) end
  end)

  openItemDetail = function(data)
    if not data or not data.name then return end
    detail.CurrentItem = data
    activeQuery = "itembuy"
    detailSelected = nil
    detailRowsData = {}
    detailAutoResyncDone = false

    detailIcon:SetTexture(data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    detailName:SetText(data.name)
    if data.quality and data.quality > 1 and GetItemQualityColor then
      local r, g, b = GetItemQualityColor(data.quality)
      detailName:SetTextColor(r, g, b)
      detailRing:SetVertexColor(r, g, b)
      detailRing:Show()
    else
      detailName:SetTextColor(1, 1, 1)
      detailRing:Hide()
    end
    detailCount:SetText("")
    detailEmpty:SetText("Searching...")
    detailEmpty:Show()
    updateDetailActions()
    setBrowseResultsShown(false)
    detail:Show()

    if not (CanSendAuctionQuery and CanSendAuctionQuery("list")) then
      detailEmpty:SetText("Auction query is throttled. Try again in a moment.")
      return
    end
    -- Re-query scoped to this exact item name. THIS server's QueryAuctionItems signature (per its
    -- own bundled APIDocumentation) has no dedicated exact-match flag the way some other clients'
    -- do -- passing the full item name as the search text returns just this item barring rare
    -- substring collisions (e.g. "Belt" would also match "Belt of Deep Shadow").
    local ok, err = pcall(QueryAuctionItems, data.name, 0, 0, 0, 0, 0, 0, false, 0, false)
    if not ok and NE.Log then
      NE.Log("AH", "ItemBuy QueryAuctionItems error: " .. tostring(err))
    end
  end

  local categories = CreateFrame("Frame", nil, pane)
  categories:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, -73)
  -- Height 437, not 438 -- anchored from the TOP (fixed height, unlike every other panel here which
  -- anchors its BOTTOM at pane+27), so a hardcoded 438 landed its bottom 1px below the shared
  -- pane+27 divider line the results/detail lists and the Auctions tab's panels all sit on.
  categories:SetSize(168, 437)
  pane.Categories = categories

  local catBg = categories:CreateTexture(nil, "ARTWORK")
  if NE.tex and NE.tex.SetAtlas then
    NE.tex.SetAtlas(catBg, "auctionhouse-background-categories", false)
  end
  catBg:SetPoint("TOPLEFT", categories, "TOPLEFT", 3, -3)
  catBg:SetSize(138, 433)

  if NE.nineslice and NE.nineslice.AttachInset then
    pcall(NE.nineslice.AttachInset, categories, 0, 0, 0, 0)
  end

  local ok, catList = pcall(buildCategoryList, categories)
  if ok then
    pane.CategoryList = catList
  else
    pane.CategoryList = nil
  end

  return pane
end
