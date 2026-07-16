-- DragonUI_NewEra/modules/guild/Window.lua — modern Guild panel shell (NE_GuildFrame).
--
-- DOWNPORT of NewEra/Guild/Guild.lua. NewEra clones retail's Blizzard_Communities window using
-- retail-only kit (WowScrollBoxList / ColumnDisplayTemplate / WowStyle1DropdownTemplate /
-- NE_PortraitWindowTemplate / min-max / C_GuildInfo). None of that exists on 3.3.5a, so this is a
-- REBUILD on the same recipe the Auction House port uses (modules/auctionhouse/Window.lua):
--   rock body + TopTileStreaks + PortraitFrameTemplate nineslice + portrait + title + close.
--
-- WotLK-real scope (owner decision 2026-07-15): keep the modern Communities LOOK, but only ship
-- what 3.3.5a actually serves — Roster / Guild Info / Guild Chat + guild control buttons. The
-- retail Benefits/Rewards/Reputation tab, ClubFinder recruitment, calendar and minimize-to-chat
-- are CUT (all Cata+ systems, phantom here) — same philosophy NewEra applies for vanilla Era.
--
-- RENDER-BEFORE-WIRE: this file builds the shell (chrome, side tabs, mode switching, empty content
-- panels exposed as parentKeys). Live data wires in Roster.lua / Info.lua / Chat.lua via
-- G.SetupRoster / G.SetupInfo / G.SetupChat, guarded so load order can't crash.

local NE = DragonUI_NewEra
if not NE then return end

NE.guild = NE.guild or {}
local G = NE.guild

local FRAME_NAME = "NE_GuildFrame"
local MODULE = "Guild"

-- Display modes → the content panel parentKeys shown for each. ROSTER opens first (owner steer
-- 2026-07-15 — retail itself defaults to Chat, but Roster is more useful as the first thing seen).
-- GUILD_INFO combines the Info + Chat panels side by side in one view (owner steer 2026-07-16):
-- Info takes the LEFT 25%, Chat the RIGHT 75% of the content area.
local MODE = {
  ROSTER     = { "RosterFrame" },
  GUILD_INFO = { "InfoFrame", "ChatFrame" },
}
local ALL_PANELS = { "RosterFrame", "InfoFrame", "ChatFrame" }

