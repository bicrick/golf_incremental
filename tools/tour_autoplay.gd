extends SceneTree
## v8 autoplayer: plays the whole game through the real scene — aims, swings
## with skill-based timing error, sweeps, shops, reads dialogue, travels.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/tour_autoplay.gd
## Env: SKILL (ms sigma, 55), SPEED (time scale, 4), MAX_MIN (40), SHOT_DIR,
##      SHOT_EVERY (game sec, 0 = off), RANGE, CASH, POWER

var _main: Node
var _world: Node
var _t := 0.0
var _sigma := 55.0
var _next := 0.0
var _hold_until := -1.0
var _shot_dir := ""
var _shot_every := 0.0
var _next_shot := 5.0
var _shot_i := 0
var _last_log := 0.0
var _max_sec := 2400.0
var _range_start := 0.0
var _last_range := -1
var _rng := RandomNumberGenerator.new()
var _pending_err := 0.0


func _initialize() -> void:
	_rng.seed = 11
	_sigma = float(_env("SKILL", "55"))
	Engine.time_scale = float(_env("SPEED", "4"))
	_max_sec = float(_env("MAX_MIN", "40")) * 60.0
	_shot_dir = _env("SHOT_DIR", "")
	_shot_every = float(_env("SHOT_EVERY", "0"))
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	_main = load("res://scenes/tour/tour_main.tscn").instantiate()
	root.add_child(_main)
	call_deferred("_start")


func _start() -> void:
	var T := root.get_node("Tour")
	T.saving_enabled = false
	T.reset()
	T.range_index = int(_env("RANGE", "0"))
	T.unlocked_range = T.range_index
	T.money = float(_env("CASH", "0"))
	T.levels["power"] = int(_env("POWER", "0"))
	_main.start_range(T.range_index)
	_main.title.visible = false
	_main._on_play(false)
	_world = _main.world
	if _env("LOG_BALLS", "0") == "1":
		_world.ball_came_to_rest.connect(func(r: Dictionary) -> void:
			_log("ball tier %d lost '%s' green '%s' pay %.2f carry %.0f" % [int(r.get("tier", -1)), r.get("lost", ""), r.get("green", ""), float(r.get("pay", 0.0)), float(r.get("carry", 0.0))]))
		_world.sweep_finished.connect(func(c: int, bonus: float) -> void: _log("sweep %d bonus %.2f" % [c, bonus]))


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return v if v != "" else d


func _log(s: String) -> void:
	print("[%s] %s" % [_clock(_t), s])


func _clock(sec: float) -> String:
	return "%d:%02d" % [int(sec / 60.0), int(sec) % 60]


func _process(delta: float) -> bool:
	if _world == null:
		return false
	_t += delta
	var T := root.get_node("Tour")
	if T.range_index != _last_range:
		if _last_range >= 0:
			_log("ARRIVE %s (prev range took %s)" % [T.current_range()["name"], _clock(_t - _range_start)])
		_last_range = T.range_index
		_range_start = _t
	if _shot_every > 0.0 and _t >= _next_shot and _shot_dir != "":
		_next_shot += _shot_every
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/a%03d.png" % [_shot_dir, _shot_i])
		_shot_i += 1
	if _t - _last_log > 60.0:
		_last_log = _t
		_log("dbg dlg=%s map=%s mode=%s input=%s blocked=%s title=%s" % [_main.dialogue.visible, _main.map.visible, _world.mode, _world.input_enabled, _main._blocked(), _main.title.visible])
		_log("tick $%s reach %.0f stars %d swings %d levels %s" % [TourFormat.money(T.money), T.reach(), T.total_stars(), int(T.stats["swings"]), str(T.levels)])
	if T.story_complete and not _main.ending.is_blocking() and not _main.dialogue.is_blocking():
		_log("END story complete at %s  swings %d  stars %d  keepsakes %d" % [_clock(_t), int(T.stats["swings"]), T.total_stars(), T.keepsakes.size()])
		_log("range swings %s" % str(T.range_swings))
		quit()
		return false
	if _t > _max_sec:
		_log("TIMEOUT range %d reach %.0f" % [T.range_index, T.reach()])
		quit()
		return false
	_step(T)
	return false


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _step(T: Node) -> void:
	if _hold_until > 0.0:
		if _t >= _hold_until:
			_hold_until = -1.0
			## Release with exactly the modelled human error, independent of
			## frame rate (software rendering at high time scale is choppy).
			_world.charge_t = TourData.WINDUP_SEC + _pending_err / 1000.0
			_world.release_swing()
			_next = _t + float(_env("THINK", "1.0"))
		return
	if _t < _next:
		return
	if _main.ending.is_blocking():
		var b: Button = _main.ending._button
		if b.visible:
			b.pressed.emit()
		_next = _t + 1.0
		return
	if _main.dialogue.is_blocking():
		_main.dialogue.advance()
		_next = _t + 0.35
		return
	if _main.map.is_blocking():
		if _main.map._button.visible:
			_main.map._on_button()
		_next = _t + 0.5
		return
	match _world.mode:
		0:
			_play(T)
		1:
			_sweep()


func _play(T: Node) -> void:
	_spend(T)
	if not _world.can_swing():
		return
	## Aim: default picks the farthest unstarred reachable green; otherwise drive
	## when the flag is still out of reach and greens are all starred.
	_world.aim_index = _world._default_aim()
	var err := _rng.randfn(0.0, _sigma)
	_pending_err = err
	_world.begin_swing()
	_hold_until = _t + TourData.WINDUP_SEC + err / 1000.0
	_next = _t + 0.1


## The Big Picker drives itself; a real player sometimes skips it.
func _sweep() -> void:
	if _rng.randf() < 0.01:
		_world.finish_sweep()


func _spend(T: Node) -> void:
	for _i in 30:
		var best := ""
		var best_cost := INF
		var flag := TourData.flag_green(T.current_range())
		var need: bool = float(flag.get("z", 0.0)) > float(T.reach()) - 2.0
		for u in TourData.UPGRADES:
			var id: String = u["id"]
			if not T.upgrade_visible(id) or T.upgrade_maxed(id):
				continue
			var c: float = T.upgrade_cost(id)
			if id == "power" and need:
				c *= 0.5
			if c < best_cost:
				best_cost = c
				best = id
		if best == "" or not T.buy(best):
			return
