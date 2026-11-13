class_name CraftPanel
extends CanvasLayer
## 제작대. X 키나 화면 오른쪽의 "제작대" 단추로 연다. 땔감과 산에서 주운 돌로 칼·도끼·곡괭이를 만들고,
## 가진 연장을 손에 든다. 마우스를 쓰려면 Esc로 풀어야 하고, 창을 열면 자동으로 풀린다.
## 칸 크기와 문구는 설계값이다(docs/고증_근거.md 50장).

var _sv: Survival
var _gear: Gear
var _btn: CraftButton
var _panel: PanelContainer
var _mat_l: Label
var _stone_l: Label
var _wear_l: Label
var _tab := 0
var _tab_btns: Array[Button] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _help_l: Label
var _seen := -1


func setup(sv: Survival, gear: Gear) -> void:
	_sv = sv
	_gear = gear
	_sv.bag_changed.connect(_refresh)
	_gear.changed.connect(_refresh)
	_refresh()


func _ready() -> void:
	add_to_group("side_panel")
	layer = 9
	if not InputMap.has_action("craft_panel"):
		InputMap.add_action("craft_panel")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_X
		InputMap.action_add_event("craft_panel", ev)
	_btn = CraftButton.new()
	_btn.pressed.connect(toggle)
	add_child(_btn)
	UiFlow.register(_btn, "ui_btn", 3)

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
	title.text = "제작대"
	title.set_meta("title", true)
	vb.add_child(title)
	_mat_l = Label.new()
	vb.add_child(_mat_l)
	_stone_l = Label.new()
	_stone_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_stone_l)
	_wear_l = Label.new()
	_wear_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(_wear_l)
	vb.add_child(HSeparator.new())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var grp := ButtonGroup.new()
	for ti in Gear.CATS.size():
		var tb := Button.new()
		tb.text = Gear.CATS[ti]
		tb.toggle_mode = true
		tb.button_group = grp
		tb.button_pressed = ti == 0
		tb.focus_mode = Control.FOCUS_NONE
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func() -> void:
			_tab = ti
			_refresh())
		tabs.add_child(tb)
		_tab_btns.append(tb)
	vb.add_child(tabs)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_list)
	vb.add_child(_scroll)
	vb.add_child(HSeparator.new())
	_help_l = Label.new()
	_help_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_help_l.text = "좌클릭 휘두르기 · Q 연장 바꿔 들기\n도끼로 나무를 베어 땔감을, 짐승을 잡아 고기와 가죽을 얻는다. 가죽으로 옷과 살림을 만든다."
	vb.add_child(_help_l)
	var close := Button.new()
	close.text = "닫기 (X)"
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
	if key.keycode == KEY_X:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and _panel.visible:
		_set_open(false)
		get_viewport().set_input_as_handled()


func close_panel(except: Node) -> void:
	if except != self and _panel.visible:
		_panel.visible = false
		UiSfx.play(self, "cloth_close", -16.0)


func toggle() -> void:
	_set_open(not _panel.visible)


func _set_open(on: bool) -> void:
	if on and _sv != null and _sv._player != null and _sv._player.input_locked:
		return
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


func _process(_delta: float) -> void:
	if _seen != UiPrefs.version:
		_seen = UiPrefs.version
		_restyle()
		_refresh()
	if _btn != null and _gear != null:
		_btn.set_state(_gear.tools.size(), _panel.visible)


func _restyle() -> void:
	var th := JoseonUI.make_theme()
	_panel.theme = th
	_panel.add_theme_stylebox_override("panel", JoseonUI.scroll_style())
	var k := UiPrefs.font_scale
	for l in [_mat_l, _stone_l, _wear_l, _help_l]:
		(l as Label).add_theme_font_size_override("font_size", int(17.0 * k))
	_stone_l.custom_minimum_size.x = 460.0 * k
	_wear_l.custom_minimum_size.x = 460.0 * k
	for tb in _tab_btns:
		tb.add_theme_font_size_override("font_size", int(19.0 * k))
		tb.custom_minimum_size.y = 42.0 * k
	_help_l.custom_minimum_size.x = 460.0 * k
	var vh := get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
	_scroll.custom_minimum_size = Vector2(580.0 * k, clampf(vh * 0.5, 240.0, 460.0 * k))
	var tl := _panel.get_child(0).get_child(0) as Label
	tl.add_theme_font_size_override("font_size", int(30.0 * k))
	tl.add_theme_font_override("font", JoseonUI.title_font())
	tl.add_theme_color_override("font_color", JoseonUI.SEAL)


