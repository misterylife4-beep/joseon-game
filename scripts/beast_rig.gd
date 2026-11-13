class_name BeastRig
extends Node3D
## 들짐승 몸: 사슴·멧돼지·늑대·호랑이를 같은 뼈대로 만든다.
## 몸통(숨쉬기) - 목 - 머리(귀 둘, 아래턱) - 꼬리(마디 셋), 다리 넷(윗다리와 무릎).
## 걸음은 속도에 따라 걷기(네 박자) → 속보(대각선 쌍) → 질주(앞다리 쌍, 뒷다리 쌍, 등이 휨)로 이어진다.
## 노리는 자세(몸을 낮춤), 풀 뜯기(머리 숙임), 눕기, 도약(앞다리 쭉, 뒷다리 쭉), 입 벌림, 귀 젖힘이 있다.
## 크기·비율·색은 실제 동물의 몸길이·어깨높이·털색 자료를 따른 설계값이다. (고증_근거.md 47·48장)

enum Kind { DEER, BOAR, WOLF, TIGER }

signal stepped(leg: int)

## 소유자가 매 프레임 정해 주는 자세 값
var crouch := 0.0       ## 0 선 자세, 0.3 노려보는 자세, 1.4 이상 누움
var head_down := 0.0    ## 머리를 숙인 정도(풀 뜯기·땅 파기), 0~1
var head_turn := 0.0    ## 머리를 옆으로 돌림(라디안)
var jaw := 0.0          ## 입 벌림 0~1
var ear_back := 0.0     ## 귀 젖힘 0~1 (화났을 때)
var ear_alert := 0.0    ## 귀 쫑긋 0~1 (경계)
var tail_up := 0.0      ## 꼬리 치켜듦 0~1
var lunge := 0.0        ## 도약 자세 0~1
var pace := 1.0         ## 걸음 빠르기 배율

var kind := Kind.DEER
var young := false
var variant := 0

var _torso: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _ears: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _hip: Array[Node3D] = []
var _knee: Array[Node3D] = []
var _phase := 0.0
var _prev := [0.0, 0.0, 0.0, 0.0]
var _t := 0.0
var _flick := 0.0
var _flick_i := 0
var _h0 := 1.0           ## 서 있을 때 몸통 중심 높이
var _spec := {}
static var _mats := {}

const WALK_OFF := [0.0, 0.5, 0.75, 0.25]
const TROT_OFF := [0.0, 0.5, 0.5, 0.0]
const GALLOP_OFF := [0.0, 0.1, 0.5, 0.6]


static func make(k: int, var_i: int, is_young: bool) -> BeastRig:
	var r := BeastRig.new()
	r.kind = k as Kind
	r.variant = var_i
	r.young = is_young
	r._build()
	# 사람(키 약 1.6m)과 나란히 놓았을 때 위압감이 나도록 실제 크기보다 조금 키운다. [설계]
	var big := 1.3
	match r.kind:
		Kind.DEER:
			big = 1.2
		Kind.WOLF:
			big = 1.25
		Kind.TIGER:
			big = 2.2   # 사람 곁에서 압도적으로 보이도록 크게 키운다. [설계]
	r.scale = Vector3.ONE * big
	if is_young:
		r.scale = Vector3.ONE * 0.5 * big
		r._head.scale = Vector3.ONE * 1.22   # 새끼는 머리가 몸에 비해 크다
	return r


## 털 재질. mode 0은 민무늬, 1 몸통, 2 다리, 3 꼬리 (호랑이 줄무늬, fur.gdshader 참고)
static func fur_mat(mode: int = 0) -> ShaderMaterial:
	if not _mats.has(mode):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/fur.gdshader") as Shader
		m.set_shader_parameter("stripe_mode", mode)
		_mats[mode] = m
	return _mats[mode] as ShaderMaterial


# --- 만들기 ---

func _st() -> SurfaceTool:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	return s


