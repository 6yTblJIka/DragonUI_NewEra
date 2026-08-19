-- DragonUI_NewEra/modules/inspect/InspectFrame.lua — modern chrome on the inspect window.
--
-- DOWNPORT of NewEra/InspectFrame/InspectFrame.lua (Classic 1.15). The frame this reskins is a
-- different animal on 3.3.5a, so the CHROME half of the source is re-derived against the real
-- Blizzard_InspectUI (Interface 30300) rather than transcribed:
--
--   * Era's InspectFrame inherits ButtonFrameTemplate, so the 1.15 source hid f.NineSlice's
--     template pieces and re-textured them. On 3.3.5a InspectFrame is a BARE 384x512 Frame that
--     owns exactly one region — InspectFramePortrait. Every wooden border belongs to its tab
--     SUBFRAMES, each `setAllPoints` over the whole window:
--         InspectPaperDollFrame  (id 1)  UI-Character-CharacterTab-{L1,R1,BottomLeft,BottomRight}
--         InspectPVPFrame        (id 2)  UI-Character-General-*  + its own UI-Character-PVP plate
--         InspectTalentFrame     (id 3)  UI-Character-General-*  + the talent-tree art
--     Those quadrants are UNNAMED in the XML, so they are matched by texture PATH — the same way
--     DragonUI's own character panel finds the identical art on CharacterFrame's subframes.
--   * Tabs are Character / PVP / Talents (PanelTemplates_SetNumTabs(self, 3)). There is no Honor
--     tab (vanilla-only) and no Guild tab (Cataclysm), so the 1.15 source's Honor pane and Guild
--     pane have no counterpart here — see PORT_NOTES.md.
--   * Inspect TALENTS are native on this client (InspectTalentFrame + INSPECT_TALENT_READY) — but
--     the tab is retired anyway, in favour of the 1.15 source's (and retail's) paperdoll BUTTON,
--     which opens this addon's own talent window on the inspected unit. See PaperDoll.lua.
--   * The PVP tab is drawn by PvPPane.lua on our own furniture; the native pane keeps running
--     underneath it as the data pump, with its content squelched.
--
-- GEOMETRY. ONE window size on every tab (a window that changes shape when you click a tab reads
-- as broken). The paperdoll is re-laid-out into it by PaperDoll.lua, on DragonUI's character-panel
-- numbers; Blizzard's two panes keep their own layout and are scaled + anchored so their CONTENT
-- lands on the interior instead of sitting adrift in the middle of it. See PANE_FIT below.
--
-- REUSE (the §2 core toolkit — this port has no NE.charpanel; DragonUI owns the character panel):
--   NE.panelchrome.HideClassicChrome / ApplyModernChrome / ModernizeCloseButton / TitleBand
--   NE.portrait.SetUnit, NE.tabs.ReskinClassicTab + SizeAndAnchorTabs, NE.FrameUtil.ForEachRegion
-- No new art: every atlas used here already ships for the other NewEra windows.

local NE = DragonUI_NewEra
if not NE or NE.disabled then return end

NE.inspect = NE.inspect or {}
local I = NE.inspect
local PC = NE.panelchrome

-- Retail PANEL_DEFAULT_WIDTH/HEIGHT — DragonUI's character panel to the pixel, on every tab. The
-- inspect window and the character window are the same window with someone else's gear in it, so
-- they are the same size on screen.
--
-- This was briefly 480: Blizzard's own PvP and Talents panes want ~390-421 of content height and had
-- to shrink to fit 424's 360 of interior. Neither is on screen any more — the PvP tab is ours
-- (PvPPane.lua lays out to whatever the interior is) and talents moved to a paperdoll button — so
-- the taller window bought nothing and cost the match with the character panel.
I.PANEL_W, I.PANEL_H = 338, 424
-- Blizzard's own inspect window, which the PvP and Talents panes are laid out against.
I.VANILLA_W, I.VANILLA_H = 384, 512
-- The interior rect our content lives in. Retail's SharedUIPanelTemplates PANEL_INSET_* values,
-- except for the RIGHT one: retail (and DragonUI, which inherits it) uses -6 against a left of 4,
-- and that 2px lean lands on everything anchored to this rect. It is invisible on the character
-- panel, whose frame widens under the stats sidebar so its right edge is nowhere near the columns;
-- here the frame is exactly 338 and the right-hand column ends up with visibly more air beside it
-- than the left. -4 makes the interior symmetric, which is what the content needs.
I.INSET = { left = 4, top = -60, right = -4, bottom = 4 }

