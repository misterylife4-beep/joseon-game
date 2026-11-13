class_name CookRig
extends Node3D
## 모닥불에서 음식이 익는 모습. 조리 방식에 따라 모양이 다르다.
##   pot    세 발 걸이에 솥을 걸어 곡식·콩을 끓인다 (끓는 거품, 김, 보글보글 소리)
##   roast  불가 잿불에 밤·도토리를 묻어 굽는다 (색이 짙어지고 이따금 탁 튀며 팝 소리)
##   skewer 두 갈래 받침 위 꼬치에 칡뿌리를 꿰어 돌려 가며 굽는다 (지글거림)
## 익는 정도(progress)에 따라 색이 날것에서 익은 색으로 변한다. 세발솥·꼬치 구이는 일반적 모양이며 크기와 색은 설계값이다.

var id := ""
var count := 1
var style := "pot"
var progress := 0.0
var paused := false

var _t := 0.0
var _done := false
var _raw := Color.WHITE
var _cooked := Color.WHITE
var _food_mats: Array[StandardMaterial3D] = []
var _food: Array[MeshInstance3D] = []
var _bubbles: Array[MeshInstance3D] = []
var _surface: MeshInstance3D
var _skewer: Node3D
var _steam: CPUParticles3D
var _loop: AudioStreamPlayer3D
var _pop_cd := 1.5
var _rng := RandomNumberGenerator.new()


func setup(item_id: String, n: int) -> void:
	id = item_id
	count = n
	style = Items.cook_style(id)
	_raw = Items.def(id)["col"]
	match style:
		"roast":
			_cooked = Color(0.16, 0.09, 0.05)
		"skewer":
			_cooked = Color(0.40, 0.24, 0.12)
		_:
			_cooked = Color(0.93, 0.88, 0.70).lerp(_raw, 0.25)


func _ready() -> void:
	_rng.randomize()
	match style:
		"roast":
			_build_roast()
		"skewer":
			_build_skewer()
		_:
			_build_pot()
	_steam = _make_steam(Vector3(0.0, 1.05 if style == "pot" else 0.7, 0.0), 14 if style == "pot" else 6, 2.2, 0.45, 0.4)
	add_child(_steam)
	_loop = AudioStreamPlayer3D.new()
	_loop.stream = UiSfx.stream("bubble" if style == "pot" else "sizzle")
	_loop.unit_size = 5.0
	_loop.max_distance = 45.0
	_loop.volume_db = -20.0
	add_child(_loop)
	_loop.play()
	_apply()


# --- 모양 ---

