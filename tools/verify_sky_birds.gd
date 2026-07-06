extends SceneTree
## Headless sky bird tests — run:
## godot --headless --script res://tools/verify_sky_birds.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	ok = _check_frames() and ok
	ok = await _check_range_view_bird() and ok
	ok = await _check_direction_swap() and ok
	print("sky_birds_ok=", ok)
	quit(0 if ok else 1)


func _check_frames() -> bool:
	var normal := SkyBirdFrames.make_fly_frames(false)
	var flipped := SkyBirdFrames.make_fly_frames(true)
	if normal.get_frame_count(&"fly") != SkyBirdFrames.FLY_FRAME_COUNT:
		print("FAIL: normal fly frame count wrong")
		return false
	if flipped.get_frame_count(&"fly") != SkyBirdFrames.FLY_FRAME_COUNT:
		print("FAIL: flipped fly frame count wrong")
		return false
	if normal.get_frame_texture(&"fly", 0) == flipped.get_frame_texture(&"fly", 0):
		print("FAIL: normal and flipped should use different frame textures")
		return false
	print("OK: SkyBirdFrames builds distinct normal and flipped fly cycles")
	return true


func _check_range_view_bird() -> bool:
	var scene: PackedScene = load("res://scenes/range/range_view.tscn")
	if scene == null:
		print("FAIL: could not load range_view.tscn")
		return false

	var range_view: Node3D = scene.instantiate()
	root.add_child(range_view)
	range_view.visible = true
	await process_frame

	var bird := range_view.get_node_or_null("SkyBird") as AnimatedSprite3D
	if bird == null:
		print("FAIL: RangeView missing SkyBird AnimatedSprite3D")
		range_view.queue_free()
		return false

	if bird.animation != &"fly":
		print("FAIL: SkyBird animation should be fly, got %s" % bird.animation)
		range_view.queue_free()
		return false

	if bird.sprite_frames == null or bird.sprite_frames.get_frame_count(&"fly") == 0:
		print("FAIL: SkyBird missing fly sprite frames after _ready")
		range_view.queue_free()
		return false

	if not is_equal_approx(bird.position.z, -25.0):
		print("FAIL: SkyBird should start at z=-25, got %s" % bird.position)
		range_view.queue_free()
		return false

	range_view.queue_free()
	print("OK: range_view has SkyBird with fly animation at z=-25")
	return true


func _check_direction_swap() -> bool:
	var bird := load("res://scripts/visual/sky_bird.gd").new() as AnimatedSprite3D
	root.add_child(bird)
	await process_frame

	var frames_left: SpriteFrames = bird.sprite_frames
	bird._direction = 1.0
	bird._apply_facing(true)
	await process_frame
	var frames_right: SpriteFrames = bird.sprite_frames
	if frames_left == frames_right:
		print("FAIL: sprite_frames should swap when direction changes")
		bird.queue_free()
		return false

	bird.queue_free()
	print("OK: SkyBird swaps texture set when direction changes")
	return true
