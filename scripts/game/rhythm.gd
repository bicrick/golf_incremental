class_name ChargeSwing
extends RefCounted
## Contact timing — release at wind-up contact (frame 8), not hold-to-peak power.


func contact_time_sec() -> float:
	return Balance.CONTACT_WINDUP_SEC


func contact_decay_sec() -> float:
	return Balance.CONTACT_DECAY_SEC


func charge_duration_sec() -> float:
	return contact_time_sec()


func charge_decay_sec() -> float:
	return contact_decay_sec()


## Linear 0–1 wind-up progress for anim frames 0–7.
func windup_progress(elapsed_sec: float) -> float:
	if elapsed_sec <= 0.0:
		return 0.0
	return clampf(elapsed_sec / contact_time_sec(), 0.0, 1.0)


func charge_progress(elapsed_sec: float) -> float:
	return windup_progress(elapsed_sec)


func past_contact(elapsed_sec: float) -> bool:
	return elapsed_sec > contact_time_sec()


func past_contact_fraction(elapsed_sec: float) -> float:
	var contact := contact_time_sec()
	if elapsed_sec <= contact:
		return 0.0
	return clampf((elapsed_sec - contact) / contact_decay_sec(), 0.0, 1.0)


func overshoot_fraction(elapsed_sec: float) -> float:
	return past_contact_fraction(elapsed_sec)


## Wind-up progress alias for legacy charge visuals.
func power_at(elapsed_sec: float) -> float:
	return windup_progress(elapsed_sec)


func is_in_contact_band(elapsed_sec: float, stats: PlayerStats) -> bool:
	if elapsed_sec < Balance.MIN_HOLD_SEC:
		return false
	if past_contact(elapsed_sec):
		return false
	var early_ms := (contact_time_sec() - elapsed_sec) * 1000.0
	return early_ms <= stats.timing_window_perfect_ms


func is_in_release_band(elapsed_sec: float, stats: PlayerStats) -> bool:
	return is_in_contact_band(elapsed_sec, stats)


func contact_flavor(tier: int, hold_duration_sec: float, _stats: PlayerStats) -> int:
	if tier == Balance.TimingTier.MISS:
		if hold_duration_sec < Balance.MIN_HOLD_SEC:
			return Balance.ContactFlavor.THIN
		if hold_duration_sec < contact_time_sec():
			return Balance.ContactFlavor.THIN
		return Balance.ContactFlavor.CHUNK
	if tier == Balance.TimingTier.BAD or tier == Balance.TimingTier.OKAY:
		return Balance.ContactFlavor.SLIGHTLY_FAT
	return Balance.ContactFlavor.PURE


## Continuous 0–1 quality for yard distance (1 = dead-center at contact).
func timing_quality(hold_duration_sec: float, stats: PlayerStats) -> float:
	if hold_duration_sec < Balance.MIN_HOLD_SEC:
		return stats.yard_quality_floor

	var contact := contact_time_sec()
	var delta_sec := hold_duration_sec - contact

	if delta_sec <= 0.0:
		return _yard_quality_early(absf(delta_sec) * 1000.0, stats)
	return _yard_quality_late(delta_sec * 1000.0, stats)


func _yard_quality_early(error_ms: float, stats: PlayerStats) -> float:
	var floor := stats.yard_quality_floor
	var span := 1.0 - floor
	var sigma := maxf(stats.timing_window_good_ms, 1.0)
	return floor + span * exp(-0.5 * pow(error_ms / sigma, 2.0))


func _yard_quality_late(late_ms: float, stats: PlayerStats) -> float:
	var floor := stats.yard_quality_floor
	var peak := stats.yard_quality_late_peak
	var span := peak - floor
	var sigma := maxf(stats.timing_window_late_good_ms, 1.0)
	return floor + span * exp(-0.5 * pow(late_ms / sigma, 2.0))


