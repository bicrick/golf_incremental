class_name PlayerStats
extends Resource
## Aggregated stat sheet — recomputed when upgrades change.

# Rhythm
@export var timing_window_perfect_ms: float = 50.0
@export var timing_window_good_ms: float = 100.0
@export var swing_cooldown_ms: float = 800.0
@export var perfect_payout_bonus: float = 0.0

# Distance
@export var base_yards: float = 10.0
@export var yard_multiplier: float = 1.0
@export var max_yards: float = 50.0
@export var yard_variance: float = 0.2

# Equipment
@export var club_multiplier: float = 1.0
@export var ball_multiplier: float = 1.0

# Range (v1.5+)
@export var target_zone_multiplier: float = 1.0

# Outfits (v1.5+)
@export var outfit_multiplier: float = 1.0

# Economy
@export var dollars_per_yard: float = 1.0
@export var global_multiplier: float = 1.0
@export var flat_bonus_per_swing: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 10.0

# Passive (v2)
@export var passive_swings_per_second: float = 0.0
@export var passive_payout_multiplier: float = 1.0


static func duplicate_stats(from: PlayerStats) -> PlayerStats:
	var copy := PlayerStats.new()
	copy.timing_window_perfect_ms = from.timing_window_perfect_ms
	copy.timing_window_good_ms = from.timing_window_good_ms
	copy.swing_cooldown_ms = from.swing_cooldown_ms
	copy.perfect_payout_bonus = from.perfect_payout_bonus
	copy.base_yards = from.base_yards
	copy.yard_multiplier = from.yard_multiplier
	copy.max_yards = from.max_yards
	copy.yard_variance = from.yard_variance
	copy.club_multiplier = from.club_multiplier
	copy.ball_multiplier = from.ball_multiplier
	copy.target_zone_multiplier = from.target_zone_multiplier
	copy.outfit_multiplier = from.outfit_multiplier
	copy.dollars_per_yard = from.dollars_per_yard
	copy.global_multiplier = from.global_multiplier
	copy.flat_bonus_per_swing = from.flat_bonus_per_swing
	copy.crit_chance = from.crit_chance
	copy.crit_multiplier = from.crit_multiplier
	copy.passive_swings_per_second = from.passive_swings_per_second
	copy.passive_payout_multiplier = from.passive_payout_multiplier
	return copy
