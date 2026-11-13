class_name GameMenu
extends CanvasLayer
## 시작 화면과 일시정지(Esc) 메뉴. 한지판 위에 먹글씨 단추를 놓은 같은 모양을 쓴다.
##  시작 화면: 이어하기(저장이 있을 때) · 새로 시작 · 게임 나가기
##  일시정지 : 계속하기 · 저장하기 · 게임 나가기
## 열려 있는 동안 게임 세계는 멈춘다(트리 일시정지). 위·아래(W·S) 키와 Enter로도 고를 수 있다.
## 글자 크기와 간격은 설계값이다.

enum Mode { TITLE, PAUSE }

signal continue_game
signal new_game
signal resume
signal quit_game

var mode := Mode.TITLE
## 저장하기 단추가 부르는 함수 (저장 성공 여부 bool을 돌려준다)
var do_save := Callable()

var _panel: PanelContainer
var _col: VBoxContainer
var _title: _Title
var _msg: Label
var _info: Label
var _btns: Array[_Btn] = []
var _sel := 0
var _confirm := false
var _status := ""
var _hidden: Array[CanvasLayer] = []   ## 시작 화면 동안 가려 둔 게임 화면 UI


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiPrefs.ensure()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode == Mode.TITLE:
		# 시작 화면에는 게임 안의 상태판·목표·지도·안내 글을 모두 숨긴다 (메뉴만 보이게)
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			var cl := n as CanvasLayer
			if cl != null and cl != self and cl.visible and cl.layer < 150:
				cl.visible = false
				_hidden.append(cl)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.62 if mode == Mode.TITLE else 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = JoseonUI.make_theme()
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_stylebox_override("panel", JoseonUI.plate_style(18.0, true))
	root.add_child(_panel)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", int(10.0 * _k()))
	_panel.add_child(_col)

	_show_main()
	UiSfx.play(self, "scroll", -12.0)


func _exit_tree() -> void:
	for cl in _hidden:
		if is_instance_valid(cl):
			cl.visible = true
	_hidden.clear()


func _k() -> float:
	return clampf(UiPrefs.font_scale, 0.6, 1.4) * 1.15


func _clear() -> void:
	for c in _col.get_children():
		c.queue_free()
		_col.remove_child(c)
	_btns.clear()
	_sel = 0


func _header(sub: String) -> void:
	var k := _k()
	_title = _Title.new()
	_title.text = "조선야사" if mode == Mode.TITLE else "잠시 멈춤"
	_title.sub = sub
	_title.custom_minimum_size = Vector2(440.0 * k, (118.0 if sub != "" else 92.0) * k)
	_col.add_child(_title)
	var dv := _Divider.new()
	dv.custom_minimum_size = Vector2(0.0, 18.0 * k)
	_col.add_child(dv)


func _footer_msg(text: String) -> void:
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(420.0 * _k(), 0.0)
	JoseonUI.style_label(l, 20, false, JoseonUI.INK_SOFT)
	_col.add_child(l)


func _add_btn(text: String, cb: Callable, enabled := true) -> void:
	var b := _Btn.new()
	b.text = text
	b.enabled = enabled
	b.k = _k()
	b.pressed.connect(func() -> void:
		if b.enabled:
			UiSfx.play(self, "stamp", -14.0)
			cb.call())
	b.hovered.connect(func() -> void:
		if b.enabled:
			_set_sel(_btns.find(b), true))
	_col.add_child(b)
	_btns.append(b)


func _set_sel(i: int, sound := false) -> void:
	if _btns.is_empty():
		return
	i = clampi(i, 0, _btns.size() - 1)
	if sound and i != _sel:
		UiSfx.play(self, "tick", -28.0)
	_sel = i
	for j in _btns.size():
		_btns[j].selected = j == _sel
		_btns[j].queue_redraw()


func _first_enabled() -> int:
	for j in _btns.size():
		if _btns[j].enabled:
			return j
	return 0


func _show_main() -> void:
	_confirm = false
	_clear()
	if mode == Mode.TITLE:
		_header("태조 5년 · 한양 · 성 쌓는 해")
		var inf := SaveGame.info()
		_add_btn("이어하기", _on_continue, not inf.is_empty())
		_add_btn("새로 시작", _on_new)
		_add_btn("게임 나가기", func() -> void: quit_game.emit())
		if not inf.is_empty():
			_footer_msg("%s\n저장한 때  %s" % [inf["summary"], inf["saved"]])
		else:
			_footer_msg("저장된 진행이 없습니다.")
	else:
		_header("")
		_add_btn("계속하기", func() -> void: resume.emit())
		_add_btn("저장하기", _on_save)
		_add_btn("게임 나가기", _on_quit_pause)
		_footer_msg(_status if _status != "" else "화면 설정은 F6, 조작 안내는 H 키")
	_set_sel(_first_enabled())


func _show_confirm(text: String, entries: Array) -> void:
	_confirm = true
	_clear()
	_header("")
	_footer_msg(text)
	for e in entries:
		var cb: Callable = e[1]
		_add_btn(String(e[0]), cb)
	_set_sel(0)


