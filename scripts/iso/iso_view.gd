class_name IsoView
extends Node2D
## Standalone 2D isometric build + harvest view. Sibling of RangeView.
## TileMap is 1:1 with RangeGrid (19x200). Depth is flipped so the tee
## sits toward screen bottom-left and downrange aims top-right.

enum Mode { OFF, BUILD, HARVEST }

const IsoPickupControllerScript := preload("res://scripts/iso/iso_pickup_controller.gd")
const IsoPickerIndicatorScript := preload("res://scripts/iso/iso_picker_indicator.gd")
const TILESET_PATH := "res://assets/tilesets/range_iso.tres"
const FAIRWAY_SOURCE_ID := 0
## Atlas layout from build_iso_tileset: light [0..N), dark [N..2N), mat [2N..3N).
const FAIRWAY_VARIANT_COUNT := 4
const FAIRWAY_ATLAS_LIGHT := Vector2i(0, 0) ## variant 0 light (legacy alias)
const FAIRWAY_ATLAS_DARK := Vector2i(FAIRWAY_VARIANT_COUNT, 0) ## variant 0 dark
const FAIRWAY_ATLAS_MAT := Vector2i(FAIRWAY_VARIANT_COUNT * 2, 0) ## variant 0 mat
## Match RangeView / BayCell billboard world size (yards per texture px).
const BALL_PIXEL_SIZE := 0.021
const BALL_TEX_PX := 16.0

@onready var camera: Camera2D = $Camera2D
@onready var terrain: TileMapLayer = $Terrain
@onready var paths: TileMapLayer = $Paths
@onready var objects: Node2D = $Objects
@onready var littered_balls: Node2D = $LitteredBalls
@onready var overlay: Node2D = $Overlay
@onready var harvest_fx_root: Node2D = $HarvestFx/FxRoot
@onready var picker_layer: CanvasLayer = $PickerLayer
@onready var camera_controller: IsoCameraController = $CameraController
@onready var placement_controller: PlacementController = $PlacementController

var _model: IsoWorldModel = IsoWorldModel.new()
var _terrain_ready := false
var _terrain_painted := false
var _mode: Mode = Mode.OFF
var _pickup: Node
var _picker: Node2D
var _ball_tex: Texture2D
var _litter_by_id: Dictionary = {} ## int -> Sprite2D


func _ready() -> void:
	add_to_group(&"iso_view")
	_ball_tex = DinkySpriteFrames.ball_lay_texture()
	if camera_controller:
		camera_controller.setup(camera)
	if placement_controller:
		placement_controller.setup(terrain, objects, overlay, _model)
	_setup_pickup()
	_try_load_tileset()
	camera.position = IsoGrid.iso_px_from_cell(
		IsoGrid.iso_cell_from_range_cell(RangeGrid.PLAYER_CELL)
	)
	var bus := _event_bus()
	if bus != null:
		if not bus.litter_spawned.is_connected(_on_litter_spawned):
			bus.litter_spawned.connect(_on_litter_spawned)
		if not bus.litter_removed.is_connected(_on_litter_removed):
			bus.litter_removed.connect(_on_litter_removed)
		if not bus.litter_cleared.is_connected(_on_litter_cleared):
			bus.litter_cleared.connect(_on_litter_cleared)
	set_mode(Mode.OFF)


func _event_bus() -> Node:
	return get_tree().root.get_node_or_null("EventBus")


func _setup_pickup() -> void:
	_pickup = IsoPickupControllerScript.new()
	_pickup.name = "IsoPickupController"
	add_child(_pickup)
	var bucket_counter: Control = get_tree().root.get_node_or_null(
		"Main/UI/UIRoot/GameplayChrome/IconBar/BottomRight/BucketCounter"
	)
	_pickup.setup(self, littered_balls, harvest_fx_root, camera, bucket_counter)
	_picker = IsoPickerIndicatorScript.new()
	_picker.name = "IsoPickerIndicator"
	## CanvasLayer so LINE_WIDTH 1.0 is one canvas pixel (zoom-independent hairline).
	picker_layer.add_child(_picker)
	_picker.setup(
		func() -> bool: return _pickup != null and _pickup.is_active(),
		func() -> Vector2: return get_viewport().get_mouse_position(),
		func() -> float: return _pickup.picker_radius_yards() if _pickup else 0.0,
		camera
	)


