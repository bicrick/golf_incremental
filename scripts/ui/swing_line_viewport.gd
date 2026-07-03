extends SubViewportContainer
## Perspective swing-line overlay — left 25% of screen; main range renders full width underneath.

@onready var _sub_viewport: SubViewport = $SubViewport


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch = true
	_sub_viewport.own_world_3d = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func bind_range_camera() -> void:
	var range_view := _find_range_view()
	if range_view == null:
		push_warning("SwingLineViewport: RangeView not found — perspective feed unavailable.")
		return
	if not range_view.has_method(&"bind_swing_line_viewport"):
		return
	range_view.bind_swing_line_viewport(_sub_viewport)


func _find_range_view() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null("RangeView")
	return get_tree().get_first_node_in_group(&"range_view")
