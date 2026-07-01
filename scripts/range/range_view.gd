extends Node2D
## Driving range view: parallax 2.5D layers, charge ring, ball flight, Range Rat + Dinky ball sprites.

const CHARGE_METER_POSITION := Vector2(270, 182)
const CHARGE_RING_Z_INDEX := 5
const BALL_PIXEL_SCALE := Vector2(0.6, 0.6)
const GOLFER_PIXEL_SCALE := Vector2(1.44, 1.44)
const GOLFER_HARVEST_SIDESTEP_X := -50.0
const GOLFER_HARVEST_TWEEN_SEC := 0.4
const FLIGHT_ARC_MIN_PX := 24.0
const FLIGHT_ARC_MAX_PX := 80.0
const FLIGHT_TIME_MIN_SEC := 0.40
const FLIGHT_TIME_MAX_SEC := 2.80
const FLIGHT_TIME_ARC_SEC := 0.55
const FLIGHT_TIME_TRAVEL_SEC := 1.10
const FLIGHT_TRAVEL_REF_PX := 110.0
const FLIGHT_DEPTH_EXPONENT := 0.34
const FLIGHT_DEPTH_STRETCH := 1.02
const FLIGHT_YARD_DEPTH_SCALE := 180.0
const FLIGHT_MIN_LANDING_Y := Balance.VISUAL_FLOOR_Y
const FLIGHT_BALL_TEXTURE_PX := 16.0
const LANDING_SCATTER_X := 28.0
const LANDING_Y_MARGIN := 8.0
const RANGE_X_MIN := 24.0
const RANGE_X_MAX := 456.0
const FAIRWAY_VANISHING_POINT := Vector2(240.0, 100.0)
# Fairway top must stay below vanishing point Y (y > 100) or stripe wedges overlap into solid green.
const FAIRWAY_TOP_Y := 105.0
const FAIRWAY_BOTTOM_Y := 270.0
const FAIRWAY_BOTTOM_LEFT := -800.0
const FAIRWAY_BOTTOM_RIGHT := 1280.0
const FAIRWAY_VIEWPORT_PAD := 120.0
const FAIRWAY_STRIPE_COUNT := 24
const FAIRWAY_BASE_COLOR := Color(0.40, 0.58, 0.32)
const FAIRWAY_STRIPE_LIGHT := Color(0.54, 0.76, 0.44)
const FAIRWAY_STRIPE_DARK := Color(0.36, 0.52, 0.28)
const MAT_Y_BACK := 180.0
# Absolute canvas z_index (z_as_relative = false) — background < fairway < litter < ball < golfer < float text
const Z_PARALLAX_SKY := -30
const Z_PARALLAX_HILLS := -20
const Z_PARALLAX_FAIRWAY := -10
const Z_LITTER := 1
const Z_BALL := 3
const Z_GOLFER := 4
const Z_FLOAT_TEXT := 4
const TEXT_BASE := "res://assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/Singles/TEXT"
const PickupControllerScript := preload("res://scripts/range/pickup_controller.gd")
const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")

# Range Rat swing: linear wind-up frames 0–7; release at frame 8 (contact);
# follow-through auto-plays frames 9–16. Idle loops 5 frames from idle sheet.
# idle_out_of_balls loops 17 frames (5x4) when bucket is empty or in harvest phase.

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var ball: AnimatedSprite2D = $Foreground/Ball
@onready var golfer: AnimatedSprite2D = $Foreground/Golfer
@onready var littered_balls: Node2D = $Foreground/LitteredBalls
@onready var parallax_sky: Parallax2D = $ParallaxSky
@onready var sky_polygon: Polygon2D = $ParallaxSky/Sky
@onready var sky_stars: Node2D = $ParallaxSky/Stars
@onready var sky_clouds: Node2D = $ParallaxSky/Clouds
@onready var sun: Node2D = $ParallaxSky/Sun
@onready var moon: Node2D = $ParallaxSky/Moon
@onready var parallax_hills: Parallax2D = $ParallaxHills
@onready var hills_polygon: Polygon2D = $ParallaxHills/Hills
@onready var parallax_fairway: Parallax2D = $ParallaxFairway
@onready var foreground: Node2D = $Foreground
@onready var charge_meter: Node2D = $ChargeMeter
@onready var contact_ring = $ChargeMeter/BeatRing
@onready var tier_sprite: Sprite2D = $JackpotFeedback/TierSprite
@onready var camera: Camera2D = $Camera2D

