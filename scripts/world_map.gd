class_name WorldMap
extends CanvasLayer
## M 키로 여는 조선 지도. 열려 있는 동안 플레이어 입력을 잠그고 마우스를 보이게 한다.
## Tab으로 조선 전도와 지역도를 바꾼다.

var _player: Player
## 도착 알림을 띄울 화면 (main 이 넣는다)
var hud: SurvivalHud
var _canvas: MapCanvas
var _open := false
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _dim: ColorRect
var _tween: Tween
static var _spread_shader: Shader

## 지도를 열 때의 붓 연출. 큰 붓이 화면을 지그재그로 네 번 쓸고 지나가며 짙은 먹을 남기고,
## 그 먹이 종이 결을 따라 번져 나가 한지 바탕의 지도가 드러난다. (설계값: 붓 굵기·번지는 거리·시간)
##  - 붓 한 획: 자라나는 선분까지의 거리장(둥근 붓머리). 획마다 굵기가 조금씩 다르다.
##  - 붓머리 끝은 비백(마른 붓 자국)처럼 가로로 갈라진다.
##  - 번짐: 획 둘레가 값 잡음으로 일그러지며 넓어지고, 번지는 끝에 먹이 고인 테두리가 생긴다.
const SPREAD_CODE := """
shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec2 aspect = vec2(1.78, 1.0);
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){ return n(p) * 0.55 + n(p * 2.1 + 7.3) * 0.3 + n(p * 4.7 + 1.9) * 0.15; }
void fragment(){
	vec4 c = texture(TEXTURE, UV);
	vec2 p = vec2(UV.x * aspect.x, UV.y);
	float W = aspect.x;
	float bleed = smoothstep(0.2, 0.95, reveal);
	float dmin = 9.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float prog = clamp((reveal - fi * 0.085) / 0.3, 0.0, 1.0);
		prog = mix(prog, prog * prog * (3.0 - 2.0 * prog), 0.5);
		float y0 = 0.10 + fi * 0.27;
		float dirx = mod(fi, 2.0) < 0.5 ? 1.0 : -1.0;
		vec2 a = vec2(dirx > 0.0 ? -0.12 : W + 0.12, y0 + 0.07 * dirx);
		vec2 b = vec2(dirx > 0.0 ? W + 0.12 : -0.12, y0 - 0.07 * dirx);
		vec2 ab = b - a;
		float L = length(ab);
		vec2 dir = ab / L;
		float s = dot(p - a, dir);
		vec2 q = a + dir * clamp(s, 0.0, L * prog);
		float sn = clamp(s / L, 0.0, 1.0);
		float wid = mix(1.0, 0.8, sn) * (0.85 + 0.3 * n(vec2(sn * 6.0, fi * 3.1)));
		float d = length(p - q) / wid;
		float perp = dot(p - a, vec2(-dir.y, dir.x));
		float headzone = smoothstep(L * prog - 0.35, L * prog, s) * step(0.001, prog);
		float streak = n(vec2(perp * 70.0, fi * 5.0 + sn * 2.0));
		d += headzone * (1.0 - streak) * 0.10;
		dmin = min(dmin, d);
	}
	float warp = (fbm(p * 9.0) - 0.5) * 0.10 + (n(p * 40.0) - 0.5) * 0.025;
	float dd = dmin + warp * (0.4 + bleed);
	float R = 0.10 + bleed * 0.55;
	float a = 1.0 - smoothstep(R - 0.025, R + 0.01, dd);
	a = max(a, smoothstep(0.93, 1.0, reveal));
	float core = 1.0 - smoothstep(0.03, 0.11, dd);
	float rim = smoothstep(R - 0.10, R - 0.02, dd) * (1.0 - smoothstep(R - 0.02, R + 0.01, dd));
	float ink_amt = max(core * (1.0 - smoothstep(0.30, 0.80, reveal)) * 0.94, rim * 0.5 * (1.0 - smoothstep(0.75, 1.0, reveal)));
	vec3 ink = mix(vec3(0.08, 0.07, 0.07), vec3(0.15, 0.14, 0.16), n(p * 30.0));
	COLOR = vec4(mix(c.rgb, ink, ink_amt), c.a * a);
}
"""


