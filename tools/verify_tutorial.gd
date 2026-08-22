extends SceneTree
## First-run tutorial overlay — run:
## godot --headless --path . --script res://tools/verify_tutorial.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = (await _check_overlay_present()) and ok
	ok = (await _check_typewriter_and_welcome()) and ok
	ok = _check_migration_existing_player() and ok
	ok = _check_mobile_harvest_copy() and ok
	ok = (await _check_completed_welcome_back()) and ok
	ok = (await _check_beat_advances()) and ok
	ok = _check_preview_builders() and ok
	print("tutorial_ok=", ok)
	quit(0 if ok else 1)


func _gs() -> Node:
	return root.get_node("GameState")


func _bus() -> Node:
	return root.get_node("EventBus")


func _save() -> Node:
	return root.get_node("SaveManager")


func _dismiss_box(box: Node) -> void:
	## Tests bypass slide-out tween and fire dismissed directly.
	if box.has_method("hide_thought"):
		box.hide_thought()
	box.dismissed.emit()


func _check_overlay_present() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var overlay := main.get_node_or_null("UI/UIRoot/TutorialOverlay")
	if overlay == null:
		print("FAIL: TutorialOverlay missing under UIRoot")
		main.queue_free()
		await process_frame
		return false
	if not overlay.is_in_group(&"tutorial_overlay"):
		print("FAIL: TutorialOverlay not in tutorial_overlay group")
		main.queue_free()
		await process_frame
		return false
	var sheet: Texture2D = load("res://assets/sprites/range_rat/rat-speaking-sheet.png")
	if sheet == null:
		print("FAIL: rat-speaking-sheet.png missing")
		main.queue_free()
		await process_frame
		return false
	if sheet.get_width() != 156 or sheet.get_height() != 156:
		print("FAIL: speaking sheet size want 156x156 got %dx%d" % [sheet.get_width(), sheet.get_height()])
		main.queue_free()
		await process_frame
		return false
	print("OK: TutorialOverlay present; speaking sheet 156x156 (7 frames @ 52px)")
	main.queue_free()
	await process_frame
	return true


func _check_typewriter_and_welcome() -> bool:
	var gs := _gs()
	gs.tutorial_completed = false
	gs.tutorial_progress = 0
	gs.lifetime["total_swings"] = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var overlay: Node = main.get_node("UI/UIRoot/TutorialOverlay")
	overlay.begin_if_needed()
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: dialogue should open after begin_if_needed")
		main.queue_free()
		await process_frame
		return false
	var box: Node = overlay.get_node("ThoughtBox")
	var welcome := str(box.get("_full_text"))
	if not welcome.begins_with("Hey") or not welcome.contains("Range Rat"):
		print("FAIL: first pane should welcome, got '%s'" % welcome)
		main.queue_free()
		await process_frame
		return false
	await create_timer(0.15).timeout
	if box.has_method("is_typing") and box.is_typing():
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		box._unhandled_input(key)
		await process_frame
	if box.is_typing():
		print("FAIL: typewriter should complete on Space without remaining typing")
		main.queue_free()
		await process_frame
		return false
	# Advance welcome → hold pane (wait for slide-out then slide-in)
	var key2 := InputEventKey.new()
	key2.keycode = KEY_SPACE
	key2.pressed = true
	box._unhandled_input(key2)
	await create_timer(0.25).timeout
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: Hold pane should follow Welcome")
		main.queue_free()
		await process_frame
		return false
	var hold_text := str(box.get("_full_text"))
	var hold_ok := (
		hold_text.contains("press and hold Space")
		or hold_text.contains("Press and hold Space")
		or hold_text.contains("press and hold")
		or hold_text.contains("Press and hold")
	)
	if not hold_ok:
		print("FAIL: second pane should be Hold (press and hold...), got '%s'" % hold_text)
		main.queue_free()
		await process_frame
		return false
	if box.has_node("ThoughtTail") or box.get("_tail") != null:
		print("FAIL: thought-bubble tail should be removed")
		main.queue_free()
		await process_frame
		return false
	print("OK: typewriter + welcome panes")
	main.queue_free()
	await process_frame
	return true


