class_name Person
extends Node3D
## 절차적으로 만든 사람. 뼈대(허리, 척추, 머리, 팔 2단, 다리 2단)마다 몸 조각 하나를 붙이고
## 걷기, 달리기, 망치질, 앉기, 이야기하기 동작을 코드로 움직인다.
## 키는 조선시대 평균(남 161cm, 여 149cm) 기준이다. 복식과 얼굴의 근거와 설계값은 docs/고증_근거.md 10장.
## 앞쪽은 +Z 방향이다.

enum Kind { WORKER, MASON, PORTER, OFFICIAL, YANGBAN, WOMAN, MAID, CHILD, PROTAGONIST, SOLDIER, KING }
enum Act { IDLE, HAMMER, WALK, CARRY, SIT, TALK, LOCO, WASH, DRAW, PLANE, TAMP, KITE, TOP, DRILL }

const ANIM_RANGE := 90.0
const HIP_Y := 0.85
const UPPER := 0.27
const THIGH := 0.39

var kind: int = Kind.WORKER
var act: int = Act.IDLE
var variant := 0
## CARRY일 때 지게에 얹는 짐. 1 돌, 2 나뭇짐
var load_kind := 1
## WALK/CARRY일 때 오가는 두 지점 (월드 xz)
var route_a := Vector2.ZERO
var route_b := Vector2.ZERO
var speed := 1.1
## true이면 신분별 하루 일과에 따라 낮에만 나와 있다(밤에는 집 안). 증거 NPC와 주인공은 쓰지 않는다.
var scheduled := false
## true이면 인정(밤 10시경)부터 파루(새벽 4시경)까지만 나오는 순라군이다. 시각은 널리 알려진 값을 쓴 추정이다.
var patrol := false

# 귀가 동선: 0 일하는 중, 1 집으로, 2 집 안(숨김), 3 아침에 집에서 나옴
var _home := Vector2(INF, INF)
var _state := 0
var _trip_target := Vector2.ZERO
var _saved_act := 0
var _saved_ra := Vector2.ZERO
var _saved_rb := Vector2.ZERO
var _saved_pos := Vector2.ZERO
var _sched_init := false
# 시선과 인사
var _gaze_yaw := 0.0
var _gaze_pitch := 0.0
var _greet_t := -1.0
var _greet_cool := 0.0
var _t := 0.0
var _voice: AudioStreamPlayer3D
var _lids: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _next_blink := 2.0
var _blink_t := -1.0
static var _face_mesh: SphereMesh
static var _lid_mats: Dictionary = {}
static var _mouth_mat: StandardMaterial3D
var _sched_tick := 0
var _jit := 0.0
var _ph := 0.0
var _phase := 0.0
var _to_b := true
var _long := false
var _loco_speed := 0.0
var _grounded := true
var _band := 1
var _band_check := 3.0
var lift := 0.0  ## 월대처럼 지면보다 높은 곳을 걷는 사람의 발 높이 보정
var _gd_t := randf() * 0.1
var _gd_off := 0.0
var _gd_stuck := 0.0
var _wp: Array[Vector2] = []  ## 집에 오가는 길의 남은 중간점
# 사람끼리 부딪혔을 때의 반응 (밀림, 휘청, 말풍선)
const BUMP_DIST := 0.8
var _body: StaticBody3D
var _pl: Node3D
var _shove := Vector2.ZERO
var _anchor := Vector2(INF, INF)
var _lean := Vector2.ZERO
## 물 위 자세: 0 없음, 1 노 젓기, 2 헤엄. 주인공만 쓴다 (water_phase 는 동작 위상)
## 어가 앞에서 엎드려 절하는 중 (왕 행차). 켜면 하던 일을 멈추고 부복 자세를 취한다.
var prostrate := false
## 연장·무기를 휘두르는 동작. 음수면 쉬는 중, 0~1 이면 그 진행. swing_kind 0 은 내려찍기(도끼·곡괭이), 1 은 비껴 베기, 2 는 찌르기(칼). [설계]
var swing := -1.0
var swing_kind := 0
## 활을 당기는 동작. 음수면 쉬는 중, 0~1 은 당긴 정도(1이 만작). 왼손은 활을 밀고 오른손은 턱까지 당긴다. [설계]
var aim := -1.0
var _pro_k := 0.0
## 짐승에게 덮쳐 쓰러진 상태 (등을 대고 누움). 켜면 쓰러지고 끄면 일어난다.
var fallen := false
var _fall_k := 0.0
var water_pose := 0
var water_phase := 0.0
## 헤엄칠 때 움직이는 정도 0~1 (0이면 선헤엄으로 제자리에서 물을 젓고, 1이면 평영으로 나아간다)
var swim_move := 0.0
var _swim_k := 0.0
## 치마·도포 자락: 허리에 매달려 걸음과 관성에 따라 스프링처럼 흔들린다
var _skirt: Node3D
var _cx := 0.0
var _cv := 0.0
var _cz := 0.0
var _czv := 0.0
var _cloth_v := 0.0
var _bump_cd := 0.0
var _hold := 0.0
var _bubble: Label3D
var _bubble_t := 0.0
var _contact_tick := 0

var _rig: Node3D
var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _stoop := 0.0
var _sh: Array[Node3D] = []
var _el: Array[Node3D] = []
var _th: Array[Node3D] = []
var _kn: Array[Node3D] = []

static var _cache: Dictionary = {}
static var _cloth: ShaderMaterial


static func _cloth_mat() -> ShaderMaterial:
	if _cloth == null:
		_cloth = ShaderMaterial.new()
		_cloth.shader = load("res://shaders/cloth.gdshader") as Shader
	return _cloth


func setup(k: int, a: int, pos: Vector3, yaw: float, v := -1) -> Person:
	kind = k
	act = a
	position = pos
	rotation.y = yaw
	_phase = randf() * TAU
	variant = v if v >= 0 else randi() % 4
	add_to_group("person")
	_build()
	return self


## 플레이어가 직접 움직일 때 호출한다. 속도(m/s)에 맞춰 걷기와 달리기가 정해진다.
func set_locomotion(move_speed: float, grounded: bool) -> void:
	_loco_speed = move_speed
	_grounded = grounded


## 계절 구간: 0 더운 철, 1 선선한 철(봄·가을), 2 추운 철. Season.cold 기준이다.
static func season_band() -> int:
	if Season.cold > 0.6:
		return 2
	if Season.cold < 0.28:
		return 0
	return 1


# --- 복식 정의 ---

func _outfit() -> Dictionary:
	var k := kind
	var rng := RandomNumberGenerator.new()
	rng.seed = k * 7919 + variant * 104729 + 13
	var labor := k == Kind.WORKER or k == Kind.MASON or k == Kind.PORTER
	var female := k == Kind.WOMAN or k == Kind.MAID
	var skin_base := Color(0.86, 0.70, 0.56)
	if labor:
		skin_base = Color(0.74, 0.53, 0.38)
	elif female:
		skin_base = Color(0.88, 0.74, 0.62)
	var sk := rng.randf_range(0.93, 1.06)
	var o := {
		"height": (1.49 if female else 1.61) * rng.randf_range(0.965, 1.035),
		"female": female,
		"child": k == Kind.CHILD,
		"skin": Color(skin_base.r * sk, skin_base.g * sk, skin_base.b * sk, 0.0),
		"hair": Color(0.05, 0.04, 0.04, 0.0),
		"beard": 0,
		"face_w": rng.randf_range(0.94, 1.08),
		"jaw": rng.randf_range(0.9, 1.1),
		"nose": rng.randf_range(0.85, 1.2),
		"top": Color(0.72, 0.64, 0.47, 1.0),
		"bottom": Color(0.66, 0.59, 0.43, 1.0),
		"lapel": Color(0.86, 0.84, 0.76, 1.0),
		"sash": Color(0.33, 0.28, 0.2, 1.0),
		"cuff": Color(0.72, 0.64, 0.47, 1.0),
		"shoe": "straw",
		"hat": "towel",
		"long": false,
		"wide": 0.0,
		"roll": false,
		"rolled": false,
		"dirt": 0.2,
		"bundle": false,
		"band": _band,
		"pad": 1.0,
		"scarf": false,
		"vest": false,
	}
	var gray := variant % 2 == 0
	match k:
		Kind.WORKER:
			o["beard"] = 1 if variant % 3 == 0 else 0
			o["top"] = Color(0.7, 0.62, 0.45, 1.0) if variant < 2 else Color(0.62, 0.58, 0.46, 1.0)
		Kind.MASON:
			o["top"] = Color(0.6, 0.54, 0.4, 1.0)
			o["bottom"] = Color(0.54, 0.49, 0.37, 1.0)
			o["roll"] = true
			o["rolled"] = true
			o["dirt"] = 0.38
			o["beard"] = 2
			if gray:
				o["hair"] = Color(0.6, 0.58, 0.55, 0.0)
		Kind.PORTER:
			o["top"] = Color(0.66, 0.58, 0.42, 1.0)
			o["bottom"] = Color(0.58, 0.52, 0.38, 1.0)
			o["roll"] = true
			o["rolled"] = true
			o["dirt"] = 0.32
			o["beard"] = 1 if variant % 2 == 1 else 0
		Kind.OFFICIAL:
			o["top"] = Color(0.13, 0.24, 0.36, 1.0)
			o["bottom"] = Color(0.84, 0.82, 0.74, 1.0)
			o["sash"] = Color(0.08, 0.08, 0.09, 1.0)
			o["hat"] = "samo"
			o["shoe"] = "boot"
			o["long"] = true
			o["wide"] = 0.8
			o["dirt"] = 0.05
			o["beard"] = 2 if variant < 3 else 1
			if gray:
				o["hair"] = Color(0.55, 0.53, 0.5, 0.0)
		Kind.YANGBAN:
			o["top"] = Color(0.76, 0.78, 0.7, 1.0) if variant % 2 == 0 else Color(0.58, 0.68, 0.64, 1.0)
			o["bottom"] = Color(0.84, 0.82, 0.74, 1.0)
			o["sash"] = Color(0.34, 0.4, 0.5, 1.0)
			o["hat"] = "gat"
			o["shoe"] = "boot"
			o["long"] = true
			o["wide"] = 1.0
			o["dirt"] = 0.05
			o["beard"] = 2 if variant < 2 else 1
		Kind.KING:
			# 왕: 붉은 곤룡포(상복)에 익선관. 익선관 모양은 만들지 않고 사모 꼴로 근사했다. 색과 모양은 설계값이다. (고증_근거.md 43장)
			o["top"] = Color(0.66, 0.1, 0.09, 1.0)
			o["bottom"] = Color(0.8, 0.12, 0.1, 1.0)
			o["lapel"] = Color(0.9, 0.74, 0.28, 1.0)
			o["cuff"] = Color(0.9, 0.74, 0.28, 1.0)
			o["sash"] = Color(0.85, 0.68, 0.22, 1.0)
			o["hat"] = "samo"
			o["shoe"] = "boot"
			o["long"] = true
			o["wide"] = 1.0
			o["dirt"] = 0.0
			o["beard"] = 2
			o["hair"] = Color(0.6, 0.58, 0.55, 0.0)
		Kind.WOMAN:
			o["top"] = Color(0.8, 0.74, 0.58, 1.0)
			o["bottom"] = Color(0.2, 0.27, 0.42, 1.0) if variant % 2 == 0 else Color(0.66, 0.6, 0.46, 1.0)
			o["cuff"] = Color(0.3, 0.33, 0.45, 1.0)
			o["lapel"] = Color(0.88, 0.86, 0.78, 1.0)
			o["hat"] = "hood" if variant < 2 else "bun"
			o["shoe"] = "shoe"
			o["dirt"] = 0.22
		Kind.MAID:
			o["top"] = Color(0.9, 0.8, 0.5, 1.0)
			o["bottom"] = Color(0.58, 0.17, 0.22, 1.0)
			o["cuff"] = Color(0.2, 0.27, 0.42, 1.0)
			o["lapel"] = Color(0.92, 0.9, 0.84, 1.0)
			o["hat"] = "bun"
			o["shoe"] = "shoe"
			o["dirt"] = 0.05
		Kind.SOLDIER:
			# 군졸: 철릭 차림(초기에는 길이 115~130cm 안팎, 사료). 색·모자·창 모양은 확인하지 못한 설계값이다.
			# variant 3은 수문장(관원 모자를 쓰고 색이 짙음).
			o["top"] = Color(0.2, 0.25, 0.33, 1.0) if variant < 3 else Color(0.5, 0.14, 0.12, 1.0)
			o["bottom"] = Color(0.74, 0.72, 0.64, 1.0)
			o["sash"] = Color(0.5, 0.12, 0.1, 1.0)
			o["hat"] = "jeon" if variant < 3 else "samo"
			o["shoe"] = "boot"
			o["long"] = true
			o["wide"] = 0.5
			o["dirt"] = 0.12
			o["beard"] = 1 if variant % 2 == 0 else 0
			o["height"] = 1.63 * rng.randf_range(0.97, 1.03)
		Kind.CHILD:
			o["height"] = 1.1 * rng.randf_range(0.92, 1.06)
			o["top"] = Color(0.74, 0.66, 0.5, 1.0)
			o["hat"] = "braid"
			o["jaw"] = 0.9
		Kind.PROTAGONIST:
			o["height"] = 1.64
			o["top"] = Color(0.3, 0.38, 0.46, 1.0)
			o["bottom"] = Color(0.8, 0.78, 0.7, 1.0)
			o["sash"] = Color(0.18, 0.15, 0.12, 1.0)
			o["hat"] = "gat"
			o["shoe"] = "boot"
			o["long"] = true
			o["wide"] = 0.55
			o["dirt"] = 0.1
			o["bundle"] = true
			o["skin"] = Color(0.84, 0.68, 0.53, 0.0)
	_add_traits(o)
	_apply_season(o)
	return o


