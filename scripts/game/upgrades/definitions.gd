class_name UpgradeDefinitions
extends RefCounted
## v4 deep upgrade tree — distance-pays fan-out from Base Pay.

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"base_pay", Balance.UpgradeBranch.BASE_PAY, "Base Pay",
			"Every ball you pick up is worth a little more.",
			25, 1.0, 1.39,
			[{"type": "multiply", "stat": "base_amount", "value_per_level": 1.06}],
			"", {}
		),
		_def(
			"distance_pay", Balance.UpgradeBranch.POWER, "Yardage Pay",
			"Longer shots pay more. Every yard a ball flies adds to what it's worth.",
			25, 2.0, 1.39,
			[
				{"type": "binary", "stat": "yardage_term_unlocked", "value": 1},
				## 0.1 → ~10.0 at max: 1.20^25 ≈ 95.4 → 0.1×95.4 ≈ 9.5
				{"type": "multiply", "stat": "pay_per_yard", "value_per_level": 1.06},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}
		),
		_def(
			"quality", Balance.UpgradeBranch.QUALITY, "Sweet Spot",
			"Good contact gets nudged toward great. Near-misses fly almost as far as Perfects.",
			20, 2.5, 1.44,
			[
				{"type": "binary", "stat": "sweet_spot_unlocked", "value": 1},
				{"type": "add", "stat": "sweet_spot_bonus", "value_per_level": 0.04},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}
		),
		_def(
			"pickup", Balance.UpgradeBranch.PICKUP, "Pickup",
			"Picking balls up by hand pays a bonus on each one.",
			20, 2.5, 1.42,
			[
				{"type": "binary", "stat": "pickup_bonus_unlocked", "value": 1},
				{"type": "multiply", "stat": "pickup_multiplier", "value_per_level": 1.03},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}
		),
		_def(
			"iron_set", Balance.UpgradeBranch.POWER, "Raw Power",
			"+3 yards baseline carry on every swing tier.",
			40, 7, 1.34,
			[{"type": "add", "stat": "base_yards", "value_per_level": 3.0}],
			"distance_pay", {"upgrade_id": "distance_pay", "level": 1}
		),
		_def(
			"metronome", Balance.UpgradeBranch.QUALITY, "Metronome",
			"A steadier tempo. The Perfect window gets wider.",
			15, 4.5, 1.4,
			[
				{"type": "add", "stat": "timing_window_perfect_ms", "value_per_level": 8.0},
				{"type": "add", "stat": "timing_window_great_ms", "value_per_level": 6.0},
			],
			"quality", {"upgrade_id": "quality", "level": 1}
		),
		_def(
			"perfect_pop", Balance.UpgradeBranch.QUALITY, "Perfect Pop",
			"Perfect strikes launch. Your best contact flies much farther.",
			15, 16, 1.54,
			[{"type": "multiply", "stat": "perfect_power_bonus", "value_per_level": 1.08}],
			"quality", {"upgrade_id": "quality", "level": 3}
		),
		_def(
			"range_picker", Balance.UpgradeBranch.PICKUP, "Range Picker",
			"A wider picker. Scoop up balls from farther away.",
			10, 4.5, 1.49,
			[{"type": "add", "stat": "range_picker_radius_bonus", "value_per_level": Balance.RANGE_PICKER_RADIUS_PER_LEVEL}],
			"pickup", {"upgrade_id": "pickup", "level": 1}
		),
		## Late OP nodes (formerly cheese / prestige).
		_def(
			"quick_reset", Balance.UpgradeBranch.QUALITY, "Quick Reset",
			"Reload faster between swings.",
			5, 200.0, 1.94,
			[{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.85}],
			"metronome", {"upgrade_id": "metronome", "level": 10}
		),
		_def(
			"combo_bonus", Balance.UpgradeBranch.PICKUP, "Combo Bonus",
			"Grab balls quickly one after another and each pays more.",
			5, 80.0, 1.74,
			[{"type": "add", "stat": "combo_mult_per_tier", "value_per_level": 0.08}],
			"pickup", {"upgrade_id": "pickup", "level": 8}
		),
		_def(
			"ball_count", Balance.UpgradeBranch.PICKUP, "More Balls",
			"+1 ball per bucket per level.",
			4, 300, 2.24,
			[{"type": "add", "stat": "bucket_capacity_bonus", "value_per_level": 1.0}],
			"combo_bonus", {"upgrade_id": "combo_bonus", "level": 1}
		),
		_def(
			"golden_ball", Balance.UpgradeBranch.QUALITY, "Golden Balls",
			"+2% chance teed balls are golden (double pay) per level.",
			10, 400, 1.64,
			[{"type": "add", "stat": "golden_ball_chance", "value_per_level": 0.02}],
			"perfect_pop", {"upgrade_id": "perfect_pop", "level": 5}
		),
		_def(
			"perfect_chain", Balance.UpgradeBranch.QUALITY, "Perfect Chain",
			"After 3 Perfects in a row, teed balls stay golden while the streak lasts.",
			1, 500.0, 1.04,
			[{"type": "binary", "stat": "perfect_chain_unlocked", "value": 1}],
			"golden_ball", {"upgrade_id": "golden_ball", "level": 3}
		),
		## v5: Barley's clubs — found in the mist, then levelled with cash.
		_def(
			"spoon_club", Balance.UpgradeBranch.POWER, "Barley's Spoon",
			"His old wooden spoon. +3% carry per level.",
			10, 1500.0, 1.54,
			[{"type": "multiply", "stat": "carry_multiplier", "value_per_level": 1.03}],
			"iron_set", {"upgrade_id": "iron_set", "level": 1}
		),
		_def(
			"driver_club", Balance.UpgradeBranch.POWER, "Persimmon Driver",
			"Barley's prized driver. +3% carry per level.",
			10, 20000.0, 1.54,
			[{"type": "multiply", "stat": "carry_multiplier", "value_per_level": 1.03}],
			"spoon_club", {"upgrade_id": "spoon_club", "level": 1}
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
	prerequisite: Dictionary
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
		var parent: String = def.get("parent_id", "")
		if parent.is_empty():
			continue
		links.append({"from": parent, "to": id})
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
