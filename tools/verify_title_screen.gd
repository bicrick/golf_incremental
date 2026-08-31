extends SceneTree
## Headless title screen smoke — run: godot --headless --script res://tools/verify_title_screen.gd

const FADE_DURATION_SEC := 0.55


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var ok := true

	# Autoload + Main + TitleScreen start opening theme on load. Only force-start
	# if this machine's saved settings have music off.
	if not _sfx()._music_enabled:
		_sfx()._music_enabled = true
		_sfx().play_title_bgm()
		await process_frame
	elif not _sfx().is_music_playing():
		print("FAIL: title BGM should start on load when music is enabled")
		ok = false
		_sfx().play_title_bgm()
		await process_frame

	var range_view: Node3D = main.get_node("RangeView")
	var ui: CanvasLayer = main.get_node("UI")
	var title_screen: CanvasLayer = main.get_node("TitleScreen")
	var sky_bg: Node = title_screen.get_node("SkyBg")
	var load_fade: ColorRect = title_screen.get_node_or_null("LoadFade") as ColorRect
	var press_space: Label = title_screen.get_node("Overlay/Center/VBox/PressSpace")
	var title_logo: TextureRect = title_screen.get_node("Overlay/Center/VBox/TitleLogo")

	if not title_screen.visible:
		print("FAIL: TitleScreen should be visible on launch")
		ok = false
	if range_view.visible:
		print("FAIL: RangeView should be hidden on launch")
		ok = false
	if ui.visible:
		print("FAIL: UI should be hidden on launch")
		ok = false
	if title_logo.texture == null:
		print("FAIL: title logo texture missing")
		ok = false
	elif title_logo.texture.resource_path != "res://assets/sprites/range_rat/range-rat-title-logo.png":
		print("FAIL: title logo path expected range-rat-title-logo.png, got '%s'" % title_logo.texture.resource_path)
		ok = false
	elif title_logo.custom_minimum_size.x < 400.0:
		print("FAIL: title logo should dominate the screen (min width >= 400), got %s" % title_logo.custom_minimum_size)
		ok = false
	if load_fade == null:
		print("FAIL: LoadFade black overlay missing")
		ok = false
	elif load_fade.visible or load_fade.modulate.a > 0.01:
		print("FAIL: headless load intro should finish with LoadFade hidden")
		ok = false
	if sky_bg != null and sky_bg.modulate.a < 0.99:
		print("FAIL: headless load intro should fade clouds in")
		ok = false
	var splash_path := str(ProjectSettings.get_setting("application/boot_splash/image", ""))
	if splash_path != "res://assets/sprites/range_rat/range-rat-title-logo.png":
		print("FAIL: boot splash should use title logo, got '%s'" % splash_path)
		ok = false
	var splash_bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.WHITE)
	if splash_bg != Color(0, 0, 0, 1):
		print("FAIL: boot splash background should be black, got %s" % splash_bg)
		ok = false
	var shell := FileAccess.get_file_as_string("res://tools/web/range_rat_shell.html")
	if shell.is_empty():
		print("FAIL: HTML shell missing")
		ok = false
	elif "status-title" in shell:
		print("FAIL: HTML shell should not show yellow RANGE RAT text")
		ok = false
	elif "__rangeRatTitleReady" not in shell or "fade-chrome" not in shell:
		print("FAIL: HTML shell missing title-ready fade handshake")
		ok = false
	elif "window.va" not in shell or "/_vercel/insights/script.js" not in shell:
		print("FAIL: HTML shell missing Vercel Analytics snippet")
		ok = false
	elif "godot.svg" in shell.to_lower() or "game engine" in shell.to_lower():
		print("FAIL: HTML shell still has Godot branding")
		ok = false
	if title_screen.get_node_or_null("FairwayBg") != null:
		print("FAIL: FairwayBg should be replaced by SkyBg")
		ok = false
	if not sky_bg.has_method("layer_count") or sky_bg.layer_count() != 3:
		var count: int = sky_bg.layer_count() if sky_bg.has_method("layer_count") else -1
		print("FAIL: expected 3 parallax cloud layers (Layer_4 removed), got %d" % count)
		ok = false
	if sky_bg.get_node_or_null("SkyFill") == null:
		print("FAIL: SkyFill should replace Layer_4 solid blue")
		ok = false

	var layer_1 := sky_bg.get_node_or_null("Layer1/Sprite") as TextureRect
	if layer_1 == null or layer_1.texture == null:
		print("FAIL: front cloud layer missing texture")
		ok = false

	var music_tracks: Array = _sfx().get_music_tracks()
	var music := _sfx().get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	var ambient := _sfx().get_node_or_null("AmbientWind") as AudioStreamPlayer
	if music == null or not music.playing:
		print("FAIL: title BGM should play on title screen")
		ok = false
	elif MusicTrackRhythm.track_basename(_sfx().get_current_music_track_path()) != MusicPlaylist.OPENING_THEME:
		print(
			"FAIL: title screen should play %s, got "
			% MusicPlaylist.OPENING_THEME,
			_sfx().get_current_music_track_path()
		)
		ok = false
	elif music.stream != null and not music.stream.resource_path in music_tracks:
		print("FAIL: title screen should play a discovered music track, got ", music.stream.resource_path)
		ok = false
	if ambient != null and ambient.playing:
		print("FAIL: ambient should not play on title screen")
		ok = false

	var game_state: Node = get_root().get_node_or_null("GameState")
	if game_state == null:
		print("FAIL: GameState autoload missing")
		ok = false
		print("title_screen_ok=", ok)
		quit(0 if ok else 1)
		return

	var swings_before := int(game_state.lifetime.get("total_swings", 0))
	var settings_panel: Control = main.get_node("SettingsLayer/SettingsPanel")

	# Desktop / headless: logo must not steal the start click for settings.
	if not title_screen.has_method("logo_tap_opens_settings"):
		print("FAIL: TitleScreen missing logo_tap_opens_settings")
		ok = false
	elif title_screen.logo_tap_opens_settings():
		print("FAIL: desktop/headless logo tap should not open settings")
		ok = false
	if title_logo.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("FAIL: desktop title logo should IGNORE mouse so clicks start the game")
		ok = false
	if press_space.text != "Click / Space":
		print("FAIL: desktop prompt expected 'Click / Space', got '%s'" % press_space.text)
		ok = false

	# Settings API still works (mobile branding path); must not start Play.
	if not title_screen.has_method("open_settings"):
		print("FAIL: TitleScreen missing open_settings")
		ok = false
	else:
		title_screen.open_settings()
		await process_frame
		if title_screen.is_transitioning():
			print("FAIL: open_settings must not start Play")
			ok = false
		elif not settings_panel.is_open():
			print("FAIL: open_settings should open the settings panel")
			ok = false
		else:
			print("OK: settings API opens panel without starting Play")
		settings_panel.close()
		await process_frame

	# Isolated start paths — do these before consuming the main title with a click.
	if not await _assert_space_starts_isolated_title():
		ok = false
	if not await _assert_overlay_click_starts_isolated_title():
		ok = false

	# Desktop logo click must start Play, never settings.
	var logo_click := _mouse_press_at(title_logo.get_global_rect().get_center())
	title_screen._on_title_logo_gui_input(logo_click)
	await process_frame
	if settings_panel.is_open():
		print("FAIL: desktop logo click must not open settings")
		ok = false
	if not title_screen.is_transitioning():
		print("FAIL: desktop logo click should start Play")
		ok = false
	else:
		print("OK: desktop logo click starts Play")

	# Regression: mouse press/release on title must not register as a swing.
	var click_pos := press_space.get_global_rect().get_center()
	_parse_mouse_button(click_pos, true)
	await process_frame
	_parse_mouse_button(click_pos, false)
	await process_frame
	if int(game_state.lifetime.get("total_swings", 0)) != swings_before:
		print("FAIL: mouse click on title should not auto-swing")
		ok = false
	if not range_view.visible:
		print("FAIL: RangeView should show under title during crossfade")
		ok = false
	if not ui.visible:
		print("FAIL: UI should show under title during crossfade")
		ok = false

	# Simulate mouse release after fade (PLAY click bleed-through regression).
	_parse_mouse_button(click_pos, false)

	await create_timer(FADE_DURATION_SEC + 0.1).timeout
	await process_frame

	if title_screen.visible:
		print("FAIL: TitleScreen should hide after fade")
		ok = false
	if not range_view.visible:
		print("FAIL: RangeView should show after fade")
		ok = false
	if not ui.visible:
		print("FAIL: UI should show after fade")
		ok = false

	music = _sfx().get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	ambient = _sfx().get_node_or_null("AmbientWind") as AudioStreamPlayer
	if music == null or not music.playing:
		print("FAIL: title BGM should keep playing after Play")
		ok = false
	elif music.stream != null and not music.stream.resource_path in music_tracks:
		print("FAIL: gameplay should keep title track, got ", music.stream.resource_path)
		ok = false
	if ambient != null and ambient.playing:
		print("FAIL: ambient should not start after Play when title BGM continues")
		ok = false

	var game_state_after: Node = get_root().get_node_or_null("GameState")
	if game_state_after == null:
		print("FAIL: GameState autoload missing")
		ok = false
	elif int(game_state_after.lifetime.get("total_swings", 0)) != swings_before:
		print(
			"FAIL: starting game should not auto-swing (swings=%d -> %d)"
			% [swings_before, game_state_after.lifetime["total_swings"]]
		)
		ok = false

	print("title_screen_ok=", ok)
	quit(0 if ok else 1)


