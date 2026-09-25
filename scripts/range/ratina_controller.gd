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
var _flight_with_bounces := false
var _fade_tween: Tween
var _debug_mode := false
## v5 crew refactor — Ratina plants ONE standing challenge: she hits her own
## ball (never from your bucket) and it becomes a pink flag. The flag stays
## until one of your balls rests within ratina_mark_radius — that ball pays
## × ratina_mark_bonus at pickup — then she plants the next one.
var _demo_pending := false
var _mark_pos := Vector3.INF
var _mark_yards := 0.0
var _mark_ring: Sprite3D
var _mark_flag: Sprite3D
var _mark_label: Label3D

const MARK_FLAG_PATH := "res://assets/sprites/story/ratina_flag.png"
const MARK_FLAG_PIXEL_SIZE := 0.03
## Strike view: grow the flag with distance so it reads from the tee.
const MARK_FLAG_STRIKE_SCALE_PER_100YD := 2.2
const NEXT_MARK_DELAY_SEC := 2.5
## Screen-space call-out above Ratina's head in strike view ("Land it: 109 yd").
var _call_tag: PanelContainer
var _call_label: Label
const CALL_TAG_OFFSET := Vector2(0.0, -30.0)
const CALL_PINK := Color(0.86, 0.36, 0.56, 1.0)

const MARK_RING_COLOR := Color(1.0, 0.70, 0.84, 1.0)
const MARK_MIN_YARDS := 14.0
const MARK_RANGE_MIN := 0.45
const MARK_RANGE_MAX := 0.9
const DEMO_DELAY_SEC := 1.4


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
	EventBus.fairway_impact.connect(_on_fairway_impact)
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
		_clear_flight_group()
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
	if _flight_trail != null and is_instance_valid(_flight_trail) and _flight_trail.has_method("set_camera"):
		_flight_trail.set_camera(cam)


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
		_clear_flight_group()
		return
	_demo_pending = _mark_pos == Vector3.INF
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
	_clear_flight_group()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if _golfer:
		_fade_tween.tween_property(_golfer, "modulate:a", 0.0, Balance.RATINA_FADE_OUT_SEC)
	if _ball:
		_fade_tween.tween_property(_ball, "modulate:a", 0.0, Balance.RATINA_FADE_OUT_SEC)
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
	return (
		_hired_and_enabled()
		and not _debug_mode
		and _demo_pending
		and GameState.current_phase == "strike"
	)


func _cooldown_sec() -> float:
	return DEMO_DELAY_SEC


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
	## Demo ball — her own, not from the bucket. She places it on purpose.
	if not _demo_pending:
		_abort_swing_no_ball()
		return
	_demo_pending = false
	_camera = _resolve_flight_camera()
	var tier := Balance.TimingTier.PERFECT
	var quality := Economy.quality_for_tier(tier)
	var yards := _pick_mark_yards()
	SfxManager.play_ratina_hit(tier)
	HitPoof.spawn(
		_fx_layer,
		_camera,
		_ball.global_position,
		tier,
		Balance.FeedbackTier.WHISPER,
		Vector3(0.0, 0.0, -12.0),
		_fx_reference_ortho_size()
	)
	_fly_ball(yards, tier, quality)


## Somewhere inside what you can reach on a clean swing — a distance-control test.
func _pick_mark_yards() -> float:
	var reach := Economy.yards_from_quality(1.0, GameState.stats)
	var lo := maxf(MARK_MIN_YARDS, reach * MARK_RANGE_MIN)
	var hi := maxf(lo + 4.0, reach * MARK_RANGE_MAX)
	return randf_range(lo, hi)


func _abort_swing_no_ball() -> void:
	_swinging = false
	_contact_fired = false
	_ball_in_flight = false
	_pending_swing = false
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	_clear_flight_group()
	if _ball:
		_ball.visible = false
	if _golfer:
		_golfer.play(&"waiting")
	_phase = Phase.WAITING


func _clear_flight_group() -> void:
	if _ball != null and is_instance_valid(_ball) and _ball.is_in_group(&"range_flight_ball"):
		_ball.remove_from_group(&"range_flight_ball")


