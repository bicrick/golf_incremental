class_name IsoCameraController
extends Node
## 2D pan/zoom for IsoView. Zoom snaps to discrete scales for crisp pixels.
## Drag uses the same press→threshold→pan gesture as RangeCameraController.
## WASD / arrows pan in screen space (zoom-compensated).

@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_threshold_px: float = 6.0
## Screen-space pan speed in pixels per second (divided by zoom for world delta).
@export var key_pan_speed_px: float = 480.0

## Discrete zoom steps (further out = 0.25).
const ZOOM_STEPS: Array[float] = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0]
const DEFAULT_ZOOM_INDEX := 2 ## 1.0x
## Smoothing for ball-follow pan (higher = snappier).
const FOLLOW_LERP := 8.0

var _camera: Camera2D
var _enabled := false
var _pending := false
var _drag_active := false
var _drag_origin := Vector2.ZERO
var _last_drag_screen := Vector2.ZERO
var _zoom_index: int = DEFAULT_ZOOM_INDEX
var _follow_active := false
var _follow_target := Vector2.ZERO
var _follow_cancelled := false


func setup(camera: Camera2D) -> void:
	_camera = camera
	if _camera == null:
		return
	_apply_zoom_index(_zoom_index)


func set_enabled(enabled: bool) -> void:
	if not enabled:
		if _drag_active:
			_end_drag()
		_pending = false
		cancel_follow()
	_enabled = enabled
	set_process_input(enabled)
	set_process(enabled)


func _release_drag_if_button_up() -> void:
	if not _drag_active and not _pending:
		return
	if Input.is_mouse_button_pressed(drag_button):
		return
	if _drag_active:
		_end_drag()
	else:
		_pending = false


## Smoothly pan toward an IsoView-local pixel while a ball is airborne.
## No-ops after cancel_follow() until stop_follow_soft() / a new flight.
func follow_world_px(px: Vector2) -> void:
	if not _enabled or _camera == null or _follow_cancelled:
		return
	_follow_active = true
	_follow_target = px


## User pan/zoom — drop follow for the rest of this flight.
func cancel_follow() -> void:
	_follow_active = false
	_follow_cancelled = true


## Called when no balls remain airborne; allows the next flight to follow again.
func stop_follow_soft() -> void:
	_follow_active = false
	_follow_cancelled = false


func is_following() -> bool:
	return _follow_active and not _follow_cancelled


func is_enabled() -> bool:
	return _enabled


func is_dragging() -> bool:
	return _drag_active


func get_zoom_level() -> float:
	return ZOOM_STEPS[_zoom_index]


func get_zoom_index() -> int:
	return _zoom_index


func consume_zoom_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	var direction := _zoom_direction_from_event(event)
	if direction == 0:
		return false
	cancel_follow()
	_apply_zoom_index(clampi(_zoom_index + direction, 0, ZOOM_STEPS.size() - 1))
	return true


func cancel_pending_pan() -> void:
	if _drag_active:
		_end_drag()
		return
	_pending = false


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not _enabled or _camera == null:
		return false
	if not _drag_active and UiInput.is_interactive_control_under_mouse(get_viewport()):
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != drag_button:
			return false
		if mb.pressed:
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
			cancel_follow()
			CursorManager.set_pan_dragging(true)
		if _drag_active:
			_apply_drag_motion(motion.position)
			_last_drag_screen = motion.position
			return true
		return false
	return false


## Apply a keyboard pan step (screen-space, zoom-compensated). Used by verify.
func apply_key_pan(dir: Vector2, delta: float) -> void:
	if not _enabled or _camera == null:
		return
	if dir == Vector2.ZERO:
		return
	cancel_follow()
	var zoom_x: float = maxf(_camera.zoom.x, 0.001)
	_camera.position += dir.normalized() * key_pan_speed_px * delta / zoom_x


func _input(event: InputEvent) -> void:
	if consume_pan_drag_event(event):
		get_viewport().set_input_as_handled()
		return
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


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
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if move != Vector2.ZERO:
		apply_key_pan(move, delta)
		return
	if _follow_active and not _follow_cancelled:
		var t := clampf(FOLLOW_LERP * delta, 0.0, 1.0)
		_camera.position = _camera.position.lerp(_follow_target, t)


func _zoom_direction_from_event(event: InputEvent) -> int:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return 0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			return 1
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return -1
	return 0


func _apply_zoom_index(index: int) -> void:
	_zoom_index = clampi(index, 0, ZOOM_STEPS.size() - 1)
	if _camera == null:
		return
	var z: float = ZOOM_STEPS[_zoom_index]
	_camera.zoom = Vector2(z, z)


func _apply_drag_motion(current_screen: Vector2) -> void:
	if _last_drag_screen.is_equal_approx(current_screen):
		return
	var delta_screen := _last_drag_screen - current_screen
	_camera.position += delta_screen / _camera.zoom


func _end_drag() -> void:
	_drag_active = false
	_pending = false
	CursorManager.set_pan_dragging(false)
