extends Node3D
## Driving range view — real 3D scene. Camera3D projection now does the
## depth/vanishing-point work that used to be hand-rolled perspective math;
## this script places golfer/ball/litter at real Vector3 positions and lets
## the engine handle the rest.

const CHARGE_METER_POSITION := Vector2(236.0, 185.143)
## Local offset from rhombus center — text sits above the contact ring.
const SWING_RESULT_TEXT_OFFSET := Vector2(0.0, -38.0)
const BALL_PIXEL_SIZE := 0.021
const GOLFER_PIXEL_SIZE := 0.024
const VANISH_DISTANCE_YARDS := 220.0
const PICKUP_FLY_DURATION_SEC := 0.35
const PICKUP_FLY_ARC_PX := 36.0
const PickupControllerScript := preload("res://scripts/range/pickup_controller.gd")
const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const BallFlightTrailScript := preload("res://scripts/visual/ball_flight_trail.gd")

# Range Rat swing: linear wind-up frames 0-7; release at frame 8 (contact);
# follow-through auto-plays frames 9-16. Idle loops 5 frames from idle sheet.
# idle_out_of_balls loops 17 frames (5x4) when bucket is empty or in harvest phase.

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $Sun
@onready var camera: Camera3D = $Camera3D
@onready var sky_dome: RangeSkyDome = $SkyDome
@onready var ground: MeshInstance3D = $Ground
@onready var ball: AnimatedSprite3D = $Foreground/Ball
@onready var golfer: AnimatedSprite3D = $Foreground/Golfer
@onready var littered_balls: Node3D = $Foreground/LitteredBalls
@onready var foreground: Node3D = $Foreground
@onready var charge_meter: Node2D = $ChargeMeter
@onready var contact_ring = $ChargeMeter/BeatRing
@onready var fx_layer: Node2D = $FxLayer

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
var _placement_debug: PlacementDebug
var _pickup: Node
var _flight_trail = null
var _sprite_atmosphere_tint: Color = Color.WHITE


func _ready() -> void:
	_setup_ground()
	_setup_dinky_sprites()
	_ball_home = ball.position
	_golfer_home = golfer.position
	if charge_meter:
		charge_meter.position = CHARGE_METER_POSITION
	if contact_ring:
		contact_ring.frozen_fade_completed.connect(_on_contact_ring_fade_completed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	call_deferred("_sync_tee_ball_from_bucket")
	call_deferred("_setup_pickup_controller")
	if camera:
		camera.make_current()
	_set_idle_ring()
	if sun_light:
		sun_light.shadow_enabled = false
	if sky_dome and camera:
		sky_dome.setup(camera)
	apply_atmosphere(24.0)
	_setup_placement_debug()


func get_flight_camera() -> Camera3D:
	return camera


func _setup_dinky_sprites() -> void:
	_ball_lay_texture = DinkySpriteFrames.ball_lay_texture()
	ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
	_configure_billboard(ball, BALL_PIXEL_SIZE)
	_base_ball_scale = ball.scale
	ball.play(&"idle")

	golfer.sprite_frames = RangeRatSpriteFrames.make_golfer_frames()
	_configure_billboard(golfer, GOLFER_PIXEL_SIZE)
	golfer.offset = RangeRatSpriteFrames.FOOT_OFFSET
	_base_golfer_scale = golfer.scale
	_play_golfer_idle()
	golfer.animation_finished.connect(_on_golfer_animation_finished)


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _setup_ground() -> void:
	var snap := DayNightPalette.sample_at(24.0)
	FairwayGrassTiles3D.apply_palette(
		ground, Balance.FAIRWAY_HALF_WIDTH_YARDS, snap.fairway_light, snap.fairway_dark
	)


const PLATE_CAPTURE_CYCLE_TIME := 40.0
const PLATE_CAPTURE_OUTPUT := "res://captures/range_bg.png"


func capture_plate(output_path: String = PLATE_CAPTURE_OUTPUT, cycle_time: float = PLATE_CAPTURE_CYCLE_TIME) -> Error:
	var hidden: Array[Node] = []
	for node_name in ["Foreground", "ChargeMeter"]:
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


## Real 3D day/night: DirectionalLight3D + flat background color + ground palette
## + sprite atmosphere tint.
func apply_atmosphere(cycle_time: float) -> void:
	var snap := DayNightPalette.sample_at(cycle_time)
	_sprite_atmosphere_tint = snap.canvas_modulate
	var day_factor := DayNightPalette.celestial_alpha(cycle_time, false)
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.background_color = snap.sky
		# Moonlit sky is very dark; blend ambient toward fairway green so ground
		# stays readable without brightening the sky backdrop.
		env.ambient_light_color = snap.sky.lerp(snap.fairway_light, (1.0 - day_factor) * 0.45)
	FairwayGrassTiles3D.apply_palette(
		ground, Balance.FAIRWAY_HALF_WIDTH_YARDS, snap.fairway_light, snap.fairway_dark
	)
	if sun_light:
		sun_light.light_color = DayNightPalette.MOON_COLOR.lerp(DayNightPalette.SUN_COLOR, day_factor)
		sun_light.light_energy = lerpf(0.30, 1.15, day_factor)
		sun_light.rotation_degrees = Vector3(lerpf(-70.0, -35.0, day_factor), 35.0, 0.0)
	if sky_dome:
		sky_dome.update_atmosphere(cycle_time, snap)
	_apply_sprite_atmosphere_tint()


func _apply_sprite_atmosphere_tint() -> void:
	if golfer:
		golfer.modulate = _sprite_atmosphere_tint
	if ball:
		ball.modulate = _sprite_atmosphere_tint
	if littered_balls:
		for child in littered_balls.get_children():
			if child is SpriteBase3D:
				(child as SpriteBase3D).modulate = _sprite_atmosphere_tint


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
		camera,
		charge_meter,
		_golfer_home,
		_ball_home,
		_base_golfer_scale,
		_base_ball_scale,
		_on_debug_positions_changed,
		_on_debug_scales_changed
	)
	_placement_debug.mode_changed.connect(_on_debug_mode_changed)


