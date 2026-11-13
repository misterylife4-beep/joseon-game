shader_type spatial;
render_mode cull_disabled, specular_disabled;
// 다져진 흙길. 가장자리는 노이즈로 풀어서 지면에 스며들게 한다. UV.x는 폭 방향 0~1.

uniform vec3 base_color : source_color = vec3(0.45, 0.36, 0.24);
uniform float edge_soft = 0.22;

varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float side = abs(UV.x * 2.0 - 1.0);
	float n = vnoise(wpos.xz * 1.6) * 0.6 + vnoise(wpos.xz * 0.35) * 0.4;
	float edge = 1.0 - smoothstep(1.0 - edge_soft, 1.0, side + (n - 0.5) * 0.25);
	ALBEDO = base_color * (0.78 + 0.4 * n);
	ROUGHNESS = 1.0;
	ALPHA = edge;
}
