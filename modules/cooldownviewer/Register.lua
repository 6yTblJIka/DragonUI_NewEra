-- DragonUI_NewEra/modules/cooldownviewer/Register.lua — DragonUI wiring for the Cooldown Manager.
--
-- Replaces NewEra/CooldownViewer/EditModeRegister.lua, which is written against `NE.editmode` — a
-- 6,441-line reimplementation of retail Edit Mode this addon does not have and will not port (see
-- PORT_PLAN.md §B1). The two things that file delivered are re-homed:
--
--   position  -> DragonUI's MoversSystem, reached through NE.RegisterPanel (CONTRACTS §4: panel
--                modules never touch DragonUI internals directly)
--   settings  -> the New Era options tab, via NE.RegisterOptionSection
--
-- Dropped with Edit Mode, deliberately: bottom-managed stacking (EM.RegisterBottomManaged — the
-- viewers would rise above the action-bar tower as bars are added; DragonUI has no equivalent, so
-- the viewers simply stay where the user puts them), and the retail settings-int codec.

local NE = DragonUI_NewEra
local M  = NE.cooldownviewer

-- All four retail viewers. essential/utility read spell cooldowns from the curated class lists;
-- buffIcon/buffBar read live auras (Phase 3) and need no class data.
local VIEWERS = {
  { category = "essential", id = "CooldownViewerEssential", label = "Essential Cooldowns",
    desc = "Offensive burst and damage cooldowns.", order = 40 },
  { category = "utility",   id = "CooldownViewerUtility",   label = "Utility Cooldowns",
    desc = "Defensives, interrupts, CC and escapes.", order = 41 },
  { category = "buffIcon",  id = "CooldownViewerBuffIcon",  label = "Buff Icons",
    desc = "Short-duration buffs and procs, as icons.", order = 42, aura = true },
  { category = "buffBar",   id = "CooldownViewerBuffBar",   label = "Buff Bars",
    desc = "Short-duration buffs and procs, as depleting bars.", order = 43,
    aura = true, bar = true },
}
M.VIEWER_SPECS = VIEWERS

-- ── Frames + edit mode ──────────────────────────────────────────────────────────────────────────
--
-- TIMING: registration runs at PLAYER_LOGIN, not at file load. Every other NewEra module does the
-- same (see modules/guild/Window.lua, modules/auctionhouse/Window.lua) because DragonUI's AceDB
-- profile — which the position round-trip reads and writes — is not guaranteed ready while our
-- files are still executing.
--
-- SEAM: NE.RegisterHUDFrame, not NE.RegisterPanel. RegisterPanel wires a MoversSystem mover, and
-- `/dui edit` does not drive MoversSystem at all — it drives addon.EditableFrames. See the comment
-- block on NE.RegisterHUDFrame in integration/Register.lua for the full detail. Registering a HUD
-- frame with RegisterPanel produces a handle that is silently never shown.

local booted = false

local function boot()
  if booted then return end
  booted = true

  -- Before anything reads a spell list: clear custom lists that were auto-seeded by the old
  -- GetItemMeta side effect. They shadow the curated tables and would hide the whole WotLK seed on
  -- any character that had run an earlier build. Versioned, so it runs once.
  if M.MigrateStaleCustomLists then M.MigrateStaleCustomLists() end

  for _, spec in ipairs(VIEWERS) do
    local frame = spec.aura and M.CreateBuffViewer(spec.category) or M.CreateViewer(spec.category)
    if not frame then
      if NE.Log then NE.Log("CDM", "viewer '" .. spec.category .. "' failed to build") end
    else

      NE.RegisterHUDFrame({
        name    = spec.id,
        frame   = frame,
        section = "widgets",
        key     = "ne" .. spec.id,
        defaultPoint = {
          point = "BOTTOM", relativePoint = "BOTTOM",
          -- BuffBar sits off to the side in retail's preset; the rest are centred.
          x = (spec.category == "buffBar") and 420 or 0,
          y = M.VIEWER_DEFAULT_Y[spec.category] or 300,
        },
        -- Demo content while the editor is open. Essential/Utility would otherwise be empty for a
        -- character who hasn't learned those spells (or any Death Knight, pending Phase 2), and the
        -- aura viewers are empty by nature whenever no short buff happens to be up.
        showTest = function()
          frame._editPreview = true
          frame:Show()
          frame:Rebuild()
        end,
        hideTest = function()
          frame._editPreview = false
          frame:Rebuild()
          frame:UpdateVisibility()
        end,
      })

      frame:RefreshLayout()
      frame:UpdateVisibility()
    end
  end

  -- The learn-gate reads the spellbook table (core/SpellRanks.lua). Re-source every viewer once
  -- that table has been rebuilt — training a rank, switching spec or respeccing all change what
  -- the player knows, and the viewers must follow.
  if NE.spellbook and NE.spellbook.OnRebuilt then
    NE.spellbook.OnRebuilt(function()
      M.InvalidateCuratedCache()
      M.RefreshActiveViewer()
    end)
  end
