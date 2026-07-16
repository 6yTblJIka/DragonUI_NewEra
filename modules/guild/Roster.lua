-- DragonUI_NewEra/modules/guild/Roster.lua — the guild roster (ROSTER mode) + member detail.
--
-- DOWNPORT of NewEra/Guild/Roster.lua. NewEra uses retail's WowScrollBoxList + ColumnDisplay +
-- C_GuildInfo. On 3.3.5a we rebuild on the native WotLK kit: a FauxScrollFrame list, manual column
-- headers, and the classic roster API (GuildRoster / GetGuildRosterInfo / SortGuildRoster). Member
-- actions (public/officer notes, promote/demote/remove, party invite) use the WotLK permission
-- checks (CanEditPublicNote / CanViewOfficerNote / CanGuildPromote / CanGuildRemove …).
--
-- Built from Window.lua via G.SetupRoster(f); exposes G.RefreshRoster() (called on open, on
-- GUILD_ROSTER_UPDATE, and when the ROSTER tab is selected).

local NE = DragonUI_NewEra
if not NE then return end

NE.guild = NE.guild or {}
local G = NE.guild

-- Row count is sized to the scroll well's height at the window's fixed size (see Window.lua:
-- 582 tall - 48 top - 34 bottom = 500 panel; scroll insets -46/+2 => ~452 => 25 rows at 18px).
-- Rows are parented to the panel (not clipped by the scroll frame), so overshooting this would
-- spill rows over the bottom buttons — keep it at or under the fitted count.
local NUM_ROWS   = 24
local ROW_HEIGHT = 18

-- Column layout: { key = sort key for SortGuildRoster, title, x (left offset), w, justify }.
-- Follows the reference guild frame (owner 2026-07-16): Lvl | Class | Name | Zone | Rank | Note,
-- with Class rendered as an ICON rather than text. The left guild column is gone, so the panel
-- spans the full window and the columns get generous widths.
local COLUMNS = {
  { key = "level", title = LEVEL_ABBR or "Lvl",  x = 4,   w = 40,  justify = "CENTER" },
  { key = "class", title = CLASS or "Class",     x = 46,  w = 46,  justify = "CENTER", icon = true },
  { key = "name",  title = NAME or "Name",       x = 94,  w = 150, justify = "LEFT" },
  { key = "zone",  title = ZONE or "Zone",       x = 246, w = 150, justify = "LEFT" },
  { key = "rank",  title = RANK or "Rank",       x = 398, w = 120, justify = "LEFT" },
  { key = "note",  title = LABEL_NOTE or "Note", x = 520, w = 0,   justify = "LEFT" },  -- w 0 = fill
}

