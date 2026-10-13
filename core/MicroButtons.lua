-- DragonUI_NewEra/core/MicroButtons.lua — NE.micro: our extra buttons on DragonUI's micro bar.
--
-- Lifted out of modules/encounterjournal/MicroButton.lua when a second button (Professions) arrived:
-- two modules each shifting the native cluster on their own would have fought over the same slots.
-- One owner now lays out every extra in one pass.
--
-- DragonUI's micromenu module (DragonUI/modules/micromenu.lua) skins/repositions a FIXED
-- MICRO_BUTTONS array with no extension point, so we can't inject into it. Every native button
-- is anchored directly off pUiMicroMenu's BOTTOMRIGHT corner at `x = index * (width + spacing)`
-- (NOT chained button-to-button), and DragonUI replaces `button.SetPoint` with a no-op after
-- laying it out so Blizzard's own FrameXML code can't nudge it back out of formation.
--
-- pUiMicroMenu is pinned flush to UIParent's BOTTOMRIGHT with ZERO slack for an extra button --
-- shifting MainMenu/Help rightward pushed them past the edge of the screen. So MainMenu/Help stay
-- exactly where DragonUI put them, and everything from PVP back to Character is re-chained leftward
-- from MainMenu with our buttons slotted in where retail has them (see the chain rule below). Open screen space
-- is on the left.
--
-- Shifting a DragonUI-owned button requires momentarily restoring its real SetPoint (DragonUI
-- itself does this for MainMenuBarBackpackButton in micromenu.lua) and re-installing the no-op
-- afterward so its own protections hold.
--
-- The inter-button padding is measured live off Help/MainMenu every call rather than hardcoded, so
-- it tracks grayscale/scale/spacing changes (as does the button size, copied from MainMenu). This is
-- safe because DragonUI's layout is idempotent from scratch each refresh (position = f(index)), and
-- Help/MainMenu are the two buttons we never move -- measuring off a button we DO move fed our own
-- output back into itself and compounded drift on every retry timer.
--
-- We re-run the layout whenever DragonUI's own public refresh entry points fire (hooksecurefunc on
-- addon.RefreshMicromenu / RefreshMicromenuSystem / RefreshMicromenuVehicle).

local NE = DragonUI_NewEra
if not NE then return end
NE.micro = NE.micro or {}
local M = NE.micro