func _fly_ball(yards: float, timing_tier: int, quality: int) -> void:
	var tee_world := _ball.global_position
	var path := BallFlight3DScript.build_path(
		yards,
		timing_tier,
		GameState.ratina_stats,
		Balance.ContactFlavor.PURE,
		tee_world
	)

	# Litter on the fairway (including bounce runout). Shots that carry past
	# the far grass edge vanish at touchdown instead.
	var will_litter := path.landing.z >= -RangeGrid.DEPTH_YARDS
	var animate_time := path.total_time if will_litter else path.flight_time

	_ball_in_flight = true
	_flight_with_bounces = will_litter
	_camera = _resolve_flight_camera()
	_flight_with_bounces = will_litter
	if _flight_trail:
		_flight_trail.finish()
		_flight_trail = null
	var range_visible := _range_view != null and _range_view.visible
	if _fx_layer and _camera and range_visible:
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
	_ball.set_meta("timing_tier", timing_tier)
	_ball.set_meta("is_golden", false)
	_ball.set_meta("with_bounces", will_litter)
	if not _ball.is_in_group(&"range_flight_ball"):
		_ball.add_to_group(&"range_flight_ball")
	_ball.play(&"roll")
	_ball.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFramesScript.BALL_ROLL_FRAME_COUNT) / animate_time
	)

	_flight_tween = create_tween()
	_flight_tween.tween_method(_apply_flight_sample.bind(path), 0.0, 1.0, animate_time)\
		.set_trans(Tween.TRANS_LINEAR)
	_flight_tween.chain().tween_callback(func():
		var landing := path.rest_position if will_litter else BallFlight3DScript.sample(1.0, path)
		_ball_in_flight = false
		_ball.visible = false
		_clear_flight_group()
		if _flight_trail:
			_flight_trail.finish()
			_flight_trail = null
		_flight_tween = null
		_resolve_landing(landing, quality, yards)
		_try_pending_swing()
	)


func _resolve_landing(landing: Vector3, _quality: int, yards: float) -> void:
	if _range_view == null:
		return
	if landing.z < -RangeGrid.DEPTH_YARDS:
		_demo_pending = true
		return
	_mark_pos = landing
	_mark_yards = yards
	_plant_flag()


func _mark_parent() -> Node:
	var parent: Node = _range_view.get_node_or_null("Foreground")
	return parent if parent != null else _range_view


func _plant_flag() -> void:
	if _mark_ring == null or not is_instance_valid(_mark_ring):
		_mark_ring = _make_ring()
		_mark_parent().add_child(_mark_ring)
	if _mark_flag == null or not is_instance_valid(_mark_flag):
		_mark_flag = Sprite3D.new()
		_mark_flag.name = "RatinaMarkFlag"
		_mark_flag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_mark_flag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mark_flag.shaded = false
		_mark_flag.render_priority = 2
		_mark_flag.pixel_size = MARK_FLAG_PIXEL_SIZE
		_mark_flag.texture = load(MARK_FLAG_PATH)
		_mark_parent().add_child(_mark_flag)
		_mark_label = Label3D.new()
		_mark_label.name = "RatinaMarkLabel"
		_mark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark_label.shaded = false
		_mark_label.no_depth_test = true
		_mark_label.font = PixelFont.font_for_size(14)
		_mark_label.font_size = 14
		_mark_label.outline_size = 4
		_mark_label.modulate = Color(1.0, 0.82, 0.90, 1.0)
		_mark_label.outline_modulate = Color(0.42, 0.14, 0.26, 1.0)
		_mark_parent().add_child(_mark_label)
	var radius := GameState.ratina_stats.ratina_mark_radius
	_mark_ring.pixel_size = radius * 2.0 / 64.0
	_mark_ring.global_position = _mark_pos + Vector3(0.0, 0.03, 0.0)
	_mark_label.text = "%d yd" % int(round(_mark_yards))
	for node in [_mark_ring, _mark_flag, _mark_label]:
		node.visible = true
	_mark_flag.scale = Vector3.ZERO
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_mark_flag, "scale", Vector3.ONE, 0.35)
	_mark_ring.modulate = Color(1, 1, 1, 0.85)


func _ensure_call_tag() -> void:
	if _call_tag != null and is_instance_valid(_call_tag):
		return
	if _fx_layer == null:
		return
	_call_tag = PanelContainer.new()
	_call_tag.name = "RatinaCallTag"
	_call_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = CALL_PINK
	plate.border_color = Color(0.46, 0.14, 0.28, 1.0)
	plate.set_border_width_all(1)
	plate.shadow_color = Color(0.1, 0.12, 0.08, 0.35)
	plate.shadow_offset = Vector2(1, 1)
	plate.shadow_size = 0
	plate.content_margin_left = 4
	plate.content_margin_right = 4
	plate.content_margin_top = 2
	plate.content_margin_bottom = 2
	_call_tag.add_theme_stylebox_override(&"panel", plate)
	_call_label = Label.new()
	_call_label.add_theme_color_override(&"font_color", Color(1.0, 0.96, 0.90, 1.0))
	PixelFont.apply_label(_call_label, 8)
	_call_tag.add_child(_call_label)
	_fx_layer.add_child(_call_tag)


func _update_call_tag() -> void:
	var show := (
		_hired_and_enabled()
		and _mark_pos != Vector3.INF
		and GameState.current_phase == "strike"
		and _golfer != null
		and _golfer.visible
		and _range_view != null
		and _range_view.visible
	)
	if not show:
		if _call_tag != null and is_instance_valid(_call_tag):
			_call_tag.visible = false
		return
	_ensure_call_tag()
	if _call_tag == null:
		return
	_call_label.text = "Land it %d yd" % int(round(_mark_yards))
	_call_tag.visible = true
	_call_tag.reset_size()
	var head := _project_to_screen(_golfer.global_position)
	_call_tag.position = (head + CALL_TAG_OFFSET - _call_tag.size * 0.5).round()


