class_name PlayerStats
extends Resource
## Aggregated stat sheet — recomputed when upgrades change.

# Rhythm — 6-tier ladder (Perfect/Great/Good/Okay/Bad/Miss)
@export var timing_window_perfect_ms: float = 15.0
@export var timing_window_great_ms: float = 40.0
@export var timing_window_good_ms: float = 80.0
@export var timing_window_okay_ms: float = 140.0
@export var timing_window_bad_ms: float = 220.0
@export var timing_window_late_great_ms: float = 15.0
@export var timing_window_late_good_ms: float = 35.0
@export var timing_window_late_okay_ms: float = 90.0
@export var timing_window_late_bad_max_sec: float = 0.3
@export var swing_cooldown_ms: float = 800.0

# Strike quality curve (carry distance scaling)
@export var yard_quality_floor: float = 0.08
@export var yard_quality_late_peak: float = 0.92

# Carry (flight only — never affects pickup $ directly)
@export var base_yards: float = 30.0
## Legacy — frozen at 1.0; distance-pays uses base_yards × contact × perfect_power.
@export var carry_multiplier: float = 1.0
@export var yard_variance: float = 0.2
## Sweet Spot — pulls high contact toward Perfect (flight only).
@export var sweet_spot_unlocked: float = 0.0
@export var sweet_spot_bonus: float = 0.0
## Perfect Pop — multiplies yards on near-Perfect contact (1.0 = off).
@export var perfect_power_bonus: float = 1.0

# Pickup payout formula (distance-pays: base + $/yard × yards; no quality $ term)
@export var base_amount: float = 0.25
@export var pay_per_yard: float = 0.1
@export var yardage_term_unlocked: float = 0.0
## Legacy stubs — no longer applied in Economy.
@export var quality_multiplier: float = 1.0
@export var quality_term_unlocked: float = 0.0

# Pickup branch bonuses
@export var pickup_bonus_unlocked: float = 0.0
@export var pickup_multiplier: float = 1.0
@export var pickup_flat_bonus: float = 0.0
@export var combo_mult_per_tier: float = 0.0
@export var combo_window_bonus_sec: float = 0.0
@export var range_picker_radius_bonus: float = 0.0

# Equipment (Shop)
@export var club_multiplier: float = 1.0
@export var ball_multiplier: float = 1.0
@export var golden_ball_chance: float = 0.0
@export var golden_ball_payout_multiplier: float = 2.0

# Range (v1.5+)
@export var target_zone_multiplier: float = 1.0

# Outfits (Shop — deferred)
@export var outfit_multiplier: float = 1.0

# Economy
@export var global_multiplier: float = 1.0
@export var flat_bonus_per_swing: float = 0.0
@export var bucket_capacity_bonus: float = 0.0

# Passive (v2+)
@export var passive_swings_per_second: float = 0.0
@export var passive_payout_multiplier: float = 1.0

# Ratina — autonomous swing consistency (0..1, only used by Ratina tree)
@export var consistency: float = 0.0

# Rattling — forest-edge ball collectors (only used by Rattling tree)
@export var rattling_count: float = 0.0
@export var rattling_walk_speed: float = 3.2
@export var rattling_pickup_speed_multiplier: float = 1.0
@export var rattling_golden_bonus_chance: float = 0.0
## v5 crew refactor — Rattlings fetch leftovers at this share of full pay.
@export var rattling_leftover_share: float = 0.4
## v5 crew refactor — Ratina coaches: a mark each bucket; balls resting inside
## `ratina_mark_radius` yards pay × `ratina_mark_bonus` at pickup.
@export var ratina_mark_bonus: float = 2.0
@export var ratina_mark_radius: float = 4.0
@export var ratina_mark_golden_chance: float = 0.0

## Prestige — Perfect Chain unlock (0/1)
@export var perfect_chain_unlocked: float = 0.0


static func duplicate_stats(from: PlayerStats) -> PlayerStats:
	var copy := PlayerStats.new()
	copy.timing_window_perfect_ms = from.timing_window_perfect_ms
	copy.timing_window_great_ms = from.timing_window_great_ms
	copy.timing_window_good_ms = from.timing_window_good_ms
	copy.timing_window_okay_ms = from.timing_window_okay_ms
	copy.timing_window_bad_ms = from.timing_window_bad_ms
	copy.timing_window_late_great_ms = from.timing_window_late_great_ms
	copy.timing_window_late_good_ms = from.timing_window_late_good_ms
	copy.timing_window_late_okay_ms = from.timing_window_late_okay_ms
	copy.timing_window_late_bad_max_sec = from.timing_window_late_bad_max_sec
	copy.swing_cooldown_ms = from.swing_cooldown_ms
	copy.yard_quality_floor = from.yard_quality_floor
	copy.yard_quality_late_peak = from.yard_quality_late_peak
	copy.base_yards = from.base_yards
	copy.carry_multiplier = from.carry_multiplier
	copy.yard_variance = from.yard_variance
	copy.sweet_spot_unlocked = from.sweet_spot_unlocked
	copy.sweet_spot_bonus = from.sweet_spot_bonus
	copy.perfect_power_bonus = from.perfect_power_bonus
	copy.base_amount = from.base_amount
	copy.pay_per_yard = from.pay_per_yard
	copy.quality_multiplier = from.quality_multiplier
	copy.yardage_term_unlocked = from.yardage_term_unlocked
	copy.quality_term_unlocked = from.quality_term_unlocked
	copy.pickup_bonus_unlocked = from.pickup_bonus_unlocked
	copy.pickup_multiplier = from.pickup_multiplier
	copy.pickup_flat_bonus = from.pickup_flat_bonus
	copy.combo_mult_per_tier = from.combo_mult_per_tier
	copy.combo_window_bonus_sec = from.combo_window_bonus_sec
	copy.range_picker_radius_bonus = from.range_picker_radius_bonus
	copy.club_multiplier = from.club_multiplier
	copy.ball_multiplier = from.ball_multiplier
	copy.golden_ball_chance = from.golden_ball_chance
	copy.golden_ball_payout_multiplier = from.golden_ball_payout_multiplier
	copy.target_zone_multiplier = from.target_zone_multiplier
	copy.outfit_multiplier = from.outfit_multiplier
	copy.global_multiplier = from.global_multiplier
	copy.flat_bonus_per_swing = from.flat_bonus_per_swing
	copy.bucket_capacity_bonus = from.bucket_capacity_bonus
	copy.passive_swings_per_second = from.passive_swings_per_second
	copy.passive_payout_multiplier = from.passive_payout_multiplier
	copy.consistency = from.consistency
	copy.rattling_count = from.rattling_count
	copy.rattling_walk_speed = from.rattling_walk_speed
	copy.rattling_pickup_speed_multiplier = from.rattling_pickup_speed_multiplier
	copy.rattling_golden_bonus_chance = from.rattling_golden_bonus_chance
	copy.rattling_leftover_share = from.rattling_leftover_share
	copy.ratina_mark_bonus = from.ratina_mark_bonus
	copy.ratina_mark_radius = from.ratina_mark_radius
	copy.ratina_mark_golden_chance = from.ratina_mark_golden_chance
	copy.perfect_chain_unlocked = from.perfect_chain_unlocked
	return copy