-- Side tabs (right edge). WotLK-available icons only (retail's guild-perk icons are Cata+).
local TAB_DEFS = {
  { key = "RosterTab", mode = "ROSTER",     icon = "Interface\\Icons\\INV_Misc_GroupLooking", tip = GUILD_ROSTER_TITLE or "Roster" },
  { key = "InfoTab",   mode = "GUILD_INFO", icon = "Interface\\Icons\\INV_Scroll_03",         tip = (GUILD_INFORMATION or "Guild Information") .. " / " .. (CHAT or "Chat") },
}

-- Mirror AH's per-module enable gate (DragonUI profile.newera.modules[MODULE].enabled).
local function isModuleEnabled()
  local dragon = NE.dragon
  if not (dragon and dragon.db and dragon.db.profile and dragon.db.profile.newera) then return true end
  local m = dragon.db.profile.newera.modules and dragon.db.profile.newera.modules[MODULE]
  if type(m) == "table" and m.enabled ~= nil then return m.enabled and true or false end
  return true
end

-- ---------------------------------------------------------------------------
-- Chrome (rock body + streaks + nineslice + portrait + title + close).
-- Lifted from modules/auctionhouse/Window.lua:buildChrome, guild-specific title/portrait.
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
  titleStr:SetText(GUILD or "Guild")
  f.TitleContainer = tc
  f.TitleText = titleStr
  f.Title = titleStr

  local close = CreateFrame("Button", FRAME_NAME .. "CloseButton", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, 0)
  close:SetScript("OnClick", function() G.Hide() end)
  if NE.panelchrome and NE.panelchrome.ModernizeCloseButton then
    NE.panelchrome.ModernizeCloseButton(close, { frameLevelBump = 10 })
  end

  -- Portrait = the guild crest plate. DOWNPORT: a bare Frame (no XML template) has no built-in
  -- portrait region — build one explicitly into the nineslice's circular cutout corner, same
  -- recipe as modules/professions/Window.lua / modules/spellbook/Window.lua (NE.portrait.ApplyCutout
  -- + the 3.3.5a SetMask fallback, since CreateMaskTexture is non-functional here).
  if not f.PortraitTex then
    f.PortraitTex = ns:CreateTexture(nil, "ARTWORK")
  end
  if NE.portrait and NE.portrait.ApplyCutout then
    NE.portrait.ApplyCutout(f.PortraitTex, f)
  end
  if f.PortraitTex.SetMask then
    f.PortraitTex:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
  end
  f.PortraitTex:SetTexture("Interface\\GuildFrame\\GuildLogo-NoLogo")
end

-- ---------------------------------------------------------------------------
-- Right-edge side tabs (native SpellBook-SkillLineTab plate + centered icon). WotLK-reliable
-- (retail CommunitiesFrameTabTemplate art + WowScrollBox side-tab kit don't exist here).
-- ---------------------------------------------------------------------------
local SKILLTAB = "Interface\\SpellBook\\SpellBook-SkillLineTab"

local function buildSideTabs(f)
  f.SideTabs = {}
  local prev
  for i, d in ipairs(TAB_DEFS) do
    local tab = CreateFrame("Button", FRAME_NAME .. d.key, f)
    tab:SetSize(32, 32)
    if prev then
      tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -22)
    else
      tab:SetPoint("TOPLEFT", f, "TOPRIGHT", -2, -44)
    end

    local plate = tab:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture(SKILLTAB)
    plate:SetSize(64, 64)
    plate:SetPoint("CENTER", tab, "CENTER", 12, -8)
    tab._plate = plate

    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28); icon:SetPoint("CENTER")
    icon:SetTexture(d.icon)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    tab.Icon = icon

    -- Active-state glow below the icon (CheckedTexture would draw over it).
    local glow = tab:CreateTexture(nil, "ARTWORK", nil, -1)
    glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    glow:SetBlendMode("ADD"); glow:SetAllPoints(tab); glow:Hide()
    tab._glow = glow

    tab:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")

    tab._mode = d.mode
    tab:SetScript("OnClick", function(self)
      G.SetDisplayMode(self._mode)
      if PlaySound then PlaySound("igMainMenuOptionCheckBoxOn") end
    end)
    tab:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(d.tip)
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f[d.key] = tab
    f.SideTabs[i] = tab
    prev = tab
  end
end

-- ---------------------------------------------------------------------------
-- Content panels.
--
-- The left guild column (the single-guild "CommunitiesList" analogue: banner plate + crest +
-- guild name + member count) was REMOVED at the owner's request 2026-07-16 — on 3.3.5a there's
-- exactly one guild and no Battle.net communities, so the column only ever held one entry and
-- cost ~180px of roster width. The guild name lives in the window title; the member count moved
-- onto the roster header row (Roster.lua).
-- ---------------------------------------------------------------------------
local function inset(parent, tlx, tly, brx, bry)
  local ns = CreateFrame("Frame", nil, parent)
  ns:SetPoint("TOPLEFT", parent, "TOPLEFT", tlx or 0, tly or 0)
  ns:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", brx or 0, bry or 0)
  ns:EnableMouse(false)
  if NE.nineslice and NE.nineslice.ApplyLayout then NE.nineslice.ApplyLayout(ns, "InsetFrameTemplate") end
  parent._inset = ns
  return ns
end
G.Inset = inset

-- Each content panel now spans the FULL window width (the left column is gone).
local function contentPanel(f, key)
  local p = CreateFrame("Frame", FRAME_NAME .. key, f)
  p:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
  p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 34)
  p:Hide()
  f[key] = p
  return p
end

local function buildPanels(f)
  contentPanel(f, "RosterFrame")

  -- Info + Chat are combined into a single side-by-side view: Info gets the LEFT 25% of the
  -- content area, Chat the RIGHT 75%, with a small gap between them (owner steer 2026-07-16).
  local info = contentPanel(f, "InfoFrame")
  local chat = contentPanel(f, "ChatFrame")
  local GAP = 8
  local contentW = f:GetWidth() - 24   -- 12 + 12 side insets, matching contentPanel()
  local infoW = math.floor((contentW - GAP) * 0.25 + 0.5)
  local chatW = contentW - GAP - infoW

  info:ClearAllPoints()
  info:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
  info:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 34)
  info:SetWidth(infoW)

  chat:ClearAllPoints()
  chat:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -48)
  chat:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 34)
  chat:SetWidth(chatW)
