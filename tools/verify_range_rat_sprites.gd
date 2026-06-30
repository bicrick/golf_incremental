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
	if RangeRat.IDLE_FRAME_COUNT != 5:
		print("FAIL: IDLE_FRAME_COUNT expected 5, got %d" % RangeRat.IDLE_FRAME_COUNT)
		ok = false
	return ok


func _test_frame_regions() -> bool:
	var ok := true
	var contact := RangeRat.frame_region(RangeRat.SWING_COLS, RangeRat.CONTACT_FRAME)
	if contact != Rect2i(156, 52, 52, 52):
		print("FAIL: contact region expected Rect2i(156, 52, 52, 52), got %s" % contact)
		ok = false
	var idle_last := RangeRat.frame_region(RangeRat.IDLE_COLS, RangeRat.IDLE_FRAME_COUNT - 1)
	if idle_last != Rect2i(52, 52, 52, 52):
		print("FAIL: idle frame 5 region expected Rect2i(52, 52, 52, 52), got %s" % idle_last)
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
	return ok
