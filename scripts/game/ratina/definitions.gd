class_name RatinaUpgradeDefinitions
extends RefCounted
## Ratina upgrade tree — separate id namespace from the player tree.

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"ratina_base_pay", Balance.UpgradeBranch.BASE_PAY, "Base Pay",
			"Flat cash per ball Ratina hits.",
			25, 1.20, 1.42,
			[{"type": "multiply", "stat": "base_amount", "value_per_level": 1.15}],
			"", {}
		),
		_def(
			"ratina_distance_pay", Balance.UpgradeBranch.POWER, "Yardage Pay",
			"Unlock pay per yard on Ratina's hits.",
			20, 10.0, 1.34,
			[
				{"type": "binary", "stat": "yardage_term_unlocked", "value": 1},
				{"type": "multiply", "stat": "pay_per_yard", "value_per_level": 1.06},
			],
			"ratina_base_pay", {"upgrade_id": "ratina_base_pay", "level": 1}
		),
		_def(
			"ratina_quality", Balance.UpgradeBranch.QUALITY, "Quality",
			"Higher contact tiers pay more on Ratina's hits.",
			20, 10.0, 1.32,
			[
				{"type": "binary", "stat": "quality_term_unlocked", "value": 1},
				{"type": "multiply", "stat": "quality_multiplier", "value_per_level": 1.06},
			],
			"ratina_base_pay", {"upgrade_id": "ratina_base_pay", "level": 1}
		),
		_def(
			"ratina_frequency", Balance.UpgradeBranch.PICKUP, "Frequency",
			"Ratina swings more often — shorter hit interval.",
			20, 12.0, 1.36,
			[{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.90}],
			"ratina_base_pay", {"upgrade_id": "ratina_base_pay", "level": 1}
		),
		_def(
			"ratina_raw_power", Balance.UpgradeBranch.POWER, "Raw Power",
			"+3 yards baseline carry on every Ratina hit.",
			20, 30.0, 1.22,
			[{"type": "add", "stat": "base_yards", "value_per_level": 3.0}],
			"ratina_distance_pay", {"upgrade_id": "ratina_distance_pay", "level": 1}
		),
		_def(
			"ratina_carry", Balance.UpgradeBranch.POWER, "Carry",
			"Multiply Ratina's carry distance.",
			30, 30.0, 1.24,
			[{"type": "multiply", "stat": "carry_multiplier", "value_per_level": 1.05}],
			"ratina_raw_power", {"upgrade_id": "ratina_raw_power", "level": 1}
		),
		_def(
			"ratina_consistency", Balance.UpgradeBranch.QUALITY, "Consistency",
			"Fewer bad swings — more Great and Perfect hits.",
			10, 15.0, 1.30,
			[{"type": "add", "stat": "consistency", "value_per_level": 0.08}],
			"ratina_quality", {"upgrade_id": "ratina_quality", "level": 1}
		),
		_def(
			"ratina_steady_hands", Balance.UpgradeBranch.QUALITY, "Steady Hands",
			"Even bad hits carry farther.",
			10, 30.0, 1.30,
			[{"type": "add", "stat": "yard_quality_floor", "value_per_level": 0.04}],
			"ratina_consistency", {"upgrade_id": "ratina_consistency", "level": 1}
		),
		_def(
			"ratina_rapid_fire", Balance.UpgradeBranch.PICKUP, "Rapid Fire",
			"Further shorten Ratina's swing interval.",
			10, 18.0, 1.34,
			[{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.88}],
			"ratina_frequency", {"upgrade_id": "ratina_frequency", "level": 1}
		),
		_def(
			"ratina_gatling_barrel", Balance.UpgradeBranch.PICKUP, "Gatling Barrel",
			"Maximum cadence — Ratina becomes a gatling gun.",
			5, 48.0, 1.40,
			[{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.82}],
			"ratina_rapid_fire", {"upgrade_id": "ratina_rapid_fire", "level": 1}
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