end

-- ---------------------------------------------------------------------------
-- Bottom controls (Invite / Guild Control / View Log). Per-mode visibility mirrors retail.
-- ---------------------------------------------------------------------------
local function buildControls(f)
  local log = CreateFrame("Button", FRAME_NAME .. "LogButton", f, "UIPanelButtonTemplate")
  log:SetSize(120, 22)
  log:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 6)
  log:SetText(GUILD_EVENT_LOG or "View Log")
  -- 3.3.5a ships GuildEventLogFrame inside FriendsFrame (FriendsFrame.xml), so it exists but its
  -- default anchor is the old GuildControlPopupFrame — off-screen from our window. We reparent it,
  -- re-anchor it to the RIGHT of our guild frame, and skin it to match the NewEra chrome (once).
  local function skinEventLog(elf)
    if elf._neSkinned then return end
    elf._neSkinned = true

    -- Strip the default parchment backdrop.
    if elf.SetBackdrop then elf:SetBackdrop(nil) end

    -- Rock body (same as every other NE window).
    local body = elf:CreateTexture(nil, "BACKGROUND", nil, -8)
    local rockPath = NE.tex and NE.tex.localFiles and NE.tex.localFiles[374155]
    body:SetTexture(rockPath or 374155, "REPEAT", "REPEAT")
    body:SetHorizTile(true); body:SetVertTile(true)
    body:SetPoint("TOPLEFT",  elf, "TOPLEFT",  0, -21)
    body:SetPoint("BOTTOMRIGHT", elf, "BOTTOMRIGHT", 0, 0)

    -- TopTileStreaks banner.
    local streaks = elf:CreateTexture(nil, "BORDER")
    if NE.tex and NE.tex.SetAtlas then NE.tex.SetAtlas(streaks, "_UI-Frame-TopTileStreaks", false) end
    streaks:SetPoint("TOPLEFT",  elf, "TOPLEFT",  6, -21)
    streaks:SetPoint("TOPRIGHT", elf, "TOPRIGHT", -2, -21)
    streaks:SetHeight(43); streaks:SetHorizTile(true)

    -- NineSlice chrome: no-portrait layout so the top-left corner is flat (no circular cutout).
    local ns = CreateFrame("Frame", nil, elf)
    ns:SetAllPoints(elf)
    if NE.nineslice and NE.nineslice.ApplyLayout then NE.nineslice.ApplyLayout(ns, "ButtonFrameTemplateNoPortrait") end

    -- Re-skin the title to sit in our title bar (no portrait, so left offset matches centre).
    local titleStr = _G.GuildEventLogTitle
    if titleStr then
      titleStr:ClearAllPoints()
      titleStr:SetPoint("TOP",   elf, "TOP",    0,  -6)
      titleStr:SetPoint("LEFT",  elf, "LEFT",   12,  0)
      titleStr:SetPoint("RIGHT", elf, "RIGHT", -12,  0)
      titleStr:SetFontObject(GameFontNormal)
      titleStr:SetJustifyH("CENTER")
    end

    -- Replace the old stone close button with our modernized one.
    local oldClose = _G.GuildEventLogCloseButton
    if oldClose then
      if NE.panelchrome and NE.panelchrome.ModernizeCloseButton then
        NE.panelchrome.ModernizeCloseButton(oldClose, { frameLevelBump = 10 })
      end
      oldClose:ClearAllPoints()
      oldClose:SetPoint("TOPRIGHT", elf, "TOPRIGHT", 1, 0)
    end

    -- Strip the inner frame's parchment backdrop.
    local inner = _G.GuildEventFrame
    if inner and inner.SetBackdrop then inner:SetBackdrop(nil) end
    if inner then
      -- Recessed inset well around the scroll area.
      if NE.nineslice and NE.nineslice.AttachInset then
        pcall(NE.nineslice.AttachInset, inner, 0, 0, 0, 0)
      end
    end

    -- Register with UISpecialFrames so Escape closes the log on its own (once, after skin applied).
    if _G.UISpecialFrames then
      tinsert(_G.UISpecialFrames, "GuildEventLogFrame")
    end

    -- Hide the redundant bottom "Close" button — the corner X is sufficient.
    local cancelBtn = _G.GuildEventLogCancelButton
    if cancelBtn then cancelBtn:Hide() end
  end

  log:SetScript("OnClick", function()
    local elf = _G.GuildEventLogFrame
    if not elf then return end
    if elf:IsShown() then
      elf:Hide()
    else
      if QueryGuildEventLog then QueryGuildEventLog() end
      elf:SetParent(UIParent)
      elf:SetFrameStrata("DIALOG")
      elf:SetToplevel(true)
      elf:ClearAllPoints()
      elf:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
      skinEventLog(elf)
      elf:Show()
    end
  end)
  f.LogButton = log

  local control = CreateFrame("Button", FRAME_NAME .. "ControlButton", f, "UIPanelButtonTemplate")
  control:SetSize(120, 22)
  control:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 6)
  control:SetText(GUILDCONTROL or "Guild Control")
  control:SetScript("OnClick", function()
    if GuildControlUI_LoadUI then GuildControlUI_LoadUI() end
    if _G.GuildControlUI and ShowUIPanel then ShowUIPanel(_G.GuildControlUI) end
  end)
  f.ControlButton = control

  local invite = CreateFrame("Button", FRAME_NAME .. "InviteButton", f, "UIPanelButtonTemplate")
  invite:SetSize(120, 22)
  invite:SetPoint("RIGHT", control, "LEFT", -4, 0)
  invite:SetText(GUILD_INVITE_MEMBER or COMMUNITIES_INVITE_MEMBERS or "Invite")
  f.InviteButton = invite

  -- Inline name prompt for the invite. This previously called StaticPopup_Show("ADD_GUILDMEMBER"),
  -- which silently returns nil (doing nothing) when no dialog of that name is defined — the exact
  -- failure the Social "Add Friend" button hit on this client. Drive GuildInvite() directly instead.
  local prompt = CreateFrame("Frame", nil, f)
  prompt:SetPoint("BOTTOMLEFT",  invite, "TOPLEFT",  -80, 6)
  prompt:SetPoint("BOTTOMRIGHT", control, "TOPRIGHT", 0, 6)
  prompt:SetHeight(26)
  prompt:SetFrameLevel(f:GetFrameLevel() + 20)
  prompt:Hide()
  local fill = prompt:CreateTexture(nil, "BACKGROUND")
  fill:SetTexture("Interface\\Buttons\\WHITE8X8")
  fill:SetVertexColor(0.06, 0.06, 0.07, 0.95)
  fill:SetAllPoints(prompt)
  local lbl = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lbl:SetPoint("LEFT", prompt, "LEFT", 6, 0)
  lbl:SetText(GUILD_INVITE_MEMBER or "Invite")
  local box = CreateFrame("EditBox", nil, prompt, "InputBoxTemplate")
  box:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
  box:SetPoint("RIGHT", prompt, "RIGHT", -8, 0)
  box:SetHeight(20); box:SetAutoFocus(false); box:SetMaxLetters(12)
  box:SetScript("OnEnterPressed", function(self)
    local t = self:GetText()
    if t and t ~= "" and GuildInvite then GuildInvite(t) end
    self:SetText(""); self:ClearFocus(); prompt:Hide()
  end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); prompt:Hide() end)
  f.InvitePrompt = prompt

  invite:SetScript("OnClick", function() prompt:Show(); box:SetFocus() end)
