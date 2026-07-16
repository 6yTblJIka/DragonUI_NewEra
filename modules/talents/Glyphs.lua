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
local GLYPH_NAME_PREFIX = "Glyph of "
-- Socket ring: the gold circle from the talents sheet (talents-node-circle-yellow), isolated from a
-- 2x upscale for a crisper edge and shipped as a 128 TGA. White tint on the active spec (true gold),
-- dimmed when locked/inactive/off-spec.
local GLYPH_RING_TEXTURE = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\glyph-ring-gold.tga"
-- Greyscale copy of the ring for LEVEL-LOCKED sockets (desaturated). A separate texture, not
-- SetDesaturated(), because on 3.3.5a SetDesaturated OVERRIDES the vertex tint we use to dim it.
local GLYPH_RING_DESAT_TEXTURE = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\glyph-ring-desat.tga"
-- The visible ring fills only this fraction of its (transparent-margined) texture box; the marching
-- ants use it so their endpoints land on the ring edge instead of out in the empty margin.
local RING_ART_FRAC = 0.66

-- Diablo-style animated globes behind each socket (HoradricSpheres idle sprite, downsized to 512):
-- health (red) on MAJOR sockets, mana (blue) on MINOR. Full-colour + animated for a live glyph,
-- desaturated when the socket is unused. One shared 30fps ticker cycles the 67-frame flipbook across
-- every socket globe (texcoords are normalised to the original 4096 sheet, so they hold at any size).
local GLOBE_HEALTH = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\glyph-globe-health.tga"
local GLOBE_MANA   = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\glyph-globe-mana.tga"
local GLOBE_FRAMES, GLOBE_COLS, GLOBE_FW, GLOBE_STRIDE, GLOBE_SHEET = 67, 11, 350, 352, 4096
local function globeCoord(i)
  local col = (i - 1) % GLOBE_COLS
  local row = math.floor((i - 1) / GLOBE_COLS)
  local x, y = col * GLOBE_STRIDE, 1 + row * GLOBE_STRIDE
  return x / GLOBE_SHEET, (x + GLOBE_FW) / GLOBE_SHEET, y / GLOBE_SHEET, (y + GLOBE_FW) / GLOBE_SHEET
end
local glyphGlobes = {}
local globeFrameIndex = 1
local globeTicker
local function ensureGlobeTicker()
  if globeTicker or not (C_Timer and C_Timer.NewTicker) then return end
  globeTicker = C_Timer.NewTicker(1 / 30, function()
    if not (T.GlyphsIsActive and T.GlyphsIsActive()) then return end   -- only animate while visible
    globeFrameIndex = globeFrameIndex % GLOBE_FRAMES + 1
    local l, r, t, b = globeCoord(globeFrameIndex)
    for i = 1, #glyphGlobes do
      local g = glyphGlobes[i]
      if g:IsShown() then g:SetTexCoord(l, r, t, b) end
    end
  end)
end
-- Glass gloss/shine overlaid on TOP of everything (over the rune) so the socket reads as a glass orb.
local GLYPH_GLOSS_TEXTURE = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\glyph-orbgloss.tga"
-- Soft round drop-shadow behind the globe (lifted from the reference sheet). Baked dark.
local GLYPH_SHADOW_TEXTURE = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\glyph-shadow.tga"
-- Multipliers on the socket's base size. The animated sphere and the gloss over it are grown so the
-- orb reads big; the gold ring is pushed out to sit at the sphere's rim; the shadow haloes just beyond.
local GLOBE_SCALE = 1.00   -- animated sphere (and the gloss over it) — fills the orb
local RING_SCALE  = 1.8   -- gold ring — sits at the sphere's outer rim
-- Point a socket's globe at health/mana; full colour + lit when `lit`.
local function configGlobe(button, isMajor, lit, size)
  local g = button and button.Globe
  if not g then return end
  g:SetTexture(isMajor and GLOBE_HEALTH or GLOBE_MANA)
  local d = size * GLOBE_SCALE
  g:SetSize(d, d)
  if g.SetDesaturated then g:SetDesaturated(not lit) end
  g:SetAlpha(lit and 1 or 0.45)
  g:Show()
  -- Glass gloss on top (over the rune), sized to the orb, for the glass-sphere look.
  local gs = button.Gloss
  if gs then
    gs:SetTexture(GLYPH_GLOSS_TEXTURE)
    gs:SetSize(d * 1.2, d * 1.2)
    gs:SetAlpha(lit and 0.8 or 0.5)
    gs:Show()
  end
end

