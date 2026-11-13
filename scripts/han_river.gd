class_name HanRiver
extends Node3D
## 한강과 성 밖 풍경: 강물, 나루(선착장), 평저선, 나룻배, 논, 갈대, 나루터 마을.
## 근거(docs/고증_근거.md 11장): 나루 이름과 평저선은 사료. 강 폭·위치(도성 남쪽을 압축), 논 배치, 마을 구성은 설계값이다.
## 마포 시전과 객주 번성, 송파·삼밭나루는 후대 모습이라 두지 않았다.

const FERRIES: Array[Dictionary] = [
	{"name": "양화나루", "x": -330.0},
	{"name": "노들나루", "x": -60.0},
	{"name": "광나루", "x": 360.0},
]

## 잔교 발판 자리: 각 항목 {"rect": Rect2(x, z 범위), "top": 윗면 높이}
static var piers: Array[Dictionary] = []

var _boats: Array[Dictionary] = []
var _wood_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


## 잔교 발판 위(margin 만큼 넓혀서)면 윗면 높이, 아니면 -999.
static func pier_deck_at(x: float, z: float, margin := 0.0) -> float:
	var pt := Vector2(x, z)
	for d in piers:
		var r: Rect2 = d["rect"]
		if r.grow(margin).has_point(pt):
			return float(d["top"])
	return -999.0


func _ready() -> void:
	piers.clear()
	_rng.seed = 1395
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.vertex_color_use_as_albedo = true
	_wood_mat.vertex_color_is_srgb = true
	_wood_mat.roughness = 0.9
	_wood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_water()
	for f in FERRIES:
		_build_ferry(f["name"], f["x"])
	_build_fields()


func _build_water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800.0, 150.0)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/river.gdshader")
	mi.material_override = mat
	mi.position = Vector3(0.0, HanyangMap.RIVER_LEVEL, HanyangMap.RIVER_Z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ground(x: float, z: float) -> float:
	return HanyangMap.height_no_carve(x, z)


func _build_ferry(fname: String, fx: float) -> void:
	var rz := HanyangMap.river_z(fx)
	var deck := HanyangMap.RIVER_LEVEL + 0.45
	var north := rz - 40.0  # 북쪽 물가
	# 잔교: 물가에서 물 위로 뻗은 나무 선착장
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.38, 0.28, 0.19, 0.0)
	var plen := 20.0
	for i in 12:
		BodyMesh.box(st, Vector3(0.0, deck, north + 1.0 + float(i) * plen / 12.0), Vector3(3.2, 0.12, plen / 12.0 - 0.06), wood)
	for i in 6:
		var pz := north + 1.0 + float(i) * plen / 5.0
		for sx in [-1.0, 1.0]:
			BodyMesh.box(st, Vector3(float(sx) * 1.6, deck - 1.8, pz), Vector3(0.22, 4.0, 0.22), Color(0.3, 0.22, 0.15, 0.0))
	var pier := MeshInstance3D.new()
	pier.mesh = st.commit()
	pier.material_override = _wood_mat
	pier.position = Vector3(fx, 0.0, 0.0)
	pier.visibility_range_end = 400.0
	add_child(pier)
	# 발판과 기둥에 충돌을 준다: 올라서 걸을 수 있고, 기둥은 뚫고 지나갈 수 없다
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("surface", "plank")
	var deck_top := deck + 0.06
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(3.4, 0.4, plen)
	dcs.shape = dbox
	dcs.position = Vector3(fx, deck_top - 0.2, north + 10.17)
	body.add_child(dcs)
	for i in 6:
		var pz := north + 1.0 + float(i) * plen / 5.0
		for sx in [-1.0, 1.0]:
			var pcs := CollisionShape3D.new()
			var pbox := BoxShape3D.new()
			pbox.size = Vector3(0.26, 4.0, 0.26)
			pcs.shape = pbox
			pcs.position = Vector3(fx + float(sx) * 1.6, deck - 1.8, pz)
			body.add_child(pcs)
	add_child(body)
	piers.append({"rect": Rect2(fx - 1.7, north + 0.17, 3.4, plen), "top": deck_top})
	# 나루 이름
	var label := Label3D.new()
	label.text = fname
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(fx, deck + 5.0, north + 2.0)
	label.font_size = 56
	label.pixel_size = 0.014
	label.outline_size = 12
	label.visibility_range_end = 260.0
	add_child(label)
	# 선착장 횃불
	for sx in [-1.0, 1.0]:
		var tc := Torch.new()
		tc.position = Vector3(fx + float(sx) * 1.5, deck + 0.1, north + 3.0)
		tc.light_range = 16.0
		add_child(tc)
	# 사공과 나그네 한 명
	var sg := Person.new().setup(Person.Kind.WORKER, Person.Act.IDLE, Vector3(fx + 0.4, deck + 0.06, north + 8.0), 0.0, 1)
	sg.scheduled = true
	add_child(sg)
	var tr := Person.new().setup(Person.Kind.YANGBAN, Person.Act.IDLE, Vector3(fx - 0.5, deck + 0.06, north + 4.5), PI, 0)
	tr.scheduled = true
	add_child(tr)
	# 물가에 대어 둔 배 두 척
	for k in 2:
		var blen := 7.0 + 1.2 * float(k)
		var b := _make_boat(blen, false, false, RowBoat.new())
		(b as RowBoat).length = blen
		b.position = Vector3(fx + (4.5 if k == 0 else -4.8), HanyangMap.RIVER_LEVEL + 0.1, north + 11.0 + 3.0 * float(k))
		b.rotation.y = 0.05 + 0.1 * float(k)
		add_child(b)
	# 강을 건너는 나룻배
	var fb := _make_boat(8.5, true)
	fb.position = Vector3(fx + 18.0, HanyangMap.RIVER_LEVEL + 0.1, rz)
	add_child(fb)
	_boats.append({"node": fb, "x": fx + 18.0, "phase": _rng.randf() * TAU})
	# 마을과 갈대
	_build_village(fx)
	_build_reeds(fx)


