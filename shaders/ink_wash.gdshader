shader_type canvas_item;
// 한국화(수묵담채) 룩: 화면을 먹의 농담과 한지 색으로 바꾸고 윤곽선을 먹선처럼 그린다.
// F2로 켜고 끈다. 원래 화면의 색을 color_keep 만큼만 남겨 담채 느낌을 낸다.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 paper_color : source_color = vec3(0.92, 0.88, 0.76);
uniform vec3 ink_color : source_color = vec3(0.09, 0.10, 0.12);
uniform float color_keep : hint_range(0.0, 1.0) = 0.35;
uniform float edge_strength : hint_range(0.0, 2.0) = 1.0;

float lum(vec2 uv) {
	return dot(texture(screen_tex, uv).rgb, vec3(0.299, 0.587, 0.114));
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));

	float tl = lum(SCREEN_UV + vec2(-px.x, -px.y));
	float t = lum(SCREEN_UV + vec2(0.0, -px.y));
	float tr = lum(SCREEN_UV + vec2(px.x, -px.y));
	float lf = lum(SCREEN_UV + vec2(-px.x, 0.0));
	float rt = lum(SCREEN_UV + vec2(px.x, 0.0));
	float bl = lum(SCREEN_UV + vec2(-px.x, px.y));
	float b = lum(SCREEN_UV + vec2(0.0, px.y));
	float br = lum(SCREEN_UV + vec2(px.x, px.y));
	float gx = (tr + 2.0 * rt + br) - (tl + 2.0 * lf + bl);
	float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	float edge = smoothstep(0.06, 0.35, length(vec2(gx, gy)) * edge_strength);

	float grain = hash21(FRAGCOORD.xy);
	float wash = pow(1.0 - clamp(l, 0.0, 1.0), 1.3);
	vec3 tone = mix(paper_color, ink_color, wash * 0.85);
	vec3 tint = mix(tone, tone * (c * 1.6 + 0.2), color_keep);
	tint = mix(tint, ink_color, edge * 0.75);
	tint *= 0.94 + grain * 0.06;

	float vig = smoothstep(1.1, 0.35, length(SCREEN_UV - 0.5) * 1.4);
	tint = mix(paper_color * 0.8, tint, vig);

	COLOR = vec4(tint, 1.0);
}