end

-- ---------------------------------------------------------------------------
-- Display-mode switching (retail CommunitiesFrameMixin:SetDisplayMode, guild subset).
-- ---------------------------------------------------------------------------
function G.SetDisplayMode(mode)
  local f = G.frame
  if not f or not MODE[mode] then return end
  f.displayMode = mode
  for _, key in ipairs(ALL_PANELS) do if f[key] then f[key]:Hide() end end
  for _, key in ipairs(MODE[mode]) do if f[key] then f[key]:Show() end end

  for _, d in ipairs(TAB_DEFS) do
    local tab = f[d.key]
    if tab then
      local active = (d.mode == mode)
      if tab._glow then tab._glow:SetShown(active) end
    end
  end

  -- Bottom controls per mode: Invite in Roster/Info+Chat, Guild Control in Roster/Info+Chat, Log in Info+Chat.
  if f.InviteButton  then f.InviteButton:SetShown(mode == "ROSTER" or mode == "GUILD_INFO") end
  if f.ControlButton then f.ControlButton:SetShown(mode == "ROSTER" or mode == "GUILD_INFO") end
  if f.LogButton     then f.LogButton:SetShown(mode == "GUILD_INFO") end

  if mode == "ROSTER" and G.RefreshRoster then G.RefreshRoster() end
  if mode == "GUILD_INFO" and G.RefreshInfo then G.RefreshInfo() end
