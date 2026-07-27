@tool
class_name IsoView
extends Node2D
## Standalone 2D isometric build + harvest view. Sibling of RangeView.
## TileMap is 1:1 with RangeGrid (19x200). Depth is flipped so the tee
## sits toward screen bottom-left and downrange aims top-right.
##
## @tool: paints the fairway in the editor when this scene is open.
## Runtime wiring (EventBus, actors, pickup) runs only outside the editor.

enum Mode { OFF, BUILD, HARVEST }

const IsoPickupControllerScript := preload("res://scripts/iso/iso_pickup_controller.gd")
const IsoPickerIndicatorScript := preload("res://scripts/iso/iso_picker_indicator.gd")
const TILESET_PATH := "res://assets/tilesets/range_iso.tres"
const FAIRWAY_SOURCE_ID := 0
## Atlas layout from build_iso_tileset: light [0..N), dark [N..2N), forest [2N..3N), mat [3N].
const FAIRWAY_VARIANT_COUNT := 3
const FAIRWAY_ATLAS_LIGHT := Vector2i(0, 0) ## variant 0 light (legacy alias)
const FAIRWAY_ATLAS_DARK := Vector2i(FAIRWAY_VARIANT_COUNT, 0) ## variant 0 dark
const FAIRWAY_ATLAS_FOREST := Vector2i(FAIRWAY_VARIANT_COUNT * 2, 0) ## variant 0 forest apron
## Single authored mat tile — fairway_mat.png (atlas index 3N).
const FAIRWAY_ATLAS_MAT := Vector2i(FAIRWAY_VARIANT_COUNT * 3, 0)
## Iso cells of darker forest apron beyond the fairway on each side.
## Sized so max zoom-out (0.25) still has ground when panned to a fairway edge.
const APRON_PAD_CELLS := 36
## Match RangeView / BayCell billboard world size (yards per texture px).
const BALL_PIXEL_SIZE := 0.021
const BALL_TEX_PX := 16.0

@onready var camera: Camera2D = $Camera2D
@onready var terrain: TileMapLayer = $Terrain
@onready var paths: TileMapLayer = $Paths
@onready var objects: Node2D = $Objects
@onready var yardage_markers: Node2D = $YardageMarkers
@onready var littered_balls: Node2D = $LitteredBalls
@onready var flights: Node2D = $Flights
@onready var trails: Node2D = $Trails
@onready var overlay: Node2D = $Overlay
@onready var harvest_fx_root: Node2D = $HarvestFx/FxRoot
@onready var picker_layer: CanvasLayer = $PickerLayer
@onready var camera_controller: IsoCameraController = $CameraController
@onready var placement_controller: PlacementController = $PlacementController
@onready var actor_layer: IsoActorLayer = $ActorLayer
@onready var flight_layer: IsoFlightLayer = $FlightLayer

var _model: IsoWorldModel = IsoWorldModel.new()
var _terrain_ready := false
var _terrain_painted := false
var _yardage_markers_built := false
var _mode: Mode = Mode.OFF
var _pickup: Node
var _picker: Node2D
var _ball_tex: Texture2D
var _litter_by_id: Dictionary = {} ## int -> Sprite2D
var _editor_clearing_for_save := false

## Inspector: tick to repaint fairway + refocus camera while editing this scene.
@export var editor_repaint_preview: bool = false:
	set(value):
		editor_repaint_preview = false
		if value and Engine.is_editor_hint() and is_inside_tree():
			_refresh_editor_preview()


func _should_use_editor_rig() -> bool:
	if not Engine.is_editor_hint():
		return false
	var edited := get_tree().edited_scene_root
	return edited != null and edited == self


func _enter_tree() -> void:
	if _should_use_editor_rig():
		call_deferred("_refresh_editor_preview")


func _notification(what: int) -> void:
	## Avoid baking painted fairway + apron cells into the .tscn on save.
	if what == NOTIFICATION_EDITOR_PRE_SAVE and _should_use_editor_rig():
		_editor_clearing_for_save = true
		if terrain:
			terrain.clear()
		if paths:
			paths.clear()
	elif what == NOTIFICATION_EDITOR_POST_SAVE and _should_use_editor_rig():
		_editor_clearing_for_save = false
		_refresh_editor_preview()


