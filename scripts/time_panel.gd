class_name TimePanel
extends CanvasLayer
## 시각과 계절을 직접 정하는 패널. T 키로 열고 닫는다. 열면 마우스 커서가 나타난다.
## 시각 슬라이더는 하루 안의 시각(0~24시), 월 선택은 음력 월(계절)을 바꾼다. 게임 진행(공사 일수)은 그대로다.

const MONTH_LABELS := [
	"정월 (한겨울)", "2월 (이른 봄)", "3월 (봄 · 꽃)", "4월 (늦봄)", "5월 (초여름)", "6월 (한여름)",
	"7월 (여름)", "8월 (초가을)", "9월 (가을 · 단풍)", "10월 (늦가을)", "11월 (초겨울)", "12월 (겨울)",
]

var _dn: DayNight
var _panel: PanelContainer
var _btn: ClockButton
var _hour_slider: HSlider
var _hour_label: Label
var _month_opt: OptionButton
var _freeze: CheckBox
var _date_label: Label
var _normal_len := 240.0
var _syncing := false
var _seen_version := -1


func setup(dn: DayNight) -> void:
	_dn = dn
	_normal_len = dn.day_length_sec
	layer = 20
	_build_ui()
	_set_open(false)


func _build_ui() -> void:
	add_to_group("side_panel")
	_btn = ClockButton.new()
	_btn.pressed.connect(func() -> void: _set_open(not _panel.visible))
	add_child(_btn)
	UiFlow.register(_btn, "ui_btn", 1)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -330.0
	_panel.offset_top = 40.0
	_panel.offset_right = -12.0
	add_child(_panel)
	_panel.add_to_group("ui_avoid_right")
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "시간 · 계절  (T 로 닫기)"
	box.add_child(title)

	_date_label = Label.new()
	box.add_child(_date_label)

	var hrow := HBoxContainer.new()
	box.add_child(hrow)
	var hl := Label.new()
	hl.text = "시각"
	hrow.add_child(hl)
	_hour_label = Label.new()
	_hour_label.custom_minimum_size = Vector2(110, 0)
	_hour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hrow.add_child(_hour_label)
	_hour_slider = HSlider.new()
	_hour_slider.min_value = 0.0
	_hour_slider.max_value = 23.99
	_hour_slider.step = 0.1
	_hour_slider.focus_mode = Control.FOCUS_NONE
	_hour_slider.value_changed.connect(_on_hour)
	box.add_child(_hour_slider)

	var quick := HBoxContainer.new()
	box.add_child(quick)
	for q in [["새벽", 5.0], ["낮", 12.0], ["해질녘", 18.0], ["한밤", 0.5]]:
		var b := Button.new()
		b.text = q[0]
		b.focus_mode = Control.FOCUS_NONE
		var hv: float = q[1]
		b.pressed.connect(func() -> void: _set_hour(hv))
		quick.add_child(b)

	var ml := Label.new()
	ml.text = "계절 (음력 월)"
	box.add_child(ml)
	_month_opt = OptionButton.new()
	_month_opt.focus_mode = Control.FOCUS_NONE
	for m in MONTH_LABELS:
		_month_opt.add_item(m)
	_month_opt.item_selected.connect(_on_month)
	box.add_child(_month_opt)

	_freeze = CheckBox.new()
	_freeze.text = "시간 멈춤"
	_freeze.focus_mode = Control.FOCUS_NONE
	_freeze.toggled.connect(_on_freeze)
	box.add_child(_freeze)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()


func close_panel(except: Node) -> void:
	if except != self and _panel.visible:
		_panel.visible = false
		_btn.open = false
		_btn.queue_redraw()


func _set_open(on: bool) -> void:
	if on:
		get_tree().call_group("side_panel", "close_panel", self)
	_panel.visible = on
	_btn.open = on
	_btn.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if _seen_version != UiPrefs.version:
		_seen_version = UiPrefs.version
		_panel.theme = JoseonUI.make_theme()
	if _dn == null or not _panel.visible:
		return
	_syncing = true
	_hour_slider.value = _dn.hour
	_hour_label.text = "%s  %02d:%02d" % [JoseonUI.sijin_short(_dn.hour), int(_dn.hour), int((_dn.hour - floorf(_dn.hour)) * 60.0)]
	var m := clampi(int(floorf(Season.month_f)) - 1, 0, 11)
	if _month_opt.selected != m:
		_month_opt.select(m)
	_date_label.text = Season.date_text()
	_syncing = false


