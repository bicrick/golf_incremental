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
		if not await _verify_strike_dolly(rv, cam, ball):
			ok = false
		if not await _verify_strike_feedback_portrait(rv, cam):
			ok = false

	if not await _verify_upgrade_panel_portrait():
		ok = false

	if ok:
		print("OK: verify_portrait_layout")
		quit(0)
	else:
		quit(1)


func _set_logical_size(size: Vector2i) -> void:
	var win := root as Window
	if win == null:
		return
	win.content_scale_size = size
	win.size = size
	if win.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func _verify_strike_dolly(rv: Node, cam: Camera3D, ball: Node3D) -> bool:
	var home: Transform3D = cam.transform
	if rv.has_method(&"perspective_home_transform"):
		home = rv.call(&"perspective_home_transform")
	var home_pos := home.origin
	var back_dir := home.basis.z
	var authored_fov := cam.fov

	_set_logical_size(Vector2i(480, 270))
	await process_frame
	if rv.has_method(&"apply_viewport_aspect"):
		rv.apply_viewport_aspect()
	if not cam.position.is_equal_approx(home_pos):
		push_error("FAIL: landscape strike camera left authored pose")
		return false
	if not is_equal_approx(cam.fov, authored_fov):
		push_error("FAIL: landscape FOV changed (%s -> %s)" % [authored_fov, cam.fov])
		return false
	if cam.keep_aspect != Camera3D.KEEP_HEIGHT:
		push_error("FAIL: landscape keep_aspect left KEEP_HEIGHT")
		return false
	print("OK: landscape strike camera at authored pose")

	_set_logical_size(Vector2i(270, 480))
	await process_frame
	if rv.has_method(&"apply_viewport_aspect"):
		rv.apply_viewport_aspect()
	var dolly := cam.position - home_pos
	var along := dolly.dot(back_dir)
	var lateral := (dolly - back_dir * along).length()
	if along < 0.60 or along > 0.75:
		push_error(
			"FAIL: portrait dolly along look-back=%s (want ~0.67)" % snappedf(along, 0.01)
		)
		return false
	if lateral > 0.05:
		push_error("FAIL: portrait dolly left the look line (lateral=%s)" % snappedf(lateral, 0.01))
		return false
	if not is_equal_approx(cam.fov, authored_fov):
		push_error("FAIL: portrait FOV changed (%s -> %s)" % [authored_fov, cam.fov])
		return false
	if cam.keep_aspect != Camera3D.KEEP_HEIGHT:
		push_error("FAIL: portrait keep_aspect left KEEP_HEIGHT")
		return false
	var ball_screen: Vector2 = cam.unproject_position(ball.global_position)
	var vp := root.get_visible_rect().size
	if ball_screen.y > vp.y or ball_screen.x < 0.0 or ball_screen.x > vp.x:
		push_error(
			"FAIL: portrait ball off-screen (%s) vp=%s" % [ball_screen, vp]
		)
		return false
	print(
		"OK: portrait strike dolly-back=",
		snappedf(along, 0.01),
		" fov=",
		authored_fov
	)

	_set_logical_size(Vector2i(480, 270))
	await process_frame
	if rv.has_method(&"apply_viewport_aspect"):
		rv.apply_viewport_aspect()
	if not cam.position.is_equal_approx(home_pos):
		push_error("FAIL: landscape did not restore authored strike pose")
		return false
	print("OK: landscape restored authored strike pose")
	return true


func _find_strike_feedback_sprite(rv: Node) -> Sprite3D:
	var anchor := rv.get_node_or_null("StrikeFeedbackAnchor")
	if anchor == null:
		return null
	for child in anchor.get_children():
		if not child is Node3D:
			continue
		for grand in child.get_children():
			if grand is Sprite3D:
				return grand
	return null


