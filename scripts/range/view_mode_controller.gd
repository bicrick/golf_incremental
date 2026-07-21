class_name ViewModeController
extends Node
## Full-screen strike (perspective) vs harvest (ortho) camera modes with snapshot dissolve.

enum Mode { STRIKE, HARVEST, TRANSITIONING }

signal view_mode_changed(mode: Mode)

const VIEW_DISSOLVE_SEC := 0.30

var _mode: Mode = Mode.STRIKE
var _perspective_camera: Camera3D
var _ortho_camera: Camera3D
var _sky_dome: RangeSkyDome
var _perspective_sky_dome: RangeSkyDome
var _camera_controller: RangeCameraController
var _range_view: Node3D
var _transition: Control
var _harvest_view_ready := false
var _transition_gen := 0


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


func get_mode() -> Mode:
	return _mode


func is_transitioning() -> bool:
	return _mode == Mode.TRANSITIONING


func is_harvest_view_ready() -> bool:
	return _mode == Mode.HARVEST and _harvest_view_ready


func can_use_ortho_pan() -> bool:
	return is_harvest_view_ready()


func start_initial_mode() -> void:
	if GameState.is_harvest_phase():
		_enter_harvest_immediate()
	else:
		_enter_strike_immediate()


func on_phase_changed(phase: String) -> void:
	if phase == "harvest":
		_transition_to_harvest()
	elif phase == "strike":
		_transition_to_strike()


func _transition_to_harvest() -> void:
	if _mode == Mode.HARVEST and _harvest_view_ready:
		return
	_run_transition(_apply_harvest_cameras, Mode.HARVEST)


func _transition_to_strike() -> void:
	if _mode == Mode.STRIKE:
		return
	_run_transition(_apply_strike_cameras, Mode.STRIKE)


func _run_transition(apply_cameras: Callable, final_mode: Mode) -> void:
	_transition_gen += 1
	var gen := _transition_gen
	_mode = Mode.TRANSITIONING
	_harvest_view_ready = false
	if _camera_controller:
		_camera_controller.set_enabled(false)
	view_mode_changed.emit(_mode)

	var dissolve := _fade_duration(VIEW_DISSOLVE_SEC)
	# Headless / zero-dissolve: settle synchronously so pickup gates unlock same frame.
	if _transition == null or dissolve <= 0.0:
		apply_cameras.call()
		_finish_transition(final_mode, gen)
		return
	_run_transition_async(apply_cameras, final_mode, dissolve, gen)


func _run_transition_async(
	apply_cameras: Callable, final_mode: Mode, dissolve: float, gen: int
) -> void:
	var outgoing: Camera3D = (
		_perspective_camera if final_mode == Mode.HARVEST else _ortho_camera
	)
	if _transition.has_method(&"capture_from_camera") and outgoing != null:
		await _transition.capture_from_camera(outgoing)
	if gen != _transition_gen:
		return
	apply_cameras.call()
	await get_tree().process_frame
	if gen != _transition_gen:
		return
	# Unlock pan/pickup as soon as the new camera is live; dissolve is visual only.
	_finish_transition(final_mode, gen)
	if _transition.has_method(&"dissolve_out"):
		await _transition.dissolve_out(dissolve)


func _finish_transition(final_mode: Mode, gen: int) -> void:
	if gen != _transition_gen:
		return
	_mode = final_mode
	_harvest_view_ready = final_mode == Mode.HARVEST
	if final_mode == Mode.HARVEST and _camera_controller and _range_view and _range_view.visible:
		_camera_controller.set_enabled(true)
	elif final_mode == Mode.STRIKE and _camera_controller:
		_camera_controller.set_enabled(false)
	view_mode_changed.emit(_mode)


func _enter_strike_immediate() -> void:
	_transition_gen += 1
	_apply_strike_cameras()
	_mode = Mode.STRIKE
	_harvest_view_ready = false
	view_mode_changed.emit(_mode)


func _enter_harvest_immediate() -> void:
	_transition_gen += 1
	_apply_harvest_cameras()
	_mode = Mode.HARVEST
	_harvest_view_ready = true
	if _camera_controller and _range_view and _range_view.visible:
		_camera_controller.set_enabled(true)
	view_mode_changed.emit(_mode)


func _apply_strike_cameras() -> void:
	if _perspective_camera:
		_perspective_camera.current = true
	if _ortho_camera:
		_ortho_camera.current = false
	if _perspective_sky_dome and _perspective_camera:
		_perspective_sky_dome.setup(_perspective_camera)
	if _camera_controller:
		_camera_controller.set_enabled(false)


func _apply_harvest_cameras() -> void:
	## Cameras swap during dissolve; ortho pan stays disabled until _finish_transition.
	if _ortho_camera:
		_ortho_camera.current = true
	if _perspective_camera:
		_perspective_camera.current = false
	if _sky_dome and _ortho_camera:
		_sky_dome.setup(_ortho_camera)
	if _camera_controller:
		_camera_controller.set_enabled(false)


func _fade_duration(seconds: float) -> float:
	if _is_headless():
		return 0.0
	return seconds


func _is_headless() -> bool:
	# --headless is stripped from OS.get_cmdline_args() under --script runs.
	if DisplayServer.get_name() == "headless":
		return true
	for arg in OS.get_cmdline_args():
		if arg == "--headless":
			return true
	return false
