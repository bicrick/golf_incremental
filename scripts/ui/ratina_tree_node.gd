extends PanelContainer
## Ratina upgrade tree node — mirrors upgrade_tree_node for Ratina's tree.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")

signal purchase_requested(upgrade_id: String)

enum NodeState { LOCKED, UNAFFORDABLE, PURCHASABLE, MAXED }

const TooltipText := preload("res://scripts/ui/upgrade_tooltip_text.gd")
const TooltipViewportClampScript = preload("res://scripts/ui/tooltip_viewport_clamp.gd")

const NODE_SIZE := UpgradeIcon.DEFAULT_NODE_SIZE
const TOOLTIP_DELAY_SEC := 0.08
const TOOLTIP_MAX_WIDTH := 150
const TOOLTIP_GAP := 5
const TOOLTIP_EDGE_MARGIN := 8.0

const TOOLTIP_BG := Color(0.08, 0.11, 0.06, 0.96)
const TOOLTIP_BORDER := Color(0.78, 0.66, 0.28, 1)
const TOOLTIP_NAME := Color(1.0, 0.9, 0.45, 1)
const TOOLTIP_DESC := Color(0.82, 0.78, 0.66, 1)
const TOOLTIP_LEVEL := Color(0.62, 0.72, 0.52, 1)
const TOOLTIP_PRICE := Color(1.0, 0.9, 0.45, 1)
const TOOLTIP_PRICE_DIM := Color(0.72, 0.62, 0.52, 1)
const MODULATE_LOCKED := Color(0.42, 0.4, 0.38, 0.72)
const MODULATE_UNAFFORDABLE := Color(0.58, 0.55, 0.5, 0.82)
const MODULATE_MAXED := Color(1.0, 0.92, 0.62, 1.0)

var upgrade_id: String = ""
var _branch: int = Balance.UpgradeBranch.BASE_PAY

var _state: NodeState = NodeState.LOCKED
var _hovering := false
var _panel_style: StyleBoxFlat
var _tooltip_def: Dictionary = {}
var _tooltip_level := 0
var _tooltip_cost := 0.0
var _tooltip_maxed := false
var _tooltip_unlocked := false
var _tooltip_affordable := false
var _preview_provider := Callable(RatinaUpgradeEffects, "preview_stats")

@onready var _button: Button = $HitButton
@onready var _glow: ColorRect = $GlowOverlay
@onready var _border: Control = $BorderOverlay
@onready var _shape_icon: TextureRect = $ShapeIcon
@onready var _tooltip_panel: PanelContainer = $TooltipPanel
@onready var _tooltip_name: Label = $TooltipPanel/Margin/VBox/NameLabel
@onready var _tooltip_desc: Label = $TooltipPanel/Margin/VBox/DescLabel
@onready var _tooltip_level_label: Label = $TooltipPanel/Margin/VBox/LevelLabel
@onready var _tooltip_price_label: Label = $TooltipPanel/Margin/VBox/PriceLabel
@onready var _tooltip_timer: Timer = $TooltipTimer


func _ready() -> void:
	custom_minimum_size = NODE_SIZE
	size = NODE_SIZE
	_button.pressed.connect(_on_pressed)
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.tooltip_text = ""
	PixelFont.apply_label(_tooltip_name, 7)
	PixelFont.apply_label(_tooltip_desc, 6)
	PixelFont.apply_label(_tooltip_level_label, 6)
	PixelFont.apply_label(_tooltip_price_label, 6)
	_ensure_panel_style()
	_tooltip_panel.top_level = true
	_tooltip_panel.z_index = 20
	_tooltip_timer.wait_time = TOOLTIP_DELAY_SEC
	_tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	_style_tooltip_panel()


func setup(def: Dictionary, _namespace: String = UpgradeGraph.NAMESPACE_RATINA) -> void:
	upgrade_id = def["id"]
	_branch = int(def.get("branch", Balance.UpgradeBranch.BASE_PAY))
	UpgradeIcon.configure(_shape_icon, upgrade_id, NODE_SIZE)
	refresh()


