class_name Hanok
extends Node3D
## 절차적으로 만든 한옥(기와집)과 초가집. 정면은 +Z 방향이다.

enum Style { TILE, THATCH }

const KAN := 3.0
const WALL_H := 2.6

var _style: int = Style.TILE
var _nx := 3
var _nz := 2
## 관아·문루 여부. 단청 띠, 공포, 높은 기단은 관아·문루에만 넣는다 (민가에는 없음).
var _official := false

static var _mats: Dictionary = {}
static var _lattice: ShaderMaterial
static var _roof_mats: Dictionary = {}

## 멀리서는 그리지 않는다. 집이 많아 장면이 무거워지는 것을 막는다.
const VIS_END := 150.0


func setup(style: int, kan_x: int, kan_z: int, pos: Vector3, yaw: float, official := false) -> void:
	_official = official
	_style = style
	_nx = kan_x
	_nz = kan_z
	position = pos
	rotation.y = yaw
	_build()


## 같은 색 재질은 하나를 함께 쓴다.
static func shared_mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	return shared_mat(color, rough)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.visibility_range_end = VIS_END
	add_child(mi)
	return mi


func _build() -> void:
	var w := _nx * KAN
	var d := _nz * KAN
	var tile := _style == Style.TILE
	var base_h := 0.5 if tile else 0.3
	if _official:
		base_h = 0.9
	var base_mat := _mat(Color(0.5, 0.48, 0.44) if tile else Color(0.36, 0.3, 0.22), 0.95)
	var wall_mat := _mat(Color(0.74, 0.68, 0.56) if tile else Color(0.6, 0.5, 0.36), 1.0)
	var wood_mat := _mat(Color(0.34, 0.2, 0.12) if tile else Color(0.3, 0.22, 0.14), 0.8)
	var pillar_r := 0.13 if tile else 0.1

	# 기단: 경사진 땅에서도 뜨지 않도록 1m 땅속으로 묻는다
	_box(Vector3(w + 1.2, base_h + 1.0, d + 1.2), Vector3(0.0, (base_h - 1.0) * 0.5, 0.0), base_mat)

	# 기둥: 둘레를 따라 칸마다 하나씩
	for i in range(_nx + 1):
		for j in range(_nz + 1):
			if i > 0 and i < _nx and j > 0 and j < _nz:
				continue
			var px := -w * 0.5 + i * KAN
			var pz := -d * 0.5 + j * KAN
			var cm := CylinderMesh.new()
			cm.top_radius = pillar_r
			cm.bottom_radius = pillar_r
			cm.height = WALL_H
			cm.radial_segments = 10
			cm.rings = 1
			var pi := MeshInstance3D.new()
			pi.mesh = cm
			pi.material_override = wood_mat
			pi.position = Vector3(px, base_h + WALL_H * 0.5, pz)
			pi.visibility_range_end = VIS_END
			add_child(pi)

	# 뒷벽과 옆벽: 흙벽
	_box(Vector3(w, WALL_H, 0.16), Vector3(0.0, base_h + WALL_H * 0.5, -d * 0.5), wall_mat)
	_box(Vector3(0.16, WALL_H, d), Vector3(-w * 0.5, base_h + WALL_H * 0.5, 0.0), wall_mat)
	_box(Vector3(0.16, WALL_H, d), Vector3(w * 0.5, base_h + WALL_H * 0.5, 0.0), wall_mat)

	# 앞면: 칸마다 머름과 창호
	if _lattice == null:
		_lattice = ShaderMaterial.new()
		_lattice.shader = load("res://shaders/lattice.gdshader")
	var lattice := _lattice
	var mureum_h := 0.45
	var panel_h := WALL_H - 0.55
	for i in range(_nx):
		var cx := -w * 0.5 + (i + 0.5) * KAN
		_box(Vector3(KAN - 0.2, mureum_h, 0.16), Vector3(cx, base_h + mureum_h * 0.5, d * 0.5), wall_mat)
		_box(Vector3(KAN - 0.3, panel_h, 0.05), Vector3(cx, base_h + mureum_h + panel_h * 0.5, d * 0.5), lattice)

	# 도리: 기둥 위를 두르는 보
	var top_y := base_h + WALL_H + 0.1
	_box(Vector3(w + 0.3, 0.2, 0.25), Vector3(0.0, top_y, d * 0.5), wood_mat)
	_box(Vector3(w + 0.3, 0.2, 0.25), Vector3(0.0, top_y, -d * 0.5), wood_mat)
	_box(Vector3(0.25, 0.2, d + 0.3), Vector3(-w * 0.5, top_y, 0.0), wood_mat)
	_box(Vector3(0.25, 0.2, d + 0.3), Vector3(w * 0.5, top_y, 0.0), wood_mat)

	# 지붕
	var roof_y := base_h + WALL_H + 0.25
	var roof := _make_roof(w * 0.5, d * 0.5)
	if not _roof_mats.has(_style):
		var rm := ShaderMaterial.new()
		rm.shader = load("res://shaders/roof.gdshader")
		if tile:
			rm.set_shader_parameter("base_color", Color(0.13, 0.14, 0.16))
			rm.set_shader_parameter("thatch", 0.0)
		else:
			rm.set_shader_parameter("base_color", Color(0.55, 0.45, 0.26))
			rm.set_shader_parameter("thatch", 1.0)
		_roof_mats[_style] = rm
	var rmat: ShaderMaterial = _roof_mats[_style]
	roof.material_override = rmat
	roof.visibility_range_end = VIS_END
	roof.position = Vector3(0.0, roof_y, 0.0)
	add_child(roof)

	if tile:
		var rl := (w * 0.5 + 1.3) * 0.55
		var ridge_y := roof_y + 1.9 + 0.1
		_box(Vector3(rl * 2.0 + 0.6, 0.22, 0.3), Vector3(0.0, ridge_y, 0.0), _mat(Color(0.1, 0.1, 0.12), 0.7))

	_add_details(w, d, base_h, top_y, roof_y, wood_mat)

	# 충돌: 기단+몸체 한 덩어리
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w + 0.6, base_h + WALL_H, d + 0.6)
	cs.shape = shape
	cs.position = Vector3(0.0, (base_h + WALL_H) * 0.5, 0.0)
	body.add_child(cs)
	add_child(body)


