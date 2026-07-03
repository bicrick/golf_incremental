extends Control
## Full-viewport shell for UI under CanvasLayer — gives children a real Control rect.


func _ready() -> void:
	_bind_viewport()
	if not get_viewport().size_changed.is_connected(_bind_viewport):
		get_viewport().size_changed.connect(_bind_viewport)


func _bind_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _gui_input(event: InputEvent) -> void:
	# Fallback: embedded debug runner often delivers wheel to UI before 3D _input.
	var range_view := get_node_or_null("../../RangeView")
	if range_view and range_view.has_method(&"consume_zoom_event"):
		if range_view.consume_zoom_event(event):
			accept_event()
