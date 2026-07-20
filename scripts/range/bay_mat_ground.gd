class_name BayMatGround
extends RefCounted
## Fairway grass tile on hitting mats — darker than fairway dark stripes, with edge lips.

const CELL_SIZE_YARDS := CellGround.CELL_SIZE_YARDS
const CELL_HALF_YARDS := CellGround.CELL_HALF_YARDS
const PIXEL_YARDS := 0.024
const MAT_Y := PIXEL_YARDS
const RENDER_PRIORITY := 5
const LIP_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const NEAR_Z := 0.0
const FAR_Z := -CELL_SIZE_YARDS
## Darken fairway_dark toward black so mats read below the fairway dark stripes.
const MAT_DARKEN := 0.28


static func apply_to_mesh(
	mesh_instance: MeshInstance3D,
	fairway_light: Color = Color.TRANSPARENT,
	fairway_dark: Color = Color.TRANSPARENT
) -> void:
	if mesh_instance == null:
		return
	if fairway_light == Color.TRANSPARENT:
		var snap := DayNightPalette.sample_at(24.0)
		var day_factor := DayNightPalette.day_light_factor(24.0)
		var colors := DayNightPalette.fairway_stripe_colors(snap, day_factor)
		fairway_light = colors[0]
		fairway_dark = colors[1]

	mesh_instance.mesh = build_mat_mesh()
	var mat_color := mat_stripe_color(fairway_dark)
	var mat := FairwayGrassTiles3D.make_bay_mat_material()
	mat.set_shader_parameter(&"fairway_light", mat_color)
	mat.set_shader_parameter(&"fairway_dark", mat_color)
	mesh_instance.set_surface_override_material(0, mat)

	var lip_mat := make_lip_material()
	for surface_idx in range(1, mesh_instance.mesh.get_surface_count()):
		mesh_instance.set_surface_override_material(surface_idx, lip_mat)
	mesh_instance.sorting_offset = 2.0
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func mat_stripe_color(fairway_dark: Color) -> Color:
	return fairway_dark.lerp(Color.BLACK, MAT_DARKEN)


static func build_mat_mesh() -> ArrayMesh:
	var x0 := -CELL_HALF_YARDS
	var x1 := CELL_HALF_YARDS
	var z_near_inner := NEAR_Z - PIXEL_YARDS
	var z_far_inner := FAR_Z + PIXEL_YARDS
	var mesh := ArrayMesh.new()

	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		_top_quad_arrays(x0, x1, MAT_Y, z_near_inner, z_far_inner, true)
	)
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		_wall_arrays(x0, x1, 0.0, MAT_Y, z_near_inner, false)
	)
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		_top_quad_arrays(x0, x1, MAT_Y, z_near_inner, NEAR_Z, false)
	)
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		_wall_arrays(x0, x1, 0.0, MAT_Y, z_far_inner, true)
	)
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		_top_quad_arrays(x0, x1, MAT_Y, FAR_Z, z_far_inner, false)
	)
	return mesh


static func _top_quad_arrays(
	x0: float,
	x1: float,
	y: float,
	z_near: float,
	z_far: float,
	with_uv: bool
) -> Array:
	var verts := PackedVector3Array([
		Vector3(x0, y, z_near),
		Vector3(x1, y, z_near),
		Vector3(x1, y, z_far),
		Vector3(x0, y, z_far),
	])
	var arrays := _surface_arrays(verts, PackedInt32Array([0, 1, 2, 0, 2, 3]))
	if with_uv:
		var width := x1 - x0
		var depth := z_near - z_far
		var u_max := width / CELL_SIZE_YARDS
		var v_max := depth / CELL_SIZE_YARDS
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(u_max, 0.0),
			Vector2(u_max, v_max),
			Vector2(0.0, v_max),
		])
	return arrays


static func _wall_arrays(
	x0: float,
	x1: float,
	y0: float,
	y1: float,
	z: float,
	face_toward_positive_z: bool
) -> Array:
	var verts := PackedVector3Array([
		Vector3(x0, y0, z),
		Vector3(x0, y1, z),
		Vector3(x1, y1, z),
		Vector3(x1, y0, z),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	if not face_toward_positive_z:
		indices = PackedInt32Array([0, 2, 1, 0, 3, 2])
	return _surface_arrays(verts, indices)


static func _surface_arrays(verts: PackedVector3Array, indices: PackedInt32Array) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func make_lip_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LIP_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = RENDER_PRIORITY + 1
	return mat
