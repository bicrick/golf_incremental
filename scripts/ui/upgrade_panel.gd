extends Control
## Full-screen cash upgrade tree.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const RadialTreeLayout = preload("res://scripts/ui/upgrade_tree_layout.gd")

const NODE_SCENE := preload("res://scenes/ui/upgrade_tree_node.tscn")
const UpgradeNodeTap = preload("res://scripts/ui/upgrade_node_tap.gd")

const NODE_HALF := UpgradeIcon.NODE_HALF
const BOUNDS_PADDING := 24.0
const FIT_PADDING := 68.0
const FIT_PADDING_PORTRAIT := 88.0
const FIT_FILL := 0.98
const FIT_FILL_PORTRAIT := 0.84
const CHROME_TOP := 28.0
const CHROME_BOTTOM_PORTRAIT := 36.0
const REVEAL_STAGGER_SEC := 0.05
## v5 menu refresh — never open more zoomed-in than this; room for level/price tags.
const MAX_START_ZOOM := 2.0
const INFO_TAG_RESERVE := 18.0

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
## Blocks currency/stats deferred refresh from stomping purchase/reveal tweens.
var _suppress_deferred_refresh := false


func _ready() -> void:
	visible = false
	_strip_stale_prestige_chrome()
	back_button.pressed.connect(close)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.shop_item_purchased.connect(_on_shop_item_purchased)
	EventBus.ratina_upgrade_purchased.connect(_on_ratina_upgrade_purchased)
	EventBus.rattling_upgrade_purchased.connect(_on_rattling_upgrade_purchased)
	_apply_fonts()
	UiTheme.apply_header_bar(header_bar)
	_style_back_button()
	_camera_controller.setup(tree_viewport, tree_world)
	if not tree_viewport.gui_input.is_connected(_on_tree_gui_input):
		tree_viewport.gui_input.connect(_on_tree_gui_input)
	RadialTreeLayout.use_portrait_aspect = UiLayout.is_portrait(get_viewport())
	_build_tree()
	_refresh_all()


func apply_viewport_layout() -> void:
	var want_portrait := UiLayout.is_portrait(get_viewport())
	var aspect_changed := RadialTreeLayout.use_portrait_aspect != want_portrait
	RadialTreeLayout.use_portrait_aspect = want_portrait
	if aspect_changed:
		_build_tree()
		_refresh_all()
	if _is_open:
		fit_to_view()


## Drop leftover Play/Prestige tab chrome from earlier builds.
func _strip_stale_prestige_chrome() -> void:
	var row: HBoxContainer = $Content/Header/Row
	title_label.visible = true
	title_label.text = "Upgrades"
	for stale_name in ["TabBar", "TabHeadings", "PrestigeCount", "CheeseIcon"]:
		var stale := row.get_node_or_null(stale_name)
		if stale != null:
			stale.queue_free()
	for stale_name in ["Content/PrestigeButton", "PrestigeConfirm", "PrestigeConfirmModal", "PrestigeButtonTooltip"]:
		var node := get_node_or_null(stale_name)
		if node != null:
			node.queue_free()


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
	apply_viewport_layout()
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
	UpgradeNodeTap.clear()
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


func _gui_input(event: InputEvent) -> void:
	_handle_tree_pointer_event(event, self)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


func _on_tree_gui_input(event: InputEvent) -> void:
	_handle_tree_pointer_event(event, tree_viewport)


func _handle_tree_pointer_event(event: InputEvent, host: Control) -> void:
	if not _is_open:
		return
	if consume_zoom_event(event):
		host.accept_event()
		return
	if host != tree_viewport:
		return
	if _is_primary_release(event) and not _camera_controller.did_drag():
		if not _camera_controller.is_pinching() and _release_clears_inspect():
			UpgradeNodeTap.clear()


func _release_clears_inspect() -> bool:
	## Empty-area release dismisses inspect. Releases on tree HitButtons must not
	## clear — that click is inspect/buy.
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return true
	var n: Node = hovered
	while n != null:
		if n == nodes_root:
			return false
		n = n.get_parent()
	return true


func _is_primary_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false


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
	UpgradeNodeTap.clear()
	for child in nodes_root.get_children():
		child.queue_free()
	_nodes.clear()

	_layout_positions = RadialTreeLayout.compute_positions()
	for graph_node in UpgradeGraph.all_nodes():
		var id: String = graph_node["id"]
		var node_namespace: String = graph_node["namespace"]
		var def: Dictionary = graph_node["def"]
		var node: PanelContainer = NODE_SCENE.instantiate()
		nodes_root.add_child(node)
		node.setup(def, node_namespace)
		var layout_pos: Vector2 = _layout_positions.get(id, Vector2.ZERO)
		node.position = layout_pos - NODE_HALF
		node.purchase_requested.connect(_on_purchase_requested)
		_nodes[id] = node
	if connectors.has_method("setup"):
		connectors.setup(_layout_positions, _nodes)

	_apply_tree_bounds(_layout_bounds(), BOUNDS_PADDING)


func _refresh_all() -> void:
	_refresh_pending = false
	_refresh_header()
	for id in _nodes:
		var node: PanelContainer = _nodes[id]
		var revealed := _is_node_revealed(id)
		node.visible = revealed
		if revealed and node.has_method("refresh"):
			node.refresh()
	connectors.queue_redraw()


