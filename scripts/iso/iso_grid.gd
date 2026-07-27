class_name IsoGrid
extends RefCounted
## Bridge between RangeGrid yards and Godot 2D isometric TileMapLayer pixels.
## Tile shape: ISOMETRIC, layout: DIAMOND_DOWN, tile_size: 64x32.
## 1 TileMap cell = 1 RangeGrid cell (SUBCELLS = 1).
## Depth is flipped vs RangeGrid row so downrange aims screen top-right
## (tee / PLAYER_CELL toward bottom-left), matching the live range read.
##
## Pixel space is origin-shifted so the player address pose sits at (0,0).
## TileMapLayers must use position = -view_origin_px_raw() to match.

const TILE_PX := Vector2i(64, 32)
## TileMap cells per logical RangeGrid cell on each axis (1:1 parity).
const SUBCELLS := 1
## PixelLab flat diamond canvas height (no depth skirt).
const TILE_TEXTURE_HEIGHT := 32
## Vertical screen pixels per yard of altitude (airborne ball cheat).
const HEIGHT_PX_PER_YARD := 8.0
## World nudge from bay tee tip → player address pose (matches IsoActorMirror bias).
const VIEW_ORIGIN_BIAS_YARDS := Vector3(-0.35, 0.0, -0.85)


static func iso_width_cells() -> int:
	return RangeGrid.GRID_WIDTH_CELLS * SUBCELLS


static func iso_depth_cells() -> int:
	return RangeGrid.GRID_DEPTH_CELLS * SUBCELLS


## Flip RangeGrid depth so increasing row (downrange) → decreasing iso Y
## (screen top-right under DIAMOND_DOWN).
static func _flip_depth_iso(range_y: float) -> float:
	return float(iso_depth_cells()) - range_y


static func _flip_depth_range(iso_y: float) -> float:
	return float(iso_depth_cells()) - iso_y


## Anchor iso cell for a RangeGrid cell (depth flipped).
static func iso_cell_from_range_cell(range_cell: Vector2i) -> Vector2i:
	var origin_x := range_cell.x * SUBCELLS
	var origin_y := int(_flip_depth_iso(float((range_cell.y + 1) * SUBCELLS)))
	return Vector2i(origin_x, origin_y)


## RangeGrid cell containing an iso TileMap cell.
static func range_cell_from_iso_cell(iso_cell: Vector2i) -> Vector2i:
	var range_y_end := _flip_depth_range(float(iso_cell.y))
	var range_y := int(ceil(range_y_end / float(SUBCELLS))) - 1
	return Vector2i(
		int(floor(float(iso_cell.x) / float(SUBCELLS))),
		range_y
	)


