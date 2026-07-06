@tool
class_name RangeSkyDome
extends Node3D
## Camera-following sky dome — gradient sky, shader-painted sun/moon, star field.
## @tool: builds dome mesh in the editor so sky is visible without Play mode.

## Large enough that the sphere's lower surface crosses the ground plane far
## beyond the 300 yd range (a 500 yd dome centered on the elevated ortho camera
## used to slice through the ground at ~Z -240, painting sky over the fairway's
## final yards). Still well inside the default 4000 camera far plane.
const DOME_RADIUS := 1500.0
## ~10° apparent diameter (5° half-angle).
const SUN_ANGULAR_SIZE := deg_to_rad(5.0)
const MOON_ANGULAR_SIZE := deg_to_rad(4.5)
const SKY_SHADER := preload("res://shaders/range_sky_dome.gdshader")
const SUN_TEXTURE := preload("res://assets/sprites/sky/sun.png")
const MOON_TEXTURE := preload("res://assets/sprites/sky/moon.png")

var _follow_camera: Camera3D
var _shader_mat: ShaderMaterial
var _star_alpha: float = 0.0
var _sun_alpha: float = 0.0
var _sun_world_position: Vector3 = Vector3.ZERO


func setup(camera: Camera3D) -> void:
	_follow_camera = camera


func get_star_alpha() -> float:
	return _star_alpha


func get_sun_alpha() -> float:
	return _sun_alpha


func get_sun_world_position() -> Vector3:
	return _sun_world_position


func _ready() -> void:
	_build_dome()


func _process(_delta: float) -> void:
	if _follow_camera:
		global_position = _follow_camera.global_position


func update_atmosphere(cycle_time: float, snap: DayNightPalette.AtmosphereSnapshot) -> void:
	if _shader_mat == null:
		return

	var horizon := snap.sky.lightened(0.12)
	var zenith := snap.sky.darkened(0.08)
	_shader_mat.set_shader_parameter(&"sky_horizon_color", horizon)
	_shader_mat.set_shader_parameter(&"sky_top_color", zenith)
	_star_alpha = DayNightPalette.star_visibility(cycle_time)
	_shader_mat.set_shader_parameter(&"star_alpha", _star_alpha)

	var viewer := global_position
	if _follow_camera:
		viewer = _follow_camera.global_position

	var sun_dir := DayNightPalette.celestial_view_direction(cycle_time, false, viewer)
	_sun_world_position = viewer + sun_dir * (DOME_RADIUS - 20.0)
	_sun_alpha = DayNightPalette.celestial_alpha(cycle_time, false)
	var moon_alpha := DayNightPalette.celestial_alpha(cycle_time, true)

	_shader_mat.set_shader_parameter(&"sun_direction", sun_dir)
	_shader_mat.set_shader_parameter(&"sun_color", DayNightPalette.SUN_COLOR)
	_shader_mat.set_shader_parameter(&"sun_alpha", _sun_alpha)
	_shader_mat.set_shader_parameter(&"sun_angular_size", SUN_ANGULAR_SIZE)
	_shader_mat.set_shader_parameter(&"sun_texture", SUN_TEXTURE)

	_shader_mat.set_shader_parameter(
		&"moon_direction",
		DayNightPalette.celestial_view_direction(cycle_time, true, viewer)
	)
	_shader_mat.set_shader_parameter(&"moon_color", DayNightPalette.MOON_COLOR)
	_shader_mat.set_shader_parameter(&"moon_alpha", moon_alpha)
	_shader_mat.set_shader_parameter(&"moon_angular_size", MOON_ANGULAR_SIZE)
	_shader_mat.set_shader_parameter(&"moon_texture", MOON_TEXTURE)


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
	_shader_mat.set_shader_parameter(&"sun_texture", SUN_TEXTURE)
	_shader_mat.set_shader_parameter(&"moon_texture", MOON_TEXTURE)
	_shader_mat.set_shader_parameter(&"sun_angular_size", SUN_ANGULAR_SIZE)
	_shader_mat.set_shader_parameter(&"moon_angular_size", MOON_ANGULAR_SIZE)
	_shader_mat.render_priority = -128

	var dome := MeshInstance3D.new()
	dome.name = &"DomeMesh"
	dome.mesh = sphere
	dome.material_override = _shader_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