## 얼굴과 몸의 개인차. 한 사람마다 나이·눈매·눈썹·입술·광대·얼굴 길이·귀·어깨·배·굽은 정도가 다르다.
## 범위와 나이 분포는 설계값이다. 15세기 조선 사람의 통계가 아니라 실제 사람의 몸이 이만큼 다양하다는 일반 관찰을 따랐다.
## 난수는 기존 외형과 섞이지 않도록 따로 만든다.
func _add_traits(o: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = kind * 31337 + variant * 7777 + 5
	var a := r.randf()
	var female: bool = o["female"]
	var age := 1
	match kind:
		Kind.CHILD:
			age = -1
		Kind.WORKER, Kind.MASON, Kind.PORTER:
			age = 0 if a < 0.32 else (1 if a < 0.82 else 2)
		Kind.SOLDIER:
			age = 0 if a < 0.55 else (1 if a < 0.95 else 2)
		Kind.OFFICIAL, Kind.YANGBAN:
			age = 0 if a < 0.1 else (1 if a < 0.65 else 2)
		Kind.WOMAN:
			age = 0 if a < 0.2 else (1 if a < 0.75 else 2)
		Kind.MAID:
			age = 0 if a < 0.6 else 1
		Kind.PROTAGONIST:
			age = 0
		Kind.KING:
			age = 2
	o["age"] = age
	o["eye_slant"] = r.randf_range(0.04, 0.2)
	o["eye_w"] = r.randf_range(0.92, 1.1)
	o["brow_t"] = r.randf_range(0.7, 0.95) if female else r.randf_range(0.95, 1.35)
	o["lip"] = r.randf_range(0.9, 1.25) if female else r.randf_range(0.8, 1.15)
	o["cheek"] = r.randf_range(0.92, 1.12)
	o["face_len"] = r.randf_range(0.94, 1.08)
	o["ear"] = r.randf_range(0.9, 1.25)
	o["shoulder"] = r.randf_range(0.9, 0.98) if female else r.randf_range(0.94, 1.08)
	o["belly"] = 0.0
	o["stoop"] = 0.0
	if age == 2:
		o["hair"] = Color(0.62, 0.6, 0.58, 0.0)
		o["stoop"] = r.randf_range(0.1, 0.2)
		o["height"] = float(o["height"]) * 0.985
	elif age == 1:
		var porter := kind == Kind.PORTER
		o["stoop"] = r.randf_range(0.08, 0.14) if porter else r.randf_range(0.0, 0.04)
		if not female and (kind == Kind.OFFICIAL or kind == Kind.YANGBAN):
			o["belly"] = r.randf_range(0.01, 0.035)
	if kind == Kind.PROTAGONIST:
		o["eye_w"] = 1.0
		o["brow_t"] = 1.1

## 계절별 옷차림. 겨울 솜옷·방한모, 여름 삼베옷·패랭이는 15세기 직접 사료를 찾지 못한 설계값이다(docs 19장).
func _apply_season(o: Dictionary) -> void:
	var band: int = o["band"]
	var labor := kind == Kind.WORKER or kind == Kind.MASON or kind == Kind.PORTER
	var elite := kind == Kind.OFFICIAL or kind == Kind.YANGBAN or kind == Kind.PROTAGONIST or kind == Kind.KING
	if band == 2:
		o["pad"] = 1.12
		o["scarf"] = true
		var t: Color = o["top"]
		o["top"] = Color(t.r * 0.9, t.g * 0.88, t.b * 0.86, 1.0)
		var b: Color = o["bottom"]
		o["bottom"] = Color(b.r * 0.92, b.g * 0.9, b.b * 0.88, 1.0)
		o["roll"] = false
		o["rolled"] = false
		o["wide"] = float(o["wide"]) * 0.8
		if labor or kind == Kind.CHILD:
			o["hat"] = "earflap"
		if elite and kind != Kind.OFFICIAL and kind != Kind.KING:
			o["vest"] = true
		if kind == Kind.WOMAN and o["hat"] == "bun":
			o["hat"] = "hood"
	elif band == 0:
		# 더운 철: 삼베·모시처럼 밝고 얇은 색, 소매와 바짓단을 걷는다
		var t2: Color = o["top"]
		if labor or kind == Kind.CHILD:
			o["top"] = t2.lerp(Color(0.84, 0.8, 0.66, 1.0), 0.45)
			o["roll"] = true
			o["rolled"] = true
			o["hat"] = "paeraengi"
		elif kind == Kind.WOMAN or kind == Kind.MAID:
			o["top"] = t2.lerp(Color(0.9, 0.88, 0.8, 1.0), 0.3)
		elif kind == Kind.YANGBAN:
			o["top"] = t2.lerp(Color(0.88, 0.88, 0.82, 1.0), 0.4)


# --- 조립 ---

func _build() -> void:
	_band = season_band()
	var o := _outfit()
	_long = o["long"]
	_stoop = float(o["stoop"])
	_rig = Node3D.new()
	_rig.scale = Vector3.ONE * (float(o["height"]) / 1.61)
	add_child(_rig)
	_hips = Node3D.new()
	_hips.position = Vector3(0.0, HIP_Y, 0.0)
	_rig.add_child(_hips)
	_attach(_hips, "pelvis", o)
	if o["female"] or o["long"]:
		_skirt = Node3D.new()
		_hips.add_child(_skirt)
		_attach(_skirt, "skirt", o)
	_spine = Node3D.new()
	_hips.add_child(_spine)
	_attach(_spine, "torso", o)
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.55, 0.0)
	_spine.add_child(_head)
	_attach(_head, "head", o)
	if o["child"]:
		_head.scale = Vector3.ONE * 1.15
	_build_face_parts(o)
	if act == Act.TALK:
		_voice = AudioStreamPlayer3D.new()
		var vk := 2 if o["child"] else (1 if o["female"] else 0)
		_voice.stream = Ambience.mumble_stream(vk)
		_voice.unit_size = 3.0
		_voice.max_distance = 16.0
		_voice.volume_db = -8.0
		_head.add_child(_voice)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.185, 0.47, 0.0)
		_spine.add_child(sh)
		_attach(sh, "arm_up_%d" % i, o)
		var el := Node3D.new()
		el.position = Vector3(0.0, -UPPER, 0.0)
		sh.add_child(el)
		_attach(el, "arm_low_%d" % i, o)
		var th := Node3D.new()
		th.position = Vector3(s * 0.085, 0.0, 0.0)
		_hips.add_child(th)
		_attach(th, "thigh", o)
		var kn := Node3D.new()
		kn.position = Vector3(0.0, -THIGH, 0.0)
		th.add_child(kn)
		_attach(kn, "shin", o)
		_sh.append(sh)
		_el.append(el)
		_th.append(th)
		_kn.append(kn)
	if kind == Kind.PORTER and act == Act.CARRY:
		_attach(_spine, "frame_%d" % load_kind, o)
	if kind == Kind.SOLDIER:
		_attach(_spine, "spear", o)
	_reset_pose()


## 눈꺼풀(깜빡임)과 입(말할 때 벌어짐). 얼굴 메시 위에 얹는 작은 조각이고 크기는 설계값이다.
func _build_face_parts(o: Dictionary) -> void:
	if _face_mesh == null:
		_face_mesh = SphereMesh.new()
		_face_mesh.radius = 0.5
		_face_mesh.height = 1.0
		_face_mesh.radial_segments = 8
		_face_mesh.rings = 4
		_mouth_mat = StandardMaterial3D.new()
		_mouth_mat.albedo_color = Color(0.2, 0.05, 0.05)
		_mouth_mat.roughness = 1.0
	var skin: Color = o["skin"]
	var key := skin.to_html(false)
	if not _lid_mats.has(key):
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(skin.r * 0.97, skin.g * 0.95, skin.b * 0.95)
		lm.roughness = 0.9
		_lid_mats[key] = lm
	var fw: float = o["face_w"]
	for sgn in [-1.0, 1.0]:
		var lid := MeshInstance3D.new()
		lid.mesh = _face_mesh
		lid.material_override = _lid_mats[key]
		lid.position = Vector3(float(sgn) * 0.036 * fw, 0.118, 0.094)
		lid.scale = Vector3(0.026, 0.0, 0.016)
		lid.visible = false
		lid.visibility_range_end = 25.0
		_head.add_child(lid)
		_lids.append(lid)
	_mouth = MeshInstance3D.new()
	_mouth.mesh = _face_mesh
	_mouth.material_override = _mouth_mat
	_mouth.position = Vector3(0.0, 0.038, 0.087)
	_mouth.scale = Vector3(0.028, 0.0, 0.012)
	_mouth.visible = false
	_mouth.visibility_range_end = 25.0
	_head.add_child(_mouth)
	_next_blink = randf_range(1.0, 5.0)


func _animate_face(delta: float) -> void:
	# 눈 깜빡임: 3~6초마다 0.16초
	if _blink_t < 0.0:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_t = 0.0
	else:
		_blink_t += delta
		var q := _blink_t / 0.16
		var closure := sin(clampf(q, 0.0, 1.0) * PI)
		for lid in _lids:
			lid.visible = closure > 0.05
			lid.scale.y = 0.016 * closure
		if q >= 1.0:
			_blink_t = -1.0
			_next_blink = randf_range(3.0, 6.0)
			for lid in _lids:
				lid.visible = false
	# 말하는 입: 음절마다 열렸다 닫히고 문장 사이에 쉰다
	if act == Act.TALK:
		var open := absf(sin(_t * 9.0 + _phase)) * clampf(sin(_t * 1.9 + _phase) * 2.0, 0.0, 1.0)
		_mouth.visible = open > 0.08
		_mouth.scale.y = 0.014 * open
	elif _mouth.visible:
		_mouth.visible = false