-- Levels above InspectFrame the tab subframes are raised to, so our interior ground renders
-- between the frame's rock fill and the tab contents instead of on top of them.
local SUBFRAME_LEVEL = 10
I.SUBFRAME_LEVEL = SUBFRAME_LEVEL   -- PvPPane.lua puts its own pane on the same level

-- How far in from the screen edge the panel manager should place this window. DragonUI's value for
-- the character panel, so the two sit on the same line.
local PANEL_X_NUDGE = 6

local SUBFRAMES = { "InspectPaperDollFrame", "InspectPVPFrame", "InspectTalentFrame" }
I.SUBFRAMES = SUBFRAMES

local TABS = { "InspectFrameTab1", "InspectFrameTab2", "InspectFrameTab3" }

-- The wooden 4-quadrant chrome families the subframes declare, verified against the 3.3.5a XML.
-- Matched on the texture PATH because the quadrants carry no names. Deliberately narrow: the
-- talent tree's own InspectTalentFrameBackground* art and the PvP plate are CONTENT, not chrome,
-- and stay exactly where Blizzard put them.
local CLASSIC_CHROME = {
  "ui%-character%-charactertab",
  "ui%-character%-general",
}

-- Named regions that are not chrome by path but still have to go. InspectTalentFramePortrait is
-- the talents pane's own copy of the frame portrait, drawn at its TOPLEFT(7,-6) — a second head
-- behind the one in the corner cutout, and it travels to wherever the pane is fitted below.
local CLASSIC_EXTRA = { "InspectTalentFramePortrait" }

local function isClassicChrome(path)
  if type(path) ~= "string" then return false end
  local lower = path:lower()
  for i = 1, #CLASSIC_CHROME do
    if lower:find(CLASSIC_CHROME[i]) then return true end
  end
  return false
end

