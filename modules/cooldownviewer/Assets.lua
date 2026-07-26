-- DragonUI_NewEra/modules/cooldownviewer/Assets.lua — art for the cooldown VIEWERS.
--
-- (The /cdm settings window's own art is SettingsAssets.lua. This file is the bars and icons.)
--
-- PORT_PLAN §H.2 / Phase 8a. Six atlases were being set by name across ItemMixins, AuraItemMixins and
-- both BuffViewers item shapes, and not one of them was registered — so every `SetAtlas` returned
-- false and every region rendered as nothing. Nothing errored and nothing was logged, because a
-- missed atlas is an invisible texture, which is why this survived five phases of in-game testing:
-- the icons looked like plain spellbook icons and there was nothing to suggest they were meant not to.
--
-- WHY IT WAS MISSED. Upstream registers the sheet FDID and stops. On Classic Era the client's own
-- atlas database answers `C_Texture.GetAtlasInfo` for these names even where the art differs, so a
-- rect is never needed at the call site. 3.3.5a has no atlas database at all, so we must supply the
-- rect as well — and only the `SetAtlas` calls were ported, not the data behind them.
--
-- WHERE THE RECTS COME FROM, AND WHY THEY ARE NOT 0→1. Transcribed from
-- ReferenceAddons/NewEra/Generated/AtlasData.lua, the same practice SettingsAssets.lua follows.
-- §H.2 supposed upstream had no rects for these and that they would have to be derived from the BLP;
-- it does have them, and they are emphatically NOT full-file rects — 6704514 is a shared 256x128
-- sheet carrying the icon overlay in its left third and the three bar pieces down its right. Reading
-- a single-purpose sheet into a 0→1 rect would have stretched the overlay across the bar art.
--
-- VERIFIED, not transcribed on faith. Each BLP's real dimensions were read from its header, and the
-- rect fractions multiplied back out to the pixel:
--
--   6704514  256x128    overlay (0.339844-0.003906)*256 = 86.0   (0.679688-0.007812)*128 = 86.0
--                       bar     (0.832031-0.347656)*256 = 124.0  (0.250000-0.171875)*128 = 10.0
--                       bar-bg  (0.863281-0.347656)*256 = 132.0  (0.156250-0.007812)*128 = 19.0
--                       bar-pip (0.386719-0.347656)*256 = 10.0   (0.625000-0.265625)*128 = 46.0
--   6685874  512x1024   oorshdw (0.343750-0.259766)*512 = 43.0   (0.042969-0.000977)*1024 = 43.0
--   5199404  2048x1024  flipbk  (0.458496-0.412598)*2048 = 94.0  (0.898438-0.393555)*1024 = 517.0
--
-- Every product lands on the declared width/height exactly, which is the check that matters: it
-- proves these rects belong to the sheets we are shipping. SettingsAssets.lua records the failure
-- this guards against — retail repacked sheet 7289697, so the Era-generated rects were wrong for the
-- 12.1.0 BLP and had to be re-derived. The harness now asserts this arithmetic (qa/offline).
--
-- ONE BEHAVIOUR CHANGE TO KNOW ABOUT. Registering the GCD flipbook flips `hasFlipbook()` in
-- ItemMixins from false to true, which retires the fallback ready-flash burst and activates the
-- 22-frame sprite stepper — a code path that has never once executed, because the atlas it gates on
-- has never been registered. Its frame math is at least self-consistent with this art (94/2 = 47,
-- 517/11 = 47, so the sheet is 2x11 frames of 47px, exactly what FLASH_COLS/FLASH_ROWS say). If it
-- looks wrong in game, deleting the one flipbook line below reverts to the fallback with no other
-- change — the fallback was written to be the permanent alternative, not a stopgap.
--
-- 8b's inputs (6731092 icon-swipe, 5423465 secondarycooldown) are deliberately NOT shipped here.
-- They are file textures for SetSwipeTexture/SetEdgeTexture rather than atlases, nothing reads them
-- yet, and shipping art ahead of the code that uses it is how a repo accumulates 8MB of dead weight.

local NE = DragonUI_NewEra
if not (NE and NE.tex and NE.tex.RegisterLocal) then return end

local PATH = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\CooldownViewer\\"

-- 6704514 — the shared CoolDownManager sheet: icon overlay + the three BuffBar pieces.
NE.tex.RegisterLocal(6704514, PATH .. "6704514-ui-hud-cooldownmanager-iconoverlay.blp")
-- 6685874 — the out-of-range shadow.
NE.tex.RegisterLocal(6685874, PATH .. "6685874-ui-cooldownmanager-oorshadow.blp")
-- 5199404 — the shared ActionBar sheet; we take only the GCD flipbook strip from it.
NE.tex.RegisterLocal(5199404, PATH .. "5199404-ui-hud-actionbar-gcd-flipbook.blp")

NE.tex.RegisterAtlases({
  -- The icon frame. This is the single biggest visual difference between our viewers and retail's:
  -- without it a tile is a bare icon with no border at all.
  ["UI-HUD-CoolDownManager-IconOverlay"] = { file = 6704514, left = 0.003906, right = 0.339844, top = 0.007812, bottom = 0.679688, width = 86,  height = 86 },

  -- Out-of-range shading, on its own sheet (ItemMixins:39).
  ["UI-CooldownManager-OORshadow"]       = { file = 6685874, left = 0.259766, right = 0.343750, top = 0.000977, bottom = 0.042969, width = 43,  height = 43 },

  -- The ready-flash sprite strip: 2 columns x 11 rows of 47px frames (ItemMixins:46). See the
  -- behaviour-change note in the header before touching this one.
  ["UI-HUD-ActionBar-GCD-Flipbook"]      = { file = 5199404, left = 0.412598, right = 0.458496, top = 0.393555, bottom = 0.898438, width = 94,  height = 517 },

  -- BuffBar fill, backing and the pip that rides the fill's right edge (AuraItemMixins:184-189).
  -- Registration alone; the nine-slice insets AtlasSlice.lua carries for these are §H.2 8d's
  -- business, and that phase is a visual judgement rather than a data one.
  ["UI-HUD-CoolDownManager-Bar"]         = { file = 6704514, left = 0.347656, right = 0.832031, top = 0.171875, bottom = 0.250000, width = 124, height = 10 },
  ["UI-HUD-CoolDownManager-Bar-BG"]      = { file = 6704514, left = 0.347656, right = 0.863281, top = 0.007812, bottom = 0.156250, width = 132, height = 19 },
  ["UI-HUD-CoolDownManager-Bar-Pip"]     = { file = 6704514, left = 0.347656, right = 0.386719, top = 0.265625, bottom = 0.625000, width = 10,  height = 46 },
})
