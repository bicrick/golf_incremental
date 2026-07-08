extends SceneTree
## Headless shop-item tree smoke test — run:
## godot --headless --script res://tools/verify_shop.gd

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL: GameState autoload missing")
		quit(1)
		return

	gs.reset_to_fresh()
	gs.currency = 500.0
	gs.upgrades_unlocked = true
	if not gs.purchase_upgrade("base_pay"):
		print("FAIL: could not purchase base_pay")
		ok = false
	else:
		print("OK: base_pay unlocks branch heads including ball_count")

	if not UpgradeGraph.is_unlocked("ball_count"):
		print("FAIL: ball_count should unlock at base_pay Lv.1")
		ok = false

	var before_capacity: int = gs.get_bucket_capacity()
	if not gs.purchase_shop_item("ball_count"):
		print("FAIL: could not purchase ball_count without shop gate")
		ok = false
	elif gs.get_bucket_capacity() != before_capacity + 1:
		print(
			"FAIL: ball_count expected capacity %d, got %d"
			% [before_capacity + 1, gs.get_bucket_capacity()]
		)
		ok = false
	else:
		print("OK: ball_count increases bucket capacity from upgrade tree")

	ok = _check_ball_count_max_capacity(gs) and ok

	if not gs.purchase_shop_item("golden_ball"):
		print("FAIL: could not purchase golden_ball Lv.1")
		ok = false
	elif not is_equal_approx(gs.stats.golden_ball_chance, Balance.GOLDEN_BALL_BASE_CHANCE):
		print(
			"FAIL: golden_ball Lv.1 expected %.2f chance, got %.2f"
			% [Balance.GOLDEN_BALL_BASE_CHANCE, gs.stats.golden_ball_chance]
		)
		ok = false
	else:
		print("OK: golden_ball Lv.1 unlocks 5%% chance")

	if not gs.purchase_shop_item("golden_ball"):
		print("FAIL: could not purchase golden_ball Lv.2")
		ok = false
	var expected_chance := (
		Balance.GOLDEN_BALL_BASE_CHANCE + Balance.GOLDEN_BALL_CHANCE_PER_LEVEL
	)
	if not is_equal_approx(gs.stats.golden_ball_chance, expected_chance):
		print(
			"FAIL: golden_ball Lv.2 expected %.2f chance, got %.2f"
			% [expected_chance, gs.stats.golden_ball_chance]
		)
		ok = false
	else:
		print("OK: golden_ball Lv.2 increases chance")

	gs.currency = Balance.RATINA_UNLOCK_COST + 50.0
	gs.upgrade_levels["base_pay"] = 3
	gs._recompute_stats()
	var before_ratina: float = gs.currency
	if not gs.purchase_upgrade("ratina_hire"):
		print("FAIL: could not purchase ratina_hire from tree")
		ok = false
	if not gs.ratina_unlocked:
		print("FAIL: ratina_unlocked flag not set")
		ok = false
	if not is_equal_approx(before_ratina - gs.currency, Balance.RATINA_UNLOCK_COST):
		print("FAIL: ratina hire should cost $100")
		ok = false
	else:
		print("OK: ratina hire costs $100 from upgrade tree")

	main.get_node("TitleScreen").visible = false
	main.get_node("RangeView").visible = true
	main.get_node("UI").visible = true
	main._set_gameplay_ui_visible(true)
	await process_frame

	var upgrade_panel: Control = main.get_node("UI/UIRoot/UpgradePanel")
	upgrade_panel.open()
	await process_frame
	if not upgrade_panel.visible:
		print("FAIL: upgrade panel not visible after open()")
		ok = false
	else:
		print("OK: unified upgrade panel opens")

	var nodes_root: Control = upgrade_panel.get_node("Content/TreeViewport/TreeWorld/Nodes")
	var ratina_node: Node = null
	for child in nodes_root.get_children():
		if child.upgrade_id == "ratina_base_pay":
			ratina_node = child
			break
	if ratina_node == null:
		print("FAIL: ratina_base_pay node missing from mega-tree")
		ok = false
	elif not ratina_node.visible:
		print("FAIL: ratina_base_pay should be visible after hire")
		ok = false
	else:
		print("OK: ratina subtree visible in unified tree")

	upgrade_panel.close()
	await process_frame

	gs.upgrade_levels = {"base_pay": 1}
	gs.shop_levels = {"golden_ball": 1}
	gs._recompute_stats()
	var base_payout: float = Economy.resolve_pickup_ball_payout(1, 30.0, 1, gs.stats)
	var doubled_payout: float = base_payout * gs.stats.golden_ball_payout_multiplier
	if not is_equal_approx(doubled_payout, base_payout * 2.0):
		print("FAIL: golden payout multiplier expected 2x")
		ok = false
	else:
		print("OK: golden payout multiplier is 2x")

	print("shop_ok=", ok)
	quit(0 if ok else 1)


func _check_ball_count_max_capacity(gs: Node) -> bool:
	gs.reset_to_fresh()
	gs.currency = 1_000_000.0
	gs.upgrades_unlocked = true
	gs.purchase_upgrade("base_pay")
	var def: Dictionary = ShopDefinitions.get_def("ball_count")
	var max_level: int = int(def.get("max_level", 0))
	for _i in max_level:
		if not gs.purchase_shop_item("ball_count"):
			print("FAIL: could not purchase ball_count to max level")
			return false
	if gs.get_bucket_capacity() != Balance.BUCKET_CAPACITY_MAX:
		print(
			"FAIL: max ball_count should reach capacity %d, got %d"
			% [Balance.BUCKET_CAPACITY_MAX, gs.get_bucket_capacity()]
		)
		return false
	print("OK: ball_count reaches max bucket capacity %d" % Balance.BUCKET_CAPACITY_MAX)
	return true