## All iso cells covered by one RangeGrid cell.
static func iso_cells_for_range_cell(range_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var origin := iso_cell_from_range_cell(range_cell)
	for dx in SUBCELLS:
		for dy in SUBCELLS:
			cells.append(Vector2i(origin.x + dx, origin.y + dy))
	return cells


## Cell containing a world-yards point. X maps to column, -Z maps to row depth.
static func cell_from_yards(p: Vector3) -> Vector2i:
	var col := int(floor((p.x + RangeGrid.HALF_WIDTH_YARDS) / RangeGrid.CELL_SIZE_YARDS))
	var row := int(floor((-p.z) / RangeGrid.CELL_SIZE_YARDS))
	return Vector2i(col, row)


## World-yards center of a RangeGrid cell (y = 0).
static func yards_from_cell(cell: Vector2i) -> Vector3:
	var x_bounds := RangeGrid.cell_x_bounds(cell.x)
	var z_bounds := RangeGrid.cell_z_bounds(cell.y)
	return Vector3(
		(x_bounds.x + x_bounds.y) * 0.5,
		0.0,
		(z_bounds.x + z_bounds.y) * 0.5
	)


## Continuous fractional RangeGrid cell coords from world yards.
static func cellf_from_yards(p: Vector3) -> Vector2:
	var col := (p.x + RangeGrid.HALF_WIDTH_YARDS) / RangeGrid.CELL_SIZE_YARDS
	var row := (-p.z) / RangeGrid.CELL_SIZE_YARDS
	return Vector2(col, row)


## Continuous iso TileMap cell coords (depth flipped).
static func iso_cellf_from_yards(p: Vector3) -> Vector2:
	var cf := cellf_from_yards(p)
	return Vector2(cf.x * float(SUBCELLS), _flip_depth_iso(cf.y * float(SUBCELLS)))


## Player address pose in world yards — IsoView local (0,0).
static func view_origin_yards() -> Vector3:
	return RangeGrid.player_bay_origin() + VIEW_ORIGIN_BIAS_YARDS


## Unshifted Godot map_to_local of the view origin (TileMapLayer.position = -this).
static func view_origin_px_raw() -> Vector2:
	return _iso_px_from_cellf_raw(iso_cellf_from_yards(view_origin_yards()))


## Godot DIAMOND_DOWN map_to_local for continuous iso cell coords (unshifted).
static func _iso_px_from_cellf_raw(cf: Vector2) -> Vector2:
	var tw := float(TILE_PX.x)
	var th := float(TILE_PX.y)
	return Vector2(
		(cf.x - cf.y) * (tw * 0.5) + tw * 0.5,
		(cf.x + cf.y) * (th * 0.5) + th * 0.5
	)


static func iso_px_from_cellf_raw(cf: Vector2) -> Vector2:
	return _iso_px_from_cellf_raw(cf)


static func iso_px_from_cell_raw(cell: Vector2i) -> Vector2:
	return _iso_px_from_cellf_raw(Vector2(cell))


## Godot DIAMOND_DOWN map_to_local, shifted so view origin is (0,0).
static func iso_px_from_cellf(cf: Vector2) -> Vector2:
	return _iso_px_from_cellf_raw(cf) - view_origin_px_raw()


static func iso_px_from_cell(cell: Vector2i) -> Vector2:
	return iso_px_from_cellf(Vector2(cell))


## Screen position for a world-yards point on the TileMap (origin-shifted).
static func iso_px_from_yards(p: Vector3) -> Vector2:
	var px := _iso_px_from_cellf_raw(iso_cellf_from_yards(p))
	px.y -= height_px(p.y)
	return px - view_origin_px_raw()


## Screen-px semi-axes of a world-XZ ground circle (axis-aligned, 2:1 on 64x32).
static func iso_px_radii_from_yards(radius_yards: float) -> Vector2:
	var cells := radius_yards / RangeGrid.CELL_SIZE_YARDS
	return Vector2(float(TILE_PX.x), float(TILE_PX.y)) * 0.5 * cells * sqrt(2.0)


static func height_px(altitude_yards: float) -> float:
	return altitude_yards * HEIGHT_PX_PER_YARD


## Inverse of iso_px_from_cellf (ground plane only; ignores altitude).
static func cellf_from_iso_px(px: Vector2) -> Vector2:
	return _cellf_from_iso_px_raw(px + view_origin_px_raw())


static func _cellf_from_iso_px_raw(px: Vector2) -> Vector2:
	var tw := float(TILE_PX.x)
	var th := float(TILE_PX.y)
	var lx := px.x - tw * 0.5
	var ly := px.y - th * 0.5
	var col := (lx / (tw * 0.5) + ly / (th * 0.5)) * 0.5
	var row := (ly / (th * 0.5) - lx / (tw * 0.5)) * 0.5
	return Vector2(col, row)


static func cell_from_iso_px(px: Vector2) -> Vector2i:
	var cf := cellf_from_iso_px(px)
	return Vector2i(int(floor(cf.x)), int(floor(cf.y)))


## Ground yards from an IsoView-local pixel (altitude ignored).
static func yards_from_iso_px(px: Vector2) -> Vector3:
	var iso_cf := cellf_from_iso_px(px)
	var range_col := iso_cf.x / float(SUBCELLS)
	var range_row := _flip_depth_range(iso_cf.y) / float(SUBCELLS)
	return Vector3(
		range_col * RangeGrid.CELL_SIZE_YARDS - RangeGrid.HALF_WIDTH_YARDS,
		0.0,
		-range_row * RangeGrid.CELL_SIZE_YARDS
	)
