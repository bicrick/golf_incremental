extends Node
## Global signal hub — scenes subscribe; game logic emits.

signal swing_resolved(
	yards: float,
	timing_tier: int,
	payout: float,
	feedback_tier: int,
	combo: int,
	chain_level: int
)
signal swing_chain_window_started
signal swing_chain_window_expired
signal swing_chain_charging_started
signal swing_chain_state_changed(active: bool, chain_level: int)
signal upgrade_purchased(id: String, level: int, branch: int)
signal stats_changed(stats: PlayerStats, currency: float)
signal milestone_reached(id: String, display_name: String)
signal combo_broken(previous_combo: int)
signal swing_charging_changed(charging: bool)
signal swing_charge_updated(power: float, in_release_band: bool, past_peak: bool)
signal ui_panel_toggled(panel_id: String, is_open: bool)