func _process(_delta: float) -> void:
	_update_call_tag()
	## Keep the flag readable from the tee: scale up with distance in strike view.
	if _mark_flag == null or not is_instance_valid(_mark_flag) or not _mark_flag.visible:
		return
	var strike := GameState.current_phase == "strike"
	var s := 1.0
	if strike:
		s = maxf(1.0, _mark_yards / 100.0 * MARK_FLAG_STRIKE_SCALE_PER_100YD)
	if not _mark_flag.scale.is_equal_approx(Vector3.ZERO) and _mark_flag.scale.x >= 0.99:
		_mark_flag.scale = Vector3.ONE * s
	var h := 40.0 * MARK_FLAG_PIXEL_SIZE * _mark_flag.scale.x
	_mark_flag.global_position = _mark_pos + Vector3(0.0, h * 0.5, 0.0)
	_mark_label.global_position = _mark_pos + Vector3(0.0, h + 0.3 * s, 0.0)
	_mark_label.pixel_size = 0.012 * s
	_mark_ring.visible = not strike


func _make_ring() -> Sprite3D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			if d <= 1.0 and d >= 0.88:
				img.set_pixel(x, y, MARK_RING_COLOR)
			elif d < 0.88 and (x + y) % 6 == 0 and int(d * 8.0) % 2 == 0:
				img.set_pixel(x, y, Color(MARK_RING_COLOR, 0.3))
	var ring := Sprite3D.new()
	ring.name = "RatinaMarkRing"
	ring.axis = Vector3.AXIS_Y
	ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ring.shaded = false
	ring.double_sided = true
	ring.render_priority = -1
	ring.texture = ImageTexture.create_from_image(img)
	return ring


func _clear_mark() -> void:
	_mark_pos = Vector3.INF
	for node in [_mark_ring, _mark_flag, _mark_label]:
		if node != null and is_instance_valid(node):
			node.visible = false


func _on_fairway_impact(world_pos: Vector3) -> void:
	if _mark_pos == Vector3.INF or not _hired_and_enabled():
		return
	var flat := Vector2(world_pos.x - _mark_pos.x, world_pos.z - _mark_pos.z)
	if flat.length() > GameState.ratina_stats.ratina_mark_radius:
		return
	var litter_root: Node = _range_view.get("littered_balls")
	if litter_root == null:
		return
	for child in litter_root.get_children():
		if not child is Sprite3D:
			continue
		if String(child.get_meta("ball_source", "")) != "player":
			continue
		if (child as Sprite3D).global_position.distance_to(world_pos) > 0.05:
			continue
		if bool(child.get_meta("ratina_mark", false)):
			return
		child.set_meta("ratina_mark", true)
		if randf() < GameState.ratina_stats.ratina_mark_golden_chance:
			child.set_meta("ball_golden", true)
			(child as Sprite3D).modulate = Balance.GOLDEN_BALL_TINT
		GameState.lifetime["ratina_marks_hit"] = int(GameState.lifetime.get("ratina_marks_hit", 0)) + 1
		EventBus.ratina_mark_hit.emit(world_pos)
		_celebrate()
		_clear_mark()
		get_tree().create_timer(NEXT_MARK_DELAY_SEC).timeout.connect(_queue_next_mark)
		return


func _queue_next_mark() -> void:
	_demo_pending = true
	if _hired_and_enabled() and not _swinging and not _ball_in_flight:
		_refresh_cooldown_timer()


func _celebrate() -> void:
	if _golfer != null and not _swinging and _golfer.sprite_frames.has_animation(&"waiting"):
		_golfer.play(&"waiting")
	var sfx := get_node_or_null("/root/SfxManager")
	if sfx != null and sfx.has_method("play_ratina_mark_hit"):
		sfx.play_ratina_mark_hit()


func mark_position() -> Vector3:
	return _mark_pos


func _apply_flight_sample(progress: float, path: BallFlight3D.FlightPath) -> void:
	if _flight_with_bounces:
		_ball.global_position = BallFlight3DScript.sample_total(progress, path)
	else:
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


func _resolve_flight_camera() -> Camera3D:
	if _range_view != null and _range_view.has_method("get_flight_camera"):
		return _range_view.get_flight_camera()
	return _camera


func _fx_reference_ortho_size() -> float:
	if _range_view != null and _range_view.has_method("get_fx_reference_ortho_size"):
		return _range_view.get_fx_reference_ortho_size()
	if _camera:
		return _camera.size
	return 8.0


func _project_to_screen(world_pos: Vector3) -> Vector2:
	var cam := _resolve_flight_camera()
	if cam == null:
		return Vector2.ZERO
	return cam.unproject_position(world_pos)
