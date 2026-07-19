-- DragonUI_NewEra/modules/encounterjournal/NavBar.lua — breadcrumb navbar + search box.
--
-- DOWNPORT of NewEra/EncounterJournal/NavBar.lua. NewEra reuses Era's shipped NavBarTemplate
-- via its Core NE.navbar wrapper; neither exists on 3.3.5a, so the breadcrumb is REBUILT as a
-- flat text-button trail: [Home] > [Instance ▾] > [Boss]. Same behaviours:
--   * Home            → back to the instance-select grid (NE.ej.ShowList)
--   * Instance crumb  → back to the instance overview (clears the selected boss)
--   * Instance ▾      → boss-jump menu (EasyMenu — native 3.3.5a)
--   * Boss crumb      → re-shows that boss
--   * Search box      → filters the instance grid by name (SearchBoxTemplate via ClassicAPI,
--                       pcall'd with an InputBoxTemplate fallback)
--
-- retail anchors (EJ.xml:1209-1213, 1196-1206): navBar TOPLEFT(61,-22) 500×34;
-- searchBox TOPRIGHT(-10,-32) 210×20.

local NE = DragonUI_NewEra
if not NE then return end

NE.ej = NE.ej or {}

-- Dropdown contents for the instance breadcrumb button: jump to a boss.
local function bossJumpList()
  local f = NE.ej.frame
  local inst = f and f._currentInstance
  local list = {}
  if inst and inst.encounters then
    for _, enc in ipairs(inst.encounters) do
      local e = enc
      list[#list + 1] = {
        text = e.name,
        func = function() if NE.ej.ShowBoss then NE.ej.ShowBoss(e) end end,
        notCheckable = true,
      }
    end
  end
  return list
end

-- Shared context menu host for the ▾ boss-jump (EasyMenu needs a named dropdown frame).
local menuHost

-- One crumb: flat gold text button with hover brighten; optional ▾ arrow with its own click.
local function acquireCrumb(navBar, i)
  local c = navBar.crumbs[i]
  if c then return c end
  c = CreateFrame("Button", nil, navBar)
  c:SetHeight(24)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  c.text:SetPoint("LEFT", c, "LEFT", 4, 0)
  c:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 0.6) end)
  c:SetScript("OnLeave", function(self)
    if self._isLast then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(1, 0.82, 0) end
  end)
  -- ▾ arrow (shown only for crumbs carrying a listFunc)
  c.arrow = CreateFrame("Button", nil, navBar)
  c.arrow:SetSize(18, 24)
  c.arrow.tex = c.arrow:CreateTexture(nil, "ARTWORK")
  c.arrow.tex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  c.arrow.tex:SetSize(12, 12)
  c.arrow.tex:SetPoint("CENTER", c.arrow, "CENTER", 0, 0)
  -- DOWNPORT: no Texture:SetRotation on 3.3.5a — rotate the right-pointing arrow 90° CW to
  -- point down via the 8-arg SetTexCoord corner mapping (UL←LL, LL←LR, UR←UL, LR←UR).
  c.arrow.tex:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
  c.arrow:SetScript("OnClick", function(self)
    if not self._listFunc then return end
    if not menuHost then
      menuHost = CreateFrame("Frame", "NE_EJNavBarMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local list = self._listFunc()
    if #list > 0 and EasyMenu then
      EasyMenu(list, menuHost, self, 0, 0, "MENU")
    end
  end)
  -- separator BEFORE this crumb (hidden for the first)
  c.sep = navBar:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  c.sep:SetText(">")
  navBar.crumbs[i] = c
  return c
end

function NE.ej.BuildNavBar(f)
  if f._neNavBar then return f._neNavBar end

  local navBar = CreateFrame("Frame", "NE_EncounterJournalNavBar", f)
  navBar:SetSize(500, 34)
  navBar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -24)
  local lvl = (f.NineSlice and f.NineSlice:GetFrameLevel() or f:GetFrameLevel()) + 6
  navBar:SetFrameLevel(lvl)
  navBar.crumbs = {}
  f._neNavBar = navBar

  -- Search box (filters the instance grid). pcall the ClassicAPI template; fall back to a
  -- plain InputBoxTemplate if a future build renames it — the journal works without search.
  local ok, sb = pcall(CreateFrame, "EditBox", "NE_EncounterJournalSearchBox", f, "SearchBoxTemplate")
  if not (ok and sb) then
    ok, sb = pcall(CreateFrame, "EditBox", "NE_EncounterJournalSearchBox", f, "InputBoxTemplate")
    if ok and sb then sb:SetAutoFocus(false) end
  end
  if ok and sb then
    sb:SetSize(180, 20)
    sb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -32)
    sb:SetFrameLevel(lvl)
    sb:HookScript("OnTextChanged", function(self)
      if NE.ej.FilterGrid then NE.ej.FilterGrid(self:GetText()) end
    end)
    sb:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f._neSearchBox = sb
  end
  return navBar
end

-- Rebuild the breadcrumb trail. Entry shape mirrors NewEra's NE.navbar hierarchy:
-- { name, OnClick, listFunc }. Home is implicit (index 0).
function NE.ej.RefreshNavBar()
  local f = NE.ej.frame
  local navBar = f and f._neNavBar
  if not navBar then return end

  local hierarchy = {}
  local inst = f._currentInstance
  if inst then
    hierarchy[#hierarchy + 1] = {
      name     = inst.name,
      OnClick  = function() if NE.ej.ShowInstance then NE.ej.ShowInstance(inst) end end,
      listFunc = bossJumpList,   -- the ▾ boss-jump dropdown
    }
  end
  local boss = f._currentBoss
  if boss then
    hierarchy[#hierarchy + 1] = {
      name    = boss.name,
      OnClick = function() if NE.ej.ShowBoss then NE.ej.ShowBoss(boss) end end,
    }
  end

  -- crumb 1 is always Home; then the hierarchy.
  local entries = { { name = HOME or "Home", OnClick = function() if NE.ej.ShowList then NE.ej.ShowList() end end } }
  for _, e in ipairs(hierarchy) do entries[#entries + 1] = e end

  local prev
  for i, e in ipairs(entries) do
    local c = acquireCrumb(navBar, i)
    c.text:SetText(e.name or "?")
    c:SetWidth((c.text:GetStringWidth() or 40) + 8)
    c._isLast = (i == #entries)
    c.text:SetTextColor(c._isLast and 1 or 1, c._isLast and 1 or 0.82, c._isLast and 1 or 0)
    c:SetScript("OnClick", function() if e.OnClick then e.OnClick() end end)
    c:ClearAllPoints()
    if prev then
      c.sep:Show()
      c.sep:ClearAllPoints()
      c.sep:SetPoint("LEFT", prev, "RIGHT", 2, 0)
      c:SetPoint("LEFT", c.sep, "RIGHT", 2, 0)
    else
      c.sep:Hide()
      c:SetPoint("LEFT", navBar, "LEFT", 0, 0)
    end
    if e.listFunc then
      c.arrow._listFunc = e.listFunc
      c.arrow:ClearAllPoints()
      c.arrow:SetPoint("LEFT", c, "RIGHT", -2, 0)
      c.arrow:Show()
      prev = c.arrow
    else
      c.arrow:Hide()
      prev = c
    end
    c:Show()
  end
  for i = #entries + 1, #navBar.crumbs do
    navBar.crumbs[i]:Hide()
    navBar.crumbs[i].arrow:Hide()
    navBar.crumbs[i].sep:Hide()
  end
end
