-- DragonUI_NewEra/integration/Register.lua
-- The single DragonUI handshake every NewEra panel module routes through.
--
-- Later-sprint panels NEVER touch DragonUI internals directly. They call
--   NE.RegisterPanel(spec)
-- and this file wires that spec into DragonUI's ModuleRegistry, MoversSystem,
-- and our own boot dispatcher + QA harness + options list. Every base-API call
-- is defensively guarded so a missing/renamed base symbol logs a warning instead
-- of erroring (load order between the parallel-built addon parts must never crash).
--
-- DOWNPORT: this whole file is new glue (no 1.15 NewEra counterpart); the 1.15
-- addon had its own settings UI, here we proxy into DragonUI's unified UX.

local NE = DragonUI_NewEra
if not NE then return end

-- ----------------------------------------------------------------------------
-- Small logging helper. Prefer DragonUI's :Print / :Error if present, else
-- fall back to DEFAULT_CHAT_FRAME so a missing base API still surfaces.
-- ----------------------------------------------------------------------------
local function warn(msg)
    local dragon = NE.dragon
    if dragon and type(dragon.Error) == "function" then
        -- DragonUI:Error(...) is a method (self-call).
        local ok = pcall(dragon.Error, dragon, "[NewEra] " .. msg)
        if ok then return end
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc55DragonUI_NewEra|r: " .. msg)
    end
end
NE._warn = NE._warn or warn

-- The ordered list the Options builder renders one toggle per panel from.
-- Each entry: { id, title, desc, refresh, order }. Kept here (not in Options.lua)
-- so it is populated even if DragonUI_Options never loads.
NE.optionPanels = NE.optionPanels or {}

-- ----------------------------------------------------------------------------
-- DB bootstrap. Panel ENABLE flags + the per-panel `enabled` toggles live in
-- DragonUI's profile (DragonUIDB) under profile.newera so the whole UX is
-- unified. Our own DragonUI_NewEraDB only holds per-char panel state.
-- ----------------------------------------------------------------------------
local function ensureProfile()
    local dragon = NE.dragon
    if not (dragon and dragon.db and dragon.db.profile) then
        return nil
    end
    local profile = dragon.db.profile
    if type(profile.newera) ~= "table" then
        profile.newera = { enabled = true }
    end
    if profile.newera.enabled == nil then
        profile.newera.enabled = true
    end
    if type(profile.newera.modules) ~= "table" then
        profile.newera.modules = {}
    end
    return profile.newera
end
NE.EnsureProfile = ensureProfile

-- Convenience: the newera config sub-table (may be nil pre-login).
function NE.Config()
    return ensureProfile()
end

-- ----------------------------------------------------------------------------
-- NE.OnReady — bootstrap.lua calls this once SavedVariables are loaded
-- (after ADDON_LOADED for our addon, i.e. DragonUI.db is already an AceDB).
-- ----------------------------------------------------------------------------
function NE.OnReady()
    local cfg = ensureProfile()
    if not cfg then
        warn("DragonUI.db.profile not available at OnReady; newera settings not initialised.")
        return
    end

    -- Re-run boot for any panel that registered BEFORE OnReady (load-order
    -- safety: a panel file may have called RegisterPanel before SavedVariables
    -- were ready, so its modules.Register entry now has a real default to read).
    for _, panel in ipairs(NE.optionPanels) do
        if cfg.modules[panel.id] == nil or type(cfg.modules[panel.id]) ~= "table" then
            cfg.modules[panel.id] = { enabled = true }
        end
    end
end

