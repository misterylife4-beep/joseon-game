class_name HanyangMap
extends RefCounted
## 한양 지도와 지형 함수. 근거와 설계값 구분은 docs/고증_근거.md 참고.
## 좌표: x는 동쪽(+), z는 남쪽(+), 북쪽은 -z. 가로·세로 축척 모두 약 1:10.

## 도성 타원의 동서·남북 반폭 (설계값)
const A := 230.0
const B := 170.0
## 성벽 높이. 사료상 평균 약 5~8m
const WALL_H := 6.0
## 천자문 순서로 나눈 성벽 공사 구간 수 (사료)
const SECTIONS := 97

## 경복궁 터와 궁성 (설계값)
const PALACE_C := Vector2(-30.0, -128.0)
const PALACE_HALF := Vector2(34.0, 22.0)
const FLAT_HALF := Vector2(28.0, 18.0)
const FLAT_BLEND := 24.0
## 광화문(궁성 남문)과 육조거리 남쪽 끝 황토현
const GWANGHWAMUN := Vector2(-30.0, -106.0)
const HWANGTOHYEON := Vector2(-30.0, -30.0)

## 종묘(경복궁 동쪽)와 사직단(서쪽). 좌묘우사. 실제 위치를 압축한 설계값
const JONGMYO_C := Vector2(100.0, -78.0)
const SAJIK_C := Vector2(-115.0, -80.0)
## 민가를 짓지 않는 구역
const JONGMYO_RECT := Rect2(56.0, -118.0, 88.0, 82.0)
const SAJIK_RECT := Rect2(-154.0, -118.0, 78.0, 76.0)

## 개천(청계천 전신) 구간
const STREAM_X0 := -180.0
const STREAM_X1 := 252.0

## 도성 8문. deg는 타원 매개각(동쪽 0도, 북쪽 90도, 반시계). 방위는 개략값
const GATES: Array[Dictionary] = [
	{"name": "숙정문", "big": true, "deg": 75.0},
	{"name": "창의문", "big": false, "deg": 125.0},
	{"name": "혜화문", "big": false, "deg": 45.0},
	{"name": "흥인지문", "big": true, "deg": 2.0},
	{"name": "광희문", "big": false, "deg": 328.0},
	{"name": "숭례문", "big": true, "deg": 258.0},
	{"name": "소의문", "big": false, "deg": 222.0},
	{"name": "돈의문", "big": true, "deg": 185.0},
]

static var _noise: FastNoiseLite
static var _plateau := INF


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = 1392
		_noise.frequency = 0.012
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_noise.fractal_octaves = 4
	return _noise


