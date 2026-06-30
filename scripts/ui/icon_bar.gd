extends Control
## Corner icon buttons — opens full-screen views (e.g. upgrade tree).

signal upgrades_toggled(is_open: bool)

const ICON_SIZE := Vector2i(24, 24)
const MARGIN := 8

const COLOR_WOOD := Color(0.55, 0.42, 0.32, 1)
const COLOR_WOOD_DARK := Color(0.35, 0.28, 0.22, 1)
const COLOR_DISABLED := Color(0.45, 0.4, 0.35, 0.6)

const PULSE_BOB_AMPLITUDE := 2.0
const PULSE_BOB_FREQ := 2.4
const PULSE_ALPHA_MIN := 0.94
const PULSE_ALPHA_MAX := 1.0

@onready var upgrades_button: Button = $TopRight/UpgradesButton
@onready var settings_button: Button = $TopLeft/SettingsButton
@onready var stats_button: Button = $BottomLeft/StatsButton
@onready var _upgrades_glyph: Control = $TopRight/UpgradesButton/Glyph

var _upgrade_panel: Node = null
var _upgrades_open := false
var _pulse_active := false
var _pulse_time := 0.0
var _glyph_rest_y := 0.0


func _ready() -> void:
	_upgrade_panel = get_parent().get_node_or_null("UpgradePanel")
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	settings_button.disabled = true
	stats_button.disabled = true
	_style_upgrades_button()
	_style_icon_button(settings_button, COLOR_DISABLED)
	_style_icon_button(stats_button, COLOR_DISABLED)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	call_deferred("_capture_glyph_rest_y")
	call_deferred("_update_pulse_state")


func _capture_glyph_rest_y() -> void:
	_glyph_rest_y = _upgrades_glyph.position.y


func _process(delta: float) -> void:
	if not _pulse_active:
		return
	_pulse_time += delta
	var wave := sin(_pulse_time * PULSE_BOB_FREQ)
	_upgrades_glyph.position.y = _glyph_rest_y + wave * PULSE_BOB_AMPLITUDE
	var alpha := lerpf(PULSE_ALPHA_MIN, PULSE_ALPHA_MAX, 0.5 + 0.5 * wave)
	_upgrades_glyph.modulate = Color(1.0, 1.0, 1.0, alpha)


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
	_stop_pulse(false)
	_pulse_time = 0.0
	_upgrades_glyph.modulate = Color(1.0, 1.0, 1.0, PULSE_ALPHA_MIN)
	set_process(true)


func _stop_pulse(reset_visual: bool = true) -> void:
	set_process(false)
	if reset_visual:
		_reset_glyph_visual()


func _reset_glyph_visual() -> void:
	_upgrades_glyph.position.y = _glyph_rest_y
	_upgrades_glyph.modulate = Color.WHITE


func _on_upgrades_pressed() -> void:
	if _upgrade_panel == null:
		return
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
