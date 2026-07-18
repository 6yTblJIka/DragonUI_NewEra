-- DragonUI_NewEra/core/Scale.lua — per-window scaling for the standalone panels.
--
-- Three modes per window:
--   "ui"     follow the game's UI Scale slider (the frame inherits UIParent → SetScale(1)).
--   "none"   no scaling: pixel-perfect, independent of the UI Scale slider (PinPixelPerfect).
--   "custom" a fixed multiplier in [MIN, MAX].
-- Settings persist account-wide in NE.db.scale[window] = { mode, custom }. The DragonUI options
-- "New Era" tab exposes a dropdown (mode) + slider (custom) per window (see integration/Options.lua),
-- and changes apply IMMEDIATELY to the live frame via S.Apply.

local NE = DragonUI_NewEra
NE.scale = NE.scale or {}
local S = NE.scale

S.MIN, S.MAX = 0.5, 1.5

-- Per-window defaults preserve each window's prior look: spellbook/talents were a fixed 0.8; the
-- character panel had no custom scale (= followed the UI scale).
local DEFAULTS = {
  character = { mode = "ui",     custom = 1.0 },
  spellbook = { mode = "custom", custom = 0.8 },
  talents   = { mode = "custom", custom = 0.8 },
}

S._frames = S._frames or {}   -- window -> live Frame

local function store()
  local db = NE.db
  if not db then return nil end
  db.scale = db.scale or {}
  return db.scale
end

-- mode, custom for a window (falls back to defaults; never nil).
function S.Get(window)
  local d = DEFAULTS[window] or { mode = "ui", custom = 1.0 }
  local st = store()
  local s = st and st[window]
  if not s then return d.mode, d.custom end
  return s.mode or d.mode, s.custom or d.custom
end

-- Register a window's live frame so Apply/Set can rescale it on demand.
function S.SetFrame(window, frame)
  if window and frame then S._frames[window] = frame end
end

-- Apply the current setting to the window's registered frame (no-op if not registered yet).
function S.Apply(window)
  local f = S._frames[window]
  if not f or not f.SetScale then return end
  local mode, custom = S.Get(window)
  if mode == "none" then
    if NE.FrameUtil and NE.FrameUtil.PinPixelPerfect then
      NE.FrameUtil.PinPixelPerfect(f)         -- 1 logical px = 1 physical; ignores the UI scale slider
    else
      f:SetScale(1.0)
    end
  elseif mode == "custom" then
    local c = tonumber(custom) or 0.8
    if c < S.MIN then c = S.MIN elseif c > S.MAX then c = S.MAX end
    f:SetScale(c)
  else  -- "ui": inherit UIParent so the window tracks the game UI Scale slider
    f:SetScale(1.0)
  end
end

-- Persist a new mode + apply live.
function S.SetMode(window, mode)
  if mode ~= "ui" and mode ~= "none" and mode ~= "custom" then return end
  local st = store()
  if st then st[window] = st[window] or {}; st[window].mode = mode end
  S.Apply(window)
end

-- Persist a new custom value (clamped) + apply live.
function S.SetCustom(window, value)
  local v = tonumber(value)
  if not v then return end
  if v < S.MIN then v = S.MIN elseif v > S.MAX then v = S.MAX end
  local st = store()
  if st then st[window] = st[window] or {}; st[window].custom = v end
  S.Apply(window)
end
