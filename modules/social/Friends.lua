-- DragonUI_NewEra/modules/social/Friends.lua — the Friends tab, with its Friends/Ignore SUB-tabs.
--
-- Structure mirrors the stock 3.3.5a Socials window (owner supplied the stock frames as reference
-- 2026-07-16): the Friends bottom-tab hosts two sub-tabs — Friends and Ignore — each with its own
-- list and its own button row. Entries are TWO-line (status icon + "Name, Level N Class" over the
-- zone), not the single-line rows of the first pass.
--
-- Native WotLK APIs: GetNumFriends / GetFriendInfo / AddFriend / RemoveFriend / SetSelectedFriend
-- and GetNumIgnores / GetIgnoreName / DelIgnore.
-- Built from Window.lua via SO.SetupFriends(f); exposes SO.RefreshFriends() / SO.RefreshIgnore().

local NE = DragonUI_NewEra
if not NE then return end

NE.social = NE.social or {}
local SO = NE.social

-- Two-line entries, sized for a 620px-wide window. Row height 28 -> 34 (owner steer 2026-07-17:
-- text read too small for the frame at 28px/small fonts — bumped the name/info font sizes back up
-- a step, which needs the extra height back; still packed with no dead space beyond what those
-- fonts need, unlike the original 34px rows which had slack on top of small-font text). Fitted to
-- the sub-view's scroll well: the Friends panel is ~480 tall, minus the sub-tab strip (26) and the
-- button row (34) => ~412 => 12 rows at 34px. Rows aren't clipped by the scroll frame, so don't
-- overshoot.
local NUM_ROWS   = 12
local ROW_HEIGHT = 34

-- Ignore rows are single-line, so they fit a smaller extent.
local IGNORE_ROWS   = 25
local IGNORE_HEIGHT = 16

local STATUS_ONLINE  = FRIENDS_TEXTURE_ONLINE  or "Interface\\FriendsFrame\\StatusIcon-Online"
local STATUS_AFK     = FRIENDS_TEXTURE_AFK     or "Interface\\FriendsFrame\\StatusIcon-Away"
local STATUS_DND     = FRIENDS_TEXTURE_DND     or "Interface\\FriendsFrame\\StatusIcon-DnD"
local STATUS_OFFLINE = FRIENDS_TEXTURE_OFFLINE or "Interface\\FriendsFrame\\StatusIcon-Offline"

local function statusTexture(connected, status)
  if not connected then return STATUS_OFFLINE end
  if status == (CHAT_FLAG_AFK or "<Away>") then return STATUS_AFK end
  if status == (CHAT_FLAG_DND or "<Busy>") then return STATUS_DND end
  return STATUS_ONLINE
end

-- "Name, Level 60 Warlock" — built explicitly rather than through FRIENDS_LIST_TEMPLATE. That
-- global does NOT have retail's "%s, Level %d %s" shape on this 3.3.5a client: feeding it
-- (name, level, class) rendered "- Parkanator 60" (it clearly carries fewer/reordered specifiers,
-- so the class arg was dropped). Concatenation is client-shape-independent.
local function friendNameText(name, level, class)
  local out = tostring(name or "")
  if level and level ~= 0 then
    out = out .. ", " .. (LEVEL or "Level") .. " " .. tostring(level)
  end
  if class and class ~= "" and class ~= UNKNOWN then
    out = out .. " " .. tostring(class)
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Sub-tabs (Friends | Ignore). A SECOND tab group can't share the frame-level PanelTemplates
-- state the bottom tabs use (frame.selectedTab / numTabs is per-frame), so the selected art is
-- driven manually — the same approach modules/spellbook/Spellbook.lua uses. ReskinClassicTab
-- paints the ACTIVE (gold) atlas onto the *Disabled pieces, so SELECTED = show *Disabled.
-- ---------------------------------------------------------------------------
local function setTabArt(tab, selected)
  if not tab then return end
  local n = tab:GetName()
  local function set(suffix, show)
    local t = _G[n .. suffix]
    if t then if show then t:Show() else t:Hide() end end
  end
  set("Left", not selected); set("Middle", not selected); set("Right", not selected)
  set("LeftDisabled", selected); set("MiddleDisabled", selected); set("RightDisabled", selected)
  local hl = tab._neCustomHL
  if hl then
    local a = selected and 0 or 0.4
    if hl.left   then hl.left:SetAlpha(a)   end
    if hl.middle then hl.middle:SetAlpha(a) end
    if hl.right  then hl.right:SetAlpha(a)  end
  end
end

local SUBTABS = {
  { key = "FRIENDS", label = FRIENDS or "Friends" },
  { key = "IGNORE",  label = IGNORE or "Ignore" },
}

