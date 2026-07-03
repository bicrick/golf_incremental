extends Control
## Full-screen sky-color crossfade overlay for view mode switches.

@onready var _overlay: ColorRect = $ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0


func fade_to_color(color: Color, duration: float) -> void:
	_overlay.color = color
	visible = true
	if duration <= 0.0:
		modulate.a = 1.0
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func fade_out(duration: float) -> void:
	if duration <= 0.0:
		modulate.a = 0.0
		visible = false
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	visible = false
