class_name GentryTravel
extends Node3D
## 길을 지나가는 양반 행렬. 왕 행차와 달리 의장 없이 그냥 길 가는 모습이다.
## 조선 초에는 마차(말이 끄는 수레)를 쓰지 않았다. 양반은 말을 타고 견마잡이가 고삐를 잡았고,
## 높은 관원은 하인 여럿이 메는 가마(평교자)를 탔다. 그래서 말 탄 양반과 가마 탄 관원 두 가지를 두었다.
## 수와 속도, 행렬 구성은 설계값이다. (고증_근거.md 46장)

const HORSES := 2
const LITTERS := 1

var _groups: Array[Dictionary] = []


func build(pts: PackedVector2Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1397
	var n := pts.size()
	if n < 30:
		return
	var made := 0
	var guard := 0
	while made < HORSES + LITTERS and guard < 600:
		guard += 1
		var i := rng.randi_range(0, n - 20)
		var j := i + rng.randi_range(6, 16)
		var a := pts[i]
		var b := pts[j]
		var d := a.distance_to(b)
		if d < 45.0 or d > 95.0:
			continue
		var ok := true
		for q in range(i, j):
			if pts[q].distance_to(pts[q + 1]) > 14.0:
				ok = false
				break
		if not ok:
			continue
		# 다른 행렬의 길과 14 m 안으로 겹치면 고르지 않는다(서로 부딪쳐 지나가지 않도록)
		var clash := false
		for og in _groups:
			for u in 6:
				var pa: Vector2 = (og["a"] as Vector2).lerp(og["b"], float(u) / 5.0)
				for w in 6:
					if pa.distance_to(a.lerp(b, float(w) / 5.0)) < 14.0:
						clash = true
		if clash:
			continue
		var lat := rng.randf_range(-2.0, 2.0)
		var dv := (b - a).normalized()
		var side := Vector2(-dv.y, dv.x) * lat
		_make_group(a + side, b + side, made < HORSES, made, rng)
		made += 1


func _ground(p: Vector2) -> float:
	return HanyangMap.stand(p.x, p.y)


func _person(kind: int, act: int, v: int) -> Person:
	var p := Person.new().setup(kind, act, Vector3.ZERO, 0.0, v)
	add_child(p)
	return p


func _make_group(a: Vector2, b: Vector2, mounted: bool, idx: int, rng: RandomNumberGenerator) -> void:
	var g := {
		"a": a, "b": b, "len": a.distance_to(b), "s": rng.randf() * a.distance_to(b), "sgn": 1.0 if rng.randf() < 0.5 else -1.0,
		"speed": 1.5 if mounted else 1.25, "wait": 0.0, "mem": [], "moving": false, "bow": false, "chk": rng.randf() * 0.25, "blocked": false, "stuck": 0.0, "ignore": 0.0,
	}
	var mem: Array = g["mem"]
	if mounted:
		# 견마잡이(고삐를 쥐고 앞에 섬) · 말 탄 양반 · 짐 든 종자
		mem.append(_m(_person(Person.Kind.WORKER, Person.Act.LOCO, idx), 0.0, 0.5, 0.0, "loco", true))
		mem.append(_m(_horse(idx), 2.2, 0.0, 0.0, "horse", false))
		var rider := _person(Person.Kind.YANGBAN, Person.Act.SIT, idx)
		mem.append(_m(rider, 2.2, 0.0, 0.95, "rider", false))
		mem.append(_m(_person(Person.Kind.PORTER, Person.Act.LOCO, idx + 1), 5.2, -0.6, 0.0, "loco", false))
	else:
		# 앞서 길을 트는 하인(밤에는 등롱) · 가마 · 가마꾼 넷 · 가마 탄 관원
		var lead := _person(Person.Kind.WORKER, Person.Act.LOCO, idx)
		var lantern := Torch.new()
		lantern.style = Torch.Style.LANTERN
		lantern.power = 1.6
		lantern.light_range = 12.0
		lantern.position = Vector3(-0.38, 0.9, 0.1)
		lead.add_child(lantern)
		mem.append(_m(lead, 0.0, 0.4, 0.0, "loco", false))
		mem.append(_m(_litter(), 6.0, 0.0, 0.0, "litter", false))
		for k in 4:
			var lt := -1.1 if k % 2 == 0 else 1.1
			var of := 4.4 if k < 2 else 7.6
			mem.append(_m(_person(Person.Kind.PORTER, Person.Act.LOCO, idx + k), of, lt, 0.0, "loco", false))
		var passenger := _person(Person.Kind.OFFICIAL, Person.Act.SIT, idx)
		mem.append(_m(passenger, 6.0, 0.0, 0.9, "rider", false))
		mem.append(_m(_person(Person.Kind.WORKER, Person.Act.LOCO, idx + 2), 10.5, 0.5, 0.0, "loco", false))
	_groups.append(g)
	_place(g, 0.0, true)


func _m(n: Node3D, off: float, lat: float, y: float, role: String, _lead: bool) -> Dictionary:
	return {"n": n, "off": off, "lat": lat, "y": y, "role": role}


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


## 말: 몸통·목·머리·꼬리·네 다리. 다리는 걸음에 맞춰 흔든다(키가 작은 조선 말, 어깨높이 약 1.1 m. 설계).
func _horse(idx: int) -> Node3D:
	var cols: Array[Color] = [Color(0.42, 0.27, 0.16), Color(0.16, 0.13, 0.12), Color(0.55, 0.42, 0.3)]
	var c: Color = cols[idx % cols.size()]
	var h := Node3D.new()
	h.name = "Horse"
	_box(h, Vector3(0.5, 0.52, 1.35), Vector3(0.0, 0.92, 0.0), c)
	var neck := _box(h, Vector3(0.24, 0.6, 0.3), Vector3(0.0, 1.22, 0.7), c)
	neck.rotation.x = 0.55
	_box(h, Vector3(0.22, 0.26, 0.5), Vector3(0.0, 1.42, 1.0), c)
	_box(h, Vector3(0.08, 0.5, 0.1), Vector3(0.0, 0.88, -0.72), c.darkened(0.3)).rotation.x = -0.3
	_box(h, Vector3(0.5, 0.06, 0.5), Vector3(0.0, 1.2, -0.05), Color(0.55, 0.16, 0.12))  # 안장 깔개
	for k in 4:
		var leg := Node3D.new()
		leg.name = "Leg%d" % k
		leg.position = Vector3(-0.17 if k % 2 == 0 else 0.17, 0.66, 0.46 if k < 2 else -0.46)
		_box(leg, Vector3(0.11, 0.66, 0.11), Vector3(0.0, -0.33, 0.0), c.darkened(0.15))
		h.add_child(leg)
	add_child(h)
	return h


## 평교자: 앞뒤로 긴 채를 하인들이 어깨에 메는 가마(설계 묘사, 형태는 간략).
func _litter() -> Node3D:
	var n := Node3D.new()
	n.name = "Litter"
	var wood := Color(0.34, 0.22, 0.12)
	var blue := Color(0.2, 0.3, 0.42)
	_box(n, Vector3(1.0, 0.1, 1.2), Vector3(0.0, 0.95, 0.0), wood)
	for sx in [-0.45, 0.45]:
		for sz in [-0.55, 0.55]:
			_box(n, Vector3(0.07, 1.3, 0.07), Vector3(sx, 1.6, sz), wood)
	_box(n, Vector3(1.2, 0.08, 1.4), Vector3(0.0, 2.3, 0.0), blue)
	for sx in [-0.55, 0.55]:
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 4.0
		pole.mesh = cm
		pole.material_override = _mat(wood)
		pole.rotation.x = PI / 2.0
		pole.position = Vector3(sx, 1.05, 0.0)
		n.add_child(pole)
	add_child(n)
	return n


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for g in _groups:
		_step(g, delta, cam)


func _step(g: Dictionary, delta: float, cam: Camera3D) -> void:
	var a: Vector2 = g["a"]
	var b: Vector2 = g["b"]
	var mem: Array = g["mem"]
	# 누군가 엎드렸으면(왕 행차) 모두 멈춘다
	var bow := false
	for m in mem:
		var p := m["n"] as Person
		if p != null and p.prostrate:
			bow = true
			break
	g["bow"] = bow
	var moving := not bow
	# 앞에 사람(다른 행렬·길 가는 사람·플레이어)이 가까이 있으면 비켜 지나갈 때까지 선다
	g["chk"] = float(g["chk"]) - delta
	g["ignore"] = maxf(float(g["ignore"]) - delta, 0.0)
	if float(g["chk"]) <= 0.0:
		g["chk"] = 0.25
		g["blocked"] = _ahead_blocked(g)
		g["stuck"] = float(g["stuck"]) + 0.25 if g["blocked"] else 0.0
		if float(g["stuck"]) > 5.0:
			g["ignore"] = 3.0  # 오래 막히면 잠깐 그냥 간다
			g["stuck"] = 0.0
	if g["blocked"] and float(g["ignore"]) <= 0.0:
		moving = false
	if float(g["wait"]) > 0.0:
		g["wait"] = float(g["wait"]) - delta
		moving = false
	if moving:
		var s: float = g["s"] + float(g["sgn"]) * float(g["speed"]) * delta
		if s >= float(g["len"]):
			s = float(g["len"])
			g["sgn"] = -1.0
			g["wait"] = 1.5
		elif s <= 0.0:
			s = 0.0
			g["sgn"] = 1.0
			g["wait"] = 1.5
		g["s"] = s
	if moving != g["moving"]:
		g["moving"] = moving
		for m in mem:
			if m["role"] == "loco":
				(m["n"] as Person).set_locomotion(float(g["speed"]) if moving else 0.0, true)
	# 멀리 있는 행렬은 위치만 갱신한다
	if cam != null:
		var c := Vector2(cam.global_position.x, cam.global_position.z)
		if c.distance_to(a.lerp(b, float(g["s"]) / maxf(float(g["len"]), 1.0))) > 260.0:
			_place(g, delta, true)
			_legs(g, 0.0, delta)
			return
	_place(g, delta, false)
	_legs(g, float(g["speed"]) if moving else 0.0, delta)


func _ahead_blocked(g: Dictionary) -> bool:
	var a: Vector2 = g["a"]
	var b: Vector2 = g["b"]
	var ln: float = g["len"]
	var head := a.lerp(b, float(g["s"]) / maxf(ln, 1.0))
	var dv := (b - a) / maxf(ln, 0.01) * float(g["sgn"])
	var front := head + dv * 3.0
	var own := {}
	for m in g["mem"]:
		own[m["n"]] = true
	for n in get_tree().get_nodes_in_group("person"):
		if own.has(n):
			continue
		var p := n as Node3D
		if p == null:
			continue
		var q := Vector2(p.global_position.x, p.global_position.z)
		if q.distance_to(front) < 3.2 and (q - head).dot(dv) > -0.5:
			return true
	return false


func _place(g: Dictionary, delta: float, snap: bool) -> void:
	var a: Vector2 = g["a"]
	var b: Vector2 = g["b"]
	var ln: float = g["len"]
	var head := a.lerp(b, float(g["s"]) / maxf(ln, 1.0))
	var dv := (b - a) / maxf(ln, 0.01) * float(g["sgn"])
	var side := Vector2(-dv.y, dv.x)
	var bow: bool = g["bow"]
	var want_yaw := atan2(dv.x, dv.y)
	for m in g["mem"]:
		var n: Node3D = m["n"]
		var pos := head - dv * float(m["off"]) + side * float(m["lat"])
		var y: float = m["y"]
		var role: String = m["role"]
		if bow:
			# 길가에서 가마를 내려놓고 말에서 내려 엎드린다
			if role == "rider":
				y = 0.3 if float(m["off"]) == 6.0 else 0.0
			elif role == "litter":
				y = -0.6
		var tgt := Vector3(pos.x, _ground(pos) + y, pos.y)
		if snap:
			n.position = tgt
			n.rotation.y = want_yaw
		else:
			var k := minf(delta * 5.0, 1.0)
			n.position = n.position.lerp(tgt, k)
			n.rotation.y = lerp_angle(n.rotation.y, want_yaw, k)


## 말 다리를 걸음에 맞춰 흔든다.
func _legs(g: Dictionary, speed: float, delta: float) -> void:
	for m in g["mem"]:
		if m["role"] != "horse":
			continue
		var h: Node3D = m["n"]
		var t := Time.get_ticks_msec() * 0.001
		for k in 4:
			var leg := h.get_node_or_null("Leg%d" % k) as Node3D
			if leg == null:
				continue
			var ph := t * 6.0 * (speed / 1.5) + (0.0 if k == 0 or k == 3 else PI)
			leg.rotation.x = lerpf(leg.rotation.x, sin(ph) * 0.5 * clampf(speed, 0.0, 1.0), minf(delta * 8.0, 1.0))
