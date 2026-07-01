class_name BallFlightTrail
extends Node2D
## Subtle screen-space tail behind the ball during flight — short fading Line2D.

const TRAIL_COLOR := Color(0.95, 0.92, 0.82, 1.0)
const FADE_OUT_SEC := 0.2

var _camera: Camera3D
var _line: Line2D
var _points: PackedVector2Array = PackedVector2Array()
var _tracking := true


static func begin(parent: Node2D, camera: Camera3D) -> Node2D:
	var trail := BallFlightTrail.new()
	trail._camera = camera
	parent.add_child(trail)
	trail.z_index = 1
	trail.z_as_relative = false
	trail._setup_line()
	return trail


func _setup_line() -> void:
	_line = Line2D.new()
	_line.width = Balance.FLIGHT_TRAIL_WIDTH
	_line.default_color = TRAIL_COLOR
	_line.antialiased = false
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var gradient := Gradient.new()
	gradient.set_color(0, Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, 0.0))
	gradient.set_color(1, Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, Balance.FLIGHT_TRAIL_HEAD_ALPHA))
	_line.gradient = gradient
	add_child(_line)


func track(world_pos: Vector3) -> void:
	if not _tracking or _camera == null:
		return
	var screen := _camera.unproject_position(world_pos)
	var local := screen
	if get_parent() is Node2D:
		local = get_parent().to_local(screen)
	if _points.is_empty():
		_points.append(local)
		_refresh_line()
		return
	var last := _points[_points.size() - 1]
	if last.distance_to(local) < Balance.FLIGHT_TRAIL_MIN_SAMPLE_PX:
		return
	_points.append(local)
	while _points.size() > Balance.FLIGHT_TRAIL_MAX_POINTS:
		_points.remove_at(0)
	_refresh_line()


func finish() -> void:
	if not _tracking:
		return
	_tracking = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	tween.tween_callback(queue_free)


func point_count() -> int:
	return _points.size()


func tail_alpha() -> float:
	if _line == null or _line.gradient == null:
		return 0.0
	return _line.gradient.get_color(0).a


func head_alpha() -> float:
	if _line == null or _line.gradient == null:
		return 0.0
	return _line.gradient.get_color(1).a


func _refresh_line() -> void:
	if _line:
		_line.points = _points
