extends PanelContainer
## Bottom-right ball bucket count — wood panel, Dinky ball icon + current/max fraction.

const COLOR_NORMAL := Color(0.85, 0.92, 0.98, 1.0)
const COLOR_EMPTY := Color(0.95, 0.55, 0.45, 0.85)

@onready var _ball_icon: TextureRect = $Row/BallIcon
@onready var _count_label: Label = $Row/CountLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_wood_panel(self)
	_ball_icon.texture = DinkySpriteFrames.ball_lay_texture()
	_ball_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	PixelFont.apply_label(_count_label, 10)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	_update_count(GameState._bucket_display_count(), GameState.bucket_capacity)


func _on_bucket_changed(count: int, capacity: int) -> void:
	_update_count(count, capacity)


func _on_phase_changed(_phase: String) -> void:
	_update_count(GameState._bucket_display_count(), GameState.bucket_capacity)


func _update_count(count: int, capacity: int) -> void:
	_count_label.text = "%d/%d" % [count, capacity]
	var tint := COLOR_EMPTY if count <= 0 and not GameState.is_harvest_phase() else COLOR_NORMAL
	_count_label.add_theme_color_override(&"font_color", tint)
	_ball_icon.modulate = tint


func get_tween_target_global() -> Vector2:
	return get_global_rect().get_center()
