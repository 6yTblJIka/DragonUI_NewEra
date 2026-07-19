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
local previewHost, previewLayer, previewModel, previewName, previewHint, previewFavBtn
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
-- Favorites (per-character, persisted in NE.db - see bootstrap.lua schema 2)
-- ---------------------------------------------------------------------------
-- Keyed by filter+creatureID rather than list index/slot, since GetCompanionInfo's slot ordering
-- isn't guaranteed stable across sessions (per Blizzard's own docs) - creatureID is the one thing
-- that reliably identifies "this specific mount/pet" from one login to the next.
local function favKey(data)
  if not (data and data.creatureID) then return nil end
  return activeFilter .. ":" .. tostring(data.creatureID)
end

local function favTable()
  if not (NE.db and NE.CharKey) then return nil end
  NE.db.companionFavorites = NE.db.companionFavorites or {}
  local key = NE.CharKey()
  NE.db.companionFavorites[key] = NE.db.companionFavorites[key] or {}
  return NE.db.companionFavorites[key]
end

local function isFavorite(data)
  local t, k = favTable(), favKey(data)
  return t ~= nil and k ~= nil and t[k] == true
end

local function setFavorite(data, fav)
  local t, k = favTable(), favKey(data)
  if not (t and k) then return end
  if fav then t[k] = true else t[k] = nil end
end

-- Stable partition: favorites first (in their existing relative order), then everything else -
-- rather than a full sort, so non-favorites don't get shuffled around by name/index each refresh.
local function applyFavoritesOrder()
  local t = favTable()
  if not t then return end
  local favs, rest = {}, {}
  for _, data in ipairs(list) do
    local k = favKey(data)
    if k and t[k] then table.insert(favs, data) else table.insert(rest, data) end
  end
  local n = 0
  for i = 1, #favs do n = n + 1; list[n] = favs[i] end
  for i = 1, #rest do n = n + 1; list[n] = rest[i] end
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
  applyFavoritesOrder()
end