func _check_migration_existing_player() -> bool:
	var gs := _gs()
	var parsed := {
		"lifetime": {"total_swings": 12},
	}
	gs.lifetime = {"total_swings": 12}
	gs.tutorial_completed = false
	gs.tutorial_progress = 0
	_save()._load_tutorial_flags(parsed)
	if not gs.tutorial_completed:
		print("FAIL: existing save without tutorial keys should complete tutorial")
		return false
	if gs.tutorial_progress < 10:
		print("FAIL: migrated progress should be 10, got %d" % gs.tutorial_progress)
		return false
	parsed = {
		"tutorial_completed": false,
		"tutorial_progress": 1,
		"tutorial_version": 3,
		"lifetime": {"total_swings": 3},
	}
	gs.lifetime = {"total_swings": 3}
	_save()._load_tutorial_flags(parsed)
	if gs.tutorial_completed:
		print("FAIL: explicit tutorial_completed=false should not be overridden")
		return false
	if gs.tutorial_progress != 1:
		print("FAIL: explicit tutorial_progress=1 expected, got %d" % gs.tutorial_progress)
		return false
	# Legacy v1 progress remap (no tutorial_version → treated as v1)
	parsed = {
		"tutorial_completed": false,
		"tutorial_progress": 2,
		"lifetime": {"total_swings": 1},
	}
	gs.lifetime = {"total_swings": 1}
	_save()._load_tutorial_flags(parsed)
	if gs.tutorial_progress != 3:
		print("FAIL: legacy progress 2 should remap to FIRST_BUCKET=3, got %d" % gs.tutorial_progress)
		return false
	parsed = {
		"tutorial_completed": false,
		"tutorial_progress": 3,
		"lifetime": {"total_swings": 1},
	}
	_save()._load_tutorial_flags(parsed)
	if gs.tutorial_progress != 8:
		print("FAIL: legacy progress 3 should remap to HARVEST_RETURN=8, got %d" % gs.tutorial_progress)
		return false
	# v2 completed save bumps final progress to KEEP_GOING
	parsed = {
		"tutorial_completed": true,
		"tutorial_progress": 9,
		"tutorial_version": 2,
		"lifetime": {"total_swings": 5},
	}
	gs.lifetime = {"total_swings": 5}
	_save()._load_tutorial_flags(parsed)
	if not gs.tutorial_completed or gs.tutorial_progress < 10:
		print(
			"FAIL: v2 completed should bump progress to 10, got completed=%s progress=%d"
			% [str(gs.tutorial_completed), gs.tutorial_progress]
		)
		return false
	# Mid-tutorial at UPGRADES (v2/v3) must not soft-lock / force-complete
	parsed = {
		"tutorial_completed": false,
		"tutorial_progress": 9,
		"tutorial_version": 2,
		"lifetime": {"total_swings": 2},
	}
	gs.lifetime = {"total_swings": 2}
	_save()._load_tutorial_flags(parsed)
	if gs.tutorial_completed or gs.tutorial_progress != 9:
		print(
			"FAIL: mid-tutorial UPGRADES save should stay progress=9 incomplete, got completed=%s progress=%d"
			% [str(gs.tutorial_completed), gs.tutorial_progress]
		)
		return false
	print("OK: tutorial migration")
	return true


