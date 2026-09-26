extends SceneTree
## v9 checks: data, economy sanity, save round-trip, and a short scripted run
## through the real scene that exercises every room.
##   godot --headless --path . --script res://tools/verify_fortune.gd

var _fails := 0
var _main: Node
var _t := 0.0
var _phase := 0
var _earned_at := {}


func _initialize() -> void:
	_check_data()
	_check_econ()
	_main = load("res://scenes/fortune/fortune_main.tscn").instantiate()
	root.add_child(_main)
	call_deferred("_start")


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + what)


func _check_data() -> void:
	var ids := {}
	for r in FortuneData.ROOMS:
		ids[r["id"]] = true
	var seen := {}
	for u in FortuneData.UPGRADES:
		var id: String = u["id"]
		_ok(not seen.has(id), "duplicate upgrade " + id)
		seen[id] = true
		_ok(ids.has(u["room"]), id + " has unknown room")
		_ok(ResourceLoader.exists("res://assets/sprites/tour/icons/%s.png" % u["icon"]), id + " icon missing")
		_ok(float(u["base"]) > 0.0 and float(u["growth"]) >= 1.0 and int(u["max"]) >= 1, id + " bad cost/max")
		if u.has("needs"):
			_ok(not FortuneData.upgrade(u["needs"]).is_empty(), id + " needs unknown upgrade")
	for v in FortuneData.RENOVATIONS:
		_ok(not TourLooks.look(v).is_empty(), "renovation venue has no look: " + v)


func _check_econ() -> void:
	var odds := FortuneEcon.card_odds({"card_luck": 8})
	var sum := 0.0
	for o in odds:
		sum += o
		_ok(o >= 0.0, "negative card odds")
	_ok(absf(sum - 1.0) < 0.001, "card odds sum to %f" % sum)
	_ok(FortuneEcon.ring_for(0.0, {}) == 3, "centre should be the PIN")
	_ok(FortuneEcon.ring_for(999.0, {}) == -1, "far away should miss")
	_ok(FortuneEcon.tier_for_error(0.0, 1.0) == 0 and FortuneEcon.tier_for_error(900.0, 1.0) == 5, "tier windows")
	_ok(FortuneEcon.tee_cooldown({"tee_speed": 99}) >= 0.14, "cooldown floor")


func _start() -> void:
	var G := root.get_node("Game")
	G.saving_enabled = false
	G.reset()
	## Save round-trip.
	G.cash = 1234.5
	G.levels = {"tee_value": 3, "putt_auto": 2}
	G.rooms = {"tee": true, "green": true}
	G.permanent = 0.07
	var d: Dictionary = JSON.parse_string(JSON.stringify(G.to_dict()))
	G.reset()
	G.from_dict(d)
	_ok(is_equal_approx(G.cash, 1234.5) and G.level("tee_value") == 3 and G.rooms.get("green", false) and is_equal_approx(G.permanent, 0.07), "save round-trip")
	_ok(not G.can_buy("card_value"), "locked room's upgrade must not be buyable")
	_ok(not G.available("tee_cousins"), "cousins need Ratina first")
	## Scripted run: every room unlocked, a little money, play each.
	G.reset()
	G.cash = 1e6 - 1.0
	for r in FortuneData.ROOMS:
		G.rooms[r["id"]] = true
	G.levels = {"putt_auto": 3, "card_auto": 3, "dice_auto": 2, "tee_ratina": 2, "tee_cousins": 1}
	_main.title.visible = false
	_main._on_play(false)
	G.upgrades_changed.emit()


func _process(delta: float) -> bool:
	_t += delta
	var G := root.get_node("Game")
	if _main == null or not _main.in_session:
		return false
	match _phase:
		0:
			_main.select_room("tee")
			_main.tee.begin_swing()
			_phase = 1
		1:
			if _t > 0.5 and _main.tee.charging:
				_main.tee.release_swing()
			if _t > 3.0:
				_ok(int(G.stats["swings"]) >= 1, "a swing registered")
				_earned_at["tee"] = G.earned
				_main.select_room("green")
				_main.green.player_drop(160.0)
				_phase = 2
		2:
			if _t > 6.0:
				_ok(int(G.stats["putts"]) >= 1, "a putt dropped")
				_main.select_room("cards")
				_main.cards.key_action()
				_phase = 3
		3:
			_main.cards.key_action()
			if _t > 8.0:
				_ok(int(G.stats["cards"]) >= 1, "a card was bought")
				_main.select_room("dice")
				_main.dice.key_action()
				_phase = 4
		4:
			if _t > 10.0:
				_ok(G.earned > float(_earned_at["tee"]), "rooms keep earning")
				_ok(G.cash >= FortuneData.GOAL, "reached the goal")
				_main._buy_range()
				_ok(G.has_won, "bought the range")
				_phase = 5
		5:
			if _t > 12.5:
				_ok(_main.ending.visible, "ending card shows")
				print("scripted run reached the end")
				print("verify_fortune: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
				return true
	if _t > 30.0:
		_ok(false, "scripted run timed out in phase %d" % _phase)
		print("verify_fortune: %d FAILED" % _fails)
		return true
	return false