func _refresh() -> void:
	if _list == null or _sv == null or _gear == null:
		return
	var k := UiPrefs.font_scale
	_mat_l.text = "땔감 %d단 · 돌 %d개 · 가죽 %d장 · 고기 %d점 · 깃털 %d · 힘줄 %d · 화살 %d발" % [_sv.firewood, _gear.stone_total(), _gear.hide_count(), _gear.meat_total(), _gear.feathers, _gear.sinew, _gear.arrows]
	var parts: Array[String] = []
	for id in Gear.STONE_ORDER:
		var n := int(_gear.stones.get(id, 0))
		if n > 0:
			parts.append("%s ×%d" % [Gear.stone_name(id), n])
	for hid in Gear.HIDE_ORDER:
		var hn := int(_gear.hides.get(hid, 0))
		if hn > 0:
			parts.append("%s ×%d" % [Gear.hide_name(hid), hn])
	_stone_l.text = "가진 재료: " + (" · ".join(parts) if not parts.is_empty() else "돌은 산에서, 가죽은 짐승을 잡아 얻는다.")
	var wp: Array[String] = []
	for sl in ["head", "neck", "body", "hands", "feet"]:
		if _gear.worn.has(sl):
			wp.append(String(Gear.GOODS[String(_gear.worn[sl])]["name"]))
	_wear_l.text = "입은 것: %s  (추위 −%d%% · 피해 −%d%% · 기력 −%d%%)" % [
		" · ".join(wp) if not wp.is_empty() else "없음", int(round(_gear.cold_resist() * 100.0)), int(round(_gear.dmg_cut() * 100.0)), int(round(_gear.stam_save() * 100.0))]
	for c in _list.get_children():
		c.queue_free()
	for id in Gear.CAT_ORDER[_tab]:
		_list.add_child(_row(String(id), k))


func _effects(d: Dictionary) -> String:
	var e: Array[String] = []
	if float(d.get("cold", 0.0)) > 0.0:
		e.append("추위 −%d%%" % int(round(float(d["cold"]) * 100.0)))
	if float(d.get("cut", 0.0)) > 0.0:
		e.append("피해 −%d%%" % int(round(float(d["cut"]) * 100.0)))
	if float(d.get("stam", 0.0)) > 0.0:
		e.append("달리기 기력 −%d%%" % int(round(float(d["stam"]) * 100.0)))
	if float(d.get("morale", 0.0)) > 0.0:
		e.append("마음 +%d" % int(d["morale"]))
	return " · ".join(e)


