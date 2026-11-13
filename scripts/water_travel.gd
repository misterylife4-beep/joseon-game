class_name WaterTravel
extends Node
## 물에서의 이동: 배 타고 내리기(E), 뛰어들기(Space), 헤엄칠 때 줄어드는 숨 게이지와 익사 피해.
## 숨이 줄고 차는 빠르기, 물에 젖은 체온 저하는 모두 설계값이다.
## 근거(고증_근거.md 35장): 한강 나루에서 평저선을 노와 삿대로 부린 것은 사료, 게임 조작은 설계값.

const BREATH_MAX := 100.0
const DRAIN_SLOW := 3.4
const DRAIN_FAST := 7.0
const REGEN_LAND := 22.0
const REGEN_BOAT := 14.0
const LOW := 30.0
const DROWN_DPS := 9.0

var breath := BREATH_MAX

var _player: Player
var _survival: Survival
var _hud: SurvivalHud
var _gauge: BreathGauge
var _prompt: Label
var _warned_low := false
var _hint_cd := 0.0
var _drown_toast_cd := 0.0
var _was_swimming := false
var _last_text := ""
var _ripple_cd := 0.0
var _splash_cd := 0.0
var _log_cd := 0.0
var _splash: AudioStreamPlayer
var _ring_mesh: TorusMesh
var _ring_mat: StandardMaterial3D


func setup(player: Player, survival: Survival, hud: SurvivalHud) -> void:
	_player = player
	_survival = survival
	_hud = hud
	for b in get_tree().get_nodes_in_group("boat"):
		var rb := b as RowBoat
		if rb != null:
			rb.blocked.connect(_on_blocked)
	_pier_test()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	JoseonUI.style_toast(_prompt, 20)
	root.add_child(_prompt)
	UiFlow.register(_prompt, "ui_prompt", 2)
	_splash = AudioStreamPlayer.new()
	_splash.stream = _make_splash()
	_splash.volume_db = -9.0
	add_child(_splash)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.34
	_ring_mesh.outer_radius = 0.4
	_ring_mesh.rings = 16
	_ring_mesh.ring_segments = 4
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.6)
	_gauge = BreathGauge.new()
	_gauge.visible = false
	root.add_child(_gauge)
	UiFlow.register(_gauge, "ui_prompt", 3)


func _on_blocked(msg: String) -> void:
	if _hud != null:
		_hud.toast(msg, 3.5)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_hint_cd = maxf(_hint_cd - delta, 0.0)
	_drown_toast_cd = maxf(_drown_toast_cd - delta, 0.0)
	_update_breath(delta)
	_update_boat(delta)
	_update_wake(delta)
	_log_cd -= delta
	if _log_cd <= 0.0 and (_player.swimming or _player.wade_depth > 0.0 or _player.riding != null):
		_log_cd = 2.0
		print("WATER pos=%s swim=%s wade=%.2f ground_depth=%.2f breath=%.0f boat=%s" % [
			str(_player.global_position), str(_player.swimming), _player.wade_depth,
			_player.water_depth(), breath, str(_player.riding != null)])


## 얕은 물을 걷거나 헤엄칠 때 발밑에 물결 고리를 띄우고 철벅 소리를 낸다.
func _update_wake(delta: float) -> void:
	_ripple_cd = maxf(_ripple_cd - delta, 0.0)
	_splash_cd = maxf(_splash_cd - delta, 0.0)
	if _player.riding != null:
		return
	var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 0.6
	if not moving:
		return
	var in_water := _player.swimming or _player.wade_depth > 0.12
	if not in_water:
		return
	if _ripple_cd <= 0.0:
		_ripple_cd = 0.45
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh
		var mat := _ring_mat.duplicate() as StandardMaterial3D
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.top_level = true
		add_child(ring)
		ring.global_position = Vector3(_player.global_position.x, HanyangMap.RIVER_LEVEL + 0.04, _player.global_position.z)
		ring.scale = Vector3(0.6, 1.0, 0.6)
		var tw := ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 1.0)
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)
		tw.chain().tween_callback(ring.queue_free)
	if _splash_cd <= 0.0:
		_splash_cd = 0.9 if _player.swimming else 0.5
		_splash.volume_db = -13.0 if _player.swimming else -9.0
		_splash.pitch_scale = randf_range(0.85, 1.15)
		_splash.play()


