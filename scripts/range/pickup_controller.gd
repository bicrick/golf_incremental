class_name PickupController
extends Node
## Harvest-phase range picker — click on the fairway to collect one litter ball
## inside the picker circle (closest to circle center wins). Fly-to-bucket juice
## stays 2D screen-space (owned by RangeView).

var _range_view: Node3D
var _littered_balls: Node3D
var _bucket_counter: Control
var _active := false
var _combo := 1
var _best_combo := 1
var _last_collect_msec := -999999


func setup(range_view: Node3D, littered_balls: Node3D, bucket_counter: Control) -> void:
	_range_view = range_view
	_littered_balls = littered_balls
	_bucket_counter = bucket_counter
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)


func is_active() -> bool:
	return _active and GameState.is_collect_mode() and _harvest_view_ready()


func _harvest_view_ready() -> bool:
	if _range_view == null:
		return false
	if _range_view.has_method("is_harvest_view_ready"):
		return _range_view.is_harvest_view_ready()
	return _active


func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if not event is InputEventMouseButton:
		return false
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or click.pressed:
		return false
	return _try_collect_at(click.position)


func reset_combo() -> void:
	_combo = 1
	_best_combo = 1
	_last_collect_msec = -999999


func _interrupt_combo() -> void:
	_combo = 1
	_last_collect_msec = -999999


func get_bucket_target_screen() -> Vector2:
	return _bucket_target_screen()


func try_complete_harvest() -> void:
	if GameState.is_harvest_complete():
		_finish_harvest()


func _on_phase_changed(phase: String) -> void:
	_active = phase == "harvest"
	if _active:
		reset_combo()
		_mark_all_litter_collectible()


func _on_swing_resolved(_yards: float, _tier: int, _payout: float, _feedback: int) -> void:
	_interrupt_combo()


func _camera() -> Camera3D:
	if _range_view and _range_view.has_method(&"get_flight_camera"):
		return _range_view.get_flight_camera()
	return null


func _try_collect_at(screen_pos: Vector2) -> bool:
	var litter: Sprite3D = _pick_litter_at(screen_pos)
	if litter == null:
		return false
	_collect_litter(litter)
	return true


func _pick_litter_at(screen_pos: Vector2) -> Sprite3D:
	if _littered_balls == null:
		return null
	var camera := _camera()
	if camera == null:
		return null
	var hit: Variant = RangeGroundRay.hit(camera, screen_pos)
	if hit == null:
		return null
	var pick_ground: Vector3 = hit
	var pick_xz := Vector2(pick_ground.x, pick_ground.z)
	var world_radius := Balance.range_picker_radius_yards(GameState.stats)
	var hit_radius := world_radius + Balance.RANGE_PICKER_HIT_SLACK_YARDS
	var best: Sprite3D = null
	var best_dist := INF
	for child in _littered_balls.get_children():
		if not child is Sprite3D:
			continue
		if not child.get_meta("collectible", false):
			continue
		var sprite := child as Sprite3D
		if camera.is_position_behind(sprite.global_position):
			continue
		var ball_xz := RangePickerIndicator.litter_ground_xz(sprite)
		var world_dist := ball_xz.distance_to(pick_xz)
		var ball_ground := Vector3(sprite.global_position.x, 0.0, sprite.global_position.z)
		var ball_screen := camera.unproject_position(sprite.global_position)
		var screen_radius := RangePickerIndicator.screen_radius_px(
			camera, ball_ground, hit_radius
		)
		var screen_dist := screen_pos.distance_to(ball_screen)
		var in_world := world_dist <= hit_radius
		var in_screen := screen_dist <= screen_radius
		if not in_world and not in_screen:
			continue
		var dist := world_dist if in_world else screen_dist
		if dist < best_dist:
			best_dist = dist
			best = sprite
	return best


func _collect_litter(litter: Sprite3D) -> void:
	if not is_instance_valid(litter):
		return
	litter.set_meta("collectible", false)
	var world_pos := litter.global_position
	var camera := _camera()
	var start_screen := camera.unproject_position(world_pos) if camera else Vector2.ZERO
	litter.queue_free()

	var combo_tier := _advance_combo()
	var quality: int = litter.get_meta("ball_quality", 1)
	var yardage: float = litter.get_meta("ball_yardage", GameState.stats.base_yards)
	var is_golden: bool = litter.get_meta("ball_golden", false)
	var source: String = litter.get_meta("ball_source", "player")
	var payout := GameState.collect_harvest_ball(
		world_pos, combo_tier, quality, yardage, is_golden, source
	)
	SfxManager.play_pickup_plink(combo_tier)
	if _range_view.has_method("show_pickup_cash_float"):
		_range_view.show_pickup_cash_float(world_pos, payout, combo_tier, is_golden)
	# Ratina harvest emits ratina_ball_collected; avoid double HUD stack rows.
	if payout > 0.0 and source != "ratina":
		EventBus.pickup_payout.emit(payout, combo_tier)
	_fly_to_bucket(start_screen)
	if GameState.is_harvest_complete():
		_finish_harvest()


func _advance_combo() -> int:
	var now := Time.get_ticks_msec()
	if now - _last_collect_msec <= int(Economy.combo_window_sec(GameState.stats) * 1000.0):
		_combo += 1
	else:
		_combo = 1
	_last_collect_msec = now
	_best_combo = maxi(_best_combo, _combo)
	return _combo


func _bucket_target_screen() -> Vector2:
	if _bucket_counter == null:
		return Vector2(440.0, 250.0)
	if _bucket_counter.has_method("get_tween_target_global"):
		return _bucket_counter.get_tween_target_global()
	return _bucket_counter.get_global_rect().get_center()


func _fly_to_bucket(start_screen: Vector2) -> void:
	var end_screen := _bucket_target_screen()
	if _range_view.has_method("spawn_pickup_fly_icon"):
		_range_view.spawn_pickup_fly_icon(start_screen, end_screen)


func _finish_harvest() -> void:
	var bonus := GameState.complete_harvest(_best_combo)
	if bonus > 0.0:
		EventBus.pickup_payout.emit(bonus, 0)
	SfxManager.play_bucket_full_chime()
	_clear_litter()
	_return_to_strike()


func _return_to_strike() -> void:
	if _range_view.has_method("on_harvest_complete"):
		_range_view.on_harvest_complete()


func _mark_all_litter_collectible() -> void:
	if _littered_balls == null:
		return
	for child in _littered_balls.get_children():
		if child is Sprite3D:
			child.set_meta("collectible", true)


func _clear_litter() -> void:
	if _littered_balls == null:
		return
	for child in _littered_balls.get_children():
		child.queue_free()
