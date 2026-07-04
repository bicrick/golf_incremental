shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;

uniform vec4 sky_top_color : source_color;
uniform vec4 sky_horizon_color : source_color;
uniform float star_alpha = 0.0;

uniform vec3 sun_direction = vec3(0.0, 0.5, -1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform float sun_alpha = 0.0;
uniform float sun_angular_size = 0.0873;
uniform sampler2D sun_texture : filter_nearest;

uniform vec3 moon_direction = vec3(0.0, 0.5, -1.0);
uniform vec4 moon_color : source_color = vec4(0.85, 0.88, 0.95, 1.0);
uniform float moon_alpha = 0.0;
uniform float moon_angular_size = 0.0785;
uniform sampler2D moon_texture : filter_nearest;

vec3 celestial_sample(
	vec3 dir,
	vec3 center_dir,
	float angular_size,
	sampler2D tex,
	vec4 tint,
	float alpha
) {
	if (alpha <= 0.001) {
		return vec3(0.0);
	}
	float cos_limit = cos(angular_size);
	float facing = dot(dir, center_dir);
	if (facing < cos_limit) {
		return vec3(0.0);
	}

	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), center_dir));
	if (dot(right, right) < 0.0001) {
		right = vec3(1.0, 0.0, 0.0);
	}
	vec3 up = cross(center_dir, right);
	float inv_facing = 1.0 / max(facing, 0.001);
	vec2 uv = vec2(dot(dir, right), dot(dir, up)) * inv_facing / tan(angular_size) * 0.5 + 0.5;

	float disc = smoothstep(cos_limit, 1.0, facing);
	vec3 result = tint.rgb * disc;

	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec4 texel = texture(tex, uv);
		float lum = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
		float tex_mask = max(step(0.5, texel.a), step(0.12, lum));
		result = mix(result, texel.rgb * tint.rgb, tex_mask * disc);
	}

	return result * alpha;
}

void fragment() {
	vec3 dir = normalize(VERTEX);
	float elevation = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 sky = mix(sky_horizon_color.rgb, sky_top_color.rgb, elevation);

	vec3 sun_rgb = celestial_sample(dir, normalize(sun_direction), sun_angular_size, sun_texture, sun_color, sun_alpha);
	sky = mix(sky, sun_rgb, step(0.001, length(sun_rgb)));

	vec3 moon_rgb = celestial_sample(dir, normalize(moon_direction), moon_angular_size, moon_texture, moon_color, moon_alpha);
	sky = mix(sky, moon_rgb, step(0.001, length(moon_rgb)));

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
