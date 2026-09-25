class_name StoryFinds
extends RefCounted
## v5 story finds — objects hidden in the harvest mist. See docs/v5/02-finds.md.
##
## kind:
##   "find"   — click once revealed.
##   "target" — a ball must land within `radius` yards first, then click.
##   "finale" — the first green; arms the last ball.

const SPRITE_DIR := "res://assets/sprites/story/"

## Finds this far past the fog line draw as pale silhouettes inside the bank.
const SILHOUETTE_YARDS := 36.0
## A find is "revealed" once the fog line is at least this far past it.
const REVEAL_MARGIN_YARDS := 2.0

enum Act { RANGE = 1, MIST = 2, COURSE = 3, FINALE = 4 }

static var _by_id: Dictionary = {}
static var _order: Array[String] = []


static func _init_defs() -> void:
	if not _order.is_empty():
		return
	var defs: Array[Dictionary] = [
		_def("scorecard_1", "Torn Scorecard", Act.RANGE, 30.0, 1.5, "find",
			"scorecard", {"note": "note_1"}, {"persist": false}),
		_def("ratina_bag", "Someone's Golf Bag", Act.RANGE, 54.0, -6.0, "find",
			"ratina_bag", {"unlock_ratina": true}, {"persist": false}),
		_def("range_bell", "Range Bell", Act.RANGE, 74.0, 2.0, "target",
			"range_bell", {"swing_cooldown_mult": 0.85},
			{"radius": 7.0, "sprite_found": "range_bell_rung"}),
		_def("picker_cart", "Buried Picker Cart", Act.MIST, 105.0, -8.0, "find",
			"picker_cart", {"bucket_bonus": 2.0}, {}),
		_def("rattling_burrow", "Burrow at the Edge", Act.MIST, 146.0, 11.0, "find",
			"rattling_burrow", {"unlock_rattlings": true}, {}),
		_def("scorecard_2", "Another Scorecard", Act.MIST, 168.0, -3.0, "find",
			"scorecard", {"note": "note_2"}, {"persist": false}),
		_def("barley_spoon", "Barley's Spoon", Act.MIST, 190.0, 5.0, "find",
			"barley_spoon", {"unlock_node": "spoon_club"}, {"persist": false}),
		_def("stone_lantern", "Stone Lantern", Act.MIST, 222.0, -9.0, "find",
			"stone_lantern", {"golden_chance": 0.03}, {}),
		_def("birdhouse", "Birdhouse", Act.MIST, 248.0, -1.5, "target",
			"birdhouse", {"golden_bird_mult": 2.0},
			{"radius": 7.0, "sprite_found": "birdhouse_knocked"}),
		_def("scorecard_3", "A Third Scorecard", Act.COURSE, 275.0, 4.0, "find",
			"scorecard", {"note": "note_3"}, {"persist": false}),
		_def("persimmon_driver", "Persimmon Driver", Act.COURSE, 305.0, -4.0, "find",
			"persimmon_driver", {"unlock_node": "driver_club"}, {"persist": false}),
		_def("footbridge", "Footbridge", Act.COURSE, 330.0, 0.0, "find",
			"footbridge", {"rattling_speed_mult": 1.3}, {"pixel_size": 0.036}),
		_def("tee_sign", "Hole 1 Tee Sign", Act.COURSE, 356.0, -10.0, "find",
			"tee_sign", {"note": "note_tee"}, {}),
		_def("first_green", "The First Green", Act.FINALE, 382.0, 0.0, "finale",
			"flagstick", {"note": "note_last", "arm_finale": true}, {}),
	]
	for d in defs:
		_by_id[d["id"]] = d
		_order.append(d["id"])


