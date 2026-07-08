-- DragonUI_NewEra/modules/talents/Glyphs.lua — glyph tab renderer for 3.3.5a.
--
-- This file owns the reusable glyph view that lives inside NE_TalentFrame. The talents tab
-- strip toggles the view on/off; Behavior.lua keeps it refreshed from live glyph/spec events.

local NE = DragonUI_NewEra
local T  = NE.talents or {}
NE.talents = T

local SOCKET_COUNT = 6
local GLYPH_DOT_SIZE = 4
local GLYPH_DOT_GAP = 9
local GLYPH_FLOW_SPEED = 16

local root
local panes = {}
local refreshDriver
local glyphEdgePhase = 0

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

local function positionGlyphEdge(edge, phase)
  local dots, span, gap = edge.dots, edge.span, edge.gap
  for i = 1, #dots do
    local dist = ((i - 1) * gap + phase) % span
    local d = dots[i]
    d:ClearAllPoints()
    d:SetPoint("CENTER", edge.parent, "CENTER", edge.x0 + edge.ux * dist, edge.y0 + edge.uy * dist)
  end
end

local function ensureGlyphFlowDriver(host)
  if not (host and host.HookScript) or host._glyphEdgeFlow then return end
  host._glyphEdgeFlow = true
  host:HookScript("OnUpdate", function(self, dt)
    if not T._glyphActive then return end
    dt = dt or 0
    glyphEdgePhase = glyphEdgePhase + dt * GLYPH_FLOW_SPEED
    if glyphEdgePhase > 1e6 then glyphEdgePhase = 0 end
    for _, pane in pairs(panes) do
      if pane and pane:IsShown() and pane._glyphEdges then
        for i = 1, #pane._glyphEdges do
          positionGlyphEdge(pane._glyphEdges[i], glyphEdgePhase)
        end
      end
    end
  end)
end

local function resetPaneEdges(pane)
  if not pane then return end
  pane._edgeN = 0
  pane._glyphEdges = pane._glyphEdges or {}
  for i = 1, #pane._glyphEdges do pane._glyphEdges[i] = nil end
end

local function acquirePaneDot(pane)
  pane._edgeN = (pane._edgeN or 0) + 1
  pane.edgePool = pane.edgePool or {}
  local d = pane.edgePool[pane._edgeN]
  if not d then
    d = pane:CreateTexture(nil, "ARTWORK", nil, -2)
    d:SetTexture("Interface\\Buttons\\WHITE8X8")
    pane.edgePool[pane._edgeN] = d
  end
  d:Show()
  return d
end

local function hideUnusedPaneDots(pane)
  if not (pane and pane.edgePool) then return end
  for i = (pane._edgeN or 0) + 1, #pane.edgePool do
    pane.edgePool[i]:Hide()
  end
end

