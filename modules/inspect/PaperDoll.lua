-- DragonUI_NewEra/modules/inspect/PaperDoll.lua — the inspect window's Character tab, re-laid-out
-- into the window's interior rect (InspectFrame.lua owns the window size).
--
-- DOWNPORT of the content half of NewEra/InspectFrame/InspectFrame.lua. The 1.15 source leaned on
-- NE.charpanel (its own character-panel port) for the race backdrop, the model control bar and the
-- slot art. This addon has no NE.charpanel — DragonUI ships the character panel here — so the
-- reference for every number below is DragonUI's own character panel (modules/characterpanel/
-- slots.lua, model.lua, modelcontrols.lua). Matching it is the point: the inspect window and the
-- character window are the same window with someone else's gear in it, and on this client they are
-- built from the same Blizzard templates, so they should land pixel-for-pixel together.
--
-- What moves (Blizzard's numbers were measured for the 384x512 wooden window):
--   * left column head  -> Inset TOPLEFT(4,-2)      the other seven chain off it in XML
--   * right column head -> Inset TOPRIGHT(-4,-2)
--   * weapon row        -> Inset BOTTOM, centred by arithmetic (3 slots = 37+5+37+5+37 = 121)
--   * model             -> 231 wide, centred, 6 below the interior's top, as tall as it allows, with
--                          the race backdrop behind it scaled to match and the inner trim around it
--   * item level        -> DragonUI's floating average, lifted off the weapon row it lands on
--   * level line        -> centred under the title band, class-coloured, with the guild under it
--
-- 3.3.5a NOTES
--   * There is no INSPECT_READY on this client — INSPECT_TALENT_READY is the only "inspect data
--     arrived" signal (the same one DragonUI's item-level module rides).
--   * The rotate buttons are InspectModelRotateLeftButton / ...RightButton — NOT the
--     InspectModelFrameRotate* names the 1.15 source used. Blizzard's InspectModelFrame_OnUpdate
--     polls them BY GLOBAL NAME for hold-to-rotate, so they are restyled and moved, never replaced.

local NE = DragonUI_NewEra
if not NE or NE.disabled then return end

NE.inspect = NE.inspect or {}
local I = NE.inspect
local L = NE.L

-- Model. The WIDTH is DragonUI's character-panel width; the HEIGHT is derived so the viewport
-- always reaches from 6px under the interior's top to 34px above its bottom — which is where the
-- weapon row's top edge lands (20 up + 37 tall = 57, less the 23px of overlap the row is meant to
-- have with the model's feet). Feed it the character panel's own 360-tall interior and it returns
-- exactly 320, DragonUI's number; feed it the taller interior this window now has and the model
-- grows into it rather than leaving a band of nothing under the character.
local MODEL_W = 231
local MODEL_BOTTOM_GAP, MODEL_TOP_GAP = 34, 6

local function modelHeight(interiorH)
  return interiorH - MODEL_TOP_GAP - MODEL_BOTTOM_GAP
end

local LEFT_COLUMN = {
  "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectBackSlot",
  "InspectChestSlot", "InspectShirtSlot", "InspectTabardSlot", "InspectWristSlot",
}
local RIGHT_COLUMN = {
  "InspectHandsSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
  "InspectFinger0Slot", "InspectFinger1Slot", "InspectTrinket0Slot", "InspectTrinket1Slot",
}
local WEAPON_ROW = { "InspectMainHandSlot", "InspectSecondaryHandSlot", "InspectRangedSlot" }
-- Three 37px slots with Blizzard's own 5px gaps: 37+5+37+5+37.
local WEAPON_ROW_W = 3 * 37 + 2 * 5

I.LEFT_COLUMN, I.RIGHT_COLUMN, I.WEAPON_ROW = LEFT_COLUMN, RIGHT_COLUMN, WEAPON_ROW

-- ----------------------------------------------------------------------------
-- Slot frames. 3.3.5a's slot buttons inherit bare ItemButtonTemplate — the metal frame simply does
-- not exist on this client — so it is drawn as a texture behind each button, from the same sheet
-- and the same slices DragonUI's character panel uses (Char-Paperdoll-Parts). The sheet lives in
-- DragonUI, which is a hard dependency; if that path ever moves, the slots keep Blizzard's own
-- border and nothing else changes.
-- ----------------------------------------------------------------------------
local LEFT_SLICE   = { w = 49, h = 44, 0.20703125, 0.39843750, 0.59375, 0.93750 }
local RIGHT_SLICE  = { w = 50, h = 44, 0.00390625, 0.19921875, 0.59375, 0.93750 }
local BOTTOM_SLICE = { w = 42, h = 53, 0.67187500, 0.83593750, 0.00781, 0.42188 }
local GAP_LEFT     = { w = 6,  h = 54, 0.70703125, 0.73046875, 0.43750, 0.85938 }
local GAP_RIGHT    = { w = 7,  h = 54, 0.67187500, 0.69921875, 0.43750, 0.85938 }

local function partsSheet()
  local dir = NE.dragon and NE.dragon._dir
  return dir and (dir .. "CharacterPanel\\charpaperdollparts") or nil
end

local function decorate(slotName, slice, point, x, y)
  local slot = _G[slotName]
  if not slot or slot._neSlotFrame then return end
  local sheet = partsSheet()
  if not sheet then return end

  local tex = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
  tex:SetTexture(sheet)
  tex:SetTexCoord(slice[1], slice[2], slice[3], slice[4])
  tex:SetWidth(slice.w)
  tex:SetHeight(slice.h)
  tex:SetPoint(point, slot, point, x, y)
  slot._neSlotFrame = tex
end

local function gapFiller(slotName, slice, point, relPoint)
  local slot = _G[slotName]
  if not (slot and slot._neSlotFrame) or slot._neSlotGap then return end
  local sheet = partsSheet()
  if not sheet then return end

  local tex = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
  tex:SetTexture(sheet)
  tex:SetTexCoord(slice[1], slice[2], slice[3], slice[4])
  tex:SetWidth(slice.w)
  tex:SetHeight(slice.h)
  tex:SetPoint(point, slot._neSlotFrame, relPoint, 0, 0)
  slot._neSlotGap = tex
end

local function decorateSlots()
  for _, name in ipairs(LEFT_COLUMN)  do decorate(name, LEFT_SLICE,   "TOPLEFT",  -4, 0) end
  for _, name in ipairs(RIGHT_COLUMN) do decorate(name, RIGHT_SLICE,  "TOPRIGHT",  4, 0) end
  for _, name in ipairs(WEAPON_ROW)   do decorate(name, BOTTOM_SLICE, "TOPLEFT",  -4, 8) end
  gapFiller("InspectMainHandSlot", GAP_LEFT,  "TOPRIGHT", "TOPLEFT")
  gapFiller("InspectRangedSlot",   GAP_RIGHT, "TOPLEFT",  "TOPRIGHT")
end

-- Only the three column heads move; the rest of each column chains off them in Blizzard's XML.
local function anchorSlots(inset)
  local head = _G.InspectHeadSlot
  if head and not head._neAnchored then
    head._neAnchored = true
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -2)
  end

  local hands = _G.InspectHandsSlot
  if hands and not hands._neAnchored then
    hands._neAnchored = true
    hands:ClearAllPoints()
    hands:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -4, -2)
  end

  -- The weapon row sits BETWEEN the columns, over the model's feet, the way retail's does — which
  -- is what lets a 424-tall window hold two eight-slot columns at all. Centred by arithmetic rather
  -- than by DragonUI's hard 83/103: those are measured against ITS interior width, and this one is
  -- free to differ (see I.INSET).
  local mh = _G.InspectMainHandSlot
  if mh and not mh._neAnchored then
    mh._neAnchored = true
    local interiorW = I.InteriorSize()
    mh:ClearAllPoints()
    mh:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", math.floor((interiorW - WEAPON_ROW_W) / 2), 20)
  end
