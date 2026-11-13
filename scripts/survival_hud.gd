class_name SurvivalHud
extends CanvasLayer
## 생존 화면. 한지 판 위에 붓으로 그은 수치 선과 상징 그림(밥그릇, 화로, 짚신, 약초, 마음의 원)을 그린다.
## 상징과 붓 선의 모양은 설계값이다. 수치가 25 아래로 내려가면 주홍으로 변하며 깜박인다.

const NAMES: Array[String] = ["허기", "체온", "기력", "건강", "마음"]

var _plate: StatPlate
var _root: Control
var _prompt: Label
var _toast: Label
var _keys: Label
var _toast_left := 0.0
var _seen_version := -1


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	_plate = StatPlate.new()
	_plate.position = Vector2(16.0, 118.0)
	root.add_child(_plate)
	UiFlow.register(_plate, "ui_left", 1)

	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_top = -126.0
	_prompt.offset_bottom = -126.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	root.add_child(_prompt)
	UiFlow.register(_prompt, "ui_prompt", 1)

	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 150.0
	_toast.offset_bottom = 150.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	root.add_child(_toast)
	UiFlow.register(_toast, "ui_toast", 1)

	_keys = Label.new()
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys.offset_left = 16.0
	_keys.offset_top = -84.0
	_keys.offset_bottom = -84.0
	_keys.text = "G 줍기 · F 모닥불 피우기 · R 먹기(불 곁에서는 죽)"
	root.add_child(_keys)
	UiFlow.register(_keys, "ui_hint", 1)
	_restyle()


func _process(delta: float) -> void:
	if _seen_version != UiPrefs.version:
		_restyle()
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
			_toast.visible = false


func _restyle() -> void:
	_seen_version = UiPrefs.version
	JoseonUI.style_toast(_prompt, 24)
	JoseonUI.style_toast(_toast, 24)
	JoseonUI.style_label(_keys, 16)
	_keys.visible = UiPrefs.hint_open
	_plate.queue_redraw()


func set_stats(values: Array[float]) -> void:
	_plate.values = values.duplicate()


func set_bag(firewood: int, grain: int) -> void:
	_plate.bag = "땔감 %d · 곡식 %d" % [firewood, grain]


func set_prompt(text: String) -> void:
	var was_hidden := not _prompt.visible
	_prompt.text = text
	_prompt.visible = text != ""
	if _prompt.visible and was_hidden:
		UiFx.ink_in(_prompt, 0.45)


## 붉은 낙관이 쾅 찍히는 연출. 알림 줄 아래에 쌓여 글자를 가리지 않는다.
func stamp(file: String) -> void:
	var t := JoseonUI.tex(JoseonUI.tname(file))
	if t == null or _root == null:
		return
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(76.0, 76.0)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.pivot_offset = Vector2(38.0, 38.0)
	r.scale = Vector2(2.6, 2.6)
	r.modulate.a = 0.0
	_root.add_child(r)
	UiFlow.register(r, "ui_toast", 2)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(r, "modulate:a", 1.0, 0.12)
	tw.tween_callback(func() -> void:
		UiSfx.play(self, "stamp", -6.0)
		if file.contains("wi"):
			UiSfx.play(self, "drum", -8.0))
	tw.tween_interval(3.0)
	tw.tween_property(r, "modulate:a", 0.0, 0.8)
	tw.tween_callback(r.queue_free)


## sfx: "auto" 는 글 내용에 맞는 소리, "none" 은 무음, 그 밖에는 UiSfx 의 소리 이름
func toast(text: String, seconds: float = 3.0, sfx := "auto") -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = seconds
	UiFx.ink_in(_toast, 0.8)
	if sfx == "auto":
		sfx = UiSfx.toast_kind(text)
	if sfx != "none":
		UiSfx.play(self, sfx, -12.0)


