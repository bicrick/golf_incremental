extends SceneTree
## Headless Pro Shop smoke test — run:
## godot --headless --script res://tools/verify_shop.gd


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

	var icon_bar: Node = main.get_node("UI/UIRoot/IconBar")
	var shop_wrap: Control = icon_bar.get_node("TopRight/TopRightRow/ShopWrap")
	var shop_button: Button = icon_bar.get_node("TopRight/TopRightRow/ShopWrap/ShopButton")
	var shop_panel: Control = main.get_node("UI/UIRoot/ShopPanel")
	var upgrade_panel: Control = main.get_node("UI/UIRoot/UpgradePanel")

	gs.reset_to_fresh()
	await process_frame
	if icon_bar.has_method("_refresh_shop_lock_state"):
		icon_bar._refresh_shop_lock_state()
	if shop_wrap.visible:
		print("FAIL: shop icon visible before base_pay Lv.1")
		ok = false
	else:
		print("OK: shop icon hidden before base_pay Lv.1")

	gs.currency = 500.0
	gs.upgrades_unlocked = true
	if not gs.purchase_upgrade("base_pay"):
		print("FAIL: could not purchase base_pay")
		ok = false
	await process_frame
	if icon_bar.has_method("_refresh_shop_lock_state"):
		icon_bar._refresh_shop_lock_state()
		icon_bar._layout_top_right_corner()
	if not shop_wrap.visible:
		print("FAIL: shop icon should appear after base_pay Lv.1")
		ok = false
	else:
		print("OK: shop icon visible after base_pay Lv.1")

	if gs.shop_unlocked:
		print("FAIL: shop should start locked")
		ok = false
	var before_unlock_currency: float = gs.currency
	if not gs.try_unlock_shop():
		print("FAIL: try_unlock_shop failed with sufficient funds")
		ok = false
	if not gs.shop_unlocked:
		print("FAIL: shop_unlocked flag not set")
		ok = false
	if not is_equal_approx(before_unlock_currency - gs.currency, Balance.SHOP_UNLOCK_COST):
		print(
			"FAIL: shop unlock should cost $50, spent %.2f"
			% (before_unlock_currency - gs.currency)
		)
		ok = false
	else:
		print("OK: shop unlock costs $50")

	var before_capacity: int = gs.get_bucket_capacity()
	if not gs.purchase_shop_item("ball_count"):
		print("FAIL: could not purchase ball_count")
		ok = false
	elif gs.get_bucket_capacity() != before_capacity + 1:
		print(
			"FAIL: ball_count expected capacity %d, got %d"
			% [before_capacity + 1, gs.get_bucket_capacity()]
		)
		ok = false
	else:
		print("OK: ball_count increases bucket capacity")

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

	gs.currency = Balance.RATINA_UNLOCK_COST + 10.0
	var before_ratina: float = gs.currency
	if not gs.try_unlock_ratina():
		print("FAIL: try_unlock_ratina failed with sufficient funds")
		ok = false
	if not gs.ratina_unlocked:
		print("FAIL: ratina_unlocked flag not set")
		ok = false
	if not is_equal_approx(before_ratina - gs.currency, Balance.RATINA_UNLOCK_COST):
		print("FAIL: ratina unlock should cost $100")
		ok = false
	else:
		print("OK: ratina unlock costs $100")

	main.get_node("TitleScreen").visible = false
	main.get_node("RangeView").visible = true
	main.get_node("UI").visible = true
	main._set_gameplay_ui_visible(true)
	await process_frame

	shop_panel.open()
	await process_frame
	if not shop_panel.visible:
		print("FAIL: shop panel not visible after open()")
		ok = false
	else:
		print("OK: shop panel opens")

	shop_panel.close()
	await process_frame

	upgrade_panel.open()
	await process_frame
	var ratina_tab: Button = upgrade_panel.get_node("Content/Header/TabRow/RatinaTab")
	if not ratina_tab.visible:
		print("FAIL: Ratina tab should be visible after hire")
		ok = false
	else:
		print("OK: Ratina tab visible after hire")
	ratina_tab.pressed.emit()
	await process_frame
	var ratina_placeholder: Control = upgrade_panel.get_node("Content/RatinaPlaceholder")
	if not ratina_placeholder.visible:
		print("FAIL: Ratina placeholder should show when tab selected")
		ok = false
	else:
		print("OK: Ratina placeholder tab works")

	gs.upgrade_levels = {}
	gs.shop_levels = {"golden_ball": 1}
	gs._recompute_stats()
	var base_payout: float = Economy.resolve_pickup_ball_payout(1, 30.0, 1, gs.stats)
	var doubled_payout: float = base_payout * gs.stats.golden_ball_payout_multiplier
	if not is_equal_approx(doubled_payout, base_payout * 2.0):
		print("FAIL: golden payout multiplier expected 2x, got %.4f vs %.4f" % [doubled_payout, base_payout * 2.0])
		ok = false
	elif not is_equal_approx(gs.stats.golden_ball_payout_multiplier, Balance.GOLDEN_BALL_PAYOUT_MULTIPLIER):
		print("FAIL: golden_ball_payout_multiplier mismatch")
		ok = false
	else:
		print("OK: golden payout multiplier is 2x")

	print("shop_ok=", ok)
	quit(0 if ok else 1)
