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
	ok = await _test_exit_harvest_restores_arrow() and ok
	ok = await _test_stale_pan_clears_without_mouse_button() and ok
	ok = await _test_complete_harvest_restores_arrow() and ok
	print("cursor_ok=", ok)
	quit(0 if ok else 1)


func _spawn_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	return main


func _start_playing(main: Node) -> void:
	if main.has_method("_on_play_transition_started"):
		main._on_play_transition_started()
	main._on_play_pressed()


func _enter_harvest(gs: Node) -> void:
	gs.bucket_remaining = 0
	gs.try_enter_harvest()


func _wait_harvest_view(main: Node, timeout_ms: int = 2000) -> void:
	var end := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < end:
		var iso_view: Node = main.get_node_or_null("IsoView")
		if (
			iso_view != null
			and iso_view.has_method("is_harvest_view_ready")
			and iso_view.is_harvest_view_ready()
		):
			return
		var range_view: Node = main.get_node_or_null("RangeView")
		if (
			range_view != null
			and range_view.has_method("is_harvest_view_ready")
			and range_view.is_harvest_view_ready()
		):
			return
		await process_frame


func _cleanup(main: Node) -> void:
	CursorManager.set_pan_dragging(false)
	CursorManager.refresh()
	main.queue_free()
	await process_frame


func _test_strike_arrow() -> bool:
	var main: Node = await _spawn_main()
	if CursorManager.debug_applied_kind() != &"arrow":
		print("FAIL: strike boot should apply arrow cursor")
		await _cleanup(main)
		return false
	_start_playing(main)
	await process_frame
	await process_frame
	if CursorManager.debug_applied_kind() != &"arrow":
		print("FAIL: strike gameplay should keep arrow cursor")
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: strike_arrow")
	return true


func _test_harvest_before_view_ready() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	# Headless transitions complete instantly; force view-not-ready to test resolver.
	CursorManager.debug_set_harvest_view_ready(func(): return false)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"arrow":
		print("FAIL: harvest phase before ortho view ready should stay arrow")
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: harvest_before_view_ready")
	return true


func _test_collect_range_picker_when_view_ready() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	await _wait_harvest_view(main)
	CursorManager.debug_set_harvest_view_ready(main._is_harvest_view_ready)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: collect mode with harvest view ready should show range picker cursor")
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: collect_range_picker_when_view_ready")
	return true


func _test_pan_grab_overrides_range_picker() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	await _wait_harvest_view(main)
	CursorManager.debug_set_harvest_view_ready(main._is_harvest_view_ready)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: pre-pan setup should be range picker cursor")
		await _cleanup(main)
		return false

	CursorManager.set_pan_dragging(true)
	if CursorManager.debug_applied_kind() != &"grab":
		print("FAIL: pan drag should override to grab cursor")
		await _cleanup(main)
		return false
	CursorManager.set_pan_dragging(false)
	await _cleanup(main)
	print("OK: pan_grab_overrides_range_picker")
	return true


func _test_pan_end_restores_range_picker() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	await _wait_harvest_view(main)
	CursorManager.debug_set_harvest_view_ready(main._is_harvest_view_ready)
	CursorManager.refresh()
	CursorManager.set_pan_dragging(true)
	CursorManager.set_pan_dragging(false)
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: ending pan drag should restore range picker in collect mode")
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: pan_end_restores_range_picker")
	return true


func _test_exit_harvest_restores_arrow() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	await _wait_harvest_view(main)
	CursorManager.debug_set_harvest_view_ready(main._is_harvest_view_ready)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: pre-exit should be range picker")
		await _cleanup(main)
		return false

	gs.exit_harvest_early()
	await process_frame
	await process_frame
	if CursorManager.debug_applied_kind() != &"arrow":
		print(
			"FAIL: exit harvest should restore arrow, got %s"
			% String(CursorManager.debug_applied_kind())
		)
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: exit_harvest_restores_arrow")
	return true


func _test_stale_pan_clears_without_mouse_button() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	_enter_harvest(gs)
	await _wait_harvest_view(main)
	CursorManager.debug_set_harvest_view_ready(main._is_harvest_view_ready)
	CursorManager.set_pan_dragging(true)
	if CursorManager.debug_applied_kind() != &"grab":
		print("FAIL: stale-pan setup should be grab")
		await _cleanup(main)
		return false

	## Simulate missed mouse-up: pan flag latched, button not held.
	CursorManager.refresh()
	if CursorManager.debug_pan_dragging():
		print("FAIL: refresh should clear pan when mouse button is up")
		await _cleanup(main)
		return false
	if CursorManager.debug_applied_kind() != &"range_picker":
		print(
			"FAIL: clearing stale pan should restore range picker, got %s"
			% String(CursorManager.debug_applied_kind())
		)
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: stale_pan_clears_without_mouse_button")
	return true


func _test_complete_harvest_restores_arrow() -> bool:
	var main: Node = await _spawn_main()
	_start_playing(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	gs.bucket_capacity = 2
	gs.bucket_remaining = 0
	gs.harvest_stash = 0
	gs.pending_vanish_collects = 0
	gs.try_enter_harvest()
	await _wait_harvest_view(main)
	CursorManager.debug_set_harvest_view_ready(main._is_harvest_view_ready)
	CursorManager.refresh()
	if CursorManager.debug_applied_kind() != &"range_picker":
		print("FAIL: complete-harvest setup should be range picker")
		await _cleanup(main)
		return false

	gs.collect_harvest_ball(Vector3.ZERO, 1)
	gs.complete_harvest(1)
	await process_frame
	await process_frame
	if CursorManager.debug_applied_kind() != &"arrow":
		print(
			"FAIL: completing harvest should restore arrow, got %s"
			% String(CursorManager.debug_applied_kind())
		)
		await _cleanup(main)
		return false
	await _cleanup(main)
	print("OK: complete_harvest_restores_arrow")
	return true
