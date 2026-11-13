class_name OpeningVideo
extends CanvasLayer
## 게임을 시작할 때 틀어 주는 오프닝 영상(res://video/opening.ogv, 약 10초).
## 영상이 나오는 동안 게임 세계는 멈춰 있고(소리와 시간 포함), Esc·스페이스·엔터·마우스 클릭으로 건너뛸 수 있다.
## 영상이 끝나거나 건너뛰면 까만 화면으로 부드럽게 사라지며 게임이 시작된다.
## Godot은 .mp4를 재생하지 못해 Ogg Theora(.ogv)로 바꿔 쓴다. 영상은 AI로 만든 연출이며 역사 고증 자료가 아니다.

signal finished

const PATH := "res://video/opening.ogv"
const FADE_IN := 0.8
const FADE_OUT := 0.9

var active := false
var _player: VideoStreamPlayer
var _black: ColorRect
var _cover: ColorRect
var _hint: Label
var _t := 0.0
var _ending := false
var _prev_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stream: VideoStream = null
	if ResourceLoader.exists(PATH):
		stream = load(PATH) as VideoStream
	if stream == null and FileAccess.file_exists(PATH):
		var ts := VideoStreamTheora.new()
		ts.file = PATH
		stream = ts
	if stream == null:
		queue_free()
		return
	active = true
	_prev_mouse = Input.mouse_mode
	get_tree().paused = true

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)

	var box := AspectRatioContainer.new()
	box.ratio = 16.0 / 9.0
	box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_player = VideoStreamPlayer.new()
	_player.stream = stream
	_player.expand = true
	_player.volume_db = -4.0
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_end)
	box.add_child(_player)

	# 처음에는 검은 천이 걷히며 영상이 보이고, 끝날 때는 다시 덮인다
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)

	_hint = Label.new()
	_hint.text = "Space · Esc · 클릭: 건너뛰기"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -24.0
	_hint.offset_bottom = -18.0
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.0))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_player.play()


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if not _ending:
		_cover.color.a = clampf(1.0 - _t / FADE_IN, 0.0, 1.0)
		# 건너뛰기 안내는 2초쯤부터 은은히 보인다
		var ha := clampf((_t - 2.0) / 1.0, 0.0, 1.0) * 0.8
		_hint.add_theme_color_override("font_color", Color(1, 1, 1, ha))
		_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, ha))
		# 영상이 끝나기 직전부터 검게 사라지기 시작한다
		if _player != null and _player.stream != null:
			var len := _player.get_stream_length()
			if len > 1.0 and _player.stream_position > len - FADE_OUT and _player.is_playing():
				_cover.color.a = clampf(1.0 - (len - _player.stream_position) / FADE_OUT, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if not active or _ending:
		return
	var skip := false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER):
			skip = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_end()


func _end() -> void:
	if _ending:
		return
	_ending = true
	_hint.visible = false
	if _player != null:
		var vol := _player.volume_db
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_parallel(true)
		tw.tween_property(_cover, "color:a", 1.0, FADE_OUT * 0.6)
		tw.tween_property(_player, "volume_db", -60.0, FADE_OUT * 0.6).from(vol)
		tw.chain().tween_callback(_finish)
	else:
		_finish()


func _finish() -> void:
	if _player != null:
		_player.stop()
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse
	active = false
	finished.emit()
	queue_free()
