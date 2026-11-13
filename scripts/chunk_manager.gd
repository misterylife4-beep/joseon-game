class_name ChunkManager
extends Node3D
## 플레이어 주변의 지형 청크만 만들고 먼 청크는 지운다.
## 높이는 HanyangMap이 정한다: 내사산이 감싼 분지와 개천, 경복궁 터.

@export var chunk_size := 64.0
@export var resolution := 32
@export var view_radius := 4
@export var height_scale := 24.0
@export var trees_per_chunk := 30
@export var grass_per_chunk := 260

var target: Node3D

var _material: ShaderMaterial
var _pine_mesh: ArrayMesh
var _broad_mesh: ArrayMesh
var _grass_mesh: ArrayMesh
var _grass_mat: ShaderMaterial
var _rock_mesh: ArrayMesh
var _shrub_mesh: ArrayMesh
## 계절이 바뀌면 Season이 색을 바꾸는 나무 잎 재질
static var pine_crown_mat: StandardMaterial3D
static var broad_crown_mat: StandardMaterial3D
static var rock_mat: StandardMaterial3D
static var shrub_mat: StandardMaterial3D
var _chunks: Dictionary = {}  # Vector2i -> Node3D
var _pending: Array[Vector2i] = []
var _last_center := Vector2i(1 << 30, 1 << 30)


var _trunk_shape: CylinderShape3D
## 도끼로 벤 나무. 청크가 다시 만들어져도 베인 나무는 심지 않는다. 열쇠는 "청크x,청크z,번호".
static var felled: Dictionary = {}
const TREE_HP := 6.0   ## 나무 한 그루를 쓰러뜨리는 데 드는 힘(도끼 한 번의 힘이 1~2). [설계]

func _ready() -> void:
	add_to_group("chunks")
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/terrain.gdshader") as Shader
	_material.set_shader_parameter("noise_tex", _make_noise_texture())
	_material.set_shader_parameter("city_axes", Vector2(HanyangMap.A, HanyangMap.B))
	_material.set_shader_parameter("height_ref", 40.0)

	_pine_mesh = _make_pine_mesh()
	_broad_mesh = _make_broadleaf_mesh()
	_grass_mesh = _make_grass_mesh()
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = load("res://shaders/grass.gdshader") as Shader
	_rock_mesh = _make_rock_mesh()
	_shrub_mesh = _make_shrub_mesh()
	rock_mat = StandardMaterial3D.new()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.roughness = 0.97
	shrub_mat = StandardMaterial3D.new()
	shrub_mat.vertex_color_use_as_albedo = true
	shrub_mat.roughness = 1.0


## 한쪽으로 휜 붉은 줄기와 납작하게 층진 솔잎 덩어리.
## 소나무(Pinus densiflora)가 조선의 대표 수종이라는 점만 사료이고, 모양 수치는 설계값이다.
func _pine_lean(t: float) -> float:
	return sin(t * 3.1) * 0.35 * t + t * t * 0.4


func _make_pine_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var top := 5.2

	# 줄기: 위로 갈수록 가늘고 휘어진다
	var tr := SurfaceTool.new()
	tr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 7
	var segs := 8
	for j in rings:
		var t0 := float(j) / rings
		var t1 := float(j + 1) / rings
		var c0 := Vector3(_pine_lean(t0), t0 * top, 0.0)
		var c1 := Vector3(_pine_lean(t1), t1 * top, 0.0)
		var r0 := lerpf(0.3, 0.1, t0)
		var r1 := lerpf(0.3, 0.1, t1)
		for k in segs:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var p00 := c0 + d0 * r0
			var p01 := c0 + d1 * r0
			var p10 := c1 + d0 * r1
			var p11 := c1 + d1 * r1
			_mtri(tr, p00, p01, p11, d0, d1, d1, Color(1, 1, 1))
			_mtri(tr, p00, p11, p10, d0, d1, d0, Color(1, 1, 1))
	tr.commit(mesh)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.42, 0.23, 0.15)
	trunk_mat.roughness = 1.0
	mesh.surface_set_material(0, trunk_mat)

	# 솔잎 덩어리: 납작한 타원체 네 개
	var cr := SurfaceTool.new()
	cr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pads := [
		[Vector3(_pine_lean(0.62), 3.3, 0.0), Vector3(1.7, 0.45, 1.4)],
		[Vector3(_pine_lean(0.8) + 0.6, 4.3, 0.2), Vector3(1.5, 0.4, 1.3)],
		[Vector3(_pine_lean(1.0), 5.4, 0.0), Vector3(1.2, 0.4, 1.1)],
		[Vector3(_pine_lean(0.5) - 1.2, 2.7, -0.3), Vector3(1.0, 0.3, 0.9)],
	]
	for pad in pads:
		_ellipsoid(cr, pad[0], pad[1], Color(0.1, 0.22, 0.09))
	cr.commit(mesh)
	var crown_mat := StandardMaterial3D.new()
	crown_mat.vertex_color_use_as_albedo = true
	crown_mat.roughness = 1.0
	pine_crown_mat = crown_mat
	mesh.surface_set_material(1, crown_mat)
	return mesh


