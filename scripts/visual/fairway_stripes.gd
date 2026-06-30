class_name FairwayStripes
extends RefCounted
## Procedural perspective fairway stripes — shared by range view and title screen.

const VANISHING_POINT := Vector2(240.0, 100.0)
const VIEWPORT_WIDTH := 480.0
const VIEWPORT_PAD := 120.0
const DEFAULT_TOP_Y := 105.0
const DEFAULT_BOTTOM_Y := 270.0
const BOTTOM_LEFT := -800.0
const BOTTOM_RIGHT := 1280.0
const STRIPE_COUNT := 24
const BASE_COLOR := Color(0.40, 0.58, 0.32)
const STRIPE_LIGHT := Color(0.54, 0.76, 0.44)
const STRIPE_DARK := Color(0.36, 0.52, 0.28)


static func build_polygons(
	top_y: float = DEFAULT_TOP_Y,
	bottom_y: float = DEFAULT_BOTTOM_Y,
	vanishing_point: Vector2 = VANISHING_POINT
) -> Array[Dictionary]:
	var polygons: Array[Dictionary] = []
	polygons.append({
		"color": BASE_COLOR,
		"polygon": PackedVector2Array([
			Vector2(-VIEWPORT_PAD, bottom_y),
			Vector2(VIEWPORT_WIDTH + VIEWPORT_PAD, bottom_y),
			Vector2(VIEWPORT_WIDTH + VIEWPORT_PAD, top_y),
			Vector2(-VIEWPORT_PAD, top_y),
		]),
	})

	var colors: Array[Color] = [STRIPE_LIGHT, STRIPE_DARK]
	var span := BOTTOM_RIGHT - BOTTOM_LEFT
	var segment_width := span / float(STRIPE_COUNT)
	for index in STRIPE_COUNT:
		var x0_bottom := BOTTOM_LEFT + index * segment_width
		var x1_bottom := BOTTOM_LEFT + (index + 1) * segment_width
		var x0_top := perspective_x_at_y(vanishing_point, x0_bottom, bottom_y, top_y)
		var x1_top := perspective_x_at_y(vanishing_point, x1_bottom, bottom_y, top_y)
		polygons.append({
			"color": colors[index % 2],
			"polygon": PackedVector2Array([
				Vector2(x0_bottom, bottom_y),
				Vector2(x1_bottom, bottom_y),
				Vector2(x1_top, top_y),
				Vector2(x0_top, top_y),
			]),
		})
	return polygons


## Full-viewport title fan — VP sits above the screen so top_y can be 0 without bow-tie quads.
static func build_title_screen_polygons() -> Array[Dictionary]:
	const TITLE_TOP_Y := 0.0
	const TITLE_BOTTOM_Y := 270.0
	const TITLE_VP := Vector2(240.0, -40.0)
	return build_polygons(TITLE_TOP_Y, TITLE_BOTTOM_Y, TITLE_VP)


static func populate(
	container: Node,
	top_y: float = DEFAULT_TOP_Y,
	bottom_y: float = DEFAULT_BOTTOM_Y
) -> void:
	for child in container.get_children():
		child.free()

	for entry in build_polygons(top_y, bottom_y):
		var stripe := Polygon2D.new()
		stripe.color = entry["color"]
		stripe.polygon = entry["polygon"]
		container.add_child(stripe)


static func perspective_x_at_y(
	vanishing_point: Vector2,
	x_at_far_y: float,
	y_far: float,
	y_near: float
) -> float:
	var denom := y_far - vanishing_point.y
	if absf(denom) < 0.001:
		return vanishing_point.x
	var t := (y_near - vanishing_point.y) / denom
	return vanishing_point.x + t * (x_at_far_y - vanishing_point.x)
