extends Control
## Animated upgrade-tree connector edges drawn in TreeWorld space.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const UpgradeTreeStroke = preload("res://scripts/ui/upgrade_tree_stroke.gd")

const NODE_HALF := Vector2(19, 19)
## Pull endpoints slightly inside the node so strokes meet drawn borders.
const EDGE_INSET := 0.92

var _layout_positions: Dictionary = {}
var _animating := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(layout_positions: Dictionary, _nodes: Dictionary = {}) -> void:
	_layout_positions = layout_positions
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


func _draw() -> void:
	for link in UpgradeGraph.connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if not _layout_positions.has(from_id) or not _layout_positions.has(to_id):
			continue
		if not UpgradeGraph.is_revealed(from_id) or not UpgradeGraph.is_revealed(to_id):
			continue
		var from_center: Vector2 = _layout_positions[from_id]
		var to_center: Vector2 = _layout_positions[to_id]
		var from_point: Vector2 = _rect_edge_point(from_center, to_center, NODE_HALF)
		var to_point: Vector2 = _rect_edge_point(to_center, from_center, NODE_HALF)
		var edge_state := resolve_edge_state(to_id)
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


static func resolve_edge_state(to_id: String) -> UpgradeTreeStroke.EdgeState:
	if not UpgradeGraph.is_unlocked(to_id):
		return UpgradeTreeStroke.EdgeState.DORMANT
	var def := UpgradeGraph.get_def(to_id)
	var max_level := int(def.get("max_level", 0))
	var level := UpgradeGraph.level(to_id)
	if max_level > 0 and level >= max_level:
		return UpgradeTreeStroke.EdgeState.COMPLETE
	var cost := UpgradeGraph.cost(to_id)
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if gs != null and level < max_level and gs.currency >= cost:
		return UpgradeTreeStroke.EdgeState.CHARGED
	return UpgradeTreeStroke.EdgeState.LIVE


func _rect_edge_point(center: Vector2, toward: Vector2, half: Vector2) -> Vector2:
	var delta: Vector2 = toward - center
	if delta.length_squared() < 1.0:
		return center
	var dir: Vector2 = delta.normalized()
	var t_min := INF
	if absf(dir.x) > 0.0001:
		for edge_x in [-half.x, half.x]:
			var t: float = edge_x / dir.x
			if t > 0.0:
				var y: float = dir.y * t
				if absf(y) <= half.y:
					t_min = minf(t_min, t)
	if absf(dir.y) > 0.0001:
		for edge_y in [-half.y, half.y]:
			var t: float = edge_y / dir.y
			if t > 0.0:
				var x: float = dir.x * t
				if absf(x) <= half.x:
					t_min = minf(t_min, t)
	if t_min == INF:
		return center
	return center + dir * t_min * EDGE_INSET
