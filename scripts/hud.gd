class_name Hud
extends CanvasLayer
## 화면 UI. 상태 표시, 상호작용 안내, 방(榜) 모양 알림, 백지본 패널, 두루마리 대화창을 코드로 만든다.
## 모양은 JoseonUI(한지·먹·주칠 등)와 UiPrefs(글자 크기·판 투명도·장식)를 따른다.
## 글꼴은 res://fonts/ 의 나눔명조 등을 먼저 찾고, 없으면 윈도우의 바탕체를 쓴다 (JoseonUI.font).

const HINT_FULL := "WASD 이동 · Shift 달리기 · Space 점프 · E 수집 · J 백지본 · M 지도 · N 미니맵(오른쪽 아래) · B 가방 · T 시간 · F6 화면 설정 · Esc 메뉴(저장·나가기) · F2 한국화 · F3 고급 조명 · H 접기"
const HINT_SHORT := "H  조작 안내"

var _info: Label
var _prompt: Label
var _toast: Label
var _hint: Label
var _ledger_panel: PanelContainer
var _ledger_text: RichTextLabel
var _dialogue_panel: PanelContainer
var _dialogue_name: Label
var _dialogue_text: Label
var _dialogue_hint: Label
var _toast_left := 0.0
var _seen_version := -1


func _ready() -> void:
	UiPrefs.ensure()
	UiSfx.hook(get_tree())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	root.theme = JoseonUI.make_theme()

	add_child(UiFlow.new())

	_info = _make_label(root)
	_info.position = Vector2(16, 12)
	UiFlow.register(_info, "ui_left", 0)

	root.add_child(DateBanner.new())   # 화면 위 가운데의 한자 날짜

	_prompt = _make_label(root)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_top = -80.0
	_prompt.offset_bottom = -80.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	UiFlow.register(_prompt, "ui_prompt", 0)

	_toast = _make_label(root)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 182.0
	_toast.offset_bottom = 182.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	UiFlow.register(_toast, "ui_toast", 0)

	_hint = _make_label(root)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = 16.0
	_hint.offset_top = -16.0
	_hint.offset_bottom = -16.0
	UiFlow.register(_hint, "ui_hint", 0)

	_ledger_panel = PanelContainer.new()
	_ledger_panel.custom_minimum_size = Vector2(780, 440)
	_ledger_panel.visible = false
	root.add_child(_ledger_panel)
	_ledger_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_ledger_panel.add_child(margin)

	_ledger_text = RichTextLabel.new()
	_ledger_text.bbcode_enabled = true
	_ledger_text.custom_minimum_size = Vector2(740, 400)
	margin.add_child(_ledger_text)

	_build_dialogue_panel(root)

	Records.ledger_changed.connect(refresh_ledger)
	refresh_ledger()
	_restyle()


func _process(delta: float) -> void:
	if _seen_version != UiPrefs.version:
		_restyle()
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
			_toast.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		UiSfx.play(self, "toggle", -16.0)
		UiPrefs.hint_open = not UiPrefs.hint_open
		UiPrefs.changed()
		get_viewport().set_input_as_handled()


