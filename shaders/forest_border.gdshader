shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform int atlas_cols = 1;
uniform int atlas_rows = 1;
uniform bool billboard_y = false;

varying vec2 atlas_uv;

void vertex() {
	int cols = max(atlas_cols, 1);
	int rows = max(atlas_rows, 1);
	int tile_count = cols * rows;
	int tile = clamp(int(floor(INSTANCE_CUSTOM.x * float(tile_count) + 0.001)), 0, tile_count - 1);
	float col = float(tile % cols);
	float row = float(tile / cols);
	float u_scale = 1.0 / float(cols);
	float v_scale = 1.0 / float(rows);
	atlas_uv = vec2(col * u_scale, row * v_scale) + UV * vec2(u_scale, v_scale);

	if (billboard_y) {
		mat4 mv = MODELVIEW_MATRIX;
		mv[0] = vec4(normalize(vec3(mv[0].x, 0.0, mv[0].z)), 0.0);
		mv[2] = vec4(cross(mv[1].xyz, mv[0].xyz), 0.0);
		MODELVIEW_MATRIX = mv;
	}
}

void fragment() {
	vec4 tex = texture(albedo_tex, atlas_uv);
	if (tex.a * tint.a < 0.5) {
		discard;
	}
	ALBEDO = tex.rgb * tint.rgb;
	ALPHA = 1.0;
}
