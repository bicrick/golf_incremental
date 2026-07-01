extends SceneTree
## v2 Phase B visual carry floor, real-3D edition — run:
## godot --headless --script res://tools/verify_v2_visual_floor.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(42)
	var ok := true
	ok = _check_ok_tier_floor() and ok
	ok = _check_perfect_first_band() and ok
	ok = _check_whiff_dribble() and ok
	ok = _check_ok_plus_apex() and ok
	ok = _check_gameplay_yards_unchanged() and ok
	print("v2_visual_floor_ok=", ok)
	quit(0 if ok else 1)


func _default_stats() -> PlayerStats:
	return Balance.default_stats()


func _ok_tier_sample() -> Dictionary:
	var stats := _default_stats()
	var charge := ChargeSwing.new()
	var contact := charge.contact_time_sec()
	# Mid OK window: between good edge (100ms) and OK edge (150ms) early release.
	var hold := contact - 120.0 / 1000.0
	var tier := charge.evaluate_timing(hold, stats)
	var quality := charge.timing_quality(hold, stats)
	var flavor := charge.contact_flavor(tier, hold, stats)
	var yards := Economy.yards_from_quality(quality, stats)
	if tier != Balance.TimingTier.OK:
		print(
			"FAIL: expected OK tier sample, got %s (hold=%.3f early_ms=%.0f)"
			% [Balance.TIER_NAMES[tier], hold, absf(hold - contact) * 1000.0]
		)
		return {}
	if flavor != Balance.ContactFlavor.SLIGHTLY_FAT:
		print("FAIL: OK tier sample expected SLIGHTLY_FAT flavor, got %d" % flavor)
		return {}
	return {"tier": tier, "yards": yards, "quality": quality, "flavor": flavor}


func _check_ok_tier_floor() -> bool:
	var ok := true
	var stats := _default_stats()
	var sample := _ok_tier_sample()
	if sample.is_empty():
		return false

	var path := BallFlight3D.build_path(
		sample["yards"], sample["tier"], stats, sample["flavor"]
	)
	var travel := path.origin.distance_to(path.landing)

	if path.visual_yards < Balance.VISUAL_FLOOR_YARDS - 0.01:
		print(
			"FAIL: OK tier visual_yards=%.2f below floor %.2f"
			% [path.visual_yards, Balance.VISUAL_FLOOR_YARDS]
		)
		ok = false
	else:
		print(
			"OK: OK tier floor (gameplay_yards=%.1f visual_yards=%.1f travel=%.2fyd)"
			% [sample["yards"], path.visual_yards, travel]
		)
	return ok


func _check_perfect_first_band() -> bool:
	var ok := true
	var stats := _default_stats()
	var charge := ChargeSwing.new()
	var contact := charge.contact_time_sec()
	var yards := Economy.yards_from_quality(1.0, stats)
	var tier := charge.evaluate_timing(contact, stats)

	var path := BallFlight3D.build_path(yards, tier, stats, Balance.ContactFlavor.PURE)
	var travel := path.origin.distance_to(path.landing)

	if tier != Balance.TimingTier.PERFECT:
		print("FAIL: perfect sample tier=%s" % Balance.TIER_NAMES[tier])
		ok = false
	if path.visual_yards < Balance.VISUAL_FLOOR_YARDS - 0.01:
		print(
			"FAIL: perfect visual_yards=%.2f not at first band (floor %.2f)"
			% [path.visual_yards, Balance.VISUAL_FLOOR_YARDS]
		)
		ok = false
	elif travel < 10.0:
		print("FAIL: perfect travel %.2fyd too short to read as golf carry" % travel)
		ok = false
	else:
		print(
			"OK: perfect first band (gameplay_yards=%.1f visual_yards=%.1f travel=%.2fyd)"
			% [yards, path.visual_yards, travel]
		)
	return ok


func _check_whiff_dribble() -> bool:
	var ok := true
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

	var path := BallFlight3D.build_path(yards, tier, stats, Balance.ContactFlavor.THIN)
	var travel := path.origin.distance_to(path.landing)

	if path.visual_yards > Balance.WHIFF_MAX_YARDS + 0.01:
		print(
			"FAIL: whiff visual_yards=%.2f exceeds cap %.2f"
			% [path.visual_yards, Balance.WHIFF_MAX_YARDS]
		)
		ok = false
	if travel > Balance.WHIFF_MAX_YARDS + 0.01:
		print(
			"FAIL: whiff travel %.2fyd exceeds dribble max %.2fyd"
			% [travel, Balance.WHIFF_MAX_YARDS]
		)
		ok = false
	else:
		print(
			"OK: whiff dribble (gameplay_yards=%.1f visual_yards=%.2f travel=%.2fyd)"
			% [yards, path.visual_yards, travel]
		)
	return ok


func _check_ok_plus_apex() -> bool:
	var ok := true
	var stats := _default_stats()
	var sample := _ok_tier_sample()
	if sample.is_empty():
		return false

	var path := BallFlight3D.build_path(
		sample["yards"], sample["tier"], stats, sample["flavor"]
	)
	var min_apex := Balance.VISUAL_FLOOR_YARDS * Balance.FLIGHT_APEX_RATIO[Balance.ContactFlavor.SLIGHTLY_FAT] * 0.5
	if path.apex_height < min_apex:
		print(
			"FAIL: OK tier apex %.2fyd below expected minimum %.2fyd"
			% [path.apex_height, min_apex]
		)
		ok = false
	else:
		print("OK: OK tier apex=%.2fyd (min expected=%.2fyd)" % [path.apex_height, min_apex])

	var miss_path := BallFlight3D.build_path(
		3.0, Balance.TimingTier.MISS, stats, Balance.ContactFlavor.THIN
	)
	if miss_path.apex_height >= path.apex_height:
		print("FAIL: miss apex %.2fyd should stay below OK+ apex %.2fyd" % [miss_path.apex_height, path.apex_height])
		ok = false
	else:
		print("OK: miss apex=%.2fyd stays low" % miss_path.apex_height)
	return ok


func _check_gameplay_yards_unchanged() -> bool:
	var stats := _default_stats()
	var perfect_yards := Economy.yards_from_quality(1.0, stats)
	if absf(perfect_yards - 30.0) > 1.5:
		print("FAIL: gameplay yards changed perfect=%.2f" % perfect_yards)
		return false
	print("OK: gameplay yards unchanged (perfect=%.1f)" % perfect_yards)
	return true
