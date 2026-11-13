class_name WildBeast
extends Node3D
## 들짐승 한 마리: 사슴(무리 지어 풀을 뜯고, 하나가 놀라면 모두 달아난다), 멧돼지(어미는 새끼를 지키며 땅을 파헤치다
## 가까이 가면 발로 땅을 긁고 달려들어 들이받는다), 늑대(밤에 무리로 둘러싸 맴돌다 한 마리씩 덮친다).
## 근거(docs/고증_근거.md 35장·47장): 조선 초 한양 둘레 산에 사슴·멧돼지·늑대·범이 산 것은 사료/일반 서술이다.
## 몸 크기, 속도, 피해량, 행동 순서와 무리 짓기는 모두 설계값이다. 불 곁에서는 늑대가 다가오지 못한다.

signal gone(beast: WildBeast)

enum Kind { DEER, BOAR, WOLF }
enum S { IDLE, WANDER, GRAZE, REST, ALERT, STALK, TELL, CHARGE, LEAP, RETREAT, FLEE }

const OUT_U := 1.02

## 지금 달려드는 늑대 수 (한 번에 한 마리만 덤빈다)
static var attackers := 0

var kind := Kind.DEER
var young := false
var male := false
var start_resting := false
## 같은 무리(자기 포함). 무리원은 같은 배열을 함께 쓴다.
var family: Array = []

var _player: Player
var _survival: Survival
var _rig: BeastRig
var _state := S.WANDER
var _state_t := 0.0
var _life := 0.0
var _heading := Vector2(0.0, 1.0)
var _attack_at := 18.0
var _bites := 0
var _combo := 2          ## 연속으로 공격하는 횟수(2~3)
var _rams := 0
var _hit_cd := 0.0
var _orbit := 1.0
var _blocked := 0.0
var _voice: AudioStreamPlayer3D
var _foot: AudioStreamPlayer3D
var _rustle: AudioStreamPlayer3D
var _voice_cd := 5.0
var _rustle_cd := 0.0
var _is_attacker := false
var _rng := RandomNumberGenerator.new()
var _moved := 0.0
var _spd := 0.0
var _ring := 22.0
var _ang := 0.0
var _slot := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_t := 0.0
var _toss := 0.0
var _noise := 1.0
var _track_toggle := false
var _said_alert := false
## 싸움: 체력과 죽음. 덮치기 시작했거나 맞은 멧돼지·늑대는 두 번 물거나 들이받기 전에는 달아나지 않는다.
var hp := 40.0
var dead := false
var _engaged := false
var _landed := 0
var hp_max := 40.0
var _stun := 0.0          ## 맞고 움찔하는 시간
var _kb := Vector2.ZERO   ## 맞아 밀려나는 속도(m/s)
var _dodge_cd := 0.0
var _rage := 0.0          ## 맞아서 성난 시간 (멧돼지)
var _scale0 := Vector3.ZERO
var _hit_tw: Tween


func setup(k: Kind, player: Player, survival: Survival, start: Vector2) -> void:
	kind = k
	_player = player
	_survival = survival
	_rng.randomize()
	position = Vector3(start.x, HanyangMap.surface(start.x, start.y), start.y)
	_heading = Vector2.from_angle(_rng.randf() * TAU)
	rotation.y = atan2(_heading.x, _heading.y)
	_orbit = 1.0 if _rng.randf() < 0.5 else -1.0
	_attack_at = _rng.randf_range(12.0, 26.0)
	_combo = _rng.randi_range(2, 3)
	hp = {Kind.DEER: 36.0, Kind.BOAR: 70.0, Kind.WOLF: 45.0}[k] * (0.5 if young else 1.0)
	hp_max = hp
	_ang = _rng.randf() * TAU
	_state = S.STALK if kind == Kind.WOLF else S.WANDER


