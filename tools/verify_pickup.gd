extends SceneTree
## Headless pickup / harvest phase test — run:
## godot --headless --script res://tools/verify_pickup.gd

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
	ok = _check_harvest_trigger(gs) and ok
	ok = _check_collect_increments(gs) and ok
	ok = _check_economy_grants(gs) and ok
	ok = _check_combo_logic() and ok
	ok = _check_bucket_refill_and_strike(gs) and ok
	ok = await _check_space_does_not_skip_harvest(main, gs) and ok
	ok = _check_event_bus_signals(gs) and ok
	ok = await _check_phase_integration(main, gs) and ok
	ok = await _check_harvest_idle_at_home(main, gs) and ok
	ok = await _check_hit_mode_during_harvest(main, gs) and ok
	_cleanup_save()
	print("pickup_ok=", ok)
	quit(0 if ok else 1)


func _cleanup_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")


func _reset(gs: Node) -> void:
	gs.reset_to_fresh()


func _enter_harvest(gs: Node) -> void:
	gs.bucket_remaining = 0
	gs._enter_harvest_phase()


func _check_harvest_trigger(gs: Node) -> bool:
	_reset(gs)
	var before_phase: String = gs.current_phase
	gs.bucket_remaining = 1
	if not gs.consume_bucket_ball():
		print("FAIL: consume_bucket_ball returned false with 1 remaining")
		return false
	if gs.current_phase != "harvest":
		print("FAIL: expected harvest phase after last swing, got %s" % gs.current_phase)
		return false
	if gs.harvest_collected != 0:
		print("FAIL: harvest_collected should start at 0")
		return false
	if gs.has_bucket_balls():
		print("FAIL: has_bucket_balls true during harvest")
		return false
	print("OK: bucket 0 triggers harvest phase (was %s)" % before_phase)
	return true


func _check_collect_increments(gs: Node) -> bool:
	_reset(gs)
	_enter_harvest(gs)
	var payout: float = gs.collect_harvest_ball(Vector3(1.0, 0.0, -5.0), 1)
	if gs.harvest_collected != 1:
		print("FAIL: harvest_collected expected 1, got %d" % gs.harvest_collected)
		return false
	if payout <= 0.0:
		print("FAIL: collect payout should be positive")
		return false
	gs.collect_harvest_ball(Vector3(1.1, 0.0, -5.5), 2)
	if gs.harvest_collected != 2:
		print("FAIL: harvest_collected expected 2, got %d" % gs.harvest_collected)
		return false
	print("OK: collect increments harvest_collected")
	return true


func _check_economy_grants(gs: Node) -> bool:
	_reset(gs)
	_enter_harvest(gs)
	var start_currency: float = gs.currency
	var per_ball := Economy.pickup_per_ball_value(gs.stats)
	var combo2 := Economy.resolve_pickup_ball_payout(2, gs.stats)
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	var after_one: float = gs.currency
	if not is_equal_approx(after_one - start_currency, per_ball):
		print(
			"FAIL: per-ball payout expected %.2f, got %.2f"
			% [per_ball, after_one - start_currency]
		)
		return false
	gs.collect_harvest_ball(Vector3.ZERO, 2)
	if not is_equal_approx(gs.currency - after_one, combo2):
		print("FAIL: combo payout mismatch for tier 2")
		return false
	var bonus := Economy.bucket_complete_bonus_value(gs.stats)
	gs.harvest_collected = gs.bucket_capacity - 1
	var before_complete: float = gs.currency
	gs.complete_harvest(1)
	if not is_equal_approx(gs.currency - before_complete, bonus):
		print("FAIL: bucket complete bonus expected %.2f" % bonus)
		return false
	print("OK: pickup and bucket bonus economy grants")
	return true


func _check_combo_logic() -> bool:
	if not is_equal_approx(Economy.combo_multiplier(1), 1.0):
		print("FAIL: combo tier 1 mult should be 1.0")
		return false
	if not is_equal_approx(Economy.combo_multiplier(2), 1.1):
		print("FAIL: combo tier 2 mult should be 1.1")
		return false
	if not is_equal_approx(Economy.combo_multiplier(4), 1.3):
		print("FAIL: combo tier 4 mult should be 1.3")
		return false
	print("OK: combo multiplier tiers")
	return true


func _check_bucket_refill_and_strike(gs: Node) -> bool:
	_reset(gs)
	_enter_harvest(gs)
	gs.harvest_collected = gs.bucket_capacity
	var bonus: float = gs.complete_harvest(2)
	if bonus <= 0.0:
		print("FAIL: complete_harvest bonus should be positive")
		return false
	if gs.current_phase != "strike":
		print("FAIL: expected strike phase after harvest complete")
		return false
	if gs.bucket_remaining != gs.bucket_capacity:
		print(
			"FAIL: bucket refill expected %d, got %d"
			% [gs.bucket_capacity, gs.bucket_remaining]
		)
		return false
	if not gs.has_bucket_balls():
		print("FAIL: has_bucket_balls false after refill")
		return false
	if gs.harvest_collected != 0:
		print("FAIL: harvest_collected not cleared after complete")
		return false
	print("OK: bucket refilled and strike phase restored")
	return true