## 참나무류를 흉내 낸 둥근 활엽수. 도성 주변 산은 소나무가 많고 활엽수는 적게 섞는다 (설계값).
func _make_broadleaf_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var tr := SurfaceTool.new()
	tr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		_mtri(tr, d0 * 0.3, d1 * 0.3, d1 * 0.16 + Vector3(0, 3.6, 0), d0, d1, d1, Color(1, 1, 1))
		_mtri(tr, d0 * 0.3, d1 * 0.16 + Vector3(0, 3.6, 0), d0 * 0.16 + Vector3(0, 3.6, 0), d0, d1, d0, Color(1, 1, 1))
	tr.commit(mesh)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.3, 0.24, 0.18)
	trunk_mat.roughness = 1.0
	mesh.surface_set_material(0, trunk_mat)

	var cr := SurfaceTool.new()
	cr.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(cr, Vector3(0.0, 4.4, 0.0), Vector3(2.2, 1.7, 2.1), Color(0.2, 0.36, 0.13))
	_ellipsoid(cr, Vector3(1.0, 3.7, 0.5), Vector3(1.3, 1.0, 1.2), Color(0.22, 0.38, 0.14))
	cr.commit(mesh)
	var crown_mat := StandardMaterial3D.new()
	crown_mat.vertex_color_use_as_albedo = true
	crown_mat.roughness = 1.0
	broad_crown_mat = crown_mat
	mesh.surface_set_material(1, crown_mat)
	return mesh


## 풀포기: 서로 엇갈린 세 장의 세로 판. 높이와 폭은 설계값.
func _make_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.3
	var ht := 0.55
	for i in 3:
		var a := PI * i / 3.0
		var dir := Vector3(cos(a), 0.0, sin(a)) * hw
		var q := [
			[-dir, Vector2(0.0, 0.0)], [dir, Vector2(1.0, 0.0)], [dir + Vector3(0, ht, 0), Vector2(1.0, 1.0)],
			[-dir, Vector2(0.0, 0.0)], [dir + Vector3(0, ht, 0), Vector2(1.0, 1.0)], [-dir + Vector3(0, ht, 0), Vector2(0.0, 1.0)],
		]
		for v in q:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


## 삼각형 하나. 바깥쪽(hint) 방향이 앞면이 되도록 감는 방향을 맞추고 꼭짓점 법선을 쓴다.
func _mtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 0.0000001:
		return
	var hint := na + nb + nc
	if cr.dot(hint) > 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
	st.set_color(col)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(nc)
	st.add_vertex(c)


