-- DragonUI_NewEra/modules/guild/Window.lua — modern Guild panel shell (NE_GuildFrame).
--
-- DOWNPORT of NewEra/Guild/Guild.lua. NewEra clones retail's Blizzard_Communities window using
-- retail-only kit (WowScrollBoxList / ColumnDisplayTemplate / WowStyle1DropdownTemplate /
-- NE_PortraitWindowTemplate / min-max / C_GuildInfo). None of that exists on 3.3.5a, so this is a
-- REBUILD on the same recipe the Auction House port uses (modules/auctionhouse/Window.lua):
--   rock body + TopTileStreaks + PortraitFrameTemplate nineslice + portrait + title + close.
--
-- WotLK-real scope (owner decision 2026-07-15): keep the modern Communities LOOK, but only ship
-- what 3.3.5a actually serves — Roster / Guild Info (+ Guild Chat, sharing that same tab) + guild
-- control buttons. The retail Benefits/Rewards/Reputation tab, ClubFinder recruitment, calendar and
-- minimize-to-chat are CUT (all Cata+ systems, phantom here) — same philosophy NewEra applies for
-- vanilla Era.
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
-- GUILD_INFO now shows BOTH InfoFrame and ChatFrame side by side (owner steer 2026-07-17: "combine
-- the chat and guild info tabs... guild info on the left, chat on the right, chat gets 75%") — the
-- tab keeps its original name/tooltip ("Guild Information"), it just also holds Chat now. ROSTER is
-- the ONE mode that shows the left GuildColumn (owner steer 2026-07-17: "I actually wanted this
-- blue left pane only on the roster tab") — the column isn't a per-mode content panel like the
-- other two, it's a persistent sidebar toggled separately in SetDisplayMode below.
local MODE = {
  ROSTER     = { "RosterFrame" },
  GUILD_INFO = { "InfoFrame", "ChatFrame" },
}
local ALL_PANELS = { "RosterFrame", "InfoFrame", "ChatFrame" }

-- Side tabs (right edge). WotLK-available icons only (retail's guild-perk icons are Cata+).
-- Only 2 tabs now — Chat was folded into the Guild Info tab (see MODE above), so there's no
-- separate ChatTab side button anymore.
local TAB_DEFS = {
  { key = "RosterTab", mode = "ROSTER",     icon = "Interface\\Icons\\INV_Misc_GroupLooking", tip = GUILD_ROSTER_TITLE or "Roster" },
  { key = "InfoTab",   mode = "GUILD_INFO", icon = "Interface\\Icons\\INV_Scroll_03",         tip = GUILD_INFORMATION or "Guild Information" },
}

-- Gated entirely by the options panel's single "Social (Friends/Who/Guild/Chat/Raid)" checkbox
-- (id "Social") — there is no separate Guild row, so Guild has no enable flag of its own; consult
-- ONLY modules.Social. (A short-lived separate "Guild" toggle briefly existed and was removed —
-- do NOT resurrect a modules[MODULE] check here, or a stray leftover modules.Guild.enabled=false
-- from that toggle's use would wedge Guild disabled forever with no control left to undo it.)
local function isModuleEnabled()
  local dragon = NE.dragon
  if not (dragon and dragon.db and dragon.db.profile and dragon.db.profile.newera) then return true end
  local modules = dragon.db.profile.newera.modules
  local social = modules and modules.Social
  if type(social) == "table" and social.enabled == false then return false end
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
  -- Left edge inset 4px (owner steer 2026-07-17, measured from a cropped screenshot: "it sticks out
  -- 4 pixels"). An 8px OUTWARD overhang was tried first and made the sliver bigger, not smaller —
  -- confirming the border's opaque coverage falls INSIDE the frame's nominal left edge, not past
  -- it, so body needs to be pulled IN (positive x), not pushed out. Right/bottom left flush — no
  -- sliver reported there at this baseline, only the left edge.
  body:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -21)
  body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

  local ns = CreateFrame("Frame", nil, f)
  ns:SetAllPoints(f)
  -- Flat (non-portrait) corner — no circular cutout (owner steer 2026-07-17: "remove the circle
  -- again"). The guild crest already has a proper home in the GuildColumn banner (buildGuildColumn
  -- below), so this window doesn't need a corner portrait at all.
  if NE.nineslice and NE.nineslice.ApplyLayout then NE.nineslice.ApplyLayout(ns, "ButtonFrameTemplateNoPortrait") end
  f.NineSlice = ns

  -- The streaks band needs to sit in a NARROW gap in the stack, and neither obvious placement works:
  --   on `f`            -> underneath the nineslice child frame, invisible (draw layers don't help;
  --                        a child frame always beats its parent's textures)
  --   on `ns`           -> above the nineslice, but also above the guild column, so it covered the
  --                        crest
  -- So it gets its own frame, explicitly levelled ABOVE the nineslice and BELOW the guild column
  -- (which buildGuildColumn pins to base+10). Explicit levels rather than creation order, because
  -- same-level frames resolve by creation sequence — which is exactly the fragile, hard-to-see
  -- coupling that made this take several attempts.
  -- Sized to just the top strip the band actually occupies (SetPoint TOPLEFT/TOPRIGHT + height),
  -- NOT SetAllPoints(f) — a full-window frame at this level had no measurable reason to interfere
  -- with anything below it (it never calls EnableMouse, and neither does ApplyTopTileStreaks), but
  -- the Roster tab's "Show Offline" checkbox stopped responding to clicks right after that frame was
  -- introduced, in a build using an in-house 3.3.5a client + compat layer whose mouse-hit-testing
  -- defaults aren't guaranteed to match retail's. Rather than lean on an assumption about this
  -- client's EnableMouse semantics, remove the possibility outright: this frame now physically
  -- cannot cover the checkbox (or anything else past the title band), regardless of what it does or
  -- doesn't intercept.
  local sf = CreateFrame("Frame", nil, f)
  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  sf:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  sf:SetHeight(70)
  sf:SetFrameLevel((ns:GetFrameLevel() or 1) + 1)
  f.StreaksHost = sf
  if NE.nineslice and NE.nineslice.ApplyTopTileStreaks then
    NE.nineslice.ApplyTopTileStreaks(f, { parent = sf })
  end

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

  -- No corner portrait (owner steer 2026-07-17: reverted the round cutout for good — every attempt
  -- to fill it cleanly on this client either left it transparent, black, or otherwise wrong). The
  -- guild crest already lives in the GuildColumn banner, so there's no second copy needed here.
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
      -- Gap tightened 34 -> 14 (owner-reported 2026-07-17: "closer together" / "heap of space
      -- between them" — the 28 math assumed the plate's opaque art fills its whole 64x60 bounding
      -- box, but the sprite clearly has transparent padding, so that theoretical overlap floor
      -- doesn't match the real visible art). Going empirical instead: drop it further if there's
      -- still a gap after /reload.
      tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
    else
      -- x nudged -2 -> 3 (owner-measured 2026-07-17: "moved over to the right about 5 pixels").
      -- Subsequent tabs inherit this x via their 0-offset anchor to prev, so all tabs shift together.
      tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, -44)
    end

    -- Height cropped 64 -> 60 (owner-measured 2026-07-17: "reduced by about 3 pixels, remove this
    -- from the bottom"; adjusted to 60 after review). Re-anchored TOP instead of CENTER so the top
    -- edge stays put and only the bottom edge moves up — a plain SetSize under the old CENTER anchor
    -- would have trimmed both edges equally.
    local plate = tab:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture(SKILLTAB)
    plate:SetSize(64, 60)
    plate:SetPoint("TOP", tab, "CENTER", 12, 24)
    tab._plate = plate

    -- REVERTED 2026-07-17: tried centering on `plate` instead of `tab`, assuming the plate art's
    -- icon-hole sat at its geometric center — it didn't (owner: "that broke it a lot"), so the icon
    -- ended up spilling outside the tab shape entirely. Back to centering on `tab`; the plate's icon
    -- slot isn't at its own center, so anchoring to the tab's center (not the plate's) was actually
    -- closer. Fill-size/offset still needs a screenshot-measured tweak per the owner's original
    -- "icons dont fully fill them" report.
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
-- Content panels + the Roster-only left GuildColumn.
--
-- The left guild column (the single-guild "CommunitiesList" analogue) was removed entirely
-- 2026-07-16, restored the same day scoped to the Chat tab, then moved to the Roster tab
-- 2026-07-17 (owner: "I actually wanted this blue left pane only on the roster tab" — the Chat
-- placement was a mistake made while combining Info and Chat into one tab). Info and Chat stay
-- full-width — the column only shows next to Roster now.
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

-- Full-width content panel (Roster / Info).
local function contentPanel(f, key)
  local p = CreateFrame("Frame", FRAME_NAME .. key, f)
  p:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
  p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 34)
  p:Hide()
  f[key] = p
  return p
end

local GUILD_COLUMN_WIDTH = 180

-- The Roster-only left column: bluemenu decorative frame (owner: "reference NewEra for any missing
-- art" — pulled from ReferenceAddons/NewEra/Art/LFG/, the exact 3 files NewEra's own
-- Guild.lua:buildCommunitiesList reuses for this same panel) + a single static "entry" (there's
-- only ever one guild): banner plate + tabard crest badge + guild name + member count.
-- Texcoords transcribed verbatim from NewEra/Guild/Guild.lua:186-236 (raw SetTexture+SetTexCoord,
-- not atlas nicknames — matched here 1:1, see modules/guild/Assets.lua).
local function buildGuildColumn(f)
  local list = CreateFrame("Frame", FRAME_NAME .. "GuildColumn", f)
  -- Explicitly above the chrome's nineslice (base+1) and streaks host (base+2), so the crest and the
  -- column art are never painted over by window decoration. Previously this relied on being created
  -- later than those frames at the same level, which is invisible coupling and broke as soon as the
  -- streaks moved.
  list:SetFrameLevel((f:GetFrameLevel() or 0) + 10)
  list:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
  list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 34)
  list:SetWidth(GUILD_COLUMN_WIDTH)
  list:Hide()   -- shown only in ROSTER mode (SetDisplayMode)
  f.GuildColumn = list

  local function localTex(fdid) return NE.tex and NE.tex.localFiles and NE.tex.localFiles[fdid] end
  local BLUEMENU = localTex(593918)
  local BLUEVERT = localTex(593919)
  local BLUEGOLD = localTex(593917)

  if BLUEMENU then
    local bg = list:CreateTexture(nil, "ARTWORK", nil, 1)
    bg:SetTexture(BLUEMENU)
    bg:SetTexCoord(0.00390625, 0.82421875, 0.18554688, 0.58984375)
    bg:SetPoint("TOPLEFT",     list, "TOPLEFT",      2, 0)
    bg:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -2, 0)
    list.Bg = bg

    local topF = list:CreateTexture(nil, "ARTWORK", nil, 2)
    topF:SetTexture(BLUEMENU); topF:SetSize(155, 55)
    topF:SetTexCoord(0.00390625, 0.72656250, 0.12988281, 0.18359375)
    topF:SetPoint("TOPLEFT", list, "TOPLEFT", 14, -6)

    local botF = list:CreateTexture(nil, "ARTWORK", nil, 2)
    botF:SetTexture(BLUEMENU); botF:SetSize(155, 55)
    botF:SetTexCoord(0.26171875, 0.98437500, 0.06542969, 0.11914063)
    botF:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 14, 1)
  end

  inset(list, 3, 1, 0, -3)

  -- FilligreeOverlay — the gold corner frame around the list.
  if BLUEMENU and BLUEVERT and BLUEGOLD then
    local fo = CreateFrame("Frame", nil, list)
    fo:SetFrameLevel(list:GetFrameLevel() + 5)
    fo:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -1)
    fo:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -2, 0)
    list.FilligreeOverlay = fo

    local function corner(tc, p, x, y)
      local t = fo:CreateTexture(nil, "OVERLAY"); t:SetTexture(BLUEMENU); t:SetSize(64, 64)
      t:SetTexCoord(tc[1], tc[2], tc[3], tc[4]); t:SetPoint(p, fo, p, x, y); return t
    end
    local tl = corner({ 0.00390625, 0.25390625, 0.00097656, 0.06347656 }, "TOPLEFT", 3, 2)
    local tr = corner({ 0.51953125, 0.76953125, 0.00097656, 0.06347656 }, "TOPRIGHT", -1, 2)
    local br = corner({ 0.51171875, 0.26171875, 0.00097656, 0.06347656 }, "BOTTOMRIGHT", 0, 0)
    local bl = corner({ 0.26171875, 0.51171875, 0.00097656, 0.06347656 }, "BOTTOMLEFT", 3, 0)

    local leftBar = fo:CreateTexture(nil, "OVERLAY"); leftBar:SetTexture(BLUEVERT); leftBar:SetVertTile(true)
    leftBar:SetTexCoord(0.0625, 0.3984375, 0, 1); leftBar:SetSize(43, 247)
    leftBar:SetPoint("TOPLEFT", fo, "TOPLEFT", 3, -62)

    local rightBar = fo:CreateTexture(nil, "OVERLAY"); rightBar:SetTexture(BLUEVERT)
    rightBar:SetVertTile(true); rightBar:SetWidth(43)
    rightBar:SetTexCoord(0.4140625, 0.75, 0, 1)
    rightBar:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
    rightBar:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)

    local topBar = fo:CreateTexture(nil, "BORDER"); topBar:SetTexture(BLUEGOLD)
    topBar:SetHorizTile(true); topBar:SetHeight(43)
    topBar:SetTexCoord(0, 1, 0.0078125, 0.34375)
    topBar:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0); topBar:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)

    local botBar = fo:CreateTexture(nil, "BORDER"); botBar:SetTexture(BLUEGOLD)
    botBar:SetHorizTile(true); botBar:SetHeight(43)
    botBar:SetTexCoord(0, 1, 0.359375, 0.6953125)
    botBar:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0); botBar:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
  end

  -- The single guild "entry": banner plate (communities atlas — already registered) + tabard
  -- crest (real design via Tabard.lua when it resolves, else the static NoLogo crest) + name.
  local banner = list:CreateTexture(nil, "ARTWORK", nil, 3)
  -- SetAtlas RETURNS FALSE when the atlas entry or its bundled BLP can't be resolved, and on failure
  -- it applies neither texture nor size (size is only set on success). Ignoring that left a 0x0
  -- untextured banner — invisible, and useless to anchor against, which is what made the tabard
  -- crest render as an emblem floating over bare panel. Give it an explicit size so it is at least a
  -- valid anchor target, and record the outcome; Tabard.lua retries the atlas and falls back to the
  -- NoLogo crest as its plate while this stays false.
  banner:SetSize(74, 69)
  list.BannerAtlasOK = (NE.tex and NE.tex.SetAtlas
    and NE.tex.SetAtlas(banner, "communities-guildbanner-background", true)) or false
  banner:SetPoint("TOP", list, "TOP", 0, -46)
  list.Banner = banner

  local crest = list:CreateTexture(nil, "OVERLAY", nil, 4)
  crest:SetTexture("Interface\\GuildFrame\\GuildLogo-NoLogo")
  crest:SetSize(44, 44)
  crest:SetPoint("CENTER", banner, "CENTER", 0, 2)
  list.Crest = crest
  list.CrestSize = 40   -- box Tabard.lua sizes the emblem against; just inside the crest's edge

  local name = list:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  name:SetPoint("TOP", banner, "BOTTOM", 0, -12)
  name:SetPoint("LEFT", list, "LEFT", 8, 0)
  name:SetPoint("RIGHT", list, "RIGHT", -8, 0)
  name:SetJustifyH("CENTER")
  name:SetText(GUILD or "Guild")
  list.Name = name

  list.MemberCount = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  list.MemberCount:SetPoint("TOP", name, "BOTTOM", 0, -6)

  list.SetGuild = function(gname, online, total)
    name:SetText(gname or (GUILD or "Guild"))
    if online and total then
      list.MemberCount:SetText(string.format("%d/%d %s", online, total, GUILD_MEMBERS or "Members"))
    elseif total then
      list.MemberCount:SetText(string.format("%d %s", total, GUILD_MEMBERS or "Members"))
    else
      list.MemberCount:SetText("")
    end
  end

  if G.SetupTabard then G.SetupTabard(list) end