var _swing := Swing.new()
var _ball_home: Vector2
var _golfer_home: Vector2
var _base_ball_scale: Vector2 = BALL_PIXEL_SCALE
var _base_golfer_scale: Vector2 = GOLFER_PIXEL_SCALE
var _golfer_joy_active: bool = false
var _golfer_holding_finish: bool = false
var _ball_in_flight: bool = false
var _ball_at_tee: bool = true
var _ball_lay_texture: Texture2D
var _flight_config: BallFlightRenderer.FlightConfig
var _fairway_stripes: Array[Polygon2D] = []
var _placement_debug: PlacementDebug
var _pickup: Node
var _golfer_sidestep_tween: Tween
var _golfer_at_harvest_side := false
var _pending_harvest_sidestep := false


func _ready() -> void:
	_setup_fairway_stripes()
	_configure_draw_layers()
	_setup_dinky_sprites()
	_ball_home = ball.position
	_golfer_home = golfer.position
	_flight_config = _build_flight_config()
	if charge_meter:
		charge_meter.position = CHARGE_METER_POSITION
	if contact_ring:
		contact_ring.frozen_fade_completed.connect(_on_contact_ring_fade_completed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.range_action_changed.connect(_on_range_action_changed)
	call_deferred("_sync_tee_ball_from_bucket")
	call_deferred("_setup_pickup_controller")
	if camera:
		camera.make_current()
	_set_idle_ring()
	apply_atmosphere(24.0)
	_setup_placement_debug()


func _setup_dinky_sprites() -> void:
	_ball_lay_texture = DinkySpriteFrames.ball_lay_texture()
	ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
	ball.scale = BALL_PIXEL_SCALE
	_base_ball_scale = BALL_PIXEL_SCALE
	ball.play(&"idle")

	golfer.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
	golfer.scale = GOLFER_PIXEL_SCALE
	_base_golfer_scale = GOLFER_PIXEL_SCALE
	golfer.offset = RangeRatSpriteFrames.FOOT_OFFSET
	_play_golfer_idle()
	golfer.animation_finished.connect(_on_golfer_animation_finished)


func _setup_fairway_stripes() -> void:
	_fairway_stripes = FairwayStripes.populate(
		$ParallaxFairway/FairwayStripes, FAIRWAY_TOP_Y, FAIRWAY_BOTTOM_Y
	)


const PLATE_CAPTURE_CYCLE_TIME := 40.0
const PLATE_CAPTURE_OUTPUT := "res://captures/range_bg.png"


func capture_plate(output_path: String = PLATE_CAPTURE_OUTPUT, cycle_time: float = PLATE_CAPTURE_CYCLE_TIME) -> Error:
	var hidden: Array[Node] = []
	for node_name in ["Foreground", "ChargeMeter", "JackpotFeedback"]:
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
	if sky_polygon:
		sky_polygon.color = snap.sky
	if hills_polygon:
		hills_polygon.color = snap.hills
	FairwayStripes.apply_palette(
		_fairway_stripes, snap.fairway_base, snap.fairway_light, snap.fairway_dark
	)
	if canvas_modulate:
		canvas_modulate.color = snap.canvas_modulate
	if sun and sun.has_method(&"apply_celestial"):
		sun.apply_celestial(
			DayNightPalette.celestial_position(cycle_time, false),
			DayNightPalette.celestial_alpha(cycle_time, false),
			snap.moon_sky_cutout
		)
	if moon and moon.has_method(&"apply_celestial"):
		moon.apply_celestial(
			DayNightPalette.celestial_position(cycle_time, true),
			DayNightPalette.celestial_alpha(cycle_time, true),
			snap.moon_sky_cutout
		)
	if sky_stars and sky_stars.has_method(&"apply_visibility"):
		sky_stars.apply_visibility(DayNightPalette.star_visibility(cycle_time))
	if sky_clouds and sky_clouds.has_method(&"apply_visibility"):
		sky_clouds.apply_visibility(DayNightPalette.cloud_visibility(cycle_time))


func _configure_draw_layers() -> void:
	parallax_sky.z_as_relative = false
	parallax_sky.z_index = Z_PARALLAX_SKY
	parallax_hills.z_as_relative = false
	parallax_hills.z_index = Z_PARALLAX_HILLS
	parallax_fairway.z_as_relative = false
	parallax_fairway.z_index = Z_PARALLAX_FAIRWAY

	foreground.z_as_relative = false
	foreground.z_index = Z_LITTER
	littered_balls.z_as_relative = false
	littered_balls.z_index = Z_LITTER
	golfer.z_as_relative = false
	golfer.z_index = Z_GOLFER
	ball.z_as_relative = false
	ball.z_index = Z_BALL
	if charge_meter:
		charge_meter.z_as_relative = false
		charge_meter.z_index = CHARGE_RING_Z_INDEX


func _process(delta: float) -> void:
	_swing.update(delta)
	_update_ball_reload()
	_update_charge_visuals()


func _setup_placement_debug() -> void:
	_placement_debug = PlacementDebug.new()
	add_child(_placement_debug)
	_placement_debug.setup(
		golfer,
		ball,
		foreground,
		_golfer_home,
		_ball_home,
		_base_golfer_scale,
		_base_ball_scale,
		_on_debug_positions_changed,
		_on_debug_scales_changed
	)
	_placement_debug.mode_changed.connect(_on_debug_mode_changed)


func _on_debug_positions_changed(golfer_pos: Vector2, ball_pos: Vector2) -> void:
	_golfer_home = golfer_pos
	_ball_home = ball_pos
	_flight_config.tee_x = _ball_home.x
	_flight_config.tee_y = _ball_home.y
	if GameState.is_harvest_phase() and _golfer_at_harvest_side:
		_tween_golfer_to(_golfer_harvest_position(), true)
	elif not GameState.is_harvest_phase():
		golfer.position = _golfer_home


func _on_debug_scales_changed(golfer_scale: Vector2, ball_scale: Vector2) -> void:
	_base_golfer_scale = golfer_scale
	_base_ball_scale = ball_scale
	golfer.scale = golfer_scale
	ball.scale = ball_scale
	_flight_config.base_ball_scale = ball_scale
	_flight_config.min_visible_px = 1.0 * ball_scale.x


func _on_debug_mode_changed(active: bool) -> void:
	if active and _swing.is_charging():
		_swing.release_strike()
	if active:
		if charge_meter:
			charge_meter.visible = false
		_set_idle_ring()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _placement_debug and _placement_debug.is_active():
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


func golfer_strike_home() -> Vector2:
	return _golfer_home


func golfer_harvest_offset() -> Vector2:
	return Vector2(GOLFER_HARVEST_SIDESTEP_X, 0.0)


func _golfer_harvest_position() -> Vector2:
	return _golfer_home + golfer_harvest_offset()


func _kill_golfer_sidestep_tween() -> void:
	if _golfer_sidestep_tween and _golfer_sidestep_tween.is_valid():
		_golfer_sidestep_tween.kill()
	_golfer_sidestep_tween = null


func _tween_golfer_to(target: Vector2, at_harvest_side: bool = _golfer_at_harvest_side) -> void:
	_kill_golfer_sidestep_tween()
	if golfer.position.is_equal_approx(target):
		_golfer_at_harvest_side = at_harvest_side
		return
	_golfer_sidestep_tween = create_tween()
	_golfer_sidestep_tween.tween_property(
		golfer, "position", target, GOLFER_HARVEST_TWEEN_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_golfer_sidestep_tween.tween_callback(func() -> void:
		_golfer_at_harvest_side = at_harvest_side
	)


func _is_golfer_sidestep_tweening() -> bool:
	return _golfer_sidestep_tween != null and _golfer_sidestep_tween.is_valid()


func _request_harvest_sidestep() -> void:
	if not GameState.is_harvest_phase() or not GameState.is_collect_mode():
		return
	if _golfer_idle_blocked() or _ball_in_flight:
		_pending_harvest_sidestep = true
		return
	_pending_harvest_sidestep = false
	_golfer_at_harvest_side = true
	_play_golfer_idle()
	_tween_golfer_to(_golfer_harvest_position(), true)


func _request_strike_home() -> void:
	_pending_harvest_sidestep = false
	_golfer_at_harvest_side = false
	_tween_golfer_to(_golfer_home, false)


func _try_pending_harvest_sidestep() -> void:
	if not _pending_harvest_sidestep:
		return
	if not GameState.is_harvest_phase():
		_pending_harvest_sidestep = false
		return
	if _golfer_idle_blocked() or _ball_in_flight:
		return
	_request_harvest_sidestep()


func _sync_golfer_idle_from_bucket() -> void:
	if _golfer_idle_blocked():
		return
	if GameState.has_bucket_balls():
		# Bucket refilled — always leave idle_out_of_balls. Hold follow only while
		# the struck ball is still in flight and the tee is empty.
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
	_try_pending_harvest_sidestep()


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
	if _placement_debug and _placement_debug.is_active():
		return
	if not _swing.is_charging():
		if contact_ring and contact_ring.is_frozen():
			if charge_meter:
				charge_meter.visible = true
		else:
			if charge_meter:
				charge_meter.visible = false
			if contact_ring and not contact_ring.is_flash_active():
				contact_ring.hide_idle()
			if not _ball_in_flight:
				if _ball_at_tee:
					ball.position = _ball_home
					ball.scale = _base_ball_scale
					if ball.animation != &"roll":
						ball.play(&"idle")
				if GameState.is_collect_mode():
					_try_pending_harvest_sidestep()
				elif not _is_golfer_sidestep_tweening():
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

	if not _ball_at_tee:
		return

	var compress := windup * 0.14
	ball.scale = _base_ball_scale * Vector2(1.0 + compress * 0.5, 1.0 - compress)
	ball.position = _ball_home + Vector2(0.0, compress * 5.0)
	golfer.position = _golfer_home + Vector2(lerpf(0.0, -2.0, windup), lerpf(0.0, 1.0, windup))


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
	payout: float,
	feedback_tier: int
) -> void:
	_flash_beat_ring(tier)
	HitPoof.spawn(self, ball.global_position, tier, feedback_tier)
	_spawn_float_text(tier, yards, payout)
	_show_tier_sprite(tier, feedback_tier)
	if feedback_tier == Balance.FeedbackTier.JACKPOT:
		_play_golfer_joy()
	elif not _golfer_joy_active:
		_play_swing_followthrough()
	_fly_ball(yards, feedback_tier, tier)


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
	_try_pending_harvest_sidestep()


func _play_swing_followthrough() -> void:
	golfer.play(&"follow")


func _show_tier_sprite(tier: int, feedback_tier: int) -> void:
	if not tier_sprite:
		return
	var path := ""
	if feedback_tier == Balance.FeedbackTier.JACKPOT:
		path = TEXT_BASE + "/TXT_EAGLE.png"
	if path.is_empty():
		return
	tier_sprite.texture = load(path)
	tier_sprite.visible = true
	tier_sprite.modulate = Color.WHITE
	tier_sprite.scale = Vector2(2, 2)
	var tween := create_tween()
	tween.tween_property(tier_sprite, "modulate:a", 0.0, 0.85).set_delay(0.5)
	tween.tween_callback(func():
		tier_sprite.visible = false
		tier_sprite.modulate = Color.WHITE
	)


func show_pickup_cash_float(world_pos: Vector2, payout: float, combo_tier: int) -> void:
	FloatCashTextScript.spawn(self, world_pos, payout, combo_tier, Z_FLOAT_TEXT)


func _spawn_float_text(tier: int, yards: float, payout: float) -> void:
	var tier_name := Balance.TIER_NAMES[tier]
	var label := Label.new()
	label.text = "%s\n%d yds\n+$%s" % [tier_name, int(yards), FloatCashTextScript.format_amount(payout)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelFont.apply_label(label, 8)
	label.modulate = Balance.TIER_COLORS[tier]
	label.position = ball.global_position + Vector2(-36, -52)
	label.z_as_relative = false
	label.z_index = Z_FLOAT_TEXT
	add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -48), 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.85).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_sync_tee_ball_from_bucket()
	_sync_golfer_idle_from_bucket()


