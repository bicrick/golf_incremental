class_name UpgradeDefinitions
extends RefCounted
## v4 deep upgrade tree — fan-out from Base Pay.

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"base_pay", Balance.UpgradeBranch.BASE_PAY, "Base Pay",
			"Flat cash per ball picked up. Does not change how far you hit.",
			25, 1.50, 1.48,
			[{"type": "multiply", "stat": "base_amount", "value_per_level": 1.15}],
			"", {}, Vector2(213, 6)
		),
		_def(
			"distance_pay", Balance.UpgradeBranch.POWER, "Yardage Pay",
			"Unlock pay per yard. Keep base $; each yard flown adds bonus cash at pickup.",
			20, 12.0, 1.36,
			[
				{"type": "binary", "stat": "yardage_term_unlocked", "value": 1},
				{"type": "multiply", "stat": "pay_per_yard", "value_per_level": 1.06},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}, Vector2(120, 62)
		),
		_def(
			"quality", Balance.UpgradeBranch.QUALITY, "Quality",
			"Unlock payout bonus from contact tier (Perfect pays more than Miss).",
			20, 12.0, 1.34,
			[
				{"type": "binary", "stat": "quality_term_unlocked", "value": 1},
				{"type": "multiply", "stat": "quality_multiplier", "value_per_level": 1.06},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}, Vector2(213, 62)
		),
		_def(
			"pickup", Balance.UpgradeBranch.PICKUP, "Pickup",
			"Unlock pickup bonuses on collected balls.",
			20, 12.0, 1.38,
			[
				{"type": "binary", "stat": "pickup_bonus_unlocked", "value": 1},
				{"type": "multiply", "stat": "pickup_multiplier", "value_per_level": 1.06},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}, Vector2(306, 62)
		),
		_def(
			"iron_set", Balance.UpgradeBranch.POWER, "Raw Power",
			"+3 yards baseline carry on every swing tier.",
			20, 36.0, 1.24,
			[{"type": "add", "stat": "base_yards", "value_per_level": 3.0}],
			"distance_pay", {"upgrade_id": "distance_pay", "level": 1}, Vector2(120, 114)
		),
		_def(
			"power", Balance.UpgradeBranch.POWER, "Carry",
			"Multiply carry distance — extra pop on top of raw power.",
			30, 36.0, 1.26,
			[{"type": "multiply", "stat": "carry_multiplier", "value_per_level": 1.05}],
			"iron_set", {"upgrade_id": "iron_set", "level": 1}, Vector2(120, 166)
		),
		_def(
			"metronome", Balance.UpgradeBranch.QUALITY, "Metronome",
			"Widen the Perfect timing window — easier clean strikes.",
			10, 18.0, 1.32,
			[{"type": "add", "stat": "timing_window_perfect_ms", "value_per_level": 8.0}],
			"quality", {"upgrade_id": "quality", "level": 1}, Vector2(213, 114)
		),
		_def(
			"great_eye", Balance.UpgradeBranch.QUALITY, "Great Eye",
			"Widen the Great timing band — more high-tier hits.",
			10, 36.0, 1.32,
			[{"type": "add", "stat": "timing_window_great_ms", "value_per_level": 10.0}],
			"metronome", {"upgrade_id": "metronome", "level": 1}, Vector2(165, 166)
		),
		_def(
			"quick_reset", Balance.UpgradeBranch.QUALITY, "Quick Reset",
			"Shorten swing cooldown — more strikes per bucket.",
			10, 36.0, 1.40,
			[{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.5}],
			"metronome", {"upgrade_id": "metronome", "level": 1}, Vector2(261, 166)
		),
		_def(
			"tip_jar", Balance.UpgradeBranch.PICKUP, "Tip Jar",
			"Flat extra cash added every time you pick up a ball.",
			15, 18.0, 1.32,
			[{"type": "add", "stat": "pickup_flat_bonus", "value_per_level": 0.25}],
			"pickup", {"upgrade_id": "pickup", "level": 1}, Vector2(270, 114)
		),
		_def(
			"combo_bonus", Balance.UpgradeBranch.PICKUP, "Combo Bonus",
			"Fast harvest clicks multiply pickup payout.",
			10, 18.0, 1.32,
			[{"type": "add", "stat": "combo_mult_per_tier", "value_per_level": 0.10}],
			"pickup", {"upgrade_id": "pickup", "level": 1}, Vector2(306, 114)
		),
		_def(
			"quick_hands", Balance.UpgradeBranch.PICKUP, "Quick Hands",
			"Longer combo window between harvest clicks.",
			10, 18.0, 1.32,
			[{"type": "add", "stat": "combo_window_bonus_sec", "value_per_level": 0.15}],
			"pickup", {"upgrade_id": "pickup", "level": 1}, Vector2(342, 114)
		),
		_def(
			"magnetic_glove", Balance.UpgradeBranch.PICKUP, "Magnetic Glove",
			"Future — balls pull toward cursor. (Stub)",
			1, 48.0, 2.0,
			[{"type": "binary", "stat": "magnetic_glove", "value": 1}],
			"quick_hands", {"upgrade_id": "quick_hands", "level": 1}, Vector2(342, 166)
		),
	]
	for d in defs:
		_by_id[d["id"]] = d
		_tree_order.append(d["id"])


