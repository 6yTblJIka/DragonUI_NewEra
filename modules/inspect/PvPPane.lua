-- DragonUI_NewEra/modules/inspect/PvPPane.lua — a modern PvP pane for the inspect window's PVP tab.
--
-- Replaces Blizzard's `InspectPVPFrame`, whose whole look is one 512x512 `UI-Character-PVP`
-- parchment plate with six numbers and three arena plates arranged on top of it. Fitted into a
-- modern frame that plate is the only thing left that still reads as 2007, and there is very little
-- data behind it — so this draws the same data on the window set's own furniture instead.
--
-- DATA (3.3.5a, verified against Blizzard_InspectUI/InspectPVPFrame.lua):
--   GetInspectHonorData()      -> todayHK, todayHonor, yesterdayHK, yesterdayHonor,
--                                 lifetimeHK, lifetimeRank
--   HasInspectHonorData() / RequestInspectHonorData() / event INSPECT_HONOR_UPDATE
--   GetInspectArenaTeamData(i) -> teamName, teamSize, teamRating, teamPlayed, teamWins,
--                                 playerPlayed, playerRating, bgR, bgG, bgB,
--                                 emblem, emR, emG, emB, border, brR, brG, brB
--   MAX_ARENA_TEAMS = 3, and the sizes are always 2 / 3 / 5.
--
-- The native pane is left loaded and simply never shown: it is what Blizzard's own event handlers
-- and the tab machinery drive, and its OnShow is what fires the honor request on this client.
--
-- 3.3.5a NOTES
--   * `GetInspectArenaTeamData` must be CALLED ONCE PER TEAM before the data is populated — the
--     native `InspectPVPFrame_Update` does exactly this priming loop, and dropping it leaves the
--     first read of a freshly-inspected unit empty.
--   * The bracket a unit has no team in still gets a row, dimmed, the way the native pane shows an
--     empty 2v2/3v3/5v5 plate — an absent team is information too.

local NE = DragonUI_NewEra
if not NE or NE.disabled then return end

NE.inspect = NE.inspect or {}
local I = NE.inspect
local L = NE.L

local BANNER_W     = 38      -- team standard, inside the row
local HEADING_H    = 22
local HONOR_H      = 110     -- rank line + the 3 x 2 table
local ROW_MIN_H    = 46      -- an arena bracket row never gets tighter than this
local GOLD         = { 1, 0.82, 0 }
local DIM          = { 0.6, 0.6, 0.6 }
local BRACKETS     = { 2, 3, 5 }

-- Every box in here is an inset with a BLACK ground, not a window onto the stone behind it: the
-- data is what should read, and the rock showing through a table of numbers is just noise. The
-- nineslice supplies the recessed border; this supplies the floor.
local function insetBox(box)
  if NE.nineslice and NE.nineslice.AttachInset then
    NE.nineslice.AttachInset(box, 0, 0, 0, 0)
  end
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT",     box, "TOPLEFT",      3, -3)
  bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3,  3)
  bg:SetTexture(0, 0, 0, 0.85)   -- DOWNPORT: colour args on SetTexture; no SetColorTexture here
  box.Bg = bg
  return bg
end

local function fs(parent, layer, font, r, g, b, justify)
  local t = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall")
  t:SetTextColor(r or 1, g or 1, b or 1)
  t:SetJustifyH(justify or "LEFT")
  return t
end

