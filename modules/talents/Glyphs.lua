-- DragonUI_NewEra/modules/talents/Glyphs.lua — side popout for 3.3.5a glyph sockets.
--
-- Adds a glyph panel attached to the right side of NE_TalentFrame. It follows the currently
-- viewed talent group (spec 1/spec 2), so switching spec tabs immediately shows that spec's
-- major/minor glyph sockets.

local NE = DragonUI_NewEra
local T  = NE.talents or {}
NE.talents = T

local ROW_H = 28
local ROW_GAP = 2
local MAJOR = _G.GLYPH_TYPE_MAJOR or 1
local MINOR = _G.GLYPH_TYPE_MINOR or 2

local panel
local toggle
T._glyphCollapsed = (T._glyphCollapsed == nil) and false or T._glyphCollapsed

local function setSolid(tex, r, g, b, a)
  if not tex then return end
  if tex.SetColorTexture then
    tex:SetColorTexture(r, g, b, a)
  else
    tex:SetTexture(r, g, b, a)
  end
end

local function groupLabel(group)
  if group == 2 then return "Secondary" end
  return "Primary"
end

local function getGlyphLink(socket, group)
  if not GetGlyphLink then return nil end
  local ok, link = pcall(GetGlyphLink, socket, group)
  if ok and link and link ~= "" then return link end
  ok, link = pcall(GetGlyphLink, socket)
  if ok and link and link ~= "" then return link end
  return nil
end

local function getSocketInfo(socket, group)
  if not GetGlyphSocketInfo then return nil end
  local enabled, glyphType, r3, r4, r5 = GetGlyphSocketInfo(socket, group)

  -- 3.3.5a can return 4 values: enabled, glyphType, glyphSpellID, icon.
  -- Later clients return at least 5 values where the third is tooltip/index.
  local glyphSpellID, icon
  if (type(r4) == "string" or type(r4) == "number") and r5 == nil then
    glyphSpellID = r3
    icon = r4
  else
    glyphSpellID = r4
    icon = r5
  end

  return {
    socket = socket,
    enabled = enabled,
    glyphType = glyphType,
    glyphSpellID = glyphSpellID,
    icon = icon,
    link = getGlyphLink(socket, group),
  }
end

local function styleRow(row)
  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  setSolid(bg, 0.07, 0.07, 0.08, 0.92)
  row.bg = bg

  local border = row:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", 0, 0)
  border:SetPoint("BOTTOMRIGHT", 0, 0)
  setSolid(border, 0.24, 0.24, 0.27, 1)
  border:SetTexCoord(0, 1, 0, 1)
  row.border = border

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 4, 0)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 4)
  row.name:SetJustifyH("LEFT")

  row.state = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.state:SetPoint("LEFT", row.icon, "RIGHT", 6, -6)
  row.state:SetJustifyH("LEFT")

  row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.slot:SetPoint("RIGHT", -6, 0)
end