end

-- Model and slot buttons are siblings at the same frame level, so draw order falls to creation
-- order — and a zoomed-in model paints straight over the weapon row beneath it.
--
-- The model's own level is re-asserted first rather than assumed: InspectFrame.lua raises the whole
-- paperdoll subframe above our interior ground, and whether a 3.3.5a child follows its parent's
-- SetFrameLevel is not something worth betting the model's visibility on. Re-asserting costs a call
-- and settles it — and it must happen BEFORE the control strip is built, so the strip is created
-- against the level the model ends up with.
local function raiseSlots()
  local model = _G.InspectModelFrame
  if not model then return end
  local parent = model:GetParent()
  if parent and parent.GetFrameLevel then
    model:SetFrameLevel(parent:GetFrameLevel() + 1)
  end
  local level = model:GetFrameLevel() + 2
  for _, group in ipairs({ LEFT_COLUMN, RIGHT_COLUMN, WEAPON_ROW }) do
    for _, name in ipairs(group) do
      local slot = _G[name]
      if slot then slot:SetFrameLevel(level) end
    end
  end
end

-- ----------------------------------------------------------------------------
-- Model + race backdrop.
-- ----------------------------------------------------------------------------
-- Blizzard's own DressUpTexturePath applies this same fallback: the 3.3.5a client ships no Gnome
-- or Troll backdrop art.
local RACE_FALLBACK = { GNOME = "Dwarf", TROLL = "Orc" }

