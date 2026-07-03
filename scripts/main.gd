extends Node
## Root scene — title screen first, Play reveals range view and HUD.

@onready var range_view: Node3D = $RangeView
@onready var ui: CanvasLayer = $UI
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var swing_line_layer: CanvasLayer = $SwingLineLayer
@onready var swing_line_viewport: Control = $SwingLineLayer/SwingLineViewport
@onready var hud: Control = $UI/UIRoot/HUD
@onready var icon_bar: Control = $UI/UIRoot/IconBar
@onready var upgrade_panel: Control = $UI/UIRoot/UpgradePanel
@onready var shop_panel: Control = $UI/UIRoot/ShopPanel
@onready var settings_panel: Control = $SettingsLayer/SettingsPanel
@onready var pause_menu: Control = $SettingsLayer/PauseMenu


func _ready() -> void:
	CursorManager.apply_default_cursors()
	range_view.visible = false
	ui.visible = false
	swing_line_layer.visible = false
	title_screen.play_pressed.connect(_on_play_pressed)
	settings_panel.wipe_confirmed.connect(_on_wipe_confirmed)
	EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	SfxManager.play_title_bgm()


func _on_play_pressed() -> void:
	title_screen.visible = false
	if title_screen.has_method("reset_for_show"):
		title_screen.reset_for_show()
	range_view.visible = true
	ui.visible = true
	swing_line_layer.visible = true
	_set_gameplay_ui_visible(true)
	if swing_line_viewport.has_method(&"bind_range_camera"):
		swing_line_viewport.bind_range_camera()


func _on_ui_panel_toggled(panel_id: String, is_open: bool) -> void:
	if panel_id not in ["upgrades", "settings", "pause", "shop"]:
		return
	if not ui.visible:
		return
	var overlay_open := _is_overlay_panel_open()
	range_view.visible = not overlay_open
	_set_gameplay_ui_visible(not overlay_open)


func _is_overlay_panel_open() -> bool:
	if pause_menu.has_method("is_open") and pause_menu.is_open():
		return true
	if settings_panel.has_method("is_open") and settings_panel.is_open():
		return true
	if upgrade_panel.has_method("is_open") and upgrade_panel.is_open():
		return true
	if shop_panel.has_method("is_open") and shop_panel.is_open():
		return true
	return false


func _on_wipe_confirmed() -> void:
	SaveManager.wipe_character()


func _set_gameplay_ui_visible(visible: bool) -> void:
	hud.visible = visible
	swing_line_layer.visible = visible
	icon_bar.visible = visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_game"):
		if range_view.visible:
			get_viewport().set_input_as_handled()
			SaveManager.reset_and_reload()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _is_in_gameplay():
		return
	get_viewport().set_input_as_handled()
	_handle_escape()


func _is_in_gameplay() -> bool:
	return ui.visible and range_view.visible or _is_overlay_panel_open()


func _handle_escape() -> void:
	if settings_panel.has_method("is_open") and settings_panel.is_open():
		if settings_panel.has_method("close_to_pause"):
			settings_panel.close_to_pause()
		else:
			settings_panel.close()
		return
	if shop_panel.has_method("is_open") and shop_panel.is_open():
		shop_panel.close()
		return
	if upgrade_panel.has_method("is_open") and upgrade_panel.is_open():
		upgrade_panel.close()
		return
	if pause_menu.has_method("is_open") and pause_menu.is_open():
		pause_menu.close()
		return
	if pause_menu.has_method("open"):
		pause_menu.open()
