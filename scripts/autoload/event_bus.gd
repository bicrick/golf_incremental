extends Node
## Global signal hub — scenes subscribe; game logic emits.

signal swing_resolved(yards: float, timing_tier: int, payout: float, feedback_tier: int)
signal upgrade_purchased(id: String, level: int, branch: int)
signal stats_changed(stats: PlayerStats, currency: float)
signal milestone_reached(id: String, display_name: String)
signal swing_charging_changed(charging: bool)
signal swing_charge_updated(power: float, in_release_band: bool, past_peak: bool)
signal ui_panel_toggled(panel_id: String, is_open: bool)
signal bucket_changed(count: int, capacity: int)
signal phase_changed(phase: String)
signal ball_collected(world_pos: Vector2, combo: int)
signal bucket_completed(bonus: float)
signal pickup_payout(amount: float, combo: int)
