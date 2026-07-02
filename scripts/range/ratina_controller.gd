extends Node3D
## Autonomous second golfer — timer-driven swings, ball flight, income per hit.

const BALL_PIXEL_SIZE := 0.021
const GOLFER_PIXEL_SIZE := 0.024

const DinkySpriteFramesScript := preload("res://scripts/range/dinky_sprite_frames.gd")
const BallFlight3DScript := preload("res://scripts/range/ball_flight_3d.gd")
const BallFlightTrailScript := preload("res://scripts/visual/ball_flight_trail.gd")
const FloatCashTextScript := preload("res://scripts/visual/float_cash_text.gd")
const FloatStrikeTextScript := preload("res://scripts/visual/float_strike_text.gd")

var _range_view: Node3D
var _golfer: AnimatedSprite3D
var _ball: AnimatedSprite3D
var _ball_litter: Node3D
var _fx_layer: Node2D
var _camera: Camera3D

var _home: Vector3
var _ball_home: Vector3
var _base_ball_scale: Vector3 = Vector3.ONE
var _base_golfer_scale: Vector3 = Vector3.ONE
var _ball_lay_texture: Texture2D
var _atmosphere_tint: Color = Color.WHITE

enum Phase { ADDRESS, WAITING, SWING }

var _swing_timer: Timer
var _phase_timer: Timer
var _phase := Phase.ADDRESS
var _active := false
var _swinging := false
var _ball_in_flight := false
var _contact_fired := false
var _pending_swing := false
var _flight_trail = null
var _debug_mode := false


func setup(range_view: Node3D) -> void:
	_range_view = range_view
	_fx_layer = range_view.get_node_or_null("FxLayer")
	_camera = range_view.get_flight_camera() if range_view.has_method("get_flight_camera") else null
	_ball_lay_texture = DinkySpriteFramesScript.ball_lay_texture()

	_home = range_view.golfer_strike_home() + Balance.RATINA_HOME_OFFSET
	_ball_home = _home + Balance.RATINA_BALL_OFFSET

	_ball_litter = Node3D.new()
	_ball_litter.name = "RatinaBallLitter"
	range_view.get_node("Foreground").add_child(_ball_litter)

	_golfer = AnimatedSprite3D.new()
	_golfer.name = "Ratina"
	_golfer.sprite_frames = RatinaSpriteFrames.make_golfer_frames()
	_configure_billboard(_golfer, GOLFER_PIXEL_SIZE)
	_golfer.offset = RatinaSpriteFrames.FOOT_OFFSET
	_base_golfer_scale = _golfer.scale
	_golfer.position = _home
	range_view.get_node("Foreground").add_child(_golfer)
	_golfer.visible = false
	_golfer.animation_finished.connect(_on_golfer_animation_finished)
	_golfer.frame_changed.connect(_on_golfer_frame_changed)

	_ball = AnimatedSprite3D.new()
	_ball.name = "RatinaBall"
	_ball.sprite_frames = DinkySpriteFramesScript.make_ball_frames()
	_configure_billboard(_ball, BALL_PIXEL_SIZE)
	_base_ball_scale = _ball.scale
	_ball.position = _ball_home
	_ball.visible = false
	range_view.get_node("Foreground").add_child(_ball)

	_swing_timer = Timer.new()
	_swing_timer.name = "SwingTimer"
	_swing_timer.one_shot = true
	add_child(_swing_timer)
	_swing_timer.timeout.connect(_on_swing_timer_timeout)

	_phase_timer = Timer.new()
	_phase_timer.name = "PhaseTimer"
	_phase_timer.one_shot = true
	add_child(_phase_timer)
	_phase_timer.timeout.connect(_on_phase_timer_timeout)

	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.ratina_upgrade_purchased.connect(_on_ratina_upgrade_purchased)
	_refresh_active_state()


func get_golfer_sprite() -> AnimatedSprite3D:
	return _golfer


func get_ball_sprite() -> AnimatedSprite3D:
	return _ball


func strike_home() -> Vector3:
	return _home


func ball_strike_home() -> Vector3:
	return _ball_home


func get_base_golfer_scale() -> Vector3:
	return _base_golfer_scale


func get_base_ball_scale() -> Vector3:
	return _base_ball_scale


func set_debug_mode(active: bool) -> void:
	_debug_mode = active
	if active:
		_swing_timer.stop()
		_phase_timer.stop()
		_swinging = false
		_ball_in_flight = false
		_contact_fired = false
		if _flight_trail:
			_flight_trail.finish()
			_flight_trail = null
		if _golfer:
			_golfer.visible = true
			_golfer.play(&"idle")
			_golfer.position = _home
		if _ball:
			_ball.visible = true
			_ball.position = _ball_home
			_ball.play(&"idle")
	elif _active and not _swinging and not _ball_in_flight:
		_refresh_cooldown_timer()
		_start_waiting_phase()
	_sync_visibility()


func set_debug_positions(golfer_pos: Vector3, ball_pos: Vector3) -> void:
	_home = golfer_pos
	_ball_home = ball_pos
	if _golfer:
		_golfer.position = _home
	if _ball and not _ball_in_flight:
		_ball.position = _ball_home