func _row(id: String, k: float) -> Control:
	var d: Dictionary = Gear.recipe(id)
	var is_tool := Gear.TOOLS.has(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.custom_minimum_size.x = 400.0 * k
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var cost: Array[String] = []
	var c := Gear.cost_of(id)
	for key in c:
		cost.append("%s %d" % [String(Gear.COST_NAME[key]), int(c[key])])
	var nm := Label.new()
	nm.text = "%s   (%s)" % [String(d["name"]), " + ".join(cost)]
	nm.set_meta("bold", true)
	nm.add_theme_font_size_override("font_size", int(21.0 * k))
	nm.add_theme_font_override("font", JoseonUI.title_font())
	left.add_child(nm)
	var ds := Label.new()
	if is_tool and String(d["kind"]) == "bow":
		ds.text = "%s  %d회 · 화살 %d발" % [String(d["desc"]), int(_gear.tools.get(id, d["dur"])), _gear.arrows]
	elif is_tool:
		ds.text = "%s  힘 %d%s · %d회" % [String(d["desc"]), int(d["dmg"]), (" · 벌목 %.1f" % float(d["chop"])) if float(d["chop"]) > 0.0 else "", int(_gear.tools.get(id, d["dur"]))]
	else:
		var ef := _effects(d)
		ds.text = String(d["desc"]) + ("  " + ef if ef != "" else "")
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD
	ds.custom_minimum_size.x = 400.0 * k
	ds.add_theme_font_size_override("font_size", int(15.0 * k))
	left.add_child(ds)
	var bt := Button.new()
	bt.focus_mode = Control.FOCUS_NONE
	bt.custom_minimum_size = Vector2(130.0, 44.0) * k
	bt.add_theme_font_size_override("font_size", int(18.0 * k))
	var owned := _gear.tools.has(id) or (_gear.goods.has(id) and String(d.get("give", "")) == "")
	if owned:
		if is_tool:
			var held := _gear.equipped == id
			bt.text = "내려놓기" if held else "손에 들기"
			bt.pressed.connect(func() -> void:
				_gear.equip("" if held else id))
		elif String(d.get("slot", "")) != "":
			var on := String(_gear.worn.get(String(d["slot"]), "")) == id
			bt.text = "벗기" if on else "입기"
			bt.pressed.connect(func() -> void:
				_gear.toggle_wear(id))
		else:
			bt.text = "가졌다"
			bt.disabled = true
	else:
		var why := _gear.why_not(id)
		bt.text = "만들기" if why == "" else "재료 부족"
		bt.tooltip_text = why
		bt.disabled = why != ""
		bt.pressed.connect(func() -> void:
			_gear.craft(id))
	row.add_child(bt)
	return row


## 화면 오른쪽의 제작대 단추: 널빤지 작업대 위에 도끼가 놓인 모양 (설계값)
class CraftButton extends Control:
	signal pressed

	const LW := 84.0
	const LH := 100.0

	var count := 0
	var open := false
	var _hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "제작대 (X)"
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

	func _process(_delta: float) -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5) * 0.74  # 단추 줄여 쓰기
		var want := Vector2(LW, LH) * k
		if custom_minimum_size != want:
			custom_minimum_size = want
			size = want

	func _draw() -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5) * 0.74  # 단추 줄여 쓰기
		JoseonUI.button_plate(self, size, _hover, open)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var wood := JoseonUI.WOOD
		var dark := Color(0.28, 0.18, 0.1)
		var ink := JoseonUI.INK
		# 작업대: 상판과 네 다리
		draw_colored_polygon(PackedVector2Array([Vector2(12, 50), Vector2(72, 50), Vector2(68, 60), Vector2(16, 60)]), wood)
		draw_polyline(PackedVector2Array([Vector2(12, 50), Vector2(72, 50), Vector2(68, 60), Vector2(16, 60), Vector2(12, 50)]), ink, 1.6, true)
		for x in [18.0, 62.0]:
			var lx: float = x
			draw_rect(Rect2(lx, 60.0, 5.0, 18.0), dark)
		draw_line(Vector2(22, 70), Vector2(62, 70), dark, 2.0, true)
		# 도끼: 자루와 돌날
		draw_line(Vector2(30, 48), Vector2(54, 22), dark, 3.4, true)
		draw_colored_polygon(PackedVector2Array([Vector2(50, 17), Vector2(62, 20), Vector2(58, 32), Vector2(48, 28)]), Color(0.6, 0.6, 0.58))
		draw_polyline(PackedVector2Array([Vector2(50, 17), Vector2(62, 20), Vector2(58, 32), Vector2(48, 28), Vector2(50, 17)]), ink, 1.4, true)
		if count > 0:
			var sc := Vector2(68.0, 14.0)
			draw_circle(sc, 11.0, JoseonUI.SEAL)
			draw_arc(sc, 11.0, 0.0, TAU, 20, JoseonUI.PAPER_LIGHT, 1.2, true)
			var txt := str(mini(count, 99))
			var f := JoseonUI.title_font()
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, sc + Vector2(-tw * 0.5, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, JoseonUI.PAPER_LIGHT)
		var cap := "제작대  X"
		var cf := JoseonUI.title_font()
		var cw := cf.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		JoseonUI.text_bold(self, Vector2((LW - cw) * 0.5, LH - 12.0), cap, 17, JoseonUI.INK, JoseonUI.PAPER)