local function buildSubTabs(panel)
  panel._subTabs = {}
  local prev
  for i, def in ipairs(SUBTABS) do
    local name = "NE_SocialFriendsSubTab" .. i
    local tab = CreateFrame("Button", name, panel, "CharacterFrameTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(def.label)
    tab._key = def.key
    if prev then
      tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
    else
      tab:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, 0)
    end
    if NE.tabs and NE.tabs.ReskinClassicTab then NE.tabs.ReskinClassicTab(name) end
    if NE.tabs and NE.tabs.MakeTopTab then NE.tabs.MakeTopTab(name) end   -- these point UP
    tab:SetScript("OnClick", function(self)
      if PlaySound then PlaySound("igCharacterInfoTab") end
      SO.SetFriendsSubTab(self._key)
    end)
    panel._subTabs[i] = tab
    prev = tab
  end
end

-- ---------------------------------------------------------------------------
-- Own status toggle (owner steer 2026-07-17: "friends tab is missing the status toggle" — stock
-- FriendsFrame has an Available/Away/Busy control, ours had none). AFK/DND are TOGGLES on this
-- client, not a direct "set" API — the same primitive the native /afk and /dnd slash commands use
-- (SendChatMessage(msg, "AFK"/"DND")) — so only fire the call when the target state isn't already
-- active, and going "Available" just toggles off whichever flag is currently set.
-- ---------------------------------------------------------------------------
local function setOwnStatus(mode)
  local isAFK = UnitIsAFK and UnitIsAFK("player")
  local isDND = UnitIsDND and UnitIsDND("player")
  if mode == "AFK" then
    if not isAFK then SendChatMessage(AFK_MESSAGE or "", "AFK") end
  elseif mode == "DND" then
    if not isDND then SendChatMessage(DND_MESSAGE or "", "DND") end
  else
    if isAFK then SendChatMessage(AFK_MESSAGE or "", "AFK") end
    if isDND then SendChatMessage(DND_MESSAGE or "", "DND") end
  end
end

local statusMenuFrame
local function openStatusMenu(anchor)
  if not EasyMenu then return end
  if not statusMenuFrame then
    statusMenuFrame = CreateFrame("Frame", "NE_SocialStatusMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local menu = {
    { text = "Available", notCheckable = true, func = function() setOwnStatus("AVAILABLE") end },
    { text = "Away",      notCheckable = true, func = function() setOwnStatus("AFK") end },
    { text = "Busy",      notCheckable = true, func = function() setOwnStatus("DND") end },
  }
  EasyMenu(menu, statusMenuFrame, anchor, 0, 0, "MENU")
end

local function buildStatusButton(panel)
  local btn = CreateFrame("Button", nil, panel)
  btn:SetSize(110, 20)
  btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -2)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(14, 14)
  icon:SetPoint("LEFT", btn, "LEFT", 2, 0)
  btn.icon = icon

  local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
  label:SetJustifyH("LEFT")
  btn.label = label

  local arrow = btn:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetSize(10, 10)
  arrow:SetPoint("LEFT", label, "RIGHT", 2, 0)

  btn:SetScript("OnClick", function(self) openStatusMenu(self) end)
  panel.StatusButton = btn
end

function SO.RefreshOwnStatus()
  local f = SO.frame
  local btn = f and f.FriendsPanel and f.FriendsPanel.StatusButton
  if not btn then return end
  local isAFK = UnitIsAFK and UnitIsAFK("player")
  local isDND = UnitIsDND and UnitIsDND("player")
  if isDND then
    btn.icon:SetTexture(STATUS_DND); btn.label:SetText("Busy")
  elseif isAFK then
    btn.icon:SetTexture(STATUS_AFK); btn.label:SetText("Away")
  else
    btn.icon:SetTexture(STATUS_ONLINE); btn.label:SetText("Available")
  end
end

function SO.SetFriendsSubTab(key)
  local f = SO.frame
  local panel = f and f.FriendsPanel
  if not (panel and panel._subTabs) then return end
  panel._sub = key
  for _, tab in ipairs(panel._subTabs) do
    setTabArt(tab, tab._key == key)
  end
  if panel.FriendsView then panel.FriendsView:SetShown(key == "FRIENDS") end
  if panel.IgnoreView  then panel.IgnoreView:SetShown(key == "IGNORE") end
  if key == "FRIENDS" then
    if ShowFriends then ShowFriends() end
    SO.RefreshFriends()
  else
    SO.RefreshIgnore()
  end
end

