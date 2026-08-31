extends CanvasLayer
## Range Rat title screen — parallax cloud sky; Play crossfades into the range.

const WebAudioUnlockScript = preload("res://scripts/audio/web_audio_unlock.gd")

signal play_pressed
## Emitted when the fade begins so Main can reveal the range underneath.
signal play_transition_started

const LOGO_DISPLAY_SIZE := Vector2(420.0, 132.0)
const PROMPT_FONT_SIZE := 8
const FADE_DURATION_SEC := 0.55
const LOAD_FADE_DURATION_SEC := 0.55
const PROMPT_INTRO_FADE_SEC := 0.35

const PROMPT_FADE_MIN_ALPHA := 0.25
const PROMPT_FADE_MAX_ALPHA := 1.0
const PROMPT_FADE_HALF_CYCLE_SEC := 0.9
const TITLE_READY_JS := "window.__rangeRatTitleReady && window.__rangeRatTitleReady();"

@onready var sky_bg: Control = $SkyBg
@onready var load_fade: ColorRect = $LoadFade
@onready var overlay: Control = $Overlay
@onready var title_logo: TextureRect = $Overlay/Center/VBox/TitleLogo
@onready var press_space_label: Label = $Overlay/Center/VBox/PressSpace

var _transitioning := false
var _intro_active := true
var _prompt_fade_tween: Tween


func _ready() -> void:
	_setup_title_logo()
	_setup_press_space_label()
	press_space_label.gui_input.connect(_on_press_space_gui_input)
	if overlay != null and not overlay.gui_input.is_connected(_on_overlay_gui_input):
		overlay.gui_input.connect(_on_overlay_gui_input)
	if title_logo != null and not title_logo.gui_input.is_connected(_on_title_logo_gui_input):
		title_logo.gui_input.connect(_on_title_logo_gui_input)
	if sky_bg.has_method(&"apply_cycle_time"):
		sky_bg.apply_cycle_time(60.0)
	apply_viewport_layout()
	_prepare_load_intro()
	SfxManager.play_title_bgm()
	call_deferred(&"_begin_load_intro")


func is_transitioning() -> bool:
	return _transitioning


func get_fade_duration() -> float:
	return FADE_DURATION_SEC


func sync_atmosphere_from_range(range_view: Node3D) -> void:
	if sky_bg == null or not sky_bg.has_method(&"apply_cycle_time"):
		return
	var cycle_time := 60.0
	var cycle := range_view.get_node_or_null("DayNightCycle") if range_view else null
	if cycle != null and cycle.has_method(&"cycle_elapsed"):
		cycle_time = cycle.cycle_elapsed()
	sky_bg.apply_cycle_time(cycle_time)


func apply_viewport_layout() -> void:
	if title_logo == null or press_space_label == null:
		return
	var size := UiLayout.viewport_size(get_viewport())
	var max_w := mini(LOGO_DISPLAY_SIZE.x, size.x * 0.9)
	var scale := max_w / LOGO_DISPLAY_SIZE.x
	title_logo.custom_minimum_size = LOGO_DISPLAY_SIZE * scale
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_logo_input_mode()
	if UiLayout.is_mobile_touch():
		press_space_label.text = "Tap to play"
	else:
		press_space_label.text = "Click / Space"


func _prepare_load_intro() -> void:
	_intro_active = true
	_stop_prompt_fade()
	if press_space_label != null:
		press_space_label.modulate.a = 0.0
	if load_fade != null:
		load_fade.visible = true
		load_fade.modulate.a = 1.0
	if sky_bg != null:
		sky_bg.modulate.a = 0.0


func _begin_load_intro() -> void:
	apply_viewport_layout()
	_notify_html_title_ready()
	if _is_headless():
		_finish_load_intro()
		return
	var tween := create_tween().set_parallel(true)
	if sky_bg != null:
		tween.tween_property(sky_bg, "modulate:a", 1.0, LOAD_FADE_DURATION_SEC).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
	if load_fade != null:
		tween.tween_property(load_fade, "modulate:a", 0.0, LOAD_FADE_DURATION_SEC).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_finish_load_intro)


