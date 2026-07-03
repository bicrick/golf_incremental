extends Control
## Full-screen snapshot dissolve for view mode switches.

@onready var _snapshot: TextureRect = $Snapshot

var _capture_ui_hook: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	_snapshot.visible = false
	_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE


func set_capture_ui_hook(hook: Callable) -> void:
	_capture_ui_hook = hook


func capture_from_viewport() -> void:
	_set_gameplay_ui_visible(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_tex := get_viewport().get_texture()
	_set_gameplay_ui_visible(true)
	if viewport_tex == null:
		return
	var image := viewport_tex.get_image()
	if image == null or image.is_empty():
		return
	var texture := ImageTexture.create_from_image(image)
	_snapshot.texture = texture
	_snapshot.visible = true
	visible = true
	modulate.a = 1.0


func dissolve_out(duration: float) -> void:
	if duration <= 0.0:
		_clear_snapshot()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_clear_snapshot()


func _clear_snapshot() -> void:
	modulate.a = 0.0
	visible = false
	_snapshot.visible = false
	_snapshot.texture = null


func _set_gameplay_ui_visible(show_ui: bool) -> void:
	if _capture_ui_hook.is_valid():
		_capture_ui_hook.call(show_ui)
		return
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method(&"set_capture_ui_visible"):
		main.set_capture_ui_visible(show_ui)
