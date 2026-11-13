class_name WallWorks
extends Node3D
## 성벽 공사장과 경복궁 터 작업장.
## 사료: 태조 5년(1396) 구간을 군현에 나누어 동시에 쌓았다. 그래서 아직 올라가지 않은 구간에도 공사장이 있다.
## 설계값: 일꾼 수와 작업 방식, 돌 운반법(지게), 돌·통나무 더미 모양 (docs/고증_근거.md 8장).

## 공사장을 둘 구간 번호 (97구간 중). 문과 개천에서 먼 구간을 골랐다.
const LOTS: Array[int] = [40, 47, 58, 69, 80, 86]

var _lots: Dictionary = {}  # 구간 번호 -> Node3D
var _rammers: Array[Node3D] = []
var _rammer_y: Array[float] = []


func _ready() -> void:
	for s in LOTS:
		var lot := _make_lot(s)
		add_child(lot)
		_lots[s] = lot
	# 공사장 사람들도 해 뜰 무렵 나와 해 질 무렵 돌아간다
	for n in find_children("*", "Person", true, false):
		(n as Person).scheduled = true


## 올라간 구간의 공사장은 사라진다.
func set_progress(p: float) -> void:
	var count := int(floorf(clampf(p, 0.0, 1.0) * HanyangMap.SECTIONS))
	for s in _lots:
		_lots[s].visible = s >= count
		WalkGuard.set_collide(_lots[s], s >= count)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, HanyangMap.height(x, z), z)


func _make_lot(s: int) -> Node3D:
	var root := Node3D.new()
	var k := s * HanyangWall.SEGS
	var a := HanyangMap.crest_point(HanyangWall.PHI_START - TAU * float(k) / float(HanyangWall.TOTAL))
	var b := HanyangMap.crest_point(HanyangWall.PHI_START - TAU * float(k + 2) / float(HanyangWall.TOTAL))
	var t := (b - a).normalized()
	var out := Vector2(t.y, -t.x)
	if out.dot(a) < 0.0:
		out = -out
	var inn := -out
	var c := a + inn * 7.0  # 성 안쪽 작업 마당

	_stone_pile(root, c + t * 3.0)
	var tk := Tink.new()
	tk.position = _ground(c.x, c.y) + Vector3(0.0, 1.0, 0.0)
	root.add_child(tk)
	_log_pile(root, c - t * 4.0 + inn * 2.0)

	# 석수 둘: 돌 곁에서 정으로 쪼는 사람
	for i in 2:
		var p := c + t * (1.5 + 3.0 * i) + inn * 2.0
		var m := Person.new().setup(Person.Kind.MASON, Person.Act.HAMMER, _ground(p.x, p.y), atan2(t.x, t.y) + (0.4 if i == 0 else -0.5))
		root.add_child(m)
	# 짐꾼 둘: 돌 더미와 성벽 자리 사이를 오간다
	for i in 2:
		var from_p := c + t * (3.0 + 2.0 * i)
		var to_p := a + inn * 1.0 + t * (4.0 * i)
		var pr := Person.new().setup(Person.Kind.PORTER, Person.Act.CARRY, _ground(from_p.x, from_p.y), 0.0)
		pr.route_a = from_p
		pr.route_b = to_p
		pr.speed = 0.9
		root.add_child(pr)
	# 밤에도 일할 수 있도록 작업 마당 양쪽에 횃불
	for tsign in [-1.0, 1.0]:
		var ts: float = tsign
		var tpos := c + t * (ts * 6.0) + inn * 1.0
		var tc := Torch.new()
		tc.position = _ground(tpos.x, tpos.y)
		root.add_child(tc)
	# 그늘에 앉아 쉬는 일꾼 하나
	var rp := c - t * 6.5 + inn * 3.5
	root.add_child(Person.new().setup(Person.Kind.WORKER, Person.Act.SIT, _ground(rp.x, rp.y), atan2(t.x, t.y) + 0.8))
	# 감독하는 관원 하나
	var op := c - t * 1.0 + inn * 4.0
	root.add_child(Person.new().setup(Person.Kind.OFFICIAL, Person.Act.IDLE, _ground(op.x, op.y), atan2(out.x, out.y)))
	_scaffold(root, a, t, out)
	if HanyangMap.height(a.x, a.y) < HanyangWall.STONE_ABOVE:
		_formwork(root, a, t, inn)
		_tamping_crew(root, a + inn * 5.5 - t * 7.0)
	# 두 사람이 메는 목도 한 조
	var mk := Mokdo.new().setup(c + t * 1.0 + inn * 1.5, a + inn * 1.5 + t * 8.0)
	root.add_child(mk)
	return root


## 달구질 조: 흙벽(판축) 구간에서 네 사람이 달구를 들었다 놓으며 흙을 다진다. 사료에는 평지를 토성으로 쌓았다는 것까지만 있고
## 도구와 인원은 설계값이다(docs 19장).
func _tamping_crew(parent: Node3D, c: Vector2) -> void:
	var g := _ground(c.x, c.y)
	var rammer := Node3D.new()
	rammer.position = g
	parent.add_child(rammer)
	var wood := Hanok.shared_mat(Color(0.38, 0.27, 0.17), 0.95)
	var rope := Hanok.shared_mat(Color(0.5, 0.42, 0.28), 1.0)
	var log_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.26
	cm.bottom_radius = 0.3
	cm.height = 1.2
	cm.radial_segments = 10
	cm.rings = 1
	log_mi.mesh = cm
	log_mi.material_override = wood
	log_mi.position = Vector3(0.0, 0.6, 0.0)
	log_mi.visibility_range_end = 120.0
	rammer.add_child(log_mi)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var rb := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 1.5)
		rb.mesh = bm
		rb.material_override = rope
		rb.position = Vector3(cos(ang) * 0.7, 1.15, sin(ang) * 0.7)
		rb.rotation.y = -ang + PI * 0.5
		rb.visibility_range_end = 80.0
		rammer.add_child(rb)
		var pp := c + Vector2(cos(ang), sin(ang)) * 1.5
		var w := Person.new().setup(Person.Kind.WORKER, Person.Act.TAMP, _ground(pp.x, pp.y), atan2(-cos(ang), -sin(ang)))
		parent.add_child(w)
	_rammers.append(rammer)
	_rammer_y.append(g.y)


