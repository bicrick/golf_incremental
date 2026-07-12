extends Control
## Corner icon buttons — opens full-screen upgrade tree.

signal upgrades_toggled(is_open: bool)

const ICON_SIZE := Vector2i(24, 24)
const MARGIN := 8
const PANEL_BORDER := 2
const WRAP_MARGIN_H := 2
const WRAP_MARGIN_V := 1

const HOVER_BOB_AMPLITUDE := 1.5
const HOVER_BOB_FREQ := 2.4

@onready var hit_button: Button = $BottomRight/HitWrap/HitButton
@onready var _hit_wrap: PanelContainer = $BottomRight/HitWrap
@onready var upgrades_button: Button = $TopRight/UpgradesWrap/UpgradesButton
@onready var _upgrades_glyph: Control = $TopRight/UpgradesWrap/UpgradesButton/Glyph
@onready var _upgrades_wrap: PanelContainer = $TopRight/UpgradesWrap

var _upgrade_panel: Node = null
var _upgrades_open := false
var _upgrades_rest_y := 0.0
var _upgrades_hover := false
var _hover_bob_time := 0.0


func _ready() -> void:
	var ui_root := get_parent().get_parent()
	_upgrade_panel = ui_root.get_node_or_null("UpgradePanel")
	hit_button.pressed.connect(_on_hit_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	upgrades_button.mouse_entered.connect(_on_upgrades_mouse_entered)
	upgrades_button.mouse_exited.connect(_on_upgrades_mouse_exited)
	EventBus.phase_changed.connect(_on_phase_changed)
	_style_hit_wrap()
	_style_hit_button()
	_style_upgrades_wrap()
	_style_upgrades_button()
	_layout_top_right_corner()
	_refresh_hit_visibility()
	upgrades_button.disabled = false
	upgrades_button.tooltip_text = ""
	_upgrades_wrap.modulate = Color.WHITE
	if _upgrades_glyph:
		_upgrades_glyph.locked = false
	call_deferred("_capture_button_rest_positions")
	set_process(false)


func _on_phase_changed(_phase: String) -> void:
	_refresh_hit_visibility()


func _refresh_hit_visibility() -> void:
	_hit_wrap.visible = GameState.is_harvest_phase()


func _on_hit_pressed() -> void:
	GameState.exit_harvest_early()


func _capture_button_rest_positions() -> void:
	_upgrades_rest_y = _upgrades_wrap.position.y


func _process(delta: float) -> void:
	if not _upgrades_hover:
		return
	_hover_bob_time += delta
	var wave := sin(_hover_bob_time * HOVER_BOB_FREQ) * HOVER_BOB_AMPLITUDE
	if _upgrades_hover:
		_upgrades_wrap.position.y = _upgrades_rest_y + wave


func _on_upgrades_mouse_entered() -> void:
	_upgrades_hover = true
	_apply_wrap_panel_style(_upgrades_wrap, true)
	set_process(true)


func _on_upgrades_mouse_exited() -> void:
	_upgrades_hover = false
	_upgrades_wrap.position.y = _upgrades_rest_y
	_apply_wrap_panel_style(_upgrades_wrap, false, upgrades_button.button_pressed)
	set_process(_upgrades_hover)


func _on_upgrades_pressed() -> void:
	if _upgrade_panel == null:
		return
	if _upgrade_panel.has_method("toggle"):
		_upgrade_panel.toggle()
		_upgrades_open = _upgrade_panel.is_open() if _upgrade_panel.has_method("is_open") else not _upgrades_open
	else:
		_upgrades_open = not _upgrades_open
		_upgrade_panel.visible = _upgrades_open
	set_upgrades_open(_upgrades_open)
	upgrades_toggled.emit(_upgrades_open)


func set_upgrades_open(is_open: bool) -> void:
	_upgrades_open = is_open
	upgrades_button.button_pressed = is_open
	if _upgrades_glyph:
		_upgrades_glyph.highlighted = is_open
	_apply_wrap_panel_style(_upgrades_wrap, _upgrades_hover, is_open)


func _layout_top_right_corner() -> void:
	var top_right: Control = $TopRight
	var outer := Vector2(_wrap_outer_size())
	top_right.offset_left = -MARGIN - outer.x
	top_right.offset_top = MARGIN
	top_right.offset_right = -MARGIN
	top_right.offset_bottom = MARGIN + outer.y
	_upgrades_wrap.custom_minimum_size = outer


func _wrap_outer_size() -> Vector2i:
	return Vector2i(
		ICON_SIZE.x + WRAP_MARGIN_H * 2 + PANEL_BORDER * 2,
		ICON_SIZE.y + WRAP_MARGIN_V * 2 + PANEL_BORDER * 2
	)


func _make_wrap_panel_style(hovering: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := UiTheme.make_wood_panel()
	style.content_margin_left = WRAP_MARGIN_H
	style.content_margin_right = WRAP_MARGIN_H
	style.content_margin_top = WRAP_MARGIN_V
	style.content_margin_bottom = WRAP_MARGIN_V
	if pressed:
		style.bg_color = UiTheme.COLOR_PARCHMENT.darkened(0.05)
	elif hovering:
		style.bg_color = UiTheme.COLOR_PARCHMENT.lightened(0.06)
	return style


func _apply_wrap_panel_style(wrap: PanelContainer, hovering: bool = false, pressed: bool = false) -> void:
	wrap.add_theme_stylebox_override(&"panel", _make_wrap_panel_style(hovering, pressed))


func _style_hit_wrap() -> void:
	_hit_wrap.custom_minimum_size = Vector2(_wrap_outer_size())
	_apply_wrap_panel_style(_hit_wrap)


func _style_upgrades_wrap() -> void:
	_apply_wrap_panel_style(_upgrades_wrap)


func _style_icon_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(ICON_SIZE)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)


func _style_hit_button() -> void:
	_style_icon_button(hit_button)


func _style_upgrades_button() -> void:
	_style_icon_button(upgrades_button)
