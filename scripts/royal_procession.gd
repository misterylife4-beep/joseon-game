class_name RoyalProcession
extends Node3D
## 왕 행차(거둥): 광화문을 나선 어가가 육조거리와 운종가를 지나 종묘로 간다.
## - 행렬이 지나는 동안 한양의 모든 사람(군졸·관원 포함, 예외 없음)이 길가에 엎드려 절한다.
## - 플레이어는 Z 키를 누르고 있는 동안 엎드린다. 어가가 가까이 왔는데 일어서 있으면 포졸에게 붙들려 끌려간다.
## 행차 길·행렬 구성·거리와 시간 수치는 설계값이다. (고증_근거.md 43장)

const SPEED := 3.6          ## 행렬이 가는 속도(m/s). 실제 거둥은 훨씬 느렸으나 게임 진행에 맞춰 줄였다.
const BOW_R := 70.0         ## 어가에서 이 거리 안의 사람은 엎드린다
const BOW_OUT := 85.0       ## 이 거리 밖으로 벗어나야 일어선다 (자주 오르내리지 않도록)
const WARN_R := 75.0
const ARREST_R := 30.0
const GRACE := 2.5          ## 일어서 있는 채로 이만큼 지나면 붙잡힌다
const KING_OFF := 18.0      ## 행렬 맨 앞에서 가마까지의 거리
const START_HOUR := 12.0   ## 오시(午時) 정각 (11~13시). 12시에 매일 출발한다

enum S { IDLE, RUN, ARREST, END }

var _player: Player
var _sv: Survival
var _hud: SurvivalHud
var _state := S.IDLE
var _path: Array[Vector2] = []
var _dirs: Array[Vector2] = []
var _cum: Array[float] = []
var _len := 0.0
var _head := 0.0
var _members: Array[Dictionary] = []
var _busy: Dictionary = {}
var _bowed: Dictionary = {}
var _king_p := Vector2.ZERO
var _bow_t := 0.0
var _music: AudioStreamPlayer
var _warn_t := 0.0
var _unbow := 0.0
var _last_day := -1
var _end_t := 0.0
var _guards: Array[Person] = []
var _guard_run := false
var _drag := false
var _drag_dir := Vector2.ZERO
var _fade: ColorRect
var _fade_label: Label
var _moving := false


func setup(player: Player, sv: Survival, hud: SurvivalHud) -> void:
	_player = player
	_sv = sv
	_hud = hud
	UiSfx.stream.call_deferred("chwita")  # 합성에 1~2초 걸려 미리 만들어 둔다
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade_label = Label.new()
	_fade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fade_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_fade_label.add_theme_font_override("font", JoseonUI.title_font())
	_fade_label.add_theme_font_size_override("font_size", 34)
	_fade_label.add_theme_color_override("font_color", JoseonUI.PAPER)
	_fade_label.add_theme_color_override("font_outline_color", JoseonUI.PAPER)
	_fade_label.add_theme_constant_override("outline_size", 2)
	_fade_label.modulate.a = 0.0
	_fade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_label)


func _unhandled_input(event: InputEvent) -> void:
	# 시험용: F8 로 바로 행차를 시작한다
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		if _state == S.IDLE and _player != null:
			_start()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	match _state:
		S.IDLE:
			_check_start()
		S.RUN:
			_head += SPEED * delta
			_after_move(delta)
			_watch_player(delta)
			if _head - KING_OFF >= _len:
				_state = S.END
				_end_t = 3.5
				_set_moving(false)
		S.ARREST:
			_after_move(delta)
			_arrest_motion(delta)
		S.END:
			_after_move(delta)
			_end_t -= delta
			if _end_t <= 0.0:
				_dismiss(true)


# --- 시작 ---

func _check_start() -> void:
	var day := DayNight.day_now
	if day == _last_day or DayNight.hour_now < START_HOUR or DayNight.hour_now > START_HOUR + 0.7:
		return
	_last_day = day
	# 매일 오시(12시)에 출발한다. 도성 안에 있을 때만 일어난다.
	if _player.input_locked or _player.swimming or _player.riding != null:
		return
	if HanyangMap.u_of(_player.global_position.x, _player.global_position.z) > 0.95:
		return
	_start()