func _attach(parent: Node3D, part: String, o: Dictionary) -> void:
	if part == "thigh" and o["female"]:
		return  # 치마 속 다리는 보이지 않는다
	var m := _part_mesh(part, o)
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _cloth_mat()
	mi.visibility_range_end = 140.0
	parent.add_child(mi)


func _part_mesh(part: String, o: Dictionary) -> ArrayMesh:
	var key := "%d_%d_%d_%s" % [kind, variant, int(o["band"]), part]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match part:
		"pelvis":
			_b_pelvis(st, o)
		"skirt":
			_b_skirt(st, o)
		"torso":
			_b_torso(st, o)
		"head":
			_b_head(st, o)
		"thigh":
			_b_thigh(st, o)
		"shin":
			_b_shin(st, o)
		_:
			if part.begins_with("arm_up_"):
				_b_arm_up(st, o, -1.0 if part.ends_with("0") else 1.0)
			elif part.begins_with("arm_low_"):
				_b_arm_low(st, o, -1.0 if part.ends_with("0") else 1.0)
			elif part.begins_with("frame_"):
				_b_frame(st, int(part.substr(6)))
			elif part == "spear":
				_b_spear(st)
	var m: ArrayMesh = st.commit()
	_cache[key] = m
	return m


static func _dirty(c: Color, amount: float) -> Color:
	var f := 1.0 - amount
	return Color(c.r * f, c.g * f, c.b * f, c.a)


# --- 몸 조각 ---

func _b_pelvis(st: SurfaceTool, o: Dictionary) -> void:
	var bottom: Color = o["bottom"]
	var dirt: float = o["dirt"]
	var low := _dirty(bottom, dirt)
	if o["female"]:
		var band: Color = o["lapel"]
		BodyMesh.loft(st, [[0.34, 0.158, 0.118], [0.26, 0.17, 0.125]], 14, band, band)
	elif o["long"]:
		var robe: Color = o["top"]
		BodyMesh.loft(st, [[0.06, 0.18, 0.12], [-0.02, 0.19, 0.13]], 16, robe, _dirty(robe, dirt))
	else:
		BodyMesh.loft(st, [[0.06, 0.17, 0.115], [-0.1, 0.19, 0.13]], 14, bottom, low)


## 치마와 도포 자락: 허리에 매달려 따로 흔들리는 조각
func _b_skirt(st: SurfaceTool, o: Dictionary) -> void:
	var bottom: Color = o["bottom"]
	var dirt: float = o["dirt"]
	var low := _dirty(bottom, dirt)
	if o["female"]:
		# 치마: 허리에서 발등 위까지. 1390년대에는 크게 부풀지 않은 모양 (설계값)
		BodyMesh.loft(st, [
			[0.26, 0.17, 0.125], [0.1, 0.2, 0.15], [-0.2, 0.26, 0.23],
			[-0.5, 0.31, 0.29], [-0.78, 0.35, 0.34, 0.0, -0.02],
		], 16, bottom, low)
	else:
		var robe: Color = o["top"]
		BodyMesh.loft(st, [
			[0.05, 0.185, 0.125], [-0.1, 0.215, 0.15], [-0.35, 0.255, 0.19], [-0.57, 0.285, 0.225],
		], 16, robe, _dirty(robe, dirt))


func _b_torso(st: SurfaceTool, o: Dictionary) -> void:
	var f: bool = o["female"]
	var top: Color = o["top"]
	var low := _dirty(top, float(o["dirt"]) * 0.6)
	var skin: Color = o["skin"]
	var pad: float = o["pad"]
	var hm := (0.165 if f else 0.17) * pad
	var wa := (0.125 if f else 0.155) * pad + float(o["belly"])
	var ch := (0.155 if f else 0.185) * pad
	var sh := (0.17 if f else 0.2) * pad * float(o["shoulder"])
	var hem := -0.03 if f else -0.04
	BodyMesh.loft(st, [
		[hem, hm, 0.115 * pad], [0.12, wa, 0.105 * pad], [0.30, ch, 0.12 * pad], [0.43, sh, 0.105 * pad], [0.49, 0.075, 0.065],
	], 14, low, top)
	if pad > 1.05:
		# 누비 솜옷: 가로 누빔선
		var qline := _dirty(top, 0.16)
		for qy in [0.06, 0.16, 0.26, 0.36]:
			var yy: float = qy
			BodyMesh.loft(st, [[yy, wa * 1.0 + 0.004, 0.108 * pad], [yy + 0.008, wa * 1.0 + 0.004, 0.108 * pad]], 14, qline, qline)
	if o["vest"]:
		# 배자(덧입는 조끼): 짙은 색
		var vc := Color(0.16, 0.14, 0.12, 1.0)
		BodyMesh.loft(st, [[-0.02, hm + 0.012, 0.125 * pad], [0.3, ch + 0.012, 0.13 * pad], [0.43, sh + 0.008, 0.115 * pad]], 14, vc, vc)
	if o["scarf"]:
		# 목도리
		var sc := Color(0.62, 0.52, 0.36, 1.0)
		BodyMesh.loft(st, [[0.45, 0.075, 0.07], [0.5, 0.082, 0.078], [0.56, 0.07, 0.065]], 12, sc, sc)
	# 목
	BodyMesh.loft(st, [[0.46, 0.052, 0.05], [0.6, 0.047, 0.045]], 10, skin, skin)
	# 앞섶: 동정(흰 깃)과 여밈선, 고름
	var lap: Color = o["lapel"]
	var seam := _dirty(top, 0.18)
	BodyMesh.box(st, Vector3(-0.02, 0.28, 0.123), Vector3(0.022, 0.45, 0.01), lap, Vector3(0.0, 0.0, -0.24))
	BodyMesh.box(st, Vector3(0.03, 0.31, 0.122), Vector3(0.016, 0.4, 0.01), seam, Vector3(0.0, 0.0, 0.12))
	var rib := _dirty(top, 0.3)
	BodyMesh.box(st, Vector3(0.05, 0.27, 0.127), Vector3(0.014, 0.17, 0.006), rib, Vector3(0.0, 0.0, 0.1))
	if not f:
		var sash: Color = o["sash"]
		BodyMesh.loft(st, [[0.1, wa + 0.012, 0.114], [0.155, wa + 0.012, 0.114]], 14, sash, sash)
	if o["bundle"]:
		# 주인공: 등에 멘 서류 보퉁이와 가슴을 가로지르는 끈, 허리춤 주머니
		var cloth := Color(0.7, 0.64, 0.5, 1.0)
		BodyMesh.ellipsoid(st, Vector3(0.0, 0.2, -0.17), Vector3(0.14, 0.11, 0.07), cloth)
		var strap := Color(0.42, 0.3, 0.18, 1.0)
		BodyMesh.box(st, Vector3(0.0, 0.22, 0.131), Vector3(0.02, 0.5, 0.01), strap, Vector3(0.0, 0.0, 0.5))
		BodyMesh.box(st, Vector3(-0.13, 0.04, 0.1), Vector3(0.06, 0.08, 0.04), Color(0.12, 0.1, 0.09, 1.0))


