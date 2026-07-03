extends SceneTree
## Headless middle-mouse camera drag test — run:
## godot --headless --script res://tools/verify_camera_pan.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = await _test_drag_pans_camera() and ok
	ok = await _test_range_view_routes_drag() and ok
	print("camera_pan_ok=", ok)
	quit(0 if ok else 1)


func _load_autoloads() -> void:
	for script_path in [
		"res://scripts/autoload/event_bus.gd",
		"res://scripts/autoload/game_state.gd",
	]:
		var node: Node = load(script_path).new()
		if script_path.ends_with("event_bus.gd"):
			node.name = "EventBus"
		elif script_path.ends_with("game_state.gd"):
			node.name = "GameState"
		root.add_child(node)
	await process_frame


func _test_drag_pans_camera() -> bool:
	var range_view: Node3D = load("res://scenes/range/range_view.tscn").instantiate()
	root.add_child(range_view)
	await process_frame
	await process_frame

	var controller: RangeCameraController = range_view.get_node("CameraController")
	var camera: Camera3D = range_view.get_node("Camera3D")
	if controller == null or camera == null:
		print("FAIL: range view missing camera controller or camera")
		range_view.queue_free()
		return false
	if not controller.is_enabled():
		print("FAIL: camera controller should be enabled on visible range view")
		range_view.queue_free()
		return false

	var start_pos := camera.position
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = Vector2(120.0, 80.0)
	if not controller.consume_pan_drag_event(down):
		print("FAIL: middle mouse down should start drag")
		range_view.queue_free()
		return false
	if not controller.is_dragging():
		print("FAIL: controller should report dragging after middle mouse down")
		range_view.queue_free()
		return false

	var move := InputEventMouseMotion.new()
	move.position = Vector2(160.0, 110.0)
	if not controller.consume_pan_drag_event(move):
		print("FAIL: mouse motion should be consumed while dragging")
		range_view.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		print("FAIL: camera position should change after drag motion")
		range_view.queue_free()
		return false

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = Vector2(160.0, 110.0)
	if not controller.consume_pan_drag_event(up):
		print("FAIL: middle mouse up should end drag")
		range_view.queue_free()
		return false
	if controller.is_dragging():
		print("FAIL: controller should not be dragging after release")
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: drag_pans_camera")
	return true


func _test_range_view_routes_drag() -> bool:
	var range_view: Node3D = load("res://scenes/range/range_view.tscn").instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame
	await process_frame

	var camera: Camera3D = range_view.get_node("Camera3D")
	var start_pos := camera.position

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = Vector2(200.0, 100.0)
	if not range_view.consume_pan_drag_event(down):
		print("FAIL: range_view should route middle mouse down to camera drag")
		range_view.queue_free()
		return false

	var move := InputEventMouseMotion.new()
	move.position = Vector2(240.0, 130.0)
	if not range_view.consume_pan_drag_event(move):
		print("FAIL: range_view should route drag motion")
		range_view.queue_free()
		return false
	if camera.position.is_equal_approx(start_pos):
		print("FAIL: routed drag should move camera")
		range_view.queue_free()
		return false

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = Vector2(240.0, 130.0)
	range_view.consume_pan_drag_event(up)

	range_view.queue_free()
	print("OK: range_view_routes_drag")
	return true
