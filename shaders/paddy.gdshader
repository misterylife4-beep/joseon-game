shader_type spatial;
// 논: 물 댄 바닥에 모가 줄지어 서 있다. 세로줄 간격 약 0.3m는 설계값.

uniform vec3 water_col : source_color = vec3(0.25, 0.3, 0.26);
uniform vec3 seedling : source_color = vec3(0.32, 0.46, 0.16);

global uniform float season_cold;
global uniform float season_autumn;
global uniform float season_snow;
global uniform float season_crop;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = wp.xz / 0.32;
	vec2 f = fract(g) - 0.5;
	float tuft = 1.0 - smoothstep(0.1, 0.32, length(f));
	// 모는 봄에 심어 여름에 자라고 가을에 누렇게 익으며, 겨울 논은 벤 그루터기와 얼음뿐이다.
	tuft *= max(season_crop, 0.0);
	vec3 crop_col = mix(seedling, vec3(0.7, 0.58, 0.2), clamp(season_autumn * 1.6, 0.0, 1.0));
	vec3 bare = mix(water_col, vec3(0.42, 0.36, 0.26), clamp(season_cold * 1.3, 0.0, 1.0));
	vec3 col = mix(bare, crop_col, tuft);
	col = mix(col, vec3(0.88, 0.9, 0.94), season_snow * 0.9);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.08, 0.9, season_cold), 0.8, tuft);
	SPECULAR = 0.6;
}