static func _def(
	id: String,
	display_name: String,
	act: int,
	yards: float,
	x: float,
	kind: String,
	sprite: String,
	reward: Dictionary,
	extra: Dictionary
) -> Dictionary:
	var d := {
		"id": id,
		"display_name": display_name,
		"act": act,
		"yards": yards,
		"x": x,
		"kind": kind,
		"sprite": sprite,
		"sprite_found": sprite,
		"reward": reward,
		"persist": true,
		"radius": 0.0,
		"pixel_size": 0.032,
	}
	for k in extra:
		d[k] = extra[k]
	return d


static func all() -> Array:
	_init_defs()
	var out: Array = []
	for id in _order:
		out.append(_by_id[id])
	return out


static func order() -> Array[String]:
	_init_defs()
	return _order


static func get_def(id: String) -> Dictionary:
	_init_defs()
	return _by_id.get(id, {})


static func sprite_path(name: String) -> String:
	return SPRITE_DIR + name + ".png"


static func act_name(act: int) -> String:
	match act:
		Act.RANGE:
			return "I · The Range"
		Act.MIST:
			return "II · The Mist"
		Act.COURSE:
			return "III · The Old Course"
		Act.FINALE:
			return "The First Green"
	return ""


## Story role of each find — see docs/v5/02-finds.md ("Barley's trail").
## Find ids whose reward is a story gate for an upgrade node.
static func find_granting(reward_key: String) -> String:
	_init_defs()
	for id in _order:
		if (_by_id[id]["reward"] as Dictionary).has(reward_key):
			return id
	return ""


## Multiplicative / additive story rewards folded into PlayerStats.
static func apply_rewards(stats: PlayerStats, found: Dictionary) -> void:
	_init_defs()
	for id in _order:
		if not found.has(id):
			continue
		var r: Dictionary = _by_id[id]["reward"]
		if r.has("carry_mult"):
			stats.carry_multiplier *= float(r["carry_mult"])
		if r.has("swing_cooldown_mult"):
			stats.swing_cooldown_ms *= float(r["swing_cooldown_mult"])
		if r.has("bucket_bonus"):
			stats.bucket_capacity_bonus += float(r["bucket_bonus"])
		if r.has("golden_chance"):
			stats.golden_ball_chance += float(r["golden_chance"])
		if r.has("pickup_mult"):
			stats.pickup_multiplier *= float(r["pickup_mult"])


## Rattling-side story rewards (the footbridge lets them cross the creek).
static func apply_rattling_rewards(stats: PlayerStats, found: Dictionary) -> void:
	_init_defs()
	for id in _order:
		if not found.has(id):
			continue
		var r: Dictionary = _by_id[id]["reward"]
		if r.has("rattling_speed_mult"):
			stats.rattling_walk_speed *= float(r["rattling_speed_mult"])


## Short reward line for the Journal / toast.
static func reward_text(id: String) -> String:
	var r: Dictionary = get_def(id).get("reward", {})
	if r.has("unlock_ratina"):
		return "Ratina joined: land on her pink ball for bonus pay."
	if r.has("unlock_rattlings"):
		return "Rattlings joined: they fetch balls you leave behind."
	if r.has("carry_mult"):
		return "Carry ×%.2f" % float(r["carry_mult"])
	if r.has("unlock_node"):
		var node_name := String(UpgradeDefinitions.get_def(String(r["unlock_node"])).get("display_name", ""))
		return "New in the upgrade tree: %s" % node_name
	if r.has("swing_cooldown_mult"):
		return "Swings recover faster."
	if r.has("bucket_bonus"):
		return "+%d balls per bucket" % int(r["bucket_bonus"])
	if r.has("golden_chance"):
		return "+%d%% golden balls" % int(round(float(r["golden_chance"]) * 100.0))
	if r.has("golden_bird_mult"):
		return "Golden birds ×%d" % int(r["golden_bird_mult"])
	if r.has("pickup_mult"):
		return "Pickup pay ×%.2f" % float(r["pickup_mult"])
	if r.has("rattling_speed_mult"):
		return "Rattlings scurry ×%.1f" % float(r["rattling_speed_mult"])
	if r.has("arm_finale"):
		return "One ball."
	return ""
