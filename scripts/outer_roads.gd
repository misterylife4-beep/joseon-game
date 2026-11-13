class_name OuterRoads
extends Node3D
## 성 밖 길과 마을: 대문에서 나루로 이어지는 흙길, 길가 초가 마을(울타리 두른 마당), 밭, 장승, 길 가는 사람.
## 근거(docs/고증_근거.md 19장): 도성 밖 성저십리가 도성 안과 하나의 생활권이었다는 점과 한강 나루들은 사료다.
## 길의 정확한 경로, 마을 위치와 크기, 밭 배치, 장승(조선 후기 풍속 중심)은 설계값이다.
## 칠패·이문 같은 후대 시장 마을은 두지 않았다.

## [성문, 나루 번호(HanRiver.FERRIES), 길 폭]
const ROUTES: Array = [
	["돈의문", 0, 5.0],
	["숭례문", 1, 6.5],
	["흥인지문", 2, 6.0],
]
const STEP := 11.0
const CELL := 5.0

static var _roads: Array[PackedVector2Array] = []
static var _cells := {}
static var _ready_flag := false

var _wood_mat: StandardMaterial3D


# --- 경로 (정적: 나무·풀 배치가 길을 피하려고 먼저 물어볼 수 있다) ---

static func _ensure() -> void:
	if _ready_flag:
		return
	_ready_flag = true
	for r in ROUTES:
		var gname: String = r[0]
		var fi: int = r[1]
		var fx: float = HanRiver.FERRIES[fi]["x"]
		var pts := _make_route(gname, fx)
		_roads.append(pts)
		for p in pts:
			_cells[Vector2i(floori(p.x / CELL), floori(p.y / CELL))] = true


static func _make_route(gname: String, fx: float) -> PackedVector2Array:
	var g := HanyangMap.gate_pos(gname)
	var out_dir := Vector2(g.x / (HanyangMap.A * HanyangMap.A), g.y / (HanyangMap.B * HanyangMap.B)).normalized()
	var start := g + out_dir * 7.0
	var rz := HanyangMap.river_z(fx + 31.0)
	# 나루터 마을(HanRiver)의 집 사이 빈틈(fx+31)으로 내려가 선착장에 닿는다.
	var pre := Vector2(fx + 31.0, rz - 100.0)
	var ctrl: Array = [g]
	ctrl.append_array(_trace(start, pre))
	ctrl.append(Vector2(fx + 31.0, rz - 60.0))
	ctrl.append(Vector2(fx + 31.0, rz - 46.0))
	ctrl.append(Vector2(fx + 4.0, rz - 41.0))
	return _smooth(ctrl, 2)


## 목적지 쪽으로 가되 가파른 곳과 급한 꺾임을 피해 11m씩 길을 더듬어 간다.
static func _trace(start: Vector2, target: Vector2) -> Array:
	var out: Array = [start]
	var pos := start
	var heading := (target - start).normalized()
	for _i in 220:
		var to_t := target - pos
		if to_t.length() < STEP * 1.3:
			break
		var base := to_t.angle()
		var h0 := HanyangMap.height_no_carve(pos.x, pos.y)
		var best_cost := INF
		var best := pos
		var best_hd := heading
		for ang in [-0.8, -0.5, -0.3, -0.12, 0.0, 0.12, 0.3, 0.5, 0.8]:
			var a: float = ang
			var hd := Vector2.from_angle(base + a)
			var cand := pos + hd * STEP
			var dh := absf(HanyangMap.height_no_carve(cand.x, cand.y) - h0)
			var cost := dh * 3.0 + absf(a) * 2.0 + absf(heading.angle_to(hd)) * 6.0
			if HanyangMap.u_of(cand.x, cand.y) < 1.04:
				cost += 40.0
			if cost < best_cost:
				best_cost = cost
				best = cand
				best_hd = hd
		pos = best
		heading = best_hd
		out.append(pos)
	out.append(target)
	return out


static func _smooth(ctrl: Array, per_span: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for k in per_span:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(per_span)))
	out.append(ctrl[n - 1] as Vector2)
	return out


## 성 밖 길(과 길가 여유)에 가까운 곳인가. 나무와 풀을 심지 않는 데 쓴다.
static func near_road(x: float, z: float) -> bool:
	_ensure()
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if _cells.has(Vector2i(cx + dx, cz + dz)):
				return true
	return false


static func _dist_to_roads(p: Vector2) -> float:
	var best := INF
	for pts in _roads:
		for q in pts:
			best = minf(best, p.distance_to(q))
	return best


# --- 만들기 ---