-- Retail's own per-race dimming: the backdrops differ in brightness, so one flat value washes out
-- the pale ones. Keyed off the RESOLVED race, so a Gnome drawn on Dwarf art gets Dwarf's value.
local RACE_OVERLAY_ALPHA = {
  BLOODELF = 0.8, NIGHTELF = 0.6, SCOURGE = 0.3, TROLL = 0.6, ORC = 0.6,
}
local OVERLAY_ALPHA_DEFAULT = 0.7

local function raceFile(unit)
  local _, fileName = UnitRace(unit)
  if not fileName then return "Orc", "ORC" end
  local upper = strupper(fileName)
  local resolved = RACE_FALLBACK[upper] or fileName
  return resolved, strupper(resolved)
end

-- The four stitched quarters of a DressUpBackground set. Widths are absolute (212 + 19 = 231, the
-- model's width); HEIGHTS are fractions of the model's height, because that height is now derived
-- from the interior rather than fixed at 320 — at DragonUI's 320 they come back to its own 245/75.
-- Cropped to the viewport: 245 + 75 = 320 of a 128-tall bottom tile, hence BOTTOM_CROP.
local BOTTOM_CROP = 75 / 128
local QUARTERS = {
  { suffix = 1, w = 212, hf = 245 / 320, tc = { 0.171875, 1, 0.0392156862745098, 1 },
    point = "TOPLEFT", rel = "TOPLEFT" },
  { suffix = 2, w = 19,  hf = 245 / 320, tc = { 0, 0.296875, 0.0392156862745098, 1 },
    point = "TOPLEFT", rel = "TOPRIGHT" },
  { suffix = 3, w = 212, hf = 75 / 320,  tc = { 0.171875, 1, 0, BOTTOM_CROP },
    point = "TOPLEFT", rel = "BOTTOMLEFT" },
  { suffix = 4, w = 19,  hf = 75 / 320,  tc = { 0, 0.296875, 0, BOTTOM_CROP },
    point = "TOPLEFT", rel = "BOTTOMRIGHT" },
}

-- Follows DragonUI's own "grey model backdrop" setting so both windows are dimmed the same way.
-- Defaults to on (retail desaturates and dims, and so did the 1.15 source) when the base addon
-- doesn't answer.
local function greyBackdrop()
  local dragon = NE.dragon
  if dragon and type(dragon.GetModuleConfig) == "function" then
    local ok, cfg = pcall(dragon.GetModuleConfig, dragon, "characterpanel")
    if ok and type(cfg) == "table" and cfg.grey_model_backdrop ~= nil then
      return cfg.grey_model_backdrop and true or false
    end
  end
  return true
end

local function buildBackdrop(model)
  if model._neRaceBg then return end
  model._neRaceBg = {}

  local mh = model:GetHeight() or 320
  local topLeft
  for _, q in ipairs(QUARTERS) do
    local tex = model:CreateTexture(nil, "BACKGROUND")
    tex:SetWidth(q.w)
    tex:SetHeight(q.hf * mh)
    tex:SetTexCoord(q.tc[1], q.tc[2], q.tc[3], q.tc[4])
    if q.suffix == 1 then
      tex:SetPoint(q.point, model, q.rel, 0, 0)
      topLeft = tex
    else
      tex:SetPoint(q.point, topLeft, q.rel, 0, 0)
    end
    model._neRaceBg[q.suffix] = tex
  end

  -- Bounded by the MODEL, not the backdrop grid: BORDER is retail's layer for it.
  local overlay = model:CreateTexture(nil, "BORDER")
  overlay:SetTexture(0, 0, 0)
  overlay:SetPoint("TOPLEFT", model._neRaceBg[1], "TOPLEFT", 0, 0)
  overlay:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 0, 0)
  model._neRaceBgOverlay = overlay
