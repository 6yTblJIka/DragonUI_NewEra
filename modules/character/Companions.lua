-- DragonUI_NewEra/modules/character/Companions.lua — Mounts & Companions browser.
--
-- Shares the Pet tab's pane (DragonUI_NewEra_CharacterPane_Pet) rather than adding a whole new
-- top-level tab, since on this server mounts and non-combat companion pets are both queried through
-- the same pre-Cata Companions API and conceptually belong together with "your pet stuff".
--
-- Two small buttons in the pane's top-right corner switch between:
--   "My Pet"    -- the existing PetPaperDoll.lua model/stats view (untouched).
--   "Collection" -- a scrollable icon grid of mounts + companion pets, with a Mounts/Companions
--                   filter. Click an icon to summon it; click the currently-summoned one again to
--                   dismiss it (same convention as Blizzard's later Mount Journal).
--
-- DATA (3.3.5a pre-Cata Companions API):
--   GetNumCompanions("MOUNT"/"CRITTER")
--   GetCompanionInfo("type", index) -> creatureID, creatureName, creatureSpellID, icon, issummoned, mountTypeID
--   CallCompanion("type", index) / DismissCompanion("type")
--   Events: COMPANION_LEARNED, COMPANION_UPDATE
-- Every call is pcall-guarded — a server with a slightly different Companions implementation should
-- degrade to an empty/disabled grid rather than error.

local NE = DragonUI_NewEra
NE.charpanel = NE.charpanel or {}
local CP = NE.charpanel

local function log(msg)
  if CP._log then CP._log("COMPANIONS: " .. tostring(msg)); return end
  if NE.Log then NE.Log("COMPANIONS", msg) end
end

local ICON_SIZE   = 36
local ICON_GAP    = 6
local COLS        = 6
local TOGGLE_H    = 20
local FILTER_H    = 20
local SCROLL_GAP  = 16   -- room reserved on the right for the custom scrollbar

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local pane
local topRow, petModeBtn, collectionModeBtn
local collectionFrame, filterRow, mountFilterBtn, critterFilterBtn
local scroll, content, emptyLabel
local activeFilter = "MOUNT"     -- "MOUNT" or "CRITTER"
local collectionActive = false
local icons = {}                 -- recycled icon buttons
local list  = {}                 -- flat list of companion data for the active filter

local function getPane()
  if pane then return pane end
  pane = _G.DragonUI_NewEra_CharacterPane_Pet or (CP.EnsurePane and CP.EnsurePane("Pet"))
  return pane
end

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------
local function rebuildList()
  for i = #list, 1, -1 do list[i] = nil end
  local ok, count = pcall(GetNumCompanions, activeFilter)
  count = (ok and count) or 0
  local n = 0
  for i = 1, count do
    local okI, _, name, spellID, icon, issummoned = pcall(GetCompanionInfo, activeFilter, i)
    if okI and name then
      n = n + 1
      list[n] = { index = i, name = name, spellID = spellID, icon = icon, issummoned = issummoned }
    end
  end
end

-- ---------------------------------------------------------------------------
-- Icon grid (recycled buttons on a plain, pixel-scrolled ScrollFrame)
-- ---------------------------------------------------------------------------
local function iconOnClick(self)
  local data = self._data
  if not data then return end
  if data.issummoned then
    pcall(DismissCompanion, activeFilter)
  else
    pcall(CallCompanion, activeFilter, data.index)
  end
  -- COMPANION_UPDATE should refresh us, but nudge shortly after in case a server doesn't fire it.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.2, function() if CP.RefreshCollection then pcall(CP.RefreshCollection) end end)
  end
end

local function iconOnEnter(self)
  local data = self._data
  if not data then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(data.name, 1, 1, 1)
  if data.issummoned then
    GameTooltip:AddLine(_G.CANCEL and (_G.CANCEL .. " (click to dismiss)") or "Click to dismiss", 0, 1, 0)
  else
    GameTooltip:AddLine("Click to summon", 1, 0.82, 0)
  end
  GameTooltip:Show()
end

local function acquireIcon(i)
  if icons[i] then return icons[i] end
  local b = CreateFrame("Button", nil, content)
  b:SetSize(ICON_SIZE, ICON_SIZE)

  local tex = b:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b._icon = tex

  local slotTex = b:CreateTexture(nil, "BACKGROUND")
  slotTex:SetAllPoints(b)
  slotTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  b._slot = slotTex

  local activeBorder = b:CreateTexture(nil, "OVERLAY")
  activeBorder:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
  activeBorder:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
  activeBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  activeBorder:SetBlendMode("ADD")
  activeBorder:SetVertexColor(0.2, 1, 0.2)
  activeBorder:Hide()
  b._activeBorder = activeBorder

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b)
  hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  hl:SetBlendMode("ADD")

  b:SetScript("OnEnter", iconOnEnter)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnClick", iconOnClick)

  icons[i] = b
  return b
