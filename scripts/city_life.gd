class_name CityLife
extends Node3D
## 도성 안 생활 시설: 우물과 물 긷는 여인, 개천 빨래터, 대장간, 목수 작업장.
## 사료: 이런 시설의 1396년 위치와 규모는 확인하지 못했다. 한양에 우물, 개천 빨래, 대장간이 있었다는 일반적 사실만
## 쓰고 위치·모양은 모두 설계값이다(docs/고증_근거.md 18장). 개천 돌다리(광통교 등)는 태종 대 공사라 1막에는 두지 않는다.

## main이 민가 예약 지점으로 미리 넘겨 주는 자리(대장간, 목수 마당)
const SMITHY := Vector2(132.0, 22.0)
const CARPENTER := Vector2(-62.0, 66.0)


func build(road_pts: PackedVector2Array) -> void:
	_wells(road_pts)
	_laundry()
	_smithy()
	_carpenter()
	_children_play(road_pts)


var _kite_roots: Array[Node3D] = []
var _tops: Array[Node3D] = []


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var winter_kites := Season.month_f < 3.0 or Season.month_f >= 12.0
	for i in _kite_roots.size():
		_kite_roots[i].visible = winter_kites
		_kite_roots[i].rotation.z = 0.12 * sin(t * 1.7 + float(i))
	var ice_top := Season.cold > 0.5
	for i in _tops.size():
		_tops[i].visible = ice_top
		_tops[i].rotation.y = t * 14.0 + float(i)


func _on_road(p: Vector2, road_pts: PackedVector2Array) -> bool:
	for rp in road_pts:
		if p.distance_to(rp) < 9.0:
			return true
	return false


func _box(parent: Node3D, c: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = c
	mi.rotation.y = yaw
	mi.visibility_range_end = 150.0
	parent.add_child(mi)
	return mi


func _y(p: Vector2) -> float:
	return HanyangMap.height(p.x, p.y)


func _wells(road_pts: PackedVector2Array) -> void:
	var hp := HanyangCity.house_points
	var stone := Hanok.shared_mat(Color(0.5, 0.48, 0.44), 0.95)
	var wood := Hanok.shared_mat(Color(0.36, 0.26, 0.17), 0.9)
	var dark := Hanok.shared_mat(Color(0.03, 0.04, 0.05), 1.0)
	var made := 0
	var i := 3
	while i < hp.size() and made < 8:
		var p := hp[i] + Vector2(4.5, 2.0)
		i += 9
		if _on_road(p, road_pts) or HanyangMap.u_of(p.x, p.y) > 0.82:
			continue
		var gy := _y(p)
		# 우물 테두리는 돌을 네모로 둘렀다 (모양은 설계값)
		var w := Node3D.new()
		w.position = Vector3(p.x, gy, p.y)
		add_child(w)
		for sx in [-1.0, 1.0]:
			_box(w, Vector3(float(sx) * 0.55, 0.3, 0.0), Vector3(0.3, 0.6, 1.4), stone)
		for sz in [-1.0, 1.0]:
			_box(w, Vector3(0.0, 0.3, float(sz) * 0.55), Vector3(0.8, 0.6, 0.3), stone)
		_box(w, Vector3(0.0, 0.58, 0.0), Vector3(0.8, 0.02, 0.8), dark)
		# 두레박 걸이: 기둥 둘과 가로대, 줄 하나
		for sx in [-1.0, 1.0]:
			_box(w, Vector3(float(sx) * 0.7, 0.9, 0.0), Vector3(0.1, 1.8, 0.1), wood)
		_box(w, Vector3(0.0, 1.8, 0.0), Vector3(1.6, 0.1, 0.1), wood)
		_box(w, Vector3(0.0, 1.35, 0.0), Vector3(0.02, 0.9, 0.02), wood)
		_box(w, Vector3(0.0, 0.88, 0.0), Vector3(0.22, 0.2, 0.22), wood)
		var maid := Person.new().setup(Person.Kind.WOMAN, Person.Act.DRAW, Vector3(p.x, gy, p.y + 1.1), PI, made % 4)
		maid.scheduled = true
		add_child(maid)
		made += 1


## 개천 북쪽 둑에서 허리를 굽혀 빨래를 두드리는 여인들
func _laundry() -> void:
	var stone := Hanok.shared_mat(Color(0.55, 0.53, 0.48), 0.95)
	for x in [-70.0, 36.0, 118.0]:
		var fx: float = x
		var z := HanyangMap.stream_z(fx) - 6.2
		var gy := HanyangMap.height_no_carve(fx, z)
		_box(self, Vector3(fx, gy + 0.08, z + 0.9), Vector3(1.8, 0.2, 0.7), stone)
		for k in 2:
			var px := fx - 0.7 + 1.4 * float(k)
			var wm := Person.new().setup(Person.Kind.WOMAN, Person.Act.WASH, Vector3(px, gy, z), 0.0, (int(fx) + k) % 4)
			wm.scheduled = true
			add_child(wm)


## 대장간: 지붕만 얹은 열린 작업장에 화로와 모루. 화로 불빛이 주황색으로 흔들린다.
func _smithy() -> void:
	var p := SMITHY
	var gy := _y(p)
	var root := Node3D.new()
	root.position = Vector3(p.x, gy, p.y)
	add_child(root)
	var wood := Hanok.shared_mat(Color(0.3, 0.22, 0.15), 0.95)
	var thatch := Hanok.shared_mat(Color(0.5, 0.4, 0.22), 1.0)
	var stone := Hanok.shared_mat(Color(0.35, 0.33, 0.3), 0.95)
	var iron := Hanok.shared_mat(Color(0.12, 0.12, 0.13), 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, Vector3(float(sx) * 2.4, 1.2, float(sz) * 1.8), Vector3(0.18, 2.4, 0.18), wood)
	_box(root, Vector3(0.0, 2.55, 0.0), Vector3(6.2, 0.35, 4.8), thatch)
	_box(root, Vector3(-1.4, 0.45, -1.2), Vector3(1.4, 0.9, 1.0), stone)  # 화로
	_box(root, Vector3(0.6, 0.35, 0.2), Vector3(0.5, 0.7, 0.3), wood)     # 모루 받침
	_box(root, Vector3(0.6, 0.78, 0.2), Vector3(0.6, 0.16, 0.26), iron)    # 모루
	_box(root, Vector3(1.8, 0.2, -1.2), Vector3(1.0, 0.4, 0.9), Hanok.shared_mat(Color(0.05, 0.05, 0.05), 1.0))  # 숯더미
	# 화로 불빛과 잉걸불
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.45, 0.1)
	_box(root, Vector3(-1.4, 0.92, -1.2), Vector3(0.9, 0.06, 0.6), glow)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-1.4, 1.3, -1.0)
	lamp.light_color = Color(1.0, 0.5, 0.2)
	lamp.light_energy = 2.2
	lamp.omni_range = 14.0
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 60.0
	lamp.distance_fade_length = 20.0
	root.add_child(lamp)
	# 대장장이는 모루 곁에서 쇠를 두드린다
	var smith := Person.new().setup(Person.Kind.MASON, Person.Act.HAMMER, Vector3(p.x + 0.6, gy, p.y + 1.1), PI, 1)
	smith.scheduled = true
	add_child(smith)
	var tk := Tink.new()
	tk.position = Vector3(p.x + 0.6, gy + 1.0, p.y)
	tk.base_pitch = 0.8
	add_child(tk)
	var label := Label3D.new()
	label.text = "대장간"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(p.x, gy + 4.4, p.y)
	label.font_size = 52
	label.pixel_size = 0.012
	label.outline_size = 12
	label.visibility_range_end = 70.0
	add_child(label)


