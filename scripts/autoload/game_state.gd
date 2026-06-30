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
	# Effects.apply_all_upgrades(stats, upgrade_levels) — Workstream B


func purchase_upgrade(_id: String) -> bool:
	# Stub — Workstream B implements
	return false
