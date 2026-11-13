class_name Items
extends RefCounted
## 가방에 들어가는 먹거리 데이터와 땅에 놓인 모양.
## 곡물 구성은 『농사직설』(1429) 항목(삼·벼·기장과 조·피·콩과 팥·보리와 밀·참깨·메밀)과
## 15세기 밭농사에서 흔했던 작목(기장, 콩, 벼, 보리, 피)을 따른다(docs/고증_근거.md 32장). 감자·고구마·옥수수·고추는
## 16세기 이후에 들어와 넣지 않았다. 도토리·밤·칡뿌리는 흉년에 먹던 구황 식물로 [추정]이다.
## 가중치(w), 배고픔 회복량(raw/cook), 마음 변화는 모두 설계값이다.

## 가방 칸 순서
const ORDER: Array[String] = ["gijang", "kong", "byeo", "bori", "pi", "jo", "pat", "mil", "memil", "nokdu", "dotori", "bam", "chik", "dallae", "naengi", "ssuk", "gosari", "minari", "pa", "buchu", "doraji", "deodeok", "mu", "maneul", "meoru", "darae", "ppalgi", "odi", "gam", "daechu", "dolbae", "oi", "gaji", "bak", "gaeam", "jat", "songi", "seogi", "pyogo", "meat_deer", "meat_boar", "meat_wolf", "meat_tiger", "meat_pheasant", "meat_pigeon", "meat_duck", "meat_sparrow", "yukpo"]

