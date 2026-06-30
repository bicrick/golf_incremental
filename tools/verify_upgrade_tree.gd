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

	var panel: Control = main.get_node("UI/UIRoot/UpgradePanel")
	if panel == null:
		print("FAIL: UpgradePanel missing from main")
		ok = false
	else:
		panel.open()
		await process_frame
		if not panel.visible:
			print("FAIL: panel not visible after open()")
			ok = false
		var nodes_root: Control = panel.get_node("ModalRoot/Frame/Content/TreeCanvas/Nodes")
		if nodes_root.get_child_count() != 10:
			print("FAIL: expected 10 tree nodes, got ", nodes_root.get_child_count())
			ok = false
		panel.close()
		if panel.visible:
			print("FAIL: panel still visible after close()")
			ok = false

	print("upgrade_tree_ok=", ok)
	quit(0 if ok else 1)
