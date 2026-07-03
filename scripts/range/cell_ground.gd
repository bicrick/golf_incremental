class_name CellGround
extends RefCounted
## One atomic 2×2 yd grass tile — single atlas quad, local origin at near-edge center.

const CELL_SIZE_YARDS := 2.0
const CELL_HALF_YARDS := CELL_SIZE_YARDS * 0.5


static func build_mesh(light_color: Color) -> ArrayMesh:
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


static func apply_to_mesh(mesh_instance: MeshInstance3D, light_color: Color, dark_color: Color) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = build_mesh(light_color)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, FairwayGrassTiles3D.make_material())


static func build_grid_mesh(
	cols: int,
	rows: int,
	light_color: Color,
	dark_color: Color
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for row in rows:
		for col in cols:
			var x_bounds := RangeGrid.cell_x_bounds(col)
			var z_bounds := RangeGrid.cell_z_bounds(row)
			var tint := light_color if (col + row) % 2 == 0 else dark_color
			_append_grass_quad(
				verts, colors, uvs, indices,
				x_bounds.x, x_bounds.y,
				z_bounds.x, z_bounds.y,
				tint
			)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func apply_grid_to_mesh(
	mesh_instance: MeshInstance3D,
	cols: int,
	rows: int,
	light_color: Color,
	dark_color: Color
) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = build_grid_mesh(cols, rows, light_color, dark_color)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, FairwayGrassTiles3D.make_material())


static func _append_grass_quad(
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