func _handle_purchase_fx(purchased_id: String) -> void:
	if not _is_open:
		_request_refresh()
		return
	_suppress_deferred_refresh = true
	var was_visible: Dictionary = {}
	for id in _nodes:
		was_visible[id] = (_nodes[id] as PanelContainer).visible
	_refresh_pending = false
	_refresh_header()
	var newly_revealed: Array[String] = []
	for id in _nodes:
		var node: PanelContainer = _nodes[id]
		var revealed := _is_node_revealed(id)
		var was_shown := bool(was_visible.get(id, false))
		node.visible = revealed
		if revealed and node.has_method("refresh"):
			node.refresh()
		if revealed and not was_shown:
			newly_revealed.append(id)
			if node.has_method("prep_reveal_in"):
				node.prep_reveal_in()
	connectors.queue_redraw()
	var purchased: PanelContainer = _nodes.get(purchased_id) as PanelContainer
	if purchased != null and purchased.has_method("play_purchase_burst"):
		purchased.play_purchase_burst()
	if connectors.has_method("surge_edge"):
		connectors.surge_edge(purchased_id)
	_animate_reveals(newly_revealed)
	call_deferred("_clear_purchase_fx_suppress")


func _clear_purchase_fx_suppress() -> void:
	_suppress_deferred_refresh = false
	_refresh_pending = false


func _animate_reveals(ids: Array[String]) -> void:
	if ids.is_empty():
		return
	var delay := 0.0
	for id in ids:
		var node: PanelContainer = _nodes.get(id) as PanelContainer
		if node == null or not node.has_method("play_reveal_in"):
			continue
		var captured := node
		get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(captured) and captured.has_method("play_reveal_in"):
					captured.play_reveal_in()
		)
		delay += REVEAL_STAGGER_SEC


func _is_node_revealed(id: String) -> bool:
	return UpgradeGraph.is_revealed(id)


func _refresh_header() -> void:
	currency_label.text = "$%s" % _format_currency(GameState.currency)
	_refresh_finds_chip()


## v5 — story progress beside the title (the tree grows as the mist recedes).
func _refresh_finds_chip() -> void:
	var row: HBoxContainer = $Content/Header/Row
	var chip := row.get_node_or_null("FindsChip") as Label
	if chip == null:
		chip = Label.new()
		chip.name = "FindsChip"
		chip.add_theme_color_override(&"font_color", Color(0.46, 0.36, 0.22, 1))
		PixelFont.apply_label(chip, 7)
		row.add_child(chip)
		row.move_child(chip, currency_label.get_index())
	var found: int = GameState.story_found_count()
	chip.visible = found > 0
	chip.text = "Finds %d/%d" % [found, GameState.story_total_count()]


func _request_refresh() -> void:
	if not _is_open or _refresh_pending or _suppress_deferred_refresh:
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
	if not UpgradeGraph.purchase(id):
		SfxManager.play_ui_error()


func _on_currency_changed(currency: float) -> void:
	if not _is_open:
		return
	currency_label.text = "$%s" % _format_currency(currency)
	_request_refresh()


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_request_refresh()


func _on_upgrade_purchased(id: String, _level: int, _branch: int) -> void:
	_handle_purchase_fx(id)


func _on_shop_item_purchased(id: String, _level: int) -> void:
	_handle_purchase_fx(id)


func _on_ratina_upgrade_purchased(id: String, _level: int) -> void:
	_handle_purchase_fx(id)


func _on_rattling_upgrade_purchased(id: String, _level: int) -> void:
	_handle_purchase_fx(id)


func _layout_bounds(revealed_only: bool = false) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for id in _layout_positions:
		if revealed_only and not _is_node_revealed(id):
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
	# v5: fit what the player can see (crew subtrees stay hidden until found),
	# capped so an early three-node tree doesn't balloon.
	var world_bounds := _layout_bounds(false)
	var fit_bounds := _layout_bounds(true)
	fit_bounds = fit_bounds.grow_individual(0, 0, 0, INFO_TAG_RESERVE)
	var portrait := RadialTreeLayout.use_portrait_aspect
	var pad := FIT_PADDING_PORTRAIT if portrait else FIT_PADDING
	var fill := FIT_FILL_PORTRAIT if portrait else FIT_FILL
	var tree_size := fit_bounds.size + Vector2(pad * 2.0, pad * 2.0)
	var tree_center := fit_bounds.get_center()
	var vp_size := tree_viewport.size
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		call_deferred("fit_to_view")
		return
	var top_reserve := header_bar.size.y if header_bar.size.y > 1.0 else CHROME_TOP
	var bottom_reserve := CHROME_BOTTOM_PORTRAIT if portrait else 8.0
	var usable_origin := Vector2(0.0, top_reserve)
	var usable_size := Vector2(vp_size.x, maxf(vp_size.y - top_reserve - bottom_reserve, 8.0))
	var start_zoom := minf(usable_size.x / tree_size.x, usable_size.y / tree_size.y) * fill
	start_zoom = clampf(start_zoom, 0.01, MAX_START_ZOOM)
	var pan := usable_origin + usable_size * 0.5 - tree_center * start_zoom
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
	UiTheme.apply_panel_label(title_label)
	UiTheme.apply_panel_label(currency_label)


func _style_back_button() -> void:
	UiTheme.apply_compact_primary_button(back_button)


func _format_currency(n: float) -> String:
	return FloatCashText.format_amount(n)