func _on_debug_positions_changed(golfer_pos: Vector3, ball_pos: Vector3) -> void:
	_golfer_home = golfer_pos
	_ball_home = ball_pos
	golfer.position = _golfer_home


func _on_debug_scales_changed(golfer_scale: Vector3, ball_scale: Vector3) -> void:
	_base_golfer_scale = golfer_scale
	_base_ball_scale = ball_scale
	golfer.scale = golfer_scale
	ball.scale = ball_scale


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


func golfer_strike_home() -> Vector3:
	return _golfer_home


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

	if _ball_at_tee:
		ball.position = _ball_home
		ball.scale = _base_ball_scale

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
	if camera == null:
		return Vector2.ZERO
	return camera.unproject_position(world_pos)


func _fairway_screen_dir(from_world: Vector3) -> Vector2:
	var origin := _project_to_screen(from_world)
	var down_line := _project_to_screen(from_world + Vector3(0.0, 0.0, -12.0))
	var dir := down_line - origin
	if dir.length_squared() < 1.0:
		return Vector2(0.0, -1.0)
	return dir.normalized()


func show_pickup_cash_float(world_pos: Vector3, payout: float, combo_tier: int) -> void:
	FloatCashTextScript.spawn(fx_layer, _project_to_screen(world_pos), payout, combo_tier)


## Screen-space "fly to bucket" icon used by PickupController when a litter
## ball is collected — the litter itself is a 3D Sprite3D and is freed
## immediately on collect; this is purely UI juice, so it stays 2D.
func spawn_pickup_fly_icon(start_screen: Vector2, end_screen: Vector2) -> void:
	if fx_layer == null or _ball_lay_texture == null:
		return
	var icon := Sprite2D.new()
	icon.texture = _ball_lay_texture
	icon.position = start_screen
	icon.scale = Vector2(0.5, 0.5)
	fx_layer.add_child(icon)
	var mid := (start_screen + end_screen) * 0.5 + Vector2(0.0, -PICKUP_FLY_ARC_PX)
	var tween := create_tween()
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
	var tier_name := Balance.TIER_NAMES[tier]
	var label := Label.new()
	label.text = "%s\n%d yds" % [tier_name, int(yards)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 2
	PixelFont.apply_label(label, 8)
	label.modulate = Balance.TIER_COLORS[tier]
	charge_meter.add_child(label)
	label.reset_size()
	var size := label.get_minimum_size()
	label.position = Vector2(-size.x * 0.5, SWING_RESULT_TEXT_OFFSET.y - size.y)

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, ContactChargeRing.FROZEN_FADE_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_sync_tee_ball_from_bucket()
	_sync_golfer_idle_from_bucket()


func _on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_sync_tee_ball_from_bucket()
	elif phase == "strike":
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


func _leave_litter_ball(land_position: Vector3, land_scale: Vector3, quality: int, yardage: float) -> void:
	var litter := Sprite3D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = land_scale
	_configure_billboard(litter, BALL_PIXEL_SIZE)
	litter.modulate = _sprite_atmosphere_tint
	litter.set_meta("collectible", true)
	litter.set_meta("ball_quality", quality)
	litter.set_meta("ball_yardage", yardage)
	littered_balls.add_child(litter)


func _apply_flight_sample(progress: float, path: BallFlight3D.FlightPath) -> void:
	ball.global_position = BallFlight3D.sample(progress, path)
	if _flight_trail:
		_flight_trail.track(ball.global_position)


func _fly_ball(yards: float, feedback_tier: int, timing_tier: int, quality: int) -> void:
	var path := BallFlight3D.build_path(
		yards,
		timing_tier,
		GameState.stats,
		_swing.last_contact_flavor,
		_ball_home
	)

	_ball_in_flight = true
	_ball_at_tee = false
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	if fx_layer and camera:
		_flight_trail = BallFlightTrailScript.begin(fx_layer, camera)
		_flight_trail.track(ball.global_position)
	ball.visible = true
	ball.position = _ball_home
	ball.scale = _base_ball_scale
	ball.modulate = _sprite_atmosphere_tint
	ball.play(&"roll")
	ball.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFrames.BALL_ROLL_FRAME_COUNT) / path.flight_time
	)

	var tween := create_tween()
	tween.tween_method(_apply_flight_sample.bind(path), 0.0, 1.0, path.flight_time)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func():
		var landing := BallFlight3D.sample(1.0, path)
		_ball_in_flight = false
		if _flight_trail:
			_flight_trail.finish()
			_flight_trail = null
		if path.visual_yards <= VANISH_DISTANCE_YARDS:
			_leave_litter_ball(landing, _base_ball_scale, quality, yards)
		else:
			DistanceTwinkle.spawn(fx_layer, _project_to_screen(landing))
		ball.visible = false
		ball.modulate = _sprite_atmosphere_tint
		if GameState.has_bucket_balls():
			_update_ball_reload()
		else:
			_ball_at_tee = false
		_sync_golfer_idle_from_bucket()
	)

	if feedback_tier == Balance.FeedbackTier.JACKPOT and camera:
		var shake := create_tween()
		shake.tween_property(camera, "h_offset", 0.05, 0.05)
		shake.tween_property(camera, "h_offset", -0.04, 0.05)
		shake.tween_property(camera, "h_offset", 0.0, 0.05)
