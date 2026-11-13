class_name Tiger
extends Node3D
## 호랑이 한 마리. 위험도 2 이상 땅에서만 움직인다 (마을·들길 앞에서 멈춘다).
## 몸을 낮춰 맴돌며 노려보다(으르렁) 우뚝 서서 포효하고(TELL) 달려와(CHARGE) 앞발을 뻗어 덮친다(LEAP).
## 덮치면 플레이어는 뒤로 넘어지고 화면에 발톱 자국이 그어지며, 호랑이는 잠깐 누른 채 문 뒤(PIN) 물러난다.
## 두 번 덮치면 떠난다. 불 곁에 있거나 마을로 들어가면 가까이 오지 않고 떠난다.
## 근거(docs/고증_근거.md 20장·47장): 조선의 호환과 고개마다 사람을 모아 보냈다는 점은 사료다.
## 몸 크기, 속도, 물림 피해, 행동 순서와 연출은 모두 설계값이다.

signal gone
signal bitten

enum S { STALK, TELL, CHARGE, LEAP, PIN, RETREAT, FLEE }

const BITE_DAMAGE := 24.0
const STALK_SPEED := 3.2
const CHARGE_SPEED := 9.0
const FLEE_SPEED := 7.0

var _player: Player
var _survival: Survival
var _rig: BeastRig
var _state := S.STALK
var _state_t := 0.0
var _stalk_len := 11.0
var _life := 0.0
var _bite_cd := 0.0
var _bites := 0
var _max_bites := 2
var _blocked := 0.0
var _orbit := 1.0
var _heading := Vector2(0.0, 1.0)
var _voice: AudioStreamPlayer3D
var _foot: AudioStreamPlayer3D
var _rustle: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _moved := 0.0
var _spd := 0.0
var _growl_cd := 3.0
var _rustle_cd := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_t := 0.0
var _track_toggle := false
## 싸움: 체력과 죽음. 한 번이라도 덮치기 시작했거나 맞았으면 두 번 물기 전에는 달아나지 않는다.
var hp := 150.0
var dead := false
var _engaged := false
var hp_max := 150.0
var _stun := 0.0
var _kb := Vector2.ZERO
var _dodge_cd := 0.0
var _scale0 := Vector3.ZERO
var _hit_tw: Tween
const BODY := 2.0   ## 몸 크기(칼이 닿는 거리에 더한다)


func setup(player: Player, survival: Survival, start: Vector2) -> void:
	_player = player
	_survival = survival
	_rng.randomize()
	_max_bites = _rng.randi_range(2, 3)
	_orbit = 1.0 if _rng.randf() < 0.5 else -1.0
	_stalk_len = _rng.randf_range(10.0, 15.0)
	position = Vector3(start.x, HanyangMap.surface(start.x, start.y), start.y)
	var to_p := Vector2(_player.global_position.x - start.x, _player.global_position.z - start.y)
	if to_p.length() > 0.1:
		_heading = to_p.normalized()
	rotation.y = atan2(_heading.x, _heading.y)


func _ready() -> void:
	add_to_group("predator")
	add_to_group("beast")
	_rig = BeastRig.make(int(BeastRig.Kind.TIGER), 0, false)
	add_child(_rig)
	_rig.stepped.connect(_on_step)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 14.0
	_voice.max_distance = 140.0
	_voice.position.y = 1.0
	add_child(_voice)
	_foot = AudioStreamPlayer3D.new()
	_foot.unit_size = 6.0
	_foot.max_distance = 50.0
	add_child(_foot)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.stream = BeastSfx.stream("rustle")
	_rustle.unit_size = 5.0
	_rustle.max_distance = 40.0
	_rustle.volume_db = -10.0
	add_child(_rustle)
	_say("tiger_growl", 4.0)


## 노리며 다가오는 중인가 (심장 박동 효과가 본다)
func body_size() -> float:
	return BODY


func hunting() -> bool:
	return _state in [S.STALK, S.TELL, S.CHARGE, S.LEAP]


func _say(sname: String, db := 4.0, pitch := 1.0) -> void:
	_voice.stream = BeastSfx.stream(sname)
	_voice.volume_db = db
	_voice.pitch_scale = pitch
	_voice.play()


