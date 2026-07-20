-- DragonUI_NewEra/modules/encounterjournal/EncounterPage.lua — the encounter view, data-driven
-- from NE.ej.DATA. Left lore/instance panel + right full-width info panel (book bg + info tabs
-- + boss list + per-boss content).
--
-- DOWNPORT of NewEra/EncounterJournal/EncounterPage.lua (Classic 1.15) onto 3.3.5a:
--   * ModelScene → gone (Cata+ widget). The PlayerModel FALLBACK path is now the PRIMARY:
--     boss models load via Model:SetCreature(displayID) (proven on this client by
--     ezCollections; NOT SetDisplayInfo — on this custom client that method takes a raw
--     model M2 FileID, not a creatureDisplayID, per WeakAuras' own compat shim, so calling
--     it with a displayID silently "succeeds" while rendering nothing). The retail
--     auto-fit camera (SetPortraitZoom / SetCameraPosition — none exist here) is emulated by
--     offsetting the MODEL from the fixed default camera using the generated per-boss
--     MODEL_CAM table (cdist/ctz), with MODEL_TWEAKS + tunable globals for outliers.
--   * Drag-rotate: Era's Model_OnMouseDown/_OnUpdate handlers don't exist on 3.3.5a — a small
--     cursor-delta OnUpdate drives Model:SetFacing instead.
--   * Dropdowns (loot slot filter + TBC Normal/Heroic): WowStyle1 DropdownButton →
--     NE.ej.CreateDropdown (Support.lua).
--   * SetShown → Show/Hide (3.3.5a hard rule); Button:SetEnabled → Enable/Disable.
--   * All UIPanelScrollFrameTemplate frames are NAMED (template OnLoad does _G name lookups).
--   * Loot rows: NE_EncounterItemTemplate XML (mixin attr is Legion+) → NE.ej.CreateLootRow.
--   * GET_ITEM_INFO_RECEIVED doesn't fire on 3.3.5a → uncached loot is primed via a hidden
--     tooltip (server item query) and the visible list re-renders on a short C_Timer poll.
--   * "Defeated this week": GetSavedInstanceEncounterInfo is Cata+ → feature degrades to off
--     (guarded); checkmark art = native ReadyCheck-Ready (no map-markeddefeated atlas here).
--   * "Show Map": 3.3.5a has no dungeon maps for Classic/TBC instances (WotLK-only) and no
--     WorldMapFrame:SetMapID — the button is hidden unless a NE.worldmap.ShowDungeonMap
--     provider appears later (guarded call kept).
--   * GetSpellTexture(spellID) can't resolve arbitrary ids on 3.3.5a → select(3, GetSpellInfo).
--
-- Layout transcribed from retail Cata Blizzard_EncounterJournal.xml:1307-1610 (12.0.5.67451).

local NE = DragonUI_NewEra
if not NE then return end

NE.ej = NE.ej or {}

local selInst, selBoss   -- module state: current instance + boss tables

-- 3.3.5a: no Region:SetShown.
local function setShown(o, on)
  if on then o:Show() else o:Hide() end
end

-- GameFontBlack may be absent on 3.3.5a; dark parchment color is set explicitly at use sites.
local BLACK_FONT = _G.GameFontBlack and "GameFontBlack" or "GameFontHighlightSmall"

local function sliceTex(parent, slice, layer, setSize)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  NE.ej.ApplySlice(t, slice, setSize)
  return t
end

local function makeTab(parent, id, iconSel, iconUnsel, tip)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(63, 57)
  local n = sliceTex(t, "UI-EJ-Tab-UnSelected"); n:SetAllPoints(t); t:SetNormalTexture(n)
  local h = sliceTex(t, "UI-EJ-Tab-Highlight");  h:SetAllPoints(t); h:SetBlendMode("ADD"); t:SetHighlightTexture(h)
  t.selBG = sliceTex(t, "UI-EJ-Tab-Selected", "ARTWORK"); t.selBG:SetAllPoints(t); t.selBG:Hide()
  t.unselIcon = sliceTex(t, iconUnsel, "OVERLAY", true); t.unselIcon:SetPoint("RIGHT", t, "RIGHT", -6, 0)
  t.selIcon   = sliceTex(t, iconSel,   "OVERLAY", true); t.selIcon:SetPoint("CENTER", t.unselIcon, "CENTER", 0, 0); t.selIcon:Hide()
  t.tabID = id
  t:SetScript("OnClick", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN) end
    NE.ej.SelectTab(id)
  end)
  if tip then
    NE.tooltip.Wire(t, tip)
  end
  return t
end

-- Left lore/instance panel (the instance landing on the right page)
local function buildLorePanel(enc)
  local p = CreateFrame("Frame", "NE_EncounterJournalInstanceFrame", enc)
  p:SetSize(390, 425)
  p:SetPoint("BOTTOMRIGHT", enc, "BOTTOMRIGHT", -1, 2)
  enc.instance = p

  -- Loading-screen artwork at the TOP (per-instance LoreFileDataID set in PopulateEncounter).
  local loreBG = p:CreateTexture(nil, "BACKGROUND")
  loreBG:SetTexture(NE.tex.localFiles[527422] or 527422)   -- UI-EJ-LOREBG-Default placeholder
  loreBG:SetSize(390, 330)
  loreBG:SetPoint("TOP", p, "TOP", 3, -9)
  loreBG:SetTexCoord(0, 0.7617187, 0, 0.65625)   -- retail crop (same for default + per-instance)
  p.loreBG = loreBG

  -- Name plate + dungeon name near the TOP of the artwork.
  local titleBG = sliceTex(p, "UI-EJ-DungeonNameBg", "ARTWORK", true)   -- 256x64 native
  titleBG:SetPoint("TOP", loreBG, "TOP", 0, -38)
  p.titleBG = titleBG

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetWidth(256); title:SetJustifyH("CENTER")
  title:SetPoint("CENTER", titleBG, "CENTER", 0, 1)
  NE.font.Set(title, NE.font.MORPHEUS, 24, "", GameFontNormalHuge or GameFontNormalLarge)
  title:SetShadowColor(0, 0, 0, 1); title:SetShadowOffset(1, -1)
  p.title = title

  -- Show-Map button at the BOTTOM. DOWNPORT: hidden — no dungeon maps for Classic/TBC
  -- instances on the 3.3.5a client. Re-shown automatically if a NE.worldmap.ShowDungeonMap
  -- provider is ported later (see PopulateEncounter).
  local map = CreateFrame("Button", nil, p)
  map:SetSize(48, 32)
  map:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 33, 126)
  local mapBG = sliceTex(map, "UI-EJ-ShowMapBG", "BACKGROUND", true)
  mapBG:SetPoint("LEFT", map, "LEFT", -3, 5)
  local mapTex = map:CreateTexture(nil, "ARTWORK")
  mapTex:SetTexture("Interface\\QuestFrame\\UI-QuestMap_Button")
  mapTex:SetSize(48, 32); mapTex:SetPoint("RIGHT", map, "RIGHT", 0, 0)
  mapTex:SetTexCoord(0.125, 0.875, 0.0, 0.5)
  local mapText = map:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  mapText:SetPoint("LEFT", map, "RIGHT", 2, 0)
  mapText:SetText(ENCOUNTER_JOURNAL_SHOW_MAP or "Show Map")
  map:SetScript("OnClick", function() if NE.ej.ShowMap then NE.ej.ShowMap() end end)
  NE.tooltip.Wire(map, ENCOUNTER_JOURNAL_SHOW_MAP or "Show Map")
  map:Hide()
  p.mapButton = map

  -- Lore text — retail LoreScrollingFont 315x95 BOTTOMLEFT(35,5); arrows-only scrollbar.
  local loreScroll = CreateFrame("ScrollFrame", "NE_EJLoreScroll", p, "UIPanelScrollFrameTemplate")
  loreScroll:SetSize(315, 95)
  loreScroll:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 35, 5)
  loreScroll.ScrollBar = loreScroll.ScrollBar or _G["NE_EJLoreScrollScrollBar"]   -- DOWNPORT
  local loreChild = CreateFrame("Frame", nil, loreScroll)
  loreChild:SetSize(315, 1)
  loreScroll:SetScrollChild(loreChild)
  local lore = loreChild:CreateFontString(nil, "ARTWORK", BLACK_FONT)
  lore:SetWidth(315)
  lore:SetJustifyH("LEFT"); lore:SetJustifyV("TOP")
  lore:SetTextColor(0.25, 0.1484375, 0.02)
  lore:SetPoint("TOPLEFT", loreChild, "TOPLEFT", 0, 0)
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(loreScroll, { hideIfUnscrollable = true }) end
  -- arrows-only: hide the thumb + track so only the two arrows show (retail lore look)
  local sbb = loreScroll.ScrollBar or _G["NE_EJLoreScrollScrollBar"]
  if sbb then
    local th = sbb.GetThumbTexture and sbb:GetThumbTexture(); if th then th:SetAlpha(0) end
    for _, k in ipairs({ "_neThumbCapTop", "_neThumbCapBot", "_neTrackBegin", "_neTrackEnd", "_neTrackMiddle" }) do
      if sbb[k] then sbb[k]:SetAlpha(0) end
    end
  end
  p.lore = lore
  p.loreChild = loreChild
