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
	var gameplay_chrome: Control = ui_root.get_node("GameplayChrome")
	var hud: Control = gameplay_chrome.get_node("HUD")
	var margin: MarginContainer = hud.get_node("Margin")
	var icon_bar: Control = gameplay_chrome.get_node("IconBar")
	var bucket_counter: Control = icon_bar.get_node("BottomRight/BucketCounter")
	var vp_size: Vector2 = root.get_visible_rect().size

	print("viewport_size=", vp_size)
	print("ui_root_size=", ui_root.size, " pos=", ui_root.position)
	print("hud_size=", hud.size, " pos=", hud.position)
	print("margin_global=", margin.global_position, " size=", margin.size)
	print("bucket_counter_global=", bucket_counter.global_position, " size=", bucket_counter.size)

	var ok := true
	if ui_root.size != vp_size:
		print("FAIL: UIRoot not viewport-sized")
		ok = false
	if hud.size != gameplay_chrome.size:
		print("FAIL: HUD not filling GameplayChrome")
		ok = false
	if margin.global_position != Vector2(EXPECTED_PADDING, EXPECTED_PADDING):
		print("FAIL: Margin not at (%d,%d), got %s" % [EXPECTED_PADDING, EXPECTED_PADDING, margin.global_position])
		ok = false
	if margin.size.x <= 0 or margin.size.y <= 0:
		print("FAIL: Margin collapsed to zero size")
		ok = false
	if not margin.has_node("CurrencyPanel"):
		print("FAIL: CurrencyPanel missing from HUD margin")
		ok = false
	if not margin.get_node("CurrencyPanel") is PanelContainer:
		print("FAIL: CurrencyPanel should be a PanelContainer")
		ok = false
	if hud.has_node("Margin/VBox/HintLabel") or hud.has_node("Margin/VBox/PhaseLabel"):
		print("FAIL: legacy hint/phase labels still in HUD")
		ok = false
	if hud.has_node("Margin/VBox/BucketLabel"):
		print("FAIL: legacy BucketLabel still in HUD")
		ok = false
	if icon_bar.has_node("BottomRight/RangeModeToggle"):
		print("FAIL: RangeModeToggle should be removed")
		ok = false
	if icon_bar.has_node("BottomLeft/StatsButton"):
		print("FAIL: stats placeholder should be removed")
		ok = false
	if icon_bar.has_node("BottomLeft"):
		print("FAIL: settings cog BottomLeft should be removed")
		ok = false
	if not bucket_counter is PanelContainer:
		print("FAIL: BucketCounter should be a PanelContainer")
		ok = false
	if bucket_counter.global_position.x < vp_size.x * 0.5:
		print("FAIL: bucket counter not in right half of screen")
		ok = false
	if bucket_counter.global_position.y < vp_size.y * 0.5:
		print("FAIL: bucket counter not in bottom half of screen")
		ok = false
	var count_label: Label = bucket_counter.get_node("Row/CountLabel")
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

	print("hud_layout_ok=", ok)
	quit(0 if ok else 1)
