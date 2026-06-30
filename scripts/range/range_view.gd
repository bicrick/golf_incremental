extends Node2D
## Driving range view: parallax 2.5D layers, charge ring, ball flight, Dinky sprites.

const CHARGE_METER_POSITION := Vector2(300, 182)
const POWER_BAR_HEIGHT := 56.0
const POWER_BAR_HALF_WIDTH := 3.0
const BALL_PIXEL_SCALE := Vector2(1, 1)
const GOLFER_PIXEL_SCALE := Vector2(3, 3)
const FLIGHT_ARC_MIN_PX := 12.0
const FLIGHT_ARC_MAX_PX := 40.0
const FLIGHT_TIME_MIN_SEC := 0.65
const FLIGHT_TIME_RANGE_SEC := 0.95
const FLIGHT_DEPTH_EXPONENT := 0.34
const FLIGHT_DEPTH_STRETCH := 1.02
const FLIGHT_YARD_DEPTH_SCALE := 180.0
const FLIGHT_MIN_LANDING_Y := 176.0
const FLIGHT_BALL_TEXTURE_PX := 8.0
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
const MAT_Y_FRONT := 225.0
const MAT_Y_BACK := 195.0
const MAT_X_LEFT := 158.0
const MAT_X_RIGHT := 292.0
const MAT_BORDER_OUTSET := 3.0
# Absolute canvas z_index (z_as_relative = false) — background < fairway < mat < litter < golfer < ball < float text
const Z_PARALLAX_SKY := -30
const Z_PARALLAX_HILLS := -20
const Z_PARALLAX_FAIRWAY := -10
const Z_MAT := 0
const Z_LITTER := 1
const Z_GOLFER := 2
const Z_BALL := 3
const Z_FLOAT_TEXT := 4
const SWING_FRAME_COUNT := 5
const TEXT_BASE := "res://assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/Singles/TEXT"

# Swing wind-up maps charge_progress (0→1) to Swing01–05 frames over charge_duration_sec().
# Normal charge: Balance.CHARGE_DURATION_SEC (0.5s).
# Release holds Swing05 (frame 4) at impact; ball roll uses 11 frames at speed 11 / flight_time.

@onready var ball: AnimatedSprite2D = $Foreground/Ball
@onready var golfer: AnimatedSprite2D = $Foreground/Golfer
@onready var littered_balls: Node2D = $Foreground/LitteredBalls
@onready var range_mat: Node2D = $RangeMat
@onready var parallax_sky: Parallax2D = $ParallaxSky
@onready var parallax_hills: Parallax2D = $ParallaxHills
@onready var parallax_fairway: Parallax2D = $ParallaxFairway
@onready var foreground: Node2D = $Foreground
@onready var charge_meter: Node2D = $ChargeMeter
@onready var beat_ring: Node2D = $ChargeMeter/BeatRing
@onready var ring_outer: Polygon2D = $ChargeMeter/BeatRing/RingOuter
@onready var ring_inner: Polygon2D = $ChargeMeter/BeatRing/RingInner
@onready var sweet_spot_glow: Polygon2D = $ChargeMeter/BeatRing/SweetSpotGlow
@onready var sweet_spot_label: Label = $ChargeMeter/SweetSpotLabel
@onready var tier_sprite: Sprite2D = $JackpotFeedback/TierSprite
@onready var camera: Camera2D = $Camera2D
var power_bar_fill: Polygon2D = null

var _swing := Swing.new()
var _ball_home: Vector2
var _golfer_home: Vector2
var _base_ball_scale: Vector2 = BALL_PIXEL_SCALE
var _base_golfer_scale: Vector2 = GOLFER_PIXEL_SCALE
var _ring_base_scale: float = 1.0
var _flash_tween: Tween
var _result_flash_active: bool = false
var _golfer_joy_active: bool = false
var _ball_in_flight: bool = false
var _ball_at_tee: bool = true
var _ball_lay_texture: Texture2D
var _flight_config: BallFlightRenderer.FlightConfig


func _ready() -> void:
	_setup_fairway_stripes()
	_setup_range_mat()
	_configure_draw_layers()
	_setup_dinky_sprites()
	_ball_home = ball.position
	_golfer_home = golfer.position
	_flight_config = _build_flight_config()
	PixelFont.apply_label(sweet_spot_label, 8)
	if charge_meter:
		charge_meter.position = CHARGE_METER_POSITION
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	if camera:
		camera.make_current()
	_set_idle_ring()