func _check_mobile_harvest_copy() -> bool:
	var mobile_enter := TutorialCopy.line_for(TutorialCopy.Beat.HARVEST_ENTER, true)
	var desktop_enter := TutorialCopy.line_for(TutorialCopy.Beat.HARVEST_ENTER, false)
	if not mobile_enter.contains("bag"):
		print("FAIL: mobile harvest-enter should mention bag, got '%s'" % mobile_enter)
		return false
	if mobile_enter.contains("down-range") or mobile_enter.contains("Click"):
		print("FAIL: mobile harvest-enter must not say click down-range, got '%s'" % mobile_enter)
		return false
	if not desktop_enter.contains("down-range"):
		print("FAIL: desktop harvest-enter should mention down-range, got '%s'" % desktop_enter)
		return false
	if TutorialCopy.preview_kind_for(TutorialCopy.Beat.HARVEST_ENTER, true) != TutorialUiPreviews.Kind.SHAG_BAG:
		print("FAIL: mobile HARVEST_ENTER should preview SHAG_BAG")
		return false
	if TutorialCopy.preview_kind_for(TutorialCopy.Beat.HARVEST_ENTER, false) != TutorialUiPreviews.Kind.NONE:
		print("FAIL: desktop HARVEST_ENTER should have no preview")
		return false
	var mobile_return := TutorialCopy.line_for(TutorialCopy.Beat.HARVEST_RETURN, true)
	if not mobile_return.contains("bottom-right") and not mobile_return.contains("Tap"):
		print("FAIL: mobile return tip should mention bottom-right tap, got '%s'" % mobile_return)
		return false
	var desktop_find := TutorialCopy.line_for(TutorialCopy.Beat.HARVEST_FIND_HINT, false)
	var mobile_find := TutorialCopy.line_for(TutorialCopy.Beat.HARVEST_FIND_HINT, true)
	if not desktop_find.contains("zoom") or not desktop_find.contains("ring"):
		print("FAIL: desktop find hint should mention zoom + ring, got '%s'" % desktop_find)
		return false
	if not mobile_find.contains("pinch") or not mobile_find.contains("tap"):
		print("FAIL: mobile find hint should mention pinch + tap, got '%s'" % mobile_find)
		return false
	if desktop_find.contains("—") or mobile_find.contains("—"):
		print("FAIL: find hint must not use em dashes")
		return false
	var stuck := TutorialCopy.line_for(TutorialCopy.Beat.UPGRADES_STUCK)
	var spend := TutorialCopy.line_for(TutorialCopy.Beat.UPGRADES_SPEND)
	var upgrades := TutorialCopy.line_for(TutorialCopy.Beat.UPGRADES, true)
	var menu_broke := TutorialCopy.line_for(TutorialCopy.Beat.UPGRADES_MENU_BROKE)
	var menu_click := TutorialCopy.line_for(TutorialCopy.Beat.UPGRADES_MENU_CLICK)
	if stuck.is_empty() or not stuck.contains("stuck"):
		print("FAIL: UPGRADES_STUCK copy missing, got '%s'" % stuck)
		return false
	if spend.is_empty() or not spend.contains("upgrades"):
		print("FAIL: UPGRADES_SPEND copy missing, got '%s'" % spend)
		return false
	if not upgrades.contains("Top-right") or not upgrades.contains("Click"):
		print("FAIL: upgrades CTA should say Top-right + Click, got '%s'" % upgrades)
		return false
	if TutorialCopy.preview_kind_for(TutorialCopy.Beat.UPGRADES_STUCK) != TutorialUiPreviews.Kind.NONE:
		print("FAIL: UPGRADES_STUCK must not show upgrades preview")
		return false
	if TutorialCopy.preview_kind_for(TutorialCopy.Beat.UPGRADES_SPEND) != TutorialUiPreviews.Kind.NONE:
		print("FAIL: UPGRADES_SPEND must not show upgrades preview")
		return false
	if TutorialCopy.preview_kind_for(TutorialCopy.Beat.UPGRADES) != TutorialUiPreviews.Kind.UPGRADES:
		print("FAIL: UPGRADES CTA must preview upgrades button")
		return false
	if not menu_broke.contains("broke") or not menu_broke.contains("upgrade"):
		print("FAIL: menu broke tip missing, got '%s'" % menu_broke)
		return false
	if not menu_click.contains("square"):
		print("FAIL: menu click tip missing, got '%s'" % menu_click)
		return false
	for line in [stuck, spend, upgrades, menu_broke, menu_click]:
		if str(line).contains("—"):
			print("FAIL: upgrades copy must not use em dashes, got '%s'" % line)
			return false
	var keep := TutorialCopy.line_for(TutorialCopy.Beat.KEEP_GOING)
	if not keep.contains("Keep going") or not keep.contains("bucket"):
		print("FAIL: KEEP_GOING copy missing, got '%s'" % keep)
		return false
	print("OK: mobile harvest copy + upgrades comedy + keep-going line")
	return true