-- A section heading: gold caps on its own line, with a hairline under it.
local function heading(parent, text, anchorTo, y)
  local box = CreateFrame("Frame", nil, parent)
  box:SetHeight(HEADING_H)
  box:SetPoint("TOPLEFT",  anchorTo or parent, anchorTo and "BOTTOMLEFT" or "TOPLEFT", 0, y or 0)
  box:SetPoint("TOPRIGHT", anchorTo or parent, anchorTo and "BOTTOMRIGHT" or "TOPRIGHT", 0, y or 0)

  local label = fs(box, "OVERLAY", "GameFontNormalSmall", GOLD[1], GOLD[2], GOLD[3])
  label:SetPoint("LEFT", box, "LEFT", 2, 0)
  label:SetText(text)
  box.Label = label

  local rule = box:CreateTexture(nil, "ARTWORK")
  rule:SetHeight(1)
  rule:SetPoint("LEFT",  label, "RIGHT", 6, 0)
  rule:SetPoint("RIGHT", box, "RIGHT", -2, 0)
  rule:SetTexture(1, 1, 1)          -- DOWNPORT: colour args, not SetColorTexture
  rule:SetVertexColor(1, 0.82, 0, 0.25)
  box.Rule = rule

  return box
end

-- ----------------------------------------------------------------------------
-- Build.
-- ----------------------------------------------------------------------------
local function buildHonor(pane, below)
  local box = CreateFrame("Frame", nil, pane)
  box:SetPoint("TOPLEFT",  below, "BOTTOMLEFT",  0, -6)
  box:SetPoint("TOPRIGHT", below, "BOTTOMRIGHT", 0, -6)
  box:SetHeight(HONOR_H)
  insetBox(box)

  -- The rank, across the top: badge and name on one line rather than stacked, so the table below
  -- gets the full width of the box and the two never fight over the left column.
  local badge = box:CreateTexture(nil, "ARTWORK")
  badge:SetWidth(28); badge:SetHeight(30)
  badge:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -6)
  pane.Badge = badge

  -- The badge index is the SECOND return of GetPVPRankInfo, zero-padded — the same art and the
  -- same lookup DragonUI's own honor tab uses.
  local rank = fs(box, "OVERLAY", "GameFontNormalSmall", GOLD[1], GOLD[2], GOLD[3])
  rank:SetPoint("LEFT", badge, "RIGHT", 6, 0)
  rank:SetPoint("RIGHT", box, "RIGHT", -10, 0)
  pane.RankName = rank

  -- The 3 x 2 table under it. Columns are laid out from the RIGHT edge so the numbers stay aligned
  -- however wide the labels get in another locale, and the label column is what is left over.
  local COL_W, LABEL_X = 66, 12
  local cols = { HONOR_TODAY or "Today", HONOR_YESTERDAY or "Yesterday", HONOR_LIFETIME or "Lifetime" }
  pane.Cells = {}
  for c = 1, 3 do
    local head = fs(box, "OVERLAY", "GameFontNormalSmall", DIM[1], DIM[2], DIM[3], "CENTER")
    head:SetWidth(COL_W)
    head:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8 - (3 - c) * COL_W, -44)
    head:SetText(cols[c])

    for r = 1, 2 do
      local cell = fs(box, "OVERLAY", "GameFontHighlightSmall", 1, 1, 1, "CENTER")
      cell:SetWidth(COL_W)
      cell:SetPoint("TOP", head, "BOTTOM", 0, -6 - (r - 1) * 20)
      pane.Cells[(r - 1) * 3 + c] = cell
    end
  end

  -- Short labels on purpose: HONORABLE_KILLS ("Honorable Kills") is wider than the space the three
  -- columns leave, and ran under the Today column. The native pane labels these rows the same way.
  local rowLabels = { L["Kills"], HONOR or L["Honor"] }
  for r = 1, 2 do
    local lab = fs(box, "OVERLAY", "GameFontNormalSmall", DIM[1], DIM[2], DIM[3])
    lab:SetPoint("LEFT", box, "LEFT", LABEL_X, 0)
    lab:SetPoint("TOP", pane.Cells[(r - 1) * 3 + 1], "TOP", 0, 0)
    lab:SetText(rowLabels[r])
  end

  return box
end

