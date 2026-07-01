extends Button
## Collect / Hit mode toggle during harvest phase.

const COLOR_COLLECT := Color(0.95, 0.75, 0.45, 1.0)
const COLOR_HIT := Color(0.75, 0.82, 0.72, 1.0)
const COLOR_DISABLED := Color(0.55, 0.52, 0.48, 0.7)


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	tooltip_text = ""
	pressed.connect(_on_pressed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.range_action_changed.connect(_on_range_action_changed)
	_apply_style()
	_sync_from_state()


func _on_pressed() -> void:
	GameState.toggle_range_action()


func _on_phase_changed(_phase: String) -> void:
	_sync_from_state()


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_sync_from_state()


func _on_range_action_changed(_mode: String) -> void:
	_sync_from_state()


func _sync_from_state() -> void:
	var in_harvest := GameState.is_harvest_phase()
	visible = in_harvest
	if not in_harvest:
		return
	disabled = not GameState.can_toggle_range_action()
	if GameState.is_hit_mode():
		text = "HIT"
		add_theme_color_override(&"font_color", COLOR_HIT if not disabled else COLOR_DISABLED)
	else:
		text = "COL"
		add_theme_color_override(&"font_color", COLOR_COLLECT if not disabled else COLOR_DISABLED)


func _apply_style() -> void:
	custom_minimum_size = Vector2(28, 20)
	add_theme_font_override(&"font", PixelFont.font_for_size(8))
	add_theme_font_size_override(&"font_size", 8)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0.35, 0.28, 0.22, 0.85)
	empty.border_width_left = 1
	empty.border_width_top = 1
	empty.border_width_right = 1
	empty.border_width_bottom = 1
	empty.border_color = Color(0.2, 0.15, 0.1, 0.9)
	empty.corner_radius_top_left = 2
	empty.corner_radius_top_right = 2
	empty.corner_radius_bottom_left = 2
	empty.corner_radius_bottom_right = 2
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_color_override(&"font_outline_color", Color(0.2, 0.15, 0.1, 0.8))
	add_theme_constant_override(&"outline_size", 1)