local function drawPaneEdge(pane, startButton, endButton, color)
  if not (pane and startButton and endButton) then return end
  local sx, sy = startButton:GetCenter()
  local ex, ey = endButton:GetCenter()
  local px, py = pane:GetCenter()
  if not (sx and sy and ex and ey and px and py) then return end
  sx, sy = sx - px, sy - py
  ex, ey = ex - px, ey - py
  local dx, dy = ex - sx, ey - sy
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then return end
  local ux, uy = dx / dist, dy / dist
  local startRadius = (startButton.Border and startButton.Border:GetWidth() or startButton:GetWidth() or 0) * 0.5
  local endRadius = (endButton.Border and endButton.Border:GetWidth() or endButton:GetWidth() or 0) * 0.5
  local x0, y0 = sx + ux * startRadius, sy + uy * startRadius
  local span = dist - startRadius - endRadius
  if span <= 0 then return end
  local count = math.floor(span / GLYPH_DOT_GAP + 0.5)
  if count < 1 then count = 1 end
  local gap = span / count
  local dots = {}
  for _ = 1, count do
    local d = acquirePaneDot(pane)
    d:SetSize(GLYPH_DOT_SIZE, GLYPH_DOT_SIZE)
    d:SetVertexColor(color[1], color[2], color[3], color[4])
    dots[#dots + 1] = d
  end
  local edge = { parent = pane, x0 = x0, y0 = y0, ux = ux, uy = uy, span = span, gap = gap, dots = dots }
  pane._glyphEdges[#pane._glyphEdges + 1] = edge
  positionGlyphEdge(edge, glyphEdgePhase)
end

local function updatePaneEdges(pane, activePane)
  if not pane then return end
  resetPaneEdges(pane)
  if not T._glyphActive then
    hideUnusedPaneDots(pane)
    return
  end

  local majorColor = activePane and { 1.0, 0.84, 0.18, 0.95 } or { 0.62, 0.49, 0.24, 0.45 }
  local minorColor = activePane and { 1.0, 0.84, 0.18, 0.72 } or { 0.62, 0.49, 0.24, 0.32 }
  local sockets = pane.sockets
  drawPaneEdge(pane, sockets[1], sockets[3], majorColor)
  drawPaneEdge(pane, sockets[3], sockets[5], majorColor)
  drawPaneEdge(pane, sockets[5], sockets[1], majorColor)
  drawPaneEdge(pane, sockets[2], sockets[4], minorColor)
  drawPaneEdge(pane, sockets[4], sockets[6], minorColor)
  drawPaneEdge(pane, sockets[6], sockets[2], minorColor)
  hideUnusedPaneDots(pane)
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

local function getStockGlyphSocket(button)
  local info = button and button._glyphInfo
  if not (info and info.socket) then return nil end

  if not ((NE.IsAddOnLoaded and NE.IsAddOnLoaded("Blizzard_GlyphUI")) or _G.GlyphFrame) then
    if type(_G.LoadAddOn) == "function" then
      pcall(_G.LoadAddOn, "Blizzard_GlyphUI")
    end
  end

  return _G["GlyphFrameGlyph" .. tostring(info.socket)]
end

local function copyTooltipToButton(button)
  if not (button and GameTooltip and GameTooltip:IsShown()) then return false end

  local lines = {}
  local numLines = GameTooltip:NumLines() or 0
  for i = 1, numLines do
    local left = _G["GameTooltipTextLeft" .. i]
    if left and left.GetText then
      local text = left:GetText()
      if text and text ~= "" then
        local r, g, b = left:GetTextColor()
        lines[#lines + 1] = { text = text, r = r or 1, g = g or 1, b = b or 1 }
      end
    end
  end
  if #lines == 0 then return false end

  GameTooltip:Hide()
  GameTooltip:SetOwner(button, "ANCHOR_NONE")
  GameTooltip:SetPoint("BOTTOMLEFT", button, "TOPRIGHT", 3, 2)
  GameTooltip:SetText(lines[1].text, lines[1].r, lines[1].g, lines[1].b)
  for i = 2, #lines do
    local line = lines[i]
    GameTooltip:AddLine(line.text, line.r, line.g, line.b, true)
  end
  GameTooltip:Show()
  return true
end

local function tooltipForSocket(button)
  local info = button._glyphInfo
  if not info then return end

  local stock = getStockGlyphSocket(button)
  if stock and stock.GetScript then
    local onEnter = stock:GetScript("OnEnter")
    if type(onEnter) == "function" then
      local ok = pcall(onEnter, stock)
      if ok and GameTooltip and GameTooltip:IsShown() then
        if copyTooltipToButton(button) then return end
      end
    end
  end

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

  local stock = getStockGlyphSocket(button)
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

local function applyIconHover(button, hovered)
  if not (button and button.Icon) then return end
  if not button._hasGlyph then
    button.Icon:SetAlpha(button._iconAlpha or 1)
    if button.IconTint then button.IconTint:SetAlpha(button._iconTintAlpha or 0) end
    return
  end

  local iconAlpha = button._iconAlpha or 1
  button.Icon:SetAlpha(hovered and math.min(1, iconAlpha + 0.32) or iconAlpha)
  if button.IconTint and button._iconTintShown then
    local tintAlpha = button._iconTintAlpha or 0
    button.IconTint:SetAlpha(hovered and math.min(1, tintAlpha + 0.28) or tintAlpha)
  end
end

local function setSocketHitRect(button, frameSize, hitSize)
  if not (button and button.SetHitRectInsets) then return end
  local inset = math.max(0, math.floor(((frameSize or 0) - (hitSize or 0)) / 2))
  button:SetHitRectInsets(inset, inset, inset, inset)
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
    applyIconHover(self, true)
    tooltipForSocket(self)
  end)
  b:SetScript("OnLeave", function(self)
    self._hovered = nil
    applyBorderTint(self, false)
    applyIconHover(self, false)
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
  ensureGlyphFlowDriver(h)

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
    local lockedBorderSize = slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize
    button.Border:SetSize(lockedBorderSize, lockedBorderSize)
    setSocketHitRect(button, slotButtonSize, lockedBorderSize)
    button._borderTint = { 0.78, 0.80, 0.84, 1 }
    button._hoverTint = nil
    button._hoverBorder = nil
    applyBorderTint(button, false)
    button.Icon:SetSize(34, 34)
    button.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button._hasGlyph = nil
    button._iconAlpha = 1
    button._iconTintAlpha = 0
    button._iconTintShown = nil
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
    local lockedBorderSize = slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize
    button.Border:SetSize(lockedBorderSize, lockedBorderSize)
    setSocketHitRect(button, slotButtonSize, lockedBorderSize)
    button._borderTint = { 0.78, 0.80, 0.84, 1 }
    button._hoverTint = nil
    button._hoverBorder = nil
    applyBorderTint(button, false)
    button.Icon:SetSize(34, 34)
    button.Icon:SetTexture(emptyGlyphIcon(info.glyphType))
    button._hasGlyph = nil
    button._iconAlpha = 1
    button._iconTintAlpha = 0
    button._iconTintShown = nil
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
  setSocketHitRect(button, slotButtonSize, borderSize)
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
  button._hasGlyph = hasGlyph and true or nil
  button._iconAlpha = ((hasGlyph and activePane) and 1 or (activePane and 1 or 0.75))
  button.Icon:SetAlpha(button._iconAlpha)
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
      button._iconTintAlpha = isMajor and 0.7 or 0.5
      button._iconTintShown = true
      button.IconTint:SetAlpha(button._iconTintAlpha)
      button.IconTint:Show()
    else
      button._iconTintAlpha = 0
      button._iconTintShown = nil
      button.IconTint:Hide()
    end
  end

  button.Glow:Hide()
  applyIconHover(button, button._hovered)

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

  updatePaneEdges(pane, activePane)

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