func refresh() -> void:
	if upgrade_id.is_empty():
		return
	var def := RatinaUpgradeDefinitions.get_def(upgrade_id)
	if def.is_empty():
		return

	var level := GameState.get_ratina_upgrade_level(upgrade_id)
	var max_level := int(def["max_level"])
	var unlocked := UpgradeGraph.is_unlocked(upgrade_id)
	var cost := UpgradeGraph.cost(upgrade_id)
	var maxed := level >= max_level
	var affordable := unlocked and not maxed and GameState.currency >= cost

	if maxed:
		_state = NodeState.MAXED
	elif not unlocked:
		_state = NodeState.LOCKED
	elif affordable:
		_state = NodeState.PURCHASABLE
	else:
		_state = NodeState.UNAFFORDABLE

	_tooltip_def = def
	_tooltip_level = level
	_tooltip_cost = cost
	_tooltip_maxed = maxed
	_tooltip_unlocked = unlocked
	_tooltip_affordable = affordable

	_apply_visual_state()
	_button.disabled = _state == NodeState.LOCKED or _state == NodeState.MAXED
	if _tooltip_panel.visible:
		_update_tooltip_content()
		_position_tooltip()


func get_center() -> Vector2:
	return position + size * 0.5


func _on_mouse_entered() -> void:
	_hovering = true
	_tooltip_timer.start()


func _on_mouse_exited() -> void:
	_hovering = false
	_tooltip_timer.stop()
	_hide_tooltip()


func _on_tooltip_timer_timeout() -> void:
	if _hovering:
		_show_tooltip()


func _on_pressed() -> void:
	if upgrade_id.is_empty():
		return
	purchase_requested.emit(upgrade_id)


func _update_tooltip_content() -> void:
	_tooltip_name.text = _tooltip_def.get("display_name", "")
	var desc: String = _tooltip_def.get("description", "")
	var preview: String = TooltipText.effect_preview(
		_tooltip_def,
		_tooltip_level,
		GameState.ratina_upgrade_levels,
		_tooltip_maxed,
		_preview_provider
	)
	if not preview.is_empty():
		desc = "%s\n%s" % [desc, preview]
	_tooltip_desc.text = desc
	var max_level := int(_tooltip_def.get("max_level", 0))
	if _tooltip_maxed:
		_tooltip_level_label.text = "Lv %d/%d  MAX" % [_tooltip_level, max_level]
		_tooltip_price_label.visible = false
	elif not _tooltip_unlocked:
		var hint := UpgradeGraph.lock_hint(upgrade_id)
		_tooltip_level_label.text = hint if not hint.is_empty() else "Locked"
		_tooltip_price_label.visible = false
	else:
		_tooltip_level_label.text = "Lv %d/%d" % [_tooltip_level, max_level]
		_tooltip_price_label.visible = true
		if _tooltip_affordable:
			_tooltip_price_label.text = "Cost: $%s" % _format_cost(_tooltip_cost)
			_tooltip_price_label.add_theme_color_override(&"font_color", TOOLTIP_PRICE)
		else:
			_tooltip_price_label.text = "Need: $%s" % _format_cost(_tooltip_cost)
			_tooltip_price_label.add_theme_color_override(&"font_color", TOOLTIP_PRICE_DIM)


