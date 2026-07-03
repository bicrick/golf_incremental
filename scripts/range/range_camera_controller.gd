class_name RangeCameraController
extends Node
## Orthographic pan/zoom. Scene Camera3D owns position and starting size; this script
## only pans freely and clamps zoom relative to the size at setup. Rotation is locked
## elsewhere via V4CameraConfig.
##
## Zoom listens on Node._input and via consume_zoom_event() (called from range_view
## _unhandled_input and ui_root _gui_input when the embedded runner routes wheel to UI).
## Middle-mouse drag pan is routed only through consume_pan_drag_event().

@export var pan_speed: float = 24.0
@export var zoom_step: float = 1.0
@export var zoom_in_factor: float = 0.5
@export var zoom_out_factor: float = 4.0
@export var drag_button: MouseButton = MOUSE_BUTTON_MIDDLE

var _camera: Camera3D
var _start_size: float
var _enabled := false
var _drag_active := false
var _last_drag_screen := Vector2.ZERO
var _right_dir := Vector3.RIGHT
var _forward_dir := Vector3.FORWARD


func setup(camera: Camera3D) -> void:
	_camera = camera
	if _camera == null:
		return
	_start_size = _camera.size
	_refresh_pan_axes()


func set_enabled(enabled: bool) -> void:
	if not enabled and _drag_active:
		_end_drag()
	_enabled = enabled
	set_process_input(enabled)
	set_process(enabled)


func is_enabled() -> bool:
	return _enabled


func is_dragging() -> bool:
	return _drag_active


func consume_zoom_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	var amount := _zoom_amount_from_event(event)
	if is_zero_approx(amount):
		return false
	_apply_zoom(amount)
	return true


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != drag_button:
			return false
		if mb.pressed:
			_drag_active = true
			_last_drag_screen = mb.position
			CursorManager.set_grab_cursor()
			return true
		if _drag_active:
			_end_drag()
			return true
		return false
	if event is InputEventMouseMotion and _drag_active:
		var motion := event as InputEventMouseMotion
		_apply_drag_delta(motion.position - _last_drag_screen)
		_last_drag_screen = motion.position
		return true
	return false


func _input(event: InputEvent) -> void:
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


func _zoom_amount_from_event(event: InputEvent) -> float:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return 0.0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -zoom_step
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return zoom_step
	if event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		return -zoom_step * (mag.factor - 1.0) * 4.0
	return 0.0


func _apply_zoom(delta: float) -> void:
	var min_size := _start_size * zoom_in_factor
	var max_size := _start_size * zoom_out_factor
	if min_size > max_size:
		var swap := min_size
		min_size = max_size
		max_size = swap
	_camera.size = clampf(_camera.size + delta, min_size, max_size)


func _apply_drag_delta(delta: Vector2) -> void:
	if delta == Vector2.ZERO:
		return
	_refresh_pan_axes()
	var vp_height := get_viewport().get_visible_rect().size.y
	if is_zero_approx(vp_height):
		return
	var units_per_pixel := (_camera.size * 2.0) / vp_height
	_camera.position -= _right_dir * delta.x * units_per_pixel
	_camera.position += _forward_dir * delta.y * units_per_pixel


func _end_drag() -> void:
	_drag_active = false
	CursorManager.sync_collect_cursor()


func _process(delta: float) -> void:
	if not _enabled or _camera == null:
		return

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
