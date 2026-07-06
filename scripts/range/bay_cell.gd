@tool
extends Node3D
## 2×2 yd hitting bay — tune in this scene, ship at runtime.
## EditorOnly (camera, grid, lighting) exists only while editing this scene
## standalone; instanced bays and runtime loads strip it.

const CellGroundScript := preload("res://scripts/range/cell_ground.gd")
const CELL_SIZE_YARDS := CellGroundScript.CELL_SIZE_YARDS
const CELL_HALF_YARDS := CellGroundScript.CELL_HALF_YARDS
const BALL_PIXEL_SIZE := 0.021
const GOLFER_PIXEL_SIZE := 0.024
const DIVIDER_LIFT := 0.02

@export_group("Camera (editor tuning)")
@export var camera_size: float = 8.0:
	set(value):
		if is_equal_approx(camera_size, value):
			return
		camera_size = value
		_apply_camera()
@export var camera_position: Vector3 = Vector3(1.470001, 1.5166433, 2.1563973):
	set(value):
		if camera_position.is_equal_approx(value):
			return
		camera_position = value
		_apply_camera()

@export_group("Ground")
@export var show_grid_overlay: bool = true:
	set(value):
		show_grid_overlay = value
		_rebuild_grid_overlay()

@onready var _ground: MeshInstance3D = $Ground

var _golfer: AnimatedSprite3D
var _ball: AnimatedSprite3D


func _cache_sprite_nodes() -> void:
	_golfer = get_node_or_null("Golfer") as AnimatedSprite3D
	_ball = get_node_or_null("Ball") as AnimatedSprite3D


func _should_use_editor_rig() -> bool:
	if not Engine.is_editor_hint():
		return false
	var edited := get_tree().edited_scene_root
	return edited != null and edited == self


func _enter_tree() -> void:
	_cache_sprite_nodes()
	if _should_use_editor_rig():
		_refresh_editor_preview()


func _ready() -> void:
	_cache_sprite_nodes()
	_refresh_editor_preview()
	if _should_use_editor_rig():
		var cam := _get_camera()
		if cam:
			cam.current = true
	else:
		_remove_editor_rig()
		if not Engine.is_editor_hint():
			_play_idle()


func _refresh_editor_preview() -> void:
	_setup_ground()
	_setup_sprites()
	_setup_side_dividers()
	if _should_use_editor_rig():
		_setup_editor_environment()
		_apply_camera()
		_rebuild_grid_overlay()
		_rebuild_tee_marker()


func _setup_sprites() -> void:
	pass


func get_golfer() -> AnimatedSprite3D:
	return _golfer


func get_ball() -> AnimatedSprite3D:
	return _ball


func strike_home() -> Vector3:
	return _golfer.position if _golfer else Vector3.ZERO


func ball_strike_home() -> Vector3:
	return _ball.position if _ball else Vector3.ZERO


func get_base_golfer_scale() -> Vector3:
	return _golfer.scale if _golfer else Vector3.ONE


func get_base_ball_scale() -> Vector3:
	return _ball.scale if _ball else Vector3.ONE


func apply_palette(light_color: Color, dark_color: Color) -> void:
	CellGroundScript.apply_to_mesh(_ground, light_color, dark_color)


func apply_ground_palette(light_color: Color, dark_color: Color) -> void:
	apply_palette(light_color, dark_color)


func apply_sprite_tint(tint: Color) -> void:
	if _golfer:
		_golfer.modulate = tint
	if _ball:
		_ball.modulate = tint


func _get_camera() -> Camera3D:
	return get_node_or_null("EditorOnly/Camera3D") as Camera3D


func _remove_editor_rig() -> void:
	var editor_only := get_node_or_null("EditorOnly")
	if editor_only:
		editor_only.queue_free()


func _get_grid_overlay() -> MeshInstance3D:
	return get_node_or_null("EditorOnly/GridOverlay") as MeshInstance3D


