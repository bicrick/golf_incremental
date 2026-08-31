extends SceneTree
## Headless upgrade effect direction test — run:
## godot --headless --script res://tools/verify_upgrade_effects.gd


const PERFECT := Balance.TimingTier.PERFECT
const SAMPLE_YARDAGE := 30.0
const SAMPLE_QUALITY := 6


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		quit(1)
		return

	var cases: Array[Dictionary] = [
		{"id": "base_pay", "prereq_levels": {}},
		{"id": "distance_pay", "prereq_levels": {"base_pay": 1}},
		{"id": "iron_set", "prereq_levels": {"base_pay": 1, "distance_pay": 1}},
		{"id": "quality", "prereq_levels": {"base_pay": 1}},
		{"id": "perfect_pop", "prereq_levels": {"base_pay": 1, "quality": 3}},
		{"id": "metronome", "prereq_levels": {"base_pay": 1, "quality": 1}},
		{"id": "pickup", "prereq_levels": {"base_pay": 1}},
	]

	for case in cases:
		var id: String = case["id"]
		gs.currency = 1_000_000.0
		gs.upgrade_levels = case["prereq_levels"].duplicate()
		gs._recompute_stats()
		var before := _snapshot(gs)
		if not gs.purchase_upgrade(id):
			print("FAIL [%s]: purchase failed" % id)
			ok = false
			continue
		var after := _snapshot(gs)
		var err := _check_upgrade(id, before, after)
		if not err.is_empty():
			print("FAIL [%s]: %s" % [id, err])
			ok = false
		else:
			print(
				"OK [%s] perfect_yards %.2f->%.2f pickup %.4f->%.4f depth %.3f->%.3f" % [
					id,
					before.perfect_yards,
					after.perfect_yards,
					before.pickup_payout,
					after.pickup_payout,
					before.visual_depth,
					after.visual_depth,
				]
			)

	ok = _check_distance_curve(gs) and ok
	ok = _check_pickup_formula(gs) and ok

	print("upgrade_effects_ok=", ok)
	quit(0 if ok else 1)


