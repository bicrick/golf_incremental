class_name WorldCloudField
extends Node3D
## Pre-filled cloud deck — random XZ scatter, uniform east drift, wrap replenishment.

enum DeckMood { CLEAR, SCATTERED, OVERCAST }

const WorldCloudClusterScript := preload("res://scripts/visual/world_cloud_cluster.gd")

const NIGHT_SPAWN_INTERVAL_MAX := 18.0

@export var cloud_layer_y: float = 19.0
@export var block_size: float = 2.5
@export var max_clouds_day: int = 24
@export var min_clouds_night: int = 2
@export var spawn_interval_sec: float = 3.0
@export var drift_speed: float = 2.5
@export var deck_half_extent_x: float = 20000.0
@export var wrap_inner_fraction: float = 0.35
@export var spawn_depth_x_factor: float = 8.0
@export var spawn_z_near: float = -15.0
@export var spawn_z_far: float = -285.0
@export var mood_clear_weight: float = 0.10
@export var mood_scattered_weight: float = 0.40
@export var mood_clear_min_sec: float = 18.0
@export var mood_clear_max_sec: float = 35.0
@export var mood_cloudy_min_sec: float = 50.0
@export var mood_cloudy_max_sec: float = 110.0
@export var ebb_flow_period_sec: float = 110.0
@export var ebb_flow_depth: float = 0.22
@export var coverage_clear_max: float = 0.0
@export var coverage_min: float = 0.12
@export var coverage_scattered_min: float = 0.28
@export var coverage_scattered_max: float = 0.55
@export var coverage_max_day: float = 0.52
@export var coverage_overcast_min: float = 0.62
@export var coverage_overcast_max: float = 0.92
@export var coverage_max_night: float = 0.35
@export var coverage_min_day: float = 0.22
@export var mood_change_min_sec: float = 50.0
@export var mood_change_max_sec: float = 110.0

var _active: Array[Node3D] = []
var _spawn_timer := 0.0
var _mood_timer := 0.0
var _mood_duration := 60.0
var _flow_phase := 0.0
var _deck_mood: DeckMood = DeckMood.SCATTERED
var _density := 1.0
var _target_alpha := 0.88
var _day_tint := Color(0.97, 0.98, 1.0)
var _night_blend := 0.0
var _master_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_master_material = WorldCloudClusterScript._default_material()
	if Engine.is_editor_hint():
		return
	_flow_phase = _rng.randf_range(0.0, TAU)
	_roll_mood(false)
	_seed_field()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var parent_3d := get_parent() as Node3D
	if parent_3d != null and not parent_3d.visible:
		return

	_update_mood(delta)
	_flow_phase += delta * TAU / maxf(ebb_flow_period_sec, 1.0)
	_move_clouds(delta)
	_wrap_oob()
	if _deck_mood != DeckMood.CLEAR:
		_spawn_timer += delta
		if _spawn_timer >= _current_spawn_interval() and _active.size() < _current_max_active():
			_spawn_timer = 0.0
			_spawn_patch(_random_field_position())
	_apply_material_tint()


func update_atmosphere(
	cycle_time: float,
	snap: DayNightPalette.AtmosphereSnapshot,
	day_factor: float
) -> void:
	var day_peak := DayNightPalette.cloud_visibility(cycle_time)
	_density = lerpf(0.0, 1.0, day_peak)
	_target_alpha = lerpf(0.45, 0.88, maxf(_density, 0.15))
	_day_tint = Color(0.97, 0.98, 1.0)
	var night_tint := snap.canvas_modulate.lerp(Color(0.82, 0.85, 0.92), 0.6)
	_night_blend = 1.0 - day_factor
	_day_tint = _day_tint.lerp(night_tint, _night_blend)
	_trim_to_cap()
	_apply_material_tint()


func get_density() -> float:
	return _density


func get_max_active() -> int:
	return _current_max_active()


func get_target_alpha() -> float:
	return _target_alpha


func get_drift_speed() -> float:
	return drift_speed


func get_deck_mood() -> int:
	return _deck_mood


func pick_field_position() -> Vector3:
	return _random_field_position()


func pick_wrap_position() -> Vector3:
	return _random_wrap_position()


func despawn_x_for_z(z: float) -> float:
	return deck_half_extent_x_for_z(z)


func west_wrap_limit_for_z(z: float) -> float:
	return -deck_half_extent_x_for_z(z)


func deck_half_extent_x_for_z(z: float) -> float:
	return deck_half_extent_x + depth_push_for_z(z)


func depth_push_for_z(z: float) -> float:
	return absf(z) * spawn_depth_x_factor


func set_deck_mood_for_test(mood: DeckMood) -> void:
	_deck_mood = mood
	_mood_timer = 0.0
	_trim_to_cap()
	if mood != DeckMood.CLEAR:
		_replenish_to_cap()


func track_cluster_for_test(cluster: Node3D) -> void:
	_active.append(cluster)


func move_clouds_step(delta: float) -> void:
	_move_clouds(delta)


func get_flow_strength() -> float:
	return _flow_multiplier()


