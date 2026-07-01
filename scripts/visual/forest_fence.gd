class_name ForestFence
extends RefCounted
## Forest fence running down both fairway edges. In the old 2.5D range this
## needed hand-rolled perspective-trapezoid math to converge toward a
## vanishing point; in real 3D it is just two flat textured quads placed in
## world space — Camera3D projection makes them recede toward the horizon
## for free.

const TEXTURE_PATH := "res://assets/sprites/forest/middle.png"
## Content band inside middle.png (240px tall): transparent 0-88, tree/
## path/flower art 89-174, plain base 175-239. UV only samples the content
## band so repeats butt against each other with no dead space.
const CONTENT_TOP_PX := 89.0
const CONTENT_BOTTOM_PX := 175.0
const FENCE_HEIGHT_YARDS := 4.0
## World-Z span of one texture repeat.
const REPEAT_YARDS := 6.0


static func _uv_v_range(tex_height: float) -> Vector2:
	return Vector2(CONTENT_TOP_PX / tex_height, CONTENT_BOTTOM_PX / tex_height)


static func _build_wall_mesh(x: float, length_yards: float, tex: Texture2D) -> ArrayMesh:
	var tex_height := float(tex.get_height())
	var v_range := _uv_v_range(tex_height)
	var repeat := maxf(length_yards / REPEAT_YARDS, 1.0)

	var verts := PackedVector3Array([
		Vector3(x, 0.0, 0.0),
		Vector3(x, 0.0, -length_yards),
		Vector3(x, FENCE_HEIGHT_YARDS, -length_yards),
		Vector3(x, FENCE_HEIGHT_YARDS, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, v_range.y),
		Vector2(repeat, v_range.y),
		Vector2(repeat, v_range.x),
		Vector2(0.0, v_range.x),
	])
	var normal := Vector3(1.0 if x < 0.0 else -1.0, 0.0, 0.0)
	var normals := PackedVector3Array([normal, normal, normal, normal])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_material(tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	return mat


## Populate `container` (a Node3D) with left/right fence walls at +/-half_width,
## running `length_yards` down -Z from the tee.
static func populate(
	container: Node3D,
	half_width: float,
	length_yards: float,
	texture: Texture2D = null
) -> Array[MeshInstance3D]:
	for child in container.get_children():
		child.free()

	var tex := texture
	if tex == null:
		tex = load(TEXTURE_PATH) as Texture2D
	if tex == null:
		return []

	var material := make_material(tex)
	var walls: Array[MeshInstance3D] = []
	for x in [-half_width, half_width]:
		var wall := MeshInstance3D.new()
		wall.mesh = _build_wall_mesh(x, length_yards, tex)
		wall.set_surface_override_material(0, material)
		container.add_child(wall)
		walls.append(wall)
	return walls