func _start() -> void:
	var h := HanyangMap.HWANGTOHYEON
	var e := HanyangMap.gate_pos("흥인지문")
	var tx := clampf((100.0 - h.x) / (e.x - h.x), 0.0, 1.0)
	_path = [
		HanyangMap.GWANGHWAMUN,
		h,
		h.lerp(e, 0.3) + Vector2(0.0, -3.0),
		h.lerp(e, tx),
		Vector2(100.0, -42.0),
	]
	_dirs.clear()
	_cum.clear()
	_cum.append(0.0)
	for i in range(1, _path.size()):
		var seg := _path[i] - _path[i - 1]
		_dirs.append(seg.normalized())
		_cum.append(_cum[i - 1] + seg.length())
	_len = _cum.back()
	_head = 0.0
	_members.clear()
	_busy.clear()
	_build_formation()
	_after_move(0.0, true)
	_state = S.RUN
	_unbow = 0.0
	_warn_t = 0.0
	_music = null
	_set_moving(true)
	_hud.toast("취타 소리가 울린다. 어가 행차다! 길가에 엎드려라.  [ Z 키를 누르고 있기 ]", 5.0)


## 행렬: 앞에 군졸, 오방기, 가마(왕과 가마꾼), 뒤따르는 호위 군졸. 구성과 수는 설계값이다.
func _build_formation() -> void:
	for k in 2:
		var lat := -2.0 if k == 0 else 2.0
		_add_person(Person.Kind.SOLDIER, 0.0, lat, 1, true)
		_add_person(Person.Kind.SOLDIER, 3.0, lat, 2, true)
	var flag_cols: Array[Color] = [Color(0.18, 0.32, 0.55), Color(0.72, 0.16, 0.12), Color(0.86, 0.68, 0.16), Color(0.88, 0.86, 0.78)]
	for k in 4:
		var lat2 := -3.0 if k % 2 == 0 else 3.0
		var off := 7.0 if k < 2 else 11.0
		_add_person(Person.Kind.SOLDIER, off, lat2, k, false)
		_add_banner(off, lat2 + (0.5 if lat2 > 0.0 else -0.5), flag_cols[k])
	_add_litter()
	for k in 4:
		var lat3 := -1.25 if k % 2 == 0 else 1.25
		var off3 := KING_OFF - 1.8 if k < 2 else KING_OFF + 1.8
		_add_person(Person.Kind.PORTER, off3, lat3, k, false)
	var king := _add_person(Person.Kind.KING, KING_OFF, 0.0, 0, false, 1.05, Person.Act.SIT)
	king.set_locomotion(0.0, true)
	for k in 6:
		var lat4 := -2.2 if k % 2 == 0 else 2.2
		_add_person(Person.Kind.SOLDIER, 27.0 + float(k / 2) * 3.0, lat4, k, false)


func _add_person(kind: int, off: float, lat: float, v: int, lead: bool, y := 0.0, act := Person.Act.LOCO) -> Person:
	var p := Person.new().setup(kind, act, Vector3.ZERO, 0.0, v)
	add_child(p)
	_members.append({"n": p, "off": off, "lat": lat, "y": y, "lead": lead, "person": true, "loco": act == Person.Act.LOCO})
	return p


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)


func _add_banner(off: float, lat: float, col: Color) -> void:
	var n := Node3D.new()
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.045
	cm.height = 3.6
	pole.mesh = cm
	pole.material_override = _mat(Color(0.28, 0.18, 0.1))
	pole.position.y = 1.8
	n.add_child(pole)
	_box(n, Vector3(0.04, 1.2, 0.9), Vector3(0.0, 3.0, 0.5), col)
	add_child(n)
	_members.append({"n": n, "off": off, "lat": lat, "y": 0.0, "lead": false, "person": false, "loco": false})


func _add_litter() -> void:
	var n := Node3D.new()
	var wood := Color(0.3, 0.19, 0.1)
	var red := Color(0.62, 0.14, 0.1)
	_box(n, Vector3(2.0, 0.14, 2.2), Vector3(0.0, 0.95, 0.0), wood)
	for sx in [-0.95, 0.95]:
		for sz in [-1.0, 1.0]:
			_box(n, Vector3(0.1, 1.8, 0.1), Vector3(sx, 1.9, sz), red)
	_box(n, Vector3(2.6, 0.14, 2.8), Vector3(0.0, 2.85, 0.0), red)
	_box(n, Vector3(2.8, 0.06, 3.0), Vector3(0.0, 2.95, 0.0), Color(0.8, 0.62, 0.2))
	for sx in [-1.25, 1.25]:
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 4.4
		pole.mesh = cm
		pole.material_override = _mat(wood)
		pole.rotation.x = PI / 2.0
		pole.position = Vector3(sx, 1.0, 0.0)
		n.add_child(pole)
	add_child(n)
	_members.append({"n": n, "off": KING_OFF, "lat": 0.0, "y": 0.0, "lead": false, "person": false, "loco": false})


