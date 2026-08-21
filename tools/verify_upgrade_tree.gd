extends SceneTree
## Headless unified upgrade tree smoke test — run:
## godot --headless --script res://tools/verify_upgrade_tree.gd

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const RadialTreeLayout = preload("res://scripts/ui/upgrade_tree_layout.gd")
const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")
const UpgradeTreeConnectors = preload("res://scripts/ui/upgrade_tree_connectors.gd")
const UpgradeIcon = preload("res://scripts/ui/upgrade_icon.gd")
const UpgradeNodeTap = preload("res://scripts/ui/upgrade_node_tap.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	## Desktop/editor/headless must not use tap-inspect (trackpads can report touchscreen).
	if UiLayout.is_mobile_touch():
		print("FAIL: is_mobile_touch() should be false on desktop/headless")
		ok = false
	else:
		print("OK: is_mobile_touch() false on desktop")

	var player_defs := UpgradeDefinitions.all()
	if player_defs.size() != 8:
		print("FAIL: expected 8 player upgrades, got ", player_defs.size())
		ok = false
	var base_pay := UpgradeDefinitions.get_def("base_pay")
	if base_pay.is_empty() or base_pay.get("parent_id", "x") != "":
		print("FAIL: base_pay root missing or has parent")
		ok = false
	for removed_id in ["quick_reset", "combo_bonus", "ratina_hire"]:
		if not UpgradeDefinitions.get_def(removed_id).is_empty():
			print("FAIL: %s should be removed from Play defs" % removed_id)
			ok = false
	var branch_heads := ["distance_pay", "quality", "pickup"]
	for head in branch_heads:
		var graph_parent := UpgradeGraph.parent_id(head)
		if graph_parent != "base_pay":
			print("FAIL: %s should branch from base_pay in graph, got %s" % [head, graph_parent])
			ok = false
	if UpgradeGraph.all_nodes().size() != 8:
		print("FAIL: expected 8 graph nodes, got ", UpgradeGraph.all_nodes().size())
		ok = false
	if UpgradeGraph.connections().size() != 7:
		print("FAIL: expected 7 graph connections, got ", UpgradeGraph.connections().size())
		ok = false
	for hidden_id in ["ball_count", "golden_ball", "ratina_hire", "rattling_more"]:
		if not UpgradeGraph.get_node(hidden_id).is_empty():
			print("FAIL: %s should be hidden from Play graph" % hidden_id)
			ok = false

	var icon_assets_ok := true
	for node_def in UpgradeGraph.all_nodes():
		var id: String = node_def.get("id", "")
		var icon_path := UpgradeIcon.path_for(id)
		if not ResourceLoader.exists(icon_path):
			print("FAIL: missing upgrade icon for %s at %s" % [id, icon_path])
			ok = false
			icon_assets_ok = false
		elif UpgradeIcon.load_texture(id) == null:
			print("FAIL: could not load upgrade icon for %s" % id)
			ok = false
			icon_assets_ok = false
	if icon_assets_ok:
		print("OK: all %d upgrade icon assets present" % UpgradeGraph.all_nodes().size())

	var layout_a := RadialTreeLayout.compute_positions()
	var layout_b := RadialTreeLayout.compute_positions()
	if layout_a.size() != 8:
		print("FAIL: expected 8 layout positions, got ", layout_a.size())
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
	if not is_equal_approx(gs.get_upgrade_cost("base_pay"), 1.0):
		print("FAIL: base_pay Lv.0 cost expected $1.00, got %.2f" % gs.get_upgrade_cost("base_pay"))
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
		_reset_tree_progress(gs)
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
		if visible_after_base != 4:
			print("FAIL: expected 4 revealed nodes after base_pay, got ", visible_after_base)
			ok = false

		if nodes_root.get_child_count() != 8:
			print("FAIL: expected 8 tree nodes built, got ", nodes_root.get_child_count())
			ok = false

		ok = _check_tree_node_icons(nodes_root) and ok
		ok = _check_tree_node_icon_centering(nodes_root) and ok
		ok = _check_branch_stroke_palettes() and ok
		ok = _check_ratina_pink_palette() and ok

		ok = _check_tree_pan(panel) and ok
		ok = await _check_purchase_after_pan(gs, panel) and ok
		ok = _check_pan_press_does_not_claim(panel) and ok
		ok = await _check_desktop_click_buys(gs, panel) and ok
		ok = await _check_tap_inspect_then_buy(gs, panel) and ok
		ok = _check_continuous_zoom(panel) and ok
		ok = await _check_portrait_tree_fit(main, panel) and ok
		ok = await _check_purchase_spam(gs, panel) and ok
		ok = await _check_currency_format(panel) and ok
		ok = _check_animated_connectors(panel, gs) and ok

		panel.close()
		await process_frame
		var connectors_closed: Control = panel.get_node("Content/TreeViewport/TreeWorld/Connectors")
		if connectors_closed != null and connectors_closed.is_processing():
			print("FAIL: connectors should stop processing when panel closes")
			ok = false
		if not range_view.visible:
			print("FAIL: range view should restore after closing upgrade view")
			ok = false

	gs.reset_to_fresh()
	await process_frame
	var icon_bar_node: Node = main.get_node("UI/UIRoot/GameplayChrome/IconBar")
	if not gs.upgrades_unlocked:
		print("FAIL: upgrades should be unlocked by default after reset")
		ok = false
	if icon_bar_node.upgrades_button.disabled:
		print("FAIL: upgrades button should be enabled by default")
		ok = false
	if not icon_bar_node.upgrades_button.tooltip_text.is_empty():
		print("FAIL: upgrades button should have no unlock tooltip")
		ok = false

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


func _check_animated_connectors(panel: Control, gs: Node) -> bool:
	var connectors: Control = panel.get_node_or_null("Content/TreeViewport/TreeWorld/Connectors")
	if connectors == null:
		print("FAIL: Connectors node missing")
		return false
	if connectors.get_script() == null:
		print("FAIL: Connectors should have upgrade_tree_connectors script")
		return false
	if not connectors.has_method("set_animating") or not connectors.has_method("get_phase"):
		print("FAIL: Connectors missing animation API")
		return false
	if not connectors.is_processing():
		print("FAIL: connectors should process while panel is open")
		return false
	var phase_a: float = connectors.get_phase()
	# Advance shared phase the same way connectors do each frame.
	UpgradeTreeStroke.advance_phase(0.05)
	var phase_b: float = UpgradeTreeStroke.get_phase()
	if phase_b <= phase_a:
		print("FAIL: stroke phase should advance (a=%.3f b=%.3f)" % [phase_a, phase_b])
		return false

	gs.upgrade_levels = {}
	gs.shop_levels = {}
	gs._recompute_stats()
	var dormant := UpgradeTreeConnectors.resolve_edge_state("distance_pay")
	if dormant != UpgradeTreeStroke.EdgeState.DORMANT:
		print("FAIL: distance_pay edge should be DORMANT before unlock, got ", dormant)
		return false

	gs.currency = 500.0
	gs.upgrade_levels = {"base_pay": 1}
	gs._recompute_stats()
	var charged := UpgradeTreeConnectors.resolve_edge_state("distance_pay")
	if charged != UpgradeTreeStroke.EdgeState.CHARGED:
		print("FAIL: distance_pay edge should be CHARGED when affordable, got ", charged)
		return false

	gs.currency = 0.0
	var live := UpgradeTreeConnectors.resolve_edge_state("distance_pay")
	if live != UpgradeTreeStroke.EdgeState.LIVE:
		print("FAIL: distance_pay edge should be LIVE when unlocked but unaffordable, got ", live)
		return false

	var def := UpgradeGraph.get_def("distance_pay")
	var distance_branch := int(def.get("branch", Balance.UpgradeBranch.BASE_PAY))
	if distance_branch != Balance.UpgradeBranch.POWER:
		print("FAIL: distance_pay should be POWER branch for stroke color")
		return false
	var power_palette := UpgradeTreeStroke.palette_for_branch(Balance.UpgradeBranch.POWER)
	var charged_style := UpgradeTreeStroke.edge_style(
		UpgradeTreeStroke.EdgeState.CHARGED,
		Balance.UpgradeBranch.POWER
	)
	if charged_style["color"] != power_palette["charged"]:
		print("FAIL: POWER charged edge color mismatch")
		return false

	var max_level := int(def.get("max_level", 1))
	gs.upgrade_levels = {"base_pay": 1, "distance_pay": max_level}
	gs._recompute_stats()
	var complete := UpgradeTreeConnectors.resolve_edge_state("distance_pay")
	if complete != UpgradeTreeStroke.EdgeState.COMPLETE:
		print("FAIL: distance_pay edge should be COMPLETE when maxed, got ", complete)
		return false

	var sample_node: Node = panel.get_node("Content/TreeViewport/TreeWorld/Nodes").get_child(0)
	if sample_node.get_node_or_null("BorderOverlay") == null:
		print("FAIL: tree nodes should have BorderOverlay")
		return false

	print("OK: animated connectors + border overlays")
	return true


func _check_tree_node_icons(nodes_root: Control) -> bool:
	var ok := true
	for child in nodes_root.get_children():
		var icon: Node = child.get_node_or_null("ShapeIcon")
		if icon == null or not icon is TextureRect:
			print("FAIL: tree node %s missing ShapeIcon TextureRect" % child.name)
			ok = false
			continue
		if (icon as TextureRect).texture == null:
			print("FAIL: tree node %s has no icon texture after setup" % child.name)
			ok = false
	if ok:
		print("OK: all tree nodes have upgrade icon textures")
	return ok


func _check_branch_stroke_palettes() -> bool:
	var ok := true
	var required_keys := ["dormant", "live", "charged", "complete", "glow", "base"]
	for branch in [
		Balance.UpgradeBranch.BASE_PAY,
		Balance.UpgradeBranch.POWER,
		Balance.UpgradeBranch.QUALITY,
		Balance.UpgradeBranch.PICKUP,
	]:
		var palette: Dictionary = UpgradeTreeStroke.palette_for_branch(branch)
		for key in required_keys:
			if not palette.has(key):
				print("FAIL: branch %d palette missing key %s" % [branch, key])
				ok = false
	if ok:
		print("OK: branch stroke palettes cover BASE_PAY/POWER/QUALITY/PICKUP")
	return ok


func _check_tree_node_icon_centering(nodes_root: Control) -> bool:
	var ok := true
	var expected_size := UpgradeIcon.DEFAULT_NODE_SIZE
	var node_center := expected_size * 0.5
	for child in nodes_root.get_children():
		if child is Control and not (child as Control).size.is_equal_approx(expected_size):
			print(
				"FAIL: node size should be %s on %s (got %s)"
				% [expected_size, child.name, (child as Control).size]
			)
			ok = false
		var tip: Control = child.get_node_or_null("TooltipPanel") as Control
		if tip != null and not tip.top_level:
			print("FAIL: TooltipPanel should be top_level on %s" % child.name)
			ok = false
		var icon: TextureRect = child.get_node_or_null("ShapeIcon") as TextureRect
		if icon == null:
			continue
		if icon.stretch_mode != TextureRect.STRETCH_KEEP_CENTERED:
			print(
				"FAIL: icon stretch_mode should be KEEP_CENTERED on %s (got %d)"
				% [child.name, icon.stretch_mode]
			)
			ok = false
		var icon_center := icon.position + icon.size * 0.5
		if not icon_center.is_equal_approx(node_center):
			print(
				"FAIL: icon rect off-center on %s (center=%s expected=%s)"
				% [child.name, icon_center, node_center]
			)
			ok = false
		if icon.texture != null:
			var tex_size := icon.texture.get_size()
			if tex_size != Vector2(32, 32):
				print(
					"FAIL: icon texture should be 32x32 on %s (got %s)"
					% [child.name, tex_size]
				)
				ok = false
	if ok:
		print("OK: tree node icons centered in 44x44 medallions")
	return ok


func _check_ratina_pink_palette() -> bool:
	var hire_palette := UpgradeTreeStroke.palette_for_upgrade("ratina_hire")
	var base_palette := UpgradeTreeStroke.palette_for_upgrade("ratina_base_pay")
	var player_palette := UpgradeTreeStroke.palette_for_upgrade("base_pay")
	var power_palette := UpgradeTreeStroke.palette_for_branch(Balance.UpgradeBranch.POWER)
	if hire_palette["charged"] == player_palette["charged"]:
		print("FAIL: ratina_hire should use pink palette, not Base Pay gold")
		return false
	if base_palette["charged"] != hire_palette["charged"]:
		print("FAIL: Ratina subtree should share pink palette with ratina_hire")
		return false
	if not UpgradeTreeStroke.is_ratina_upgrade("ratina_hire"):
		print("FAIL: ratina_hire should be detected as Ratina upgrade")
		return false
	var power_charged: Color = power_palette["charged"]
	var ratina_charged: Color = hire_palette["charged"]
	# True red: high R, low G; pink: high R and G closer together.
	if power_charged.g >= 0.45:
		print("FAIL: Power charged should be true red (low green), got ", power_charged)
		return false
	if absf(power_charged.g - ratina_charged.g) < 0.15:
		print("FAIL: Power red and Ratina pink greens too similar")
		return false
	print("OK: Ratina pink + Power true-red stroke palettes")
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
	## Press arms pan but must not claim the event (HitButtons need the press).
	if panel.consume_pan_drag_event(_left_down(origin)):
		print("FAIL: pan press should arm without claiming (return false)")
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


func _check_desktop_click_buys(gs: Node, panel: Control) -> bool:
	## Desktop/mouse: inspect mode off → single press purchases.
	UpgradeNodeTap.force_inspect_mode = false
	UpgradeNodeTap.clear()
	_reset_tree_progress(gs)
	gs.currency = 500.0
	panel.consume_pan_drag_event(_left_down(Vector2(-100.0, -100.0)))
	panel.open()
	await process_frame
	await process_frame
	panel._refresh_all()
	await process_frame
	var node := _find_tree_node(panel, "base_pay")
	if node == null:
		print("FAIL: base_pay tree node missing for desktop click-buy")
		return false
	if UpgradeNodeTap.is_inspect_mode():
		print("FAIL: desktop path should not be in inspect mode")
		return false
	var level_before: int = gs.get_upgrade_level("base_pay")
	node._on_pressed()
	await process_frame
	if gs.get_upgrade_level("base_pay") != level_before + 1:
		print(
			"FAIL: desktop single click should buy (before=%d after=%d)"
			% [level_before, gs.get_upgrade_level("base_pay")]
		)
		return false
	print("OK: desktop single click buys")
	return true


func _check_pan_press_does_not_claim(panel: Control) -> bool:
	var camera: Node = panel.get_node("TreeCameraController")
	var tree_viewport: Control = panel.get_node("Content/TreeViewport")
	if camera == null or tree_viewport == null:
		print("FAIL: missing camera/viewport for pan-press claim check")
		return false
	if not panel.is_open():
		panel.open()
	var origin: Vector2 = tree_viewport.get_global_rect().get_center()
	## Simulate a click that never crosses the drag threshold.
	if panel.consume_pan_drag_event(_left_down(origin)):
		print("FAIL: click press must not be claimed by tree pan")
		return false
	var wiggle := origin + Vector2(2.0, 1.0)
	if panel.consume_pan_drag_event(_mouse_motion(wiggle)):
		print("FAIL: sub-threshold motion must not be claimed by tree pan")
		return false
	if camera.did_drag():
		print("FAIL: sub-threshold click should not set did_drag")
		return false
	panel.consume_pan_drag_event(_left_up(wiggle))
	print("OK: pan press/wiggle leaves click free for HitButton")
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


func _check_tap_inspect_then_buy(gs: Node, panel: Control) -> bool:
	UpgradeNodeTap.force_inspect_mode = true
	UpgradeNodeTap.clear()
	_reset_tree_progress(gs)
	gs.currency = 500.0
	## Clear sticky did_drag from prior pan checks so inspect isn't blocked.
	panel.consume_pan_drag_event(_left_down(Vector2(-100.0, -100.0)))
	panel.open()
	await process_frame
	await process_frame
	panel._refresh_all()
	await process_frame
	var node := _find_tree_node(panel, "base_pay")
	if node == null:
		print("FAIL: base_pay tree node missing for tap-inspect")
		UpgradeNodeTap.force_inspect_mode = false
		UpgradeNodeTap.clear()
		return false
	var level_before: int = gs.get_upgrade_level("base_pay")
	node._on_pressed()
	await process_frame
	if gs.get_upgrade_level("base_pay") != level_before:
		print("FAIL: first tap should inspect, not buy")
		UpgradeNodeTap.force_inspect_mode = false
		UpgradeNodeTap.clear()
		return false
	if not UpgradeNodeTap.is_selected(node):
		print("FAIL: first tap should select the node")
		UpgradeNodeTap.force_inspect_mode = false
		UpgradeNodeTap.clear()
		return false
	var tip: Control = node.get_node_or_null("TooltipPanel") as Control
	if tip == null or not tip.visible:
		print("FAIL: first tap should show hover tooltip")
		UpgradeNodeTap.force_inspect_mode = false
		UpgradeNodeTap.clear()
		return false
	node._on_pressed()
	await process_frame
	if gs.get_upgrade_level("base_pay") != level_before + 1:
		print(
			"FAIL: second tap should buy (before=%d after=%d)"
			% [level_before, gs.get_upgrade_level("base_pay")]
		)
		UpgradeNodeTap.force_inspect_mode = false
		UpgradeNodeTap.clear()
		return false
	UpgradeNodeTap.force_inspect_mode = false
	UpgradeNodeTap.clear()
	print("OK: first tap inspects, second tap buys")
	return true


func _check_continuous_zoom(panel: Control) -> bool:
	var camera: Node = panel.get_node("TreeCameraController")
	if camera == null or not camera.has_method("get_zoom_target"):
		print("FAIL: tree camera missing get_zoom_target")
		return false
	if not panel.is_open():
		panel.open()
	var z0: float = camera.get_zoom_target()
	var mag := InputEventMagnifyGesture.new()
	mag.factor = 1.12
	mag.position = panel.get_node("Content/TreeViewport").get_global_rect().get_center()
	if not panel.consume_zoom_event(mag):
		print("FAIL: MagnifyGesture should be consumed")
		return false
	var z1: float = camera.get_zoom_target()
	if z1 <= z0:
		print("FAIL: pinch should zoom in continuously (%.4f -> %.4f)" % [z0, z1])
		return false
	if z1 > z0 * 1.4:
		print("FAIL: pinch zoom too steppy (%.4f -> %.4f)" % [z0, z1])
		return false
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	t0.position = Vector2(120, 140)
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = Vector2(180, 140)
	panel.consume_zoom_event(t0)
	panel.consume_zoom_event(t1)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(220, 140)
	var z2: float = camera.get_zoom_target()
	if not panel.consume_zoom_event(drag):
		print("FAIL: two-finger pinch drag should zoom")
		return false
	var z3: float = camera.get_zoom_target()
	if z3 <= z2:
		print("FAIL: two-finger pinch should zoom in (%.4f -> %.4f)" % [z2, z3])
		return false
	print("OK: continuous pinch zoom (magnify %.3f->%.3f, fingers %.3f->%.3f)" % [z0, z1, z2, z3])
	return true


func _check_portrait_tree_fit(main: Node, panel: Control) -> bool:
	_set_logical_size(Vector2i(270, 480))
	await process_frame
	if main.has_method("_notify_portrait_layout"):
		main._notify_portrait_layout()
	panel.open()
	await process_frame
	await process_frame
	if not RadialTreeLayout.use_portrait_aspect:
		print("FAIL: portrait layout should set use_portrait_aspect")
		_restore_landscape_tree(main, panel)
		return false
	var aspect := RadialTreeLayout.content_aspect(panel._layout_positions)
	if absf(aspect / RadialTreeLayout.PORTRAIT_ASPECT - 1.0) > RadialTreeLayout.ASPECT_TOLERANCE:
		print(
			"FAIL: portrait tree aspect %.3f not within tolerance of 9:16"
			% aspect
		)
		_restore_landscape_tree(main, panel)
		return false
	var header: Control = panel.get_node("Content/Header")
	var header_rect := header.get_global_rect()
	var nodes_root: Control = panel.get_node("Content/TreeViewport/TreeWorld/Nodes")
	for child in nodes_root.get_children():
		if not child.visible or not (child is Control):
			continue
		var center: Vector2 = (child as Control).get_global_rect().get_center()
		if header_rect.has_point(center):
			print("FAIL: tree node center under header after portrait fit: ", child.name)
			_restore_landscape_tree(main, panel)
			return false
	panel._select_tab(panel.Tab.PRESTIGE)
	await process_frame
	await process_frame
	var prestige_btn: Control = panel.get_node_or_null("Content/PrestigeButton") as Control
	if prestige_btn != null and prestige_btn.visible:
		var btn_rect := prestige_btn.get_global_rect()
		var prestige_nodes: Control = panel.get_node("Content/TreeViewport/TreeWorld/Nodes")
		for child in prestige_nodes.get_children():
			if not child.visible or not (child is Control):
				continue
			var center: Vector2 = (child as Control).get_global_rect().get_center()
			if btn_rect.has_point(center):
				print("FAIL: prestige node center under Prestige button")
				_restore_landscape_tree(main, panel)
				return false
	print("OK: portrait tree aspect=%.3f and chrome clears node centers" % aspect)
	_restore_landscape_tree(main, panel)
	return true


func _restore_landscape_tree(main: Node, panel: Control) -> void:
	UpgradeNodeTap.force_inspect_mode = false
	UpgradeNodeTap.clear()
	_set_logical_size(Vector2i(480, 270))
	if main.has_method("_notify_portrait_layout"):
		main._notify_portrait_layout()
	RadialTreeLayout.use_portrait_aspect = false
	if panel.has_method("apply_viewport_layout"):
		panel.apply_viewport_layout()
	if panel.has_method("_select_tab"):
		panel._select_tab(panel.Tab.PLAY)


func _set_logical_size(size: Vector2i) -> void:
	var win := root as Window
	if win == null:
		return
	win.content_scale_size = size
	win.size = size
	if win.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func _find_tree_node(panel: Control, upgrade_id: String) -> Node:
	var nodes_root: Control = panel.get_node_or_null("Content/TreeViewport/TreeWorld/Nodes")
	if nodes_root == null:
		return null
	for child in nodes_root.get_children():
		if child.get("upgrade_id") == upgrade_id:
			return child
	return null


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


func _reset_tree_progress(gs: Node) -> void:
	gs.upgrade_levels = {}
	gs.shop_levels = {}
	gs.ratina_upgrade_levels = {}
	gs.rattling_upgrade_levels = {}
	gs._recompute_stats()


func _count_visible_nodes(nodes_root: Control) -> int:
	var count := 0
	for child in nodes_root.get_children():
		if child.visible:
			count += 1
	return count
