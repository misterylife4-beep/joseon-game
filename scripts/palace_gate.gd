class_name PalaceGate
extends CityGate
## 광화문. 안쪽 경복궁 터 기단(0.6m)으로 오르는 비탈을 더한다.
## (city_gate.gd 는 편집기가 덮어써서 새 파일로 둔다.)


## 광화문 안쪽: 경복궁 터 기단(0.6m)으로 올라가는 완만한 비탈. 기단 남쪽 끝은 문에서 8m 안쪽이다(설계값).
func _build() -> void:
	super()
	if gate_name != "광화문":
		return
	var top_y := HanyangMap.height(HanyangMap.PALACE_C.x, HanyangMap.PALACE_C.y) + 0.6 - position.y
	var base_y := _ground_local(0.0, -4.2)
	_ramp(-4.2, base_y, -8.4, top_y, 12.0)


## 로컬 z0(높이 y0)에서 z1(높이 y1)까지 폭 w 의 비탈판
func _ramp(z0: float, y0: float, z1: float, y1: float, w: float) -> void:
	var d := Vector3(0.0, y1 - y0, z1 - z0)
	var len := d.length()
	d = d.normalized()
	var bx := Vector3.RIGHT
	var by := d.cross(bx)
	if by.y < 0.0:
		by = -by
		bx = -bx
	var thick := 1.0
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, thick, len)
	mi.mesh = mesh
	mi.material_override = Hanok.shared_mat(Color(0.55, 0.5, 0.42), 0.95)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	body.add_child(cs)
	var mid := Vector3(0.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	body.transform = Transform3D(Basis(bx, by, d), mid - by * (thick * 0.5))
	add_child(body)
