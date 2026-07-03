extends Control
## Full-screen palette wash overlay for view mode switches.

@onready var _overlay: ColorRect = $ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0


func crossfade_wash(peak: Color, out_color: Color, fade_in: float, fade_out: float) -> void:
	_overlay.color = peak
	visible = true
	if fade_in <= 0.0 and fade_out <= 0.0:
		modulate.a = 0.0
		visible = false
		return
	if fade_in <= 0.0:
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		var fade_in_tween := create_tween()
		fade_in_tween.tween_property(self, "modulate:a", 1.0, fade_in)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await fade_in_tween.finished

	if fade_out <= 0.0:
		modulate.a = 0.0
		visible = false
		return

	var fade_out_tween := create_tween().set_parallel(true)
	fade_out_tween.tween_property(self, "modulate:a", 0.0, fade_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out_tween.tween_property(_overlay, "color", out_color, fade_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out_tween.finished
	visible = false
