-- Resolver behind the NE.L seam (see bootstrap.lua). Modules should read NE.L and never call this
-- directly: NE.L falls back to the English key when AceLocale is absent, whereas this returns nil.
--
-- AceLocale-3.0 is not vendored here; it comes from DragonUI, which the TOC hard-depends on. The
-- optional-lookup flags on both calls keep a missing library from erroring at load.

DragonUI_NewEra = DragonUI_NewEra or {}
local NE = DragonUI_NewEra

function NE:GetLocale()
    local Ace = LibStub and LibStub("AceLocale-3.0", true)
    return Ace and Ace:GetLocale("DragonUI_NewEra", true)
end
