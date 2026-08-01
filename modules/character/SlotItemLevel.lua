-- DragonUI_NewEra/modules/character/SlotItemLevel.lua — the item level number drawn on each equipped
-- PaperDoll slot, toggled from the character panel's settings cog (SettingsCog.lua).
--
-- Structured after SlotQuality.lua, which does the same job for the quality border: the same 19 slot
-- buttons, the same PLAYER_EQUIPMENT_CHANGED per-slot / login full-pass event shape.
--
-- 3.3.5a NOTES (§B):
--   * Item level is GetItemInfo(link)'s 4th return. There is no cache-independent getter for it the
--     way GetInventoryItemQuality is for quality, so a cold cache means no number for that slot.
--   * GET_ITEM_INFO_RECEIVED DOES NOT FIRE on this client (see modules/encounterjournal/EncounterPage
--     .lua:21) — there is no event to wait on. Equipped items are almost always already cached, but a
--     cold login can miss, so a BOUNDED retry ticker re-runs the pass a few times and then gives up
--     rather than polling forever.
--   * The label sits BOTTOMLEFT: PaperDollItemSlotButtonTemplate's own $parentCount FontString owns
--     BOTTOMRIGHT, and the slot's metal frame art (SlotFrames.lua) sits outside the button.

local NE = DragonUI_NewEra
NE.charpanel = NE.charpanel or {}
local CP = NE.charpanel

local MODULE = "character"

local function log(msg) if CP._log then CP._log(msg) elseif NE.Log then NE.Log("CHARPANEL", msg) end end

-- The 19 character equipment slots (Ammo excluded — different button type), matching SlotQuality.lua.
local SLOTS = {
  "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot",
  "CharacterBackSlot", "CharacterChestSlot", "CharacterShirtSlot",
  "CharacterTabardSlot", "CharacterWristSlot",
  "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
  "CharacterFinger0Slot", "CharacterFinger1Slot",
  "CharacterTrinket0Slot", "CharacterTrinket1Slot",
  "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot",
}

-- ----------------------------------------------------------------------------
-- Setting. ACCOUNT-wide, not per character: it's a display preference about how the panel looks,
-- not state about a particular character (contrast Sidebar.lua's per-character collapse/order).
-- Default ON — the number is the point of the feature; the cog is there to turn it back off.
-- ----------------------------------------------------------------------------
local DEFAULT_SHOWN = true

local function settings()
  if not NE.db then return nil end
  NE.db.charPanel = NE.db.charPanel or {}
  return NE.db.charPanel
end

function CP.IsSlotItemLevelShown()
  local s = settings()
  if not s or s.showSlotItemLevel == nil then return DEFAULT_SHOWN end
  return s.showSlotItemLevel and true or false
end

function CP.SetSlotItemLevelShown(on)
  local s = settings()
  if s then s.showSlotItemLevel = on and true or false end
  if CP.UpdateAllSlotItemLevels then CP.UpdateAllSlotItemLevels() end
end

-- ----------------------------------------------------------------------------
-- The label. Created once per slot button, kept even while the setting is off (just hidden) so
-- toggling costs nothing.
-- ----------------------------------------------------------------------------
local function ensureLabel(slot)
  if slot._neIlvlText then return slot._neIlvlText end
  local fs = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  -- Above the icon AND the IconBorder quality ring, both of which draw on OVERLAY.
  if fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY", 7) end
  fs:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 2, 2)
  fs:SetJustifyH("LEFT")
  if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1); fs:SetShadowOffset(1, -1) end
  slot._neIlvlText = fs
  return fs
end

-- Paint one slot. Returns true if the item is equipped but its level is not cached yet, so the
-- caller knows a retry is worth scheduling.
local function updateSlot(slot)
  if not (slot and slot.GetID and slot.CreateFontString) then return false end
  local fs = ensureLabel(slot)

  if not CP.IsSlotItemLevelShown() then fs:Hide(); return false end

  local id = slot:GetID()
  if not id or id == 0 then fs:Hide(); return false end

  local link = GetInventoryItemLink("player", id)
  if not link then fs:Hide(); return false end

  local ok, _, _, quality, ilvl = pcall(GetItemInfo, link)
  if not ok or not ilvl or ilvl <= 0 then
    fs:Hide()
    return true   -- equipped but uncached — retry
  end

  fs:SetText(tostring(ilvl))
  local qc = quality and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
  if qc then fs:SetTextColor(qc.r, qc.g, qc.b) else fs:SetTextColor(1, 1, 1) end
  fs:Show()
  return false
end

local function updateAll()
  local cold = false
  for _, name in ipairs(SLOTS) do
    if updateSlot(_G[name]) then cold = true end
  end
  return cold
end

CP.UpdateAllSlotItemLevels = updateAll

-- ----------------------------------------------------------------------------
-- Bounded retry for a cold item cache. No GET_ITEM_INFO_RECEIVED on 3.3.5a, so this is the only way
-- an uncached equipped item ever gets its number — but it MUST terminate, or a genuinely unresolvable
-- link (a server-side custom item the client has no data for) would poll for the whole session.
-- ----------------------------------------------------------------------------
local RETRY_INTERVAL, RETRY_LIMIT = 0.5, 10
local retry = CreateFrame("Frame")
retry:Hide()
retry:SetScript("OnUpdate", function(self, elapsed)
  self._t = (self._t or 0) + (elapsed or 0)
  if self._t < RETRY_INTERVAL then return end
  self._t = 0
  self._n = (self._n or 0) + 1
  if not updateAll() or self._n >= RETRY_LIMIT then self:Hide() end
end)

local function updateAllWithRetry()
  if updateAll() then
    retry._t, retry._n = 0, 0
    retry:Show()
  else
    retry:Hide()
  end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
boot:SetScript("OnEvent", function(_, event, slotID)
  if NE.modules and NE.modules.IsEnabled and not NE.modules.IsEnabled(MODULE) then return end
  if event == "PLAYER_EQUIPMENT_CHANGED" and slotID then
    for _, name in ipairs(SLOTS) do
      local slot = _G[name]
      if slot and slot.GetID and slot:GetID() == slotID then
        if updateSlot(slot) then retry._t, retry._n = 0, 0; retry:Show() end
        return
      end
    end
    return
  end
  local ok, err = pcall(updateAllWithRetry)
  if not ok then log("SlotItemLevel update failed: " .. tostring(err)) end
end)