local function buildTeamRow(pane, index, below, rowH)
  local row = CreateFrame("Frame", nil, pane)
  row:SetHeight(rowH)
  row:SetPoint("TOPLEFT",  below, "BOTTOMLEFT",  0, index == 1 and -6 or -4)
  row:SetPoint("TOPRIGHT", below, "BOTTOMRIGHT", 0, index == 1 and -6 or -4)
  insetBox(row)

  -- The team standard: Blizzard's own three-piece banner (background tint, border, emblem).
  local banner = row:CreateTexture(nil, "ARTWORK")
  banner:SetWidth(BANNER_W); banner:SetHeight(rowH - 8)
  banner:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.Banner = banner

  local border = row:CreateTexture(nil, "ARTWORK", nil, 1)
  border:SetAllPoints(banner)
  row.Border = border

  local emblem = row:CreateTexture(nil, "OVERLAY")
  emblem:SetWidth(20); emblem:SetHeight(20)
  emblem:SetPoint("CENTER", banner, "CENTER", 0, 2)
  row.Emblem = emblem

  local name = fs(row, "OVERLAY", "GameFontNormal")
  name:SetPoint("TOPLEFT", banner, "TOPRIGHT", 8, -6)
  name:SetPoint("RIGHT", row, "RIGHT", -70, 0)
  row.Name = name

  local record = fs(row, "OVERLAY", "GameFontHighlightSmall", DIM[1], DIM[2], DIM[3])
  record:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
  row.Record = record

  local rating = fs(row, "OVERLAY", "GameFontNormalLarge", GOLD[1], GOLD[2], GOLD[3], "RIGHT")
  rating:SetPoint("RIGHT", row, "RIGHT", -10, 6)
  rating:SetWidth(60)
  row.Rating = rating

  local ratingLabel = fs(row, "OVERLAY", "GameFontNormalSmall", DIM[1], DIM[2], DIM[3], "RIGHT")
  ratingLabel:SetPoint("TOPRIGHT", rating, "BOTTOMRIGHT", 0, -1)
  ratingLabel:SetWidth(60)
  ratingLabel:SetText(RATING or L["Rating"])
  row.RatingLabel = ratingLabel

  return row
end

