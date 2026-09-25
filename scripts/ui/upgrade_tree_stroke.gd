class_name UpgradeTreeStroke
extends RefCounted
## Shared stroke widths, colors, and solid-line drawing for upgrade tree edges/borders.

const UpgradeGraph = preload("res://scripts/game/upgrades/graph.gd")

enum EdgeState { DORMANT, LIVE, CHARGED, COMPLETE }
enum BorderState { LOCKED, DEFAULT, AFFORD, MAXED }

## v5 menu refresh — chunkier pixel paths + framed parchment medallions.
const EDGE_WIDTH := 3.0
const EDGE_GLOW_WIDTH := 7.0
## Dark under-stroke so paths read against bright sky/clouds.
const EDGE_CASING_WIDTH := 2.0
const EDGE_CASING_COLOR := Color(0.12, 0.16, 0.10, 0.55)
const BORDER_WIDTH := 2.0
const BORDER_GLOW_WIDTH := 4.0
const BORDER_WIDTH_MAXED := 3.0
const CORNER_RADIUS := 2.0
## Pixel stair cut on each corner (44×44 medallion → chunky rounded square).
const PIXEL_CORNER_CUT := 5
const CIRCLE_SEGMENTS := 28
const FILL_COLOR := Color(0.98, 0.95, 0.86, 1.0)
## Lower-right bevel band + top-left highlight on the parchment medallion.
const FILL_SHADE := Color(0.88, 0.83, 0.70, 1.0)
const FILL_HIGHLIGHT := Color(1.0, 1.0, 0.96, 1.0)
## Hard pixel drop shadow under each medallion.
const SHADOW_COLOR := Color(0.10, 0.16, 0.10, 0.35)
const SHADOW_OFFSET := Vector2(2, 3)
const GLOW_ALPHA_SCALE := 0.65
## Phase wrap for alpha pulse (no dash marching).
const PULSE_PERIOD := TAU

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
		_phase = fmod(_phase, PULSE_PERIOD)


static func pulse_alpha(phase: float, speed_mult: float, base_alpha: float = 1.0) -> float:
	## Subtle breathe for charged afford cues — solid stroke, no gaps.
	var wave := 0.82 + 0.18 * sin(phase * speed_mult * 4.0)
	return clampf(base_alpha * wave, 0.0, 1.0)


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
				"animated": false,
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
				"animated": false,
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
	var stroke := color
	var soft := Color(
		glow_color.r, glow_color.g, glow_color.b, glow_color.a * GLOW_ALPHA_SCALE
	)
	if animated:
		stroke = Color(color.r, color.g, color.b, pulse_alpha(phase, speed_mult, color.a))
		soft = Color(soft.r, soft.g, soft.b, pulse_alpha(phase, speed_mult, soft.a))
	if with_glow:
		canvas.draw_line(from_point, to_point, soft, EDGE_GLOW_WIDTH)
	var casing := EDGE_CASING_COLOR
	casing.a *= clampf(color.a, 0.0, 1.0)
	canvas.draw_line(from_point, to_point, casing, width + EDGE_CASING_WIDTH * 2.0)
	canvas.draw_line(from_point, to_point, stroke, width)


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
		var body := _pixel_squircle_points(inner, cut, false)
		var shadow := PackedVector2Array()
		for p in body:
			shadow.append(p + SHADOW_OFFSET)
		canvas.draw_colored_polygon(shadow, SHADOW_COLOR)
		canvas.draw_colored_polygon(body, FILL_SHADE)
		var top_rect := Rect2(inner.position, inner.size - Vector2(3, 3))
		canvas.draw_colored_polygon(
			_pixel_squircle_points(top_rect, maxi(cut - 1, 1), false), FILL_COLOR
		)
		canvas.draw_line(
			inner.position + Vector2(cut + 1, 2),
			Vector2(inner.end.x - cut - 3, inner.position.y + 2),
			FILL_HIGHLIGHT,
			1.0
		)
	var points := _pixel_squircle_points(inner, cut, true)
	if points.size() < 2:
		return
	var stroke := color
	var soft := Color(
		glow_color.r, glow_color.g, glow_color.b, glow_color.a * GLOW_ALPHA_SCALE
	)
	if animated:
		stroke = Color(color.r, color.g, color.b, pulse_alpha(phase, SPEED_BORDER, color.a))
		soft = Color(soft.r, soft.g, soft.b, pulse_alpha(phase, SPEED_BORDER, soft.a))
	if with_glow:
		canvas.draw_polyline(points, soft, BORDER_GLOW_WIDTH, false)
	canvas.draw_polyline(points, stroke, width, false)


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
	if points.size() < 2:
		return
	var stroke := color
	var soft := Color(
		glow_color.r, glow_color.g, glow_color.b, glow_color.a * GLOW_ALPHA_SCALE
	)
	if animated:
		stroke = Color(color.r, color.g, color.b, pulse_alpha(phase, SPEED_BORDER, color.a))
		soft = Color(soft.r, soft.g, soft.b, pulse_alpha(phase, SPEED_BORDER, soft.a))
	if with_glow:
		canvas.draw_polyline(points, soft, BORDER_GLOW_WIDTH, false)
	canvas.draw_polyline(points, stroke, width, false)


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