const DEFS := {
	"gijang": {"name": "기장", "hanja": "黍", "kind": "grain", "w": 24, "raw": 9, "cook": 44, "morale": 6, "shape": "sheaf", "head": "nod", "col": Color(0.88, 0.76, 0.36),
		"desc": "15세기 밭농사에서 가장 널리 심던 곡식. 밥이나 죽을 쑤어 먹는다.",
		"cook_msg": "기장죽을 쑤어 먹었다. 구수하고 속이 든든하다.", "raw_msg": "기장 알갱이를 씹어 삼켰다. 불에 익히면 더 낫다."},
	"kong": {"name": "콩", "hanja": "大豆", "kind": "grain", "w": 20, "raw": 12, "cook": 38, "morale": 5, "shape": "beans", "col": Color(0.86, 0.78, 0.5),
		"desc": "밥에 두어 먹고 장을 담그는 귀한 곡식. 삶으면 힘이 난다.",
		"cook_msg": "콩을 삶아 먹었다. 기운이 돋는다.", "raw_msg": "날콩을 씹었다. 비릿하고 단단하다."},
	"byeo": {"name": "쌀", "hanja": "稻", "kind": "grain", "w": 12, "raw": 10, "cook": 56, "morale": 12, "shape": "sheaf", "head": "nod", "col": Color(0.9, 0.78, 0.32),
		"desc": "벼의 낟알. 흰쌀밥은 가장 귀한 끼니다.",
		"cook_msg": "쌀밥을 지어 먹었다. 오랜만의 흰밥에 마음이 풀린다.", "raw_msg": "쌀알을 씹었다. 날로는 영 맛이 없다."},
	"bori": {"name": "보리", "hanja": "大麥", "kind": "grain", "w": 16, "raw": 9, "cook": 46, "morale": 5, "shape": "sheaf", "head": "ear", "col": Color(0.8, 0.76, 0.4),
		"desc": "쌀이 떨어진 철을 넘기게 해 주는 곡식. 보리밥은 거칠지만 든든하다.",
		"cook_msg": "보리밥을 지어 먹었다. 거칠어도 배가 찬다.", "raw_msg": "보리 알갱이를 씹었다. 껍질이 까끌하다."},
	"pi": {"name": "피", "hanja": "稷", "kind": "grain", "w": 10, "raw": 8, "cook": 38, "morale": 3, "shape": "sheaf", "head": "nod", "col": Color(0.72, 0.64, 0.34),
		"desc": "척박한 땅에서도 자라는 곡식. 흉년에 요긴하다.",
		"cook_msg": "피죽을 쑤어 먹었다. 맛은 없어도 허기는 가신다.", "raw_msg": "피 알갱이를 씹었다. 쓰고 거칠다."},
	"jo": {"name": "조", "hanja": "粟", "kind": "grain", "w": 8, "raw": 9, "cook": 42, "morale": 5, "shape": "sheaf", "head": "nod", "col": Color(0.9, 0.62, 0.2),
		"desc": "알이 작고 노란 곡식. 조밥은 옛날부터 먹었다.",
		"cook_msg": "조밥을 지어 먹었다. 포슬포슬하다.", "raw_msg": "좁쌀을 씹었다. 입안이 깔깔하다."},
	"pat": {"name": "팥", "hanja": "小豆", "kind": "grain", "w": 4, "raw": 8, "cook": 34, "morale": 7, "shape": "beans", "col": Color(0.55, 0.16, 0.12),
		"desc": "붉은 콩. 죽을 쑤면 달고 든든하다.",
		"cook_msg": "팥죽을 쑤어 먹었다. 따뜻하고 달큰하다.", "raw_msg": "날팥을 씹었다. 떫고 딱딱하다."},
	"mil": {"name": "밀", "hanja": "小麥", "kind": "grain", "w": 3, "raw": 9, "cook": 40, "morale": 5, "shape": "sheaf", "head": "ear", "col": Color(0.82, 0.66, 0.36),
		"desc": "보리와 함께 심는 곡식. 가루 내어 먹는다.",
		"cook_msg": "밀을 갈아 수제비를 떠 먹었다. 속이 풀린다.", "raw_msg": "밀알을 씹었다. 질기다."},
	"memil": {"name": "메밀", "hanja": "蕎麥", "kind": "grain", "w": 2, "raw": 8, "cook": 40, "morale": 6, "shape": "beans", "col": Color(0.3, 0.22, 0.16),
		"desc": "거친 땅에서도 빨리 자라는 곡식. 묵이나 국수로 먹는다.",
		"cook_msg": "메밀묵을 쑤어 먹었다. 담백하다.", "raw_msg": "메밀 낟알을 씹었다. 쓰고 거칠다."},
	"nokdu": {"name": "녹두", "hanja": "菉豆", "kind": "grain", "w": 1, "raw": 8, "cook": 34, "morale": 6, "shape": "beans", "col": Color(0.5, 0.62, 0.3),
		"desc": "작고 푸른 콩. 죽을 쑤어 먹는다.",
		"cook_msg": "녹두죽을 쑤어 먹었다. 순하고 속이 편하다.", "raw_msg": "날녹두를 씹었다. 비릿하다."},
	"dotori": {"name": "도토리", "hanja": "橡實", "kind": "wild", "w": 10, "raw": 5, "cook": 30, "morale": 3, "shape": "nuts", "col": Color(0.5, 0.32, 0.16), "cap": true, "sting": 2,
		"desc": "숲에서 줍는 구황 열매. 날것은 떫어 탈이 나고, 익히면 먹을 만하다.",
		"cook_msg": "도토리를 구워 으깨 먹었다. 떫은맛이 가셨다.", "raw_msg": "날도토리를 씹었다. 떫어서 배가 쓰리다."},
	"bam": {"name": "밤", "hanja": "栗", "kind": "wild", "w": 8, "raw": 16, "cook": 28, "morale": 6, "shape": "nuts", "col": Color(0.36, 0.2, 0.1), "cap": false, "sting": 0,
		"desc": "산에서 줍는 열매. 날로도 먹고 구우면 고소하다.",
		"cook_msg": "밤을 구워 먹었다. 고소하고 달다.", "raw_msg": "밤을 까서 날로 먹었다. 달큰하다."},
	"chik": {"name": "칡뿌리", "hanja": "葛根", "kind": "wild", "w": 8, "raw": 12, "cook": 26, "morale": 3, "shape": "root", "col": Color(0.66, 0.5, 0.32), "sting": 0,
		"desc": "산비탈에서 캐는 뿌리. 씹으면 즙이 나오고 구우면 부드럽다.",
		"cook_msg": "칡뿌리를 구워 먹었다. 은근히 달다.", "raw_msg": "칡뿌리를 씹어 즙을 삼켰다. 쌉쌀하다."},
	"dallae": {"name": "달래", "hanja": "野蒜", "kind": "wild", "w": 6, "raw": 7, "cook": 18, "morale": 3, "shape": "greens", "col": Color(0.55, 0.72, 0.3), "sting": 0,
		"desc": "산자락 양지에 나는 매콤한 작은 알뿌리 나물.",
		"cook_msg": "달래를 데쳐 무쳐 먹었다. 알싸하고 향긋하다.", "raw_msg": "달래를 씹었다. 맵고 알싸하다."},
	"naengi": {"name": "냉이", "hanja": "薺", "kind": "wild", "w": 6, "raw": 6, "cook": 20, "morale": 3, "shape": "greens", "col": Color(0.42, 0.6, 0.28), "sting": 0,
		"desc": "이른 봄 들길에 먼저 올라오는 나물. 국을 끓이면 향이 좋다.",
		"cook_msg": "냉이국을 끓여 먹었다. 구수하고 향긋하다.", "raw_msg": "냉이를 씹었다. 쌉쌀하다."},
	"ssuk": {"name": "쑥", "hanja": "艾", "kind": "wild", "w": 6, "raw": 5, "cook": 20, "morale": 4, "shape": "greens", "col": Color(0.5, 0.62, 0.4), "sting": 0,
		"desc": "어디서나 나는 향 짙은 풀. 국이나 떡에 넣는다.",
		"cook_msg": "쑥국을 끓여 먹었다. 향이 짙고 속이 따뜻해진다.", "raw_msg": "쑥을 씹었다. 쓰고 향이 강하다."},
	"gosari": {"name": "고사리", "hanja": "蕨", "kind": "wild", "w": 5, "raw": 3, "cook": 22, "morale": 3, "shape": "greens", "col": Color(0.4, 0.5, 0.22), "sting": 3,
		"desc": "산비탈에서 꺾는 어린 순. 날로는 독성이 있어 반드시 삶아 먹는다.",
		"cook_msg": "고사리를 삶아 나물로 먹었다. 부드럽고 구수하다.", "raw_msg": "날고사리를 씹었다. 아리고 속이 불편하다."},
	"minari": {"name": "미나리", "hanja": "水芹", "kind": "wild", "w": 6, "raw": 6, "cook": 18, "morale": 3, "shape": "greens", "col": Color(0.35, 0.62, 0.3), "sting": 0,
		"desc": "논둑과 물가에서 자라는 향 좋은 나물.",
		"cook_msg": "미나리를 데쳐 먹었다. 아삭하고 향긋하다.", "raw_msg": "미나리를 씹었다. 풋내가 상큼하다."},
	"pa": {"name": "파", "hanja": "蔥", "kind": "veg", "w": 7, "raw": 6, "cook": 16, "morale": 2, "shape": "greens", "col": Color(0.46, 0.68, 0.3), "sting": 0,
		"desc": "밭에 심는 양념 채소. 국에 넣으면 맛이 난다.",
		"cook_msg": "파를 넣어 끓여 먹었다. 달큰하고 구수하다.", "raw_msg": "파를 씹었다. 맵다."},
	"buchu": {"name": "부추", "hanja": "韭", "kind": "veg", "w": 6, "raw": 6, "cook": 18, "morale": 3, "shape": "greens", "col": Color(0.4, 0.66, 0.3), "sting": 0,
		"desc": "밭 귀퉁이에서 자주 베는 푸성귀.",
		"cook_msg": "부추를 데쳐 먹었다. 향이 은근하다.", "raw_msg": "부추를 씹었다. 맵고 풋내가 난다."},
	"doraji": {"name": "도라지", "hanja": "桔梗", "kind": "wild", "w": 5, "raw": 8, "cook": 30, "morale": 4, "shape": "root", "col": Color(0.92, 0.88, 0.78), "sting": 1,
		"desc": "산에서 캐는 하얀 뿌리. 쌉쌀하고 구우면 구수하다.",
		"cook_msg": "도라지를 구워 먹었다. 쌉쌀하고 고소하다.", "raw_msg": "도라지를 씹었다. 쓰고 아리다."},
	"deodeok": {"name": "더덕", "hanja": "沙蔘", "kind": "wild", "w": 5, "raw": 9, "cook": 32, "morale": 5, "shape": "root", "col": Color(0.84, 0.74, 0.56), "sting": 0,
		"desc": "깊은 산 그늘에서 덩굴을 타고 자라는 향 짙은 뿌리.",
		"cook_msg": "더덕을 구워 먹었다. 향이 진하고 달다.", "raw_msg": "더덕을 씹었다. 향은 좋으나 진이 끈적인다."},
	"mu": {"name": "무", "hanja": "蘿蔔", "kind": "veg", "w": 7, "raw": 12, "cook": 28, "morale": 3, "shape": "root", "col": Color(0.94, 0.94, 0.9), "sting": 0,
		"desc": "밭에서 뽑는 통통한 무. 국이나 김치에 쓴다.",
		"cook_msg": "무를 삶아 먹었다. 달고 시원하다.", "raw_msg": "무를 씹었다. 아삭하고 매콤하다."},
	"maneul": {"name": "마늘", "hanja": "蒜", "kind": "veg", "w": 5, "raw": 5, "cook": 20, "morale": 2, "shape": "root", "col": Color(0.95, 0.93, 0.86), "sting": 1,
		"desc": "밭에 심는 알뿌리 양념. 맵고 향이 강하다.",
		"cook_msg": "마늘을 구워 먹었다. 맵던 맛이 달아진다.", "raw_msg": "마늘을 씹었다. 몹시 맵다."},
	"meoru": {"name": "머루", "hanja": "山葡萄", "kind": "wild", "w": 6, "raw": 14, "cook": 18, "morale": 6, "shape": "berry", "col": Color(0.22, 0.1, 0.3), "sting": 0,
		"desc": "산 덩굴에 달리는 검붉은 야생 포도.",
		"cook_msg": "머루를 졸여 먹었다. 달고 새콤하다.", "raw_msg": "머루를 따 먹었다. 새콤달콤하다."},
	"darae": {"name": "다래", "hanja": "軟棗", "kind": "wild", "w": 6, "raw": 14, "cook": 18, "morale": 6, "shape": "berry", "col": Color(0.5, 0.66, 0.26), "sting": 0,
		"desc": "산골짜기 덩굴에 열리는 작은 열매. 새콤달콤하다.",
		"cook_msg": "다래를 졸여 먹었다. 새콤하고 부드럽다.", "raw_msg": "다래를 따 먹었다. 새콤달콤하다."},
	"ppalgi": {"name": "산딸기", "hanja": "覆盆子", "kind": "wild", "w": 6, "raw": 11, "cook": 14, "morale": 6, "shape": "berry", "col": Color(0.8, 0.1, 0.14), "sting": 0,
		"desc": "산길가 가시덤불에 열리는 붉은 열매.",
		"cook_msg": "산딸기를 졸여 먹었다. 달고 새콤하다.", "raw_msg": "산딸기를 따 먹었다. 새콤하다."},
	"odi": {"name": "오디", "hanja": "桑椹", "kind": "wild", "w": 5, "raw": 12, "cook": 16, "morale": 6, "shape": "berry", "col": Color(0.2, 0.08, 0.2), "sting": 0,
		"desc": "뽕나무에 열리는 검붉은 열매. 입안이 까맣게 물든다.",
		"cook_msg": "오디를 졸여 먹었다. 달콤하다.", "raw_msg": "오디를 따 먹었다. 달고 입이 까매진다."},
	"gam": {"name": "감", "hanja": "柿", "kind": "wild", "w": 5, "raw": 18, "cook": 24, "morale": 8, "shape": "fruit", "col": Color(0.94, 0.5, 0.14), "sting": 0,
		"desc": "마을 어귀 감나무의 주황빛 열매. 말리면 곶감이 된다.",
		"cook_msg": "감을 쪄 먹었다. 달고 쫀득하다.", "raw_msg": "감을 베어 물었다. 달콤하나 떫은 맛이 남는다."},
	"daechu": {"name": "대추", "hanja": "棗", "kind": "wild", "w": 5, "raw": 14, "cook": 26, "morale": 6, "shape": "fruit", "col": Color(0.55, 0.15, 0.1), "sting": 0,
		"desc": "집 마당에 심는 붉은 열매. 달고 기운을 돋운다.",
		"cook_msg": "대추를 쪄 먹었다. 달고 든든하다.", "raw_msg": "대추를 씹었다. 달다."},
	"dolbae": {"name": "돌배", "hanja": "梨", "kind": "wild", "w": 4, "raw": 12, "cook": 22, "morale": 5, "shape": "fruit", "col": Color(0.7, 0.62, 0.3), "sting": 0,
		"desc": "산에서 자라는 작고 단단한 배. 떫으나 쪄 먹으면 달다.",
		"cook_msg": "돌배를 쪄 먹었다. 떫은 맛이 가시고 달다.", "raw_msg": "돌배를 베어 물었다. 시고 떫다."},
	"oi": {"name": "오이", "hanja": "黃瓜", "kind": "veg", "w": 6, "raw": 10, "cook": 14, "morale": 4, "shape": "fruit", "col": Color(0.3, 0.55, 0.2), "sting": 0, "long": true,
		"desc": "밭 덩굴에 열리는 긴 열매. 날로 먹어도 시원하다.",
		"cook_msg": "오이를 데쳐 먹었다. 시원하고 달다.", "raw_msg": "오이를 베어 물었다. 아삭하고 시원하다."},
	"gaji": {"name": "가지", "hanja": "茄", "kind": "veg", "w": 5, "raw": 6, "cook": 22, "morale": 3, "shape": "fruit", "col": Color(0.3, 0.12, 0.4), "sting": 0, "long": true,
		"desc": "보라빛 긴 열매. 쪄서 나물로 먹는다.",
		"cook_msg": "가지를 쪄 먹었다. 부드럽고 달큰하다.", "raw_msg": "가지를 베어 물었다. 떫고 밋밋하다."},
	"bak": {"name": "박", "hanja": "匏", "kind": "veg", "w": 5, "raw": 8, "cook": 24, "morale": 3, "shape": "fruit", "col": Color(0.86, 0.84, 0.62), "sting": 0,
		"desc": "초가 지붕 위에 열리는 둥근 박. 속을 삶아 먹는다.",
		"cook_msg": "박을 삶아 먹었다. 담백하고 부드럽다.", "raw_msg": "박을 갉아 먹었다. 밍밍하다."},
	"gaeam": {"name": "개암", "hanja": "榛", "kind": "wild", "w": 6, "raw": 14, "cook": 24, "morale": 4, "shape": "nuts", "col": Color(0.62, 0.46, 0.26), "sting": 0, "cap": false,
		"desc": "산기슭 개암나무에 달리는 고소한 열매.",
		"cook_msg": "개암을 구워 먹었다. 고소하고 든든하다.", "raw_msg": "개암을 까 먹었다. 고소하다."},
	"jat": {"name": "잣", "hanja": "海松子", "kind": "wild", "w": 4, "raw": 18, "cook": 22, "morale": 8, "shape": "nuts", "col": Color(0.88, 0.78, 0.5), "sting": 0, "cap": false,
		"desc": "깊은 산 잣나무 솔방울 속의 귀한 열매. 기름지고 든든하다.",
		"cook_msg": "잣을 볶아 먹었다. 기름지고 향이 짙다.", "raw_msg": "잣을 까 먹었다. 고소하고 기름지다."},
	"songi": {"name": "송이", "hanja": "松茸", "kind": "wild", "w": 2, "raw": 6, "cook": 28, "morale": 10, "shape": "mushroom", "col": Color(0.8, 0.7, 0.5), "sting": 1,
		"desc": "소나무 숲에서 나는 향 좋은 귀한 버섯.",
		"cook_msg": "송이를 구워 먹었다. 향이 그윽하다.", "raw_msg": "송이를 씹었다. 향은 좋으나 날것은 속이 불편하다."},
	"seogi": {"name": "석이버섯", "hanja": "石耳", "kind": "wild", "w": 3, "raw": 6, "cook": 22, "morale": 5, "shape": "mushroom", "col": Color(0.3, 0.26, 0.22), "sting": 1,
		"desc": "깎아지른 바위에 붙어 자라는 검은 버섯.",
		"cook_msg": "석이버섯을 데쳐 먹었다. 오독오독하다.", "raw_msg": "석이를 씹었다. 질기다."},
	"pyogo": {"name": "표고", "hanja": "香蕈", "kind": "wild", "w": 4, "raw": 6, "cook": 26, "morale": 6, "shape": "mushroom", "col": Color(0.5, 0.34, 0.2), "sting": 1,
		"desc": "참나무 그루터기에 돋는 갈색 버섯. 말려도 향이 좋다.",
		"cook_msg": "표고를 구워 먹었다. 쫄깃하고 향긋하다.", "raw_msg": "표고를 씹었다. 날것은 질기고 비릿하다."},
	"meat_deer": {"name": "사슴 고기", "hanja": "鹿肉", "kind": "meat", "w": 0, "raw": 6, "cook": 42, "morale": 9, "shape": "root", "col": Color(0.62, 0.18, 0.15), "sting": 4,
		"desc": "사슴의 넓적다리살. 기름기가 적고 부드러워 구우면 가장 맛이 좋다.",
		"cook_msg": "사슴 고기를 구워 먹었다. 담백하고 부드럽다.", "raw_msg": "날 사슴 고기를 씹었다. 비리고 속이 불편하다."},
	"meat_boar": {"name": "멧돼지 고기", "hanja": "猪肉", "kind": "meat", "w": 0, "raw": 6, "cook": 48, "morale": 8, "shape": "root", "col": Color(0.55, 0.14, 0.13), "sting": 5,
		"desc": "비계가 두툼한 멧돼지 고기. 구우면 기름이 흘러 든든하다.",
		"cook_msg": "멧돼지 고기를 구워 먹었다. 기름져서 힘이 솟는다.", "raw_msg": "날 멧돼지 고기를 씹었다. 누린내가 심하다."},
	"meat_wolf": {"name": "늑대 고기", "hanja": "狼肉", "kind": "meat", "w": 0, "raw": 3, "cook": 28, "morale": 1, "shape": "root", "col": Color(0.42, 0.12, 0.16), "sting": 7,
		"desc": "질기고 노린내가 심한 살. 먹을 것이 없을 때나 먹는다.",
		"cook_msg": "늑대 고기를 구워 먹었다. 질기고 노린내가 난다.", "raw_msg": "날 늑대 고기를 씹었다. 역하다."},
	"meat_tiger": {"name": "호랑이 고기", "hanja": "虎肉", "kind": "meat", "w": 0, "raw": 8, "cook": 55, "morale": 16, "shape": "root", "col": Color(0.5, 0.1, 0.1), "sting": 3,
		"desc": "산군(山君)의 고기. 힘이 솟는다고 하여 귀하게 여긴다.",
		"cook_msg": "호랑이 고기를 구워 먹었다. 온몸에 기운이 퍼진다.", "raw_msg": "날 호랑이 고기를 씹었다. 질기고 비리다."},
	"meat_pheasant": {"name": "꿩고기", "hanja": "雉肉", "kind": "meat", "w": 0, "raw": 5, "cook": 40, "morale": 9, "shape": "root", "col": Color(0.74, 0.4, 0.34), "sting": 3,
		"desc": "꿩의 가슴살. 살이 곱고 담백해 구이와 탕으로 널리 먹던 고기다.",
		"cook_msg": "꿩고기를 구워 먹었다. 담백하고 고소하다.", "raw_msg": "날 꿩고기를 씹었다. 비리다."},
	"meat_pigeon": {"name": "산비둘기 고기", "hanja": "鳩肉", "kind": "meat", "w": 0, "raw": 4, "cook": 28, "morale": 6, "shape": "root", "col": Color(0.7, 0.34, 0.32), "sting": 3,
		"desc": "산비둘기의 가슴살. 작지만 기름져서 구우면 든든하다.",
		"cook_msg": "산비둘기를 구워 먹었다. 고소하고 기름지다.", "raw_msg": "날 비둘기 고기를 씹었다. 비릿하다."},
	"meat_duck": {"name": "오리고기", "hanja": "鴨肉", "kind": "meat", "w": 0, "raw": 5, "cook": 38, "morale": 8, "shape": "root", "col": Color(0.68, 0.3, 0.28), "sting": 4,
		"desc": "강가 오리의 살. 기름기가 많아 구우면 향이 진하다.",
		"cook_msg": "오리고기를 구워 먹었다. 기름이 흐르고 진하다.", "raw_msg": "날 오리고기를 씹었다. 누린내가 난다."},
	"meat_sparrow": {"name": "참새 고기", "hanja": "雀肉", "kind": "meat", "w": 0, "raw": 2, "cook": 12, "morale": 3, "shape": "root", "col": Color(0.72, 0.38, 0.32), "sting": 1,
		"desc": "참새 한 마리의 살. 아주 작아서 요기만 된다.",
		"cook_msg": "참새를 꼬치에 구워 먹었다. 뼈째 오독오독 씹힌다.", "raw_msg": "날 참새 고기를 씹었다. 먹을 것이 없다."},
	"yukpo": {"name": "육포", "hanja": "脯", "kind": "meat", "w": 0, "raw": 32, "cook": 34, "morale": 6, "shape": "root", "col": Color(0.4, 0.2, 0.12), "sting": 0,
		"desc": "고기를 얇게 저며 불에 말린 포. 오래 두고 먹을 수 있다.",
		"cook_msg": "육포를 불에 데워 먹었다. 쫄깃하고 짭짤하다.", "raw_msg": "육포를 질겅질겅 씹었다. 짭짤하고 든든하다."},
}

