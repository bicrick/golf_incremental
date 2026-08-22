@tool
extends Node3D
## Driving range view — orthographic v4 grid with contact-swing gameplay restored.
##
## @tool: builds ground meshes in the editor. Runtime wiring (EventBus, swing,
## pickup, Ratina) runs only when not Engine.is_editor_hint().

const CHARGE_METER_POSITION := Vector2(236.0, 185.143)
const RATINA_UNLOCKED_CHARGE_METER_POSITION := Vector2(225.0, 185.143)
const BALL_PIXEL_SIZE := 0.021
const PICKUP_FLY_DURATION_SEC := 0.35
const PICKUP_FLY_ARC_PX := 36.0
const PLATE_CAPTURE_CYCLE_TIME := 40.0
const PLATE_CAPTURE_OUTPUT := "res://captures/range_bg.png"

const PickupControllerScript := preload("res://scripts/range/pickup_controller.gd")
const RangePickerIndicatorScript := preload("res://scripts/range/range_picker_indicator.gd")
const HarvestFogScript := preload("res://scripts/range/harvest_fog.gd")
const RatinaControllerScript := preload("res://scripts/range/ratina_controller.gd")
const RattlingControllerScript := preload("res://scripts/range/rattling_controller.gd")
const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const StrikeFeedbackBillboardScript := preload("res://scripts/visual/strike_feedback_billboard.gd")
const BallFlightTrailScript := preload("res://scripts/visual/ball_flight_trail.gd")
const GoldenBallAuraScript := preload("res://scripts/visual/golden_ball_aura.gd")
const RatinaBayCellScene: PackedScene = preload("res://scenes/range/cells/ratina_bay_cell.tscn")
const EmptyBayCellScene: PackedScene = preload("res://scenes/range/cells/empty_bay_cell.tscn")
const BayMatGroundScript := preload("res://scripts/range/bay_mat_ground.gd")

const MOON_LIGHT_ENERGY := 0.16
const CELESTIAL_SPRITE_DISTANCE := 520.0
const CELESTIAL_SPRITE_PIXEL_SIZE := 4.4
const CELESTIAL_SPRITE_RENDER_PRIORITY := -80
## Portrait strike dolly-back along the authored look line (camera +Z).
## World yards ≈ meters here; ~2/3 m. Not an FOV / KEEP_HEIGHT zoom.
const PORTRAIT_STRIKE_DOLLY_BACK := 0.67
const SUN_TEXTURE := preload("res://assets/sprites/sky/sun.png")
const MOON_TEXTURE := preload("res://assets/sprites/sky/moon.png")
const RangeSkyStarsScript := preload("res://scripts/visual/range_sky_stars.gd")

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $Sun
@onready var moon_light: DirectionalLight3D = $Moon
@onready var camera: Camera3D = $Camera3D
@onready var perspective_camera: Camera3D = $PerspectiveCamera
@onready var ground: MeshInstance3D = $Ground
@onready var backdrop: Node3D = $Backdrop
@onready var bays: Node3D = $Bays
@onready var littered_balls: Node3D = $Foreground/LitteredBalls
@onready var yardage_markers: Node3D = $Foreground/YardageMarkers
@onready var foreground: Node3D = $Foreground
@onready var player_bay: Node3D = $Bays/PlayerBay
@onready var charge_meter: Node2D = $ChargeMeter
@onready var contact_ring = $ChargeMeter/BeatRing
@onready var fx_layer: Node2D = $FxLayer
## User-placeable in the editor — hover point for the player's world-space
## strike feedback billboard (tier name + yardage). Defaults to the empty
## fairway cell to the right of the player bay; reposition freely.
@onready var strike_feedback_anchor: Marker3D = $StrikeFeedbackAnchor
@onready var _camera_controller: RangeCameraController = $CameraController
@onready var _view_mode_controller: ViewModeController = $ViewModeController
@onready var ambient_birds: Node3D = get_node_or_null("AmbientBirds")

## Editor-only debug hook: with the game running, select RangeView in the
## Remote scene tree and tick this checkbox in the Inspector to force-unlock
## Rattlings and drop a test ball for one to fetch. Never used in-game.
@export var debug_spawn_test_rattling: bool = false:
	set(value):
		debug_spawn_test_rattling = false
		if value and not Engine.is_editor_hint() and is_inside_tree():
			_debug_spawn_test_rattling()

var ratina_bay: Node3D
var golfer: AnimatedSprite3D
var ball: AnimatedSprite3D
var ratina_sprite: AnimatedSprite3D
var ratina_ball_sprite: AnimatedSprite3D

var _swing := Swing.new()
var _ball_home: Vector3
var _golfer_home: Vector3
var _base_ball_scale: Vector3 = Vector3.ONE
var _base_golfer_scale: Vector3 = Vector3.ONE
var _golfer_joy_active: bool = false
var _ball_in_flight: bool = false
var _ball_at_tee: bool = true
var _tee_ball_is_golden: bool = false
var _tee_ball_prepared: bool = false
var _ball_lay_texture: Texture2D
var _pickup: Node
var _picker_indicator: Node3D
var _harvest_fog # HarvestFog
var _next_litter_id: int = 1
var _suppress_litter_bus := false
var _ratina: Node
var _rattling_controller: Node
var _active_flights: Array[Dictionary] = []
var _strike_feedback_billboard: StrikeFeedbackBillboard
var _sprite_atmosphere_tint: Color = Color.WHITE
var _ratina_layout_applied: bool = false
var _ratina_strike_text_offset: Vector2 = Balance.RATINA_STRIKE_TEXT_OFFSET
var _view_mode_started := false
## Swallow leftover harvest-exit presses so they cannot charge a swing.
var _ignore_pointer_until_release: bool = false
var _held_touch_indices: Dictionary = {}
var _backdrop_mesh: MeshInstance3D
var _editor_backdrop_camera_xform: Transform3D = Transform3D()
var _empty_bays_container: Node3D
var _sun_sprite: Sprite3D
var _moon_sprite: Sprite3D
var _sky_stars: RangeSkyStars
var _perspective_home_xform: Transform3D = Transform3D()
var _perspective_home_captured: bool = false


func _should_use_editor_rig() -> bool:
	if not Engine.is_editor_hint():
		return false
	var edited := get_tree().edited_scene_root
	return edited != null and edited == self


func _enter_tree() -> void:
	if _should_use_editor_rig():
		call_deferred("_refresh_preview")