func _check_completed_welcome_back() -> bool:
	var gs := _gs()
	gs.tutorial_completed = true
	gs.tutorial_progress = 10
	if TutorialCopy.WELCOME_BACK_LINES.size() < 8:
		print(
			"FAIL: expected ~10 welcome-back lines, got %d"
			% TutorialCopy.WELCOME_BACK_LINES.size()
		)
		return false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var overlay: Node = main.get_node("UI/UIRoot/TutorialOverlay")
	overlay.begin_if_needed()
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: completed tutorial should show welcome-back dialogue")
		main.queue_free()
		await process_frame
		return false
	var box: Node = overlay.get_node("ThoughtBox")
	var line := str(box.get("_full_text"))
	if not TutorialCopy.is_welcome_back_line(line):
		print("FAIL: welcome-back line not in pool, got '%s'" % line)
		main.queue_free()
		await process_frame
		return false
	if not gs.tutorial_completed:
		print("FAIL: welcome-back must not clear tutorial_completed")
		main.queue_free()
		await process_frame
		return false
	# Second begin while open should not stack / restart tutorial.
	overlay.begin_if_needed()
	await process_frame
	if str(box.get("_full_text")) != line:
		print("FAIL: re-begin while open should not replace welcome-back text")
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	if overlay.is_blocking_input():
		print("FAIL: welcome-back dismiss should close dialogue")
		main.queue_free()
		await process_frame
		return false
	if box.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("FAIL: dismissed welcome-back box must IGNORE mouse")
		main.queue_free()
		await process_frame
		return false
	if not gs.tutorial_completed or gs.tutorial_progress != 10:
		print(
			"FAIL: welcome-back must leave tutorial flags alone, got completed=%s progress=%d"
			% [str(gs.tutorial_completed), gs.tutorial_progress]
		)
		main.queue_free()
		await process_frame
		return false
	# After dismiss, another Play-style begin may show again (once per Play).
	overlay.begin_if_needed()
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: second Play begin should show welcome-back again")
		main.queue_free()
		await process_frame
		return false
	var line2 := str(box.get("_full_text"))
	if not TutorialCopy.is_welcome_back_line(line2):
		print("FAIL: second welcome-back not in pool, got '%s'" % line2)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	print("OK: completed shows welcome-back (skips full intro)")
	main.queue_free()
	await process_frame
	return true


