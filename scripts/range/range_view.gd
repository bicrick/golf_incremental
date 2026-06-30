extends Node2D
## Driving range view: parallax 2.5D layers, charge ring, ball flight, Dinky sprites.

const CHARGE_METER_POSITION := Vector2(300, 182)
const POWER_BAR_HEIGHT := 56.0
const POWER_BAR_HALF_WIDTH := 3.0
const BALL_PIXEL_SCALE := Vector2(1, 1)
const GOLFER_PIXEL_SCALE := Vector2(3, 3)
const FLIGHT_ARC_MIN_PX := 24.0
const FLIGHT_ARC_MAX_PX := 72.0
const FLIGHT_APEX_SCALE_BOOST := 0.08
const FLIGHT_TIME_MIN_SEC := 0.65
const FLIGHT_TIME_RANGE_SEC := 0.95
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
# Absolute canvas z_index (z_as_relative = false) — background < fairway < mat < litter < golfer < ball
const Z_PARALLAX_SKY := -30
const Z_PARALLAX_HILLS := -20
const Z_PARALLAX_FAIRWAY := -10
const Z_MAT := 0
const Z_LITTER := 1
const Z_GOLFER := 2
const Z_BALL := 3
const SWING_FRAME_COUNT := 5
const TEXT_BASE := "res://assets/imported/dinky_tiny_golf/Dinky_Tiny_Golf_Free/Singles/TEXT"

# Swing wind-up maps charge_progress (0→1) to Swing01–05 frames over charge_duration_sec().
# Normal charge: Balance.CHARGE_DURATION_SEC (0.5s). Chain charge: × CHAIN_CHARGE_DURATION_SCALE (0.2s).
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

@export var horizon_position: Vector2 = Vector2(240, 40)
@export var tee_position: Vector2 = Vector2(240, 200)

var _swing := Swing.new()
var _ball_home: Vector2
var _golfer_home: Vector2
var _base_ball_scale: Vector2 = BALL_PIXEL_SCALE
var _base_golfer_scale: Vector2 = GOLFER_PIXEL_SCALE
var _ring_base_scale: float = 1.0
var _flash_tween: Tween
var _result_flash_active: bool = false
var _chain_active: bool = false
var _chain_visual_level: int = 0
var _golfer_joy_active: bool = false
var _ball_in_flight: bool = false
var _ball_at_tee: bool = true
var _ball_lay_texture: Texture2D
var _flight_end_scale_factor: float = 1.0


