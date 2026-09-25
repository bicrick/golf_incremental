extends SceneTree
## v5 Ratina (companion) tests — run:
## godot --headless --script res://tools/verify_ratina.gd
##
## Ratina joins via her golf bag, widens the Perfect window (tempo tips), never
## hits a ball or touches the bucket, and has no upgrade tree.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	var gs: Node = root.get_node("GameState")
	gs.reset_to_fresh()
	gs.tutorial_completed = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var range_view: Node = main.get_node("RangeView")
	var ratina: Node = range_view.get("_ratina")
	if ratina == null:
		print("FAIL: RangeView should create the Ratina controller")
		quit(1)
		return
	if gs.ratina_unlocked or ratina.get_golfer_sprite().visible:
		print("FAIL: Ratina should be absent before her bag is found")
		ok = false
	if not RatinaUpgradeDefinitions.all().is_empty():
		print("FAIL: Ratina should have no upgrade tree")
		ok = false

	var window_before: float = gs.stats.timing_window_perfect_ms
	gs.record_carry(360.0)
	gs.discover_find("ratina_found")
	await process_frame
	if not gs.ratina_unlocked or not ratina.get_golfer_sprite().visible:
		print("FAIL: Ratina should join and appear after her bag")
		ok = false
	if gs.stats.timing_window_perfect_ms <= window_before:
		print("FAIL: her tempo tips should widen the Perfect window")
		ok = false
	else:
		print("OK: Ratina joins; Perfect window %.0f → %.0f ms" % [window_before, gs.stats.timing_window_perfect_ms])

	## Force a practice swing: no ball, bucket untouched, no litter.
	var bucket_before: int = gs.bucket_remaining
	var litter_before: int = range_view.get("littered_balls").get_child_count()
	ratina._perform_swing()
	Engine.time_scale = 6.0
	for _i in 90:
		await process_frame
	Engine.time_scale = 1.0
	if gs.bucket_remaining != bucket_before:
		print("FAIL: Ratina must not draw from the player's bucket")
		ok = false
	if range_view.get("littered_balls").get_child_count() != litter_before:
		print("FAIL: Ratina's practice swing must not leave a ball")
		ok = false
	if ratina.get_ball_sprite().visible:
		print("FAIL: Ratina should never show a ball")
		ok = false
	if ok:
		print("OK: practice swings only — no ball, no bucket, no litter")

	main.queue_free()
	await process_frame
	print("ratina_ok=", ok)
	quit(0 if ok else 1)
