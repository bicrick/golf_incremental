class_name StrikeMist
extends Node3D
## v5 — the mist bank seen from the tee. Layered translucent veils stand on the
## fairway just past the fog line (GameState.revealed_yards()), so the story's
## progress bar is visible where the player spends most of their time. Harvest
## view keeps its ground fog; these veils fade out there.

const LAYERS := [
	## [yards past the fog line, height (yd), max alpha]
	[4.0, 3.0, 0.45],
	[12.0, 5.5, 0.62],
	[26.0, 9.0, 0.78],
	[48.0, 14.0, 0.9],
]
const WIDTH_YARDS := 110.0
const FADE_SEC := 0.6

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 mist_color : source_color = vec4(0.84, 0.87, 0.82, 1.0);
uniform float alpha_max = 0.6;
uniform float seed = 0.0;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = h21(i); float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0)); float d = h21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
void fragment() {
	// UV.y: 0 top, 1 bottom. Dense at the ground, soft wispy top edge.
	float up = 1.0 - UV.y;
	float n = vnoise(vec2(UV.x * 9.0 + TIME * 0.05 + seed, up * 2.0 + seed))
		+ 0.5 * vnoise(vec2(UV.x * 23.0 - TIME * 0.08 + seed * 3.0, up * 5.0));
	float edge = smoothstep(1.0, 0.25 + n * 0.35, up);
	float sides = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	// Chunky alpha steps so it reads as pixel-art mist, not a smooth gradient.
	float a = floor(edge * sides * 6.0) / 6.0;
	ALBEDO = mist_color.rgb;
	ALPHA = a * alpha_max;
}
"""

var _veils: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _tee_z := 0.0
var _amount := 0.0
var _color := Color(0.84, 0.87, 0.82, 1.0)


func setup(tee_z: float) -> void:
	_tee_z = tee_z
	name = "StrikeMist"
	var shader := Shader.new()
	shader.code = SHADER_CODE
	for i in LAYERS.size():
		var layer: Array = LAYERS[i]
		var quad := QuadMesh.new()
		quad.size = Vector2(WIDTH_YARDS, float(layer[1]))
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"alpha_max", float(layer[2]))
		mat.set_shader_parameter(&"seed", float(i) * 7.3)
		mat.render_priority = 1
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_veils.append(mi)
		_mats.append(mat)


func set_mist_color(c: Color) -> void:
	_color = c.lerp(Color(0.95, 0.96, 0.92), 0.25)


## `strike_view` true while the tee camera is active.
func update(delta: float, strike_view: bool) -> void:
	var want := 1.0 if strike_view and not GameState.story_complete else 0.0
	_amount = move_toward(_amount, want, delta / FADE_SEC)
	visible = _amount > 0.01
	if not visible:
		return
	var reveal := GameState.revealed_yards()
	for i in _veils.size():
		var layer: Array = LAYERS[i]
		var yards := reveal + float(layer[0])
		var h := float(layer[1])
		_veils[i].position = Vector3(0.0, h * 0.5 - 0.05, _tee_z - yards)
		## Past the far edge of the range there's nothing to hide.
		_veils[i].visible = yards < RangeGrid.DEPTH_YARDS + 40.0
		var c := _color
		c.a = 1.0
		_mats[i].set_shader_parameter(&"mist_color", c)
		_mats[i].set_shader_parameter(&"alpha_max", float(layer[2]) * _amount)