func _check_pickup_formula(gs: Node) -> bool:
	gs.upgrade_levels = {}
	gs._recompute_stats()
	var flat := Economy.resolve_pickup_ball_payout(1, SAMPLE_YARDAGE, 1, gs.stats)
	if not is_equal_approx(flat, 0.35):
		print("FAIL: fresh pickup expected $0.35, got %.4f" % flat)
		return false

	gs.upgrade_levels = {"base_pay": 1, "distance_pay": 1}
	gs._recompute_stats()
	var with_yardage := Economy.resolve_pickup_ball_payout(
		SAMPLE_QUALITY, SAMPLE_YARDAGE, 1, gs.stats
	)
	var expected_yardage: float = (
		gs.stats.base_amount + gs.stats.base_amount * gs.stats.pay_per_yard * SAMPLE_YARDAGE
	)
	if not is_equal_approx(with_yardage, expected_yardage):
		print(
			"FAIL: additive yardage pickup expected %.4f, got %.4f"
			% [expected_yardage, with_yardage]
		)
		return false

	var short := Economy.resolve_pickup_ball_payout(1, 15.0, 1, gs.stats)
	if short < gs.stats.base_amount:
		print("FAIL: short-yard pickup %.4f below base %.4f" % [short, gs.stats.base_amount])
		return false

	# Quality / Sweet Spot must NOT multiply pickup cash — only flight.
	gs.upgrade_levels = {"base_pay": 1, "distance_pay": 1, "quality": 5}
	gs._recompute_stats()
	var with_sweet := Economy.resolve_pickup_ball_payout(SAMPLE_QUALITY, SAMPLE_YARDAGE, 1, gs.stats)
	if not is_equal_approx(with_sweet, expected_yardage):
		print(
			"FAIL: Sweet Spot must not change pickup for fixed yards (expected %.4f, got %.4f)"
			% [expected_yardage, with_sweet]
		)
		return false

	gs.upgrade_levels = {"base_pay": 1, "pickup": 1, "combo_bonus": 1}
	gs._recompute_stats()
	var combo2 := Economy.resolve_pickup_ball_payout(1, SAMPLE_YARDAGE, 2, gs.stats)
	var combo1 := Economy.resolve_pickup_ball_payout(1, SAMPLE_YARDAGE, 1, gs.stats)
	if not is_equal_approx(combo2, combo1 * 1.08):
		print("FAIL: combo tier 2 expected 1.08x, got %.4f vs %.4f" % [combo2, combo1])
		return false

	gs.upgrade_levels = {"base_pay": 1, "ball_count": 2}
	gs._recompute_stats()
	if gs.get_bucket_capacity() != Balance.BUCKET_CAPACITY_DEFAULT + 2:
		print(
			"FAIL: ball_count capacity expected %d, got %d"
			% [Balance.BUCKET_CAPACITY_DEFAULT + 2, gs.get_bucket_capacity()]
		)
		return false

	gs.upgrade_levels = {"base_pay": 1, "quick_reset": 1}
	gs._recompute_stats()
	var expected_cd := Balance.default_stats().swing_cooldown_ms * 0.85
	if not is_equal_approx(gs.stats.swing_cooldown_ms, expected_cd):
		print(
			"FAIL: quick_reset cooldown expected %.1f, got %.1f"
			% [expected_cd, gs.stats.swing_cooldown_ms]
		)
		return false

	gs.upgrade_levels = {"base_pay": 1, "golden_ball": 3}
	gs._recompute_stats()
	if not is_equal_approx(gs.stats.golden_ball_chance, 0.06):
		print("FAIL: golden_ball chance expected 0.06, got %.3f" % gs.stats.golden_ball_chance)
		return false

	gs.upgrade_levels = {"base_pay": 1, "perfect_chain": 1}
	gs._recompute_stats()
	if int(gs.stats.perfect_chain_unlocked) < 1:
		print("FAIL: perfect_chain should unlock flag")
		return false

	print("OK: pickup formula unlock stages (distance-pays)")
	gs.upgrade_levels = {
		"base_pay": 1,
		"distance_pay": UpgradeDefinitions.get_def("distance_pay").get("max_level", 0),
	}
	gs._recompute_stats()
	var max_ppy: float = gs.stats.pay_per_yard
	if max_ppy < 8.0 or max_ppy > 12.0:
		print("FAIL: max Yardage Pay expected ~10.0 $/yd, got %.3f" % max_ppy)
		return false
	print("OK: max Yardage Pay pay_per_yard=%.2f" % max_ppy)
	return true


func _check_distance_curve(gs: Node) -> bool:
	var ok := true
	gs.upgrade_levels = {}
	gs._recompute_stats()
	var start_yards := Economy.yards_from_quality(1.0, gs.stats)
	if absf(start_yards - 30.0) > 1.5:
		print("FAIL: fresh save perfect yards expected ~30, got %.2f" % start_yards)
		ok = false
	else:
		print("OK: fresh save perfect yards=%.2f" % start_yards)

	var max_levels := {
		"iron_set": UpgradeDefinitions.get_def("iron_set").get("max_level", 0),
		"quality": UpgradeDefinitions.get_def("quality").get("max_level", 0),
		"perfect_pop": UpgradeDefinitions.get_def("perfect_pop").get("max_level", 0),
	}
	gs.upgrade_levels = max_levels
	gs._recompute_stats()
	var end_yards := Economy.yards_from_quality(1.0, gs.stats)
	if end_yards < 300.0:
		print(
			"FAIL: maxed power/contact perfect yards expected >= 300, got %.2f"
			% end_yards
		)
		ok = false
	else:
		print(
			"OK: maxed distance perfect yards=%.2f (base=%.2f perfect_pop=%.3f)"
			% [end_yards, gs.stats.base_yards, gs.stats.perfect_power_bonus]
		)

	var raw_max := {"iron_set": max_levels["iron_set"]}
	gs.upgrade_levels = raw_max
	gs._recompute_stats()
	var raw_only_yards := Economy.yards_from_quality(1.0, gs.stats)
	if raw_only_yards < 140.0:
		print(
			"FAIL: max raw power only expected >= 140 yd, got %.2f"
			% raw_only_yards
		)
		ok = false
	elif raw_only_yards >= 220.0:
		print(
			"FAIL: max raw power only expected < 220 yd (on fairway), got %.2f"
			% raw_only_yards
		)
		ok = false
	else:
		print("OK: max raw power only perfect yards=%.2f" % raw_only_yards)

	# Steeper contact gap: Perfect should outpace Miss more than before.
	gs.upgrade_levels = {}
	gs._recompute_stats()
	var perfect_yd := Economy.yards_from_quality(1.0, gs.stats)
	var miss_yd := Economy.yards_from_quality(Balance.TIER_MULTS[5], gs.stats)
	var ratio := perfect_yd / maxf(miss_yd, 0.01)
	if ratio < 10.0:
		print("FAIL: Perfect/Miss yard ratio expected >= 10, got %.2f" % ratio)
		ok = false
	else:
		print("OK: Perfect/Miss yard ratio=%.2f" % ratio)
	return ok


