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
	if not margin.has_node("VBox/TopRow/CurrencyPanel"):
		print("FAIL: CurrencyPanel missing from HUD margin")
		ok = false
	if not margin.get_node("VBox/TopRow/CurrencyPanel") is PanelContainer:
		print("FAIL: CurrencyPanel should be a PanelContainer")
		ok = false
	var currency_panel: Control = margin.get_node("VBox/TopRow/CurrencyPanel")
	if currency_panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		print("FAIL: CurrencyPanel should STOP mouse so money-tap opens pause")
		ok = false
	if not hud.has_method("open_pause_menu"):
		print("FAIL: HUD missing open_pause_menu")
		ok = false
	else:
		var pause_menu: Control = main.get_node_or_null("SettingsLayer/PauseMenu")
		if pause_menu == null or not pause_menu.has_method("open"):
			print("FAIL: PauseMenu missing")
			ok = false
		else:
			## Title is still showing; hide it so money-tap can open pause.
			var title_screen: CanvasLayer = main.get_node_or_null("TitleScreen")
			if title_screen != null:
				title_screen.visible = false
			main.ui.visible = true
			hud.open_pause_menu()
			await process_frame
			if not pause_menu.is_open():
				print("FAIL: money-tap path should open pause menu")
				ok = false
			else:
				print("OK: HUD currency opens pause")
			if not pause_menu.has_method("should_show_exit_button"):
				print("FAIL: PauseMenu missing should_show_exit_button")
				ok = false
			else:
				var exit_btn: Button = pause_menu.get_node_or_null(
					"Content/Center/MainRow/LeftPane/ExitButton"
				)
				if exit_btn == null:
					print("FAIL: ExitButton missing")
					ok = false
				elif exit_btn.visible != pause_menu.should_show_exit_button():
					print("FAIL: ExitButton visibility should match should_show_exit_button()")
					ok = false
				elif OS.has_feature("web") and exit_btn.visible:
					print("FAIL: Exit Game must be hidden on web")
					ok = false
				else:
					print("OK: Exit Game visibility=", exit_btn.visible)
			pause_menu.close()
			if title_screen != null:
				title_screen.visible = true
	if not margin.has_node("VBox/TopRow/RatinaChip"):
		print("FAIL: RatinaChip missing from HUD top row")
		ok = false
	if not margin.has_node("VBox/TopRow/RattlingChip"):
		print("FAIL: RattlingChip missing from HUD top row")
		ok = false
	var rattling_chip: Control = margin.get_node("VBox/TopRow/RattlingChip")
	var rattling_button: Button = rattling_chip.get_node("Button")
	if rattling_button.focus_mode != Control.FOCUS_NONE:
		print("FAIL: RattlingChip button should not grab keyboard focus (Space swing collision)")
		ok = false
	var ratina_chip: Control = margin.get_node("VBox/TopRow/RatinaChip")
	var ratina_button: Button = ratina_chip.get_node("Button")
	if ratina_button.focus_mode != Control.FOCUS_NONE:
		print("FAIL: RatinaChip button should not grab keyboard focus (Space swing collision)")
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
	if icon_bar.has_node("BottomRight/HitWrap") or icon_bar.has_node("BottomRight/HitButton"):
		print("FAIL: harvest Hit toggle should be removed")
		ok = false
	if icon_bar.get_node_or_null("TopRight/UpgradesWrap/UpgradesButton") == null:
		print("FAIL: upgrades button missing from IconBar")
		ok = false
	if icon_bar.has_node("TopRight/BuildWrap") or icon_bar.has_node("TopRight/BuildButton"):
		print("FAIL: Build button should be removed from IconBar")
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
	if gs != null:
		gs.bucket_remaining = 3
		if not gs.try_enter_harvest():
			print("FAIL: try_enter_harvest should succeed for bucket ball-return check")
			ok = false
		else:
			await process_frame
			if bucket_counter.mouse_filter != Control.MOUSE_FILTER_STOP:
				print("FAIL: harvest bucket should STOP mouse so it is tappable ball-return")
				ok = false
			else:
				print("OK: harvest bucket mouse_filter STOP")
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			bucket_counter._on_gui_input(click)
			await process_frame
			if gs.current_phase != "strike":
				print(
					"FAIL: harvest bucket tap should return_all_balls_free, got %s"
					% gs.current_phase
				)
				ok = false
			elif gs.bucket_remaining != gs.bucket_capacity:
				print(
					"FAIL: bucket ball-return should refill leftover balls, expected %d got %d"
					% [gs.bucket_capacity, gs.bucket_remaining]
				)
				ok = false
			else:
				print("OK: harvest bucket tap returns leftover balls and exits to strike")

	if not margin.has_node("VBox/IncomeStack"):
		print("FAIL: IncomeStack missing from HUD")
		ok = false
	else:
		var income_stack: Node = margin.get_node("VBox/IncomeStack")
		if income_stack.get_script() == null:
			print("FAIL: IncomeStack should have income_stack.gd script")
			ok = false
	if margin.has_node("VBox/RattlingIncomeLabel"):
		print("FAIL: legacy RattlingIncomeLabel still in HUD")
		ok = false

	var currency_label: Label = margin.get_node("VBox/TopRow/CurrencyPanel/CurrencyLabel")
	var before_text := currency_label.text
	if gs != null:
		var start_currency: float = gs.currency
		gs.add_currency(12.5)
		await process_frame
		await process_frame
		# Reel should be animating or already showing a value between start and target.
		if currency_label.text == before_text and not is_equal_approx(start_currency, gs.currency):
			# Allow brief same-frame; wait for tween progress.
			await create_timer(0.15).timeout
		if currency_label.text == "$%s" % _format_amount(start_currency) and gs.currency > start_currency + 0.01:
			# Still at old value after 150ms is a fail — reel should have moved.
			print("FAIL: currency reel did not advance after add_currency")
			ok = false
		await create_timer(0.85).timeout
		var expected := "$%s" % _format_amount(gs.currency)
		if currency_label.text != expected:
			print("FAIL: currency reel should settle to %s, got %s" % [expected, currency_label.text])
			ok = false
		else:
			print("OK: currency reel settled to %s" % expected)
		# Spends should snap down immediately.
		var event_bus: Node = root.get_node("EventBus")
		var spend_target: float = maxf(gs.currency - 5.0, 0.0)
		gs.currency = spend_target
		event_bus.currency_changed.emit(spend_target)
		await process_frame
		await process_frame
		var spend_expected := "$%s" % _format_amount(spend_target)
		if currency_label.text != spend_expected:
			print("FAIL: currency reel should snap on spend to %s, got %s" % [spend_expected, currency_label.text])
			ok = false
		else:
			print("OK: currency reel snaps on spend")
		# Income stack should accept a push via pickup_payout.
		var stack: Node = margin.get_node("VBox/IncomeStack")
		var rows_before := stack.get_child_count()
		event_bus.pickup_payout.emit(3.25, 1)
		await process_frame
		if stack.get_child_count() != rows_before + 1:
			print("FAIL: IncomeStack should gain a row on pickup_payout")
			ok = false
		else:
			var top_row: Label = stack.get_child(0)
			if not top_row.text.begins_with("+$"):
				print("FAIL: IncomeStack top row should be +$ text, got %s" % top_row.text)
				ok = false
			else:
				print("OK: IncomeStack prepends +$ row")
		# Spam past MAX_ROWS must not hang (queue_free alone does not drop child count).
		for i in 12:
			event_bus.pickup_payout.emit(0.1 + float(i) * 0.01, 1)
		await process_frame
		if stack.get_child_count() > 5:
			print(
				"FAIL: IncomeStack should cap at 5 rows after spam, got %d"
				% stack.get_child_count()
			)
			ok = false
		else:
			print("OK: IncomeStack caps at %d rows under spam" % stack.get_child_count())

	print("hud_layout_ok=", ok)
	quit(0 if ok else 1)


func _format_amount(amount: float) -> String:
	const FloatCashText := preload("res://scripts/visual/float_cash_text.gd")
	return FloatCashText.format_amount(amount)
