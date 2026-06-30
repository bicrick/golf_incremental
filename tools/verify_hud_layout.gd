extends SceneTree
## Headless HUD layout check — run: godot --headless --script res://tools/verify_hud_layout.gd

const EXPECTED_PADDING := 10


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var ui_root: Control = main.get_node("UI/UIRoot")
	var hud: Control = ui_root.get_node("HUD")
	var margin: MarginContainer = hud.get_node("Margin")
	var vp_size: Vector2 = root.get_visible_rect().size

	print("viewport_size=", vp_size)
	print("ui_root_size=", ui_root.size, " pos=", ui_root.position)
	print("hud_size=", hud.size, " pos=", hud.position)
	print("margin_global=", margin.global_position, " size=", margin.size)

	var ok := true
	if ui_root.size != vp_size:
		print("FAIL: UIRoot not viewport-sized")
		ok = false
	if hud.size != ui_root.size:
		print("FAIL: HUD not filling UIRoot")
		ok = false
	if margin.global_position != Vector2(EXPECTED_PADDING, EXPECTED_PADDING):
		print("FAIL: Margin not at (%d,%d), got %s" % [EXPECTED_PADDING, EXPECTED_PADDING, margin.global_position])
		ok = false
	if margin.size.x <= 0 or margin.size.y <= 0:
		print("FAIL: Margin collapsed to zero size")
		ok = false

	print("hud_layout_ok=", ok)
	quit(0 if ok else 1)
