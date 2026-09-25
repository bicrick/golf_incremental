shader_type canvas_item;
// Foreground sway: grass at the bottom and leaves at the top move with the
// music (energy) and kick on the beat (pulse). Trunks in the middle hold
// still. Offsets snap to whole pixels so the art stays crisp.

uniform float energy = 0.0;
uniform float pulse = 0.0;
uniform float t = 0.0;
uniform vec2 size = vec2(480.0, 270.0);

void fragment() {
	float grass = smoothstep(0.62, 1.0, UV.y);
	float leaves = smoothstep(0.3, 0.0, UV.y);
	float weight = max(grass, leaves * 0.6);
	float wave = sin(t * 1.3 + UV.y * 9.0 + UV.x * 3.0) * (0.6 + energy * 1.6) + pulse * 1.2;
	float px = floor(wave * weight * 2.2 + 0.5);
	vec2 uv = UV + vec2(px / size.x, 0.0);
	COLOR = texture(TEXTURE, uv);
}
