class_name YardageMarkerLayout
extends RefCounted
## Shared 50–300 yd marker contract for RangeView (3D) and IsoView (2D).
## Matches Foreground/YardageMarkers in range_view.tscn.

const SIDE_X := 18.0
const Z_ORIGIN_BIAS := 10.57
const PIXEL_SIZE := 0.015
const TEXTURE_PX := 76.0
const YARDS := [50, 100, 150, 200, 250, 300]

const TEXTURE_PATHS := {
	50: "res://assets/sprites/range/yardage_markers/50-transparent.png",
	100: "res://assets/sprites/range/yardage_markers/100-transparent.png",
	150: "res://assets/sprites/range/yardage_markers/150-transparent.png",
	200: "res://assets/sprites/range/yardage_markers/200-transparent.png",
	250: "res://assets/sprites/range/yardage_markers/250-transparent.png",
	300: "res://assets/sprites/range/yardage_markers/300-transparent.png",
}


static func world_height_yards() -> float:
	return TEXTURE_PX * PIXEL_SIZE


static func z_for_yards(yards: int) -> float:
	return -(float(yards) + Z_ORIGIN_BIAS)


static func world_position(side_x: float, yards: int) -> Vector3:
	return Vector3(side_x, 0.0, z_for_yards(yards))


## Twelve entries: left then right for each yardage, matching scene child order intent.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for yards in YARDS:
		out.append(_entry(-SIDE_X, yards, "Left"))
		out.append(_entry(SIDE_X, yards, "Right"))
	return out


static func _entry(side_x: float, yards: int, side_name: String) -> Dictionary:
	return {
		"yards": yards,
		"side_x": side_x,
		"name": "Marker%d%s" % [yards, side_name],
		"world_pos": world_position(side_x, yards),
		"texture_path": TEXTURE_PATHS[yards],
	}
