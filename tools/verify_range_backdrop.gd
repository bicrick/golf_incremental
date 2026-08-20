extends SceneTree
## godot --headless --script res://tools/verify_range_backdrop.gd

const RANGE_VIEW_SCENE := preload("res://scenes/range/range_view.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _verify_populate() and ok
	ok = _verify_palette_tints() and ok
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

	var tex := load(RangeBackdrop.TEXTURE_PATH) as Texture2D
	if tex == null:
		print("FAIL: backdrop texture missing at ", RangeBackdrop.TEXTURE_PATH)
		return false

	var mat := mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat == null or mat.get_shader_parameter(&"albedo_tex") != tex:
		print("FAIL: backdrop material missing expected texture")
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
