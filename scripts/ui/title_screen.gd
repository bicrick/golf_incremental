extends CanvasLayer
## Range Rat title screen — parallax cloud sky, Play starts the game.

signal play_pressed

const TITLE_FONT_SIZE := 18
const BUTTON_FONT_SIZE := 12
const FADE_DURATION_SEC := 0.5

const COLOR_TITLE := Color(1.0, 0.92, 0.45, 1.0)
const COLOR_TITLE_OUTLINE := Color(0.2, 0.15, 0.08, 0.9)
const COLOR_BUTTON_FILL := Color(0.82, 0.72, 0.48, 1.0)
const COLOR_BUTTON_BORDER := Color(0.18, 0.52, 0.48, 1.0)
const COLOR_BUTTON_HOVER := Color(0.92, 0.82, 0.58, 1.0)
const COLOR_BUTTON_PRESSED := Color(0.68, 0.58, 0.38, 1.0)

const BOB_AMPLITUDE_PX := 3.0
const BOB_SPEED := 2.4

@onready var sky_bg: Control = $SkyBg
@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/Center/VBox/TitleLabel
@onready var play_button: Button = $Overlay/Center/VBox/PlayBob/PlayButton

var _bob_time := 0.0
var _play_button_rest_y := 0.0
var _transitioning := false


func _ready() -> void:
	_apply_fonts()
	_style_play_button()
	play_button.pressed.connect(_on_play_pressed)
	call_deferred("_capture_play_button_rest_y")


func _capture_play_button_rest_y() -> void:
	_play_button_rest_y = play_button.position.y


func _process(delta: float) -> void:
	if _transitioning:
		return
	_bob_time += delta
	play_button.position.y = _play_button_rest_y + sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE_PX


func _apply_fonts() -> void:
	PixelFont.apply_label(title_label, TITLE_FONT_SIZE)
	title_label.add_theme_color_override(&"font_color", COLOR_TITLE)
	title_label.add_theme_color_override(&"font_outline_color", COLOR_TITLE_OUTLINE)
	title_label.add_theme_constant_override(&"outline_size", 2)


func _style_play_button() -> void:
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(128.0, 36.0)
	play_button.add_theme_font_override(&"font", PixelFont.font_for_size(BUTTON_FONT_SIZE))
	play_button.add_theme_font_size_override(&"font_size", BUTTON_FONT_SIZE)
	play_button.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08, 1.0))
	play_button.add_theme_color_override(&"font_hover_color", Color(0.12, 0.1, 0.08, 1.0))
	play_button.add_theme_color_override(&"font_pressed_color", Color(0.12, 0.1, 0.08, 1.0))
	play_button.add_theme_stylebox_override(&"normal", _make_button_style(COLOR_BUTTON_FILL))
	play_button.add_theme_stylebox_override(&"hover", _make_button_style(COLOR_BUTTON_HOVER))
	play_button.add_theme_stylebox_override(&"pressed", _make_button_style(COLOR_BUTTON_PRESSED))
	play_button.add_theme_stylebox_override(&"focus", _make_button_style(COLOR_BUTTON_HOVER))


func _make_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = COLOR_BUTTON_BORDER
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _on_play_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	play_button.disabled = true
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
	play_button.disabled = false
	_bob_time = 0.0
