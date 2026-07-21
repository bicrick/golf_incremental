extends Control
## Full-screen unified upgrade tree — Play (cash) and Prestige (cheese) tabs.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const RadialTreeLayout = preload("res://scripts/ui/upgrade_tree_layout.gd")
const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")

const NODE_SCENE := preload("res://scenes/ui/upgrade_tree_node.tscn")
const CHEESE_ICON := preload("res://assets/ui/cheese-currency-icon.png")
const StyledHoverTooltipScript = preload("res://scripts/ui/styled_hover_tooltip.gd")
const StyledConfirmModalScript = preload("res://scripts/ui/styled_confirm_modal.gd")

const NODE_HALF := UpgradeIcon.NODE_HALF
const BOUNDS_PADDING := 24.0
const FIT_PADDING := 56.0
const FIT_FILL := 0.98
const REVEAL_STAGGER_SEC := 0.05
const TAB_ACTIVE_COLOR := UiTheme.COLOR_TAB_ACTIVE
## Muted green — inactive look only; tabs stay fully clickable.
const TAB_INACTIVE_COLOR := UiTheme.COLOR_TAB_INACTIVE

enum Tab { PLAY, PRESTIGE }

@onready var tree_viewport: Control = $Content/TreeViewport
@onready var tree_world: Control = $Content/TreeViewport/TreeWorld
@onready var connectors: Control = $Content/TreeViewport/TreeWorld/Connectors
@onready var nodes_root: Control = $Content/TreeViewport/TreeWorld/Nodes
@onready var header_bar: PanelContainer = $Content/Header
@onready var title_label: Label = $Content/Header/Row/Title
@onready var currency_label: Label = $Content/Header/Row/CurrencyLabel
@onready var back_button: Button = $Content/Header/Row/BackButton
@onready var _camera_controller: Node = $TreeCameraController

var _base_tab_button: Button
var _prestige_tab_button: Button
var _prestige_count_label: Label
var _cheese_icon: TextureRect
var _prestige_button: Button
var _prestige_tooltip: Node
var _confirm_modal: Control

var _active_tab: Tab = Tab.PLAY
var _is_open := false
var _ritual_shop := false
var _nodes: Dictionary = {}
var _layout_positions: Dictionary = {}
var _refresh_pending := false
## Blocks currency/stats deferred refresh from stomping purchase/reveal tweens.
var _suppress_deferred_refresh := false