-- Native 3.3.5a class-icon sheet + coords. CLASS_ICON_TCOORDS is a stock global (modules/talents
-- already relies on it). The addon also ships a CIRCULAR `classicon-<class>` atlas via
-- modules/character/Assets.lua, but the reference frame's icons are the SQUARE stock ones.
local CLASS_ICON_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local function classColor(classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

-- Point a texture at a class's icon in the stock sheet. Returns false when the class is unknown
-- (so the caller can hide the icon rather than show the whole 4x4 sheet).
local function setClassIcon(tex, classFile)
  local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
  if not c then return false end
  tex:SetTexture(CLASS_ICON_TEX)
  tex:SetTexCoord(c[1], c[2], c[3], c[4])
  return true
end

-- Format a last-online tuple (GetGuildRosterLastOnline) into a short string.
-- The localized LASTONLINE_* templates' SHAPE isn't guaranteed on this client (FRIENDS_LIST_TEMPLATE
-- turned out not to match retail's specifiers), and a template wanting more args than we pass makes
-- string.format ERROR — so each format goes through pcall with a plain fallback.
local function safeFormat(tmpl, value, unit)
  local ok, s = pcall(string.format, tmpl or ("%d " .. unit), value)
  return (ok and s) or (tostring(value) .. " " .. unit)
end

local function lastOnlineText(i)
  if not GetGuildRosterLastOnline then return "" end
  local years, months, days, hours = GetGuildRosterLastOnline(i)
  if not years then return "" end
  if years  > 0 then return safeFormat(LASTONLINE_YEARS,  years,  "years")  end
  if months > 0 then return safeFormat(LASTONLINE_MONTHS, months, "months") end
  if days   > 0 then return safeFormat(LASTONLINE_DAYS,   days,   "days")   end
  if hours  > 0 then return safeFormat(LASTONLINE_HOURS,  hours,  "hours")  end
  return "< 1 " .. "hour"
end

-- ---------------------------------------------------------------------------
-- Member detail popup (click a roster row).
-- ---------------------------------------------------------------------------
local function buildMemberDetail(parent)
  local d = CreateFrame("Frame", "NE_GuildMemberDetail", parent)
  d:SetSize(220, 300)
  d:SetFrameStrata("DIALOG")
  d:SetToplevel(true); d:EnableMouse(true)
  d:SetPoint("TOPLEFT", parent, "TOPRIGHT", -6, -40)
  d:Hide()

  -- Dark backdrop (native DialogBox art — reliable on 3.3.5a).
  d:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })

  local close = CreateFrame("Button", nil, d, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)

  d.Name = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  d.Name:SetPoint("TOPLEFT", d, "TOPLEFT", 18, -18)
  d.Name:SetWidth(160); d.Name:SetJustifyH("LEFT")

  d.Level = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  d.Level:SetPoint("TOPLEFT", d.Name, "BOTTOMLEFT", 0, -4)

  d.Zone = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  d.Zone:SetPoint("TOPLEFT", d.Level, "BOTTOMLEFT", 0, -4)

  d.Rank = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  d.Rank:SetPoint("TOPLEFT", d.Zone, "BOTTOMLEFT", 0, -4)

  -- Public note.
  local nlabel = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nlabel:SetPoint("TOPLEFT", d.Rank, "BOTTOMLEFT", 0, -10)
  nlabel:SetText(LABEL_NOTE or "Note")
  local note = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
  note:SetSize(170, 20); note:SetAutoFocus(false)
  note:SetPoint("TOPLEFT", nlabel, "BOTTOMLEFT", 6, -2)
  note:SetScript("OnEnterPressed", function(self)
    if d._index and GuildRosterSetPublicNote then GuildRosterSetPublicNote(d._index, self:GetText()) end
    self:ClearFocus()
  end)
  note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  d.NoteEdit = note

  -- Officer note (shown only when viewable).
  local olabel = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  olabel:SetPoint("TOPLEFT", nlabel, "BOTTOMLEFT", 0, -46)
  olabel:SetText(GUILD_OFFICERNOTES_LABEL or "Officer Note")
  d.OfficerLabel = olabel
  local onote = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
  onote:SetSize(170, 20); onote:SetAutoFocus(false)
  onote:SetPoint("TOPLEFT", olabel, "BOTTOMLEFT", 6, -2)
  onote:SetScript("OnEnterPressed", function(self)
    if d._index and GuildRosterSetOfficerNote then GuildRosterSetOfficerNote(d._index, self:GetText()) end
    self:ClearFocus()
  end)
  onote:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  d.OfficerEdit = onote

  -- Action buttons: Promote / Demote / Remove / Group Invite.
  local function actionButton(text, w)
    local b = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    b:SetSize(w or 90, 20); b:SetText(text)
    return b
  end
  d.Promote = actionButton(GUILD_PROMOTE or "Promote")
  d.Promote:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 16, 40)
  d.Promote:SetScript("OnClick", function() if d._name and GuildPromote then GuildPromote(d._name); G.RefreshRoster() end end)

  d.Demote = actionButton(GUILD_DEMOTE or "Demote")
  d.Demote:SetPoint("LEFT", d.Promote, "RIGHT", 4, 0)
  d.Demote:SetScript("OnClick", function() if d._name and GuildDemote then GuildDemote(d._name); G.RefreshRoster() end end)

  d.Invite = actionButton(GROUP_INVITE or "Invite")
  d.Invite:SetPoint("BOTTOMLEFT", d.Promote, "TOPLEFT", 0, 6)
  d.Invite:SetScript("OnClick", function() if d._name and InviteUnit then InviteUnit(d._name) end end)

  d.Remove = actionButton(REMOVE or "Remove")
  d.Remove:SetPoint("LEFT", d.Invite, "RIGHT", 4, 0)
  d.Remove:SetScript("OnClick", function()
    if d._name and GuildUninvite then GuildUninvite(d._name); d:Hide(); G.RefreshRoster() end
  end)

  parent.MemberDetail = d
  return d
end

