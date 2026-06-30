extends Node
## Root scene — title screen first, Play reveals range view and HUD.

@onready var range_view: Node2D = $RangeView
@onready var ui: CanvasLayer = $UI
@onready var title_screen: CanvasLayer = $TitleScreen


func _ready() -> void:
	range_view.visible = false
	ui.visible = false
	title_screen.play_pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	title_screen.visible = false
	if title_screen.has_method("reset_for_show"):
		title_screen.reset_for_show()
	range_view.visible = true
	ui.visible = true
