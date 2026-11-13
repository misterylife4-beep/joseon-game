class_name Shrines
extends Node3D
## 종묘(경복궁 동쪽)와 사직단(서쪽). 좌묘우사의 원칙.
## 사료(docs/고증_근거.md 17장): 1395년 종묘는 정전 대실 7칸에 좌우 익랑 각 2칸, 담 안에 공신당 5칸·신문 3칸,
## 담 밖에 신주 7칸·향관청 5칸·남행랑 9칸·재궁 5칸을 두었다. 사직단은 사단(동)과 직단(서)이 정방형이고
## 북쪽에 신좌를 모셨으며 북신문만 3칸이다. 담의 크기, 단 크기, 건물 배치 좌표는 설계값이다.

const STONE := Color(0.58, 0.56, 0.5)
const KAN := Hanok.KAN


func _ready() -> void:
	_build_jongmyo()
	_build_sajik()


func _hk(style: int, nx: int, nz: int, p: Vector2, yaw: float, official := true) -> void:
	var hk := Hanok.new()
	hk.setup(style, nx, nz, Vector3(p.x, HanyangMap.height(p.x, p.y), p.y), yaw, official)
	add_child(hk)


## 지면이 울퉁불퉁해도 평평하게 보이도록 기단 상자를 깊게 묻는다.
func _terrace(c: Vector2, size: Vector2, top_above := 0.3) -> float:
	var base := HanyangMap.height(c.x, c.y)
	var top := base + top_above
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 3.0, size.y)
	mi.mesh = bm
	mi.material_override = Hanok.shared_mat(Color(0.5, 0.45, 0.38), 1.0)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(c.x, top - 1.5, c.y)
	add_child(body)
	return top


## 사각 담. gaps는 변 이름("N","S","E","W")과 문틈 너비
func _wall_ring(c: Vector2, half: Vector2, top_y: float, wall_h: float, thick: float, gaps: Dictionary) -> void:
	var mat := Hanok.shared_mat(Color(0.6, 0.57, 0.5), 0.95)
	for side in ["N", "S", "E", "W"]:
		var horizontal: bool = side == "N" or side == "S"
		var length: float = half.x * 2.0 if horizontal else half.y * 2.0
		var gap: float = gaps.get(side, 0.0)
		var center := Vector2(c.x, c.y + (-half.y if side == "N" else half.y)) if horizontal else Vector2(c.x + (half.x if side == "E" else -half.x), c.y)
		var parts: Array = []
		if gap <= 0.0:
			parts.append([0.0, length])
		else:
			var seg := (length - gap) * 0.5
			parts.append([-(gap + seg) * 0.5, seg])
			parts.append([(gap + seg) * 0.5, seg])
		for pp in parts:
			var off: float = pp[0]
			var ln: float = pp[1]
			var body := StaticBody3D.new()
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(ln if horizontal else thick, wall_h, thick if horizontal else ln)
			mi.mesh = bm
			mi.material_override = mat
			body.add_child(mi)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = bm.size
			cs.shape = sh
			body.add_child(cs)
			body.position = Vector3(center.x + (off if horizontal else 0.0), top_y + wall_h * 0.5, center.y + (0.0 if horizontal else off))
			add_child(body)


