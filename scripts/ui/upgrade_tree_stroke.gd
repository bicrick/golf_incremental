class_name UpgradeTreeStroke
extends RefCounted
## Shared stroke widths, colors, and dash drawing for upgrade tree edges/borders.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")
const PrestigeDefinitionsScript = preload("res://scripts/game/prestige/definitions.gd")

enum EdgeState { DORMANT, LIVE, CHARGED, COMPLETE }
enum BorderState { LOCKED, DEFAULT, AFFORD, MAXED }

const EDGE_WIDTH := 1.5
const EDGE_GLOW_WIDTH := 3.5
const BORDER_WIDTH := 1.0
const BORDER_GLOW_WIDTH := 2.0
const BORDER_WIDTH_MAXED := 2.0
const CORNER_RADIUS := 2.0
## Pixel stair cut on each corner (44×44 medallion → chunky rounded square).
const PIXEL_CORNER_CUT := 3
const CIRCLE_SEGMENTS := 28
const FILL_COLOR := Color(0.12, 0.10, 0.08, 0.55)
const GLOW_ALPHA_SCALE := 0.65

const DASH_LENGTH := 4.0
const DASH_GAP := 3.5
const DASH_PERIOD := DASH_LENGTH + DASH_GAP

const SPEED_LIVE := 0.55
const SPEED_CHARGED := 1.15
const SPEED_COMPLETE := 0.18
const SPEED_BORDER := 0.9

# Base Pay — warm gold
const COLOR_BASE_PAY_LINE := Color(0.55, 0.48, 0.32, 0.85)
const COLOR_BASE_PAY_LINE_LOCKED := Color(0.35, 0.32, 0.28, 0.5)
const COLOR_BASE_PAY_LIVE := Color(0.88, 0.74, 0.32, 0.92)
const COLOR_BASE_PAY_CHARGED := Color(1.0, 0.9, 0.42, 1.0)
const COLOR_BASE_PAY_COMPLETE := Color(0.82, 0.68, 0.28, 0.95)
const COLOR_BASE_PAY_GLOW := Color(1.0, 0.92, 0.45, 0.28)

# Power — true red (distinct from Ratina pink)
const COLOR_POWER_LINE := Color(0.72, 0.22, 0.18, 0.9)
const COLOR_POWER_LINE_LOCKED := Color(0.42, 0.22, 0.20, 0.5)
const COLOR_POWER_LIVE := Color(0.95, 0.28, 0.22, 0.95)
const COLOR_POWER_CHARGED := Color(1.0, 0.35, 0.25, 1.0)
const COLOR_POWER_COMPLETE := Color(0.88, 0.24, 0.18, 0.95)
const COLOR_POWER_GLOW := Color(1.0, 0.40, 0.28, 0.32)

# Quality / tempo — teal-blue
const COLOR_QUALITY_LINE := Color(0.32, 0.48, 0.58, 0.85)
const COLOR_QUALITY_LINE_LOCKED := Color(0.28, 0.32, 0.38, 0.5)
const COLOR_QUALITY_LIVE := Color(0.38, 0.72, 0.92, 0.92)
const COLOR_QUALITY_CHARGED := Color(0.48, 0.88, 1.0, 1.0)
const COLOR_QUALITY_COMPLETE := Color(0.32, 0.68, 0.82, 0.95)
const COLOR_QUALITY_GLOW := Color(0.48, 0.88, 1.0, 0.28)

# Pickup — green
const COLOR_PICKUP_LINE := Color(0.42, 0.52, 0.28, 0.85)
const COLOR_PICKUP_LINE_LOCKED := Color(0.32, 0.35, 0.28, 0.5)
const COLOR_PICKUP_LIVE := Color(0.68, 0.82, 0.32, 0.92)
const COLOR_PICKUP_CHARGED := Color(0.86, 1.0, 0.45, 1.0)
const COLOR_PICKUP_COMPLETE := Color(0.68, 0.82, 0.28, 0.95)
const COLOR_PICKUP_GLOW := Color(0.86, 1.0, 0.45, 0.28)

