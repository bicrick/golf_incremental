extends SceneTree
## v9 screenshot harness.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/fortune_shot.gd
## Env: ROOM (tee|green|cards|dice), CASH, LEVELS (id:lv,...), ROOMS (all|ids),
##      SHOT_AT (comma secs), SWING_AT (comma secs; tee swings / room actions),
##      OPEN (title|ending|pause), OUT (dir), PERMANENT, BUFF (name:mult:sec)

var _main: Node
var _t := 0.0
var _swings: Array = []
var _shots: Array = []
var _out := "/tmp/claude-0/sp/shots"
var _i := 0
var _quit_at := 0.0
var _hold := -1.0


func _initialize() -> void:
	for s in _env("SWING_AT", "").split(",", false):
		_swings.append(float(s))
	for s in _env("SHOT_AT", "1").split(",", false):
		_shots.append(float(s))
	_out = _env("OUT", _out)
	DirAccess.make_dir_recursive_absolute(_out)
	_quit_at = _shots.max() + 0.3
	_main = load("res://scenes/fortune/fortune_main.tscn").instantiate()
	root.add_child(_main)
	call_deferred("_start")


func _start() -> void:
	var G := root.get_node("Game")
	G.saving_enabled = false
	G.reset()
	G.cash = float(_env("CASH", "0"))
	G.earned = maxf(G.cash, 1.0)
	G.permanent = float(_env("PERMANENT", "0"))
	for pair in _env("LEVELS", "").split(",", false):
		var kv := pair.split(":")
		G.levels[kv[0]] = int(kv[1])
	var rooms := _env("ROOMS", "")
	for r in FortuneData.ROOMS:
		if rooms == "all" or rooms.contains(r["id"]):
			G.rooms[r["id"]] = true
	for b in _env("BUFF", "").split(",", false):
		var p := b.split(":")
		G.add_buff(p[0], float(p[1]), float(p[2]))
	_main._on_upgrades()
	_main.tee._sync()
	if _env("OPEN", "") == "title":
		return
	_main.title.visible = false
	_main._on_play(false)
	_main.select_room(_env("ROOM", "tee"))
	match _env("OPEN", ""):
		"ending":
			_main.ending.show_card()
		"pause":
			_main.pause.open()


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return v if v != "" else d


func _process(delta: float) -> bool:
	_t += delta
	if not _swings.is_empty() and _t >= float(_swings[0]):
		_swings.pop_front()
		match String(_main.current):
			"tee":
				_main.tee.begin_swing()
				_hold = _t + 0.5
			"green":
				_main.green.player_drop(randf_range(120, 200))
			"cards":
				_main.cards.key_action()
			"dice":
				_main.dice.key_action()
	if _hold > 0.0 and _t >= _hold:
		_hold = -1.0
		_main.tee.release_swing()
	if not _shots.is_empty() and _t >= float(_shots[0]):
		_shots.pop_front()
		var img := root.get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [_out, _i])
		_i += 1
	return _t > _quit_at
