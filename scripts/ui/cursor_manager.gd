class_name CursorManager
extends RefCounted
## Central cursor resolver — one place decides arrow / range picker / grab from game state.
##
## Priority: pan grab > range picker (harvest view ready) > default arrow.
## UI Controls use mouse_default_cursor_shape = CURSOR_POINTING_HAND; both shapes
## are rebound together so viewport and button hover stay in sync.

const CURSOR_ARROW_PATH := "res://assets/cursors/cursor_arrow.png"
const CURSOR_HAND_PATH := "res://assets/cursors/cursor_hand.png"
const CURSOR_RANGE_PICKER_PATH := "res://assets/cursors/cursor_range_picker.png"
const CURSOR_GRAB_PATH := "res://assets/cursors/cursor_grab.png"

const SELECTABLE_CURSOR_SHAPE := Control.CURSOR_POINTING_HAND

static var _arrow_texture: Texture2D
static var _hand_texture: Texture2D
static var _range_picker_texture: Texture2D
static var _grab_texture: Texture2D
static var _arrow_hotspot := Vector2.ZERO
static var _hand_hotspot := Vector2.ZERO
static var _range_picker_hotspot := Vector2.ZERO
static var _grab_hotspot := Vector2.ZERO
static var _initialized := false
static var _bound := false
static var _pan_dragging := false
static var _harvest_view_ready: Callable = func(): return false
static var _applied_kind: StringName = &"arrow"
static var _game_state: Node
static var _viewport: Viewport
static var _tree: SceneTree
static var _deferred_refresh_pending := false


static func bind_gameplay(range_view: Node3D) -> void:
	_pan_dragging = false
	_viewport = range_view.get_viewport()
	_tree = range_view.get_tree()
	if range_view.has_method(&"is_harvest_view_ready"):
		_harvest_view_ready = range_view.is_harvest_view_ready
	_game_state = range_view.get_node_or_null("/root/GameState")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _bound:
		refresh()
		return
	_bound = true
	var event_bus: Node = range_view.get_node_or_null("/root/EventBus")
	if event_bus:
		if not event_bus.phase_changed.is_connected(_on_phase_changed):
			event_bus.phase_changed.connect(_on_phase_changed)
		if not event_bus.bucket_changed.is_connected(_on_bucket_changed):
			event_bus.bucket_changed.connect(_on_bucket_changed)
	var view_mode_controller := range_view.get_node_or_null("ViewModeController")
	if view_mode_controller and view_mode_controller.has_signal(&"view_mode_changed"):
		view_mode_controller.view_mode_changed.connect(func(_mode): refresh())
	refresh()


static func apply_default_cursors() -> void:
	refresh()


static func set_pan_dragging(active: bool) -> void:
	if _pan_dragging == active:
		return
	_pan_dragging = active
	## Arming grab must not run stale-clear in the same stack — headless tests and
	## same-frame camera arming never have the mouse button sampled as pressed.
	if _pan_dragging:
		_apply_grab()
		_sync_os_cursor_shape()
	else:
		refresh()


static func refresh() -> void:
	_clear_stale_pan_dragging()
	if _pan_dragging:
		_apply_grab()
	elif _is_collect_mode() and _harvest_view_ready.is_valid() and _harvest_view_ready.call():
		_apply_range_picker()
	else:
		_apply_arrow()
	_sync_os_cursor_shape()


static func _is_collect_mode() -> bool:
	return _game_state != null and _game_state.is_collect_mode()


static func debug_applied_kind() -> StringName:
	return _applied_kind


static func debug_pan_dragging() -> bool:
	return _pan_dragging


static func debug_set_harvest_view_ready(callable: Callable) -> void:
	_harvest_view_ready = callable


static func debug_set_viewport(viewport: Viewport) -> void:
	_viewport = viewport


static func mark_selectable(control: Control) -> void:
	control.mouse_default_cursor_shape = SELECTABLE_CURSOR_SHAPE


