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
	gs.cheese = 0.0
	gs.prestige_count = 0
	gs.prestige_levels = {}
	gs.currency = 4999.0
	gs._recompute_stats()
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
	if gs.cheese < 1.0:
		print("FAIL: expected cheese >= 1")
		quit(1)
		return
	if gs.prestige_count < 1:
		print("FAIL: prestige_count")
		quit(1)
		return
	print("OK verify_prestige Part 0")
	quit(0)
