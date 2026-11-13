class_name GoalsPanel
extends CanvasLayer
## 목표 단추와 목표판. 화면 오른쪽 위 단추(두루마리)나 O 키로 막별 주요 목표를 펼쳐 본다.
## 목표 글은 ActGoals 를 그대로 읽는다. 두루마리 모양과 칸 크기는 설계값이다.

var _btn: GoalsButton
var _board: GoalsBoard
var _acc := 0.0
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _player: Player


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	add_to_group("side_panel")
	layer = 9
	_btn = GoalsButton.new()
	_btn.pressed.connect(toggle)
	add_child(_btn)
	UiFlow.register(_btn, "ui_btn", 2)
	_board = GoalsBoard.new()
	_board.visible = false
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_board)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_O:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and _board.visible:
		_set_open(false)
		get_viewport().set_input_as_handled()


func close_panel(except: Node) -> void:
	if except != self and _board.visible:
		_board.visible = false
		_btn.open = false
		_btn.queue_redraw()


func toggle() -> void:
	_set_open(not _board.visible)


func _set_open(on: bool) -> void:
	if on and _player != null and _player.input_locked:
		return
	if on == _board.visible:
		return
	if on:
		get_tree().call_group("side_panel", "close_panel", self)
	_board.visible = on
	_btn.open = on
	_btn.queue_redraw()
	if on:
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		UiSfx.play(self, "scroll", -12.0)
		UiFx.ink_in(_board, 0.6)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		UiSfx.play(self, "page", -16.0)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.3:
		return
	_acc = 0.0
	_btn.set_count(ActGoals.remaining(ActGoals.current_act()).size())
	if _board.visible:
		_board.queue_redraw()


## 목표 단추: 족자(두루마리 게시문). 위아래 막대에 한지를 걸고 붓글씨 몇 줄과 붉은 낙관을 찍었다.
class GoalsButton extends Control:
	signal pressed

	const LW := 84.0
	const LH := 100.0

	var count := 0
	var open := false
	var _hover := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "목표 (O)"
		mouse_entered.connect(func() -> void:
			_hover = true
			UiSfx.play(self, "tick", -28.0)
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func set_count(n: int) -> void:
		if n != count:
			count = n
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pressed.emit()
				accept_event()

	func _process(delta: float) -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5) * 0.74  # 단추 줄여 쓰기
		var want := Vector2(LW, LH) * k
		if custom_minimum_size != want:
			custom_minimum_size = want
			size = want
		if _hover:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5) * 0.74  # 단추 줄여 쓰기
		JoseonUI.button_plate(self, size, _hover, open)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var sway := sin(_t * 5.0) * 1.2 if _hover else 0.0
		var lift := -2.0 if _hover else 0.0
		var wood := JoseonUI.WOOD
		var wood_l := Color(0.46, 0.32, 0.18)
		var gold := Color(0.80, 0.62, 0.26)
		var paper := Color(0.96, 0.92, 0.80)
		var paper_d := Color(0.86, 0.79, 0.62)
		var ink := JoseonUI.INK
		# 족자는 위아래 여백까지 모두 단추 안(0~84 x 0~100 중 위 72까지)에 들어오게 그린다
		var cx := 40.0
		var top_y := 20.0 + lift
		var bot_y := 66.0 + lift
		var half_w := 17.0
		# 걸이 끈: 두 갈래가 위 한 점에서 모인다
		draw_polyline(PackedVector2Array([Vector2(cx - 13.0, top_y - 2.0), Vector2(cx + sway, top_y - 14.0), Vector2(cx + 13.0, top_y - 2.0)]), wood, 1.8, true)
		draw_circle(Vector2(cx + sway, top_y - 14.0), 2.2, gold)
		# 한지: 위는 밝고 아래로 갈수록 그늘, 가장자리에 먹선
		var tl := Vector2(cx - half_w, top_y)
		var tr := Vector2(cx + half_w, top_y)
		var br := Vector2(cx + half_w, bot_y)
		var bl := Vector2(cx - half_w, bot_y)
		draw_polygon(PackedVector2Array([tl, tr, br, bl]), PackedColorArray([paper, paper, paper_d, paper_d]))
		draw_rect(Rect2(tl, Vector2(half_w * 2.0, bot_y - top_y)), ink, false, 1.3)
		draw_line(tl + Vector2(3.0, 3.0), tr + Vector2(-3.0, 3.0), Color(1, 1, 1, 0.55), 1.0)
		# 세로로 쓴 글줄 세 줄 (조선 문서는 위에서 아래로 쓴다)
		var cols := [[cx - 9.0, 17.0], [cx - 1.0, 23.0], [cx + 7.0, 13.0]]
		for cl in cols:
			var lx: float = cl[0]
			var ll: float = cl[1]
			for j in int(ll / 5.0):
				var yy := top_y + 7.0 + float(j) * 5.0
				var dw := 2.6 if j % 3 != 1 else 1.8
				draw_line(Vector2(lx, yy), Vector2(lx, yy + 3.2), ink, dw, true)
		# 낙관: 붉은 인장에 완료 표시
		var sp := Vector2(cx + 8.0, bot_y - 9.0)
		draw_rect(Rect2(sp - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), JoseonUI.SEAL)
		draw_rect(Rect2(sp - Vector2(6.0, 6.0), Vector2(12.0, 12.0)).grow(-1.5), Color(1, 1, 1, 0.25), false, 1.0)
		draw_polyline(PackedVector2Array([sp + Vector2(-3.0, 0.0), sp + Vector2(-0.8, 2.8), sp + Vector2(3.4, -3.0)]), paper, 1.8, true)
		# 위아래 축: 나무 몸통, 윗면 하이라이트, 금빛 마개
		for ry in [top_y - 5.0, bot_y]:
			var y: float = ry
			var rod := Rect2(Vector2(cx - half_w - 4.0, y), Vector2(half_w * 2.0 + 8.0, 5.0))
			draw_rect(rod, wood)
			draw_rect(Rect2(rod.position + Vector2(0.0, 0.6), Vector2(rod.size.x, 1.6)), wood_l)
			draw_rect(rod, ink, false, 1.0)
			draw_rect(Rect2(Vector2(rod.position.x - 2.5, y - 0.5), Vector2(3.0, 6.0)), gold)
			draw_rect(Rect2(Vector2(rod.end.x - 0.5, y - 0.5), Vector2(3.0, 6.0)), gold)
		# 남은 목표 수 도장
		if count > 0:
			var sc := Vector2(68.0, 17.0)
			draw_circle(sc, 11.0, JoseonUI.SEAL)
			draw_arc(sc, 11.0, 0.0, TAU, 20, JoseonUI.PAPER_LIGHT, 1.2, true)
			var txt := str(mini(count, 99))
			var f := JoseonUI.title_font()
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, sc + Vector2(-tw * 0.5, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, JoseonUI.PAPER_LIGHT)
		var cap := "목표  O"
		var cf := JoseonUI.title_font()
		var cw := cf.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		JoseonUI.text_bold(self, Vector2((LW - cw) * 0.5, LH - 12.0), cap, 18, ink, JoseonUI.PAPER)


