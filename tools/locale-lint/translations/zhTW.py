# -*- coding: utf-8 -*-
"""Traditional Chinese translations. Keys are the enUS.lua source text verbatim.

Not a script conversion of zhCN: the Taiwan client's glossary differs in more than characters
(拍賣場 vs 拍賣行, 雕紋 vs 雕文, 專精, 爆擊), so this is written out in full rather than inherited.

Machine-drafted. Placeholder parity is enforced by check_keys.py --verify; wording is not reviewed.
"""

T = {
    # ── Professions ─────────────────────────────────────────────────────────────────────────────
    "Alchemy": "鍊金術",
    "Blacksmithing": "鍛造",
    "Enchanting": "附魔",
    "Engineering": "工程學",
    "Herbalism": "草藥學",
    "Leatherworking": "製皮",
    "Mining": "採礦",
    "Smelting": "冶煉",
    "Skinning": "剝皮",
    "Tailoring": "裁縫",
    "Inscription": "銘文",
    "Jewelcrafting": "珠寶設計",
    "Prospecting": "探勘",
    "Cooking": "烹飪",
    "First Aid": "急救",
    "Fishing": "釣魚",
    "Select a recipe to craft": "選擇一個配方來製作",
    "Hide item tooltips in list": "在清單中隱藏物品提示",
    "Colour names by skill difficulty": "依技能難度為名稱上色",
    "Plain skill bar (no animation)": "簡潔技能條（無動畫）",
    "Create": "製造",
    "Create All": "全部製造",
    "Show Learned": "顯示已學會",
    "Has Skill Up": "可提升技能",
    "Have Materials": "擁有材料",

    # ── Character, titles, equipment manager ────────────────────────────────────────────────────
    "None": "無",

    # ── Auction house ───────────────────────────────────────────────────────────────────────────
    " -- partial scan": " -- 部分掃描",
    "Auction query is throttled. Try again in a moment.": "拍賣場查詢受到限制。請稍後再試。",
    "Buy out this auction for %s?": "以%s直接購買這件拍賣品？",
    r"Choose search criteria and press \"Search\"": "選擇搜尋條件並按下\"搜尋\"",
    "Loading results...": "正在載入結果……",
    "Lvl": "等級",
    "Modern visual shell for Buy/Sell/Auctions with optional Auctionator tab embedding.":
        "用於「購買/出售/拍賣」的現代介面，可選擇內嵌 Auctionator 頁籤。",
    "No listings.": "沒有拍賣品。",
    "No results. Adjust filters and search again.": "沒有結果。請調整篩選條件後重新搜尋。",
    "Page %d of %d  (items %d-%d of %d, from %d auction)%s":
        "第%d頁，共%d頁（物品%d-%d，共%d件，來自%d件拍賣）%s",
    "Page %d of %d  (items %d-%d of %d, from %d auctions)%s":
        "第%d頁，共%d頁（物品%d-%d，共%d件，來自%d件拍賣）%s",
    "Page 1 of 1": "第1頁，共1頁",
    "Per Item": "單價",
    "Place a bid of %s?": "出價%s？",
    "Scanning page %d of %d...": "正在掃描第%d頁，共%d頁……",
    "Searching...": "正在搜尋……",
    "Sort Per Item": "依單價排序",
    "You have no auctions.": "你沒有拍賣品。",

    # ── Bags ────────────────────────────────────────────────────────────────────────────────────
    "All Bags": "所有背包",
    "Auto-empty old bag when swapping": "更換背包時自動清空舊背包",
    "Auto-sell junk at merchants": "在商人處自動賣出垃圾物品",
    "Bag Options": "背包選項",
    "Category (smart)": "分類（智慧）",
    "Combined bag (all-in-one)": "合併背包（一體式）",
    "Item Level": "物品等級",
    "Keys": "鑰匙",
    "Merchant": "商人",
    "Name": "名稱",
    "Not enough free space to swap that bag.": "空間不足，無法更換該背包。",
    "One movable window showing every bag slot in a Dragonflight-style grid. Takes over bag opening "
    "and replaces the per-window 'Retail bags' restyle. Reload (/reload) to apply.":
        "一個可移動視窗，以巨龍崛起風格的格線顯示所有背包欄位。它會接管背包的開啟，並取代逐視窗的"
        "「正式服背包」重繪。需 /reload 生效。",
    "Quality": "品質",
    "Red-tint unusable items": "將無法使用的物品染成紅色",
    "Restyle the bag windows with the Dragonflight metal frame, portrait, and item quality borders. "
    "Disable to keep the stock Blizzard bags. Reload (/reload) to apply.":
        "以巨龍崛起的金屬外框、頭像和物品品質邊框重繪背包視窗。關閉則保留暴雪原版背包。需 /reload 生效。",
    "Retail bags": "正式服背包",
    "Reverse sort order": "反轉排序順序",
    "Search": "搜尋",
    "Separate specialty bags": "單獨顯示專用背包",
    "Shift-right-click to stop watching": "Shift+右鍵點擊可停止關注",
    "Show item level on items": "在物品上顯示物品等級",
    "Show keyring row": "顯示鑰匙圈那一列",
    "Sold %d junk item(s).": "已賣出%d件垃圾物品。",
    "Sort Bags": "整理背包",
    "Sort by": "排序方式",
    "Sorting…": "正在整理……",
    "Swapping bag…": "正在更換背包……",
    "The same setting as Enable Item Level in DragonUI's options (Enhancements > Item Level). "
    "Covers the character panel and every other frame too.":
        "與 DragonUI 選項中「啟用物品等級」（強化 > 物品等級）為同一項設定。同樣適用於角色面板和其他所有視窗。",
    "Turn on Item Level in DragonUI's options (Enhancements > Item Level) first.":
        "請先在 DragonUI 選項中開啟「物品等級」（強化 > 物品等級）。",

    # ── Cooldown manager ────────────────────────────────────────────────────────────────────────
    "(empty)": "（空）",
    "(your spec)": "（你的專精）",
    "A ready sound plays when a COOLDOWN finishes.|nThis spell has none, so it can never play."
    "|nClearing it also clears the badge.":
        "就緒音效會在「冷卻」結束時播放。|n此法術沒有冷卻，因此音效永遠不會響起。|n清除它同時也會清除標記。",
    "A spell can be on cooldown and buffing you at the same time. The glow says which icons are "
    "buffed; the timer says how long.":
        "一個法術可以同時處於冷卻中並為你提供增益。光效顯示哪些圖示帶有增益，計時器顯示還剩多久。",
    "Active": "生效中",
    "Alert": "提示",
    "Always": "永遠",
    "Auto-track buffs under %ds": "自動追蹤短於%d秒的增益",
    "Available": "可用",
    "Bar Content": "長條內容",
    "Bar Width": "長條寬度",
    "Both of these are immediate and cannot be undone from here — Revert only covers layout changes.":
        "這兩項都會立即生效且無法在此復原——「還原」只涵蓋版面變更。",
    "Buff Bars": "增益長條",
    "Buff Icons": "增益圖示",
    "Buff tracking": "增益追蹤",
    "Buffed spells": "帶增益的法術",
    "Buffs you have not seen before are recorded and listed under Not Displayed on the Tracked Buffs "
    "tab, where you can assign the ones you want. Nothing appears on screen until you do.":
        "你先前未見過的增益會被記錄，並列在「追蹤的增益」頁籤的「未顯示」中，你可以在那裡指派需要的增益。"
        "在此之前畫面上不會出現任何內容。",
    "Button Glow": "按鈕光效",
    "Clear All Alerts": "清除所有提示",
    "Clear Ready Sound": "清除就緒音效",
    "Clear all alerts and sounds": "清除所有提示和音效",
    "Clear every configured alert and ready sound?\\n\\nSpell lists and frame positions are not affected.":
        "清除所有已設定的提示和就緒音效？\\n\\n法術清單和視窗位置不受影響。",
    "Closes edit mode and opens the Cooldown Manager window, which carries the settings that are not "
    "per-viewer: alerts, ready sounds, buff tracking, icon fit and the resets.":
        "關閉編輯模式並開啟冷卻管理員視窗，其中包含不屬於單一顯示器的設定：提示、就緒音效、增益追蹤、"
        "圖示調整以及各項重設。",
    "Cooldown Manager": "冷卻管理員",
    "Cooldown Manager Settings": "冷卻管理員設定",
    "Cooldown Manager layout string (Ctrl+C to copy):": "冷卻管理員版面代碼（按 Ctrl+C 複製）：",
    "Copy": "複製",
    "Defensives, interrupts, CC and escapes.": "防禦、中斷、控場和脫身技能。",
    "Delete": "刪除",
    r'Delete the layout \"%s\"?': '刪除版面\"%s\"？',
    "Drag onto Essential or Utility to track it.": "拖曳到「核心」或「輔助」上即可追蹤。",
    "Draw the countdown number on each icon.": "在每個圖示上顯示倒數數字。",
    "Each viewer's own settings — size, spacing, orientation, visibility, what its icons show — live "
    "on the frame, in edit mode, where you can see what you are changing. These open edit mode with "
    "that viewer selected and its settings already up. Closes this window; not available in combat.":
        "每個顯示器自身的設定——大小、間距、方向、可見性、圖示顯示內容——都在框架上，位於編輯模式中，"
        "你可以直接看到自己在改什麼。這些按鈕會開啟編輯模式並選取該顯示器，同時展開它的設定。"
        "會關閉本視窗；戰鬥中無法使用。",
    "Enable Cooldown Manager": "啟用冷卻管理員",
    "Enabled": "已啟用",
    "Essential Cooldowns": "核心冷卻",
    "Everything": "全部",
    "Everything (no spec)": "全部（不分專精）",
    "Everything the Cooldown Manager can be told to do that is not about one viewer's layout. Layout "
    "and position both live on the frame itself, in edit mode (/dui edit) — click a viewer there for "
    "its own settings, or use the buttons just below to go straight to one.":
        "冷卻管理員所有與單一顯示器版面無關的功能。版面和位置都在框架本身，位於編輯模式（/dui edit）中——"
        "在那裡點擊某個顯示器可查看它自己的設定，或使用下方的按鈕直接前往。",
    "Export Layout": "匯出版面",
    "FX Style": "特效樣式",
    "Flashes once, the moment the cooldown finishes.|nWorks for every spell.":
        "冷卻結束的瞬間閃爍一次。|n適用於所有法術。",
    "Frame strength": "外框強度",
    "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is the "
    "stock look, not a bug.":
        "圖示之間的間距。正式服會將該值偏移 -4，因此在低值時會略微重疊——這是原版效果，並非錯誤。",
    "Glow while buffed": "有增益時發光",
    "Glows during the last %d%% of this buff's|nremaining time.": "在該增益剩餘時間的|n最後%d%%內發光。",
    "Glows during the last %d%% of this spell's own|nbuff or debuff.":
        "在該法術自身增益或減益剩餘時間的|n最後%d%%內發光。",
    "Glows for as long as the spell is off cooldown|nand affordable.":
        "只要該法術已冷卻完畢|n且資源足夠，就持續發光。",
    "Glows for as long as this buff is on you.|n|nThe one that works for a proc: it asks whether "
    "the|nbuff is up, not whether something is castable|nor off cooldown.":
        "只要該增益在你身上，就持續發光。|n|n適用於觸發效果：它判斷的是|n增益是否存在，而不是某個技能"
        "是否可施放|n或是否已冷卻完畢。",
    "Glows for as long as this spell's effect is|nup on %s.": "只要該法術的效果在%s身上，|n就持續發光。",
    "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.":
        "當該法術的增益（薩滿則為其圖騰）存在時，為圖示加上金色光環。",
    "Hidden": "隱藏",
    "Hide When Inactive": "未生效時隱藏",
    "Horizontal": "水平",
    "How many icons before the layout wraps. Vertical orientation reads this as icons per column.":
        "版面換行前的圖示數量。在垂直方向下，此值代表每欄的圖示數。",
    "Icon Direction": "圖示方向",
    "Icon Limit": "圖示上限",
    "Icon Only": "僅圖示",
    "Icon Padding": "圖示間距",
    "Icon Size": "圖示大小",
    "Icon and Name": "圖示和名稱",
    "Icon fit": "圖示調整",
    "Icon inset": "圖示內縮",
    "Import": "匯入",
    "Import Layout": "匯入版面",
    "In Combat": "戰鬥中",
    "Lasts %s sec": "持續%s秒",
    "Layouts": "版面",
    "Layouts include appearance": "版面包含外觀設定",
    "Left": "向左",
    "Load the %s starter layout?\\n\\nEssential is set to that spec's spells. Everything else for your "
    "class moves to Not Displayed — nothing is deleted, and you can drag any of it back.\\n\\nTracked "
    "auras, trinkets, alerts and frame positions are not affected.":
        "載入%s的初始版面？\\n\\n「核心」將設為該專精的法術。你職業的其餘內容會移至「未顯示」——不會刪除"
        "任何東西，你可以隨時把它們拖回來。\\n\\n追蹤的光環、飾品、提示和視窗位置不受影響。",
    "Marching Ants": "流動虛線",
    "Move to %s": "移動到%s",
    "Name Only": "僅名稱",
    "Name this layout:": "為此版面命名：",
    "New Layout": "新增版面",
    "Not displayed on any viewer": "未在任何顯示器上顯示",
    "Not yet learned": "尚未學會",
    "Nothing to undo. It covers LAYOUTS, not the settings|non these tabs — a viewer's own size and "
    "position revert|nfrom its edit-mode panel instead.":
        "沒有可復原的內容。它涵蓋的是「版面」，而非這些頁籤|n中的設定——顯示器自身的大小和位置需從它的"
        "|n編輯模式面板還原。",
    "Off by default. Turn on to show the four viewers; turn off to hide them again. Takes effect "
    "immediately either way, and nothing is forgotten — this switch stores one flag and touches "
    "nothing else, so your setup comes back exactly as you left it.":
        "預設關閉。開啟可顯示四個顯示器，關閉則再次隱藏它們。兩個方向都會立即生效，且不會遺失任何內容"
        "——這個開關只儲存一個標記，不更動其他任何東西，因此你的設定會原樣恢復。",
    "Off, both specs share one set of lists. Turning it on copies the layout you have now into the "
    "spec you are in.":
        "關閉時，兩個專精共用同一組清單。開啟後會把你目前的版面複製到你所在的專精中。",
    "Off, loading or importing a layout changes only what you track — lists, tracked buffs, trinkets, "
    "alerts and sounds. On, it also applies the orientation, icons per row, size, padding and opacity "
    "the layout was saved with.|n|nLayouts always SAVE appearance either way, so this only decides "
    "what happens when one is applied. Revert always puts appearance back, whatever this says.":
        "關閉時，載入或匯入版面只會改變你追蹤的內容——清單、追蹤的增益、飾品、提示和音效。開啟後，還會"
        "套用該版面儲存時的方向、每列圖示數、大小、間距和不透明度。|n|n無論如何，版面一律會「儲存」外觀，"
        "因此此項只決定套用版面時的行為。無論此項如何設定，「還原」一律會恢復外觀。",
    "Off, orientation, icons per row, size, padding and opacity are one setup for every character. On, "
    "each character can differ — until you change something here it still follows the shared setup, so "
    "nothing moves when you tick this, and unticking it gives the shared setup back without losing "
    "what you changed.":
        "關閉時，方向、每列圖示數、大小、間距和不透明度對所有角色共用一組設定。開啟後，每個角色都可以不同"
        "——在你於此處做出變更之前，它仍沿用共用設定，因此勾選時不會有任何位移；取消勾選則會恢復共用設定，"
        "同時不會遺失你變更過的內容。",
    "Offensive burst and damage cooldowns.": "進攻性爆發和傷害類冷卻技能。",
    "Opacity": "不透明度",
    "Open Cooldown Manager": "開啟冷卻管理員",
    "Opens a share string you can copy with Ctrl+C.|nIt covers this class's spell lists, tracked "
    "auras,|ntrinket placement, alerts and sounds.":
        "開啟一段可用 Ctrl+C 複製的分享代碼。|n其中包含該職業的法術清單、追蹤的光環、|n飾品位置、提示和音效。",
    "Opens the Cooldown Manager window (/cdm) on its Spells tab. Needs the module on — the window "
    "configures the viewers, so it goes away with them.":
        "在「法術」頁籤開啟冷卻管理員視窗（/cdm）。需要啟用該模組——此視窗用於設定顯示器，因此會隨它們一同消失。",
    "Options": "選項",
    "Orientation": "方向",
    "Pandemic Border": "重施外框",
    "Paste a Cooldown Manager layout string:": "貼上一段冷卻管理員版面代碼：",
    "Ready Sound": "就緒音效",
    "Ready sound: %s": "就緒音效：%s",
    "Refresh": "更新",
    "Refresh Window": "更新時限",
    "Remove": "移除",
    "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.":
        "移除所有針對單一法術的提示和就緒音效。法術清單和位置不受影響。",
    "Rename": "重新命名",
    "Requires the %s talent": "需要天賦「%s」",
    "Reset": "重設",
    "Reset %s to its default layout?\\n\\nThis viewer's position, size, orientation and visibility all "
    "go back to stock. Nothing else is affected, and it cannot be undone.":
        "將%s重設為預設版面？\\n\\n該顯示器的位置、大小、方向和可見性都會恢復原樣。其他內容不受影響，"
        "且此操作無法復原。",
    "Reset Spell Lists": "重設法術清單",
    "Reset spell and buff lists": "重設法術和增益清單",
    "Reset this class's Cooldown Manager spell and buff lists to their defaults?\\n\\nOther classes, "
    "alerts, sounds and frame positions are not affected.":
        "將該職業的冷卻管理員法術和增益清單重設為預設值？\\n\\n其他職業、提示、音效和視窗位置不受影響。",
    "Reset to the starter layout?\\n\\nThis reverts every Cooldown Manager edit — spells, tracked auras, "
    "trinket placement, alerts and sounds — to their defaults, and clears your saved-layout "
    "selection.\\n\\nFrame positions are not affected.":
        "重設為初始版面？\\n\\n這會將冷卻管理員的所有變更——法術、追蹤的光環、飾品位置、提示和音效——"
        "恢復為預設值，並清除你已儲存的版面選擇。\\n\\n視窗位置不受影響。",
    "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its spell lists, "
    "aura assignments and trinket placement. Other classes, alerts, sounds and positions are not "
    "affected.":
        "恢復「目前職業」的精選預設值和自動追蹤時限，並清除其法術清單、光環指派和飾品位置。"
        "其他職業、提示、音效和位置不受影響。",
    "Retail's Cooldown Manager, driven from curated per-class cooldown lists. |cffffcc55Off by "
    "default|r — it adds four viewers to the middle of your screen, so it waits to be asked. Every "
    "setting — which spells and buffs are tracked, each viewer's layout, size and visibility, alerts "
    "and ready sounds — lives in the Cooldown Manager window itself (/cdm). Drag the viewers with "
    "DragonUI's editor mode to reposition them, and right-click one there for its own layout settings.":
        "正式服的冷卻管理員，由各職業精選的冷卻清單驅動。|cffffcc55預設關閉|r——它會在你的畫面中央加入四個"
        "顯示器，因此需要你主動開啟。所有設定——追蹤哪些法術和增益、每個顯示器的版面、大小和可見性、"
        "提示和就緒音效——都在冷卻管理員視窗內（/cdm）。用 DragonUI 的編輯模式拖曳顯示器以調整位置，"
        "並在那裡按右鍵點擊某個顯示器以查看它自己的版面設定。",
    "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the spell's "
    "cooldown and the glow alone marks it as buffed — which is clearer when the two differ, as on "
    "Prayer of Mending.":
        "正式服的行為：有增益時，圖示倒數的是「增益」。關閉後，它倒數的是法術冷卻，僅以光效標示有增益——"
        "當兩者不一致時（例如「癒合禱言」）這樣更清楚。",
    "Revert": "還原",
    "Right": "向右",
    "Save, load, import and export the whole|nCooldown Manager setup for this class.":
        "儲存、載入、匯入和匯出該職業|n整套冷卻管理員設定。",
    "Separate appearance per character": "每個角色使用獨立外觀",
    "Separate layout per spec": "每個專精使用獨立版面",
    "Short-duration buffs and procs, as depleting bars.": "短時增益和觸發效果，以遞減長條顯示。",
    "Short-duration buffs and procs, as icons.": "短時增益和觸發效果，以圖示顯示。",
    "Show Timer": "顯示計時器",
    "Show Tooltips": "顯示滑鼠提示",
    "Show Unlearned": "顯示未學會的",
    "Show a slot only while its aura is active.": "僅在光環生效時顯示對應欄位。",
    "Show a tooltip when hovering an icon.": "滑鼠移到圖示上時顯示提示。",
    "Show every short buff the moment it lands, without assigning it first. Convenient on a character "
    "you are still setting up; in a raid it fills the viewers with other people's cooldowns, food and "
    "flasks.":
        "在每個短時增益生效的瞬間就顯示它，無需事先指派。對仍在設定中的角色很方便；但在團隊副本中，"
        "這會讓顯示器塞滿他人的冷卻技能、食物和精煉藥劑。",
    "Show the buff's time, not the cooldown": "顯示增益時間，而非冷卻時間",
    "Show them as": "顯示為",
    "Show this viewer at all. The editor handle stays either way, so this is reversible from right here.":
        "是否顯示該顯示器。無論如何編輯把手都會保留，因此可以直接在此復原。",
    "Sparkles": "閃光",
    "Talent specs": "天賦專精",
    "The frame is a soft shadow that falls on the icon's outer edge, so it only shows where there is "
    "icon underneath it. Strength draws it more than once to deepen it — that is also what makes its "
    "rounded corners read, since the icons themselves cannot be rounded here. Inset shrinks the icon, "
    "which slides the shadow off it, so raise that one sparingly.":
        "外框是落在圖示外緣的柔和陰影，因此只在其下方有圖示的地方顯示。強度會多次繪製它以加深效果——"
        "這也是它的圓角能被看出來的原因，因為此處圖示本身無法做成圓角。內縮會縮小圖示，使陰影滑出圖示，"
        "所以請謹慎提高該值。",
    "The full curated list for your class, both specs' spells|nincluded. This is what the Cooldown "
    "Manager shipped with|nbefore per-spec starters.":
        "你職業的完整精選清單，包含兩個專精的法術。|n這是冷卻管理員在推出各專精初始版面之前|n所附帶的內容。",
    "Tracked automatically. Drag it into a section to pin it there.":
        "已自動追蹤。將它拖入某個區段即可固定在那裡。",
    "Undoes the last layout change — applying a layout,|nimporting one, or the starter reset.|n|nOne "
    "step, and only for this session.":
        "復原上一次版面變更——套用版面、|n匯入版面或重設為初始版面。|n|n只能復原一步，且僅在本次登入期間有效。",
    "Usable": "可施放",
    "Use Starter Layout": "使用初始版面",
    "Utility Cooldowns": "輔助冷卻",
    "Vertical": "垂直",
    "Viewer layout": "顯示器版面",
    "Visibility": "可見性",
    "When this viewer is on screen at all. Hidden still leaves the editor handle here.":
        "該顯示器何時出現在畫面上。選擇「隱藏」仍會在此保留編輯把手。",
    "Which of the two buff viewers auto-tracked buffs land in.":
        "自動追蹤的增益會進入兩個增益顯示器中的哪一個。",
    "Which spells and buffs you track is remembered separately for each talent spec, so a Discipline "
    "layout and a Holy one do not overwrite each other. Where each viewer sits is always remembered "
    "per character; the appearance settings are shared unless you say otherwise below.":
        "你追蹤的法術和增益會依天賦專精分別記錄，因此戒律版面與神聖版面不會互相覆蓋。每個顯示器的位置"
        "一律依角色記錄；除非你在下方另行設定，否則外觀設定為共用。",
    "is turned off. Enable it in DragonUI's options, under New Era > Cooldown Manager.":
        "已關閉。請在 DragonUI 選項的 New Era > 冷卻管理員中啟用它。",
    "you": "你",
    "|n|nOn a buff row this is about RE-CASTING it,|nnot about the buff being up — that is Active.":
        "|n|n在增益列中，這指的是「重新施放」，|n而不是增益是否存在——那是「生效中」。",
    "|n|nThe one for a DoT or a shield: it asks whether|nthe aura is up, not whether the cooldown is "
    "ready.":
        "|n|n適用於持續傷害或護盾：它判斷的是|n光環是否存在，而不是冷卻是否就緒。",
    "|n|nThis one also waits for a target below %d%% health.": "|n|n此項還會等待生命值低於%d%%的目標。",
    "|n|n|cff40ff40Applies %s to %s, so this will work.|r": "|n|n|cff40ff40會對%s施加%s，因此這會生效。|r",
    "|n|n|cff40ff40Its aura is active now, so this will work.|r":
        "|n|n|cff40ff40它的光環目前處於生效狀態，因此這會生效。|r",
    "|n|n|cffffd200No aura of this name is up right now.|r": "|n|n|cffffd200目前沒有該名稱的光環生效。|r",

    # ── Adventure guide ─────────────────────────────────────────────────────────────────────────
    "(No abilities recorded for this encounter.)": "（該首領戰沒有記錄任何技能。）",
    "(no model)": "（無模型）",
    "Adventure Guide": "冒險指南",
    "Eastern Kingdoms": "東部王國",
    "Kalimdor": "卡林多",
    "Model will load once seen within this session due to client limitations.":
        "受客戶端限制，模型需在本次登入中出現過一次後才會載入。",
    "Phase %d": "第%d階段",
    "The Adventure Guide: bosses, abilities, and loot for Classic and Burning Crusade dungeons and "
    "raids (/aguide).":
        "冒險指南：經典版和燃燒的遠征地城與團隊副本的首領、技能和戰利品（/aguide）。",

    # ── Guild ───────────────────────────────────────────────────────────────────────────────────
    "GuildControlPopupFrame is missing on this client.": "此客戶端缺少 GuildControlPopupFrame。",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "現代社群風格的公會視窗（成員 / 資訊 / 聊天）。",
    "Promote": "晉升",

    # ── Level up display ────────────────────────────────────────────────────────────────────────
    "Battleground available": "可進入新戰場",
    "Can be learned from a trainer": "可向訓練師學習",
    "Dungeon available": "可進入新地城",
    "Enable Level Up Display": "啟用升級提示",
    "Level Up Display": "升級提示",
    "New Feature": "新功能",
    "New Riding Skill": "新的騎術",
    "New Talent Point": "新的天賦點數",
    "New Talent Points": "新的天賦點數",
    "New rank available": "可取得新軍階",
    "On by default. Turn off to stop the banner appearing on level-up; the harvest keeps running "
    "either way, so turning it back on costs nothing.":
        "預設開啟。關閉後升級時不再顯示橫幅；無論如何資料蒐集都會繼續執行，因此重新開啟不會有任何代價。",
    "Play the level-up sound": "播放升級音效",
    "Raid available": "可進入新團隊副本",
    "Retail's level-up banner. What it announces is read from |cffffcc55this server|r — abilities and "
    "their levels come from your class trainer's own list, battlegrounds and dungeons from the "
    "client's brackets. Visit a trainer once to fill it in; |cffffcc55/nelevelup coverage|r shows "
    "what it knows.":
        "正式服的升級橫幅。它所公布的內容讀取自|cffffcc55目前伺服器|r——技能及其等級來自你職業訓練師"
        "自己的清單，戰場和地城則來自客戶端的等級區間。去訓練師那裡走一趟即可填入資料；"
        "|cffffcc55/nelevelup coverage|r 可查看它已知的內容。",
    "Talents": "天賦",
    "You have reached": "你已達到",
    "level %d": "%d級",
    "|cffffcc55Off by default.|r The game already plays its own fanfare when you level, so this only "
    "adds a second copy on top of it. Turn it on if you want /nelevelup previews to make a sound, "
    "since those fire no game sound of their own.":
        "|cffffcc55預設關閉。|r升級時遊戲本身已會播放自己的號角聲，因此此項只會在其上疊加第二次。"
        "如果你希望 /nelevelup 的預覽帶有音效，可以開啟它，因為預覽本身不會觸發任何遊戲音效。",

    # ── Professions window ──────────────────────────────────────────────────────────────────────
    "Auctionator API not available for reagent scans.": "Auctionator 介面無法使用，無法掃描材料。",
    "Auctionator scan started for recipe reagents.": "已開始使用 Auctionator 掃描配方材料。",
    "Open the Auction House first to run Auctionator scans.":
        "請先開啟拍賣場才能執行 Auctionator 掃描。",
    "Requires the Auction House window to be open.": "需要開啟拍賣場視窗。",
    "Requires: %s": "需要：%s",
    "Retail-style crafting window for all professions.": "適用於所有專業的正式服風格製作視窗。",
    "Scan AH": "掃描拍賣場",
    "Searches Auctionator for the selected recipe and its reagents.":
        "在 Auctionator 中搜尋所選配方及其材料。",

    # ── Social ──────────────────────────────────────────────────────────────────────────────────
    "Away": "暫離",
    "Busy": "忙碌",
    "Cancel Extend": "取消延長",
    "Enter a note for %s:": "為%s輸入備註：",
    "Extend": "延長",
    "Extended": "已延長",
    "ID: %s": "ID：%s",
    "Instance": "副本",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "現代好友視窗（好友 / 忽略 / 誰），並附有公會頁籤。",
    "Promote to Assistant": "晉升為助理",
    "Promote to Raid Leader": "晉升為團隊隊長",
    "Resets In": "重置於",
    "Set Note": "設定備註",
    "You are not saved to any instances.": "你沒有綁定任何副本。",

    # ── Spellbook ───────────────────────────────────────────────────────────────────────────────
    "Spellbook": "法術書",
    "The modern Dragonflight spellbook window. Disable to keep the stock Blizzard spellbook.":
        "現代巨龍崛起風格的法術書視窗。關閉則保留暴雪原版法術書。",

    # ── Talents ─────────────────────────────────────────────────────────────────────────────────
    "  %s: have %d, build wants %d": "  %s：現有%d點，設定需要%d點",
    "%s\\n\\nImport anyway?": "%s\\n\\n仍要匯入？",
    "ACTIVE EFFECTS": "生效中的效果",
    "Activate": "啟用",
    "Copy this build string (Ctrl+C). Talented & the WoWhead/wotlkdb calculators import it too:":
        "複製這段設定代碼（Ctrl+C）。Talented 以及 WoWhead/wotlkdb 計算機也可匯入：",
    "Delete loadout '%s'?": "刪除設定「%s」？",
    "GLYPHS": "雕紋",
    "Glyph options": "雕紋選項",
    "Glyphs": "雕紋",
    "Import…": "匯入…",
    "Loadouts": "設定組",
    "Locked": "已鎖定",
    "MAJOR GLYPHS": "主要雕紋",
    "MINOR GLYPHS": "次要雕紋",
    "NO ACTIVE EFFECTS": "沒有生效中的效果",
    "Name this imported loadout:": "為匯入的設定組命名：",
    "Name this loadout (saves your current spec):": "為此設定組命名（儲存你目前的專精）：",
    "Paste a talent string or calculator URL (Talented / WoWhead / wotlkdb):":
        "貼上天賦代碼或計算機網址（Talented / WoWhead / wotlkdb）：",
    "Pet": "寵物",
    "Remove this glyph?": "移除該雕紋？",
    "Rename loadout:": "重新命名設定組：",
    "Rename specialization": "重新命名專精",
    "Rename this specialization (letters only, max %d):": "重新命名該專精（僅限字母，最多%d個字元）：",
    "Save current spec…": "儲存目前專精…",
    "Server uses custom talents": "伺服器使用了自訂天賦",
    "Show glyph effects": "顯示雕紋效果",
    "Show glyph names": "顯示雕紋名稱",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "為匯出的設定標記此伺服器，以便匯入到其他版面時先行提示。",
    "Talents Panel": "天賦面板",
    "The modern talents window. Turn off to use the standard Blizzard talent window.":
        "現代天賦視窗。關閉則使用暴雪標準天賦視窗。",
    "This loadout has fewer points in some talents than you've already spent, so it needs a respec "
    "first:\\n":
        "該設定組在某些天賦上的點數少於你已投入的點數，因此需要先重置天賦：\\n",
    "Toggle slot name labels and the active-effects list.": "切換欄位名稱標籤和生效效果清單。",
    "Unlock Spec": "解鎖專精",
    "\\n\\nReset at a class trainer, then load again. (The rest has been staged — click Apply to learn it.)":
        "\\n\\n請到職業訓練師處重置天賦，然後重新載入。（其餘部分已準備就緒——點擊「套用」即可學習。）",

    # ── Options panel ───────────────────────────────────────────────────────────────────────────
    "Adventure Guide (Encounter Journal)": "冒險指南（首領戰日誌）",
    "Auction House": "拍賣場",
    "Boss and loot browser. Requires a /reload to take effect (the micro button doesn't re-check this "
    "live).":
        "首領與戰利品瀏覽器。需 /reload 才會生效（微型按鈕不會即時重新檢查此項）。",
    "Click for this frame's settings.": "點擊可查看該視窗的設定。",
    "Combined Bag": "合併背包",
    "Custom": "自訂",
    "Custom scale": "自訂縮放",
    "Drag to move.": "拖曳以移動。",
    "Each window's size: \\\"Use UI scale\\\" follows the game's UI Scale slider, \\\"No scaling\\\" "
    "stays pixel-perfect, \\\"Custom\\\" uses its slider. The custom slider is greyed out and locked "
    "unless that window's mode is set to Custom.":
        "每個視窗的大小：\"使用介面縮放\"會跟隨遊戲的介面縮放滑桿，\"不縮放\"維持像素精確，"
        "\"自訂\"使用它自己的滑桿。除非該視窗的模式設為「自訂」，否則自訂滑桿會變灰並鎖定。",
    "Guild": "公會",
    "Looking For Group": "尋找隊伍",
    "Looking For Group (Dungeon/Raid Finder)": "尋找隊伍（地城/團隊副本搜尋器）",
    "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. Panels appear "
    "here as their modules load.":
        "移植到 DragonUI 上的 NewEra 面板。在下方開啟或關閉某個面板。面板會隨其模組載入而出現在這裡。",
    "No scaling": "不縮放",
    "Our all-in-one bag window. Turn OFF to use the stock Blizzard bags instead. Reload (/reload) to "
    "apply.":
        "我們的一體式背包視窗。關閉後將改用暴雪原版背包。需 /reload 生效。",
    "Professions": "專業技能",
    "Reload (/reload) to apply.": "需 /reload 生效。",
    "Scale mode": "縮放模式",
    "Scaling controls are unavailable: the 'core\\\\Scale.lua' file isn't loaded. Make sure your "
    "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.":
        "縮放選項無法使用：檔案 'core\\Scale.lua' 未載入。請確認你安裝的 DragonUI_NewEra 同時包含 "
        "core/Scale.lua 以及它在 .toc 中的對應行，然後執行 /reload。",
    "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).":
        "縮放選項需要較新版本的 DragonUI 選項面板（AddSlider/AddDropdown）。",
    "Social": "社交",
    "Social (Friends/Who/Guild/Chat/Raid)": "社交（好友/誰/公會/聊天/團隊）",
    "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.":
        "使用 DragonUI 的視窗取代暴雪預設視窗。變更會在 /reload 後生效。",
    "Use UI scale": "使用介面縮放",
    "Window Scaling": "視窗縮放",
    "Windows": "視窗",

    # ── Shared UI ───────────────────────────────────────────────────────────────────────────────
    "Select All": "全選",

    # ── Inspect ──────────────────────────────────────────────────────────────────
    #
    # Honor / Arena / Rating / Kills are FALLBACKS: modules/inspect/PvPPane.lua prefers the
    # client's own HONOR / ARENA / RATING / HONORABLE_KILLS globals and only reaches for these
    # if one of them is missing.
    "Arena": "競技場",
    "Honor": "榮譽",
    "Inspect window": "檢視視窗",
    "Kills": "擊殺",
    "Modern frame, portrait and tabs on the inspect window, with its Character tab laid out like the character window. Reload (/reload) to apply.":
        "為檢視視窗套用現代風格的邊框、頭像與頁籤，其角色頁籤的版面與角色面板一致。需要 /reload 生效。",
    "No team": "無隊伍",
    "Rating": "評分",
    "Unranked": "無軍階",
    "View this player's talents.": "檢視該玩家的天賦。",
    "points spent": "點已花費",
}
