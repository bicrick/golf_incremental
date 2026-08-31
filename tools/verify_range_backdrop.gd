extends SceneTree
## godot --headless --script res://tools/verify_range_backdrop.gd

const RANGE_VIEW_SCENE := preload("res://scenes/range/range_view.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _verify_populate() and ok
	ok = _verify_palette_tints() and ok
	ok = _verify_ping_pong() and ok
	print("range_backdrop_ok=", ok)
	quit(0 if ok else 1)


func _verify_populate() -> bool:
	var range_view := RANGE_VIEW_SCENE.instantiate()
	root.add_child(range_view)
	await process_frame
	await process_frame

	var backdrop := range_view.get_node_or_null("Backdrop") as Node3D
	var camera := range_view.get_node_or_null("PerspectiveCamera") as Camera3D
	if backdrop == null or camera == null:
		print("FAIL: missing Backdrop or PerspectiveCamera on range_view")
		return false

	var mesh_instance := RangeBackdrop.populate(backdrop, camera)
	if mesh_instance == null:
		print("FAIL: RangeBackdrop.populate returned null")
		return false

	if not FileAccess.file_exists(RangeBackdrop.TEXTURE_PATH):
		print("FAIL: breeze gif missing at ", RangeBackdrop.TEXTURE_PATH)
		return false
	if not FileAccess.file_exists(RangeBackdrop.ORIGINAL_STILL_PATH):
		print("FAIL: original range_backdrop.png should remain on disk")
		return false

	var anim := RangeBackdrop.make_animated_texture()
	if anim == null:
		print("FAIL: make_animated_texture returned null")
		return false
	var expected_frames := RangeBackdrop.ping_pong_sequence().size()
	if anim.frames != expected_frames:
		print(
			"FAIL: animated backdrop frames=%d expected ping-pong %d"
			% [anim.frames, expected_frames]
		)
		return false
	if not is_equal_approx(anim.get_frame_duration(0), RangeBackdrop.FRAME_DURATION_SEC):
		print("FAIL: animated backdrop frame duration not set")
		return false
	var frame0 := anim.get_frame_texture(0)
	if frame0 == null or frame0.get_width() != 256 or frame0.get_height() != 180:
		print("FAIL: breeze gif frames expected 256x180")
		return false

	var mat := mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat == null or mat.get_shader_parameter(&"albedo_tex") != anim:
		print("FAIL: backdrop material missing animated texture")
		return false

	var mesh := mesh_instance.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0:
		print("FAIL: backdrop mesh has no surfaces")
		return false

	## KEEP_HEIGHT: fov is vertical — quad must cover the measured frustum width.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.make_current()
	await process_frame
	var covered := RangeBackdrop.populate(
		backdrop, camera, RangeBackdrop.DEFAULT_DISTANCE_YARDS, 16.0 / 9.0
	)
	if covered == null:
		print("FAIL: repopulate under KEEP_HEIGHT failed")
		return false
	var arrays := covered.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_x := INF
	var max_x := -INF
	for v in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	var quad_w := max_x - min_x
	## At 16:9 KEEP_HEIGHT, frustum width is ~1227 yd at 450; undersized math was ~690.
	if quad_w < 1000.0:
		print("FAIL: backdrop quad too narrow under KEEP_HEIGHT (w=", snappedf(quad_w, 0.1), ")")
		return false
	print("OK: backdrop KEEP_HEIGHT width=", snappedf(quad_w, 0.1))
	return true


func _verify_palette_tints() -> bool:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	mesh_instance.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = RangeBackdrop.BACKDROP_SHADER
	mesh_instance.set_surface_override_material(0, mat)

	var grass := Color(0.9, 0.99, 0.12, 1.0)
	var foliage := Color(1.0, 1.0, 1.0, 1.0)
	RangeBackdrop.apply_palette_tints(mesh_instance, grass, foliage)

	if mat.get_shader_parameter(&"grass_tint") != grass:
		print("FAIL: apply_palette_tints did not update grass_tint")
		return false
	if mat.get_shader_parameter(&"foliage_tint") != foliage:
		print("FAIL: apply_palette_tints did not update foliage_tint")
		return false
	if mat.get_shader_parameter(&"albedo_color") != Color.WHITE:
		print("FAIL: apply_palette_tints should reset albedo_color to white")
		return false

	RangeBackdrop.apply_tint(mesh_instance, Color(0.7, 0.8, 0.9, 1.0))
	if mat.get_shader_parameter(&"grass_tint") != Color(0.7, 0.8, 0.9, 1.0):
		print("FAIL: apply_tint legacy wrapper did not update grass_tint")
		return false
	if mat.get_shader_parameter(&"foliage_tint") != Color(0.7, 0.8, 0.9, 1.0):
		print("FAIL: apply_tint legacy wrapper did not update foliage_tint")
		return false

	print("OK: backdrop palette tint uniforms")
	return true


func _verify_ping_pong() -> bool:
	var duration := RangeBackdrop.FRAME_DURATION_SEC
	if RangeBackdrop.ping_pong_frame(0.0) != 0:
		print("FAIL: ping-pong should start at frame 0")
		return false
	if RangeBackdrop.ping_pong_frame(duration) != 1:
		print("FAIL: ping-pong should advance to frame 1 after one hold")
		return false
	if RangeBackdrop.ping_pong_frame(duration * 15.0) != 15:
		print("FAIL: ping-pong should reach last frame 15")
		return false
	if RangeBackdrop.ping_pong_frame(duration * 16.0) != 14:
		print("FAIL: ping-pong should reverse after the last frame")
		return false
	if RangeBackdrop.ping_pong_frame(duration * 29.0) != 1:
		print("FAIL: ping-pong should return to frame 1 before wrapping")
		return false
	if RangeBackdrop.ping_pong_frame(duration * 30.0) != 0:
		print("FAIL: ping-pong should wrap to frame 0 without a snap from 15")
		return false
	var sequence := RangeBackdrop.ping_pong_sequence()
	if sequence.size() != 30 or sequence[0] != 0 or sequence[15] != 15 or sequence[16] != 14:
		print("FAIL: ping-pong sequence should be 0..15..1")
		return false
	print("OK: backdrop ping-pong frame indices")
	return true