end

local function applyBackdrop()
  local model = _G.InspectModelFrame
  local f = _G.InspectFrame
  if not (model and model._neRaceBg and f) then return end

  local unit = f.unit
  local file, key = raceFile(unit)
  local base = "Interface\\DressUpFrame\\DressUpBackground-" .. file
  local grey = greyBackdrop()

  for suffix, tex in pairs(model._neRaceBg) do
    tex:SetTexture(base .. suffix)
    tex:SetDesaturated(grey)
    tex:Show()
  end
  if model._neRaceBgOverlay then
    model._neRaceBgOverlay:SetAlpha(grey and (RACE_OVERLAY_ALPHA[key] or OVERLAY_ALPHA_DEFAULT) or 0)
    model._neRaceBgOverlay:Show()
  end
end
I.ApplyBackdrop = applyBackdrop

local function resizeModel(inset)
  local model = _G.InspectModelFrame
  if not model or model._neResized then return end
  model._neResized = true
  model:SetWidth(MODEL_W)
  -- COMPUTED interior height, not inset:GetHeight() — see I.InteriorSize's header.
  local _, interiorH = I.InteriorSize()
  model:SetHeight(modelHeight(interiorH))
  model:ClearAllPoints()
  -- Centred in the interior, same reasoning as the weapon row. (At DragonUI's 328-wide interior
  -- this comes out at 48, its own number.)
  local interiorW = I.InteriorSize()
  model:SetPoint("TOPLEFT", inset, "TOPLEFT", math.floor((interiorW - MODEL_W) / 2), -MODEL_TOP_GAP)
end

-- ----------------------------------------------------------------------------
-- Model controls — rotate / zoom / reset, revealed on hover, in the character panel's own style.
--
-- The gestures (drag to turn, wheel to zoom, right-drag to pan, middle-click to reset) come from
-- DragonUI's shared model-view kit, so an inspected character handles exactly like your own. All
-- of it is optional: with an older base addon that exposes no kit, the two native rotate buttons
-- are simply left where Blizzard put them.
-- ----------------------------------------------------------------------------
local BTN_SIZE, BTN_OVERLAP = 29, 5

