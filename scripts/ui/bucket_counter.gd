extends HBoxContainer
## Bottom-right ball bucket count — Dinky ball icon + number + combo during harvest.

const COLOR_NORMAL := Color(0.85, 0.92, 0.98, 1.0)
const COLOR_EMPTY := Color(0.95, 0.55, 0.45, 0.85)
const COLOR_COMBO := Color(1.0, 0.88, 0.25, 1.0)

@onready var _ball_icon: TextureRect = $BallIcon
@onready var _count_label: Label = $CountLabel
@onready var _combo_label: Label = $ComboLabel

var _combo_hide_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_icon.texture = DinkySpriteFrames.ball_lay_texture()
	_ball_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	PixelFont.apply_label(_count_label, 10)
	PixelFont.apply_label(_combo_label, 8)
	_combo_label.visible = false
	_combo_label.add_theme_color_override(&"font_color", COLOR_COMBO)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.ball_collected.connect(_on_ball_collected)
	EventBus.phase_changed.connect(_on_phase_changed)
	_update_count(GameState.bucket_remaining)


func _process(delta: float) -> void:
	if _combo_hide_timer <= 0.0:
		return
	_combo_hide_timer -= delta
	if _combo_hide_timer <= 0.0 and not GameState.is_harvest_phase():
		_combo_label.visible = false


func _on_bucket_changed(count: int, _capacity: int) -> void:
	_update_count(count)


func _on_phase_changed(phase: String) -> void:
	if phase == "strike":
		_combo_label.visible = false
		_combo_hide_timer = 0.0
		_update_count(GameState.bucket_remaining)


func _on_ball_collected(_world_pos: Vector2, combo: int) -> void:
	if combo <= 1:
		_combo_label.visible = false
		return
	_combo_label.text = "x%d" % combo
	_combo_label.visible = true
	_combo_hide_timer = Balance.COMBO_WINDOW_SEC + 0.4


func _update_count(count: int) -> void:
	_count_label.text = str(count)
	var tint := COLOR_EMPTY if count <= 0 and not GameState.is_harvest_phase() else COLOR_NORMAL
	_count_label.add_theme_color_override(&"font_color", tint)
	_ball_icon.modulate = tint


func get_tween_target_global() -> Vector2:
	return get_global_rect().get_center()
