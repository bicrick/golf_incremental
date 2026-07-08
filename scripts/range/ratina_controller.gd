extends Node3D
## Autonomous second golfer — timer-driven swings, shared bucket + litter pool.

const BALL_PIXEL_SIZE := 0.021
const GOLFER_PIXEL_SIZE := 0.024

const DinkySpriteFramesScript := preload("res://scripts/range/dinky_sprite_frames.gd")
const BallFlight3DScript := preload("res://scripts/range/ball_flight_3d.gd")
const BallFlightTrailScript := preload("res://scripts/visual/ball_flight_trail.gd")
const FloatStrikeTextScript := preload("res://scripts/visual/float_strike_text.gd")

var _range_view: Node3D
var _golfer: AnimatedSprite3D
var _ball: AnimatedSprite3D
var _fx_layer: Node2D
var _camera: Camera3D

var _home: Vector3
var _ball_home: Vector3
var _base_ball_scale: Vector3 = Vector3.ONE
var _base_golfer_scale: Vector3 = Vector3.ONE
var _atmosphere_tint: Color = Color.WHITE

enum Phase { ADDRESS, WAITING, SWING }

var _swing_timer: Timer
var _phase_timer: Timer
var _phase := Phase.ADDRESS
var _active := false
## HUD toggle (independent of the one-time hire flag). When off, she fully
## despawns (fades out and hides) — any in-progress swing is cancelled outright.
var _enabled := true
var _swinging := false
var _ball_in_flight := false
var _contact_fired := false
var _pending_swing := false
var _flight_trail = null
var _flight_tween: Tween
var _fade_tween: Tween
var _debug_mode := false


func setup(range_view: Node3D, bay_cell: Node) -> void:
	_range_view = range_view
	_fx_layer = range_view.get_node_or_null("FxLayer")
	_camera = range_view.get_flight_camera() if range_view.has_method("get_flight_camera") else null

	_golfer = bay_cell.get_golfer() as AnimatedSprite3D
	_ball = bay_cell.get_ball() as AnimatedSprite3D
	_home = bay_cell.strike_home()
	_ball_home = bay_cell.ball_strike_home()
	_base_golfer_scale = bay_cell.get_base_golfer_scale()
	_base_ball_scale = bay_cell.get_base_ball_scale()

	_golfer.visible = false
	_golfer.animation_finished.connect(_on_golfer_animation_finished)
	_golfer.frame_changed.connect(_on_golfer_frame_changed)

	_ball.visible = false

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
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.helper_toggled.connect(_on_helper_toggled)
	_enabled = GameState.ratina_active
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
	elif _hired_and_enabled() and not _swinging and not _ball_in_flight:
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
	if _golfer:
		_home = _golfer.position
	if _ball:
		_ball_home = _ball.position
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


func set_flight_camera(cam: Camera3D) -> void:
	_camera = cam


func apply_atmosphere_tint(tint: Color) -> void:
	_atmosphere_tint = tint
	## Preserve whatever alpha a toggle fade is currently animating — a tint
	## refresh (e.g. day/night cycle) must never pop a faded-out Ratina back
	## to full opacity mid-fade.
	if _golfer:
		_golfer.modulate = Color(tint.r, tint.g, tint.b, _golfer.modulate.a)
	if _ball and _ball.visible:
		_ball.modulate = Color(tint.r, tint.g, tint.b, _ball.modulate.a)


func _on_stats_changed(_stats: PlayerStats, _currency: float) -> void:
	_refresh_active_state()


func _on_helper_toggled(helper: String, active: bool) -> void:
	if helper != "ratina":
		return
	_enabled = active
	if _enabled:
		_fade_in()
	else:
		_fade_out_and_despawn()


func _on_ratina_upgrade_purchased(_id: String, _level: int) -> void:
	_refresh_cooldown_timer()


func _on_phase_changed(_new_phase: String) -> void:
	## She keeps hitting through the player's collect mode — only her own
	## bucket/stash availability (via _can_swing) gates her, not the phase.
	if _hired_and_enabled() and not _debug_mode and not _swinging and not _ball_in_flight:
		_refresh_cooldown_timer()
		if _swing_timer.is_stopped() and not _pending_swing:
			_start_waiting_phase()


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	if not _can_swing():
		return
	if not _swinging and not _ball_in_flight and _swing_timer.is_stopped():
		_refresh_cooldown_timer()


