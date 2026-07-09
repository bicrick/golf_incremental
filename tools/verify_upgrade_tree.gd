extends SceneTree
## Headless unified upgrade tree smoke test — run:
## godot --headless --script res://tools/verify_upgrade_tree.gd

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const RadialTreeLayout = preload("res://scripts/ui/upgrade_tree_layout.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	var player_defs := UpgradeDefinitions.all()
	if player_defs.size() != 11:
		print("FAIL: expected 11 player upgrades, got ", player_defs.size())
		ok = false
	var base_pay := UpgradeDefinitions.get_def("base_pay")
	if base_pay.is_empty() or base_pay.get("parent_id", "x") != "":
		print("FAIL: base_pay root missing or has parent")
		ok = false
	var branch_heads := ["distance_pay", "quality", "pickup", "ball_count"]
	for head in branch_heads:
		var graph_parent := UpgradeGraph.parent_id(head)
		if graph_parent != "base_pay":
			print("FAIL: %s should branch from base_pay in graph, got %s" % [head, graph_parent])
			ok = false
	if UpgradeGraph.all_nodes().size() != 23:
		print("FAIL: expected 23 graph nodes, got ", UpgradeGraph.all_nodes().size())
		ok = false
	if UpgradeGraph.connections().size() != 22:
		print("FAIL: expected 22 graph connections, got ", UpgradeGraph.connections().size())
		ok = false

	var layout_a := RadialTreeLayout.compute_positions()
	var layout_b := RadialTreeLayout.compute_positions()
	if layout_a.size() != 23:
		print("FAIL: expected 23 layout positions, got ", layout_a.size())
		ok = false
	if layout_a.get("base_pay", Vector2.ONE) != Vector2.ZERO:
		print("FAIL: base_pay should be at origin")
		ok = false
	for id in layout_a:
		if layout_a[id] != layout_b[id]:
			print("FAIL: layout not deterministic for ", id)
			ok = false
			break
	if RadialTreeLayout.min_pair_distance(layout_a) < RadialTreeLayout.MIN_NODE_DISTANCE:
		print("FAIL: layout nodes overlap after relaxation (min=%.2f)" % RadialTreeLayout.min_pair_distance(layout_a))
		ok = false
	var layout_aspect := RadialTreeLayout.content_aspect(layout_a)
	if absf(layout_aspect / RadialTreeLayout.TARGET_ASPECT - 1.0) > RadialTreeLayout.ASPECT_TOLERANCE:
		print(
			"FAIL: layout aspect %.3f not within tolerance of 16:9 (%.3f)"
			% [layout_aspect, RadialTreeLayout.TARGET_ASPECT]
		)
		ok = false
	else:
		print("OK: layout aspect=%.3f (target 16:9)" % layout_aspect)

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

	for head in branch_heads:
		if not UpgradeGraph.is_unlocked(head):
			print("FAIL: %s should unlock at base_pay Lv.1" % head)
			ok = false

	if gs.purchase_upgrade("distance_pay"):
		if gs.stats.yardage_term_unlocked <= 0.0:
			print("FAIL: distance_pay did not unlock yardage term")
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

	if gs.purchase_upgrade("quality"):
		if gs.stats.sweet_spot_unlocked <= 0.0:
			print("FAIL: quality (Sweet Spot) did not unlock sweet_spot")
			ok = false
		if gs.stats.sweet_spot_bonus <= 0.0:
			print("FAIL: quality (Sweet Spot) did not raise sweet_spot_bonus")
			ok = false
	else:
		print("FAIL: could not purchase quality")
		ok = false

	gs.currency = 500.0
	gs.upgrade_levels = {"base_pay": 1, "quality": 3}
	gs._recompute_stats()
	if gs.purchase_upgrade("perfect_pop"):
		if gs.stats.perfect_power_bonus <= 1.0:
			print("FAIL: perfect_pop did not raise perfect_power_bonus")
			ok = false
	else:
		print("FAIL: could not purchase perfect_pop")
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
		await process_frame
		if not panel.visible:
			print("FAIL: panel not visible after open()")
			ok = false
		if panel.get_node_or_null("SkyBg") == null:
			print("FAIL: upgrade panel should use parallax SkyBg")
			ok = false
		elif not panel.get_node("SkyBg").has_method("layer_count") or panel.get_node("SkyBg").layer_count() != 3:
			print("FAIL: upgrade SkyBg should have 3 cloud layers")
			ok = false
		if range_view.visible:
			print("FAIL: RangeView should hide while upgrade panel is open")
			ok = false

		var nodes_root: Control = panel.get_node("Content/TreeViewport/TreeWorld/Nodes")
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
		if visible_after_base != 6:
			print("FAIL: expected 6 revealed nodes after base_pay, got ", visible_after_base)
			ok = false

		if nodes_root.get_child_count() != 23:
			print("FAIL: expected 23 tree nodes built, got ", nodes_root.get_child_count())
			ok = false

		ok = _check_tree_pan(panel) and ok
		ok = await _check_purchase_after_pan(gs, panel) and ok
		ok = await _check_purchase_spam(gs, panel) and ok
		ok = await _check_currency_format(panel) and ok

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

	ok = await _check_upgrades_button_clickable_during_harvest(main, gs, panel, icon_bar_node) and ok

	print("upgrade_tree_ok=", ok)
	quit(0 if ok else 1)


func _check_purchase_spam(gs: Node, panel: Control) -> bool:
	gs.currency = 50_000.0
	panel.open()
	await process_frame
	await process_frame
	var level_before: int = gs.get_upgrade_level("base_pay")
	var bought := 0
	for _i in 12:
		if gs.purchase_upgrade("base_pay"):
			bought += 1
	await process_frame
	await process_frame
	var level_after: int = gs.get_upgrade_level("base_pay")
	if level_after != level_before + bought:
		print(
			"FAIL: spam purchases inconsistent (before=%d bought=%d after=%d)"
			% [level_before, bought, level_after]
		)
		return false
	if not panel.visible:
		print("FAIL: panel should stay open after spam purchases")
		return false
	if panel._refresh_pending:
		print("FAIL: refresh should have flushed after deferred frame")
		return false
	var currency_label: Label = panel.get_node("Content/Header/Row/CurrencyLabel")
	if currency_label == null or not currency_label.text.begins_with("$"):
		print("FAIL: currency label missing after spam")
		return false
	print("OK: spam purchases coalesce refresh (bought=%d)" % bought)
	return true


func _check_currency_format(panel: Control) -> bool:
	if FloatCashText.format_amount(1.5) != "1.50":
		print("FAIL: format_amount(1.5) expected 1.50, got %s" % FloatCashText.format_amount(1.5))
		return false
	if FloatCashText.format_amount(0.2) != "0.20":
		print("FAIL: format_amount(0.2) expected 0.20, got %s" % FloatCashText.format_amount(0.2))
		return false
	if FloatCashText.format_amount(311.0) != "311":
		print("FAIL: format_amount(311) expected 311, got %s" % FloatCashText.format_amount(311.0))
		return false
	var gs: Node = root.get_node("GameState")
	gs.currency = 311.5
	panel._refresh_all()
	await process_frame
	var currency_label: Label = panel.get_node("Content/Header/Row/CurrencyLabel")
	if currency_label == null or currency_label.text != "$311.50":
		print(
			"FAIL: panel currency should show cents, got %s"
			% (currency_label.text if currency_label else "<missing>")
		)
		return false
	var header: PanelContainer = panel.get_node("Content/Header")
	if header == null:
		print("FAIL: header PanelContainer missing")
		return false
	var tree_viewport: Control = panel.get_node("Content/TreeViewport")
	if tree_viewport == null or not is_zero_approx(tree_viewport.offset_top):
		print(
			"FAIL: TreeViewport should be full-height under header, offset_top=%s"
			% (tree_viewport.offset_top if tree_viewport else "<missing>")
		)
		return false
	var content: Control = panel.get_node("Content")
	if content.get_children().find(header) <= content.get_children().find(tree_viewport):
		print("FAIL: Header should draw after TreeViewport so tree scrolls underneath")
		return false
	print("OK: currency format shows cents below $1K")
	return true


func _check_tree_pan(panel: Control) -> bool:
	var camera: Node = panel.get_node("TreeCameraController")
	var tree_viewport: Control = panel.get_node("Content/TreeViewport")
	if camera == null or tree_viewport == null:
		print("FAIL: missing tree camera or viewport for pan check")
		return false
	if not camera.is_enabled():
		print("FAIL: tree camera should be enabled while panel is open")
		return false

	var origin: Vector2 = tree_viewport.get_global_rect().get_center()
	var pan_before: Vector2 = camera.get_pan_offset()
	if not panel.consume_pan_drag_event(_left_down(origin)):
		print("FAIL: empty TreeViewport should accept pan drag start")
		return false
	var dragged := origin + Vector2(40.0, 24.0)
	if not panel.consume_pan_drag_event(_mouse_motion(dragged)):
		print("FAIL: tree pan drag motion should be consumed")
		return false
	var pan_after: Vector2 = camera.get_pan_offset()
	if pan_after.is_equal_approx(pan_before):
		print("FAIL: tree pan offset should change after drag")
		return false
	if not camera.did_drag():
		print("FAIL: tree camera should report did_drag after pan")
		return false
	panel.consume_pan_drag_event(_left_up(dragged))
	print("OK: tree pan drag updates offset")
	return true


func _check_purchase_after_pan(gs: Node, panel: Control) -> bool:
	var camera: Node = panel.get_node("TreeCameraController")
	if camera == null or not camera.did_drag():
		print("FAIL: expected sticky did_drag after pan before purchase click")
		return false
	# Outside-viewport press hits the same pan-block early return as a HitButton click.
	panel.consume_pan_drag_event(_left_down(Vector2(-100.0, -100.0)))
	if camera.did_drag():
		print("FAIL: new mouse-down should clear did_drag even when pan start is blocked")
		return false
	var level_before: int = gs.get_upgrade_level("base_pay")
	gs.currency = 500.0
	panel._on_purchase_requested("base_pay")
	await process_frame
	if gs.get_upgrade_level("base_pay") != level_before + 1:
		print(
			"FAIL: _on_purchase_requested after pan should buy (before=%d after=%d)"
			% [level_before, gs.get_upgrade_level("base_pay")]
		)
		return false
	print("OK: purchase after pan clears sticky did_drag")
	return true


func _left_down(position: Vector2) -> InputEventMouseButton:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.global_position = position
	return down


func _left_up(position: Vector2) -> InputEventMouseButton:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.global_position = position
	return up


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var move := InputEventMouseMotion.new()
	move.position = position
	move.global_position = position
	return move


func _check_upgrades_button_clickable_during_harvest(
	main: Node, gs: Node, panel: Control, icon_bar_node: Node
) -> bool:
	gs.reset_to_fresh()
	gs.currency = Balance.UPGRADES_UNLOCK_COST
	gs.upgrades_unlocked = true
	if icon_bar_node.has_method("_refresh_upgrades_lock_state"):
		icon_bar_node._refresh_upgrades_lock_state()
	panel.close()
	await process_frame
	var range_view: Node3D = main.get_node("RangeView")

	gs.bucket_remaining = 0
	gs.try_enter_harvest()
	var end := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < end:
		if range_view.has_method("is_harvest_view_ready") and range_view.is_harvest_view_ready():
			break
		await process_frame
	await process_frame

	var target: Vector2 = icon_bar_node.upgrades_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = target
	motion.global_position = target
	Input.parse_input_event(motion)
	await process_frame
	_parse_mouse_button_test(target, true)
	await process_frame
	_parse_mouse_button_test(target, false)
	await process_frame
	await process_frame

	gs.exit_harvest_early()
	await process_frame

	if not panel.visible:
		print("FAIL: upgrades button click during harvest should open UpgradePanel")
		panel.close()
		return false
	panel.close()
	await process_frame
	print("OK: upgrades button remains clickable during harvest (collect mode)")
	return true


func _parse_mouse_button_test(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _count_visible_nodes(nodes_root: Control) -> int:
	var count := 0
	for child in nodes_root.get_children():
		if child.visible:
			count += 1
	return count