local function build()
  local f = _G.InspectFrame
  local inset = f and I.EnsureInset and I.EnsureInset(f)
  if not inset or I.pvp then return I.pvp end

  local pane = CreateFrame("Frame", "NE_InspectPVPFrame", f)
  pane:SetPoint("TOPLEFT",     inset, "TOPLEFT",     6, -6)
  pane:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)
  pane:SetFrameLevel((f:GetFrameLevel() or 1) + (I.SUBFRAME_LEVEL or 10))
  pane:Hide()

  local honorHead = heading(pane, HONOR or L["Honor"], nil, 0)
  -- The faction crest, on the inspected unit's side rather than the player's — the native pane
  -- reads UnitFactionGroup("player") here, which is simply a bug when you inspect the other side.
  local crest = pane:CreateTexture(nil, "OVERLAY")
  crest:SetWidth(20); crest:SetHeight(20)
  crest:SetPoint("RIGHT", honorHead, "RIGHT", -2, 0)
  pane.Crest = crest
  honorHead.Rule:SetPoint("RIGHT", crest, "LEFT", -6, 0)

  local honorBox = buildHonor(pane, honorHead)
  local arenaHead = heading(pane, ARENA or L["Arena"], honorBox, -10)

  -- The three bracket rows share out whatever is left, so the block fills the tab instead of
  -- stopping two thirds of the way down. (pane = interior less its 6px margins.)
  local _, interiorH = I.InteriorSize()   -- computed, not measured (see I.InteriorSize)
  local paneH = interiorH - 12
  local spare = paneH - (HEADING_H + 6 + HONOR_H + 10 + HEADING_H + 6 + 4 + 4)
  local rowH  = math.max(ROW_MIN_H, math.floor(spare / #BRACKETS))

  pane.Rows = {}
  local below = arenaHead
  for i = 1, #BRACKETS do
    pane.Rows[i] = buildTeamRow(pane, i, below, rowH)
    below = pane.Rows[i]
  end

  I.pvp = pane
  return pane
end

-- ----------------------------------------------------------------------------
-- Data.
-- ----------------------------------------------------------------------------
local function num(v)
  if not v or v == 0 then return "0" end
  return tostring(v)
end

local function refreshHonor(pane, unit)
  local todayHK, todayHonor, yesterdayHK, yesterdayHonor, lifetimeHK, lifetimeRank
  if GetInspectHonorData then
    todayHK, todayHonor, yesterdayHK, yesterdayHonor, lifetimeHK, lifetimeRank = GetInspectHonorData()
  end

  local cells = pane.Cells
  cells[1]:SetText(num(todayHK));      cells[2]:SetText(num(yesterdayHK)); cells[3]:SetText(num(lifetimeHK))
  cells[4]:SetText(num(todayHonor));   cells[5]:SetText(num(yesterdayHonor))
  -- Lifetime honor is not transmitted for an inspected unit (the native pane leaves it blank too).
  cells[6]:SetText("|cff808080--|r")

  local rankName, rankNumber
  if lifetimeRank and lifetimeRank > 0 and GetPVPRankInfo then
    rankName, rankNumber = GetPVPRankInfo(lifetimeRank)
  end
  pane.RankName:SetText(rankName or L["Unranked"])
  if rankNumber and tonumber(rankNumber) and tonumber(rankNumber) > 0 then
    pane.Badge:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", tonumber(rankNumber)))
    pane.Badge:Show()
  else
    pane.Badge:Hide()
  end

  local faction = unit and UnitFactionGroup and UnitFactionGroup(unit)
  if faction and (faction == "Alliance" or faction == "Horde") then
    pane.Crest:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
    pane.Crest:Show()
  else
    pane.Crest:Hide()
  end
end

local function refreshArena(pane)
  -- Prime the client's inspect-arena cache first: the native pane calls this same loop before it
  -- reads anything, and without it the first read after an inspect comes back empty.
  if GetInspectArenaTeamData then
    for i = 1, (MAX_ARENA_TEAMS or 3) do GetInspectArenaTeamData(i) end
  end

  -- Teams arrive in team-index order, not bracket order; map them onto the 2/3/5 rows.
  local bySize = {}
  if GetInspectArenaTeamData then
    for i = 1, (MAX_ARENA_TEAMS or 3) do
      local teamName, teamSize, teamRating, teamPlayed, teamWins,
            playerPlayed, playerRating, bgR, bgG, bgB,
            emblem, emR, emG, emB, border, brR, brG, brB = GetInspectArenaTeamData(i)
      if teamSize and teamName and teamName ~= "" then
        bySize[teamSize] = {
          name = teamName, rating = teamRating or 0,
          played = teamPlayed or 0, wins = teamWins or 0,
          personal = playerRating or 0,
          bg = { bgR, bgG, bgB }, emblem = emblem, em = { emR, emG, emB },
          border = border, br = { brR, brG, brB },
        }
      end
    end
  end

  for i, size in ipairs(BRACKETS) do
    local row  = pane.Rows[i]
    local team = bySize[size]

    row.Banner:SetTexture("Interface\\PVPFrame\\PVP-Banner-" .. size)

    if team then
      row:SetAlpha(1)
      row.Banner:SetVertexColor(team.bg[1] or 1, team.bg[2] or 1, team.bg[3] or 1)
      if team.border and team.border ~= -1 then
        row.Border:SetTexture("Interface\\PVPFrame\\PVP-Banner-" .. size .. "-Border-" .. team.border)
        row.Border:SetVertexColor(team.br[1] or 1, team.br[2] or 1, team.br[3] or 1)
        row.Border:Show()
      else
        row.Border:Hide()
      end
      if team.emblem and team.emblem ~= -1 then
        row.Emblem:SetTexture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-" .. team.emblem)
        row.Emblem:SetVertexColor(team.em[1] or 1, team.em[2] or 1, team.em[3] or 1)
        row.Emblem:Show()
      else
        row.Emblem:Hide()
      end

      row.Name:SetText(team.name)
      row.Name:SetTextColor(1, 1, 1)
      row.Record:SetText(string.format("%dv%d   %d - %d", size, size, team.wins, team.played - team.wins))
      row.Rating:SetText(tostring(team.rating))
      row.RatingLabel:Show()
    else
      -- No team in this bracket: the row stays, dimmed, naming the bracket. An absent team is
      -- information — it is how the native pane shows an empty plate, and it keeps the three
      -- brackets in the same place whoever you inspect.
      row:SetAlpha(0.45)
      row.Banner:SetVertexColor(0.35, 0.35, 0.35)
      row.Border:Hide()
      row.Emblem:Hide()
      row.Name:SetText(string.format("%dv%d", size, size))
      row.Name:SetTextColor(DIM[1], DIM[2], DIM[3])
      row.Record:SetText(L["No team"])
      row.Rating:SetText("")
      row.RatingLabel:Hide()
    end
  end
end

function I.RefreshPvP()
  local pane = I.pvp
  local f = _G.InspectFrame
  if not (pane and pane:IsShown() and f) then return end
  refreshHonor(pane, f.unit)
  refreshArena(pane)
end

-- ----------------------------------------------------------------------------
-- Take over the PVP tab.
--
-- The native FRAME keeps running — Blizzard's tab machinery shows and hides it, its OnShow is what
-- fires the honor request on this client, and its OnEvent is what keeps the client's inspect-honor
-- cache fresh. Only its CONTENT goes: every region and child is hidden, and their `Show` is
-- neutered, because `InspectPVPTeam_Update` re-shows the team plates on every honor tick.
--
-- Hiding the frame itself instead was the obvious move and is wrong: `InspectSwitchTabs` hides the
-- outgoing pane, and `Hide()` on an already-hidden frame fires no OnHide — so ours would have been
-- left on screen over the paperdoll on the way back to tab 1.
-- ----------------------------------------------------------------------------
local function squelch(obj)
  if not obj or obj._neSquelched then return end
  obj._neSquelched = true
  if obj.Hide then obj:Hide() end
  obj.Show = obj.Hide   -- render-proof: the native update re-shows these whenever honor data lands
end

local function squelchNative(native)
  for _, r in ipairs({ native:GetRegions() }) do squelch(r) end
  for _, c in ipairs({ native:GetChildren() }) do squelch(c) end
end

function I.ApplyPvPPane()
  local native = _G.InspectPVPFrame
  if not native or native._nePaneWired then return end
  local pane = build()
  if not pane then return end
  native._nePaneWired = true

  squelchNative(native)

  native:HookScript("OnShow", function()
    pane:Show()
    if not (HasInspectHonorData and HasInspectHonorData()) and RequestInspectHonorData then
      RequestInspectHonorData()
    end
    I.RefreshPvP()
  end)
  native:HookScript("OnHide", function() pane:Hide() end)
  if native:IsShown() then pane:Show(); I.RefreshPvP() end

  -- Retargeting reuses the open window: InspectFrame_UnitChanged re-notifies and the new unit's
  -- data lands asynchronously, so both the hook and the arrival event drive a refresh.
  if type(_G.InspectFrame_UnitChanged) == "function" then
    hooksecurefunc("InspectFrame_UnitChanged", function()
      if RequestInspectHonorData then RequestInspectHonorData() end
      I.RefreshPvP()
    end)
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("INSPECT_HONOR_UPDATE")
  ev:RegisterEvent("INSPECT_TALENT_READY")   -- 3.3.5a's only "inspect data arrived" signal
  ev:SetScript("OnEvent", function() I.RefreshPvP() end)
end
