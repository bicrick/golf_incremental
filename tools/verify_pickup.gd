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
	ok = _check_voluntary_entry_and_early_exit(gs) and ok
	ok = _check_harvest_display_shows_inventory(gs) and ok
	ok = _check_harvest_target_accounts_for_stash(gs) and ok
	ok = _check_collect_increments(gs) and ok
	ok = _check_free_harvest_credit_no_payout(gs) and ok
	ok = _check_return_all_balls_free_full_bucket(gs) and ok
	ok = _check_economy_grants(gs) and ok
	ok = _check_currency_changed_not_stats(gs) and ok
	ok = _check_combo_logic() and ok
	ok = _check_vanish_auto_collect(gs) and ok
	ok = _check_bucket_refill_and_strike(gs) and ok
	ok = await _check_space_exits_harvest(main, gs) and ok
	ok = _check_event_bus_signals(gs) and ok
	ok = await _check_phase_integration(main, gs) and ok
	ok = await _check_harvest_idle_at_home(main, gs) and ok
	ok = await _check_no_swing_during_harvest(main, gs) and ok
	ok = await _check_harvest_exit_ignores_leftover_press(main, gs) and ok
	ok = await _check_bucket_counter_exits_harvest(main, gs) and ok
	ok = await _check_background_click_enters_harvest(main, gs) and ok
	ok = await _check_empty_click_does_not_exit_harvest(main, gs) and ok
	ok = await _check_mid_flight_view_switch_and_pickup_gate(main, gs) and ok
	ok = await _check_combo_interrupted_by_swing(main, gs) and ok
	_cleanup_save()
	print("pickup_ok=", ok)
	quit(0 if ok else 1)


func _cleanup_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")


func _reset(gs: Node) -> void:
	gs.reset_to_fresh()
	## Pickup input tests are not tutorial coverage — keep dialogue off so Space /
	## background click reach RangeView.
	gs.tutorial_completed = true
	gs.tutorial_progress = 10


func _enter_harvest(gs: Node) -> void:
	gs.bucket_remaining = 0
	gs.try_enter_harvest()


func _start_playing(main: Node) -> void:
	## Play fade shows the range before title hide — verifies must match that order.
	var gs: Node = root.get_node("GameState")
	gs.tutorial_completed = true
	gs.tutorial_progress = 10
	if main.has_method("_on_play_transition_started"):
		main._on_play_transition_started()
	main._on_play_pressed()
	_dismiss_tutorial_overlay(main)


func _dismiss_tutorial_overlay(main: Node) -> void:
	## Welcome-back / residual dialogue blocks Space and background collect clicks.
	var overlay := main.get_node_or_null("UI/UIRoot/TutorialOverlay")
	if overlay == null:
		return
	var box = overlay.get_node_or_null("ThoughtBox")
	if box == null:
		return
	if box.has_method("hide_thought"):
		box.hide_thought()
	if box.has_signal("dismissed"):
		box.dismissed.emit()


func _wait_harvest_view(range_view: Node, timeout_ms: int = 2000) -> void:
	var end := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < end:
		if range_view.has_method("is_harvest_view_ready") and range_view.is_harvest_view_ready():
			return
		await process_frame


func _check_harvest_trigger(gs: Node) -> bool:
	_reset(gs)
	gs.bucket_remaining = 1
	if not gs.consume_bucket_ball():
		print("FAIL: consume_bucket_ball returned false with 1 remaining")
		return false
	if gs.current_phase != "strike":
		print(
			"FAIL: emptying the bucket should not force harvest phase, got %s"
			% gs.current_phase
		)
		return false
	if gs.has_bucket_balls():
		print("FAIL: has_bucket_balls true with an empty bucket in strike")
		return false
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed voluntarily from strike")
		return false
	if gs.current_phase != "harvest":
		print("FAIL: expected harvest phase after try_enter_harvest, got %s" % gs.current_phase)
		return false
	if gs.harvest_collected != 0:
		print("FAIL: harvest_collected should start at 0")
		return false
	print("OK: emptying the bucket no longer forces harvest; entry is voluntary")
	return true


