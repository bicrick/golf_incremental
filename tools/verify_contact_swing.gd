extends SceneTree
## Phase E contact swing — run:
## godot --headless --script res://tools/verify_contact_swing.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_linear_windup() and ok
	ok = _check_perfect_at_contact() and ok
	ok = _check_contact_flavors() and ok
	ok = _check_late_hold_decay() and ok
	ok = _check_sweet_spot_upgrade() and ok
	ok = _check_flavor_arc() and ok
	print("contact_swing_ok=", ok)
	quit(0 if ok else 1)


func _check_linear_windup() -> bool:
	var swing := ChargeSwing.new()
	var contact := swing.contact_time_sec()
	var mid := swing.windup_progress(contact * 0.5)
	if absf(mid - 0.5) > 0.01:
		print("FAIL: windup at half contact expected ~0.5, got %.3f" % mid)
		return false
	# Old ease curve would be ~0.5 at t=0.5 but lower at t=0.25.
	var quarter := swing.windup_progress(contact * 0.25)
	if absf(quarter - 0.25) > 0.01:
		print("FAIL: windup at quarter contact expected ~0.25, got %.3f" % quarter)
		return false
	if swing.charge_progress(contact * 0.4) != swing.windup_progress(contact * 0.4):
		print("FAIL: charge_progress should match linear windup_progress")
		return false
	print("OK: linear windup progress")
	return true


func _check_perfect_at_contact() -> bool:
	var swing := ChargeSwing.new()
	var stats := Balance.default_stats()
	var contact := swing.contact_time_sec()
	var tier := swing.evaluate_timing(contact, stats)
	if tier != Balance.TimingTier.PERFECT:
		print("FAIL: release at contact expected Perfect, got %s" % Balance.TIER_NAMES[tier])
		return false
	print("OK: perfect at contact moment")
	return true


func _check_contact_flavors() -> bool:
	var swing := ChargeSwing.new()
	var stats := Balance.default_stats()
	var contact := swing.contact_time_sec()

	var early_tier := swing.evaluate_timing(Balance.MIN_HOLD_SEC * 0.5, stats)
	var early_flavor := swing.contact_flavor(early_tier, Balance.MIN_HOLD_SEC * 0.5, stats)
	if early_flavor != Balance.ContactFlavor.THIN:
		print("FAIL: early miss expected THIN flavor, got %d" % early_flavor)
		return false

	var late_hold := contact + swing.contact_decay_sec() * 0.6
	var late_tier := swing.evaluate_timing(late_hold, stats)
	var late_flavor := swing.contact_flavor(late_tier, late_hold, stats)
	if late_flavor != Balance.ContactFlavor.CHUNK:
		print("FAIL: late miss expected CHUNK flavor, got %d" % late_flavor)
		return false

	var okay_hold := contact - (stats.timing_window_good_ms + stats.timing_window_okay_ms) * 0.5 / 1000.0
	var okay_tier := swing.evaluate_timing(okay_hold, stats)
	var okay_flavor := swing.contact_flavor(okay_tier, okay_hold, stats)
	if okay_tier != Balance.TimingTier.OKAY:
		print("FAIL: Okay tier sample got %s" % Balance.TIER_NAMES[okay_tier])
		return false
	if okay_flavor != Balance.ContactFlavor.SLIGHTLY_FAT:
		print("FAIL: Okay tier expected SLIGHTLY_FAT flavor, got %d" % okay_flavor)
		return false

	var bad_hold := contact - (stats.timing_window_okay_ms + stats.timing_window_bad_ms) * 0.5 / 1000.0
	var bad_tier := swing.evaluate_timing(bad_hold, stats)
	var bad_flavor := swing.contact_flavor(bad_tier, bad_hold, stats)
	if bad_tier != Balance.TimingTier.BAD:
		print("FAIL: Bad tier sample got %s" % Balance.TIER_NAMES[bad_tier])
		return false
	if bad_flavor != Balance.ContactFlavor.SLIGHTLY_FAT:
		print("FAIL: Bad tier expected SLIGHTLY_FAT flavor, got %d" % bad_flavor)
		return false

	var good_flavor := swing.contact_flavor(
		Balance.TimingTier.GOOD, contact - 0.02, stats
	)
	if good_flavor != Balance.ContactFlavor.PURE:
		print("FAIL: Good tier expected PURE flavor, got %d" % good_flavor)
		return false

	print("OK: contact flavors thin/chunk/slightly_fat/pure")
	return true


