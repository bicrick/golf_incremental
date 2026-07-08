extends SceneTree
## Headless Ratina smoke test — run:
## godot --headless --script res://tools/verify_ratina.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _test_swing_sprite_frames() and ok

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		quit(1)
		return

	var range_view: Node3D = main.get_node("RangeView")
	var ratina_controller: Node = range_view.get_node_or_null("RatinaController")
	var ratina_sprite: Node = range_view.ratina_sprite

	gs.reset_to_fresh()
	await process_frame

	if ratina_controller == null:
		print("FAIL: RatinaController missing from RangeView")
		ok = false
	elif ratina_sprite != null and ratina_sprite.visible:
		print("FAIL: Ratina sprite should be hidden before unlock")
		ok = false
	else:
		print("OK: Ratina inactive before unlock")

	var defs: Array = RatinaUpgradeDefinitions.all()
	if defs.size() != 10:
		print("FAIL: expected 10 Ratina upgrade nodes, got %d" % defs.size())
		ok = false
	else:
		print("OK: Ratina upgrade tree has 10 nodes")

	for link in RatinaUpgradeDefinitions.connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if RatinaUpgradeDefinitions.get_def(from_id).is_empty():
			print("FAIL: ratina connection parent missing: %s" % from_id)
			ok = false
		if RatinaUpgradeDefinitions.get_def(to_id).is_empty():
			print("FAIL: ratina connection child missing: %s" % to_id)
			ok = false
	if ok:
		print("OK: Ratina tree connections resolve")

	for player_id in UpgradeDefinitions.tree_order():
		if RatinaUpgradeDefinitions.get_def(player_id).size() > 0:
			print("FAIL: Ratina tree id collides with player id: %s" % player_id)
			ok = false
	if ok:
		print("OK: Ratina ids do not overlap player tree")

	gs.currency = 500.0
	gs.upgrades_unlocked = true
	gs.upgrade_levels = {"base_pay": 3}
	gs._recompute_stats()
	if not gs.purchase_upgrade("ratina_hire"):
		print("FAIL: could not hire Ratina from upgrade tree")
		ok = false
	await process_frame

	if not gs.ratina_unlocked:
		print("FAIL: ratina_unlocked flag not set")
		ok = false
	else:
		print("OK: Ratina unlocked")

	if not is_equal_approx(gs.ratina_stats.swing_cooldown_ms, 10000.0):
		print(
			"FAIL: base swing_cooldown_ms should be 10000, got %.1f"
			% gs.ratina_stats.swing_cooldown_ms
		)
		ok = false
	else:
		print("OK: Ratina base swing interval is 10s")

	if ratina_sprite == null or not ratina_sprite.visible:
		print("FAIL: Ratina sprite should be visible after unlock")
		ok = false
	else:
		print("OK: Ratina visible after unlock")

	var before_base: float = gs.ratina_stats.base_amount
	var before_currency: float = gs.currency
	if not gs.purchase_ratina_upgrade("ratina_base_pay"):
		print("FAIL: could not purchase ratina_base_pay")
		ok = false
	elif gs.ratina_stats.base_amount <= before_base:
		print(
			"FAIL: ratina_base_pay should raise base_amount (%.3f -> %.3f)"
			% [before_base, gs.ratina_stats.base_amount]
		)
		ok = false
	elif gs.currency >= before_currency:
		print("FAIL: ratina_base_pay should deduct currency")
		ok = false
	else:
		print("OK: ratina_base_pay raises base_amount and costs currency")

	var before_interval: float = gs.ratina_stats.swing_cooldown_ms
	gs.currency = 500.0
	if not gs.purchase_ratina_upgrade("ratina_frequency"):
		print("FAIL: could not purchase ratina_frequency")
		ok = false
	elif gs.ratina_stats.swing_cooldown_ms >= before_interval:
		print(
			"FAIL: ratina_frequency should lower interval (%.1f -> %.1f ms)"
			% [before_interval, gs.ratina_stats.swing_cooldown_ms]
		)
		ok = false
	else:
		print("OK: ratina_frequency lowers swing interval")

	ok = await _test_controller_cooldown_refresh(gs, range_view, ratina_controller) and ok

	var swing_state := {
		"fired": false,
		"yards": 0.0,
		"payout": -1.0,
	}
	var on_swing := func(yards: float, _tier: int, payout: float) -> void:
		swing_state["fired"] = true
		swing_state["yards"] = yards
		swing_state["payout"] = payout
	var event_bus: Node = root.get_node("EventBus")
	event_bus.ratina_swing_resolved.connect(on_swing)

	var tier: int = RatinaSwingResolver.roll_tier(gs.ratina_stats.consistency)
	var quality: int = Economy.quality_for_tier(tier)
	var yards: float = Economy.yards_from_quality(Balance.TIER_MULTS[tier], gs.ratina_stats)

	var currency_before_collect: float = gs.currency
	var collect_payout: float = gs.credit_ratina_ball(yards, quality)
	if collect_payout <= 0.0:
		print("FAIL: credit_ratina_ball should return positive payout")
		ok = false
	elif gs.currency <= currency_before_collect:
		print("FAIL: credit_ratina_ball should add currency on collection")
		ok = false
	else:
		print("OK: credit_ratina_ball awards cash on collection")

	var bucket_before: int = gs.bucket_remaining
	if not gs.consume_bucket_ball():
		print("FAIL: consume_bucket_ball should succeed with balls remaining")
		ok = false
	event_bus.ratina_swing_resolved.emit(yards, tier, 0.0)
	await process_frame

	if not swing_state["fired"]:
		print("FAIL: ratina_swing_resolved signal not received")
		ok = false
	elif float(swing_state["yards"]) <= 0.0:
		print("FAIL: ratina swing yards should be positive")
		ok = false
	elif not is_equal_approx(float(swing_state["payout"]), 0.0):
		print("FAIL: ratina_swing_resolved payout should be 0 at contact (deferred to collection)")
		ok = false
	elif gs.bucket_remaining != bucket_before - 1:
		print("FAIL: ratina swing should consume one bucket ball")
		ok = false
	else:
		print("OK: ratina swing consumes bucket and defers payout to collection")

	ok = _test_ratina_swings_during_harvest(gs, ratina_controller) and ok

	var upgrade_panel: Control = main.get_node("UI/UIRoot/UpgradePanel")
	if upgrade_panel.has_method("open"):
		upgrade_panel.open()
		await process_frame
		var nodes_root: Control = upgrade_panel.get_node("Content/TreeViewport/TreeWorld/Nodes")
		var ratina_nodes := 0
		for child in nodes_root.get_children():
			if child.upgrade_id.begins_with("ratina_"):
				ratina_nodes += 1
		if ratina_nodes < 10:
			print("FAIL: unified tree should include Ratina nodes, got ", ratina_nodes)
			ok = false
		else:
			print("OK: unified tree includes Ratina upgrade nodes")

	if ok:
		print("PASS: verify_ratina")
		quit(0)
	else:
		print("FAIL: verify_ratina")
		quit(1)