func _check_voluntary_entry_and_early_exit(gs: Node) -> bool:
	_reset(gs)
	gs.bucket_remaining = 3
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed with balls remaining")
		return false
	if gs.harvest_stash != 3:
		print("FAIL: harvest_stash expected 3, got %d" % gs.harvest_stash)
		return false
	if gs.bucket_remaining != 0:
		print("FAIL: bucket_remaining should be 0 while stashed, got %d" % gs.bucket_remaining)
		return false

	gs.collect_harvest_ball(Vector3.ZERO, 1)
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	if gs.harvest_collected != 2:
		print("FAIL: expected 2 collected balls, got %d" % gs.harvest_collected)
		return false

	gs.exit_harvest_early()
	if gs.current_phase != "strike":
		print("FAIL: exit_harvest_early should return to strike, got %s" % gs.current_phase)
		return false
	if gs.bucket_remaining != 5:
		print(
			"FAIL: expected merged bucket_remaining 5 (3 stash + 2 collected), got %d"
			% gs.bucket_remaining
		)
		return false
	if gs.harvest_stash != 0 or gs.harvest_collected != 0:
		print("FAIL: stash/collected should clear after early exit")
		return false
	print("OK: voluntary entry stashes unhit balls; early exit merges stash + collected")
	return true


func _check_harvest_display_shows_inventory(gs: Node) -> bool:
	_reset(gs)
	gs.bucket_remaining = 6
	gs.try_enter_harvest()
	var display: int = gs._bucket_display_count()
	if display != 6:
		print(
			"FAIL: harvest display should show stash inventory 6, got %d"
			% display
		)
		return false
	_reset(gs)
	gs.bucket_remaining = 3
	gs.try_enter_harvest()
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	display = gs._bucket_display_count()
	if display != 4:
		print(
			"FAIL: harvest display should be stash+collected (3+1=4), got %d"
			% display
		)
		return false
	print("OK: harvest bucket display shows stash + collected inventory")
	return true


func _check_free_harvest_credit_no_payout(gs: Node) -> bool:
	_reset(gs)
	gs.bucket_remaining = 0
	gs.try_enter_harvest()
	var before: float = gs.currency
	var credited: int = gs.credit_free_harvest_balls(3)
	if credited != 3:
		print("FAIL: credit_free_harvest_balls expected 3, got %d" % credited)
		return false
	if gs.harvest_collected != 3:
		print(
			"FAIL: free credit should raise harvest_collected to 3, got %d"
			% gs.harvest_collected
		)
		return false
	if not is_equal_approx(gs.currency, before):
		print("FAIL: free harvest credit must not change currency")
		return false
	var capped: int = gs.credit_free_harvest_balls(100)
	var target: int = gs._harvest_target()
	if gs.harvest_collected != target:
		print(
			"FAIL: free credit should cap at harvest target %d, got %d"
			% [target, gs.harvest_collected]
		)
		return false
	if capped != target - 3:
		print(
			"FAIL: capped free credit expected %d, got %d"
			% [target - 3, capped]
		)
		return false
	if not is_equal_approx(gs.currency, before):
		print("FAIL: capped free credit must not change currency")
		return false
	print("OK: free harvest credit fills without payout")
	return true


func _check_return_all_balls_free_full_bucket(gs: Node) -> bool:
	_reset(gs)
	gs.bucket_remaining = 0
	gs.try_enter_harvest()
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	var before: float = gs.currency
	var filled: int = gs.return_all_balls_free()
	if gs.current_phase != "strike":
		print(
			"FAIL: return_all_balls_free should return to strike, got %s"
			% gs.current_phase
		)
		return false
	if gs.bucket_remaining != gs.bucket_capacity:
		print(
			"FAIL: return_all_balls_free should refill full capacity, got %d/%d"
			% [gs.bucket_remaining, gs.bucket_capacity]
		)
		return false
	if filled != gs.bucket_capacity - 1:
		print(
			"FAIL: return_all_balls_free should fill remaining %d, got %d"
			% [gs.bucket_capacity - 1, filled]
		)
		return false
	if not is_equal_approx(gs.currency, before):
		print("FAIL: return_all_balls_free must not change currency")
		return false

	# Even with zero progress / no litter accounting, free return restores full.
	_reset(gs)
	gs.bucket_remaining = 2
	gs.try_enter_harvest()
	before = gs.currency
	filled = gs.return_all_balls_free()
	if gs.bucket_remaining != gs.bucket_capacity:
		print(
			"FAIL: free return with stash should still end at full capacity, got %d"
			% gs.bucket_remaining
		)
		return false
	if filled != gs.bucket_capacity - 2:
		print(
			"FAIL: free return should fill capacity-minus-stash (%d), got %d"
			% [gs.bucket_capacity - 2, filled]
		)
		return false
	if not is_equal_approx(gs.currency, before):
		print("FAIL: free return with stash must not change currency")
		return false
	print("OK: return_all_balls_free always restores a full bucket with no payout")
	return true


