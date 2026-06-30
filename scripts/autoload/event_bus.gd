extends Node
## Global signal hub — scenes subscribe; game logic emits.

signal swing_resolved(
	yards: float,
	timing_tier: int,
	payout: float,
	feedback_tier: int,
	combo: int
)
signal upgrade_purchased(id: String, level: int, branch: int)
signal stats_changed(stats: PlayerStats, currency: float)
signal milestone_reached(id: String, display_name: String)
signal combo_broken(previous_combo: int)