func build() -> void:
	_ensure()
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.vertex_color_use_as_albedo = true
	_wood_mat.vertex_color_is_srgb = true
	_wood_mat.roughness = 0.9
	_wood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road.gdshader") as Shader
	for i in _roads.size():
		var width: float = ROUTES[i][2]
		_ribbon(_roads[i], width, road_mat)
	_villages()
	for i in _roads.size():
		var life := StreetLife.new()
		add_child(life)
		life.build(_roads[i], 5, 0)


func _ribbon(pts: PackedVector2Array, width: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var pl := pts[i] + nrm * width * 0.5
		var pr := pts[i] - nrm * width * 0.5
		var vl := Vector3(pl.x, HanyangMap.surface(pl.x, pl.y, false) + 0.04, pl.y)
		var vr := Vector3(pr.x, HanyangMap.surface(pr.x, pr.y, false) + 0.04, pr.y)
		var v := 0.0
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
			v = acc / 8.0
			var data := [
				[prev_l, Vector2(1.0, prev_v)], [prev_r, Vector2(0.0, prev_v)], [vl, Vector2(1.0, v)],
				[prev_r, Vector2(0.0, prev_v)], [vr, Vector2(0.0, v)], [vl, Vector2(1.0, v)],
			]
			for d in data:
				st.set_normal(Vector3.UP)
				st.set_uv(d[1])
				st.add_vertex(d[0])
		prev_l = vl
		prev_r = vr
		prev_v = v
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 450.0
	add_child(mi)


func _flat_range(c: Vector2, hx: float, hz: float) -> float:
	var lo := INF
	var hi := -INF
	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 0.0, 1.0]:
			var h := HanyangMap.height_no_carve(c.x + float(dx) * hx, c.y + float(dz) * hz)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


func _villages() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1396
	var placed: Array[Vector2] = []
	var fence := SurfaceTool.new()
	fence.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.34, 0.25, 0.16, 0.0)
	var first_site := true
	for ri in _roads.size():
		var pts := _roads[ri]
		var n := pts.size()
		for fr in [0.25, 0.55]:
			var idx := clampi(int(float(n) * float(fr)), 4, n - 5)
			var c := pts[idx]
			var t := (pts[idx + 3] - pts[idx - 3]).normalized()
			var nrm := Vector2(-t.y, t.x)
			if c.y > HanyangMap.river_z(c.x) - 115.0 or HanyangMap.u_of(c.x, c.y) < 1.08:
				continue
			var houses := 0
			for k in 9:
				if houses >= 6:
					break
				var side := 1.0 if k % 2 == 0 else -1.0
				var pos := c + t * rng.randf_range(-32.0, 32.0) + nrm * side * rng.randf_range(12.0, 20.0)
				var kx := rng.randi_range(2, 3)
				var kz := rng.randi_range(1, 2)
				var w := float(kx) * Hanok.KAN
				var d := float(kz) * Hanok.KAN
				if _flat_range(pos, w * 0.5 + 3.0, d * 0.5 + 3.5) > 0.8:
					continue
				if HanyangMap.u_of(pos.x, pos.y) < 1.08:
					continue
				var close := false
				for q in placed:
					if q.distance_to(pos) < 15.0:
						close = true
						break
				if close or _dist_to_roads(pos) < 10.0:
					continue
				var hk := Hanok.new()
				hk.setup(Hanok.Style.THATCH, kx, kz, Vector3(pos.x, HanyangMap.height_no_carve(pos.x, pos.y), pos.y), 0.0)
				add_child(hk)
				HanyangCity.house_points.append(pos)
				placed.append(pos)
				houses += 1
				_fence(fence, pos, w * 0.5 + 3.0, d * 0.5 + 3.5, wood)
			_fields(c, t, nrm, placed, rng)
			if first_site:
				first_site = false
				_jangseung(c - t * 38.0 + nrm * 5.0, t)
	var mi := MeshInstance3D.new()
	mi.mesh = fence.commit()
	mi.material_override = _wood_mat
	mi.visibility_range_end = 180.0
	add_child(mi)