func _check_harvest_target_accounts_for_stash(gs: Node) -> bool:
	_reset(gs)
	gs.bucket_remaining = 4
	gs.try_enter_harvest()
	var target: int = gs.bucket_capacity - 4
	for i in range(target - 1):
		gs.collect_harvest_ball(Vector3.ZERO, 1)
	if gs.is_harvest_complete():
		print("FAIL: harvest should not complete before reaching the stash-aware target")
		return false
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	if not gs.is_harvest_complete():
		print("FAIL: harvest should complete once collected balls reach capacity minus stash")
		return false
	gs.complete_harvest(1)
	if gs.bucket_remaining != gs.bucket_capacity:
		print(
			"FAIL: complete_harvest should refill to full capacity, got %d"
			% gs.bucket_remaining
		)
		return false
	print("OK: harvest completion target accounts for stashed balls")
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
	var per_ball := Economy.resolve_pickup_ball_payout(1, gs.stats.base_yards, 1, gs.stats)
	var combo2 := Economy.resolve_pickup_ball_payout(1, gs.stats.base_yards, 2, gs.stats)
	gs.collect_harvest_ball(Vector3.ZERO, 1, 1, gs.stats.base_yards)
	var after_one: float = gs.currency
	if not is_equal_approx(after_one - start_currency, per_ball):
		print(
			"FAIL: per-ball payout expected %.2f, got %.2f"
			% [per_ball, after_one - start_currency]
		)
		return false
	if not is_equal_approx(combo2, per_ball):
		print("FAIL: default combo tier 2 should match tier 1 (no combo upgrade)")
		return false
	gs.harvest_collected = gs.bucket_capacity - 1
	var before_complete: float = gs.currency
	gs.complete_harvest(1)
	if not is_equal_approx(gs.currency, before_complete):
		print("FAIL: bucket complete should grant no bonus by default")
		return false
	print("OK: pickup economy grants (no default combo/bucket bonus)")
	return true


func _check_currency_changed_not_stats(gs: Node) -> bool:
	_reset(gs)
	_enter_harvest(gs)
	var event_bus: Node = root.get_node("EventBus")
	var currency_hits: Array = []
	var stats_hits: Array = []
	var on_currency := func(_currency: float) -> void:
		currency_hits.append(1)
	var on_stats := func(_stats: PlayerStats, _currency: float) -> void:
		stats_hits.append(1)
	event_bus.currency_changed.connect(on_currency)
	event_bus.stats_changed.connect(on_stats)

	var before: float = gs.currency
	for _i in 5:
		gs.collect_harvest_ball(Vector3.ZERO, 1)
	var after: float = gs.currency

	event_bus.currency_changed.disconnect(on_currency)
	event_bus.stats_changed.disconnect(on_stats)

	if after <= before:
		print("FAIL: currency should rise after collects")
		return false
	if currency_hits.size() != 5:
		print("FAIL: currency_changed expected 5 emits, got %d" % currency_hits.size())
		return false
	if stats_hits.size() != 0:
		print("FAIL: collect should not emit stats_changed, got %d" % stats_hits.size())
		return false
	print("OK: pickup emits currency_changed without stats_changed")
	return true


func _check_combo_logic() -> bool:
	var stats := Balance.default_stats()
	if not is_equal_approx(Economy.combo_multiplier(1, stats), 1.0):
		print("FAIL: combo tier 1 mult should be 1.0")
		return false
	if not is_equal_approx(Economy.combo_multiplier(4, stats), 1.0):
		print("FAIL: default combo tier 4 mult should be 1.0 without upgrade")
		return false
	var levels := {"base_pay": 1, "pickup": 1, "combo_bonus": 1}
	stats = UpgradeEffects.preview_stats(levels)
	if not is_equal_approx(Economy.combo_multiplier(2, stats), 1.08):
		print("FAIL: combo tier 2 mult should be 1.08 with combo_bonus Lv.1")
		return false
	print("OK: combo multiplier gated by upgrade")
	return true


