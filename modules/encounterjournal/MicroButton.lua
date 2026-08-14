-- DragonUI_NewEra/modules/encounterjournal/MicroButton.lua
-- A micromenu-adjacent button that opens the Adventure Guide (Encounter Journal).
--
-- DragonUI's own micromenu module (DragonUI/modules/micromenu.lua) skins/repositions a FIXED
-- MICRO_BUTTONS array with no extension point, so we can't inject into it. Every native button
-- is anchored directly off pUiMicroMenu's BOTTOMRIGHT corner at `x = index * (width + spacing)`
-- (NOT chained button-to-button), and DragonUI replaces `button.SetPoint` with a no-op after
-- laying it out so Blizzard's own FrameXML code can't nudge it back out of formation.
--
-- We insert ourselves between PVPMicroButton and MainMenuMicroButton (mirrors retail order and
-- NewEra's reference bar, which places Adventure Guide right before Help/MainMenu). The whole row
-- is anchored off pUiMicroMenu, which itself is pinned flush to UIParent's BOTTOMRIGHT with ZERO
-- slack for an extra button -- shifting MainMenu/Help rightward (an earlier version of this file)
-- pushed them past the edge of the screen. Instead we leave MainMenu/Help exactly where DragonUI
-- put them and shift everything from PVP back to Character one slot to the LEFT, where there's
-- open screen space, to make room for our button immediately left of MainMenu.
--
-- Shifting a DragonUI-owned button requires momentarily restoring its real SetPoint (DragonUI
-- itself does this for MainMenuBarBackpackButton around micromenu.lua:2525) and re-installing the
-- no-op afterward so its own protections hold.
--
-- The inter-button padding is measured live off Help/MainMenu's current positions every call
-- rather than hardcoded, so it stays correct across grayscale/scale/spacing changes (as does the
-- button's own size, copied from MainMenu). This is safe because DragonUI's
-- layout is idempotent from scratch each refresh (position = f(index), not relative to last
-- frame), so by the time our hooksecurefunc callback runs, every native button is always freshly
-- pristine (un-shifted) -- see setupMicroButtons/LayoutMicroButtons in micromenu.lua. That also
-- means when the module is disabled we don't need to un-shift anything: DragonUI's own next
-- refresh already reset everyone to pristine before our hook even runs.
--
-- We re-run this anchor whenever DragonUI's own public refresh entry points fire (hooksecurefunc
-- on addon.RefreshMicromenu / RefreshMicromenuSystem / RefreshMicromenuVehicle).

local NE = DragonUI_NewEra
local L = NE.L
if not NE then return end
NE.ej = NE.ej or {}

local MODULE = "EncounterJournal"

-- Real retail "AdventureGuide" micro-button art, not a generic icon. Sourced from NewEra
-- (ReferenceAddons/NewEra/Generated/AtlasData.lua: ui-hud-micromenu-adventureguide-*-2x, all on
-- fdid 4708813 = ReferenceAddons/NewEra/Art/Common/4708813-micromenu-1x.blp, copied to
-- Textures/Common/4708813-ui-hud-micromenu.blp). Same sheet/rect family DragonUI's own
-- micromenu.lua atlas system uses for the OTHER buttons (ui-hud-micromenu-<name>-<state>-2x) --
-- DragonUI's shipped sheet just never included Adventure Guide since 3.3.5a has no native one.
local ART_FDID = 4708813
NE.tex.RegisterLocal(ART_FDID, "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Common\\4708813-ui-hud-micromenu.blp")
local ART = {
  up        = { file = ART_FDID, left = 0.065430, right = 0.127930, top = 0.166016, bottom = 0.326172, width = 32, height = 41 },
  down      = { file = ART_FDID, left = 0.000977, right = 0.063477, top = 0.822266, bottom = 0.982422, width = 32, height = 41 },
  mouseover = { file = ART_FDID, left = 0.065430, right = 0.127930, top = 0.001953, bottom = 0.162109, width = 32, height = 41 },
  disabled  = { file = ART_FDID, left = 0.000977, right = 0.063477, top = 0.658203, bottom = 0.818359, width = 32, height = 41 },
}
for state, info in pairs(ART) do
  NE.tex.RegisterAtlas("ui-hud-micromenu-adventureguide-" .. state .. "-2x", info)
end

-- DragonUI paints a metal plate BEHIND every native icon (button.DragonUIBackground in
-- micromenu.lua). Verified by actually decoding this sheet to PNG and cropping it (scratchpad
-- blp2png.js + ImageMagick, see [[blp-inspection-workflow]]) rather than guessing coords blind --
-- these two rows in our icon's own column are genuine plain rounded-plate assets (not garbage/
-- another icon), matching the up/down/mouseover/disabled rows' 6-row-per-column layout.
local BG = {
  normal = { file = ART_FDID, left = ART.up.left, right = ART.up.right, top = 0.330078, bottom = 0.490234 },
  pushed = { file = ART_FDID, left = ART.up.left, right = ART.up.right, top = 0.494141, bottom = 0.654297 },
}
NE.tex.RegisterAtlas("ui-hud-micromenu-adventureguide-bg-2x", BG.normal)
NE.tex.RegisterAtlas("ui-hud-micromenu-adventureguide-bg-pushed-2x", BG.pushed)

