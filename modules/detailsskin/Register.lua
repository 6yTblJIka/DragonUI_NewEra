-- DragonUI_NewEra/modules/detailsskin/Register.lua — options + slash command for the Details! theme.
--
-- Replaces the source's two entry points (NewEra's install wizard checkbox and its /ne options
-- button, neither of which exists here) with the one this addon uses for everything: a section on
-- DragonUI's "New Era" tab, plus a slash command.
--
-- THERE IS NO ENABLE TOGGLE, and no NE.modules.Register entry. A reload-gated switch would be
-- describing something that does not happen on its own: installing the skin only makes it LIST in
-- Details' own skin dropdown, and nothing about the meter changes until the player asks for it
-- here or picks it there. Applying it is an action, so it is a button.

local NE = DragonUI_NewEra
local DS = NE and NE.detailsskin
local L  = NE and NE.L
if not (NE and DS) or NE.disabled then return end

NE.RegisterOptionSection({
  id    = "detailsskin",
  order = 47,
  build = function(scroll, C)
    if C.AddSpacer then C:AddSpacer(scroll) end
    C:AddHeading(scroll, L["Damage Meter Skin"])

    if not DS.IsDetailsLoaded() then
      C:AddDescription(scroll,
        L["|cffff5555Details! is not installed.|r This is a theme for the Details! Damage Meter, "
        .. "not a meter of its own — with Details! absent there is nothing to skin."])
      return
    end

    C:AddDescription(scroll,
      L["A retail-styled theme for |cffffcc55Details!|r, drawn with art from retail's own damage "
      .. "meter: a gold-titled header bar, class-coloured bars on a near-invisible panel, and "
      .. "abbreviated numbers. It is registered with Details! at login, so it also appears in "
      .. "Details!' own skin list under |cffffcc55New Era|r."])

    if C.AddButton then
      C:AddButton(scroll, {
        label    = L["Apply the New Era skin"],
        desc     = L["Switches every Details! window to the skin and sets K/M number abbreviation. "
                   .. "Window size and position stay yours — use Details!' own scale slider for "
                   .. "those. Your choice is remembered and put back after a reload (Details! does "
                   .. "not keep it on its own); picking another skin in Details! ends that. Run this "
                   .. "again after you customise something in Details! and want the theme back."],
        callback = function()
          if DS.Apply() then
            print("|cff1784d1New Era|r: " .. L["Details! skin applied."])
          else
            print("|cff1784d1New Era|r: " .. L["Could not apply the skin — Details! is not ready yet."])
          end
        end,
      })
    else
      C:AddDescription(scroll, L["Run |cffffcc55/nedetails|r to apply it."])
    end
  end,
})

-- ── Slash command ───────────────────────────────────────────────────────────────────────────────
--
-- Same action as the button, reachable without opening the options — and the only way in if this
-- DragonUI build's options kit has no AddButton.

SLASH_NEDETAILS1 = "/nedetails"
SlashCmdList["NEDETAILS"] = function()
  if not DS.IsDetailsLoaded() then
    print("|cff1784d1New Era|r: " .. L["Details! is not installed."])
    return
  end
  if DS.Apply() then
    print("|cff1784d1New Era|r: " .. L["Details! skin applied."])
  else
    print("|cff1784d1New Era|r: " .. L["Could not apply the skin — Details! is not ready yet."])
  end
end
