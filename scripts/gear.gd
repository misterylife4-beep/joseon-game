class_name Gear
extends Node
## 연장과 무기. 산에서 주운 돌과 땔감으로 칼·도끼·곡괭이를 만들고, 손에 들어 휘두른다.
## 도끼는 나무를 베어 땔감을 얻고, 칼·도끼·곡괭이는 모두 야생 짐승과 싸우는 데 쓴다.
## 돌의 종류, 연장의 모양·힘·내구는 모두 설계값이다. 1396년에는 이미 철제 연장이 흔했으나,
## 이 게임에서는 막손이 맨몸으로 산에 들어선 처지를 살려 나무·돌 연장부터 만들게 했다(docs/고증_근거.md 50장).

signal changed

## 돌 종류: 서울 일대 산의 바위는 화강암(북한산·도봉산·관악산)과 편마암이 많고 석영 맥(차돌)이 곳곳에 있다. 부싯돌은 단단한 규질 돌. 분포는 [추정].
const STONES := {
	"granite": {"name": "화강암 돌", "w": 5, "col": Color(0.66, 0.63, 0.6), "desc": "산마루 바위에서 떨어진 둥글둥글한 돌. 단단하고 묵직하다."},
	"gneiss": {"name": "편마암 조각", "w": 3, "col": Color(0.42, 0.4, 0.43), "desc": "결이 줄무늬진 납작한 돌. 쪼개면 날이 선다."},
	"quartz": {"name": "차돌", "w": 2, "col": Color(0.93, 0.91, 0.84), "desc": "하얀 석영 돌. 단단하고 깨지면 날카롭다."},
	"chert": {"name": "부싯돌", "w": 1, "col": Color(0.26, 0.27, 0.3), "desc": "검푸른 단단한 돌. 부딪치면 불꽃이 튀고 날이 곱게 선다."},
}
const STONE_ORDER: Array[String] = ["granite", "gneiss", "quartz", "chert"]

## kind: knife 칼 / axe 도끼 / pick 곡괭이. dmg 짐승에게 주는 힘, chop 나무 베는 힘, dur 쓸 수 있는 횟수, time 한 번 휘두르는 초.
const TOOLS := {
	"wood_knife": {"name": "나무 칼", "kind": "knife", "dmg": 9.0, "chop": 0.0, "dur": 24, "time": 0.5, "wood": 2, "stone": 0,
		"desc": "단단한 가지를 깎아 날을 세운 칼. 가볍고 빠르지만 힘이 약하다."},
	"wood_axe": {"name": "나무 도끼", "kind": "axe", "dmg": 13.0, "chop": 1.0, "dur": 30, "time": 0.8, "wood": 3, "stone": 0,
		"desc": "굵은 가지 끝을 쐐기로 깎은 도끼. 나무를 천천히 벨 수 있다."},
	"wood_pick": {"name": "나무 곡괭이", "kind": "pick", "dmg": 8.0, "chop": 0.0, "dur": 30, "time": 0.8, "wood": 3, "stone": 0,
		"desc": "끝이 굽은 가지를 뾰족하게 깎은 곡괭이. 돌을 주울 때 더 많이 캔다."},
	"stone_knife": {"name": "돌칼", "kind": "knife", "dmg": 19.0, "chop": 0.0, "dur": 48, "time": 0.5, "wood": 1, "stone": 2,
		"desc": "깨진 돌날을 나무 자루에 덴 칼. 짐승과 싸울 만하다."},
	"stone_axe": {"name": "돌도끼", "kind": "axe", "dmg": 28.0, "chop": 1.8, "dur": 64, "time": 0.85, "wood": 2, "stone": 3,
		"desc": "돌날을 자루에 단단히 묶은 도끼. 나무도 잘 베고 짐승에게 큰 상처를 입힌다."},
	"stone_pick": {"name": "돌곡괭이", "kind": "pick", "dmg": 16.0, "chop": 0.0, "dur": 64, "time": 0.85, "wood": 2, "stone": 3,
		"desc": "뾰족한 돌을 자루에 묶은 곡괭이. 돌을 한꺼번에 여럿 캔다."},
	"wood_bow": {"name": "나무 활", "kind": "bow", "dmg": 4.0, "chop": 0.0, "dur": 90, "time": 0.5, "wood": 4, "stone": 0, "sinew": 1,
		"desc": "굵은 가지를 휘어 힘줄로 시위를 건 활. 좌클릭을 누르고 있으면 당기고, 떼면 쏜다."},
}
const TOOL_ORDER: Array[String] = ["wood_knife", "wood_axe", "wood_pick", "stone_knife", "stone_axe", "stone_pick", "wood_bow"]

## 짐승 가죽 (사냥하면 떨어진다)
const HIDES := {
	"hide_deer": {"name": "사슴 가죽", "col": Color(0.62, 0.42, 0.24)},
	"hide_boar": {"name": "멧돼지 가죽", "col": Color(0.27, 0.21, 0.17)},
	"hide_wolf": {"name": "늑대 가죽", "col": Color(0.52, 0.48, 0.42)},
	"hide_tiger": {"name": "호랑이 가죽", "col": Color(0.86, 0.5, 0.16)},
}
const HIDE_ORDER: Array[String] = ["hide_deer", "hide_boar", "hide_wolf", "hide_tiger"]
const MEATS: Array[String] = ["meat_deer", "meat_boar", "meat_wolf", "meat_tiger", "meat_pheasant", "meat_pigeon", "meat_duck", "meat_sparrow"]

