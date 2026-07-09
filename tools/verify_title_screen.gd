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

	# Headless runs load user settings; force music on for title BGM assertions.
	_sfx()._music_enabled = true
	_sfx().play_title_bgm()
	await process_frame

	var range_view: Node3D = main.get_node("RangeView")
	var ui: CanvasLayer = main.get_node("UI")
	var title_screen: CanvasLayer = main.get_node("TitleScreen")
	var sky_bg: Node = title_screen.get_node("SkyBg")
	var press_space: Label = title_screen.get_node("Overlay/Center/VBox/PressSpace")
	var title_logo: TextureRect = title_screen.get_node("Overlay/Center/VBox/TitleLogo")

	var ok := true

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

	# Regression: mouse press/release on title must not register as a swing.
	var click_pos := press_space.get_global_rect().get_center()
	_parse_mouse_button(click_pos, true)
	await process_frame
	_parse_mouse_button(click_pos, false)
	await process_frame
	if int(game_state.lifetime.get("total_swings", 0)) != swings_before:
		print("FAIL: mouse click on title should not auto-swing")
		ok = false

	_parse_space_key(true)
	await process_frame
	if not title_screen.is_transitioning():
		print("FAIL: Space should begin fade transition")
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


func _parse_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _parse_space_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)


func _sfx() -> Node:
	return get_root().get_node("SfxManager")
