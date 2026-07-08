extends Node
## Persist game state to user://save.json and audio prefs to user://settings.json

const SAVE_PATH: String = "user://save.json"
const SETTINGS_PATH: String = "user://settings.json"

var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 1.0
var music_volume: float = 1.0

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


func save_settings() -> void:
	var data := {
		"sfx_enabled": sfx_enabled,
		"music_enabled": music_enabled,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
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


func _migrate_save(from_version: int) -> void:
	if from_version < 2:
		if GameState.ratina_unlocked and GameState.get_upgrade_level("ratina_hire") < 1:
			GameState.upgrade_levels["ratina_hire"] = 1
		if GameState.rattlings_unlocked and GameState.get_rattling_upgrade_level("rattling_more") < 1:
			GameState.rattling_upgrade_levels["rattling_more"] = 1


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
	GameState.upgrades_unlocked = bool(parsed.get("upgrades_unlocked", false))
	GameState.shop_unlocked = bool(parsed.get("shop_unlocked", false))
	GameState.ratina_unlocked = bool(parsed.get("ratina_unlocked", false))
	GameState.rattlings_unlocked = bool(parsed.get("rattlings_unlocked", false))
	GameState.ratina_active = bool(parsed.get("ratina_active", true))
	GameState.rattlings_active = bool(parsed.get("rattlings_active", true))
	GameState.shop_levels = parsed.get("shop_levels", {})
	GameState.ratina_upgrade_levels = parsed.get("ratina_upgrade_levels", {})
	GameState.rattling_upgrade_levels = parsed.get("rattling_upgrade_levels", {})
	GameState.currency += _refund_removed_rattling_payout()
	GameState.lifetime = parsed.get("lifetime", GameState.lifetime)
	GameState.bucket_capacity = int(parsed.get("bucket_capacity", Balance.BUCKET_CAPACITY_DEFAULT))
	var saved_remaining: int = int(parsed.get("bucket_remaining", -1))
	GameState.bucket_remaining = saved_remaining if saved_remaining >= 0 else GameState.bucket_capacity
	_migrate_save(save_version)
