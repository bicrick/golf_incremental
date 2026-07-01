extends SceneTree
## Headless bucket strike gate test — run:
## godot --headless --script res://tools/verify_bucket.gd

const CAPACITY := Balance.BUCKET_CAPACITY_DEFAULT


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_cleanup_save()

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		quit(1)
		return

	var ok := true
	ok = _check_initial_capacity(gs) and ok
	ok = await _check_decrement_on_resolve(gs) and ok
	ok = _check_block_at_zero(gs) and ok
	ok = _check_bucket_changed_signal(gs) and ok
	ok = _check_save_roundtrip(gs) and ok
	ok = _check_load_refills_empty_bucket(gs) and ok
	ok = await _check_tee_ball_visibility(main, gs) and ok
	ok = await _check_space_does_not_refill(main, gs) and ok
	_cleanup_save()
	print("bucket_ok=", ok)
	quit(0 if ok else 1)


func _cleanup_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")


func _reset_bucket(gs: Node) -> void:
	gs.reset_to_fresh()


func _check_initial_capacity(gs: Node) -> bool:
	_reset_bucket(gs)
	if gs.bucket_capacity != CAPACITY:
		print("FAIL: bucket_capacity expected %d, got %d" % [CAPACITY, gs.bucket_capacity])
		return false
	if gs.bucket_remaining != CAPACITY:
		print("FAIL: bucket_remaining expected %d, got %d" % [CAPACITY, gs.bucket_remaining])
		return false
	print("OK: initial bucket %d/%d" % [gs.bucket_remaining, gs.bucket_capacity])
	return true


func _check_decrement_on_resolve(gs: Node) -> bool:
	_reset_bucket(gs)
	var swing: RefCounted = _make_swing()
	if swing == null:
		return false
	await _wait_for_swing_ready(swing, gs.stats)
	swing.start_charge()
	if not swing.is_charging():
		print("FAIL: start_charge did not enter charging state")
		return false
	swing.release_strike()
	if gs.bucket_remaining != CAPACITY - 1:
		print(
			"FAIL: after one swing bucket_remaining expected %d, got %d"
			% [CAPACITY - 1, gs.bucket_remaining]
		)
		return false
	print("OK: bucket decrements to %d after resolve" % gs.bucket_remaining)
	return true


func _check_block_at_zero(gs: Node) -> bool:
	_reset_bucket(gs)
	gs.bucket_remaining = 0
	var swing: RefCounted = _make_swing()
	if swing == null:
		return false
	swing.start_charge()
	if swing.is_charging():
		print("FAIL: start_charge allowed swing with empty bucket")
		return false
	swing.release_strike()
	if gs.bucket_remaining != 0:
		print("FAIL: release_strike changed empty bucket count")
		return false
	print("OK: swing blocked at bucket 0")
	return true


func _check_bucket_changed_signal(gs: Node) -> bool:
	_reset_bucket(gs)
	var event_bus: Node = root.get_node("EventBus")
	var emissions: Array = []
	var handler := func(count: int, capacity: int) -> void:
		emissions.append({"count": count, "capacity": capacity})
	event_bus.bucket_changed.connect(handler)

	gs.consume_bucket_ball()

	event_bus.bucket_changed.disconnect(handler)

	if emissions.is_empty():
		print("FAIL: bucket_changed not emitted on consume")
		return false
	var last: Dictionary = emissions[-1]
	if last["count"] != CAPACITY - 1 or last["capacity"] != CAPACITY:
		print("FAIL: bucket_changed payload %s" % last)
		return false
	print("OK: bucket_changed emitted (%d, %d)" % [last["count"], last["capacity"]])
	return true


func _check_save_roundtrip(gs: Node) -> bool:
	_reset_bucket(gs)
	var save_manager: Node = root.get_node("SaveManager")
	gs.bucket_remaining = 3
	save_manager.save_game()
	gs.bucket_remaining = -1
	save_manager.load_game()
	gs._ensure_bucket_initialized()
	if gs.bucket_remaining != 3:
		print("FAIL: save roundtrip bucket_remaining expected 3, got %d" % gs.bucket_remaining)
		return false
	print("OK: bucket_remaining persists through save/load")
	return true


