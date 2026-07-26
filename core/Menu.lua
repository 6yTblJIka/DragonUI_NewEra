-- DragonUI_NewEra/core/Menu.lua — a MenuUtil-shaped context-menu builder over 3.3.5a's
-- UIDropDownMenu.
--
-- WHY THIS EXISTS. Every menu in the NewEra source is written against retail's MenuUtil builder
-- API: a generator function receives a root description and calls `root:CreateTitle`,
-- `CreateButton`, `CreateRadio`, `CreateCheckbox`, `CreateDivider`, nesting freely by adding
-- children to a returned description. None of that exists here. Reimplementing the *API* once, in
-- ~200 lines, lets each of those generators port close to verbatim instead of being hand-rewritten
-- into UIDropDownMenu's init-callback idiom — which is both more code overall and a fresh chance to
-- get the level plumbing wrong at every site.
--
-- WHICH BACKEND. Prefer ClassicAPI's `C_UIDropDownMenu_*`. The native 3.3.5a one hard-caps at
-- C_UIDROPDOWNMENU_MAXLEVELS = 2, and the Cooldown Manager's ready-sound menu is three deep
-- (item -> Ready Sound -> category -> entry). ClassicAPI's copy grows the cap on demand inside
-- C_UIDropDownMenu_CreateFrames, which is exactly the constraint that decides this. The native
-- functions are kept as a fallback so the shim still works (two levels deep) if ClassicAPI is
-- absent; the two APIs are otherwise the same shape, differing only in the list-frame name prefix.
--
-- THE TREE IS SEPARATE FROM THE RENDER. `NE.menu.BuildRoot` runs a generator and returns a plain
-- node tree with no widget touched. That is what makes menu CONTENT testable offline: a test can
-- build the tree, walk it, and invoke a leaf's callback to assert the wiring, without stubbing any
-- of UIDropDownMenu.
--
-- SUBMENU PARENTS ARE `notClickable`. A row with children gets hasArrow + notClickable, not a
-- no-op func. UIDropDownMenu's OnClick toggles the row's Check texture *before* it looks at func,
-- so a clickable-but-inert parent paints a stray checkmark on itself. Disabling the row leaves
-- OnEnter (which is what opens the submenu) firing normally.
--
-- RADIOS REFRESH THEMSELVES. C_UIDropDownMenu_Refresh keys off frame.selectedName/ID/Value, which
-- says nothing about function-valued `checked`, so it cannot be used here. Instead a radio's click
-- re-evaluates every sibling's predicate and repaints the check textures directly.

local NE = DragonUI_NewEra
NE.menu = NE.menu or {}

-- ── node tree ───────────────────────────────────────────────────────────────────────────────────

local Node = {}
Node.__index = Node

local function newNode(kind, text)
  return setmetatable({ kind = kind, text = text, children = {} }, Node)
end

