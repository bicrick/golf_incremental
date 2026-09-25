extends Node
## v8 run state (autoload `Tour`): money, upgrades, ranges, greens, keepsakes,
## story. Saves to user://tour_save.json. The world and UI read from here and
## listen to its signals; nothing else owns progression.

signal money_changed(money: float)
signal upgrades_changed
signal range_changed(index: int)
signal bucket_changed(remaining: int, size: int)
signal green_starred(range_index: int, green_id: String)
signal keepsake_found(id: String)
signal range_cleared(index: int)
signal story_completed

const SAVE_PATH := "user://tour_save.json"
const SAVE_VERSION := 1
const AUTOSAVE_SEC := 10.0

var money := 0.0
var levels: Dictionary = {}
var range_index := 0
var unlocked_range := 0
var cleared: Dictionary = {} ## range id -> true
var stars: Dictionary = {} ## green id -> true (lantern greens: lit)
var keepsakes: Dictionary = {}
var rewards: Dictionary = {}
var seen: Dictionary = {} ## story beat ids already played
var range_swings: Dictionary = {} ## range id -> swings until its flag
var story_complete := false
var bucket_remaining := 8
var streak := 0
var stats := {"swings": 0, "perfects": 0, "greens": 0, "aces": 0, "best": 0.0, "earned": 0.0}
var play_time := 0.0
var flags: Dictionary = {} ## misc one-shot flags (bought_any, swept, ...)

## Off for sims and tests so they never touch the player's save.
var saving_enabled := true
var _autosave_t := 0.0
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	play_time += delta
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_SEC:
		_autosave_t = 0.0
		if _dirty:
			save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- derived ---------------------------------------------------------------

func current_range() -> Dictionary:
	return TourData.get_range(range_index)


func reach() -> float:
	return TourPhysics.reach(levels, rewards, keepsakes)


func bucket_size() -> int:
	return TourPhysics.bucket_size(levels, keepsakes)


func level(id: String) -> int:
	return int(levels.get(id, 0))


func lit_count(range_def: Dictionary = {}) -> int:
	var r := range_def if not range_def.is_empty() else current_range()
	var n := 0
	for g in r["greens"]:
		if g.get("lantern", false) and stars.get(g["id"], false):
			n += 1
	return n


func stars_in_range(index: int) -> int:
	var n := 0
	for g in TourData.get_range(index)["greens"]:
		if stars.get(g["id"], false):
			n += 1
	return n


func total_stars() -> int:
	return stars.size()


func has_started() -> bool:
	return stats["swings"] > 0 or seen.size() > 0


# --- money / upgrades ------------------------------------------------------

func add_money(amount: float) -> void:
	if amount <= 0.0:
		return
	money += amount
	stats["earned"] = float(stats["earned"]) + amount
	_dirty = true
	money_changed.emit(money)


func upgrade_cost(id: String) -> float:
	var u := TourData.upgrade(id)
	return floor(float(u["base"]) * pow(float(u["growth"]), level(id)))


func upgrade_visible(id: String) -> bool:
	var u := TourData.upgrade(id)
	var gate: String = u.get("shows", "")
	match gate:
		"":
			return true
		"bought_any":
			return flags.get("bought_any", false)
		"green_hit":
			return stats["greens"] > 0
		"stars_2":
			return total_stars() >= 2
		"swept":
			return flags.get("swept", false)
	if gate.begins_with("range_"):
		return unlocked_range >= int(gate.substr(6))
	return true


func upgrade_maxed(id: String) -> bool:
	return level(id) >= int(TourData.upgrade(id)["max"])


func can_buy(id: String) -> bool:
	return upgrade_visible(id) and not upgrade_maxed(id) and money >= upgrade_cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	money -= upgrade_cost(id)
	levels[id] = level(id) + 1
	flags["bought_any"] = true
	_dirty = true
	money_changed.emit(money)
	upgrades_changed.emit()
	if id == "bucket":
		bucket_remaining += 2
		bucket_changed.emit(bucket_remaining, bucket_size())
	return true


# --- bucket ----------------------------------------------------------------

func use_ball() -> void:
	bucket_remaining = maxi(bucket_remaining - 1, 0)
	bucket_changed.emit(bucket_remaining, bucket_size())


func refill_bucket(count: int = -1) -> void:
	bucket_remaining = bucket_size() if count < 0 else mini(bucket_remaining + count, bucket_size())
	bucket_changed.emit(bucket_remaining, bucket_size())


