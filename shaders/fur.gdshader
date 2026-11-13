shader_type spatial;
// 짐승 털: 꼭짓점 색에 잔털 무늬(값 잡음)를 섞고, 테두리에 부드러운 빛을 더해 털 느낌을 낸다.
// stripe_mode가 0이 아니면 호랑이 줄무늬를 그린다. 줄무늬는 꼭짓점 색의 알파가 1인 곳에만 생긴다(흰 털 부위는 알파 0).
//   1 몸통·목: 등에서 옆구리로 내려오는 세로줄(끊기고 갈라진다)   2 다리: 가로줄, 아래로 갈수록 사라짐   3 꼬리: 고리 무늬
uniform float fur_scale = 34.0;
uniform float sheen = 0.32;
uniform int stripe_mode = 0;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 stripe_col = vec3(0.13, 0.075, 0.04);
varying vec3 opos;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float stripes(vec3 p) {
	if (stripe_mode == 1) {
		float wob = vnoise(p * vec3(6.0, 5.0, 4.0)) * 2.6 + sin(p.y * 8.0 + p.z * 3.0) * 0.55;
		float s = sin(p.z * 42.0 + wob * 2.0 + sign(p.x) * 1.9);
		float taper = smoothstep(-0.14, 0.26, p.y);
		float thr = mix(0.80, 0.34, taper);
		float gap = smoothstep(0.22, 0.42, vnoise(p * vec3(9.0, 12.0, 9.0) + 3.1));
		return smoothstep(thr, thr + 0.14, s) * gap * smoothstep(-0.2, -0.04, p.y);
	}
	if (stripe_mode == 2) {
		float wob = vnoise(p * vec3(8.0, 6.0, 8.0)) * 2.0;
		float s = sin(p.y * 34.0 + wob * 1.6 + sign(p.x) * 1.1);
		float gap = smoothstep(0.25, 0.45, vnoise(p * 11.0 + 7.7));
		return smoothstep(0.35, 0.5, s) * gap * smoothstep(-0.55, -0.12, p.y);
	}
	if (stripe_mode == 3) {
		float wob = vnoise(p * 10.0) * 0.8;
		float s = sin(p.z * 84.0 + wob);
		return smoothstep(0.0, 0.2, s);
	}
	return 0.0;
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	float n = vnoise(opos * fur_scale) * 0.6 + vnoise(opos * fur_scale * 2.7) * 0.4;
	vec3 col = COLOR.rgb;
	if (stripe_mode != 0) {
		float w = stripes(opos) * COLOR.a;
		col = mix(col, stripe_col, w * 0.92);
	}
	vec3 base = col * (0.72 + 0.55 * n);
	ALBEDO = mix(base, vec3(1.0), flash * 0.55);
	ROUGHNESS = 0.96;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * rim * sheen + vec3(flash) * 0.85;
}
