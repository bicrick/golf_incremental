extends Control
## Full-screen settings view — audio toggles and character wipe.

signal wipe_confirmed

const COLOR_TITLE := Color(1.0, 0.92, 0.45, 1.0)
const COLOR_LABEL := Color(0.92, 0.88, 0.78, 1.0)
const COLOR_DANGER_FILL := Color(0.72, 0.32, 0.28, 1.0)
const COLOR_DANGER_BORDER := Color(0.45, 0.12, 0.1, 1.0)
const COLOR_DANGER_HOVER := Color(0.82, 0.38, 0.32, 1.0)

@onready var back_button: Button = $Content/Header/BackButton
@onready var title_label: Label = $Content/Header/Title
@onready var sfx_toggle: CheckButton = $Content/Body/SfxRow/SfxToggle
@onready var music_toggle: CheckButton = $Content/Body/MusicRow/MusicToggle
@onready var sfx_volume_slider: Control = $Content/Body/SfxVolumeRow/SfxVolumeSlider
@onready var music_volume_slider: Control = $Content/Body/MusicVolumeRow/MusicVolumeSlider
@onready var wipe_button: Button = $Content/Body/WipeButton
@onready var wipe_dialog: ConfirmationDialog = $WipeDialog

var _is_open := false


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	wipe_button.pressed.connect(_on_wipe_pressed)
	wipe_dialog.confirmed.connect(_on_wipe_dialog_confirmed)
	_apply_fonts()
	_style_back_button()
	_style_toggle(sfx_toggle)
	_style_toggle(music_toggle)
	_style_wipe_button()
	_sync_controls_from_manager()


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_close_other_panels()
	_is_open = true
	visible = true
	_sync_controls_from_manager()
	_notify_icon_bar(true)
	EventBus.ui_panel_toggled.emit("settings", true)


func close() -> void:
	_is_open = false
	visible = false
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("settings", false)


func _sync_controls_from_manager() -> void:
	sfx_toggle.set_block_signals(true)
	music_toggle.set_block_signals(true)
	sfx_toggle.button_pressed = SfxManager.is_sfx_enabled()
	music_toggle.button_pressed = SfxManager.is_music_enabled()
	sfx_toggle.set_block_signals(false)
	music_toggle.set_block_signals(false)

	sfx_volume_slider.set_block_signals(true)
	music_volume_slider.set_block_signals(true)
	sfx_volume_slider.value = SfxManager.get_sfx_volume()
	music_volume_slider.value = SfxManager.get_music_volume()
	sfx_volume_slider.set_block_signals(false)
	music_volume_slider.set_block_signals(false)


func _on_sfx_volume_changed(volume: float) -> void:
	SfxManager.set_sfx_volume(volume)


func _on_music_volume_changed(volume: float) -> void:
	SfxManager.set_music_volume(volume)


func _on_sfx_toggled(enabled: bool) -> void:
	SfxManager.set_sfx_enabled(enabled)


func _on_music_toggled(enabled: bool) -> void:
	SfxManager.set_music_enabled(enabled)


func _on_wipe_pressed() -> void:
	wipe_dialog.popup_centered()


func _on_wipe_dialog_confirmed() -> void:
	close()
	wipe_confirmed.emit()


func _close_other_panels() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var upgrade_panel := main.get_node_or_null("UI/UIRoot/UpgradePanel")
	if upgrade_panel and upgrade_panel.has_method("is_open") and upgrade_panel.is_open():
		upgrade_panel.close()


func _notify_icon_bar(is_open: bool) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var icon_bar := main.get_node_or_null("UI/UIRoot/IconBar")
	if icon_bar and icon_bar.has_method("set_settings_open"):
		icon_bar.set_settings_open(is_open)


func _apply_fonts() -> void:
	PixelFont.apply_label(title_label, 10)
	PixelFont.apply_label($Content/Body/SfxRow/SfxLabel, 8)
	PixelFont.apply_label($Content/Body/MusicRow/MusicLabel, 8)
	PixelFont.apply_label($Content/Body/SfxVolumeRow/SfxVolumeLabel, 8)
	PixelFont.apply_label($Content/Body/MusicVolumeRow/MusicVolumeLabel, 8)
	$Content/Body/SfxRow/SfxLabel.add_theme_color_override(&"font_color", COLOR_LABEL)
	$Content/Body/MusicRow/MusicLabel.add_theme_color_override(&"font_color", COLOR_LABEL)
	$Content/Body/SfxVolumeRow/SfxVolumeLabel.add_theme_color_override(&"font_color", COLOR_LABEL)
	$Content/Body/MusicVolumeRow/MusicVolumeLabel.add_theme_color_override(&"font_color", COLOR_LABEL)
	title_label.add_theme_color_override(&"font_color", COLOR_TITLE)


func _style_back_button() -> void:
	back_button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	back_button.add_theme_font_size_override(&"font_size", 8)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.72, 0.48, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.18, 0.52, 0.48, 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	back_button.add_theme_stylebox_override(&"normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.92, 0.82, 0.58, 0.95)
	back_button.add_theme_stylebox_override(&"hover", hover)
	back_button.add_theme_stylebox_override(&"pressed", hover)


func _style_toggle(toggle: CheckButton) -> void:
	toggle.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	toggle.add_theme_font_size_override(&"font_size", 8)


func _style_wipe_button() -> void:
	wipe_button.text = "Wipe Character"
	wipe_button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	wipe_button.add_theme_font_size_override(&"font_size", 8)
	wipe_button.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.9, 1.0))
	wipe_button.add_theme_stylebox_override(&"normal", _make_button_style(COLOR_DANGER_FILL, COLOR_DANGER_BORDER))
	wipe_button.add_theme_stylebox_override(&"hover", _make_button_style(COLOR_DANGER_HOVER, COLOR_DANGER_BORDER))
	wipe_button.add_theme_stylebox_override(&"pressed", _make_button_style(COLOR_DANGER_FILL.darkened(0.12), COLOR_DANGER_BORDER))
	wipe_dialog.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	wipe_dialog.add_theme_font_size_override(&"font_size", 8)
	wipe_dialog.dialog_text = (
		"Delete all progress?\n\n"
		+ "Currency, upgrades, and stats will be wiped.\n"
		+ "Audio settings are kept."
	)
	wipe_dialog.ok_button_text = "Wipe"
	wipe_dialog.cancel_button_text = "Cancel"


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
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
