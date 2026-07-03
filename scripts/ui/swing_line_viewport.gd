extends PanelContainer
## Persistent 9:16 perspective swing-line feed in a wood-trim panel.

const ASPECT_WIDTH := 9.0
const ASPECT_HEIGHT := 16.0
const ASPECT_TOLERANCE := 0.02

@export var viewport_size: Vector2i = Vector2i(108, 192):
	set(value):
		viewport_size = value
		if is_inside_tree():
			_apply_viewport_size()

@export var panel_margin: Vector2 = Vector2(8.0, 44.0)

@onready var _sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var _sub_viewport_container: SubViewportContainer = $SubViewportContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_wood_panel(self)
	offset_left = panel_margin.x
	offset_top = panel_margin.y
	_sub_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sub_viewport.own_world_3d = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_apply_viewport_size()
	call_deferred("_bind_camera")


func _apply_viewport_size() -> void:
	if _sub_viewport == null:
		return
	_warn_if_aspect_drift(viewport_size)
	_sub_viewport.size = viewport_size
	if _sub_viewport_container:
		_sub_viewport_container.custom_minimum_size = Vector2(viewport_size)


func _warn_if_aspect_drift(size: Vector2i) -> void:
	if size.y <= 0:
		return
	var ratio := float(size.x) / float(size.y)
	var target := ASPECT_WIDTH / ASPECT_HEIGHT
	if absf(ratio - target) > ASPECT_TOLERANCE:
		push_warning(
			"SwingLineViewport: viewport_size %s is not 9:16 — center crop will be wrong." % size
		)


func _bind_camera() -> void:
	var range_view := get_node_or_null("../../RangeView")
	if range_view and range_view.has_method(&"bind_swing_line_viewport"):
		range_view.bind_swing_line_viewport(_sub_viewport)
