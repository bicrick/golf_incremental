class_name PlacementDebug
extends Node
## Runtime-only golfer/ball placement tuner for the driving range view.

signal mode_changed(active: bool)

const MOVE_STEP_PX := 1.0
const MOVE_FAST_PX_PER_SEC := 120.0
const MOVE_FAST_DELAY_SEC := 0.35
const SCALE_STEP := 0.05
const SCALE_MIN := 0.25
const SCALE_MAX := 4.0
const PICK_GOLFER_RADIUS := 48.0
const PICK_BALL_RADIUS := 20.0
const OVERLAY_FONT_SIZE := 8

var _enabled := false
var _active := false
var _golfer: AnimatedSprite2D
var _ball: AnimatedSprite2D
var _foreground: Node2D
var _on_positions_changed: Callable
var _on_scales_changed: Callable
var _golfer_home_start: Vector2
var _ball_home_start: Vector2
var _golfer_scale_start: Vector2
var _ball_scale_start: Vector2

var _canvas: CanvasLayer
var _title_label: Label
var _info_label: Label
var _help_label: Label
var _copy_button: Button
var _status_label: Label

var _drag_target := ""
var _key_hold_time := 0.0


func _ready() -> void:
	_enabled = OS.is_debug_build() or Engine.is_editor_hint()
	if not _enabled:
		set_process(false)
		return
	_build_overlay()
	set_process(_enabled)
	set_process_input(_enabled)


func setup(
	golfer: AnimatedSprite2D,
	ball: AnimatedSprite2D,
	foreground: Node2D,
	golfer_home: Vector2,
	ball_home: Vector2,
	golfer_scale: Vector2,
	ball_scale: Vector2,
	on_positions_changed: Callable,
	on_scales_changed: Callable
) -> void:
	_golfer = golfer
	_ball = ball
	_foreground = foreground
	_golfer_home_start = golfer_home
	_ball_home_start = ball_home
	_golfer_scale_start = golfer_scale
	_ball_scale_start = ball_scale
	_on_positions_changed = on_positions_changed
	_on_scales_changed = on_scales_changed
	_refresh_overlay()


func is_active() -> bool:
	return _enabled and _active


func _build_overlay() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	_canvas.visible = false
	add_child(_canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.05, 0.88)
	panel_style.border_color = Color(0.45, 0.95, 0.45, 0.95)
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override(&"panel", panel_style)
	_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 4)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "DEBUG PLACE"
	PixelFont.apply_label(_title_label, OVERLAY_FONT_SIZE)
	_title_label.modulate = Color(0.55, 1.0, 0.55, 1.0)
	vbox.add_child(_title_label)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	PixelFont.apply_label(_info_label, OVERLAY_FONT_SIZE)
	vbox.add_child(_info_label)

	_help_label = Label.new()
	_help_label.text = "P toggle | Arrows rat | Shift+arrows ball | [ ] rat scale | , . ball scale | Drag | C copy"
	PixelFont.apply_label(_help_label, 6)
	_help_label.modulate = Color(0.75, 0.85, 0.75, 1.0)
	vbox.add_child(_help_label)

	_copy_button = Button.new()
	_copy_button.text = "Copy positions"
	_copy_button.custom_minimum_size = Vector2(140, 18)
	_copy_button.pressed.connect(_copy_positions)
	_copy_button.add_theme_font_override(&"font", PixelFont.font_for_size(OVERLAY_FONT_SIZE))
	vbox.add_child(_copy_button)

	_status_label = Label.new()
	_status_label.visible = false
	PixelFont.apply_label(_status_label, 6)
	_status_label.modulate = Color(0.55, 1.0, 0.55, 1.0)
	vbox.add_child(_status_label)


func _can_use() -> bool:
	var parent_view := get_parent()
	return _enabled and parent_view != null and parent_view.visible


func _process(delta: float) -> void:
	if not is_active():
		return
	_apply_keyboard_movement(delta)
	_refresh_overlay()


func _input(event: InputEvent) -> void:
	if not _can_use():
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		if key.pressed and key.keycode == KEY_P:
			_toggle_active()
			get_viewport().set_input_as_handled()
			return
		if not _active:
			return
		if key.pressed and key.keycode == KEY_C:
			_copy_positions()
			get_viewport().set_input_as_handled()
			return
		if key.pressed:
			var scale_delta := 0.0
			match key.keycode:
				KEY_BRACKETLEFT:
					scale_delta = -SCALE_STEP
					_adjust_scale("golfer", scale_delta)
					get_viewport().set_input_as_handled()
					return
				KEY_BRACKETRIGHT:
					scale_delta = SCALE_STEP
					_adjust_scale("golfer", scale_delta)
					get_viewport().set_input_as_handled()
					return
				KEY_COMMA:
					scale_delta = -SCALE_STEP
					_adjust_scale("ball", scale_delta)
					get_viewport().set_input_as_handled()
					return
				KEY_PERIOD:
					scale_delta = SCALE_STEP
					_adjust_scale("ball", scale_delta)
					get_viewport().set_input_as_handled()
					return

	if not _active:
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_drag_target = _pick_target(mouse.global_position)
				if not _drag_target.is_empty():
					get_viewport().set_input_as_handled()
			else:
				_drag_target = ""
	elif event is InputEventMouseMotion and not _drag_target.is_empty():
		_move_target(_drag_target, _mouse_to_foreground(event.global_position))
		get_viewport().set_input_as_handled()