local function buildControls(model)
  local dragon = NE.dragon
  local CP = dragon and dragon.CharacterPanel
  local left, right = _G.InspectModelRotateLeftButton, _G.InspectModelRotateRightButton
  if not (model and left and right) or model._neControls then return end
  -- All-or-nothing: without the base addon's model-view kit AND its button skin there is no strip
  -- to build, and Blizzard's two wooden rotate buttons are left exactly where they are.
  if not (dragon and type(dragon.ZoomModelView) == "function"
          and type(dragon.WireModelView) == "function"
          and CP and type(CP.StyleModelButton) == "function") then
    return
  end
  model._neControls = true

  -- Drag to turn, wheel to zoom, right-drag to pan, middle-click to reset — on the model itself.
  -- `hook` keeps Blizzard's own scripts (its OnUpdate is what carries a held rotate button).
  pcall(dragon.WireModelView, dragon, model,
        { hook = true, pivot = dragon.ModelPivot and dragon.ModelPivot.player })

  local bar = CreateFrame("Frame", "NE_InspectModelControls", model)
  bar:SetHeight(BTN_SIZE)
  bar:SetPoint("TOP", model, "TOP", 0, -1)
  bar:SetAlpha(0)
  bar:EnableMouse(true)
  bar:Hide()

  local function makeButton(name, glyph, onClick)
    local btn = CreateFrame("Button", name, bar)
    pcall(CP.StyleModelButton, btn, glyph)
    btn:SetScript("OnClick", onClick)
    return btn
  end

  -- The two natives keep their own parent and their global names: Blizzard's OnUpdate finds them
  -- that way, and that is what makes press-and-hold spin the model. Only their art and their spot
  -- in the row change.
  pcall(CP.StyleModelButton, left,  "common-icon-rotateright")
  pcall(CP.StyleModelButton, right, "common-icon-rotateleft")

  local strip = {
    left, right,
    makeButton("NE_InspectModelZoomOut", "common-icon-zoomout",
               function() dragon:ZoomModelView(model, -1) end),
    makeButton("NE_InspectModelZoomIn", "common-icon-zoomin",
               function() dragon:ZoomModelView(model, 1) end),
    makeButton("NE_InspectModelReset", "common-icon-undo", function()
      if dragon.ResetModelView then dragon:ResetModelView(model) end
      if dragon.ResetModelRotation then dragon:ResetModelRotation(model) end
    end),
  }

  local step = BTN_SIZE - BTN_OVERLAP
  bar:SetWidth(step * (#strip - 1) + BTN_SIZE)
  for i, btn in ipairs(strip) do
    btn:ClearAllPoints()
    btn:SetPoint("LEFT", bar, "LEFT", (i - 1) * step, 0)
  end
  -- The two natives are the model's own children, not the bar's, so hiding the bar does not hide
  -- them — and an invisible button still swallows clicks. They go down and come back with the strip.
  left:SetFrameLevel(bar:GetFrameLevel() + 1)
  right:SetFrameLevel(bar:GetFrameLevel() + 1)
  left:Hide()
  right:Hide()

  local function releaseButtons()
    for _, btn in ipairs(strip) do
      if btn.GetButtonState and btn:GetButtonState() == "PUSHED" then btn:SetButtonState("NORMAL") end
    end
  end

  -- Revealed over the model, the strip OR any button: the buttons take the mouse focus, so without
  -- them on the same pair of handlers the cursor can leave through one and strand the strip lit.
  local function show()
    -- Not while a button is held: moving off one onto the model re-fires this and stops the spin.
    if not IsMouseButtonDown("LeftButton") then releaseButtons() end
    bar:Show()
    bar:SetAlpha(1)
    left:Show()
    right:Show()
  end
  local function hide()
    if bar:IsMouseOver() or model:IsMouseOver() then return end
    bar:Hide()
    bar:SetAlpha(0)
    left:Hide()
    right:Hide()
    releaseButtons()
  end

  model:HookScript("OnEnter", show)
  model:HookScript("OnLeave", hide)
  bar:HookScript("OnEnter", show)
  bar:HookScript("OnLeave", hide)
  for _, btn in ipairs(strip) do
    btn:HookScript("OnEnter", show)
    btn:HookScript("OnLeave", hide)
    -- Anything drawn over a model swallows its input; hand the gestures back. The rotate buttons
    -- keep their own left-click, so that one gesture is the exception.
    if type(dragon.ForwardModelInput) == "function" then
      pcall(dragon.ForwardModelInput, dragon, btn, model, true)
    end
  end
  if type(dragon.ForwardModelInput) == "function" then
    pcall(dragon.ForwardModelInput, dragon, bar, model)
  end

  -- Closing the window mid-hover would otherwise reopen it with the strip lit and a button latched.
  model:HookScript("OnHide", function()
    releaseButtons()
    bar:Hide()
    bar:SetAlpha(0)
    left:Hide()
    right:Hide()
  end)
end

-- ----------------------------------------------------------------------------
-- Header lines: "Level N Race Class" (class-coloured) and the guild under it.
-- ----------------------------------------------------------------------------
local function levelLine(unit)
  local level = UnitLevel(unit)
  if not level or level == -1 or level == 0 then level = "??" end
  local race = UnitRace(unit) or ""
  local classDisplay, classFile = UnitClass(unit)
  local coloured = NE.color.WrapClass(classFile, classDisplay or "")

  -- PLAYER_LEVEL is the localized "Level %s %s %s" — this client's enUS build already uses %s in
  -- the level slot, precisely because Blizzard's own InspectPaperDollFrame_SetLevel feeds it the
  -- STRING "??" for an out-of-range unit. Later clients (and some locale builds) write %d there,
  -- and string.format("%d", "??") is an ERROR in Lua 5.1, not a warning — so relax the slot rather
  -- than trust it, and keep the whole call inside a pcall in case a template carries more slots.
  local template = string.gsub(_G.PLAYER_LEVEL or "Level %d %s %s", "%%d", "%%s")
  local ok, line = pcall(string.format, template, tostring(level), race, coloured)
  if ok then return line end
  return "Level " .. tostring(level) .. " " .. race .. " " .. coloured
end

local function applyHeaderLines()
  local f = _G.InspectFrame
  local fs = _G.InspectLevelText
  if not (f and fs and f.unit) then return end

  fs:SetText(levelLine(f.unit))

  -- Blizzard ships InspectGuildText hidden and never fills it in, even though GetGuildInfo answers
  -- for an inspected unit on this client. Retail's inspect shows the guild, so fill it in — the
  -- same line DragonUI's character panel drives for the player (Wrath commented out its own
  -- SetGuild call, so nothing else ever writes either of them).
  local gfs = _G.InspectGuildText
  local guildName = GetGuildInfo(f.unit)
  local hasGuild = gfs and guildName and guildName ~= ""
  if gfs then
    if hasGuild then
      gfs:SetText("<" .. guildName .. ">")
      gfs:ClearAllPoints()
      gfs:SetPoint("TOP", fs, "BOTTOM", 0, -1)   -- Blizzard's own gap for this line
      gfs:Show()
    else
      gfs:Hide()
    end
  end

  -- Blizzard hangs the level line off InspectNameText's BOTTOM, which we moved into the title band.
  -- Retail lifts the line from -42 to -36 whenever a second line sits under it, so the pair centres
  -- as a block — the same arithmetic, and the same two offsets, as the character panel's.
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", _G.InspectPaperDollFrame or f, "TOP", 0, hasGuild and -36 or -42)
end
I.ApplyHeaderLines = applyHeaderLines

-- ----------------------------------------------------------------------------
-- DragonUI's average item level, moved off the weapon row.
--
-- Its item-level module floats that number at the model's BOTTOM (modules/itemlevel.lua, a holder
-- frame anchored BOTTOMLEFT/BOTTOMRIGHT to the model) — which lands square on the weapon slots
-- here, because our row deliberately overlays the model's feet. On the character panel it never
-- collides: the sidebar shows item level as a stat row and the floating copy is suppressed
-- (addon.SetCharacterAverageSuppressed). Inspect has no sidebar and no such switch, so the text
-- moves instead: same holder, same module, re-anchored to clear the row.
--
-- The FontString is private to that module, so it is found by SHAPE rather than by name: a child
-- frame of the paperdoll, anchored to the model, holding exactly one region, and that region a
-- FontString. Nothing else in this window matches, and if the module is off or never drew, the
-- search simply finds nothing and is retried on the next refresh.
-- ----------------------------------------------------------------------------
local ILVL_ABOVE_ROW = 27   -- weapon row top is 23 above the model's bottom; +4 of air
local ILVL_TRIES     = 8    -- ~2s of looking, then give up until the next refresh

