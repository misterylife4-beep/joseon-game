class_name Weather
extends Node3D
## 비와 눈. 며칠에 한 번 오후에 내리고, 겨울(기온값 0.55 초과)에는 눈이 온다.
## 조선 초 실제 날씨는 알 수 없고 연출용이다(사료 없음). 첫날은 항상 맑다.

var _rain: GPUParticles3D
var _snow: GPUParticles3D


func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.88, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.6)
	q.material = m
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16.0, 0.2, 16.0)
	pm.direction = Vector3(0.1, -1.0, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3.ZERO
	_rain = GPUParticles3D.new()
	_rain.process_material = pm
	_rain.draw_pass_1 = q
	_rain.amount = 1400
	_rain.lifetime = 1.0
	_rain.local_coords = false
	_rain.emitting = false
	_rain.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	add_child(_rain)

	# 눈: 느리게 흔들리며 내려온다
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sq := QuadMesh.new()
	sq.size = Vector2(0.07, 0.07)
	sq.material = sm
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spm.emission_box_extents = Vector3(16.0, 0.2, 16.0)
	spm.direction = Vector3(0.1, -1.0, 0.0)
	spm.spread = 25.0
	spm.initial_velocity_min = 1.2
	spm.initial_velocity_max = 2.2
	spm.gravity = Vector3.ZERO
	spm.turbulence_enabled = true
	spm.turbulence_noise_strength = 0.8
	_snow = GPUParticles3D.new()
	_snow.process_material = spm
	_snow.draw_pass_1 = sq
	_snow.amount = 1200
	_snow.lifetime = 8.0
	_snow.local_coords = false
	_snow.emitting = false
	_snow.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	add_child(_snow)


func _target(day: int, hour: float) -> float:
	if day < 2:
		return 0.0
	# 겨울에는 눈이 더 자주 온다
	var every := 3 if Season.cold > 0.55 else 4
	if hash(day * 7919 + 13) % every != 0:
		return 0.0
	var start := 11.0 + float(hash(day) % 5)
	if hour >= start and hour < start + 4.0:
		return 1.0
	return 0.0


func _process(delta: float) -> void:
	var tg := _target(DayNight.day_now, DayNight.hour_now)
	DayNight.rain_amount = move_toward(DayNight.rain_amount, tg, delta * 0.08)
	var snowing := Season.cold > 0.55
	_rain.emitting = DayNight.rain_amount > 0.05 and not snowing
	_rain.amount_ratio = clampf(DayNight.rain_amount, 0.05, 1.0)
	_snow.emitting = DayNight.rain_amount > 0.05 and snowing
	_snow.amount_ratio = clampf(DayNight.rain_amount, 0.05, 1.0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rain.global_position = cam.global_position + Vector3(0.0, 12.0, 0.0)
		_snow.global_position = cam.global_position + Vector3(0.0, 10.0, 0.0)