func _on_step(leg: int) -> void:
	_foot.stream = BeastSfx.stream("step_tiger")
	_foot.volume_db = -6.0 + clampf((_spd - 3.0) * 0.9, 0.0, 6.0)
	_foot.pitch_scale = _rng.randf_range(0.92, 1.08)
	_foot.play()
	if leg < 2:
		_track_toggle = not _track_toggle
		if _track_toggle and BeastFx.inst != null:
			BeastFx.inst.add_track(3, Vector3(global_position.x, HanyangMap.surface(global_position.x, global_position.z), global_position.z), rotation.y)
	if _spd > 4.0 and _rustle_cd <= 0.0:
		_rustle_cd = 0.4
		_rustle.pitch_scale = _rng.randf_range(0.85, 1.1)
		_rustle.play()


# --- 행동 ---

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _can_stand(p: Vector2) -> bool:
	return Region.danger_at(p.x, p.y) >= 2


func _step(dir: Vector2, speed_in: float, delta: float) -> bool:
	var speed := speed_in * _speed_mul()
	var here := _flat(position)
	var nxt := here + dir * speed * delta
	if not _can_stand(nxt):
		return false
	position = Vector3(nxt.x, HanyangMap.surface(nxt.x, nxt.y) + 0.02, nxt.y)
	_moved += speed * delta
	return true


## 덮치기 시작했고 아직 두 번 물지 못했으면 달아나지 않는다 (마을로 들어선 때는 예외).
func _locked(safe_player := false) -> bool:
	return _engaged and _bites < 2 and not safe_player and not dead


## 칼·도끼를 맞았을 때. 호랑이는 덩치가 커서 거의 밀리지 않고 움찔만 하며, 맞을수록 더 사납게 다시 덮친다.
## 위협(으르렁) → 짧은 돌진 → 포효로 이어지다가 몰리면 앞발로 후려친다 (docs/고증_근거.md 52장).
func take_hit(dmg: float, from: Vector3) -> void:
	if dead:
		return
	hp -= dmg
	_engaged = true
	var away := _flat(position) - Vector2(from.x, from.z)
	away = away.normalized() if away.length() > 0.01 else Vector2.from_angle(randf() * TAU)
	_kb = away * clampf(dmg * 0.4 / 3.5, 0.6, 2.5)
	_stun = clampf(0.1 + dmg * 0.006 / 3.5, 0.1, 0.22)
	_squash()
	HitReact.react(self, _rig, from, dmg, 3.2)
	_say("tiger_roar" if hp > 0.0 else "tiger_huff", 6.0 + clampf(dmg * 0.1, 0.0, 3.0), clampf(1.0 - dmg * 0.006, 0.85, 1.0))
	if hp <= 0.0:
		_die()
	elif _state in [S.STALK, S.RETREAT, S.FLEE]:
		_set_state(S.TELL)


## 맞으면 튀는 털 조각 색
func fur_color() -> Color:
	return Color(0.82, 0.46, 0.14)


func _squash() -> void:
	if _rig == null:
		return
	if _scale0 == Vector3.ZERO:
		_scale0 = _rig.scale
	if _hit_tw != null and _hit_tw.is_valid():
		_hit_tw.kill()
	_rig.scale = _scale0
	_hit_tw = create_tween()
	_hit_tw.tween_property(_rig, "scale", _scale0 * Vector3(1.05, 0.94, 1.05), 0.05)
	_hit_tw.tween_property(_rig, "scale", _scale0, 0.14)


func _apply_kb(delta: float) -> void:
	if _kb.length() < 0.05:
		return
	var nxt := _flat(position) + _kb * delta
	if _can_stand(nxt):
		position = Vector3(nxt.x, HanyangMap.surface(nxt.x, nxt.y) + 0.02, nxt.y)
	_kb = _kb.move_toward(Vector2.ZERO, 14.0 * delta)


## 호랑이는 가끔(20%) 휘두르는 순간 옆으로 비킨다
func _try_dodge(dist: float, dir: Vector2) -> void:
	if _dodge_cd > 0.0 or _state in [S.LEAP, S.FLEE, S.PIN]:
		return
	if Time.get_ticks_msec() - Gear.swing_start_ms > 260 or dist > Gear.REACH + BODY + 0.6:
		return
	_dodge_cd = 2.0
	if _rng.randf() < 0.2:
		_kb = Vector2(-dir.y, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0) * 5.0


## 다친 호랑이는(체력 30% 아래) 절룩인다
func _speed_mul() -> float:
	return 0.8 if hp < hp_max * 0.3 else 1.0


