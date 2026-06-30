extends SceneTree
## Headless ball flight rendering tests — run:
## godot --headless --script res://tools/verify_ball_flight.gd

const TEE_X := 248.0
const TEE_Y := 206.0
const HORIZON_GROUND_Y := 113.0
const MAT_BACK_Y := 195.0
const VANISHING_POINT := Vector2(240.0, 100.0)
const FAR_SCALE := 0.30


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_scale_monotonic() and ok
	ok = _check_landing_scale_alignment() and ok
	ok = _check_arc_from_hit() and ok
	ok = _check_scale_bounds() and ok
	ok = _check_fairway_travel() and ok
	ok = _check_vanish_into_distance() and ok
	print("ball_flight_ok=", ok)
	quit(0 if ok else 1)


func _make_config() -> BallFlightRenderer.FlightConfig:
	var config := BallFlightRenderer.FlightConfig.new()
	config.tee_x = TEE_X
	config.tee_y = TEE_Y
	config.horizon_ground_y = HORIZON_GROUND_Y
	config.mat_back_y = MAT_BACK_Y
	config.vanishing_point = VANISHING_POINT
	config.far_scale = FAR_SCALE
	config.flight_depth_exponent = 0.34
	config.flight_depth_stretch = 1.20
	config.min_landing_y = 176.0
	config.arc_min_px = 12.0
	config.arc_max_px = 40.0
	config.landing_scatter_x = 28.0
	config.range_x_min = 24.0
	config.range_x_max = 456.0
	return config


func _maxed_stats() -> PlayerStats:
	var stats := Balance.default_stats()
	var max_levels := {
		"power": UpgradeDefinitions.get_def("power").get("max_level", 0),
		"leg_day": UpgradeDefinitions.get_def("leg_day").get("max_level", 0),
		"followthrough_form": UpgradeDefinitions.get_def("followthrough_form").get("max_level", 0),
		"core_strength": UpgradeDefinitions.get_def("core_strength").get("max_level", 0),
	}
	UpgradeEffects.apply_all(stats, max_levels)
	return stats


func _check_scale_monotonic() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _maxed_stats()
	for yards in [30.0, 100.0, 150.0, 300.0]:
		var path := BallFlightRenderer.build_path(
			yards, Balance.TimingTier.PERFECT, stats, config
		)
		var prev_scale := INF
		for step in 21:
			var progress := float(step) / 20.0
			var sample := BallFlightRenderer.sample(progress, path, config)
			var scale_factor: float = sample["scale_factor"]
			if scale_factor > prev_scale + 0.0001:
				print(
					"FAIL: scale not monotonic at %.0fyd progress %.2f scale %.4f > prev %.4f"
					% [yards, progress, scale_factor, prev_scale]
				)
				ok = false
				break
			prev_scale = scale_factor
	if ok:
		print("OK: scale monotonically decreases over flight progress")
	return ok


func _check_landing_scale_alignment() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _maxed_stats()
	for yards in [30.0, 150.0, 300.0]:
		var path := BallFlightRenderer.build_path(
			yards, Balance.TimingTier.GOOD, stats, config
		)
		var landing := BallFlightRenderer.sample(1.0, path, config)
		var expected := PerspectiveGround.scale_at_depth(path.depth_t, 1.0, FAR_SCALE)
		var actual: float = landing["scale_factor"]
		if absf(actual - expected) > 0.001:
			print(
				"FAIL: landing scale %.4f != depth scale %.4f at %.0fyd (depth_t=%.3f)"
				% [actual, expected, yards, path.depth_t]
			)
			ok = false
	if ok:
		print("OK: landing scale matches perspective depth")
	return ok


func _check_arc_from_hit() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _maxed_stats()
	var tier := Balance.TimingTier.PERFECT

	var short_arc := BallFlightRenderer.arc_height_for_hit(30.0, tier, stats, config)
	var long_arc := BallFlightRenderer.arc_height_for_hit(300.0, tier, stats, config)
	if long_arc <= short_arc:
		print(
			"FAIL: arc should increase with yards short=%.2f long=%.2f"
			% [short_arc, long_arc]
		)
		ok = false
	else:
		print("OK: arc increases with yards (30yd=%.1fpx 300yd=%.1fpx)" % [short_arc, long_arc])

	var yards := 150.0
	var perfect_arc := BallFlightRenderer.arc_height_for_hit(
		yards, Balance.TimingTier.PERFECT, stats, config
	)
	var miss_arc := BallFlightRenderer.arc_height_for_hit(
		yards, Balance.TimingTier.MISS, stats, config
	)
	if perfect_arc <= miss_arc:
		print(
			"FAIL: arc should increase with timing tier perfect=%.2f miss=%.2f"
			% [perfect_arc, miss_arc]
		)
		ok = false
	else:
		print("OK: arc increases with timing quality (150yd perfect=%.1f miss=%.1f)" % [
			perfect_arc, miss_arc
		])
	return ok


