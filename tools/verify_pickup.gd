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
	ok = _check_skip_harvest_early(gs) and ok
	ok = _check_event_bus_signals(gs) and ok
	ok = await _check_phase_integration(main, gs) and ok
	ok = await _check_harvest_sidestep(main, gs) and ok
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
	var payout: float = gs.collect_harvest_ball(Vector2(100, 120), 1)
	if gs.harvest_collected != 1:
		print("FAIL: harvest_collected expected 1, got %d" % gs.harvest_collected)
		return false
	if payout <= 0.0:
		print("FAIL: collect payout should be positive")
		return false
	gs.collect_harvest_ball(Vector2(110, 125), 2)
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
	gs.collect_harvest_ball(Vector2.ZERO, 1)
	var after_one: float = gs.currency
	if not is_equal_approx(after_one - start_currency, per_ball):
		print(
			"FAIL: per-ball payout expected %.2f, got %.2f"
			% [per_ball, after_one - start_currency]
		)
		return false
	gs.collect_harvest_ball(Vector2.ZERO, 2)
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


func _check_skip_harvest_early(gs: Node) -> bool:
	_reset(gs)
	_enter_harvest(gs)
	gs.collect_harvest_ball(Vector2.ZERO, 1)
	var partial_collected: int = gs.harvest_collected
	if partial_collected <= 0:
		print("FAIL: skip test needs partial collection")
		return false
	var before_currency: float = gs.currency
	var bonus := Economy.bucket_complete_bonus_value(gs.stats)
	gs.skip_harvest()
	if gs.current_phase != "strike":
		print("FAIL: skip_harvest should return to strike, got %s" % gs.current_phase)
		return false
	if gs.bucket_remaining != gs.bucket_capacity:
		print(
			"FAIL: skip_harvest should refill bucket to %d, got %d"
			% [gs.bucket_capacity, gs.bucket_remaining]
		)
		return false
	if not gs.has_bucket_balls():
		print("FAIL: has_bucket_balls false after skip_harvest")
		return false
	if gs.harvest_collected != 0:
		print("FAIL: harvest_collected not cleared after skip_harvest")
		return false
	if not is_equal_approx(gs.currency - before_currency, 0.0):
		print("FAIL: skip_harvest should not grant bucket-complete bonus")
		return false
	if is_equal_approx(bonus, 0.0):
		print("FAIL: skip test setup — bonus should be positive for contrast")
		return false
	print("OK: skip_harvest refills bucket without bonus")
	return true


func _check_event_bus_signals(gs: Node) -> bool:
	_reset(gs)
	var event_bus: Node = root.get_node("EventBus")
	var collected: Array = []
	var completed: Array = []
	var phases: Array = []
	var on_collected := func(_pos: Vector2, combo: int) -> void:
		collected.append(combo)
	var on_completed := func(bonus: float) -> void:
		completed.append(bonus)
	var on_phase := func(phase: String) -> void:
		phases.append(phase)
	event_bus.ball_collected.connect(on_collected)
	event_bus.bucket_completed.connect(on_completed)
	event_bus.phase_changed.connect(on_phase)

	_enter_harvest(gs)
	gs.collect_harvest_ball(Vector2(50, 80), 1)
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
	var range_view: Node2D = main.get_node("RangeView")
	var litter_parent: Node2D = range_view.get_node("Foreground/LitteredBalls")

	range_view._leave_litter_ball(Vector2(240, 160), Vector2(0.5, 0.5))
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
	click.position = range_view.get_canvas_transform() * litter.global_position
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

	# Early exit via Space — litter stays, becomes non-collectible until next harvest.
	range_view._leave_litter_ball(Vector2(300, 170), Vector2(0.5, 0.5))
	var skip_key := InputEventKey.new()
	skip_key.keycode = KEY_SPACE
	skip_key.pressed = true
	if not range_view._pickup.handle_input(skip_key):
		print("FAIL: Space skip did not finish harvest early")
		return false
	await process_frame
	if gs.current_phase != "strike":
		print("FAIL: Space skip should return to strike")
		return false
	if litter_parent.get_child_count() < 1:
		print("FAIL: skip should leave uncollected litter on fairway")
		return false
	for child in litter_parent.get_children():
		if child.get_meta("collectible", true):
			print("FAIL: litter should be non-collectible after skip")
			return false
	_enter_harvest(gs)
	await process_frame
	for child in litter_parent.get_children():
		if not child.get_meta("collectible", false):
			print("FAIL: litter should be collectible again on re-enter harvest")
			return false

	print("OK: range pickup integration")
	return true


func _check_harvest_sidestep(main: Node, gs: Node) -> bool:
	_reset(gs)
	main._on_play_pressed()
	await process_frame
	await process_frame
	var range_view: Node2D = main.get_node("RangeView")
	var home: Vector2 = range_view.golfer_strike_home()
	var offset: Vector2 = range_view.golfer_harvest_offset()
	var harvest_pos: Vector2 = home + offset

	_enter_harvest(gs)
	await process_frame
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		if range_view.golfer.position.is_equal_approx(harvest_pos):
			break
		await process_frame
	if not range_view.golfer.position.is_equal_approx(harvest_pos):
		print(
			"FAIL: harvest sidestep expected %s, got %s"
			% [harvest_pos, range_view.golfer.position]
		)
		return false
	if range_view.golfer.animation != &"idle_out_of_balls":
		print("FAIL: harvest sidestep should play idle_out_of_balls")
		return false

	gs.skip_harvest()
	await process_frame
	deadline = Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		if range_view.golfer.position.is_equal_approx(home):
			break
		await process_frame
	if not range_view.golfer.position.is_equal_approx(home):
		print(
			"FAIL: strike return expected %s, got %s"
			% [home, range_view.golfer.position]
		)
		return false

	print("OK: harvest sidestep offset %.0fpx, return to strike home" % offset.x)
	return true