## 익힌 음식 이름 (조리법은 일반적 조리법이며 사료 인용이 아니다)
const COOKED := {
	"gijang": "기장죽", "kong": "삶은 콩", "byeo": "쌀밥", "bori": "보리밥", "pi": "피죽", "jo": "조밥", "pat": "팥죽",
	"mil": "밀 수제비", "memil": "메밀묵", "nokdu": "녹두죽", "dotori": "구운 도토리", "bam": "군밤", "chik": "구운 칡뿌리", "dallae": "달래무침", "naengi": "냉이국", "ssuk": "쑥국", "gosari": "고사리나물", "minari": "미나리무침", "pa": "파국", "buchu": "부추무침", "doraji": "구운 도라지", "deodeok": "더덕구이", "mu": "무국", "maneul": "구운 마늘", "meoru": "머루 조림", "darae": "다래 조림", "ppalgi": "산딸기 조림", "odi": "오디 조림", "gam": "찐 감", "daechu": "찐 대추", "dolbae": "찐 돌배", "oi": "데친 오이", "gaji": "가지찜", "bak": "박나물", "gaeam": "구운 개암", "jat": "볶은 잣", "songi": "송이구이", "seogi": "석이 무침", "pyogo": "표고구이", "meat_deer": "구운 사슴 고기", "meat_boar": "구운 멧돼지 고기", "meat_wolf": "구운 늑대 고기", "meat_tiger": "구운 호랑이 고기", "meat_pheasant": "구운 꿩고기", "meat_pigeon": "구운 산비둘기", "meat_duck": "구운 오리고기", "meat_sparrow": "참새구이", "yukpo": "데운 육포",
}

