class_name UpgradeEffects
extends RefCounted
## Apply upgrade effects to PlayerStats — stable definition order.


static func apply_all(stats: PlayerStats, levels: Dictionary) -> void:
	for def in UpgradeDefinitions.all():
		var id: String = def["id"]
		var level: int = levels.get(id, 0)
		if level <= 0:
			continue
		for effect in def.get("effects", []):
			_apply_effect(stats, effect, level)


static func preview_stats(levels: Dictionary) -> PlayerStats:
	var stats := Balance.default_stats()
	apply_all(stats, levels)
	return stats


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
		"timing_window_great_ms":
			return stats.timing_window_great_ms
		"timing_window_good_ms":
			return stats.timing_window_good_ms
		"timing_window_okay_ms":
			return stats.timing_window_okay_ms
		"timing_window_bad_ms":
			return stats.timing_window_bad_ms
		"swing_cooldown_ms":
			return stats.swing_cooldown_ms
		"yard_quality_floor":
			return stats.yard_quality_floor
		"yard_quality_late_peak":
			return stats.yard_quality_late_peak
		"base_amount":
			return stats.base_amount
		"pay_per_yard":
			return stats.pay_per_yard
		"quality_multiplier":
			return stats.quality_multiplier
		"yardage_term_unlocked":
			return stats.yardage_term_unlocked
		"quality_term_unlocked":
			return stats.quality_term_unlocked
		"pickup_bonus_unlocked":
			return stats.pickup_bonus_unlocked
		"pickup_multiplier":
			return stats.pickup_multiplier
		"pickup_flat_bonus":
			return stats.pickup_flat_bonus
		"combo_mult_per_tier":
			return stats.combo_mult_per_tier
		"combo_window_bonus_sec":
			return stats.combo_window_bonus_sec
		"range_picker_radius_bonus":
			return stats.range_picker_radius_bonus
		"base_yards":
			return stats.base_yards
		"carry_multiplier":
			return stats.carry_multiplier
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
		"global_multiplier":
			return stats.global_multiplier
		"flat_bonus_per_swing":
			return stats.flat_bonus_per_swing
		"bucket_capacity_bonus":
			return stats.bucket_capacity_bonus
		"passive_swings_per_second":
			return stats.passive_swings_per_second
		"passive_payout_multiplier":
			return stats.passive_payout_multiplier
		"consistency":
			return stats.consistency
		"rattling_count":
			return stats.rattling_count
		"rattling_walk_speed":
			return stats.rattling_walk_speed
		"rattling_pickup_speed_multiplier":
			return stats.rattling_pickup_speed_multiplier
		"rattling_golden_bonus_chance":
			return stats.rattling_golden_bonus_chance
		"rattling_payout_multiplier":
			return stats.rattling_payout_multiplier
		_:
			push_warning("UpgradeEffects: unknown stat '%s'" % stat_name)
			return 0.0


static func _write_stat(stats: PlayerStats, stat_name: String, value: float) -> void:
	match stat_name:
		"timing_window_perfect_ms":
			stats.timing_window_perfect_ms = value
		"timing_window_great_ms":
			stats.timing_window_great_ms = value
		"timing_window_good_ms":
			stats.timing_window_good_ms = value
		"timing_window_okay_ms":
			stats.timing_window_okay_ms = value
		"timing_window_bad_ms":
			stats.timing_window_bad_ms = value
		"swing_cooldown_ms":
			stats.swing_cooldown_ms = value
		"yard_quality_floor":
			stats.yard_quality_floor = value
		"yard_quality_late_peak":
			stats.yard_quality_late_peak = value
		"base_amount":
			stats.base_amount = value
		"pay_per_yard":
			stats.pay_per_yard = value
		"quality_multiplier":
			stats.quality_multiplier = value
		"yardage_term_unlocked":
			stats.yardage_term_unlocked = value
		"quality_term_unlocked":
			stats.quality_term_unlocked = value
		"pickup_bonus_unlocked":
			stats.pickup_bonus_unlocked = value
		"pickup_multiplier":
			stats.pickup_multiplier = value
		"pickup_flat_bonus":
			stats.pickup_flat_bonus = value
		"combo_mult_per_tier":
			stats.combo_mult_per_tier = value
		"combo_window_bonus_sec":
			stats.combo_window_bonus_sec = value
		"range_picker_radius_bonus":
			stats.range_picker_radius_bonus = value
		"base_yards":
			stats.base_yards = value
		"carry_multiplier":
			stats.carry_multiplier = value
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
		"global_multiplier":
			stats.global_multiplier = value
		"flat_bonus_per_swing":
			stats.flat_bonus_per_swing = value
		"bucket_capacity_bonus":
			stats.bucket_capacity_bonus = value
		"passive_swings_per_second":
			stats.passive_swings_per_second = value
		"passive_payout_multiplier":
			stats.passive_payout_multiplier = value
		"consistency":
			stats.consistency = value
		"rattling_count":
			stats.rattling_count = value
		"rattling_walk_speed":
			stats.rattling_walk_speed = value
		"rattling_pickup_speed_multiplier":
			stats.rattling_pickup_speed_multiplier = value
		"rattling_golden_bonus_chance":
			stats.rattling_golden_bonus_chance = value
		"rattling_payout_multiplier":
			stats.rattling_payout_multiplier = value
		_:
			push_warning("UpgradeEffects: unknown stat '%s'" % stat_name)
