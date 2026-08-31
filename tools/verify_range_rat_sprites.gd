extends SceneTree
## Headless Range Rat sprite sheet tests — run:
## godot --headless --script res://tools/verify_range_rat_sprites.gd

const RangeRat := preload("res://scripts/range/range_rat_sprite_frames.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _test_constants() and ok
	ok = _test_frame_regions() and ok
	ok = _test_sprite_frames() and ok
	ok = _test_idle_anim_switch() and ok
	ok = _test_idle_selection_rule() and ok
	print("range_rat_sprites_ok=%s" % ok)
	quit(0 if ok else 1)


func _test_constants() -> bool:
	var ok := true
	if RangeRat.CONTACT_FRAME != 8:
		print("FAIL: CONTACT_FRAME expected 8, got %d" % RangeRat.CONTACT_FRAME)
		ok = false
	if RangeRat.WINDUP_LAST != 7:
		print("FAIL: WINDUP_LAST expected 7, got %d" % RangeRat.WINDUP_LAST)
		ok = false
	if RangeRat.SWING_FRAME_COUNT != 17:
		print("FAIL: SWING_FRAME_COUNT expected 17, got %d" % RangeRat.SWING_FRAME_COUNT)
		ok = false
	if RangeRat.IDLE_FRAME_COUNT != 17:
		print("FAIL: IDLE_FRAME_COUNT expected 17, got %d" % RangeRat.IDLE_FRAME_COUNT)
		ok = false
	if RangeRat.IDLE_COLS != 5:
		print("FAIL: IDLE_COLS expected 5, got %d" % RangeRat.IDLE_COLS)
		ok = false
	if RangeRat.IDLE_OUT_OF_BALLS_FRAME_COUNT != 17:
		print(
			"FAIL: IDLE_OUT_OF_BALLS_FRAME_COUNT expected 17, got %d"
			% RangeRat.IDLE_OUT_OF_BALLS_FRAME_COUNT
		)
		ok = false
	if RangeRat.RETURN_FRAME_COUNT != 7:
		print("FAIL: RETURN_FRAME_COUNT expected 7, got %d" % RangeRat.RETURN_FRAME_COUNT)
		ok = false
	return ok


func _test_frame_regions() -> bool:
	var ok := true
	var contact := RangeRat.frame_region(RangeRat.SWING_COLS, RangeRat.CONTACT_FRAME)
	if contact != Rect2i(156, 52, 52, 52):
		print("FAIL: contact region expected Rect2i(156, 52, 52, 52), got %s" % contact)
		ok = false
	var idle_last := RangeRat.frame_region(RangeRat.IDLE_COLS, RangeRat.IDLE_FRAME_COUNT - 1)
	if idle_last != Rect2i(52, 156, 52, 52):
		print("FAIL: idle frame 17 region expected Rect2i(52, 156, 52, 52), got %s" % idle_last)
		ok = false
	var oob_last := RangeRat.frame_region(
		RangeRat.IDLE_OUT_OF_BALLS_COLS, RangeRat.IDLE_OUT_OF_BALLS_FRAME_COUNT - 1
	)
	if oob_last != Rect2i(52, 156, 52, 52):
		print("FAIL: idle_out_of_balls frame 17 region expected Rect2i(52, 156, 52, 52), got %s" % oob_last)
		ok = false
	return ok


func _test_sprite_frames() -> bool:
	var ok := true
	var frames := RangeRat.make_golfer_frames()
	if frames.get_frame_count(&"idle") != RangeRat.IDLE_FRAME_COUNT:
		print(
			"FAIL: idle animation has %d frames, expected %d"
			% [frames.get_frame_count(&"idle"), RangeRat.IDLE_FRAME_COUNT]
		)
		ok = false
	if not frames.get_animation_loop(&"idle"):
		print("FAIL: idle animation should loop")
		ok = false
	if frames.get_animation_speed(&"idle") != RangeRat.IDLE_FPS:
		print(
			"FAIL: idle speed expected %.1f, got %.1f"
			% [RangeRat.IDLE_FPS, frames.get_animation_speed(&"idle")]
		)
		ok = false
	if frames.get_frame_count(&"idle_out_of_balls") != RangeRat.IDLE_OUT_OF_BALLS_FRAME_COUNT:
		print(
			"FAIL: idle_out_of_balls has %d frames, expected %d"
			% [frames.get_frame_count(&"idle_out_of_balls"), RangeRat.IDLE_OUT_OF_BALLS_FRAME_COUNT]
		)
		ok = false
	if not frames.get_animation_loop(&"idle_out_of_balls"):
		print("FAIL: idle_out_of_balls animation should loop")
		ok = false
	if frames.get_animation_speed(&"idle_out_of_balls") != RangeRat.IDLE_OUT_OF_BALLS_FPS:
		print(
			"FAIL: idle_out_of_balls speed expected %.1f, got %.1f"
			% [RangeRat.IDLE_OUT_OF_BALLS_FPS, frames.get_animation_speed(&"idle_out_of_balls")]
		)
		ok = false
	if frames.get_frame_count(&"swing") != RangeRat.SWING_FRAME_COUNT:
		print(
			"FAIL: swing animation has %d frames, expected %d"
			% [frames.get_frame_count(&"swing"), RangeRat.SWING_FRAME_COUNT]
		)
		ok = false
	var follow_count := RangeRat.FOLLOW_END - RangeRat.FOLLOW_START + 1
	if frames.get_frame_count(&"follow") != follow_count:
		print(
			"FAIL: follow animation has %d frames, expected %d"
			% [frames.get_frame_count(&"follow"), follow_count]
		)
		ok = false
	var idle_tex: Texture2D = frames.get_frame_texture(&"idle", 0)
	if idle_tex == null:
		print("FAIL: idle frame 0 texture is null")
		ok = false
	var swing_tex: Texture2D = frames.get_frame_texture(&"swing", RangeRat.CONTACT_FRAME)
	if swing_tex == null:
		print("FAIL: swing contact frame texture is null")
		ok = false
	var oob_tex: Texture2D = frames.get_frame_texture(&"idle_out_of_balls", 0)
	if oob_tex == null:
		print("FAIL: idle_out_of_balls frame 0 texture is null")
		ok = false
	if frames.get_frame_count(&"return_to_address") != RangeRat.RETURN_FRAME_COUNT:
		print(
			"FAIL: return_to_address has %d frames, expected %d"
			% [frames.get_frame_count(&"return_to_address"), RangeRat.RETURN_FRAME_COUNT]
		)
		ok = false
	if frames.get_animation_loop(&"return_to_address"):
		print("FAIL: return_to_address animation should not loop")
		ok = false
	if frames.get_animation_speed(&"return_to_address") != RangeRat.RETURN_FPS:
		print(
			"FAIL: return_to_address speed expected %.1f, got %.1f"
			% [RangeRat.RETURN_FPS, frames.get_animation_speed(&"return_to_address")]
		)
		ok = false
	var return_tex: Texture2D = frames.get_frame_texture(&"return_to_address", 0)
	if return_tex == null:
		print("FAIL: return_to_address frame 0 texture is null")
		ok = false
	return ok


func _test_idle_anim_switch() -> bool:
	var ok := true
	var frames := RangeRat.make_golfer_frames()
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.play(&"idle_out_of_balls")
	if sprite.animation != &"idle_out_of_balls":
		print(
			"FAIL: expected idle_out_of_balls after play, got %s" % String(sprite.animation)
		)
		ok = false
	sprite.stop()
	sprite.play(&"idle")
	if sprite.animation != &"idle":
		print("FAIL: expected idle after switch from idle_out_of_balls, got %s" % String(sprite.animation))
		ok = false
	if not sprite.is_playing():
		print("FAIL: idle animation should be playing after switch")
		ok = false
	sprite.free()
	return ok


func _test_idle_selection_rule() -> bool:
	var ok := true
	# Mirrors range_view._golfer_idle_anim() + GameState.has_bucket_balls().
	var cases: Array[Dictionary] = [
		{"phase": "strike", "remaining": 3, "expected": &"idle"},
		{"phase": "strike", "remaining": 0, "expected": &"idle_out_of_balls"},
		{"phase": "harvest", "remaining": 6, "expected": &"idle_out_of_balls"},
		{"phase": "harvest", "remaining": 0, "expected": &"idle_out_of_balls"},
	]
	for entry in cases:
		var has_balls: bool = entry["phase"] == "strike" and int(entry["remaining"]) > 0
		var anim: StringName = &"idle" if has_balls else &"idle_out_of_balls"
		if anim != entry["expected"]:
			print(
				"FAIL: phase=%s remaining=%d expected %s, got %s"
				% [entry["phase"], entry["remaining"], entry["expected"], anim]
			)
			ok = false
	return ok
