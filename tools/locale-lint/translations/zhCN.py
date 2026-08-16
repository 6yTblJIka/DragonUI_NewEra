# -*- coding: utf-8 -*-
"""Simplified Chinese translations. Keys are the enUS.lua source text verbatim.

Machine-drafted. Placeholder parity is enforced by check_keys.py --verify; wording is not reviewed.
"""

T = {
    # ── Professions ─────────────────────────────────────────────────────────────────────────────
    "Alchemy": "炼金术",
    "Blacksmithing": "锻造",
    "Enchanting": "附魔",
    "Engineering": "工程学",
    "Herbalism": "草药学",
    "Leatherworking": "制皮",
    "Mining": "采矿",
    "Smelting": "熔炼",
    "Skinning": "剥皮",
    "Tailoring": "裁缝",
    "Inscription": "铭文",
    "Jewelcrafting": "珠宝加工",
    "Prospecting": "勘探",
    "Cooking": "烹饪",
    "First Aid": "急救",
    "Fishing": "钓鱼",
    "Select a recipe to craft": "选择一个配方进行制作",
    "Hide item tooltips in list": "在列表中隐藏物品提示",
    "Colour names by skill difficulty": "按技能难度为名称着色",
    "Plain skill bar (no animation)": "简洁技能条（无动画）",
    "Create": "制造",
    "Create All": "全部制造",
    "Show Learned": "显示已学会",
    "Has Skill Up": "可提升技能",
    "Have Materials": "拥有材料",

    # ── Character, titles, equipment manager ────────────────────────────────────────────────────
    "None": "无",

    # ── Auction house ───────────────────────────────────────────────────────────────────────────
    " -- partial scan": " -- 部分扫描",
    "Auction query is throttled. Try again in a moment.": "拍卖行查询受到限制。请稍后再试。",
    "Buy out this auction for %s?": "以%s一口价买下这件拍卖品？",
    r"Choose search criteria and press \"Search\"": "选择搜索条件并点击\"搜索\"",
    "Loading results...": "正在载入结果……",
    "Lvl": "等级",
    "Modern visual shell for Buy/Sell/Auctions with optional Auctionator tab embedding.":
        "用于“购买/出售/拍卖”的现代界面，可选内嵌 Auctionator 标签页。",
    "No listings.": "没有拍卖品。",
    "No results. Adjust filters and search again.": "没有结果。请调整筛选条件后重新搜索。",
    "Page %d of %d  (items %d-%d of %d, from %d auction)%s":
        "第%d页，共%d页（物品%d-%d，共%d件，来自%d个拍卖）%s",
    "Page %d of %d  (items %d-%d of %d, from %d auctions)%s":
        "第%d页，共%d页（物品%d-%d，共%d件，来自%d个拍卖）%s",
    "Page 1 of 1": "第1页，共1页",
    "Per Item": "单价",
    "Place a bid of %s?": "出价%s？",
    "Scanning page %d of %d...": "正在扫描第%d页，共%d页……",
    "Searching...": "正在搜索……",
    "Sort Per Item": "按单价排序",
    "You have no auctions.": "你没有拍卖品。",

    # ── Bags ────────────────────────────────────────────────────────────────────────────────────
    "All Bags": "所有背包",
    "Auto-empty old bag when swapping": "更换背包时自动清空旧背包",
    "Auto-sell junk at merchants": "在商人处自动出售垃圾物品",
    "Bag Options": "背包选项",
    "Category (smart)": "分类（智能）",
    "Combined bag (all-in-one)": "合并背包（一体式）",
    "Item Level": "物品等级",
    "Keys": "钥匙",
    "Merchant": "商人",
    "Name": "名称",
    "Not enough free space to swap that bag.": "空间不足，无法更换该背包。",
    "One movable window showing every bag slot in a Dragonflight-style grid. Takes over bag opening "
    "and replaces the per-window 'Retail bags' restyle. Reload (/reload) to apply.":
        "一个可移动窗口，以巨龙时代风格的网格显示所有背包格。它接管背包的开启，并取代逐窗口的“正式服背包”"
        "重绘。需 /reload 生效。",
    "Quality": "品质",
    "Red-tint unusable items": "将无法使用的物品染成红色",
    "Restyle the bag windows with the Dragonflight metal frame, portrait, and item quality borders. "
    "Disable to keep the stock Blizzard bags. Reload (/reload) to apply.":
        "用巨龙时代的金属边框、头像和物品品质边框重绘背包窗口。关闭则保留暴雪原版背包。需 /reload 生效。",
    "Retail bags": "正式服背包",
    "Reverse sort order": "反转排序顺序",
    "Search": "搜索",
    "Separate specialty bags": "单独显示专用背包",
    "Shift-right-click to stop watching": "Shift+右键点击可停止关注",
    "Show item level on items": "在物品上显示物品等级",
    "Show keyring row": "显示钥匙链一行",
    "Sold %d junk item(s).": "已出售%d件垃圾物品。",
    "Sort Bags": "整理背包",
    "Sort by": "排序方式",
    "Sorting…": "正在整理……",
    "Swapping bag…": "正在更换背包……",
    "The same setting as Enable Item Level in DragonUI's options (Enhancements > Item Level). "
    "Covers the character panel and every other frame too.":
        "与 DragonUI 选项中“启用物品等级”（增强 > 物品等级）为同一项设置。同样作用于角色面板和其他所有窗口。",
    "Turn on Item Level in DragonUI's options (Enhancements > Item Level) first.":
        "请先在 DragonUI 选项中开启“物品等级”（增强 > 物品等级）。",

    # ── Cooldown manager ────────────────────────────────────────────────────────────────────────
    "(empty)": "（空）",
    "(your spec)": "（你的专精）",
    "A ready sound plays when a COOLDOWN finishes.|nThis spell has none, so it can never play."
    "|nClearing it also clears the badge.":
        "就绪音效在“冷却”结束时播放。|n此法术没有冷却，因此音效永远不会响起。|n清除它同时也会清除标记。",
    "A spell can be on cooldown and buffing you at the same time. The glow says which icons are "
    "buffed; the timer says how long.":
        "一个法术可以同时处于冷却中并为你提供增益。光效显示哪些图标带有增益，计时器显示还剩多久。",
    "Active": "生效中",
    "Alert": "提示",
    "Always": "始终",
    "Auto-track buffs under %ds": "自动追踪短于%d秒的增益",
    "Available": "可用",
    "Bar Content": "条形内容",
    "Bar Width": "条形宽度",
    "Both of these are immediate and cannot be undone from here — Revert only covers layout changes.":
        "这两项都会立即生效且无法在此撤销——“还原”只涵盖布局改动。",
    "Buff Bars": "增益条",
    "Buff Icons": "增益图标",
    "Buff tracking": "增益追踪",
    "Buffed spells": "带增益的法术",
    "Buffs you have not seen before are recorded and listed under Not Displayed on the Tracked Buffs "
    "tab, where you can assign the ones you want. Nothing appears on screen until you do.":
        "你此前未见过的增益会被记录，并列在“追踪的增益”标签页的“未显示”中，你可以在那里指派需要的增益。"
        "在此之前屏幕上不会出现任何内容。",
    "Button Glow": "按钮光效",
    "Clear All Alerts": "清除所有提示",
    "Clear Ready Sound": "清除就绪音效",
    "Clear all alerts and sounds": "清除所有提示和音效",
    "Clear every configured alert and ready sound?\\n\\nSpell lists and frame positions are not affected.":
        "清除所有已配置的提示和就绪音效？\\n\\n法术列表和窗口位置不受影响。",
    "Closes edit mode and opens the Cooldown Manager window, which carries the settings that are not "
    "per-viewer: alerts, ready sounds, buff tracking, icon fit and the resets.":
        "关闭编辑模式并打开冷却管理器窗口，其中包含不属于单个显示器的设置：提示、就绪音效、增益追踪、"
        "图标适配以及各项重置。",
    "Cooldown Manager": "冷却管理器",
    "Cooldown Manager Settings": "冷却管理器设置",
    "Cooldown Manager layout string (Ctrl+C to copy):": "冷却管理器布局代码（按 Ctrl+C 复制）：",
    "Copy": "复制",
    "Defensives, interrupts, CC and escapes.": "防御、打断、控制和脱身技能。",
    "Delete": "删除",
    r'Delete the layout \"%s\"?': '删除布局\"%s\"？',
    "Drag onto Essential or Utility to track it.": "拖到“核心”或“辅助”上即可追踪。",
    "Draw the countdown number on each icon.": "在每个图标上显示倒计时数字。",
    "Each viewer's own settings — size, spacing, orientation, visibility, what its icons show — live "
    "on the frame, in edit mode, where you can see what you are changing. These open edit mode with "
    "that viewer selected and its settings already up. Closes this window; not available in combat.":
        "每个显示器自身的设置——大小、间距、方向、可见性、图标显示内容——都在窗体上，位于编辑模式中，"
        "你可以直观地看到自己在改什么。这些按钮会打开编辑模式并选中该显示器，同时展开它的设置。"
        "会关闭本窗口；战斗中不可用。",
    "Enable Cooldown Manager": "启用冷却管理器",
    "Enabled": "已启用",
    "Essential Cooldowns": "核心冷却",
    "Everything": "全部",
    "Everything (no spec)": "全部（不分专精）",
    "Everything the Cooldown Manager can be told to do that is not about one viewer's layout. Layout "
    "and position both live on the frame itself, in edit mode (/dui edit) — click a viewer there for "
    "its own settings, or use the buttons just below to go straight to one.":
        "冷却管理器所有与单个显示器布局无关的功能。布局和位置都在窗体本身，位于编辑模式（/dui edit）中——"
        "在那里点击某个显示器可查看它自己的设置，或使用下方的按钮直接前往。",
    "Export Layout": "导出布局",
    "FX Style": "特效样式",
    "Flashes once, the moment the cooldown finishes.|nWorks for every spell.":
        "冷却结束的瞬间闪烁一次。|n适用于所有法术。",
    "Frame strength": "边框强度",
    "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is the "
    "stock look, not a bug.":
        "图标之间的间距。正式服会将该值偏移 -4，因此在低值时会略微重叠——这是原版效果，并非错误。",
    "Glow while buffed": "有增益时发光",
    "Glows during the last %d%% of this buff's|nremaining time.": "在该增益剩余时间的|n最后%d%%内发光。",
    "Glows during the last %d%% of this spell's own|nbuff or debuff.":
        "在该法术自身增益或减益剩余时间的|n最后%d%%内发光。",
    "Glows for as long as the spell is off cooldown|nand affordable.":
        "只要该法术已冷却完毕|n且资源足够，就持续发光。",
    "Glows for as long as this buff is on you.|n|nThe one that works for a proc: it asks whether "
    "the|nbuff is up, not whether something is castable|nor off cooldown.":
        "只要该增益在你身上，就持续发光。|n|n适用于触发效果：它判断的是|n增益是否存在，而不是某个技能"
        "是否可施放|n或是否已冷却完毕。",
    "Glows for as long as this spell's effect is|nup on %s.": "只要该法术的效果在%s身上，|n就持续发光。",
    "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.":
        "当该法术的增益（萨满则为其图腾）存在时，为图标加上金色光环。",
    "Hidden": "隐藏",
    "Hide When Inactive": "未生效时隐藏",
    "Horizontal": "水平",
    "How many icons before the layout wraps. Vertical orientation reads this as icons per column.":
        "布局换行前的图标数量。在竖直方向下，此值表示每列的图标数。",
    "Icon Direction": "图标方向",
    "Icon Limit": "图标上限",
    "Icon Only": "仅图标",
    "Icon Padding": "图标间距",
    "Icon Size": "图标大小",
    "Icon and Name": "图标和名称",
    "Icon fit": "图标适配",
    "Icon inset": "图标内缩",
    "Import": "导入",
    "Import Layout": "导入布局",
    "In Combat": "战斗中",
    "Lasts %s sec": "持续%s秒",
    "Layouts": "布局",
    "Layouts include appearance": "布局包含外观设置",
    "Left": "向左",
    "Load the %s starter layout?\\n\\nEssential is set to that spec's spells. Everything else for your "
    "class moves to Not Displayed — nothing is deleted, and you can drag any of it back.\\n\\nTracked "
    "auras, trinkets, alerts and frame positions are not affected.":
        "载入%s的初始布局？\\n\\n“核心”将被设为该专精的法术。你职业的其余内容将移至“未显示”——不会删除"
        "任何东西，你可以随时把它们拖回来。\\n\\n追踪的光环、饰品、提示和窗口位置不受影响。",
    "Marching Ants": "流动虚线",
    "Move to %s": "移动到%s",
    "Name Only": "仅名称",
    "Name this layout:": "为该布局命名：",
    "New Layout": "新建布局",
    "Not displayed on any viewer": "未在任何显示器上显示",
    "Not yet learned": "尚未学会",
    "Nothing to undo. It covers LAYOUTS, not the settings|non these tabs — a viewer's own size and "
    "position revert|nfrom its edit-mode panel instead.":
        "没有可撤销的内容。它涵盖的是“布局”，而非这些标签页|n中的设置——显示器自身的大小和位置需从它的"
        "|n编辑模式面板还原。",
    "Off by default. Turn on to show the four viewers; turn off to hide them again. Takes effect "
    "immediately either way, and nothing is forgotten — this switch stores one flag and touches "
    "nothing else, so your setup comes back exactly as you left it.":
        "默认关闭。开启可显示四个显示器，关闭则再次隐藏它们。两个方向都会立即生效，且不会遗忘任何内容"
        "——这个开关只保存一个标记，不改动其他任何东西，因此你的配置会原样恢复。",
    "Off, both specs share one set of lists. Turning it on copies the layout you have now into the "
    "spec you are in.":
        "关闭时，两个专精共用同一套列表。开启后会把你当前的布局复制到你所在的专精中。",
    "Off, loading or importing a layout changes only what you track — lists, tracked buffs, trinkets, "
    "alerts and sounds. On, it also applies the orientation, icons per row, size, padding and opacity "
    "the layout was saved with.|n|nLayouts always SAVE appearance either way, so this only decides "
    "what happens when one is applied. Revert always puts appearance back, whatever this says.":
        "关闭时，载入或导入布局只会改变你追踪的内容——列表、追踪的增益、饰品、提示和音效。开启后，还会"
        "应用该布局保存时的方向、每行图标数、大小、间距和不透明度。|n|n无论如何，布局始终会“保存”外观，"
        "因此此项只决定应用布局时的行为。无论此项如何设置，“还原”始终会恢复外观。",
    "Off, orientation, icons per row, size, padding and opacity are one setup for every character. On, "
    "each character can differ — until you change something here it still follows the shared setup, so "
    "nothing moves when you tick this, and unticking it gives the shared setup back without losing "
    "what you changed.":
        "关闭时，方向、每行图标数、大小、间距和不透明度对所有角色共用一套配置。开启后，每个角色都可以不同"
        "——在你于此处做出改动之前，它仍沿用共享配置，因此勾选时不会有任何位移；取消勾选则会恢复共享配置，"
        "同时不会丢失你改动过的内容。",
    "Offensive burst and damage cooldowns.": "进攻性爆发和伤害类冷却技能。",
    "Opacity": "不透明度",
    "Open Cooldown Manager": "打开冷却管理器",
    "Opens a share string you can copy with Ctrl+C.|nIt covers this class's spell lists, tracked "
    "auras,|ntrinket placement, alerts and sounds.":
        "打开一段可用 Ctrl+C 复制的分享代码。|n其中包含该职业的法术列表、追踪的光环、|n饰品位置、提示和音效。",
    "Opens the Cooldown Manager window (/cdm) on its Spells tab. Needs the module on — the window "
    "configures the viewers, so it goes away with them.":
        "在“法术”标签页打开冷却管理器窗口（/cdm）。需要启用该模块——此窗口用于配置显示器，因此会随它们一同消失。",
    "Options": "选项",
    "Orientation": "方向",
    "Pandemic Border": "重施边框",
    "Paste a Cooldown Manager layout string:": "粘贴一段冷却管理器布局代码：",
    "Ready Sound": "就绪音效",
    "Ready sound: %s": "就绪音效：%s",
    "Refresh": "刷新",
    "Refresh Window": "刷新窗口期",
    "Remove": "移除",
    "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.":
        "移除所有针对单个法术的提示和就绪音效。法术列表和位置不受影响。",
    "Rename": "重命名",
    "Requires the %s talent": "需要天赋“%s”",
    "Reset": "重置",
    "Reset %s to its default layout?\\n\\nThis viewer's position, size, orientation and visibility all "
    "go back to stock. Nothing else is affected, and it cannot be undone.":
        "将%s重置为默认布局？\\n\\n该显示器的位置、大小、方向和可见性都会恢复原样。其他内容不受影响，"
        "且此操作无法撤销。",
    "Reset Spell Lists": "重置法术列表",
    "Reset spell and buff lists": "重置法术和增益列表",
    "Reset this class's Cooldown Manager spell and buff lists to their defaults?\\n\\nOther classes, "
    "alerts, sounds and frame positions are not affected.":
        "将该职业的冷却管理器法术和增益列表重置为默认值？\\n\\n其他职业、提示、音效和窗口位置不受影响。",
    "Reset to the starter layout?\\n\\nThis reverts every Cooldown Manager edit — spells, tracked auras, "
    "trinket placement, alerts and sounds — to their defaults, and clears your saved-layout "
    "selection.\\n\\nFrame positions are not affected.":
        "重置为初始布局？\\n\\n这会将冷却管理器的所有改动——法术、追踪的光环、饰品位置、提示和音效——"
        "恢复为默认值，并清除你已保存的布局选择。\\n\\n窗口位置不受影响。",
    "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its spell lists, "
    "aura assignments and trinket placement. Other classes, alerts, sounds and positions are not "
    "affected.":
        "恢复“当前职业”的精选默认值和自动追踪时限，并清除其法术列表、光环指派和饰品位置。"
        "其他职业、提示、音效和位置不受影响。",
    "Retail's Cooldown Manager, driven from curated per-class cooldown lists. |cffffcc55Off by "
    "default|r — it adds four viewers to the middle of your screen, so it waits to be asked. Every "
    "setting — which spells and buffs are tracked, each viewer's layout, size and visibility, alerts "
    "and ready sounds — lives in the Cooldown Manager window itself (/cdm). Drag the viewers with "
    "DragonUI's editor mode to reposition them, and right-click one there for its own layout settings.":
        "正式服的冷却管理器，由各职业精选的冷却列表驱动。|cffffcc55默认关闭|r——它会在你的屏幕中央添加四个"
        "显示器，因此需要你主动开启。所有设置——追踪哪些法术和增益、每个显示器的布局、大小和可见性、"
        "提示和就绪音效——都在冷却管理器窗口内（/cdm）。用 DragonUI 的编辑模式拖动显示器以调整位置，"
        "并在那里右键点击某个显示器以查看它自己的布局设置。",
    "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the spell's "
    "cooldown and the glow alone marks it as buffed — which is clearer when the two differ, as on "
    "Prayer of Mending.":
        "正式服的行为：有增益时，图标倒数的是“增益”。关闭后，它倒数的是法术冷却，仅用光效标示有增益——"
        "当两者不一致时（例如“愈合祷言”）这样更清楚。",
    "Revert": "还原",
    "Right": "向右",
    "Save, load, import and export the whole|nCooldown Manager setup for this class.":
        "保存、载入、导入和导出该职业|n整套冷却管理器配置。",
    "Separate appearance per character": "每个角色使用独立外观",
    "Separate layout per spec": "每个专精使用独立布局",
    "Short-duration buffs and procs, as depleting bars.": "短时增益和触发效果，以递减条形显示。",
    "Short-duration buffs and procs, as icons.": "短时增益和触发效果，以图标显示。",
    "Show Timer": "显示计时器",
    "Show Tooltips": "显示鼠标提示",
    "Show Unlearned": "显示未学会的",
    "Show a slot only while its aura is active.": "仅在光环生效时显示对应格位。",
    "Show a tooltip when hovering an icon.": "鼠标悬停在图标上时显示提示。",
    "Show every short buff the moment it lands, without assigning it first. Convenient on a character "
    "you are still setting up; in a raid it fills the viewers with other people's cooldowns, food and "
    "flasks.":
        "在每个短时增益生效的瞬间就显示它，无需事先指派。对仍在配置中的角色很方便；但在团队副本中，"
        "这会让显示器塞满他人的冷却技能、食物和合剂。",
    "Show the buff's time, not the cooldown": "显示增益时间，而非冷却时间",
    "Show them as": "显示为",
    "Show this viewer at all. The editor handle stays either way, so this is reversible from right here.":
        "是否显示该显示器。无论如何编辑手柄都会保留，因此可以直接在此撤销。",
    "Sparkles": "闪光",
    "Talent specs": "天赋专精",
    "The frame is a soft shadow that falls on the icon's outer edge, so it only shows where there is "
    "icon underneath it. Strength draws it more than once to deepen it — that is also what makes its "
    "rounded corners read, since the icons themselves cannot be rounded here. Inset shrinks the icon, "
    "which slides the shadow off it, so raise that one sparingly.":
        "边框是落在图标外缘的柔和阴影，因此只在其下方有图标的地方显示。强度会多次绘制它以加深效果——"
        "这也是它的圆角能被看出来的原因，因为此处图标本身无法做成圆角。内缩会缩小图标，从而使阴影滑出图标，"
        "所以请谨慎提高该值。",
    "The full curated list for your class, both specs' spells|nincluded. This is what the Cooldown "
    "Manager shipped with|nbefore per-spec starters.":
        "你职业的完整精选列表，包含两个专精的法术。|n这是冷却管理器在推出按专精初始布局之前|n所附带的内容。",
    "Tracked automatically. Drag it into a section to pin it there.":
        "已自动追踪。将它拖入某个分区即可固定在那里。",
    "Undoes the last layout change — applying a layout,|nimporting one, or the starter reset.|n|nOne "
    "step, and only for this session.":
        "撤销上一次布局改动——应用布局、|n导入布局或重置为初始布局。|n|n只能撤销一步，且仅在本次登录期间有效。",
    "Usable": "可施放",
    "Use Starter Layout": "使用初始布局",
    "Utility Cooldowns": "辅助冷却",
    "Vertical": "竖直",
    "Viewer layout": "显示器布局",
    "Visibility": "可见性",
    "When this viewer is on screen at all. Hidden still leaves the editor handle here.":
        "该显示器何时出现在屏幕上。选择“隐藏”仍会在此保留编辑手柄。",
    "Which of the two buff viewers auto-tracked buffs land in.":
        "自动追踪的增益会进入两个增益显示器中的哪一个。",
    "Which spells and buffs you track is remembered separately for each talent spec, so a Discipline "
    "layout and a Holy one do not overwrite each other. Where each viewer sits is always remembered "
    "per character; the appearance settings are shared unless you say otherwise below.":
        "你追踪的法术和增益会按天赋专精分别记录，因此戒律布局与神圣布局不会互相覆盖。每个显示器的位置"
        "始终按角色记录；除非你在下方另行设置，否则外观设置为共享。",
    "is turned off. Enable it in DragonUI's options, under New Era > Cooldown Manager.":
        "已关闭。请在 DragonUI 选项的 New Era > 冷却管理器中启用它。",
    "you": "你",
    "|n|nOn a buff row this is about RE-CASTING it,|nnot about the buff being up — that is Active.":
        "|n|n在增益行中，这指的是“重新施放”，|n而不是增益是否存在——那是“生效中”。",
    "|n|nThe one for a DoT or a shield: it asks whether|nthe aura is up, not whether the cooldown is "
    "ready.":
        "|n|n适用于持续伤害或护盾：它判断的是|n光环是否存在，而不是冷却是否就绪。",
    "|n|nThis one also waits for a target below %d%% health.": "|n|n此项还会等待生命值低于%d%%的目标。",
    "|n|n|cff40ff40Applies %s to %s, so this will work.|r": "|n|n|cff40ff40会对%s施加%s，因此这会生效。|r",
    "|n|n|cff40ff40Its aura is active now, so this will work.|r":
        "|n|n|cff40ff40它的光环当前处于生效状态，因此这会生效。|r",
    "|n|n|cffffd200No aura of this name is up right now.|r": "|n|n|cffffd200当前没有该名称的光环生效。|r",

    # ── Adventure guide ─────────────────────────────────────────────────────────────────────────
    "(No abilities recorded for this encounter.)": "（该首领战没有记录任何技能。）",
    "(no model)": "（无模型）",
    "Adventure Guide": "冒险指南",
    "Eastern Kingdoms": "东部王国",
    "Kalimdor": "卡利姆多",
    "Model will load once seen within this session due to client limitations.":
        "受客户端限制，模型需在本次登录中出现过一次后才会载入。",
    "Phase %d": "第%d阶段",
    "The Adventure Guide: bosses, abilities, and loot for Classic and Burning Crusade dungeons and "
    "raids (/aguide).":
        "冒险指南：经典旧世和燃烧的远征地下城与团队副本的首领、技能和战利品（/aguide）。",

    # ── Guild ───────────────────────────────────────────────────────────────────────────────────
    "GuildControlPopupFrame is missing on this client.": "此客户端缺少 GuildControlPopupFrame。",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "现代社区风格的公会窗口（成员 / 信息 / 聊天）。",
    "Promote": "提升",

    # ── Level up display ────────────────────────────────────────────────────────────────────────
    "Battleground available": "可进入新战场",
    "Can be learned from a trainer": "可向训练师学习",
    "Dungeon available": "可进入新地下城",
    "Enable Level Up Display": "启用升级提示",
    "Level Up Display": "升级提示",
    "New Feature": "新功能",
    "New Riding Skill": "新的骑术",
    "New Talent Point": "新的天赋点",
    "New Talent Points": "新的天赋点",
    "New rank available": "可获得新军衔",
    "On by default. Turn off to stop the banner appearing on level-up; the harvest keeps running "
    "either way, so turning it back on costs nothing.":
        "默认开启。关闭后升级时不再显示横幅；无论如何数据采集都会继续运行，因此重新开启不会有任何代价。",
    "Play the level-up sound": "播放升级音效",
    "Raid available": "可进入新团队副本",
    "Retail's level-up banner. What it announces is read from |cffffcc55this server|r — abilities and "
    "their levels come from your class trainer's own list, battlegrounds and dungeons from the "
    "client's brackets. Visit a trainer once to fill it in; |cffffcc55/nelevelup coverage|r shows "
    "what it knows.":
        "正式服的升级横幅。它所公布的内容读取自|cffffcc55当前服务器|r——技能及其等级来自你职业训练师"
        "自己的列表，战场和地下城则来自客户端的等级区间。去训练师处走一趟即可填充数据；"
        "|cffffcc55/nelevelup coverage|r 可查看它已知的内容。",
    "Talents": "天赋",
    "You have reached": "你已达到",
    "level %d": "%d级",
    "|cffffcc55Off by default.|r The game already plays its own fanfare when you level, so this only "
    "adds a second copy on top of it. Turn it on if you want /nelevelup previews to make a sound, "
    "since those fire no game sound of their own.":
        "|cffffcc55默认关闭。|r升级时游戏本身已会播放自己的号角声，因此此项只会在其上叠加第二次。"
        "如果你希望 /nelevelup 的预览带有音效，可以开启它，因为预览本身不会触发任何游戏音效。",

    # ── Professions window ──────────────────────────────────────────────────────────────────────
    "Auctionator API not available for reagent scans.": "Auctionator 接口不可用，无法扫描材料。",
    "Auctionator scan started for recipe reagents.": "已开始使用 Auctionator 扫描配方材料。",
    "Open the Auction House first to run Auctionator scans.":
        "请先打开拍卖行才能运行 Auctionator 扫描。",
    "Requires the Auction House window to be open.": "需要打开拍卖行窗口。",
    "Requires: %s": "需要：%s",
    "Retail-style crafting window for all professions.": "适用于所有专业的正式服风格制作窗口。",
    "Scan AH": "扫描拍卖行",
    "Searches Auctionator for the selected recipe and its reagents.":
        "在 Auctionator 中搜索所选配方及其材料。",

    # ── Social ──────────────────────────────────────────────────────────────────────────────────
    "Away": "暂离",
    "Busy": "忙碌",
    "Cancel Extend": "取消延期",
    "Enter a note for %s:": "为%s输入备注：",
    "Extend": "延期",
    "Extended": "已延期",
    "ID: %s": "ID：%s",
    "Instance": "副本",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "现代好友窗口（好友 / 屏蔽 / 谁），并带有公会标签页。",
    "Promote to Assistant": "提升为助手",
    "Promote to Raid Leader": "提升为团队领袖",
    "Resets In": "重置于",
    "Set Note": "设置备注",
    "You are not saved to any instances.": "你没有绑定任何副本。",

    # ── Spellbook ───────────────────────────────────────────────────────────────────────────────
    "Spellbook": "法术书",
    "The modern Dragonflight spellbook window. Disable to keep the stock Blizzard spellbook.":
        "现代巨龙时代风格的法术书窗口。关闭则保留暴雪原版法术书。",

    # ── Talents ─────────────────────────────────────────────────────────────────────────────────
    "  %s: have %d, build wants %d": "  %s：现有%d点，配置需要%d点",
    "%s\\n\\nImport anyway?": "%s\\n\\n仍要导入？",
    "ACTIVE EFFECTS": "生效中的效果",
    "Activate": "激活",
    "Copy this build string (Ctrl+C). Talented & the WoWhead/wotlkdb calculators import it too:":
        "复制这段配置代码（Ctrl+C）。Talented 以及 WoWhead/wotlkdb 计算器也可导入：",
    "Delete loadout '%s'?": "删除配置“%s”？",
    "GLYPHS": "雕文",
    "Glyph options": "雕文选项",
    "Glyphs": "雕文",
    "Import…": "导入…",
    "Loadouts": "配置",
    "Locked": "已锁定",
    "MAJOR GLYPHS": "主要雕文",
    "MINOR GLYPHS": "次要雕文",
    "NO ACTIVE EFFECTS": "没有生效中的效果",
    "Name this imported loadout:": "为导入的配置命名：",
    "Name this loadout (saves your current spec):": "为该配置命名（保存你当前的专精）：",
    "Paste a talent string or calculator URL (Talented / WoWhead / wotlkdb):":
        "粘贴天赋代码或计算器网址（Talented / WoWhead / wotlkdb）：",
    "Pet": "宠物",
    "Remove this glyph?": "移除该雕文？",
    "Rename loadout:": "重命名配置：",
    "Rename specialization": "重命名专精",
    "Rename this specialization (letters only, max %d):": "重命名该专精（仅限字母，最多%d个字符）：",
    "Save current spec…": "保存当前专精…",
    "Server uses custom talents": "服务器使用了自定义天赋",
    "Show glyph effects": "显示雕文效果",
    "Show glyph names": "显示雕文名称",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "为导出的配置标记此服务器，以便导入到其他布局时先行提示。",
    "Talents Panel": "天赋面板",
    "The modern talents window. Turn off to use the standard Blizzard talent window.":
        "现代天赋窗口。关闭则使用暴雪标准天赋窗口。",
    "This loadout has fewer points in some talents than you've already spent, so it needs a respec "
    "first:\\n":
        "该配置在某些天赋上的点数少于你已投入的点数，因此需要先洗点：\\n",
    "Toggle slot name labels and the active-effects list.": "切换格位名称标签和生效效果列表。",
    "Unlock Spec": "解锁专精",
    "\\n\\nReset at a class trainer, then load again. (The rest has been staged — click Apply to learn it.)":
        "\\n\\n请到职业训练师处洗点，然后重新载入。（其余部分已准备就绪——点击“应用”即可学习。）",

    # ── Options panel ───────────────────────────────────────────────────────────────────────────
    "Adventure Guide (Encounter Journal)": "冒险指南（首领战日志）",
    "Auction House": "拍卖行",
    "Boss and loot browser. Requires a /reload to take effect (the micro button doesn't re-check this "
    "live).":
        "首领与战利品浏览器。需 /reload 才能生效（微型按钮不会实时重新检查此项）。",
    "Click for this frame's settings.": "点击可查看该窗口的设置。",
    "Combined Bag": "合并背包",
    "Custom": "自定义",
    "Custom scale": "自定义缩放",
    "Drag to move.": "拖动以移动。",
    "Each window's size: \\\"Use UI scale\\\" follows the game's UI Scale slider, \\\"No scaling\\\" "
    "stays pixel-perfect, \\\"Custom\\\" uses its slider. The custom slider is greyed out and locked "
    "unless that window's mode is set to Custom.":
        "每个窗口的大小：\"使用界面缩放\"跟随游戏的界面缩放滑块，\"不缩放\"保持像素精确，"
        "\"自定义\"使用它自己的滑块。除非该窗口的模式设为“自定义”，否则自定义滑块会变灰并锁定。",
    "Guild": "公会",
    "Looking For Group": "寻找组队",
    "Looking For Group (Dungeon/Raid Finder)": "寻找组队（地下城/团队副本查找器）",
    "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. Panels appear "
    "here as their modules load.":
        "移植到 DragonUI 上的 NewEra 面板。在下方开启或关闭某个面板。面板会随其模块载入而出现在这里。",
    "No scaling": "不缩放",
    "Our all-in-one bag window. Turn OFF to use the stock Blizzard bags instead. Reload (/reload) to "
    "apply.":
        "我们的一体式背包窗口。关闭后将改用暴雪原版背包。需 /reload 生效。",
    "Professions": "专业",
    "Reload (/reload) to apply.": "需 /reload 生效。",
    "Scale mode": "缩放模式",
    "Scaling controls are unavailable: the 'core\\\\Scale.lua' file isn't loaded. Make sure your "
    "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.":
        "缩放选项不可用：文件 'core\\Scale.lua' 未载入。请确认你安装的 DragonUI_NewEra 同时包含 "
        "core/Scale.lua 以及它在 .toc 中的对应行，然后执行 /reload。",
    "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).":
        "缩放选项需要更新版本的 DragonUI 选项面板（AddSlider/AddDropdown）。",
    "Social": "社交",
    "Social (Friends/Who/Guild/Chat/Raid)": "社交（好友/谁/公会/聊天/团队）",
    "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.":
        "使用 DragonUI 的窗口替代暴雪默认窗口。改动将在 /reload 后生效。",
    "Use UI scale": "使用界面缩放",
    "Window Scaling": "窗口缩放",
    "Windows": "窗口",

    # ── Shared UI ───────────────────────────────────────────────────────────────────────────────
    "Select All": "全选",
}