-- ---------------------------------------------------------------------------
-- Right-click context menus (owner steer 2026-07-17: rows had no context menu at all — right-click
-- was never wired up). Native EasyMenu/UIDropDownMenu, same pattern as
-- modules/bags/CombinedBag.lua:CB.OpenMenu (confirmed working on 3.3.5a).
-- ---------------------------------------------------------------------------
local friendMenuFrame
local function openFriendMenu(idx)
  if not (EasyMenu and idx) then return end
  if not friendMenuFrame then
    friendMenuFrame = CreateFrame("Frame", "NE_SocialFriendMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local name = GetFriendInfo(idx)
  local menu = {
    { text = name or "", isTitle = true, notCheckable = true },
    { text = SEND_MESSAGE or "Send Message", notCheckable = true, func = function()
        if name and ChatFrame_SendTell then ChatFrame_SendTell(name) end
      end },
    { text = REMOVE_FRIEND or "Remove Friend", notCheckable = true, func = function()
        if RemoveFriend then RemoveFriend(idx) end
        SO.RefreshFriends()
      end },
  }
  EasyMenu(menu, friendMenuFrame, "cursor", 0, 0, "MENU")
end

local ignoreMenuFrame
local function openIgnoreMenu(idx)
  if not (EasyMenu and idx) then return end
  if not ignoreMenuFrame then
    ignoreMenuFrame = CreateFrame("Frame", "NE_SocialIgnoreMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local name = GetIgnoreName and GetIgnoreName(idx)
  local menu = {
    { text = name or "", isTitle = true, notCheckable = true },
    { text = DELETE or "Remove", notCheckable = true, func = function()
        if name and DelIgnore then DelIgnore(name) end
        SO.RefreshIgnore()
      end },
  }
  EasyMenu(menu, ignoreMenuFrame, "cursor", 0, 0, "MENU")
end

-- ---------------------------------------------------------------------------
-- Friends view.
-- ---------------------------------------------------------------------------
local function setupFriendsView(view)
  view._selected = nil

  local scroll = CreateFrame("ScrollFrame", "NE_SocialFriendsScroll", view, "FauxScrollFrameTemplate")
  -- Inset 3px from the view's edges (owner steer 2026-07-17), on top of the existing scrollbar
  -- clearance (-24) and button-row clearance (34).
  scroll:SetPoint("TOPLEFT", view, "TOPLEFT", 3, -5)
  scroll:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -27, 37)
  scroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, ROW_HEIGHT, SO.RefreshFriends)
  end)
  view._scroll = scroll
  scroll.ScrollBar = _G["NE_SocialFriendsScrollScrollBar"]   -- 3.3.5a template has no parentKey
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(scroll) end

  -- Online/offline separator (owner steer 2026-07-17: "a separator in the list between online and
  -- offline friends, just a light grey bar"). One shared bar, repositioned each refresh to sit
  -- between whichever two VISIBLE rows are the online->offline transition (RefreshFriends below);
  -- naturally hides itself when that boundary has scrolled out of view or doesn't exist (all
  -- online/all offline).
  local sep = view:CreateTexture(nil, "OVERLAY")
  sep:SetTexture("Interface\\Buttons\\WHITE8X8")
  sep:SetVertexColor(0.6, 0.6, 0.6, 0.5)
  sep:SetHeight(1)
  sep:Hide()
  view._sep = sep

  view._rows = {}
  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(ROW_HEIGHT)
    -- Top padding 0 -> -4 -> -9 (owner steer 2026-07-17: the first row sat flush against the
    -- inset's top edge with no breathing room; then another +5px on top of that).
    if i == 1 then row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -9)
    else row:SetPoint("TOPLEFT", view._rows[i - 1], "BOTTOMLEFT", 0, 0) end
    row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Alternating row stripe (owner steer 2026-07-17: "guild roster has a stripe like effect... can
    -- the friends list also have this?" — same treatment as modules/guild/Roster.lua's row stripe).
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
    stripe:SetVertexColor(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    stripe:SetAllPoints(row)
    row._stripe = stripe

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    sel:SetBlendMode("ADD"); sel:SetAllPoints(row); sel:SetAlpha(0.4); sel:Hide()
    row._sel = sel

    -- Icon 12 -> 14, name/info bumped to the next font size up (owner steer 2026-07-17: text read
    -- too small for a 620px-wide window; the shrink toward the reference's plainer dot went a step
    -- too far on the text itself).
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 5, 2)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT"); name:SetWordWrap(false)
    row.name = name

    local info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    info:SetJustifyH("LEFT"); info:SetWordWrap(false)
    row.info = info

    -- Thin row divider (owner steer 2026-07-17, reference NewEra screenshot: entries are separated
    -- by a faint horizontal line, which our rows never had).
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(1, 1, 1, 0.08)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 0)
    divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
    row._divider = divider

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
      if not self._index then return end
      if button == "RightButton" then
        openFriendMenu(self._index)
        return
      end
      view._selected = self._index
      if SetSelectedFriend then SetSelectedFriend(self._index) end
      SO.RefreshFriends()
    end)
    view._rows[i] = row
  end

  local add = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  add:SetSize(116, 22); add:SetText(ADD_FRIEND or "Add Friend")
  add:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 0, 4)
  -- Stock Blizzard invite dialog (owner steer 2026-07-17, same fix as the Guild Invite button:
  -- "fix the add friend button to do this also"). REVERTED the inline name-prompt above — that was
  -- built on an unverified assumption that StaticPopup_Show("ADD_FRIEND") silently no-ops here; on a
  -- standard 3.3.5a client this is the same long-standing popup the native FriendsFrame Add Friend
  -- button itself opens (hasEditBox, OnAccept calls AddFriend() with the typed name internally). The
  -- list refresh doesn't need a manual call either — FRIENDLIST_UPDATE (registered below) already
  -- drives SO.RefreshFriends() once the server round-trip lands.
  add:SetScript("OnClick", function() StaticPopup_Show("ADD_FRIEND") end)

  -- Send Message / Remove Friend buttons REMOVED (owner steer 2026-07-17): both actions are
  -- already on the row's right-click menu (openFriendMenu above), so the dedicated buttons were
  -- redundant.
