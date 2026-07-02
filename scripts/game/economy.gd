class_name Economy
extends RefCounted
## Payout and purchase logic.


static func upgrade_cost(base: float, growth: float, level: int) -> float:
	var stretch := 1.0 + float(level) * Balance.UPGRADE_COST_LEVEL_STRETCH
	return floor(base * pow(growth, level) * stretch * 100.0 + 0.0001) / 100.0


static func resolve_payout(
	_timing_tier: int,
	stats: PlayerStats,
	timing_quality: float = 1.0
) -> Dictionary:
	var yards: float = yards_from_quality(timing_quality, stats)
	return { "yards": yards }


## Gameplay carry — stats + strike quality only (no cap, no pay stats).
static func yards_from_quality(strike_quality: float, stats: PlayerStats) -> float:
	var q := clampf(strike_quality, stats.yard_quality_floor, 1.0)
	return stats.base_yards * stats.carry_multiplier * q


static func quality_for_tier(timing_tier: int) -> int:
	if timing_tier < 0 or timing_tier >= Balance.QUALITY_FOR_TIER.size():
		return 1
	return Balance.QUALITY_FOR_TIER[timing_tier]


static func resolve_pickup_ball_payout(
	quality: int,
	yardage: float,
	combo_tier: int,
	stats: PlayerStats
) -> float:
	var shot_value := _shot_value(quality, yardage, stats)
	shot_value = _apply_pickup_layer(shot_value, stats)
	return shot_value * combo_multiplier(combo_tier, stats)


static func _shot_value(quality: int, yardage: float, stats: PlayerStats) -> float:
	var payout := stats.base_amount
	if stats.yardage_term_unlocked > 0.0:
		payout += stats.base_amount * stats.pay_per_yard * maxf(yardage, 0.0)
	if stats.quality_term_unlocked > 0.0:
		payout *= float(maxi(quality, 1)) * stats.quality_multiplier
	return payout


static func _apply_pickup_layer(shot_value: float, stats: PlayerStats) -> float:
	if stats.pickup_bonus_unlocked <= 0.0:
		return shot_value
	return shot_value * stats.pickup_multiplier + stats.pickup_flat_bonus


## Ball flight depth on the range fairway (0 at tee → 1.0 at VISUAL_MAX_YARDS).
static func visual_depth_t(yards: float, _stats: PlayerStats) -> float:
	var y := maxf(yards, 0.0)
	var scale := Balance.PERSPECTIVE_DEPTH_SCALE
	var max_y := Balance.VISUAL_MAX_YARDS
	var denom := 1.0 - exp(-max_y / scale)
	if denom < 0.0001:
		return clampf(y / max_y, 0.0, 1.0)
	var normalized := (1.0 - exp(-y / scale)) / denom
	return clampf(pow(normalized, Balance.PERSPECTIVE_DEPTH_EXPONENT), 0.0, 1.0)


static func visual_landing_y(
	yards: float,
	tee_y: float,
	horizon_y: float,
	stats: PlayerStats
) -> float:
	return lerpf(tee_y, horizon_y, visual_depth_t(yards, stats))


static func combo_multiplier(combo_tier: int, stats: PlayerStats) -> float:
	if stats.combo_mult_per_tier <= 0.0:
		return 1.0
	var tier := maxi(combo_tier, 1)
	return 1.0 + stats.combo_mult_per_tier * float(tier - 1)


static func combo_window_sec(stats: PlayerStats) -> float:
	return Balance.COMBO_WINDOW_SEC + stats.combo_window_bonus_sec
