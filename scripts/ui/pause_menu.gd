extends Control
## Full-screen pause menu — opened with Escape during gameplay.

signal settings_requested
signal exit_requested

const COLOR_TITLE := Color(1.0, 0.92, 0.45, 1.0)
const COLOR_LABEL := Color(0.92, 0.88, 0.78, 1.0)
const COLOR_MENU_FILL := Color(0.82, 0.72, 0.48, 0.92)
const COLOR_MENU_BORDER := Color(0.18, 0.52, 0.48, 1.0)
const COLOR_MENU_HOVER := Color(0.92, 0.82, 0.58, 0.95)
const COLOR_EXIT_FILL := Color(0.72, 0.32, 0.28, 1.0)
const COLOR_EXIT_BORDER := Color(0.45, 0.12, 0.1, 1.0)
const COLOR_EXIT_HOVER := Color(0.82, 0.38, 0.32, 1.0)
const DEBUG_MONEY_AMOUNT := 1_000_000.0

@onready var title_label: Label = $Content/Center/MainRow/LeftPane/Title
@onready var music_player: PanelContainer = $Content/Center/MainRow/RightPane/MusicSection
@onready var resume_button: Button = $Content/Center/MainRow/LeftPane/ResumeButton
@onready var settings_button: Button = $Content/Center/MainRow/LeftPane/SettingsButton
@onready var exit_button: Button = $Content/Center/MainRow/LeftPane/ExitButton
@onready var debug_label: Label = $Content/Center/MainRow/LeftPane/DebugSection/DebugLabel
@onready var add_money_button: Button = $Content/Center/MainRow/LeftPane/DebugSection/AddMoneyButton
@onready var desert_mode_toggle: CheckButton = $Content/Center/MainRow/LeftPane/DebugSection/DesertModeToggle

var _is_open := false


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	add_money_button.pressed.connect(_on_add_money_pressed)
	desert_mode_toggle.toggled.connect(_on_desert_mode_toggled)
	_apply_fonts()
	_style_menu_button(resume_button)
	_style_menu_button(settings_button)
	_style_exit_button(exit_button)
	_style_menu_button(add_money_button)
	_style_menu_button(desert_mode_toggle)


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
	if music_player.has_method("refresh"):
		music_player.refresh()
	_sync_desert_mode_toggle()
	EventBus.ui_panel_toggled.emit("pause", true)


func close() -> void:
	_is_open = false
	visible = false
	EventBus.ui_panel_toggled.emit("pause", false)


func _on_settings_pressed() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var panel: Control = main.get_node_or_null("SettingsLayer/SettingsPanel")
	if panel == null:
		return
	visible = false
	if panel.has_method("open_from_pause"):
		panel.open_from_pause()
	elif panel.has_method("open"):
		panel.open()


func _on_exit_pressed() -> void:
	exit_requested.emit()
	get_tree().quit()


func _on_add_money_pressed() -> void:
	GameState.add_currency(DEBUG_MONEY_AMOUNT)


func _on_desert_mode_toggled(pressed: bool) -> void:
	var range_view := _range_view()
	if range_view == null or not range_view.has_method(&"set_desert_mode"):
		return
	range_view.set_desert_mode(pressed)


func _sync_desert_mode_toggle() -> void:
	var range_view := _range_view()
	if range_view == null or not range_view.has_method(&"is_desert_mode"):
		return
	var enabled: bool = range_view.is_desert_mode()
	if desert_mode_toggle.button_pressed != enabled:
		desert_mode_toggle.set_pressed_no_signal(enabled)


func _range_view() -> Node:
	# PauseMenu lives under Main/SettingsLayer — walk up so headless tests work too.
	var node: Node = self
	while node != null:
		var range_view := node.get_node_or_null("RangeView")
		if range_view != null:
			return range_view
		node = node.get_parent()
	return null


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
	PixelFont.apply_label(title_label, 12)
	PixelFont.apply_label(debug_label, 8)
	title_label.add_theme_color_override(&"font_color", COLOR_TITLE)
	debug_label.add_theme_color_override(&"font_color", COLOR_LABEL)


func _style_menu_button(button: Button) -> void:
	button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	button.add_theme_font_size_override(&"font_size", 8)
	button.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.08, 1))
	button.add_theme_stylebox_override(&"normal", _make_button_style(COLOR_MENU_FILL, COLOR_MENU_BORDER))
	button.add_theme_stylebox_override(&"hover", _make_button_style(COLOR_MENU_HOVER, COLOR_MENU_BORDER))
	button.add_theme_stylebox_override(&"pressed", _make_button_style(COLOR_MENU_FILL.darkened(0.08), COLOR_MENU_BORDER))


func _style_exit_button(button: Button) -> void:
	button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	button.add_theme_font_size_override(&"font_size", 8)
	button.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.9, 1.0))
	button.add_theme_stylebox_override(&"normal", _make_button_style(COLOR_EXIT_FILL, COLOR_EXIT_BORDER))
	button.add_theme_stylebox_override(&"hover", _make_button_style(COLOR_EXIT_HOVER, COLOR_EXIT_BORDER))
	button.add_theme_stylebox_override(&"pressed", _make_button_style(COLOR_EXIT_FILL.darkened(0.12), COLOR_EXIT_BORDER))


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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