end

-- Right info panel: book bg, header, info tabs, boss list (scroll), content area
local function buildInfoPanel(enc)
  local p = CreateFrame("Frame", "NE_EncounterJournalInfoFrame", enc)
  p:SetSize(785, 425)
  p:SetPoint("BOTTOMRIGHT", enc, "BOTTOMRIGHT", -1, 2)
  enc.info = p

  local bg = p:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(NE.tex.localFiles[521750] or 521750)   -- UI-EJ-JournalBG
  bg:SetSize(785, 425)
  bg:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  bg:SetTexCoord(0, 0.766601562, 0, 0.830078125)

  -- Two page-header strips span the full two-page width.
  local lh = sliceTex(p, "UI-EJ-LeftPageHeader", "BACKGROUND", true)
  lh:SetDrawLayer("BACKGROUND", 3)
  lh:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -11)
  local rh = sliceTex(p, "UI-EJ-RightPageHeader", "BACKGROUND", true)
  rh:SetDrawLayer("BACKGROUND", 3)
  rh:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -11)
  p.rightHeader = rh

  -- Header titles: dungeon name (left page) + boss name (right page).
  p.instanceTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  p.instanceTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 70, -16)
  p.instanceTitle:SetWidth(310); p.instanceTitle:SetJustifyH("LEFT"); p.instanceTitle:SetTextColor(1, 0.82, 0)
  NE.font.Set(p.instanceTitle, NE.font.MORPHEUS, 16, "", GameFontNormal)
  p.encounterTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  p.encounterTitle:SetPoint("TOPLEFT", p, "TOPLEFT", 400, -14)
  p.encounterTitle:SetWidth(360); p.encounterTitle:SetJustifyH("CENTER"); p.encounterTitle:SetTextColor(1, 0.82, 0)
  NE.font.Set(p.encounterTitle, NE.font.MORPHEUS, 18, "", GameFontNormalLarge)

  -- Loot slot-filter dropdown (right page header; shown only on the Loot tab). Fully
  -- pcall-wrapped: non-critical chrome must not abort buildInfoPanel.
  pcall(function()
    local lootFilter = NE.ej.CreateDropdown(p, "NE_EJLootFilterDropdown", 120)
    lootFilter:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -10)
    lootFilter:SetDefaultText(ALL or "All")
    lootFilter:SetupMenu(function(dropdown, root)
      -- Only offer categories the current loot actually has (retail skips empty ones).
      local present = NE.ej.PresentLootCategories(p.lootSource)
      for _, fl in ipairs(NE.ej.LOOT_FILTERS) do
        local key, label = fl[1], fl[2]
        if key == "ALL" or present[key] then
          root:CreateRadio(label,
            function() return (p.lootSlot or "ALL") == key end,
            function()
              p.lootSlot = key
              if dropdown.SetDefaultText then dropdown:SetDefaultText(label) end
              if NE.ej.SelectTab then NE.ej.SelectTab(p.selectedTab or 2) end
            end)
        end
      end
    end)
    lootFilter:Hide()
    p.lootFilter = lootFilter
  end)

  -- Difficulty dropdown — shown for multi-difficulty instances. Two independent option sets
  -- share this one dropdown widget:
  --   * TBC/WotLK 5-man DUNGEONS: static Normal/Heroic (p.hasHeroic set in PopulateEncounter);
  --     loot/section rows carry an optional diff="n"/"h" tag.
  --   * WotLK RAIDS: data-driven 10/25-Player (+ Heroic variants on raidHeroic instances) —
  --     p.diffOptions (built in PopulateEncounter from inst.isRaid/inst.raidHeroic) is a list of
  --     { id, size, heroic, label }; loot rows carry size=10|25 and an optional diff="h" tag.
  -- SetupMenu's generator re-runs every time the dropdown opens (UIDropDownMenu_Initialize),
  -- so branching on p.diffOptions here stays correctly in sync as the selected instance changes.
  pcall(function()
    local diffText = _G.ENCOUNTER_JOURNAL_DIFF_TEXT or "%d Player (%s)"
    local dungeonLabels = {
      [1] = diffText:format(5, _G.PLAYER_DIFFICULTY1 or "Normal"),
      [2] = diffText:format(5, _G.PLAYER_DIFFICULTY2 or "Heroic"),
    }
    local dd = NE.ej.CreateDropdown(p, "NE_EJDifficultyDropdown", 150)
    dd:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -10)
    dd:SetDefaultText(dungeonLabels[1])
    dd:SetupMenu(function(dropdown, root)
      if p.diffOptions then
        for _, opt in ipairs(p.diffOptions) do
          local optID = opt.id
          root:CreateRadio(opt.label,
            function() return (p.difficultyID or 1) == optID end,
            function()
              p.difficultyID = optID
              if dropdown.SetDefaultText then dropdown:SetDefaultText(opt.label) end
              if NE.ej.SelectTab then NE.ej.SelectTab(p.selectedTab or 2) end
            end)
        end
      else
        for _, id in ipairs({ 1, 2 }) do
          root:CreateRadio(dungeonLabels[id],
            function() return (p.difficultyID or 1) == id end,
            function()
              p.difficultyID = id
              if dropdown.SetDefaultText then dropdown:SetDefaultText(dungeonLabels[id]) end
              if NE.ej.SelectTab then NE.ej.SelectTab(p.selectedTab or 2) end
            end)
        end
      end
    end)
    dd:Hide()
    p.difficultyDropdown = dd
  end)

  -- model/instance button (top-left) → back to the instance overview (retail parity)
  local ib = CreateFrame("Button", nil, p)
  ib:SetSize(64, 61)
  ib:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -3)
  -- dungeon-specific portrait under the UI-EJ-BossModelButton ring (set per-instance)
  ib.icon = ib:CreateTexture(nil, "BACKGROUND")
  ib.icon:SetSize(40, 40)
  ib.icon:SetPoint("CENTER", ib, "CENTER", 0, 1)
  local ibN = sliceTex(ib, "UI-EJ-BossModelButton"); ibN:SetAllPoints(ib); ib:SetNormalTexture(ibN)
  local ibH = sliceTex(ib, "UI-EJ-BossModelButton"); ibH:SetAllPoints(ib); ibH:SetBlendMode("ADD"); ib:SetHighlightTexture(ibH)
  -- step back ONE level (boss → instance overview), not all the way to the dungeon grid.
  ib:SetScript("OnClick", function() if selInst and NE.ej.ShowInstance then NE.ej.ShowInstance(selInst) end end)
  NE.tooltip.Wire(ib, BACK or "Back")
  p.instanceButton = ib

  -- Info tabs. Vanilla/TBC-raid content ships NO overview sections, so retail's collapsed
  -- layout applies: tab 1 = lore + abilities (Boss icon), tab 3 hidden, Model below Loot.
  local overview = makeTab(p, 1, "UI-EJ-Tab-BossIcon-Selected",  "UI-EJ-Tab-BossIcon-UnSelected",  ABILITIES or "Abilities")
  overview:SetPoint("TOPLEFT", p, "TOPRIGHT", -4, -35)
  local loot = makeTab(p, 2, "UI-EJ-Tab-LootIcon-Selected",      "UI-EJ-Tab-LootIcon-UnSelected",  LOOT_NOUN or "Loot")
  loot:SetPoint("TOP", overview, "BOTTOM", 0, 2)
  -- tab 3 created for index stability but never shown/enabled (collapsed into tab 1).
  local boss = makeTab(p, 3, "UI-EJ-Tab-AbilitiesIcon-Selected", "UI-EJ-Tab-AbilitiesIcon-UnSelected", ABILITIES or "Abilities")
  boss:Hide()
  local model = makeTab(p, 4, "UI-EJ-Tab-ModelIcon-Selected",    "UI-EJ-Tab-ModelIcon-UnSelected", MODEL or "Model")
  model:SetPoint("TOP", loot, "BOTTOM", 0, 2)
  p.tabs = { overview, loot, boss, model }

  -- Boss list (left page) — real scroll viewport + modern reskinned scrollbar.
  local bossScroll = CreateFrame("ScrollFrame", "NE_EJBossScroll", p, "UIPanelScrollFrameTemplate")
  bossScroll:SetSize(330, 382)
  bossScroll:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 25, 1)
  bossScroll.ScrollBar = bossScroll.ScrollBar or _G["NE_EJBossScrollScrollBar"]   -- DOWNPORT
  local bossChild = CreateFrame("Frame", nil, bossScroll)
  bossChild:SetSize(330, 1)
  bossScroll:SetScrollChild(bossChild)
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(bossScroll, { hideIfUnscrollable = true }) end
  p.bossList = { scroll = bossChild, buttons = {} }

  -- Content area (right page): a text body, a loot row holder, and a creature model.
  local c = CreateFrame("Frame", nil, p)
  c:SetPoint("TOPLEFT", p, "TOPLEFT", 400, -44)
  c:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 16)
  -- DOWNPORT FIX: !!!ClassicAPI's SetClipsChildren shim (Util/WidgetAPI.lua) clips via a
  -- ScrollFrame mask sized from Self:GetSize() AT CALL TIME. `c` is only anchor-positioned (two
  -- opposite corners, no explicit SetSize) — GetSize() can read back 0 before the anchors resolve,
  -- permanently pinning the clip mask to 0x0 and hiding EVERYTHING nested in `c` (abilities,
  -- loot, model) forever after. Give it an explicit size (matches the anchor math: p is 785x425)
  -- before clipping so the mask captures the real bounds.
  c:SetSize(785 - 400 - 16, 425 - 44 - 16)
  if c.SetClipsChildren then c:SetClipsChildren(true) end
  c.text = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  c.text:SetPoint("TOPLEFT"); c.text:SetWidth(360)
  c.text:SetJustifyH("LEFT"); c.text:SetJustifyV("TOP")
  c.text:Hide()
  -- Loot list — scrollable viewport + reskinned bar. c.lootFrame is the scroll CHILD.
  c.lootScroll = CreateFrame("ScrollFrame", "NE_EJLootScroll", c, "UIPanelScrollFrameTemplate")
  c.lootScroll:SetPoint("TOPLEFT", c, "TOPLEFT", 20, 0)
  c.lootScroll:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -22, 0)
  c.lootScroll.ScrollBar = c.lootScroll.ScrollBar or _G["NE_EJLootScrollScrollBar"]   -- DOWNPORT
  c.lootFrame = CreateFrame("Frame", nil, c.lootScroll)
  c.lootFrame:SetSize(321, 1)
  c.lootScroll:SetScrollChild(c.lootFrame)
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(c.lootScroll, { hideIfUnscrollable = true }) end
  c.lootFrame.rows = {}
  c.lootScroll:Hide()
  -- Abilities list (right page) — scrollable icon+title+body cards.
  c.sectionScroll = CreateFrame("ScrollFrame", "NE_EJSectionScroll", c, "UIPanelScrollFrameTemplate")
  c.sectionScroll:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
  c.sectionScroll:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -22, 0)
  c.sectionScroll.ScrollBar = c.sectionScroll.ScrollBar or _G["NE_EJSectionScrollScrollBar"]   -- DOWNPORT
  local sc = CreateFrame("Frame", nil, c.sectionScroll)
  sc:SetSize(340, 1)
  c.sectionScroll:SetScrollChild(sc)
  if NE.scrollbar and NE.scrollbar.Reskin then NE.scrollbar.Reskin(c.sectionScroll, { hideIfUnscrollable = true }) end
  c.sectionChild = sc
  c.sectionWidgets = {}
  c.sectionScroll:Hide()
  p.content = c

  -- Model area. DOWNPORT: plain Frame + PlayerModel (no ModelScene on 3.3.5a). Retail layer
  -- order preserved: dungeonBG BACKGROUND/1 → [3D model] → paperFrame OVERLAY → name.
  local ma = CreateFrame("Frame", nil, p)
  ma:SetSize(390, 423)
  ma:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -3, 1)
  ma:Hide()
  ma.bg = ma:CreateTexture(nil, "BACKGROUND", nil, 1)
  ma.bg:SetTexture(NE.tex.localFiles[521743] or 521743)   -- UI-EJ-BACKGROUND-Default
  -- dungeonBG: 512x512 file shown 394x425 via a horizontally-flipped crop.
  ma.bg:SetTexCoord(0.76953125, 0, 0, 0.83007813)
  ma.bg:SetSize(394, 425); ma.bg:SetPoint("BOTTOMLEFT", ma, "BOTTOMLEFT", 0, -2)
  ma.model = CreateFrame("PlayerModel", nil, ma)
  ma.model:SetAllPoints(ma)
  -- paper frame OVERLAYS the model (transparent centre frames it); lives on a child frame
  -- ABOVE the PlayerModel (a texture on `ma` would render UNDER the 3D model).
  local pf = CreateFrame("Frame", nil, ma)
  pf:SetAllPoints(ma); pf:SetFrameLevel(ma.model:GetFrameLevel() + 2)
  ma.shadow = pf:CreateTexture(nil, "OVERLAY", nil, 0)
  ma.shadow:SetTexture(NE.tex.localFiles[527690] or 527690)   -- UI-EJ-BossModelPaperFrame
  ma.shadow:SetTexCoord(0.767578125, 0, 0, 0.828125)          -- its OWN flipped crop
  ma.shadow:SetSize(393, 424); ma.shadow:SetPoint("BOTTOMRIGHT", ma, "BOTTOMRIGHT", 3, 0)
  ma.nameShadow = pf:CreateTexture(nil, "OVERLAY", nil, 1)
  NE.ej.ApplySlice(ma.nameShadow, "UI-EJ-BossNameShadow", true)  -- 395x63
  ma.nameShadow:SetPoint("BOTTOM", pf, "BOTTOM", 0, -2)
  ma.name = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ma.name:SetSize(380, 10); ma.name:SetJustifyH("CENTER")
  ma.name:SetPoint("BOTTOM", pf, "BOTTOM", 0, 6)
  NE.font.Set(ma.name, NE.font.MORPHEUS, 18, "", GameFontNormalLarge)
  ma.name:SetShadowColor(0, 0, 0, 1); ma.name:SetShadowOffset(1, -1)

  -- Drag-to-rotate. DOWNPORT: 3.3.5a's generic Model_OnMouseDown/_OnUpdate handlers don't
  -- exist — a cursor-delta OnUpdate drives Model:SetFacing. Mousedown is forwarded from every
  -- frame in the stack (the paper-frame child otherwise eats the clicks).
  local rot = CreateFrame("Frame", nil, ma)
  rot:SetAllPoints(ma)
  rot:SetFrameLevel(pf:GetFrameLevel() + 1)
  ma.rotator = rot
  ma.model.rotation = 0
  local dragging, lastX
  rot:SetScript("OnUpdate", function()
    if not dragging then return end
    local x = GetCursorPosition()
    local dx = x - (lastX or x)
    lastX = x
    ma.model.rotation = (ma.model.rotation or 0) + dx * 0.015
    pcall(ma.model.SetFacing, ma.model, ma.model.rotation)
  end)
  local function fwdDown(_, btn)
    if not btn or btn == "LeftButton" then dragging = true; lastX = nil; ma._userRotated = true end
  end
  local function fwdUp(_, btn)
    if not btn or btn == "LeftButton" then dragging = false end
  end
  for _, fr in ipairs({ ma, ma.model, pf, rot }) do
    fr:EnableMouse(true)
    fr:SetScript("OnMouseDown", fwdDown)
    fr:SetScript("OnMouseUp",   fwdUp)
  end

  p.modelArea = ma
