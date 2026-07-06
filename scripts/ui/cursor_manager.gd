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


static func bind_gameplay(range_view: Node3D) -> void:
	_pan_dragging = false
	if range_view.has_method(&"is_harvest_view_ready"):
		_harvest_view_ready = range_view.is_harvest_view_ready
	_game_state = range_view.get_node_or_null("/root/GameState")
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
	refresh()


static func refresh() -> void:
	if _pan_dragging:
		_apply_grab()
	elif _is_collect_mode() and _harvest_view_ready.is_valid() and _harvest_view_ready.call():
		_apply_range_picker()
	else:
		_apply_arrow()


static func _is_collect_mode() -> bool:
	return _game_state != null and _game_state.is_collect_mode()


static func debug_applied_kind() -> StringName:
	return _applied_kind


static func debug_set_harvest_view_ready(callable: Callable) -> void:
	_harvest_view_ready = callable


static func mark_selectable(control: Control) -> void:
	control.mouse_default_cursor_shape = SELECTABLE_CURSOR_SHAPE


static func _on_phase_changed(_phase: String) -> void:
	refresh()


static func _on_bucket_changed(_count: int, _capacity: int) -> void:
	refresh()


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
