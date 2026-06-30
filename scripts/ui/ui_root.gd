extends Control
## Full-viewport shell for UI under CanvasLayer — gives children a real Control rect.


func _ready() -> void:
	_bind_viewport()
	if not get_viewport().size_changed.is_connected(_bind_viewport):
		get_viewport().size_changed.connect(_bind_viewport)


func _bind_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
