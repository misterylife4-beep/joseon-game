class_name Wildlife
extends Node
## 들짐승을 플레이어 둘레의 성 밖에 풀어 놓는 관리자.
## 낮·저녁에는 사슴 가족과 멧돼지(어미와 새끼), 밤에는 멧돼지와 늑대 무리(위험한 곳일수록 많다). 밤에는 사슴이 누워 쉬기도 한다.
## 성 안과 마을에는 나오지 않는다.
## 마릿수, 나오는 거리, 시간대 가중은 설계값이다 (근거는 docs/고증_근거.md 35장).

const SPAWN_MIN := 36.0
const SPAWN_MAX := 78.0
const DESPAWN := 150.0
const CHECK := 2.5
const MAX_TOTAL := 18
const MAX_DEER := 8
const MAX_BOAR := 7
const MAX_WOLF := 4

var _player: Player
var _survival: Survival
var _hud: SurvivalHud
var _timer := 3.0
var _wolf_cd := 0.0
var _rng := RandomNumberGenerator.new()
var _beasts: Array[WildBeast] = []


func setup(player: Player, survival: Survival, hud: SurvivalHud) -> void:
	_player = player
	_survival = survival
	_hud = hud
	_rng.randomize()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_wolf_cd = maxf(_wolf_cd - delta, 0.0)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK
	_prune()
	if _player.riding != null or _player.swimming:
		return
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	if bool(Region.zone_at(pp.x, pp.y)["town"]):
		return
	_try_spawn(pp)


func _count(k: WildBeast.Kind) -> int:
	var n := 0
	for b in _beasts:
		if b.kind == k:
			n += 1
	return n


func _prune() -> void:
	var keep: Array[WildBeast] = []
	var pp := _player.global_position
	for b in _beasts:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if b.global_position.distance_to(pp) > DESPAWN:
			b.queue_free()
			continue
		keep.append(b)
	_beasts = keep


func _find_spot(pp: Vector2) -> Variant:
	for _try in 12:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var sp := pp + Vector2.from_angle(ang) * dist
		if WildBeast.can_stand(sp):
			return sp
	return null


func _try_spawn(pp: Vector2) -> void:
	if _beasts.size() >= MAX_TOTAL - 4:
		return
	var night := DayNight.night_amount
	var danger := Region.danger_at(pp.x, pp.y)
	var roll := _rng.randf()
	var kind := WildBeast.Kind.DEER
	var rest_herd := false
	var day := night < 0.4
	var mountain := danger >= 2
	if day and _rng.randf() < 0.3:
		return   # 낮에는 밤보다 조금 덜 나온다
	if danger <= 1 and _rng.randf() < 0.35:
		return   # 들길(위험도 1)은 산보다 덜 나온다
	if night >= 0.5 and _wolf_cd <= 0.0 and roll < 0.6 and _count(WildBeast.Kind.WOLF) == 0:
		kind = WildBeast.Kind.WOLF
	elif day and danger >= 1 and _wolf_cd <= 0.0 and roll < (0.3 if mountain else 0.12) and _count(WildBeast.Kind.WOLF) == 0:
		kind = WildBeast.Kind.WOLF   # 대낮에도 늑대가 나온다: 산(위험도 2 이상)은 자주, 들길(1)은 더 드물게
	elif roll < 0.62 and _count(WildBeast.Kind.BOAR) < MAX_BOAR - 2:
		kind = WildBeast.Kind.BOAR
	elif _count(WildBeast.Kind.DEER) < MAX_DEER - 2 and (night < 0.6 or _rng.randf() < 0.6):
		kind = WildBeast.Kind.DEER
		rest_herd = night >= 0.6
	else:
		return
	var spot: Variant = _find_spot(pp)
	if spot == null:
		return
	var sp: Vector2 = spot
	match kind:
		WildBeast.Kind.WOLF:
			if day:
				_spawn_pack(sp, 2)
				_wolf_cd = 110.0
				_hud.toast("대낮인데도 산자락에서 늑대 무리가 어슬렁거린다.", 4.0)
			else:
				_spawn_pack(sp, 2 + (1 if danger >= 2 else 0) + (1 if danger >= 4 else 0))
				_wolf_cd = 70.0
				_hud.toast("멀리서 늑대 무리가 따라붙는다. 불 곁이 안전하다.", 4.0)
		WildBeast.Kind.BOAR:
			if _rng.randf() < 0.45:
				_spawn_boar_family(sp)
				if night > 0.3:
					_hud.toast("풀숲에서 멧돼지 가족이 씩씩거린다. 새끼 곁에 가지 마라.", 3.5)
			else:
				_add(kind, sp, false, true, null, false)
				if night > 0.3:
					_hud.toast("풀숲에서 멧돼지가 씩씩거린다.", 3.0)
		_:
			_spawn_herd(sp, rest_herd)


func _near(sp: Vector2, lo: float, hi: float) -> Vector2:
	for _i in 6:
		var q := sp + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(lo, hi)
		if WildBeast.can_stand(q):
			return q
	return sp


## 사슴 가족: 어미 사슴과 새끼, 때로는 수사슴. 하나가 놀라면 모두 달아난다.
func _spawn_herd(sp: Vector2, resting: bool) -> void:
	var fam: Array = []
	var n := _rng.randi_range(2, 4)
	for i in n:
		var young := i == 1 and _rng.randf() < 0.6 or i == 3
		var male := i == 2 and _rng.randf() < 0.5
		var at := sp if i == 0 else _near(sp, 2.0, 5.0)
		var b := _add(WildBeast.Kind.DEER, at, young, male, fam, resting)
		fam.append(b)
	for b in fam:
		(b as WildBeast).family = fam


## 멧돼지 가족: 어미와 줄무늬 새끼 둘 안팎. 어미는 새끼를 지켜 더 멀리서 경계하고 더 빨리 덤빈다.
func _spawn_boar_family(sp: Vector2) -> void:
	var fam: Array = []
	var sow := _add(WildBeast.Kind.BOAR, sp, false, false, fam, false)
	fam.append(sow)
	for i in _rng.randi_range(2, 3):
		var p := _add(WildBeast.Kind.BOAR, _near(sp, 1.0, 2.5), true, false, fam, false)
		fam.append(p)
	for b in fam:
		(b as WildBeast).family = fam


func _spawn_pack(sp: Vector2, pack: int) -> void:
	var fam: Array = []
	for i in pack:
		if _count(WildBeast.Kind.WOLF) + fam.size() >= MAX_WOLF:
			break
		var at := sp if i == 0 else _near(sp, 2.0, 6.0)
		var b := _add(WildBeast.Kind.WOLF, at, false, false, fam, false)
		fam.append(b)
	for b in fam:
		(b as WildBeast).family = fam


func _add(k: WildBeast.Kind, at: Vector2, young: bool, male: bool, fam: Variant, resting: bool) -> WildBeast:
	var b := WildBeast.new()
	b.young = young
	b.male = male
	b.start_resting = resting
	if fam != null:
		b.family = fam as Array
	b.setup(k, _player, _survival, at)
	b.gone.connect(_on_gone)
	get_parent().add_child(b)
	_beasts.append(b)
	return b


func _on_gone(b: WildBeast) -> void:
	_beasts.erase(b)
