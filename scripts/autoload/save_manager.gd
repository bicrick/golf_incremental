extends Node
## Persist game state to user://save.json

const SAVE_PATH: String = "user://save.json"
var _autosave_timer: float = 0.0


func _ready() -> void:
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


func _on_state_changed(_a = null, _b = null, _c = null, _d = null, _e = null) -> void:
	pass  # Throttled by autosave timer


func save_game() -> void:
	var data := {
		"version": Balance.SAVE_VERSION,
		"currency": GameState.currency,
		"upgrade_levels": GameState.upgrade_levels.duplicate(),
		"lifetime": GameState.lifetime.duplicate(),
		"last_save_time": Time.get_unix_time_from_system() * 1000,
	}
	var json := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


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
	if parsed.get("version", 0) != Balance.SAVE_VERSION:
		push_warning("SaveManager: save version mismatch")
		return
	GameState.currency = float(parsed.get("currency", 0.0))
	GameState.upgrade_levels = parsed.get("upgrade_levels", {})
	GameState.lifetime = parsed.get("lifetime", GameState.lifetime)
