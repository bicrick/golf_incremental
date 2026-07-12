class_name TooltipViewportClamp
extends RefCounted
## Keep hover tooltips fully inside the visible viewport after preferred placement.

const EDGE_MARGIN := 8.0


static func visible_bounds(from: Node) -> Rect2:
	if from == null:
		return Rect2(Vector2.ZERO, Vector2(480, 270))
	var viewport := from.get_viewport()
	if viewport == null:
		return Rect2(Vector2.ZERO, Vector2(480, 270))
	return viewport.get_visible_rect()


static func clamp_pos(pos: Vector2, tip_size: Vector2, bounds: Rect2, margin: float = EDGE_MARGIN) -> Vector2:
	var min_x := bounds.position.x + margin
	var min_y := bounds.position.y + margin
	var max_x := bounds.end.x - tip_size.x - margin
	var max_y := bounds.end.y - tip_size.y - margin
	# If tip is larger than the usable area, pin to the near edge.
	if max_x < min_x:
		max_x = min_x
	if max_y < min_y:
		max_y = min_y
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))
