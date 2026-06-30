extends SceneTree
## v2 Phase B visual carry floor — run:
## godot --headless --script res://tools/verify_v2_visual_floor.gd

const TEE_X := 248.0
const TEE_Y := 206.0
const FAR_GROUND_Y := 105.0
const GROUND_BOTTOM_Y := 270.0
const VANISHING_POINT := Vector2(240.0, 100.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(42)
	var ok := true
	ok = _check_ok_tier_floor() and ok
	ok = _check_perfect_first_band() and ok
	ok = _check_whiff_dribble() and ok
	ok = _check_ok_plus_arc() and ok
	ok = _check_gameplay_yards_unchanged() and ok
	print("v2_visual_floor_ok=", ok)
	quit(0 if ok else 1)


func _make_config() -> BallFlightRenderer.FlightConfig:
	var config := BallFlightRenderer.FlightConfig.new()
	config.tee_x = TEE_X
	config.tee_y = TEE_Y
	config.far_ground_y = FAR_GROUND_Y
	config.ground_bottom_y = GROUND_BOTTOM_Y
	config.vanishing_point = VANISHING_POINT
	config.flight_depth_exponent = 0.34
	config.flight_depth_stretch = 1.02
	config.yard_depth_scale = 180.0
	config.min_landing_y = Balance.VISUAL_FLOOR_Y
	config.base_ball_scale = Vector2(0.6, 0.6)
	config.min_visible_px = 0.6
	config.ball_texture_px = 16.0
	config.arc_min_px = 12.0
	config.arc_max_px = 40.0
	config.landing_scatter_x = 28.0
	config.range_x_min = 24.0
	config.range_x_max = 456.0
	return config


func _default_stats() -> PlayerStats:
	return Balance.default_stats()


func _ok_tier_sample() -> Dictionary:
	var stats := _default_stats()
	var charge := ChargeSwing.new()
	var peak := charge.charge_duration_sec()
	# Mid OK window: between good edge (100ms) and OK edge (150ms) early release.
	var hold := peak - 120.0 / 1000.0
	var tier := charge.evaluate_timing(hold, stats)
	var quality := charge.timing_quality(hold, stats)
	var yards := Economy.yards_from_quality(quality, stats)
	if tier != Balance.TimingTier.OK:
		print(
			"FAIL: expected OK tier sample, got %s (hold=%.3f early_ms=%.0f)"
			% [Balance.TIER_NAMES[tier], hold, absf(hold - peak) * 1000.0]
		)
		return {}
	return {"tier": tier, "yards": yards, "quality": quality}


func _floor_landing_y(config: BallFlightRenderer.FlightConfig) -> float:
	return PerspectiveGround.y_at_p(
		Balance.VISUAL_FLOOR_P,
		config.tee_y,
		config.far_ground_y,
		config.vanishing_point
	)


func _check_ok_tier_floor() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _default_stats()
	var sample := _ok_tier_sample()
	if sample.is_empty():
		return false

	var path := BallFlightRenderer.build_path(
		sample["yards"], sample["tier"], stats, config
	)
	var landing_y: float = path.landing_ground.y
	var floor_y := _floor_landing_y(config)
	var travel := config.tee_y - landing_y

	if path.persp_p < Balance.VISUAL_FLOOR_P - 0.001:
		print(
			"FAIL: OK tier persp_p=%.3f below floor %.3f"
			% [path.persp_p, Balance.VISUAL_FLOOR_P]
		)
		ok = false
	if landing_y > floor_y + 0.5:
		print(
			"FAIL: OK tier landing_y=%.1f above floor %.1f (yards=%.1f travel=%.1fpx)"
			% [landing_y, floor_y, sample["yards"], travel]
		)
		ok = false
	else:
		print(
			"OK: OK tier floor (yards=%.1f p=%.3f landing_y=%.1f travel=%.1fpx)"
			% [sample["yards"], path.persp_p, landing_y, travel]
		)
	return ok


func _check_perfect_first_band() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _default_stats()
	var charge := ChargeSwing.new()
	var yards := Economy.yards_from_quality(1.0, stats)
	var tier := charge.evaluate_timing(charge.charge_duration_sec(), stats)

	var path := BallFlightRenderer.build_path(
		yards, tier, stats, config
	)
	var landing_y := path.landing_ground.y
	var floor_y := _floor_landing_y(config)
	var travel := config.tee_y - landing_y

	if tier != Balance.TimingTier.PERFECT:
		print("FAIL: perfect sample tier=%s" % Balance.TIER_NAMES[tier])
		ok = false
	if landing_y > floor_y + 0.5:
		print(
			"FAIL: perfect landing_y=%.1f not at first band (floor %.1f travel=%.1fpx)"
			% [landing_y, floor_y, travel]
		)
		ok = false
	elif travel < 30.0:
		print("FAIL: perfect travel %.1fpx too short to read as golf carry" % travel)
		ok = false
	else:
		print(
			"OK: perfect first band (yards=%.1f landing_y=%.1f travel=%.1fpx)"
			% [yards, landing_y, travel]
		)
	return ok


func _check_whiff_dribble() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _default_stats()
	var charge := ChargeSwing.new()
	var hold := Balance.MIN_HOLD_SEC * 0.5
	var tier := charge.evaluate_timing(hold, stats)
	var yards := Economy.yards_from_quality(
		charge.timing_quality(hold, stats), stats
	)

	if tier != Balance.TimingTier.MISS:
		print("FAIL: whiff sample tier=%s" % Balance.TIER_NAMES[tier])
		ok = false

	var path := BallFlightRenderer.build_path(yards, tier, stats, config)
	var landing_y := path.landing_ground.y
	var travel := config.tee_y - landing_y

	if path.persp_p > Balance.WHIFF_MAX_P + 0.001:
		print(
			"FAIL: whiff persp_p=%.3f exceeds cap %.3f"
			% [path.persp_p, Balance.WHIFF_MAX_P]
		)
		ok = false
	if travel > Balance.VISUAL_DRIBBLE_MAX_PX:
		print(
			"FAIL: whiff travel %.1fpx exceeds dribble max %.0fpx (landing_y=%.1f)"
			% [travel, Balance.VISUAL_DRIBBLE_MAX_PX, landing_y]
		)
		ok = false
	else:
		print(
			"OK: whiff dribble (yards=%.1f p=%.3f travel=%.1fpx)"
			% [yards, path.persp_p, travel]
		)
	return ok


func _check_ok_plus_arc() -> bool:
	var ok := true
	var config := _make_config()
	var stats := _default_stats()
	var sample := _ok_tier_sample()
	if sample.is_empty():
		return false

	var arc := BallFlightRenderer.arc_height_for_hit(
		sample["yards"], sample["tier"], stats, config
	)
	if arc < Balance.VISUAL_ARC_MIN_PX:
		print(
			"FAIL: OK tier arc %.1fpx below minimum %.0fpx"
			% [arc, Balance.VISUAL_ARC_MIN_PX]
		)
		ok = false
	else:
		print("OK: OK tier arc=%.1fpx (min=%.0fpx)" % [arc, Balance.VISUAL_ARC_MIN_PX])

	var miss_arc := BallFlightRenderer.arc_height_for_hit(
		3.0, Balance.TimingTier.MISS, stats, config
	)
	if miss_arc >= Balance.VISUAL_ARC_MIN_PX:
		print("FAIL: miss arc %.1fpx should stay below OK+ floor" % miss_arc)
		ok = false
	else:
		print("OK: miss arc=%.1fpx stays low" % miss_arc)
	return ok


func _check_gameplay_yards_unchanged() -> bool:
	var stats := _default_stats()
	var perfect_yards := Economy.yards_from_quality(1.0, stats)
	if absf(perfect_yards - 30.0) > 1.5:
		print("FAIL: gameplay yards changed perfect=%.2f" % perfect_yards)
		return false
	print("OK: gameplay yards unchanged (perfect=%.1f)" % perfect_yards)
	return true
