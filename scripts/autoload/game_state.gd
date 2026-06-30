extends Node
## Currency, upgrade levels, and computed stats.

var currency: float = 0.0
var upgrade_levels: Dictionary = {}
var stats: PlayerStats = Balance.default_stats()
var lifetime: Dictionary = {
	"total_swings": 0,
	"lifetime_yards": 0.0,
	"lifetime_earnings": 0.0,
	"best_combo": 0,
	"perfect_count": 0,
}


func _ready() -> void:
	SaveManager.load_game()
	_recompute_stats()
	EventBus.stats_changed.emit(stats, currency)


func add_currency(amount: float) -> void:
	currency += amount
	lifetime["lifetime_earnings"] = lifetime.get("lifetime_earnings", 0.0) + amount
	EventBus.stats_changed.emit(stats, currency)


func get_upgrade_level(id: String) -> int:
	return upgrade_levels.get(id, 0)


func _recompute_stats() -> void:
	stats = Balance.default_stats()
	UpgradeEffects.apply_all(stats, upgrade_levels)


func purchase_upgrade(id: String) -> bool:
	var def := UpgradeDefinitions.get_def(id)
	if def.is_empty():
		return false
	var level := get_upgrade_level(id)
	if level >= int(def["max_level"]):
		return false
	if not UpgradeDefinitions.is_unlocked(id, upgrade_levels, lifetime):
		return false
	var cost := Economy.upgrade_cost(float(def["base_cost"]), float(def["growth_rate"]), level)
	if currency < cost:
		return false
	currency -= cost
	upgrade_levels[id] = level + 1
	_recompute_stats()
	EventBus.upgrade_purchased.emit(id, level + 1, int(def["branch"]))
	EventBus.stats_changed.emit(stats, currency)
	return true


func get_upgrade_cost(id: String) -> float:
	var def := UpgradeDefinitions.get_def(id)
	if def.is_empty():
		return 0.0
	return Economy.upgrade_cost(float(def["base_cost"]), float(def["growth_rate"]), get_upgrade_level(id))
