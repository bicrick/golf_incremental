extends Control
## Full-screen settings view — audio toggles and character reset.

signal wipe_confirmed

@onready var header_bar: PanelContainer = $Content/Header
@onready var back_button: Button = $Content/Header/Row/BackButton
@onready var title_label: Label = $Content/Header/Row/Title
@onready var sfx_toggle: CheckButton = $Content/Body/SfxRow/SfxToggle
@onready var music_toggle: CheckButton = $Content/Body/MusicRow/MusicToggle
@onready var sfx_volume_slider: Control = $Content/Body/SfxVolumeRow/SfxVolumeSlider
@onready var music_volume_slider: Control = $Content/Body/MusicVolumeRow/MusicVolumeSlider
@onready var frame_graph_toggle: CheckButton = $Content/Body/FrameGraphRow/FrameGraphToggle
@onready var reset_button: Button = $Content/Body/ResetButton
@onready var reset_dialog: ConfirmationDialog = $ResetDialog

var _is_open := false
var _opened_from_pause := false


func _ready() -> void:
	visible = false
	back_button.pressed.connect(_on_back_pressed)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	music_toggle.toggled.connect(_on_music_toggled)
	frame_graph_toggle.toggled.connect(_on_frame_graph_toggled)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	reset_button.pressed.connect(_on_reset_pressed)
	reset_dialog.confirmed.connect(_on_reset_dialog_confirmed)
	reset_dialog.get_ok_button().mouse_default_cursor_shape = CursorManager.SELECTABLE_CURSOR_SHAPE
	reset_dialog.get_cancel_button().mouse_default_cursor_shape = CursorManager.SELECTABLE_CURSOR_SHAPE
	_apply_fonts()
	UiTheme.apply_header_bar(header_bar)
	UiTheme.apply_compact_primary_button(back_button)
	_style_toggle(sfx_toggle)
	_style_toggle(music_toggle)
	_style_toggle(frame_graph_toggle)
	_style_reset_button()
	_sync_controls_from_manager()


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_opened_from_pause = false
	_open_panel()


func open_from_pause() -> void:
	_opened_from_pause = true
	_open_panel()


func _open_panel() -> void:
	_close_other_panels()
	_is_open = true
	visible = true
	_sync_controls_from_manager()
	EventBus.ui_panel_toggled.emit("settings", true)


func close() -> void:
	_opened_from_pause = false
	_is_open = false
	visible = false
	EventBus.ui_panel_toggled.emit("settings", false)


func close_to_pause() -> void:
	_opened_from_pause = false
	_is_open = false
	visible = false
	EventBus.ui_panel_toggled.emit("settings", false)
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var pause_menu: Control = main.get_node_or_null("SettingsLayer/PauseMenu")
	if pause_menu and pause_menu.has_method("open"):
		pause_menu.open()


func _on_back_pressed() -> void:
	if _opened_from_pause:
		close_to_pause()
	else:
		close()


func _sync_controls_from_manager() -> void:
	sfx_toggle.set_block_signals(true)
	music_toggle.set_block_signals(true)
	sfx_toggle.button_pressed = SfxManager.is_sfx_enabled()
	music_toggle.button_pressed = SfxManager.is_music_enabled()
	sfx_toggle.text = "On" if SfxManager.is_sfx_enabled() else "Off"
	music_toggle.text = "On" if SfxManager.is_music_enabled() else "Off"
	sfx_toggle.set_block_signals(false)
	music_toggle.set_block_signals(false)

	sfx_volume_slider.set_block_signals(true)
	music_volume_slider.set_block_signals(true)
	sfx_volume_slider.value = SfxManager.get_sfx_volume()
	music_volume_slider.value = SfxManager.get_music_volume()
	sfx_volume_slider.set_block_signals(false)
	music_volume_slider.set_block_signals(false)

	frame_graph_toggle.set_block_signals(true)
	frame_graph_toggle.button_pressed = SaveManager.frame_graph_enabled
	frame_graph_toggle.text = "On" if SaveManager.frame_graph_enabled else "Off"
	frame_graph_toggle.set_block_signals(false)


func _on_frame_graph_toggled(enabled: bool) -> void:
	SaveManager.frame_graph_enabled = enabled
	SaveManager.save_settings()
	frame_graph_toggle.text = "On" if enabled else "Off"
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var overlay := main.get_node_or_null("FrameTimeOverlay")
	if overlay and overlay.has_method("set_enabled"):
		overlay.set_enabled(enabled)


func _on_sfx_volume_changed(volume: float) -> void:
	SfxManager.set_sfx_volume(volume)


func _on_music_volume_changed(volume: float) -> void:
	SfxManager.set_music_volume(volume)


func _on_sfx_toggled(enabled: bool) -> void:
	SfxManager.set_sfx_enabled(enabled)
	sfx_toggle.text = "On" if enabled else "Off"


func _on_music_toggled(enabled: bool) -> void:
	SfxManager.set_music_enabled(enabled)
	music_toggle.text = "On" if enabled else "Off"


func _on_reset_pressed() -> void:
	reset_dialog.popup_centered()


func _on_reset_dialog_confirmed() -> void:
	close()
	wipe_confirmed.emit()


func _close_other_panels() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var ui_root := main.get_node_or_null("UI/UIRoot")
	if ui_root == null:
		return
	for panel_name in ["UpgradePanel"]:
		var panel := ui_root.get_node_or_null(panel_name)
		if panel and panel.has_method("is_open") and panel.is_open():
			panel.close()


func _apply_fonts() -> void:
	PixelFont.apply_label(title_label, 10)
	PixelFont.apply_label($Content/Body/SfxRow/SfxLabel, 8)
	PixelFont.apply_label($Content/Body/MusicRow/MusicLabel, 8)
	PixelFont.apply_label($Content/Body/SfxVolumeRow/SfxVolumeLabel, 8)
	PixelFont.apply_label($Content/Body/MusicVolumeRow/MusicVolumeLabel, 8)
	PixelFont.apply_label($Content/Body/FrameGraphRow/FrameGraphLabel, 8)
	UiTheme.apply_body_label($Content/Body/SfxRow/SfxLabel)
	UiTheme.apply_body_label($Content/Body/MusicRow/MusicLabel)
	UiTheme.apply_body_label($Content/Body/SfxVolumeRow/SfxVolumeLabel)
	UiTheme.apply_body_label($Content/Body/MusicVolumeRow/MusicVolumeLabel)
	UiTheme.apply_body_label($Content/Body/FrameGraphRow/FrameGraphLabel)
	UiTheme.apply_title_label(title_label)


func _style_toggle(toggle: CheckButton) -> void:
	toggle.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	toggle.add_theme_font_size_override(&"font_size", 8)


func _style_reset_button() -> void:
	reset_button.text = "Reset Character"
	UiTheme.apply_danger_button(reset_button)
	reset_dialog.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	reset_dialog.add_theme_font_size_override(&"font_size", 8)
	reset_dialog.dialog_text = (
		"Delete all progress?\n\n"
		+ "Currency, upgrades, and stats will be reset.\n"
		+ "Audio settings are kept."
	)
	reset_dialog.ok_button_text = "Reset"
	reset_dialog.cancel_button_text = "Cancel"
