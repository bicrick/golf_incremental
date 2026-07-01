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
		{"id": "bucket_size", "prereq_levels": {"base_pay": 1}},
		{"id": "yardage_markers", "prereq_levels": {"base_pay": 15}},
		{"id": "yardage", "prereq_levels": {"base_pay": 15, "yardage_markers": 1}},
		{"id": "carry_form", "prereq_levels": {"base_pay": 15, "yardage_markers": 1, "yardage": 1}},
		{"id": "yardage_cap", "prereq_levels": {
			"base_pay": 15, "yardage_markers": 1, "yardage": 1, "carry_form": 1
		}},
		{"id": "carry_power", "prereq_levels": {"base_pay": 15, "yardage_markers": 1}},
		{"id": "yardage_mult", "prereq_levels": {"base_pay": 15, "yardage_markers": 1}},
		{"id": "contact_awareness", "prereq_levels": {"base_pay": 15, "yardage_markers": 1, "yardage_mult": 15}},
		{"id": "contact_training", "prereq_levels": {
			"base_pay": 15, "yardage_markers": 1, "yardage_mult": 15, "contact_awareness": 1
		}},
		{"id": "quality_mult", "prereq_levels": {
			"base_pay": 15, "yardage_markers": 1, "yardage_mult": 15, "contact_awareness": 1
		}},
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
	gs.upgrade_levels = {"base_pay": 15, "yardage_markers": 1}
	gs._recompute_stats()
	var with_yardage := Economy.resolve_pickup_ball_payout(
		1, SAMPLE_YARDAGE, 1, gs.stats
	)
	var expected_yardage: float = gs.stats.base_amount * SAMPLE_YARDAGE * gs.stats.yardage_multiplier
	if not is_equal_approx(with_yardage, expected_yardage):
		print(
			"FAIL: yardage pickup expected %.4f, got %.4f"
			% [expected_yardage, with_yardage]
		)
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
	for id in ["yardage", "carry_form", "yardage_cap", "carry_power"]:
		max_levels[id] = UpgradeDefinitions.get_def(id).get("max_level", 0)
	gs.upgrade_levels = max_levels
	gs._recompute_stats()
	var end_yards := Economy.yards_from_quality(1.0, gs.stats)
	if end_yards < 280.0:
		print("FAIL: maxed distance perfect yards expected ~300, got %.2f" % end_yards)
		ok = false
	elif end_yards > 305.0:
		print("FAIL: maxed distance perfect yards unexpectedly high %.2f" % end_yards)
		ok = false
	else:
		print(
			"OK: maxed distance perfect yards=%.2f (base=%.2f cap=%.0f)"
			% [end_yards, gs.stats.base_yards, gs.stats.max_yards]
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
			if a_stats.base_amount <= b_stats.base_amount:
				return "base_amount did not increase"
			if after.pickup_payout <= before.pickup_payout:
				return "pickup payout did not increase"
		"bucket_size":
			if a_stats.bucket_capacity_bonus <= b_stats.bucket_capacity_bonus:
				return "bucket_capacity_bonus did not increase"
		"yardage_markers":
			if a_stats.yardage_term_unlocked <= b_stats.yardage_term_unlocked:
				return "yardage_term_unlocked did not flip on"
		"yardage":
			if a_stats.base_yards <= b_stats.base_yards:
				return "base_yards did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"yardage_cap":
			if a_stats.max_yards <= b_stats.max_yards:
				return "max_yards did not increase"
		"carry_form":
			if a_stats.yard_multiplier <= b_stats.yard_multiplier:
				return "yard_multiplier did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"carry_power":
			if a_stats.yard_multiplier <= b_stats.yard_multiplier:
				return "yard_multiplier did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"yardage_mult":
			if a_stats.yardage_multiplier <= b_stats.yardage_multiplier:
				return "yardage_multiplier did not increase"
			if after.pickup_payout <= before.pickup_payout:
				return "pickup payout did not increase"
		"contact_awareness":
			if a_stats.quality_term_unlocked <= b_stats.quality_term_unlocked:
				return "quality_term_unlocked did not flip on"
		"contact_training":
			if a_stats.timing_window_perfect_ms <= b_stats.timing_window_perfect_ms:
				return "timing_window_perfect_ms did not increase"
		"quality_mult":
			if a_stats.quality_multiplier <= b_stats.quality_multiplier:
				return "quality_multiplier did not increase"
			if after.pickup_payout <= before.pickup_payout:
				return "pickup payout did not increase"
	return ""