end

-- Boss list population (pooled buttons)
local function acquireBossButton(list, i)
  local b = list.buttons[i]
  if b then return b end
  b = CreateFrame("Button", nil, list.scroll)
  b:SetSize(325, 55)
  local up = sliceTex(b, "UI-EJ-BossButton-Up");        up:SetAllPoints(b); b:SetNormalTexture(up)
  local hi = sliceTex(b, "UI-EJ-BossButton-Highlight"); hi:SetAllPoints(b); hi:SetBlendMode("ADD"); b:SetHighlightTexture(hi)
  local dn = sliceTex(b, "UI-EJ-BossButton-Down");      dn:SetAllPoints(b); b:SetPushedTexture(dn)
  -- creature portrait + name live on a CHILD FRAME above the button's HIGHLIGHT layer.
  local cf = CreateFrame("Frame", nil, b)
  cf:SetFrameLevel(b:GetFrameLevel() + 2)
  cf:SetAllPoints(b)
  b.creature = cf:CreateTexture(nil, "ARTWORK")
  b.creature:SetSize(128, 64)                            -- per EJ.xml:585
  b.creature:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 13)   -- overhangs the button top by 13
  b.name = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.name:SetPoint("LEFT", b, "LEFT", 105, -3); b.name:SetWidth(205); b.name:SetJustifyH("LEFT")
  b.name:SetTextColor(0.827, 0.659, 0.463)
  -- "Defeated this week" checkmark. DOWNPORT: native ReadyCheck art (no retail atlas here);
  -- only ever shown if the per-encounter lockout API exists (it doesn't on stock 3.3.5a).
  b.defeated = cf:CreateTexture(nil, "OVERLAY")
  b.defeated:SetSize(16, 16)
  b.defeated:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 0)
  b.defeated:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.defeated:Hide()
  list.buttons[i] = b
  return b
end

-- Keep the selected boss's row highlighted (retail locks the selected EncounterButton).
local function applyBossHighlight()
  local f = NE.ej.frame
  local bl = f and f.encounter and f.encounter.info and f.encounter.info.bossList
  if not (bl and bl.buttons) then return end
  for _, b in ipairs(bl.buttons) do
    if b.LockHighlight then
      if b.enc and b.enc == selBoss then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
end

