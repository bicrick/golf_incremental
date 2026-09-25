class_name UpgradeGraph
extends RefCounted
## Unified mega-tree graph — merges player, shop, Ratina, and Rattling definitions.

const ROOT_ID := "base_pay"

const NAMESPACE_PLAYER := "player"
const NAMESPACE_SHOP := "shop"
const NAMESPACE_RATINA := "ratina"
const NAMESPACE_RATTLING := "rattling"

static var _nodes: Dictionary = {}
static var _tree_order: Array[String] = []
static var _children: Dictionary = {}


static func _graph_overrides() -> Dictionary:
	## Crew subtrees hang off the player tree (they are story-gated below).
	return {
		"rattling_more": "pickup",
	}


## v5 story gates — node id → StoryFinds id that must be found first.
## Crew roots stay hidden until their find; other gated nodes show locked with a hint.
const STORY_GATES := {
	"rattling_more": "rattling_burrow",
	"quick_reset": "range_bell",
	"ball_count": "picker_cart",
	"golden_ball": "stone_lantern",
	"perfect_chain": "tee_sign",
	"spoon_club": "barley_spoon",
	"driver_club": "persimmon_driver",
}
const HIDDEN_UNTIL_FOUND := ["rattling_more"]


static func story_gate(id: String) -> String:
	return String(STORY_GATES.get(id, ""))


static func _story_gate_open(id: String) -> bool:
	var find_id := story_gate(id)
	if find_id.is_empty():
		return true
	return _game_state().is_find_found(find_id)


static func _init_graph() -> void:
	if not _tree_order.is_empty():
		return
	_nodes.clear()
	_children.clear()
	_tree_order.clear()

	for def in UpgradeDefinitions.all():
		_register_node(def, NAMESPACE_PLAYER)
	# Shop empty. Crew trees join behind story finds (Ratina's bag, the burrow).
	for def in RatinaUpgradeDefinitions.all():
		_register_node(def, NAMESPACE_RATINA)
	for def in RattlingUpgradeDefinitions.all():
		_register_node(def, NAMESPACE_RATTLING)


static func _register_node(def: Dictionary, node_namespace: String) -> void:
	var id: String = def["id"]
	var parent: String = def.get("parent_id", "")
	var overrides := _graph_overrides()
	if overrides.has(id):
		parent = overrides[id]
	var node := {
		"id": id,
		"namespace": node_namespace,
		"parent_id": parent,
		"prerequisite": def.get("prerequisite", {}).duplicate(),
		"def": def,
	}
	_nodes[id] = node
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
	var node := get_node(id)
	return node.get("def", {})


static func namespace_for(id: String) -> String:
	return get_node(id).get("namespace", "")


static func parent_id(id: String) -> String:
	return get_node(id).get("parent_id", "")


static func tree_order() -> Array[String]:
	_init_graph()
	return _tree_order


static func children(id: String) -> Array[String]:
	_init_graph()
	if _children.is_empty():
		_build_children_map()
	return _children.get(id, [])


static func _build_children_map() -> void:
	for child_id in _tree_order:
		var parent: String = parent_id(child_id)
		if parent.is_empty():
			continue
		if not _children.has(parent):
			_children[parent] = []
		_children[parent].append(child_id)


static func connections() -> Array:
	_init_graph()
	var links: Array = []
	for id in _tree_order:
		var parent: String = parent_id(id)
		if parent.is_empty():
			continue
		links.append({"from": parent, "to": id})
	return links


static func _game_state() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


static func level(id: String) -> int:
	match namespace_for(id):
		NAMESPACE_PLAYER:
			return _game_state().get_upgrade_level(id)
		NAMESPACE_SHOP:
			return _game_state().get_shop_item_level(id)
		NAMESPACE_RATINA:
			return _game_state().get_ratina_upgrade_level(id)
		NAMESPACE_RATTLING:
			return _game_state().get_rattling_upgrade_level(id)
		_:
			return 0


static func cost(id: String) -> float:
	match namespace_for(id):
		NAMESPACE_PLAYER:
			return _game_state().get_upgrade_cost(id)
		NAMESPACE_SHOP:
			return _game_state().get_shop_item_cost(id)
		NAMESPACE_RATINA:
			return _game_state().get_ratina_upgrade_cost(id)
		NAMESPACE_RATTLING:
			return _game_state().get_rattling_upgrade_cost(id)
		_:
			return 0.0


static func is_unlocked(id: String) -> bool:
	_init_graph()
	var node := get_node(id)
	if node.is_empty():
		return false
	if not _story_gate_open(id):
		return false
	var prereq: Dictionary = node.get("prerequisite", {})
	if prereq.is_empty():
		return _namespace_unlock_gate(id)
	var req_id: String = prereq.get("upgrade_id", "")
	var req_level: int = prereq.get("level", 1)
	if level(req_id) < req_level:
		return false
	return _namespace_unlock_gate(id)


static func _namespace_unlock_gate(id: String) -> bool:
	var ns := namespace_for(id)
	if ns == NAMESPACE_RATINA and id != "ratina_hire":
		return _game_state().ratina_unlocked
	if ns == NAMESPACE_RATTLING and id != "rattling_more":
		return _game_state().rattlings_unlocked
	return true


static func is_revealed(id: String) -> bool:
	if id == ROOT_ID:
		return true
	if id in HIDDEN_UNTIL_FOUND and not _story_gate_open(id):
		return false
	var parent: String = parent_id(id)
	if parent.is_empty():
		return true
	if not is_revealed(parent):
		return false
	return level(parent) >= 1


static func lock_hint(id: String) -> String:
	if is_unlocked(id):
		return ""
	if not _story_gate_open(id):
		var find := StoryFinds.get_def(story_gate(id))
		if _game_state().is_find_revealed(story_gate(id)):
			return "Find the %s (~%d yd)" % [
				String(find.get("display_name", "?")), int(find.get("yards", 0))
			]
		return "Hidden in the mist (~%d yd)" % int(find.get("yards", 0))
	var node := get_node(id)
	var prereq: Dictionary = node.get("prerequisite", {})
	if prereq.is_empty():
		return "Locked"
	var req_id: String = prereq.get("upgrade_id", "")
	var req_level: int = prereq.get("level", 1)
	var req_def := get_def(req_id)
	var req_name: String = req_def.get("display_name", req_id)
	return "Need %s Lv.%d" % [req_name, req_level]


static func purchase(id: String) -> bool:
	match namespace_for(id):
		NAMESPACE_PLAYER:
			return _game_state().purchase_upgrade(id)
		NAMESPACE_SHOP:
			return _game_state().purchase_shop_item(id)
		NAMESPACE_RATINA:
			return _game_state().purchase_ratina_upgrade(id)
		NAMESPACE_RATTLING:
			return _game_state().purchase_rattling_upgrade(id)
		_:
			return false


static func has_affordable_upgrade() -> bool:
	_init_graph()
	for id in _tree_order:
		var def: Dictionary = get_def(id)
		var current_level: int = level(id)
		if current_level >= int(def.get("max_level", 0)):
			continue
		if not is_unlocked(id):
			continue
		if not is_revealed(id):
			continue
		if _game_state().currency >= cost(id):
			return true
	return false
