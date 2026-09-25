extends SceneTree
## v8 pacing sim — plays the real TourPhysics / Tour state with a modeled
## player and prints when each range clears and the story ends.
##   godot --headless --path . --script res://tools/sim_tour_pacing.gd
## Env: SKILL=casual|good|pro (good), SEED (7), QUIET=1

const SIGMA_MS := {"casual": 95.0, "good": 60.0, "pro": 34.0}
const SEC_PER_SWING := {"casual": 2.8, "good": 2.3, "pro": 1.9}
const SWEEP_BASE_SEC := 3.0
const SWEEP_SEC_PER_BALL := 0.45
const CLEAR_SEC := 25.0 ## note, map, arrival card
const SHOP_SEC_PER_BUY := 1.5

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _log: Array[String] = []
var T: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	T = root.get_node("Tour")
	var skill := OS.get_environment("SKILL")
	if skill == "":
		skill = "good"
	_rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7
	T.saving_enabled = false
	T.reset()
	var sigma: float = SIGMA_MS[skill]
	var swing_sec: float = SEC_PER_SWING[skill]
	var range_start := 0.0
	var buys := 0
	var guard := 0
	while not T.story_complete and _t < 3600.0 * 2 and guard < 100000:
		guard += 1
		var r: Dictionary = T.current_range()
		## --- a bucket ---
		var landed: Array = []
		var bucket_pay := 0.0
		while T.bucket_remaining > 0 and not T.story_complete:
			var aim := _choose_aim(r)
			var err := _rng.randfn(0.0, sigma)
			var tier := TourPhysics.tier_for_error(err, TourPhysics.window_scale(T.levels, T.keepsakes))
			var wind := Vector2.ZERO
			if r["mechanic"] == "wind":
				wind = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-0.10, 0.14))
				## Player leans into the wind: half as well without the reader.
				var know := 1.0 if T.level("wind") > 0 else 0.5
				aim.x -= wind.x * aim.y / 100.0 * know * 0.8
				aim.y /= 1.0 + wind.y * know
			var shot := TourPhysics.resolve_shot(aim, tier, signf(err), wind, r, T.levels, T.keepsakes, _rng)
			var verdict := TourPhysics.judge(shot, r, T.lit_count())
			T.use_ball()
			T.record_swing(tier, shot["carry"])
			_t += swing_sec
			if tier <= 1:
				T.streak += 1
			else:
				T.streak = 0
			var golden := _rng.randf() < TourPhysics.golden_chance(T.levels)
			var pay := TourPhysics.payout(shot, verdict, T.streak, golden, T.lit_count(), r, T.levels, T.keepsakes)
			if verdict["green"] != "":
				var g_id: String = verdict["green"]
				if T.star_green(g_id):
					pay += TourPhysics.first_green_bonus(shot["carry"], T.levels, T.keepsakes, r)
					_log_line("  star %s (%s)" % [g_id, TourData.TIER_NAMES[tier]])
				var g := _green(r, g_id)
				if g.get("ratina", false):
					if r["mechanic"] == "finale":
						if tier <= 1:
							_log_line("FINALE — the Longest Hole, total %s" % _clock(_t))
							T.complete_story()
							break
					else:
						_log_line("CLEAR %-16s %s  (took %s, swings %d, reach %.0f, buys %d, $%.0f) %s" % [r["name"], _clock(_t), _clock(_t - range_start), int(T.stats["swings"]), T.reach(), buys, T.money, str(T.levels)])
						T.clear_range(T.range_index)
						_t += CLEAR_SEC
						T.travel_to(T.range_index + 1)
						range_start = _t
						r = T.current_range()
						landed.clear()
						break
			T.add_money(pay)
			bucket_pay += pay
			if verdict["lost"] == "":
				landed.append(pay)
		if T.story_complete:
			break
		## --- sweep ---
		var n := landed.size()
		var cart: float = 1.0 + 0.2 * T.level("cart")
		_t += SWEEP_BASE_SEC + n * SWEEP_SEC_PER_BALL / cart
		if n > 0:
			var avg := bucket_pay / n
			var tip := 0.0
			for i in n:
				tip += avg * 0.05 * mini(i + 1, 6 + 2 * T.level("cart"))
			T.add_money(tip)
		T.flags["swept"] = true
		T.refill_bucket()
		## Keepsakes: spotted once the reach covers them.
		for k in r["keepsakes"]:
			if not T.keepsakes.get(k["id"], false) and T.reach() >= float(k["z"]) * 0.9:
				T.find_keepsake(k["id"])
				_log_line("  keepsake %s" % k["id"])
		## --- shop ---
		buys += _spend(r)
	_log_line("END %s swings=%d buys=%d levels=%s" % [_clock(_t), T.stats["swings"], buys, str(T.levels)])
	for l in _log:
		print(l)
	quit(0)


func _green(r: Dictionary, id: String) -> Dictionary:
	for g in r["greens"]:
		if g["id"] == id:
			return g
	return {}


func _choose_aim(r: Dictionary) -> Vector2:
	var reach: float = T.reach()
	var best := Vector2(0, reach)
	var best_val := 0.0
	var roll: float = float(r.get("roll", 0.0))
	for g in r["greens"]:
		if g.has("needs_lit") and T.lit_count() < int(g["needs_lit"]):
			continue
		var target := Vector2(float(g["x"]), float(g["z"]))
		## Aim short to let it roll on.
		var aim := TourPhysics.landing_for(target, g, r, T.levels, T.keepsakes)
		if aim.length() > reach:
			continue
		var val := float(g["z"]) * 3.0
		if not T.stars.get(g["id"], false):
			val *= 20.0
		if g.get("ratina", false):
			val *= 100.0
		if val > best_val:
			best_val = val
			best = aim
	if best_val < reach:
		best = TourPhysics.safe_drive(Vector2(0, reach), r, T.levels, T.keepsakes)
	return best


func _spend(r: Dictionary) -> int:
	var count := 0
	var flag := TourData.flag_green(r)
	var need_reach: bool = float(flag.get("z", 0.0)) > float(T.reach()) - 2.0
	for _i in 100:
		var best := ""
		var best_cost := INF
		for u in TourData.UPGRADES:
			var id: String = u["id"]
			if not T.upgrade_visible(id) or T.upgrade_maxed(id):
				continue
			var c: float = T.upgrade_cost(id)
			if id == "power" and need_reach:
				c *= 0.5
			if c < best_cost:
				best_cost = c
				best = id
		if best == "" or not T.buy(best):
			break
		count += 1
		_t += SHOP_SEC_PER_BUY
	return count


func _log_line(s: String) -> void:
	if OS.get_environment("QUIET") == "1" and not (s.begins_with("CLEAR") or s.begins_with("FINALE") or s.begins_with("END")):
		return
	_log.append("[%s] %s" % [_clock(_t), s])


func _clock(sec: float) -> String:
	return "%d:%02d" % [int(sec / 60.0), int(sec) % 60]