## 막별 목표를 적어 놓은 한지 판
class GoalsBoard extends Control:
	const LOGICAL := Vector2(470.0, 700.0)

	var _fibers := PackedVector2Array()
	var _bottom := 9999.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	## 글자 크기 설정을 따르되 화면 높이에 다 들어오게 줄인다
	func _k() -> float:
		var vh := get_viewport_rect().size.y - 40.0
		return minf(clampf(UiPrefs.font_scale, 0.5, 1.5), vh / LOGICAL.y)

	func _process(_d: float) -> void:
		if visible:
			var want := LOGICAL * _k()
			if custom_minimum_size != want:
				custom_minimum_size = want
				size = want

	func _para(x: float, y: float, w: float, text: String, fs: int, col: Color) -> float:
		var f := JoseonUI.font()
		var h := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
		if y + h > _bottom:
			return y + h + 10.0
		draw_multiline_string(f, Vector2(x, y + float(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
		return y + h + 10.0

	func _mark(c: Vector2, done: bool) -> void:
		if done:
			draw_arc(c, 7.0, 0.0, TAU, 20, JoseonUI.PINE, 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-3.5, 0.5), c + Vector2(-1.0, 3.5), c + Vector2(4.0, -3.5)]), JoseonUI.PINE, 2.2, true)
		else:
			draw_arc(c, 7.0, 0.0, TAU, 20, JoseonUI.INK, 1.6, true)

	func _draw() -> void:
		var k := _k()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var r := Rect2(Vector2.ZERO, LOGICAL)
		draw_rect(r, JoseonUI.PAPER)
		if _fibers.is_empty():
			_fibers = JoseonUI.fibers(r, 160, 1397)
		draw_multiline(_fibers, Color(0.55, 0.47, 0.33, 0.16), 1.0)
		JoseonUI.frame(self, r.grow(-8.0))
		JoseonUI.seal(self, Vector2(28.0, 24.0), 40.0, "목표")
		draw_string(JoseonUI.title_font(), Vector2(80.0, 52.0), "막별 주요 목표", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, JoseonUI.INK)
		var hint := "O 또는 Esc 닫기"
		var hw := JoseonUI.font().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(JoseonUI.font(), Vector2(r.end.x - hw - 30.0, r.end.y - 22.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, JoseonUI.INK_SOFT)
		_bottom = r.end.y - 34.0
		var x := 36.0
		var w := r.size.x - 72.0
		var y := 84.0
		var f := JoseonUI.font()
		var cur := ActGoals.current_act()
		for i in ActGoals.ACTS.size():
			var a: Dictionary = ActGoals.ACTS[i]
			var is_open := bool(a["open"])
			var head_col := JoseonUI.INK if is_open else JoseonUI.INK_SOFT
			var title: String = a["name"]
			if i == cur:
				title = "▶ " + title
			if y + 24.0 > _bottom:
				return
			draw_string(JoseonUI.title_font(), Vector2(x, y + 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, head_col)
			var when_text: String = a["when"] if is_open else "%s · 준비 중" % a["when"]
			y += 26.0
			y = _para(x, y, w, when_text, 13, JoseonUI.INK_SOFT) - 4.0
			if not is_open:
				y += 8.0
				continue
			for g in a["goals"]:
				var done := ActGoals.is_done(g)
				var col := JoseonUI.INK_SOFT if done else JoseonUI.INK
				var text := ActGoals.goal_text(g)
				var th := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 26.0, 16).y
				if y + th > _bottom:
					return
				_mark(Vector2(x + 8.0, y + 11.0), done)
				draw_multiline_string(f, Vector2(x + 26.0, y + 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, w - 26.0, 16, -1, col)
				if done:
					draw_line(Vector2(x + 26.0, y + 11.0), Vector2(x + 26.0 + minf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, w - 26.0), y + 11.0), Color(col.r, col.g, col.b, 0.55), 1.2)
				y += th + 7.0
			var later: String = a["later"]
			if later != "":
				y = _para(x + 26.0, y, w - 26.0, later, 13, JoseonUI.INK_SOFT)
			y += 8.0
