@tool
class_name CellRig
extends Node3D
## Shared 2×2 yd cell rig — camera, lighting, ground, grid overlay.
## Open any cell prefab in the editor to tune layout with the same in-game ortho view.

const CellGroundScript := preload("res://scripts/range/cell_ground.gd")
const CELL_SIZE_YARDS := CellGroundScript.CELL_SIZE_YARDS
const CELL_HALF_YARDS := CellGroundScript.CELL_HALF_YARDS

@export_group("Camera (canonical v4 reference)")
@export var camera_size: float = V4CameraConfig.HITTING_CELL_DEFAULT_SIZE:
	set(value):
		camera_size = value
		_apply_camera()
@export var camera_position: Vector3 = V4CameraConfig.HITTING_CELL_DEFAULT_POSITION:
	set(value):
		camera_position = value
		_apply_camera()

@export_group("Ground")
@export var show_grid_overlay: bool = true:
	set(value):
		show_grid_overlay = value
		_rebuild_grid_overlay()

@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera3D
@onready var _ground: MeshInstance3D = $Ground
@onready var _grid_overlay: MeshInstance3D = $GridOverlay


func _ready() -> void:
	_setup_environment()
	_setup_ground()
	_apply_camera()
	_rebuild_grid_overlay()
	if _use_embedded_rig():
		if _camera:
			_camera.current = true
	else:
		set_embedded_rig_active(false)


func _use_embedded_rig() -> bool:
	return Engine.is_editor_hint() or is_inside_tree() and get_tree().edited_scene_root == self


func set_embedded_rig_active(active: bool) -> void:
	if _camera:
		_camera.current = active
	if _sun:
		_sun.visible = active
	if _grid_overlay:
		_grid_overlay.visible = active and show_grid_overlay
	if _world_environment:
		if active:
			var stored: Environment = _world_environment.get_meta(
				"stored_environment", null
			) as Environment
			if stored:
				_world_environment.environment = stored
		else:
			if not _world_environment.has_meta("stored_environment"):
				_world_environment.set_meta(
					"stored_environment",
					_world_environment.environment
				)
			_world_environment.environment = null


func apply_palette(light_color: Color, dark_color: Color) -> void:
	CellGroundScript.apply_to_mesh(_ground, light_color, dark_color)


func apply_ground_palette(light_color: Color, dark_color: Color) -> void:
	apply_palette(light_color, dark_color)


func _setup_environment() -> void:
	var snap := DayNightPalette.sample_at(24.0)
	if _world_environment and _world_environment.environment:
		_world_environment.environment.background_color = snap.sky
		_world_environment.environment.ambient_light_color = snap.sky.lerp(
			snap.fairway_light, 0.15
		)
	if _sun:
		_sun.light_color = DayNightPalette.SUN_COLOR
		_sun.light_energy = 1.15
		_sun.rotation_degrees = Vector3(-35.0, 35.0, 0.0)


func _setup_ground() -> void:
	if _ground == null:
		return
	var snap := DayNightPalette.sample_at(24.0)
	apply_palette(snap.fairway_light, snap.fairway_dark)


func _apply_camera() -> void:
	if _camera == null:
		return
	var pos := _camera.position if Engine.is_editor_hint() else camera_position
	V4CameraConfig.apply_locked_rotation(_camera, pos, camera_size)
	if Engine.is_editor_hint():
		camera_position = pos


func _rebuild_grid_overlay() -> void:
	if _grid_overlay == null:
		return
	if not show_grid_overlay or (not _use_embedded_rig() and not Engine.is_editor_hint()):
		_grid_overlay.mesh = null
		return
	_grid_overlay.mesh = _build_grid_overlay_mesh()
	if _grid_overlay.get_surface_override_material(0) == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_grid_overlay.set_surface_override_material(0, mat)


func _build_grid_overlay_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var line_color := Color(1.0, 1.0, 1.0, 0.55)
	var y := 0.02

	var x0 := -CELL_HALF_YARDS
	var x1 := CELL_HALF_YARDS
	var z_near := 0.0
	var z_far := -CELL_SIZE_YARDS

	_append_line(verts, colors, indices, Vector3(x0, y, z_near), Vector3(x1, y, z_near), line_color)
	_append_line(verts, colors, indices, Vector3(x1, y, z_near), Vector3(x1, y, z_far), line_color)
	_append_line(verts, colors, indices, Vector3(x1, y, z_far), Vector3(x0, y, z_far), line_color)
	_append_line(verts, colors, indices, Vector3(x0, y, z_far), Vector3(x0, y, z_near), line_color)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _append_line(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	color: Color
) -> void:
	var base := verts.size()
	verts.append(a)
	verts.append(b)
	colors.append(color)
	colors.append(color)
	indices.append(base)
	indices.append(base + 1)
