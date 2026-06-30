extends Control
## Corner icon buttons — toggles overlay menus without blocking the range view.

signal upgrades_toggled(is_open: bool)

const ICON_SIZE := Vector2i(24, 24)
const MARGIN := 8

const COLOR_WOOD := Color(0.55, 0.42, 0.32, 1)
const COLOR_WOOD_DARK := Color(0.35, 0.28, 0.22, 1)
const COLOR_CREAM := Color(0.85, 0.75, 0.55, 1)
const COLOR_DISABLED := Color(0.45, 0.4, 0.35, 0.6)

@onready var upgrades_button: Button = $TopRight/UpgradesButton
@onready var settings_button: Button = $TopLeft/SettingsButton
@onready var stats_button: Button = $BottomLeft/StatsButton

var _upgrade_panel: Node = null
var _upgrades_open := false


func _ready() -> void:
	_upgrade_panel = get_parent().get_node_or_null("UpgradePanel")
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	settings_button.disabled = true
	stats_button.disabled = true
	_style_icon_button(upgrades_button, COLOR_CREAM)
	_style_icon_button(settings_button, COLOR_DISABLED)
	_style_icon_button(stats_button, COLOR_DISABLED)


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


func _set_upgrades_pressed(is_open: bool) -> void:
	upgrades_button.button_pressed = is_open
	var glyph := upgrades_button.get_node_or_null("Glyph") as ColorRect
	if glyph:
		glyph.color = Color(0.95, 0.88, 0.65, 1) if is_open else COLOR_CREAM


func _style_icon_button(button: Button, glyph_color: Color) -> void:
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
	var glyph := button.get_node_or_null("Glyph") as ColorRect
	if glyph:
		glyph.color = glyph_color
