class_name UiFx
extends RefCounted
## UI 연출: 먹이 번지며 나타나는 효과(셰이더)와 붓·종이 소리(절차 합성).
## 값(시간, 음량)은 설계값이다. 소리는 파일 없이 코드로 만든 잡음이라 실제 붓·종이 소리와는 다르다.

const INK_SHADER := """
shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec4 c = COLOR;  // 글자색·판 질감은 이미 들어 있다. 덮어쓰면 글자가 하얗게 나온다
	float m = n(FRAGCOORD.xy * 0.045) * 0.6 + n(FRAGCOORD.xy * 0.12) * 0.4;
	float edge = reveal * 1.5 - m;
	float a = clamp(edge * 4.0, 0.0, 1.0);
	// 번지는 가장자리는 조금 어둡게
	float rim = clamp(1.0 - abs(edge - 0.12) * 8.0, 0.0, 1.0) * 0.18;
	c.rgb *= 1.0 - rim;
	c.a *= a;
	COLOR = c;
}
"""

static var _shader: Shader = null
static var _wavs: Dictionary = {}


## 먹이 번지며 나타난다. 이미 쓰고 있던 머티리얼이 없을 때만 입힌다.
static func ink_in(c: Control, seconds := 0.7) -> void:
	if c == null or not c.is_inside_tree():
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = INK_SHADER
	var mat := c.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = _shader
		c.material = mat
	mat.set_shader_parameter("reveal", 0.0)
	var tw := c.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("reveal", v), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## kind: "brush"(붓이 스치는 소리), "paper"(종이 넘기는 소리), "stamp"(도장 찍는 소리)
static func play(owner: Node, kind: String, volume_db := -14.0) -> void:
	UiSfx.play(owner, kind, volume_db)


static func _wav(kind: String) -> AudioStreamWAV:
	if _wavs.has(kind):
		return _wavs[kind]
	var rate := 22050
	var dur := 0.3
	match kind:
		"brush":
			dur = 0.38
		"paper":
			dur = 0.30
		"stamp":
			dur = 0.22
	var n := int(float(rate) * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777 + kind.length()
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / float(n)
		var x := rng.randf() * 2.0 - 1.0
		var v := 0.0
		match kind:
			"brush":
				# 붓이 스치는 소리: 서서히 커졌다 줄어드는 거친 잡음, 높은 소리가 점점 줄어든다
				var a := lerpf(0.55, 0.12, t)
				lp += a * (x - lp)
				var env := sin(t * PI)
				v = (x - lp) * 0.35 * env + lp * 0.5 * env
			"paper":
				# 종이 넘김: 짧은 부스럭 잡음 여러 번
				var burst := 0.35 + 0.65 * maxf(0.0, sin(t * 38.0 + sin(t * 11.0) * 2.0))
				lp += 0.7 * (x - lp)
				v = lp * burst * (1.0 - t) * 0.6
			_:
				# 도장: 둔탁한 낮은 울림
				lp += 0.06 * (x - lp)
				lp2 += 0.15 * (sin(float(i) * 0.045) - lp2)
				v = (lp * 1.4 + lp2 * 0.9) * exp(-t * 9.0)
		var s := int(clampf(v, -1.0, 1.0) * 30000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_wavs[kind] = w
	return w
