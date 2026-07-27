class_name IsoBallTrail
extends Node2D
## Iso-pixel Line2D tracer behind an in-flight ball. Same look as BallFlightTrail
## but projects world yards through IsoGrid instead of Camera3D.unproject.

const FADE_OUT_SEC := 0.2

var _camera: Camera2D
var _line: Line2D
var _tier_color: Color
var _width_mult: float = 1.0
var _world_points: PackedVector3Array = PackedVector3Array()
var _tracking := true


static func begin(
	parent: Node2D,
	camera: Camera2D,
	timing_tier: int = Balance.TimingTier.GOOD,
	color_override: Color = Color.TRANSPARENT
) -> Node2D:
	var trail := IsoBallTrail.new()
	trail._camera = camera
	if color_override.a > 0.0:
		trail._tier_color = color_override
		trail._width_mult = Balance.GOLDEN_TRAIL_WIDTH_MULT
	else:
		trail._tier_color = Balance.TIER_COLORS[timing_tier]
		trail._width_mult = 1.0
	parent.add_child(trail)
	trail.z_index = 1
	trail.z_as_relative = false
	trail._setup_line()
	trail.set_process(true)
	return trail


func _setup_line() -> void:
	_line = Line2D.new()
	_line.width = Balance.FLIGHT_TRAIL_WIDTH
	_line.default_color = _tier_color
	_line.antialiased = false
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var gradient := Gradient.new()
	gradient.set_color(0, Color(_tier_color.r, _tier_color.g, _tier_color.b, 0.0))
	gradient.set_color(
		1,
		Color(_tier_color.r, _tier_color.g, _tier_color.b, Balance.FLIGHT_TRAIL_HEAD_ALPHA)
	)
	_line.gradient = gradient
	add_child(_line)


func _process(_delta: float) -> void:
	if _world_points.is_empty():
		return
	_refresh_line()


func track(world_pos: Vector3) -> void:
	if not _tracking:
		return
	var local := IsoGrid.iso_px_from_yards(world_pos)
	if _world_points.is_empty():
		_world_points.append(world_pos)
		_refresh_line()
		return
	var last_local := IsoGrid.iso_px_from_yards(_world_points[_world_points.size() - 1])
	if last_local.distance_to(local) < Balance.FLIGHT_TRAIL_MIN_SAMPLE_PX:
		return
	_world_points.append(world_pos)
	while _world_points.size() > Balance.FLIGHT_TRAIL_MAX_POINTS:
		_world_points.remove_at(0)
	_refresh_line()


func finish() -> void:
	if not _tracking:
		return
	_tracking = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	tween.tween_callback(queue_free)


func point_count() -> int:
	return _world_points.size()


func trail_color() -> Color:
	return _tier_color


func _refresh_line() -> void:
	if _line == null:
		return
	var zoom := 1.0
	if _camera != null:
		zoom = maxf(_camera.zoom.x, 0.001)
	_line.width = Balance.FLIGHT_TRAIL_WIDTH * zoom * _width_mult
	var n := _world_points.size()
	var locals := PackedVector2Array()
	locals.resize(n)
	for i in n:
		locals[i] = IsoGrid.iso_px_from_yards(_world_points[i])
	_line.points = locals