func _ready() -> void:
	_setup_fairway_stripes()
	_setup_range_mat()
	_configure_draw_layers()
	_setup_dinky_sprites()
	_ball_home = ball.position
	_golfer_home = golfer.position
	PixelFont.apply_label(sweet_spot_label, 8)
	if charge_meter:
		charge_meter.position = CHARGE_METER_POSITION
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_charging_changed.connect(_on_swing_charging_changed)
	EventBus.swing_charge_updated.connect(_on_swing_charge_updated)
	EventBus.swing_chain_window_started.connect(_on_chain_window_started)
	EventBus.swing_chain_charging_started.connect(_on_chain_charging_started)
	EventBus.swing_chain_state_changed.connect(_on_chain_state_changed)
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
	var container: Node2D = $ParallaxFairway/FairwayStripes
	for child in container.get_children():
		child.free()

	# Full viewport-width safety fill so perspective wedge tops never expose side voids.
	var viewport_base := Polygon2D.new()
	viewport_base.color = FAIRWAY_BASE_COLOR
	viewport_base.polygon = PackedVector2Array([
		Vector2(-FAIRWAY_VIEWPORT_PAD, FAIRWAY_BOTTOM_Y),
		Vector2(480.0 + FAIRWAY_VIEWPORT_PAD, FAIRWAY_BOTTOM_Y),
		Vector2(480.0 + FAIRWAY_VIEWPORT_PAD, FAIRWAY_TOP_Y),
		Vector2(-FAIRWAY_VIEWPORT_PAD, FAIRWAY_TOP_Y),
	])
	container.add_child(viewport_base)

	var colors: Array[Color] = [FAIRWAY_STRIPE_LIGHT, FAIRWAY_STRIPE_DARK]
	var span := FAIRWAY_BOTTOM_RIGHT - FAIRWAY_BOTTOM_LEFT
	var segment_width := span / float(FAIRWAY_STRIPE_COUNT)
	for index in FAIRWAY_STRIPE_COUNT:
		var x0_bottom := FAIRWAY_BOTTOM_LEFT + index * segment_width
		var x1_bottom := FAIRWAY_BOTTOM_LEFT + (index + 1) * segment_width
		var x0_top := _perspective_x_at_y(
			FAIRWAY_VANISHING_POINT, x0_bottom, FAIRWAY_BOTTOM_Y, FAIRWAY_TOP_Y
		)
		var x1_top := _perspective_x_at_y(
			FAIRWAY_VANISHING_POINT, x1_bottom, FAIRWAY_BOTTOM_Y, FAIRWAY_TOP_Y
		)
		var stripe := Polygon2D.new()
		stripe.color = colors[index % 2]
		stripe.polygon = PackedVector2Array([
			Vector2(x0_bottom, FAIRWAY_BOTTOM_Y),
			Vector2(x1_bottom, FAIRWAY_BOTTOM_Y),
			Vector2(x1_top, FAIRWAY_TOP_Y),
			Vector2(x0_top, FAIRWAY_TOP_Y),
		])
		container.add_child(stripe)


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

	var grid_color := Color(0.22, 0.48, 0.22)
	var mid_y := lerpf(MAT_Y_FRONT, MAT_Y_BACK, 0.55)
	var mid_left := _perspective_x_at_y(
		FAIRWAY_VANISHING_POINT, MAT_X_LEFT, MAT_Y_FRONT, mid_y
	)
	var mid_right := _perspective_x_at_y(
		FAIRWAY_VANISHING_POINT, MAT_X_RIGHT, MAT_Y_FRONT, mid_y
	)
	var h_line := Polygon2D.new()
	h_line.color = grid_color
	h_line.polygon = PackedVector2Array([
		Vector2(mid_left + 5.0, mid_y - 0.5),
		Vector2(mid_right - 5.0, mid_y - 0.5),
		Vector2(mid_right - 5.0, mid_y + 0.5),
		Vector2(mid_left + 5.0, mid_y + 0.5),
	])
	range_mat.add_child(h_line)

	var center_bottom := (MAT_X_LEFT + MAT_X_RIGHT) * 0.5
	var center_top := _perspective_x_at_y(
		FAIRWAY_VANISHING_POINT, center_bottom, MAT_Y_FRONT, MAT_Y_BACK
	)
	var v_line := Polygon2D.new()
	v_line.color = grid_color
	v_line.polygon = PackedVector2Array([
		Vector2(center_bottom - 0.5, MAT_Y_FRONT - 5.0),
		Vector2(center_bottom + 0.5, MAT_Y_FRONT - 5.0),
		Vector2(center_top + 0.5, MAT_Y_BACK + 5.0),
		Vector2(center_top - 0.5, MAT_Y_BACK + 5.0),
	])
	range_mat.add_child(v_line)


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
	var x_left_top := _perspective_x_at_y(
		FAIRWAY_VANISHING_POINT, x_left_bottom, y_bottom, y_top
	)
	var x_right_top := _perspective_x_at_y(
		FAIRWAY_VANISHING_POINT, x_right_bottom, y_bottom, y_top
	)
	return PackedVector2Array([
		Vector2(x_left_bottom, y_bottom),
		Vector2(x_right_bottom, y_bottom),
		Vector2(x_right_top, y_top),
		Vector2(x_left_top, y_top),
	])


static func _perspective_x_at_y(
	vanishing_point: Vector2,
	x_at_far_y: float,
	y_far: float,
	y_near: float
) -> float:
	var denom := y_far - vanishing_point.y
	if absf(denom) < 0.001:
		return vanishing_point.x
	var t := (y_near - vanishing_point.y) / denom
	return vanishing_point.x + t * (x_at_far_y - vanishing_point.x)