func _check_beat_advances() -> bool:
	var gs := _gs()
	var bus := _bus()
	gs.tutorial_completed = false
	gs.tutorial_progress = 1 # HOLD dismissed — awaiting first swing
	gs.tutorial_upgrade_menu_seen = false
	gs.bucket_remaining = 6
	gs.current_phase = "strike"
	gs.upgrade_levels.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var overlay: Node = main.get_node("UI/UIRoot/TutorialOverlay")
	overlay.begin_if_needed()
	await process_frame
	# Perfect first swing → nice shot reaction, then first-bucket tip
	bus.swing_resolved.emit(40.0, Balance.TimingTier.PERFECT, 0.0, 0)
	await create_timer(0.45).timeout
	if not overlay.is_blocking_input():
		print("FAIL: shot reaction should open after first swing")
		main.queue_free()
		await process_frame
		return false
	var box: Node = overlay.get_node("ThoughtBox")
	var reaction := str(box.get("_full_text"))
	if reaction != TutorialCopy.shot_reaction_line(Balance.TimingTier.PERFECT):
		print("FAIL: Perfect first swing should praise, got '%s'" % reaction)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: first-bucket tip should follow shot reaction")
		main.queue_free()
		await process_frame
		return false
	var bucket_tip := str(box.get("_full_text"))
	if not bucket_tip.contains("first bucket"):
		print("FAIL: expected first-bucket tip, got '%s'" % bucket_tip)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	if gs.tutorial_progress != 3:
		print("FAIL: progress should be FIRST_BUCKET=3 after tip, got %d" % gs.tutorial_progress)
		main.queue_free()
		await process_frame
		return false
	# Mid-bucket Perfect must NOT open another praise pane.
	bus.swing_resolved.emit(42.0, Balance.TimingTier.PERFECT, 0.0, 0)
	await create_timer(0.2).timeout
	if overlay.is_blocking_input():
		print("FAIL: mid-bucket Perfect must not interject praise")
		main.queue_free()
		await process_frame
		return false
	# Empty bucket → out-of-balls → harvest enter
	gs.bucket_remaining = 0
	bus.bucket_changed.emit(0, 6)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: out-of-balls pane should open on empty bucket")
		main.queue_free()
		await process_frame
		return false
	var out_text := str(box.get("_full_text"))
	if not out_text.contains("collect") or out_text.contains("Now what") or out_text.contains("What should I"):
		print("FAIL: expected out-of-balls collect copy, got '%s'" % out_text)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: harvest-enter pane should follow out-of-balls")
		main.queue_free()
		await process_frame
		return false
	var enter_text := str(box.get("_full_text"))
	if not enter_text.contains("harvest") and not enter_text.contains("bag"):
		print("FAIL: expected harvest-enter copy, got '%s'" % enter_text)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	if gs.tutorial_progress != 5:
		print("FAIL: progress should be HARVEST_ENTER=5, got %d" % gs.tutorial_progress)
		main.queue_free()
		await process_frame
		return false
	# Harvest phase → pick tip waits for ball_collected (does not block world input)
	gs.current_phase = "harvest"
	bus.phase_changed.emit("harvest")
	await process_frame
	await process_frame
	if not box.is_open():
		print("FAIL: harvest-pick tip should open on harvest enter")
		main.queue_free()
		await process_frame
		return false
	var pick_text := str(box.get("_full_text"))
	if not pick_text.contains("pick") and not pick_text.contains("cursor"):
		print("FAIL: expected harvest-pick copy, got '%s'" % pick_text)
		main.queue_free()
		await process_frame
		return false
	if overlay.is_blocking_input():
		print("FAIL: HARVEST_PICK wait mode must not block world input")
		main.queue_free()
		await process_frame
		return false
	if box.has_method("blocks_world_input") and box.blocks_world_input():
		print("FAIL: ThoughtBox.blocks_world_input should be false during HARVEST_PICK")
		main.queue_free()
		await process_frame
		return false
	if box.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("FAIL: HARVEST_PICK overlay must IGNORE mouse so fairway is clickable")
		main.queue_free()
		await process_frame
		return false
	var panel: Control = box.get_node_or_null("DialoguePanel")
	if panel != null and panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		print("FAIL: HARVEST_PICK DialoguePanel should STOP so tap-on-box can nudge")
		main.queue_free()
		await process_frame
		return false
	# Finish typewriter; Space must not dismiss while waiting for pickup.
	if box.is_typing():
		var space_finish := InputEventKey.new()
		space_finish.keycode = KEY_SPACE
		space_finish.pressed = true
		box._unhandled_input(space_finish)
		await process_frame
	if box.is_typing():
		print("FAIL: Space should finish typewriter during HARVEST_PICK")
		main.queue_free()
		await process_frame
		return false
	# Space while waiting → soft nudge to HARVEST_FIND_HINT (still wait-for-pickup).
	var space_nudge := InputEventKey.new()
	space_nudge.keycode = KEY_SPACE
	space_nudge.pressed = true
	box._unhandled_input(space_nudge)
	await process_frame
	await process_frame
	if not box.is_open():
		print("FAIL: Space must not dismiss HARVEST_PICK before ball_collected")
		main.queue_free()
		await process_frame
		return false
	var find_text := str(box.get("_full_text"))
	if find_text == pick_text:
		print("FAIL: Space during HARVEST_PICK wait should show find hint, still got pick copy")
		main.queue_free()
		await process_frame
		return false
	if not find_text.contains("range") or not find_text.contains("ring"):
		print("FAIL: expected harvest find-hint copy, got '%s'" % find_text)
		main.queue_free()
		await process_frame
		return false
	if overlay.is_blocking_input():
		print("FAIL: find hint must keep wait-for-pickup (no world block)")
		main.queue_free()
		await process_frame
		return false
	if int(overlay.get("_active_beat")) != TutorialCopy.Beat.HARVEST_FIND_HINT:
		print(
			"FAIL: active beat should be HARVEST_FIND_HINT after Space nudge, got %s"
			% str(overlay.get("_active_beat"))
		)
		main.queue_free()
		await process_frame
		return false
	# Second Space while on find hint: stay open, still waiting for pickup.
	box._unhandled_input(space_nudge)
	await process_frame
	if not box.is_open() or str(box.get("_full_text")) != find_text:
		print("FAIL: Space on find hint must not dismiss or leave wait-for-pickup")
		main.queue_free()
		await process_frame
		return false
	print("OK: HARVEST_PICK Space nudge → find hint (still waits for pickup)")
	# Simulated first pickup advances to harvest-done tip (from find hint too).
	bus.ball_collected.emit(Vector3.ZERO, 1)
	await create_timer(0.3).timeout
	await process_frame
	await process_frame
	if not box.is_open():
		print("FAIL: harvest-done tip should open after ball_collected")
		main.queue_free()
		await process_frame
		return false
	if not str(box.get("_full_text")).contains("done picking"):
		print("FAIL: expected harvest-done tip after pickup, got '%s'" % str(box.get("_full_text")))
		main.queue_free()
		await process_frame
		return false
	if not overlay.is_blocking_input():
		print("FAIL: harvest-done should restore click-to-advance blocking")
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	await process_frame
	var return_text := str(box.get("_full_text"))
	if not return_text.contains("bottom-right") and not return_text.contains("bucket"):
		print("FAIL: expected harvest-return tip, got '%s'" % return_text)
		main.queue_free()
		await process_frame
		return false
	if int(box.get("_preview_kind")) != TutorialUiPreviews.Kind.BUCKET:
		print("FAIL: harvest-return should show bucket preview, kind=%s" % str(box.get("_preview_kind")))
		main.queue_free()
		await process_frame
		return false
	if box.get_node_or_null("DialoguePanel") == null:
		print("FAIL: DialoguePanel missing")
		main.queue_free()
		await process_frame
		return false
	var preview_host: Node = box.get("_preview_host")
	if preview_host == null or not preview_host.visible or preview_host.get_child_count() < 1:
		print("FAIL: harvest-return preview host should show a child")
		main.queue_free()
		await process_frame
		return false
	if preview_host.get_child(0).name != "BucketPreview":
		print("FAIL: expected BucketPreview child, got %s" % preview_host.get_child(0).name)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	if gs.tutorial_progress != 8:
		print("FAIL: progress should be HARVEST_RETURN=8, got %d" % gs.tutorial_progress)
		main.queue_free()
		await process_frame
		return false
	# Strike return → upgrades story (stuck → spend → CTA with preview)
	gs.current_phase = "strike"
	bus.phase_changed.emit("strike")
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: upgrades story should open after harvest return")
		main.queue_free()
		await process_frame
		return false
	var stuck_text := str(box.get("_full_text"))
	if not stuck_text.contains("stuck"):
		print("FAIL: first upgrades pane should be stuck beat, got '%s'" % stuck_text)
		main.queue_free()
		await process_frame
		return false
	if int(box.get("_preview_kind")) != TutorialUiPreviews.Kind.NONE:
		print("FAIL: stuck pane must not show upgrades preview")
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: spend pane should follow stuck")
		main.queue_free()
		await process_frame
		return false
	var spend_text := str(box.get("_full_text"))
	if not spend_text.contains("upgrades"):
		print("FAIL: second upgrades pane should be spend beat, got '%s'" % spend_text)
		main.queue_free()
		await process_frame
		return false
	if int(box.get("_preview_kind")) != TutorialUiPreviews.Kind.NONE:
		print("FAIL: spend pane must not show upgrades preview")
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: upgrades CTA should follow spend")
		main.queue_free()
		await process_frame
		return false
	var cta_text := str(box.get("_full_text"))
	if not cta_text.contains("Top-right") or not cta_text.contains("Click"):
		print("FAIL: CTA pane copy missing, got '%s'" % cta_text)
		main.queue_free()
		await process_frame
		return false
	if int(box.get("_preview_kind")) != TutorialUiPreviews.Kind.UPGRADES:
		print("FAIL: upgrades CTA should show upgrades preview, kind=%s" % str(box.get("_preview_kind")))
		main.queue_free()
		await process_frame
		return false
	preview_host = box.get("_preview_host")
	if preview_host == null or not preview_host.visible or preview_host.get_child_count() < 1:
		print("FAIL: upgrades preview host should show a child")
		main.queue_free()
		await process_frame
		return false
	if preview_host.get_child(0).name != "UpgradesPreview":
		print("FAIL: expected UpgradesPreview child, got %s" % preview_host.get_child(0).name)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	if gs.tutorial_completed:
		print("FAIL: dismissing upgrades must NOT complete tutorial yet")
		main.queue_free()
		await process_frame
		return false
	if gs.tutorial_progress != 9:
		print("FAIL: progress should be UPGRADES=9 after tip, got %d" % gs.tutorial_progress)
		main.queue_free()
		await process_frame
		return false
	# First visit inside upgrade menu — dialogue above panel
	gs.tutorial_upgrade_menu_seen = false
	bus.ui_panel_toggled.emit("upgrades", true)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: upgrade menu intro should open on first panel open")
		main.queue_free()
		await process_frame
		return false
	if not overlay.visible:
		print("FAIL: TutorialOverlay must stay visible over UpgradePanel")
		main.queue_free()
		await process_frame
		return false
	var broke_text := str(box.get("_full_text"))
	if not broke_text.contains("broke"):
		print("FAIL: menu intro should be broke beat, got '%s'" % broke_text)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: menu click tip should follow broke")
		main.queue_free()
		await process_frame
		return false
	var click_text := str(box.get("_full_text"))
	if not click_text.contains("square"):
		print("FAIL: expected menu click tip, got '%s'" % click_text)
		main.queue_free()
		await process_frame
		return false
	_dismiss_box(box)
	await process_frame
	if not gs.tutorial_upgrade_menu_seen:
		print("FAIL: dismissing menu click should persist tutorial_upgrade_menu_seen")
		main.queue_free()
		await process_frame
		return false
	# Re-open must not repeat menu intro
	bus.ui_panel_toggled.emit("upgrades", true)
	await process_frame
	await process_frame
	if overlay.is_blocking_input():
		print("FAIL: upgrade menu intro must not repeat")
		main.queue_free()
		await process_frame
		return false
	# First purchase while panel still "open" must not show keep-going yet
	gs.upgrade_levels["sweet_spot"] = 1
	bus.upgrade_purchased.emit("sweet_spot", 1, 0)
	await process_frame
	await process_frame
	if overlay.is_blocking_input():
		print("FAIL: keep-going must wait until upgrades panel closes")
		main.queue_free()
		await process_frame
		return false
	bus.ui_panel_toggled.emit("upgrades", false)
	await process_frame
	await process_frame
	if not overlay.is_blocking_input():
		print("FAIL: keep-going tip should open after first purchase + panel close")
		main.queue_free()
		await process_frame
		return false
	var keep_text := str(box.get("_full_text"))
	if not keep_text.contains("Keep going"):
		print("FAIL: expected keep-going copy, got '%s'" % keep_text)
		main.queue_free()
		await process_frame
		return false
	# Second purchase must not re-open after dismiss
	_dismiss_box(box)
	await process_frame
	if not gs.tutorial_completed:
		print("FAIL: dismissing keep-going should complete tutorial")
		main.queue_free()
		await process_frame
		return false
	if gs.tutorial_progress != 10:
		print("FAIL: completed progress should be KEEP_GOING=10, got %d" % gs.tutorial_progress)
		main.queue_free()
		await process_frame
		return false
	bus.upgrade_purchased.emit("sweet_spot", 2, 0)
	bus.ui_panel_toggled.emit("upgrades", false)
	await process_frame
	if overlay.is_blocking_input():
		print("FAIL: keep-going must not repeat after tutorial completed")
		main.queue_free()
		await process_frame
		return false
	print("OK: beat advances guided flow")
	main.queue_free()
	await process_frame
	return true