func _ready() -> void:
	if Engine.is_editor_hint():
		if _should_use_editor_rig():
			_refresh_editor_preview()
		return

	add_to_group(&"iso_view")
	_ball_tex = DinkySpriteFrames.ball_lay_texture()
	if camera_controller:
		camera_controller.setup(camera)
	if placement_controller:
		placement_controller.setup(terrain, objects, overlay, _model)
	_setup_actor_and_flight_layers()
	_setup_pickup()
	_try_load_tileset()
	_ensure_yardage_markers()
	camera.position = _player_bay_px()
	var bus := _event_bus()
	if bus != null:
		if not bus.litter_spawned.is_connected(_on_litter_spawned):
			bus.litter_spawned.connect(_on_litter_spawned)
		if not bus.litter_removed.is_connected(_on_litter_removed):
			bus.litter_removed.connect(_on_litter_removed)
		if not bus.litter_cleared.is_connected(_on_litter_cleared):
			bus.litter_cleared.connect(_on_litter_cleared)
	set_mode(Mode.OFF)


func _player_bay_px() -> Vector2:
	## View origin is the player address pose — camera sits at (0,0).
	return Vector2.ZERO


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or _editor_clearing_for_save:
		return
	_resolve_editor_nodes()
	visible = true
	_try_load_tileset()
	_apply_view_origin_offset()
	if _terrain_ready and terrain != null:
		_paint_default_terrain()
		_terrain_painted = true
	_ensure_yardage_markers()
	_sync_editor_focus_marker()
	if actor_layer:
		IsoEditorPlaceholders.setup_for_editor(actor_layer)
	if camera:
		camera.position = Vector2.ZERO
		camera.enabled = true
		camera.make_current()
	apply_atmosphere(60.0)


func _resolve_editor_nodes() -> void:
	if terrain == null:
		terrain = get_node_or_null("Terrain") as TileMapLayer
	if paths == null:
		paths = get_node_or_null("Paths") as TileMapLayer
	if objects == null:
		objects = get_node_or_null("Objects") as Node2D
	if yardage_markers == null:
		yardage_markers = get_node_or_null("YardageMarkers") as Node2D
	if littered_balls == null:
		littered_balls = get_node_or_null("LitteredBalls") as Node2D
	if flights == null:
		flights = get_node_or_null("Flights") as Node2D
	if trails == null:
		trails = get_node_or_null("Trails") as Node2D
	if overlay == null:
		overlay = get_node_or_null("Overlay") as Node2D
	if camera == null:
		camera = get_node_or_null("Camera2D") as Camera2D
	if actor_layer == null:
		actor_layer = get_node_or_null("ActorLayer") as IsoActorLayer


func _sync_editor_focus_marker() -> void:
	var marker := get_node_or_null("EditorFocus") as Marker2D
	if marker == null:
		marker = Marker2D.new()
		marker.name = "EditorFocus"
		add_child(marker)
		var root := get_tree().edited_scene_root
		if root:
			marker.owner = root
	marker.position = Vector2.ZERO
	marker.gizmo_extents = 48.0


func _event_bus() -> Node:
	return get_tree().root.get_node_or_null("EventBus")


func _setup_actor_and_flight_layers() -> void:
	## Parent Main may not be in group "main" yet (children _ready before parent).
	var range_view: Node3D = get_parent().get_node_or_null("RangeView") as Node3D
	if range_view == null:
		var main := get_tree().get_first_node_in_group(&"main")
		if main != null:
			range_view = main.get_node_or_null("RangeView") as Node3D
	if range_view == null:
		range_view = get_tree().get_first_node_in_group(&"range_view") as Node3D
	if actor_layer:
		actor_layer.setup(range_view)
	if flight_layer:
		flight_layer.setup(flights, trails, camera, camera_controller)
	## Defer a rebind in case RangeView player refs were not ready yet.
	call_deferred("_rebind_actor_layers")


func _rebind_actor_layers() -> void:
	if actor_layer == null:
		return
	var range_view: Node3D = get_parent().get_node_or_null("RangeView") as Node3D
	if range_view == null:
		return
	actor_layer.setup(range_view)
	if is_active():
		actor_layer.set_enabled(true)


func get_actor_layer() -> IsoActorLayer:
	return actor_layer


