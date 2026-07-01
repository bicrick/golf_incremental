extends SceneTree
## Headless upgrade tree smoke test — run:
## godot --headless --script res://tools/verify_upgrade_tree.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	var defs := UpgradeDefinitions.all()
	if defs.size() != 11:
		print("FAIL: expected 11 upgrades, got ", defs.size())
		ok = false
	var base_pay := UpgradeDefinitions.get_def("base_pay")
	if base_pay.is_empty() or base_pay.get("parent_id", "x") != "":
		print("FAIL: base_pay root missing or has parent")
		ok = false
	var branch_heads := ["bucket_size", "yardage_markers"]
	for head in branch_heads:
		var def := UpgradeDefinitions.get_def(head)
		if def.get("parent_id", "") != "base_pay":
			print("FAIL: %s should branch from base_pay" % head)
			ok = false
	if UpgradeDefinitions.connections().size() != 10:
		print("FAIL: expected 10 tree connections")
		ok = false

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		ok = false
		print("upgrade_tree_ok=", ok)
		quit(1)
		return

	gs.currency = 500.0
	gs.upgrade_levels = {}
	gs._recompute_stats()
	var before_base: float = gs.stats.base_amount
	if not gs.purchase_upgrade("base_pay"):
		print("FAIL: could not purchase base_pay")
		ok = false
	if gs.get_upgrade_level("base_pay") != 1:
		print("FAIL: base_pay level not incremented")
		ok = false
	if gs.stats.base_amount <= before_base:
		print("FAIL: base_pay did not affect base_amount")
		ok = false
	if gs.purchase_upgrade("bucket_size"):
		if gs.stats.bucket_capacity_bonus <= 0.0:
			print("FAIL: bucket_size did not increase capacity bonus")
			ok = false
	else:
		print("FAIL: could not purchase bucket_size after base_pay")
		ok = false

	gs.upgrade_levels["base_pay"] = 15
	gs._recompute_stats()
	if not gs.purchase_upgrade("yardage_markers"):
		print("FAIL: could not purchase yardage_markers at base_pay 15")
		ok = false
	if gs.stats.yardage_term_unlocked <= 0.0:
		print("FAIL: yardage_markers did not unlock yardage term")
		ok = false
	if gs.purchase_upgrade("yardage"):
		if gs.stats.base_yards <= Balance.default_stats().base_yards:
			print("FAIL: yardage did not increase base_yards")
			ok = false
	else:
		print("FAIL: could not purchase yardage")
		ok = false
	if gs.purchase_upgrade("yardage_mult"):
		if gs.stats.yardage_multiplier <= Balance.default_stats().yardage_multiplier:
			print("FAIL: yardage_mult did not increase yardage_multiplier")
			ok = false
	else:
		print("FAIL: could not purchase yardage_mult")
		ok = false

	var range_view: Node3D = main.get_node("RangeView")
	var ui: CanvasLayer = main.get_node("UI")
	var hud: Control = main.get_node("UI/UIRoot/HUD")
	var icon_bar: Control = main.get_node("UI/UIRoot/IconBar")
	var panel: Control = main.get_node("UI/UIRoot/UpgradePanel")

	main.get_node("TitleScreen").visible = false
	range_view.visible = true
	ui.visible = true
	main._set_gameplay_ui_visible(true)
	await process_frame
	if panel == null:
		print("FAIL: UpgradePanel missing from main")
		ok = false
	else:
		var sky_bg: Node = panel.get_node_or_null("SkyBg")
		if sky_bg == null or not sky_bg.has_method("layer_count") or sky_bg.layer_count() != 4:
			var count: int = sky_bg.layer_count() if sky_bg != null and sky_bg.has_method("layer_count") else -1
			print("FAIL: expected 4 cloud layers on upgrade view, got %d" % count)
			ok = false
		if panel.get_node_or_null("DimOverlay") != null:
			print("FAIL: upgrade view should not use modal DimOverlay")
			ok = false

		gs.upgrade_levels = {}
		gs._recompute_stats()
		panel.open()
		await process_frame
		if not panel.visible:
			print("FAIL: panel not visible after open()")
			ok = false
		if range_view.visible:
			print("FAIL: range view should hide when upgrade view opens")
			ok = false
		if hud.visible or icon_bar.visible:
			print("FAIL: gameplay HUD should hide when upgrade view opens")
			ok = false

		var nodes_root: Control = panel.get_node("Content/TreeCanvas/Nodes")
		var visible_before := _count_visible_nodes(nodes_root)
		if visible_before != 1:
			print("FAIL: expected 1 revealed node at start, got ", visible_before)
			ok = false

		gs.currency = 500.0
		panel._refresh_all()
		await process_frame
		if not gs.purchase_upgrade("base_pay"):
			print("FAIL: could not purchase base_pay from upgrade view")
			ok = false
		panel._refresh_all()
		await process_frame
		var visible_after_base := _count_visible_nodes(nodes_root)
		if visible_after_base != 2:
			print("FAIL: expected 2 revealed nodes after base_pay, got ", visible_after_base)
			ok = false

		if nodes_root.get_child_count() != 11:
			print("FAIL: expected 11 tree nodes built, got ", nodes_root.get_child_count())
			ok = false

		panel.close()
		await process_frame
		if panel.visible:
			print("FAIL: panel still visible after close()")
			ok = false
		if not range_view.visible:
			print("FAIL: range view should restore after closing upgrade view")
			ok = false
		if not hud.visible or not icon_bar.visible:
			print("FAIL: gameplay HUD should restore after closing upgrade view")
			ok = false

	print("upgrade_tree_ok=", ok)
	quit(0 if ok else 1)


func _count_visible_nodes(nodes_root: Control) -> int:
	var count := 0
	for child in nodes_root.get_children():
		if child.visible:
			count += 1
	return count
