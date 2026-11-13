class_name BagPanel
extends CanvasLayer
## 가방. B 키나 화면 오른쪽의 "가방" 단추로 연다. 지닌 곡식·열매와 땔감, 지금까지 먹은 것을 보여 주고
## 고른 것을 먹을 수 있다(R도 같다). 마우스를 쓰려면 Esc로 마우스를 풀어야 하고, 가방을 열면 자동으로 풀린다.
## 칸 크기와 문구는 설계값이다.

const COLS := 4

var _sv: Survival
var _btn: BagButton
var _panel: PanelContainer
var _grid: GridContainer
var _name_l: Label
var _desc_l: Label
var _fx_l: Label
var _eat_btn: Button
var _eaten_l: Label
var _wood_l: Label
var _empty_l: Label
var _sel := ""
var _seen := -1
var _acc := 0.0


func setup(sv: Survival) -> void:
	_sv = sv
	_sv.bag_changed.connect(_refresh)
	_sv.cook_changed.connect(_refresh)
	_refresh()


func _ready() -> void:
	add_to_group("side_panel")
	layer = 9
	_btn = BagButton.new()
	_btn.pressed.connect(toggle)
	add_child(_btn)
	UiFlow.register(_btn, "ui_btn", 0)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "가방"
	title.set_meta("title", true)
	vb.add_child(title)
	_wood_l = Label.new()
	vb.add_child(_wood_l)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(_grid)
	_empty_l = Label.new()
	_empty_l.text = "가방이 비었다. 곡식과 열매를 주워 보자."
	vb.add_child(_empty_l)
	vb.add_child(HSeparator.new())
	_name_l = Label.new()
	_name_l.set_meta("bold", true)
	vb.add_child(_name_l)
	_desc_l = Label.new()
	_desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_desc_l)
	_fx_l = Label.new()
	vb.add_child(_fx_l)
	_eat_btn = Button.new()
	_eat_btn.focus_mode = Control.FOCUS_NONE
	_eat_btn.pressed.connect(_on_eat)
	vb.add_child(_eat_btn)
	vb.add_child(HSeparator.new())
	var eh := Label.new()
	eh.text = "먹은 것"
	eh.set_meta("bold", true)
	vb.add_child(eh)
	_eaten_l = Label.new()
	_eaten_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_eaten_l)
	var close := Button.new()
	close.text = "닫기 (B)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	vb.add_child(close)
	_restyle()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_B:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and _panel.visible:
		_set_open(false)
		get_viewport().set_input_as_handled()


## 다른 단추 창이 열리면 이 창은 닫는다
func close_panel(except: Node) -> void:
	if except != self and _panel.visible:
		_panel.visible = false
		UiSfx.play(self, "cloth_close", -16.0)


func toggle() -> void:
	_set_open(not _panel.visible)


func _set_open(on: bool) -> void:
	if on and _sv != null and _sv._player != null and _sv._player.input_locked:
		return  # 대화 중에는 열지 않는다
	if on:
		get_tree().call_group("side_panel", "close_panel", self)
	_panel.visible = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		UiSfx.play(self, "cloth", -12.0)
		_refresh()
		UiFx.ink_in(_panel, 0.3)
	else:
		UiSfx.play(self, "cloth_close", -16.0)


func _process(delta: float) -> void:
	if _seen != UiPrefs.version:
		_seen = UiPrefs.version
		_restyle()
		_refresh()
	_acc += delta
	if _acc < 0.3:
		return
	_acc = 0.0
	if _sv == null:
		return
	var total := _sv.grain + _sv.firewood
	_btn.set_state(total, _panel.visible)
	if _panel.visible:
		_update_detail()


func _restyle() -> void:
	var th := JoseonUI.make_theme()
	_panel.theme = th
	_panel.add_theme_stylebox_override("panel", JoseonUI.scroll_style())
	var k := UiPrefs.font_scale
	for l in [_wood_l, _empty_l, _desc_l, _fx_l, _eaten_l]:
		(l as Label).add_theme_font_size_override("font_size", int(17.0 * k))
	_desc_l.custom_minimum_size.x = 380.0 * k
	_eaten_l.custom_minimum_size.x = 380.0 * k
	for l2 in [_name_l]:
		(l2 as Label).add_theme_font_size_override("font_size", int(22.0 * k))
		(l2 as Label).add_theme_font_override("font", JoseonUI.title_font())
	var tl := _panel.get_child(0).get_child(0) as Label
	tl.add_theme_font_size_override("font_size", int(30.0 * k))
	tl.add_theme_font_override("font", JoseonUI.title_font())
	tl.add_theme_color_override("font_color", JoseonUI.SEAL)
	_eat_btn.add_theme_font_size_override("font_size", int(18.0 * k))


