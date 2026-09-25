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
	_bind_bucket_counter_click()


func is_active() -> bool:
	## Ready when 3D ortho has settled. Iso harvest ready is unused player-path
	## leftover (verify_iso_view can still enable IsoView.Mode.HARVEST).
	return _active and GameState.is_collect_mode() and _harvest_view_ready()


func _harvest_view_ready() -> bool:
	if _iso_harvest_ready():
		return true
	if _range_view == null:
		return false
	if _range_view.has_method("is_harvest_view_ready"):
		return _range_view.is_harvest_view_ready()
	return _active


func _iso_harvest_ready() -> bool:
	var iso := get_tree().get_first_node_in_group(&"iso_view")
	if iso == null or not iso.has_method(&"is_harvest_view_ready"):
		return false
	return iso.is_harvest_view_ready()


func handle_input(event: InputEvent) -> bool:
	## Pickup only after harvest settle — phase alone is not enough.
	## Player harvest clicks stay on this 3D path (RangeView ortho).
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


func _interrupt_combo() -> void:
	_combo = 1
	_last_collect_msec = -999999


func get_bucket_target_screen() -> Vector2:
	return _bucket_target_screen()


func try_complete_harvest() -> void:
	if GameState.is_harvest_complete():
		_finish_harvest()


## Return every missing ball for free (litter, vanished, despawned), clear the
## fairway, discard unresolved flights, and restore a full bucket.
func return_all_litter_free() -> bool:
	if not GameState.is_collect_mode():
		return false
	## Iso pickup owns the bucket only if IsoView harvest is forced on (verify).
	if _iso_harvest_ready():
		return false
	## Rattlings on the crew: leave the stragglers for them (paid at their share).
	if GameState.rattlings_unlocked and GameState.rattlings_active:
		RattlingController.mark_leftovers(_littered_balls, true)
	else:
		_clear_litter()
	if _range_view != null and _range_view.has_method("discard_active_flights"):
		_range_view.discard_active_flights()
	GameState.return_all_balls_free()
	SfxManager.play_bucket_full_chime()
	_return_to_strike()
	return true


func _on_phase_changed(phase: String) -> void:
	_active = phase == "harvest"
	if _active:
		reset_combo()
		_mark_all_litter_collectible()
	_bind_bucket_counter_click()


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
	var world_radius := Balance.range_picker_radius_yards(GameState.stats)
	var hit: Variant = RangePickerIndicator.picker_ground_at_cursor(
		camera, screen_pos, world_radius
	)
	if hit == null:
		return null
	var pick_ground: Vector3 = hit
	var pick_xz := Vector2(pick_ground.x, pick_ground.z)
	var hit_radius := world_radius + Balance.RANGE_PICKER_HIT_SLACK_YARDS
	var center_screen := camera.unproject_position(pick_ground)
	var ring_screen_r := RangePickerIndicator.screen_radius_px(
		camera, pick_ground, world_radius
	)
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
		var ball_ground := Vector3(ball_xz.x, 0.0, ball_xz.y)
		var ball_screen := camera.unproject_position(ball_ground)
		var screen_dist := center_screen.distance_to(ball_screen)
		## Accept world-circle OR screen-ring around the same offset center (not tip).
		var in_world := world_dist <= hit_radius
		var in_screen := screen_dist <= ring_screen_r + 4.0
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
	var litter_id: int = int(litter.get_meta("litter_id", -1))
	var quality: int = litter.get_meta("ball_quality", 1)
	var yardage: float = litter.get_meta("ball_yardage", GameState.stats.base_yards)
	var is_golden: bool = litter.get_meta("ball_golden", false)
	var source: String = litter.get_meta("ball_source", "player")
	var already_credited: bool = litter.get_meta("leftover_credited", false)
	litter.queue_free()
	if litter_id >= 0:
		EventBus.litter_removed.emit(litter_id)

	var combo_tier := _advance_combo()
	var payout := 0.0
	if already_credited:
		## Straggler the bucket already got back for free — pay, don't recount.
		payout = GameState.collect_uncounted_ball(quality, yardage, combo_tier, is_golden)
	else:
		payout = GameState.collect_harvest_ball(
			world_pos, combo_tier, quality, yardage, is_golden, source
		)
	SfxManager.play_pickup_plink(combo_tier)
	if _range_view.has_method("show_pickup_cash_float"):
		_range_view.show_pickup_cash_float(world_pos, payout, combo_tier, is_golden)
	if payout > 0.0:
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
	EventBus.litter_cleared.emit()


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