func _roof_y(x: float, z: float, wr: float, dr: float, rl: float, rise: float, lift: float, expo: float) -> float:
	var ax := absf(x)
	var az := absf(z)
	var tx := clampf((wr - ax) / maxf(wr - rl, 0.001), 0.0, 1.0)
	var tz := clampf((dr - az) / dr, 0.0, 1.0)
	return rise * pow(minf(tx, tz), expo) + lift * pow(ax / wr, 4.0) * pow(az / dr, 2.0)


func _make_roof(half_w: float, half_d: float) -> MeshInstance3D:
	var tile := _style == Style.TILE
	var ov := 1.3 if tile else 0.9
	var rise := 1.9 if tile else 2.1
	var lift := 0.45 if tile else 0.0
	var expo := 1.4 if tile else 1.0
	var wr := half_w + ov
	var dr := half_d + ov
	var rl := wr * 0.55 if tile else wr * 0.35
	# 용마루 반길이를 지붕 반폭 기준으로 둔다 (맞배/우진각 느낌)
	var nx := 28
	var nz := 16
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for iz in range(nz + 1):
		for ix in range(nx + 1):
			var x := -wr + 2.0 * wr * float(ix) / nx
			var z := -dr + 2.0 * dr * float(iz) / nz
			var y := _roof_y(x, z, wr, dr, rl, rise, lift, expo)
			verts.append(Vector3(x, y, z))
			uvs.append(Vector2(x, z))
	for iz in range(nz):
		for ix in range(nx):
			var i00 := iz * (nx + 1) + ix
			var i10 := i00 + 1
			var i01 := i00 + (nx + 1)
			var i11 := i01 + 1
			idx.append_array([i00, i10, i01, i10, i11, i01])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# 법선 생성
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


