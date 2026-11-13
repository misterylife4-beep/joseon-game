class_name CookPanel
extends CanvasLayer
## 모닥불 요리 창. 불가에서 C 를 누르면 가방의 곡식·열매 가운데 익힐 것과 개수를 골라 익히기 시작한다.
## 익히는 동안에는 화면 아래에 진행 줄이 뜨고, 불 위에서 음식이 익어 가는 모습이 보인다(CookRig).
## 시간·개수 제한은 설계값이다. 조리법은 일반적인 방식이며 사료 인용이 아니다(docs/고증_근거.md 35장).

const COLS := 4
const MAX_QTY := 3

var _sv: Survival
var _player: Player
var _panel: PanelContainer
var _grid: GridContainer
var _name_l: Label
var _method_l: Label
var _fx_l: Label
var _qty_l: Label
var _minus: Button
var _plus: Button
var _start: Button
var _empty_l: Label
var _prompt: Label
var _gauge: CookGauge
var _sel := ""
var _qty := 1
var _seen := -1
var _last_prompt := ""


func setup(sv: Survival, player: Player) -> void:
	_sv = sv
	_player = player
	_gauge.sv = sv


func _ready() -> void:
	layer = 9
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
	title.text = "모닥불 요리"
	vb.add_child(title)
	var tip := Label.new()
	tip.text = "익힐 것을 고르세요. 곡식은 솥에 끓이고, 밤과 도토리는 잿불에, 칡뿌리는 꼬치에 굽습니다."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.custom_minimum_size.x = 420.0
	vb.add_child(tip)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(_grid)
	_empty_l = Label.new()
	_empty_l.text = "익힐 곡식이나 열매가 없다."
	vb.add_child(_empty_l)
	vb.add_child(HSeparator.new())
	_name_l = Label.new()
	vb.add_child(_name_l)
	_method_l = Label.new()
	vb.add_child(_method_l)
	_fx_l = Label.new()
	vb.add_child(_fx_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	_minus = Button.new()
	_minus.text = " − "
	_minus.focus_mode = Control.FOCUS_NONE
	_minus.pressed.connect(_change_qty.bind(-1))
	row.add_child(_minus)
	_qty_l = Label.new()
	row.add_child(_qty_l)
	_plus = Button.new()
	_plus.text = " + "
	_plus.focus_mode = Control.FOCUS_NONE
	_plus.pressed.connect(_change_qty.bind(1))
	row.add_child(_plus)
	_start = Button.new()
	_start.focus_mode = Control.FOCUS_NONE
	_start.pressed.connect(_on_start)
	vb.add_child(_start)
	var close := Button.new()
	close.text = "닫기 (C)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: _set_open(false))
	vb.add_child(close)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	root.add_child(_prompt)
	UiFlow.register(_prompt, "ui_prompt", 5)
	_gauge = CookGauge.new()
	_gauge.visible = false
	root.add_child(_gauge)
	UiFlow.register(_gauge, "ui_prompt", 6)
	_restyle()


func _restyle() -> void:
	var th := JoseonUI.make_theme()
	_panel.theme = th
	_panel.add_theme_stylebox_override("panel", JoseonUI.scroll_style())
	var k := UiPrefs.font_scale
	for l in [_method_l, _fx_l, _qty_l, _empty_l]:
		(l as Label).add_theme_font_size_override("font_size", int(17.0 * k))
	_name_l.add_theme_font_size_override("font_size", int(22.0 * k))
	_name_l.add_theme_font_override("font", JoseonUI.title_font())
	var vb := _panel.get_child(0)
	var tl := vb.get_child(0) as Label
	tl.add_theme_font_size_override("font_size", int(30.0 * k))
	tl.add_theme_font_override("font", JoseonUI.title_font())
	tl.add_theme_color_override("font_color", JoseonUI.SEAL)
	var tip := vb.get_child(1) as Label
	tip.add_theme_font_size_override("font_size", int(16.0 * k))
	tip.custom_minimum_size.x = 420.0 * k
	_start.add_theme_font_size_override("font_size", int(19.0 * k))
	JoseonUI.style_toast(_prompt, 22)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_C:
		if _panel.visible:
			_set_open(false)
		else:
			_try_open()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and _panel.visible:
		_set_open(false)
		get_viewport().set_input_as_handled()


func _raw_ids() -> Array[String]:
	var out: Array[String] = []
	for id in Items.ORDER:
		if int(_sv.items.get(id, 0)) > 0:
			out.append(String(id))
	return out


func _try_open() -> void:
	if _sv == null or _player == null or _player.input_locked:
		return
	if _sv.is_cooking():
		var nm := Items.cooked_name(String(_sv.cook_job["id"]))
		_sv._hud.toast("지금 %s%s 익히고 있다." % [nm, Items.eul(nm)], 2.0, "deny")
		return
	if _sv.nearest_fire() == null:
		_sv._hud.toast("모닥불 가까이에서 C 를 눌러 요리한다.", 2.5, "deny")
		return
	if _raw_ids().is_empty():
		_sv._hud.toast("익힐 곡식이나 열매가 없다.", 2.0, "deny")
		return
	_set_open(true)


func _set_open(on: bool) -> void:
	_panel.visible = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		UiSfx.play(self, "cloth", -14.0)
		_qty = 1
		_rebuild()
		UiFx.ink_in(_panel, 0.3)
	else:
		UiSfx.play(self, "cloth_close", -18.0)


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var ids := _raw_ids()
	if not ids.has(_sel):
		_sel = ids[0] if not ids.is_empty() else ""
	var k := UiPrefs.font_scale
	for id in ids:
		_grid.add_child(_slot(id, k))
	_empty_l.visible = ids.is_empty()
	_update_detail()


func _slot(id: String, k: float) -> Button:
	var d := Items.def(id)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = id == _sel
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(104.0, 80.0) * k
	b.pressed.connect(_select.bind(id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var sw := ColorRect.new()
	sw.color = d["col"]
	sw.custom_minimum_size = Vector2(34.0, 14.0) * k
	sw.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sw)
	var nl := Label.new()
	nl.text = String(d["name"])
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", int(17.0 * k))
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nl)
	var cl := Label.new()
	cl.text = "×%d" % int(_sv.items.get(id, 0))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_theme_font_size_override("font_size", int(15.0 * k))
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cl)
	return b


