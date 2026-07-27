class_name IsoPickerIndicator
extends Node2D
## Canvas-space harvest picker for IsoView.
## Matches the old 3D RangePickerIndicator: angular dashes on a ground-projected
## ellipse, stroked at a constant 1 canvas pixel so camera zoom does not inflate
## the line.

const SEGMENTS := 48
const DASH_ON := 2
const DASH_OFF := 2
const LINE_WIDTH := 1.0
const RING_COLOR := Color(0.95, 0.98, 1.0, 0.78)

var _visible_getter: Callable
var _center_getter: Callable
var _radius_yards_getter: Callable
var _camera: Camera2D
var _center := Vector2.ZERO
var _radius_yards := 0.0
var _last_radius := -1.0
var _last_zoom := -1.0
var _radii_screen := Vector2.ZERO


func setup(
	visible_getter: Callable,
	center_getter: Callable,
	radius_yards_getter: Callable,
	camera: Camera2D
) -> void:
	_visible_getter = visible_getter
	_center_getter = center_getter
	_radius_yards_getter = radius_yards_getter
	_camera = camera
	visible = false
	texture_filter = TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if _visible_getter == null or not _visible_getter.is_valid() or not _visible_getter.call():
		visible = false
		return
	_center = _center_getter.call() if _center_getter.is_valid() else Vector2.ZERO
	_radius_yards = _radius_yards_getter.call() if _radius_yards_getter.is_valid() else 0.0
	if _radius_yards < 0.01 or _camera == null:
		visible = false
		return
	visible = true
	position = _center
	var zoom_x: float = maxf(_camera.zoom.x, 0.001)
	if absf(_radius_yards - _last_radius) > 0.001 or absf(zoom_x - _last_zoom) > 0.001:
		_last_radius = _radius_yards
		_last_zoom = zoom_x
		_radii_screen = IsoGrid.iso_px_radii_from_yards(_radius_yards) * zoom_x
	queue_redraw()


func _draw() -> void:
	if _radii_screen.x < 0.5 or _radii_screen.y < 0.5:
		return
	var cycle := DASH_ON + DASH_OFF
	for i in SEGMENTS:
		if i % cycle >= DASH_ON:
			continue
		var a0 := TAU * float(i) / float(SEGMENTS)
		var a1 := TAU * float(i + 1) / float(SEGMENTS)
		var p0 := Vector2(cos(a0) * _radii_screen.x, sin(a0) * _radii_screen.y)
		var p1 := Vector2(cos(a1) * _radii_screen.x, sin(a1) * _radii_screen.y)
		draw_line(p0, p1, RING_COLOR, LINE_WIDTH, false)
