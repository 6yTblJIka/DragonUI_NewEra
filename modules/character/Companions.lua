-- DragonUI_NewEra/modules/character/Companions.lua — Mounts & Companions browser.
--
-- Shares the Pet tab's pane (DragonUI_NewEra_CharacterPane_Pet) rather than adding a whole new
-- top-level tab, since on this server mounts and non-combat companion pets are both queried through
-- the same pre-Cata Companions API and conceptually belong together with "your pet stuff".
--
-- Two small buttons in the pane's top-right corner switch between:
--   "My Pet"     -- the existing PetPaperDoll.lua model/stats view (untouched).
--   "Collection" -- a scrollable icon grid of mounts + companion pets, with a Mounts/Companions
--                   filter. Left-click an icon to preview its 3D model (in the space normally used
--                   by the pet-stats sidebar - mounts/companions have no combat stats worth showing,
--                   so that space is repurposed here). Right-click to summon it, or dismiss it if
--                   it's already active.
--
-- DATA (3.3.5a pre-Cata Companions API):
--   GetNumCompanions("MOUNT"/"CRITTER")
--   GetCompanionInfo("type", index) -> creatureID, creatureName, creatureSpellID, icon, issummoned, mountTypeID
--   CallCompanion("type", index) / DismissCompanion("type")
--   PlayerModel:SetCreature(creatureID) -- added 3.0.2, so this works even without summoning anything.
--   Events: COMPANION_LEARNED, COMPANION_UPDATE
-- Every call is pcall-guarded — a server with a slightly different Companions implementation should
-- degrade to an empty/disabled grid rather than error. Note per Blizzard's own bug reports,
-- SetCreature() only reliably shows a model if that creature's model is already client-cached; since
-- these are the player's own learned companions that's normally already true.

local NE = DragonUI_NewEra
NE.charpanel = NE.charpanel or {}
local CP = NE.charpanel

local function log(msg)
  if CP._log then CP._log("COMPANIONS: " .. tostring(msg)); return end
  if NE.Log then NE.Log("COMPANIONS", msg) end
end

local ICON_SIZE   = 36
local ICON_GAP    = 14   -- breathing room for the enlarged "currently summoned" ring
local COLS        = 6
local TOGGLE_H    = 20
local FILTER_H    = 20
local SCROLL_GAP  = 16   -- room reserved on the right for the custom scrollbar
local BORDER_SIZE = 10   -- how far the summoned/preview rings extend past the icon, each side
local BORDER_THICK = 3   -- ring line thickness

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local pane
local topRow, petModeBtn, collectionModeBtn
local collectionFrame, filterRow, mountFilterBtn, critterFilterBtn
local scroll, content, emptyLabel
local previewHost, previewModel, previewName, previewHint
local activeFilter = "MOUNT"     -- "MOUNT" or "CRITTER"
local collectionActive = false
local previewedData               -- the companion currently shown in the 3D preview (or nil)
local icons = {}                  -- recycled icon buttons
local list  = {}                  -- flat list of companion data for the active filter

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
    local okI, creatureID, name, spellID, icon, issummoned = pcall(GetCompanionInfo, activeFilter, i)
    if okI and name then
      n = n + 1
      list[n] = {
        index = i, creatureID = creatureID, name = name,
        spellID = spellID, icon = icon, issummoned = issummoned,
      }
    end
  end
end

-- ---------------------------------------------------------------------------
-- 3D preview (repurposes the pet-stats sidebar's InsetRight space - see applySidebarMode below)
-- ---------------------------------------------------------------------------
local function buildPreview()
  if previewModel then return true end
  local host = CP.InsetRight
  if not host then return false end
  previewHost = host

  local ok, m = pcall(CreateFrame, "PlayerModel", "DragonUI_NewEra_CompanionPreviewModel", host)
  if not ok or not m then log("buildPreview: PlayerModel creation failed"); return false end
  previewModel = m
  previewModel:SetPoint("TOPLEFT", host, "TOPLEFT", 3, -24)
  previewModel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -3, 3)
  previewModel:EnableMouse(true)
  previewModel:SetScript("OnMouseDown", function(self)
    self._rotating = true
    self._lastX = GetCursorPosition()
  end)
  previewModel:SetScript("OnMouseUp", function(self) self._rotating = false end)
  previewModel:SetScript("OnUpdate", function(self)
    if not self._rotating then return end
    local x = GetCursorPosition()
    local dx = x - (self._lastX or x)
    self._lastX = x
    if dx ~= 0 then
      self._rot = (self._rot or 0) - dx * 0.01
      pcall(self.SetRotation, self, self._rot)
    end
  end)

  previewName = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  previewName:SetPoint("TOP", host, "TOP", 0, -6)
  previewName:SetPoint("LEFT", host, "LEFT", 6, 0)
  previewName:SetPoint("RIGHT", host, "RIGHT", -6, 0)

  previewHint = host:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  previewHint:SetPoint("CENTER", previewModel, "CENTER", 0, 0)
  previewHint:SetText("Left-click an icon to preview it here.\nRight-click to summon/dismiss.")

  return true
end

local function showPreview(data)
  previewedData = data
  if not (previewModel and buildPreview()) then return end
  if not data then
    previewModel:Hide()
    if previewName then previewName:SetText("") end
    if previewHint then previewHint:Show() end
    return
  end
  if previewHint then previewHint:Hide() end
  previewModel:Show()
  if data.creatureID then
    pcall(previewModel.SetCreature, previewModel, data.creatureID)
  end
  previewModel._rot = 0
  pcall(previewModel.SetRotation, previewModel, 0)
  if previewName then previewName:SetText(data.name) end
