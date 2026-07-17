-- DragonUI_NewEra/modules/social/Channels.lua — the Chat tab (chat channels).
--
-- Structure mirrors the stock 3.3.5a Chat Channels tab (owner supplied the stock frames as
-- reference 2026-07-16): a LEFT list of channels grouped under category headers (Group / World /
-- Custom), a RIGHT roster pane for the selected channel, and an Add button.
--
-- The first pass used the flat GetChannelList(), which can't express the category headers. The
-- stock list comes from GetNumDisplayChannels() + GetChannelDisplayInfo(i) — the same API the
-- stock ChannelFrame uses, where each entry is either a header or a channel. Both that pair and
-- the roster API are probed at runtime and fall back gracefully, since this addon targets more
-- than one 3.3.5a-derived build.
--
-- Built from Window.lua via SO.SetupChannels(f); exposes SO.RefreshChannels().

local NE = DragonUI_NewEra
if not NE then return end

NE.social = NE.social or {}
local SO = NE.social

local NUM_ROWS    = 24
local ROW_HEIGHT  = 16

-- Roster pane (owner steer 2026-07-17: capped at 23 names because it was a fixed, non-scrolling
-- FontString stack — real channels like General can run well past that). ROSTER_ROWS is now the
-- VISIBLE scrolled window; ROSTER_PROBE_MAX is how many rosterIndex slots we'll query per channel
-- (cheap local reads, no network cost — GetChannelRosterInfo just walks already-cached data).
local ROSTER_ROWS      = 34
local ROSTER_ROW_HEIGHT = 14
local ROSTER_PROBE_MAX  = 300

-- Forward-declared: read by the roster scroll's OnVerticalScroll (wired in SO.SetupChannels,
-- which is defined before this is assigned) and by refreshRoster below.
local renderRosterRows

