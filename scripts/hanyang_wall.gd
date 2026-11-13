class_name HanyangWall
extends Node3D
## 한양도성. 백악마루(天자 구간)에서 시계 방향으로 97구간, 능선을 따라 쌓는다.
## 산지(높은 곳)는 돌, 평지는 다진 흙. 문 8개는 근처 구간이 올라가면 함께 선다.
## 구간 번호·천자문·시계 방향은 사료, 단면과 규모는 설계값(docs/고증_근거.md).

const SEGS := 4
const TOTAL := HanyangMap.SECTIONS * SEGS
const PHI_START := 1.7453  # 100도, 백악마루 부근
const HALF_BOTTOM := 1.6
const HALF_TOP := 1.1
const SUNK := 0.8
const STONE_ABOVE := 5.0  # 이보다 높은 곳은 석성
## 천자문 앞 100자. 97구간 이름으로 앞에서부터 쓴다.
const CHARS := "天地玄黃宇宙洪荒日月盈昃辰宿列張寒來暑往秋收冬藏閏餘成歲律呂調陽雲騰致雨露結爲霜金生麗水玉出崑岡劍號巨闕珠稱夜光果珍李柰菜重芥薑海鹹河淡鱗潛羽翔龍師火帝鳥官人皇始制文字乃服衣裳推位讓國有虞陶唐弔民伐罪"

var _sections: Array[StaticBody3D] = []
var _gates: Array[CastleGate] = []
var _gate_frac: Array[float] = []
var _gate_pos: Array[Vector2] = []
var _gate_half: Array[float] = []
var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/wall.gdshader") as Shader
	_prepare_gates()
	_build()
	set_progress(0.0)


## p: 0.0 ~ 1.0, 올라간 구간의 비율
func set_progress(p: float) -> void:
	var count := int(floorf(clampf(p, 0.0, 1.0) * _sections.size()))
	for i in _sections.size():
		var body := _sections[i]
		var on := i < count
		body.visible = on
		body.collision_layer = 1 if on else 0
	for i in _gates.size():
		var g := _gates[i]
		var on := _gate_frac[i] < p
		if on and g.get_parent() == null:
			add_child(g)
		elif not on and g.get_parent() != null:
			remove_child(g)


func _prepare_gates() -> void:
	for g in HanyangMap.GATES:
		var phi := HanyangMap.gate_phi(g["name"])
		var pos2 := HanyangMap.crest_point(phi)
		var big: bool = g["big"]
		var gate := CityGate.new()
		# 성 밖 방향 = 타원 바깥쪽 법선
		var t := HanyangMap.crest_point(phi + 0.01) - HanyangMap.crest_point(phi - 0.01)
		var nrm := Vector2(t.y, -t.x).normalized()
		if nrm.dot(pos2) < 0.0:
			nrm = -nrm
		var yaw := atan2(nrm.x, nrm.y)
		gate.setup(g["name"], big, Vector3(pos2.x, HanyangMap.height(pos2.x, pos2.y), pos2.y), yaw)
		_gates.append(gate)
		_gate_pos.append(pos2)
		_gate_half.append(gate.span * 0.5 + 1.0)
		_gate_frac.append(fposmod(PHI_START - phi, TAU) / TAU)


func _build() -> void:
	var pts: Array[Vector2] = []
	for i in TOTAL + 1:
		pts.append(HanyangMap.crest_point(PHI_START - TAU * float(i) / float(TOTAL)))

	for s in HanyangMap.SECTIONS:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for k in SEGS:
			var i := s * SEGS + k
			var a := pts[i]
			var b := pts[i + 1]
			if _skip_segment((a + b) * 0.5):
				continue
			_add_segment(st, a, b)
			any = true

		_add_marker(s, pts[s * SEGS], pts[s * SEGS + 1])
		if not any:
			var empty := StaticBody3D.new()
			add_child(empty)
			_sections.append(empty)
			continue

		var mesh := st.commit()
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		add_child(body)
		_sections.append(body)


func _skip_segment(mid: Vector2) -> bool:
	for i in _gate_pos.size():
		if mid.distance_to(_gate_pos[i]) < _gate_half[i]:
			return true
	# 오간수문 자리: 개천이 성벽을 가로지르는 곳
	if mid.x > 190.0 and absf(mid.y - HanyangMap.stream_z(mid.x)) < 6.0:
		return true
	return false


