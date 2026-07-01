class_name FairwayGround3D
extends RefCounted
## Builds the driving-range ground as a real 3D mesh — alternating light/dark
## "mower stripe" lanes running lengthwise down the fairway toward -Z.
## Replaces the old FairwayStripes perspective-trapezoid Polygon2D stack;
## Camera3D projection now does the vanishing-point convergence for free.

const STRIPE_WIDTH_YARDS := 2.0
const FAIRWAY_DEPTH_YARDS := 224.0  ## 28 × 8 yd — unchanged fairway reach


static func build_mesh(
	half_width: float,
	light_color: Color,
	dark_color: Color
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var z_near := 0.0
	var z_far := -FAIRWAY_DEPTH_YARDS
	var stripe_count := ceili(half_width * 2.0 / STRIPE_WIDTH_YARDS)

	for i in stripe_count:
		var x0 := -half_width + float(i) * STRIPE_WIDTH_YARDS
		var x1 := minf(x0 + STRIPE_WIDTH_YARDS, half_width)
		var color := light_color if i % 2 == 0 else dark_color
		var base := verts.size()
		verts.append(Vector3(x0, 0.0, z_near))
		verts.append(Vector3(x1, 0.0, z_near))
		verts.append(Vector3(x1, 0.0, z_far))
		verts.append(Vector3(x0, 0.0, z_far))
		for _c in 4:
			colors.append(color)
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2,
			base, base + 2, base + 3,
		]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Rebuild the mesh in-place on an existing MeshInstance3D (day/night palette swaps).
static func apply_palette(
	mesh_instance: MeshInstance3D,
	half_width: float,
	light_color: Color,
	dark_color: Color
) -> void:
	if mesh_instance == null:
		return
	mesh_instance.mesh = build_mesh(half_width, light_color, dark_color)
	if mesh_instance.get_surface_override_material(0) == null:
		mesh_instance.set_surface_override_material(0, make_material())