func _ready() -> void:
	add_to_group("beast")
	var variant := 0
	match kind:
		Kind.DEER, Kind.BOAR:
			variant = 1 if male else 0
		_:
			variant = _rng.randi() % 3
	_rig = BeastRig.make(int(kind), variant, young)
	if not young:
		_rig.scale *= _rng.randf_range(0.95, 1.07)
	add_child(_rig)
	_rig.stepped.connect(_on_step)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 12.0
	_voice.max_distance = 160.0
	_voice.position.y = 0.8
	add_child(_voice)
	_foot = AudioStreamPlayer3D.new()
	_foot.unit_size = 5.0
	_foot.max_distance = 45.0
	add_child(_foot)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.stream = BeastSfx.stream("rustle")
	_rustle.unit_size = 5.0
	_rustle.max_distance = 40.0
	_rustle.volume_db = -14.0
	add_child(_rustle)
	if kind == Kind.WOLF:
		add_to_group("predator")
		if is_leader():
			_voice_cd = _rng.randf_range(2.0, 6.0)
	if start_resting and kind == Kind.DEER:
		_state = S.REST
		_rig.crouch = 1.5


func _exit_tree() -> void:
	if _is_attacker:
		_is_attacker = false
		attackers = maxi(attackers - 1, 0)


## 노리며 다가오는 중인가 (심장 박동 효과가 본다)
func hunting() -> bool:
	return kind == Kind.WOLF and _state in [S.STALK, S.TELL, S.CHARGE, S.LEAP]


func is_leader() -> bool:
	return not family.is_empty() and family[0] == self


func _leader() -> WildBeast:
	for m in family:
		if not is_instance_valid(m):
			continue
		var b := m as WildBeast
		if b != null and not b.is_queued_for_deletion() and not b.young:
			return b
	return null


func _say(sname: String, db := 0.0, pitch := 1.0) -> void:
	if _voice == null:
		return
	_voice.stream = BeastSfx.stream(sname)
	_voice.volume_db = db
	_voice.pitch_scale = pitch
	_voice.play()


# --- 소리와 발자국 ---

func _on_step(leg: int) -> void:
	var sname := "step_deer"
	var tk := 0
	var vol := -12.0
	match kind:
		Kind.BOAR:
			sname = "step_boar"
			tk = 1
			vol = -9.0
		Kind.WOLF:
			sname = "step_wolf"
			tk = 2
			vol = -14.0
	if young:
		vol -= 4.0
	vol += clampf((_spd - 3.0) * 0.8, 0.0, 5.0)
	_foot.stream = BeastSfx.stream(sname)
	_foot.volume_db = vol
	_foot.pitch_scale = _rng.randf_range(0.9, 1.1) * (1.2 if young else 1.0)
	_foot.play()
	if leg < 2 and not young:
		_track_toggle = not _track_toggle
		if _track_toggle and BeastFx.inst != null:
			BeastFx.inst.add_track(tk, Vector3(global_position.x, HanyangMap.surface(global_position.x, global_position.z), global_position.z), rotation.y)
	if _spd > 4.0 and _rustle_cd <= 0.0:
		_rustle_cd = 0.45
		_rustle.pitch_scale = _rng.randf_range(0.9, 1.15)
		_rustle.play()


# --- 행동 ---

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## 짐승이 설 수 있는 곳: 성 밖, 마을이 아닌 곳, 물가가 아닌 마른 땅
static func can_stand(p: Vector2) -> bool:
	if HanyangMap.u_of(p.x, p.y) < OUT_U:
		return false
	if bool(Region.zone_at(p.x, p.y)["town"]):
		return false
	if HanyangMap.surface(p.x, p.y) < HanyangMap.RIVER_LEVEL + 0.4:
		return false
	return HanRiver.pier_deck_at(p.x, p.y, 3.0) < -900.0


func _step(dir: Vector2, speed_in: float, delta: float) -> bool:
	var speed := speed_in * _speed_mul()
	var here := _flat(position)
	var d := dir
	for attempt in 3:
		var nxt := here + d * speed * delta
		if can_stand(nxt):
			position = Vector3(nxt.x, HanyangMap.surface(nxt.x, nxt.y) + 0.02, nxt.y)   # 눈에 보이는 땅에 바로 붙인다(늦게 따라가면 비탈에서 묻힌다)
			_moved += speed * delta
			return true
		d = d.rotated(0.9 * _orbit * float(attempt + 1))
	return false


func _face(dir: Vector2, delta: float, rate: float) -> void:
	if dir.length() < 0.001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), clampf(rate * delta, 0.0, 1.0))
	_heading = Vector2(sin(rotation.y), cos(rotation.y))