local pinItemLevelText
function pinItemLevelText()
  local pd, model = _G.InspectPaperDollFrame, _G.InspectModelFrame
  if not (pd and model) or pd._neIlvlPinned or not pd.GetChildren then return end

  -- It is not there yet on the refresh that matters. DragonUI computes the average off
  -- INSPECT_TALENT_READY and its own 0.1s/0.6s debounces, and only BUILDS the FontString once it
  -- has a number — which lands after the refresh this is called from, so a single look finds
  -- nothing and the text appears, unpinned, over the weapon row. Look again for a couple of
  -- seconds; the flag stops it the moment it lands.
  if C_Timer and C_Timer.After and (pd._neIlvlTries or 0) < ILVL_TRIES then
    pd._neIlvlTries = (pd._neIlvlTries or 0) + 1
    C_Timer.After(0.25, pinItemLevelText)
  end

  for _, child in ipairs({ pd:GetChildren() }) do
    if child ~= model and child.GetNumRegions and child:GetNumRegions() == 1
       and child.GetPoint and child:GetNumPoints() and child:GetNumPoints() > 0 then
      local _, rel = child:GetPoint(1)
      if rel == model then
        local fs = child:GetRegions()
        if fs and fs.GetObjectType and fs:GetObjectType() == "FontString" then
          fs:ClearAllPoints()
          fs:SetPoint("BOTTOM", model, "BOTTOM", 0, ILVL_ABOVE_ROW)
          pd._neIlvlPinned = true
          return
        end
      end
    end
  end
end
I.PinItemLevelText = pinItemLevelText