## 철벅이는 소리: 저역 잡음이 빠르게 사라지는 짧은 덩어리
static func _make_splash() -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * 0.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var lp := 0.0
	for i in n:
		var t := float(i) / float(rate)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.35 - 0.25 * t / 0.3)
		var env := smoothstep(0.0, 0.015, t) * exp(-t * 11.0)
		data.encode_s16(i * 2, int(clampf(lp * env * 1.6, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## 시작 직후 선착장 발판 충돌을 위에서 쏘아 확인해 로그에 남긴다(PIERTEST).
func _pier_test() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := _player.get_world_3d().direct_space_state
	for d in HanRiver.piers:
		var r: Rect2 = d["rect"]
		var c := r.get_center()
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, 5.0, c.y), Vector3(c.x, -30.0, c.y), 1)
		var h := space.intersect_ray(q)
		print("PIERTEST center=%s expected_top=%.2f hit=%s" % [str(c), float(d["top"]), str(h["position"]) if not h.is_empty() else "NONE"])


func _update_breath(delta: float) -> void:
	if _player.swimming:
		if not _was_swimming and _hint_cd <= 0.0:
			_hint_cd = 25.0
			_hud.toast("물에 뛰어들었다. 숨이 차기 전에 뭍이나 배로 돌아가자.", 4.0)
		var drain := DRAIN_FAST if _player.swim_fast else DRAIN_SLOW
		breath = maxf(breath - drain * delta, 0.0)
		_player.swim_speed_mul = 1.0 if breath > LOW else lerpf(0.45, 1.0, breath / LOW)
		if breath < LOW and not _warned_low:
			_warned_low = true
			_hud.toast("숨이 가빠온다. 어서 뭍으로 나가야 한다.", 3.0)
		if breath <= 0.0:
			_survival.hurt(DROWN_DPS * delta)
			if _drown_toast_cd <= 0.0:
				_drown_toast_cd = 5.0
				_hud.toast("물을 삼켰다. 숨이 막힌다!", 2.5)
	else:
		_player.swim_speed_mul = 1.0
		var regen := REGEN_BOAT if _player.riding != null else REGEN_LAND
		breath = minf(breath + regen * delta, BREATH_MAX)
		if breath > 70.0:
			_warned_low = false
	_was_swimming = _player.swimming
	_gauge.value = breath / BREATH_MAX
	_gauge.visible = _player.swimming or breath < BREATH_MAX - 0.5


func _nearest_boat() -> RowBoat:
	var best: RowBoat = null
	var best_d := RowBoat.BOARD_RANGE
	for b in get_tree().get_nodes_in_group("boat"):
		var rb := b as RowBoat
		if rb == null or rb.rider != null:
			continue
		var d := rb.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = rb
	return best


func _update_boat(_delta: float) -> void:
	var boat := _player.riding
	var text := ""
	if boat != null:
		var spot := boat.landing_spot()
		var can_land := spot != Vector3.INF
		text = "E 배에서 내리기 · W S 노 젓기 · A D 뱃머리 · Space 물로 뛰어들기" if can_land \
			else "W S 노 젓기 · A D 뱃머리 · 물가에 닿으면 E 로 내린다 · Space 물로 뛰어들기"
		if not _player.input_locked:
			if Input.is_action_just_pressed("interact") and can_land:
				boat.leave_to(spot)
				_hud.toast("배에서 내렸다.", 2.0)
			elif Input.is_action_just_pressed("jump"):
				var side := Vector3(cos(boat.rotation.y), 0.0, -sin(boat.rotation.y)) * 1.6
				var pos := boat.global_position + side
				boat.leave_to(Vector3(pos.x, HanyangMap.RIVER_LEVEL - 1.15, pos.z))
				_player.swimming = true
	elif not _player.input_locked:
		var nb := _nearest_boat()
		if nb != null:
			text = "E 배에 오르기"
			if Input.is_action_just_pressed("interact"):
				nb.board(_player)
				_hud.toast("배에 올랐다. W 로 노를 저어 나아간다.", 3.0)
				text = ""
	if text == "" and not _player.input_locked and (_player.swimming or _player.wade_depth > 0.3):
		if _player.ledge_ahead() != Vector3.INF:
			text = "Space 기어오르기"
	if text != _last_text:
		_last_text = text
		var was_hidden := not _prompt.visible
		_prompt.text = text
		_prompt.visible = text != ""
		if _prompt.visible and was_hidden:
			UiFx.ink_in(_prompt, 0.45)


## 숨 게이지: 한지 판 위에 붓으로 그은 가로 선. 숨이 줄면 푸른 선이 짧아지고 30 아래에서는 주홍으로 깜박인다.
class BreathGauge extends Control:
	var value := 1.0

	func _process(_d: float) -> void:
		if visible:
			custom_minimum_size = Vector2(250.0, 46.0) * UiPrefs.font_scale
			queue_redraw()

	func _draw() -> void:
		var k := UiPrefs.font_scale
		var r := Rect2(Vector2.ZERO, custom_minimum_size)
		draw_style_box(JoseonUI.plate_style(2.0), r)
		var low := value < WaterTravel.LOW / WaterTravel.BREATH_MAX
		var blink := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012) if low else 1.0
		JoseonUI.text_halo(self, Vector2(r.position.x + 22.0 * k, r.size.y * 0.5 + 7.0 * k), "숨", int(20.0 * k), JoseonUI.INK)
		var bx := r.position.x + 62.0 * k
		var bw := r.size.x - 62.0 * k - 24.0 * k
		var bar := Rect2(bx, r.size.y * 0.5 - 6.0 * k, bw, 12.0 * k)
		draw_rect(bar, Color(JoseonUI.INK_SOFT, 0.18))
		var col := Color(0.70, 0.15, 0.12, blink) if low else Color(0.20, 0.42, 0.55, 0.95)
		var fw := bw * clampf(value, 0.0, 1.0)
		if fw > 1.0:
			draw_rect(Rect2(bx, bar.position.y + 1.0, fw, bar.size.y - 2.0), col)
		draw_rect(bar, JoseonUI.INK, false, 2.0)
