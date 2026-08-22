shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 foliage_tint : source_color = vec4(1.0);
/// UV.y at and below the painted grass band — forced opaque to hide horizon sky slits.
uniform float grass_uv_min : hint_range(0.0, 1.0) = 0.52;

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	vec4 zone_tint = UV.y >= grass_uv_min ? grass_tint : foliage_tint;
	vec4 tinted = tex * zone_tint * albedo_color;
	if (UV.y >= grass_uv_min) {
		tinted.a = 1.0;
	}
	ALBEDO = tinted.rgb;
	ALPHA = tinted.a;
}
