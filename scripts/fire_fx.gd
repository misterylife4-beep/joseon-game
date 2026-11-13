class_name FireFx
extends Node3D
## 모닥불. 불은 공이 아니라 위로 솟으며 흔들리고 식어 가는 여러 불꽃 덩어리다.
## 불꽃(노랑→주황→붉은색으로 식으며 작아짐), 위로 튀는 불티, 올라가며 퍼지는 연기, 숯처럼 빛나는 장작, 깜빡이는 빛으로 만든다.
## 색·크기·개수는 모두 설계값이다. 불꽃 색이 아래는 밝은 노랑, 위로 갈수록 주황과 붉은색이 되는 것은 실제 불의 모습을 따랐다.

var _flame: GPUParticles3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _embers: Array[MeshInstance3D] = []
var _ember_mat: StandardMaterial3D
var _t := randf() * 50.0
var _burn := 1.0

static var _blob_tex: GradientTexture2D


static func _blob() -> GradientTexture2D:
	if _blob_tex != null:
		return _blob_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_blob_tex = GradientTexture2D.new()
	_blob_tex.gradient = g
	_blob_tex.fill = GradientTexture2D.FILL_RADIAL
	_blob_tex.fill_from = Vector2(0.5, 0.5)
	_blob_tex.fill_to = Vector2(1.0, 0.5)
	_blob_tex.width = 64
	_blob_tex.height = 64
	return _blob_tex


func _ready() -> void:
	_build_base()
	_flame = _make_particles(40, 0.9, Vector2(0.55, 0.8), true)
	_flame.process_material = _flame_material()
	_flame.position = Vector3(0.0, 0.25, 0.0)
	_flame.draw_pass_1 = _quad(Vector2(0.5, 0.75), true, 1.0)
	add_child(_flame)

	_sparks = _make_particles(14, 1.6, Vector2(0.05, 0.05), false)
	_sparks.process_material = _spark_material()
	_sparks.position = Vector3(0.0, 0.45, 0.0)
	_sparks.draw_pass_1 = _quad(Vector2(0.05, 0.05), true, 1.0)
	_sparks.local_coords = false
	add_child(_sparks)

	_smoke = _make_particles(18, 4.5, Vector2(0.9, 0.9), false)
	_smoke.process_material = _smoke_material()
	_smoke.position = Vector3(0.0, 1.1, 0.0)
	_smoke.draw_pass_1 = _quad(Vector2(0.9, 0.9), false, 0.35)
	_smoke.local_coords = false
	add_child(_smoke)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.58, 0.28)
	_light.omni_range = 14.0
	_light.light_energy = 2.2
	_light.position = Vector3(0.0, 0.9, 0.0)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var flick := 0.82 + 0.12 * sin(_t * 11.0) + 0.06 * sin(_t * 27.0 + 1.3) + 0.04 * sin(_t * 5.0)
	_light.light_energy = 2.4 * flick * _burn
	_light.light_color = Color(1.0, 0.55 + 0.06 * sin(_t * 7.0), 0.26)
	_ember_mat.emission_energy_multiplier = (1.2 + 0.8 * sin(_t * 2.3) + 0.4 * sin(_t * 6.1)) * _burn


## 0이면 꺼지고 1이면 한창 타는 불. 불꽃·불티·연기가 불이 약해질수록 줄어든다.
func set_burn(level: float) -> void:
	_burn = clampf(level, 0.0, 1.0)
	if _flame == null:
		return
	_flame.amount_ratio = clampf(_burn * 1.1, 0.05, 1.0)
	_sparks.amount_ratio = clampf(_burn * 1.2 - 0.2, 0.02, 1.0)
	_smoke.amount_ratio = clampf(0.4 + _burn * 0.6, 0.05, 1.0)