## 목수 마당: 통나무 더미와 작업대, 대패질하는 목수
func _carpenter() -> void:
	var p := CARPENTER
	var gy := _y(p)
	var wood := Hanok.shared_mat(Color(0.5, 0.38, 0.24), 0.95)
	var bark := Hanok.shared_mat(Color(0.32, 0.23, 0.15), 1.0)
	var shave := Hanok.shared_mat(Color(0.78, 0.66, 0.45), 1.0)
	var root := Node3D.new()
	root.position = Vector3(p.x, gy, p.y)
	add_child(root)
	for i in 6:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.22
		cm.height = 4.5
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = bark
		mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
		mi.position = Vector3(-3.0, 0.25 + 0.38 * floorf(i / 3.0), -2.0 + 0.4 * float(i % 3) + 0.2 * floorf(i / 3.0))
		root.add_child(mi)
	_box(root, Vector3(1.0, 0.45, 0.0), Vector3(3.2, 0.1, 0.8), wood)  # 작업대 판
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(1.0 + float(sx) * 1.4, 0.2, 0.0), Vector3(0.14, 0.4, 0.7), bark)
	_box(root, Vector3(0.0, 0.52, 0.0), Vector3(1.6, 0.05, 0.3), wood)  # 켜고 있는 판자
	for i in 5:
		_box(root, Vector3(0.4 + 0.3 * float(i), 0.03, 0.8 + 0.1 * float(i % 2)), Vector3(0.25, 0.02, 0.1), shave, 0.4 * float(i))
	var carp := Person.new().setup(Person.Kind.WORKER, Person.Act.PLANE, Vector3(p.x + 1.0, gy, p.y + 0.95), PI, 2)
	carp.scheduled = true
	add_child(carp)
	var label := Label3D.new()
	label.text = "목수 마당"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(p.x, gy + 3.5, p.y)
	label.font_size = 52
	label.pixel_size = 0.012
	label.outline_size = 12
	label.visibility_range_end = 70.0
	add_child(label)