func _set_hour(h: float) -> void:
	_dn.hour = h


func _on_hour(v: float) -> void:
	if _syncing:
		return
	_set_hour(v)


## 고른 달의 한가운데(15일 무렵)가 되도록 날짜를 옮긴다.
func _on_month(idx: int) -> void:
	var target := float(idx) * Season.MONTH_LEN + 14.0
	var base := Season.START_DOY + float(_dn.day - 1) * Season.DAYS_PER_GAME_DAY + _dn.hour / 24.0
	Season.debug_shift = target - base


func _on_freeze(on: bool) -> void:
	_dn.day_length_sec = 1.0e9 if on else _normal_len


## 화면 오른쪽의 시간 단추: 열두 시진을 둘러 새긴 둥근 시반(時盤)과 지금 시각을 가리키는 붉은 바늘.
## 시반은 자(子)가 위, 오(午)가 아래이고 밤 시간(유시~묘시)은 어둡게 칠했다. 모양과 색은 설계값이다.
## 하루를 열두 시진(十二支)으로 나눈 것은 사료다.
class ClockButton extends Control:
	signal pressed

	const LW := 84.0
	const LH := 100.0

	var open := false
	var _hover := false
	var _acc := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "시간·계절 설정 (T)"
		mouse_entered.connect(func() -> void:
			_hover = true
			UiSfx.play(self, "tick", -28.0)
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

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
		_acc += delta
		if _acc > 0.25:
			_acc = 0.0
			queue_redraw()

	## 시각(0~24)을 위(자시)에서 시계 방향으로 잰 각도
	static func _ang(h: float) -> float:
		return h / 24.0 * TAU - PI * 0.5

	func _draw() -> void:
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5) * 0.74  # 단추 줄여 쓰기
		JoseonUI.button_plate(self, size, _hover, open)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var c := Vector2(42.0, 44.0)
		var r := 28.0
		var ink := JoseonUI.INK
		# 시반 바탕과 밤 부분
		draw_circle(c, r, JoseonUI.PAPER_LIGHT)
		var night := PackedVector2Array([c])
		for i in 33:
			var h := 19.0 + 10.0 * float(i) / 32.0  # 유시(19시)~묘시(5시)
			night.append(c + Vector2.from_angle(_ang(h)) * (r - 1.0))
		draw_colored_polygon(night, Color(0.18, 0.2, 0.32, 0.3))
		draw_arc(c, r, 0.0, TAU, 40, ink, 2.0, true)
		draw_arc(c, r - 5.0, 0.0, TAU, 40, JoseonUI.INK_SOFT, 1.0, true)
		# 열두 시진 경계 눈금: 자시는 23시~1시 가운데가 위
		for i in 12:
			var a := _ang(float(i) * 2.0 - 1.0)
			draw_line(c + Vector2.from_angle(a) * (r - 5.0), c + Vector2.from_angle(a) * (r - 1.0), ink, 1.2, true)
		# 子·卯·午·酉 네 글자
		var f := JoseonUI.title_font()
		for q in 4:
			var ch: String = JoseonUI.SIJIN_HANJA[q * 3]
			var a2 := _ang(float(q * 6))
			var tp := c + Vector2.from_angle(a2) * (r - 11.0)
			var tw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(f, tp + Vector2(-tw * 0.5, 4.5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
		# 지금 시각을 가리키는 바늘
		var ha := _ang(DayNight.hour_now)
		var tip := c + Vector2.from_angle(ha) * (r - 6.0)
		draw_line(c - Vector2.from_angle(ha) * 4.0, tip, JoseonUI.SEAL, 2.6, true)
		draw_circle(tip, 2.4, JoseonUI.SEAL)
		draw_circle(c, 3.2, ink)
		draw_circle(c, 1.2, JoseonUI.PAPER_LIGHT)
		# 이름과 단축키
		var cap := "시간  T"
		var cw := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		JoseonUI.text_bold(self, Vector2((LW - cw) * 0.5, LH - 12.0), cap, 18, ink, JoseonUI.PAPER)
