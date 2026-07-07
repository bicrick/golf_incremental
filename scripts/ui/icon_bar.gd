extends Control
## Corner icon buttons — opens full-screen views (upgrade tree, Pro Shop).

signal upgrades_toggled(is_open: bool)
signal shop_toggled(is_open: bool)

const ICON_SIZE := Vector2i(24, 24)
const MARGIN := 8
const PANEL_BORDER := 2
const WRAP_MARGIN_H := 2
const WRAP_MARGIN_V := 1
const CORNER_GAP := 4

const HOVER_BOB_AMPLITUDE := 1.5
const HOVER_BOB_FREQ := 2.4

@onready var hit_button: Button = $BottomRight/HitWrap/HitButton
@onready var _hit_wrap: PanelContainer = $BottomRight/HitWrap
@onready var shop_button: Button = $TopRight/TopRightRow/ShopWrap/ShopButton
@onready var upgrades_button: Button = $TopRight/TopRightRow/UpgradesWrap/UpgradesButton
@onready var _shop_glyph: Control = $TopRight/TopRightRow/ShopWrap/ShopButton/Glyph
@onready var _shop_wrap: PanelContainer = $TopRight/TopRightRow/ShopWrap
@onready var _upgrades_glyph: Control = $TopRight/TopRightRow/UpgradesWrap/UpgradesButton/Glyph
@onready var _upgrades_wrap: PanelContainer = $TopRight/TopRightRow/UpgradesWrap
@onready var _top_right_row: HBoxContainer = $TopRight/TopRightRow

var _upgrade_panel: Node = null
var _shop_panel: Node = null
var _upgrades_open := false
var _shop_open := false
var _upgrades_rest_y := 0.0
var _shop_rest_y := 0.0
var _upgrades_hover := false
var _shop_hover := false
var _hover_bob_time := 0.0


