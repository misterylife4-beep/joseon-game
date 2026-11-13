class_name HanyangSite
extends Node3D
## 1막 경복궁 터. 정전 기둥이 서 있고 날이 지날수록 궁성이 올라간다.
## 궁성 크기는 설계값이다. 남문(광화문)과 북문 자리는 비워 둔다.
## 이 노드는 add_child 하기 전에 position(경복궁 터 중심, 높이는 평탄한 지면)을 정해야 한다.

const HALF_X := 34.0
const HALF_Z := 22.0
const SEG_LEN := 6.0
const WALL_H := 6.0
const WALL_T := 2.0
const GATE_HALF := 10.0

var _wall_segments: Array[StaticBody3D] = []
## 진행도에 따라 하나씩 올라가는 전각 (진행도, 노드)
var _stages: Array = []


func _ready() -> void:
	_build_platform()
	_build_pillars()
	_build_walls()
	_build_halls()
	set_progress(0.0)


## p: 0.0 ~ 1.0
func set_progress(p: float) -> void:
	var count := int(floorf(clampf(p, 0.0, 1.0) * _wall_segments.size()))
	for i in _wall_segments.size():
		var seg := _wall_segments[i]
		var on := i < count
		seg.visible = on
		seg.collision_layer = 1 if on else 0
	for st in _stages:
		(st[1] as Node3D).visible = p >= float(st[0])


## 경복궁 전각. 1395년 준공 당시의 구성(연침, 편전, 전문, 행랑, 각루)을 압축해 세운다.
## 사료: 정전, 연침, 보평청, 전문, 행랑, 각루 등이 지어졌다(docs/고증_근거.md 11장). 칸 수는 압축한 설계값이다.
## 1막 연출에서는 성벽과 함께 올라가지만 실제로는 궁궐이 먼저 끝났다(1395-09 준공, 성벽은 1396).
func _build_halls() -> void:
	# [진행도, 칸x, 칸z, 위치(x,z), yaw, 높이]
	var specs: Array = [
		[0.30, 3, 2, Vector2(-14.0, -19.0), 0.0, 0.0],
		[0.30, 3, 2, Vector2(0.0, -19.0), 0.0, 0.0],
		[0.30, 3, 2, Vector2(14.0, -19.0), 0.0, 0.0],
		[0.55, 3, 2, Vector2(0.0, -12.5), 0.0, 0.0],
		[0.75, 7, 1, Vector2(-29.0, 2.0), PI * 0.5, 0.0],
		[0.75, 7, 1, Vector2(29.0, 2.0), -PI * 0.5, 0.0],
		[0.90, 3, 1, Vector2(0.0, 17.0), 0.0, 0.0],
		[1.00, 1, 1, Vector2(-30.0, -19.0), 0.0, WALL_H],
		[1.00, 1, 1, Vector2(30.0, -19.0), 0.0, WALL_H],
	]
	for sp in specs:
		var pos2: Vector2 = sp[3]
		var hk := Hanok.new()
		var gx := position.x + pos2.x
		var gz := position.z + pos2.y
		var local_y := HanyangMap.height(gx, gz) - position.y
		var raised := float(sp[5]) > 0.0
		if not raised:
			local_y = maxf(local_y, 0.6) if absf(pos2.x) < 20.0 and absf(pos2.y) < 14.0 else local_y
		hk.setup(Hanok.Style.TILE, int(sp[1]), int(sp[2]), Vector3(pos2.x, local_y + float(sp[5]), pos2.y), float(sp[4]), true)
		hk.visible = false
		add_child(hk)
		_stages.append([float(sp[0]), hk])


func _build_platform() -> void:
	var body := _box(Vector3(40, 0.6, 28), Vector3(0, 0.3, 0), 0.0, Color(0.55, 0.5, 0.42))
	add_child(body)


func _build_pillars() -> void:
	# 경복궁 정전이 올라갈 자리의 기둥들
	for ix in 4:
		for iz in 3:
			var pos := Vector3(-12.0 + ix * 8.0, 4.1, -8.0 + iz * 8.0)
			var body := StaticBody3D.new()
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 7.0
			mi.mesh = cyl
			mi.material_override = _flat(Color(0.6, 0.18, 0.12))
			body.add_child(mi)
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 0.5
			shape.height = 7.0
			cs.shape = shape
			body.add_child(cs)
			body.position = pos
			add_child(body)


func _build_walls() -> void:
	var stone := Color(0.62, 0.6, 0.56)
	# 남쪽 변
	for x in _span(-HALF_X, HALF_X):
		if absf(x) > GATE_HALF:
			_add_wall(Vector3(x, WALL_H * 0.5, HALF_Z), 0.0, stone)
	# 동쪽 변
	for z in _span(HALF_Z, -HALF_Z):
		_add_wall(Vector3(HALF_X, WALL_H * 0.5, z), PI * 0.5, stone)
	# 북쪽 변
	for x in _span(HALF_X, -HALF_X):
		if absf(x) > GATE_HALF:
			_add_wall(Vector3(x, WALL_H * 0.5, -HALF_Z), 0.0, stone)
	# 서쪽 변
	for z in _span(-HALF_Z, HALF_Z):
		_add_wall(Vector3(-HALF_X, WALL_H * 0.5, z), PI * 0.5, stone)


func _span(from: float, to: float) -> Array[float]:
	var out: Array[float] = []
	var dir := 1.0 if to > from else -1.0
	var cur := from + dir * SEG_LEN * 0.5
	while (to - cur) * dir > 0.0:
		out.append(cur)
		cur += dir * SEG_LEN
	return out


func _add_wall(pos: Vector3, rot_y: float, color: Color) -> void:
	# 지형을 따라 높이를 맞추고 1m 묻는다
	var ground := HanyangMap.height(position.x + pos.x, position.z + pos.z) - position.y
	var body := _box(
		Vector3(SEG_LEN, WALL_H + 1.0, WALL_T),
		Vector3(pos.x, ground + (WALL_H - 1.0) * 0.5, pos.z),
		rot_y,
		color
	)
	add_child(body)
	_wall_segments.append(body)


func _box(size: Vector3, pos: Vector3, rot_y: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _flat(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation.y = rot_y
	return body


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m
