extends Control
## Animated upgrade-tree connector edges drawn in TreeWorld space.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")
const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")

const NODE_HALF := UpgradeIcon.NODE_HALF
## Pull endpoints slightly inside the node so strokes meet drawn borders.
const EDGE_INSET := 0.92

var _layout_positions: Dictionary = {}
var _animating := false
## "play" uses UpgradeGraph; "prestige" uses PrestigeDefinitions connections.
var _tab_mode: String = "play"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(layout_positions: Dictionary, _nodes: Dictionary = {}, tab_mode: String = "play") -> void:
	_layout_positions = layout_positions
	_tab_mode = tab_mode
	queue_redraw()


func set_animating(enabled: bool) -> void:
	_animating = enabled
	set_process(enabled)
	if enabled:
		queue_redraw()


func get_phase() -> float:
	return UpgradeTreeStroke.get_phase()


func _process(delta: float) -> void:
	if not _animating:
		return
	UpgradeTreeStroke.advance_phase(delta)
	queue_redraw()


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
	for link in _connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if not _layout_positions.has(from_id) or not _layout_positions.has(to_id):
			continue
		if not _is_revealed(from_id) or not _is_revealed(to_id):
			continue
		var from_center: Vector2 = _layout_positions[from_id]
		var to_center: Vector2 = _layout_positions[to_id]
		var from_point: Vector2 = _circle_edge_point(from_center, to_center, NODE_HALF.x)
		var to_point: Vector2 = _circle_edge_point(to_center, from_center, NODE_HALF.x)
		var edge_state := resolve_edge_state(to_id, _tab_mode)
		var style := UpgradeTreeStroke.edge_style_for_upgrade(edge_state, to_id)
		var palette := UpgradeTreeStroke.palette_for_upgrade(to_id)
		UpgradeTreeStroke.draw_flow_segment(
			self,
			from_point,
			to_point,
			style["color"],
			style["width"],
			UpgradeTreeStroke.get_phase(),
			style["speed"],
			style["animated"],
			style["glow"],
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


func _circle_edge_point(center: Vector2, toward: Vector2, radius: float) -> Vector2:
	var delta: Vector2 = toward - center
	if delta.length_squared() < 1.0:
		return center
	return center + delta.normalized() * radius * EDGE_INSET
