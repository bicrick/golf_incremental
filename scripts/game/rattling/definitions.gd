class_name RattlingUpgradeDefinitions
extends RefCounted
## Rattling upgrade tree — separate id namespace from the player and Ratina trees.

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"rattling_more", Balance.UpgradeBranch.BASE_PAY, "More Rattlings",
			"Hire another Rattling to work the forest edge.",
			24, 10.0, 1.45,
			[{"type": "add", "stat": "rattling_count", "value_per_level": Balance.RATTLING_COUNT_BONUS_PER_LEVEL}],
			"", {}
		),
		_def(
			"rattling_speed", Balance.UpgradeBranch.POWER, "Scurry Speed",
			"Rattlings walk faster to and from the fairway.",
			15, 8.0, 1.30,
			[{"type": "multiply", "stat": "rattling_walk_speed", "value_per_level": 1.08}],
			"rattling_more", {"upgrade_id": "rattling_more", "level": 1}
		),
		_def(
			"rattling_quick_paws", Balance.UpgradeBranch.PICKUP, "Quick Paws",
			"Faster pickup animation — less time fumbling the ball.",
			10, 9.0, 1.30,
			[{"type": "multiply", "stat": "rattling_pickup_speed_multiplier", "value_per_level": 1.10}],
			"rattling_more", {"upgrade_id": "rattling_more", "level": 1}
		),
		_def(
			"rattling_keen_nose", Balance.UpgradeBranch.QUALITY, "Keen Nose",
			"Rattlings sniff out extra golden balls.",
			10, 20.0, 1.36,
			[{"type": "add", "stat": "rattling_golden_bonus_chance", "value_per_level": 0.01}],
			"rattling_more", {"upgrade_id": "rattling_more", "level": 1}
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
