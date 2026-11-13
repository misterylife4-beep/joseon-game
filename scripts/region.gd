class_name Region
extends RefCounted
## 지역 데이터: 위험도 구역, 영남길 첫 구간(광나루 남쪽 ~ 양재 ~ 달래내 고개 ~ 너덜이)의 길·산·마을.
## 근거(docs/고증_근거.md 20장): 영남 사람들이 한강을 건너 양재를 지나 달래내 고개(서울 경계)와
## 너덜이(판교)로 넘어가는 용인로를 썼다는 점, 고개 호환에 대비해 사람을 모아 보냈다는 점은 사료·연구 자료다.
## 길의 굽이, 구간 거리 압축(실제보다 훨씬 짧게), 산의 높이와 위치, 위험도 구분, 마을 위치는 모두 설계값이다.
##
## 위험도: 0 마을(맹수 없음, 게임 규칙) / 1 들길 / 2 구릉·숲 / 3 산길 / 4 깊은 산.

const FERRY_X := 360.0  # HanRiver.FERRIES[2] 광나루

## 광나루 남쪽 나루에서 시작하는 길의 길목들 (첫 점은 런타임에 남쪽 선착장으로 둔다)
const CTRL_REST: Array[Vector2] = [
	Vector2(380.0, 470.0),
	Vector2(430.0, 600.0),
	Vector2(470.0, 760.0),
	Vector2(500.0, 900.0),
	Vector2(540.0, 1050.0),
	Vector2(610.0, 1200.0),
	Vector2(680.0, 1330.0),
	Vector2(730.0, 1450.0),
	Vector2(770.0, 1600.0),
	Vector2(800.0, 1760.0),
	Vector2(815.0, 1850.0),
]

## 구역. 앞에 있는 것이 먼저 맞는다. town은 마을(집과 빈터), enter는 처음 들어설 때 글.
const ZONES: Array[Dictionary] = [
	{"id": "jetty_s", "name": "광나루 남쪽 나루터", "c": Vector2(364.0, 400.0), "r": 70.0, "danger": 0, "town": false,
		"enter": "강 남쪽 나루터다. 이 길로 남쪽 양재를 지나 고개를 넘는다."},
	{"id": "yangjae", "name": "양재 마을", "c": Vector2(500.0, 900.0), "r": 80.0, "danger": 0, "town": true,
		"enter": "양재 마을이다. 여기서는 짐승 걱정 없이 쉴 수 있다."},
	{"id": "pangyo", "name": "너덜이 마을", "c": Vector2(815.0, 1850.0), "r": 80.0, "danger": 0, "town": true,
		"enter": "너덜이 마을이다. 고개를 무사히 넘었다."},
	{"id": "cheonggye", "name": "청계산 깊은 골", "c": Vector2(1020.0, 1260.0), "r": 300.0, "danger": 4, "town": false,
		"enter": "길도 없는 깊은 산이다. 짐승의 땅이다."},
	{"id": "dalnae", "name": "달래내 고개", "c": Vector2(660.0, 1370.0), "r": 380.0, "danger": 3, "town": false,
		"enter": "달래내 고개다. 호랑이가 나온다고 한다. 해 지기 전에 넘어야 한다."},
	{"id": "foothill", "name": "고개 어귀 숲", "c": Vector2(660.0, 1370.0), "r": 600.0, "danger": 2, "town": false,
		"enter": "숲이 깊어진다. 이 앞이 달래내 고개다."},
]

const DEFAULT_NEAR := {"id": "outskirts", "name": "성저십리", "danger": 0, "town": false, "enter": ""}
const DEFAULT_FAR := {"id": "fields", "name": "들길", "danger": 1, "town": false, "enter": ""}

static var _ready_flag := false
static var _pts := PackedVector2Array()
static var _hs := PackedFloat32Array()
static var _grid := {}
static var _plant := {}


# --- 지역 쿼리 ---

static func zone_at(x: float, z: float) -> Dictionary:
	var p := Vector2(x, z)
	for zn in ZONES:
		var c: Vector2 = zn["c"]
		var r: float = zn["r"]
		if p.distance_to(c) < r:
			return zn
	if z < 420.0:
		return DEFAULT_NEAR
	return DEFAULT_FAR


static func danger_at(x: float, z: float) -> int:
	var zn := zone_at(x, z)
	return int(zn["danger"])


## 나무를 더 빽빽하게 심는 정도 (산일수록 많다)
static func tree_boost(x: float, z: float) -> float:
	var d := danger_at(x, z)
	if d >= 3:
		return 1.9
	if d == 2:
		return 1.35
	return 1.0


