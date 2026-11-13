shader_type canvas_item;
// 짐승에게 맞았을 때 화면 가장자리가 붉게 번쩍이고, 발톱 자국이 그어진다. 몸이 약해지면 가장자리가 숨쉬듯 붉어진다.
uniform float hurt = 0.0;
uniform float slash = 0.0;
uniform float fade = 0.0;
uniform float low = 0.0;
uniform float t = 0.0;

float claw(vec2 uv, vec2 origin, float reveal) {
	vec2 dir = normalize(vec2(0.55, 1.0));
	vec2 nor = vec2(dir.y, -dir.x);
	vec2 p = uv - origin;
	float along = dot(p, dir);
	float d = abs(dot(p, nor));
	float len = 0.95;
	float w = 0.02 * (1.0 - clamp(along / len, 0.0, 1.0)) + 0.002;
	float body = 1.0 - smoothstep(w * 0.6, w, d);
	float cut = step(0.0, along) * (1.0 - step(len * reveal, along));
	return body * cut;
}

void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.22, 0.85, length(c * vec2(1.25, 1.0)));
	float a = v * (hurt * 0.9 + low * (0.30 + 0.16 * sin(t * 6.5)));
	float s = 0.0;
	s += claw(UV, vec2(0.28, -0.05), slash);
	s += claw(UV, vec2(0.42, -0.02), clamp(slash * 1.1 - 0.05, 0.0, 1.0));
	s += claw(UV, vec2(0.56, -0.06), clamp(slash * 1.2 - 0.1, 0.0, 1.0));
	s *= (1.0 - fade);
	vec3 col = mix(vec3(0.45, 0.0, 0.0), vec3(0.18, 0.0, 0.0), clamp(s, 0.0, 1.0));
	COLOR = vec4(col, clamp(a + s * 0.9, 0.0, 1.0));
}
