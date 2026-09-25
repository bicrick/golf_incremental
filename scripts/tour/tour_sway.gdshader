shader_type canvas_item;
// Foreground sway: grass at the bottom and leaves at the top drift gently
// with the music (energy) and lean on the beat (pulse). Trunks hold still.

uniform float energy = 0.0;
uniform float pulse = 0.0;
uniform float t = 0.0;
uniform vec2 size = vec2(480.0, 270.0);

void fragment() {
	float grass = smoothstep(0.62, 1.0, UV.y);
	float leaves = smoothstep(0.3, 0.0, UV.y);
	float weight = max(grass, leaves * 0.6);
	// Smooth, gentle drift (sub-pixel is fine: the art stays pixel art, the
	// motion doesn't have to stair-step). Tips move, bases stay planted.
	float wave = sin(t * 0.9 + UV.y * 5.0 + UV.x * 2.0) * (0.35 + energy * 0.6) + pulse * 0.35;
	float px = wave * weight * 1.1;
	vec2 uv = UV + vec2(px / size.x, 0.0);
	COLOR = texture(TEXTURE, uv);
}
