@tool
extends Node3D
## Driving range view — orthographic v4 grid with contact-swing gameplay restored.
##
## @tool: builds ground meshes in the editor. Runtime wiring (EventBus, swing,
## pickup, Ratina) runs only when not Engine.is_editor_hint().

const CHARGE_METER_POSITION := Vector2(236.0, 185.143)
const RATINA_UNLOCKED_CHARGE_METER_POSITION := Vector2(225.0, 185.143)
const SWING_RESULT_TEXT_OFFSET := Vector2(0.0, -38.0)
const BALL_PIXEL_SIZE := 0.021
const VANISH_DISTANCE_YARDS := 220.0
const GOLDEN_BALL_TINT := Color(1.0, 0.88, 0.28, 1.0)
const PICKUP_FLY_DURATION_SEC := 0.35
const PICKUP_FLY_ARC_PX := 36.0
const PLATE_CAPTURE_CYCLE_TIME := 40.0
const PLATE_CAPTURE_OUTPUT := "res://captures/range_bg.png"

const PickupControllerScript := preload("res://scripts/range/pickup_controller.gd")
const RatinaControllerScript := preload("res://scripts/range/ratina_controller.gd")
const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const FloatStrikeTextScript := preload("res://scripts/visual/float_strike_text.gd")
const BallFlightTrailScript := preload("res://scripts/visual/ball_flight_trail.gd")
const RatinaBayCellScene := preload("res://scenes/range/cells/ratina_bay_cell.tscn")

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $Sun
@onready var camera: Camera3D = $Camera3D
@onready var sky_dome: RangeSkyDome = $SkyDome
@onready var ground: MeshInstance3D = $Ground
@onready var surround_ground: MeshInstance3D = $Surround
@onready var bays: Node3D = $Bays
@onready var littered_balls: Node3D = $Foreground/LitteredBalls
@onready var foreground: Node3D = $Foreground
@onready var player_bay: Node3D = $Bays/PlayerBay
@onready var charge_meter: Node2D = $ChargeMeter
@onready var contact_ring = $ChargeMeter/BeatRing
@onready var fx_layer: Node2D = $FxLayer
@onready var _camera_controller: RangeCameraController = $CameraController

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
var _golfer_holding_finish: bool = false
var _ball_in_flight: bool = false
var _ball_at_tee: bool = true
var _ball_lay_texture: Texture2D
var _pickup: Node
var _ratina: Node
var _active_flights: Array[Dictionary] = []
var _sprite_atmosphere_tint: Color = Color.WHITE
var _ratina_layout_applied: bool = false
var _ratina_strike_text_offset: Vector2 = Balance.RATINA_STRIKE_TEXT_OFFSET
var _surround_home_size: float = -1.0


func _should_use_editor_rig() -> bool:
	if not Engine.is_editor_hint():
		return false
	var edited := get_tree().edited_scene_root
	return edited != null and edited == self


func _enter_tree() -> void:
	if _should_use_editor_rig():
		_refresh_preview()


func _ready() -> void:
	_ball_lay_texture = DinkySpriteFrames.ball_lay_texture()
	_refresh_preview()
	_setup_ratina_bay()

	if charge_meter:
		charge_meter.position = CHARGE_METER_POSITION
	if camera:
		camera.make_current()
	if sky_dome and camera:
		sky_dome.setup(camera)
	apply_atmosphere(24.0)

	if Engine.is_editor_hint():
		if ratina_sprite:
			ratina_sprite.visible = true
		if ratina_ball_sprite:
			ratina_ball_sprite.visible = true
		return

	_setup_player_refs()
	_camera_controller.setup(camera)
	_camera_controller.set_enabled(visible)

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
	call_deferred("_apply_ratina_layout_if_needed")
	_set_idle_ring()
	if sun_light:
		sun_light.shadow_enabled = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _camera_controller and not Engine.is_editor_hint():
		_camera_controller.set_enabled(visible)


func consume_zoom_event(event: InputEvent) -> bool:
	if not visible or _camera_controller == null:
		return false
	return _camera_controller.consume_zoom_event(event)