static func _def(
	id: String,
	branch: int,
	display_name: String,
	description: String,
	max_level: int,
	base_cost: float,
	growth_rate: float,
	effects: Array,
	parent_id: String,
	prerequisite: Dictionary,
	tree_pos: Vector2
) -> Dictionary:
	return {
		"id": id,
		"branch": branch,
		"display_name": display_name,
		"description": description,
		"max_level": max_level,
		"base_cost": base_cost,
		"growth_rate": growth_rate,
		"effects": effects,
		"parent_id": parent_id,
		"prerequisite": prerequisite,
		"tree_pos": tree_pos,
	}


static func all() -> Array:
	_init_defs()
	var result: Array = []
	for id in _tree_order:
		result.append(_by_id[id])
	return result


static func get_def(id: String) -> Dictionary:
	_init_defs()
	return _by_id.get(id, {})


static func tree_order() -> Array[String]:
	_init_defs()
	return _tree_order


static func connections() -> Array:
	_init_defs()
	var links: Array = []
	for id in _tree_order:
		var def: Dictionary = _by_id[id]
		var parent_id: String = def.get("parent_id", "")
		if parent_id.is_empty():
			continue
		links.append({"from": parent_id, "to": id})
	return links


static func is_unlocked(id: String, levels: Dictionary, _lifetime: Dictionary = {}) -> bool:
	var def := get_def(id)
	if def.is_empty():
		return false
	var prereq: Dictionary = def.get("prerequisite", {})
	if prereq.is_empty():
		return true
	var req_id: String = prereq.get("upgrade_id", "")
	var req_level: int = prereq.get("level", 1)
	return levels.get(req_id, 0) >= req_level


static func has_affordable_upgrade(
	levels: Dictionary, currency: float, lifetime: Dictionary = {}
) -> bool:
	_init_defs()
	for id in _tree_order:
		var def: Dictionary = _by_id[id]
		var level: int = int(levels.get(id, 0))
		if level >= int(def["max_level"]):
			continue
		if not is_unlocked(id, levels, lifetime):
			continue
		var cost := Economy.upgrade_cost(
			float(def["base_cost"]), float(def["growth_rate"]), level
		)
		if currency >= cost:
			return true
	return false


static func lock_hint(id: String, levels: Dictionary) -> String:
	var def := get_def(id)
	if def.is_empty() or is_unlocked(id, levels):
		return ""
	var prereq: Dictionary = def.get("prerequisite", {})
	var req_id: String = prereq.get("upgrade_id", "")
	var req_level: int = prereq.get("level", 1)
	var req_def := get_def(req_id)
	var req_name: String = req_def.get("display_name", req_id)
	return "Need %s Lv.%d" % [req_name, req_level]
