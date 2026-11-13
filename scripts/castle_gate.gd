class_name CastleGate
extends Node3D
## 도성 성문. 로컬 +Z가 성 밖이다. 석축 기단에 홍예 대신 문틈을 내고 문루를 올린다.
## 규모와 모양은 모두 설계값이다(docs/고증_근거.md). 대문은 2층 지붕, 소문은 1층 지붕.

var gate_name := ""
var big := true
var span := 20.0
var _doors: Array[Node3D] = []
var _door_bodies: Array[StaticBody3D] = []
var _door_open := 1.0


func setup(n: String, is_big: bool, pos: Vector3, yaw: float) -> void:
	gate_name = n
	big = is_big
	span = 20.0 if big else 14.0
	position = pos
	rotation.y = yaw
	_build()


func _build() -> void:
	var depth := 8.0 if big else 6.0
	var base_h := 6.5 if big else 5.5
	var open_w := 4.2 if big else 3.2
	var open_h := 4.6 if big else 3.8
	var stone := Hanok.shared_mat(Color(0.5, 0.48, 0.44), 0.95)
	var side_w := (span - open_w) * 0.5

	# 좌우 석축은 땅속으로 1m 묻는다
	for sx in [-1.0, 1.0]:
		_solid(
			Vector3(side_w, base_h + 1.0, depth),
			Vector3(sx * (open_w + side_w) * 0.5, (base_h - 1.0) * 0.5, 0.0),
			stone
		)
	# 문틈 위 가로 석축
	_solid(
		Vector3(open_w + 0.2, base_h - open_h, depth),
		Vector3(0.0, open_h + (base_h - open_h) * 0.5, 0.0),
		stone
	)

	# 성문 앞 횃불: 석축 위 앞쪽 가장자리 양쪽
	for sx in [-1.0, 1.0]:
		var tx: float = sx
		var tc := Torch.new()
		tc.position = Vector3(tx * (open_w * 0.5 + 1.4), base_h, depth * 0.5 - 0.6)
		tc.light_range = 20.0
		add_child(tc)

	# 수문장 한 명과 군졸 한 명: 문 양옆 성 밖에 선다 (인원과 자세는 설계값, 문마다 수문장 배치는 정도전의 궁문 시위 제안과 같은 맥락의 추정)
	for gi in 2:
		var gx := -1.0 if gi == 0 else 1.0
		var glx := gx * (open_w * 0.5 + 1.0)
		var glz := depth * 0.5 + 1.2
		var guard := Person.new().setup(
			Person.Kind.SOLDIER, Person.Act.IDLE,
			Vector3(glx, _ground_local(glx, glz), glz), 0.0, 3 if gi == 0 else (gi + 1) % 3
		)
		add_child(guard)

	if gate_name != "광화문":
		_build_doors(open_w, open_h)
	_apron(open_w, depth, 1.0)
	_apron(open_w, depth, -1.0)

	# 문루
	var lower := Hanok.new()
	if big:
		lower.setup(Hanok.Style.TILE, 5, 1, Vector3(0.0, base_h, 0.0), 0.0, true)
		add_child(lower)
		var upper := Hanok.new()
		upper.setup(Hanok.Style.TILE, 3, 1, Vector3(0.0, base_h + 4.2, 0.0), 0.0, true)
		add_child(upper)
	else:
		lower.setup(Hanok.Style.TILE, 3, 1, Vector3(0.0, base_h, 0.0), 0.0, true)
		add_child(lower)

	var label := Label3D.new()
	label.text = gate_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, base_h + (12.0 if big else 8.0), 0.0)
	label.font_size = 64
	label.pixel_size = 0.014
	label.outline_size = 14
	label.visibility_range_end = 260.0
	add_child(label)


