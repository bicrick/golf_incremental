class_name UpgradeNodeTap
extends RefCounted
## Mobile: first tap inspects (tooltip + highlight), second tap buys.
## Desktop hover + click-to-buy is unchanged.

## Tests can force inspect-mode without a touchscreen.
static var force_inspect_mode := false
static var _selected: Node = null


static func is_inspect_mode() -> bool:
	return force_inspect_mode or UiLayout.is_mobile_touch()


static func is_selected(node: Node) -> bool:
	return _selected == node and is_instance_valid(_selected)


static func selected() -> Node:
	if _selected != null and not is_instance_valid(_selected):
		_selected = null
	return _selected


static func select(node: Node) -> void:
	if node == _selected:
		return
	_clear_current()
	_selected = node
	if node != null and node.has_method("begin_inspect"):
		node.begin_inspect()


static func clear(from: Node = null) -> void:
	if from != null and _selected != from:
		return
	_clear_current()


static func _clear_current() -> void:
	var prev := _selected
	_selected = null
	if prev != null and is_instance_valid(prev) and prev.has_method("clear_inspect"):
		prev.clear_inspect()
