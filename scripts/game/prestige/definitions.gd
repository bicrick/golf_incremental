class_name PrestigeDefinitions
extends RefCounted
## Cheese prestige upgrade definitions — persist across prestiges.

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	# Every purchase costs 1 cheese (base_cost 1, growth_rate 1.0).
	var defs: Array[Dictionary] = [
		_def(
			"cheese_press", Balance.UpgradeBranch.BASE_PAY, "Cheese Press",
			"+1 base cheese granted each prestige.",
			10, 1.0, 1.0,
			[],
			"", {}
		),
		_def(
			"ambition", Balance.UpgradeBranch.POWER, "Ambition",
			"Double the prestige cash threshold and double cheese payout per level.",
			5, 1.0, 1.0,
			[],
			"cheese_press", {"upgrade_id": "cheese_press", "level": 1}
		),
		_def(
			"prestige_quick_reset", Balance.UpgradeBranch.QUALITY, "Quick Reset",
			"Shorten swing cooldown (×0.85 per level).",
			5, 1.0, 1.0,
			[{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.85}],
			"cheese_press", {"upgrade_id": "cheese_press", "level": 1}
		),
		_def(
			"prestige_combo", Balance.UpgradeBranch.PICKUP, "Combo Hands",
			"Fast harvest clicks multiply pickup payout.",
			5, 1.0, 1.0,
			[{"type": "add", "stat": "combo_mult_per_tier", "value_per_level": 0.08}],
			"cheese_press", {"upgrade_id": "cheese_press", "level": 1}
		),
		_def(
			"prestige_deep_bucket", Balance.UpgradeBranch.PICKUP, "Deep Bucket",
			"+1 permanent bucket capacity per level.",
			4, 1.0, 1.0,
			[{"type": "add", "stat": "bucket_capacity_bonus", "value_per_level": 1.0}],
			"cheese_press", {"upgrade_id": "cheese_press", "level": 1}
		),
		_def(
			"prestige_golden_tee", Balance.UpgradeBranch.QUALITY, "Golden Tee",
			"+2% golden ball chance per level.",
			10, 1.0, 1.0,
			[{"type": "add", "stat": "golden_ball_chance", "value_per_level": 0.02}],
			"cheese_press", {"upgrade_id": "cheese_press", "level": 1}
		),
		_def(
			"prestige_perfect_chain", Balance.UpgradeBranch.QUALITY, "Perfect Chain",
			"After 3 Perfects in a row, teed balls stay golden while the streak lasts.",
			1, 1.0, 1.0,
			[{"type": "binary", "stat": "perfect_chain_unlocked", "value": 1}],
			"cheese_press", {"upgrade_id": "cheese_press", "level": 1}
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
	var parent_id: String = str(def.get("parent_id", ""))
	if not parent_id.is_empty() and int(levels.get(parent_id, 0)) < 1:
		return false
	var prereq: Dictionary = def.get("prerequisite", {})
	if prereq.is_empty():
		return true
	var req_id: String = prereq.get("upgrade_id", "")
	var req_level: int = prereq.get("level", 1)
	return int(levels.get(req_id, 0)) >= req_level


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