## 평저선: 바닥이 평평한 배(사료는 후기 그림 설명이라 크기와 모양은 설계값)
## owner_boatman: 사공을 태울지 (직접 저을 배에는 태우지 않는다)
func _make_boat(length: float, with_crew: bool, boatman := true, root: Node3D = null) -> Node3D:
	if root == null:
		root = Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := Color(0.42, 0.3, 0.2, 0.0)
	var dark := Color(0.3, 0.22, 0.15, 0.0)
	BodyMesh.box(st, Vector3(0.0, 0.1, 0.0), Vector3(1.6, 0.1, length), dark)
	for sx in [-1.0, 1.0]:
		BodyMesh.box(st, Vector3(float(sx) * 0.82, 0.38, 0.0), Vector3(0.08, 0.6, length * 0.96), col, Vector3(0.0, 0.0, float(sx) * -0.12))
	for ez in [-1.0, 1.0]:
		BodyMesh.box(st, Vector3(0.0, 0.38, float(ez) * length * 0.5), Vector3(1.6, 0.6, 0.08), col)
		BodyMesh.box(st, Vector3(0.0, 0.5, float(ez) * (length * 0.5 + 0.35)), Vector3(1.3, 0.08, 0.8), col, Vector3(float(ez) * 0.35, 0.0, 0.0))
	for i in 3:
		BodyMesh.box(st, Vector3(0.0, 0.42, (float(i) - 1.0) * length * 0.28), Vector3(1.66, 0.07, 0.16), dark)
	# 삿대
	BodyMesh.box(st, Vector3(0.95, 1.2, length * 0.35), Vector3(0.05, 3.4, 0.05), Color(0.5, 0.4, 0.26, 0.0), Vector3(0.0, 0.0, 0.18))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _wood_mat
	mi.visibility_range_end = 300.0
	root.add_child(mi)
	if boatman:
		var sg := Person.new().setup(Person.Kind.WORKER, Person.Act.IDLE, Vector3(0.3, 0.18, length * 0.35), PI, 3)
		root.add_child(sg)
	if with_crew:
		var p1 := Person.new().setup(Person.Kind.WOMAN, Person.Act.IDLE, Vector3(-0.2, 0.18, -length * 0.1), 0.0, 2)
		var p2 := Person.new().setup(Person.Kind.YANGBAN, Person.Act.IDLE, Vector3(0.25, 0.18, -length * 0.28), 0.3, 1)
		root.add_child(p1)
		root.add_child(p2)
	return root


func _build_village(fx: float) -> void:
	var offs: Array[Vector2] = [
		Vector2(-30, -66), Vector2(-14, -70), Vector2(4, -64), Vector2(22, -70), Vector2(40, -64),
		Vector2(-22, -86), Vector2(-2, -90), Vector2(18, -86),
	]
	for o in offs:
		var x := fx + o.x + _rng.randf_range(-3.0, 3.0)
		var z := HanyangMap.river_z(x) + o.y + _rng.randf_range(-3.0, 3.0)
		var hk := Hanok.new()
		hk.setup(Hanok.Style.THATCH, _rng.randi_range(2, 3), 1, Vector3(x, HanyangMap.height(x, z), z), _rng.randf_range(-0.15, 0.15))
		add_child(hk)


