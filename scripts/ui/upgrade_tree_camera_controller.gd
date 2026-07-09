class_name UpgradeTreeCameraController
extends Node
## 2D pan/zoom for the upgrade tree — mirrors RangeCameraController wheel + pinch behavior.
##
## Zoom listens on Node._input and via consume_zoom_event() when the embedded runner
## routes wheel events to UI. Left-click drag pan uses the same path.

@export var zoom_step_factor: float = 0.08
@export var zoom_in_factor: float = 0.5
@export var zoom_out_factor: float = 4.0
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_threshold_px: float = 6.0

var _viewport: Control
var _world: Control
var _start_zoom := 1.0
var _zoom := 1.0
var _pan_offset := Vector2.ZERO
var _enabled := false
var _pending := false
var _drag_active := false
var _drag_origin := Vector2.ZERO
var _drag_start_pan := Vector2.ZERO
var _did_drag := false


func setup(viewport: Control, world: Control) -> void:
	_viewport = viewport
	_world = world


func set_enabled(enabled: bool) -> void:
	if not enabled:
		if _drag_active:
			_end_drag()
		_pending = false
	_enabled = enabled
	set_process_input(enabled)


func is_enabled() -> bool:
	return _enabled


func is_dragging() -> bool:
	return _drag_active


func did_drag() -> bool:
	return _did_drag


func reference_zoom() -> float:
	return _start_zoom


func set_baseline(start_zoom: float, pan_offset: Vector2) -> void:
	_start_zoom = maxf(start_zoom, 0.01)
	_zoom = _start_zoom
	_pan_offset = pan_offset
	_apply_world_transform()


func get_zoom() -> float:
	return _zoom


func get_pan_offset() -> Vector2:
	return _pan_offset


func consume_zoom_event(event: InputEvent) -> bool:
	if not _enabled or _viewport == null or _world == null:
		return false
	var amount := _zoom_amount_from_event(event)
	if is_zero_approx(amount):
		return false
	var focal := _focal_screen_from_event(event)
	_apply_zoom(amount, focal)
	return true


func consume_pan_drag_event(event: InputEvent) -> bool:
	if not _enabled or _viewport == null or _world == null:
		return false
	# TreeViewport is MOUSE_FILTER_STOP so empty space would look "interactive" to
	# UiInput — only block pan start on real buttons (Back + node HitButtons).
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
	return hovered is BaseButton


func _event_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).global_position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).global_position
	return get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	if consume_pan_drag_event(event):
		get_viewport().set_input_as_handled()
		return
	if consume_zoom_event(event):
		get_viewport().set_input_as_handled()


func _zoom_amount_from_event(event: InputEvent) -> float:
	var step := _start_zoom * zoom_step_factor
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return 0.0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			return step
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return -step
	if event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		return step * (mag.factor - 1.0) * 4.0
	return 0.0


func _focal_screen_from_event(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMagnifyGesture:
		return get_viewport().get_mouse_position()
	return get_viewport().get_mouse_position()


func _apply_zoom(delta_zoom: float, focal_screen: Vector2) -> void:
	var zoom_min := _start_zoom / zoom_out_factor
	var zoom_max := _start_zoom / zoom_in_factor
	if zoom_min > zoom_max:
		var swap := zoom_min
		zoom_min = zoom_max
		zoom_max = swap
	var old_zoom := _zoom
	var new_zoom := clampf(old_zoom + delta_zoom, zoom_min, zoom_max)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var viewport_local := focal_screen - _viewport.global_position
	var world_before := (viewport_local - _pan_offset) / old_zoom
	_zoom = new_zoom
	_pan_offset = viewport_local - world_before * _zoom
	_apply_world_transform()


func _apply_world_transform() -> void:
	if _world == null:
		return
	_world.scale = Vector2(_zoom, _zoom)
	_world.position = _pan_offset


func _end_drag() -> void:
	_drag_active = false
	_pending = false
	CursorManager.set_pan_dragging(false)