static func _on_phase_changed(_phase: String) -> void:
	## Phase swaps often hide/IGNORE hover targets mid-hover (bucket, Hit).
	## Clear pan and refresh now + next frame after Control cursor shapes settle.
	_pan_dragging = false
	_schedule_refresh()


static func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_schedule_refresh()


static func _schedule_refresh() -> void:
	refresh()
	if _tree == null or _deferred_refresh_pending:
		return
	_deferred_refresh_pending = true
	_tree.process_frame.connect(_on_deferred_refresh, CONNECT_ONE_SHOT)


static func _on_deferred_refresh() -> void:
	_deferred_refresh_pending = false
	refresh()


static func _clear_stale_pan_dragging() -> void:
	## Missed mouse-up (focus loss, handled input) can leave grab latched.
	if _pan_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pan_dragging = false


static func _sync_os_cursor_shape() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not _should_force_arrow_shape():
		return
	## Controls that flip to IGNORE/hide while hovered never emit mouse_exited,
	## so POINTING_HAND can stick over empty world. Force ARROW when nothing
	## interactive is actually requesting the hand.
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


static func _should_force_arrow_shape() -> bool:
	if _pan_dragging or _applied_kind == &"grab" or _applied_kind == &"range_picker":
		## These modes bind the same texture to ARROW + POINTING_HAND; keep OS
		## on ARROW so we don't latch the hand shape across mode changes.
		return true
	if _viewport == null or not is_instance_valid(_viewport):
		return true
	var hovered := _viewport.gui_get_hovered_control()
	if hovered == null or not is_instance_valid(hovered):
		return true
	if not hovered.visible or not hovered.is_visible_in_tree():
		return true
	if hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return true
	return hovered.mouse_default_cursor_shape == Control.CURSOR_ARROW


static func _apply_arrow() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_arrow_texture, Input.CURSOR_ARROW, _arrow_hotspot)
	Input.set_custom_mouse_cursor(_hand_texture, Input.CURSOR_POINTING_HAND, _hand_hotspot)
	_applied_kind = &"arrow"


static func _apply_range_picker() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_range_picker_texture, Input.CURSOR_ARROW, _range_picker_hotspot)
	Input.set_custom_mouse_cursor(_range_picker_texture, Input.CURSOR_POINTING_HAND, _range_picker_hotspot)
	_applied_kind = &"range_picker"


static func _apply_grab() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_grab_texture, Input.CURSOR_ARROW, _grab_hotspot)
	Input.set_custom_mouse_cursor(_grab_texture, Input.CURSOR_POINTING_HAND, _grab_hotspot)
	_applied_kind = &"grab"


static func _ensure_loaded() -> void:
	if _initialized:
		return
	var arrow := _load_cursor(CURSOR_ARROW_PATH)
	_arrow_texture = arrow["texture"]
	_arrow_hotspot = arrow["hotspot"]
	var hand := _load_cursor(CURSOR_HAND_PATH)
	_hand_texture = hand["texture"]
	_hand_hotspot = hand["hotspot"]
	var range_picker := _load_cursor(CURSOR_RANGE_PICKER_PATH)
	_range_picker_texture = range_picker["texture"]
	_range_picker_hotspot = range_picker["hotspot"]
	var grab := _load_cursor(CURSOR_GRAB_PATH)
	_grab_texture = grab["texture"]
	_grab_hotspot = grab["hotspot"]
	_initialized = true


static func _load_cursor(path: String) -> Dictionary:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_error("CursorManager: failed to load %s" % path)
		return {"texture": ImageTexture.new(), "hotspot": Vector2.ZERO}
	var image := texture.get_image()
	var hotspot := _hotspot_for(image)
	return {"texture": texture, "hotspot": hotspot}


static func _hotspot_for(image: Image) -> Vector2:
	var opaque := _opaque_bounds(image)
	if opaque.size == Vector2.ZERO:
		return Vector2.ZERO
	return opaque.position


static func _opaque_bounds(image: Image) -> Rect2:
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
