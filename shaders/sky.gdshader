shader_type sky;
// 낮밤 하늘: 그라디언트, 해, 달, 별, 구름.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 top_color : source_color = vec3(0.32, 0.55, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.25, 0.28, 0.22);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_offset = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}

	if (h > 0.0) {
		// 별
		if (night > 0.01) {
			vec3 cell = floor(dir * 250.0);
			float r = hash13(cell);
			float star = step(0.9965, r) * smoothstep(0.0, 0.25, h);
			col += vec3(star) * night;
		}

		// 해
		float sd = dot(dir, normalize(sun_dir));
		float disc = smoothstep(0.9990, 0.9996, sd);
		float glow = pow(max(sd, 0.0), 24.0) * 0.45;
		col += sun_color * (disc * 2.5 + glow) * (1.0 - night);

		// 달: 해와의 위치 관계에서 밝은 쪽이 저절로 정해진다(위상). 반지름은 보기 좋게 키운 값.
		vec3 w = normalize(moon_dir);
		vec3 p = dir - w * dot(dir, w);
		float R = 0.034;
		float pl = length(p);
		if (dot(dir, w) > 0.0 && pl < R) {
			vec3 nrm = (p + w * sqrt(max(R * R - pl * pl, 0.0))) / R;
			float lit = smoothstep(-0.02, 0.06, dot(nrm, normalize(sun_dir)));
			float edge = 1.0 - smoothstep(R * 0.92, R, pl);
			float tex = 0.85 + 0.15 * vnoise(p.xz * 260.0 + vec2(p.y * 130.0));
			vec3 mc = mix(vec3(0.035, 0.04, 0.06), vec3(0.9, 0.9, 0.82) * tex, lit);
			float vis = mix(0.35, 1.0, night);
			col = mix(col, mc * 1.5, edge * vis);
		}

		// 구름
		vec2 cp = dir.xz / (h + 0.25) * 1.6 + vec2(cloud_offset, cloud_offset * 0.4);
		float c = fbm(cp);
		float cl = smoothstep(1.0 - cloud_cover * 0.75, 1.0, c + 0.12);
		cl *= smoothstep(0.0, 0.12, h);
		vec3 cloud_col = mix(vec3(1.0), horizon_color * 1.1 + vec3(0.05), 0.25);
		cloud_col = mix(cloud_col, vec3(0.06, 0.07, 0.11), night * 0.9);
		col = mix(col, cloud_col, cl * 0.85);
	}

	COLOR = col;
}
