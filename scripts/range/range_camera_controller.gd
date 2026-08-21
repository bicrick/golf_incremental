class_name RangeCameraController
extends Node
## Orthographic pan/zoom. Scene Camera3D owns position and starting size; this script
## only pans freely and clamps zoom relative to the size at setup. Rotation is locked
## elsewhere via V4CameraConfig.
##
## Zoom listens on Node._input and via consume_zoom_event() (called from range_view
## _unhandled_input and ui_root _gui_input when the embedded runner routes wheel to UI).
## Left-click drag pan uses the same _input path plus consume_pan_drag_event() fallbacks.
## A small movement threshold distinguishes drag pan from click pickup.
## Pinch is 1:1 with finger distance (maps-style); wheel is a small proportional notch.

@export var pan_speed: float = 24.0
## Multiplicative zoom per mouse-wheel notch (>1 zooms in / shrinks ortho size).
@export var wheel_zoom_factor: float = 1.1
@export var zoom_in_factor: float = 0.5
@export var zoom_out_factor: float = 4.0
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_threshold_px: float = 6.0

var _camera: Camera3D
var _start_size: float
var _enabled := false
var _pending := false
var _drag_active := false
var _drag_origin := Vector2.ZERO
var _last_drag_screen := Vector2.ZERO
var _right_dir := Vector3.RIGHT
var _forward_dir := Vector3.FORWARD
var _last_zoom_event: InputEvent
var _last_zoom_claimed := false

const PAN_PLANE_Y := 0.0


func setup(camera: Camera3D) -> void:
	_camera = camera
	if _camera == null:
		return
	_start_size = _camera.size
	_refresh_pan_axes()


func set_enabled(enabled: bool) -> void:
	if not enabled:
		if _drag_active:
			_end_drag()
		_pending = false
		_pinch_touches.clear()
		_pinch_start_dist = 0.0
	_enabled = enabled
	set_process_input(enabled)
	set_process(enabled)


func is_enabled() -> bool:
	return _enabled


func is_dragging() -> bool:
	return _drag_active


func reference_ortho_size() -> float:
	return _start_size


func consume_zoom_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	if event == _last_zoom_event:
		return _last_zoom_claimed
	var factor := _zoom_factor_from_event(event)
	if factor <= 0.0 or is_equal_approx(factor, 1.0):
		_last_zoom_event = event
		_last_zoom_claimed = false
		return false
	_apply_zoom_factor(factor, _focal_screen_from_event(event))
	_last_zoom_event = event
	_last_zoom_claimed = true
	return true


## Call when a click was used for gameplay (collect) so it cannot become a pan.
func cancel_pending_pan() -> void:
	if _drag_active:
		_end_drag()
		return
	_pending = false


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	if _pinch_touches.size() >= 2:
		if _drag_active:
			_end_drag()
		_pending = false
		return false
	if not _drag_active and UiInput.is_interactive_control_under_mouse(get_viewport()):
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != drag_button:
			return false
		if mb.pressed:
			## Arm pan, but do not claim the press — collect-on-press needs it first.
			## Drag only claims the gesture after motion past drag_threshold_px.
			_pending = true
			_drag_origin = mb.position
			_last_drag_screen = mb.position
			return false
		if _drag_active:
			_end_drag()
			return true
		if _pending:
			_pending = false
			return false
		return false
	if event is InputEventMouseMotion and (_pending or _drag_active):
		var motion := event as InputEventMouseMotion
		if _pending and not _drag_active:
			if motion.position.distance_to(_drag_origin) <= drag_threshold_px:
				return false
			_pending = false
			_drag_active = true
			CursorManager.set_pan_dragging(true)
		if _drag_active:
			_apply_drag_motion(motion.position)
			_last_drag_screen = motion.position
			return true
		return false
	return false


func _input(event: InputEvent) -> void:
	if consume_pan_drag_event(event):
		get_viewport().set_input_as_handled()
		return
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