## 반지름이 r(x,y,z)인 타원체. 위쪽은 밝게, 아래쪽은 어둡게 칠한다.
func _ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> void:
	var lat := 5
	var lon := 10
	for i in lat:
		var th0 := PI * i / lat
		var th1 := PI * (i + 1) / lat
		for k in lon:
			var ph0 := TAU * k / lon
			var ph1 := TAU * (k + 1) / lon
			var d00 := _sph(th0, ph0)
			var d01 := _sph(th0, ph1)
			var d10 := _sph(th1, ph0)
			var d11 := _sph(th1, ph1)
			var c00 := _shade(col, d00.y)
			var c01 := _shade(col, d01.y)
			var c10 := _shade(col, d10.y)
			var c11 := _shade(col, d11.y)
			var p00 := c + d00 * r
			var p01 := c + d01 * r
			var p10 := c + d10 * r
			var p11 := c + d11 * r
			_mtri(st, p00, p01, p11, d00, d01, d11, (c00 + c01 + c11) / 3.0)
			_mtri(st, p00, p11, p10, d00, d11, d10, (c00 + c11 + c10) / 3.0)


func _sph(th: float, ph: float) -> Vector3:
	return Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))


func _shade(col: Color, up: float) -> Color:
	var f := 0.65 + 0.4 * clampf(up * 0.5 + 0.5, 0.0, 1.0)
	return Color(col.r * f, col.g * f, col.b * f)


func _make_noise_texture() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	var img := n.get_seamless_image(512, 512)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func height_at(x: float, z: float) -> float:
	return HanyangMap.height(x, z)


## 게임 시작 때 플레이어 아래 지형을 즉시 만들어 허공에 떨어지지 않게 한다.
func prime(pos: Vector3) -> void:
	var c := _chunk_of(pos)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _chunks.has(key):
				_build_chunk(key)


func _process(_delta: float) -> void:
	if target == null:
		return
	var c := _chunk_of(target.global_position)
	if c != _last_center:
		_last_center = c
		_refresh(c)
	if not _pending.is_empty():
		var key: Vector2i = _pending.pop_front()
		if not _chunks.has(key):
			_build_chunk(key)


func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))


func _refresh(center: Vector2i) -> void:
	for key in _chunks.keys():
		var k: Vector2i = key
		if maxi(absi(k.x - center.x), absi(k.y - center.y)) > view_radius + 1:
			(_chunks[k] as Node3D).queue_free()
			_chunks.erase(k)

	_pending.clear()
	for dz in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			if not _chunks.has(key):
				_pending.append(key)
	_pending.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - center).length_squared() < (b - center).length_squared()
	)


func _build_chunk(key: Vector2i) -> void:
	var origin := Vector3(key.x * chunk_size, 0.0, key.y * chunk_size)
	var step := chunk_size / float(resolution)
	var n := resolution + 1

	# 가장자리 법선을 위해 사방으로 한 칸씩 더 샘플링한다. 높이 함수 호출을 줄이는 방법이다.
	var pn := n + 2
	var padded := PackedFloat32Array()
	padded.resize(pn * pn)
	for zi in pn:
		for xi in pn:
			padded[zi * pn + xi] = height_at(origin.x + (xi - 1) * step, origin.z + (zi - 1) * step)

	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var normals: Array[Vector3] = []
	normals.resize(n * n)
	for zi in n:
		for xi in n:
			var pidx := (zi + 1) * pn + (xi + 1)
			var idx := zi * n + xi
			heights[idx] = padded[pidx]
			var hl := padded[pidx - 1]
			var hr := padded[pidx + 1]
			var hd := padded[pidx - pn]
			var hu := padded[pidx + pn]
			normals[idx] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in resolution:
		for xi in resolution:
			var i00 := zi * n + xi
			var i10 := i00 + 1
			var i01 := i00 + n
			var i11 := i01 + 1
			# 삼각형 두 개: 시계 방향이 앞면
			_add_vertex(st, heights, normals, i00, xi, zi, step)
			_add_vertex(st, heights, normals, i10, xi + 1, zi, step)
			_add_vertex(st, heights, normals, i01, xi, zi + 1, step)
			_add_vertex(st, heights, normals, i10, xi + 1, zi, step)
			_add_vertex(st, heights, normals, i11, xi + 1, zi + 1, step)
			_add_vertex(st, heights, normals, i01, xi, zi + 1, step)

	var chunk := Node3D.new()
	chunk.position = origin

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material
	chunk.add_child(mi)

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	cs.shape = shape
	cs.position = Vector3(chunk_size * 0.5, 0.0, chunk_size * 0.5)
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)
	chunk.add_child(body)

	_add_trees(chunk, key, origin)

	add_child(chunk)
	_chunks[key] = chunk


