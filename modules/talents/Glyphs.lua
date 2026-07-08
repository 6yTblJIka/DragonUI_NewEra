-- DragonUI_NewEra/modules/talents/Glyphs.lua — glyph tab renderer for 3.3.5a.
--
-- This file owns the reusable glyph view that lives inside NE_TalentFrame. The talents tab
-- strip toggles the view on/off; Behavior.lua keeps it refreshed from live glyph/spec events.

local NE = DragonUI_NewEra
local T  = NE.talents or {}
NE.talents = T

local SOCKET_COUNT = 6

local root
local panes = {}
local refreshDriver

T._glyphActive = (T._glyphActive ~= nil) and T._glyphActive or false

local function queueGlyphRefresh(passes)
  passes = tonumber(passes) or 1
  if passes < 1 then return end
  if not refreshDriver then
    refreshDriver = CreateFrame("Frame")
    refreshDriver:Hide()
  end
  refreshDriver._remaining = math.max(refreshDriver._remaining or 0, passes)
  refreshDriver:SetScript("OnUpdate", function(self)
    self._remaining = (self._remaining or 1) - 1
    if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
    if T.GlyphsApplyPaneVisibility then pcall(T.GlyphsApplyPaneVisibility) end
    if self._remaining <= 0 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    end
  end)
  refreshDriver:Show()
end

StaticPopupDialogs = StaticPopupDialogs or {}
if not StaticPopupDialogs["NE_GLYPH_REMOVE_CONFIRM"] then
  StaticPopupDialogs["NE_GLYPH_REMOVE_CONFIRM"] = {
    text = "Remove this glyph?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(self, data)
      local button = data and data.button
      local info = button and button._glyphInfo
      if not (info and info.socket) then return end
      if type(_G.RemoveGlyphFromSocket) == "function" then
        local ok = pcall(_G.RemoveGlyphFromSocket, info.socket)
        if ok then
          queueGlyphRefresh(3)
        end
      end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
  }
end

local function setAtlas(tex, atlas, fallbackTexture)
  if tex and NE.tex and NE.tex.SetAtlas and atlas then
    if NE.tex.SetAtlas(tex, atlas, true) then return true end
  end
  if tex and fallbackTexture and tex.SetTexture then
    tex:SetTexture(fallbackTexture)
  end
  return false
end

local function applyPaneBackground(pane)
  if not (pane and pane.bg and pane._bgNick) then return end

  local nick = pane._bgNick
  local a = NE.tex and NE.tex.atlases and NE.tex.atlases[nick:lower()]
  if not a then
    if NE.tex and NE.tex.SetAtlas then
      NE.tex.SetAtlas(pane.bg, nick, false)
    end
    pane.bg:SetTexCoord(0, 1, 0, 1)
    return
  end

  if NE.tex and NE.tex.SetAtlas then
    NE.tex.SetAtlas(pane.bg, nick, false)
  end

  local paneW = pane:GetWidth() or 0
  local paneH = pane:GetHeight() or 0
  if paneW <= 0 or paneH <= 0 then return end

  local destA, srcA = paneW / paneH, a.width / a.height
  local left, right, top, bottom = a.left, a.right, a.top, a.bottom
  if destA > srcA then
    bottom = top + (bottom - top) * (srcA / destA)
  else
    left = right - (right - left) * (destA / srcA)
  end
  if pane._bgFlip then
    left, right = right, left
  end
  pane.bg:SetTexCoord(left, right, top, bottom)
end

local function specBackgroundNick(group)
  local bestTab, bestSpent = 1, -1
  local tabCount = (GetNumTalentTabs and GetNumTalentTabs(false, false)) or 0
  for tab = 1, tabCount do
    local spent = 0
    local numTalents = (GetNumTalents and GetNumTalents(tab, false, false)) or 0
    if GetTalentInfo then
      for i = 1, numTalents do
        local _, _, _, _, rank, _, _, _, previewRank = GetTalentInfo(tab, i, false, false, group)
        spent = spent + (previewRank or rank or 0)
      end
    else
      local _, _, tabSpent = GetTalentTabInfo and GetTalentTabInfo(tab, false, false, group)
      spent = tabSpent or 0
    end
    if spent > bestSpent then
      bestSpent = spent
      bestTab = tab
    end
  end
  return T.BackgroundNick and T.BackgroundNick(bestTab) or nil
end

