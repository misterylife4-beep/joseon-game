class_name FaceKit
extends Node
## 주인공 얼굴. 눈(흰자·눈동자·시선), 눈썹, 입술, 볼·코끝의 붉은 기운, 추울 때 입김을 움직이는 조각으로 만들어 머리에 얹는다.
## 표정은 눈썹 기울기·높이, 눈 찡그림, 입꼬리, 입 벌림, 볼 붉기 다섯 값으로 정하고 생존 수치(추위·허기·마음·기력)와 모닥불 곁인지에 따라 부드럽게 바뀐다.
## 크기와 위치는 설계값이고 실제 인체 비율(눈은 머리 높이의 가운데쯤, 눈 사이는 눈 하나 폭, 입 폭은 두 눈동자 안쪽 사이쯤)을 따랐다.
## 머리 로컬 좌표: 얼굴 앞면이 +Z, 눈 높이 y=0.118, 눈썹 y=0.138, 코끝 y=0.078, 입 y=0.04.
## lite=true 이면 NPC용 가벼운 얼굴이다. 눈동자 점·볼·코끝·입김을 빼고, 표정은 하는 일(act)과 계절·성별·나이로 정하며,
## 카메라가 가까우면 눈이 카메라 쪽을 본다. 개인차(눈매·눈 크기·눈썹 굵기·입술 두께·광대·주름)는 Person._add_traits 가 정한 값을 읽는다.

var lite := false
var _person: Person
var _age := 1
var _beard_z := 0.0
var _survival: Survival
var _head: Node3D
var _parts: Node3D
var _fw := 1.0
var _skin := Color(0.8, 0.6, 0.45)
var _hair := Color(0.05, 0.04, 0.04)

var _brow: Array[MeshInstance3D] = []
var _eye: Array[Node3D] = []
var _iris: Array[Node3D] = []
var _cheek: Array[MeshInstance3D] = []
var _cheek_mat: StandardMaterial3D
var _nose_tip: MeshInstance3D
var _nose_mat: StandardMaterial3D
var _lip_up: MeshInstance3D
var _lip_low: MeshInstance3D
var _corner: Array[MeshInstance3D] = []
var _inside: MeshInstance3D
var _breath: GPUParticles3D

# 현재 표정 값 (목표를 향해 부드럽게 따라간다)
var _brow_raise := 0.0
var _brow_inner := 0.0
var _squint := 0.0
var _curve := 0.0
var _open := 0.0
var _flush := 0.0

var _t := randf() * 50.0
var _gaze := Vector2.ZERO
var _gaze_goal := Vector2.ZERO
var _gaze_wait := 1.0
var _check := 0.0
var _breath_t := 0.0


func setup(person: Person, is_lite: bool = false) -> void:
	_person = person
	lite = is_lite


func _exit_tree() -> void:
	if _parts != null and is_instance_valid(_parts):
		_parts.queue_free()


func _process(delta: float) -> void:
	if _person == null:
		return
	_t += delta
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		# 계절 옷이 바뀌면 사람 모델이 다시 만들어진다. 머리가 바뀌었으면 얼굴 조각을 새로 붙인다.
		var h: Node3D = _person._head
		if h != null and (_parts == null or not is_instance_valid(_parts) or _head != h):
			_attach(h)
		if _survival == null and not lite:
			for c in get_parent().get_parent().get_children():
				if c is Survival:
					_survival = c
	if _parts == null or not is_instance_valid(_parts):
		return
	_update_expression(delta)
	_apply()
	_update_breath(delta)


# --- 만들기 ---

