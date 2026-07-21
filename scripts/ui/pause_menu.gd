extends Control
## Full-screen pause menu — opened with Escape during gameplay.

signal settings_requested
signal exit_requested

const DEBUG_MONEY_AMOUNT := 1_000_000.0

@onready var title_label: Label = $Content/Center/MainRow/LeftPane/Title
@onready var music_player: PanelContainer = $Content/Center/MainRow/RightPane/MusicSection
@onready var resume_button: Button = $Content/Center/MainRow/LeftPane/ResumeButton
@onready var settings_button: Button = $Content/Center/MainRow/LeftPane/SettingsButton
@onready var exit_button: Button = $Content/Center/MainRow/LeftPane/ExitButton
@onready var debug_label: Label = $Content/Center/MainRow/LeftPane/DebugSection/DebugLabel
@onready var add_money_button: Button = $Content/Center/MainRow/LeftPane/DebugSection/AddMoneyButton

var _is_open := false


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	add_money_button.pressed.connect(_on_add_money_pressed)
	_apply_fonts()
	UiTheme.apply_primary_button(resume_button)
	UiTheme.apply_primary_button(settings_button)
	UiTheme.apply_danger_button(exit_button)
	UiTheme.apply_primary_button(add_money_button)


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
	UiTheme.apply_title_label(title_label)
	UiTheme.apply_body_label(debug_label)
