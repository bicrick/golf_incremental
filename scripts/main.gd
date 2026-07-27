extends Node
## Root scene — title screen first; Play crossfades into the range and HUD.

@onready var range_view: Node3D = $RangeView
@onready var iso_view: Node2D = get_node_or_null("IsoView") as Node2D
@onready var ui: CanvasLayer = $UI
@onready var title_screen: CanvasLayer = $TitleScreen
@onready var gameplay_chrome: Control = $UI/UIRoot/GameplayChrome
@onready var upgrade_panel: Control = $UI/UIRoot/UpgradePanel
@onready var settings_panel: Control = $SettingsLayer/SettingsPanel
@onready var pause_menu: Control = $SettingsLayer/PauseMenu

var _build_view_active := false
var _harvest_view_active := false


func _ready() -> void:
	add_to_group(&"main")
	CursorManager.bind_gameplay(range_view)
	CursorManager.debug_set_harvest_view_ready(_is_harvest_view_ready)
	## Per-event mouse delivery — avoids macOS click batching quirks.
	Input.set_use_accumulated_input(false)
	range_view.visible = false
	if iso_view:
		iso_view.visible = false
		if iso_view.has_method(&"set_mode"):
			iso_view.set_mode(IsoView.Mode.OFF)
		elif iso_view.has_method(&"set_active"):
			iso_view.set_active(false)
	ui.visible = false
	title_screen.play_transition_started.connect(_on_play_transition_started)
	title_screen.play_pressed.connect(_on_play_pressed)
	settings_panel.wipe_confirmed.connect(_on_wipe_confirmed)
	EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	EventBus.phase_changed.connect(_on_phase_changed_view)
	if title_screen.has_method(&"sync_atmosphere_from_range"):
		title_screen.sync_atmosphere_from_range(range_view)
	SfxManager.play_title_bgm()


func _is_harvest_view_ready() -> bool:
	if (
		iso_view != null
		and iso_view.has_method(&"is_harvest_view_ready")
		and iso_view.is_harvest_view_ready()
	):
		return true
	if range_view != null and range_view.has_method(&"is_harvest_view_ready"):
		return range_view.is_harvest_view_ready()
	return false


func _on_phase_changed_view(phase: String) -> void:
	if phase == "harvest":
		set_harvest_view(true)
	elif phase == "strike":
		set_harvest_view(false)


func _on_play_transition_started() -> void:
	## Range + HUD under the title so the cloud fade reads as a soft crossfade.
	_build_view_active = false
	_harvest_view_active = false
	range_view.visible = true
	if iso_view:
		if iso_view.has_method(&"set_mode"):
			iso_view.set_mode(IsoView.Mode.OFF)
		elif iso_view.has_method(&"set_active"):
			iso_view.set_active(false)
		iso_view.visible = false
	ui.visible = true
	_set_gameplay_ui_visible(true)
	_sync_build_button()


func _on_play_pressed() -> void:
	title_screen.visible = false
	if title_screen.has_method("reset_for_show"):
		title_screen.reset_for_show()


func _on_ui_panel_toggled(panel_id: String, is_open: bool) -> void:
	if panel_id not in ["upgrades", "settings", "pause"]:
		return
	if not ui.visible:
		return
	if panel_id == "upgrades" and is_open:
		_sync_upgrade_sky_tint()
	var overlay_open := _is_overlay_panel_open()
	_set_active_world_visible(not overlay_open)
	_set_gameplay_ui_visible(not overlay_open)


func _set_active_world_visible(visible: bool) -> void:
	if _harvest_view_active and iso_view != null:
		range_view.visible = false
		if visible:
			if iso_view.has_method(&"set_mode"):
				iso_view.set_mode(IsoView.Mode.HARVEST)
			else:
				iso_view.visible = true
				if iso_view.has_method(&"set_active"):
					iso_view.set_active(true)
		else:
			if iso_view.has_method(&"set_mode"):
				iso_view.set_mode(IsoView.Mode.OFF)
			elif iso_view.has_method(&"set_active"):
				iso_view.set_active(false)
			iso_view.visible = false
		CursorManager.refresh()
		return
	if _build_view_active and iso_view != null:
		iso_view.visible = visible
		if iso_view.has_method(&"set_active"):
			iso_view.set_active(visible)
		range_view.visible = false
	else:
		range_view.visible = visible
		if iso_view != null:
			iso_view.visible = false
			if iso_view.has_method(&"set_active"):
				iso_view.set_active(false)
	CursorManager.refresh()


func _sync_upgrade_sky_tint() -> void:
	var sky_bg := upgrade_panel.get_node_or_null("SkyBg")
	if sky_bg == null or not sky_bg.has_method(&"apply_cycle_time"):
		return
	var cycle_time := 60.0
	var cycle := range_view.get_node_or_null("DayNightCycle")
	if cycle != null and cycle.has_method(&"cycle_elapsed"):
		cycle_time = cycle.cycle_elapsed()
	sky_bg.apply_cycle_time(cycle_time)