## 조리 방식: pot 솥에 끓이기(곡식·콩), roast 잿불에 묻어 굽기(밤·도토리), skewer 꼬치에 꿰어 굽기(칡뿌리)
static func cook_style(id: String) -> String:
	match id:
		"dotori", "bam", "gaeam", "jat", "maneul":
			return "roast"
		"chik", "doraji", "deodeok", "songi", "pyogo", "meat_deer", "meat_boar", "meat_wolf", "meat_tiger", "meat_pheasant", "meat_pigeon", "meat_duck", "meat_sparrow":
			return "skewer"
	return "pot"


## 한 개를 익히는 데 걸리는 초 (설계값)
static func cook_time(id: String) -> float:
	match cook_style(id):
		"roast":
			return 7.0
		"skewer":
			return 9.0
	return 12.0


## 여러 개를 한꺼번에 익힐 때 걸리는 시간: 첫 개는 그대로, 한 개 더할 때마다 35%씩 늘어난다.
static func batch_time(id: String, n: int) -> float:
	return cook_time(id) * (1.0 + 0.35 * float(maxi(n - 1, 0)))


static func cooked_name(id: String) -> String:
	return String(COOKED.get(id, String(def(id).get("name", id))))


static func cook_method(id: String) -> String:
	match cook_style(id):
		"roast":
			return "잿불에 묻어 굽기"
		"skewer":
			return "꼬치에 꿰어 굽기"
	return "솥에 안쳐 끓이기"