static func _rect_polygon(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])


func _process(delta: float) -> void:
	_swing.update(delta)
	_update_ball_reload()
	_update_charge_visuals()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_swing.start_charge()
		else:
			_swing.release_strike()
	elif event is InputEventKey:
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


func _update_power_bar(power: float, in_band: bool, past_peak: bool, is_chain: bool = false) -> void:
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
		if is_chain:
			power_bar_fill.color = Color(
				Balance.CHAIN_RING_COLOR.r,
				Balance.CHAIN_RING_COLOR.g,
				Balance.CHAIN_RING_COLOR.b * 0.45,
				0.95
			)
		else:
			power_bar_fill.color = Color(0.4, 0.95, 0.5, 0.95)
	elif past_peak:
		power_bar_fill.color = Color(0.95, 0.4, 0.35, 0.9)
	else:
		power_bar_fill.color = Color(0.95, 0.85, 0.4, lerpf(0.5, 0.95, power))


func _update_charge_visuals() -> void:
	if _swing.is_chain_window():
		_update_chain_window_visuals()
		return

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
	var is_chain := _swing.is_chain_charging()
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
			var pulse := 0.7 + 0.3 * sin(elapsed * (22.0 if is_chain else 18.0))
			if is_chain:
				ring_inner.modulate = Color(
					Balance.CHAIN_RING_COLOR.r,
					Balance.CHAIN_RING_COLOR.g,
					Balance.CHAIN_RING_COLOR.b,
					pulse
				)
			else:
				ring_inner.modulate = Color(0.35, 1.0, 0.48, pulse)
		elif is_chain:
			ring_inner.modulate = Color(
				Balance.CHAIN_RING_COLOR.r,
				Balance.CHAIN_RING_COLOR.g * lerpf(0.75, 1.0, power),
				Balance.CHAIN_RING_COLOR.b * 0.35,
				lerpf(0.55, 1.0, power)
			)
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
			if is_chain:
				var chain_pulse := 0.8 + 0.2 * sin(elapsed * 22.0)
				ring_outer.modulate = Color(
					Balance.CHAIN_RING_COLOR.r,
					Balance.CHAIN_RING_COLOR.g,
					Balance.CHAIN_RING_COLOR.b * 0.45,
					chain_pulse
				)
			else:
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
		elif is_chain:
			ring_outer.modulate = Color(
				Balance.CHAIN_RING_COLOR.r,
				Balance.CHAIN_RING_COLOR.g,
				Balance.CHAIN_RING_COLOR.b * 0.35,
				lerpf(0.45, 0.95, converge)
			)
		else:
			ring_outer.modulate = Color(1.0, 1.0, 1.0, lerpf(0.3, 0.9, converge))

	if is_chain and sweet_spot_label:
		sweet_spot_label.visible = true
		sweet_spot_label.text = Balance.CHAIN_LABEL_CHARGE
		var chain_text_pulse := 0.85 + 0.15 * sin(elapsed * 22.0)
		sweet_spot_label.modulate = Color(
			Balance.CHAIN_RING_COLOR.r,
			Balance.CHAIN_RING_COLOR.g,
			Balance.CHAIN_RING_COLOR.b * 0.5,
			chain_text_pulse
		)
	else:
		_update_sweet_spot_indicator(in_band, elapsed)

	_update_power_bar(power, in_band, past_peak, is_chain)

	if not _ball_at_tee:
		return

	var compress := power * 0.18
	ball.scale = _base_ball_scale * Vector2(1.0 + compress * 0.5, 1.0 - compress)
	ball.position = _ball_home + Vector2(0.0, compress * 6.0)

	golfer.position = _golfer_home + Vector2(lerpf(0.0, -4.0, power), lerpf(0.0, 2.0, power))