func _die() -> void:
	dead = true
	remove_from_group("beast")
	remove_from_group("predator")
	_set_state(S.PIN)
	set_process(false)
	gone.emit()
	if _rig != null:
		var h := 1.0 * _rig.scale.x
		var tw := create_tween()
		tw.tween_property(_rig, "rotation:z", PI * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_rig, "position", Vector3(h * 0.9, 0.35, 0.0), 0.55)
	if _survival != null:
		_survival.add_drops(global_position, "meat_tiger", 6, "hide_tiger", 3.2)
		_survival.drop_notice("호랑이")
		_survival.reward_kill(25.0)
	get_tree().create_timer(150.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _set_state(s: S) -> void:
	if s in [S.TELL, S.CHARGE, S.LEAP]:
		_engaged = true
	_state = s
	_state_t = 0.0
	_blocked = 0.0


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	_life += delta
	_state_t += delta
	_bite_cd = maxf(_bite_cd - delta, 0.0)
	_growl_cd = maxf(_growl_cd - delta, 0.0)
	_rustle_cd = maxf(_rustle_cd - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)

	var me := _flat(position)
	var pp := _flat(_player.global_position)
	var to_p := pp - me
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var safe_player := Region.danger_at(pp.x, pp.y) <= 1
	var fire := _survival != null and _survival.near_fire()

	_apply_kb(delta)
	if _stun > 0.0:
		_stun -= delta
		_animate(delta)
		return
	_try_dodge(dist, dir)

	# 마을·들길로 들어서거나 오래 끌면 떠난다
	if _state != S.FLEE and (safe_player or ((_life > 80.0 and not fire) or _life > 420.0) and not _locked()):
		_set_state(S.FLEE)

	match _state:
		S.STALK:
			var want := dir
			if dist < 20.0:
				want = -dir
			var side := Vector2(-dir.y, dir.x) * _orbit
			var v := side * 1.3
			if dist > 27.0 or dist < 20.0:
				v += want * STALK_SPEED
			_step(v.normalized() if v.length() > 0.01 else dir, minf(v.length(), STALK_SPEED), delta)
			_face(dir if dist > 0.5 else _heading, delta, 3.0)
			if _growl_cd <= 0.0 and dist < 40.0:
				_growl_cd = _rng.randf_range(3.5, 6.0) if fire else _rng.randf_range(6.0, 10.0)
				_say("tiger_growl", 2.0)
			if fire:
				pass   # 불이 있으면 가까이 오지 않고, 달아나지도 않고 계속 둘레를 돌며 노려본다
			elif _state_t > _stalk_len:
				_set_state(S.TELL)
		S.TELL:
			# 우뚝 서서 포효한다: 입을 크게 벌리고 귀를 젖히고 화면이 살짝 흔들린다
			_face(dir, delta, 6.0)
			if _state_t < 0.05:
				_say("tiger_roar", 8.0)
				_player.add_shake(0.45)
			elif _state_t > 0.5 and _state_t < 0.56:
				_player.add_shake(0.3)
			if fire and dist < 12.0 and not _locked():
				_set_state(S.STALK)
			elif _state_t > (0.9 if hp < hp_max else 1.7):
				_set_state(S.CHARGE)
		S.CHARGE:
			if dist > 7.0:
				if _step(dir, CHARGE_SPEED, delta):
					_blocked = 0.0
				else:
					_blocked += delta
					if _blocked > 1.6 and not _locked():
						_set_state(S.FLEE)
			elif dist < 3.6 and _bite_cd <= 0.0:
				_swipe(dir)       # 코앞이면 뛰어오르지 않고 앞발로 후려친다
			else:
				_start_leap(pp)
			_face(dir, delta, 8.0)
			if fire and dist < 12.0 and not _locked():
				_set_state(S.STALK)
		S.LEAP:
			_leap_t += delta / 0.55
			var k := clampf(_leap_t, 0.0, 1.0)
			var p := _leap_from.lerp(_leap_to, k)
			p.y += sin(k * PI) * 1.2
			position = p
			if _leap_t >= 1.0:
				_land(dir)
		S.PIN:
			# 넘어뜨린 사람을 앞발로 누르고 문다
			_face(dir, delta, 4.0)
			if _state_t > 1.1:
				if _bites >= _max_bites:
					_set_state(S.FLEE)
				else:
					_set_state(S.RETREAT)
		S.RETREAT:
			_step(-dir, 4.5, delta)
			_face(dir, delta, 5.0)
			if _state_t > (0.8 if hp < hp_max else 1.5):
				_set_state(S.TELL)     # 멀리 달아나지 않고 곧 다시 덮친다
		S.FLEE:
			_step(-dir, FLEE_SPEED, delta)
			_face(-dir, delta, 6.0)
			if _state_t > 7.0 or dist > 70.0:
				gone.emit()
				queue_free()
				return
	_animate(delta)


## 바짝 붙은 사람을 앞발로 후려친다 (할퀴는 힘 15). 사람은 비틀거리지만 넘어지지는 않는다.
func _swipe(dir: Vector2) -> void:
	_bites += 1
	_bite_cd = 1.4
	_survival.hurt(15.0, "호랑이 발톱에 할퀴었다!")
	_player.stagger(Vector3(dir.x, 0.0, dir.y), 4.5, 0.4, false)
	if BeastFx.inst != null:
		BeastFx.inst.hit(15.0, "claw")
	_say("tiger_roar", 6.0)
	_set_state(S.RETREAT)


func _start_leap(pp: Vector2) -> void:
	_leap_from = position
	var me := _flat(position)
	var d := (pp - me).normalized()
	var end := pp - d * 1.8
	_leap_to = Vector3(end.x, HanyangMap.surface(end.x, end.y), end.y)
	_leap_t = 0.0
	_set_state(S.LEAP)


## 도약이 끝났다: 사람이 아직 앞발이 닿는 곳에 있으면 덮친다.
func _land(dir: Vector2) -> void:
	var pp := _flat(_player.global_position)
	if _flat(position).distance_to(pp) < 4.6 and _bite_cd <= 0.0:
		_bites += 1
		_bite_cd = 1.8
		if _survival != null:
			_survival.hurt(BITE_DAMAGE, "호랑이에게 덮쳐 물렸다!")
		_player.stagger(Vector3(dir.x, 0.0, dir.y), 6.5, 1.7, true)
		if BeastFx.inst != null:
			BeastFx.inst.hit(BITE_DAMAGE, "claw")
		bitten.emit()
		_say("tiger_roar", 8.0)
		_set_state(S.PIN)
	else:
		_set_state(S.RETREAT)


func _animate(delta: float) -> void:
	var spd := _moved / maxf(delta, 0.001)
	_moved = 0.0
	_spd = lerpf(_spd, spd, clampf(delta * 8.0, 0.0, 1.0))
	var r := _rig
	var crouch := 0.0
	var head_down := 0.0
	var jaw := 0.0
	var ear_back := 0.0
	var lunge := 0.0
	var tail_up := 0.0
	match _state:
		S.STALK:
			crouch = 0.4
			head_down = 0.35
			ear_back = 0.4
		S.TELL:
			crouch = 0.15
			head_down = -0.15
			jaw = 1.0
			ear_back = 1.0
			tail_up = 0.5
		S.CHARGE:
			head_down = 0.2
			ear_back = 0.9
		S.LEAP:
			lunge = 1.0
			jaw = 1.0
			ear_back = 1.0
		S.PIN:
			crouch = 0.55
			head_down = 0.3
			jaw = 0.5 + 0.5 * sin(_state_t * 14.0)
			ear_back = 0.9
		S.RETREAT:
			crouch = 0.2
			ear_back = 0.5
		S.FLEE:
			ear_back = 0.4
	if hp < hp_max * 0.3 and not dead:
		crouch = maxf(crouch, 0.25)
		head_down += 0.2
	if _stun > 0.0:
		crouch = maxf(crouch, 0.4)
		head_down = -0.4
		ear_back = 1.0
		jaw = 0.8
	r.crouch = lerpf(r.crouch, crouch, clampf(delta * 5.0, 0.0, 1.0))
	r.head_down = lerpf(r.head_down, head_down, clampf(delta * 5.0, 0.0, 1.0))
	r.jaw = lerpf(r.jaw, jaw, clampf(delta * 10.0, 0.0, 1.0))
	r.ear_back = lerpf(r.ear_back, ear_back, clampf(delta * 8.0, 0.0, 1.0))
	r.tail_up = lerpf(r.tail_up, tail_up, clampf(delta * 5.0, 0.0, 1.0))
	r.lunge = lerpf(r.lunge, lunge, clampf(delta * 14.0, 0.0, 1.0))
	r.update(delta, _spd)


func _face(dir: Vector2, delta: float, rate: float) -> void:
	var target := atan2(dir.x, dir.y)
	rotation.y = lerp_angle(rotation.y, target, clampf(rate * delta, 0.0, 1.0))
	_heading = Vector2(sin(rotation.y), cos(rotation.y))