## 마당을 두른 낮은 울타리. 남쪽(앞)에 사립문 자리를 비운다.
func _fence(st: SurfaceTool, c: Vector2, hx: float, hz: float, col: Color) -> void:
	var step := 1.7
	var corners: Array = []
	var nx := int(ceilf(hx * 2.0 / step))
	var nz := int(ceilf(hz * 2.0 / step))
	for i in nx + 1:
		var x := c.x - hx + float(i) * (hx * 2.0 / float(nx))
		corners.append(Vector2(x, c.y - hz))
		if absf(x - c.x) > 1.4:
			corners.append(Vector2(x, c.y + hz))
	for j in range(1, nz):
		var z := c.y - hz + float(j) * (hz * 2.0 / float(nz))
		corners.append(Vector2(c.x - hx, z))
		corners.append(Vector2(c.x + hx, z))
	for p in corners:
		var pv: Vector2 = p
		var h := HanyangMap.height_no_carve(pv.x, pv.y)
		BodyMesh.box(st, Vector3(pv.x, h + 0.55, pv.y), Vector3(0.07, 1.1, 0.07), col)
	# 가로대: 북·동·서 변과 남쪽 양옆
	for rail_h in [0.42, 0.86]:
		var ry: float = rail_h
		var gy := HanyangMap.height_no_carve(c.x, c.y)
		BodyMesh.box(st, Vector3(c.x, gy + ry, c.y - hz), Vector3(hx * 2.0, 0.04, 0.04), col)
		BodyMesh.box(st, Vector3(c.x - hx, gy + ry, c.y), Vector3(0.04, 0.04, hz * 2.0), col)
		BodyMesh.box(st, Vector3(c.x + hx, gy + ry, c.y), Vector3(0.04, 0.04, hz * 2.0), col)
		var seg := hx - 1.4
		BodyMesh.box(st, Vector3(c.x - 1.4 - seg * 0.5, gy + ry, c.y + hz), Vector3(seg, 0.04, 0.04), col)
		BodyMesh.box(st, Vector3(c.x + 1.4 + seg * 0.5, gy + ry, c.y + hz), Vector3(seg, 0.04, 0.04), col)


## 밭: 마을 뒤쪽 평평한 곳에 이랑 진 맨땅을 깐다. 계절에 따라 색이 바뀐다.
func _fields(c: Vector2, t: Vector2, nrm: Vector2, placed: Array[Vector2], rng: RandomNumberGenerator) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/field.gdshader") as Shader
	var made := 0
	for k in 8:
		if made >= 2:
			break
		var side := 1.0 if k % 2 == 0 else -1.0
		var pos := c + t * rng.randf_range(-30.0, 30.0) + nrm * side * rng.randf_range(32.0, 46.0)
		var w := 16.0
		var d := 12.0
		if _flat_range(pos, w * 0.5, d * 0.5) > 0.8 or HanyangMap.u_of(pos.x, pos.y) < 1.1:
			continue
		if pos.y > HanyangMap.river_z(pos.x) - 100.0:
			continue
		var close := false
		for q in placed:
			if q.distance_to(pos) < 14.0:
				close = true
				break
		if close or _dist_to_roads(pos) < 9.0:
			continue
		var hmax := -INF
		var hmin := INF
		for dx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				var hh := HanyangMap.height_no_carve(pos.x + float(dx) * w * 0.5, pos.y + float(dz) * d * 0.5)
				hmax = maxf(hmax, hh)
				hmin = minf(hmin, hh)
		var depth := hmax - hmin + 0.5
		var bm := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(w, depth, d)
		bm.mesh = bx
		bm.material_override = mat
		bm.position = Vector3(pos.x, hmax + 0.04 - depth * 0.5, pos.y)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bm.visibility_range_end = 300.0
		add_child(bm)
		placed.append(pos)
		made += 1


## 마을 어귀에 세운 장승 한 쌍(설계값: 크기·얼굴 모양. 조선 후기 풍속 기록이 많아 1396년 모습은 추정이다).
func _jangseung(p: Vector2, t: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.4, 0.28, 0.17, 0.0)
	var dark := Color(0.06, 0.05, 0.04, 0.0)
	for s in [-1.0, 1.0]:
		var sg: float = s
		var gx := p.x + t.x * sg * 1.4
		var gz := p.y + t.y * sg * 1.4
		var gy := HanyangMap.height_no_carve(gx, gz)
		BodyMesh.box(st, Vector3(gx, gy + 1.1, gz), Vector3(0.3, 2.2, 0.3), wood)
		BodyMesh.ellipsoid(st, Vector3(gx, gy + 1.85, gz), Vector3(0.24, 0.3, 0.2), wood)
		BodyMesh.box(st, Vector3(gx - 0.08, gy + 1.9, gz + 0.19), Vector3(0.07, 0.04, 0.03), dark)
		BodyMesh.box(st, Vector3(gx + 0.08, gy + 1.9, gz + 0.19), Vector3(0.07, 0.04, 0.03), dark)
		BodyMesh.box(st, Vector3(gx, gy + 1.76, gz + 0.2), Vector3(0.1, 0.03, 0.03), dark)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _wood_mat
	mi.visibility_range_end = 160.0
	add_child(mi)