func _e(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> void:
	BodyMesh.ellipsoid(st, c, r, col, 0.0, PI, 0.0, TAU, 8, 14)


## 점·무늬처럼 작은 것은 면을 적게 쓴다.
func _sp(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> void:
	BodyMesh.ellipsoid(st, c, r, col, 0.0, PI, 0.0, TAU, 3, 6)


func _node(parent: Node3D, pos: Vector3, st: SurfaceTool = null, mode: int = 0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	if st != null:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = fur_mat(mode)
		n.add_child(mi)
	return n


## 실제 크기 자료(어깨높이·몸길이)에 맞춘 값. 다리는 허벅지·팔뚝(lu), 정강이·발목(ll), 발(paw) 순이다.
## ur/lr은 윗다리·아랫다리 굵기, sk는 걸음 폭 배율, lie는 누웠을 때 몸통 높이, k_down은 머리를 땅까지 숙이는 정도.
func _build() -> void:
	match kind:
		Kind.DEER:
			# 꽃사슴: 어깨 약 0.95m, 다리 가늘고 정강이가 길다
			_spec = {"lu": 0.27, "ll": 0.31, "paw": 0.04, "hx": 0.1, "fz": 0.34, "hz": -0.38, "hy": 0.12, "ur": 0.06, "lr": 0.03, "pawr": Vector3(0.03, 0.02, 0.05),
				"trot": 1.8, "gallop": 5.0, "sk": 1.3, "lie": 0.2, "k_down": 1.65, "neck0": 0.0, "head0": 0.55, "tilt": -0.75, "tail_rest": [0.0]}
		Kind.BOAR:
			# 멧돼지: 어깨 약 0.9m, 몸은 옆으로 좁고 앞이 높다
			_spec = {"lu": 0.17, "ll": 0.2, "paw": 0.035, "hx": 0.12, "fz": 0.32, "hz": -0.34, "hy": 0.2, "ur": 0.075, "lr": 0.042, "pawr": Vector3(0.04, 0.02, 0.05),
				"trot": 1.8, "gallop": 4.5, "sk": 1.35, "lie": 0.2, "k_down": 0.95, "neck0": 0.05, "head0": 0.22, "tilt": -0.15, "tail_rest": [-0.3, 0.1]}
		Kind.WOLF:
			# 한국 늑대: 어깨 약 0.72m, 가슴이 좁고 깊으며 발이 크다
			_spec = {"lu": 0.19, "ll": 0.22, "paw": 0.03, "hx": 0.075, "fz": 0.28, "hz": -0.3, "hy": 0.12, "ur": 0.05, "lr": 0.03, "pawr": Vector3(0.04, 0.02, 0.06),
				"trot": 2.0, "gallop": 5.0, "sk": 1.5, "lie": 0.15, "k_down": 1.2, "neck0": 0.2, "head0": -0.12, "tilt": -0.12, "tail_rest": [-0.8, 0.1, 0.1]}
		_:
			# 한국(아무르) 호랑이: 머리·몸통 약 2.0m, 꼬리 약 0.9m, 어깨 약 1.05m
			_spec = {"lu": 0.24, "ll": 0.22, "paw": 0.05, "hx": 0.17, "fz": 0.42, "hz": -0.5, "hy": 0.19, "ur": 0.105, "lr": 0.068, "pawr": Vector3(0.085, 0.038, 0.115),
				"trot": 2.2, "gallop": 6.0, "sk": 1.55, "lie": 0.27, "k_down": 1.25, "neck0": 0.3, "head0": -0.22, "tilt": -0.2, "tail_rest": [-0.55, 0.05, 0.1, 0.15, 0.2, 0.2]}
	var lu: float = _spec["lu"]
	var ll: float = _spec["ll"]
	_h0 = (lu + ll + float(_spec["paw"])) * 0.985 + float(_spec["hy"])
	_torso = _node(self, Vector3(0.0, _h0, 0.0))
	match kind:
		Kind.DEER:
			_build_deer()
		Kind.BOAR:
			_build_boar()
		Kind.WOLF:
			_build_wolf()
		_:
			_build_tiger()
	_build_legs()


func _build_legs() -> void:
	var lu: float = _spec["lu"]
	var lt: float = float(_spec["ll"]) + float(_spec["paw"])   # 무릎에서 땅까지
	var hx: float = _spec["hx"]
	var hy: float = _spec["hy"]
	var ur: float = _spec["ur"]
	var lr: float = _spec["lr"]
	var pr: Vector3 = _spec["pawr"]
	var col: Color = _spec["fur"]
	var low: Color = _spec["leg_low"]
	var dark: Color = _spec["dark"]
	var pcol: Color = _spec["paw_col"]
	var smode := 2 if kind == Kind.TIGER else 0
	var hoof: bool = kind == Kind.DEER or kind == Kind.BOAR
	for i in 4:
		var fore := i < 2
		var sx := -1.0 if i % 2 == 0 else 1.0
		var z: float = _spec["fz"] if fore else _spec["hz"]
		var ust := _st()
		_e(ust, Vector3(0.0, -lu * 0.42, 0.0), Vector3(ur, lu * 0.62, ur * (1.0 if fore else 1.12)), col)
		_leg_upper_extra(ust, fore, sx, col)
		var hip := _node(_torso, Vector3(sx * hx, -hy, z), ust, smode)
		var lst := _st()
		_e(lst, Vector3(0.0, -lt * 0.5, 0.0), Vector3(lr, lt * 0.55, lr), low)
		if hoof:
			BodyMesh.box(lst, Vector3(0.0, -lt + 0.035, 0.012), Vector3(lr * 1.9, 0.07, lr * 2.8), dark)
		else:
			_e(lst, Vector3(0.0, -lt + pr.y, pr.z * 0.3), pr, pcol)
		_leg_lower_extra(lst, fore, sx, lt)
		var knee := _node(hip, Vector3(0.0, -lu, 0.0), lst, 0)
		if not fore:
			hip.rotation.x = -0.25
			knee.rotation.x = 0.5
		_hip.append(hip)
		_knee.append(knee)


## 종마다 다른 어깨·허벅지·다리 안쪽 털 같은 덧살
func _leg_upper_extra(ust: SurfaceTool, fore: bool, sx: float, col: Color) -> void:
	match kind:
		Kind.TIGER:
			if fore:
				_e(ust, Vector3(0.0, 0.1, -0.03), Vector3(0.14, 0.17, 0.2), col)     # 어깨뼈와 어깨살: 걸을 때 솟았다 가라앉는다
			else:
				_e(ust, Vector3(0.0, 0.0, -0.04), Vector3(0.15, 0.22, 0.23), col)    # 굵은 넓적다리
			_e(ust, Vector3(-sx * 0.07, -0.1, 0.01), Vector3(0.05, 0.16, 0.08), Color(0.94, 0.87, 0.72, 0.0))   # 다리 안쪽의 흰 털
		Kind.DEER:
			if fore:
				_e(ust, Vector3(0.0, 0.05, 0.0), Vector3(0.085, 0.12, 0.12), _spec["fur"])
			else:
				_e(ust, Vector3(0.0, -0.01, -0.03), Vector3(0.095, 0.16, 0.12), _spec["fur"])
		Kind.BOAR:
			if fore:
				_e(ust, Vector3(0.0, 0.05, 0.0), Vector3(0.1, 0.14, 0.14), _spec["fur"])
			else:
				_e(ust, Vector3(0.0, 0.0, -0.03), Vector3(0.1, 0.15, 0.12), _spec["fur"])
		Kind.WOLF:
			if not fore:
				_e(ust, Vector3(0.0, -0.01, -0.03), Vector3(0.065, 0.12, 0.09), _spec["fur"])


func _leg_lower_extra(lst: SurfaceTool, fore: bool, sx: float, lt: float) -> void:
	if kind == Kind.DEER and not fore:
		_sp(lst, Vector3(0.0, -lt * 0.3, -0.012), Vector3(0.026, 0.045, 0.03), Color(0.93, 0.88, 0.78))   # 뒷다리 발목의 옅은 털 뭉치
	if kind == Kind.WOLF:
		_sp(lst, Vector3(0.0, -lt * 0.35, 0.0), Vector3(0.036, lt * 0.3, 0.036), Color(0.78, 0.7, 0.55))   # 다리 앞쪽 옅은 털


func _add_ears(parent: Node3D, px: float, py: float, pz: float, r: Vector3, col: Color, inner: Color, spot := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var tilt: float = _spec["tilt"]
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var est := _st()
		_e(est, Vector3(0.0, r.y * 0.9, 0.0), r, col)
		_e(est, Vector3(0.0, r.y * 0.9, r.z * 0.4), r * Vector3(0.6, 0.75, 0.5), inner)
		if spot.a > 0.0:
			_e(est, Vector3(0.0, r.y * 1.0, -r.z * 0.8), Vector3(r.x * 0.5, r.y * 0.45, r.z * 0.4), spot)   # 귀 뒤의 흰 점
		var ear := _node(parent, Vector3(s * px, py, pz), est)
		ear.rotation.z = s * tilt
		_ears.append(ear)


func _build_tail(parent: Node3D, base: Vector3, segs: int, seg_len: float, thick: float, col: Color, tip: Color, mode: int = 0, taper: float = 0.08) -> void:
	var cur := parent
	var pos := base
	for i in segs:
		var tst := _st()
		var c := tip if i == segs - 1 else col
		var t := thick * (1.0 - taper * float(i))
		_e(tst, Vector3(0.0, 0.0, -seg_len * 0.5), Vector3(t, t, seg_len * 0.62), c)
		var seg := _node(cur, pos, tst, mode)
		_tail.append(seg)
		cur = seg
		pos = Vector3(0.0, 0.0, -seg_len * 0.9)


func _build_deer() -> void:
	var stag := variant % 2 == 1 and not young
	var spotted := not stag   # 암컷·새끼는 여름 털(흰 점), 수컷은 짙은 겨울 털과 목갈기
	var fur := Color(0.56, 0.37, 0.22) if spotted else Color(0.30, 0.24, 0.19)
	var back := Color(0.40, 0.26, 0.15) if spotted else Color(0.20, 0.16, 0.12)
	var belly := Color(0.86, 0.78, 0.64) if spotted else Color(0.62, 0.55, 0.45)
	var cream := Color(0.95, 0.91, 0.82)
	var dark := Color(0.08, 0.06, 0.05)
	_spec["fur"] = fur
	_spec["leg_low"] = fur.darkened(0.12) if spotted else Color(0.24, 0.19, 0.15)
	_spec["dark"] = dark
	_spec["paw_col"] = dark
	var st := _st()
	_e(st, Vector3(0.0, 0.0, 0.0), Vector3(0.17, 0.21, 0.5), fur)
	_e(st, Vector3(0.0, 0.03, 0.3), Vector3(0.16, 0.21, 0.22), fur)          # 가슴
	_e(st, Vector3(0.0, 0.02, -0.33), Vector3(0.16, 0.2, 0.22), fur)         # 엉덩이
	_e(st, Vector3(0.0, 0.17, 0.0), Vector3(0.05, 0.05, 0.46), back)         # 등을 따라 난 짙은 선
	_e(st, Vector3(0.0, -0.09, 0.02), Vector3(0.14, 0.12, 0.42), belly)
	# 엉덩이 흰 무늬(위쪽은 검은 테)
	_e(st, Vector3(0.0, 0.06, -0.5), Vector3(0.11, 0.14, 0.08), cream)
	_e(st, Vector3(0.0, 0.2, -0.46), Vector3(0.09, 0.03, 0.07), dark)
	if spotted or young:
		for side in [-1.0, 1.0]:
			var sd: float = side
			for row in 3:
				var yy := 0.12 - 0.075 * float(row)
				var xx := 0.17 * sqrt(maxf(1.0 - pow(yy / 0.21, 2.0), 0.05)) + 0.002
				for k in 7:
					var zz := -0.38 + 0.12 * float(k) + (0.05 if row % 2 == 1 else 0.0)
					_sp(st, Vector3(sd * xx, yy, zz), Vector3(0.014, 0.014, 0.012), cream)
	_node(_torso, Vector3.ZERO, st)
	# 목: 앞위로 비스듬히 약 43도
	_neck = _node(_torso, Vector3(0.0, 0.12, 0.38))
	var nst := _st()
	_e(nst, Vector3(0.0, 0.0, 0.0), Vector3(0.085, 0.085, 0.26), fur)
	_e(nst, Vector3(0.0, -0.05, 0.03), Vector3(0.07, 0.07, 0.22), belly)
	if stag:
		_e(nst, Vector3(0.0, 0.0, -0.04), Vector3(0.13, 0.13, 0.2), back)   # 수컷 목갈기
	var nn := _node(_neck, Vector3(0.0, 0.17, 0.18), nst)
	nn.rotation.x = -0.75
	_head = _node(_neck, Vector3(0.0, 0.34, 0.36))
	var hst := _st()
	_e(hst, Vector3(0.0, 0.0, 0.04), Vector3(0.07, 0.078, 0.115), fur)
	_e(hst, Vector3(0.0, -0.032, 0.17), Vector3(0.047, 0.046, 0.095), belly if spotted else fur.lightened(0.1))
	_e(hst, Vector3(0.0, -0.022, 0.262), Vector3(0.03, 0.026, 0.026), dark)   # 코
	_e(hst, Vector3(0.0, -0.065, 0.2), Vector3(0.036, 0.02, 0.07), cream)      # 턱 밑 흰 털
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_e(hst, Vector3(s * 0.066, 0.03, 0.095), Vector3(0.02, 0.022, 0.02), Color(0.04, 0.025, 0.02))   # 큰 눈
		_sp(hst, Vector3(s * 0.058, 0.05, 0.1), Vector3(0.025, 0.012, 0.02), Color(0.14, 0.1, 0.08))     # 눈가 그늘
	_node(_head, Vector3.ZERO, hst)
	_head.rotation.x = 0.55
	_add_ears(_head, 0.075, 0.06, -0.025, Vector3(0.042, 0.105, 0.022), fur, belly)
	if stag:
		var ant := _st()
		var bone := Color(0.60, 0.50, 0.36)
		for sx in [-1.0, 1.0]:
			var s: float = sx
			BodyMesh.box(ant, Vector3(s * 0.075, 0.13, -0.01), Vector3(0.022, 0.26, 0.022), bone, Vector3(-0.15, 0.0, s * -0.28))   # 본줄기
			BodyMesh.box(ant, Vector3(s * 0.125, 0.32, -0.03), Vector3(0.018, 0.22, 0.018), bone, Vector3(0.25, 0.0, s * 0.45))
			BodyMesh.box(ant, Vector3(s * 0.09, 0.07, 0.07), Vector3(0.017, 0.13, 0.017), bone, Vector3(1.0, 0.0, s * -0.1))      # 밑가지(앞으로)
			BodyMesh.box(ant, Vector3(s * 0.11, 0.26, 0.03), Vector3(0.016, 0.14, 0.016), bone, Vector3(0.7, 0.0, s * -0.5))     # 가운뎃가지
			BodyMesh.box(ant, Vector3(s * 0.15, 0.44, 0.0), Vector3(0.014, 0.14, 0.014), bone, Vector3(0.3, 0.0, s * 0.2))        # 끝 갈래
		_node(_head, Vector3(0.0, 0.05, 0.0), ant)
	else:
		# 암컷은 수컷 뿔 자리에 검은 혹이 있다
		var bump := _st()
		for sx in [-1.0, 1.0]:
			var s: float = sx
			_sp(bump, Vector3(s * 0.04, 0.075, 0.0), Vector3(0.016, 0.012, 0.016), dark)
		_node(_head, Vector3.ZERO, bump)
	_jaw = _node(_head, Vector3(0.0, -0.05, 0.12))
	_build_tail(_torso, Vector3(0.0, 0.1, -0.56), 1, 0.12, 0.045, cream, cream)


func _build_boar() -> void:
	var fur := Color(0.20, 0.155, 0.115)
	var lite := Color(0.34, 0.275, 0.21)
	var dark := Color(0.06, 0.045, 0.035)
	var tusk := Color(0.93, 0.89, 0.78)
	_spec["fur"] = fur
	_spec["leg_low"] = Color(0.14, 0.11, 0.085)
	_spec["dark"] = dark
	_spec["paw_col"] = dark
	var tusked := variant % 2 == 1 and not young
	var st := _st()
	_e(st, Vector3(0.0, 0.0, 0.0), Vector3(0.2, 0.22, 0.46), fur)
	_e(st, Vector3(0.0, 0.17, 0.3), Vector3(0.17, 0.12, 0.26), lite.darkened(0.25))   # 어깨 솟은 곳
	_e(st, Vector3(0.0, -0.02, 0.3), Vector3(0.2, 0.23, 0.22), fur)                   # 깊은 가슴
	_e(st, Vector3(0.0, -0.01, -0.36), Vector3(0.17, 0.2, 0.2), fur)                  # 가는 뒤쪽
	_e(st, Vector3(0.0, -0.1, 0.0), Vector3(0.16, 0.14, 0.4), lite)
	for k in 9:
		var zz := 0.42 - 0.1 * float(k)
		var topy := lerpf(0.2, 0.3, smoothstep(-0.4, 0.35, zz))
		_sp(st, Vector3(0.0, topy + 0.02, zz), Vector3(0.022, 0.07, 0.065), dark)    # 등을 따라 선 억센 갈기
	if young:
		# 새끼는 연한 밤색 몸에 노란 줄무늬(수박 같다)
		for side in [-1.0, 1.0]:
			var sd: float = side
			for k in 4:
				_sp(st, Vector3(sd * 0.185, 0.07 - 0.03 * float(k % 2), 0.28 - 0.17 * float(k)), Vector3(0.018, 0.14, 0.05), Color(0.62, 0.48, 0.28))
	_node(_torso, Vector3.ZERO, st)
	_neck = _node(_torso, Vector3(0.0, 0.08, 0.4))
	var nst := _st()
	_e(nst, Vector3(0.0, 0.0, 0.1), Vector3(0.19, 0.2, 0.2), fur)
	_node(_neck, Vector3.ZERO, nst)
	_head = _node(_neck, Vector3(0.0, -0.03, 0.3))
	var hst := _st()
	_e(hst, Vector3(0.0, 0.0, 0.05), Vector3(0.12, 0.14, 0.17), fur)               # 이마
	_e(hst, Vector3(0.0, -0.055, 0.33), Vector3(0.075, 0.07, 0.22), lite)          # 길고 곧은 주둥이
	_e(hst, Vector3(0.0, -0.06, 0.55), Vector3(0.062, 0.058, 0.022), Color(0.42, 0.3, 0.28))   # 코 판(원반)
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_sp(hst, Vector3(s * 0.025, -0.06, 0.57), Vector3(0.012, 0.014, 0.01), dark)   # 콧구멍
		_e(hst, Vector3(s * 0.098, 0.045, 0.165), Vector3(0.013, 0.013, 0.013), Color(0.06, 0.04, 0.03))   # 작은 눈
		_e(hst, Vector3(s * 0.105, -0.035, 0.12), Vector3(0.04, 0.07, 0.1), lite.lightened(0.12))          # 볼의 옅은 털
	_node(_head, Vector3.ZERO, hst)
	_add_ears(_head, 0.1, 0.14, -0.03, Vector3(0.045, 0.085, 0.02), fur, lite)
	var jst := _st()
	_e(jst, Vector3(0.0, 0.0, 0.17), Vector3(0.058, 0.034, 0.18), lite)
	if tusked:
		for sx in [-1.0, 1.0]:
			var s: float = sx
			BodyMesh.box(jst, Vector3(s * 0.062, 0.05, 0.33), Vector3(0.02, 0.1, 0.02), tusk, Vector3(0.5, 0.0, s * -0.22))   # 위로 휜 엄니
	_jaw = _node(_head, Vector3(0.0, -0.075, 0.1), jst)
	_build_tail(_torso, Vector3(0.0, 0.14, -0.54), 2, 0.14, 0.022, fur, dark)


func _build_wolf() -> void:
	var shades: Array[Color] = [Color(0.52, 0.45, 0.34), Color(0.40, 0.37, 0.33), Color(0.58, 0.50, 0.38)]
	var fur: Color = shades[variant % 3]
	var saddle := fur.darkened(0.38)
	var belly := Color(0.80, 0.75, 0.64)
	var pale := Color(0.84, 0.78, 0.66)
	var dark := Color(0.07, 0.05, 0.04)
	_spec["fur"] = fur
	_spec["leg_low"] = fur.lightened(0.08)
	_spec["dark"] = dark
	_spec["paw_col"] = fur.darkened(0.12)
	var st := _st()
	_e(st, Vector3(0.0, 0.0, 0.0), Vector3(0.12, 0.15, 0.4), fur)
	_e(st, Vector3(0.0, -0.01, 0.27), Vector3(0.135, 0.17, 0.2), fur)          # 좁고 깊은 가슴
	_e(st, Vector3(0.0, 0.01, -0.3), Vector3(0.12, 0.155, 0.2), fur)
	_e(st, Vector3(0.0, 0.1, 0.04), Vector3(0.09, 0.065, 0.36), saddle)        # 등의 짙은 안장 무늬
	_e(st, Vector3(0.0, -0.1, 0.1), Vector3(0.1, 0.08, 0.3), belly)
	_node(_torso, Vector3.ZERO, st)
	_neck = _node(_torso, Vector3(0.0, 0.09, 0.34))
	var nst := _st()
	_e(nst, Vector3(0.0, 0.0, 0.1), Vector3(0.14, 0.15, 0.2), fur.lightened(0.04))   # 목덜미 갈기
	_e(nst, Vector3(0.0, -0.08, 0.1), Vector3(0.1, 0.09, 0.16), pale)                # 목 아래 옅은 털
	_node(_neck, Vector3.ZERO, nst)
	_head = _node(_neck, Vector3(0.0, 0.06, 0.26))
	var hst := _st()
	_e(hst, Vector3(0.0, 0.0, 0.03), Vector3(0.082, 0.085, 0.11), fur)               # 넓은 이마
	_e(hst, Vector3(0.0, -0.02, 0.17), Vector3(0.042, 0.04, 0.12), pale)             # 가는 주둥이
	_e(hst, Vector3(0.0, 0.012, 0.19), Vector3(0.016, 0.01, 0.09), saddle)           # 콧등의 짙은 선
	_e(hst, Vector3(0.0, -0.012, 0.285), Vector3(0.022, 0.02, 0.02), dark)           # 코
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_e(hst, Vector3(s * 0.062, 0.03, 0.085), Vector3(0.013, 0.01, 0.015), Color(0.9, 0.68, 0.12))   # 비스듬한 호박색 눈
		_sp(hst, Vector3(s * 0.064, 0.03, 0.095), Vector3(0.006, 0.006, 0.006), dark)
		_e(hst, Vector3(s * 0.078, -0.035, 0.03), Vector3(0.035, 0.05, 0.07), pale)                     # 볼 털
	_node(_head, Vector3.ZERO, hst)
	_add_ears(_head, 0.05, 0.085, -0.015, Vector3(0.032, 0.075, 0.016), fur, pale)
	var jst := _st()
	_e(jst, Vector3(0.0, 0.0, 0.08), Vector3(0.034, 0.02, 0.1), pale)
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_sp(jst, Vector3(s * 0.025, 0.03, 0.16), Vector3(0.006, 0.02, 0.006), Color(0.96, 0.94, 0.88))   # 송곳니
	_jaw = _node(_head, Vector3(0.0, -0.045, 0.06), jst)
	_build_tail(_torso, Vector3(0.0, 0.05, -0.48), 3, 0.13, 0.06, fur, dark, 0, 0.1)


func _build_tiger() -> void:
	# 아무르(한국) 호랑이: 옅은 주황 바탕에 넓게 떨어진 갈색 줄무늬, 흰 가슴·배·목털, 귀 뒤의 흰 점
	var orange := Color(0.85, 0.51, 0.18)
	var cream := Color(0.95, 0.90, 0.78, 0.0)     # 알파 0: 줄무늬가 생기지 않는 흰 털
	var dark := Color(0.09, 0.06, 0.04)
	var mark := Color(0.13, 0.075, 0.04)
	_spec["fur"] = orange
	_spec["leg_low"] = orange.lightened(0.04)
	_spec["dark"] = dark
	_spec["paw_col"] = Color(0.90, 0.78, 0.58)
	var st := _st()
	_e(st, Vector3(0.0, 0.0, -0.08), Vector3(0.27, 0.29, 0.66), orange)
	_e(st, Vector3(0.0, -0.02, 0.34), Vector3(0.27, 0.3, 0.28), orange)         # 깊은 앞가슴
	_e(st, Vector3(0.0, 0.2, 0.3), Vector3(0.2, 0.13, 0.26), orange)            # 어깨 솟은 곳(등선이 어깨에서 가장 높다)
	_e(st, Vector3(0.0, 0.0, -0.5), Vector3(0.26, 0.27, 0.28), orange)          # 엉덩이는 어깨보다 낮다
	_e(st, Vector3(0.0, -0.2, -0.05), Vector3(0.21, 0.13, 0.55), cream)         # 흰 배
	_e(st, Vector3(0.0, -0.18, 0.4), Vector3(0.17, 0.13, 0.2), cream)           # 흰 가슴
	_node(_torso, Vector3.ZERO, st, 1)
	_neck = _node(_torso, Vector3(0.0, 0.12, 0.5))
	var nst := _st()
	_e(nst, Vector3(0.0, 0.0, 0.16), Vector3(0.23, 0.23, 0.26), orange)         # 굵은 목
	_e(nst, Vector3(0.0, -0.11, 0.12), Vector3(0.25, 0.16, 0.2), cream)         # 목 아래·옆의 흰 털(겨울에 두툼하다)
	_node(_neck, Vector3.ZERO, nst, 1)
	_head = _node(_neck, Vector3(0.0, 0.0, 0.36))
	var hst := _st()
	_e(hst, Vector3(0.0, 0.02, 0.0), Vector3(0.17, 0.15, 0.18), orange)         # 넓은 머리뼈
	_e(hst, Vector3(0.0, -0.07, 0.2), Vector3(0.115, 0.085, 0.13), cream)       # 넓고 짧은 주둥이
	_e(hst, Vector3(0.0, -0.03, 0.325), Vector3(0.05, 0.03, 0.03), Color(0.62, 0.34, 0.3))   # 코
	_e(hst, Vector3(0.0, -0.115, 0.2), Vector3(0.1, 0.008, 0.12), dark)         # 입선
	for k in 4:
		for sx in [-1.0, 1.0]:
			var s: float = sx
			_sp(hst, Vector3(s * (0.045 + 0.012 * float(k % 2)), -0.075 - 0.012 * float(k >> 1), 0.27 + 0.012 * float(k % 2)), Vector3(0.008, 0.008, 0.008), dark)   # 수염 뿌리 점
	# 이마의 왕(王)자 무늬: 머리뼈 곡면 위의 가로줄 셋과 세로줄
	for bar in [[0.12, 0.062], [0.045, 0.078], [-0.025, 0.07]]:
		var bz: float = bar[0]
		var bw: float = bar[1]
		var by := 0.02 + 0.15 * sqrt(maxf(1.0 - pow(bz / 0.18, 2.0), 0.0)) + 0.002
		_sp(hst, Vector3(0.0, by, bz), Vector3(bw, 0.011, 0.011), mark)
	for vz in [0.1, 0.07, 0.04, 0.01, -0.02, -0.05]:
		var vzf: float = vz
		var vy := 0.02 + 0.15 * sqrt(maxf(1.0 - pow(vzf / 0.18, 2.0), 0.0)) + 0.002
		_sp(hst, Vector3(0.0, vy, vzf), Vector3(0.009, 0.011, 0.02), mark)
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_e(hst, Vector3(s * 0.172, -0.05, 0.0), Vector3(0.09, 0.12, 0.12), cream)             # 볼 털(겨울털)
		_e(hst, Vector3(s * 0.085, 0.085, 0.13), Vector3(0.045, 0.022, 0.04), cream)           # 눈 위의 흰 무늬
		_e(hst, Vector3(s * 0.106, 0.05, 0.135), Vector3(0.02, 0.022, 0.02), Color(0.96, 0.78, 0.12))   # 호박색 눈
		_sp(hst, Vector3(s * 0.119, 0.05, 0.14), Vector3(0.008, 0.012, 0.012), Color(0.02, 0.02, 0.02))   # 둥근 눈동자
		_sp(hst, Vector3(s * 0.108, 0.036, 0.15), Vector3(0.012, 0.007, 0.022), dark)                      # 눈가 검은 선
		for k in 3:
			_sp(hst, Vector3(s * 0.258, 0.07 - 0.05 * float(k), 0.03 + 0.02 * float(k)), Vector3(0.012, 0.018, 0.065), mark)   # 볼의 줄무늬
		BodyMesh.box(hst, Vector3(s * 0.058, -0.135, 0.28), Vector3(0.016, 0.07, 0.016), Color(0.97, 0.95, 0.89))   # 윗송곳니
	_node(_head, Vector3.ZERO, hst)
	_add_ears(_head, 0.14, 0.14, -0.07, Vector3(0.065, 0.062, 0.03), dark, cream, Color(0.96, 0.94, 0.9, 1.0))   # 귀: 뒤는 검고 흰 점, 앞은 흰 털
	var jst := _st()
	_e(jst, Vector3(0.0, -0.005, 0.12), Vector3(0.078, 0.034, 0.14), cream)
	_e(jst, Vector3(0.0, 0.03, 0.1), Vector3(0.06, 0.01, 0.11), Color(0.38, 0.1, 0.1))     # 입 안
	_e(jst, Vector3(0.0, 0.026, 0.1), Vector3(0.035, 0.012, 0.09), Color(0.82, 0.38, 0.38))   # 혀
	for sx in [-1.0, 1.0]:
		var s: float = sx
		BodyMesh.box(jst, Vector3(s * 0.045, 0.05, 0.22), Vector3(0.016, 0.06, 0.016), Color(0.97, 0.95, 0.89))   # 아랫송곳니
	_jaw = _node(_head, Vector3(0.0, -0.07, 0.05), jst)
	# 꼬리: 굵고 길다(약 0.9m). 주황 바탕에 검은 고리, 끝은 검다
	_build_tail(_torso, Vector3(0.0, 0.08, -0.74), 6, 0.155, 0.062, orange, dark, 3, 0.05)


# --- 움직임 ---

## 속도(m/s)에 맞춰 걸음과 몸짓을 갱신한다. 소유자가 자세 값(crouch 등)을 정한 뒤 부른다.
func update(delta: float, speed: float) -> void:
	_t += delta
	var trot_at: float = _spec["trot"]
	var gal_at: float = _spec["gallop"]
	var tw := clampf((speed - 0.7) / (trot_at - 0.7), 0.0, 1.0)
	var gw := clampf((speed - trot_at) / (gal_at - trot_at), 0.0, 1.0)
	var moving := clampf(speed / 0.5, 0.0, 1.0)
	var leg_len: float = float(_spec["lu"]) + float(_spec["ll"]) + float(_spec["paw"])
	var stride: float = leg_len * float(_spec["sk"]) * (1.7 + 1.0 * tw + 1.7 * gw) * pace
	_phase = fposmod(_phase + speed * delta / maxf(stride, 0.1), 1.0)
	var amp := lerpf(lerpf(0.42, 0.55, tw), 0.8, gw) * moving * (1.0 - lunge)
	var bend := lerpf(lerpf(0.55, 0.8, tw), 1.05, gw) * moving * (1.0 - lunge)
	var a_c := minf(crouch, 1.6) * 0.9
	var cr_mix := clampf(crouch, 0.0, 1.0)
	for i in 4:
		var off := lerpf(lerpf(float(WALK_OFF[i]), float(TROT_OFF[i]), tw), float(GALLOP_OFF[i]), gw)
		var f := fposmod(_phase + off, 1.0)
		var psi := TAU * f
		var theta := amp * sin(psi) * (1.0 - cr_mix * 0.7)
		var lift := maxf(0.0, -cos(psi))
		var fore := i < 2
		var rest_hip := 0.0 if fore else -0.25
		var rest_knee := 0.0 if fore else 0.5
		var hip_x := rest_hip + theta
		var knee_x := rest_knee + bend * lift
		# 몸을 낮출수록 다리를 접는다
		if fore:
			hip_x += a_c
			knee_x += -2.0 * a_c
		else:
			hip_x += -a_c * 0.6
			knee_x += 1.4 * a_c
		# 도약: 앞다리는 앞으로, 뒷다리는 뒤로 쭉 뻗는다
		if lunge > 0.0:
			if fore:
				hip_x = lerpf(hip_x, -1.1, lunge)
				knee_x = lerpf(knee_x, 0.1, lunge)
			else:
				hip_x = lerpf(hip_x, 0.9, lunge)
				knee_x = lerpf(knee_x, 0.2, lunge)
		_hip[i].rotation.x = hip_x
		_knee[i].rotation.x = knee_x
		var prev: float = _prev[i]
		var crossed := (prev < 0.75 and f >= 0.75) or (f < prev and (prev < 0.75 or f >= 0.75))
		if crossed and moving > 0.35 and crouch < 0.7 and lunge < 0.3:
			stepped.emit(i)
		_prev[i] = f
	# 몸통: 높이, 앞뒤 기울기(질주 때 등이 휨), 위아래 출렁임, 숨쉬기
	var breath := sin(_t * (2.2 + 1.2 * gw))
	var bob := absf(sin(TAU * _phase)) * 0.03 * moving * (1.0 + gw)
	_torso.position.y = maxf(_h0 * cos(minf(a_c, 1.3)), float(_spec["lie"])) + bob - lunge * 0.05
	_torso.rotation.x = -0.1 * gw * sin(TAU * (_phase + 0.2)) - lunge * 0.25 + 0.0
	_torso.scale = Vector3(1.0 + 0.008 * breath, 1.0 + 0.016 * breath, 1.0)
	# 머리와 목
	var look_down := head_down * float(_spec["k_down"]) + crouch * 0.35
	_neck.rotation.x = float(_spec["neck0"]) + look_down + 0.05 * sin(TAU * _phase * 2.0) * moving
	_neck.rotation.y = clampf(head_turn, -1.0, 1.0)
	_head.rotation.x = float(_spec["head0"]) + head_down * 0.45
	if _jaw != null:
		_jaw.rotation.x = jaw * (0.7 if kind != Kind.DEER else 0.3)
	# 귀: 가끔 한쪽이 쫑긋 움직이고, 경계하면 곧추서며, 화나면 젖힌다
	_flick -= delta
	if _flick <= -randf_range(1.5, 5.0):
		_flick = 0.14
		_flick_i = randi() % 2
	for i in _ears.size():
		var s := -1.0 if i == 0 else 1.0
		var tw2 := 0.0
		if _flick > 0.0 and i == _flick_i:
			tw2 = sin((0.14 - _flick) / 0.14 * PI) * 0.5
		_ears[i].rotation.x = -ear_back * 0.9 + ear_alert * 0.15 - tw2 * 0.6
		_ears[i].rotation.z = s * (float(_spec["tilt"]) - ear_back * 0.55 + ear_alert * 0.2)
	# 꼬리: 걸을 때 좌우로 흔들고, 쳐들거나 늘어뜨린다
	var trest: Array = _spec["tail_rest"]
	for i in _tail.size():
		var sw := sin(_t * (2.0 + 5.0 * moving) + float(i) * 0.9) * (0.08 + 0.14 * moving) * (1.0 + 0.3 * float(i))
		var r0 := float(trest[i]) if i < trest.size() else 0.0
		_tail[i].rotation.y = sw
		# 꼬리는 뒤(-z)로 뻗으므로 +x 회전이 위로 든다. 처진 꼬리가 기본이고 tail_up이 클수록 치켜든다.
		_tail[i].rotation.x = r0 + tail_up * (1.1 if i == 0 else 0.35)