local function specTabLabel(group)
  local text = _G["NE_TalentSpecTab" .. tostring(group) .. "Text"]
  if text and text.GetText then
    local label = text:GetText()
    if label and label ~= "" then return label end
  end
  local tab = _G["NE_TalentSpecTab" .. tostring(group)]
  if tab and tab.GetText then
    local label = tab:GetText()
    if label and label ~= "" then return label end
  end
  return (group == 2) and "Secondary" or "Primary"
end

local function groupStatus(group)
  return specTabLabel(group)
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
    enabled = enabled and true or false,
    glyphType = glyphType,
    glyphSpellID = glyphSpellID,
    icon = icon,
    link = getGlyphLink(socket, group),
  }
end

local function emptyGlyphIcon(glyphType)
  if glyphType == 2 then
    return "Interface\\Icons\\INV_Glyph_MinorGlyph"
  end
  return "Interface\\Icons\\INV_Glyph_MajorGlyph"
end

local function tooltipForSocket(button)
  local info = button._glyphInfo
  if not info then return end

  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  local shown = false
  if GameTooltip.SetGlyph and info.socket then
    local ok = pcall(GameTooltip.SetGlyph, GameTooltip, info.socket, button._group or 1)
    shown = ok and true or false
  end
  if (not shown) and info.link and GameTooltip.SetHyperlink then
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, info.link)
    shown = ok and true or false
  end
  if not shown then
    GameTooltip:SetText(button._fallbackName or "Glyph Socket", 1, 1, 1)
    if button._fallbackState then
      GameTooltip:AddLine(button._fallbackState, 0.8, 0.8, 0.8, true)
    end
  end
  GameTooltip:Show()
end

local function clickStockGlyphSocket(button, mouseButton)
  local info = button and button._glyphInfo
  if not (info and info.socket and button._activePane) then return end

  if mouseButton == "RightButton" and type(_G.IsShiftKeyDown) == "function" and _G.IsShiftKeyDown() then
    if type(_G.StaticPopup_Show) == "function" then
      _G.StaticPopup_Show("NE_GLYPH_REMOVE_CONFIRM", nil, nil, { button = button })
      return
    end
  end

  if not ((NE.IsAddOnLoaded and NE.IsAddOnLoaded("Blizzard_GlyphUI")) or _G.GlyphFrame) then
    if type(_G.LoadAddOn) == "function" then
      pcall(_G.LoadAddOn, "Blizzard_GlyphUI")
    end
  end

  local stock = _G["GlyphFrameGlyph" .. tostring(info.socket)]
  if not stock then return end

  if stock.Click then
    stock:Click(mouseButton or "LeftButton")
    return
  end

  local onClick = stock.GetScript and stock:GetScript("OnClick")
  if type(onClick) == "function" then
    onClick(stock, mouseButton or "LeftButton")
    return
  end
end

local function applyBorderTint(button, hovered)
  if not (button and button.Border) then return end
  local tint = (hovered and button._hoverTint) or button._borderTint
  if not tint then return end
  button.Border:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 1)
end

local function buildSocket(parent, index)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(64, 64)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  b.Border = b:CreateTexture(nil, "ARTWORK")
  b.Border:SetSize(64, 64)
  b.Border:SetPoint("CENTER")

  b.Glow = b:CreateTexture(nil, "ARTWORK", nil, -1)
  b.Glow:SetSize(82, 82)
  b.Glow:SetPoint("CENTER")
  b.Glow:SetBlendMode("ADD")
  b.Glow:Hide()

  b.Icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
  b.Icon:SetSize(34, 34)
  b.Icon:SetPoint("CENTER")
  b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if b.Icon.SetVertexColor then b.Icon:SetVertexColor(1, 1, 1, 1) end

  b.IconTint = b:CreateTexture(nil, "ARTWORK", nil, 2)
  b.IconTint:SetSize(34, 34)
  b.IconTint:SetPoint("CENTER")
  b.IconTint:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.IconTint:SetBlendMode("ADD")
  b.IconTint:SetVertexColor(1.0, 0.84, 0.28)
  b.IconTint:SetAlpha(0.55)
  b.IconTint:Hide()

  b.Plus = b:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  b.Plus:SetPoint("CENTER", 0, 0)
  b.Plus:SetText("+")
  b.Plus:SetTextColor(0.95, 0.88, 0.55)

  b:SetScript("OnEnter", function(self)
    self._hovered = true
    if self._hoverBorder then applyBorderTint(self, true) end
    tooltipForSocket(self)
  end)
  b:SetScript("OnLeave", function(self)
    self._hovered = nil
    applyBorderTint(self, false)
    if self.Glow then self.Glow:Hide() end
    GameTooltip:Hide()
  end)
  b:SetScript("OnClick", function(self, mouseButton)
    clickStockGlyphSocket(self, mouseButton)
  end)

  b._index = index
  return b
