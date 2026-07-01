shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 sky_top_color : source_color;
uniform vec4 sky_horizon_color : source_color;
uniform float star_alpha = 0.0;

void fragment() {
	vec3 dir = normalize(VERTEX);
	float elevation = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 sky = mix(sky_horizon_color.rgb, sky_top_color.rgb, elevation);

	vec2 star_uv = vec2(atan(dir.x, dir.z) / TAU + 0.5, elevation);
	vec2 grid = star_uv * vec2(160.0, 80.0);
	vec2 cell = fract(grid) - 0.5;
	vec2 cell_id = floor(grid);
	float n = fract(sin(dot(cell_id, vec2(127.1, 311.7))) * 43758.5453);
	float point = step(0.9935, n);
	float r = length(cell);
	float star = point * (1.0 - smoothstep(0.015, 0.035, r));
	sky = mix(sky, vec3(0.94, 0.96, 1.0), star * star_alpha);

	ALBEDO = sky;
}
