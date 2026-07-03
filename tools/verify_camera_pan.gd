extends SceneTree
## Headless middle-mouse camera drag test — run:
## godot --headless --path . --script res://tools/verify_camera_pan.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _test_drag_pans_camera() and ok
	ok = await _test_range_view_routes_drag() and ok
	print("camera_pan_ok=", ok)
	quit(0 if ok else 1)


func _spawn_playing_range() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._on_play_pressed()
	return main


func _test_drag_pans_camera() -> bool:
	var main: Node = _spawn_playing_range()
	await process_frame
	await process_frame

	var range_view: Node3D = main.get_node("RangeView")
	var controller: Node = range_view.get_node("CameraController")
	var camera: Camera3D = range_view.get_node("Camera3D")
	if controller == null or camera == null:
		print("FAIL: range view missing camera controller or camera")
		main.queue_free()
		return false
	if not controller.is_enabled():
		print("FAIL: camera controller should be enabled during gameplay")
		main.queue_free()
		return false

	var start_pos := camera.position
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = Vector2(120.0, 80.0)
	if not controller.consume_pan_drag_event(down):
		print("FAIL: middle mouse down should start drag")
		main.queue_free()
		return false
	if not controller.is_dragging():
		print("FAIL: controller should report dragging after middle mouse down")
		main.queue_free()
		return false

	var move := InputEventMouseMotion.new()
	move.position = Vector2(160.0, 110.0)
	if not controller.consume_pan_drag_event(move):
		print("FAIL: mouse motion should be consumed while dragging")
		main.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		print("FAIL: camera position should change after drag motion")
		main.queue_free()
		return false

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = Vector2(160.0, 110.0)
	if not controller.consume_pan_drag_event(up):
		print("FAIL: middle mouse up should end drag")
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

	var range_view: Node3D = main.get_node("RangeView")
	var camera: Camera3D = range_view.get_node("Camera3D")
	var start_pos := camera.position

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = Vector2(200.0, 100.0)
	if not range_view.consume_pan_drag_event(down):
		print("FAIL: range_view should route middle mouse down to camera drag")
		main.queue_free()
		return false

	var move := InputEventMouseMotion.new()
	move.position = Vector2(240.0, 130.0)
	if not range_view.consume_pan_drag_event(move):
		print("FAIL: range_view should route drag motion")
		main.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		print("FAIL: routed drag should move camera")
		main.queue_free()
		return false

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = Vector2(240.0, 130.0)
	range_view.consume_pan_drag_event(up)

	main.queue_free()
	print("OK: range_view_routes_drag")
	return true
