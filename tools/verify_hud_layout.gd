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
	var icon_bar: Control = ui_root.get_node("IconBar")
	var bucket_counter: Control = icon_bar.get_node("BottomRight/BucketCounter")
	var mode_toggle: Control = icon_bar.get_node("BottomRight/RangeModeToggle")
	var settings_btn: Control = icon_bar.get_node("BottomLeft/SettingsWrap/SettingsButton")
	var vp_size: Vector2 = root.get_visible_rect().size

	print("viewport_size=", vp_size)
	print("ui_root_size=", ui_root.size, " pos=", ui_root.position)
	print("hud_size=", hud.size, " pos=", hud.position)
	print("margin_global=", margin.global_position, " size=", margin.size)
	print("bucket_counter_global=", bucket_counter.global_position, " size=", bucket_counter.size)
	print("settings_btn_global=", settings_btn.global_position, " size=", settings_btn.size)

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
	if hud.has_node("Margin/VBox/BucketLabel"):
		print("FAIL: legacy BucketLabel still in HUD")
		ok = false
	if icon_bar.has_node("BottomLeft/StatsButton"):
		print("FAIL: stats placeholder should be removed")
		ok = false
	if bucket_counter.global_position.x < vp_size.x * 0.5:
		print("FAIL: bucket counter not in right half of screen")
		ok = false
	if bucket_counter.global_position.y < vp_size.y * 0.5:
		print("FAIL: bucket counter not in bottom half of screen")
		ok = false
	if settings_btn.global_position.x >= vp_size.x * 0.5:
		print("FAIL: settings button not in left half of screen")
		ok = false
	if settings_btn.global_position.y < vp_size.y * 0.5:
		print("FAIL: settings button not in bottom half of screen")
		ok = false
	if settings_btn.global_position.x > bucket_counter.global_position.x:
		print("FAIL: settings should be left of bucket counter")
		ok = false
	var count_label: Label = bucket_counter.get_node("CountLabel")
	var gs: Node = root.get_node_or_null("GameState")
	var expected_count := "%d/%d" % [Balance.BUCKET_CAPACITY_DEFAULT, Balance.BUCKET_CAPACITY_DEFAULT]
	if gs != null:
		expected_count = "%d/%d" % [gs.bucket_remaining, gs.bucket_capacity]
	if count_label.text != expected_count:
		print(
			"FAIL: bucket count label expected '%s', got '%s'"
			% [expected_count, count_label.text]
		)
		ok = false
	if "/" not in count_label.text:
		print("FAIL: bucket count should show current/max fraction")
		ok = false
	if not mode_toggle is Button:
		print("FAIL: RangeModeToggle missing from bottom-right")
		ok = false
	if mode_toggle.visible:
		print("FAIL: RangeModeToggle should be hidden outside harvest")
		ok = false

	print("hud_layout_ok=", ok)
	quit(0 if ok else 1)