# Ratina — pink (hire + Ratina subtree)
const COLOR_RATINA_LINE := Color(0.62, 0.38, 0.48, 0.85)
const COLOR_RATINA_LINE_LOCKED := Color(0.42, 0.30, 0.36, 0.5)
const COLOR_RATINA_LIVE := Color(0.95, 0.55, 0.72, 0.92)
const COLOR_RATINA_CHARGED := Color(1.0, 0.68, 0.82, 1.0)
const COLOR_RATINA_COMPLETE := Color(0.88, 0.48, 0.66, 0.95)
const COLOR_RATINA_GLOW := Color(1.0, 0.72, 0.85, 0.28)

static var _phase := 0.0


static func get_phase() -> float:
	return _phase


static func advance_phase(delta: float) -> void:
	_phase += delta
	if _phase > 1000.0:
		_phase = fmod(_phase, DASH_PERIOD)


static func _ratina_palette() -> Dictionary:
	return {
		"dormant": COLOR_RATINA_LINE_LOCKED,
		"live": COLOR_RATINA_LIVE,
		"charged": COLOR_RATINA_CHARGED,
		"complete": COLOR_RATINA_COMPLETE,
		"glow": COLOR_RATINA_GLOW,
		"base": COLOR_RATINA_LINE,
	}


static func palette_for_branch(branch: int) -> Dictionary:
	match branch:
		Balance.UpgradeBranch.POWER:
			return {
				"dormant": COLOR_POWER_LINE_LOCKED,
				"live": COLOR_POWER_LIVE,
				"charged": COLOR_POWER_CHARGED,
				"complete": COLOR_POWER_COMPLETE,
				"glow": COLOR_POWER_GLOW,
				"base": COLOR_POWER_LINE,
			}
		Balance.UpgradeBranch.QUALITY:
			return {
				"dormant": COLOR_QUALITY_LINE_LOCKED,
				"live": COLOR_QUALITY_LIVE,
				"charged": COLOR_QUALITY_CHARGED,
				"complete": COLOR_QUALITY_COMPLETE,
				"glow": COLOR_QUALITY_GLOW,
				"base": COLOR_QUALITY_LINE,
			}
		Balance.UpgradeBranch.PICKUP:
			return {
				"dormant": COLOR_PICKUP_LINE_LOCKED,
				"live": COLOR_PICKUP_LIVE,
				"charged": COLOR_PICKUP_CHARGED,
				"complete": COLOR_PICKUP_COMPLETE,
				"glow": COLOR_PICKUP_GLOW,
				"base": COLOR_PICKUP_LINE,
			}
		_:
			return {
				"dormant": COLOR_BASE_PAY_LINE_LOCKED,
				"live": COLOR_BASE_PAY_LIVE,
				"charged": COLOR_BASE_PAY_CHARGED,
				"complete": COLOR_BASE_PAY_COMPLETE,
				"glow": COLOR_BASE_PAY_GLOW,
				"base": COLOR_BASE_PAY_LINE,
			}


static func is_ratina_upgrade(upgrade_id: String) -> bool:
	if upgrade_id.is_empty():
		return false
	if upgrade_id == "ratina_hire" or upgrade_id.begins_with("ratina_"):
		return true
	return UpgradeGraph.namespace_for(upgrade_id) == UpgradeGraph.NAMESPACE_RATINA


static func palette_for_upgrade(upgrade_id: String) -> Dictionary:
	if is_ratina_upgrade(upgrade_id):
		return _ratina_palette()
	return palette_for_branch(branch_for_upgrade(upgrade_id))


static func branch_for_upgrade(upgrade_id: String) -> int:
	var def := UpgradeGraph.get_def(upgrade_id)
	if def.is_empty():
		def = PrestigeDefinitionsScript.get_def(upgrade_id)
	return int(def.get("branch", Balance.UpgradeBranch.BASE_PAY))


static func border_color_for_upgrade(upgrade_id: String, state: BorderState) -> Color:
	var palette := palette_for_upgrade(upgrade_id)
	match state:
		BorderState.LOCKED:
			return palette["dormant"]
		BorderState.AFFORD:
			return palette["charged"]
		BorderState.MAXED:
			return palette["complete"]
		_:
			return palette["base"]