end

-- ---------------------------------------------------------------------------
-- Icon grid (recycled buttons on a plain, pixel-scrolled ScrollFrame)
-- ---------------------------------------------------------------------------
local function iconOnClick(self, button)
  local data = self._data
  if not data then return end
  if button == "RightButton" then
    if data.issummoned then
      pcall(DismissCompanion, activeFilter)
    else
      pcall(CallCompanion, activeFilter, data.index)
    end
    -- COMPANION_UPDATE should refresh us, but nudge shortly after in case a server doesn't fire it.
    if C_Timer and C_Timer.After then
      C_Timer.After(0.2, function() if CP.RefreshCollection then pcall(CP.RefreshCollection) end end)
    end
  else
    showPreview(data)
    if CP.RefreshCollection then pcall(CP.RefreshCollection) end -- to update the preview-ring highlight
  end
end

local function iconOnEnter(self)
  local data = self._data
  if not data then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(data.name, 1, 1, 1)
  if data.issummoned then
    GameTooltip:AddLine("Right-click to dismiss", 0, 1, 0)
  else
    GameTooltip:AddLine("Right-click to summon", 1, 0.82, 0)
  end
  GameTooltip:AddLine("Left-click to preview", 0.6, 0.8, 1)
  GameTooltip:Show()
end

-- A single, clean backdrop ring (rather than a stretched icon-border texture, which distorts once
-- pushed this far out) so both the "summoned" and "previewing" indicators stay crisp at this size.
local function makeRing(parent, r, g, b)
  local ring = CreateFrame("Frame", nil, parent)
  ring:SetPoint("TOPLEFT", parent, "TOPLEFT", -BORDER_SIZE, BORDER_SIZE)
  ring:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", BORDER_SIZE, -BORDER_SIZE)
  ring:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = BORDER_THICK,
  })
  ring:SetBackdropBorderColor(r, g, b, 1)
  ring:Hide()
  return ring
end

local function acquireIcon(i)
  if icons[i] then return icons[i] end
  local b = CreateFrame("Button", nil, content)
  b:SetSize(ICON_SIZE, ICON_SIZE)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local tex = b:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b._icon = tex

  local slotTex = b:CreateTexture(nil, "BACKGROUND")
  slotTex:SetAllPoints(b)
  slotTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  b._slot = slotTex

  -- Green: this one is currently summoned. Blue: this one is what's in the 3D preview. Both can be
  -- shown at once (offset slightly) since they mean different things.
  b._activeRing = makeRing(b, 0.25, 1, 0.25)
  b._previewRing = makeRing(b, 0.35, 0.7, 1)
  b._previewRing:SetPoint("TOPLEFT", b, "TOPLEFT", -(BORDER_SIZE + BORDER_THICK + 2), (BORDER_SIZE + BORDER_THICK + 2))
  b._previewRing:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", (BORDER_SIZE + BORDER_THICK + 2), -(BORDER_SIZE + BORDER_THICK + 2))

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

  -- Extra spacing beyond the icon+ring so neighboring rings never touch.
  local cellW = ICON_SIZE + ICON_GAP + BORDER_SIZE
  for i, data in ipairs(list) do
    local b = acquireIcon(i)
    b._data = data
    if data.icon then b._icon:SetTexture(data.icon) end
    if data.issummoned then b._activeRing:Show() else b._activeRing:Hide() end
    if previewedData and previewedData.index == data.index then
      b._previewRing:Show()
    else
      b._previewRing:Hide()
    end
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
  showPreview(nil)
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
  content:SetWidth((ICON_SIZE + ICON_GAP + BORDER_SIZE) * COLS + ICON_GAP)
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

-- Swap what's showing in the pet-stats sidebar's InsetRight space: the normal pet stats pane for
-- "My Pet", our 3D preview for "Collection". Both are children of the same InsetRight and just take
-- turns being Shown/Hidden - the sidebar stays expanded (548-wide frame) the whole time, which is
-- what actually frees up the space rather than collapsing it away.
local function applySidebarMode(showCollectionSide)
  if CP.ExpandPetSidebar then pcall(CP.ExpandPetSidebar) end -- ensures InsetRight/frame width + builds the stats pane
  if showCollectionSide then
    if CP._sidebar then CP._sidebar:Hide() end
    if buildPreview() then
      showPreview(previewedData) -- re-show whatever was last previewed, or the hint if nothing was
      previewModel:Show()
    end
  else
    if previewModel then previewModel:Hide() end
    if previewName then previewName:SetText("") end
    if previewHint then previewHint:Hide() end
    -- CP.ExpandPetSidebar above already re-showed CP._sidebar with fresh pet stats.
  end
end
CP.SyncPetSidebarForCollection = function() applySidebarMode(true) end

local function showCollection(show)
  collectionActive = show
  if CP.SetPetCollectionMode then pcall(CP.SetPetCollectionMode, show) end
  if collectionFrame then
    if show then collectionFrame:Show() else collectionFrame:Hide() end
  end
  if show then refreshCollection() end
  applySidebarMode(show)
  setButtonEnabled(petModeBtn, show)
  setButtonEnabled(collectionModeBtn, not show)
end
CP.ShowPetCollection = showCollection

-- Exposed so TabButtons.lua's "Pet" tab-select branch knows whether re-entering the Pet tab should
-- restore the normal pet-stats sidebar or keep showing the Collection preview (TabButtons otherwise
-- unconditionally calls CP.ExpandPetSidebar() for the Pet tab, which would yank the model preview
-- away and put the stale pet stats back up).
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