shader_type spatial;
// Unshaded like the painted backdrop — sun must not wash out stripe tints.
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 fairway_light : source_color = vec4(1.0);
uniform vec4 fairway_dark : source_color = vec4(0.85);
uniform vec4 tile_uv_bounds;
uniform float tile_size_yards = 2.0;
uniform float half_width_yards = 25.0;

/// Harvest fog of war (Ground mesh only — bay mats leave fog_amount at 0).
uniform float fog_amount = 0.0;
uniform float tee_z = 0.0;
uniform float reveal_yards = 18.0;
uniform float fog_falloff_yards = 14.0;
uniform vec4 fog_color : source_color = vec4(0.78, 0.82, 0.74, 1.0);

varying vec3 world_vertex;

float _hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float _value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = _hash21(i);
	float b = _hash21(i + vec2(1.0, 0.0));
	float c = _hash21(i + vec2(0.0, 1.0));
	float d = _hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 local_uv = fract(UV);
	vec2 atlas_uv = mix(tile_uv_bounds.xy, tile_uv_bounds.zw, local_uv);
	vec4 tex = texture(albedo_tex, atlas_uv);

	// Mower stripes parallel to -Z: alternate tint by column (world X).
	int col = int(floor((world_vertex.x + half_width_yards) / tile_size_yards));
	float use_dark = float(col & 1);
	vec4 tint = mix(fairway_light, fairway_dark, use_dark);
	vec3 grass = tex.rgb * tint.rgb;

	float amount = clamp(fog_amount, 0.0, 1.0);
	if (amount > 0.001) {
		float yards_from_tee = -(world_vertex.z - tee_z);
		// Breathing edge — wobble only pushes fog farther down-range so the
		// clear pad (reveal = max_carry + 1) never shrinks toward the tee.
		float wobble = _value_noise(vec2(world_vertex.x * 0.18, TIME * 0.22)) * 1.5;
		float falloff = max(fog_falloff_yards, 0.001);
		float t = smoothstep(reveal_yards, reveal_yards + falloff, yards_from_tee - wobble);

		// Flatten stripe contrast + desaturate toward cool sage/pearl.
		float grey = dot(grass, vec3(0.299, 0.587, 0.114));
		vec3 flat_grass = mix(grass, vec3(grey), 0.55);
		vec3 misted = mix(flat_grass, fog_color.rgb, 0.72);

		// Brighter ridge in the first third of the falloff — reads as a bank, not a cut.
		float ridge = smoothstep(0.0, 0.33, t) * (1.0 - smoothstep(0.33, 0.72, t));
		vec3 ridge_col = mix(fog_color.rgb, vec3(0.92, 0.94, 0.88), 0.45);
		misted = mix(misted, ridge_col, ridge * 0.55);

		grass = mix(grass, misted, t * amount);
	}

	ALBEDO = grass;
	ROUGHNESS = 0.95;
}