-- "Defeated this week" checkmark. DOWNPORT: GetSavedInstanceEncounterInfo is a Cata+ API —
-- absent on 3.3.5a the whole feature degrades to hidden checkmarks.
local function buildDefeatedSet()
  local set = {}
  if not (GetSavedInstanceEncounterInfo and GetNumSavedInstances) then return set end
  local n = GetNumSavedInstances() or 0
  for r = 1, n do
    local _, _, _, _, _, _, _, _, _, _, numBosses = GetSavedInstanceInfo(r)
    for i = 1, (numBosses or 0) do
      local bossName, _, isKilled = GetSavedInstanceEncounterInfo(r, i)
      if bossName and isKilled then set[bossName:lower()] = true end
    end
  end
  return set
end
local function applyDefeatedOverlays()
  local f = NE.ej.frame
  local bl = f and f.encounter and f.encounter.info and f.encounter.info.bossList
  if not (bl and bl.buttons) then return end
  local killed = buildDefeatedSet()
  for _, b in ipairs(bl.buttons) do
    if b.defeated then
      local nm = b.enc and b.enc.name
      setShown(b.defeated, nm ~= nil and killed[nm:lower()] == true)
    end
  end
end
-- RequestRaidInfo's result lands on UPDATE_INSTANCE_INFO (async), so re-apply when it arrives.
local defeatedWatch = CreateFrame("Frame")
defeatedWatch:RegisterEvent("UPDATE_INSTANCE_INFO")
defeatedWatch:SetScript("OnEvent", applyDefeatedOverlays)