end

function SO.RefreshFriends()
  local f = SO.frame
  local view = f and f.FriendsPanel and f.FriendsPanel.FriendsView
  if not (view and view._rows) then return end

  local total = (GetNumFriends and GetNumFriends()) or 0
  local offset = FauxScrollFrame_GetOffset(view._scroll)
  local prevConnected, sepPlaced = nil, false

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = view._rows[i]
    local isBoundary = false
    if idx <= total then
      local name, level, class, area, connected, status = GetFriendInfo(idx)
      row._index = idx
      row.icon:SetTexture(statusTexture(connected, status))
      if connected then
        row.name:SetText(friendNameText(name, level, class))
        row.name:SetTextColor(1, 0.82, 0)
        row.info:SetText(area or "")
        row.info:SetTextColor(0.5, 0.5, 0.5)
      else
        row.name:SetText(tostring(name or ""))
        row.name:SetTextColor(0.5, 0.5, 0.5)
        row.info:SetText(FRIENDS_LIST_OFFLINE or "Offline")
        row.info:SetTextColor(0.4, 0.4, 0.4)
      end
      if row._sel then row._sel:SetShown(idx == view._selected) end
      isBoundary = (prevConnected == true and connected == false)
      if isBoundary and view._sep then
        -- Centered in the 10px gap opened up below (5px clear on either side of the line — owner
        -- steer 2026-07-17), not flush against either row.
        view._sep:ClearAllPoints()
        view._sep:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 4, 5)
        view._sep:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", -4, 5)
        view._sep:Show()
        sepPlaced = true
      end
      prevConnected = connected
      row:Show()
    else
      row._index = nil
      if row._sel then row._sel:Hide() end
      row:Hide()
    end

    -- Re-anchor every refresh (the boundary row index moves as friends log on/off or the list
    -- scrolls): normal flush chain, except the boundary row gets pushed down an extra 10px to open
    -- the gap the separator sits in.
    if i == 1 then
      row:SetPoint("TOPLEFT", view._scroll, "TOPLEFT", 0, -9)
    else
      row:SetPoint("TOPLEFT", view._rows[i - 1], "BOTTOMLEFT", 0, isBoundary and -10 or 0)
    end
  end
  if not sepPlaced and view._sep then view._sep:Hide() end
  FauxScrollFrame_Update(view._scroll, total, NUM_ROWS, ROW_HEIGHT)
end