func get_camera() -> Camera3D:
	return camera


func get_flight_camera() -> Camera3D:
	return camera


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
	_setup_camera()
	_setup_player_bay()


func _setup_player_bay() -> void:
	if player_bay == null:
		return
	player_bay.position = RangeGrid.player_bay_origin()
	var bay_ground := player_bay.get_node_or_null("Ground") as MeshInstance3D
	if bay_ground:
		bay_ground.visible = false


func _build_ground() -> void:
	if ground == null or surround_ground == null:
		return
	_ensure_ground_meshes()
	var snap := DayNightPalette.sample_at(24.0)
	_apply_ground_palette(snap.fairway_light, snap.fairway_dark)


func _ensure_ground_meshes() -> void:
	CellGround.ensure_grid_mesh(
		ground,
		RangeGrid.GRID_WIDTH_CELLS,
		RangeGrid.GRID_DEPTH_CELLS
	)
	var home_size := _camera_home_size()
	if not is_equal_approx(_surround_home_size, home_size):
		_surround_home_size = home_size
		surround_ground.mesh = FairwayGrassTiles3D.build_surround_mesh(
			Color.WHITE,
			home_size
		)
		surround_ground.set_surface_override_material(0, FairwayGrassTiles3D.make_apron_material())
		surround_ground.sorting_offset = -1.0


func _apply_ground_palette(light_color: Color, dark_color: Color) -> void:
	CellGround.apply_palette_uniforms(ground, light_color, dark_color)
	FairwayGrassTiles3D.apply_surround_palette_uniforms(
		surround_ground,
		light_color.lerp(dark_color, 0.2)
	)


func _camera_home_size() -> float:
	if camera:
		return camera.size
	return 8.0


func _setup_camera() -> void:
	if camera == null:
		return
	# Editor preview only — runtime uses the scene Camera3D transform as saved.
	if _should_use_editor_rig():
		V4CameraConfig.apply_locked_rotation_only(camera)
	camera.current = true


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
	_sprite_atmosphere_tint = snap.canvas_modulate
	var day_factor := DayNightPalette.celestial_alpha(cycle_time, false)
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_color = snap.sky
		env.ambient_light_color = snap.sky.lerp(snap.fairway_light, (1.0 - day_factor) * 0.45)
	_apply_ground_palette(snap.fairway_light, snap.fairway_dark)
	if sun_light:
		sun_light.light_color = DayNightPalette.MOON_COLOR.lerp(DayNightPalette.SUN_COLOR, day_factor)
		sun_light.light_energy = lerpf(0.30, 1.15, day_factor)
		sun_light.rotation_degrees = Vector3(lerpf(-70.0, -35.0, day_factor), 35.0, 0.0)
	if sky_dome:
		sky_dome.update_atmosphere(cycle_time, snap)
	if player_bay:
		player_bay.apply_ground_palette(snap.fairway_light, snap.fairway_dark)
	if ratina_bay:
		ratina_bay.apply_ground_palette(snap.fairway_light, snap.fairway_dark)
	_apply_sprite_atmosphere_tint()


func _apply_sprite_atmosphere_tint() -> void:
	if player_bay:
		player_bay.apply_sprite_tint(_sprite_atmosphere_tint)
	for flight in _active_flights:
		var sprite: Node = flight.get("sprite")
		if sprite is SpriteBase3D and is_instance_valid(sprite):
			(sprite as SpriteBase3D).modulate = _sprite_atmosphere_tint
	if littered_balls:
		for child in littered_balls.get_children():
			if child is SpriteBase3D:
				(child as SpriteBase3D).modulate = _sprite_atmosphere_tint
	if _ratina and _ratina.has_method("apply_atmosphere_tint"):
		_ratina.apply_atmosphere_tint(_sprite_atmosphere_tint)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_swing.update(delta)
	_update_ball_reload()
	_update_charge_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not visible:
		return
	if _camera_controller and _camera_controller.consume_zoom_event(event):
		get_viewport().set_input_as_handled()
		return
	if _pickup and _pickup.handle_input(event):
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