end

local function hideAllIcons()
  for _, b in ipairs(icons) do b:Hide() end
end

local function layoutGrid()
  if not content then return end
  hideAllIcons()

  if #list == 0 then
    if emptyLabel then
      emptyLabel:SetText(activeFilter == "MOUNT"
        and "You have not learned any mounts."
        or "You have not learned any companion pets.")
      emptyLabel:Show()
    end
    content:SetHeight(1)
    return
  end
  if emptyLabel then emptyLabel:Hide() end

  local cellW = ICON_SIZE + ICON_GAP
  for i, data in ipairs(list) do
    local b = acquireIcon(i)
    b._data = data
    if data.icon then b._icon:SetTexture(data.icon) end
    if data.issummoned then b._activeBorder:Show() else b._activeBorder:Hide() end
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", content, "TOPLEFT", col * cellW + ICON_GAP, -(row * cellW + ICON_GAP))
    b:Show()
  end

  local rows = math.max(1, math.ceil(#list / COLS))
  content:SetHeight(rows * cellW + ICON_GAP)
end

local function refreshCollection()
  if not collectionActive then return end
  rebuildList()
  layoutGrid()
end
CP.RefreshCollection = refreshCollection

-- ---------------------------------------------------------------------------
-- Filter buttons (Mounts / Companions)
-- ---------------------------------------------------------------------------
-- 3.3.5a Button widgets use Enable()/Disable(), not the retail SetEnabled(bool) convenience method.
local function setButtonEnabled(btn, enabled)
  if not btn then return end
  if enabled then pcall(btn.Enable, btn) else pcall(btn.Disable, btn) end
end

local function setFilterArt()
  setButtonEnabled(mountFilterBtn, activeFilter ~= "MOUNT")
  setButtonEnabled(critterFilterBtn, activeFilter ~= "CRITTER")
end

local function selectFilter(filter)
  if activeFilter == filter then return end
  activeFilter = filter
  setFilterArt()
  refreshCollection()
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
local function buildCollectionFrame(host)
  if collectionFrame then return end

  collectionFrame = CreateFrame("Frame", nil, host)
  collectionFrame:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -(TOGGLE_H + 8))
  collectionFrame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -4, 4)
  collectionFrame:Hide()

  filterRow = CreateFrame("Frame", nil, collectionFrame)
  filterRow:SetPoint("TOPLEFT", collectionFrame, "TOPLEFT", 0, 0)
  filterRow:SetPoint("TOPRIGHT", collectionFrame, "TOPRIGHT", 0, 0)
  filterRow:SetHeight(FILTER_H)

  mountFilterBtn = CreateFrame("Button", nil, filterRow, "UIPanelButtonTemplate")
  mountFilterBtn:SetSize(90, FILTER_H)
  mountFilterBtn:SetPoint("TOPLEFT", filterRow, "TOPLEFT", 0, 0)
  mountFilterBtn:SetText(_G.MOUNTS or "Mounts")
  mountFilterBtn:SetScript("OnClick", function() selectFilter("MOUNT") end)

  critterFilterBtn = CreateFrame("Button", nil, filterRow, "UIPanelButtonTemplate")
  critterFilterBtn:SetSize(90, FILTER_H)
  critterFilterBtn:SetPoint("LEFT", mountFilterBtn, "RIGHT", 4, 0)
  critterFilterBtn:SetText(_G.COMPANIONS or "Companions")
  critterFilterBtn:SetScript("OnClick", function() selectFilter("CRITTER") end)

  scroll = CreateFrame("ScrollFrame", "DragonUI_NewEra_CompanionsScroll", collectionFrame)
  scroll:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", 0, -6)
  scroll:SetPoint("BOTTOMRIGHT", collectionFrame, "BOTTOMRIGHT", -SCROLL_GAP, 0)
  scroll:EnableMouseWheel(true)

  content = CreateFrame("Frame", nil, scroll)
  content:SetWidth((ICON_SIZE + ICON_GAP) * COLS + ICON_GAP)
  content:SetHeight(1)
  content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  scroll:SetScrollChild(content)

  if NE.scrollbar and NE.scrollbar.BuildCustomPixel then
    pcall(NE.scrollbar.BuildCustomPixel, scroll, { x = -1 })
  end

  emptyLabel = collectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  emptyLabel:SetPoint("TOP", scroll, "TOP", 0, -20)
  emptyLabel:Hide()

  setFilterArt()
