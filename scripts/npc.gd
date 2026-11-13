class_name Npc
extends Node3D
## 대화할 수 있는 인물. 데이터는 Act1Data.NPCS 항목이다.

var data: Dictionary
var _person: Person


func setup(d: Dictionary) -> void:
	data = d
	position = d["pos"]


func _ready() -> void:
	add_to_group("npc")

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	body.add_child(cs)
	add_child(body)

	# 사람 모델: 석공은 돌을 쪼는 동작, 궁녀는 서 있는 모습
	var is_mason: bool = str(data["id"]).begins_with("mason")
	var kind: int = Person.Kind.MASON if is_mason else Person.Kind.MAID
	var act: int = Person.Act.HAMMER if is_mason else Person.Act.IDLE
	_person = Person.new().setup(kind, act, Vector3.ZERO, 0.0, 1 if is_mason else 0)
	add_child(_person)

	var label := Label3D.new()
	label.text = str(data["name"])
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.1, 0.0)
	label.font_size = 48
	label.pixel_size = 0.005
	label.outline_size = 12
	add_child(label)


## 가까이 온 사람 쪽으로 천천히 몸을 돌린다.
func _process(delta: float) -> void:
	if _person == null or _person.prostrate:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to := cam.global_position - global_position
	if to.length() > 9.0 or to.length() < 0.1:
		return
	_person.rotation.y = lerp_angle(_person.rotation.y, atan2(to.x, to.z), minf(delta * 3.0, 1.0))
