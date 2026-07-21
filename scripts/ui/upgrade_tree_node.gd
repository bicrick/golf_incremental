extends PanelContainer
## Compact icon squircle — sprite-first; details in top-level tooltip only.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")
const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")
const PrestigeEffectsScript = preload("res://scripts/game/prestige/effects.gd")
const TooltipText := preload("res://scripts/ui/upgrade_tooltip_text.gd")
const TooltipViewportClampScript = preload("res://scripts/ui/tooltip_viewport_clamp.gd")

signal purchase_requested(upgrade_id: String)

enum NodeState { LOCKED, UNAFFORDABLE, PURCHASABLE, MAXED }

const NODE_SIZE := UpgradeIcon.DEFAULT_NODE_SIZE
const TOOLTIP_DELAY_SEC := 0.08
const TOOLTIP_MAX_WIDTH := 150
const TOOLTIP_GAP := 5
const TOOLTIP_EDGE_MARGIN := 8.0
const TOOLTIP_FADE_SEC := 0.12
const TOOLTIP_SLIDE_PX := 4.0
const HOVER_SCALE := 1.12
const HOVER_TWEEN_SEC := 0.12
const BURST_PEAK_SCALE := 1.2
const BURST_UP_SEC := 0.08
const BURST_DOWN_SEC := 0.14
const REVEAL_TWEEN_SEC := 0.22
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
var _namespace: String = UpgradeGraph.NAMESPACE_PLAYER
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
var _hover_boost := false
var _motion_busy := false
var _base_modulate := Color.WHITE
var _scale_tween: Tween
var _tooltip_tween: Tween
var _burst_tween: Tween
var _reveal_tween: Tween
var _tooltip_rest_global := Vector2.ZERO

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
	pivot_offset = NODE_SIZE * 0.5
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


func setup(def: Dictionary, node_namespace: String = UpgradeGraph.NAMESPACE_PLAYER) -> void:
	upgrade_id = def["id"]
	_namespace = node_namespace
	_branch = int(def.get("branch", Balance.UpgradeBranch.BASE_PAY))
	UpgradeIcon.configure(_shape_icon, upgrade_id, NODE_SIZE)
	refresh()


func refresh() -> void:
	if upgrade_id.is_empty():
		return
	var def: Dictionary = _def_for_node()
	if def.is_empty():
		return

	var level := _level_for_node()
	var max_level := int(def["max_level"])
	var unlocked := _is_unlocked()
	var cost := _cost_for_node()
	var maxed := level >= max_level
	var currency: float = (
		float(GameState.cheese) if _namespace == "prestige" else GameState.currency
	)
	var affordable: bool = unlocked and not maxed and currency >= cost

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


func play_hover_in() -> void:
	if _state == NodeState.LOCKED or _motion_busy:
		return
	_hover_boost = true
	_apply_visual_state()
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * HOVER_SCALE, HOVER_TWEEN_SEC)


func play_hover_out() -> void:
	_hover_boost = false
	if not _motion_busy:
		_apply_visual_state()
	_kill_scale_tween()
	_scale_tween = create_tween()
	_scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, HOVER_TWEEN_SEC)


func play_purchase_burst() -> void:
	_motion_busy = true
	_hover_boost = false
	_kill_scale_tween()
	_kill_burst_tween()
	# Flash border to charged, then settle via refresh-driven state.
	var charged := UpgradeTreeStroke.border_color_for_upgrade(
		upgrade_id, UpgradeTreeStroke.BorderState.AFFORD
	)
	var glow := UpgradeTreeStroke.glow_color_for_upgrade(upgrade_id)
	if _border and _border.has_method("configure"):
		_border.configure(charged, true, true, glow, UpgradeTreeStroke.BORDER_WIDTH_MAXED, 1.8)
	scale = Vector2.ONE
	_burst_tween = create_tween()
	_burst_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_burst_tween.tween_property(self, "scale", Vector2.ONE * BURST_PEAK_SCALE, BURST_UP_SEC)
	_burst_tween.tween_property(self, "scale", Vector2.ONE, BURST_DOWN_SEC).set_trans(Tween.TRANS_QUAD)
	_burst_tween.finished.connect(_on_burst_finished, CONNECT_ONE_SHOT)


func prep_reveal_in() -> void:
	## Hide at zero scale immediately so refresh does not flash a full node.
	_motion_busy = true
	_kill_reveal_tween()
	_kill_scale_tween()
	scale = Vector2.ZERO
	modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, 0.0)


