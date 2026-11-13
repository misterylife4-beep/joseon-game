class_name SouthRoad
extends Node3D
## 영남길 첫 구간: 광나루 남쪽 선착장, 흙길, 양재 마을, 너덜이 마을.
## 근거(docs/고증_근거.md 20장): 영남 사람들이 한강을 건너 양재, 달래내 고개, 너덜이로 갔다는 점은 사료·연구 자료다.
## 길의 굽이와 폭, 마을 위치·크기·집 배치, 선착장 모양은 설계값이다. 주막은 1396년에 없어서 두지 않았다.

var _wood_mat: StandardMaterial3D


func build() -> void:
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.vertex_color_use_as_albedo = true
	_wood_mat.vertex_color_is_srgb = true
	_wood_mat.roughness = 0.9
	_wood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var pts := Region.road_points()
	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://shaders/road.gdshader") as Shader
	_ribbon(pts, 5.5, road_mat)
	_pier()

	var rng := RandomNumberGenerator.new()
	rng.seed = 1396
	var placed: Array[Vector2] = []
	for t in Region.towns():
		_town(t, pts, rng, placed)

	# 짐승 걱정이 없는 앞쪽 길에만 길 가는 사람을 둔다 (산길에는 두지 않는다)
	var safe := PackedVector2Array()
	for p in pts:
		if p.y < 1080.0:
			safe.append(p)
	var life := StreetLife.new()
	add_child(life)
	life.build(safe, 5, 0)


# --- 길 ---

func _ribbon(pts: PackedVector2Array, width: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		var pl := pts[i] + nrm * width * 0.5
		var pr := pts[i] - nrm * width * 0.5
		var vl := Vector3(pl.x, HanyangMap.surface(pl.x, pl.y, false) + 0.04, pl.y)
		var vr := Vector3(pr.x, HanyangMap.surface(pr.x, pr.y, false) + 0.04, pr.y)
		var v := 0.0
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
			v = acc / 8.0
			var data := [
				[prev_l, Vector2(1.0, prev_v)], [prev_r, Vector2(0.0, prev_v)], [vl, Vector2(1.0, v)],
				[prev_r, Vector2(0.0, prev_v)], [vr, Vector2(0.0, v)], [vl, Vector2(1.0, v)],
			]
			for d in data:
				st.set_normal(Vector3.UP)
				st.set_uv(d[1])
				st.add_vertex(d[0])
		prev_l = vl
		prev_r = vr
		prev_v = v
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 450.0
	add_child(mi)


## 남쪽 물가의 잔교. 북쪽 선착장(HanRiver)과 마주 본다.
func _pier() -> void:
	var rz := HanyangMap.river_z(Region.FERRY_X)
	var deck := HanyangMap.RIVER_LEVEL + 0.45
	var x := Region.FERRY_X + 4.0
	var edge := rz + 40.0
	var plen := 20.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.38, 0.28, 0.19, 0.0)
	for i in 12:
		BodyMesh.box(st, Vector3(x, deck, edge - 1.0 - float(i) * plen / 12.0), Vector3(3.2, 0.12, plen / 12.0 - 0.06), wood)
	for i in 6:
		var pz := edge - 1.0 - float(i) * plen / 5.0
		for sx in [-1.6, 1.6]:
			var px: float = sx
			BodyMesh.box(st, Vector3(x + px, deck - 0.9, pz), Vector3(0.16, 1.8, 0.16), wood)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _wood_mat
	mi.visibility_range_end = 300.0
	add_child(mi)


# --- 마을 ---

func _nearest_index(pts: PackedVector2Array, c: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in pts.size():
		var d := pts[i].distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = i
	return best


func _flat_range(c: Vector2, hx: float, hz: float) -> float:
	var lo := INF
	var hi := -INF
	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 0.0, 1.0]:
			var h := HanyangMap.height_no_carve(c.x + float(dx) * hx, c.y + float(dz) * hz)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


## 길 양쪽에 초가를 늘어놓는다. 길에서 10m 안쪽과 서로 15m 안쪽에는 짓지 않는다.
func _town(t: Dictionary, pts: PackedVector2Array, rng: RandomNumberGenerator, placed: Array[Vector2]) -> void:
	var c: Vector2 = t["c"]
	var idx := clampi(_nearest_index(pts, c), 4, pts.size() - 5)
	var tg := (pts[idx + 3] - pts[idx - 3]).normalized()
	var nrm := Vector2(-tg.y, tg.x)
	var houses := 0
	for k in 22:
		if houses >= 9:
			break
		var side := 1.0 if k % 2 == 0 else -1.0
		var pos := pts[idx] + tg * rng.randf_range(-45.0, 45.0) + nrm * side * rng.randf_range(12.0, 24.0)
		var kx := rng.randi_range(2, 3)
		var kz := rng.randi_range(1, 2)
		var w := float(kx) * Hanok.KAN
		var d := float(kz) * Hanok.KAN
		if _flat_range(pos, w * 0.5 + 2.5, d * 0.5 + 3.0) > 0.9:
			continue
		var close := false
		for q in placed:
			if q.distance_to(pos) < 15.0:
				close = true
				break
		if close:
			continue
		var hk := Hanok.new()
		var face := (pts[idx] - pos).normalized()
		hk.setup(Hanok.Style.THATCH, kx, kz, Vector3(pos.x, HanyangMap.height_no_carve(pos.x, pos.y), pos.y), atan2(face.x, face.y))
		add_child(hk)
		HanyangCity.house_points.append(pos)
		placed.append(pos)
		houses += 1