func _attach(h: Node3D) -> void:
	if _parts != null and is_instance_valid(_parts):
		_parts.queue_free()
	_head = h
	var o := _person._outfit()
	_skin = o["skin"]
	_skin.a = 1.0
	_hair = o["hair"]
	_hair.a = 1.0
	_age = int(o["age"])
	var ck: float = o["cheek"]
	_fw = float(o["face_w"]) * ck
	_beard_z = 0.014 if int(o["beard"]) == 2 else 0.0
	var ew: float = o["eye_w"] * (1.22 if _age < 0 else 1.0)
	var eh: float = 1.15 if _age < 0 else 1.0
	var slant: float = o["eye_slant"] * (0.5 if _age < 0 else 1.0)
	var bt: float = o["brow_t"] * (0.8 if _age < 0 else 1.0)
	var lp: float = o["lip"] * (0.85 if _age < 0 else 1.0)
	_parts = Node3D.new()
	_parts.scale = Vector3(1.0, float(o["face_len"]), 1.0)
	h.add_child(_parts)
	_brow.clear()
	_eye.clear()
	_iris.clear()
	_cheek.clear()
	_corner.clear()

	var white := _mat(Color(0.93, 0.91, 0.87))
	var iris_m := _mat(Color(0.14, 0.08, 0.05))
	var pupil_m := _mat(Color(0.01, 0.01, 0.01))
	var brow_m := _mat(_hair)
	for sgn in [-1.0, 1.0]:
		var s: float = sgn
		# 눈: 흰자, 갈색 눈동자, 검은 동자. 눈꺼풀 깜빡임은 Person이 얹은 피부색 조각이 덮는다.
		var eye := Node3D.new()
		eye.position = Vector3(s * 0.036 * _fw, 0.118, 0.0925)
		# 눈매: 바깥쪽 끝이 안쪽보다 조금 올라간다
		eye.rotation.z = s * slant
		_parts.add_child(eye)
		eye.add_child(_ell(Vector3.ZERO, Vector3(0.0125 * ew, 0.0072 * ew * eh, 0.0055), white))
		var iris := Node3D.new()
		iris.position = Vector3(0.0, 0.0, 0.0055)
		eye.add_child(iris)
		iris.add_child(_ell(Vector3.ZERO, Vector3(0.0058 * ew * eh, 0.0058 * ew * eh, 0.0028), iris_m))
		if not lite:
			iris.add_child(_ell(Vector3(0.0, 0.0, 0.0022), Vector3(0.0028, 0.0028, 0.0014), pupil_m))
		_eye.append(eye)
		_iris.append(iris)
		# 눈썹
		var br := _ell(Vector3(s * 0.037 * _fw, 0.138, 0.0945), Vector3(0.024, 0.0048 * bt, 0.0055), brow_m)
		_parts.add_child(br)
		_brow.append(br)

	# 볼과 코끝의 붉은 기운(추울 때 트고 붉어진다)
	_cheek_mat = StandardMaterial3D.new()
	_cheek_mat.albedo_color = Color(0.8, 0.2, 0.16, 0.0)
	_cheek_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cheek_mat.roughness = 1.0
	for sgn in [-1.0, 1.0]:
		if lite:
			break
		var s2: float = sgn
		var c := _ell(Vector3(s2 * 0.052 * _fw, 0.088, 0.0795), Vector3(0.022, 0.015, 0.006), _cheek_mat)
		c.rotation.y = s2 * 0.5
		_parts.add_child(c)
		_cheek.append(c)
	_nose_mat = StandardMaterial3D.new()
	_nose_mat.albedo_color = Color(0.8, 0.2, 0.16, 0.0)
	_nose_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_nose_mat.roughness = 1.0
	if not lite:
		_nose_tip = _ell(Vector3(0.0, 0.072, 0.121), Vector3(0.0105, 0.0085, 0.0055), _nose_mat)
		_parts.add_child(_nose_tip)

	# 입: 윗입술은 아랫입술보다 얇고 조금 앞으로 나온다. 입꼬리는 따로 움직인다.
	var lip_m_up := _mat(Color(_skin.r * 0.8, _skin.g * 0.5, _skin.b * 0.48))
	var lip_m_low := _mat(Color(_skin.r * 0.86, _skin.g * 0.55, _skin.b * 0.52))
	_lip_up = _ell(Vector3(0.0, 0.0445, 0.0855 + _beard_z), Vector3(0.0215 * lp, 0.0032 * lp, 0.0055), lip_m_up)
	_lip_low = _ell(Vector3(0.0, 0.0365, 0.0855 + _beard_z), Vector3(0.0195 * lp, 0.0042 * lp, 0.0055), lip_m_low)
	_parts.add_child(_lip_up)
	_parts.add_child(_lip_low)
	for sgn in [-1.0, 1.0]:
		var s3: float = sgn
		var cn := _ell(Vector3(s3 * 0.021, 0.04, 0.0825), Vector3(0.007, 0.0028, 0.005), lip_m_up)
		_parts.add_child(cn)
		_corner.append(cn)
	_inside = _ell(Vector3(0.0, 0.04, 0.0845 + _beard_z), Vector3(0.016, 0.0, 0.004), _mat(Color(0.18, 0.04, 0.04)))
	_inside.visible = false
	_parts.add_child(_inside)

	# 주름: 나이 든 얼굴만. 이마 가로줄, 눈꼬리 잔주름, 코 옆에서 입꼬리로 내려오는 팔자주름.
	if _age >= 2:
		var wr := _mat(Color(_skin.r * 0.74, _skin.g * 0.68, _skin.b * 0.66))
		for k in 2:
			_parts.add_child(_ell(Vector3(0.0, 0.158 + 0.012 * k, 0.0915 - 0.002 * k), Vector3(0.026 - 0.004 * k, 0.0011, 0.003), wr))
		for sgn in [-1.0, 1.0]:
			var s4: float = sgn
			var nl := _ell(Vector3(s4 * 0.027, 0.06, 0.0825), Vector3(0.0035, 0.015, 0.003), wr)
			nl.rotation.z = s4 * 0.35
			_parts.add_child(nl)
			var cf := _ell(Vector3(s4 * (0.036 * _fw + 0.019), 0.112, 0.0765), Vector3(0.008, 0.0012, 0.003), wr)
			cf.rotation.y = s4 * 0.8
			cf.rotation.z = s4 * 0.3
			_parts.add_child(cf)
	if lite:
		return

	# 입김
	_breath = GPUParticles3D.new()
	_breath.amount = 6
	_breath.lifetime = 1.3
	_breath.local_coords = false
	_breath.randomness = 0.5
	_breath.emitting = false
	_breath.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	_breath.position = Vector3(0.0, 0.036, 0.11 + _beard_z)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.15, 1.0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.0, 0.12, 0.0)
	pm.damping_min = 0.5
	pm.damping_max = 0.9
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.3))
	cv.add_point(Vector2(1.0, 2.0))
	var ct := CurveTexture.new()
	ct.curve = cv
	pm.scale_curve = ct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_breath.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = FireFx._blob()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = qm
	_breath.draw_pass_1 = q
	_parts.add_child(_breath)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _ell(pos: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 10
	sp.rings = 5
	mi.mesh = sp
	mi.material_override = mat
	mi.position = pos
	mi.scale = radii * 2.0
	mi.visibility_range_end = 30.0
	return mi


# --- 표정 ---

func _update_lite(delta: float) -> void:
	var p := _person
	var cold_f := clampf(Season.cold * 0.75 + 0.2 * DayNight.night_amount, 0.0, 1.0)
	var goal_raise := 0.0
	var goal_inner := -0.5 * cold_f
	var goal_squint := 0.35 * cold_f
	var goal_curve := -0.1 * cold_f
	var goal_open := 0.0
	var goal_flush := cold_f * 0.5
	if p.kind == Person.Kind.OFFICIAL or p.kind == Person.Kind.YANGBAN or p.kind == Person.Kind.SOLDIER:
		goal_inner -= 0.12
		goal_curve -= 0.08
	if p.kind == Person.Kind.CHILD:
		goal_curve += 0.25
		goal_raise += 0.1
	match p.act:
		Person.Act.HAMMER, Person.Act.CARRY, Person.Act.PLANE, Person.Act.TAMP, Person.Act.DRILL:
			# 힘쓰는 일: 눈썹을 모으고 눈을 가늘게 뜨고 얼굴이 붉어진다
			goal_inner -= 0.4
			goal_squint = maxf(goal_squint, 0.28)
			goal_flush += 0.3
			goal_curve -= 0.1
		Person.Act.TALK:
			goal_raise += 0.12
			goal_curve += 0.15
			if p._mouth != null and p._mouth.visible:
				goal_open = clampf(p._mouth.scale.y / 0.014, 0.0, 1.0) * 0.75
		Person.Act.KITE, Person.Act.TOP:
			goal_curve += 0.6
			goal_raise += 0.2
		Person.Act.SIT, Person.Act.WASH:
			goal_curve += 0.05
	var k := clampf(delta * 4.0, 0.0, 1.0)
	_brow_raise = lerpf(_brow_raise, goal_raise, k)
	_brow_inner = lerpf(_brow_inner, goal_inner, k)
	_squint = lerpf(_squint, goal_squint, k)
	_curve = lerpf(_curve, goal_curve, k)
	_open = lerpf(_open, goal_open, k)
	_flush = lerpf(_flush, goal_flush, k * 0.4)
	# 시선: 평소엔 두리번거리고, 카메라가 가까이 앞에 있으면 가끔 눈이 마주친다
	_gaze_wait -= delta
	if _gaze_wait <= 0.0:
		_gaze_wait = randf_range(1.5, 4.0)
		_gaze_goal = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5))
		var cam := get_viewport().get_camera_3d()
		if cam != null and _head != null and is_instance_valid(_head):
			var lc: Vector3 = _head.global_transform.affine_inverse() * cam.global_position
			if lc.z > 0.3 and lc.length() < 8.0 and fmod(_t * 0.37, 1.0) < 0.65:
				_gaze_goal = Vector2(clampf(lc.x / lc.z * 2.5, -1.0, 1.0), clampf((lc.y - 0.118) / lc.z * 2.5, -0.5, 0.5))
	_gaze = _gaze.lerp(_gaze_goal, clampf(delta * 8.0, 0.0, 1.0))


