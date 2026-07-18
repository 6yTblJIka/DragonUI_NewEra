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

local function classColor(classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

-- ---------------------------------------------------------------------------
-- Right-click context menu on a group slot (owner steer 2026-07-17: no menu existed on the group
-- grid at all). Same EasyMenu/UIDropDownMenu pattern as Friends.lua/Roster.lua/Who.lua.
-- Promote/demote/assignment calls all use the (unit, name, exactMatch) signature confirmed via the
-- on-client APIDocumentation addon (RaidDocumentation.lua/PartyDocumentation.lua) and cross-checked
-- against a live, working raid addon on this server (AddOns/Cell_Wrath/Utilities/RaidRosterFrame.lua
-- calls PromoteToAssistant/DemoteAssistant/UninviteUnit the same way). Passing name (not a unit
-- token) keeps this independent of the slot's raid-roster index. "MAINTANK"/"MAINASSIST" are the
-- confirmed SetPartyAssignment() assignment strings (same Cell_Wrath file + Indicators/Built-in.lua).
-- Promote/Remove items are only offered to a leader/assist, matching stock permission gating.
-- ---------------------------------------------------------------------------
local raidSlotMenuFrame
local function openRaidSlotMenu(name)
  if not (EasyMenu and name) then return end
  if not raidSlotMenuFrame then
    raidSlotMenuFrame = CreateFrame("Frame", "NE_SocialRaidSlotMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local canManage = (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
  local menu = { { text = name, isTitle = true, notCheckable = true } }
  menu[#menu + 1] = { text = "Set Focus", notCheckable = true, func = function()
      if FocusUnit then FocusUnit(nil, name) end
    end }
  if canManage then
    menu[#menu + 1] = { text = "Promote to Raid Leader", notCheckable = true, func = function()
        if PromoteToLeader then PromoteToLeader(nil, name) end
        SO.RefreshRaid()
      end }
    menu[#menu + 1] = { text = "Promote to Assistant", notCheckable = true, func = function()
        if PromoteToAssistant then PromoteToAssistant(nil, name) end
        SO.RefreshRaid()
      end }
    menu[#menu + 1] = { text = "Promote to Main Tank", notCheckable = true, func = function()
        if SetPartyAssignment then SetPartyAssignment("MAINTANK", nil, name) end
      end }
    menu[#menu + 1] = { text = "Promote to Main Assist", notCheckable = true, func = function()
        if SetPartyAssignment then SetPartyAssignment("MAINASSIST", nil, name) end
      end }
    menu[#menu + 1] = { text = REMOVE or "Remove", notCheckable = true, func = function()
        if UninviteUnit then UninviteUnit(nil, name) end
        SO.RefreshRaid()
      end }
  end
  menu[#menu + 1] = { text = CANCEL or "Cancel", notCheckable = true }
  EasyMenu(menu, raidSlotMenuFrame, "cursor", 0, 0, "MENU")
end

-- ---------------------------------------------------------------------------
-- Saved Instances (raid lockouts). Owner correction 2026-07-17: the toggleable Raid Info popup
-- was removed on the assumption its lockout info was already surfaced somewhere in the main Raid
-- tab -- turned out nothing in the addon ever actually read GetSavedInstanceInfo, so lockouts
-- weren't shown ANYWHERE. Rebuilt here, inline at the top of the Raid tab instead of as a separate
-- popup. 3.3.5a API (confirmed via the on-client APIDocumentation addon,
-- Documentation/InstanceDocumentation.lua -- this build's GetSavedInstanceInfo has no
-- numEncounters/encounterProgress, that's a later/retail addition to the same-named API):
--   GetNumSavedInstances() -> count
--   GetSavedInstanceInfo(index) -> name, id, reset, difficulty, locked, extended,
--                                   instanceIDMostSig, isRaid, maxPlayers, difficultyName
-- RequestRaidInfo() asks the server to (re)send this; UPDATE_INSTANCE_INFO fires on arrival.
-- ---------------------------------------------------------------------------
local SAVED_BLOCK_H = 60

local function formatReset(seconds)
  seconds = tonumber(seconds) or 0
  if seconds <= 0 then return "Expired" end
  local h = math.floor(seconds / 3600)
  local d = math.floor(h / 24)
  if d > 0 then return string.format("%dd %dh", d, h - d * 24) end
  if h > 0 then return string.format("%dh %dm", h, math.floor((seconds % 3600) / 60)) end
  return string.format("%dm", math.floor(seconds / 60))
end

local function buildSavedInstances(panel)
  local block = CreateFrame("Frame", nil, panel)
  block:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
  block:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -4)
  block:SetHeight(SAVED_BLOCK_H)

  local title = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", block, "TOPLEFT", 4, 0)
  title:SetText(RAID_INFO or "Saved Instances")
  title:SetTextColor(1, 0.82, 0)

  local body = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  body:SetPoint("RIGHT", block, "RIGHT", -4, 0)
  body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
  body:SetWordWrap(true)
  block.Body = body

  -- Thin separator under the block so it reads as a distinct section from the group grid below.
  local sep = block:CreateTexture(nil, "ARTWORK")
  sep:SetTexture("Interface\\Buttons\\WHITE8X8")
  sep:SetVertexColor(1, 1, 1, 0.10)
  sep:SetHeight(1)
  sep:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT", 4, 0)
  sep:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -4, 0)

  panel.SavedInstances = block
  return block
end

function SO.RefreshSavedInstances()
  local f = SO.frame
  local panel = f and f.RaidPanel
  local block = panel and panel.SavedInstances
  if not (block and GetNumSavedInstances) then return end

  local n = GetNumSavedInstances() or 0
  local lines = {}
  for i = 1, n do
    local name, _, reset, _, locked, extended, _, isRaid, _, difficultyName = GetSavedInstanceInfo(i)
    if name and isRaid and locked then
      local label = (difficultyName and difficultyName ~= "") and (name .. " (" .. difficultyName .. ")") or name
      local line = string.format("%s - %s", label, formatReset(reset))
      if extended then line = line .. " |cff40ff40(Extended)|r" end
      lines[#lines + 1] = line
    end
  end
  block.Body:SetText((#lines > 0) and table.concat(lines, "\n") or "You are not saved to any raid instances.")
end

-- ---------------------------------------------------------------------------
-- Raid roster: grouped grid (owner report 2026-07-17, with a screenshot of the default UI: "The
-- raid tab should be in groups" -- the flat Name/Level/Class/Group/Zone table didn't match the
-- stock RaidFrame's Group 1-8 layout). 8 groups x 5 slots (the WotLK 40-man raid cap), laid out 2
-- columns x 4 rows -- odd groups (1/3/5/7) left, even groups (2/4/6/8) right -- matching the
-- reference screenshot. Always visible (not swapped for an empty-state blurb): the stock frame
-- shows all 8 groups, slots reading "Empty", even with zero raid members.
-- ---------------------------------------------------------------------------
local NUM_GROUPS      = 8
local SLOTS_PER_GROUP = 5
local GROUP_HEADER_H  = 16
-- SLOT_H 13->12, GROUP_GAP_Y 6->4->3 (owner report 2026-07-17: the class summary strip moved below
-- the grid, and later enlarged + pushed down further, needs pixels reclaimed from the grid each
-- time to avoid overlapping the outer-chrome buttons).
local SLOT_H          = 12
local GROUP_BOX_H     = GROUP_HEADER_H + SLOTS_PER_GROUP * SLOT_H
local GROUP_GAP_Y     = 3
local COL_GAP_X       = 8
local LEFT_GROUPS  = { 1, 3, 5, 7 }
local RIGHT_GROUPS = { 2, 4, 6, 8 }

local LEADER_ICON  = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local ASSIST_ICON  = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local EMPTY_LABEL  = EMPTY or "Empty"

local function buildGroupBox(col, groupIndex, stackPos)
  local box = CreateFrame("Frame", nil, col)
  local y = -(stackPos - 1) * (GROUP_BOX_H + GROUP_GAP_Y)
  box:SetPoint("TOPLEFT", col, "TOPLEFT", 0, y)
  box:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, y)
  box:SetHeight(GROUP_BOX_H)

  local hdrBg = box:CreateTexture(nil, "BACKGROUND")
  hdrBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  hdrBg:SetVertexColor(0.10, 0.10, 0.12, 0.95)
  hdrBg:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  hdrBg:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  hdrBg:SetHeight(GROUP_HEADER_H)

  local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", box, "TOPLEFT", 4, -GROUP_HEADER_H / 2)
  label:SetText((GROUP or "Group") .. " " .. groupIndex)
  label:SetTextColor(1, 0.82, 0)

  local bodyBg = box:CreateTexture(nil, "BACKGROUND")
  bodyBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bodyBg:SetVertexColor(0.04, 0.04, 0.05, 0.6)
  bodyBg:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -GROUP_HEADER_H)
  bodyBg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)

  box.slots = {}
  for s = 1, SLOTS_PER_GROUP do
    -- Button, not a plain Frame (owner steer 2026-07-17: right-click menu needs click detection).
    local slot = CreateFrame("Button", nil, box)
    slot:SetHeight(SLOT_H)
    slot:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -GROUP_HEADER_H - (s - 1) * SLOT_H)
    slot:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -GROUP_HEADER_H - (s - 1) * SLOT_H)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnClick", function(self, button)
      if button == "RightButton" and self._name then openRaidSlotMenu(self._name) end
    end)
    -- Hover highlight on the slot itself (owner report 2026-07-17: slots had none — every other
    -- list in this addon highlights on hover, e.g. Friends/Who/Guild Roster rows via this same
    -- texture+ADD). Also shows the unit's tooltip, using the real raid-roster unit token (set in
    -- RefreshRaid as slot._unit — "raidN") so GameTooltip:SetUnit resolves health/buffs/etc.
    slot:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    slot:SetScript("OnEnter", function(self)
      if self._unit and UnitExists and UnitExists(self._unit) and GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(self._unit)
      end
    end)
    slot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    if s % 2 == 0 then
      local stripe = slot:CreateTexture(nil, "ARTWORK")
      stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
      stripe:SetVertexColor(1, 1, 1, 0.03)
      stripe:SetAllPoints(slot)
    end

    local icon = slot:CreateTexture(nil, "OVERLAY")
    icon:SetSize(10, 10)
    icon:SetPoint("LEFT", slot, "LEFT", 3, 0)
    icon:Hide()
    slot.icon = icon

    local fs = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", slot, "LEFT", 15, 0)
    fs:SetPoint("RIGHT", slot, "RIGHT", -3, 0)
    fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
    slot.text = fs

    box.slots[s] = slot
  end

  return box
