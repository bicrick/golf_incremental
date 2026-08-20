extends SceneTree
## Headless portrait layout smoke — content scale sizes + tree aspect flag.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	var portrait := Vector2(270, 480)
	var landscape := Vector2(480, 270)
	var scale_p := UiLayout.content_scale_size_for_viewport(portrait)
	var scale_l := UiLayout.content_scale_size_for_viewport(landscape)
	if scale_p != Vector2i(270, 480):
		push_error("FAIL: portrait content_scale_size got %s" % scale_p)
		ok = false
	else:
		print("OK: portrait content_scale_size=", scale_p)
	if scale_l != Vector2i(480, 270):
		push_error("FAIL: landscape content_scale_size got %s" % scale_l)
		ok = false
	else:
		print("OK: landscape content_scale_size=", scale_l)

	RadialTreeLayout.use_portrait_aspect = true
	var positions := RadialTreeLayout.compute_positions()
	var aspect := RadialTreeLayout.content_aspect(positions)
	print("OK: portrait tree aspect=", snappedf(aspect, 0.01))
	RadialTreeLayout.use_portrait_aspect = false
	positions = RadialTreeLayout.compute_positions()
	aspect = RadialTreeLayout.content_aspect(positions)
	print("OK: landscape tree aspect=", snappedf(aspect, 0.01))

	## Landscape strike framing: KEEP_HEIGHT keeps tee/ball on-screen at 16:9.
	var packed := load("res://scenes/range/range_view.tscn") as PackedScene
	var rv := packed.instantiate()
	root.add_child(rv)
	await process_frame
	await process_frame
	if rv.has_method(&"apply_viewport_aspect"):
		rv.apply_viewport_aspect()
	var cam := rv.get_node_or_null("PerspectiveCamera") as Camera3D
	var ball := rv.get_node_or_null("Bays/PlayerBay/Ball") as Node3D
	if cam == null or ball == null:
		push_error("FAIL: missing PerspectiveCamera or PlayerBay/Ball")
		ok = false
	else:
		if cam.keep_aspect != Camera3D.KEEP_HEIGHT:
			push_error("FAIL: expected KEEP_HEIGHT, got %s" % cam.keep_aspect)
			ok = false
		else:
			print("OK: perspective keep_aspect=KEEP_HEIGHT")
		var ball_screen: Vector2 = cam.unproject_position(ball.global_position)
		var vp_h := root.get_visible_rect().size.y
		if ball_screen.y > vp_h:
			push_error(
				"FAIL: ball below viewport (y=%.1f vp_h=%.1f) — landscape too zoomed"
				% [ball_screen.y, vp_h]
			)
			ok = false
		else:
			print("OK: ball on-screen y=", snappedf(ball_screen.y, 0.1), " vp_h=", vp_h)

	if ok:
		print("OK: verify_portrait_layout")
		quit(0)
	else:
		quit(1)
