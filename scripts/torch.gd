class_name Torch
extends Node3D
## 횃불(POST)과 등롱(LANTERN). 밤에만 불이 켜지고 불꽃 세기가 흔들린다.
## 횃불은 이야기 속에도 나온다(연이의 증언). 놓는 자리와 불빛 세기·범위는 설계값이다.

enum Style { POST, LANTERN }

var style: int = Style.POST
var power := 2.2
var light_range := 16.0

var _light: OmniLight3D
var _flame: MeshInstance3D
var _t := randf() * 100.0

static var _wood: StandardMaterial3D
static var _fire: StandardMaterial3D
static var _paper: StandardMaterial3D


func _ready() -> void:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.25, 0.17, 0.1)
		_wood.roughness = 1.0
		_fire = StandardMaterial3D.new()
		_fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fire.albedo_color = Color(1.0, 0.6, 0.2)
		_fire.emission_enabled = true
		_fire.emission = Color(1.0, 0.5, 0.1)
		_fire.emission_energy_multiplier = 3.0
		_paper = StandardMaterial3D.new()
		_paper.albedo_color = Color(0.9, 0.78, 0.5)
		_paper.emission_enabled = true
		_paper.emission = Color(1.0, 0.65, 0.25)
		_paper.emission_energy_multiplier = 1.2

	var top_y := 2.1
	if style == Style.POST:
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.07
		cm.height = 2.0
		cm.radial_segments = 6
		cm.rings = 1
		pole.mesh = cm
		pole.material_override = _wood
		pole.position.y = 1.0
		pole.visibility_range_end = 110.0
		add_child(pole)
		# 기둥 끝에 감은 불쏘시개
		var wrap := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.09
		wm.bottom_radius = 0.06
		wm.height = 0.25
		wm.radial_segments = 6
		wm.rings = 1
		wrap.mesh = wm
		wrap.material_override = _wood
		wrap.position.y = 2.0
		wrap.visibility_range_end = 110.0
		add_child(wrap)
	else:
		top_y = 0.0
		var body := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.11
		bm.bottom_radius = 0.09
		bm.height = 0.26
		bm.radial_segments = 8
		bm.rings = 1
		body.mesh = bm
		body.material_override = _paper
		body.visibility_range_end = 110.0
		add_child(body)

	_flame = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1 if style == Style.POST else 0.05
	sm.height = sm.radius * 2.8
	sm.radial_segments = 8
	sm.rings = 4
	_flame.mesh = sm
	_flame.material_override = _fire
	_flame.position.y = top_y + 0.12
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.visibility_range_end = 110.0
	add_child(_flame)

	_light = OmniLight3D.new()
	_light.position.y = top_y + 0.15
	_light.omni_range = light_range
	_light.omni_attenuation = 1.4
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 80.0
	_light.distance_fade_length = 25.0
	add_child(_light)
	_apply(0.0)


func _process(delta: float) -> void:
	_t += delta
	_apply(delta)


func _apply(_delta: float) -> void:
	var n := DayNight.night_amount
	var on := n > 0.05
	_flame.visible = on
	_light.visible = on
	if not on:
		return
	var fl := 0.88 + 0.12 * sin(_t * 13.0) + 0.06 * sin(_t * 29.0 + 1.3)
	_light.light_energy = power * n * fl
	_flame.scale = Vector3(1.0, 0.9 + 0.2 * fl, 1.0)