func _update_expression(delta: float) -> void:
	if lite:
		_update_lite(delta)
		return
	var warmth := 100.0 - Season.cold * 50.0
	var hunger := 100.0
	var morale := 70.0
	var stamina := 100.0
	var health := 100.0
	var fire := false
	var tired := false
	if _survival != null:
		warmth = _survival.warmth
		hunger = _survival.hunger
		morale = _survival.morale
		stamina = _survival.stamina
		health = _survival.health
		fire = _survival.near_fire()
		tired = _survival._exhausted
	var cold_f := clampf((60.0 - warmth) / 60.0, 0.0, 1.0)
	var sad_f := clampf(maxf(maxf((40.0 - morale) / 40.0, (35.0 - hunger) / 35.0), (35.0 - health) / 35.0), 0.0, 1.0)
	var happy_f := 0.5 if (fire and warmth > 50.0) else (0.3 if morale > 75.0 else 0.0)
	var tired_f := clampf((40.0 - stamina) / 40.0, 0.0, 1.0)
	if tired:
		tired_f = maxf(tired_f, 0.8)

	var goal_raise := 0.25 * happy_f - 0.1 * cold_f + 0.12 * sad_f
	var goal_inner := -0.55 * cold_f + 0.75 * sad_f
	var goal_squint := clampf(0.5 * cold_f + 0.35 * tired_f, 0.0, 0.65)
	var goal_curve := 0.8 * happy_f - 0.6 * sad_f - 0.25 * cold_f
	var goal_open := 0.65 * tired_f
	var goal_flush := clampf(cold_f * 0.75 + tired_f * 0.25, 0.0, 1.0)
	var k := clampf(delta * 3.0, 0.0, 1.0)
	_brow_raise = lerpf(_brow_raise, goal_raise, k)
	_brow_inner = lerpf(_brow_inner, goal_inner, k)
	_squint = lerpf(_squint, goal_squint, k)
	_curve = lerpf(_curve, goal_curve, k)
	_open = lerpf(_open, goal_open, k)
	_flush = lerpf(_flush, goal_flush, k * 0.4)

	# 시선: 가만히 있지 않고 1~3초마다 조금씩 옮긴다
	_gaze_wait -= delta
	if _gaze_wait <= 0.0:
		_gaze_wait = randf_range(1.0, 3.0)
		_gaze_goal = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5))
	_gaze = _gaze.lerp(_gaze_goal, clampf(delta * 8.0, 0.0, 1.0))


