@tool
extends "res://scripts/range/bay_cell.gd"

const DIVIDER_LIFT := 0.02


func _refresh_editor_preview() -> void:
	super._refresh_editor_preview()
	_setup_side_dividers()


func _setup_sprites() -> void:
	var golfer := get_node_or_null("Golfer") as AnimatedSprite3D
	if golfer:
		golfer.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
		_strip_empty_default_animation(golfer.sprite_frames)
		_configure_billboard(golfer, GOLFER_PIXEL_SIZE)
		golfer.offset = RangeRatSpriteFrames.FOOT_OFFSET
		if Engine.is_editor_hint():
			golfer.animation = &"idle"
			golfer.frame = 0
	var ball := get_node_or_null("Ball") as AnimatedSprite3D
	if ball:
		ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
		_strip_empty_default_animation(ball.sprite_frames)
		_configure_billboard(ball, BALL_PIXEL_SIZE)
		if Engine.is_editor_hint():
			ball.animation = &"idle"
			ball.frame = 0


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