end

-- ---------------------------------------------------------------------------
-- Construction + show/hide.
-- ---------------------------------------------------------------------------
local function createWindow()
  if G.frame then return G.frame end

  -- DOWNPORT: a bare Frame (no "PortraitFrameTemplate" widget-template inheritance) — matches
  -- modules/professions + modules/spellbook + modules/character, NOT the Auction House module's
  -- template-inherited approach. On this client, inheriting the template didn't yield a usable
  -- f.portrait region and left the chrome looking flat; every OTHER window in this addon builds
  -- 100% of its chrome (body/streaks/nineslice/portrait) manually on a plain frame, which is the
  -- proven-working pattern.
  local f = CreateFrame("Frame", FRAME_NAME, UIParent)
  f:SetSize(990, 582)   -- owner steer: ~30% larger than the first pass
  f:SetPoint("LEFT", UIParent, "LEFT", 16, 0)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:SetClampedToScreen(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  f:Hide()
  G.frame = f

  buildChrome(f)
  buildPanels(f)
  buildSideTabs(f)
  buildControls(f)

  -- Data layers (each guarded; built once, before the first SetDisplayMode).
  if G.SetupRoster then G.SetupRoster(f) end
  if G.SetupInfo   then G.SetupInfo(f) end
  if G.SetupChat   then G.SetupChat(f) end

  f:HookScript("OnShow", function()
    local gname = IsInGuild and IsInGuild() and GetGuildInfo("player")
    if NE.panelchrome and NE.panelchrome.SetTitle then NE.panelchrome.SetTitle(f, gname or (GUILD or "Guild")) end
    if GuildRoster then GuildRoster() end   -- request a fresh roster on open
    if G.RefreshRoster then G.RefreshRoster() end
    if G.RefreshInfo then G.RefreshInfo() end
  end)

  -- Close the event log popup whenever the guild window itself hides.
  f:HookScript("OnHide", function()
    if _G.GuildEventLogFrame and _G.GuildEventLogFrame:IsShown() then
      _G.GuildEventLogFrame:Hide()
    end
  end)

  if NE.FrameUtil and NE.FrameUtil.WirePanelSounds then
    NE.FrameUtil.WirePanelSounds(f, "igCharacterInfoOpen", "igCharacterInfoClose")
  end
  if NE.FrameUtil and NE.FrameUtil.EscClose then NE.FrameUtil.EscClose(FRAME_NAME) end
  if NE.panelchrome and NE.panelchrome.PinPixelPerfect then NE.panelchrome.PinPixelPerfect(f) end

  G.SetDisplayMode("ROSTER")   -- owner steer 2026-07-15: Roster is the default tab, not Chat
  return f
end

function G.Show()
  if not isModuleEnabled() then return end
  local f = createWindow()
  -- If the Social/Friends window is open (its Guild tab is what usually launches us), open to its
  -- RIGHT instead of stacking on the same default LEFT anchor (both windows default to
  -- UIParent LEFT +16 -- identical spots -- so without this they land fully overlapped).
  local social = NE.social and NE.social.frame
  if social and social:IsShown() then
    f:ClearAllPoints()
    f:SetPoint("LEFT", social, "RIGHT", 8, 0)
  end
  f:Show()
end
function G.Hide() if G.frame then G.frame:Hide() end end
function G.Toggle()
  local f = createWindow()
  if f:IsShown() then G.Hide() else G.Show() end
end

-- Boot: build the shell at login so it's warm, register with the options/QA seams.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
  if isModuleEnabled() then createWindow() end
  if NE.RegisterPanel then
    NE.RegisterPanel({
      id = MODULE,
      title = GUILD or "Guild",
      desc = "Modern Communities-style guild window (Roster / Info / Chat).",
      frame = G.frame,
      openFn = G.Show,
      closeFn = G.Hide,
      order = 60,
    })
  end
end)
