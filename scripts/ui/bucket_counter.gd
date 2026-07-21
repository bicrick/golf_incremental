extends PanelContainer
## Bottom-right ball bucket count — themed plate, Dinky ball icon + current/max fraction.
## In collect mode (incomplete bucket), pulses/bobs and accepts click to return all litter free.

signal return_all_pressed

const COLOR_NORMAL := UiTheme.COLOR_PANEL_TEXT
const COLOR_ICON_NORMAL := Color.WHITE
const COLOR_EMPTY := Color(0.95, 0.55, 0.45, 0.85)
const GLOW_MODULATE := Color(1.18, 1.24, 1.14, 1.0)
const GLOW_HALF_CYCLE_SEC := 0.7
const BOB_AMPLITUDE := 2.0
const BOB_FREQ := 2.6

@onready var _ball_icon: TextureRect = $Row/BallIcon
@onready var _count_label: Label = $Row/CountLabel

var _glow_tween: Tween
var _actionable := false
var _rest_y := 0.0
var _bob_time := 0.0
var _rest_captured := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)
	UiTheme.apply_hud_plate(self)
	_ball_icon.texture = DinkySpriteFrames.ball_lay_texture()
	_ball_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ball_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelFont.apply_label(_count_label, 10)
	UiTheme.apply_panel_label(_count_label)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	_update_count(GameState._bucket_display_count(), GameState.bucket_capacity)
	set_process(false)
	_refresh_actionable()


func _process(delta: float) -> void:
	if not _actionable or not _rest_captured:
		return
	_bob_time += delta
	position.y = _rest_y + sin(_bob_time * BOB_FREQ) * BOB_AMPLITUDE


func _on_bucket_changed(count: int, capacity: int) -> void:
	_update_count(count, capacity)
	_refresh_actionable()


func _on_phase_changed(_phase: String) -> void:
	_update_count(GameState._bucket_display_count(), GameState.bucket_capacity)
	_refresh_actionable()


func _update_count(count: int, capacity: int) -> void:
	_count_label.text = "%d/%d" % [count, capacity]
	var empty := count <= 0 and not GameState.is_harvest_phase()
	_count_label.add_theme_color_override(&"font_color", COLOR_EMPTY if empty else COLOR_NORMAL)
	# Never tint the ball sprite with text green — that reads as near-black.
	_ball_icon.modulate = COLOR_EMPTY if empty else COLOR_ICON_NORMAL


func get_tween_target_global() -> Vector2:
	return get_global_rect().get_center()


func _refresh_actionable() -> void:
	var was_actionable := _actionable
	_actionable = GameState.is_collect_mode()
	if _actionable:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CursorManager.SELECTABLE_CURSOR_SHAPE
		_start_attention()
		if not was_actionable:
			# Capture after HBox reflow (Hit button may appear the same frame).
			call_deferred("_capture_rest_y")
			get_tree().create_timer(0.05).timeout.connect(_capture_rest_y)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_stop_attention()


func _capture_rest_y() -> void:
	if not _actionable:
		return
	_rest_y = position.y
	_bob_time = 0.0
	_rest_captured = true


func _start_attention() -> void:
	if _glow_tween == null or not _glow_tween.is_valid():
		modulate = Color.WHITE
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(self, "modulate", GLOW_MODULATE, GLOW_HALF_CYCLE_SEC).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_property(self, "modulate", Color.WHITE, GLOW_HALF_CYCLE_SEC).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
	set_process(true)


func _stop_attention() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
	modulate = Color.WHITE
	set_process(false)
	if _rest_captured:
		position.y = _rest_y
	_rest_captured = false
	_bob_time = 0.0


func _on_gui_input(event: InputEvent) -> void:
	if not _actionable:
		return
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	accept_event()
	return_all_pressed.emit()