func _setup_dinky_sprites() -> void:
	_ball_lay_texture = DinkySpriteFrames.ball_lay_texture()
	ball.sprite_frames = DinkySpriteFrames.make_ball_frames()
	ball.scale = BALL_PIXEL_SCALE
	_base_ball_scale = BALL_PIXEL_SCALE
	ball.play(&"idle")

	golfer.sprite_frames = DinkySpriteFrames.make_golfer_frames()
	golfer.scale = GOLFER_PIXEL_SCALE
	_base_golfer_scale = GOLFER_PIXEL_SCALE
	golfer.play(&"idle")
	golfer.animation_finished.connect(_on_golfer_animation_finished)


func _setup_fairway_stripes() -> void:
	FairwayStripes.populate($ParallaxFairway/FairwayStripes, FAIRWAY_TOP_Y, FAIRWAY_BOTTOM_Y)


func _setup_range_mat() -> void:
	range_mat.position = Vector2.ZERO
	for child in range_mat.get_children():
		child.free()

	var fill_corners := _mat_trapezoid(MAT_X_LEFT, MAT_X_RIGHT, MAT_Y_FRONT, MAT_Y_BACK)
	var border_corners := _mat_trapezoid(
		MAT_X_LEFT - MAT_BORDER_OUTSET,
		MAT_X_RIGHT + MAT_BORDER_OUTSET,
		MAT_Y_FRONT + MAT_BORDER_OUTSET * 0.5,
		MAT_Y_BACK - MAT_BORDER_OUTSET
	)

	var border := Polygon2D.new()
	border.color = Color(0.08, 0.18, 0.08)
	border.polygon = border_corners
	range_mat.add_child(border)

	var fill := Polygon2D.new()
	fill.color = Color(0.15, 0.38, 0.15)
	fill.polygon = fill_corners
	range_mat.add_child(fill)

	var back_left := fill_corners[3]
	var back_right := fill_corners[2]
	var highlight := Polygon2D.new()
	highlight.color = Color(0.28, 0.55, 0.28)
	highlight.polygon = PackedVector2Array([
		back_left + Vector2(3.0, 3.0),
		back_right + Vector2(-3.0, 3.0),
		back_right + Vector2(-3.0, 7.0),
		back_left + Vector2(3.0, 7.0),
	])
	range_mat.add_child(highlight)


func _configure_draw_layers() -> void:
	parallax_sky.z_as_relative = false
	parallax_sky.z_index = Z_PARALLAX_SKY
	parallax_hills.z_as_relative = false
	parallax_hills.z_index = Z_PARALLAX_HILLS
	parallax_fairway.z_as_relative = false
	parallax_fairway.z_index = Z_PARALLAX_FAIRWAY

	range_mat.z_as_relative = false
	range_mat.z_index = Z_MAT

	foreground.z_as_relative = false
	foreground.z_index = Z_LITTER
	littered_balls.z_as_relative = false
	littered_balls.z_index = Z_LITTER
	golfer.z_as_relative = false
	golfer.z_index = Z_GOLFER
	ball.z_as_relative = false
	ball.z_index = Z_BALL


func _mat_trapezoid(
	x_left_bottom: float,
	x_right_bottom: float,
	y_bottom: float,
	y_top: float
) -> PackedVector2Array:
	var x_left_top := PerspectiveGround.centerline_x_at_y(
		y_top, FAIRWAY_VANISHING_POINT, x_left_bottom, y_bottom
	)
	var x_right_top := PerspectiveGround.centerline_x_at_y(
		y_top, FAIRWAY_VANISHING_POINT, x_right_bottom, y_bottom
	)
	return PackedVector2Array([
		Vector2(x_left_bottom, y_bottom),
		Vector2(x_right_bottom, y_bottom),
		Vector2(x_right_top, y_top),
		Vector2(x_left_top, y_top),
	])


func _process(delta: float) -> void:
	_swing.update(delta)
	_update_ball_reload()
	_update_charge_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
		golfer.stop()
		golfer.animation = &"swing"
		golfer.frame = 0
		if _ball_at_tee:
			ball.play(&"idle")
	elif not _golfer_joy_active:
		golfer.frame = SWING_FRAME_COUNT - 1


