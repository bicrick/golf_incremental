shader_type canvas_item;
render_mode blend_add, unshaded;
// Additive light over the 3D range: a soft sun/moon halo and slow-turning
// god rays from where the sun sits in the painted sky. Smooth, not pixel-
// stepped: the art is pixel art, the light is air.

uniform vec2 sun = vec2(240.0, 80.0); // screen px
uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float halo = 0.35;
uniform float rays = 0.25;
uniform float breathe = 0.0; // music
uniform float t = 0.0;
uniform vec2 size = vec2(480.0, 270.0);

float hash(float n) { return fract(sin(n) * 43758.5453); }

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void fragment() {
	vec2 px = UV * size;
	vec2 d = px - sun;
	float dist = length(d) / size.y;
	float ang = atan(d.y, d.x);
	// Halo: two soft falloffs.
	float h = exp(-dist * 7.0) * 0.9 + exp(-dist * 2.2) * 0.25;
	h *= halo * (1.0 + breathe * 0.35);
	// Rays: angular noise bands that slowly turn and shimmer, fading out.
	float r = noise1(ang * 9.0 + t * 0.08) * 0.6 + noise1(ang * 23.0 - t * 0.13) * 0.4;
	r = smoothstep(0.45, 0.95, r) * exp(-dist * 1.6) * smoothstep(0.02, 0.12, dist);
	r *= rays * (0.8 + breathe * 0.5);
	vec3 c = sun_color.rgb * (h + r);
	COLOR = vec4(c, 1.0);
}