# --- 길 위의 위치 ---

func _seg(s: float) -> int:
	for i in range(1, _path.size()):
		if s <= _cum[i]:
			return i - 1
	return _path.size() - 2


func _at(s: float) -> Vector2:
	if s <= 0.0:
		return _path[0] + _dirs[0] * s
	if s >= _len:
		return _path.back() + _dirs.back() * (s - _len)
	var i := _seg(s)
	var seg := _cum[i + 1] - _cum[i]
	return _path[i].lerp(_path[i + 1], (s - _cum[i]) / maxf(seg, 0.01))


func _tan_at(s: float) -> Vector2:
	if s <= 0.0:
		return _dirs[0]
	if s >= _len:
		return _dirs.back()
	return _dirs[_seg(s)]


func _set_moving(on: bool) -> void:
	_moving = on
	for m in _members:
		if m["loco"]:
			(m["n"] as Person).set_locomotion(SPEED if on else 0.0, true)


## 행렬 배치, 엎드리기 갱신, 북과 징 소리.
func _after_move(delta: float, snap := false) -> void:
	for m in _members:
		var n: Node3D = m["n"]
		if _busy.has(n):
			continue
		var s: float = _head - float(m["off"])
		var tg := _tan_at(s)
		var side := Vector2(-tg.y, tg.x)
		var c := _at(s) + side * float(m["lat"])
		n.position = Vector3(c.x, HanyangMap.stand(c.x, c.y, true) + float(m["y"]), c.y)
		var want := atan2(tg.x, tg.y)
		n.rotation.y = want if snap else lerp_angle(n.rotation.y, want, minf(delta * 5.0, 1.0))
	_king_p = _at(_head - KING_OFF)
	if snap:
		return
	_bow_t -= delta
	if _bow_t <= 0.0:
		_bow_t = 0.5
		_update_bowers()
	_face_king(delta)
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var d := pp.distance_to(_king_p)
	# 대취타: 행렬이 가까우면 들리고 멀어지면 작아진다. 한 곡이 끝나면 처음부터 다시 연주한다.
	var vol := -6.0 - clampf((d - 15.0) * 0.25, 0.0, 34.0)
	if _music != null and is_instance_valid(_music):
		_music.volume_db = -80.0 if _state == S.ARREST else vol
	elif _state == S.RUN and d < 190.0:
		_music = UiSfx.play(self, "chwita", vol, 1.0)


func _is_member(p: Node) -> bool:
	for m in _members:
		if m["n"] == p:
			return true
	return false


## 어가에서 가까운 사람은 모두 엎드린다. 하던 일이 무엇이든, 신분이 무엇이든 예외가 없다.
func _update_bowers() -> void:
	for n in get_tree().get_nodes_in_group("person"):
		var p := n as Person
		if p == null or p.kind == Person.Kind.PROTAGONIST or _is_member(p):
			continue
		var q := Vector2(p.global_position.x, p.global_position.z)
		var d := q.distance_to(_king_p)
		if d < BOW_R:
			p.prostrate = true
			_bowed[p] = true
		elif d > BOW_OUT and _bowed.has(p):
			p.prostrate = false
			_bowed.erase(p)


func _face_king(delta: float) -> void:
	for k in _bowed.keys():
		var p := k as Person
		if p == null or not is_instance_valid(p):
			_bowed.erase(k)
			continue
		var to := _king_p - Vector2(p.global_position.x, p.global_position.z)
		if to.length() > 4.0:
			p.rotation.y = lerp_angle(p.rotation.y, atan2(to.x, to.y), minf(delta * 3.0, 1.0))


# --- 플레이어 ---

func _watch_player(delta: float) -> void:
	if _player.input_locked:
		return
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var d := pp.distance_to(_king_p)
	_warn_t -= delta
	if d < WARN_R and not _player.bowing and _warn_t <= 0.0:
		_warn_t = 7.0
		_hud.toast("어가가 온다! Z 키를 누르고 있으면 엎드려 절한다.", 3.0)
	var near := d < ARREST_R and not _player.bowing and not _player.swimming and _player.riding == null
	if near:
		_unbow += delta
		if _unbow >= GRACE:
			_arrest()
	else:
		_unbow = maxf(_unbow - delta * 2.0, 0.0)


# --- 연행 ---

