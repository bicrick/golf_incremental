extends Node2D
## Driving range view: parallax 2.5D layers, charge ring, ball flight.

const CHARGE_METER_POSITION := Vector2(300, 182)
const POWER_BAR_HEIGHT := 56.0
const POWER_BAR_HALF_WIDTH := 3.0

@onready var ball: Node2D = $Foreground/Ball
@onready var golfer: Node2D = $Foreground/Golfer
@onready var charge_meter: Node2D = $ChargeMeter
@onready var beat_ring: Node2D = $ChargeMeter/BeatRing
@onready var ring_outer: Polygon2D = $ChargeMeter/BeatRing/RingOuter
@onready var ring_inner: Polygon2D = $ChargeMeter/BeatRing/RingInner
@onready var sweet_spot_glow: Polygon2D = $ChargeMeter/BeatRing/SweetSpotGlow
@onready var sweet_spot_label: Label = $ChargeMeter/SweetSpotLabel
@onready var camera: Camera2D = $Camera2D
var power_bar_fill: Polygon2D = null

@export var horizon_position: Vector2 = Vector2(240, 40)
@export var tee_position: Vector2 = Vector2(240, 200)

var _swing := Swing.new()
var _ball_home: Vector2
var _golfer_home: Vector2
var _ring_base_scale: float = 1.0
var _flash_tween: Tween
var _result_flash_active: bool = false
var _chain_active: bool = false
var _chain_visual_level: int = 0


func _ready() -> void:
	_ball_home = ball.position
	_golfer_home = golfer.position
	if charge_meter:
		charge_meter.position = CHARGE_METER_POSITION
	EventBus.swing_resolved.connect(_on_swing_resolved)
	EventBus.swing_chain_window_started.connect(_on_chain_window_started)
	EventBus.swing_chain_charging_started.connect(_on_chain_charging_started)
	EventBus.swing_chain_state_changed.connect(_on_chain_state_changed)
	if camera:
		camera.make_current()
	_set_idle_ring()


func _process(delta: float) -> void:
	_swing.update(delta)
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
		if not _result_flash_active:
			ball.position = _ball_home
			ball.scale = Vector2.ONE
			golfer.position = _golfer_home
			golfer.rotation = 0.0
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

	var compress := power * 0.18
	ball.scale = Vector2(1.0 + compress * 0.5, 1.0 - compress)
	ball.position = _ball_home + Vector2(0.0, compress * 6.0)

	golfer.rotation = lerpf(0.0, -0.22, power)
	golfer.position = _golfer_home + Vector2(lerpf(0.0, -6.0, power), lerpf(0.0, 4.0, power))


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


func _spawn_float_text(tier: int, yards: float, payout: float, chain_level: int = 1) -> void:
	var tier_name := Balance.TIER_NAMES[tier]
	if chain_level >= 2 and tier == Balance.TimingTier.PERFECT:
		tier_name = "%s x%.0f" % [tier_name, Balance.CHAIN_LEVEL_2_MULT]
	var label := Label.new()
	label.text = "%s\n%d yds\n+$%d" % [tier_name, int(yards), int(payout)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
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


func _fly_ball(yards: float, feedback_tier: int, timing_tier: int) -> void:
	var tier_flight: float = Balance.TIER_MULTS.get(timing_tier, 0.1)
	var t := clampf(yards / GameState.stats.max_yards, 0.08, 1.0)
	t = maxf(t, tier_flight * 0.35)
	var target := tee_position.lerp(horizon_position, t)
	var flight_time := 0.3 + t * 0.5
	var end_scale := lerpf(0.4, 0.12, t)

	ball.position = _ball_home
	ball.scale = Vector2.ONE

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ball, "position", target, flight_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "scale", Vector2(end_scale, end_scale), flight_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		ball.position = _ball_home
		ball.scale = Vector2.ONE
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
