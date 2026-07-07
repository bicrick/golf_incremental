extends SceneTree
## Headless Rattlings smoke test — run:
## godot --headless --script res://tools/verify_rattlings.gd

const RattlingSpriteFramesScript := preload("res://scripts/range/rattling_sprite_frames.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_sprite_frames() and ok
	ok = _check_definitions() and ok

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		print("rattlings_ok=false")
		quit(1)
		return

	ok = _check_unlock_flow(gs) and ok
	ok = _check_upgrade_effects(gs) and ok
	ok = _check_credit_accounting(gs) and ok

	main.get_node("TitleScreen").visible = false
	main.get_node("RangeView").visible = true
	main.get_node("UI").visible = true
	main._set_gameplay_ui_visible(true)
	await process_frame

	ok = await _check_shop_ui(main, gs) and ok
	ok = await _check_upgrade_panel_ui(main, gs) and ok
	ok = await _check_range_view_wiring(main, gs) and ok
	ok = await _check_controller_pickup_cycle(main, gs) and ok

	print("rattlings_ok=", ok)
	quit(0 if ok else 1)


func _check_sprite_frames() -> bool:
	var ok := true
	var frames := RattlingSpriteFramesScript.make_frames()
	for anim in [&"walk", &"walk_ball", &"pickup"]:
		if not frames.has_animation(anim):
			print("FAIL: missing animation ", anim)
			ok = false
		elif frames.get_frame_count(anim) != RattlingSpriteFramesScript.FRAME_COUNT:
			print(
				"FAIL: %s expected %d frames, got %d"
				% [anim, RattlingSpriteFramesScript.FRAME_COUNT, frames.get_frame_count(anim)]
			)
			ok = false
	if not frames.has_animation(&"idle") or not frames.has_animation(&"idle_ball"):
		print("FAIL: missing idle/idle_ball animation")
		ok = false
	if ok:
		print("OK: RattlingSpriteFrames has 13-frame walk/walk_ball/pickup + idle poses")
	return ok


func _check_definitions() -> bool:
	var ok := true
	var defs := RattlingUpgradeDefinitions.all()
	if defs.size() != 5:
		print("FAIL: expected 5 rattling upgrades, got ", defs.size())
		ok = false
	var root_def := RattlingUpgradeDefinitions.get_def("rattling_more")
	if root_def.is_empty() or root_def.get("parent_id", "x") != "":
		print("FAIL: rattling_more root missing or has parent")
		ok = false
	for head in ["rattling_speed", "rattling_payout", "rattling_quick_paws"]:
		var def := RattlingUpgradeDefinitions.get_def(head)
		if def.get("parent_id", "") != "rattling_more":
			print("FAIL: %s should branch from rattling_more" % head)
			ok = false
	if ok:
		print("OK: RattlingUpgradeDefinitions tree shape correct")
	return ok


func _check_unlock_flow(gs: Node) -> bool:
	var ok := true
	gs.reset_to_fresh()
	gs.currency = 100.0
	gs.shop_unlocked = false
	if gs.try_unlock_rattlings():
		print("FAIL: try_unlock_rattlings should require shop_unlocked")
		ok = false
	gs.shop_unlocked = true
	var before: float = gs.currency
	if not gs.try_unlock_rattlings():
		print("FAIL: try_unlock_rattlings failed with sufficient funds")
		ok = false
	if not gs.rattlings_unlocked:
		print("FAIL: rattlings_unlocked flag not set")
		ok = false
	if not is_equal_approx(before - gs.currency, Balance.RATTLING_UNLOCK_COST):
		print("FAIL: rattling unlock should cost $10, spent %.2f" % (before - gs.currency))
		ok = false
	else:
		print("OK: rattling unlock costs $10 and requires shop_unlocked")
	return ok


func _check_upgrade_effects(gs: Node) -> bool:
	var ok := true
	gs.rattling_upgrade_levels = {}
	gs._recompute_stats()
	var base_count: float = gs.rattling_stats.rattling_count
	var base_speed: float = gs.rattling_stats.rattling_walk_speed
	var base_payout_mult: float = gs.rattling_stats.rattling_payout_multiplier
	gs.currency = 500.0

	if not gs.purchase_rattling_upgrade("rattling_more"):
		print("FAIL: could not purchase rattling_more")
		ok = false
	elif gs.rattling_stats.rattling_count <= base_count:
		print("FAIL: rattling_more did not increase rattling_count")
		ok = false

	if not gs.purchase_rattling_upgrade("rattling_speed"):
		print("FAIL: could not purchase rattling_speed")
		ok = false
	elif gs.rattling_stats.rattling_walk_speed <= base_speed:
		print("FAIL: rattling_speed did not increase walk speed")
		ok = false

	if not gs.purchase_rattling_upgrade("rattling_payout"):
		print("FAIL: could not purchase rattling_payout")
		ok = false
	elif gs.rattling_stats.rattling_payout_multiplier <= base_payout_mult:
		print("FAIL: rattling_payout did not increase rattling_payout_multiplier")
		ok = false

	if not gs.purchase_rattling_upgrade("rattling_quick_paws"):
		print("FAIL: could not purchase rattling_quick_paws")
		ok = false
	elif gs.rattling_stats.rattling_pickup_speed_multiplier <= 1.0:
		print("FAIL: rattling_quick_paws did not increase pickup speed multiplier")
		ok = false

	if not gs.purchase_rattling_upgrade("rattling_keen_nose"):
		print("FAIL: could not purchase rattling_keen_nose")
		ok = false
	elif gs.rattling_stats.rattling_golden_bonus_chance <= 0.0:
		print("FAIL: rattling_keen_nose did not increase golden bonus chance")
		ok = false

	if ok:
		print("OK: all 5 rattling upgrades affect rattling_stats")
	return ok


func _check_credit_accounting(gs: Node) -> bool:
	var ok := true
	gs.rattling_upgrade_levels = {}
	gs._recompute_stats()

	gs.current_phase = "strike"
	gs.bucket_capacity = 6
	gs.bucket_remaining = 3
	var before_currency: float = gs.currency
	var payout: float = gs.credit_rattling_ball(4, 30.0, false)
	if payout <= 0.0:
		print("FAIL: credit_rattling_ball returned non-positive payout")
		ok = false
	if not is_equal_approx(gs.currency - before_currency, payout):
		print("FAIL: credit_rattling_ball did not add payout to currency")
		ok = false
	if gs.bucket_remaining != 4:
		print("FAIL: strike-phase rattling collect should hand the ball back into bucket_remaining")
		ok = false
	gs.bucket_remaining = gs.bucket_capacity
	gs.credit_rattling_ball(4, 30.0, false)
	if gs.bucket_remaining != gs.bucket_capacity:
		print("FAIL: bucket_remaining should not exceed bucket_capacity")
		ok = false

	gs.current_phase = "harvest"
	var before_harvest: int = gs.harvest_collected
	gs.credit_rattling_ball(4, 30.0, false)
	if gs.harvest_collected != before_harvest + 1:
		print("FAIL: harvest-phase rattling collect should increment harvest_collected")
		ok = false

	gs.rattling_stats.rattling_golden_bonus_chance = 1.0
	var normal_payout := Economy.resolve_pickup_ball_payout(4, 30.0, 1, gs.stats)
	var expected_golden: float = (
		normal_payout * gs.stats.golden_ball_payout_multiplier * gs.rattling_stats.rattling_payout_multiplier
	)
	var golden_payout: float = gs.credit_rattling_ball(4, 30.0, false)
	if not is_equal_approx(golden_payout, expected_golden):
		print("FAIL: keen nose golden bonus should apply the player's golden multiplier")
		ok = false

	gs.reset_to_fresh()
	if ok:
		print("OK: credit_rattling_ball awards cash and credits the bucket in both phases")

	ok = _check_ratina_source_collect(gs) and ok
	return ok


func _check_ratina_source_collect(gs: Node) -> bool:
	var ok := true
	gs.reset_to_fresh()
	gs.current_phase = "strike"
	gs.bucket_remaining = 3
	var before_ratina_earnings: float = gs.lifetime.get("ratina_lifetime_earnings", 0.0)
	var before_rattling_earnings: float = gs.lifetime.get("rattling_lifetime_earnings", 0.0)
	var before_currency: float = gs.currency
	var payout: float = gs.credit_rattling_ball(4, 30.0, false, "ratina")
	if payout <= 0.0:
		print("FAIL: ratina-source rattling collect returned non-positive payout")
		ok = false
	if not is_equal_approx(gs.currency - before_currency, payout):
		print("FAIL: ratina-source rattling collect did not add payout to currency")
		ok = false
	if gs.lifetime.get("ratina_lifetime_earnings", 0.0) <= before_ratina_earnings:
		print("FAIL: ratina-source collect should increment ratina_lifetime_earnings")
		ok = false
	if gs.lifetime.get("rattling_lifetime_earnings", 0.0) != before_rattling_earnings:
		print("FAIL: ratina-source collect should not increment rattling_lifetime_earnings")
		ok = false
	if ok:
		print("OK: rattling collect of ratina litter pays via ratina_stats")
	return ok


func _check_shop_ui(main: Node, gs: Node) -> bool:
	var ok := true
	gs.reset_to_fresh()
	gs.currency = 500.0
	gs.upgrades_unlocked = true
	gs.purchase_upgrade("base_pay")
	gs.try_unlock_shop()
	await process_frame

	var shop_panel: Control = main.get_node("UI/UIRoot/ShopPanel")
	var rattling_card: PanelContainer = shop_panel.get_node("Content/Items/RattlingCard")
	if rattling_card == null:
		print("FAIL: RattlingCard missing from shop panel")
		return false

	shop_panel.open()
	await process_frame
	var buy_button: Button = rattling_card.get_node("Margin/Row/BuyButton")
	if buy_button.text != "$10":
		print("FAIL: rattling buy button should show $10, got ", buy_button.text)
		ok = false
	buy_button.pressed.emit()
	await process_frame
	if not gs.rattlings_unlocked:
		print("FAIL: pressing rattling buy button should unlock rattlings")
		ok = false
	if buy_button.text != "HIRED" or not buy_button.disabled:
		print("FAIL: rattling buy button should show HIRED and disable after unlock")
		ok = false
	shop_panel.close()
	await process_frame
	if ok:
		print("OK: shop panel Rattling card unlocks Rattlings")
	return ok


func _check_upgrade_panel_ui(main: Node, gs: Node) -> bool:
	var ok := true
	var upgrade_panel: Control = main.get_node("UI/UIRoot/UpgradePanel")
	upgrade_panel.open()
	await process_frame
	var rattling_tab: Button = upgrade_panel.get_node("Content/Header/TabRow/RattlingTab")
	if not rattling_tab.visible:
		print("FAIL: Rattling tab should be visible after unlock")
		ok = false
	rattling_tab.pressed.emit()
	await process_frame
	var rattling_placeholder: Control = upgrade_panel.get_node("Content/RattlingPlaceholder")
	if not rattling_placeholder.visible:
		print("FAIL: Rattling placeholder should show when tab selected")
		ok = false
	var nodes_root: Control = rattling_placeholder.get_node("RattlingTreeCanvas/Nodes")
	if nodes_root.get_child_count() != RattlingUpgradeDefinitions.all().size():
		print(
			"FAIL: expected %d rattling tree nodes, got %d"
			% [RattlingUpgradeDefinitions.all().size(), nodes_root.get_child_count()]
		)
		ok = false
	upgrade_panel.close()
	await process_frame
	if ok:
		print("OK: upgrade panel Rattling tab builds its tree")
	return ok


func _check_range_view_wiring(main: Node, _gs: Node) -> bool:
	var range_view: Node3D = main.get_node("RangeView")
	await process_frame
	await process_frame
	if range_view.get("_rattling_controller") == null:
		print("FAIL: RangeView did not set up a RattlingController")
		return false
	print("OK: RangeView wires up a RattlingController at runtime")
	return true


func _check_controller_pickup_cycle(main: Node, gs: Node) -> bool:
	var ok := true
	var range_view: Node3D = main.get_node("RangeView")
	var littered_balls: Node3D = range_view.get_node("Foreground/LitteredBalls")

	gs.rattlings_unlocked = true
	gs.rattling_stats.rattling_count = 1.0
	gs.rattling_stats.rattling_walk_speed = 500.0
	gs.rattling_stats.rattling_pickup_speed_multiplier = 50.0

	var litter := Sprite3D.new()
	litter.set_meta("collectible", true)
	litter.set_meta("ball_quality", 4)
	litter.set_meta("ball_yardage", 30.0)
	litter.set_meta("ball_golden", false)
	littered_balls.add_child(litter)
	litter.global_position = Vector3(0.0, 0.0, -10.0)
	await process_frame

	var controller: Node = range_view.get("_rattling_controller")
	if controller == null:
		print("FAIL: no rattling controller available for pickup cycle test")
		return false

	var before_currency: float = gs.currency
	var start_msec := Time.get_ticks_msec()
	var collected := false
	while Time.get_ticks_msec() - start_msec < 3000:
		await process_frame
		if gs.currency > before_currency and not is_instance_valid(litter):
			collected = true
			break

	if not collected:
		print("FAIL: Rattling did not fetch the litter ball and credit cash within 3s")
		ok = false
	if ok:
		print("OK: Rattling claims litter, walks it back, and credits cash")

	## Golden litter should pay out the golden multiplier end-to-end, not
	## just when calling credit_rattling_ball() directly.
	gs.rattlings_unlocked = true
	gs.rattling_stats.rattling_count = 1.0
	gs.rattling_stats.rattling_walk_speed = 500.0
	gs.rattling_stats.rattling_pickup_speed_multiplier = 50.0
	gs.rattling_stats.rattling_golden_bonus_chance = 0.0
	var normal_payout := Economy.resolve_pickup_ball_payout(4, 30.0, 1, gs.stats)
	var expected_golden_payout: float = (
		normal_payout * gs.stats.golden_ball_payout_multiplier * gs.rattling_stats.rattling_payout_multiplier
	)

	var golden_litter := Sprite3D.new()
	golden_litter.set_meta("collectible", true)
	golden_litter.set_meta("ball_quality", 4)
	golden_litter.set_meta("ball_yardage", 30.0)
	golden_litter.set_meta("ball_golden", true)
	littered_balls.add_child(golden_litter)
	golden_litter.global_position = Vector3(0.0, 0.0, -10.0)
	await process_frame

	var before_golden_currency: float = gs.currency
	start_msec = Time.get_ticks_msec()
	var golden_collected := false
	while Time.get_ticks_msec() - start_msec < 3000:
		await process_frame
		if gs.currency > before_golden_currency and not is_instance_valid(golden_litter):
			golden_collected = true
			break

	if not golden_collected:
		print("FAIL: Rattling did not fetch the golden litter ball within 3s")
		ok = false
	elif not is_equal_approx(gs.currency - before_golden_currency, expected_golden_payout):
		print(
			"FAIL: golden litter should pay %.4f, got %.4f"
			% [expected_golden_payout, gs.currency - before_golden_currency]
		)
		ok = false
	elif ok:
		print("OK: Rattling respects the golden ball payout multiplier end-to-end")

	gs.reset_to_fresh()
	return ok
