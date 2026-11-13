class_name Player
extends CharacterBody3D
## 3인칭 플레이어. 마우스로 카메라 회전, WASD 이동, Shift 달리기, Space 점프.

@export var walk_speed := 5.0
@export var sprint_speed := 9.0
@export var jump_velocity := 6.0
@export var mouse_sensitivity := 0.0025

var input_locked := false
## 가려는 속도(걷기/달리기). 사람과 부딪혔을 때 부딪힌 세기를 정하는 데 쓴다.
var intent_speed := 0.0
## 타고 있는 배 (없으면 null)
var riding: RowBoat = null
## 깊은 물에서 헤엄치는 중인가
var swimming := false
## 숨이 가쁠 때 헤엄 속도를 줄이는 배율 (WaterTravel 이 정한다)
var swim_speed_mul := 1.0
## 빠르게 헤엄치는 중인가 (숨이 더 빨리 닳는다)
var swim_fast := false
## Z 를 누르고 있으면 엎드려 절한다 (왕 행차 때). 엎드린 동안은 움직이지 못한다.
var bowing := false
## 카메라 흔들림 세기(맞았을 때) — add_shake 로 올리고 저절로 줄어든다
var _shake := 0.0
var _knock := Vector3.ZERO
var _stun_gen := 0
## 어가 앞에서 붙잡혀 끌려가는 중 (royal_procession.gd)
var arrested := false
## 물이나 배에서 내린 지 얼마 안 됐으면 양수 (나룻배 자동 승선을 막는다)
var water_recent := 0.0

const SWIM_SPEED := 2.3
const SWIM_FAST := 3.4
const SWIM_DEPTH_IN := 1.0
const SWIM_DEPTH_OUT := 0.8
## 물에 잠긴 깊이(m): 발이 물 면 아래로 얼마나 내려갔나. 걸어서 건너는 얕은 물의 깊이다.
var wade_depth := 0.0
## 옷이 젖은 정도 0~1. 헤엄치거나 물을 걸으면 오르고 시간이 지나면 마른다 (survival.gd 가 체온에 반영)
var wetness := 0.0
var _climb_t := -1.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw := 0.0
var _pitch := -0.3
var _model: Node3D
var _person: Person
var _lantern: Torch
var _cam_pivot: Node3D
var _spring: SpringArm3D
var _camera: Camera3D


func _ready() -> void:
	add_to_group("player")
	collision_mask = 3  # 1: 세상, 2: 사람 몸통
	_build_body()
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	# 1막 주인공 견습 서리 도윤: 직령포에 갓, 등에 서류 보퉁이 (복식은 docs/고증_근거.md 10장)
	_model = Node3D.new()
	add_child(_model)
	_person = Person.new()
	# 사람 모델은 +Z가 앞이라 반 바퀴 돌려 -Z를 앞으로 맞춘다
	_person.setup(Person.Kind.PROTAGONIST, Person.Act.LOCO, Vector3.ZERO, PI, 0)
	_model.add_child(_person)
	# 밤길을 밝히는 등롱 (손에 든 모습)
	_lantern = Torch.new()
	var lantern := _lantern
	lantern.style = Torch.Style.LANTERN
	lantern.power = 1.6
	lantern.light_range = 12.0
	lantern.position = Vector3(-0.38, 0.78, -0.3)
	lantern.visible = false
	_model.add_child(lantern)


func _build_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.top_level = true
	add_child(_cam_pivot)

	_spring = SpringArm3D.new()
	_spring.spring_length = 5.0
	_spring.margin = 0.3
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_spring.shape = probe
	_cam_pivot.add_child(_spring)
	_spring.add_excluded_object(get_rid())

	_camera = Camera3D.new()
	_camera.far = 1200.0
	_camera.fov = 62.0
	_spring.add_child(_camera)
	_camera.make_current()


func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -1.2, 0.4)


## 이 자리의 물 깊이(m). 강물 면이 없는 곳은 0.
func water_depth() -> float:
	var x := global_position.x
	var z := global_position.z
	if absf(x) > 890.0 or absf(z - HanyangMap.RIVER_Z) > 72.0:
		return 0.0
	return maxf(HanyangMap.RIVER_LEVEL - HanyangMap.height(x, z), 0.0)


