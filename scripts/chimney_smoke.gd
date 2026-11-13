class_name ChimneySmoke
extends Node3D
## 민가 굴뚝과 연기. 한옥의 굴뚝은 지붕 위가 아니라 집 뒤편에 낮게 따로 세운 흙·돌 기둥이었다(설계값: 높이 1.3m, 위치는 집 뒤쪽).
## 연기는 온돌을 때는 추운 철, 아침저녁 밥 짓는 때에 더 많이 난다. 양과 속도는 설계값이다.

var _smoke: GPUParticles3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.3, 0.26)
	mat.roughness = 1.0
	var stack := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.28
	c.height = 1.3
	stack.mesh = c
	stack.material_override = mat
	stack.position = Vector3(0.0, 0.65, 0.0)
	add_child(stack)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.08
	cap.mesh = cm
	cap.material_override = mat
	cap.position = Vector3(0.0, 1.32, 0.0)
	add_child(cap)

	_smoke = GPUParticles3D.new()
	_smoke.amount = 14
	_smoke.lifetime = 6.0
	_smoke.local_coords = false
	_smoke.randomness = 0.6
	_smoke.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(10.0, 14.0, 8.0))
	_smoke.position = Vector3(0.0, 1.4, 0.0)
	_smoke.process_material = _material()
	_smoke.draw_pass_1 = _quad()
	_smoke.emitting = true
	add_child(_smoke)


## 0~1: 연기의 양
func set_strength(level: float) -> void:
	if _smoke != null:
		_smoke.amount_ratio = clampf(level, 0.05, 1.0)


func _quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = FireFx._blob()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	q.material = m
	return q


func _material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 8.0
	m.initial_velocity_min = 0.7
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0.28, 0.25, 0.08)
	m.damping_min = 0.15
	m.damping_max = 0.35
	m.scale_min = 0.8
	m.scale_max = 1.2
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.4))
	cv.add_point(Vector2(1.0, 2.8))
	var ct := CurveTexture.new()
	ct.curve = cv
	m.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([
		Color(0.7, 0.7, 0.72, 0.0),
		Color(0.7, 0.7, 0.72, 0.3),
		Color(0.75, 0.76, 0.78, 0.14),
		Color(0.8, 0.8, 0.82, 0.0),
	])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	m.set("turbulence_enabled", true)
	m.set("turbulence_noise_strength", 0.4)
	m.set("turbulence_noise_scale", 3.0)
	return m
