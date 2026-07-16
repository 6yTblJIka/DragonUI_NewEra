-- DragonUI_NewEra/modules/guild/Assets.lua — Guild panel art registration.
--
-- DOWNPORT of NewEra/Guild/Assets.lua. Two differences from the reference:
--   (1) BLP paths point at OUR addon (Textures\Guild\...), and
--   (2) the atlas-name → texcoord rects NewEra read from its generated NE_ATLAS global are
--       TRANSCRIBED here into NE.tex.atlases via NE.tex.RegisterAtlases (the 3.3.5a client has
--       no native atlas DB; same convention as modules/character/Assets.lua + Professions/Assets.lua).
--
-- Source coord rects transcribed verbatim from NewEra/Generated/AtlasData.lua (build 12.0.5.67451):
--   communities-guildbanner-background -> AtlasData.lua:2830
--   communities-guildbanner-border     -> AtlasData.lua:2831
--   voicechat-icon-headphone-on        -> AtlasData.lua:15894
--
-- Load order: BEFORE Window.lua / Roster.lua (any NE.tex.SetAtlas on these sheets). Shared chrome
-- (rock body, UI-Frame metal nineslice, InsetFrame inner-border, tab sheet, minimal scrollbar,
-- GuildFrame parchment — a native 3.3.5a path) is NOT re-registered here; it lives in Core.

local NE = DragonUI_NewEra
if not (NE and NE.tex and NE.tex.RegisterLocal) then return end

local P = "Interface\\AddOns\\DragonUI_NewEra\\Textures\\Guild\\"

-- ============================================================================
-- 1. fdid → shipped BLP path  (NE.tex.RegisterLocal)
-- ============================================================================

-- 1981967 — Communities atlas sheet. Holds communities-guildbanner-background / -border, the
-- guild-banner plate drawn behind a guild-list entry's emblem. Extracted build-pinned 12.0.5.67451.
--
-- CURRENTLY UNUSED (owner removed the left guild column 2026-07-16 — the banner plate was its only
-- consumer). Registration is kept because it costs nothing at runtime: the BLP is only streamed if
-- something actually calls NE.tex.SetAtlas on one of these names, and it's the art a future guild
-- tabard/crest badge would want. If no such feature lands, drop this line AND
-- Textures/Guild/1981967-communities.blp (~525KB) together.
NE.tex.RegisterLocal(1981967, P .. "1981967-communities.blp")

-- 1677861 — voicechat icon sheet (voicechat-icon-headphone-on etc.) for the guild-chat headset
-- button. 1:1 visual parity only — voice chat is non-functional on 3.3.5a.
NE.tex.RegisterLocal(1677861, P .. "1677861-voicechat-icons.blp")

-- ============================================================================
-- 2. atlas-name → texcoord rect  (NE.tex.RegisterAtlases)
-- ============================================================================

NE.tex.RegisterAtlases({
  ["communities-guildbanner-background"] = { file = 1981967, left = 0.926758, right = 0.999023, top = 0.001953, bottom = 0.136719, width = 74, height = 69 },
  ["communities-guildbanner-border"]     = { file = 1981967, left = 0.601562, right = 0.673828, top = 0.480469, bottom = 0.615234, width = 74, height = 69 },
  ["voicechat-icon-headphone-on"]        = { file = 1677861, left = 0.169922, right = 0.294922, top = 0.269531, bottom = 0.519531, width = 64, height = 64 },
})
