extends SceneTree
## v8 regression check: data sanity, shot math, save round-trip, and a
## scripted run through the real scene (swing, sweep, flag, travel, ending).
##   godot --headless --path . --script res://tools/verify_tour.gd

var _fails := 0
var _main: Node
var T: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		_fails += 1


func _run() -> void:
	T = root.get_node("Tour")
	T.saving_enabled = false
	T.reset()
	print("data")
	_data_checks()
	print("physics")
	_physics_checks()
	print("save")
	_save_checks()
	print("scene")
	await _scene_checks()
	print("%s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


func _data_checks() -> void:
	_check(TourData.range_count() == 5, "five ranges")
	var ids := {}
	for i in TourData.range_count():
		var r := TourData.get_range(i)
		var flag := TourData.flag_green(r)
		_check(not flag.is_empty(), "%s has Ratina's flag" % r["id"])
		_check(TourLooks.LOOKS.has(r["id"]), "%s has a look" % r["id"])
		_check(r["keepsakes"].size() == 2, "%s has two keepsakes" % r["id"])
		for g in r["greens"]:
			_check(not ids.has(g["id"]), "green id %s unique" % g["id"])
			ids[g["id"]] = true
			_check(float(g["z"]) <= float(flag["z"]), "%s not past the flag" % g["id"])
		for n in ["sky", "far", "near"]:
			var path := "res://assets/sprites/tour/backdrops/%s_%s.png" % [r["id"], n]
			if r["id"] == "edge" and n == "near":
				continue
			_check(ResourceLoader.exists(path), "backdrop %s" % path)
		for p in TourLooks.look(r["id"]).get("props", []):
			_check(ResourceLoader.exists("res://assets/sprites/tour/props/%s.png" % p[0]), "prop %s" % p[0])
		if i < 4:
			_check(TourStory.BEATS.has("flag_" + String(r["id"])), "flag beat for %s" % r["id"])
		if i > 0:
			_check(TourStory.BEATS.has("arrive_" + String(r["id"])), "arrival beat for %s" % r["id"])
	for u in TourData.UPGRADES:
		_check(ResourceLoader.exists("res://assets/sprites/tour/icons/%s.png" % u["icon"]), "icon for %s" % u["id"])
	for k in TourData.all_keepsakes():
		_check(ResourceLoader.exists("res://assets/sprites/tour/%s.png" % k["id"]), "keepsake art %s" % k["id"])


func _physics_checks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := TourData.get_range(0)
	var lv := {}
	_check(TourPhysics.tier_for_error(0.0, 1.0) == 0, "zero error is Perfect")
	_check(TourPhysics.tier_for_error(400.0, 1.0) == 5, "big error is a Miss")
	_check(TourPhysics.tier_for_error(-50.0, 1.0) == 1, "50 ms early is Great")
	var on := 0
	for i in 200:
		var s := TourPhysics.resolve_shot(Vector2(-5, 45), 0, 1.0, Vector2.ZERO, r, lv, {}, rng)
		if TourPhysics.judge(s, r, 0)["green"] == "b1":
			on += 1
	_check(on >= 190, "Perfects at the practice green land on it (%d/200)" % on)
	var late := TourPhysics.resolve_shot(Vector2(0, 100), 3, 1.0, Vector2.ZERO, r, lv, {}, rng)
	_check((late["land"] as Vector2).x > 2.0, "late release pushes right")
	var early := TourPhysics.resolve_shot(Vector2(0, 100), 3, -1.0, Vector2.ZERO, r, lv, {}, rng)
	_check((early["land"] as Vector2).x < -2.0, "early release pulls left")
	var cliffs := TourData.get_range(1)
	var wet := TourPhysics.judge({"land": Vector2(0, 194), "rest": Vector2(0, 194)}, cliffs, 0)
	_check(wet["lost"] == "water", "short of the island is wet")
	var island := TourPhysics.judge({"land": Vector2(0, 212), "rest": Vector2(0, 212)}, cliffs, 0)
	_check(island["lost"] == "" and island["green"] == "c_flag", "the island green is dry")
	var frost := TourData.get_range(3)
	_check(TourPhysics.judge({"land": Vector2(1, 400), "rest": Vector2(1, 400)}, frost, 3)["green"] == "", "Frostpine flag hidden until 4 lit")
	_check(TourPhysics.judge({"land": Vector2(1, 400), "rest": Vector2(1, 400)}, frost, 4)["green"] == "f_flag", "Frostpine flag shows at 4 lit")
	_check(TourPhysics.reach({"power": 10}, {}, {}) > TourPhysics.reach({}, {}, {}), "Club Speed adds reach")


func _save_checks() -> void:
	T.reset()
	T.money = 123.0
	T.levels = {"power": 3}
	T.stars = {"b1": true}
	T.range_index = 1
	T.unlocked_range = 1
	var d: Dictionary = JSON.parse_string(JSON.stringify(T.to_dict()))
	T.reset()
	T.from_dict(d)
	_check(is_equal_approx(T.money, 123.0) and T.level("power") == 3 and T.stars.has("b1") and T.range_index == 1, "save round-trips")
	T.reset()


func _scene_checks() -> void:
	_main = load("res://scenes/tour/tour_main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	for b in TourStory.BEATS.keys():
		T.seen[b] = true
	_main.title.visible = false
	_main._on_play(false)
	await process_frame
	var w: Node = _main.world
	_check(w.range_def["id"] == "barley", "starts at Barley's Range")
	## Swing: hold for exactly the windup.
	var before: int = T.bucket_remaining
	w.begin_swing()
	w.charge_t = TourData.WINDUP_SEC
	w.release_swing()
	_check(T.bucket_remaining == before - 1, "a swing uses a ball")
	_check(w.last_tier == 0, "perfect timing is a Perfect")
	await _wait(4.0)
	_check(T.money > 0.0, "the ball paid on landing ($%.2f)" % T.money)
	## Empty the bucket and sweep.
	T.bucket_remaining = 0
	w.begin_sweep()
	await _wait(1.0)
	_check(w.mode == 1, "sweep starts")
	w.finish_sweep()
	await _wait(1.0)
	_check(T.bucket_remaining == T.bucket_size(), "sweep refills the bucket")
	## Buy.
	T.money = 1000.0
	var reach: float = T.reach()
	_check(T.buy("power") and T.reach() > reach, "buying Club Speed adds reach")
	## Reach the flag: force a perfect shot at Ratina's flag.
	T.levels["power"] = 12
	w._refresh_aim_options()
	for i in w.aim_options.size():
		if w.aim_options[i]["id"] == "b_flag":
			w.select_aim(i)
	T.bucket_remaining = 5
	w.cooldown = 0.0
	w.begin_swing()
	w.charge_t = TourData.WINDUP_SEC
	w.release_swing()
	for _i in 60:
		await _wait(0.5)
		if _main.dialogue.is_blocking():
			_main.dialogue.advance()
		if _main.map.is_blocking():
			break
	_check(T.cleared.get("barley", false), "landing on Ratina's flag clears the range")
	_check(T.rewards.get("spoon", false), "the spoon is the reward")
	for _i in 20:
		await _wait(0.4)
		if _main.map._button.visible:
			_main.map._on_button()
			break
	await _wait(1.0)
	_check(T.range_index == 1 and w.range_def["id"] == "cliffs", "the map travels on to Saltwind Cliffs")
	## Jump to the Edge and play the finale.
	T.unlocked_range = 4
	T.travel_to(4)
	_main.start_range(4)
	T.levels["power"] = 40
	w._refresh_aim_options()
	for i in w.aim_options.size():
		if w.aim_options[i]["id"] == "e_flag":
			w.select_aim(i)
	T.bucket_remaining = 5
	w.cooldown = 0.0
	w.begin_swing()
	w.charge_t = TourData.WINDUP_SEC
	w.release_swing()
	_check(w.flying.size() == 1, "the last ball is in the air")
	for _i in 80:
		await _wait(0.5)
		if _main.dialogue.is_blocking():
			_main.dialogue.advance()
		if _main.ending._button.visible:
			break
	_check(T.story_complete, "the Longest Hole ends the story")
	_check(_main.ending._button.visible, "the scorecard shows")
	_main.ending._on_keep()
	await _wait(2.5)
	_check(not _main.ending.is_blocking(), "Keep swinging returns to play")


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
