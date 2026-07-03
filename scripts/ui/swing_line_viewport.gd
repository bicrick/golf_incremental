extends SubViewportContainer
## Perspective swing-line overlay. Renders at physical window pixels for the panel rect (crisp 3D/sprites).

@onready var _sub_viewport: SubViewport = $SubViewport


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch = false
	_sub_viewport.own_world_3d = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.snap_2d_transforms_to_pixel = true
	_sub_viewport.snap_2d_vertices_to_pixel = true
	_sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_sub_viewport.scaling_3d_scale = 1.0
	resized.connect(_sync_viewport_resolution)
	get_viewport().size_changed.connect(_sync_viewport_resolution)
	call_deferred("_sync_viewport_resolution")


func bind_range_camera() -> void:
	var range_view := _find_range_view()
	if range_view == null:
		push_warning("SwingLineViewport: RangeView not found — perspective feed unavailable.")
		return
	if not range_view.has_method(&"bind_swing_line_viewport"):
		return
	range_view.bind_swing_line_viewport(_sub_viewport)


func _sync_viewport_resolution() -> void:
	if _sub_viewport == null:
		return
	var target := _physical_pixel_size()
	if _sub_viewport.size != target:
		_sub_viewport.size = target


func _physical_pixel_size() -> Vector2i:
	var xform := get_screen_transform()
	var corners: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y),
	]
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for corner in corners:
		var screen_p: Vector2 = xform * corner
		min_p = min_p.min(screen_p)
		max_p = max_p.max(screen_p)
	return Vector2i(
		maxi(1, int(round(max_p.x - min_p.x))),
		maxi(1, int(round(max_p.y - min_p.y)))
	)


func _find_range_view() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null("RangeView")
	return get_tree().get_first_node_in_group(&"range_view")