## 청크마다 같은 위치에 같은 나무가 나오도록 청크 좌표로 난수를 고정한다.
## 도성 주변과 가파른 곳, 너무 높은 곳에는 심지 않는다. 줄기에는 충돌을 둔다.
func _add_trees(chunk: Node3D, key: Vector2i, origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 1392

	var pines: Array[Transform3D] = []
	var broads: Array[Transform3D] = []
	var pine_ids: Array[String] = []
	var broad_ids: Array[String] = []
	var tree_count := int(float(trees_per_chunk) * Region.tree_boost(origin.x + chunk_size * 0.5, origin.z + chunk_size * 0.5))
	for i in tree_count:
		var lx := rng.randf() * chunk_size
		var lz := rng.randf() * chunk_size
		var s := rng.randf_range(0.9, 1.8)
		var yaw := rng.randf() * TAU
		var broad := rng.randf() < 0.2
		var wx := origin.x + lx
		var wz := origin.z + lz
		# 도성 안쪽 평지와 성벽 바로 곁에는 심지 않는다. 안쪽 산비탈에는 드문드문 둔다.
		var u := HanyangMap.u_of(wx, wz)
		if u < 0.88 or (u > 0.96 and u < 1.04):
			continue
		if u < 1.0 and rng.randf() < 0.5:
			continue
		if wz > 150.0 and HanyangMap.river_dist(wx, wz) < 60.0:
			continue  # 강가와 강바닥에는 나무를 심지 않는다 (논과 갈대밭 자리)
		if OuterRoads.near_road(wx, wz) or Region.no_plant(wx, wz):
			continue  # 성 밖 길 위에는 심지 않는다
		var h := height_at(wx, wz)
		var gx := height_at(wx + 1.0, wz) - h
		var gz := height_at(wx, wz + 1.0) - h
		if sqrt(gx * gx + gz * gz) > 0.75:
			continue
		var fk := "%d,%d,%d" % [key.x, key.y, i]
		if felled.has(fk):
			continue
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(lx, h - 0.1, lz))
		if broad:
			broads.append(xf)
			broad_ids.append(fk)
		else:
			pines.append(xf)
			pine_ids.append(fk)

	_add_grass(chunk, key, origin)
	_add_rocks_and_shrubs(chunk, key, origin)
	var pine_mm := _add_multimesh(chunk, _pine_mesh, null, pines)
	var broad_mm := _add_multimesh(chunk, _broad_mesh, null, broads)
	var shapes := _add_trunk_colliders(chunk, pines, broads)
	# 벌목을 위한 나무 목록: 위치, 멀티메시 번호, 줄기 충돌 모양
	var list: Array[Dictionary] = []
	for j in pines.size():
		list.append({"id": pine_ids[j], "xf": pines[j], "mm": pine_mm, "idx": j, "cs": shapes[j], "hp": TREE_HP})
	for j in broads.size():
		list.append({"id": broad_ids[j], "xf": broads[j], "mm": broad_mm, "idx": j, "cs": shapes[pines.size() + j], "hp": TREE_HP})
	chunk.set_meta("trees", list)


## 나무 줄기 충돌: 청크마다 한 몸에 줄기 모양 기둥을 모아 붙인다. 반지름과 높이는 설계값이다.
func _add_trunk_colliders(chunk: Node3D, pines: Array[Transform3D], broads: Array[Transform3D]) -> Array:
	var made: Array = []
	if pines.is_empty() and broads.is_empty():
		return made
	if _trunk_shape == null:
		_trunk_shape = CylinderShape3D.new()
		_trunk_shape.radius = 0.38
		_trunk_shape.height = 3.0
	var body := StaticBody3D.new()
	for xf in pines + broads:
		var cs := CollisionShape3D.new()
		cs.shape = _trunk_shape
		cs.position = xf.origin + Vector3(0.0, 1.5, 0.0)
		body.add_child(cs)
		made.append(cs)
	chunk.add_child(body)
	return made