-- Retail micro-button art, fdid 4708813 (NewEra's ReferenceAddons/NewEra/Art/Common/4708813-micromenu-1x.blp).
-- Same sheet/rect family DragonUI's own micromenu atlas uses for the OTHER buttons
-- (ui-hud-micromenu-<name>-<state>-2x); DragonUI's shipped sheet just lacks the retail-only icons.
local ART_FDID = 4708813
NE.tex.RegisterLocal(ART_FDID, "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Common\\4708813-ui-hud-micromenu.blp")
M.ART_FDID = ART_FDID

-- DragonUI paints a metal plate BEHIND every native icon (button.DragonUIBackground). These are the
-- same plate rects DragonUI uses (micromenu.lua, bg/bgPushed texcoords), on this sheet. Verified by
-- decoding the sheet to PNG and cropping (see [[blp-inspection-workflow]]).
NE.tex.RegisterAtlas("ui-hud-micromenu-plate-2x",        { file = ART_FDID, left = 0.065430, right = 0.127930, top = 0.330078, bottom = 0.490234 })
NE.tex.RegisterAtlas("ui-hud-micromenu-plate-pushed-2x", { file = ART_FDID, left = 0.065430, right = 0.127930, top = 0.494141, bottom = 0.654297 })

-- The strip left of MainMenu is read off the bar itself (DragonUI's shown buttons, right to left by
-- position) rather than from a list of names kept here: a hardcoded list missed DragonUI's own
-- Professions button the day it shipped, and Spellbook was chained on top of it. Our extras slot in
-- by rule (spec.before): Professions right of Character, as retail has it; one with no `before`
-- (Adventure Guide) goes right next to the menu.
local extras = {}   -- [global name] = { button, enabled = fn }

-- DragonUI's micro-button strip. Its clean-room micromenu rewrite (2026-09) renamed the frame from
-- pUiMicroMenu to DragonUI_MicroButtonBar; without the new name Layout bailed out and hid every
-- button we add (Professions, Adventure Guide). Both names are accepted so either DragonUI works.
local function microMenu()
  return _G.DragonUI_MicroButtonBar or _G.pUiMicroMenu
end

local function syncPlate(b)
  if b.nePanelOpen then b.nePlate[1]:Hide(); b.nePlate[2]:Show()
  else b.nePlate[1]:Show(); b.nePlate[2]:Hide() end
end

-- Panel-open state: the pushed plate + pushed icon while the button's window is up, like DragonUI's
-- own buttons (which follow SetButtonState from FrameXML).
function M.SetPushed(b, open)
  if not b then return end
  b.nePanelOpen = open and true or false
  b:SetButtonState(open and "PUSHED" or "NORMAL", open and true or nil)
  syncPlate(b)
end

-- spec = { name, art (atlas stem, e.g. "professions"), tooltip (string or fn), onClick, enabled (fn),
--          before (optional: global name of the DragonUI button this one sits immediately right of) }
-- Atlases ui-hud-micromenu-<art>-{up,down,mouseover,disabled}-2x must be registered by the caller.
function M.Add(spec)
  local b = CreateFrame("Button", spec.name, microMenu() or UIParent)
  -- DragonUI hardcodes native buttons to 32x40 regardless of the art's 41px height; layout() then
  -- tracks whatever size DragonUI last gave MainMenu (14x19 in grayscale mode).
  b:SetSize(32, 40)
  b:SetFrameStrata("MEDIUM")
  b:Hide()

  local function plate(atlas)
    local t = b:CreateTexture(nil, "BACKGROUND")
    NE.tex.SetAtlas(t, atlas, false)
    t:SetPoint("CENTER", b, "CENTER", -1, 1)   -- DragonUI's DragonUIBackground offset
    t:SetSize(32, 41)
    return t
  end
  b.nePlate = { plate("ui-hud-micromenu-plate-2x"), plate("ui-hud-micromenu-plate-pushed-2x") }
  syncPlate(b)
  b:SetScript("OnMouseDown", function(self) self.nePlate[1]:Hide(); self.nePlate[2]:Show() end)
  b:SetScript("OnMouseUp", function(self) syncPlate(self) end)

  local stem = "ui-hud-micromenu-" .. spec.art .. "-"
  local function state(layer, s)
    local t = b:CreateTexture(nil, layer)
    NE.tex.SetAtlas(t, stem .. s .. "-2x", false)
    t:SetAllPoints(b)
    return t
  end
  b:SetNormalTexture(state("ARTWORK", "up"))
  b:SetPushedTexture(state("ARTWORK", "down"))
  b:SetDisabledTexture(state("ARTWORK", "disabled"))
  local h = state("HIGHLIGHT", "mouseover")
  h:SetBlendMode("ADD")
  b:SetHighlightTexture(h)

  b:SetScript("OnClick", spec.onClick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local text = type(spec.tooltip) == "function" and spec.tooltip() or spec.tooltip
    GameTooltip:SetText(text or "")
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  extras[spec.name] = { button = b, enabled = spec.enabled, before = spec.before }
  if M.Layout then M.Layout() end
  return b
end

-- Temporarily restore a DragonUI-noop'd button's real SetPoint, reposition it, then re-install
-- the no-op.
local function setPointThroughNoop(button, ...)
  local noop = NE.dragon and NE.dragon._noop
  local wasNooped = (noop ~= nil and button.SetPoint == noop)
  if wasNooped then button.SetPoint = UIParent.SetPoint end
  button:ClearAllPoints()
  button:SetPoint(...)
  if wasNooped then button.SetPoint = noop end
end

local function hideAll()
  for _, e in pairs(extras) do e.button:Hide() end
end

function M.Layout()
  if not next(extras) then return end

  local pvp, mainMenu, help, menu = _G.PVPMicroButton, _G.MainMenuMicroButton, _G.HelpMicroButton, microMenu()
  if not (pvp and mainMenu and help and menu and pvp:IsVisible()) then hideAll(); return end

  -- Edge-to-edge padding between two adjacent buttons we never move. Normally NEGATIVE: DragonUI's
  -- default icon_spacing is -6 (the plates tuck under each other). No scale conversion: every micro
  -- button, ours included, is an unscaled child of pUiMicroMenu, so GetLeft/GetRight already report
  -- in the units SetPoint offsets use.
  local helpLeft, mainRight = help:GetLeft(), mainMenu:GetRight()
  if not (helpLeft and mainRight and mainMenu:GetLeft()) then hideAll(); return end
  local pad = helpLeft - mainRight
  -- DragonUI's skin not applied yet (stock positions, spread across a wide bar): wait for the next
  -- retry / refresh rather than chaining off it.
  if pad > 100 or pad < -100 then hideAll(); return end

  local bw, bh = mainMenu:GetWidth(), mainMenu:GetHeight()
  local any = false
  for _, e in pairs(extras) do
    local b = e.button
    e.on = (not e.enabled) or e.enabled()
    if e.on then
      any = true
      if b:GetParent() ~= menu then b:SetParent(menu) end   -- adopt the menu (and its scale)
      if bw and bh and bw > 0 and bh > 0 then
        b:SetSize(bw, bh)
        b.nePlate[1]:SetSize(bw, bh + 1); b.nePlate[2]:SetSize(bw, bh + 1)
      end
      b:Show()
    else
      b:Hide()
    end
  end
  -- Nothing of ours to place: leave DragonUI's strip exactly as it laid it out.
  if not any then return end

  -- DragonUI's own buttons left of MainMenu, right to left. Only their ORDER is read, so it does not
  -- matter whether DragonUI or an earlier pass of ours last placed them. dragonUISuppressed marks a
  -- button whose owning module was switched off; DragonUI hides it and closes the gap, so skip it.
  local mainLeft = mainMenu:GetLeft()
  local natives = {}
  for _, b in ipairs({ menu:GetChildren() }) do
    local name, left = b:GetName(), b:GetLeft()
    if name and name:find("MicroButton$") and not extras[name] and not b.dragonUISuppressed
       and b:IsShown() and left and left < mainLeft then
      natives[#natives + 1] = b
    end
  end
  table.sort(natives, function(x, y) return x:GetLeft() > y:GetLeft() end)

  local chain, placed = {}, {}
  local function addExtras(before)
    for _, e in pairs(extras) do
      if e.on and not placed[e] and e.before == before then
        placed[e] = true
        chain[#chain + 1] = e.button
      end
    end
  end
  addExtras(nil)
  for _, b in ipairs(natives) do
    addExtras(b:GetName())
    chain[#chain + 1] = b
  end
  -- An extra whose `before` button is absent goes on the left end rather than vanishing.
  for _, e in pairs(extras) do
    if e.on and not placed[e] then chain[#chain + 1] = e.button end
  end

  local prev = mainMenu
  for _, b in ipairs(chain) do
    if extras[b:GetName()] then
      b:ClearAllPoints()
      b:SetPoint("BOTTOMRIGHT", prev, "BOTTOMLEFT", -pad, 0)
    else
      setPointThroughNoop(b, "BOTTOMRIGHT", prev, "BOTTOMLEFT", -pad, 0)
    end
    prev = b
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_ENTERING_VEHICLE")
f:RegisterEvent("UNIT_EXITING_VEHICLE")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    -- DragonUI applies its micromenu skin on the same event, but how long it takes to settle varies
    -- (cold login vs /reload). Retry a few times; Layout is idempotent and self-guarding.
    if C_Timer and C_Timer.After then
      for _, t in ipairs({ 1, 3, 6, 10 }) do C_Timer.After(t, M.Layout) end
    else
      M.Layout()
    end
    f:UnregisterEvent("PLAYER_LOGIN")
  else
    M.Layout()
  end
end)

-- Track DragonUI's own relayouts (spacing/scale/grayscale/vehicle) via its public refresh points.
do
  local dragon = NE.dragon
  if dragon then
    for _, fn in ipairs({ "RefreshMicromenu", "RefreshMicromenuSystem", "RefreshMicromenuVehicle" }) do
      if dragon[fn] then hooksecurefunc(dragon, fn, function() M.Layout() end) end
    end
  end
end
