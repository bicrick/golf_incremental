class_name ShopDefinitions
extends RefCounted
## Pro Shop item definitions — separate from the upgrade tree.

static var _by_id: Dictionary = {}
static var _order: Array[String] = []


static func _init_defs() -> void:
	if not _order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def(
			"ball_count", "More Balls",
			"Carry more balls per bucket before harvest.",
			Balance.BUCKET_CAPACITY_MAX - Balance.BUCKET_CAPACITY_DEFAULT,
			4.0, 1.18,
			[{"type": "add", "stat": "bucket_capacity_bonus", "value_per_level": Balance.BALL_COUNT_BONUS_PER_LEVEL}]
		),
		_def(
			"golden_ball", "Golden Balls",
			"Chance each ball pays double at pickup. Lv.1 unlocks at 5%.",
			10, 25.0, 1.40,
			[{"type": "golden_chance", "stat": "golden_ball_chance"}]
		),
	]
	for d in defs:
		_by_id[d["id"]] = d
		_order.append(d["id"])


static func _def(
	id: String,
	display_name: String,
	description: String,
	max_level: int,
	base_cost: float,
	growth_rate: float,
	effects: Array
) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"max_level": max_level,
		"base_cost": base_cost,
		"growth_rate": growth_rate,
		"effects": effects,
	}


static func all() -> Array:
	_init_defs()
	var result: Array = []
	for id in _order:
		result.append(_by_id[id])
	return result


static func get_def(id: String) -> Dictionary:
	_init_defs()
	return _by_id.get(id, {})


static func order() -> Array[String]:
	_init_defs()
	return _order
