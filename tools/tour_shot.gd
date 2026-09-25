extends SceneTree
## Quick v8 screenshot harness.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/tour_shot.gd
## Env: RANGE (0), OUT (dir), POWER (upgrade level), SWING_AT (comma secs),
##      SHOT_AT (comma secs), SWEEP_AT (sec), STARS (comma ids)

var _main: Node
var _t := 0.0
var _swings: Array = []
var _shots: Array = []
var _out := "/tmp/claude-0/sp/shots"
var _i := 0
var _sweep_at := -1.0
var _quit_at := 0.0
var _hold := -1.0


func _initialize() -> void:
	for s in _env("SWING_AT", "").split(",", false):
		_swings.append(float(s))
	for s in _env("SHOT_AT", "1").split(",", false):
		_shots.append(float(s))
	_sweep_at = float(_env("SWEEP_AT", "-1"))
	_out = _env("OUT", _out)
	DirAccess.make_dir_recursive_absolute(_out)
	_quit_at = _shots.max() + 0.3
	_main = load("res://scenes/tour/tour_main.tscn").instantiate()
	root.add_child(_main)
	if _env("TITLE", "0") != "1":
		call_deferred("_start")


func _start() -> void:
	var T := root.get_node("Tour")
	T.saving_enabled = false
	T.reset()
	T.range_index = int(_env("RANGE", "0"))
	T.unlocked_range = T.range_index
	T.levels["power"] = int(_env("POWER", "0"))
	for id in _env("STARS", "").split(",", false):
		T.stars[id] = true
	if _env("DIALOGUE", "0") != "1":
		for b in TourStory.BEATS.keys():
			T.seen[b] = true
			T.seen["arrive_" + b] = true
	T.money = float(_env("CASH", "0"))
	for pair in _env("LEVELS", "").split(",", false):
		var kv := pair.split(":")
		T.levels[kv[0]] = int(kv[1])
	_main.start_range(T.range_index)
	if _env("OPEN", "") == "title":
		return
	_main.title.visible = false
	_main._on_play(false)
	match _env("OPEN", ""):
		"shop":
			_main.shop.toggle()
		"map":
			_main.map.travel(T.range_index, mini(T.range_index + 1, 4))
		"journal":
			_main.journal.open()
		"ending":
			_main.ending.sunrise(0.5)
			_main.ending.show_card()
		"dialogue":
			_main.dialogue.play(_env("BEAT", "intro"))
		"pause":
			_main.pause.open()


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return v if v != "" else d


func _process(delta: float) -> bool:
	_t += delta
	var world: Node = _main.get("world")
	if world == null:
		return false
	if not _swings.is_empty() and _t >= float(_swings[0]):
		_swings.pop_front()
		world.begin_swing()
		_hold = _t + 0.5 + randf_range(-0.02, 0.02)
	if _hold > 0 and _t >= _hold:
		_hold = -1
		world.release_swing()
	if _sweep_at > 0 and _t >= _sweep_at:
		_sweep_at = -1
		world.begin_sweep()
	if not _shots.is_empty() and _t >= float(_shots[0]):
		_debug()
		_shots.pop_front()
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/s%02d.png" % [_out, _i])
		_i += 1
	if _t >= _quit_at:
		quit()
	return false


func _debug() -> void:
	var m = _main
	print("DBG in_session=", m._in_session, " blocked=", m._blocked(), " input=", m.world.input_enabled, " mode=", m.world.mode,
		" dlg=", m.dialogue.visible, " map=", m.map.visible, " end=", m.ending.is_blocking(), " pause=", m.pause.visible, " j=", m.journal.visible, " title=", m.title.visible)
