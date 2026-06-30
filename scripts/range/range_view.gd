extends Node2D
## Driving range view: parallax 2.5D layers, beat ring, ball flight.

@onready var ball: Node2D = $Foreground/Ball
@onready var beat_ring: Node2D = $BeatRing
@onready var camera: Camera2D = $Camera2D

@export var horizon_position: Vector2 = Vector2(240, 40)
@export var tee_position: Vector2 = Vector2(240, 200)

var _swing := Swing.new()
var _ball_home: Vector2
var _ring_base_scale: float = 1.0


func _ready() -> void:
	_ball_home = ball.position
	EventBus.swing_resolved.connect(_on_swing_resolved)
	if camera:
		camera.make_current()


func _process(delta: float) -> void:
	_swing.update(delta)
	_pulse_beat_ring()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_swing.attempt_swing()
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_SPACE:
			_swing.attempt_swing()


func _pulse_beat_ring() -> void:
	if not beat_ring:
		return
	var phase := _swing.rhythm.beat_phase
	var pulse := 0.85 + 0.25 * (1.0 - absf(phase - 0.0) * 2.0) if phase < 0.5 else 0.85 + 0.25 * (1.0 - absf(phase - 1.0) * 2.0)
	beat_ring.scale = Vector2.ONE * _ring_base_scale * pulse


func _on_swing_resolved(yards: float, _tier: int, _payout: float, feedback_tier: int, _combo: int) -> void:
	_fly_ball(yards, feedback_tier)


func _fly_ball(yards: float, feedback_tier: int) -> void:
	var t := clampf(yards / GameState.stats.max_yards, 0.15, 1.0)
	var target := tee_position.lerp(horizon_position, t)
	var flight_time := 0.35 + t * 0.45
	var end_scale := lerpf(0.35, 0.15, t)

	ball.position = _ball_home
	ball.scale = Vector2.ONE

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ball, "position", target, flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "scale", Vector2(end_scale, end_scale), flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
