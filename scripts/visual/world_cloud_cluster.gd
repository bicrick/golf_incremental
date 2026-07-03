class_name WorldCloudCluster
extends RefCounted
## Thermodynamic voxel cloud — density field, diffusion, greedy exterior mesh.

const GRID_W := 10
const GRID_H := 8
const DEFAULT_BLOCK_SIZE := 2.5
const DIFFUSION_STRENGTH := 0.22
const DIFFUSION_PASSES := 2
const CURL_STRENGTH := 0.15
const STACK_CHANCE := 0.08

const FACE_DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]


static func generate(
	seed: int,
	layer_y: float,
	coverage_target: float,
	block_size: float = DEFAULT_BLOCK_SIZE,
	base_material: Material = null
) -> Node3D:
	var cluster := Node3D.new()
	cluster.name = &"CloudCluster"

	var build := _build_solids(seed, coverage_target, layer_y, block_size)
	if build.solids.is_empty():
		cluster.set_meta(&"block_count", 0)
		cluster.set_meta(&"solid_centers", PackedVector3Array())
		return cluster

	var mesh := _build_exterior_mesh(build.solids, layer_y, block_size)
	if mesh == null:
		cluster.set_meta(&"block_count", 0)
		cluster.set_meta(&"solid_centers", PackedVector3Array())
		return cluster

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"CloudMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = base_material.duplicate() if base_material else _default_material()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cluster.add_child(mesh_instance)

	cluster.set_meta(&"block_count", build.solids.size())
	cluster.set_meta(&"solid_centers", build.centers)
	return cluster


static func block_count_for(cluster: Node3D) -> int:
	return int(cluster.get_meta(&"block_count", 0))


static func block_positions(cluster: Node3D) -> Array[Vector3]:
	var stored: Variant = cluster.get_meta(&"solid_centers", null)
	if stored is PackedVector3Array:
		var positions: Array[Vector3] = []
		for pos in stored as PackedVector3Array:
			positions.append(pos)
		positions.sort_custom(_sort_positions)
		return positions
	var positions: Array[Vector3] = []
	for child in cluster.get_children():
		if child is MeshInstance3D:
			positions.append((child as MeshInstance3D).position)
	positions.sort_custom(_sort_positions)
	return positions


static func has_merged_mesh(cluster: Node3D) -> bool:
	if cluster.get_child_count() != 1:
		return false
	return cluster.get_child(0) is MeshInstance3D


static func _sort_positions(a: Vector3, b: Vector3) -> bool:
	if not is_equal_approx(a.x, b.x):
		return a.x < b.x
	if not is_equal_approx(a.z, b.z):
		return a.z < b.z
	return a.y < b.y


static func _default_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.97, 0.98, 1.0, 0.85)
	return mat


class _BuildResult:
	var solids: Dictionary = {}
	var centers: PackedVector3Array = PackedVector3Array()


static func _build_solids(
	seed: int,
	coverage_target: float,
	layer_y: float,
	block_size: float
) -> _BuildResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var vapor := FastNoiseLite.new()
	vapor.seed = seed
	vapor.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	vapor.frequency = rng.randf_range(0.06, 0.12)
	vapor.fractal_octaves = 2

	var curl := FastNoiseLite.new()
	curl.seed = seed + 4113
	curl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	curl.frequency = vapor.frequency * 1.8

	var coverage := clampf(coverage_target, 0.12, 0.95)
	var rho_sat := lerpf(0.58, 0.32, coverage)
	var center := Vector2(float(GRID_W) * 0.5, float(GRID_H) * 0.5)
	var max_radius := maxf(center.length(), 0.001)

	var rho: Array = []
	rho.resize(GRID_H)
	for gz in GRID_H:
		rho[gz] = []
		(rho[gz] as Array).resize(GRID_W)
		for gx in GRID_W:
			var simplex := vapor.get_noise_2d(float(gx), float(gz)) * 0.5 + 0.5
			var curl_bias := _curl_scalar(curl, float(gx), float(gz))
			var dist := Vector2(float(gx), float(gz)).distance_to(center) / max_radius
			var falloff := 1.0 - _smoothstep(0.65, 1.0, dist)
			(rho[gz] as Array)[gx] = clampf((simplex + CURL_STRENGTH * curl_bias) * falloff, 0.0, 1.0)

	for _pass in DIFFUSION_PASSES:
		rho = _diffuse(rho)

	var result := _BuildResult.new()
	for gz in GRID_H:
		for gx in GRID_W:
			var condensed: float = (rho[gz] as Array)[gx]
			if condensed <= rho_sat:
				continue
			var key := Vector3i(gx, 0, gz)
			result.solids[key] = true
			if condensed > rho_sat + 0.12 and rng.randf() < STACK_CHANCE:
				result.solids[Vector3i(gx, 1, gz)] = true

	for key: Vector3i in result.solids.keys():
		var origin := Vector3(
			float(key.x) * block_size,
			layer_y + float(key.y) * block_size,
			-float(key.z) * block_size
		)
		result.centers.append(
			origin + Vector3(block_size * 0.5, block_size * 0.5, -block_size * 0.5)
		)

	return result


