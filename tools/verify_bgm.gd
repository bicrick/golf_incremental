extends SceneTree
## Headless BGM smoke check — run: godot --headless --script res://tools/verify_bgm.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sfx: Node = load("res://scripts/audio/sfx_manager.gd").new()
	root.add_child(sfx)
	await process_frame
	sfx._music_enabled = true

	var tracks: Array = sfx.get_music_tracks()
	print("OK: track_count=", tracks.size())
	for track_path in tracks:
		print("OK: track=", track_path)

	if tracks.size() < 2:
		print("FAIL: expected at least 2 music tracks for rotation")
		quit(1)
		return

	sfx.play_title_bgm()
	await process_frame

	var music := sfx.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if music == null:
		print("FAIL: BackgroundMusic player missing after play_title_bgm")
		quit(1)
		return
	if music.stream == null:
		print("FAIL: title BGM stream not loaded")
		quit(1)
		return
	if not music.playing:
		print("FAIL: title BGM not playing")
		quit(1)
		return

	var title_path := music.stream.resource_path
	if not title_path in tracks:
		print("FAIL: title BGM should be one of discovered tracks, got ", title_path)
		quit(1)
		return

	print("OK: title_track=", title_path)
	print("OK: title_playing=", music.playing)

	if music.stream is AudioStreamMP3:
		if music.stream.loop:
			print("FAIL: title BGM should not loop")
			quit(1)
			return
	elif music.stream is AudioStreamOggVorbis:
		if music.stream.loop:
			print("FAIL: title BGM should not loop")
			quit(1)
			return
	elif music.stream is AudioStreamWAV:
		if music.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			print("FAIL: title BGM should not loop")
			quit(1)
			return

	if not music.finished.is_connected(sfx._on_music_finished):
		print("FAIL: title BGM should use rotation handler")
		quit(1)
		return

	sfx.start_bgm()
	await process_frame

	if not music.playing:
		print("FAIL: title BGM stopped after start_bgm")
		quit(1)
		return

	var gameplay_path := music.stream.resource_path
	if gameplay_path != title_path:
		print("FAIL: start_bgm should keep current track, got ", gameplay_path)
		quit(1)
		return

	print("OK: gameplay_track=", gameplay_path)
	print("OK: title_track_continues=true")

	if music.stream is AudioStreamMP3:
		if music.stream.loop:
			print("FAIL: gameplay BGM should not loop")
			quit(1)
			return
	elif music.stream is AudioStreamOggVorbis:
		if music.stream.loop:
			print("FAIL: gameplay BGM should not loop")
			quit(1)
			return
	elif music.stream is AudioStreamWAV:
		if music.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			print("FAIL: gameplay BGM should not loop")
			quit(1)
			return

	if not music.finished.is_connected(sfx._on_music_finished):
		print("FAIL: gameplay BGM should use rotation handler")
		quit(1)
		return

	print("OK: volume_db=", music.volume_db)
	print("OK: gameplay_mode=playlist_rotation")

	var display_name: String = sfx.get_current_music_display_name()
	if display_name.is_empty():
		print("FAIL: display name should not be empty")
		quit(1)
		return
	for ext in ["mp3", "ogg", "wav", "flac"]:
		if display_name.to_lower().ends_with("." + ext):
			print("FAIL: display name should omit extension, got ", display_name)
			quit(1)
			return
	print("OK: display_name=", display_name)

	var before_skip: String = sfx.get_current_music_track_path()
	sfx.skip_music_track()
	await process_frame
	var after_skip: String = sfx.get_current_music_track_path()
	if after_skip.is_empty() or after_skip == before_skip:
		print("FAIL: skip should change track from ", before_skip, " got ", after_skip)
		quit(1)
		return
	if not music.playing:
		print("FAIL: music should play after skip")
		quit(1)
		return
	print("OK: skip_track=", after_skip)

	sfx.previous_music_track()
	await process_frame
	var after_prev: String = sfx.get_current_music_track_path()
	if after_prev != before_skip:
		print("FAIL: previous should return to ", before_skip, " got ", after_prev)
		quit(1)
		return
	print("OK: previous_track=", after_prev)

	sfx.stop_music()
	await process_frame
	if sfx.is_music_playing():
		print("FAIL: music should stop after stop_music")
		quit(1)
		return
	print("OK: stop_music=true")

	quit(0)