func _setup_editor_environment() -> void:
	var snap := DayNightPalette.sample_at(24.0)
	var world_env := get_node_or_null("EditorOnly/WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.background_color = snap.sky
		world_env.environment.ambient_light_color = snap.sky.lerp(snap.fairway_light, 0.15)
	var sun := get_node_or_null("EditorOnly/Sun") as DirectionalLight3D
	if sun:
		sun.light_color = DayNightPalette.SUN_COLOR
		sun.light_energy = 1.15
		sun.rotation_degrees = Vector3(-35.0, 35.0, 0.0)


func _setup_ground() -> void:
	var ground := _ground if _ground else get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return
	var snap := DayNightPalette.sample_at(24.0)
	CellGroundScript.apply_to_mesh(ground, snap.fairway_light, snap.fairway_dark)


func _setup_side_dividers() -> void:
	_apply_side_divider(get_node_or_null("SideDividerLeft") as MeshInstance3D, -CELL_HALF_YARDS)
	_apply_side_divider(get_node_or_null("SideDividerRight") as MeshInstance3D, CELL_HALF_YARDS)


func _apply_side_divider(mesh_instance: MeshInstance3D, x_edge: float) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = _build_side_divider_mesh(x_edge)
	if mesh_instance.get_surface_override_material(0) == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.set_surface_override_material(0, mat)


func _build_side_divider_mesh(x_edge: float) -> ArrayMesh:
	var half := GOLFER_PIXEL_SIZE * 0.5
	var x0 := x_edge - half
	var x1 := x_edge + half
	var y0 := DIVIDER_LIFT
	var y1 := y0 + GOLFER_PIXEL_SIZE
	var z_near := 0.0
	var z_far := -CELL_SIZE_YARDS

	var verts := PackedVector3Array([
		Vector3(x0, y0, z_near),
		Vector3(x1, y0, z_near),
		Vector3(x1, y1, z_near),
		Vector3(x0, y1, z_near),
		Vector3(x0, y0, z_far),
		Vector3(x1, y0, z_far),
		Vector3(x1, y1, z_far),
		Vector3(x0, y1, z_far),
	])
	var indices := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		5, 4, 7, 5, 7, 6,
		4, 0, 3, 4, 3, 7,
		1, 5, 6, 1, 6, 2,
		3, 2, 6, 3, 6, 7,
		4, 5, 1, 4, 1, 0,
	])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _apply_camera() -> void:
	var cam := _get_camera()
	if cam == null:
		return
	var pos := cam.position if Engine.is_editor_hint() else camera_position
	V4CameraConfig.apply_locked_rotation(cam, pos, camera_size)
	if _should_use_editor_rig() and not camera_position.is_equal_approx(pos):
		camera_position = pos


func _rebuild_grid_overlay() -> void:
	var grid := _get_grid_overlay()
	if grid == null:
		return
	if not _should_use_editor_rig() or not show_grid_overlay:
		grid.mesh = null
		return
	grid.mesh = _build_grid_overlay_mesh()
	if grid.get_surface_override_material(0) == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		grid.set_surface_override_material(0, mat)


func _rebuild_tee_marker() -> void:
	var marker := get_node_or_null("EditorOnly/TeeMarker") as MeshInstance3D
	if marker == null:
		return
	if not _should_use_editor_rig():
		marker.mesh = null
		return
	marker.mesh = _build_tee_marker_mesh()
	if marker.get_surface_override_material(0) == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		marker.set_surface_override_material(0, mat)


func _build_tee_marker_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var color := Color(1.0, 0.85, 0.2, 0.9)
	var y := 0.03
	var half := 0.18
	_append_line(verts, colors, indices, Vector3(-half, y, 0.0), Vector3(half, y, 0.0), color)
	_append_line(verts, colors, indices, Vector3(0.0, y, -half), Vector3(0.0, y, half), color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


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


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _strip_empty_default_animation(frames: SpriteFrames) -> void:
	if frames == null:
		return
	if frames.has_animation(&"default") and frames.get_frame_count(&"default") == 0:
		frames.remove_animation(&"default")


func _play_idle() -> void:
	if _golfer:
		_golfer.animation = &"idle"
		_golfer.frame = 0
		_golfer.play(&"idle")
	if _ball:
		_ball.animation = &"idle"
		_ball.frame = 0
		_ball.play(&"idle")