## 스타일(색·글자 크기·판 투명도)이 바뀌었을 때 모든 칸을 다시 꾸민다.
func _restyle() -> void:
	_seen_version = UiPrefs.version
	JoseonUI.style_label(_info, 20)
	JoseonUI.style_toast(_prompt, 24)
	JoseonUI.style_toast(_toast, 24)
	JoseonUI.style_label(_hint, 16)
	_hint.text = HINT_FULL if UiPrefs.hint_open else HINT_SHORT
	_ledger_panel.add_theme_stylebox_override("panel", JoseonUI.plate_style(12.0, true))
	_ledger_text.add_theme_color_override("default_color", JoseonUI.INK)
	_ledger_text.add_theme_color_override("font_selected_color", JoseonUI.INK)
	_ledger_text.add_theme_font_size_override("normal_font_size", int(20.0 * UiPrefs.font_scale))
	_ledger_text.add_theme_font_size_override("bold_font_size", int(24.0 * UiPrefs.font_scale))
	_dialogue_panel.add_theme_stylebox_override("panel", JoseonUI.scroll_style())
	_dialogue_name.add_theme_font_override("font", JoseonUI.title_font())
	_dialogue_name.add_theme_font_size_override("font_size", int(26.0 * UiPrefs.font_scale))
	_dialogue_name.add_theme_color_override("font_color", JoseonUI.SEAL)
	_dialogue_text.add_theme_font_size_override("font_size", int(24.0 * UiPrefs.font_scale))
	_dialogue_text.add_theme_color_override("font_color", JoseonUI.INK)
	_dialogue_hint.add_theme_font_size_override("font_size", int(17.0 * UiPrefs.font_scale))
	_dialogue_hint.add_theme_color_override("font_color", JoseonUI.INK_SOFT)


func set_info(text: String) -> void:
	_info.text = text


func set_prompt(text: String) -> void:
	var was_hidden := not _prompt.visible
	_prompt.text = text
	_prompt.visible = text != ""
	if _prompt.visible and was_hidden:
		UiFx.ink_in(_prompt, 0.45)


## 방(榜): 길에 붙이는 알림 글. 판 위에 먹으로 쓴다.
func show_toast(text: String, seconds: float = 3.0) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = seconds
	UiFx.ink_in(_toast, 0.8)
	UiSfx.play(self, UiSfx.toast_kind(text), -12.0)


func show_ledger(on: bool) -> void:
	_ledger_panel.visible = on
	if on:
		refresh_ledger()


func refresh_ledger() -> void:
	var lines: PackedStringArray = []
	lines.append("[b]백지본(白紙本)[/b]")
	lines.append("숫자키로 기록할 증거를 고르세요. 기록하면 진실이 남지만 가문이 위험해집니다. J로 닫기.")
	lines.append("")
	if Records.order.is_empty():
		lines.append("아직 수집한 증거가 없습니다.")
	for i in Records.order.size():
		var e: Dictionary = Records.evidence[Records.order[i]]
		var state := "기록함" if bool(e["written"]) else "보류"
		lines.append("%d. (%s) %s  - 위험 %d / 진실 %d" % [i + 1, state, e["title"], int(e["risk"]), int(e["truth"])])
		lines.append("      " + str(e["text"]))
	lines.append("")
	lines.append("가문 위험도: %d      기록한 진실: %d / %d" % [Records.family_risk, Records.written_truth(), Records.total_truth()])
	_ledger_text.text = "\n".join(lines)


func show_dialogue(speaker: String, text: String, hint: String) -> void:
	_dialogue_name.text = speaker
	_dialogue_text.text = text
	_dialogue_hint.text = hint
	var was_open := _dialogue_panel.visible
	_dialogue_panel.visible = true
	if not was_open:
		UiFx.ink_in(_dialogue_panel, 0.7)
		UiSfx.play(self, "scroll", -12.0)
	else:
		UiSfx.play(self, "page", -16.0)


func hide_dialogue() -> void:
	_dialogue_panel.visible = false


func _build_dialogue_panel(root: Control) -> void:
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.visible = false
	root.add_child(_dialogue_panel)
	_dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialogue_panel.offset_left = 120.0
	_dialogue_panel.offset_right = -120.0
	_dialogue_panel.offset_top = -240.0
	_dialogue_panel.offset_bottom = -50.0
	_dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UiFlow.register(_dialogue_panel, "ui_dialogue", 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_dialogue_panel.add_child(box)

	_dialogue_name = Label.new()
	box.add_child(_dialogue_name)

	_dialogue_text = Label.new()
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialogue_text.custom_minimum_size = Vector2(0, 80)
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_dialogue_text)

	_dialogue_hint = Label.new()
	_dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_dialogue_hint)


func _make_label(parent: Control) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
