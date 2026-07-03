class_name CellGround
extends RefCounted
## One atomic 2×2 yd grass tile — shader-tiled atlas quad, local origin at near-edge center.

const CELL_SIZE_YARDS := 2.0
const CELL_HALF_YARDS := CELL_SIZE_YARDS * 0.5


static func build_mesh(_light_color: Color) -> ArrayMesh:
	var x0 := -CELL_HALF_YARDS
	var x1 := CELL_HALF_YARDS
	return FairwayGrassTiles3D.build_plane_mesh(x0, x1, 0.0, -CELL_SIZE_YARDS)


static func apply_to_mesh(mesh_instance: MeshInstance3D, light_color: Color, dark_color: Color) -> void:
	if mesh_instance == null:
		return
	ensure_cell_mesh(mesh_instance)
	FairwayGrassTiles3D.apply_palette_uniforms(mesh_instance, light_color, dark_color)


static func ensure_cell_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	var x0 := -CELL_HALF_YARDS
	var x1 := CELL_HALF_YARDS
	FairwayGrassTiles3D.ensure_fairway_plane(mesh_instance, x0, x1, 0.0, -CELL_SIZE_YARDS)


static func build_grid_mesh(
	cols: int,
	rows: int,
	_light_color: Color,
	_dark_color: Color
) -> ArrayMesh:
	var _unused_cols := cols
	var _unused_rows := rows
	return FairwayGrassTiles3D.build_plane_mesh(
		-RangeGrid.HALF_WIDTH_YARDS,
		RangeGrid.HALF_WIDTH_YARDS,
		0.0,
		-RangeGrid.DEPTH_YARDS
	)


static func ensure_grid_mesh(mesh_instance: MeshInstance3D, cols: int, rows: int) -> void:
	if mesh_instance == null:
		return
	var _unused_cols := cols
	var _unused_rows := rows
	FairwayGrassTiles3D.ensure_fairway_plane(
		mesh_instance,
		-RangeGrid.HALF_WIDTH_YARDS,
		RangeGrid.HALF_WIDTH_YARDS,
		0.0,
		-RangeGrid.DEPTH_YARDS
	)


static func apply_grid_to_mesh(
	mesh_instance: MeshInstance3D,
	cols: int,
	rows: int,
	light_color: Color,
	dark_color: Color
) -> void:
	if mesh_instance == null:
		return
	ensure_grid_mesh(mesh_instance, cols, rows)
	FairwayGrassTiles3D.apply_palette_uniforms(mesh_instance, light_color, dark_color)


static func apply_palette_uniforms(
	mesh_instance: MeshInstance3D,
	light_color: Color,
	dark_color: Color
) -> void:
	FairwayGrassTiles3D.apply_palette_uniforms(mesh_instance, light_color, dark_color)
