extends SceneTree
## godot --headless --path . --script res://tools/verify_prestige.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.cheese = 0
	gs.prestige_count = 0
	gs.prestige_levels = {}
	gs.upgrade_levels = {}
	gs.shop_levels = {}
	gs._recompute_stats()

	# --- Part 0: prestige gate + wipe ---
	gs.currency = 4999.0
	if gs.prestige():
		print("FAIL: prestige allowed under threshold")
		quit(1)
		return
	gs.currency = 5000.0
	gs.upgrade_levels = {"base_pay": 3}
	if not gs.prestige():
		print("FAIL: prestige denied at threshold")
		quit(1)
		return
	if gs.currency != 0.0:
		print("FAIL: cash not wiped")
		quit(1)
		return
	if gs.get_upgrade_level("base_pay") != 0:
		print("FAIL: play upgrades not wiped")
		quit(1)
		return
	if gs.cheese < 1:
		print("FAIL: expected cheese >= 1, got %d" % gs.cheese)
		quit(1)
		return
	if gs.prestige_count < 1:
		print("FAIL: prestige_count")
		quit(1)
		return
	print("OK: prestige cash-out wipe")

	# --- Costs are always 1 cheese ---
	if gs.get_prestige_upgrade_cost("cheese_press") != 1:
		print("FAIL: cheese_press cost expected 1, got %d" % gs.get_prestige_upgrade_cost("cheese_press"))
		quit(1)
		return
	print("OK: prestige upgrade base cost is 1")

	# --- Part 1: purchase cheese_press ---
	var cheese_before: int = int(gs.cheese)
	if not gs.purchase_prestige_upgrade("cheese_press"):
		print("FAIL: could not buy cheese_press")
		quit(1)
		return
	if gs.get_prestige_upgrade_level("cheese_press") != 1:
		print("FAIL: cheese_press level")
		quit(1)
		return
	if gs.cheese != cheese_before - 1:
		print("FAIL: cheese spend expected %d, got %d" % [cheese_before - 1, gs.cheese])
		quit(1)
		return
	print("OK: cheese_press purchase")

	# Surplus cheese when cash >> threshold (ambition 0)
	# base 1 + cheese_press 1 = 2; surplus floor(5000/2500)=2 → total 4
	gs.prestige_levels = {"cheese_press": 1}
	gs._recompute_stats()
	var surplus_gain: int = gs.cheese_from_prestige_cash(10000.0)
	if surplus_gain != 4:
		print("FAIL: surplus cheese expected 4, got %d" % surplus_gain)
		quit(1)
		return
	print("OK: surplus cheese payout")

	# Ambition raises threshold (×2) and multiplies cheese payout by 2^ambition
	gs.prestige_levels = {"cheese_press": 1, "ambition": 1}
	gs._recompute_stats()
	if not is_equal_approx(gs.prestige_threshold, 10000.0):
		print("FAIL: ambition threshold expected 10000, got %.0f" % gs.prestige_threshold)
		quit(1)
		return
	# At threshold with press 1: (1+1+0 surplus) * 2^1 = 4
	var amb1_gain: int = gs.cheese_from_prestige_cash(10000.0)
	if amb1_gain != 4:
		print("FAIL: ambition×2 base payout expected 4, got %d" % amb1_gain)
		quit(1)
		return
	# Surplus 10000 over 10k → floor(10000/2500)=4; (2+4)*2 = 12
	var amb1_surplus: int = gs.cheese_from_prestige_cash(20000.0)
	if amb1_surplus != 12:
		print("FAIL: ambition×2 surplus payout expected 12, got %d" % amb1_surplus)
		quit(1)
		return
	gs.prestige_levels = {"cheese_press": 3, "ambition": 2}
	gs._recompute_stats()
	# press +3 → base 1+3=4; at threshold: 4 * 2^2 = 16
	var amb2_gain: int = gs.cheese_from_prestige_cash(gs.prestige_threshold)
	if amb2_gain != 16:
		print("FAIL: ambition×4 press payout expected 16, got %d" % amb2_gain)
		quit(1)
		return
	print("OK: ambition threshold + cheese multiplier")

	# Ambition purchase also costs 1
	gs.cheese = 5
	gs.prestige_levels = {"cheese_press": 1}
	gs._recompute_stats()
	if gs.get_prestige_upgrade_cost("ambition") != 1:
		print("FAIL: ambition cost expected 1")
		quit(1)
		return
	if not gs.purchase_prestige_upgrade("ambition"):
		print("FAIL: could not buy ambition")
		quit(1)
		return
	if gs.cheese != 4:
		print("FAIL: ambition should cost 1 cheese")
		quit(1)
		return
	print("OK: ambition costs 1 cheese")

	# Deep Bucket capacity after prestige wipe of play levels
	gs.prestige_levels = {"cheese_press": 1, "prestige_deep_bucket": 2}
	gs.upgrade_levels = {}
	gs.shop_levels = {}
	gs._recompute_stats()
	if gs.get_bucket_capacity() != Balance.BUCKET_CAPACITY_DEFAULT + 2:
		print(
			"FAIL: deep bucket capacity expected %d, got %d"
			% [Balance.BUCKET_CAPACITY_DEFAULT + 2, gs.get_bucket_capacity()]
		)
		quit(1)
		return
	print("OK: deep bucket capacity")

	# Combo mult 0 without perk, > 0 with perk
	gs.prestige_levels = {}
	gs._recompute_stats()
	if gs.stats.combo_mult_per_tier != 0.0:
		print("FAIL: combo should be 0 without perk")
		quit(1)
		return
	gs.prestige_levels = {"cheese_press": 1, "prestige_combo": 2}
	gs._recompute_stats()
	if not is_equal_approx(gs.stats.combo_mult_per_tier, 0.16):
		print("FAIL: combo mult expected 0.16, got %.3f" % gs.stats.combo_mult_per_tier)
		quit(1)
		return
	print("OK: combo hands")

	# Quick Reset lowers cooldown
	gs.prestige_levels = {}
	gs._recompute_stats()
	var base_cd: float = gs.stats.swing_cooldown_ms
	gs.prestige_levels = {"cheese_press": 1, "prestige_quick_reset": 1}
	gs._recompute_stats()
	var reduced_cd: float = gs.stats.swing_cooldown_ms
	if reduced_cd >= base_cd:
		print("FAIL: quick reset should lower cooldown (%.1f -> %.1f)" % [base_cd, reduced_cd])
		quit(1)
		return
	if not is_equal_approx(reduced_cd, base_cd * 0.85):
		print("FAIL: quick reset expected ×0.85, got %.3f" % (reduced_cd / base_cd))
		quit(1)
		return
	print("OK: quick reset cooldown")

	# Perfect Chain streak
	gs.prestige_levels = {"cheese_press": 1, "prestige_perfect_chain": 1}
	gs.perfect_swing_streak = 0
	gs._recompute_stats()
	if not gs.stats.perfect_chain_unlocked >= 1.0:
		print("FAIL: perfect chain unlock flag")
		quit(1)
		return
	gs.note_swing_tier(Balance.TimingTier.PERFECT)
	gs.note_swing_tier(Balance.TimingTier.PERFECT)
	gs.note_swing_tier(Balance.TimingTier.PERFECT)
	if not gs.is_perfect_chain_golden_active():
		print("FAIL: perfect chain golden should activate after 3 perfects")
		quit(1)
		return
	gs.note_swing_tier(Balance.TimingTier.GREAT)
	if gs.is_perfect_chain_golden_active():
		print("FAIL: perfect chain should break on non-perfect")
		quit(1)
		return
	print("OK: perfect chain streak")

	# Golden tee chance
	gs.prestige_levels = {"cheese_press": 1, "prestige_golden_tee": 3}
	gs._recompute_stats()
	if not is_equal_approx(gs.stats.golden_ball_chance, 0.06):
		print("FAIL: golden tee chance expected 0.06, got %.3f" % gs.stats.golden_ball_chance)
		quit(1)
		return
	print("OK: golden tee")

	print("OK verify_prestige")
	quit(0)