func _b_head(st: SurfaceTool, o: Dictionary) -> void:
	var skin: Color = o["skin"]
	var hair: Color = o["hair"]
	var fw: float = o["face_w"]
	var jaw: float = o["jaw"]
	var nose: float = o["nose"]
	var f: bool = o["female"]
	var hat: String = o["hat"]
	var yo := Vector3(0.0, 0.1, 0.0)  # 머리 중심이 목 위쪽에 오도록 올린다

	# 얼굴 윤곽
	var fl: float = o["face_len"]
	var ck: float = o["cheek"]
	BodyMesh.loft(st, [
		[-0.112 * fl + yo.y, 0.03 * jaw, 0.04, 0.0, 0.012],
		[-0.092 * fl + yo.y, 0.06 * jaw, 0.066, 0.0, 0.01],
		[-0.05 * fl + yo.y, 0.08 * fw * ck, 0.086, 0.0, 0.006],
		[0.0 + yo.y, 0.088 * fw * ck, 0.098],
		[0.05 * fl + yo.y, 0.088 * fw * ck, 0.098, 0.0, -0.004],
		[0.09 * fl + yo.y, 0.07 * fw, 0.08, 0.0, -0.008],
		[0.113 * fl + yo.y, 0.03 * fw, 0.04, 0.0, -0.01],
	], 14, skin, skin, true, true)

	# 눈코입귀: 크기와 위치는 설계값
	var dark_skin := Color(skin.r * 0.93, skin.g * 0.9, skin.b * 0.9, 0.0)
	BodyMesh.ellipsoid(st, yo + Vector3(0.0, -0.018, 0.1), Vector3(0.013 * nose, 0.03, 0.022 * nose), dark_skin)
	var eye := Color(0.05, 0.035, 0.035, 0.0)
	var brow := Color(hair.r, hair.g, hair.b, 0.0)
	var ear_c := Color(skin.r * 0.97, skin.g * 0.95, skin.b * 0.95, 0.0)
	# 눈·눈썹·입은 FaceKit(face_kit.gd)이 움직이는 조각으로 따로 만든다(가까이 있는 사람에게만 붙는다)
	var ear_s: float = o["ear"]
	for sgn in [-1.0, 1.0]:
		var s: float = sgn
		BodyMesh.ellipsoid(st, yo + Vector3(s * 0.089 * fw * ck, 0.0, 0.0), Vector3(0.008, 0.028 * ear_s, 0.019 * ear_s), ear_c, 0.0, PI, 0.0, TAU, 4, 8)

	# 수염
	var beard: int = o["beard"]
	if beard >= 1:
		BodyMesh.ellipsoid(st, yo + Vector3(0.0, -0.045, 0.093), Vector3(0.032, 0.008, 0.01), brow, 0.0, PI, 0.0, TAU, 4, 8)
	if beard >= 2:
		BodyMesh.ellipsoid(st, yo + Vector3(0.0, -0.095, 0.062), Vector3(0.042, 0.065, 0.035), brow, 0.0, PI, 0.0, TAU, 5, 9)

	# 머리카락: 앞이마 위로 단단히 빗어 올린다
	var cap_lat := PI * 0.5 if hat != "hood" else PI * 0.55
	BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.03, -0.012), Vector3(0.094 * fw, 0.1, 0.108), hair, 0.0, cap_lat, 0.0, TAU, 5, 12)
	if f:
		if hat == "bun" or hat == "hood":
			BodyMesh.ellipsoid(st, yo + Vector3(0.0, -0.035, -0.1), Vector3(0.045, 0.042, 0.04), hair)
			BodyMesh.box(st, yo + Vector3(0.0, -0.035, -0.1), Vector3(0.13, 0.007, 0.007), Color(0.75, 0.6, 0.25, 0.0))
	elif hat == "braid":
		BodyMesh.ellipsoid(st, yo + Vector3(0.0, -0.16, -0.1), Vector3(0.02, 0.11, 0.02), hair)
		BodyMesh.box(st, yo + Vector3(0.0, -0.265, -0.1), Vector3(0.03, 0.03, 0.01), Color(0.65, 0.12, 0.14, 1.0))
	else:
		BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.14, -0.005), Vector3(0.03, 0.035, 0.03), hair)  # 상투

	# 쓰개
	var black := Color(0.04, 0.04, 0.045, 1.0)
	match hat:
		"gat":
			# 갓: 좁은 챙과 둥근 모자 (15세기 크기는 추정)
			BodyMesh.loft(st, [[0.068 + yo.y, 0.185, 0.175], [0.08 + yo.y, 0.178, 0.168]], 18, black, black, true, true)
			BodyMesh.loft(st, [
				[0.08 + yo.y, 0.088, 0.092], [0.13 + yo.y, 0.082, 0.087], [0.19 + yo.y, 0.062, 0.067],
			], 14, black, black, false, true)
			var cord := Color(0.5, 0.12, 0.1, 1.0)
			BodyMesh.box(st, yo + Vector3(-0.094, -0.01, 0.0), Vector3(0.006, 0.17, 0.006), cord)
			BodyMesh.box(st, yo + Vector3(0.094, -0.01, 0.0), Vector3(0.006, 0.17, 0.006), cord)
		"samo":
			# 사모: 날개가 달린 관원 모자 (모양은 단순화한 설계값)
			BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.115, -0.005), Vector3(0.092, 0.085, 0.1), black, 0.0, PI * 0.62, 0.0, TAU, 5, 12)
			BodyMesh.box(st, yo + Vector3(-0.15, 0.17, -0.045), Vector3(0.12, 0.012, 0.03), black, Vector3(0.0, 0.0, 0.2))
			BodyMesh.box(st, yo + Vector3(0.15, 0.17, -0.045), Vector3(0.12, 0.012, 0.03), black, Vector3(0.0, 0.0, -0.2))
		"jeon":
			# 군졸 모자: 검은 둥근 전립 비슷한 모양 (설계값, 15세기 실제 형태 미확인)
			BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.1, -0.005), Vector3(0.1, 0.075, 0.108), black, 0.0, PI * 0.55, 0.0, TAU, 5, 12)
			BodyMesh.loft(st, [[0.07 + yo.y, 0.15, 0.145], [0.085 + yo.y, 0.14, 0.135]], 16, black, black, true, true)
		"towel":
			# 헝겊 수건을 이마에 맸다
			var tw := Color(0.82, 0.8, 0.7, 1.0)
			BodyMesh.loft(st, [
				[0.045 + yo.y, 0.097, 0.108, 0.0, -0.008], [0.078 + yo.y, 0.095, 0.106, 0.0, -0.008],
			], 14, tw, tw)
			BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.06, -0.12), Vector3(0.03, 0.025, 0.02), tw)
		"earflap":
			# 방한모(귀덮개): 이마·귀·뒷목을 덮는 솜 모자. 15세기 형태는 설계값.
			var wool := Color(0.36, 0.29, 0.2, 1.0)
			BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.05, -0.01), Vector3(0.104 * fw, 0.1, 0.116), wool, 0.0, PI * 0.58, 0.0, TAU, 5, 12)
			for sgn2 in [-1.0, 1.0]:
				var s2: float = sgn2
				BodyMesh.box(st, yo + Vector3(s2 * 0.092 * fw, -0.03, 0.0), Vector3(0.026, 0.12, 0.09), wool)
			BodyMesh.box(st, yo + Vector3(0.0, -0.02, -0.105), Vector3(0.15, 0.1, 0.03), wool)
		"paeraengi":
			# 패랭이: 대나무를 엮은 평민 모자. 챙이 좁고 위가 평평하다. 1396년 형태는 설계값.
			var bam := Color(0.66, 0.55, 0.32, 1.0)
			BodyMesh.loft(st, [[0.07 + yo.y, 0.17, 0.165], [0.08 + yo.y, 0.165, 0.16]], 16, bam, bam, true, true)
			BodyMesh.loft(st, [[0.08 + yo.y, 0.088, 0.09], [0.14 + yo.y, 0.075, 0.078]], 14, bam, bam, false, true)
		"hood":
			# 몽두의: 머리와 어깨를 가리는 쓰개 (태종 12년 기록)
			var lin := Color(0.82, 0.78, 0.64, 1.0)
			BodyMesh.ellipsoid(st, yo + Vector3(0.0, 0.0, -0.02), Vector3(0.125, 0.14, 0.14), lin, 0.0, PI * 0.85, 2.27, TAU + 0.87, 6, 12)
			BodyMesh.loft(st, [
				[-0.06, 0.12, 0.13, 0.0, -0.03], [-0.14, 0.2, 0.16, 0.0, -0.03], [-0.2, 0.24, 0.17, 0.0, -0.03],
			], 14, lin, _dirty(lin, 0.1))
		_:
			pass


func _b_arm_up(st: SurfaceTool, o: Dictionary, _side: float) -> void:
	var top: Color = o["top"]
	var low := _dirty(top, float(o["dirt"]) * 0.5)
	var w: float = o["wide"]
	var r1 := lerpf(0.062, 0.105, w) * (float(o["pad"]) if w < 0.1 else 1.0)
	BodyMesh.ellipsoid(st, Vector3.ZERO, Vector3(0.075, 0.075, 0.075) * float(o["pad"]), top)
	BodyMesh.loft(st, [
		[0.0, 0.07, 0.07], [-0.13, lerpf(0.066, 0.088, w), lerpf(0.066, 0.088, w)], [-0.27, r1, r1],
	], 12, top, low)
	if o["roll"]:
		# 걷어 올린 소맷단
		BodyMesh.loft(st, [[-0.235, r1 + 0.006, r1 + 0.006], [-0.27, r1 + 0.009, r1 + 0.009]], 12, low, low)


func _b_arm_low(st: SurfaceTool, o: Dictionary, side: float) -> void:
	var skin: Color = o["skin"]
	var w: float = o["wide"]
	if o["roll"]:
		BodyMesh.loft(st, [[0.0, 0.04, 0.037], [-0.24, 0.031, 0.029]], 10, skin, skin)
	else:
		var top: Color = o["top"]
		var low := _dirty(top, float(o["dirt"]) * 0.5)
		var r_el := lerpf(0.062, 0.105, w)
		var r_mid := lerpf(0.058, 0.12, w)
		var r_cuff := lerpf(0.05, 0.15, w)
		BodyMesh.loft(st, [[0.0, r_el, r_el], [-0.12, r_mid, r_mid], [-0.25, r_cuff, r_cuff]], 12, top, low)
		if o["female"]:
			var cuff: Color = o["cuff"]
			BodyMesh.loft(st, [[-0.2, r_cuff + 0.004, r_cuff + 0.004], [-0.27, r_cuff + 0.004, r_cuff + 0.004]], 12, cuff, cuff)
	BodyMesh.ellipsoid(st, Vector3(0.0, -0.29, 0.0), Vector3(0.031, 0.05, 0.017), skin, 0.0, PI, 0.0, TAU, 5, 8)
	BodyMesh.ellipsoid(st, Vector3(-side * 0.027, -0.27, 0.012), Vector3(0.011, 0.026, 0.011), skin, 0.0, PI, 0.0, TAU, 4, 8)


func _b_thigh(st: SurfaceTool, o: Dictionary) -> void:
	var pants: Color = o["bottom"]
	var low := _dirty(pants, o["dirt"])
	BodyMesh.loft(st, [
		[0.04, 0.118, 0.115], [-0.2, 0.108, 0.105], [-0.39, 0.088, 0.088],
	], 12, pants, low)


func _b_shin(st: SurfaceTool, o: Dictionary) -> void:
	var pants: Color = o["bottom"]
	var low := _dirty(pants, o["dirt"])
	var skin: Color = o["skin"]
	var shoe: String = o["shoe"]
	var female: bool = o["female"]
	var white := Color(0.88, 0.86, 0.8, 1.0)
	if female:
		BodyMesh.loft(st, [[-0.3, 0.044, 0.045], [-0.37, 0.04, 0.042]], 10, white, white)
	elif o["rolled"]:
		# 바짓단을 무릎 아래로 걷어 올려 종아리가 보인다
		BodyMesh.loft(st, [[0.0, 0.088, 0.088], [-0.12, 0.078, 0.08]], 12, pants, low)
		BodyMesh.loft(st, [[-0.11, 0.084, 0.086], [-0.14, 0.084, 0.086]], 12, low, low)
		BodyMesh.loft(st, [[-0.13, 0.062, 0.064], [-0.2, 0.058, 0.06], [-0.33, 0.04, 0.042], [-0.37, 0.036, 0.04]], 10, skin, skin)
	else:
		BodyMesh.loft(st, [[0.0, 0.088, 0.088], [-0.15, 0.074, 0.076], [-0.29, 0.055, 0.056]], 12, pants, low)
		var band := _dirty(pants, 0.35)  # 대님
		BodyMesh.loft(st, [[-0.275, 0.059, 0.06], [-0.305, 0.059, 0.06]], 10, band, band)
		BodyMesh.loft(st, [[-0.3, 0.044, 0.045], [-0.37, 0.04, 0.042]], 10, white, white)
	match shoe:
		"straw":
			var straw := Color(0.62, 0.5, 0.28, 1.0)
			BodyMesh.ellipsoid(st, Vector3(0.0, -0.425, 0.05), Vector3(0.043, 0.03, 0.115), straw, 0.0, PI, 0.0, TAU, 5, 10)
			var cord := Color(0.5, 0.4, 0.2, 1.0)
			BodyMesh.loft(st, [[-0.36, 0.05, 0.052], [-0.39, 0.05, 0.052]], 10, cord, cord)
		"boot":
			var leather := Color(0.06, 0.05, 0.05, 0.0)
			BodyMesh.loft(st, [[-0.27, 0.058, 0.06], [-0.37, 0.05, 0.052]], 10, leather, leather)
			BodyMesh.ellipsoid(st, Vector3(0.0, -0.425, 0.055), Vector3(0.046, 0.035, 0.12), leather, 0.0, PI, 0.0, TAU, 5, 10)
		_:
			var cloth_shoe := Color(0.1, 0.1, 0.16, 1.0)
			BodyMesh.ellipsoid(st, Vector3(0.0, -0.425, 0.05), Vector3(0.04, 0.03, 0.105), cloth_shoe, 0.0, PI, 0.0, TAU, 5, 10)


## 지게: 등에 멘 나무틀. load는 1 돌, 2 나뭇짐. 틀 모양은 설계값이다.
func _b_frame(st: SurfaceTool, load_k: int) -> void:
	var wood := Color(0.32, 0.22, 0.14, 0.0)
	for sgn in [-1.0, 1.0]:
		var s: float = sgn
		BodyMesh.box(st, Vector3(s * 0.12, 0.3, -0.2), Vector3(0.03, 0.62, 0.03), wood, Vector3(0.15, 0.0, 0.0))
		BodyMesh.box(st, Vector3(s * 0.12, 0.43, -0.07), Vector3(0.03, 0.02, 0.26), wood)
	for y in [0.1, 0.34, 0.54]:
		var yy: float = y
		BodyMesh.box(st, Vector3(0.0, yy, -0.2), Vector3(0.26, 0.025, 0.025), wood)
	BodyMesh.box(st, Vector3(0.0, 0.08, -0.36), Vector3(0.34, 0.02, 0.3), wood)
	if load_k == 2:
		var stick := Color(0.4, 0.3, 0.18, 0.0)
		for i in 7:
			var dx := (float(i) - 3.0) * 0.045
			BodyMesh.box(st, Vector3(dx, 0.38, -0.34), Vector3(0.035, 0.6, 0.035), stick, Vector3(0.05 * float(i % 3 - 1), 0.0, 0.0))
	else:
		BodyMesh.box(st, Vector3(0.0, 0.23, -0.36), Vector3(0.34, 0.26, 0.28), Color(0.56, 0.54, 0.5, 0.0))