func _update_chain_window_visuals() -> void:
	if charge_meter:
		charge_meter.visible = true
	if power_bar_fill:
		power_bar_fill.visible = false

	var elapsed := _swing.chain_window_elapsed_sec()
	var remaining := _swing.chain_window_remaining_sec()
	var urgency := 1.0 - clampf(remaining / Balance.CHAIN_WINDOW_SEC, 0.0, 1.0)
	var pulse := 0.55 + 0.45 * sin(elapsed * 36.0)

	beat_ring.scale = Vector2.ONE * _ring_base_scale * (1.0 + 0.06 * sin(elapsed * 36.0))
	if ring_inner:
		ring_inner.scale = Vector2.ONE * Balance.RING_INNER_SCALE
		ring_inner.modulate = Color(
			Balance.CHAIN_RING_COLOR.r,
			Balance.CHAIN_RING_COLOR.g,
			Balance.CHAIN_RING_COLOR.b * 0.45,
			lerpf(0.45, 1.0, pulse)
		)
	if ring_outer:
		ring_outer.scale = Vector2.ONE * lerpf(1.25, Balance.RING_OUTER_ALIGN_SCALE, urgency)
		ring_outer.modulate = Color(
			Balance.CHAIN_RING_COLOR.r,
			Balance.CHAIN_RING_COLOR.g,
			Balance.CHAIN_RING_COLOR.b * 0.35,
			lerpf(0.35, 0.95, pulse)
		)
	if sweet_spot_glow:
		sweet_spot_glow.visible = true
		sweet_spot_glow.modulate = Color(
			Balance.CHAIN_RING_COLOR.r,
			Balance.CHAIN_RING_COLOR.g,
			Balance.CHAIN_RING_COLOR.b * 0.5,
			pulse
		)
		sweet_spot_glow.scale = Vector2.ONE * (1.0 + 0.12 * sin(elapsed * 36.0))
	if sweet_spot_label:
		sweet_spot_label.visible = true
		sweet_spot_label.text = Balance.CHAIN_LABEL_WINDOW
		sweet_spot_label.modulate = Color(
			Balance.CHAIN_RING_COLOR.r,
			Balance.CHAIN_RING_COLOR.g,
			Balance.CHAIN_RING_COLOR.b * 0.55,
			lerpf(0.75, 1.0, pulse)
		)


func _flash_beat_ring(tier: int, chain_level: int = 1) -> void:
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
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		flash_color = Balance.CHAIN_RING_COLOR
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
	feedback_tier: int,
	_combo: int,
	chain_level: int
) -> void:
	_chain_active = false
	_chain_visual_level = 0
	_flash_beat_ring(tier, chain_level)
	_spawn_float_text(tier, yards, payout, chain_level)
	_show_tier_sprite(tier, feedback_tier, chain_level)
	if feedback_tier == Balance.FeedbackTier.JACKPOT or (
		chain_level >= 2 and tier == Balance.TimingTier.PERFECT
	):
		_play_golfer_joy()
	_fly_ball(yards, feedback_tier, tier)


func _on_chain_window_started() -> void:
	_chain_active = true
	_chain_visual_level = 1


func _on_chain_charging_started() -> void:
	_chain_active = true
	_chain_visual_level = 2


func _on_chain_state_changed(active: bool, _chain_level: int) -> void:
	if not active:
		_chain_active = false
		_chain_visual_level = 0


func _play_golfer_joy() -> void:
	_golfer_joy_active = true
	golfer.play(&"joy")


func _show_tier_sprite(tier: int, feedback_tier: int, chain_level: int) -> void:
	if not tier_sprite:
		return
	var path := ""
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		path = TEXT_BASE + "/TXT_HOLEINONE.png"
	elif feedback_tier == Balance.FeedbackTier.JACKPOT:
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


