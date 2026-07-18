-- DragonUI_NewEra/modules/guild/Tabard.lua — the guild's tabard crest, rendered as a small badge
-- in the Roster tab's left column (Window.lua's GuildColumn).
--
-- DOWNPORT of NewEra/Guild/Tabard.lua. Two changes from the reference:
--
--   (1) NO CIRCULAR MASK. The reference clips the badge to a circle via
--       badge:CreateMaskTexture() + Texture:AddMaskTexture() — retail-only. core/Portrait.lua
--       already documents that CreateMaskTexture is EXPOSED but returns nil on 3.3.5a (masks are
--       non-functional here), which is exactly why every other portrait in this addon uses the
--       legacy Texture:SetMask(path) fallback instead. SetMask crops a texture to ONE shared alpha
--       image over that texture's own draw rect; applying it separately to 4 quadrant textures
--       would crop each quadrant to its OWN full circle rather than one shared circle arc, which
--       reads wrong. So the badge here is a plain SQUARE (still the real bg+emblem tabard art,
--       just not circle-cropped) — an honest simplification given the client's actual constraints,
--       not an attempt at the retail circular look.
--
--   (2) GetGuildTabardFiles() is UNCONFIRMED on this specific 3.3.5a build. The reference's header
--       comment cites "verified on Era 1.15.8" — a DIFFERENT client than this one, and grepping
--       every installed addon here (including the packed Blizzard_GuildBankUI.pub, which is the
--       stock consumer of this exact API on live clients) turned up no evidence either way. Every
--       call is guarded so a missing/nil-returning API just falls back to the static
--       GuildLogo-NoLogo crest — never an error.

local NE = DragonUI_NewEra
if not NE then return end

NE.guild = NE.guild or {}
local G = NE.guild

