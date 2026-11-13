shader_type canvas_item;
// 붓글씨 마른 획: 글자 위에 가로로 긴 갈필(마른 붓) 결을 얹어 먹이 군데군데 갈라지게 한다.
uniform float dry : hint_range(0.0, 1.0) = 0.38;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float streak = vnoise(FRAGCOORD.xy * vec2(0.035, 0.85));
	float blot = vnoise(FRAGCOORD.xy * 0.06);
	float gap = smoothstep(0.58, 0.82, streak) * (0.35 + 0.65 * blot);
	c.a *= 1.0 - dry * gap;
	COLOR = c;
}