static func border_color_for(branch: int, state: BorderState) -> Color:
	var palette := palette_for_branch(branch)
	match state:
		BorderState.LOCKED:
			return palette["dormant"]
		BorderState.AFFORD:
			return palette["charged"]
		BorderState.MAXED:
			return palette["complete"]
		_:
			return palette["base"]


static func glow_color_for_upgrade(upgrade_id: String) -> Color:
	return palette_for_upgrade(upgrade_id)["glow"]


static func glow_color_for(branch: int) -> Color:
	return palette_for_branch(branch)["glow"]


static func edge_style_for_upgrade(state: EdgeState, upgrade_id: String) -> Dictionary:
	return edge_style(state, branch_for_upgrade(upgrade_id), upgrade_id)


static func edge_style(state: EdgeState, branch: int, upgrade_id: String = "") -> Dictionary:
	var palette := (
		palette_for_upgrade(upgrade_id) if not upgrade_id.is_empty() else palette_for_branch(branch)
	)
	match state:
		EdgeState.DORMANT:
			return {
				"color": palette["dormant"],
				"width": EDGE_WIDTH * 0.85,
				"animated": false,
				"speed": 0.0,
				"glow": false,
			}
		EdgeState.LIVE:
			return {
				"color": palette["live"],
				"width": EDGE_WIDTH,
				"animated": true,
				"speed": SPEED_LIVE,
				"glow": false,
			}
		EdgeState.CHARGED:
			return {
				"color": palette["charged"],
				"width": EDGE_WIDTH,
				"animated": true,
				"speed": SPEED_CHARGED,
				"glow": true,
			}
		EdgeState.COMPLETE:
			return {
				"color": palette["complete"],
				"width": EDGE_WIDTH,
				"animated": true,
				"speed": SPEED_COMPLETE,
				"glow": true,
			}
		_:
			return {
				"color": palette["dormant"],
				"width": EDGE_WIDTH,
				"animated": false,
				"speed": 0.0,
				"glow": false,
			}


static func draw_flow_segment(
	canvas: CanvasItem,
	from_point: Vector2,
	to_point: Vector2,
	color: Color,
	width: float,
	phase: float,
	speed_mult: float,
	animated: bool,
	with_glow: bool = false,
	glow_color: Color = COLOR_BASE_PAY_GLOW
) -> void:
	var delta := to_point - from_point
	var length := delta.length()
	if length < 0.5:
		return
	var dir := delta / length
	if with_glow:
		var soft := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a)
		if animated:
			_draw_dashed_line(canvas, from_point, dir, length, soft, EDGE_GLOW_WIDTH, phase, speed_mult)
		else:
			canvas.draw_line(from_point, to_point, soft, EDGE_GLOW_WIDTH)
	if animated:
		_draw_dashed_line(canvas, from_point, dir, length, color, width, phase, speed_mult)
	else:
		canvas.draw_line(from_point, to_point, color, width)


static func squircle_corner_radius(size: Vector2) -> float:
	## Pixel stair depth (not a smooth arc radius).
	return float(pixel_corner_cut(size))


static func pixel_corner_cut(size: Vector2) -> int:
	var max_cut := int(floor(minf(size.x, size.y) * 0.5)) - 1
	return clampi(PIXEL_CORNER_CUT, 1, maxi(max_cut, 1))


static func draw_rounded_border(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	width: float,
	phase: float,
	animated: bool,
	with_glow: bool = false,
	glow_color: Color = COLOR_BASE_PAY_GLOW
) -> void:
	draw_squircle_border(canvas, rect, color, width, phase, animated, with_glow, glow_color, true)


