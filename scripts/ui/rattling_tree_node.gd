extends PanelContainer
## Rattling upgrade tree node — mirrors ratina_tree_node for the Rattling tree.

signal purchase_requested(upgrade_id: String)

enum NodeState { LOCKED, UNAFFORDABLE, PURCHASABLE, MAXED }

const TooltipText := preload("res://scripts/ui/upgrade_tooltip_text.gd")

const NODE_SIZE := Vector2(38, 38)
const FONT_SIZE := 6
const TOOLTIP_DELAY_SEC := 0.08
const TOOLTIP_MAX_WIDTH := 150
const TOOLTIP_GAP := 5
const TOOLTIP_EDGE_MARGIN := 4

const SHORT_NAMES: Dictionary = {
	"rattling_more": "MOR",
	"rattling_speed": "SPD",
	"rattling_payout": "PAY",
	"rattling_quick_paws": "QCK",
	"rattling_keen_nose": "NOS",
}

const COLOR_BG := Color(0.14, 0.17, 0.11, 0.92)
const COLOR_BORDER := Color(0.42, 0.52, 0.28, 1)
const COLOR_BORDER_AFFORD := Color(0.78, 0.92, 0.35, 1)
const COLOR_BORDER_GLOW := Color(0.86, 1.0, 0.45, 1)
const COLOR_BORDER_LOCKED := Color(0.32, 0.35, 0.28, 0.8)
const COLOR_BORDER_MAXED := Color(0.68, 0.82, 0.28, 1)
const COLOR_GLOW := Color(0.86, 1.0, 0.25, 1.0)
const COLOR_TEXT_DIM := Color(0.5, 0.55, 0.42, 1)
const COLOR_TEXT_GOLD := Color(0.86, 1.0, 0.45, 1)
const TOOLTIP_BG := Color(0.08, 0.11, 0.06, 0.96)
const TOOLTIP_BORDER := Color(0.66, 0.78, 0.28, 1)
const TOOLTIP_NAME := Color(0.86, 1.0, 0.45, 1)
const TOOLTIP_DESC := Color(0.82, 0.86, 0.66, 1)
const TOOLTIP_LEVEL := Color(0.62, 0.72, 0.52, 1)
const TOOLTIP_PRICE := Color(0.86, 1.0, 0.45, 1)
const TOOLTIP_PRICE_DIM := Color(0.62, 0.72, 0.52, 1)
const MODULATE_LOCKED := Color(0.42, 0.4, 0.38, 0.72)
const MODULATE_UNAFFORDABLE := Color(0.58, 0.55, 0.5, 0.82)
const MODULATE_MAXED := Color(0.92, 1.0, 0.62, 1.0)

var upgrade_id: String = ""

var _state: NodeState = NodeState.LOCKED
var _hovering := false
var _glow_phase := 0.0
var _base_footer_text := ""
var _tooltip_def: Dictionary = {}
var _tooltip_level := 0
var _tooltip_cost := 0.0
var _tooltip_maxed := false
var _tooltip_unlocked := false
var _tooltip_affordable := false
var _preview_provider := Callable(RattlingUpgradeEffects, "preview_stats")

@onready var _button: Button = $HitButton
@onready var _glow: ColorRect = $GlowOverlay
@onready var _shape_icon: Control = $ShapeIcon
@onready var _footer_label: Label = $FooterLabel
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
	PixelFont.apply_label(_footer_label, FONT_SIZE)
	PixelFont.apply_label(_tooltip_name, 7)
	PixelFont.apply_label(_tooltip_desc, 6)
	PixelFont.apply_label(_tooltip_level_label, 6)
	PixelFont.apply_label(_tooltip_price_label, 6)
	_style_panel(COLOR_BORDER, 1)
	_tooltip_timer.wait_time = TOOLTIP_DELAY_SEC
	_tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	_style_tooltip_panel()


func setup(def: Dictionary) -> void:
	upgrade_id = def["id"]
	if _shape_icon:
		_shape_icon.branch = int(def.get("branch", Balance.UpgradeBranch.BASE_PAY))
		_shape_icon.queue_redraw()
	refresh()


func refresh() -> void:
	if upgrade_id.is_empty():
		return
	var def := RattlingUpgradeDefinitions.get_def(upgrade_id)
	if def.is_empty():
		return

	var level := GameState.get_rattling_upgrade_level(upgrade_id)
	var max_level := int(def["max_level"])
	var unlocked := RattlingUpgradeDefinitions.is_unlocked(upgrade_id, GameState.rattling_upgrade_levels)
	var cost := GameState.get_rattling_upgrade_cost(upgrade_id)
	var maxed := level >= max_level
	var affordable := unlocked and not maxed and GameState.currency >= cost
	var short_name: String = SHORT_NAMES.get(upgrade_id, def["display_name"].substr(0, 3))

	if maxed:
		_state = NodeState.MAXED
	elif not unlocked:
		_state = NodeState.LOCKED
	elif affordable:
		_state = NodeState.PURCHASABLE
	else:
		_state = NodeState.UNAFFORDABLE

	_base_footer_text = _footer_text(def, level, maxed, unlocked, short_name)

	_tooltip_def = def
	_tooltip_level = level
	_tooltip_cost = cost
	_tooltip_maxed = maxed
	_tooltip_unlocked = unlocked
	_tooltip_affordable = affordable

	_apply_visual_state()
	_footer_label.text = _base_footer_text
	_button.disabled = _state == NodeState.LOCKED or _state == NodeState.MAXED
	if _tooltip_panel.visible:
		_update_tooltip_content()
		_position_tooltip()


