extends RefCounted
## Slot-machine style count-up for the HUD bank total.
## Tracks a display value separately from GameState.currency; positive
## increases ease toward the target, spends/loads snap immediately.

const BASE_DURATION_SEC := 0.4
const MAX_DURATION_SEC := 0.7
const MIN_DURATION_SEC := 0.25
const SCALE_PULSE := 1.04

var _host: Control
var _label: Label
var _format: Callable
var _display: float = 0.0
var _target: float = 0.0
var _tween: Tween
var _spinning: bool = false


func setup(host: Control, label: Label, format_cb: Callable, initial: float) -> void:
	_host = host
	_label = label
	_format = format_cb
	_display = initial
	_target = initial
	_write_label()
	_reset_juice()


func get_display() -> float:
	return _display


func is_spinning() -> bool:
	return _spinning


func set_target(amount: float) -> void:
	_target = amount
	if amount < _display - 0.0001:
		_snap(amount)
		return
	if is_equal_approx(amount, _display):
		_snap(amount)
		return
	_start_or_retarget()


func snap(amount: float) -> void:
	_snap(amount)


func _snap(amount: float) -> void:
	_kill_tween()
	_display = amount
	_target = amount
	_spinning = false
	_reset_juice()
	_write_label()


func _start_or_retarget() -> void:
	var delta := absf(_target - _display)
	var duration := clampf(
		BASE_DURATION_SEC + minf(delta / 50.0, 0.25),
		MIN_DURATION_SEC,
		MAX_DURATION_SEC
	)
	_kill_tween()
	_spinning = true
	_tween = _host.create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_on_tween_step, _display, _target, duration)
	_tween.tween_callback(_on_tween_finished)


func _on_tween_step(value: float) -> void:
	_display = value
	_write_label()
	if _spinning and _label != null:
		_label.pivot_offset = _label.size * 0.5
		var pulse := lerpf(1.0, SCALE_PULSE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.04))
		_label.scale = Vector2(pulse, pulse)


func _on_tween_finished() -> void:
	_display = _target
	_spinning = false
	_reset_juice()
	_write_label()


func _write_label() -> void:
	if _label == null:
		return
	_label.text = "$%s" % str(_format.call(_display))


func _reset_juice() -> void:
	if _label == null:
		return
	_label.scale = Vector2.ONE
	_label.pivot_offset = _label.size * 0.5


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
