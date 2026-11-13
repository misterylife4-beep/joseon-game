class_name PalaceCrew
extends Node3D
## 경복궁 터의 사람들. 공사 중에는 목수·화공·석수·달구질꾼·짐꾼·군사·관원·아이·밥 나르는 여인이 일하고,
## 1막을 마쳐 궁궐이 완공되면 일꾼은 물러가고 궁녀·관원·사관·수문 군사가 궁을 지킨다.
## 사료: 경복궁은 1395년 9월 준공, 건축은 도편수 아래 목수·석수·화공 등 장인과 부역 인부, 감독 관원이 맡았다.
## 인원 구성·배치·동작은 설계값이다(docs/고증_근거.md 30장). 월대(기단) 높이 0.6 m는 PalaceSite 와 같다.

const DECK := 0.6

var _site: PalaceSite
var _work: Node3D
var _staff: Node3D
var _guards: Node3D
var _rammers: Array[Node3D] = []
var _rammer_y := 0.0


func setup(site: PalaceSite) -> void:
	_site = site


func _ready() -> void:
	_work = Node3D.new()
	add_child(_work)
	_staff = Node3D.new()
	_staff.visible = false
	add_child(_staff)
	_guards = Node3D.new()
	add_child(_guards)
	_build_work()
	_build_staff()
	_build_guards()
	set_complete(_site.is_complete())
	for n in find_children("*", "Person", true, false):
		var pp := n as Person
		if pp.kind != Person.Kind.SOLDIER:
			pp.scheduled = true


func set_complete(done: bool) -> void:
	_work.visible = not done
	_staff.visible = done
	WalkGuard.set_collide(_work, not done)
	WalkGuard.set_collide(_staff, done)


# --- 좌표 도우미 (터 중심 기준 지역 좌표 → 월드) ---

func _w(lx: float, lz: float) -> Vector2:
	return Vector2(_site.position.x + lx, _site.position.z + lz)


func _deck_pos(lx: float, lz: float) -> Vector3:
	var w := _w(lx, lz)
	return Vector3(w.x, _site.position.y + DECK, w.y)


func _ground_pos(lx: float, lz: float) -> Vector3:
	var w := _w(lx, lz)
	return Vector3(w.x, HanyangMap.stand(w.x, w.y, true), w.y)


func _person(parent: Node3D, kind: int, act: int, pos: Vector3, yaw: float, v := -1) -> Person:
	var p := Person.new().setup(kind, act, pos, yaw, v)
	parent.add_child(p)
	return p


func _face(dx: float, dz: float) -> float:
	return atan2(dx, dz)


# --- 공사 중 ---

