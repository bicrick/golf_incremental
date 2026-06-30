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
	var fairway_bg: Node = title_screen.get_node("FairwayBg")
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
	if title_screen.get_node_or_null("GrassBg") != null:
		print("FAIL: GrassBg tile texture should be removed")
		ok = false
	if title_screen.get_node_or_null("Background") != null:
		print("FAIL: old Node2D Background should be replaced by FairwayBg Control")
		ok = false
	if not fairway_bg.has_method("stripe_count") or fairway_bg.stripe_count() < 25:
		var count: int = fairway_bg.stripe_count() if fairway_bg.has_method("stripe_count") else -1
		print("FAIL: expected fairway stripes (base + 24), got %d" % count)
		ok = false

	var music := _sfx().get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	var ambient := _sfx().get_node_or_null("AmbientWind") as AudioStreamPlayer
	if music != null and music.playing:
		print("FAIL: BGM should not play on title screen")
		ok = false
	if ambient != null and ambient.playing:
		print("FAIL: ambient should not play on title screen")
		ok = false

	play_button.pressed.emit()
	await process_frame
	if not play_button.disabled:
		print("FAIL: play should begin fade transition after press")
		ok = false

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
	var audio_playing := (music != null and music.playing) or (ambient != null and ambient.playing)
	if not audio_playing:
		print("FAIL: background audio should start after Play")
		ok = false

	print("title_screen_ok=", ok)
	quit(0 if ok else 1)


func _sfx() -> Node:
	return get_root().get_node("SfxManager")