## 옷과 살림. slot: head 머리, neck 목, body 몸, hands 손, feet 발, "" 입지 않고 지니기만 해도 되는 것.
## cost 의 hide 는 호랑이를 뺀 아무 가죽, tiger 는 호랑이 가죽, wolf 는 늑대 가죽, meat 는 아무 고기.
## cold 추위 줄임, cut 입는 피해 줄임, stam 달릴 때 기력 아낌, morale 마음 보탬(비율이 아니라 마음 목표값에 더한다). 값은 모두 설계값.
## 갖신(가죽신), 갖옷(짐승 털가죽 옷), 휘항(귀·목을 덮는 방한모), 토시, 호피(虎皮, 관아 의자 덮개), 포(脯, 말린 고기)는 조선 시대에도 쓴 말이다. [사료]
const GOODS := {
	"boots": {"name": "갖신", "cat": 1, "slot": "feet", "cost": {"hide": 2}, "cold": 0.08, "cut": 0.0, "stam": 0.12, "morale": 0.0,
		"desc": "가죽으로 지은 신. 발이 덜 시리고 달려도 덜 지친다."},
	"hands": {"name": "털 토시", "cat": 1, "slot": "hands", "cost": {"hide": 1}, "cold": 0.06, "cut": 0.03, "stam": 0.0, "morale": 0.0,
		"desc": "털가죽으로 만든 팔 덮개. 손목이 따뜻하고 물려도 덜 다친다."},
	"hat": {"name": "털 휘항", "cat": 1, "slot": "head", "cost": {"hide": 2}, "cold": 0.12, "cut": 0.05, "stam": 0.0, "morale": 0.0,
		"desc": "머리와 귀, 목을 덮는 털모자. 겨울 찬바람을 막는다."},
	"scarf": {"name": "늑대털 목도리", "cat": 1, "slot": "neck", "cost": {"wolf": 1}, "cold": 0.1, "cut": 0.0, "stam": 0.0, "morale": 2.0,
		"desc": "늑대 털가죽을 목에 두른다. 따뜻하고 으쓱해진다."},
	"coat": {"name": "갖옷", "cat": 1, "slot": "body", "cost": {"hide": 4}, "cold": 0.25, "cut": 0.12, "stam": 0.0, "morale": 0.0,
		"desc": "짐승 털가죽을 이어 지은 겉옷. 추위를 크게 막고 이빨도 조금 막는다."},
	"tigercoat": {"name": "호피 갖옷", "cat": 1, "slot": "body", "cost": {"tiger": 1, "hide": 2}, "cold": 0.32, "cut": 0.22, "stam": 0.0, "morale": 4.0,
		"desc": "호랑이 가죽으로 지은 갖옷. 가장 따뜻하고 단단하며, 입으면 담이 커진다."},
	"arrows": {"name": "화살 (5발)", "cat": 0, "slot": "", "cost": {"wood": 1, "feather": 2, "stone": 1}, "cold": 0.0, "cut": 0.0, "stam": 0.0, "morale": 0.0, "ammo": 5,
		"desc": "곧은 가지에 돌촉을 박고 깃을 단 화살 다섯 발. 활과 함께 쓴다."},
	"sack": {"name": "가죽 자루", "cat": 2, "slot": "", "cost": {"hide": 2}, "cold": 0.0, "cut": 0.0, "stam": 0.0, "morale": 0.0,
		"desc": "가죽을 박아 만든 자루. 지니고 있으면 곡식과 열매를 주울 때 가끔 하나 더 담는다."},
	"tigermat": {"name": "호피 깔개", "cat": 2, "slot": "", "cost": {"tiger": 1, "wood": 1}, "cold": 0.0, "cut": 0.0, "stam": 0.0, "morale": 6.0,
		"desc": "호랑이 가죽을 펴 말린 깔개. 지니고만 있어도 마음이 든든하다."},
	"yukpo": {"name": "육포 (2개)", "cat": 2, "slot": "", "cost": {"meat": 2, "wood": 1}, "cold": 0.0, "cut": 0.0, "stam": 0.0, "morale": 0.0, "give": "yukpo", "n": 2,
		"desc": "고기를 얇게 저며 불에 말린다. 날로 먹어도 탈이 없고 오래 둔다."},
}
const ARROWS_PER := 5
const CATS: Array[String] = ["연장·무기", "옷·방한", "살림·손질"]
const CAT_ORDER: Array = [
	["wood_knife", "stone_knife", "wood_axe", "stone_axe", "wood_pick", "stone_pick", "wood_bow", "arrows"],
	["boots", "hands", "hat", "scarf", "coat", "tigercoat"],
	["sack", "tigermat", "yukpo"],
]
const COST_NAME := {"feather": "깃털", "sinew": "힘줄", "wood": "땔감", "stone": "돌", "hide": "가죽", "tiger": "호랑이 가죽", "wolf": "늑대 가죽", "meat": "고기"}

const BOULDER_HP := 5.0     ## 큰 바위를 깨는 데 드는 힘(나무 곡괭이 1.0, 돌곡괭이 1.8). [설계]
const REACH := 2.3          ## 팔이 닿는 거리(m). 짐승 몸 크기를 더해 잰다.
const FIST_DMG := 3.0

## 가진 돌: 종류 id -> 개수
var stones: Dictionary = {}
## 가진 연장: id -> 남은 횟수
var tools: Dictionary = {}
var equipped := ""
## 가진 가죽: id -> 장
var hides: Dictionary = {}
## 만들어 가진 옷·살림: id -> true
var goods: Dictionary = {}
## 입고 있는 옷: 자리 -> id
var worn: Dictionary = {}
## 깃털, 힘줄(짐승 가죽을 벗길 때 나온다), 화살
var feathers := 0
var sinew := 0
var arrows := 0
var archery: Archery

var _player: Player
var _sv: Survival
var _hint: Label
var _hint_layer: CanvasLayer
var _held: Node3D
var _held_id := "?"
var _cd := 0.0
var _swing := -1.0
var _swing_len := 0.6
var _strike_done := false
var _sfx: AudioStreamPlayer
var _seen := -1
var _cm: ChunkManager
static var _mats: Dictionary = {}
## 사람이 마지막으로 휘두르기 시작한 때(ms). 짐승이 보고 비켜서는 데 쓴다.
static var swing_start_ms := -99999
var _combo := 0
var _last_swing_ms := -99999


func setup(player: Player, sv: Survival) -> void:
	_player = player
	_sv = sv
	_sv.gear = self
	_sv._add_key("cycle_tool", KEY_Q)
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 9
	add_child(_hint_layer)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_hint_layer.add_child(_hint)
	UiFlow.register(_hint, "ui_hint", 2)
	archery = Archery.new()
	add_child(archery)
	archery.setup(player, sv, self)
	_restyle()


# --- 돌 -----------------------------------------------------------------