## Zoom scale > 1 zooms in (smaller ortho size). 1 = no change.
func _zoom_factor_from_event(event: InputEvent) -> float:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return 1.0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			return wheel_zoom_factor
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return 1.0 / wheel_zoom_factor
	if event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		## Godot factor is incremental (1.2 = fingers 20% farther = zoom 1.2x).
		return mag.factor
	return _pinch_factor_from_touch(event)


var _pinch_touches: Dictionary = {}
var _pinch_start_dist := 0.0


func _pinch_factor_from_touch(event: InputEvent) -> float:
	## Fallback when MagnifyGesture is missing (common on mobile web).
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pinch_touches[touch.index] = touch.position
			if _pinch_touches.size() == 2:
				_pinch_start_dist = _pinch_finger_distance()
		else:
			_pinch_touches.erase(touch.index)
			if _pinch_touches.size() < 2:
				_pinch_start_dist = 0.0
		return 1.0
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _pinch_touches.has(drag.index):
			return 1.0
		_pinch_touches[drag.index] = drag.position
		if _pinch_touches.size() != 2 or _pinch_start_dist < 1.0:
			return 1.0
		var dist := _pinch_finger_distance()
		if dist < 1.0:
			return 1.0
		var factor := dist / _pinch_start_dist
		_pinch_start_dist = dist
		## Instant 1:1: fingers 20% farther → factor 1.2 → size /= 1.2.
		return factor
	return 1.0


func _pinch_finger_distance() -> float:
	if _pinch_touches.size() < 2:
		return 0.0
	var pts: Array = _pinch_touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _focal_screen_from_event(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMagnifyGesture:
		return (event as InputEventMagnifyGesture).position
	if _pinch_touches.size() >= 2:
		var pts: Array = _pinch_touches.values()
		return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	return get_viewport().get_mouse_position()


func _apply_zoom_factor(factor: float, focal_screen: Vector2) -> void:
	var min_size := _start_size * zoom_in_factor
	var max_size := _start_size * zoom_out_factor
	if min_size > max_size:
		var swap := min_size
		min_size = max_size
		max_size = swap
	var old_size := _camera.size
	if old_size <= 0.0001 or factor <= 0.0001:
		return
	var new_size := clampf(old_size / factor, min_size, max_size)
	if is_equal_approx(old_size, new_size):
		return
	var world_before: Variant = null
	if focal_screen.length_squared() > 0.25:
		world_before = _ground_at_screen(focal_screen)
	_camera.size = new_size
	if world_before == null:
		return
	var world_after: Variant = _ground_at_screen(focal_screen)
	if world_after == null:
		return
	var delta: Vector3 = world_before - world_after
	_camera.position.x += delta.x
	_camera.position.z += delta.z


func _apply_drag_motion(current_screen: Vector2) -> void:
	if _last_drag_screen.is_equal_approx(current_screen):
		return
	var from: Variant = _ground_at_screen(_last_drag_screen)
	var to: Variant = _ground_at_screen(current_screen)
	if from == null or to == null:
		return
	var delta: Vector3 = from - to
	_camera.position.x += delta.x
	_camera.position.z += delta.z


func _ground_at_screen(screen_pos: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (PAN_PLANE_Y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _end_drag() -> void:
	_drag_active = false
	_pending = false
	CursorManager.set_pan_dragging(false)


func _release_drag_if_button_up() -> void:
	if not _drag_active and not _pending:
		return
	if Input.is_mouse_button_pressed(drag_button):
		return
	if _drag_active:
		_end_drag()
	else:
		_pending = false


func _process(delta: float) -> void:
	if not _enabled or _camera == null:
		return
	_release_drag_if_button_up()

	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y -= 1.0
	if move == Vector2.ZERO:
		return

	_refresh_pan_axes()
	var delta_xz := (_right_dir * move.x + _forward_dir * move.y).normalized()
	_camera.position += delta_xz * pan_speed * delta


func _refresh_pan_axes() -> void:
	if _camera == null:
		return
	var basis := _camera.global_transform.basis
	_right_dir = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	_forward_dir = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