func _ready() -> void:
	var ui_root := get_parent().get_parent()
	_upgrade_panel = ui_root.get_node_or_null("UpgradePanel")
	_shop_panel = ui_root.get_node_or_null("ShopPanel")
	hit_button.pressed.connect(_on_hit_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	shop_button.mouse_entered.connect(_on_shop_mouse_entered)
	shop_button.mouse_exited.connect(_on_shop_mouse_exited)
	upgrades_button.mouse_entered.connect(_on_upgrades_mouse_entered)
	upgrades_button.mouse_exited.connect(_on_upgrades_mouse_exited)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.phase_changed.connect(_on_phase_changed)
	_style_hit_wrap()
	_style_hit_button()
	_style_shop_wrap()
	_style_upgrades_wrap()
	_style_shop_button()
	_style_upgrades_button()
	_layout_top_right_corner()
	_refresh_hit_visibility()
	shop_button.tooltip_text = ""
	upgrades_button.tooltip_text = ""
	call_deferred("_capture_button_rest_positions")
	call_deferred("_refresh_shop_lock_state")
	call_deferred("_refresh_upgrades_lock_state")
	set_process(false)


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_refresh_shop_lock_state()
	_refresh_upgrades_lock_state()


func _on_upgrade_purchased(id: String, _level: int, _branch: int) -> void:
	if id == "base_pay":
		_refresh_shop_lock_state()
		_layout_top_right_corner()


func _on_phase_changed(_phase: String) -> void:
	_refresh_hit_visibility()


## Hit button only appears in collect mode — lets the player return to hitting
## with any ball count (stashed + collected balls merge back into the bucket).
func _refresh_hit_visibility() -> void:
	_hit_wrap.visible = GameState.is_harvest_phase()


func _on_hit_pressed() -> void:
	GameState.exit_harvest_early()


func _refresh_shop_lock_state() -> void:
	if shop_button == null:
		return
	var visible := GameState.is_shop_visible()
	_shop_wrap.visible = visible
	if not visible:
		return
	var unlocked := GameState.shop_unlocked
	var can_afford := GameState.currency >= Balance.SHOP_UNLOCK_COST
	shop_button.disabled = not unlocked and not can_afford
	if unlocked:
		shop_button.tooltip_text = ""
		_shop_wrap.modulate = Color.WHITE
		if _shop_glyph:
			_shop_glyph.locked = false
	else:
		shop_button.tooltip_text = "$%.0f" % Balance.SHOP_UNLOCK_COST
		if can_afford:
			_shop_wrap.modulate = Color(1.0, 1.0, 1.0, 0.85)
		else:
			_shop_wrap.modulate = Color(0.55, 0.52, 0.48, 0.75)
		if _shop_glyph:
			_shop_glyph.locked = true


func _refresh_upgrades_lock_state() -> void:
	if upgrades_button == null:
		return
	var unlocked := GameState.upgrades_unlocked
	var can_afford := GameState.currency >= Balance.UPGRADES_UNLOCK_COST
	upgrades_button.disabled = not unlocked and not can_afford
	if unlocked:
		upgrades_button.tooltip_text = ""
		_upgrades_wrap.modulate = Color.WHITE
		if _upgrades_glyph:
			_upgrades_glyph.locked = false
	else:
		upgrades_button.tooltip_text = "$%.2f" % Balance.UPGRADES_UNLOCK_COST
		if can_afford:
			_upgrades_wrap.modulate = Color(1.0, 1.0, 1.0, 0.85)
		else:
			_upgrades_wrap.modulate = Color(0.55, 0.52, 0.48, 0.75)
		if _upgrades_glyph:
			_upgrades_glyph.locked = true


func _capture_button_rest_positions() -> void:
	_shop_rest_y = _shop_wrap.position.y
	_upgrades_rest_y = _upgrades_wrap.position.y


func _process(delta: float) -> void:
	if not _shop_hover and not _upgrades_hover:
		return
	_hover_bob_time += delta
	var wave := sin(_hover_bob_time * HOVER_BOB_FREQ) * HOVER_BOB_AMPLITUDE
	if _shop_hover:
		_shop_wrap.position.y = _shop_rest_y + wave
	if _upgrades_hover:
		_upgrades_wrap.position.y = _upgrades_rest_y + wave


func _on_shop_mouse_entered() -> void:
	_shop_hover = true
	_apply_wrap_panel_style(_shop_wrap, true)
	set_process(true)


func _on_shop_mouse_exited() -> void:
	_shop_hover = false
	_shop_wrap.position.y = _shop_rest_y
	_apply_wrap_panel_style(_shop_wrap, false, shop_button.button_pressed)
	_update_hover_process()


func _on_upgrades_mouse_entered() -> void:
	_upgrades_hover = true
	_apply_wrap_panel_style(_upgrades_wrap, true)
	set_process(true)


func _on_upgrades_mouse_exited() -> void:
	_upgrades_hover = false
	_upgrades_wrap.position.y = _upgrades_rest_y
	_apply_wrap_panel_style(_upgrades_wrap, false, upgrades_button.button_pressed)
	_update_hover_process()


func _update_hover_process() -> void:
	var any_hover := _shop_hover or _upgrades_hover
	set_process(any_hover)
	if not any_hover:
		_hover_bob_time = 0.0


func _on_shop_pressed() -> void:
	if _shop_panel == null:
		return
	if not GameState.shop_unlocked:
		if not GameState.try_unlock_shop():
			return
		_refresh_shop_lock_state()
	_close_upgrade_panel()
	if _shop_panel.has_method("toggle"):
		_shop_panel.toggle()
		_shop_open = _shop_panel.is_open() if _shop_panel.has_method("is_open") else not _shop_open
	else:
		_shop_open = not _shop_open
		_shop_panel.visible = _shop_open
	set_shop_open(_shop_open)
	shop_toggled.emit(_shop_open)


func set_shop_open(is_open: bool) -> void:
	_shop_open = is_open
	shop_button.button_pressed = is_open
	if _shop_glyph:
		_shop_glyph.highlighted = is_open
	_apply_wrap_panel_style(_shop_wrap, _shop_hover, is_open)


func _on_upgrades_pressed() -> void:
	if _upgrade_panel == null:
		return
	if not GameState.upgrades_unlocked:
		if not GameState.try_unlock_upgrades():
			return
		_refresh_upgrades_lock_state()
	_close_shop_panel()
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


func _wrap_outer_size() -> Vector2i:
	return Vector2i(
		ICON_SIZE.x + WRAP_MARGIN_H * 2 + PANEL_BORDER * 2,
		ICON_SIZE.y + WRAP_MARGIN_V * 2 + PANEL_BORDER * 2
	)


func _layout_top_right_corner() -> void:
	var top_right: Control = $TopRight
	var outer := Vector2(_wrap_outer_size())
	var button_count := 2 if GameState.is_shop_visible() else 1
	var row_width := outer.x * button_count + CORNER_GAP * maxi(button_count - 1, 0)
	top_right.offset_left = -MARGIN - row_width
	top_right.offset_top = MARGIN
	top_right.offset_right = -MARGIN
	top_right.offset_bottom = MARGIN + outer.y
	_shop_wrap.custom_minimum_size = outer
	_upgrades_wrap.custom_minimum_size = outer


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


func _style_shop_wrap() -> void:
	_apply_wrap_panel_style(_shop_wrap)


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


func _style_shop_button() -> void:
	_style_icon_button(shop_button)


func _style_upgrades_button() -> void:
	_style_icon_button(upgrades_button)


func _close_upgrade_panel() -> void:
	if _upgrade_panel and _upgrade_panel.has_method("is_open") and _upgrade_panel.is_open():
		_upgrade_panel.close()


func _close_shop_panel() -> void:
	if _shop_panel and _shop_panel.has_method("is_open") and _shop_panel.is_open():
		_shop_panel.close()