func _check_late_hold_decay() -> bool:
	var swing := ChargeSwing.new()
	var stats := Balance.default_stats()
	var contact := swing.contact_time_sec()

	var great_late := swing.evaluate_timing(contact + 0.005, stats)
	if great_late != Balance.TimingTier.GREAT:
		print("FAIL: just past contact expected Great, got %s" % Balance.TIER_NAMES[great_late])
		return false

	var good_late := swing.evaluate_timing(contact + 0.030, stats)
	if good_late != Balance.TimingTier.GOOD:
		print("FAIL: past post-peak-great window expected Good, got %s" % Balance.TIER_NAMES[good_late])
		return false

	var okay_late := swing.evaluate_timing(
		contact + Balance.POST_PEAK_OKAY_MS * 0.75 / 1000.0, stats
	)
	if okay_late != Balance.TimingTier.OKAY:
		print("FAIL: late hold decay expected Okay, got %s" % Balance.TIER_NAMES[okay_late])
		return false

	var bad_late := swing.evaluate_timing(
		contact + swing.contact_decay_sec() * 0.4, stats
	)
	if bad_late != Balance.TimingTier.BAD:
		print("FAIL: late hold decay expected Bad, got %s" % Balance.TIER_NAMES[bad_late])
		return false

	var miss_late := swing.evaluate_timing(contact + swing.contact_decay_sec() * 0.75, stats)
	if miss_late != Balance.TimingTier.MISS:
		print("FAIL: long late hold expected Miss, got %s" % Balance.TIER_NAMES[miss_late])
		return false

	print("OK: late hold tier decay Great → Good → Okay → Bad → Miss")
	return true


func _check_sweet_spot_upgrade() -> bool:
	var swing := ChargeSwing.new()
	var base_stats := Balance.default_stats()
	var upgraded := Balance.default_stats()
	upgraded.timing_window_perfect_ms = base_stats.timing_window_perfect_ms + 20.0

	var contact := swing.contact_time_sec()
	var edge_hold := contact - (base_stats.timing_window_perfect_ms + 5.0) / 1000.0
	var base_tier := swing.evaluate_timing(edge_hold, base_stats)
	var up_tier := swing.evaluate_timing(edge_hold, upgraded)
	if base_tier == Balance.TimingTier.PERFECT:
		print("FAIL: edge hold should not be Perfect at base window")
		return false
	if up_tier != Balance.TimingTier.PERFECT:
		print("FAIL: upgraded window should grant Perfect at same hold")
		return false
	print("OK: sweet spot upgrade widens perfect window")
	return true


## Real-3D flight: apex height is `visual_yards * apex_ratio_for(flavor)` —
## verify the flavor ordering the old BallFlightRenderer arc heights used to
## encode (pure highest, slightly-fat lower, thin/chunk lowest/hop-low).
func _check_flavor_arc() -> bool:
	var stats := Balance.default_stats()

	var thin_path := BallFlight3D.build_path(
		3.0, Balance.TimingTier.MISS, stats, Balance.ContactFlavor.THIN
	)
	var chunk_path := BallFlight3D.build_path(
		3.0, Balance.TimingTier.MISS, stats, Balance.ContactFlavor.CHUNK
	)
	var pure_path := BallFlight3D.build_path(
		30.0, Balance.TimingTier.PERFECT, stats, Balance.ContactFlavor.PURE
	)
	var fat_path := BallFlight3D.build_path(
		20.0, Balance.TimingTier.OKAY, stats, Balance.ContactFlavor.SLIGHTLY_FAT
	)

	if thin_path.apex_height >= pure_path.apex_height:
		print("FAIL: thin flavor apex %.2f should stay low vs pure %.2f" % [thin_path.apex_height, pure_path.apex_height])
		return false
	if chunk_path.apex_height >= 2.0:
		print("FAIL: chunk flavor apex %.2f should stay hop-low" % chunk_path.apex_height)
		return false
	if fat_path.apex_height >= pure_path.apex_height:
		print(
			"FAIL: slightly-fat apex %.2f should stay below pure apex %.2f"
			% [fat_path.apex_height, pure_path.apex_height]
		)
		return false
	if fat_path.apex_height <= thin_path.apex_height:
		print(
			"FAIL: slightly-fat apex %.2f should stay above a thin skid %.2f"
			% [fat_path.apex_height, thin_path.apex_height]
		)
		return false
	print("OK: flavor apex heights ordered thin/chunk < fat < pure")
	return true