static func cook_doing(id: String) -> String:
	match cook_style(id):
		"roast":
			return "굽는 중"
		"skewer":
			return "굽는 중"
	return "끓이는 중"


## 가방 열쇠: 날것은 id, 익힌 것은 "c:id"
static func key_id(key: String) -> String:
	return key.substr(2) if key.begins_with("c:") else key


static func key_cooked(key: String) -> bool:
	return key.begins_with("c:")


## 어디서 얼마나 나는가: 민가 곁 / 밭 / 논(강가 벌) / 산
const POOLS := {
	"house": ["gijang", "kong", "bori", "pi", "jo", "pat", "byeo", "memil", "mu", "pa", "maneul", "buchu", "oi", "gaji", "bak", "gam", "daechu"],
	"field": ["gijang", "kong", "bori", "pi", "jo", "pat", "mil", "memil", "nokdu", "byeo", "mu", "pa", "maneul", "buchu", "oi", "gaji", "bak"],
	"paddy": ["byeo", "byeo", "byeo", "pi", "bori", "minari"],
	"wild": ["dotori", "bam", "chik", "dallae", "naengi", "ssuk", "gosari", "doraji", "deodeok", "meoru", "darae", "ppalgi", "odi", "dolbae", "gaeam", "jat", "songi", "seogi", "pyogo"],
}