func _refresh() -> void:
	if _grid == null or _sv == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var k := UiPrefs.font_scale
	var any := false
	if _sel != "" and _sv.count_of(_sel) <= 0:
		_sel = ""
	for id in Items.ORDER:
		var cn := int(_sv.cooked.get(id, 0))
		if cn <= 0:
			continue
		any = true
		if _sel == "":
			_sel = "c:" + String(id)
		_grid.add_child(_slot("c:" + String(id), cn, k))
	for id in Items.ORDER:
		var n := int(_sv.items.get(id, 0))
		if n <= 0:
			continue
		any = true
		if _sel == "":
			_sel = id
		_grid.add_child(_slot(id, n, k))
	_empty_l.visible = not any
	_wood_l.text = "땔감 %d단" % _sv.firewood
	if _sv.gear != null:
		_wood_l.text += " · 돌 %d개 · 가죽 %d장" % [_sv.gear.stone_total(), _sv.gear.hide_count()]
		if _sv.gear.feathers > 0 or _sv.gear.arrows > 0 or _sv.gear.sinew > 0:
			_wood_l.text += " · 깃털 %d · 힘줄 %d · 화살 %d발" % [_sv.gear.feathers, _sv.gear.sinew, _sv.gear.arrows]
	if _sv.is_cooking():
		_wood_l.text += " · 익히는 중: %s" % String(Items.def(String(_sv.cook_job["id"]))["name"])
	var parts: Array[String] = []
	for id in Items.ORDER:
		if int(_sv.eaten.get(id, 0)) > 0:
			parts.append("%s ×%d" % [String(Items.def(id)["name"]), int(_sv.eaten[id])])
	_eaten_l.text = "아직 먹은 것이 없다." if parts.is_empty() else " · ".join(parts)
	_sv.selected = _sel
	_update_detail()


func _slot(key: String, n: int, k: float) -> Button:
	var id := Items.key_id(key)
	var cooked := Items.key_cooked(key)
	var d := Items.def(id)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = key == _sel
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(104.0, 88.0) * k
	b.pressed.connect(_select.bind(key))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var sw := ColorRect.new()
	var base: Color = d["col"]
	sw.color = base.lerp(Color(0.45, 0.26, 0.1), 0.55) if cooked else base
	sw.custom_minimum_size = Vector2(34.0, 16.0) * k
	sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sw)
	var nl := Label.new()
	nl.text = Items.cooked_name(id) if cooked else String(d["name"])
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", int(17.0 * k))
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nl)
	var cl := Label.new()
	cl.text = ("익힘 ×%d" if cooked else "×%d") % n
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_theme_font_size_override("font_size", int(15.0 * k))
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cl)
	return b


func _select(key: String) -> void:
	_sel = key
	_sv.selected = key
	_refresh()


func _update_detail() -> void:
	if _sel == "" or _sv == null:
		_name_l.text = ""
		_desc_l.text = ""
		_fx_l.text = ""
		_eat_btn.visible = false
		return
	var id := Items.key_id(_sel)
	var cooked := Items.key_cooked(_sel)
	var d := Items.def(id)
	if cooked:
		_name_l.text = "%s  (%s)" % [Items.cooked_name(id), String(d["name"])]
		_desc_l.text = "모닥불에서 익힌 음식. " + String(d["desc"])
		_fx_l.text = "허기 +%d · 마음 +%d · 체온 +%d" % [int(d["cook"]), int(d["morale"]), 8 if _sv.near_fire() else 4]
	else:
		_name_l.text = "%s  %s" % [String(d["name"]), String(d["hanja"])]
		_desc_l.text = String(d["desc"])
		_fx_l.text = "날것 허기 +%d · 모닥불에서 익히면 +%d  (불가에서 C)" % [int(d["raw"]), int(d["cook"])]
	_eat_btn.visible = true
	_eat_btn.text = "먹기 (R)"


func _on_eat() -> void:
	if _sel == "":
		return
	_sv.eat_item(_sel)