end

-- Class icon summary strip. Owner report 2026-07-17: parked just outside the window's right edge
-- (the first placement), it was "very hard to see" — moved to a horizontal row directly below the
-- group grid instead, fully inside the visible panel. Still non-interactive: one icon per class
-- with a count of how many raid members are that class, no click/filter behavior. Reuses the same
-- class-icon sheet + coords as Guild Roster's class column (CLASS_ICON_TCOORDS is a stock global).
-- Sizes bumped (owner report 2026-07-17: "move the class icons down a bit and make them a little
-- larger") — icon 16->20, gap below the grid 4->10, strip/item sizes grown to match.
local CLASS_ICON_TEX  = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_ICON_SIZE = 20
local CLASS_STRIP_H   = 28
local CLASS_STRIP_GAP = 10
local CLASS_ITEM_W    = 40
local ORDERED_CLASSES = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
  "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local function buildClassSummary(panel, grid)
  local strip = CreateFrame("Frame", nil, panel)
  strip:SetSize(CLASS_ITEM_W * #ORDERED_CLASSES, CLASS_STRIP_H)
  strip:SetPoint("TOP", grid, "BOTTOM", 0, -CLASS_STRIP_GAP)
  panel.ClassSummaryStrip = strip

  panel._classIcons = {}
  local prev
  for _, classFile in ipairs(ORDERED_CLASSES) do
    local row = CreateFrame("Frame", nil, strip)
    row:SetSize(CLASS_ITEM_W, CLASS_STRIP_H)
    row:EnableMouse(true)
    if prev then row:SetPoint("LEFT", prev, "RIGHT", 0, 0)
    else row:SetPoint("LEFT", strip, "LEFT", 0, 0) end
    prev = row

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if c then
      icon:SetTexture(CLASS_ICON_TEX)
      icon:SetTexCoord(c[1], c[2], c[3], c[4])
    end

    local count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", icon, "RIGHT", 2, 0)

    row:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    panel._classIcons[classFile] = { icon = icon, count = count }
  end

  return strip
end

-- Owner steer 2026-07-17: "the group frames on the raid tab should sit inside the inset by 15px" —
-- the boxes were flush against the panel's own dark-inset border on the left/right.
local GRID_SIDE_INSET = 15

local function buildGroupGrid(panel)
  local grid = CreateFrame("Frame", nil, panel)
  grid:SetPoint("TOPLEFT", panel, "TOPLEFT", GRID_SIDE_INSET, -22 - SAVED_BLOCK_H)
  grid:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -GRID_SIDE_INSET, 34 + CLASS_STRIP_GAP + CLASS_STRIP_H)
  panel.Grid = grid

  local leftCol = CreateFrame("Frame", nil, grid)
  leftCol:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 0)
  leftCol:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", 0, 0)
  leftCol:SetPoint("RIGHT", grid, "CENTER", -COL_GAP_X / 2, 0)

  local rightCol = CreateFrame("Frame", nil, grid)
  rightCol:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, 0)
  rightCol:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", 0, 0)
  rightCol:SetPoint("LEFT", grid, "CENTER", COL_GAP_X / 2, 0)

  panel._groupBoxes = {}
  for i, g in ipairs(LEFT_GROUPS) do
    panel._groupBoxes[g] = buildGroupBox(leftCol, g, i)
  end
  for i, g in ipairs(RIGHT_GROUPS) do
    panel._groupBoxes[g] = buildGroupBox(rightCol, g, i)
  end

  return grid
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

  buildSavedInstances(panel)
  local grid = buildGroupGrid(panel)
  buildClassSummary(panel, grid)

  -- Ready Check (owner steer 2026-07-17, marked with a screenshot annotation in the chrome gap
  -- under the title). Parented to `panel` (so it shows/hides with the Raid tab like everything
  -- else here) but anchored off the WINDOW frame, since that gap sits above the panel's own top
  -- edge (panel content starts 56px down; the title text itself only runs to about -20).
  -- DoReadyCheck() (confirmed via the on-client APIDocumentation addon, PartyDocumentation.lua /
  -- RaidDocumentation.lua) works for both a party and a raid; only the leader/an assist can call it,
  -- so the button is enabled/disabled the same way Convert to Raid already is.
  local ready = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  ready:SetSize(110, 20)
  ready:SetText(READY_CHECK or "Ready Check")
  ready:SetPoint("TOP", f, "TOP", 0, -33)
  ready:SetScript("OnClick", function()
    if DoReadyCheck then DoReadyCheck() end
  end)
  panel.ReadyCheck = ready

  -- Raid Browser (owner report 2026-07-17: "doesn't open anything" — ToggleRaidBrowser isn't a real
  -- 3.3.5a global, it doesn't exist on this client and the call was silently no-op'ing. Patch 3.3's
  -- actual Icecrown Raid Finder frame is LFRParentFrame, toggled with ToggleLFRParentFrame — confirmed
  -- as the live, working call via AddOns/DragonUI/modules/micromenu.lua:2649, which drives the same
  -- frame from the minimap LFG eye's "listed" mode.) Moved into the bottom outer-chrome band
  -- alongside Convert to Raid (owner steer 2026-07-17: the group grid replaced the old empty-state
  -- blurb it used to live inside).
  local browser = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  browser:SetSize(140, 22); browser:SetText(RAID_BROWSER_BUTTON or "Raid Browser")
  browser:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, -29)
  browser:SetScript("OnClick", function()
    if ToggleLFRParentFrame then ToggleLFRParentFrame() end
  end)
  panel.Browser = browser

  -- Convert to Raid (party leader, not already a raid). Anchored 29px below panel's own bottom
  -- edge, not +4 (owner report 2026-07-17, same fix as the Friends/Who tab buttons: panel's dark
  -- inset covers its full extent down to its own bottom edge, which already sits 36px above the
  -- window's true bottom — +4 sat the button inside the dark inset instead of the outer grey
  -- chrome band below it).
  local convert = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  convert:SetSize(140, 22); convert:SetText(CONVERT_TO_RAID or "Convert to Raid")
  convert:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, -29)
  convert:SetScript("OnClick", function()
    if ConvertToRaid then ConvertToRaid() end
    SO.RefreshRaid()
  end)
  panel.Convert = convert

  -- Raid Info button REMOVED (owner steer 2026-07-17): the popup is redundant now that its
  -- lockout info is surfaced inline via buildSavedInstances() above.
  if RequestRaidInfo then RequestRaidInfo() end
  SO.RefreshSavedInstances()
  SO.RefreshRaid()
