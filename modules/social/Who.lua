-- DragonUI_NewEra/modules/social/Who.lua — the Who tab for NE_FriendsFrame.
--
-- Native WotLK APIs: SetWhoToUI(1) routes /who results to the UI (not chat); SendWho(filter)
-- queries; GetNumWhoResults / GetWhoInfo read them; WHO_LIST_UPDATE fires on arrival. Built from
-- Window.lua via SO.SetupWho(f); exposes SO.RefreshWho().

local NE = DragonUI_NewEra
if not NE then return end

NE.social = NE.social or {}
local SO = NE.social

-- Fitted to the panel's scroll well (scroll insets -46/+34 of a 480-tall panel => ~400 => 25 rows
-- at 16px); rows aren't clipped by the scroll frame, so don't overshoot.
local NUM_ROWS   = 23
local ROW_HEIGHT = 16

-- Columns, in the STOCK 3.3.5a order (owner supplied the stock frames as reference 2026-07-16):
-- Name | Zone | Lvl | Class — NOT the Name/Level/Class/Zone of the first pass.
-- { title, x, w, justify }; w 0 = fill to the row's right edge.
local COLUMNS = {
  { title = NAME or "Name",        x = 4,   w = 150, justify = "LEFT" },
  { title = ZONE or "Zone",        x = 156, w = 170, justify = "LEFT" },
  { title = LEVEL_ABBR or "Lvl",   x = 328, w = 40,  justify = "CENTER" },
  { title = CLASS or "Class",      x = 370, w = 0,   justify = "LEFT" },
}

local function classColor(classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

function SO.SetupWho(f)
  local panel = f.WhoPanel
  if not panel or panel._built then return end
  panel._built = true
  panel._selected = nil

  -- NOTE: SetWhoToUI is deliberately NOT set here. It's a global, sticky flag — setting it at
  -- build time (login) hijacked every /who the player typed into the UI for the whole session.
  -- Window.lua's SO.SetWhoRouting toggles it with the Who tab's visibility instead.

  -- Search box + button.
  local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  box:SetSize(200, 20); box:SetAutoFocus(false)
  box:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -2)
  box:SetScript("OnEnterPressed", function(self)
    if SetWhoToUI then SetWhoToUI(1) end
    if SendWho then SendWho(self:GetText() or "") end
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  panel._box = box

  local search = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  search:SetSize(80, 22); search:SetText(SEARCH or "Search")
  search:SetPoint("LEFT", box, "RIGHT", 8, 0)
  search:SetScript("OnClick", function()
    if SetWhoToUI then SetWhoToUI(1) end
    if SendWho then SendWho(box:GetText() or "") end
  end)

  -- Refresh — re-runs the last query (stock window has this bottom-left).
  local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  refresh:SetSize(90, 22); refresh:SetText(REFRESH or "Refresh")
  refresh:SetPoint("LEFT", search, "RIGHT", 8, 0)
  refresh:SetScript("OnClick", function()
    if SetWhoToUI then SetWhoToUI(1) end
    if SendWho then SendWho(box:GetText() or "") end
  end)

  -- "N People Found" readout (stock WhoFrameTotals).
  panel.Totals = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.Totals:SetPoint("BOTTOM", panel, "BOTTOM", 0, 30)

  -- Column header strip.
  local header = CreateFrame("Frame", nil, panel)
  header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -28)
  header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -28)
  header:SetHeight(16)
  for _, col in ipairs(COLUMNS) do
    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", header, "LEFT", col.x + 2, 0)
    fs:SetText(col.title)
  end

  -- List.
  local scroll = CreateFrame("ScrollFrame", "NE_SocialWhoScroll", panel, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -46)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 34)
  scroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, ROW_HEIGHT, SO.RefreshWho)
  end)
  panel._scroll = scroll
  scroll.ScrollBar = _G["NE_SocialWhoScrollScrollBar"]   -- 3.3.5a template doesn't set the parentKey
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(scroll) end

  panel._rows = {}
  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    if i == 1 then row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    else row:SetPoint("TOPLEFT", panel._rows[i - 1], "BOTTOMLEFT", 0, 0) end
    row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.cells = {}
    for c, col in ipairs(COLUMNS) do
      local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
      if col.w > 0 then fs:SetWidth(col.w) else fs:SetPoint("RIGHT", row, "RIGHT", -2, 0) end
      fs:SetJustifyH(col.justify); fs:SetWordWrap(false)
      row.cells[c] = fs
    end
    row:SetScript("OnClick", function(self) panel._selected = self._index; SO.RefreshWho() end)
    panel._rows[i] = row
  end

  -- Buttons: Add Friend / Group Invite / Whisper on the selected result.
  local function selectedName()
    if not panel._selected then return nil end
    return (GetWhoInfo and (GetWhoInfo(panel._selected)))
  end

  local addf = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  addf:SetSize(110, 22); addf:SetText(ADD_FRIEND or "Add Friend")
  addf:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
  addf:SetScript("OnClick", function() local n = selectedName(); if n and AddFriend then AddFriend(n) end end)

  local invite = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  invite:SetSize(110, 22); invite:SetText(GROUP_INVITE or "Invite")
  invite:SetPoint("LEFT", addf, "RIGHT", 4, 0)
  invite:SetScript("OnClick", function() local n = selectedName(); if n and InviteUnit then InviteUnit(n) end end)

  local whisper = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  whisper:SetSize(90, 22); whisper:SetText(WHISPER or "Whisper")
  whisper:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 4)
  whisper:SetScript("OnClick", function()
    local n = selectedName(); if n and ChatFrame_SendTell then ChatFrame_SendTell(n) end
  end)
end

function SO.RefreshWho()
  local f = SO.frame
  local panel = f and f.WhoPanel
  if not (panel and panel._rows) then return end
  local total = (GetNumWhoResults and GetNumWhoResults()) or 0
  local offset = FauxScrollFrame_GetOffset(panel._scroll)

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = panel._rows[i]
    if idx <= total then
      local name, guild, level, race, class, zone, classFile = GetWhoInfo(idx)
      row._index = idx
      row.cells[1]:SetText(name or "")
      row.cells[2]:SetText(zone or "")
      row.cells[3]:SetText(level or "")
      row.cells[4]:SetText(class or "")
      row.cells[1]:SetTextColor(classColor(classFile))
      row:Show()
    else
      row._index = nil
      row:Hide()
    end
  end
  FauxScrollFrame_Update(panel._scroll, total, NUM_ROWS, ROW_HEIGHT)

  -- Stock readout: "N People Found". The localized template's SHAPE isn't guaranteed on this
  -- client (FRIENDS_LIST_TEMPLATE turned out not to match retail's specifiers — it silently
  -- dropped an arg), and a template expecting more args than we pass would make string.format
  -- ERROR. So try the localized one under pcall and fall back to a plain built string.
  if panel.Totals then
    local shown, totalFound = GetNumWhoResults()
    local n = tonumber(totalFound) or tonumber(shown) or total or 0
    local ok, s = pcall(string.format, WHO_FRAME_TOTAL_TEMPLATE or "%d People Found", n)
    panel.Totals:SetText((ok and s) or (tostring(n) .. " People Found"))
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("WHO_LIST_UPDATE")
ev:SetScript("OnEvent", function() if SO.RefreshWho then SO.RefreshWho() end end)
