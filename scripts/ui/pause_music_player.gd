extends PanelContainer
## Compact music player in the pause menu right pane.

const TRANSPORT_BUTTON_SIZE := Vector2(28, 24)

@onready var track_name_label: Label = $MusicContent/TrackNameLabel
@onready var rewind_button: Button = $MusicContent/ControlsRow/RewindButton
@onready var play_pause_button: Button = $MusicContent/ControlsRow/PlayPauseButton
@onready var skip_button: Button = $MusicContent/ControlsRow/SkipButton
@onready var play_glyph: Control = $MusicContent/ControlsRow/PlayPauseButton/PlayGlyph
@onready var pause_glyph: Control = $MusicContent/ControlsRow/PlayPauseButton/PauseGlyph
@onready var rewind_glyph: Control = $MusicContent/ControlsRow/RewindButton/RewindGlyph
@onready var skip_glyph: Control = $MusicContent/ControlsRow/SkipButton/SkipGlyph


func _ready() -> void:
	rewind_button.pressed.connect(_on_rewind_pressed)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	SfxManager.music_track_changed.connect(_on_music_track_changed)
	UiTheme.apply_menu_panel(self)
	_apply_fonts()
	_style_transport_button(rewind_button)
	_style_transport_button(play_pause_button)
	_style_transport_button(skip_button)
	refresh()


func refresh() -> void:
	track_name_label.text = SfxManager.get_current_music_display_name()
	var controls_enabled := SfxManager.is_music_enabled() and not SfxManager.get_music_tracks().is_empty()
	rewind_button.disabled = not controls_enabled
	play_pause_button.disabled = not controls_enabled
	skip_button.disabled = not controls_enabled
	var label_color := UiTheme.COLOR_LABEL if controls_enabled else UiTheme.COLOR_DISABLED
	track_name_label.add_theme_color_override(&"font_color", label_color)
	_set_glyph_disabled(rewind_glyph, not controls_enabled)
	_set_glyph_disabled(play_glyph, not controls_enabled)
	_set_glyph_disabled(pause_glyph, not controls_enabled)
	_set_glyph_disabled(skip_glyph, not controls_enabled)
	_refresh_play_pause_glyph()


func _refresh_play_pause_glyph() -> void:
	var show_play := SfxManager.should_show_play_icon()
	play_glyph.visible = show_play
	pause_glyph.visible = not show_play


func _on_rewind_pressed() -> void:
	SfxManager.previous_music_track()
	EventBus.ui_panel_toggled.emit("pause", true)
	refresh()


func _on_play_pause_pressed() -> void:
	SfxManager.toggle_music_playback()
	EventBus.ui_panel_toggled.emit("pause", true)
	refresh()


func _on_skip_pressed() -> void:
	SfxManager.skip_music_track()
	EventBus.ui_panel_toggled.emit("pause", true)
	refresh()


func _on_music_track_changed(_path: String) -> void:
	refresh()


func _set_glyph_disabled(glyph: Control, is_disabled: bool) -> void:
	glyph.set("disabled", is_disabled)


func _apply_fonts() -> void:
	PixelFont.apply_label(track_name_label, 8)
	UiTheme.apply_body_label(track_name_label)


func _style_transport_button(button: Button) -> void:
	button.text = ""
	button.custom_minimum_size = TRANSPORT_BUTTON_SIZE
	UiTheme.apply_transport_button(button)