## 덮치기 시작했고 아직 두 번 입히지 못했으면 달아나지 않는다 (마을로 들어선 때는 예외).
func _locked() -> bool:
	if not _engaged or _landed >= 2 or dead or young or kind == Kind.DEER:
		return false
	var pp := _flat(_player.global_position)
	return not (bool(Region.zone_at(pp.x, pp.y)["town"]) or HanyangMap.u_of(pp.x, pp.y) < 0.95)


func body_size() -> float:
	return {Kind.DEER: 0.9, Kind.BOAR: 0.9, Kind.WOLF: 0.8}[kind] * (0.6 if young else 1.0)


## 칼·도끼를 맞았을 때. 짐승은 종마다 다르게 움직인다 (docs/고증_근거.md 52장).
## 맞은 만큼 뒤로 밀리고 잠깐 움찔하며(몸이 클수록 덜 밀리고 덜 움찔한다), 다친 뒤에는 절룩인다.
func take_hit(dmg: float, from: Vector3) -> void:
	if dead:
		return
	hp -= dmg
	if not young and kind != Kind.DEER:
		_engaged = true
	var away := _flat(position) - Vector2(from.x, from.z)
	away = away.normalized() if away.length() > 0.01 else Vector2.from_angle(randf() * TAU)
	var mass: float = float({Kind.DEER: 1.0, Kind.BOAR: 1.7, Kind.WOLF: 0.8}[kind]) * (0.5 if young else 1.0)
	_kb = away * clampf(dmg * 0.4 / mass, 1.5, 7.0)
	_stun = clampf(0.1 + dmg * 0.006 / mass, 0.12, 0.5)
	_squash()
	HitReact.react(self, _rig, from, dmg, mass * 1.3)
	# 세게 맞을수록 소리가 크고 낮다
	var loud := clampf(dmg * 0.12, 0.0, 4.0)
	var pit := clampf(1.12 - dmg * 0.008 + _rng.randf_range(-0.05, 0.05), 0.8, 1.2)
	match kind:
		Kind.DEER:
			_say("deer_bark", 0.0 + loud, pit)
		Kind.BOAR:
			_say("boar_squeal", 4.0 + loud, pit)
		_:
			_say("wolf_yelp", 4.0 + loud, pit)
	if hp <= 0.0:
		_die()
		return
	if kind == Kind.DEER or young:
		_flee_now()
		_alarm_family(true)
		return
	_alarm_family(false)
	match kind:
		Kind.BOAR:
			# 상처 입은 멧돼지는 더 사납게 곧장 다시 들이받는다 (짧고 거친 돌진)
			_rage = 7.0
			_set_state(S.CHARGE)
		_:
			# 늑대는 맞으면 낑낑대며 물러나 몸을 사리고, 곧 옆으로 돌아 다시 덤빈다
			if _rng.randf() < 0.55:
				_set_state(S.RETREAT)
			elif _state != S.CHARGE and _state != S.LEAP:
				_set_state(S.TELL)


## 맞으면 튀는 털 조각 색
func fur_color() -> Color:
	match kind:
		Kind.DEER:
			return Color(0.62, 0.45, 0.28)
		Kind.BOAR:
			return Color(0.26, 0.21, 0.18)
		_:
			return Color(0.52, 0.51, 0.48)


func _squash() -> void:
	if _rig == null:
		return
	if _scale0 == Vector3.ZERO:
		_scale0 = _rig.scale
	if _hit_tw != null and _hit_tw.is_valid():
		_hit_tw.kill()
	_rig.scale = _scale0
	_hit_tw = create_tween()
	_hit_tw.tween_property(_rig, "scale", _scale0 * Vector3(1.1, 0.88, 1.1), 0.05)
	_hit_tw.tween_property(_rig, "scale", _scale0, 0.14)


## 밀려나는 몸을 움직인다
func _apply_kb(delta: float) -> void:
	if _kb.length() < 0.05:
		return
	var nxt := _flat(position) + _kb * delta
	if can_stand(nxt):
		position = Vector3(nxt.x, HanyangMap.surface(nxt.x, nxt.y) + 0.02, nxt.y)
	_kb = _kb.move_toward(Vector2.ZERO, 18.0 * delta)


