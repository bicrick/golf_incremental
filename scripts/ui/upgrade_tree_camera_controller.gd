class_name UpgradeTreeCameraController
extends Node
## 2D pan/zoom for the upgrade tree — continuous wheel + pinch like IsoCameraController.
##
## Zoom listens on Node._input and via consume_zoom_event() from the panel
## _gui_input / _unhandled_input (web often routes pinch to GUI).
## Drag pan uses press→threshold like harvest. Tree node buttons do not block pan.

@export var wheel_zoom_factor: float = 1.1
@export var pinch_zoom_gain: float = 1.0
@export var zoom_in_factor: float = 0.5
@export var zoom_out_factor: float = 4.0
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_threshold_px: float = 6.0

const ZOOM_LERP := 18.0

var _viewport: Control
var _world: Control
var _start_zoom := 1.0
var _zoom := 1.0
var _zoom_target := 1.0
var _zoom_focal := Vector2.ZERO
var _pan_offset := Vector2.ZERO
var _enabled := false
var _pending := false
var _drag_active := false
var _drag_origin := Vector2.ZERO
var _drag_start_pan := Vector2.ZERO
var _did_drag := false
var _last_zoom_event: InputEvent
var _last_zoom_claimed := false
## Two-finger pinch fallback (when MagnifyGesture is missing on mobile web).
var _pinch_touches: Dictionary = {} ## finger index → screen pos
var _pinch_start_dist := 0.0


func setup(viewport: Control, world: Control) -> void:
	_viewport = viewport
	_world = world


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


func _process(delta: float) -> void:
	if not _enabled:
		return
	_lerp_zoom(delta)
	if not _drag_active and not _pending:
		return
	if Input.is_mouse_button_pressed(drag_button):
		return
	if _drag_active:
		_end_drag()
	else:
		_pending = false


func is_enabled() -> bool:
	return _enabled


func is_dragging() -> bool:
	return _drag_active


func did_drag() -> bool:
	return _did_drag


func is_pinching() -> bool:
	return _pinch_touches.size() >= 2


func reference_zoom() -> float:
	return _start_zoom


func set_baseline(start_zoom: float, pan_offset: Vector2) -> void:
	_start_zoom = maxf(start_zoom, 0.01)
	_zoom = _start_zoom
	_zoom_target = _start_zoom
	_pan_offset = pan_offset
	_apply_world_transform()


func get_zoom() -> float:
	return _zoom


func get_zoom_target() -> float:
	return _zoom_target


func get_pan_offset() -> Vector2:
	return _pan_offset


func consume_zoom_event(event: InputEvent) -> bool:
	if not _enabled or _viewport == null or _world == null:
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


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not _enabled or _viewport == null or _world == null:
		return false
	if _pinch_touches.size() >= 2:
		if _drag_active:
			_end_drag()
		_pending = false
		return false
	# Clear sticky did_drag on every new left press, including HitButton clicks that
	# return early via _should_block_pan_start (otherwise purchases stay dead after pan).
	if event is InputEventMouseButton:
		var press := event as InputEventMouseButton
		if press.button_index == drag_button and press.pressed:
			_did_drag = false
	if not _drag_active and _should_block_pan_start(event):
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != drag_button:
			return false
		if mb.pressed:
			_pending = true
			_did_drag = false
			_drag_origin = mb.position
			_drag_start_pan = _pan_offset
			return true
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
				return true
			_pending = false
			_drag_active = true
			_did_drag = true
			CursorManager.set_pan_dragging(true)
		if _drag_active:
			var delta: Vector2 = motion.position - _drag_origin
			_pan_offset = _drag_start_pan + delta
			_apply_world_transform()
			return true
		return _pending
	return false


func _should_block_pan_start(event: InputEvent) -> bool:
	var screen_pos := _event_screen_position(event)
	if not _viewport.get_global_rect().has_point(screen_pos):
		return true
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered is BaseButton:
		## Tree node HitButtons: allow press→threshold pan (inspect/buy ignore drag).
		return not _is_under_world(hovered)
	return false


func _is_under_world(node: Node) -> bool:
	var n := node
	while n != null:
		if n == _world:
			return true
		n = n.get_parent()
	return false


func _event_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).global_position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).global_position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	if consume_pan_drag_event(event):
		get_viewport().set_input_as_handled()
		return
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


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
		return 1.0 + (mag.factor - 1.0) * pinch_zoom_gain
	return _pinch_factor_from_touch(event)


func _pinch_factor_from_touch(event: InputEvent) -> float:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pinch_touches[touch.index] = touch.position
			if _pinch_touches.size() == 2:
				_pinch_start_dist = _pinch_finger_distance()
				_did_drag = true
				if _drag_active:
					_end_drag()
				_pending = false
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
		_did_drag = true
		if _drag_active:
			_end_drag()
		_pending = false
		return 1.0 + (factor - 1.0) * pinch_zoom_gain
	return 1.0


func _pinch_finger_distance() -> float:
	if _pinch_touches.size() < 2:
		return 0.0
	var pts: Array = _pinch_touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _focal_screen_from_event(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).global_position
	if event is InputEventMagnifyGesture:
		return (event as InputEventMagnifyGesture).position
	if _pinch_touches.size() >= 2:
		var pts: Array = _pinch_touches.values()
		return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
	return get_viewport().get_mouse_position()


func _apply_zoom_factor(factor: float, focal_screen: Vector2) -> void:
	var zoom_min := _start_zoom / zoom_out_factor
	var zoom_max := _start_zoom / zoom_in_factor
	if zoom_min > zoom_max:
		var swap := zoom_min
		zoom_min = zoom_max
		zoom_max = swap
	_zoom_focal = focal_screen
	var new_target := clampf(_zoom_target * factor, zoom_min, zoom_max)
	if is_equal_approx(_zoom_target, new_target):
		return
	_zoom_target = new_target


func _lerp_zoom(delta: float) -> void:
	if is_equal_approx(_zoom, _zoom_target):
		return
	var t := clampf(ZOOM_LERP * delta, 0.0, 1.0)
	var old_zoom := _zoom
	var new_zoom := lerpf(_zoom, _zoom_target, t)
	if absf(new_zoom - _zoom_target) < 0.0005:
		new_zoom = _zoom_target
	_retarget_pan(old_zoom, new_zoom, _zoom_focal)
	_zoom = new_zoom
	_apply_world_transform()


func _retarget_pan(old_zoom: float, new_zoom: float, focal_screen: Vector2) -> void:
	if old_zoom <= 0.0001 or _viewport == null:
		return
	var viewport_local := focal_screen - _viewport.global_position
	var world_before := (viewport_local - _pan_offset) / old_zoom
	_pan_offset = viewport_local - world_before * new_zoom


func _apply_world_transform() -> void:
	if _world == null:
		return
	_world.scale = Vector2(_zoom, _zoom)
	_world.position = _pan_offset


func _end_drag() -> void:
	_drag_active = false
	_pending = false
	CursorManager.set_pan_dragging(false)
