-- DragonUI_NewEra/modules/cooldownviewer/SettingsCategories.lua — the collapsible category sections
-- inside the /cdm panel's scroll body. Downport of NewEra/CooldownViewerSettings/Categories.lua.
--
-- Each category is a header over a grid: icon categories are a 7-wide grid of 38x38 tiles (8px pad,
-- so 46px pitch), the bar category a single column of 317x38 rows (10px pad, 48px pitch). Those
-- numbers are upstream's, probe-confirmed against retail, and are kept exactly.
--
-- DOWNPORT: upstream builds its header with NE.listheader.Build, a Core helper this addon does not
-- have. Built inline here instead — the same substitution modules/character/Reputation.lua made for
-- the same missing helper, using the client's own +/- buttons for the collapse affordance.
--
-- Phase 4b-2 renders and tooltips. Clicking is wired but inert: the context menu that moves, hides
-- and assigns alerts arrives in 4b-3 through CDS.OnItemClick, which this file calls and that file
-- provides.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

local CDS = NE.cooldownviewersettings
local Adapter = CDS.adapter

local ICON, PAD = 38, 8
local PITCH  = ICON + PAD          -- 46
local STRIDE = 7
local CAT_W  = 344
local CAT_GAP = 18
local CONTAINER_X, CONTAINER_Y = 13, -15
local HEADER_H = 26
local BAR_W, BAR_H, BAR_PITCH = 317, 38, 48

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- ── Item tiles ──────────────────────────────────────────────────────────────────────────────────

-- Unlearned entries stay listed but read as unavailable: the Hidden catalog deliberately shows the
-- whole arsenal, so a low-level character can see what they will be able to track.
local function applyLearnedTint(item)
  local known = (not M.IsTrackable) or M.IsTrackable(item.spellID)
  item._unlearned = not known
  if item._unlearned then
    item.Icon:SetDesaturated(true)
    item.Icon:SetVertexColor(1.0, 0.4, 0.4)
  else
    item.Icon:SetDesaturated(false)
    item.Icon:SetVertexColor(1, 1, 1)
  end
end

local function itemOnEnter(self)
  if not self.spellID then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if M.TooltipSetSpell then M.TooltipSetSpell(GameTooltip, self.spellID) end
  if self._unlearned then
    GameTooltip:AddLine("Not yet learned", 1, 0.3, 0.3)
  end
  GameTooltip:Show()
end

local function itemOnLeave() GameTooltip:Hide() end

local function itemOnClick(self, button)
  if CDS.OnItemClick then CDS.OnItemClick(self, button) end
end

local function wireItem(b)
  b:SetScript("OnEnter", itemOnEnter)
  b:SetScript("OnLeave", itemOnLeave)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", itemOnClick)
end