func set_debug_scales(golfer_scale: Vector3, ball_scale: Vector3) -> void:
	_base_golfer_scale = golfer_scale
	_base_ball_scale = ball_scale
	if _golfer:
		_golfer.scale = golfer_scale
	if _ball and not _ball_in_flight:
		_ball.scale = ball_scale


func refresh_strike_homes() -> void:
	if _range_view == null:
		return
	_home = _range_view.golfer_strike_home() + Balance.RATINA_HOME_OFFSET
	_ball_home = _home + Balance.RATINA_BALL_OFFSET
	if _golfer and not _swinging:
		_golfer.position = _home
	if _ball and not _ball_in_flight:
		_ball.position = _ball_home


func apply_unlock_layout(golfer_scale: Vector3, ball_scale: Vector3) -> void:
	_base_golfer_scale = golfer_scale
	_base_ball_scale = ball_scale
	refresh_strike_homes()
	if _golfer:
		_golfer.scale = golfer_scale
	if _ball and not _ball_in_flight:
		_ball.scale = ball_scale


func apply_atmosphere_tint(tint: Color) -> void:
	_atmosphere_tint = tint
	if _golfer:
		_golfer.modulate = tint
	if _ball and _ball.visible:
		_ball.modulate = tint


func _configure_billboard(sprite: SpriteBase3D, pixel_size: float) -> void:
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_refresh_active_state()


func _on_ratina_upgrade_purchased(_id: String, _level: int) -> void:
	_refresh_cooldown_timer()


func _refresh_active_state() -> void:
	var should_be_active := GameState.ratina_unlocked
	if should_be_active == _active:
		if _active:
			_refresh_cooldown_timer()
		_sync_visibility()
		return
	_active = should_be_active
	_sync_visibility()
	if not _active:
		_swing_timer.stop()
		_phase_timer.stop()
		_swinging = false
		_ball_in_flight = false
		_contact_fired = false
		_pending_swing = false
		if _flight_trail:
			_flight_trail.finish()
			_flight_trail = null
		for child in _ball_litter.get_children():
			child.queue_free()
		return
	_refresh_cooldown_timer()
	_start_waiting_phase()


func _sync_visibility() -> void:
	if _debug_mode:
		if _golfer:
			_golfer.visible = true
		if _ball and not _ball_in_flight:
			_ball.visible = true
		return
	if _golfer:
		_golfer.visible = _active
	if _ball:
		_ball.visible = _active and not _ball_in_flight


func _cooldown_sec() -> float:
	return maxf(GameState.ratina_stats.swing_cooldown_ms / 1000.0, 0.35)


func _update_timer_interval() -> void:
	_swing_timer.wait_time = _cooldown_sec()


func _refresh_cooldown_timer() -> void:
	if not _active or _debug_mode:
		return
	_update_timer_interval()
	if _swinging or _ball_in_flight:
		return
	if _pending_swing:
		_try_pending_swing()
		return
	_swing_timer.start()
	if _phase == Phase.WAITING:
		_reschedule_waiting_to_address()


func _start_cooldown_timer() -> void:
	if not _active or _debug_mode:
		return
	_update_timer_interval()
	_swing_timer.start()


func _on_swing_timer_timeout() -> void:
	if not _active or _debug_mode:
		return
	if _swinging or _ball_in_flight:
		_pending_swing = true
		return
	_perform_swing()


func _try_pending_swing() -> void:
	if not _active or _debug_mode or _swinging or _ball_in_flight:
		return
	if not _pending_swing:
		return
	_pending_swing = false
	_perform_swing()


func _perform_swing() -> void:
	_swinging = true
	_contact_fired = false
	_phase = Phase.SWING
	_phase_timer.stop()
	_golfer.play(&"swing")
	_ball.visible = true
	_ball.position = _ball_home
	_ball.scale = _base_ball_scale
	_ball.modulate = _atmosphere_tint
	_ball.play(&"idle")


func _on_golfer_frame_changed() -> void:
	if not _swinging:
		return
	if _golfer.animation != &"swing":
		return
	if not _contact_fired and _golfer.frame == RatinaSpriteFrames.CONTACT_FRAME:
		_contact_fired = true
		_launch_ball()
	elif _golfer.frame >= RatinaSpriteFrames.FOLLOW_START + RatinaSpriteFrames.FOLLOW_HOLD_FRAMES:
		_complete_swing_anim()


func _launch_ball() -> void:
	_start_cooldown_timer()
	var tier := RatinaSwingResolver.roll_tier(GameState.ratina_stats.consistency)
	var strike_quality: float = Balance.TIER_MULTS[tier]
	var quality := Economy.quality_for_tier(tier)
	var yards := Economy.yards_from_quality(strike_quality, GameState.ratina_stats)
	var payout := GameState.credit_ratina_ball(yards, quality)
	EventBus.ratina_swing_resolved.emit(yards, tier, payout)
	SfxManager.play_ratina_hit(tier)

	var contact_screen := _project_to_screen(_ball.global_position)
	HitPoof.spawn(
		_fx_layer,
		contact_screen,
		_fairway_screen_dir(_ball.global_position),
		tier,
		Balance.FeedbackTier.WHISPER
	)
	FloatStrikeTextScript.spawn(
		_fx_layer,
		contact_screen,
		tier,
		yards,
		_strike_text_offset()
	)
	_fly_ball(yards, tier, quality, payout)


