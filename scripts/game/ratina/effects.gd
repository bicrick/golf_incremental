class_name RatinaUpgradeEffects
extends RefCounted
## Apply Ratina upgrade effects to PlayerStats.


static func apply_all(stats: PlayerStats, levels: Dictionary) -> void:
	for def in RatinaUpgradeDefinitions.all():
		var id: String = def["id"]
		var level: int = levels.get(id, 0)
		if level <= 0:
			continue
		for effect in def.get("effects", []):
			UpgradeEffects._apply_effect(stats, effect, level)


static func preview_stats(levels: Dictionary) -> PlayerStats:
	var stats := Balance.default_ratina_stats()
	apply_all(stats, levels)
	return stats
