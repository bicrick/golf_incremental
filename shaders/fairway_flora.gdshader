shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway_speed = 1.8;
uniform float sway_amount = 0.025;
uniform float flora_height = 1.0;

varying vec2 atlas_uv;

void vertex() {
	int species = clamp(int(floor(INSTANCE_CUSTOM.x * 4.0)), 0, 3);
	float col = float(species % 2);
	float row = float(species / 2);
	atlas_uv = vec2(col * 0.5, row * 0.5) + UV * 0.5;

	float phase = INSTANCE_CUSTOM.y * 6.2831853;
	float height_weight = clamp(VERTEX.y / flora_height, 0.0, 1.0);
	float sway = sin(TIME * sway_speed + phase) * sway_amount * height_weight;
	VERTEX.x += sway;

	// Y-axis billboard — always face the strike camera while staying upright.
	mat4 mv = MODELVIEW_MATRIX;
	mv[0] = vec4(normalize(vec3(mv[0].x, 0.0, mv[0].z)), 0.0);
	mv[2] = vec4(cross(mv[1].xyz, mv[0].xyz), 0.0);
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	vec4 tex = texture(albedo_tex, atlas_uv);
	if (tex.a * tint.a < 0.5) {
		discard;
	}

	vec3 color = tex.rgb * tint.rgb;
	// Darken the base so sprites feel rooted in the turf.
	float ground_blend = smoothstep(0.45, 1.0, UV.y);
	color = mix(color, color * vec3(0.72, 0.88, 0.68), ground_blend * 0.45);
	ALBEDO = color;
}