-- ---------------------------------------------------------------------------
-- Ignore view.
-- ---------------------------------------------------------------------------
local function setupIgnoreView(view)
  view._selected = nil

  local scroll = CreateFrame("ScrollFrame", "NE_SocialIgnoreScroll", view, "FauxScrollFrameTemplate")
  -- Inset 3px from the view's edges (owner steer 2026-07-17), on top of the existing scrollbar
  -- clearance (-24) and button-row clearance (34).
  scroll:SetPoint("TOPLEFT", view, "TOPLEFT", 3, -5)
  scroll:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -27, 37)
  scroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, IGNORE_HEIGHT, SO.RefreshIgnore)
  end)
  view._scroll = scroll
  scroll.ScrollBar = _G["NE_SocialIgnoreScrollScrollBar"]
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(scroll) end

  view._rows = {}
  for i = 1, IGNORE_ROWS do
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(IGNORE_HEIGHT)
    -- Top padding 0 -> -4 (owner steer 2026-07-17: the first row sat flush against the inset's top
    -- edge with no breathing room).
    if i == 1 then row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -4)
    else row:SetPoint("TOPLEFT", view._rows[i - 1], "BOTTOMLEFT", 0, 0) end
    row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    sel:SetBlendMode("ADD"); sel:SetAllPoints(row); sel:SetAlpha(0.4); sel:Hide()
    row._sel = sel

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", row, "LEFT", 6, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT"); name:SetWordWrap(false)
    row.name = name

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
      if not self._index then return end
      if button == "RightButton" then
        openIgnoreMenu(self._index)
        return
      end
      view._selected = self._index; SO.RefreshIgnore()
    end)
    view._rows[i] = row
  end

  local add = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  add:SetSize(116, 22); add:SetText(IGNORE_PLAYER or "Ignore Player")
  add:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 0, 4)
  -- Stock Blizzard dialog (owner steer 2026-07-17, same fix as the Guild Invite / Add Friend
  -- buttons: "use the blizzard ui not the one you did"). REVERTED the inline name-prompt — same
  -- disproven "StaticPopup_Show silently no-ops here" theory as the other two buttons; on a
  -- standard 3.3.5a client "ADD_IGNORE" is the same long-standing popup the native Ignore tab's
  -- own button opens (hasEditBox, OnAccept calls AddIgnore() with the typed name internally).
  add:SetScript("OnClick", function() StaticPopup_Show("ADD_IGNORE") end)

  -- Remove button REMOVED (owner steer 2026-07-17): already on the row's right-click menu
  -- (openIgnoreMenu above), so the dedicated button was redundant.
end

function SO.RefreshIgnore()
  local f = SO.frame
  local view = f and f.FriendsPanel and f.FriendsPanel.IgnoreView
  if not (view and view._rows) then return end

  local total = (GetNumIgnores and GetNumIgnores()) or 0
  local offset = FauxScrollFrame_GetOffset(view._scroll)

  for i = 1, IGNORE_ROWS do
    local idx = offset + i
    local row = view._rows[i]
    if idx <= total then
      row._index = idx
      row.name:SetText((GetIgnoreName and GetIgnoreName(idx)) or "")
      row.name:SetTextColor(1, 0.82, 0)
      if row._sel then row._sel:SetShown(idx == view._selected) end
      row:Show()
    else
      row._index = nil
      if row._sel then row._sel:Hide() end
      row:Hide()
    end
  end
  FauxScrollFrame_Update(view._scroll, total, IGNORE_ROWS, IGNORE_HEIGHT)
end

-- SO.SetupFriends builds the Friends panel + BOTH sub-views (Window.lua calls it once).
function SO.SetupFriends(f)
  local panel = f.FriendsPanel
  if not panel or panel._built then return end
  panel._built = true

  buildSubTabs(panel)
  buildStatusButton(panel)
  SO.RefreshOwnStatus()

  local function subView()
    local v = CreateFrame("Frame", nil, panel)
    v:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -28)   -- below the sub-tab strip
    v:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    v:Hide()

    -- Dark recessed backdrop (owner steer 2026-07-17: reference NewEra Friends tab reads much
    -- darker/flatter than our default stone chrome, which was showing straight through with
    -- nothing behind the rows — same treatment already used for the guild chat panel). Alpha
    -- lowered 0.90 -> 0.75 so the stone texture's grain still reads through as subtle mottling,
    -- rather than a flat solid block (reference has visible texture, not a flat fill).
    local bg = v:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.06, 0.06, 0.07, 0.75)
    bg:SetAllPoints(v)
    if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, v, 0, 0, 0, 0) end

    return v
  end
  panel.FriendsView = subView()
  panel.IgnoreView  = subView()

  setupFriendsView(panel.FriendsView)
  setupIgnoreView(panel.IgnoreView)

  SO.SetFriendsSubTab("FRIENDS")
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "FRIENDLIST_UPDATE", "IGNORELIST_UPDATE", "PLAYER_FLAGS_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "FRIENDLIST_UPDATE" and SO.RefreshFriends then SO.RefreshFriends() end
  if event == "IGNORELIST_UPDATE" and SO.RefreshIgnore then SO.RefreshIgnore() end
  if event == "PLAYER_FLAGS_CHANGED" and (not unit or unit == "player") and SO.RefreshOwnStatus then
    SO.RefreshOwnStatus()
  end
end)