func _flow_multiplier() -> float:
	if _deck_mood == DeckMood.CLEAR:
		return 0.0
	var wave := sin(_flow_phase) * 0.5 + 0.5
	return lerpf(1.0 - ebb_flow_depth, 1.0, wave)


func _current_max_active() -> int:
	if _deck_mood == DeckMood.CLEAR or _density <= 0.01:
		return 0
	var mood_cap := max_clouds_day
	match _deck_mood:
		DeckMood.SCATTERED:
			mood_cap = maxi(4, roundi(float(max_clouds_day) * 0.72))
		DeckMood.OVERCAST:
			mood_cap = max_clouds_day
	mood_cap = maxi(1, roundi(float(mood_cap) * _flow_multiplier()))
	return maxi(
		roundi(lerpf(float(min_clouds_night), float(mood_cap), _density)),
		min_clouds_night if _deck_mood != DeckMood.CLEAR else 0
	)


func _current_spawn_interval() -> float:
	return lerpf(NIGHT_SPAWN_INTERVAL_MAX, spawn_interval_sec, maxf(_density, 0.2))


func _roll_mood(allow_clear: bool = true) -> void:
	var roll := _rng.randf()
	var clear_cutoff := mood_clear_weight if allow_clear else 0.0
	var scattered_cutoff := clear_cutoff + mood_scattered_weight
	if roll < clear_cutoff:
		_deck_mood = DeckMood.CLEAR
		_mood_duration = _rng.randf_range(mood_clear_min_sec, mood_clear_max_sec)
	elif roll < scattered_cutoff:
		_deck_mood = DeckMood.SCATTERED
		_mood_duration = _rng.randf_range(mood_cloudy_min_sec, mood_cloudy_max_sec)
	else:
		_deck_mood = DeckMood.OVERCAST
		_mood_duration = _rng.randf_range(mood_cloudy_min_sec, mood_cloudy_max_sec)
	_mood_timer = 0.0
	_trim_to_cap()
	if _deck_mood != DeckMood.CLEAR:
		_replenish_to_cap()


func _update_mood(delta: float) -> void:
	_mood_timer += delta
	if _mood_timer < _mood_duration:
		return
	_roll_mood()
	if _deck_mood != DeckMood.CLEAR:
		_replenish_to_cap()


func _replenish_to_cap() -> void:
	var cap := _current_max_active()
	while _active.size() < cap:
		_spawn_patch(_random_field_position())


func _seed_field() -> void:
	if _deck_mood == DeckMood.CLEAR:
		return
	_replenish_to_cap()


func _spawn_patch(position: Vector3) -> void:
	if _deck_mood == DeckMood.CLEAR:
		return
	var seed := int(_rng.randi())
	var coverage := _pick_coverage()
	var cluster: Node3D = WorldCloudClusterScript.generate(
		seed,
		cloud_layer_y,
		coverage,
		block_size,
		_master_material
	)
	if WorldCloudClusterScript.block_count_for(cluster) <= 0:
		cluster.queue_free()
		return

	cluster.position = position
	add_child(cluster)
	_active.append(cluster)


func _random_field_position() -> Vector3:
	var z := _rng.randf_range(spawn_z_near, spawn_z_far)
	var extent := deck_half_extent_x_for_z(z)
	return Vector3(_rng.randf_range(-extent, extent), 0.0, z)


func _random_wrap_position() -> Vector3:
	var z := _rng.randf_range(spawn_z_near, spawn_z_far)
	var extent := deck_half_extent_x_for_z(z)
	var west_outer := -extent
	var west_inner := -extent * wrap_inner_fraction
	return Vector3(_rng.randf_range(west_outer, west_inner), 0.0, z)


func _pick_coverage() -> float:
	if _deck_mood == DeckMood.CLEAR:
		return coverage_clear_max
	if _deck_mood == DeckMood.OVERCAST:
		if _density < 0.6:
			return _rng.randf_range(coverage_scattered_min, coverage_max_night)
		return _rng.randf_range(coverage_overcast_min, coverage_overcast_max)
	if _density < 0.6:
		return _rng.randf_range(coverage_min, coverage_max_night)
	return _rng.randf_range(coverage_scattered_min, coverage_scattered_max)


func _move_clouds(delta: float) -> void:
	var velocity := Vector3(drift_speed, 0.0, 0.0)
	for cluster in _active:
		if is_instance_valid(cluster):
			cluster.position += velocity * delta


func _wrap_oob() -> void:
	for cluster in _active:
		if not is_instance_valid(cluster):
			continue
		if cluster.position.x > despawn_x_for_z(cluster.position.z):
			cluster.position = _random_wrap_position()


func _trim_to_cap() -> void:
	var cap := _current_max_active()
	while _active.size() > cap:
		var cluster: Node3D = _active.pop_back() as Node3D
		if is_instance_valid(cluster):
			cluster.queue_free()


func _apply_material_tint() -> void:
	if _master_material == null:
		return
	_master_material.albedo_color = Color(
		_day_tint.r,
		_day_tint.g,
		_day_tint.b,
		_target_alpha
	)
	for cluster in _active:
		if not is_instance_valid(cluster):
			continue
		for child in cluster.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = _master_material