func _process(_delta: float) -> void:
	if _rammers.is_empty():
		return
	var lift := Person.tamp_lift()
	for i in _rammers.size():
		_rammers[i].position.y = _rammer_y[i] + 0.55 * lift


## 비계: 성벽 바깥쪽에 세운 통나무 기둥, 가로대, 대각 버팀 (모양은 설계값)
func _scaffold(parent: Node3D, a: Vector2, t: Vector2, out: Vector2) -> void:
	var wood := Hanok.shared_mat(Color(0.42, 0.31, 0.2), 0.95)
	var base := a + out * 0.8
	var yaw := atan2(t.x, t.y)
	for i in 4:
		var p := base + t * (float(i) * 3.0)
		var gy := HanyangMap.height(p.x, p.y)
		var pole := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 6.5, 0.14)
		pole.mesh = bm
		pole.material_override = wood
		pole.position = Vector3(p.x, gy + 3.0, p.y)
		pole.visibility_range_end = 150.0
		parent.add_child(pole)
		WalkGuard.add_box(parent, pole.position, Vector3(0.4, 6.5, 0.4))
	for level in [2.0, 4.0]:
		var gy0 := HanyangMap.height(base.x, base.y)
		var mid := base + t * 4.5
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.1, 0.1, 9.2)
		rail.mesh = rb
		rail.material_override = wood
		rail.position = Vector3(mid.x, gy0 + float(level), mid.y)
		rail.rotation.y = yaw
		rail.visibility_range_end = 150.0
		parent.add_child(rail)
	# 작업용 널판
	var deck := MeshInstance3D.new()
	var db := BoxMesh.new()
	db.size = Vector3(1.0, 0.08, 8.0)
	deck.mesh = db
	deck.material_override = wood
	var dm := base + t * 4.5
	deck.position = Vector3(dm.x, HanyangMap.height(base.x, base.y) + 2.0, dm.y)
	deck.rotation.y = yaw
	deck.visibility_range_end = 150.0
	parent.add_child(deck)


## 판축 거푸집: 평지 토성을 쌓을 때 양쪽에 대는 널판 틀 (판축은 오래된 흙다짐 기법, 1396년 현장 모습은 설계값)
func _formwork(parent: Node3D, a: Vector2, t: Vector2, inn: Vector2) -> void:
	var wood := Hanok.shared_mat(Color(0.5, 0.38, 0.24), 0.95)
	var yaw := atan2(t.x, t.y)
	for side in [-1.0, 1.0]:
		var p := a + inn * (float(side) * HanyangWall.HALF_BOTTOM) + t * 2.0
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 1.5, 4.5)
		board.mesh = bm
		board.material_override = wood
		board.position = Vector3(p.x, HanyangMap.height(p.x, p.y) + 0.75, p.y)
		board.rotation.y = yaw
		board.visibility_range_end = 150.0
		parent.add_child(board)
		WalkGuard.add_box(parent, board.position, bm.size, yaw)
	for k in 3:
		var q := a + t * (0.5 + 1.5 * float(k))
		var tie := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(HanyangWall.HALF_BOTTOM * 2.0 + 0.5, 0.1, 0.1)
		tie.mesh = tb
		tie.material_override = wood
		tie.position = Vector3(q.x, HanyangMap.height(q.x, q.y) + 1.35, q.y)
		tie.rotation.y = yaw + PI * 0.5
		tie.visibility_range_end = 150.0
		parent.add_child(tie)


static func _stone_pile(parent: Node3D, c: Vector2) -> void:
	var mat := Hanok.shared_mat(Color(0.56, 0.54, 0.5), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(c.x) * 31.0 + absf(c.y) * 17.0)
	for i in 9:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 0.9))
		mi.mesh = bm
		mi.material_override = mat
		var x := c.x + rng.randf_range(-2.0, 2.0)
		var z := c.y + rng.randf_range(-1.5, 1.5)
		mi.position = Vector3(x, HanyangMap.height(x, z) + bm.size.y * 0.5 - 0.05 + (0.45 if i > 5 else 0.0), z)
		mi.rotation.y = rng.randf() * PI
		mi.visibility_range_end = 150.0
		parent.add_child(mi)
	WalkGuard.add_box(parent, Vector3(c.x, HanyangMap.height(c.x, c.y) + 0.55, c.y), Vector3(4.4, 1.1, 3.4))


static func _log_pile(parent: Node3D, c: Vector2) -> void:
	var mat := Hanok.shared_mat(Color(0.36, 0.25, 0.16), 0.95)
	var gh := HanyangMap.height(c.x, c.y)
	for i in 6:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.18
		cm.height = 4.0
		cm.radial_segments = 8
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat
		var row := 0 if i < 4 else 1
		var col := i if i < 4 else i - 4
		mi.position = Vector3(c.x + (col - 1.5 + 0.5 * row) * 0.36, gh + 0.18 + row * 0.32, c.y)
		mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		mi.visibility_range_end = 150.0
		parent.add_child(mi)
	WalkGuard.add_box(parent, Vector3(c.x, gh + 0.5, c.y), Vector3(2.0, 1.0, 4.2))
