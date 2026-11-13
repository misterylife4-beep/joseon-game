shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// 사람 모델 재질. 정점 색의 알파가 1이면 천(삼베·무명의 올과 결, 주름 그늘, 거친 옹이),
// 0이면 피부·나무·가죽처럼 매끈한 면으로 그린다. 색은 정점 색에 구워 두었다.

varying vec3 lp;
varying vec3 vcol;
varying float vcloth;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
	vcol = COLOR.rgb;
	vcloth = COLOR.a;
	// 옷자락·소매 끝 흔들림: 뼈대 아래쪽(밑단·소맷부리)일수록 바람에 살랑인다. 진폭은 설계값.
	if (COLOR.a > 0.5) {
		float hang = clamp(-VERTEX.y - 0.18, 0.0, 0.6);
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float ph = TIME * 1.7 + wp.x * 0.9 + wp.z * 0.7;
		VERTEX.x += hang * 0.045 * sin(ph);
		VERTEX.z += hang * 0.045 * sin(ph * 0.8 + 1.7);
	}
}

void fragment() {
	vec3 col = pow(vcol, vec3(2.2)); // 정점 색은 보이는 색(sRGB)으로 적어 두었다
	if (vcloth > 0.5) {
		// 올: 가로세로로 엇갈린 잔 무늬
		float warp = 0.5 + 0.5 * sin(lp.x * 230.0 + lp.z * 60.0) * sin(lp.y * 230.0);
		float weft = 0.5 + 0.5 * sin(lp.z * 230.0 + lp.x * 60.0) * sin(lp.y * 230.0 + 1.3);
		float weave = mix(warp, weft, 0.5);
		// 주름 그늘: 몸통을 도는 세로 주름
		float fold = 0.5 + 0.5 * sin(atan(lp.z, lp.x) * 9.0 + lp.y * 2.5);
		// 삼베의 거친 옹이
		float nub = step(0.93, h21(floor(vec2(lp.x + lp.z * 1.7, lp.y) * 80.0)));
		// 염색 얼룩
		float patch = h21(floor(vec2(lp.x + lp.z, lp.y) * 14.0));
		col *= mix(0.9, 1.06, weave);
		col *= mix(0.92, 1.05, fold);
		col *= mix(0.95, 1.04, patch);
		col += vec3(0.05) * nub;
		ROUGHNESS = 1.0;
		SPECULAR = 0.04;
	} else {
		col *= 0.97 + 0.06 * h21(floor(lp.xy * 140.0));
		ROUGHNESS = 0.68;
		SPECULAR = 0.3;
		RIM = 0.25;
		RIM_TINT = 0.6;
	}
	ALBEDO = col;
}