-- Build the display list: { {header=bool, name=, number=, count=, index=} , ... }
-- Preferred: GetChannelDisplayInfo (carries headers). Fallback: the flat GetChannelList (no
-- headers — every entry renders as a plain channel row).
local function displayList()
  local out = {}
  if GetNumDisplayChannels and GetChannelDisplayInfo then
    local n = GetNumDisplayChannels() or 0
    for i = 1, n do
      local name, header, collapsed, channelNumber, count = GetChannelDisplayInfo(i)
      if name then
        out[#out + 1] = {
          index = i, name = name, header = header and true or false,
          collapsed = collapsed, number = channelNumber, count = count,
        }
      end
    end
    return out
  end

  if GetChannelList then
    -- Flat vararg: (id, name) pairs on 3.3.5a; later clients insert a third `disabled` boolean.
    local vals = { GetChannelList() }
    local stride = (type(vals[3]) == "boolean") and 3 or 2
    for i = 1, #vals, stride do
      local id, name = vals[i], vals[i + 1]
      if id and name then
        out[#out + 1] = { index = #out + 1, name = name, header = false, number = id }
      end
    end
  end
  return out
end

function SO.SetupChannels(f)
  local panel = f.ChatPanel
  if not panel or panel._built then return end
  panel._built = true
  panel._selected = nil

  -- Dark recessed backdrop, applied to each fill'd (owner steer 2026-07-17: "Who, Chat and Raid
  -- tabs should have the dark inset frames" — same treatment already used for Friends/Roster; the
  -- Left/Right wells already had a border via AttachInset but no dark fill behind it).
  local function darkFill(v)
    local bg = v:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.06, 0.06, 0.07, 0.75)
    bg:SetAllPoints(v)
    return bg
  end

  -- LEFT: channel list (recessed well).
  local left = CreateFrame("Frame", nil, panel)
  left:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -2)
  left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 34)
  left:SetWidth(250)
  darkFill(left)
  if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, left, 0, 0, 0, 0) end
  panel.Left = left

  -- RIGHT: roster of the selected channel.
  local right = CreateFrame("Frame", nil, panel)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
  right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 34)
  darkFill(right)
  if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, right, 0, 0, 0, 0) end
  panel.Right = right

  local scroll = CreateFrame("ScrollFrame", "NE_SocialChannelScroll", left, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", left, "TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -24, 4)
  scroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, ROW_HEIGHT, SO.RefreshChannels)
  end)
  panel._scroll = scroll
  scroll.ScrollBar = _G["NE_SocialChannelScrollScrollBar"]   -- 3.3.5a template has no parentKey
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(scroll) end

  panel._rows = {}
  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, left)
    row:SetHeight(ROW_HEIGHT)
    if i == 1 then row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    else row:SetPoint("TOPLEFT", panel._rows[i - 1], "BOTTOMLEFT", 0, 0) end
    row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    sel:SetBlendMode("ADD"); sel:SetAllPoints(row); sel:SetAlpha(0.4); sel:Hide()
    row._sel = sel

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT"); label:SetWordWrap(false)
    row.label = label

    row:SetScript("OnClick", function(self)
      if self._header or not self._name then return end   -- headers aren't selectable
      panel._selected = self._name
      panel._selectedIndex = self._index
      if SetSelectedDisplayChannel then pcall(SetSelectedDisplayChannel, self._index) end
      SO.RefreshChannels()
    end)
    panel._rows[i] = row
  end

  -- Roster header ("N players") — separate from the scrollable name list below it. Padding
  -- tightened to match the left channel list's 4px inset (owner steer 2026-07-17: "take up the
  -- full inset panel" — the old 10/8 padding was wasting space versus the left list's convention).
  panel.RosterHeader = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.RosterHeader:SetPoint("TOPLEFT", right, "TOPLEFT", 4, -4)
  panel.RosterHeader:SetPoint("RIGHT", right, "RIGHT", -4, 0)
  panel.RosterHeader:SetJustifyH("LEFT")

  -- Roster name list, now scrollable (owner steer 2026-07-17: "seems to cap at 23 players" — it
  -- was a fixed FontString stack with no way to see past it). Anchored flush to the panel's own
  -- edges (matching the left list's scroll) rather than indented under the header.
  local rosterScroll = CreateFrame("ScrollFrame", "NE_SocialChannelRosterScroll", right, "FauxScrollFrameTemplate")
  rosterScroll:SetPoint("TOPLEFT", panel.RosterHeader, "BOTTOMLEFT", 0, -4)
  rosterScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -24, 4)
  rosterScroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, ROSTER_ROW_HEIGHT, function() renderRosterRows(panel) end)
  end)
  panel._rosterScroll = rosterScroll
  rosterScroll.ScrollBar = _G["NE_SocialChannelRosterScrollScrollBar"]   -- 3.3.5a template has no parentKey
  -- BuildCustom, not Reskin (owner steer 2026-07-17: "no scrollbar" — Reskin's in-place reskin of
  -- the stock Slider is documented as non-rendering for FauxScrollFrameTemplate lists;
  -- core/ScrollbarReskin.lua:249-256 explains why BuildCustom exists as the real fix, already used
  -- for the Guild Event Log list).
  if NE.scrollbar and NE.scrollbar.BuildCustom then NE.scrollbar.BuildCustom(rosterScroll) end

  panel._roster = {}
  for i = 1, ROSTER_ROWS do
    local fs = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if i == 1 then fs:SetPoint("TOPLEFT", rosterScroll, "TOPLEFT", 0, 0)
    else fs:SetPoint("TOPLEFT", panel._roster[i - 1], "BOTTOMLEFT", 0, -2) end
    fs:SetPoint("RIGHT", rosterScroll, "RIGHT", -2, 0)
    fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
    panel._roster[i] = fs
  end

  -- Add (join a channel).
  local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  add:SetSize(110, 22); add:SetText(ADD or "Add")
  add:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  add:SetScript("OnClick", function()
    if panel._joinBox then panel._joinBox:Show(); panel._joinBox:SetFocus() end
  end)

  -- Inline join box (the stock Add opens a popup; an inline box avoids a StaticPopup whose
  -- exact name isn't confirmable without the client's FrameXML).
  local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  box:SetSize(200, 20); box:SetAutoFocus(false)
  box:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 4)
  box:SetScript("OnEnterPressed", function(self)
    local n = self:GetText()
    if n and n ~= "" and JoinChannelByName then JoinChannelByName(n) end
    self:SetText(""); self:ClearFocus()
    SO.RefreshChannels()
  end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  panel._joinBox = box

  local leave = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  leave:SetSize(110, 22); leave:SetText(LEAVE or "Leave")
  leave:SetPoint("RIGHT", add, "LEFT", -4, 0)
  leave:SetScript("OnClick", function()
    if panel._selected and LeaveChannelByName then
      LeaveChannelByName(panel._selected)
      panel._selected, panel._selectedIndex = nil, nil
      SO.RefreshChannels()
    end
  end)
end

-- Paint the currently visible window of panel._rosterNames into the fixed row FontStrings, per
-- the roster scroll's offset.
renderRosterRows = function(panel)
  local names = panel._rosterNames or {}
  local total = #names
  local offset = panel._rosterScroll and FauxScrollFrame_GetOffset(panel._rosterScroll) or 0
  for i = 1, ROSTER_ROWS do
    panel._roster[i]:SetText(names[offset + i] or "")
  end
  if panel._rosterScroll then
    FauxScrollFrame_Update(panel._rosterScroll, total, ROSTER_ROWS, ROSTER_ROW_HEIGHT)
  end
end

-- Populate the right pane with the selected channel's roster, when the client exposes it.
-- DOWNPORT: GetChannelDisplayInfo's `count` return is unreliable on this server (confirmed
-- 2026-07-17: read back 0 for a channel the default UI shows real members for), so don't trust it
-- as a loop bound. Probe GetChannelRosterInfo directly instead, starting at rosterIndex 1 and
-- stopping at the first index that fails — that's how the real member count is actually known here.
local function refreshRoster(panel, entry)
  panel._rosterNames = {}
  if entry and GetChannelRosterInfo then
    for i = 1, ROSTER_PROBE_MAX do
      local ok, name = pcall(GetChannelRosterInfo, entry.index, i)
      if not (ok and name) then break end
      panel._rosterNames[#panel._rosterNames + 1] = name
    end
  end
  local shown = #panel._rosterNames
  panel.RosterHeader:SetText(entry
    and string.format("|cffffd200%d|r %s", shown, (shown == 1) and "player" or "players")
    or "")
  renderRosterRows(panel)
end

function SO.RefreshChannels()
  local f = SO.frame
  local panel = f and f.ChatPanel
  if not (panel and panel._rows) then return end

  local list = displayList()
  local total = #list
  local offset = FauxScrollFrame_GetOffset(panel._scroll)

  -- Find the selected entry across the WHOLE list, not just the currently visible rows (a prior
  -- version only searched the visible slice, so a selection scrolled out of view silently cleared
  -- the roster pane).
  local selectedEntry
  if panel._selected then
    for _, e in ipairs(list) do
      if not e.header and e.name == panel._selected then selectedEntry = e; break end
    end
  end

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = panel._rows[i]
    local e = list[idx]
    if e then
      row._name   = e.name
      row._index  = e.index
      row._header = e.header
      if e.header then
        -- Category row (Group / World / Custom): gold, flush left, not selectable.
        row.label:SetText(e.name)
        row.label:SetTextColor(1, 0.82, 0)
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
      else
        -- Channel row: indented, numbered.
        row.label:SetText((e.number and (tostring(e.number) .. ". ") or "") .. tostring(e.name))
        row.label:SetTextColor(1, 1, 1)
        row.label:SetPoint("LEFT", row, "LEFT", 18, 0)
      end
      local isSel = (not e.header) and e == selectedEntry
      if row._sel then row._sel:SetShown(isSel) end
      row:Show()
    else
      row._name, row._index, row._header = nil, nil, nil
      if row._sel then row._sel:Hide() end
      row:Hide()
    end
  end
  FauxScrollFrame_Update(panel._scroll, total, NUM_ROWS, ROW_HEIGHT)
  refreshRoster(panel, selectedEntry)
end

-- Channel joins/leaves. Registered defensively: RegisterEvent throws on an event name the client
-- doesn't know, and this addon targets more than one 3.3.5a-derived build.
local ev = CreateFrame("Frame")
for _, e in ipairs({ "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE", "CHANNEL_COUNT_UPDATE",
                     "CHANNEL_ROSTER_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() if SO.RefreshChannels then SO.RefreshChannels() end end)