## 이 자리 가까이의 서 있는 나무 하나 (없으면 빈 사전). r 은 반지름(m).
func nearest_tree(p: Vector3, r: float) -> Dictionary:
	var c := _chunk_of(p)
	var best := {}
	var best_d := r
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k := Vector2i(c.x + dx, c.y + dz)
			if not _chunks.has(k):
				continue
			var ch: Node3D = _chunks[k]
			if not ch.has_meta("trees"):
				continue
			for e in (ch.get_meta("trees") as Array):
				if e.has("gone"):
					continue
				var o: Vector3 = ch.position + (e["xf"] as Transform3D).origin
				var d := Vector2(o.x - p.x, o.z - p.z).length()
				if d < best_d:
					best_d = d
					best = e
					best["chunk"] = ch
	return best


## 도끼질 한 번. 쓰러뜨렸으면 참을 돌려준다.
func chop(e: Dictionary, power: float, from: Vector3) -> bool:
	e["hp"] = float(e["hp"]) - power
	if float(e["hp"]) > 0.0:
		return false
	e["gone"] = true
	felled[String(e["id"])] = true
	var xf: Transform3D = e["xf"]
	var mm: MultiMesh = e["mm"]
	if mm != null:
		mm.set_instance_transform(int(e["idx"]), Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))
	var cs: CollisionShape3D = e["cs"]
	if is_instance_valid(cs):
		cs.set_deferred("disabled", true)
	var ch: Node3D = e["chunk"]
	var s := xf.basis.get_scale().x
	# 그루터기와 쓰러지는 줄기
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.12)
	wood.roughness = 1.0
	var stump := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.28 * s
	sm.bottom_radius = 0.34 * s
	sm.height = 0.4
	stump.mesh = sm
	stump.material_override = wood
	stump.position = xf.origin + Vector3(0.0, 0.2, 0.0)
	ch.add_child(stump)
	var trunk := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.18 * s
	lm.bottom_radius = 0.3 * s
	lm.height = 5.0 * s
	trunk.mesh = lm
	trunk.material_override = wood
	var piv := Node3D.new()
	piv.position = xf.origin + Vector3(0.0, 0.4, 0.0)
	ch.add_child(piv)
	trunk.position = Vector3(0.0, lm.height * 0.5, 0.0)
	piv.add_child(trunk)
	var away := Vector2(xf.origin.x + ch.position.x - from.x, xf.origin.z + ch.position.z - from.z)
	if away.length() < 0.01:
		away = Vector2(0.0, 1.0)
	away = away.normalized()
	var axis := Vector3(away.y, 0.0, -away.x)   # 베는 사람 반대쪽으로 넘어진다
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: piv.basis = Basis(axis, a), 0.0, PI * 0.5 - 0.05, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(14.0)
	tw.tween_callback(func() -> void: piv.queue_free())
	return true


