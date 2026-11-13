class_name HanyangCity
extends Node3D
## 도성 안의 길, 개천, 관청, 민가. 근거와 설계값은 docs/고증_근거.md.
## 1막(1394~1396)이므로 시전행랑·석축 하천·종루는 두지 않는다.

const CELL_W := 15.0
const CELL_D := 13.0
const VIS_END := 150.0

## [이름, 영역, 기와집 비율, 필지가 차는 비율]. 북촌·남촌은 양반, 개천 주변은 중하층.
const ZONES: Array[Dictionary] = [
	{"name": "북촌", "rect": Rect2(18, -118, 130, 74), "tile": 0.45, "dens": 0.45},
	{"name": "서촌", "rect": Rect2(-190, -95, 110, 60), "tile": 0.15, "dens": 0.4},
	{"name": "중촌", "rect": Rect2(-120, -2, 190, 16), "tile": 0.1, "dens": 0.6},
	{"name": "남촌", "rect": Rect2(-150, 46, 210, 66), "tile": 0.35, "dens": 0.4},
	{"name": "아랫대", "rect": Rect2(62, -8, 130, 62), "tile": 0.05, "dens": 0.5},
]

const EAST_OFFICES: Array[String] = ["의정부", "삼군부", "이조", "호조"]
const WEST_OFFICES: Array[String] = ["예조", "사헌부", "병조", "형조", "공조"]

var _rng := RandomNumberGenerator.new()
var _road_mat: ShaderMaterial
var _road_pts := PackedVector2Array()
var _road_half := PackedFloat32Array()
var _reserved: Array[Vector2] = []
## 길 하나하나의 점들과 폭 (개천을 건너는 자리를 찾는 데 쓴다)
var _road_lines: Array[PackedVector2Array] = []
var _road_widths: Array[float] = []
## 개천 다리 자리 {c, dir, half_len, half_w}
var _bridges: Array[Dictionary] = []
## 민가 위치(사람이 저녁에 돌아가는 곳)
static var house_points := PackedVector2Array()


func build(reserved: Array[Vector2]) -> void:
	_reserved = reserved
	house_points = PackedVector2Array()
	_rng.seed = 1394
	_road_mat = ShaderMaterial.new()
	_road_mat.shader = load("res://shaders/road.gdshader") as Shader
	_build_roads()
	_build_stream()
	_build_stream_bridges()
	_build_gwanghwamun()
	_build_offices()
	_build_neighborhoods()


## 길 위의 점들 (사람이 오가는 길을 정할 때 쓴다)
func road_points() -> PackedVector2Array:
	return _road_pts


# --- 길 ---

func _build_roads() -> void:
	# 육조거리: 광화문 → 황토현
	_road([HanyangMap.GWANGHWAMUN, HanyangMap.HWANGTOHYEON], 14.0)

	# 운종가: 돈의문 ~ 황토현 ~ 흥인지문. 동서 대문을 잇는 큰길
	var w := HanyangMap.gate_pos("돈의문")
	var e := HanyangMap.gate_pos("흥인지문")
	var h := HanyangMap.HWANGTOHYEON
	_road([
		w, w.lerp(h, 0.4) + Vector2(0.0, 4.0), w.lerp(h, 0.75), h,
		h.lerp(e, 0.3) + Vector2(0.0, -3.0), h.lerp(e, 0.65) + Vector2(0.0, 2.0), h.lerp(e, 0.9), e,
	], 9.0)

	# 남대문로: 숭례문에서 북쪽 운종가로
	var s := HanyangMap.gate_pos("숭례문")
	var t := Vector2(s.x * 0.5, -22.0)
	_road([s, s.lerp(t, 0.35) + Vector2(6.0, 0.0), s.lerp(t, 0.7), t], 7.0)

	# 나머지 문은 안쪽으로 짧게 길을 낸다
	for g in HanyangMap.GATES:
		var gn: String = g["name"]
		if gn in ["돈의문", "흥인지문", "숭례문"]:
			continue
		var gp := HanyangMap.gate_pos(gn)
		_road([gp, gp.lerp(Vector2.ZERO, 0.08), gp.lerp(Vector2.ZERO, 0.17)], 5.0)


func _road(ctrl: Array, width: float) -> void:
	var pts := _catmull(ctrl, 8)
	for p in pts:
		_road_pts.append(p)
		_road_half.append(width * 0.5)
	_road_lines.append(pts)
	_road_widths.append(width)
	_ribbon(pts, width, 0.03, _road_mat, true)


func _catmull(ctrl: Array, per_span: int) -> PackedVector2Array:
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