func _select(id: String) -> void:
	_sel = id
	_qty = 1
	_rebuild()


func _change_qty(delta: int) -> void:
	if _sel == "":
		return
	var have := int(_sv.items.get(_sel, 0))
	_qty = clampi(_qty + delta, 1, mini(MAX_QTY, have))
	_update_detail()


func _update_detail() -> void:
	var has := _sel != ""
	_minus.visible = has
	_plus.visible = has
	_qty_l.visible = has
	_start.visible = has
	if not has:
		_name_l.text = ""
		_method_l.text = ""
		_fx_l.text = ""
		return
	var d := Items.def(_sel)
	var have := int(_sv.items.get(_sel, 0))
	_qty = clampi(_qty, 1, mini(MAX_QTY, maxi(have, 1)))
	_name_l.text = "%s  →  %s" % [String(d["name"]), Items.cooked_name(_sel)]
	_method_l.text = "%s · %d초 걸린다" % [Items.cook_method(_sel), int(Items.batch_time(_sel, _qty))]
	_fx_l.text = "날것 허기 +%d  →  익히면 +%d · 마음 +%d" % [int(d["raw"]), int(d["cook"]), int(d["morale"])]
	_qty_l.text = "%d개" % _qty
	_start.text = "익히기 시작"


func _on_start() -> void:
	if _sel == "":
		return
	var id := _sel
	var n := _qty
	_set_open(false)
	_sv.start_cook(id, n)


func _process(_delta: float) -> void:
	if _seen != UiPrefs.version:
		_seen = UiPrefs.version
		_restyle()
	if _sv == null or _player == null:
		return
	if _panel.visible and (_sv.nearest_fire() == null or _sv.is_cooking()):
		_set_open(false)
	var text := ""
	if not _panel.visible and not _player.input_locked and not _sv.is_cooking() and _sv.nearest_fire() != null and not _raw_ids().is_empty():
		text = "C  모닥불에 요리하기"
	if text != _last_prompt:
		_last_prompt = text
		var was_hidden := not _prompt.visible
		_prompt.text = text
		_prompt.visible = text != ""
		if _prompt.visible and was_hidden:
			UiFx.ink_in(_prompt, 0.45)
	_gauge.visible = _sv.is_cooking()


## 익히는 진행 줄: 한지 판 위에 이름과 불꽃빛 줄. 불 곁을 떠나면 멈춤을 알린다.
class CookGauge extends Control:
	var sv: Survival

	func _process(_d: float) -> void:
		if visible:
			custom_minimum_size = Vector2(320.0, 52.0) * UiPrefs.font_scale
			queue_redraw()

	func _draw() -> void:
		if sv == null or sv.cook_job.is_empty():
			return
		var k := UiPrefs.font_scale
		var r := Rect2(Vector2.ZERO, custom_minimum_size)
		draw_style_box(JoseonUI.plate_style(2.0), r)
		var id: String = sv.cook_job["id"]
		var n: int = sv.cook_job["n"]
		var total: float = sv.cook_job["total"]
		var left: float = sv.cook_job["left"]
		var p := clampf(1.0 - left / total, 0.0, 1.0)
		var paused: bool = sv.cook_job["paused"]
		var label := "%s %s" % [Items.cooked_name(id), Items.cook_doing(id)]
		if n > 1:
			label += " ×%d" % n
		if paused:
			label = "불 곁으로 돌아오세요"
		JoseonUI.text_halo(self, Vector2(22.0 * k, 24.0 * k), label, int(17.0 * k), JoseonUI.INK)
		var bx := 22.0 * k
		var bw := r.size.x - 44.0 * k
		var bar := Rect2(bx, r.size.y - 18.0 * k, bw, 9.0 * k)
		draw_rect(bar, Color(JoseonUI.INK_SOFT, 0.18))
		var glow := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.01)
		var col := Color(0.86, 0.42, 0.12, glow) if not paused else Color(0.5, 0.45, 0.4, 0.8)
		draw_rect(Rect2(bx, bar.position.y + 1.0, bw * p, bar.size.y - 2.0), col)
		draw_rect(bar, JoseonUI.INK, false, 2.0)
