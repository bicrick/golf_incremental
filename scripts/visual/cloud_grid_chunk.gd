class_name CloudGridChunk
extends RefCounted
## Occupancy bitmap to merged exterior mesh for one fixed cloud grid region.

const FACE_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]


static func default_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.97, 0.98, 1.0, 0.94)
	mat.render_priority = 2
	return mat


static func build_mesh_from_occupancy(
	occupancy: Dictionary,
	x_min: float,
	z_min: float,
	cell_size: float,
	layer_y: float
) -> ArrayMesh:
	var solids: Dictionary = {}
	for key: Variant in occupancy.keys():
		if not bool(occupancy[key]):
			continue
		var cell: Vector2i = key as Vector2i
		solids[Vector3i(cell.x, 0, cell.y)] = true
	return _build_exterior_mesh(solids, x_min, z_min, cell_size, layer_y)


static func occupied_cell_count(occupancy: Dictionary) -> int:
	var count := 0
	for key: Variant in occupancy.keys():
		if bool(occupancy[key]):
			count += 1
	return count


static func _build_exterior_mesh(
	solids: Dictionary,
	x_min: float,
	z_min: float,
	cell_size: float,
	layer_y: float
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for key: Vector3i in solids.keys():
		var origin := Vector3(
			x_min + float(key.x) * cell_size,
			layer_y + float(key.y) * cell_size,
			z_min + float(key.z) * cell_size
		)
		for dir_index in FACE_DIRS.size():
			var dir: Vector3i = FACE_DIRS[dir_index]
			var neighbor := key + dir
			if solids.has(neighbor):
				continue
			_add_face(vertices, normals, indices, origin, cell_size, dir)

	if vertices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	origin: Vector3,
	size: float,
	dir: Vector3i
) -> void:
	var normal := Vector3(float(dir.x), float(dir.y), float(dir.z))
	var start := vertices.size()
	var s := size

	var corners: Array[Vector3] = []
	if dir == Vector3i(1, 0, 0):
		corners = [
			origin + Vector3(s, 0, 0),
			origin + Vector3(s, s, 0),
			origin + Vector3(s, s, s),
			origin + Vector3(s, 0, s),
		]
	elif dir == Vector3i(-1, 0, 0):
		corners = [
			origin + Vector3(0, 0, s),
			origin + Vector3(0, s, s),
			origin + Vector3(0, s, 0),
			origin + Vector3(0, 0, 0),
		]
	elif dir == Vector3i(0, 1, 0):
		corners = [
			origin + Vector3(0, s, 0),
			origin + Vector3(0, s, s),
			origin + Vector3(s, s, s),
			origin + Vector3(s, s, 0),
		]
	elif dir == Vector3i(0, -1, 0):
		corners = [
			origin + Vector3(0, 0, s),
			origin + Vector3(s, 0, s),
			origin + Vector3(s, 0, 0),
			origin + Vector3(0, 0, 0),
		]
	elif dir == Vector3i(0, 0, 1):
		corners = [
			origin + Vector3(0, 0, s),
			origin + Vector3(s, 0, s),
			origin + Vector3(s, s, s),
			origin + Vector3(0, s, s),
		]
	else:
		corners = [
			origin + Vector3(s, 0, 0),
			origin + Vector3(0, 0, 0),
			origin + Vector3(0, s, 0),
			origin + Vector3(s, s, 0),
		]

	for corner in corners:
		vertices.append(corner)
		normals.append(normal)
	indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