local function showMemberDetail(f, index)
  local d = f.MemberDetail
  if not d then return end
  local name, rank, _, level, _, zone, note, officernote, online, _, classFile = GetGuildRosterInfo(index)
  if not name then d:Hide(); return end
  d._index, d._name = index, name
  d.Name:SetText(name); d.Name:SetTextColor(classColor(classFile))
  d.Level:SetText((LEVEL or "Level") .. " " .. tostring(level or ""))
  d.Zone:SetText((online and (zone or "")) or lastOnlineText(index))
  d.Rank:SetText((RANK or "Rank") .. ": " .. tostring(rank or ""))

  d.NoteEdit:SetText(note or "")
  local canEditNote = CanEditPublicNote and CanEditPublicNote()
  d.NoteEdit:SetEnabled(canEditNote and true or false)

  local canViewOfficer = CanViewOfficerNote and CanViewOfficerNote()
  d.OfficerLabel:SetShown(canViewOfficer)
  d.OfficerEdit:SetShown(canViewOfficer)
  if canViewOfficer then
    d.OfficerEdit:SetText(officernote or "")
    d.OfficerEdit:SetEnabled(CanEditOfficerNote and CanEditOfficerNote() and true or false)
  end

  d.Promote:SetShown(CanGuildPromote and CanGuildPromote() and true or false)
  d.Demote:SetShown(CanGuildDemote and CanGuildDemote() and true or false)
  d.Remove:SetShown(CanGuildRemove and CanGuildRemove() and true or false)
  d:Show()
end

