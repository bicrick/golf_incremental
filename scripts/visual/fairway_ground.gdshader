shader_type spatial;
// Unshaded like the painted backdrop — sun must not wash out stripe tints.
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 fairway_light : source_color = vec4(1.0);
uniform vec4 fairway_dark : source_color = vec4(0.85);
uniform vec4 tile_uv_bounds;
uniform float tile_size_yards = 2.0;
uniform float half_width_yards = 25.0;

varying vec3 world_vertex;

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

	ALBEDO = tex.rgb * tint.rgb;
	ROUGHNESS = 0.95;
}
