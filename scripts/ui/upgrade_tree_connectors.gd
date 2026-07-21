extends Control
## Animated upgrade-tree connector edges drawn in TreeWorld space.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")
const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")

const NODE_HALF := UpgradeIcon.NODE_HALF
## Pull endpoints slightly inside the node so strokes meet drawn borders.
const EDGE_INSET := 0.92
const SURGE_DURATION_SEC := 0.35

var _layout_positions: Dictionary = {}
var _animating := false
## "play" uses UpgradeGraph; "prestige" uses PrestigeDefinitions connections.
var _tab_mode: String = "play"
## to_id → remaining surge time (seconds).
var _edge_surges: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(layout_positions: Dictionary, _nodes: Dictionary = {}, tab_mode: String = "play") -> void:
	_layout_positions = layout_positions
	_tab_mode = tab_mode
	_edge_surges.clear()
	queue_redraw()


func set_animating(enabled: bool) -> void:
	_animating = enabled
	if not enabled:
		_edge_surges.clear()
	set_process(enabled)
	if enabled:
		queue_redraw()


func surge_edge(to_id: String, duration: float = SURGE_DURATION_SEC) -> void:
	if to_id.is_empty():
		return
	_edge_surges[to_id] = duration
	set_process(true)
	queue_redraw()


func get_phase() -> float:
	return UpgradeTreeStroke.get_phase()


func _process(delta: float) -> void:
	if _animating:
		UpgradeTreeStroke.advance_phase(delta)
	if not _edge_surges.is_empty():
		var finished: Array[String] = []
		for id in _edge_surges:
			_edge_surges[id] = float(_edge_surges[id]) - delta
			if float(_edge_surges[id]) <= 0.0:
				finished.append(id)
		for id in finished:
			_edge_surges.erase(id)
	queue_redraw()
	if not _animating and _edge_surges.is_empty():
		set_process(false)


func _game_state() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GameState")


func _connections() -> Array:
	if _tab_mode == "prestige":
		return PrestigeDefinitionsScript.connections()
	return UpgradeGraph.connections()


func _is_revealed(id: String) -> bool:
	# Prestige: always draw the full cheese tree (cash-out does not hide nodes).
	if _tab_mode == "prestige":
		return true
	return UpgradeGraph.is_revealed(id)


func _draw() -> void:
	var corner_r := UpgradeTreeStroke.squircle_corner_radius(NODE_HALF * 2.0)
	for link in _connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if not _layout_positions.has(from_id) or not _layout_positions.has(to_id):
			continue
		if not _is_revealed(from_id) or not _is_revealed(to_id):
			continue
		var from_center: Vector2 = _layout_positions[from_id]
		var to_center: Vector2 = _layout_positions[to_id]
		var from_point: Vector2 = UpgradeTreeStroke.squircle_rim_point(
			from_center, to_center, NODE_HALF, corner_r, EDGE_INSET
		)
		var to_point: Vector2 = UpgradeTreeStroke.squircle_rim_point(
			to_center, from_center, NODE_HALF, corner_r, EDGE_INSET
		)
		var edge_state := resolve_edge_state(to_id, _tab_mode)
		if _edge_surges.has(to_id):
			edge_state = UpgradeTreeStroke.EdgeState.CHARGED
		var style := UpgradeTreeStroke.edge_style_for_upgrade(edge_state, to_id)
		var palette := UpgradeTreeStroke.palette_for_upgrade(to_id)
		var speed: float = style["speed"]
		if _edge_surges.has(to_id):
			speed = UpgradeTreeStroke.SPEED_CHARGED * 1.6
		UpgradeTreeStroke.draw_flow_segment(
			self,
			from_point,
			to_point,
			style["color"],
			style["width"],
			UpgradeTreeStroke.get_phase(),
			speed,
			style["animated"],
			style["glow"] or _edge_surges.has(to_id),
			palette["glow"]
		)


static func resolve_edge_state(to_id: String, tab_mode: String = "play") -> UpgradeTreeStroke.EdgeState:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if tab_mode == "prestige":
		if gs == null:
			return UpgradeTreeStroke.EdgeState.DORMANT
		if not PrestigeDefinitionsScript.is_unlocked(to_id, gs.prestige_levels):
			return UpgradeTreeStroke.EdgeState.DORMANT
		var pdef := PrestigeDefinitionsScript.get_def(to_id)
		var pmax := int(pdef.get("max_level", 0))
		var plevel: int = gs.get_prestige_upgrade_level(to_id)
		if pmax > 0 and plevel >= pmax:
			return UpgradeTreeStroke.EdgeState.COMPLETE
		var pcost: float = gs.get_prestige_upgrade_cost(to_id)
		if plevel < pmax and gs.cheese >= pcost:
			return UpgradeTreeStroke.EdgeState.CHARGED
		return UpgradeTreeStroke.EdgeState.LIVE
	if not UpgradeGraph.is_unlocked(to_id):
		return UpgradeTreeStroke.EdgeState.DORMANT
	var def := UpgradeGraph.get_def(to_id)
	var max_level := int(def.get("max_level", 0))
	var level := UpgradeGraph.level(to_id)
	if max_level > 0 and level >= max_level:
		return UpgradeTreeStroke.EdgeState.COMPLETE
	var cost := UpgradeGraph.cost(to_id)
	if gs != null and level < max_level and gs.currency >= cost:
		return UpgradeTreeStroke.EdgeState.CHARGED
	return UpgradeTreeStroke.EdgeState.LIVE
