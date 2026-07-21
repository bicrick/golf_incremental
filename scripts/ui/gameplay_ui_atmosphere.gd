extends Control
## Applies day/night canvas_modulate tint to gameplay HUD chrome (currency, bucket, icon buttons).

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate = Color.WHITE
	EventBus.atmosphere_tint_changed.connect(_on_atmosphere_tint_changed)


func _on_atmosphere_tint_changed(tint: Color) -> void:
	modulate = tint
