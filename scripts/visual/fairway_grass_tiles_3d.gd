class_name FairwayGrassTiles3D
extends RefCounted
## Fairway ground using the light grass tile from the GRASS+ asset pack (col 0 row 0).
## Mower stripes and atlas tiling are handled in fairway_ground.gdshader.
## Apron/surround uses col 0 row 1 from the same atlas.

const ATLAS_TEXTURE := preload("res://assets/sprites/fairway/grass_plus_atlas.png")
const GROUND_SHADER := preload("res://scripts/visual/fairway_ground.gdshader")

const TILE_PX := 16.0
const ATLAS_WIDTH_PX := 400.0
const ATLAS_HEIGHT_PX := 224.0
const UV_INSET_PX := 0.5
const STRIPE_WIDTH_YARDS := 2.0
const TILE_SIZE_YARDS := 2.0
const FAIRWAY_DEPTH_YARDS := 224.0

const GRASS_TILE_COL := 0
const GRASS_TILE_ROW := 0
const DESERT_TILE_COL := 1
const DESERT_TILE_ROW := 0
const APRON_TILE_COL := 0
const APRON_TILE_ROW := 1
const DARK_STRIPE_PALETTE_BLEND := 0.45

const SURROUND_HALF_WIDTH_YARDS := 70.0
const SURROUND_DEPTH_YARDS := 340.0
const SURROUND_BLEED_MARGIN := 8.0
const SURROUND_Y := -0.01

const GROUND_MODE_FAIRWAY := 0
const GROUND_MODE_APRON := 1


static func build_plane_mesh(
	x_min: float,
	x_max: float,
	z_near: float,
	z_far: float,
	y: float = 0.0
) -> ArrayMesh:
	var width := x_max - x_min
	var depth := z_near - z_far
	var u_max := width / TILE_SIZE_YARDS
	var v_max := depth / TILE_SIZE_YARDS

	var verts := PackedVector3Array([
		Vector3(x_min, y, z_near),
		Vector3(x_max, y, z_near),
		Vector3(x_max, y, z_far),
		Vector3(x_min, y, z_far),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(u_max, 0.0),
		Vector2(u_max, v_max),
		Vector2(0.0, v_max),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_fairway_material() -> ShaderMaterial:
	return _make_shader_material(GROUND_MODE_FAIRWAY, GRASS_TILE_COL, GRASS_TILE_ROW)


static func make_bay_mat_material() -> ShaderMaterial:
	## Hitting mats always stay on the green grass tile (col 0, row 0).
	return _make_shader_material(GROUND_MODE_FAIRWAY, GRASS_TILE_COL, GRASS_TILE_ROW)


static func make_apron_material() -> ShaderMaterial:
	return _make_shader_material(GROUND_MODE_APRON, APRON_TILE_COL, APRON_TILE_ROW)


static func make_material() -> ShaderMaterial:
	return make_fairway_material()


static func uv_for_tile(col: int, row: int) -> Vector4:
	return _uv_for_tile(col, row)


static func apply_tile_uv(mesh_instance: MeshInstance3D, col: int, row: int) -> void:
	if mesh_instance == null:
		return
	var mat := _get_shader_material(mesh_instance, make_fairway_material)
	mat.set_shader_parameter(&"tile_uv_bounds", _uv_for_tile(col, row))


static func apply_palette_uniforms(
	mesh_instance: MeshInstance3D,
	light_color: Color,
	dark_color: Color
) -> void:
	if mesh_instance == null:
		return
	var mat := _get_shader_material(mesh_instance, make_fairway_material)
	mat.set_shader_parameter(&"fairway_light", light_color)
	mat.set_shader_parameter(&"fairway_dark", dark_color)


static func apply_apron_palette_uniforms(mesh_instance: MeshInstance3D, tint: Color) -> void:
	if mesh_instance == null:
		return
	var mat := _get_shader_material(mesh_instance, make_apron_material)
	mat.set_shader_parameter(&"apron_tint", tint)


static func ensure_fairway_plane(
	mesh_instance: MeshInstance3D,
	x_min: float,
	x_max: float,
	z_near: float,
	z_far: float,
	y: float = 0.0
) -> void:
	if mesh_instance == null:
		return
	if mesh_instance.mesh == null:
		mesh_instance.mesh = build_plane_mesh(x_min, x_max, z_near, z_far, y)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, make_fairway_material())


static func build_mesh(
	half_width: float,
	light_color: Color,
	dark_color: Color,
	depth_yards: float = FAIRWAY_DEPTH_YARDS
) -> ArrayMesh:
	return build_plane_mesh(-half_width, half_width, 0.0, -depth_yards)


static func apply_palette(
	mesh_instance: MeshInstance3D,
	half_width: float,
	light_color: Color,
	dark_color: Color,
	depth_yards: float = FAIRWAY_DEPTH_YARDS
) -> void:
	if mesh_instance == null:
		return
	ensure_fairway_plane(mesh_instance, -half_width, half_width, 0.0, -depth_yards)
	apply_palette_uniforms(mesh_instance, light_color, dark_color)


static func _surround_near_z(home_size: float) -> float:
	return maxf(home_size * 5.0, 40.0) + SURROUND_BLEED_MARGIN


static func build_surround_mesh(tint: Color, home_size: float) -> ArrayMesh:
	var _unused := tint
	var _unused_home := home_size
	return build_plane_mesh(
		-SURROUND_HALF_WIDTH_YARDS,
		SURROUND_HALF_WIDTH_YARDS,
		_surround_near_z(home_size),
		-SURROUND_DEPTH_YARDS,
		SURROUND_Y
	)


static func ensure_surround_mesh(mesh_instance: MeshInstance3D, home_size: float) -> void:
	if mesh_instance == null:
		return
	var z_near := _surround_near_z(home_size)
	if mesh_instance.mesh == null:
		mesh_instance.mesh = build_plane_mesh(
			-SURROUND_HALF_WIDTH_YARDS,
			SURROUND_HALF_WIDTH_YARDS,
			z_near,
			-SURROUND_DEPTH_YARDS,
			SURROUND_Y
		)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, make_apron_material())
	mesh_instance.sorting_offset = -1.0


