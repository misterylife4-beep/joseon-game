class_name MapCanvas
extends Control
## 열어 보는 조선 지도. 두 가지 면: 조선 전도(개략도)와 지역도(한양과 영남길 첫 구간, 게임 좌표 그대로).
## 근거(docs/고증_근거.md 21장): 전도의 고을·길 이름은 기획서 조사 결과를 따르고, 해안선과 산줄기 좌표는 개략 설계값이다.
## 지역도는 게임 안 지형을 그대로 읽어 그린 것이라 실제 지도와 다르다 (한양 1:10, 영남길 구간은 압축).

enum Mode { NATION, LOCAL }

const LX0 := -450.0
const LX1 := 1350.0
const LZ0 := -280.0
const LZ1 := 1950.0
const CELL := 12.0

static var _tex: ImageTexture

## 한양 성문을 눌렀을 때 (문 이름, 성문 위치)
signal gate_picked(gate_name: String, pos: Vector2)
## 발견한 거점(깃발)을 눌렀을 때 (Discovery 의 id)
signal place_picked(id: String)

var mode := Mode.NATION
var _gate_hits: Array[Dictionary] = []
var _place_hits: Array[Dictionary] = []
var _hover := -1
var _place_hover := -1
var player: Player

var _fibers := PackedVector2Array()
var _fiber_size := Vector2.ZERO
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, JoseonUI.PAPER)
	if _fiber_size != size:
		_fiber_size = size
		_fibers = JoseonUI.fibers(r, 220, 1396)
	draw_multiline(_fibers, Color(0.55, 0.47, 0.33, 0.16), 1.0)
	JoseonUI.frame(self, r.grow(-8.0))

	JoseonUI.seal(self, Vector2(28.0, 24.0), 42.0, "지도")
	var title := "조선 전도" if mode == Mode.NATION else "한양과 영남길"
	var sub := "태조 5년 무렵 · 개략도" if mode == Mode.NATION else "게임 안 지형을 그대로 옮긴 지역도"
	draw_string(JoseonUI.title_font(), Vector2(82.0, 46.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, JoseonUI.INK)
	draw_string(JoseonUI.font(), Vector2(84.0, 66.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, JoseonUI.INK_SOFT)
	var hint := "Tab 면 바꾸기 · M 또는 Esc 닫기"
	var hw := JoseonUI.font().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(JoseonUI.font(), Vector2(r.end.x - hw - 34.0, 46.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, JoseonUI.INK_SOFT)

	# 지도만 크게: 위 제목줄과 아래 한 줄 안내띠 사이를 모두 지도에 쓴다
	var map_rect := Rect2(Vector2(34.0, 78.0), Vector2(r.size.x - 68.0, r.size.y - 78.0 - 104.0))
	_bottom = r.end.y - 20.0
	if mode == Mode.NATION:
		_draw_nation(map_rect)
		_strip_nation(Vector2(40.0, map_rect.end.y + 16.0), r.size.x - 80.0)
	else:
		_draw_local(map_rect)
		_strip_local(Vector2(40.0, map_rect.end.y + 16.0), r.size.x - 80.0)


# --- 글 쓰기 도우미 ---

var _bottom := 9999.0


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.LOCAL:
		return
	if event is InputEventMouseMotion:
		var p := (event as InputEventMouseMotion).position
		var h := -1
		for i in _gate_hits.size():
			if (_gate_hits[i]["rect"] as Rect2).has_point(p):
				h = i
				break
		var ph := -1
		for j in _place_hits.size():
			if (_place_hits[j]["rect"] as Rect2).has_point(p):
				ph = j
				break
		if h != _hover or ph != _place_hover:
			if ph != _place_hover and ph >= 0:
				UiSfx.play(self, "tick", -24.0)
			_hover = h
			_place_hover = ph
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			for h in _gate_hits:
				if (h["rect"] as Rect2).has_point(mb.position):
					gate_picked.emit(String(h["name"]), h["pos"] as Vector2)
					accept_event()
					return
			for h2 in _place_hits:
				if (h2["rect"] as Rect2).has_point(mb.position):
					place_picked.emit(String(h2["id"]))
					accept_event()
					return


func _para(x: float, y: float, w: float, text: String, fs: int, col: Color) -> float:
	var f := JoseonUI.font()
	var h := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
	if y + h > _bottom:
		return y + h + 10.0  # 자리가 모자라면 그리지 않는다 (다른 글자와 겹침 방지)
	draw_multiline_string(f, Vector2(x, y + float(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
	return y + f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y + 10.0


func _head(x: float, y: float, text: String) -> float:
	if y + 40.0 > _bottom:
		return y + 40.0
	draw_string(JoseonUI.font(), Vector2(x, y + 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, JoseonUI.SEAL)
	draw_line(Vector2(x, y + 28.0), Vector2(x + 40.0, y + 28.0), JoseonUI.SEAL, 2.0)
	return y + 40.0


func _here_text() -> String:
	if player == null:
		return ""
	var zn := Region.zone_at(player.global_position.x, player.global_position.z)
	var d := int(zn["danger"])
	return "%s\n위험 %d단계 (%s)" % [zn["name"], d, JoseonUI.LEVEL_NAMES[d]]


# --- 조선 전도 ---

func _draw_nation(mr: Rect2) -> void:
	var s := minf(mr.size.x / JoseonGeo.SIZE.x, mr.size.y / JoseonGeo.SIZE.y)
	var org := mr.position + (mr.size - JoseonGeo.SIZE * s) * 0.5
	var sea := Rect2(org, JoseonGeo.SIZE * s)
	draw_rect(sea, Color(JoseonUI.SEA.r, JoseonUI.SEA.g, JoseonUI.SEA.b, 0.45))

	var land := PackedVector2Array()
	for ll in JoseonGeo.OUTLINE:
		land.append(org + JoseonGeo.project(ll) * s)
	if not Geometry2D.triangulate_polygon(land).is_empty():
		draw_colored_polygon(land, JoseonUI.PAPER_LIGHT)
	var closed := land.duplicate()
	closed.append(land[0])
	draw_polyline(closed, JoseonUI.INK, 2.0, true)

	var jeju := PackedVector2Array()
	for ll in JoseonGeo.JEJU:
		jeju.append(org + JoseonGeo.project(ll) * s)
	if not Geometry2D.triangulate_polygon(jeju).is_empty():
		draw_colored_polygon(jeju, JoseonUI.PAPER_LIGHT)
	var jc := jeju.duplicate()
	jc.append(jeju[0])
	draw_polyline(jc, JoseonUI.INK, 1.6, true)
	draw_rect(sea, JoseonUI.INK_SOFT, false, 1.5)

	_sea_label(org, s, Vector2(125.0, 36.4), "서해")
	_sea_label(org, s, Vector2(130.0, 38.0), "동해")
	_sea_label(org, s, Vector2(127.8, 33.8), "남해")

	# 산줄기
	for i in JoseonGeo.RIDGE.size() - 1:
		var a := org + JoseonGeo.project(JoseonGeo.RIDGE[i]) * s
		var b := org + JoseonGeo.project(JoseonGeo.RIDGE[i + 1]) * s
		draw_dashed_line(a, b, Color(JoseonUI.INK_SOFT.r, JoseonUI.INK_SOFT.g, JoseonUI.INK_SOFT.b, 0.55), 2.0, 6.0)
	for pk in JoseonGeo.PEAKS:
		var p := org + JoseonGeo.project(Vector2(float(pk[1]), float(pk[2]))) * s
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(-6, 4), p + Vector2(6, 4)]), JoseonUI.INK_SOFT)
		JoseonUI.text_halo(self, p + Vector2(8, 4), String(pk[0]), 12, JoseonUI.INK_SOFT, JoseonUI.PAPER_LIGHT)

	# 강
	for rv in JoseonGeo.RIVERS:
		var pts := PackedVector2Array()
		for ll in rv[1]:
			pts.append(org + JoseonGeo.project(ll) * s)
		draw_polyline(pts, Color(JoseonUI.INDIGO.r, JoseonUI.INDIGO.g, JoseonUI.INDIGO.b, 0.85), 2.0, true)
		var mid := pts[pts.size() / 2]
		JoseonUI.text_halo(self, mid + Vector2(5, -3), String(rv[0]), 11, JoseonUI.INDIGO, JoseonUI.PAPER_LIGHT)

	# 길: 영남길을 마지막에 굵게
	for rt in JoseonGeo.ROUTES:
		if String(rt[0]) == "영남길":
			continue
		var pts := _route_points(rt[1], org, s)
		for i in pts.size() - 1:
			draw_dashed_line(pts[i], pts[i + 1], Color(JoseonUI.OCHRE.r, JoseonUI.OCHRE.g, JoseonUI.OCHRE.b, 0.85), 1.8, 5.0)
	for rt in JoseonGeo.ROUTES:
		if String(rt[0]) == "영남길":
			var pts := _route_points(rt[1], org, s)
			draw_polyline(pts, Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.25), 8.0, true)
			draw_polyline(pts, JoseonUI.SEAL, 3.0, true)

	for pa in JoseonGeo.PASSES:
		var p := org + JoseonGeo.project(Vector2(float(pa[1]), float(pa[2]))) * s
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), JoseonUI.SEAL)
		JoseonUI.text_halo(self, p + Vector2(8, 4), String(pa[0]), 11, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)

	# 고을
	for t in JoseonGeo.TOWNS:
		var nm := String(t[0])
		var tier := int(t[3])
		var p := org + JoseonGeo.project(Vector2(float(t[1]), float(t[2]))) * s
		var rad := 6.0 if tier == 2 else (4.5 if tier == 1 else 3.0)
		var col := JoseonUI.SEAL if tier == 2 else JoseonUI.INK
		draw_circle(p, rad + 1.5, JoseonUI.PAPER_LIGHT)
		draw_circle(p, rad, col)
		if nm == "양재" or nm == "판교":
			continue
		var fs := 15 if tier >= 1 else 12
		JoseonUI.text_halo(self, p + Vector2(rad + 3.0, 5.0), nm, fs, JoseonUI.INK, JoseonUI.PAPER_LIGHT)

	_compass(Vector2(sea.end.x - 28.0, sea.position.y + 36.0))

	if player != null:
		var pl := org + JoseonGeo.project(_player_ll()) * s
		var pulse := 9.0 + 3.0 * sin(_t * 3.0)
		draw_arc(pl, pulse, 0.0, TAU, 24, JoseonUI.SEAL, 2.0, true)
		draw_circle(pl, 4.5, JoseonUI.SEAL)
		JoseonUI.text_halo(self, pl + Vector2(-58.0, -12.0), "막손 (여기)", 13, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)


func _route_points(stops: Array, org: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for ll in JoseonGeo.route_ll(stops):
		out.append(org + JoseonGeo.project(ll) * s)
	return out


func _sea_label(org: Vector2, s: float, ll: Vector2, text: String) -> void:
	var p := org + JoseonGeo.project(ll) * s
	draw_string(JoseonUI.font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(JoseonUI.INDIGO.r, JoseonUI.INDIGO.g, JoseonUI.INDIGO.b, 0.6))


func _compass(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(6, 4), c + Vector2(-6, 4)]), JoseonUI.INK)
	draw_line(c + Vector2(0, 4), c + Vector2(0, 18), JoseonUI.INK, 2.0)
	draw_string(JoseonUI.font(), c + Vector2(-7, 36), "북", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, JoseonUI.INK)


