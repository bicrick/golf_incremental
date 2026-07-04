class_name FairwayFlora
extends RefCounted
## Scattered fairway-edge flowers and grass tufts — one MultiMesh draw call.

const FLORA_SHADER := preload("res://shaders/fairway_flora.gdshader")

const SPRITE_PATHS: Array[String] = [
	"res://assets/sprites/fairway/crabgrass.png",
	"res://assets/sprites/fairway/daisy.png",
	"res://assets/sprites/fairway/dandelion.png",
	"res://assets/sprites/fairway/rose.png",
]

## Atlas index matches SPRITE_PATHS order (crabgrass-heavy for subtle edges).
const SPECIES_WEIGHTS: Array[float] = [0.45, 0.30, 0.18, 0.07]

const INSTANCE_COUNT := 180
const SEED := 4242
const DEPTH_MIN_YARDS := 28.0
const DEPTH_MAX_YARDS := 115.0
const FLORA_Y := 0.015
const SIZE_MIN := 0.10
const SIZE_MAX := 0.20
const SPECIES_COUNT := 4
const CLUSTER_COUNT := 36
const INSTANCES_PER_CLUSTER_MIN := 3
const INSTANCES_PER_CLUSTER_MAX := 7
const CLUSTER_Z_SPREAD := 5.0
const CLUSTER_X_SPREAD := 0.6
const BAY_EXCLUSION_X := 4.0
const BAY_EXCLUSION_Z_NEAR := -22.0


static func _build_atlas() -> Dictionary:
	var images: Array[Image] = []
	var max_w := 0
	var max_h := 0
	for path in SPRITE_PATHS:
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("FairwayFlora: missing texture at %s" % path)
			continue
		var img := tex.get_image()
		images.append(img)
		max_w = maxi(max_w, img.get_width())
		max_h = maxi(max_h, img.get_height())

	if images.is_empty():
		return {}

	var atlas_w := max_w * 2
	var atlas_h := max_h * 2
	var atlas_img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var cell_positions: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(max_w, 0),
		Vector2i(0, max_h),
		Vector2i(max_w, max_h),
	]
	for i in images.size():
		var img: Image = images[i]
		atlas_img.blit_rect(
			img,
			Rect2i(0, 0, img.get_width(), img.get_height()),
			cell_positions[i]
		)

	return {
		"texture": ImageTexture.create_from_image(atlas_img),
		"cell_w": max_w,
		"cell_h": max_h,
	}


static func _build_quad_mesh(width: float, height: float) -> ArrayMesh:
	var half_w := width * 0.5
	var verts := PackedVector3Array([
		Vector3(-half_w, 0.0, 0.0),
		Vector3(half_w, 0.0, 0.0),
		Vector3(half_w, height, 0.0),
		Vector3(-half_w, height, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
	])
	var normals := PackedVector3Array([
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_material(atlas: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FLORA_SHADER
	mat.set_shader_parameter(&"albedo_tex", atlas)
	mat.set_shader_parameter(&"flora_height", 1.0)
	return mat


static func _pick_species(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var cumulative := 0.0
	for i in SPECIES_WEIGHTS.size():
		cumulative += SPECIES_WEIGHTS[i]
		if roll <= cumulative:
			return i
	return SPECIES_COUNT - 1


static func _depth_scale(z: float) -> float:
	var depth := absf(z)
	var t := inverse_lerp(DEPTH_MIN_YARDS, DEPTH_MAX_YARDS, depth)
	return lerpf(1.05, 0.55, clampf(t, 0.0, 1.0))


static func _in_bay_exclusion(x: float, z: float) -> bool:
	return absf(x) < BAY_EXCLUSION_X and z > BAY_EXCLUSION_Z_NEAR


static func _sample_edge_cluster(rng: RandomNumberGenerator) -> Vector3:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var edge_x := side * rng.randf_range(
		Balance.FAIRWAY_HALF_WIDTH_YARDS + 0.5,
		RangeGrid.HALF_WIDTH_YARDS - 0.6
	)
	var z := -rng.randf_range(DEPTH_MIN_YARDS, DEPTH_MAX_YARDS)
	return Vector3(edge_x, FLORA_Y, z)


static func _generate_positions(rng: RandomNumberGenerator) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var attempts := 0
	var max_attempts := INSTANCE_COUNT * 8

	while positions.size() < INSTANCE_COUNT and attempts < max_attempts:
		attempts += 1
		var cluster := _sample_edge_cluster(rng)
		var cluster_size := rng.randi_range(INSTANCES_PER_CLUSTER_MIN, INSTANCES_PER_CLUSTER_MAX)
		for _j in cluster_size:
			if positions.size() >= INSTANCE_COUNT:
				break
			var offset := Vector3(
				rng.randf_range(-CLUSTER_X_SPREAD, CLUSTER_X_SPREAD),
				0.0,
				rng.randf_range(-CLUSTER_Z_SPREAD, CLUSTER_Z_SPREAD)
			)
			var pos := cluster + offset
			pos.x = clampf(
				pos.x,
				-(RangeGrid.HALF_WIDTH_YARDS - 0.4),
				RangeGrid.HALF_WIDTH_YARDS - 0.4
			)
			if absf(pos.x) < Balance.FAIRWAY_HALF_WIDTH_YARDS + 0.2:
				continue
			if _in_bay_exclusion(pos.x, pos.z):
				continue
			positions.append(pos)

	while positions.size() < INSTANCE_COUNT:
		var pos := _sample_edge_cluster(rng)
		if absf(pos.x) < Balance.FAIRWAY_HALF_WIDTH_YARDS + 0.2:
			continue
		if _in_bay_exclusion(pos.x, pos.z):
			continue
		positions.append(pos)

	return positions


## Populate `container` with a single MultiMeshInstance3D of scattered flora.
static func populate(container: Node3D) -> MultiMeshInstance3D:
	for child in container.get_children():
		child.queue_free()

	var atlas_data := _build_atlas()
	if atlas_data.is_empty():
		return null

	var quad := _build_quad_mesh(1.0, 1.0)
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_custom_data = true
	multi_mesh.mesh = quad
	multi_mesh.instance_count = INSTANCE_COUNT

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var positions := _generate_positions(rng)
	var placed := mini(positions.size(), INSTANCE_COUNT)
	multi_mesh.instance_count = placed

	for i in placed:
		var pos: Vector3 = positions[i]
		var scale := rng.randf_range(SIZE_MIN, SIZE_MAX) * _depth_scale(pos.z)
		var species := _pick_species(rng)
		var phase := rng.randf()

		var xf := Transform3D(Basis.IDENTITY, pos)
		xf = xf.scaled(Vector3(scale, scale, scale))
		multi_mesh.set_instance_transform(i, xf)
		multi_mesh.set_instance_custom_data(
			i,
			Color(float(species) / float(SPECIES_COUNT) + 0.001, phase, 0.0, 0.0)
		)

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FloraMultiMesh"
	mmi.multimesh = multi_mesh
	mmi.material_override = _make_material(atlas_data["texture"])
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	container.add_child(mmi)
	return mmi


static func apply_tint(mmi: MultiMeshInstance3D, color: Color) -> void:
	if mmi == null:
		return
	var mat := mmi.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter(&"tint", color)
