extends SceneTree
## Dev playtest autoplayer — plays the real game through real input events:
## holds/releases Space on the contact frame, clicks balls and story finds in
## harvest, advances dialogue, and buys upgrades between buckets. Screenshots.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/playtest_autoplay.gd
##
## Env: DURATION (sec, 180), SHOT_DIR (user://playtest), SHOT_EVERY (sec, 20),
##      SKIP_TUTORIAL=1, CASH (start $), CARRY (seed max carry), SKILL (0..1 hit
##      accuracy, 0.8), FRESH=1 (wipe save first), BUY=1 (auto-buy, default on).

var _main: Node
var _range: Node
var _gs: Node
var _t := 0.0
var _duration := 180.0
var _shot_dir := "user://playtest"
var _shot_every := 20.0
var _next_shot := 3.0
var _shot_i := 0
var _skill := 0.8
var _buy := true

var _charging := false
var _charge_start_ms := 0
var _hold_target_ms := 500
var _next_action_t := 1.0
var _last_log := -999.0
var _found_before := 0


func _initialize() -> void:
	_duration = float(_env("DURATION", "180"))
	_shot_dir = _env("SHOT_DIR", "user://playtest")
	_shot_every = float(_env("SHOT_EVERY", "20"))
	_skill = float(_env("SKILL", "0.8"))
	_buy = _env("BUY", "1") == "1"
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	call_deferred("_boot")


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if not v.is_empty() else fallback


func _boot() -> void:
	_gs = root.get_node("GameState")
	if _env("FRESH", "0") == "1":
		_gs.reset_to_fresh()
	if _env("SKIP_TUTORIAL", "0") == "1":
		_gs.tutorial_completed = true
		_gs.tutorial_progress = 10
		_gs.tutorial_upgrade_menu_seen = true
	if _env("CASH", "") != "":
		_gs.currency = float(_env("CASH", "0"))
	if _env("CARRY", "") != "":
		_gs.lifetime["max_carry_yards"] = float(_env("CARRY", "0"))
	## FOUND=id,id — pre-claim finds (crew etc.) to start mid-story.
	for id in _env("FOUND", "").split(",", false):
		_gs.story_triggered[id.strip_edges()] = true
		_gs.discover_find(id.strip_edges())
	## LEVELS=id:n,id:n — pre-buy upgrades.
	for pair in _env("LEVELS", "").split(",", false):
		var kv := pair.split(":")
		if kv.size() == 2:
			_gs.upgrade_levels[kv[0]] = int(kv[1])
	_gs._recompute_stats()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main._on_play_transition_started()
	_main.get_node("TitleScreen").visible = false
	_main._on_play_pressed()
	_range = _main.get_node("RangeView")
	if _env("LOG_SWINGS", "0") == "1":
		root.get_node("EventBus").swing_resolved.connect(
			func(y: float, tier: int, _p: float, _f: int) -> void:
				_log("swing  %s %.1f yd (held %d ms)" % [Balance.TIER_NAMES[tier], y, Time.get_ticks_msec() - _charge_start_ms])
		)
	_found_before = _gs.story_found_count()
	_log("start  $%.0f carry %.0f" % [_gs.currency, _gs.max_carry_yards()])


func _process(delta: float) -> bool:
	if _range == null:
		return false
	_t += delta
	if _t >= _next_shot:
		_next_shot += _shot_every
		_screenshot()
	if _t >= _duration:
		_screenshot()
		_log("end    $%.0f carry %.0f finds %d swings %d" % [
			_gs.currency, _gs.max_carry_yards(), _gs.story_found_count(),
			int(_gs.lifetime.get("total_swings", 0))
		])
		quit()
		return false
	if _gs.story_found_count() != _found_before:
		_found_before = _gs.story_found_count()
		_log("FIND   %d/%d" % [_found_before, _gs.story_total_count()])
	if _t - _last_log > 30.0:
		_last_log = _t
		_log("tick   $%.0f carry %.0f bucket %d phase %s" % [
			_gs.currency, _gs.max_carry_yards(), _gs.bucket_remaining, _gs.current_phase
		])
	_step()
	return false


