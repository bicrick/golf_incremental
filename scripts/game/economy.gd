class_name Economy
extends RefCounted
## Payout and purchase logic.


static func upgrade_cost(base: float, growth: float, level: int) -> float:
	return floor(base * pow(growth, level))


static func resolve_payout(
	_timing_tier: int,
	stats: PlayerStats,
	timing_quality: float = 1.0
) -> Dictionary:
	var yards: float = yards_from_quality(timing_quality, stats)
	return { "yards": yards }


static func yards_from_quality(timing_quality: float, stats: PlayerStats) -> float:
	return minf(
		stats.base_yards * stats.yard_multiplier * clampf(timing_quality, 0.0, 1.0),
		stats.max_yards
	)


## Legacy discrete-tier yard formula (pre-continuous quality).
static func yards_from_tier(timing_tier: int, stats: PlayerStats) -> float:
	var tier_mult: float = Balance.TIER_MULTS.get(timing_tier, 0.1)
	return minf(stats.base_yards * stats.yard_multiplier * tier_mult, stats.max_yards)


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
	var payout := stats.base_amount
	if stats.yardage_term_unlocked > 0.0:
		payout *= maxf(yardage, 0.0) * stats.yardage_multiplier
	if stats.quality_term_unlocked > 0.0:
		payout *= float(maxi(quality, 1)) * stats.quality_multiplier
	return payout * combo_multiplier(combo_tier)


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


static func combo_multiplier(combo_tier: int) -> float:
	var tier := maxi(combo_tier, 1)
	return 1.0 + Balance.COMBO_MULT_PER_TIER * float(tier - 1)


static func bucket_complete_bonus_value(stats: PlayerStats) -> float:
	return Balance.BUCKET_COMPLETE_BONUS * stats.global_multiplier
