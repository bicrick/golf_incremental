extends SceneTree
## Headless real-3D ball flight tests — run:
## godot --headless --script res://tools/verify_ball_flight.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_apex_positive() and ok
	ok = _check_returns_to_ground() and ok
	ok = _check_distance_scales_with_yards() and ok
	ok = _check_apex_scales_with_contact_flavor() and ok
	ok = _check_flight_time_monotonic() and ok
	ok = _check_flight_time_bounds() and ok
	ok = _check_landing_matches_visual_yards() and ok
	print("ball_flight_ok=", ok)
	quit(0 if ok else 1)


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


func _check_apex_positive() -> bool:
	var ok := true
	var stats := _maxed_stats()
	for yards in [30.0, 100.0, 150.0, 300.0, 500.0]:
		var path := BallFlight3D.build_path(
			yards, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
		)
		var peak_y := -INF
		for step in 21:
			var progress := float(step) / 20.0
			var pos := BallFlight3D.sample(progress, path)
			peak_y = maxf(peak_y, pos.y)
		if peak_y <= 0.0:
			print("FAIL: %.0fyd flight never rises above ground (peak_y=%.3f)" % [yards, peak_y])
			ok = false
	if ok:
		print("OK: flight arcs above ground for all tested distances")
	return ok


func _check_returns_to_ground() -> bool:
	var ok := true
	var stats := _maxed_stats()
	for yards in [30.0, 150.0, 300.0]:
		var path := BallFlight3D.build_path(
			yards, Balance.TimingTier.GOOD, stats, Balance.ContactFlavor.PURE
		)
		var landing := BallFlight3D.sample(1.0, path)
		if absf(landing.y) > 0.01:
			print("FAIL: %.0fyd landing y=%.4f expected ~0" % [yards, landing.y])
			ok = false
	if ok:
		print("OK: ball returns to ground plane (y~=0) at end of flight")
	return ok


func _check_distance_scales_with_yards() -> bool:
	var ok := true
	var stats := _maxed_stats()
	var short_path := BallFlight3D.build_path(
		30.0, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
	)
	var long_path := BallFlight3D.build_path(
		300.0, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
	)
	var short_dist := short_path.origin.distance_to(short_path.landing)
	var long_dist := long_path.origin.distance_to(long_path.landing)
	if long_dist <= short_dist:
		print(
			"FAIL: landing distance should grow with yards short=%.2f long=%.2f"
			% [short_dist, long_dist]
		)
		ok = false
	else:
		print("OK: landing distance grows with yards (30yd=%.1f 300yd=%.1f)" % [short_dist, long_dist])
	return ok


func _check_apex_scales_with_contact_flavor() -> bool:
	var ok := true
	var stats := _maxed_stats()
	var yards := 150.0
	var pure := BallFlight3D.build_path(yards, Balance.TimingTier.OK, stats, Balance.ContactFlavor.PURE)
	var fat := BallFlight3D.build_path(yards, Balance.TimingTier.OK, stats, Balance.ContactFlavor.SLIGHTLY_FAT)
	var thin := BallFlight3D.build_path(yards, Balance.TimingTier.MISS, stats, Balance.ContactFlavor.THIN)
	if pure.apex_height <= fat.apex_height:
		print(
			"FAIL: pure contact should arc higher than slightly-fat (pure=%.2f fat=%.2f)"
			% [pure.apex_height, fat.apex_height]
		)
		ok = false
	if fat.apex_height <= thin.apex_height:
		print(
			"FAIL: slightly-fat should still arc higher than a thin skid (fat=%.2f thin=%.2f)"
			% [fat.apex_height, thin.apex_height]
		)
		ok = false
	if ok:
		print(
			"OK: apex height ordered pure > slightly-fat > thin (%.2f > %.2f > %.2f)"
			% [pure.apex_height, fat.apex_height, thin.apex_height]
		)
	return ok


func _check_flight_time_monotonic() -> bool:
	var ok := true
	var stats := _maxed_stats()
	var short_path := BallFlight3D.build_path(
		30.0, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
	)
	var mid_path := BallFlight3D.build_path(
		150.0, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
	)
	var long_path := BallFlight3D.build_path(
		300.0, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
	)
	if short_path.flight_time >= mid_path.flight_time \
			or mid_path.flight_time >= long_path.flight_time:
		print(
			"FAIL: flight_time should increase with distance 30=%.2fs 150=%.2fs 300=%.2fs"
			% [short_path.flight_time, mid_path.flight_time, long_path.flight_time]
		)
		ok = false
	else:
		print(
			"OK: flight_time increases with distance (30=%.2fs 150=%.2fs 300=%.2fs)"
			% [short_path.flight_time, mid_path.flight_time, long_path.flight_time]
		)
	return ok


func _check_flight_time_bounds() -> bool:
	var ok := true
	var stats := _maxed_stats()
	for yards in [1.0, 30.0, 150.0, 300.0, 800.0]:
		for tier in [Balance.TimingTier.PERFECT, Balance.TimingTier.MISS]:
			var path := BallFlight3D.build_path(yards, tier, stats, Balance.ContactFlavor.PURE)
			if path.flight_time < Balance.FLIGHT_TIME_MIN_SEC - 0.001 \
					or path.flight_time > Balance.FLIGHT_TIME_MAX_SEC + 0.001:
				print(
					"FAIL: flight_time %.2fs outside [%.2f, %.2f] at %.0fyd tier=%d"
					% [path.flight_time, Balance.FLIGHT_TIME_MIN_SEC, Balance.FLIGHT_TIME_MAX_SEC, yards, tier]
				)
				ok = false
	if ok:
		print("OK: flight_time stays within configured clamp")
	return ok


func _check_landing_matches_visual_yards() -> bool:
	var ok := true
	var stats := _maxed_stats()

	var miss_path := BallFlight3D.build_path(
		2.0, Balance.TimingTier.MISS, stats, Balance.ContactFlavor.THIN
	)
	var miss_dist := miss_path.origin.distance_to(miss_path.landing)
	if miss_dist > Balance.WHIFF_MAX_YARDS + 0.01:
		print("FAIL: whiff distance %.2f exceeds cap %.2f" % [miss_dist, Balance.WHIFF_MAX_YARDS])
		ok = false
	else:
		print("OK: whiff dribble capped near tee (dist=%.2fyd)" % miss_dist)

	var ok_path := BallFlight3D.build_path(
		20.0, Balance.TimingTier.OK, stats, Balance.ContactFlavor.SLIGHTLY_FAT
	)
	var ok_dist := ok_path.origin.distance_to(ok_path.landing)
	if ok_dist < Balance.VISUAL_FLOOR_YARDS - 0.01:
		print("FAIL: OK+ carry distance %.2f below floor %.2f" % [ok_dist, Balance.VISUAL_FLOOR_YARDS])
		ok = false
	else:
		print("OK: OK+ meets visual carry floor (dist=%.2fyd)" % ok_dist)
	return ok