static func draw_squircle_border(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	width: float,
	phase: float,
	animated: bool,
	with_glow: bool = false,
	glow_color: Color = COLOR_BASE_PAY_GLOW,
	draw_fill: bool = true
) -> void:
	var snapped := _snap_rect(rect)
	var inset := maxf(width * 0.5, 0.5)
	var inner := snapped.grow(-inset)
	inner = _snap_rect(inner)
	if inner.size.x < 2.0 or inner.size.y < 2.0:
		return
	var cut := pixel_corner_cut(inner.size)
	if draw_fill:
		canvas.draw_colored_polygon(_pixel_squircle_points(inner, cut, false), FILL_COLOR)
	var points := _pixel_squircle_points(inner, cut, true)
	var perimeter := _polyline_length(points)
	if perimeter < 1.0:
		return
	if with_glow:
		var soft := Color(
			glow_color.r, glow_color.g, glow_color.b, glow_color.a * GLOW_ALPHA_SCALE
		)
		if animated:
			_draw_dashed_polyline(canvas, points, perimeter, soft, BORDER_GLOW_WIDTH, phase, SPEED_BORDER)
		else:
			canvas.draw_polyline(points, soft, BORDER_GLOW_WIDTH, true)
	if animated:
		_draw_dashed_polyline(canvas, points, perimeter, color, width, phase, SPEED_BORDER)
	else:
		canvas.draw_polyline(points, color, width, true)


static func draw_circle_border(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	width: float,
	phase: float,
	animated: bool,
	with_glow: bool = false,
	glow_color: Color = COLOR_BASE_PAY_GLOW,
	draw_fill: bool = true
) -> void:
	## Legacy circle path — prefer draw_squircle_border for tree nodes.
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.5 - width * 0.5
	if radius < 1.0:
		return
	if draw_fill:
		canvas.draw_circle(center, radius, FILL_COLOR)
	var points := _circle_points(center, radius)
	var perimeter := _polyline_length(points)
	if perimeter < 1.0:
		return
	if with_glow:
		var soft := Color(
			glow_color.r, glow_color.g, glow_color.b, glow_color.a * GLOW_ALPHA_SCALE
		)
		if animated:
			_draw_dashed_polyline(canvas, points, perimeter, soft, BORDER_GLOW_WIDTH, phase, SPEED_BORDER)
		else:
			canvas.draw_polyline(points, soft, BORDER_GLOW_WIDTH, true)
	if animated:
		_draw_dashed_polyline(canvas, points, perimeter, color, width, phase, SPEED_BORDER)
	else:
		canvas.draw_polyline(points, color, width, true)


## Rim point on a centered pixel squircle from `center` toward `toward`.
static func squircle_rim_point(
	center: Vector2,
	toward: Vector2,
	half_extents: Vector2,
	corner_radius: float = -1.0,
	inset: float = 0.92
) -> Vector2:
	var delta := toward - center
	if delta.length_squared() < 1.0:
		return center
	var dir := delta.normalized()
	var size := half_extents * 2.0
	var cut := int(round(corner_radius)) if corner_radius >= 0.0 else pixel_corner_cut(size)
	cut = clampi(cut, 1, pixel_corner_cut(size))
	var local_rect := Rect2(-half_extents, size)
	var points := _pixel_squircle_points(local_rect, cut, true)
	var hit_t := _ray_polyline_exit_t(Vector2.ZERO, dir, points)
	if hit_t < 0.0:
		# Fallback: axis box.
		var tx := INF if absf(dir.x) < 0.0001 else half_extents.x / absf(dir.x)
		var ty := INF if absf(dir.y) < 0.0001 else half_extents.y / absf(dir.y)
		hit_t = minf(tx, ty)
	return center + dir * hit_t * inset


static func _snap_rect(rect: Rect2) -> Rect2:
	var pos := Vector2(roundf(rect.position.x), roundf(rect.position.y))
	var end := Vector2(roundf(rect.end.x), roundf(rect.end.y))
	return Rect2(pos, end - pos)