func _build_work() -> void:
	var wood := Hanok.shared_mat(Color(0.5, 0.38, 0.24), 0.95)
	var stone := Hanok.shared_mat(Color(0.62, 0.6, 0.56), 0.95)
	var paint := Hanok.shared_mat(Color(0.2, 0.42, 0.38), 0.9)

	# 목수 넷: 기둥 사이에서 들보감을 대패질한다. 앞에 받침 위 통나무를 둔다.
	var carp_spots: Array = [Vector2(-8.0, -4.0), Vector2(8.0, -4.0), Vector2(-8.0, 4.0), Vector2(8.0, 4.0)]
	for i in carp_spots.size():
		var cs: Vector2 = carp_spots[i]
		var yaw := PI * 0.5 if cs.x < 0.0 else -PI * 0.5
		var p := _person(_work, Person.Kind.WORKER, Person.Act.PLANE, _deck_pos(cs.x, cs.y), yaw, (i + 1) % 4)
		p.lift = DECK
		var fx := 1.0 if cs.x < 0.0 else -1.0
		var bp := _deck_pos(cs.x + fx * 1.85, cs.y)
		_prop_box(_work, bp + Vector3(0.0, 0.62, 0.0), Vector3(3.0, 0.3, 0.3), wood, 0.0)

	# 화공 둘: 북쪽 전각 앞에서 단청 밑그림을 그린다.
	for sx in [-1.5, 1.5]:
		var px: float = sx
		var painter := _person(_work, Person.Kind.WORKER, Person.Act.DRAW, _deck_pos(px, -8.2), PI, 2)
		painter.lift = DECK
		_prop_box(_work, _deck_pos(px, -7.2) + Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.7, 0.5), paint, 0.0)

	# 도편수와 부편수: 설계도(화본)를 놓고 이야기한다.
	var chief := _person(_work, Person.Kind.OFFICIAL, Person.Act.TALK, _deck_pos(-1.2, -5.2), PI * 0.5, 1)
	var chief2 := _person(_work, Person.Kind.OFFICIAL, Person.Act.TALK, _deck_pos(1.2, -5.2), -PI * 0.5, 3)
	chief.lift = DECK
	chief2.lift = DECK

	# 석수 셋: 서쪽 마당에서 월대 돌을 쪼는다.
	for i in 3:
		var mz := -6.0 + 3.0 * float(i)
		_person(_work, Person.Kind.MASON, Person.Act.HAMMER, _ground_pos(-23.0, mz), -PI * 0.5, i + 1)
		_prop_box(_work, _ground_pos(-24.4, mz) + Vector3(0.0, 0.35, 0.0), Vector3(1.1, 0.7, 1.0), stone, 0.2 * float(i))
	# 다듬은 돌 더미와 목재 더미
	WallWorks._stone_pile(_work, _w(-24.2, 16.5))
	WallWorks._log_pile(_work, _w(23.5, -9.5))

	# 달구질꾼 넷: 동쪽에서 기단 흙을 다진다.
	_tamp_group(_w(24.5, 4.0))

	# 짐꾼 넷: 서쪽과 동쪽 길을 따라 돌과 목재를 나른다.
	for i in 2:
		var pw := _person(_work, Person.Kind.PORTER, Person.Act.CARRY, _ground_pos(-20.8, 12.0 - 8.0 * float(i)), 0.0, i + 1)
		pw.load_kind = 2
		pw.route_a = _w(-20.8, 12.5)
		pw.route_b = _w(-20.8, -12.5)
		pw.speed = 0.9 + 0.1 * float(i)
		var pe := _person(_work, Person.Kind.PORTER, Person.Act.CARRY, _ground_pos(21.2, -10.0 + 8.0 * float(i)), 0.0, i + 3)
		pe.load_kind = 1
		pe.route_a = _w(21.2, -12.5)
		pe.route_b = _w(21.2, 11.5)
		pe.speed = 0.85 + 0.1 * float(i)

	# 밥 광주리를 이고 오는 여인 둘, 물을 나르는 아이 둘
	for i in 2:
		var wm := _person(_work, Person.Kind.WOMAN, Person.Act.CARRY, _ground_pos(-21.8, 6.0), 0.0, i + 1)
		wm.load_kind = 2
		wm.route_a = _w(-22.4 - 1.0 * float(i), 13.0)
		wm.route_b = _w(-22.4 - 1.0 * float(i), 3.0)
		wm.speed = 0.8
		var kd := _person(_work, Person.Kind.CHILD, Person.Act.WALK, _ground_pos(22.0, 0.0), 0.0, i)
		kd.route_a = _w(22.4, 11.0 - 3.0 * float(i))
		kd.route_b = _w(22.4, -5.0 - 1.0 * float(i))
		kd.speed = 1.0 + 0.15 * float(i)

	# 쉬는 일꾼과 감독하는 관원, 공사를 살피러 온 양반
	_person(_work, Person.Kind.WORKER, Person.Act.SIT, _ground_pos(-25.5, 12.8), 0.8, 0)
	_person(_work, Person.Kind.WORKER, Person.Act.SIT, _ground_pos(25.5, -12.5), -2.2, 3)
	_person(_work, Person.Kind.OFFICIAL, Person.Act.IDLE, _ground_pos(-21.0, 2.0), -PI * 0.5, 2)
	_person(_work, Person.Kind.OFFICIAL, Person.Act.TALK, _ground_pos(-3.5, 19.8), PI * 0.5, 0)
	_person(_work, Person.Kind.YANGBAN, Person.Act.TALK, _ground_pos(-2.2, 19.8), -PI * 0.5, 1)

	# 밤에도 일하도록 횃불
	for tp in [Vector2(-22.0, -9.0), Vector2(22.0, 9.5), Vector2(-22.0, 13.5), Vector2(22.0, -13.0)]:
		var t := Torch.new()
		t.position = _ground_pos(tp.x, tp.y)
		_work.add_child(t)


