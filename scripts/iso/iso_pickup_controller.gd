class_name IsoPickupController
extends Node
## DEPRECATED for player harvest — live pickup is PickupController on RangeView.
## Kept for verify_iso_view when IsoView.Mode.HARVEST is forced on.
## IsoView harvest picker — click fairway to collect litter (closest in radius).

var _iso_view: Node2D
var _litter_root: Node2D
var _fx_root: Node2D
var _bucket_counter: Control
var _camera: Camera2D
var _active := false
var _combo := 1
var _best_combo := 1
var _last_collect_msec := -999999
var _ball_tex: Texture2D


func setup(
	iso_view: Node2D,
	litter_root: Node2D,
	fx_root: Node2D,
	camera: Camera2D,
	bucket_counter: Control
) -> void:
	_iso_view = iso_view
	_litter_root = litter_root
	_fx_root = fx_root
	_camera = camera
	_bucket_counter = bucket_counter
	_ball_tex = DinkySpriteFrames.ball_lay_texture()
	var bus := _event_bus()
	if bus != null and not bus.phase_changed.is_connected(_on_phase_changed):
		bus.phase_changed.connect(_on_phase_changed)
	_bind_bucket_counter_click()


func _event_bus() -> Node:
	return get_tree().root.get_node_or_null("EventBus")


func _game_state() -> Node:
	return get_tree().root.get_node_or_null("GameState")


func _sfx() -> Node:
	return get_tree().root.get_node_or_null("SfxManager")


func is_active() -> bool:
	var gs := _game_state()
	return (
		_active
		and gs != null
		and gs.is_collect_mode()
		and _iso_view != null
		and _iso_view.has_method(&"is_harvest_view_ready")
		and _iso_view.is_harvest_view_ready()
	)


func handle_input(event: InputEvent) -> bool:
	if not is_active():
		return false
	if not event is InputEventMouseButton:
		return false
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return false
	return _try_collect_at(click.position)


func reset_combo() -> void:
	_combo = 1
	_best_combo = 1
	_last_collect_msec = -999999


func try_complete_harvest() -> void:
	var gs := _game_state()
	if gs != null and gs.is_harvest_complete():
		_finish_harvest()


func return_all_litter_free() -> bool:
	var gs := _game_state()
	if gs == null or not gs.is_collect_mode():
		return false
	## 3D harvest (verify / tooling) is owned by PickupController.
	if not is_active():
		return false
	_clear_all_litter()
	var range_view := _range_view()
	if range_view != null and range_view.has_method("discard_active_flights"):
		range_view.discard_active_flights()
	gs.return_all_balls_free()
	var sfx := _sfx()
	if sfx != null:
		sfx.play_bucket_full_chime()
	_return_to_strike()
	return true


func get_bucket_target_screen() -> Vector2:
	if _bucket_counter == null:
		return Vector2(440.0, 250.0)
	if _bucket_counter.has_method("get_tween_target_global"):
		return _bucket_counter.get_tween_target_global()
	return _bucket_counter.get_global_rect().get_center()


func picker_radius_yards() -> float:
	var gs := _game_state()
	var stats = gs.stats if gs != null else null
	return (
		Balance.range_picker_radius_yards(stats)
		if stats != null
		else Balance.RANGE_PICKER_BASE_RADIUS_YARDS
	)


## Viewport/canvas semi-axes of the dashed picker ellipse (matches IsoPickerIndicator).
func picker_radii_screen() -> Vector2:
	var radii_iso := IsoGrid.iso_px_radii_from_yards(picker_radius_yards())
	if _camera == null:
		return radii_iso
	var zoom_x: float = maxf(_camera.zoom.x, 0.001)
	return radii_iso * zoom_x


## Ellipse center from cursor tip — tip sits on the bottom rim.
func picker_center_from_tip_screen(tip_screen: Vector2) -> Vector2:
	var radii := picker_radii_screen()
	return tip_screen + Vector2(0.0, -radii.y)


## CanvasLayer / viewport position for the dashed ellipse (matches tip-on-rim).
func picker_center_screen() -> Vector2:
	return picker_center_from_tip_screen(get_viewport().get_mouse_position())


## Iso-local center of the ground pick circle (same tip-on-bottom-rim offset).
func picker_center_iso() -> Vector2:
	if _camera == null or _iso_view == null:
		return Vector2.ZERO
	var mouse_iso := _iso_view.to_local(_camera.get_global_mouse_position())
	var radii := IsoGrid.iso_px_radii_from_yards(picker_radius_yards())
	return mouse_iso + Vector2(0.0, -radii.y)


func _on_phase_changed(phase: String) -> void:
	_active = phase == "harvest"
	if _active:
		reset_combo()
		_mark_all_collectible()
	_bind_bucket_counter_click()


func _try_collect_at(screen_pos: Vector2) -> bool:
	var litter := _pick_litter_at(screen_pos)
	if litter == null:
		return false
	_collect_litter(litter)
	return true


## Screen-space ellipse test matching the drawn ring (WYSIWYG). Ball visual
## radius is padded in so a ball that looks inside the ellipse counts.
func _pick_litter_at(tip_screen: Vector2) -> Sprite2D:
	if _litter_root == null:
		return null
	var radii := picker_radii_screen()
	if radii.x < 0.5 or radii.y < 0.5:
		return null
	var center := picker_center_from_tip_screen(tip_screen)
	var best: Sprite2D = null
	var best_norm_sq := INF
	for child in _litter_root.get_children():
		if not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if not sprite.get_meta("collectible", false):
			continue
		var ball_screen := sprite.get_global_transform_with_canvas().origin
		var pad := _ball_screen_radius(sprite)
		var rx := radii.x + pad
		var ry := radii.y + pad
		if rx < 0.001 or ry < 0.001:
			continue
		var d := ball_screen - center
		var norm_sq := (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry)
		if norm_sq > 1.0:
			continue
		if norm_sq < best_norm_sq:
			best_norm_sq = norm_sq
			best = sprite
	return best


