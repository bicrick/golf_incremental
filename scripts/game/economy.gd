class_name Economy
extends RefCounted
## Payout and purchase logic — Workstream B implements fully.


static func upgrade_cost(base: float, growth: float, level: int) -> float:
	return floor(base * pow(growth, level))


static func resolve_payout(
	timing_tier: int,
	combo: int,
	stats: PlayerStats,
	chain_level: int = 1,
	timing_quality: float = 1.0
) -> Dictionary:
	var tier_mult: float = Balance.TIER_MULTS.get(timing_tier, 0.1)
	var combo_mult: float = 1.0 + combo * Balance.COMBO_BONUS_PER_STACK
	var chain_mult: float = Balance.CHAIN_LEVEL_2_MULT if chain_level >= 2 else 1.0
	# Yards: continuous quality curve; tier mult applies to payout only.
	var yards: float = yards_from_quality(timing_quality, stats)
	var payout: float = (
		yards * tier_mult * combo_mult * chain_mult * stats.club_multiplier * stats.ball_multiplier
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