## 달구 하나를 네 사람이 들었다 놓으며 땅을 다진다.
func _tamp_group(c: Vector2) -> void:
	var g := Vector3(c.x, HanyangMap.stand(c.x, c.y, true), c.y)
	_rammer_y = g.y
	var rammer := Node3D.new()
	rammer.position = g
	_work.add_child(rammer)
	var log_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.3
	cm.height = 1.2
	cm.radial_segments = 10
	cm.rings = 1
	log_mi.mesh = cm
	log_mi.material_override = Hanok.shared_mat(Color(0.38, 0.27, 0.17), 0.95)
	log_mi.position = Vector3(0.0, 0.6, 0.0)
	rammer.add_child(log_mi)
	var rope := Hanok.shared_mat(Color(0.5, 0.42, 0.28), 1.0)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var rb := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 1.5)
		rb.mesh = bm
		rb.material_override = rope
		rb.position = Vector3(cos(ang) * 0.7, 1.15, sin(ang) * 0.7)
		rb.rotation.y = -ang + PI * 0.5
		rammer.add_child(rb)
		var pp := c + Vector2(cos(ang), sin(ang)) * 1.5
		_person(_work, Person.Kind.WORKER, Person.Act.TAMP, Vector3(pp.x, HanyangMap.stand(pp.x, pp.y, true), pp.y), atan2(-cos(ang), -sin(ang)), i)
	WalkGuard.add_box(_work, g + Vector3(0.0, 0.6, 0.0), Vector3(0.8, 1.2, 0.8))
	_rammers.append(rammer)


func _process(_delta: float) -> void:
	if _rammers.is_empty() or not _work.visible:
		return
	var lift := Person.tamp_lift()
	for r in _rammers:
		r.position.y = _rammer_y + 0.55 * lift


func _prop_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	mi.visibility_range_end = 120.0
	parent.add_child(mi)
	WalkGuard.add_box(parent, pos, size, yaw)


# --- 완공 뒤 ---

func _build_staff() -> void:
	# 궁녀 넷: 월대 앞마당과 양옆 길을 오간다 (월대 위 높이는 lift 로 맞춘다)
	var maid_routes: Array = [
		[Vector2(-17.0, 10.5), Vector2(17.0, 10.5)],
		[Vector2(16.0, 11.8), Vector2(-16.0, 11.8)],
		[Vector2(-15.5, -4.5), Vector2(-15.5, 5.0)],
		[Vector2(15.5, 5.0), Vector2(15.5, -4.5)],
	]
	for i in maid_routes.size():
		var r: Array = maid_routes[i]
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var m := _person(_staff, Person.Kind.MAID, Person.Act.WALK, _deck_pos(a.x, a.y), 0.0, i)
		m.lift = DECK
		m.route_a = _w(a.x, a.y)
		m.route_b = _w(b.x, b.y)
		m.speed = 0.8 + 0.08 * float(i)
	# 관원 둘이 앞마당을 거닌다
	var off_routes: Array = [[Vector2(-12.0, 9.0), Vector2(12.0, 9.0)], [Vector2(13.0, 12.8), Vector2(-9.0, 12.8)]]
	for i in off_routes.size():
		var r2: Array = off_routes[i]
		var a2: Vector2 = r2[0]
		var b2: Vector2 = r2[1]
		var o := _person(_staff, Person.Kind.OFFICIAL, Person.Act.WALK, _deck_pos(a2.x, a2.y), 0.0, i + 1)
		o.lift = DECK
		o.route_a = _w(a2.x, a2.y)
		o.route_b = _w(b2.x, b2.y)
		o.speed = 0.7
	# 근정전 앞에 서 있는 상궁과 내관 자리, 글 적는 사관
	var sg := _person(_staff, Person.Kind.MAID, Person.Act.IDLE, _deck_pos(-3.0, 8.6), PI, 2)
	var og := _person(_staff, Person.Kind.OFFICIAL, Person.Act.IDLE, _deck_pos(3.0, 8.6), PI, 0)
	var sa := _person(_staff, Person.Kind.OFFICIAL, Person.Act.SIT, _deck_pos(14.0, 8.5), -PI * 0.5, 3)
	var tk := _person(_staff, Person.Kind.YANGBAN, Person.Act.TALK, _deck_pos(-14.0, 8.0), PI * 0.5, 1)
	var tk2 := _person(_staff, Person.Kind.OFFICIAL, Person.Act.TALK, _deck_pos(-12.8, 8.0), -PI * 0.5, 2)
	for q in [sg, og, sa, tk, tk2]:
		(q as Person).lift = DECK


# --- 늘 서 있는 문지기 ---

func _build_guards() -> void:
	for gx in [-8.0, 8.0]:
		var x: float = gx
		_person(_guards, Person.Kind.SOLDIER, Person.Act.IDLE, _ground_pos(x, 20.6), 0.0, 0)
	for gx in [-7.0, 7.0]:
		var x2: float = gx
		_person(_guards, Person.Kind.SOLDIER, Person.Act.IDLE, _ground_pos(x2, -20.2), PI, 1)