func _add_segment(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var t := (b - a).normalized()
	var nrm := Vector2(t.y, -t.x)
	if nrm.dot((a + b) * 0.5) < 0.0:
		nrm = -nrm  # 성 밖 방향

	var ha := HanyangMap.height(a.x, a.y)
	var hb := HanyangMap.height(b.x, b.y)
	var stone := 1.0 if (ha + hb) * 0.5 > STONE_ABOVE else 0.0
	var col := Color(0.47, 0.37, 0.26, stone)

	var ends: Array = []
	for e in 2:
		var p: Vector2 = a if e == 0 else b
		var h: float = ha if e == 0 else hb
		var top := h + HanyangMap.WALL_H
		# 단면: 바깥 아래, 바깥 위, 안쪽 위, 안쪽 아래
		ends.append([
			_v3(p + nrm * HALF_BOTTOM, h - SUNK),
			_v3(p + nrm * HALF_TOP, top),
			_v3(p - nrm * HALF_TOP, top),
			_v3(p - nrm * HALF_BOTTOM, h - SUNK),
		])
	_extrude(st, ends[0], ends[1], col)

	# 바깥쪽 가장자리의 여장(낮은 담). 석성 구간에는 가운데에 총안(활·총 구멍) 틈을 낸다.
	# 흙으로 쌓은 구간은 낮은 흙담으로 둔다. 1396년 여장의 유무와 높이는 확인하지 못한 설계값이다.
	var ph := 1.1 if stone > 0.5 else 0.7
	var spans: Array = [[0.0, 0.42], [0.58, 1.0]] if stone > 0.5 else [[0.0, 1.0]]
	for sp in spans:
		var t0: float = sp[0]
		var t1: float = sp[1]
		var parapet: Array = []
		for e in 2:
			var tt := t0 if e == 0 else t1
			var p2 := a.lerp(b, tt)
			var h2 := lerpf(ha, hb, tt)
			var top2 := h2 + HanyangMap.WALL_H
			parapet.append([
				_v3(p2 + nrm * HALF_TOP, top2),
				_v3(p2 + nrm * (HALF_TOP - 0.1), top2 + ph),
				_v3(p2 + nrm * (HALF_TOP - 0.55), top2 + ph),
				_v3(p2 + nrm * (HALF_TOP - 0.65), top2),
			])
		_extrude(st, parapet[0], parapet[1], col)


func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## 단면 4점을 두 끝에서 이어 붙인 기둥을 만든다.
func _extrude(st: SurfaceTool, e0: Array, e1: Array, col: Color) -> void:
	var c0: Vector3 = (e0[0] + e0[1] + e0[2] + e0[3]) * 0.25
	var c1: Vector3 = (e1[0] + e1[1] + e1[2] + e1[3]) * 0.25
	for j in 4:
		var j2 := (j + 1) % 4
		var mid: Vector3 = (e0[j] + e0[j2] + e1[j] + e1[j2]) * 0.25
		var hint: Vector3 = mid - (c0 + c1) * 0.5
		_tri(st, e0[j], e0[j2], e1[j2], hint, col)
		_tri(st, e0[j], e1[j2], e1[j], hint, col)
	var axis: Vector3 = c1 - c0
	_tri(st, e0[0], e0[1], e0[2], -axis, col)
	_tri(st, e0[0], e0[2], e0[3], -axis, col)
	_tri(st, e1[0], e1[1], e1[2], axis, col)
	_tri(st, e1[0], e1[2], e1[3], axis, col)


## 면이 hint 방향을 향하도록 감는 방향과 법선을 맞춘다.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3, col: Color) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 0.000001:
		return
	if cr.dot(hint) > 0.0:
		var tmp := b
		b = c
		c = tmp
		cr = -cr
	var nrm := -cr.normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(nrm)
		st.add_vertex(v)


## 구간 시작을 알리는 표석. 천자문 글자를 새긴다. 성벽이 오르기 전에도 보인다.
func _add_marker(s: int, a: Vector2, b: Vector2) -> void:
	var t := (b - a).normalized()
	var nrm := Vector2(t.y, -t.x)
	if nrm.dot(a) < 0.0:
		nrm = -nrm
	var p := a - nrm * 3.0
	if _skip_segment(a):
		return
	var h := HanyangMap.height(p.x, p.y)

	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 1.4, 0.35)
	mi.mesh = mesh
	mi.material_override = Hanok.shared_mat(Color(0.5, 0.48, 0.44), 0.95)
	mi.visibility_range_end = 130.0
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(p.x, h + 0.55, p.y)
	body.rotation.y = atan2(t.x, t.y)
	add_child(body)

	var label := Label3D.new()
	label.text = CHARS.substr(s, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(p.x, h + 2.1, p.y)
	label.font_size = 96
	label.pixel_size = 0.012
	label.outline_size = 16
	label.visibility_range_end = 90.0
	add_child(label)