func get_flight_layer() -> IsoFlightLayer:
	return flight_layer


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
	## CanvasLayer: stroke width is 1 screen px (stretch-compensated), zoom-independent.
	picker_layer.add_child(_picker)
	_picker.setup(
		func() -> bool: return _pickup != null and _pickup.is_active(),
		func() -> Vector2: return _pickup.picker_center_screen() if _pickup else get_viewport().get_mouse_position(),
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
	if actor_layer:
		actor_layer.set_enabled(active)
	if flight_layer:
		flight_layer.set_enabled(active)
	if active and _terrain_ready and not _terrain_painted:
		_paint_default_terrain()
		_terrain_painted = true
	if active:
		_ensure_yardage_markers()
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


## Iso terrain PNGs are authored independently of DayNightPalette 3D stripes.
## Wash strength at night so day/night still reads after brighter authored means.
const ISO_TERRAIN_TOD_WASH := 0.55


func apply_atmosphere(cycle_time: float) -> void:
	var snap := DayNightPalette.sample_at(cycle_time)
	var day_factor := DayNightPalette.day_light_factor(cycle_time)
	var tint := DayNightPalette.apply_moonlight(snap.canvas_modulate, day_factor)
	## Keep authored iso greens readable — do not apply full 3D fairway stripe modulate.
	var terrain_tint := Color.WHITE.lerp(tint, ISO_TERRAIN_TOD_WASH * (1.0 - day_factor))
	if terrain:
		terrain.modulate = terrain_tint
	if paths:
		paths.modulate = terrain_tint
	if objects:
		objects.modulate = tint
	if yardage_markers:
		## Full moonlight — same tint as RangeView yardage Sprite3Ds / iso props.
		yardage_markers.modulate = tint
	if littered_balls:
		## Litter sprites are WHITE/golden; parent wash matches 3D litter.modulate.
		littered_balls.modulate = tint
	## Flight mirrors copy SpriteBase3D.modulate — leave Flights untinted (no double wash).
	if flights:
		flights.modulate = Color.WHITE
	if trails:
		trails.modulate = tint
	if overlay:
		overlay.modulate = tint
	## Actor mirrors copy 3D modulate 1:1 — never wash this layer.
	if actor_layer:
		actor_layer.modulate = Color.WHITE


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
	var ball_scale := authored_ball_scale()
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
	_apply_view_origin_offset()
	_terrain_ready = true


func _apply_view_origin_offset() -> void:
	## TileMap map_to_local is unshifted; slide layers so (0,0) is the player.
	var origin := IsoGrid.view_origin_px_raw()
	if terrain:
		terrain.position = -origin
	if paths:
		paths.position = -origin


func _paint_default_terrain() -> void:
	if terrain.tile_set == null:
		return
	var w := RangeGrid.GRID_WIDTH_CELLS
	var d := RangeGrid.GRID_DEPTH_CELLS
	var pad := APRON_PAD_CELLS
	## Fairway iso cells occupy [0,w) × [0,d). Paint forest apron around that rect.
	for iso_x in range(-pad, w + pad):
		for iso_y in range(-pad, d + pad):
			var iso := Vector2i(iso_x, iso_y)
			var range_cell := IsoGrid.range_cell_from_iso_cell(iso)
			if (
				range_cell.x >= 0
				and range_cell.x < w
				and range_cell.y >= 0
				and range_cell.y < d
			):
				terrain.set_cell(
					iso, FAIRWAY_SOURCE_ID, fairway_atlas_for_cell(range_cell.x, range_cell.y)
				)
			else:
				terrain.set_cell(iso, FAIRWAY_SOURCE_ID, forest_atlas_for_cell(iso_x, iso_y))
	_paint_bay_mats()
	_block_reserved_bays()


static func fairway_atlas_for_cell(col: int, row: int) -> Vector2i:
	## Column light/dark stripes + per-cell variant scatter so neighbors differ.
	var variant := absi(hash(Vector2i(col, row))) % FAIRWAY_VARIANT_COUNT
	var band_base := FAIRWAY_VARIANT_COUNT if (col & 1) else 0
	return Vector2i(band_base + variant, 0)


static func forest_atlas_for_cell(iso_x: int, iso_y: int) -> Vector2i:
	## Darker apron band — variant scatter only (no mower stripes).
	var variant := absi(hash(Vector2i(iso_x, iso_y))) % FAIRWAY_VARIANT_COUNT
	return Vector2i(FAIRWAY_VARIANT_COUNT * 2 + variant, 0)


## One mat texture for every bay — fairway_mat.png (no variant scatter).
static func fairway_mat_atlas_for_cell(_col: int = 0, _row: int = 0) -> Vector2i:
	return FAIRWAY_ATLAS_MAT


## Iso Sprite2D scale so litter matches RangeView ball world diameter.
static func litter_sprite_scale() -> float:
	var diameter_yards := BALL_TEX_PX * BALL_PIXEL_SIZE
	var c := IsoGrid.iso_px_from_yards(Vector3.ZERO)
	var e := IsoGrid.iso_px_from_yards(Vector3(diameter_yards, 0.0, 0.0))
	return maxf(0.12, c.distance_to(e) / BALL_TEX_PX)


## Readable iso size — 2× world-height parity with RangeView Sprite3Ds.
const YARDAGE_MARKER_DISPLAY_SCALE := 2.0
## Right/topside band markers sit into the diamond; lift screen-up a few px.
const YARDAGE_MARKER_TOPSIDE_LIFT_PX := 8.0


## Iso Sprite2D scale so yardage signs read at 2× RangeView world height.
static func yardage_marker_sprite_scale() -> float:
	var height_px := YardageMarkerLayout.world_height_yards() * IsoGrid.HEIGHT_PX_PER_YARD
	return maxf(0.12, height_px / YardageMarkerLayout.TEXTURE_PX) * YARDAGE_MARKER_DISPLAY_SCALE


static func yardage_marker_iso_px(world_pos: Vector3) -> Vector2:
	var px := IsoGrid.iso_px_from_yards(world_pos)
	## Positive X = topside / right outer band in DIAMOND_DOWN read.
	if world_pos.x > 0.0:
		px.y -= YARDAGE_MARKER_TOPSIDE_LIFT_PX
	return px


func _ensure_yardage_markers() -> void:
	if yardage_markers == null:
		yardage_markers = get_node_or_null("YardageMarkers") as Node2D
	if yardage_markers == null:
		return
	if _yardage_markers_built and yardage_markers.get_child_count() > 0:
		return
	for child in yardage_markers.get_children():
		yardage_markers.remove_child(child)
		child.queue_free()
	var scale := yardage_marker_sprite_scale()
	var half_tex := YardageMarkerLayout.TEXTURE_PX * 0.5
	for entry in YardageMarkerLayout.entries():
		var path: String = entry["texture_path"]
		if not ResourceLoader.exists(path):
			push_warning("IsoView: yardage marker texture missing %s" % path)
			continue
		var sprite := Sprite2D.new()
		sprite.name = String(entry["name"])
		sprite.texture = load(path) as Texture2D
		sprite.centered = true
		sprite.offset = Vector2(0.0, -half_tex)
		sprite.scale = Vector2(scale, scale)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = Color.WHITE
		sprite.position = yardage_marker_iso_px(entry["world_pos"] as Vector3)
		yardage_markers.add_child(sprite)
	_yardage_markers_built = true


## Prefer PlayerBallPlaceholder scale (editor-authored); else projected litter scale.
func authored_ball_scale() -> float:
	return IsoEditorPlaceholders.ball_scale(actor_layer)


func _paint_bay_mats() -> void:
	## Every bay on the player row — single fairway_mat atlas cell.
	var bay_cells: Array[Vector2i] = [RangeGrid.PLAYER_CELL, RangeGrid.RATINA_CELL]
	bay_cells.append_array(RangeGrid.empty_bay_cells_on_player_row())
	var mat_atlas := FAIRWAY_ATLAS_MAT
	for range_cell in bay_cells:
		for iso in IsoGrid.iso_cells_for_range_cell(range_cell):
			terrain.set_cell(iso, FAIRWAY_SOURCE_ID, mat_atlas)


func _block_reserved_bays() -> void:
	var blocked: Array[Vector2i] = []
	for range_cell in [RangeGrid.PLAYER_CELL, RangeGrid.RATINA_CELL]:
		blocked.append_array(IsoGrid.iso_cells_for_range_cell(range_cell))
	_model.block_cells(blocked)