func _mat(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _part(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


## 두 점을 잇는 가는 막대
func _rod(a: Vector3, b: Vector3, radius: float, col: Color, parent: Node3D = null) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 6
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _mat(col)
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5)
	(parent if parent != null else self).add_child(mi)


func _build_pot() -> void:
	var wood := Color(0.34, 0.24, 0.14)
	var apex := Vector3(0.0, 1.55, 0.0)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		_rod(Vector3(cos(a) * 0.85, 0.0, sin(a) * 0.85), apex, 0.028, wood)
	_rod(Vector3(0.0, 1.0, 0.0), apex, 0.012, Color(0.2, 0.2, 0.2))
	var iron := _mat(Color(0.10, 0.10, 0.11), 0.55, 0.6)
	var body := CylinderMesh.new()
	body.top_radius = 0.27
	body.bottom_radius = 0.2
	body.height = 0.3
	body.radial_segments = 14
	body.rings = 1
	_part(body, iron, Vector3(0.0, 0.8, 0.0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.255
	rim.outer_radius = 0.29
	rim.rings = 14
	rim.ring_segments = 5
	_part(rim, iron, Vector3(0.0, 0.95, 0.0))
	var sm := _mat(_raw, 0.5)
	_food_mats.append(sm)
	var surf := CylinderMesh.new()
	surf.top_radius = 0.25
	surf.bottom_radius = 0.25
	surf.height = 0.02
	surf.radial_segments = 14
	surf.rings = 1
	_surface = _part(surf, sm, Vector3(0.0, 0.93, 0.0))
	var bm := _mat(Color(1.0, 1.0, 0.95, 1.0), 0.3)
	for i in 6:
		var sp := SphereMesh.new()
		sp.radius = 0.03
		sp.height = 0.05
		sp.radial_segments = 6
		sp.rings = 3
		var a2 := _rng.randf() * TAU
		var r := _rng.randf() * 0.19
		_bubbles.append(_part(sp, bm, Vector3(cos(a2) * r, 0.945, sin(a2) * r)))


func _build_roast() -> void:
	var n := mini(count, 5)
	for i in n:
		var a := TAU * float(i) / float(n) + 0.3
		var sp := SphereMesh.new()
		sp.radius = 0.06
		sp.height = 0.11 if id == "bam" else 0.14
		sp.radial_segments = 8
		sp.rings = 4
		var m := _mat(_raw, 0.6)
		_food_mats.append(m)
		_food.append(_part(sp, m, Vector3(cos(a) * 0.42, 0.08, sin(a) * 0.42)))


func _build_skewer() -> void:
	var wood := Color(0.34, 0.24, 0.14)
	for sx in [-0.66, 0.66]:
		var x: float = sx
		_rod(Vector3(x, 0.0, 0.0), Vector3(x, 0.78, 0.0), 0.022, wood)
		_rod(Vector3(x, 0.7, 0.0), Vector3(x * 0.8, 0.9, 0.12), 0.015, wood)
		_rod(Vector3(x, 0.7, 0.0), Vector3(x * 0.8, 0.9, -0.12), 0.015, wood)
	_skewer = Node3D.new()
	_skewer.position = Vector3(0.0, 0.72, 0.0)
	add_child(_skewer)
	_rod(Vector3(-0.72, 0.0, 0.0), Vector3(0.72, 0.0, 0.0), 0.014, Color(0.5, 0.4, 0.26), _skewer)
	var n := mini(count, 3)
	for i in n:
		var cp := CapsuleMesh.new()
		cp.radius = 0.055
		cp.height = 0.24
		cp.radial_segments = 8
		cp.rings = 3
		var m := _mat(_raw, 0.9)
		_food_mats.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = cp
		mi.material_override = m
		mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
		mi.position = Vector3((float(i) - float(n - 1) * 0.5) * 0.34, 0.07, 0.0)
		_skewer.add_child(mi)
		_food.append(mi)


func _make_steam(pos: Vector3, amount: int, life: float, size: float, rise: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = rise * 0.6
	p.initial_velocity_max = rise
	p.gravity = Vector3(0.0, 0.1, 0.0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.25, Color(1, 1, 1, 0.38))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FireFx._blob()
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# --- 진행 ---

## 김의 세기(0~1): 약하면 끄고, 세면 크고 많이 오른다.
func _set_steam(level: float) -> void:
	if _steam == null:
		return
	_steam.emitting = level > 0.12
	_steam.scale_amount_min = 0.3 * (0.5 + level)
	_steam.scale_amount_max = 0.5 * (0.5 + level)


func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	_apply()


func set_paused(on: bool) -> void:
	paused = on


func _apply() -> void:
	var c := _raw.lerp(_cooked, smoothstep(0.1, 0.95, progress))
	for m in _food_mats:
		m.albedo_color = c
	if _steam != null:
		_set_steam(clampf(0.25 + progress * 0.75, 0.1, 1.0))


## 다 익었다: 김이 확 오르고 맑은 종소리가 난 뒤 잠시 뒤 치워진다.
func finish() -> void:
	if _done:
		return
	_done = true
	progress = 1.0
	_apply()
	if _loop != null:
		_loop.stop()
	var bell := AudioStreamPlayer3D.new()
	bell.stream = UiSfx.stream("done")
	bell.unit_size = 8.0
	bell.volume_db = 0.0
	add_child(bell)
	bell.play()
	if _steam != null:
		_set_steam(1.0)
		_steam.initial_velocity_max = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(queue_free)


func cancel() -> void:
	queue_free()


func _process(delta: float) -> void:
	if _done:
		return
	if paused:
		if _loop != null:
			_loop.volume_db = lerpf(_loop.volume_db, -40.0, clampf(delta * 4.0, 0.0, 1.0))
		if _steam != null:
			_set_steam(0.1)
		return
	_t += delta
	if _loop != null:
		_loop.volume_db = lerpf(_loop.volume_db, lerpf(-22.0, -7.0, minf(progress * 2.0, 1.0)), clampf(delta * 4.0, 0.0, 1.0))
	if _steam != null:
		_set_steam(clampf(0.25 + progress * 0.75, 0.1, 1.0))
	match style:
		"pot":
			var k := 0.3 + 0.9 * progress
			for i in _bubbles.size():
				var s := 0.55 + 0.45 * sin(_t * (6.0 + float(i)) + float(i) * 1.7)
				_bubbles[i].scale = Vector3.ONE * maxf(s * k, 0.05)
				_bubbles[i].visible = progress > 0.12 or i < 2
			if _surface != null:
				_surface.position.y = 0.93 + 0.006 * sin(_t * 9.0) * k
		"skewer":
			if _skewer != null:
				_skewer.rotation.x += delta * 0.9
		_:
			_pop_cd -= delta
			if _pop_cd <= 0.0 and progress > 0.3 and not _food.is_empty():
				_pop_cd = _rng.randf_range(1.2, 2.8)
				_pop(_rng.randi() % _food.size())


## 밤 한 알이 탁 튀어 올랐다 떨어진다
func _pop(i: int) -> void:
	var mi := _food[i]
	var y0 := mi.position.y
	var snd := AudioStreamPlayer3D.new()
	snd.stream = UiSfx.stream("pop")
	snd.unit_size = 5.0
	snd.volume_db = -3.0
	snd.pitch_scale = _rng.randf_range(0.85, 1.2)
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	var tw := create_tween()
	tw.tween_property(mi, "position:y", y0 + 0.32, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position:y", y0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
