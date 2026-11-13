class_name StreetLife
extends Node3D
## 큰길을 오가는 사람들. 길 위 점들 가운데 이어진 구간을 골라 두 점 사이를 오가게 한다.
## 신분별 비율과 수는 설계값이다. 1막에는 시전행랑이 없으므로 장사하는 사람은 두지 않았다.

const KINDS: Array[int] = [
	Person.Kind.WORKER, Person.Kind.WORKER, Person.Kind.WORKER, Person.Kind.WORKER,
	Person.Kind.PORTER, Person.Kind.PORTER, Person.Kind.PORTER,
	Person.Kind.WOMAN, Person.Kind.WOMAN, Person.Kind.WOMAN,
	Person.Kind.CHILD, Person.Kind.CHILD,
	Person.Kind.YANGBAN, Person.Kind.YANGBAN,
	Person.Kind.OFFICIAL, Person.Kind.OFFICIAL,
]


func build(pts: PackedVector2Array, walkers: int, talkers: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1394
	var n := pts.size()
	if n < 30:
		return

	var placed := 0
	var guard := 0
	while placed < walkers and guard < walkers * 30:
		guard += 1
		var i := rng.randi_range(0, n - 20)
		var j := i + rng.randi_range(6, 16)
		var a := pts[i]
		var b := pts[j]
		var d := a.distance_to(b)
		if d < 25.0 or d > 90.0:
			continue
		var ok := true
		for q in range(i, j):
			if pts[q].distance_to(pts[q + 1]) > 14.0:
				ok = false
				break
		if not ok:
			continue
		var t := (b - a).normalized()
		var side := Vector2(-t.y, t.x) * rng.randf_range(-2.5, 2.5)
		var k: int = KINDS[rng.randi() % KINDS.size()]
		var p := Person.new()
		var act := Person.Act.WALK
		if k == Person.Kind.PORTER:
			act = Person.Act.CARRY
			p.load_kind = 2
		var start := a + side
		p.setup(k, act, Vector3(start.x, HanyangMap.stand(start.x, start.y), start.y), 0.0, rng.randi_range(0, 3))
		p.route_a = a + side
		p.route_b = b + side
		p.scheduled = true
		p.speed = rng.randf_range(0.8, 1.3) if k != Person.Kind.CHILD else rng.randf_range(1.5, 2.2)
		add_child(p)
		placed += 1

	# 길가에 서서 이야기하는 두 사람
	var made := 0
	guard = 0
	while made < talkers and guard < talkers * 30:
		guard += 1
		var i := rng.randi_range(0, n - 2)
		var c := pts[i]
		var t2 := (pts[i + 1] - c).normalized()
		var off := Vector2(-t2.y, t2.x) * (rng.randf_range(5.0, 7.0) * (1.0 if rng.randf() < 0.5 else -1.0))
		var pos := c + off
		var kinds: Array[int] = [Person.Kind.YANGBAN, Person.Kind.OFFICIAL, Person.Kind.WORKER, Person.Kind.WOMAN]
		var k1: int = kinds[rng.randi() % kinds.size()]
		var k2: int = k1 if rng.randf() < 0.6 else kinds[rng.randi() % kinds.size()]
		var gap := Vector2(-t2.y, t2.x).rotated(0.4) * 0.5
		var p1 := pos - gap
		var p2 := pos + gap
		var yaw1 := atan2((p2 - p1).x, (p2 - p1).y)
		var pa := Person.new().setup(k1, Person.Act.TALK, _ground(p1), yaw1, rng.randi_range(0, 3))
		var pb := Person.new().setup(k2, Person.Act.IDLE, _ground(p2), yaw1 + PI, rng.randi_range(0, 3))
		pa.scheduled = true
		pb.scheduled = true
		add_child(pa)
		add_child(pb)
		made += 1


## 순라: 인정부터 파루까지 큰길을 오가는 군졸 둘씩 두 조. 등롱을 든다.
func build_patrol(pts: PackedVector2Array) -> void:
	var n := pts.size()
	if n < 60:
		return
	for team in 2:
		var i := (n / 4) * (team * 2 + 1)
		i = clampi(i, 0, n - 24)
		var a := pts[i]
		var b := pts[i + 14]
		for m in 2:
			var side := Vector2(-(b - a).y, (b - a).x).normalized() * (1.2 if m == 0 else -1.2)
			var p := Person.new()
			p.setup(Person.Kind.SOLDIER, Person.Act.WALK, _ground(a + side), 0.0, m + team)
			p.route_a = a + side
			p.route_b = b + side
			p.speed = 1.0
			p.scheduled = true
			p.patrol = true
			if m == 0:
				var lantern := Torch.new()
				lantern.style = Torch.Style.LANTERN
				lantern.power = 1.6
				lantern.light_range = 12.0
				lantern.position = Vector3(-0.38, 0.9, 0.1)
				p.add_child(lantern)
			add_child(p)


## 육조거리(광화문 앞 큰길): 관청에 오가는 관원과 하인, 길 가는 백성이 밤낮으로 오간다. 일과 시각과 무관하게 늘 다니며(설계),
## 밤에는 절반이 등롱을 든다. 수와 신분 비율은 설계값이다. (고증_근거.md 45장)
func build_yukjo_street() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1396
	var cx := HanyangMap.GWANGHWAMUN.x
	var z0 := HanyangMap.GWANGHWAMUN.y + 10.0
	var z1 := HanyangMap.HWANGTOHYEON.y - 4.0
	var kinds: Array[int] = [
		Person.Kind.OFFICIAL, Person.Kind.OFFICIAL, Person.Kind.OFFICIAL, Person.Kind.YANGBAN,
		Person.Kind.WORKER, Person.Kind.PORTER, Person.Kind.WOMAN, Person.Kind.WORKER, Person.Kind.CHILD,
	]
	for m in 14:
		var k: int = kinds[m % kinds.size()]
		var za := rng.randf_range(z0, z1 - 30.0)
		var zb := za + rng.randf_range(30.0, 62.0)
		zb = minf(zb, z1)
		var lat := rng.randf_range(-5.2, 5.2)
		var a := Vector2(cx + lat, za)
		var b := Vector2(cx + lat + rng.randf_range(-1.0, 1.0), zb)
		var p := Person.new()
		var act := Person.Act.WALK
		if k == Person.Kind.PORTER:
			act = Person.Act.CARRY
			p.load_kind = 2
		var start := a.lerp(b, rng.randf())
		p.setup(k, act, _ground(start), 0.0, rng.randi_range(0, 3))
		p.route_a = a
		p.route_b = b
		p.speed = rng.randf_range(0.9, 1.3) if k != Person.Kind.CHILD else rng.randf_range(1.5, 2.0)
		if m % 2 == 0:
			var lantern := Torch.new()
			lantern.style = Torch.Style.LANTERN
			lantern.power = 1.6
			lantern.light_range = 12.0
			lantern.position = Vector3(-0.38, 0.9, 0.1)
			p.add_child(lantern)
		add_child(p)
	# 길가에 서서 이야기하는 사람들
	for t in 3:
		var pos := Vector2(cx + (7.0 if t % 2 == 0 else -7.0), z0 + 16.0 + 22.0 * float(t))
		var gap := Vector2(0.0, 1.0).rotated(0.4) * 0.5
		var kk: int = Person.Kind.OFFICIAL if t != 1 else Person.Kind.YANGBAN
		var pa := Person.new().setup(kk, Person.Act.TALK, _ground(pos - gap), atan2(gap.x, gap.y), rng.randi_range(0, 3))
		var pb := Person.new().setup(kk, Person.Act.IDLE, _ground(pos + gap), atan2(-gap.x, -gap.y), rng.randi_range(0, 3))
		add_child(pa)
		add_child(pb)


## 군졸 훈련장(설계값 위치): 창을 든 군졸 여섯이 두 줄로 서서 수문장의 호령에 맞춰 같은 박자로 창을 찌른다.
## 조선 초 군사 훈련의 절차·진법은 확인하지 못했고, 사료는 군졸이 철릭 차림에 창을 들었다는 정도다(docs 14장·19장).
const DRILL := Vector2(152.0, -10.0)


func build_drill() -> void:
	var t := Vector2(1.0, 0.0)
	var face := Vector2(0.0, 1.0)  # 남쪽을 향해 선다
	for row in 2:
		for col in 3:
			var p := DRILL + t * (float(col) - 1.0) * 2.0 + face * (-float(row) * 2.0)
			var sol := Person.new().setup(Person.Kind.SOLDIER, Person.Act.DRILL, _ground(p), 0.0, (row + col) % 3)
			sol.scheduled = true
			sol.rotation.y = 0.0
			add_child(sol)
	# 호령하는 수문장(관원 모자) 하나와 짚 표적
	var cp := DRILL + face * 5.5
	var cmd := Person.new().setup(Person.Kind.SOLDIER, Person.Act.TALK, _ground(cp), PI, 3)
	cmd.scheduled = true
	add_child(cmd)
	var tp := DRILL + face * 9.0
	var target := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.34
	cm.height = 1.5
	cm.radial_segments = 8
	cm.rings = 1
	target.mesh = cm
	target.material_override = Hanok.shared_mat(Color(0.62, 0.52, 0.3), 1.0)
	target.position = _ground(tp) + Vector3(0.0, 0.75, 0.0)
	target.visibility_range_end = 120.0
	add_child(target)
	var tc := Torch.new()
	tc.position = _ground(DRILL + Vector2(4.5, 3.0))
	add_child(tc)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, HanyangMap.stand(p.x, p.y), p.y)