## 화면 오른쪽의 가방 단추: 길 떠나는 이가 어깨에 메던 괴나리봇짐(천으로 싸 매듭지은 짐)을 그린다.
## 괴나리봇짐은 선비와 보부상이 먼 길에 지던 작은 보따리로, 모양과 색은 설계값이다(docs/고증_근거.md 33장).
class BagButton extends Control:
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
		tooltip_text = "가방 (B)"
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func set_state(n: int, is_open: bool) -> void:
		if n != count or is_open != open:
			count = n
			open = is_open
			queue_redraw()

	func _on_enter() -> void:
		_hover = true
		UiSfx.play(self, "tick", -28.0)
		queue_redraw()

	func _on_exit() -> void:
		_hover = false
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
		var lift := -2.5 if _hover else 0.0
		var sway := sin(_t * 5.0) * 1.6 if _hover else 0.0
		_bundle(Vector2(42.0, 46.0 + lift), sway)
		# 갯수 도장
		if count > 0:
			var sc := Vector2(68.0, 18.0)
			draw_circle(sc, 11.0, JoseonUI.SEAL)
			draw_arc(sc, 11.0, 0.0, TAU, 20, JoseonUI.PAPER_LIGHT, 1.2, true)
			var txt := str(mini(count, 99))
			var f := JoseonUI.title_font()
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, sc + Vector2(-tw * 0.5, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, JoseonUI.PAPER_LIGHT)
		# 이름과 단축키
		var cap := "가방  B"
		var cf := JoseonUI.title_font()
		var cw := cf.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		JoseonUI.text_bold(self, Vector2((LW - cw) * 0.5, LH - 12.0), cap, 18, JoseonUI.INK, JoseonUI.PAPER)

	## 괴나리봇짐: 어깨끈 두 줄, 천으로 싼 짐, 위의 매듭, 가슴 쪽 가로 끈
	func _bundle(c: Vector2, sway: float) -> void:
		var rope := JoseonUI.WOOD
		var cloth := Color(0.78, 0.66, 0.44)
		var shade := Color(0.6, 0.48, 0.3)
		var ink := JoseonUI.INK
		# 어깨끈
		for sx in [-1.0, 1.0]:
			var s: float = sx
			var pts := PackedVector2Array()
			for i in 11:
				var t := float(i) / 10.0
				pts.append(c + Vector2(s * (16.0 + 14.0 * t), -8.0 - 28.0 * sin(t * PI * 0.5)))
			draw_polyline(pts, rope, 2.6, true)
		# 짐 몸통: 아래가 불룩한 보따리
		var body := PackedVector2Array()
		for i in 25:
			var a := PI * float(i) / 24.0
			body.append(c + Vector2(cos(a) * 25.0, 4.0 + sin(a) * 22.0))
		body.append(c + Vector2(-25.0, 4.0))
		body.append(c + Vector2(-17.0, -10.0))
		body.append(c + Vector2(17.0, -10.0))
		body.append(c + Vector2(25.0, 4.0))
		draw_colored_polygon(body, cloth)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-23, 12), c + Vector2(23, 12), c + Vector2(15, 24), c + Vector2(-15, 24)]), shade)
		draw_polyline(body, ink, 1.8, true)
		# 천 주름과 가로 끈
		draw_line(c + Vector2(-20.0, 0.0), c + Vector2(20.0, 0.0), rope, 3.0, true)
		draw_arc(c + Vector2(0.0, 6.0), 14.0, 0.2, PI - 0.2, 12, shade, 1.4, true)
		for dx in [-14.0, -7.0, 7.0, 14.0]:
			var x: float = dx
			draw_line(c + Vector2(x, 8.0), c + Vector2(x + 2.0, 17.0), shade, 1.2, true)
		# 매듭: 천 모서리 둘과 동여맨 끈
		var kn := c + Vector2(0.0, -12.0)
		draw_colored_polygon(PackedVector2Array([kn + Vector2(-3, 2), kn + Vector2(-13 + sway, -9), kn + Vector2(-6 + sway, -13), kn + Vector2(1, -2)]), cloth)
		draw_polyline(PackedVector2Array([kn + Vector2(-3, 2), kn + Vector2(-13 + sway, -9), kn + Vector2(-6 + sway, -13), kn + Vector2(1, -2)]), ink, 1.4, true)
		draw_colored_polygon(PackedVector2Array([kn + Vector2(3, 2), kn + Vector2(13 + sway, -9), kn + Vector2(6 + sway, -13), kn + Vector2(-1, -2)]), cloth)
		draw_polyline(PackedVector2Array([kn + Vector2(3, 2), kn + Vector2(13 + sway, -9), kn + Vector2(6 + sway, -13), kn + Vector2(-1, -2)]), ink, 1.4, true)
		draw_circle(kn + Vector2(0, 1), 3.6, rope)
		draw_circle(kn + Vector2(0, 1), 1.4, cloth)
