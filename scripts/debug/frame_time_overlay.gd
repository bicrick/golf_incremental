extends CanvasLayer
## Always-on frame-time graph overlay. Toggle from Settings.

@onready var _panel: Control = $Panel
@onready var _graph: Control = $Panel/Graph


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_enabled(SaveManager.frame_graph_enabled)


func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	if _graph:
		_graph.visible = enabled
		if enabled and _graph.has_method("clear_peak"):
			_graph.clear_peak()