func setup(player: Player) -> void:
	_player = player
	_canvas.player = player


func _ready() -> void:
	layer = 15
	visible = false
	var dim := ColorRect.new()
	_dim = dim
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_canvas = MapCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.offset_left = 56.0
	_canvas.offset_top = 36.0
	_canvas.offset_right = -56.0
	_canvas.offset_bottom = -36.0
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gate_picked.connect(_on_gate_picked)
	_canvas.place_picked.connect(_on_place_picked)
	_canvas.set_process(false)
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or _player == null:
		return
	if key.keycode == KEY_M:
		if _open:
			_set_open(false)
		elif not _player.input_locked:
			_set_open(true)
		get_viewport().set_input_as_handled()
	elif _open and key.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif _open and key.keycode == KEY_TAB:
		_canvas.mode = MapCanvas.Mode.LOCAL if _canvas.mode == MapCanvas.Mode.NATION else MapCanvas.Mode.NATION
		get_viewport().set_input_as_handled()


func _set_open(on: bool) -> void:
	_open = on
	_canvas.set_process(on)
	_player.input_locked = on
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if on:
		get_tree().call_group("side_panel", "close_panel", self)
		visible = true
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_canvas.queue_redraw()
		_play_spread()
	else:
		visible = false
		_canvas.material = null
		_dim.modulate.a = 1.0
		UiSfx.play(self, "page", -12.0)
		Input.mouse_mode = _prev_mouse


func _play_spread() -> void:
	if _spread_shader == null:
		_spread_shader = Shader.new()
		_spread_shader.code = SPREAD_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _spread_shader
	var sz := get_viewport().get_visible_rect().size - Vector2(112.0, 72.0)
	mat.set_shader_parameter("aspect", Vector2(sz.x / sz.y, 1.0))
	mat.set_shader_parameter("reveal", 0.0)
	_canvas.material = mat
	_dim.modulate.a = 0.0
	var total := 1.7
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.45)
	_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("reveal", v), 0.0, 1.0, total)
	# 붓이 지나가는 네 번의 소리 (획마다 높낮이를 달리)
	var pitches := [1.0, 0.9, 1.08, 0.95]
	for i in 4:
		_tween.tween_callback(func() -> void: UiSfx.play(self, "brush", -7.0, pitches[i])).set_delay(float(i) * 0.085 * total)
	_tween.tween_callback(func() -> void: UiSfx.play(self, "paper", -14.0)).set_delay(0.45 * total)
	_tween.chain().tween_callback(func() -> void:
		_canvas.material = null
		UiSfx.play(self, "stamp", -14.0))


## 발견한 거점을 눌러 그 자리로 바로 이동한다.
func _on_place_picked(id: String) -> void:
	if _player == null:
		return
	var pl := Discovery.place(id)
	if pl.is_empty():
		return
	var dest := pl["dest"] as Vector2
	var pos := Vector3(dest.x, HanyangMap.height(dest.x, dest.y) + 1.0, dest.y)
	_set_open(false)
	if _player.riding != null:
		_player.riding.leave_to(pos)
	_player.swimming = false
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player._yaw = float(pl["yaw"])
	_player.water_recent = 6.0  # 나루터에 내려도 나룻배가 저절로 건너지 않게
	if hud != null:
		hud.toast("%s에 도착했다." % String(pl["name"]), 3.0, "pluck_up")


## 한양 성문을 눌러 그 문 안쪽으로 바로 이동한다 (도성 중심 방향으로 9 m 들어간 자리).
func _on_gate_picked(gate_name: String, pos: Vector2) -> void:
	if _player == null:
		return
	var inward := (-pos).normalized()
	var dest := pos + inward * 9.0
	_set_open(false)
	_player.global_position = Vector3(dest.x, HanyangMap.height(dest.x, dest.y) + 1.0, dest.y)
	_player.velocity = Vector3.ZERO
	_player._yaw = atan2(-inward.x, -inward.y)