func _on_swing_charge_updated(_power: float, _in_band: bool, _past_peak: bool) -> void:
	if not _swing.is_charging():
		return
	var elapsed := _swing.charge_elapsed_sec()
	var progress := _swing.charge.charge_progress(elapsed)
	var frame := clampi(
		int(floor(progress * float(SWING_FRAME_COUNT - 1))),
		0,
		SWING_FRAME_COUNT - 1
	)
	if golfer.animation != &"swing":
		golfer.animation = &"swing"
	golfer.frame = frame


func _on_golfer_animation_finished() -> void:
	if golfer.animation == &"joy":
		_golfer_joy_active = false
		if not _swing.is_charging():
			golfer.play(&"idle")


func _set_idle_ring() -> void:
	if _result_flash_active:
		return
	if charge_meter:
		charge_meter.visible = false
	if sweet_spot_glow:
		sweet_spot_glow.visible = false
	if sweet_spot_label:
		sweet_spot_label.visible = false
	if not beat_ring:
		return
	beat_ring.scale = Vector2.ONE * _ring_base_scale
	if ring_inner:
		ring_inner.scale = Vector2.ONE * Balance.RING_INNER_SCALE
		ring_inner.modulate = Color(0.92, 0.85, 0.55, 0.18)
	if ring_outer:
		ring_outer.scale = Vector2.ONE * 1.35
		ring_outer.modulate = Color(1.0, 1.0, 1.0, 0.1)


func _update_sweet_spot_indicator(in_band: bool, elapsed: float) -> void:
	if sweet_spot_glow:
		sweet_spot_glow.visible = in_band
		if in_band:
			var pulse := 0.55 + 0.45 * sin(elapsed * 18.0)
			sweet_spot_glow.modulate = Color(1.0, 0.92, 0.35, pulse)
			sweet_spot_glow.scale = Vector2.ONE * (1.0 + 0.08 * sin(elapsed * 18.0))
	if sweet_spot_label:
		sweet_spot_label.visible = in_band
		if in_band:
			var text_pulse := 0.85 + 0.15 * sin(elapsed * 18.0)
			sweet_spot_label.modulate = Color(0.45, 1.0, 0.55, text_pulse)


func _update_power_bar(power: float, in_band: bool, past_peak: bool) -> void:
	if not power_bar_fill:
		return
	var fill_h := power * POWER_BAR_HEIGHT
	if fill_h < 0.5:
		power_bar_fill.visible = false
		return
	power_bar_fill.visible = true
	var bottom := POWER_BAR_HEIGHT * 0.5
	power_bar_fill.polygon = PackedVector2Array([
		Vector2(-POWER_BAR_HALF_WIDTH, bottom),
		Vector2(POWER_BAR_HALF_WIDTH, bottom),
		Vector2(POWER_BAR_HALF_WIDTH, bottom - fill_h),
		Vector2(-POWER_BAR_HALF_WIDTH, bottom - fill_h),
	])
	if in_band:
		power_bar_fill.color = Color(0.4, 0.95, 0.5, 0.95)
	elif past_peak:
		power_bar_fill.color = Color(0.95, 0.4, 0.35, 0.9)
	else:
		power_bar_fill.color = Color(0.95, 0.85, 0.4, lerpf(0.5, 0.95, power))