static func def(id: String) -> Dictionary:
	return DEFS[id] if DEFS.has(id) else {}


static func roll(pool: String, rng: RandomNumberGenerator) -> String:
	var ids: Array = POOLS[pool]
	var total := 0
	for id in ids:
		total += int(DEFS[id]["w"])
	var r := rng.randi_range(0, total - 1)
	for id in ids:
		r -= int(DEFS[id]["w"])
		if r < 0:
			return String(id)
	return String(ids[0])


## 받침이 있으면 "을", 없으면 "를"
static func eul(word: String) -> String:
	if word.is_empty():
		return "을"
	var c := word.unicode_at(word.length() - 1)
	if c < 0xAC00 or c > 0xD7A3:
		return "을"
	return "을" if (c - 0xAC00) % 28 != 0 else "를"


# --- 땅에 놓인 모양 ---

static func make_node(id: String) -> Node3D:
	var d := def(id)
	var n := Node3D.new()
	var col: Color = d["col"]
	match String(d["shape"]):
		"sheaf":
			_sheaf(n, col, String(d["head"]))
		"beans":
			_beans(n, col)
		"nuts":
			_nuts(n, col, bool(d["cap"]))
		"root":
			_root(n, col)
		"berry":
			_berry(n, col)
		"greens":
			_greens(n, col)
		"mushroom":
			_mushroom(n, col)
		"fruit":
			_fruit(n, col, bool(d.get("long", false)))
	return n


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.visibility_range_end = 90.0
	parent.add_child(mi)
	return mi


