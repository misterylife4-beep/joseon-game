class_name BeastFx
extends Node
## 짐승과 맞닥뜨렸을 때의 느낌을 만드는 효과 모음.
## - 맞으면: 화면 가장자리가 붉게 번쩍이고(호랑이 발톱은 세 줄 자국), 화면이 흔들리고, 순간 느려지며(타격감), 쿵·신음 소리가 난다.
## - 노리는 짐승이 가까우면 심장 박동이 빨라지고, 체력이 낮으면 화면 가장자리가 숨쉬듯 붉어진다.
## - 걸어간 짐승은 발자국을 남긴다(사슴·멧돼지 갈라진 발굽, 늑대·호랑이 발바닥). 몇 십 초 뒤 흐려진다.
## 세기·시간·수치는 설계값이다. (고증_근거.md 47장)

const TRACK_MAX := 40
const TRACK_LIFE := 80.0

static var inst: BeastFx
static var _paw: Dictionary = {}

var _player: Player
var _sv: Survival
var _mat: ShaderMaterial
var _rect: ColorRect
var _hb_t := 0.0
var _threat := 0.0
var _scan_t := 0.0
var _tracks: Array[Decal] = []
var _track_born: Array[float] = []
var _track_i := 0
var _clock := 0.0


func setup(player: Player, sv: Survival) -> void:
	_player = player
	_sv = sv
	inst = self
	var layer := CanvasLayer.new()
	layer.layer = 24
	add_child(layer)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/hit_overlay.gdshader") as Shader
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	layer.add_child(_rect)
	BeastSfx.warm(get_tree())


func _exit_tree() -> void:
	if inst == self:
		inst = null


## 맞았다. kind: "claw"(호랑이 발톱) "bite"(늑대·호랑이 물기) "ram"(멧돼지 들이받기).
func hit(dmg: float, kind: String) -> void:
	if _mat == null:
		return
	var strong := clampf(dmg / 24.0, 0.35, 1.0)
	_mat.set_shader_parameter("hurt", strong)
	var tw := create_tween()
	tw.tween_property(_mat, "shader_parameter/hurt", 0.0, 1.0 + 0.8 * strong)
	if kind == "claw":
		_mat.set_shader_parameter("slash", 0.0)
		_mat.set_shader_parameter("fade", 0.0)
		var ts := create_tween()
		ts.tween_property(_mat, "shader_parameter/slash", 1.0, 0.22)
		ts.tween_property(_mat, "shader_parameter/fade", 1.0, 1.4)
	_player.add_shake(0.5 + 0.7 * strong)
	var stop := 0.05 + 0.08 * strong
	Engine.time_scale = 0.2
	get_tree().create_timer(stop, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)
	match kind:
		"claw":
			BeastSfx.play2d(self, "slash", -3.0)
		"ram":
			BeastSfx.play2d(self, "thud", -2.0)
		_:
			BeastSfx.play2d(self, "bite", -3.0)
	BeastSfx.play2d(self, "hurt", -6.0, randf_range(0.92, 1.05))


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_clock += delta
	_mat.set_shader_parameter("t", _clock)
	var low := 0.0
	if _sv != null:
		low = clampf((32.0 - _sv.health) / 32.0, 0.0, 1.0)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.3
		_threat = _scan_threat()
	var intensity := maxf(low * 0.7, _threat)
	_mat.set_shader_parameter("low", maxf(low, _threat * 0.35))
	_hb_t -= delta
	if intensity > 0.12 and _hb_t <= 0.0:
		_hb_t = lerpf(1.15, 0.48, intensity)
		BeastSfx.play2d(self, "heart", -22.0 + 14.0 * intensity, 0.9 + 0.2 * intensity)
	_fade_tracks()


## 노리며 다가오는 짐승이 가까울수록 1에 가깝다.
func _scan_threat() -> float:
	var best := 0.0
	var pp := _player.global_position
	for n in get_tree().get_nodes_in_group("predator"):
		var b := n as Node3D
		if b == null or not b.has_method("hunting") or not b.hunting():
			continue
		var d := b.global_position.distance_to(pp)
		best = maxf(best, clampf(1.0 - (d - 5.0) / 28.0, 0.0, 1.0))
	return best


# --- 발자국 ---

## kind: 0 사슴 1 멧돼지 2 늑대 3 호랑이. yaw 는 짐승이 향한 방향(rotation.y).
func add_track(kind: int, pos: Vector3, yaw: float) -> void:
	if _player == null or pos.distance_to(_player.global_position) > 60.0:
		return
	var d: Decal
	if _tracks.size() < TRACK_MAX:
		d = Decal.new()
		d.cull_mask = 1
		add_child(d)
		_tracks.append(d)
		_track_born.append(_clock)
		_track_i = _tracks.size() - 1
	else:
		_track_i = (_track_i + 1) % TRACK_MAX
		d = _tracks[_track_i]
		_track_born[_track_i] = _clock
	var sz: float = [0.24, 0.28, 0.32, 0.5][clampi(kind, 0, 3)]
	d.texture_albedo = _paw_tex(kind)
	d.size = Vector3(sz, 0.8, sz)
	d.position = Vector3(pos.x, pos.y + 0.1, pos.z)
	d.rotation = Vector3(0.0, yaw + PI, 0.0)
	d.modulate = Color(1, 1, 1, 1)


func _fade_tracks() -> void:
	for i in _tracks.size():
		var age := _clock - _track_born[i]
		_tracks[i].modulate.a = clampf(1.0 - age / TRACK_LIFE, 0.0, 1.0)
		_tracks[i].visible = age < TRACK_LIFE


static func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


static func _paw_tex(kind: int) -> ImageTexture:
	if _paw.has(kind):
		return _paw[kind]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.12, 0.08, 0.05, 0.75)
	match kind:
		0:
			_blob(img, 11.0, 15.0, 3.5, 8.0, c)
			_blob(img, 21.0, 15.0, 3.5, 8.0, c)
		1:
			_blob(img, 11.0, 13.0, 4.5, 7.0, c)
			_blob(img, 21.0, 13.0, 4.5, 7.0, c)
			_blob(img, 8.0, 26.0, 2.0, 2.0, c)
			_blob(img, 24.0, 26.0, 2.0, 2.0, c)
		2:
			_blob(img, 16.0, 21.0, 6.5, 5.5, c)
			for p in [Vector2(8, 11), Vector2(13, 6), Vector2(19, 6), Vector2(24, 11)]:
				_blob(img, p.x, p.y, 3.0, 3.5, c)
		_:
			_blob(img, 16.0, 21.0, 9.0, 6.5, c)
			for p in [Vector2(6, 12), Vector2(12, 6), Vector2(20, 6), Vector2(26, 12)]:
				_blob(img, p.x, p.y, 4.0, 4.5, c)
	var tex := ImageTexture.create_from_image(img)
	_paw[kind] = tex
	return tex
