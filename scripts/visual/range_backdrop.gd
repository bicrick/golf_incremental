class_name RangeBackdrop
extends RefCounted
## Painted horizon backdrop — camera-facing quad sized to the perspective frustum.
## Plays the breeze GIF frames via AnimatedTexture, ping-ponging so the loop never snaps.
## Original still frame: res://assets/sprites/background/range_backdrop.png

const TEXTURE_PATH := "res://assets/sprites/background/range_backdrop_breeze.gif"
const FRAME_PATH_FORMAT := "res://assets/sprites/background/range_backdrop_breeze_frames/%02d.png"
const ORIGINAL_STILL_PATH := "res://assets/sprites/background/range_backdrop.png"
const BACKDROP_SHADER := preload("res://shaders/range_backdrop.gdshader")
const FRAME_COUNT := 16
## One beat at 120 BPM (60/120). Most range tracks sit near this.
const FRAME_DURATION_SEC := 0.5

static var _animated: AnimatedTexture
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

	var tex := make_animated_texture()
	if tex == null:
		push_error("RangeBackdrop: missing breeze GIF frames")
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


static func ping_pong_frame(
	time_sec: float,
	frame_count: int = FRAME_COUNT,
	duration: float = FRAME_DURATION_SEC
) -> int:
	var last := maxi(frame_count - 1, 1)
	var cycle := last * 2
	var step := int(floor(time_sec / maxf(duration, 0.001)))
	var pos := posmod(step, cycle)
	if pos > last:
		return cycle - pos
	return pos


static func ping_pong_sequence(frame_count: int = FRAME_COUNT) -> PackedInt32Array:
	var last := maxi(frame_count - 1, 1)
	var sequence := PackedInt32Array()
	for i in frame_count:
		sequence.append(i)
	var i := last - 1
	while i > 0:
		sequence.append(i)
		i -= 1
	return sequence


static func make_animated_texture() -> AnimatedTexture:
	if _animated != null:
		return _animated
	var frames: Array[Texture2D] = []
	for index in FRAME_COUNT:
		var tex := load(FRAME_PATH_FORMAT % index) as Texture2D
		if tex == null:
			push_error("RangeBackdrop: missing gif frame %s" % (FRAME_PATH_FORMAT % index))
			return null
		frames.append(tex)
	var sequence := ping_pong_sequence(FRAME_COUNT)
	var anim := AnimatedTexture.new()
	anim.frames = sequence.size()
	anim.pause = false
	anim.speed_scale = 1.0
	for slot in sequence.size():
		anim.set_frame_texture(slot, frames[sequence[slot]])
		anim.set_frame_duration(slot, FRAME_DURATION_SEC)
	_animated = anim
	return _animated


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