func _arrest() -> void:
	if _state == S.ARREST:
		return
	_state = S.ARREST
	_set_moving(false)
	_player.input_locked = true
	_player.arrested = true
	_hud.toast("무엄하다! 어가 앞에서 감히 고개를 들다니!", 3.5)
	UiSfx.play(self, "gong", -2.0, 0.85)
	UiSfx.play(self, "drum", -3.0, 0.8)
	# 맨 앞 군졸 둘이 달려온다
	_guards.clear()
	for m in _members:
		if m["lead"] and _guards.size() < 2:
			_guards.append(m["n"] as Person)
			_busy[m["n"]] = true
	_guard_run = true
	var t := 0.0
	while t < 7.0 and _guard_run:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_guard_run = false
	for g in _guards:
		g.set_locomotion(0.0, true)
	UiSfx.play(self, "stamp", -4.0, 0.9)
	_hud.toast("포졸들이 양팔을 낚아채 끌고 간다.", 3.0)
	await get_tree().create_timer(1.1).timeout
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	_drag_dir = (HanyangMap.GWANGHWAMUN - pp).normalized()
	_drag = true
	for g in _guards:
		g.set_locomotion(2.4, true)
	await get_tree().create_timer(1.2).timeout
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.1)
	await tw.finished
	_drag = false
	_fade_label.text = "의금부 옥에 갇혀 하룻밤을 보냈다."
	var tl := create_tween()
	tl.tween_property(_fade_label, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(3.2).timeout
	# 풀려난 곳은 광화문 앞. 불경죄의 대가로 곤장을 맞고 굶주렸다 (수치는 설계값).
	var out := HanyangMap.GWANGHWAMUN + Vector2(10.0, 16.0)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(out.x, HanyangMap.stand(out.x, out.y, true) + 1.0, out.y)
	Records.family_risk += 1
	_sv.hurt(15.0)
	_sv.hunger = maxf(_sv.hunger - 20.0, 0.0)
	_dismiss(false)
	var tb := create_tween()
	tb.set_parallel(true)
	tb.tween_property(_fade_label, "modulate:a", 0.0, 0.8)
	tb.tween_property(_fade, "color:a", 0.0, 1.4).set_delay(0.4)
	await tb.finished
	_player.arrested = false
	_player.input_locked = false
	_hud.toast("곤장을 맞고 풀려났다. 가문에 화가 미칠까 두렵다.  (가문 위험도 +1)", 4.5)


func _arrest_motion(delta: float) -> void:
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	if _guard_run:
		var arrived := 0
		for i in _guards.size():
			var g := _guards[i]
			var side := -1.0 if i == 0 else 1.0
			var to := pp + Vector2(side * 0.9, 0.0) - Vector2(g.position.x, g.position.z)
			if to.length() > 0.6:
				var step := to.normalized() * 8.0 * delta
				g.position.x += step.x
				g.position.z += step.y
				g.position.y = HanyangMap.stand(g.position.x, g.position.z, true)
				g.rotation.y = lerp_angle(g.rotation.y, atan2(to.x, to.y), minf(delta * 10.0, 1.0))
				g.set_locomotion(8.0, true)
			else:
				arrived += 1
		if arrived >= _guards.size():
			_guard_run = false
	elif _drag:
		var mv := _drag_dir * 2.4 * delta
		_player.global_position += Vector3(mv.x, 0.0, mv.y)
		for i in _guards.size():
			var g := _guards[i]
			var side := -1.0 if i == 0 else 1.0
			var perp := Vector2(-_drag_dir.y, _drag_dir.x)
			var c := Vector2(_player.global_position.x, _player.global_position.z) + perp * side * 0.9
			g.position = Vector3(c.x, HanyangMap.stand(c.x, c.y, true), c.y)
			g.rotation.y = atan2(_drag_dir.x, _drag_dir.y)
		_player.face_toward(_drag_dir)


# --- 끝 ---

## 행렬을 거두고 엎드린 사람들을 일으킨다.
func _dismiss(show_toast: bool) -> void:
	for k in _bowed.keys():
		var p := k as Person
		if p != null and is_instance_valid(p):
			p.prostrate = false
	_bowed.clear()
	for m in _members:
		var n: Node3D = m["n"]
		if is_instance_valid(n):
			n.queue_free()
	_members.clear()
	_busy.clear()
	_guards.clear()
	_guard_run = false
	_state = S.IDLE
	if show_toast:
		_hud.toast("어가가 종묘로 드셨다. 길이 다시 열렸다.", 3.5)
