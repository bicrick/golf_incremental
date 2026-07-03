@tool
extends Node3D
## v4 reference rig — canonical orthographic camera angle and atomic hitting-cell layout.
## Open `scenes/range/hitting_cell.tscn` in the editor to tune camera and sprites.
## Not instanced into main.tscn; `range_view.tscn`'s Camera3D is synced from this rig.

const BALL_PIXEL_SIZE := 0.021
const GOLFER_PIXEL_SIZE := 0.024
const CELL_SIZE_YARDS := 2.0
const CELL_HALF_YARDS := CELL_SIZE_YARDS * 0.5
## One atomic cell: 2×2 yd, centered on X=0, near edge at Z=0, depth toward -Z.

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
@onready var _golfer: AnimatedSprite3D = $Golfer
@onready var _ball: AnimatedSprite3D = $Ball
@onready var _tee_marker: MeshInstance3D = $TeeMarker


func _ready() -> void:
	_setup_environment()
	_setup_ground()
	_setup_sprites()
	_apply_camera()
	_rebuild_grid_overlay()
	if _camera:
		_camera.current = true


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
	_ground.mesh = _build_reference_ground_mesh(snap.fairway_light, snap.fairway_dark)
	if _ground.get_surface_override_material(0) == null:
		_ground.set_surface_override_material(0, FairwayGrassTiles3D.make_material())


func _build_reference_ground_mesh(light_color: Color, _dark_color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var x0 := -CELL_HALF_YARDS
	var x1 := CELL_HALF_YARDS
	var z_near := 0.0
	var z_far := -CELL_SIZE_YARDS
	_append_grass_quad(verts, colors, uvs, indices, x0, x1, z_near, z_far, light_color)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_grass_quad(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	x0: float,
	x1: float,
	z_near: float,
	z_far: float,
	tint: Color
) -> void:
	var uv := FairwayGrassTiles3D._uv_for_tile(
		FairwayGrassTiles3D.GRASS_TILE_COL,
		FairwayGrassTiles3D.GRASS_TILE_ROW
	)
	var base := verts.size()
	verts.append(Vector3(x0, 0.0, z_near))
	verts.append(Vector3(x1, 0.0, z_near))
	verts.append(Vector3(x1, 0.0, z_far))
	verts.append(Vector3(x0, 0.0, z_far))
	for _c in 4:
		colors.append(tint)
	uvs.append(Vector2(uv.x, uv.y))
	uvs.append(Vector2(uv.z, uv.y))
	uvs.append(Vector2(uv.z, uv.w))
	uvs.append(Vector2(uv.x, uv.w))
	indices.append_array(PackedInt32Array([
		base, base + 1, base + 2,
		base, base + 2, base + 3,
	]))


func _setup_sprites() -> void:
	if _golfer:
		_golfer.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
		_configure_billboard(_golfer, GOLFER_PIXEL_SIZE)
		_golfer.offset = RangeRatSpriteFrames.FOOT_OFFSET
		_golfer.animation = &"idle"
		_golfer.frame = 0
		if not Engine.is_editor_hint():
			_golfer.play(&"idle")
	if _ball:
		_ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
		_configure_billboard(_ball, BALL_PIXEL_SIZE)
		_ball.animation = &"idle"
		_ball.frame = 0
		if not Engine.is_editor_hint():
			_ball.play(&"idle")


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _apply_camera() -> void:
	if _camera == null:
		return
	# In editor, keep the Camera3D node's position (e.g. after Align Transform With View).
	# Rotation is always forced to the project-locked basis; only position/size are tunable.
	var pos := _camera.position if Engine.is_editor_hint() else camera_position
	V4CameraConfig.apply_locked_rotation(_camera, pos, camera_size)
	if Engine.is_editor_hint():
		camera_position = pos


func _rebuild_grid_overlay() -> void:
	if _grid_overlay == null:
		return
	if not show_grid_overlay:
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

	# Single cell border (4 edges).
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


## Relative layout from cell origin (tee) — used by docs and future HittingBayController.
func golfer_local_offset() -> Vector3:
	return _golfer.position if _golfer else Vector3.ZERO


func ball_local_offset() -> Vector3:
	return _ball.position if _ball else Vector3.ZERO


func golfer_local_scale() -> Vector3:
	return _golfer.scale if _golfer else Vector3.ONE


func ball_local_scale() -> Vector3:
	return _ball.scale if _ball else Vector3.ONE
