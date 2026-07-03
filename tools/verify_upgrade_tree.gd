extends SceneTree
## Headless upgrade tree smoke test — run:
## godot --headless --script res://tools/verify_upgrade_tree.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	var defs := UpgradeDefinitions.all()
	if defs.size() != 13:
		print("FAIL: expected 13 upgrades, got ", defs.size())
		ok = false
	var base_pay := UpgradeDefinitions.get_def("base_pay")
	if base_pay.is_empty() or base_pay.get("parent_id", "x") != "":
		print("FAIL: base_pay root missing or has parent")
		ok = false
	var branch_heads := ["distance_pay", "quality", "pickup"]
	for head in branch_heads:
		var def := UpgradeDefinitions.get_def(head)
		if def.get("parent_id", "") != "base_pay":
			print("FAIL: %s should branch from base_pay" % head)
			ok = false
	if UpgradeDefinitions.connections().size() != 12:
		print("FAIL: expected 12 tree connections, got ", UpgradeDefinitions.connections().size())
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
	gs.upgrades_unlocked = true
	gs.upgrade_levels = {}
	gs._recompute_stats()
	if not is_equal_approx(gs.get_upgrade_cost("base_pay"), 1.50):
		print("FAIL: base_pay Lv.0 cost expected $1.50, got %.2f" % gs.get_upgrade_cost("base_pay"))
		ok = false
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
	if not is_equal_approx(gs.stats.base_amount, 0.2875):
		print("FAIL: base_pay Lv.1 expected base_amount $0.2875, got %.2f" % gs.stats.base_amount)
		ok = false

	for head in branch_heads:
		if not UpgradeDefinitions.is_unlocked(head, gs.upgrade_levels):
			print("FAIL: %s should unlock at base_pay Lv.1" % head)
			ok = false

	if gs.purchase_upgrade("distance_pay"):
		if gs.stats.yardage_term_unlocked <= 0.0:
			print("FAIL: distance_pay did not unlock yardage term")
			ok = false
		if gs.stats.pay_per_yard <= Balance.default_stats().pay_per_yard:
			print("FAIL: distance_pay did not increase pay_per_yard")
			ok = false
	else:
		print("FAIL: could not purchase distance_pay")
		ok = false

	if gs.purchase_upgrade("iron_set"):
		if gs.stats.base_yards <= 30.0:
			print("FAIL: iron_set did not increase base_yards")
			ok = false
	else:
		print("FAIL: could not purchase iron_set")
		ok = false

	if gs.purchase_upgrade("power"):
		if gs.stats.carry_multiplier <= 1.0:
			print("FAIL: power did not increase carry_multiplier")
			ok = false
	else:
		print("FAIL: could not purchase power")
		ok = false

	if gs.purchase_upgrade("quality"):
		if gs.stats.quality_term_unlocked <= 0.0:
			print("FAIL: quality did not unlock quality term")
			ok = false
	else:
		print("FAIL: could not purchase quality")
		ok = false

	var range_view: Node3D = main.get_node("RangeView")
	var ui: CanvasLayer = main.get_node("UI")
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
		gs.upgrade_levels = {}
		gs._recompute_stats()
		panel.open()
		await process_frame
		if not panel.visible:
			print("FAIL: panel not visible after open()")
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
		if visible_after_base != 4:
			print("FAIL: expected 4 revealed nodes after base_pay, got ", visible_after_base)
			ok = false

		if nodes_root.get_child_count() != 13:
			print("FAIL: expected 13 tree nodes built, got ", nodes_root.get_child_count())
			ok = false

		panel.close()
		await process_frame
		if not range_view.visible:
			print("FAIL: range view should restore after closing upgrade view")
			ok = false

	gs.reset_to_fresh()
	await process_frame
	var icon_bar_node: Node = main.get_node("UI/UIRoot/GameplayChrome/IconBar")
	if icon_bar_node.has_method("_refresh_upgrades_lock_state"):
		icon_bar_node._refresh_upgrades_lock_state()
	if not gs.upgrades_unlocked and gs.currency < Balance.UPGRADES_UNLOCK_COST:
		if not icon_bar_node.upgrades_button.disabled:
			print("FAIL: upgrades button should be disabled below unlock cost")
			ok = false
	gs.currency = Balance.UPGRADES_UNLOCK_COST
	if icon_bar_node.has_method("_refresh_upgrades_lock_state"):
		icon_bar_node._refresh_upgrades_lock_state()
	if gs.try_unlock_upgrades():
		if not gs.upgrades_unlocked:
			print("FAIL: try_unlock_upgrades should set flag")
			ok = false
		if gs.currency > 0.001:
			print("FAIL: unlock should spend full cost, currency=%.2f" % gs.currency)
			ok = false
	else:
		print("FAIL: try_unlock_upgrades failed at exact cost")
		ok = false

	gs.upgrades_unlocked = true
	panel.close()
	await process_frame
	if icon_bar_node.has_method("_on_upgrades_pressed"):
		icon_bar_node._on_upgrades_pressed()
	else:
		icon_bar_node.upgrades_button.pressed.emit()
	await process_frame
	if not panel.visible:
		print("FAIL: upgrades button should open UpgradePanel")
		ok = false
	panel.close()
	await process_frame

	print("upgrade_tree_ok=", ok)
	quit(0 if ok else 1)


func _count_visible_nodes(nodes_root: Control) -> int:
	var count := 0
	for child in nodes_root.get_children():
		if child.visible:
			count += 1
	return count