local root
local panes = {}
local refreshDriver
local glyphEdgePhase = 0
local glyphOptionsMenu

T._glyphActive = (T._glyphActive ~= nil) and T._glyphActive or false

local function glyphLabelNamesEnabled()
  return (NE.db and NE.db.talentGlyphSlotNames) and true or false
end

local function setGlyphLabelNamesEnabled(enabled)
  if not NE.db then return end
  NE.db.talentGlyphSlotNames = enabled and true or false
end

local function trimGlyphPrefix(name)
  if type(name) ~= "string" then return nil end
  local trimmed = name:gsub("^Glyph%s+[Oo]f%s+", "")
  if trimmed == "" then
    return name
  end
  if trimmed ~= name then
    return trimmed
  end
  if name:sub(1, #GLYPH_NAME_PREFIX) == GLYPH_NAME_PREFIX then
    return name:sub(#GLYPH_NAME_PREFIX + 1)
  end
  return name
end

local function glyphDisplayName(info, fallbackSpellName)
  if not info then return nil end
  local itemName
  if info.link and GetItemInfo then
    itemName = GetItemInfo(info.link)
  end
  if (not itemName) and type(info.link) == "string" then
    itemName = info.link:match("%[(.-)%]")
  end
  return trimGlyphPrefix(itemName or fallbackSpellName)
end

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

-- Refresh the glyph view whenever the game reports a glyph change. The removal path alone polled a
-- few frames, which read stale socket data — so a removed glyph's icon lingered. These events fire
-- once the socket data has actually updated, so the graphic clears/updates reliably.
do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED", "USE_GLYPH",
                       "ACTIVE_TALENT_GROUP_CHANGED" }) do
    pcall(function() ev:RegisterEvent(e) end)
  end
  ev:SetScript("OnEvent", function()
    if T.GlyphsIsActive and T.GlyphsIsActive() then queueGlyphRefresh(2) end
  end)
end

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
          -- Drop the removed glyph's rune immediately (visual feedback); the repaint below fills the
          -- empty placeholder once the socket actually reads empty.
          button._hasGlyph = nil
          if button.Icon then button.Icon:SetTexture(nil) end
          if button.IconTint then button.IconTint:Hide() end
          if button.Glow then button.Glow:Hide() end
          -- RemoveGlyphFromSocket round-trips the server (~0.5s) before GetGlyphSocketInfo reports the
          -- socket empty — its glyphSpell (3rd return on 3.3.5a) goes nil. Poll on a timer until it
          -- clears, THEN repaint, so we never repaint from stale data (which redrew the old rune). The
          -- GLYPH_REMOVED/GLYPH_UPDATED handler also repaints if the server fires those.
          local socket, group = info.socket, info.group
          local tries = 0
          local function poll()
            tries = tries + 1
            local _, _, glyphSpell = GetGlyphSocketInfo(socket, group)
            local cleared = not (type(glyphSpell) == "number" and glyphSpell > 0)
            if cleared or tries >= 25 then
              if T.GlyphsRefresh then pcall(T.GlyphsRefresh) end
            elseif C_Timer and C_Timer.After then
              C_Timer.After(0.15, poll)
            end
          end
          if C_Timer and C_Timer.After then C_Timer.After(0.15, poll) else queueGlyphRefresh(60) end
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
  local startRadius = (startButton.Border and startButton.Border:GetWidth() or startButton:GetWidth() or 0) * 0.5 * RING_ART_FRAC
  local endRadius = (endButton.Border and endButton.Border:GetWidth() or endButton:GetWidth() or 0) * 0.5 * RING_ART_FRAC
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
    -- Shift-right-click is the "remove glyph" gesture — only offer it on a socket that HAS a glyph.
    -- Consume the click either way so an empty socket does nothing (no confirm popup, no fall-through).
    if button._hasGlyph and type(_G.StaticPopup_Show) == "function" then
      _G.StaticPopup_Show("NE_GLYPH_REMOVE_CONFIRM", nil, nil, { button = button })
    end
    return
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
  button.Icon:SetAlpha(hovered and math.min(1, iconAlpha + 0.45) or iconAlpha)
  if button.IconTint and button._iconTintShown then
    local tintAlpha = button._iconTintAlpha or 0
    button.IconTint:SetAlpha(hovered and math.min(1, tintAlpha + 0.40) or tintAlpha)
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

  -- Stack, bottom to top: shadow -> animated globe -> rune (Icon) -> orb gloss -> gold ring (Border).
  -- 1) Soft shadow at the very bottom.
  b.GlowUnder = b:CreateTexture(nil, "BACKGROUND", nil, -2)
  b.GlowUnder:SetPoint("CENTER")
  -- 2) Animated Diablo globe on top of the shadow, still behind the rune.
  b.Globe = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  b.Globe:SetPoint("CENTER")
  b.Globe:SetTexCoord(globeCoord(1))
  glyphGlobes[#glyphGlobes + 1] = b.Globe
  ensureGlobeTicker()

  -- 4) Glass gloss over the rune (ARTWORK 3 → above the Icon/IconTint at 1/2, below the ring).
  b.Gloss = b:CreateTexture(nil, "ARTWORK", nil, 3)
  b.Gloss:SetPoint("CENTER")

  -- 5) Gold ring on the very top (OVERLAY → above the gloss and everything else).
  b.Border = b:CreateTexture(nil, "OVERLAY", nil, 1)
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

  b.Name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if _G.SystemFont_Shadow_Med1 then b.Name:SetFontObject(_G.SystemFont_Shadow_Med1) end
  b.Name:SetTextColor(0.95, 0.90, 0.75)
  b.Name:SetWidth(160)
  b.Name:SetWordWrap(true)
  b.Name:Hide()

  if index == 1 then
    b.Name:SetPoint("BOTTOM", b, "TOP", 0, 8)
    b.Name:SetJustifyH("CENTER")
  elseif index == 4 then
    b.Name:SetPoint("TOP", b, "BOTTOM", 0, -10)
    b.Name:SetJustifyH("CENTER")
  elseif index == 2 or index == 3 then
    b.Name:SetPoint("LEFT", b, "RIGHT", 10, 0)
    b.Name:SetJustifyH("LEFT")
  else
    b.Name:SetPoint("RIGHT", b, "LEFT", -10, 0)
    b.Name:SetJustifyH("RIGHT")
  end

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