## 막손의 전도 위치: 한양 남쪽 길 위에서는 한양-양재-판교 사이를 길 진행도로 옮긴다 (개략).
func _player_ll() -> Vector2:
	var stops := JoseonGeo.route_ll(["한양", "양재", "판교"])
	var pz := player.global_position.z
	if pz < 380.0:
		return stops[0]
	var pts := Region.road_points()
	var best := 0
	var best_d := INF
	var pp := Vector2(player.global_position.x, pz)
	for i in pts.size():
		var d := pts[i].distance_squared_to(pp)
		if d < best_d:
			best_d = d
			best = i
	var seg := clampf(float(best) / float(pts.size() - 1), 0.0, 1.0) * 2.0
	if seg < 1.0:
		return stops[0].lerp(stops[1], seg)
	return stops[1].lerp(stops[2], seg - 1.0)


## 아래 안내띠(전도): 지금 있는 곳과 범례. 틀 안쪽에 들어오도록 두 줄로 굵게 쓴다.
func _strip_nation(p: Vector2, w: float) -> void:
	if player != null:
		var zn := Region.zone_at(player.global_position.x, player.global_position.z)
		JoseonUI.text_bold(self, p + Vector2(0, 20), "지금 있는 곳  " + String(zn["name"]), 19, JoseonUI.INK)
	var x := p.x + w * 0.40
	_legend_line(Vector2(x, p.y + 12.0), JoseonUI.SEAL, false, "영남길")
	_legend_line(Vector2(x + 120.0, p.y + 12.0), JoseonUI.OCHRE, true, "다른 길")
	_legend_line(Vector2(x + 250.0, p.y + 12.0), JoseonUI.INDIGO, false, "강")
	_legend_line(Vector2(x + 340.0, p.y + 12.0), JoseonUI.INK_SOFT, true, "산줄기")
	JoseonUI.text_bold(self, p + Vector2(0, 52), "개략도입니다. 해안선·강·산줄기는 손으로 줄여 그려 실제와 다릅니다.", 16, JoseonUI.INK_SOFT)


