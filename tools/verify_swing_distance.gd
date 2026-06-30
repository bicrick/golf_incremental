extends SceneTree
## Headless swing distance monotonicity test — run:
## godot --headless --script res://tools/verify_swing_distance.gd

const TEE_Y := 206.0
const HORIZON_GROUND_Y := 113.0  # FAIRWAY_TOP_Y (105) + LANDING_Y_MARGIN (8)


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

	ok = _check_balance_targets() and ok
	ok = _check_visual_depth() and ok

	print("swing_distance_ok=", ok)
	quit(0 if ok else 1)


func _check_balance_targets() -> bool:
	var ok := true
	var default_stats := Balance.default_stats()
	var start_yards := Economy.yards_from_quality(1.0, default_stats)
	if absf(start_yards - 30.0) > 1.5:
		print("FAIL: default perfect yards expected ~30, got %.2f" % start_yards)
		ok = false
	else:
		print("OK: default perfect yards=%.2f" % start_yards)

	var maxed := Balance.default_stats()
	var max_levels := {
		"power": UpgradeDefinitions.get_def("power").get("max_level", 0),
		"leg_day": UpgradeDefinitions.get_def("leg_day").get("max_level", 0),
		"followthrough_form": UpgradeDefinitions.get_def("followthrough_form").get("max_level", 0),
		"core_strength": UpgradeDefinitions.get_def("core_strength").get("max_level", 0),
	}
	UpgradeEffects.apply_all(maxed, max_levels)
	var end_yards := Economy.yards_from_quality(1.0, maxed)
	if end_yards < 480.0:
		print("FAIL: maxed distance perfect yards expected ~500+, got %.2f" % end_yards)
		ok = false
	elif end_yards > 560.0:
		print("FAIL: maxed distance perfect yards unexpectedly high %.2f" % end_yards)
		ok = false
	else:
		print(
			"OK: maxed distance perfect yards=%.2f (base=%.2f mult=%.3f cap=%.0f)"
			% [end_yards, maxed.base_yards, maxed.yard_multiplier, maxed.max_yards]
		)
	return ok


func _ground_y_for_depth(t: float) -> float:
	return lerpf(TEE_Y, HORIZON_GROUND_Y, t)


func _landing_y(yards: float, stats: PlayerStats) -> float:
	return Economy.visual_landing_y(yards, TEE_Y, HORIZON_GROUND_Y, stats)


