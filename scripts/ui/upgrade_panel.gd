extends Control
## Full-screen upgrade tree view — cloud sky background, progressive node reveal.

const NODE_SCENE := preload("res://scenes/ui/upgrade_tree_node.tscn")
const RATINA_NODE_SCENE := preload("res://scenes/ui/ratina_tree_node.tscn")

const COLOR_LINE := Color(0.55, 0.48, 0.32, 0.85)
const COLOR_LINE_LOCKED := Color(0.35, 0.32, 0.28, 0.5)

@onready var connectors: Control = $Content/TreeCanvas/Connectors
@onready var nodes_root: Control = $Content/TreeCanvas/Nodes
@onready var tree_canvas: Control = $Content/TreeCanvas
@onready var ratina_placeholder: Control = $Content/RatinaPlaceholder
@onready var ratina_tree_canvas: Control = $Content/RatinaPlaceholder/RatinaTreeCanvas
@onready var ratina_connectors: Control = $Content/RatinaPlaceholder/RatinaTreeCanvas/Connectors
@onready var ratina_nodes_root: Control = $Content/RatinaPlaceholder/RatinaTreeCanvas/Nodes
@onready var ratina_stats_label: Label = $Content/RatinaPlaceholder/StatsLabel
@onready var title_label: Label = $Content/Header/Title
@onready var currency_label: Label = $Content/Header/CurrencyLabel
@onready var back_button: Button = $Content/Header/BackButton
@onready var tab_upgrades: Button = $Content/Header/TabRow/UpgradesTab
@onready var tab_ratina: Button = $Content/Header/TabRow/RatinaTab

