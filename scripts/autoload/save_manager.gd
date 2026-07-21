extends Node
## Persist game state to user://save.json and audio prefs to user://settings.json

const SAVE_PATH: String = "user://save.json"
const SETTINGS_PATH: String = "user://settings.json"

var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var frame_graph_enabled: bool = false

var _autosave_timer: float = 0.0


func _ready() -> void:
	load_settings()
	EventBus.upgrade_purchased.connect(_on_state_changed)
	EventBus.swing_resolved.connect(_on_state_changed)


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= Balance.AUTOSAVE_INTERVAL_SEC:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _on_state_changed(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null) -> void:
	pass  # Throttled by autosave timer


func save_game() -> void:
	var data := {
		"version": Balance.SAVE_VERSION,
		"currency": GameState.currency,
		"upgrade_levels": GameState.upgrade_levels.duplicate(),
		"upgrades_unlocked": GameState.upgrades_unlocked,
		"shop_unlocked": GameState.shop_unlocked,
		"ratina_unlocked": GameState.ratina_unlocked,
		"rattlings_unlocked": GameState.rattlings_unlocked,
		"ratina_active": GameState.ratina_active,
		"rattlings_active": GameState.rattlings_active,
		"shop_levels": GameState.shop_levels.duplicate(),
		"ratina_upgrade_levels": GameState.ratina_upgrade_levels.duplicate(),
		"rattling_upgrade_levels": GameState.rattling_upgrade_levels.duplicate(),
		"cheese": GameState.cheese,
		"prestige_count": GameState.prestige_count,
		"prestige_threshold": GameState.prestige_threshold,
		"prestige_levels": GameState.prestige_levels.duplicate(),
		"lifetime": GameState.lifetime.duplicate(),
		"bucket_remaining": GameState.bucket_remaining,
		"bucket_capacity": GameState.bucket_capacity,
		"last_save_time": Time.get_unix_time_from_system() * 1000,
	}
	var json := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: corrupt settings, using defaults")
		return
	sfx_enabled = bool(parsed.get("sfx_enabled", true))
	music_enabled = bool(parsed.get("music_enabled", true))
	sfx_volume = clampf(float(parsed.get("sfx_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(parsed.get("music_volume", 1.0)), 0.0, 1.0)
	frame_graph_enabled = bool(parsed.get("frame_graph_enabled", false))


func save_settings() -> void:
	var data := {
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"frame_graph_enabled": frame_graph_enabled,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func wipe_character() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")
	GameState.reset_to_fresh()
	get_tree().reload_current_scene()


func reset_and_reload() -> void:
	wipe_character()


## The "Payout Bonus" rattling upgrade was removed for being overpowered.
## Any levels a player already bought are refunded in full so nobody loses
## progress, then the stale key is dropped from the save.
func _refund_removed_rattling_payout() -> float:
	if not GameState.rattling_upgrade_levels.has("rattling_payout"):
		return 0.0
	var level: int = int(GameState.rattling_upgrade_levels["rattling_payout"])
	GameState.rattling_upgrade_levels.erase("rattling_payout")
	var refund := 0.0
	for i in range(level):
		refund += Economy.upgrade_cost(8.0, 1.32, i)
	return refund


## Distance-pays prune (save v3): fold Carry into Raw Power, refund removed nodes,
## fold Ratina cadence chain into Frequency.
func _migrate_distance_pays_prune() -> float:
	var refund := 0.0
	refund += _fold_player_levels("power", "iron_set", 36.0, 1.26)
	refund += _refund_player_levels("great_eye", 36.0, 1.32)
	refund += _refund_player_levels("tip_jar", 18.0, 1.32)
	refund += _fold_ratina_levels("ratina_carry", "ratina_raw_power", 30.0, 1.24)
	refund += _fold_ratina_levels("ratina_rapid_fire", "ratina_frequency", 18.0, 1.34)
	refund += _fold_ratina_levels("ratina_gatling_barrel", "ratina_frequency", 48.0, 1.40)
	refund += _refund_ratina_levels("ratina_steady_hands", 30.0, 1.30)
	return refund


func _fold_player_levels(
	from_id: String, into_id: String, from_base: float, from_growth: float
) -> float:
	if not GameState.upgrade_levels.has(from_id):
		return 0.0
	var from_level: int = int(GameState.upgrade_levels[from_id])
	GameState.upgrade_levels.erase(from_id)
	if from_level <= 0:
		return 0.0
	var into_def := UpgradeDefinitions.get_def(into_id)
	var max_into: int = int(into_def.get("max_level", 99))
	var cur: int = int(GameState.upgrade_levels.get(into_id, 0))
	var room: int = maxi(max_into - cur, 0)
	var absorbed: int = mini(from_level, room)
	GameState.upgrade_levels[into_id] = cur + absorbed
	var refund := 0.0
	for i in range(absorbed, from_level):
		refund += Economy.upgrade_cost(from_base, from_growth, i)
	return refund


func _refund_player_levels(id: String, base: float, growth: float) -> float:
	if not GameState.upgrade_levels.has(id):
		return 0.0
	var level: int = int(GameState.upgrade_levels[id])
	GameState.upgrade_levels.erase(id)
	var refund := 0.0
	for i in range(level):
		refund += Economy.upgrade_cost(base, growth, i)
	return refund


func _fold_ratina_levels(
	from_id: String, into_id: String, from_base: float, from_growth: float
) -> float:
	if not GameState.ratina_upgrade_levels.has(from_id):
		return 0.0
	var from_level: int = int(GameState.ratina_upgrade_levels[from_id])
	GameState.ratina_upgrade_levels.erase(from_id)
	if from_level <= 0:
		return 0.0
	var into_def := RatinaUpgradeDefinitions.get_def(into_id)
	var max_into: int = int(into_def.get("max_level", 99))
	var cur: int = int(GameState.ratina_upgrade_levels.get(into_id, 0))
	var room: int = maxi(max_into - cur, 0)
	var absorbed: int = mini(from_level, room)
	GameState.ratina_upgrade_levels[into_id] = cur + absorbed
	var refund := 0.0
	for i in range(absorbed, from_level):
		refund += Economy.upgrade_cost(from_base, from_growth, i)
	return refund


func _refund_ratina_levels(id: String, base: float, growth: float) -> float:
	if not GameState.ratina_upgrade_levels.has(id):
		return 0.0
	var level: int = int(GameState.ratina_upgrade_levels[id])
	GameState.ratina_upgrade_levels.erase(id)
	var refund := 0.0
	for i in range(level):
		refund += Economy.upgrade_cost(base, growth, i)
	return refund


func _migrate_save(from_version: int) -> float:
	var refund := 0.0
	if from_version < 2:
		if GameState.ratina_unlocked and GameState.get_upgrade_level("ratina_hire") < 1:
			GameState.upgrade_levels["ratina_hire"] = 1
		if GameState.rattlings_unlocked and GameState.get_rattling_upgrade_level("rattling_more") < 1:
			GameState.rattling_upgrade_levels["rattling_more"] = 1
	if from_version < 3:
		refund += _migrate_distance_pays_prune()
	if from_version < 4:
		_migrate_v7_strip_play_op()
	return refund


func _migrate_v7_strip_play_op() -> void:
	for stale_id in ["quick_reset", "combo_bonus", "ratina_hire"]:
		GameState.upgrade_levels.erase(stale_id)
	GameState.shop_levels.erase("ball_count")
	GameState.shop_levels.erase("golden_ball")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: corrupt save, starting fresh")
		return
	if parsed.get("version", 0) > Balance.SAVE_VERSION:
		push_warning("SaveManager: save version mismatch")
		return
	var save_version: int = int(parsed.get("version", 0))
	GameState.currency = float(parsed.get("currency", 0.0))
	GameState.upgrade_levels = parsed.get("upgrade_levels", {})
	# Upgrades menu is always available; migrate old locked saves.
	GameState.upgrades_unlocked = true
	GameState.shop_unlocked = bool(parsed.get("shop_unlocked", false))
	GameState.ratina_unlocked = bool(parsed.get("ratina_unlocked", false))
	GameState.rattlings_unlocked = bool(parsed.get("rattlings_unlocked", false))
	GameState.ratina_active = bool(parsed.get("ratina_active", true))
	GameState.rattlings_active = bool(parsed.get("rattlings_active", true))
	GameState.shop_levels = parsed.get("shop_levels", {})
	GameState.ratina_upgrade_levels = parsed.get("ratina_upgrade_levels", {})
	GameState.rattling_upgrade_levels = parsed.get("rattling_upgrade_levels", {})
	GameState.cheese = int(floor(float(parsed.get("cheese", 0))))
	GameState.prestige_count = int(parsed.get("prestige_count", 0))
	GameState.prestige_levels = parsed.get("prestige_levels", {}).duplicate()
	if typeof(GameState.prestige_levels) != TYPE_DICTIONARY:
		GameState.prestige_levels = {}
	# threshold recomputed in _recompute_stats via Ambition
	GameState.currency += _refund_removed_rattling_payout()
	GameState.lifetime = parsed.get("lifetime", GameState.lifetime)
	GameState.bucket_capacity = int(parsed.get("bucket_capacity", Balance.BUCKET_CAPACITY_DEFAULT))
	var saved_remaining: int = int(parsed.get("bucket_remaining", -1))
	GameState.bucket_remaining = saved_remaining if saved_remaining >= 0 else GameState.bucket_capacity
	GameState.currency += _migrate_save(save_version)
	GameState._recompute_stats()