func _check_vanish_auto_collect(gs: Node) -> bool:
	_reset(gs)
	var start_currency: float = gs.currency
	var expected_base: float = gs.stats.base_amount
	var payout: float = gs.credit_vanished_ball(Vector3(0.0, 0.0, -250.0), 1, 250.0)
	if not is_equal_approx(payout, expected_base):
		print("FAIL: vanish payout expected $%.2f, got %.4f" % [expected_base, payout])
		return false
	if not is_equal_approx(gs.currency - start_currency, expected_base):
		print(
			"FAIL: vanish payout currency delta expected $%.2f, got %.4f"
			% [expected_base, gs.currency - start_currency]
		)
		return false
	if gs.pending_vanish_collects != 1:
		print(
			"FAIL: strike-phase vanish should pending=1, got %d"
			% gs.pending_vanish_collects
		)
		return false
	if gs.harvest_collected != 0:
		print("FAIL: strike-phase vanish should not touch harvest_collected")
		return false

	gs.try_enter_harvest()
	if gs.harvest_collected != 1:
		print(
			"FAIL: harvest should start with pending vanish count 1, got %d"
			% gs.harvest_collected
		)
		return false
	if gs.pending_vanish_collects != 0:
		print("FAIL: pending vanish collects should clear on harvest entry")
		return false

	_reset(gs)
	_enter_harvest(gs)
	expected_base = gs.stats.base_amount
	payout = gs.credit_vanished_ball(Vector3(0.0, 0.0, -250.0), 1, 250.0)
	if not is_equal_approx(payout, expected_base):
		print("FAIL: harvest-phase vanish payout expected $%.2f, got %.4f" % [expected_base, payout])
		return false
	if gs.harvest_collected != 1:
		print(
			"FAIL: harvest-phase vanish should increment harvest_collected, got %d"
			% gs.harvest_collected
		)
		return false

	gs.harvest_collected = gs.bucket_capacity - 1
	payout = gs.credit_vanished_ball(Vector3(1.0, 0.0, -250.0), 6, 250.0)
	if gs.harvest_collected != gs.bucket_capacity:
		print(
			"FAIL: last vanish should fill bucket, got %d/%d"
			% [gs.harvest_collected, gs.bucket_capacity]
		)
		return false
	if not gs.is_harvest_complete():
		print("FAIL: last vanish should complete harvest")
		return false

	print("OK: vanish auto-collect credits bucket and pays out")
	return true


func _check_bucket_refill_and_strike(gs: Node) -> bool:
	_reset(gs)
	_enter_harvest(gs)
	gs.harvest_collected = gs.bucket_capacity
	gs.complete_harvest(2)
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


func _check_space_exits_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	gs.bucket_remaining = 2
	gs.try_enter_harvest()
	await _wait_harvest_view(range_view)
	await process_frame
	if gs.current_phase != "harvest":
		print("FAIL: space test expected harvest phase")
		return false
	gs.collect_harvest_ball(Vector3.ZERO, 1)

	_send_space(range_view, true)
	await process_frame
	_send_space(range_view, false)
	await process_frame
	if gs.current_phase != "strike":
		print("FAIL: Space in collect mode should exit to strike, got %s" % gs.current_phase)
		return false
	if gs.bucket_remaining != 3:
		print(
			"FAIL: Space exit should merge stash(2) + collected(1) = 3, got %d"
			% gs.bucket_remaining
		)
		return false
	print("OK: Space in collect mode exits to strike with merged bucket")
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
	if not phases.has("strike"):
		print("FAIL: phase_changed strike not emitted after harvest")
		return false
	print("OK: EventBus pickup signals")
	return true


