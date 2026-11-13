shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// 풀포기. 가로로 교차한 판에 날 모양을 깎고, 끝으로 갈수록 바람에 흔들린다.
// UV.x는 판 가로 0~1, UV.y는 아래 0 ~ 위 1.

uniform vec3 base_color : source_color = vec3(0.14, 0.2, 0.07);
uniform vec3 tip_color : source_color = vec3(0.42, 0.45, 0.18);
uniform float sway = 0.14;
uniform float wind_speed = 1.3;

global uniform float season_cold;
global uniform float season_autumn;
global uniform float season_snow;

varying float v_phase;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = wp.x * 0.35 + wp.z * 0.27;
	v_phase = fract(sin(dot(floor(wp.xz * 3.0), vec2(12.9, 78.2))) * 43758.5);
	float w = sin(TIME * wind_speed + ph) + 0.5 * sin(TIME * 2.3 + ph * 1.7);
	float k = UV.y * UV.y;
	VERTEX.x += w * sway * k;
	VERTEX.z += w * sway * 0.5 * k;
	VERTEX.y *= 1.0 - 0.55 * season_snow;
}

void fragment() {
	// 날 모양: 위로 갈수록 좁아지는 삼각형 두세 개
	float t = UV.y;
	float x = fract(UV.x * 3.0) - 0.5;
	float width = (1.0 - t) * 0.42;
	if (abs(x) > width) {
		discard;
	}
	vec3 col = mix(base_color, tip_color, t) * (0.8 + 0.4 * v_phase);
	col = mix(col, vec3(0.38, 0.32, 0.18) * (0.8 + 0.4 * v_phase), season_cold * 0.8);
	col = mix(col, vec3(0.45, 0.3, 0.1) * (0.8 + 0.4 * v_phase), season_autumn * 0.5);
	col = mix(col, vec3(0.8, 0.82, 0.86), season_snow * 0.55);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
