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

-- Two-line entries (stock rows are tall). Fitted to the sub-view's scroll well: the Friends panel
-- is ~480 tall, minus the sub-tab strip (26) and the button row (34) => ~412 => 12 rows at 34px.
-- Rows aren't clipped by the scroll frame, so don't overshoot.
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

-- Inline name prompt. The stock Add Friend opens StaticPopup "ADD_FRIEND", but StaticPopup_Show
-- silently returns nil when a dialog of that name isn't defined — which is exactly why the button
-- did nothing here — and even when defined, this window sits at DIALOG strata and can draw over
-- the popup. An inline box is deterministic and matches the Chat tab's join box.
local function inlinePrompt(view, labelText, onAccept)
  local p = CreateFrame("Frame", nil, view)
  p:SetPoint("TOPLEFT",  view, "TOPLEFT",  0, 0)
  p:SetPoint("TOPRIGHT", view, "TOPRIGHT", -24, 0)
  p:SetHeight(26)
  p:SetFrameLevel(view:GetFrameLevel() + 5)
  p:Hide()

  local fill = p:CreateTexture(nil, "BACKGROUND")
  fill:SetTexture("Interface\\Buttons\\WHITE8X8")
  fill:SetVertexColor(0.06, 0.06, 0.07, 0.95)
  fill:SetAllPoints(p)

  local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lbl:SetPoint("LEFT", p, "LEFT", 6, 0)
  lbl:SetText(labelText)

  local box = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
  box:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
  box:SetPoint("RIGHT", p, "RIGHT", -8, 0)
  box:SetHeight(20)
  box:SetAutoFocus(false)
  box:SetMaxLetters(12)
  box:SetScript("OnEnterPressed", function(self)
    local t = self:GetText()
    if t and t ~= "" then onAccept(t) end
    self:SetText(""); self:ClearFocus(); p:Hide()
  end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); p:Hide() end)

  p.Open = function() p:Show(); box:SetFocus() end
  return p
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
-- Friends view.
-- ---------------------------------------------------------------------------
local function setupFriendsView(view)
  view._selected = nil

  local scroll = CreateFrame("ScrollFrame", "NE_SocialFriendsScroll", view, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -2)
  scroll:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -24, 34)
  scroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, ROW_HEIGHT, SO.RefreshFriends)
  end)
  view._scroll = scroll
  scroll.ScrollBar = _G["NE_SocialFriendsScrollScrollBar"]   -- 3.3.5a template has no parentKey
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(scroll) end

  view._rows = {}
  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(ROW_HEIGHT)
    if i == 1 then row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    else row:SetPoint("TOPLEFT", view._rows[i - 1], "BOTTOMLEFT", 0, 0) end
    row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    sel:SetBlendMode("ADD"); sel:SetAllPoints(row); sel:SetAlpha(0.4); sel:Hide()
    row._sel = sel

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -3)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 1)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT"); name:SetWordWrap(false)
    row.name = name

    local info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    info:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    info:SetJustifyH("LEFT"); info:SetWordWrap(false)
    row.info = info

    row:SetScript("OnClick", function(self)
      if self._index then
        view._selected = self._index
        if SetSelectedFriend then SetSelectedFriend(self._index) end
        SO.RefreshFriends()
      end
    end)
    view._rows[i] = row
  end

  view._prompt = inlinePrompt(view, ADD_FRIEND or "Add Friend", function(text)
    if AddFriend then AddFriend(text) end
    if ShowFriends then ShowFriends() end   -- re-request so the new friend lands in the list
    SO.RefreshFriends()
  end)

  local add = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  add:SetSize(116, 22); add:SetText(ADD_FRIEND or "Add Friend")
  add:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 0, 4)
  add:SetScript("OnClick", function() view._prompt.Open() end)

  local msg = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  msg:SetSize(116, 22); msg:SetText(SEND_MESSAGE or "Send Message")
  msg:SetPoint("LEFT", add, "RIGHT", 4, 0)
  msg:SetScript("OnClick", function()
    if view._selected then
      local n = GetFriendInfo(view._selected)
      if n and ChatFrame_SendTell then ChatFrame_SendTell(n) end
    end
  end)

  -- The stock window puts removal on a right-click menu; a button is clearer and keeps the
  -- action reachable without a context-menu implementation.
  local remove = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  remove:SetSize(116, 22); remove:SetText(REMOVE_FRIEND or "Remove Friend")
  remove:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -24, 4)
  remove:SetScript("OnClick", function()
    if view._selected and RemoveFriend then
      RemoveFriend(view._selected)
      view._selected = nil
      SO.RefreshFriends()
    end
  end)
end

function SO.RefreshFriends()
  local f = SO.frame
  local view = f and f.FriendsPanel and f.FriendsPanel.FriendsView
  if not (view and view._rows) then return end

  local total = (GetNumFriends and GetNumFriends()) or 0
  local offset = FauxScrollFrame_GetOffset(view._scroll)

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = view._rows[i]
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
      row:Show()
    else
      row._index = nil
      if row._sel then row._sel:Hide() end
      row:Hide()
    end
  end
  FauxScrollFrame_Update(view._scroll, total, NUM_ROWS, ROW_HEIGHT)
end

-- ---------------------------------------------------------------------------
-- Ignore view.
-- ---------------------------------------------------------------------------
local function setupIgnoreView(view)
  view._selected = nil

  local scroll = CreateFrame("ScrollFrame", "NE_SocialIgnoreScroll", view, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -2)
  scroll:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -24, 34)
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
    if i == 1 then row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
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

    row:SetScript("OnClick", function(self)
      if self._index then view._selected = self._index; SO.RefreshIgnore() end
    end)
    view._rows[i] = row
  end

  -- Same StaticPopup pitfall as Add Friend ("ADD_IGNORE" silently no-ops if undefined) → inline.
  view._prompt = inlinePrompt(view, IGNORE_PLAYER or "Ignore Player", function(text)
    if AddIgnore then AddIgnore(text) end
    SO.RefreshIgnore()
  end)

  local add = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  add:SetSize(116, 22); add:SetText(IGNORE_PLAYER or "Ignore Player")
  add:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 0, 4)
  add:SetScript("OnClick", function() view._prompt.Open() end)

  local remove = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
  remove:SetSize(116, 22); remove:SetText(DELETE or "Remove")
  remove:SetPoint("LEFT", add, "RIGHT", 4, 0)
  remove:SetScript("OnClick", function()
    if view._selected and GetIgnoreName and DelIgnore then
      local n = GetIgnoreName(view._selected)
      if n then DelIgnore(n); view._selected = nil; SO.RefreshIgnore() end
    end
  end)
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

  local function subView()
    local v = CreateFrame("Frame", nil, panel)
    v:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -28)   -- below the sub-tab strip
    v:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    v:Hide()
    return v
  end
  panel.FriendsView = subView()
  panel.IgnoreView  = subView()

  setupFriendsView(panel.FriendsView)
  setupIgnoreView(panel.IgnoreView)

  SO.SetFriendsSubTab("FRIENDS")
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "FRIENDLIST_UPDATE", "IGNORELIST_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "FRIENDLIST_UPDATE" and SO.RefreshFriends then SO.RefreshFriends() end
  if event == "IGNORELIST_UPDATE" and SO.RefreshIgnore then SO.RefreshIgnore() end
end)