func _on_swing_charging_changed(charging: bool) -> void:
	if charging:
		_golfer_joy_active = false
		_golfer_holding_finish = false
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
	if charge_meter:
		charge_meter.position = RATINA_UNLOCKED_CHARGE_METER_POSITION
	_ratina_strike_text_offset = Balance.RATINA_STRIKE_TEXT_OFFSET
	if _ratina and _ratina.has_method("refresh_strike_homes"):
		_ratina.refresh_strike_homes()


func _sync_golfer_idle_from_bucket() -> void:
	if golfer == null or _golfer_idle_blocked():
		return
	if GameState.has_bucket_balls():
		if _golfer_holding_finish and not _ball_at_tee:
			return
		_golfer_holding_finish = false
	else:
		_golfer_holding_finish = false
	_play_golfer_idle()


func _on_golfer_animation_finished() -> void:
	if golfer.animation == &"joy":
		_golfer_joy_active = false
		if not _swing.is_charging():
			_play_golfer_idle()
	elif golfer.animation == &"follow":
		_hold_swing_finish()


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
		golfer.position = _golfer_home + Vector3(0.0, lerpf(0.0, 0.03, windup), lerpf(0.0, -0.03, windup))


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
	_flash_beat_ring(tier)
	HitPoof.spawn(
		fx_layer,
		_project_to_screen(ball.global_position),
		_fairway_screen_dir(ball.global_position),
		tier,
		feedback_tier
	)
	var quality := Economy.quality_for_tier(tier)
	_spawn_float_text(tier, yards)
	if feedback_tier == Balance.FeedbackTier.JACKPOT:
		_play_golfer_joy()
	elif not _golfer_joy_active:
		_play_swing_followthrough()
	_fly_ball(yards, feedback_tier, tier, quality)


func _play_golfer_joy() -> void:
	_golfer_holding_finish = false
	_golfer_joy_active = true
	golfer.play(&"joy")


func _hold_swing_finish() -> void:
	if not GameState.has_bucket_balls() or _ball_at_tee:
		_golfer_holding_finish = false
		_play_golfer_idle()
		return
	_golfer_holding_finish = true
	golfer.stop()
	golfer.animation = &"follow"
	golfer.frame = golfer.sprite_frames.get_frame_count(&"follow") - 1


func _release_swing_finish() -> void:
	_golfer_holding_finish = false
	if not _golfer_idle_blocked():
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


func show_pickup_cash_float(world_pos: Vector3, payout: float, combo_tier: int) -> void:
	FloatCashTextScript.spawn(fx_layer, _project_to_screen(world_pos), payout, combo_tier)


func _handle_vanished_ball(landing: Vector3, quality: int, yardage: float, is_golden: bool = false) -> void:
	DistanceTwinkle.spawn(fx_layer, _project_to_screen(landing))
	var payout := GameState.credit_vanished_ball(landing, quality, yardage, 1, is_golden)
	show_pickup_cash_float(landing, payout, 1)
	if payout > 0.0:
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
	icon.scale = Vector2(0.5, 0.5)
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


func _spawn_float_text(tier: int, yards: float) -> void:
	if charge_meter == null:
		return
	FloatStrikeTextScript.spawn(
		charge_meter,
		Vector2.ZERO,
		tier,
		yards,
		SWING_RESULT_TEXT_OFFSET
	)


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_sync_tee_ball_from_bucket()
	_sync_golfer_idle_from_bucket()


func _on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_sync_tee_ball_from_bucket()
	elif phase == "strike":
		if golfer:
			golfer.position = _golfer_home
	_sync_golfer_idle_from_bucket()


func on_harvest_complete() -> void:
	_respawn_ball_at_tee()


func _setup_pickup_controller() -> void:
	_pickup = PickupControllerScript.new()
	_pickup.name = "PickupController"
	add_child(_pickup)
	var bucket_counter: Control = get_tree().root.get_node_or_null(
		"Main/UI/UIRoot/IconBar/BottomRight/BucketCounter"
	)
	if bucket_counter:
		_pickup.setup(self, littered_balls, bucket_counter)


