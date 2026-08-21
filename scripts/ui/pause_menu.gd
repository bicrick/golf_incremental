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
	_apply_exit_visibility()
	apply_viewport_layout()


func apply_viewport_layout() -> void:
	var main_row := get_node_or_null("Content/Center/MainRow") as BoxContainer
	var divider := get_node_or_null("Content/Center/MainRow/Divider") as Control
	var left := get_node_or_null("Content/Center/MainRow/LeftPane") as Control
	var right := get_node_or_null("Content/Center/MainRow/RightPane") as Control
	if main_row == null or left == null or right == null:
		return
	var portrait := UiLayout.is_portrait(get_viewport())
	## Swap HBox ↔ VBox for portrait so the music pane stacks under buttons.
	var want_vertical := portrait
	var is_vertical := main_row is VBoxContainer
	if want_vertical == is_vertical:
		if divider:
			divider.visible = not portrait
		_apply_exit_visibility()
		return
	var parent := main_row.get_parent()
	var children := main_row.get_children()
	var new_row: BoxContainer = VBoxContainer.new() if want_vertical else HBoxContainer.new()
	new_row.name = "MainRow"
	new_row.add_theme_constant_override(&"separation", 20 if not want_vertical else 12)
	new_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(new_row)
	parent.move_child(new_row, main_row.get_index())
	for child in children:
		main_row.remove_child(child)
		new_row.add_child(child)
	main_row.queue_free()
	if divider:
		divider.visible = not portrait
	## Shrink button min widths on narrow screens.
	var btn_w := 140.0 if portrait else 160.0
	for btn in [resume_button, settings_button, exit_button, add_money_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(btn_w, 0)
	if right != null:
		right.custom_minimum_size = Vector2(168.0 if not portrait else 0.0, 0)
	_apply_exit_visibility()


func should_show_exit_button() -> bool:
	## Web / mobile / touch have no process to quit; hide Exit there.
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return false
	if UiLayout.is_mobile_touch():
		return false
	return true


func _apply_exit_visibility() -> void:
	if exit_button != null:
		exit_button.visible = should_show_exit_button()


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
	apply_viewport_layout()
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
	UiTheme.apply_title_on_dark(title_label)
	UiTheme.apply_body_on_dark(debug_label)
