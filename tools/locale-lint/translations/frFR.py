# -*- coding: utf-8 -*-
"""French translations. Keys are the enUS.lua source text verbatim.

Machine-drafted. Placeholder parity is enforced by check_keys.py --verify; wording is not reviewed.
"""

T = {
    # ── Professions ─────────────────────────────────────────────────────────────────────────────
    "Alchemy": "Alchimie",
    "Blacksmithing": "Forge",
    "Enchanting": "Enchantement",
    "Engineering": "Ingénierie",
    "Herbalism": "Herboristerie",
    "Leatherworking": "Travail du cuir",
    "Mining": "Minage",
    "Smelting": "Fonte",
    "Skinning": "Dépeçage",
    "Tailoring": "Couture",
    "Inscription": "Calligraphie",
    "Jewelcrafting": "Joaillerie",
    "Prospecting": "Prospection",
    "Cooking": "Cuisine",
    "First Aid": "Secourisme",
    "Fishing": "Pêche",
    "Select a recipe to craft": "Sélectionnez une recette à fabriquer",
    "Hide item tooltips in list": "Masquer les infobulles d'objet dans la liste",
    "Colour names by skill difficulty": "Colorer les noms selon la difficulté",
    "Plain skill bar (no animation)": "Barre de compétence simple (sans animation)",
    "Create": "Créer",
    "Create All": "Tout créer",
    "Show Learned": "Afficher les apprises",
    "Has Skill Up": "Fait progresser",
    "Have Materials": "Composants disponibles",

    # ── Character, titles, equipment manager ────────────────────────────────────────────────────
    "None": "Aucun",

    # ── Auction house ───────────────────────────────────────────────────────────────────────────
    " -- partial scan": " -- analyse partielle",
    "Auction query is throttled. Try again in a moment.":
        "La requête d'hôtel des ventes est limitée. Réessayez dans un instant.",
    "Buy out this auction for %s?": "Acheter cette enchère pour %s ?",
    r"Choose search criteria and press \"Search\"":
        "Choisissez des critères puis cliquez sur \"Rechercher\"",
    "Loading results...": "Chargement des résultats...",
    "Lvl": "Niv",
    "Modern visual shell for Buy/Sell/Auctions with optional Auctionator tab embedding.":
        "Interface moderne pour Acheter/Vendre/Enchères, avec onglet Auctionator optionnel.",
    "No listings.": "Aucune annonce.",
    "No results. Adjust filters and search again.":
        "Aucun résultat. Ajustez les filtres et relancez la recherche.",
    "Page %d of %d  (items %d-%d of %d, from %d auction)%s":
        "Page %d sur %d  (objets %d-%d sur %d, sur %d enchère)%s",
    "Page %d of %d  (items %d-%d of %d, from %d auctions)%s":
        "Page %d sur %d  (objets %d-%d sur %d, sur %d enchères)%s",
    "Page 1 of 1": "Page 1 sur 1",
    "Per Item": "À l'unité",
    "Place a bid of %s?": "Enchérir de %s ?",
    "Scanning page %d of %d...": "Analyse de la page %d sur %d...",
    "Searching...": "Recherche...",
    "Sort Per Item": "Trier par prix unitaire",
    "You have no auctions.": "Vous n'avez aucune enchère.",

    # ── Bags ────────────────────────────────────────────────────────────────────────────────────
    "All Bags": "Tous les sacs",
    "Auto-empty old bag when swapping": "Vider l'ancien sac lors d'un échange",
    "Auto-sell junk at merchants": "Vendre automatiquement la camelote chez les marchands",
    "Bag Options": "Options de sac",
    "Category (smart)": "Catégorie (intelligent)",
    "Combined bag (all-in-one)": "Sac combiné (tout-en-un)",
    "Item Level": "Niveau d'objet",
    "Keys": "Clés",
    "Merchant": "Marchand",
    "Name": "Nom",
    "Not enough free space to swap that bag.":
        "Pas assez de place libre pour échanger ce sac.",
    "One movable window showing every bag slot in a Dragonflight-style grid. Takes over bag opening "
    "and replaces the per-window 'Retail bags' restyle. Reload (/reload) to apply.":
        "Une fenêtre déplaçable affichant tous les emplacements de sac dans une grille façon Dragonflight. "
        "Prend en charge l'ouverture des sacs et remplace l'habillage « Sacs retail » par fenêtre. /reload "
        "pour appliquer.",
    "Quality": "Qualité",
    "Red-tint unusable items": "Teinter en rouge les objets inutilisables",
    "Restyle the bag windows with the Dragonflight metal frame, portrait, and item quality borders. "
    "Disable to keep the stock Blizzard bags. Reload (/reload) to apply.":
        "Réhabille les fenêtres de sac avec le cadre métallique Dragonflight, le portrait et les bordures de "
        "qualité. Désactivez pour conserver les sacs Blizzard d'origine. /reload pour appliquer.",
    "Retail bags": "Sacs retail",
    "Reverse sort order": "Inverser l'ordre de tri",
    "Search": "Rechercher",
    "Separate specialty bags": "Séparer les sacs spécialisés",
    "Shift-right-click to stop watching": "Maj+clic droit pour arrêter la surveillance",
    "Show item level on items": "Afficher le niveau d'objet sur les objets",
    "Show keyring row": "Afficher la rangée du trousseau",
    "Sold %d junk item(s).": "%d objet(s) de camelote vendu(s).",
    "Sort Bags": "Trier les sacs",
    "Sort by": "Trier par",
    "Sorting…": "Tri en cours…",
    "Swapping bag…": "Échange du sac…",
    "The same setting as Enable Item Level in DragonUI's options (Enhancements > Item Level). "
    "Covers the character panel and every other frame too.":
        "Le même réglage que « Activer le niveau d'objet » dans les options de DragonUI (Améliorations > "
        "Niveau d'objet). Couvre également la fenêtre de personnage et toutes les autres fenêtres.",
    "Turn on Item Level in DragonUI's options (Enhancements > Item Level) first.":
        "Activez d'abord « Niveau d'objet » dans les options de DragonUI (Améliorations > Niveau d'objet).",

    # ── Cooldown manager ────────────────────────────────────────────────────────────────────────
    "(empty)": "(vide)",
    "(your spec)": "(votre spécialisation)",
    "A ready sound plays when a COOLDOWN finishes.|nThis spell has none, so it can never play."
    "|nClearing it also clears the badge.":
        "Un son de disponibilité retentit à la fin d'un TEMPS DE RECHARGE.|nCe sort n'en a pas, il ne pourra "
        "donc jamais retentir.|nLe réinitialiser efface aussi le badge.",
    "A spell can be on cooldown and buffing you at the same time. The glow says which icons are "
    "buffed; the timer says how long.":
        "Un sort peut être en recharge et vous améliorer en même temps. La lueur indique quelles icônes sont "
        "améliorées ; le minuteur, pour combien de temps.",
    "Active": "Actif",
    "Alert": "Alerte",
    "Always": "Toujours",
    "Auto-track buffs under %ds": "Suivre automatiquement les bonus de moins de %ds",
    "Available": "Disponible",
    "Bar Content": "Contenu de la barre",
    "Bar Width": "Largeur de la barre",
    "Both of these are immediate and cannot be undone from here — Revert only covers layout changes.":
        "Ces deux actions sont immédiates et irréversibles depuis ici — « Rétablir » ne couvre que les "
        "changements de disposition.",
    "Buff Bars": "Barres de bonus",
    "Buff Icons": "Icônes de bonus",
    "Buff tracking": "Suivi des bonus",
    "Buffed spells": "Sorts améliorés",
    "Buffs you have not seen before are recorded and listed under Not Displayed on the Tracked Buffs "
    "tab, where you can assign the ones you want. Nothing appears on screen until you do.":
        "Les bonus encore inconnus sont enregistrés et listés sous « Non affichés » dans l'onglet « Bonus "
        "suivis », où vous pouvez assigner ceux que vous voulez. Rien n'apparaît à l'écran avant cela.",
    "Button Glow": "Lueur de bouton",
    "Clear All Alerts": "Effacer toutes les alertes",
    "Clear Ready Sound": "Effacer le son de disponibilité",
    "Clear all alerts and sounds": "Effacer toutes les alertes et tous les sons",
    "Clear every configured alert and ready sound?\\n\\nSpell lists and frame positions are not affected.":
        "Effacer toutes les alertes et tous les sons de disponibilité configurés ?\\n\\nLes listes de sorts et "
        "les positions des fenêtres ne sont pas affectées.",
    "Closes edit mode and opens the Cooldown Manager window, which carries the settings that are not "
    "per-viewer: alerts, ready sounds, buff tracking, icon fit and the resets.":
        "Ferme le mode édition et ouvre la fenêtre du Gestionnaire de temps de recharge, qui contient les "
        "réglages non propres à un afficheur : alertes, sons de disponibilité, suivi des bonus, ajustement "
        "des icônes et les réinitialisations.",
    "Cooldown Manager": "Gestionnaire de temps de recharge",
    "Cooldown Manager Settings": "Réglages du Gestionnaire de temps de recharge",
    "Cooldown Manager layout string (Ctrl+C to copy):":
        "Code de disposition du Gestionnaire de temps de recharge (Ctrl+C pour copier) :",
    "Copy": "Copier",
    "Defensives, interrupts, CC and escapes.":
        "Défensifs, interruptions, contrôle et fuites.",
    "Delete": "Supprimer",
    r'Delete the layout \"%s\"?': 'Supprimer la disposition \"%s\" ?',
    "Drag onto Essential or Utility to track it.":
        "Faites-le glisser sur « Essentiels » ou « Utilitaires » pour le suivre.",
    "Draw the countdown number on each icon.": "Afficher le décompte sur chaque icône.",
    "Each viewer's own settings — size, spacing, orientation, visibility, what its icons show — live "
    "on the frame, in edit mode, where you can see what you are changing. These open edit mode with "
    "that viewer selected and its settings already up. Closes this window; not available in combat.":
        "Les réglages propres à chaque afficheur — taille, espacement, orientation, visibilité, contenu des "
        "icônes — se trouvent sur le cadre lui-même, en mode édition, où vous voyez ce que vous modifiez. Ces "
        "boutons ouvrent le mode édition avec cet afficheur sélectionné et ses réglages déjà ouverts. Ferme "
        "cette fenêtre ; indisponible en combat.",
    "Enable Cooldown Manager": "Activer le Gestionnaire de temps de recharge",
    "Enabled": "Activé",
    "Essential Cooldowns": "Temps de recharge essentiels",
    "Everything": "Tout",
    "Everything (no spec)": "Tout (sans spécialisation)",
    "Everything the Cooldown Manager can be told to do that is not about one viewer's layout. Layout "
    "and position both live on the frame itself, in edit mode (/dui edit) — click a viewer there for "
    "its own settings, or use the buttons just below to go straight to one.":
        "Tout ce que le Gestionnaire de temps de recharge peut faire qui ne concerne pas la disposition d'un "
        "afficheur. Disposition et position se trouvent sur le cadre lui-même, en mode édition (/dui edit) — "
        "cliquez-y sur un afficheur pour ses propres réglages, ou utilisez les boutons ci-dessous.",
    "Export Layout": "Exporter la disposition",
    "FX Style": "Style d'effet",
    "Flashes once, the moment the cooldown finishes.|nWorks for every spell.":
        "Clignote une fois, dès la fin du temps de recharge.|nFonctionne pour tous les sorts.",
    "Frame strength": "Intensité du cadre",
    "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is the "
    "stock look, not a bug.":
        "Espace entre les icônes. Retail décale cette valeur de -4, si bien qu'elles se chevauchent "
        "légèrement en bas de plage — c'est le rendu d'origine, pas un bug.",
    "Glow while buffed": "Luire tant que le bonus est actif",
    "Glows during the last %d%% of this buff's|nremaining time.":
        "Luit pendant les derniers %d%% du temps|nrestant de ce bonus.",
    "Glows during the last %d%% of this spell's own|nbuff or debuff.":
        "Luit pendant les derniers %d%% du bonus ou|nmalus propre à ce sort.",
    "Glows for as long as the spell is off cooldown|nand affordable.":
        "Luit tant que le sort est disponible|net que vous pouvez le lancer.",
    "Glows for as long as this buff is on you.|n|nThe one that works for a proc: it asks whether "
    "the|nbuff is up, not whether something is castable|nor off cooldown.":
        "Luit tant que ce bonus est sur vous.|n|nCelui qui convient à un proc : il vérifie si le|nbonus est "
        "actif, pas si quelque chose est lançable|nou disponible.",
    "Glows for as long as this spell's effect is|nup on %s.":
        "Luit tant que l'effet de ce sort est|nactif sur %s.",
    "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.":
        "Entoure l'icône d'un halo doré tant que le bonus du sort (ou, pour un chaman, son totem) est actif.",
    "Hidden": "Masqué",
    "Hide When Inactive": "Masquer si inactif",
    "Horizontal": "Horizontal",
    "How many icons before the layout wraps. Vertical orientation reads this as icons per column.":
        "Nombre d'icônes avant que la disposition ne passe à la ligne. En orientation verticale, il s'agit "
        "d'icônes par colonne.",
    "Icon Direction": "Sens des icônes",
    "Icon Limit": "Limite d'icônes",
    "Icon Only": "Icône seule",
    "Icon Padding": "Espacement des icônes",
    "Icon Size": "Taille des icônes",
    "Icon and Name": "Icône et nom",
    "Icon fit": "Ajustement des icônes",
    "Icon inset": "Retrait de l'icône",
    "Import": "Importer",
    "Import Layout": "Importer une disposition",
    "In Combat": "En combat",
    "Lasts %s sec": "Dure %s s",
    "Layouts": "Dispositions",
    "Layouts include appearance": "Les dispositions incluent l'apparence",
    "Left": "Gauche",
    "Load the %s starter layout?\\n\\nEssential is set to that spec's spells. Everything else for your "
    "class moves to Not Displayed — nothing is deleted, and you can drag any of it back.\\n\\nTracked "
    "auras, trinkets, alerts and frame positions are not affected.":
        "Charger la disposition de départ %s ?\\n\\n« Essentiels » reprend les sorts de cette "
        "spécialisation. Tout le reste de votre classe passe dans « Non affichés » — rien n'est supprimé et "
        "vous pouvez tout ramener par glisser-déposer.\\n\\nLes auras suivies, bijoux, alertes et positions de "
        "fenêtres ne sont pas affectés.",
    "Marching Ants": "Fourmis en marche",
    "Move to %s": "Déplacer vers %s",
    "Name Only": "Nom seul",
    "Name this layout:": "Nommez cette disposition :",
    "New Layout": "Nouvelle disposition",
    "Not displayed on any viewer": "Affiché sur aucun afficheur",
    "Not yet learned": "Pas encore appris",
    "Nothing to undo. It covers LAYOUTS, not the settings|non these tabs — a viewer's own size and "
    "position revert|nfrom its edit-mode panel instead.":
        "Rien à annuler. Cela couvre les DISPOSITIONS, pas les réglages|nde ces onglets — la taille et la "
        "position d'un afficheur|nse rétablissent depuis son panneau en mode édition.",
    "Off by default. Turn on to show the four viewers; turn off to hide them again. Takes effect "
    "immediately either way, and nothing is forgotten — this switch stores one flag and touches "
    "nothing else, so your setup comes back exactly as you left it.":
        "Désactivé par défaut. Activez-le pour afficher les quatre afficheurs, désactivez-le pour les "
        "masquer à nouveau. L'effet est immédiat dans les deux sens et rien n'est oublié : cet interrupteur "
        "n'enregistre qu'un indicateur et ne touche à rien d'autre, votre configuration revient donc "
        "exactement telle que vous l'avez laissée.",
    "Off, both specs share one set of lists. Turning it on copies the layout you have now into the "
    "spec you are in.":
        "Désactivé, les deux spécialisations partagent un même jeu de listes. En l'activant, la disposition "
        "actuelle est copiée dans la spécialisation où vous êtes.",
    "Off, loading or importing a layout changes only what you track — lists, tracked buffs, trinkets, "
    "alerts and sounds. On, it also applies the orientation, icons per row, size, padding and opacity "
    "the layout was saved with.|n|nLayouts always SAVE appearance either way, so this only decides "
    "what happens when one is applied. Revert always puts appearance back, whatever this says.":
        "Désactivé, charger ou importer une disposition ne change que ce que vous suivez : listes, bonus "
        "suivis, bijoux, alertes et sons. Activé, cela applique aussi l'orientation, les icônes par ligne, "
        "la taille, l'espacement et l'opacité enregistrés avec la disposition.|n|nLes dispositions "
        "ENREGISTRENT toujours l'apparence dans les deux cas ; ceci ne décide donc que de ce qui se passe à "
        "l'application. « Rétablir » restaure toujours l'apparence, quoi que dise cette option.",
    "Off, orientation, icons per row, size, padding and opacity are one setup for every character. On, "
    "each character can differ — until you change something here it still follows the shared setup, so "
    "nothing moves when you tick this, and unticking it gives the shared setup back without losing "
    "what you changed.":
        "Désactivé, l'orientation, les icônes par ligne, la taille, l'espacement et l'opacité forment une "
        "seule configuration pour tous les personnages. Activé, chaque personnage peut différer : tant que "
        "vous ne changez rien ici, il suit encore la configuration partagée, donc rien ne bouge en cochant "
        "cette case, et la décocher rend la configuration partagée sans perdre vos modifications.",
    "Offensive burst and damage cooldowns.":
        "Temps de recharge offensifs de burst et de dégâts.",
    "Opacity": "Opacité",
    "Open Cooldown Manager": "Ouvrir le Gestionnaire de temps de recharge",
    "Opens a share string you can copy with Ctrl+C.|nIt covers this class's spell lists, tracked "
    "auras,|ntrinket placement, alerts and sounds.":
        "Ouvre un code de partage copiable avec Ctrl+C.|nIl couvre les listes de sorts de cette classe, les "
        "auras suivies,|nle placement des bijoux, les alertes et les sons.",
    "Opens the Cooldown Manager window (/cdm) on its Spells tab. Needs the module on — the window "
    "configures the viewers, so it goes away with them.":
        "Ouvre la fenêtre du Gestionnaire de temps de recharge (/cdm) sur l'onglet « Sorts ». Nécessite le "
        "module activé : la fenêtre configure les afficheurs et disparaît donc avec eux.",
    "Options": "Options",
    "Orientation": "Orientation",
    "Pandemic Border": "Bordure de pandémie",
    "Paste a Cooldown Manager layout string:":
        "Collez un code de disposition du Gestionnaire de temps de recharge :",
    "Ready Sound": "Son de disponibilité",
    "Ready sound: %s": "Son de disponibilité : %s",
    "Refresh": "Rafraîchir",
    "Refresh Window": "Fenêtre de rafraîchissement",
    "Remove": "Retirer",
    "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.":
        "Retire toutes les alertes et tous les sons de disponibilité par sort. Les listes de sorts et les "
        "positions ne sont pas affectées.",
    "Rename": "Renommer",
    "Requires the %s talent": "Nécessite le talent %s",
    "Reset": "Réinitialiser",
    "Reset %s to its default layout?\\n\\nThis viewer's position, size, orientation and visibility all "
    "go back to stock. Nothing else is affected, and it cannot be undone.":
        "Réinitialiser %s à sa disposition par défaut ?\\n\\nLa position, la taille, l'orientation et la "
        "visibilité de cet afficheur reviennent aux valeurs d'origine. Rien d'autre n'est affecté, et c'est "
        "irréversible.",
    "Reset Spell Lists": "Réinitialiser les listes de sorts",
    "Reset spell and buff lists": "Réinitialiser les listes de sorts et de bonus",
    "Reset this class's Cooldown Manager spell and buff lists to their defaults?\\n\\nOther classes, "
    "alerts, sounds and frame positions are not affected.":
        "Réinitialiser aux valeurs par défaut les listes de sorts et de bonus du Gestionnaire de temps de "
        "recharge pour cette classe ?\\n\\nLes autres classes, les alertes, les sons et les positions de "
        "fenêtres ne sont pas affectés.",
    "Reset to the starter layout?\\n\\nThis reverts every Cooldown Manager edit — spells, tracked auras, "
    "trinket placement, alerts and sounds — to their defaults, and clears your saved-layout "
    "selection.\\n\\nFrame positions are not affected.":
        "Revenir à la disposition de départ ?\\n\\nCela réinitialise toutes les modifications du Gestionnaire "
        "de temps de recharge — sorts, auras suivies, placement des bijoux, alertes et sons — et efface "
        "votre sélection de disposition enregistrée.\\n\\nLes positions des fenêtres ne sont pas affectées.",
    "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its spell lists, "
    "aura assignments and trinket placement. Other classes, alerts, sounds and positions are not "
    "affected.":
        "Restaure les valeurs par défaut sélectionnées et la fenêtre de suivi automatique pour CETTE CLASSE, "
        "en effaçant ses listes de sorts, ses assignations d'auras et son placement de bijoux. Les autres "
        "classes, alertes, sons et positions ne sont pas affectés.",
    "Retail's Cooldown Manager, driven from curated per-class cooldown lists. |cffffcc55Off by "
    "default|r — it adds four viewers to the middle of your screen, so it waits to be asked. Every "
    "setting — which spells and buffs are tracked, each viewer's layout, size and visibility, alerts "
    "and ready sounds — lives in the Cooldown Manager window itself (/cdm). Drag the viewers with "
    "DragonUI's editor mode to reposition them, and right-click one there for its own layout settings.":
        "Le Gestionnaire de temps de recharge de retail, alimenté par des listes de temps de recharge "
        "sélectionnées par classe. |cffffcc55Désactivé par défaut|r — il ajoute quatre afficheurs au centre "
        "de votre écran et attend donc qu'on le lui demande. Chaque réglage — quels sorts et bonus sont "
        "suivis, la disposition, la taille et la visibilité de chaque afficheur, les alertes et les sons de "
        "disponibilité — se trouve dans la fenêtre du Gestionnaire elle-même (/cdm). Déplacez les afficheurs "
        "avec le mode édition de DragonUI et faites-y un clic droit sur l'un d'eux pour ses propres réglages "
        "de disposition.",
    "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the spell's "
    "cooldown and the glow alone marks it as buffed — which is clearer when the two differ, as on "
    "Prayer of Mending.":
        "Comportement de retail : tant que le bonus est actif, l'icône décompte le BONUS. Désactivé, elle "
        "décompte le temps de recharge du sort et seule la lueur signale le bonus — ce qui est plus clair "
        "quand les deux diffèrent, comme pour « Prière de guérison ».",
    "Revert": "Rétablir",
    "Right": "Droite",
    "Save, load, import and export the whole|nCooldown Manager setup for this class.":
        "Enregistrer, charger, importer et exporter toute la configuration|ndu Gestionnaire de temps de "
        "recharge pour cette classe.",
    "Separate appearance per character": "Apparence distincte par personnage",
    "Separate layout per spec": "Disposition distincte par spécialisation",
    "Short-duration buffs and procs, as depleting bars.":
        "Bonus et procs de courte durée, sous forme de barres décroissantes.",
    "Short-duration buffs and procs, as icons.":
        "Bonus et procs de courte durée, sous forme d'icônes.",
    "Show Timer": "Afficher le minuteur",
    "Show Tooltips": "Afficher les infobulles",
    "Show Unlearned": "Afficher les non appris",
    "Show a slot only while its aura is active.":
        "N'afficher un emplacement que tant que son aura est active.",
    "Show a tooltip when hovering an icon.":
        "Afficher une infobulle au survol d'une icône.",
    "Show every short buff the moment it lands, without assigning it first. Convenient on a character "
    "you are still setting up; in a raid it fills the viewers with other people's cooldowns, food and "
    "flasks.":
        "Affiche tout bonus court dès qu'il s'applique, sans l'assigner au préalable. Pratique sur un "
        "personnage en cours de configuration ; en raid, cela remplit les afficheurs des temps de recharge, "
        "nourritures et flacons des autres.",
    "Show the buff's time, not the cooldown":
        "Afficher la durée du bonus, pas le temps de recharge",
    "Show them as": "Les afficher comme",
    "Show this viewer at all. The editor handle stays either way, so this is reversible from right here.":
        "Afficher ou non cet afficheur. La poignée d'édition reste dans les deux cas, c'est donc réversible "
        "d'ici même.",
    "Sparkles": "Étincelles",
    "Talent specs": "Spécialisations de talents",
    "The frame is a soft shadow that falls on the icon's outer edge, so it only shows where there is "
    "icon underneath it. Strength draws it more than once to deepen it — that is also what makes its "
    "rounded corners read, since the icons themselves cannot be rounded here. Inset shrinks the icon, "
    "which slides the shadow off it, so raise that one sparingly.":
        "Le cadre est une ombre douce qui tombe sur le bord extérieur de l'icône ; il n'apparaît donc que là "
        "où une icône se trouve dessous. L'intensité le dessine plusieurs fois pour le renforcer — c'est "
        "aussi ce qui rend ses coins arrondis lisibles, puisque les icônes elles-mêmes ne peuvent pas être "
        "arrondies ici. Le retrait rétrécit l'icône, ce qui fait glisser l'ombre hors d'elle : augmentez-le "
        "avec parcimonie.",
    "The full curated list for your class, both specs' spells|nincluded. This is what the Cooldown "
    "Manager shipped with|nbefore per-spec starters.":
        "La liste complète sélectionnée pour votre classe, sorts des deux|nspécialisations inclus. C'est ce "
        "que contenait le Gestionnaire|navant les dispositions de départ par spécialisation.",
    "Tracked automatically. Drag it into a section to pin it there.":
        "Suivi automatiquement. Faites-le glisser dans une section pour l'y épingler.",
    "Undoes the last layout change — applying a layout,|nimporting one, or the starter reset.|n|nOne "
    "step, and only for this session.":
        "Annule le dernier changement de disposition — appliquer une disposition,|nen importer une ou "
        "réinitialiser celle de départ.|n|nUne seule étape, et seulement pour cette session.",
    "Usable": "Utilisable",
    "Use Starter Layout": "Utiliser la disposition de départ",
    "Utility Cooldowns": "Temps de recharge utilitaires",
    "Vertical": "Vertical",
    "Viewer layout": "Disposition de l'afficheur",
    "Visibility": "Visibilité",
    "When this viewer is on screen at all. Hidden still leaves the editor handle here.":
        "Quand cet afficheur est visible à l'écran. « Masqué » laisse tout de même la poignée d'édition ici.",
    "Which of the two buff viewers auto-tracked buffs land in.":
        "Dans lequel des deux afficheurs de bonus arrivent les bonus suivis automatiquement.",
    "Which spells and buffs you track is remembered separately for each talent spec, so a Discipline "
    "layout and a Holy one do not overwrite each other. Where each viewer sits is always remembered "
    "per character; the appearance settings are shared unless you say otherwise below.":
        "Les sorts et bonus que vous suivez sont mémorisés séparément pour chaque spécialisation, si bien "
        "qu'une disposition Discipline et une Sacré ne s'écrasent pas. La position de chaque afficheur est "
        "toujours mémorisée par personnage ; les réglages d'apparence sont partagés sauf indication "
        "contraire ci-dessous.",
    "is turned off. Enable it in DragonUI's options, under New Era > Cooldown Manager.":
        "est désactivé. Activez-le dans les options de DragonUI, sous New Era > Gestionnaire de temps de "
        "recharge.",
    "you": "vous",
    "|n|nOn a buff row this is about RE-CASTING it,|nnot about the buff being up — that is Active.":
        "|n|nSur une ligne de bonus, il s'agit de le RELANCER,|npas de savoir si le bonus est actif — c'est "
        "« Actif ».",
    "|n|nThe one for a DoT or a shield: it asks whether|nthe aura is up, not whether the cooldown is "
    "ready.":
        "|n|nCelui qui convient à un DoT ou un bouclier : il vérifie si|nl'aura est active, pas si le temps "
        "de recharge est prêt.",
    "|n|nThis one also waits for a target below %d%% health.":
        "|n|nCelui-ci attend en plus une cible en dessous de %d%% de vie.",
    "|n|n|cff40ff40Applies %s to %s, so this will work.|r":
        "|n|n|cff40ff40Applique %s à %s, cela fonctionnera donc.|r",
    "|n|n|cff40ff40Its aura is active now, so this will work.|r":
        "|n|n|cff40ff40Son aura est active en ce moment, cela fonctionnera donc.|r",
    "|n|n|cffffd200No aura of this name is up right now.|r":
        "|n|n|cffffd200Aucune aura de ce nom n'est active actuellement.|r",

    # ── Adventure guide ─────────────────────────────────────────────────────────────────────────
    "(No abilities recorded for this encounter.)":
        "(Aucune capacité enregistrée pour cette rencontre.)",
    "(no model)": "(aucun modèle)",
    "Adventure Guide": "Guide d'aventure",
    "Eastern Kingdoms": "Royaumes de l'Est",
    "Kalimdor": "Kalimdor",
    "Model will load once seen within this session due to client limitations.":
        "Le modèle se chargera une fois vu au cours de cette session, en raison des limites du client.",
    "Phase %d": "Phase %d",
    "The Adventure Guide: bosses, abilities, and loot for Classic and Burning Crusade dungeons and "
    "raids (/aguide).":
        "Le Guide d'aventure : boss, capacités et butin des donjons et raids de Classic et Burning Crusade "
        "(/aguide).",

    # ── Guild ───────────────────────────────────────────────────────────────────────────────────
    "GuildControlPopupFrame is missing on this client.":
        "GuildControlPopupFrame est absent de ce client.",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "Fenêtre de guilde moderne façon Communautés (Liste / Infos / Discussion).",
    "Promote": "Promouvoir",

    # ── Level up display ────────────────────────────────────────────────────────────────────────
    "Battleground available": "Champ de bataille disponible",
    "Can be learned from a trainer": "Peut être appris auprès d'un maître",
    "Dungeon available": "Donjon disponible",
    "Enable Level Up Display": "Activer l'annonce de niveau",
    "Level Up Display": "Annonce de niveau",
    "New Feature": "Nouveauté",
    "New Riding Skill": "Nouvelle compétence d'équitation",
    "New Talent Point": "Nouveau point de talent",
    "New Talent Points": "Nouveaux points de talent",
    "New rank available": "Nouveau rang disponible",
    "On by default. Turn off to stop the banner appearing on level-up; the harvest keeps running "
    "either way, so turning it back on costs nothing.":
        "Activé par défaut. Désactivez-le pour que la bannière n'apparaisse plus au passage de niveau ; la "
        "collecte continue de toute façon, le réactiver ne coûte donc rien.",
    "Play the level-up sound": "Jouer le son de passage de niveau",
    "Raid available": "Raid disponible",
    "Retail's level-up banner. What it announces is read from |cffffcc55this server|r — abilities and "
    "their levels come from your class trainer's own list, battlegrounds and dungeons from the "
    "client's brackets. Visit a trainer once to fill it in; |cffffcc55/nelevelup coverage|r shows "
    "what it knows.":
        "La bannière de passage de niveau de retail. Ce qu'elle annonce est lu depuis |cffffcc55ce "
        "serveur|r — les capacités et leurs niveaux proviennent de la liste de votre maître de classe, les "
        "champs de bataille et donjons des tranches du client. Rendez visite une fois à un maître pour la "
        "remplir ; |cffffcc55/nelevelup coverage|r montre ce qui est connu.",
    "Talents": "Talents",
    "You have reached": "Vous avez atteint",
    "level %d": "le niveau %d",
    "|cffffcc55Off by default.|r The game already plays its own fanfare when you level, so this only "
    "adds a second copy on top of it. Turn it on if you want /nelevelup previews to make a sound, "
    "since those fire no game sound of their own.":
        "|cffffcc55Désactivé par défaut.|r Le jeu joue déjà sa propre fanfare au passage de niveau ; ceci "
        "n'en ajoute donc qu'une seconde par-dessus. Activez-le si vous voulez que les aperçus /nelevelup "
        "produisent un son, car ceux-ci ne déclenchent aucun son du jeu.",

    # ── Professions window ──────────────────────────────────────────────────────────────────────
    "Auctionator API not available for reagent scans.":
        "L'API d'Auctionator n'est pas disponible pour analyser les composants.",
    "Auctionator scan started for recipe reagents.":
        "Analyse Auctionator lancée pour les composants de la recette.",
    "Open the Auction House first to run Auctionator scans.":
        "Ouvrez d'abord l'hôtel des ventes pour lancer des analyses Auctionator.",
    "Requires the Auction House window to be open.":
        "Nécessite que la fenêtre de l'hôtel des ventes soit ouverte.",
    "Requires: %s": "Nécessite : %s",
    "Retail-style crafting window for all professions.":
        "Fenêtre d'artisanat façon retail pour tous les métiers.",
    "Scan AH": "Analyser l'HV",
    "Searches Auctionator for the selected recipe and its reagents.":
        "Recherche dans Auctionator la recette sélectionnée et ses composants.",

    # ── Social ──────────────────────────────────────────────────────────────────────────────────
    "Away": "Absent",
    "Busy": "Occupé",
    "Cancel Extend": "Annuler la prolongation",
    "Enter a note for %s:": "Saisissez une note pour %s :",
    "Extend": "Prolonger",
    "Extended": "Prolongé",
    "ID: %s": "ID : %s",
    "Instance": "Instance",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "Fenêtre d'amis moderne (Amis / Ignorés / Qui) avec un onglet Guilde.",
    "Promote to Assistant": "Promouvoir assistant",
    "Promote to Raid Leader": "Promouvoir chef de raid",
    "Resets In": "Réinitialisation dans",
    "Set Note": "Définir une note",
    "You are not saved to any instances.": "Vous n'êtes lié à aucune instance.",

    # ── Spellbook ───────────────────────────────────────────────────────────────────────────────
    "Spellbook": "Grimoire",
    "The modern Dragonflight spellbook window. Disable to keep the stock Blizzard spellbook.":
        "La fenêtre de grimoire moderne façon Dragonflight. Désactivez pour conserver le grimoire Blizzard "
        "d'origine.",

    # ── Talents ─────────────────────────────────────────────────────────────────────────────────
    "  %s: have %d, build wants %d": "  %s : vous avez %d, la build en demande %d",
    "%s\\n\\nImport anyway?": "%s\\n\\nImporter quand même ?",
    "ACTIVE EFFECTS": "EFFETS ACTIFS",
    "Activate": "Activer",
    "Copy this build string (Ctrl+C). Talented & the WoWhead/wotlkdb calculators import it too:":
        "Copiez ce code de build (Ctrl+C). Talented et les calculateurs WoWhead/wotlkdb l'importent aussi :",
    "Delete loadout '%s'?": "Supprimer la configuration « %s » ?",
    "GLYPHS": "GLYPHES",
    "Glyph options": "Options de glyphes",
    "Glyphs": "Glyphes",
    "Import…": "Importer…",
    "Loadouts": "Configurations",
    "Locked": "Verrouillé",
    "MAJOR GLYPHS": "GLYPHES MAJEURS",
    "MINOR GLYPHS": "GLYPHES MINEURS",
    "NO ACTIVE EFFECTS": "AUCUN EFFET ACTIF",
    "Name this imported loadout:": "Nommez cette configuration importée :",
    "Name this loadout (saves your current spec):":
        "Nommez cette configuration (enregistre votre spécialisation actuelle) :",
    "Paste a talent string or calculator URL (Talented / WoWhead / wotlkdb):":
        "Collez un code de talents ou une URL de calculateur (Talented / WoWhead / wotlkdb) :",
    "Pet": "Familier",
    "Remove this glyph?": "Retirer ce glyphe ?",
    "Rename loadout:": "Renommer la configuration :",
    "Rename specialization": "Renommer la spécialisation",
    "Rename this specialization (letters only, max %d):":
        "Renommez cette spécialisation (lettres uniquement, %d max.) :",
    "Save current spec…": "Enregistrer la spécialisation actuelle…",
    "Server uses custom talents": "Le serveur utilise des talents personnalisés",
    "Show glyph effects": "Afficher les effets des glyphes",
    "Show glyph names": "Afficher les noms des glyphes",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "Marque les builds exportées avec ce royaume afin que les imports sur d'autres dispositions "
        "avertissent d'abord.",
    "Talents Panel": "Fenêtre de talents",
    "The modern talents window. Turn off to use the standard Blizzard talent window.":
        "La fenêtre de talents moderne. Désactivez-la pour utiliser la fenêtre de talents Blizzard standard.",
    "This loadout has fewer points in some talents than you've already spent, so it needs a respec "
    "first:\\n":
        "Cette configuration comporte moins de points dans certains talents que vous n'en avez déjà dépensé ; "
        "elle nécessite donc d'abord une réinitialisation :\\n",
    "Toggle slot name labels and the active-effects list.":
        "Affiche ou masque les noms d'emplacement et la liste des effets actifs.",
    "Unlock Spec": "Débloquer la spécialisation",
    "\\n\\nReset at a class trainer, then load again. (The rest has been staged — click Apply to learn it.)":
        "\\n\\nRéinitialisez auprès d'un maître de classe, puis rechargez. (Le reste est préparé — cliquez "
        "sur « Appliquer » pour l'apprendre.)",

    # ── Options panel ───────────────────────────────────────────────────────────────────────────
    "Adventure Guide (Encounter Journal)": "Guide d'aventure (Journal des rencontres)",
    "Auction House": "Hôtel des ventes",
    "Boss and loot browser. Requires a /reload to take effect (the micro button doesn't re-check this "
    "live).":
        "Navigateur de boss et de butin. Nécessite un /reload pour prendre effet (le micro-bouton ne le "
        "revérifie pas en direct).",
    "Click for this frame's settings.": "Cliquez pour les réglages de cette fenêtre.",
    "Combined Bag": "Sac combiné",
    "Custom": "Personnalisé",
    "Custom scale": "Échelle personnalisée",
    "Drag to move.": "Faites glisser pour déplacer.",
    "Each window's size: \\\"Use UI scale\\\" follows the game's UI Scale slider, \\\"No scaling\\\" "
    "stays pixel-perfect, \\\"Custom\\\" uses its slider. The custom slider is greyed out and locked "
    "unless that window's mode is set to Custom.":
        "La taille de chaque fenêtre : \"Utiliser l'échelle de l'interface\" suit le curseur d'échelle du "
        "jeu, \"Aucune mise à l'échelle\" reste au pixel près et \"Personnalisé\" utilise son propre "
        "curseur. Le curseur personnalisé est grisé et verrouillé tant que le mode de cette fenêtre n'est "
        "pas « Personnalisé ».",
    "Guild": "Guilde",
    "Looking For Group": "Recherche de groupe",
    "Looking For Group (Dungeon/Raid Finder)": "Recherche de groupe (donjons/raids)",
    "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. Panels appear "
    "here as their modules load.":
        "Fenêtres NewEra portées sur DragonUI. Activez ou désactivez une fenêtre ci-dessous. Les fenêtres "
        "apparaissent ici à mesure que leurs modules se chargent.",
    "No scaling": "Aucune mise à l'échelle",
    "Our all-in-one bag window. Turn OFF to use the stock Blizzard bags instead. Reload (/reload) to "
    "apply.":
        "Notre fenêtre de sacs tout-en-un. DÉSACTIVEZ-la pour utiliser les sacs Blizzard d'origine. /reload "
        "pour appliquer.",
    "Professions": "Métiers",
    "Reload (/reload) to apply.": "/reload pour appliquer.",
    "Scale mode": "Mode d'échelle",
    "Scaling controls are unavailable: the 'core\\\\Scale.lua' file isn't loaded. Make sure your "
    "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.":
        "Les contrôles d'échelle sont indisponibles : le fichier 'core\\Scale.lua' n'est pas chargé. "
        "Vérifiez que votre installation de DragonUI_NewEra contient core/Scale.lua ET sa ligne dans le "
        ".toc, puis faites /reload.",
    "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).":
        "Les contrôles d'échelle nécessitent une fenêtre d'options DragonUI plus récente "
        "(AddSlider/AddDropdown).",
    "Social": "Social",
    "Social (Friends/Who/Guild/Chat/Raid)": "Social (Amis/Qui/Guilde/Discussion/Raid)",
    "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.":
        "Utiliser la fenêtre de DragonUI à la place de celle de Blizzard. Les changements prennent effet "
        "après un /reload.",
    "Use UI scale": "Utiliser l'échelle de l'interface",
    "Window Scaling": "Mise à l'échelle des fenêtres",
    "Windows": "Fenêtres",

    # ── Shared UI ───────────────────────────────────────────────────────────────────────────────
    "Select All": "Tout sélectionner",

    # ── Inspect ──────────────────────────────────────────────────────────────────
    #
    # Honor / Arena / Rating / Kills are FALLBACKS: modules/inspect/PvPPane.lua prefers the
    # client's own HONOR / ARENA / RATING / HONORABLE_KILLS globals and only reaches for these
    # if one of them is missing.
    "Arena": "Arène",
    "Honor": "Honneur",
    "Inspect window": "Fenêtre d'inspection",
    "Kills": "Victimes",
    "Modern frame, portrait and tabs on the inspect window, with its Character tab laid out like the character window. Reload (/reload) to apply.":
        "Cadre, portrait et onglets modernes pour la fenêtre d'inspection, dont l'onglet Personnage reprend la mise en page de la fenêtre de personnage. Rechargez (/reload) pour appliquer.",
    "No team": "Aucune équipe",
    "Rating": "Cote",
    "Unranked": "Sans rang",
    "View this player's talents.": "Voir les talents de ce joueur.",
    "points spent": "points dépensés",
}
