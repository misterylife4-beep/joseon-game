class_name RowBoat
extends Node3D
## 나루에 대어 둔 작은 평저선. 올라타면 W/S 로 노를 젓고 A/D 로 뱃머리를 돌린다. 얕은 곳이나 선착장에는 부딪혀 멈춘다.
## 평저선과 노(櫓)·삿대로 강을 건넌 것은 사료(고증_근거.md 11장). 속도·회전·부딪힘은 설계값이다.

signal blocked(msg: String)

const MAX_SPEED := 4.2
const FAST_SPEED := 5.6
const BACK_SPEED := 1.6
const BOARD_RANGE := 3.4
const MIN_DEPTH := 0.45

var length := 7.0
var rider: Player = null
var speed := 0.0
var stroke := 0.0
var _t := 0.0
var _bump_cd := 0.0


func _ready() -> void:
	add_to_group("boat")
	_t = randf() * 10.0


func seat_local() -> Vector3:
	return Vector3(0.0, 0.2, length * 0.12)


func seat_global() -> Vector3:
	return to_global(seat_local())


## 배 몸통(직사각형)까지의 수평 거리
func distance_to(p: Vector3) -> float:
	var lp := to_local(p)
	var dx := maxf(absf(lp.x) - 0.85, 0.0)
	var dz := maxf(absf(lp.z) - length * 0.5, 0.0)
	return Vector2(dx, dz).length()


func board(p: Player) -> void:
	rider = p
	p.riding = self
	p.swimming = false
	p.velocity = Vector3.ZERO
	p.global_position = seat_global()
	speed = 0.0


## 내려서 설 자리. 뭍이나 선착장이 가까이 있으면 그 위치, 없으면 Vector3.INF
func landing_spot() -> Vector3:
	for r in [2.6, 3.6, 5.0, 6.5]:
		for k in 16:
			var ang := rotation.y + float(k) * TAU / 16.0
			var q := global_position + Vector3(sin(ang), 0.0, cos(ang)) * float(r)
			var deck := HanRiver.pier_deck_at(q.x, q.z)
			if deck > -900.0:
				return Vector3(q.x, deck + 0.15, q.z)
			var h := HanyangMap.height(q.x, q.z)
			if h > HanyangMap.RIVER_LEVEL + 0.15 and h < HanyangMap.RIVER_LEVEL + 3.0:
				return Vector3(q.x, h + 0.15, q.z)
	return Vector3.INF


func leave_to(pos: Vector3) -> void:
	if rider == null:
		return
	var p := rider
	rider = null
	p.riding = null
	p.global_position = pos
	p.velocity = Vector3.ZERO
	speed = 0.0


func _water_ok(p: Vector3) -> String:
	if HanRiver.pier_deck_at(p.x, p.z, 0.5) > -900.0:
		return "pier"
	if p.z > WildWatch.water_limit_z(p.x):
		return "limit"
	if absf(p.z - HanyangMap.RIVER_Z) > 70.0 or absf(p.x) > 880.0:
		return "edge"
	if HanyangMap.RIVER_LEVEL - HanyangMap.height(p.x, p.z) < MIN_DEPTH:
		return "shallow"
	return ""


func _physics_process(delta: float) -> void:
	_t += delta
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	position.y = HanyangMap.RIVER_LEVEL + 0.1 + 0.03 * sin(_t * 1.3)
	rotation.z = 0.02 * sin(_t * 0.9)
	if rider == null:
		speed = 0.0
		return

	var inp := Vector2.ZERO
	var fast := false
	if not rider.input_locked:
		inp = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		fast = Input.is_action_pressed("sprint")
	var thrust := inp.y < -0.1
	var target := 0.0
	if thrust:
		target = (FAST_SPEED if fast else MAX_SPEED) * -inp.y
	elif inp.y > 0.1:
		target = -BACK_SPEED * inp.y
	if target != 0.0:
		speed = move_toward(speed, target, 2.2 * delta)
	else:
		speed = move_toward(speed, 0.0, (0.55 + 0.35 * absf(speed)) * delta)
	if thrust or inp.y > 0.1:
		stroke += delta * (3.6 if fast else 2.6) * (1.0 if thrust else -0.7)
	# 뱃머리: 속도가 있을수록 잘 돈다 (제자리에서도 노로 조금씩 돈다)
	var turn_rate := 0.35 + clampf(absf(speed) / 3.0, 0.0, 1.0) * 0.75
	rotation.y -= inp.x * turn_rate * delta
	if absf(inp.x) > 0.1 and not thrust:
		stroke += delta * 1.4

	var fwd := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	var np := global_position + fwd * speed * delta
	var half := length * 0.5
	var probes: Array[Vector3] = [
		np + fwd * (half + 0.4), np - fwd * (half + 0.2), np + side * 0.85, np - side * 0.85, np,
	]
	var why := ""
	for q in probes:
		why = _water_ok(q)
		if why != "":
			break
	if why == "":
		global_position.x = np.x
		global_position.z = np.z
	else:
		if absf(speed) > 0.8 and _bump_cd <= 0.0:
			_bump_cd = 4.0
			blocked.emit(_block_text(why))
		speed = -speed * 0.2
	rider.global_position = seat_global()
	rider.velocity = Vector3.ZERO


static func _block_text(why: String) -> String:
	match why:
		"limit":
			return "아직 한양을 떠날 수 없다. 강 건너는 1막을 마친 뒤에 갈 수 있다."
		"pier":
			return "배가 선착장 기둥에 부딪혔다. 뱃머리를 돌려 비켜 가자."
		"edge":
			return "더 나아갈 물길이 없다. 뱃머리를 돌리자."
	return "배 바닥이 모래에 닿았다. 뱃머리를 돌려 물길로 나가자."
