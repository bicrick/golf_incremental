class_name BallFlightTrail
extends Node2D
## Screen-space tail behind the ball during flight — world-space samples reprojected each frame.
## Width follows perspective foreshortening (anchored to the first/tee sample) so far
## landings don't leave a uniform-pixel smudge.

const FADE_OUT_SEC := 0.2

var _camera: Camera3D
var _reference_ortho_size: float = 0.0
var _reference_px_per_yard: float = 0.0
var _line: Line2D
var _tier_color: Color
var _width_mult: float = 1.0
var _world_points: PackedVector3Array = PackedVector3Array()
var _depth_scales: PackedFloat32Array = PackedFloat32Array()
var _tracking := true


static func begin(
	parent: Node2D,
	camera: Camera3D,
	timing_tier: int = Balance.TimingTier.GOOD,
	reference_ortho_size: float = 0.0,
	color_override: Color = Color.TRANSPARENT
) -> Node2D:
	var trail := BallFlightTrail.new()
	trail._camera = camera
	trail._reference_ortho_size = reference_ortho_size if reference_ortho_size > 0.0 else camera.size
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
	gradient.set_color(1, Color(_tier_color.r, _tier_color.g, _tier_color.b, Balance.FLIGHT_TRAIL_HEAD_ALPHA))
	_line.gradient = gradient
	add_child(_line)


func _process(_delta: float) -> void:
	if _world_points.is_empty() or _camera == null:
		return
	_refresh_line()


func track(world_pos: Vector3) -> void:
	if not _tracking or _camera == null:
		return
	var local := _project_to_local(world_pos)
	if _world_points.is_empty():
		_reference_px_per_yard = _px_per_yard(world_pos)
		_world_points.append(world_pos)
		_refresh_line()
		return
	var last_local := _project_to_local(_world_points[_world_points.size() - 1])
	if last_local.distance_to(local) < Balance.FLIGHT_TRAIL_MIN_SAMPLE_PX:
		return
	_world_points.append(world_pos)
	while _world_points.size() > Balance.FLIGHT_TRAIL_MAX_POINTS:
		_world_points.remove_at(0)
	_refresh_line()


func set_camera(camera: Camera3D) -> void:
	_camera = camera
	if not _world_points.is_empty():
		# Re-anchor reference under the new projection so depth scales stay
		# meaningful after perspective ↔ ortho swaps.
		_reference_px_per_yard = _px_per_yard(_world_points[0])
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


func screen_point_at(index: int) -> Vector2:
	if _line == null or index < 0 or index >= _line.points.size():
		return Vector2.ZERO
	return _line.points[index]


func world_point_at(index: int) -> Vector3:
	if index < 0 or index >= _world_points.size():
		return Vector3.ZERO
	return _world_points[index]


## Perspective width multiplier at trail sample `index` (1 = tee-scale).
func width_scale_at(index: int) -> float:
	if index < 0 or index >= _depth_scales.size():
		return 1.0
	return _depth_scales[index]


func tail_alpha() -> float:
	if _line == null or _line.gradient == null:
		return 0.0
	return _line.gradient.get_color(0).a


func head_alpha() -> float:
	if _line == null or _line.gradient == null:
		return 0.0
	return _line.gradient.get_color(1).a


func trail_color() -> Color:
	return _tier_color


func _project_to_local(world_pos: Vector3) -> Vector2:
	var screen := _camera.unproject_position(world_pos)
	if get_parent() is Node2D:
		return get_parent().to_local(screen)
	return screen


## Screen pixels spanned by 1 world yard sideways at `world_pos`.
func _px_per_yard(world_pos: Vector3) -> float:
	if _camera == null:
		return 1.0
	var side := _camera.global_transform.basis.x.normalized()
	var a := _camera.unproject_position(world_pos)
	var b := _camera.unproject_position(world_pos + side)
	var px := a.distance_to(b)
	return px if px > 0.0001 else 0.0001


func _depth_scale_for(world_pos: Vector3) -> float:
	if _reference_px_per_yard <= 0.0:
		return 1.0
	var scale := _px_per_yard(world_pos) / _reference_px_per_yard
	return clampf(scale, Balance.FLIGHT_TRAIL_MIN_DEPTH_SCALE, 1.0)


func _refresh_line() -> void:
	if _line == null or _camera == null:
		return
	var zoom := ScreenFxScale.compensation(_camera, _reference_ortho_size)
	_line.width = Balance.FLIGHT_TRAIL_WIDTH * zoom * _width_mult
	var n := _world_points.size()
	var locals := PackedVector2Array()
	locals.resize(n)
	_depth_scales.resize(n)
	var curve := Curve.new()
	curve.clear_points()
	for i in n:
		locals[i] = _project_to_local(_world_points[i])
		var scale := _depth_scale_for(_world_points[i])
		_depth_scales[i] = scale
		var t := 0.0 if n <= 1 else float(i) / float(n - 1)
		curve.add_point(Vector2(t, scale))
	_line.width_curve = curve
	_line.points = locals
