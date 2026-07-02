extends Control
## 8-bit horizontal slider — chunky track and square thumb via _draw().

signal value_changed(value: float)

const TRACK_HEIGHT := 8
const THUMB_WIDTH := 10
const THUMB_HEIGHT := 14
const BORDER := 2

const COLOR_TRACK_BORDER := Color("#2A4420")
const COLOR_TRACK_BG := Color("#3A3428")
const COLOR_TRACK_FILL := Color("#3DDC84")
const COLOR_TRACK_FILL_HI := Color("#5AF098")
const COLOR_THUMB_FACE := Color("#D8EECF")
const COLOR_THUMB_BORDER := Color("#1B3D18")
const COLOR_THUMB_HI := Color("#EAF6E4")

@export_range(0.0, 1.0, 0.01) var min_value: float = 0.0
@export_range(0.0, 1.0, 0.01) var max_value: float = 1.0
@export_range(0.0, 1.0, 0.01) var step: float = 0.05

var value: float = 1.0:
	set(v):
		var clamped := clampf(snappedf(v, step), min_value, max_value)
		if is_equal_approx(value, clamped):
			return
		value = clamped
		queue_redraw()
		value_changed.emit(value)

var _dragging := false


func _ready() -> void:
	custom_minimum_size = Vector2(120, THUMB_HEIGHT + 4)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CursorManager.SELECTABLE_CURSOR_SHAPE
	focus_mode = Control.FOCUS_ALL
	queue_redraw()


func _draw() -> void:
	var track_y := (size.y - TRACK_HEIGHT) * 0.5
	var track_rect := Rect2(0.0, track_y, size.x, TRACK_HEIGHT)
	var thumb_x := _thumb_x_for_value()

	draw_rect(track_rect, COLOR_TRACK_BORDER)
	var inner := track_rect.grow(-float(BORDER))
	draw_rect(inner, COLOR_TRACK_BG)

	var fill_width := maxf(0.0, thumb_x + THUMB_WIDTH * 0.5 - inner.position.x)
	if fill_width > 0.0:
		draw_rect(Rect2(inner.position.x, inner.position.y, fill_width, inner.size.y), COLOR_TRACK_FILL)

	var thumb_rect := Rect2(
		thumb_x,
		(size.y - THUMB_HEIGHT) * 0.5,
		THUMB_WIDTH,
		THUMB_HEIGHT
	)
	draw_rect(thumb_rect.grow(1.0), COLOR_THUMB_BORDER)
	draw_rect(thumb_rect, COLOR_THUMB_FACE)
	draw_rect(Rect2(thumb_rect.position.x + 2, thumb_rect.position.y + 2, 2, 2), COLOR_THUMB_HI)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging = true
			_set_value_from_x(mb.position.x)
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_set_value_from_x((event as InputEventMouseMotion).position.x)
		accept_event()


func _set_value_from_x(local_x: float) -> void:
	var usable := maxf(size.x - THUMB_WIDTH, 1.0)
	var ratio := clampf((local_x - THUMB_WIDTH * 0.5) / usable, 0.0, 1.0)
	value = lerpf(min_value, max_value, ratio)


func _thumb_x_for_value() -> float:
	var usable := maxf(size.x - THUMB_WIDTH, 1.0)
	var t := 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)
	return t * usable
