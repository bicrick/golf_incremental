class_name RadialTreeLayout
extends RefCounted
## Static radial layout with wedge skeleton + organic force relaxation.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")

const NODE_SIZE := 38.0
const RING_SPACING := 92.0
const MIN_NODE_DISTANCE := 54.0
const RELAX_ITERATIONS := 150
const SEPARATION_ITERATIONS := 30
const REPULSION_STRENGTH := 1800.0
const SPRING_STRENGTH := 0.08
const CENTER_PULL := 0.002
const DAMPING := 0.85
const JITTER_ANGLE_DEG := 4.0
const JITTER_RADIUS := 6.0


static func compute_positions(root_id: String = UpgradeGraph.ROOT_ID) -> Dictionary:
	var children := _children_map()
	var subtree_weights := _subtree_weights(root_id, children)
	var angles := {}
	_assign_angles(root_id, -PI, PI, children, subtree_weights, angles)

	var positions: Dictionary = {}
	positions[root_id] = Vector2.ZERO
	_place_children(root_id, 1, angles, children, positions)
	var spring_lengths := _edge_spring_lengths(positions)
	_relax(positions, children, root_id, spring_lengths)
	_separate_overlaps(positions, root_id)
	return positions


static func _children_map() -> Dictionary:
	var children: Dictionary = {}
	for link in UpgradeGraph.connections():
		var parent_id: String = link["from"]
		var child_id: String = link["to"]
		if not children.has(parent_id):
			children[parent_id] = []
		children[parent_id].append(child_id)
	for parent_id in children:
		children[parent_id].sort()
	return children


static func _subtree_weights(node_id: String, children: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	_compute_weight(node_id, children, weights)
	return weights


static func _compute_weight(node_id: String, children: Dictionary, weights: Dictionary) -> float:
	var child_ids: Array = children.get(node_id, [])
	if child_ids.is_empty():
		weights[node_id] = 1.0
		return 1.0
	var total := 0.0
	for child_id in child_ids:
		total += _compute_weight(child_id, children, weights)
	weights[node_id] = maxf(total, 1.0)
	return weights[node_id]


static func _assign_angles(
	node_id: String,
	start_angle: float,
	end_angle: float,
	children: Dictionary,
	weights: Dictionary,
	angles: Dictionary
) -> void:
	angles[node_id] = (start_angle + end_angle) * 0.5
	var child_ids: Array = children.get(node_id, [])
	if child_ids.is_empty():
		return
	var total_weight := 0.0
	for child_id in child_ids:
		total_weight += float(weights.get(child_id, 1.0))
	var cursor := start_angle
	for child_id in child_ids:
		var child_weight: float = float(weights.get(child_id, 1.0))
		var wedge := (end_angle - start_angle) * (child_weight / total_weight)
		_assign_angles(child_id, cursor, cursor + wedge, children, weights, angles)
		cursor += wedge


static func _place_children(
	node_id: String,
	depth: int,
	angles: Dictionary,
	children: Dictionary,
	positions: Dictionary
) -> void:
	for child_id in children.get(node_id, []):
		var angle: float = float(angles.get(child_id, 0.0))
		angle += deg_to_rad(_deterministic_jitter(child_id, -JITTER_ANGLE_DEG, JITTER_ANGLE_DEG))
		var radius := depth * RING_SPACING + _deterministic_jitter(child_id, -JITTER_RADIUS, JITTER_RADIUS)
		positions[child_id] = Vector2(cos(angle), sin(angle)) * radius
		_place_children(child_id, depth + 1, angles, children, positions)


static func _edge_spring_lengths(positions: Dictionary) -> Dictionary:
	var lengths: Dictionary = {}
	for link in UpgradeGraph.connections():
		var from_id: String = link["from"]
		var to_id: String = link["to"]
		if not positions.has(from_id) or not positions.has(to_id):
			continue
		var key := "%s->%s" % [from_id, to_id]
		lengths[key] = positions[from_id].distance_to(positions[to_id])
	return lengths


static func _relax(
	positions: Dictionary,
	children: Dictionary,
	root_id: String,
	spring_lengths: Dictionary
) -> void:
	var ids: Array = positions.keys()
	ids.sort()
	var velocities: Dictionary = {}
	for id in ids:
		velocities[id] = Vector2.ZERO

	for _iteration in RELAX_ITERATIONS:
		var forces: Dictionary = {}
		for id in ids:
			forces[id] = Vector2.ZERO

		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var id_a: String = ids[i]
				var id_b: String = ids[j]
				var delta: Vector2 = positions[id_a] - positions[id_b]
				var dist: float = maxf(delta.length(), 0.01)
				if dist >= MIN_NODE_DISTANCE:
					continue
				var push: Vector2 = delta.normalized() * ((MIN_NODE_DISTANCE - dist) / MIN_NODE_DISTANCE)
				push *= REPULSION_STRENGTH * 0.001
				forces[id_a] += push
				forces[id_b] -= push

		for link in UpgradeGraph.connections():
			var from_id: String = link["from"]
			var to_id: String = link["to"]
			if not positions.has(from_id) or not positions.has(to_id):
				continue
			var delta: Vector2 = positions[to_id] - positions[from_id]
			var dist: float = maxf(delta.length(), 0.01)
			var key := "%s->%s" % [from_id, to_id]
			var spring_length: float = float(spring_lengths.get(key, dist))
			var desired: Vector2 = delta.normalized() * spring_length
			var spring: Vector2 = (delta - desired) * SPRING_STRENGTH
			forces[from_id] += spring
			forces[to_id] -= spring
			if from_id == root_id:
				forces[to_id] -= positions[to_id] * CENTER_PULL

		for id in ids:
			if id == root_id:
				positions[id] = Vector2.ZERO
				velocities[id] = Vector2.ZERO
				continue
			velocities[id] = (velocities[id] + forces[id]) * DAMPING
			positions[id] += velocities[id]


static func _separate_overlaps(positions: Dictionary, root_id: String) -> void:
	var ids: Array = positions.keys()
	ids.sort()
	for _iteration in SEPARATION_ITERATIONS:
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var id_a: String = ids[i]
				var id_b: String = ids[j]
				var delta: Vector2 = positions[id_a] - positions[id_b]
				var dist: float = maxf(delta.length(), 0.01)
				if dist >= MIN_NODE_DISTANCE:
					continue
				var push: Vector2 = delta.normalized() * (MIN_NODE_DISTANCE - dist) * 0.5
				if id_a != root_id:
					positions[id_a] += push
				if id_b != root_id:
					positions[id_b] -= push
		positions[root_id] = Vector2.ZERO


static func _deterministic_jitter(seed_text: String, min_value: float, max_value: float) -> float:
	var hash_value: int = abs(seed_text.hash())
	var t: float = float(hash_value % 10000) / 10000.0
	return lerpf(min_value, max_value, t)


static func min_pair_distance(positions: Dictionary) -> float:
	var ids: Array = positions.keys()
	ids.sort()
	var min_dist := INF
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var dist: float = positions[ids[i]].distance_to(positions[ids[j]])
			min_dist = minf(min_dist, dist)
	return min_dist if min_dist != INF else MIN_NODE_DISTANCE