## 창: 오른손 앞에 세워 든다. 길이와 모양은 설계값(사료 미확인).
func _b_spear(st: SurfaceTool) -> void:
	var wood := Color(0.36, 0.25, 0.15, 0.0)
	var steel := Color(0.62, 0.64, 0.66, 0.0)
	var base := Vector3(0.2, 0.0, 0.34)
	BodyMesh.box(st, base + Vector3(0.0, 0.6, 0.0), Vector3(0.028, 2.0, 0.028), wood)
	BodyMesh.box(st, base + Vector3(0.0, 1.68, 0.0), Vector3(0.04, 0.2, 0.012), steel)
	BodyMesh.box(st, base + Vector3(0.0, 1.8, 0.0), Vector3(0.022, 0.08, 0.01), steel)
	BodyMesh.box(st, base + Vector3(0.0, 1.55, 0.0), Vector3(0.04, 0.06, 0.04), Color(0.55, 0.12, 0.1, 0.0))


# --- 동작 ---

func _reset_pose() -> void:
	_hips.position.y = HIP_Y
	_hips.position.x = 0.0
	_hips.rotation = Vector3.ZERO
	_spine.rotation = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	for i in 2:
		_sh[i].rotation = Vector3.ZERO
		_el[i].rotation = Vector3.ZERO
		_th[i].rotation = Vector3.ZERO
		_kn[i].rotation = Vector3.ZERO


## 신분별 활동 시각 [시작, 끝]. 해 뜰 무렵부터 해 질 무렵까지가 기본이고 수치는 설계값이다(사료 없음).
func _awake_window() -> Vector2:
	match kind:
		Kind.WORKER, Kind.MASON, Kind.PORTER:
			return Vector2(5.5, 19.0)
		Kind.WOMAN, Kind.MAID:
			return Vector2(5.0, 20.5)
		Kind.CHILD:
			return Vector2(6.5, 19.0)
		Kind.OFFICIAL:
			return Vector2(6.5, 19.5)
		Kind.YANGBAN, Kind.KING:
			return Vector2(7.0, 21.0)
		Kind.SOLDIER:
			return Vector2(0.0, 24.0)
	return Vector2(0.0, 24.0)


## 가까이 있고 보일 때만 목소리를 낸다.
func _voice_tick() -> void:
	if _voice == null:
		return
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_squared_to(global_position) < 20.0 * 20.0
	var on := near and is_visible_in_tree()
	if on and not _voice.playing:
		_voice.play(randf() * 3.0)
	elif not on and _voice.playing:
		_voice.stop()


func _nearest_home() -> Vector2:
	var best := Vector2(INF, INF)
	var bd := INF
	var me := Vector2(position.x, position.z)
	for hp in HanyangCity.house_points:
		var d := me.distance_to(hp)
		if d < bd:
			bd = d
			best = hp
	return best


func _update_schedule() -> void:
	if _jit == 0.0:
		_jit = (fmod(absf(position.x * 12.9898 + position.z * 78.233), 1.0) - 0.5) * 1.6
	var h: float = DayNight.hour_now
	if patrol:
		visible = h >= 22.0 or h < 4.0
		return
	var w := _awake_window()
	var a := w.x + _jit
	var b := w.y + _jit
	if not _sched_init:
		_sched_init = true
		_home = _nearest_home()
		_saved_act = act
		_saved_ra = route_a
		_saved_rb = route_b
		_saved_pos = Vector2(position.x, position.z)
	var me := _saved_pos
	var has_home := _home.x != INF and me.distance_to(_home) < 45.0
	var lead := 0.0
	if has_home:
		lead = clampf(me.distance_to(_home) / (1.6 * DayNight.sec_per_hour), 0.2, 3.0)
	var want := 0
	if h < a - lead or h >= b:
		want = 2
	elif h < a:
		want = 3
	elif h >= b - lead:
		want = 1
	if not has_home and want != 0:
		want = 0 if (h >= a and h < b) else 2
	if want == _state:
		return
	_enter_state(want, has_home)


func _enter_state(want: int, has_home: bool) -> void:
	match want:
		0:
			if _state == 3 or _state == 1:
				position = Vector3(_saved_pos.x, HanyangMap.stand(_saved_pos.x, _saved_pos.y) + lift, _saved_pos.y)
			act = _saved_act
			route_a = _saved_ra
			route_b = _saved_rb
			visible = true
		1:
			_saved_pos = Vector2(position.x, position.z) if _state == 0 else _saved_pos
			act = Act.WALK
			route_a = Vector2.ZERO
			route_b = Vector2.ZERO
			if not _plan_trip(Vector2(position.x, position.z), _home, true):
				visible = false
				want = 2
				_state = 2
				return
			visible = true
		2:
			visible = false
			if _state == 0:
				_saved_pos = Vector2(position.x, position.z)
		3:
			position = Vector3(_home.x, HanyangMap.stand(_home.x, _home.y), _home.y)
			act = Act.WALK
			route_a = Vector2.ZERO
			route_b = Vector2.ZERO
			if not _plan_trip(_home, _saved_pos, false):
				position = Vector3(_saved_pos.x, HanyangMap.stand(_saved_pos.x, _saved_pos.y) + lift, _saved_pos.y)
				act = _saved_act
				route_a = _saved_ra
				route_b = _saved_rb
				visible = true
				want = 0
				_state = 0
				return
			visible = true
	_state = want



# --- 부딪힘: 몸은 단단한 벽이 아니라 밀리고 휘청이다 ---
## 사람과 사람이 부딪히면 (1) 가벼운 쪽·버티지 않는 쪽이 밀려나고(운동량), (2) 윗몸이 젖혀지고 팔이 허우적거리며,
## (3) 잠시 멈춰 부딪힌 쪽을 쳐다보고, (4) 신분과 상황에 맞는 말이 나온다(걷다 부딪히면 가볍게, 달려와 부딪히면 크게).
## 밀림 세기·시간·말은 모두 설계값이다(docs/고증_근거.md 31장).

const LINES_SOFT := {
	"worker": ["아, 미안하오.", "허허, 앞 좀 보시오.", "어이쿠."],
	"official": ["험, 조심하게.", "어허."],
	"yangban": ["어허, 조심하게.", "험."],
	"woman": ["아이고, 죄송합니다.", "어머, 미안해요."],
	"maid": ["송구합니다.", "어맛."],
	"child": ["앗, 죄송해요.", "앗!"],
	"soldier": ["물러서시오.", "길을 비키시오."],
}
const LINES_HARD := {
	"worker": ["아이쿠!", "어이쿠, 눈은 어디 두고 다니시오!", "에그머니!"],
	"official": ["어허, 무엄하다!", "이게 무슨 짓인가!"],
	"yangban": ["이런 고약한!", "어허, 무엄하구나!"],
	"woman": ["어머나!", "에구머니나!"],
	"maid": ["어맛!", "송구하옵니다…"],
	"child": ["으앙!", "앗, 아파!"],
	"soldier": ["멈추시오!", "무슨 짓이오!"],
}


func _line_group() -> String:
	match kind:
		Kind.OFFICIAL:
			return "official"
		Kind.YANGBAN:
			return "yangban"
		Kind.WOMAN:
			return "woman"
		Kind.MAID:
			return "maid"
		Kind.CHILD:
			return "child"
		Kind.SOLDIER:
			return "soldier"
	return "worker"


func _ready() -> void:
	if kind == Kind.PROTAGONIST or get_parent() is Npc:
		return
	# 플레이어가 사람을 통과하지 못하도록 몸통 충돌체(층 2)를 둔다. 가까울 때만 켠다.
	_body = StaticBody3D.new()
	_body.collision_layer = 0
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	_body.add_child(cs)
	add_child(_body)


func _player_node() -> Node3D:
	if _pl == null or not is_instance_valid(_pl):
		_pl = get_tree().get_first_node_in_group("player") as Node3D
	return _pl


func _social_tick(delta: float) -> void:
	if kind == Kind.PROTAGONIST or act == Act.LOCO or prostrate:
		return
	var pl := _player_node()
	if pl == null:
		return
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_hold = maxf(_hold - delta, 0.0)
	_contact_tick += 1
	var vis := is_visible_in_tree()
	var me := global_position
	var to := Vector2(pl.global_position.x - me.x, pl.global_position.z - me.z)
	var d2 := to.length_squared()
	if _contact_tick % 8 == 0 and _body != null:
		_body.collision_layer = 2 if (vis and d2 < 400.0) else 0
	if _bubble != null and _bubble.visible:
		_bubble_t -= delta
		_bubble.modulate.a = clampf(_bubble_t / 0.4, 0.0, 1.0)
		if _bubble_t <= 0.0:
			_bubble.visible = false
	if not vis:
		return
	var npc_child := get_parent() is Npc
	# 밀려난 몸이 감속하며 멈춘다. 막히면 그 자리에서 멈춘다.
	if _shove.length_squared() > 0.0004:
		_shove *= exp(-5.0 * delta)
		var step := _shove * delta
		if WalkGuard.clear(self, Vector2(position.x, position.z), step.normalized(), position.y):
			position.x += step.x
			position.z += step.y
		else:
			_shove = Vector2.ZERO
	else:
		_shove = Vector2.ZERO
	_lean *= exp(-4.5 * delta)
	# 멈춰서 부딪힌 쪽을 본다
	if _hold > 0.0 and not npc_child and d2 > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.y), minf(delta * 6.0, 1.0))
	# 서서 일하던 사람은 밀린 뒤 제자리로 천천히 돌아간다 (플레이어가 바싹 붙어 있으면 기다린다)
	if _anchor.x != INF and _hold <= 0.0 and _shove == Vector2.ZERO:
		if act == Act.WALK or act == Act.CARRY:
			_anchor = Vector2(INF, INF)
		elif d2 > 1.2:
			var cur := Vector2(position.x, position.z)
			var dv := _anchor - cur
			if dv.length() < 0.06:
				position.x = _anchor.x
				position.z = _anchor.y
				_anchor = Vector2(INF, INF)
			else:
				var mv := dv.normalized() * minf(0.8 * delta, dv.length())
				position.x += mv.x
				position.z += mv.y
	# 접촉
	if _bump_cd <= 0.0 and d2 < BUMP_DIST * BUMP_DIST and absf(pl.global_position.y - me.y) < 1.3:
		_bump(pl, to, npc_child)


func _bump(pl: Node3D, to: Vector2, npc_child: bool) -> void:
	_bump_cd = 2.5
	var away := -to.normalized() if to.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
	# 부딪힌 세기: 플레이어가 가려는 속도 + 이쪽이 걷던 속도 (둘 다 서 있어도 최소값)
	var s := 1.5
	var intent = pl.get("intent_speed")
	if intent != null:
		s = maxf(s, float(intent))
	if act == Act.WALK or act == Act.CARRY:
		s += speed
	var mass := 1.0
	match kind:
		Kind.SOLDIER:
			mass = 0.4
		Kind.CHILD:
			mass = 1.4
		Kind.WOMAN, Kind.MAID:
			mass = 1.15
	var carrying := act == Act.CARRY
	if carrying:
		mass *= 0.9
	var hard := s >= 7.5
	if not npc_child:
		_shove = away * clampf((0.5 + 0.4 * s) * mass, 0.5, 4.5)
		if _anchor.x == INF:
			_anchor = Vector2(position.x, position.z)
	_lean = away * clampf((0.10 + 0.045 * s) * mass * (1.4 if carrying else 1.0), 0.1, 0.55)
	_hold = (1.8 if hard else 1.1) + randf() * 0.5
	var pool: Array = (LINES_HARD if hard else LINES_SOFT)[_line_group()]
	_say(String(pool[randi() % pool.size()]), 2.2 if hard else 1.8)