func play_reveal_in() -> void:
	if not _motion_busy or scale != Vector2.ZERO:
		prep_reveal_in()
	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)
	_reveal_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_reveal_tween.tween_property(self, "scale", Vector2.ONE, REVEAL_TWEEN_SEC)
	_reveal_tween.tween_property(self, "modulate", _base_modulate, REVEAL_TWEEN_SEC * 0.85)
	_reveal_tween.finished.connect(_on_reveal_finished, CONNECT_ONE_SHOT)


func _on_burst_finished() -> void:
	_motion_busy = false
	if _hovering and _state != NodeState.LOCKED:
		play_hover_in()
	else:
		scale = Vector2.ONE
		_apply_visual_state()


func _on_reveal_finished() -> void:
	_motion_busy = false
	modulate = _base_modulate
	scale = Vector2.ONE
	if _hovering and _state != NodeState.LOCKED:
		play_hover_in()


func _on_mouse_entered() -> void:
	_hovering = true
	_tooltip_timer.start()
	if _state != NodeState.LOCKED:
		play_hover_in()


func _on_mouse_exited() -> void:
	_hovering = false
	_tooltip_timer.stop()
	_hide_tooltip()
	if not _motion_busy:
		play_hover_out()


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
		_tooltip_def, _tooltip_level, _levels_for_namespace(), _tooltip_maxed, _preview_for_namespace()
	)
	if not preview.is_empty():
		desc = "%s\n%s" % [desc, preview]
	_tooltip_desc.text = desc
	var max_level := int(_tooltip_def.get("max_level", 0))
	if _tooltip_maxed:
		_tooltip_level_label.text = "Lv %d/%d  MAX" % [_tooltip_level, max_level]
		_tooltip_price_label.visible = false
	elif not _tooltip_unlocked:
		var hint := _lock_hint()
		_tooltip_level_label.text = hint if not hint.is_empty() else "Locked"
		_tooltip_price_label.visible = false
	else:
		_tooltip_level_label.text = "Lv %d/%d" % [_tooltip_level, max_level]
		_tooltip_price_label.visible = true
		var currency_mark := "Cheese " if _namespace == "prestige" else "$"
		if _tooltip_affordable:
			_tooltip_price_label.text = "Cost: %s%s" % [currency_mark, _format_cost(_tooltip_cost)]
			_tooltip_price_label.add_theme_color_override(&"font_color", TOOLTIP_PRICE)
		else:
			_tooltip_price_label.text = "Need: %s%s" % [currency_mark, _format_cost(_tooltip_cost)]
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
	_tooltip_rest_global = global_pos
	_tooltip_panel.global_position = global_pos
	# Keep medallion size fixed even if layout reflows.
	custom_minimum_size = NODE_SIZE
	size = NODE_SIZE
	pivot_offset = NODE_SIZE * 0.5


func _tooltip_bounds_rect() -> Rect2:
	return TooltipViewportClampScript.visible_bounds(self)


func _apply_visual_state() -> void:
	# Soft fill comes from squircle draw; ColorRect glow stays off.
	_glow.visible = false
	set_process(false)

	match _state:
		NodeState.PURCHASABLE:
			_base_modulate = Color.WHITE
			_shape_icon.modulate = Color.WHITE
			_configure_border(
				UpgradeTreeStroke.BorderState.AFFORD,
				true,
				true,
				UpgradeTreeStroke.BORDER_WIDTH,
				1.35 if _hover_boost else 1.0
			)
		NodeState.MAXED:
			_base_modulate = MODULATE_MAXED
			_shape_icon.modulate = MODULATE_MAXED
			_configure_border(
				UpgradeTreeStroke.BorderState.MAXED,
				false,
				true,
				UpgradeTreeStroke.BORDER_WIDTH_MAXED,
				1.0
			)
		NodeState.LOCKED:
			_base_modulate = MODULATE_LOCKED
			_shape_icon.modulate = MODULATE_LOCKED
			_configure_border(UpgradeTreeStroke.BorderState.LOCKED, false, false)
		NodeState.UNAFFORDABLE:
			_base_modulate = MODULATE_UNAFFORDABLE
			_shape_icon.modulate = MODULATE_UNAFFORDABLE
			_configure_border(UpgradeTreeStroke.BorderState.DEFAULT, false, false)

	if _hover_boost and _state != NodeState.LOCKED:
		var charged := UpgradeTreeStroke.border_color_for_upgrade(
			upgrade_id, UpgradeTreeStroke.BorderState.AFFORD
		)
		var glow := UpgradeTreeStroke.glow_color_for_upgrade(upgrade_id)
		var width := (
			UpgradeTreeStroke.BORDER_WIDTH_MAXED
			if _state == NodeState.MAXED
			else UpgradeTreeStroke.BORDER_WIDTH
		)
		if _border and _border.has_method("configure"):
			_border.configure(
				charged,
				_state == NodeState.PURCHASABLE,
				true,
				glow,
				width,
				1.6 if _state == NodeState.PURCHASABLE else 1.0
			)

	if not _motion_busy:
		modulate = _base_modulate