## Player collect mode should not stop Ratina — she keeps hitting from the
## stashed (unhit) balls while the player collects litter.
func _test_ratina_swings_during_harvest(gs: Node, ratina_controller: Node) -> bool:
	gs.current_phase = "strike"
	gs.bucket_remaining = 3
	gs.harvest_stash = 0
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest should succeed from strike")
		return false
	if gs.harvest_stash != 3:
		print("FAIL: harvest_stash expected 3, got %d" % gs.harvest_stash)
		gs.exit_harvest_early()
		return false
	if not ratina_controller.call("_can_swing"):
		print("FAIL: Ratina should still be able to swing during harvest with stashed balls")
		gs.exit_harvest_early()
		return false
	if not gs.consume_ratina_bucket_ball():
		print("FAIL: consume_ratina_bucket_ball should draw from harvest_stash")
		gs.exit_harvest_early()
		return false
	if gs.harvest_stash != 2:
		print("FAIL: consume_ratina_bucket_ball should decrement harvest_stash, got %d" % gs.harvest_stash)
		gs.exit_harvest_early()
		return false
	gs.harvest_stash = 0
	if ratina_controller.call("_can_swing"):
		print("FAIL: Ratina should be blocked once harvest_stash is exhausted")
		gs.exit_harvest_early()
		return false
	gs.exit_harvest_early()
	print("OK: Ratina keeps swinging from the stash during the player's collect mode")
	return true