func _on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_sync_tee_ball_from_bucket()
		_sync_golfer_for_harvest_mode()
	elif phase == "strike":
		_request_strike_home()
	_sync_golfer_idle_from_bucket()


func _on_range_action_changed(_mode: String) -> void:
	if not GameState.is_harvest_phase():
		return
	_sync_tee_ball_from_bucket()
	_sync_golfer_for_harvest_mode()
	_sync_golfer_idle_from_bucket()


func _sync_golfer_for_harvest_mode() -> void:
	if GameState.is_collect_mode():
		_request_harvest_sidestep()
	else:
		_request_strike_home()


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


func _sync_tee_ball_from_bucket() -> void:
	if _ball_in_flight:
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
	if _ball_in_flight:
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
	ball.visible = true
	ball.position = _ball_home
	ball.scale = _base_ball_scale
	ball.play(&"idle")
	_ball_at_tee = true
	_set_idle_ring()
	_release_swing_finish()
	_sync_golfer_idle_from_bucket()


func _build_flight_config() -> BallFlightRenderer.FlightConfig:
	var config := BallFlightRenderer.FlightConfig.new()
	config.tee_x = _ball_home.x
	config.tee_y = _ball_home.y
	config.far_ground_y = FAIRWAY_TOP_Y
	config.ground_bottom_y = FAIRWAY_BOTTOM_Y
	config.mat_back_y = MAT_Y_BACK
	config.vanishing_point = FAIRWAY_VANISHING_POINT
	config.flight_depth_exponent = FLIGHT_DEPTH_EXPONENT
	config.flight_depth_stretch = FLIGHT_DEPTH_STRETCH
	config.yard_depth_scale = FLIGHT_YARD_DEPTH_SCALE
	config.min_landing_y = FLIGHT_MIN_LANDING_Y
	config.ball_texture_px = FLIGHT_BALL_TEXTURE_PX
	config.arc_min_px = FLIGHT_ARC_MIN_PX
	config.arc_max_px = FLIGHT_ARC_MAX_PX
	config.landing_scatter_x = LANDING_SCATTER_X
	config.range_x_min = RANGE_X_MIN
	config.range_x_max = RANGE_X_MAX
	config.flight_time_min_sec = FLIGHT_TIME_MIN_SEC
	config.flight_time_max_sec = FLIGHT_TIME_MAX_SEC
	config.flight_time_arc_sec = FLIGHT_TIME_ARC_SEC
	config.flight_time_travel_sec = FLIGHT_TIME_TRAVEL_SEC
	config.flight_travel_ref_px = FLIGHT_TRAVEL_REF_PX
	config.base_ball_scale = _base_ball_scale
	config.min_visible_px = 1.0 * _base_ball_scale.x
	return config