func _fly_ball(yards: float, timing_tier: int, quality: int, payout: float) -> void:
	var path := BallFlight3DScript.build_path(
		yards,
		timing_tier,
		GameState.ratina_stats,
		Balance.ContactFlavor.PURE,
		_ball_home
	)

	_ball_in_flight = true
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	if _fx_layer and _camera:
		_flight_trail = BallFlightTrailScript.begin(_fx_layer, _camera)
		_flight_trail.track(_ball.global_position)
	_ball.visible = true
	_ball.position = _ball_home
	_ball.scale = _base_ball_scale
	_ball.modulate = _atmosphere_tint
	_ball.play(&"roll")
	_ball.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFramesScript.BALL_ROLL_FRAME_COUNT) / path.flight_time
	)

	var tween := create_tween()
	tween.tween_method(_apply_flight_sample.bind(path), 0.0, 1.0, path.flight_time)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func():
		var landing := BallFlight3DScript.sample(1.0, path)
		_ball_in_flight = false
		_ball.visible = false
		if _flight_trail:
			_flight_trail.finish()
			_flight_trail = null
		_spawn_litter_ball(landing, quality)
		DistanceTwinkle.spawn(_fx_layer, _project_to_screen(landing))
		FloatCashTextScript.spawn(_fx_layer, _project_to_screen(landing), payout, 1)
		_try_pending_swing()
	)


func _apply_flight_sample(progress: float, path: BallFlight3D.FlightPath) -> void:
	_ball.global_position = BallFlight3DScript.sample(progress, path)
	if _flight_trail:
		_flight_trail.track(_ball.global_position)


func _spawn_litter_ball(land_position: Vector3, _quality: int) -> void:
	var litter := Sprite3D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = _base_ball_scale
	_configure_billboard(litter, BALL_PIXEL_SIZE)
	litter.modulate = _atmosphere_tint
	_ball_litter.add_child(litter)
	var despawn := get_tree().create_timer(Balance.RATINA_BALL_DESPAWN_SEC)
	despawn.timeout.connect(func():
		if is_instance_valid(litter):
			litter.queue_free()
	)


func _on_golfer_animation_finished() -> void:
	if _golfer.animation == &"swing" and _swinging:
		_complete_swing_anim()


func _on_phase_timer_timeout() -> void:
	if _phase == Phase.WAITING and not _swinging and not _ball_in_flight:
		_enter_address_prep_phase()


func _complete_swing_anim() -> void:
	if not _swinging:
		return
	_swinging = false
	_try_pending_swing()
	if _swinging:
		return
	if not _active or _debug_mode:
		return
	_start_waiting_phase()


func _start_waiting_phase() -> void:
	if not _active or _debug_mode or _swinging:
		return
	if _swing_timer.is_stopped():
		_start_cooldown_timer()
	_phase = Phase.WAITING
	_golfer.play(&"waiting")
	if _ball and not _ball_in_flight:
		_ball.visible = false
	_reschedule_waiting_to_address()


func _reschedule_waiting_to_address() -> void:
	_phase_timer.stop()
	if _phase != Phase.WAITING or _swinging or not _active:
		return
	var prep_sec := Balance.RATINA_ADDRESS_PREP_SEC
	var remaining := _swing_timer.time_left if not _swing_timer.is_stopped() else _cooldown_sec()
	var wait_duration := maxf(remaining - prep_sec, 0.0)
	if wait_duration <= 0.01:
		_enter_address_prep_phase()
	else:
		_phase_timer.wait_time = wait_duration
		_phase_timer.start()


func _enter_address_prep_phase() -> void:
	if _swinging or not _active:
		return
	_phase_timer.stop()
	_phase = Phase.ADDRESS
	_golfer.play(&"idle")
	if _ball and not _ball_in_flight:
		_ball.visible = true
		_ball.position = _ball_home
		_ball.play(&"idle")


func _strike_text_offset() -> Vector2:
	if _range_view != null and _range_view.has_method("ratina_strike_text_offset"):
		return _range_view.ratina_strike_text_offset()
	return Balance.RATINA_STRIKE_TEXT_OFFSET


func _project_to_screen(world_pos: Vector3) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	return _camera.unproject_position(world_pos)


func _fairway_screen_dir(from_world: Vector3) -> Vector2:
	var origin := _project_to_screen(from_world)
	var down_line := _project_to_screen(from_world + Vector3(0.0, 0.0, -12.0))
	var dir := down_line - origin
	if dir.length_squared() < 1.0:
		return Vector2(0.0, -1.0)
	return dir.normalized()