func _test_swing_sprite_frames() -> bool:
	var ok := true
	if RatinaSpriteFrames.SWING_FRAME_COUNT != 17:
		print(
			"FAIL: SWING_FRAME_COUNT expected 17, got %d"
			% RatinaSpriteFrames.SWING_FRAME_COUNT
		)
		ok = false
	if RatinaSpriteFrames.WINDUP_LAST != 11:
		print("FAIL: WINDUP_LAST expected 11, got %d" % RatinaSpriteFrames.WINDUP_LAST)
		ok = false
	if RatinaSpriteFrames.CONTACT_FRAME != 12:
		print("FAIL: CONTACT_FRAME expected 12, got %d" % RatinaSpriteFrames.CONTACT_FRAME)
		ok = false
	if RatinaSpriteFrames.FOLLOW_START != 13 or RatinaSpriteFrames.FOLLOW_END != 16:
		print(
			"FAIL: follow range expected 13-16, got %d-%d"
			% [RatinaSpriteFrames.FOLLOW_START, RatinaSpriteFrames.FOLLOW_END]
		)
		ok = false

	if RatinaSpriteFrames.FOLLOW_HOLD_FRAMES != 2:
		print(
			"FAIL: FOLLOW_HOLD_FRAMES expected 2, got %d"
			% RatinaSpriteFrames.FOLLOW_HOLD_FRAMES
		)
		ok = false
	var frames := RatinaSpriteFrames.make_golfer_frames()
	if frames.get_frame_count(&"waiting") != RatinaSpriteFrames.WAITING_FRAME_COUNT:
		print(
			"FAIL: waiting animation has %d frames, expected %d"
			% [frames.get_frame_count(&"waiting"), RatinaSpriteFrames.WAITING_FRAME_COUNT]
		)
		ok = false
	if frames.get_frame_count(&"swing") != RatinaSpriteFrames.SWING_FRAME_COUNT:
		print(
			"FAIL: swing animation has %d frames, expected %d"
			% [frames.get_frame_count(&"swing"), RatinaSpriteFrames.SWING_FRAME_COUNT]
		)
		ok = false
	var follow_count := RatinaSpriteFrames.FOLLOW_END - RatinaSpriteFrames.FOLLOW_START + 1
	if frames.get_frame_count(&"follow") != follow_count:
		print(
			"FAIL: follow animation has %d frames, expected %d"
			% [frames.get_frame_count(&"follow"), follow_count]
		)
		ok = false
	var contact_tex: Texture2D = frames.get_frame_texture(&"swing", RatinaSpriteFrames.CONTACT_FRAME)
	if contact_tex == null:
		print("FAIL: swing contact frame texture is null")
		ok = false
	elif ok:
		print("OK: Ratina swing uses full 17-frame sheet (contact 12, follow 13-16)")
	return ok


func _test_controller_cooldown_refresh(gs: Node, range_view: Node3D, ratina_controller: Node) -> bool:
	if ratina_controller == null:
		print("FAIL: RatinaController missing for cooldown refresh test")
		return false

	var swing_timer: Timer = ratina_controller.get_node_or_null("SwingTimer")
	if swing_timer == null:
		print("FAIL: Ratina SwingTimer missing")
		return false

	var base_sec: float = gs.ratina_stats.swing_cooldown_ms / 1000.0
	if not is_equal_approx(swing_timer.wait_time, maxf(base_sec, 0.35)):
		print(
			"FAIL: Ratina timer should match stats (%.3fs vs timer %.3fs)"
			% [base_sec, swing_timer.wait_time]
		)
		return false
	print("OK: Ratina timer matches swing_cooldown_ms after unlock")

	var before_sec: float = swing_timer.wait_time
	gs.currency = 500.0
	if not gs.purchase_ratina_upgrade("ratina_rapid_fire"):
		print("FAIL: could not purchase ratina_rapid_fire for timer refresh test")
		return false

	var expected_sec: float = maxf(gs.ratina_stats.swing_cooldown_ms / 1000.0, 0.35)
	if swing_timer.wait_time >= before_sec:
		print(
			"FAIL: ratina_rapid_fire should lower timer wait (%.3fs -> %.3fs, got %.3fs)"
			% [before_sec, expected_sec, swing_timer.wait_time]
		)
		return false
	if not is_equal_approx(swing_timer.wait_time, expected_sec):
		print(
			"FAIL: Ratina timer wait_time stale after upgrade (expected %.3fs, got %.3fs)"
			% [expected_sec, swing_timer.wait_time]
		)
		return false
	if swing_timer.is_stopped():
		print("FAIL: Ratina timer should restart after frequency upgrade while idle")
		return false

	# Simulate a missed timeout while busy — cadence upgrades must still fire when idle.
	ratina_controller._swinging = true
	ratina_controller._ball_in_flight = true
	swing_timer.wait_time = 0.01
	swing_timer.start()
	await swing_timer.timeout
	await process_frame

	if not ratina_controller._pending_swing:
		print("FAIL: Ratina should queue pending swing when cooldown expires while busy")
		ratina_controller._swinging = false
		ratina_controller._ball_in_flight = false
		ratina_controller._pending_swing = false
		return false

	ratina_controller._swinging = false
	ratina_controller._ball_in_flight = false
	ratina_controller.call("_try_pending_swing")
	await process_frame

	if ratina_controller._swinging:
		print("OK: Ratina pending swing fires once idle after missed timeout")
	else:
		print("FAIL: Ratina pending swing did not start after becoming idle")
		ratina_controller._pending_swing = false
		return false

	ratina_controller._swinging = false
	ratina_controller._pending_swing = false
	ratina_controller._refresh_cooldown_timer()
	print("OK: Ratina timer refreshes on frequency upgrade and pending swings recover")
	return true