func _check_visual_depth() -> bool:
	var ok := true
	var default_stats := Balance.default_stats()
	var maxed := Balance.default_stats()
	var max_levels := {
		"power": UpgradeDefinitions.get_def("power").get("max_level", 0),
		"leg_day": UpgradeDefinitions.get_def("leg_day").get("max_level", 0),
		"followthrough_form": UpgradeDefinitions.get_def("followthrough_form").get("max_level", 0),
		"core_strength": UpgradeDefinitions.get_def("core_strength").get("max_level", 0),
	}
	UpgradeEffects.apply_all(maxed, max_levels)

	var start_yards := Economy.yards_from_quality(1.0, default_stats)
	var start_t := Economy.visual_depth_t(start_yards, default_stats)
	var start_y := _landing_y(start_yards, default_stats)
	if start_t >= 0.95:
		print("FAIL: default perfect visual depth %.3f too far (expected well below horizon)" % start_t)
		ok = false
	elif start_y < 190.0 or start_y > 202.0:
		print("FAIL: default perfect landing_y=%.1f expected near tee (190-202)" % start_y)
		ok = false
	else:
		print(
			"OK: default perfect depth t=%.3f landing_y=%.1f (yards=%.1f visual_max=%.0f)"
			% [start_t, start_y, start_yards, Balance.VISUAL_MAX_YARDS]
		)

	var mid_yards := 150.0
	var end_yards := Economy.yards_from_quality(1.0, maxed)
	var mid_t := Economy.visual_depth_t(mid_yards, maxed)
	var mid_y := _landing_y(mid_yards, maxed)
	var short_t := Economy.visual_depth_t(30.0, maxed)
	var long_t := Economy.visual_depth_t(end_yards, maxed)
	if short_t >= mid_t or mid_t >= long_t:
		print(
			"FAIL: maxed depth order 30yd=%.3f 150yd=%.3f max=%.3f not increasing"
			% [short_t, mid_t, long_t]
		)
		ok = false
	else:
		print(
			"OK: maxed depth order 30yd=%.3f 150yd=%.3f max=%.3f"
			% [short_t, mid_t, long_t]
		)
		print(
			"OK: 150yd depth t=%.3f landing_y=%.1f (max_yards=%.0f)"
			% [mid_t, mid_y, maxed.max_yards]
		)

	var end_t := Economy.visual_depth_t(end_yards, maxed)
	var end_y := _landing_y(end_yards, maxed)
	if end_t < 0.95:
		print("FAIL: maxed perfect depth %.3f should reach horizon (~1.0)" % end_t)
		ok = false
	else:
		print(
			"OK: maxed perfect depth t=%.3f landing_y=%.1f (yards=%.1f max=%.0f)"
			% [end_t, end_y, end_yards, maxed.max_yards]
		)

	# Tier must not inflate depth — same yards, different tiers → same t.
	var good_yards := Economy.yards_from_quality(0.7, default_stats)
	var good_t := Economy.visual_depth_t(good_yards, default_stats)
	var miss_yards := Economy.yards_from_quality(0.1, default_stats)
	var miss_t := Economy.visual_depth_t(miss_yards, default_stats)
	if good_yards > miss_yards and miss_t > good_t + 0.001:
		print(
			"FAIL: depth order miss_t=%.3f > good_t=%.3f (yards %.1f vs %.1f)"
			% [miss_t, good_t, miss_yards, good_yards]
		)
		ok = false
	elif start_yards > good_yards and good_t > start_t + 0.001:
		print(
			"FAIL: depth order good_t=%.3f > perfect_t=%.3f (yards %.1f vs %.1f)"
			% [good_t, start_t, good_yards, start_yards]
		)
		ok = false
	else:
		print("OK: depth tracks yards only (perfect=%.3f good=%.3f miss=%.3f)" % [
			start_t, good_t, miss_t
		])

	var y30 := _landing_y(30.0, maxed)
	var y100 := _landing_y(100.0, maxed)
	var y150 := _landing_y(150.0, maxed)
	var y300 := _landing_y(300.0, maxed)
	if y30 < 190.0 or y30 > 202.0:
		print("FAIL: 30yd landing_y=%.1f expected near tee (190-202)" % y30)
		ok = false
	if absf(y300 - HORIZON_GROUND_Y) > 1.0:
		print("FAIL: 300yd landing_y=%.1f expected horizon (%.1f)" % [y300, HORIZON_GROUND_Y])
		ok = false
	if y150 < 140.0 or y150 > 156.0:
		print("FAIL: 150yd landing_y=%.1f expected mid range (140-156)" % y150)
		ok = false
	if y150 >= y30 or y150 <= y300:
		print("FAIL: 150yd landing_y=%.1f expected between 30yd (%.1f) and 300yd (%.1f)" % [
			y150, y30, y300
		])
		ok = false

	# Far yard gaps should compress more than near gaps (parallax).
	var near_gap := y30 - y100
	var far_gap := _landing_y(250.0, maxed) - y300
	if far_gap >= near_gap:
		print(
			"FAIL: far 250-300yd gap %.1fpx should be smaller than near 30-100yd gap %.1fpx"
			% [far_gap, near_gap]
		)
		ok = false
	else:
		print("OK: parallax compression near_gap=%.1fpx far_gap=%.1fpx" % [near_gap, far_gap])

	print("--- visual depth formula ---")
	print(
		"norm = (1 - exp(-yards / %.0f)) / (1 - exp(-%.0f / %.0f)); t = pow(norm, %.1f); landing_y = lerp(%.0f, %.0f, t)"
		% [
			Balance.PERSPECTIVE_DEPTH_SCALE,
			Balance.VISUAL_MAX_YARDS,
			Balance.PERSPECTIVE_DEPTH_SCALE,
			Balance.PERSPECTIVE_DEPTH_EXPONENT,
			TEE_Y,
			HORIZON_GROUND_Y,
		]
	)
	print("landing Y table: 30yd→%.1f 100yd→%.1f 150yd→%.1f 300yd→%.1f" % [y30, y100, y150, y300])
	return ok


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
