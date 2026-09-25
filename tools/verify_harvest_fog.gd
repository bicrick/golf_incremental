extends SceneTree
## Headless harvest fog of war tests — run:
## godot --headless --script res://tools/verify_harvest_fog.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_save()
	var ok := true
	ok = _check_reveal_formula() and ok
	ok = _check_record_carry() and ok
	ok = _check_old_save_seed() and ok
	ok = _check_picker_blocked_ground() and ok
	ok = await _check_fog_amount_strike_vs_harvest() and ok
	_cleanup_save()
	print("harvest_fog_ok=", ok)
	quit(0 if ok else 1)


func _cleanup_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")


func _check_reveal_formula() -> bool:
	var gs: Node = root.get_node("GameState")
	gs.reset_to_fresh()
	if not is_equal_approx(gs.max_carry_yards(), 0.0):
		print("FAIL: fresh max_carry expected 0")
		return false
	if not is_equal_approx(gs.revealed_yards(), Balance.HARVEST_FOG_MIN_REVEAL_YARDS):
		print(
			"FAIL: fresh reveal expected %.1f, got %.1f"
			% [Balance.HARVEST_FOG_MIN_REVEAL_YARDS, gs.revealed_yards()]
		)
		return false
	gs.lifetime["max_carry_yards"] = 40.0
	var expected := 40.0 + Balance.HARVEST_FOG_BUFFER_YARDS
	if not is_equal_approx(gs.revealed_yards(), expected):
		print("FAIL: reveal expected %.1f, got %.1f" % [expected, gs.revealed_yards()])
		return false
	print("OK: reveal formula (min pad + buffer past max carry)")
	return true


func _check_record_carry() -> bool:
	var gs: Node = root.get_node("GameState")
	var bus: Node = root.get_node("EventBus")
	gs.reset_to_fresh()
	var emitted: Array = []
	var on_changed := func(yards: float) -> void:
		emitted.append(yards)
	bus.max_carry_changed.connect(on_changed)
	gs.record_carry(25.0)
	gs.record_carry(20.0)
	gs.record_carry(32.5)
	bus.max_carry_changed.disconnect(on_changed)
	if emitted.size() != 2:
		print("FAIL: expected 2 max_carry_changed emissions, got ", emitted.size())
		return false
	if not is_equal_approx(float(emitted[0]), 25.0) or not is_equal_approx(float(emitted[1]), 32.5):
		print("FAIL: unexpected carry emissions ", emitted)
		return false
	if not is_equal_approx(gs.max_carry_yards(), 32.5):
		print("FAIL: max_carry expected 32.5, got ", gs.max_carry_yards())
		return false
	print("OK: record_carry updates + emits only on personal best")
	return true


func _check_old_save_seed() -> bool:
	var gs: Node = root.get_node("GameState")
	gs.reset_to_fresh()
	gs.lifetime = {
		"total_swings": 12,
		"lifetime_yards": 300.0,
		"lifetime_earnings": 10.0,
		"ratina_lifetime_earnings": 0.0,
		"rattling_lifetime_earnings": 0.0,
		"perfect_count": 1,
	}
	gs.stats.base_yards = 42.0
	gs.seed_max_carry_from_progress()
	if not is_equal_approx(gs.max_carry_yards(), 42.0):
		print(
			"FAIL: old-save seed expected base_yards 42, got ",
			gs.max_carry_yards()
		)
		return false
	# Second call must not overwrite an existing key.
	gs.lifetime["max_carry_yards"] = 55.0
	gs.seed_max_carry_from_progress()
	if not is_equal_approx(gs.max_carry_yards(), 55.0):
		print("FAIL: seed should no-op when max_carry_yards already set")
		return false
	print("OK: old-save max_carry seed from base_yards")
	return true


func _check_picker_blocked_ground() -> bool:
	var on_fairway := Vector3(0.0, 0.0, -40.0)
	var off_side := Vector3(RangeGrid.HALF_WIDTH_YARDS + 2.0, 0.0, -40.0)
	var fog_state := {"active": true, "tee_z": -10.0, "reveal_yards": 51.0}
	if not RangePickerIndicator.is_on_fairway(on_fairway):
		print("FAIL: -40z midline should be on fairway")
		return false
	if RangePickerIndicator.is_on_fairway(off_side):
		print("FAIL: past half-width should be off fairway")
		return false
	if RangePickerIndicator.is_blocked_ground(off_side, fog_state) != true:
		print("FAIL: off-map should be blocked")
		return false
	# Tip on clear grass just shy of reveal must stay pickable (ring, not X).
	var clear_spot := Vector3(0.0, 0.0, -10.0 - 50.0) # 50yd; reveal 51
	var fog_spot := Vector3(0.0, 0.0, -10.0 - 80.0) # 80yd past reveal 51
	if RangePickerIndicator.is_blocked_ground(clear_spot, fog_state):
		print("FAIL: clear fairway just before reveal should not be blocked")
		return false
	if not RangePickerIndicator.is_in_harvest_fog(clear_spot, -10.0, 51.0) \
		and RangePickerIndicator.is_blocked_ground(
			Vector3(0.0, 0.0, -10.0 - 51.0), fog_state
		) != true:
		print("FAIL: tip exactly at reveal should be blocked fog")
		return false
	if not RangePickerIndicator.is_blocked_ground(fog_spot, fog_state):
		print("FAIL: past reveal should be blocked fog")
		return false
	if RangePickerIndicator.is_blocked_ground(clear_spot, {"active": false}):
		print("FAIL: inactive fog should not block clear fairway")
		return false
	print("OK: picker blocks off-map and fog ground")
	return true