func _verify_strike_feedback_portrait(rv: Node, cam: Camera3D) -> bool:
	_set_logical_size(Vector2i(270, 480))
	await process_frame
	if rv.has_method(&"apply_viewport_aspect"):
		rv.apply_viewport_aspect()
	await process_frame
	await process_frame

	var sprite := _find_strike_feedback_sprite(rv)
	if sprite == null:
		push_error("FAIL: strike feedback Sprite3D missing")
		return false

	var want_ps := (
		StrikeFeedbackBillboard.DEFAULT_PIXEL_SIZE * StrikeFeedbackBillboard.PORTRAIT_SCALE
	)
	if not is_equal_approx(sprite.pixel_size, want_ps):
		push_error(
			"FAIL: portrait strike feedback pixel_size=%s want %s"
			% [sprite.pixel_size, want_ps]
		)
		return false

	if cam.is_position_behind(sprite.global_position):
		push_error("FAIL: portrait strike feedback behind camera")
		return false
	var screen: Vector2 = cam.unproject_position(sprite.global_position)
	var vp := root.get_visible_rect().size
	var frac_x := screen.x / vp.x
	## Target is 0.67; clamp may pull in a bit so the full "xxx.x yds" fits.
	if frac_x < 0.58 or frac_x > 0.78:
		push_error(
			"FAIL: portrait strike feedback x-frac=%s (want ~0.62-0.72)"
			% snappedf(frac_x, 0.01)
		)
		return false
	var half_w := (
		StrikeFeedbackBillboard.LABEL_HALF_WIDTH_PX * sprite.pixel_size
	)
	var right_pt: Vector3 = sprite.global_position + cam.global_transform.basis.x * half_w
	if not cam.is_position_behind(right_pt):
		var right_s: Vector2 = cam.unproject_position(right_pt)
		var margin := StrikeFeedbackBillboard.PORTRAIT_MARGIN_PX
		if right_s.x > vp.x - margin + 0.5:
			push_error(
				"FAIL: portrait yards clip right edge (x=%.1f vp=%.1f)"
				% [right_s.x, vp.x]
			)
			return false
	print(
		"OK: portrait strike feedback scale=",
		StrikeFeedbackBillboard.PORTRAIT_SCALE,
		" x-frac=",
		snappedf(frac_x, 0.01)
	)

	_set_logical_size(Vector2i(480, 270))
	await process_frame
	if rv.has_method(&"apply_viewport_aspect"):
		rv.apply_viewport_aspect()
	await process_frame
	await process_frame
	if not is_equal_approx(sprite.pixel_size, StrikeFeedbackBillboard.DEFAULT_PIXEL_SIZE):
		push_error(
			"FAIL: landscape strike feedback pixel_size=%s want %s"
			% [sprite.pixel_size, StrikeFeedbackBillboard.DEFAULT_PIXEL_SIZE]
		)
		return false
	print("OK: landscape strike feedback restored full size")
	return true


func _verify_upgrade_panel_portrait() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var panel: Control = main.get_node_or_null("UI/UIRoot/UpgradePanel")
	if panel == null:
		push_error("FAIL: UpgradePanel missing")
		main.queue_free()
		return false
	_set_logical_size(Vector2i(270, 480))
	await process_frame
	if main.has_method("_notify_portrait_layout"):
		main._notify_portrait_layout()
	main.get_node("TitleScreen").visible = false
	main.get_node("UI").visible = true
	panel.open()
	await process_frame
	await process_frame
	if not RadialTreeLayout.use_portrait_aspect:
		push_error("FAIL: upgrade panel should use portrait tree aspect")
		main.queue_free()
		return false
	var aspect := RadialTreeLayout.content_aspect(panel._layout_positions)
	if absf(aspect / RadialTreeLayout.PORTRAIT_ASPECT - 1.0) > RadialTreeLayout.ASPECT_TOLERANCE:
		push_error("FAIL: portrait upgrade tree aspect=%s" % snappedf(aspect, 0.01))
		main.queue_free()
		return false
	var header: Control = panel.get_node("Content/Header")
	var header_rect := header.get_global_rect()
	var nodes_root: Control = panel.get_node("Content/TreeViewport/TreeWorld/Nodes")
	for child in nodes_root.get_children():
		if not child.visible or not (child is Control):
			continue
		var center: Vector2 = (child as Control).get_global_rect().get_center()
		if header_rect.has_point(center):
			push_error("FAIL: upgrade node center under header in portrait")
			main.queue_free()
			return false
	print("OK: portrait upgrade panel aspect=", snappedf(aspect, 0.01))
	panel.close()
	_set_logical_size(Vector2i(480, 270))
	RadialTreeLayout.use_portrait_aspect = false
	main.queue_free()
	return true
