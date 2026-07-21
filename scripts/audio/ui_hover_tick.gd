class_name UiHoverTick
extends RefCounted
## Detects entering a selectable UI control and throttles hover ticks (Cuelume-style).

const COOLDOWN_MS := 150

var _target_id := 0
var _last_msec := -999999


## Returns true once when the mouse enters a new selectable target (throttled).
func poll(hovered: Control) -> bool:
	var selectable := resolve_selectable(hovered)
	var id := selectable.get_instance_id() if selectable != null else 0
	if id == _target_id:
		return false
	_target_id = id
	if selectable == null:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_msec < COOLDOWN_MS:
		return false
	_last_msec = now
	return true


static func resolve_selectable(control: Control) -> Control:
	var node: Node = control
	while node != null:
		if node is BaseButton:
			return node as Control
		if node is Control:
			var c := node as Control
			if c.mouse_default_cursor_shape == CursorManager.SELECTABLE_CURSOR_SHAPE:
				return c
		node = node.get_parent()
	return null
