-- Drive the NE.L localization seam against a stubbed client.
--
-- The seam is deliberately lazy: bootstrap.lua runs before LibStub, compat/Locale.lua and the
-- Locales/ files, so NE.L cannot bind to a locale table at definition time and resolves on first
-- READ instead. That ordering is exactly the thing a syntax check cannot verify and a live client
-- would only reveal as silently-English strings, so it is asserted here.
--
--   luajit qa/offline/test_locale.lua
--   NE_LOCALE=frFR luajit qa/offline/test_locale.lua
--
-- Override the addon root with NE_ADDON_ROOT (trailing slash); DragonUI's libs are found relative
-- to it, since AceLocale-3.0 is not vendored in this addon.

local ADDON = os.getenv("NE_ADDON_ROOT") or "./"
local LIBS  = os.getenv("NE_DRAGONUI_ROOT") or (ADDON .. "../DragonUI/")
local LOCALE = os.getenv("NE_LOCALE") or "deDE"

local failures = 0
local function check(label, ok, detail)
  if ok then
    print("  ok   " .. label)
  else
    failures = failures + 1
    print("  FAIL " .. label .. (detail and ("  -- " .. tostring(detail)) or ""))
  end
end

-- ── client stubs ────────────────────────────────────────────────────────────
-- Only what the files under test touch on the way to defining the seam.
function GetLocale() return LOCALE end
function UnitName() return "Tester" end
function GetRealmName() return "Offline" end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
geterrorhandler = function() return function(msg) error(msg, 0) end end

-- WoW exposes the string library's functions as bare globals, and LibStub/AceLocale use them.
strmatch, strfind, strsub, strlower, strupper, format = string.match, string.find, string.sub,
                                                        string.lower, string.upper, string.format
tinsert, tremove, wipe = table.insert, table.remove, function(t)
  for k in pairs(t) do t[k] = nil end
  return t
end

local function newFrame()
  local f = {}
  function f:RegisterEvent() end
  function f:UnregisterEvent() end
  function f:UnregisterAllEvents() end
  function f:SetScript() end
  return f
end
function CreateFrame() return newFrame() end

-- DragonUI is a hard dependency of bootstrap.lua; a bare table is enough to get past the check.
DragonUI = { L = {} }

local function run(path)
  local chunk, err = loadfile(path)
  if not chunk then error("load " .. path .. ": " .. tostring(err), 0) end
  return chunk("DragonUI_NewEra")
end

-- ── load order, exactly as the .toc declares it ─────────────────────────────
run(ADDON .. "bootstrap.lua")

local NE = DragonUI_NewEra
check("bootstrap defined NE.L", type(NE.L) == "table")

-- Read BEFORE AceLocale exists. This is the case the lazy resolver has to survive: it must fall
-- back to the English key AND must not cache that failure, or every later read stays English.
check("falls back to the key with no locale library",
      NE.L["Sort Bags"] == "Sort Bags", NE.L["Sort Bags"])

run(LIBS .. "libs/LibStub/LibStub.lua")
run(LIBS .. "libs/AceLocale-3.0/AceLocale-3.0.lua")
run(ADDON .. "compat/Locale.lua")
run(ADDON .. "Locales/enUS.lua")
run(ADDON .. "Locales/" .. LOCALE .. ".lua")

-- ── the seam resolves ───────────────────────────────────────────────────────
check("GetLocale() reaches the registered application", NE:GetLocale() ~= nil)

local translated = NE.L["Sort Bags"]
check("a key now returns its " .. LOCALE .. " translation",
      type(translated) == "string" and translated ~= "Sort Bags", translated)

-- The whole point of Phase 1: strings that route through NE.L (bags, level-up, the settings cog)
-- were previously unreachable by any locale file.
check("an NE.L-only key is translated too",
      NE.L["You have reached"] ~= "You have reached", NE.L["You have reached"])

-- And the AceLocale-side keys still work, since both now read the same table.
check("an AceLocale-side key is translated too",
      NE.L["Alchemy"] ~= "Alchemy", NE.L["Alchemy"])

-- Unknown keys must come back as themselves, silently. enUS registers with silent=true precisely
-- so a missing entry degrades to English instead of firing AceLocale's non-breaking error.
local unknown = "a key no locale will ever define " .. tostring(os.time())
check("an unknown key returns itself", NE.L[unknown] == unknown, NE.L[unknown])

-- Format strings must survive with their placeholders intact, since callers string.format them.
local ok, formatted = pcall(string.format, NE.L["Sold %d junk item(s)."], 3)
check("a format-string key still formats", ok and formatted:find("3", 1, true) ~= nil, formatted)

-- ── result ──────────────────────────────────────────────────────────────────
print("")
if failures > 0 then
  print(failures .. " failure(s)")
  os.exit(1)
end
print("locale seam ok (" .. LOCALE .. ")")
