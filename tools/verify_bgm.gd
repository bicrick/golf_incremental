extends SceneTree
## Headless BGM smoke check — run: godot --headless --script res://tools/verify_bgm.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_manager: Node = root.get_node_or_null("SaveManager")
	var autoload: Node = root.get_node_or_null("SfxManager")
	var settings_music_on := save_manager != null and bool(save_manager.music_enabled)
	if autoload != null and settings_music_on:
		await process_frame
		if not autoload.is_music_playing():
			print("FAIL: autoload SfxManager should start BGM on load")
			quit(1)
			return
		if MusicTrackRhythm.track_basename(autoload.get_current_music_track_path()) != MusicPlaylist.OPENING_THEME:
			print(
				"FAIL: autoload BGM should be %s on load, got "
				% MusicPlaylist.OPENING_THEME,
				autoload.get_current_music_track_path()
			)
			quit(1)
			return
		print("OK: autoload_starts_on_load=true")
	elif autoload != null:
		print("OK: autoload_music_disabled_in_settings=true")

	if save_manager != null:
		save_manager.music_enabled = true
	var sfx: Node = load("res://scripts/audio/sfx_manager.gd").new()
	root.add_child(sfx)
	await process_frame
	sfx._music_enabled = true

	var ready_music := sfx.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
	if ready_music == null or not ready_music.playing:
		print("FAIL: SfxManager._ready should start BGM without play_title_bgm")
		quit(1)
		return
	if MusicTrackRhythm.track_basename(sfx.get_current_music_track_path()) != MusicPlaylist.OPENING_THEME:
		print(
			"FAIL: _ready BGM should be %s, got "
			% MusicPlaylist.OPENING_THEME,
			sfx.get_current_music_track_path()
		)
		quit(1)
		return
	print("OK: starts_on_load=true")

	var tracks: Array = sfx.get_music_tracks()
	print("OK: track_count=", tracks.size())
	for track_path in tracks:
		print("OK: track=", track_path)

	if tracks.size() < 2:
		print("FAIL: expected at least 2 music tracks for rotation")
		quit(1)
		return

	var expected_order := MusicPlaylist.ordered_basenames()
	var got_order: PackedStringArray = PackedStringArray()
	for track_path in tracks:
		got_order.append(MusicTrackRhythm.track_basename(str(track_path)))
	if got_order.size() < expected_order.size():
		print("FAIL: playlist missing tracks, got ", got_order)
		quit(1)
		return
	for i in expected_order.size():
		if got_order[i] != expected_order[i]:
			print(
				"FAIL: playlist order expected %s at %d, got %s"
				% [expected_order[i], i, got_order[i]]
			)
			quit(1)
			return
	print("OK: playlist_order=", ",".join(got_order))

	var wrap_repeat: Array[String] = [
		"res://audio/main-theme.ogg",
		"res://audio/sunrise.ogg",
		"res://audio/main-theme.ogg",
	]
	var wrap_i := MusicPlaylist.next_index(wrap_repeat, 2)
	if MusicTrackRhythm.track_basename(wrap_repeat[wrap_i]) == MusicPlaylist.OPENING_THEME:
		print("FAIL: loop should skip an immediate opening-theme repeat")
		quit(1)
		return
	print("OK: no_consecutive_repeat=true")

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

	var title_path: String = sfx.get_current_music_track_path()
	if MusicTrackRhythm.track_basename(title_path) != MusicPlaylist.OPENING_THEME:
		print(
			"FAIL: title BGM should always be %s, got "
			% MusicPlaylist.OPENING_THEME,
			title_path
		)
		quit(1)
		return

	print("OK: title_track=", title_path)
	print("OK: opening_theme_first=true")
	print("OK: title_playing=", music.playing)

	sfx.play_title_bgm()
	await process_frame
	if sfx.get_current_music_track_path() != title_path:
		print("FAIL: play_title_bgm should not restart a new track, got ", sfx.get_current_music_track_path())
		quit(1)
		return
	if not music.playing:
		print("FAIL: title BGM should stay playing after a second play_title_bgm")
		quit(1)
		return
	print("OK: title_bgm_idempotent=true")

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

	await create_timer(0.2).timeout
	var pos_before := music.get_playback_position()
	sfx.start_bgm()
	await process_frame

	if not music.playing:
		print("FAIL: title BGM stopped after start_bgm")
		quit(1)
		return

	var gameplay_path: String = sfx.get_current_music_track_path()
	if gameplay_path != title_path:
		print("FAIL: start_bgm should keep current track, got ", gameplay_path)
		quit(1)
		return
	if pos_before > 0.05 and music.get_playback_position() < pos_before * 0.5:
		print(
			"FAIL: start_bgm restarted the title track (pos %s -> %s)"
			% [pos_before, music.get_playback_position()]
		)
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

	var played: Array[String] = [MusicTrackRhythm.track_basename(title_path)]
	for _i in tracks.size():
		sfx._on_music_finished()
		await process_frame
		var next_path: String = sfx.get_current_music_track_path()
		var next_name := MusicTrackRhythm.track_basename(next_path)
		if next_name.is_empty():
			print("FAIL: rotation produced an empty track")
			quit(1)
			return
		if next_name == played[played.size() - 1]:
			print("FAIL: consecutive repeat after ", next_name)
			quit(1)
			return
		played.append(next_name)
	if played[1] != "sunrise":
		print("FAIL: after opening theme expected sunrise, got ", played[1])
		quit(1)
		return
	print("OK: daytime_sequence=", ",".join(played))

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