## 세부 장식. 자료로 확인되지 않은 모양은 모두 설계값이다 (docs/고증_근거.md 6장).
func _add_details(w: float, d: float, base_h: float, top_y: float, roof_y: float, wood_mat: StandardMaterial3D) -> void:
	var tile := _style == Style.TILE
	var clay := _mat(Color(0.42, 0.36, 0.3), 1.0)
	var stone := _mat(Color(0.5, 0.48, 0.44), 0.95)

	# 섬돌: 앞 가운데에 놓은 디딤돌
	if not _official:
		_box(Vector3(1.0, 0.22, 0.55), Vector3(0.0, 0.11, d * 0.5 + 0.9), stone)

	if _official:
		# 관아: 앞면 계단과 단청 띠, 간단히 줄인 공포
		if _nz >= 2:  # 문루는 계단 없이 성문 위에 얹힌다
			_box(Vector3(2.6, 0.45, 0.7), Vector3(0.0, 0.22, d * 0.5 + 1.0), stone)
			_box(Vector3(2.0, 0.45, 0.5), Vector3(0.0, 0.67, d * 0.5 + 0.9), stone)
		var red := _mat(Color(0.55, 0.13, 0.09), 0.7)
		var green := _mat(Color(0.12, 0.38, 0.3), 0.7)
		# 도리 아래 단청 띠: 초록 바탕에 붉은 선 (단순화)
		_box(Vector3(w + 0.34, 0.14, 0.28), Vector3(0.0, top_y - 0.17, d * 0.5), green)
		_box(Vector3(w + 0.34, 0.05, 0.3), Vector3(0.0, top_y - 0.27, d * 0.5), red)
		_box(Vector3(w + 0.34, 0.14, 0.28), Vector3(0.0, top_y - 0.17, -d * 0.5), green)
		# 공포: 앞줄 기둥 위의 작은 받침 덩어리
		for i in range(_nx + 1):
			var px := -w * 0.5 + i * KAN
			_box(Vector3(0.5, 0.3, 0.5), Vector3(px, top_y + 0.22, d * 0.5), wood_mat)
			_box(Vector3(0.9, 0.12, 0.3), Vector3(px, top_y + 0.43, d * 0.5), red)
		# 처마 끝 부연: 지붕 앞가장자리 아래 붉은 띠
		if tile:
			_box(Vector3(w + 2.0, 0.1, 0.12), Vector3(0.0, roof_y - 0.05, d * 0.5 + 1.1), red)
		return

	# 민가
	if not tile:
		# 초가 지붕 두께: 처마 가장자리를 둘러 짚이 두툼해 보이게
		var wr := w * 0.5 + 0.9
		var dr := d * 0.5 + 0.9
		var th := _mat(Color(0.5, 0.4, 0.22), 1.0)
		_box(Vector3(wr * 2.0, 0.4, 0.3), Vector3(0.0, roof_y - 0.12, dr), th)
		_box(Vector3(wr * 2.0, 0.4, 0.3), Vector3(0.0, roof_y - 0.12, -dr), th)
		_box(Vector3(0.3, 0.4, dr * 2.0), Vector3(wr, roof_y - 0.12, 0.0), th)
		_box(Vector3(0.3, 0.4, dr * 2.0), Vector3(-wr, roof_y - 0.12, 0.0), th)
		# 용마름: 지붕 마루 위에 덮은 짚
		_box(Vector3(w * 0.7, 0.2, 0.5), Vector3(0.0, roof_y + 2.15, 0.0), th)

	# 굴뚝: 집 뒤쪽에 따로 세운 낮은 굴뚝
	_add_smoke(Vector3(w * 0.5 - 0.6, 1.7, -d * 0.5 - 0.9))
	_box(Vector3(0.55, 1.5, 0.55), Vector3(w * 0.5 - 0.6, 0.75, -d * 0.5 - 0.9), clay)
	_box(Vector3(0.75, 0.15, 0.75), Vector3(w * 0.5 - 0.6, 1.58, -d * 0.5 - 0.9), clay)

	# 장독대: 집 옆에 독 두 개 (기와집은 세 개)
	var jar_mat := _mat(Color(0.28, 0.18, 0.12), 0.55)
	var n_jar := 3 if tile else 2
	for k in range(n_jar):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.28
		cm.height = 0.6 + 0.1 * (k % 2)
		cm.radial_segments = 10
		cm.rings = 1
		var jm := MeshInstance3D.new()
		jm.mesh = cm
		jm.material_override = jar_mat
		jm.position = Vector3(-w * 0.5 - 0.5 - 0.5 * (k % 2), cm.height * 0.5, -d * 0.5 + 0.4 + 0.6 * k)
		jm.visibility_range_end = 70.0
		add_child(jm)


## 밤이 되면 창호지 안쪽에서 등불이 비치는 효과 (DayNight가 매 프레임 호출)
static func set_night(n: float) -> void:
	if _lattice == null:
		return
	_lattice.set_shader_parameter("glow", lerpf(0.18, 1.0, n))
	_lattice.set_shader_parameter("paper_color", Color(0.9, 0.86, 0.74).lerp(Color(1.0, 0.78, 0.45), n))


static var _smoke_mat: StandardMaterial3D
static var _smoke_mesh: QuadMesh


## 굴뚝 연기: 저녁부터 밤까지 가늘게 피어오른다 (설계값)
func _add_smoke(pos: Vector3) -> void:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_color = Color(0.75, 0.75, 0.78, 0.35)
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(0.7, 0.7)
		_smoke_mesh.material = _smoke_mat
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.15, 1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.1, 0.0, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.color = Color(1, 1, 1, 0.6)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	var ps := GPUParticles3D.new()
	ps.amount = 6
	ps.lifetime = 5.0
	ps.process_material = pm
	ps.draw_pass_1 = _smoke_mesh
	ps.position = pos
	ps.visibility_range_end = 60.0
	ps.local_coords = false
	add_child(ps)
