extends Control
## Soft day/night tint on gameplay HUD chrome — keeps cream plates readable.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate = Color.WHITE
	EventBus.atmosphere_tint_changed.connect(_on_atmosphere_tint_changed)


func _on_atmosphere_tint_changed(tint: Color) -> void:
	modulate = UiTheme.ui_atmosphere_modulate(tint)