func _say(text: String, secs: float) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.position = Vector3(0.0, 2.15, 0.0)
		_bubble.font_size = 44
		_bubble.pixel_size = 0.0045
		_bubble.outline_size = 12
		_bubble.outline_modulate = Color(0.1, 0.06, 0.03, 0.95)
		_bubble.no_depth_test = true
		_bubble.render_priority = 5
		add_child(_bubble)
	_bubble.text = text
	_bubble.modulate = Color(1.0, 0.96, 0.82, 1.0)
	_bubble.visible = true
	_bubble_t = secs


## 부딪힌 뒤 윗몸이 젖혀지고 팔이 허우적거린다 (자세 계산이 끝난 뒤에 얹는다)
func _apply_lean() -> void:
	if _rig == null:
		return
	if _lean.length_squared() < 0.00004:
		if _rig.rotation != Vector3.ZERO:
			_rig.rotation = Vector3.ZERO
		return
	var lv := global_transform.basis.inverse() * Vector3(_lean.x, 0.0, _lean.y)
	_rig.rotation = Vector3(lv.z, 0.0, -lv.x)
	if _sh.size() >= 2:
		var m := minf(_lean.length() * 2.5, 1.0)
		_sh[0].rotation.z -= m
		_sh[1].rotation.z += m

## 막힌 곳을 비켜 가는 방향. 갈 곳이 없으면 Vector2.ZERO를 돌려주고 막힌 시간을 쌓는다.
func _guard_dir(dir: Vector2, delta: float) -> Vector2:
	_gd_t -= delta
	if _gd_t <= 0.0:
		_gd_t = 0.1
		_gd_off = WalkGuard.steer(self, Vector2(position.x, position.z), dir, position.y)
	if _gd_off == INF:
		_gd_stuck += delta
		return Vector2.ZERO
	_gd_stuck = maxf(_gd_stuck - delta * 3.0, 0.0)
	return dir.rotated(_gd_off)


## 집에 오가는 길을 정한다: 마당 문과 궁성·성문 같은 열린 문을 거친다. 건널 수 없으면 false.
func _plan_trip(from: Vector2, to: Vector2, going_home: bool) -> bool:
	_wp.clear()
	_gd_stuck = 0.0
	var pts: Array[Vector2] = []
	if going_home:
		var appr := TownNav.yard_approach(to)
		var r = TownNav.route(from, appr)
		if r == null:
			return false
		pts.append_array(r)
		pts.append(TownNav.yard_gate(to))
		pts.append(to)
	else:
		pts.append(TownNav.yard_gate(from))
		var appr2 := TownNav.yard_approach(from)
		pts.append(appr2)
		var r2 = TownNav.route(appr2, to)
		if r2 == null:
			return false
		pts.append_array(r2)
	_trip_target = pts[0]
	pts.remove_at(0)
	_wp = pts
	return true


## 집으로 가거나 집에서 나오는 길을 걷는다. 도착했는지에 따라 상태를 바꾼다.
func _step_trip(delta: float) -> float:
	if _hold > 0.0:
		return 0.0
	var cur := Vector2(position.x, position.z)
	var dir := _trip_target - cur
	if dir.length() < (0.8 if _wp.is_empty() else 1.1):
		if not _wp.is_empty():
			_trip_target = _wp.pop_front()
			return 0.0
		if _state == 1:
			visible = false
			_state = 2
		else:
			act = _saved_act
			route_a = _saved_ra
			route_b = _saved_rb
			_state = 0
		return 0.0
	var near_door := _state == 1 and _wp.is_empty() and dir.length() < 3.5  # 마당 안 집 앞에서는 비켜 가지 않고 들어간다
	dir = dir.normalized()
	var gd := dir if near_door else _guard_dir(dir, delta)
	if gd == Vector2.ZERO:
		if _gd_stuck > 4.0:
			# 오래 막히면 길을 마친 것으로 친다 (보이지 않는 곳에서 이어진다)
			_gd_stuck = 0.0
			if _state == 1:
				visible = false
				_state = 2
			else:
				position = Vector3(_saved_pos.x, HanyangMap.stand(_saved_pos.x, _saved_pos.y) + lift, _saved_pos.y)
				act = _saved_act
				route_a = _saved_ra
				route_b = _saved_rb
				_state = 0
		return 0.0
	dir = gd
	var spd := 1.6
	var step := dir * spd * delta
	position = Vector3(position.x + step.x, HanyangMap.stand(position.x + step.x, position.z + step.y), position.z + step.y)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), minf(delta * 6.0, 1.0))
	return spd


## 계절이 바뀌어 옷차림 구간이 달라졌을 때 몸을 다시 조립한다. 메시는 캐시되므로 처음 한 번만 비싸다.
func _refresh_outfit() -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = null
	_sh.clear()
	_el.clear()
	_th.clear()
	_kn.clear()
	_lids.clear()
	_voice = null
	_mouth = null
	_skirt = null
	_blink_t = -1.0
	_build()


func _process(delta: float) -> void:
	_band_check -= delta
	if _band_check <= 0.0:
		_band_check = 4.0 + randf() * 3.0
		if season_band() != _band:
			_refresh_outfit()
	if (scheduled or _voice != null) and act != Act.LOCO:
		_sched_tick += 1
		if _sched_tick % 30 == 1:
			if scheduled:
				_update_schedule()
			_voice_tick()
	_social_tick(delta)
	if _rig == null or not is_visible_in_tree():
		return
	var trip_v := 0.0
	if scheduled and (_state == 1 or _state == 3) and not prostrate:
		trip_v = _step_trip(delta)
	if act != Act.LOCO:
		var cam := get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(global_position) > ANIM_RANGE * ANIM_RANGE:
			return
	_t += delta
	_animate_face(delta)
	var v := 0.0
	match act:
		Act.WALK, Act.CARRY:
			if prostrate:
				v = 0.0
			else:
				v = trip_v if (_state == 1 or _state == 3) else _walk_route(delta)
		Act.LOCO:
			v = _loco_speed
	_reset_pose()
	match act:
		Act.IDLE:
			_pose_idle()
		Act.TALK:
			_pose_talk()
		Act.HAMMER:
			_pose_hammer()
		Act.SIT:
			_pose_sit()
		Act.WASH:
			_pose_wash()
		Act.DRAW:
			_pose_draw()
		Act.PLANE:
			_pose_plane()
		Act.TAMP:
			_pose_tamp()
		Act.KITE:
			_pose_kite()
		Act.TOP:
			_pose_top()
		Act.DRILL:
			_pose_drill()
		_:
			if act == Act.LOCO and water_pose == 1:
				_pose_row()
			elif act == Act.LOCO and water_pose == 2:
				_pose_swim()
			elif act == Act.LOCO and not _grounded:
				_pose_air()
			elif v > 0.15:
				_pose_walk(v, delta)
			else:
				_pose_idle()
	if _stoop > 0.001:
		# 나이 든 사람과 짐 지는 사람은 등이 굽는다
		_spine.rotation.x += _stoop
		_head.rotation.x -= _stoop * 0.8
	if kind == Kind.SOLDIER:
		# 창을 든 오른팔은 걸을 때도 고정한다
		_sh[1].rotation = Vector3(-0.35, 0.0, 0.05)
		_el[1].rotation = Vector3(-1.0, 0.0, 0.0)
	if swing >= 0.0 and swing <= 1.0 and _sh.size() >= 2:
		_pose_swing(swing)
	if aim >= 0.0 and _sh.size() >= 2:
		_pose_aim(aim)
	_gaze_and_greet(delta)
	_pro_k = move_toward(_pro_k, 1.0 if prostrate else 0.0, delta * 1.5)
	if _pro_k > 0.001:
		_pose_kowtow(smoothstep(0.0, 1.0, _pro_k))
	_fall_k = move_toward(_fall_k, 1.0 if fallen else 0.0, delta * (5.0 if fallen else 1.3))
	if _fall_k > 0.001:
		_pose_fallen(smoothstep(0.0, 1.0, _fall_k))
	_apply_lean()
	_cloth_update(delta, v)


func _walk_route(delta: float) -> float:
	if route_a == route_b or _hold > 0.0:
		return 0.0
	var target := route_b if _to_b else route_a
	var cur := Vector2(position.x, position.z)
	var dir := target - cur
	if dir.length() < 0.6:
		_to_b = not _to_b
		return 0.0
	dir = dir.normalized()
	var gd := _guard_dir(dir, delta)
	if gd == Vector2.ZERO:
		if _gd_stuck > 2.0:
			_gd_stuck = 0.0
			_to_b = not _to_b
		return 0.0
	dir = gd
	var step := dir * speed * delta
	var nx := position.x + step.x
	var nz := position.z + step.y
	position = Vector3(nx, HanyangMap.stand(nx, nz) + lift, nz)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), minf(delta * 6.0, 1.0))
	return speed


## 오른손에 쥔 연장을 휘두른다. p 는 0~1: 0~0.38 치켜들기, 0.38~0.55 빠르게 내려침, 이후 되돌림.
func _pose_swing(p: float) -> void:
	var w := 0.0
	if p < 0.38:
		w = smoothstep(0.0, 1.0, p / 0.38)
	elif p < 0.55:
		w = 1.0 - (p - 0.38) / 0.17
	else:
		w = 0.0
	if swing_kind == 0:
		_sh[1].rotation = Vector3(lerpf(-0.5, -2.6, w), 0.0, 0.12)
		_el[1].rotation.x = lerpf(-0.3, -0.9, w)
		_spine.rotation.x += lerpf(0.18, -0.12, w)
	elif swing_kind == 2:
		# 찌르기: 팔꿈치를 접어 뒤로 당겼다가 곧게 내민다
		_sh[1].rotation = Vector3(lerpf(-1.55, -0.5, w), 0.0, 0.05)
		_el[1].rotation.x = lerpf(-0.1, -1.9, w)
		_spine.rotation.x += lerpf(0.12, -0.08, w)
	else:
		_sh[1].rotation = Vector3(lerpf(-1.0, -1.7, w), 0.0, lerpf(-0.1, 0.9, w))
		_el[1].rotation.x = lerpf(-0.4, -0.8, w)
		_spine.rotation.y += lerpf(0.0, 0.35, w) - 0.2
	_sh[0].rotation.x = -0.35


## 활 쏘기 자세 (사법8절 중 들어올리기~만작). 몸은 옆으로 서서 얼굴만 과녁을 보고,
## 왼팔(줌팔)은 곧게 뻗어 활을 밀고, 오른팔(깍지손)은 팔꿈치를 뒤로 접어 귀 곁까지 당긴다. [설계]
func _pose_aim(a: float) -> void:
	var k := smoothstep(0.0, 1.0, clampf(a, 0.0, 1.0))
	_sh[0].rotation = Vector3(-1.5, 0.0, -0.04)
	_el[0].rotation.x = -0.04
	_sh[1].rotation = Vector3(-1.45, 0.0, lerpf(0.15, 1.25, k))
	_el[1].rotation.x = lerpf(-0.3, -2.35, k)
	_spine.rotation.x = 0.04
	_spine.rotation.y += 0.55 * minf(1.0, a * 3.0)
	_head.rotation.y -= 0.55 * minf(1.0, a * 3.0)


## 오른손(아래팔 끝) 자리. 들고 있는 연장을 여기에 붙인다.
func hand() -> Node3D:
	return _el[1] if _el.size() >= 2 else null


## 왼손(아래팔 끝) 자리. 활을 여기에 쥔다.
func hand_l() -> Node3D:
	return _el[0] if _el.size() >= 2 else null


