class_name ViewModeController
extends Node
## Full-screen strike (perspective) vs harvest (ortho) camera modes with sky crossfade.

enum Mode { STRIKE, HARVEST, TRANSITIONING }

signal view_mode_changed(mode: Mode)

const VIEW_CROSSFADE_IN_SEC := 0.35
const VIEW_CROSSFADE_OUT_SEC := 0.35
const VIEW_HARVEST_DELAY_AFTER_FLIGHTS_SEC := 0.3

var _mode: Mode = Mode.STRIKE
var _perspective_camera: Camera3D
var _ortho_camera: Camera3D
var _sky_dome: RangeSkyDome
var _perspective_sky_dome: RangeSkyDome
var _camera_controller: RangeCameraController
var _range_view: Node3D
var _transition: Control
var _sky_color_provider: Callable = Callable()
var _has_active_flights: Callable = Callable()
var _pending_harvest := false
var _harvest_view_ready := false


func setup(
	range_view: Node3D,
	perspective_camera: Camera3D,
	ortho_camera: Camera3D,
	sky_dome: RangeSkyDome,
	perspective_sky_dome: RangeSkyDome,
	camera_controller: RangeCameraController
) -> void:
	_range_view = range_view
	_perspective_camera = perspective_camera
	_ortho_camera = ortho_camera
	_sky_dome = sky_dome
	_perspective_sky_dome = perspective_sky_dome
	_camera_controller = camera_controller


func bind_transition(transition: Control) -> void:
	_transition = transition


func set_sky_color_provider(provider: Callable) -> void:
	_sky_color_provider = provider


func set_has_active_flights_checker(checker: Callable) -> void:
	_has_active_flights = checker


func get_mode() -> Mode:
	return _mode


func is_transitioning() -> bool:
	return _mode == Mode.TRANSITIONING


func is_harvest_view_ready() -> bool:
	return _mode == Mode.HARVEST and _harvest_view_ready and not is_transitioning()


func can_use_ortho_pan() -> bool:
	return _mode == Mode.HARVEST and _harvest_view_ready and not is_transitioning()


func start_initial_mode() -> void:
	if GameState.is_harvest_phase():
		_enter_harvest_immediate()
	else:
		_enter_strike_immediate()


func on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_pending_harvest = true
		_try_begin_harvest_transition()
	elif phase == "strike":
		_pending_harvest = false
		_transition_to_strike()


func _process(_delta: float) -> void:
	if _pending_harvest:
		_try_begin_harvest_transition()


func _try_begin_harvest_transition() -> void:
	if not _pending_harvest or is_transitioning() or _mode == Mode.HARVEST:
		return
	if _has_active_flights.is_valid() and _has_active_flights.call():
		return
	_pending_harvest = false
	_transition_to_harvest()


func _transition_to_harvest() -> void:
	if _mode == Mode.HARVEST and _harvest_view_ready:
		return
	_run_transition(_enter_harvest_immediate, true)


func _transition_to_strike() -> void:
	if _mode == Mode.STRIKE:
		return
	_run_transition(_enter_strike_immediate, false)


func _run_transition(apply_mode: Callable, is_harvest: bool) -> void:
	if _transition == null:
		apply_mode.call()
		return
	_mode = Mode.TRANSITIONING
	_harvest_view_ready = false
	view_mode_changed.emit(_mode)
	var fade_in := _fade_duration(VIEW_CROSSFADE_IN_SEC)
	var fade_out := _fade_duration(VIEW_CROSSFADE_OUT_SEC)
	var delay := _fade_duration(VIEW_HARVEST_DELAY_AFTER_FLIGHTS_SEC) if is_harvest else 0.0
	_run_transition_async(apply_mode, fade_in, fade_out, delay)


func _run_transition_async(apply_mode: Callable, fade_in: float, fade_out: float, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var sky := _current_sky_color()
	await _transition.fade_to_color(sky, fade_in)
	apply_mode.call()
	await _transition.fade_out(fade_out)
	if _mode != Mode.TRANSITIONING:
		return
	if _pending_harvest and _mode == Mode.TRANSITIONING:
		return
	view_mode_changed.emit(_mode)


func _enter_strike_immediate() -> void:
	_mode = Mode.STRIKE
	_harvest_view_ready = false
	if _perspective_camera:
		_perspective_camera.current = true
	if _ortho_camera:
		_ortho_camera.current = false
	if _perspective_sky_dome and _perspective_camera:
		_perspective_sky_dome.setup(_perspective_camera)
	if _camera_controller:
		_camera_controller.set_enabled(false)
	view_mode_changed.emit(_mode)


func _enter_harvest_immediate() -> void:
	_mode = Mode.HARVEST
	_harvest_view_ready = true
	if _ortho_camera:
		_ortho_camera.current = true
	if _perspective_camera:
		_perspective_camera.current = false
	if _sky_dome and _ortho_camera:
		_sky_dome.setup(_ortho_camera)
	if _camera_controller and _range_view and _range_view.visible:
		_camera_controller.set_enabled(true)
	view_mode_changed.emit(_mode)


func _current_sky_color() -> Color:
	if _sky_color_provider.is_valid():
		return _sky_color_provider.call()
	return DayNightPalette.SKY_DAY


func _fade_duration(seconds: float) -> float:
	if _is_headless():
		return 0.0
	return seconds


func _is_headless() -> bool:
	for arg in OS.get_cmdline_args():
		if arg == "--headless":
			return true
	return false