## 발이 강물 면 아래로 내려간 깊이. 선착장 위나 뭍이면 0.
func submerge() -> float:
	var x := global_position.x
	var z := global_position.z
	if absf(x) > 890.0 or absf(z - HanyangMap.RIVER_Z) > 72.0:
		return 0.0
	return maxf(HanyangMap.RIVER_LEVEL - global_position.y, 0.0)


## 한양 개천 물에 잠긴 깊이. 수면은 둑 높이보다 0.6 m 낮다 (hanyang_city.gd 의 물 면과 같은 값).
func stream_submerge() -> float:
	var x := global_position.x
	var z := global_position.z
	if x < HanyangMap.STREAM_X0 + 10.0 or x > 246.0 or absf(z - HanyangMap.stream_z(x)) > 5.0:
		return 0.0
	return maxf(HanyangMap.height_no_carve(x, HanyangMap.stream_z(x)) - 0.6 - global_position.y, 0.0)


func _update_wetness(delta: float) -> void:
	var target := 0.0
	var rate := 0.0125  # 마르는 데 약 80초
	if swimming:
		target = 1.0
		rate = 0.5
	elif wade_depth > 0.12:
		target = clampf(0.25 + wade_depth * 0.6, 0.0, 0.8)
		rate = 0.35
	if target > wetness:
		wetness = move_toward(wetness, target, rate * delta)
	elif target == 0.0:
		wetness = move_toward(wetness, 0.0, rate * delta)


## 앞쪽에 짚고 올라설 수 있는 턱(발판·뭍 가장자리)의 윗면 위치. 없으면 Vector3.INF.
func ledge_ahead() -> Vector3:
	var fwd := -_model.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return Vector3.INF
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var feet := global_position.y
	for d in [0.6, 1.0]:
		var o := global_position + fwd * float(d)
		var q := PhysicsRayQueryParameters3D.create(Vector3(o.x, feet + 2.4, o.z), Vector3(o.x, feet + 0.1, o.z), 1)
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		if h.is_empty():
			continue
		var pos: Vector3 = h["position"]
		var nrm: Vector3 = h["normal"]
		if nrm.y > 0.6 and pos.y > feet + 0.5 and pos.y < feet + 2.1:
			return pos + fwd * 0.3
	return Vector3.INF


func _try_climb() -> bool:
	var top := ledge_ahead()
	if top == Vector3.INF:
		return false
	_climb_from = global_position
	_climb_to = Vector3(top.x, top.y + 0.05, top.z)
	_climb_t = 0.0
	swimming = false
	return true


func _update_swim_state() -> void:
	var d := water_depth()
	if swimming:
		if d < SWIM_DEPTH_OUT:
			swimming = false
	elif d > SWIM_DEPTH_IN and global_position.y < HanyangMap.RIVER_LEVEL + 0.25:
		swimming = true
		velocity.y *= 0.2


func _ride(delta: float) -> void:
	velocity = Vector3.ZERO
	intent_speed = 0.0
	_model.rotation.y = lerp_angle(_model.rotation.y, riding.rotation.y, 10.0 * delta)
	_person.water_pose = 1
	_person.water_phase = riding.stroke
	_person.set_locomotion(0.0, true)


func _swim(delta: float) -> void:
	var dir := Vector3.ZERO
	if not input_locked:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Basis(Vector3.UP, _yaw) * Vector3(inp.x, 0.0, inp.y)
	swim_fast = Input.is_action_pressed("sprint") and dir.length() > 0.01 and swim_speed_mul > 0.7
	var spd := (SWIM_FAST if swim_fast else SWIM_SPEED) * swim_speed_mul
	intent_speed = spd if dir.length() > 0.01 else 0.0
	# 평영은 차는 순간 빠르고 팔을 모을 때 느리다
	spd *= Person.swim_surge(_person.water_phase)
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * spd, spd * 3.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, spd * 3.0 * delta)
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, spd * 2.0 * delta + 0.5 * delta)
		velocity.z = move_toward(velocity.z, 0.0, spd * 2.0 * delta + 0.5 * delta)
	# 물 면에 가슴까지 잠겨 떠 있는다
	var t := Time.get_ticks_msec() * 0.001
	var surface_y := HanyangMap.RIVER_LEVEL - 1.15 + 0.04 * sin(t * 2.0)
	velocity.y = (surface_y - global_position.y) * 6.0
	move_and_slide()
	var sp := Vector2(velocity.x, velocity.z).length()
	_person.water_pose = 2
	_person.swim_move = 1.0 if dir.length() > 0.01 else clampf(sp / 1.2, 0.0, 1.0)
	# 평영 한 주기는 약 1.5초(빠르면 1.1초), 제자리에서는 느리게 물을 젓는다
	_person.water_phase += delta * lerpf(2.2, 4.2 + sp * 0.35, _person.swim_move)
	_person.set_locomotion(0.0, true)


