extends SceneTree
## Headless swing distance monotonicity test — run:
## godot --headless --script res://tools/verify_swing_distance.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stats := Balance.default_stats()
	var charge := ChargeSwing.new()
	var peak := charge.charge_duration_sec()
	var ok := true

	# Early-release samples: error decreases toward peak → yards must increase.
	var early_errors_ms: Array[float] = [150.0, 120.0, 100.0, 75.0, 50.0, 25.0, 10.0, 0.0]
	var prev_yards := -1.0
	for error_ms in early_errors_ms:
		var hold := peak - error_ms / 1000.0
		var quality := charge.timing_quality(hold, stats)
		var yards := Economy.yards_from_quality(quality, stats)
		var tier := charge.evaluate_timing(hold, stats)
		if yards <= prev_yards:
			print(
				"FAIL: early error %.0fms yards %.2f not > prev %.2f (tier %s quality %.3f)"
				% [error_ms, yards, prev_yards, Balance.TIER_NAMES[tier], quality]
			)
			ok = false
		prev_yards = yards

	# Late-release samples: closer to peak → higher yards.
	var late_errors_ms: Array[float] = [300.0, 200.0, 100.0, 35.0, 10.0, 1.0]
	prev_yards = -1.0
	for late_ms in late_errors_ms:
		var hold := peak + late_ms / 1000.0
		var quality := charge.timing_quality(hold, stats)
		var yards := Economy.yards_from_quality(quality, stats)
		if yards <= prev_yards:
			print("FAIL: late +%.0fms yards %.2f not > prev %.2f (quality %.3f)" % [
				late_ms, yards, prev_yards, quality
			])
			ok = false
		prev_yards = yards

	_print_examples(stats, charge, peak)

	print("swing_distance_ok=", ok)
	quit(0 if ok else 1)


func _print_examples(stats: PlayerStats, charge: ChargeSwing, peak: float) -> void:
	print("--- yard formula comparison (default stats) ---")
	print("OLD: min(base_yards * yard_mult * TIER_MULT[tier], max_yards)")
	print("NEW: min(base_yards * yard_mult * timing_quality, max_yards); tier mult on payout only")

	var cases: Array[Dictionary] = [
		{"label": "perfect center (0ms)", "hold": peak},
		{"label": "near-perfect early (10ms)", "hold": peak - 0.010},
		{"label": "perfect edge (50ms)", "hold": peak - 0.050},
		{"label": "good edge (100ms)", "hold": peak - 0.100},
		{"label": "late good edge (+35ms)", "hold": peak + 0.035},
	]

	for case in cases:
		var hold: float = case["hold"]
		var tier := charge.evaluate_timing(hold, stats)
		var quality := charge.timing_quality(hold, stats)
		var new_yards := Economy.yards_from_quality(quality, stats)
		var old_yards := Economy.yards_from_tier(tier, stats)
		print(
			"%s | tier=%s quality=%.3f | old=%.2f yds new=%.2f yds"
			% [case["label"], Balance.TIER_NAMES[tier], quality, old_yards, new_yards]
		)