local btn

local function isModuleEnabled()
  local dragon = NE.dragon
  if not (dragon and dragon.db and dragon.db.profile and dragon.db.profile.modules) then return true end
  local m = dragon.db.profile.modules["ne_" .. MODULE]
  if type(m) == "table" and m.enabled == false then return false end
  return true
end

local function create()
  if btn then return btn end

  -- Parent to pUiMicroMenu itself (not UIParent) so we inherit the SAME effective scale as every
  -- native button. DragonUI scales that frame down (menu:SetScale(menuScale)) to fit the classic
  -- 32x40 art into the modern micro-bar's visual size; a button parented to plain UIParent
  -- (effective scale 1) would render at its full 32x40 LOCAL size in REAL screen pixels --
  -- literally 1/menuScale times bigger on screen than a same-sized native button, which is what
  -- was actually making ours look oversized (not the icon's art/shape).
  local parent = _G.pUiMicroMenu or UIParent
  local b = CreateFrame("Button", "NE_EJMicroButton", parent)
  -- DragonUI hardcodes native buttons to 32x40 (micromenu.lua:2052) regardless of the art's true
  -- 41px asset height, squishing the texture slightly -- match that exactly so bottoms AND tops
  -- line up with the rest of the row instead of poking up by 1px.
  b:SetSize(32, 40)
  b:SetFrameStrata("MEDIUM")

  -- Matches DragonUI's own DragonUIBackground formula exactly (micromenu.lua ~2154-2167):
  -- SetSize(sizeX, sizeY + 1) centered with a (-1, 1) offset, sized off the BUTTON's own 32x40.
  local bg = b:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(bg, "ui-hud-micromenu-adventureguide-bg-2x", false)
  bg:SetPoint("CENTER", b, "CENTER", -1, 1)
  bg:SetSize(32, 41)

  local bgPushed = b:CreateTexture(nil, "BACKGROUND")
  NE.tex.SetAtlas(bgPushed, "ui-hud-micromenu-adventureguide-bg-pushed-2x", false)
  bgPushed:SetPoint("CENTER", b, "CENTER", -1, 1)
  bgPushed:SetSize(32, 41)
  bgPushed:Hide()
  b:SetScript("OnMouseDown", function() bg:Hide(); bgPushed:Show() end)
  b:SetScript("OnMouseUp", function() bg:Show(); bgPushed:Hide() end)
  -- Kept so reposition() can re-apply the (sizeX, sizeY + 1) formula when the button is resized
  -- to match the native ones (grayscale mode swaps 32x40 for 14x19).
  b.neBackgrounds = { bg, bgPushed }

  local n = b:CreateTexture(nil, "ARTWORK")
  NE.tex.SetAtlas(n, "ui-hud-micromenu-adventureguide-up-2x", false)
  n:SetAllPoints(b)
  b:SetNormalTexture(n)

  local p = b:CreateTexture(nil, "ARTWORK")
  NE.tex.SetAtlas(p, "ui-hud-micromenu-adventureguide-down-2x", false)
  p:SetAllPoints(b)
  b:SetPushedTexture(p)

  local h = b:CreateTexture(nil, "HIGHLIGHT")
  NE.tex.SetAtlas(h, "ui-hud-micromenu-adventureguide-mouseover-2x", false)
  h:SetAllPoints(b)
  h:SetBlendMode("ADD")
  b:SetHighlightTexture(h)

  local d = b:CreateTexture(nil, "ARTWORK")
  NE.tex.SetAtlas(d, "ui-hud-micromenu-adventureguide-disabled-2x", false)
  d:SetAllPoints(b)
  b:SetDisabledTexture(d)

  b:SetScript("OnClick", function()
    if NE.ej.Toggle then NE.ej.Toggle() end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(ADVENTURE_JOURNAL or L["Adventure Guide"])
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  btn = b
  return b
end

-- Temporarily restore a DragonUI-noop'd button's real SetPoint, reposition it, then re-install
-- the no-op -- same pattern DragonUI itself uses when it needs to move one of its own buttons
-- after initial layout (see MainMenuBarBackpackButton handling in micromenu.lua).
local function setPointThroughNoop(button, ...)
  local dragon = NE.dragon
  local noop = dragon and dragon._noop
  local wasNooped = (noop ~= nil and button.SetPoint == noop)
  if wasNooped then button.SetPoint = UIParent.SetPoint end
  button:ClearAllPoints()
  button:SetPoint(...)
  if wasNooped then button.SetPoint = noop end
end

-- The native buttons left of MainMenu, in DragonUI's own right-to-left MICRO_BUTTONS order
-- (micromenu.lua:108-120, non-Ascension branch -- this server has no PathToAscensionMicroButton).
-- We shift this whole cluster one slot left to open a gap for our button, cascading from PVP
-- (the one immediately left of MainMenu) back to Character.
--
-- This list MUST stay in sync with that array. CollectionsMicroButton is not a stock 3.3.5a button
-- -- DragonUI's Pets & Mounts module creates it (modules/collections/microbutton.lua) -- and it was
-- missing here, so the cascade jumped straight from PVP to LFD and dropped PVP directly on top of
-- it. Anything DragonUI later inserts into MICRO_BUTTONS has to be added here too.
local LEFT_CLUSTER_NAMES = {
  "PVPMicroButton", "CollectionsMicroButton", "LFDMicroButton", "SocialsMicroButton",
  "QuestLogMicroButton", "AchievementMicroButton", "TalentMicroButton", "SpellbookMicroButton",
  "CharacterMicroButton",
}

local function reposition()
  if not btn then return end

  if not isModuleEnabled() then
    btn:Hide()
    return
  end

  local pvp = _G.PVPMicroButton
  local mainMenu = _G.MainMenuMicroButton
  local help = _G.HelpMicroButton
  local menu = _G.pUiMicroMenu
  if not (pvp and mainMenu and help and menu and pvp:IsVisible()) then
    btn:Hide()
    return
  end

  -- create() can run before DragonUI has built pUiMicroMenu, in which case it fell back to
  -- UIParent. Adopt the real menu the moment it exists: everything below assumes our button shares
  -- the native buttons' parent, and therefore their scale.
  if btn:GetParent() ~= menu then btn:SetParent(menu) end

  -- Track whatever size DragonUI gave the native buttons on its last pass -- 32x40 normally, but
  -- 14x19 with grayscale_icons on (micromenu.lua:2012-2016). Keeping our hardcoded 32 there would
  -- be an 18px overlap all by itself.
  local bw, bh = mainMenu:GetWidth(), mainMenu:GetHeight()
  if bw and bh and bw > 0 and bh > 0 then
    btn:SetSize(bw, bh)
    for _, plate in ipairs(btn.neBackgrounds) do plate:SetSize(bw, bh + 1) end
  end

  -- Live edge-to-edge padding between two already-adjacent native buttons, measured fresh so it
  -- tracks the user's current spacing/scale/grayscale settings. Deliberately measured from
  -- Help/MainMenu -- the two buttons this module NEVER moves -- not from PVP/MainMenu. PVP gets
  -- relocated by us every call, so measuring off it fed our own prior output back into itself:
  -- each retry (1s/3s/6s/10s) compounded the drift outward, since DragonUI doesn't re-run its own
  -- layout on every one of our timers to reset PVP back to pristine in between. Help/MainMenu are
  -- a stable ground truth immune to that feedback loop, however many times this runs.
  --
  -- Normally NEGATIVE: DragonUI's default icon_spacing is -6, i.e. the plates deliberately tuck
  -- under each other by 6 (stride = 32 + (-6) = 26, micromenu.lua:1834-1841).
  local helpLeft, mainRight = help:GetLeft(), mainMenu:GetRight()
  if not (helpLeft and mainRight) then
    btn:Hide()
    return
  end
  local pad = helpLeft - mainRight

  -- Sanity guard: belt-and-suspenders in case DragonUI's skin hasn't applied yet at all (its
  -- buttons still at stock Blizzard positions, spread across a much wider bar). A sane packed
  -- gap is a handful of pixels either way; bail out and let the next scheduled retry (or the
  -- next real DragonUI refresh) catch it once the skin has actually settled.
  if pad > 100 or pad < -100 then
    btn:Hide()
    return
  end

  -- NO scale conversion here. GetLeft/GetRight already report in the queried frame's OWN
  -- coordinate space (screen pixels divided by its effective scale), and every micro button --
  -- ours included -- is an UNSCALED child of pUiMicroMenu (DragonUI only ever scales the menu
  -- frame itself, micromenu.lua:1929/2391/2509). So `pad` is already in exactly the units SetPoint
  -- offsets use below. Dividing it by menu:GetEffectiveScale() -- as this did -- inflated it by
  -- 1/(uiScale * scale_menu), e.g. 1/(0.64*0.9) = 1.74x at 1440p: -6 became -10.4, so each of the
  -- nine buttons we move landed ~4px too far right, and the compounding chain stacked the left end
  -- of the strip on top of itself.
  btn:ClearAllPoints()
  btn:SetPoint("BOTTOMRIGHT", mainMenu, "BOTTOMLEFT", -pad, 0)
  btn:Show()

  -- MainMenu/Help are NOT touched -- pUiMicroMenu is pinned flush to UIParent's BOTTOMRIGHT with
  -- no slack, so pushing them further right runs them off the edge of the screen. Our button sits
  -- immediately left of MainMenu instead, and the whole PVP..Character cluster shifts one slot
  -- further left (open screen space there) to make room.
  -- dragonUISuppressed marks a button whose owning module was switched off; DragonUI drops it from
  -- the strip entirely and closes the gap (CollectPresentMicroButtons, micromenu.lua:1824). Chain
  -- past those the same way, or we'd spend a slot on a hidden button and leave a hole in the row.
  local prev = btn
  for _, name in ipairs(LEFT_CLUSTER_NAMES) do
    local b = _G[name]
    if b and not b.dragonUISuppressed then
      setPointThroughNoop(b, "BOTTOMRIGHT", prev, "BOTTOMLEFT", -pad, 0)
      prev = b
    end
  end
end
NE.ej.RefreshMicroButton = reposition

local function init()
  create()
  reposition()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_ENTERING_VEHICLE")
f:RegisterEvent("UNIT_EXITING_VEHICLE")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    -- DragonUI applies its micromenu skin on the same event, but how long that actually takes
    -- to settle varies (more addons initializing on a cold login vs. a /reload) -- a single fixed
    -- delay isn't reliable. Retry a few times over the first several seconds; reposition() is
    -- idempotent (recomputes fresh from current button positions, with its own sanity guard
    -- against an unsettled/stock layout), so repeated calls are harmless and self-correcting.
    if C_Timer and C_Timer.After then
      C_Timer.After(1, init)
      C_Timer.After(3, reposition)
      C_Timer.After(6, reposition)
      C_Timer.After(10, reposition)
    else
      init()
    end
    f:UnregisterEvent("PLAYER_LOGIN")
  else
    reposition()
  end
end)

-- Track DragonUI's own relayouts (spacing/scale/grayscale/vehicle changes) instead of its
-- private layout internals -- these are the module's public refresh entry points.
do
  local dragon = NE.dragon
  if dragon then
    if dragon.RefreshMicromenu then hooksecurefunc(dragon, "RefreshMicromenu", reposition) end
    if dragon.RefreshMicromenuSystem then hooksecurefunc(dragon, "RefreshMicromenuSystem", reposition) end
    if dragon.RefreshMicromenuVehicle then hooksecurefunc(dragon, "RefreshMicromenuVehicle", reposition) end
  end
end
