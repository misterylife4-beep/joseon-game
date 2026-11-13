class_name Archery
extends Node
## 활 쏘기. 좌클릭을 누르고 있으면 시위를 당기고(만작까지 0.9초), 떼면 쏜다. 우클릭은 취소.
## 몸은 옆으로 서서 왼팔로 활을 밀고 오른팔로 당긴다(사법8절의 들어올리기·당기기·만작·발시·잔신을 줄였다).
## 화살은 중력에 휘어 날아가고, 짐승과 새, 땅, 바위, 나무에 맞으면 박힌다. 땅이나 몸에 박힌 화살은 일부 주울 수 있다.
## 당기는 시간, 속도, 힘, 흔들림은 모두 설계값이다 (근거는 docs/고증_근거.md 56장).

const DRAW_TIME := 0.9
const GRAV := 9.0
const MAX_FLIGHT := 5.0
const AIM_WALK := 1.6

var _player: Player
var _sv: Survival
var _gear: Gear
var _bow: Node3D
var _str_a: MeshInstance3D
var _str_b: MeshInstance3D
var _nock: Node3D
var _drawing := false
var _draw := 0.0
var _hold := 0.0
var _follow := 0.0
var _flying: Array[Dictionary] = []
var _layer: CanvasLayer
var _cross: Crosshair
var _slowed := false
var _walk0 := 5.0
var _sprint0 := 9.0
var _rng := RandomNumberGenerator.new()
static var _mats: Dictionary = {}


## 화면 가운데 조준 표시: 당길수록 원이 좁아진다
class Crosshair extends Control:
	var spread := 1.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := 7.0 + 26.0 * spread
		var paper := Color(0.98, 0.95, 0.86, 0.92)
		var ink := Color(0.1, 0.08, 0.07, 0.85)
		draw_arc(c, r, 0.0, TAU, 40, ink, 4.5, true)
		draw_arc(c, r, 0.0, TAU, 40, paper, 2.0, true)
		draw_circle(c, 3.2, ink)
		draw_circle(c, 2.0, paper)


func setup(player: Player, sv: Survival, gear: Gear) -> void:
	_player = player
	_sv = sv
	_gear = gear
	_rng.randomize()
	_walk0 = player.walk_speed
	_sprint0 = player.sprint_speed
	_layer = CanvasLayer.new()
	_layer.layer = 8
	_layer.visible = false
	add_child(_layer)
	_cross = Crosshair.new()
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_cross)


static func _mat(key: String, col: Color, rough := 0.9) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	_mats[key] = m
	return m


func _person() -> Variant:
	return _player.get("_person") if _player != null else null


# --- 활 모양 ---------------------------------------------------------------

## 왼손에 활을 쥐게 한다. 활은 가운데(줌통)가 바깥으로 불룩하고 양 끝이 사람 쪽으로 휜다. 길이 1.16m. [설계]
func build_bow() -> void:
	clear_bow()
	var pr: Variant = _person()
	if pr == null:
		return
	var hl: Node3D = pr.hand_l()
	if hl == null:
		return
	_bow = Node3D.new()
	_bow.rotation.x = -PI * 0.5   # 팔을 내렸을 때는 팔을 따라 세운다
	hl.add_child(_bow)
	var wood := _mat("bow_wood", Color(0.42, 0.28, 0.14), 0.8)
	var grip := _mat("bow_grip", Color(0.72, 0.62, 0.44), 0.95)
	var prev := Vector3(0.0, 0.15, -0.58)
	for i in range(1, 13):
		var t := float(i) / 12.0
		var z := lerpf(-0.58, 0.58, t)
		var y := 0.15 * pow(absf(z) / 0.58, 2.0)
		var pt := Vector3(0.0, y, z)
		var r := lerpf(0.011, 0.02, 1.0 - absf(z) / 0.58)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.radial_segments = 6
		mi.mesh = cm
		mi.material_override = wood
		_bow.add_child(mi)
		_place_seg(mi, prev, pt)
		prev = pt
	var gm := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.027
	gc.bottom_radius = 0.027
	gc.radial_segments = 8
	gm.mesh = gc
	gm.material_override = grip
	_bow.add_child(gm)
	_place_seg(gm, Vector3(0.0, 0.0, -0.07), Vector3(0.0, 0.0, 0.07))
	var string := _mat("bow_string", Color(0.86, 0.8, 0.64), 0.9)
	_str_a = _string_piece(string)
	_str_b = _string_piece(string)
	_set_string(Vector3(0.0, 0.15, 0.0))
	_nock = Gear.arrow_node()
	_nock.rotation.x = -PI * 0.5
	_nock.visible = false
	_bow.add_child(_nock)


func _string_piece(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0035
	cm.bottom_radius = 0.0035
	cm.radial_segments = 4
	mi.mesh = cm
	mi.material_override = mat
	_bow.add_child(mi)
	return mi


func _place_seg(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	(mi.mesh as CylinderMesh).height = l
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, d / l))