func _legend_line(p: Vector2, col: Color, dashed: bool, text: String) -> void:
	if dashed:
		draw_dashed_line(p, p + Vector2(34, 0), col, 2.0, 5.0)
	else:
		draw_line(p, p + Vector2(34, 0), col, 3.0)
	JoseonUI.text_bold(self, p + Vector2(44, 7), text, 16, JoseonUI.INK)


# --- 지역도 ---

## 지역도 바탕 그림. 지도 화면과 미니맵이 함께 쓴다.
static func ensure_texture() -> ImageTexture:
	if _tex == null:
		_build_texture()
	return _tex


static func _build_texture() -> void:
	var nx := int(ceil((LX1 - LX0) / CELL))
	var nz := int(ceil((LZ1 - LZ0) / CELL))
	var pw := nx + 2
	var hs := PackedFloat32Array()
	hs.resize(pw * (nz + 2))
	for j in nz + 2:
		for i in pw:
			hs[j * pw + i] = HanyangMap.height(LX0 + float(i - 1) * CELL, LZ0 + float(j - 1) * CELL)
	var img := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	for j in nz:
		for i in nx:
			var k := (j + 1) * pw + (i + 1)
			var x := LX0 + float(i) * CELL
			var z := LZ0 + float(j) * CELL
			var col: Color
			if z > 200.0 and HanyangMap.river_dist(x, z) < 40.0:
				col = Color(0.58, 0.70, 0.74)
			else:
				var t := clampf((hs[k] + 8.0) / 70.0, 0.0, 1.0)
				col = Color(0.86, 0.84, 0.68).lerp(Color(0.55, 0.63, 0.43), smoothstep(0.0, 0.35, t))
				col = col.lerp(Color(0.52, 0.46, 0.38), smoothstep(0.55, 1.0, t))
				var shade := (hs[k - 1] - hs[k + 1]) * 0.06 + (hs[k - pw] - hs[k + pw]) * 0.06
				var f := 1.0 + clampf(shade, -0.35, 0.35)
				col = Color(col.r * f, col.g * f, col.b * f)
			img.set_pixel(i, j, col)
	_tex = ImageTexture.create_from_image(img)


