shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// 개천 물. UV.x는 가로 방향 0~1, UV.y는 흐름 방향으로 8m마다 1씩 늘어난다.
// 잔물결 두 겹이 천천히 흐르고, 가장자리는 투명하게 풀어진다.

uniform vec3 deep_color : source_color = vec3(0.12, 0.22, 0.24);
uniform vec3 shallow_color : source_color = vec3(0.26, 0.4, 0.38);
uniform float flow_speed = 0.25;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = vec2(UV.x * 6.0, UV.y * 6.0 - TIME * flow_speed * 6.0);
	float r1 = vnoise(uv * 1.7);
	float r2 = vnoise(uv * 3.9 + vec2(5.0, TIME * 0.4));
	float ripple = r1 * 0.6 + r2 * 0.4;
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	vec3 col = mix(shallow_color, deep_color, edge);
	col += vec3(0.1) * smoothstep(0.7, 0.9, ripple);
	ALBEDO = col;
	ALPHA = mix(0.2, 0.82, edge);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	NORMAL = normalize(NORMAL + vec3((ripple - 0.5) * 0.3, 0.0, (r2 - 0.5) * 0.3));
}