func _set_string(mid: Vector3) -> void:
	if _str_a == null or _str_b == null:
		return
	_place_seg(_str_a, Vector3(0.0, 0.15, -0.58), mid)
	_place_seg(_str_b, mid, Vector3(0.0, 0.15, 0.58))
	if _nock != null:
		_nock.position = mid


func clear_bow() -> void:
	_drawing = false
	_follow = 0.0
	_slow(false)
	var pr: Variant = _person()
	if pr != null:
		pr.aim = -1.0
	if _bow != null and is_instance_valid(_bow):
		_bow.queue_free()
	_bow = null
	_str_a = null
	_str_b = null
	_nock = null


func _slow(on: bool) -> void:
	if on and not _slowed:
		_walk0 = _player.walk_speed
		_sprint0 = _player.sprint_speed
		_player.walk_speed = AIM_WALK
		_player.sprint_speed = AIM_WALK
		_slowed = true
	elif not on and _slowed:
		_player.walk_speed = _walk0
		_player.sprint_speed = _sprint0
		_slowed = false


# --- 당기고 쏘기 -------------------------------------------------------------

func begin_draw() -> void:
	if _drawing or _bow == null or _player == null:
		return
	if _player.riding != null or _player.swimming or _player.input_locked:
		return
	if _gear.arrows <= 0:
		_sv._hud.toast("화살이 없다. 제작대에서 만들자.", 2.0, "deny")
		return
	_drawing = true
	_draw = 0.0
	_hold = 0.0
	_follow = 0.0
	_nock.visible = true
	_slow(true)
	UiSfx.play(self, "bow_creak", -14.0, randf_range(0.9, 1.05))


func cancel_draw() -> void:
	if not _drawing:
		return
	_drawing = false
	_slow(false)
	if _nock != null:
		_nock.visible = false
	var pr: Variant = _person()
	if pr != null:
		pr.aim = -1.0


func release_draw() -> void:
	if not _drawing:
		return
	if _draw < 0.25:
		cancel_draw()
		return
	_drawing = false
	_slow(false)
	_fire()
	if _nock != null:
		_nock.visible = false
	_follow = 0.5


func _fire() -> void:
	var cam: Camera3D = _player.get("_camera")
	if cam == null:
		return
	var origin := _player.global_position + Vector3(0.0, 1.45, 0.0)
	var fwd := -cam.global_transform.basis.z
	var target := cam.global_position + fwd * 70.0
	var dir := (target - origin).normalized()
	var spread := (1.0 - _draw) * 0.07 + clampf(_hold - 1.8, 0.0, 4.0) * 0.012
	if Vector2(_player.velocity.x, _player.velocity.z).length() > 0.5:
		spread += 0.02
	dir = (dir + Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * spread * 0.5).normalized()
	var start := origin + dir * 0.9
	var node := Gear.arrow_node()
	var host := _player.get_parent()
	host.add_child(node)
	node.global_position = start
	if absf(dir.y) < 0.99:
		node.look_at(start + dir, Vector3.UP)
	var speed := lerpf(16.0, 46.0, pow(_draw, 1.2))
	var dmg := 16.0 * (0.55 + 0.45 * _draw)
	_flying.append({"node": node, "pos": start, "vel": dir * speed, "t": 0.0, "dmg": dmg})
	_gear.arrows -= 1
	_gear._wear()
	_gear._update_hint()
	_gear.changed.emit()
	UiSfx.play(self, "bow_twang", -6.0, lerpf(0.9, 1.08, _draw))
	_player.add_shake(0.1)


# --- 화살 날기 ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var a: Dictionary = _flying[i]
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			_flying.remove_at(i)
			continue
		var p0: Vector3 = a["pos"]
		var v: Vector3 = a["vel"]
		v.y -= GRAV * delta
		var p1 := p0 + v * delta
		a["t"] = float(a["t"]) + delta
		var res := _hit_test(p0, p1)
		if res.is_empty():
			var ground := HanyangMap.surface(p1.x, p1.z)
			if p1.y <= ground:
				res = {"kind": "ground", "pos": Vector3(p1.x, ground, p1.z)}
		if not res.is_empty():
			_land(a, res, v.normalized())
			_flying.remove_at(i)
			continue
		a["pos"] = p1
		a["vel"] = v
		node.global_position = p1
		var vn := v.normalized()
		if absf(vn.y) < 0.99:
			node.look_at(p1 + vn, Vector3.UP)
		if float(a["t"]) > MAX_FLIGHT:
			node.queue_free()
			_flying.remove_at(i)


