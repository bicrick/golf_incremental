extends SceneTree
## Headless cursor resolver test — run:
## godot --headless --path . --script res://tools/verify_cursor.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _test_strike_arrow() and ok
	ok = await _test_harvest_before_view_ready() and ok
	ok = await _test_collect_range_picker_when_view_ready() and ok
	ok = await _test_pan_grab_overrides_range_picker() and ok
	ok = await _test_pan_end_restores_range_picker() and ok
	print("cursor_ok=", ok)
	quit(0 if ok else 1)


func _spawn_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	return main


func _enter_harvest(gs: Node) -> void:
	gs.bucket_remaining = 0
	gs._enter_harvest_phase()


func _wait_harvest_view(range_view: Node, timeout_ms: int = 2000) -> void:
	var end := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < end:
		if range_view.has_method("is_harvest_view_ready") and range_view.is_harvest_view_ready():
			return
		await process_frame


func _test_strike_arrow() -> bool:
	var main: Node = await _spawn_main()
	if CursorManager.debug_applied_kind() != &"arrow":
		print("FAIL: strike boot should apply arrow cursor")
		main.queue_free()
		return false
	main._on_play_pressed()
	await process_frame
	await process_frame
	if CursorManager.debug_applied_kind() != &"arrow":
		print("FAIL: strike gameplay should keep arrow cursor")
		main.queue_free()
		return false
	main.queue_free()
	print("OK: strike_arrow")
	return true


func _test_harvest_before_view_ready() -> bool:
	var main: Node = await _spawn_main()
	main._on_play_pressed()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	# Headless transitions complete instantly; force view-not-ready to test resolver.
	CursorManager.debug_set_harvest_view_ready(func(): return false)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"arrow":
		print("FAIL: harvest phase before ortho view ready should stay arrow")
		main.queue_free()
		return false
	main.queue_free()
	print("OK: harvest_before_view_ready")
	return true


func _test_collect_range_picker_when_view_ready() -> bool:
	var main: Node = await _spawn_main()
	main._on_play_pressed()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await _wait_harvest_view(range_view)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: collect mode with harvest view ready should show range picker cursor")
		main.queue_free()
		return false
	main.queue_free()
	print("OK: collect_range_picker_when_view_ready")
	return true


func _test_pan_grab_overrides_range_picker() -> bool:
	var main: Node = await _spawn_main()
	main._on_play_pressed()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await _wait_harvest_view(range_view)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: pre-pan setup should be range picker cursor")
		main.queue_free()
		return false

	CursorManager.set_pan_dragging(true)
	if CursorManager.debug_applied_kind() != &"grab":
		print("FAIL: pan drag should override to grab cursor")
		main.queue_free()
		return false
	main.queue_free()
	print("OK: pan_grab_overrides_range_picker")
	return true


func _test_pan_end_restores_range_picker() -> bool:
	var main: Node = await _spawn_main()
	main._on_play_pressed()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await _wait_harvest_view(range_view)
	CursorManager.refresh()
	CursorManager.set_pan_dragging(true)
	CursorManager.set_pan_dragging(false)
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: ending pan drag should restore range picker in collect mode")
		main.queue_free()
		return false
	main.queue_free()
	print("OK: pan_end_restores_range_picker")
	return true
