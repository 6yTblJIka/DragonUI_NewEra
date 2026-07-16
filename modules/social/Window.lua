-- DragonUI_NewEra/modules/social/Window.lua — modern Social/Friends window shell (NE_FriendsFrame).
--
-- DOWNPORT of NewEra/Social/Social.lua. NewEra RESKINS Classic 1.15's modern ButtonFrameTemplate
-- FriendsFrame in place. 3.3.5a's FriendsFrame is the OLD parchment/stone frame — there is no
-- modern chrome to reskin — so, like the Auction House port, we BUILD a new window from
-- PortraitFrameTemplate and drive it off the classic friends/ignore/who APIs. The Guild tab opens
-- the separate NE_GuildFrame (NE.guild.Toggle) rather than hosting a guild view inline.
--
-- RENDER-BEFORE-WIRE: this file builds the shell (chrome, tabs, empty content panels). The list
-- content wires in Friends.lua (Friends/Ignore) and Who.lua via SO.SetupFriends / SO.SetupWho.

local NE = DragonUI_NewEra
if not NE then return end

NE.social = NE.social or {}
local SO = NE.social

local FRAME_NAME = "NE_FriendsFrame"
local MODULE = "Social"

-- Bottom tabs — the native 3.3.5a Socials set (owner supplied the stock frames as reference
-- 2026-07-16): Friends / Who / Guild / Chat / Raid. Ignore is NOT a bottom tab here; it's a
-- SUB-tab inside the Friends panel (see Friends.lua), exactly as the stock window does it.
-- Guild is an ACTION tab: it opens the standalone NE_GuildFrame instead of hosting a guild view.
local TABS = {
  { mode = "FRIENDS", label = FRIENDS or "Friends", panel = "FriendsPanel" },
  { mode = "WHO",     label = WHO or "Who", panel = "WhoPanel" },
  { mode = "GUILD",   label = GUILD or "Guild", action = true },
  { mode = "CHAT",    label = CHAT or "Chat", panel = "ChatPanel" },
  { mode = "RAID",    label = RAID or "Raid", panel = "RaidPanel" },
}

local function isModuleEnabled()
  local dragon = NE.dragon
  if not (dragon and dragon.db and dragon.db.profile and dragon.db.profile.newera) then return true end
  local m = dragon.db.profile.newera.modules and dragon.db.profile.newera.modules[MODULE]
  if type(m) == "table" and m.enabled ~= nil then return m.enabled and true or false end
  return true
end

-- ---------------------------------------------------------------------------
-- Chrome (rock + streaks + nineslice + portrait + title + close) — AH recipe.
-- ---------------------------------------------------------------------------
local function buildChrome(f)
  local body = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  local rockPath = NE.tex and NE.tex.localFiles and NE.tex.localFiles[374155]
  body:SetTexture(rockPath or 374155, "REPEAT", "REPEAT")
  body:SetHorizTile(true); body:SetVertTile(true)
  body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -21)
  body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

  local streaks = f:CreateTexture(nil, "BORDER")
  if NE.tex and NE.tex.SetAtlas then NE.tex.SetAtlas(streaks, "_UI-Frame-TopTileStreaks", false) end
  streaks:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
  streaks:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)
  streaks:SetHeight(43); streaks:SetHorizTile(true)

  local ns = CreateFrame("Frame", nil, f)
  ns:SetAllPoints(f)
  if NE.nineslice and NE.nineslice.ApplyLayout then NE.nineslice.ApplyLayout(ns, "PortraitFrameTemplate") end
  f.NineSlice = ns

  -- Title. DOWNPORT: PC.SetTitle only writes into frame.TitleContainer.TitleText or frame.Title.
  -- A bare Frame has NEITHER, so SetTitle silently no-op'd and the title bar rendered blank.
  -- Build the band + string ourselves (same as modules/professions/Window.lua) and expose it as
  -- f.Title so every later NE.panelchrome.SetTitle(f, ...) call drives it.
  local tc = CreateFrame("Frame", nil, f)
  tc:SetFrameLevel((ns:GetFrameLevel() or 2) + 10)
  tc:SetPoint("TOPLEFT",  f, "TOPLEFT",  58, -1)
  tc:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -1)
  tc:SetHeight(20); tc:EnableMouse(false)
  local titleStr = tc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleStr:SetJustifyH("CENTER")
  titleStr:SetPoint("TOP",   f, "TOP",    0,  -6)
  titleStr:SetPoint("LEFT",  f, "LEFT",   58,  0)
  titleStr:SetPoint("RIGHT", f, "RIGHT", -58,  0)
  titleStr:SetText(FRIENDS_LIST or "Friends List")
  f.TitleContainer = tc
  f.TitleText = titleStr
  f.Title = titleStr

  local close = CreateFrame("Button", FRAME_NAME .. "CloseButton", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 0)
  close:SetScript("OnClick", function() SO.Hide() end)
  if NE.panelchrome and NE.panelchrome.ModernizeCloseButton then
    NE.panelchrome.ModernizeCloseButton(close, { frameLevelBump = 10 })
  end

  -- Portrait. DOWNPORT: a bare Frame (no XML template) has no built-in portrait region — build one
  -- explicitly into the nineslice's circular cutout corner (same recipe as modules/professions +
  -- modules/spellbook + modules/guild/Window.lua).
  if not f.PortraitTex then
    f.PortraitTex = ns:CreateTexture(nil, "ARTWORK")
  end
  if NE.portrait and NE.portrait.ApplyCutout then
    NE.portrait.ApplyCutout(f.PortraitTex, f)
  end
  if f.PortraitTex.SetMask then
    f.PortraitTex:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  end
  f.PortraitTex:SetTexture("Interface\\FriendsFrame\\FriendsFrameScrollIcon")