local function wireRowTooltip(row)
  row:SetScript("OnEnter", function(self)
    local info = self._glyphInfo
    if not info then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local shown = false
    if GameTooltip.SetGlyph and info.socket then
      local ok = pcall(GameTooltip.SetGlyph, GameTooltip, info.socket, panel and panel._group or 1)
      shown = ok and true or false
    end
    if (not shown) and info.link and GameTooltip.SetHyperlink then
      local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, info.link)
      shown = ok and true or false
    end
    if not shown then
      GameTooltip:SetText(self._fallbackName or "Glyph Socket", 1, 1, 1)
      if self._fallbackState then
        GameTooltip:AddLine(self._fallbackState, 0.8, 0.8, 0.8, true)
      end
    end
    GameTooltip:Show()
  end)

  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function applyRow(row, info, slotLabel)
  row._glyphInfo = info
  row.slot:SetText(slotLabel or "")

  if not info then
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.name:SetText("Unavailable")
    row.state:SetText("")
    row._fallbackName = "Glyph Socket"
    row._fallbackState = nil
    row:SetAlpha(0.5)
    row:EnableMouse(false)
    return
  end

  local spellName, _, spellIcon = nil, nil, nil
  if info.glyphSpellID and info.glyphSpellID > 0 and GetSpellInfo then
    spellName, _, spellIcon = GetSpellInfo(info.glyphSpellID)
  end

  row.icon:SetTexture(spellIcon or info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

  if not info.enabled then
    row.name:SetText("Locked socket")
    row.state:SetText("Requires higher level")
    row.state:SetTextColor(0.65, 0.65, 0.65)
    row:SetAlpha(0.55)
    row:EnableMouse(false)
    row._fallbackName = "Locked socket"
    row._fallbackState = "Requires higher level"
    return
  end

  row:SetAlpha(1)
  row:EnableMouse(true)

  local hasGlyph = (type(info.glyphSpellID) == "number" and info.glyphSpellID > 0) or (info.link ~= nil)
  if hasGlyph then
    row.name:SetText(spellName or "Glyph")
    row.state:SetText("Equipped")
    row.state:SetTextColor(0.22, 0.95, 0.22)
    row._fallbackName = spellName or "Glyph"
    row._fallbackState = "Equipped"
  else
    row.name:SetText("Empty socket")
    row.state:SetText("No glyph inserted")
    row.state:SetTextColor(0.86, 0.78, 0.38)
    row._fallbackName = "Empty socket"
    row._fallbackState = "No glyph inserted"
  end
end

function T.GlyphsRefresh()
  if not panel then return end

  local group = T._viewGroup or T._activeGroup or 1
  panel._group = group
  panel.spec:SetText(groupLabel(group) .. " Spec")

  local numSockets = (GetNumGlyphSockets and GetNumGlyphSockets()) or 0
  local major, minor = {}, {}

  for socket = 1, numSockets do
    local info = getSocketInfo(socket, group)
    if info then
      if info.glyphType == MINOR then
        minor[#minor + 1] = info
      else
        major[#major + 1] = info
      end
    end
  end

  for i = 1, 3 do
    applyRow(panel.majorRows[i], major[i], "M" .. i)
    applyRow(panel.minorRows[i], minor[i], "m" .. i)
  end
end

local function buildPanel()
  if panel then return panel end

  local host = T.frame
  if not host then return nil end

  panel = CreateFrame("Frame", "NE_TalentGlyphPopout", host)
  panel:SetSize(224, 296)
  panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 12, -80)
  panel:SetFrameStrata("HIGH")
  panel:EnableMouse(true)

  if panel.SetBackdrop then
    panel:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
  end

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -14)
  title:SetText("Glyphs")

  panel.spec = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.spec:SetPoint("TOPRIGHT", -14, -16)
  panel.spec:SetText("Primary Spec")

  local majorHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  majorHeader:SetPoint("TOPLEFT", 14, -40)
  majorHeader:SetText("Major")

  panel.majorRows = {}
  for i = 1, 3 do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(196, ROW_H)
    row:SetPoint("TOPLEFT", 14, -62 - ((i - 1) * (ROW_H + ROW_GAP)))
    styleRow(row)
    wireRowTooltip(row)
    panel.majorRows[i] = row
  end

  local minorHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  minorHeader:SetPoint("TOPLEFT", 14, -170)
  minorHeader:SetText("Minor")

  panel.minorRows = {}
  for i = 1, 3 do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(196, ROW_H)
    row:SetPoint("TOPLEFT", 14, -192 - ((i - 1) * (ROW_H + ROW_GAP)))
    styleRow(row)
    wireRowTooltip(row)
    panel.minorRows[i] = row
  end

  return panel
end

local function updateToggleLabel()
  if not toggle then return end
  toggle:SetText("Glyphs")
end

local function ensureToggle()
  if toggle then return toggle end
  local host = T.frame
  if not host then return nil end

  toggle = CreateFrame("Button", "NE_TalentGlyphToggle", host, "UIPanelButtonTemplate")
  toggle:SetSize(96, 26)
  if host._loBtn then
    toggle:SetPoint("LEFT", host._loBtn, "RIGHT", 8, 0)
  else
    toggle:SetPoint("BOTTOM", host, "BOTTOM", 112, ((T.FRAME and T.FRAME.CHROME_B) or 0) + 27)
  end
  toggle:SetScript("OnClick", function()
    local p = buildPanel()
    if not p then return end
    if p:IsShown() then
      p:Hide()
      T._glyphCollapsed = true
    else
      p:Show()
      T._glyphCollapsed = false
    end
    updateToggleLabel()
    if p:IsShown() then T.GlyphsRefresh() end
  end)

  return toggle
end

local function ensureUI()
  local host = T.frame
  if not host then return end

  ensureToggle()
  buildPanel()
  if panel then
    if T._glyphCollapsed then panel:Hide() else panel:Show() end
  end
  updateToggleLabel()
end

local function hookPopulate()
  if T._glyphPopulateHooked then return end
  local orig = T.Populate
  if type(orig) ~= "function" then return end

  T._glyphPopulateHooked = true
  T.Populate = function(...)
    local r = orig(...)
    ensureUI()
    T.GlyphsRefresh()
    updateToggleLabel()
    return r
  end
end

local function boot()
  local f = T.frame
  if not f then return end

  f:HookScript("OnHide", function()
    if panel then panel:Hide() end
    updateToggleLabel()
  end)

  local ev = CreateFrame("Frame")
  for _, e in ipairs({
    "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED",
    "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
  }) do
    pcall(function() ev:RegisterEvent(e) end)
  end
  ev:SetScript("OnEvent", function()
    if f and f:IsShown() then T.GlyphsRefresh() end
  end)
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
  hookPopulate()
  boot()
  init:UnregisterEvent("PLAYER_LOGIN")
end)