-- Sweep one subframe's own textures, hiding the wooden chrome. Idempotent, and cheap enough to
-- re-run on every show (nothing here re-shows them, but the frames are Blizzard's).
--
-- EVERY LAYER, not just BACKGROUND: the paperdoll and PvP panes declare their quadrants on
-- BACKGROUND, but the TALENTS pane declares the identical four textures on BORDER
-- (InspectTalentFrame.xml). A BACKGROUND-only walk left that whole wooden frame on screen inside
-- ours. The path match is what keeps a full walk safe — it is the only thing deciding, and it
-- names two texture families and nothing else.
local function sweepChrome(frame)
  if not frame then return end
  NE.FrameUtil.ForEachRegion(frame, "Texture", nil, function(r)
    if r._neChromeHidden then
      r:Hide()
    elseif r.GetTexture and isClassicChrome(r:GetTexture()) then
      r._neChromeHidden = true
      r:Hide()
    end
  end)
  for _, name in ipairs(CLASSIC_EXTRA) do
    local r = _G[name]
    if r and r.Hide then r:Hide() end
  end
end
I.SweepChrome = sweepChrome

-- ----------------------------------------------------------------------------
-- Interior — retail's PANEL_INSET_* box as a frame, grounded in DragonUI's own
-- `character-panel-background`. Everything the paperdoll lays out hangs off it, the native panes
-- are fitted to it, and it is the one place the interior geometry is written down.
--
-- The stack is the character panel's, and it needs BOTH halves: the stone body underneath, which is
-- what makes the window read like the rest of the family, and this recessed dark ground on top of
-- it, which is what makes the content area read as an inset rather than as content floating on
-- wallpaper. A round with only the ground looked like a black blanket over the stone; a round with
-- only the stone lost the inset. Neither is the character panel.
--
-- DragonUI injects set_atlas onto the Texture metatable for every texture in the client
-- (utils/core.lua inject_api), which is how this reaches the atlas; a flat near-black stands in if
-- that is ever unavailable, and paintInset re-tries so a late injection still lands.
-- ----------------------------------------------------------------------------
local function paintInset(inset)
  if inset._nePainted then return end
  local bg = inset.Bg
  if bg.set_atlas then
    inset._nePainted = pcall(bg.set_atlas, bg, "character-panel-background") and true or false
  end
  if not inset._nePainted then
    bg:SetTexture(0, 0, 0, 0.9)   -- DOWNPORT: colour args on SetTexture; no SetColorTexture here
  end
end

-- The recessed rim. DragonUI exposes the exact routine its character panel rims ITS insets with
-- (CP.DrawPaneBorder — 6px UI-Frame-Inner corners over 3px tiles, including the one-pixel drop the
-- bottom pair needs), so this calls that rather than approximating it with our own nineslice: the
-- two windows should be the same window, and "the same" is easier to keep true when it is literally
-- the same code. `host` owns the textures so they hide with it, `target` is what gets rimmed, and
-- `outset` pushes the rim clear of a target whose own ground would otherwise show past it.
--
-- Falls back to our InsetFrameTemplate nineslice — same art family, marginally different geometry —
-- if the base addon ever stops exposing it.
function I.DrawInsetBorder(host, target, outset)
  local CP = NE.dragon and NE.dragon.CharacterPanel
  if CP and type(CP.DrawPaneBorder) == "function" then
    local ok = pcall(CP.DrawPaneBorder, host, target, outset)
    if ok then return true end
  end
  if NE.nineslice and NE.nineslice.AttachInset and host == target then
    local o = outset or 0
    NE.nineslice.AttachInset(host, -o, o, o, -o)
    return true
  end
  return false
end

local function ensureInset(f)
  if f.NE_Inset then return f.NE_Inset end

  local inset = CreateFrame("Frame", "NE_InspectFrameInset", f)
  inset:SetPoint("TOPLEFT",     f, "TOPLEFT",     I.INSET.left,  I.INSET.top)
  inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", I.INSET.right, I.INSET.bottom)
  inset:SetFrameLevel((f:GetFrameLevel() or 1) + 2)
  inset:EnableMouse(false)

  local bg = inset:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(inset)
  inset.Bg = bg
  paintInset(inset)

  I.DrawInsetBorder(inset, inset)

  f.NE_Inset = inset
  return inset
end
I.EnsureInset = ensureInset

-- The window body: UI-Background-Rock, tiled, AT FULL BRIGHTNESS from just under the title bar.
--
-- PC.ApplyModernChrome paints this too, but through PC.ApplyBodyFill, which multiplies the rock by
-- PC.BODY_TINT (0.32) — the near-black the bag windows want. Every window in the NewEra family that
-- reads as stone (professions, guild, auction house) paints its own body untinted instead, and this
-- is that same three lines — but flush to the LEFT edge, not guild's measured 4px inset
-- (modules/guild/Window.lua:79). That window's border covers a sliver its body would otherwise show
-- past; this one's does not, and the 4 left a visible strip of bare frame down the left side.
local ROCK_FDID = 374155

local function paintBody(f)
  local bg = f.Bg
  if not bg then
    -- ApplyModernChrome normally builds this; owning the fallback means a change over there can
    -- never leave this window with no body at all, only with the wrong one for a moment.
    bg = f:CreateTexture(nil, "BACKGROUND")
    f.Bg = bg
  end
  local rockPath = NE.tex and NE.tex.localFiles and NE.tex.localFiles[ROCK_FDID]
  bg:SetTexture(rockPath or ROCK_FDID, "REPEAT", "REPEAT")
  bg:SetHorizTile(true)
  bg:SetVertTile(true)
  bg:SetTexCoord(0, 1, 0, 1)
  bg:SetVertexColor(1, 1, 1)
  bg:ClearAllPoints()
  bg:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -21)
  bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,   0)
  bg:Show()