func _ready() -> void:
	visible = false
	_ensure_tab_chrome()
	back_button.pressed.connect(close)
	_base_tab_button.pressed.connect(_on_base_tab_pressed)
	_prestige_tab_button.pressed.connect(_on_prestige_tab_pressed)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.cheese_changed.connect(_on_cheese_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.shop_item_purchased.connect(_on_shop_item_purchased)
	EventBus.ratina_upgrade_purchased.connect(_on_ratina_upgrade_purchased)
	EventBus.rattling_upgrade_purchased.connect(_on_rattling_upgrade_purchased)
	EventBus.prestige_upgrade_purchased.connect(_on_prestige_upgrade_purchased)
	EventBus.prestiged.connect(_on_prestiged)
	_apply_fonts()
	UiTheme.apply_header_bar(header_bar)
	_style_back_button()
	_style_prestige_button()
	_setup_prestige_tooltip()
	_camera_controller.setup(tree_viewport, tree_world)
	_build_tree()
	_refresh_all()


func _setup_prestige_tooltip() -> void:
	_prestige_tooltip = get_node_or_null("PrestigeButtonTooltip")
	if _prestige_tooltip == null:
		_prestige_tooltip = StyledHoverTooltipScript.new()
		_prestige_tooltip.name = "PrestigeButtonTooltip"
		add_child(_prestige_tooltip)
	# Keep button mouse events alive when "disabled" so styled hover works.
	_prestige_button.tooltip_text = ""
	_prestige_tooltip.bind(_prestige_button)
	_refresh_prestige_button()


func _ensure_tab_chrome() -> void:
	var row: HBoxContainer = $Content/Header/Row
	# Drop runtime TabBar chrome from earlier builds (bordered Play + arrows).
	var stale_tab_bar := row.get_node_or_null("TabBar")
	if stale_tab_bar != null:
		stale_tab_bar.queue_free()

	title_label.visible = false
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var headings: HBoxContainer = row.get_node_or_null("TabHeadings") as HBoxContainer
	if headings == null:
		headings = HBoxContainer.new()
		headings.name = "TabHeadings"
		headings.alignment = BoxContainer.ALIGNMENT_CENTER
		headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		headings.mouse_filter = Control.MOUSE_FILTER_STOP
		headings.add_theme_constant_override(&"separation", 16)
		row.add_child(headings)
		row.move_child(headings, title_label.get_index())

	# Migrate earlier Label-based headings to always-clickable flat Buttons.
	for stale_name in ["BaseTab", "PrestigeTab"]:
		var stale := headings.get_node_or_null(stale_name)
		if stale != null and not (stale is Button):
			headings.remove_child(stale)
			stale.free()

	_base_tab_button = headings.get_node_or_null("BaseTab") as Button
	if _base_tab_button == null:
		_base_tab_button = _make_tab_heading("BaseTab", "Base")
		headings.add_child(_base_tab_button)
	_prestige_tab_button = headings.get_node_or_null("PrestigeTab") as Button
	if _prestige_tab_button == null:
		_prestige_tab_button = _make_tab_heading("PrestigeTab", "Prestige")
		headings.add_child(_prestige_tab_button)

	# Tab access is never gated by cash / can_prestige().
	_base_tab_button.disabled = false
	_prestige_tab_button.disabled = false

	_prestige_count_label = row.get_node_or_null("PrestigeCount") as Label
	if _prestige_count_label == null:
		_prestige_count_label = Label.new()
		_prestige_count_label.name = "PrestigeCount"
		_prestige_count_label.visible = false
		_prestige_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(_prestige_count_label)
		row.move_child(_prestige_count_label, row.get_child_count() - 2)

	_cheese_icon = row.get_node_or_null("CheeseIcon") as TextureRect
	if _cheese_icon == null:
		_cheese_icon = TextureRect.new()
		_cheese_icon.name = "CheeseIcon"
		_cheese_icon.texture = CHEESE_ICON
		_cheese_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cheese_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_cheese_icon.custom_minimum_size = Vector2(14, 14)
		_cheese_icon.visible = false
		_cheese_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(_cheese_icon)
		row.move_child(_cheese_icon, row.get_child_count() - 2)

	_prestige_button = get_node_or_null("Content/PrestigeButton") as Button
	if _prestige_button == null:
		_prestige_button = Button.new()
		_prestige_button.name = "PrestigeButton"
		_prestige_button.text = "Prestige"
		_prestige_button.visible = false
		_prestige_button.anchor_left = 1.0
		_prestige_button.anchor_top = 1.0
		_prestige_button.anchor_right = 1.0
		_prestige_button.anchor_bottom = 1.0
		_prestige_button.offset_left = -88.0
		_prestige_button.offset_top = -28.0
		_prestige_button.offset_right = -8.0
		_prestige_button.offset_bottom = -8.0
		_prestige_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_prestige_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
		$Content.add_child(_prestige_button)

	# Drop default Godot ConfirmationDialog from earlier builds.
	var stale_confirm := get_node_or_null("PrestigeConfirm")
	if stale_confirm != null:
		remove_child(stale_confirm)
		stale_confirm.free()

	_confirm_modal = get_node_or_null("PrestigeConfirmModal") as Control
	if _confirm_modal == null:
		_confirm_modal = StyledConfirmModalScript.new()
		_confirm_modal.name = "PrestigeConfirmModal"
		add_child(_confirm_modal)
	_confirm_modal.configure(
		"Prestige",
		"Prestige now? You will lose all cash and Base upgrades. You will gain cheese and keep Prestige upgrades.",
		"Prestige",
		"Cancel"
	)
	if not _confirm_modal.confirmed.is_connected(_on_prestige_confirmed):
		_confirm_modal.confirmed.connect(_on_prestige_confirmed)


func _make_tab_heading(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(64, 18)
	# Text-only heading: no bordered chrome.
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override(&"normal", empty)
	button.add_theme_stylebox_override(&"hover", empty)
	button.add_theme_stylebox_override(&"pressed", empty)
	button.add_theme_stylebox_override(&"disabled", empty)
	button.add_theme_stylebox_override(&"focus", empty)
	return button


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
	if _ritual_shop:
		# Ritual owns close via close_ritual_shop / Advance.
		return
	_is_open = false
	visible = false
	_camera_controller.set_enabled(false)
	if connectors.has_method("set_animating"):
		connectors.set_animating(false)
	if _prestige_tooltip and _prestige_tooltip.has_method("hide_now"):
		_prestige_tooltip.hide_now()
	if _confirm_modal and _confirm_modal.has_method("close_modal"):
		_confirm_modal.close_modal()
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("upgrades", false)


## Prestige celebration shop: Prestige tree only, no Base tab / cash-out button.
func open_ritual_shop() -> void:
	_ritual_shop = true
	_close_other_panels()
	_is_open = true
	visible = true
	_active_tab = Tab.PRESTIGE
	_camera_controller.set_enabled(true)
	if connectors.has_method("set_animating"):
		connectors.set_animating(true)
	_build_tree()
	_refresh_all()
	call_deferred("fit_to_view")
	_notify_icon_bar(true)
	EventBus.ui_panel_toggled.emit("upgrades", true)


func close_ritual_shop() -> void:
	_ritual_shop = false
	_is_open = false
	visible = false
	_camera_controller.set_enabled(false)
	if connectors.has_method("set_animating"):
		connectors.set_animating(false)
	if _prestige_tooltip and _prestige_tooltip.has_method("hide_now"):
		_prestige_tooltip.hide_now()
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("upgrades", false)
	_active_tab = Tab.PLAY


func is_ritual_shop() -> bool:
	return _ritual_shop


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


func _on_base_tab_pressed() -> void:
	if _ritual_shop:
		return
	_select_tab(Tab.PLAY)


func _on_prestige_tab_pressed() -> void:
	# Always allow visiting the Prestige tree — cash-out is a separate button.
	_select_tab(Tab.PRESTIGE)


func _select_tab(tab: Tab) -> void:
	if _active_tab == tab:
		return
	_active_tab = tab
	_build_tree()
	_refresh_all()
	call_deferred("fit_to_view")

func _build_tree() -> void:
	for child in nodes_root.get_children():
		child.queue_free()
	_nodes.clear()

	if _active_tab == Tab.PRESTIGE:
		_layout_positions = RadialTreeLayout.compute_positions_for(
			"cheese_press", PrestigeDefinitionsScript.connections()
		)
		for def in PrestigeDefinitionsScript.all():
			var id: String = def["id"]
			var node: PanelContainer = NODE_SCENE.instantiate()
			nodes_root.add_child(node)
			node.setup(def, "prestige")
			var layout_pos: Vector2 = _layout_positions.get(id, Vector2.ZERO)
			node.position = layout_pos - NODE_HALF
			node.purchase_requested.connect(_on_purchase_requested)
			_nodes[id] = node
		if connectors.has_method("setup"):
			connectors.setup(_layout_positions, _nodes, "prestige")
	else:
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
			connectors.setup(_layout_positions, _nodes, "play")

	_apply_tree_bounds(_layout_bounds(), BOUNDS_PADDING)


func _refresh_all() -> void:
	_refresh_pending = false
	_refresh_header()
	_refresh_prestige_button()
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
	_refresh_prestige_button()
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
	# Prestige tree is always fully visible — cash-out threshold does not hide it.
	if _active_tab == Tab.PRESTIGE:
		return true
	return UpgradeGraph.is_revealed(id)


func _refresh_header() -> void:
	var on_prestige := _active_tab == Tab.PRESTIGE
	_prestige_count_label.visible = on_prestige
	_cheese_icon.visible = on_prestige
	_prestige_button.visible = on_prestige and not _ritual_shop
	_base_tab_button.visible = not _ritual_shop
	_prestige_tab_button.visible = true
	back_button.visible = not _ritual_shop
	# Never disable tab headings — muted color is visual-only.
	_base_tab_button.disabled = false
	_prestige_tab_button.disabled = false
	_apply_tab_heading_colors(on_prestige)
	if on_prestige:
		_prestige_count_label.text = "Prestige #%d" % GameState.prestige_count
		currency_label.text = "%d" % GameState.cheese
	else:
		currency_label.text = "$%s" % _format_currency(GameState.currency)


func _apply_tab_heading_colors(on_prestige: bool) -> void:
	var base_color := TAB_INACTIVE_COLOR if on_prestige else TAB_ACTIVE_COLOR
	var prestige_color := TAB_ACTIVE_COLOR if on_prestige else TAB_INACTIVE_COLOR
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		_base_tab_button.add_theme_color_override(key, base_color)
		_prestige_tab_button.add_theme_color_override(key, prestige_color)
	_base_tab_button.add_theme_color_override(&"font_disabled_color", base_color)
	_prestige_tab_button.add_theme_color_override(&"font_disabled_color", prestige_color)


func _refresh_prestige_button() -> void:
	if not _prestige_button.visible:
		if _prestige_tooltip and _prestige_tooltip.has_method("hide_now"):
			_prestige_tooltip.hide_now()
		return
	# Cash-out only — does not gate tab access or tree visibility.
	# Stay enabled for hover (Godot suppresses mouse_entered on disabled buttons).
	var can := GameState.can_prestige()
	_prestige_button.disabled = false
	_prestige_button.tooltip_text = ""
	_apply_prestige_button_afford_look(can)
	var threshold := GameState.prestige_threshold
	var title := "Prestige"
	var body: String
	if can:
		body = "Cash out for cheese. Reset Play upgrades. Keep Prestige perks."
		_prestige_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		var need := maxf(0.0, threshold - GameState.currency)
		body = (
			"Need $%s on hand to prestige.\nRequires $%s. Reset cash upgrades and cash. Keep cheese and prestige perks."
			% [_format_currency(need if need > 0.0 else threshold), _format_currency(threshold)]
		)
		_prestige_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _prestige_tooltip and _prestige_tooltip.has_method("set_content"):
		_prestige_tooltip.set_content(title, body)


func _apply_prestige_button_afford_look(can_afford: bool) -> void:
	# Visual grey-out without Button.disabled so styled tooltips still hover.
	if can_afford:
		_prestige_button.modulate = Color.WHITE
	else:
		_prestige_button.modulate = Color(0.72, 0.7, 0.66, 0.85)


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
	if _active_tab == Tab.PRESTIGE:
		GameState.purchase_prestige_upgrade(id)
	else:
		UpgradeGraph.purchase(id)


func _on_prestige_pressed() -> void:
	if not GameState.can_prestige():
		return
	if _confirm_modal and _confirm_modal.has_method("open_modal"):
		_confirm_modal.open_modal()


func _on_prestige_confirmed() -> void:
	if not GameState.can_prestige():
		return
	var cheese_before: int = GameState.cheese
	var gained: int = GameState.cheese_from_prestige_cash(GameState.currency)
	if not GameState.prestige():
		return
	if _confirm_modal and _confirm_modal.has_method("close_modal"):
		_confirm_modal.close_modal()
	# Hide normal upgrade panel; celebration flow takes over.
	_is_open = false
	visible = false
	_camera_controller.set_enabled(false)
	if connectors.has_method("set_animating"):
		connectors.set_animating(false)
	_notify_icon_bar(false)
	EventBus.ui_panel_toggled.emit("upgrades", false)
	var flow := get_parent().get_node_or_null("PrestigeFlow")
	if flow != null and flow.has_method("begin_ritual"):
		flow.begin_ritual(cheese_before, gained)
	else:
		# Fallback if flow missing — state already prestiged.
		_refresh_all()

func _on_currency_changed(currency: float) -> void:
	if not _is_open:
		return
	if _active_tab == Tab.PLAY:
		currency_label.text = "$%s" % _format_currency(currency)
	_refresh_prestige_button()
	_request_refresh()


func _on_cheese_changed(cheese: int) -> void:
	if not _is_open:
		return
	if _active_tab == Tab.PRESTIGE:
		currency_label.text = "%d" % cheese
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


func _on_prestige_upgrade_purchased(id: String, _level: int) -> void:
	_handle_purchase_fx(id)


func _on_prestiged(_count: int, _gained: float) -> void:
	_request_refresh()


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
	_base_tab_button.add_theme_font_override(&"font", PixelFont.font_for_size(10))
	_base_tab_button.add_theme_font_size_override(&"font_size", 10)
	_prestige_tab_button.add_theme_font_override(&"font", PixelFont.font_for_size(10))
	_prestige_tab_button.add_theme_font_size_override(&"font_size", 10)
	PixelFont.apply_label(currency_label, 8)
	PixelFont.apply_label(_prestige_count_label, 8)
	UiTheme.apply_panel_label(currency_label)
	UiTheme.apply_panel_label(_prestige_count_label)


func _style_back_button() -> void:
	UiTheme.apply_compact_primary_button(back_button)


func _style_prestige_button() -> void:
	UiTheme.apply_accent_button(_prestige_button)


func _format_currency(n: float) -> String:
	return FloatCashText.format_amount(n)