end

local function layoutRoot()
  local h = T.Host and T.Host() or T.frame
  if not h then return nil end

  if root and root:GetParent() ~= h then
    root:SetParent(h)
  end

  if not root then
    root = CreateFrame("Frame", "NE_TalentGlyphRoot", h)
    root:SetFrameLevel((h:GetFrameLevel() or 1))
    root.title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    root.title:SetPoint("TOP", 0, -8)
    root.title:SetText("Glyphs")
  end

  root:ClearAllPoints()
  root:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
  root:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, (T.FRAME and T.FRAME.BOTTOMBAR_H) or 80)
  return root
end

local function buildPane(group)
  if panes[group] then return panes[group] end

  local h = T.Host and T.Host() or T.frame
  if not h then return nil end

  local pane = CreateFrame("Frame", "NE_TalentGlyphPane" .. group, h)
  pane:SetFrameLevel((h:GetFrameLevel() or 1))

  pane.bg = pane:CreateTexture(nil, "BACKGROUND", nil, -1)
  pane.bg:SetAllPoints(pane)
  pane._bgNick = specBackgroundNick(group)
  pane._bgFlip = (group == 1)

  pane.spec = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  if _G.SystemFont_Shadow_Large2 then pane.spec:SetFontObject(_G.SystemFont_Shadow_Large2) end
  if pane.spec.SetTextScale then pane.spec:SetTextScale(1.1) end
  pane.spec:SetJustifyH("CENTER")
  pane.spec:SetPoint("TOP", 0, -28)
  pane.spec:SetText(groupStatus(group))

  pane.core = pane:CreateTexture(nil, "ARTWORK")
  pane.core:SetSize(84, 84)
  pane.core:SetPoint("CENTER", 0, 0)
  pane.core:Hide()

  pane.coreIcon = pane:CreateTexture(nil, "OVERLAY", nil, 1)
  pane.coreIcon:SetSize(20, 20)
  pane.coreIcon:SetPoint("CENTER", 0, 0)
  if not setAtlas(pane.coreIcon, "questlog-icon-setting", "Interface\\Buttons\\UI-OptionsButton") then
    pane.coreIcon:SetSize(18, 18)
  end
  pane.coreIcon:Hide()

  pane.sockets = {}
  local positions = {
    [1] = { 0, 118 },
    [2] = { 102, 60 },
    [3] = { 102, -60 },
    [4] = { 0, -118 },
    [5] = { -102, -60 },
    [6] = { -102, 60 },
  }
  for displayIndex = 1, SOCKET_COUNT do
    local socket = buildSocket(pane, displayIndex)
    socket:SetPoint("CENTER", pane, "CENTER", positions[displayIndex][1], positions[displayIndex][2])
    pane.sockets[displayIndex] = socket
  end

  panes[group] = pane
  return pane
end

local function applyPaneStyle(pane, active)
  if not pane then return end
  pane.spec:SetText(groupStatus(pane._group or 1))
  pane.spec:SetTextColor(1, 1, 1)
end

