# Data Model

## Core enums

```gdscript
enum TimingTier { PERFECT, GOOD, OK, MISS }

enum FeedbackTier { WHISPER, WARM, JACKPOT, MILESTONE }

enum UpgradeBranch {
	RHYTHM,
	DISTANCE,
	CLUBS,
	BALLS,
	RANGE,
	OUTFITS,
	ECONOMY,
	FRIENDS,
}
```

String keys used in save JSON: `"perfect"`, `"good"`, `"ok"`, `"miss"`.

## PlayerStats

Aggregated stat sheet — recomputed when upgrades change. Use a `Resource` or plain class:

```gdscript
class_name PlayerStats
extends Resource

# Rhythm
@export var timing_window_perfect_ms: float = 50.0
@export var timing_window_good_ms: float = 100.0
@export var swing_cooldown_ms: float = 800.0
@export var combo_decay_slow: float = 0.0
@export var good_counts_for_combo: bool = false
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
```

Default stats from `scripts/config/balance.gd` → `DEFAULT_STATS`.

## UpgradeDefinition

```gdscript
class_name UpgradeDefinition
extends Resource

@export var id: String
@export var branch: UpgradeBranch
@export var display_name: String
@export var description: String
@export var max_level: int = 10
@export var base_cost: float = 10.0
@export var growth_rate: float = 1.15
@export var prerequisite_id: String = ""
@export var prerequisite_level: int = 0
@export var milestone_stat: String = ""
@export var milestone_value: float = 0.0
@export var effect_type: String = "multiply"  # multiply | add | set | unlock
@export var effect_stat: String = ""
@export var effect_per_level: float = 1.1
@export var named_unlocks: Dictionary = {}  # level -> String
```

Alternative v1: static `Array` of dictionaries in `definitions.gd` if Resources are overkill initially.

## LifetimeStats

```gdscript
class_name LifetimeStats
extends Resource

@export var total_swings: int = 0
@export var lifetime_yards: float = 0.0
@export var lifetime_earnings: float = 0.0
@export var best_combo: int = 0
@export var perfect_count: int = 0
```

## SaveData

Serialized to `user://save.json`:

```gdscript
# Keys in saved Dictionary / JSON
var save_data := {
	"version": 1,
	"currency": 0.0,
	"upgrade_levels": {},  # String -> int
	"lifetime": {
		"total_swings": 0,
		"lifetime_yards": 0.0,
		"lifetime_earnings": 0.0,
		"best_combo": 0,
		"perfect_count": 0,
	},
	"last_save_time": 0,  # unix ms
}
```

### Save version migration

- Increment `version` on breaking changes
- `SaveManager` migrates or resets with warning

### Example save JSON

```json
{
  "version": 1,
  "currency": 12345,
  "upgrade_levels": {
    "metronome": 3,
    "leg_day": 2,
    "dollars_per_yard": 1
  },
  "lifetime": {
    "total_swings": 500,
    "lifetime_yards": 4200,
    "lifetime_earnings": 15000,
    "best_combo": 7,
    "perfect_count": 120
  },
  "last_save_time": 1719700000000
}
```

## EventBus signals

Defined in `scripts/autoload/event_bus.gd`:

```gdscript
extends Node

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
```

Scenes connect in `_ready()`:

```gdscript
EventBus.swing_resolved.connect(_on_swing_resolved)
```

Logic emits via `EventBus.swing_resolved.emit(...)`. No direct scene references from economy.

## Effect application

When upgrade purchased or on load:

1. Start from `DEFAULT_STATS` in `balance.gd`
2. For each upgrade level, apply effect in stable-sorted definition order
3. Cache in `GameState.stats`
4. `EventBus.stats_changed.emit(stats, currency)`

```gdscript
func apply_multiply_effect(stats: PlayerStats, stat_name: String, per_level: float, level: int) -> void:
	var current: float = stats.get(stat_name)
	stats.set(stat_name, current * pow(per_level, level))
```

## Payout resolution (reference)

```gdscript
func resolve_payout(
	timing_tier: int,
	combo: int,
	stats: PlayerStats,
	target_zone_mult: float = 1.0
) -> Dictionary:
	var tier_mult: float = Balance.TIER_MULTS[timing_tier]
	var combo_mult: float = 1.0 + combo * Balance.COMBO_BONUS_PER_STACK
	var yards: float = min(
		stats.base_yards * stats.yard_multiplier * tier_mult,
		stats.max_yards
	)
	var payout: float = (
		yards * combo_mult * stats.club_multiplier * stats.ball_multiplier
		* target_zone_mult * stats.outfit_multiplier * stats.global_multiplier
		* stats.dollars_per_yard + stats.flat_bonus_per_swing
	)
	var feedback_tier: int = classify_feedback(payout, timing_tier, combo)
	return { "payout": payout, "feedback_tier": feedback_tier, "yards": yards }
```

Full rules: [../design/03-economy.md](../design/03-economy.md).

## Rhythm state

Held in `Rhythm` class or `GameState`:

```gdscript
var bpm: float = 66.0
var beat_phase: float = 0.0       # 0.0–1.0
var combo: int = 0
var last_swing_time_msec: int = 0
var can_swing: bool = true
```

## Related docs

- Architecture: [01-architecture.md](01-architecture.md)
- Agent contracts: [03-agent-workstreams.md](03-agent-workstreams.md)
