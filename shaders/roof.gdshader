shader_type spatial;
render_mode cull_disabled;
// 지붕 재질. thatch가 0이면 기와(암기와와 수키와의 골과 단), 1이면 초가(볏짚 결).
// 지붕 메시의 UV에는 평면 좌표(x, z)가 들어 있다.

uniform vec3 base_color : source_color = vec3(0.13, 0.14, 0.16);
uniform float thatch : hint_range(0.0, 1.0) = 0.0;

global uniform float season_snow;

varying vec2 plan;
varying vec3 wn;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	plan = UV;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col;
	if (thatch < 0.5) {
		// 기와골: 약 0.35m 간격의 세로 줄과 0.3m 간격의 가로 단
		float rib = smoothstep(0.55, 1.0, abs(sin(plan.x * 18.0)));
		float row = smoothstep(0.9, 1.0, fract(plan.y * 3.3));
		float n = h21(floor(vec2(plan.x * 2.85, plan.y * 3.3)));
		col = base_color * (0.78 + 0.3 * rib) * (1.0 - 0.28 * row) * (0.85 + 0.3 * n);
		ROUGHNESS = 0.65;
	} else {
		// 볏짚: 얇은 세로 결과 가로로 두른 새끼줄 느낌의 띠
		float fiber = h21(vec2(floor(plan.x * 45.0), floor(plan.y * 2.0)));
		float band = smoothstep(0.85, 1.0, fract(plan.y * 1.4));
		col = base_color * (0.7 + 0.55 * fiber) * (1.0 - 0.25 * band);
		ROUGHNESS = 0.97;
	}
	float up = FRONT_FACING ? wn.y : -wn.y;
	col = mix(col, vec3(0.9, 0.92, 0.95), season_snow * smoothstep(0.5, 0.85, up));
	ALBEDO = col;
}
