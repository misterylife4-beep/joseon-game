class_name MiniMap
extends CanvasLayer
## 오른쪽 아래 작은 지도(아래에 가까운 성문 이름·방향·거리). N 키로 켜고 끈다. 지도 화면(M)의 지역도 그림을 그대로 쓰며
## 플레이어를 가운데에 두고 위쪽이 북쪽이다. 보이는 범위(520 m)와 크기는 설계값이다.

const LOGICAL := 220.0
const WINDOW := 520.0
const BORDER := 10.0
const STRIP := 40.0
## 성문 이름 정보: 한자, 흔히 부르던 이름. 8문의 위치·이름은 도성 8문(사료)을 따르되 1396년의 정확한 명칭은 [추정]이다.
const GATE_INFO := {
	"숙정문": ["肅靖門", "북대문"],
	"창의문": ["彰義門", "자하문"],
	"혜화문": ["惠化門", "동소문"],
	"흥인지문": ["興仁之門", "동대문"],
	"광희문": ["光熙門", "수구문"],
	"숭례문": ["崇禮門", "남대문"],
	"소의문": ["昭義門", "서소문"],
	"돈의문": ["敦義門", "서대문"],
}
const DIRS := ["동", "북동", "북", "북서", "서", "남서", "남", "남동"]

var _player: Player
var _view: MiniView


func setup(player: Player) -> void:
	_player = player
	_view.player = player


func _ready() -> void:
	layer = 6
	_view = MiniView.new()
	add_child(_view)
	UiFlow.register(_view, "ui_corner_r", 0)
	_view.visible = UiPrefs.minimap_on


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_N:
		return
	if _player != null and _player.input_locked:
		return
	UiPrefs.minimap_on = not UiPrefs.minimap_on
	UiPrefs.changed()
	_view.visible = UiPrefs.minimap_on
	UiSfx.play(self, "page", -16.0)
	get_viewport().set_input_as_handled()