end

-- ── Diagnostic ──────────────────────────────────────────────────────────────────────────────────
-- /necdm — report, per curated spell for the player's class, exactly what the learn-gate decided
-- and why. Added after a report that talent-granted abilities (Penance on Disc, Guardian Spirit on
-- Holy) and level-squished abilities (Divine Hymn at 60) were being filtered out: guessing at which
-- of the three checks failed is far slower than printing all three.
SLASH_NECDM1 = "/necdm"
SlashCmdList["NECDM"] = function()
  local _, class = UnitClass("player")
  local SB = NE.spellbook
  local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1CDM|r " .. msg) end

  say(("class=%s  spellbook built=%s  names=%d"):format(
    tostring(class),
    tostring(SB and SB.built),
    (function() local n = 0; for _ in pairs(SB and SB.KNOWN_NAMES or {}) do n = n + 1 end; return n end)()))

  for _, category in ipairs({ "essential", "utility" }) do
    local source = M.SPELL_DATA_BY_CATEGORY and M.SPELL_DATA_BY_CATEGORY[category]
    local list = source and source[class] or {}
    local shown = M.GetActiveSpellList(category)
    local inShown = {}
    for _, id in ipairs(shown) do inShown[id] = true end

    -- Report whether a CUSTOM list is overriding the curated table. Its absence from the first
    -- version of this command is why a spell could report book=true on every check and still be
    -- hidden: the gate was fine, the list it was gating had been replaced.
    local custom = M.GetCustomList(category, class)
    say(("|cffffcc55%s|r — %d curated, %d shown%s"):format(
      category, #list, #shown,
      custom and ("  |cffff5555[custom list active: %d entries — curated table IGNORED]|r"):format(#custom) or ""))
    for _, id in ipairs(list) do
      local name = GetSpellInfo(id)
      local book = name and SB and SB.IsSpellNameKnown and SB.IsSpellNameKnown(name)
      local known = IsSpellKnown and IsSpellKnown(id)
      local byname = name and GetSpellInfo(name) ~= nil
      if not inShown[id] then
        say(("   |cffff5555hidden|r %-24s id=%-6d book=%-5s IsSpellKnown=%-5s byName=%s"):format(
          tostring(name or "?"), id, tostring(book), tostring(known), tostring(byname)))
      end
    end
  end
end

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:SetScript("OnEvent", function()
  local ok, err = pcall(boot)
  if not ok and NE.Log then NE.Log("CDM", "boot failed: " .. tostring(err)) end
end)

-- ── Options ─────────────────────────────────────────────────────────────────────────────────────

-- The ten retail Edit Mode settings, per viewer. Order and ranges match
-- EditModeSettingDisplayInfo.lua so a player who knows retail finds what they expect.
local function buildViewerControls(parent, C, spec)
  local frameID = M.FRAME_ID[spec.category]

  local function get(key) return M.GetOpt(frameID, key) end
  local function set(key)
    return function(v) M.SetOpt(frameID, key, v) end
  end

  C:AddToggle(parent, {
    label   = "Enabled",
    desc    = "Show this cooldown viewer.",
    getFunc = function() return M.IsCategoryEnabled(spec.category) end,
    setFunc = function(v) M.SetCategoryEnabled(spec.category, v) end,
  })

  if C.AddDropdown then
    C:AddDropdown(parent, {
      label   = "Orientation",
      values  = { horizontal = "Horizontal", vertical = "Vertical" },
      getFunc = function() return get("orientation") end,
      setFunc = set("orientation"),
    })
    C:AddDropdown(parent, {
      label   = "Icon direction",
      values  = { right = "Right", left = "Left" },
      getFunc = function() return get("iconDirection") end,
      setFunc = set("iconDirection"),
    })
    C:AddDropdown(parent, {
      label   = "Visibility",
      values  = { always = "Always", incombat = "In Combat", hidden = "Hidden" },
      getFunc = function() return get("visibleSetting") end,
      setFunc = set("visibleSetting"),
    })
  end

  if C.AddSlider then
    C:AddSlider(parent, {
      label   = "Icon limit",
      min = 1, max = 20, step = 1,
      getFunc = function() return get("iconLimit") end,
      setFunc = set("iconLimit"),
    })
    C:AddSlider(parent, {
      label   = "Icon size (%)",
      min = 50, max = 200, step = 10,
      getFunc = function() return get("iconSize") end,
      setFunc = set("iconSize"),
    })
    C:AddSlider(parent, {
      label   = "Icon padding (px)",
      min = 0, max = 14, step = 1,
      getFunc = function() return get("iconPadding") end,
      setFunc = set("iconPadding"),
    })
    C:AddSlider(parent, {
      label   = "Opacity (%)",
      min = 50, max = 100, step = 1,
      getFunc = function() return get("opacity") end,
      setFunc = set("opacity"),
    })
  end

  C:AddToggle(parent, {
    label   = "Show timer",
    desc    = "Draw the countdown number on each icon.",
    getFunc = function() return get("showTimer") and true or false end,
    setFunc = set("showTimer"),
  })
  C:AddToggle(parent, {
    label   = "Show tooltips",
    desc    = "Show a tooltip when hovering an icon.",
    getFunc = function() return get("showTooltips") and true or false end,
    setFunc = set("showTooltips"),
  })
  -- Hide When Inactive only takes effect on the aura viewers: retail's Essential/Utility templates
  -- do not set allowHideWhenInactive, so those always show every known cooldown.
  C:AddToggle(parent, {
    label   = "Hide when inactive",
    desc    = spec.aura
      and "Show a slot only while its aura is active."
      or  "No effect here — Essential and Utility always show known cooldowns, matching retail.",
    getFunc = function() return get("hideWhenInactive") and true or false end,
    setFunc = set("hideWhenInactive"),
  })

  -- Bar-only settings (retail exposes these on the BuffBar system alone).
  if spec.bar then
    if C.AddDropdown then
      C:AddDropdown(parent, {
        label   = "Bar content",
        values  = { iconAndName = "Icon and Name", iconOnly = "Icon Only", nameOnly = "Name Only" },
        getFunc = function() return get("barContent") end,
        setFunc = set("barContent"),
      })
    end
    if C.AddSlider then
      C:AddSlider(parent, {
        label   = "Bar width (%)",
        min = 50, max = 200, step = 5,
        getFunc = function() return get("barWidthScale") end,
        setFunc = set("barWidthScale"),
      })
    end
  end
end

NE.RegisterOptionSection({
  id    = "cooldownviewer",
  order = 40,
  build = function(scroll, C)
    if C.AddSpacer then C:AddSpacer(scroll) end
    C:AddHeading(scroll, "Cooldown Manager")
    C:AddDescription(scroll,
      "Retail's Cooldown Manager, driven from curated per-class cooldown lists. Drag the viewers "
      .. "with DragonUI's editor mode to reposition them.")

    local AceGUI = LibStub and LibStub("AceGUI-3.0")
    if AceGUI then
      local row = AceGUI:Create("SimpleGroup")
      row:SetFullWidth(true)
      row:SetLayout("Flow")
      scroll:AddChild(row)
      for _, spec in ipairs(VIEWERS) do
        local col = AceGUI:Create("SimpleGroup")
        col:SetRelativeWidth(0.49)
        col:SetLayout("List")
        row:AddChild(col)
        local hdr = AceGUI:Create("Heading")
        hdr:SetText(spec.label)
        hdr:SetFullWidth(true)
        col:AddChild(hdr)
        buildViewerControls(col, C, spec)
      end
    else
      for _, spec in ipairs(VIEWERS) do
        C:AddHeading(scroll, spec.label)
        buildViewerControls(scroll, C, spec)
      end
    end

    -- Aura auto-tracking. The buff viewers have no curated list: any player buff shorter than the
    -- auto-track window shows automatically, which is what makes trinket/potion/proc buffs work
    -- without enumerating them in advance.
    if C.AddSpacer then C:AddSpacer(scroll) end
    C:AddHeading(scroll, "Buff tracking")
    C:AddDescription(scroll,
      ("Buff Icons and Buff Bars automatically track any buff on you lasting %d seconds or less. "):format(
        M.BUFF_TRACK_MAX_DURATION or 120)
      .. "Longer buffs and permanent toggles are ignored, so the viewers stay quiet out of combat.")

    C:AddToggle(scroll, {
      label   = "Auto-track short buffs",
      desc    = "Turn off to show only auras you have explicitly assigned.",
      getFunc = function() return M.IsAutoTrackBuffs() end,
      setFunc = function(v) M.SetAutoTrackBuffs(v) end,
    })
    if C.AddDropdown then
      C:AddDropdown(scroll, {
        label   = "Show auto-tracked buffs as",
        values  = { both = "Both icons and bars", icon = "Icons only", bar = "Bars only" },
        getFunc = function() return M.AutoTrackDest() end,
        setFunc = function(v) M.SetAutoTrackDest(v) end,
      })
    end

    C:AddToggle(scroll, {
      label   = "Reset tracked spells and auras",
      desc    = "Clear per-character spell-list overrides and aura assignments, falling back to the "
                .. "curated defaults and the auto-track window. Does not move or resize the viewers.",
      getFunc = function() return false end,
      setFunc = function() M.ResetTracking() end,
    })
  end,
})
