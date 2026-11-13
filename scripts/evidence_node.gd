class_name EvidenceNode
extends Node3D
## 월드에 놓인 증거. 플레이어가 가까이 가서 E를 누르면 수집한다.

var data: Dictionary

var _base_y := 0.0
var _t := 0.0


func setup(entry: Dictionary, pos: Vector3) -> void:
	data = entry
	position = pos
	_base_y = pos.y


func _ready() -> void:
	add_to_group("evidence")

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.25)
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.2
	light.omni_range = 6.0
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 2.0) * 0.12