func _ready() -> void:
	if not Engine.is_editor_hint():
		_ball_lay_texture = DinkySpriteFrames.ball_lay_texture()
		if not EventBus.litter_removed.is_connected(_on_bus_litter_removed):
			EventBus.litter_removed.connect(_on_bus_litter_removed)
		if not EventBus.litter_cleared.is_connected(_on_bus_litter_cleared):
			EventBus.litter_cleared.connect(_on_bus_litter_cleared)
	_refresh_preview()
	if not Engine.is_editor_hint():
		_setup_ratina_bay()

	if charge_meter:
		_layout_charge_meter()
	_setup_celestial_sprites()
	if _should_use_editor_rig():
		if perspective_camera:
			perspective_camera.make_current()
		elif camera:
			camera.make_current()
		set_process(_should_use_editor_rig())
	apply_atmosphere(60.0)

	if Engine.is_editor_hint():
		if ratina_sprite:
			ratina_sprite.visible = true
		if ratina_ball_sprite:
			ratina_ball_sprite.visible = true
		return

	_setup_player_refs()
	_camera_controller.setup(camera)
	_setup_view_mode_controller()
	_setup_harvest_fog()
	_setup_strike_feedback_billboard()
	apply_viewport_aspect()

	if contact_ring:
		contact_ring.frozen_fade_completed.connect(_on_contact_ring_fade_completed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.stats_changed.connect(_on_stats_changed)
	call_deferred("_sync_tee_ball_from_bucket")
	call_deferred("_setup_pickup_controller")
	call_deferred("_setup_ratina_controller")
	call_deferred("_setup_rattling_controller")
	call_deferred("_apply_ratina_layout_if_needed")
	_set_idle_ring()
	set_process_input(true)
	if sun_light:
		sun_light.shadow_enabled = false


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or Engine.is_editor_hint():
		return
	## Hide screen-space FxLayer while RangeView is off-screen so Camera3D
	## unprojections (trails / poofs) do not smear over IsoView.
	if fx_layer:
		fx_layer.visible = visible
	if not visible or _view_mode_started or _view_mode_controller == null:
		return
	_view_mode_started = true
	_view_mode_controller.start_initial_mode()


func consume_zoom_event(event: InputEvent) -> bool:
	if not visible or _camera_controller == null:
		return false
	if _view_mode_controller and not _view_mode_controller.can_use_ortho_pan():
		return false
	return _camera_controller.consume_zoom_event(event)


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not visible or _camera_controller == null:
		return false
	if _view_mode_controller and not _view_mode_controller.can_use_ortho_pan():
		return false
	return _camera_controller.consume_pan_drag_event(event)


func get_camera() -> Camera3D:
	## Prefer whichever camera is actually rendering (covers TRANSITIONING after swap).
	if camera and camera.current:
		return camera
	if perspective_camera and perspective_camera.current:
		return perspective_camera
	if _view_mode_controller and _view_mode_controller.get_mode() == ViewModeController.Mode.HARVEST:
		return camera
	if perspective_camera:
		return perspective_camera
	return camera


func get_flight_camera() -> Camera3D:
	return get_camera()


func get_perspective_camera() -> Camera3D:
	return perspective_camera


func is_transitioning() -> bool:
	return _view_mode_controller != null and _view_mode_controller.is_transitioning()


func is_harvest_view_ready() -> bool:
	return _view_mode_controller != null and _view_mode_controller.is_harvest_view_ready()


## Drop in-flight player balls without resolving litter / vanish payout.
func discard_active_flights() -> void:
	for flight in _active_flights.duplicate():
		var sprite: Node = flight.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		var trail = flight.get("trail")
		if trail != null and trail.has_method("finish"):
			trail.finish()
	_active_flights.clear()
	_ball_in_flight = false


## Reset camera / litter after a hard run wipe (settings wipe, etc.).
func prepare_after_run_reset() -> void:
	if GameState.is_harvest_phase():
		GameState.exit_harvest_early()
	EventBus.litter_cleared.emit()
	discard_active_flights()
	if ball != null:
		ball.visible = false


func _setup_view_mode_controller() -> void:
	if _view_mode_controller == null:
		return
	_view_mode_controller.setup(
		self,
		perspective_camera,
		camera,
		_camera_controller
	)
	var main := get_tree().root.get_node_or_null("Main")
	if main:
		var transition := main.get_node_or_null("ViewTransitionLayer/ViewTransition")
		if transition:
			_view_mode_controller.bind_transition(transition)
	_view_mode_controller.view_mode_changed.connect(_on_view_mode_changed)
	EventBus.phase_changed.connect(_view_mode_controller.on_phase_changed)


func _setup_harvest_fog() -> void:
	_harvest_fog = HarvestFogScript.new()
	# Must match BallFlight3D origin (world tee), not bay-local ball home.z.
	var tee_world_z := RangeGrid.player_bay_origin().z
	if player_bay != null:
		tee_world_z = player_bay.to_global(_ball_home).z
	_harvest_fog.setup(
		ground,
		yardage_markers,
		_view_mode_controller,
		tee_world_z,
		foreground,
		ambient_birds as RangeBirdDirector
	)
	_harvest_fog.set_atmosphere_tint(_sprite_atmosphere_tint)
	if _view_mode_controller:
		_harvest_fog.on_view_mode_changed(_view_mode_controller.get_mode())


func get_fx_reference_ortho_size() -> float:
	if _camera_controller:
		return _camera_controller.reference_ortho_size()
	return _camera_home_size()


func get_golfer() -> AnimatedSprite3D:
	return golfer


func get_ball() -> AnimatedSprite3D:
	return ball


func ratina_strike_text_offset() -> Vector2:
	return _ratina_strike_text_offset


func _setup_player_refs() -> void:
	if player_bay == null:
		return
	golfer = player_bay.get_golfer()
	ball = player_bay.get_ball()
	_golfer_home = player_bay.strike_home()
	_ball_home = player_bay.ball_strike_home()
	_base_golfer_scale = player_bay.get_base_golfer_scale()
	_base_ball_scale = player_bay.get_base_ball_scale()
	if golfer:
		golfer.animation_finished.connect(_on_golfer_animation_finished)
		_play_golfer_idle()


func _setup_ratina_bay() -> void:
	if ratina_bay != null:
		return
	ratina_bay = RatinaBayCellScene.instantiate()
	ratina_bay.position = RangeGrid.ratina_bay_origin()
	bays.add_child(ratina_bay)
	ratina_sprite = ratina_bay.get_golfer()
	ratina_ball_sprite = ratina_bay.get_ball()


func _refresh_preview() -> void:
	_build_ground()
	_build_backdrop()
	_setup_camera()
	_setup_player_bay()
	_setup_empty_bays()


func _setup_empty_bays() -> void:
	if bays == null:
		return
	var container := _ensure_empty_bays_container()
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for cell: Vector2i in RangeGrid.empty_bay_cells_on_player_row():
		var bay := EmptyBayCellScene.instantiate()
		bay.position = RangeGrid.bay_origin(cell.x, cell.y)
		container.add_child(bay)
		_configure_placed_bay(bay)
		if Engine.is_editor_hint():
			var root := get_tree().edited_scene_root
			if root:
				bay.owner = root


func _ensure_empty_bays_container() -> Node3D:
	if _empty_bays_container != null and is_instance_valid(_empty_bays_container):
		return _empty_bays_container
	_empty_bays_container = bays.get_node_or_null("EmptyBays") as Node3D
	if _empty_bays_container == null:
		_empty_bays_container = Node3D.new()
		_empty_bays_container.name = "EmptyBays"
		bays.add_child(_empty_bays_container)
		if Engine.is_editor_hint():
			var root := get_tree().edited_scene_root
			if root:
				_empty_bays_container.owner = root
	return _empty_bays_container


func _configure_placed_bay(bay: Node3D) -> void:
	var bay_ground := bay.get_node_or_null("Ground") as MeshInstance3D
	if bay_ground:
		bay_ground.visible = true
		BayMatGroundScript.apply_to_mesh(bay_ground)


func _setup_player_bay() -> void:
	if player_bay == null:
		return
	player_bay.position = RangeGrid.player_bay_origin()
	_configure_placed_bay(player_bay)


func _build_ground() -> void:
	if ground == null:
		return
	_ensure_ground_meshes()
	var snap := DayNightPalette.sample_at(24.0)
	_apply_ground_palette(snap.fairway_light, snap.fairway_dark)


func _ensure_ground_meshes() -> void:
	ground.mesh = FairwayGrassTiles3D.build_plane_mesh(
		-RangeGrid.HALF_WIDTH_YARDS,
		RangeGrid.HALF_WIDTH_YARDS,
		0.0,
		-RangeGrid.DEPTH_YARDS
	)
	if ground.get_surface_override_material(0) == null:
		ground.set_surface_override_material(0, FairwayGrassTiles3D.make_fairway_material())


func _apply_ground_palette(light_color: Color, dark_color: Color) -> void:
	CellGround.apply_palette_uniforms(ground, light_color, dark_color)


func _build_backdrop() -> void:
	var backdrop_node := get_node_or_null("Backdrop") as Node3D
	var cam := get_node_or_null("PerspectiveCamera") as Camera3D
	if backdrop_node == null or cam == null:
		return
	var aspect := _live_aspect()
	_backdrop_mesh = RangeBackdrop.populate(backdrop_node, cam, RangeBackdrop.DEFAULT_DISTANCE_YARDS, aspect)
	if not Engine.is_editor_hint() and backdrop_node.visible and _view_mode_controller != null:
		_update_backdrop_visibility(_view_mode_controller.get_mode())
	elif Engine.is_editor_hint():
		backdrop_node.visible = true
		_editor_backdrop_camera_xform = cam.transform


func _live_aspect() -> float:
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	if size.x > 1.0 and size.y > 1.0:
		return size.x / size.y
	return RangeBackdrop.REFERENCE_ASPECT


func apply_viewport_aspect() -> void:
	if Engine.is_editor_hint():
		return
	## Always KEEP_HEIGHT so vertical framing (rat + tee) matches the authored
	## strike pose. KEEP_WIDTH at 16:9 treats fov as vertical and crops the
	## golfer off the bottom; portrait already looked correct with KEEP_HEIGHT.
	## Wide web EXPAND viewports also keep that vertical frame and grow sides.
	if camera:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
	if perspective_camera:
		perspective_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_apply_perspective_portrait_dolly()
	_build_backdrop()
	_layout_charge_meter()


func perspective_home_transform() -> Transform3D:
	_ensure_perspective_home()
	return _perspective_home_xform


func _ensure_perspective_home() -> void:
	if _perspective_home_captured or perspective_camera == null:
		return
	_perspective_home_xform = perspective_camera.transform
	_perspective_home_captured = true


func _apply_perspective_portrait_dolly() -> void:
	if perspective_camera == null:
		return
	_ensure_perspective_home()
	perspective_camera.transform = _perspective_home_xform
	## Portrait only — landscape desktop keeps the authored strike pose.
	if not UiLayout.is_portrait(get_viewport()):
		return
	## Godot look is -Z; +basis.z is backward. Dolly-back, not FOV zoom.
	perspective_camera.position += (
		perspective_camera.transform.basis.z * PORTRAIT_STRIKE_DOLLY_BACK
	)


func _layout_charge_meter() -> void:
	if charge_meter == null:
		return
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(480, 270)
	var unlocked := false
	if not Engine.is_editor_hint():
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			unlocked = bool(gs.get("ratina_unlocked"))
	var base := RATINA_UNLOCKED_CHARGE_METER_POSITION if unlocked else CHARGE_METER_POSITION
	## Landscape uses authored coords; portrait recenters near bottom-middle.
	if UiLayout.is_portrait(get_viewport()):
		charge_meter.position = Vector2(size.x * 0.5 - 4.0, size.y * 0.72)
	else:
		## Scale authored 480x270 coords into the live viewport.
		charge_meter.position = Vector2(
			base.x * (size.x / 480.0),
			base.y * (size.y / 270.0)
		)


func horizon_screen_y() -> float:
	## Screen Y of the fairway horizon (ground plane at look-center). Above =
	## sky/backdrop; below = fairway for mobile strike taps.
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(480, 270)
	var cam := get_flight_camera()
	if cam == null:
		cam = perspective_camera if perspective_camera else camera
	if cam == null or not cam.is_inside_tree():
		return size.y * 0.45
	var look_dir := -cam.global_transform.basis.z
	var origin := cam.global_position
	## Intersect camera forward ray with y=0 ground plane.
	if absf(look_dir.y) < 0.0001:
		return size.y * 0.45
	var t := -origin.y / look_dir.y
	if t <= 0.0:
		return size.y * 0.45
	var ground_point := origin + look_dir * t
	var screen := cam.unproject_position(ground_point)
	if not is_finite(screen.y):
		return size.y * 0.45
	return clampf(screen.y, size.y * 0.2, size.y * 0.8)


func _update_backdrop_visibility(mode: ViewModeController.Mode) -> void:
	if backdrop == null:
		return
	# Keep rendering through the strike→harvest dissolve snapshot; hide only in ortho pickup view.
	backdrop.visible = mode != ViewModeController.Mode.HARVEST


func _on_view_mode_changed(mode: ViewModeController.Mode) -> void:
	_update_backdrop_visibility(mode)
	if _harvest_fog:
		_harvest_fog.on_view_mode_changed(mode)
	var flight_cam := get_flight_camera()
	if _ratina != null and _ratina.has_method("set_flight_camera"):
		_ratina.set_flight_camera(flight_cam)
	## Player trails stay bound to the strike camera unless we rebind — otherwise
	## mid-flight harvest switch leaves a perspective-projected Line2D on ortho.
	_rebind_active_flight_trails(flight_cam)


func _rebind_active_flight_trails(flight_cam: Camera3D) -> void:
	if flight_cam == null:
		return
	for flight in _active_flights:
		var trail = flight.get("trail")
		if trail != null and is_instance_valid(trail) and trail.has_method("set_camera"):
			trail.set_camera(flight_cam)


func _camera_home_size() -> float:
	if camera:
		return camera.size
	return 8.0


func _setup_camera() -> void:
	if camera == null:
		return
	# Harvest uses the pre-IsoView 3D lock; scene owns position + ortho size.
	# Bay cells keep V4CameraConfig.LOCKED_BASIS (2:1 dimetric).
	V4CameraConfig.apply_harvest_locked_rotation_only(camera)
	camera.current = true
	apply_viewport_aspect()


func capture_plate(output_path: String = PLATE_CAPTURE_OUTPUT, cycle_time: float = PLATE_CAPTURE_CYCLE_TIME) -> Error:
	var hidden: Array[Node] = []
	for node_name in ["Foreground", "Bays", "ChargeMeter"]:
		var node := get_node_or_null(node_name)
		if node == null or not node.visible:
			continue
		hidden.append(node)
		node.visible = false

	var cycle := get_node_or_null("DayNightCycle")
	var cycle_was_processing := false
	if cycle:
		cycle_was_processing = cycle.is_processing()
		cycle.set_process(false)
	apply_atmosphere(cycle_time)

	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var target_size := Vector2i(get_viewport().get_visible_rect().size)
	if image.get_size() != target_size:
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	var global_path := output_path
	if not global_path.is_absolute_path():
		global_path = ProjectSettings.globalize_path(output_path)
	var dir_path := global_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var err := image.save_png(global_path)

	for node in hidden:
		node.visible = true
	if cycle and cycle_was_processing:
		cycle.set_process(true)

	return err


func apply_atmosphere(cycle_time: float) -> void:
	var snap := DayNightPalette.sample_at(cycle_time)
	var day_factor := DayNightPalette.day_light_factor(cycle_time)
	_sprite_atmosphere_tint = DayNightPalette.apply_moonlight(snap.canvas_modulate, day_factor)
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_color = snap.sky
		var ambient := snap.sky.lerp(snap.fairway_light, (1.0 - day_factor) * 0.45)
		env.ambient_light_color = DayNightPalette.apply_moonlight(ambient, day_factor)
		_apply_procedural_sky(env, snap)
	var fairway_colors := DayNightPalette.fairway_stripe_colors(snap, day_factor)
	_apply_ground_palette(fairway_colors[0], fairway_colors[1])
	_apply_celestial_lights(cycle_time, day_factor)
	if player_bay:
		player_bay.apply_ground_palette(fairway_colors[0], fairway_colors[1])
	if ratina_bay:
		ratina_bay.apply_ground_palette(fairway_colors[0], fairway_colors[1])
	if _empty_bays_container:
		for bay in _empty_bays_container.get_children():
			if bay.has_method("apply_ground_palette"):
				bay.apply_ground_palette(fairway_colors[0], fairway_colors[1])
	if _backdrop_mesh:
		var backdrop_tint := DayNightPalette.backdrop_tint(snap, day_factor)
		RangeBackdrop.apply_palette_tints(_backdrop_mesh, backdrop_tint, backdrop_tint)
	_apply_divider_brightness(day_factor)
	_apply_sprite_atmosphere_tint()
	if _harvest_fog:
		_harvest_fog.set_fog_color(DayNightPalette.harvest_fog_color(day_factor))
		_harvest_fog.set_atmosphere_tint(_sprite_atmosphere_tint)
	EventBus.atmosphere_tint_changed.emit(_sprite_atmosphere_tint)


func _apply_procedural_sky(env: Environment, snap: DayNightPalette.AtmosphereSnapshot) -> void:
	if env.sky == null:
		return
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	var horizon := snap.sky.lightened(0.12)
	var zenith := snap.sky.darkened(0.08)
	sky_mat.sky_horizon_color = horizon
	sky_mat.sky_top_color = zenith
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = snap.sky.darkened(0.20)
	# Hide soft ProceduralSky light discs — pixel sprites own the look.
	sky_mat.sun_angle_max = 0.5


func _setup_celestial_sprites() -> void:
	if _sun_sprite == null:
		_sun_sprite = _make_celestial_sprite(&"SunSprite", SUN_TEXTURE)
	if _moon_sprite == null:
		_moon_sprite = _make_celestial_sprite(&"MoonSprite", MOON_TEXTURE)
	if _sky_stars == null:
		_sky_stars = RangeSkyStarsScript.new()
		_sky_stars.name = &"SkyStars"
		add_child(_sky_stars)
		_sky_stars.setup()


func _make_celestial_sprite(node_name: StringName, texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.transparent = true
	sprite.render_priority = CELESTIAL_SPRITE_RENDER_PRIORITY
	_configure_billboard(sprite, CELESTIAL_SPRITE_PIXEL_SIZE)
	sprite.visible = false
	add_child(sprite)
	return sprite


func _apply_celestial_lights(cycle_time: float, day_factor: float) -> void:
	var sun_dir := DayNightPalette.celestial_view_direction(cycle_time, false, Vector3.ZERO)
	if sun_light:
		_aim_celestial_light(sun_light, sun_dir)
		sun_light.light_color = DayNightPalette.SUN_COLOR
		# Scale from 0 at horizon — no energy floor, so dusk does not hard-cut.
		sun_light.light_energy = 0.70 * day_factor
		sun_light.shadow_enabled = false

	var moon_dir := DayNightPalette.celestial_view_direction(cycle_time, true, Vector3.ZERO)
	var moon_light_alpha := DayNightPalette.celestial_alpha(cycle_time, true)
	if moon_light:
		_aim_celestial_light(moon_light, moon_dir)
		moon_light.light_color = DayNightPalette.MOON_COLOR
		# Soft fill for lit meshes; unshaded fairway/backdrop use moonlight tint instead.
		moon_light.light_energy = MOON_LIGHT_ENERGY * moon_light_alpha
		moon_light.shadow_enabled = false

	# Sprites stay up until ~mountain ridge, then fade — separate from light energy.
	_place_celestial_sprite(
		_sun_sprite, sun_dir, DayNightPalette.celestial_sprite_alpha(cycle_time, false)
	)
	_place_celestial_sprite(
		_moon_sprite, moon_dir, DayNightPalette.celestial_sprite_alpha(cycle_time, true)
	)
	_update_sky_stars(cycle_time)


func _place_celestial_sprite(sprite: Sprite3D, sky_dir: Vector3, alpha: float) -> void:
	if sprite == null:
		return
	if alpha <= 0.01:
		sprite.visible = false
		return
	sprite.visible = true
	sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
	sprite.global_position = (
		_celestial_viewer_origin() + sky_dir.normalized() * CELESTIAL_SPRITE_DISTANCE
	)


func _update_sky_stars(cycle_time: float) -> void:
	if _sky_stars == null:
		return
	# Same rise/set fade as the moon sprite (mountain ridge, not decor windows).
	_sky_stars.update_for_viewer(
		_celestial_viewer_origin(), DayNightPalette.celestial_sprite_alpha(cycle_time, true)
	)


func _celestial_viewer_origin() -> Vector3:
	var origin := global_position
	var active := get_viewport().get_camera_3d() if is_inside_tree() else null
	if active:
		return active.global_position
	if perspective_camera and perspective_camera.current:
		return perspective_camera.global_position
	if camera:
		return camera.global_position
	return origin


func _aim_celestial_light(light: DirectionalLight3D, sky_dir: Vector3) -> void:
	if light == null or sky_dir.length_squared() < 0.0001:
		return
	var dir := sky_dir.normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	# DirectionalLight shines along -Z; aim so rays come from the sky body.
	light.look_at(light.global_position - dir, up)


func _apply_divider_brightness(day_factor: float) -> void:
	if player_bay and player_bay.has_method("apply_divider_brightness"):
		player_bay.apply_divider_brightness(day_factor)
	if _empty_bays_container:
		for bay in _empty_bays_container.get_children():
			if bay.has_method("apply_divider_brightness"):
				bay.apply_divider_brightness(day_factor)


func _apply_sprite_atmosphere_tint() -> void:
	if player_bay:
		player_bay.apply_sprite_tint(_sprite_atmosphere_tint)
	if ball and _ball_at_tee and is_instance_valid(ball):
		ball.modulate = _ball_modulate(_tee_ball_is_golden)
	for flight in _active_flights:
		var sprite: Node = flight.get("sprite")
		if sprite is SpriteBase3D and is_instance_valid(sprite):
			(sprite as SpriteBase3D).modulate = _ball_modulate(flight.get("is_golden", false))
	if littered_balls:
		for child in littered_balls.get_children():
			if child is SpriteBase3D:
				if child.get_meta("ball_golden", false):
					child.modulate = Balance.GOLDEN_BALL_TINT
				else:
					child.modulate = _sprite_atmosphere_tint
	# Yardage markers: HarvestFog owns modulate when active (fog fade + atmosphere).
	if yardage_markers and _harvest_fog == null:
		for child in yardage_markers.get_children():
			if child is SpriteBase3D:
				(child as SpriteBase3D).modulate = _sprite_atmosphere_tint
	if _ratina and _ratina.has_method("apply_atmosphere_tint"):
		_ratina.apply_atmosphere_tint(_sprite_atmosphere_tint)
	if _rattling_controller and _rattling_controller.has_method("apply_atmosphere_tint"):
		_rattling_controller.apply_atmosphere_tint(_sprite_atmosphere_tint)
	if ambient_birds and ambient_birds.has_method("apply_atmosphere_tint"):
		ambient_birds.apply_atmosphere_tint(_sprite_atmosphere_tint)


func _process(delta: float) -> void:
	if _should_use_editor_rig():
		var cam := get_node_or_null("PerspectiveCamera") as Camera3D
		if cam != null and not cam.transform.is_equal_approx(_editor_backdrop_camera_xform):
			_build_backdrop()
		return
	_clear_ignore_if_pointers_up()
	_swing.update(delta)
	_update_ball_reload()
	_update_charge_visuals()
	if _harvest_fog:
		_harvest_fog.update(delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	_track_pointer_event(event)
	_clear_ignore_if_pointers_up()


## Call when harvest ends (empty tap, collect-all, Space) so a leftover
## finger/mouse press cannot become a charge or strike.
func ignore_pointer_until_release() -> void:
	_ignore_pointer_until_release = true
	if _swing.is_charging():
		_swing.cancel_charge()
		_set_idle_ring()
		if not _golfer_joy_active:
			_play_golfer_idle()


func _track_pointer_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_held_touch_indices[touch.index] = true
		else:
			_held_touch_indices.erase(touch.index)


func _any_pointer_down() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	return not _held_touch_indices.is_empty()


func _clear_ignore_if_pointers_up() -> void:
	if _ignore_pointer_until_release and not _any_pointer_down():
		_ignore_pointer_until_release = false


func _should_ignore_strike_pointer() -> bool:
	if not _ignore_pointer_until_release:
		return false
	_clear_ignore_if_pointers_up()
	return _ignore_pointer_until_release


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# RangeView may be hidden under overlays. Still accept Space charge/release
	# and harvest exit so leftover-press / desktop exit keep working.
	if not visible:
		if GameState.is_harvest_phase():
			_handle_harvest_input(event)
		elif _iso_view_showing():
			_handle_strike_input(event)
		return
	# Pan/zoom only after harvest ortho settle (can_use_ortho_pan). View toggles
	# (Space / background click) stay available mid-flight and mid-dissolve;
	# pickup itself is gated by PickupController.is_active() / harvest_view_ready.
	if _camera_controller and _camera_controller.consume_zoom_event(event):
		get_viewport().set_input_as_handled()
		return
	## Collect before pan so LMB press can pick up; pan arms on press but only
	## claims the gesture after the drag threshold.
	if GameState.is_harvest_phase():
		_handle_harvest_input(event)
		if get_viewport().is_input_handled():
			return
	else:
		_handle_strike_input(event)
		if get_viewport().is_input_handled():
			return
	if _camera_controller and _camera_controller.consume_pan_drag_event(event):
		get_viewport().set_input_as_handled()


func _iso_view_showing() -> bool:
	var iso := get_tree().get_first_node_in_group(&"iso_view")
	return iso != null and iso.visible


## Collect mode: pickup click, or desktop Space to return to striking.
## Empty click / tap stays in harvest. Exit via last-ball complete_harvest(),
## bucket 2/6 return_all_balls_free(), mobile shag-bag toggle, or desktop Space.
func _handle_harvest_input(event: InputEvent) -> void:
	if _tutorial_blocks_input():
		if event is InputEventKey or _is_left_pointer_event(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if UiLayout.is_mobile_touch():
			return
		var key := event as InputEventKey
		if not key.echo and key.pressed and key.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			GameState.exit_harvest_early()
		return
	if _try_harvest_bird_click(event):
		if _camera_controller and _camera_controller.has_method(&"cancel_pending_pan"):
			_camera_controller.cancel_pending_pan()
		get_viewport().set_input_as_handled()
		return
	if _pickup and _pickup.handle_input(event):
		if _camera_controller and _camera_controller.has_method(&"cancel_pending_pan"):
			_camera_controller.cancel_pending_pan()
		get_viewport().set_input_as_handled()
		return


func _try_harvest_bird_click(event: InputEvent) -> bool:
	if ambient_birds == null or not ambient_birds.has_method("try_harvest_click"):
		return false
	if not GameState.is_collect_mode():
		return false
	if not is_harvest_view_ready():
		return false
	var screen := Vector2.ZERO
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
			return false
		screen = click.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return false
		screen = touch.position
	else:
		return false
	return ambient_birds.try_harvest_click(screen)


## Hitting mode: Space swings when the bucket has balls. Desktop left-click
## on the background enters collect if there is litter. Mobile swings on any
## fairway tap; harvest is the shag-bag HUD toggle.
func _handle_strike_input(event: InputEvent) -> void:
	if _tutorial_blocks_input():
		if _is_left_pointer_event(event) or _is_space_event(event):
			get_viewport().set_input_as_handled()
		return
	if _should_ignore_strike_pointer():
		if _is_left_pointer_event(event) or _is_space_event(event):
			get_viewport().set_input_as_handled()
		return
	if UiLayout.is_mobile_touch():
		if _handle_mobile_strike_input(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if _try_background_click_to_collect(event as InputEventMouseButton):
			get_viewport().set_input_as_handled()
		return
	if not GameState.has_bucket_balls():
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.echo or key.keycode != KEY_SPACE:
		return
	if key.pressed:
		_swing.start_charge()
	else:
		_swing.release_strike()


func _tutorial_blocks_input() -> bool:
	var overlay := get_tree().get_first_node_in_group(&"tutorial_overlay")
	return (
		overlay != null
		and overlay.has_method("is_blocking_input")
		and overlay.is_blocking_input()
	)


func _is_space_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	return not key.echo and key.keycode == KEY_SPACE


func _handle_mobile_strike_input(event: InputEvent) -> bool:
	if UiInput.is_interactive_control_under_mouse(get_viewport()):
		return false
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		pressed = touch.pressed
		released = not touch.pressed
		pos = touch.position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return false
		pressed = click.pressed
		released = not click.pressed
		pos = click.position
	else:
		return false
	if _should_ignore_strike_pointer():
		return true
	if pressed:
		if GameState.has_bucket_balls():
			_swing.start_charge()
			return true
		return false
	if released and _swing.is_charging():
		_swing.release_strike()
		return true
	return false


func _try_background_click_to_collect(click: InputEventMouseButton) -> bool:
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return false
	if _swing.is_charging():
		return false
	if UiInput.is_interactive_control_under_mouse(get_viewport()):
		return false
	return GameState.try_enter_harvest()


func _is_left_pointer_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.button_index == MOUSE_BUTTON_LEFT and click.pressed
	return false


func _is_left_pointer_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		return click.button_index == MOUSE_BUTTON_LEFT and not click.pressed
	return false


func _is_left_pointer_event(event: InputEvent) -> bool:
	return _is_left_pointer_press(event) or _is_left_pointer_release(event)


func _on_swing_charging_changed(charging: bool) -> void:
	if charging:
		_golfer_joy_active = false
		golfer.stop()
		golfer.animation = &"swing"
		golfer.frame = 0
		if contact_ring:
			contact_ring.show_charging(GameState.stats)
		if _ball_at_tee:
			ball.play(&"idle")
	elif not _golfer_joy_active:
		golfer.stop()
		golfer.animation = &"swing"
		golfer.frame = RangeRatSpriteFrames.CONTACT_FRAME


func _on_swing_charge_updated(windup: float, _in_band: bool, _past_contact: bool) -> void:
	if not _swing.is_charging():
		return
	var frame := clampi(
		int(floor(windup * float(RangeRatSpriteFrames.WINDUP_LAST))),
		0,
		RangeRatSpriteFrames.WINDUP_LAST
	)
	if golfer.animation != &"swing":
		golfer.animation = &"swing"
	golfer.frame = frame


func _golfer_idle_anim() -> StringName:
	if GameState.is_harvest_phase():
		return &"idle_out_of_balls"
	if GameState.has_bucket_balls():
		return &"idle"
	return &"idle_out_of_balls"


func _play_golfer_idle() -> void:
	if golfer == null:
		return
	var anim := _golfer_idle_anim()
	if golfer.animation == anim and golfer.is_playing():
		return
	if golfer.animation != anim:
		golfer.stop()
	golfer.play(anim)


func _golfer_idle_blocked() -> bool:
	return (
		_golfer_joy_active
		or _swing.is_charging()
		or golfer.animation == &"joy"
		or golfer.animation == &"swing"
		or (golfer.animation == &"follow" and golfer.is_playing())
		or (golfer.animation == &"return_to_address" and golfer.is_playing())
	)


func golfer_strike_home() -> Vector3:
	return _golfer_home


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_apply_ratina_layout_if_needed()


func _apply_ratina_layout_if_needed() -> void:
	if not GameState.ratina_unlocked or _ratina_layout_applied:
		return
	_apply_ratina_unlocked_layout()
	_ratina_layout_applied = true


func _apply_ratina_unlocked_layout() -> void:
	_layout_charge_meter()
	_ratina_strike_text_offset = Balance.RATINA_STRIKE_TEXT_OFFSET
	if _ratina and _ratina.has_method("refresh_strike_homes"):
		_ratina.refresh_strike_homes()


func _sync_golfer_idle_from_bucket() -> void:
	if golfer == null or _golfer_idle_blocked():
		return
	_play_golfer_idle()


func _on_golfer_animation_finished() -> void:
	if golfer.animation == &"joy":
		_golfer_joy_active = false
		if not _swing.is_charging():
			_play_return_to_address()
	elif golfer.animation == &"follow":
		_play_return_to_address()
	elif golfer.animation == &"return_to_address":
		_play_golfer_idle()


func _clear_frozen_charge_ring() -> void:
	if contact_ring and contact_ring.is_frozen():
		contact_ring.clear_frozen_result()


func _on_contact_ring_fade_completed() -> void:
	if charge_meter:
		charge_meter.visible = false


func _set_idle_ring() -> void:
	if contact_ring and (contact_ring.is_frozen() or contact_ring.is_flash_active()):
		return
	if charge_meter:
		charge_meter.visible = false
	if contact_ring:
		contact_ring.hide_idle()


func _update_charge_visuals() -> void:
	if not _swing.is_charging():
		if contact_ring and contact_ring.is_frozen():
			if charge_meter:
				charge_meter.visible = true
		else:
			if charge_meter:
				charge_meter.visible = false
			if contact_ring and not contact_ring.is_flash_active():
				contact_ring.hide_idle()
			if _ball_at_tee and ball:
				ball.position = _ball_home
				ball.scale = _base_ball_scale
				if ball.animation != &"roll":
					ball.play(&"idle")
			if golfer:
				golfer.position = _golfer_home
			_sync_golfer_idle_from_bucket()
		if not _swing.is_charging():
			return

	if charge_meter:
		charge_meter.visible = true

	var elapsed := _swing.charge_elapsed_sec()
	var windup := _swing.charge.windup_progress(elapsed)
	var in_band := _swing.charge.is_in_contact_band(elapsed, GameState.stats)
	var past_contact := _swing.charge.past_contact(elapsed)
	var past_contact_frac := _swing.charge.past_contact_fraction(elapsed)

	if contact_ring:
		contact_ring.update_visuals(
			windup, in_band, past_contact, past_contact_frac, elapsed, GameState.stats
		)

	if _ball_at_tee and ball:
		ball.position = _ball_home
		ball.scale = _base_ball_scale

	if golfer:
		golfer.position = _golfer_home


func _flash_beat_ring(tier: int) -> void:
	if not contact_ring:
		return
	if charge_meter:
		charge_meter.visible = true
	contact_ring.freeze_release_result(
		tier, _swing.last_contact_flavor, _swing.last_hold_sec, GameState.stats
	)


func _on_swing_resolved(
	yards: float,
	tier: int,
	_payout: float,
	feedback_tier: int
) -> void:
	GameState.note_swing_tier(tier)
	_flash_beat_ring(tier)
	HitPoof.spawn(
		fx_layer,
		get_flight_camera(),
		ball.global_position,
		tier,
		feedback_tier,
		Vector3(0.0, 0.0, -12.0),
		get_fx_reference_ortho_size()
	)
	var quality := Economy.quality_for_tier(tier)
	if feedback_tier == Balance.FeedbackTier.JACKPOT:
		_play_golfer_joy()
	elif not _golfer_joy_active:
		_play_swing_followthrough()
	_fly_ball(yards, feedback_tier, tier, quality)


func _play_golfer_joy() -> void:
	_golfer_joy_active = true
	golfer.play(&"joy")


func _play_return_to_address() -> void:
	if golfer == null:
		return
	golfer.speed_scale = 1.0
	golfer.play(&"return_to_address")


func _release_swing_finish() -> void:
	if golfer == null:
		return
	if golfer.animation == &"return_to_address":
		golfer.stop()
		golfer.speed_scale = 1.0
	_play_golfer_idle()


func _play_swing_followthrough() -> void:
	golfer.play(&"follow")


func _project_to_screen(world_pos: Vector3) -> Vector2:
	var cam := get_flight_camera()
	if cam == null:
		return Vector2.ZERO
	return cam.unproject_position(world_pos)


func _fairway_screen_dir(from_world: Vector3) -> Vector2:
	var origin := _project_to_screen(from_world)
	var down_line := _project_to_screen(from_world + Vector3(0.0, 0.0, -12.0))
	var dir := down_line - origin
	if dir.length_squared() < 1.0:
		return Vector2(0.0, -1.0)
	return dir.normalized()


func show_pickup_cash_float(
	world_pos: Vector3,
	payout: float,
	combo_tier: int,
	is_golden: bool = false
) -> void:
	var cam := get_flight_camera()
	var fx_scale := ScreenFxScale.compensation(cam, get_fx_reference_ortho_size())
	var text_color := Balance.GOLDEN_BALL_TINT if is_golden else Color.TRANSPARENT
	if is_golden and fx_layer and cam:
		GoldenBallAuraScript.spawn_pickup(
			fx_layer,
			cam,
			world_pos,
			get_fx_reference_ortho_size()
		)
	FloatCashTextScript.spawn(
		fx_layer,
		_project_to_screen(world_pos),
		payout,
		combo_tier,
		4,
		fx_scale,
		text_color
	)


func _handle_vanished_ball(landing: Vector3, quality: int, yardage: float, is_golden: bool = false) -> void:
	show_vanished_ball_fx(landing, quality, yardage, is_golden, "player")


func show_vanished_ball_fx(
	landing: Vector3,
	quality: int,
	yardage: float,
	is_golden: bool = false,
	source: String = "player"
) -> void:
	DistanceTwinkle.spawn(
		fx_layer,
		get_flight_camera(),
		landing,
		get_fx_reference_ortho_size(),
		is_golden
	)
	var payout: float
	if source == "ratina":
		payout = GameState.credit_ratina_vanished_ball(landing, quality, yardage, 1, is_golden)
	else:
		payout = GameState.credit_vanished_ball(landing, quality, yardage, 1, is_golden)
	show_pickup_cash_float(landing, payout, 1, is_golden)
	# Ratina vanish emits ratina_ball_collected; avoid double HUD stack rows.
	if payout > 0.0 and source != "ratina":
		EventBus.pickup_payout.emit(payout, 1)
	SfxManager.play_pickup_plink(1)
	_fly_vanished_ball_to_bucket(landing)


func _fly_vanished_ball_to_bucket(landing: Vector3) -> void:
	var start_screen := _project_to_screen(landing)
	var end_screen := _bucket_target_screen()
	await spawn_pickup_fly_icon(start_screen, end_screen)
	if _pickup and _pickup.has_method("try_complete_harvest"):
		_pickup.try_complete_harvest()


func _bucket_target_screen() -> Vector2:
	if _pickup and _pickup.has_method("get_bucket_target_screen"):
		return _pickup.get_bucket_target_screen()
	return Vector2(440.0, 250.0)


func spawn_pickup_fly_icon(start_screen: Vector2, end_screen: Vector2) -> void:
	if fx_layer == null or _ball_lay_texture == null:
		return
	var icon := Sprite2D.new()
	icon.texture = _ball_lay_texture
	icon.position = start_screen
	var fx_scale := ScreenFxScale.compensation(get_flight_camera(), get_fx_reference_ortho_size())
	icon.scale = Vector2(0.5, 0.5) * fx_scale
	fx_layer.add_child(icon)
	var mid := (start_screen + end_screen) * 0.5 + Vector2(0.0, -PICKUP_FLY_ARC_PX)
	var tween := icon.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(icon):
				return
			var u := 1.0 - t
			icon.position = (
				u * u * start_screen + 2.0 * u * t * mid + t * t * end_screen
			),
		0.0,
		1.0,
		PICKUP_FLY_DURATION_SEC
	)
	await tween.finished
	if is_instance_valid(icon):
		icon.queue_free()


func _setup_strike_feedback_billboard() -> void:
	_ensure_strike_feedback_billboard()


## Creates the player's world-space strike feedback billboard under the
## editor-placed anchor on first use. Bound once to the perspective/strike
## camera — never `get_flight_camera()` — so it keeps facing that camera
## even after a harvest (ortho) view-mode switch.
func _ensure_strike_feedback_billboard() -> StrikeFeedbackBillboard:
	if _strike_feedback_billboard != null and is_instance_valid(_strike_feedback_billboard):
		return _strike_feedback_billboard
	if strike_feedback_anchor == null:
		return null
	_strike_feedback_billboard = StrikeFeedbackBillboardScript.new()
	strike_feedback_anchor.add_child(_strike_feedback_billboard)
	_strike_feedback_billboard.setup(perspective_camera)
	return _strike_feedback_billboard


func _begin_yardage_counter(tier: int, yards: float) -> int:
	var billboard := _ensure_strike_feedback_billboard()
	if billboard == null:
		return -1
	return billboard.begin(tier, yards)


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_sync_tee_ball_from_bucket()
	_sync_golfer_idle_from_bucket()


func _on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_sync_tee_ball_from_bucket()
	elif phase == "strike":
		if golfer:
			golfer.position = _golfer_home
		ignore_pointer_until_release()
	_sync_golfer_idle_from_bucket()


func on_harvest_complete() -> void:
	_respawn_ball_at_tee()


func _setup_pickup_controller() -> void:
	_pickup = PickupControllerScript.new()
	_pickup.name = "PickupController"
	add_child(_pickup)
	var bucket_counter: Control = get_tree().root.get_node_or_null(
		"Main/UI/UIRoot/GameplayChrome/IconBar/BottomRight/BucketCounter"
	)
	if bucket_counter:
		_pickup.setup(self, littered_balls, bucket_counter)
	_setup_range_picker_indicator()


func _setup_range_picker_indicator() -> void:
	_picker_indicator = RangePickerIndicatorScript.new()
	_picker_indicator.name = "RangePickerIndicator"
	foreground.add_child(_picker_indicator)
	_picker_indicator.setup(
		func() -> Camera3D: return get_flight_camera(),
		func() -> bool: return _pickup != null and _pickup.is_active(),
		func() -> Dictionary:
			if _harvest_fog == null or _harvest_fog.fog_amount() <= 0.001:
				return {"active": false, "tee_z": 0.0, "reveal_yards": 0.0}
			return {
				"active": true,
				"tee_z": _harvest_fog.tee_z(),
				"reveal_yards": _harvest_fog.displayed_reveal_yards(),
			}
	)


func _setup_ratina_controller() -> void:
	_ratina = RatinaControllerScript.new()
	_ratina.name = "RatinaController"
	add_child(_ratina)
	_ratina.setup(self, ratina_bay)


func _setup_rattling_controller() -> void:
	_rattling_controller = RattlingControllerScript.new()
	_rattling_controller.name = "RattlingController"
	add_child(_rattling_controller)
	_rattling_controller.setup(self, foreground, littered_balls)
	_rattling_controller.apply_atmosphere_tint(_sprite_atmosphere_tint)


## Debug-only: force-unlocks Rattlings (no currency spent) and drops a test
## litter ball on the fairway centerline for one to walk out and fetch.
func _debug_spawn_test_rattling() -> void:
	if not GameState.rattlings_unlocked:
		GameState.rattlings_unlocked = true
		EventBus.stats_changed.emit(GameState.stats, GameState.currency)
	if GameState.rattling_stats.rattling_count < 1:
		GameState.rattling_stats.rattling_count = 1
	_leave_litter_ball(Vector3(0.0, 0.0, -12.0), _base_ball_scale, 3, 12.0, false)
	print("[debug] Rattlings force-unlocked; spawned a test litter ball at z=-12 for pickup.")


func _sync_tee_ball_from_bucket() -> void:
	if ball == null:
		return
	if not GameState.has_bucket_balls():
		ball.visible = false
		_ball_at_tee = false
		_tee_ball_prepared = false
		_clear_frozen_charge_ring()
		_set_idle_ring()
		_sync_golfer_idle_from_bucket()
		return
	if _ball_at_tee:
		ball.visible = true
		ball.position = _ball_home
		ball.scale = _base_ball_scale
		if not _tee_ball_prepared:
			_prepare_tee_ball()
		else:
			ball.modulate = _ball_modulate(_tee_ball_is_golden)
		if ball.animation != &"roll":
			ball.play(&"idle")


func _update_ball_reload() -> void:
	if ball == null:
		return
	if not GameState.has_bucket_balls():
		if ball.visible or _ball_at_tee:
			ball.visible = false
			_ball_at_tee = false
		return
	if _ball_at_tee:
		return
	if _swing.can_swing(GameState.stats):
		_respawn_ball_at_tee()


func _respawn_ball_at_tee() -> void:
	if ball == null:
		return
	ball.visible = true
	ball.position = _ball_home
	ball.scale = _base_ball_scale
	ball.play(&"idle")
	_ball_at_tee = true
	_prepare_tee_ball()
	_set_idle_ring()
	_release_swing_finish()
	_sync_golfer_idle_from_bucket()


func leave_litter_ball(
	land_position: Vector3,
	land_scale: Vector3,
	quality: int,
	yardage: float,
	is_golden: bool = false,
	source: String = "player"
) -> void:
	# Fog / blocked-cursor line tracks furthest rest, not carry alone (bounces run past).
	_record_rest_reach(land_position)
	var litter_id := _next_litter_id
	_next_litter_id += 1
	var litter := Sprite3D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = land_scale
	_configure_billboard(litter, BALL_PIXEL_SIZE)
	litter.modulate = Balance.GOLDEN_BALL_TINT if is_golden else _sprite_atmosphere_tint
	litter.set_meta("litter_id", litter_id)
	litter.set_meta("collectible", true)
	litter.set_meta("ball_quality", quality)
	litter.set_meta("ball_yardage", yardage)
	litter.set_meta("ball_golden", is_golden)
	litter.set_meta("ball_source", source)
	littered_balls.add_child(litter)
	EventBus.litter_spawned.emit(
		litter_id, land_position, quality, yardage, is_golden, source
	)


func _tee_world_z() -> float:
	if _harvest_fog != null:
		return _harvest_fog.tee_z()
	if player_bay != null:
		return player_bay.to_global(_ball_home).z
	return RangeGrid.player_bay_origin().z


func _record_rest_reach(land_position: Vector3) -> void:
	var reach := -(land_position.z - _tee_world_z())
	GameState.record_carry(reach)


func _on_bus_litter_removed(litter_id: int) -> void:
	if littered_balls == null or _suppress_litter_bus:
		return
	_suppress_litter_bus = true
	for child in littered_balls.get_children():
		if int(child.get_meta("litter_id", -1)) == litter_id:
			child.queue_free()
			break
	_suppress_litter_bus = false


func _on_bus_litter_cleared() -> void:
	if littered_balls == null or _suppress_litter_bus:
		return
	_suppress_litter_bus = true
	for child in littered_balls.get_children():
		child.queue_free()
	_suppress_litter_bus = false


func _leave_litter_ball(
	land_position: Vector3,
	land_scale: Vector3,
	quality: int,
	yardage: float,
	is_golden: bool = false
) -> void:
	leave_litter_ball(land_position, land_scale, quality, yardage, is_golden, "player")


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _roll_is_golden() -> bool:
	if GameState.is_perfect_chain_golden_active():
		return true
	var chance := GameState.stats.golden_ball_chance
	if chance <= 0.0:
		return false
	return randf() < chance


func _prepare_tee_ball() -> void:
	_tee_ball_is_golden = _roll_is_golden()
	_tee_ball_prepared = true
	if ball:
		ball.modulate = _ball_modulate(_tee_ball_is_golden)


func _ball_modulate(is_golden: bool) -> Color:
	if is_golden:
		return Balance.GOLDEN_BALL_TINT
	return _sprite_atmosphere_tint


func _sync_ball_in_flight_flag() -> void:
	_ball_in_flight = not _active_flights.is_empty()


func _register_flight(flight: Dictionary) -> void:
	_active_flights.append(flight)
	_sync_ball_in_flight_flag()


func _finish_flight(flight: Dictionary) -> void:
	_active_flights.erase(flight)
	_sync_ball_in_flight_flag()


func _spawn_flight_sprite() -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = DinkySpriteFrames.make_ball_frames()
	_configure_billboard(sprite, BALL_PIXEL_SIZE)
	sprite.scale = _base_ball_scale
	sprite.modulate = _sprite_atmosphere_tint
	sprite.add_to_group(&"range_flight_ball")
	foreground.add_child(sprite)
	return sprite


func _apply_flight_sample(progress: float, flight: Dictionary, path: BallFlight3D.FlightPath) -> void:
	var sprite: Node = flight.get("sprite")
	if not sprite is AnimatedSprite3D or not is_instance_valid(sprite):
		return
	if flight.get("with_bounces", false):
		sprite.global_position = BallFlight3D.sample_total(progress, path)
	else:
		sprite.global_position = BallFlight3D.sample(progress, path)
	var trail = flight.get("trail")
	if trail:
		trail.track(sprite.global_position)
	var yardage_id: int = int(flight.get("yardage_id", -1))
	if (
		yardage_id >= 0
		and _strike_feedback_billboard != null
		and is_instance_valid(_strike_feedback_billboard)
	):
		_strike_feedback_billboard.set_progress(yardage_id, progress)


func _fly_ball(yards: float, feedback_tier: int, timing_tier: int, quality: int) -> void:
	var tee_world := ball.global_position
	var path := BallFlight3D.build_path(
		yards,
		timing_tier,
		GameState.stats,
		_swing.last_contact_flavor,
		tee_world
	)
	var is_golden := _tee_ball_is_golden
	_tee_ball_prepared = false

	_ball_at_tee = false
	ball.visible = false

	# Litter on the fairway (including bounce runout). Shots that carry past
	# the far grass edge vanish at touchdown instead.
	var will_litter := path.landing.z >= -RangeGrid.DEPTH_YARDS
	var animate_time := path.total_time if will_litter else path.flight_time

	var flight_sprite := _spawn_flight_sprite()
	flight_sprite.global_position = tee_world
	flight_sprite.modulate = _ball_modulate(is_golden)
	flight_sprite.play(&"roll")
	flight_sprite.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFrames.BALL_ROLL_FRAME_COUNT) / animate_time
	)

	flight_sprite.set_meta("timing_tier", timing_tier)
	flight_sprite.set_meta("is_golden", is_golden)
	flight_sprite.set_meta("with_bounces", will_litter)
	var flight := {
		"sprite": flight_sprite,
		"trail": null,
		"is_golden": is_golden,
		"with_bounces": will_litter,
		"yardage_id": _begin_yardage_counter(timing_tier, yards),
	}
	var flight_cam := get_flight_camera()
	if fx_layer and flight_cam and visible:
		flight["trail"] = BallFlightTrailScript.begin(
			fx_layer,
			flight_cam,
			timing_tier,
			get_fx_reference_ortho_size()
		)
		flight["trail"].track(flight_sprite.global_position)
	_register_flight(flight)

	var tween := flight_sprite.create_tween()
	tween.tween_method(_apply_flight_sample.bind(flight, path), 0.0, 1.0, animate_time)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func():
		if not _active_flights.has(flight):
			return
		var trail = flight.get("trail")
		if trail:
			trail.finish()
		if is_instance_valid(flight_sprite):
			flight_sprite.queue_free()
		_finish_flight(flight)
		var yardage_id: int = int(flight.get("yardage_id", -1))
		if (
			yardage_id >= 0
			and _strike_feedback_billboard != null
			and is_instance_valid(_strike_feedback_billboard)
		):
			_strike_feedback_billboard.finish(yardage_id)
		if will_litter:
			_leave_litter_ball(path.rest_position, _base_ball_scale, quality, yards, is_golden)
		else:
			_handle_vanished_ball(BallFlight3D.sample(1.0, path), quality, yards, is_golden)
		_sync_golfer_idle_from_bucket()
	)

	var shake_cam := get_flight_camera()
	if feedback_tier == Balance.FeedbackTier.JACKPOT and shake_cam:
		var shake := shake_cam.create_tween()
		shake.tween_property(shake_cam, "h_offset", 0.05, 0.05)
		shake.tween_property(shake_cam, "h_offset", -0.04, 0.05)
		shake.tween_property(shake_cam, "h_offset", 0.0, 0.05)