-- ----------------------------------------------------------------------------
-- NE.RegisterPanel(spec)
--   spec = { id, title, desc, frame, openFn, closeFn, defaultPoint, order }
--
-- The one helper every panel module calls. Wires the panel into:
--   (1) profile.newera.modules[id] = { enabled = true }   (default)
--   (2) NE.modules.Register  (our boot dispatcher, from Core agent)
--   (3) NE.dragon.ModuleRegistry:Register  (DragonUI's module list)
--   (4) NE.dragon.MoversSystem:RegisterMover  (drag-to-move the frame)
--   (5) NE.qa.modules  (the /dnetest harness)
--   (6) NE.optionPanels  (the "New Era" options tab)
-- Every step is independently guarded.
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- NE.RegisterHUDFrame(spec)
--   spec = { name, frame, section, key, editorVisible, showTest, hideTest, onHide }
--
-- The HUD-frame counterpart to RegisterPanel. RegisterPanel is for toggled WINDOWS: it wires a
-- MoversSystem mover, which is fine for a window you drag by its title bar.
--
-- It is the WRONG seam for an always-on HUD element, because DragonUI has TWO independent
-- positioning systems and `/dui edit` only drives one of them:
--
--   addon.MoversSystem   (core/movers.lua)  -- what RegisterPanel uses. Its ToggleConfigMode is
--                                              reachable only from a dead `elseif` branch in
--                                              core/commands.lua:31 (addon.EditorMode always
--                                              exists, so the first branch always wins).
--   addon.EditableFrames (core/api.lua:551) -- what /dui edit actually shows, via
--                                              EditorMode:Show -> addon:ShowAllEditableFrames.
--
-- So a HUD frame must register as an EditableFrame or it is simply invisible to edit mode.
--
-- Position round-trip: DragonUI's editor saves via addon.SaveUIFramePosition, which writes
-- `anchor` / `posX` / `posY` into profile[section][key]. Note that its own
-- addon.ApplyUIFramePosition reads DIFFERENT field names (`x`/`y`, gated on an `override` flag
-- nothing sets), so it will not restore what Save wrote — we therefore restore ourselves, reading
-- the fields Save actually writes. This mirrors what MoversSystem:LoadPosition does for the same
-- legacy configPath shape (core/movers.lua:358-366).
-- ----------------------------------------------------------------------------

function NE.ApplySavedFramePosition(frame, section, key)
    local dragon = NE.dragon
    local profile = dragon and dragon.db and dragon.db.profile
    local cfg = profile and profile[section] and profile[section][key]
    if not (frame and cfg and cfg.anchor and cfg.posX and cfg.posY) then return false end
    frame:ClearAllPoints()
    frame:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY)
    return true
end