func _refresh_active_state() -> void:
	## Resync from the source of truth here too (not just via helper_toggled) —
	## GameState.reset_to_fresh() writes ratina_active directly without going
	## through set_ratina_active(), so a stale cached _enabled could otherwise
	## survive a reset and permanently hide/despawn her (or vice versa).
	_enabled = GameState.ratina_active
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
		_golfer.visible = _active and _enabled
	if _ball:
		## Frequent EventBus.stats_changed emissions (e.g. Rattling collections)
		## route through here — never resurrect the ball mid-WAITING, or it
		## shows the last flight's looping "roll" frames frozen in place.
		## Also never resurrect the ball while she's toggled off, or the
		## HUD chip's fade-out gets undone by an unrelated stats refresh.
		var should_show_ball := _active and _enabled and not _ball_in_flight and _phase != Phase.WAITING
		if should_show_ball and not _ball.visible:
			_ball.position = _ball_home
			_ball.scale = _base_ball_scale
			_ball.play(&"idle")
		_ball.visible = should_show_ball


## HUD toggle switched off — this is a hard, immediate despawn (not "let the
## current swing finish"): cancel any in-progress swing/flight outright, then
## fade both sprites to invisible.
func _fade_out_and_despawn() -> void:
	_swing_timer.stop()
	_phase_timer.stop()
	_swinging = false
	_ball_in_flight = false
	_contact_fired = false
	_pending_swing = false
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	if _flight_tween and _flight_tween.is_valid():
		_flight_tween.kill()
		_flight_tween = null
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if _golfer:
		_fade_tween.tween_property(_golfer, "modulate:a", 0.0, Balance.RATTLING_FADE_SEC)
	if _ball:
		_fade_tween.tween_property(_ball, "modulate:a", 0.0, Balance.RATTLING_FADE_SEC)
	_fade_tween.set_parallel(false)
	_fade_tween.tween_callback(func():
		if _golfer:
			_golfer.visible = false
		if _ball:
			_ball.visible = false
	)


## HUD toggle switched back on — fade her back in, then resume the normal
## swing loop as if she'd just been hired.
func _fade_in() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if not _active or _debug_mode:
		return
	if _golfer:
		_golfer.visible = true
		_golfer.modulate.a = 0.0
		_golfer.play(&"idle")
	_fade_tween = create_tween()
	if _golfer:
		_fade_tween.tween_property(_golfer, "modulate:a", _atmosphere_tint.a, Balance.RATTLING_FADE_SEC)
	_fade_tween.tween_callback(func():
		_refresh_cooldown_timer()
		if not _swinging and not _ball_in_flight and not _pending_swing and _swing_timer.is_stopped():
			_start_waiting_phase()
	)


## Master gate for the whole swing/phase state machine — hired AND not
## toggled off via the HUD chip. Every scheduling function below must check
## this (not just `_active`), or a stray timer callback can pop her sprite
## or ball back to visible while she's supposed to be fully despawned.
func _hired_and_enabled() -> bool:
	return _active and _enabled


func _can_swing() -> bool:
	return _hired_and_enabled() and not _debug_mode and GameState.ratina_has_ball_to_hit()


func _cooldown_sec() -> float:
	return maxf(GameState.ratina_stats.swing_cooldown_ms / 1000.0, 0.35)


func _update_timer_interval() -> void:
	_swing_timer.wait_time = _cooldown_sec()


func _refresh_cooldown_timer() -> void:
	if not _hired_and_enabled() or _debug_mode or not _can_swing():
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
	if not _hired_and_enabled() or _debug_mode:
		return
	_update_timer_interval()
	_swing_timer.start()


func _on_swing_timer_timeout() -> void:
	if not _hired_and_enabled() or _debug_mode:
		return
	if _swinging or _ball_in_flight:
		_pending_swing = true
		return
	_perform_swing()


func _try_pending_swing() -> void:
	if not _hired_and_enabled() or _debug_mode or _swinging or _ball_in_flight:
		return
	if not _pending_swing:
		return
	_pending_swing = false
	_perform_swing()