func _leave_litter_ball(land_position: Vector2, land_scale: Vector2) -> void:
	var litter := Sprite2D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = land_scale
	litter.z_as_relative = false
	litter.z_index = int(land_position.y)
	litter.set_meta("collectible", true)
	littered_balls.add_child(litter)


func _apply_flight_sample(progress: float, path: BallFlightRenderer.FlightPath) -> void:
	var sample := BallFlightRenderer.sample(progress, path, _flight_config)
	ball.position = sample["visual_pos"]
	ball.scale = sample["scale"]
	ball.modulate.a = sample["ball_alpha"]
	ball.visible = sample["visible"]


func _fly_ball(yards: float, feedback_tier: int, timing_tier: int) -> void:
	_flight_config.base_ball_scale = _base_ball_scale
	var path := BallFlightRenderer.build_path(
		yards,
		timing_tier,
		GameState.stats,
		_flight_config,
		_swing.last_contact_flavor
	)

	_ball_in_flight = true
	_ball_at_tee = false
	ball.visible = true
	ball.position = _ball_home
	ball.scale = _base_ball_scale
	ball.modulate = Color.WHITE
	ball.play(&"roll")
	ball.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFrames.BALL_ROLL_FRAME_COUNT) / path.flight_time
	)

	var tween := create_tween()
	tween.tween_method(_apply_flight_sample.bind(path), 0.0, 1.0, path.flight_time)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func():
		var landing := BallFlightRenderer.sample(1.0, path, _flight_config)
		_ball_in_flight = false
		if landing["visible"]:
			_leave_litter_ball(landing["visual_pos"], landing["scale"])
		else:
			DistanceTwinkle.spawn(self, landing["visual_pos"])
		ball.visible = false
		ball.modulate = Color.WHITE
		if GameState.has_bucket_balls():
			_update_ball_reload()
		else:
			_ball_at_tee = false
		_sync_golfer_idle_from_bucket()
		_try_pending_harvest_sidestep()
	)

	if feedback_tier == Balance.FeedbackTier.JACKPOT and camera:
		var shake := create_tween()
		shake.tween_property(camera, "offset", Vector2(4, -3), 0.05)
		shake.tween_property(camera, "offset", Vector2(-3, 2), 0.05)
		shake.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func nudge_parallax(offset: Vector2) -> void:
	for child in get_children():
		if child is Parallax2D:
			child.scroll_offset += offset
