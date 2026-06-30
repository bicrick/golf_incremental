class_name UpgradeEffects
extends RefCounted
## Apply upgrade effects to PlayerStats — stable definition order.


static func apply_all(stats: PlayerStats, levels: Dictionary) -> void:
	for def in UpgradeDefinitions.all():
		var id: String = def["id"]
		var level: int = levels.get(id, 0)
		if level <= 0:
			continue
		_apply_effect(stats, def["effect"], level)


static func _apply_effect(stats: PlayerStats, effect: Dictionary, level: int) -> void:
	match effect.get("type", ""):
		"multiply":
			_apply_multiply(stats, str(effect.get("stat", "")), float(effect.get("value_per_level", 1.0)), level)
		"add":
			_apply_add(stats, str(effect.get("stat", "")), float(effect.get("value_per_level", 0.0)), level)
		"binary":
			_apply_binary(stats, str(effect.get("stat", "")), effect.get("value", 0))


static func _apply_multiply(stats: PlayerStats, stat_name: String, per_level: float, level: int) -> void:
	var current: float = _read_stat(stats, stat_name)
	_write_stat(stats, stat_name, current * pow(per_level, level))


static func _apply_add(stats: PlayerStats, stat_name: String, per_level: float, level: int) -> void:
	var current: float = _read_stat(stats, stat_name)
	_write_stat(stats, stat_name, current + per_level * level)


static func _apply_binary(stats: PlayerStats, stat_name: String, value: Variant) -> void:
	_write_stat(stats, stat_name, 1.0 if bool(value) else 0.0)


static func _read_stat(stats: PlayerStats, stat_name: String) -> float:
	match stat_name:
		"timing_window_perfect_ms":
			return stats.timing_window_perfect_ms
		"timing_window_good_ms":
			return stats.timing_window_good_ms
		"swing_cooldown_ms":
			return stats.swing_cooldown_ms
		"perfect_payout_bonus":
			return stats.perfect_payout_bonus
		"base_yards":
			return stats.base_yards
		"yard_multiplier":
			return stats.yard_multiplier
		"max_yards":
			return stats.max_yards
		"yard_variance":
			return stats.yard_variance
		"club_multiplier":
			return stats.club_multiplier
		"ball_multiplier":
			return stats.ball_multiplier
		"target_zone_multiplier":
			return stats.target_zone_multiplier
		"outfit_multiplier":
			return stats.outfit_multiplier
		"dollars_per_yard":
			return stats.dollars_per_yard
		"global_multiplier":
			return stats.global_multiplier
		"flat_bonus_per_swing":
			return stats.flat_bonus_per_swing
		"crit_chance":
			return stats.crit_chance
		"crit_multiplier":
			return stats.crit_multiplier
		"passive_swings_per_second":
			return stats.passive_swings_per_second
		"passive_payout_multiplier":
			return stats.passive_payout_multiplier
		_:
			push_warning("UpgradeEffects: unknown stat '%s'" % stat_name)
			return 0.0


static func _write_stat(stats: PlayerStats, stat_name: String, value: float) -> void:
	match stat_name:
		"timing_window_perfect_ms":
			stats.timing_window_perfect_ms = value
		"timing_window_good_ms":
			stats.timing_window_good_ms = value
		"swing_cooldown_ms":
			stats.swing_cooldown_ms = value
		"perfect_payout_bonus":
			stats.perfect_payout_bonus = value
		"base_yards":
			stats.base_yards = value
		"yard_multiplier":
			stats.yard_multiplier = value
		"max_yards":
			stats.max_yards = value
		"yard_variance":
			stats.yard_variance = value
		"club_multiplier":
			stats.club_multiplier = value
		"ball_multiplier":
			stats.ball_multiplier = value
		"target_zone_multiplier":
			stats.target_zone_multiplier = value
		"outfit_multiplier":
			stats.outfit_multiplier = value
		"dollars_per_yard":
			stats.dollars_per_yard = value
		"global_multiplier":
			stats.global_multiplier = value
		"flat_bonus_per_swing":
			stats.flat_bonus_per_swing = value
		"crit_chance":
			stats.crit_chance = value
		"crit_multiplier":
			stats.crit_multiplier = value
		"passive_swings_per_second":
			stats.passive_swings_per_second = value
		"passive_payout_multiplier":
			stats.passive_payout_multiplier = value
		_:
			push_warning("UpgradeEffects: unknown stat '%s'" % stat_name)
