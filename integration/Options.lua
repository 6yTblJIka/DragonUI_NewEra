-- DragonUI_NewEra/integration/Options.lua
-- Adds a "New Era" tab to the DragonUI options panel (the DragonUI_Options
-- companion addon). The tab lists one enable toggle per registered NewEra panel.
--
-- DragonUI_Options is a separate, possibly LoadOnDemand-ish addon: it may load
-- AFTER us, or already be loaded. We handle both: register now if its
-- OptionsPanel is present, otherwise hook ADDON_LOADED for "DragonUI_Options".
--
-- DOWNPORT: new glue; the 1.15 NewEra addon had a bespoke settings frame. We
-- proxy each panel's `enabled` flag into DragonUI's profile + PanelControls.

local NE = DragonUI_NewEra
if not NE then return end

local OPTIONS_ADDON = "DragonUI_Options"
local TAB_KEY       = "newera"
local TAB_TITLE     = "New Era"
local TAB_ORDER     = 16

-- The list the builder iterates is owned by Register.lua. Keep a safe handle.
NE.optionPanels = NE.optionPanels or {}

-- ----------------------------------------------------------------------------
-- builder(scroll): called by OptionsPanel each time the tab is shown.
-- `scroll` is an AceGUI ScrollFrame; controls are added via NE.dragon.PanelControls
-- (Controls:AddHeading / AddDescription / AddToggle, all of which :AddChild it).
-- Must never error when the panel list is empty.
-- ----------------------------------------------------------------------------
local function builder(scroll)
    local dragon = NE.dragon
    local C = dragon and dragon.PanelControls
    if not C then
        -- No PanelControls to render with; nothing we can safely draw.
        return
    end

    C:AddHeading(scroll, TAB_TITLE)
    C:AddDescription(scroll,
        "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. "
        .. "Panels appear here as their modules load.")
    if C.AddSpacer then C:AddSpacer(scroll) end

    -- (Per-window enable toggles live in the "Windows" section below; we intentionally do NOT also
    -- render NE.optionPanels here — that produced a redundant top-of-page "Character Panel" toggle.)

    -- ----------------------------------------------------------------------------
    -- Windows — enable/disable each replacement window. RELOAD-GATED: toggling only writes the flag;
    -- a disabled module simply isn't booted on the next /reload (the Blizzard default frame is used).
    -- ----------------------------------------------------------------------------
    if NE.modules and NE.modules.IsEnabled then
        C:AddHeading(scroll, "Windows")
        C:AddDescription(scroll,
            "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.")
        local WINDOWS = {
            { id = "character",   label = "Character panel" },
            { id = "Spellbook",   label = "Spellbook" },
            { id = "Talents",     label = "Talents" },
            { id = "Professions", label = "Professions" },
        }
        for _, w in ipairs(WINDOWS) do
            local id = w.id
            C:AddToggle(scroll, {
                label   = w.label,
                desc    = "Reload (/reload) to apply.",
                getFunc = function() return NE.modules.IsEnabled(id) and true or false end,
                setFunc = function(v)
                    if NE.modules.SetEnabled then pcall(NE.modules.SetEnabled, id, v) end
                end,
            })
        end
    end

    -- ----------------------------------------------------------------------------
    -- Window scaling — a mode dropdown (UI scale / none / custom) + a custom-size slider per window.
    -- Backed by NE.scale (NE.db.scale[window]); changes apply IMMEDIATELY to the live frame.
    -- ----------------------------------------------------------------------------
    if C.AddSpacer then C:AddSpacer(scroll) end
    C:AddHeading(scroll, "Window Scaling")
    local S = NE.scale
    if not S then
        -- core/Scale.lua isn't loaded — surface it instead of silently showing nothing.
        C:AddDescription(scroll,
            "Scaling controls are unavailable: the 'core\\Scale.lua' file isn't loaded. Make sure your "
            .. "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.")
    elseif not (C.AddDropdown and C.AddSlider) then
        C:AddDescription(scroll, "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).")
    else
        C:AddDescription(scroll,
            "Each window's size: \"Use UI scale\" follows the game's UI Scale slider, \"No scaling\" "
            .. "stays pixel-perfect, \"Custom\" uses its slider. The custom slider is greyed out and "
            .. "locked unless that window's mode is set to Custom.")
        local AceGUI = LibStub and LibStub("AceGUI-3.0")
        local MODES = { ui = "Use UI scale", none = "No scaling", custom = "Custom" }
        local WINDOWS = {
            { key = "character",   label = "Character" },
            { key = "spellbook",   label = "Spellbook" },
            { key = "talents",     label = "Talents" },
            { key = "professions", label = "Professions" },
        }

        -- One window's stacked controls: a centered column header, a mode dropdown, and a custom-scale
        -- slider that disables/re-enables live as the mode dropdown changes (no /reload needed).
        local function buildColumn(parent, key, label)
            if AceGUI then
                local hdr = AceGUI:Create("Heading")
                hdr:SetText(label)
                hdr:SetFullWidth(true)
                parent:AddChild(hdr)
            end
            local slider
            C:AddDropdown(parent, {
                label   = "Scale mode",
                values  = MODES,
                getFunc = function() local m = S.Get(key); return m end,
                setFunc = function(v)
                    S.SetMode(key, v)
                    if slider then slider:SetDisabled(v ~= "custom") end
                end,
            })
            slider = C:AddSlider(parent, {
                label    = "Custom scale",
                min      = S.MIN or 0.5, max = S.MAX or 1.5, step = 0.05,
                getFunc  = function() local _, c = S.Get(key); return c end,
                setFunc  = function(v) S.SetCustom(key, v) end,
                disabled = function() return S.Get(key) ~= "custom" end,
            })
        end

        if AceGUI then
            -- Three side-by-side columns (Character | Spellbook | Talents), each a vertical stack.
            local row = AceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")
            scroll:AddChild(row)
            for _, w in ipairs(WINDOWS) do
                local col = AceGUI:Create("SimpleGroup")
                col:SetRelativeWidth(0.32)
                col:SetLayout("List")
                row:AddChild(col)
                buildColumn(col, w.key, w.label)
            end
        else
            -- No AceGUI containers available: fall back to a flat vertical list.
            for _, w in ipairs(WINDOWS) do
                C:AddHeading(scroll, w.label)
                buildColumn(scroll, w.key, w.label)
            end
        end
    end
end
NE.OptionsBuilder = builder

-- ----------------------------------------------------------------------------
-- Registration with whichever DragonUI_Options instance is available.
-- ----------------------------------------------------------------------------
local registered = false

local function tryRegister()
    if registered then return true end
    local dragon = NE.dragon
    local panel = dragon and dragon.OptionsPanel
    if not (panel and type(panel.RegisterTab) == "function") then
        return false
    end
    local ok, err = pcall(panel.RegisterTab, panel, TAB_KEY, TAB_TITLE, builder, TAB_ORDER)
    if ok then
        registered = true
        return true
    end
    if NE._warn then NE._warn("OptionsPanel:RegisterTab failed: " .. tostring(err)) end
    return false
end

-- Case A: DragonUI_Options already loaded (OptionsPanel present) -> register now.
if not tryRegister() then
    -- Case B: hook ADDON_LOADED and register once DragonUI_Options arrives.
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        -- Retry on the DragonUI_Options load specifically, but also opportunistically
        -- on any load in case OptionsPanel appeared via a different addon name.
        if (name == OPTIONS_ADDON or NE.dragon and NE.dragon.OptionsPanel) and tryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
