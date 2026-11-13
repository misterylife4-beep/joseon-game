class_name ActGoals
extends RefCounted
## 막(幕)별 주요 목표. 지도 화면 오른쪽에 보인다.
## 막의 이름과 때와 곳은 기획서(조선 팔도 생존기, 전국 맵 개정판)를 따른다. 목표 문구는 설계값이다.
## 진행은 user://act_goals.cfg 에 저장한다(새로 시작하면 지워진다). 1막의 증거 수집은 Records에서 직접 읽는다.

enum State { TODO, DONE }

const SAVE_PATH := "user://act_goals.cfg"

static var done: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in cf.get_section_keys("done"):
			done[k] = true


static func _save() -> void:
	var cf := ConfigFile.new()
	for k in done.keys():
		cf.set_value("done", String(k), true)
	cf.save(SAVE_PATH)

const ACTS: Array[Dictionary] = [
	{
		"name": "1막 성 쌓는 해", "when": "1396년 1~9월 · 한양", "open": true,
		"goals": [
			{"id": "a1_evidence", "text": "성안을 돌며 증거를 모은다"},
			{"id": "a1_written", "text": "J로 백지본을 열어 기록할 증거를 고른다"},
			{"id": "a1_finale", "text": "경복궁 터의 백지본에서 1막을 마무리한다"},
		],
		"later": "",
	},
	{
		"name": "2막 귀향길", "when": "1396년 10~11월 · 영남길", "open": true,
		"goals": [
			{"id": "a2_ferry", "text": "광나루에서 한강을 건넌다"},
			{"id": "a2_yangjae", "text": "양재 마을에 닿는다"},
			{"id": "a2_tiger", "text": "달래내 고개에서 범을 만나도 살아남는다"},
			{"id": "a2_pangyo", "text": "달래내 고개를 넘어 너덜이 마을에 닿는다"},
		],
		"later": "이어서: 용인 → 충주 → 계립령 → 상주 → 낙동강 → 동래 (길은 아직 만드는 중)",
	},
	{
		"name": "3막 불탄 고향", "when": "겨울 · 동래와 남해안", "open": false,
		"goals": [
			{"id": "a3_family", "text": "가족의 행방을 찾는다"},
			{"id": "a3_winter", "text": "폐허에서 겨울을 난다"},
			{"id": "a3_sea", "text": "왜구를 피해 바다에서 먹을 것을 구한다"},
		],
		"later": "",
	},
	{
		"name": "4막 팔도 유랑", "when": "1397년부터 · 전국", "open": false,
		"goals": [
			{"id": "a4_trace", "text": "가족의 흔적을 따라 전라도와 서해 뱃길로 간다"},
			{"id": "a4_north", "text": "서북면과 동북면까지 걸어간다"},
		],
		"later": "",
	},
]


static func mark(id: String) -> void:
	_ensure()
	if done.has(id):
		return
	done[id] = true
	_save()


static func reset() -> void:
	_ensure()
	done.clear()
	_save()


## 저장된 단계 표시가 있는가 (예: "a1_finale")
static func finished(id: String) -> bool:
	_ensure()
	return done.has(id)


## 막 i의 모든 목표를 마쳤는가
static func act_complete(i: int) -> bool:
	for g in ACTS[i]["goals"]:
		if not is_done(g):
			return false
	return true


## 막 i에서 아직 못 한 목표들
static func remaining(i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in ACTS[i]["goals"]:
		if not is_done(g):
			out.append(g)
	return out


## 구역에 들어설 때 호출한다.
static func on_zone(id: String) -> void:
	match id:
		"yangjae":
			mark("a2_yangjae")
		"dalnae", "cheonggye":
			mark("_dalnae")
		"pangyo":
			if done.has("_dalnae"):
				mark("a2_pangyo")


static func is_done(g: Dictionary) -> bool:
	_ensure()
	var id: String = g["id"]
	match id:
		"a1_evidence":
			return Records.order.size() >= Act1Data.EVIDENCE.size()
		"a1_written":
			for eid in Records.order:
				if bool((Records.evidence[eid] as Dictionary)["written"]):
					return true
			return false
	return done.has(id)


static func goal_text(g: Dictionary) -> String:
	var t: String = g["text"]
	if g["id"] == "a1_evidence":
		return "%s (%d/%d)" % [t, Records.order.size(), Act1Data.EVIDENCE.size()]
	return t


## 지금 하고 있는 막: 열린 막 가운데 끝나지 않은 첫 막. 모두 끝났으면 열린 마지막 막.
static func current_act() -> int:
	var last_open := 0
	for i in ACTS.size():
		var a: Dictionary = ACTS[i]
		if not bool(a["open"]):
			continue
		last_open = i
		for g in a["goals"]:
			if not is_done(g):
				return i
	return last_open