local function updateSocket(button, info, activePane, wantMajor)
  button._glyphInfo = info
  button._group = info and info.group or button._group
  local slotIsMajor = (wantMajor == true) or (info and info.glyphType ~= 2) or false
  local slotButtonSize = slotIsMajor and 104 or 92
  local lockedMajorBorderSize = 74
  local emptyMajorBorderSize = 78
  local filledMajorBorderSize = 84
  local lockedMinorBorderSize = 57
  local emptyMinorBorderSize = 57
  local filledMinorBorderSize = 65

  if not info then
    button:SetSize(slotButtonSize, slotButtonSize)
    setAtlas(button.Border, "talents-node-circle-locked", nil)
    button.Border:SetSize(slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize, slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize)
    button._borderTint = { 0.78, 0.80, 0.84, 1 }
    button._hoverTint = nil
    button._hoverBorder = nil
    applyBorderTint(button, false)
    button.Icon:SetSize(34, 34)
    button.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    if button.Icon.SetDesaturated then button.Icon:SetDesaturated(true) end
    if button.IconTint then button.IconTint:Hide() end
    button.Glow:Hide()
    button.Plus:SetText("")
    button._fallbackName = "Glyph Socket"
    button._fallbackState = "Unavailable"
    button:EnableMouse(false)
    button._activePane = nil
    button:SetAlpha(0.45)
    return
  end

  button._activePane = activePane and true or nil
  button:EnableMouse(activePane and true or false)
  button:SetSize(slotButtonSize, slotButtonSize)
  button:SetAlpha(activePane and 1 or 0.55)

  if not info.enabled then
    button:SetSize(slotButtonSize, slotButtonSize)
    setAtlas(button.Border, activePane and "talents-node-circle-locked" or "talents-node-circle-gray", nil)
    button.Border:SetSize(slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize, slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize)
    button._borderTint = { 0.78, 0.80, 0.84, 1 }
    button._hoverTint = nil
    button._hoverBorder = nil
    applyBorderTint(button, false)
    button.Icon:SetSize(34, 34)
    button.Icon:SetTexture(emptyGlyphIcon(info.glyphType))
    if button.Icon.SetDesaturated then button.Icon:SetDesaturated(true) end
    if button.IconTint then button.IconTint:Hide() end
    button.Glow:Hide()
    button.Plus:SetText("")
    button._fallbackName = "Locked socket"
    button._fallbackState = "Requires higher level"
    return
  end

  local spellName, _, spellIcon = nil, nil, nil
  if info.glyphSpellID and info.glyphSpellID > 0 and GetSpellInfo then
    spellName, _, spellIcon = GetSpellInfo(info.glyphSpellID)
  end

  local isMajor = slotIsMajor
  local hasGlyph = (type(info.glyphSpellID) == "number" and info.glyphSpellID > 0) or (info.link ~= nil)
  local borderSize = isMajor and ((hasGlyph and filledMajorBorderSize) or emptyMajorBorderSize)
                             or ((hasGlyph and filledMinorBorderSize) or emptyMinorBorderSize)
  local stateAtlas = "talents-node-circle-gray"
  setAtlas(button.Border, stateAtlas, nil)
  button.Border:SetSize(borderSize, borderSize)
  button._borderTint = activePane and { 0.63, 0.49, 0.28, 1 } or { 0.74, 0.76, 0.80, 1 }
  button._hoverTint = { 1.0, 0.86, 0.24, 1 }
  button._hoverBorder = true
  applyBorderTint(button, button._hovered)

  local iconSize
  if isMajor then
    iconSize = hasGlyph and 52 or 47
  else
    iconSize = hasGlyph and 34 or 30
  end
  if not activePane then iconSize = iconSize - 2 end
  button.Icon:SetSize(iconSize, iconSize)
  local iconTex = hasGlyph and (info.icon or spellIcon) or emptyGlyphIcon(info.glyphType)
  button.Icon:SetTexture(iconTex)
  if button.Icon.SetVertexColor then button.Icon:SetVertexColor(1, 1, 1, 1) end
  button.Icon:SetAlpha((hasGlyph and activePane) and 1 or (activePane and 1 or 0.75))
  if button.Icon.SetDesaturated then
    if hasGlyph and activePane then
      button.Icon:SetDesaturated(false)
    else
      button.Icon:SetDesaturated(not activePane)
    end
  end

  if button.IconTint then
    if hasGlyph and activePane then
      button.IconTint:SetSize(iconSize, iconSize)
      button.IconTint:SetTexture(iconTex)
      button.IconTint:SetAlpha(isMajor and 0.7 or 0.5)
      button.IconTint:Show()
    else
      button.IconTint:Hide()
    end
  end

  button.Glow:Hide()

  button.Plus:SetText("")
  button._fallbackName = spellName or "Glyph"
  button._fallbackState = hasGlyph and "Equipped" or "Empty socket"
end

local function layoutPane(pane, index, total, rootWidth, rootHeight)
  if not pane then return end

  local gap = 0
  local paneW, paneH

  if total >= 2 then
    paneW = math.floor((rootWidth - gap) / 2)
    paneH = math.floor(rootHeight)
    pane:SetSize(paneW, paneH)
    pane:ClearAllPoints()
    if index == 1 then
      pane:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    else
      pane:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    end
  else
    paneW = math.floor(rootWidth)
    paneH = math.floor(rootHeight)
    pane:SetSize(paneW, paneH)
    pane:ClearAllPoints()
    pane:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    pane:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
  end

  applyPaneBackground(pane)
