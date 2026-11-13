class_name WildWatch
extends Node
## 야외 감시자: 구역이 바뀔 때 알림, 광나루 나룻배 건너기, 위험도 3 이상 산에서 호랑이 등장.
## 마을(위험도 0)에서는 맹수가 나오지 않는다는 규칙은 게임 규칙(설계값)이다.
## 호랑이가 나오기 전 새소리가 끊기는 기척과 등장 확률, 시간대 가중은 설계값이다.

const FERRY_RANGE := 3.2
const FIRST_GRACE := 40.0
const AFTER_GRACE := 150.0
const FORCE_AFTER := 70.0
## 1막을 마치기 전 한양 바깥으로 나갈 수 없는 경계 (설계값): 성저십리 안(정규화 반지름)과 한강 북쪽 기슭까지
const LIMIT_U := 2.6
## 걸어서는 선착장 끝(강 중심선 북쪽 19 m)까지, 헤엄치거나 배를 타면 강 한가운데 조금 못 미친 곳까지만
const RIVER_MARGIN := 17.0
const WATER_SOUTH := 4.0
const WALL_TOAST_CD := 7.0

var _player: Player
var _survival: Survival
var _hud: SurvivalHud
var _zone_id := ""
var _danger := 0
var _tiger: Tiger = null
var _exposure := 0.0
var _cooldown := FIRST_GRACE
var _omen := -1.0
var _crossing := false
var _ferry_cd := 3.0
var _fade: ColorRect
var _flash: ColorRect
var _rng := RandomNumberGenerator.new()
var _vig: InkVignette
var _wild: NightWildlife
var _wall_cd := 0.0


func setup(player: Player, survival: Survival, hud: SurvivalHud) -> void:
	_player = player
	_survival = survival
	_hud = hud
	_rng.randomize()
	_vig = InkVignette.new()
	add_child(_vig)
	_wild = NightWildlife.new()
	add_child(_wild)
	_wild.setup(player, hud, _vig)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_fade = _overlay(Color(0.0, 0.0, 0.0, 0.0))
	_flash = _overlay(Color(0.65, 0.0, 0.0, 0.0))
	layer.add_child(_fade)
	layer.add_child(_flash)


