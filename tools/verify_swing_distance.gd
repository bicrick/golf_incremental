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
	var contact := charge.contact_time_sec()
	var ok := true

	# Early-release samples: error decreases toward contact → yards must increase.
	var early_errors_ms: Array[float] = [150.0, 120.0, 100.0, 75.0, 50.0, 25.0, 10.0, 0.0]
	var prev_yards := -1.0
	for error_ms in early_errors_ms:
		var hold := contact - error_ms / 1000.0
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

	# Late-release samples: closer to contact → higher yards.
	var late_errors_ms: Array[float] = [300.0, 200.0, 100.0, 35.0, 10.0, 1.0]
	prev_yards = -1.0
	for late_ms in late_errors_ms:
		var hold := contact + late_ms / 1000.0
		var quality := charge.timing_quality(hold, stats)
		var yards := Economy.yards_from_quality(quality, stats)
		if yards <= prev_yards:
			print("FAIL: late +%.0fms yards %.2f not > prev %.2f (quality %.3f)" % [
				late_ms, yards, prev_yards, quality
			])
			ok = false
		prev_yards = yards

	_print_examples(stats, charge, contact)

	ok = _check_balance_targets() and ok
	ok = _check_visual_depth() and ok
	ok = _check_yardage_stack() and ok

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
		"iron_set": UpgradeDefinitions.get_def("iron_set").get("max_level", 0),
		"quality": UpgradeDefinitions.get_def("quality").get("max_level", 0),
		"perfect_pop": UpgradeDefinitions.get_def("perfect_pop").get("max_level", 0),
	}
	UpgradeEffects.apply_all(maxed, max_levels)
	var end_yards := Economy.yards_from_quality(1.0, maxed)
	if end_yards < 300.0:
		print(
			"FAIL: maxed perfect yards expected >= 300, got %.2f (start=%.2f)"
			% [end_yards, start_yards]
		)
		ok = false
	else:
		print(
			"OK: maxed distance perfect yards=%.2f (base=%.2f perfect_pop=%.3f)"
			% [end_yards, maxed.base_yards, maxed.perfect_power_bonus]
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
		"iron_set": UpgradeDefinitions.get_def("iron_set").get("max_level", 0),
		"quality": UpgradeDefinitions.get_def("quality").get("max_level", 0),
		"perfect_pop": UpgradeDefinitions.get_def("perfect_pop").get("max_level", 0),
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

	var end_yards := Economy.yards_from_quality(1.0, maxed)
	var mid_yards := minf(end_yards * 0.6, 80.0)
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
			"OK: maxed depth order 30yd=%.3f %.0fyd=%.3f max=%.3f"
			% [short_t, mid_yards, mid_t, long_t]
		)
		print(
			"OK: mid depth t=%.3f landing_y=%.1f (yards=%.0f)"
			% [mid_t, mid_y, mid_yards]
		)

	var end_t := Economy.visual_depth_t(end_yards, maxed)
	var end_y := _landing_y(end_yards, maxed)
	if end_t < 0.45:
		print("FAIL: maxed perfect depth %.3f too shallow for %.1f yds" % [end_t, end_yards])
		ok = false
	else:
		print(
			"OK: maxed perfect depth t=%.3f landing_y=%.1f (yards=%.1f)"
			% [end_t, end_y, end_yards]
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


func _check_yardage_stack() -> bool:
	var ok := true
	var stack: YardageStack = load("res://scripts/visual/yardage_stack.gd").new()
	root.add_child(stack)

	var id_a := stack.begin(Balance.TimingTier.MISS, 40.0)
	if id_a < 0:
		print("FAIL: yardage stack begin returned invalid id")
		ok = false
	stack.set_progress(id_a, 0.5)
	var yards_label: Label = null
	for child in stack.get_children():
		# Entry root: tier_label, yards_label
		if child.get_child_count() >= 2 and child.get_child(1) is Label:
			yards_label = child.get_child(1)
			break
	if yards_label == null:
		print("FAIL: yardage stack missing yards label after begin")
		ok = false
	elif yards_label.text != YardageStack.format_yards_line(20.0):
		print(
			"FAIL: expected mid-flight '%s', got '%s'"
			% [YardageStack.format_yards_line(20.0), yards_label.text]
		)
		ok = false

	var id_b := stack.begin(Balance.TimingTier.GOOD, 10.0)
	if stack.get_child_count() > YardageStack.MAX_ENTRIES:
		print(
			"FAIL: yardage stack exceeded max entries (%d > %d)"
			% [stack.get_child_count(), YardageStack.MAX_ENTRIES]
		)
		ok = false

	# Third begin should cap at MAX_ENTRIES.
	var _id_c := stack.begin(Balance.TimingTier.PERFECT, 30.0)
	if stack.get_child_count() > YardageStack.MAX_ENTRIES:
		print(
			"FAIL: yardage stack did not trim on third begin (%d)"
			% stack.get_child_count()
		)
		ok = false

	stack.finish(id_a)
	stack.finish(id_b)
	if ok:
		print("OK: yardage stack begin/progress/cap")
	stack.queue_free()
	return ok


func _print_examples(stats: PlayerStats, charge: ChargeSwing, contact: float) -> void:
	print("--- contact swing yard examples (default stats) ---")
	print("CARRY: base_yards × contact_power × perfect_power_bonus (distance-pays)")

	var cases: Array[Dictionary] = [
		{"label": "perfect at contact (0ms)", "hold": contact},
		{"label": "near-perfect early (10ms)", "hold": contact - 0.010},
		{"label": "great edge (40ms)", "hold": contact - 0.040},
		{"label": "good edge (80ms)", "hold": contact - 0.080},
		{"label": "okay edge (140ms)", "hold": contact - 0.140},
		{"label": "late great edge (+15ms)", "hold": contact + 0.015},
	]

	for case in cases:
		var hold: float = case["hold"]
		var tier := charge.evaluate_timing(hold, stats)
		var quality := charge.timing_quality(hold, stats)
		var new_yards := Economy.yards_from_quality(quality, stats)
		print(
			"%s | tier=%s quality=%.3f | carry=%.2f yds"
			% [case["label"], Balance.TIER_NAMES[tier], quality, new_yards]
		)