func _label(text: String, p: Vector2, y: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(p.x, y, p.y)
	label.font_size = 56
	label.pixel_size = 0.014
	label.outline_size = 12
	label.visibility_range_end = 220.0
	add_child(label)


func _torch(p: Vector2, y: float) -> void:
	var tc := Torch.new()
	tc.position = Vector3(p.x, y, p.y)
	tc.light_range = 16.0
	add_child(tc)


func _build_jongmyo() -> void:
	var c := HanyangMap.JONGMYO_C
	var top := _terrace(c, Vector2(76.0, 60.0))
	# 담: 동서 폭 62m, 남북 깊이 48m (설계값). 남쪽 신문 3칸, 동문 3칸, 서문 1칸
	_wall_ring(c, Vector2(31.0, 24.0), top, 3.2, 0.9, {"S": KAN * 3.0, "E": KAN * 3.0, "W": KAN})
	# 신문(남쪽 정문)
	var gate_p := Vector2(c.x, c.y + 24.0)
	_hk(Hanok.Style.TILE, 3, 1, gate_p, 0.0)
	# 정전: 대실 7칸에 좌우 익랑 2칸씩. 전체 11칸이고 단순한 맞배집(지붕 모양은 단순화)
	_hk(Hanok.Style.TILE, 11, 1, Vector2(c.x, c.y - 6.0), 0.0)
	# 담 안 공신당 5칸 (정전 앞 동남쪽)
	_hk(Hanok.Style.TILE, 5, 1, Vector2(c.x + 16.0, c.y + 10.0), 0.0)
	# 담 밖: 남행랑 9칸, 향관청 5칸(서), 재궁 5칸(동), 신주 7칸(북). 좌우 행랑 각 5칸은 동서 담 바깥.
	_hk(Hanok.Style.TILE, 9, 1, Vector2(c.x, c.y + 31.0), 0.0, false)
	_hk(Hanok.Style.TILE, 5, 1, Vector2(c.x - 40.0, c.y - 4.0), PI * 0.5, false)
	_hk(Hanok.Style.TILE, 5, 1, Vector2(c.x + 40.0, c.y - 4.0), -PI * 0.5, false)
	_hk(Hanok.Style.TILE, 7, 1, Vector2(c.x, c.y - 34.0), 0.0, false)
	_label("종묘", gate_p, top + 10.0)
	for sx in [-1.0, 1.0]:
		_torch(Vector2(c.x + float(sx) * 7.0, c.y + 27.0), top + 0.1)


func _build_sajik() -> void:
	var c := HanyangMap.SAJIK_C
	var top := _terrace(c, Vector2(64.0, 64.0))
	# 주원(바깥담) 50m 정방형. 북신문 3칸이 가장 크고 동·서·남문은 1칸 (설계 크기)
	_wall_ring(c, Vector2(25.0, 25.0), top, 3.0, 0.8, {"N": KAN * 3.0, "S": KAN, "E": KAN, "W": KAN})
	_hk(Hanok.Style.TILE, 3, 1, Vector2(c.x, c.y - 25.0), PI)
	# 안쪽 유(낮은 담) 38m 정방형, 네 변 가운데 유문
	_wall_ring(c, Vector2(19.0, 19.0), top, 1.2, 0.5, {"N": 3.0, "S": 3.0, "E": 3.0, "W": 3.0})
	# 사단(동쪽)과 직단(서쪽): 각 한 변 8m, 높이 1m, 4면 3단 계단. 곡식의 직단이 서쪽(사료)
	_altar(Vector2(c.x + 8.5, c.y), top)
	_altar(Vector2(c.x - 8.5, c.y), top)
	# 신실(신좌 보관): 북쪽 안쪽
	_hk(Hanok.Style.TILE, 3, 1, Vector2(c.x, c.y - 21.5), PI)
	_label("사직단", Vector2(c.x, c.y + 25.0), top + 7.0)
	for sx in [-1.0, 1.0]:
		_torch(Vector2(c.x + float(sx) * 5.0, c.y + 28.0), top + 0.1)


func _altar(p: Vector2, top: float) -> void:
	var mat := Hanok.shared_mat(STONE, 0.95)
	var tiers := [[8.0, 0.35], [7.2, 0.7], [6.4, 1.05]]
	var body := StaticBody3D.new()
	for t in tiers:
		var sz: float = t[0]
		var hh: float = t[1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sz, 0.35, sz)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(0.0, hh - 0.175, 0.0)
		body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(8.0, 1.05, 8.0)
	cs.shape = sh
	cs.position = Vector3(0.0, 0.525, 0.0)
	body.add_child(cs)
	body.position = Vector3(p.x, top, p.y)
	add_child(body)