local function makeIconItem(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(ICON, ICON)

  b.Icon = b:CreateTexture(nil, "ARTWORK")
  b.Icon:SetAllPoints()
  b.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- same crop the live viewer uses

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  hl:SetBlendMode("ADD")

  function b:SetSpell(spellID)
    self.spellID = spellID
    local name, _, icon = GetSpellInfo(spellID)
    self.spellName = name
    self.Icon:SetTexture(icon or QUESTION_MARK)
    applyLearnedTint(self)
  end

  wireItem(b)
  return b
end

local function makeBarItem(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(BAR_W, BAR_H)

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(0, 0, 0, 0.35)

  b.Icon = b:CreateTexture(nil, "ARTWORK")
  b.Icon:SetSize(BAR_H - 4, BAR_H - 4)
  b.Icon:SetPoint("LEFT", b, "LEFT", 2, 0)
  b.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  b.Label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.Label:SetPoint("LEFT", b.Icon, "RIGHT", 8, 0)
  b.Label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  b.Label:SetJustifyH("LEFT")

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  hl:SetBlendMode("ADD")

  function b:SetSpell(spellID)
    self.spellID = spellID
    local name, _, icon = GetSpellInfo(spellID)
    self.spellName = name
    self.Icon:SetTexture(icon or QUESTION_MARK)
    self.Label:SetText(name or ("Spell " .. tostring(spellID)))
    applyLearnedTint(self)
  end

  wireItem(b)
  return b
end

-- ── Category section ────────────────────────────────────────────────────────────────────────────

-- Inline collapsible header. NE.listheader does not exist here; this is the same substitution
-- modules/character/Reputation.lua makes, with the client's own +/- collapse buttons.
local function makeHeader(parent, onToggle)
  local h = CreateFrame("Button", nil, parent)
  h:SetHeight(HEADER_H)

  local bg = h:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(1, 1, 1, 0.06)

  h.Toggle = h:CreateTexture(nil, "ARTWORK")
  h.Toggle:SetSize(16, 16)
  h.Toggle:SetPoint("LEFT", h, "LEFT", 4, 0)

  h.Text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h.Text:SetPoint("LEFT", h.Toggle, "RIGHT", 4, 0)

  h.Count = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  h.Count:SetPoint("RIGHT", h, "RIGHT", -6, 0)

  h:SetScript("OnClick", onToggle)

  function h:SetExpanded(on)
    self.Toggle:SetTexture(on and "Interface\\Buttons\\UI-MinusButton-Up"
                              or  "Interface\\Buttons\\UI-PlusButton-Up")
  end
  return h
end

local function makeCategory(parent, kind)
  local c = CreateFrame("Frame", nil, parent)
  c:SetWidth(CAT_W)
  c.kind = kind
  c._factory = (kind == "bar") and makeBarItem or makeIconItem
  c.items = {}
  c._expanded = true
  c._count = 0

  c.header = makeHeader(c, function() c:Toggle() end)
  c.header:SetPoint("TOPLEFT")
  c.header:SetPoint("TOPRIGHT")

  c.container = CreateFrame("Frame", nil, c)
  c.container:SetPoint("TOPLEFT", c.header, "BOTTOMLEFT", CONTAINER_X, CONTAINER_Y)
  c.container:SetWidth(kind == "bar" and BAR_W or (STRIDE * PITCH - PAD))

  c.empty = c:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  c.empty:SetPoint("TOPLEFT", c.container, "TOPLEFT", 2, -2)
  c.empty:SetText("(empty)")
  c.empty:Hide()

  function c:Relayout()
    local n = self._count
    local contH
    if self.kind == "bar" then
      contH = (n > 0) and (n * BAR_PITCH - (BAR_PITCH - BAR_H)) or 0
    else
      local rows = math.ceil(n / STRIDE)
      contH = (rows > 0) and (rows * PITCH - PAD) or 0
    end
    if n == 0 then contH = 14 end
    self.container:SetHeight(math.max(1, contH))

    if self._expanded then self.container:Show() else self.container:Hide() end
    if n == 0 and self._expanded then self.empty:Show() else self.empty:Hide() end

    for i, item in ipairs(self.items) do
      if i <= n and self._expanded then
        item:ClearAllPoints()
        if self.kind == "bar" then
          item:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -(i - 1) * BAR_PITCH)
        else
          local col, row = (i - 1) % STRIDE, math.floor((i - 1) / STRIDE)
          item:SetPoint("TOPLEFT", self.container, "TOPLEFT", col * PITCH, -row * PITCH)
        end
        item:Show()
      else
        item:Hide()
      end
    end

    self.header:SetExpanded(self._expanded)
    self:SetHeight(HEADER_H + (self._expanded and (math.abs(CONTAINER_Y) + self.container:GetHeight()) or 0))
  end

  function c:Toggle()
    self._expanded = not self._expanded
    self:Relayout()
    if CDS.RestackCategories then CDS.RestackCategories() end
  end

  -- Fill from a list of spellIDs. Tiles are pooled: the pool only ever grows, and surplus tiles are
  -- hidden by Relayout rather than destroyed.
  function c:SetItems(ids)
    self._count = #ids
    for i, id in ipairs(ids) do
      local item = self.items[i]
      if not item then
        item = self._factory(self.container)
        self.items[i] = item
      end
      item._catID = self._catID
      item:SetSpell(id)
    end
    self.header.Count:SetText(tostring(#ids))
    self:Relayout()
  end

  return c
end

-- ── Panel wiring ────────────────────────────────────────────────────────────────────────────────

local categories = {}   -- catID -> frame

-- Stack the visible sections top-down and size the scroll child to match, so the scrollbar knows
-- how far it can go.
function CDS.RestackCategories()
  local panel = CDS.panel
  if not panel then return end

  local mode = CDS.GetDisplayMode() or "spells"
  local y = 0
  local prev
  for _, catID in ipairs(Adapter.MODE_ORDER[mode] or {}) do
    local c = categories[catID]
    if c and c._active then
      c:ClearAllPoints()
      if prev then
        c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -CAT_GAP)
      else
        c:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, 0)
      end
      c:Show()
      y = y + c:GetHeight() + CAT_GAP
      prev = c
    end
  end
  panel.content:SetHeight(math.max(1, y))
end

function CDS.RefreshLayout()
  local panel = CDS.panel
  if not panel then return end
  if panel.placeholder then panel.placeholder:Hide() end

  local _, class = UnitClass("player")
  local mode = CDS.GetDisplayMode() or "spells"

  -- Deactivate everything first, so a category that belongs to the other tab can't linger.
  for _, c in pairs(categories) do c._active = false; c:Hide() end

  for _, catID in ipairs(Adapter.MODE_ORDER[mode] or {}) do
    local c = categories[catID]
    if not c then
      c = makeCategory(panel.content, Adapter.Kind(catID))
      c._catID = catID
      c.header.Text:SetText(Adapter.Label(catID))
      categories[catID] = c
    end
    c._active = true
    c:SetItems(Adapter.GetItems(catID, class))
  end

  CDS.RestackCategories()
  if CDS.ApplyItemFilter and panel.search then CDS.ApplyItemFilter(panel.search:GetText()) end
end

-- Search DIMS non-matching tiles rather than reflowing the grid — retail's behaviour, and it keeps
-- an item's position stable while you type.
function CDS.ApplyItemFilter(text)
  text = (text or ""):lower()
  local blank = (text == "")
  for _, c in pairs(categories) do
    if c._active then
      for i, item in ipairs(c.items) do
        if i <= c._count then
          local match = blank or ((item.spellName or ""):lower():find(text, 1, true) ~= nil)
          item:SetAlpha(match and 1 or 0.25)
        end
      end
    end
  end
end

CDS._categories = categories   -- test seam
