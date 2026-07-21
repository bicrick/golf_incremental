class_name FrameTimeGraph
extends Control
## Rolling frame-time graph overlay (Settings toggle).

const HISTORY := 180
const Y_MAX_MS := 50.0
const REF_60_MS := 1000.0 / 60.0
const REF_30_MS := 1000.0 / 30.0

var _samples: PackedFloat32Array = PackedFloat32Array()
var _write := 0
var _count := 0
var _latest_ms := 0.0
var _window_max_ms := 0.0
var _sum_ms := 0.0

@onready var _stats: Label = $Stats


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_samples.resize(HISTORY)
	_samples.fill(0.0)
	custom_minimum_size = Vector2(200, 72)
	if _stats:
		PixelFont.apply_label(_stats, 6)
		_stats.add_theme_color_override(&"font_color", Color(0.92, 0.9, 0.82, 1.0))
		_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	## Wall-clock frame time (includes whatever made this frame late).
	var ms := delta * 1000.0
	_push(ms)
	queue_redraw()
	var fps := Engine.get_frames_per_second()
	if _stats:
		var avg := _sum_ms / float(maxi(_count, 1))
		_stats.text = "fps %d  frame %0.1fms  avg %0.1f  peak %0.1f" % [
			fps, _latest_ms, avg, _window_max_ms
		]


func clear_peak() -> void:
	_window_max_ms = _latest_ms


func _push(ms: float) -> void:
	if _count == HISTORY:
		_sum_ms -= _samples[_write]
	else:
		_count += 1
	_samples[_write] = ms
	_write = (_write + 1) % HISTORY
	_latest_ms = ms
	_sum_ms += ms
	## Peak within the visible history window only (not lifetime).
	var peak := 0.0
	for i in _count:
		var idx := (_write - _count + i + HISTORY) % HISTORY
		peak = maxf(peak, _samples[idx])
	_window_max_ms = peak


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.05, 0.07, 0.06, 0.82))
	draw_rect(rect, Color(0.55, 0.5, 0.35, 0.9), false, 1.0)

	var plot := Rect2(4.0, 14.0, size.x - 8.0, size.y - 18.0)
	_draw_ref_line(plot, REF_60_MS, Color(0.35, 0.75, 0.4, 0.55))
	_draw_ref_line(plot, REF_30_MS, Color(0.85, 0.55, 0.25, 0.55))

	if _count < 2:
		return
	var points := PackedVector2Array()
	points.resize(_count)
	for i in _count:
		var idx := (_write - _count + i + HISTORY) % HISTORY
		var t := float(i) / float(HISTORY - 1)
		var x := plot.position.x + t * plot.size.x
		var y_norm := clampf(_samples[idx] / Y_MAX_MS, 0.0, 1.0)
		var y := plot.position.y + plot.size.y - y_norm * plot.size.y
		points[i] = Vector2(x, y)
	draw_polyline(points, Color(0.95, 0.88, 0.45, 1.0), 1.5, true)


func _draw_ref_line(plot: Rect2, ms: float, color: Color) -> void:
	var y_norm := clampf(ms / Y_MAX_MS, 0.0, 1.0)
	var y := plot.position.y + plot.size.y - y_norm * plot.size.y
	draw_line(
		Vector2(plot.position.x, y),
		Vector2(plot.position.x + plot.size.x, y),
		color,
		1.0
	)