end

-- Guild Info gets the left 25% of the GUILD_INFO tab, Chat the remaining 75% (owner 2026-07-17).
-- Computed off the shared content area's width (990 frame - 12/-12 side margins = 966), minus the
-- 10px gap between the two panes.
local INFO_PANE_WIDTH = math.floor((966 - 10) * 0.25 + 0.5)

local function buildPanels(f)
  buildGuildColumn(f)

  -- Roster sits to the RIGHT of the (Roster-only) GuildColumn, not full-width.
  local roster = contentPanel(f, "RosterFrame")
  roster:ClearAllPoints()
  roster:SetPoint("TOPLEFT", f.GuildColumn, "TOPRIGHT", 10, 0)
  roster:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 34)

  -- Guild Info (narrow left column) + Chat (the rest) share the GUILD_INFO tab.
  local info = contentPanel(f, "InfoFrame")
  info:ClearAllPoints()
  info:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
  info:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 34)
  info:SetWidth(INFO_PANE_WIDTH)

  local chat = contentPanel(f, "ChatFrame")
  chat:ClearAllPoints()
  chat:SetPoint("TOPLEFT", info, "TOPRIGHT", 10, 0)
  chat:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 34)
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

    -- Hide any leftover native chrome baked directly onto the frame by its own XML template (the
    -- classic dialog corner/border art) — SetBackdrop(nil) above only clears an actual Backdrop, it
    -- doesn't touch plain Texture regions. One of those was showing as a stray gold-bordered square
    -- peeking out from behind our modernized close button (owner-reported 2026-07-17: "weird extra
    -- texture frame underneath the X"). Everything visual is redrawn by body/streaks/ns below, so any
    -- pre-existing Texture region on the frame itself is safe to hide outright (FontStrings, like the
    -- title, are left alone).
    for _, region in ipairs({ elf:GetRegions() }) do
      if region.GetObjectType and region:GetObjectType() == "Texture" then
        region:Hide()
      end
    end

    -- Rock body (same as every other NE window).
    local body = elf:CreateTexture(nil, "BACKGROUND", nil, -8)
    local rockPath = NE.tex and NE.tex.localFiles and NE.tex.localFiles[374155]
    body:SetTexture(rockPath or 374155, "REPEAT", "REPEAT")
    body:SetHorizTile(true); body:SetVertTile(true)
    -- Left edge inset 5px (owner-adjusted from the 4px in buildChrome's identical body texture
    -- above). Bottom edge inset 1px (owner-measured: "1 pixel sliver on the bottom"). Right left
    -- flush — no sliver reported there.
    body:SetPoint("TOPLEFT",  elf, "TOPLEFT",  5, -21)
    body:SetPoint("BOTTOMRIGHT", elf, "BOTTOMRIGHT", 0, 1)

    -- TopTileStreaks banner (shared helper: same geometry, plus retry on atlas failure).
    if NE.nineslice and NE.nineslice.ApplyTopTileStreaks then
      NE.nineslice.ApplyTopTileStreaks(elf)
    end

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
      -- Dark recessed backdrop behind the log text (owner steer 2026-07-17: "the dark background
      -- should be behind the text in the guild log") — same WHITE8X8 fill as the Roster/Chat
      -- panels, drawn first so the log lines sit on top of it.
      local logBg = inner:CreateTexture(nil, "BACKGROUND")
      logBg:SetTexture("Interface\\Buttons\\WHITE8X8")
      logBg:SetVertexColor(0.06, 0.06, 0.07, 0.90)
      logBg:SetAllPoints(inner)
      inner._neBg = logBg

      -- Recessed inset well around the scroll area.
      if NE.nineslice and NE.nineslice.AttachInset then
        pcall(NE.nineslice.AttachInset, inner, 0, 0, 0, 0)
      end
    end

    -- Modern minimal-scrollbar for the log's list (owner steer 2026-07-17: "the scrollbar in it
    -- rethemed to the modern one"). Names confirmed via /dump GuildEventFrame:GetChildren() in-game
    -- (owner-supplied): the real FauxScrollFrame is the global "GuildEventLogScrollFrame", with its
    -- hidden slider at "GuildEventLogScrollFrameScrollBar" + ...ScrollUpButton/...ScrollDownButton —
    -- exactly the shape NE.scrollbar.BuildCustom expects (name .. "ScrollBar", then
    -- sliderName .. "ScrollUpButton"/"ScrollDownButton"). An earlier attempt used
    -- NE.scrollbar.Reskin (in-place reskin of the stock Slider) and reverted 2026-07-17 — it made the
    -- bar disappear entirely, matching this same file's own documented reason BuildCustom exists at
    -- all ("Reskin ... was not rendering"). BuildCustom is the hand-built bar every other FauxScroll
    -- list in this addon already uses, so this now matches that established pattern instead.
    local logScroll = _G.GuildEventLogScrollFrame
    if logScroll and NE.scrollbar and NE.scrollbar.BuildCustom then
      local ok, bar = pcall(NE.scrollbar.BuildCustom, logScroll, { x = -8, alwaysShow = true })
      if ok and bar then
        -- Same strata trap hit repeatedly in the Auction House lists (see ScrollbarReskin.lua
        -- callers in modules/auctionhouse/Browse.lua): BuildCustom's bar defaults to "HIGH", but
        -- `elf` gets explicitly promoted to "DIALOG" strata whenever the log is shown (this file's
        -- OnClick handler below), so every descendant frame (inner/logScroll included) inherits
        -- DIALOG too — a HIGH-strata bar renders BEHIND that content, i.e. invisible. Force it up.
        bar:SetFrameStrata("DIALOG")
        bar:SetFrameLevel((inner and inner:GetFrameLevel() or 1) + 10)
        if bar._upBtn then bar._upBtn:SetFrameStrata("DIALOG"); bar._upBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
        if bar._downBtn then bar._downBtn:SetFrameStrata("DIALOG"); bar._downBtn:SetFrameLevel(bar:GetFrameLevel() + 1) end
      end
    end

    -- Register with UISpecialFrames so Escape closes the log on its own (once, after skin applied).
    if _G.UISpecialFrames then
      tinsert(_G.UISpecialFrames, "GuildEventLogFrame")
    end

    -- Hide the redundant bottom "Close" button — the corner X is sufficient.
    local cancelBtn = _G.GuildEventLogCancelButton
    if cancelBtn then cancelBtn:Hide() end

    -- Trim the empty rock-textured strip left below the list where that Cancel button used to sit
    -- (owner-reported 2026-07-17, screenshot with the strip circled: "the actual log area should
    -- either extend into the ... area or that area should be removed. Removing it might be
    -- better"). Measured live off the real content's bottom edge rather than a hardcoded offset,
    -- since the scroll frame's own size/anchors come from Blizzard's native XML, not this addon.
    -- Pulls the window's own bottom edge up to hug the content; body/streaks/ns are all anchored to
    -- elf itself, so they follow this resize automatically.
    if inner and logScroll then
      local innerBottom = inner:GetBottom()
      local scrollBottom = logScroll:GetBottom()
      local frameBottom = elf:GetBottom()
      if innerBottom and scrollBottom and frameBottom then
        local contentBottom = math.min(innerBottom, scrollBottom)
        local margin = 10
        local trim = (contentBottom - margin) - frameBottom
        if trim > 0 then
          elf:SetHeight(elf:GetHeight() - trim)
        end
      end
    end
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

  -- Stock Blizzard invite dialog (owner steer 2026-07-17: "should trigger the default blizzard
  -- invite window not its own"). REVERTED the inline name-prompt tried earlier — that was built on
  -- an unverified assumption that StaticPopup_Show("ADD_GUILDMEMBER") silently no-ops here; on a
  -- standard 3.3.5a client this is the same long-standing popup the native GuildFrame invite button
  -- itself opens (hasEditBox, OnAccept calls GuildInvite() with the typed name internally).
  invite:SetScript("OnClick", function() StaticPopup_Show("ADD_GUILDMEMBER") end)
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

  -- The left GuildColumn is Roster-only (owner steer 2026-07-17) — it isn't one of the per-mode
  -- content panels swapped above, so toggle it separately.
  if f.GuildColumn then f.GuildColumn:SetShown(mode == "ROSTER") end

  -- Bottom controls per mode. Chat no longer has its own mode (folded into GUILD_INFO), so Invite
  -- is just shown in both remaining modes now; Guild Control and the log button unchanged.
  if f.InviteButton  then f.InviteButton:SetShown(mode == "ROSTER" or mode == "GUILD_INFO") end
  if f.ControlButton then f.ControlButton:SetShown(mode == "ROSTER" or mode == "GUILD_INFO") end
  if f.LogButton     then f.LogButton:SetShown(mode == "GUILD_INFO") end

  if mode == "ROSTER" and G.RefreshRoster then G.RefreshRoster() end
  if mode == "GUILD_INFO" and G.RefreshInfo then G.RefreshInfo() end
  if mode == "ROSTER" and G.UpdateTabard then G.UpdateTabard() end
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
    -- Best-effort immediate paint (cached count, may be stale) — GuildRoster()'s response below
    -- fires GUILD_ROSTER_UPDATE, which re-syncs it for real via Roster.lua's recountOnline.
    -- BUG FIX 2026-07-17: this used to omit `total`, so SetGuild's `online and total` check always
    -- failed and blanked the member count on every open — self-healing only if GUILD_ROSTER_UPDATE
    -- happened to refire while shown, which GuildRoster()'s server-side throttle makes unreliable
    -- (owner report: crest/count "doesn't always load"). GetNumGuildMembers() is always immediately
    -- available (no roster scan needed), unlike G._onlineCount which requires recountOnline to have
    -- run at least once.
    local total = GetNumGuildMembers and GetNumGuildMembers()
    if f.GuildColumn and f.GuildColumn.SetGuild then f.GuildColumn.SetGuild(gname, G._onlineCount, total) end
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
  -- Window scale (owner steer 2026-07-17: "the guild tab [needs] to follow the same scaling" as
  -- the Social window). NE.scale.Apply is the preferred path (core/Scale.lua's DEFAULTS["guild"]
  -- matches Social's 1.0 default, and is exposed as a mode dropdown + custom slider in the options
  -- panel's "Window Scaling" section, same as Professions/Spellbook/Talents/Social).
  -- PinPixelPerfect(f) is the fallback if core/Scale.lua isn't loaded for some reason.
  if NE.scale and NE.scale.Apply then
    if NE.scale.SetFrame then NE.scale.SetFrame("guild", f) end
    NE.scale.Apply("guild")
  elseif NE.panelchrome and NE.panelchrome.PinPixelPerfect then
    NE.panelchrome.PinPixelPerfect(f)
  end

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