func _perform_swing() -> void:
	if not _can_swing():
		_pending_swing = false
		return
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
	if not GameState.consume_ratina_bucket_ball():
		_abort_swing_no_ball()
		return
	_start_cooldown_timer()
	var tier := RatinaSwingResolver.roll_tier(GameState.ratina_stats.consistency)
	var strike_quality: float = Balance.TIER_MULTS[tier]
	var quality := Economy.quality_for_tier(tier)
	var yards := Economy.yards_from_quality(strike_quality, GameState.ratina_stats)
	EventBus.ratina_swing_resolved.emit(yards, tier, 0.0)
	SfxManager.play_ratina_hit(tier)

	var contact_screen := _project_to_screen(_ball.global_position)
	HitPoof.spawn(
		_fx_layer,
		_camera,
		_ball.global_position,
		tier,
		Balance.FeedbackTier.WHISPER,
		Vector3(0.0, 0.0, -12.0),
		_fx_reference_ortho_size()
	)
	FloatStrikeTextScript.spawn(
		_fx_layer,
		contact_screen,
		tier,
		yards,
		_strike_text_offset()
	)
	_fly_ball(yards, tier, quality)


func _abort_swing_no_ball() -> void:
	_swinging = false
	_contact_fired = false
	_ball_in_flight = false
	_pending_swing = false
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	if _ball:
		_ball.visible = false
	if _golfer:
		_golfer.play(&"waiting")
	_phase = Phase.WAITING


func _fly_ball(yards: float, timing_tier: int, quality: int) -> void:
	var tee_world := _ball.global_position
	var path := BallFlight3DScript.build_path(
		yards,
		timing_tier,
		GameState.ratina_stats,
		Balance.ContactFlavor.PURE,
		tee_world
	)

	_ball_in_flight = true
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	if _fx_layer and _camera:
		_flight_trail = BallFlightTrailScript.begin(
			_fx_layer,
			_camera,
			timing_tier,
			_fx_reference_ortho_size()
		)
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

	_flight_tween = create_tween()
	_flight_tween.tween_method(_apply_flight_sample.bind(path), 0.0, 1.0, path.flight_time)\
		.set_trans(Tween.TRANS_LINEAR)
	_flight_tween.chain().tween_callback(func():
		var landing := BallFlight3DScript.sample(1.0, path)
		_ball_in_flight = false
		_ball.visible = false
		if _flight_trail:
			_flight_trail.finish()
			_flight_trail = null
		_flight_tween = null
		_resolve_landing(landing, quality, yards, path.visual_yards)
		_try_pending_swing()
	)


func _resolve_landing(landing: Vector3, quality: int, yards: float, visual_yards: float) -> void:
	if _range_view == null:
		return
	if visual_yards <= Balance.VANISH_DISTANCE_YARDS:
		if _range_view.has_method("leave_litter_ball"):
			_range_view.leave_litter_ball(
				landing, _base_ball_scale, quality, yards, false, "ratina"
			)
	elif _range_view.has_method("show_vanished_ball_fx"):
		_range_view.show_vanished_ball_fx(landing, quality, yards, false, "ratina")


func _apply_flight_sample(progress: float, path: BallFlight3D.FlightPath) -> void:
	_ball.global_position = BallFlight3DScript.sample(progress, path)
	if _flight_trail:
		_flight_trail.track(_ball.global_position)


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
	if not _hired_and_enabled() or _debug_mode:
		return
	_start_waiting_phase()


func _start_waiting_phase() -> void:
	if not _hired_and_enabled() or _debug_mode or _swinging:
		return
	if _can_swing() and _swing_timer.is_stopped():
		_start_cooldown_timer()
	_phase = Phase.WAITING
	_golfer.play(&"waiting")
	if _ball and not _ball_in_flight:
		_ball.visible = false
	_reschedule_waiting_to_address()


func _reschedule_waiting_to_address() -> void:
	_phase_timer.stop()
	if _phase != Phase.WAITING or _swinging or not _hired_and_enabled():
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
	if _swinging or not _hired_and_enabled():
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


func _fx_reference_ortho_size() -> float:
	if _range_view != null and _range_view.has_method("get_fx_reference_ortho_size"):
		return _range_view.get_fx_reference_ortho_size()
	if _camera:
		return _camera.size
	return 8.0


func _project_to_screen(world_pos: Vector3) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	return _camera.unproject_position(world_pos)