func _spawn_float_text(tier: int, yards: float, payout: float, chain_level: int = 1) -> void:
	var tier_name := Balance.TIER_NAMES[tier]
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		tier_name = "%s x%.0f" % [tier_name, Balance.CHAIN_LEVEL_2_MULT]
	var label := Label.new()
	label.text = "%s\n%d yds\n+$%d" % [tier_name, int(yards), int(payout)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelFont.apply_label(label, 8)
	var text_color: Color = Balance.TIER_COLORS[tier]
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		text_color = Balance.CHAIN_RING_COLOR
	label.modulate = text_color
	label.position = ball.global_position + Vector2(-36, -52)
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


func _leave_litter_ball(land_position: Vector2, land_scale: Vector2) -> void:
	var litter := Sprite2D.new()
	litter.texture = _ball_lay_texture
	litter.position = land_position
	litter.scale = land_scale
	littered_balls.add_child(litter)


func _ground_y_for_depth(t: float) -> float:
	# Map shot depth to fairway ground plane: near tee y → far horizon line (never above VP).
	return lerpf(_ball_home.y, FAIRWAY_TOP_Y + LANDING_Y_MARGIN, t)


func _ground_centerline_x_at_y(y: float) -> float:
	return _perspective_x_at_y(
		FAIRWAY_VANISHING_POINT,
		_ball_home.x,
		_ball_home.y,
		y
	)


func _landing_target_for_depth(t: float) -> Vector2:
	var y := _ground_y_for_depth(t)
	return Vector2(_ground_centerline_x_at_y(y), y)


func _scatter_landing_target(base_target: Vector2, depth_t: float) -> Vector2:
	var scatter_x := randf_range(-LANDING_SCATTER_X, LANDING_SCATTER_X) * lerpf(0.65, 1.0, depth_t)
	var landed := base_target + Vector2(scatter_x, 0.0)
	landed.x = clampf(landed.x, RANGE_X_MIN, RANGE_X_MAX)
	landed.y = clampf(
		landed.y,
		FAIRWAY_TOP_Y + LANDING_Y_MARGIN,
		_ball_home.y + 4.0
	)
	return landed


func _flight_arc_height(depth_t: float) -> float:
	return lerpf(FLIGHT_ARC_MIN_PX, FLIGHT_ARC_MAX_PX, depth_t)


func _flight_position_at(progress: float, start: Vector2, end: Vector2, depth_t: float) -> void:
	var ground := start.lerp(end, progress)
	var arc_h := _flight_arc_height(depth_t)
	# Parabola: 0 at takeoff/landing, peak = arc_h at progress 0.5
	var lift := 4.0 * arc_h * progress * (1.0 - progress)
	ball.position = Vector2(ground.x, ground.y - lift)

	var depth_scale := lerpf(1.0, _flight_end_scale_factor, progress)
	var apex_weight := 4.0 * progress * (1.0 - progress)
	ball.scale = _base_ball_scale * depth_scale * (1.0 + FLIGHT_APEX_SCALE_BOOST * apex_weight)


func _fly_ball(yards: float, feedback_tier: int, _timing_tier: int) -> void:
	# Depth from continuous yards — max_yards is a payout cap, not visual scale.
	var visual_max := maxf(
		GameState.stats.base_yards * GameState.stats.yard_multiplier,
		1.0
	)
	var t := clampf(yards / visual_max, 0.08, 1.0)
	var target := _scatter_landing_target(_landing_target_for_depth(t), t)
	var flight_time := FLIGHT_TIME_MIN_SEC + t * FLIGHT_TIME_RANGE_SEC
	var end_scale_factor := lerpf(0.4, 0.12, t)
	var start_pos := _ball_home
	_flight_end_scale_factor = end_scale_factor

	_ball_in_flight = true
	_ball_at_tee = false
	ball.visible = true
	ball.position = start_pos
	ball.scale = _base_ball_scale
	ball.play(&"roll")
	ball.sprite_frames.set_animation_speed(
		&"roll",
		float(DinkySpriteFrames.BALL_ROLL_FRAME_COUNT) / flight_time
	)

	var tween := create_tween()
	tween.tween_method(
		_flight_position_at.bind(start_pos, target, t),
		0.0,
		1.0,
		flight_time
	).set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(func():
		_ball_in_flight = false
		_leave_litter_ball(ball.position, ball.scale)
		ball.visible = false
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
