extends SceneTree
## Headless title screen smoke — run: godot --headless --script res://tools/verify_title_screen.gd

const FADE_DURATION_SEC := 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var range_view: Node2D = main.get_node("RangeView")
	var ui: CanvasLayer = main.get_node("UI")
	var title_screen: CanvasLayer = main.get_node("TitleScreen")
	var sky_bg: Node = title_screen.get_node("SkyBg")
	var play_button: Button = title_screen.get_node("Overlay/Center/VBox/PlayBob/PlayButton")
	var title_label: Label = title_screen.get_node("Overlay/Center/VBox/TitleLabel")

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
	if title_label.text != "Range Rat":
		print("FAIL: title text expected 'Range Rat', got '%s'" % title_label.text)
		ok = false
	if title_screen.get_node_or_null("FairwayBg") != null:
		print("FAIL: FairwayBg should be replaced by SkyBg")
		ok = false
	if not sky_bg.has_method("layer_count") or sky_bg.layer_count() != 4:
		var count: int = sky_bg.layer_count() if sky_bg.has_method("layer_count") else -1
		print("FAIL: expected 4 parallax cloud layers, got %d" % count)
		ok = false

	var layer_1 := sky_bg.get_node_or_null("Layer1/Sprite") as TextureRect
	if layer_1 == null or layer_1.texture == null:
		print("FAIL: front cloud layer missing texture")
		ok = false

	var music := _sfx().get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	var ambient := _sfx().get_node_or_null("AmbientWind") as AudioStreamPlayer
	if music == null or not music.playing:
		print("FAIL: title BGM should play on title screen")
		ok = false
	elif music.stream != null and not _is_title_track(music.stream.resource_path):
		print("FAIL: title screen should play 8 bit memory track, got ", music.stream.resource_path)
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
	var click_pos := play_button.get_global_rect().get_center()
	_parse_mouse_button(click_pos, true)
	await process_frame
	_parse_mouse_button(click_pos, false)
	await process_frame
	if int(game_state.lifetime.get("total_swings", 0)) != swings_before:
		print("FAIL: mouse click on title should not auto-swing")
		ok = false

	play_button.pressed.emit()
	await process_frame
	if not play_button.disabled:
		print("FAIL: play should begin fade transition after press")
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
	elif music.stream != null and not _is_title_track(music.stream.resource_path):
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


func _sfx() -> Node:
	return get_root().get_node("SfxManager")


func _is_title_track(path: String) -> bool:
	var base := path.get_file().get_basename().to_lower()
	base = base.replace(" ", "").replace("-", "").replace("_", "")
	return base.contains("8bitmemor")