## 도성 안쪽 흙마당과 가파른 비탈, 길가를 피해 풀포기를 흩뿌린다.
func _add_grass(chunk: Node3D, key: Vector2i, origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 1396
	var xs: Array[Transform3D] = []
	for i in grass_per_chunk:
		var lx := rng.randf() * chunk_size
		var lz := rng.randf() * chunk_size
		var wx := origin.x + lx
		var wz := origin.z + lz
		var u := HanyangMap.u_of(wx, wz)
		if u < 0.86:
			continue
		if absf(wz - HanyangMap.stream_z(wx)) < 7.0 and wx > HanyangMap.STREAM_X0:
			continue
		if wz > 150.0 and HanyangMap.river_dist(wx, wz) < 52.0:
			continue
		if OuterRoads.near_road(wx, wz) or Region.no_plant(wx, wz):
			continue
		var h := height_at(wx, wz)
		var gx := height_at(wx + 1.0, wz) - h
		var gz := height_at(wx, wz + 1.0) - h
		if sqrt(gx * gx + gz * gz) > 0.6:
			continue
		if h > 27.0:
			continue
		var sc := rng.randf_range(0.7, 1.5)
		var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
		xs.append(Transform3D(bs, Vector3(lx, h, lz)))
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _grass_mesh
	mm.instance_count = xs.size()
	for j in xs.size():
		mm.set_instance_transform(j, xs[j])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 110.0
	chunk.add_child(mmi)


func _add_multimesh(chunk: Node3D, mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> MultiMesh:
	if transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	chunk.add_child(mmi)
	return mm


func _add_vertex(
	st: SurfaceTool,
	heights: PackedFloat32Array,
	normals: Array[Vector3],
	idx: int,
	xi: int,
	zi: int,
	step: float
) -> void:
	var h := heights[idx]
	st.set_normal(normals[idx])
	st.set_color(_color_for(h))
	st.add_vertex(Vector3(xi * step, h, zi * step))


func _color_for(h: float) -> Color:
	var t := clampf(h / (height_scale * 1.2), 0.0, 1.0)
	var field := Color(0.55, 0.6, 0.34)
	var forest := Color(0.28, 0.46, 0.24)
	var rock := Color(0.46, 0.43, 0.4)
	if t < 0.35:
		return field.lerp(forest, t / 0.35)
	return forest.lerp(rock, (t - 0.35) / 0.65)


## 화강암 바위: 납작한 타원체 서너 개를 겹친 덩어리. 인왕산은 암반이 40% 이상이라는 조사에 따라
## 능선 쪽에 바위를 많이 흩뜨린다. 크기와 개수는 설계값이다.
func _make_rock_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0.0, 0.5, 0.0), Vector3(1.5, 0.9, 1.2), Color(0.6, 0.58, 0.54))
	_ellipsoid(st, Vector3(0.9, 0.35, 0.4), Vector3(0.9, 0.6, 0.8), Color(0.54, 0.52, 0.49))
	_ellipsoid(st, Vector3(-0.8, 0.3, -0.5), Vector3(0.8, 0.5, 0.7), Color(0.64, 0.62, 0.58))
	st.commit(mesh)
	return mesh


## 진달래나 싸리 같은 낮은 관목(수종은 일반적 추정, 모양은 설계값)
func _make_shrub_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0.0, 0.5, 0.0), Vector3(0.7, 0.55, 0.65), Color(0.2, 0.3, 0.1))
	_ellipsoid(st, Vector3(0.5, 0.35, 0.2), Vector3(0.45, 0.4, 0.45), Color(0.24, 0.33, 0.11))
	_ellipsoid(st, Vector3(-0.4, 0.4, -0.2), Vector3(0.5, 0.45, 0.5), Color(0.18, 0.28, 0.1))
	st.commit(mesh)
	return mesh


func _add_rocks_and_shrubs(chunk: Node3D, key: Vector2i, origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 1398
	var rocks: Array[Transform3D] = []
	var shrubs: Array[Transform3D] = []
	for i in 14:
		var lx := rng.randf() * chunk_size
		var lz := rng.randf() * chunk_size
		var wx := origin.x + lx
		var wz := origin.z + lz
		var u := HanyangMap.u_of(wx, wz)
		if u < 0.88:
			continue
		if wz > 150.0 and HanyangMap.river_dist(wx, wz) < 55.0:
			continue
		var h := height_at(wx, wz)
		var gx := height_at(wx + 1.0, wz) - h
		var gz := height_at(wx, wz + 1.0) - h
		var slope := sqrt(gx * gx + gz * gz)
		var sc := rng.randf_range(0.6, 1.9)
		var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.7, 1.1), sc))
		if h > 12.0 and (slope > 0.3 or rng.randf() < 0.35):
			rocks.append(Transform3D(bs, Vector3(lx, h - 0.25, lz)))
		elif slope < 0.55 and h < 24.0 and rng.randf() < 0.7:
			var ss := rng.randf_range(0.8, 1.7)
			shrubs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ss, ss, ss)), Vector3(lx, h - 0.05, lz)))
	_add_multimesh(chunk, _rock_mesh, rock_mat, rocks)
	_add_multimesh(chunk, _shrub_mesh, shrub_mat, shrubs)
