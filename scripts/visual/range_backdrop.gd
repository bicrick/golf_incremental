class_name RangeBackdrop
extends RefCounted
## Painted horizon backdrop — camera-facing quad sized to the perspective frustum.
## Transparent sky in the texture lets the dynamic sky dome show through.

const TEXTURE_PATH := "res://assets/sprites/background/range_backdrop.png"
const BACKDROP_SHADER := preload("res://shaders/range_backdrop.gdshader")
const DEFAULT_DISTANCE_YARDS := 290.0
## Nudge the quad along camera-up so the painted treeline meets the fairway horizon.
const HORIZON_OFFSET_YARDS := -1.0


static func populate(
	container: Node3D,
	camera: Camera3D,
	distance_yards: float = DEFAULT_DISTANCE_YARDS
) -> MeshInstance3D:
	for child in container.get_children():
		child.free()

	if camera == null:
		return null

	var tex := load(TEXTURE_PATH) as Texture2D
	if tex == null:
		push_error("RangeBackdrop: missing texture at %s" % TEXTURE_PATH)
		return null

	var mesh := _build_camera_quad(camera, distance_yards, container)
	var material := _make_material(tex)

	var wall := MeshInstance3D.new()
	wall.name = &"BackdropQuad"
	wall.mesh = mesh
	wall.set_surface_override_material(0, material)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	container.add_child(wall)
	return wall


static func apply_tint(mesh_instance: MeshInstance3D, tint: Color) -> void:
	if mesh_instance == null:
		return
	var mat := mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter(&"albedo_color", tint)


static func _make_material(tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	mat.set_shader_parameter(&"albedo_tex", tex)
	mat.set_shader_parameter(&"albedo_color", Color.WHITE)
	mat.render_priority = -64
	return mat


static func _build_camera_quad(camera: Camera3D, distance_yards: float, container: Node3D) -> ArrayMesh:
	var viewport_size := _viewport_size(camera)
	var aspect := viewport_size.x / maxf(float(viewport_size.y), 1.0)
	var half_fov := deg_to_rad(camera.fov * 0.5)
	var height := 2.0 * distance_yards * tan(half_fov)
	var width := height * aspect

	var cam_xform := _camera_transform_relative_to(container, camera)
	var cam_basis := cam_xform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up := cam_basis.y
	var center := cam_xform.origin + forward * distance_yards + up * HORIZON_OFFSET_YARDS

	var half_w := width * 0.5
	var half_h := height * 0.5
	# Local-space verts: Backdrop node Transform shifts the quad in the editor.
	var verts := PackedVector3Array([
		center - right * half_w - up * half_h,
		center + right * half_w - up * half_h,
		center + right * half_w + up * half_h,
		center - right * half_w + up * half_h,
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
	])
	var normal := (-forward).normalized()
	var normals := PackedVector3Array([normal, normal, normal, normal])
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


static func _camera_transform_relative_to(container: Node3D, camera: Camera3D) -> Transform3D:
	var parent := container.get_parent()
	if parent is Node3D and camera.get_parent() == parent:
		return parent.transform.affine_inverse() * camera.transform
	return camera.transform


static func _viewport_size(camera: Camera3D) -> Vector2i:
	var viewport := camera.get_viewport()
	if viewport:
		var size := Vector2i(viewport.get_visible_rect().size)
		if size.x > 1 and size.y > 1:
			return size
	return Vector2i(480, 270)
