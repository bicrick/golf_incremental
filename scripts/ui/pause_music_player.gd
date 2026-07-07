extends VBoxContainer
## Compact music player shown at the top of the pause menu.

const COLOR_LABEL := Color(0.92, 0.88, 0.78, 1.0)
const COLOR_MENU_FILL := Color(0.82, 0.72, 0.48, 0.92)
const COLOR_MENU_BORDER := Color(0.18, 0.52, 0.48, 1.0)
const COLOR_MENU_HOVER := Color(0.92, 0.82, 0.58, 0.95)
const COLOR_DISABLED := Color(0.55, 0.52, 0.48, 1.0)

@onready var track_name_label: Label = $TrackRow/TrackNameLabel
@onready var rewind_button: Button = $ControlsRow/RewindButton
@onready var stop_button: Button = $ControlsRow/StopButton
@onready var skip_button: Button = $ControlsRow/SkipButton


func _ready() -> void:
	rewind_button.pressed.connect(_on_rewind_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	SfxManager.music_track_changed.connect(_on_music_track_changed)
	_apply_fonts()
	_style_transport_button(rewind_button)
	_style_transport_button(stop_button)
	_style_transport_button(skip_button)
	refresh()


func refresh() -> void:
	track_name_label.text = SfxManager.get_current_music_display_name()
	var controls_enabled := SfxManager.is_music_enabled() and not SfxManager.get_music_tracks().is_empty()
	rewind_button.disabled = not controls_enabled
	stop_button.disabled = not controls_enabled
	skip_button.disabled = not controls_enabled
	var label_color := COLOR_LABEL if controls_enabled else COLOR_DISABLED
	track_name_label.add_theme_color_override(&"font_color", label_color)


func _on_rewind_pressed() -> void:
	SfxManager.previous_music_track()
	EventBus.ui_panel_toggled.emit("pause", true)


func _on_stop_pressed() -> void:
	SfxManager.stop_music()
	refresh()
	EventBus.ui_panel_toggled.emit("pause", true)


func _on_skip_pressed() -> void:
	SfxManager.skip_music_track()
	EventBus.ui_panel_toggled.emit("pause", true)


func _on_music_track_changed(_path: String) -> void:
	refresh()


func _apply_fonts() -> void:
	PixelFont.apply_label(track_name_label, 8)
	track_name_label.add_theme_color_override(&"font_color", COLOR_LABEL)


func _style_transport_button(button: Button) -> void:
	button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	button.add_theme_font_size_override(&"font_size", 8)
	button.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08, 1))
	button.add_theme_color_override(&"font_disabled_color", COLOR_DISABLED)
	button.add_theme_stylebox_override(&"normal", _make_button_style(COLOR_MENU_FILL, COLOR_MENU_BORDER))
	button.add_theme_stylebox_override(&"hover", _make_button_style(COLOR_MENU_HOVER, COLOR_MENU_BORDER))
	button.add_theme_stylebox_override(
		&"pressed",
		_make_button_style(COLOR_MENU_FILL.darkened(0.08), COLOR_MENU_BORDER)
	)
	button.add_theme_stylebox_override(
		&"disabled",
		_make_button_style(COLOR_MENU_FILL.darkened(0.18), COLOR_MENU_BORDER.darkened(0.2))
	)


func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
