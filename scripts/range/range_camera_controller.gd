class_name RangeCameraController
extends Node
## Orthographic pan/zoom. Scene Camera3D owns position and starting size; this script
## only pans freely and clamps zoom relative to the size at setup. Rotation is locked
## elsewhere via V4CameraConfig.

@export var pan_speed: float = 24.0
@export var zoom_sensitivity: float = 1.5
@export var zoom_in_factor: float = 0.5
@export var zoom_out_factor: float = 4.0

var _camera: Camera3D
var _start_size: float
var _enabled := false
var _right_dir := Vector3.RIGHT
var _forward_dir := Vector3.FORWARD


func setup(camera: Camera3D) -> void:
	_camera = camera
	if _camera == null:
		return
	_start_size = _camera.size
	_refresh_pan_axes()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_input(enabled)
	set_process(enabled)


func is_enabled() -> bool:
	return _enabled


func _input(event: InputEvent) -> void:
	if not _enabled or _camera == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			_apply_zoom(direction * mb.factor * zoom_sensitivity)
			get_viewport().set_input_as_handled()


func _apply_zoom(delta: float) -> void:
	var min_size := _start_size * zoom_in_factor
	var max_size := _start_size * zoom_out_factor
	if min_size > max_size:
		var swap := min_size
		min_size = max_size
		max_size = swap
	_camera.size = clampf(_camera.size + delta, min_size, max_size)


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