end

-- ---------------------------------------------------------------------------
-- Content panels (one per non-action tab). Exposed as parentKeys for the list files.
-- ---------------------------------------------------------------------------
local function buildPanels(f)
  for _, t in ipairs(TABS) do
    if t.panel then
      local p = CreateFrame("Frame", FRAME_NAME .. t.panel, f)
      p:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -44)
      p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 36)
      p:Hide()
      f[t.panel] = p
    end
  end
end

-- ---------------------------------------------------------------------------
-- Tabs (CharacterFrameTabButtonTemplate + shared reskin, same as AH).
-- ---------------------------------------------------------------------------
local function buildTabs(f)
  f._tabNames = {}
  f._tabIds = {}
  for i, t in ipairs(TABS) do
    local name = FRAME_NAME .. "Tab" .. i
    local tab = CreateFrame("Button", name, f, "CharacterFrameTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(t.label)
    tab._mode = t.mode
    tab._action = t.action
    tab:SetScript("OnClick", function(self) SO.SetMode(self._mode) end)
    f._tabNames[#f._tabNames + 1] = name
    f._tabIds[t.mode] = i
    if NE.tabs and NE.tabs.ReskinClassicTab then NE.tabs.ReskinClassicTab(name) end
  end
  if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #TABS) end
  if NE.tabs and NE.tabs.SizeAndAnchorTabs then
    NE.tabs.SizeAndAnchorTabs(f, f._tabNames, { startX = 16, startY = 2, parentPoint = "BOTTOMLEFT" })
  end
end

-- /who result routing. SetWhoToUI(1) makes the SERVER send who-results to the UI (firing
-- WHO_LIST_UPDATE) instead of printing them to chat. It's a GLOBAL, sticky flag, so we only turn
-- it on while our Who tab is actually the visible tab, and turn it back off otherwise — otherwise
-- every /who the player typed got hijacked into the UI (and Blizzard's WHO_LIST_UPDATE handler
-- then force-showed the old FriendsFrame on top of ours).
function SO.SetWhoRouting(toUI)
  if SetWhoToUI then SetWhoToUI(toUI and 1 or 0) end
end

-- The stock window retitles itself per tab ("Friends List" / "Who List" / "Chat Channels" /
-- "Raid") rather than carrying one static title — mirror that.
local TITLE_BY_MODE = {
  FRIENDS = FRIENDS_LIST or "Friends List",
  WHO     = WHO_LIST or ((WHO or "Who") .. " " .. (LIST_LABEL or "List")),
  CHAT    = CHAT_CHANNELS or "Chat Channels",
  RAID    = RAID or "Raid",
}

local function setTitleForMode(f, mode)
  local t = TITLE_BY_MODE[mode] or (FRIENDS or "Friends")
  if NE.panelchrome and NE.panelchrome.SetTitle then
    NE.panelchrome.SetTitle(f, t)
  elseif f.TitleText then
    f.TitleText:SetText(t)
  end
end

function SO.SetMode(mode)
  local f = SO.frame
  if not f then return end

  -- Guild is an action tab: open the guild window, keep the friends window on its current tab.
  if mode == "GUILD" then
    if NE.guild and NE.guild.Toggle then NE.guild.Toggle() end
    if PanelTemplates_SetTab and f._currentTab then PanelTemplates_SetTab(f, f._currentTab) end
    return
  end

  for _, t in ipairs(TABS) do
    if t.panel and f[t.panel] then f[t.panel]:SetShown(t.mode == mode) end
  end
  f._mode = mode
  local id = f._tabIds[mode]
  if id then
    f._currentTab = id
    if PanelTemplates_SetTab then PanelTemplates_SetTab(f, id) end
  end
  setTitleForMode(f, mode)

  -- Route who-results to the UI only while the Who tab is up (and the window is open).
  SO.SetWhoRouting(mode == "WHO" and f:IsShown())

  if mode == "FRIENDS" then
    if ShowFriends then ShowFriends() end
    if SO.RefreshFriends then SO.RefreshFriends() end
    if SO.RefreshIgnore then SO.RefreshIgnore() end
  elseif mode == "WHO" then
    if SO.RefreshWho then SO.RefreshWho() end
  elseif mode == "CHAT" then
    if SO.RefreshChannels then SO.RefreshChannels() end
  elseif mode == "RAID" then
    if SO.RefreshRaid then SO.RefreshRaid() end
  end
end

-- ---------------------------------------------------------------------------
-- Construction + show/hide.
-- ---------------------------------------------------------------------------
local function createWindow()
  if SO.frame then return SO.frame end

  -- DOWNPORT: bare Frame, not template-inherited — see the comment in modules/guild/Window.lua's
  -- createWindow() for why (the AH module's template-inheritance approach left f.portrait unset).
  local f = CreateFrame("Frame", FRAME_NAME, UIParent)
  f:SetSize(620, 560)   -- owner steer: ~30% larger than the first pass (+ room for 6 tabs)
  f:SetPoint("LEFT", UIParent, "LEFT", 16, 0)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  f:Hide()
  SO.frame = f

  buildChrome(f)
  buildPanels(f)
  buildTabs(f)

  if SO.SetupFriends then SO.SetupFriends(f) end
  if SO.SetupWho then SO.SetupWho(f) end
  if SO.SetupChannels then SO.SetupChannels(f) end
  if SO.SetupRaid then SO.SetupRaid(f) end

  f:HookScript("OnShow", function()
    if ShowFriends then ShowFriends() end
    if SO.RefreshFriends then SO.RefreshFriends() end
    SO.SetWhoRouting(f._mode == "WHO")
  end)
  -- Stop hijacking /who once our window is closed (the flag is global + sticky).
  f:HookScript("OnHide", function() SO.SetWhoRouting(false) end)

  if NE.FrameUtil and NE.FrameUtil.WirePanelSounds then
    NE.FrameUtil.WirePanelSounds(f, "igCharacterInfoOpen", "igCharacterInfoClose")
  end
  if NE.FrameUtil and NE.FrameUtil.EscClose then NE.FrameUtil.EscClose(FRAME_NAME) end
  if NE.panelchrome and NE.panelchrome.PinPixelPerfect then NE.panelchrome.PinPixelPerfect(f) end

  SO.SetMode("FRIENDS")
  return f
end

function SO.Show()
  if not isModuleEnabled() then return end
  createWindow():Show()
end
function SO.Hide() if SO.frame then SO.frame:Hide() end end
function SO.Toggle()
  local f = createWindow()
  if f:IsShown() then SO.Hide() else SO.Show() end
end

-- Route the game's "open friends" verb to our window.
local wired = false
local function wireRedirects()
  if wired then return end
  wired = true
  if type(_G.ToggleFriendsFrame) == "function" then
    local orig = _G.ToggleFriendsFrame
    _G.ToggleFriendsFrame = function(tab)
      if isModuleEnabled() then
        SO.Toggle()
        return
      end
      return orig(tab)
    end
  end

  -- Suppress the native FriendsFrame. Blizzard's own WHO_LIST_UPDATE handler calls
  -- FriendsFrame_ShowSubFrame("WhoFrame") + ShowUIPanel(FriendsFrame), which popped the OLD
  -- window up next to ours whenever who-results came back to the UI. Hide it and show ours.
  local ff = _G.FriendsFrame
  if ff and not ff._neSocialHooked then
    ff._neSocialHooked = true
    ff:HookScript("OnShow", function(self)
      if isModuleEnabled() then
        self:Hide()
        SO.Show()
      end
    end)
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
  if isModuleEnabled() then createWindow() end
  wireRedirects()
  if NE.RegisterPanel then
    NE.RegisterPanel({
      id = MODULE,
      title = SOCIALS or FRIENDS or "Social",
      desc = "Modern friends window (Friends / Ignore / Who) with a Guild tab.",
      frame = SO.frame,
      openFn = SO.Show,
      closeFn = SO.Hide,
      order = 55,
    })
  end
end)
