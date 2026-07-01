class_name UpgradeDefinitions
extends RefCounted
## v3 formula-unlock upgrade tree — barebones fan-out from Base Pay.

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"base_pay", Balance.UpgradeBranch.BASE_PAY, "Base Pay", "+$ per ball.",
			100, 5.0, 1.05,
			[{"type": "add", "stat": "base_amount", "value_per_level": 0.02}],
			"", {}, Vector2(213, 6)
		),
		_def(
			"yardage", Balance.UpgradeBranch.YARDAGE, "Yardage", "Unlock yardage payout + rate.",
			100, 10.0, 1.055,
			[
				{"type": "binary", "stat": "yardage_term_unlocked", "value": 1},
				{"type": "multiply", "stat": "yardage_multiplier", "value_per_level": 1.03},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}, Vector2(48, 62)
		),
		_def(
			"quality", Balance.UpgradeBranch.QUALITY, "Quality", "Unlock quality payout + bonus.",
			100, 15.0, 1.055,
			[
				{"type": "binary", "stat": "quality_term_unlocked", "value": 1},
				{"type": "multiply", "stat": "quality_multiplier", "value_per_level": 1.05},
			],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}, Vector2(213, 62)
		),
		_def(
			"power", Balance.UpgradeBranch.POWER, "Power", "+carry strength.",
			5, 15.0, 1.45,
			[{"type": "multiply", "stat": "yard_multiplier", "value_per_level": 1.13}],
			"base_pay", {"upgrade_id": "base_pay", "level": 1}, Vector2(378, 62)
		),
		_def(
			"leg_day", Balance.UpgradeBranch.POWER, "Leg Day", "+base yards.",
			10, 25.0, 1.5,
			[{"type": "multiply", "stat": "base_yards", "value_per_level": 1.112}],
			"power", {"upgrade_id": "power", "level": 1}, Vector2(378, 114)
		),
		_def(
			"core_strength", Balance.UpgradeBranch.POWER, "Core", "Raise max yards.",
			8, 75.0, 1.6,
			[{"type": "add", "stat": "max_yards", "value_per_level": 32.0}],
			"leg_day", {"upgrade_id": "leg_day", "level": 1}, Vector2(378, 166)
		),
		_def(
			"contact_training", Balance.UpgradeBranch.QUALITY, "Metronome", "Wider perfect window.",
			10, 25.0, 1.5,
			[{"type": "add", "stat": "timing_window_perfect_ms", "value_per_level": 4.0}],
			"quality", {"upgrade_id": "quality", "level": 1}, Vector2(213, 114)
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