func _update_charge_visuals() -> void:
	if not _swing.is_charging():
		if not _result_flash_active and not _ball_in_flight and _ball_at_tee:
			ball.position = _ball_home
			ball.scale = _base_ball_scale
			if ball.animation != &"roll":
				ball.play(&"idle")
			golfer.position = _golfer_home
			if not _golfer_joy_active and golfer.animation != &"joy":
				golfer.play(&"idle")
			_set_idle_ring()
		return

	if charge_meter:
		charge_meter.visible = true

	var elapsed := _swing.charge_elapsed_sec()
	var charge := _swing.charge
	var power := charge.power_at(elapsed)
	var in_band := charge.is_in_release_band(elapsed, GameState.stats)
	var overshoot := charge.overshoot_fraction(elapsed)
	var past_peak := overshoot > 0.0
	var outer_scale := charge.outer_ring_scale(elapsed)
	var converge := 1.0 - clampf(
		(outer_scale - Balance.RING_OUTER_ALIGN_SCALE)
		/ (Balance.RING_OUTER_START_SCALE - Balance.RING_OUTER_ALIGN_SCALE),
		0.0,
		1.0
	)

	beat_ring.scale = Vector2.ONE * _ring_base_scale
	if ring_inner:
		ring_inner.scale = Vector2.ONE * charge.inner_ring_scale()
		if in_band:
			var pulse := 0.7 + 0.3 * sin(elapsed * 18.0)
			ring_inner.modulate = Color(0.35, 1.0, 0.48, pulse)
		else:
			ring_inner.modulate = Color(
				1.0,
				lerpf(0.82, 0.96, power),
				lerpf(0.42, 0.58, power),
				lerpf(0.45, 1.0, power)
			)
	if ring_outer:
		ring_outer.scale = Vector2.ONE * outer_scale
		if in_band:
			var gold_pulse := 0.75 + 0.25 * sin(elapsed * 18.0)
			ring_outer.modulate = Color(1.0, 0.88, 0.25, gold_pulse)
		elif past_peak:
			var red := clampf(overshoot * 1.8, 0.0, 1.0)
			var pulse := 0.82 + 0.18 * sin(elapsed * 14.0)
			ring_outer.modulate = Color(
				1.0,
				lerpf(0.95, 0.28, red),
				lerpf(0.95, 0.25, red),
				lerpf(0.75, 0.95, red) * pulse
			)
		else:
			ring_outer.modulate = Color(1.0, 1.0, 1.0, lerpf(0.3, 0.9, converge))

	_update_sweet_spot_indicator(in_band, elapsed)
	_update_power_bar(power, in_band, past_peak)

	if not _ball_at_tee:
		return

	var compress := power * 0.18
	ball.scale = _base_ball_scale * Vector2(1.0 + compress * 0.5, 1.0 - compress)
	ball.position = _ball_home + Vector2(0.0, compress * 6.0)

	golfer.position = _golfer_home + Vector2(lerpf(0.0, -4.0, power), lerpf(0.0, 2.0, power))


func _flash_beat_ring(tier: int) -> void:
	if not beat_ring:
		return
	_result_flash_active = true
	if charge_meter:
		charge_meter.visible = true
	if sweet_spot_glow:
		sweet_spot_glow.visible = false
	if sweet_spot_label:
		sweet_spot_label.visible = false
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	var flash_color: Color = Balance.TIER_COLORS[tier]
	beat_ring.scale = Vector2.ONE * _ring_base_scale
	if ring_inner:
		ring_inner.scale = Vector2.ONE * Balance.RING_INNER_SCALE
		ring_inner.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 1.0)
	if ring_outer:
		ring_outer.scale = Vector2.ONE * Balance.RING_OUTER_ALIGN_SCALE
		ring_outer.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 0.65)
	_flash_tween = create_tween()
	_flash_tween.tween_property(ring_inner, "modulate:a", 0.18, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.parallel().tween_property(ring_outer, "scale", Vector2.ONE * 1.35, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.chain().tween_callback(func():
		_result_flash_active = false
		_set_idle_ring()
	)


func _on_swing_resolved(
	yards: float,
	tier: int,
	payout: float,
	feedback_tier: int
) -> void:
	_flash_beat_ring(tier)
	_spawn_float_text(tier, yards, payout)
	_show_tier_sprite(tier, feedback_tier)
	if feedback_tier == Balance.FeedbackTier.JACKPOT:
		_play_golfer_joy()
	_fly_ball(yards, feedback_tier, tier)


func _play_golfer_joy() -> void:
	_golfer_joy_active = true
	golfer.play(&"joy")


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


func _spawn_float_text(tier: int, yards: float, payout: float) -> void:
	var tier_name := Balance.TIER_NAMES[tier]
	var label := Label.new()
	label.text = "%s\n%d yds\n+$%d" % [tier_name, int(yards), int(payout)]
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


func _update_ball_reload() -> void:
	if _ball_at_tee or _ball_in_flight:
		return
	if _swing.can_swing(GameState.stats):
		_respawn_ball_at_tee()


func _respawn_ball_at_tee() -> void:
	ball.visible = true
	ball.position = _ball_home
	ball.scale = _base_ball_scale
	ball.play(&"idle")
	_ball_at_tee = true


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
	config.flight_time_range_sec = FLIGHT_TIME_RANGE_SEC
	config.base_ball_scale = _base_ball_scale
	return config


func _leave_litter_ball(land_position: Vector2, land_scale: Vector2) -> void:
	var litter := Sprite2D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = land_scale
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
		yards, timing_tier, GameState.stats, _flight_config
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
		_ball_at_tee = false
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
