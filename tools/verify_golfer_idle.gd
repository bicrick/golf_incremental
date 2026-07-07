extends SceneTree
## Headless golfer idle selection tests — run:
## godot --headless --script res://tools/verify_golfer_idle.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		quit(1)
		return

	var ok := true
	ok = _check_has_bucket_balls(gs) and ok
	ok = _check_idle_anim_selection() and ok
	ok = _check_sync_guard_when_out_of_balls() and ok
	print("golfer_idle_ok=%s" % ok)
	quit(0 if ok else 1)


func _idle_anim_for_bucket(has_balls: bool) -> StringName:
	return &"idle" if has_balls else &"idle_out_of_balls"


func _should_sync_out_of_balls_idle(
	golfer_anim: StringName,
	follow_playing: bool,
	return_playing: bool
) -> bool:
	if golfer_anim == &"follow" and follow_playing:
		return false
	if golfer_anim == &"return_to_address" and return_playing:
		return false
	if golfer_anim == &"swing":
		return false
	return true


func _check_has_bucket_balls(gs: Node) -> bool:
	var ok := true
	gs.reset_to_fresh()
	if not gs.has_bucket_balls():
		print("FAIL: fresh game should have bucket balls")
		ok = false
	gs.bucket_remaining = 0
	if gs.has_bucket_balls():
		print("FAIL: empty bucket in strike should not have bucket balls")
		ok = false
	gs.try_enter_harvest()
	if gs.has_bucket_balls():
		print("FAIL: harvest phase should not have bucket balls")
		ok = false
	return ok


func _check_idle_anim_selection() -> bool:
	var ok := true
	if _idle_anim_for_bucket(true) != &"idle":
		print("FAIL: expected idle when bucket has balls")
		ok = false
	if _idle_anim_for_bucket(false) != &"idle_out_of_balls":
		print("FAIL: expected idle_out_of_balls when bucket empty")
		ok = false
	return ok


func _check_sync_guard_when_out_of_balls() -> bool:
	var ok := true
	if _should_sync_out_of_balls_idle(&"follow", true, false):
		print("FAIL: active follow-through should defer out-of-balls idle sync")
		ok = false
	if not _should_sync_out_of_balls_idle(&"follow", false, false):
		print("FAIL: finished follow should allow out-of-balls idle sync")
		ok = false
	if _should_sync_out_of_balls_idle(&"return_to_address", false, true):
		print("FAIL: active return_to_address should defer out-of-balls idle sync")
		ok = false
	if not _should_sync_out_of_balls_idle(&"return_to_address", false, false):
		print("FAIL: finished return_to_address should allow out-of-balls idle sync")
		ok = false
	if _should_sync_out_of_balls_idle(&"swing", false, false):
		print("FAIL: swing anim should defer out-of-balls idle sync")
		ok = false
	return ok
