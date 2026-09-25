shader_type canvas_item;
render_mode unshaded;
// Final air over everything but the UI: a soft vignette and a gentle colour
// grade toward the range's time of day.

uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.9, 1.0);
uniform float tint_amount = 0.08;
uniform float vignette = 0.35;
uniform vec4 vignette_color : source_color = vec4(0.08, 0.05, 0.12, 1.0);

void fragment() {
	vec2 q = UV - 0.5;
	q.x *= 1.3;
	float v = smoothstep(0.35, 0.85, length(q)) * vignette;
	// Premultiplied-looking: darken edges, lay a thin tint wash on top.
	COLOR = vec4(mix(tint.rgb, vignette_color.rgb, v / max(v + tint_amount, 0.0001)), max(v, tint_amount));
}
