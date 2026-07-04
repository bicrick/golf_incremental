shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
/// UV.y at and below the painted grass band — forced opaque to hide horizon sky slits.
uniform float grass_uv_min : hint_range(0.0, 1.0) = 0.52;

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	if (UV.y >= grass_uv_min) {
		tex.a = 1.0;
	}
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