func _ball_screen_radius(sprite: Sprite2D) -> float:
	if _ball_tex == null or not is_instance_valid(sprite):
		return 0.0
	var canvas_scale := sprite.get_global_transform_with_canvas().get_scale()
	var half_w := 0.5 * float(_ball_tex.get_width()) * absf(canvas_scale.x)
	var half_h := 0.5 * float(_ball_tex.get_height()) * absf(canvas_scale.y)
	return minf(half_w, half_h)


func _collect_litter(litter: Sprite2D) -> void:
	if not is_instance_valid(litter):
		return
	var gs := _game_state()
	if gs == null:
		return
	litter.set_meta("collectible", false)
	var world_pos: Vector3 = litter.get_meta("world_pos", Vector3.ZERO)
	var litter_id: int = int(litter.get_meta("litter_id", -1))
	var quality: int = int(litter.get_meta("ball_quality", 1))
	var yardage: float = float(litter.get_meta("ball_yardage", gs.stats.base_yards))
	var is_golden: bool = bool(litter.get_meta("ball_golden", false))
	var source: String = str(litter.get_meta("ball_source", "player"))
	var start_screen := get_viewport().get_mouse_position()
	litter.queue_free()
	var bus := _event_bus()
	if bus != null:
		bus.litter_removed.emit(litter_id)

	var combo_tier := _advance_combo()
	var payout: float = gs.collect_harvest_ball(
		world_pos, combo_tier, quality, yardage, is_golden, source
	)
	var sfx := _sfx()
	if sfx != null:
		sfx.play_pickup_plink(combo_tier)
	_show_cash_float(start_screen, payout, combo_tier, is_golden)
	if payout > 0.0 and source != "ratina" and bus != null:
		bus.pickup_payout.emit(payout, combo_tier)
	_fly_to_bucket(start_screen)
	if gs.is_harvest_complete():
		_finish_harvest()


func _advance_combo() -> int:
	var gs := _game_state()
	var now := Time.get_ticks_msec()
	var window_ms := 800
	if gs != null:
		window_ms = int(Economy.combo_window_sec(gs.stats) * 1000.0)
	if now - _last_collect_msec <= window_ms:
		_combo += 1
	else:
		_combo = 1
	_last_collect_msec = now
	_best_combo = maxi(_best_combo, _combo)
	return _combo


func _show_cash_float(screen_pos: Vector2, payout: float, combo_tier: int, is_golden: bool) -> void:
	if _fx_root == null:
		return
	var text_color := Balance.GOLDEN_BALL_TINT if is_golden else Color.TRANSPARENT
	FloatCashText.spawn(_fx_root, screen_pos, payout, combo_tier, 4, 1.0, text_color)


func _fly_to_bucket(start_screen: Vector2) -> void:
	if _fx_root == null or _ball_tex == null:
		return
	var end_screen := get_bucket_target_screen()
	var icon := Sprite2D.new()
	icon.texture = _ball_tex
	icon.position = start_screen
	icon.scale = Vector2(0.5, 0.5)
	_fx_root.add_child(icon)
	var mid := (start_screen + end_screen) * 0.5 + Vector2(0.0, -36.0)
	var tween := icon.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(_fly_icon_step.bind(icon, start_screen, mid, end_screen), 0.0, 1.0, 0.28)
	tween.tween_callback(icon.queue_free)


func _fly_icon_step(
	t: float, icon: Sprite2D, start_screen: Vector2, mid: Vector2, end_screen: Vector2
) -> void:
	if not is_instance_valid(icon):
		return
	var u := 1.0 - t
	icon.position = u * u * start_screen + 2.0 * u * t * mid + t * t * end_screen


func _finish_harvest() -> void:
	var gs := _game_state()
	if gs == null:
		return
	var bonus: float = gs.complete_harvest(_best_combo)
	var bus := _event_bus()
	if bonus > 0.0 and bus != null:
		bus.pickup_payout.emit(bonus, 0)
	var sfx := _sfx()
	if sfx != null:
		sfx.play_bucket_full_chime()
	_clear_all_litter()
	_return_to_strike()


func _return_to_strike() -> void:
	var range_view := _range_view()
	if range_view != null and range_view.has_method("on_harvest_complete"):
		range_view.on_harvest_complete()


func _clear_all_litter() -> void:
	var bus := _event_bus()
	if bus != null:
		bus.litter_cleared.emit()


func _mark_all_collectible() -> void:
	if _litter_root == null:
		return
	for child in _litter_root.get_children():
		if child is Sprite2D:
			child.set_meta("collectible", true)


func _range_view() -> Node:
	var main := get_tree().get_first_node_in_group(&"main")
	if main != null:
		return main.get_node_or_null("RangeView")
	return get_tree().get_first_node_in_group(&"range_view")


func _bind_bucket_counter_click() -> void:
	if _bucket_counter == null:
		return
	if not _bucket_counter.has_signal("ball_return_pressed"):
		return
	if _bucket_counter.ball_return_pressed.is_connected(_on_bucket_ball_return):
		return
	_bucket_counter.ball_return_pressed.connect(_on_bucket_ball_return)


func _on_bucket_ball_return() -> void:
	return_all_litter_free()
