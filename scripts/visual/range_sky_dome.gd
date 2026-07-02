@tool
class_name RangeSkyDome
extends Node3D
## Camera-following sky dome — gradient sky shader, pixel sun/moon billboards, star field.
## @tool: builds its dome mesh/celestials in the editor too, so it's visible
## in the 3D viewport instead of empty until Play mode runs _ready().

const DOME_RADIUS := 500.0
const CELESTIAL_DISTANCE := 480.0
const SUN_PIXEL_SIZE := 0.28
const MOON_PIXEL_SIZE := 0.26
const SKY_SHADER := preload("res://shaders/range_sky_dome.gdshader")
const SUN_TEXTURE := preload("res://assets/sprites/sky/sun.png")
const MOON_TEXTURE := preload("res://assets/sprites/sky/moon.png")

var _follow_camera: Camera3D
var _shader_mat: ShaderMaterial
var _sun: Sprite3D
var _moon: Sprite3D
var _star_alpha: float = 0.0


func setup(camera: Camera3D) -> void:
	_follow_camera = camera


func get_star_alpha() -> float:
	return _star_alpha


func get_sun_alpha() -> float:
	return _sun.modulate.a if _sun else 0.0


func _ready() -> void:
	_build_dome()
	_build_celestials()


func _process(_delta: float) -> void:
	if _follow_camera:
		global_position = _follow_camera.global_position


func update_atmosphere(cycle_time: float, snap: DayNightPalette.AtmosphereSnapshot) -> void:
	if _shader_mat:
		var horizon := snap.sky.lightened(0.12)
		var zenith := snap.sky.darkened(0.08)
		_shader_mat.set_shader_parameter(&"sky_horizon_color", horizon)
		_shader_mat.set_shader_parameter(&"sky_top_color", zenith)
		_star_alpha = DayNightPalette.star_visibility(cycle_time)
		_shader_mat.set_shader_parameter(&"star_alpha", _star_alpha)

	_update_celestial(_sun, cycle_time, false, DayNightPalette.SUN_COLOR)
	_update_celestial(_moon, cycle_time, true, DayNightPalette.MOON_COLOR)


func _build_dome() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = DOME_RADIUS
	sphere.height = DOME_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = SKY_SHADER
	_shader_mat.set_shader_parameter(&"star_alpha", 0.0)
	_shader_mat.set_shader_parameter(&"sky_horizon_color", DayNightPalette.SKY_DAY.lightened(0.12))
	_shader_mat.set_shader_parameter(&"sky_top_color", DayNightPalette.SKY_DAY.darkened(0.08))
	_shader_mat.render_priority = -128

	var dome := MeshInstance3D.new()
	dome.name = &"DomeMesh"
	dome.mesh = sphere
	dome.material_override = _shader_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


func _build_celestials() -> void:
	_sun = _make_celestial_sprite(&"Sun", SUN_TEXTURE, SUN_PIXEL_SIZE)
	_moon = _make_celestial_sprite(&"Moon", MOON_TEXTURE, MOON_PIXEL_SIZE)
	add_child(_sun)
	add_child(_moon)


func _make_celestial_sprite(node_name: StringName, texture: Texture2D, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _update_celestial(sprite: Sprite3D, cycle_time: float, is_moon: bool, tint: Color) -> void:
	if sprite == null:
		return
	var direction := _celestial_direction(cycle_time, is_moon)
	sprite.position = direction * CELESTIAL_DISTANCE
	var alpha := DayNightPalette.celestial_alpha(cycle_time, is_moon)
	sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)
	sprite.visible = alpha > 0.01


## Arc spans camera left horizon → zenith → right horizon so sun/moon cross the frame.
func _celestial_direction(cycle_time: float, is_moon: bool) -> Vector3:
	var angle := DayNightPalette.celestial_angle(cycle_time, is_moon)
	if _follow_camera == null:
		return DayNightPalette.celestial_direction_3d(cycle_time, is_moon)
	var right := _follow_camera.global_transform.basis.x.normalized()
	var up := Vector3.UP
	return (right * -cos(angle) + up * sin(angle)).normalized()
