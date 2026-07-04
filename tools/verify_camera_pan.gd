extends SceneTree
## Headless left-click camera drag test — run:
## godot --headless --path . --script res://tools/verify_camera_pan.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _test_strike_disables_pan() and ok
	ok = await _test_click_does_not_pan() and ok
	ok = await _test_drag_pans_camera() and ok
	ok = await _test_range_view_routes_drag() and ok
	print("camera_pan_ok=", ok)
	quit(0 if ok else 1)


func _spawn_playing_range() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._on_play_pressed()
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


func _left_down(position: Vector2) -> InputEventMouseButton:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	return down


func _left_up(position: Vector2) -> InputEventMouseButton:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	return up


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var move := InputEventMouseMotion.new()
	move.position = position
	return move


func _test_strike_disables_pan() -> bool:
	var main: Node = _spawn_playing_range()
	await process_frame
	await process_frame

	var range_view: Node3D = main.get_node("RangeView")
	var controller: Node = range_view.get_node("CameraController")
	if controller == null:
		print("FAIL: range view missing camera controller")
		main.queue_free()
		return false
	if controller.is_enabled():
		print("FAIL: camera controller should be disabled during strike")
		main.queue_free()
		return false

	if range_view.consume_pan_drag_event(_left_down(Vector2(120.0, 80.0))):
		print("FAIL: strike phase should not consume pan drag")
		main.queue_free()
		return false

	main.queue_free()
	print("OK: strike_disables_pan")
	return true


func _test_click_does_not_pan() -> bool:
	var main: Node = _spawn_playing_range()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await _wait_harvest_view(range_view)

	var controller: Node = range_view.get_node("CameraController")
	var camera: Camera3D = range_view.get_node("Camera3D")
	if controller == null or camera == null:
		print("FAIL: range view missing camera controller or camera")
		main.queue_free()
		return false

	var start_pos := camera.position
	var origin := Vector2(120.0, 80.0)
	if not controller.consume_pan_drag_event(_left_down(origin)):
		print("FAIL: left mouse down should be consumed while pending drag")
		main.queue_free()
		return false
	if controller.is_dragging():
		print("FAIL: controller should not be dragging immediately after press")
		main.queue_free()
		return false

	var wiggle := origin + Vector2(2.0, 2.0)
	if not controller.consume_pan_drag_event(_mouse_motion(wiggle)):
		print("FAIL: sub-threshold motion should stay pending")
		main.queue_free()
		return false
	if controller.is_dragging():
		print("FAIL: sub-threshold motion should not start drag")
		main.queue_free()
		return false

	if controller.consume_pan_drag_event(_left_up(wiggle)):
		print("FAIL: click release should not be consumed by pan controller")
		main.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		pass
	else:
		print("FAIL: click path should not move camera")
		main.queue_free()
		return false

	main.queue_free()
	print("OK: click_does_not_pan")
	return true


func _test_drag_pans_camera() -> bool:
	var main: Node = _spawn_playing_range()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await _wait_harvest_view(range_view)

	var controller: Node = range_view.get_node("CameraController")
	var camera: Camera3D = range_view.get_node("Camera3D")
	if controller == null or camera == null:
		print("FAIL: range view missing camera controller or camera")
		main.queue_free()
		return false
	if not controller.is_enabled():
		print("FAIL: camera controller should be enabled during harvest")
		main.queue_free()
		return false

	var start_pos := camera.position
	if not controller.consume_pan_drag_event(_left_down(Vector2(120.0, 80.0))):
		print("FAIL: left mouse down should start pending drag")
		main.queue_free()
		return false
	if controller.is_dragging():
		print("FAIL: controller should not be dragging until threshold exceeded")
		main.queue_free()
		return false

	if not controller.consume_pan_drag_event(_mouse_motion(Vector2(160.0, 110.0))):
		print("FAIL: mouse motion should be consumed while dragging")
		main.queue_free()
		return false
	if not controller.is_dragging():
		print("FAIL: controller should report dragging after threshold motion")
		main.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		print("FAIL: camera position should change after drag motion")
		main.queue_free()
		return false

	if not controller.consume_pan_drag_event(_left_up(Vector2(160.0, 110.0))):
		print("FAIL: left mouse up should end drag")
		main.queue_free()
		return false
	if controller.is_dragging():
		print("FAIL: controller should not be dragging after release")
		main.queue_free()
		return false

	main.queue_free()
	print("OK: drag_pans_camera")
	return true


func _test_range_view_routes_drag() -> bool:
	var main: Node = _spawn_playing_range()
	await process_frame
	await process_frame

	var gs: Node = root.get_node("GameState")
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await _wait_harvest_view(range_view)

	var camera: Camera3D = range_view.get_node("Camera3D")
	var start_pos := camera.position

	if not range_view.consume_pan_drag_event(_left_down(Vector2(200.0, 100.0))):
		print("FAIL: range_view should route left mouse down to camera drag")
		main.queue_free()
		return false

	if not range_view.consume_pan_drag_event(_mouse_motion(Vector2(240.0, 130.0))):
		print("FAIL: range_view should route drag motion")
		main.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		print("FAIL: routed drag should move camera")
		main.queue_free()
		return false

	range_view.consume_pan_drag_event(_left_up(Vector2(240.0, 130.0)))

	main.queue_free()
	print("OK: range_view_routes_drag")
	return true
