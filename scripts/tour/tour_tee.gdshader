shader_type spatial;
render_mode unshaded, cull_disabled;
// v8 tee rise: grassy top where the rat stands, a painted rock/soil face
// dropping away to the range below.

uniform vec3 top_a : source_color = vec3(0.37, 0.64, 0.25);
uniform vec3 top_b : source_color = vec3(0.32, 0.58, 0.22);
uniform vec3 face_a : source_color = vec3(0.55, 0.45, 0.36);
uniform vec3 face_b : source_color = vec3(0.45, 0.36, 0.30);
uniform vec3 face_dark : source_color = vec3(0.30, 0.24, 0.22);
uniform vec3 lip : source_color = vec3(0.30, 0.55, 0.22);
uniform float top_y = 8.0;
uniform float darkness = 0.0;
uniform vec3 night_tint : source_color = vec3(0.10, 0.14, 0.28);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col;
	if (world_normal.y > 0.8) {
		// Tee top: mown in a small checker, with grain.
		// Tee box: close-mown stripes, a touch lighter than the fairway.
		vec2 c = floor(world_pos.xz / 0.6);
		col = mod(c.x, 2.0) < 1.0 ? top_a : top_b;
		col = mix(col, vec3(1.0, 0.97, 0.85), 0.08);
		col *= 0.95 + 0.1 * hash(floor(world_pos.xz * 6.0));
	} else {
		float depth = top_y - world_pos.y;
		float band = floor((world_pos.y + hash(vec2(floor(world_pos.x * 0.5), 1.0)) * 0.6) / 0.9);
		col = mod(band, 2.0) < 1.0 ? face_a : face_b;
		if (hash(floor(world_pos.xz * 2.0 + world_pos.y)) > 0.93) col = face_dark;
		// Shadow toward the base; a grassy lip hangs over the top edge.
		col = mix(col, face_dark, clamp(depth / max(top_y, 1.0), 0.0, 1.0) * 0.55);
		if (depth < 0.5 + 0.35 * hash(vec2(floor(world_pos.x * 2.0), floor(world_pos.z * 2.0)))) col = lip;
	}
	if (darkness > 0.0) {
		col = mix(col, col * night_tint * 2.4, darkness * 0.75);
	}
	ALBEDO = col;
}
