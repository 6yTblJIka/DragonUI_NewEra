-- DragonUI_NewEra/modules/cooldownviewer/SettingsAssets.lua — art for the /cdm settings panel.
--
-- Two sheets, one shipped here and one already on disk:
--
--   7289697 (Interface\CDM\CDMAdvanced) — the side-tab GLYPHS. TWW-era art this client's data has
--     no entry for, so it must ship as a local BLP copy or SetAtlas renders nothing.
--   5684744 (questlog)                  — the side-tab BODY and its hover/selected glows, used by
--     NE.tabs.MakeSideTab. Already shipped by modules/spellbook/Assets.lua for its cog icon; only
--     the rects were missing, so this file adds them.
--
-- That second point corrects a stale note in core/Tabs.lua, which said the questlog-tab-side*
-- atlases live on "a different (not-yet-shipped) sheet". They do not — they are on 5684744, the
-- same sheet the spellbook already ships. MakeSideTab has therefore been rendering transparent
-- everywhere for want of three rects, not for want of art.
--
-- Rects transcribed verbatim from NewEra/Generated/AtlasData.lua, except the two CDM glyphs, whose
-- coords come from the reference CooldownViewerSettings/Assets.lua — that file re-derives them
-- because retail 12.1.0 REPACKED this sheet, so the Era-pinned generated rects are wrong for the
-- BLP we ship. We ship the 12.1.0 BLP, so we use the 12.1.0 coords.

local NE = DragonUI_NewEra
if not (NE and NE.tex and NE.tex.RegisterLocal) then return end

NE.tex.RegisterLocal(7289697,
  "Interface\\AddOns\\DragonUI_NewEra\\Textures\\CooldownViewerSettings\\7289697-cdmadvanced.blp")

NE.tex.RegisterAtlases({
  -- Side-tab body + states (sheet 5684744, registered by modules/spellbook/Assets.lua).
  ["questlog-tab-side"]             = { file = 5684744, left = 0.105469, right = 0.205078, top = 0.396484, bottom = 0.513672, width = 51, height = 60 },
  ["questlog-tab-side-glow-hover"]  = { file = 5684744, left = 0.001953, right = 0.101562, top = 0.396484, bottom = 0.513672, width = 51, height = 60 },
  ["questlog-tab-side-glow-select"] = { file = 5684744, left = 0.001953, right = 0.101562, top = 0.578125, bottom = 0.695312, width = 51, height = 60 },

  -- CDM side-tab glyphs (sheet 7289697, 512x128). icon_buffreorder is deliberately absent: it
  -- belongs to the Group Buffs tab, which this port does not have (PORT_PLAN §G.4).
  ["icon_cooldownmanager"] = { file = 7289697, left = 0.330078, right = 0.455078, top = 0.085938, bottom = 0.585938, width = 32, height = 32 },
  ["icon_trackedbuffs"]    = { file = 7289697, left = 0.201172, right = 0.326172, top = 0.007813, bottom = 0.507813, width = 32, height = 32 },
})
