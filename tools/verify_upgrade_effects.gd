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
		{"id": "power", "prereq_levels": {"base_pay": 1}},
		{"id": "distance_pay", "prereq_levels": {"base_pay": 1, "power": 1}},
		{"id": "quality", "prereq_levels": {"base_pay": 1}},
		{"id": "iron_set", "prereq_levels": {"base_pay": 1, "power": 1, "distance_pay": 1}},
		{"id": "power_surge", "prereq_levels": {"base_pay": 1, "power": 1, "distance_pay": 1}},
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
	if not is_equal_approx(flat, 0.25):
		print("FAIL: fresh pickup expected $0.25, got %.4f" % flat)
		return false

	gs.upgrade_levels = {"base_pay": 1, "power": 1, "distance_pay": 1}
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

	gs.upgrade_levels = {"base_pay": 1, "power": 1, "distance_pay": 1, "quality": 1}
	gs._recompute_stats()
	var full := Economy.resolve_pickup_ball_payout(SAMPLE_QUALITY, SAMPLE_YARDAGE, 1, gs.stats)
	var shot: float = gs.stats.base_amount + gs.stats.base_amount * gs.stats.pay_per_yard * SAMPLE_YARDAGE
	var expected_full: float = shot * float(SAMPLE_QUALITY) * gs.stats.quality_multiplier
	if not is_equal_approx(full, expected_full):
		print("FAIL: full pickup expected %.4f, got %.4f" % [expected_full, full])
		return false

	gs.upgrade_levels = {"base_pay": 1, "pickup": 1, "combo_bonus": 1}
	gs._recompute_stats()
	var combo2 := Economy.resolve_pickup_ball_payout(1, SAMPLE_YARDAGE, 2, gs.stats)
	var combo1 := Economy.resolve_pickup_ball_payout(1, SAMPLE_YARDAGE, 1, gs.stats)
	if not is_equal_approx(combo2, combo1 * 1.10):
		print("FAIL: combo tier 2 expected 1.10x, got %.4f vs %.4f" % [combo2, combo1])
		return false

	print("OK: pickup formula unlock stages")
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

	var max_levels := {}
	for id in ["power", "distance_pay", "iron_set", "power_surge"]:
		max_levels[id] = UpgradeDefinitions.get_def(id).get("max_level", 0)
	gs.upgrade_levels = max_levels
	gs._recompute_stats()
	var end_yards := Economy.yards_from_quality(1.0, gs.stats)
	if end_yards < start_yards * 3.0:
		print(
			"FAIL: maxed distance perfect yards expected well above start, got %.2f"
			% end_yards
		)
		ok = false
	else:
		print(
			"OK: maxed distance perfect yards=%.2f (base=%.2f carry=%.3f)"
			% [end_yards, gs.stats.base_yards, gs.stats.carry_multiplier]
		)
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
			if not is_equal_approx(a_stats.base_amount, 0.2875):
				return "base_amount expected $0.2875 at Lv.1, got %.2f" % a_stats.base_amount
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
			if a_stats.quality_term_unlocked <= b_stats.quality_term_unlocked:
				return "quality_term_unlocked did not flip on"
			if a_stats.quality_multiplier <= b_stats.quality_multiplier:
				return "quality_multiplier did not increase"
		"power", "power_surge":
			if a_stats.carry_multiplier <= b_stats.carry_multiplier:
				return "carry_multiplier did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"iron_set":
			if a_stats.base_yards <= b_stats.base_yards:
				return "base_yards did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"metronome":
			if a_stats.timing_window_perfect_ms <= b_stats.timing_window_perfect_ms:
				return "timing_window_perfect_ms did not increase"
		"pickup":
			if a_stats.pickup_bonus_unlocked <= b_stats.pickup_bonus_unlocked:
				return "pickup_bonus_unlocked did not flip on"
	return ""