func _check_scale_bounds() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _maxed_stats()

	var short_path := BallFlightRenderer.build_path(
		30.0, Balance.TimingTier.PERFECT, stats, config
	)
	var short_landing := BallFlightRenderer.sample(1.0, short_path, config)
	var short_scale: float = short_landing["scale_factor"]
	if short_scale <= 0.58:
		print("FAIL: 30yd landing scale %.3f expected > 0.58" % short_scale)
		ok = false
	else:
		print("OK: short shot landing scale=%.3f" % short_scale)

	var long_path := BallFlightRenderer.build_path(
		300.0, Balance.TimingTier.PERFECT, stats, config
	)
	var long_landing := BallFlightRenderer.sample(1.0, long_path, config)
	var long_scale: float = long_landing["scale_factor"]
	if absf(long_scale - FAR_SCALE) > 0.05:
		print("FAIL: max shot landing scale %.3f expected ~%.2f" % [long_scale, FAR_SCALE])
		ok = false
	else:
		print("OK: max shot landing scale=%.3f" % long_scale)

	for yards in [30.0, 80.0, 150.0, 220.0, 300.0]:
		var path := BallFlightRenderer.build_path(
			yards, Balance.TimingTier.OK, stats, config
		)
		for step in 11:
			var progress := float(step) / 10.0
			var sample := BallFlightRenderer.sample(progress, path, config)
			var scale_factor: float = sample["scale_factor"]
			if scale_factor < 0.25 or scale_factor > 1.0:
				print(
					"FAIL: scale %.3f out of bounds [0.25, 1.0] at %.0fyd progress %.1f"
					% [scale_factor, yards, progress]
				)
				ok = false
	if ok:
		print("OK: scale stays within [0.25, 1.0] across sampled flights")
	return ok


func _check_fairway_travel() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _maxed_stats()

	var short_path := BallFlightRenderer.build_path(
		30.0, Balance.TimingTier.PERFECT, stats, config
	)
	var short_y := short_path.landing_ground.y
	if short_y >= MAT_BACK_Y:
		print(
			"FAIL: 30yd landing_y=%.1f should clear mat back (%.0f)"
			% [short_y, MAT_BACK_Y]
		)
		ok = false
	elif short_y > 172.0:
		print(
			"FAIL: 30yd landing_y=%.1f expected well onto fairway (<=172)"
			% short_y
		)
		ok = false
	else:
		print("OK: 30yd clears mat and lands on fairway (y=%.1f)" % short_y)

	var long_path := BallFlightRenderer.build_path(
		300.0, Balance.TimingTier.PERFECT, stats, config
	)
	var long_y := long_path.landing_ground.y
	if absf(long_y - HORIZON_GROUND_Y) > 2.0:
		print("FAIL: 300yd landing_y=%.1f expected horizon (%.0f)" % [long_y, HORIZON_GROUND_Y])
		ok = false
	else:
		print("OK: 300yd reaches horizon (y=%.1f)" % long_y)

	var travel := TEE_Y - short_y
	if travel < 34.0:
		print("FAIL: 30yd travel %.1fpx too short to read on screen" % travel)
		ok = false
	else:
		print("OK: 30yd visible travel=%.1fpx" % travel)
	return ok


func _check_vanish_into_distance() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _maxed_stats()

	var path := BallFlightRenderer.build_path(
		520.0, Balance.TimingTier.PERFECT, stats, config
	)
	if not path.vanishes_into_distance:
		print("FAIL: 520yd shot should vanish into distance")
		ok = false

	var mid := BallFlightRenderer.sample(0.7, path, config)
	var end := BallFlightRenderer.sample(1.0, path, config)
	if mid["ball_alpha"] <= 0.99:
		print("FAIL: ball should stay visible until late flight (alpha=%.2f at 70%%)" % mid["ball_alpha"])
		ok = false
	if end["ball_alpha"] > 0.05:
		print("FAIL: ball should fade out at horizon (alpha=%.2f)" % end["ball_alpha"])
		ok = false
	if absf(end["visual_pos"].y - HORIZON_GROUND_Y) > 4.0:
		print(
			"FAIL: vanishing shot should finish at horizon y=%.1f got %.1f"
			% [HORIZON_GROUND_Y, end["visual_pos"].y]
		)
		ok = false

	var normal := BallFlightRenderer.build_path(
		250.0, Balance.TimingTier.PERFECT, stats, config
	)
	if normal.vanishes_into_distance:
		print("FAIL: 250yd shot should leave litter, not vanish")
		ok = false

	if ok:
		print("OK: shots beyond 300yd vanish at horizon with fade")
	return ok
