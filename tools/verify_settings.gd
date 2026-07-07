extends SceneTree
## Headless settings smoke — run: godot --headless --script res://tools/verify_settings.gd

const SETTINGS_PATH := "user://settings.json"
const SAVE_PATH := "user://save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	_cleanup_user_files()
	_load_autoloads()
	await process_frame

	ok = _test_default_settings() and ok
	ok = await _test_persist_settings() and ok
	ok = await _test_sfx_manager_flags() and ok
	ok = _test_volume_persistence() and ok
	ok = await _test_sfx_manager_volume_api() and ok
	ok = _test_wipe_keeps_settings() and ok
	ok = await _test_main_has_settings_panel() and ok
	ok = await _test_pause_menu() and ok

	_cleanup_user_files()
	print("settings_ok=", ok)
	quit(0 if ok else 1)


func _load_autoloads() -> void:
	for script_path in [
		"res://scripts/autoload/event_bus.gd",
		"res://scripts/autoload/save_manager.gd",
		"res://scripts/autoload/game_state.gd",
		"res://scripts/audio/sfx_manager.gd",
	]:
		var node: Node = load(script_path).new()
		if script_path.ends_with("event_bus.gd"):
			node.name = "EventBus"
		elif script_path.ends_with("save_manager.gd"):
			node.name = "SaveManager"
		elif script_path.ends_with("game_state.gd"):
			node.name = "GameState"
		elif script_path.ends_with("sfx_manager.gd"):
			node.name = "SfxManager"
		root.add_child(node)
	await process_frame


func _test_default_settings() -> bool:
	var save_manager: Node = root.get_node("SaveManager")
	if save_manager.sfx_enabled != true or save_manager.music_enabled != true:
		print("FAIL: default settings should enable sfx and music")
		return false
	if not is_equal_approx(save_manager.sfx_volume, 1.0) or not is_equal_approx(save_manager.music_volume, 1.0):
		print("FAIL: default volume should be 1.0")
		return false
	print("OK: default_settings")
	return true


func _test_persist_settings() -> bool:
	var save_manager: Node = root.get_node("SaveManager")
	save_manager.sfx_enabled = false
	save_manager.music_enabled = false
	save_manager.save_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		print("FAIL: settings file not written")
		return false

	var save_manager_b: Node = load("res://scripts/autoload/save_manager.gd").new()
	save_manager_b.name = "SaveManagerReload"
	root.add_child(save_manager_b)
	await process_frame

	if save_manager_b.sfx_enabled != false or save_manager_b.music_enabled != false:
		print("FAIL: settings did not persist across load")
		save_manager_b.queue_free()
		return false
	save_manager_b.queue_free()
	print("OK: settings_persist")
	return true


func _test_sfx_manager_flags() -> bool:
	var sfx: Node = root.get_node("SfxManager")
	sfx.set_sfx_enabled(false)
	sfx.set_music_enabled(false)
	if sfx.is_sfx_enabled() or sfx.is_music_enabled():
		print("FAIL: SfxManager flags not applied")
		return false

	sfx._play("ui_click", 0.0)
	await process_frame
	for child in sfx.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("SfxPlayer") and child.playing:
			print("FAIL: SFX should be muted")
			return false

	print("OK: sfx_manager_flags")
	return true


func _test_volume_persistence() -> bool:
	var save_manager: Node = root.get_node("SaveManager")
	save_manager.sfx_volume = 0.35
	save_manager.music_volume = 0.65
	save_manager.save_settings()

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		print("FAIL: settings json corrupt after volume save")
		return false
	if not is_equal_approx(float(parsed.get("sfx_volume", -1.0)), 0.35):
		print("FAIL: sfx_volume not persisted")
		return false
	if not is_equal_approx(float(parsed.get("music_volume", -1.0)), 0.65):
		print("FAIL: music_volume not persisted")
		return false

	save_manager.load_settings()
	if not is_equal_approx(save_manager.sfx_volume, 0.35) or not is_equal_approx(save_manager.music_volume, 0.65):
		print("FAIL: volumes not loaded from settings file")
		return false

	print("OK: volume_persistence")
	return true


func _test_sfx_manager_volume_api() -> bool:
	var sfx: Node = root.get_node("SfxManager")
	sfx.set_sfx_enabled(true)
	sfx.set_music_enabled(true)
	sfx.set_sfx_volume(0.5)
	sfx.set_music_volume(0.25)

	if not is_equal_approx(sfx.get_sfx_volume(), 0.5):
		print("FAIL: get_sfx_volume mismatch")
		return false
	if not is_equal_approx(sfx.get_music_volume(), 0.25):
		print("FAIL: get_music_volume mismatch")
		return false

	sfx.play_title_bgm()
	await process_frame

	var music := sfx.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music == null or not music.playing:
		print("FAIL: music should play for volume api test")
		return false

	var expected_db: float = -9.0 + linear_to_db(0.25)
	if not is_equal_approx(music.volume_db, expected_db):
		print("FAIL: music volume_db expected %.2f got %.2f" % [expected_db, music.volume_db])
		return false

	sfx._play("ui_click", -8.0)
	await process_frame
	for child in sfx.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("SfxPlayer") and child.playing:
			var expected_sfx_db: float = -8.0 + linear_to_db(0.5)
			if not is_equal_approx(child.volume_db, expected_sfx_db):
				print("FAIL: sfx volume_db expected %.2f got %.2f" % [expected_sfx_db, child.volume_db])
				return false
			print("OK: sfx_manager_volume_api")
			return true

	print("FAIL: sfx player did not play during volume api test")
	return false