## 묶은 곡식 단: 짚대 일곱 가닥과 이삭, 새끼 띠
static func _sheaf(n: Node3D, col: Color, head: String) -> void:
	var straw := Hanok.shared_mat(Color(0.72, 0.6, 0.32), 1.0)
	var hm := Hanok.shared_mat(col, 0.9)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var lean := 0.12
		var st := CylinderMesh.new()
		st.top_radius = 0.012
		st.bottom_radius = 0.016
		st.height = 0.8
		st.radial_segments = 5
		st.rings = 1
		var base := Vector3(cos(a) * 0.05, 0.4, sin(a) * 0.05)
		_mesh(n, st, straw, base, Vector3(sin(a) * lean, 0.0, -cos(a) * lean))
		var top := Vector3(cos(a) * 0.12, 0.78, sin(a) * 0.12)
		match head:
			"nod":
				var cp := CapsuleMesh.new()
				cp.radius = 0.028
				cp.height = 0.17
				cp.radial_segments = 6
				cp.rings = 2
				_mesh(n, cp, hm, top + Vector3(cos(a) * 0.05, -0.05, sin(a) * 0.05), Vector3(sin(a) * 0.9, 0.0, -cos(a) * 0.9))
			_:
				var cp2 := CapsuleMesh.new()
				cp2.radius = 0.02
				cp2.height = 0.16
				cp2.radial_segments = 6
				cp2.rings = 2
				_mesh(n, cp2, hm, top + Vector3(0.0, 0.04, 0.0), Vector3(sin(a) * 0.12, 0.0, -cos(a) * 0.12))
	var band := CylinderMesh.new()
	band.top_radius = 0.085
	band.bottom_radius = 0.085
	band.height = 0.05
	band.radial_segments = 8
	band.rings = 1
	_mesh(n, band, Hanok.shared_mat(Color(0.45, 0.34, 0.2), 1.0), Vector3(0.0, 0.3, 0.0))