## Legacy build toggle API.
func set_active(active: bool) -> void:
	set_mode(Mode.BUILD if active else Mode.OFF)


func set_mode(mode: Mode) -> void:
	_mode = mode
	var active := mode != Mode.OFF
	visible = active
	if camera:
		camera.enabled = active
	if camera_controller:
		camera_controller.set_enabled(active)
	if placement_controller:
		placement_controller.set_enabled(mode == Mode.BUILD)
		if mode == Mode.BUILD and placement_controller.get_active_catalog_id() == &"":
			pass
	if active and _terrain_ready and not _terrain_painted:
		_paint_default_terrain()
		_terrain_painted = true
	if active:
		_sync_atmosphere_from_range()
	CursorManager.refresh()


func get_mode() -> Mode:
	return _mode


func is_active() -> bool:
	return _mode != Mode.OFF


func is_harvest_view_ready() -> bool:
	return _mode == Mode.HARVEST and _terrain_painted and visible


func get_world_model() -> IsoWorldModel:
	return _model


func get_pickup_controller() -> Node:
	return _pickup


func apply_atmosphere(cycle_time: float) -> void:
	var snap := DayNightPalette.sample_at(cycle_time)
	var day_factor := DayNightPalette.day_light_factor(cycle_time)
	var tint := DayNightPalette.apply_moonlight(snap.canvas_modulate, day_factor)
	if terrain:
		terrain.modulate = tint
	if paths:
		paths.modulate = tint
	if objects:
		objects.modulate = tint
	if littered_balls:
		littered_balls.modulate = tint
	if overlay:
		overlay.modulate = tint