-- RegisterEditableFrame on its own is ONLY metadata. The editor's drag affordances —
-- RegisterForDrag, OnDragStart/OnDragStop (which auto-saves to configPath), the green nineslice
-- overlay, the text label — are attached by DragonUI's frame FACTORY, addon.CreateUIFrame
-- (core/api.lua:255). addon.HideUIFrame, which the editor calls on each registered frame, only does
-- SetMovable(true)/EnableMouse(true) and shows an overlay that a plain CreateFrame doesn't have.
--
-- So the DragonUI pattern is: build a CreateUIFrame **anchor**, register the ANCHOR as the editable
-- frame, and hang the real HUD content off it. modules/castbar.lua does exactly this with
-- CastbarModule.anchor. We follow it.
function NE.RegisterHUDFrame(spec)
    if type(spec) ~= "table" or not (spec.name and spec.frame) then
        warn("RegisterHUDFrame needs a name and frame; ignored.")
        return
    end
    local dragon = NE.dragon
    if not (dragon and type(dragon.RegisterEditableFrame) == "function"
            and type(dragon.CreateUIFrame) == "function") then
        warn("DragonUI editor API absent; '" .. tostring(spec.name) .. "' won't be movable.")
        return
    end

    local section = spec.section or "widgets"
    local key     = spec.key or spec.name
    local content = spec.frame

    -- The draggable handle. Sized to the content's current footprint; kept in sync below.
    local w = math.max(content:GetWidth() or 0, 32)
    local h = math.max(content:GetHeight() or 0, 32)
    local okAnchor, anchor = pcall(dragon.CreateUIFrame, w, h, spec.name)
    if not okAnchor or not anchor then
        warn("CreateUIFrame failed for '" .. tostring(spec.name) .. "': " .. tostring(anchor))
        return
    end

    -- Position the ANCHOR (saved position wins over the module's default), then pin content to it.
    if not NE.ApplySavedFramePosition(anchor, section, key) then
        local d = spec.defaultPoint
        anchor:ClearAllPoints()
        if d then
            anchor:SetPoint(d.point or "CENTER", UIParent, d.relativePoint or d.point or "CENTER",
                            d.x or 0, d.y or 0)
        else
            anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end

    content:ClearAllPoints()
    content:SetPoint("CENTER", anchor, "CENTER", 0, 0)

    -- Keep the grab target matching what's actually on screen as icons come and go.
    content:SetScript("OnSizeChanged", function(f)
        local cw, ch = f:GetWidth(), f:GetHeight()
        if cw and ch and cw > 0 and ch > 0 then anchor:SetSize(cw, ch) end
    end)

    local ok, err = pcall(dragon.RegisterEditableFrame, dragon, {
        name       = spec.name,
        frame      = anchor,
        configPath = { section, key },
        -- Always offer it in edit mode. A HUD frame that is empty right now still needs to be
        -- positionable — that is what showTest is for.
        editorVisible = spec.editorVisible or function() return true end,
        showTest   = spec.showTest,
        hideTest   = spec.hideTest,
        onHide     = function()
            if spec.hideTest then spec.hideTest() end
            if spec.onHide then spec.onHide() end
        end,
    })
    if not ok then
        warn("RegisterEditableFrame failed for '" .. tostring(spec.name) .. "': " .. tostring(err))
        return
    end

    spec.frame.editorAnchor = anchor
    return anchor
end

function NE.RegisterPanel(spec)
    if type(spec) ~= "table" or not spec.id then
        warn("RegisterPanel called without a spec.id; ignored.")
        return
    end

    local id    = spec.id
    local title = spec.title or id
    local desc  = spec.desc or ""

    -- (1) DB default. Guarded: profile may not exist yet pre-login; the default
    -- is re-asserted in OnReady for panels that registered early.
    local cfg = ensureProfile()
    if cfg then
        if type(cfg.modules[id]) ~= "table" then
            cfg.modules[id] = { enabled = true }
        elseif cfg.modules[id].enabled == nil then
            cfg.modules[id].enabled = true
        end
    end

    -- enabled() reads the live DB value, defaulting to true when DB is absent.
    local function isEnabled()
        local c = ensureProfile()
        if c and type(c.modules[id]) == "table" and c.modules[id].enabled ~= nil then
            return c.modules[id].enabled and true or false
        end
        return true
    end

    -- (2) Boot dispatcher (Core agent's Core/Modules.lua). No-op gracefully if
    -- NE.modules is nil so load order can't crash.
    if NE.modules and type(NE.modules.Register) == "function" then
        local ok, err = pcall(function()
            NE.modules.Register{
                name    = id,
                default = true,
                onBoot  = function()
                    -- Only open/show when the panel is enabled in config.
                    if isEnabled() and spec.openFn then
                        spec.openFn()
                    end
                end,
            }
        end)
        if not ok then
            warn("NE.modules.Register failed for '" .. id .. "': " .. tostring(err))
        end
    end

    -- (3) DragonUI ModuleRegistry. Real base API is either
    -- NE.dragon.ModuleRegistry:Register(name, moduleTable, displayName, desc, order)
    -- or the convenience wrapper NE.dragon:RegisterModule(...). Prefer whichever
    -- the base actually exposes. We pass a lightweight module table carrying an
    -- Enable refresh hook so DragonUI's enable/disable plumbing can drive us.
    local moduleTable = {
        ne_id = id,
        Enable = function()
            if spec.openFn then spec.openFn() end
        end,
        Disable = function()
            if spec.closeFn then spec.closeFn() end
        end,
        Refresh = function()
            if isEnabled() then
                if spec.openFn then spec.openFn() end
            else
                if spec.closeFn then spec.closeFn() end
            end
        end,
    }
    local dragon = NE.dragon
    if dragon then
        local registered = false
        local mr = dragon.ModuleRegistry
        if mr and type(mr.Register) == "function" then
            local ok, err = pcall(mr.Register, mr, "ne_" .. id, moduleTable, title, desc, spec.order)
            if ok then
                registered = true
            else
                warn("ModuleRegistry:Register failed for '" .. id .. "': " .. tostring(err))
            end
        end
        if not registered and type(dragon.RegisterModule) == "function" then
            local ok, err = pcall(dragon.RegisterModule, dragon, "ne_" .. id, moduleTable, title, desc, spec.order)
            if not ok then
                warn("RegisterModule failed for '" .. id .. "': " .. tostring(err))
            end
        elseif not registered and not mr then
            warn("DragonUI exposes neither ModuleRegistry nor RegisterModule; '" .. id .. "' not in module list.")
        end
    end

    -- (4) Mover. Guard if MoversSystem or the frame is absent.
    if dragon and dragon.MoversSystem and type(dragon.MoversSystem.RegisterMover) == "function" then
        if spec.frame then
            local ok, err = pcall(function()
                dragon.MoversSystem:RegisterMover{
                    name         = "ne_" .. id,
                    parent       = spec.frame,
                    text         = title,
                    configPath   = { "widgets", "ne_" .. id },
                    defaultPoint = spec.defaultPoint,
                }
            end)
            if not ok then
                warn("RegisterMover failed for '" .. id .. "': " .. tostring(err))
            end
        end
        -- No frame yet (lazily-created panel): the panel re-calls RegisterPanel
        -- or registers its mover itself once the frame exists. Silent by design.
    elseif dragon and not dragon.MoversSystem then
        warn("DragonUI.MoversSystem absent; '" .. id .. "' not movable.")
    end

    -- (5) QA harness list.
    if NE.qa then
        NE.qa.modules = NE.qa.modules or {}
        table.insert(NE.qa.modules, {
            name  = title,
            frame = spec.frame,
            open  = spec.openFn,
            close = spec.closeFn,
        })
    end

    -- (6) Options tab list (rendered by Options.lua). Store a refresh fn so the
    -- toggle callback can re-run this panel's enable without knowing internals.
    table.insert(NE.optionPanels, {
        id      = id,
        title   = title,
        desc    = desc,
        order   = spec.order or 999,
        refresh = moduleTable.Refresh,
    })

    return moduleTable
end
