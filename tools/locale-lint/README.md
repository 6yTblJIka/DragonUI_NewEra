# locale-lint

Keeps `Locales/` honest against the strings the addon actually asks for.

Every user-facing string routes through the `NE.L` seam (see `bootstrap.lua`), and the keys ARE the
English text. That makes drift invisible at runtime: AceLocale's silent default returns the key, so
a string that never reached `enUS.lua` looks perfectly fine in English and is simply untranslatable
in every other locale. These checks are what drift can't hide from.

## Checks

```bash
python tools/locale-lint/check_keys.py --raw      # literals reaching the UI without going through L
python tools/locale-lint/check_keys.py            # keys the source uses vs. what enUS declares
python tools/locale-lint/check_keys.py --verify   # every translation reproduces enUS's placeholders
```

All three exit non-zero on failure, so they can gate CI. `--verify` is the one that matters most:
callers `string.format` these strings, so a translation that drops a `%d` throws at the moment the
tooltip or popup is built, not at load. It also checks `|n` line breaks and `|cRRGGBBAA` colour tags.

`--raw` honours an allowlist inside `check_keys.py` for the handful of literals that stay English on
purpose (the pre-locale bootstrap failure message, a third-party addon's name, a client error
passthrough, and the Sprint-0 demo panel). Add to it with a reason rather than letting the check sit
permanently red.

Bulk game data — encounter/boss names, boss ability text, aura names used as API-lookup identifiers
— is skipped via `SKIP_FILES`. That content is translated by whoever sourced it, not by us.

## Adding a string

Route it through `L["..."]` in the source, then:

```bash
python tools/locale-lint/gen_enus.py              # appends new keys to enUS.lua, grouped by module
```

`gen_enus.py` is additive on purpose. `enUS.lua`'s first two sections carry keys reachable only
through dynamic subscripts (`L[engKey]` for a profession, `L[stat.tooltip]` for a paper-doll line);
a regenerate-from-scratch would drop exactly those, because no scanner can see them. `check_keys.py`
reports how many dynamic subscripts exist and where, so the count can be sanity-checked by hand.

## Translations

`Locales/<locale>.lua` is generated, not hand-edited:

```bash
python tools/locale-lint/gen_locale.py deDE       # one locale
python tools/locale-lint/gen_locale.py --all      # every locale with a translation map
```

Source of truth is `translations/<locale>.py`, a `T = {raw_key: translated}` map where `raw_key` is
the key exactly as it appears between the quotes in `enUS.lua`. Driving the file layout from
`enUS.lua` means a translation file can never drift out of order or silently lose a key — regenerate
and the diff is only the strings that changed. A locale may set `EXTENDS = "<other>"` to inherit and
override (esMX does this over esES).

Correcting a string in `Locales/*.lua` directly is fine, but port the fix back into the map or the
next regenerate will overwrite it.

**The shipped non-English translations are machine-drafted and have not been reviewed by native
speakers.** Placeholder parity is enforced; wording is not. Corrections are welcome and cheap — edit
the map, regenerate, run `--verify`.

## Runtime

`qa/offline/test_locale.lua` drives the seam against a stubbed client: it asserts the lazy resolver
falls back to English before AceLocale exists, resolves afterwards, translates both `NE.L`-only and
AceLocale-side keys, returns unknown keys unchanged, and keeps format strings formattable.

```bash
luajit qa/offline/test_locale.lua
NE_LOCALE=frFR luajit qa/offline/test_locale.lua
```
