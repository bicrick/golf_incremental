extends SceneTree
## Headless near-fairway bird tests — run:
## godot --headless --script res://tools/verify_sky_birds.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_frames() and ok
	ok = _check_recolor_and_flip() and ok
	ok = await _check_range_view_director() and ok
	ok = await _check_bird_cycle() and ok
	ok = await _check_species_sticky_across_facing() and ok
	ok = _check_treeline_gate() and ok
	ok = await _check_ground_and_front_bias() and ok
	ok = _check_squawk_assets() and ok
	ok = await _check_golden_and_click_flush() and ok
	print("sky_birds_ok=", ok)
	quit(0 if ok else 1)


func _check_frames() -> bool:
	var frames := SkyBirdFrames.make_frames(SkyBirdFrames.Species.BLUE, false)
	if frames.get_frame_count(&"idle") != SkyBirdFrames.IDLE_FRAME_COUNT:
		print("FAIL: idle frame count wrong")
		return false
	if frames.get_frame_count(&"fly") != SkyBirdFrames.FLY_FRAME_COUNT:
		print("FAIL: fly frame count wrong")
		return false
	if frames.get_frame_count(&"eat") != SkyBirdFrames.EAT_FRAME_COUNT:
		print("FAIL: eat frame count wrong")
		return false
	if frames.get_animation_loop(&"eat"):
		print("FAIL: eat should not loop")
		return false
	print("OK: SkyBirdFrames builds idle, fly, and eat")
	return true


func _check_recolor_and_flip() -> bool:
	var blue := SkyBirdFrames.make_frames(SkyBirdFrames.Species.BLUE, false)
	var sparrow := SkyBirdFrames.make_frames(SkyBirdFrames.Species.SPARROW, false)
	var rust := SkyBirdFrames.make_frames(SkyBirdFrames.Species.RUST, false)
	var golden := SkyBirdFrames.make_frames(SkyBirdFrames.Species.GOLDEN, false)
	var flipped := SkyBirdFrames.make_frames(SkyBirdFrames.Species.BLUE, true)
	var blue_tex := blue.get_frame_texture(&"fly", 0)
	if blue_tex == sparrow.get_frame_texture(&"fly", 0):
		print("FAIL: sparrow recolor should change fly textures")
		return false
	if blue_tex == rust.get_frame_texture(&"fly", 0):
		print("FAIL: rust recolor should change fly textures")
		return false
	if blue_tex == golden.get_frame_texture(&"fly", 0):
		print("FAIL: golden recolor should change fly textures")
		return false
	if blue_tex == flipped.get_frame_texture(&"fly", 0):
		print("FAIL: flipped frames should differ from unflipped")
		return false
	if not _texture_looks_golden(golden.get_frame_texture(&"fly", 0)):
		print("FAIL: golden fly frame should sample warm gold pixels")
		return false
	print("OK: recolors and flip produce distinct textures")
	return true