func _finish_load_intro() -> void:
	if sky_bg != null:
		sky_bg.modulate.a = 1.0
	if load_fade != null:
		load_fade.modulate.a = 0.0
		load_fade.visible = false
	_intro_active = false
	if _transitioning:
		return
	_fade_in_prompt()


func _fade_in_prompt() -> void:
	if press_space_label == null:
		return
	press_space_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(press_space_label, "modulate:a", PROMPT_FADE_MAX_ALPHA, PROMPT_INTRO_FADE_SEC).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_prompt_fade)


func _notify_html_title_ready() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(TITLE_READY_JS, true)


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _input(event: InputEvent) -> void:
	# Resume only — opening theme already started on load. Web autoplay unlock
	# must not pick a different track.
	if WebAudioUnlockScript.is_unlock_gesture(event):
		SfxManager.play_title_bgm()
	if not _transitioning:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _intro_active:
		return
	if _transitioning:
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if _is_settings_open():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed or key.keycode != KEY_SPACE:
			return
		get_viewport().set_input_as_handled()
		_on_play_pressed()
		return
	## Empty tap / click starts the game. Mobile logo tap opens settings instead.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			get_viewport().set_input_as_handled()
			_on_play_pressed()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_on_play_pressed()


func logo_tap_opens_settings() -> bool:
	## Branding tap is the mobile settings path. Desktop clicks must start play.
	return UiLayout.is_mobile_touch()


func _apply_logo_input_mode() -> void:
	if title_logo == null:
		return
	if logo_tap_opens_settings():
		title_logo.mouse_filter = Control.MOUSE_FILTER_STOP
		title_logo.mouse_default_cursor_shape = CursorManager.SELECTABLE_CURSOR_SHAPE
	else:
		title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_logo.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _setup_title_logo() -> void:
	title_logo.custom_minimum_size = LOGO_DISPLAY_SIZE
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_logo_input_mode()


func _setup_press_space_label() -> void:
	press_space_label.text = "Click / Space"
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


func _on_overlay_gui_input(event: InputEvent) -> void:
	_on_press_space_gui_input(event)


func _on_title_logo_gui_input(event: InputEvent) -> void:
	if _intro_active or _transitioning:
		return
	if not _is_primary_press(event):
		return
	if not logo_tap_opens_settings():
		title_logo.accept_event()
		_on_play_pressed()
		return
	title_logo.accept_event()
	open_settings()


func open_settings() -> void:
	if _intro_active or _transitioning:
		return
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var panel: Control = main.get_node_or_null("SettingsLayer/SettingsPanel")
	if panel == null:
		return
	if panel.has_method("is_open") and panel.is_open():
		return
	if panel.has_method("open"):
		panel.open()


func _is_settings_open() -> bool:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return false
	var panel: Control = main.get_node_or_null("SettingsLayer/SettingsPanel")
	return panel != null and panel.has_method("is_open") and panel.is_open()


func _is_primary_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _on_press_space_gui_input(event: InputEvent) -> void:
	if _intro_active or _transitioning or _is_settings_open():
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_on_play_pressed()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_play_pressed()


func _on_play_pressed() -> void:
	if _intro_active or _transitioning:
		return
	_transitioning = true
	_stop_prompt_fade()
	SfxManager.play_start()
	SfxManager.play_title_bgm()
	SfxManager.start_bgm()
	play_transition_started.emit()
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
	_intro_active = false
	sky_bg.modulate.a = 1.0
	overlay.modulate.a = 1.0
	if load_fade != null:
		load_fade.modulate.a = 0.0
		load_fade.visible = false
	press_space_label.modulate.a = PROMPT_FADE_MAX_ALPHA
	apply_viewport_layout()
	_start_prompt_fade()
