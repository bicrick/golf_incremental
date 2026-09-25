shader_type canvas_item;
// Backdrop layer motion: aurora curtains that ripple, heat shimmer rising off
// hot ground, and a slow breath of light. All smooth.

uniform float t = 0.0;
uniform float ripple = 0.0;   // aurora: vertical sway, px
uniform float shimmer = 0.0;  // heat: horizontal wobble near the bottom, px
uniform float glow = 0.0;     // brightness lift
uniform vec2 size = vec2(480.0, 104.0);

void fragment() {
	vec2 uv = UV;
	uv.y += ripple * sin(UV.x * 18.0 + t * 0.7) * 0.5 / size.y + ripple * sin(UV.x * 7.0 - t * 0.4) * 0.5 / size.y;
	float low = smoothstep(0.55, 1.0, UV.y);
	uv.x += shimmer * low * sin(UV.y * 90.0 + t * 5.0) / size.x;
	vec4 c = texture(TEXTURE, uv);
	c.rgb *= 1.0 + glow;
	COLOR = c;
}