func _position_tooltip() -> void:
	var tip_size: Vector2 = _tooltip_panel.get_combined_minimum_size()
	tip_size.x = clampf(tip_size.x, 72.0, TOOLTIP_MAX_WIDTH)
	_tooltip_panel.custom_minimum_size = tip_size
	_tooltip_panel.size = tip_size

	var bounds: Rect2 = TooltipViewportClampScript.visible_bounds(self)
	var y: float = (NODE_SIZE.y - tip_size.y) * 0.5
	var x_right: float = NODE_SIZE.x + TOOLTIP_GAP
	var x_left: float = -tip_size.x - TOOLTIP_GAP

	var right_global := global_position + Vector2(x_right, y)
	var right_fits := (
		right_global.x >= bounds.position.x + TOOLTIP_EDGE_MARGIN
		and right_global.x + tip_size.x <= bounds.end.x - TOOLTIP_EDGE_MARGIN
	)

	var x: float = x_right
	if not right_fits:
		var left_global := global_position + Vector2(x_left, y)
		var left_fits := (
			left_global.x >= bounds.position.x + TOOLTIP_EDGE_MARGIN
			and left_global.x + tip_size.x <= bounds.end.x - TOOLTIP_EDGE_MARGIN
		)
		if left_fits:
			x = x_left
		else:
			x = x_left if global_position.x > bounds.position.x + bounds.size.x * 0.5 else x_right

	var global_pos := global_position + Vector2(x, y)
	global_pos = TooltipViewportClampScript.clamp_pos(global_pos, tip_size, bounds, TOOLTIP_EDGE_MARGIN)
	_tooltip_panel.global_position = global_pos
	custom_minimum_size = NODE_SIZE
	size = NODE_SIZE


func _tooltip_bounds_rect() -> Rect2:
	return TooltipViewportClampScript.visible_bounds(self)


func _apply_visual_state() -> void:
	_glow.visible = false
	set_process(false)

	match _state:
		NodeState.PURCHASABLE:
			modulate = Color.WHITE
			_shape_icon.modulate = Color.WHITE
			_configure_border(UpgradeTreeStroke.BorderState.AFFORD, true, true)
		NodeState.MAXED:
			modulate = MODULATE_MAXED
			_shape_icon.modulate = MODULATE_MAXED
			_configure_border(UpgradeTreeStroke.BorderState.MAXED, false, true)
		NodeState.LOCKED:
			modulate = MODULATE_LOCKED
			_shape_icon.modulate = MODULATE_LOCKED
			_configure_border(UpgradeTreeStroke.BorderState.LOCKED, false, false)
		NodeState.UNAFFORDABLE:
			modulate = MODULATE_UNAFFORDABLE
			_shape_icon.modulate = MODULATE_UNAFFORDABLE
			_configure_border(UpgradeTreeStroke.BorderState.DEFAULT, false, false)


func _style_tooltip_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TOOLTIP_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = TOOLTIP_BORDER
	_tooltip_panel.add_theme_stylebox_override(&"panel", style)
	_tooltip_name.add_theme_color_override(&"font_color", TOOLTIP_NAME)
	_tooltip_desc.add_theme_color_override(&"font_color", TOOLTIP_DESC)
	_tooltip_level_label.add_theme_color_override(&"font_color", TOOLTIP_LEVEL)
	_tooltip_price_label.add_theme_color_override(&"font_color", TOOLTIP_PRICE)


func _show_tooltip() -> void:
	if not _hovering or _tooltip_def.is_empty():
		return
	_update_tooltip_content()
	_position_tooltip()
	_tooltip_panel.visible = true


func _hide_tooltip() -> void:
	_tooltip_panel.visible = false


func _configure_border(border_state: UpgradeTreeStroke.BorderState, animated: bool, with_glow: bool) -> void:
	if _border and _border.has_method("configure"):
		var border_color := UpgradeTreeStroke.border_color_for_upgrade(upgrade_id, border_state)
		var glow_color := UpgradeTreeStroke.glow_color_for_upgrade(upgrade_id)
		_border.configure(border_color, animated, with_glow, glow_color)


func _ensure_panel_style() -> void:
	if _panel_style != null:
		return
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0, 0, 0, 0)
	_panel_style.border_width_left = 0
	_panel_style.border_width_top = 0
	_panel_style.border_width_right = 0
	_panel_style.border_width_bottom = 0
	_panel_style.corner_radius_top_left = 0
	_panel_style.corner_radius_top_right = 0
	_panel_style.corner_radius_bottom_left = 0
	_panel_style.corner_radius_bottom_right = 0
	_panel_style.content_margin_left = 0
	_panel_style.content_margin_top = 0
	_panel_style.content_margin_right = 0
	_panel_style.content_margin_bottom = 0
	add_theme_stylebox_override(&"panel", _panel_style)


func _format_cost(n: float) -> String:
	return FloatCashText.format_amount(n)
