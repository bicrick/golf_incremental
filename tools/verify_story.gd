extends SceneTree
## v5 story tests — run:
## godot --headless --script res://tools/verify_story.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_save()
	var ok := true
	ok = _check_catalog() and ok
	ok = _check_reveal_and_claim() and ok
	ok = _check_rewards() and ok
	ok = _check_story_gates() and ok
	ok = _check_save_roundtrip() and ok
	ok = await _check_target_landing() and ok
	ok = _check_finale() and ok
	_cleanup_save()
	print("story_ok=", ok)
	quit(0 if ok else 1)


func _gs() -> Node:
	return root.get_node("GameState")


func _cleanup_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")


func _check_catalog() -> bool:
	var ok := true
	var last := -1.0
	for def in StoryFinds.all():
		var id: String = def["id"]
		if float(def["yards"]) <= last:
			print("FAIL: finds must be ordered by yardage (", id, ")")
			ok = false
		last = float(def["yards"])
		if not ResourceLoader.exists(StoryFinds.sprite_path(String(def["sprite"]))):
			print("FAIL: missing sprite for ", id)
			ok = false
		if StoryScript.lines_for_find(id).is_empty():
			print("FAIL: no dialogue for ", id)
			ok = false
		var r: Dictionary = def["reward"]
		if r.has("note") and StoryScript.note_text(String(r["note"])).is_empty():
			print("FAIL: missing note text for ", id)
			ok = false
		if String(def["kind"]) == "target" and StoryScript.hint_lines_for(id).is_empty():
			print("FAIL: target find without hint lines: ", id)
			ok = false
	## Fairway ground ends at RangeGrid.DEPTH_YARDS in world z; the tee sits ~10 yd in.
	var tee_z := RangeGrid.player_bay_origin().z
	if last > RangeGrid.DEPTH_YARDS + tee_z - 6.0:
		print("FAIL: last find past the range's far edge")
		ok = false
	if ok:
		print("OK: %d finds ordered, with sprites, lines and notes" % StoryFinds.order().size())
	return ok


func _check_reveal_and_claim() -> bool:
	var ok := true
	var gs := _gs()
	gs.reset_to_fresh()
	if gs.is_find_revealed("scorecard_1"):
		print("FAIL: scorecard revealed at 0 carry")
		ok = false
	gs.record_carry(40.0)
	if not gs.is_find_claimable("scorecard_1"):
		print("FAIL: scorecard should be claimable at 40 yd carry")
		ok = false
	if gs.is_find_revealed("ratina_bag"):
		print("FAIL: ratina bag revealed too early")
		ok = false
	if gs.unannounced_revealed_finds() != ["scorecard_1"]:
		print("FAIL: expected scorecard to be unannounced, got ", gs.unannounced_revealed_finds())
		ok = false
	if not gs.discover_find("scorecard_1") or gs.discover_find("scorecard_1"):
		print("FAIL: discover should succeed exactly once")
		ok = false
	if gs.story_found_count() != 1:
		print("FAIL: found count should be 1")
		ok = false
	if ok:
		print("OK: reveal follows the fog line; finds claim once")
	return ok


func _check_rewards() -> bool:
	var ok := true
	var gs := _gs()
	gs.reset_to_fresh()
	gs.record_carry(200.0)
	gs.upgrade_levels["iron_set"] = 1
	if UpgradeGraph.is_unlocked("spoon_club"):
		print("FAIL: Barley's Spoon node should wait for the spoon find")
		ok = false
	gs.discover_find("barley_spoon")
	if not UpgradeGraph.is_unlocked("spoon_club"):
		print("FAIL: finding the spoon should open the Barley's Spoon node")
		ok = false
	var before: float = Economy.yards_from_quality(1.0, gs.stats)
	gs.currency = 1e9
	gs.purchase_upgrade("spoon_club")
	var after: float = Economy.yards_from_quality(1.0, gs.stats)
	if not is_equal_approx(after / before, 1.03):
		print("FAIL: spoon node should give carry ×1.03 per level, got ×%.3f" % (after / before))
		ok = false
	var cap_before: int = gs.bucket_capacity
	gs.discover_find("picker_cart")
	if gs.bucket_capacity != cap_before + 2:
		print("FAIL: picker cart should add 2 balls per bucket")
		ok = false
	var cd_before: float = gs.stats.swing_cooldown_ms
	gs.story_triggered["range_bell"] = true
	gs.discover_find("range_bell")
	if not is_equal_approx(gs.stats.swing_cooldown_ms, cd_before * 0.85):
		print("FAIL: bell should shorten swing cooldown")
		ok = false
	gs.discover_find("ratina_bag")
	if not gs.ratina_unlocked:
		print("FAIL: ratina bag should unlock Ratina")
		ok = false
	if ok:
		print("OK: rewards fold into stats (carry, bucket, tempo, crew)")
	return ok