func _physics_process(delta: float) -> void:
	if _climb_t >= 0.0:
		_climb_t += delta / 0.45
		var k := minf(_climb_t, 1.0)
		var cp := _climb_from.lerp(_climb_to, k)
		cp.y += sin(k * PI) * 0.45
		global_position = cp
		velocity = Vector3.ZERO
		_person.water_pose = 0
		_person.set_locomotion(0.0, true)
		if _climb_t >= 1.0:
			_climb_t = -1.0
		return
	if riding != null:
		water_recent = 6.0
		_ride(delta)
		return
	water_recent = maxf(water_recent - delta, 0.0)
	_update_swim_state()
	wade_depth = maxf(submerge(), stream_submerge())
	_update_wetness(delta)
	if not input_locked and Input.is_action_just_pressed("jump") and (swimming or wade_depth > 0.3):
		if _try_climb():
			return
	if swimming:
		water_recent = 6.0
		_swim(delta)
		return
	swim_fast = false
	_person.water_pose = 0
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var dir := Vector3.ZERO
	if not input_locked:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Basis(Vector3.UP, _yaw) * Vector3(inp.x, 0.0, inp.y)
		bowing = Input.is_key_pressed(KEY_Z) and is_on_floor() and wade_depth < 0.3
		if bowing:
			dir = Vector3.ZERO
		elif Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
	else:
		bowing = false

	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if wade_depth > 0.2:
		speed *= lerpf(1.0, 0.55, clampf((wade_depth - 0.2) / 0.8, 0.0, 1.0))
	intent_speed = speed if dir.length() > 0.01 else 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * speed, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, speed * 8.0 * delta)
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

	if _knock.length() > 0.1:
		velocity.x = _knock.x
		velocity.z = _knock.z
		_knock = _knock.move_toward(Vector3.ZERO, 14.0 * delta)
	move_and_slide()
	_person.prostrate = bowing
	_person.set_locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor())


## 짐승에게 맞았을 때 화면이 흔들린다. a 는 0~1.
func add_shake(a: float) -> void:
	_shake = maxf(_shake, clampf(a, 0.0, 1.5))


## 덮쳐 넘어뜨리거나 들이받아 밀어낸다. dir 방향으로 impulse(m/s) 만큼 밀리고, stun 초 동안 움직일 수 없다.
## fall 이 참이면 뒤로 넘어졌다가 일어난다. 대화·연출로 이미 입력이 잠긴 때는 밀리기만 한다.
func stagger(dir: Vector3, impulse: float, stun: float, fall := false) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() > 0.01:
		_knock = d.normalized() * impulse
	if input_locked or stun <= 0.0:
		return
	input_locked = true
	_stun_gen += 1
	var gen := _stun_gen
	if fall:
		_person.fallen = true
	get_tree().create_timer(stun).timeout.connect(func() -> void:
		if gen == _stun_gen:
			input_locked = false
			_person.fallen = false)


## 끌려갈 때처럼 밖에서 몸의 방향을 정한다 (x, z 평면 방향).
func face_toward(dir: Vector2) -> void:
	if dir.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.y), 0.2)


func _process(_delta: float) -> void:
	# 등롱은 해가 지고 불이 켜질 때(Torch 와 같은 기준)만 들고 다닌다. 낮에는 들지 않는다.
	_lantern.visible = DayNight.night_amount > 0.05
	_shake = move_toward(_shake, 0.0, _delta * 2.2)
	var sh := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.12
	_cam_pivot.global_position = global_position + Vector3(0, 1.6, 0) + sh
	_cam_pivot.rotation = Vector3(_pitch + sh.y * 0.3, _yaw + sh.x * 0.3, sh.x * 0.6)
