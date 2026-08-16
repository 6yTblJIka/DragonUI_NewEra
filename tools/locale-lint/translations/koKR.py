# -*- coding: utf-8 -*-
"""Korean translations. Keys are the enUS.lua source text verbatim.

Machine-drafted. Placeholder parity is enforced by check_keys.py --verify; wording is not reviewed.
Note for a reviewer: Korean particles (은/는, 이/가, 을/를) depend on the final consonant of the
preceding word, so the %s-interpolated strings below cannot pick the right particle in every case.
Where that would read badly the sentence is rewritten to avoid the particle rather than guess.
"""

T = {
    # ── Professions ─────────────────────────────────────────────────────────────────────────────
    "Alchemy": "연금술",
    "Blacksmithing": "대장기술",
    "Enchanting": "마법부여",
    "Engineering": "기계공학",
    "Herbalism": "약초채집",
    "Leatherworking": "가죽세공",
    "Mining": "채광",
    "Smelting": "제련",
    "Skinning": "무두질",
    "Tailoring": "재봉술",
    "Inscription": "주문각인",
    "Jewelcrafting": "보석세공",
    "Prospecting": "광물 탐색",
    "Cooking": "요리",
    "First Aid": "응급치료",
    "Fishing": "낚시",
    "Select a recipe to craft": "제작할 도안을 선택하십시오",
    "Hide item tooltips in list": "목록에서 아이템 툴팁 숨기기",
    "Colour names by skill difficulty": "숙련도 난이도에 따라 이름 색칠",
    "Plain skill bar (no animation)": "단순한 숙련도 막대 (애니메이션 없음)",
    "Create": "제작",
    "Create All": "모두 제작",
    "Show Learned": "배운 것 표시",
    "Has Skill Up": "숙련도 상승",
    "Have Materials": "재료 보유",

    # ── Character, titles, equipment manager ────────────────────────────────────────────────────
    "None": "없음",

    # ── Auction house ───────────────────────────────────────────────────────────────────────────
    " -- partial scan": " -- 부분 검색",
    "Auction query is throttled. Try again in a moment.":
        "경매장 조회가 제한되었습니다. 잠시 후 다시 시도하십시오.",
    "Buy out this auction for %s?": "%s에 이 경매를 즉시 구매하시겠습니까?",
    r"Choose search criteria and press \"Search\"": "검색 조건을 선택하고 \"검색\"을 누르십시오",
    "Loading results...": "결과를 불러오는 중...",
    "Lvl": "레벨",
    "Modern visual shell for Buy/Sell/Auctions with optional Auctionator tab embedding.":
        "구매/판매/경매를 위한 현대적인 인터페이스이며, Auctionator 탭을 선택적으로 넣을 수 있습니다.",
    "No listings.": "등록된 경매가 없습니다.",
    "No results. Adjust filters and search again.": "결과가 없습니다. 필터를 조정하고 다시 검색하십시오.",
    "Page %d of %d  (items %d-%d of %d, from %d auction)%s":
        "%d/%d 페이지  (아이템 %d-%d / 총 %d개, 경매 %d건)%s",
    "Page %d of %d  (items %d-%d of %d, from %d auctions)%s":
        "%d/%d 페이지  (아이템 %d-%d / 총 %d개, 경매 %d건)%s",
    "Page 1 of 1": "1/1 페이지",
    "Per Item": "개당",
    "Place a bid of %s?": "%s를 입찰하시겠습니까?",
    "Scanning page %d of %d...": "%d/%d 페이지 검색 중...",
    "Searching...": "검색 중...",
    "Sort Per Item": "개당 가격순 정렬",
    "You have no auctions.": "등록한 경매가 없습니다.",

    # ── Bags ────────────────────────────────────────────────────────────────────────────────────
    "All Bags": "모든 가방",
    "Auto-empty old bag when swapping": "교체 시 기존 가방 자동 비우기",
    "Auto-sell junk at merchants": "상인에게 잡동사니 자동 판매",
    "Bag Options": "가방 설정",
    "Category (smart)": "분류 (스마트)",
    "Combined bag (all-in-one)": "통합 가방 (일체형)",
    "Item Level": "아이템 레벨",
    "Keys": "열쇠",
    "Merchant": "상인",
    "Name": "이름",
    "Not enough free space to swap that bag.": "가방을 교체할 공간이 부족합니다.",
    "One movable window showing every bag slot in a Dragonflight-style grid. Takes over bag opening "
    "and replaces the per-window 'Retail bags' restyle. Reload (/reload) to apply.":
        "모든 가방 칸을 용의 군단 스타일 격자로 보여주는 이동 가능한 단일 창입니다. 가방 열기를 대신 "
        "처리하며 창별 '정식 서버 가방' 재단장을 대체합니다. 적용하려면 /reload 하십시오.",
    "Quality": "품질",
    "Red-tint unusable items": "사용할 수 없는 아이템을 붉게 표시",
    "Restyle the bag windows with the Dragonflight metal frame, portrait, and item quality borders. "
    "Disable to keep the stock Blizzard bags. Reload (/reload) to apply.":
        "가방 창을 용의 군단 금속 테두리, 초상화, 아이템 품질 테두리로 재단장합니다. 끄면 기본 블리자드 "
        "가방을 유지합니다. 적용하려면 /reload 하십시오.",
    "Retail bags": "정식 서버 가방",
    "Reverse sort order": "정렬 순서 반대로",
    "Search": "검색",
    "Separate specialty bags": "전문 가방 따로 표시",
    "Shift-right-click to stop watching": "Shift+우클릭하면 주시를 중지합니다",
    "Show item level on items": "아이템에 아이템 레벨 표시",
    "Show keyring row": "열쇠 꾸러미 줄 표시",
    "Sold %d junk item(s).": "잡동사니 %d개를 판매했습니다.",
    "Sort Bags": "가방 정리",
    "Sort by": "정렬 기준",
    "Sorting…": "정리하는 중…",
    "Swapping bag…": "가방 교체 중…",
    "The same setting as Enable Item Level in DragonUI's options (Enhancements > Item Level). "
    "Covers the character panel and every other frame too.":
        "DragonUI 설정의 '아이템 레벨 사용'(강화 > 아이템 레벨)과 동일한 설정입니다. 캐릭터 창을 비롯한 "
        "모든 창에도 적용됩니다.",
    "Turn on Item Level in DragonUI's options (Enhancements > Item Level) first.":
        "먼저 DragonUI 설정에서 '아이템 레벨'(강화 > 아이템 레벨)을 켜십시오.",

    # ── Cooldown manager ────────────────────────────────────────────────────────────────────────
    "(empty)": "(비어 있음)",
    "(your spec)": "(현재 특성)",
    "A ready sound plays when a COOLDOWN finishes.|nThis spell has none, so it can never play."
    "|nClearing it also clears the badge.":
        "준비 완료 소리는 '재사용 대기시간'이 끝날 때 재생됩니다.|n이 주문에는 대기시간이 없어 소리가 "
        "재생될 수 없습니다.|n소리를 지우면 표식도 함께 지워집니다.",
    "A spell can be on cooldown and buffing you at the same time. The glow says which icons are "
    "buffed; the timer says how long.":
        "주문은 재사용 대기 중이면서 동시에 효과를 줄 수 있습니다. 빛은 어떤 아이콘에 효과가 걸려 있는지, "
        "타이머는 얼마나 남았는지 알려줍니다.",
    "Active": "지속 중",
    "Alert": "알림",
    "Always": "항상",
    "Auto-track buffs under %ds": "%d초 미만 효과 자동 추적",
    "Available": "사용 가능",
    "Bar Content": "막대 내용",
    "Bar Width": "막대 너비",
    "Both of these are immediate and cannot be undone from here — Revert only covers layout changes.":
        "두 작업 모두 즉시 적용되며 여기서는 되돌릴 수 없습니다 — '되돌리기'는 배치 변경만 다룹니다.",
    "Buff Bars": "효과 막대",
    "Buff Icons": "효과 아이콘",
    "Buff tracking": "효과 추적",
    "Buffed spells": "효과가 걸린 주문",
    "Buffs you have not seen before are recorded and listed under Not Displayed on the Tracked Buffs "
    "tab, where you can assign the ones you want. Nothing appears on screen until you do.":
        "처음 보는 효과는 기록되어 '추적 중인 효과' 탭의 '표시 안 함' 아래에 나열되며, 원하는 것을 "
        "지정할 수 있습니다. 그 전까지는 화면에 아무것도 표시되지 않습니다.",
    "Button Glow": "버튼 발광",
    "Clear All Alerts": "모든 알림 지우기",
    "Clear Ready Sound": "준비 완료 소리 지우기",
    "Clear all alerts and sounds": "모든 알림과 소리 지우기",
    "Clear every configured alert and ready sound?\\n\\nSpell lists and frame positions are not affected.":
        "설정된 모든 알림과 준비 완료 소리를 지우시겠습니까?\\n\\n주문 목록과 창 위치는 영향을 받지 "
        "않습니다.",
    "Closes edit mode and opens the Cooldown Manager window, which carries the settings that are not "
    "per-viewer: alerts, ready sounds, buff tracking, icon fit and the resets.":
        "편집 모드를 닫고 재사용 대기시간 관리자 창을 엽니다. 이 창에는 개별 표시창에 속하지 않는 설정, "
        "즉 알림, 준비 완료 소리, 효과 추적, 아이콘 맞춤 및 초기화가 들어 있습니다.",
    "Cooldown Manager": "재사용 대기시간 관리자",
    "Cooldown Manager Settings": "재사용 대기시간 관리자 설정",
    "Cooldown Manager layout string (Ctrl+C to copy):":
        "재사용 대기시간 관리자 배치 문자열 (Ctrl+C로 복사):",
    "Copy": "복사",
    "Defensives, interrupts, CC and escapes.": "방어, 시전 방해, 군중 제어 및 탈출기입니다.",
    "Delete": "삭제",
    r'Delete the layout \"%s\"?': '배치 \"%s\"을(를) 삭제하시겠습니까?',
    "Drag onto Essential or Utility to track it.":
        "'핵심' 또는 '보조'로 끌어다 놓으면 추적합니다.",
    "Draw the countdown number on each icon.": "각 아이콘에 남은 시간 숫자를 표시합니다.",
    "Each viewer's own settings — size, spacing, orientation, visibility, what its icons show — live "
    "on the frame, in edit mode, where you can see what you are changing. These open edit mode with "
    "that viewer selected and its settings already up. Closes this window; not available in combat.":
        "각 표시창 고유의 설정 — 크기, 간격, 방향, 표시 여부, 아이콘이 보여주는 내용 — 은 편집 모드의 "
        "프레임 위에 있어 무엇을 바꾸는지 직접 확인할 수 있습니다. 이 버튼들은 해당 표시창이 선택되고 "
        "설정이 열린 상태로 편집 모드를 엽니다. 이 창은 닫히며, 전투 중에는 사용할 수 없습니다.",
    "Enable Cooldown Manager": "재사용 대기시간 관리자 사용",
    "Enabled": "사용함",
    "Essential Cooldowns": "핵심 기술",
    "Everything": "전체",
    "Everything (no spec)": "전체 (특성 무관)",
    "Everything the Cooldown Manager can be told to do that is not about one viewer's layout. Layout "
    "and position both live on the frame itself, in edit mode (/dui edit) — click a viewer there for "
    "its own settings, or use the buttons just below to go straight to one.":
        "재사용 대기시간 관리자가 할 수 있는 일 가운데 개별 표시창의 배치와 무관한 모든 것입니다. 배치와 "
        "위치는 편집 모드(/dui edit)의 프레임 자체에 있습니다 — 그곳에서 표시창을 클릭하면 고유 설정이 "
        "열리며, 아래 버튼으로 바로 이동할 수도 있습니다.",
    "Export Layout": "배치 내보내기",
    "FX Style": "효과 스타일",
    "Flashes once, the moment the cooldown finishes.|nWorks for every spell.":
        "재사용 대기시간이 끝나는 순간 한 번 반짝입니다.|n모든 주문에 적용됩니다.",
    "Frame strength": "테두리 강도",
    "Gap between icons. Retail offsets this by -4, so the low end overlaps slightly — that is the "
    "stock look, not a bug.":
        "아이콘 사이의 간격입니다. 정식 서버는 이 값을 -4만큼 보정하므로 낮은 값에서는 약간 겹칩니다 — "
        "이는 원본 모습이며 오류가 아닙니다.",
    "Glow while buffed": "효과가 걸려 있을 때 발광",
    "Glows during the last %d%% of this buff's|nremaining time.":
        "이 효과의 남은 시간 중 마지막 %d%% 동안|n빛납니다.",
    "Glows during the last %d%% of this spell's own|nbuff or debuff.":
        "이 주문 자체의 효과 또는 약화 효과의|n마지막 %d%% 동안 빛납니다.",
    "Glows for as long as the spell is off cooldown|nand affordable.":
        "주문이 재사용 대기 중이 아니고|n자원이 충분한 동안 계속 빛납니다.",
    "Glows for as long as this buff is on you.|n|nThe one that works for a proc: it asks whether "
    "the|nbuff is up, not whether something is castable|nor off cooldown.":
        "이 효과가 걸려 있는 동안 계속 빛납니다.|n|n발동 효과에 적합합니다: 시전 가능 여부나|n대기시간이 "
        "아니라|n효과가 지속 중인지를 확인합니다.",
    "Glows for as long as this spell's effect is|nup on %s.":
        "이 주문의 효과가 %s에게 지속되는 동안|n계속 빛납니다.",
    "Halo the icon gold while the spell's buff (or, for a shaman, its totem) is up.":
        "주문의 효과(주술사는 해당 토템)가 지속되는 동안 아이콘을 금색 후광으로 감쌉니다.",
    "Hidden": "숨김",
    "Hide When Inactive": "비활성 시 숨기기",
    "Horizontal": "가로",
    "How many icons before the layout wraps. Vertical orientation reads this as icons per column.":
        "배치가 줄바꿈되기 전까지의 아이콘 수입니다. 세로 방향에서는 열당 아이콘 수로 해석됩니다.",
    "Icon Direction": "아이콘 방향",
    "Icon Limit": "아이콘 개수 제한",
    "Icon Only": "아이콘만",
    "Icon Padding": "아이콘 간격",
    "Icon Size": "아이콘 크기",
    "Icon and Name": "아이콘과 이름",
    "Icon fit": "아이콘 맞춤",
    "Icon inset": "아이콘 여백",
    "Import": "가져오기",
    "Import Layout": "배치 가져오기",
    "In Combat": "전투 중",
    "Lasts %s sec": "%s초 동안 지속",
    "Layouts": "배치",
    "Layouts include appearance": "배치에 외형 포함",
    "Left": "왼쪽",
    "Load the %s starter layout?\\n\\nEssential is set to that spec's spells. Everything else for your "
    "class moves to Not Displayed — nothing is deleted, and you can drag any of it back.\\n\\nTracked "
    "auras, trinkets, alerts and frame positions are not affected.":
        "%s 기본 배치를 불러오시겠습니까?\\n\\n'핵심'이 해당 특성의 주문으로 설정됩니다. 직업의 나머지 "
        "항목은 '표시 안 함'으로 이동합니다 — 삭제되는 것은 없으며 언제든 다시 끌어다 놓을 수 "
        "있습니다.\\n\\n추적 중인 오라, 장신구, 알림 및 창 위치는 영향을 받지 않습니다.",
    "Marching Ants": "흐르는 점선",
    "Move to %s": "%s(으)로 이동",
    "Name Only": "이름만",
    "Name this layout:": "이 배치의 이름:",
    "New Layout": "새 배치",
    "Not displayed on any viewer": "어떤 표시창에도 표시되지 않음",
    "Not yet learned": "아직 배우지 않음",
    "Nothing to undo. It covers LAYOUTS, not the settings|non these tabs — a viewer's own size and "
    "position revert|nfrom its edit-mode panel instead.":
        "되돌릴 것이 없습니다. 이 기능은 이 탭의 설정이 아니라|n'배치'를 다룹니다 — 표시창 고유의 크기와 "
        "위치는|n해당 편집 모드 창에서 되돌립니다.",
    "Off by default. Turn on to show the four viewers; turn off to hide them again. Takes effect "
    "immediately either way, and nothing is forgotten — this switch stores one flag and touches "
    "nothing else, so your setup comes back exactly as you left it.":
        "기본적으로 꺼져 있습니다. 켜면 표시창 네 개가 나타나고, 끄면 다시 숨겨집니다. 어느 쪽이든 즉시 "
        "적용되며 아무것도 잊히지 않습니다 — 이 스위치는 표시 하나만 저장할 뿐 다른 것은 건드리지 않으므로 "
        "설정은 그대로 되돌아옵니다.",
    "Off, both specs share one set of lists. Turning it on copies the layout you have now into the "
    "spec you are in.":
        "끄면 두 특성이 하나의 목록 묶음을 공유합니다. 켜면 현재 배치가 지금 사용 중인 특성으로 "
        "복사됩니다.",
    "Off, loading or importing a layout changes only what you track — lists, tracked buffs, trinkets, "
    "alerts and sounds. On, it also applies the orientation, icons per row, size, padding and opacity "
    "the layout was saved with.|n|nLayouts always SAVE appearance either way, so this only decides "
    "what happens when one is applied. Revert always puts appearance back, whatever this says.":
        "끄면 배치를 불러오거나 가져올 때 추적 대상만 바뀝니다 — 목록, 추적 중인 효과, 장신구, 알림, 소리. "
        "켜면 해당 배치가 저장될 때의 방향, 줄당 아이콘 수, 크기, 간격, 불투명도도 함께 적용됩니다."
        "|n|n배치는 어느 쪽이든 항상 외형을 '저장'하므로, 이 설정은 적용할 때의 동작만 결정합니다. "
        "'되돌리기'는 이 설정과 무관하게 항상 외형을 복원합니다.",
    "Off, orientation, icons per row, size, padding and opacity are one setup for every character. On, "
    "each character can differ — until you change something here it still follows the shared setup, so "
    "nothing moves when you tick this, and unticking it gives the shared setup back without losing "
    "what you changed.":
        "끄면 방향, 줄당 아이콘 수, 크기, 간격, 불투명도가 모든 캐릭터에 대해 하나의 설정으로 적용됩니다. "
        "켜면 캐릭터마다 다를 수 있습니다 — 여기서 무언가를 바꾸기 전까지는 공유 설정을 그대로 따르므로 "
        "체크해도 아무것도 움직이지 않으며, 체크를 해제하면 변경한 내용을 잃지 않고 공유 설정으로 "
        "돌아갑니다.",
    "Offensive burst and damage cooldowns.": "공격적인 폭발기와 피해 기술입니다.",
    "Opacity": "불투명도",
    "Open Cooldown Manager": "재사용 대기시간 관리자 열기",
    "Opens a share string you can copy with Ctrl+C.|nIt covers this class's spell lists, tracked "
    "auras,|ntrinket placement, alerts and sounds.":
        "Ctrl+C로 복사할 수 있는 공유 문자열을 엽니다.|n이 직업의 주문 목록, 추적 중인 오라,|n장신구 배치, "
        "알림, 소리가 포함됩니다.",
    "Opens the Cooldown Manager window (/cdm) on its Spells tab. Needs the module on — the window "
    "configures the viewers, so it goes away with them.":
        "재사용 대기시간 관리자 창(/cdm)을 '주문' 탭에서 엽니다. 모듈이 켜져 있어야 합니다 — 이 창은 "
        "표시창을 설정하므로 표시창과 함께 사라집니다.",
    "Options": "설정",
    "Orientation": "방향",
    "Pandemic Border": "재적용 테두리",
    "Paste a Cooldown Manager layout string:":
        "재사용 대기시간 관리자 배치 문자열을 붙여넣으십시오:",
    "Ready Sound": "준비 완료 소리",
    "Ready sound: %s": "준비 완료 소리: %s",
    "Refresh": "재적용",
    "Refresh Window": "재적용 구간",
    "Remove": "제거",
    "Remove every per-spell alert and ready sound. Spell lists and positions are not affected.":
        "주문별 알림과 준비 완료 소리를 모두 제거합니다. 주문 목록과 위치는 영향을 받지 않습니다.",
    "Rename": "이름 변경",
    "Requires the %s talent": "'%s' 특성이 필요합니다",
    "Reset": "초기화",
    "Reset %s to its default layout?\\n\\nThis viewer's position, size, orientation and visibility all "
    "go back to stock. Nothing else is affected, and it cannot be undone.":
        "%s을(를) 기본 배치로 초기화하시겠습니까?\\n\\n이 표시창의 위치, 크기, 방향, 표시 여부가 모두 "
        "원래대로 돌아갑니다. 다른 항목은 영향을 받지 않으며, 되돌릴 수 없습니다.",
    "Reset Spell Lists": "주문 목록 초기화",
    "Reset spell and buff lists": "주문 및 효과 목록 초기화",
    "Reset this class's Cooldown Manager spell and buff lists to their defaults?\\n\\nOther classes, "
    "alerts, sounds and frame positions are not affected.":
        "이 직업의 재사용 대기시간 관리자 주문 및 효과 목록을 기본값으로 초기화하시겠습니까?\\n\\n다른 "
        "직업, 알림, 소리, 창 위치는 영향을 받지 않습니다.",
    "Reset to the starter layout?\\n\\nThis reverts every Cooldown Manager edit — spells, tracked auras, "
    "trinket placement, alerts and sounds — to their defaults, and clears your saved-layout "
    "selection.\\n\\nFrame positions are not affected.":
        "기본 배치로 초기화하시겠습니까?\\n\\n재사용 대기시간 관리자의 모든 변경 사항 — 주문, 추적 중인 "
        "오라, 장신구 배치, 알림, 소리 — 이 기본값으로 되돌아가고 저장된 배치 선택이 "
        "지워집니다.\\n\\n창 위치는 영향을 받지 않습니다.",
    "Restore the curated defaults and the auto-track window for THIS CLASS, clearing its spell lists, "
    "aura assignments and trinket placement. Other classes, alerts, sounds and positions are not "
    "affected.":
        "'현재 직업'의 선별된 기본값과 자동 추적 구간을 복원하고, 해당 직업의 주문 목록, 오라 지정, 장신구 "
        "배치를 지웁니다. 다른 직업, 알림, 소리, 위치는 영향을 받지 않습니다.",
    "Retail's Cooldown Manager, driven from curated per-class cooldown lists. |cffffcc55Off by "
    "default|r — it adds four viewers to the middle of your screen, so it waits to be asked. Every "
    "setting — which spells and buffs are tracked, each viewer's layout, size and visibility, alerts "
    "and ready sounds — lives in the Cooldown Manager window itself (/cdm). Drag the viewers with "
    "DragonUI's editor mode to reposition them, and right-click one there for its own layout settings.":
        "직업별로 선별된 기술 목록으로 동작하는 정식 서버의 재사용 대기시간 관리자입니다. "
        "|cffffcc55기본적으로 꺼져 있습니다|r — 화면 한가운데에 표시창 네 개를 추가하므로 직접 켜야 "
        "합니다. 모든 설정 — 어떤 주문과 효과를 추적할지, 각 표시창의 배치, 크기, 표시 여부, 알림과 준비 "
        "완료 소리 — 은 재사용 대기시간 관리자 창(/cdm) 안에 있습니다. DragonUI의 편집 모드에서 표시창을 "
        "끌어 위치를 옮기고, 그곳에서 표시창을 우클릭하면 고유 배치 설정이 열립니다.",
    "Retail's behaviour: while buffed, the icon counts down the BUFF. Off, it counts down the spell's "
    "cooldown and the glow alone marks it as buffed — which is clearer when the two differ, as on "
    "Prayer of Mending.":
        "정식 서버의 동작입니다: 효과가 걸려 있는 동안 아이콘은 '효과'의 남은 시간을 셉니다. 끄면 주문의 "
        "재사용 대기시간을 세고 빛만으로 효과가 걸려 있음을 표시합니다 — '치유의 기원'처럼 둘이 다를 때 더 "
        "명확합니다.",
    "Revert": "되돌리기",
    "Right": "오른쪽",
    "Save, load, import and export the whole|nCooldown Manager setup for this class.":
        "이 직업의 재사용 대기시간 관리자 설정 전체를|n저장, 불러오기, 가져오기, 내보내기 합니다.",
    "Separate appearance per character": "캐릭터별로 외형 분리",
    "Separate layout per spec": "특성별로 배치 분리",
    "Short-duration buffs and procs, as depleting bars.":
        "짧은 지속 효과와 발동 효과를 줄어드는 막대로 표시합니다.",
    "Short-duration buffs and procs, as icons.": "짧은 지속 효과와 발동 효과를 아이콘으로 표시합니다.",
    "Show Timer": "타이머 표시",
    "Show Tooltips": "툴팁 표시",
    "Show Unlearned": "배우지 않은 것 표시",
    "Show a slot only while its aura is active.": "오라가 지속되는 동안에만 칸을 표시합니다.",
    "Show a tooltip when hovering an icon.": "아이콘 위에 마우스를 올리면 툴팁을 표시합니다.",
    "Show every short buff the moment it lands, without assigning it first. Convenient on a character "
    "you are still setting up; in a raid it fills the viewers with other people's cooldowns, food and "
    "flasks.":
        "짧은 효과를 지정하지 않고도 적용되는 즉시 모두 표시합니다. 아직 설정 중인 캐릭터에 편리하지만, "
        "공격대에서는 다른 사람의 기술, 음식, 비약으로 표시창이 가득 찹니다.",
    "Show the buff's time, not the cooldown": "대기시간 대신 효과 지속시간 표시",
    "Show them as": "표시 방식",
    "Show this viewer at all. The editor handle stays either way, so this is reversible from right here.":
        "이 표시창을 아예 표시할지 여부입니다. 어느 쪽이든 편집 손잡이는 남아 있으므로 바로 여기서 되돌릴 "
        "수 있습니다.",
    "Sparkles": "반짝임",
    "Talent specs": "특성",
    "The frame is a soft shadow that falls on the icon's outer edge, so it only shows where there is "
    "icon underneath it. Strength draws it more than once to deepen it — that is also what makes its "
    "rounded corners read, since the icons themselves cannot be rounded here. Inset shrinks the icon, "
    "which slides the shadow off it, so raise that one sparingly.":
        "테두리는 아이콘 바깥 가장자리에 드리우는 부드러운 그림자이므로 아래에 아이콘이 있는 곳에만 "
        "보입니다. 강도는 그림자를 여러 번 그려 짙게 만듭니다 — 여기서는 아이콘 자체를 둥글게 만들 수 "
        "없으므로, 둥근 모서리가 보이는 것도 이 때문입니다. 여백은 아이콘을 줄여 그림자를 아이콘 밖으로 "
        "밀어내므로 신중하게 올리십시오.",
    "The full curated list for your class, both specs' spells|nincluded. This is what the Cooldown "
    "Manager shipped with|nbefore per-spec starters.":
        "두 특성의 주문을 모두 포함한, 직업 전체의 선별 목록입니다.|n특성별 기본 배치가 생기기 전 재사용 "
        "대기시간 관리자에|n기본으로 들어 있던 구성입니다.",
    "Tracked automatically. Drag it into a section to pin it there.":
        "자동으로 추적됩니다. 원하는 구역으로 끌어다 놓으면 그곳에 고정됩니다.",
    "Undoes the last layout change — applying a layout,|nimporting one, or the starter reset.|n|nOne "
    "step, and only for this session.":
        "마지막 배치 변경을 되돌립니다 — 배치 적용,|n배치 가져오기, 기본 배치 초기화.|n|n한 단계만 "
        "가능하며, 이번 접속 동안에만 유효합니다.",
    "Usable": "시전 가능",
    "Use Starter Layout": "기본 배치 사용",
    "Utility Cooldowns": "보조 기술",
    "Vertical": "세로",
    "Viewer layout": "표시창 배치",
    "Visibility": "표시 여부",
    "When this viewer is on screen at all. Hidden still leaves the editor handle here.":
        "이 표시창이 화면에 언제 나타날지 정합니다. '숨김'을 골라도 편집 손잡이는 여기 남습니다.",
    "Which of the two buff viewers auto-tracked buffs land in.":
        "자동 추적된 효과가 두 효과 표시창 중 어디로 들어갈지 정합니다.",
    "Which spells and buffs you track is remembered separately for each talent spec, so a Discipline "
    "layout and a Holy one do not overwrite each other. Where each viewer sits is always remembered "
    "per character; the appearance settings are shared unless you say otherwise below.":
        "어떤 주문과 효과를 추적하는지는 특성별로 따로 기억되므로 수양 배치와 신성 배치가 서로 덮어쓰지 "
        "않습니다. 각 표시창의 위치는 항상 캐릭터별로 기억됩니다. 외형 설정은 아래에서 달리 지정하지 않는 "
        "한 공유됩니다.",
    "is turned off. Enable it in DragonUI's options, under New Era > Cooldown Manager.":
        "이(가) 꺼져 있습니다. DragonUI 설정의 New Era > 재사용 대기시간 관리자에서 켜십시오.",
    "you": "자신",
    "|n|nOn a buff row this is about RE-CASTING it,|nnot about the buff being up — that is Active.":
        "|n|n효과 줄에서는 효과가 지속 중인지가 아니라|n'다시 시전'하는 것을 뜻합니다 — 그것은 "
        "'지속 중'입니다.",
    "|n|nThe one for a DoT or a shield: it asks whether|nthe aura is up, not whether the cooldown is "
    "ready.":
        "|n|n지속 피해나 보호막에 적합합니다: 대기시간이 준비되었는지가|n아니라 오라가 지속 중인지를 "
        "확인합니다.",
    "|n|nThis one also waits for a target below %d%% health.":
        "|n|n이 항목은 생명력 %d%% 미만인 대상도 기다립니다.",
    "|n|n|cff40ff40Applies %s to %s, so this will work.|r":
        "|n|n|cff40ff40%s을(를) %s에게 적용하므로 정상 작동합니다.|r",
    "|n|n|cff40ff40Its aura is active now, so this will work.|r":
        "|n|n|cff40ff40해당 오라가 지금 지속 중이므로 정상 작동합니다.|r",
    "|n|n|cffffd200No aura of this name is up right now.|r":
        "|n|n|cffffd200현재 이 이름의 오라가 지속되고 있지 않습니다.|r",

    # ── Adventure guide ─────────────────────────────────────────────────────────────────────────
    "(No abilities recorded for this encounter.)": "(이 전투에 기록된 능력이 없습니다.)",
    "(no model)": "(모델 없음)",
    "Adventure Guide": "모험 안내서",
    "Eastern Kingdoms": "동부 왕국",
    "Kalimdor": "칼림도어",
    "Model will load once seen within this session due to client limitations.":
        "클라이언트 제약으로 인해, 이번 접속 중 한 번 본 뒤에야 모델이 표시됩니다.",
    "Phase %d": "%d단계",
    "The Adventure Guide: bosses, abilities, and loot for Classic and Burning Crusade dungeons and "
    "raids (/aguide).":
        "모험 안내서: 클래식과 불타는 성전 던전 및 공격대의 우두머리, 능력, 전리품 (/aguide).",

    # ── Guild ───────────────────────────────────────────────────────────────────────────────────
    "GuildControlPopupFrame is missing on this client.":
        "이 클라이언트에는 GuildControlPopupFrame이 없습니다.",
    "Modern Communities-style guild window (Roster / Info / Chat).":
        "현대적인 커뮤니티 방식의 길드 창입니다 (명단 / 정보 / 대화).",
    "Promote": "승급",

    # ── Level up display ────────────────────────────────────────────────────────────────────────
    "Battleground available": "새로운 전장 이용 가능",
    "Can be learned from a trainer": "교관에게 배울 수 있음",
    "Dungeon available": "새로운 던전 이용 가능",
    "Enable Level Up Display": "레벨 상승 표시 사용",
    "Level Up Display": "레벨 상승 표시",
    "New Feature": "새로운 기능",
    "New Riding Skill": "새로운 탈것 숙련",
    "New Talent Point": "새로운 특성 점수",
    "New Talent Points": "새로운 특성 점수",
    "New rank available": "새로운 계급 획득 가능",
    "On by default. Turn off to stop the banner appearing on level-up; the harvest keeps running "
    "either way, so turning it back on costs nothing.":
        "기본적으로 켜져 있습니다. 끄면 레벨이 오를 때 배너가 나타나지 않습니다. 어느 쪽이든 데이터 수집은 "
        "계속되므로 다시 켜는 데 드는 비용은 없습니다.",
    "Play the level-up sound": "레벨 상승 소리 재생",
    "Raid available": "새로운 공격대 이용 가능",
    "Retail's level-up banner. What it announces is read from |cffffcc55this server|r — abilities and "
    "their levels come from your class trainer's own list, battlegrounds and dungeons from the "
    "client's brackets. Visit a trainer once to fill it in; |cffffcc55/nelevelup coverage|r shows "
    "what it knows.":
        "정식 서버의 레벨 상승 배너입니다. 표시 내용은 |cffffcc55현재 서버|r에서 읽어옵니다 — 능력과 그 "
        "레벨은 직업 교관의 목록에서, 전장과 던전은 클라이언트의 레벨 구간에서 가져옵니다. 교관을 한 번 "
        "방문하면 내용이 채워지며, |cffffcc55/nelevelup coverage|r로 무엇이 등록되었는지 확인할 수 "
        "있습니다.",
    "Talents": "특성",
    "You have reached": "달성했습니다",
    "level %d": "%d레벨",
    "|cffffcc55Off by default.|r The game already plays its own fanfare when you level, so this only "
    "adds a second copy on top of it. Turn it on if you want /nelevelup previews to make a sound, "
    "since those fire no game sound of their own.":
        "|cffffcc55기본적으로 꺼져 있습니다.|r 레벨이 오를 때 게임이 이미 자체 팡파르를 재생하므로, 이 "
        "설정은 그 위에 소리를 하나 더 얹을 뿐입니다. /nelevelup 미리보기에서 소리가 나기를 원한다면 "
        "켜십시오. 미리보기는 자체적으로 게임 소리를 내지 않습니다.",

    # ── Professions window ──────────────────────────────────────────────────────────────────────
    "Auctionator API not available for reagent scans.":
        "재료 검색에 사용할 Auctionator API를 이용할 수 없습니다.",
    "Auctionator scan started for recipe reagents.": "도안 재료에 대한 Auctionator 검색을 시작했습니다.",
    "Open the Auction House first to run Auctionator scans.":
        "Auctionator 검색을 실행하려면 먼저 경매장을 여십시오.",
    "Requires the Auction House window to be open.": "경매장 창이 열려 있어야 합니다.",
    "Requires: %s": "필요: %s",
    "Retail-style crafting window for all professions.":
        "모든 전문 기술을 위한 정식 서버 방식의 제작 창입니다.",
    "Scan AH": "경매장 검색",
    "Searches Auctionator for the selected recipe and its reagents.":
        "선택한 도안과 그 재료를 Auctionator에서 검색합니다.",

    # ── Social ──────────────────────────────────────────────────────────────────────────────────
    "Away": "자리 비움",
    "Busy": "다른 용무 중",
    "Cancel Extend": "연장 취소",
    "Enter a note for %s:": "%s에 대한 메모를 입력하십시오:",
    "Extend": "연장",
    "Extended": "연장됨",
    "ID: %s": "ID: %s",
    "Instance": "인스턴스",
    "Modern friends window (Friends / Ignore / Who) with a Guild tab.":
        "길드 탭이 있는 현대적인 친구 창입니다 (친구 / 차단 / 검색).",
    "Promote to Assistant": "부관으로 승급",
    "Promote to Raid Leader": "공격대장으로 승급",
    "Resets In": "초기화까지",
    "Set Note": "메모 설정",
    "You are not saved to any instances.": "저장된 인스턴스가 없습니다.",

    # ── Spellbook ───────────────────────────────────────────────────────────────────────────────
    "Spellbook": "주문서",
    "The modern Dragonflight spellbook window. Disable to keep the stock Blizzard spellbook.":
        "현대적인 용의 군단 스타일 주문서 창입니다. 끄면 기본 블리자드 주문서를 유지합니다.",

    # ── Talents ─────────────────────────────────────────────────────────────────────────────────
    "  %s: have %d, build wants %d": "  %s: 현재 %d점, 구성에 필요한 점수 %d점",
    "%s\\n\\nImport anyway?": "%s\\n\\n그래도 가져오시겠습니까?",
    "ACTIVE EFFECTS": "지속 중인 효과",
    "Activate": "활성화",
    "Copy this build string (Ctrl+C). Talented & the WoWhead/wotlkdb calculators import it too:":
        "이 구성 문자열을 복사하십시오 (Ctrl+C). Talented와 WoWhead/wotlkdb 계산기에서도 가져올 수 "
        "있습니다:",
    "Delete loadout '%s'?": "구성 '%s'을(를) 삭제하시겠습니까?",
    "GLYPHS": "문양",
    "Glyph options": "문양 설정",
    "Glyphs": "문양",
    "Import…": "가져오기…",
    "Loadouts": "구성",
    "Locked": "잠김",
    "MAJOR GLYPHS": "주요 문양",
    "MINOR GLYPHS": "보조 문양",
    "NO ACTIVE EFFECTS": "지속 중인 효과 없음",
    "Name this imported loadout:": "가져온 구성의 이름:",
    "Name this loadout (saves your current spec):": "이 구성의 이름 (현재 특성을 저장합니다):",
    "Paste a talent string or calculator URL (Talented / WoWhead / wotlkdb):":
        "특성 문자열 또는 계산기 주소를 붙여넣으십시오 (Talented / WoWhead / wotlkdb):",
    "Pet": "소환수",
    "Remove this glyph?": "이 문양을 제거하시겠습니까?",
    "Rename loadout:": "구성 이름 변경:",
    "Rename specialization": "특성 이름 변경",
    "Rename this specialization (letters only, max %d):":
        "이 특성의 이름을 변경합니다 (글자만, 최대 %d자):",
    "Save current spec…": "현재 특성 저장…",
    "Server uses custom talents": "서버가 변경된 특성을 사용함",
    "Show glyph effects": "문양 효과 표시",
    "Show glyph names": "문양 이름 표시",
    "Tags exported builds with this realm so imports onto other layouts warn first.":
        "내보낸 구성에 이 서버를 표시하여 다른 배치로 가져올 때 먼저 경고하도록 합니다.",
    "Talents Panel": "특성 창",
    "The modern talents window. Turn off to use the standard Blizzard talent window.":
        "현대적인 특성 창입니다. 끄면 기본 블리자드 특성 창을 사용합니다.",
    "This loadout has fewer points in some talents than you've already spent, so it needs a respec "
    "first:\\n":
        "이 구성은 일부 특성의 점수가 이미 투자한 점수보다 적으므로 먼저 특성을 초기화해야 합니다:\\n",
    "Toggle slot name labels and the active-effects list.":
        "칸 이름 표시와 지속 효과 목록을 전환합니다.",
    "Unlock Spec": "특성 잠금 해제",
    "\\n\\nReset at a class trainer, then load again. (The rest has been staged — click Apply to learn it.)":
        "\\n\\n직업 교관에게서 초기화한 뒤 다시 불러오십시오. (나머지는 준비되어 있습니다 — '적용'을 "
        "누르면 배웁니다.)",

    # ── Options panel ───────────────────────────────────────────────────────────────────────────
    "Adventure Guide (Encounter Journal)": "모험 안내서 (전투 기록)",
    "Auction House": "경매장",
    "Boss and loot browser. Requires a /reload to take effect (the micro button doesn't re-check this "
    "live).":
        "우두머리와 전리품 탐색기입니다. 적용하려면 /reload가 필요합니다 (작은 버튼은 이 값을 실시간으로 "
        "다시 확인하지 않습니다).",
    "Click for this frame's settings.": "클릭하면 이 창의 설정이 열립니다.",
    "Combined Bag": "통합 가방",
    "Custom": "사용자 지정",
    "Custom scale": "사용자 지정 크기",
    "Drag to move.": "끌어서 이동합니다.",
    "Each window's size: \\\"Use UI scale\\\" follows the game's UI Scale slider, \\\"No scaling\\\" "
    "stays pixel-perfect, \\\"Custom\\\" uses its slider. The custom slider is greyed out and locked "
    "unless that window's mode is set to Custom.":
        "각 창의 크기입니다: \"UI 크기 사용\"은 게임의 UI 크기 슬라이더를 따르고, \"크기 조절 안 함\"은 "
        "픽셀 단위로 정확하게 유지하며, \"사용자 지정\"은 자체 슬라이더를 사용합니다. 해당 창의 모드가 "
        "'사용자 지정'이 아니면 사용자 지정 슬라이더는 흐려지고 잠깁니다.",
    "Guild": "길드",
    "Looking For Group": "파티 찾기",
    "Looking For Group (Dungeon/Raid Finder)": "파티 찾기 (던전/공격대 찾기)",
    "NewEra panels ported onto DragonUI. Toggle a panel below to enable or disable it. Panels appear "
    "here as their modules load.":
        "DragonUI로 이식된 NewEra 창입니다. 아래에서 창을 켜거나 끌 수 있습니다. 창은 해당 모듈이 로드되면 "
        "여기에 나타납니다.",
    "No scaling": "크기 조절 안 함",
    "Our all-in-one bag window. Turn OFF to use the stock Blizzard bags instead. Reload (/reload) to "
    "apply.":
        "이 애드온의 일체형 가방 창입니다. 끄면 기본 블리자드 가방을 사용합니다. 적용하려면 /reload "
        "하십시오.",
    "Professions": "전문 기술",
    "Reload (/reload) to apply.": "적용하려면 /reload 하십시오.",
    "Scale mode": "크기 모드",
    "Scaling controls are unavailable: the 'core\\\\Scale.lua' file isn't loaded. Make sure your "
    "installed DragonUI_NewEra includes core/Scale.lua AND its line in the .toc, then /reload.":
        "크기 설정을 사용할 수 없습니다: 'core\\Scale.lua' 파일이 로드되지 않았습니다. 설치된 "
        "DragonUI_NewEra에 core/Scale.lua와 .toc의 해당 줄이 모두 있는지 확인한 뒤 /reload 하십시오.",
    "Scaling controls need a newer DragonUI options panel (AddSlider/AddDropdown).":
        "크기 설정에는 더 새로운 DragonUI 설정 창이 필요합니다 (AddSlider/AddDropdown).",
    "Social": "친구",
    "Social (Friends/Who/Guild/Chat/Raid)": "친구 (친구/검색/길드/대화/공격대)",
    "Use DragonUI's window in place of the Blizzard default. Changes take effect after a /reload.":
        "블리자드 기본 창 대신 DragonUI의 창을 사용합니다. 변경 사항은 /reload 후에 적용됩니다.",
    "Use UI scale": "UI 크기 사용",
    "Window Scaling": "창 크기 조절",
    "Windows": "창",

    # ── Shared UI ───────────────────────────────────────────────────────────────────────────────
    "Select All": "모두 선택",
}