function Node:Add(node)
  self.children[#self.children + 1] = node
  return node
end

function Node:CreateTitle(text)
  return self:Add(newNode("title", text))
end

function Node:CreateDivider()
  return self:Add(newNode("divider"))
end

-- A button with children becomes a submenu; the callback is then ignored, matching MenuUtil.
function Node:CreateButton(text, onClick, data)
  local n = newNode("button", text)
  n.onClick, n.data = onClick, data
  return self:Add(n)
end

function Node:CreateRadio(text, isSelected, onClick, data)
  local n = newNode("radio", text)
  n.isSelected, n.onClick, n.data = isSelected, onClick, data
  return self:Add(n)
end

function Node:CreateCheckbox(text, isSelected, onClick, data)
  local n = newNode("checkbox", text)
  n.isSelected, n.onClick, n.data = isSelected, onClick, data
  return self:Add(n)
end

-- First child with this exact text. For callers that want to drive a built menu (tests, mostly)
-- without counting indices.
function Node:Child(text)
  for _, c in ipairs(self.children) do
    if c.text == text then return c end
  end
  return nil
end

function Node:Invoke()
  if self.onClick then self.onClick(self.data) end
end

NE.menu.Node = Node

-- generator(owner, root, ...) — MenuUtil's signature. Our generators ignore `owner`.
function NE.menu.BuildRoot(generator, owner, ...)
  if type(generator) ~= "function" then return nil end
  local root = newNode("root")
  generator(owner, root, ...)
  NE.menu._lastRoot = root   -- test seam
  return root
end

-- ── backend ─────────────────────────────────────────────────────────────────────────────────────

local B   -- resolved on first use; the globals do not exist until ClassicAPI has loaded

local function backend()
  if B ~= nil then return B or nil end
  if _G.C_UIDropDownMenu_AddButton and _G.C_ToggleDropDownMenu then
    B = {
      prefix     = "C_DropDownList",
      template   = "C_UIDropDownMenuTemplate",
      CreateInfo = _G.C_UIDropDownMenu_CreateInfo,
      AddButton  = _G.C_UIDropDownMenu_AddButton,
      Initialize = _G.C_UIDropDownMenu_Initialize,
      Toggle     = _G.C_ToggleDropDownMenu,
      CloseAll   = _G.C_CloseDropDownMenus,
    }
  elseif _G.UIDropDownMenu_AddButton and _G.ToggleDropDownMenu then
    -- Two levels only. Enough for a flat menu, not for the sound picker.
    B = {
      prefix     = "DropDownList",
      template   = "UIDropDownMenuTemplate",
      CreateInfo = _G.UIDropDownMenu_CreateInfo,
      AddButton  = _G.UIDropDownMenu_AddButton,
      Initialize = _G.UIDropDownMenu_Initialize,
      Toggle     = _G.ToggleDropDownMenu,
      CloseAll   = _G.CloseDropDownMenus,
    }
  else
    B = false
  end
  return B or nil
end

local function listButton(level, index)
  local b = backend()
  return b and _G[b.prefix .. level .. "Button" .. index] or nil
end

-- Repaint the check/radio marks for one open level from their predicates. Called after a radio or
-- checkbox fires, because the built-in OnClick only knows how to toggle the row you clicked.
local function refreshChecks(level)
  local b = backend()
  local list = b and _G[b.prefix .. level]
  if not list then return end
  for i = 1, (list.numButtons or 0) do
    local btn = listButton(level, i)
    local node = btn and btn._neNode
    if node and node.isSelected then
      local on = node.isSelected(node.data) and true or false
      local check = _G[btn:GetName() .. "Check"]
      if check then
        if node.kind == "radio" then
          check:SetTexture("Interface\\Buttons\\UI-RadioButton")
          check:SetTexCoord(on and 0.25 or 0, on and 0.5 or 0.25, 0, 1)
          if check.SetDesaturated then check:SetDesaturated(not on) end
          check:SetAlpha(on and 1 or 0.25)
          check:Show()
        elseif on then
          check:Show()
        else
          check:Hide()
        end
      end
      if on then btn:LockHighlight() else btn:UnlockHighlight() end
    end
  end
end

-- ── render ──────────────────────────────────────────────────────────────────────────────────────

-- UIDropDownMenu calls this once per open level, handing back whatever we stashed in info.menuList
-- for the parent row. Stashing the node itself is what gives us arbitrary nesting for free.
local function initLevel(frame, level, menuList)
  local b = backend()
  if not b then return end
  level = level or 1
  local node = menuList or frame._neRoot
  if not node then return end

  for _, child in ipairs(node.children) do
    local info = b.CreateInfo()
    local kind = child.kind

    if kind == "divider" then
      -- No divider primitive on this client. A disabled blank row reads as one.
      info.text, info.isTitle, info.notCheckable, info.disabled = " ", true, true, 1
    elseif kind == "title" then
      info.text, info.isTitle, info.notCheckable, info.disabled = child.text, true, true, 1
    elseif #child.children > 0 then
      info.text = child.text
      info.notCheckable = true
      info.hasArrow = true
      info.notClickable = true    -- see header: keeps OnClick from painting a stray check
      info.menuList = child
    elseif child.isSelected then
      info.text = child.text
      info.isRadio = (kind == "radio") or nil
      info.isNotRadio = (kind ~= "radio") or nil
      info.checked = function() return child.isSelected(child.data) and true or false end
      info.keepShownOnClick = true
      info.func = function()
        if child.onClick then child.onClick(child.data) end
        refreshChecks(level)
      end
    else
      info.text = child.text
      info.notCheckable = true
      info.func = function() if child.onClick then child.onClick(child.data) end end
    end

    b.AddButton(info, level)

    -- AddButton bumps numButtons; that is the index of the row it just wrote.
    local list = _G[b.prefix .. level]
    local btn = list and listButton(level, list.numButtons or 0)
    if btn then btn._neNode = child end
  end
end

-- One shared, never-shown anchor frame. UIDropDownMenu needs a "dropdown" object to hang the
-- initialize function and the open state off; it is not the thing the player sees.
local function anchorFrame()
  local b = backend()
  if not b then return nil end
  if NE.menu._frame then return NE.menu._frame end
  local f = CreateFrame("Frame", "NE_ContextMenu", UIParent, b.template)
  f:Hide()
  NE.menu._frame = f
  return f
end

function NE.menu.Close(level)
  local b = backend()
  if b and b.CloseAll then b.CloseAll(level or 1) end
end

-- Open a cursor-anchored context menu. Always opens: closing first means right-clicking a second
-- item while the first item's menu is up switches to it instead of just dismissing.
function NE.menu.OpenContext(generator, owner, ...)
  local b, f = backend(), anchorFrame()
  if not (b and f) then return nil end
  f._neRoot = NE.menu.BuildRoot(generator, owner, ...)
  if not f._neRoot then return nil end
  f._neAnchor = nil
  b.CloseAll(1)
  b.Initialize(f, initLevel, "MENU")
  b.Toggle(1, nil, f, "cursor", 0, 0)
  return f
end

-- Open anchored to a frame, with toggle semantics — the cog-button behaviour, where clicking the
-- same button again dismisses. `spec` = { point, relativePoint, x, y }.
function NE.menu.ToggleAnchored(generator, anchor, spec, owner, ...)
  local b, f = backend(), anchorFrame()
  if not (b and f and anchor) then return nil end
  spec = spec or {}

  -- Reusing one anchor frame means "is a menu open?" is global. If the open one belongs to some
  -- other trigger, this click should switch to us, not dismiss theirs.
  if f._neAnchor ~= anchor then b.CloseAll(1) end
  f._neAnchor = anchor

  f._neRoot = NE.menu.BuildRoot(generator, owner, ...)
  if not f._neRoot then return nil end

  -- C_ToggleDropDownMenu reads these off the dropdown frame in preference to its arguments.
  f.point         = spec.point or "TOPRIGHT"
  f.relativePoint = spec.relativePoint or "BOTTOMRIGHT"
  f.relativeTo    = nil
  f.xOffset       = spec.x or 0
  f.yOffset       = spec.y or -2

  b.Initialize(f, initLevel, "MENU")
  b.Toggle(1, nil, f, anchor, f.xOffset, f.yOffset)
  return f
end

function NE.menu.IsAvailable() return backend() ~= nil end
