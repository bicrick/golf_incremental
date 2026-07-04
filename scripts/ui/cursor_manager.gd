class_name CursorManager
extends RefCounted
## Custom pixel cursors — default pointer, button hover, and harvest grab.

const CURSOR_ARROW_PATH := "res://assets/cursors/cursor_arrow.png"
const CURSOR_HAND_PATH := "res://assets/cursors/cursor_hand.png"
const CURSOR_GRAB_PATH := "res://assets/cursors/cursor_grab.png"

## Cursor shape every selectable/clickable Control should request via
## `mouse_default_cursor_shape` so hovering shows the hand cursor instead of
## silently falling back to the CURSOR_ARROW shape. During collect mode the
## default pointer is the open hand; pan drag temporarily switches to grab.
const SELECTABLE_CURSOR_SHAPE := Control.CURSOR_POINTING_HAND

static var _arrow_texture: Texture2D
static var _hand_texture: Texture2D
static var _grab_texture: Texture2D
static var _arrow_hotspot := Vector2.ZERO
static var _hand_hotspot := Vector2.ZERO
static var _grab_hotspot := Vector2.ZERO
static var _initialized := false


static func apply_default_cursors() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_arrow_texture, Input.CURSOR_ARROW, _arrow_hotspot)
	Input.set_custom_mouse_cursor(_hand_texture, Input.CURSOR_POINTING_HAND, _hand_hotspot)


static func set_hand_cursor() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_hand_texture, Input.CURSOR_ARROW, _hand_hotspot)
	Input.set_custom_mouse_cursor(_hand_texture, Input.CURSOR_POINTING_HAND, _hand_hotspot)


static func set_grab_cursor() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_grab_texture, Input.CURSOR_ARROW, _grab_hotspot)
	# Selectable UI controls request CURSOR_POINTING_HAND — rebind it too so
	# pan drag always shows the grabbing glove, not the open hand.
	Input.set_custom_mouse_cursor(_grab_texture, Input.CURSOR_POINTING_HAND, _grab_hotspot)


static func clear_grab_cursor() -> void:
	_ensure_loaded()
	Input.set_custom_mouse_cursor(_arrow_texture, Input.CURSOR_ARROW, _arrow_hotspot)
	Input.set_custom_mouse_cursor(_hand_texture, Input.CURSOR_POINTING_HAND, _hand_hotspot)


static func sync_collect_cursor() -> void:
	if GameState.is_collect_mode():
		set_hand_cursor()
	else:
		clear_grab_cursor()


## Marks a Control as selectable so hovering it shows the hand cursor.
## Use for controls built at runtime; static scene Buttons should instead set
## mouse_default_cursor_shape = 2 (Control.CURSOR_POINTING_HAND) directly in
## the .tscn file.
static func mark_selectable(control: Control) -> void:
	control.mouse_default_cursor_shape = SELECTABLE_CURSOR_SHAPE


static func _ensure_loaded() -> void:
	if _initialized:
		return
	var arrow := _load_cursor(CURSOR_ARROW_PATH)
	_arrow_texture = arrow["texture"]
	_arrow_hotspot = arrow["hotspot"]
	var hand := _load_cursor(CURSOR_HAND_PATH)
	_hand_texture = hand["texture"]
	_hand_hotspot = hand["hotspot"]
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
	# Top-left of visible art — natural tip for arrow / top of palm for hands.
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