func _pose_idle() -> void:
	var breath := sin(_t * 1.7 + _phase)
	_spine.rotation.x = 0.015 * breath
	_hips.rotation.z = 0.02 * sin(_t * 0.4 + _phase)
	_head.rotation.y = 0.12 * sin(_t * 0.5 + _phase)
	_sh[0].rotation.z = -0.08
	_sh[1].rotation.z = 0.08
	_el[0].rotation.x = -0.12
	_el[1].rotation.x = -0.12


func _pose_talk() -> void:
	_pose_idle()
	_sh[1].rotation.x = -0.5 + 0.2 * sin(_t * 2.2 + _phase)
	_sh[1].rotation.z = 0.25
	_el[1].rotation.x = -1.1 + 0.3 * sin(_t * 3.1 + _phase)
	_head.rotation.x = 0.05 * sin(_t * 2.7)


func _pose_hammer() -> void:
	# 오른팔을 천천히 들어 올렸다가 빠르게 내려친다. 왼팔은 정을 잡는다.
	var p := fposmod(_t * 1.6 + _phase, 1.0)
	var swing := 0.0
	if p < 0.7:
		swing = smoothstep(0.0, 1.0, p / 0.7)
	else:
		var q := (p - 0.7) / 0.3
		swing = 1.0 - q * q
	_sh[1].rotation.x = lerpf(-0.7, -2.3, swing)
	_el[1].rotation.x = lerpf(-0.2, -1.2, swing)
	_sh[1].rotation.z = 0.1
	_sh[0].rotation.x = -0.9
	_sh[0].rotation.z = -0.1
	_el[0].rotation.x = -0.7
	_spine.rotation.x = 0.28 + 0.1 * (1.0 - swing)
	_head.rotation.x = -0.15
	for i in 2:
		_th[i].rotation.x = -0.35
		_kn[i].rotation.x = 0.7
	_hips.position.y = HIP_Y - 0.05


## 부복(엎드려 절함): 무릎을 꿇고 상체를 숙여 두 손을 앞 땅에 짚고 이마를 낮춘다. k 는 0~1 로 자세에 들어가는 정도.
## 어가가 지나는 동안 길가의 백성이 이 자세를 취했다 (고증_근거.md 43장, 설계 묘사).
func _pose_kowtow(k: float) -> void:
	_hips.position.y = lerpf(_hips.position.y, 0.3, k)
	_hips.position.x = 0.0
	var br := 0.02 * sin(_t * 1.3 + _phase) * k
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = _th[i].rotation.lerp(Vector3(-0.15, 0.0, s * 0.06), k)
		_kn[i].rotation = _kn[i].rotation.lerp(Vector3(2.5, 0.0, 0.0), k)
		_sh[i].rotation = _sh[i].rotation.lerp(Vector3(-2.7, 0.0, s * 0.18), k)
		_el[i].rotation = _el[i].rotation.lerp(Vector3(-0.15, 0.0, 0.0), k)
	_spine.rotation = _spine.rotation.lerp(Vector3(1.3 + br, 0.0, 0.0), k)
	_head.rotation = _head.rotation.lerp(Vector3(0.45, 0.0, 0.0), k)


## 쓰러짐: 뒤로 넘어져 등을 대고 눕고, 두 팔은 막으려 위로 벌린다. k 는 0~1.
func _pose_fallen(k: float) -> void:
	_hips.position.y = lerpf(_hips.position.y, 0.2, k)
	_hips.rotation.x = lerpf(_hips.rotation.x, -1.5, k)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_sh[i].rotation = _sh[i].rotation.lerp(Vector3(-2.2, 0.0, s * 0.5), k)
		_el[i].rotation = _el[i].rotation.lerp(Vector3(-0.5, 0.0, 0.0), k)
		_th[i].rotation = _th[i].rotation.lerp(Vector3(-0.2, 0.0, s * 0.25), k)
		_kn[i].rotation = _kn[i].rotation.lerp(Vector3(0.5, 0.0, 0.0), k)
	_head.rotation = _head.rotation.lerp(Vector3(-0.35, 0.0, 0.0), k)


func _pose_sit() -> void:
	_hips.position.y = 0.24
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-1.5, 0.0, s * 0.55)
		_kn[i].rotation.x = 2.4
		_sh[i].rotation = Vector3(-0.5, 0.0, s * 0.12)
		_el[i].rotation.x = -0.5
	_spine.rotation.x = 0.04 + 0.015 * sin(_t * 1.7 + _phase)
	_head.rotation.y = 0.12 * sin(_t * 0.5 + _phase)


## 배에 앉아 노를 당긴다 (다리는 앞으로 뻗고 팔은 앞뒤로 크게 젓는다).
func _pose_row() -> void:
	_hips.position.y = 0.26
	var k := sin(water_phase)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-1.45, 0.0, s * 0.18)
		_kn[i].rotation.x = 0.4
		_sh[i].rotation = Vector3(-1.15 - 0.55 * k, 0.0, s * 0.12)
		_el[i].rotation.x = -0.35 - 0.5 * (0.5 - 0.5 * k)
	_spine.rotation.x = 0.1 - 0.22 * k
	_head.rotation.x = 0.1 * k


## 평영(개구리헤엄) 한 번의 주기에서 구간별 세기. u 는 0~1 주기 위치.
## 사람이 헤엄치는 법(분석): ①팔 당기기(두 팔이 앞에서 양옆으로 벌어지며 물을 끌고, 머리와 어깨가 떠올라 숨을 쉰다)
## ②팔 모으기(두 손이 턱 밑으로 모이고 무릎이 배 쪽으로 접혀 올라온다) ③차기(두 다리가 바깥으로 휘돌며 뒤로 힘차게 펴지고 팔은 앞으로 뻗는다)
## ④미끄러지기(온몸을 곧게 펴고 나아간다). 속도는 차는 순간에 가장 빠르고 팔을 모을 때 가장 느리다.
## 조선 시대에는 자유형(크롤)이 없었고 개헤엄·평영 계열과 선헤엄(서서 헤엄), 누워헤엄이 쓰였다. (고증_근거.md 41장)
static func swim_pull(u: float) -> float:
	return smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.2, 0.4, u))


static func swim_gather(u: float) -> float:
	return smoothstep(0.3, 0.46, u) * (1.0 - smoothstep(0.5, 0.6, u))


static func swim_kick(u: float) -> float:
	return smoothstep(0.5, 0.64, u) * (1.0 - smoothstep(0.72, 0.92, u))


## 헤엄치는 속도 배율: 찰 때 가장 빠르고 모을 때 가장 느리다. 평균은 약 1.
static func swim_surge(phase: float) -> float:
	var u := fposmod(phase / TAU, 1.0)
	return clampf(0.38 + 1.3 * swim_kick(u) + 0.35 * swim_pull(u) + 0.15 * (1.0 - swim_gather(u)), 0.35, 1.6) * 1.15


func _pose_swim() -> void:
	_swim_k = move_toward(_swim_k, swim_move, get_process_delta_time() * 2.5)
	var u := fposmod(water_phase / TAU, 1.0)
	var pull := swim_pull(u)
	var gather := swim_gather(u)
	var kick := swim_kick(u)
	var spread := 0.08 + 0.4 * smoothstep(0.4, 0.55, u) * (1.0 - smoothstep(0.58, 0.7, u))
	var trp := fposmod(water_phase * 0.5 / TAU, 1.0) * TAU  # 선헤엄 젓기 위상
	# --- 평영 ---
	var b_hips_y := 1.06
	var b_hips_x := 1.3 - 0.28 * pull + 0.08 * kick
	var b_head := -0.95 - 0.3 * pull
	# --- 선헤엄: 곧게 서서 가슴까지 잠기고 두 팔로 물을 젓고 다리를 번갈아 접었다 편다 ---
	var t_hips_y := 0.66 + 0.02 * sin(trp * 2.0)
	_hips.position.y = lerpf(t_hips_y, b_hips_y, _swim_k)
	_hips.rotation.x = lerpf(0.05, b_hips_x, _swim_k)
	_spine.rotation.x = lerpf(0.0, 0.0, _swim_k)
	_head.rotation.x = lerpf(0.0, b_head, _swim_k)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var ph := trp + float(i) * PI
		# 팔: 평영은 앞으로 곧게 뻗었다가 양옆으로 벌려 당기고 턱 밑으로 모은다
		var b_sh_x := -2.87 + 0.55 * pull + 0.95 * gather
		var b_sh_z := s * (0.14 + 0.95 * pull + 0.05 * gather)
		var b_el := -(0.1 + 0.8 * pull + 1.1 * gather)
		var t_sh_x := -0.3 + 0.25 * sin(ph * 2.0)
		var t_sh_z := s * (0.55 + 0.2 * cos(ph * 2.0))
		var t_el := -0.9 - 0.3 * sin(ph * 2.0)
		_sh[i].rotation = Vector3(lerpf(t_sh_x, b_sh_x, _swim_k), 0.0, lerpf(t_sh_z, b_sh_z, _swim_k))
		_el[i].rotation.x = lerpf(t_el, b_el, _swim_k)
		# 다리: 평영은 뒤로 곧게 뻗었다가 무릎을 접어 올리고(개구리) 바깥으로 휘돌며 모아 편다
		var b_th_x := 0.27 - 1.05 * gather * (1.0 - kick)
		var b_th_z := s * (spread + 0.25 * gather)
		var b_kn := 0.1 + 1.9 * gather * (1.0 - kick) + 0.3 * smoothstep(0.5, 0.6, u) * (1.0 - smoothstep(0.6, 0.72, u))
		var t_th_x := -0.55 - 0.35 * sin(ph)
		var t_th_z := s * 0.12
		var t_kn := 0.9 + 0.6 * sin(ph + 1.0)
		_th[i].rotation = Vector3(lerpf(t_th_x, b_th_x, _swim_k), 0.0, lerpf(t_th_z, b_th_z, _swim_k))
		_kn[i].rotation.x = lerpf(t_kn, b_kn, _swim_k)


## 빨래터에서 허리를 굽혀 빨래를 두드린다.
func _pose_wash() -> void:
	_hips.position.y = HIP_Y - 0.28
	_spine.rotation.x = 0.95
	_head.rotation.x = -0.35
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-1.2, 0.0, s * 0.25)
		_kn[i].rotation.x = 1.9
		var beat := sin(_t * 5.0 + _phase + float(i) * PI)
		_sh[i].rotation = Vector3(-0.6 + 0.25 * beat, 0.0, s * 0.08)
		_el[i].rotation.x = -0.5 - 0.25 * beat


## 우물에서 두레박 줄을 번갈아 당긴다.
func _pose_draw() -> void:
	_spine.rotation.x = 0.28
	var pull := sin(_t * 1.6 + _phase)
	_sh[0].rotation = Vector3(-1.1 + 0.5 * pull, 0.0, -0.1)
	_el[0].rotation.x = -0.9 - 0.5 * pull
	_sh[1].rotation = Vector3(-1.1 - 0.5 * pull, 0.0, 0.1)
	_el[1].rotation.x = -0.9 + 0.5 * pull
	_head.rotation.x = 0.12


## 목수가 긴 대패를 밀고 당긴다.
func _pose_plane() -> void:
	var stroke := sin(_t * 2.0 + _phase)
	_spine.rotation.x = 0.55 + 0.08 * stroke
	_hips.position.y = HIP_Y - 0.1
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-0.5, 0.0, s * 0.2)
		_kn[i].rotation.x = 0.7
		_sh[i].rotation = Vector3(-1.2 + 0.35 * stroke, 0.0, s * 0.06)
		_el[i].rotation.x = -0.6 - 0.2 * stroke
	_head.rotation.x = -0.25


