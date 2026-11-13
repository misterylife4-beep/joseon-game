class_name Fireflies
extends GPUParticles3D
## 반딧불: 여름밤(음력 5~7월)에만 카메라 주변에서 떠다닌다. 월 범위는 설계값이다.

func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.8, 1.0, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.7, 1.0, 0.25)
	m.emission_energy_multiplier = 3.0
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	q.material = m
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 1.2, 14)
	pm.direction = Vector3(0, 0.2, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	process_material = pm
	draw_pass_1 = q
	amount = 40
	lifetime = 6.0
	local_coords = false
	emitting = false


func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		global_position = Vector3(p.x, HanyangMap.height_no_carve(p.x, p.z) + 1.2, p.z)
	emitting = DayNight.night_amount > 0.6 and Season.firefly() > 0.1
