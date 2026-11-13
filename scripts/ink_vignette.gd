class_name InkVignette
extends CanvasLayer
## 위험한 곳(범이 나는 산길)에 들어서면 화면 가장자리에 먹이 번져 어두워진다.
## 위험 단계 0~4에 따라 짙기가 부드럽게 바뀐다. 짙기 값은 설계값이다.

const SHADER := """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float t = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 q = (UV - 0.5) * vec2(1.15, 1.0);
	float r = length(q) * 1.55;
	float nz = n(UV * 5.0 + vec2(t * 0.05, -t * 0.03)) * 0.6 + n(UV * 13.0 - vec2(t * 0.04, 0.0)) * 0.4;
	float edge = smoothstep(0.62, 1.12, r + (nz - 0.5) * 0.45);
	COLOR = vec4(0.03, 0.025, 0.02, edge * strength);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _level := 0.0
var _target := 0.0
var _t := 0.0
var _pulse := 0.0
var _zone_target := 0.0
var _ambient := 0.0


func _ready() -> void:
	layer = 4
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)


## 위험 단계(0~4)
func set_danger(level: int) -> void:
	_zone_target = [0.0, 0.0, 0.22, 0.42, 0.62][clampi(level, 0, 4)]
	_target = maxf(_zone_target, _ambient)


## 저녁 산길의 으스스한 분위기 (0~1 -> 가장자리 짙기)
func set_ambient(v: float) -> void:
	_ambient = clampf(v, 0.0, 0.5)
	_target = maxf(_zone_target, _ambient)


## 범이 가까울 때 잠깐 더 짙어지게 (0~1)
func set_pulse(v: float) -> void:
	_pulse = clampf(v, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_level = move_toward(_level, _target, delta * 0.25)
	var extra := _pulse * 0.25 * (0.6 + 0.4 * sin(_t * 5.0))
	_mat.set_shader_parameter("strength", clampf(_level + extra, 0.0, 0.9))
	_mat.set_shader_parameter("t", _t)
