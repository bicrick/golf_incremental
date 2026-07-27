class_name IsoWorldModel
extends RefCounted
## Occupancy map for isometric placements. Keys are cells; values are placement records.
## Bay cells from RangeGrid are reserved and non-buildable.

signal changed

## placement_id -> { "id": StringName, "anchor": Vector2i, "catalog_id": StringName }
var _placements: Dictionary = {}
## cell -> placement_id (occupancy)
var _occupancy: Dictionary = {}
## Scenery / tree-border cells that reject placement.
var _blocked: Dictionary = {}
var _next_id: int = 1


func clear() -> void:
	_placements.clear()
	_occupancy.clear()
	_blocked.clear()
	_next_id = 1
	changed.emit()


func block_cell(cell: Vector2i) -> void:
	_blocked[cell] = true


func block_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_blocked[cell] = true


func is_reserved(cell: Vector2i) -> bool:
	## `cell` is a TileMap / RangeGrid cell (1:1).
	if _blocked.has(cell):
		return true
	if cell.x < 0 or cell.x >= IsoGrid.iso_width_cells():
		return true
	if cell.y < 0 or cell.y >= IsoGrid.iso_depth_cells():
		return true
	var range_cell := IsoGrid.range_cell_from_iso_cell(cell)
	if range_cell == RangeGrid.PLAYER_CELL or range_cell == RangeGrid.RATINA_CELL:
		return true
	return false


func footprint_cells(anchor: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in footprint.x:
		for dy in footprint.y:
			cells.append(Vector2i(anchor.x + dx, anchor.y + dy))
	return cells


func can_place(catalog_id: StringName, anchor: Vector2i) -> bool:
	if not IsoCatalog.has(catalog_id):
		return false
	var fp := IsoCatalog.footprint(catalog_id)
	for cell in footprint_cells(anchor, fp):
		if is_reserved(cell):
			return false
		if _occupancy.has(cell):
			return false
	return true


func place(catalog_id: StringName, anchor: Vector2i) -> StringName:
	if not can_place(catalog_id, anchor):
		return &""
	var placement_id := StringName("p_%d" % _next_id)
	_next_id += 1
	var fp := IsoCatalog.footprint(catalog_id)
	_placements[placement_id] = {
		"id": placement_id,
		"anchor": anchor,
		"catalog_id": catalog_id,
	}
	for cell in footprint_cells(anchor, fp):
		_occupancy[cell] = placement_id
	changed.emit()
	return placement_id


func remove(placement_id: StringName) -> bool:
	if not _placements.has(placement_id):
		return false
	var record: Dictionary = _placements[placement_id]
	var catalog_id: StringName = record["catalog_id"]
	var anchor: Vector2i = record["anchor"]
	var fp := IsoCatalog.footprint(catalog_id)
	for cell in footprint_cells(anchor, fp):
		_occupancy.erase(cell)
	_placements.erase(placement_id)
	changed.emit()
	return true


func get_placement(placement_id: StringName) -> Dictionary:
	return _placements.get(placement_id, {})


func get_placement_at(cell: Vector2i) -> Dictionary:
	if not _occupancy.has(cell):
		return {}
	return get_placement(_occupancy[cell])


func all_placements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _placements.keys():
		out.append(_placements[key])
	return out


func serialize() -> Dictionary:
	var list: Array = []
	for key in _placements.keys():
		var record: Dictionary = _placements[key]
		list.append({
			"catalog_id": String(record["catalog_id"]),
			"anchor_x": (record["anchor"] as Vector2i).x,
			"anchor_y": (record["anchor"] as Vector2i).y,
		})
	return {"placements": list, "next_id": _next_id}


func deserialize(data: Dictionary) -> void:
	clear()
	_next_id = int(data.get("next_id", 1))
	var list: Array = data.get("placements", [])
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var catalog_id := StringName(str(item.get("catalog_id", "")))
		var anchor := Vector2i(int(item.get("anchor_x", 0)), int(item.get("anchor_y", 0)))
		if can_place(catalog_id, anchor):
			# Preserve sequential ids from next_id; place() advances it.
			place(catalog_id, anchor)
	# Restore next_id after bulk place (place advances it).
	_next_id = int(data.get("next_id", _next_id))