static func _adiff(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


## 능선(성벽)이 지나는 반지름 비율. 1을 중심으로 구불거린다.
static func crest_r(phi: float) -> float:
	return 1.0 + 0.07 * sin(3.0 * phi + 1.0) + 0.045 * sin(7.0 * phi + 0.5) + 0.03 * sin(13.0 * phi + 2.0)


static func crest_point(phi: float) -> Vector2:
	var cr := crest_r(phi)
	return Vector2(A * cr * cos(phi), -B * cr * sin(phi))


## 정규화 반지름. 1이면 성벽 위치, 작으면 도성 안쪽.
static func u_of(x: float, z: float) -> float:
	var ex := x / A
	var ez := z / B
	return sqrt(ex * ex + ez * ez) / crest_r(atan2(-ez, ex))


## 능선 높이(m). 백악 342, 인왕 338, 남산 262, 낙산 125를 1:10로 줄인 값.
static func ridge_peak(phi: float) -> float:
	var p := 12.0
	p += 22.0 * exp(-pow(_adiff(phi, 1.7453) / 0.55, 2.0))
	p += 22.0 * exp(-pow(_adiff(phi, 2.8798) / 0.5, 2.0))
	p += 15.0 * exp(-pow(_adiff(phi, 4.7473) / 0.6, 2.0))
	return p


## 성문 근처에서 능선이 낮아지는 정도(0~1)
static func gate_dip(phi: float) -> float:
	var best := 0.0
	for g in GATES:
		var d := _adiff(phi, deg_to_rad(g["deg"])) / 0.12
		best = maxf(best, exp(-d * d))
	return best


static func gate_phi(gate_name: String) -> float:
	for g in GATES:
		if g["name"] == gate_name:
			return deg_to_rad(g["deg"])
	return 0.0


static func gate_pos(gate_name: String) -> Vector2:
	return crest_point(gate_phi(gate_name))


static func stream_z(x: float) -> float:
	return 24.0 + 10.0 * sin(x * 0.022 + 1.0)


static func stream_carve(x: float, z: float) -> float:
	if x < STREAM_X0 - 20.0 or x > STREAM_X1:
		return 0.0
	var d := absf(z - stream_z(x))
	if d > 8.0:
		return 0.0
	var fade := smoothstep(STREAM_X0 - 20.0, STREAM_X0 + 20.0, x) * (1.0 - smoothstep(228.0, STREAM_X1, x))
	return 1.6 * (1.0 - smoothstep(2.0, 7.5, d)) * fade


## 한강 (설계값): 도성 남쪽, 남산 뒤편으로 흐른다. 실제 거리는 줄여 압축했다.
const RIVER_Z := 340.0
const RIVER_LEVEL := -8.5
const PLAIN_H := -7.0


static func river_z(x: float) -> float:
	return RIVER_Z + 22.0 * sin(x * 0.008 + 0.5)


## 강 중심선까지의 거리(z 방향)
static func river_dist(x: float, z: float) -> float:
	return absf(z - river_z(x))


## 영남길 쪽 산과 길을 더한 지형 높이 (Region.modify)
static func raw_height(x: float, z: float) -> float:
	return Region.modify(x, z, raw_height_base(x, z))


static func raw_height_base(x: float, z: float) -> float:
	var ex := x / A
	var ez := z / B
	var phi := atan2(-ez, ex)
	var u := sqrt(ex * ex + ez * ez) / crest_r(phi)
	# 북쪽이 조금 높은 완만한 분지 바닥
	var h := 3.0 - 0.045 * clampf(z, -B * 1.3, B * 1.3)
	var nz := _n().get_noise_2d(x, z)
	if u > 0.7:
		var rise := smoothstep(0.7, 1.0, u)
		var peak := ridge_peak(phi) * (1.0 - 0.8 * gate_dip(phi))
		var outer := smoothstep(1.0, 1.7, u)
		h += peak * rise * (1.0 - 0.3 * outer)
	h += nz * (0.8 + 14.0 * smoothstep(0.85, 1.6, u))
	# 남쪽 강변 평지와 강바닥
	if z > 150.0:
		var rd := river_dist(x, z)
		var plain := 1.0 - smoothstep(70.0, 150.0, rd)
		h = lerpf(h, PLAIN_H + nz * 0.5, plain)
		h -= (1.0 - smoothstep(24.0, 46.0, rd)) * 4.2
	return h


static func plateau_height() -> float:
	if _plateau == INF:
		_plateau = raw_height(PALACE_C.x, PALACE_C.y)
	return _plateau


## 개천 하상을 파지 않은 높이(다리·길·수면 기준)
static func height_no_carve(x: float, z: float) -> float:
	var h := raw_height(x, z)
	var dx := maxf(absf(x - PALACE_C.x) - FLAT_HALF.x, 0.0)
	var dz := maxf(absf(z - PALACE_C.y) - FLAT_HALF.y, 0.0)
	var d := sqrt(dx * dx + dz * dz)
	if d < FLAT_BLEND:
		h = lerpf(plateau_height(), h, smoothstep(0.0, FLAT_BLEND, d))
	return h


static func height(x: float, z: float) -> float:
	return height_no_carve(x, z) - stream_carve(x, z)


## 지형 메시는 2m 격자(청크 64m ÷ 32칸)의 높이를 삼각형으로 이어 만든다. 높이 함수 값과 메시는 곡률이 큰 산지에서 최대 수십 cm 어긋나
## 그 위에 선 사람·짐승의 발이 땅에 묻힐 수 있다. 이 함수는 메시와 똑같은 삼각형 보간으로 '눈에 보이는 땅'의 높이를 돌려준다.
const MESH_STEP := 2.0
## 사람이 길 위에 서 있을 때 발바닥이 길(지면 위 약 3cm)에 묻히지 않도록 더하는 높이
const STAND_LIFT := 0.03


static func _hc(x: float, z: float, carve: bool) -> float:
	return height(x, z) if carve else height_no_carve(x, z)


static func surface(x: float, z: float, carve := true) -> float:
	var gx := x / MESH_STEP
	var gz := z / MESH_STEP
	var ix := floorf(gx)
	var iz := floorf(gz)
	var u := gx - ix
	var v := gz - iz
	var x0 := ix * MESH_STEP
	var z0 := iz * MESH_STEP
	var h10 := _hc(x0 + MESH_STEP, z0, carve)
	var h01 := _hc(x0, z0 + MESH_STEP, carve)
	if u + v <= 1.0:
		var h00 := _hc(x0, z0, carve)
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	var h11 := _hc(x0 + MESH_STEP, z0 + MESH_STEP, carve)
	return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)


## 사람이 서는 높이: 눈에 보이는 땅 + 길 두께. carve가 false면 개천 하상을 파지 않은 둑·다리 높이.
static func stand(x: float, z: float, carve := false) -> float:
	return surface(x, z, carve) + STAND_LIFT