func _on_continue() -> void:
	continue_game.emit()


func _on_new() -> void:
	if SaveGame.exists():
		_show_confirm("저장된 진행이 사라집니다.\n정말 새로 시작할까요?", [
			["새로 시작", func() -> void: new_game.emit()],
			["돌아가기", _show_main],
		])
	else:
		new_game.emit()


func _on_save() -> void:
	var ok := false
	if do_save.is_valid():
		ok = bool(do_save.call())
	_status = "저장했습니다." if ok else "저장하지 못했습니다. 다시 시도해 주세요."
	_show_main()


func _on_quit_pause() -> void:
	_show_confirm("나가기 전에 저장할까요?", [
		["저장하고 나가기", func() -> void:
			if do_save.is_valid():
				do_save.call()
			quit_game.emit()],
		["저장 없이 나가기", func() -> void: quit_game.emit()],
		["돌아가기", _show_main],
	])


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	var handled := true
	match k.keycode:
		KEY_UP, KEY_W:
			_move_sel(-1)
		KEY_DOWN, KEY_S:
			_move_sel(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _btns.is_empty() and _btns[_sel].enabled:
				_btns[_sel].pressed.emit()
		KEY_ESCAPE:
			if _confirm:
				_show_main()
			elif mode == Mode.PAUSE:
				resume.emit()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _move_sel(d: int) -> void:
	if _btns.is_empty():
		return
	var i := _sel
	for _n in _btns.size():
		i = (i + d + _btns.size()) % _btns.size()
		if _btns[i].enabled:
			break
	_set_sel(i, true)


## 큰 제목: 먹글씨와 아래 작은 글
class _Title extends Control:
	var text := ""
	var sub := ""

	func _draw() -> void:
		var k := clampf(UiPrefs.font_scale, 0.6, 1.4) * 1.15
		var f := JoseonUI.title_font()
		var fs := int(66.0 * k)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := Vector2((size.x - w) * 0.5, 66.0 * k)
		draw_string(f, base + Vector2(3.0, 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.25))
		JoseonUI.text_bold(self, base, text, fs, JoseonUI.INK, JoseonUI.PAPER)
		if sub != "":
			var sfs := int(22.0 * k)
			var sf := JoseonUI.font()
			var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
			draw_string(sf, Vector2((size.x - sw) * 0.5, 100.0 * k), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, JoseonUI.INK_SOFT)
		JoseonUI.seal(self, Vector2(size.x * 0.5 + w * 0.5 + 10.0 * k, 12.0 * k), 30.0 * k, "朝")


## 가는 선과 가운데 금빛 마름모
class _Divider extends Control:
	func _draw() -> void:
		var cx := size.x * 0.5
		var y := size.y * 0.5
		var ic := JoseonUI.INK_SOFT
		var gc := JoseonUI.OCHRE
		for sgn in [-1.0, 1.0]:
			var s: float = sgn
			draw_line(Vector2(cx + s * 14.0, y), Vector2(cx + s * size.x * 0.4, y), Color(ic.r, ic.g, ic.b, 0.8), 1.6)
			draw_line(Vector2(cx + s * 14.0, y + 3.0), Vector2(cx + s * size.x * 0.32, y + 3.0), Color(gc.r, gc.g, gc.b, 0.7), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 6.0), Vector2(cx + 6.0, y), Vector2(cx, y + 6.0), Vector2(cx - 6.0, y)]), JoseonUI.SEAL)


## 메뉴 단추: 한지판 단추 모양에 먹글씨
class _Btn extends Control:
	signal pressed
	signal hovered

	var text := ""
	var enabled := true
	var selected := false
	var k := 1.0
	var _down := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(func() -> void: hovered.emit())

	func _ready() -> void:
		custom_minimum_size = Vector2(300.0 * k, 54.0 * k)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_down = true
					queue_redraw()
				else:
					var was := _down
					_down = false
					queue_redraw()
					if was and Rect2(Vector2.ZERO, size).has_point(mb.position):
						pressed.emit()
				accept_event()

	func _draw() -> void:
		JoseonUI.button_plate(self, size, selected and enabled, _down)
		var f := JoseonUI.title_font()
		var fs := int(27.0 * k)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := JoseonUI.INK if enabled else Color(JoseonUI.INK.r, JoseonUI.INK.g, JoseonUI.INK.b, 0.35)
		var halo := JoseonUI.PAPER if enabled else Color(JoseonUI.PAPER.r, JoseonUI.PAPER.g, JoseonUI.PAPER.b, 0.3)
		JoseonUI.text_bold(self, Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.34 + (2.0 if _down else 0.0)), text, fs, col, halo)
		if selected and enabled:
			var gc := JoseonUI.SEAL
			for sx in [10.0, size.x - 10.0]:
				var x: float = sx
				draw_colored_polygon(PackedVector2Array([Vector2(x, size.y * 0.5 - 5.0), Vector2(x + 5.0, size.y * 0.5), Vector2(x, size.y * 0.5 + 5.0), Vector2(x - 5.0, size.y * 0.5)]), gc)