func _step() -> void:
	if _charging:
		if Time.get_ticks_msec() - _charge_start_ms >= _hold_target_ms:
			_key(KEY_SPACE, false)
			_charging = false
			_next_action_t = _t + 0.3
		return
	if _t < _next_action_t:
		return
	if _dialogue_open():
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)
		_next_action_t = _t + 0.5
		return
	var ending: Node = root.get_node_or_null("Main/StoryEndingLayer/StoryEnding")
	if ending != null and ending.is_running():
		var btn: Button = ending.get("_continue_button")
		if btn != null and btn.is_visible_in_tree():
			btn.pressed.emit()
		_next_action_t = _t + 1.0
		return
	if _gs.current_phase == "strike":
		if _gs.bucket_remaining > 0:
			_swing()
		else:
			if _buy:
				_spend()
			if not _gs.try_enter_harvest():
				_next_action_t = _t + 0.5
			else:
				_next_action_t = _t + 1.2
	elif _gs.current_phase == "harvest":
		_harvest_step()


func _dialogue_open() -> bool:
	for group in [&"tutorial_overlay", &"story_dialogue"]:
		var nodes := get_nodes_in_group(group)
		var n: Node = nodes[0] if not nodes.is_empty() else null
		if n != null and n.has_method("is_blocking_input") and n.is_blocking_input():
			return true
	return false


func _swing() -> void:
	## Aim: hold for the contact frame, with skill-scaled jitter.
	var ideal_ms := int(Balance.CONTACT_WINDUP_SEC * 1000.0)
	var jitter := int(randf_range(-1.0, 1.0) * (1.0 - _skill) * 160.0)
	_hold_target_ms = maxi(ideal_ms + jitter, 60)
	_key(KEY_SPACE, true)
	_charging = true
	_charge_start_ms = Time.get_ticks_msec()


func _harvest_step() -> void:
	if not _range.is_harvest_view_ready():
		_next_action_t = _t + 0.2
		return
	var cam: Camera3D = _range.get_flight_camera()
	## Story finds first (claimable or hint).
	var finds: Node = _range.get_story_finds()
	if finds != null:
		for id in StoryFinds.order():
			if _gs.is_find_found(id) or not _gs.is_find_revealed(id):
				continue
			if not _gs.is_find_claimable(id) and StoryFinds.get_def(id)["kind"] != "target":
				continue
			if _gs.is_find_claimable(id):
				var pos: Vector3 = finds.find_world_position(id)
				_center_camera(cam, pos)
				_click(cam.unproject_position(pos + Vector3(0, 0.4, 0)))
				_log("click  find %s" % id)
				_next_action_t = _t + 0.8
				return
	var litter_root: Node = _range.get("littered_balls")
	for child in litter_root.get_children():
		if child is Sprite3D and child.get_meta("collectible", false):
			var p: Vector3 = (child as Sprite3D).global_position
			_center_camera(cam, p)
			_click(cam.unproject_position(p))
			_next_action_t = _t + 0.25
			return
	## Nothing left to click — return leftovers.
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_next_action_t = _t + 1.0


func _center_camera(cam: Camera3D, world: Vector3) -> void:
	var screen := cam.unproject_position(world)
	var vp := root.get_visible_rect().size
	if Rect2(Vector2(40, 40), vp - Vector2(80, 80)).has_point(screen):
		return
	## Shift the ortho camera so the target sits mid-screen (dev cheat).
	var center_ray_hit: Variant = _ground_at(cam, vp * 0.5)
	if center_ray_hit == null:
		return
	var d: Vector3 = world - center_ray_hit
	cam.global_position += Vector3(d.x, 0.0, d.z)


func _ground_at(cam: Camera3D, screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var n := cam.project_ray_normal(screen)
	if absf(n.y) < 0.0001:
		return null
	var t := -o.y / n.y
	return o + n * t


func _spend() -> void:
	for _i in 60:
		var best := ""
		var best_cost := INF
		for id in UpgradeGraph.tree_order():
			var def := UpgradeGraph.get_def(id)
			if UpgradeGraph.level(id) >= int(def.get("max_level", 0)):
				continue
			if not UpgradeGraph.is_unlocked(id) or not UpgradeGraph.is_revealed(id):
				continue
			var c := UpgradeGraph.cost(id)
			if c < best_cost:
				best_cost = c
				best = id
		if best.is_empty() or _gs.currency < best_cost:
			return
		UpgradeGraph.purchase(best)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _click(viewport_pos: Vector2) -> void:
	## Injected events are in window space; the game renders at 480x270 stretched.
	var pos: Vector2 = root.get_final_transform() * viewport_pos
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)


func _screenshot() -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/shot_%03d.png" % [_shot_dir, _shot_i]
	img.save_png(path)
	_shot_i += 1


func _log(msg: String) -> void:
	print("[%6.1fs] %s" % [_t, msg])