func _toggle_active() -> void:
	_active = not _active
	_drag_target = ""
	_key_hold_time = 0.0
	if _canvas:
		_canvas.visible = _active
	if _active:
		_refresh_overlay()
		if _golfer:
			_golfer.play(&"idle")
	mode_changed.emit(_active)


func _apply_keyboard_movement(delta: float) -> void:
	var move_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1.0
	if move_dir == Vector2.ZERO:
		_key_hold_time = 0.0
		return

	_key_hold_time += delta
	var step := MOVE_STEP_PX
	if _key_hold_time >= MOVE_FAST_DELAY_SEC:
		step = MOVE_FAST_PX_PER_SEC * delta

	var target := "golfer"
	if Input.is_key_pressed(KEY_SHIFT):
		target = "ball"

	var pos := _target_position(target) + move_dir.normalized() * step
	_set_target_position(target, pos)


func _pick_target(global_pos: Vector2) -> String:
	if _golfer == null or _ball == null:
		return ""
	var golfer_dist := global_pos.distance_to(_golfer.global_position)
	var ball_dist := global_pos.distance_to(_ball.global_position)
	if golfer_dist <= PICK_GOLFER_RADIUS and golfer_dist <= ball_dist:
		return "golfer"
	if ball_dist <= PICK_BALL_RADIUS:
		return "ball"
	return ""


func _mouse_to_foreground(global_pos: Vector2) -> Vector2:
	if _foreground == null:
		return global_pos
	return _foreground.to_local(global_pos)


func _move_target(target: String, local_pos: Vector2) -> void:
	_set_target_position(target, local_pos)


func _target_position(target: String) -> Vector2:
	if target == "ball" and _ball:
		return _ball.position
	if _golfer:
		return _golfer.position
	return Vector2.ZERO


func _set_target_position(target: String, pos: Vector2) -> void:
	if target == "ball":
		if _ball:
			_ball.position = pos
	else:
		if _golfer:
			_golfer.position = pos
	_notify_positions_changed()


func _notify_positions_changed() -> void:
	if _on_positions_changed.is_valid():
		_on_positions_changed.call(_golfer.position, _ball.position)


func _adjust_scale(target: String, delta: float) -> void:
	var sprite: AnimatedSprite2D = _golfer if target == "golfer" else _ball
	if sprite == null:
		return
	var next := clampf(sprite.scale.x + delta, SCALE_MIN, SCALE_MAX)
	var uniform := Vector2(next, next)
	sprite.scale = uniform
	_notify_scales_changed()


func _notify_scales_changed() -> void:
	if _on_scales_changed.is_valid():
		_on_scales_changed.call(_golfer.scale, _ball.scale)


func _refresh_overlay() -> void:
	if _info_label == null or _golfer == null or _ball == null:
		return
	var golfer_pos := _golfer.position
	var ball_pos := _ball.position
	var lines: PackedStringArray = [
		"Golfer position = Vector2(%s, %s)" % [_fmt(golfer_pos.x), _fmt(golfer_pos.y)],
		"Ball position = Vector2(%s, %s)" % [_fmt(ball_pos.x), _fmt(ball_pos.y)],
		"Golfer scale = Vector2(%s, %s)" % [_fmt(_golfer.scale.x), _fmt(_golfer.scale.y)],
		"Ball scale = Vector2(%s, %s)" % [_fmt(_ball.scale.x), _fmt(_ball.scale.y)],
	]
	var golfer_delta := golfer_pos - _golfer_home_start
	if golfer_delta.length() >= 5.0:
		lines.append(
			"# Golfer moved %s px from session start" % _fmt(golfer_delta.length())
		)
	_info_label.text = "\n".join(lines)


func _fmt(value: float) -> String:
	if is_equal_approx(value, snapped(value, 1.0)):
		return str(int(snapped(value, 1.0)))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")


func _copy_positions() -> void:
	if _golfer == null or _ball == null:
		return
	var golfer_pos := _golfer.position
	var ball_pos := _ball.position
	var lines: PackedStringArray = [
		"Golfer position = Vector2(%s, %s)" % [_fmt(golfer_pos.x), _fmt(golfer_pos.y)],
		"Ball position = Vector2(%s, %s)" % [_fmt(ball_pos.x), _fmt(ball_pos.y)],
		"Golfer scale = Vector2(%s, %s)" % [_fmt(_golfer.scale.x), _fmt(_golfer.scale.y)],
		"Ball scale = Vector2(%s, %s)" % [_fmt(_ball.scale.x), _fmt(_ball.scale.y)],
	]
	var golfer_delta := golfer_pos - _golfer_home_start
	if golfer_delta.length() >= 5.0:
		lines.append("# Golfer delta from start: %s" % golfer_delta)
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print("[PlacementDebug]\n", text)
	if _status_label:
		_status_label.text = "Copied to clipboard"
		_status_label.visible = true
		var tween := create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(func(): _status_label.visible = false)