## 사람이 막 휘두르는 걸 보면 늑대는 옆으로 비켜서고, 멧돼지는 거의 비키지 않는다
func _try_dodge(dist: float, dir: Vector2) -> void:
	if _dodge_cd > 0.0 or young or kind == Kind.DEER or _state in [S.LEAP, S.FLEE, S.REST]:
		return
	if Time.get_ticks_msec() - Gear.swing_start_ms > 260 or dist > Gear.REACH + body_size() + 0.6:
		return
	_dodge_cd = 1.6
	var p: float = float({Kind.DEER: 0.0, Kind.BOAR: 0.1, Kind.WOLF: 0.4}[kind])
	if _rng.randf() < p:
		var side := Vector2(-dir.y, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_kb = side * 6.0


## 다친 짐승은 절룩이고(체력 35% 아래), 성난 멧돼지는 빨라진다
func _speed_mul() -> float:
	var m := 1.0
	if hp < hp_max * 0.35:
		m *= 0.75
	if _rage > 0.0:
		m *= 1.2
	return m


func _die() -> void:
	dead = true
	remove_from_group("beast")
	remove_from_group("predator")
	if _is_attacker:
		_is_attacker = false
		attackers = maxi(attackers - 1, 0)
	set_process(false)
	gone.emit(self)
	if _rig != null:
		var h: float = float({Kind.DEER: 1.0, Kind.BOAR: 0.75, Kind.WOLF: 0.7}[kind]) * _rig.scale.x
		var tw := create_tween()
		tw.tween_property(_rig, "rotation:z", PI * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_rig, "position", Vector3(h * 0.9, 0.25, 0.0), 0.5)
	if _survival != null and not young:
		var key: String = {Kind.DEER: "deer", Kind.BOAR: "boar", Kind.WOLF: "wolf"}[kind]
		var meat: int = int({Kind.DEER: 3, Kind.BOAR: 4, Kind.WOLF: 2}[kind])
		var nm: String = String({Kind.DEER: "사슴", Kind.BOAR: "멧돼지", Kind.WOLF: "늑대"}[kind])
		_survival.add_drops(global_position, "meat_" + key, meat, "hide_" + key, 1.3)
		_survival.drop_notice(nm)
		_survival.reward_kill(8.0)
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


func _set_state(s: S) -> void:
	if s in [S.TELL, S.CHARGE, S.LEAP] and not young and kind != Kind.DEER:
		_engaged = true
	_state = s
	_state_t = 0.0
	_blocked = 0.0


func _flee_now() -> void:
	if _locked():
		if _state != S.CHARGE and _state != S.LEAP:
			_set_state(S.CHARGE)
		return
	if _state != S.FLEE:
		_set_state(S.FLEE)
		if _is_attacker:
			_is_attacker = false
			attackers = maxi(attackers - 1, 0)


## 무리 하나가 놀라면 나머지도 경계하고, 하나가 달아나면 모두 달아난다.
func _alarm_family(flee: bool) -> void:
	for m in family:
		if not is_instance_valid(m) or m == self:
			continue
		var b := m as WildBeast
		if b == null:
			continue
		if flee:
			b._flee_now()
		elif b._state in [S.IDLE, S.GRAZE, S.WANDER, S.REST]:
			b._set_state(S.ALERT)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	_life += delta
	_state_t += delta
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_voice_cd = maxf(_voice_cd - delta, 0.0)
	_rustle_cd = maxf(_rustle_cd - delta, 0.0)
	_toss = maxf(_toss - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_rage = maxf(_rage - delta, 0.0)

	var me := _flat(position)
	var pp := _flat(_player.global_position)
	var to_p := pp - me
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var fire := _survival != null and _survival.near_fire()
	var player_safe := bool(Region.zone_at(pp.x, pp.y)["town"]) or HanyangMap.u_of(pp.x, pp.y) < 0.95
	# 플레이어가 뛰면 소리가 커 멀리서도 눈치채고, 살금살금 걸으면 늦게 눈치챈다
	var ps := Vector2(_player.velocity.x, _player.velocity.z).length()
	_noise = clampf(0.75 + ps * 0.09, 0.75, 1.6)

	_apply_kb(delta)
	if _stun > 0.0:
		_stun -= delta
		_animate(delta, dir, dist)
		return
	_try_dodge(dist, dir)
	match kind:
		Kind.DEER:
			_deer(delta, dir, dist)
		Kind.BOAR:
			_boar(delta, dir, dist, fire, player_safe)
		_:
			_wolf(delta, dir, dist, fire, player_safe, pp)

	if _state == S.FLEE and (dist > 75.0 or _state_t > 14.0):
		gone.emit(self)
		queue_free()
		return
	_animate(delta, dir, dist)


## 서 있는 자세·머리·귀·꼬리를 상태에 맞춰 정하고 몸을 움직인다.
func _animate(delta: float, dir: Vector2, dist: float) -> void:
	var spd := _moved / maxf(delta, 0.001)
	_moved = 0.0
	_spd = lerpf(_spd, spd, clampf(delta * 8.0, 0.0, 1.0))
	var r := _rig
	var t := _life
	var crouch := 0.0
	var head_down := 0.0
	var head_turn := 0.0
	var jaw := 0.0
	var ear_back := 0.0
	var ear_alert := 0.0
	var tail_up := 0.0
	var lunge := 0.0
	match _state:
		S.REST:
			crouch = 1.5
			ear_alert = 0.0
		S.IDLE:
			head_turn = 0.6 * sin(t * 0.45 + float(get_instance_id() % 7))
			ear_alert = 0.3
		S.GRAZE:
			head_down = 1.0 if kind == Kind.DEER else 0.85 + 0.15 * sin(t * 3.0)
			if kind == Kind.BOAR:
				jaw = 0.25 + 0.25 * sin(t * 9.0)
			ear_alert = 0.1
		S.WANDER:
			head_down = 0.05 * sin(t * 2.0)
		S.ALERT:
			ear_alert = 1.0
			head_turn = 0.25 * sin(t * 1.3)
			tail_up = 1.0 if kind == Kind.DEER else 0.0
			if kind == Kind.BOAR:
				head_down = 0.2
				ear_back = 0.3
		S.STALK:
			crouch = 0.35
			head_down = 0.3
			ear_back = 0.35
		S.TELL:
			crouch = 0.55 if kind == Kind.WOLF else 0.0
			head_down = 0.6 if kind == Kind.BOAR else 0.3
			jaw = 0.8 if kind == Kind.WOLF else 0.0
			ear_back = 1.0
		S.CHARGE:
			ear_back = 0.9
			head_down = 0.5 if kind == Kind.BOAR else 0.2
			jaw = 0.5 if kind == Kind.WOLF and dist < 8.0 else 0.0
		S.LEAP:
			lunge = 1.0
			jaw = 1.0
			ear_back = 1.0
		S.RETREAT:
			ear_back = 0.4
			head_down = -0.4 if _toss > 0.0 else 0.1
		S.FLEE:
			tail_up = 1.0 if kind == Kind.DEER else 0.0
			ear_back = 0.5
	if _toss > 0.0:
		head_down = -0.6   # 멧돼지가 들이받고 머리를 쳐든다
	if hp < hp_max * 0.35 and not dead:
		crouch = maxf(crouch, 0.25)   # 다쳐서 몸을 낮추고 절룩인다
		head_down += 0.2
	if _stun > 0.0:
		crouch = maxf(crouch, 0.5)    # 맞은 순간 몸이 움츠러들고 머리가 젖혀진다
		head_down = -0.5
		ear_back = 1.0
		jaw = 0.7
	r.crouch = lerpf(r.crouch, crouch, clampf(delta * 4.0, 0.0, 1.0))
	r.head_down = lerpf(r.head_down, head_down, clampf(delta * 5.0, 0.0, 1.0))
	r.head_turn = lerpf(r.head_turn, head_turn, clampf(delta * 3.0, 0.0, 1.0))
	r.jaw = lerpf(r.jaw, jaw, clampf(delta * 10.0, 0.0, 1.0))
	r.ear_back = lerpf(r.ear_back, ear_back, clampf(delta * 8.0, 0.0, 1.0))
	r.ear_alert = lerpf(r.ear_alert, ear_alert, clampf(delta * 6.0, 0.0, 1.0))
	r.tail_up = lerpf(r.tail_up, tail_up, clampf(delta * 5.0, 0.0, 1.0))
	r.lunge = lerpf(r.lunge, lunge, clampf(delta * 14.0, 0.0, 1.0))
	r.update(delta, _spd)


func _wander(delta: float, speed: float) -> void:
	if _state_t > _rng.randf_range(3.0, 7.0):
		_state_t = 0.0
		var roll := _rng.randf()
		if roll < 0.35:
			_set_state(S.IDLE)
			return
		if roll < 0.7:
			_set_state(S.GRAZE)
			return
		_heading = _heading.rotated(_rng.randf_range(-1.4, 1.4))
	# 무리원은 우두머리를 따라간다
	var lead := _leader()
	if lead != null and lead != self:
		var to_l := _flat(lead.position) - _flat(position)
		if to_l.length() > 5.5:
			_heading = to_l.normalized()
			if _step(_heading, speed * 1.5, delta):
				_face(_heading, delta, 4.0)
			return
		elif lead._state == S.GRAZE:
			_set_state(S.GRAZE)
			return
	if _step(_heading, speed, delta):
		_face(_heading, delta, 3.0)
	else:
		_heading = _heading.rotated(1.2)


func _deer(delta: float, dir: Vector2, dist: float) -> void:
	var alert_r := 26.0 * _noise
	match _state:
		S.REST:
			if dist < 14.0 * _noise:
				_set_state(S.ALERT)
				_alarm_family(false)
		S.IDLE:
			if _state_t > _rng.randf_range(2.5, 4.5):
				_set_state(S.GRAZE if _rng.randf() < 0.5 else S.WANDER)
			if dist < alert_r:
				_set_state(S.ALERT)
				_alarm_family(false)
		S.GRAZE:
			if _state_t > _rng.randf_range(5.0, 9.0):
				_set_state(S.IDLE if _rng.randf() < 0.4 else S.WANDER)
			if dist < alert_r:
				_set_state(S.ALERT)
				_alarm_family(false)
		S.WANDER:
			if dist < alert_r:
				_set_state(S.ALERT)
				_alarm_family(false)
				return
			_wander(delta, 1.1)
		S.ALERT:
			if _state_t < 0.05 and not young:
				_say("deer_snort", -6.0)
			_face(dir, delta, 4.0)
			if dist < 15.0 * _noise or (_state_t > 6.0 and dist < 22.0):
				if not _said_alert and not young:
					_said_alert = true
					_say("deer_bark", 0.0)
				_flee_now()
				_alarm_family(true)
			elif dist > 34.0:
				_set_state(S.WANDER)
		_:
			var away := -dir
			if _step(away, 9.0, delta):
				_face(away, delta, 8.0)
			else:
				_heading = _heading.rotated(0.8)
				_step(_heading, 6.0, delta)


func _boar(delta: float, dir: Vector2, dist: float, fire: bool, player_safe: bool) -> void:
	if young:
		_piglet(delta, dir, dist)
		return
	var guard := _guards_young()
	var aggro := 11.0 if not guard else 15.0
	match _state:
		S.IDLE:
			if _state_t > 3.0:
				_set_state(S.GRAZE if _rng.randf() < 0.6 else S.WANDER)
			if dist < aggro and not player_safe:
				_set_state(S.ALERT)
		S.GRAZE:
			if _voice_cd <= 0.0:
				_voice_cd = _rng.randf_range(5.0, 10.0)
				_say("boar_grunt", -4.0)
			if _state_t > _rng.randf_range(6.0, 11.0):
				_set_state(S.WANDER)
			if dist < aggro and not player_safe:
				_set_state(S.ALERT)
		S.WANDER:
			if dist < aggro and not player_safe:
				_set_state(S.ALERT)
				return
			_wander(delta, 1.3)
		S.ALERT:
			_face(dir, delta, 5.0)
			if _state_t < 0.05:
				_say("boar_snort", 0.0)
			if player_safe or dist > aggro + 8.0:
				_set_state(S.WANDER)
			elif fire:
				_watch_circle(delta, dir, dist, aggro + 3.0, 2.2)   # 불을 피하며 둘레를 돌며 노려본다
				if _voice_cd <= 0.0:
					_voice_cd = _rng.randf_range(4.0, 8.0)
					_say("boar_grunt" if _rng.randf() < 0.6 else "boar_snort", 1.0)
			elif _state_t > 1.2 and dist < aggro + 1.0:
				_set_state(S.TELL)
		S.TELL:
			# 발로 땅을 긁으며 노려본다
			_face(dir, delta, 6.0)
			if _state_t < 0.05:
				_say("boar_grunt", 3.0)
			if player_safe:
				_set_state(S.WANDER)
			elif fire:
				_set_state(S.ALERT)
			elif _state_t > (0.8 if guard else 1.3):
				_say("boar_squeal", 3.0)
				_set_state(S.CHARGE)
		S.CHARGE:
			if dist > 1.9:
				if _step(dir, 8.5, delta):
					_blocked = 0.0
				else:
					_blocked += delta
					if _blocked > 1.2:
						_flee_now()
			_face(dir, delta, 9.0)
			if fire and dist < 8.0:
				_set_state(S.ALERT)
			elif dist < 2.3 and _hit_cd <= 0.0:
				_hit_cd = 1.2
				_rams += 1
				_landed += 1
				_survival.hurt(14.0, "멧돼지에게 들이받혔다!")
				_player.stagger(Vector3(dir.x, 0.0, dir.y), 9.0, 1.1, true)
				if BeastFx.inst != null:
					BeastFx.inst.hit(14.0, "ram")
				_say("boar_squeal", 4.0)
				_toss = 0.5
				_set_state(S.RETREAT)
			elif _state_t > 9.0:
				_flee_now()
		S.RETREAT:
			if _state_t > 0.6 and _step(-dir, 4.0, delta):
				_face(dir, delta, 4.0)
			if player_safe:
				_flee_now()
			elif fire:
				_set_state(S.ALERT)
			elif _rams < _combo and _state_t > (0.6 if _rage > 0.0 else 1.3):
				_say("boar_squeal", 3.0)
				_set_state(S.CHARGE)     # 숨 고르고 다시 들이받는다
			elif _state_t > 2.5:
				_flee_now()
		_:
			var away := -dir
			if _step(away, 7.0, delta):
				_face(away, delta, 7.0)


## 불 곁의 사람 둘레를 일정한 거리를 두고 빙빙 돌며 노려본다.
func _watch_circle(delta: float, dir: Vector2, dist: float, ring: float, speed: float) -> void:
	var side := Vector2(-dir.y, dir.x) * _orbit
	var radial := clampf((dist - ring) * 0.35, -1.0, 1.0)
	var v := side * 0.8 + dir * radial
	if v.length() > 0.01:
		_step(v.normalized(), speed, delta)
	_face(dir, delta, 4.0)


## 공격하던 중 불 때문에 물러서면 달아나지 않고 다시 둘레를 맴도는 자세로 돌아간다.
func _back_to_watch() -> void:
	if _is_attacker:
		_is_attacker = false
		attackers = maxi(attackers - 1, 0)
	_set_state(S.STALK)


func _guards_young() -> bool:
	for m in family:
		if is_instance_valid(m) and (m as WildBeast).young:
			return true
	return false


## 새끼 멧돼지: 어미 곁을 졸졸 따라다니고, 사람이 가까우면 어미 쪽으로 달아난다.
func _piglet(delta: float, dir: Vector2, dist: float) -> void:
	var lead := _leader()
	if _state == S.FLEE:
		var away := -dir
		if _step(away, 5.5, delta):
			_face(away, delta, 7.0)
		return
	if dist < 5.5 or (lead != null and lead._state in [S.FLEE, S.CHARGE, S.TELL]):
		_flee_now()
		return
	if lead != null:
		var to_l := _flat(lead.position) - _flat(position)
		if to_l.length() > 1.8 + float(get_index() % 3):
			var spd := clampf(to_l.length() * 0.8, 0.8, 4.0)
			if _step(to_l.normalized(), spd, delta):
				_face(to_l.normalized(), delta, 6.0)
			_state = S.WANDER
		else:
			_state = S.GRAZE if lead._state == S.GRAZE else S.IDLE
	else:
		_wander(delta, 1.0)


func _wolf(delta: float, dir: Vector2, dist: float, fire: bool, player_safe: bool, pp: Vector2) -> void:
	if _voice_cd <= 0.0 and _state != S.FLEE and _state != S.LEAP:
		if is_leader() and _rng.randf() < delta * 0.1:
			_voice_cd = 20.0
			_say("wolf_howl", 4.0)
		elif dist < 26.0 and _state == S.STALK and _rng.randf() < delta * 0.15:
			_voice_cd = 7.0
			_say("wolf_snarl", 0.0)
	var day_out := DayNight.night_amount < 0.3 and Region.danger_at(position.x, position.z) < 2   # 낮에도 산에서는 남는다
	if _state != S.FLEE and (player_safe or day_out or (_life > 95.0 and not fire) or _life > 420.0):
		_flee_now()
	match _state:
		S.STALK:
			# 무리가 사람을 둘러싸고 서서히 좁혀 온다
			var n := maxi(family.size(), 1)
			var idx := family.find(self)
			_slot = maxi(idx, 0)
			if fire:
				_ring = lerpf(_ring, 16.0, clampf(delta * 0.6, 0.0, 1.0))   # 불빛 밖에서 맴돈다
			else:
				_ring = maxf(_ring - delta * 0.35, 11.0)
			_ang += delta * (0.3 if fire else 0.18) * _orbit
			var want_ang := _ang + TAU * float(_slot) / float(n)
			var target := pp + Vector2.from_angle(want_ang) * _ring
			var to_t := target - _flat(position)
			var moving := false
			if to_t.length() > 1.2:
				var sp := minf(to_t.length() * 0.9, 4.4)
				moving = _step(to_t.normalized(), sp, delta)
			_face(dir, delta, 3.0)
			if fire:
				return   # 달아나지 않고 불 둘레를 돌며 지켜본다
			if _state_t > _attack_at and attackers < 1 and _bites < 1 and _hit_cd <= 0.0:
				attackers += 1
				_is_attacker = true
				_set_state(S.TELL)
		S.TELL:
			_face(dir, delta, 8.0)
			if _state_t < 0.05:
				_say("wolf_snarl", 3.0)
			if fire and dist < 10.0:
				_back_to_watch()
			elif _state_t > 0.9:
				_set_state(S.CHARGE)
		S.CHARGE:
			if dist > 5.5:
				if _step(dir, 7.5, delta):
					_blocked = 0.0
				else:
					_blocked += delta
					if _blocked > 1.4:
						_flee_now()
			elif dist < 2.6 and _hit_cd <= 0.0:
				_land_bite(dir, dist)      # 바짝 붙었으면 뛰지 않고 곧바로 덥석 문다
			else:
				_start_leap(pp)
			_face(dir, delta, 9.0)
			if fire and dist < 10.0:
				_back_to_watch()
			elif _state_t > 8.0:
				_flee_now()
		S.LEAP:
			_leap_t += delta / 0.5
			var k := clampf(_leap_t, 0.0, 1.0)
			var p := _leap_from.lerp(_leap_to, k)
			p.y += sin(k * PI) * 0.95
			position = p
			if _leap_t >= 1.0:
				_land_bite(dir, dist)
		S.RETREAT:
			if _step(-dir, 5.5, delta):
				_face(dir, delta, 5.0)
			if fire and dist < 10.0:
				_back_to_watch()
			elif _bites < _combo and _state_t > 1.0:
				_set_state(S.CHARGE)     # 한 번 물고 빠졌다가 다시 달려든다
			elif _state_t > 3.0:
				_flee_now()
		_:
			var away := -dir
			if _step(away, 7.0, delta):
				_face(away, delta, 7.0)


func _start_leap(pp: Vector2) -> void:
	_leap_from = position
	var me := _flat(position)
	var d := (pp - me).normalized()
	var end := pp - d * 0.9
	_leap_to = Vector3(end.x, HanyangMap.surface(end.x, end.y), end.y)
	_leap_t = 0.0
	_say("wolf_snarl", 4.0)
	_set_state(S.LEAP)


func _land_bite(dir: Vector2, _dist: float) -> void:
	var pp := _flat(_player.global_position)
	var near := _flat(position).distance_to(pp) < 2.8
	_bites += 1
	_hit_cd = 1.2
	if near:
		_landed += 1
		_survival.hurt(8.0, "늑대에게 물렸다!")
		_player.stagger(Vector3(dir.x, 0.0, dir.y), 4.5, 0.4, false)
		if BeastFx.inst != null:
			BeastFx.inst.hit(8.0, "bite")
	_set_state(S.RETREAT)
	if _is_attacker and _bites >= _combo:
		_is_attacker = false
		attackers = maxi(attackers - 1, 0)