func evaluate_timing(hold_duration_sec: float, stats: PlayerStats) -> int:
	if hold_duration_sec < Balance.MIN_HOLD_SEC:
		return Balance.TimingTier.MISS

	var contact := contact_time_sec()
	var delta_sec := hold_duration_sec - contact

	if delta_sec <= 0.0:
		var early_ms := absf(delta_sec) * 1000.0
		if early_ms <= stats.timing_window_perfect_ms:
			return Balance.TimingTier.PERFECT
		if early_ms <= stats.timing_window_great_ms:
			return Balance.TimingTier.GREAT
		if early_ms <= stats.timing_window_good_ms:
			return Balance.TimingTier.GOOD
		if early_ms <= stats.timing_window_okay_ms:
			return Balance.TimingTier.OKAY
		if early_ms <= stats.timing_window_bad_ms:
			return Balance.TimingTier.BAD
		return Balance.TimingTier.MISS

	var late_ms := delta_sec * 1000.0
	if late_ms <= stats.timing_window_late_great_ms:
		return Balance.TimingTier.GREAT
	if late_ms <= stats.timing_window_late_good_ms:
		return Balance.TimingTier.GOOD
	if late_ms <= stats.timing_window_late_okay_ms:
		return Balance.TimingTier.OKAY
	if delta_sec <= stats.timing_window_late_bad_max_sec:
		return Balance.TimingTier.BAD
	return Balance.TimingTier.MISS


## Signed offline launch angle from hold duration — tier-ladder keyed to evaluate_timing ms stops.
func offline_degrees_from_hold(hold_sec: float, stats: PlayerStats) -> float:
	if hold_sec < Balance.MIN_HOLD_SEC:
		return Balance.LANDING_MAX_OFFLINE_DEG

	var contact := contact_time_sec()
	var delta_sec := hold_sec - contact
	if absf(delta_sec) < 0.0001:
		return 0.0

	var magnitude := 0.0
	if delta_sec < 0.0:
		var early_ms := absf(delta_sec) * 1000.0
		var stops: Array = [
			[stats.timing_window_perfect_ms, Balance.TimingTier.GREAT],
			[stats.timing_window_great_ms, Balance.TimingTier.GOOD],
			[stats.timing_window_good_ms, Balance.TimingTier.OKAY],
			[stats.timing_window_bad_ms, Balance.TimingTier.BAD],
		]
		magnitude = _ladder_offline_deg(
			early_ms, Balance.TimingTier.PERFECT, stops, Balance.TIER_OFFLINE_DEG_EARLY
		)
	else:
		var late_ms := delta_sec * 1000.0
		var stops: Array = [
			[stats.timing_window_late_great_ms, Balance.TimingTier.GOOD],
			[stats.timing_window_late_good_ms, Balance.TimingTier.OKAY],
			[stats.timing_window_late_okay_ms, Balance.TimingTier.BAD],
			[stats.timing_window_late_bad_max_sec * 1000.0, Balance.TimingTier.MISS],
		]
		magnitude = _ladder_offline_deg(
			late_ms, Balance.TimingTier.GREAT, stops, Balance.TIER_OFFLINE_DEG_LATE
		)

	return signf(delta_sec) * magnitude


func _ladder_offline_deg(value_ms: float, start_tier: int, stops: Array, anchors: Dictionary) -> float:
	var prev_ms := 0.0
	var prev_deg: float = anchors.get(start_tier, 0.0)
	for stop in stops:
		var threshold_ms: float = stop[0]
		var tier: int = stop[1]
		var deg: float = anchors.get(tier, Balance.LANDING_MAX_OFFLINE_DEG)
		if value_ms <= threshold_ms:
			var t := inverse_lerp(prev_ms, maxf(threshold_ms, prev_ms + 0.001), value_ms)
			return lerpf(prev_deg, deg, clampf(t, 0.0, 1.0))
		prev_ms = threshold_ms
		prev_deg = deg
	return Balance.LANDING_MAX_OFFLINE_DEG
