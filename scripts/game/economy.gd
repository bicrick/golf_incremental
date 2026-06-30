class_name Economy
extends RefCounted
## Payout and purchase logic — Workstream B implements fully.


static func upgrade_cost(base: float, growth: float, level: int) -> float:
	return floor(base * pow(growth, level))


static func resolve_payout(timing_tier: int, combo: int, stats: PlayerStats) -> Dictionary:
	var tier_mult: float = Balance.TIER_MULTS.get(timing_tier, 0.1)
	var combo_mult: float = 1.0 + combo * Balance.COMBO_BONUS_PER_STACK
	var yards: float = min(stats.base_yards * stats.yard_multiplier * tier_mult, stats.max_yards)
	var payout: float = (
		yards * combo_mult * stats.club_multiplier * stats.ball_multiplier
		* stats.target_zone_multiplier * stats.outfit_multiplier
		* stats.global_multiplier * stats.dollars_per_yard
		+ stats.flat_bonus_per_swing
	)
	return { "payout": payout, "yards": yards }
