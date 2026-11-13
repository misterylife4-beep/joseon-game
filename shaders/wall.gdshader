shader_type spatial;
render_mode cull_disabled;
// 도성 성벽 질감. 정점 색의 알파가 1이면 돌(산지 석성), 0이면 다진 흙(평지 토성).

varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = abs(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));
	float along = wpos.x * step(n.x, n.z) + wpos.z * step(n.z, n.x);
	vec2 uv = vec2(along, wpos.y);
	if (n.y > 0.7) {
		uv = wpos.xz;
	}

	vec3 stone_col;
	{
		float row = floor(uv.y / 0.55);
		float shift = h21(vec2(row, 3.0)) * 1.2;
		vec2 cell = vec2(floor((uv.x + shift) / 0.95), row);
		vec2 f = vec2(fract((uv.x + shift) / 0.95), fract(uv.y / 0.55));
		float mortar = step(f.x, 0.05) + step(f.y, 0.08);
		float tone = 0.78 + 0.4 * h21(cell);
		stone_col = vec3(0.52, 0.5, 0.46) * tone;
		stone_col = mix(stone_col, vec3(0.2, 0.19, 0.17), clamp(mortar, 0.0, 1.0));
	}

	vec3 earth_col;
	{
		float layer = floor(uv.y / 0.4);
		float f = fract(uv.y / 0.4);
		float tone = 0.85 + 0.25 * h21(vec2(layer, floor(uv.x * 0.6)));
		earth_col = COLOR.rgb * tone;
		earth_col *= 1.0 - 0.18 * step(f, 0.06);
	}

	ALBEDO = mix(earth_col, stone_col, COLOR.a);
	ROUGHNESS = 0.95;
}