func _check_fog_amount_strike_vs_harvest() -> bool:
	_cleanup_save()
	var gs: Node = root.get_node("GameState")
	gs.reset_to_fresh()
	gs.tutorial_completed = true
	gs.tutorial_progress = 10
	gs.lifetime["max_carry_yards"] = 50.0

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if main.has_method("_on_play_transition_started"):
		main._on_play_transition_started()
	main._on_play_pressed()
	await process_frame
	await process_frame

	var range_view: Node3D = main.get_node_or_null("RangeView")
	if range_view == null:
		print("FAIL: RangeView missing")
		main.queue_free()
		return false
	var fog: RefCounted = range_view.get("_harvest_fog")
	if fog == null:
		print("FAIL: harvest fog controller missing")
		main.queue_free()
		return false

	# Strike: fog_amount must stay at 0.
	for _i in 8:
		await process_frame
	if fog.fog_amount() > 0.001:
		print("FAIL: fog_amount should be 0 in strike, got ", fog.fog_amount())
		main.queue_free()
		return false

	var ground: MeshInstance3D = range_view.get_node("Ground")
	var mat := ground.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		print("FAIL: Ground missing ShaderMaterial")
		main.queue_free()
		return false
	## v5: the mist bank is visible from the tee too (StrikeMist), at a softer
	## ground amount — fog_amount() (the "in harvest" signal) stays 0.
	var strike_amt: float = float(mat.get_shader_parameter(&"fog_amount"))
	if absf(strike_amt - fog.STRIKE_GROUND_FOG) > 0.05:
		print("FAIL: Ground fog uniform in strike should be the strike mist %.2f, got %.2f" % [fog.STRIKE_GROUND_FOG, strike_amt])
		main.queue_free()
		return false

	gs.fairway_litter_count = 1
	if not gs.try_enter_harvest():
		print("FAIL: try_enter_harvest failed")
		main.queue_free()
		return false
	await _wait_harvest_ready(range_view, 600)
	if not range_view.is_harvest_view_ready():
		print("FAIL: harvest view never ready")
		main.queue_free()
		return false

	# Fog must already be fully on — no green→mist fade-in.
	await process_frame
	if fog.fog_amount() < 0.99:
		print("FAIL: fog_amount should snap to 1 on harvest enter, got ", fog.fog_amount())
		main.queue_free()
		return false

	var harvest_amt: float = float(mat.get_shader_parameter(&"fog_amount"))
	if harvest_amt < 0.99:
		print("FAIL: Ground fog_amount uniform should be ~1 immediately, got ", harvest_amt)
		main.queue_free()
		return false
	var reveal: float = float(mat.get_shader_parameter(&"reveal_yards"))
	var expected_reveal: float = float(gs.revealed_yards())
	if absf(reveal - expected_reveal) > 1.0:
		print(
			"FAIL: reveal_yards uniform expected ~%.1f, got %.1f"
			% [expected_reveal, reveal]
		)
		main.queue_free()
		return false

	# Fog yards must be measured from world tee (bay origin), not bay-local z≈0.
	var tee_z: float = float(mat.get_shader_parameter(&"tee_z"))
	var expected_tee_z: float = RangeGrid.player_bay_origin().z
	if absf(tee_z - expected_tee_z) > 2.0:
		print(
			"FAIL: tee_z should be world bay origin ~%.1f, got %.1f (local z would look early)"
			% [expected_tee_z, tee_z]
		)
		main.queue_free()
		return false

	var label: Label3D = fog.max_carry_label()
	if label == null or not is_instance_valid(label):
		print("FAIL: max carry label missing")
		main.queue_free()
		return false
	if not label.visible:
		print("FAIL: max carry label should show in harvest when max_carry > 0")
		main.queue_free()
		return false
	if label.text != "50 yd":
		print("FAIL: max carry label text expected '50 yd', got ", label.text)
		main.queue_free()
		return false
	if label.outline_size > 3:
		print("FAIL: max carry label outline should stay thin, got ", label.outline_size)
		main.queue_free()
		return false
	if label.pixel_size > 0.018:
		print("FAIL: max carry label should stay small, pixel_size=", label.pixel_size)
		main.queue_free()
		return false
	var expected_z: float = tee_z - 50.0
	if absf(label.position.z - expected_z) > 0.6:
		print(
			"FAIL: max carry label z expected ~%.1f, got %.1f"
			% [expected_z, label.position.z]
		)
		main.queue_free()
		return false
	if label.position.x < 18.0:
		print("FAIL: max carry label should sit on the right edge, x=", label.position.x)
		main.queue_free()
		return false

	# Birds past the reveal line should take the mist modulate.
	var director: RangeBirdDirector = range_view.get_node_or_null("AmbientBirds") as RangeBirdDirector
	if director == null:
		print("FAIL: AmbientBirds missing for bird fog check")
		main.queue_free()
		return false
	if fog.get("_bird_director") == null:
		print("FAIL: harvest fog missing bird director wiring")
		main.queue_free()
		return false
	var pool: Array = director.birds()
	if pool.size() < 2:
		print("FAIL: need at least 2 pooled birds")
		main.queue_free()
		return false
	var clear_bird: RangeBird = pool[0]
	var fog_bird: RangeBird = pool[1]
	clear_bird.apply_atmosphere_tint(Color.WHITE)
	fog_bird.apply_atmosphere_tint(Color.WHITE)
	clear_bird.start_cycle(
		Vector3(10.0, 12.0, tee_z - 10.0),
		Vector3(10.0, 0.02, tee_z - 10.0),
		SkyBirdFrames.Species.BLUE,
		8.0
	)
	fog_bird.start_cycle(
		Vector3(12.0, 12.0, tee_z - 120.0),
		Vector3(12.0, 0.02, tee_z - 120.0),
		SkyBirdFrames.Species.BLUE,
		8.0
	)
	clear_bird.position = Vector3(10.0, 0.02, tee_z - 10.0)
	fog_bird.position = Vector3(12.0, 0.02, tee_z - 120.0)
	## Snap to perch so clickable() reflects fog gating, not approach state.
	clear_bird._enter_perch()
	fog_bird._enter_perch()
	fog._apply_bird_modulates()
	if clear_bird.modulate.is_equal_approx(fog_bird.modulate):
		print(
			"FAIL: fogged bird should differ from clear bird clear=",
			clear_bird.modulate,
			" fog=",
			fog_bird.modulate,
			" reveal=",
			fog.displayed_reveal_yards()
		)
		main.queue_free()
		return false
	if fog_bird.modulate.a >= 0.55:
		print(
			"FAIL: fogged bird should dissolve into mist (low alpha), got a=",
			fog_bird.modulate.a
		)
		main.queue_free()
		return false
	if clear_bird.modulate.a < 0.99:
		print("FAIL: clear bird should stay opaque, got a=", clear_bird.modulate.a)
		main.queue_free()
		return false
	if fog_bird.is_clickable():
		print("FAIL: fogged bird should not be clickable")
		main.queue_free()
		return false
	if not clear_bird.is_clickable():
		print("FAIL: clear perched bird should be clickable")
		main.queue_free()
		return false
	## Fog wash pulls RGB toward harvest fog color (not just a dark silhouette).
	var fog_col: Color = fog.get("_fog_color")
	var wash := (
		absf(fog_bird.modulate.r - fog_col.r)
		+ absf(fog_bird.modulate.g - fog_col.g)
		+ absf(fog_bird.modulate.b - fog_col.b)
	) / 3.0
	if wash > 0.28:
		print(
			"FAIL: fogged bird RGB should wash toward fog color, wash=",
			wash,
			" bird=",
			fog_bird.modulate,
			" fog=",
			fog_col
		)
		main.queue_free()
		return false
	clear_bird.clear_harvest_fog()
	fog_bird.clear_harvest_fog()

	gs.exit_harvest_early()
	var deadline_msec := Time.get_ticks_msec() + 800
	while fog.fog_amount() > 0.05 and Time.get_ticks_msec() < deadline_msec:
		await process_frame
	if fog.fog_amount() > 0.05:
		print("FAIL: fog_amount should fade out on strike return, got ", fog.fog_amount())
		main.queue_free()
		return false

	main.queue_free()
	await process_frame
	print("OK: fog snaps on harvest enter; clears on strike return")
	return true


func _wait_harvest_ready(range_view: Node3D, timeout_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if range_view.has_method("is_harvest_view_ready") and range_view.is_harvest_view_ready():
			return
		await process_frame
