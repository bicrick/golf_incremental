extends Control
## Full-screen palette wash overlay for view mode switches.

@onready var _overlay: ColorRect = $ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0


func fade_in_wash(peak: Color, duration: float) -> void:
	_overlay.color = peak
	visible = true
	if duration <= 0.0:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func fade_out_wash(out_color: Color, duration: float) -> void:
	if duration <= 0.0:
		modulate.a = 0.0
		visible = false
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_overlay, "color", out_color, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	visible = false