end

local function showCollection(show)
  collectionActive = show
  if CP.SetPetCollectionMode then pcall(CP.SetPetCollectionMode, show) end
  if collectionFrame then
    if show then collectionFrame:Show() else collectionFrame:Hide() end
  end
  if show then
    refreshCollection()
    -- Companions/mounts have no combat stats worth showing - collapse the right-side sidebar so it
    -- doesn't sit there next to the grid still displaying the last live pet's Health/Armor/etc.
    if CP.CollapseSidebar then pcall(CP.CollapseSidebar) end
  else
    -- Back to an actual class pet - bring the stats sidebar back.
    if CP.ExpandPetSidebar then pcall(CP.ExpandPetSidebar)
    elseif CP.ExpandSidebar then pcall(CP.ExpandSidebar) end
  end
  setButtonEnabled(petModeBtn, show)
  setButtonEnabled(collectionModeBtn, not show)
end
CP.ShowPetCollection = showCollection

-- Exposed so TabButtons.lua's "Pet" tab-select branch can ask whether it should expand the pet-stats
-- sidebar or leave it collapsed - re-entering the Pet tab mid-Collection would otherwise re-expand it
-- (TabButtons unconditionally calls CP.ExpandPetSidebar() for the Pet tab).
function CP.IsPetCollectionActive()
  return collectionActive
end

local function buildToggle(host)
  if topRow then return end

  topRow = CreateFrame("Frame", nil, host)
  topRow:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -4)
  topRow:SetSize(160, TOGGLE_H)
  topRow:SetFrameLevel((host:GetFrameLevel() or 1) + 20)

  collectionModeBtn = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
  collectionModeBtn:SetSize(78, TOGGLE_H)
  collectionModeBtn:SetPoint("TOPRIGHT", topRow, "TOPRIGHT", 0, 0)
  collectionModeBtn:SetText("Collection")
  collectionModeBtn:SetScript("OnClick", function() showCollection(true) end)

  petModeBtn = CreateFrame("Button", nil, topRow, "UIPanelButtonTemplate")
  petModeBtn:SetSize(78, TOGGLE_H)
  petModeBtn:SetPoint("RIGHT", collectionModeBtn, "LEFT", -4, 0)
  petModeBtn:SetText(_G.PET or "My Pet")
  petModeBtn:SetScript("OnClick", function() showCollection(false) end)
  setButtonEnabled(petModeBtn, false) -- resting state = Pet view
end

local function build()
  local host = getPane()
  if not host then return false end
  buildToggle(host)
  buildCollectionFrame(host)
  return true
end

-- ---------------------------------------------------------------------------
-- Events: companions learned/updated keep the grid in sync; also refresh whenever the Pet tab
-- becomes the active tab (TabButtons.lua's refreshers table doesn't know about us, so re-assert the
-- resting Pet-view / re-show ourselves if we're mid-Collection when the tab is re-entered).
-- ---------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("COMPANION_LEARNED")
boot:RegisterEvent("COMPANION_UPDATE")
boot:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if C_Timer and C_Timer.After then C_Timer.After(0, build) else build() end
  else
    refreshCollection()
  end
end)
