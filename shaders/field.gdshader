shader_type spatial;
render_mode specular_disabled;
// 밭: 이랑과 고랑이 번갈아 나는 마른 땅. 겨울에는 맨흙과 서리, 여름에는 푸른 작물, 가을에는 누렇게 익는다.
// 이랑 간격 약 0.8m는 설계값이다.

uniform vec3 soil : source_color = vec3(0.36, 0.27, 0.18);
uniform vec3 crop_green : source_color = vec3(0.3, 0.46, 0.18);

global uniform float season_cold;
global uniform float season_autumn;
global uniform float season_snow;
global uniform float season_crop;

varying vec3 wp;
varying float up;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = NORMAL.y;
}

void fragment() {
	vec3 col = soil * 0.8;
	if (up > 0.5) {
		float row = abs(fract(wp.x / 0.8) - 0.5) * 2.0;      // 0 고랑 중심, 1 이랑 중심
		float ridge = smoothstep(0.2, 0.9, row);
		vec3 base = soil * (0.78 + 0.32 * ridge);
		vec3 leaf = mix(crop_green, vec3(0.72, 0.6, 0.24), clamp(season_autumn * 1.6, 0.0, 1.0));
		float cover = ridge * max(season_crop, 0.0);
		col = mix(base, leaf, cover);
		col = mix(col, vec3(0.78, 0.8, 0.84), clamp(season_cold - 0.6, 0.0, 1.0) * 0.5);
		col = mix(col, vec3(0.88, 0.9, 0.94), season_snow * 0.9);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
