extends SceneTree
## Headless real-3D ball flight tests — run:
## godot --headless --script res://tools/verify_ball_flight.gd


const BallFlightTrailScript := preload("res://scripts/visual/ball_flight_trail.gd")
const HitPoofScript := preload("res://scripts/visual/hit_poof.gd")


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
	ok = _check_landing_proportional_to_yards() and ok
	ok = _check_tier_ladder_distance_separation() and ok
	ok = await _check_flight_trail() and ok
	ok = await _check_flight_trail_zoom_anchor() and ok
	ok = await _check_hit_poof_anchor() and ok
	ok = await _check_hit_poof_zoom_compensation() and ok
	print("ball_flight_ok=", ok)
	quit(0 if ok else 1)


func _maxed_stats() -> PlayerStats:
	var stats := Balance.default_stats()
	var max_levels := {
		"power": UpgradeDefinitions.get_def("power").get("max_level", 0),
		"distance_pay": UpgradeDefinitions.get_def("distance_pay").get("max_level", 0),
		"iron_set": UpgradeDefinitions.get_def("iron_set").get("max_level", 0),
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
	var pure := BallFlight3D.build_path(yards, Balance.TimingTier.OKAY, stats, Balance.ContactFlavor.PURE)
	var fat := BallFlight3D.build_path(yards, Balance.TimingTier.OKAY, stats, Balance.ContactFlavor.SLIGHTLY_FAT)
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


## Visual flight must always equal gameplay yards exactly — no floor or cap,
## for any tier including Miss.
func _check_landing_proportional_to_yards() -> bool:
	var ok := true
	var stats := _maxed_stats()

	var cases: Array[Dictionary] = [
		{"yards": 2.0, "tier": Balance.TimingTier.MISS, "flavor": Balance.ContactFlavor.THIN},
		{"yards": 4.0, "tier": Balance.TimingTier.BAD, "flavor": Balance.ContactFlavor.SLIGHTLY_FAT},
		{"yards": 10.0, "tier": Balance.TimingTier.OKAY, "flavor": Balance.ContactFlavor.SLIGHTLY_FAT},
		{"yards": 20.0, "tier": Balance.TimingTier.GOOD, "flavor": Balance.ContactFlavor.PURE},
		{"yards": 28.0, "tier": Balance.TimingTier.GREAT, "flavor": Balance.ContactFlavor.PURE},
		{"yards": 30.0, "tier": Balance.TimingTier.PERFECT, "flavor": Balance.ContactFlavor.PURE},
	]
	for case in cases:
		var path := BallFlight3D.build_path(case["yards"], case["tier"], stats, case["flavor"])
		if absf(path.visual_yards - case["yards"]) > 0.001:
			print(
				"FAIL: %s tier visual_yards %.2f does not match gameplay yards %.2f"
				% [Balance.TIER_NAMES[case["tier"]], path.visual_yards, case["yards"]]
			)
			ok = false
		# Landing is a real Vector3 — lateral scatter means Euclidean distance
		# is >= the forward carry, never less, and stays close for small scatter.
		var dist := path.origin.distance_to(path.landing)
		if dist < case["yards"] - 0.001:
			print(
				"FAIL: %s tier landing distance %.2f should be >= carry yards %.2f"
				% [Balance.TIER_NAMES[case["tier"]], dist, case["yards"]]
			)
			ok = false
	if ok:
		print("OK: visual carry (visual_yards) matches gameplay yards exactly for every tier")
	return ok


## The distance ladder should visibly separate, not cluster around one value.
## Samples sit at the midpoint of each tier's early-release window so the
## comparison reflects a typical hit in that tier, not its worst edge.
func _check_tier_ladder_distance_separation() -> bool:
	var ok := true
	var stats := Balance.default_stats()
	var charge := ChargeSwing.new()
	var contact := charge.contact_time_sec()

	var samples := [
		{"tier": Balance.TimingTier.MISS, "hold": Balance.MIN_HOLD_SEC * 0.5},
		{
			"tier": Balance.TimingTier.BAD,
			"hold": contact - (stats.timing_window_okay_ms + stats.timing_window_bad_ms) * 0.5 / 1000.0,
		},
		{
			"tier": Balance.TimingTier.OKAY,
			"hold": contact - (stats.timing_window_good_ms + stats.timing_window_okay_ms) * 0.5 / 1000.0,
		},
		{
			"tier": Balance.TimingTier.GOOD,
			"hold": contact - (stats.timing_window_great_ms + stats.timing_window_good_ms) * 0.5 / 1000.0,
		},
		{
			"tier": Balance.TimingTier.GREAT,
			"hold": contact - (stats.timing_window_perfect_ms + stats.timing_window_great_ms) * 0.5 / 1000.0,
		},
		{"tier": Balance.TimingTier.PERFECT, "hold": contact},
	]

	var prev_dist := -1.0
	var report: Array[String] = []
	var distances: Array[float] = []
	for sample in samples:
		var hold: float = sample["hold"]
		var quality := charge.timing_quality(hold, stats)
		var yards := Economy.yards_from_quality(quality, stats)
		var flavor := charge.contact_flavor(sample["tier"], hold, stats)
		var path := BallFlight3D.build_path(yards, sample["tier"], stats, flavor)
		var dist := path.visual_yards
		distances.append(dist)
		report.append("%s=%.1fyd" % [Balance.TIER_NAMES[sample["tier"]], dist])
		if dist <= prev_dist:
			print("FAIL: tier ladder distance not increasing (%s)" % ", ".join(report))
			ok = false
		prev_dist = dist

	var miss_dist: float = distances[0]
	var perfect_dist: float = distances[distances.size() - 1]
	if perfect_dist < miss_dist * 5.0:
		print(
			"FAIL: Perfect (%.1fyd) should clearly outdistance Miss (%.1fyd), not just edge past it"
			% [perfect_dist, miss_dist]
		)
		ok = false

	if ok:
		print("OK: tier ladder distance increases Miss < Bad < Okay < Good < Great < Perfect (%s)" % ", ".join(report))
	return ok


func _check_flight_trail() -> bool:
	var ok := true
	var fx_layer := Node2D.new()
	root.add_child(fx_layer)

	var camera := Camera3D.new()
	camera.position = Vector3(0.24, 1.24, -2.016)
	camera.rotation_degrees = Vector3(1.2, 3.0, 0.0)
	root.add_child(camera)
	await process_frame

	var trail = BallFlightTrailScript.begin(fx_layer, camera, Balance.TimingTier.PERFECT)
	var origin := Vector3(-0.545, 0.05, -6.395)
	for step in 12:
		var z := origin.z - float(step) * 8.0
		var y := origin.y + sin(float(step) * 0.4) * 2.0
		trail.track(Vector3(origin.x, y, z))

	if trail.point_count() > Balance.FLIGHT_TRAIL_MAX_POINTS:
		print(
			"FAIL: trail point count %d exceeds cap %d"
			% [trail.point_count(), Balance.FLIGHT_TRAIL_MAX_POINTS]
		)
		ok = false
	elif trail.point_count() < 3:
		print("FAIL: trail should accumulate multiple spaced points, got %d" % trail.point_count())
		ok = false

	if trail.tail_alpha() >= trail.head_alpha():
		print(
			"FAIL: trail gradient tail alpha %.3f should be less than head %.3f"
			% [trail.tail_alpha(), trail.head_alpha()]
		)
		ok = false

	var expected_perfect: Color = Balance.TIER_COLORS[Balance.TimingTier.PERFECT]
	if not trail.trail_color().is_equal_approx(expected_perfect):
		print(
			"FAIL: Perfect trail color %s should match tier color %s"
			% [trail.trail_color(), expected_perfect]
		)
		ok = false

	var bad_trail = BallFlightTrailScript.begin(fx_layer, camera, Balance.TimingTier.BAD)
	if not bad_trail.trail_color().is_equal_approx(Balance.TIER_COLORS[Balance.TimingTier.BAD]):
		print(
			"FAIL: Bad trail color %s should match tier color %s"
			% [bad_trail.trail_color(), Balance.TIER_COLORS[Balance.TimingTier.BAD]]
		)
		ok = false
	bad_trail.queue_free()

	var golden_trail = BallFlightTrailScript.begin(
		fx_layer, camera, Balance.TimingTier.GOOD, 0.0, Balance.GOLDEN_TRAIL_COLOR
	)
	if not golden_trail.trail_color().is_equal_approx(Balance.GOLDEN_TRAIL_COLOR):
		print(
			"FAIL: golden trail color %s should match %s"
			% [golden_trail.trail_color(), Balance.GOLDEN_TRAIL_COLOR]
		)
		ok = false
	golden_trail.queue_free()

	var first_screen_before: Vector2 = trail.screen_point_at(0)
	camera.position += Vector3(5.0, 0.0, 0.0)
	await process_frame
	var first_screen_after: Vector2 = trail.screen_point_at(0)
	if first_screen_before.distance_to(first_screen_after) < 1.0:
		print(
			"FAIL: trail screen point should move after camera pan (before %s, after %s)"
			% [first_screen_before, first_screen_after]
		)
		ok = false
	for i in trail.point_count():
		var expected: Vector2 = fx_layer.to_local(camera.unproject_position(trail.world_point_at(i)))
		var actual: Vector2 = trail.screen_point_at(i)
		if expected.distance_to(actual) > 0.5:
			print(
				"FAIL: trail point %d mismatch after pan (expected %s, got %s)"
				% [i, expected, actual]
			)
			ok = false
			break

	trail.finish()
	if ok:
		print("OK: flight trail caps points, fades tail-to-head, and survives camera pan")
	return ok


func _check_flight_trail_zoom_anchor() -> bool:
	var ok := true
	var fx_layer := Node2D.new()
	root.add_child(fx_layer)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.24, 1.24, -2.016)
	camera.rotation_degrees = Vector3(1.2, 3.0, 0.0)
	camera.size = 10.0
	root.add_child(camera)
	await process_frame

	var reference_size := camera.size
	var trail = BallFlightTrailScript.begin(
		fx_layer, camera, Balance.TimingTier.PERFECT, reference_size
	)
	var world_head := Vector3(-0.545, 0.05, -6.395)
	trail.track(world_head)
	await process_frame

	var expected := fx_layer.to_local(camera.unproject_position(world_head))
	var actual: Vector2 = trail.screen_point_at(trail.point_count() - 1)
	if expected.distance_to(actual) > 0.5:
		print(
			"FAIL: trail head mismatch at reference zoom (expected %s, got %s)"
			% [expected, actual]
		)
		ok = false

	camera.size = reference_size * 4.0
	await process_frame

	expected = fx_layer.to_local(camera.unproject_position(world_head))
	actual = trail.screen_point_at(trail.point_count() - 1)
	if expected.distance_to(actual) > 0.5:
		print(
			"FAIL: trail head mismatch when zoomed out (expected %s, got %s)"
			% [expected, actual]
		)
		ok = false

	trail.finish()
	if ok:
		print("OK: flight trail head tracks ball at extreme zoom")
	return ok


