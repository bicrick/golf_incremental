extends SceneTree
## Headless music pulse smoke — run: godot --headless --path . --script res://tools/verify_music_pulse.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	await process_frame

	ok = await _test_music_bus_after_bgm() and ok
	ok = await _test_pulse_inactive_when_music_disabled() and ok
	ok = await _test_backdrop_pulse_on_trigger() and ok

	print("music_pulse_ok=", ok)
	quit(0 if ok else 1)


func _sfx() -> Node:
	return root.get_node("/root/SfxManager")


func _pulse() -> Node:
	return root.get_node("/root/MusicPulseService")


func _test_music_bus_after_bgm() -> bool:
	_sfx()._music_enabled = true
	_sfx().play_title_bgm()
	await process_frame

	if not _sfx().is_music_active():
		print("FAIL: music should be active after play_title_bgm")
		return false

	var bus_idx: int = _sfx().get_music_bus_index()
	if bus_idx < 0:
		print("FAIL: Music bus missing after BGM start")
		return false
	if _sfx().get_music_spectrum_instance() == null:
		print("FAIL: spectrum analyzer instance missing after BGM start")
		return false

	print("OK: music_active_after_bgm=true")
	return true


func _test_pulse_inactive_when_music_disabled() -> bool:
	_sfx().set_music_enabled(false)
	await process_frame

	if _pulse().get_sway_amount() != 0.0:
		print("FAIL: sway amount should be 0 when music disabled")
		return false
	if _pulse().is_active():
		print("FAIL: pulse service should be inactive when music disabled")
		return false

	print("OK: pulse_inactive_when_music_disabled=true")
	_sfx().set_music_enabled(true)
	await process_frame
	return true


func _test_backdrop_pulse_on_trigger() -> bool:
	var range_view: Node = load("res://scenes/range/range_view.tscn").instantiate()
	root.add_child(range_view)
	await process_frame

	var backdrop := range_view.get_node_or_null("Backdrop") as Node3D
	if backdrop == null:
		print("FAIL: Backdrop node missing on range_view")
		return false

	backdrop.visible = true
	backdrop.call("capture_base_transform")
	var base_transform := backdrop.transform
	backdrop.call("apply_pulse_strength", 1.0)

	if backdrop.transform.is_equal_approx(base_transform):
		print("FAIL: backdrop transform should change when pulse triggers")
		return false

	_sfx().set_music_enabled(false)
	backdrop.call("apply_pulse_strength", 0.0)

	if not backdrop.transform.is_equal_approx(base_transform):
		print("FAIL: backdrop transform should return to base when pulse inactive")
		return false

	_sfx().set_music_enabled(true)
	await process_frame

	print("OK: backdrop_pulse_transform=true")
	return true