func _style_tooltip_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TOOLTIP_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = TOOLTIP_BORDER
	style.shadow_size = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
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
	_kill_tooltip_tween()
	_tooltip_panel.visible = true
	_tooltip_panel.modulate = Color(1, 1, 1, 0)
	_tooltip_panel.global_position = _tooltip_rest_global + Vector2(0, TOOLTIP_SLIDE_PX)
	_tooltip_tween = create_tween()
	_tooltip_tween.set_parallel(true)
	_tooltip_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tooltip_tween.tween_property(_tooltip_panel, "modulate:a", 1.0, TOOLTIP_FADE_SEC)
	_tooltip_tween.tween_property(
		_tooltip_panel, "global_position", _tooltip_rest_global, TOOLTIP_FADE_SEC
	)


func _hide_tooltip() -> void:
	_kill_tooltip_tween()
	_tooltip_panel.visible = false
	_tooltip_panel.modulate = Color.WHITE


func _configure_border(
	border_state: UpgradeTreeStroke.BorderState,
	animated: bool,
	with_glow: bool,
	width: float = UpgradeTreeStroke.BORDER_WIDTH,
	pulse_speed_mult: float = 1.0
) -> void:
	if _border and _border.has_method("configure"):
		var border_color := UpgradeTreeStroke.border_color_for_upgrade(upgrade_id, border_state)
		var glow_color := UpgradeTreeStroke.glow_color_for_upgrade(upgrade_id)
		_border.configure(border_color, animated, with_glow, glow_color, width, pulse_speed_mult)


func _ensure_panel_style() -> void:
	if _panel_style != null:
		return
	_panel_style = StyleBoxFlat.new()
	# Fill comes from the squircle medallion draw; panel chrome stays transparent.
	_panel_style.bg_color = Color(0, 0, 0, 0)
	_panel_style.border_width_left = 0
	_panel_style.border_width_top = 0
	_panel_style.border_width_right = 0
	_panel_style.border_width_bottom = 0
	var corner := int(round(UpgradeTreeStroke.squircle_corner_radius(NODE_SIZE)))
	_panel_style.corner_radius_top_left = corner
	_panel_style.corner_radius_top_right = corner
	_panel_style.corner_radius_bottom_left = corner
	_panel_style.corner_radius_bottom_right = corner
	_panel_style.content_margin_left = 0
	_panel_style.content_margin_top = 0
	_panel_style.content_margin_right = 0
	_panel_style.content_margin_bottom = 0
	add_theme_stylebox_override(&"panel", _panel_style)


func _kill_scale_tween() -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = null


func _kill_tooltip_tween() -> void:
	if _tooltip_tween != null and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip_tween = null


func _kill_burst_tween() -> void:
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = null


func _kill_reveal_tween() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


func _def_for_node() -> Dictionary:
	if _namespace == "prestige":
		return PrestigeDefinitionsScript.get_def(upgrade_id)
	return UpgradeGraph.get_def(upgrade_id)


func _level_for_node() -> int:
	if _namespace == "prestige":
		return GameState.get_prestige_upgrade_level(upgrade_id)
	return UpgradeGraph.level(upgrade_id)


func _cost_for_node() -> float:
	if _namespace == "prestige":
		return GameState.get_prestige_upgrade_cost(upgrade_id)
	return UpgradeGraph.cost(upgrade_id)


func _is_unlocked() -> bool:
	if _namespace == "prestige":
		return PrestigeDefinitionsScript.is_unlocked(upgrade_id, GameState.prestige_levels)
	return UpgradeGraph.is_unlocked(upgrade_id)


func _lock_hint() -> String:
	if _namespace == "prestige":
		return PrestigeDefinitionsScript.lock_hint(upgrade_id, GameState.prestige_levels)
	return UpgradeGraph.lock_hint(upgrade_id)


func _levels_for_namespace() -> Dictionary:
	match _namespace:
		UpgradeGraph.NAMESPACE_SHOP:
			return GameState.shop_levels
		"prestige":
			return GameState.prestige_levels
		_:
			return GameState.upgrade_levels


func _preview_for_namespace() -> Callable:
	if _namespace == UpgradeGraph.NAMESPACE_SHOP:
		return Callable(ShopEffects, "preview_stats")
	if _namespace == "prestige":
		return Callable(PrestigeEffectsScript, "preview_stats")
	return Callable(UpgradeEffects, "preview_stats")


func _format_cost(n: float) -> String:
	if _namespace == "prestige":
		return "%d" % int(floor(n))
	return FloatCashText.format_amount(n)
