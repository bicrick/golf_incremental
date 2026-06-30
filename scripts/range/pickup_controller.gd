class_name PickupController
extends Node
## Harvest-phase click pickup — litter collect, combo, tween to bucket UI.

const MIN_HIT_RADIUS_PX := 24.0
const ARC_HEIGHT_PX := 36.0
const TWEEN_DURATION_SEC := 0.35

var _range_view: Node2D
var _littered_balls: Node2D
var _bucket_counter: Control
var _active := false
var _combo := 1
var _best_combo := 1
var _last_collect_msec := -999999
var _collecting := false


func setup(range_view: Node2D, littered_balls: Node2D, bucket_counter: Control) -> void:
	_range_view = range_view
	_littered_balls = littered_balls
	_bucket_counter = bucket_counter
	EventBus.phase_changed.connect(_on_phase_changed)


func is_active() -> bool:
	return _active


func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_SPACE:
			_skip_harvest()
			return true
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


func _on_phase_changed(phase: String) -> void:
	_active = phase == "harvest"
	if _active:
		reset_combo()
		_mark_all_litter_collectible()


func _try_collect_at(screen_pos: Vector2) -> bool:
	var litter: Sprite2D = _pick_litter_at(screen_pos)
	if litter == null:
		return false
	_collect_litter(litter)
	return true


func _pick_litter_at(screen_pos: Vector2) -> Sprite2D:
	if _littered_balls == null:
		return null
	var canvas_xform := _range_view.get_canvas_transform()
	var world_click := canvas_xform.affine_inverse() * screen_pos
	var candidates: Array[Dictionary] = []
	for child in _littered_balls.get_children():
		if not child is Sprite2D:
			continue
		if not child.get_meta("collectible", false):
			continue
		var sprite := child as Sprite2D
		var dist := world_click.distance_to(sprite.global_position)
		var hit_radius := _hit_radius_for(sprite)
		if dist > hit_radius:
			continue
		candidates.append({
			"sprite": sprite,
			"dist": dist,
			"z": sprite.z_index,
		})
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["z"] != b["z"]:
			return a["z"] > b["z"]
		return a["dist"] < b["dist"]
	)
	return candidates[0]["sprite"] as Sprite2D


func _hit_radius_for(sprite: Sprite2D) -> float:
	var tex_size := Vector2(16.0, 16.0)
	if sprite.texture:
		tex_size = sprite.texture.get_size() * sprite.scale
	var sprite_radius := maxf(tex_size.x, tex_size.y) * 0.5
	return maxf(MIN_HIT_RADIUS_PX, sprite_radius)


func _collect_litter(litter: Sprite2D) -> void:
	if not is_instance_valid(litter):
		return
	_collecting = true
	litter.set_meta("collectible", false)
	var world_pos := litter.global_position
	var combo_tier := _advance_combo()
	var payout := GameState.collect_harvest_ball(world_pos, combo_tier)
	SfxManager.play_pickup_plink(combo_tier)
	if _range_view.has_method("show_pickup_cash_float"):
		_range_view.show_pickup_cash_float(world_pos, payout, combo_tier)
	if payout > 0.0:
		EventBus.pickup_payout.emit(payout, combo_tier)
	_tween_to_bucket(litter)


func _advance_combo() -> int:
	var now := Time.get_ticks_msec()
	if now - _last_collect_msec <= int(Balance.COMBO_WINDOW_SEC * 1000.0):
		_combo += 1
	else:
		_combo = 1
	_last_collect_msec = now
	_best_combo = maxi(_best_combo, _combo)
	return _combo


func _bucket_target_global() -> Vector2:
	if _bucket_counter == null:
		return Vector2(440.0, 250.0)
	if _bucket_counter.has_method("get_tween_target_global"):
		return _bucket_counter.get_tween_target_global()
	return _bucket_counter.get_global_rect().get_center()


func _tween_to_bucket(litter: Sprite2D) -> void:
	var start := litter.global_position
	var end := _bucket_target_global()
	var mid := (start + end) * 0.5 + Vector2(0.0, -ARC_HEIGHT_PX)
	var tween := _range_view.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(litter):
				return
			var u := 1.0 - t
			litter.global_position = (
				u * u * start + 2.0 * u * t * mid + t * t * end
			),
		0.0,
		1.0,
		TWEEN_DURATION_SEC
	)
	tween.tween_callback(func() -> void:
		if is_instance_valid(litter):
			litter.queue_free()
		_collecting = false
		if GameState.is_harvest_complete():
			_finish_harvest()
	)


func _finish_harvest() -> void:
	var bonus := GameState.complete_harvest(_best_combo)
	if bonus > 0.0:
		EventBus.pickup_payout.emit(bonus, 0)
	SfxManager.play_bucket_full_chime()
	_clear_litter()
	_return_to_strike()


func _skip_harvest() -> void:
	GameState.skip_harvest()
	_mark_all_litter_non_collectible()
	_return_to_strike()


func _return_to_strike() -> void:
	if _range_view.has_method("on_harvest_complete"):
		_range_view.on_harvest_complete()


func _mark_all_litter_collectible() -> void:
	if _littered_balls == null:
		return
	for child in _littered_balls.get_children():
		if child is Sprite2D:
			child.set_meta("collectible", true)


func _mark_all_litter_non_collectible() -> void:
	if _littered_balls == null:
		return
	for child in _littered_balls.get_children():
		if child is Sprite2D:
			child.set_meta("collectible", false)


func _clear_litter() -> void:
	if _littered_balls == null:
		return
	for child in _littered_balls.get_children():
		child.queue_free()