func _test_wipe_keeps_settings() -> bool:
	var save_manager: Node = root.get_node("SaveManager")
	var game_state: Node = root.get_node("GameState")
	save_manager.sfx_enabled = false
	save_manager.music_enabled = true
	save_manager.save_settings()
	game_state.currency = 999.0
	game_state.upgrade_levels = {"test_upgrade": 3}
	save_manager.save_game()

	if not FileAccess.file_exists(SAVE_PATH):
		print("FAIL: save file not written before wipe test")
		return false

	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")
	game_state.reset_to_fresh()

	if game_state.currency != 0.0 or not game_state.upgrade_levels.is_empty():
		print("FAIL: wipe did not reset GameState")
		return false
	if not FileAccess.file_exists(SETTINGS_PATH):
		print("FAIL: settings file removed during wipe")
		return false

	save_manager.load_settings()
	if save_manager.sfx_enabled != false or save_manager.music_enabled != true:
		print("FAIL: wipe changed audio settings")
		return false

	print("OK: wipe_keeps_settings")
	return true


func _test_main_has_settings_panel() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var settings_panel := main.get_node_or_null("SettingsLayer/SettingsPanel")
	if settings_panel == null:
		print("FAIL: SettingsPanel missing from main scene")
		main.queue_free()
		return false
	if settings_panel.get_node_or_null("Content/Body/MusicVolumeRow/MusicVolumeSlider") == null:
		print("FAIL: music volume slider missing")
		main.queue_free()
		return false
	if settings_panel.get_node_or_null("Content/Body/SfxVolumeRow/SfxVolumeSlider") == null:
		print("FAIL: sfx volume slider missing")
		main.queue_free()
		return false
	if not settings_panel.has_method("open") or not settings_panel.has_method("is_open"):
		print("FAIL: SettingsPanel missing open/is_open API")
		main.queue_free()
		return false

	var pause_menu := main.get_node_or_null("SettingsLayer/PauseMenu")
	if pause_menu == null:
		print("FAIL: PauseMenu missing from main scene")
		main.queue_free()
		return false
	if not pause_menu.has_method("open") or not pause_menu.has_method("is_open"):
		print("FAIL: PauseMenu missing open/is_open API")
		main.queue_free()
		return false

	var icon_bar := main.get_node_or_null("UI/UIRoot/GameplayChrome/IconBar")
	if icon_bar != null and icon_bar.has_node("BottomLeft"):
		print("FAIL: settings cog should be removed from icon bar")
		main.queue_free()
		return false

	var reset_button: Button = settings_panel.get_node_or_null("Content/Body/ResetButton")
	if reset_button == null:
		print("FAIL: Reset Character button missing")
		main.queue_free()
		return false
	if reset_button.text != "Reset Character":
		print("FAIL: reset button text expected 'Reset Character', got '%s'" % reset_button.text)
		main.queue_free()
		return false

	var reset_dialog: ConfirmationDialog = settings_panel.get_node_or_null("ResetDialog")
	if reset_dialog == null:
		print("FAIL: ResetDialog missing")
		main.queue_free()
		return false
	if reset_dialog.title != "Reset Character?":
		print("FAIL: reset dialog title expected 'Reset Character?'")
		main.queue_free()
		return false
	if reset_dialog.ok_button_text != "Reset":
		print("FAIL: reset dialog ok button expected 'Reset', got '%s'" % reset_dialog.ok_button_text)
		main.queue_free()
		return false

	var title_settings := main.get_node_or_null("TitleScreen/Overlay/SettingsButton")
	if title_settings != null:
		print("FAIL: title screen should not have a settings button")
		main.queue_free()
		return false

	main.queue_free()
	print("OK: main_settings_panel")
	return true


func _test_pause_menu() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var pause_menu: Control = main.get_node("SettingsLayer/PauseMenu")
	var game_state: Node = root.get_node("GameState")
	game_state.currency = 100.0

	main._on_play_pressed()
	await process_frame

	if pause_menu.is_open():
		print("FAIL: pause menu should start closed")
		main.queue_free()
		return false

	pause_menu.open()
	await process_frame

	if not pause_menu.is_open():
		print("FAIL: pause menu should open")
		main.queue_free()
		return false

	var add_money_btn: Button = pause_menu.get_node(
		"Content/Center/MainRow/LeftPane/DebugSection/AddMoneyButton"
	)
	add_money_btn.pressed.emit()
	await process_frame

	if not is_equal_approx(game_state.currency, 100.0 + 1_000_000.0):
		print("FAIL: debug add money expected %.0f got %.0f" % [100.0 + 1_000_000.0, game_state.currency])
		main.queue_free()
		return false

	pause_menu.close()
	await process_frame

	if pause_menu.is_open():
		print("FAIL: pause menu should close")
		main.queue_free()
		return false

	main.queue_free()
	print("OK: pause_menu")
	return true


func _cleanup_user_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("settings.json"):
		dir.remove("settings.json")
	if dir.file_exists("save.json"):
		dir.remove("save.json")