## 아이들 놀이: 연날리기(정월), 팽이치기(겨울), 뛰어다니기. 1396년 한양 아이들 놀이의 사료는 찾지 못했다.
## 연날리기와 팽이치기는 오래된 민속 놀이라 넣었고, 위치·인원·동작은 모두 설계값이다(docs 19장).
func _children_play(road_pts: PackedVector2Array) -> void:
	var hp := HanyangCity.house_points
	if hp.size() < 30:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1397
	var sites: Array[Vector2] = []
	var i := 11
	while i < hp.size() and sites.size() < 6:
		var p := hp[i] + Vector2(rng.randf_range(6.0, 9.0), rng.randf_range(-7.0, -4.0))
		i += 17
		if _on_road(p, road_pts) or HanyangMap.u_of(p.x, p.y) > 0.8:
			continue
		var h := _y(p)
		if absf(_y(p + Vector2(3.0, 0.0)) - h) > 0.5 or absf(_y(p + Vector2(0.0, 3.0)) - h) > 0.5:
			continue
		sites.append(p)
	for si in sites.size():
		var c := sites[si]
		var kind_of_play := si % 3
		if kind_of_play == 0:
			_kite(c, rng)
		elif kind_of_play == 1:
			_top_game(c, rng)
		else:
			_chase(c, rng)


func _child(p: Vector2, act: int, yaw: float, rng: RandomNumberGenerator) -> Person:
	var kid := Person.new().setup(Person.Kind.CHILD, act, Vector3(p.x, _y(p), p.y), yaw, rng.randi_range(0, 3))
	kid.scheduled = true
	add_child(kid)
	return kid


func _kite(c: Vector2, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	var kid := _child(c, Person.Act.KITE, yaw, rng)
	_child(c + Vector2(2.2, 1.0), Person.Act.IDLE, yaw + 2.5, rng)
	var hand := Vector3(c.x, _y(c) + 1.2, c.y)
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	var kite_pos := hand + dir * 7.0 + Vector3(0.0, 15.0, 0.0)
	var root := Node3D.new()
	root.position = kite_pos
	add_child(root)
	var paper := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.9, 0.02)
	paper.mesh = bm
	paper.material_override = Hanok.shared_mat(Color(0.88, 0.84, 0.7), 0.9)
	paper.visibility_range_end = 120.0
	root.add_child(paper)
	var spine := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.03, 0.9, 0.03)
	spine.mesh = sm
	spine.material_override = Hanok.shared_mat(Color(0.5, 0.2, 0.15), 0.9)
	spine.position = Vector3(0.0, 0.0, 0.02)
	spine.visibility_range_end = 120.0
	root.add_child(spine)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.06, 1.8, 0.01)
	tail.mesh = tm
	tail.material_override = Hanok.shared_mat(Color(0.6, 0.15, 0.15), 0.9)
	tail.position = Vector3(0.0, -1.3, 0.0)
	tail.visibility_range_end = 120.0
	root.add_child(tail)
	var line_len := hand.distance_to(kite_pos)
	var line := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.012, 0.012, line_len)
	line.mesh = lm
	line.material_override = Hanok.shared_mat(Color(0.8, 0.78, 0.7), 1.0)
	line.transform = Transform3D(Basis.looking_at((kite_pos - hand).normalized(), Vector3.UP), (hand + kite_pos) * 0.5)
	line.visibility_range_end = 120.0
	add_child(line)
	_kite_roots.append(root)
	kid.rotation.y = yaw


func _top_game(c: Vector2, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * TAU
	var d := Vector2(sin(yaw), cos(yaw))
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var p := c + d * side * 1.6
		_child(p, Person.Act.TOP, atan2(-d.x * side, -d.y * side), rng)
	var wood := Hanok.shared_mat(Color(0.42, 0.28, 0.16), 0.8)
	for k in 2:
		var tp := c + d.rotated(PI * 0.5) * (0.5 if k == 0 else -0.5)
		var top := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.01
		cm.height = 0.13
		cm.radial_segments = 8
		cm.rings = 1
		top.mesh = cm
		top.material_override = wood
		top.position = Vector3(tp.x, _y(tp) + 0.07, tp.y)
		top.visibility_range_end = 60.0
		add_child(top)
		_tops.append(top)


func _chase(c: Vector2, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var a := c + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var b := a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(7.0, 10.0)
		var kid := _child(a, Person.Act.WALK, 0.0, rng)
		kid.route_a = a
		kid.route_b = b
		kid.speed = rng.randf_range(2.2, 2.8)