func _check_phase_integration(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	var litter_parent: Node3D = range_view.get_node("Foreground/LitteredBalls")

	range_view._leave_litter_ball(Vector3(0.3, 0.0, -8.0), Vector3(1.0, 1.0, 1.0), 3, 10.0)
	if litter_parent.get_child_count() != 1:
		print("FAIL: litter spawn failed")
		return false
	var litter: Node = litter_parent.get_child(0)
	if not litter.get_meta("collectible", false):
		print("FAIL: litter missing collectible meta")
		return false

	_enter_harvest(gs)
	await _wait_harvest_view(range_view)
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
	_start_playing(main)
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

	gs.collect_harvest_ball(Vector3.ZERO, 1)
	await process_frame
	if range_view.golfer.animation != &"idle_out_of_balls":
		print("FAIL: harvest idle should stay idle_out_of_balls after collecting balls")
		return false

	gs.exit_harvest_early()
	await process_frame
	if not range_view.golfer.position.is_equal_approx(home):
		print(
			"FAIL: strike return expected home %s, got %s"
			% [home, range_view.golfer.position]
		)
		return false

	print("OK: harvest idle stays at home, returns to idle on strike")
	return true


func _check_no_swing_during_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")

	_enter_harvest(gs)
	await _wait_harvest_view(range_view)
	await process_frame
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	if gs.harvest_collected != 1:
		print("FAIL: expected 1 collected ball before swing-block check")
		return false
	if not gs.is_collect_mode():
		print("FAIL: partial bucket should still allow pickup")
		return false

	range_view._swing._last_swing_msec = Time.get_ticks_msec() - int(gs.stats.swing_cooldown_ms) - 1
	range_view._swing.start_charge()
	if range_view._swing.is_charging():
		print("FAIL: start_charge should be blocked entirely during harvest phase")
		return false

	var collected_before: int = gs.harvest_collected
	_send_space(range_view, true)
	await process_frame
	if range_view._swing.is_charging():
		print("FAIL: Space press during harvest should not start a swing")
		return false
	if gs.current_phase != "strike":
		print("FAIL: Space during harvest should exit to strike, got %s" % gs.current_phase)
		return false
	if gs.bucket_remaining != collected_before:
		print(
			"FAIL: exit via Space should merge collected balls into the bucket, expected %d got %d"
			% [collected_before, gs.bucket_remaining]
		)
		return false

	print("OK: harvest phase never allows swinging; Space exits to strike instead")
	return true


func _check_harvest_exit_ignores_leftover_press(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	gs.bucket_remaining = 3
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed with balls remaining")
		return false
	await _wait_harvest_view(range_view)

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(240, 220)
	range_view._input(touch_down)

	gs.exit_harvest_early()
	if not range_view._ignore_pointer_until_release:
		print("FAIL: harvest→strike should ignore leftover pointer while a finger is down")
		return false

	range_view._swing._last_swing_msec = Time.get_ticks_msec() - int(gs.stats.swing_cooldown_ms) - 1
	var leftover := InputEventScreenTouch.new()
	leftover.index = 0
	leftover.pressed = true
	leftover.position = Vector2(240, range_view.horizon_screen_y() + 40)
	range_view._handle_mobile_strike_input(leftover)
	if range_view._swing.is_charging():
		print("FAIL: leftover harvest press should not start a charge")
		return false

	_send_space(range_view, true)
	if range_view._swing.is_charging():
		print("FAIL: Space should not start a charge while leftover pointer ignore is active")
		return false

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	range_view._input(touch_up)
	await process_frame
	if range_view._ignore_pointer_until_release:
		print("FAIL: ignore flag should clear after all pointers release")
		return false

	var fresh := InputEventScreenTouch.new()
	fresh.index = 0
	fresh.pressed = true
	fresh.position = leftover.position
	range_view._handle_mobile_strike_input(fresh)
	if not range_view._swing.is_charging():
		print("FAIL: after pointer release, a new below-horizon press should start a charge")
		return false

	range_view._swing.cancel_charge()
	if range_view._swing.is_charging():
		print("FAIL: cancel_charge should drop an in-progress charge without hitting")
		return false

	print("OK: harvest exit ignores leftover press until release")
	return true


func _check_bucket_counter_exits_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	var bucket: Control = main.get_node_or_null(
		"UI/UIRoot/GameplayChrome/IconBar/BottomRight/BucketCounter"
	)
	if bucket == null or not bucket.has_method("_on_gui_input"):
		print("FAIL: BucketCounter missing for ball-return check")
		return false

	gs.bucket_remaining = 3
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed for bucket ball-return")
		return false
	await _wait_harvest_view(range_view)
	gs.collect_harvest_ball(Vector3.ZERO, 1)
	if bucket.mouse_filter != Control.MOUSE_FILTER_STOP:
		print("FAIL: harvest bucket should be tappable (STOP)")
		return false

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	bucket._on_gui_input(click)
	await process_frame
	if gs.current_phase != "strike":
		print("FAIL: bucket tap should return_all_balls_free, got %s" % gs.current_phase)
		return false
	if gs.bucket_remaining != gs.bucket_capacity:
		print(
			"FAIL: bucket ball-return should refill leftover balls to %d, got %d"
			% [gs.bucket_capacity, gs.bucket_remaining]
		)
		return false

	print("OK: bucket tap returns leftover balls via return_all_balls_free")
	return true


func _check_background_click_enters_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_visible_rect().size * 0.5
	range_view._unhandled_input(click)
	await process_frame
	if gs.current_phase != "harvest":
		print("FAIL: background click should voluntarily enter harvest, got %s" % gs.current_phase)
		return false

	print("OK: background click in hitting mode enters collect mode")
	return true


func _check_empty_click_does_not_exit_harvest(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	gs.bucket_remaining = 3
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed before empty-click stay check")
		return false
	await _wait_harvest_view(range_view)
	gs.collect_harvest_ball(Vector3.ZERO, 1)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = root.get_visible_rect().size * 0.5
	range_view._unhandled_input(press)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	range_view._unhandled_input(release)
	await process_frame
	if gs.current_phase != "harvest":
		print("FAIL: empty harvest click must stay in harvest, got %s" % gs.current_phase)
		return false

	print("OK: empty harvest click stays in collect mode")
	return true


func _check_mid_flight_view_switch_and_pickup_gate(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	var vm: Node = range_view.get_node("ViewModeController")

	# Simulate balls still in the air — view switch must not wait on flights.
	range_view._active_flights.append({"debug": true})
	gs.bucket_remaining = 2
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed mid-flight")
		return false
	await _wait_harvest_view(range_view, 500)
	if not range_view.is_harvest_view_ready():
		print("FAIL: harvest ortho should settle without waiting for active flights")
		return false
	if range_view._pickup == null or not range_view._pickup.is_active():
		print("FAIL: pickup should be active once harvest view is ready")
		return false

	# Gate: pickup must ignore clicks while the harvest settle flag is false.
	# Iso harvest also counts as ready — force it off for this 3D settle check.
	vm._harvest_view_ready = false
	if main.has_method(&"set_harvest_view"):
		main.set_harvest_view(false)
	await process_frame
	if range_view._pickup.is_active():
		print("FAIL: pickup must stay inactive until harvest_view_ready")
		return false
	var blocked := InputEventMouseButton.new()
	blocked.button_index = MOUSE_BUTTON_LEFT
	blocked.pressed = false
	blocked.position = Vector2(10, 10)
	if range_view._pickup.handle_input(blocked):
		print("FAIL: pickup handle_input must no-op before harvest view ready")
		return false
	vm._harvest_view_ready = true
	if main.has_method(&"set_harvest_view"):
		main.set_harvest_view(true)
	await process_frame
	if not range_view._pickup.is_active():
		print("FAIL: pickup should reactivate when harvest_view_ready returns")
		return false

	range_view._active_flights.clear()
	gs.exit_harvest_early()
	await process_frame
	print("OK: mid-flight view switch settles without flight wait; pickup gated on ready")
	return true


func _check_combo_interrupted_by_swing(main: Node, gs: Node) -> bool:
	_reset(gs)
	_start_playing(main)
	await process_frame
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")
	_enter_harvest(gs)

	var pickup: Node = range_view._pickup
	if pickup == null:
		print("FAIL: pickup controller missing for combo interrupt test")
		return false

	var tier1: int = pickup._advance_combo()
	var tier2: int = pickup._advance_combo()
	if tier1 != 1 or tier2 != 2:
		print("FAIL: expected combo tiers 1 then 2, got %d then %d" % [tier1, tier2])
		return false
	if pickup._combo != 2:
		print("FAIL: expected _combo=2 after two pickups, got %d" % pickup._combo)
		return false
	if pickup._best_combo != 2:
		print("FAIL: expected _best_combo=2, got %d" % pickup._best_combo)
		return false

	var event_bus: Node = root.get_node("EventBus")
	event_bus.swing_resolved.emit(100.0, Balance.TimingTier.GOOD, 0.0, Balance.FeedbackTier.WHISPER)
	if pickup._combo != 1:
		print("FAIL: swing should reset _combo to 1, got %d" % pickup._combo)
		return false
	if pickup._best_combo != 2:
		print("FAIL: swing should preserve _best_combo=2, got %d" % pickup._best_combo)
		return false

	var tier_after: int = pickup._advance_combo()
	if tier_after != 1:
		print("FAIL: pickup after swing should be combo tier 1, got %d" % tier_after)
		return false

	print("OK: swing interrupts pickup combo streak")
	return true
