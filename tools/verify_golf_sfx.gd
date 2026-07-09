extends SceneTree
## Headless golf hit SFX smoke — run: godot --headless --script res://tools/verify_golf_sfx.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_asset_files() and ok
	ok = _check_pool_config() and ok
	ok = await _check_sfx_manager_playback() and ok
	ok = await _check_upgrade_bling() and ok
	print("golf_sfx_ok=", ok)
	quit(0 if ok else 1)


func _check_asset_files() -> bool:
	var normal := GolfHitSfx.normal_paths()
	var power := GolfHitSfx.power_paths()
	if normal.size() != 4:
		print("FAIL: expected 4 normal golf hits, got ", normal.size())
		return false
	if power.size() != 5:
		print("FAIL: expected 5 power golf hits, got ", power.size())
		return false
	for path in normal + power:
		if load(path) == null:
			print("FAIL: could not load golf wav at ", path)
			return false
	print("OK: golf wav assets (", normal.size() + power.size(), " files)")
	return true


func _check_pool_config() -> bool:
	if not GolfHitSfx.is_big_hit(Balance.TimingTier.PERFECT, Balance.FeedbackTier.WHISPER):
		print("FAIL: perfect timing should count as big hit")
		return false
	if GolfHitSfx.is_big_hit(Balance.TimingTier.GOOD, Balance.FeedbackTier.WHISPER):
		print("FAIL: good timing alone should not be big hit")
		return false
	if not GolfHitSfx.is_big_hit(Balance.TimingTier.OKAY, Balance.FeedbackTier.JACKPOT):
		print("FAIL: jackpot feedback should count as big hit")
		return false
	print("OK: big hit routing rules")
	return true


func _check_sfx_manager_playback() -> bool:
	for script_path in [
		"res://scripts/autoload/event_bus.gd",
		"res://scripts/autoload/save_manager.gd",
	]:
		var node: Node = load(script_path).new()
		if script_path.ends_with("event_bus.gd"):
			node.name = "EventBus"
		else:
			node.name = "SaveManager"
		root.add_child(node)
	await process_frame

	var sfx: Node = load("res://scripts/audio/sfx_manager.gd").new()
	sfx.name = "SfxManager"
	root.add_child(sfx)
	await process_frame

	if sfx._golf_hit_normal.is_empty() or sfx._golf_hit_power.is_empty():
		print("FAIL: golf hit stream pools not loaded")
		return false

	sfx._play_golf_hit(Balance.TimingTier.GOOD, Balance.FeedbackTier.WHISPER)
	await process_frame
	if not _any_sfx_playing(sfx):
		print("FAIL: normal golf hit did not start playback")
		return false

	sfx._play_golf_hit(Balance.TimingTier.PERFECT, Balance.FeedbackTier.WARM)
	await process_frame
	if not _any_sfx_playing(sfx):
		print("FAIL: power golf hit did not start playback")
		return false

	print("OK: sfx_manager golf hit playback")
	return true


func _check_upgrade_bling() -> bool:
	var sfx: Node = root.get_node_or_null("SfxManager")
	if sfx == null:
		sfx = load("res://scripts/audio/sfx_manager.gd").new()
		sfx.name = "SfxManager"
		root.add_child(sfx)
		await process_frame
	if not sfx._streams.has("upgrade_bling"):
		print("FAIL: upgrade_bling stream missing")
		return false
	if sfx._streams.has("upgrade_tap") or sfx._streams.has("upgrade_purchase"):
		print("FAIL: legacy upgrade_tap/upgrade_purchase should be removed")
		return false
	var loaded: AudioStream = sfx._streams["upgrade_bling"]
	if loaded == null:
		print("FAIL: upgrade_bling stream is null")
		return false
	if loaded.resource_path != sfx.UPGRADE_BLING_PATH:
		print(
			"FAIL: upgrade_bling should load Mixkit asset, got path=%s"
			% loaded.resource_path
		)
		return false
	if sfx.POOL_SIZE < 8:
		print("FAIL: SFX pool should be at least 8 for spam, got ", sfx.POOL_SIZE)
		return false
	sfx.set_sfx_enabled(true)
	sfx.set_sfx_volume(1.0)
	sfx._on_upgrade_purchased("base_pay", 3, 0)
	await process_frame
	if not _any_sfx_playing(sfx):
		print("FAIL: upgrade_bling did not start playback")
		return false
	print("OK: upgrade_bling playback")
	return true


func _any_sfx_playing(sfx: Node) -> bool:
	for child in sfx.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("SfxPlayer") and child.playing:
			return true
	return false