static func _circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(CIRCLE_SEGMENTS + 1):
		var angle := TAU * float(i) / float(CIRCLE_SEGMENTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Axis-aligned pixel stair outline (chunky rounded square).
static func _pixel_squircle_points(rect: Rect2, cut: int, close: bool = true) -> PackedVector2Array:
	var c := clampi(cut, 1, int(floor(minf(rect.size.x, rect.size.y) * 0.5)) - 1)
	var left := roundf(rect.position.x)
	var top := roundf(rect.position.y)
	var right := roundf(rect.end.x)
	var bottom := roundf(rect.end.y)
	var points := PackedVector2Array()
	# Top edge.
	points.append(Vector2(left + c, top))
	points.append(Vector2(right - c, top))
	# Top-right stair down-right.
	for i in range(1, c + 1):
		points.append(Vector2(right - c + i, top + i))
	# Right edge.
	points.append(Vector2(right, bottom - c))
	# Bottom-right stair down-left.
	for i in range(1, c + 1):
		points.append(Vector2(right - i, bottom - c + i))
	# Bottom edge.
	points.append(Vector2(left + c, bottom))
	# Bottom-left stair up-left.
	for i in range(1, c + 1):
		points.append(Vector2(left + c - i, bottom - i))
	# Left edge.
	points.append(Vector2(left, top + c))
	# Top-left stair up-right (stop before repeating the first vertex).
	for i in range(1, c):
		points.append(Vector2(left + i, top + c - i))
	if close and not points.is_empty():
		points.append(points[0])
	return points


static func _ray_polyline_exit_t(origin: Vector2, dir: Vector2, points: PackedVector2Array) -> float:
	var best_t := -1.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg := b - a
		var denom := dir.x * seg.y - dir.y * seg.x
		if absf(denom) < 0.0001:
			continue
		var ao := a - origin
		var t := (ao.x * seg.y - ao.y * seg.x) / denom
		var u := (ao.x * dir.y - ao.y * dir.x) / denom
		if t > 0.001 and u >= -0.001 and u <= 1.001:
			if best_t < 0.0 or t < best_t:
				best_t = t
	return best_t


static func _draw_dashed_line(
	canvas: CanvasItem,
	from_point: Vector2,
	dir: Vector2,
	length: float,
	color: Color,
	width: float,
	phase: float,
	speed_mult: float
) -> void:
	var offset := fposmod(phase * speed_mult * DASH_PERIOD, DASH_PERIOD)
	var cursor := -offset
	while cursor < length:
		var dash_start := maxf(cursor, 0.0)
		var dash_end := minf(cursor + DASH_LENGTH, length)
		if dash_end > dash_start:
			canvas.draw_line(from_point + dir * dash_start, from_point + dir * dash_end, color, width)
		cursor += DASH_PERIOD


static func _draw_dashed_polyline(
	canvas: CanvasItem,
	points: PackedVector2Array,
	perimeter: float,
	color: Color,
	width: float,
	phase: float,
	speed_mult: float
) -> void:
	var offset := fposmod(phase * speed_mult * DASH_PERIOD, DASH_PERIOD)
	var cursor := -offset
	while cursor < perimeter:
		var dash_start := maxf(cursor, 0.0)
		var dash_end := minf(cursor + DASH_LENGTH, perimeter)
		if dash_end > dash_start:
			_draw_polyline_span(canvas, points, dash_start, dash_end, color, width)
		cursor += DASH_PERIOD


static func _draw_polyline_span(
	canvas: CanvasItem,
	points: PackedVector2Array,
	start_dist: float,
	end_dist: float,
	color: Color,
	width: float
) -> void:
	var traveled := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg_len := a.distance_to(b)
		if seg_len < 0.001:
			continue
		var seg_start := traveled
		var seg_end := traveled + seg_len
		var overlap_start := maxf(start_dist, seg_start)
		var overlap_end := minf(end_dist, seg_end)
		if overlap_end > overlap_start:
			var t0 := (overlap_start - seg_start) / seg_len
			var t1 := (overlap_end - seg_start) / seg_len
			canvas.draw_line(a.lerp(b, t0), a.lerp(b, t1), color, width)
		traveled = seg_end
		if traveled >= end_dist:
			break


static func _rounded_rect_points(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var points := PackedVector2Array()
	# Top edge left→right, then clockwise with simple corner chamfers (2 samples).
	points.append(Vector2(left + r, top))
	points.append(Vector2(right - r, top))
	points.append(Vector2(right, top + r))
	points.append(Vector2(right, bottom - r))
	points.append(Vector2(right - r, bottom))
	points.append(Vector2(left + r, bottom))
	points.append(Vector2(left, bottom - r))
	points.append(Vector2(left, top + r))
	points.append(Vector2(left + r, top))
	return points


static func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total