func _texture_looks_golden(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null:
		return false
	var goldish := 0
	var opaque := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a < 0.5:
				continue
			opaque += 1
			## Warm gold: red high, green mid-high, blue low.
			if p.r > 0.55 and p.g > 0.35 and p.b < p.g * 0.75 and p.r >= p.g:
				goldish += 1
	return opaque > 0 and float(goldish) / float(opaque) >= 0.25


func _check_range_view_director() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var director := range_view.get_node_or_null("AmbientBirds") as RangeBirdDirector
	if director == null:
		print("FAIL: RangeView missing AmbientBirds director")
		range_view.queue_free()
		return false

	if director.get_child_count() < RangeBirdDirector.POOL_SIZE:
		print(
			"FAIL: expected at least %d pooled birds, got %d"
			% [RangeBirdDirector.POOL_SIZE, director.get_child_count()]
		)
		range_view.queue_free()
		return false

	var perch := director.pick_perch()
	if perch.z > RangeBirdDirector.PERCH_Z_NEAR or perch.z < RangeBirdDirector.PERCH_Z_FAR:
		print("FAIL: perch z out of near-fairway band %s" % perch)
		range_view.queue_free()
		return false
	if absf(perch.x) < 5.0:
		print("FAIL: perch too close to centerline %s" % perch)
		range_view.queue_free()
		return false

	var approach := director.pick_approach(perch)
	if approach.y < RangeBirdDirector.MIN_APPROACH_Y - 0.01:
		print("FAIL: approach should start high, got %s" % approach)
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: RangeView has AmbientBirds pool and near-fairway perches")
	return true


func _check_bird_cycle() -> bool:
	var bird := RangeBird.new()
	root.add_child(bird)
	await process_frame

	var from := Vector3(20.0, 12.0, -40.0)
	var perch := Vector3(10.0, 0.05, -50.0)
	bird.start_cycle(from, perch, SkyBirdFrames.Species.BLUE, 4.0)
	if bird.animation != &"fly":
		print("FAIL: approach should play fly, got %s" % bird.animation)
		bird.queue_free()
		return false
	if not bird.visible:
		print("FAIL: approaching bird should be visible")
		bird.queue_free()
		return false

	bird.set_process(false)
	var frames_a: SpriteFrames = bird.sprite_frames
	## Travel toward +X (camera-right fallback) should flip the left-facing atlas.
	bird._face_toward(Vector3(1.0, 0.0, 0.0), true)
	var frames_b: SpriteFrames = bird.sprite_frames
	if frames_a == frames_b:
		print("FAIL: sprite_frames should swap when facing changes")
		bird.queue_free()
		return false
	if not bird.faces_screen_right():
		print("FAIL: moving +X should face screen-right (flipped)")
		bird.queue_free()
		return false
	bird._face_toward(Vector3(-1.0, 0.0, 0.0), true)
	if bird.faces_screen_right():
		print("FAIL: moving -X should face screen-left (unflipped)")
		bird.queue_free()
		return false
	bird.set_process(true)

	bird.takeoff_to(Vector3(18.0, 14.0, -44.0))
	if bird.animation != &"fly":
		print("FAIL: takeoff should play fly")
		bird.queue_free()
		return false

	bird.queue_free()
	print("OK: RangeBird approach / facing / takeoff")
	return true


func _check_species_sticky_across_facing() -> bool:
	var bird := RangeBird.new()
	root.add_child(bird)
	await process_frame

	bird.start_cycle(Vector3(-20.0, 12.0, -40.0), Vector3(-10.0, 0.02, -45.0), SkyBirdFrames.Species.RUST, 4.0)
	var land_tex: Texture2D = bird.sprite_frames.get_frame_texture(bird.animation, 0)
	bird.set_process(false)
	## Same facing as approach (still moving left-ish), then takeoff the other way.
	bird.takeoff_to(Vector3(18.0, 14.0, -40.0))
	var leave_tex: Texture2D = bird.sprite_frames.get_frame_texture(bird.animation, 0)
	var rust := SkyBirdFrames.make_frames(SkyBirdFrames.Species.RUST, bird._using_flipped)
	var leave_expected := rust.get_frame_texture(&"fly", 0)
	if leave_tex != leave_expected:
		print("FAIL: takeoff should keep the landing species textures")
		bird.queue_free()
		return false
	## Reuse pool slot as a different species without changing preferred facing.
	bird._pool()
	bird.start_cycle(Vector3(-20.0, 12.0, -40.0), Vector3(-10.0, 0.02, -45.0), SkyBirdFrames.Species.SPARROW, 4.0)
	var reuse_tex: Texture2D = bird.sprite_frames.get_frame_texture(bird.animation, 0)
	var sparrow := SkyBirdFrames.make_frames(SkyBirdFrames.Species.SPARROW, bird._using_flipped)
	if reuse_tex != sparrow.get_frame_texture(&"fly", 0):
		print("FAIL: reused bird should bind the new species immediately")
		bird.queue_free()
		return false
	if reuse_tex == land_tex:
		print("FAIL: reused bird still showing previous species")
		bird.queue_free()
		return false

	bird.queue_free()
	print("OK: species stays sticky from land through takeoff and pool reuse")
	return true


func _check_treeline_gate() -> bool:
	var high := Vector3(0.0, 12.0, -40.0)
	if not RangeBirdDirector.is_above_treeline(null, high):
		print("FAIL: high point should pass fallback treeline gate")
		return false
	var low := Vector3(0.0, 1.0, -40.0)
	if RangeBirdDirector.is_above_treeline(null, low):
		print("FAIL: low point should fail fallback treeline gate")
		return false
	print("OK: treeline gate rejects low flight without a camera")
	return true


func _check_ground_and_front_bias() -> bool:
	var bird := RangeBird.new()
	root.add_child(bird)
	await process_frame
	if bird.offset.y <= 0.0:
		print("FAIL: bird offset.y should be positive for foot anchoring, got %s" % bird.offset)
		bird.queue_free()
		return false
	if RangeBird.PERCH_Y < 0.0:
		print("FAIL: PERCH_Y must be on or above the ground plane")
		bird.queue_free()
		return false
	bird.queue_free()

	var director := RangeBirdDirector.new()
	root.add_child(director)
	await process_frame

	var near_band := 0
	var samples := 80
	var mid := (RangeBirdDirector.PERCH_Z_NEAR + RangeBirdDirector.PERCH_Z_FAR) * 0.5
	for _i in samples:
		var perch := director.pick_perch()
		if perch.y < RangeBird.PERCH_Y - 0.001:
			print("FAIL: perch under grass %s" % perch)
			director.queue_free()
			return false
		## Nearer the tee = larger (less negative) z.
		if perch.z >= mid:
			near_band += 1
	director.queue_free()
	if near_band < int(samples * 0.58):
		print(
			"FAIL: expected front-biased perches, near_band=%d / %d"
			% [near_band, samples]
		)
		return false
	print("OK: foot-anchored perch Y and front-biased depth (%d/%d near)" % [near_band, samples])
	return true


func _check_squawk_assets() -> bool:
	var paths := BirdSquawkSfx.paths()
	if paths.size() != BirdSquawkSfx.SQUAWK_FILES.size():
		print("FAIL: squawk path count mismatch")
		return false
	for path in paths:
		if not ResourceLoader.exists(path):
			print("FAIL: missing bird squawk asset %s" % path)
			return false
	print("OK: all %d bird squawk assets present" % paths.size())
	return true


func _check_golden_and_click_flush() -> bool:
	var director := RangeBirdDirector.new()
	root.add_child(director)
	await process_frame

	var bird: RangeBird = null
	for child in director.get_children():
		if child is RangeBird:
			bird = child
			break
	if bird == null:
		print("FAIL: director has no RangeBird children")
		director.queue_free()
		return false

	bird.start_cycle(
		Vector3(20.0, 12.0, -40.0),
		Vector3(10.0, 0.02, -45.0),
		SkyBirdFrames.Species.BLUE,
		8.0,
		true
	)
	## Snap to perched so click flush can run without waiting for the approach tween.
	bird._enter_perch()
	if not bird.is_golden:
		print("FAIL: golden flag not set")
		director.queue_free()
		return false
	if bird.species != SkyBirdFrames.Species.GOLDEN:
		print("FAIL: golden spawn should force GOLDEN species frames")
		director.queue_free()
		return false
	if bird.sprite_frames == null or bird.sprite_frames == SkyBirdFrames.make_frames(SkyBirdFrames.Species.BLUE, bird._using_flipped):
		print("FAIL: golden bird still using blue frames")
		director.queue_free()
		return false
	var reward := bird.claim_golden_reward()
	if reward < Balance.GOLDEN_BIRD_BASE_REWARD - 0.01:
		print("FAIL: golden reward too small %s" % reward)
		director.queue_free()
		return false
	if bird.claim_golden_reward() != 0.0:
		print("FAIL: golden reward should only claim once")
		director.queue_free()
		return false

	var gs := root.get_node_or_null("/root/GameState")
	if gs != null and gs.stats != null:
		var stats: PlayerStats = gs.stats
		var saved_base: float = stats.base_amount
		var saved_pay: float = stats.pay_per_yard
		var saved_yards: float = stats.base_yards
		var saved_yard_term: float = stats.yardage_term_unlocked
		var saved_pickup_unlock: float = stats.pickup_bonus_unlocked
		var saved_pickup_mult: float = stats.pickup_multiplier
		var saved_flat: float = stats.pickup_flat_bonus
		var saved_golden_mult: float = stats.golden_ball_payout_multiplier
		stats.base_amount = 12.0
		stats.pay_per_yard = 0.5
		stats.base_yards = 100.0
		stats.yardage_term_unlocked = 1.0
		stats.pickup_bonus_unlocked = 1.0
		stats.pickup_multiplier = 2.0
		stats.pickup_flat_bonus = 1.0
		stats.golden_ball_payout_multiplier = 2.0
		var expected := Economy.resolve_golden_bird_payout(stats)
		var one_ball := Economy.resolve_pickup_ball_payout(1, stats.base_yards, 1, stats)
		if expected < one_ball * Balance.GOLDEN_BIRD_BALL_EQUIVALENT - 0.01:
			print("FAIL: scaled golden bird should beat %s balls (%s < %s)" % [
				Balance.GOLDEN_BIRD_BALL_EQUIVALENT, expected, one_ball
			])
			director.queue_free()
			return false
		bird.start_cycle(
			Vector3(20.0, 12.0, -40.0),
			Vector3(10.0, 0.02, -45.0),
			SkyBirdFrames.Species.BLUE,
			8.0,
			true
		)
		bird._enter_perch()
		var scaled_reward := bird.claim_golden_reward()
		stats.base_amount = saved_base
		stats.pay_per_yard = saved_pay
		stats.base_yards = saved_yards
		stats.yardage_term_unlocked = saved_yard_term
		stats.pickup_bonus_unlocked = saved_pickup_unlock
		stats.pickup_multiplier = saved_pickup_mult
		stats.pickup_flat_bonus = saved_flat
		stats.golden_ball_payout_multiplier = saved_golden_mult
		if absf(scaled_reward - expected) > 0.01:
			print("FAIL: scaled golden reward %s != expected %s" % [scaled_reward, expected])
			director.queue_free()
			return false
		if scaled_reward <= Balance.GOLDEN_BIRD_BASE_REWARD + 0.01:
			print("FAIL: late-game golden reward should exceed early floor")
			director.queue_free()
			return false

	bird.start_cycle(
		Vector3(20.0, 12.0, -40.0),
		Vector3(10.0, 0.02, -45.0),
		SkyBirdFrames.Species.SPARROW,
		8.0,
		false
	)
	bird._enter_perch()
	if not director.has_method("try_harvest_click"):
		print("FAIL: director missing try_harvest_click")
		director.queue_free()
		return false

	director.queue_free()
	print("OK: golden reward + harvest click API")
	return true
