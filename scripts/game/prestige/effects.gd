class_name PrestigeEffects
extends RefCounted
## Apply cheese prestige effects to PlayerStats.

const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")


static func apply_all(stats: PlayerStats, levels: Dictionary) -> void:
	for def in PrestigeDefinitionsScript.all():
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
	_write_stat(stats, stat_name, current + per_level * float(level))


static func _apply_binary(stats: PlayerStats, stat_name: String, value: Variant) -> void:
	_write_stat(stats, stat_name, 1.0 if bool(value) else 0.0)


static func _read_stat(stats: PlayerStats, stat_name: String) -> float:
	match stat_name:
		"swing_cooldown_ms":
			return stats.swing_cooldown_ms
		"combo_mult_per_tier":
			return stats.combo_mult_per_tier
		"bucket_capacity_bonus":
			return stats.bucket_capacity_bonus
		"golden_ball_chance":
			return stats.golden_ball_chance
		"perfect_chain_unlocked":
			return stats.perfect_chain_unlocked
		_:
			push_warning("PrestigeEffects: unknown stat '%s'" % stat_name)
			return 0.0


static func _write_stat(stats: PlayerStats, stat_name: String, value: float) -> void:
	match stat_name:
		"swing_cooldown_ms":
			stats.swing_cooldown_ms = value
		"combo_mult_per_tier":
			stats.combo_mult_per_tier = value
		"bucket_capacity_bonus":
			stats.bucket_capacity_bonus = value
		"golden_ball_chance":
			stats.golden_ball_chance = value
		"perfect_chain_unlocked":
			stats.perfect_chain_unlocked = value
		_:
			push_warning("PrestigeEffects: unknown stat '%s'" % stat_name)