func _overlay(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	_wall_cd = maxf(_wall_cd - delta, 0.0)
	_enforce_bounds(pp)
	_update_zone(pp)
	var near := 0.0
	if _tiger != null and is_instance_valid(_tiger):
		near = clampf(1.0 - _tiger.global_position.distance_to(_player.global_position) / 35.0, 0.0, 1.0)
	_vig.set_pulse(near)
	_update_ferry(pp, delta)
	_update_tiger(delta)


# --- 한양 이탈 제한 ---

## 1막의 일이 남아 있으면 한양(성저십리)과 한강 북쪽 기슭 안에 머물게 한다.
func _locked() -> bool:
	return not ActGoals.act_complete(0)


func _lock_reason() -> String:
	var rest := ActGoals.remaining(0)
	var t := "아직 한양을 떠날 수 없다."
	if not rest.is_empty():
		t += " 남은 일: " + String(rest[0]["text"])
	return t


## 물 위(헤엄·배)에서 갈 수 있는 가장 남쪽 z. 1막을 마치면 제한이 없다.
static func water_limit_z(x: float) -> float:
	if ActGoals.act_complete(0):
		return INF
	return HanyangMap.river_z(x) + WATER_SOUTH


func _enforce_bounds(pp: Vector2) -> void:
	if _crossing or not _locked():
		return
	if _player.riding != null:
		return
	var q := pp
	var rz := HanyangMap.river_z(pp.x) - RIVER_MARGIN
	if _player.swimming:
		rz = water_limit_z(pp.x)
	if q.y > rz:
		q.y = rz
	var u := HanyangMap.u_of(q.x, q.y)
	if u > LIMIT_U:
		q = q * (LIMIT_U - 0.02) / u
	if q.is_equal_approx(pp):
		return
	_player.global_position = Vector3(q.x, _player.global_position.y, q.y)
	var v := _player.velocity
	_player.velocity = Vector3(0.0, v.y, 0.0)
	if _wall_cd <= 0.0:
		_wall_cd = WALL_TOAST_CD
		_hud.toast(_lock_reason(), 4.0)


# --- 구역 알림 ---

func _update_zone(pp: Vector2) -> void:
	var zn := Region.zone_at(pp.x, pp.y)
	var id: String = zn["id"]
	_danger = int(zn["danger"])
	_vig.set_danger(_danger)
	if id == _zone_id:
		return
	_zone_id = id
	ActGoals.on_zone(id)
	var msg: String = zn["enter"]
	if msg != "":
		_hud.toast(msg, 4.0)
		if _danger >= 3:
			_hud.stamp("seal_wi.png")


# --- 나룻배 ---

func _update_ferry(pp: Vector2, delta: float) -> void:
	_ferry_cd = maxf(_ferry_cd - delta, 0.0)
	if _crossing or _ferry_cd > 0.0 or _player.input_locked or _player.water_recent > 0.0:
		return
	if pp.distance_to(Region.landing_north()) < FERRY_RANGE:
		if _locked():
			_ferry_cd = 5.0
			_hud.toast("사공이 고개를 젓는다. " + _lock_reason(), 4.0)
			return
		_cross(true)
	elif pp.distance_to(Region.landing_south()) < FERRY_RANGE:
		_cross(false)


func _cross(to_south: bool) -> void:
	_crossing = true
	_player.input_locked = true
	_hud.toast("나룻배에 오른다. 사공이 삿대를 민다.", 3.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_interval(1.4)
	tw.tween_callback(_land.bind(to_south))
	tw.tween_property(_fade, "color:a", 0.0, 1.0)
	tw.tween_callback(_cross_done)


func _land(to_south: bool) -> void:
	var dest := Region.landing_south() + Vector2(0.0, 6.0) if to_south else Region.landing_north() + Vector2(0.0, -6.0)
	_player.global_position = Vector3(dest.x, HanyangMap.height(dest.x, dest.y) + 1.0, dest.y)
	_player.velocity = Vector3.ZERO
	_player._yaw = PI if to_south else 0.0
	_hud.toast("강을 건넜다.", 2.5)
	if to_south:
		ActGoals.mark("a2_ferry")


func _cross_done() -> void:
	_crossing = false
	_player.input_locked = false
	_ferry_cd = 4.0


# --- 호랑이 ---

func _update_tiger(delta: float) -> void:
	if _tiger != null and not is_instance_valid(_tiger):
		_tiger = null
	if _tiger != null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _danger < 3:
		_exposure = maxf(_exposure - delta * 2.0, 0.0)
		_omen = -1.0
		return
	if _crossing or _player.input_locked:
		return
	_exposure += delta
	if _omen >= 0.0:
		_omen -= delta
		if _omen < 0.0:
			if not _spawn_tiger():
				_omen = 1.0
		return
	if _cooldown > 0.0:
		return
	var rate := 0.012 * (1.0 + 1.6 * DayNight.night_amount) * (1.0 + 0.5 * Season.cold)
	if _danger >= 4:
		rate *= 1.4
	if _exposure > FORCE_AFTER or _rng.randf() < rate * delta:
		_omen = 7.0
		_hud.toast("새 소리가 뚝 끊겼다. 숲이 이상하게 조용하다.", 4.5)


func _spawn_tiger() -> bool:
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	for _try in 14:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(42.0, 58.0)
		var sp := pp + Vector2.from_angle(ang) * dist
		if Region.danger_at(sp.x, sp.y) < 3:
			continue
		var t := Tiger.new()
		t.setup(_player, _survival, sp)
		t.gone.connect(_on_tiger_gone)
		t.bitten.connect(_on_bitten)
		get_parent().add_child(t)
		_tiger = t
		_hud.toast("어둠 속에서 호랑이가 나타났다!", 3.5)
		return true
	return false


func _on_tiger_gone() -> void:
	ActGoals.mark("a2_tiger")
	_cooldown = AFTER_GRACE
	_exposure = 0.0
	_omen = -1.0


func _on_bitten() -> void:
	_flash.color.a = 0.55
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.9)
