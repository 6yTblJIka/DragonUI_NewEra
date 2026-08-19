# -*- coding: utf-8 -*-
"""German translations. Keys are the enUS.lua source text verbatim (Lua escapes intact).

Machine-drafted. Placeholder parity is enforced by check_keys.py --verify; wording is not reviewed.
"""

T = {
    # ── Professions ─────────────────────────────────────────────────────────────────────────────
    #
    # These sixteen are NOT display labels. modules/professions/Crafting.lua matches the live
    # client's GetTradeSkillLine() against L[engKey] to pick the window's icon and skill-bar theme,
    # so a value that isn't byte-identical to the German client's own name silently falls through
    # to the question-mark icon -- the symptom reported in issue #66.
    #
    # Verified against a real deDE 3.3.5a client by the reporter in that issue; do not "improve"
    # the wording here without checking it against the client first.
    "Alchemy": "Alchemie",
    "Blacksmithing": "Schmiedekunst",
    "Enchanting": "Verzauberkunst",
    "Engineering": "Ingenieurskunst",
    "Herbalism": "Kräuterkunde",
    "Leatherworking": "Lederverarbeitung",
    "Mining": "Bergbau",
    "Smelting": "Schmelzen",
    "Skinning": "Kürschnerei",
    "Tailoring": "Schneiderei",
    "Inscription": "Inschriftenkunde",
    "Jewelcrafting": "Juwelenschleifen",
    "Prospecting": "Sondieren",
    "Cooking": "Kochkunst",
    "First Aid": "Erste Hilfe",
    "Fishing": "Angeln",
    "Select a recipe to craft": "Wählt ein Rezept zum Herstellen",
    "Hide item tooltips in list": "Gegenstandstooltips in der Liste ausblenden",
    "Colour names by skill difficulty": "Namen nach Schwierigkeitsgrad einfärben",
    "Plain skill bar (no animation)": "Einfache Fertigkeitsleiste (ohne Animation)",
    "Create": "Herstellen",
    "Create All": "Alle herstellen",
    "Show Learned": "Erlernte anzeigen",
    "Has Skill Up": "Erhöht Fertigkeit",
    "Have Materials": "Materialien vorhanden",

    # ── Character, titles, equipment manager ────────────────────────────────────────────────────
    "None": "Keine",

    # ── Auction house ───────────────────────────────────────────────────────────────────────────
    " -- partial scan": " -- Teilsuche",
    "Auction query is throttled. Try again in a moment.":
        "Die Auktionsabfrage ist gedrosselt. Versucht es gleich noch einmal.",
    "Buy out this auction for %s?": "Diese Auktion für %s sofortkaufen?",
    r"Choose search criteria and press \"Search\"": "Wählt Suchkriterien und drückt \"Suchen\"",
    "Loading results...": "Ergebnisse werden geladen...",
    "Lvl": "Stufe",
    "Modern visual shell for Buy/Sell/Auctions with optional Auctionator tab embedding.":
        "Moderne Oberfläche für Kaufen/Verkaufen/Auktionen mit optionalem Auctionator-Tab.",
    "No listings.": "Keine Angebote.",
    "No results. Adjust filters and search again.":
        "Keine Ergebnisse. Passt die Filter an und sucht erneut.",
    "Page %d of %d  (items %d-%d of %d, from %d auction)%s":
        "Seite %d von %d  (Gegenstände %d-%d von %d, aus %d Auktion)%s",
    "Page %d of %d  (items %d-%d of %d, from %d auctions)%s":
        "Seite %d von %d  (Gegenstände %d-%d von %d, aus %d Auktionen)%s",
    "Page 1 of 1": "Seite 1 von 1",
    "Per Item": "Pro Gegenstand",
    "Place a bid of %s?": "Gebot über %s abgeben?",
    "Scanning page %d of %d...": "Seite %d von %d wird durchsucht...",
    "Searching...": "Suche läuft...",
    "Sort Per Item": "Nach Stückpreis sortieren",
    "You have no auctions.": "Ihr habt keine Auktionen.",

    # ── Bags ────────────────────────────────────────────────────────────────────────────────────
    "All Bags": "Alle Taschen",
    "Auto-empty old bag when swapping": "Alte Tasche beim Tauschen automatisch leeren",
    "Auto-sell junk at merchants": "Schrott bei Händlern automatisch verkaufen",
    "Bag Options": "Taschenoptionen",
    "Category (smart)": "Kategorie (intelligent)",
    "Combined bag (all-in-one)": "Kombinierte Tasche (alles in einem)",
    "Item Level": "Gegenstandsstufe",
    "Keys": "Schlüssel",
    "Merchant": "Händler",
    "Name": "Name",
    "Not enough free space to swap that bag.":
        "Nicht genügend freier Platz, um diese Tasche zu tauschen.",
    "One movable window showing every bag slot in a Dragonflight-style grid. Takes over bag opening "
    "and replaces the per-window 'Retail bags' restyle. Reload (/reload) to apply.":
        "Ein bewegliches Fenster mit allen Taschenplätzen in einem Dragonflight-Raster. Übernimmt das "
        "Öffnen der Taschen und ersetzt die Einzelfenster-Umgestaltung 'Retail-Taschen'. /reload zum Anwenden.",
    "Quality": "Qualität",
    "Red-tint unusable items": "Unbenutzbare Gegenstände rot einfärben",
    "Restyle the bag windows with the Dragonflight metal frame, portrait, and item quality borders. "
    "Disable to keep the stock Blizzard bags. Reload (/reload) to apply.":
        "Gestaltet die Taschenfenster mit Dragonflight-Metallrahmen, Porträt und Qualitätsrändern neu. "
        "Deaktivieren, um die Standardtaschen von Blizzard zu behalten. /reload zum Anwenden.",
    "Retail bags": "Retail-Taschen",
    "Reverse sort order": "Sortierreihenfolge umkehren",
    "Search": "Suchen",
    "Separate specialty bags": "Spezialtaschen getrennt anzeigen",
    "Shift-right-click to stop watching": "Umschalt+Rechtsklick, um die Beobachtung zu beenden",
    "Show item level on items": "Gegenstandsstufe auf Gegenständen anzeigen",
    "Show keyring row": "Schlüsselbundreihe anzeigen",
    "Sold %d junk item(s).": "%d Schrottgegenstand/-gegenstände verkauft.",
    "Sort Bags": "Taschen sortieren",
    "Sort by": "Sortieren nach",
    "Sorting…": "Sortiere…",
    "Swapping bag…": "Tausche Tasche…",
    "The same setting as Enable Item Level in DragonUI's options (Enhancements > Item Level). "
    "Covers the character panel and every other frame too.":
        "Dieselbe Einstellung wie 'Gegenstandsstufe aktivieren' in den DragonUI-Optionen "
        "(Erweiterungen > Gegenstandsstufe). Gilt auch für das Charakterfenster und alle anderen Fenster.",
    "Turn on Item Level in DragonUI's options (Enhancements > Item Level) first.":
        "Aktiviert zuerst 'Gegenstandsstufe' in den DragonUI-Optionen (Erweiterungen > Gegenstandsstufe).",

    # ── Cooldown manager ────────────────────────────────────────────────────────────────────────
    "(empty)": "(leer)",
    "(your spec)": "(Eure Spezialisierung)",
    "A ready sound plays when a COOLDOWN finishes.|nThis spell has none, so it can never play."
    "|nClearing it also clears the badge.":
        "Ein Bereitschaftston erklingt, wenn eine ABKLINGZEIT endet.|nDieser Zauber hat keine, der Ton "
        "kann also nie erklingen.|nZurücksetzen entfernt auch das Abzeichen.",
    "A spell can be on cooldown and buffing you at the same time. The glow says which icons are "
    "buffed; the timer says how long.":
        "Ein Zauber kann gleichzeitig auf Abklingzeit sein und Euch stärken. Das Leuchten zeigt, welche "
        "Symbole gestärkt sind; der Zeitanzeiger, wie lange.",
    "Active": "Aktiv",
    "Alert": "Hinweis",
    "Always": "Immer",
    "Auto-track buffs under %ds": "Stärkungszauber unter %ds automatisch verfolgen",
    "Available": "Verfügbar",
    "Bar Content": "Balkeninhalt",
    "Bar Width": "Balkenbreite",
    "Both of these are immediate and cannot be undone from here — Revert only covers layout changes.":
        "Beides wirkt sofort und lässt sich von hier aus nicht rückgängig machen — 'Zurücksetzen' "
        "betrifft nur Layoutänderungen.",
    "Buff Bars": "Stärkungszauberbalken",
    "Buff Icons": "Stärkungszaubersymbole",
    "Buff tracking": "Stärkungszauber verfolgen",
    "Buffed spells": "Gestärkte Zauber",
    "Buffs you have not seen before are recorded and listed under Not Displayed on the Tracked Buffs "
    "tab, where you can assign the ones you want. Nothing appears on screen until you do.":
        "Bisher unbekannte Stärkungszauber werden aufgezeichnet und unter 'Nicht angezeigt' im Reiter "
        "'Verfolgte Stärkungszauber' aufgeführt, wo Ihr die gewünschten zuweisen könnt. Vorher erscheint nichts.",
    "Button Glow": "Schaltflächenleuchten",
    "Clear All Alerts": "Alle Hinweise löschen",
    "Clear Ready Sound": "Bereitschaftston löschen",
    "Clear all alerts and sounds": "Alle Hinweise und Töne löschen",
    "Clear every configured alert and ready sound?\\n\\nSpell lists and frame positions are not affected.":
        "Alle eingerichteten Hinweise und Bereitschaftstöne löschen?\\n\\nZauberlisten und Fensterpositionen "
        "bleiben unberührt.",
    "Closes edit mode and opens the Cooldown Manager window, which carries the settings that are not "
    "per-viewer: alerts, ready sounds, buff tracking, icon fit and the resets.":
        "Schließt den Bearbeitungsmodus und öffnet das Abklingzeitenmanager-Fenster mit allen "
        "Einstellungen, die nicht zu einer einzelnen Anzeige gehören: Hinweise, Bereitschaftstöne, "
        "Stärkungszauberverfolgung, Symbolanpassung und die Zurücksetzungen.",
    "Cooldown Manager": "Abklingzeitenmanager",
    "Cooldown Manager Settings": "Abklingzeitenmanager-Einstellungen",
    "Cooldown Manager layout string (Ctrl+C to copy):":
        "Abklingzeitenmanager-Layoutcode (Strg+C zum Kopieren):",
    "Copy": "Kopieren",
    "Defensives, interrupts, CC and escapes.":
        "Verteidigung, Unterbrechungen, Kontrolle und Fluchtzauber.",
    "Delete": "Löschen",
    r'Delete the layout \"%s\"?': 'Das Layout \"%s\" löschen?',
    "Drag onto Essential or Utility to track it.":
        "Auf 'Wesentlich' oder 'Hilfreich' ziehen, um es zu verfolgen.",
    "Draw the countdown number on each icon.": "Die Restzeit auf jedem Symbol anzeigen.",
    "Each viewer's own settings — size, spacing, orientation, visibility, what its icons show — live "
    "on the frame, in edit mode, where you can see what you are changing. These open edit mode with "
    "that viewer selected and its settings already up. Closes this window; not available in combat.":
        "Die eigenen Einstellungen jeder Anzeige — Größe, Abstand, Ausrichtung, Sichtbarkeit, Symbolinhalt "
        "— liegen am Rahmen selbst, im Bearbeitungsmodus, wo Ihr seht, was Ihr ändert. Diese Schaltflächen "
        "öffnen den Bearbeitungsmodus mit der gewählten Anzeige und ihren Einstellungen. Schließt dieses "
        "Fenster; im Kampf nicht verfügbar.",
    "Enable Cooldown Manager": "Abklingzeitenmanager aktivieren",
    "Enabled": "Aktiviert",
    "Essential Cooldowns": "Wesentliche Abklingzeiten",
    "Everything": "Alles",
    "Everything (no spec)": "Alles (ohne Spezialisierung)",
    "Everything the Cooldown Manager can be told to do that is not about one viewer's layout. Layout "
    "and position both live on the frame itself, in edit mode (/dui edit) — click a viewer there for "
    "its own settings, or use the buttons just below to go straight to one.":
        "Alles, was der Abklingzeitenmanager tun kann, sofern es nicht das Layout einer einzelnen Anzeige "
        "betrifft. Layout und Position liegen am Rahmen selbst, im Bearbeitungsmodus (/dui edit) — klickt "
        "dort eine Anzeige für ihre eigenen Einstellungen an, oder nutzt die Schaltflächen unten.",
    "Export Layout": "Layout exportieren",
    "FX Style": "Effektstil",
    "Flashes once, the moment the cooldown finishes.|nWorks for every spell.":
        "Blitzt einmal auf, sobald die Abklingzeit endet.|nFunktioniert für jeden Zauber.",
    "Frame strength": "Rahmenstärke",
    "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is the "
    "stock look, not a bug.":
        "Abstand zwischen den Symbolen. Retail verschiebt diesen um -4, daher überlappen sie am unteren "
        "Ende leicht — das ist das Originalverhalten, kein Fehler.",
    "Glow while buffed": "Leuchten, solange gestärkt",
    "Glows during the last %d%% of this buff's|nremaining time.":
        "Leuchtet während der letzten %d%% der|nverbleibenden Dauer dieses Stärkungszaubers.",
    "Glows during the last %d%% of this spell's own|nbuff or debuff.":
        "Leuchtet während der letzten %d%% des eigenen|nStärkungs- oder Schwächungszaubers.",
    "Glows for as long as the spell is off cooldown|nand affordable.":
        "Leuchtet, solange der Zauber bereit|nund bezahlbar ist.",
    "Glows for as long as this buff is on you.|n|nThe one that works for a proc: it asks whether "
    "the|nbuff is up, not whether something is castable|nor off cooldown.":
        "Leuchtet, solange dieser Stärkungszauber auf Euch liegt.|n|nDer richtige für einen Proc: er "
        "fragt, ob der|nStärkungszauber aktiv ist, nicht ob etwas wirkbar|noder bereit ist.",
    "Glows for as long as this spell's effect is|nup on %s.":
        "Leuchtet, solange die Wirkung dieses Zaubers|nauf %s aktiv ist.",
    "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.":
        "Umgibt das Symbol golden, solange der Stärkungszauber (bei Schamanen dessen Totem) aktiv ist.",
    "Hidden": "Verborgen",
    "Hide When Inactive": "Bei Inaktivität ausblenden",
    "Horizontal": "Horizontal",
    "How many icons before the layout wraps. Vertical orientation reads this as icons per column.":
        "Wie viele Symbole, bevor das Layout umbricht. Bei vertikaler Ausrichtung gilt dies je Spalte.",
    "Icon Direction": "Symbolrichtung",
    "Icon Limit": "Symbolgrenze",
    "Icon Only": "Nur Symbol",
    "Icon Padding": "Symbolabstand",
    "Icon Size": "Symbolgröße",
    "Icon and Name": "Symbol und Name",
    "Icon fit": "Symbolanpassung",
    "Icon inset": "Symboleinzug",
    "Import": "Importieren",
    "Import Layout": "Layout importieren",
    "In Combat": "Im Kampf",
    "Lasts %s sec": "Dauert %s Sek.",
    "Layouts": "Layouts",
    "Layouts include appearance": "Layouts enthalten das Erscheinungsbild",
    "Left": "Links",
    "Load the %s starter layout?\\n\\nEssential is set to that spec's spells. Everything else for your "
    "class moves to Not Displayed — nothing is deleted, and you can drag any of it back.\\n\\nTracked "
    "auras, trinkets, alerts and frame positions are not affected.":
        "Das Startlayout %s laden?\\n\\n'Wesentlich' wird auf die Zauber dieser Spezialisierung gesetzt. "
        "Alles andere Eurer Klasse wandert zu 'Nicht angezeigt' — nichts wird gelöscht, und Ihr könnt alles "
        "zurückziehen.\\n\\nVerfolgte Auren, Schmuckstücke, Hinweise und Fensterpositionen bleiben unberührt.",
    "Marching Ants": "Laufende Ameisen",
    "Move to %s": "Verschieben nach %s",
    "Name Only": "Nur Name",
    "Name this layout:": "Diesem Layout einen Namen geben:",
    "New Layout": "Neues Layout",
    "Not displayed on any viewer": "In keiner Anzeige dargestellt",
    "Not yet learned": "Noch nicht erlernt",
    "Nothing to undo. It covers LAYOUTS, not the settings|non these tabs — a viewer's own size and "
    "position revert|nfrom its edit-mode panel instead.":
        "Nichts rückgängig zu machen. Es betrifft LAYOUTS, nicht die|nEinstellungen dieser Reiter — Größe "
        "und Position einer Anzeige|nsetzt Ihr stattdessen in deren Bearbeitungsfenster zurück.",
    "Off by default. Turn on to show the four viewers; turn off to hide them again. Takes effect "
    "immediately either way, and nothing is forgotten — this switch stores one flag and touches "
    "nothing else, so your setup comes back exactly as you left it.":
        "Standardmäßig aus. Einschalten zeigt die vier Anzeigen, ausschalten blendet sie wieder aus. Wirkt "
        "in beiden Richtungen sofort, und nichts geht verloren — dieser Schalter speichert nur ein Kennzeichen "
        "und rührt sonst nichts an, Eure Einrichtung kehrt also unverändert zurück.",
    "Off, both specs share one set of lists. Turning it on copies the layout you have now into the "
    "spec you are in.":
        "Aus teilen sich beide Spezialisierungen einen Satz Listen. Beim Einschalten wird das aktuelle "
        "Layout in die Spezialisierung kopiert, in der Ihr Euch befindet.",
    "Off, loading or importing a layout changes only what you track — lists, tracked buffs, trinkets, "
    "alerts and sounds. On, it also applies the orientation, icons per row, size, padding and opacity "
    "the layout was saved with.|n|nLayouts always SAVE appearance either way, so this only decides "
    "what happens when one is applied. Revert always puts appearance back, whatever this says.":
        "Aus ändert das Laden oder Importieren eines Layouts nur, was Ihr verfolgt — Listen, verfolgte "
        "Stärkungszauber, Schmuckstücke, Hinweise und Töne. An werden auch Ausrichtung, Symbole je Reihe, "
        "Größe, Abstand und Deckkraft des gespeicherten Layouts übernommen.|n|nLayouts SPEICHERN das "
        "Erscheinungsbild ohnehin immer, dies entscheidet also nur über das Anwenden. 'Zurücksetzen' stellt "
        "das Erscheinungsbild immer wieder her, unabhängig davon.",
    "Off, orientation, icons per row, size, padding and opacity are one setup for every character. On, "
    "each character can differ — until you change something here it still follows the shared setup, so "
    "nothing moves when you tick this, and unticking it gives the shared setup back without losing "
    "what you changed.":
        "Aus gelten Ausrichtung, Symbole je Reihe, Größe, Abstand und Deckkraft für alle Charaktere "
        "gemeinsam. An darf jeder Charakter abweichen — bis Ihr hier etwas ändert, folgt er weiter der "
        "gemeinsamen Einrichtung, beim Aktivieren bewegt sich also nichts, und beim Deaktivieren kehrt die "
        "gemeinsame Einrichtung zurück, ohne Eure Änderungen zu verlieren.",
    "Offensive burst and damage cooldowns.": "Offensive Burst- und Schadensabklingzeiten.",
    "Opacity": "Deckkraft",
    "Open Cooldown Manager": "Abklingzeitenmanager öffnen",
    "Opens a share string you can copy with Ctrl+C.|nIt covers this class's spell lists, tracked "
    "auras,|ntrinket placement, alerts and sounds.":
        "Öffnet einen Teilcode, den Ihr mit Strg+C kopieren könnt.|nEr umfasst die Zauberlisten dieser "
        "Klasse, verfolgte Auren,|nSchmuckstückplatzierung, Hinweise und Töne.",
    "Opens the Cooldown Manager window (/cdm) on its Spells tab. Needs the module on — the window "
    "configures the viewers, so it goes away with them.":
        "Öffnet das Abklingzeitenmanager-Fenster (/cdm) im Reiter 'Zauber'. Benötigt das aktivierte Modul — "
        "das Fenster richtet die Anzeigen ein und verschwindet mit ihnen.",
    "Options": "Optionen",
    "Orientation": "Ausrichtung",
    "Pandemic Border": "Pandemierand",
    "Paste a Cooldown Manager layout string:": "Fügt einen Abklingzeitenmanager-Layoutcode ein:",
    "Ready Sound": "Bereitschaftston",
    "Ready sound: %s": "Bereitschaftston: %s",
    "Refresh": "Auffrischen",
    "Refresh Window": "Auffrischfenster",
    "Remove": "Entfernen",
    "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.":
        "Entfernt alle zauberbezogenen Hinweise und Bereitschaftstöne. Zauberlisten und Positionen bleiben "
        "unberührt.",
    "Rename": "Umbenennen",
    "Requires the %s talent": "Erfordert das Talent %s",
    "Reset": "Zurücksetzen",
    "Reset %s to its default layout?\\n\\nThis viewer's position, size, orientation and visibility all "
    "go back to stock. Nothing else is affected, and it cannot be undone.":
        "%s auf das Standardlayout zurücksetzen?\\n\\nPosition, Größe, Ausrichtung und Sichtbarkeit dieser "
        "Anzeige kehren auf die Voreinstellung zurück. Sonst ändert sich nichts, und es lässt sich nicht "
        "rückgängig machen.",
    "Reset Spell Lists": "Zauberlisten zurücksetzen",
    "Reset spell and buff lists": "Zauber- und Stärkungszauberlisten zurücksetzen",
    "Reset this class's Cooldown Manager spell and buff lists to their defaults?\\n\\nOther classes, "
    "alerts, sounds and frame positions are not affected.":
        "Die Zauber- und Stärkungszauberlisten des Abklingzeitenmanagers für diese Klasse auf die "
        "Voreinstellung zurücksetzen?\\n\\nAndere Klassen, Hinweise, Töne und Fensterpositionen bleiben "
        "unberührt.",
    "Reset to the starter layout?\\n\\nThis reverts every Cooldown Manager edit — spells, tracked auras, "
    "trinket placement, alerts and sounds — to their defaults, and clears your saved-layout "
    "selection.\\n\\nFrame positions are not affected.":
        "Auf das Startlayout zurücksetzen?\\n\\nDies setzt jede Änderung am Abklingzeitenmanager — Zauber, "
        "verfolgte Auren, Schmuckstückplatzierung, Hinweise und Töne — auf die Voreinstellung zurück und "
        "löscht Eure Layoutauswahl.\\n\\nFensterpositionen bleiben unberührt.",
    "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its spell lists, "
    "aura assignments and trinket placement. Other classes, alerts, sounds and positions are not "
    "affected.":
        "Stellt die kuratierten Voreinstellungen und das Fenster zur automatischen Verfolgung für DIESE "
        "KLASSE wieder her und löscht deren Zauberlisten, Aurenzuweisungen und Schmuckstückplatzierung. "
        "Andere Klassen, Hinweise, Töne und Positionen bleiben unberührt.",
    "Retail's Cooldown Manager, driven from curated per-class cooldown lists. |cffffcc55Off by "
    "default|r — it adds four viewers to the middle of your screen, so it waits to be asked. Every "
    "setting — which spells and buffs are tracked, each viewer's layout, size and visibility, alerts "
    "and ready sounds — lives in the Cooldown Manager window itself (/cdm). Drag the viewers with "
    "DragonUI's editor mode to reposition them, and right-click one there for its own layout settings.":
        "Der Abklingzeitenmanager aus Retail, gespeist aus kuratierten Abklingzeitenlisten je Klasse. "
        "|cffffcc55Standardmäßig aus|r — er setzt vier Anzeigen in die Mitte Eures Bildschirms und wartet "
        "daher auf Eure Aufforderung. Jede Einstellung — welche Zauber und Stärkungszauber verfolgt werden, "
        "Layout, Größe und Sichtbarkeit jeder Anzeige, Hinweise und Bereitschaftstöne — liegt im "
        "Abklingzeitenmanager-Fenster selbst (/cdm). Verschiebt die Anzeigen im Bearbeitungsmodus von "
        "DragonUI und klickt dort mit rechts auf eine für deren eigene Layouteinstellungen.",
    "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the spell's "
    "cooldown and the glow alone marks it as buffed — which is clearer when the two differ, as on "
    "Prayer of Mending.":
        "Verhalten wie in Retail: solange gestärkt, zählt das Symbol den STÄRKUNGSZAUBER herunter. Aus zählt "
        "es die Abklingzeit des Zaubers herunter, und allein das Leuchten kennzeichnet ihn als gestärkt — "
        "was klarer ist, wenn beide voneinander abweichen, etwa bei 'Gebet der Besserung'.",
    "Revert": "Zurücksetzen",
    "Right": "Rechts",
    "Save, load, import and export the whole|nCooldown Manager setup for this class.":
        "Die gesamte Abklingzeitenmanager-Einrichtung|ndieser Klasse speichern, laden, importieren und exportieren.",
    "Separate appearance per character": "Eigenes Erscheinungsbild je Charakter",
    "Separate layout per spec": "Eigenes Layout je Spezialisierung",
    "Short-duration buffs and procs, as depleting bars.":
        "Kurze Stärkungszauber und Procs als ablaufende Balken.",
    "Short-duration buffs and procs, as icons.": "Kurze Stärkungszauber und Procs als Symbole.",
    "Show Timer": "Zeitanzeige einblenden",
    "Show Tooltips": "Tooltips anzeigen",
    "Show Unlearned": "Nicht erlernte anzeigen",
    "Show a slot only while its aura is active.":
        "Einen Platz nur anzeigen, solange dessen Aura aktiv ist.",
    "Show a tooltip when hovering an icon.":
        "Einen Tooltip anzeigen, wenn Ihr über ein Symbol fahrt.",
    "Show every short buff the moment it lands, without assigning it first. Convenient on a character "
    "you are still setting up; in a raid it fills the viewers with other people's cooldowns, food and "
    "flasks.":
        "Zeigt jeden kurzen Stärkungszauber, sobald er wirkt, ohne ihn vorher zuzuweisen. Praktisch bei "
        "einem Charakter, den Ihr noch einrichtet; im Schlachtzug füllt es die Anzeigen mit fremden "
        "Abklingzeiten, Speisen und Fläschchen.",
    "Show the buff's time, not the cooldown": "Dauer des Stärkungszaubers statt der Abklingzeit anzeigen",
    "Show them as": "Anzeigen als",
    "Show this viewer at all. The editor handle stays either way, so this is reversible from right here.":
        "Diese Anzeige überhaupt einblenden. Der Bearbeitungsgriff bleibt so oder so erhalten, es lässt sich "
        "also direkt hier rückgängig machen.",
    "Sparkles": "Funkeln",
    "Talent specs": "Talentspezialisierungen",
    "The frame is a soft shadow that falls on the icon's outer edge, so it only shows where there is "
    "icon underneath it. Strength draws it more than once to deepen it — that is also what makes its "
    "rounded corners read, since the icons themselves cannot be rounded here. Inset shrinks the icon, "
    "which slides the shadow off it, so raise that one sparingly.":
        "Der Rahmen ist ein weicher Schatten auf der Außenkante des Symbols und erscheint daher nur dort, wo "
        "ein Symbol darunterliegt. 'Stärke' zeichnet ihn mehrfach, um ihn zu vertiefen — das lässt auch seine "
        "runden Ecken erkennen, da die Symbole selbst hier nicht abgerundet werden können. 'Einzug' "
        "verkleinert das Symbol und schiebt den Schatten davon herunter, erhöht diesen Wert also sparsam.",
    "The full curated list for your class, both specs' spells|nincluded. This is what the Cooldown "
    "Manager shipped with|nbefore per-spec starters.":
        "Die vollständige kuratierte Liste Eurer Klasse, mit den Zaubern|nbeider Spezialisierungen. Damit "
        "wurde der Abklingzeitenmanager|nvor den Startlayouts je Spezialisierung ausgeliefert.",
    "Tracked automatically. Drag it into a section to pin it there.":
        "Wird automatisch verfolgt. Zieht es in einen Abschnitt, um es dort festzuhalten.",
    "Undoes the last layout change — applying a layout,|nimporting one, or the starter reset.|n|nOne "
    "step, and only for this session.":
        "Macht die letzte Layoutänderung rückgängig — ein Layout anwenden,|neines importieren oder das "
        "Startlayout zurücksetzen.|n|nEin Schritt, und nur für diese Sitzung.",
    "Usable": "Einsetzbar",
    "Use Starter Layout": "Startlayout verwenden",
    "Utility Cooldowns": "Hilfreiche Abklingzeiten",
    "Vertical": "Vertikal",
    "Viewer layout": "Anzeigenlayout",
    "Visibility": "Sichtbarkeit",
    "When this viewer is on screen at all. Hidden still leaves the editor handle here.":
        "Wann diese Anzeige überhaupt auf dem Bildschirm ist. 'Verborgen' belässt den Bearbeitungsgriff hier.",
    "Which of the two buff viewers auto-tracked buffs land in.":
        "In welcher der beiden Stärkungszauberanzeigen automatisch verfolgte Stärkungszauber landen.",
    "Which spells and buffs you track is remembered separately for each talent spec, so a Discipline "
    "layout and a Holy one do not overwrite each other. Where each viewer sits is always remembered "
    "per character; the appearance settings are shared unless you say otherwise below.":
        "Welche Zauber und Stärkungszauber Ihr verfolgt, wird je Talentspezialisierung getrennt gespeichert, "
        "sodass sich ein Disziplin- und ein Heilig-Layout nicht überschreiben. Wo jede Anzeige sitzt, wird "
        "immer je Charakter gespeichert; die Einstellungen zum Erscheinungsbild sind gemeinsam, sofern Ihr "
        "unten nichts anderes festlegt.",
    "is turned off. Enable it in DragonUI's options, under New Era > Cooldown Manager.":
        "ist ausgeschaltet. Aktiviert ihn in den DragonUI-Optionen unter New Era > Abklingzeitenmanager.",
    "you": "Euch",
    "|n|nOn a buff row this is about RE-CASTING it,|nnot about the buff being up — that is Active.":
        "|n|nIn einer Stärkungszauberzeile geht es ums ERNEUTE Wirken,|nnicht darum, ob er aktiv ist — das "
        "ist 'Aktiv'.",
    "|n|nThe one for a DoT or a shield: it asks whether|nthe aura is up, not whether the cooldown is "
    "ready.":
        "|n|nDer richtige für einen DoT oder Schild: er fragt, ob|ndie Aura aktiv ist, nicht ob die "
        "Abklingzeit bereit ist.",
    "|n|nThis one also waits for a target below %d%% health.":
        "|n|nDieser wartet zudem auf ein Ziel unter %d%% Gesundheit.",
    "|n|n|cff40ff40Applies %s to %s, so this will work.|r":
        "|n|n|cff40ff40Wirkt %s auf %s, dies funktioniert also.|r",
    "|n|n|cff40ff40Its aura is active now, so this will work.|r":
        "|n|n|cff40ff40Die Aura ist gerade aktiv, dies funktioniert also.|r",
    "|n|n|cffffd200No aura of this name is up right now.|r":
        "|n|n|cffffd200Derzeit ist keine Aura dieses Namens aktiv.|r",

    # ── Adventure guide ─────────────────────────────────────────────────────────────────────────
    "(No abilities recorded for this encounter.)":
        "(Für diese Begegnung sind keine Fähigkeiten verzeichnet.)",
    "(no model)": "(kein Modell)",
    "Adventure Guide": "Abenteuerführer",
    "Eastern Kingdoms": "Östliche Königreiche",
    "Kalimdor": "Kalimdor",
    "Model will load once seen within this session due to client limitations.":
        "Das Modell wird geladen, sobald es in dieser Sitzung gesehen wurde (Clienteinschränkung).",
    "Phase %d": "Phase %d",
    "The Adventure Guide: bosses, abilities, and loot for Classic and Burning Crusade dungeons and "
    "raids (/aguide).":
        "Der Abenteuerführer: Bosse, Fähigkeiten und Beute für Dungeons und Schlachtzüge aus Classic und "
        "Burning Crusade (/aguide).",

    # ── Guild ───────────────────────────────────────────────────────────────────────────────────
    "GuildControlPopupFrame is missing on this client.":
        "GuildControlPopupFrame fehlt in diesem Client.",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "Modernes Gildenfenster im Communities-Stil (Liste / Info / Chat).",
    "Promote": "Befördern",

    # ── Level up display ────────────────────────────────────────────────────────────────────────
    "Battleground available": "Schlachtfeld verfügbar",
    "Can be learned from a trainer": "Bei einem Lehrer erlernbar",
    "Dungeon available": "Dungeon verfügbar",
    "Enable Level Up Display": "Stufenaufstiegsanzeige aktivieren",
    "Level Up Display": "Stufenaufstiegsanzeige",
    "New Feature": "Neue Funktion",
    "New Riding Skill": "Neue Reitfertigkeit",
    "New Talent Point": "Neuer Talentpunkt",
    "New Talent Points": "Neue Talentpunkte",
    "New rank available": "Neuer Rang verfügbar",
    "On by default. Turn off to stop the banner appearing on level-up; the harvest keeps running "
    "either way, so turning it back on costs nothing.":
        "Standardmäßig an. Ausschalten verhindert das Banner beim Stufenaufstieg; die Datensammlung läuft "
        "ohnehin weiter, das Wiedereinschalten kostet also nichts.",
    "Play the level-up sound": "Stufenaufstiegston abspielen",
    "Raid available": "Schlachtzug verfügbar",
    "Retail's level-up banner. What it announces is read from |cffffcc55this server|r — abilities and "
    "their levels come from your class trainer's own list, battlegrounds and dungeons from the "
    "client's brackets. Visit a trainer once to fill it in; |cffffcc55/nelevelup coverage|r shows "
    "what it knows.":
        "Das Stufenaufstiegsbanner aus Retail. Was es ankündigt, wird von |cffffcc55diesem Server|r "
        "gelesen — Fähigkeiten und ihre Stufen stammen aus der Liste Eures Klassenlehrers, Schlachtfelder "
        "und Dungeons aus den Stufenbereichen des Clients. Besucht einmal einen Lehrer, um es zu füllen; "
        "|cffffcc55/nelevelup coverage|r zeigt, was bekannt ist.",
    "Talents": "Talente",
    "You have reached": "Ihr habt erreicht",
    "level %d": "Stufe %d",
    "|cffffcc55Off by default.|r The game already plays its own fanfare when you level, so this only "
    "adds a second copy on top of it. Turn it on if you want /nelevelup previews to make a sound, "
    "since those fire no game sound of their own.":
        "|cffffcc55Standardmäßig aus.|r Das Spiel spielt beim Stufenaufstieg bereits eine eigene Fanfare, "
        "dies legt also nur eine zweite darüber. Schaltet es ein, wenn Vorschauen mit /nelevelup einen Ton "
        "erzeugen sollen, da diese keinen eigenen Spielton auslösen.",

    # ── Professions window ──────────────────────────────────────────────────────────────────────
    "Auctionator API not available for reagent scans.":
        "Die Auctionator-API steht für Reagenziensuchen nicht zur Verfügung.",
    "Auctionator scan started for recipe reagents.":
        "Auctionator-Suche für die Reagenzien des Rezepts gestartet.",
    "Open the Auction House first to run Auctionator scans.":
        "Öffnet zuerst das Auktionshaus, um Auctionator-Suchen auszuführen.",
    "Requires the Auction House window to be open.":
        "Erfordert ein geöffnetes Auktionshausfenster.",
    "Requires: %s": "Erfordert: %s",
    "Retail-style crafting window for all professions.":
        "Herstellungsfenster im Retail-Stil für alle Berufe.",
    "Scan AH": "AH durchsuchen",
    "Searches Auctionator for the selected recipe and its reagents.":
        "Durchsucht Auctionator nach dem gewählten Rezept und seinen Reagenzien.",

    # ── Social ──────────────────────────────────────────────────────────────────────────────────
    "Away": "Abwesend",
    "Busy": "Beschäftigt",
    "Cancel Extend": "Verlängerung abbrechen",
    "Enter a note for %s:": "Gebt eine Notiz für %s ein:",
    "Extend": "Verlängern",
    "Extended": "Verlängert",
    "ID: %s": "ID: %s",
    "Instance": "Instanz",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "Modernes Freundesfenster (Freunde / Ignorieren / Wer) mit Gildenreiter.",
    "Promote to Assistant": "Zum Assistenten befördern",
    "Promote to Raid Leader": "Zum Schlachtzugsleiter befördern",
    "Resets In": "Zurücksetzung in",
    "Set Note": "Notiz festlegen",
    "You are not saved to any instances.": "Ihr seid an keine Instanzen gebunden.",

    # ── Spellbook ───────────────────────────────────────────────────────────────────────────────
    "Spellbook": "Zauberbuch",
    "The modern Dragonflight spellbook window. Disable to keep the stock Blizzard spellbook.":
        "Das moderne Dragonflight-Zauberbuchfenster. Deaktivieren, um das Standardzauberbuch von Blizzard "
        "zu behalten.",

    # ── Talents ─────────────────────────────────────────────────────────────────────────────────
    "  %s: have %d, build wants %d": "  %s: vorhanden %d, Build benötigt %d",
    "%s\\n\\nImport anyway?": "%s\\n\\nTrotzdem importieren?",
    "ACTIVE EFFECTS": "AKTIVE EFFEKTE",
    "Activate": "Aktivieren",
    "Copy this build string (Ctrl+C). Talented & the WoWhead/wotlkdb calculators import it too:":
        "Kopiert diesen Build-Code (Strg+C). Talented sowie die Rechner von WoWhead/wotlkdb importieren ihn "
        "ebenfalls:",
    "Delete loadout '%s'?": "Die Vorlage '%s' löschen?",
    "GLYPHS": "GLYPHEN",
    "Glyph options": "Glyphenoptionen",
    "Glyphs": "Glyphen",
    "Import…": "Importieren…",
    "Loadouts": "Vorlagen",
    "Locked": "Gesperrt",
    "MAJOR GLYPHS": "GROSSE GLYPHEN",
    "MINOR GLYPHS": "KLEINE GLYPHEN",
    "NO ACTIVE EFFECTS": "KEINE AKTIVEN EFFEKTE",
    "Name this imported loadout:": "Gebt dieser importierten Vorlage einen Namen:",
    "Name this loadout (saves your current spec):":
        "Gebt dieser Vorlage einen Namen (speichert Eure aktuelle Spezialisierung):",
    "Paste a talent string or calculator URL (Talented / WoWhead / wotlkdb):":
        "Fügt einen Talentcode oder eine Rechner-URL ein (Talented / WoWhead / wotlkdb):",
    "Pet": "Begleiter",
    "Remove this glyph?": "Diese Glyphe entfernen?",
    "Rename loadout:": "Vorlage umbenennen:",
    "Rename specialization": "Spezialisierung umbenennen",
    "Rename this specialization (letters only, max %d):":
        "Diese Spezialisierung umbenennen (nur Buchstaben, max. %d):",
    "Save current spec…": "Aktuelle Spezialisierung speichern…",
    "Server uses custom talents": "Server verwendet eigene Talente",
    "Show glyph effects": "Glypheneffekte anzeigen",
    "Show glyph names": "Glyphennamen anzeigen",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "Kennzeichnet exportierte Builds mit diesem Realm, sodass Importe in andere Layouts zuerst warnen.",
    "Talents Panel": "Talentfenster",
    "The modern talents window. Turn off to use the standard Blizzard talent window.":
        "Das moderne Talentfenster. Ausschalten, um das Standardtalentfenster von Blizzard zu verwenden.",
    "This loadout has fewer points in some talents than you've already spent, so it needs a respec "
    "first:\\n":
        "Diese Vorlage hat in einigen Talenten weniger Punkte, als Ihr bereits vergeben habt; sie erfordert "
        "daher zuerst eine Umverteilung:\\n",
    "Toggle slot name labels and the active-effects list.":
        "Schaltet die Platzbezeichnungen und die Liste der aktiven Effekte um.",
    "Unlock Spec": "Spezialisierung freischalten",
    "\\n\\nReset at a class trainer, then load again. (The rest has been staged — click Apply to learn it.)":
        "\\n\\nSetzt bei einem Klassenlehrer zurück und ladet dann erneut. (Der Rest wurde vorbereitet — "
        "klickt auf 'Anwenden', um ihn zu erlernen.)",

    # ── Options panel ───────────────────────────────────────────────────────────────────────────
    "Adventure Guide (Encounter Journal)": "Abenteuerführer (Schlachtzugsbrowser)",
    "Auction House": "Auktionshaus",
    "Boss and loot browser. Requires a /reload to take effect (the micro button doesn't re-check this "
    "live).":
        "Boss- und Beutebrowser. Erfordert ein /reload (die Mikroschaltfläche prüft dies nicht live erneut).",
    "Click for this frame's settings.": "Klicken für die Einstellungen dieses Fensters.",
    "Combined Bag": "Kombinierte Tasche",
    "Custom": "Benutzerdefiniert",
    "Custom scale": "Benutzerdefinierte Skalierung",
    "Drag to move.": "Ziehen zum Verschieben.",
    # Lua escapes the embedded quotes but not the apostrophes, so the key mixes both forms.
    "Each window's size: \\\"Use UI scale\\\" follows the game's UI Scale slider, \\\"No scaling\\\" "
    "stays pixel-perfect, \\\"Custom\\\" uses its slider. The custom slider is greyed out and locked "
    "unless that window's mode is set to Custom.":
        "Die Größe jedes Fensters: \"UI-Skalierung verwenden\" folgt dem UI-Skalierungsregler des Spiels, "
        "\"Keine Skalierung\" bleibt pixelgenau, \"Benutzerdefiniert\" nutzt den eigenen Regler. Der "
        "benutzerdefinierte Regler ist gesperrt, solange der Modus des Fensters nicht auf "
        "'Benutzerdefiniert' steht.",
    "Guild": "Gilde",
    "Looking For Group": "Gruppensuche",
    "Looking For Group (Dungeon/Raid Finder)": "Gruppensuche (Dungeon-/Schlachtzugssuche)",
    "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. Panels appear "
    "here as their modules load.":
        "NewEra-Fenster, portiert auf DragonUI. Schaltet ein Fenster unten ein oder aus. Fenster erscheinen "
        "hier, sobald ihre Module geladen werden.",
    "No scaling": "Keine Skalierung",
    "Our all-in-one bag window. Turn OFF to use the stock Blizzard bags instead. Reload (/reload) to "
    "apply.":
        "Unser Alles-in-einem-Taschenfenster. AUSschalten, um stattdessen die Standardtaschen von Blizzard "
        "zu verwenden. /reload zum Anwenden.",
    "Professions": "Berufe",
    "Reload (/reload) to apply.": "/reload zum Anwenden.",
    "Scale mode": "Skalierungsmodus",
    "Scaling controls are unavailable: the 'core\\\\Scale.lua' file isn't loaded. Make sure your "
    "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.":
        "Die Skalierungsregler sind nicht verfügbar: Die Datei 'core\\Scale.lua' ist nicht geladen. Stellt "
        "sicher, dass Euer installiertes DragonUI_NewEra core/Scale.lua UND dessen Zeile in der .toc "
        "enthält, und führt dann /reload aus.",
    "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).":
        "Die Skalierungsregler benötigen ein neueres DragonUI-Optionsfenster (AddSlider/AddDropdown).",
    "Social": "Sozial",
    "Social (Friends/Who/Guild/Chat/Raid)": "Sozial (Freunde/Wer/Gilde/Chat/Schlachtzug)",
    "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.":
        "Das Fenster von DragonUI anstelle des Blizzard-Standards verwenden. Änderungen wirken nach einem "
        "/reload.",
    "Use UI scale": "UI-Skalierung verwenden",
    "Window Scaling": "Fensterskalierung",
    "Windows": "Fenster",

    # ── Shared UI ───────────────────────────────────────────────────────────────────────────────
    "Select All": "Alles auswählen",

    # ── Inspect ──────────────────────────────────────────────────────────────────
    #
    # Honor / Arena / Rating / Kills are FALLBACKS: modules/inspect/PvPPane.lua prefers the
    # client's own HONOR / ARENA / RATING / HONORABLE_KILLS globals and only reaches for these
    # if one of them is missing.
    "Arena": "Arena",
    "Honor": "Ehre",
    "Inspect window": "Untersuchen-Fenster",
    "Kills": "Siege",
    "Modern frame, portrait and tabs on the inspect window, with its Character tab laid out like the character window. Reload (/reload) to apply.":
        "Modernes Fenster, Porträt und Tabs für das Untersuchen-Fenster; der Charakter-Tab ist wie das Charakterfenster aufgebaut. Zum Übernehmen /reload ausführen.",
    "No team": "Kein Team",
    "Rating": "Wertung",
    "Unranked": "Kein Rang",
    "View this player's talents.": "Die Talente dieses Spielers ansehen.",
    "points spent": "Punkte vergeben",
}
