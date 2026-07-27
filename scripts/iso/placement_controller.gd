class_name PlacementController
extends Node
## Ghost preview + click-to-place for IsoView buildings/props.
## Placement is triggered by IsoView on LMB release (so drag-pan wins).

signal placed(placement_id: StringName, catalog_id: StringName, anchor: Vector2i)

const VALID_TINT := Color(0.55, 1.0, 0.55, 0.7)
const INVALID_TINT := Color(1.0, 0.45, 0.45, 0.7)

var _terrain: TileMapLayer
var _objects: Node2D
var _overlay: Node2D
var _model: IsoWorldModel
var _ghost: Sprite2D
var _active_catalog_id: StringName = &""
var _enabled := false
var _hover_cell := Vector2i(-9999, -9999)


func setup(terrain: TileMapLayer, objects: Node2D, overlay: Node2D, model: IsoWorldModel) -> void:
	_terrain = terrain
	_objects = objects
	_overlay = overlay
	_model = model
	_ensure_ghost()
	if _model != null and not _model.changed.is_connected(_rebuild_objects):
		_model.changed.connect(_rebuild_objects)
	_rebuild_objects()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _ghost:
		_ghost.visible = enabled and _active_catalog_id != &""
	set_process(enabled)
	# Input is owned by IsoView so pan/zoom can run first.
	set_process_unhandled_input(false)


func is_enabled() -> bool:
	return _enabled


func set_active_catalog_id(catalog_id: StringName) -> void:
	_active_catalog_id = catalog_id
	_ensure_ghost()
	if _ghost == null:
		return
	if catalog_id == &"":
		_ghost.texture = null
		_ghost.visible = false
		return
	var tex := IsoCatalog.load_texture(catalog_id)
	_ghost.texture = tex
	var entry := IsoCatalog.get_entry(catalog_id)
	_ghost.offset = entry.get("anchor_offset", Vector2.ZERO)
	var s: float = float(entry.get("scale", 1.0))
	_ghost.scale = Vector2(s, s)
	_ghost.visible = _enabled and tex != null


func get_active_catalog_id() -> StringName:
	return _active_catalog_id


## Place at the current hover cell. Called by IsoView on LMB release.
func try_place_hover() -> bool:
	if not _enabled or _active_catalog_id == &"":
		return false
	return _try_place_at(_hover_cell)


func _process(_delta: float) -> void:
	if not _enabled or _terrain == null or _active_catalog_id == &"":
		if _ghost:
			_ghost.visible = false
		return
	var local := _terrain.to_local(_terrain.get_global_mouse_position())
	var cell := _terrain.local_to_map(local)
	if cell != _hover_cell:
		_hover_cell = cell
		_update_ghost()
	elif _ghost:
		_ghost.visible = true
		_update_ghost()


func _try_place_at(cell: Vector2i) -> bool:
	if _model == null:
		return false
	if not _model.can_place(_active_catalog_id, cell):
		return false
	var placement_id := _model.place(_active_catalog_id, cell)
	if placement_id == &"":
		return false
	placed.emit(placement_id, _active_catalog_id, cell)
	return true


func _update_ghost() -> void:
	if _ghost == null or _terrain == null:
		return
	_ghost.position = IsoGrid.iso_px_from_cell(_hover_cell)
	var valid := _model != null and _model.can_place(_active_catalog_id, _hover_cell)
	_ghost.modulate = VALID_TINT if valid else INVALID_TINT
	_ghost.visible = _enabled and _active_catalog_id != &"" and _ghost.texture != null


func _ensure_ghost() -> void:
	if _overlay == null:
		return
	if _ghost != null and is_instance_valid(_ghost):
		return
	_ghost = Sprite2D.new()
	_ghost.name = "PlacementGhost"
	_ghost.z_index = 100
	_ghost.visible = false
	_overlay.add_child(_ghost)


func _rebuild_objects() -> void:
	if _objects == null or _model == null or _terrain == null:
		return
	for child in _objects.get_children():
		_objects.remove_child(child)
		child.queue_free()
	for record in _model.all_placements():
		var catalog_id: StringName = record["catalog_id"]
		var anchor: Vector2i = record["anchor"]
		var sprite := Sprite2D.new()
		sprite.name = String(record["id"])
		sprite.texture = IsoCatalog.load_texture(catalog_id)
		var entry := IsoCatalog.get_entry(catalog_id)
		sprite.offset = entry.get("anchor_offset", Vector2.ZERO)
		var s: float = float(entry.get("scale", 1.0))
		sprite.scale = Vector2(s, s)
		sprite.position = IsoGrid.iso_px_from_cell(anchor)
		_objects.add_child(sprite)