## 나무 함지에 담긴 낟알 무더기 (콩·팥·메밀·녹두)
static func _beans(n: Node3D, col: Color) -> void:
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.24
	bowl.bottom_radius = 0.18
	bowl.height = 0.12
	bowl.radial_segments = 10
	bowl.rings = 1
	_mesh(n, bowl, Hanok.shared_mat(Color(0.36, 0.25, 0.15), 0.95), Vector3(0.0, 0.06, 0.0))
	var bm := Hanok.shared_mat(col, 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(col.r * 1000.0) + 17
	for i in 14:
		var sp := SphereMesh.new()
		sp.radius = 0.04
		sp.height = 0.07
		sp.radial_segments = 6
		sp.rings = 3
		var r := rng.randf() * 0.17
		var a := rng.randf() * TAU
		_mesh(n, sp, bm, Vector3(cos(a) * r, 0.14 + 0.08 * (1.0 - r / 0.17), sin(a) * r))


## 열매 몇 알 (도토리는 깍정이 모자가 있다)
static func _nuts(n: Node3D, col: Color, cap: bool) -> void:
	var nm := Hanok.shared_mat(col, 0.6)
	var cm := Hanok.shared_mat(Color(0.3, 0.2, 0.1), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(col.g * 1000.0) + 5
	for i in 5:
		var a := TAU * float(i) / 5.0 + rng.randf() * 0.5
		var r := 0.05 + rng.randf() * 0.11
		var p := Vector3(cos(a) * r, 0.05, sin(a) * r)
		var sp := SphereMesh.new()
		sp.radius = 0.05
		sp.height = 0.1 if cap else 0.085
		sp.radial_segments = 8
		sp.rings = 4
		_mesh(n, sp, nm, p)
		if cap:
			var hat := SphereMesh.new()
			hat.radius = 0.044
			hat.height = 0.05
			hat.radial_segments = 8
			hat.rings = 2
			_mesh(n, hat, cm, p + Vector3(0.0, 0.045, 0.0))


## 캐낸 칡뿌리: 굵은 뿌리와 가는 덩굴
static func _root(n: Node3D, col: Color) -> void:
	var rm := Hanok.shared_mat(col, 0.95)
	var c := CylinderMesh.new()
	c.top_radius = 0.045
	c.bottom_radius = 0.07
	c.height = 0.75
	c.radial_segments = 7
	c.rings = 1
	_mesh(n, c, rm, Vector3(0.0, 0.07, 0.0), Vector3(0.0, 0.5, PI * 0.5))
	var v := CylinderMesh.new()
	v.top_radius = 0.01
	v.bottom_radius = 0.012
	v.height = 0.5
	v.radial_segments = 4
	v.rings = 1
	_mesh(n, v, Hanok.shared_mat(Color(0.3, 0.42, 0.2), 1.0), Vector3(0.2, 0.1, 0.12), Vector3(0.3, 0.2, PI * 0.5 - 0.5))


## 덩굴 가지에 맺힌 열매 송이 (머루·다래·산딸기·오디)
static func _berry(n: Node3D, col: Color) -> void:
	var bm := Hanok.shared_mat(col, 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(col.r * 900.0) + int(col.b * 500.0) + 3
	var twig := CylinderMesh.new()
	twig.top_radius = 0.01
	twig.bottom_radius = 0.014
	twig.height = 0.34
	twig.radial_segments = 4
	twig.rings = 1
	_mesh(n, twig, Hanok.shared_mat(Color(0.34, 0.24, 0.12), 1.0), Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.0, PI * 0.5 - 0.3))
	for i in 7:
		var sp := SphereMesh.new()
		sp.radius = 0.04
		sp.height = 0.08
		sp.radial_segments = 6
		sp.rings = 3
		_mesh(n, sp, bm, Vector3(rng.randf_range(-0.14, 0.14), 0.08 + rng.randf() * 0.07, rng.randf_range(-0.08, 0.08)))


## 푸성귀 한 줌: 잎 다섯 장이 부채꼴로 솟는다 (나물·파·부추)
static func _greens(n: Node3D, col: Color) -> void:
	var gm := Hanok.shared_mat(col, 0.9)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var cp := CapsuleMesh.new()
		cp.radius = 0.022
		cp.height = 0.34
		cp.radial_segments = 5
		cp.rings = 1
		_mesh(n, cp, gm, Vector3(cos(a) * 0.05, 0.16, sin(a) * 0.05), Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5))
	var band := CylinderMesh.new()
	band.top_radius = 0.045
	band.bottom_radius = 0.045
	band.height = 0.03
	band.radial_segments = 6
	band.rings = 1
	_mesh(n, band, Hanok.shared_mat(Color(0.55, 0.42, 0.24), 1.0), Vector3(0.0, 0.06, 0.0))


## 버섯 세 송이
static func _mushroom(n: Node3D, col: Color) -> void:
	var cap_m := Hanok.shared_mat(col, 0.7)
	var stem_m := Hanok.shared_mat(Color(0.9, 0.86, 0.76), 0.8)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var p := Vector3(cos(a) * 0.09, 0.0, sin(a) * 0.09)
		var h := 0.1 + 0.03 * float(i)
		var st := CylinderMesh.new()
		st.top_radius = 0.02
		st.bottom_radius = 0.026
		st.height = h
		st.radial_segments = 6
		st.rings = 1
		_mesh(n, st, stem_m, p + Vector3(0.0, h * 0.5, 0.0))
		var cp := SphereMesh.new()
		cp.radius = 0.06
		cp.height = 0.06
		cp.radial_segments = 8
		cp.rings = 3
		_mesh(n, cp, cap_m, p + Vector3(0.0, h + 0.01, 0.0))


## 열매·박·오이·가지 몇 개 (long 이면 길쭉하게 눕는다)
static func _fruit(n: Node3D, col: Color, is_long: bool) -> void:
	var fm := Hanok.shared_mat(col, 0.5)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var p := Vector3(cos(a) * 0.1, 0.07, sin(a) * 0.1)
		if is_long:
			var cp := CapsuleMesh.new()
			cp.radius = 0.04
			cp.height = 0.26
			cp.radial_segments = 8
			cp.rings = 2
			_mesh(n, cp, fm, Vector3(p.x, 0.045, p.z), Vector3(0.0, a, PI * 0.5))
		else:
			var sp := SphereMesh.new()
			sp.radius = 0.075
			sp.height = 0.15
			sp.radial_segments = 8
			sp.rings = 4
			_mesh(n, sp, fm, p)