## 점들을 따라 지형에 붙는 띠 메시를 만든다. 개천을 건너는 곳은 하상이 아닌 둑 높이를 따라 다리처럼 지난다.
func _ribbon(pts: PackedVector2Array, width: float, y_off: float, mat: Material, bridge: bool) -> void:
	if pts.size() < 2:
		return
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
		var yl := HanyangMap.surface(pl.x, pl.y, not bridge) + y_off
		var yr := HanyangMap.surface(pr.x, pr.y, not bridge) + y_off
		var vl := Vector3(pl.x, yl, pl.y)
		var vr := Vector3(pr.x, yr, pr.y)
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
			var v := acc / 8.0
			_ribbon_quad(st, prev_l, prev_r, vl, vr, prev_v, v)
		prev_l = vl
		prev_r = vr
		prev_v = acc / 8.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ribbon_quad(st: SurfaceTool, l0: Vector3, r0: Vector3, l1: Vector3, r1: Vector3, v0: float, v1: float) -> void:
	var up := Vector3.UP
	var data := [
		[l0, Vector2(1.0, v0)], [r0, Vector2(0.0, v0)], [l1, Vector2(1.0, v1)],
		[r0, Vector2(0.0, v0)], [r1, Vector2(0.0, v1)], [l1, Vector2(1.0, v1)],
	]
	for d in data:
		st.set_normal(up)
		st.set_uv(d[1])
		st.add_vertex(d[0])


# --- 개천 ---

func _build_stream() -> void:
	var pts := PackedVector2Array()
	var x := HanyangMap.STREAM_X0 + 10.0
	while x < 246.0:
		pts.append(Vector2(x, HanyangMap.stream_z(x)))
		x += 4.0

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader") as Shader

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 5.0
	var acc := 0.0
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		# 수면은 개천 중심 둑 높이보다 0.6m 낮게 둔다
		var y0 := HanyangMap.height_no_carve(p0.x, p0.y) - 0.6
		var y1 := HanyangMap.height_no_carve(p1.x, p1.y) - 0.6
		var a := Vector3(p0.x, y0, p0.y - half)
		var b := Vector3(p0.x, y0, p0.y + half)
		var c := Vector3(p1.x, y1, p1.y - half)
		var d := Vector3(p1.x, y1, p1.y + half)
		var v0 := acc / 8.0
		acc += p0.distance_to(p1)
		var v1 := acc / 8.0
		var data := [
			[a, Vector2(0.0, v0)], [b, Vector2(1.0, v0)], [c, Vector2(0.0, v1)],
			[b, Vector2(1.0, v0)], [d, Vector2(1.0, v1)], [c, Vector2(0.0, v1)],
		]
		for q in data:
			st.set_normal(Vector3.UP)
			st.set_uv(q[1])
			st.add_vertex(q[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var label := Label3D.new()
	label.text = "개천"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var lx := 20.0
	label.position = Vector3(lx, HanyangMap.height_no_carve(lx, HanyangMap.stream_z(lx)) + 3.0, HanyangMap.stream_z(lx))
	label.font_size = 56
	label.pixel_size = 0.012
	label.outline_size = 12
	label.visibility_range_end = 80.0
	add_child(label)


# --- 광화문, 관청 ---

func _build_gwanghwamun() -> void:
	var p := HanyangMap.GWANGHWAMUN
	var gate := PalaceGate.new()
	gate.setup("광화문", true, Vector3(p.x, HanyangMap.height(p.x, p.y), p.y), 0.0)
	add_child(gate)


func _build_offices() -> void:
	var z0 := HanyangMap.GWANGHWAMUN.y + 10.0
	var ax := HanyangMap.GWANGHWAMUN.x
	for i in EAST_OFFICES.size():
		_office(EAST_OFFICES[i], Vector2(ax + 15.0, z0 + i * 12.0), -PI / 2.0)
	for i in WEST_OFFICES.size():
		_office(WEST_OFFICES[i], Vector2(ax - 15.0, z0 + i * 12.0), PI / 2.0)


func _office(office_name: String, p: Vector2, yaw: float) -> void:
	var h := HanyangMap.height(p.x, p.y)
	var hk := Hanok.new()
	hk.setup(Hanok.Style.TILE, 3, 2, Vector3(p.x, h, p.y), yaw, true)
	add_child(hk)
	# 관청 마당 앞 횃불 두 개
	for sx in [-1.0, 1.0]:
		var tx: float = sx
		var off := Basis(Vector3.UP, yaw) * Vector3(tx * 4.5, 0.0, 5.5)
		var tp := Vector2(p.x + off.x, p.y + off.z)
		var tc := Torch.new()
		tc.position = Vector3(tp.x, HanyangMap.height(tp.x, tp.y), tp.y)
		add_child(tc)
	var label := Label3D.new()
	label.text = office_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(p.x, h + 9.0, p.y)
	label.font_size = 56
	label.pixel_size = 0.012
	label.outline_size = 12
	label.visibility_range_end = 75.0
	add_child(label)


# --- 민가 ---

func _build_neighborhoods() -> void:
	for zone in ZONES:
		var rect: Rect2 = zone["rect"]
		var cols := int(rect.size.x / CELL_W)
		var rows := int(rect.size.y / CELL_D)
		for j in rows:
			for i in cols:
				if _rng.randf() > float(zone["dens"]):
					continue
				var c := rect.position + Vector2((i + 0.5) * CELL_W, (j + 0.5) * CELL_D)
				c += Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8))
				if _blocked(c):
					continue
				var tile := _rng.randf() < float(zone["tile"])
				_house(c, tile)