-- ---------------------------------------------------------------------------
-- 3D preview (repurposes the pet-stats sidebar's InsetRight space - see applySidebarMode below)
-- ---------------------------------------------------------------------------
-- Reuses the same 4-quarter race-keyed background ModelArea.lua stitches behind the main Character
-- tab's CharacterModelFrame (desaturated + dark race-tinted overlay), via the CP.RaceBgQuarters(race)
-- lookup it exposes for exactly this kind of reuse. Native quarter art is proportioned for a 231x320
-- model (retail's fixed size); our preview frame is a different size (it fills whatever's left of
-- InsetRight), so instead of fixed pixel dimensions like ModelArea.lua uses, each quarter is sized as
-- a fraction of the preview frame's actual width/height, recomputed on OnSizeChanged.
local RACE_BG_W_TL, RACE_BG_W_TR = 212 / 231, 19 / 231
local RACE_BG_H_TL, RACE_BG_H_BL = 245 / 373, 128 / 373

local function resizePreviewBg(model)
  local w, h = model:GetWidth(), model:GetHeight()
  if not w or not h or w <= 0 or h <= 0 then return end
  local tlW, trW = w * RACE_BG_W_TL, w * RACE_BG_W_TR
  local tlH, blH = h * RACE_BG_H_TL, h * RACE_BG_H_BL
  model._bgTL:SetSize(tlW, tlH)
  model._bgTR:SetSize(trW, tlH)
  model._bgBL:SetSize(tlW, blH)
  model._bgBR:SetSize(trW, blH)
end

local function buildPreviewBackground(model)
  if model._neBgBuilt then return end

  local bgTL = model:CreateTexture(nil, "BACKGROUND")
  bgTL:SetPoint("TOPLEFT", model, "TOPLEFT", 0, 0)
  bgTL:SetTexCoord(0.171875, 1, 0.0392156862745098, 1)

  local bgTR = model:CreateTexture(nil, "BACKGROUND")
  bgTR:SetPoint("TOPLEFT", bgTL, "TOPRIGHT", 0, 0)
  bgTR:SetTexCoord(0, 0.296875, 0.0392156862745098, 1)

  local bgBL = model:CreateTexture(nil, "BACKGROUND")
  bgBL:SetPoint("TOPLEFT", bgTL, "BOTTOMLEFT", 0, 0)
  bgBL:SetTexCoord(0.171875, 1, 0, 1)

  local bgBR = model:CreateTexture(nil, "BACKGROUND")
  bgBR:SetPoint("TOPLEFT", bgTL, "BOTTOMRIGHT", 0, 0)
  bgBR:SetTexCoord(0, 0.296875, 0, 1)

  -- Same dark race-tint overlay ModelArea.lua uses, above the bg quarters / below the model.
  local overlay = model:CreateTexture(nil, "BORDER")
  if overlay.SetColorTexture then overlay:SetColorTexture(0, 0, 0) else overlay:SetTexture(0, 0, 0) end
  overlay:SetPoint("TOPLEFT", bgTL, "TOPLEFT", 0, 0)
  overlay:SetPoint("BOTTOMRIGHT", bgBR, "BOTTOMRIGHT", 0, 0)

  model._bgTL, model._bgTR, model._bgBL, model._bgBR, model._bgOverlay = bgTL, bgTR, bgBL, bgBR, overlay
  model._neBgBuilt = true
  model:SetScript("OnSizeChanged", resizePreviewBg)
end

local function applyPreviewRaceBackground(model)
  if not (model and CP.RaceBgQuarters) then return end
  buildPreviewBackground(model)
  if not model._neBgBuilt then return end

  local _, raceFile = UnitRace("player")
  local q1, q2, q3, q4, alpha = CP.RaceBgQuarters(raceFile)
  model._bgTL:SetTexture(q1)
  model._bgTR:SetTexture(q2)
  model._bgBL:SetTexture(q3)
  model._bgBR:SetTexture(q4)
  for _, t in ipairs({ model._bgTL, model._bgTR, model._bgBL, model._bgBR }) do
    if t.SetDesaturated then pcall(t.SetDesaturated, t, true) end
  end
  model._bgOverlay:SetAlpha(alpha)
  resizePreviewBg(model)
end

local function buildPreview()
  if previewModel then return true end
  local host = CP.InsetRight
  if not host then return false end
  previewHost = host

  -- Everything below is parented to this wrapper rather than directly to host. A level bump alone
  -- (host+50) wasn't enough - some sidebar element (likely a "sticky" category header that isn't
  -- actually a child of CP._sidebar, so CP._sidebar:Hide() never touches it) kept drawing over the
  -- bottom of the model. Bumping to DIALOG strata is the blunt-but-reliable fix: strata beats level
  -- regardless of what else is in that frame subtree or how it's parented.
  local layer = CreateFrame("Frame", nil, host)
  layer:SetAllPoints(host)
  layer:SetFrameStrata("DIALOG")
  layer:SetFrameLevel((host:GetFrameLevel() or 1) + 50)
  layer:Hide()
  previewLayer = layer

  -- Full-bleed opaque backstop covering the ENTIRE layer (not just the model's own inset bounds).
  -- CP._sidebar:Hide() below is still attempted, but this is the part that actually guarantees
  -- nothing behind it - sidebar rows or otherwise - can bleed through the top/edge gaps around the
  -- model that the race-bg quarters don't cover.
  local backstop = layer:CreateTexture(nil, "BACKGROUND")
  backstop:SetAllPoints(layer)
  if backstop.SetColorTexture then
    backstop:SetColorTexture(0.06, 0.06, 0.08, 1)
  else
    backstop:SetTexture(0.06, 0.06, 0.08, 1)
  end

  local ok, m = pcall(CreateFrame, "PlayerModel", "DragonUI_NewEra_CompanionPreviewModel", layer)
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
  pcall(applyPreviewRaceBackground, previewModel)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function() pcall(resizePreviewBg, previewModel) end)
  end

  previewName = layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  previewName:SetPoint("TOP", host, "TOP", 0, -6)
  previewName:SetPoint("LEFT", host, "LEFT", 6, 0)
  previewName:SetPoint("RIGHT", host, "RIGHT", -26, 0) -- leave room for the favorite checkbox

  previewFavBtn = CreateFrame("CheckButton", nil, layer, "UICheckButtonTemplate")
  previewFavBtn:SetSize(20, 20)
  previewFavBtn:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2, -1)
  previewFavBtn:SetScript("OnClick", function(self)
    if not previewedData then self:SetChecked(false); return end
    setFavorite(previewedData, self:GetChecked() and true or false)
    refreshCollection()
  end)
  previewFavBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Favorite", 1, 0.82, 0)
    GameTooltip:AddLine("Keeps this at the front of the collection.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  previewFavBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  previewFavBtn:Hide()

  previewHint = layer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
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
    if previewFavBtn then previewFavBtn:Hide() end
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
  if previewFavBtn then
    previewFavBtn:Show()
    previewFavBtn:SetChecked(isFavorite(data))
  end
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
    GameTooltip:AddLine("Right-click to dismiss", 1, 0.82, 0)
  else
    GameTooltip:AddLine("Right-click to summon", 1, 0.82, 0)
  end
  GameTooltip:AddLine("Left-click to preview", 0.82, 0.85, 0.9)
  GameTooltip:Show()
end

-- A single, clean backdrop ring (rather than a stretched icon-border texture, which distorts once
-- pushed this far out) so both the "summoned" and "previewing" indicators stay crisp at this size.
-- Adds a faint tinted glow behind the icon too, echoing retail's gold-highlighted collection rows
-- (we're a grid of icons rather than text rows, so a full row-fill doesn't apply, but the warm gold
-- glow + bright edge reads the same way).
local function makeRing(parent, edgeR, edgeG, edgeB, bgR, bgG, bgB, bgAlpha)
  local ring = CreateFrame("Frame", nil, parent)
  ring:SetPoint("TOPLEFT", parent, "TOPLEFT", -BORDER_SIZE, BORDER_SIZE)
  ring:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", BORDER_SIZE, -BORDER_SIZE)
  ring:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = BORDER_THICK,
  })
  ring:SetBackdropColor(bgR or 0, bgG or 0, bgB or 0, bgAlpha or 0)
  ring:SetBackdropBorderColor(edgeR, edgeG, edgeB, 1)
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

  -- Gold: this one is currently summoned (retail's collection "selected" gold). Silver: this one is
  -- what's in the 3D preview. Both can show at once (offset slightly) since they mean different things.
  b._activeRing = makeRing(b, 1.0, 0.82, 0.0, 0.55, 0.42, 0.05, 0.35)
  b._previewRing = makeRing(b, 0.82, 0.85, 0.9, 0.3, 0.32, 0.36, 0.3)
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
      if previewLayer then previewLayer:Show() end
      showPreview(previewedData) -- re-show whatever was last previewed, or the hint if nothing was
    end
  else
    if previewLayer then previewLayer:Hide() end
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

-- Whether this character has an actual controllable combat pet UI at all (Blizzard's own
-- PetTab_Update rule: Hunter/Warlock/DK/Mage-with-elemental, or anyone with a temporary pet unit
-- active). Mirrors petTabShown()'s pet-half in TabButtons.lua.
local function canHavePet()
  local ok, v = pcall(function() return HasPetUI and HasPetUI() end)
  return ok and v and true or false
end

-- Hides the "My Pet" toggle (and the class-pet view behind it) for classes that never have a combat
-- pet - Shaman, Priest, Rogue, etc. There's nothing useful to show there, so Collection becomes the
-- only/default view instead of an empty "You do not have a pet." pane the player can't do anything
-- about. Re-checked on the same events TabButtons.lua watches, since a pet-capable state can appear
-- mid-session (e.g. a temporary pet-granting trinket/spell on an otherwise petless class).
local function refreshPetSectionAvailability()
  local has = canHavePet()
  if petModeBtn then
    if has then petModeBtn:Show() else petModeBtn:Hide() end
  end
  if not has and not collectionActive then
    showCollection(true)
  end
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

  refreshPetSectionAvailability()
end

local function build()
  local host = getPane()
  if not host then return false end
  buildCollectionFrame(host)
  buildToggle(host)

  -- Safety net independent of TabButtons.lua's own tab-switch bookkeeping: previewLayer lives on
  -- CP.InsetRight, which is a SHARED region (Character tab uses it too, for its own stats sidebar),
  -- not something scoped to the Pet tab. Tying the hide directly to this pane's own OnHide - which
  -- fires no matter which other tab got selected - means we don't have to individually teach every
  -- other tab's branch in TabButtons.lua about us to avoid leaking the preview into their space.
  if not host._neCompanionsHideHooked then
    host._neCompanionsHideHooked = true
    host:HookScript("OnHide", function()
      if previewLayer then previewLayer:Hide() end
    end)
  end

  -- Second gap, opposite direction: TabButtons.lua's selectTab() (which is what actually re-syncs
  -- previewLayer's visibility - see CP.SyncPetSidebarForCollection) only runs when you click between
  -- tabs. It does NOT re-run just because the whole character panel is closed and reopened via
  -- keybind - that only calls Show()/Hide() on the outer frame, which doesn't fire OnShow/OnHide on
  -- child panes whose own Show()/Hide() wasn't directly called. So if you left on Pet+Collection,
  -- closed the panel, and reopened it fresh, previewLayer's last-known state could be stale (hidden)
  -- even though the Pet tab is what's actually showing. Re-assert it on every panel open.
  if CP.frame and not CP.frame._neCompanionsPanelShowHooked then
    CP.frame._neCompanionsPanelShowHooked = true
    CP.frame:HookScript("OnShow", function()
      if CP._activeTab == "Pet" and collectionActive then
        applySidebarMode(true)
      end
    end)
  end

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
boot:RegisterEvent("UNIT_PET")
boot:RegisterEvent("PET_UI_UPDATE")
boot:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    if C_Timer and C_Timer.After then C_Timer.After(0, build) else build() end
  elseif event == "UNIT_PET" or event == "PET_UI_UPDATE" then
    refreshPetSectionAvailability()
  else
    refreshCollection()
  end
end)