local function fillBossList(inst)
  local list = NE.ej.frame.encounter.info.bossList
  local encs = inst.encounters or {}
  if RequestRaidInfo then RequestRaidInfo() end   -- refresh the saved-raid lockout
  for i, enc in ipairs(encs) do
    local b = acquireBossButton(list, i)
    b:ClearAllPoints()
    -- 15px top pad so the first boss's portrait (overhangs +13) isn't clipped.
    if i == 1 then b:SetPoint("TOPLEFT", list.scroll, "TOPLEFT", 0, -15)
    else b:SetPoint("TOPLEFT", list.buttons[i-1], "BOTTOMLEFT", 0, -2) end
    b.name:SetText(enc.name or "?")
    b.enc = enc
    local cr = enc.creatures and enc.creatures[1]
    if cr and cr.file and cr.file > 0 then
      b.creature:SetTexture(NE.tex.localFiles[cr.file] or cr.file)
      b.creature:SetTexCoord(0, 1, 0, 1)
      b.creature:Show()
    else
      b.creature:Hide()
    end
    local encRef = enc
    b:SetScript("OnClick", function()
      if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN) end
      NE.ej.ShowBoss(encRef)
    end)
    b:Show()
  end
  for i = #encs + 1, #list.buttons do list.buttons[i]:Hide() end
  applyBossHighlight()      -- restore the selected-row highlight after a (re)build
  applyDefeatedOverlays()   -- show "defeated this week" checkmarks (no-op on stock 3.3.5a)
  list.scroll:SetHeight(math.max(1, #encs * 57 + 15))  -- +15 top pad; drives the scroll range
end

-- Loot rendering (resolve via GetItemInfo; cold items primed + re-rendered by a short poll).
-- Loot row = NE.ej.CreateLootRow (EncounterItem.lua): 321x45, icon 42x42, name top, slot
-- bottom-left, armor/weapon type bottom-right, UI-EJ-LootFrame row bg, quality border.
local function lootRow(lf, i)
  local r = lf.rows[i]
  if r then return r end
  r = NE.ej.CreateLootRow(lf)
  lf.rows[i] = r
  return r
end

-- Category header (retail EncounterItemDividerTemplate). Med3 may be absent → GameFontNormal.
local function lootHeader(lf, i)
  lf.headers = lf.headers or {}
  local h = lf.headers[i]
  if h then return h end
  h = CreateFrame("Frame", nil, lf)
  h:SetSize(321, 30)
  h.name = h:CreateFontString(nil, "OVERLAY", _G.GameFontNormalMed3 and "GameFontNormalMed3" or "GameFontNormal")
  h.name:SetJustifyH("LEFT")
  h.name:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 2, 3)
  lf.headers[i] = h
  return h
end

-- Paint one loot row from a resolved item record (see renderLoot's bucketing).
local function fillLootRow(r, it)
  r.itemID = it.id
  r.link = it.link   -- HandleModifiedItemClick needs the link, not the id
  r.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  r.name:SetText(it.name)
  local col = NE.itembtn.TextColor(it.quality or 1)
  if col then
    r.name:SetTextColor(col.r, col.g, col.b)
    r.iconBorder:SetVertexColor(col.r, col.g, col.b); r.iconBorder:Show()
  else
    r.name:SetTextColor(1, 1, 1); r.iconBorder:Hide()
  end
  r.slot:SetText((it.equipLoc and it.equipLoc ~= "" and _G[it.equipLoc]) or "")
  r.armorType:SetText(it.itemSubType or it.itemType or "")
  -- drop% (NE addition): show only when AtlasLoot recorded a rate (pct>0)
  r.dropPct:SetText(it.pct and it.pct > 0 and string.format("%.1f%%", it.pct) or "")
end

local MAX_LOOT = 100   -- scrollable; the instance-wide aggregate can be large

-- Loot slot filter (retail Enum.ItemSlotFilterType): {key, label}; key "ALL" = no filter.
NE.ej.LOOT_FILTERS = {
  { "ALL",            _G.ALL_INVENTORY_SLOTS or ALL or "All" },
  { "INVTYPE_HEAD",   _G.INVTYPE_HEAD or "Head" },
  { "INVTYPE_NECK",   _G.INVTYPE_NECK or "Neck" },
  { "INVTYPE_SHOULDER", _G.INVTYPE_SHOULDER or "Shoulder" },
  { "INVTYPE_CLOAK",  _G.INVTYPE_CLOAK or "Back" },
  { "INVTYPE_CHEST",  _G.INVTYPE_CHEST or "Chest" },
  { "INVTYPE_WRIST",  _G.INVTYPE_WRIST or "Wrist" },
  { "INVTYPE_HAND",   _G.INVTYPE_HAND or "Hands" },
  { "INVTYPE_WAIST",  _G.INVTYPE_WAIST or "Waist" },
  { "INVTYPE_LEGS",   _G.INVTYPE_LEGS or "Legs" },
  { "INVTYPE_FEET",   _G.INVTYPE_FEET or "Feet" },
  { "MAINHAND",       _G.INVTYPE_WEAPONMAINHAND or "Main Hand" },
  { "OFFHAND",        _G.INVTYPE_WEAPONOFFHAND or "Off Hand" },
  { "INVTYPE_FINGER", _G.INVTYPE_FINGER or "Finger" },
  { "INVTYPE_TRINKET", _G.INVTYPE_TRINKET or "Trinket" },
  { "OTHER",          _G.EJ_LOOT_SLOT_FILTER_OTHER or OTHER or "Other" },
}
local LOOT_DIRECT = { INVTYPE_HEAD=1, INVTYPE_NECK=1, INVTYPE_SHOULDER=1, INVTYPE_CLOAK=1,
  INVTYPE_CHEST=1, INVTYPE_WRIST=1, INVTYPE_HAND=1, INVTYPE_WAIST=1, INVTYPE_LEGS=1, INVTYPE_FEET=1,
  INVTYPE_FINGER=1, INVTYPE_TRINKET=1 }
local function lootCategory(equipLoc)
  if equipLoc == "INVTYPE_ROBE" then return "INVTYPE_CHEST" end
  if LOOT_DIRECT[equipLoc] then return equipLoc end
  if equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_WEAPON"
     or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN" then
    return "MAINHAND"
  end
  if equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then
    return "OFFHAND"
  end
  return "OTHER"
end

-- The slot categories actually PRESENT in a loot list (resolved items only).
function NE.ej.PresentLootCategories(items)
  local present = {}
  if items then
    for i = 1, #items do
      local entry = items[i]
      local id = (type(entry) == "table") and entry.id or entry
      local name, _, _, _, _, _, _, _, equipLoc = GetItemInfo(id)
      if name then present[lootCategory(equipLoc or "")] = true end
    end
  end
  return present
end

-- Rarity tiers — OWNER DIVERGENCE (NewEra): equippable gear bucketed by drop chance into four
-- titled tiers; non-equippable goes under "Bonus".
local TIER_EXTREME_MAX  = 1    -- 0 < pct < 1%    → Extremely Rare
local TIER_VERYRARE_MAX = 5    -- 1% ≤ pct < 5%   → Very Rare
local TIER_UNCOMMON_MAX = 15   -- 5% ≤ pct < 15%  → Uncommon ; pct ≥ 15% or unknown → Common
local function lootTier(equipLoc, pct)
  if lootCategory(equipLoc or "") == "OTHER" then return "bonus" end
  if pct and pct > 0 then
    if pct < TIER_EXTREME_MAX  then return "extreme"  end
    if pct < TIER_VERYRARE_MAX then return "veryrare" end
    if pct < TIER_UNCOMMON_MAX then return "uncommon" end
  end
  return "common"
end
local LOOT_TIERS = {
  { key = "extreme",  title = _G.EJ_ITEM_CATEGORY_EXTREMELY_RARE or "Extremely Rare" },
  { key = "veryrare", title = _G.EJ_ITEM_CATEGORY_VERY_RARE or "Very Rare" },
  { key = "uncommon", title = _G.ITEM_QUALITY2_DESC or "Uncommon" },
  { key = "common",   title = _G.ITEM_QUALITY1_DESC or "Common" },
  { key = "bonus",    title = _G.BONUS_LOOT_TOOLTIP_TITLE or "Bonus" },
}

-- Difficulty filter shared by loot rows (size+diff) and ability sections (diff only).
--   * Raids (info.diffOptions present, set in PopulateEncounter): a row's optional `size`
--     (10|25) must match the selected option's size; a row's diff="h" must match the option's
--     heroic-ness EXACTLY (WotLK raid loot is a hard split — a Normal-tagged/untagged item is
--     never also a Heroic drop, unlike the 5-man "applies to both" convention below).
--   * 5-man dungeons: legacy — an untagged row (dif=nil) applies to both Normal and Heroic.
local function passesDifficulty(info, dif, size)
  if info.diffOptions then
    local sel
    for _, opt in ipairs(info.diffOptions) do
      if opt.id == (info.difficultyID or 1) then sel = opt; break end
    end
    sel = sel or info.diffOptions[1]
    if not sel then return true end
    if size and sel.size and size ~= sel.size then return false end
    local heroicSel = sel.heroic and true or false
    if (dif == "h") ~= heroicSel then return false end
    return true
  else
    local heroicSel = info.hasHeroic and (info.difficultyID or 1) == 2 or false
    if dif and (dif == "h") ~= heroicSel then return false end
    return true
  end
end

local function renderLoot(boss, preserveScroll)
  local info = NE.ej.frame.encounter.info
  local lf = info.content.lootFrame
  local items = boss and boss.loot or {}
  -- Remember the list currently shown so the cache poll can re-render THIS view as items
  -- stream in — both the boss page and the instance-landing aggregate.
  info.lootSource = items
  local filter = info.lootSlot or "ALL"

  -- Pass 1 — resolve + slot-filter, bucket into rarity tiers. Cold items are primed (server
  -- item query via hidden tooltip) and skipped; the poll below re-renders as answers arrive.
  local buckets = { extreme = {}, veryrare = {}, uncommon = {}, common = {}, bonus = {} }
  local count, unresolved = 0, 0
  for i = 1, #items do
    if count >= MAX_LOOT then break end
    -- loot schema is { {id=ITEMID, pct=DROP%, size=10|25|nil, diff="h"|"n"|nil}, ... }; tolerate
    -- a bare id.
    local entry = items[i]
    local id   = (type(entry) == "table") and entry.id   or entry
    local pct  = (type(entry) == "table") and entry.pct  or 0
    local dif  = (type(entry) == "table") and entry.diff or nil
    local size = (type(entry) == "table") and entry.size or nil
    if not passesDifficulty(info, dif, size) then
      -- wrong difficulty/size — filtered out before any item resolve
    else
      local name, link, quality, _, _, itemType, itemSubType, _, equipLoc, icon = GetItemInfo(id)
      if not name then
        unresolved = unresolved + 1
        if id then
          if NE.ej.PrimeItem then NE.ej.PrimeItem(id) end
          if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        end
      elseif filter == "ALL" or lootCategory(equipLoc or "") == filter then
        count = count + 1
        local b = buckets[lootTier(equipLoc, pct)]
        b[#b + 1] = { id = id, link = link, name = name, quality = quality, itemType = itemType,
                      itemSubType = itemSubType, equipLoc = equipLoc, icon = icon, pct = pct }
      end
    end
  end

  -- Pass 2 — render tiers in retail order; a header before each non-empty tier.
  local rowN, hdrN, prev, totalH = 0, 0, nil, 0
  local function place(w, h)
    w:ClearAllPoints()
    if not prev then w:SetPoint("TOPLEFT", lf, "TOPLEFT", 0, 0)
    else w:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2) end
    prev = w; totalH = totalH + h + 2; w:Show()
  end
  for _, tier in ipairs(LOOT_TIERS) do
    local bucket = buckets[tier.key]
    if #bucket > 0 then
      if tier.title then
        hdrN = hdrN + 1
        local h = lootHeader(lf, hdrN)
        h.name:SetText(tier.title)
        place(h, h:GetHeight())
      end
      for _, it in ipairs(bucket) do
        rowN = rowN + 1
        local r = lootRow(lf, rowN)
        fillLootRow(r, it)
        place(r, 45)   -- row 45 + 2 gap
      end
    end
  end
  for i = rowN + 1, #lf.rows do lf.rows[i]:Hide() end
  if lf.headers then for i = hdrN + 1, #lf.headers do lf.headers[i]:Hide() end end
  lf:SetHeight(math.max(1, totalH))   -- drives the loot scroll range
  -- Reset scroll only when switching into a fresh view; a streaming re-render keeps the
  -- user's place.
  if not preserveScroll and lf:GetParent().SetVerticalScroll then lf:GetParent():SetVerticalScroll(0) end

  -- DOWNPORT: the GET_ITEM_INFO_RECEIVED substitute — poll while this view still has cold
  -- items, re-rendering scroll-preserving as the server answers the item queries.
  if unresolved > 0 and NE.ej.SchedulePrimedRefresh then
    NE.ej.SchedulePrimedRefresh(
      function()
        local inf = NE.ej.frame and NE.ej.frame.encounter and NE.ej.frame.encounter.info
        if not (inf and inf.selectedTab == 2 and inf.lootSource == items) then return false end
        for i = 1, #items do
          local entry = items[i]
          local id = (type(entry) == "table") and entry.id or entry
          if id and not GetItemInfo(id) then return true end
        end
        return false
      end,
      function() renderLoot({ loot = items }, true) end)
  end
end

-- Abilities tab: retail's collapsible PaperHeader sections. Strip unresolved spell-script
-- tokens ($8040d duration, $s1 effect values, $bull; bullets) that the client can't
-- substitute without live spell data — they'd render as raw "$8040d".
local function cleanBody(s)
  s = (s or ""):gsub("%$%d+%a%d*", ""):gsub("%$%a%d*", ""):gsub("%$bull;?", "•")
  return (s:gsub("%s+([%.,])", "%1"):gsub("  +", " "):gsub("^%s+", ""))
end

local SEC_W = 334

-- 3-slice paper-header band (left + stretched mid + right) on `parent` at `layer`.
local function paperBand(parent, state, layer)
  local b = {}
  b.l = parent:CreateTexture(nil, layer); NE.ej.ApplySlice(b.l, "UI-EJ-PaperHeader-" .. state .. "-Left", true)
  b.l:ClearAllPoints(); b.l:SetPoint("LEFT", parent, "LEFT", -1, -1)
  b.r = parent:CreateTexture(nil, layer); NE.ej.ApplySlice(b.r, "UI-EJ-PaperHeader-" .. state .. "-Right", true)
  b.r:ClearAllPoints(); b.r:SetPoint("RIGHT", parent, "RIGHT", 3, -1)
  b.m = parent:CreateTexture(nil, layer); NE.ej.ApplySlice(b.m, "_PaperHeader-" .. state .. "-Mid", false)
  b.m:SetHeight(29); b.m:SetPoint("LEFT", b.l, "RIGHT", -32, 0); b.m:SetPoint("RIGHT", b.r, "LEFT", 32, 0)
  return b
end
local function bandShown(b, on) setShown(b.l, on); setShown(b.m, on); setShown(b.r, on) end

local function acquireSection(c, i)
  local w = c.sectionWidgets[i]
  if w then return w end
  w = CreateFrame("Frame", nil, c.sectionChild)
  w:SetWidth(SEC_W)
  local hb = CreateFrame("Button", nil, w)
  hb:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0); hb:SetPoint("TOPRIGHT", w, "TOPRIGHT", 0, 0)
  hb:SetHeight(24)
  w.header  = hb
  w.cBand   = paperBand(hb, "UnSelectUp", "BACKGROUND")   -- collapsed
  w.eBand   = paperBand(hb, "SelectDown", "BACKGROUND")   -- expanded
  paperBand(hb, "Highlight", "HIGHLIGHT")                 -- HIGHLIGHT layer = auto hover glow
  w.expandedIcon = hb:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  w.expandedIcon:SetPoint("LEFT", hb, "LEFT", 5, 0)
  w.abilityIcon = hb:CreateTexture(nil, "OVERLAY")
  w.abilityIcon:SetSize(18, 18); w.abilityIcon:SetPoint("LEFT", w.expandedIcon, "RIGHT", 5, 0)
  w.abilityIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  -- section icon-flag badges on the right (Interruptible/Magic/Enrage/…), right-to-left.
  -- Each badge is a mouse-enabled Frame (a texture can't take OnEnter) + tooltip strings.
  w.flagIcons = {}
  for fi = 1, 6 do
    local ic = CreateFrame("Frame", nil, hb)
    ic:SetSize(16, 16)
    ic.tex = ic:CreateTexture(nil, "OVERLAY"); ic.tex:SetAllPoints(ic)
    if fi == 1 then ic:SetPoint("RIGHT", hb, "RIGHT", -4, 0)
    else ic:SetPoint("RIGHT", w.flagIcons[fi - 1], "LEFT", -2, 0) end
    ic:EnableMouse(true)
    ic:SetScript("OnEnter", function(self)
      if not self.tooltipTitle then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
      if self.tooltipText and self.tooltipText ~= "" then
        GameTooltip:AddLine(self.tooltipText, nil, nil, nil, true)
      end
      GameTooltip:Show()
    end)
    ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ic:Hide()
    w.flagIcons[fi] = ic
  end
  w.title = hb:CreateFontString(nil, "OVERLAY", "GameFontNormal"); w.title:SetJustifyH("LEFT")
  w.desc = w:CreateFontString(nil, "ARTWORK", BLACK_FONT)
  w.desc:SetJustifyH("LEFT"); w.desc:SetJustifyV("TOP"); w.desc:SetTextColor(0.25, 0.1484375, 0.02)
  w.desc:SetWidth(SEC_W - 26); w.desc:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 13, -9)
  -- parchment inset box behind the description + its bottom border
  w.descBG = w:CreateTexture(nil, "BACKGROUND")
  NE.ej.ApplySlice(w.descBG, "UI-PaperOverlay-AbilityTextBG", false)
  w.descBG:SetPoint("TOPLEFT", w.desc, "TOPLEFT", -9, 12)
  w.descBG:SetPoint("BOTTOMRIGHT", w.desc, "BOTTOMRIGHT", 9, -11)
  w.descBottom = w:CreateTexture(nil, "BACKGROUND")
  NE.ej.ApplySlice(w.descBottom, "UI-PaperOverlay-AbilityTextBottomBorder", false)
  w.descBottom:SetHeight(9)
  w.descBottom:SetPoint("LEFT", w.descBG, "BOTTOMLEFT", 0, 0)
  w.descBottom:SetPoint("RIGHT", w.descBG, "BOTTOMRIGHT", 0, 0)
  hb:SetScript("OnClick", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    if w.sectionID and c._secExp then c._secExp[w.sectionID] = not c._secExp[w.sectionID] end
    if c._reflow then c._reflow() end
  end)
  c.sectionWidgets[i] = w
  return w
