extends SceneTree
## Headless BGM smoke check — run: godot --headless --script res://tools/verify_bgm.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sfx: Node = load("res://scripts/audio/sfx_manager.gd").new()
	root.add_child(sfx)
	await process_frame
	sfx.start_bgm()
	await process_frame

	var music := sfx.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music == null:
		print("FAIL: BackgroundMusic player missing")
		quit(1)
		return
	if music.stream == null:
		print("FAIL: BGM stream not loaded")
		quit(1)
		return
	if not music.playing:
		print("FAIL: BGM not playing")
		quit(1)
		return

	print("OK: BGM track=", music.stream.resource_path)
	print("OK: volume_db=", music.volume_db)
	print("OK: playing=", music.playing)
	quit(0)
