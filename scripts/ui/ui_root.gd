extends Control
## Full-viewport shell for UI under CanvasLayer — gives children a real Control rect.
## MOUSE_FILTER_IGNORE so fairway/empty space clicks reach gameplay; buttons/panels
## keep STOP. Wheel/pan still flow via Node._input on camera controllers.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_viewport()
	if not get_viewport().size_changed.is_connected(_bind_viewport):
		get_viewport().size_changed.connect(_bind_viewport)


func _bind_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
