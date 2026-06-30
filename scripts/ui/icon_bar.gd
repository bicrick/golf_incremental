extends Control
## Corner icon buttons — opens full-screen views (e.g. upgrade tree).

signal upgrades_toggled(is_open: bool)
signal settings_toggled(is_open: bool)

const ICON_SIZE := Vector2i(24, 24)
const MARGIN := 8

const COLOR_WOOD := Color(0.55, 0.42, 0.32, 1)
const COLOR_WOOD_DARK := Color(0.35, 0.28, 0.22, 1)
const COLOR_DISABLED := Color(0.45, 0.4, 0.35, 0.6)

const PULSE_BOB_AMPLITUDE := 1.5
const PULSE_BOB_FREQ := 1.2

@onready var upgrades_button: Button = $TopRight/UpgradesButton
@onready var settings_button: Button = $BottomRight/SettingsButton
@onready var stats_button: Button = $BottomLeft/StatsButton
@onready var _upgrades_glyph: Control = $TopRight/UpgradesButton/Glyph
@onready var _settings_glyph: Control = $BottomRight/SettingsButton/Glyph

var _upgrade_panel: Node = null
var _settings_panel: Node = null
var _upgrades_open := false
var _settings_open := false
var _pulse_active := false
var _pulse_time := 0.0
var _button_rest_y := 0.0


func _ready() -> void:
	_upgrade_panel = get_parent().get_node_or_null("UpgradePanel")
	var main := get_tree().root.get_node_or_null("Main")
	if main:
		_settings_panel = main.get_node_or_null("SettingsLayer/SettingsPanel")
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	_style_upgrades_button()
	_style_settings_button()
	_style_icon_button(stats_button, COLOR_DISABLED)
	stats_button.disabled = true
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	upgrades_button.tooltip_text = ""
	call_deferred("_capture_button_rest_y")
	call_deferred("_update_pulse_state")


func _capture_button_rest_y() -> void:
	_button_rest_y = upgrades_button.position.y


func _process(delta: float) -> void:
	if not _pulse_active:
		return
	_pulse_time += delta
	var wave := sin(_pulse_time * PULSE_BOB_FREQ)
	upgrades_button.position.y = _button_rest_y + wave * PULSE_BOB_AMPLITUDE


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_update_pulse_state()


func _on_upgrade_purchased(_id: String, _level: int, _branch: int) -> void:
	_update_pulse_state()


func _has_affordable_upgrade() -> bool:
	return UpgradeDefinitions.has_affordable_upgrade(
		GameState.upgrade_levels, GameState.currency, GameState.lifetime
	)


func _update_pulse_state() -> void:
	var should_pulse := not _upgrades_open and _has_affordable_upgrade()
	if should_pulse == _pulse_active:
		return
	_pulse_active = should_pulse
	if _pulse_active:
		_start_pulse()
	else:
		_stop_pulse()


func _start_pulse() -> void:
	set_process(true)


func _stop_pulse(reset_visual: bool = true) -> void:
	set_process(false)
	if reset_visual:
		_reset_button_bob()


func _reset_button_bob() -> void:
	upgrades_button.position.y = _button_rest_y


func _on_upgrades_pressed() -> void:
	if _upgrade_panel == null:
		return
	if _settings_panel and _settings_panel.has_method("is_open") and _settings_panel.is_open():
		_settings_panel.close()
	if _upgrade_panel.has_method("toggle"):
		_upgrade_panel.toggle()
		_upgrades_open = _upgrade_panel.is_open() if _upgrade_panel.has_method("is_open") else not _upgrades_open
	else:
		_upgrades_open = not _upgrades_open
		_upgrade_panel.visible = _upgrades_open
	_set_upgrades_pressed(_upgrades_open)
	upgrades_toggled.emit(_upgrades_open)


func set_upgrades_open(is_open: bool) -> void:
	_upgrades_open = is_open
	_set_upgrades_pressed(is_open)
	_update_pulse_state()


func _set_upgrades_pressed(is_open: bool) -> void:
	upgrades_button.button_pressed = is_open
	_upgrades_glyph.highlighted = is_open


func _style_upgrades_button() -> void:
	upgrades_button.custom_minimum_size = Vector2(ICON_SIZE)
	var empty := StyleBoxEmpty.new()
	upgrades_button.add_theme_stylebox_override("normal", empty)
	upgrades_button.add_theme_stylebox_override("hover", empty)
	upgrades_button.add_theme_stylebox_override("pressed", empty)
	upgrades_button.add_theme_stylebox_override("disabled", empty)


func _on_settings_pressed() -> void:
	if _settings_panel == null:
		return
	if _upgrade_panel and _upgrade_panel.has_method("is_open") and _upgrade_panel.is_open():
		_upgrade_panel.close()
	if _settings_panel.has_method("toggle"):
		_settings_panel.toggle()
		_settings_open = _settings_panel.is_open() if _settings_panel.has_method("is_open") else not _settings_open
	else:
		_settings_open = not _settings_open
		_settings_panel.visible = _settings_open
	_set_settings_pressed(_settings_open)
	settings_toggled.emit(_settings_open)


func set_settings_open(is_open: bool) -> void:
	_settings_open = is_open
	_set_settings_pressed(is_open)


func _set_settings_pressed(is_open: bool) -> void:
	settings_button.button_pressed = is_open
	if _settings_glyph:
		_settings_glyph.highlighted = is_open


func _style_settings_button() -> void:
	settings_button.custom_minimum_size = Vector2(ICON_SIZE)
	var empty := StyleBoxEmpty.new()
	settings_button.add_theme_stylebox_override("normal", empty)
	settings_button.add_theme_stylebox_override("hover", empty)
	settings_button.add_theme_stylebox_override("pressed", empty)
	settings_button.add_theme_stylebox_override("disabled", empty)


func _style_icon_button(button: Button, glyph_color: Color = Color.TRANSPARENT) -> void:
	button.custom_minimum_size = Vector2(ICON_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_WOOD
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_WOOD_DARK
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	if glyph_color == Color.TRANSPARENT:
		return
	var glyph := button.get_node_or_null("Glyph") as ColorRect
	if glyph:
		glyph.color = glyph_color
