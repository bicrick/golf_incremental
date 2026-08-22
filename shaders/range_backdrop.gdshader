shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 foliage_tint : source_color = vec4(1.0);
/// UV.y at and below the painted grass band — forced opaque to hide horizon sky slits.
uniform float grass_uv_min : hint_range(0.0, 1.0) = 0.52;
uniform int sheet_cols = 4;
uniform int sheet_rows = 4;
uniform int frame_count = 16;
/// Seconds each atlas frame is held. Ping-pong so the loop never snaps.
uniform float frame_duration = 3.0;

int ping_pong_frame(float time_sec) {
	int last = max(frame_count - 1, 1);
	int cycle = last * 2;
	int step = int(floor(time_sec / max(frame_duration, 0.001)));
	int pos = step % cycle;
	if (pos < 0) {
		pos += cycle;
	}
	if (pos > last) {
		return cycle - pos;
	}
	return pos;
}

void fragment() {
	int cols = max(sheet_cols, 1);
	int rows = max(sheet_rows, 1);
	int frame_index = ping_pong_frame(TIME);
	int col = frame_index % cols;
	int row = frame_index / cols;
	vec2 frame_size = vec2(1.0 / float(cols), 1.0 / float(rows));
	vec2 origin = vec2(float(col), float(row)) * frame_size;
	vec2 tex_size = vec2(textureSize(albedo_tex, 0));
	vec2 half_texel = 0.5 / max(tex_size, vec2(1.0));
	vec2 atlas_uv = clamp(
		origin + UV * frame_size,
		origin + half_texel,
		origin + frame_size - half_texel
	);
	vec4 tex = texture(albedo_tex, atlas_uv);
	vec4 zone_tint = UV.y >= grass_uv_min ? grass_tint : foliage_tint;
	vec4 tinted = tex * zone_tint * albedo_color;
	if (UV.y >= grass_uv_min) {
		tinted.a = 1.0;
	}
	ALBEDO = tinted.rgb;
	ALPHA = tinted.a;
}
