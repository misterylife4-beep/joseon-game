class_name CityGate
extends CastleGate
## 성문. 문 앞뒤 높이 차를 계단 대신 길고 완만한 비탈로 이어, 점프 없이 걸어 들어가게 한다.
## (castle_gate.gd 는 편집기에 열려 있어 덮어써지므로 이 파일에서 _apron 을 덮어쓴다.)


## 문 바닥과 바깥(안쪽) 지면의 높이 차를 길고 완만한 비탈로 잇는다. 계단이 아니므로 점프 없이 걸어 오른다.
## 비탈 길이와 폭은 설계값이다. side=+1 성 밖, -1 성 안.
func _apron(open_w: float, depth: float, side: float) -> void:
	var run := 14.0
	var edge := side * depth * 0.5
	var g_end := _ground_local(0.0, edge + side * run)
	if absf(g_end) < 0.12:
		return
	var d := Vector3(0.0, g_end, side * run).normalized()
	var bx := Vector3.RIGHT
	var by := d.cross(bx)
	if by.y < 0.0:
		by = -by
		bx = -bx
	var thick := 1.0
	var len := Vector3(0.0, g_end, run).length()
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(open_w + 1.0, thick, len)
	mi.mesh = mesh
	mi.material_override = Hanok.shared_mat(Color(0.5, 0.48, 0.44), 0.95)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	body.add_child(cs)
	var mid := Vector3(0.0, g_end * 0.5, edge + side * run * 0.5)
	body.transform = Transform3D(Basis(bx, by, d), mid - by * (thick * 0.5))
	add_child(body)
