shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// 절차적 지형 질감: 높이와 경사에 따라 풀, 숲 바닥, 흙, 바위를 섞고
// 세 가지 크기의 노이즈로 색에 변화를 준다. 한양 도성 안쪽 평지는 맨흙 바닥으로 칠한다.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 grass_color : source_color = vec3(0.30, 0.34, 0.14);
uniform vec3 forest_color : source_color = vec3(0.14, 0.22, 0.09);
uniform vec3 dirt_color : source_color = vec3(0.38, 0.29, 0.19);
uniform vec3 rock_color : source_color = vec3(0.33, 0.30, 0.27);
uniform vec2 city_axes = vec2(230.0, 170.0);
uniform float height_ref = 38.0;

global uniform float season_cold;
global uniform float season_autumn;
global uniform float season_snow;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n_large = texture(noise_tex, world_pos.xz * 0.004).r;
	float n_mid = texture(noise_tex, world_pos.xz * 0.03).r;
	float n_fine = texture(noise_tex, world_pos.xz * 0.25).r;

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float h = world_pos.y / height_ref;
	float city_r = length(world_pos.xz / city_axes);

	// 풀 → 숲 바닥 (높을수록, 노이즈가 높을수록 숲)
	vec3 col = mix(grass_color, forest_color, smoothstep(0.05, 0.55, h + (n_large - 0.5) * 0.5));

	// 맨땅 얼룩
	col = mix(col, dirt_color, smoothstep(0.62, 0.85, n_mid) * 0.45);

	// 도성 안쪽 흙마당
	float yard = 1.0 - smoothstep(0.3, 0.85, city_r);
	col = mix(col, dirt_color, clamp(yard * (0.75 + n_mid * 0.25), 0.0, 1.0));

	// 경사진 곳은 바위
	col = mix(col, rock_color, smoothstep(0.16, 0.36, slope + (n_mid - 0.5) * 0.12));

	// 높은 산등성이는 허연 화강암이 드러난다 (백악산·인왕산이 특히 그렇다)
	vec3 granite = vec3(0.58, 0.56, 0.52) * mix(0.88, 1.1, n_fine);
	float expose = smoothstep(0.55, 0.8, h + (n_mid - 0.5) * 0.3) * smoothstep(0.06, 0.18, slope);
	col = mix(col, granite, expose * 0.85);

	// 한강 물가: 젖은 모래와 개흙
	float shore = 1.0 - smoothstep(-8.0, -6.6, world_pos.y);
	float wet = 1.0 - smoothstep(-9.2, -8.4, world_pos.y);
	col = mix(col, vec3(0.5, 0.43, 0.3), shore * step(1.0, world_pos.z / 150.0));
	col = mix(col, vec3(0.22, 0.2, 0.15), wet * step(1.0, world_pos.z / 150.0));

	// 잔 무늬
	col *= mix(0.78, 1.18, n_mid) * mix(0.9, 1.1, n_fine);

	// 계절: 겨울엔 풀이 마르고, 가을엔 누래지며, 눈이 평평한 곳을 덮는다
	col = mix(col, vec3(0.42, 0.37, 0.25) * mix(0.9, 1.1, n_mid), season_cold * 0.7 * (1.0 - expose));
	col = mix(col, vec3(0.5, 0.34, 0.13) * mix(0.9, 1.1, n_mid), season_autumn * 0.5 * (1.0 - expose));
	float snow_m = season_snow * smoothstep(0.55, 0.9, world_normal.y) * (0.75 + 0.25 * n_mid);
	col = mix(col, vec3(0.88, 0.9, 0.94), snow_m);

	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.08;
}
