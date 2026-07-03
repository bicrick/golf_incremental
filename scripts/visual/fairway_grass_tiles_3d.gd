class_name FairwayGrassTiles3D
extends RefCounted
## Fairway ground using the light grass tile from the GRASS+ asset pack (col 0 row 0).
## Mower stripes reuse the same atlas tile; dark stripes are a subtle vertex tint.

const ATLAS_TEXTURE := preload("res://assets/sprites/fairway/grass_plus_atlas.png")

const TILE_PX := 16.0
const ATLAS_WIDTH_PX := 400.0
const ATLAS_HEIGHT_PX := 224.0
## Inward inset keeps UVs off atlas tile borders (col 1 is orange/yellow at x=16).
const UV_INSET_PX := 0.5
const STRIPE_WIDTH_YARDS := 2.0
const TILE_SIZE_YARDS := 2.0  ## One 16×16 atlas tile per 2×2 yard world patch.
const FAIRWAY_DEPTH_YARDS := 224.0

## Column 0 row 0 — Rect2(0, 0, 16, 16). Both stripes sample this tile.
const GRASS_TILE_COL := 0
const GRASS_TILE_ROW := 0
## Blend toward palette fairway_dark (~85% brightness vs light); keeps day/night response.
const DARK_STRIPE_PALETTE_BLEND := 0.45
## Flat surround under the striped fairway — fills ortho camera bleed past grid edges.
const SURROUND_HALF_WIDTH_YARDS := 70.0
const SURROUND_DEPTH_YARDS := 340.0
const SURROUND_NEAR_Z := 16.0
const SURROUND_Y := -0.01


static func build_mesh(
	half_width: float,
	light_color: Color,
	dark_color: Color,
	depth_yards: float = FAIRWAY_DEPTH_YARDS
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var z_near := 0.0
	var z_far := -depth_yards
	var stripe_count := ceili(half_width * 2.0 / STRIPE_WIDTH_YARDS)

	for i in stripe_count:
		var x0 := -half_width + float(i) * STRIPE_WIDTH_YARDS
		var x1 := minf(x0 + STRIPE_WIDTH_YARDS, half_width)
		var use_light := i % 2 == 0
		var tint := light_color if use_light else light_color.lerp(dark_color, DARK_STRIPE_PALETTE_BLEND)
		var z0 := z_near
		while z0 > z_far:
			var z1 := maxf(z0 - TILE_SIZE_YARDS, z_far)
			_append_stripe_quad(
				verts, colors, uvs, indices, x0, x1, z0, z1, tint, GRASS_TILE_COL, GRASS_TILE_ROW
			)
			z0 = z1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ATLAS_TEXTURE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func apply_palette(
	mesh_instance: MeshInstance3D,
	half_width: float,
	light_color: Color,
	dark_color: Color,
	depth_yards: float = FAIRWAY_DEPTH_YARDS
) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = build_mesh(half_width, light_color, dark_color, depth_yards)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, make_material())


static func build_surround_mesh(color: Color) -> ArrayMesh:
	var x0 := -SURROUND_HALF_WIDTH_YARDS
	var x1 := SURROUND_HALF_WIDTH_YARDS
	var z_near := SURROUND_NEAR_Z
	var z_far := -SURROUND_DEPTH_YARDS
	var verts := PackedVector3Array([
		Vector3(x0, SURROUND_Y, z_near),
		Vector3(x1, SURROUND_Y, z_near),
		Vector3(x1, SURROUND_Y, z_far),
		Vector3(x0, SURROUND_Y, z_far),
	])
	var colors := PackedColorArray([color, color, color, color])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_surround_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func apply_surround(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = build_surround_mesh(color)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, make_surround_material())
	mesh_instance.sorting_offset = -1.0


static func _uv_for_tile(col: int, row: int) -> Vector4:
	var px_x := float(col) * TILE_PX
	var px_y := float(row) * TILE_PX
	var u0 := maxf((px_x + UV_INSET_PX) / ATLAS_WIDTH_PX, 0.0)
	var u1 := minf((px_x + TILE_PX - UV_INSET_PX) / ATLAS_WIDTH_PX, 1.0)
	var v0 := maxf((px_y + UV_INSET_PX) / ATLAS_HEIGHT_PX, 0.0)
	var v1 := minf((px_y + TILE_PX - UV_INSET_PX) / ATLAS_HEIGHT_PX, 1.0)
	return Vector4(u0, v0, u1, v1)


static func _append_stripe_quad(
	verts: PackedVector3Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	x0: float,
	x1: float,
	z_near: float,
	z_far: float,
	tint: Color,
	tile_col: int,
	tile_row: int
) -> void:
	var uv := _uv_for_tile(tile_col, tile_row)
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