end

local HEADER_INDENT = 15    -- retail Blizzard_EncounterJournal.lua
local SECTION_GAP   = 6

-- IconFlags bitmask → list of set bit indices.
local function flagBits(flags)
  local out = {}
  flags = flags or 0
  for i = 0, 13 do
    if bit.band(flags, bit.lshift(1, i)) ~= 0 then out[#out + 1] = i end
  end
  return out
end
local function flagTexCoord(i)
  local l = (i % 8) / 8
  local t = math.floor(i / 8) / 2
  return l, l + 0.125, t, t + 0.5
end

-- Bit-index → modern flag atlas names (kept from NewEra; the icons_16x16_* atlases are NOT
-- registered on this port, so SetFlagIcon always falls to the legacy UI-EJ-Icons grid).
local FLAG_ATLAS = {
  [0]="icons_16x16_tank",   [1]="icons_16x16_damage",  [2]="icons_16x16_heal",
  [3]="icons_16x16_heroic", [4]="icons_16x16_deadly",  [5]="icons_16x16_important",
  [6]="icons_16x16_inturrupt", [7]="icons_16x16_magic", [8]="icons_16x16_curse",
  [9]="icons_16x16_poison", [10]="icons_16x16_disease", [11]="icons_16x16_enrage",
  [12]="icons_16x16_mythic", [13]="icons_16x16_blood",
}
-- Fallback tooltip titles (the ENCOUNTER_JOURNAL_SECTION_FLAG<i> globals are Cata+).
local FLAG_NAME = {
  [0]="Role: Tank", [1]="Role: Damage", [2]="Role: Healer", [3]="Heroic Difficulty",
  [4]="Deadly", [5]="Important", [6]="Interruptible", [7]="Magic Effect", [8]="Curse Effect",
  [9]="Poison Effect", [10]="Disease Effect", [11]="Enrage Effect", [12]="Mythic Difficulty",
  [13]="Bleed Effect",
}
NE.ej.FLAG_NAME = FLAG_NAME

-- Apply the flag icon for bit-index `i`: named atlas when registered, else retail's legacy
-- UI-EJ-Icons 8x2 grid. NOTE: NE.tex.SetAtlas IS the texcoord set — no trailing SetTexCoord.
function NE.ej.SetFlagIcon(tex, i)
  local atlas = FLAG_ATLAS[i]
  if not (atlas and NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(tex, atlas, false)) then
    tex:SetTexture(NE.tex.localFiles[521749] or 521749)
    tex:SetTexCoord(flagTexCoord(i))
  end
end

-- Lay out one section row at `depth` (indented 15px/level). Returns the row's height.
local function layoutSection(w, s, depth, exp)
  local rowW = SEC_W - depth * HEADER_INDENT
  w:SetWidth(rowW)
  w.title:SetFontObject((depth == 0 and _G.GameFontNormalMed3) or _G.GameFontNormal)
  w.title:ClearAllPoints()
  -- left glyph: creature portrait > ability icon (FDID) > spell-resolved icon > none.
  -- DOWNPORT: spell icons resolve via GetSpellInfo (GetSpellTexture can't take arbitrary
  -- ids on 3.3.5a); creature portraits need SetPortraitTextureFromCreatureDisplayID (absent
  -- on stock 3.3.5a → those sub-creature headers render without an icon).
  -- DOWNPORT FIX: 3.3.5a's SetTexture can't read a raw FileDataID (core/Texture.lua) — it
  -- renders the client's "missing texture" glyph (a red square), not a blank. s.icon is a raw
  -- modern FDID from the DB2-extracted dungeon data (Data/DataTBC) and is almost never one of
  -- the 501 EJ BLPs we shipped locally, so only trust it when NE.tex.localFiles actually has an
  -- entry; otherwise fall through to the spell icon (hand-seeded raid data always sets a real
  -- spell id instead of icon) or hide the glyph rather than show a red square.
  local mappedFDID = s.icon and s.icon > 0 and NE.tex.localFiles[s.icon]
  local spellIcon = (not mappedFDID) and s.spell and s.spell > 0 and GetSpellInfo
    and select(3, GetSpellInfo(s.spell)) or nil
  if s.cdisp and s.cdisp > 0 and SetPortraitTextureFromCreatureDisplayID then
    SetPortraitTextureFromCreatureDisplayID(w.abilityIcon, s.cdisp)
    w.abilityIcon:Show(); w.title:SetPoint("LEFT", w.abilityIcon, "RIGHT", 5, 0)
  elseif mappedFDID or spellIcon then
    w.abilityIcon:SetTexture(mappedFDID or spellIcon)
    w.abilityIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    w.abilityIcon:Show(); w.title:SetPoint("LEFT", w.abilityIcon, "RIGHT", 5, 0)
  else
    w.abilityIcon:Hide(); w.title:SetPoint("LEFT", w.expandedIcon, "RIGHT", 5, 0)
  end
  -- right-side flag badges (right-to-left); title's RIGHT anchor stops at the leftmost one.
  local bits, last = flagBits(s.flags), 0
  for fi = 1, #w.flagIcons do
    local idx = bits[fi]   -- 0-based bit index
    local ic = w.flagIcons[fi]
    if idx then
      NE.ej.SetFlagIcon(ic.tex, idx)
      ic.tooltipTitle = _G["ENCOUNTER_JOURNAL_SECTION_FLAG" .. idx] or FLAG_NAME[idx]
      ic.tooltipText  = _G["ENCOUNTER_JOURNAL_SECTION_FLAG_DESCRIPTION" .. idx]
      ic:Show(); last = fi
    else
      ic:Hide()
    end
  end
  if last > 0 then w.title:SetPoint("RIGHT", w.flagIcons[last], "LEFT", -5, 0)
  else w.title:SetPoint("RIGHT", w.header, "RIGHT", -8, 0) end
  w.title:SetText(s.title or "")
  w.desc:SetWidth(rowW - 26); w.desc:SetText(cleanBody(s.body))
  local hasBody = (w.desc:GetText() or "") ~= ""
  w.expandedIcon:SetText(exp and "-" or "+")
  bandShown(w.cBand, not exp); bandShown(w.eBand, exp)
  local showDesc = exp and hasBody
  setShown(w.desc, showDesc); setShown(w.descBG, showDesc); setShown(w.descBottom, showDesc)
  local h = 24
  if showDesc then h = h + 9 + (w.desc:GetStringHeight() or 0) + 11 + 9 end  -- gap + text + box pad + border
  w:SetHeight(h)
  return h
end

-- Sections form a tree walked EXACTLY as retail does (ToggleHeaders): start at the boss's
-- rootSection and follow the sibling linked-list (`sib`); an expanded header descends into
-- its `child` chain (indented). Headers expanded by default; `visited` guards cycles.
local function renderSections(boss)
  local c = NE.ej.frame.encounter.info.content
  local byId = {}
  for _, s in ipairs(boss.sections or {}) do byId[s.id] = s end
  c._secExp = c._secExp or {}
  -- Lead lore paragraph: the boss description at the TOP, above the ability sections.
  if not c.leadDesc then
    c.leadDesc = c.sectionChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    c.leadDesc:SetJustifyH("LEFT"); c.leadDesc:SetJustifyV("TOP"); c.leadDesc:SetWidth(SEC_W)
    c.leadDesc:SetTextColor(0.25, 0.1484375, 0.02)   -- dark on the parchment page
  end
  c.leadDesc:SetText(cleanBody(boss.desc))
  c._reflow = function()
    local hasLore = (c.leadDesc:GetText() or "") ~= ""
    setShown(c.leadDesc, hasLore)
    local y = -6
    if hasLore then
      c.leadDesc:ClearAllPoints()
      c.leadDesc:SetPoint("TOPLEFT", c.sectionChild, "TOPLEFT", 6, y)
      y = y - (c.leadDesc:GetStringHeight() or 0) - 14   -- gap before the first ability band
    end
    -- Difficulty filter (mirrors renderLoot's passesDifficulty): a section's optional diff tag
    -- must match the selected difficulty; skipping a section skips its subtree.
    local dinfo = NE.ej.frame.encounter.info
    local idx, visited = 0, {}
    local function walk(startID, depth)
      local id = startID
      while id and id ~= 0 and byId[id] and not visited[id] do
        visited[id] = true
        local s = byId[id]
        local dif = s.diff
        if not passesDifficulty(dinfo, dif, nil) then
          id = s.sib   -- wrong difficulty: drop this section and its subtree
        else
          idx = idx + 1
          local w = acquireSection(c, idx)
          w.sectionID = s.id
          if c._secExp[s.id] == nil then c._secExp[s.id] = true end   -- expanded by default
          local exp = c._secExp[s.id] and true or false
          local h = layoutSection(w, s, depth, exp)
          w:ClearAllPoints(); w:SetPoint("TOPLEFT", c.sectionChild, "TOPLEFT", 6 + depth * HEADER_INDENT, y)
          w:Show()
          y = y - h - SECTION_GAP
          if exp then walk(s.child, depth + 1) end
          id = s.sib
        end
      end
    end
    local root = boss.rootSection
    if not root or root == 0 then root = boss.sections and boss.sections[1] and boss.sections[1].id end
    walk(root, 0)
    for i = idx + 1, #c.sectionWidgets do c.sectionWidgets[i]:Hide() end
    c.sectionChild:SetHeight(math.max(1, -y + 6))
  end
  c._reflow()
  c.sectionScroll:SetVerticalScroll(0)
end

-- Model display. DOWNPORT: the PRIMARY path is the PlayerModel (no ModelScene on 3.3.5a).
-- Camera: the generated per-boss MODEL_CAM (cdist = camera distance, ctz = look-at height in
-- model units) is emulated by pushing the MODEL away from the fixed default camera (-X) and
-- down (-Z). Mapping constants are globals, tunable in-game via /run DragonUI_NewEra.ej.CAM_*.
-- A hand MODEL_TWEAKS[displayID] = { cdist=, ctz=, facing=, mscale= } outlier always wins.
NE.ej.MODEL_TWEAKS = NE.ej.MODEL_TWEAKS or {}
NE.ej.DEFAULT_MODEL_SCALE = NE.ej.DEFAULT_MODEL_SCALE or 1
NE.ej.DEFAULT_CAM_DIST = NE.ej.DEFAULT_CAM_DIST or 2.2   -- when no MODEL_CAM entry (TBC bosses)
NE.ej.DEFAULT_CAM_TZ   = NE.ej.DEFAULT_CAM_TZ   or 0.35
NE.ej.CAM_X0 = NE.ej.CAM_X0 or 1.0    -- model X offset at cdist 0 (toward camera)
NE.ej.CAM_XK = NE.ej.CAM_XK or 0.55   -- X pushback per cdist unit
NE.ej.CAM_ZK = NE.ej.CAM_ZK or 0.9    -- Z drop per ctz unit

-- NE.ej.NormalizeModel(ma, displayID [, tier])
-- tier: 1 = Classic (display = creature NPC ID → SetCreature), 2+ = TBC/WotLK
--       (display = CreatureDisplayInfoID from retail EJ DB2 → SetDisplayInfo).
-- ma MUST already be shown before this is called — the 3.3.5a engine silently skips
-- model loads while the frame ancestor chain is hidden (cold-start, QuestNpcModel.lua).
function NE.ej.NormalizeModel(ma, displayID, tier)
  if not ma then return end
  local model = ma.model
  if not model then return end
  ma._userRotated = false
  -- Load persisted camera overrides once per session (DOWNPORT: NewEraDB → NE.db).
  if not NE.ej._tweaksLoaded and NE.db then
    for d, t in pairs(NE.db._ejTweaks or {}) do NE.ej.MODEL_TWEAKS[d] = t end
    if NE.db._ejGlobalMScale then NE.ej.DEFAULT_MODEL_SCALE = NE.db._ejGlobalMScale end
    NE.ej._tweaksLoaded = true
  end
  if not (displayID and displayID > 0) then
    pcall(model.ClearModel, model); model:Hide()
    return
  end
  local t = NE.ej.MODEL_TWEAKS[displayID] or {}
  local cam = (NE.ej.MODEL_CAM and NE.ej.MODEL_CAM[displayID]) or {}
  model.rotation = t.facing or 0
  local function applyCamera()
    pcall(function()
      if model.SetModelScale then model:SetModelScale(t.mscale or NE.ej.DEFAULT_MODEL_SCALE or 1) end
      local cdist = t.cdist or cam.cdist or NE.ej.DEFAULT_CAM_DIST
      local ctz   = t.ctz   or cam.ctz   or NE.ej.DEFAULT_CAM_TZ
      local x = (NE.ej.CAM_X0 or 1.0) - cdist * (NE.ej.CAM_XK or 0.55)
      local z = -ctz * (NE.ej.CAM_ZK or 0.9)
      if model.SetPosition then model:SetPosition(x, 0, z) end
      if model.SetFacing and not ma._userRotated then model:SetFacing(model.rotation or 0) end
    end)
  end

  -- API selection: Classic (tier 1) stores creature NPC IDs → SetCreature(npcID).
  -- TBC+ (tier 2+) stores JournalEncounterCreature.CreatureDisplayInfoID from retail EJ DB2
  -- → SetDisplayInfo(creatureDisplayInfoID), which is the standard WoW 3.3.5a API for loading
  -- a model by display ID (confirmed via WeakAuras.lua which calls SetDisplayInfo with display
  -- info IDs, not raw file IDs despite the misleading variable name in that shim).
  -- SetCreature is NOT used for TBC+ because it takes creature NPC IDs, not display info IDs
  -- (confirmed by DBM-GUI/QuestNpcModel usage, and by GetCompanionInfo returning NPC IDs which
  -- ezCollections passes to SetCreature for mount previews).
  local function loadModel()
    pcall(model.ClearModel, model)
    if tier and tier >= 2 then
      pcall(model.SetDisplayInfo, model, displayID)
    else
      pcall(model.SetCreature, model, displayID)
    end
  end

  ma._activeDisplayID = displayID   -- token to detect stale timer callbacks on boss switch
  loadModel()
  applyCamera()
  if model.HasScript and model:HasScript("OnModelLoaded") then
    model:SetScript("OnModelLoaded", applyCamera)
  end
  -- Belt-and-suspenders retry: the first load of a session can race the client's internal
  -- data lookup and come back empty. Re-issue once after a short delay.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.15, function()
      if ma._activeDisplayID ~= displayID then return end   -- boss was switched, ignore
      if model:IsShown() then
        loadModel()
        applyCamera()
      end
    end)
    C_Timer.After(0.5, function()
      if ma._activeDisplayID ~= displayID then return end
      applyCamera()
    end)
  end
  model:Show()
end

-- The single renderer: decides lore-landing vs per-boss content from (selBoss, tab)
local function refreshView()
  local f = NE.ej.frame
  if not (f and f.encounter and f.encounter.info) then return end
  local enc, info = f.encounter, f.encounter.info

  -- Tab availability. Tab 3 (the separate abilities page) is collapsed into tab 1 and never
  -- shown. Model(4) is BOSS-ONLY; on the instance landing only 1 + 2 are live.
  local enabled
  if not selBoss then
    enabled = { [1] = true, [2] = true, [3] = false, [4] = false }
  else
    enabled = { [1] = true, [2] = true, [3] = false, [4] = true  }
  end

  local tab = info.selectedTab or 1
  if not enabled[tab] then               -- current tab ghosted → jump to first available
    for _, id in ipairs({ 1, 2, 4 }) do if enabled[id] then tab = id; break end end
    info.selectedTab = tab
  end

  for _, t in ipairs(info.tabs) do
    local en = enabled[t.tabID] and true or false
    local on = (t.tabID == tab) and en
    setShown(t.selBG, on); setShown(t.selIcon, on); setShown(t.unselIcon, not on)
    if en then t:Enable() else t:Disable() end   -- DOWNPORT: no Button:SetEnabled on 3.3.5a
    t.unselIcon:SetDesaturated(not en); t.unselIcon:SetAlpha(en and 1 or 0.35)
    if t.selIcon.SetDesaturated then t.selIcon:SetDesaturated(not en) end
  end

  local c = info.content
  c.text:Hide(); c.lootScroll:Hide(); c.sectionScroll:Hide()
  if info.modelArea then info.modelArea:Hide() end
  -- Boss title in the header is hidden on Model AND Loot (that header hosts the loot
  -- filters, not the boss name) — matching retail.
  local hideBossTitle = (tab == 4 or tab == 2)
  if info.encounterTitle then
    info.encounterTitle:SetText(selBoss and selBoss.name or "")
    setShown(info.encounterTitle, (selBoss and not hideBossTitle) and true or false)
  end
  if info.rightHeader then setShown(info.rightHeader, tab ~= 4) end
  if info.difficultyDropdown then
    local hasDiff = info.hasHeroic or (info.diffOptions and #info.diffOptions > 0)
    local showDiff = (hasDiff and tab ~= 4) and true or false
    setShown(info.difficultyDropdown, showDiff)
    -- keep the collapsed label in sync -- PopulateEncounter may have just swapped instances
    -- (different diffOptions / a reset difficultyID) without the dropdown ever being opened.
    if showDiff and info.difficultyDropdown.GenerateMenu then info.difficultyDropdown:GenerateMenu() end
  end
  if info.lootFilter then
    setShown(info.lootFilter, tab == 2)   -- slot filter only on Loot
    -- The difficulty dropdown owns retail's top-right corner; slide the slot filter left
    -- when both are visible.
    info.lootFilter:ClearAllPoints()
    if info.difficultyDropdown and info.difficultyDropdown:IsShown() then
      info.lootFilter:SetPoint("TOPRIGHT", info.difficultyDropdown, "TOPLEFT", 24, 0)
    else
      info.lootFilter:SetPoint("TOPRIGHT", info, "TOPRIGHT", -2, -10)
    end
  end

  if not selBoss then
    if tab == 2 then            -- instance landing Loot = aggregated instance-wide drops
      enc.instance:Hide()       -- don't leave the lore artwork showing beneath the loot
      local agg, seen = {}, {}
      for _, e in ipairs((selInst and selInst.encounters) or {}) do
        for _, entry in ipairs(e.loot or {}) do
          local eid = (type(entry) == "table") and entry.id or entry
          if eid and not seen[eid] then seen[eid] = true; agg[#agg + 1] = entry end
        end
      end
      renderLoot({ loot = agg }); c.lootScroll:Show()
    else
      enc.instance:Show()       -- lore landing on the right page
    end
    return
  end
  enc.instance:Hide()

  if tab == 2 then            -- Loot
    renderLoot(selBoss); c.lootScroll:Show()
  elseif tab == 4 then        -- Model
    local ma = info.modelArea
    if ma then
      -- per-instance model backdrop (JournalInstance.BGFileDataID); default if unshipped
      local bgFD = selInst and selInst.bgFDID
      ma.bg:SetTexture(NE.tex.localFiles[bgFD] or NE.tex.localFiles[521743] or 521743)
      ma.name:SetText(selBoss.name or "")
      -- Show ma BEFORE NormalizeModel: the 3.3.5a engine silently skips SetCreature while the
      -- frame ancestor chain is hidden, so the model would never load if we called it first.
      ma:Show()
      local cr = selBoss.creatures and selBoss.creatures[1]
      NE.ej.NormalizeModel(ma, cr and cr.display, selInst and selInst.tier)
    else
      c.text:SetText("(no model)"); c.text:Show()
    end
  else                        -- tab 1 = lore description + ability sections
    if (selBoss.sections and #selBoss.sections > 0) or (selBoss.desc and selBoss.desc ~= "") then
      renderSections(selBoss); c.sectionScroll:Show()
    else
      c.text:SetText("(No abilities recorded for this encounter.)"); c.text:Show()
    end
  end
end

-- Public API
function NE.ej.SelectTab(id)
  local f = NE.ej.frame
  if not (f and f.encounter and f.encounter.info) then return end
  f.encounter.info.selectedTab = id
  refreshView()
end

function NE.ej.ShowBoss(enc)
  selBoss = enc
  if NE.ej.frame then NE.ej.frame._currentBoss = enc end
  applyBossHighlight()   -- keep the clicked boss row highlighted
  refreshView()
  if NE.ej.RefreshNavBar then NE.ej.RefreshNavBar() end   -- breadcrumb extends to the boss
end

-- "Show Map". DOWNPORT: only live if a NE.worldmap.ShowDungeonMap provider exists (the
-- NewEra dungeon-map overlay hasn't been ported); 3.3.5a has no classic/TBC dungeon maps and
-- no WorldMapFrame:SetMapID, so there is no native fallback.
function NE.ej.ShowMap(inst)
  if InCombatLockdown() then return end
  inst = inst or selInst
  if not inst then return end
  if NE.worldmap and NE.worldmap.ShowDungeonMap and inst.id and NE.worldmap.ShowDungeonMap(inst.id) then
    return
  end
end

function NE.ej.PopulateEncounter(inst)
  selInst, selBoss = inst, nil
  local enc = NE.ej.frame.encounter
  enc.instance.title:SetText(inst.name or "")
  if enc.info.instanceTitle then enc.info.instanceTitle:SetText(inst.name or "") end
  -- Multi-difficulty gate for the difficulty dropdown: TBC/WotLK dungeons run Normal + Heroic
  -- (hasHeroic, static 2-option list built in buildInfoPanel); WotLK raids run 10/25-Player,
  -- plus a separate Heroic mode on ICC/Ruby Sanctum/Trial of the Grand Crusader (inst.raidHeroic)
  -- -- a data-driven diffOptions list instead, since the option COUNT varies per raid.
  -- difficultyID always resets to 1 (Normal / 10-Player Normal) on entering a fresh instance.
  enc.info.difficultyID = 1
  if inst.isRaid and inst.tier == 3 then
    enc.info.hasHeroic = false
    local diffText = _G.ENCOUNTER_JOURNAL_DIFF_TEXT or "%d Player (%s)"
    local normalLbl, heroicLbl = _G.PLAYER_DIFFICULTY1 or "Normal", _G.PLAYER_DIFFICULTY2 or "Heroic"
    local opts = {
      { id = 1, size = 10, heroic = false, label = diffText:format(10, normalLbl) },
      { id = 2, size = 25, heroic = false, label = diffText:format(25, normalLbl) },
    }
    if inst.raidHeroic then
      opts[3] = { id = 3, size = 10, heroic = true, label = diffText:format(10, heroicLbl) }
      opts[4] = { id = 4, size = 25, heroic = true, label = diffText:format(25, heroicLbl) }
    end
    enc.info.diffOptions = opts
  else
    enc.info.hasHeroic = (NE.flavor == "tbc" and (inst.tier == 2 or inst.tier == 3) and not inst.isRaid) or false
    enc.info.diffOptions = nil
  end
  -- per-instance loading-screen lore background (LoreFileDataID)
  if inst.loreFDID and inst.loreFDID > 0 and enc.instance.loreBG then
    enc.instance.loreBG:SetTexture(NE.tex.localFiles[inst.loreFDID] or inst.loreFDID)
    enc.instance.loreBG:SetTexCoord(0, 0.7617187, 0, 0.65625)
  end
  enc.instance.lore:SetText(inst.desc or "")
  if enc.instance.loreChild then
    enc.instance.loreChild:SetHeight(math.max(1, (enc.instance.lore:GetStringHeight() or 0) + 4))
  end
  -- "Show Map" only when a dungeon-map provider can actually serve this instance.
  if enc.instance.mapButton then
    setShown(enc.instance.mapButton,
      (NE.worldmap and NE.worldmap.ShowDungeonMap and inst.id) and true or false)
  end
  -- dungeon-specific back-button portrait (the instance's splash under the ring)
  local ib = enc.info and enc.info.instanceButton
  if ib and ib.icon and inst.buttonFDID and inst.buttonFDID > 0 then
    ib.icon:SetTexture(NE.tex.localFiles[inst.buttonFDID] or inst.buttonFDID)
    NE.ej.SetButtonTexCoord(ib.icon, inst.buttonFDID, true)
  end
  fillBossList(inst)
  enc.info.selectedTab = 1
  refreshView()
end

function NE.ej.BuildEncounterPage(f)
  local enc = f.encounter
  if not enc or enc._neBuilt then return end
  enc._neBuilt = true
  -- pcall each: a failure in one panel must not skip the other.
  local okI = pcall(buildInfoPanel, enc)   -- info first = book backdrop; lore layers on the right
  local okL = pcall(buildLorePanel, enc)
  if not (okI and okL) and NE.Log then NE.Log("EJ", "BuildEncounterPage: info=%s lore=%s", tostring(okI), tostring(okL)) end
  -- retail layers instance ABOVE info; as plain children both default to enc+1 → equal
  -- sibling levels draw non-deterministically. Pin both to reproduce retail's split.
  local lvl = enc:GetFrameLevel()
  if enc.info then enc.info:SetFrameLevel(lvl) end
  if enc.instance then enc.instance:SetFrameLevel(lvl + 1) end
end