func _check_preview_builders() -> bool:
	var upgrades: Control = TutorialUiPreviews.make_upgrades_preview()
	if upgrades == null or upgrades.name != "UpgradesPreview":
		print("FAIL: upgrades preview builder")
		return false
	var slot := upgrades.get_node_or_null("Slot") as Control
	var glyph := upgrades.get_node_or_null("Slot/Glyph") as Control
	if slot == null or glyph == null:
		print("FAIL: upgrades preview missing Slot/Glyph")
		upgrades.free()
		return false
	if slot.custom_minimum_size != Vector2(TutorialUiPreviews.ICON_SIZE):
		print("FAIL: upgrades slot size want %s got %s" % [TutorialUiPreviews.ICON_SIZE, slot.custom_minimum_size])
		upgrades.free()
		return false
	if glyph.custom_minimum_size != Vector2(TutorialUiPreviews.ARROW_GLYPH_SIZE):
		print(
			"FAIL: upgrades glyph size want %s got %s"
			% [TutorialUiPreviews.ARROW_GLYPH_SIZE, glyph.custom_minimum_size]
		)
		upgrades.free()
		return false
	# Centered in slot like icon_bar.tscn (±11 for 22×22 in 24×24).
	var half := float(TutorialUiPreviews.ARROW_GLYPH_SIZE.x) * 0.5
	if (
		not is_equal_approx(glyph.anchor_left, 0.5)
		or not is_equal_approx(glyph.offset_left, -half)
		or not is_equal_approx(glyph.offset_right, half)
	):
		print(
			"FAIL: upgrades glyph not centered in slot (anchors/offsets L=%s R=%s)"
			% [glyph.offset_left, glyph.offset_right]
		)
		upgrades.free()
		return false
	var bucket: Control = TutorialUiPreviews.make_bucket_preview()
	if bucket == null or bucket.name != "BucketPreview":
		print("FAIL: bucket preview builder")
		upgrades.free()
		return false
	var icon := bucket.get_node_or_null("Row/BallIcon") as TextureRect
	if icon == null or icon.texture == null:
		print("FAIL: bucket preview missing ball texture")
		upgrades.free()
		bucket.free()
		return false
	var shag: Control = TutorialUiPreviews.make_shag_bag_preview()
	if shag == null or shag.name != "ShagBagPreview":
		print("FAIL: shag bag preview builder")
		upgrades.free()
		bucket.free()
		return false
	if shag.get_child_count() < 1:
		print("FAIL: shag bag preview missing glyph")
		upgrades.free()
		bucket.free()
		shag.free()
		return false
	if not ResourceLoader.exists("res://assets/ui/shag_bag.png"):
		print("FAIL: shag_bag.png missing")
		upgrades.free()
		bucket.free()
		shag.free()
		return false
	upgrades.free()
	bucket.free()
	shag.free()
	print("OK: preview builders")
	return true
