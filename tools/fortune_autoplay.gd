extends SceneTree
## v9 autoplayer: plays Fortune Range through the real scene — swings with a
## skill-based timing error, drops putts, scratches cards, rolls dice, hops
## rooms, buys the cheapest thing it can, and buys the range at $1M.
##   godot --headless --path . --script res://tools/fortune_autoplay.gd
## Env: SKILL (ms sigma, 60), SPEED (time scale, 20), MAX_MIN (45),
##      DWELL (sec per room visit, 25), LOG_EVERY (game sec, 60)

var _main: Node
var _t := 0.0
var _sigma := 70.0
var _max_sec := 2700.0
var _dwell := 25.0
var _log_every := 60.0
var _next_log := 0.0
var _next_buy := 0.0
var _next_act := 0.0
var _room_until := 0.0
var _room_i := 0
var _rng := RandomNumberGenerator.new()
var _milestones := {}
var _buys := 0
var _release_at := -1.0
var _by_room := {}


func _initialize() -> void:
	_rng.seed = int(_env("SEED", "11"))
	_sigma = float(_env("SKILL", "70"))
	Engine.time_scale = float(_env("SPEED", "20"))
	_max_sec = float(_env("MAX_MIN", "45")) * 60.0
	_dwell = float(_env("DWELL", "25"))
	_log_every = float(_env("LOG_EVERY", "60"))
	_main = load("res://scenes/fortune/fortune_main.tscn").instantiate()
	root.add_child(_main)
	call_deferred("_start")


func _start() -> void:
	var G := root.get_node("Game")
	G.saving_enabled = false
	G.reset()
	_main.title.visible = false
	_main._on_play(false)
	G.room_unlocked.connect(func(id: String) -> void: _log("UNLOCK %s" % id))
	G.room_earned.connect(func(id: String, amt: float) -> void: _by_room[id] = float(_by_room.get(id, 0.0)) + amt)
	G.big_moment.connect(func(_k: String, text: String) -> void: _log("  moment: " + text))
	_main.dice.rolled.connect(func(kind: String) -> void:
		if kind != "plain":
			_log("  dice: " + kind))


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return v if v != "" else d


func _log(s: String) -> void:
	var G := root.get_node("Game")
	print("[%5.1f min] $%-10s %s" % [G.play_time / 60.0, TourFormat.money(G.cash), s])


func _process(delta: float) -> bool:
	var G := root.get_node("Game")
	if _main == null or not _main.in_session:
		return false
	_t = G.play_time
	_play()
	if _t >= _next_buy:
		_next_buy = _t + 0.5
		_shop()
	for m in [1000.0, 10000.0, 100000.0, 250000.0, 500000.0]:
		if G.earned >= m and not _milestones.has(m):
			_milestones[m] = true
			_log("MILESTONE earned $%s" % TourFormat.money(m))
	if _t >= _next_log:
		_next_log = _t + _log_every
		_log("rate $%s/s  mult x%.2f  perm +%d%%  buys %d  room %s  lv %s" % [TourFormat.money(_main.topbar._rate),
			G.global_mult(), int(G.permanent * 100.0), _buys, _main.current, _levels_brief()])
		_log("  by room " + _room_brief())
	if G.cash >= FortuneData.GOAL and not G.has_won:
		_main._buy_range()
		_log("  by room " + _room_brief())
		_log("BOUGHT THE RANGE at %.1f min  stats %s" % [_t / 60.0, str(G.stats)])
		return true
	if _t > _max_sec:
		_log("TIMEOUT")
		return true
	return false


func _room_brief() -> String:
	var parts: Array[String] = []
	for k in _by_room:
		parts.append("%s $%s" % [k, TourFormat.money(_by_room[k])])
	return "  ".join(parts)


func _levels_brief() -> String:
	var G := root.get_node("Game")
	var parts: Array[String] = []
	for u in FortuneData.UPGRADES:
		var l: int = G.level(u["id"])
		if l > 0:
			parts.append("%s%d" % [String(u["id"]).split("_")[1].left(4), l])
	return " ".join(parts)


## Room hopping: stay a while, then move to the next open room.
func _play() -> void:
	var G := root.get_node("Game")
	var open: Array[String] = []
	for r in FortuneData.ROOMS:
		if G.rooms.get(r["id"], false):
			open.append(r["id"])
	if _t >= _room_until:
		_room_i = (_room_i + 1) % open.size()
		_main.select_room(open[_room_i])
		_room_until = _t + (_dwell * 1.6 if open[_room_i] == "tee" else _dwell)
	if _t < _next_act:
		return
	match String(_main.current):
		"tee":
			var tee: Node = _main.tee
			## Hold through the windup like a person, then let go with some error.
			if tee.charging and _t >= _release_at:
				tee.charge_t = FortuneEcon.WINDUP_SEC + _rng.randfn(0.0, _sigma) / 1000.0
				tee.release_swing()
				_next_act = _t + _rng.randf_range(0.15, 0.35) ## reaction before the next
			elif tee.can_swing():
				tee.begin_swing()
				_release_at = _t + FortuneEcon.WINDUP_SEC
		"green":
			var g: Node = _main.green
			g.player_drop(_rng.randf_range(60.0, 262.0))
			_next_act = _t + 0.3
		"cards":
			_main.cards.key_action()
			_next_act = _t + 0.28
		"dice":
			_main.dice.key_action()
			_next_act = _t + 0.25


## Unlock rooms first; otherwise buy the cheapest affordable upgrade.
func _shop() -> void:
	var G := root.get_node("Game")
	for r in FortuneData.ROOMS:
		if not G.rooms.get(r["id"], false) and G.cash >= float(r["unlock"]):
			G.unlock_room(r["id"])
			return
	## Near the goal, save instead of spending.
	var rate: float = maxf(_main.topbar._rate, 1.0)
	if (FortuneData.GOAL - G.cash) / rate < 150.0:
		return
	var best := ""
	var best_cost := INF
	for u in FortuneData.UPGRADES:
		var id: String = u["id"]
		if G.can_buy(id) and G.cost(id) < best_cost:
			best = id
			best_cost = G.cost(id)
	if best != "":
		G.buy(best)
		_buys += 1
