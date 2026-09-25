extends SceneTree
## v5 pacing sim — plays the real economy / upgrade graph / story with a modeled
## player and prints when each find and the ending land. Run:
##   godot --headless --path . --script res://tools/sim_story_pacing.gd
## Env: SKILL=casual|good|pro (default good), MAX_MIN (default 600), BUY=cheap|smart

const HARVEST_SEC_PER_BALL := 0.8
const HARVEST_OVERHEAD_SEC := 4.0
const SWING_MIN_SEC := 1.1
const TARGET_FIND_DELAY_BUCKETS := 4
const COMBO_TIER_TYPICAL := 3

## Tier mix [Perfect, Great, Good, Okay, Bad, Miss] and contact quality per tier.
const SKILLS := {
	"casual": [0.10, 0.25, 0.30, 0.20, 0.10, 0.05],
	"good": [0.30, 0.35, 0.20, 0.10, 0.04, 0.01],
	"pro": [0.60, 0.30, 0.08, 0.02, 0.0, 0.0],
}
const TIER_QUALITY := [1.0, 0.86, 0.70, 0.52, 0.34, 0.12]
const MARK_HIT_PER_BUCKET := {"casual": 0.15, "good": 0.3, "pro": 0.5}

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _events: Array = []
var _target_wait: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _gs() -> Node:
	return root.get_node("GameState")


func _run() -> void:
	_rng.seed = 7
	var skill_name := OS.get_environment("SKILL")
	if skill_name.is_empty():
		skill_name = "good"
	var mix: Array = SKILLS.get(skill_name, SKILLS["good"])
	var max_min := float(OS.get_environment("MAX_MIN")) if OS.get_environment("MAX_MIN") != "" else 600.0
	var smart := OS.get_environment("BUY") == "smart"
	var gs := _gs()
	gs.reset_to_fresh()
	gs.tutorial_completed = true
	var buckets := 0
	var buys := 0
	var last_report := 0.0
	while _t < max_min * 60.0 and not gs.story_complete:
		# --- strike a bucket ---
		var n: int = gs.bucket_capacity
		var cooldown := maxf(gs.stats.swing_cooldown_ms / 1000.0, SWING_MIN_SEC)
		var earned := 0.0
		for i in n:
			var tier := _roll_tier(mix)
			var q: float = TIER_QUALITY[tier]
			var yards: float = Economy.yards_from_quality(q, gs.stats)
			if gs.story_finale_armed:
				yards = maxf(yards, 380.0)
				gs.story_finale_armed = false
				_log("LAST BALL")
				gs.complete_story()
				break
			gs.record_carry(yards)
			var pay := Economy.resolve_pickup_ball_payout(6 - tier, yards, COMBO_TIER_TYPICAL, gs.stats)
			if _rng.randf() < gs.stats.golden_ball_chance:
				pay *= gs.stats.golden_ball_payout_multiplier
			earned += pay
			_check_targets(gs, yards)
		_t += n * cooldown
		# --- Ratina's flag: a standing distance challenge (skill-dependent) ---
		if gs.ratina_unlocked and _rng.randf() < float(MARK_HIT_PER_BUCKET.get(skill_name, 0.3)):
			var mark_pay := Economy.resolve_pickup_ball_payout(5, gs.max_carry_yards() * 0.7, COMBO_TIER_TYPICAL, gs.stats)
			earned += mark_pay * maxf(gs.ratina_stats.ratina_mark_bonus - 1.0, 0.0)
		# --- harvest ---
		var picking := n
		if gs.rattlings_unlocked:
			picking = maxi(n - int(gs.rattling_stats.rattling_count), 1)
		_t += HARVEST_OVERHEAD_SEC + picking * HARVEST_SEC_PER_BALL
		gs.add_currency(earned)
		buckets += 1
		# --- story: claim whatever the mist gave back ---
		for id in StoryFinds.order():
			if gs.is_find_found(id):
				continue
			var def := StoryFinds.get_def(id)
			if String(def["kind"]) == "target" and gs.is_find_revealed(id) and not gs.is_find_triggered(id):
				_target_wait[id] = int(_target_wait.get(id, 0)) + 1
				if int(_target_wait[id]) >= TARGET_FIND_DELAY_BUCKETS:
					gs.trigger_find(id)
			if gs.is_find_claimable(id):
				gs.discover_find(id)
				_log("FIND %-17s @%3d yd  carry %.0f" % [id, int(def["yards"]), gs.max_carry_yards()])
		# --- spend ---
		buys += _spend(gs, smart)
		if _t - last_report >= float(OS.get_environment("REPORT_SEC") if OS.get_environment("REPORT_SEC") != "" else "600"):
			last_report = _t
			var per_ball := Economy.resolve_pickup_ball_payout(6, gs.max_carry_yards(), COMBO_TIER_TYPICAL, gs.stats)
			_log("   base %.3f ppy %.3f pick %.2f combo %.2f yd %.0f gold %.2f cool %.0f" % [gs.stats.base_amount, gs.stats.pay_per_yard, gs.stats.pickup_multiplier, Economy.combo_multiplier(COMBO_TIER_TYPICAL, gs.stats), gs.max_carry_yards(), gs.stats.golden_ball_chance, gs.stats.swing_cooldown_ms])
			_log("… $%.0f  carry %.0f  buys %d  bucket %d  $/ball@best %.1f  base_yd %.0f pop %.2f  lv %s" % [gs.currency, gs.max_carry_yards(), buys, gs.bucket_capacity, per_ball, gs.stats.base_yards, gs.stats.perfect_power_bonus, str(gs.upgrade_levels)])
	_log("END story_complete=%s buckets=%d buys=%d" % [gs.story_complete, buckets, buys])
	for e in _events:
		print(e)
	quit(0)


func _roll_tier(mix: Array) -> int:
	var r := _rng.randf()
	var acc := 0.0
	for i in mix.size():
		acc += float(mix[i])
		if r <= acc:
			return i
	return mix.size() - 1


func _check_targets(gs: Node, yards: float) -> void:
	## Landing scatter ±3 yd: a ball whose carry falls within radius of a target counts.
	for id in ["range_bell", "birdhouse"]:
		if gs.is_find_found(id) or gs.is_find_triggered(id):
			continue
		var def := StoryFinds.get_def(id)
		if absf(yards - float(def["yards"])) <= float(def["radius"]) * 0.6:
			gs.trigger_find(id)


func _spend(gs: Node, smart: bool) -> int:
	var count := 0
	for _guard in 200:
		var best_id := ""
		var best_cost := INF
		for id in UpgradeGraph.tree_order():
			var def := UpgradeGraph.get_def(id)
			if UpgradeGraph.level(id) >= int(def.get("max_level", 0)):
				continue
			if not UpgradeGraph.is_unlocked(id) or not UpgradeGraph.is_revealed(id):
				continue
			var c := UpgradeGraph.cost(id)
			if smart and int(def.get("branch", 0)) == Balance.UpgradeBranch.POWER:
				c *= 0.6
			if c < best_cost:
				best_cost = c
				best_id = id
		if best_id.is_empty() or gs.currency < UpgradeGraph.cost(best_id):
			break
		if not UpgradeGraph.purchase(best_id):
			break
		count += 1
	return count


func _log(msg: String) -> void:
	var m := int(_t / 60.0)
	_events.append("[%3d:%02d] %s" % [m, int(_t) % 60, msg])
