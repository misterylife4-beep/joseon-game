class_name UiFlow
extends Node
## 화면 글자판 자동 배치. 여러 UI(상태, 알림, 안내, 대화창)가 서로 겹쳐 가리지 않게 매 프레임 쌓아 배치한다.
## 각 칸은 그룹에 등록하고 "ui_order" 값으로 순서를 정한다.
##   ui_left   : 왼쪽 위에서 아래로 쌓음 (정보, 상태 판)
##   ui_banner : 위 가운데 날짜 배너. 겹치지 않게 폭에 맞춰 줄어들고, 알림(ui_toast)은 그 아래부터 쌓인다
##   ui_toast  : 위 가운데에서 아래로 쌓음 (알림)
##   ui_hint   : 왼쪽 아래에서 위로 쌓음 (조작 안내)
##   ui_corner : 왼쪽 아래 모서리 (예비)
##   ui_corner_r : 오른쪽 아래 모서리 (미니맵)
##   ui_btn    : 오른쪽 위 안내판 바로 아래에 오른쪽부터 나란히 놓는 단추 줄 (가방, 시간, 목표)
##   ui_right  : 오른쪽 위에서 아래로 쌓음 (지금 할 일). ui_avoid_right 칸(시간 판) 아래부터 시작
##   ui_prompt : 가운데 아래, 안내 위로 쌓음 ([E] 대화 등)
##   ui_dialogue : 대화창이 열려 있으면 아래 칸들은 그 위로 올라간다
## 너무 긴 글자판은 화면 폭 안에서 줄바꿈한다. 모든 길이는 설계값이다.

const GAP := 8.0
const MARGIN := 16.0
const TOP_TOAST := 56.0


static func register(n: Control, group: String, order: int) -> void:
	n.add_to_group(group)
	n.set_meta("ui_order", order)


