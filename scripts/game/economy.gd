class_name Economy
extends RefCounted
## Payout and purchase logic — Workstream B implements fully.


static func upgrade_cost(base: float, growth: float, level: int) -> float:
	return floor(base * pow(growth, level))


static func resolve_payout(
	timing_tier: int,
	stats: PlayerStats,
	timing_quality: float = 1.0
) -> Dictionary:
	var tier_mult: float = Balance.TIER_MULTS.get(timing_tier, 0.1)
	var yards: float = yards_from_quality(timing_quality, stats)

	var payout: float = (
		yards * tier_mult * stats.club_multiplier * stats.ball_multiplier
		* stats.target_zone_multiplier * stats.outfit_multiplier
		* stats.global_multiplier * stats.dollars_per_yard
		+ stats.flat_bonus_per_swing
	)
	if timing_tier == Balance.TimingTier.PERFECT and stats.perfect_payout_bonus > 0.0:
		payout *= 1.0 + stats.perfect_payout_bonus
	return { "payout": payout, "yards": yards }


static func yards_from_quality(timing_quality: float, stats: PlayerStats) -> float:
	return minf(
		stats.base_yards * stats.yard_multiplier * clampf(timing_quality, 0.0, 1.0),
		stats.max_yards
	)


## Legacy discrete-tier yard formula (pre-continuous quality).
static func yards_from_tier(timing_tier: int, stats: PlayerStats) -> float:
	var tier_mult: float = Balance.TIER_MULTS.get(timing_tier, 0.1)
	return minf(stats.base_yards * stats.yard_multiplier * tier_mult, stats.max_yards)


## Ball flight depth on the range fairway (0 at tee → 1.0 at VISUAL_MAX_YARDS).
## Non-linear: equal yard steps shrink on screen toward the horizon (parallax).
## Gameplay max_yards caps payout yards only — not screen placement.
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