class MiniView extends Control:
	var player: Player
	var _acc := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		custom_minimum_size = Vector2(MiniMap.LOGICAL, MiniMap.LOGICAL + MiniMap.STRIP)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5)
		var want := Vector2(MiniMap.LOGICAL, MiniMap.LOGICAL + MiniMap.STRIP) * k
		if custom_minimum_size != want:
			custom_minimum_size = want
			size = want
		_acc += delta
		if visible and _acc >= 0.08:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var full := Rect2(Vector2.ZERO, Vector2(MiniMap.LOGICAL, MiniMap.LOGICAL))
		var inner := full.grow(-MiniMap.BORDER)
		draw_rect(full, JoseonUI.PAPER)
		if player == null:
			return
		var c := Vector2(player.global_position.x, player.global_position.z)
		var sc := inner.size.x / MiniMap.WINDOW
		var win := Rect2(c - Vector2(MiniMap.WINDOW, MiniMap.WINDOW) * 0.5, Vector2(MiniMap.WINDOW, MiniMap.WINDOW))
		draw_rect(inner, JoseonUI.SEA)
		var tex := MapCanvas.ensure_texture()
		var bounds := Rect2(MapCanvas.LX0, MapCanvas.LZ0, tex.get_width() * MapCanvas.CELL, tex.get_height() * MapCanvas.CELL)
		var inter := win.intersection(bounds)
		if inter.has_area():
			var src := Rect2((inter.position - bounds.position) / MapCanvas.CELL, inter.size / MapCanvas.CELL)
			var dst := Rect2(inner.position + (inter.position - win.position) * sc, inter.size * sc)
			draw_texture_rect_region(tex, dst, src)
		# 위험한 곳
		for zn in Region.ZONES:
			if int(zn["danger"]) >= 3:
				var zc: Vector2 = zn["c"]
				draw_circle(_w(zc, win, inner, sc), float(zn["r"]) * sc, Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.16))
		# 영남길
		var road := PackedVector2Array()
		for p in Region.road_points():
			road.append(_w(p, win, inner, sc))
		draw_polyline(road, JoseonUI.PAPER_LIGHT, 4.0, true)
		draw_polyline(road, JoseonUI.OCHRE, 2.0, true)
		# 성벽, 궁궐, 성문
		var wall := PackedVector2Array()
		for i in 97:
			var cp := HanyangMap.crest_point(TAU * float(i) / 96.0)
			wall.append(_w(cp, win, inner, sc))
		draw_polyline(wall, JoseonUI.PAPER_LIGHT, 3.5, true)
		draw_polyline(wall, JoseonUI.INK, 1.8, true)
		var pr := Rect2(_w(HanyangMap.PALACE_C - HanyangMap.PALACE_HALF, win, inner, sc), HanyangMap.PALACE_HALF * 2.0 * sc)
		draw_rect(pr, Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, 0.4))
		for g in HanyangMap.GATES:
			var q := _w(HanyangMap.gate_pos(String(g["name"])), win, inner, sc)
			draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), JoseonUI.SEAL)
			if inner.grow(-16.0).has_point(q):
				JoseonUI.text_halo(self, q + Vector2(5.0, -4.0), String(g["name"]), 11, JoseonUI.SEAL, JoseonUI.PAPER_LIGHT)
		for tn in Region.towns():
			var q2 := _w(tn["c"] as Vector2, win, inner, sc)
			draw_circle(q2, 3.5, JoseonUI.PAPER_LIGHT)
			draw_circle(q2, 2.4, JoseonUI.INK)
		# 나 (가운데)
		var yaw := player._yaw
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var perp := Vector2(-fwd.y, fwd.x)
		var pc := inner.get_center()
		var tri := PackedVector2Array([pc + fwd * 8.0, pc - fwd * 5.0 + perp * 5.0, pc - fwd * 5.0 - perp * 5.0])
		draw_circle(pc, 9.0, Color(JoseonUI.PAPER_LIGHT.r, JoseonUI.PAPER_LIGHT.g, JoseonUI.PAPER_LIGHT.b, 0.7))
		draw_colored_polygon(tri, JoseonUI.SEAL)
		# 이름표와 북쪽 표시
		var zone := Region.zone_at(c.x, c.y)
		var name_text := String(zone["name"])
		var nw := JoseonUI.font().get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		JoseonUI.text_halo(self, Vector2(inner.get_center().x - nw * 0.5, inner.end.y - 6.0), name_text, 13, JoseonUI.INK, JoseonUI.PAPER_LIGHT)
		JoseonUI.text_halo(self, Vector2(inner.get_center().x - 7.0, inner.position.y + 14.0), "北", 13, JoseonUI.INK, JoseonUI.PAPER_LIGHT)
		# 테두리: 안쪽 바깥을 한지로 덮고 먹선 두 줄
		var b := MiniMap.BORDER
		draw_rect(Rect2(0, 0, full.size.x, b), JoseonUI.PAPER)
		draw_rect(Rect2(0, full.size.y - b, full.size.x, b), JoseonUI.PAPER)
		draw_rect(Rect2(0, 0, b, full.size.y), JoseonUI.PAPER)
		draw_rect(Rect2(full.size.x - b, 0, b, full.size.y), JoseonUI.PAPER)
		draw_rect(full.grow(-1.5), JoseonUI.INK, false, 3.0)
		draw_rect(inner.grow(1.5), JoseonUI.INK_SOFT, false, 1.2)
		_draw_strip(c)


	func _draw_strip(c: Vector2) -> void:
		var r := Rect2(0.0, MiniMap.LOGICAL + 4.0, MiniMap.LOGICAL, MiniMap.STRIP - 4.0)
		draw_rect(r, JoseonUI.PAPER)
		draw_rect(r.grow(-1.5), JoseonUI.INK, false, 2.5)
		var best := ""
		var bd := INF
		var bp := Vector2.ZERO
		for g in HanyangMap.GATES:
			var gp := HanyangMap.gate_pos(String(g["name"]))
			var d := c.distance_to(gp)
			if d < bd:
				bd = d
				best = String(g["name"])
				bp = gp
		var info: Array = MiniMap.GATE_INFO.get(best, ["", ""])
		var v := bp - c
		var ang := rad_to_deg(atan2(-v.y, v.x))
		var dir: String = MiniMap.DIRS[int(roundf(wrapf(ang, 0.0, 360.0) / 45.0)) % 8]
		var dist := "%d m" % int(roundf(bd / 5.0) * 5.0) if bd < 1000.0 else "%.1f km" % (bd / 1000.0)
		JoseonUI.text_halo(self, Vector2(10.0, r.position.y + 16.0), "가까운 문 · %s %s" % [best, String(info[0])], 13, JoseonUI.INK, JoseonUI.PAPER)
		JoseonUI.text_halo(self, Vector2(10.0, r.position.y + 31.0), "%s · %s쪽 · %s" % [String(info[1]), dir, dist], 12, JoseonUI.INK_SOFT, JoseonUI.PAPER)

	func _w(p: Vector2, win: Rect2, inner: Rect2, sc: float) -> Vector2:
		return inner.position + (p - win.position) * sc
