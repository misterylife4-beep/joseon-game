class_name UiSettings
extends CanvasLayer
## F6 화면 설정: 스타일(한지/단청/수묵), 글자 크기, 판 투명도, 장식 테두리, 조작 안내.
## 바꾸는 즉시 모든 UI와 지도에 반영되고 user://ui_prefs.cfg 에 저장된다.
## 만족할 때까지 이 창에서 직접 보며 맞추고, 더 바꾸고 싶은 점은 말로 알려주면 새 항목을 더한다.

var _panel: PanelContainer
var _theme_opt: OptionButton
var _scale: HSlider
var _scale_val: Label
var _opacity: HSlider
var _opacity_val: Label
var _ornament: CheckBox
var _hint: CheckBox
var _syncing := false
var _seen_version := -1
var _prev_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 25
	UiPrefs.ensure()
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(380, 0)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "화면 설정  (F6 으로 닫기)"
	box.add_child(title)

	var sl := Label.new()
	sl.text = "스타일"
	box.add_child(sl)
	_theme_opt = OptionButton.new()
	_theme_opt.focus_mode = Control.FOCUS_NONE
	for n in JoseonUI.THEME_NAMES:
		_theme_opt.add_item(n)
	_theme_opt.item_selected.connect(_on_theme)
	box.add_child(_theme_opt)

	_scale_val = Label.new()
	box.add_child(_scale_val)
	_scale = _slider(0.5, 1.5, 0.05, box)
	_scale.value_changed.connect(_on_scale)

	_opacity_val = Label.new()
	box.add_child(_opacity_val)
	_opacity = _slider(0.4, 1.0, 0.05, box)
	_opacity.value_changed.connect(_on_opacity)

	_ornament = CheckBox.new()
	_ornament.text = "판 테두리 장식"
	_ornament.focus_mode = Control.FOCUS_NONE
	_ornament.toggled.connect(_on_ornament)
	box.add_child(_ornament)

	_hint = CheckBox.new()
	_hint.text = "조작 안내 항상 펼치기"
	_hint.focus_mode = Control.FOCUS_NONE
	_hint.toggled.connect(_on_hint)
	box.add_child(_hint)

	var reset := Button.new()
	reset.text = "처음 설정으로"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_on_reset)
	box.add_child(reset)
	_sync()


func _slider(lo: float, hi: float, step: float, parent: Control) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	parent.add_child(s)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_sync()
	else:
		Input.mouse_mode = _prev_mouse


func _process(_delta: float) -> void:
	if _seen_version != UiPrefs.version:
		_seen_version = UiPrefs.version
		_panel.theme = JoseonUI.make_theme()
		_sync()


func _sync() -> void:
	_syncing = true
	_theme_opt.select(UiPrefs.theme_id)
	_scale.value = UiPrefs.font_scale
	_opacity.value = UiPrefs.opacity
	_ornament.button_pressed = UiPrefs.ornament
	_hint.button_pressed = UiPrefs.hint_open
	_scale_val.text = "화면 크기  %d%%" % int(round(UiPrefs.font_scale * 100.0))
	_opacity_val.text = "판 진하기  %d%%" % int(round(UiPrefs.opacity * 100.0))
	_syncing = false


func _on_theme(idx: int) -> void:
	if _syncing:
		return
	UiPrefs.theme_id = idx
	UiPrefs.changed()


func _on_scale(v: float) -> void:
	if _syncing:
		return
	UiPrefs.font_scale = v
	UiPrefs.changed()


func _on_opacity(v: float) -> void:
	if _syncing:
		return
	UiPrefs.opacity = v
	UiPrefs.changed()


func _on_ornament(on: bool) -> void:
	if _syncing:
		return
	UiPrefs.ornament = on
	UiPrefs.changed()


func _on_hint(on: bool) -> void:
	if _syncing:
		return
	UiPrefs.hint_open = on
	UiPrefs.changed()


func _on_reset() -> void:
	UiPrefs.theme_id = 0
	UiPrefs.font_scale = UiPrefs.DEFAULT_SCALE
	UiPrefs.opacity = 0.92
	UiPrefs.ornament = true
	UiPrefs.hint_open = false
	UiPrefs.changed()