## 한지 판 위에 수치 다섯 줄과 소지품을 그리는 칸
class StatPlate extends Control:
	var values: Array[float] = [80.0, 85.0, 100.0, 100.0, 70.0]
	var bag := ""
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(312.0, 300.0)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	const LOGICAL := Vector2(312.0, 300.0)

	func _process(delta: float) -> void:
		_t += delta
		# 화면 크기 설정에 맞춰 판 전체를 줄이고 늘린다 (안의 배치는 그대로)
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5)
		var want := LOGICAL * k
		if custom_minimum_size != want:
			custom_minimum_size = want
			size = want
		queue_redraw()

	func _tint(v: float) -> Color:
		if v < 25.0:
			var pulse := 0.65 + 0.35 * sin(_t * 6.0)
			return Color(JoseonUI.SEAL.r, JoseonUI.SEAL.g, JoseonUI.SEAL.b, pulse)
		if v < 50.0:
			return JoseonUI.OCHRE
		return JoseonUI.INK

	func _draw() -> void:
		var f := JoseonUI.font()
		var tf := JoseonUI.title_font()
		var sc := 1.0
		var k := clampf(UiPrefs.font_scale, 0.5, 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		# 큰 판 틀은 논리 크기(312x300)로 그리고 변환으로 줄인다. 틀 질감 가장자리 크기는 그대로 40
		var plate := StyleBoxTexture.new()
		var pt := JoseonUI.tex(JoseonUI.tname("plate_l.png")) if UiPrefs.ornament else null
		if pt != null:
			plate.texture = pt
			plate.texture_margin_left = 40.0
			plate.texture_margin_right = 40.0
			plate.texture_margin_top = 40.0
			plate.texture_margin_bottom = 40.0
			plate.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
			plate.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
			plate.modulate_color = Color(1, 1, 1, UiPrefs.opacity)
			draw_style_box(plate, Rect2(Vector2.ZERO, LOGICAL))
		else:
			draw_style_box(JoseonUI.flat_plate_style(0.0), Rect2(Vector2.ZERO, LOGICAL))
		var ox := 24.0
		for i in 5:
			var v: float = values[i] if i < values.size() else 0.0
			var y := 26.0 + float(i) * 38.0
			var col := _tint(v)
			_icon(i, Vector2(ox + 30.0, y + 14.0), col)
			var nm: String = SurvivalHud.NAMES[i]
			var nfs := int(22.0 * sc)
			draw_string(tf, Vector2(ox + 54.0, y + 21.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, JoseonUI.INK)
			# 글자가 커져도 붓 선이 이름을 가리지 않게, 이름 끝에서 시작한다
			var nw := tf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
			var bx := maxf(ox + 122.0, ox + 54.0 + nw + 12.0)
			var bw := maxf(40.0, (LOGICAL.x - 44.0) - bx)
			_brush(Vector2(bx, y + 14.0), bw, v, col)
		var div := JoseonUI.tex(JoseonUI.tname("divider.png"))
		if div != null:
			draw_texture_rect(div, Rect2(Vector2(46.0, 208.0), Vector2(LOGICAL.x - 92.0, 24.0)), true, Color(1, 1, 1, 0.9))
		else:
			draw_line(Vector2(46.0, 220.0), Vector2(LOGICAL.x - 46.0, 220.0), Color(JoseonUI.INK_SOFT.r, JoseonUI.INK_SOFT.g, JoseonUI.INK_SOFT.b, 0.45), 1.2)
		_bundle(Vector2(64.0, 250.0))
		draw_string(f, Vector2(86.0, 258.0), bag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * sc), JoseonUI.INK)
		var seal_tex := JoseonUI.tex(JoseonUI.tname("seal_gil.png"))
		var bag_w := f.get_string_size(bag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * sc)).x
		if seal_tex != null and 86.0 + bag_w < LOGICAL.x - 104.0:
			draw_texture_rect(seal_tex, Rect2(Vector2(LOGICAL.x - 92.0, 234.0), Vector2(34.0, 34.0)), false)

	## 붓으로 그은 선. 붓획 질감 PNG가 있으면 그것을, 없으면 선으로 그린다.
	func _brush(p: Vector2, w: float, v: float, col: Color) -> void:
		var ratio := clampf(v / 100.0, 0.0, 1.0)
		var ttrack := JoseonUI.tex("brush_track.png")
		var tfill := JoseonUI.tex("brush_fill.png")
		if ttrack != null and tfill != null:
			var h := 24.0
			var top := p + Vector2(0.0, -h * 0.5)
			draw_texture_rect(ttrack, Rect2(top, Vector2(w, h)), false, Color(JoseonUI.INK_SOFT.r, JoseonUI.INK_SOFT.g, JoseonUI.INK_SOFT.b, 0.26))
			if ratio > 0.01:
				draw_texture_rect(tfill, Rect2(top, Vector2(maxf(w * ratio, 16.0), h)), false, col)
			return
		var track := Color(JoseonUI.INK_SOFT.r, JoseonUI.INK_SOFT.g, JoseonUI.INK_SOFT.b, 0.2)
		draw_line(p, p + Vector2(w, 0.0), track, 9.0, true)
		if ratio <= 0.01:
			return
		var x1 := p.x + w * ratio
		draw_line(p + Vector2(0.0, 0.5), Vector2(x1, p.y + 0.5), col, 8.0, true)
		draw_circle(Vector2(x1, p.y + 0.5), 4.0, col)

	## 보따리: 천을 모아 매듭지은 모양
	func _bundle(c: Vector2) -> void:
		var cloth := JoseonUI.PAPER_DARK
		var body := PackedVector2Array()
		for k in 17:
			var a := PI * float(k) / 16.0
			body.append(c + Vector2(cos(a) * 13.0, 2.0 + sin(a) * 11.0))
		draw_colored_polygon(body, cloth)
		draw_polyline(body, JoseonUI.INK, 1.6, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(0, 3), c + Vector2(5, -6), c + Vector2(0, -12)]), cloth)
		draw_polyline(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(0, -12), c + Vector2(5, -6), c + Vector2(0, 3), c + Vector2(-5, -6)]), JoseonUI.INK, 1.4, true)
		draw_line(c + Vector2(-8, 1), c + Vector2(8, 1), JoseonUI.SEAL, 2.0, true)

	func _icon(i: int, c: Vector2, col: Color) -> void:
		match i:
			0:  # 밥그릇과 고봉밥
				var rice := PackedVector2Array()
				for k in 9:
					var a := PI + PI * float(k) / 8.0
					rice.append(c + Vector2(0.0, -2.0) + Vector2(cos(a) * 8.0, sin(a) * 8.0))
				draw_colored_polygon(rice, JoseonUI.PAPER_LIGHT)
				draw_polyline(rice, JoseonUI.INK_SOFT, 1.2, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -2), c + Vector2(11, -2), c + Vector2(7, 9), c + Vector2(-7, 9)]), col)
			1:  # 화로의 불꽃
				var wob := sin(_t * 7.0) * 1.5
				draw_colored_polygon(PackedVector2Array([c + Vector2(wob, -13), c + Vector2(6, -3), c + Vector2(4, 4), c + Vector2(-4, 4), c + Vector2(-6, -3)]), col)
				draw_rect(Rect2(c + Vector2(-10, 5), Vector2(20, 5)), JoseonUI.INK)
			2:  # 짚신
				var sole := PackedVector2Array()
				for k in 14:
					var a := TAU * float(k) / 14.0
					var q := Vector2(cos(a) * 11.0, sin(a) * 5.0).rotated(-0.45)
					sole.append(c + q)
				draw_colored_polygon(sole, col)
				draw_line(c + Vector2(-2, -4), c + Vector2(3, 3), JoseonUI.INK, 1.5, true)
				draw_line(c + Vector2(2, -6), c + Vector2(7, 1), JoseonUI.INK, 1.5, true)
			3:  # 약초 잎
				draw_line(c + Vector2(0, 10), c + Vector2(0, -9), JoseonUI.INK, 2.0, true)
				var leaf := JoseonUI.PINE if col == JoseonUI.INK else col
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1), c + Vector2(-10, -7), c + Vector2(-9, 0), c + Vector2(-2, 3)]), leaf)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(10, -11), c + Vector2(9, -3), c + Vector2(2, 0)]), leaf)
			_:  # 마음: 붓으로 한 번에 그린 원
				draw_arc(c, 9.0, 0.4, TAU - 0.35, 28, col, 3.2, true)
				draw_circle(c + Vector2(1, 1), 1.6, col)