func _build_reeds(fx: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var r := 0.12 + 0.08 * float(i % 2)
		BodyMesh.box(
			st, Vector3(cos(a) * r, 0.8, sin(a) * r), Vector3(0.035, 1.6 + 0.2 * float(i % 3), 0.035),
			Color(0.46, 0.5, 0.26, 0.0), Vector3(sin(a) * 0.12, 0.0, -cos(a) * 0.12)
		)
	BodyMesh.box(st, Vector3(0.0, 1.7, 0.0), Vector3(0.09, 0.25, 0.09), Color(0.5, 0.4, 0.28, 0.0))
	var xs: Array[Transform3D] = []
	for i in 400:
		var x := fx + _rng.randf_range(-130.0, 130.0)
		var side := -1.0 if _rng.randf() < 0.65 else 1.0
		var z := HanyangMap.river_z(x) + side * _rng.randf_range(30.0, 46.0)
		var h := HanyangMap.height(x, z)
		if h < -8.9 or h > -7.0:
			continue
		var sc := _rng.randf_range(0.8, 1.5)
		xs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(x, h - 0.05, z)))
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = xs.size()
	for j in xs.size():
		mm.set_instance_transform(j, xs[j])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _wood_mat
	mmi.visibility_range_end = 220.0
	add_child(mmi)


## 논: 강변 평지에 모를 낸 논과 두렁. 배치는 설계값이다.
func _build_fields() -> void:
	var paddy_mat := ShaderMaterial.new()
	paddy_mat.shader = load("res://shaders/paddy.gdshader")
	var bund_mat := StandardMaterial3D.new()
	bund_mat.albedo_color = Color(0.36, 0.28, 0.18)
	bund_mat.roughness = 1.0
	for ix in range(-20, 21):
		for side in [-1.0, 1.0]:
			var cx := float(ix) * 26.0 + _rng.randf_range(-3.0, 3.0)
			var near_ferry := false
			for f in FERRIES:
				if absf(cx - float(f["x"])) < 58.0 and side < 0.0:
					near_ferry = true
			if near_ferry or _rng.randf() < 0.18:
				continue
			var cz := HanyangMap.river_z(cx) + float(side) * _rng.randf_range(64.0, 100.0)
			var w := _rng.randf_range(14.0, 21.0)
			var d := _rng.randf_range(10.0, 15.0)
			var hmax := -100.0
			var hmin := 100.0
			for dx in [-0.5, 0.5]:
				for dz in [-0.5, 0.5]:
					var hh := HanyangMap.height_no_carve(cx + float(dx) * w, cz + float(dz) * d)
					hmax = maxf(hmax, hh)
					hmin = minf(hmin, hh)
			var top := hmax + 0.05
			var field := Node3D.new()
			field.position = Vector3(cx, top, cz)
			var pl := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(w, d)
			pl.mesh = pm
			pl.material_override = paddy_mat
			pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pl.visibility_range_end = 320.0
			field.add_child(pl)
			# 두렁(논둑) 네 변. 지면이 낮은 쪽도 덮도록 아래로 길게 둔다.
			var depth := top - hmin + 0.4
			for e in 4:
				var bm := MeshInstance3D.new()
				var bb := BoxMesh.new()
				var horiz := e < 2
				bb.size = Vector3(w if horiz else 0.5, depth + 0.22, 0.5 if horiz else d)
				bm.mesh = bb
				bm.material_override = bund_mat
				bm.visibility_range_end = 320.0
				var sgn := -1.0 if e % 2 == 0 else 1.0
				bm.position = Vector3(0.0 if horiz else sgn * w * 0.5, -depth * 0.5 + 0.11, sgn * d * 0.5 if horiz else 0.0)
				field.add_child(bm)
			add_child(field)


func _process(delta: float) -> void:
	var h: float = DayNight.hour_now
	var running := h >= 5.5 and h < 19.0
	var t := Time.get_ticks_msec() * 0.001
	for b in _boats:
		var n: Node3D = b["node"]
		n.visible = running
		if not running:
			continue
		var ph: float = b["phase"]
		var x0: float = b["x"]
		var s := sin(t * 0.045 + ph)
		var z := HanyangMap.river_z(x0) + s * 26.0
		n.position = Vector3(x0 + 5.0 * sin(t * 0.03 + ph), HanyangMap.RIVER_LEVEL + 0.12 + 0.04 * sin(t * 1.3 + ph), z)
		var dir := cos(t * 0.045 + ph)
		n.rotation.y = 0.0 if dir >= 0.0 else PI
		n.rotation.z = 0.025 * sin(t * 0.9 + ph)