local function ensureGlyphOptionsMenu(anchor)
  if glyphOptionsMenu or not anchor then return glyphOptionsMenu end
  if not UIDropDownMenu_Initialize then return nil end
  local ok, menu = pcall(CreateFrame, "Frame", "NE_TalentGlyphOptionsMenu", anchor, "UIDropDownMenuTemplate")
  if not ok then return nil end
  menu.displayMode = "MENU"
  UIDropDownMenu_Initialize(menu, function(self, level)
    if level ~= 1 then return end

    local info = UIDropDownMenu_CreateInfo()
    info.text = "Show glyph names"
    info.checked = glyphLabelNamesEnabled()
    info.keepShownOnClick = true
    info.isNotRadio = true
    info.func = function()
      setGlyphLabelNamesEnabled(not glyphLabelNamesEnabled())
      if T.GlyphsRefresh then T.GlyphsRefresh() end
    end
    UIDropDownMenu_AddButton(info, level)
  end)
  glyphOptionsMenu = menu
  return glyphOptionsMenu
end

local function buildGlyphCog(parent)
  if parent and parent.cog then return parent.cog end

  local cog = CreateFrame("Button", "NE_TalentGlyphCog", parent)
  cog:SetSize(18, 18)
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
  cog:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
  cog:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
  cog:SetScript("OnClick", function(self)
    local menu = ensureGlyphOptionsMenu(parent)
    if menu and ToggleDropDownMenu then
      ToggleDropDownMenu(1, nil, menu, self, 6, 2)
      return
    end
    setGlyphLabelNamesEnabled(not glyphLabelNamesEnabled())
    if T.GlyphsRefresh then T.GlyphsRefresh() end
  end)
  cog:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Glyph options", 1, 1, 1)
    GameTooltip:AddLine("Toggle slot name labels.", 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
  end)
  cog:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  parent.cog = cog
  return cog
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
    -- Single page-level "GLYPHS" title, centered over the WHOLE page (shown once even under dual spec).
    -- Each pane then shows its spec NAME as a second row beneath it (see buildPane / applyPaneStyle).
    root.title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if _G.SystemFont_Shadow_Large2 then root.title:SetFontObject(_G.SystemFont_Shadow_Large2) end
    if root.title.SetTextScale then root.title:SetTextScale(1.1) end
    root.title:SetJustifyH("CENTER")
    root.title:SetPoint("TOP", root, "TOP", 0, -28)
    root.title:SetText("GLYPHS")
    root.title:SetTextColor(1, 1, 1)
    buildGlyphCog(root)
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
  -- The Glyphs page now uses a single full-window class ARTIFACT painting (f.glyphBg, applied in
  -- GlyphsApplyPaneVisibility) rather than a per-pane spec painting, so hide this pane background to
  -- avoid doubling. (_bgNick/applyPaneBackground kept for a graceful fallback if the class art is absent.)
  pane.bg:Hide()

  -- Per-pane header: this pane's SPEC NAME (Primary/Secondary or custom), centered over its own
  -- sockets, a row BELOW the single page-level "GLYPHS" title. Text + visibility set in applyPaneStyle
  -- (shown only under dual spec; a lone spec needs no name since the page title says it all).
  pane.spec = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  if _G.SystemFont_Shadow_Large2 then pane.spec:SetFontObject(_G.SystemFont_Shadow_Large2) end
  if pane.spec.SetTextScale then pane.spec:SetTextScale(0.72) end   -- smaller than the GLYPHS title (hierarchy)
  pane.spec:SetJustifyH("CENTER")
  pane.spec:SetPoint("TOP", pane, "TOP", 0, -66)
  pane.spec:SetText("")

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
  -- Show the spec name only when there are two specs (each labels its own pane). With a single spec
  -- the page-level "GLYPHS" title is enough, so leave the per-pane header blank/hidden.
  local totalGroups = (GetNumTalentGroups and (GetNumTalentGroups() or 1)) or 1
  if totalGroups >= 2 then
    pane.spec:SetText(string.upper(groupStatus(pane._group or 1) or ""))   -- CAPS "PRIMARY"/"SECONDARY" (matches the GLYPHS title)
    pane.spec:Show()
  else
    pane.spec:SetText("")
    pane.spec:Hide()
  end
  pane.spec:SetTextColor(1, 1, 1)   -- off-spec dims via pane:SetAlpha in updatePane
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
    if button.Globe then button.Globe:Hide() end   -- no socket → no globe
    if button.GlowUnder then button.GlowUnder:Hide() end
    if button.Gloss then button.Gloss:Hide() end
    button.Border:SetTexture(GLYPH_RING_TEXTURE)
    local lockedBorderSize = slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize
    button.Border:SetSize(lockedBorderSize * RING_SCALE, lockedBorderSize * RING_SCALE)
    setSocketHitRect(button, slotButtonSize, lockedBorderSize)
    button._borderTint = { 0.55, 0.55, 0.55, 1 }
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
    if button.Name then
      button.Name:SetText("")
      button.Name:Hide()
    end
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
    -- Level-locked socket: desaturated (greyscale) ring + globe until the player is high enough level.
    button.Border:SetTexture(GLYPH_RING_DESAT_TEXTURE)
    local lockedBorderSize = slotIsMajor and lockedMajorBorderSize or lockedMinorBorderSize
    button.Border:SetSize(lockedBorderSize * RING_SCALE, lockedBorderSize * RING_SCALE)
    configGlobe(button, slotIsMajor, false, lockedBorderSize)   -- locked socket → desaturated globe
    setSocketHitRect(button, slotButtonSize, lockedBorderSize)
    button._borderTint = { 0.55, 0.55, 0.55, 1 }
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
    if button.Name then
      button.Name:SetText("")
      button.Name:Hide()
    end
    return
  end

  local spellName, _, spellIcon = nil, nil, nil
  if info.glyphSpellID and info.glyphSpellID > 0 and GetSpellInfo then
    spellName, _, spellIcon = GetSpellInfo(info.glyphSpellID)
  end

  local isMajor = slotIsMajor
  -- glyphSpell is the authoritative "is there a glyph" field (nil when the socket is empty). Do NOT
  -- fall back to info.link: GetGlyphLink returns a STALE link for a just-emptied socket, which kept
  -- hasGlyph true after a removal so the old glyph icon lingered.
  local hasGlyph = (type(info.glyphSpellID) == "number" and info.glyphSpellID > 0)
  local borderSize = isMajor and ((hasGlyph and filledMajorBorderSize) or emptyMajorBorderSize)
                             or ((hasGlyph and filledMinorBorderSize) or emptyMinorBorderSize)
  -- Gold portrait ring for the socket (the character portrait's metal ring). White tint on the active
  -- spec shows its true gold; the off-spec is dimmed. Hover brightens to full.
  button.Border:SetTexture(GLYPH_RING_TEXTURE)
  button.Border:SetSize(borderSize * RING_SCALE, borderSize * RING_SCALE)
  -- Globe: full colour + animated only for a live glyph on the active spec; desaturated when unused.
  configGlobe(button, isMajor, hasGlyph and activePane, borderSize)
  setSocketHitRect(button, slotButtonSize, borderSize)
  button._borderTint = activePane and { 1.0, 1.0, 1.0, 1 } or { 0.70, 0.70, 0.70, 1 }
  button._hoverTint = { 1.0, 1.0, 1.0, 1 }
  button._hoverBorder = true
  applyBorderTint(button, button._hovered)

  local iconSize
  if isMajor then
    iconSize = hasGlyph and 52 or 47
  else
    iconSize = hasGlyph and 34 or 30
  end
  if not activePane then iconSize = iconSize - 2 end
  if hasGlyph then iconSize = iconSize * 0.9 end   -- printed rune sits at 90% scale
  button.Icon:SetSize(iconSize, iconSize)
  local iconTex = hasGlyph and (info.icon or spellIcon) or emptyGlyphIcon(info.glyphType)
  if not hasGlyph then button.Icon:SetTexture(nil) end   -- drop any prior glyph rune before the placeholder
  button.Icon:SetTexture(iconTex)
  if button.Icon.SetVertexColor then button.Icon:SetVertexColor(1, 1, 1, 1) end
  button._hasGlyph = hasGlyph and true or nil
  -- Printed rune at 75% opacity; empty/off-spec placeholder keeps its own faint alpha.
  button._iconAlpha = hasGlyph and (activePane and 0.75 or 0.6) or (activePane and 1 or 0.75)
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
  local displayName = hasGlyph and glyphDisplayName(info, spellName) or nil
  button._fallbackName = displayName or spellName or "Glyph"
  button._fallbackState = hasGlyph and "Equipped" or "Empty socket"
  if button.Name then
    if glyphLabelNamesEnabled() and hasGlyph and displayName then
      button.Name:SetText(displayName)
      button.Name:SetAlpha(activePane and 1 or 0.8)
      button.Name:Show()
    else
      button.Name:SetText("")
      button.Name:Hide()
    end
  end
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

-- Full-window class ARTIFACT painting for the Glyphs page (bundled from the TalentArt Artifact pack,
-- one per class). A single BORDER texture on the frame filling the same content rect as the talent
-- paintings — the glyph panes/sockets draw above it on the Host. Returns true if class art was set.
local GLYPH_BG_PATH = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Talents\\Artifact\\"
local GLYPH_BG_FILE = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  DEATHKNIGHT = "DeathKnight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}
local function applyGlyphBackground(f)
  if not f then return false end
  local _, classFile = UnitClass("player")
  local file = classFile and GLYPH_BG_FILE[classFile]
  if not file then return false end   -- unsupported class -> caller keeps the per-pane spec paintings
  if not f.glyphBg then
    local FR = T.FRAME or {}
    local tx = f:CreateTexture(nil, "BORDER")
    tx:SetPoint("TOPLEFT",     f, "TOPLEFT",     (FR.CHROME_L or 0), -(FR.CHROME_T or 0))
    tx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(FR.CHROME_R or 0), (FR.CHROME_B or 0) + (FR.BOTTOMBAR_H or 0))
    tx:SetTexCoord(0, 1, 0, 1)
    f.glyphBg = tx
  end
  f.glyphBg:SetTexture(GLYPH_BG_PATH .. file)
  return true
