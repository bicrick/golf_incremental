extends SceneTree
## godot --headless --script res://tools/verify_range_backdrop.gd

const RANGE_VIEW_SCENE := preload("res://scenes/range/range_view.tscn")


func _initialize() -> void:
	var ok := true
	ok = _verify_populate() and ok
	print("range_backdrop_ok=", ok)
	quit(0 if ok else 1)


func _verify_populate() -> bool:
	var range_view := RANGE_VIEW_SCENE.instantiate()
	root.add_child(range_view)

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

	RangeBackdrop.apply_tint(mesh_instance, Color(0.7, 0.8, 0.9, 1.0))
	if mat.get_shader_parameter(&"albedo_color") != Color(0.7, 0.8, 0.9, 1.0):
		print("FAIL: apply_tint did not update material color")
		return false

	return true