var _is_open := false
var _active_tab := "upgrades"
var _nodes: Dictionary = {}
var _ratina_nodes: Dictionary = {}


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	tab_upgrades.pressed.connect(_on_upgrades_tab_pressed)
	tab_ratina.pressed.connect(_on_ratina_tab_pressed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.ratina_upgrade_purchased.connect(_on_ratina_upgrade_purchased)
	_apply_fonts()
	_style_back_button()
	_style_tabs()
	_build_tree()
	_build_ratina_tree()
	_refresh_all()


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_close_other_panels()
	_is_open = true
	visible = true
	_refresh_all()
	_notify_icon_bar(true)
	EventBus.ui_panel_toggled.emit("upgrades", true)


func close() -> void:
	_is_open = false
	visible = false
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("upgrades", false)


func _notify_icon_bar(is_open: bool) -> void:
	var icon_bar := get_parent().get_node_or_null("IconBar")
	if icon_bar and icon_bar.has_method("set_upgrades_open"):
		icon_bar.set_upgrades_open(is_open)


func _close_other_panels() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var settings_panel := main.get_node_or_null("SettingsLayer/SettingsPanel")
	if settings_panel and settings_panel.has_method("is_open") and settings_panel.is_open():
		settings_panel.close()
	var shop_panel := get_parent().get_node_or_null("ShopPanel")
	if shop_panel and shop_panel.has_method("is_open") and shop_panel.is_open():
		shop_panel.close()


func _on_upgrades_tab_pressed() -> void:
	_active_tab = "upgrades"
	_refresh_tab_visibility()


func _on_ratina_tab_pressed() -> void:
	if not GameState.ratina_unlocked:
		return
	_active_tab = "ratina"
	_refresh_tab_visibility()


func _refresh_tab_visibility() -> void:
	var show_ratina_tab := GameState.ratina_unlocked
	tab_ratina.visible = show_ratina_tab
	tree_canvas.visible = _active_tab == "upgrades"
	ratina_placeholder.visible = _active_tab == "ratina" and show_ratina_tab
	title_label.text = "Upgrade Tree" if _active_tab == "upgrades" else "Ratina"
	tab_upgrades.button_pressed = _active_tab == "upgrades"
	tab_ratina.button_pressed = _active_tab == "ratina"
	if _active_tab == "ratina" and not show_ratina_tab:
		_active_tab = "upgrades"
		tree_canvas.visible = true
		ratina_placeholder.visible = false
		title_label.text = "Upgrade Tree"
	_refresh_ratina_stats_label()


func _build_ratina_tree() -> void:
	for child in ratina_nodes_root.get_children():
		child.queue_free()
	_ratina_nodes.clear()
	for def in RatinaUpgradeDefinitions.all():
		var node: PanelContainer = RATINA_NODE_SCENE.instantiate()
		ratina_nodes_root.add_child(node)
		node.setup(def)
		node.position = def["tree_pos"]
		node.purchase_requested.connect(_on_ratina_purchase_requested)
		_ratina_nodes[def["id"]] = node
	ratina_connectors.draw.connect(_draw_ratina_connectors)


func _is_ratina_node_revealed(id: String) -> bool:
	var def := RatinaUpgradeDefinitions.get_def(id)
	if def.is_empty():
		return false
	if def.get("parent_id", "").is_empty():
		return true
	return RatinaUpgradeDefinitions.is_unlocked(id, GameState.ratina_upgrade_levels)


func _refresh_ratina_tree() -> void:
	_refresh_ratina_stats_label()
	for id in _ratina_nodes:
		var node: PanelContainer = _ratina_nodes[id]
		var revealed := _is_ratina_node_revealed(id)
		node.visible = revealed
		if revealed:
			node.refresh()
	ratina_connectors.queue_redraw()


func _refresh_ratina_stats_label() -> void:
	if ratina_stats_label == null:
		return
	var interval_sec := GameState.ratina_stats.swing_cooldown_ms / 1000.0
	var sample_payout := Economy.resolve_pickup_ball_payout(
		4, GameState.ratina_stats.base_yards, 1, GameState.ratina_stats
	)
	ratina_stats_label.text = "Hits every %.1fs · ~$%.2f/hit" % [interval_sec, sample_payout]


func _on_ratina_purchase_requested(id: String) -> void:
	if not GameState.purchase_ratina_upgrade(id):
		return
	_refresh_ratina_tree()
	currency_label.text = "$%s" % _format_currency(GameState.currency)


func _on_ratina_upgrade_purchased(_id: String, _level: int) -> void:
	if _is_open and _active_tab == "ratina":
		_refresh_ratina_tree()


func _draw_ratina_connectors() -> void:
	for link in RatinaUpgradeDefinitions.connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if not _ratina_nodes.has(from_id) or not _ratina_nodes.has(to_id):
			continue
		if not _is_ratina_node_revealed(from_id) or not _is_ratina_node_revealed(to_id):
			continue
		var from_node: PanelContainer = _ratina_nodes[from_id]
		var to_node: PanelContainer = _ratina_nodes[to_id]
		var from_point: Vector2 = _connection_point(from_node, to_node.get_center())
		var to_point: Vector2 = _connection_point(to_node, from_node.get_center())
		var unlocked := RatinaUpgradeDefinitions.is_unlocked(to_id, GameState.ratina_upgrade_levels)
		var color := COLOR_LINE if unlocked else COLOR_LINE_LOCKED
		_draw_organic_connector_on(ratina_connectors, from_point, to_point, color)


func _build_tree() -> void:
	for child in nodes_root.get_children():
		child.queue_free()
	_nodes.clear()
	for def in UpgradeDefinitions.all():
		var node: PanelContainer = NODE_SCENE.instantiate()
		nodes_root.add_child(node)
		node.setup(def)
		node.position = def["tree_pos"]
		node.purchase_requested.connect(_on_purchase_requested)
		_nodes[def["id"]] = node
	connectors.draw.connect(_draw_connectors)


func _is_node_revealed(id: String) -> bool:
	var def := UpgradeDefinitions.get_def(id)
	if def.is_empty():
		return false
	if def.get("parent_id", "").is_empty():
		return true
	return UpgradeDefinitions.is_unlocked(id, GameState.upgrade_levels)


func _refresh_all() -> void:
	currency_label.text = "$%s" % _format_currency(GameState.currency)
	_refresh_tab_visibility()
	for id in _nodes:
		var node: PanelContainer = _nodes[id]
		var revealed := _is_node_revealed(id)
		node.visible = revealed
		if revealed:
			node.refresh()
	connectors.queue_redraw()
	_refresh_ratina_tree()


func _on_purchase_requested(id: String) -> void:
	if not GameState.purchase_upgrade(id):
		return
	_refresh_all()


func _on_stats_changed(_stats: PlayerStats, currency: float) -> void:
	if not _is_open:
		return
	currency_label.text = "$%s" % _format_currency(currency)
	_refresh_tab_visibility()
	for id in _nodes:
		var node: PanelContainer = _nodes[id]
		if not node.visible:
			continue
		node.refresh()
	connectors.queue_redraw()
	if _active_tab == "ratina":
		_refresh_ratina_tree()


func _on_upgrade_purchased(_id: String, _level: int, _branch: int) -> void:
	if _is_open:
		_refresh_all()


func _draw_connectors() -> void:
	for link in UpgradeDefinitions.connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if not _nodes.has(from_id) or not _nodes.has(to_id):
			continue
		if not _is_node_revealed(from_id) or not _is_node_revealed(to_id):
			continue
		var from_node: PanelContainer = _nodes[from_id]
		var to_node: PanelContainer = _nodes[to_id]
		var from_point: Vector2 = _connection_point(from_node, to_node.get_center())
		var to_point: Vector2 = _connection_point(to_node, from_node.get_center())
		var unlocked := UpgradeDefinitions.is_unlocked(to_id, GameState.upgrade_levels)
		var color := COLOR_LINE if unlocked else COLOR_LINE_LOCKED
		_draw_organic_connector_on(connectors, from_point, to_point, color)


func _draw_organic_connector_on(canvas: Control, from: Vector2, to: Vector2, color: Color) -> void:
	var delta: Vector2 = to - from
	var dist: float = delta.length()
	if dist < 1.0:
		return
	var dir: Vector2 = delta / dist
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var bend_strength: float = clampf(absf(delta.x) * 0.12 + dist * 0.05, 6.0, 16.0)
	var sign: float = 1.0 if delta.x >= 0.0 else -1.0
	if absf(delta.x) < 24.0:
		sign = 1.0 if delta.y > 0.0 else -1.0
	var elbow: Vector2 = from + delta * 0.42 + perp * bend_strength * sign
	var points := PackedVector2Array([from, elbow, to])
	canvas.draw_polyline(points, color, 1.5, true)


func _draw_organic_connector(from: Vector2, to: Vector2, color: Color) -> void:
	_draw_organic_connector_on(connectors, from, to, color)


func _connection_point(node: PanelContainer, toward: Vector2) -> Vector2:
	var center: Vector2 = node.get_center()
	var delta: Vector2 = toward - center
	if delta.length_squared() < 1.0:
		return center
	var dir: Vector2 = delta.normalized()
	var half: Vector2 = node.size * 0.5
	var reach: float = minf(half.x, half.y) * 0.82
	return center + dir * reach


func _apply_fonts() -> void:
	PixelFont.apply_label(title_label, 10)
	PixelFont.apply_label(currency_label, 8)
	PixelFont.apply_label(ratina_stats_label, 7)
	tab_upgrades.add_theme_font_override(&"font", PixelFont.font_for_size(7))
	tab_upgrades.add_theme_font_size_override(&"font_size", 7)
	tab_ratina.add_theme_font_override(&"font", PixelFont.font_for_size(7))
	tab_ratina.add_theme_font_size_override(&"font_size", 7)


func _style_tabs() -> void:
	for tab in [tab_upgrades, tab_ratina]:
		tab.toggle_mode = true
		tab.flat = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.82, 0.72, 0.48, 0.75)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.18, 0.52, 0.48, 1)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		tab.add_theme_stylebox_override(&"normal", style)
		var pressed := style.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.92, 0.82, 0.58, 0.95)
		tab.add_theme_stylebox_override(&"pressed", pressed)
		tab.add_theme_stylebox_override(&"hover", pressed)
	tab_upgrades.text = "Tree"
	tab_ratina.text = "Ratina"


func _style_back_button() -> void:
	back_button.add_theme_font_override(&"font", PixelFont.font_for_size(8))
	back_button.add_theme_font_size_override(&"font_size", 8)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.72, 0.48, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.18, 0.52, 0.48, 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	back_button.add_theme_stylebox_override(&"normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.92, 0.82, 0.58, 0.95)
	back_button.add_theme_stylebox_override(&"hover", hover)
	back_button.add_theme_stylebox_override(&"pressed", hover)


func _format_currency(n: float) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.2fK" % (n / 1_000.0)
	return str(int(n))