func _draw_local(mr: Rect2) -> void:
	if _tex == null:
		_build_texture()
	var wsize := Vector2(LX1 - LX0, LZ1 - LZ0)
	var s := minf(mr.size.x / wsize.x, mr.size.y / wsize.y)
	var org := mr.position + (mr.size - wsize * s) * 0.5
	var box := Rect2(org, wsize * s)
	draw_texture_rect(_tex, box, false)
	draw_rect(box, JoseonUI.INK_SOFT, false, 1.5)

	# 위험 구역
	for zn in Region.ZONES:
		var d := int(zn["danger"])
		if d < 2:
			continue
		var c: Vector2 = zn["c"]
		var rad: float = zn["r"]
		var ring := PackedVector2Array()
		for k in 48:
			var a := TAU * float(k) / 48.0
			var wp := c + Vector2.from_angle(a) * rad
			ring.append(_clamp_to(_q(wp.x, wp.y, org, s), box))
		if d >= 3:
			var fill := Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.26 if d >= 4 else 0.16)
			if not Geometry2D.triangulate_polygon(ring).is_empty():
				draw_colored_polygon(ring, fill)
		var rc := ring.duplicate()
		rc.append(ring[0])
		var line_col := Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.5) if d >= 3 else Color(JoseonUI.OCHRE.r, JoseonUI.OCHRE.g, JoseonUI.OCHRE.b, 0.4)
		draw_polyline(rc, line_col, 1.2, true)

	# 도성 성벽과 궁궐
	var wall := PackedVector2Array()
	for k in 97:
		var cp := HanyangMap.crest_point(TAU * float(k) / 96.0)
		wall.append(_q(cp.x, cp.y, org, s))
	draw_polyline(wall, JoseonUI.PAPER_LIGHT, 4.5, true)
	draw_polyline(wall, JoseonUI.INK, 2.2, true)
	var pr := Rect2(_q(HanyangMap.PALACE_C.x - HanyangMap.PALACE_HALF.x, HanyangMap.PALACE_C.y - HanyangMap.PALACE_HALF.y, org, s), HanyangMap.PALACE_HALF * 2.0 * s)
	draw_rect(pr, Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.35))
	draw_rect(pr, JoseonUI.SEAL, false, 1.5)
	JoseonUI.text_halo(self, pr.position + Vector2(-14, -4), "경복궁", 12, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)
	_gate_hits.clear()
	for gi in HanyangMap.GATES.size():
		var g: Dictionary = HanyangMap.GATES[gi]
		var gp := HanyangMap.gate_pos(String(g["name"]))
		var q := _q(gp.x, gp.y, org, s)
		var hot := gi == _hover
		var half := 6.0 if hot else 4.0
		draw_rect(Rect2(q - Vector2(half, half), Vector2(half, half) * 2.0), JoseonUI.SEAL)
		if hot:
			draw_rect(Rect2(q - Vector2(half + 3.0, half + 3.0), Vector2(half + 3.0, half + 3.0) * 2.0), JoseonUI.INK, false, 1.6)
		_gate_hits.append({"rect": Rect2(q - Vector2(13, 13), Vector2(26, 26)), "name": String(g["name"]), "pos": gp})
		if bool(g["big"]) or hot:
			var label := String(g["name"]) + ("  — 눌러서 이동" if hot else "")
			JoseonUI.text_halo(self, q + Vector2(8, 5), label, 12 if hot else 11, JoseonUI.SEAL if hot else JoseonUI.INK, JoseonUI.PAPER_LIGHT)

	# 한강과 나루
	var rq := _q(-400.0, HanyangMap.river_z(-400.0), org, s)
	JoseonUI.text_halo(self, rq + Vector2(0, -6), "한강", 15, JoseonUI.INDIGO, JoseonUI.PAPER_LIGHT)
	for fy in HanRiver.FERRIES:
		var fx := float(fy["x"])
		var rz := HanyangMap.river_z(fx)
		var n_q := _q(fx + 4.0, rz - 41.0, org, s)
		var s_q := _q(fx + 4.0, rz + 41.0, org, s)
		draw_line(n_q, s_q, JoseonUI.INDIGO, 1.5)
		draw_circle(n_q, 2.5, JoseonUI.INDIGO)
		draw_circle(s_q, 2.5, JoseonUI.INDIGO)
		JoseonUI.text_halo(self, n_q + Vector2(-26, -6), String(fy["name"]), 11, JoseonUI.INDIGO, JoseonUI.PAPER_LIGHT)

	# 영남길 첫 구간
	var road := PackedVector2Array()
	for p in Region.road_points():
		road.append(_q(p.x, p.y, org, s))
	draw_polyline(road, JoseonUI.PAPER_LIGHT, 5.5, true)
	draw_polyline(road, JoseonUI.OCHRE, 3.0, true)
	for tn in Region.towns():
		var c: Vector2 = tn["c"]
		var tq := _q(c.x, c.y, org, s)
		draw_circle(tq, 5.5, JoseonUI.PAPER_LIGHT)
		draw_circle(tq, 4.0, JoseonUI.INK)
		JoseonUI.text_halo(self, tq + Vector2(8, 5), String(tn["name"]), 13, JoseonUI.INK, JoseonUI.PAPER_LIGHT)
	var end_q := road[road.size() - 1]
	JoseonUI.text_halo(self, end_q + Vector2(-70, 24), "용인·충주 쪽", 12, JoseonUI.OCHRE, JoseonUI.PAPER_LIGHT)

	# 발견한 거점: 붉은 깃발. 눌러서 바로 이동한다
	_place_hits.clear()
	for pl in Discovery.places():
		var pid := String(pl["id"])
		if not Discovery.is_found(pid):
			continue
		var dp := pl["dest"] as Vector2
		var fq := _q(dp.x, dp.y, org, s)
		var fhot := _place_hits.size() == _place_hover
		var fh := 20.0 if fhot else 16.0
		draw_line(fq, fq + Vector2(0, -fh), JoseonUI.INK, 1.8, true)
		var flag := PackedVector2Array([fq + Vector2(0, -fh), fq + Vector2(11, -fh + 4.5), fq + Vector2(0, -fh + 9.0)])
		draw_colored_polygon(flag, JoseonUI.SEAL)
		draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), JoseonUI.PAPER_LIGHT, 1.2, true)
		draw_circle(fq, 2.2, JoseonUI.INK)
		_place_hits.append({"rect": Rect2(fq + Vector2(-9, -fh - 3), Vector2(24, fh + 9)), "id": pid})
		if fhot:
			JoseonUI.text_halo(self, fq + Vector2(14, -fh + 8), String(pl["name"]) + "  — 눌러서 이동", 13, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)

	# 범 나는 곳 이름표
	var dz := Vector2(660.0, 1370.0)
	var dq := _q(dz.x, dz.y, org, s)
	JoseonUI.text_halo(self, dq + Vector2(-40, 0), "달래내 고개", 14, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)
	JoseonUI.text_halo(self, dq + Vector2(-34, 16), "범 나는 곳", 12, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)
	var cq := _q(1020.0, 1260.0, org, s)
	JoseonUI.text_halo(self, cq + Vector2(-26, 0), "청계산", 13, JoseonUI.INK_SOFT, JoseonUI.PAPER_LIGHT)

	_compass(Vector2(box.end.x - 24.0, box.position.y + 34.0))

	if player != null:
		var pq := _q(player.global_position.x, player.global_position.z, org, s)
		var yaw := player._yaw
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var perp := Vector2(-fwd.y, fwd.x)
		var pulse := 11.0 + 3.0 * sin(_t * 3.0)
		draw_arc(pq, pulse, 0.0, TAU, 24, JoseonUI.SEAL, 2.0, true)
		var tri := PackedVector2Array([pq + fwd * 10.0, pq - fwd * 6.0 + perp * 6.0, pq - fwd * 6.0 - perp * 6.0])
		draw_colored_polygon(tri, JoseonUI.SEAL)
		var tc := tri.duplicate()
		tc.append(tri[0])
		draw_polyline(tc, JoseonUI.PAPER_LIGHT, 1.5, true)


