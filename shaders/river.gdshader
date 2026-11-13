shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// 한강 물. 가장자리는 깊이 차이로 투명하게 풀리고 얕은 곳에 거품이 인다.
// 달빛이 물결에 부서지도록 거칠기를 낮췄다. 색과 속도는 설계값.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 deep_color : source_color = vec3(0.05, 0.14, 0.2);
uniform vec3 shallow_color : source_color = vec3(0.2, 0.38, 0.42);
uniform float flow_speed = 0.05;

global uniform float season_cold;

varying vec3 world_pos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.08 + vec2(-TIME * flow_speed, 0.0);
	float r1 = vnoise(uv * 1.7);
	float r2 = vnoise(uv * 4.3 + vec2(TIME * 0.12, 3.0));
	float ripple = r1 * 0.6 + r2 * 0.4;

	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float diff = max(-view.z + VERTEX.z, 0.0);

	float deep = smoothstep(0.1, 3.0, diff);
	vec3 col = mix(shallow_color, deep_color, deep);
	float foam = (1.0 - smoothstep(0.0, 0.5, diff)) * smoothstep(0.35, 0.7, ripple);
	col = mix(col, vec3(0.8), foam * 0.6);
	// 겨울에는 가장자리에 살얼음이 낀다
	col = mix(col, vec3(0.78, 0.85, 0.88), smoothstep(0.6, 1.0, season_cold) * (1.0 - deep) * 0.8);
	ALBEDO = col;
	ALPHA = clamp(smoothstep(0.0, 0.35, diff) * (0.42 + 0.46 * deep), 0.0, 0.88);
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	NORMAL = normalize(NORMAL + vec3((ripple - 0.5) * 0.45, 0.0, (r2 - 0.5) * 0.45));
}
