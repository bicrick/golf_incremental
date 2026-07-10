extends Control
## Full-screen unified upgrade tree — pannable, zoomable radial mega-tree.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const RadialTreeLayout = preload("res://scripts/ui/upgrade_tree_layout.gd")

const NODE_SCENE := preload("res://scenes/ui/upgrade_tree_node.tscn")
const RATINA_NODE_SCENE := preload("res://scenes/ui/ratina_tree_node.tscn")
const RATTLING_NODE_SCENE := preload("res://scenes/ui/rattling_tree_node.tscn")

const NODE_HALF := UpgradeIcon.NODE_HALF
const BOUNDS_PADDING := 24.0
const FIT_PADDING := 56.0
const FIT_FILL := 0.98

@onready var tree_viewport: Control = $Content/TreeViewport
@onready var tree_world: Control = $Content/TreeViewport/TreeWorld
@onready var connectors: Control = $Content/TreeViewport/TreeWorld/Connectors
@onready var nodes_root: Control = $Content/TreeViewport/TreeWorld/Nodes
@onready var header_bar: PanelContainer = $Content/Header
@onready var title_label: Label = $Content/Header/Row/Title
@onready var currency_label: Label = $Content/Header/Row/CurrencyLabel
@onready var back_button: Button = $Content/Header/Row/BackButton
@onready var _camera_controller: Node = $TreeCameraController

var _is_open := false
var _nodes: Dictionary = {}
var _layout_positions: Dictionary = {}
var _refresh_pending := false


func _ready() -> void:
	visible = false
	back_button.pressed.connect(close)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.shop_item_purchased.connect(_on_shop_item_purchased)
	EventBus.ratina_upgrade_purchased.connect(_on_ratina_upgrade_purchased)
	EventBus.rattling_upgrade_purchased.connect(_on_rattling_upgrade_purchased)
	_apply_fonts()
	UiTheme.apply_wood_header_bar(header_bar)
	_style_back_button()
	_camera_controller.setup(tree_viewport, tree_world)
	_build_tree()
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
	_camera_controller.set_enabled(true)
	if connectors.has_method("set_animating"):
		connectors.set_animating(true)
	call_deferred("fit_to_view")
	_refresh_all()
	_notify_icon_bar(true)
	EventBus.ui_panel_toggled.emit("upgrades", true)


func close() -> void:
	_is_open = false
	visible = false
	_camera_controller.set_enabled(false)
	if connectors.has_method("set_animating"):
		connectors.set_animating(false)
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("upgrades", false)


func consume_zoom_event(event: InputEvent) -> bool:
	if not _is_open:
		return false
	return _camera_controller.consume_zoom_event(event)


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not _is_open:
		return false
	return _camera_controller.consume_pan_drag_event(event)


func _notify_icon_bar(is_open: bool) -> void:
	var icon_bar := get_parent().get_node_or_null("GameplayChrome/IconBar")
	if icon_bar and icon_bar.has_method("set_upgrades_open"):
		icon_bar.set_upgrades_open(is_open)


func _close_other_panels() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var settings_panel := main.get_node_or_null("SettingsLayer/SettingsPanel")
	if settings_panel and settings_panel.has_method("is_open") and settings_panel.is_open():
		settings_panel.close()


func _build_tree() -> void:
	for child in nodes_root.get_children():
		child.queue_free()
	_nodes.clear()
	_layout_positions = RadialTreeLayout.compute_positions()

	for graph_node in UpgradeGraph.all_nodes():
		var id: String = graph_node["id"]
		var node_namespace: String = graph_node["namespace"]
		var def: Dictionary = graph_node["def"]
		var node: PanelContainer = _instantiate_node(node_namespace)
		nodes_root.add_child(node)
		node.setup(def, node_namespace)
		var layout_pos: Vector2 = _layout_positions.get(id, Vector2.ZERO)
		node.position = layout_pos - NODE_HALF
		node.purchase_requested.connect(_on_purchase_requested)
		_nodes[id] = node

	if connectors.has_method("setup"):
		connectors.setup(_layout_positions, _nodes)
	_apply_tree_bounds(_layout_bounds(), BOUNDS_PADDING)