end

function T.GlyphsApplyPaneVisibility()
  local f = T.frame
  local r = root or layoutRoot()
  if not r then return end

  if T._glyphActive then
    if f then
      if f.bg then f.bg:Hide() end
      if f.petBg then f.petBg:Hide() end   -- glyph view: talent/pet paintings hidden
      -- Single class Artifact painting for the whole Glyphs page (replaces the per-pane spec art,
      -- incl. the two side-by-side backgrounds under dual spec).
      local hasArt = applyGlyphBackground(f)
      if f.glyphBg then if hasArt then f.glyphBg:Show() else f.glyphBg:Hide() end end
      if hasArt then
        for _, pane in pairs(panes) do if pane and pane.bg then pane.bg:Hide() end end
      end
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
      if f.glyphBg then f.glyphBg:Hide() end   -- leaving glyphs: drop the class Artifact painting
      -- Defer the talent background to the current view: pet view keeps the pet art (f.petBg) and
      -- hides the class painting (f.bg); Populate owns re-selecting the right one on its next pass.
      local petView = T.PetViewActive and T.PetViewActive()
      if f.bg then if petView then f.bg:Hide() else f.bg:Show() end end
      if f.petBg then if petView then f.petBg:Show() else f.petBg:Hide() end end
      if f._loBtn and not petView then f._loBtn:Show() end   -- loadout btn is player-only
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