-- Each tabard layer (background, then emblem) is TWO half-images (Upper/Lower) that must be
-- mirrored left-right to reconstruct the full symmetric design — this is how Blizzard's own guild
-- bank tabard rendering works (Blizzard_GuildBankUI), not a masking detail, and the tile's actual
-- design lives in its RIGHT half (values transcribed verbatim from NewEra/Guild/Tabard.lua — a
-- Blizzard art-layout fact, unrelated to the API-existence uncertainty in this file's header).
-- TC_N = normal (right half), TC_M = the same half horizontally mirrored.
local TC_N, TC_M = { 0.5, 1, 0, 1 }, { 1, 0.5, 0, 1 }

-- A SQUARE tabard badge: two layers (background, then emblem on top), each a 2x2 mirrored grid.
-- No mask (see file header) — `size` is the badge's edge length.
function G.MakeTabardBadge(parent, size)
  local badge = CreateFrame("Frame", nil, parent)
  badge:SetSize(size, size)
  local half = size / 2

  local function layer(sublevel)
    local q = {}
    q.UL = badge:CreateTexture(nil, "ARTWORK", nil, sublevel); q.UL:SetSize(half, half)
    q.UL:SetPoint("TOPLEFT", badge, "TOPLEFT", 0, 0); q.UL:SetTexCoord(unpack(TC_N))
    q.UR = badge:CreateTexture(nil, "ARTWORK", nil, sublevel); q.UR:SetSize(half, half)
    q.UR:SetPoint("LEFT", q.UL, "RIGHT", 0, 0); q.UR:SetTexCoord(unpack(TC_M))
    q.BL = badge:CreateTexture(nil, "ARTWORK", nil, sublevel); q.BL:SetSize(half, half)
    q.BL:SetPoint("TOP", q.UL, "BOTTOM", 0, 0); q.BL:SetTexCoord(unpack(TC_N))
    q.BR = badge:CreateTexture(nil, "ARTWORK", nil, sublevel); q.BR:SetSize(half, half)
    q.BR:SetPoint("LEFT", q.BL, "RIGHT", 0, 0); q.BR:SetTexCoord(unpack(TC_M))
    return q
  end
  badge.Bg     = layer(1)
  badge.Emblem = layer(2)
  badge:Hide()
  return badge
end

-- Paint a badge from GetGuildTabardFiles() tiles; nil bgU → hide (no design / API missing).
function G.FillTabardBadge(badge, bgU, bgL, emU, emL)
  if not (badge and bgU) then if badge then badge:Hide() end return false end
  badge.Bg.UL:SetTexture(bgU);     badge.Bg.UR:SetTexture(bgU);     badge.Bg.BL:SetTexture(bgL);     badge.Bg.BR:SetTexture(bgL)
  badge.Emblem.UL:SetTexture(emU); badge.Emblem.UR:SetTexture(emU); badge.Emblem.BL:SetTexture(emL); badge.Emblem.BR:SetTexture(emL)
  badge:Show()
  return true
end

-- Wire the crest badge into the GuildColumn (Window.lua's left panel, Roster tab only). `crest` is
-- the static GuildLogo-NoLogo texture already sitting in the column — it's shown when there's no
-- real tabard design (guildless, API missing, or the design hasn't streamed in yet) and hidden
-- when the real badge fills successfully.
function G.SetupTabard(column)
  if not column or column._neTabard then return end
  column._neTabard = true

  local badge = G.MakeTabardBadge(column, column.CrestSize or 44)
  if column.Crest then
    badge:SetPoint("CENTER", column.Crest, "CENTER", 0, 0)
  end
  -- No explicit SetFrameLevel needed: `badge` is a CHILD FRAME of `column`, and column.Crest is a
  -- Texture REGION drawn directly on `column` itself (not its own frame) — a child frame's default
  -- level (parent+1) already draws above everything the parent owns directly, regardless of the
  -- texture's draw layer. (column.Crest:GetFrameLevel() would have errored: textures have no
  -- frame-level API, only frames do.)
  column.TabardBadge = badge

  G.EnsureTabardEvents()
  G.UpdateTabard()
end

-- Shared tabard-data event frame, created once regardless of whether the (lazily-built) guild
-- window / GuildColumn exist yet. GUILD_TABARD_UPDATE fires when the design streams in — guarded
-- with pcall since its existence on this build is exactly the thing this file can't confirm.
function G.EnsureTabardEvents()
  if G._tabardEv then return end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_GUILD_UPDATE")
  ev:RegisterEvent("GUILD_ROSTER_UPDATE")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(ev.RegisterEvent, ev, "GUILD_TABARD_UPDATE")
  ev:SetScript("OnEvent", function() G.UpdateTabard() end)
  G._tabardEv = ev
  if GuildRoster then pcall(GuildRoster) end   -- nudge the server; the design streams in async
end

function G.UpdateTabard()
  local f = G.frame
  local column = f and f.GuildColumn
  if not column then return end

  local inGuild = IsInGuild and IsInGuild()
  -- GetGuildTabardFiles() -> bgUpper, bgLower, emblemUpper, emblemLower (border tiles unused).
  -- pcall'd: this API's presence/shape on this specific 3.3.5a build is UNCONFIRMED (see file
  -- header) — a missing global or a differently-shaped return must fall back cleanly, not error.
  local bgU, bgL, emU, emL
  if inGuild and GetGuildTabardFiles then
    local ok, a, b, c, d = pcall(GetGuildTabardFiles)
    if ok then bgU, bgL, emU, emL = a, b, c, d end
  end
  local filled = (inGuild and emU) and true or false

  if column.TabardBadge then
    if filled then G.FillTabardBadge(column.TabardBadge, bgU, bgL, emU, emL)
    else column.TabardBadge:Hide() end
  end
  if column.Crest then column.Crest:SetShown(not filled) end

  -- The design streams in after login/guild-join, sometimes after our first paint — retry a few
  -- times so the badge fills once it arrives. A tabard-less guild (or a client that never sends
  -- it, or lacks the API at all) just exhausts the retries and keeps the static crest.
  if not filled and inGuild and (G._tabardTries or 0) < 6 and C_Timer and C_Timer.After then
    G._tabardTries = (G._tabardTries or 0) + 1
    C_Timer.After(1.5, G.UpdateTabard)
  elseif filled then
    G._tabardTries = 0
  end
end
