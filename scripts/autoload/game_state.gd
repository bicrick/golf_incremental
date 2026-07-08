extends Node
## Currency, upgrade levels, and computed stats.

var currency: float = 0.0
var upgrade_levels: Dictionary = {}
var upgrades_unlocked: bool = false
var shop_unlocked: bool = false
var ratina_unlocked: bool = false
var rattlings_unlocked: bool = false
## Non-destructive on/off switches — toggled from the HUD chips once hired.
## Unlike the *_unlocked flags, these can be flipped freely at any time.
var ratina_active: bool = true
var rattlings_active: bool = true
var shop_levels: Dictionary = {}
var ratina_upgrade_levels: Dictionary = {}
var rattling_upgrade_levels: Dictionary = {}
var stats: PlayerStats = Balance.default_stats()
var ratina_stats: PlayerStats = Balance.default_ratina_stats()
var rattling_stats: PlayerStats = Balance.default_rattling_stats()
var bucket_remaining: int = -1
var bucket_capacity: int = 0
var current_phase: String = "strike"
var harvest_collected: int = 0
var harvest_stash: int = 0
var pending_vanish_collects: int = 0

var lifetime: Dictionary = {
	"total_swings": 0,
	"lifetime_yards": 0.0,
	"lifetime_earnings": 0.0,
	"ratina_lifetime_earnings": 0.0,
	"rattling_lifetime_earnings": 0.0,
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
	ShopEffects.apply_all(stats, shop_levels)
	ratina_stats = Balance.default_ratina_stats()
	RatinaUpgradeEffects.apply_all(ratina_stats, ratina_upgrade_levels)
	rattling_stats = Balance.default_rattling_stats()
	RattlingUpgradeEffects.apply_all(rattling_stats, rattling_upgrade_levels)
	bucket_capacity = get_bucket_capacity()


func is_shop_visible() -> bool:
	return get_upgrade_level("base_pay") >= 1


func try_unlock_shop() -> bool:
	if shop_unlocked:
		return true
	if currency < Balance.SHOP_UNLOCK_COST:
		return false
	currency -= Balance.SHOP_UNLOCK_COST
	shop_unlocked = true
	EventBus.stats_changed.emit(stats, currency)
	return true


func try_unlock_ratina() -> bool:
	if ratina_unlocked:
		return true
	if not shop_unlocked:
		return false
	if currency < Balance.RATINA_UNLOCK_COST:
		return false
	currency -= Balance.RATINA_UNLOCK_COST
	ratina_unlocked = true
	EventBus.stats_changed.emit(stats, currency)
	return true


func try_unlock_rattlings() -> bool:
	if rattlings_unlocked:
		return true
	if not shop_unlocked:
		return false
	if currency < Balance.RATTLING_UNLOCK_COST:
		return false
	currency -= Balance.RATTLING_UNLOCK_COST
	rattlings_unlocked = true
	EventBus.stats_changed.emit(stats, currency)
	return true


func set_ratina_active(active: bool) -> void:
	if ratina_active == active:
		return
	ratina_active = active
	EventBus.helper_toggled.emit("ratina", active)


func set_rattlings_active(active: bool) -> void:
	if rattlings_active == active:
		return
	rattlings_active = active
	EventBus.helper_toggled.emit("rattlings", active)


func get_shop_item_level(id: String) -> int:
	return shop_levels.get(id, 0)


func purchase_shop_item(id: String) -> bool:
	if not shop_unlocked:
		return false
	var def: Dictionary = ShopDefinitions.get_def(id)
	if def.is_empty():
		return false
	var level := get_shop_item_level(id)
	if level >= int(def["max_level"]):
		return false
	var cost := get_shop_item_cost(id)
	if currency < cost:
		return false
	currency -= cost
	shop_levels[id] = level + 1
	var old_capacity := bucket_capacity
	_recompute_stats()
	if bucket_capacity > old_capacity:
		bucket_remaining = bucket_capacity
		if current_phase == "harvest":
			harvest_collected = 0
			harvest_stash = 0
			current_phase = "strike"
			EventBus.phase_changed.emit("strike")
	EventBus.shop_item_purchased.emit(id, level + 1)
	EventBus.stats_changed.emit(stats, currency)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	return true


func get_shop_item_cost(id: String) -> float:
	var def: Dictionary = ShopDefinitions.get_def(id)
	if def.is_empty():
		return 0.0
	return Economy.upgrade_cost(
		float(def["base_cost"]), float(def["growth_rate"]), get_shop_item_level(id)
	)


func get_ratina_upgrade_level(id: String) -> int:
	return ratina_upgrade_levels.get(id, 0)


func purchase_ratina_upgrade(id: String) -> bool:
	if not ratina_unlocked:
		return false
	var def: Dictionary = RatinaUpgradeDefinitions.get_def(id)
	if def.is_empty():
		return false
	var level := get_ratina_upgrade_level(id)
	if level >= int(def["max_level"]):
		return false
	if not RatinaUpgradeDefinitions.is_unlocked(id, ratina_upgrade_levels):
		return false
	var cost := get_ratina_upgrade_cost(id)
	if currency < cost:
		return false
	currency -= cost
	ratina_upgrade_levels[id] = level + 1
	_recompute_stats()
	EventBus.ratina_upgrade_purchased.emit(id, level + 1)
	EventBus.stats_changed.emit(stats, currency)
	return true


func get_ratina_upgrade_cost(id: String) -> float:
	var def: Dictionary = RatinaUpgradeDefinitions.get_def(id)
	if def.is_empty():
		return 0.0
	return Economy.upgrade_cost(
		float(def["base_cost"]), float(def["growth_rate"]), get_ratina_upgrade_level(id)
	)


func credit_ratina_ball(yardage: float, quality: int, combo_tier: int = 1) -> float:
	var payout := Economy.resolve_pickup_ball_payout(quality, yardage, combo_tier, ratina_stats)
	add_currency(payout)
	lifetime["ratina_lifetime_earnings"] = lifetime.get("ratina_lifetime_earnings", 0.0) + payout
	EventBus.ratina_ball_collected.emit(payout)
	return payout


## Rattlings just deliver the ball — the payout is whatever the ball's
## original owner (player or Ratina) would have earned for it themselves,
## using that owner's own stats/upgrades. rattling_stats holds no payout
## formula of its own; only the Rattling tree's own bonus knobs.
func _stats_for_rattling_collect(source: String) -> PlayerStats:
	return ratina_stats if source == "ratina" else stats


func _stats_for_harvest_collect(source: String) -> PlayerStats:
	return ratina_stats if source == "ratina" else stats


func get_rattling_upgrade_level(id: String) -> int:
	return rattling_upgrade_levels.get(id, 0)


func purchase_rattling_upgrade(id: String) -> bool:
	if not rattlings_unlocked:
		return false
	var def: Dictionary = RattlingUpgradeDefinitions.get_def(id)
	if def.is_empty():
		return false
	var level := get_rattling_upgrade_level(id)
	if level >= int(def["max_level"]):
		return false
	if not RattlingUpgradeDefinitions.is_unlocked(id, rattling_upgrade_levels):
		return false
	var cost := get_rattling_upgrade_cost(id)
	if currency < cost:
		return false
	currency -= cost
	rattling_upgrade_levels[id] = level + 1
	_recompute_stats()
	EventBus.rattling_upgrade_purchased.emit(id, level + 1)
	EventBus.stats_changed.emit(stats, currency)
	return true


func get_rattling_upgrade_cost(id: String) -> float:
	var def: Dictionary = RattlingUpgradeDefinitions.get_def(id)
	if def.is_empty():
		return 0.0
	return Economy.upgrade_cost(
		float(def["base_cost"]), float(def["growth_rate"]), get_rattling_upgrade_level(id)
	)


## Awards cash for a ball a Rattling carried back to the forest, and credits
## the ball toward the bucket refill (same accounting as vanished balls).
func credit_rattling_ball(
	quality: int,
	yardage: float,
	is_golden: bool = false,
	source: String = "player"
) -> float:
	var golden := is_golden
	var collect_stats := _stats_for_rattling_collect(source)
	if source == "player" and not golden and rattling_stats.rattling_golden_bonus_chance > 0.0:
		golden = randf() < rattling_stats.rattling_golden_bonus_chance
	var payout := Economy.resolve_pickup_ball_payout(quality, yardage, 1, collect_stats)
	if golden:
		payout *= collect_stats.golden_ball_payout_multiplier
	add_currency(payout)
	if source == "ratina":
		lifetime["ratina_lifetime_earnings"] = lifetime.get("ratina_lifetime_earnings", 0.0) + payout
		EventBus.ratina_ball_collected.emit(payout)
	else:
		lifetime["rattling_lifetime_earnings"] = lifetime.get("rattling_lifetime_earnings", 0.0) + payout
		EventBus.rattling_ball_collected.emit(payout)
	if current_phase == "harvest":
		harvest_collected += 1
	else:
		bucket_remaining = mini(bucket_remaining + 1, bucket_capacity)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	return payout


func try_unlock_upgrades() -> bool:
	if upgrades_unlocked:
		return true
	if currency < Balance.UPGRADES_UNLOCK_COST:
		return false
	currency -= Balance.UPGRADES_UNLOCK_COST
	upgrades_unlocked = true
	EventBus.stats_changed.emit(stats, currency)
	return true


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
			harvest_stash = 0
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
	upgrades_unlocked = false
	shop_unlocked = false
	ratina_unlocked = false
	rattlings_unlocked = false
	ratina_active = true
	rattlings_active = true
	shop_levels.clear()
	ratina_upgrade_levels.clear()
	rattling_upgrade_levels.clear()
	stats = Balance.default_stats()
	ratina_stats = Balance.default_ratina_stats()
	rattling_stats = Balance.default_rattling_stats()
	bucket_capacity = get_bucket_capacity()
	bucket_remaining = bucket_capacity
	current_phase = "strike"
	harvest_collected = 0
	harvest_stash = 0
	pending_vanish_collects = 0
	lifetime = {
		"total_swings": 0,
		"lifetime_yards": 0.0,
		"lifetime_earnings": 0.0,
		"ratina_lifetime_earnings": 0.0,
		"rattling_lifetime_earnings": 0.0,
		"perfect_count": 0,
	}
	_recompute_stats()
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	EventBus.phase_changed.emit("strike")
	EventBus.stats_changed.emit(stats, currency)


func get_bucket_capacity() -> int:
	return mini(
		Balance.BUCKET_CAPACITY_DEFAULT + int(stats.bucket_capacity_bonus),
		Balance.BUCKET_CAPACITY_MAX
	)


func has_bucket_balls() -> bool:
	if current_phase == "strike":
		return bucket_remaining > 0
	if current_phase == "harvest":
		return harvest_collected > 0
	return false


func is_harvest_phase() -> bool:
	return current_phase == "harvest"


## Collect target for the current harvest — capacity minus balls already
## stashed (unhit) when the player voluntarily entered collect mode.
func _harvest_target() -> int:
	return maxi(bucket_capacity - harvest_stash, 0)


func is_collect_mode() -> bool:
	return is_harvest_phase() and harvest_collected < _harvest_target()


func is_harvest_complete() -> bool:
	return current_phase == "harvest" and harvest_collected >= _harvest_target()


func consume_bucket_ball() -> bool:
	if current_phase == "harvest":
		return false
	if bucket_remaining <= 0:
		return false
	bucket_remaining -= 1
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	return true


## Unlike the player, Ratina keeps swinging while the player is in collect
## mode — she draws from the stashed (unhit) balls set aside on harvest entry
## instead of being gated by the phase.
func ratina_has_ball_to_hit() -> bool:
	if current_phase == "harvest":
		return harvest_stash > 0
	return bucket_remaining > 0


func consume_ratina_bucket_ball() -> bool:
	if current_phase == "harvest":
		if harvest_stash <= 0:
			return false
		harvest_stash -= 1
		return true
	if bucket_remaining <= 0:
		return false
	bucket_remaining -= 1
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	return true


## Voluntarily enters collect mode from strike (any time, any ball count).
## Balls still unhit in the bucket are stashed and merged back in on exit.
func try_enter_harvest() -> bool:
	if current_phase == "harvest":
		return false
	harvest_stash = bucket_remaining
	bucket_remaining = 0
	harvest_collected = pending_vanish_collects
	pending_vanish_collects = 0
	current_phase = "harvest"
	EventBus.phase_changed.emit("harvest")
	EventBus.bucket_changed.emit(harvest_collected, bucket_capacity)
	return true


func collect_harvest_ball(
	world_pos: Vector3,
	combo_tier: int,
	quality: int = 1,
	yardage: float = 0.0,
	is_golden: bool = false,
	source: String = "player"
) -> float:
	if current_phase != "harvest":
		return 0.0
	if harvest_collected >= _harvest_target():
		return 0.0
	var collect_stats := _stats_for_harvest_collect(source)
	var effective_yardage := yardage if yardage > 0.0 else collect_stats.base_yards
	var payout := Economy.resolve_pickup_ball_payout(
		quality, effective_yardage, combo_tier, collect_stats
	)
	if is_golden:
		payout *= collect_stats.golden_ball_payout_multiplier
	add_currency(payout)
	if source == "ratina":
		lifetime["ratina_lifetime_earnings"] = lifetime.get("ratina_lifetime_earnings", 0.0) + payout
		EventBus.ratina_ball_collected.emit(payout)
	harvest_collected += 1
	EventBus.ball_collected.emit(world_pos, combo_tier)
	EventBus.bucket_changed.emit(harvest_collected, bucket_capacity)
	return payout


func credit_vanished_ball(
	world_pos: Vector3,
	quality: int,
	yardage: float,
	combo_tier: int = 1,
	is_golden: bool = false
) -> float:
	var effective_yardage := yardage if yardage > 0.0 else stats.base_yards
	var payout := Economy.resolve_pickup_ball_payout(
		quality, effective_yardage, combo_tier, stats
	)
	if is_golden:
		payout *= stats.golden_ball_payout_multiplier
	add_currency(payout)
	if current_phase == "harvest":
		harvest_collected += 1
	else:
		pending_vanish_collects += 1
	EventBus.ball_collected.emit(world_pos, combo_tier)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	return payout


func credit_ratina_vanished_ball(
	world_pos: Vector3,
	quality: int,
	yardage: float,
	combo_tier: int = 1,
	is_golden: bool = false
) -> float:
	var effective_yardage := yardage if yardage > 0.0 else ratina_stats.base_yards
	var payout := Economy.resolve_pickup_ball_payout(
		quality, effective_yardage, combo_tier, ratina_stats
	)
	if is_golden:
		payout *= ratina_stats.golden_ball_payout_multiplier
	add_currency(payout)
	lifetime["ratina_lifetime_earnings"] = lifetime.get("ratina_lifetime_earnings", 0.0) + payout
	if current_phase == "harvest":
		harvest_collected += 1
	else:
		pending_vanish_collects += 1
	EventBus.ratina_ball_collected.emit(payout)
	EventBus.ball_collected.emit(world_pos, combo_tier)
	EventBus.bucket_changed.emit(_bucket_display_count(), bucket_capacity)
	return payout


## Bucket has reached its collect target — full refill, litter cleared by caller.
func complete_harvest(_best_combo: int) -> float:
	if current_phase != "harvest":
		return 0.0
	harvest_collected = 0
	harvest_stash = 0
	pending_vanish_collects = 0
	bucket_remaining = bucket_capacity
	current_phase = "strike"
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	EventBus.phase_changed.emit("strike")
	return 0.0


## Voluntary early return to hitting mode — stashed + collected balls merge
## back into the bucket; litter is left behind on the fairway.
func exit_harvest_early() -> void:
	if current_phase != "harvest":
		return
	bucket_remaining = mini(harvest_stash + harvest_collected, bucket_capacity)
	harvest_stash = 0
	harvest_collected = 0
	pending_vanish_collects = 0
	current_phase = "strike"
	EventBus.bucket_changed.emit(bucket_remaining, bucket_capacity)
	EventBus.phase_changed.emit("strike")


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
