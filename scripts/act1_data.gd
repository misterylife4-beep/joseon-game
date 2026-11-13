class_name Act1Data
## 1막(건국, 1392~1418) 데이터. 모든 등장 인물과 사건 세부는 허구다.
## pos의 x, z는 월드 좌표, y는 지면 위 높이(main.gd가 지형 높이를 더해 놓는다).

## "npc": true 인 증거는 월드에 구슬로 놓지 않고 NPC와 대화해서 얻는다.
const EVIDENCE: Array[Dictionary] = [
	{
		"id": "worker_ledger",
		"title": "도성 공사 인부 장부",
		"text": "공식 기록보다 훨씬 많은 인부의 이름이 적혀 있다. 일부는 끌려온 농민들이다.",
		"risk": 1,
		"truth": 1,
		"pos": Vector3(-165, 0.8, -25),
	},
	{
		"id": "mason_testimony",
		"title": "석공 우두머리의 증언",
		"text": "겨울에도 공사를 멈추지 못했다고 한다. 다친 사람은 이름도 남지 않았다.",
		"risk": 2,
		"truth": 2,
		"npc": true,
	},
	{
		"id": "burned_draft",
		"title": "불탄 사초 조각",
		"text": "누군가 사초를 태우려 했다. 남은 조각에는 궁 안의 밤에 대한 문장이 보인다.",
		"risk": 2,
		"truth": 2,
		"pos": Vector3(-3, 0.8, -100),
	},
	{
		"id": "torch_witness",
		"title": "횃불을 본 궁녀의 이야기",
		"text": "밤새 궁 안에서 횃불이 오갔다. 공식 기록에는 그 밤이 한 줄로만 남아 있다.",
		"risk": 3,
		"truth": 3,
		"npc": true,
	},
]

const NPCS: Array[Dictionary] = [
	{
		"id": "mason_manseok",
		"name": "석공 우두머리 만석",
		"pos": Vector3(-125, 0, -85),
		"color": Color(0.45, 0.4, 0.32),
		"gives": "mason_testimony",
		"lines": [
			"한양 도성이라니, 나리들은 큰일이라 하시지만 돌을 지는 우리는 하루하루가 버겁소.",
			"겨울에도 공사를 멈추지 못했소. 손이 얼어 터져도 쉴 수 없었지.",
			"다친 이들은 이름도 남기지 못하고 떠났소. 장부에 적히는 건 일한 날수뿐이오.",
			"당신이 적는 그 기록, 정말 어디에도 안 올라가는 거요? 그렇다면 내 이름 대신 이 이야기라도 남겨 주시오.",
		],
		"after": "할 이야기는 다 했소. 어서 돌아가 일이나 하시오.",
	},
	{
		"id": "palace_maid_yeon",
		"name": "궁녀 연이",
		"pos": Vector3(-58, 0, -122),
		"color": Color(0.7, 0.35, 0.45),
		"gives": "torch_witness",
		"lines": [
			"여기까지 오셨습니까. 목소리를 낮추어 주세요.",
			"그날 밤, 궁 안에는 횃불이 쉬지 않고 오갔습니다. 저는 문틈으로 보았을 뿐입니다.",
			"아침이 되자 모두 아무 일도 없었다는 듯 움직였지요. 입을 열면 안 된다는 걸 다들 알았습니다.",
			"그래도 누군가는 기억해야 하지 않겠습니까. 제가 본 것만 말씀드리겠습니다.",
		],
		"after": "더는 말씀드릴 수 없습니다. 부디 조심하세요.",
	},
]


static func evidence_by_id(id: String) -> Dictionary:
	for e in EVIDENCE:
		if e["id"] == id:
			return e.duplicate()
	return {}
