extends SceneTree
## Headless upgrade tree smoke test — run:
## godot --headless --script res://tools/verify_upgrade_tree.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	# Definitions (no autoload required)
	var defs := UpgradeDefinitions.all()
	if defs.size() != 10:
		print("FAIL: expected 10 upgrades, got ", defs.size())
		ok = false
	var power := UpgradeDefinitions.get_def("power")
	if power.is_empty() or power.get("parent_id", "x") != "":
		print("FAIL: power root missing or has parent")
		ok = false
	var branch_heads := ["leg_day", "metronome", "dollars_per_yard"]
	for head in branch_heads:
		var def := UpgradeDefinitions.get_def(head)
		if def.get("parent_id", "") != "power":
			print("FAIL: %s should branch from power" % head)
			ok = false
	if UpgradeDefinitions.connections().size() != 9:
		print("FAIL: expected 9 tree connections")
		ok = false

	# Boot main scene so autoloads initialize
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
	var before_yard: float = gs.stats.base_yards
	if not gs.purchase_upgrade("power"):
		print("FAIL: could not purchase power")
		ok = false
	if gs.get_upgrade_level("power") != 1:
		print("FAIL: power level not incremented")
		ok = false
	if gs.stats.yard_multiplier <= 1.0:
		print("FAIL: power did not affect yard_multiplier")
		ok = false
	if gs.purchase_upgrade("leg_day"):
		if gs.stats.base_yards <= before_yard:
			print("FAIL: leg_day did not increase base_yards")
			ok = false
	else:
		print("FAIL: could not purchase leg_day after power")
		ok = false
	if gs.purchase_upgrade("metronome"):
		if gs.stats.timing_window_perfect_ms <= Balance.default_stats().timing_window_perfect_ms:
			print("FAIL: metronome did not widen timing window")
			ok = false
	else:
		print("FAIL: could not purchase metronome")
		ok = false
	if gs.purchase_upgrade("dollars_per_yard"):
		if gs.stats.dollars_per_yard <= Balance.default_stats().dollars_per_yard:
			print("FAIL: dollars_per_yard did not increase stat")
			ok = false
	else:
		print("FAIL: could not purchase dollars_per_yard")
		ok = false

	var range_view: Node3D = main.get_node("RangeView")
	var ui: CanvasLayer = main.get_node("UI")
	var hud: Control = main.get_node("UI/UIRoot/HUD")
	var icon_bar: Control = main.get_node("UI/UIRoot/IconBar")
	var panel: Control = main.get_node("UI/UIRoot/UpgradePanel")

	# Enter gameplay so main wires upgrade view navigation.
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
		if not gs.purchase_upgrade("power"):
			print("FAIL: could not purchase power from upgrade view")
			ok = false
		panel._refresh_all()
		await process_frame
		var visible_after_power := _count_visible_nodes(nodes_root)
		if visible_after_power != 4:
			print("FAIL: expected 4 revealed nodes after power, got ", visible_after_power)
			ok = false

		if nodes_root.get_child_count() != 10:
			print("FAIL: expected 10 tree nodes built, got ", nodes_root.get_child_count())
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
