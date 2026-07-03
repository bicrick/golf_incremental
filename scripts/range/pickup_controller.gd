class_name PickupController
extends Node
## Harvest-phase click pickup — litter lives in real 3D world space; hit
## testing projects each litter's world position to screen space via the
## range camera. The "fly to bucket" juice stays a 2D screen-space icon
## (owned by RangeView) since the bucket counter is UI.

const MIN_HIT_RADIUS_PX := 24.0

var _range_view: Node3D
var _littered_balls: Node3D
var _bucket_counter: Control
var _active := false
var _combo := 1
var _best_combo := 1
var _last_collect_msec := -999999
var _collecting := false


func setup(range_view: Node3D, littered_balls: Node3D, bucket_counter: Control) -> void:
	_range_view = range_view
	_littered_balls = littered_balls
	_bucket_counter = bucket_counter
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.bucket_changed.connect(_on_bucket_changed)
	EventBus.swing_resolved.connect(_on_swing_resolved)
	_sync_collect_cursor()


func is_active() -> bool:
	return _active and GameState.is_collect_mode()


func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if _collecting:
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
	if _collecting:
		return
	if GameState.is_harvest_complete():
		_finish_harvest()


func _on_phase_changed(phase: String) -> void:
	_active = phase == "harvest"
	if _active:
		reset_combo()
		_mark_all_litter_collectible()
	_sync_collect_cursor()


func _on_bucket_changed(_count: int, _capacity: int) -> void:
	_sync_collect_cursor()


func _sync_collect_cursor() -> void:
	CursorManager.sync_collect_cursor()


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
	var candidates: Array[Dictionary] = []
	for child in _littered_balls.get_children():
		if not child is Sprite3D:
			continue
		if not child.get_meta("collectible", false):
			continue
		var sprite := child as Sprite3D
		if camera.is_position_behind(sprite.global_position):
			continue
		var proj := camera.unproject_position(sprite.global_position)
		var dist := screen_pos.distance_to(proj)
		var hit_radius := _hit_radius_for(sprite, camera)
		if dist > hit_radius:
			continue
		candidates.append({
			"sprite": sprite,
			"dist": dist,
			"depth": camera.global_position.distance_squared_to(sprite.global_position),
		})
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["depth"]) - float(b["depth"])) > 0.0001:
			return a["depth"] < b["depth"]
		return a["dist"] < b["dist"]
	)
	return candidates[0]["sprite"] as Sprite3D


## Hit radius in screen pixels — projects a world-space offset near the
## sprite to measure how big it currently reads on screen at this depth.
func _hit_radius_for(sprite: Sprite3D, camera: Camera3D) -> float:
	var world_radius := 0.16
	if sprite.texture:
		world_radius = maxf(sprite.texture.get_size().x, sprite.texture.get_size().y) \
			* sprite.pixel_size * 0.5
	var center := camera.unproject_position(sprite.global_position)
	var edge := camera.unproject_position(
		sprite.global_position + camera.global_transform.basis.x * world_radius
	)
	return maxf(MIN_HIT_RADIUS_PX, center.distance_to(edge))


func _collect_litter(litter: Sprite3D) -> void:
	if not is_instance_valid(litter):
		return
	_collecting = true
	litter.set_meta("collectible", false)
	var world_pos := litter.global_position
	var camera := _camera()
	var start_screen := camera.unproject_position(world_pos) if camera else Vector2.ZERO
	litter.queue_free()

	var combo_tier := _advance_combo()
	var quality: int = litter.get_meta("ball_quality", 1)
	var yardage: float = litter.get_meta("ball_yardage", GameState.stats.base_yards)
	var is_golden: bool = litter.get_meta("ball_golden", false)
	var payout := GameState.collect_harvest_ball(
		world_pos, combo_tier, quality, yardage, is_golden
	)
	SfxManager.play_pickup_plink(combo_tier)
	if _range_view.has_method("show_pickup_cash_float"):
		_range_view.show_pickup_cash_float(world_pos, payout, combo_tier)
	if payout > 0.0:
		EventBus.pickup_payout.emit(payout, combo_tier)
	_fly_to_bucket(start_screen)


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
		await _range_view.spawn_pickup_fly_icon(start_screen, end_screen)
	_collecting = false
	if GameState.is_harvest_complete():
		_finish_harvest()


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
