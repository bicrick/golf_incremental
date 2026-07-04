shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 fairway_light : source_color = vec4(1.0);
uniform vec4 fairway_dark : source_color = vec4(0.85);
uniform vec4 apron_tint : source_color = vec4(1.0);
uniform vec4 tile_uv_bounds;
uniform float tile_size_yards = 2.0;
uniform float half_width_yards = 25.0;
uniform int ground_mode = 0;
/// Discard live fairway geometry past this world Z so the painted backdrop takes over.
uniform float ground_far_clip_z = -1000.0;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (world_vertex.z < ground_far_clip_z) {
		discard;
	}

	vec2 local_uv = fract(UV);
	vec2 atlas_uv = mix(tile_uv_bounds.xy, tile_uv_bounds.zw, local_uv);
	vec4 tex = texture(albedo_tex, atlas_uv);

	vec4 tint;
	if (ground_mode == 0) {
		// Mower stripes parallel to -Z: alternate tint by column (world X).
		int col = int(floor((world_vertex.x + half_width_yards) / tile_size_yards));
		float use_dark = float(col & 1);
		tint = mix(fairway_light, fairway_dark, use_dark);
	} else {
		tint = apron_tint;
	}

	ALBEDO = tex.rgb * tint.rgb;
	ROUGHNESS = 0.95;
}