func _build_base() -> void:
	# 재가 깔린 바닥
	var ash := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.02
	ash.mesh = disc
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.1, 0.09, 0.08)
	ash_mat.roughness = 1.0
	ash.material_override = ash_mat
	ash.position = Vector3(0.0, 0.01, 0.0)
	add_child(ash)

	# 둘레 돌
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.4, 0.38)
	stone.roughness = 1.0
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.2
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.3, 0.2 + 0.05 * float(i % 3), 0.24)
		m.mesh = b
		m.material_override = stone
		m.position = Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62)
		m.rotation.y = -a + 0.3 * float(i % 2)
		add_child(m)

	# 장작: 겉은 검게 그을리고 속은 숯불처럼 붉게 빛난다
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(0.12, 0.07, 0.05)
	_ember_mat.roughness = 1.0
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.32, 0.06)
	_ember_mat.emission_energy_multiplier = 1.5
	for i in 4:
		var l := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.07
		c.bottom_radius = 0.08
		c.height = 0.9
		l.mesh = c
		l.material_override = _ember_mat
		l.position = Vector3(0.0, 0.17, 0.0)
		l.rotation = Vector3(PI * 0.5 - 0.25, float(i) * TAU / 4.0 + 0.4, 0.0)
		add_child(l)
		_embers.append(l)


func _make_particles(amount: int, life: float, aabb_half: Vector2, local: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = local
	p.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 10.0, 8.0))
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.emitting = true
	return p


func _quad(size: Vector2, additive: bool, alpha: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _blob()
	m.albedo_color = Color(1, 1, 1, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.disable_receive_shadows = true
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	q.material = m
	return q


func _ramp(colors: Array[Color], offsets: PackedFloat32Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _shrink(start: float, end: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, start))
	c.add_point(Vector2(1.0, end))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _flame_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.22
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 14.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.1
	m.gravity = Vector3(0.0, 0.9, 0.0)
	m.damping_min = 0.3
	m.damping_max = 0.8
	m.scale_min = 0.7
	m.scale_max = 1.2
	m.scale_curve = _shrink(1.0, 0.1)
	# 밝은 노랑 → 주황 → 붉은색 → 사라짐
	var cols: Array[Color] = [
		Color(1.0, 0.95, 0.6, 0.0),
		Color(1.0, 0.85, 0.35, 0.95),
		Color(1.0, 0.5, 0.12, 0.8),
		Color(0.8, 0.18, 0.05, 0.4),
		Color(0.25, 0.05, 0.02, 0.0),
	]
	m.color_ramp = _ramp(cols, PackedFloat32Array([0.0, 0.12, 0.45, 0.8, 1.0]))
	m.set("turbulence_enabled", true)
	m.set("turbulence_noise_strength", 0.9)
	m.set("turbulence_noise_scale", 2.5)
	return m


func _spark_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 35.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 2.2
	m.gravity = Vector3(0.0, 0.2, 0.0)
	m.scale_min = 0.5
	m.scale_max = 1.3
	var cols: Array[Color] = [
		Color(1.0, 0.9, 0.5, 1.0),
		Color(1.0, 0.5, 0.1, 0.9),
		Color(0.9, 0.2, 0.05, 0.0),
	]
	m.color_ramp = _ramp(cols, PackedFloat32Array([0.0, 0.5, 1.0]))
	m.set("turbulence_enabled", true)
	m.set("turbulence_noise_strength", 1.2)
	m.set("turbulence_noise_scale", 1.5)
	return m


func _smoke_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 12.0
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 0.9
	m.gravity = Vector3(0.15, 0.35, 0.05)
	m.damping_min = 0.1
	m.damping_max = 0.3
	m.scale_min = 0.8
	m.scale_max = 1.3
	m.scale_curve = _shrink(0.5, 2.6)
	var cols: Array[Color] = [
		Color(0.35, 0.33, 0.32, 0.0),
		Color(0.4, 0.38, 0.36, 0.28),
		Color(0.45, 0.45, 0.46, 0.14),
		Color(0.5, 0.5, 0.52, 0.0),
	]
	m.color_ramp = _ramp(cols, PackedFloat32Array([0.0, 0.2, 0.65, 1.0]))
	m.set("turbulence_enabled", true)
	m.set("turbulence_noise_strength", 0.5)
	m.set("turbulence_noise_scale", 3.0)
	return m