func _check_hit_poof_anchor() -> bool:
	var ok := true
	var fx_layer := Node2D.new()
	root.add_child(fx_layer)

	var camera := Camera3D.new()
	camera.position = Vector3(0.24, 1.24, -2.016)
	camera.rotation_degrees = Vector3(1.2, 3.0, 0.0)
	root.add_child(camera)
	await process_frame

	var world_pos := Vector3(-0.545, 0.05, -6.395)
	HitPoofScript.spawn(fx_layer, camera, world_pos, Balance.TimingTier.GOOD)
	var poof := fx_layer.get_child(fx_layer.get_child_count() - 1)
	var screen_before: Vector2 = poof.screen_position()
	camera.position += Vector3(5.0, 0.0, 0.0)
	await process_frame
	var screen_after: Vector2 = poof.screen_position()
	if screen_before.distance_to(screen_after) < 1.0:
		print(
			"FAIL: hit poof screen point should move after camera pan (before %s, after %s)"
			% [screen_before, screen_after]
		)
		ok = false

	var expected: Vector2 = fx_layer.to_local(camera.unproject_position(world_pos))
	if expected.distance_to(poof.screen_position()) > 0.5:
		print(
			"FAIL: hit poof mismatch after pan (expected %s, got %s)"
			% [expected, poof.screen_position()]
		)
		ok = false

	poof.queue_free()
	if ok:
		print("OK: hit poof reprojects to world anchor during camera pan")
	return ok


func _check_hit_poof_zoom_compensation() -> bool:
	var ok := true
	var fx_layer := Node2D.new()
	root.add_child(fx_layer)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.24, 1.24, -2.016)
	camera.rotation_degrees = Vector3(1.2, 3.0, 0.0)
	camera.size = 10.0
	root.add_child(camera)
	await process_frame

	var world_pos := Vector3(-0.545, 0.05, -6.395)
	var reference_size := camera.size
	HitPoofScript.spawn(
		fx_layer,
		camera,
		world_pos,
		Balance.TimingTier.GOOD,
		0,
		Vector3(0.0, 0.0, -12.0),
		reference_size
	)
	var poof := fx_layer.get_child(fx_layer.get_child_count() - 1)
	await process_frame

	camera.size = reference_size * 4.0
	await process_frame
	var expected_scale := reference_size / camera.size
	if not is_equal_approx(poof.scale.x, expected_scale):
		print(
			"FAIL: hit poof zoom scale %.3f should match reference/current %.3f"
			% [poof.scale.x, expected_scale]
		)
		ok = false

	poof.queue_free()
	if ok:
		print("OK: hit poof compensates orthographic zoom")
	return ok