static func landing_north() -> Vector2:
	return Vector2(FERRY_X + 4.0, HanyangMap.river_z(FERRY_X) - 41.0)


static func landing_south() -> Vector2:
	return Vector2(FERRY_X + 4.0, HanyangMap.river_z(FERRY_X) + 41.0)


static func road_points() -> PackedVector2Array:
	_ensure()
	return _pts


static func towns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for zn in ZONES:
		if bool(zn["town"]):
			out.append(zn)
	return out


## 나무와 풀을 심지 않는 곳: 길과 길가, 마을 빈터
static func no_plant(x: float, z: float) -> bool:
	if z < 360.0 or z > 1960.0 or x < 300.0 or x > 900.0:
		return false
	_ensure()
	var cx := floori(x / 6.0)
	var cz := floori(z / 6.0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if _plant.has(Vector2i(cx + dx, cz + dz)):
				return true
	var p := Vector2(x, z)
	for zn in ZONES:
		if bool(zn["town"]):
			var c: Vector2 = zn["c"]
			var r: float = zn["r"]
			if p.distance_to(c) < r - 8.0:
				return true
	return false


# --- 지형 ---

## HanyangMap.raw_height 끝에서 불린다. 산을 더하고, 길 둘레를 평평하게 다진다.
static func modify(x: float, z: float, h: float) -> float:
	if z < 360.0 or z > 2300.0 or x < 0.0 or x > 1500.0:
		return h
	var out := h + _mountain(x, z)
	if x > 300.0 and x < 900.0 and z < 1960.0:
		out = _flatten(x, z, out)
	return out


## 청계산(동쪽, 높다)과 우면·관악 쪽 산줄기(서쪽). 높이는 실제의 약 1:10 (설계값).
static func _mountain(x: float, z: float) -> float:
	var ex := x - 1020.0
	var ez := z - 1260.0
	var m := 62.0 * exp(-(ex * ex + ez * ez) / (2.0 * 190.0 * 190.0))
	var wx := x - 300.0
	var wz := z - 1280.0
	m += 46.0 * exp(-(wx * wx + wz * wz) / (2.0 * 200.0 * 200.0))
	return m


static func _flatten(x: float, z: float, h: float) -> float:
	_ensure()
	var cx := floori(x / 16.0)
	var cz := floori(z / 16.0)
	var d1 := INF
	var d2 := INF
	var h1 := 0.0
	var h2 := 0.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var arr: PackedInt32Array = _grid.get(Vector2i(cx + dx, cz + dz), PackedInt32Array())
			for i in arr:
				var p := _pts[i]
				var d := Vector2(x - p.x, z - p.y).length()
				if d < d1:
					d2 = d1
					h2 = h1
					d1 = d
					h1 = _hs[i]
				elif d < d2:
					d2 = d
					h2 = _hs[i]
	if d1 > 18.0:
		return h
	var road_h := h1
	if d2 < 30.0:
		road_h = (h1 * d2 + h2 * d1) / (d1 + d2)
	return lerpf(road_h, h, smoothstep(7.0, 18.0, d1))


# --- 길 ---

static func _ensure() -> void:
	if _ready_flag:
		return
	_ready_flag = true
	var ctrl: Array[Vector2] = [landing_south()]
	ctrl.append_array(CTRL_REST)
	_pts = _smooth(ctrl, 40)
	_hs.resize(_pts.size())
	for i in _pts.size():
		var p := _pts[i]
		_hs[i] = HanyangMap.raw_height_base(p.x, p.y) + _mountain(p.x, p.y)
	# 자잘한 요철을 펴서 길이 완만하게 오르내리게 한다 (끝점은 고정)
	for _pass in 8:
		var tmp := _hs.duplicate()
		for i in range(1, _pts.size() - 1):
			var s := 0.0
			var c := 0
			for k in range(-6, 7):
				var j := clampi(i + k, 0, _pts.size() - 1)
				s += _hs[j]
				c += 1
			tmp[i] = s / float(c)
		_hs = tmp
	for i in _pts.size():
		var p := _pts[i]
		var gk := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
		var arr: PackedInt32Array = _grid.get(gk, PackedInt32Array())
		arr.append(i)
		_grid[gk] = arr
		_plant[Vector2i(floori(p.x / 6.0), floori(p.y / 6.0))] = true


static func _smooth(ctrl: Array[Vector2], per_span: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for k in per_span:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(per_span)))
	out.append(ctrl[n - 1])
	return out