func _check_load_refills_empty_bucket(gs: Node) -> bool:
	_reset_bucket(gs)
	var save_manager: Node = root.get_node("SaveManager")
	gs.bucket_remaining = 0
	save_manager.save_game()
	save_manager.load_game()
	gs._ensure_bucket_initialized()
	if gs.bucket_remaining != CAPACITY:
		print(
			"FAIL: load with empty bucket expected %d, got %d"
			% [CAPACITY, gs.bucket_remaining]
		)
		return false
	if not gs.has_bucket_balls():
		print("FAIL: has_bucket_balls false after load refill")
		return false
	print("OK: empty bucket refilled to %d on load" % gs.bucket_remaining)
	return true


func _check_swing_integration(main: Node, gs: Node) -> bool:
	_reset_bucket(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node = main.get_node("RangeView")
	await _wait_for_swing_ready(range_view._swing, gs.stats)
	var before: int = gs.bucket_remaining
	_send_space(range_view, true)
	await process_frame
	await process_frame
	_send_space(range_view, false)
	await process_frame
	await process_frame
	if gs.bucket_remaining != before - 1:
		print(
			"FAIL: range_view swing bucket expected %d, got %d"
			% [before - 1, gs.bucket_remaining]
		)
		return false
	print("OK: range_view swing integration")
	return true


func _check_space_does_not_refill(main: Node, gs: Node) -> bool:
	_reset_bucket(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node = main.get_node("RangeView")
	gs.bucket_remaining = 0
	gs._enter_harvest_phase()
	await process_frame
	_send_space(range_view, true)
	await process_frame
	_send_space(range_view, false)
	await process_frame
	if gs.has_bucket_balls():
		print("FAIL: Space refilled empty bucket during harvest")
		return false
	if gs.current_phase != "harvest":
		print("FAIL: Space should not exit harvest, got %s" % gs.current_phase)
		return false
	print("OK: Space does not refill bucket during harvest")
	return true


func _check_tee_ball_visibility(main: Node, gs: Node) -> bool:
	_reset_bucket(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	await _wait_for_tee_ball_ready(range_view, gs.stats)
	var ball: Node3D = range_view.get_node("Foreground/Ball")
	if not ball.visible:
		print("FAIL: tee ball should be visible with full bucket")
		return false

	var event_bus: Node = root.get_node("EventBus")
	gs.bucket_remaining = 0
	event_bus.bucket_changed.emit(gs.bucket_remaining, gs.bucket_capacity)
	await process_frame
	if ball.visible:
		print("FAIL: tee ball visible with empty bucket")
		return false
	if range_view._ball_at_tee:
		print("FAIL: _ball_at_tee true with empty bucket")
		return false

	gs.reset_to_fresh()
	await process_frame
	await _wait_for_swing_ready(range_view._swing, gs.stats)
	if not ball.visible:
		print("FAIL: tee ball should respawn after bucket refill")
		return false
	if not range_view._ball_at_tee:
		print("FAIL: _ball_at_tee false after bucket refill")
		return false
	print("OK: tee ball hidden at 0, visible when bucket has balls")
	return true


func _make_swing() -> RefCounted:
	var swing_script: Script = load("res://scripts/game/swing.gd")
	if swing_script == null:
		print("FAIL: could not load swing.gd")
		return null
	return swing_script.new()


func _send_space(target: Node, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	target._unhandled_input(event)


func _wait_for_tee_ball_ready(range_view: Node3D, stats: PlayerStats) -> void:
	var end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < end:
		await process_frame
		if (
			not range_view._ball_in_flight
			and range_view._ball_at_tee
			and range_view.get_node("Foreground/Ball").visible
		):
			return


func _wait_for_swing_ready(swing: RefCounted, stats: PlayerStats) -> void:
	var end := Time.get_ticks_msec() + int(stats.swing_cooldown_ms) + 50
	while Time.get_ticks_msec() < end:
		await process_frame
		if swing.can_swing(stats):
			return