# --- progress ---------------------------------------------------------------

func record_swing(tier: int, carry: float) -> void:
	stats["swings"] = int(stats["swings"]) + 1
	if tier == 0:
		stats["perfects"] = int(stats["perfects"]) + 1
	stats["best"] = maxf(float(stats["best"]), carry)
	var rid: String = current_range()["id"]
	if not cleared.get(rid, false):
		range_swings[rid] = int(range_swings.get(rid, 0)) + 1
	_dirty = true


## Returns true the first time this green is hit (a new star).
func star_green(green_id: String) -> bool:
	stats["greens"] = int(stats["greens"]) + 1
	if stars.get(green_id, false):
		return false
	stars[green_id] = true
	_dirty = true
	green_starred.emit(range_index, green_id)
	return true


func find_keepsake(id: String) -> void:
	if keepsakes.get(id, false):
		return
	keepsakes[id] = true
	if TourPhysics.bonus_sum({id: true}, "balls") > 0.0:
		refill_bucket(bucket_remaining + 1)
	_dirty = true
	keepsake_found.emit(id)
	upgrades_changed.emit()


func clear_range(index: int) -> void:
	var r := TourData.get_range(index)
	if cleared.get(r["id"], false):
		return
	cleared[r["id"]] = true
	var rw: Dictionary = r["reward"]
	if not rw.is_empty():
		rewards[rw["id"]] = true
	unlocked_range = maxi(unlocked_range, mini(index + 1, TourData.range_count() - 1))
	_dirty = true
	range_cleared.emit(index)
	upgrades_changed.emit()


func travel_to(index: int) -> void:
	range_index = clampi(index, 0, unlocked_range)
	streak = 0
	refill_bucket()
	_dirty = true
	range_changed.emit(range_index)
	save_game()


func complete_story() -> void:
	if story_complete:
		return
	story_complete = true
	cleared["edge"] = true
	_dirty = true
	save_game()
	story_completed.emit()


func mark_seen(beat: String) -> bool:
	if seen.get(beat, false):
		return false
	seen[beat] = true
	_dirty = true
	return true


# --- save --------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"money": money,
		"levels": levels,
		"range_index": range_index,
		"unlocked_range": unlocked_range,
		"cleared": cleared,
		"stars": stars,
		"keepsakes": keepsakes,
		"rewards": rewards,
		"seen": seen,
		"range_swings": range_swings,
		"story_complete": story_complete,
		"bucket_remaining": bucket_remaining,
		"stats": stats,
		"play_time": play_time,
		"flags": flags,
	}


func from_dict(d: Dictionary) -> void:
	money = float(d.get("money", 0.0))
	levels = d.get("levels", {})
	for k in levels.keys():
		levels[k] = int(levels[k])
	range_index = int(d.get("range_index", 0))
	unlocked_range = int(d.get("unlocked_range", 0))
	cleared = d.get("cleared", {})
	stars = d.get("stars", {})
	keepsakes = d.get("keepsakes", {})
	rewards = d.get("rewards", {})
	seen = d.get("seen", {})
	range_swings = d.get("range_swings", {})
	story_complete = bool(d.get("story_complete", false))
	stats.merge(d.get("stats", {}), true)
	play_time = float(d.get("play_time", 0.0))
	flags = d.get("flags", {})
	bucket_remaining = clampi(int(d.get("bucket_remaining", bucket_size())), 0, bucket_size())


func save_game() -> void:
	if not saving_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))
	_dirty = false


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		reset()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if parsed is Dictionary:
		reset()
		from_dict(parsed)
	else:
		reset()


func reset() -> void:
	money = 0.0
	levels = {}
	range_index = 0
	unlocked_range = 0
	cleared = {}
	stars = {}
	keepsakes = {}
	rewards = {}
	seen = {}
	range_swings = {}
	story_complete = false
	streak = 0
	stats = {"swings": 0, "perfects": 0, "greens": 0, "aces": 0, "best": 0.0, "earned": 0.0}
	play_time = 0.0
	flags = {}
	bucket_remaining = bucket_size()
	_dirty = true


func new_game() -> void:
	reset()
	save_game()
	money_changed.emit(money)
	upgrades_changed.emit()
	range_changed.emit(range_index)
	bucket_changed.emit(bucket_remaining, bucket_size())