func _assert_space_starts_isolated_title() -> bool:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	return await _assert_isolated_title_starts(key, "Space")


func _assert_overlay_click_starts_isolated_title() -> bool:
	var click := _mouse_press_at(Vector2(240, 135))
	return await _assert_isolated_title_starts(click, "overlay click", true)


func _assert_isolated_title_starts(event: InputEvent, label: String, via_overlay := false) -> bool:
	var isolated: CanvasLayer = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(isolated)
	await process_frame
	await process_frame
	if isolated.has_method("reset_for_show"):
		isolated.reset_for_show()
	if via_overlay:
		isolated._on_overlay_gui_input(event)
	else:
		isolated._unhandled_input(event)
	await process_frame
	var started: bool = isolated.is_transitioning()
	isolated.queue_free()
	await process_frame
	if not started:
		print("FAIL: %s should begin fade transition" % label)
		return false
	print("OK: %s starts Play" % label)
	return true


func _mouse_press_at(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	return event


func _parse_mouse_button(position: Vector2, pressed: bool) -> void:
	Input.parse_input_event(_mouse_press_at(position) if pressed else _mouse_release_at(position))


func _mouse_release_at(position: Vector2) -> InputEventMouseButton:
	var event := _mouse_press_at(position)
	event.pressed = false
	return event


func _parse_space_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)


func _sfx() -> Node:
	return get_root().get_node("SfxManager")
