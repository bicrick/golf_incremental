class_name PrestigeGraph
extends RefCounted
## Prestige (cheese) tree graph helpers for UI and unlock checks.

const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")

const ROOT_ID := "cheese_press"
const NAMESPACE_PRESTIGE := "prestige"

static var _nodes: Dictionary = {}
static var _tree_order: Array[String] = []
static var _children: Dictionary = {}


static func _init_graph() -> void:
	if not _tree_order.is_empty():
		return
	_nodes.clear()
	_children.clear()
	_tree_order.clear()
	for def in PrestigeDefinitionsScript.all():
		var id: String = def["id"]
		_nodes[id] = {
			"id": id,
			"namespace": NAMESPACE_PRESTIGE,
			"parent_id": def.get("parent_id", ""),
			"prerequisite": def.get("prerequisite", {}).duplicate(),
			"def": def,
		}
		_tree_order.append(id)


static func all_nodes() -> Array:
	_init_graph()
	var result: Array = []
	for id in _tree_order:
		result.append(_nodes[id])
	return result


static func get_node(id: String) -> Dictionary:
	_init_graph()
	return _nodes.get(id, {})


static func get_def(id: String) -> Dictionary:
	return get_node(id).get("def", {})


static func parent_id(id: String) -> String:
	return get_node(id).get("parent_id", "")


static func tree_order() -> Array[String]:
	_init_graph()
	return _tree_order


static func connections() -> Array:
	return PrestigeDefinitionsScript.connections()


static func children(id: String) -> Array[String]:
	_init_graph()
	if _children.is_empty():
		_build_children_map()
	return _children.get(id, [])


static func _build_children_map() -> void:
	_children.clear()
	for link in connections():
		var parent: String = link["from"]
		var child: String = link["to"]
		if not _children.has(parent):
			_children[parent] = [] as Array[String]
		(_children[parent] as Array[String]).append(child)


static func level(id: String) -> int:
	return Engine.get_main_loop().root.get_node("GameState").get_prestige_upgrade_level(id)


static func cost(id: String) -> float:
	return Engine.get_main_loop().root.get_node("GameState").get_prestige_upgrade_cost(id)


static func is_unlocked(id: String) -> bool:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	return PrestigeDefinitionsScript.is_unlocked(id, gs.prestige_levels)


static func is_revealed(id: String) -> bool:
	if id == ROOT_ID:
		return true
	var parent := parent_id(id)
	if parent.is_empty():
		return true
	return level(parent) >= 1


static func purchase(id: String) -> bool:
	return Engine.get_main_loop().root.get_node("GameState").purchase_prestige_upgrade(id)


static func lock_hint(id: String) -> String:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	return PrestigeDefinitionsScript.lock_hint(id, gs.prestige_levels)