end

-- ----------------------------------------------------------------------------
-- Where the UIPanel manager puts this window.
--
-- Two things are wrong with what it does by default, and both are one attribute:
--
--   xoffset   Left-area panels sit flush against the screen edge on this client (UIParent's
--             LEFT_OFFSET is 0). Fine for a wooden frame whose art carried its own transparent
--             margin; not for a modern one that is opaque to its edge. 6px in, the same nudge
--             DragonUI gives the character panel.
--   pushable  `UIPanelWindows["InspectFrame"]` declares 0, and the character panel declares 3 —
--             so opening this one takes the LEFT slot and shoves the character panel over to the
--             centre (the two swap places, which is the opposite of what you asked for). At 3 the
--             manager's "only one open" branch stops preferring us, and we land in the centre
--             slot: to the RIGHT of the character panel, which stays where it is.
--
-- On the FRAME's attributes, not in UIPanelWindows — tainting that table blocks the first panel
-- open in combat (DragonUI modules/characterpanel/chrome.lua:126). That has a catch of its own:
-- GetUIPanelWindowInfo copies the whole UIPanelWindows row onto the frame the first time it is
-- asked, and only then treats attributes as authoritative. Setting `pushable` before that copy
-- would just be overwritten by it — so declare the row's OTHER fields here too and mark it
-- defined, which is the documented way to opt a frame out of the table entirely.
-- ----------------------------------------------------------------------------
local PANEL_PUSHABLE = 3   -- == the character panel's, which is what puts us beside it

local function applyPanelLayout(f)
  if not f.SetAttribute then return end
  if f:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE
     and f:GetAttribute("UIPanelLayout-pushable") == PANEL_PUSHABLE then
    return
  end
  f:SetAttribute("UIPanelLayout-area",     "left")      -- restated: see the header
  f:SetAttribute("UIPanelLayout-pushable", PANEL_PUSHABLE)
  f:SetAttribute("UIPanelLayout-xoffset",  PANEL_X_NUDGE)
  f:SetAttribute("UIPanelLayout-enabled",  true)
  f:SetAttribute("UIPanelLayout-defined",  true)        -- last: it seals the row above
  if f:IsShown() and UpdateUIPanelPositions then UpdateUIPanelPositions(f) end
end

-- ----------------------------------------------------------------------------
-- Chrome.
-- ----------------------------------------------------------------------------
local function applyChrome()
  local f = _G.InspectFrame
  if not f then return end

  -- InspectFramePortrait is the one region InspectFrame owns and we KEEP it (it becomes the
  -- portrait cutout below), so register it before the BACKGROUND-layer walk runs.
  if _G.InspectFramePortrait then PC.Keep(f, _G.InspectFramePortrait) end
  PC.HideClassicChrome(f)

  -- Metal nineslice on f.NineSlice, the body fill, and the top tile streaks under the title band.
  PC.ApplyModernChrome(f)
  paintBody(f)     -- over the top of ApplyBodyFill's tinted version; see paintBody's header

  -- ApplyModernChrome also lays the TopTileStreaks band on the frame at BORDER, where the
  -- nineslice's 75-tall OVERLAY TopEdge covers it — as it does in every other window here, none of
  -- which show that band either. It is DELIBERATELY left covered, and this is the whole story:
  --
  --   * hosting it on a frame ABOVE the nineslice (what the guild and professions windows do) makes
  --     it visible, but a child frame draws over every texture on the frame below it — so the band
  --     covered InspectFramePortrait, which is Blizzard's and lives on the base frame, from the eyes
  --     down. Starting it clear of the portrait then left its cut edge reading as a hard shadow
  --     across the stone.
  --   * the placement that WOULD work is DragonUI's on the character panel: nineslice pieces on the
  --     FRAME ITSELF rather than a child, so plain draw layers order the stack (rock BACKGROUND <
  --     streaks BORDER < portrait ARTWORK < metal OVERLAY). NE.nineslice always applies to a child
  --     (PC.ensureNineSlice), so taking that route here means bypassing PC's chrome build.
  --
  -- Not worth it for a decorative band: the rock body is what makes this window read like the rest
  -- of the family.
  ensureInset(f)

  applyPanelLayout(f)

  -- Every tab pane above the interior ground it now sits on (fitPane re-anchors two of the three
  -- off setAllPoints, but all three are still siblings of the ground and have to draw over it).
  for _, name in ipairs(SUBFRAMES) do
    local sub = _G[name]
    if sub then sub:SetFrameLevel((f:GetFrameLevel() or 1) + SUBFRAME_LEVEL) end
  end