func _setup_ratina_controller() -> void:
	_ratina = RatinaControllerScript.new()
	_ratina.name = "RatinaController"
	add_child(_ratina)
	_ratina.setup(self, ratina_bay)


func _sync_tee_ball_from_bucket() -> void:
	if ball == null:
		return
	if not GameState.has_bucket_balls():
		ball.visible = false
		_ball_at_tee = false
		_clear_frozen_charge_ring()
		_set_idle_ring()
		_sync_golfer_idle_from_bucket()
		return
	if _ball_at_tee:
		ball.visible = true
		ball.position = _ball_home
		ball.scale = _base_ball_scale
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
	_set_idle_ring()
	_release_swing_finish()
	_sync_golfer_idle_from_bucket()


func _leave_litter_ball(
	land_position: Vector3,
	land_scale: Vector3,
	quality: int,
	yardage: float,
	is_golden: bool = false
) -> void:
	var litter := Sprite3D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = land_scale
	_configure_billboard(litter, BALL_PIXEL_SIZE)
	litter.modulate = GOLDEN_BALL_TINT if is_golden else _sprite_atmosphere_tint
	litter.set_meta("collectible", true)
	litter.set_meta("ball_quality", quality)
	litter.set_meta("ball_yardage", yardage)
	litter.set_meta("ball_golden", is_golden)
	littered_balls.add_child(litter)


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _roll_is_golden() -> bool:
	var chance := GameState.stats.golden_ball_chance
	if chance <= 0.0:
		return false
	return randf() < chance


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
	foreground.add_child(sprite)
	return sprite


func _apply_flight_sample(progress: float, flight: Dictionary, path: BallFlight3D.FlightPath) -> void:
	var sprite: Node = flight.get("sprite")
	if not sprite is AnimatedSprite3D or not is_instance_valid(sprite):
		return
	sprite.global_position = BallFlight3D.sample(progress, path)
	var trail = flight.get("trail")
	if trail:
		trail.track(sprite.global_position)


func _fly_ball(yards: float, feedback_tier: int, timing_tier: int, quality: int) -> void:
	var tee_world := ball.global_position
	var path := BallFlight3D.build_path(
		yards,
		timing_tier,
		GameState.stats,
		_swing.last_contact_flavor,
		tee_world
	)

	_ball_at_tee = false
	ball.visible = false

	var flight_sprite := _spawn_flight_sprite()
	flight_sprite.global_position = tee_world
	flight_sprite.play(&"roll")
	flight_sprite.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFrames.BALL_ROLL_FRAME_COUNT) / path.flight_time
	)

	var flight := {
		"sprite": flight_sprite,
		"trail": null,
	}
	var flight_cam := get_flight_camera()
	if fx_layer and flight_cam:
		flight["trail"] = BallFlightTrailScript.begin(fx_layer, flight_cam)
		flight["trail"].track(flight_sprite.global_position)
	_register_flight(flight)

	var tween := flight_sprite.create_tween()
	tween.tween_method(_apply_flight_sample.bind(flight, path), 0.0, 1.0, path.flight_time)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func():
		if not _active_flights.has(flight):
			return
		var landing := BallFlight3D.sample(1.0, path)
		var trail = flight.get("trail")
		if trail:
			trail.finish()
		if is_instance_valid(flight_sprite):
			flight_sprite.queue_free()
		_finish_flight(flight)
		var is_golden := _roll_is_golden()
		if path.visual_yards <= VANISH_DISTANCE_YARDS:
			_leave_litter_ball(landing, _base_ball_scale, quality, yards, is_golden)
		else:
			_handle_vanished_ball(landing, quality, yards, is_golden)
		_sync_golfer_idle_from_bucket()
	)

	var shake_cam := get_flight_camera()
	if feedback_tier == Balance.FeedbackTier.JACKPOT and shake_cam:
		var shake := shake_cam.create_tween()
		shake.tween_property(shake_cam, "h_offset", 0.05, 0.05)
		shake.tween_property(shake_cam, "h_offset", -0.04, 0.05)
		shake.tween_property(shake_cam, "h_offset", 0.0, 0.05)