func _is_overlay_panel_open() -> bool:
	if pause_menu.has_method("is_open") and pause_menu.is_open():
		return true
	if settings_panel.has_method("is_open") and settings_panel.is_open():
		return true
	if upgrade_panel.has_method("is_open") and upgrade_panel.is_open():
		return true
	return false


func _on_wipe_confirmed() -> void:
	SaveManager.wipe_character()


func _set_gameplay_ui_visible(visible: bool) -> void:
	gameplay_chrome.visible = visible


func set_capture_ui_visible(visible: bool) -> void:
	if not ui.visible:
		return
	_set_gameplay_ui_visible(visible)


func is_build_view_active() -> bool:
	return _build_view_active


func is_harvest_view_active() -> bool:
	return _harvest_view_active


func toggle_build_view() -> void:
	set_build_view(not _build_view_active)


func set_build_view(active: bool) -> void:
	if iso_view == null or title_screen.visible or not ui.visible:
		return
	if _is_overlay_panel_open():
		return
	if _harvest_view_active:
		return
	_build_view_active = active
	if active:
		range_view.visible = false
		if iso_view.has_method(&"set_mode"):
			iso_view.set_mode(IsoView.Mode.BUILD)
		else:
			iso_view.visible = true
			if iso_view.has_method(&"set_active"):
				iso_view.set_active(true)
	else:
		if iso_view.has_method(&"set_mode"):
			iso_view.set_mode(IsoView.Mode.OFF)
		elif iso_view.has_method(&"set_active"):
			iso_view.set_active(false)
		iso_view.visible = false
		range_view.visible = true
	_sync_build_button()


func set_harvest_view(active: bool) -> void:
	if iso_view == null:
		return
	_harvest_view_active = active
	if active:
		_build_view_active = false
		range_view.visible = false
		if iso_view.has_method(&"set_mode"):
			iso_view.set_mode(IsoView.Mode.HARVEST)
		else:
			iso_view.visible = true
	else:
		if iso_view.has_method(&"set_mode"):
			iso_view.set_mode(IsoView.Mode.OFF)
		iso_view.visible = false
		if not _build_view_active:
			range_view.visible = true
	_sync_build_button()
	CursorManager.refresh()


func _sync_build_button() -> void:
	var icon_bar := gameplay_chrome.get_node_or_null("IconBar") if gameplay_chrome else null
	if icon_bar != null and icon_bar.has_method(&"set_build_open"):
		icon_bar.set_build_open(_build_view_active)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload_game"):
		if range_view.visible or (iso_view != null and iso_view.visible):
			get_viewport().set_input_as_handled()
			SaveManager.reset_and_reload()
		return
	if _try_build_toggle(event):
		return
	if _try_debug_capture_input(event):
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _is_in_gameplay():
		return
	get_viewport().set_input_as_handled()
	_handle_escape()


func _is_in_gameplay() -> bool:
	var world_visible := range_view.visible or (iso_view != null and iso_view.visible)
	return ui.visible and world_visible or _is_overlay_panel_open()


## I toggles Build mode (IsoView) during gameplay.
func _try_build_toggle(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_I:
		return false
	if key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return false
	if iso_view == null or title_screen.visible or not ui.visible:
		return false
	if _harvest_view_active or GameState.is_harvest_phase():
		return false
	get_viewport().set_input_as_handled()
	toggle_build_view()
	return true


func _try_debug_capture_input(event: InputEvent) -> bool:
	if not OS.is_debug_build():
		return false
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_S:
		return false
	if key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
		return false
	if not range_view.visible or title_screen.visible:
		return false
	if not range_view.has_method(&"capture_plate"):
		return false
	get_viewport().set_input_as_handled()
	_debug_capture_plate_async()
	return true


func _debug_capture_plate_async() -> void:
	var ui_visible := ui.visible
	var settings_layer := get_node_or_null("SettingsLayer") as CanvasLayer
	var settings_visible := settings_layer.visible if settings_layer else true

	ui.visible = false
	if settings_layer:
		settings_layer.visible = false

	var cycle_time := 40.0
	var cycle := range_view.get_node_or_null("DayNightCycle")
	if cycle != null and cycle.has_method(&"cycle_elapsed"):
		cycle_time = cycle.cycle_elapsed()

	var output_path: String = range_view.PLATE_CAPTURE_OUTPUT
	var err: Error = await range_view.capture_plate(output_path, cycle_time)

	ui.visible = ui_visible
	if settings_layer:
		settings_layer.visible = settings_visible

	var path := ProjectSettings.globalize_path(output_path)
	if err == OK:
		print("[Main] Range plate saved: ", path)
	else:
		print("[Main] Range plate capture failed (", err, "): ", path)


func _handle_escape() -> void:
	if settings_panel.has_method("is_open") and settings_panel.is_open():
		if settings_panel.has_method("close_to_pause"):
			settings_panel.close_to_pause()
		else:
			settings_panel.close()
		return
	if upgrade_panel.has_method("is_open") and upgrade_panel.is_open():
		upgrade_panel.close()
		return
	if pause_menu.has_method("is_open") and pause_menu.is_open():
		pause_menu.close()
		return
	if pause_menu.has_method("open"):
		pause_menu.open()