end

-- Portrait — the inspected unit's head, seated in the nineslice corner cutout. Blizzard's
-- InspectFramePortrait is 60x60 at TOPLEFT(7,-6) on ARTWORK; the cutout wants it at (-5, 8).
-- SetPortraitTexture is natively circular on 3.3.5a, so no mask is involved (core/Portrait.lua).
local PORTRAIT_OPTS = { size = 60, layer = "ARTWORK", anchor = { "TOPLEFT", -5, 8 } }

local function applyPortrait()
  local f, p = _G.InspectFrame, _G.InspectFramePortrait
  if not (f and p) then return end
  NE.portrait.SetUnit(p, f, f.unit, PORTRAIT_OPTS)
end
I.ApplyPortrait = applyPortrait

-- Close button — reskin the EXISTING one, never create a duplicate. Blizzard parks it at
-- CENTER/TOPRIGHT(-44,-25), an offset that measured the wooden frame's overhang; the modern
-- default anchor puts it on the metal corner.
local function applyCloseButton()
  local cb = _G.InspectFrameCloseButton
  if cb and PC.ModernizeCloseButton then
    pcall(PC.ModernizeCloseButton, cb, { frameLevelBump = SUBFRAME_LEVEL + 10 })
  end

  -- The talents pane ships a SECOND close button of its own (InspectTalentFrameCloseButton, same
  -- wooden-overhang offset). With the frame's own button now on the corner it is a duplicate
  -- sitting inside the window, so it goes away — and stays away, since PanelTemplates re-shows the
  -- pane on every tab switch.
  local tcb = _G.InspectTalentFrameCloseButton
  if tcb and not tcb._neHidden then
    tcb._neHidden = true
    tcb:Hide()
    tcb:HookScript("OnShow", function(self) self:Hide() end)
  end
end

-- Title band — Blizzard's InspectNameFrame sits at CENTER(6, 232), over the old wooden header.
-- Move it into the modern metal title band, full width between the portrait and the close button.
local function applyTitle()
  local f, nameFrame = _G.InspectFrame, _G.InspectNameFrame
  if not (f and nameFrame) then return end

  local band = PC.TitleBand(f)
  nameFrame:ClearAllPoints()
  nameFrame:SetAllPoints(band)
  -- The band is painted by the nineslice TOP edge, which lives on the f.NineSlice CHILD frame.
  -- Whichever sibling has the higher frame LEVEL draws on top, so lift the name frame past it.
  nameFrame:SetFrameLevel(band:GetFrameLevel())

  local fs = _G.InspectNameText
  if fs then
    -- Blizzard sized the FontString to 109px for the old header; unclamp it so a long name uses
    -- the whole band before it truncates.
    fs:SetWidth(0)
    fs:SetFontObject(GameFontNormal)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    fs:SetJustifyH("CENTER")
    -- Centred on the WINDOW, not on the title band. The band is inset 58 from the left (clearing
    -- the portrait) and 24 from the right (clearing the close button), so centring inside it puts
    -- the name 17px right of the window's middle — visibly off. The professions and guild windows
    -- centre their titles on the frame for the same reason, "matching how the Character window
    -- centers the player name" (modules/professions/Window.lua).
    fs:ClearAllPoints()
    fs:SetPoint("TOP", f, "TOP", 0, -6)
    f._neTitle = fs
  end
