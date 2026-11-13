shader_type spatial;
// 창호(격자창): 한지색 바탕에 나무 살을 그린다. 살짝 발광해서 해질 무렵 불 켜진 창처럼 보인다.

uniform vec3 paper_color : source_color = vec3(0.9, 0.86, 0.74);
uniform vec3 wood_color : source_color = vec3(0.27, 0.17, 0.1);
uniform vec2 grid = vec2(5.0, 7.0);
uniform float line_width = 0.07;
uniform float glow = 0.18;

void fragment() {
	vec2 g = fract(UV * grid);
	float bar = step(g.x, line_width) + step(1.0 - line_width, g.x) + step(g.y, line_width) + step(1.0 - line_width, g.y);
	float border = step(UV.x, 0.04) + step(0.96, UV.x) + step(UV.y, 0.03) + step(0.97, UV.y);
	float wood = clamp(bar + border, 0.0, 1.0);
	vec3 col = mix(paper_color, wood_color, wood);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	EMISSION = paper_color * glow * (1.0 - wood);
}