end

local function updatePane(pane, group, activeGroup)
  if not pane then return end
  pane._group = group
  local activePane = (group == activeGroup)
  applyPaneStyle(pane, activePane)
  pane:SetAlpha(activePane and 1 or 0.62)

  local numSockets = (GetNumGlyphSockets and GetNumGlyphSockets()) or 0
  local majors, minors, other = {}, {}, {}
  for socketIndex = 1, numSockets do
    local info = getSocketInfo(socketIndex, group)
    if info then
      info.group = group
      if info.glyphType == 2 then
        minors[#minors + 1] = info
      elseif info.glyphType == 1 then
        majors[#majors + 1] = info
      else
        other[#other + 1] = info
      end
    end
  end

  local function popFirst(tbl)
    if #tbl == 0 then return nil end
    return table.remove(tbl, 1)
  end

  -- Display order must alternate around the ring: Major > Minor > Major > Minor > Major > Minor.
  for displayIndex = 1, SOCKET_COUNT do
    local button = pane.sockets[displayIndex]
    local wantMajor = (displayIndex % 2) == 1
    local info
    if wantMajor then
      info = popFirst(majors) or popFirst(other) or popFirst(minors)
    else
      info = popFirst(minors) or popFirst(other) or popFirst(majors)
    end
    updateSocket(button, info, activePane, wantMajor)
  end

  if T._glyphActive then pane:Show() else pane:Hide() end
end

local function ensurePanes()
  if not layoutRoot() then return nil end
  buildPane(1)
  buildPane(2)
  return root
end

function T.GlyphsSetActive(on)
  T._glyphActive = on and true or false
  if T.GlyphsApplyPaneVisibility then
    T.GlyphsApplyPaneVisibility()
  end
end

function T.GlyphsIsActive()
  return T._glyphActive and true or false
end

function T.GlyphsApplyPaneVisibility()
  local f = T.frame
  local r = root or layoutRoot()
  if not r then return end

  if T._glyphActive then
    if f then
      if f.bg then f.bg:Hide() end
      if f.trees then
        for _, tree in ipairs(f.trees) do
          if tree then tree:Hide() end
        end
      end
      if f.bottomBar then f.bottomBar:Show() end
      if f.pointsText then f.pointsText:Hide() end
      if f._loBtn then f._loBtn:Hide() end
      if f.apply then f.apply:Hide() end
      if f.reset then f.reset:Hide() end
      if f.activate then f.activate:Hide() end
    end
    for _, pane in pairs(panes) do
      if pane then pane:Show() end
    end
    r:Show()
  else
    for _, pane in pairs(panes) do
      if pane then pane:Hide() end
    end
    r:Hide()
    if f then
      if f.bg then f.bg:Show() end
      if f._loBtn then f._loBtn:Show() end
      if f.trees then
        for _, tree in ipairs(f.trees) do
          if tree then tree:Show() end
        end
      end
      if f.bottomBar then f.bottomBar:Show() end
      if f.pointsText then f.pointsText:Show() end
    end
  end
end

function T.GlyphsEnsureUI()
  if not ensurePanes() then return end
  T.GlyphsRefresh()
  T.GlyphsApplyPaneVisibility()
end

function T.GlyphsRefresh()
  if not ensurePanes() then return end

  local h = T.Host and T.Host() or T.frame
  if not h then return end

  local rootWidth = (root and root:GetWidth()) or (h.GetWidth and h:GetWidth()) or 0
  local rootHeight = (root and root:GetHeight()) or (h.GetHeight and h:GetHeight()) or 0
  if rootWidth <= 0 or rootHeight <= 0 then return end

  local activeGroup = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
  local totalGroups = (GetNumTalentGroups and (GetNumTalentGroups() or 1)) or 1
  local paneGroups = { 1 }
  if totalGroups >= 2 then paneGroups[#paneGroups + 1] = 2 end

  if root.title then root.title:SetText("Glyphs") end

  for i, group in ipairs(paneGroups) do
    local pane = panes[group]
    if pane then
      layoutPane(pane, i, #paneGroups, rootWidth, rootHeight)
      updatePane(pane, group, activeGroup)
    end
  end

  for group = 1, 2 do
    local pane = panes[group]
    if pane then
      if group > totalGroups then
        pane:Hide()
      end
    end
  end
end