func _process(_delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var vp := get_viewport().get_visible_rect().size

	# 왼쪽 위 줄
	var y := 12.0
	var left_edge := 0.0
	for n in _items("ui_left"):
		var s := _fit(n, minf(440.0, vp.x * 0.42))
		n.position = Vector2(MARGIN, y)
		y += s.y + GAP
		left_edge = maxf(left_edge, MARGIN + s.x)

	# 위 가운데 날짜 배너: 왼쪽 줄·오른쪽 단추와 겹치지 않게 쓸 수 있는 폭에 맞춰 줄이고, 알림은 그 아래에서 시작한다
	var ban_bottom := 0.0
	for b in tree.get_nodes_in_group("ui_banner"):
		var bc := b as Control
		if bc == null or not bc.visible:
			continue
		var l_edge := 0.0
		for n in _items("ui_left"):
			if n.position.y < 190.0:
				l_edge = maxf(l_edge, n.position.x + n.size.x)
		var r_edge := vp.x - MARGIN
		for g in ["ui_right", "ui_btn", "ui_avoid_right"]:
			for n in tree.get_nodes_in_group(g):
				var rc := n as Control
				if rc != null and rc.is_visible_in_tree():
					var rr := rc.get_global_rect()
					if rr.position.y < 190.0 and rr.size.x > 1.0:
						r_edge = minf(r_edge, rr.position.x)
		var half := minf(vp.x * 0.5 - l_edge, r_edge - vp.x * 0.5) - GAP
		bc.call("set_fit", maxf(half, 40.0) * 2.0)
		ban_bottom = float(bc.call("bottom_y"))

	# 위 가운데 알림 (오른쪽 시간 판과 안 겹치게 폭 제한)
	var ty := maxf(TOP_TOAST, ban_bottom + GAP)
	# 가운데 알림은 왼쪽 줄과 오른쪽 시간 판 사이에서만 펼친다 (좌우 같은 여백)
	var side := maxf(left_edge + 2.0 * GAP, 400.0)
	var toast_max := maxf(240.0, vp.x - 2.0 * side)
	for n in _items("ui_toast"):
		var s := _fit(n, toast_max)
		var tx := (vp.x - s.x) * 0.5
		if tx < left_edge + GAP:
			# 화면이 좁아 왼쪽 줄과 가로로 겹치면 그 줄 아래로 내려 놓는다
			ty = maxf(ty, y)
			tx = maxf(tx, MARGIN)
		n.position = Vector2(tx, ty)
		ty += s.y + GAP

	# 아래: 대화창이 열려 있으면 그 위, 아니면 화면 아래 끝
	var base := vp.y - MARGIN
	for d in tree.get_nodes_in_group("ui_dialogue"):
		var dc := d as Control
		if dc != null and dc.is_visible_in_tree():
			base = minf(base, dc.get_global_rect().position.y - GAP)
	var hint_top := base
	for n in _items("ui_hint"):
		var s := _fit(n, vp.x - 2.0 * MARGIN)
		n.position = Vector2(MARGIN, hint_top - s.y)
		hint_top -= s.y + GAP
	# 오른쪽 위: 시간 판 같은 칸 아래에서 시작
	var ry := 12.0
	for a in tree.get_nodes_in_group("ui_avoid_right"):
		var ac := a as Control
		if ac != null and ac.is_visible_in_tree():
			ry = maxf(ry, ac.get_global_rect().end.y + GAP)
	for n in _items("ui_right"):
		var s := _fit(n, minf(380.0, vp.x * 0.3))
		n.position = Vector2(vp.x - MARGIN - s.x, ry)
		ry += s.y + GAP
	# 단추 줄: 안내판 아래에 오른쪽부터 한 줄로
	var bx := vp.x - MARGIN
	var row_h := 0.0
	for n in _items("ui_btn"):
		var s := _fit(n, 200.0)
		n.position = Vector2(bx - s.x, ry)
		bx -= s.x + GAP
		row_h = maxf(row_h, s.y)
	if row_h > 0.0:
		ry += row_h + GAP
	# 오른쪽 아래 모서리 칸(미니맵)
	var cy := base  # 대화창이 열리면 그 위로 올라간다
	for n in _items("ui_corner_r"):
		var s := _fit(n, vp.x * 0.4)
		n.position = Vector2(vp.x - MARGIN - s.x, cy - s.y)
		cy -= s.y + GAP
	# 왼쪽 아래 모서리 칸(미니맵): 안내 줄 위에 얹는다. 가운데 알림 줄에는 영향을 주지 않는다.
	var ct := hint_top
	for n in _items("ui_corner"):
		var s := _fit(n, vp.x * 0.3)
		n.position = Vector2(MARGIN, ct - s.y)
		ct -= s.y + GAP
	var py := hint_top
	for n in _items("ui_prompt"):
		var s := _fit(n, vp.x * 0.8)
		n.position = Vector2((vp.x - s.x) * 0.5, py - s.y)
		py -= s.y + GAP


## 보이는 칸만, 순서대로
func _items(group: String) -> Array[Control]:
	var out: Array[Control] = []
	for n in get_tree().get_nodes_in_group(group):
		var c := n as Control
		if c != null and c.visible:
			out.append(c)
	out.sort_custom(func(a: Control, b: Control) -> bool: return int(a.get_meta("ui_order", 0)) < int(b.get_meta("ui_order", 0)))
	return out


## 폭 제한 안에서 크기를 정하고 그 크기를 돌려준다.
func _fit(n: Control, max_w: float) -> Vector2:
	if not n.has_meta("ui_flow_init"):
		n.set_meta("ui_flow_init", true)
		n.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		n.grow_horizontal = Control.GROW_DIRECTION_END
		n.grow_vertical = Control.GROW_DIRECTION_END
	if n is Label:
		var l := n as Label
		# 호출한 쪽이 넣은 원문과, 우리가 줄을 나눠 넣은 글을 구분한다
		var raw: String = l.text
		if l.has_meta("ui_shown"):
			if raw == String(l.get_meta("ui_shown")):
				raw = String(l.get_meta("ui_raw"))
			elif raw == String(l.get_meta("ui_raw")):
				l.text = String(l.get_meta("ui_shown"))  # 같은 원문이 다시 들어오면 나눈 글로 되돌린다
		l.set_meta("ui_raw", raw)
		var key := "%s|%d|%d" % [raw, UiPrefs.version, int(max_w)]
		if l.get_meta("ui_key", "") != key:
			l.set_meta("ui_key", key)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.custom_minimum_size.x = 0.0
			l.size = Vector2.ZERO
			var shown := TextFit.fit(l, raw, max_w)
			l.text = shown
			l.set_meta("ui_shown", shown)
			var nat := l.get_combined_minimum_size().x
			if nat > max_w:
				# 낱말 하나가 너무 길 때만 어쩔 수 없이 낱말 경계 줄바꿈에 맡긴다
				l.autowrap_mode = TextServer.AUTOWRAP_WORD
				l.custom_minimum_size.x = max_w
			l.set_meta("ui_nat", nat)
		var w := minf(float(l.get_meta("ui_nat", 0.0)), max_w)
		l.size = Vector2(maxf(w, l.custom_minimum_size.x), 0.0)
	var ms := n.get_combined_minimum_size()
	n.size = Vector2(maxf(n.size.x, ms.x), ms.y)
	return n.size