# --- 개천 다리와 둑 ---

## 길이 개천을 가로지르는 곳마다 나무다리를 놓는다. 바닥(걸을 수 있음)과 난간(막힘)에 충돌이 있고,
## 개천 물에는 들어가 걸을 수 있다(젖으면 체온이 더 빨리 식음). 근거: 고증_근거.md 39장 (설계).
func _build_stream_bridges() -> void:
	_bridges.clear()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.40, 0.30, 0.21)
	wood.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.29, 0.21, 0.14)
	dark.roughness = 0.9
	for li in _road_lines.size():
		var pts := _road_lines[li]
		var w := _road_widths[li]
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			if p0.x < HanyangMap.STREAM_X0 + 12.0 or p0.x > HanyangMap.STREAM_X1 - 12.0:
				continue
			var f0 := p0.y - HanyangMap.stream_z(p0.x)
			var f1 := p1.y - HanyangMap.stream_z(p1.x)
			if f0 * f1 > 0.0 or is_equal_approx(f0, f1):
				continue
			var c := p0.lerp(p1, f0 / (f0 - f1))
			var dir := (p1 - p0).normalized()
			var half_len := 10.5 / maxf(absf(dir.y), 0.45)
			_make_bridge(c, dir, half_len, w * 0.5, wood, dark)


func _make_bridge(c: Vector2, dir: Vector2, half_len: float, half_w: float, wood: Material, dark: Material) -> void:
	var a := c - dir * half_len
	var b := c + dir * half_len
	# 바닥 윗면은 양쪽 땅과 같은 높이로 맞춘다 (0.14 m만 높아도 캐릭터가 턱에 걸려 못 오른다)
	var ya := HanyangMap.height_no_carve(a.x, a.y) + 0.02
	var yb := HanyangMap.height_no_carve(b.x, b.y) + 0.02
	var fwd := Vector3(dir.x, (yb - ya) / (half_len * 2.0), dir.y).normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	var up := fwd.cross(right).normalized()
	var bas := Basis(right, up, fwd)
	var mid := Vector3((a.x + b.x) * 0.5, (ya + yb) * 0.5, (a.y + b.y) * 0.5)
	var length := half_len * 2.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("surface", "plank")
	body.transform = Transform3D(bas, mid)
	add_child(body)
	# 바닥: 윗면이 길 윗면과 같다
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_w * 2.0 + 0.6, 0.4, length)
	cs.shape = box
	cs.position = Vector3(0.0, -0.2, 0.0)
	body.add_child(cs)
	# 양 끝 경사: 바닥 끝에서 땅 속으로 완만하게 잠기는 판. 땅 높이가 조금 달라도 걸리지 않고 오르내린다.
	var ang := atan2(0.35, 2.5)
	for e in [-1.0, 1.0]:
		var ee: float = e
		var rs := CollisionShape3D.new()
		var rbx := BoxShape3D.new()
		rbx.size = Vector3(half_w * 2.0 + 0.6, 0.4, Vector2(2.5, 0.35).length())
		rs.shape = rbx
		rs.transform = Transform3D(Basis(Vector3.RIGHT, ee * ang), Vector3(0.0, -0.175 - 0.2 * cos(ang), ee * (half_len + 1.25) - 0.2 * ee * sin(ang)))
		body.add_child(rs)
	# 난간 충돌
	for sx in [-1.0, 1.0]:
		var rc := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(0.25, 1.5, length)
		rc.shape = rb
		rc.position = Vector3(float(sx) * (half_w + 0.3), 0.75, 0.0)
		body.add_child(rc)
	# 보이는 모양: 바닥 보, 난간 기둥과 가로대, 교각
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half_w * 2.0 + 0.8, 0.5, length)
	beam.mesh = bm
	beam.material_override = wood
	beam.position = Vector3(0.0, -0.13, 0.0)
	body.add_child(beam)
	for sx in [-1.0, 1.0]:
		var x: float = float(sx) * (half_w + 0.3)
		for yy in [0.45, 0.95]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.12, 0.1, length)
			rail.mesh = rm
			rail.material_override = wood
			rail.position = Vector3(x, float(yy), 0.0)
			body.add_child(rail)
		var n_post := int(length / 3.0) + 1
		for k in n_post:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.18, 1.1, 0.18)
			post.mesh = pm
			post.material_override = dark
			post.position = Vector3(x, 0.5, -half_len + 0.2 + float(k) * (length - 0.4) / float(n_post - 1))
			body.add_child(post)
	for k in 3:
		for sx in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.4, 3.0, 0.4)
			leg.mesh = lm
			leg.material_override = dark
			leg.position = Vector3(float(sx) * (half_w - 0.3), -1.7, (float(k) - 1.0) * length * 0.28)
			body.add_child(leg)
	_bridges.append({"c": c, "dir": dir, "half_len": half_len + 0.5, "half_w": half_w + 0.8})


