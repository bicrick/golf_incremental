extends Control
## Full-viewport shell for UI under CanvasLayer — gives children a real Control rect.
## MOUSE_FILTER_PASS so wheel events can be forwarded to the range camera when the
## embedded editor runner delivers them to UI instead of Node._input.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bind_viewport()
	if not get_viewport().size_changed.is_connected(_bind_viewport):
		get_viewport().size_changed.connect(_bind_viewport)


func _bind_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _gui_input(event: InputEvent) -> void:
	var upgrade_panel := get_node_or_null("UpgradePanel")
	if upgrade_panel and upgrade_panel.has_method(&"is_open") and upgrade_panel.is_open():
		if upgrade_panel.has_method(&"consume_pan_drag_event") and upgrade_panel.consume_pan_drag_event(event):
			accept_event()
			return
		if upgrade_panel.has_method(&"consume_zoom_event") and upgrade_panel.consume_zoom_event(event):
			accept_event()
		return
	var range_view := get_node_or_null("../../RangeView")
	if range_view == null:
		return
	if range_view.has_method(&"consume_pan_drag_event") and range_view.consume_pan_drag_event(event):
		accept_event()
		return
	if range_view.has_method(&"consume_zoom_event") and range_view.consume_zoom_event(event):
		accept_event()
