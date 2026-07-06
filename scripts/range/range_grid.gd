class_name RangeGrid
extends RefCounted
## v4 range coordinate system — 2 yd cells, 38 yd wide × 300 yd deep.

const CELL_SIZE_YARDS := 2.0
const GRID_WIDTH_CELLS := 19
const GRID_DEPTH_CELLS := 150
const HALF_WIDTH_YARDS := 19.0
const DEPTH_YARDS := 300.0

## Player bay — midline column, row 5 (10 yd into fairway from near edge).
const PLAYER_CELL := Vector2i(9, 5)
## Ratina default bay — one cell left of player, same depth row.
const RATINA_CELL := Vector2i(8, 5)


static func cell_x_bounds(col: int) -> Vector2:
	var x0 := -HALF_WIDTH_YARDS + float(col) * CELL_SIZE_YARDS
	return Vector2(x0, x0 + CELL_SIZE_YARDS)


static func cell_z_bounds(row: int) -> Vector2:
	var z_near := -float(row) * CELL_SIZE_YARDS
	return Vector2(z_near, z_near - CELL_SIZE_YARDS)


## Tee origin: center of the cell's near edge (Y = 0).
static func bay_origin(col: int, row: int) -> Vector3:
	var x_bounds := cell_x_bounds(col)
	var z_bounds := cell_z_bounds(row)
	return Vector3(
		(x_bounds.x + x_bounds.y) * 0.5,
		0.0,
		z_bounds.x
	)


static func player_bay_origin() -> Vector3:
	return bay_origin(PLAYER_CELL.x, PLAYER_CELL.y)


static func ratina_bay_origin() -> Vector3:
	return bay_origin(RATINA_CELL.x, RATINA_CELL.y)


static func is_edge_col(col: int) -> bool:
	return col == 0 or col == GRID_WIDTH_CELLS - 1


static func empty_bay_cells_on_player_row() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var row := PLAYER_CELL.y
	for col in GRID_WIDTH_CELLS:
		if is_edge_col(col):
			continue
		var cell := Vector2i(col, row)
		if cell == PLAYER_CELL or cell == RATINA_CELL:
			continue
		result.append(cell)
	return result