end

-- Tabs. Blizzard anchors Tab1 at CENTER/BOTTOMLEFT(60, 61) — inside the wooden chrome, with the
-- classic -16 overlap chaining Tab2/Tab3 off it. Retail hangs them off the frame's bottom-left
-- edge, which is what the modern tab art is cut for.
local function applyTabs()
  local f = _G.InspectFrame
  if not f then return end
  local base = f:GetFrameLevel() or 1
  for _, name in ipairs(TABS) do
    NE.tabs.ReskinClassicTab(name)
    -- Above the tab panes, which now reach past the window's bottom edge (see fitPane). Belt to
    -- that function's braces: nothing invisible gets to sit on top of the tab you are clicking.
    local tab = _G[name]
    if tab then tab:SetFrameLevel(base + SUBFRAME_LEVEL + 5) end
  end
  NE.tabs.SizeAndAnchorTabs(f, TABS, { startX = 11, startY = 2 })
end

-- ----------------------------------------------------------------------------
-- Geometry. ONE window size, every tab — a window that changes shape when you click a tab reads as
-- broken, and 338x424 is the size the character window is already at.
--
-- That means Blizzard's two panes have to be made to fit it rather than the other way round. They
-- are laid out for a 384x512 window whose WOODEN BORDER ate ~30px a side and ~90px at the bottom;
-- drop that border and the content sits in the middle of a lot of nothing. So each pane is given
-- its declared 384x512 as an explicit size (breaking the XML's setAllPoints), scaled, and anchored
-- so that its CONTENT rect — not its frame rect — lands on our interior.
--
-- The content rects below are read off Blizzard_InspectUI's own XML, in each pane's own 384x512
-- coordinate space:
--
--   InspectPVPFrame     A FALLBACK ONLY: PvPPane.lua normally squelches this pane's content and
--                       draws its own, so this fit is what the tab degrades to if that file is
--                       missing. The UI-Character-PVP plate everything else is anchored to:
--                       TOPLEFT(14,-36).
--                       Its declared size is a 512x512 SHEET, most of which is transparent, so the
--                       right and bottom edges here are where the art actually stops — measured off
--                       a screenshot of the fitted window (x 350, y -425), not read off the XML like
--                       everything else in this file. If the margins ever look uneven, these two
--                       numbers are the ones to nudge.
--   InspectTalentFrame  x from the points bar's LEFT(16) to its RIGHT(384-36=348); y from the spec
--                       tabs' TOPLEFT(...,-40) down to the BOTTOM of the tree art, which is
--                       TOPLEFT(23,-77) plus 256+128 of picture = -461. The art, not the points bar
--                       at -431: it is the bottom-most thing that DRAWS, and anything left out of
--                       this rect hangs outside the window instead of inside it.
-- ----------------------------------------------------------------------------
local PANE_FIT = {
  InspectPVPFrame    = { left = 14, top = -36, right = 350, bottom = -425 },
  InspectTalentFrame = { left = 16, top = -40, right = 348, bottom = -461 },
}

-- The interior's size, COMPUTED — never measured. `NE_Inset:GetHeight()` is the obvious way to ask
-- and it lies: the frame is resized moments earlier in the same pass, and a frame's rect does not
-- resolve until the next layout, so the getter hands back the size from before the resize. That is
-- how the model came out 408 tall against Blizzard's 512-tall window instead of 320 — with its
-- backdrop hanging past the window's bottom edge and the item-level text riding down onto the tabs.
-- Everything that needs these numbers takes them from here.
local function interiorSize()
  return I.PANEL_W - I.INSET.left + I.INSET.right,   -- 338 - 4 - 4  = 330
         I.PANEL_H + I.INSET.top  - I.INSET.bottom   -- 424 - 60 - 4 = 360
end
I.InteriorSize = interiorSize

local function fitPane(name)
  local f, sub, rect = _G.InspectFrame, _G[name], PANE_FIT[name]
  if not (f and sub and rect) or sub._neFitted then return end
  sub._neFitted = true

  local iw, ih = interiorSize()
  local cw, ch = rect.right - rect.left, rect.top - rect.bottom
  -- Never above 1: at 480 tall both panes come out within 1-2% of life size, and upscaling
  -- Blizzard's art past that would only soften it.
  local scale  = math.min(iw / cw, ih / ch, 1)

  sub:ClearAllPoints()
  sub:SetWidth(I.VANILLA_W)     -- keep the coordinate space every child is anchored in
  sub:SetHeight(I.VANILLA_H)
  sub:SetScale(scale)

  -- Anchor offsets are in the CHILD's own scale, so a physical offset divides by it. We want the
  -- pane's (rect.left, rect.top) to sit at the interior's top-left, with any width left over split
  -- evenly so the content is centred rather than pushed against the left border.
  local slack = (iw - cw * scale) / 2
  sub:SetPoint("TOPLEFT", f, "TOPLEFT",
               (I.INSET.left + slack) / scale - rect.left,
               I.INSET.top / scale - rect.top)
  sub._neFitScale = scale

  -- The pane's FRAME rect is still 384x512 in its own units, so once it is no longer setAllPoints
  -- it hangs ~65px below the window — straight over the tab strip. It is `enableMouse="true"` in
  -- the XML purely to stop clicks falling through a panel, a job our own frame already does, so
  -- take the mouse off it rather than leave an invisible blocker sitting on the tabs. Its CHILDREN
  -- (the points bar's tooltip, the honor rows, every talent button) keep their own mouse.
  sub:EnableMouse(false)
end
I.FitPane = fitPane

local function applyGeometry()
  local f = _G.InspectFrame
  if not f then return end

  f:SetWidth(I.PANEL_W)
  f:SetHeight(I.PANEL_H)

  local inset = f.NE_Inset
  if inset then
    paintInset(inset)
    inset:Show()
  end

  for _, name in ipairs(SUBFRAMES) do
    sweepChrome(_G[name])
    fitPane(name)
  end
end
I.ApplyGeometry = applyGeometry

-- ----------------------------------------------------------------------------
-- Apply everything once. Called from Register.lua when Blizzard_InspectUI loads.
-- ----------------------------------------------------------------------------
local applied = false

function I.Apply()
  if applied then return end
  local f = _G.InspectFrame
  if not (f and NE.nineslice and NE.nineslice.ApplyLayout) then return end
  applied = true

  applyChrome()
  -- SIZE THE WINDOW BEFORE ANY CONTENT IS LAID OUT. The paperdoll's model height is derived from
  -- the interior rect, and the interior is a span between the frame's corners — run this after
  -- ApplyPaperDoll and the model measures itself against Blizzard's 512-tall window instead.
  applyGeometry()
  applyCloseButton()
  applyTitle()
  applyTabs()
  applyPortrait()

  -- Paperdoll content (slots, model, level line) — PaperDoll.lua.
  if I.ApplyPaperDoll then I.ApplyPaperDoll() end

  -- Tab switches bring a different pane's wooden chrome on screen, and the first switch is what
  -- builds some of it. InspectSwitchTabs is the single funnel: InspectFrame_Show, the tab buttons
  -- and InspectFrame_UpdateTalentTab's fallback all route through it.
  if type(_G.InspectSwitchTabs) == "function" then
    hooksecurefunc("InspectSwitchTabs", applyGeometry)
  end
  f:HookScript("OnShow", function()
    applyGeometry()
    applyPortrait()
  end)
end

function I.IsApplied() return applied end
