# -*- coding: utf-8 -*-
"""Latin American Spanish. Inherits esES and overrides only where the two genuinely differ.

Blizzard's esMX drops the peninsular "vosotros"/"tú" imperative forms this addon's esES copy uses in
a handful of places, and prefers a few different nouns ("ordenar" vs "clasificar" is NOT one of them;
the real divergences are listed below). Everything unlisted falls through to esES, which keeps the
two from drifting on the ~370 strings where they agree.
"""

EXTENDS = "esES"

T = {
    # Regional vocabulary.
    "Guild": "Cofradía",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "Ventana de cofradía moderna estilo Comunidades (Lista / Información / Chat).",
    "Promote to Raid Leader": "Ascender a líder de banda",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "Etiqueta las builds exportadas con este servidor para que las importaciones en otros diseños "
        "avisen antes.",
    "Pet": "Mascota",
    "Resilience": "Temple",
    "First Aid": "Primeros auxilios",
    "Leatherworking": "Peletería",
    "Herbalism": "Herboristería",

    # esMX uses "hermandad" only for guild-as-organisation in a few strings; the window title and the
    # promote actions read better as cofradía, matching the client's own glossary.
    "Social (Friends/Who/Guild/Chat/Raid)": "Social (Amigos/Quién/Cofradía/Chat/Banda)",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "Ventana de amigos moderna (Amigos / Ignorados / Quién) con pestaña de cofradía.",
}
