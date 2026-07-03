class_name RangeCameraController
extends Node
## Runtime pan/zoom for the orthographic range camera. Rotation is fixed at setup.
##
## Editor troubleshooting:
## - Embedded game runner: scroll wheel may go to editor UI; UIRoot _gui_input is the fallback path.
## - Exact 50/50 dark bottom pane: Godot Input debug toolbar is toggled on — not a scene bug.

const PAN_SPEED_YARDS_PER_SEC := 24.0
const ZOOM_STEP := 2.0
const ZOOM_LERP_SPEED := 10.0

const PAN_MARGIN_X := 1.0
const PAN_MARGIN_Z := 4.0

var _camera: Camera3D
var _home_position: Vector3
var _home_size: float
var _target_size: float
var _enabled := false
var _right_dir := Vector3.RIGHT
var _forward_dir := Vector3.FORWARD


func setup(camera: Camera3D, home_position: Vector3, home_size: float) -> void:
	_camera = camera
	_home_position = home_position
	_home_size = home_size
	_target_size = home_size
	if _camera:
		var basis := _camera.global_transform.basis
		_right_dir = Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		_forward_dir = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_input(enabled)


func is_enabled() -> bool:
	return _enabled


func consume_zoom_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	var amount := _zoom_amount_from_event(event)
	if is_zero_approx(amount):
		return false
	_zoom_by(amount)
	return true


func _input(event: InputEvent) -> void:
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


func _zoom_amount_from_event(event: InputEvent) -> float:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -ZOOM_STEP
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return ZOOM_STEP
	if event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		return -ZOOM_STEP * (mag.factor - 1.0) * 4.0
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed:
			return 0.0
		match key.keycode:
			KEY_E, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				return -ZOOM_STEP
			KEY_Q, KEY_MINUS, KEY_KP_SUBTRACT:
				return ZOOM_STEP
	return 0.0


func _zoom_by(amount: float) -> void:
	var zoom_max := maxf(_home_size * 5.0, 40.0)
	_target_size = clampf(_target_size + amount, _home_size, zoom_max)


func _process(delta: float) -> void:
	if not _enabled or _camera == null:
		return
	if not is_equal_approx(_camera.size, _target_size):
		_camera.size = move_toward(_camera.size, _target_size, ZOOM_LERP_SPEED * delta)

	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		move -= _right_dir
	if Input.is_key_pressed(KEY_D):
		move += _right_dir
	if Input.is_key_pressed(KEY_W):
		move += _forward_dir
	if Input.is_key_pressed(KEY_S):
		move -= _forward_dir
	if move != Vector3.ZERO:
		_apply_pan(move.normalized() * PAN_SPEED_YARDS_PER_SEC * delta)


func _apply_pan(delta: Vector3) -> void:
	var pos := _camera.position + delta
	var x_min := -RangeGrid.HALF_WIDTH_YARDS - PAN_MARGIN_X
	var x_max := RangeGrid.HALF_WIDTH_YARDS + PAN_MARGIN_X
	var z_max := PAN_MARGIN_Z
	var z_min := -RangeGrid.DEPTH_YARDS - PAN_MARGIN_Z
	pos.x = clampf(pos.x, x_min, x_max)
	pos.z = clampf(pos.z, z_min, z_max)
	_camera.position = pos
