class_name Mokdo
extends Node3D
## 목도: 두 사람이 긴 나무에 돌을 매달아 어깨에 메고 나르는 방식.
## 성돌을 두 사람이 멘다는 점은 전통 운반법으로 알려져 있으나, 1396년 현장의 구체적 모습은 확인하지 못했다.
## 막대 길이, 돌 크기, 속도는 설계값이다(docs/고증_근거.md 18장).

var _front: Person
var _back: Person
var _pole: Node3D


func setup(a: Vector2, b: Vector2) -> Mokdo:
	var d := (b - a).normalized()
	var wood := Hanok.shared_mat(Color(0.4, 0.3, 0.2), 0.95)
	var stone := Hanok.shared_mat(Color(0.56, 0.54, 0.5), 0.95)
	_front = Person.new().setup(Person.Kind.PORTER, Person.Act.WALK, _ground(a + d * 0.95), atan2(d.x, d.y), 0)
	_back = Person.new().setup(Person.Kind.PORTER, Person.Act.WALK, _ground(a - d * 0.95), atan2(d.x, d.y), 1)
	for pr in [_front, _back]:
		var q: Person = pr
		q.speed = 0.7
	_front.route_a = a + d * 0.95
	_front.route_b = b + d * 0.95
	_back.route_a = a - d * 0.95
	_back.route_b = b - d * 0.95
	_front.scheduled = true
	_back.scheduled = true
	add_child(_front)
	add_child(_back)
	_pole = Node3D.new()
	var bm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.09, 2.9)
	bm.mesh = box
	bm.material_override = wood
	_pole.add_child(bm)
	var sm := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.55, 0.4, 0.5)
	sm.mesh = sb
	sm.material_override = stone
	sm.position = Vector3(0.0, -0.45, 0.0)
	_pole.add_child(sm)
	add_child(_pole)
	return self


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, HanyangMap.height_no_carve(p.x, p.y), p.y)


func _process(_delta: float) -> void:
	_pole.visible = _front.visible
	if not _pole.visible:
		return
	var mid := (_front.position + _back.position) * 0.5
	_pole.position = mid + Vector3(0.0, 1.3, 0.0)
	var dir := _front.position - _back.position
	if dir.length() > 0.2:
		_pole.rotation.y = atan2(dir.x, dir.z)
