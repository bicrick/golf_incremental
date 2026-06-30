extends Control
## Full-screen fairway stripe background drawn via Control._draw (reliable under CanvasLayer).

var _polygons: Array[Dictionary] = []
var _title_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebuild()


func setup_for_title() -> void:
	_title_mode = true
	_rebuild()


func stripe_count() -> int:
	return _polygons.size()


func _rebuild() -> void:
	if _title_mode:
		_polygons = FairwayStripes.build_title_screen_polygons()
	else:
		_polygons = FairwayStripes.build_polygons()
	queue_redraw()


func _draw() -> void:
	for entry in _polygons:
		draw_colored_polygon(entry["polygon"], entry["color"])
