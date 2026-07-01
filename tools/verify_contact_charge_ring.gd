extends SceneTree
## Contact charge ring scale regression — run:
## godot --headless --script res://tools/verify_contact_charge_ring.gd

const ContactChargeRingScript := preload("res://scripts/ui/contact_charge_ring.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_inner_scale_windup() and ok
	ok = _check_inner_overshoot() and ok
	ok = _check_outer_scale_upgrades() and ok
	ok = _check_perfect_zone_scales() and ok
	ok = _check_perfect_zone_matches_timing() and ok
	print("contact_charge_ring_ok=", ok)
	quit(0 if ok else 1)


func _check_inner_scale_windup() -> bool:
	var start: float = ContactChargeRingScript.inner_scale_for_windup(0.0, false, 0.0)
	var end: float = ContactChargeRingScript.inner_scale_for_windup(1.0, false, 0.0)
	if absf(start - Balance.RING_INNER_START_FRAC) > 0.001:
		print(
			"FAIL: inner at windup 0 expected %.2f, got %.3f"
			% [Balance.RING_INNER_START_FRAC, start]
		)
		return false
	if absf(end - Balance.RING_INNER_CONTACT_FRAC) > 0.001:
		print(
			"FAIL: inner at windup 1 expected %.2f, got %.3f"
			% [Balance.RING_INNER_CONTACT_FRAC, end]
		)
		return false
	print("OK: inner scale expands with windup")
	return true


func _check_inner_overshoot() -> bool:
	var overshoot: float = ContactChargeRingScript.inner_scale_for_windup(1.0, true, 1.0)
	if absf(overshoot - Balance.RING_INNER_OVERSHOOT_FRAC) > 0.001:
		print(
			"FAIL: inner overshoot expected %.2f, got %.3f"
			% [Balance.RING_INNER_OVERSHOOT_FRAC, overshoot]
		)
		return false
	print("OK: inner overshoot past contact")
	return true


func _check_outer_scale_upgrades() -> bool:
	var default_stats := Balance.default_stats()
	var noob: float = ContactChargeRingScript.outer_scale_for_stats(default_stats)
	if absf(noob - Balance.RING_OUTER_MIN_SCALE) > 0.001:
		print("FAIL: noob outer scale expected %.2f, got %.3f" % [Balance.RING_OUTER_MIN_SCALE, noob])
		return false

	var maxed := Balance.default_stats()
	var levels := {
		"power": UpgradeDefinitions.get_def("power").get("max_level", 0),
		"distance_pay": UpgradeDefinitions.get_def("distance_pay").get("max_level", 0),
		"iron_set": UpgradeDefinitions.get_def("iron_set").get("max_level", 0),
		"power_surge": UpgradeDefinitions.get_def("power_surge").get("max_level", 0),
	}
	UpgradeEffects.apply_all(maxed, levels)
	var maxed_scale: float = ContactChargeRingScript.outer_scale_for_stats(maxed)
	if maxed_scale <= noob:
		print("FAIL: maxed outer scale %.3f should exceed noob %.3f" % [maxed_scale, noob])
		return false
	if absf(maxed_scale - Balance.RING_OUTER_MAX_SCALE) > 0.001:
		print(
			"FAIL: maxed outer scale expected %.2f, got %.3f"
			% [Balance.RING_OUTER_MAX_SCALE, maxed_scale]
		)
		return false
	print("OK: outer scale grows with power upgrades")
	return true


func _check_perfect_zone_scales() -> bool:
	var stats := Balance.default_stats()
	var bounds: Vector2 = ContactChargeRingScript.perfect_zone_inner_scale_bounds(stats)
	var contact := Balance.CONTACT_WINDUP_SEC
	var early_hold := contact - stats.timing_window_perfect_ms / 1000.0
	var early_scale := ContactChargeRingScript.inner_scale_for_windup(
		early_hold / contact, false, 0.0
	)

	if absf(bounds.y - Balance.RING_INNER_CONTACT_FRAC) > 0.001:
		print(
			"FAIL: perfect zone late scale expected %.2f, got %.3f"
			% [Balance.RING_INNER_CONTACT_FRAC, bounds.y]
		)
		return false
	if absf(bounds.x - early_scale) > 0.001:
		print(
			"FAIL: perfect zone early scale expected %.3f, got %.3f"
			% [early_scale, bounds.x]
		)
		return false

	var upgraded := Balance.default_stats()
	upgraded.timing_window_perfect_ms += 40.0
	var wide_bounds: Vector2 = ContactChargeRingScript.perfect_zone_inner_scale_bounds(upgraded)
	if wide_bounds.x >= bounds.x:
		print("FAIL: wider perfect window should start at smaller inner scale")
		return false
	if wide_bounds.y != bounds.y:
		print("FAIL: perfect zone late scale should stay at contact align")
		return false

	print("OK: perfect zone inner scales track timing window")
	return true


func _check_perfect_zone_matches_timing() -> bool:
	var charge := ChargeSwing.new()
	var stats := Balance.default_stats()
	var contact := charge.contact_time_sec()

	# Sample just inside (not exactly on) the perfect-window edge to avoid
	# float rounding flipping the strict evaluate_timing boundary check.
	var samples := [
		contact,
		contact - stats.timing_window_perfect_ms * 0.5 / 1000.0,
		contact - stats.timing_window_perfect_ms * 0.999 / 1000.0,
		contact + stats.timing_window_perfect_ms * 0.5 / 1000.0,
		contact - stats.timing_window_perfect_ms * 1.5 / 1000.0,
	]

	for hold in samples:
		var inner := ContactChargeRingScript.inner_scale_for_hold(hold)
		var visual_in := ContactChargeRingScript.is_inner_in_perfect_zone(
			inner, stats, charge.past_contact(hold)
		)
		var timing_in := ContactChargeRingScript.is_hold_in_perfect_zone(hold, stats)
		if visual_in != timing_in:
			print(
				"FAIL: hold %.4fs visual perfect=%s timing perfect=%s"
				% [hold, visual_in, timing_in]
			)
			return false

	print("OK: visual perfect zone matches evaluate_timing")
	return true