static func apply_surround(mesh_instance: MeshInstance3D, color: Color, home_size: float) -> void:
	if mesh_instance == null:
		return
	ensure_surround_mesh(mesh_instance, home_size)
	apply_apron_palette_uniforms(mesh_instance, color)


static func apply_surround_palette_uniforms(mesh_instance: MeshInstance3D, tint: Color) -> void:
	apply_apron_palette_uniforms(mesh_instance, tint)


static func _uv_for_tile(col: int, row: int) -> Vector4:
	var px_x := float(col) * TILE_PX
	var px_y := float(row) * TILE_PX
	var u0 := maxf((px_x + UV_INSET_PX) / ATLAS_WIDTH_PX, 0.0)
	var u1 := minf((px_x + TILE_PX - UV_INSET_PX) / ATLAS_WIDTH_PX, 1.0)
	var v0 := maxf((px_y + UV_INSET_PX) / ATLAS_HEIGHT_PX, 0.0)
	var v1 := minf((px_y + TILE_PX - UV_INSET_PX) / ATLAS_HEIGHT_PX, 1.0)
	return Vector4(u0, v0, u1, v1)


static func _make_shader_material(mode: int, tile_col: int, tile_row: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter(&"ground_mode", mode)
	mat.set_shader_parameter(&"albedo_tex", ATLAS_TEXTURE)
	mat.set_shader_parameter(&"tile_size_yards", TILE_SIZE_YARDS)
	mat.set_shader_parameter(&"half_width_yards", RangeGrid.HALF_WIDTH_YARDS)
	var uv := _uv_for_tile(tile_col, tile_row)
	mat.set_shader_parameter(&"tile_uv_bounds", uv)
	return mat


static func _get_shader_material(
	mesh_instance: MeshInstance3D,
	factory: Callable
) -> ShaderMaterial:
	var mat := mesh_instance.get_surface_override_material(0)
	if mat is ShaderMaterial:
		return mat as ShaderMaterial
	var new_mat: ShaderMaterial = factory.call()
	mesh_instance.set_surface_override_material(0, new_mat)
	return new_mat