-- ---------------------------------------------------------------------------
-- Roster list.
-- ---------------------------------------------------------------------------
function G.SetupRoster(f)
  local panel = f.RosterFrame
  if not panel or panel._built then return end
  panel._built = true

  -- Show-offline toggle.
  local cb = CreateFrame("CheckButton", "NE_GuildShowOffline", panel, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
  cb:SetScale(0.9)
  local cbText = _G[cb:GetName() .. "Text"] or cb.Text
  if cbText then cbText:SetText(COMMUNITIES_MEMBER_LIST_SHOW_OFFLINE or GUILD_MEMBERS_SHOW_OFFLINE or "Show Offline") end
  if GetGuildRosterShowOffline then cb:SetChecked(GetGuildRosterShowOffline()) end
  cb:SetScript("OnClick", function(self)
    if SetGuildRosterShowOffline then SetGuildRosterShowOffline(self:GetChecked() and true or false) end
    if GuildRoster then GuildRoster() end
    G.RefreshRoster()
  end)
  panel.ShowOffline = cb

  -- Member count, right-aligned on the checkbox row (it used to live in the removed left column).
  panel.MemberCount = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.MemberCount:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -8)

  -- Column header strip: a dark bar with a recessed border and per-column separators, matching the
  -- reference frame's banded header rather than bare floating labels.
  local header = CreateFrame("Frame", nil, panel)
  header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -28)
  header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -28)
  header:SetHeight(22)
  panel.Header = header

  local hbg = header:CreateTexture(nil, "BACKGROUND")
  hbg:SetTexture("Interface\\Buttons\\WHITE8X8")
  hbg:SetVertexColor(0.10, 0.10, 0.12, 0.95)
  hbg:SetAllPoints(header)
  if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, header, 0, 0, 0, 0) end

  for i, col in ipairs(COLUMNS) do
    local btn = CreateFrame("Button", nil, header)
    btn:SetPoint("TOPLEFT", header, "TOPLEFT", col.x, 0)
    btn:SetHeight(22)
    btn:SetWidth(col.w > 0 and col.w or 160)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")   -- gold header label
    fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
    fs:SetText(col.title)
    btn._sortKey = col.key
    btn._label = fs
    btn:SetScript("OnClick", function(self)
      if SortGuildRoster then SortGuildRoster(self._sortKey) end
      G.RefreshRoster()
    end)
    btn:SetScript("OnEnter", function(self) self._label:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function(self) self._label:SetTextColor(1, 0.82, 0) end)

    -- Vertical separator on the left edge of every column after the first.
    if i > 1 then
      local sep = header:CreateTexture(nil, "ARTWORK")
      sep:SetTexture("Interface\\Buttons\\WHITE8X8")
      sep:SetVertexColor(1, 1, 1, 0.10)
      sep:SetWidth(1)
      sep:SetPoint("TOP", btn, "TOPLEFT", 0, -3)
      sep:SetPoint("BOTTOM", btn, "BOTTOMLEFT", 0, 3)
    end
  end

  -- FauxScrollFrame list.
  local scroll = CreateFrame("ScrollFrame", "NE_GuildRosterScroll", panel, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 2)
  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, G.RefreshRoster)
  end)
  panel.Scroll = scroll
  scroll.ScrollBar = _G["NE_GuildRosterScrollScrollBar"]   -- 3.3.5a template doesn't set the parentKey
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(scroll) end

  -- Row buttons.
  panel.Rows = {}
  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    if i == 1 then
      row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    else
      row:SetPoint("TOPLEFT", panel.Rows[i - 1], "BOTTOMLEFT", 0, 0)
    end
    row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Alternating row stripe (reference frame bands its rows; a flat list reads as a wall of text).
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
    stripe:SetVertexColor(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    stripe:SetAllPoints(row)
    row._stripe = stripe

    row.cells = {}
    for c, col in ipairs(COLUMNS) do
      if col.icon then
        -- Class column renders the class ICON, not text.
        local tex = row:CreateTexture(nil, "OVERLAY")
        tex:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
        tex:SetPoint("LEFT", row, "LEFT", col.x + (col.w - (ROW_HEIGHT - 4)) / 2, 0)
        row.cells[c] = tex
      else
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
        if col.w > 0 then fs:SetWidth(col.w) else fs:SetPoint("RIGHT", row, "RIGHT", -2, 0) end
        fs:SetJustifyH(col.justify)
        fs:SetWordWrap(false)
        row.cells[c] = fs
      end
    end

    row:SetScript("OnClick", function(self)
      if self._index then
        if SetGuildRosterSelection then SetGuildRosterSelection(self._index) end
        showMemberDetail(f, self._index)
      end
    end)
    panel.Rows[i] = row
  end

  buildMemberDetail(f)
end

function G.RefreshRoster()
  local f = G.frame
  local panel = f and f.RosterFrame
  if not (panel and panel._built and panel:IsShown()) then return end
  if not GetNumGuildMembers then return end

  local total = GetNumGuildMembers() or 0
  local offset = FauxScrollFrame_GetOffset(panel.Scroll)

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = panel.Rows[i]
    if idx <= total then
      local name, rank, _, level, class, zone, note, _, online, _, classFile = GetGuildRosterInfo(idx)
      row._index = idx
      local dim = online and 1 or 0.5

      row.cells[1]:SetText(level or "")
      row.cells[1]:SetTextColor(1 * dim, 0.82 * dim, 0)

      -- Class ICON (cell 2). Falls back to hidden when the class is unknown, so we never paint
      -- the whole 4x4 sheet into the cell.
      if setClassIcon(row.cells[2], classFile) then
        row.cells[2]:SetAlpha(dim)
        row.cells[2]:Show()
      else
        row.cells[2]:Hide()
      end

      row.cells[3]:SetText(name or "")
      row.cells[3]:SetTextColor(classColor(classFile))
      row.cells[3]:SetAlpha(online and 1 or 0.5)

      row.cells[4]:SetText((online and (zone or "")) or (GUILD_OFFLINE or "Offline"))
      row.cells[5]:SetText(rank or "")
      row.cells[6]:SetText(note or "")
      for c = 4, 6 do row.cells[c]:SetTextColor(dim, dim, dim) end

      row:Show()
    else
      row._index = nil
      row:Hide()
    end
  end

  FauxScrollFrame_Update(panel.Scroll, total, NUM_ROWS, ROW_HEIGHT)

  -- Member count on the header row (uses the cached online count — recomputed only on roster
  -- changes, not on every scroll; see recountOnline below).
  if panel.MemberCount then
    if G._onlineCount then
      panel.MemberCount:SetText(string.format("%d/%d %s", G._onlineCount, total, GUILD_MEMBERS or "Members"))
    else
      panel.MemberCount:SetText(string.format("%d %s", total, GUILD_MEMBERS or "Members"))
    end
  end
end

-- Recompute the online member count once (O(n)); cached for the cheap per-scroll refresh.
local function recountOnline()
  if not GetNumGuildMembers then return end
  local total = GetNumGuildMembers() or 0
  local online = 0
  for i = 1, total do
    local _, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
    if isOnline then online = online + 1 end
  end
  G._onlineCount = online
end

-- Live roster updates.
local ev = CreateFrame("Frame")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:SetScript("OnEvent", function()
  recountOnline()
  if G.RefreshRoster then G.RefreshRoster() end
end)