func _apply() -> void:
	var micro := 0.0015 * sin(_t * 0.9)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var b := _brow[i]
		var inner_down := maxf(-_brow_inner, 0.0)
		b.position = Vector3(
			s * 0.037 * _fw * (1.0 - 0.12 * inner_down),
			0.138 + 0.010 * _brow_raise - 0.004 * inner_down - 0.002 * _squint + micro,
			0.0945)
		# 바깥쪽 끝 기준으로 안쪽 끝을 올리거나(걱정) 내린다(찡그림)
		b.rotation.z = -s * _brow_inner * 0.4
		# 눈 찡그림: 눈이 가늘어지고 시선이 눈동자를 따라 움직인다
		_eye[i].scale = Vector3(1.0, 1.0 - 0.5 * _squint, 1.0)
		_iris[i].position = Vector3(_gaze.x * 0.0035, _gaze.y * 0.0018, 0.0055)

	_cheek_mat.albedo_color.a = 0.38 * _flush
	_nose_mat.albedo_color.a = 0.5 * _flush

	# 입꼬리: 웃으면 올라가고 기운이 없으면 처진다
	for i in 2:
		var s2 := -1.0 if i == 0 else 1.0
		var cn := _corner[i]
		cn.position = Vector3(s2 * (0.021 + 0.002 * _curve), 0.04 + 0.0065 * _curve - 0.0018 * _open, 0.0825 + _beard_z)
		cn.rotation.z = s2 * _curve * 0.55
	# 입 벌림: 아랫입술이 내려가고 안쪽이 어둡게 보인다
	_lip_low.position.y = 0.0365 - 0.011 * _open
	_lip_up.position.y = 0.0445 + 0.0015 * _open
	_inside.visible = _open > 0.08
	if _inside.visible:
		_inside.position.y = 0.04 - 0.0045 * _open
		_inside.scale = Vector3(0.032, 0.014 * _open, 0.008)


func _update_breath(delta: float) -> void:
	if _breath == null:
		return
	# 추우면 숨 쉴 때마다 입김이 난다. 달리면 숨이 가빠 더 자주 난다.
	var cold := Season.cold + 0.25 * DayNight.night_amount
	if cold < 0.45:
		_breath.emitting = false
		return
	var cycle := 3.4 - 1.4 * clampf(_open + _flush * 0.4, 0.0, 1.0)
	_breath_t += delta
	if _breath_t > cycle:
		_breath_t = 0.0
	_breath.emitting = _breath_t < 0.55