static func _curl_scalar(noise: FastNoiseLite, x: float, y: float) -> float:
	const EPS := 0.01
	var dx := (
		noise.get_noise_2d(x + EPS, y)
		- noise.get_noise_2d(x - EPS, y)
	)
	var dy := (
		noise.get_noise_2d(x, y + EPS)
		- noise.get_noise_2d(x, y - EPS)
	)
	return (dx - dy) * 0.5


static func _diffuse(rho: Array) -> Array:
	var next: Array = []
	next.resize(GRID_H)
	for gz in GRID_H:
		next[gz] = []
		(next[gz] as Array).resize(GRID_W)
		for gx in GRID_W:
			var laplacian := 0.0
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = gx + offset.x
				var nz: int = gz + offset.y
				if nx < 0 or nx >= GRID_W or nz < 0 or nz >= GRID_H:
					laplacian += 0.0 - (rho[gz] as Array)[gx]
				else:
					laplacian += (rho[nz] as Array)[nx] - (rho[gz] as Array)[gx]
			var value: float = (rho[gz] as Array)[gx] + DIFFUSION_STRENGTH * laplacian
			(next[gz] as Array)[gx] = clampf(value, 0.0, 1.0)
	return next


static func _build_exterior_mesh(
	solids: Dictionary,
	layer_y: float,
	block_size: float
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	for key: Vector3i in solids.keys():
		var origin := Vector3(
			float(key.x) * block_size,
			layer_y + float(key.y) * block_size,
			-float(key.z) * block_size
		)
		for dir_index in FACE_DIRS.size():
			var dir: Vector3i = FACE_DIRS[dir_index]
			var neighbor := key + dir
			if solids.has(neighbor):
				continue
			_add_face(vertices, normals, indices, origin, block_size, dir)

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
			origin + Vector3(s, s, -s),
			origin + Vector3(s, 0, -s),
		]
	elif dir == Vector3i(-1, 0, 0):
		corners = [
			origin + Vector3(0, 0, -s),
			origin + Vector3(0, s, -s),
			origin + Vector3(0, s, 0),
			origin + Vector3(0, 0, 0),
		]
	elif dir == Vector3i(0, 1, 0):
		corners = [
			origin + Vector3(0, s, 0),
			origin + Vector3(0, s, -s),
			origin + Vector3(s, s, -s),
			origin + Vector3(s, s, 0),
		]
	elif dir == Vector3i(0, -1, 0):
		corners = [
			origin + Vector3(0, 0, -s),
			origin + Vector3(s, 0, -s),
			origin + Vector3(s, 0, 0),
			origin + Vector3(0, 0, 0),
		]
	elif dir == Vector3i(0, 0, 1):
		corners = [
			origin + Vector3(0, 0, 0),
			origin + Vector3(s, 0, 0),
			origin + Vector3(s, s, 0),
			origin + Vector3(0, s, 0),
		]
	else:
		corners = [
			origin + Vector3(s, 0, -s),
			origin + Vector3(0, 0, -s),
			origin + Vector3(0, s, -s),
			origin + Vector3(s, s, -s),
		]

	for corner in corners:
		vertices.append(corner)
		normals.append(normal)
	indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
