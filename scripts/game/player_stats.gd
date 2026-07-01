class_name PlayerStats
extends Resource
## Aggregated stat sheet — recomputed when upgrades change.

# Rhythm — 6-tier ladder (Perfect/Great/Good/Okay/Bad/Miss), Perfect kept tight/rare by default.
@export var timing_window_perfect_ms: float = 15.0
@export var timing_window_great_ms: float = 40.0
@export var timing_window_good_ms: float = 80.0
@export var timing_window_okay_ms: float = 140.0
@export var timing_window_bad_ms: float = 220.0
@export var swing_cooldown_ms: float = 800.0

# Distance (flight only — payout yardage comes from resolved swing yards)
@export var base_yards: float = 30.0
@export var yard_multiplier: float = 1.0
@export var max_yards: float = 45.0
@export var yard_variance: float = 0.2

# Pickup payout formula
@export var base_amount: float = 0.25
@export var yardage_multiplier: float = 0.02
@export var quality_multiplier: float = 1.0
@export var yardage_term_unlocked: float = 0.0
@export var quality_term_unlocked: float = 0.0

# Equipment (Shop — deferred)
@export var club_multiplier: float = 1.0
@export var ball_multiplier: float = 1.0

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


static func duplicate_stats(from: PlayerStats) -> PlayerStats:
	var copy := PlayerStats.new()
	copy.timing_window_perfect_ms = from.timing_window_perfect_ms
	copy.timing_window_great_ms = from.timing_window_great_ms
	copy.timing_window_good_ms = from.timing_window_good_ms
	copy.timing_window_okay_ms = from.timing_window_okay_ms
	copy.timing_window_bad_ms = from.timing_window_bad_ms
	copy.swing_cooldown_ms = from.swing_cooldown_ms
	copy.base_yards = from.base_yards
	copy.yard_multiplier = from.yard_multiplier
	copy.max_yards = from.max_yards
	copy.yard_variance = from.yard_variance
	copy.base_amount = from.base_amount
	copy.yardage_multiplier = from.yardage_multiplier
	copy.quality_multiplier = from.quality_multiplier
	copy.yardage_term_unlocked = from.yardage_term_unlocked
	copy.quality_term_unlocked = from.quality_term_unlocked
	copy.club_multiplier = from.club_multiplier
	copy.ball_multiplier = from.ball_multiplier
	copy.target_zone_multiplier = from.target_zone_multiplier
	copy.outfit_multiplier = from.outfit_multiplier
	copy.global_multiplier = from.global_multiplier
	copy.flat_bonus_per_swing = from.flat_bonus_per_swing
	copy.bucket_capacity_bonus = from.bucket_capacity_bonus
	copy.passive_swings_per_second = from.passive_swings_per_second
	copy.passive_payout_multiplier = from.passive_payout_multiplier
	return copy