func _q(x: float, z: float, org: Vector2, s: float) -> Vector2:
	return org + Vector2(x - LX0, z - LZ0) * s


func _clamp_to(p: Vector2, box: Rect2) -> Vector2:
	return Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))


## 아래 안내띠(지역도): 지금 있는 곳, 이동 안내, 범례
func _strip_local(p: Vector2, w: float) -> void:
	if player != null:
		var zn := Region.zone_at(player.global_position.x, player.global_position.z)
		var d := int(zn["danger"])
		JoseonUI.text_bold(self, p + Vector2(0, 20), "지금 있는 곳  %s · 위험 %d단계 (%s)" % [zn["name"], d, JoseonUI.LEVEL_NAMES[d]], 19, JoseonUI.INK)
	var msg := "성문(붉은 네모)과 발견한 거점(붉은 깃발)을 누르면 바로 이동합니다.  발견 %d / %d" % [Discovery.count_found(), Discovery.places().size()]
	JoseonUI.text_bold(self, p + Vector2(0, 52), msg, 16, JoseonUI.SEAL)
	var x := p.x + w - 400.0
	var f := JoseonUI.title_font()
	draw_line(Vector2(x, p.y + 12.0), Vector2(x + 30.0, p.y + 12.0), JoseonUI.OCHRE, 3.0)
	JoseonUI.text_bold(self, Vector2(x + 38.0, p.y + 19.0), "영남길", 16, JoseonUI.INK)
	var sw := Rect2(Vector2(x + 120.0, p.y + 5.0), Vector2(26.0, 14.0))
	draw_rect(sw, Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.35))
	draw_rect(sw, JoseonUI.SEAL, false, 1.2)
	JoseonUI.text_bold(self, Vector2(x + 154.0, p.y + 19.0), "범 나는 곳", 16, JoseonUI.INK)
	draw_circle(Vector2(x + 292.0, p.y + 12.0), 4.0, JoseonUI.INK)
	JoseonUI.text_bold(self, Vector2(x + 304.0, p.y + 19.0), "마을", 16, JoseonUI.INK)
