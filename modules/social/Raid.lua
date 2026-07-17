-- DragonUI_NewEra/modules/social/Raid.lua — the Raid tab (raid roster + convert-to-raid).
--
-- The native 3.3.5a Socials window carries a Raid tab. NewEra RESKINS the native RaidFrame that
-- Era claims into its FriendsFrame; we can't do that here (our window is a rebuild, and the native
-- frame's classic art would clash with the modern chrome), so the roster is built natively on the
-- classic API: GetNumRaidMembers / GetRaidRosterInfo / ConvertToRaid. Built from Window.lua via
-- SO.SetupRaid(f); exposes SO.RefreshRaid().

local NE = DragonUI_NewEra
if not NE then return end

NE.social = NE.social or {}
local SO = NE.social

-- Fitted to the panel's scroll well (scroll insets -22/+34 of a 480-tall panel => ~424 => 26 rows
-- at 16px); rows aren't clipped by the scroll frame, so don't overshoot.
local NUM_ROWS   = 25
local ROW_HEIGHT = 16

-- Columns: { title, x, w, justify }.
local COLUMNS = {
  { title = NAME or "Name",         x = 4,   w = 120, justify = "LEFT" },
  { title = LEVEL_ABBR or "Level",  x = 126, w = 40,  justify = "CENTER" },
  { title = CLASS or "Class",       x = 168, w = 90,  justify = "LEFT" },
  { title = GROUP or "Group",       x = 260, w = 50,  justify = "CENTER" },
  { title = ZONE or "Zone",         x = 312, w = 0,   justify = "LEFT" },  -- fill
}

local function classColor(classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

function SO.SetupRaid(f)
  local panel = f.RaidPanel
  if not panel or panel._built then return end
  panel._built = true

  -- Dark recessed backdrop (owner steer 2026-07-17: "Who, Chat and Raid tabs should have the dark
  -- inset frames" — same treatment already used for Friends/Roster).
  local panelBg = panel:CreateTexture(nil, "BACKGROUND")
  panelBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  panelBg:SetVertexColor(0.06, 0.06, 0.07, 0.75)
  panelBg:SetAllPoints(panel)
  panel.Bg = panelBg
  if NE.nineslice and NE.nineslice.AttachInset then pcall(NE.nineslice.AttachInset, panel, 0, 0, 0, 0) end

  -- Column header strip.
  local header = CreateFrame("Frame", nil, panel)
  header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
  header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -4)
  header:SetHeight(16)
  for _, col in ipairs(COLUMNS) do
    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", header, "LEFT", col.x + 2, 0)
    fs:SetText(col.title)
  end

  local scroll = CreateFrame("ScrollFrame", "NE_SocialRaidScroll", panel, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 34)
  scroll:SetScript("OnVerticalScroll", function(self, o)
    FauxScrollFrame_OnVerticalScroll(self, o, ROW_HEIGHT, SO.RefreshRaid)
  end)
  panel._scroll = scroll
  scroll.ScrollBar = _G["NE_SocialRaidScrollScrollBar"]   -- 3.3.5a template has no parentKey
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
    panel._rows[i] = row
  end

  -- Empty state: the stock Raid tab shows explanatory blurb + a Raid Browser launcher when you
  -- aren't in a raid, rather than a bare "not in a raid" line.
  local empty = CreateFrame("Frame", nil, panel)
  empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -22)
  empty:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 34)
  panel.Empty = empty

  local blurb = empty:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  blurb:SetPoint("TOPLEFT", empty, "TOPLEFT", 12, -14)
  blurb:SetPoint("RIGHT", empty, "RIGHT", -12, 0)
  blurb:SetJustifyH("LEFT"); blurb:SetJustifyV("TOP")
  blurb:SetText(RAID_INFO_DESC or ERR_NOT_IN_RAID or "Raids are groups of more than 5 people.")
  blurb:SetTextColor(1, 0.82, 0)

  local prompt = empty:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prompt:SetPoint("BOTTOM", empty, "BOTTOM", 0, 46)
  prompt:SetText(RAID_BROWSER_OPT_IN or "Find a Raid Group or Assemble a Raid")

  -- Raid Browser (owner report 2026-07-17: "doesn't open anything" — ToggleRaidBrowser isn't a real
  -- 3.3.5a global, it doesn't exist on this client and the call was silently no-op'ing. Patch 3.3's
  -- actual Icecrown Raid Finder frame is LFRParentFrame, toggled with ToggleLFRParentFrame — confirmed
  -- as the live, working call via AddOns/DragonUI/modules/micromenu.lua:2649, which drives the same
  -- frame from the minimap LFG eye's "listed" mode.)
  local browser = CreateFrame("Button", nil, empty, "UIPanelButtonTemplate")
  browser:SetSize(200, 24); browser:SetText(RAID_BROWSER_BUTTON or "Open Raid Browser")
  browser:SetPoint("BOTTOM", empty, "BOTTOM", 0, 14)
  browser:SetScript("OnClick", function()
    if ToggleLFRParentFrame then ToggleLFRParentFrame() end
  end)
  panel.Browser = browser

  -- Convert to Raid (party leader, not already a raid).
  local convert = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  convert:SetSize(140, 22); convert:SetText(CONVERT_TO_RAID or "Convert to Raid")
  convert:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 4)
  convert:SetScript("OnClick", function()
    if ConvertToRaid then ConvertToRaid() end
    SO.RefreshRaid()
  end)
  panel.Convert = convert

  -- Raid Info button REMOVED (owner steer 2026-07-17): the saved-instance/lockout info it toggled
  -- is already surfaced in the main raid window, making the separate popup redundant.
end

function SO.RefreshRaid()
  local f = SO.frame
  local panel = f and f.RaidPanel
  if not (panel and panel._rows) then return end

  local total = (GetNumRaidMembers and GetNumRaidMembers()) or 0
  local offset = FauxScrollFrame_GetOffset(panel._scroll)

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = panel._rows[i]
    if idx <= total then
      local name, _, subgroup, level, _, fileName, zone, online = GetRaidRosterInfo(idx)
      row.cells[1]:SetText(name or "")
      row.cells[2]:SetText(level or "")
      row.cells[3]:SetText((fileName and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[fileName]) or "")
      row.cells[4]:SetText(subgroup or "")
      row.cells[5]:SetText((online and (zone or "")) or (FRIENDS_LIST_OFFLINE or "Offline"))
      row.cells[1]:SetTextColor(classColor(fileName))
      local dim = online and 1 or 0.5
      for c = 2, 5 do row.cells[c]:SetTextColor(dim, dim, dim) end
      row.cells[1]:SetAlpha(online and 1 or 0.5)
      row:Show()
    else
      row:Hide()
    end
  end
  FauxScrollFrame_Update(panel._scroll, total, NUM_ROWS, ROW_HEIGHT)

  -- Empty blurb vs the roster list (they occupy the same area).
  local inRaid = total > 0
  panel.Empty:SetShown(not inRaid)
  panel._scroll:SetShown(inRaid)
  if not inRaid then
    for i = 1, NUM_ROWS do panel._rows[i]:Hide() end
  end

  -- Convert only makes sense as a party leader who isn't already in a raid. The stock window
  -- keeps the button visible-but-disabled rather than hiding it.
  local canConvert = not inRaid
    and (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
    and (IsPartyLeader and IsPartyLeader())
  if canConvert then panel.Convert:Enable() else panel.Convert:Disable() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() if SO.RefreshRaid then SO.RefreshRaid() end end)
