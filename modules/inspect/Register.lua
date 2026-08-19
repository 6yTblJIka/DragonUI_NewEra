-- DragonUI_NewEra/modules/inspect/Register.lua — boot wiring for the inspect window reskin.
--
-- Blizzard_InspectUI is LoadOnDemand: it is pulled in by the FIRST InspectUnit() call, not at
-- login, so the reskin hangs off ADDON_LOADED (with a login check for the case where something
-- else has already loaded it). That is the same gate the 1.15 source used and the one CONTRACTS.md
-- §0 prescribes for LoadOnDemand frames.
--
-- Reload-gated, like every other window toggle: turning the module off writes the flag, and the
-- next /reload simply never boots it — leaving Blizzard's own inspect window untouched.

local NE = DragonUI_NewEra
if not NE or NE.disabled then return end

local I = NE.inspect
local L = NE.L
if not I then return end

local MODULE = "Inspect"

local function boot(event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= "Blizzard_InspectUI" then return end
    I.Apply()
  elseif event == "PLAYER_LOGIN" then
    if NE.IsAddOnLoaded and NE.IsAddOnLoaded("Blizzard_InspectUI") then I.Apply() end
  end
end

if NE.modules and NE.modules.Register then
  NE.modules.Register{
    name     = MODULE,
    default  = true,
    label    = L["Inspect window"],
    category = "Windows",
    -- Same string the options row renders (integration/Options.lua): one key, one translation.
    desc     = L["Modern frame, portrait and tabs on the inspect window, with its Character tab "
             .. "laid out like the character window. Reload (/reload) to apply."],
    events   = { "ADDON_LOADED", "PLAYER_LOGIN" },
    onBoot   = boot,
  }
end

-- ----------------------------------------------------------------------------
-- QA harness entry (optional; guarded). `open` needs a real, inspectable target — with none, the
-- test is a no-op rather than a failure, which is the honest result for a window that cannot be
-- opened on demand.
-- ----------------------------------------------------------------------------
if NE.qa then
  NE.qa.modules = NE.qa.modules or {}
  table.insert(NE.qa.modules, {
    name  = L["Inspect window"],
    frame = _G.InspectFrame,   -- nil until the LoadOnDemand addon loads; the harness reports that
    open  = function()
      if _G.InspectUnit and UnitExists("target") and CanInspect and CanInspect("target") then
        InspectUnit("target")
      end
    end,
    close = function()
      local f = _G.InspectFrame
      if f and f:IsShown() then
        if HideUIPanel then HideUIPanel(f) else f:Hide() end
      end
    end,
  })
end
