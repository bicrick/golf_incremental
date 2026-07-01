extends Node
## Currency, upgrade levels, and computed stats.

var currency: float = 0.0
var upgrade_levels: Dictionary = {}
var stats: PlayerStats = Balance.default_stats()
var bucket_remaining: int = -1
var bucket_capacity: int = 0
var current_phase: String = "strike"
var harvest_collected: int = 0

var lifetime: Dictionary = {
	"total_swings": 0,
	"lifetime_yards": 0.0,
	"lifetime_earnings": 0.0,
	"perfect_count": 0,
}


func _ready() -> void:
	SaveManager.load_game()
	_ensure_bucket_initialized()
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
	bucket_capacity = get_bucket_capacity()


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
	var old_capacity := bucket_capacity
	_recompute_stats()
	if bucket_capacity > old_capacity:
		bucket_remaining = bucket_capacity
		if current_phase == "harvest":
			harvest_collected = 0
			current_phase = "strike"
			EventBus.phase_changed.emit("strike")
	EventBus.upgrade_purchased.emit(id, level + 1, int(def["branch"]))
	EventBus.stats_changed.emit(stats, currency)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	return true


func get_upgrade_cost(id: String) -> float:
	var def := UpgradeDefinitions.get_def(id)
	if def.is_empty():
		return 0.0
	return Economy.upgrade_cost(float(def["base_cost"]), float(def["growth_rate"]), get_upgrade_level(id))


func reset_to_fresh() -> void:
	currency = 0.0
	upgrade_levels.clear()
	stats = Balance.default_stats()
	bucket_capacity = get_bucket_capacity()
	bucket_remaining = bucket_capacity
	current_phase = "strike"
	harvest_collected = 0
	lifetime = {
		"total_swings": 0,
		"lifetime_yards": 0.0,
		"lifetime_earnings": 0.0,
		"perfect_count": 0,
	}
	_recompute_stats()
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	EventBus.phase_changed.emit("strike")
	EventBus.stats_changed.emit(stats, currency)


func get_bucket_capacity() -> int:
	return Balance.BUCKET_CAPACITY_DEFAULT + int(stats.bucket_capacity_bonus)


func has_bucket_balls() -> bool:
	if current_phase == "strike":
		return bucket_remaining > 0
	if current_phase == "harvest":
		return harvest_collected > 0
	return false


func is_harvest_phase() -> bool:
	return current_phase == "harvest"


func is_collect_mode() -> bool:
	return is_harvest_phase() and harvest_collected < bucket_capacity


func is_harvest_complete() -> bool:
	return current_phase == "harvest" and harvest_collected >= bucket_capacity


func consume_bucket_ball() -> bool:
	if current_phase == "harvest":
		if harvest_collected <= 0:
			return false
		harvest_collected -= 1
		EventBus.bucket_changed.emit(harvest_collected, bucket_capacity)
		return true
	if bucket_remaining <= 0:
		return false
	bucket_remaining -= 1
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	if bucket_remaining <= 0:
		_enter_harvest_phase()
	return true


func collect_harvest_ball(
	world_pos: Vector3,
	combo_tier: int,
	quality: int = 1,
	yardage: float = 0.0
) -> float:
	if current_phase != "harvest":
		return 0.0
	if harvest_collected >= bucket_capacity:
		return 0.0
	var effective_yardage := yardage if yardage > 0.0 else stats.base_yards
	var payout := Economy.resolve_pickup_ball_payout(
		quality, effective_yardage, combo_tier, stats
	)
	add_currency(payout)
	harvest_collected += 1
	EventBus.ball_collected.emit(world_pos, combo_tier)
	EventBus.bucket_changed.emit(harvest_collected, bucket_capacity)
	return payout


func complete_harvest(best_combo: int) -> float:
	if current_phase != "harvest":
		return 0.0
	var bonus := Economy.bucket_complete_bonus_value(stats)
	if best_combo >= 4:
		bonus *= 1.0 + Balance.COMBO_MULT_PER_TIER * float(best_combo - 1)
	add_currency(bonus)
	_exit_harvest_to_strike(bonus)
	return bonus


func skip_harvest() -> void:
	if current_phase != "harvest":
		return
	_exit_harvest_to_strike(0.0)


func _exit_harvest_to_strike(bonus: float) -> void:
	harvest_collected = 0
	bucket_remaining = bucket_capacity
	current_phase = "strike"
	if bonus > 0.0:
		EventBus.bucket_completed.emit(bonus)
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	EventBus.phase_changed.emit("strike")


func _enter_harvest_phase() -> void:
	current_phase = "harvest"
	harvest_collected = 0
	EventBus.phase_changed.emit("harvest")
	EventBus.bucket_changed.emit(harvest_collected, bucket_capacity)


func _bucket_display_count() -> int:
	if current_phase == "harvest":
		return harvest_collected
	return bucket_remaining


func _ensure_bucket_initialized() -> void:
	_recompute_stats()
	# Litter is not persisted; refill empty bucket on load (in-session harvest handles the real loop).
	if bucket_remaining <= 0 and current_phase != "harvest":
		bucket_remaining = bucket_capacity
		current_phase = "strike"
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