func _check_space_does_not_skip_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)
	await process_frame
	if gs.current_phase != "harvest":
		print("FAIL: space test expected harvest phase")
		return false
	_send_space(range_view, true)
	await process_frame
	_send_space(range_view, false)
	await process_frame
	if gs.current_phase != "harvest":
		print("FAIL: Space should not exit harvest phase, got %s" % gs.current_phase)
		return false
	if gs.has_bucket_balls():
		print("FAIL: Space should not refill bucket during harvest")
		return false
	if gs.bucket_remaining != 0:
		print("FAIL: Space changed bucket_remaining during harvest")
		return false
	print("OK: Space does not skip harvest or refill bucket")
	return true


func _send_space(target: Node, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	target._unhandled_input(event)


func _check_event_bus_signals(gs: Node) -> bool:
	_reset(gs)
	var event_bus: Node = root.get_node("EventBus")
	var collected: Array = []
	var completed: Array = []
	var phases: Array = []
	var on_collected := func(_pos: Vector3, combo: int) -> void:
		collected.append(combo)
	var on_completed := func(bonus: float) -> void:
		completed.append(bonus)
	var on_phase := func(phase: String) -> void:
		phases.append(phase)
	event_bus.ball_collected.connect(on_collected)
	event_bus.bucket_completed.connect(on_completed)
	event_bus.phase_changed.connect(on_phase)

	_enter_harvest(gs)
	gs.collect_harvest_ball(Vector3(0.5, 0.0, -8.0), 1)
	gs.harvest_collected = gs.bucket_capacity
	gs.complete_harvest(1)

	event_bus.ball_collected.disconnect(on_collected)
	event_bus.bucket_completed.disconnect(on_completed)
	event_bus.phase_changed.disconnect(on_phase)

	if collected.is_empty():
		print("FAIL: ball_collected not emitted")
		return false
	if completed.is_empty():
		print("FAIL: bucket_completed not emitted")
		return false
	if not phases.has("strike"):
		print("FAIL: phase_changed strike not emitted after harvest")
		return false
	print("OK: EventBus pickup signals")
	return true


func _check_phase_integration(main: Node, gs: Node) -> bool:
	_reset(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	var litter_parent: Node3D = range_view.get_node("Foreground/LitteredBalls")

	range_view._leave_litter_ball(Vector3(0.3, 0.0, -8.0), Vector3(1.0, 1.0, 1.0))
	if litter_parent.get_child_count() != 1:
		print("FAIL: litter spawn failed")
		return false
	var litter: Node = litter_parent.get_child(0)
	if not litter.get_meta("collectible", false):
		print("FAIL: litter missing collectible meta")
		return false

	_enter_harvest(gs)
	await process_frame
	if range_view._pickup == null:
		print("FAIL: pickup controller not initialized")
		return false
	if not range_view._pickup.is_active():
		print("FAIL: pickup controller inactive during harvest")
		return false

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = range_view.get_flight_camera().unproject_position(litter.global_position)
	if not range_view._pickup.handle_input(click):
		print("FAIL: pickup click did not collect litter")
		return false
	await process_frame
	await process_frame
	var end := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < end and litter_parent.get_child_count() > 0:
		await process_frame
	if gs.harvest_collected < 1:
		print("FAIL: integration collect did not increment harvest")
		return false

	print("OK: range pickup integration")
	return true


func _check_harvest_idle_at_home(main: Node, gs: Node) -> bool:
	_reset(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	var home: Vector3 = range_view.golfer_strike_home()

	_enter_harvest(gs)
	await process_frame
	await process_frame
	if not range_view.golfer.position.is_equal_approx(home):
		print(
			"FAIL: harvest idle expected home %s, got %s"
			% [home, range_view.golfer.position]
		)
		return false
	if range_view.golfer.animation != &"idle_out_of_balls":
		print("FAIL: harvest idle should play idle_out_of_balls")
		return false

	gs.skip_harvest()
	await process_frame
	if not range_view.golfer.position.is_equal_approx(home):
		print(
			"FAIL: strike return expected home %s, got %s"
			% [home, range_view.golfer.position]
		)
		return false

	print("OK: harvest idle stays at home, returns to idle on strike")
	return true


func _check_hit_mode_during_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")

	_enter_harvest(gs)
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	if gs.harvest_collected != 1:
		print("FAIL: hit mode test expected 1 collected ball")
		return false
	if gs.has_bucket_balls():
		print("FAIL: collect mode should not allow bucket hits")
		return false

	gs.set_range_action_mode(gs.ACTION_HIT)
	await process_frame
	if not gs.has_bucket_balls():
		print("FAIL: hit mode should allow swings with collected balls")
		return false

	range_view._swing._last_swing_msec = Time.get_ticks_msec() - int(gs.stats.swing_cooldown_ms) - 1
	range_view._swing.start_charge()
	if not range_view._swing.is_charging():
		print("FAIL: hit mode start_charge did not begin swing")
		return false
	await process_frame
	range_view._swing.release_strike()
	await process_frame
	if gs.harvest_collected != 0:
		print(
			"FAIL: swing during harvest hit mode should consume collected ball, got %d"
			% gs.harvest_collected
		)
		return false
	if gs.current_phase != "harvest":
		print("FAIL: harvest hit swing should stay in harvest phase")
		return false
	if gs.has_bucket_balls():
		print("FAIL: empty harvest hit bucket should not allow swings")
		return false
	if gs.range_action_mode != gs.ACTION_COLLECT:
		print("FAIL: empty harvest hit bucket should auto-return to collect mode")
		return false

	print("OK: hit mode swings consume collected balls during harvest")
	return true
