class_name RatinaUpgradeDefinitions
extends RefCounted
## Ratina upgrade tree — v5 coach: her mark (bonus, size, luck).

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	## v5 crew refactor: Ratina coaches instead of swinging. Each bucket she
	## plants a mark in your range; balls that rest on it pay extra.
	var defs: Array[Dictionary] = [
		_def(
			"ratina_coaching", Balance.UpgradeBranch.BASE_PAY, "Coaching",
			"Balls that land on Ratina's mark pay more.",
			20, 6.0, 1.42,
			[{"type": "add", "stat": "ratina_mark_bonus", "value_per_level": 0.25}],
			"", {}
		),
		_def(
			"ratina_big_flag", Balance.UpgradeBranch.QUALITY, "Bigger Flag",
			"Ratina's mark gets wider — easier to land on.",
			12, 14.0, 1.45,
			[{"type": "add", "stat": "ratina_mark_radius", "value_per_level": 0.5}],
			"ratina_coaching", {"upgrade_id": "ratina_coaching", "level": 1}
		),
		_def(
			"ratina_lucky_flag", Balance.UpgradeBranch.PICKUP, "Lucky Flag",
			"Balls on the mark have a chance to turn golden.",
			10, 40.0, 1.5,
			[{"type": "add", "stat": "ratina_mark_golden_chance", "value_per_level": 0.05}],
			"ratina_coaching", {"upgrade_id": "ratina_coaching", "level": 3}
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


static func is_unlocked(id: String, levels: Dictionary) -> bool:
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