end

function SO.RefreshRaid()
  local f = SO.frame
  local panel = f and f.RaidPanel
  if not (panel and panel._groupBoxes) then return end

  for g = 1, NUM_GROUPS do
    local box = panel._groupBoxes[g]
    for s = 1, SLOTS_PER_GROUP do
      local slot = box.slots[s]
      slot.icon:Hide()
      slot.text:SetText(EMPTY_LABEL)
      slot.text:SetTextColor(0.5, 0.5, 0.5)
      slot.text:SetAlpha(1)
      slot._name = nil
      slot._unit = nil
      -- Owner steer 2026-07-17: match Channels roster — no hover glow on empty slots.
      slot:EnableMouse(false)
    end
  end

  local total = (GetNumRaidMembers and GetNumRaidMembers()) or 0
  -- Fill position within each group tracked independently of raid roster index (subgroup members
  -- aren't guaranteed contiguous/in-order in the GetRaidRosterInfo iteration).
  local fillPos = {}
  local classCounts = {}
  for i = 1, total do
    local name, rank, subgroup, level, _, fileName, zone, online = GetRaidRosterInfo(i)
    if fileName then classCounts[fileName] = (classCounts[fileName] or 0) + 1 end
    if name and subgroup and subgroup >= 1 and subgroup <= NUM_GROUPS then
      fillPos[subgroup] = (fillPos[subgroup] or 0) + 1
      local pos = fillPos[subgroup]
      if pos <= SLOTS_PER_GROUP then
        local slot = panel._groupBoxes[subgroup].slots[pos]
        slot._name = name
        slot._unit = "raid" .. i
        slot:EnableMouse(true)
        if rank == 2 then
          slot.icon:SetTexture(LEADER_ICON); slot.icon:Show()
        elseif rank == 1 then
          slot.icon:SetTexture(ASSIST_ICON); slot.icon:Show()
        else
          slot.icon:Hide()
        end
        local className = fileName and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[fileName]
        slot.text:SetText(string.format("%s  %d  %s", name, level or 0, className or ""))
        local r, gC, b = classColor(fileName)
        slot.text:SetTextColor(r, gC, b)
        slot.text:SetAlpha(online and 1 or 0.5)
      end
    end
  end

  -- Class summary strip: count + full-color icon when present in the raid, desaturated/dimmed and
  -- blank count otherwise.
  if panel._classIcons then
    for classFile, entry in pairs(panel._classIcons) do
      local n = classCounts[classFile] or 0
      if n > 0 then
        entry.icon:SetDesaturated(false)
        entry.icon:SetAlpha(1)
        entry.count:SetText(tostring(n))
        entry.count:SetTextColor(1, 1, 1)
      else
        entry.icon:SetDesaturated(true)
        entry.icon:SetAlpha(0.4)
        entry.count:SetText("")
      end
    end
  end

  -- Convert only makes sense as a party leader who isn't already in a raid. The stock window
  -- keeps the button visible-but-disabled rather than hiding it.
  local inRaid = total > 0
  local canConvert = not inRaid
    and (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
    and (IsPartyLeader and IsPartyLeader())
  if canConvert then panel.Convert:Enable() else panel.Convert:Disable() end

  -- Ready Check: only the raid leader/an assist (or the party leader, pre-conversion) can call it.
  local canReadyCheck
  if inRaid then
    canReadyCheck = (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
  else
    canReadyCheck = (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
      and (IsPartyLeader and IsPartyLeader())
  end
  if panel.ReadyCheck then
    if canReadyCheck then panel.ReadyCheck:Enable() else panel.ReadyCheck:Disable() end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() if SO.RefreshRaid then SO.RefreshRaid() end end)

-- Saved-instance lockouts are independent of raid roster/party state (UPDATE_INSTANCE_INFO fires
-- whenever the server (re)sends lockout data, e.g. after RequestRaidInfo() or on zoning into/out
-- of an instance) -- kept on its own event frame rather than folded into `ev` above so a lockout
-- refresh doesn't require also touching the roster rows.
local savedEv = CreateFrame("Frame")
pcall(savedEv.RegisterEvent, savedEv, "UPDATE_INSTANCE_INFO")
savedEv:SetScript("OnEvent", function() if SO.RefreshSavedInstances then SO.RefreshSavedInstances() end end)
