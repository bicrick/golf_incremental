extends SceneTree
## Headless upgrade effect direction test — run:
## godot --headless --script res://tools/verify_upgrade_effects.gd


const PERFECT := Balance.TimingTier.PERFECT


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
		{"id": "power", "prereq_levels": {}},
		{"id": "leg_day", "prereq_levels": {"power": 1}},
		{"id": "followthrough_form", "prereq_levels": {"power": 1, "leg_day": 1}},
		{"id": "core_strength", "prereq_levels": {"power": 1, "leg_day": 1, "followthrough_form": 1}},
		{"id": "metronome", "prereq_levels": {"power": 1}},
		{"id": "faster_followthrough", "prereq_levels": {"power": 1, "metronome": 1}},
		{"id": "perfect_bonus", "prereq_levels": {"power": 1, "metronome": 1, "faster_followthrough": 1}},
		{"id": "dollars_per_yard", "prereq_levels": {"power": 1}},
		{"id": "tip_jar", "prereq_levels": {"power": 1, "dollars_per_yard": 1}},
		{"id": "sponsorship", "prereq_levels": {"power": 1, "dollars_per_yard": 1, "tip_jar": 1}},
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
				"OK [%s] perfect_yards %.2f->%.2f payout %.2f->%.2f depth %.3f->%.3f" % [
					id,
					before.perfect_yards,
					after.perfect_yards,
					before.perfect_payout,
					after.perfect_payout,
					before.visual_depth,
					after.visual_depth,
				]
			)

	print("upgrade_effects_ok=", ok)
	quit(0 if ok else 1)


func _snapshot(gs: Node) -> Dictionary:
	var stats: PlayerStats = gs.stats
	var perfect := Economy.resolve_payout(PERFECT, stats)
	return {
		"stats": stats,
		"perfect_yards": perfect.yards,
		"perfect_payout": perfect.payout,
		"visual_depth": _visual_depth_for(stats, PERFECT),
	}


func _visual_depth_for(stats: PlayerStats, timing_tier: int) -> float:
	var result := Economy.resolve_payout(timing_tier, stats)
	var visual_max := maxf(stats.base_yards * stats.yard_multiplier, 1.0)
	return clampf(result.yards / visual_max, 0.08, 1.0)


func _check_upgrade(id: String, before: Dictionary, after: Dictionary) -> String:
	var b_stats: PlayerStats = before.stats
	var a_stats: PlayerStats = after.stats
	match id:
		"power":
			if a_stats.yard_multiplier <= b_stats.yard_multiplier:
				return "yard_multiplier did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"leg_day":
			if a_stats.base_yards <= b_stats.base_yards:
				return "base_yards did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"followthrough_form":
			if a_stats.yard_multiplier <= b_stats.yard_multiplier:
				return "yard_multiplier did not increase"
			if after.perfect_yards <= before.perfect_yards:
				return "perfect yards did not increase"
		"core_strength":
			if a_stats.max_yards <= b_stats.max_yards:
				return "max_yards did not increase"
			if after.perfect_yards < before.perfect_yards - 0.001:
				return "perfect yards decreased (%.2f -> %.2f)" % [
					before.perfect_yards, after.perfect_yards
				]
			if after.visual_depth < before.visual_depth - 0.001:
				return "visual depth decreased (%.3f -> %.3f)" % [
					before.visual_depth, after.visual_depth
				]
		"metronome":
			if a_stats.timing_window_perfect_ms <= b_stats.timing_window_perfect_ms:
				return "timing_window_perfect_ms did not increase"
		"faster_followthrough":
			if a_stats.swing_cooldown_ms >= b_stats.swing_cooldown_ms:
				return "swing_cooldown_ms did not decrease"
		"perfect_bonus":
			if a_stats.perfect_payout_bonus <= b_stats.perfect_payout_bonus:
				return "perfect_payout_bonus did not increase"
			if after.perfect_payout <= before.perfect_payout:
				return "perfect payout did not increase"
		"dollars_per_yard":
			if a_stats.dollars_per_yard <= b_stats.dollars_per_yard:
				return "dollars_per_yard did not increase"
			if after.perfect_payout <= before.perfect_payout:
				return "perfect payout did not increase"
		"tip_jar":
			if a_stats.flat_bonus_per_swing <= b_stats.flat_bonus_per_swing:
				return "flat_bonus_per_swing did not increase"
			if after.perfect_payout <= before.perfect_payout:
				return "perfect payout did not increase"
		"sponsorship":
			if a_stats.global_multiplier <= b_stats.global_multiplier:
				return "global_multiplier did not increase"
			if after.perfect_payout <= before.perfect_payout:
				return "perfect payout did not increase"
	return ""
