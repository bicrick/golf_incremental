@tool
extends Node3D
## Minimal range scene — cell grid ground, surround plane, orthographic camera with pan/zoom.
## Ground meshes build in the editor so Camera3D preview shows the fairway while tuning.

@onready var _camera: Camera3D = $Camera3D
@onready var _ground: MeshInstance3D = $Ground
@onready var _surround: MeshInstance3D = $Surround
@onready var _player_bay: Node3D = $Bays/PlayerBay
@onready var _camera_controller: RangeCameraController = $CameraController


func _should_use_editor_rig() -> bool:
	if not Engine.is_editor_hint():
		return false
	var edited := get_tree().edited_scene_root
	return edited != null and edited == self


func _enter_tree() -> void:
	if _should_use_editor_rig():
		_refresh_preview()


func _ready() -> void:
	_refresh_preview()
	if not Engine.is_editor_hint():
		_camera_controller.setup(
			_camera,
			_camera.position,
			_camera.size
		)
		_camera_controller.set_enabled(visible)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _camera_controller and not Engine.is_editor_hint():
		_camera_controller.set_enabled(visible)


func consume_zoom_event(event: InputEvent) -> bool:
	if not visible or _camera_controller == null:
		return false
	return _camera_controller.consume_zoom_event(event)


func get_camera() -> Camera3D:
	return _camera


func get_golfer() -> AnimatedSprite3D:
	if _player_bay and _player_bay.has_method(&"get_golfer"):
		return _player_bay.get_golfer()
	return null


func get_ball() -> AnimatedSprite3D:
	if _player_bay and _player_bay.has_method(&"get_ball"):
		return _player_bay.get_ball()
	return null


func _refresh_preview() -> void:
	_build_ground()
	_setup_camera()
	_setup_player_bay()


func _setup_player_bay() -> void:
	if _player_bay == null:
		return
	_player_bay.position = RangeGrid.player_bay_origin()
	var bay_ground := _player_bay.get_node_or_null("Ground") as MeshInstance3D
	if bay_ground:
		bay_ground.visible = false


func _build_ground() -> void:
	if _ground == null or _surround == null:
		return
	var snap := DayNightPalette.sample_at(24.0)
	CellGround.apply_grid_to_mesh(
		_ground,
		RangeGrid.GRID_WIDTH_CELLS,
		RangeGrid.GRID_DEPTH_CELLS,
		snap.fairway_light,
		snap.fairway_dark
	)
	FairwayGrassTiles3D.apply_surround(_surround, snap.fairway_light, _camera_home_size())


func _camera_home_size() -> float:
	if _camera:
		return _camera.size
	return 8.0


func _setup_camera() -> void:
	if _camera == null:
		return
	V4CameraConfig.apply_locked_rotation_only(_camera)
	_camera.current = true
