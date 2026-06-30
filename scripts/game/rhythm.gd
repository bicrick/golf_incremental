class_name ChargeSwing
extends RefCounted
## Charge curve and peak-timing evaluation for hold-release swings.

var combo: int = 0
var chain_mode: bool = false


func charge_duration_sec() -> float:
	if chain_mode:
		return Balance.CHARGE_DURATION_SEC * Balance.CHAIN_CHARGE_DURATION_SCALE
	return Balance.CHARGE_DURATION_SEC


func charge_decay_sec() -> float:
	if chain_mode:
		return Balance.CHARGE_DECAY_SEC * Balance.CHAIN_CHARGE_DECAY_SCALE
	return Balance.CHARGE_DECAY_SEC


func power_at(elapsed_sec: float) -> float:
	if elapsed_sec <= 0.0:
		return 0.0
	var duration := charge_duration_sec()
	if elapsed_sec < duration:
		var t := elapsed_sec / duration
		return t * t * (3.0 - 2.0 * t)
	var overshoot := elapsed_sec - duration
	return clampf(1.0 - overshoot / charge_decay_sec(), 0.0, 1.0)


func charge_progress(elapsed_sec: float) -> float:
	if elapsed_sec <= 0.0:
		return 0.0
	var duration := charge_duration_sec()
	if elapsed_sec >= duration:
		return 1.0
	var t := elapsed_sec / duration
	return t * t * (3.0 - 2.0 * t)


func overshoot_fraction(elapsed_sec: float) -> float:
	var duration := charge_duration_sec()
	if elapsed_sec <= duration:
		return 0.0
	return clampf(
		(elapsed_sec - duration) / charge_decay_sec(),
		0.0,
		1.0
	)


func outer_ring_scale(elapsed_sec: float) -> float:
	var duration := charge_duration_sec()
	if elapsed_sec <= duration:
		return lerpf(
			Balance.RING_OUTER_START_SCALE,
			Balance.RING_OUTER_ALIGN_SCALE,
			charge_progress(elapsed_sec)
		)
	var decay_t := overshoot_fraction(elapsed_sec)
	return lerpf(Balance.RING_OUTER_ALIGN_SCALE, Balance.RING_OUTER_OVERSHOOT_SCALE, decay_t)


func inner_ring_scale() -> float:
	return Balance.RING_INNER_SCALE


func is_in_release_band(elapsed_sec: float, stats: PlayerStats) -> bool:
	if elapsed_sec < Balance.MIN_HOLD_SEC:
		return false
	var error_ms := absf(elapsed_sec - charge_duration_sec()) * 1000.0
	return error_ms <= stats.timing_window_perfect_ms


## Continuous 0–1 quality for yard distance (1 = dead-center early release).
## Gaussian falloff from peak; late releases cap below 1.0. Tier labels stay discrete.
func timing_quality(hold_duration_sec: float, stats: PlayerStats) -> float:
	if hold_duration_sec < Balance.MIN_HOLD_SEC:
		return Balance.YARD_QUALITY_FLOOR

	var peak := charge_duration_sec()
	var delta_sec := hold_duration_sec - peak

	if delta_sec <= 0.0:
		return _yard_quality_early(absf(delta_sec) * 1000.0, stats)
	return _yard_quality_late(delta_sec * 1000.0)


func _yard_quality_early(error_ms: float, stats: PlayerStats) -> float:
	var floor := Balance.YARD_QUALITY_FLOOR
	var span := 1.0 - floor
	# sigma ≈ good window → ~0.7 quality at good edge, ~0.91 at perfect edge
	var sigma := maxf(stats.timing_window_good_ms * 0.85, 1.0)
	return floor + span * exp(-0.5 * pow(error_ms / sigma, 2.0))


func _yard_quality_late(late_ms: float) -> float:
	var floor := Balance.YARD_QUALITY_FLOOR
	var peak := Balance.YARD_QUALITY_LATE_PEAK
	var span := peak - floor
	var post_good_ms := Balance.POST_PEAK_GOOD_MS
	if chain_mode:
		post_good_ms *= Balance.CHAIN_CHARGE_DURATION_SCALE
	var sigma := maxf(post_good_ms * 1.25, 1.0)
	return floor + span * exp(-0.5 * pow(late_ms / sigma, 2.0))


func evaluate_timing(hold_duration_sec: float, stats: PlayerStats) -> int:
	if hold_duration_sec < Balance.MIN_HOLD_SEC:
		return Balance.TimingTier.MISS

	var peak := charge_duration_sec()
	var delta_sec := hold_duration_sec - peak

	if delta_sec <= 0.0:
		var early_ms := absf(delta_sec) * 1000.0
		if early_ms <= stats.timing_window_perfect_ms:
			return Balance.TimingTier.PERFECT
		if early_ms <= stats.timing_window_good_ms:
			return Balance.TimingTier.GOOD
		if early_ms <= stats.timing_window_good_ms * 1.5:
			return Balance.TimingTier.OK
		return Balance.TimingTier.MISS

	# Late release — no Perfect; degrades quickly through Good → OK → Miss.
	var overshoot_ms := delta_sec * 1000.0
	var post_peak_good_ms := Balance.POST_PEAK_GOOD_MS
	if chain_mode:
		post_peak_good_ms *= Balance.CHAIN_CHARGE_DURATION_SCALE
	if overshoot_ms <= post_peak_good_ms:
		return Balance.TimingTier.GOOD
	var ok_max := charge_decay_sec() * 0.5
	if delta_sec <= ok_max:
		return Balance.TimingTier.OK
	return Balance.TimingTier.MISS
