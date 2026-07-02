class_name ShopEffects
extends RefCounted
## Apply Pro Shop item effects to PlayerStats.


static func apply_all(stats: PlayerStats, levels: Dictionary) -> void:
	for def in ShopDefinitions.all():
		var id: String = def["id"]
		var level: int = int(levels.get(id, 0))
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
		"add":
			var stat_name := str(effect.get("stat", ""))
			var per_level := float(effect.get("value_per_level", 0.0))
			_write_stat(stats, stat_name, _read_stat(stats, stat_name) + per_level * level)
		"golden_chance":
			stats.golden_ball_chance = (
				Balance.GOLDEN_BALL_BASE_CHANCE
				+ float(level - 1) * Balance.GOLDEN_BALL_CHANCE_PER_LEVEL
			)


static func _read_stat(stats: PlayerStats, stat_name: String) -> float:
	match stat_name:
		"bucket_capacity_bonus":
			return stats.bucket_capacity_bonus
		"golden_ball_chance":
			return stats.golden_ball_chance
		_:
			push_warning("ShopEffects: unknown stat '%s'" % stat_name)
			return 0.0


static func _write_stat(stats: PlayerStats, stat_name: String, value: float) -> void:
	match stat_name:
		"bucket_capacity_bonus":
			stats.bucket_capacity_bonus = value
		"golden_ball_chance":
			stats.golden_ball_chance = value
		_:
			push_warning("ShopEffects: unknown stat '%s'" % stat_name)
