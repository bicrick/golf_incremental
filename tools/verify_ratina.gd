extends SceneTree
## v5 Ratina (coach) tests — run:
## godot --headless --script res://tools/verify_ratina.gd
##
## Ratina joins via her golf bag, never draws from the player's bucket, plants
## one standing pink flag, and a player ball resting on it pays the mark bonus.


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

	## Tree shape — coach tree, 3 nodes, root hangs off base_pay behind the bag.
	if RatinaUpgradeDefinitions.all().size() != 3:
		print("FAIL: expected 3 Ratina coach nodes, got ", RatinaUpgradeDefinitions.all().size())
		ok = false
	if UpgradeGraph.parent_id("ratina_coaching") != "base_pay":
		print("FAIL: ratina_coaching should hang off base_pay")
		ok = false

	gs.record_carry(80.0)
	gs.discover_find("ratina_bag")
	await process_frame
	if not gs.ratina_unlocked or not ratina.get_golfer_sprite().visible:
		print("FAIL: Ratina should join and appear after her bag")
		ok = false
	else:
		print("OK: Ratina joins via her bag")

	## She plants her first flag from her own pocket — bucket untouched.
	var bucket_before: int = gs.bucket_remaining
	Engine.time_scale = 8.0
	var start := Time.get_ticks_msec()
	while ratina.mark_position() == Vector3.INF and Time.get_ticks_msec() - start < 4000:
		await process_frame
	Engine.time_scale = 1.0
	var mark: Vector3 = ratina.mark_position()
	if mark == Vector3.INF:
		print("FAIL: Ratina should plant a flag after joining")
		ok = false
	elif gs.bucket_remaining != bucket_before:
		print("FAIL: Ratina must not draw from the player's bucket")
		ok = false
	else:
		print("OK: Ratina plants a flag at %.0f yd without touching the bucket" % ratina.get("_mark_yards"))

	## The flag stands until hit — no new demo pending while it's up.
	if bool(ratina.get("_demo_pending")):
		print("FAIL: no new demo should be pending while a flag stands")
		ok = false

	## A player ball resting on the flag is tagged and the flag clears.
	if mark != Vector3.INF:
		var litter: Sprite3D = range_view.leave_litter_ball(
			mark + Vector3(1.0, 0.0, 0.5), Vector3.ONE, 5, 80.0, false, "player"
		)
		if litter == null or not bool(litter.get_meta("ratina_mark", false)):
			print("FAIL: a ball on the flag should be tagged ratina_mark")
			ok = false
		elif ratina.mark_position() != Vector3.INF:
			print("FAIL: hitting the flag should clear it")
			ok = false
		else:
			print("OK: landing on the flag tags the ball and clears the flag")

	## Bonus math + coach upgrade.
	var extra: float = gs.pay_ratina_mark_bonus(10.0)
	if not is_equal_approx(extra, 10.0 * (gs.ratina_stats.ratina_mark_bonus - 1.0)):
		print("FAIL: mark bonus should pay (bonus - 1) × base")
		ok = false
	gs.currency = 1000.0
	var bonus_before: float = gs.ratina_stats.ratina_mark_bonus
	if not gs.purchase_ratina_upgrade("ratina_coaching") or gs.ratina_stats.ratina_mark_bonus <= bonus_before:
		print("FAIL: Coaching should raise the mark bonus")
		ok = false
	else:
		print("OK: mark bonus pays; Coaching raises it")

	main.queue_free()
	await process_frame
	print("ratina_ok=", ok)
	quit(0 if ok else 1)
