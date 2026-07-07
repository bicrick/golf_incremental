class_name UiInput
extends RefCounted
## Shared guard so camera pan / pickup / background-click gameplay input never
## swallows clicks meant for interactive UI (shop, upgrades, Hit button, etc).


static func is_interactive_control_under_mouse(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	var hovered := viewport.gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered is BaseButton:
		return true
	return hovered.mouse_filter == Control.MOUSE_FILTER_STOP
