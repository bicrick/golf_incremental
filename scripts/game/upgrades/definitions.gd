class_name UpgradeDefinitions
extends RefCounted
## v1 upgrade content — Power root branching to Distance, Rhythm, Economy.

const DINKY_BASE := "res://assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/Singles"

static var _by_id: Dictionary = {}
static var _tree_order: Array[String] = []


static func _init_defs() -> void:
	if not _tree_order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"power", Balance.UpgradeBranch.DISTANCE, "Power", "Base swing strength.",
			5, 15.0, 1.45,
			{"type": "multiply", "stat": "yard_multiplier", "value_per_level": 1.13},
			"", {}, Vector2(213, 6),
			DINKY_BASE + "/HUD/PowerBar.png"
		),
		# Distance branch
		_def(
			"leg_day", Balance.UpgradeBranch.DISTANCE, "Leg Day", "+base yards.",
			10, 25.0, 1.5,
			{"type": "multiply", "stat": "base_yards", "value_per_level": 1.112},
			"power", {"upgrade_id": "power", "level": 1}, Vector2(48, 62),
			DINKY_BASE + "/Player/Swing03.png"
		),
		_def(
			"followthrough_form", Balance.UpgradeBranch.DISTANCE, "Form", "+distance %.",
			10, 40.0, 1.55,
			{"type": "multiply", "stat": "yard_multiplier", "value_per_level": 1.065},
			"leg_day", {"upgrade_id": "leg_day", "level": 1}, Vector2(16, 114),
			DINKY_BASE + "/Ball/Ball-Sprites_0005.png"
		),
		_def(
			"core_strength", Balance.UpgradeBranch.DISTANCE, "Core", "Raise max yards.",
			8, 75.0, 1.6,
			{"type": "add", "stat": "max_yards", "value_per_level": 32.0},
			"followthrough_form", {"upgrade_id": "followthrough_form", "level": 1}, Vector2(48, 166),
			DINKY_BASE + "/Player/Swing05.png"
		),
		# Rhythm branch
		_def(
			"metronome", Balance.UpgradeBranch.RHYTHM, "Metronome", "Wider perfect window.",
			10, 25.0, 1.5,
			{"type": "add", "stat": "timing_window_perfect_ms", "value_per_level": 4.0},
			"power", {"upgrade_id": "power", "level": 1}, Vector2(213, 62),
			DINKY_BASE + "/Star.png"
		),
		_def(
			"faster_followthrough", Balance.UpgradeBranch.RHYTHM, "Tempo", "Faster swings.",
			10, 40.0, 1.55,
			{"type": "multiply", "stat": "swing_cooldown_ms", "value_per_level": 0.94},
			"metronome", {"upgrade_id": "metronome", "level": 1}, Vector2(213, 114),
			DINKY_BASE + "/Player/Walk01.png"
		),
		_def(
			"perfect_bonus", Balance.UpgradeBranch.RHYTHM, "Precision", "+Perfect payout.",
			8, 75.0, 1.6,
			{"type": "add", "stat": "perfect_payout_bonus", "value_per_level": 0.08},
			"faster_followthrough", {"upgrade_id": "faster_followthrough", "level": 1}, Vector2(213, 166),
			DINKY_BASE + "/TEXT/TXT_BIRDIE.png"
		),
		# Economy branch
		_def(
			"dollars_per_yard", Balance.UpgradeBranch.ECONOMY, "$/Yard", "More $ per yard.",
			10, 25.0, 1.5,
			{"type": "multiply", "stat": "dollars_per_yard", "value_per_level": 1.12},
			"power", {"upgrade_id": "power", "level": 1}, Vector2(378, 62),
			DINKY_BASE + "/TEXT/TXT_PAR.png"
		),
		_def(
			"tip_jar", Balance.UpgradeBranch.ECONOMY, "Tip Jar", "Flat $ per swing.",
			10, 40.0, 1.55,
			{"type": "add", "stat": "flat_bonus_per_swing", "value_per_level": 0.5},
			"dollars_per_yard", {"upgrade_id": "dollars_per_yard", "level": 1}, Vector2(410, 114),
			DINKY_BASE + "/HUD/Distance Box.png"
		),
		_def(
			"sponsorship", Balance.UpgradeBranch.ECONOMY, "Sponsor", "Global income mult.",
			8, 75.0, 1.6,
			{"type": "multiply", "stat": "global_multiplier", "value_per_level": 1.08},
			"tip_jar", {"upgrade_id": "tip_jar", "level": 1}, Vector2(378, 166),
			DINKY_BASE + "/TEXT/TXT_EAGLE.png"
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
	effect: Dictionary,
	parent_id: String,
	prerequisite: Dictionary,
	tree_pos: Vector2,
	icon_path: String
) -> Dictionary:
	return {
		"id": id,
		"branch": branch,
		"display_name": display_name,
		"description": description,
		"max_level": max_level,
		"base_cost": base_cost,
		"growth_rate": growth_rate,
		"effect": effect,
		"parent_id": parent_id,
		"prerequisite": prerequisite,
		"tree_pos": tree_pos,
		"icon_path": icon_path,
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
