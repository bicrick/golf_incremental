extends SceneTree
## Headless fairway flora scatter tests — run:
## godot --headless --script res://tools/verify_fairway_flora.gd

const DAY_TIME := 60.0
const NIGHT_TIME := 0.0
const STRIKE_MODE := 0
const HARVEST_MODE := 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_populate_api() and ok
	ok = await _check_range_view_flora() and ok
	ok = await _check_atmosphere_tint() and ok
	ok = await _check_view_mode_visibility() and ok
	print("fairway_flora_ok=", ok)
	quit(0 if ok else 1)


func _check_populate_api() -> bool:
	var container := Node3D.new()
	root.add_child(container)

	var mmi := FairwayFlora.populate(container)
	if mmi == null:
		print("FAIL: FairwayFlora.populate returned null")
		container.queue_free()
		return false

	var mm := mmi.multimesh
	if mm == null:
		print("FAIL: flora MultiMesh missing")
		container.queue_free()
		return false
	if mm.instance_count != FairwayFlora.INSTANCE_COUNT:
		print(
			"FAIL: expected %d flora instances, got %d"
			% [FairwayFlora.INSTANCE_COUNT, mm.instance_count]
		)
		container.queue_free()
		return false
	if not mm.use_custom_data:
		print("FAIL: flora MultiMesh should use custom data")
		container.queue_free()
		return false

	var mat := mmi.material_override as ShaderMaterial
	if mat == null or mat.shader == null:
		print("FAIL: flora material override missing shader")
		container.queue_free()
		return false

	container.queue_free()
	print("OK: populate creates %d-instance MultiMesh with custom data" % mm.instance_count)
	return true


func _check_range_view_flora() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var flora := range_view.get_node_or_null("Flora")
	if flora == null:
		print("FAIL: RangeView missing Flora node after load")
		range_view.queue_free()
		return false

	var mmi := flora.get_node_or_null("FloraMultiMesh") as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null:
		print("FAIL: FloraMultiMesh missing under Flora")
		range_view.queue_free()
		return false
	if mmi.multimesh.instance_count <= 0:
		print("FAIL: FloraMultiMesh has zero instances")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: range_view builds Flora/FloraMultiMesh on load")
	return true


func _check_atmosphere_tint() -> bool:
	var container := Node3D.new()
	root.add_child(container)
	var mmi := FairwayFlora.populate(container)
	if mmi == null:
		print("FAIL: could not populate flora for tint check")
		container.queue_free()
		return false

	var day_snap := DayNightPalette.sample_at(DAY_TIME)
	var night_snap := DayNightPalette.sample_at(NIGHT_TIME)

	FairwayFlora.apply_tint(mmi, day_snap.canvas_modulate)
	var mat := mmi.material_override as ShaderMaterial
	var day_tint: Color = mat.get_shader_parameter(&"tint")
	FairwayFlora.apply_tint(mmi, night_snap.canvas_modulate)
	var night_tint: Color = mat.get_shader_parameter(&"tint")

	if not day_tint.is_equal_approx(day_snap.canvas_modulate):
		print("FAIL: day flora tint mismatch")
		container.queue_free()
		return false
	if not night_tint.is_equal_approx(night_snap.canvas_modulate):
		print("FAIL: night flora tint mismatch")
		container.queue_free()
		return false
	if day_tint.is_equal_approx(night_tint):
		print("FAIL: day and night flora tints should differ")
		container.queue_free()
		return false

	container.queue_free()
	print("OK: flora tint follows DayNightPalette canvas_modulate")
	return true


func _check_view_mode_visibility() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._on_play_pressed()
	await process_frame
	await process_frame

	var range_view: Node3D = main.get_node("RangeView")
	var flora: Node3D = range_view.get_node_or_null("Flora")
	if flora == null:
		print("FAIL: playing range missing Flora node")
		main.queue_free()
		return false

	var controller: Node = range_view.get_node("ViewModeController")
	if controller.get("get_mode") == null or controller.call("get_mode") != STRIKE_MODE:
		print("FAIL: initial view mode should be STRIKE")
		main.queue_free()
		return false
	if not flora.visible:
		print("FAIL: flora should be visible during strike view")
		main.queue_free()
		return false

	var gs: Node = root.get_node("GameState")
	gs.bucket_remaining = 0
	gs._enter_harvest_phase()

	var end := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < end:
		if range_view.has_method("is_harvest_view_ready") and range_view.is_harvest_view_ready():
			break
		await process_frame

	if flora.visible:
		print("FAIL: flora should be hidden during harvest view")
		main.queue_free()
		return false

	main.queue_free()
	print("OK: flora hidden in harvest view, visible in strike view")
	return true
