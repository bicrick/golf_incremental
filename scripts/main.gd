extends Node
## Root scene — title screen first, Play reveals range view and HUD.

@onready var range_view: Node3D = $RangeView
@onready var ui: CanvasLayer = $UI
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var hud: Control = $UI/UIRoot/HUD
@onready var icon_bar: Control = $UI/UIRoot/IconBar
@onready var settings_panel: Control = $SettingsLayer/SettingsPanel


func _ready() -> void:
	CursorManager.apply_default_cursors()
	range_view.visible = false
	ui.visible = false
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
	_set_gameplay_ui_visible(true)


func _on_ui_panel_toggled(panel_id: String, is_open: bool) -> void:
	if panel_id not in ["upgrades", "settings"]:
		return
	if ui.visible:
		range_view.visible = not is_open
		_set_gameplay_ui_visible(not is_open)


func _on_wipe_confirmed() -> void:
	SaveManager.wipe_character()


func _set_gameplay_ui_visible(visible: bool) -> void:
	hud.visible = visible
	icon_bar.visible = visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("reload_game"):
		return
	if not range_view.visible:
		return
	get_viewport().set_input_as_handled()
	SaveManager.reset_and_reload()
