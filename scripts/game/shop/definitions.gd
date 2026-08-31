class_name ShopDefinitions
extends RefCounted
## Pro Shop item definitions — empty; ball_count / golden live on the cash tree.

static var _by_id: Dictionary = {}
static var _order: Array[String] = []


static func _init_defs() -> void:
	if not _order.is_empty():
		return
	# Capacity / golden are cash-tree nodes (ball_count, golden_ball).
	var defs: Array[Dictionary] = []
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