-- ----------------------------------------------------------------------------
-- The Talents TAB.
--
-- Blizzard's inspect window has one and it works, so it stays in the strip beside Character and PvP
-- where a third tab belongs. What changes is where it leads: instead of the native tree pane, it
-- opens THIS addon's talent window on the inspected unit (NE.talents.ShowInspect).
--
-- It deliberately does not become the SELECTED tab — `InspectSwitchTabs` is never called — so the
-- inspect window keeps showing the pane you were on while the talent window opens over it. Hosting
-- the tree in the tab instead is not an option worth taking: three 4x11 trees need ~900px of width.
-- Blizzard's pane fits them in 296px by showing ONE at a time behind a scrollbar; the modern
-- renderer shows all three and is sized for its own window, so a 328-wide tab would shrink it to
-- about a third — smaller than the pane it replaced.
--
-- Level gate: Blizzard's own. `InspectFrame_UpdateTalentTab` disables tab 3 for a level 1-9 unit on
-- every unit change, and a disabled tab fires no OnClick — so there is nothing to re-implement.
--
-- With the talent module unavailable the tab is left completely alone, and the native pane (fitted
-- by InspectFrame.lua) is what it shows.
-- ----------------------------------------------------------------------------
local function talentsSupported()
  return (NE.talents and type(NE.talents.ShowInspect) == "function") and true or false
end

local function applyTalentsTab()
  local f, tab = _G.InspectFrame, _G.InspectFrameTab3
  if not (f and tab) or tab._neTalentsWired or not talentsSupported() then return end
  tab._neTalentsWired = true

  tab:SetScript("OnClick", function()
    if PlaySound then pcall(PlaySound, "igCharacterInfoTab") end
    if f.unit and NE.talents and NE.talents.ShowInspect then NE.talents.ShowInspect(f.unit) end
  end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TALENTS or L["Talents"], 1, 1, 1)
    GameTooltip:AddLine(L["View this player's talents."], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", GameTooltip_Hide)
end

-- ----------------------------------------------------------------------------
-- Refresh: everything that follows the INSPECTED UNIT rather than the layout.
-- ----------------------------------------------------------------------------
local function refresh()
  if not (_G.InspectFrame and _G.InspectFrame.unit) then return end
  applyBackdrop()
  applyHeaderLines()
  pinItemLevelText()   -- built lazily by DragonUI on the first inspect that has data
  if I.ApplyPortrait then I.ApplyPortrait() end
end
I.Refresh = refresh

-- ----------------------------------------------------------------------------
-- Entry point, called once from InspectFrame.lua's I.Apply.
-- ----------------------------------------------------------------------------
function I.ApplyPaperDoll()
  local f = _G.InspectFrame
  local inset = f and I.EnsureInset(f)
  if not inset then return end

  decorateSlots()
  anchorSlots(inset)
  resizeModel(inset)
  raiseSlots()

  local model = _G.InspectModelFrame
  if model then
    buildBackdrop(model)
    -- The trim around the viewport, drawn with the same routine and the same 2px outset the
    -- character panel rims ITS model with (DragonUI modules/characterpanel/innerborder.lua). Hosted
    -- on the PAPERDOLL rather than the model, exactly as that file does: it stacks with the slots,
    -- hides with the tab, and the outset keeps it outside the model's own rect — which is what lets
    -- a texture on the parent show around a child frame's render at all.
    if not model._neBorder then
      model._neBorder = I.DrawInsetBorder(_G.InspectPaperDollFrame or model, model, 2) or nil
    end
    buildControls(model)
  end

  applyTalentsTab()
  if I.ApplyPvPPane then I.ApplyPvPPane() end

  -- Per-unit refresh. InspectPaperDollFrame_OnShow is the funnel Blizzard runs on every open AND
  -- on every retarget (InspectFrame_UnitChanged calls it directly); _SetLevel additionally fires on
  -- UNIT_LEVEL. INSPECT_TALENT_READY is this client's only "the data arrived" signal — there is no
  -- INSPECT_READY on 3.3.5a.
  if type(_G.InspectPaperDollFrame_OnShow) == "function" then
    hooksecurefunc("InspectPaperDollFrame_OnShow", refresh)
  end
  if type(_G.InspectPaperDollFrame_SetLevel) == "function" then
    hooksecurefunc("InspectPaperDollFrame_SetLevel", applyHeaderLines)
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("INSPECT_TALENT_READY")
  ev:RegisterEvent("UNIT_NAME_UPDATE")
  ev:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_NAME_UPDATE" and unit ~= (_G.InspectFrame and _G.InspectFrame.unit) then return end
    refresh()
  end)

  refresh()
end