## p0 에서 p1 로 가는 동안 처음 맞는 것. 비어 있으면 아무것도 안 맞았다.
func _hit_test(p0: Vector3, p1: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	var seg := p1 - p0
	var l2 := maxf(seg.length_squared(), 0.0001)
	for grp in ["beast", "bird"]:
		for n in get_tree().get_nodes_in_group(grp):
			var nd := n as Node3D
			if nd == null or bool(nd.get("dead")):
				continue
			var c := Vector3.ZERO
			var rad := 0.5
			if nd.has_method("arrow_center"):
				c = nd.call("arrow_center")
				rad = float(nd.call("arrow_radius"))
			else:
				var bs := float(nd.call("body_size")) if nd.has_method("body_size") else 1.0
				c = nd.global_position + Vector3(0.0, 0.45 + 0.5 * bs, 0.0)
				rad = 0.35 + 0.45 * bs
			var t := clampf((c - p0).dot(seg) / l2, 0.0, 1.0)
			var q := p0 + seg * t
			if q.distance_to(c) <= rad:
				var d := p0.distance_to(q)
				if d < best_d:
					best_d = d
					best = {"kind": "bird" if grp == "bird" else "beast", "node": nd, "pos": q}
	var space := _player.get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(p0, p1)
	rq.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(rq)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		if p0.distance_to(hp) < best_d:
			best = {"kind": "static", "pos": hp}
	return best


func _land(a: Dictionary, res: Dictionary, dir: Vector3) -> void:
	var node: Node3D = a["node"]
	var pos: Vector3 = res["pos"]
	var kind := String(res["kind"])
	var dmg := float(a["dmg"])
	if kind == "beast":
		var b: Node3D = res["node"]
		b.call("take_hit", dmg, _player.global_position)
		_gear._burst(pos, Color(0.55, 0.04, 0.04), 8)
		UiSfx.play(self, "arrow_hit", -5.0, randf_range(0.9, 1.05))
		# 화살은 몸에 박힌 채 남는다
		var stuck := int(b.get_meta("stuck", 0))
		if stuck < 5:
			b.set_meta("stuck", stuck + 1)
			node.reparent(b, true)
			node.global_position = pos - dir * 0.7
		else:
			node.queue_free()
		if bool(b.get("dead")) and _rng.randf() < 0.5:
			_sv.add_arrow_pick(Vector3(b.global_position.x, HanyangMap.surface(b.global_position.x, b.global_position.z) + 0.05, b.global_position.z) + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5)), Vector3(_rng.randf_range(-1.0, 1.0), -0.2, _rng.randf_range(-1.0, 1.0)))
		return
	if kind == "bird":
		var bd: Node3D = res["node"]
		bd.call("arrow_hit", pos, dir)
		_gear._burst(pos, Color(0.6, 0.1, 0.08), 5)
		UiSfx.play(self, "arrow_hit", -8.0, randf_range(1.05, 1.2))
		node.queue_free()
		if _rng.randf() < 0.5:
			var gp := Vector3(pos.x, HanyangMap.surface(pos.x, pos.z) + 0.05, pos.z)
			_sv.add_arrow_pick(gp, dir)
		return
	# 땅, 바위, 나무, 담에 박힌다
	UiSfx.play(self, "arrow_hit", -12.0, randf_range(0.8, 0.95))
	node.queue_free()
	if _rng.randf() < 0.85:
		_sv.add_arrow_pick(pos - dir * 0.55, dir)


# --- 화면 ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _player == null:
		return
	var has_bow := _bow != null and is_instance_valid(_bow)
	_layer.visible = has_bow
	if not has_bow:
		return
	var pr: Variant = _person()
	if pr == null:
		return
	if _drawing and (_player.input_locked or _player.riding != null or _player.swimming or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		cancel_draw()
	if _drawing:
		_draw = minf(_draw + delta / DRAW_TIME, 1.0)
		if _draw >= 1.0:
			_hold += delta
			if _hold > 2.0:
				_player.add_shake(0.02)   # 오래 당기면 팔이 떨린다
		pr.aim = _draw
		var m: Node3D = _player.get("_model")
		if m != null:
			m.rotation.y = lerp_angle(m.rotation.y, _player._yaw, clampf(14.0 * delta, 0.0, 1.0))
	elif _follow > 0.0:
		_follow -= delta
		pr.aim = 0.55 if _follow > 0.15 else -1.0   # 잔신: 쏜 뒤에도 잠깐 자세를 지킨다
		var m2: Node3D = _player.get("_model")
		if m2 != null:
			m2.rotation.y = lerp_angle(m2.rotation.y, _player._yaw, clampf(10.0 * delta, 0.0, 1.0))
	var a: float = float(pr.aim)
	_bow.rotation.x = lerpf(-PI * 0.5, 0.0, clampf(a * 4.0, 0.0, 1.0) if a >= 0.0 else 0.0)
	if _drawing:
		var rh: Node3D = pr.hand()
		if rh != null:
			var pull := _bow.to_local(rh.global_position)
			pull.x = 0.0
			pull.y = clampf(pull.y, 0.15, 0.75)
			pull.z = clampf(pull.z, -0.08, 0.08)
			_set_string(pull)
	else:
		_set_string(Vector3(0.0, 0.15, 0.0))
	_cross.spread = 1.0 - (_draw if _drawing else 0.0) * 0.8
