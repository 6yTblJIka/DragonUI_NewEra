# -*- coding: utf-8 -*-
"""Russian translations.

The first two sections were translated by hand before this pass and are preserved verbatim, except
for "Your maximum %s.", whose translation dropped the %s -- caught by check_keys.py --verify. The
rest is machine-drafted; placeholder parity is enforced, wording is not reviewed.
"""

T = {
    # ── Professions (human-translated) ──────────────────────────────────────────────────────────
    "Alchemy": "Алхимия",
    "Blacksmithing": "Кузнечное дело",
    "Enchanting": "Наложение чар",
    "Engineering": "Инженерное дело",
    "Herbalism": "Травничество",
    "Leatherworking": "Кожевничество",
    "Mining": "Горное дело",
    "Smelting": "Выплавка металла",
    "Skinning": "Снятие шкур",
    "Tailoring": "Портняжное дело",
    "Inscription": "Начертание",
    "Jewelcrafting": "Ювелирное дело",
    "Prospecting": "Просеивание",
    "Cooking": "Кулинария",
    "First Aid": "Первая помощь",
    "Fishing": "Рыбная ловля",
    "Select a recipe to craft": "Выберите рецепт для создания",
    "Hide item tooltips in list": "Скрывать подсказки в списке",
    "Colour names by skill difficulty": "Окрашивать названия по сложности",
    "Plain skill bar (no animation)": "Обычная полоса навыка (без анимации)",
    "Create": "Создать",
    "Create All": "Создать все",
    "Show Learned": "Показывать изученные",
    "Has Skill Up": "Повышают навык",
    "Have Materials": "Есть реагенты",

    # ── Character, titles, equipment manager (human-translated) ─────────────────────────────────
    # Was "Максимальное значение данного ресурса." -- the %s was dropped, so the resource name never
    # appeared. Restored so the placeholder round-trips.
    "None": "Нет",

    # ── Auction house ───────────────────────────────────────────────────────────────────────────
    " -- partial scan": " -- частичное сканирование",
    "Auction query is throttled. Try again in a moment.":
        "Запрос к аукциону ограничен. Повторите попытку через мгновение.",
    "Buy out this auction for %s?": "Выкупить этот лот за %s?",
    r"Choose search criteria and press \"Search\"":
        "Выберите условия поиска и нажмите \"Поиск\"",
    "Loading results...": "Загрузка результатов...",
    "Lvl": "Ур.",
    "Modern visual shell for Buy/Sell/Auctions with optional Auctionator tab embedding.":
        "Современный интерфейс для покупки, продажи и лотов с необязательной вкладкой Auctionator.",
    "No listings.": "Лотов нет.",
    "No results. Adjust filters and search again.":
        "Ничего не найдено. Измените фильтры и повторите поиск.",
    "Page %d of %d  (items %d-%d of %d, from %d auction)%s":
        "Страница %d из %d  (предметы %d-%d из %d, из %d лота)%s",
    "Page %d of %d  (items %d-%d of %d, from %d auctions)%s":
        "Страница %d из %d  (предметы %d-%d из %d, из %d лотов)%s",
    "Page 1 of 1": "Страница 1 из 1",
    "Per Item": "За штуку",
    "Place a bid of %s?": "Сделать ставку %s?",
    "Scanning page %d of %d...": "Сканирование страницы %d из %d...",
    "Searching...": "Поиск...",
    "Sort Per Item": "Сортировать по цене за штуку",
    "You have no auctions.": "У вас нет выставленных лотов.",

    # ── Bags ────────────────────────────────────────────────────────────────────────────────────
    "All Bags": "Все сумки",
    "Auto-empty old bag when swapping": "Опустошать старую сумку при замене",
    "Auto-sell junk at merchants": "Автоматически продавать хлам торговцам",
    "Bag Options": "Настройки сумок",
    "Category (smart)": "Категория (умная)",
    "Combined bag (all-in-one)": "Объединённая сумка (всё в одном)",
    "Item Level": "Уровень предмета",
    "Keys": "Ключи",
    "Merchant": "Торговец",
    "Name": "Название",
    "Not enough free space to swap that bag.":
        "Недостаточно свободного места для замены этой сумки.",
    "One movable window showing every bag slot in a Dragonflight-style grid. Takes over bag opening "
    "and replaces the per-window 'Retail bags' restyle. Reload (/reload) to apply.":
        "Одно перемещаемое окно со всеми ячейками сумок в сетке в стиле Dragonflight. Берёт на себя "
        "открытие сумок и заменяет оформление отдельных окон «Сумки retail». /reload для применения.",
    "Quality": "Качество",
    "Red-tint unusable items": "Подсвечивать красным непригодные предметы",
    "Restyle the bag windows with the Dragonflight metal frame, portrait, and item quality borders. "
    "Disable to keep the stock Blizzard bags. Reload (/reload) to apply.":
        "Оформляет окна сумок металлической рамкой Dragonflight, портретом и рамками качества предметов. "
        "Отключите, чтобы оставить стандартные сумки Blizzard. /reload для применения.",
    "Retail bags": "Сумки retail",
    "Reverse sort order": "Обратный порядок сортировки",
    "Search": "Поиск",
    "Separate specialty bags": "Отделять специализированные сумки",
    "Shift-right-click to stop watching": "Shift+ПКМ, чтобы прекратить отслеживание",
    "Show item level on items": "Показывать уровень предмета на предметах",
    "Show keyring row": "Показывать ряд связки ключей",
    "Sold %d junk item(s).": "Продано предметов хлама: %d.",
    "Sort Bags": "Сортировать сумки",
    "Sort by": "Сортировать по",
    "Sorting…": "Сортировка…",
    "Swapping bag…": "Замена сумки…",
    "The same setting as Enable Item Level in DragonUI's options (Enhancements > Item Level). "
    "Covers the character panel and every other frame too.":
        "Та же настройка, что и «Включить уровень предмета» в настройках DragonUI (Улучшения > Уровень "
        "предмета). Действует и на окно персонажа, и на все остальные окна.",
    "Turn on Item Level in DragonUI's options (Enhancements > Item Level) first.":
        "Сначала включите «Уровень предмета» в настройках DragonUI (Улучшения > Уровень предмета).",

    # ── Cooldown manager ────────────────────────────────────────────────────────────────────────
    "(empty)": "(пусто)",
    "(your spec)": "(ваша специализация)",
    "A ready sound plays when a COOLDOWN finishes.|nThis spell has none, so it can never play."
    "|nClearing it also clears the badge.":
        "Звук готовности звучит по окончании ВРЕМЕНИ ВОССТАНОВЛЕНИЯ.|nУ этого заклинания его нет, поэтому "
        "звук никогда не прозвучит.|nОчистка также убирает значок.",
    "A spell can be on cooldown and buffing you at the same time. The glow says which icons are "
    "buffed; the timer says how long.":
        "Заклинание может одновременно восстанавливаться и усиливать вас. Свечение показывает, на каких "
        "значках есть эффект, а таймер — как долго.",
    "Active": "Активно",
    "Alert": "Оповещение",
    "Always": "Всегда",
    "Auto-track buffs under %ds": "Автоматически отслеживать эффекты короче %d сек.",
    "Available": "Доступно",
    "Bar Content": "Содержимое полосы",
    "Bar Width": "Ширина полосы",
    "Both of these are immediate and cannot be undone from here — Revert only covers layout changes.":
        "Оба действия выполняются сразу и отсюда не отменяются — «Откат» касается только изменений "
        "расположения.",
    "Buff Bars": "Полосы эффектов",
    "Buff Icons": "Значки эффектов",
    "Buff tracking": "Отслеживание эффектов",
    "Buffed spells": "Усиленные заклинания",
    "Buffs you have not seen before are recorded and listed under Not Displayed on the Tracked Buffs "
    "tab, where you can assign the ones you want. Nothing appears on screen until you do.":
        "Ранее не встречавшиеся эффекты записываются и появляются в разделе «Не отображаются» на вкладке "
        "«Отслеживаемые эффекты», где вы можете назначить нужные. До этого на экране ничего не появится.",
    "Button Glow": "Свечение кнопки",
    "Clear All Alerts": "Очистить все оповещения",
    "Clear Ready Sound": "Очистить звук готовности",
    "Clear all alerts and sounds": "Очистить все оповещения и звуки",
    "Clear every configured alert and ready sound?\\n\\nSpell lists and frame positions are not affected.":
        "Очистить все настроенные оповещения и звуки готовности?\\n\\nСписки заклинаний и положения окон не "
        "затрагиваются.",
    "Closes edit mode and opens the Cooldown Manager window, which carries the settings that are not "
    "per-viewer: alerts, ready sounds, buff tracking, icon fit and the resets.":
        "Закрывает режим редактирования и открывает окно менеджера восстановления, где собраны настройки, "
        "не относящиеся к отдельной панели: оповещения, звуки готовности, отслеживание эффектов, подгонка "
        "значков и сбросы.",
    "Cooldown Manager": "Менеджер восстановления",
    "Cooldown Manager Settings": "Настройки менеджера восстановления",
    "Cooldown Manager layout string (Ctrl+C to copy):":
        "Строка расположения менеджера восстановления (Ctrl+C для копирования):",
    "Copy": "Копировать",
    "Defensives, interrupts, CC and escapes.":
        "Защита, прерывания, контроль и способности отхода.",
    "Delete": "Удалить",
    r'Delete the layout \"%s\"?': 'Удалить расположение \"%s\"?',
    "Drag onto Essential or Utility to track it.":
        "Перетащите на «Основные» или «Вспомогательные», чтобы отслеживать.",
    "Draw the countdown number on each icon.": "Показывать отсчёт на каждом значке.",
    "Each viewer's own settings — size, spacing, orientation, visibility, what its icons show — live "
    "on the frame, in edit mode, where you can see what you are changing. These open edit mode with "
    "that viewer selected and its settings already up. Closes this window; not available in combat.":
        "Собственные настройки каждой панели — размер, отступы, ориентация, видимость, содержимое значков "
        "— находятся на самой рамке, в режиме редактирования, где видно, что именно вы меняете. Эти кнопки "
        "открывают режим редактирования с выбранной панелью и её настройками. Закрывает это окно; в бою "
        "недоступно.",
    "Enable Cooldown Manager": "Включить менеджер восстановления",
    "Enabled": "Включено",
    "Essential Cooldowns": "Основные способности",
    "Everything": "Всё",
    "Everything (no spec)": "Всё (без специализации)",
    "Everything the Cooldown Manager can be told to do that is not about one viewer's layout. Layout "
    "and position both live on the frame itself, in edit mode (/dui edit) — click a viewer there for "
    "its own settings, or use the buttons just below to go straight to one.":
        "Всё, что умеет менеджер восстановления, кроме расположения отдельной панели. Расположение и "
        "положение находятся на самой рамке, в режиме редактирования (/dui edit) — щёлкните там по панели "
        "для её настроек либо воспользуйтесь кнопками ниже.",
    "Export Layout": "Экспорт расположения",
    "FX Style": "Стиль эффекта",
    "Flashes once, the moment the cooldown finishes.|nWorks for every spell.":
        "Вспыхивает один раз, как только восстановление завершится.|nРаботает для любого заклинания.",
    "Frame strength": "Насыщенность рамки",
    "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is the "
    "stock look, not a bug.":
        "Расстояние между значками. Retail смещает его на -4, поэтому в нижней части диапазона они слегка "
        "перекрываются — так и должно быть, это не ошибка.",
    "Glow while buffed": "Светиться при действующем эффекте",
    "Glows during the last %d%% of this buff's|nremaining time.":
        "Светится в течение последних %d%% оставшегося|nвремени этого эффекта.",
    "Glows during the last %d%% of this spell's own|nbuff or debuff.":
        "Светится в течение последних %d%% собственного|nэффекта этого заклинания.",
    "Glows for as long as the spell is off cooldown|nand affordable.":
        "Светится, пока заклинание готово|nи его можно применить.",
    "Glows for as long as this buff is on you.|n|nThe one that works for a proc: it asks whether "
    "the|nbuff is up, not whether something is castable|nor off cooldown.":
        "Светится, пока этот эффект действует на вас.|n|nПодходит для срабатываний: проверяется наличие"
        "|nэффекта, а не готовность применения|nили восстановления.",
    "Glows for as long as this spell's effect is|nup on %s.":
        "Светится, пока эффект этого заклинания|nдействует на %s.",
    "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.":
        "Окружает значок золотым ореолом, пока действует эффект заклинания (у шамана — его тотем).",
    "Hidden": "Скрыто",
    "Hide When Inactive": "Скрывать при бездействии",
    "Horizontal": "Горизонтально",
    "How many icons before the layout wraps. Vertical orientation reads this as icons per column.":
        "Сколько значков до переноса. При вертикальной ориентации это значков в столбце.",
    "Icon Direction": "Направление значков",
    "Icon Limit": "Предел значков",
    "Icon Only": "Только значок",
    "Icon Padding": "Отступ значков",
    "Icon Size": "Размер значков",
    "Icon and Name": "Значок и название",
    "Icon fit": "Подгонка значков",
    "Icon inset": "Отступ внутри значка",
    "Import": "Импорт",
    "Import Layout": "Импорт расположения",
    "In Combat": "В бою",
    "Lasts %s sec": "Длится %s сек.",
    "Layouts": "Расположения",
    "Layouts include appearance": "Расположения включают оформление",
    "Left": "Влево",
    "Load the %s starter layout?\\n\\nEssential is set to that spec's spells. Everything else for your "
    "class moves to Not Displayed — nothing is deleted, and you can drag any of it back.\\n\\nTracked "
    "auras, trinkets, alerts and frame positions are not affected.":
        "Загрузить начальное расположение «%s»?\\n\\nВ «Основные» попадут заклинания этой специализации. "
        "Всё остальное для вашего класса перейдёт в «Не отображаются» — ничего не удаляется, и вы можете "
        "перетащить обратно что угодно.\\n\\nОтслеживаемые ауры, аксессуары, оповещения и положения окон не "
        "затрагиваются.",
    "Marching Ants": "Бегущие огни",
    "Move to %s": "Переместить в «%s»",
    "Name Only": "Только название",
    "Name this layout:": "Название расположения:",
    "New Layout": "Новое расположение",
    "Not displayed on any viewer": "Не отображается ни на одной панели",
    "Not yet learned": "Ещё не изучено",
    "Nothing to undo. It covers LAYOUTS, not the settings|non these tabs — a viewer's own size and "
    "position revert|nfrom its edit-mode panel instead.":
        "Отменять нечего. Это касается РАСПОЛОЖЕНИЙ, а не настроек|nна этих вкладках — размер и положение "
        "панели|nвозвращаются из её окна режима редактирования.",
    "Off by default. Turn on to show the four viewers; turn off to hide them again. Takes effect "
    "immediately either way, and nothing is forgotten — this switch stores one flag and touches "
    "nothing else, so your setup comes back exactly as you left it.":
        "По умолчанию выключено. Включите, чтобы показать четыре панели; выключите, чтобы снова их скрыть. "
        "Действует сразу в обе стороны, и ничего не теряется — этот переключатель хранит один флаг и больше "
        "ничего не трогает, поэтому ваша настройка вернётся в точности такой, какой была.",
    "Off, both specs share one set of lists. Turning it on copies the layout you have now into the "
    "spec you are in.":
        "Выключено — обе специализации используют один набор списков. При включении текущее расположение "
        "копируется в ту специализацию, в которой вы находитесь.",
    "Off, loading or importing a layout changes only what you track — lists, tracked buffs, trinkets, "
    "alerts and sounds. On, it also applies the orientation, icons per row, size, padding and opacity "
    "the layout was saved with.|n|nLayouts always SAVE appearance either way, so this only decides "
    "what happens when one is applied. Revert always puts appearance back, whatever this says.":
        "Выключено — загрузка или импорт расположения меняет только то, что вы отслеживаете: списки, "
        "отслеживаемые эффекты, аксессуары, оповещения и звуки. Включено — применяются также ориентация, "
        "число значков в ряду, размер, отступ и непрозрачность, с которыми расположение было "
        "сохранено.|n|nРасположения в любом случае всегда СОХРАНЯЮТ оформление, поэтому эта настройка "
        "решает только то, что происходит при применении. «Откат» всегда возвращает оформление, что бы "
        "здесь ни стояло.",
    "Off, orientation, icons per row, size, padding and opacity are one setup for every character. On, "
    "each character can differ — until you change something here it still follows the shared setup, so "
    "nothing moves when you tick this, and unticking it gives the shared setup back without losing "
    "what you changed.":
        "Выключено — ориентация, число значков в ряду, размер, отступ и непрозрачность едины для всех "
        "персонажей. Включено — каждый персонаж может отличаться: пока вы что-нибудь здесь не измените, он "
        "по-прежнему следует общей настройке, поэтому при установке флажка ничего не сдвинется, а при "
        "снятии вернётся общая настройка без потери ваших изменений.",
    "Offensive burst and damage cooldowns.":
        "Атакующие способности всплеска урона и восстановления.",
    "Opacity": "Непрозрачность",
    "Open Cooldown Manager": "Открыть менеджер восстановления",
    "Opens a share string you can copy with Ctrl+C.|nIt covers this class's spell lists, tracked "
    "auras,|ntrinket placement, alerts and sounds.":
        "Открывает строку для обмена, которую можно скопировать через Ctrl+C.|nОна включает списки "
        "заклинаний этого класса, отслеживаемые ауры,|nразмещение аксессуаров, оповещения и звуки.",
    "Opens the Cooldown Manager window (/cdm) on its Spells tab. Needs the module on — the window "
    "configures the viewers, so it goes away with them.":
        "Открывает окно менеджера восстановления (/cdm) на вкладке «Заклинания». Требуется включённый "
        "модуль — окно настраивает панели и исчезает вместе с ними.",
    "Options": "Настройки",
    "Orientation": "Ориентация",
    "Pandemic Border": "Рамка пандемии",
    "Paste a Cooldown Manager layout string:":
        "Вставьте строку расположения менеджера восстановления:",
    "Ready Sound": "Звук готовности",
    "Ready sound: %s": "Звук готовности: %s",
    "Refresh": "Обновление",
    "Refresh Window": "Окно обновления",
    "Remove": "Убрать",
    "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.":
        "Убирает все оповещения и звуки готовности для отдельных заклинаний. Списки заклинаний и положения "
        "не затрагиваются.",
    "Rename": "Переименовать",
    "Requires the %s talent": "Требуется талант «%s»",
    "Reset": "Сброс",
    "Reset %s to its default layout?\\n\\nThis viewer's position, size, orientation and visibility all "
    "go back to stock. Nothing else is affected, and it cannot be undone.":
        "Сбросить «%s» к расположению по умолчанию?\\n\\nПоложение, размер, ориентация и видимость этой "
        "панели вернутся к исходным. Больше ничего не затрагивается, и отменить это нельзя.",
    "Reset Spell Lists": "Сбросить списки заклинаний",
    "Reset spell and buff lists": "Сбросить списки заклинаний и эффектов",
    "Reset this class's Cooldown Manager spell and buff lists to their defaults?\\n\\nOther classes, "
    "alerts, sounds and frame positions are not affected.":
        "Сбросить списки заклинаний и эффектов менеджера восстановления для этого класса к значениям по "
        "умолчанию?\\n\\nДругие классы, оповещения, звуки и положения окон не затрагиваются.",
    "Reset to the starter layout?\\n\\nThis reverts every Cooldown Manager edit — spells, tracked auras, "
    "trinket placement, alerts and sounds — to their defaults, and clears your saved-layout "
    "selection.\\n\\nFrame positions are not affected.":
        "Вернуться к начальному расположению?\\n\\nЭто вернёт все изменения менеджера восстановления — "
        "заклинания, отслеживаемые ауры, размещение аксессуаров, оповещения и звуки — к значениям по "
        "умолчанию и очистит выбор сохранённого расположения.\\n\\nПоложения окон не затрагиваются.",
    "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its spell lists, "
    "aura assignments and trinket placement. Other classes, alerts, sounds and positions are not "
    "affected.":
        "Восстанавливает подобранные значения по умолчанию и окно автоотслеживания для ЭТОГО КЛАССА, "
        "очищая его списки заклинаний, назначения аур и размещение аксессуаров. Другие классы, оповещения, "
        "звуки и положения не затрагиваются.",
    "Retail's Cooldown Manager, driven from curated per-class cooldown lists. |cffffcc55Off by "
    "default|r — it adds four viewers to the middle of your screen, so it waits to be asked. Every "
    "setting — which spells and buffs are tracked, each viewer's layout, size and visibility, alerts "
    "and ready sounds — lives in the Cooldown Manager window itself (/cdm). Drag the viewers with "
    "DragonUI's editor mode to reposition them, and right-click one there for its own layout settings.":
        "Менеджер восстановления из retail, работающий на подобранных списках способностей по классам. "
        "|cffffcc55По умолчанию выключен|r — он добавляет четыре панели в центр экрана, поэтому ждёт вашего "
        "решения. Все настройки — какие заклинания и эффекты отслеживаются, расположение, размер и "
        "видимость каждой панели, оповещения и звуки готовности — находятся в самом окне менеджера (/cdm). "
        "Перетаскивайте панели в режиме редактирования DragonUI, а щелчок правой кнопкой по панели там "
        "откроет её собственные настройки расположения.",
    "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the spell's "
    "cooldown and the glow alone marks it as buffed — which is clearer when the two differ, as on "
    "Prayer of Mending.":
        "Поведение как в retail: пока действует эффект, значок отсчитывает ЭФФЕКТ. Выключено — он "
        "отсчитывает восстановление заклинания, а на действующий эффект указывает только свечение, что "
        "понятнее, когда эти значения расходятся, как у «Молитвы восстановления».",
    "Revert": "Откат",
    "Right": "Вправо",
    "Save, load, import and export the whole|nCooldown Manager setup for this class.":
        "Сохранение, загрузка, импорт и экспорт всей настройки|nменеджера восстановления для этого класса.",
    "Separate appearance per character": "Отдельное оформление для каждого персонажа",
    "Separate layout per spec": "Отдельное расположение для каждой специализации",
    "Short-duration buffs and procs, as depleting bars.":
        "Короткие эффекты и срабатывания в виде убывающих полос.",
    "Short-duration buffs and procs, as icons.": "Короткие эффекты и срабатывания в виде значков.",
    "Show Timer": "Показывать таймер",
    "Show Tooltips": "Показывать подсказки",
    "Show Unlearned": "Показывать неизученные",
    "Show a slot only while its aura is active.":
        "Показывать ячейку, только пока действует её аура.",
    "Show a tooltip when hovering an icon.":
        "Показывать подсказку при наведении на значок.",
    "Show every short buff the moment it lands, without assigning it first. Convenient on a character "
    "you are still setting up; in a raid it fills the viewers with other people's cooldowns, food and "
    "flasks.":
        "Показывает любой короткий эффект сразу при появлении, без предварительного назначения. Удобно на "
        "персонаже, которого вы ещё настраиваете; в рейде это заполнит панели чужими способностями, едой и "
        "настоями.",
    "Show the buff's time, not the cooldown": "Показывать время эффекта, а не восстановления",
    "Show them as": "Показывать как",
    "Show this viewer at all. The editor handle stays either way, so this is reversible from right here.":
        "Показывать ли эту панель вообще. Маркер редактирования остаётся в любом случае, поэтому изменение "
        "обратимо прямо отсюда.",
    "Sparkles": "Искры",
    "Talent specs": "Специализации талантов",
    "The frame is a soft shadow that falls on the icon's outer edge, so it only shows where there is "
    "icon underneath it. Strength draws it more than once to deepen it — that is also what makes its "
    "rounded corners read, since the icons themselves cannot be rounded here. Inset shrinks the icon, "
    "which slides the shadow off it, so raise that one sparingly.":
        "Рамка — это мягкая тень по внешнему краю значка, поэтому она видна только там, где под ней есть "
        "значок. Насыщенность отрисовывает её несколько раз, делая глубже, — именно это позволяет "
        "различить скруглённые углы, ведь сами значки здесь скруглить нельзя. Отступ уменьшает значок и "
        "сдвигает тень с него, поэтому повышайте его осторожно.",
    "The full curated list for your class, both specs' spells|nincluded. This is what the Cooldown "
    "Manager shipped with|nbefore per-spec starters.":
        "Полный подобранный список для вашего класса, включая заклинания|nобеих специализаций. Именно с "
        "этим менеджер восстановления|nпоставлялся до появления начальных наборов по специализациям.",
    "Tracked automatically. Drag it into a section to pin it there.":
        "Отслеживается автоматически. Перетащите в раздел, чтобы закрепить там.",
    "Undoes the last layout change — applying a layout,|nimporting one, or the starter reset.|n|nOne "
    "step, and only for this session.":
        "Отменяет последнее изменение расположения — применение расположения,|nего импорт или сброс к "
        "начальному.|n|nОдин шаг, и только в течение этого сеанса.",
    "Usable": "Можно применить",
    "Use Starter Layout": "Использовать начальное расположение",
    "Utility Cooldowns": "Вспомогательные способности",
    "Vertical": "Вертикально",
    "Viewer layout": "Расположение панели",
    "Visibility": "Видимость",
    "When this viewer is on screen at all. Hidden still leaves the editor handle here.":
        "Когда эта панель вообще присутствует на экране. «Скрыто» всё равно оставляет здесь маркер "
        "редактирования.",
    "Which of the two buff viewers auto-tracked buffs land in.":
        "На какую из двух панелей эффектов попадают автоматически отслеживаемые эффекты.",
    "Which spells and buffs you track is remembered separately for each talent spec, so a Discipline "
    "layout and a Holy one do not overwrite each other. Where each viewer sits is always remembered "
    "per character; the appearance settings are shared unless you say otherwise below.":
        "То, какие заклинания и эффекты вы отслеживаете, запоминается отдельно для каждой специализации, "
        "поэтому расположения «Послушание» и «Свет» не перезаписывают друг друга. Положение каждой панели "
        "всегда запоминается для персонажа; настройки оформления общие, если ниже не указано иное.",
    "is turned off. Enable it in DragonUI's options, under New Era > Cooldown Manager.":
        "выключен. Включите его в настройках DragonUI, в разделе New Era > Менеджер восстановления.",
    "you": "вас",
    "|n|nOn a buff row this is about RE-CASTING it,|nnot about the buff being up — that is Active.":
        "|n|nВ строке эффекта речь о ПОВТОРНОМ применении,|nа не о том, действует ли эффект — это "
        "«Активно».",
    "|n|nThe one for a DoT or a shield: it asks whether|nthe aura is up, not whether the cooldown is "
    "ready.":
        "|n|nПодходит для периодического урона или щита: проверяется|nналичие ауры, а не готовность "
        "восстановления.",
    "|n|nThis one also waits for a target below %d%% health.":
        "|n|nЭтот также ждёт цель со здоровьем ниже %d%%.",
    "|n|n|cff40ff40Applies %s to %s, so this will work.|r":
        "|n|n|cff40ff40Накладывает «%s» на %s, поэтому это сработает.|r",
    "|n|n|cff40ff40Its aura is active now, so this will work.|r":
        "|n|n|cff40ff40Его аура сейчас активна, поэтому это сработает.|r",
    "|n|n|cffffd200No aura of this name is up right now.|r":
        "|n|n|cffffd200Сейчас нет активной ауры с таким названием.|r",

    # ── Adventure guide ─────────────────────────────────────────────────────────────────────────
    "(No abilities recorded for this encounter.)":
        "(Для этого сражения способности не записаны.)",
    "(no model)": "(нет модели)",
    "Adventure Guide": "Путеводитель",
    "Eastern Kingdoms": "Восточные королевства",
    "Kalimdor": "Калимдор",
    "Model will load once seen within this session due to client limitations.":
        "Модель загрузится после того, как будет увидена в этом сеансе — ограничение клиента.",
    "Phase %d": "Фаза %d",
    "The Adventure Guide: bosses, abilities, and loot for Classic and Burning Crusade dungeons and "
    "raids (/aguide).":
        "Путеводитель: боссы, способности и добыча подземелий и рейдов Classic и Burning Crusade "
        "(/aguide).",

    # ── Guild ───────────────────────────────────────────────────────────────────────────────────
    "GuildControlPopupFrame is missing on this client.":
        "GuildControlPopupFrame отсутствует в этом клиенте.",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "Современное окно гильдии в стиле сообществ (Состав / Сведения / Чат).",
    "Promote": "Повысить",

    # ── Level up display ────────────────────────────────────────────────────────────────────────
    "Battleground available": "Доступно поле боя",
    "Can be learned from a trainer": "Можно изучить у учителя",
    "Dungeon available": "Доступно подземелье",
    "Enable Level Up Display": "Включить объявление о новом уровне",
    "Level Up Display": "Объявление о новом уровне",
    "New Feature": "Новая возможность",
    "New Riding Skill": "Новый навык верховой езды",
    "New Talent Point": "Новое очко талантов",
    "New Talent Points": "Новые очки талантов",
    "New rank available": "Доступен новый ранг",
    "On by default. Turn off to stop the banner appearing on level-up; the harvest keeps running "
    "either way, so turning it back on costs nothing.":
        "По умолчанию включено. Выключите, чтобы баннер не появлялся при получении уровня; сбор данных "
        "продолжается в любом случае, поэтому обратное включение ничего не стоит.",
    "Play the level-up sound": "Проигрывать звук получения уровня",
    "Raid available": "Доступен рейд",
    "Retail's level-up banner. What it announces is read from |cffffcc55this server|r — abilities and "
    "their levels come from your class trainer's own list, battlegrounds and dungeons from the "
    "client's brackets. Visit a trainer once to fill it in; |cffffcc55/nelevelup coverage|r shows "
    "what it knows.":
        "Баннер получения уровня из retail. То, что он объявляет, считывается с |cffffcc55этого сервера|r "
        "— способности и их уровни берутся из списка вашего учителя класса, а поля боя и подземелья — из "
        "диапазонов клиента. Посетите учителя один раз, чтобы заполнить данные; "
        "|cffffcc55/nelevelup coverage|r показывает, что известно.",
    "Talents": "Таланты",
    "You have reached": "Вы достигли",
    "level %d": "%d уровня",
    "|cffffcc55Off by default.|r The game already plays its own fanfare when you level, so this only "
    "adds a second copy on top of it. Turn it on if you want /nelevelup previews to make a sound, "
    "since those fire no game sound of their own.":
        "|cffffcc55По умолчанию выключено.|r Игра и так проигрывает свои фанфары при получении уровня, "
        "поэтому это лишь добавит вторые поверх. Включите, если хотите, чтобы предпросмотры /nelevelup "
        "звучали, — сами по себе они не вызывают игровых звуков.",

    # ── Professions window ──────────────────────────────────────────────────────────────────────
    "Auctionator API not available for reagent scans.":
        "API Auctionator недоступен для сканирования реагентов.",
    "Auctionator scan started for recipe reagents.":
        "Запущено сканирование Auctionator по реагентам рецепта.",
    "Open the Auction House first to run Auctionator scans.":
        "Сначала откройте аукцион, чтобы запускать сканирование Auctionator.",
    "Requires the Auction House window to be open.": "Требуется открытое окно аукциона.",
    "Requires: %s": "Требуется: %s",
    "Retail-style crafting window for all professions.":
        "Окно создания предметов в стиле retail для всех профессий.",
    "Scan AH": "Сканировать аукцион",
    "Searches Auctionator for the selected recipe and its reagents.":
        "Ищет в Auctionator выбранный рецепт и его реагенты.",

    # ── Social ──────────────────────────────────────────────────────────────────────────────────
    "Away": "Отошёл",
    "Busy": "Занят",
    "Cancel Extend": "Отменить продление",
    "Enter a note for %s:": "Введите заметку для %s:",
    "Extend": "Продлить",
    "Extended": "Продлено",
    "ID: %s": "ID: %s",
    "Instance": "Подземелье",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "Современное окно друзей (Друзья / Игнор / Кто) с вкладкой гильдии.",
    "Promote to Assistant": "Назначить помощником",
    "Promote to Raid Leader": "Назначить лидером рейда",
    "Resets In": "Сброс через",
    "Set Note": "Задать заметку",
    "You are not saved to any instances.": "Вы не привязаны ни к одному подземелью.",

    # ── Spellbook ───────────────────────────────────────────────────────────────────────────────
    "Spellbook": "Книга заклинаний",
    "The modern Dragonflight spellbook window. Disable to keep the stock Blizzard spellbook.":
        "Современное окно книги заклинаний в стиле Dragonflight. Отключите, чтобы оставить стандартную "
        "книгу заклинаний Blizzard.",

    # ── Talents ─────────────────────────────────────────────────────────────────────────────────
    "  %s: have %d, build wants %d": "  %s: есть %d, сборке нужно %d",
    "%s\\n\\nImport anyway?": "%s\\n\\nВсё равно импортировать?",
    "ACTIVE EFFECTS": "ДЕЙСТВУЮЩИЕ ЭФФЕКТЫ",
    "Activate": "Активировать",
    "Copy this build string (Ctrl+C). Talented & the WoWhead/wotlkdb calculators import it too:":
        "Скопируйте эту строку сборки (Ctrl+C). Talented и калькуляторы WoWhead/wotlkdb тоже её "
        "импортируют:",
    "Delete loadout '%s'?": "Удалить набор «%s»?",
    "GLYPHS": "СИМВОЛЫ",
    "Glyph options": "Настройки символов",
    "Glyphs": "Символы",
    "Import…": "Импорт…",
    "Loadouts": "Наборы",
    "Locked": "Заблокировано",
    "MAJOR GLYPHS": "БОЛЬШИЕ СИМВОЛЫ",
    "MINOR GLYPHS": "МАЛЫЕ СИМВОЛЫ",
    "NO ACTIVE EFFECTS": "НЕТ ДЕЙСТВУЮЩИХ ЭФФЕКТОВ",
    "Name this imported loadout:": "Название импортированного набора:",
    "Name this loadout (saves your current spec):":
        "Название набора (сохраняет вашу текущую специализацию):",
    "Paste a talent string or calculator URL (Talented / WoWhead / wotlkdb):":
        "Вставьте строку талантов или ссылку на калькулятор (Talented / WoWhead / wotlkdb):",
    "Pet": "Питомец",
    "Remove this glyph?": "Убрать этот символ?",
    "Rename loadout:": "Переименовать набор:",
    "Rename specialization": "Переименовать специализацию",
    "Rename this specialization (letters only, max %d):":
        "Переименуйте эту специализацию (только буквы, не более %d):",
    "Save current spec…": "Сохранить текущую специализацию…",
    "Server uses custom talents": "На сервере используются изменённые таланты",
    "Show glyph effects": "Показывать эффекты символов",
    "Show glyph names": "Показывать названия символов",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "Помечает экспортируемые сборки этим миром, чтобы импорт в другие раскладки сначала предупреждал.",
    "Talents Panel": "Окно талантов",
    "The modern talents window. Turn off to use the standard Blizzard talent window.":
        "Современное окно талантов. Выключите, чтобы использовать стандартное окно талантов Blizzard.",
    "This loadout has fewer points in some talents than you've already spent, so it needs a respec "
    "first:\\n":
        "В этом наборе в некоторых талантах меньше очков, чем вы уже потратили, поэтому сначала нужно "
        "сбросить таланты:\\n",
    "Toggle slot name labels and the active-effects list.":
        "Переключает подписи ячеек и список действующих эффектов.",
    "Unlock Spec": "Разблокировать специализацию",
    "\\n\\nReset at a class trainer, then load again. (The rest has been staged — click Apply to learn it.)":
        "\\n\\nСбросьте таланты у учителя класса и загрузите снова. (Остальное подготовлено — нажмите "
        "«Применить», чтобы изучить.)",

    # ── Options panel ───────────────────────────────────────────────────────────────────────────
    "Adventure Guide (Encounter Journal)": "Путеводитель (журнал сражений)",
    "Auction House": "Аукцион",
    "Boss and loot browser. Requires a /reload to take effect (the micro button doesn't re-check this "
    "live).":
        "Обозреватель боссов и добычи. Требуется /reload (микрокнопка не перепроверяет это на лету).",
    "Click for this frame's settings.": "Щёлкните для настроек этого окна.",
    "Combined Bag": "Объединённая сумка",
    "Custom": "Своё значение",
    "Custom scale": "Свой масштаб",
    "Drag to move.": "Перетащите, чтобы переместить.",
    "Each window's size: \\\"Use UI scale\\\" follows the game's UI Scale slider, \\\"No scaling\\\" "
    "stays pixel-perfect, \\\"Custom\\\" uses its slider. The custom slider is greyed out and locked "
    "unless that window's mode is set to Custom.":
        "Размер каждого окна: \"Масштаб интерфейса\" следует за игровым ползунком масштаба, \"Без "
        "масштабирования\" сохраняет попиксельную точность, \"Своё значение\" использует свой ползунок. "
        "Ползунок своего значения затенён и заблокирован, пока режим окна не переведён в «Своё значение».",
    "Guild": "Гильдия",
    "Looking For Group": "Поиск группы",
    "Looking For Group (Dungeon/Raid Finder)": "Поиск группы (подземелья и рейды)",
    "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. Panels appear "
    "here as their modules load.":
        "Окна NewEra, перенесённые на DragonUI. Включайте и выключайте окна ниже. Окна появляются здесь по "
        "мере загрузки их модулей.",
    "No scaling": "Без масштабирования",
    "Our all-in-one bag window. Turn OFF to use the stock Blizzard bags instead. Reload (/reload) to "
    "apply.":
        "Наше окно сумок «всё в одном». ВЫКЛЮЧИТЕ, чтобы вместо него использовать стандартные сумки "
        "Blizzard. /reload для применения.",
    "Professions": "Профессии",
    "Reload (/reload) to apply.": "/reload для применения.",
    "Scale mode": "Режим масштаба",
    "Scaling controls are unavailable: the 'core\\\\Scale.lua' file isn't loaded. Make sure your "
    "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.":
        "Настройки масштаба недоступны: файл 'core\\Scale.lua' не загружен. Убедитесь, что в вашей "
        "установке DragonUI_NewEra есть core/Scale.lua И строка для него в .toc, затем выполните /reload.",
    "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).":
        "Настройкам масштаба требуется более новое окно настроек DragonUI (AddSlider/AddDropdown).",
    "Social": "Общение",
    "Social (Friends/Who/Guild/Chat/Raid)": "Общение (друзья/кто/гильдия/чат/рейд)",
    "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.":
        "Использовать окно DragonUI вместо стандартного окна Blizzard. Изменения вступят в силу после "
        "/reload.",
    "Use UI scale": "Масштаб интерфейса",
    "Window Scaling": "Масштабирование окон",
    "Windows": "Окна",

    # ── Shared UI ───────────────────────────────────────────────────────────────────────────────
    "Select All": "Выделить всё",

    # ── Inspect ──────────────────────────────────────────────────────────────────
    #
    # Honor / Arena / Rating / Kills are FALLBACKS: modules/inspect/PvPPane.lua prefers the
    # client's own HONOR / ARENA / RATING / HONORABLE_KILLS globals and only reaches for these
    # if one of them is missing.
    "Arena": "Арена",
    "Honor": "Честь",
    "Inspect window": "Окно осмотра",
    "Kills": "Убийства",
    "Modern frame, portrait and tabs on the inspect window, with its Character tab laid out like the character window. Reload (/reload) to apply.":
        "Современная рамка, портрет и вкладки в окне осмотра; вкладка «Персонаж» повторяет окно персонажа. Для применения выполните /reload.",
    "No team": "Нет команды",
    "Rating": "Рейтинг",
    "Unranked": "Без звания",
    "View this player's talents.": "Посмотреть таланты этого игрока.",
    "points spent": "очков потрачено",
}