func _sync_atmosphere_from_range() -> void:
	var main := get_tree().get_first_node_in_group(&"main")
	var range_view: Node = null
	if main != null:
		range_view = main.get_node_or_null("RangeView")
	if range_view == null:
		range_view = get_tree().get_first_node_in_group(&"range_view")
	var cycle_time := 60.0
	if range_view != null:
		var cycle := range_view.get_node_or_null("DayNightCycle")
		if cycle != null and cycle.has_method(&"cycle_elapsed"):
			cycle_time = cycle.cycle_elapsed()
	apply_atmosphere(cycle_time)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _mode == Mode.HARVEST:
		if event is InputEventKey:
			var key := event as InputEventKey
			if not key.echo and key.pressed and key.keycode == KEY_SPACE:
				get_viewport().set_input_as_handled()
				var gs := get_tree().root.get_node_or_null("GameState")
				if gs != null:
					gs.exit_harvest_early()
				return
		if _pickup != null and _pickup.handle_input(event):
			get_viewport().set_input_as_handled()
			return
		if camera_controller and camera_controller.consume_zoom_event(event):
			get_viewport().set_input_as_handled()
			return
		if camera_controller and camera_controller.consume_pan_drag_event(event):
			get_viewport().set_input_as_handled()
			return
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var catalog_ids := IsoCatalog.all_ids()
		var key_event := event as InputEventKey
		var key: Key = key_event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var idx: int = int(key) - int(KEY_1)
			if idx < catalog_ids.size():
				placement_controller.set_active_catalog_id(catalog_ids[idx])
				get_viewport().set_input_as_handled()
				return
		if key == KEY_0 or key == KEY_ESCAPE:
			if key == KEY_0:
				placement_controller.set_active_catalog_id(&"")
				get_viewport().set_input_as_handled()
				return

	if camera_controller and camera_controller.consume_zoom_event(event):
		get_viewport().set_input_as_handled()
		return
	if camera_controller and camera_controller.consume_pan_drag_event(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (
			mb.button_index == MOUSE_BUTTON_LEFT
			and not mb.pressed
			and placement_controller != null
			and placement_controller.get_active_catalog_id() != &""
		):
			if placement_controller.try_place_hover():
				if camera_controller:
					camera_controller.cancel_pending_pan()
				get_viewport().set_input_as_handled()


func _on_litter_spawned(
	litter_id: int,
	world_pos: Vector3,
	quality: int,
	yardage: float,
	is_golden: bool,
	source: String
) -> void:
	if littered_balls == null or _ball_tex == null:
		return
	if _litter_by_id.has(litter_id):
		return
	var sprite := Sprite2D.new()
	sprite.name = "Litter_%d" % litter_id
	sprite.texture = _ball_tex
	var ball_scale := litter_sprite_scale()
	sprite.scale = Vector2(ball_scale, ball_scale)
	sprite.position = IsoGrid.iso_px_from_yards(world_pos)
	sprite.z_index = 2
	if is_golden:
		sprite.modulate = Balance.GOLDEN_BALL_TINT
	sprite.set_meta("litter_id", litter_id)
	sprite.set_meta("world_pos", world_pos)
	sprite.set_meta("collectible", true)
	sprite.set_meta("ball_quality", quality)
	sprite.set_meta("ball_yardage", yardage)
	sprite.set_meta("ball_golden", is_golden)
	sprite.set_meta("ball_source", source)
	littered_balls.add_child(sprite)
	_litter_by_id[litter_id] = sprite


func _on_litter_removed(litter_id: int) -> void:
	if not _litter_by_id.has(litter_id):
		return
	var sprite: Sprite2D = _litter_by_id[litter_id]
	_litter_by_id.erase(litter_id)
	if is_instance_valid(sprite) and not sprite.is_queued_for_deletion():
		sprite.queue_free()


func _on_litter_cleared() -> void:
	_litter_by_id.clear()
	if littered_balls == null:
		return
	for child in littered_balls.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()


func _try_load_tileset() -> void:
	if not ResourceLoader.exists(TILESET_PATH):
		push_warning("IsoView: tileset missing at %s — paint skipped" % TILESET_PATH)
		return
	var ts := load(TILESET_PATH) as TileSet
	if ts == null:
		return
	terrain.tile_set = ts
	paths.tile_set = ts
	_terrain_ready = true


func _paint_default_terrain() -> void:
	if terrain.tile_set == null:
		return
	var w := RangeGrid.GRID_WIDTH_CELLS
	var d := RangeGrid.GRID_DEPTH_CELLS
	for col in w:
		for row in d:
			var iso := IsoGrid.iso_cell_from_range_cell(Vector2i(col, row))
			terrain.set_cell(iso, FAIRWAY_SOURCE_ID, fairway_atlas_for_cell(col, row))
	_paint_bay_mats()
	_block_reserved_bays()


static func fairway_atlas_for_cell(col: int, row: int) -> Vector2i:
	## Column light/dark stripes + per-cell variant scatter so neighbors differ.
	var variant := absi(hash(Vector2i(col, row))) % FAIRWAY_VARIANT_COUNT
	var band_base := FAIRWAY_VARIANT_COUNT if (col & 1) else 0
	return Vector2i(band_base + variant, 0)


## Really-dark fairway reuse for hitting mats (same grass texture, crushed value).
static func fairway_mat_atlas_for_cell(col: int, row: int) -> Vector2i:
	var variant := absi(hash(Vector2i(col, row))) % FAIRWAY_VARIANT_COUNT
	return Vector2i(FAIRWAY_VARIANT_COUNT * 2 + variant, 0)


## Iso Sprite2D scale so litter matches RangeView ball world diameter.
static func litter_sprite_scale() -> float:
	var diameter_yards := BALL_TEX_PX * BALL_PIXEL_SIZE
	var c := IsoGrid.iso_px_from_yards(Vector3.ZERO)
	var e := IsoGrid.iso_px_from_yards(Vector3(diameter_yards, 0.0, 0.0))
	return maxf(0.12, c.distance_to(e) / BALL_TEX_PX)


func _paint_bay_mats() -> void:
	for range_cell in [RangeGrid.PLAYER_CELL, RangeGrid.RATINA_CELL]:
		for iso in IsoGrid.iso_cells_for_range_cell(range_cell):
			terrain.set_cell(
				iso,
				FAIRWAY_SOURCE_ID,
				fairway_mat_atlas_for_cell(range_cell.x, range_cell.y)
			)


func _block_reserved_bays() -> void:
	var blocked: Array[Vector2i] = []
	for range_cell in [RangeGrid.PLAYER_CELL, RangeGrid.RATINA_CELL]:
		blocked.append_array(IsoGrid.iso_cells_for_range_cell(range_cell))
	_model.block_cells(blocked)
