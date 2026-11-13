class_name FinaleAltar
extends Node3D
## 경복궁 터 정전 기둥 사이의 백지본. 증거를 모두 모은 뒤 여기서 1막을 마무리한다.

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	add_to_group("finale")
	_base_y = position.y

	var book := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.12, 0.6)
	book.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.93, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.5
	book.material_override = mat
	add_child(book)

	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.8, 1.0)
	light.light_energy = 1.5
	light.omni_range = 8.0
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 1.5) * 0.08
	rotation.y += delta * 0.5