static func roll_stone(rng: RandomNumberGenerator) -> String:
	var total := 0
	for id in STONE_ORDER:
		total += int(STONES[id]["w"])
	var r := rng.randi_range(0, total - 1)
	for id in STONE_ORDER:
		r -= int(STONES[id]["w"])
		if r < 0:
			return id
	return STONE_ORDER[0]


static func hide_name(id: String) -> String:
	return String(HIDES[id]["name"]) if HIDES.has(id) else id


static func stone_name(id: String) -> String:
	return String(STONES[id]["name"]) if STONES.has(id) else id


## 땅에 놓인 돌 모양: 작은 돌 두세 개
static func stone_node(id: String) -> Node3D:
	var n := Node3D.new()
	var col: Color = STONES[id]["col"] if STONES.has(id) else Color(0.6, 0.6, 0.6)
	var m := _mat("stone_" + id, col, 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + 7
	for i in 3:
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		sp.radial_segments = 8
		sp.rings = 5
		mi.mesh = sp
		mi.material_override = m
		var sz := rng.randf_range(0.13, 0.22) * (1.2 if i == 0 else 0.8)
		mi.scale = Vector3(sz, sz * rng.randf_range(0.5, 0.75), sz * rng.randf_range(0.7, 1.0))
		mi.position = Vector3(rng.randf_range(-0.18, 0.18), mi.scale.y * 0.3, rng.randf_range(-0.18, 0.18))
		mi.rotation.y = rng.randf() * TAU
		n.add_child(mi)
	return n


func add_stone(id: String) -> int:
	var n := 1
	if equipped != "" and String(TOOLS[equipped]["kind"]) == "pick":
		n = 3 if equipped.begins_with("stone") else 2
	stones[id] = int(stones.get(id, 0)) + n
	changed.emit()
	return n


func stone_total() -> int:
	var t := 0
	for k in stones:
		t += int(stones[k])
	return t


func _take_stones(n: int) -> void:
	var left := n
	for id in STONE_ORDER:
		var have := int(stones.get(id, 0))
		var use := mini(have, left)
		if use > 0:
			stones[id] = have - use
			if int(stones[id]) <= 0:
				stones.erase(id)
			left -= use
		if left <= 0:
			break


# --- 제작 ---------------------------------------------------------------

static func recipe(id: String) -> Dictionary:
	return TOOLS[id] if TOOLS.has(id) else GOODS[id]


## 재료 사전 (0인 것은 뺀다)
static func cost_of(id: String) -> Dictionary:
	if GOODS.has(id):
		return GOODS[id]["cost"]
	var d: Dictionary = TOOLS[id]
	var c := {}
	if int(d["wood"]) > 0:
		c["wood"] = int(d["wood"])
	if int(d["stone"]) > 0:
		c["stone"] = int(d["stone"])
	if int(d.get("sinew", 0)) > 0:
		c["sinew"] = int(d["sinew"])
	return c


func hide_total() -> int:
	var t := 0
	for id in ["hide_deer", "hide_boar", "hide_wolf"]:
		t += int(hides.get(id, 0))
	return t


func hide_count() -> int:
	return hide_total() + int(hides.get("hide_tiger", 0))


func meat_total() -> int:
	var t := 0
	for id in MEATS:
		t += int(_sv.items.get(id, 0))
	return t


func _have(kind: String) -> int:
	match kind:
		"feather":
			return feathers
		"sinew":
			return sinew
		"wood":
			return _sv.firewood
		"stone":
			return stone_total()
		"hide":
			return hide_total()
		"tiger":
			return int(hides.get("hide_tiger", 0))
		"wolf":
			return int(hides.get("hide_wolf", 0))
		"meat":
			return meat_total()
	return 0


func add_feather(n := 1) -> void:
	feathers += n
	changed.emit()


func add_sinew(n := 1) -> void:
	sinew += n
	changed.emit()


func add_arrows(n := 1) -> void:
	arrows += n
	_update_hint()
	changed.emit()


func add_hide(id: String, n := 1) -> void:
	hides[id] = int(hides.get(id, 0)) + n
	changed.emit()


func _take_hides(ids: Array, n: int) -> void:
	var left := n
	for id in ids:
		var have := int(hides.get(id, 0))
		var use := mini(have, left)
		if use > 0:
			hides[id] = have - use
			if int(hides[id]) <= 0:
				hides.erase(id)
			left -= use
		if left <= 0:
			break


func _take_meat(n: int) -> void:
	var left := n
	for id in MEATS:
		var have := int(_sv.items.get(id, 0))
		var use := mini(have, left)
		if use > 0:
			_sv.items[id] = have - use
			if int(_sv.items[id]) <= 0:
				_sv.items.erase(id)
			left -= use
		if left <= 0:
			break


## 만들 수 없는 까닭 (만들 수 있으면 빈 글)
func why_not(id: String) -> String:
	if tools.has(id) or (GOODS.has(id) and goods.has(id) and String(GOODS[id].get("give", "")) == ""):
		return "이미 가지고 있다"
	var c := cost_of(id)
	for k in c:
		if _have(String(k)) < int(c[k]):
			return "%s이(가) 모자라다" % String(COST_NAME[k])
	return ""


func craft(id: String) -> bool:
	var why := why_not(id)
	var d := recipe(id)
	if why != "":
		_sv._hud.toast("%s: %s." % [String(d["name"]), why], 2.0, "deny")
		return false
	var c := cost_of(id)
	for k in c:
		var n := int(c[k])
		match String(k):
			"feather":
				feathers -= n
			"sinew":
				sinew -= n
			"wood":
				_sv.firewood -= n
			"stone":
				_take_stones(n)
			"hide":
				_take_hides(["hide_deer", "hide_boar", "hide_wolf"], n)
			"tiger":
				_take_hides(["hide_tiger"], n)
			"wolf":
				_take_hides(["hide_wolf"], n)
			"meat":
				_take_meat(n)
	var nm := String(d["name"])
	if TOOLS.has(id):
		tools[id] = int(d["dur"])
		_sv._hud.toast("%s%s 만들었다. 손에 들고 좌클릭으로 휘두른다." % [nm, Items.eul(nm)], 3.0, "flint")
		if equipped == "":
			equip(id)
	elif int(d.get("ammo", 0)) > 0:
		arrows += int(d["ammo"])
		_sv._hud.toast("화살 %d발을 만들었다. (지닌 화살 %d발)" % [int(d["ammo"]), arrows], 2.6, "flint")
	elif String(d.get("give", "")) != "":
		var g := String(d["give"])
		_sv.items[g] = int(_sv.items.get(g, 0)) + int(d["n"])
		_sv._hud.toast("%s%s 만들었다. 가방에 넣었다." % [nm, Items.eul(nm)], 2.6, "flint")
	else:
		goods[id] = true
		_sv._hud.toast("%s%s 만들었다." % [nm, Items.eul(nm)], 2.6, "flint")
		var sl := String(d["slot"])
		if sl != "" and (not worn.has(sl) or _rank(id) > _rank(String(worn[sl]))):
			worn[sl] = id
			_sv._hud.toast("%s%s 입었다." % [nm, Items.eul(nm)], 2.0, "cloth")
	_sv.bag_changed.emit()
	changed.emit()
	return true


static func _rank(id: String) -> float:
	var d: Dictionary = GOODS[id]
	return float(d["cold"]) + float(d["cut"])


## 옷을 입거나 벗는다
func toggle_wear(id: String) -> void:
	if not goods.has(id):
		return
	var sl := String(GOODS[id]["slot"])
	if sl == "":
		return
	if worn.get(sl, "") == id:
		worn.erase(sl)
	else:
		worn[sl] = id
	changed.emit()


func has_good(id: String) -> bool:
	return goods.has(id)


func _sum(key: String) -> float:
	var t := 0.0
	for sl in worn:
		t += float(GOODS[String(worn[sl])][key])
	return t


## 추위를 줄이는 비율 (0~0.6)
func cold_resist() -> float:
	return clampf(_sum("cold"), 0.0, 0.6)


## 입는 피해를 줄이는 비율 (0~0.5)
func dmg_cut() -> float:
	return clampf(_sum("cut"), 0.0, 0.5)


## 달릴 때 기력을 아끼는 비율
func stam_save() -> float:
	return clampf(_sum("stam"), 0.0, 0.5)


## 마음 목표값에 더하는 값 (입은 옷 + 지닌 호피 깔개)
func morale_bonus() -> float:
	var t := _sum("morale")
	if goods.has("tigermat"):
		t += float(GOODS["tigermat"]["morale"])
	return t


func equip(id: String) -> void:
	if id != "" and not tools.has(id):
		return
	equipped = id
	_swing = -1.0
	_set_swing_pose(-1.0)
	_rebuild_held()
	_update_hint()
	changed.emit()


## Q: 가진 연장을 차례로 바꿔 든다 (맨손도 한 칸)
func cycle() -> void:
	var have: Array[String] = [""]
	for id in TOOL_ORDER:
		if tools.has(id):
			have.append(id)
	if have.size() <= 1:
		_sv._hud.toast("들 연장이 없다. 제작대에서 만들자.", 2.0, "deny")
		return
	var i := have.find(equipped)
	var nxt: String = have[(i + 1) % have.size()]
	equip(nxt)
	var nm := "맨손" if nxt == "" else String(TOOLS[nxt]["name"])
	_sv._hud.toast("손에 든 것: %s" % nm, 1.4, "tick")


func reset() -> void:
	stones.clear()
	tools.clear()
	hides.clear()
	goods.clear()
	worn.clear()
	feathers = 0
	sinew = 0
	arrows = 0
	equip("")


# --- 땅에 떨어진 고기와 가죽 (짐승마다 모양이 다르다. 모양과 색은 설계값) ---

static func _blob(parent: Node3D, mat: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 10
	sp.rings = 6
	mi.mesh = sp
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _slab(parent: Node3D, mat: Material, pos: Vector3, size: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func _bone(parent: Node3D, pos: Vector3, length: float, rot: Vector3, r := 0.018) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = _mat("bone", Color(0.9, 0.86, 0.74), 0.7)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


## 큰 바위: 둥근 돌덩이 서너 개를 겹친 모양과 충돌. 곡괭이로 깨면 돌이 여럿 나온다. 모양은 설계값.
static func boulder_node(seed: int) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var shades := [Color(0.55, 0.53, 0.5), Color(0.46, 0.45, 0.44), Color(0.62, 0.6, 0.56)]
	var base := rng.randf_range(0.9, 1.3)
	for i in 4:
		var m := _mat("boulder_%d" % (i % 3), shades[i % 3], 0.98)
		var sz := base * (1.0 if i == 0 else rng.randf_range(0.55, 0.8))
		var off := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
		var mi := _blob(n, m, off + Vector3(0.0, sz * 0.4, 0.0), Vector3(sz * 1.5, sz * 0.95, sz * 1.25))
		mi.rotation.y = rng.randf() * TAU
	# 흰 석영 줄무늬
	_slab(n, _mat("vein", Color(0.92, 0.9,0.84), 0.8), Vector3(0.1, base * 0.85, 0.1), Vector3(base * 0.9, 0.04, 0.05), rng.randf() * TAU)
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sh := SphereShape3D.new()
	sh.radius = base * 0.95
	cs.shape = sh
	cs.position = Vector3(0.0, base * 0.5, 0.0)
	body.add_child(cs)
	n.add_child(body)
	return n


## 고기: 사슴은 뼈 달린 넓적다리, 멧돼지는 비계 얹은 두툼한 덩이, 늑대는 갈빗대 붙은 가는 살, 호랑이는 흰 마블링의 큰 덩이
static func meat_node(meat_id: String) -> Node3D:
	var n := Node3D.new()
	match meat_id:
		"meat_deer":
			var m := _mat("m_deer", Color(0.62, 0.18, 0.15), 0.55)
			_blob(n, m, Vector3(0.0, 0.12, 0.0), Vector3(0.5, 0.26, 0.3))
			_bone(n, Vector3(0.36, 0.12, 0.0), 0.4, Vector3(0.0, 0.0, PI * 0.5))
			_blob(n, _mat("bone", Color(0.9, 0.86, 0.74), 0.7), Vector3(0.58, 0.12, 0.03), Vector3(0.08, 0.08, 0.08))
		"meat_boar":
			var m2 := _mat("m_boar", Color(0.55, 0.14, 0.13), 0.55)
			_slab(n, m2, Vector3(0.0, 0.07, 0.0), Vector3(0.5, 0.14, 0.32), 0.2)
			_slab(n, _mat("fat", Color(0.94, 0.82, 0.78), 0.6), Vector3(0.0, 0.16, 0.0), Vector3(0.5, 0.05, 0.32), 0.2)
			_bone(n, Vector3(0.0, 0.09, 0.2), 0.3, Vector3(0.0, 0.0, PI * 0.5))
		"meat_wolf":
			var m3 := _mat("m_wolf", Color(0.42, 0.12, 0.17), 0.6)
			_slab(n, m3, Vector3(0.0, 0.04, -0.05), Vector3(0.42, 0.07, 0.1))
			_slab(n, m3, Vector3(0.0, 0.04, 0.07), Vector3(0.42, 0.07, 0.1))
			for i in 4:
				_bone(n, Vector3(-0.16 + 0.1 * float(i), 0.09, 0.0), 0.3, Vector3(PI * 0.5, 0.0, 0.0), 0.013)
		"meat_pheasant", "meat_pigeon", "meat_duck", "meat_sparrow":
			# 새고기: 가슴살 두 쪽과 작은 다리뼈
			var bm := _mat("m_bird", Color(0.74, 0.4, 0.34), 0.55)
			var sc := 1.0 if meat_id == "meat_pheasant" or meat_id == "meat_duck" else (0.75 if meat_id == "meat_pigeon" else 0.45)
			_blob(n, bm, Vector3(-0.05 * sc, 0.06 * sc, 0.0), Vector3(0.2, 0.1, 0.14) * sc)
			_blob(n, bm, Vector3(0.05 * sc, 0.06 * sc, 0.0), Vector3(0.2, 0.1, 0.14) * sc)
			_bone(n, Vector3(0.0, 0.05 * sc, 0.12 * sc), 0.2 * sc, Vector3(PI * 0.5, 0.0, 0.0), 0.012)
		_:
			var m4 := _mat("m_tiger", Color(0.5, 0.1, 0.1), 0.5)
			_blob(n, m4, Vector3(0.0, 0.17, 0.0), Vector3(0.74, 0.38, 0.46))
			var wm := _mat("marble", Color(0.95, 0.88, 0.84), 0.6)
			for i in 4:
				_blob(n, wm, Vector3(-0.22 + 0.15 * float(i), 0.33, 0.04 * float(i % 2) - 0.02), Vector3(0.09, 0.03, 0.05))
			_bone(n, Vector3(0.52, 0.17, 0.0), 0.5, Vector3(0.0, 0.0, PI * 0.5), 0.026)
	return n


## 땅에 놓인 깃털: 가는 대와 둥글게 휜 깃판
static func feather_node(col := Color(0.55, 0.38, 0.22)) -> Node3D:
	var n := Node3D.new()
	var vane := _mat("f_vane_" + col.to_html(), col, 0.8)
	var quill := _mat("f_quill", Color(0.9, 0.86, 0.74), 0.7)
	var q := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.006
	cm.height = 0.3
	q.mesh = cm
	q.material_override = quill
	q.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	q.position = Vector3(0.0, 0.015, 0.0)
	n.add_child(q)
	var v := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 8
	sp.rings = 4
	v.mesh = sp
	v.material_override = vane
	v.scale = Vector3(0.07, 0.012, 0.22)
	v.position = Vector3(0.0, 0.02, -0.03)
	n.add_child(v)
	n.rotation.y = randf() * TAU
	return n


## 화살: 원점이 오늬(시위 끼우는 끝)이고 촉 쪽이 -z 방향. 길이 0.85m, 돌촉, 깃 세 장. [설계]
static func arrow_node() -> Node3D:
	var n := Node3D.new()
	var shaft := _mat("a_shaft", Color(0.62, 0.5, 0.3), 0.8)
	var tip := _mat("a_tip", Color(0.55, 0.55, 0.53), 0.6)
	var fl := _mat("a_fletch", Color(0.78, 0.7, 0.55), 0.8)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.007
	cm.height = 0.85
	cm.radial_segments = 6
	m.mesh = cm
	m.material_override = shaft
	m.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	m.position = Vector3(0.0, 0.0, -0.425)
	n.add_child(m)
	var t := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.016
	tm.height = 0.07
	tm.radial_segments = 6
	t.mesh = tm
	t.material_override = tip
	t.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	t.position = Vector3(0.0, 0.0, -0.885)
	n.add_child(t)
	for i in 3:
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.002, 0.04, 0.13)
		f.mesh = bm
		f.material_override = fl
		f.position = Vector3(0.0, 0.0, -0.09)
		f.rotation.z = float(i) * TAU / 3.0
		f.translate_object_local(Vector3(0.0, 0.02, 0.0))
		n.add_child(f)
	return n


## 가죽: 몸통판에 네 다리와 머리 자리가 붙은 펼친 가죽. 사슴은 흰 점, 멧돼지는 거친 갈기선, 늑대는 옅은 배, 호랑이는 검은 줄무늬
static func hide_node(hide_id: String) -> Node3D:
	var n := Node3D.new()
	var col: Color = HIDES[hide_id]["col"] if HIDES.has(hide_id) else Color(0.5, 0.4, 0.3)
	var m := _mat("h_" + hide_id, col, 1.0)
	var k := 1.0 if hide_id != "hide_tiger" else 1.55
	_blob(n, m, Vector3(0.0, 0.025, 0.0), Vector3(0.6, 0.05, 0.42) * k)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lx: float = sx
			var lz: float = sz
			_blob(n, m, Vector3(lx * 0.26, 0.022, lz * 0.2) * k, Vector3(0.2, 0.04, 0.14) * k)
	_blob(n, m, Vector3(0.38 * k, 0.025, 0.0), Vector3(0.22, 0.045, 0.2) * k)
	match hide_id:
		"hide_deer":
			var wm := _mat("spot", Color(0.95, 0.92, 0.84), 1.0)
			for i in 8:
				_blob(n, wm, Vector3(-0.2 + 0.07 * float(i), 0.052, 0.12 * sin(float(i) * 2.1)), Vector3(0.04, 0.012, 0.04))
		"hide_boar":
			var bm := _mat("bristle", Color(0.5, 0.42, 0.34), 1.0)
			_slab(n, bm, Vector3(0.0, 0.052, 0.0), Vector3(0.5, 0.012, 0.05))
		"hide_wolf":
			var bl := _mat("wolf_belly", Color(0.86, 0.82, 0.74), 1.0)
			_blob(n, bl, Vector3(0.0, 0.052, 0.0), Vector3(0.36, 0.012, 0.16))
		_:
			var st := _mat("stripe", Color(0.08, 0.06, 0.05), 1.0)
			for i in 6:
				_slab(n, st, Vector3((-0.32 + 0.13 * float(i)) * k, 0.056, 0.0), Vector3(0.035, 0.012, 0.3 * k), 0.15 * float(i % 3 - 1))
	return n


# --- 들고 있는 모양 -----------------------------------------------------

static func _mat(key: String, col: Color, rough := 0.9) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	_mats[key] = m
	return m


func _rebuild_held() -> void:
	if _held != null and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	_held_id = equipped
	if archery != null:
		archery.clear_bow()
	if equipped == "" or _player == null:
		return
	if String(TOOLS[equipped]["kind"]) == "bow":
		if archery != null:
			archery.build_bow()
		return
	var hand: Node3D = _player.get("_person").hand() if _player.get("_person") != null else null
	if hand == null:
		return
	var d: Dictionary = TOOLS[equipped]
	var is_stone := equipped.begins_with("stone")
	var wood := _mat("w_handle", Color(0.36, 0.24, 0.12), 0.85)
	var wrap := _mat("w_wrap", Color(0.72, 0.62, 0.44), 0.95)
	var cord := _mat("w_cord", Color(0.28, 0.2, 0.11), 0.95)
	var brass := _mat("w_brass", Color(0.68, 0.52, 0.22), 0.4)
	brass.metallic = 0.7
	var head := _mat("head_stone2" if is_stone else "head_wood2", Color(0.56, 0.57, 0.55) if is_stone else Color(0.6, 0.44, 0.25), 0.55 if is_stone else 0.8)
	head.cull_mode = BaseMaterial3D.CULL_DISABLED
	var root := Node3D.new()
	root.position = Vector3(0.0, -0.26, 0.0)
	root.rotation.x = -1.15
	hand.add_child(root)
	var kind := String(d["kind"])
	match kind:
		"knife":
			# 환도 같은 긴 칼: 감은 손잡이, 코등이, 살짝 굽은 긴 날
			_part(root, CylinderMesh.new(), wood, Vector3(0.0, -0.02, 0.0), Vector3.ONE, 0.22, 0.02)
			for k in 4:
				_part(root, CylinderMesh.new(), wrap, Vector3(0.0, 0.07 - 0.05 * float(k), 0.0), Vector3.ONE, 0.028, 0.0235)
			_part(root, CylinderMesh.new(), brass, Vector3(0.0, 0.1, 0.0), Vector3.ONE, 0.03, 0.03)
			_part(root, CylinderMesh.new(), brass, Vector3(0.0, -0.125, 0.0), Vector3.ONE, 0.014, 0.055)
			var bl := _blade_mesh(0.56, 0.05, 0.04, 0.012 if is_stone else 0.016, 0.045, true)
			_mi(root, bl, head, Vector3(0.0, -0.132, 0.0), Vector3.ZERO)
		"axe":
			# 긴 자루에 날을 끈으로 묶은 도끼
			_part(root, CylinderMesh.new(), wood, Vector3(0.0, -0.3, 0.0), Vector3.ONE, 0.8, 0.021)
			_part(root, CylinderMesh.new(), wrap, Vector3(0.0, 0.0, 0.0), Vector3.ONE, 0.16, 0.0235)
			var knob := SphereMesh.new()
			knob.radius = 0.03
			knob.height = 0.06
			_mi(root, knob, wood, Vector3(0.0, 0.1, 0.0), Vector3.ZERO)
			var ah := _blade_mesh(0.17, 0.2, 0.24, 0.07, 0.0, false)
			_mi(root, ah, head, Vector3(0.0, -0.5, 0.075), Vector3.ZERO)
			for y in [-0.51, -0.545, -0.58]:
				_part(root, CylinderMesh.new(), cord, Vector3(0.0, float(y), 0.0), Vector3.ONE, 0.022, 0.034)
		_:
			# 곡괭이: 긴 자루와 양쪽으로 뾰족한 머리
			_part(root, CylinderMesh.new(), wood, Vector3(0.0, -0.3, 0.0), Vector3.ONE, 0.8, 0.021)
			_part(root, CylinderMesh.new(), wrap, Vector3(0.0, 0.0, 0.0), Vector3.ONE, 0.16, 0.0235)
			var pk := _blade_mesh(0.27, 0.07, 0.025, 0.055, -0.05, true)
			_mi(root, pk, head, Vector3(0.0, -0.6, 0.0), Vector3(-PI * 0.5, 0.0, 0.0))
			var pk2 := _blade_mesh(0.27, 0.07, 0.025, 0.055, 0.05, true)
			_mi(root, pk2, head, Vector3(0.0, -0.6, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
			_box(root, head, Vector3(0.06, 0.08, 0.07), Vector3(0.0, -0.6, 0.0))
			for z in [-0.045, 0.0, 0.045]:
				_part(root, CylinderMesh.new(), cord, Vector3(0.0, -0.6, float(z)), Vector3(1.0, 1.0, 1.0), 0.02, 0.036)
	_held = root


## 칼날 같은 납작한 쐐기 모양. 길이는 -y 쪽, 폭은 z(등→날), 두께는 x. curve는 끝이 z쪽으로 휜 정도, point면 끝이 뾰족하다.
static var _meshes := {}

static func _blade_mesh(length: float, w0: float, w1: float, thick: float, curve: float, point: bool) -> ArrayMesh:
	var key := "bm_%.3f_%.3f_%.3f_%.3f_%.3f_%s" % [length, w0, w1, thick, curve, str(point)]
	if _meshes.has(key):
		return _meshes[key]
	var segs := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in segs + 1:
		var u := float(i) / float(segs)
		var y := -length * u
		var w := lerpf(w0, w1, u)
		var cz := curve * u * u
		var t := thick * (1.0 - 0.45 * u)
		rings.append([Vector3(-t * 0.5, y, cz - w * 0.5), Vector3(t * 0.5, y, cz - w * 0.5), Vector3(0.0, y, cz + w * 0.5)])
	for i in segs:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for e in 3:
			var a0: Vector3 = r0[e]
			var b0: Vector3 = r0[(e + 1) % 3]
			var a1: Vector3 = r1[e]
			var b1: Vector3 = r1[(e + 1) % 3]
			for v in [a0, b0, a1, b0, b1, a1]:
				st.add_vertex(v as Vector3)
	var first: Array = rings[0]
	var last: Array = rings[segs]
	for v in [first[0], first[2], first[1]]:
		st.add_vertex(v as Vector3)
	if point:
		var lw := lerpf(w0, w1, 1.0)
		var tip := Vector3(0.0, -length - lw * 0.9, curve + lw * 0.3)
		for e in 3:
			var a: Vector3 = last[e]
			var b: Vector3 = last[(e + 1) % 3]
			for v in [a, b, tip]:
				st.add_vertex(v as Vector3)
	else:
		for v in [last[0], last[1], last[2]]:
			st.add_vertex(v as Vector3)
	st.generate_normals()
	var m := st.commit()
	_meshes[key] = m
	return m


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _part(parent: Node3D, mesh: CylinderMesh, mat: Material, pos: Vector3, scl: Vector3, h: float, r: float) -> void:
	mesh.top_radius = r
	mesh.bottom_radius = r * 1.1
	mesh.height = h
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)


func _box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _set_swing_pose(v: float) -> void:
	var pr = _player.get("_person") if _player != null else null
	if pr != null:
		pr.swing = v


# --- 입력과 휘두르기 ----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _player.input_locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var is_bow := equipped != "" and String(TOOLS[equipped]["kind"]) == "bow"
		if is_bow and archery != null:
			if mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				if mb.pressed:
					archery.begin_draw()
				else:
					archery.release_draw()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				archery.cancel_draw()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_attack()
	elif event.is_action_pressed("cycle_tool"):
		cycle()


func _def() -> Dictionary:
	if equipped != "" and TOOLS.has(equipped):
		return TOOLS[equipped]
	return {"name": "맨손", "kind": "fist", "dmg": FIST_DMG, "chop": 0.0, "dur": 0, "time": 0.45}


func _attack() -> void:
	if _cd > 0.0 or _swing >= 0.0 or _player.riding != null or _player.swimming:
		return
	var d := _def()
	_swing_len = float(d["time"])
	var now := Time.get_ticks_msec()
	# 칼은 1.3초 안에 이어 휘두르면 베고(1) 베고(2) 찌르는(3) 세 번 연타가 된다. 도끼·곡괭이는 한 번씩 내려찍는다.
	_combo = _combo + 1 if now - _last_swing_ms < 1300 else 0
	if _combo > 2:
		_combo = 0
	_last_swing_ms = now
	swing_start_ms = now
	var kind := String(d["kind"])
	_cd = _swing_len + (0.12 if kind != "knife" or _combo != 2 else 0.35)
	_swing = 0.0
	_strike_done = false
	var pr = _player.get("_person")
	if pr != null:
		if kind in ["axe", "pick"]:
			pr.swing_kind = 0
		else:
			pr.swing_kind = 2 if (kind == "knife" and _combo == 2) else 1
	# 휘두를 때 팔이 가르는 바람 소리
	pass


func _process(delta: float) -> void:
	if _player == null:
		return
	_cd = maxf(_cd - delta, 0.0)
	if _seen != UiPrefs.version:
		_seen = UiPrefs.version
		_restyle()
	if _held_id != equipped:
		_rebuild_held()
	if _swing >= 0.0:
		_swing += delta / _swing_len
		var yaw := _player._yaw
		_player.face_toward(Vector2(-sin(yaw), -cos(yaw)))
		_set_swing_pose(minf(_swing, 1.0))
		if _swing >= 0.45 and not _strike_done:
			_strike_done = true
			_strike()
		if _swing >= 1.0:
			_swing = -1.0
			_set_swing_pose(-1.0)


func _chunks() -> ChunkManager:
	if _cm == null or not is_instance_valid(_cm):
		_cm = get_tree().get_first_node_in_group("chunks") as ChunkManager
	return _cm


## 휘두른 순간: 앞쪽의 짐승 → 나무 순서로 맞춘다.
func _strike() -> void:
	var d := _def()
	var kind := String(d["kind"])
	var yaw := _player._yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var best: Node3D = null
	var best_d := 99.0
	for b in get_tree().get_nodes_in_group("beast"):
		if not is_instance_valid(b):
			continue
		var bn := b as Node3D
		if bn == null or not bn.has_method("take_hit"):
			continue
		var off := Vector2(bn.global_position.x, bn.global_position.z) - pp
		var size := float(bn.call("body_size")) if bn.has_method("body_size") else 0.9
		var dist := off.length()
		if dist > REACH + size:
			continue
		if dist > size + 0.6 and off.normalized().dot(fwd) < 0.15:
			continue   # 바로 앞쪽에 있는 짐승만 맞는다
		if dist < best_d:
			best_d = dist
			best = bn
	# 휘두르며 한 걸음 내딛는다 (짐승이 앞에 있으면 더 앞으로)
	_player.stagger(Vector3(fwd.x, 0.0, fwd.y), 2.6 if best != null else 1.4, 0.0, false)
	if best != null:
		var finisher := kind == "knife" and _combo == 2   # 세 번째 찌르기는 힘이 더 세다
		var dmg := float(d["dmg"]) * randf_range(0.9, 1.15) * (1.3 if finisher else 1.0)
		best.call("take_hit", dmg, _player.global_position)
		_burst(best.global_position + Vector3(0.0, 0.9, 0.0) + Vector3(-fwd.x, 0.0, -fwd.y) * 0.4, Color(0.55, 0.04, 0.04), 12 if finisher else 8)
		_hit_sound(kind)
		if best.has_method("fur_color"):
			_burst(best.global_position + Vector3(0.0, 1.0, 0.0), best.call("fur_color") as Color, 9 if finisher else 6)
		_hit_stop(0.07 if (finisher or kind == "axe") else 0.045)
		_player.add_shake(0.22 if finisher else 0.14)
		_wear()
		return
	# 큰 바위 (곡괭이로만 깬다)
	var probe0 := _player.global_position + Vector3(fwd.x, 0.0, fwd.y) * 1.4
	var bi := _sv.nearest_boulder(probe0, 2.2)
	if bi >= 0:
		if kind != "pick":
			_sv._hud.toast("큰 바위는 곡괭이로 깨야 한다.", 2.0, "deny")
			return
		var b: Dictionary = _sv.boulders[bi]
		var power := 1.8 if equipped.begins_with("stone") else 1.0
		b["hp"] = float(b["hp"]) - power
		_burst(probe0 + Vector3(0.0, 0.9, 0.0), Color(0.6, 0.58, 0.55), 10)
		UiSfx.play(self, "tok", -2.0, randf_range(0.5, 0.62))
		_player.add_shake(0.12)
		_hit_stop(0.04)
		var broke := float(b["hp"]) <= 0.0
		var big := equipped.begins_with("stone")
		_wear()
		if broke:
			_break_boulder(b, big)
		return
	# 나무
	var cm := _chunks()
	if cm != null:
		var probe := _player.global_position + Vector3(fwd.x, 0.0, fwd.y) * 1.3
		var e := cm.nearest_tree(probe, 1.9)
		if not e.is_empty():
			if kind != "axe":
				_sv._hud.toast("나무를 베려면 도끼가 있어야 한다.", 2.0, "deny")
				return
			var done := cm.chop(e, float(d["chop"]), _player.global_position)
			_burst(probe + Vector3(0.0, 1.0, 0.0), Color(0.55, 0.38, 0.2), 8)
			UiSfx.play(self, "tok", -4.0, randf_range(0.7, 0.85))
			_player.add_shake(0.08)
			_wear()
			if done:
				var s := (e["xf"] as Transform3D).basis.get_scale().x
				var n := int(4.0 + s * 2.0)
				_sv.firewood += n
				_sv.bag_changed.emit()
				_sv._hud.toast("나무가 쓰러졌다! 땔감 +%d" % n, 2.4, "pick")
			return


## 맞는 순간 아주 잠깐 시간이 늦어져 타격이 묵직하게 느껴진다(멈춤 효과)
func _hit_stop(sec: float) -> void:
	if Engine.time_scale < 0.9:
		return
	Engine.time_scale = 0.12
	get_tree().create_timer(sec, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)


## 맞은 곳에서 튀는 작은 조각(피나 나무 부스러기)
func _burst(at: Vector3, col: Color, n: int) -> void:
	var host := _player.get_parent()
	if host == null:
		return
	var pt := CPUParticles3D.new()
	pt.amount = n
	pt.lifetime = 0.6
	pt.one_shot = true
	pt.explosiveness = 1.0
	pt.direction = Vector3.UP
	pt.spread = 70.0
	pt.initial_velocity_min = 1.5
	pt.initial_velocity_max = 3.8
	pt.gravity = Vector3(0.0, -9.0, 0.0)
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _mat("burst_" + str(col.to_html()), col, 1.0)
	pt.mesh = sm
	host.add_child(pt)
	pt.global_position = at
	pt.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(pt):
			pt.queue_free())


## 큰 바위가 깨졌다: 돌 여러 개가 쏟아진다 (돌곡괭이가 더 많이, 종류도 섞여 나온다)
func _break_boulder(b: Dictionary, big: bool) -> void:
	var n := 6 if big else 4
	var got := {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in n:
		var id := roll_stone(rng)
		stones[id] = int(stones.get(id, 0)) + 1
		got[id] = int(got.get(id, 0)) + 1
	var parts: Array[String] = []
	for id in STONE_ORDER:
		if got.has(id):
			parts.append("%s %d" % [stone_name(id), int(got[id])])
	b["on"] = false
	b["left"] = 600.0
	var node: Node3D = b["node"]
	node.visible = false
	var cs := node.get_node_or_null("Body/Shape") as CollisionShape3D
	if cs != null:
		cs.set_deferred("disabled", true)
	_burst(node.global_position + Vector3(0.0, 0.8, 0.0), Color(0.6, 0.58, 0.55), 20)
	_sv._hud.toast("바위가 깨졌다! 돌 +%d (%s)" % [n, ", ".join(parts)], 3.0, "pick")
	_sv.bag_changed.emit()
	changed.emit()


func _hit_sound(kind: String) -> void:
	_sfx.stream = BeastSfx.stream("slash" if kind == "knife" else "thud")
	_sfx.pitch_scale = randf_range(0.9, 1.1)
	_sfx.play()


func _wear() -> void:
	if equipped == "":
		return
	tools[equipped] = int(tools[equipped]) - 1
	_update_hint()
	if int(tools[equipped]) <= 0:
		var nm := String(TOOLS[equipped]["name"])
		tools.erase(equipped)
		_sv._hud.toast("%s%s 부러졌다!" % [nm, "이" if Items.eul(nm) == "을" else "가"], 2.6, "deny")
		equip("")


# --- 화면 ---------------------------------------------------------------

func _update_hint() -> void:
	if _hint == null:
		return
	if equipped == "":
		_hint.visible = not tools.is_empty()
		_hint.text = "맨손 · Q 연장 들기 · 좌클릭 휘두르기"
	else:
		_hint.visible = true
		var d: Dictionary = TOOLS[equipped]
		if String(d["kind"]) == "bow":
			_hint.text = "%s (%d회) · 좌클릭 누르고 있다 떼기: 쏘기 · 우클릭: 취소 · 화살 %d발 · Q 바꾸기" % [String(d["name"]), int(tools.get(equipped, 0)), arrows]
		else:
			var extra := " · 나무 앞에서 좌클릭: 벌목" if String(d["kind"]) == "axe" else ""
			_hint.text = "%s (%d회) · 좌클릭 휘두르기 · Q 바꾸기%s" % [String(d["name"]), int(tools.get(equipped, 0)), extra]


func _restyle() -> void:
	if _hint == null:
		return
	JoseonUI.style_toast(_hint, 18)
	_update_hint()