func _process(delta: float) -> void:
	if _state != NodeState.PURCHASABLE:
		return
	_glow_phase += delta * 4.0
	var pulse := 0.5 + 0.5 * sin(_glow_phase)
	_glow.color = Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, lerpf(0.06, 0.2, pulse))
	var border_color := COLOR_BORDER_AFFORD.lerp(COLOR_BORDER_GLOW, pulse)
	_style_panel(border_color, 2 if pulse > 0.65 else 1)


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


func _footer_text(def: Dictionary, level: int, maxed: bool, unlocked: bool, short_name: String) -> String:
	if not unlocked and level <= 0:
		return short_name
	var compact: String = TooltipText.compact_stat(
		def, level, GameState.rattling_upgrade_levels, _preview_provider
	)
	if maxed:
		return "MAX" if compact.is_empty() else "MAX·%s" % compact
	if level <= 0:
		return short_name
	if compact.is_empty():
		return "L%d" % level
	return "L%d·%s" % [level, compact]


func _update_tooltip_content() -> void:
	_tooltip_name.text = _tooltip_def.get("display_name", "")
	var desc: String = _tooltip_def.get("description", "")
	var preview: String = TooltipText.effect_preview(
		_tooltip_def,
		_tooltip_level,
		GameState.rattling_upgrade_levels,
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
		var hint := RattlingUpgradeDefinitions.lock_hint(upgrade_id, GameState.rattling_upgrade_levels)
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

	var bounds: Rect2 = _tooltip_bounds_rect()
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
	global_pos.y = clampf(
		global_pos.y,
		bounds.position.y + TOOLTIP_EDGE_MARGIN,
		bounds.end.y - tip_size.y - TOOLTIP_EDGE_MARGIN
	)
	global_pos.x = clampf(
		global_pos.x,
		bounds.position.x + TOOLTIP_EDGE_MARGIN,
		bounds.end.x - tip_size.x - TOOLTIP_EDGE_MARGIN
	)
	_tooltip_panel.position = global_pos - global_position


func _tooltip_bounds_rect() -> Rect2:
	var current: Node = self
	while current:
		if current.name in ["TreeCanvas", "RatinaTreeCanvas", "RattlingTreeCanvas"] and current is Control:
			return (current as Control).get_global_rect()
		current = current.get_parent()
	return get_viewport().get_visible_rect()


func _apply_visual_state() -> void:
	_glow.visible = _state == NodeState.PURCHASABLE
	set_process(_state == NodeState.PURCHASABLE)

	match _state:
		NodeState.PURCHASABLE:
			modulate = Color.WHITE
			_shape_icon.modulate = Color.WHITE
			_footer_label.add_theme_color_override(&"font_color", COLOR_TEXT_GOLD)
			_style_panel(COLOR_BORDER_AFFORD, 1)
		NodeState.MAXED:
			_glow.color = Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, 0.0)
			modulate = MODULATE_MAXED
			_shape_icon.modulate = MODULATE_MAXED
			_footer_label.add_theme_color_override(&"font_color", COLOR_TEXT_GOLD)
			_style_panel(COLOR_BORDER_MAXED, 1)
		NodeState.LOCKED:
			_glow.color = Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, 0.0)
			modulate = MODULATE_LOCKED
			_shape_icon.modulate = MODULATE_LOCKED
			_footer_label.add_theme_color_override(&"font_color", COLOR_TEXT_DIM)
			_style_panel(COLOR_BORDER_LOCKED, 1)
		NodeState.UNAFFORDABLE:
			_glow.color = Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, 0.0)
			modulate = MODULATE_UNAFFORDABLE
			_shape_icon.modulate = MODULATE_UNAFFORDABLE
			_footer_label.add_theme_color_override(&"font_color", COLOR_TEXT_DIM)
			_style_panel(COLOR_BORDER, 1)


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


func _style_panel(border_color: Color, border_width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 1
	style.content_margin_top = 1
	style.content_margin_right = 1
	style.content_margin_bottom = 1
	add_theme_stylebox_override(&"panel", style)


func _format_cost(n: float) -> String:
	if n >= 1_000_000:
		return "%.0fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.0fK" % (n / 1_000.0)
	return str(int(n))