func _solid(size: Vector3, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	add_child(body)


## 문짝: 인정(밤 10시쯤) 종이 울리면 닫고 파루(새벽 4시쯤)에 연다. 시각은 사료의 대략값이고 문짝 모양은 설계값이다.
func _build_doors(open_w: float, open_h: float) -> void:
	var wood := Hanok.shared_mat(Color(0.2, 0.13, 0.09), 0.9)
	var iron := Hanok.shared_mat(Color(0.12, 0.12, 0.13), 0.6)
	var leaf_w := open_w * 0.5
	for sx in [-1.0, 1.0]:
		var sg: float = sx
		var pivot := Node3D.new()
		pivot.position = Vector3(sg * open_w * 0.5, 0.0, 0.0)
		add_child(pivot)
		var body := StaticBody3D.new()
		body.position = Vector3(-sg * leaf_w * 0.5, open_h * 0.5, 0.0)
		pivot.add_child(body)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(leaf_w, open_h, 0.22)
		mi.mesh = bm
		mi.material_override = wood
		mi.visibility_range_end = 200.0
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bm.size
		cs.shape = shape
		body.add_child(cs)
		# 쇠 징(문정): 앞면에 3줄 × 5줄
		var studs := MultiMesh.new()
		studs.transform_format = MultiMesh.TRANSFORM_3D
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.1
		sm.radial_segments = 6
		sm.rings = 3
		studs.mesh = sm
		studs.instance_count = 15
		var n := 0
		for ix in 3:
			for iy in 5:
				var px := (float(ix) - 1.0) * leaf_w * 0.28
				var py := (float(iy) - 2.0) * open_h * 0.19
				studs.set_instance_transform(n, Transform3D(Basis(), Vector3(px, py, 0.13)))
				n += 1
		var smi := MultiMeshInstance3D.new()
		smi.multimesh = studs
		smi.material_override = iron
		smi.visibility_range_end = 60.0
		body.add_child(smi)
		_doors.append(pivot)
		_door_bodies.append(body)
	_apply_doors(1.0)


func _apply_doors(open_amt: float) -> void:
	for i in _doors.size():
		var sg := -1.0 if i == 0 else 1.0
		_doors[i].rotation.y = sg * 1.4 * open_amt
		_door_bodies[i].collision_layer = 1 if open_amt < 0.5 else 0


func _process(delta: float) -> void:
	var h: float = DayNight.hour_now
	var want := 0.0 if (h >= 22.0 or h < 4.0) else 1.0
	if absf(_door_open - want) > 0.001:
		_door_open = move_toward(_door_open, want, delta * 0.35)
		_apply_doors(_door_open)


## 성문 로컬 좌표(x, z)에서의 지면 높이(성문 기준 상대값)
func _ground_local(lx: float, lz: float) -> float:
	var w := position + Basis(Vector3.UP, rotation.y) * Vector3(lx, 0.0, lz)
	return HanyangMap.height(w.x, w.z) - position.y


## 문 바닥과 바깥(안쪽) 지면의 높이 차를 낮은 계단으로 잇는다. 그렇지 않으면 단차에 걸려 문으로 들어갈 수 없다.
## 계단 크기는 설계값이다. side=+1 성 밖, -1 성 안.
func _apron(open_w: float, depth: float, side: float) -> void:
	var run := 1.0
	var n_max := 14
	var edge := side * depth * 0.5
	var g_end := _ground_local(0.0, edge + side * run * float(n_max))
	if g_end > -0.15:
		return  # 거의 평평하거나 오르막이면 필요 없다
	var n := clampi(int(ceilf(absf(g_end) / 0.22)), 3, n_max)
	g_end = _ground_local(0.0, edge + side * run * float(n))
	var stone := Hanok.shared_mat(Color(0.5, 0.48, 0.44), 0.95)
	for k in range(1, n + 1):
		var zc := edge + side * run * (float(k) - 0.5)
		var g := _ground_local(0.0, zc)
		var top := lerpf(0.0, g_end, float(k) / float(n))
		if top <= g + 0.02:
			continue
		var bottom := g - 0.5
		var h := top - bottom
		_solid(Vector3(open_w + 1.0, h, run), Vector3(0.0, bottom + h * 0.5, zc), stone)
