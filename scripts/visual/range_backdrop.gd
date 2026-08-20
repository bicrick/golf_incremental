class_name RangeBackdrop
extends RefCounted
## Painted horizon backdrop — camera-facing quad sized to the perspective frustum.
## Transparent sky in the texture lets the dynamic sky dome show through.

const TEXTURE_PATH := "res://assets/sprites/background/range_backdrop.png"
const BACKDROP_SHADER := preload("res://shaders/range_backdrop.gdshader")
## Far behind the ground mesh (300 yd deep) so live geometry can never reach or
## clip through the backdrop plane, but still inside the 500 yd sky dome.
## The quad is frustum-sized, so screen-space appearance is independent of this.
const DEFAULT_DISTANCE_YARDS := 450.0
## Distance the editor alignment (Backdrop node offset, horizon nudge) was tuned at.
const ALIGNMENT_TUNED_DISTANCE_YARDS := 290.0
## Nudge the quad along camera-up so the painted treeline meets the fairway horizon.
## Scaled with distance so the on-screen shift stays identical.
const HORIZON_OFFSET_YARDS := -1.0 * (DEFAULT_DISTANCE_YARDS / ALIGNMENT_TUNED_DISTANCE_YARDS)
## Default landscape aspect for editor / when no override is passed.
## Artwork is 320x180 (16:9); never stretch taller than this or mountains warp.
const REFERENCE_ASPECT := 16.0 / 9.0
## Extra coverage so the editor Backdrop translate cannot uncover frustum edges.
const BASE_OVERSCAN := 0.06


static func populate(
	container: Node3D,
	camera: Camera3D,
	distance_yards: float = DEFAULT_DISTANCE_YARDS,
	aspect_override: float = -1.0
) -> MeshInstance3D:
	for child in container.get_children():
		child.free()

	if camera == null:
		return null

	var tex := load(TEXTURE_PATH) as Texture2D
	if tex == null:
		push_error("RangeBackdrop: missing texture at %s" % TEXTURE_PATH)
		return null

	var mesh := _build_camera_quad(camera, distance_yards, container, aspect_override)
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
	apply_palette_tints(mesh_instance, tint, tint)


static func apply_palette_tints(
	mesh_instance: MeshInstance3D,
	grass_tint: Color,
	foliage_tint: Color
) -> void:
	if mesh_instance == null:
		return
	var mat := mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter(&"grass_tint", grass_tint)
		mat.set_shader_parameter(&"foliage_tint", foliage_tint)
		mat.set_shader_parameter(&"albedo_color", Color.WHITE)


static func _make_material(tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	mat.set_shader_parameter(&"albedo_tex", tex)
	mat.set_shader_parameter(&"albedo_color", Color.WHITE)
	mat.set_shader_parameter(&"grass_tint", Color.WHITE)
	mat.set_shader_parameter(&"foliage_tint", Color.WHITE)
	mat.render_priority = -64
	return mat


static func _build_camera_quad(
	camera: Camera3D,
	distance_yards: float,
	container: Node3D,
	aspect_override: float = -1.0
) -> ArrayMesh:
	var live_aspect := aspect_override if aspect_override > 0.01 else REFERENCE_ASPECT
	var cam_xform := _camera_transform_relative_to(container, camera)
	var cam_basis := cam_xform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up := cam_basis.y

	var size := _frustum_size_at_distance(camera, distance_yards, live_aspect)
	## Keep 16:9 art proportions — portrait crops sides instead of stretching mountains.
	var height := size.y
	var width := maxf(size.x, height * REFERENCE_ASPECT)
	width *= 1.0 + BASE_OVERSCAN
	height *= 1.0 + BASE_OVERSCAN
	## Verts are authored pre-Backdrop-transform; expand so the editor nudge cannot gap.
	var nudge := container.transform.origin
	width += 2.0 * absf(nudge.dot(right))
	height += 2.0 * absf(nudge.dot(up))

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


## Godot: KEEP_HEIGHT → fov is vertical; KEEP_WIDTH → fov is horizontal.
static func _frustum_size_at_distance(
	camera: Camera3D,
	distance_yards: float,
	aspect: float
) -> Vector2:
	if camera != null and camera.is_inside_tree():
		var vp := camera.get_viewport().get_visible_rect().size
		if vp.x > 1.0 and vp.y > 1.0:
			var mid := vp * 0.5
			var center := camera.project_position(mid, distance_yards)
			var right_pt := camera.project_position(Vector2(vp.x, mid.y), distance_yards)
			var top_pt := camera.project_position(Vector2(mid.x, 0.0), distance_yards)
			var w := center.distance_to(right_pt) * 2.0
			var h := center.distance_to(top_pt) * 2.0
			if w > 1.0 and h > 1.0:
				return Vector2(w, h)
	var half_fov := deg_to_rad(camera.fov * 0.5)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		var width := 2.0 * distance_yards * tan(half_fov)
		return Vector2(width, width / maxf(aspect, 0.01))
	var height := 2.0 * distance_yards * tan(half_fov)
	return Vector2(height * maxf(aspect, 0.01), height)


static func _camera_transform_relative_to(container: Node3D, camera: Camera3D) -> Transform3D:
	var parent := container.get_parent()
	if parent is Node3D and camera.get_parent() == parent:
		return parent.transform.affine_inverse() * camera.transform
	return camera.transform
