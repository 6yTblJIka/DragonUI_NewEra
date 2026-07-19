-- DragonUI_NewEra/modules/encounterjournal/Support.lua — 3.3.5a stand-ins for the NewEra
-- Core pieces the Encounter Journal leans on that this addon hasn't ported elsewhere.
--
-- DOWNPORT (new file, no 1.15 counterpart):
--   * NE.tooltip.Wire       — NewEra's shared tooltip wiring helper (feature-gated there; we
--                             provide the minimal surface the EJ uses).
--   * NE.ej.CreateDropdown  — replaces retail's CreateFrame("DropdownButton", ...,
--                             "WowStyle1DropdownTemplate"). Wraps 3.3.5a's native
--                             UIDropDownMenu machinery behind the retail-ish surface the
--                             ported call sites use: SetupMenu(generator) with
--                             root:CreateRadio(label, isSelected, onSelect), GenerateMenu()
--                             (refreshes the collapsed text), SetDefaultText(text).
--   * NE.ej.PrimeItem / NE.ej.SchedulePrimedRefresh — item-cache warming. 3.3.5a has no
--                             GET_ITEM_INFO_RECEIVED event; an uncached GetItemInfo(id) stays
--                             nil until the server answers an item query. Touching the item
--                             via a hidden tooltip's SetHyperlink issues that query; a short
--                             C_Timer poll re-renders the loot list as answers stream in.

local NE = DragonUI_NewEra
if not NE then return end

NE.ej = NE.ej or {}

-- ---------------------------------------------------------------------------------------
-- Tooltip wiring (subset of NewEra Core/Tooltip.lua used by the EJ: text or callback form).
-- ---------------------------------------------------------------------------------------
NE.tooltip = NE.tooltip or {}
if not NE.tooltip.Wire then
  function NE.tooltip.Wire(frame, tip, opts)
    local anchor = (opts and opts.anchor) or "ANCHOR_RIGHT"
    frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, anchor)
      if type(tip) == "function" then
        tip(self, GameTooltip)
      else
        GameTooltip:SetText(tip, 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
end

-- ---------------------------------------------------------------------------------------
-- Dropdown: retail SetupMenu/CreateRadio surface over 3.3.5a UIDropDownMenu.
-- UIDropDownMenuTemplate REQUIRES a global name (its children are found via _G lookups).
-- ---------------------------------------------------------------------------------------
local ddSerial = 0
function NE.ej.CreateDropdown(parent, name, menuWidth)
  if not name then
    ddSerial = ddSerial + 1
    name = "NE_EJDropdown" .. ddSerial
  end
  local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
  dd._menuWidth = menuWidth or 130

  -- The probe root: runs the generator only to find the selected radio's label.
  local function selectedLabel()
    if not dd._generator then return nil end
    local chosen
    local probe = {
      CreateRadio = function(_, label, isSelected)
        if not chosen and type(isSelected) == "function" then
          local ok, sel = pcall(isSelected)
          if ok and sel then chosen = label end
        end
      end,
    }
    pcall(dd._generator, dd, probe)
    return chosen
  end

  -- Refresh the collapsed text from the generator's selected radio (retail's auto text).
  function dd:GenerateMenu()
    local label = selectedLabel() or self._defaultText
    if label then UIDropDownMenu_SetText(self, label) end
  end

  function dd:SetDefaultText(text)
    self._defaultText = text
    if not selectedLabel() then UIDropDownMenu_SetText(self, text) end
  end

  function dd:SetupMenu(generator)
    self._generator = generator
    UIDropDownMenu_Initialize(self, function()
      local root = {
        CreateRadio = function(_, label, isSelected, onSelect)
          local info = UIDropDownMenu_CreateInfo()
          info.text = label
          local ok, sel = pcall(isSelected)
          info.checked = (ok and sel) and true or false
          info.func = function()
            if onSelect then onSelect() end
            dd:GenerateMenu()
          end
          UIDropDownMenu_AddButton(info)
        end,
      }
      generator(self, root)
    end)
    UIDropDownMenu_SetWidth(self, self._menuWidth)
    self:GenerateMenu()
  end

  return dd
end

-- ---------------------------------------------------------------------------------------
-- Item-cache warming (the GET_ITEM_INFO_RECEIVED substitute).
-- ---------------------------------------------------------------------------------------
local primeTip   -- hidden tooltip whose SetHyperlink forces the client to query the item
local primed = {}
function NE.ej.PrimeItem(id)
  if not id or primed[id] then return end
  primed[id] = true
  if not primeTip then
    primeTip = CreateFrame("GameTooltip", "NE_EJItemPrimeTooltip", UIParent, "GameTooltipTemplate")
    primeTip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  -- pcall: a bogus id must never error out of a render pass (the server just won't answer).
  pcall(primeTip.SetHyperlink, primeTip, "item:" .. id)
end

-- Poll while a loot view has unresolved items: `check()` returns true when another pass is
-- wanted; `render()` re-renders. Bounded so a permanently-unanswered id can't tick forever.
local pollTicket = 0
function NE.ej.SchedulePrimedRefresh(check, render)
  pollTicket = pollTicket + 1
  local ticket, tries = pollTicket, 0
  local function tick()
    if ticket ~= pollTicket then return end     -- superseded by a newer view
    if not check() then return end
    render()
    tries = tries + 1
    if tries < 20 and check() and C_Timer and C_Timer.After then
      C_Timer.After(0.3, tick)
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.3, tick) end
end
