extends CanvasLayer
## Range Rat title screen — parallax cloud sky, Play starts the game.

signal play_pressed

const LOGO_DISPLAY_SIZE := Vector2(420.0, 132.0)
const PROMPT_FONT_SIZE := 8
const FADE_DURATION_SEC := 0.5

const PROMPT_FADE_MIN_ALPHA := 0.25
const PROMPT_FADE_MAX_ALPHA := 1.0
const PROMPT_FADE_HALF_CYCLE_SEC := 0.9

@onready var sky_bg: Control = $SkyBg
@onready var overlay: Control = $Overlay
@onready var title_logo: TextureRect = $Overlay/Center/VBox/TitleLogo
@onready var press_space_label: Label = $Overlay/Center/VBox/PressSpace

var _transitioning := false
var _prompt_fade_tween: Tween


func _ready() -> void:
	_setup_title_logo()
	_setup_press_space_label()
	press_space_label.gui_input.connect(_on_press_space_gui_input)
	_start_prompt_fade()


func is_transitioning() -> bool:
	return _transitioning


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or not visible:
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.echo or not key.pressed or key.keycode != KEY_SPACE:
		return
	get_viewport().set_input_as_handled()
	_on_play_pressed()


func _setup_title_logo() -> void:
	title_logo.custom_minimum_size = LOGO_DISPLAY_SIZE
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _setup_press_space_label() -> void:
	press_space_label.text = "Press Space"
	press_space_label.mouse_default_cursor_shape = CursorManager.SELECTABLE_CURSOR_SHAPE
	PixelFont.apply_label(press_space_label, PROMPT_FONT_SIZE)
	press_space_label.add_theme_color_override(&"font_color", Color.BLACK)
	press_space_label.add_theme_color_override(&"font_outline_color", Color.BLACK)


func _start_prompt_fade() -> void:
	_stop_prompt_fade()
	press_space_label.modulate.a = PROMPT_FADE_MAX_ALPHA
	_prompt_fade_tween = create_tween().set_loops()
	_prompt_fade_tween.tween_property(
		press_space_label, "modulate:a", PROMPT_FADE_MIN_ALPHA, PROMPT_FADE_HALF_CYCLE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_fade_tween.tween_property(
		press_space_label, "modulate:a", PROMPT_FADE_MAX_ALPHA, PROMPT_FADE_HALF_CYCLE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_prompt_fade() -> void:
	if _prompt_fade_tween != null and _prompt_fade_tween.is_valid():
		_prompt_fade_tween.kill()
	_prompt_fade_tween = null


func _on_press_space_gui_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_on_play_pressed()


func _on_play_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_stop_prompt_fade()
	SfxManager.play_start()
	SfxManager.start_bgm()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sky_bg, "modulate:a", 0.0, FADE_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	tween.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	tween.chain().tween_callback(_finish_fade_out)


func _finish_fade_out() -> void:
	play_pressed.emit()


func reset_for_show() -> void:
	_transitioning = false
	sky_bg.modulate.a = 1.0
	overlay.modulate.a = 1.0
	press_space_label.modulate.a = PROMPT_FADE_MAX_ALPHA
	_start_prompt_fade()