func _instantiate_node(node_namespace: String) -> PanelContainer:
	match node_namespace:
		UpgradeGraph.NAMESPACE_RATINA:
			return RATINA_NODE_SCENE.instantiate()
		UpgradeGraph.NAMESPACE_RATTLING:
			return RATTLING_NODE_SCENE.instantiate()
		_:
			return NODE_SCENE.instantiate()


func _refresh_all() -> void:
	_refresh_pending = false
	currency_label.text = "$%s" % _format_currency(GameState.currency)
	for id in _nodes:
		var node: PanelContainer = _nodes[id]
		var revealed := UpgradeGraph.is_revealed(id)
		node.visible = revealed
		if revealed and node.has_method("refresh"):
			node.refresh()
	connectors.queue_redraw()


func _request_refresh() -> void:
	if not _is_open or _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	if not _refresh_pending:
		return
	if not _is_open:
		_refresh_pending = false
		return
	_refresh_all()


func _on_purchase_requested(id: String) -> void:
	if _camera_controller.did_drag():
		return
	UpgradeGraph.purchase(id)


func _on_currency_changed(currency: float) -> void:
	if not _is_open:
		return
	currency_label.text = "$%s" % _format_currency(currency)
	_request_refresh()


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_request_refresh()


func _on_upgrade_purchased(_id: String, _level: int, _branch: int) -> void:
	_request_refresh()


func _on_shop_item_purchased(_id: String, _level: int) -> void:
	_request_refresh()


func _on_ratina_upgrade_purchased(_id: String, _level: int) -> void:
	_request_refresh()


func _on_rattling_upgrade_purchased(_id: String, _level: int) -> void:
	_request_refresh()


func _layout_bounds(revealed_only: bool = false) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for id in _layout_positions:
		if revealed_only and not UpgradeGraph.is_revealed(id):
			continue
		var pos: Vector2 = _layout_positions[id]
		min_pos.x = minf(min_pos.x, pos.x - NODE_HALF.x)
		min_pos.y = minf(min_pos.y, pos.y - NODE_HALF.y)
		max_pos.x = maxf(max_pos.x, pos.x + NODE_HALF.x)
		max_pos.y = maxf(max_pos.y, pos.y + NODE_HALF.y)
	if min_pos.x == INF:
		return Rect2(Vector2.ZERO, Vector2(40, 40))
	return Rect2(min_pos, max_pos - min_pos)


func fit_to_view() -> void:
	if not _is_open:
		return
	var world_bounds := _layout_bounds()
	var fit_bounds := _layout_bounds(true)
	var tree_size := fit_bounds.size + Vector2(FIT_PADDING * 2.0, FIT_PADDING * 2.0)
	var tree_center := fit_bounds.get_center()
	var vp_size := tree_viewport.size
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		call_deferred("fit_to_view")
		return
	var start_zoom := minf(vp_size.x / tree_size.x, vp_size.y / tree_size.y) * FIT_FILL
	start_zoom = maxf(start_zoom, 0.01)
	var pan := vp_size * 0.5 - tree_center * start_zoom
	_camera_controller.set_baseline(start_zoom, pan)
	_apply_tree_bounds(world_bounds, BOUNDS_PADDING)


func _apply_tree_bounds(bounds: Rect2, padding: float) -> void:
	var padded_size := bounds.size + Vector2(padding * 2.0, padding * 2.0)
	for target in [tree_world, connectors, nodes_root]:
		target.custom_minimum_size = padded_size
		target.size = padded_size


func _apply_fonts() -> void:
	PixelFont.apply_label(title_label, 10)
	PixelFont.apply_label(currency_label, 8)


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
	return FloatCashText.format_amount(n)