func _snapshot(gs: Node) -> Dictionary:
	var stats: PlayerStats = gs.stats
	var perfect := Economy.resolve_payout(PERFECT, stats)
	return {
		"stats": stats,
		"perfect_yards": perfect.yards,
		"pickup_payout": Economy.resolve_pickup_ball_payout(
			SAMPLE_QUALITY, SAMPLE_YARDAGE, 1, stats
		),
		"visual_depth": _visual_depth_for(stats, PERFECT),
	}


func _visual_depth_for(stats: PlayerStats, timing_tier: int) -> float:
	var result := Economy.resolve_payout(timing_tier, stats)
	return Economy.visual_depth_t(result.yards, stats)


func _check_upgrade(id: String, before: Dictionary, after: Dictionary) -> String:
	var b_stats: PlayerStats = before.stats
	var a_stats: PlayerStats = after.stats
	match id:
		"base_pay":
			if not is_equal_approx(a_stats.base_amount, 0.4025):
				return "base_amount expected $0.4025 at Lv.1, got %.2f" % a_stats.base_amount
			if a_stats.base_amount <= b_stats.base_amount:
				return "base_amount did not increase"
			if after.pickup_payout <= before.pickup_payout:
				return "pickup payout did not increase"
		"distance_pay":
			if a_stats.yardage_term_unlocked <= b_stats.yardage_term_unlocked:
				return "yardage_term_unlocked did not flip on"
			if a_stats.pay_per_yard <= b_stats.pay_per_yard:
				return "pay_per_yard did not increase"
		"quality":
			if a_stats.sweet_spot_unlocked <= b_stats.sweet_spot_unlocked:
				return "sweet_spot_unlocked did not flip on"
			if a_stats.sweet_spot_bonus <= b_stats.sweet_spot_bonus:
				return "sweet_spot_bonus did not increase"
			var mid_before := Economy.yards_from_quality(0.75, b_stats)
			var mid_after := Economy.yards_from_quality(0.75, a_stats)
			if mid_after <= mid_before:
				return "Great-band yards should rise with Sweet Spot"
		"perfect_pop":
			if a_stats.perfect_power_bonus <= b_stats.perfect_power_bonus:
				return "perfect_power_bonus did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"iron_set":
			if not is_equal_approx(a_stats.base_yards, b_stats.base_yards + 3.0):
				return "base_yards expected +3 at Lv.1, got %.2f" % a_stats.base_yards
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"metronome":
			if a_stats.timing_window_perfect_ms <= b_stats.timing_window_perfect_ms:
				return "timing_window_perfect_ms did not increase"
		"pickup":
			if a_stats.pickup_bonus_unlocked <= b_stats.pickup_bonus_unlocked:
				return "pickup_bonus_unlocked did not flip on"
	return ""