func _on_bridge(p: Vector2) -> bool:
	for br in _bridges:
		var d: Vector2 = br["dir"]
		var rel := p - (br["c"] as Vector2)
		if absf(rel.dot(d)) < float(br["half_len"]) and absf(rel.dot(Vector2(-d.y, d.x))) < float(br["half_w"]):
			return true
	return false


func _blocked(p: Vector2) -> bool:
	if HanyangMap.u_of(p.x, p.y) > 0.84:
		return true
	# 경복궁과 육조거리 관청 구역
	if Rect2(-84.0, -158.0, 108.0, 130.0).has_point(p):
		return true
	if HanyangMap.JONGMYO_RECT.has_point(p) or HanyangMap.SAJIK_RECT.has_point(p):
		return true
	var sx := HanyangMap.STREAM_X0 - 10.0
	if p.x > sx and p.x < HanyangMap.STREAM_X1 and absf(p.y - HanyangMap.stream_z(p.x)) < 11.0:
		return true
	for r in _reserved:
		if p.distance_to(r) < 12.0:
			return true
	for i in _road_pts.size():
		if p.distance_to(_road_pts[i]) < _road_half[i] + 9.0:
			return true
	var h := HanyangMap.height(p.x, p.y)
	if absf(HanyangMap.height(p.x + 2.0, p.y) - h) > 0.7 or absf(HanyangMap.height(p.x, p.y + 2.0) - h) > 0.7:
		return true
	return false


func _house(p: Vector2, tile: bool) -> void:
	var nx := 3 if tile else _rng.randi_range(2, 3)
	var nz := 2 if tile else _rng.randi_range(1, 2)
	var gh := HanyangMap.height(p.x, p.y)
	var hk := Hanok.new()
	var style: int = Hanok.Style.TILE if tile else Hanok.Style.THATCH
	# 집은 남향(+Z)이고 앞마당이 넓도록 조금 북쪽에 둔다
	hk.setup(style, nx, nz, Vector3(p.x, gh, p.y - 1.0), 0.0)
	add_child(hk)
	house_points.append(Vector2(p.x, p.y + 4.0))
	_yard_wall(p, gh)


## 마당을 두른 흙담. 남쪽 가운데에 문 틈을 낸다. 골목은 담과 담 사이 약 2m.
func _yard_wall(p: Vector2, gh: float) -> void:
	var hx := 6.5
	var hz := 5.5
	var t := 0.3
	var hgt := 1.7
	var mat := Hanok.shared_mat(Color(0.6, 0.5, 0.36), 1.0)
	_wall_piece(Vector3(p.x, gh, p.y - hz), Vector3(hx * 2.0, hgt, t), mat)
	_wall_piece(Vector3(p.x - hx, gh, p.y), Vector3(t, hgt, hz * 2.0), mat)
	_wall_piece(Vector3(p.x + hx, gh, p.y), Vector3(t, hgt, hz * 2.0), mat)
	var gap := 1.3
	var seg := hx - gap
	_wall_piece(Vector3(p.x - (gap + seg * 0.5), gh, p.y + hz), Vector3(seg, hgt, t), mat)
	_wall_piece(Vector3(p.x + (gap + seg * 0.5), gh, p.y + hz), Vector3(seg, hgt, t), mat)


func _wall_piece(base: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.visibility_range_end = VIS_END
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(base.x, base.y + size.y * 0.5 - 0.5, base.z)
	add_child(body)