## 달구질(판축) 박자: 모두가 함께 들어 올리고(0→1), 잠깐 멈췄다가 떨어뜨린다. 한 주기 1.8초는 설계값.
static func tamp_lift() -> float:
	var c := fposmod(Time.get_ticks_msec() * 0.001 / 1.8, 1.0)
	if c < 0.55:
		return smoothstep(0.0, 0.55, c)
	if c < 0.63:
		return 1.0
	if c < 0.7:
		return 1.0 - (c - 0.63) / 0.07
	return 0.0


## 여럿이 밧줄을 쥐고 달구(굵은 통나무 다지개)를 들었다 놓는다.
func _pose_tamp() -> void:
	var lift := tamp_lift()
	var down := 1.0 - lift
	_hips.position.y = HIP_Y - 0.16 * down
	_spine.rotation.x = -0.12 * lift + 0.18 * down
	_head.rotation.x = -0.2 * lift
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-0.35 * down, 0.0, s * 0.18)
		_kn[i].rotation.x = 0.6 * down
		_sh[i].rotation = Vector3(-0.7 - 0.9 * lift, 0.0, s * 0.12)
		_el[i].rotation.x = -0.3 - 0.4 * down


## 연날리기: 한 손을 높이 들고 하늘을 올려다보며 실을 당긴다 (정월 풍속).
func _pose_kite() -> void:
	_spine.rotation.x = -0.1
	_head.rotation.x = -0.55
	_sh[1].rotation = Vector3(-1.5 + 0.1 * sin(_t * 2.1 + _phase), 0.0, 0.18)
	_el[1].rotation.x = -0.35
	_sh[0].rotation = Vector3(-0.5 + 0.25 * sin(_t * 1.3 + _phase), 0.0, -0.1)
	_el[0].rotation.x = -0.9
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-0.12, 0.0, s * 0.14)
		_kn[i].rotation.x = 0.18


## 팽이치기: 쭈그려 앉아 채로 팽이를 때린다.
func _pose_top() -> void:
	_hips.position.y = HIP_Y - 0.3
	_spine.rotation.x = 0.55
	_head.rotation.x = -0.1
	var swing := sin(_t * 7.0 + _phase) * maxf(0.0, sin(_t * 1.1 + _phase * 2.0))
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation = Vector3(-1.1, 0.0, s * 0.3)
		_kn[i].rotation.x = 1.7
	_sh[1].rotation = Vector3(-0.8 + 0.7 * swing, 0.0, 0.1)
	_el[1].rotation.x = -0.6 - 0.3 * swing
	_sh[0].rotation = Vector3(-0.4, 0.0, -0.1)
	_el[0].rotation.x = -0.5


## 군졸 훈련: 모두가 같은 박자로 창을 겨누었다가 찌른다. 3초 주기는 설계값(조선 초 훈련 절차는 확인하지 못했다).
func _pose_drill() -> void:
	var cyc := fposmod(Time.get_ticks_msec() * 0.001 / 3.0, 1.0)
	var thrust := 0.0
	if cyc > 0.55 and cyc < 0.75:
		thrust = sin((cyc - 0.55) / 0.2 * PI)
	_spine.rotation.x = 0.12 + 0.3 * thrust
	_hips.position.y = HIP_Y - 0.1 - 0.12 * thrust
	_head.rotation.x = -0.1
	_th[0].rotation.x = -0.15 - 0.6 * thrust
	_kn[0].rotation.x = 0.1 + 0.5 * thrust
	_th[1].rotation.x = 0.3 * thrust
	_kn[1].rotation.x = 0.2 * thrust


## 플레이어 쪽으로 시선을 돌리고, 가까이 오면 한 번 고개를 숙여 인사한다.
func _gaze_and_greet(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var want_yaw := 0.0
	var want_pitch := 0.0
	var can_look := act == Act.IDLE or act == Act.TALK or act == Act.SIT or act == Act.WASH or act == Act.DRAW
	if cam != null and can_look and kind != Kind.PROTAGONIST:
		var lp := to_local(cam.global_position)
		var dist := lp.length()
		if dist < 8.0 and lp.z > -1.0:
			want_yaw = clampf(atan2(lp.x, maxf(lp.z, 0.1)), -1.0, 1.0)
			want_pitch = clampf(-atan2(lp.y - 1.3, maxf(dist, 0.5)), -0.3, 0.3)
		# 인사: 가까워지면 처음 한 번
		_greet_cool = maxf(_greet_cool - delta, 0.0)
		if _greet_t < 0.0 and dist < 3.8 and _greet_cool <= 0.0 and act != Act.HAMMER:
			_greet_t = 0.0
			_greet_cool = 90.0
	_gaze_yaw = lerpf(_gaze_yaw, want_yaw, 1.0 - exp(-4.0 * delta))
	_gaze_pitch = lerpf(_gaze_pitch, want_pitch, 1.0 - exp(-4.0 * delta))
	_head.rotation.y += _gaze_yaw
	_head.rotation.x += _gaze_pitch
	# 표정: 일하는 사람은 지쳐 고개가 약간 숙고, 아이와 여인은 가볍게 고개를 든다
	match kind:
		Kind.WORKER, Kind.MASON, Kind.PORTER:
			_head.rotation.x += 0.06
		Kind.CHILD, Kind.WOMAN, Kind.MAID:
			_head.rotation.x -= 0.03
	if _greet_t >= 0.0:
		_greet_t += delta
		var q := _greet_t / 1.3
		if q >= 1.0:
			_greet_t = -1.0
		else:
			_spine.rotation.x += 0.35 * sin(q * PI)
			_head.rotation.x += 0.2 * sin(q * PI)


func _pose_air() -> void:
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_th[i].rotation.x = -0.6
		_kn[i].rotation.x = 0.9
		_sh[i].rotation = Vector3(-0.5, 0.0, s * 0.4)
		_el[i].rotation.x = -0.4
	_spine.rotation.x = 0.1


## 치마·도포 자락의 움직임. 사람의 옷이 자연스럽게 움직이는 방식(분석):
##  - 옷은 몸보다 늦게 따라온다: 걷기 시작하면 아랫단이 뒤로 처지고, 멈추면 앞으로 한 번 출렁이며 가라앉는다.
##  - 앞으로 나온 다리가 옷을 앞으로 밀어 치마·자락 앞이 불룩해지고, 다리를 바꿀 때 좌우로 흔들린다.
##  - 빨리 걸을수록 아랫단이 뒤로 많이 날리고 살짝 넓게 펼쳐진다.
## 스프링(강성 70, 감쇠 7.5)으로 풀어 낸 설계값이다. (고증_근거.md 42장)
func _cloth_update(delta: float, v: float) -> void:
	if _skirt == null or delta <= 0.0:
		return
	var dt := minf(delta, 0.05)
	var k := clampf(v / 5.0, 0.0, 1.6)
	var lead := 0.0
	if _th.size() == 2 and v > 0.15:
		lead = maxf(-_th[0].rotation.x, -_th[1].rotation.x)
	# 속도가 변하면 옷이 관성으로 늦게 따라온다
	_cv += clampf(v - _cloth_v, -1.0, 1.0) * 0.6
	_cloth_v = v
	var tx := 0.04 + 0.22 * k - 0.34 * lead * minf(k * 2.0, 1.0) + 0.012 * sin(_t * 1.3 + _phase)
	var tz := 0.07 * sin(_ph) * minf(k * 2.0, 1.0)
	_cv += ((tx - _cx) * 70.0 - _cv * 7.5) * dt
	_cx = clampf(_cx + _cv * dt, -0.45, 0.6)
	_czv += ((tz - _cz) * 70.0 - _czv * 7.5) * dt
	_cz = clampf(_cz + _czv * dt, -0.3, 0.3)
	_skirt.rotation = Vector3(_cx, 0.0, _cz)
	var flare := 1.0 + 0.05 * k + 0.04 * absf(_cv)
	# 다리가 옷을 뚫지 않도록: 다리가 앞뒤로 벌어진 만큼 치마·자락의 앞뒤 폭을 넓힌다 (옷이 다리에 밀려 불룩해지는 모양)
	var ext := 0.0
	if _th.size() == 2:
		ext = minf(maxf(absf(_th[0].rotation.x), absf(_th[1].rotation.x)), 0.7)
	_skirt.scale = Vector3(flare * (1.0 + 0.25 * ext), 1.0, flare * (1.0 + 1.25 * ext))


func _pose_walk(v: float, delta: float) -> void:
	var run := clampf((v - 3.0) / 3.0, 0.0, 1.0)
	var s := clampf(v / 1.3, 0.0, 1.0)
	var robe := 0.6 if _long else 1.0
	if kind == Kind.WOMAN or kind == Kind.MAID:
		robe = 0.55
	_ph += delta * v * lerpf(4.5, 3.2, run)
	var th_amp := lerpf(0.5, 0.95, run) * lerpf(0.6, 1.0, s) * robe
	var carry := act == Act.CARRY
	if carry:
		th_amp *= 0.8
	for i in 2:
		var pi_ := _ph + (PI if i == 0 else 0.0)
		_th[i].rotation.x = -sin(pi_) * th_amp
		# 무릎: 발이 닿을 때 조금 굽혀 충격을 받고(0.14), 다리가 앞으로 나올 때 가장 크게 접힌다
		var swing_flex := pow(maxf(0.0, cos(pi_ - 0.35)), 1.4)
		var load_flex := 0.14 * maxf(0.0, sin(pi_ + 0.9)) * maxf(0.0, -cos(pi_ - 0.35) + 0.2)
		_kn[i].rotation.x = swing_flex * lerpf(0.8, 1.5, run) * robe + load_flex + 0.05
		if carry:
			_sh[i].rotation.x = -0.35
			_el[i].rotation.x = -1.2
		else:
			_sh[i].rotation.x = sin(pi_) * lerpf(0.4, 0.8, run) * lerpf(0.6, 1.0, s)
			_el[i].rotation.x = -0.2 - run * 1.0 - 0.3 * maxf(0.0, -_sh[i].rotation.x) * lerpf(1.0, 0.6, run)
			_sh[i].rotation.z = (-0.06 if i == 0 else 0.06) * (1.0 + 0.5 * absf(sin(pi_)))
	# 몸통과 골반: 걸음 분석에 따라 (고증_근거.md 42장)
	#  - 골반이 위아래로 두 걸음에 한 번씩 오르내린다(발이 땅을 디딜 때 가장 낮고 몸 밑을 지날 때 가장 높다)
	#  - 몸 무게가 디딘 다리 쪽으로 옆으로 옮겨 가고(좌우 흔들림), 들린 다리 쪽 골반이 살짝 내려간다
	#  - 골반은 한 방향으로, 가슴은 반대로 비틀려 팔과 다리가 엇갈린다. 머리는 흔들림을 눌러 시선을 안정시킨다
	var sway := sin(_ph)
	_spine.rotation.x = (0.2 if carry else 0.03) + 0.18 * run
	_spine.rotation.y = sway * 0.12
	_spine.rotation.z = -sway * 0.025
	_hips.rotation.y = -sway * 0.07
	_hips.rotation.z = sway * 0.04
	_hips.position.x = -sway * 0.022 * lerpf(1.0, 0.7, run)
	_hips.position.y = HIP_Y + cos(2.0 * _ph) * 0.026 * (1.0 + run * 1.2)
	_head.rotation.x = -(0.05 + 0.1 * run) if not carry else -0.15
	_head.rotation.y = -_spine.rotation.y * 0.7 - _hips.rotation.y * 0.3
	_head.rotation.z = sway * 0.025
	_head.position.y = 0.55 - cos(2.0 * _ph) * 0.006