func _check_story_gates() -> bool:
	var ok := true
	var gs := _gs()
	gs.reset_to_fresh()
	gs.upgrade_levels = {"base_pay": 1, "pickup": 8, "combo_bonus": 1}
	gs._recompute_stats()
	if UpgradeGraph.is_unlocked("ball_count"):
		print("FAIL: More Balls should need the picker cart")
		ok = false
	if not UpgradeGraph.lock_hint("ball_count").contains("mist"):
		print("FAIL: lock hint should point into the mist, got ", UpgradeGraph.lock_hint("ball_count"))
		ok = false
	gs.record_carry(130.0)
	gs.discover_find("picker_cart")
	if not UpgradeGraph.is_unlocked("ball_count"):
		print("FAIL: More Balls should unlock after the picker cart")
		ok = false
	if UpgradeGraph.is_revealed("ratina_coaching"):
		print("FAIL: Ratina subtree should be hidden before her bag")
		ok = false
	gs.discover_find("ratina_bag")
	if not UpgradeGraph.is_revealed("ratina_coaching") or not UpgradeGraph.is_unlocked("ratina_coaching"):
		print("FAIL: Ratina subtree should open after her bag")
		ok = false
	if ok:
		print("OK: story gates lock/reveal upgrade nodes")
	return ok


func _check_save_roundtrip() -> bool:
	var ok := true
	var gs := _gs()
	var save: Node = root.get_node("SaveManager")
	gs.reset_to_fresh()
	gs.record_carry(100.0)
	gs.discover_find("scorecard_1")
	gs.discover_find("ratina_bag")
	gs.story_triggered["range_bell"] = true
	gs.story_intro_seen = true
	save.save_game()
	gs.reset_to_fresh()
	save.load_game()
	if not gs.is_find_found("ratina_bag") or not gs.is_find_triggered("range_bell"):
		print("FAIL: story state should persist")
		ok = false
	if not gs.ratina_unlocked or not gs.story_intro_seen:
		print("FAIL: story flags should persist")
		ok = false
	if ok:
		print("OK: story state survives save/load (v%d)" % Balance.SAVE_VERSION)
	return ok


func _check_target_landing() -> bool:
	var ok := true
	var gs := _gs()
	gs.reset_to_fresh()
	gs.tutorial_completed = true
	gs.record_carry(100.0)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var range_view: Node = main.get_node("RangeView")
	var director: Node = range_view.get_story_finds()
	if director == null:
		print("FAIL: RangeView should create the story finds director")
		main.queue_free()
		return false
	if gs.is_find_claimable("range_bell"):
		print("FAIL: bell should not be claimable before it is hit")
		ok = false
	var bell_pos: Vector3 = director.find_world_position("range_bell")
	root.get_node("EventBus").fairway_impact.emit(bell_pos + Vector3(20.0, 0.0, 0.0))
	if gs.is_find_triggered("range_bell"):
		print("FAIL: a far landing should not ring the bell")
		ok = false
	root.get_node("EventBus").fairway_impact.emit(bell_pos + Vector3(3.0, 0.0, -2.0))
	if not gs.is_find_claimable("range_bell"):
		print("FAIL: a landing within the radius should ring the bell")
		ok = false
	if main.get_node_or_null("UI/UIRoot/StoryDialogue") == null:
		print("FAIL: Main should mount StoryDialogue")
		ok = false
	if main.get_node_or_null("StoryEndingLayer/StoryEnding") == null:
		print("FAIL: Main should mount StoryEnding")
		ok = false
	main.queue_free()
	await process_frame
	if ok:
		print("OK: landing balls ring target finds; story UI mounted")
	return ok


func _check_finale() -> bool:
	var ok := true
	var gs := _gs()
	gs.reset_to_fresh()
	gs.record_carry(390.0)
	var shots: Array = []
	var bus: Node = root.get_node("EventBus")
	var on_shot := func() -> void: shots.append(true)
	bus.story_final_shot.connect(on_shot)
	gs.discover_find("first_green")
	if not gs.story_finale_armed:
		print("FAIL: first green should arm the last ball")
		ok = false
	gs.stats.base_yards = 30.0
	var swing: RefCounted = load("res://scripts/game/swing.gd").new()
	swing._resolve_swing(Balance.TimingTier.MISS, 0.1)
	if shots.size() != 1 or gs.story_finale_armed:
		print("FAIL: last ball should fire story_final_shot once and disarm")
		ok = false
	if gs.max_carry_yards() < 380.0:
		print("FAIL: last ball should carry to the green")
		ok = false
	bus.story_final_shot.disconnect(on_shot)
	gs.complete_story()
	if gs.revealed_yards() < 450.0:
		print("FAIL: mist should lift after the ending")
		ok = false
	if ok:
		print("OK: first green → last ball → mist lifts")
	return ok
