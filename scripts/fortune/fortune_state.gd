extends Node
## v9 run state (autoload `Game`): cash, upgrades, rooms, buffs and the
## permanent bonus. Saves to user://fortune_save.json.

signal cash_changed(cash: float)
signal upgrades_changed
signal room_unlocked(id: String)
signal buffs_changed
signal big_moment(kind: String, text: String) ## jackpots, aces, doubles…
signal won
signal room_earned(id: String, amount: float)

const SAVE_PATH := "user://fortune_save.json"
const AUTOSAVE_SEC := 8.0

var cash := 0.0
var earned := 0.0
var levels: Dictionary = {}
var rooms: Dictionary = {"tee": true}
var permanent := 0.0 ## +% to everything, from jackpots, aces, snake eyes
var buffs: Array[Dictionary] = [] ## {name, mult, t, total}
var frenzy := 0.0 ## seconds of Tee Line frenzy left
var stats := {"swings": 0, "perfects": 0, "pins": 0, "jackpots": 0, "aces": 0, "doubles": 0, "cards": 0, "putts": 0}
var play_time := 0.0
var has_won := false
var flags: Dictionary = {} ## songs heard, hints seen
var saving_enabled := true
var _save_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_game()


func _process(delta: float) -> void:
	play_time += delta
	frenzy = maxf(frenzy - delta, 0.0)
	var changed := false
	for b in buffs:
		b["t"] = float(b["t"]) - delta
		if float(b["t"]) <= 0.0:
			changed = true
	if changed:
		buffs = buffs.filter(func(b: Dictionary) -> bool: return float(b["t"]) > 0.0)
		buffs_changed.emit()
	_save_t += delta
	if _save_t > AUTOSAVE_SEC:
		_save_t = 0.0
		save_game()


# --- money --------------------------------------------------------------------------

func global_mult() -> float:
	var m := 1.0 + permanent
	for b in buffs:
		m *= float(b["mult"])
	return m


## Credit a raw amount; the global multiplier applies here. Returns what was paid.
func earn(raw: float, room: String = "") -> float:
	if raw <= 0.0:
		return 0.0
	var amt := raw * global_mult()
	cash += amt
	earned += amt
	cash_changed.emit(cash)
	if room != "":
		room_earned.emit(room, amt)
	return amt


func spend(amount: float) -> bool:
	if cash < amount:
		return false
	cash -= amount
	cash_changed.emit(cash)
	return true


# --- upgrades / rooms -----------------------------------------------------------------

func level(id: String) -> int:
	return int(levels.get(id, 0))


func cost(id: String) -> float:
	var u := FortuneData.upgrade(id)
	return floor(float(u["base"]) * pow(float(u["growth"]), level(id)))


func maxed(id: String) -> bool:
	return level(id) >= int(FortuneData.upgrade(id)["max"])


func available(id: String) -> bool:
	var u := FortuneData.upgrade(id)
	if not rooms.get(u["room"], false):
		return false
	var need: String = u.get("needs", "")
	return need == "" or level(need) > 0


func can_buy(id: String) -> bool:
	return available(id) and not maxed(id) and cash >= cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	spend(cost(id))
	levels[id] = level(id) + 1
	upgrades_changed.emit()
	return true


func unlock_room(id: String) -> bool:
	if rooms.get(id, false):
		return true
	var r := FortuneData.room(id)
	if not spend(float(r["unlock"])):
		return false
	rooms[id] = true
	room_unlocked.emit(id)
	upgrades_changed.emit()
	return true


# --- buffs & bonuses -------------------------------------------------------------------

func add_buff(name: String, mult: float, sec: float) -> void:
	for b in buffs:
		if b["name"] == name:
			b["t"] = float(b["t"]) + sec
			b["total"] = float(b["t"])
			buffs_changed.emit()
			return
	buffs.append({"name": name, "mult": mult, "t": sec, "total": sec})
	buffs_changed.emit()


func add_permanent(pct: float, why: String) -> void:
	permanent += pct
	buffs_changed.emit()
	big_moment.emit("permanent", "%s  +%s%% forever" % [why, String.num(pct * 100.0, 1).trim_suffix(".0")])


func has_started() -> bool:
	return earned > 0.0


## First time only: returns true and remembers it.
func mark_seen(key: String) -> bool:
	if flags.get(key, false):
		return false
	flags[key] = true
	return true


func bump(stat: String, n: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + n


func buy_the_range() -> bool:
	if has_won or not spend(FortuneData.GOAL):
		return false
	has_won = true
	save_game()
	won.emit()
	return true


# --- save ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"cash": cash, "earned": earned, "levels": levels, "rooms": rooms, "permanent": permanent,
		"stats": stats, "play_time": play_time, "has_won": has_won, "flags": flags}


func from_dict(d: Dictionary) -> void:
	cash = float(d.get("cash", 0.0))
	earned = float(d.get("earned", 0.0))
	levels = d.get("levels", {})
	for k in levels.keys():
		levels[k] = int(levels[k])
	rooms = d.get("rooms", {"tee": true})
	permanent = float(d.get("permanent", 0.0))
	stats.merge(d.get("stats", {}), true)
	play_time = float(d.get("play_time", 0.0))
	has_won = bool(d.get("has_won", false))
	flags = d.get("flags", {})


func save_game() -> void:
	if not saving_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> void:
	reset()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		from_dict(d)


func reset() -> void:
	cash = 0.0
	earned = 0.0
	levels = {}
	rooms = {"tee": true}
	permanent = 0.0
	buffs = []
	frenzy = 0.0
	stats = {"swings": 0, "perfects": 0, "pins": 0, "jackpots": 0, "aces": 0, "doubles": 0, "cards": 0, "putts": 0}
	play_time = 0.0
	has_won = false
	flags = {}


func new_game() -> void:
	reset()
	save_game()
	cash_changed.emit(cash)
	upgrades_changed.emit()
	buffs_changed.emit()
